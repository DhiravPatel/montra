package subscriptions

import (
	"context"
	"crypto/sha256"
	"encoding/hex"
	"encoding/json"
	"fmt"
	"strings"
	"time"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"

	"montra/backend/internal/apitypes"
	"montra/backend/internal/domain/subdetect"
	"montra/backend/internal/finance"
	"montra/backend/internal/notifications"
	"montra/backend/internal/platform/apperr"
	"montra/backend/internal/platform/audit"
	"montra/backend/internal/platform/database"
	"montra/backend/internal/platform/identity"
	"montra/backend/internal/platform/jobs"
)

// Job types.
const (
	JobDetect    = "subscriptions.detect"     // one user
	JobDetectAll = "subscriptions.detect_all" // periodic fan-out
	JobRenewals  = "subscriptions.renewals"   // periodic reminders/advancement
)

// DetectionEvidence explains a detection.
type DetectionEvidence struct {
	Reasons                []string `json:"reasons" doc:"English; localize by reason_codes"`
	ReasonCodes            []string `json:"reason_codes" enum:"charge_cadence,intervals_fit_cadence,amounts_within_tolerance" doc:"Stable codes in the order of reasons. charge_cadence: charge_count charges, typically every median_interval_days days (the candidate's cadence); intervals_fit_cadence: intervals_in_cycle of the intervals_days fit the cadence; amounts_within_tolerance: amounts_within_tolerance of charge_count amounts are within amount_tolerance_bp of the typical amount"`
	IntervalsDays          []int    `json:"intervals_days"`
	MedianIntervalDays     int      `json:"median_interval_days"`
	IntervalsInCycle       int      `json:"intervals_in_cycle" doc:"Intervals that fit the cadence (intervals_fit_cadence)"`
	AmountsMinor           []int64  `json:"amounts_minor"`
	AmountsWithinTolerance int      `json:"amounts_within_tolerance" doc:"Charges within the tolerance of the typical amount (amounts_within_tolerance)"`
	AmountToleranceBP      int      `json:"amount_tolerance_bp" doc:"Accepted deviation from the typical amount, in basis points (500 = 5%)"`
	LastChargeDate         string   `json:"last_charge_date"`
	ChargeCount            int      `json:"charge_count"`
}

// detectionReasonCodes are the codes of subdetect's reasons, in order.
var detectionReasonCodes = []string{"charge_cadence", "intervals_fit_cadence", "amounts_within_tolerance"}

// detectionToleranceBP is subdetect's accepted deviation from the typical
// amount (5%).
const detectionToleranceBP = 500

// explain fills the reason codes and the counts their texts use. Both are
// derived from the stored evidence, so candidates saved before the codes
// existed get them too.
func explain(ev *DetectionEvidence, cadence string, typical, tolerance int64) {
	if ev.Reasons == nil {
		ev.Reasons = []string{}
	}
	if ev.IntervalsDays == nil {
		ev.IntervalsDays = []int{}
	}
	if ev.AmountsMinor == nil {
		ev.AmountsMinor = []int64{}
	}
	ev.ReasonCodes = append([]string{}, detectionReasonCodes[:min(len(detectionReasonCodes), len(ev.Reasons))]...)
	ev.IntervalsInCycle, ev.AmountsWithinTolerance, ev.AmountToleranceBP = 0, 0, detectionToleranceBP
	for _, c := range subdetect.Cadences {
		if c.Name != cadence {
			continue
		}
		for _, d := range ev.IntervalsDays {
			if d >= c.Min && d <= c.Max {
				ev.IntervalsInCycle++
			}
		}
	}
	for _, a := range ev.AmountsMinor {
		if d := a - typical; d <= tolerance && -d <= tolerance {
			ev.AmountsWithinTolerance++
		}
	}
}

// DetectionCandidateDTO is a detected possible subscription.
type DetectionCandidateDTO struct {
	ID                     uuid.UUID         `json:"id"`
	MerchantID             *uuid.UUID        `json:"merchant_id,omitempty"`
	MerchantLabel          string            `json:"merchant_label"`
	Amount                 apitypes.Money    `json:"amount" doc:"Typical charge"`
	AmountTolerance        apitypes.Money    `json:"amount_tolerance"`
	Cadence                string            `json:"cadence" enum:"weekly,monthly,quarterly,semiannual,yearly"`
	ConfidenceBP           int               `json:"confidence_bp" minimum:"0" maximum:"10000" doc:"Canonical confidence in basis points (10000 = certain): an explainable score from cadence, amount consistency and charge count. Detections are suggested from 6000"`
	Confidence             string            `json:"confidence,omitempty" deprecated:"true" doc:"Deprecated (use confidence_bp): the same score as a decimal string with three places, from \"0.000\" to \"1.000\""`
	EvidenceTransactionIDs []uuid.UUID       `json:"evidence_transaction_ids"`
	Evidence               DetectionEvidence `json:"evidence"`
	NextExpectedDate       *string           `json:"next_expected_date,omitempty"`
	Status                 string            `json:"status" enum:"pending,confirmed,dismissed"`
	CreatedAt              time.Time         `json:"created_at"`
}

const candCols = `id, merchant_id, merchant_label, amount_minor, currency, amount_tolerance_minor, cadence, confidence::text,
	(confidence * 10000)::int, evidence_transaction_ids, evidence, next_expected_date, status, created_at`

func scanCandidate(r pgx.Row) (*DetectionCandidateDTO, error) {
	var c DetectionCandidateDTO
	var amt, tol int64
	var cur string
	var ev []byte
	var next *time.Time
	if err := r.Scan(&c.ID, &c.MerchantID, &c.MerchantLabel, &amt, &cur, &tol, &c.Cadence, &c.Confidence, &c.ConfidenceBP,
		&c.EvidenceTransactionIDs, &ev, &next, &c.Status, &c.CreatedAt); err != nil {
		return nil, err
	}
	c.Amount, c.AmountTolerance = apitypes.M(amt, cur), apitypes.M(tol, cur)
	if err := json.Unmarshal(ev, &c.Evidence); err != nil {
		return nil, err
	}
	explain(&c.Evidence, c.Cadence, amt, tol)
	if next != nil {
		n := finance.LocalDateString(*next)
		c.NextExpectedDate = &n
	}
	return &c, nil
}

type chargeRow struct {
	id       uuid.UUID
	date     time.Time
	amount   int64
	cur      string
	merchant *uuid.UUID
	label    string
	account  uuid.UUID
}

// DetectForUser scans the last 400 days of posted expenses and upserts
// pending candidates. Dismissed and confirmed candidates are never
// re-suggested (stable fingerprint per merchant, currency and cadence).
func (s *Service) DetectForUser(ctx context.Context, uid uuid.UUID) (int, error) {
	found := 0
	err := s.DB.WithSystemTx(ctx, func(tx pgx.Tx) error {
		var tz string
		if err := tx.QueryRow(ctx, `select p.timezone from users u join user_preferences p on p.user_id = u.id where u.id = $1 and u.status = 'active'`, uid).Scan(&tz); err != nil {
			if database.IsNoRows(err) {
				return nil
			}
			return err
		}
		today := localToday(s.now(), tz)
		rows, err := tx.Query(ctx, `select t.id, t.local_date, t.amount_minor, t.currency, t.merchant_id, coalesce(m.name, t.description, ''), t.account_id
			from transactions t left join merchants m on m.id = t.merchant_id
			where t.user_id = $1 and t.type = 'expense' and t.status = 'posted' and t.deleted_at is null and t.local_date >= $2
			and t.recurring_rule_id is null and t.transfer_id is null
			order by t.local_date limit 20000`, uid, today.AddDate(0, 0, -400))
		if err != nil {
			return err
		}
		charges, err := pgx.CollectRows(rows, func(r pgx.CollectableRow) (chargeRow, error) {
			var c chargeRow
			err := r.Scan(&c.id, &c.date, &c.amount, &c.cur, &c.merchant, &c.label, &c.account)
			return c, err
		})
		if err != nil {
			return err
		}
		// Merchants/names already tracked as subscriptions are skipped.
		trackedM := map[uuid.UUID]bool{}
		trackedN := map[string]bool{}
		srows, err := tx.Query(ctx, `select merchant_id, name from subscriptions where user_id = $1 and status <> 'cancelled'`, uid)
		if err != nil {
			return err
		}
		for srows.Next() {
			var mid *uuid.UUID
			var name string
			if err := srows.Scan(&mid, &name); err != nil {
				srows.Close()
				return err
			}
			if mid != nil {
				trackedM[*mid] = true
			}
			trackedN[finance.NormalizeName(name)] = true
		}
		srows.Close()
		if err := srows.Err(); err != nil {
			return err
		}
		type group struct {
			key, label, cur string
			merchant        *uuid.UUID
			charges         []subdetect.Charge
		}
		groups := map[string]*group{}
		var order []string
		for _, c := range charges {
			norm := finance.NormalizeName(c.label)
			var key string
			switch {
			case c.merchant != nil:
				if trackedM[*c.merchant] {
					continue
				}
				key = "m:" + c.merchant.String()
			case norm != "":
				key = "d:" + norm
			default:
				continue
			}
			if trackedN[norm] {
				continue
			}
			gk := key + "|" + c.cur
			g := groups[gk]
			if g == nil {
				g = &group{key: key, label: strings.TrimSpace(c.label), cur: c.cur, merchant: c.merchant}
				groups[gk] = g
				order = append(order, gk)
			}
			g.charges = append(g.charges, subdetect.Charge{ID: c.id.String(), Date: c.date, Amount: c.amount})
		}
		for _, gk := range order {
			g := groups[gk]
			cand, ok := subdetect.Detect(g.charges, today)
			if !ok {
				continue
			}
			ids := make([]uuid.UUID, 0, len(cand.EvidenceIDs))
			for _, e := range cand.EvidenceIDs {
				ids = append(ids, uuid.MustParse(e))
			}
			evidence := DetectionEvidence{Reasons: cand.Reasons, IntervalsDays: cand.IntervalsDays, MedianIntervalDays: cand.MedianInterval,
				AmountsMinor: cand.AmountsMinor, LastChargeDate: finance.LocalDateString(cand.LastCharge), ChargeCount: len(cand.AmountsMinor)}
			explain(&evidence, cand.Cadence, cand.Amount, cand.Tolerance)
			ev, err := json.Marshal(evidence)
			if err != nil {
				return err
			}
			sum := sha256.Sum256([]byte(g.key + "|" + g.cur + "|" + cand.Cadence))
			label := g.label
			if label == "" {
				label = "Recurring charge"
			}
			if r := []rune(label); len(r) > 200 {
				label = string(r[:200])
			}
			if _, err := tx.Exec(ctx, `insert into subscription_detection_candidates (user_id, merchant_id, merchant_label, amount_minor, currency,
				amount_tolerance_minor, cadence, confidence, evidence_transaction_ids, evidence, next_expected_date, fingerprint)
				values ($1,$2,$3,$4,$5,$6,$7,$8::numeric,$9,$10,$11,$12)
				on conflict (user_id, fingerprint) do update set amount_minor = excluded.amount_minor, amount_tolerance_minor = excluded.amount_tolerance_minor,
				  confidence = excluded.confidence, evidence_transaction_ids = excluded.evidence_transaction_ids, evidence = excluded.evidence,
				  next_expected_date = excluded.next_expected_date, merchant_label = excluded.merchant_label
				where subscription_detection_candidates.status = 'pending'`,
				uid, g.merchant, label, cand.Amount, g.cur, cand.Tolerance, cand.Cadence, fmt.Sprintf("%d.%03d", cand.ConfidenceMilli/1000, cand.ConfidenceMilli%1000),
				ids, ev, cand.NextExpected, hex.EncodeToString(sum[:])); err != nil {
				return err
			}
			found++
		}
		return nil
	})
	return found, err
}

// ListCandidates returns detection candidates (pending by default).
func (s *Service) ListCandidates(ctx context.Context, status string) ([]DetectionCandidateDTO, error) {
	uid, err := identity.UserID(ctx)
	if err != nil {
		return nil, err
	}
	if status == "" {
		status = "pending"
	}
	out := []DetectionCandidateDTO{}
	err = s.DB.WithUserReadTx(ctx, uid, func(tx pgx.Tx) error {
		rows, err := tx.Query(ctx, `select `+candCols+` from subscription_detection_candidates where status = $1
			order by confidence desc, created_at desc limit 100`, status)
		if err != nil {
			return err
		}
		defer rows.Close()
		for rows.Next() {
			c, err := scanCandidate(rows)
			if err != nil {
				return err
			}
			out = append(out, *c)
		}
		return rows.Err()
	})
	return out, database.MapError(err)
}

// RequestDetection queues a detection run for the caller.
func (s *Service) RequestDetection(ctx context.Context) error {
	uid, err := identity.UserID(ctx)
	if err != nil {
		return err
	}
	bucket := s.now().UTC().Truncate(10 * time.Minute).Format("200601021504")
	return database.MapError(s.DB.WithUserTx(ctx, uid, func(tx pgx.Tx) error {
		_, _, err := jobs.Enqueue(ctx, tx, jobs.Spec{Type: JobDetect, UserID: &uid, Payload: map[string]any{"user_id": uid},
			DedupeKey: "subdetect:" + uid.String() + ":" + bucket, Priority: 120})
		return err
	}))
}

// DetectionConfirmInput overrides detected values when confirming.
type DetectionConfirmInput struct {
	Name             string     `json:"name,omitempty" maxLength:"120" doc:"Defaults to the merchant label"`
	CategoryID       *uuid.UUID `json:"category_id,omitempty"`
	PaymentAccountID *uuid.UUID `json:"payment_account_id,omitempty" doc:"Defaults to the account of the latest matching charge"`
	Amount           string     `json:"amount,omitempty" doc:"Defaults to the typical detected amount"`
	NextRenewalDate  string     `json:"next_renewal_date,omitempty" doc:"Defaults to the projected next charge"`
}

// Confirm creates a subscription from a candidate after explicit user
// confirmation. The evidence transactions become its payment history; the
// transactions themselves are not modified.
func (s *Service) Confirm(ctx context.Context, id uuid.UUID, in DetectionConfirmInput) (*SubscriptionDetail, error) {
	uid, err := identity.UserID(ctx)
	if err != nil {
		return nil, err
	}
	var out *SubscriptionDetail
	err = s.DB.WithUserTx(ctx, uid, func(tx pgx.Tx) error {
		c, err := scanCandidate(tx.QueryRow(ctx, `select `+candCols+` from subscription_detection_candidates where id = $1 for update`, id))
		if database.IsNoRows(err) {
			return apperr.NotFound("detection")
		}
		if err != nil {
			return err
		}
		if c.Status != "pending" {
			return apperr.ConflictCode("detection_already_decided", "This detection was already "+c.Status+".", map[string]string{"status": c.Status})
		}
		// DetectionEvidence still owned, active and in the candidate currency.
		rows, err := tx.Query(ctx, `select id, local_date, amount_minor, account_id from transactions where id = any($1) and user_id = $2
			and deleted_at is null and status = 'posted' and currency = $3 order by local_date`, c.EvidenceTransactionIDs, uid, c.Amount.Currency)
		if err != nil {
			return err
		}
		type ev struct {
			id      uuid.UUID
			date    time.Time
			amount  int64
			account uuid.UUID
		}
		evidence, err := pgx.CollectRows(rows, func(r pgx.CollectableRow) (ev, error) {
			var e ev
			err := r.Scan(&e.id, &e.date, &e.amount, &e.account)
			return e, err
		})
		if err != nil {
			return err
		}
		if len(evidence) == 0 {
			return apperr.ConflictCode("detection_evidence_missing", "The supporting transactions no longer exist; dismiss this detection.", nil)
		}
		name := strings.TrimSpace(in.Name)
		if name == "" {
			name = c.MerchantLabel
		}
		amount := in.Amount
		if amount == "" {
			amount = c.Amount.Amount
		}
		account := in.PaymentAccountID
		if account == nil {
			a := evidence[len(evidence)-1].account
			account = &a
		}
		next := in.NextRenewalDate
		if next == "" && c.NextExpectedDate != nil {
			next = *c.NextExpectedDate
		}
		input := SubscriptionInput{Name: name, CategoryID: in.CategoryID, Amount: amount, Currency: c.Amount.Currency, BillingFrequency: c.Cadence,
			StartDate: finance.LocalDateString(evidence[0].date), NextRenewalDate: next, PaymentAccountID: account}
		if c.MerchantID != nil {
			var mname string
			if err := tx.QueryRow(ctx, `select name from merchants where id = $1 and user_id = $2`, *c.MerchantID, uid).Scan(&mname); err == nil {
				input.MerchantName = mname
			}
		}
		subID, err := s.create(ctx, tx, uid, input, "detected", &c.ID)
		if err != nil {
			return err
		}
		// The evidence becomes the payment history, except charges that are
		// already a payment of another subscription (never counted twice).
		for _, e := range evidence {
			amt, txID := e.amount, e.id
			linked, err := linkPayment(ctx, tx, subID, txID, uid)
			if err != nil {
				return err
			}
			if !linked {
				continue
			}
			if err := event(ctx, tx, subID, uid, "payment_recorded", nil, &amt, &txID, e.date, noteMatchedByDetection, noteCodeMatchedByDetection); err != nil {
				return err
			}
		}
		if _, err := tx.Exec(ctx, `update subscription_detection_candidates set status = 'confirmed', decided_at = now() where id = $1`, id); err != nil {
			return err
		}
		if err := audit.Record(ctx, tx, audit.Event{UserID: &uid, ActorUserID: &uid, EntityType: "subscription_detection", EntityID: &id, Action: "confirmed",
			Changes: map[string]any{"subscription_id": subID}}); err != nil {
			return err
		}
		out, err = s.detail(ctx, tx, uid, subID)
		return err
	})
	return out, database.MapError(err)
}

// Dismiss rejects a candidate; it is not suggested again.
func (s *Service) Dismiss(ctx context.Context, id uuid.UUID) error {
	uid, err := identity.UserID(ctx)
	if err != nil {
		return err
	}
	return database.MapError(s.DB.WithUserTx(ctx, uid, func(tx pgx.Tx) error {
		tag, err := tx.Exec(ctx, `update subscription_detection_candidates set status = 'dismissed', decided_at = now() where id = $1 and status = 'pending'`, id)
		if err != nil {
			return err
		}
		if tag.RowsAffected() == 0 {
			return apperr.NotFound("pending detection")
		}
		return audit.Record(ctx, tx, audit.Event{UserID: &uid, ActorUserID: &uid, EntityType: "subscription_detection", EntityID: &id, Action: "dismissed"})
	}))
}

// RegisterJobs registers detection and renewal jobs.
func (s *Service) RegisterJobs(reg *jobs.Registry) {
	reg.Register(JobDetect, func(ctx context.Context, j jobs.Job) error {
		var p struct {
			UserID uuid.UUID `json:"user_id"`
		}
		if err := j.Decode(&p); err != nil {
			return jobs.Permanent(err)
		}
		_, err := s.DetectForUser(ctx, p.UserID)
		return err
	}, jobs.WithTimeout(2*time.Minute), jobs.WithConcurrency(2))
	reg.Register(JobDetectAll, func(ctx context.Context, _ jobs.Job) error { return s.fanOutDetection(ctx) },
		jobs.WithTimeout(5*time.Minute), jobs.WithConcurrency(1))
	reg.Register(JobRenewals, func(ctx context.Context, _ jobs.Job) error { return s.Renewals(ctx) },
		jobs.WithTimeout(5*time.Minute), jobs.WithConcurrency(1))
}

// fanOutDetection queues detection for users with recent expense activity.
func (s *Service) fanOutDetection(ctx context.Context) error {
	day := s.now().UTC().Format("20060102")
	return s.DB.WithSystemTx(ctx, func(tx pgx.Tx) error {
		rows, err := tx.Query(ctx, `select distinct t.user_id from transactions t join users u on u.id = t.user_id
			where u.status = 'active' and t.type = 'expense' and t.created_at > now() - interval '2 days' limit 5000`)
		if err != nil {
			return err
		}
		ids, err := pgx.CollectRows(rows, pgx.RowTo[uuid.UUID])
		if err != nil {
			return err
		}
		for _, id := range ids {
			uid := id
			if _, _, err := jobs.Enqueue(ctx, tx, jobs.Spec{Type: JobDetect, UserID: &uid, Payload: map[string]any{"user_id": uid},
				DedupeKey: "subdetect:" + uid.String() + ":" + day, Priority: 180}); err != nil {
				return err
			}
		}
		return nil
	})
}

// Renewals advances passed renewal dates, converts ended trials and sends
// renewal and trial-ending reminders (once per date).
func (s *Service) Renewals(ctx context.Context) error {
	type sub struct {
		id, user  uuid.UUID
		name, tz  string
		status    string
		next      *time.Time
		trial     *time.Time
		reminders []int16
	}
	var list []sub
	if err := s.DB.WithSystemTx(ctx, func(tx pgx.Tx) error {
		rows, err := tx.Query(ctx, `select s.id, s.user_id, s.name, p.timezone, s.status, s.next_renewal_date, s.trial_ends_on, s.reminder_days_before
			from subscriptions s join users u on u.id = s.user_id join user_preferences p on p.user_id = s.user_id
			where s.status in ('trial','active') and u.status = 'active' order by s.id limit 5000`)
		if err != nil {
			return err
		}
		list, err = pgx.CollectRows(rows, func(r pgx.CollectableRow) (sub, error) {
			var x sub
			err := r.Scan(&x.id, &x.user, &x.name, &x.tz, &x.status, &x.next, &x.trial, &x.reminders)
			return x, err
		})
		return err
	}); err != nil {
		return err
	}
	for _, x := range list {
		if err := s.DB.WithSystemTx(ctx, func(tx pgx.Tx) error {
			return s.renewOne(ctx, tx, x.id, x.user, x.name, x.tz, x.status, x.next, x.trial, x.reminders)
		}); err != nil {
			return err
		}
	}
	return nil
}

func (s *Service) renewOne(ctx context.Context, tx pgx.Tx, id, user uuid.UUID, name, tz, status string, next, trial *time.Time, reminders []int16) error {
	today := localToday(s.now(), tz)
	if status == "trial" && trial != nil {
		window := 3
		for _, d := range reminders {
			window = max(window, int(d))
		}
		switch {
		case trial.Before(today):
			// The trial ended: the subscription is expected to renew as paid.
			if _, err := tx.Exec(ctx, `update subscriptions set status = 'active' where id = $1 and status = 'trial'`, id); err != nil {
				return err
			}
		case !trial.After(today.AddDate(0, 0, window)):
			_, created, err := notifications.Create(ctx, tx, notifications.Notification{UserID: user, Category: "subscription",
				EventType: "trial_ending", Title: name + " trial ends " + human(*trial, today), Priority: "high",
				Body: "Decide whether to keep it. Montra does not cancel subscriptions for you.", DeepLink: "/subscriptions/" + id.String(),
				EntityType: "subscription", EntityID: &id, DedupeKey: "trial:" + id.String() + ":" + finance.LocalDateString(*trial)})
			if err != nil {
				return err
			}
			if created {
				if err := event(ctx, tx, id, user, "trial_ending", nil, nil, nil, today, "", ""); err != nil {
					return err
				}
			}
		}
	}
	if next != nil && next.Before(today) {
		if err := s.advanceRenewal(ctx, tx, id, tz); err != nil {
			return err
		}
		if err := tx.QueryRow(ctx, `select next_renewal_date from subscriptions where id = $1`, id).Scan(&next); err != nil {
			return err
		}
	}
	if next == nil || status == "trial" {
		return nil
	}
	for _, d := range reminders {
		if !next.AddDate(0, 0, -int(d)).After(today) {
			_, _, err := notifications.Create(ctx, tx, notifications.Notification{UserID: user, Category: "subscription",
				EventType: "renewal_due", Title: name + " renews " + human(*next, today), Body: "Review it in Subscriptions.",
				DeepLink: "/subscriptions/" + id.String(), EntityType: "subscription", EntityID: &id,
				DedupeKey: "renewal:" + id.String() + ":" + finance.LocalDateString(*next)})
			return err
		}
	}
	return nil
}

func human(d, today time.Time) string {
	switch n := int(dateOnly(d).Sub(today).Hours() / 24); n {
	case 0:
		return "today"
	case 1:
		return "tomorrow"
	default:
		return "on " + d.Format("2 Jan")
	}
}
