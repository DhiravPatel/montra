// Package fx manages exchange rates and conversions (spec §4.19, §20B.20).
// Rates are append-only observations (base, quote, rate, source, as_of):
// a new provider rate never rewrites history. Conversions disclose the rate,
// its source and timestamp, and use exact rational arithmetic with
// half-away-from-zero rounding (domain/money).
package fx

import (
	"context"
	"encoding/xml"
	"fmt"
	"io"
	"math/big"
	"net/http"
	"strings"
	"time"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"

	"montra/backend/internal/apitypes"
	"montra/backend/internal/domain/currency"
	"montra/backend/internal/domain/money"
	"montra/backend/internal/domain/period"
	"montra/backend/internal/finance"
	"montra/backend/internal/platform/apperr"
	"montra/backend/internal/platform/audit"
	"montra/backend/internal/platform/breaker"
	"montra/backend/internal/platform/config"
	"montra/backend/internal/platform/database"
	"montra/backend/internal/platform/identity"
	"montra/backend/internal/platform/jobs"
)

// JobRefresh fetches provider rates (when a provider is configured).
const JobRefresh = "fx.refresh"

// Policies select which rate converts a dated amount.
const (
	PolicyHistorical = "historical" // latest rate on or before the amount's date
	PolicyCurrent    = "current"    // latest available rate
)

// Service implements FX.
type Service struct {
	DB   *database.DB
	Cfg  config.FXConfig
	HTTP *http.Client
	Now  func() time.Time
	// Breaker guards the provider fetch (NewBreaker); nil uses the
	// process-wide "fx.ecb" breaker.
	Breaker *breaker.Breaker
}

// NewBreaker returns the breaker for the rate provider fetch.
func NewBreaker() *breaker.Breaker { return breaker.New("fx.ecb", breaker.Options{}) }

func (s *Service) breaker() *breaker.Breaker {
	if s.Breaker != nil {
		return s.Breaker
	}
	return breaker.Named("fx.ecb", breaker.Options{})
}

func (s *Service) now() time.Time {
	if s.Now != nil {
		return s.Now()
	}
	return time.Now()
}

// Rate is a resolved rate: quote units per one base unit.
type Rate struct {
	Base     string    `json:"base"`
	Quote    string    `json:"quote"`
	Rate     string    `json:"rate" doc:"Exact decimal: quote currency units per 1 base unit"`
	Source   string    `json:"source" enum:"manual,ecb,provider"`
	AsOf     time.Time `json:"as_of"`
	Inverted bool      `json:"inverted" doc:"Derived as 1 / (quote→base rate)"`
	value    *big.Rat
}

// Lookup resolves a rate for converting `from` into `to` at time `at`
// (zero = current). The caller's manual overrides win over provider rates;
// an inverse pair is used when only the opposite direction exists.
func Lookup(ctx context.Context, tx pgx.Tx, uid uuid.UUID, from, to string, at time.Time) (*Rate, bool, error) {
	if from == to {
		return &Rate{Base: from, Quote: to, Rate: "1", Source: "manual", value: big.NewRat(1, 1)}, true, nil
	}
	if at.IsZero() {
		at = time.Now().Add(24 * time.Hour)
	}
	for _, inverted := range []bool{false, true} {
		b, q := from, to
		if inverted {
			b, q = to, from
		}
		var rateText, source string
		var asOf time.Time
		err := tx.QueryRow(ctx, `select rate::text, source, as_of from fx_rates where base_currency = $1 and quote_currency = $2
			and as_of <= $3 and (user_id = $4 or user_id is null)
			order by (user_id is not null) desc, as_of desc limit 1`, b, q, at, uid).Scan(&rateText, &source, &asOf)
		if database.IsNoRows(err) {
			continue
		}
		if err != nil {
			return nil, false, err
		}
		v, err := money.ParseRate(rateText)
		if err != nil {
			return nil, false, err
		}
		if inverted {
			v = new(big.Rat).Inv(v)
		}
		return &Rate{Base: from, Quote: to, Rate: money.FormatRate(v), Source: source, AsOf: asOf, Inverted: inverted, value: v}, true, nil
	}
	return nil, false, nil
}

// Value returns the exact rate.
func (r *Rate) Value() *big.Rat { return r.value }

// EndOfDay returns the last instant of the local calendar day that starts
// at midnight (a day can last 23 or 25 hours across a DST change, so this
// is the next local midnight minus one microsecond, the timestamptz
// resolution). Conversions dated d use the latest rate on or before it.
func EndOfDay(midnight time.Time) time.Time {
	return midnight.AddDate(0, 0, 1).Add(-time.Microsecond)
}

// NormalizeDecimal renders a PostgreSQL numeric without padding zeros:
// "83.123400000000" → "83.1234", "83.000000000000" → "83", ".5" → "0.5".
// It keeps at least one integer digit and never ends with a dot. Text that
// is not a plain decimal is returned unchanged.
func NormalizeDecimal(s string) string {
	t := strings.TrimSpace(s)
	sign := ""
	if strings.HasPrefix(t, "-") {
		sign, t = "-", t[1:]
	}
	intPart, frac, _ := strings.Cut(t, ".")
	if (intPart == "" && frac == "") || !digitsOnly(intPart) || !digitsOnly(frac) {
		return s
	}
	intPart = strings.TrimLeft(intPart, "0")
	if intPart == "" {
		intPart = "0"
	}
	frac = strings.TrimRight(frac, "0")
	if intPart == "0" && frac == "" {
		return "0"
	}
	if frac == "" {
		return sign + intPart
	}
	return sign + intPart + "." + frac
}

func digitsOnly(s string) bool {
	for _, r := range s {
		if r < '0' || r > '9' {
			return false
		}
	}
	return true
}

// ConversionDTO discloses one conversion.
type ConversionDTO struct {
	From          apitypes.Money `json:"from"`
	To            apitypes.Money `json:"to"`
	Rate          Rate           `json:"rate"`
	Policy        string         `json:"policy" enum:"historical,current"`
	RoundingDelta string         `json:"rounding_delta" doc:"Exact converted value minus the rounded amount, in target minor units"`
}

// Convert converts an amount with a disclosed rate.
func (s *Service) Convert(ctx context.Context, amount, from, to, date, policy string) (*ConversionDTO, error) {
	uid, err := identity.UserID(ctx)
	if err != nil {
		return nil, err
	}
	if !currency.Valid(from) || !currency.Valid(to) {
		return nil, apperr.FieldError("query.to", "Unsupported currency.")
	}
	minor, err := money.Parse(amount, from, money.ParseOptions{AllowNegative: true, AllowZero: true})
	if err != nil {
		return nil, apperr.FieldError("query.amount", "Enter an amount in "+from+" precision.")
	}
	if policy == "" {
		policy = PolicyCurrent
	}
	var out ConversionDTO
	err = s.DB.WithUserReadTx(ctx, uid, func(tx pgx.Tx) error {
		at := time.Time{}
		if policy == PolicyHistorical {
			u, err := finance.LoadUser(ctx, tx, uid)
			if err != nil {
				return err
			}
			d, err := finance.ParseDate("query.date", date, u.Loc)
			if err != nil {
				return err
			}
			at = EndOfDay(d)
		}
		r, ok, err := Lookup(ctx, tx, uid, from, to, at)
		if err != nil {
			return err
		}
		if !ok {
			return apperr.New(apperr.CodeNotFound, http.StatusNotFound, "No exchange rate is available for "+from+"→"+to+". Add a manual rate.")
		}
		c, err := money.Convert(minor, from, to, r.value)
		if err != nil {
			return apperr.FieldError("query.amount", "The converted amount is out of range.")
		}
		out = ConversionDTO{From: apitypes.M(minor, from), To: apitypes.M(c.ToMinor, to), Rate: *r, Policy: policy, RoundingDelta: c.RoundingDelta}
		return nil
	})
	if err != nil {
		return nil, database.MapError(err)
	}
	return &out, nil
}

// RateDTO is a stored rate observation.
type RateDTO struct {
	ID        uuid.UUID `json:"id"`
	Base      string    `json:"base"`
	Quote     string    `json:"quote"`
	Rate      string    `json:"rate" doc:"Exact decimal without padding zeros (e.g. 83.1234, 83, 0.5): quote units per 1 base unit"`
	Source    string    `json:"source" enum:"manual,ecb,provider"`
	AsOf      time.Time `json:"as_of"`
	Mine      bool      `json:"mine" doc:"Your manual override (editable)"`
	CreatedAt time.Time `json:"created_at"`
}

// ListRates returns the latest rate per pair and source visible to the
// caller (provider rates plus the caller's overrides).
func (s *Service) ListRates(ctx context.Context, base, quote string) ([]RateDTO, error) {
	uid, err := identity.UserID(ctx)
	if err != nil {
		return nil, err
	}
	out := []RateDTO{}
	err = s.DB.WithUserReadTx(ctx, uid, func(tx pgx.Tx) error {
		rows, err := tx.Query(ctx, `select distinct on (base_currency, quote_currency, source, user_id is not null)
			id, base_currency, quote_currency, rate::text, source, as_of, user_id is not null, created_at from fx_rates
			where ($1 = '' or base_currency = $1) and ($2 = '' or quote_currency = $2)
			order by base_currency, quote_currency, source, user_id is not null, as_of desc limit 500`, base, quote)
		if err != nil {
			return err
		}
		out, err = pgx.CollectRows(rows, func(r pgx.CollectableRow) (RateDTO, error) {
			var x RateDTO
			err := r.Scan(&x.ID, &x.Base, &x.Quote, &x.Rate, &x.Source, &x.AsOf, &x.Mine, &x.CreatedAt)
			x.Rate = NormalizeDecimal(x.Rate)
			return x, err
		})
		return err
	})
	return out, database.MapError(err)
}

// ManualRateInput records a personal override.
type ManualRateInput struct {
	Base  string `json:"base" pattern:"^[A-Z]{3}$"`
	Quote string `json:"quote" pattern:"^[A-Z]{3}$"`
	Rate  string `json:"rate" doc:"Quote units per 1 base unit, exact decimal (e.g. 83.1234)"`
	AsOf  string `json:"as_of,omitempty" doc:"RFC 3339 instant, or a YYYY-MM-DD date meaning the start of that day in your time zone (the rate then applies to conversions dated that day); default now. Dates after today in your time zone, and instants more than an hour ahead, are rejected"`
}

// parseAsOf resolves a manual rate's as_of. An RFC 3339 instant is kept as
// sent. A bare date is the start of that day in the user's time zone, so
// the rate applies to every conversion dated that day (conversions use the
// latest rate on or before the end of the day) and today's date is never
// "in the future", whatever the zone's offset (UTC+5:30, UTC+13, ...).
func parseAsOf(s string, now time.Time, loc *time.Location) (time.Time, error) {
	if s == "" {
		return now, nil
	}
	future := apperr.FieldError("body.as_of", "A rate cannot be dated in the future.")
	if t, err := time.Parse(time.RFC3339, s); err == nil {
		if t.After(now.Add(time.Hour)) {
			return time.Time{}, future
		}
		return t, nil
	}
	d, err := finance.ParseDate("body.as_of", s, loc)
	if err != nil {
		if _, perr := time.Parse(time.DateOnly, s); perr != nil {
			return time.Time{}, apperr.FieldError("body.as_of", "Use RFC 3339 or YYYY-MM-DD.")
		}
		return time.Time{}, err // a real date outside the supported years
	}
	if d.After(period.Today(now, loc)) {
		return time.Time{}, future
	}
	return d, nil
}

// SetManualRate stores a manual override (history is kept).
func (s *Service) SetManualRate(ctx context.Context, in ManualRateInput) (*RateDTO, error) {
	uid, err := identity.UserID(ctx)
	if err != nil {
		return nil, err
	}
	if !currency.Valid(in.Base) || !currency.Valid(in.Quote) || in.Base == in.Quote {
		return nil, apperr.FieldError("body.quote", "Choose two different supported currencies.")
	}
	r, err := money.ParseRate(in.Rate)
	if err != nil {
		return nil, apperr.FieldError("body.rate", "Enter a positive exact rate such as 83.1234.")
	}
	var out RateDTO
	err = s.DB.WithUserTx(ctx, uid, func(tx pgx.Tx) error {
		u, err := finance.LoadUser(ctx, tx, uid)
		if err != nil {
			return err
		}
		at, err := parseAsOf(in.AsOf, s.now(), u.Loc)
		if err != nil {
			return err
		}
		if err := tx.QueryRow(ctx, `insert into fx_rates (user_id, base_currency, quote_currency, rate, source, as_of)
			values ($1,$2,$3,$4::numeric,'manual',$5)
			on conflict (coalesce(user_id, '00000000-0000-0000-0000-000000000000'::uuid), base_currency, quote_currency, source, as_of)
			do update set rate = excluded.rate
			returning id, base_currency, quote_currency, rate::text, source, as_of, true, created_at`, uid, in.Base, in.Quote, money.FormatRate(r), at).
			Scan(&out.ID, &out.Base, &out.Quote, &out.Rate, &out.Source, &out.AsOf, &out.Mine, &out.CreatedAt); err != nil {
			return err
		}
		out.Rate = NormalizeDecimal(out.Rate)
		return audit.Record(ctx, tx, audit.Event{UserID: &uid, ActorUserID: &uid, EntityType: "fx_rate", EntityID: &out.ID, Action: "set",
			Changes: map[string]any{"pair": in.Base + "/" + in.Quote, "rate": out.Rate}})
	})
	if err != nil {
		return nil, database.MapError(err)
	}
	return &out, nil
}

// DeleteManualRate removes one of the caller's overrides.
func (s *Service) DeleteManualRate(ctx context.Context, id uuid.UUID) error {
	uid, err := identity.UserID(ctx)
	if err != nil {
		return err
	}
	return database.MapError(s.DB.WithUserTx(ctx, uid, func(tx pgx.Tx) error {
		tag, err := tx.Exec(ctx, `delete from fx_rates where id = $1 and user_id = $2`, id, uid)
		if err != nil {
			return err
		}
		if tag.RowsAffected() == 0 {
			return apperr.NotFound("rate")
		}
		return audit.Record(ctx, tx, audit.Event{UserID: &uid, ActorUserID: &uid, EntityType: "fx_rate", EntityID: &id, Action: "deleted"})
	}))
}

// RegisterJobs registers the provider refresh (a no-op unless FX_PROVIDER=ecb).
func (s *Service) RegisterJobs(reg *jobs.Registry) {
	reg.Register(JobRefresh, func(ctx context.Context, _ jobs.Job) error {
		if s.Cfg.Provider != "ecb" {
			return nil
		}
		_, err := s.RefreshECB(ctx)
		return err
	}, jobs.WithTimeout(time.Minute), jobs.WithConcurrency(1))
}

type ecbEnvelope struct {
	Cube struct {
		Days []struct {
			Time  string `xml:"time,attr"`
			Rates []struct {
				Currency string `xml:"currency,attr"`
				Rate     string `xml:"rate,attr"`
			} `xml:"Cube"`
		} `xml:"Cube"`
	} `xml:"Cube"`
}

// RefreshECB fetches the ECB daily reference rates (EUR base) and appends
// them as system rates; existing observations are never modified.
func (s *Service) RefreshECB(ctx context.Context) (int, error) {
	client := s.HTTP
	if client == nil {
		client = &http.Client{Timeout: 20 * time.Second}
	}
	req, err := http.NewRequestWithContext(ctx, http.MethodGet, s.Cfg.ECBURL, nil)
	if err != nil {
		return 0, err
	}
	req.Header.Set("User-Agent", "Montra-FX/1.0")
	// The fetch runs through the provider's circuit breaker: while ECB keeps
	// failing, refreshes fail fast with a retryable error (the job backs off
	// at least until the cool-down ends) instead of waiting on timeouts.
	body, err := breaker.Call(ctx, s.breaker(), func(context.Context) ([]byte, error) {
		resp, err := client.Do(req)
		if err != nil {
			return nil, err
		}
		defer func() { _ = resp.Body.Close() }()
		if resp.StatusCode != http.StatusOK {
			return nil, fmt.Errorf("ecb status %d", resp.StatusCode)
		}
		return io.ReadAll(io.LimitReader(resp.Body, 1<<20))
	})
	if err != nil {
		return 0, jobs.WithCode("provider_unavailable", err)
	}
	var env ecbEnvelope
	if err := xml.Unmarshal(body, &env); err != nil {
		return 0, jobs.Permanent(fmt.Errorf("ecb payload: %w", err))
	}
	n := 0
	err = s.DB.WithSystemTx(ctx, func(tx pgx.Tx) error {
		for _, day := range env.Cube.Days {
			at, err := time.Parse("2006-01-02", day.Time)
			if err != nil {
				continue
			}
			at = at.Add(16 * time.Hour) // ECB publishes around 16:00 CET
			for _, r := range day.Rates {
				cur := strings.ToUpper(strings.TrimSpace(r.Currency))
				if !currency.Valid(cur) {
					continue
				}
				v, err := money.ParseRate(strings.TrimSpace(r.Rate))
				if err != nil {
					continue
				}
				tag, err := tx.Exec(ctx, `insert into fx_rates (user_id, base_currency, quote_currency, rate, source, as_of)
					values (null, 'EUR', $1, $2::numeric, 'ecb', $3) on conflict do nothing`, cur, money.FormatRate(v), at)
				if err != nil {
					return err
				}
				n += int(tag.RowsAffected())
			}
		}
		return nil
	})
	return n, err
}
