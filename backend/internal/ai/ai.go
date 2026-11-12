// Package ai implements Montra's optional, advisory AI features (spec
// §4.12, §20B.13, ADR-012): grounded questions over the user's own data,
// category suggestions, duplicate checks, forecasts and report summaries.
// Every number comes from deterministic services; the model only phrases
// and classifies over minimal, redacted context, through read-only tools,
// and its structured output is validated (facts must match tool results).
// AI needs the user's ai_processing consent and works free of charge under
// fair-use limits; with the provider off, deterministic answers are given.
package ai

import (
	"context"
	"crypto/hmac"
	"crypto/sha256"
	"encoding/hex"
	"errors"
	"net/http"
	"time"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"

	"montra/backend/internal/ai/llm"
	"montra/backend/internal/analytics"
	"montra/backend/internal/finance"
	"montra/backend/internal/platform/apperr"
	"montra/backend/internal/platform/audit"
	"montra/backend/internal/platform/database"
	"montra/backend/internal/platform/identity"
	"montra/backend/internal/platform/observability"
	"montra/backend/internal/subscriptions"
)

// ConsentVersion is the AI processing disclosure version users accept.
const ConsentVersion = "2026-11-01"

// Service implements AI features.
type Service struct {
	DB        *database.DB
	Provider  llm.Provider
	Analytics *analytics.Service
	Planning  *analytics.Planning
	Finance   *finance.Service
	Subs      *subscriptions.Service
	DailyCap  int
	MaxTokens int
	// RefKey derives the opaque per-user identifier sent to the provider.
	RefKey []byte
	Now    func() time.Time
	// Metrics records provider calls and estimated cost (optional).
	Metrics *observability.Metrics
}

func (s *Service) now() time.Time {
	if s.Now != nil {
		return s.Now()
	}
	return time.Now()
}

func (s *Service) provider() llm.Provider {
	if s.Provider == nil {
		return llm.Disabled{}
	}
	return s.Provider
}

// userRef is an HMAC of the user ID: stable for abuse monitoring, never
// reversible to a person.
func (s *Service) userRef(uid uuid.UUID) string {
	m := hmac.New(sha256.New, s.RefKey)
	m.Write(uid[:])
	return "u_" + hex.EncodeToString(m.Sum(nil))[:32]
}

// Disclosure explains AI processing before consent (spec §4.12).
type Disclosure struct {
	Provider      string   `json:"provider" doc:"anthropic or disabled"`
	Model         string   `json:"model,omitempty"`
	WhatIsSent    []string `json:"what_is_sent"`
	NeverSent     []string `json:"never_sent"`
	Retention     string   `json:"retention"`
	HowToDisable  string   `json:"how_to_disable"`
	ConsentType   string   `json:"consent_type"`
	ConsentVer    string   `json:"consent_version"`
	FairUsePerDay int      `json:"fair_use_requests_per_day" doc:"Free; the limit only protects stability"`
}

// AIPreferences is the caller's AI settings.
type AIPreferences struct {
	Enabled                  bool       `json:"enabled" doc:"AI features on (needs ai_processing consent)"`
	HistoryEnabled           bool       `json:"history_enabled" doc:"Keep your AI conversations (delete them any time)"`
	ReceiptExtraction        bool       `json:"receipt_extraction" doc:"AI may read receipt images you upload (needs ai_receipt_processing consent)"`
	ProviderConfigured       bool       `json:"provider_configured" doc:"false: AI is not available in this environment; deterministic answers are used"`
	ConsentGrantedAt         *time.Time `json:"consent_granted_at,omitempty"`
	ReceiptConsentGrantedAt  *time.Time `json:"receipt_consent_granted_at,omitempty"`
	Disclosure               Disclosure `json:"disclosure"`
	RequestsToday            int        `json:"requests_today"`
	StatementPDFExtractionOn bool       `json:"statement_pdf_extraction" doc:"PDF statements can be read by AI after you confirm each import"`
}

// AIPreferencesPatch changes AI settings.
type AIPreferencesPatch struct {
	Enabled        *bool `json:"enabled,omitempty" doc:"Turning on requires the ai_processing consent (POST /me/consents)"`
	HistoryEnabled *bool `json:"history_enabled,omitempty"`
}

func (s *Service) disclosure() Disclosure {
	p := s.provider()
	return Disclosure{Provider: p.Name(), Model: p.Model(),
		WhatIsSent: []string{"Your question", "Totals, category and merchant summaries, budgets, upcoming bills and goals computed by Montra for the period you ask about",
			"Transaction descriptions only when you ask for category suggestions (long numbers, emails and phone numbers masked)",
			"Receipt images and statement PDFs only after their separate consent and your confirmation"},
		NeverSent: []string{"Passwords, PINs, OTPs or card numbers", "Full account numbers", "Other people's data, including other group members' records",
			"Your name, email or phone number"},
		Retention: "Montra keeps your AI conversations only while history is on; delete them any time. The provider processes requests " +
			"under its API terms and does not use them to train models by default.",
		HowToDisable:  "Turn AI off here or revoke the ai_processing consent; every feature keeps working with deterministic results.",
		ConsentType:   "ai_processing",
		ConsentVer:    ConsentVersion,
		FairUsePerDay: s.cap(),
	}
}

func (s *Service) cap() int {
	if s.DailyCap <= 0 {
		return 200
	}
	return s.DailyCap
}

type gate struct {
	enabled, history, consent, receipt bool
}

func readGate(ctx context.Context, tx pgx.Tx, uid uuid.UUID) (gate, *time.Time, *time.Time, error) {
	var g gate
	var consentAt, receiptAt *time.Time
	err := tx.QueryRow(ctx, `select p.ai_enabled, p.ai_history_enabled,
		(select granted_at from user_consents where user_id = $1 and consent_type = 'ai_processing' and revoked_at is null order by granted_at desc limit 1),
		(select granted_at from user_consents where user_id = $1 and consent_type = 'ai_receipt_processing' and revoked_at is null order by granted_at desc limit 1)
		from user_preferences p where p.user_id = $1`, uid).Scan(&g.enabled, &g.history, &consentAt, &receiptAt)
	g.consent, g.receipt = consentAt != nil, receiptAt != nil
	return g, consentAt, receiptAt, err
}

// Preferences returns the caller's AI settings and the disclosure.
func (s *Service) Preferences(ctx context.Context) (*AIPreferences, error) {
	uid, err := identity.UserID(ctx)
	if err != nil {
		return nil, err
	}
	var out AIPreferences
	err = s.DB.WithUserReadTx(ctx, uid, func(tx pgx.Tx) error {
		g, ca, ra, err := readGate(ctx, tx, uid)
		if err != nil {
			return err
		}
		out = AIPreferences{Enabled: g.enabled && g.consent, HistoryEnabled: g.history, ReceiptExtraction: g.receipt && g.consent,
			ProviderConfigured: s.provider().Configured(), ConsentGrantedAt: ca, ReceiptConsentGrantedAt: ra, Disclosure: s.disclosure(),
			StatementPDFExtractionOn: s.provider().Configured() && g.consent}
		return tx.QueryRow(ctx, `select count(*) from ai_usage where user_id = $1 and created_at > now() - interval '1 day'`, uid).Scan(&out.RequestsToday)
	})
	if err != nil {
		return nil, database.MapError(err)
	}
	return &out, nil
}

// UpdatePreferences turns AI or history on or off.
func (s *Service) UpdatePreferences(ctx context.Context, in AIPreferencesPatch) (*AIPreferences, error) {
	uid, err := identity.UserID(ctx)
	if err != nil {
		return nil, err
	}
	err = s.DB.WithUserTx(ctx, uid, func(tx pgx.Tx) error {
		g, _, _, err := readGate(ctx, tx, uid)
		if err != nil {
			return err
		}
		if in.Enabled != nil {
			if *in.Enabled && !g.consent {
				return apperr.New(apperr.CodeConsentRequired, http.StatusForbidden,
					"Review the AI disclosure and grant the ai_processing consent first.")
			}
			if _, err := tx.Exec(ctx, `update user_preferences set ai_enabled = $2 where user_id = $1`, uid, *in.Enabled); err != nil {
				return err
			}
		}
		if in.HistoryEnabled != nil {
			if _, err := tx.Exec(ctx, `update user_preferences set ai_history_enabled = $2 where user_id = $1`, uid, *in.HistoryEnabled); err != nil {
				return err
			}
		}
		return audit.Record(ctx, tx, audit.Event{UserID: &uid, ActorUserID: &uid, EntityType: "ai_preferences", Action: "updated",
			Changes: map[string]any{"enabled": in.Enabled, "history_enabled": in.HistoryEnabled}})
	})
	if err != nil {
		return nil, database.MapError(err)
	}
	return s.Preferences(ctx)
}

// access says whether a model may be used for the caller now.
type access struct {
	model   bool // provider configured + AI on + consent
	history bool
	reason  string // why not, for deterministic responses
}

func (s *Service) check(ctx context.Context, tx pgx.Tx, uid uuid.UUID) (access, error) {
	g, _, _, err := readGate(ctx, tx, uid)
	if err != nil {
		return access{}, err
	}
	a := access{history: g.history}
	switch {
	case !s.provider().Configured():
		a.reason = "AI is not available in this environment, so this answer comes straight from your data."
	case !g.consent || !g.enabled:
		a.reason = "AI is off for your account, so this answer comes straight from your data. Turn it on in Settings → AI."
	default:
		var n int
		if err := tx.QueryRow(ctx, `select count(*) from ai_usage where user_id = $1 and created_at > now() - interval '1 day'`, uid).Scan(&n); err != nil {
			return a, err
		}
		if n >= s.cap() {
			a.reason = "You reached today's fair-use limit for AI, so this answer comes straight from your data."
		} else {
			a.model = true
		}
	}
	return a, nil
}

// record writes usage accounting (no prompts, answers or financial data).
func (s *Service) record(ctx context.Context, uid uuid.UUID, feature string, res *llm.Result, outcome string, latency time.Duration) {
	model := s.provider().Model()
	var in, out, cost int64
	if res != nil {
		if res.Model != "" {
			model = res.Model
		}
		in, out, cost = res.Usage.InputTokens+res.Usage.CacheReadTokens+res.Usage.CacheWriteTokens, res.Usage.OutputTokens, res.Usage.CostMicroUSD
	}
	if s.Metrics != nil {
		s.Metrics.ProviderCalls.WithLabelValues(s.provider().Name(), feature, outcome).Inc()
		s.Metrics.ProviderLatency.WithLabelValues(s.provider().Name(), feature).Observe(latency.Seconds())
		if cost > 0 {
			s.Metrics.AICostMicroUSD.WithLabelValues(model, feature).Add(float64(cost))
		}
	}
	rctx := context.WithoutCancel(ctx)
	_ = s.DB.WithUserTx(rctx, uid, func(tx pgx.Tx) error {
		_, err := tx.Exec(rctx, `insert into ai_usage (user_id, feature, provider, model, input_tokens, output_tokens, cost_micro_usd, latency_ms, outcome)
			values ($1,$2,$3,$4,$5,$6,$7,$8,$9)`, uid, feature, s.provider().Name(), model, min(in, 2_000_000_000), min(out, 2_000_000_000), cost,
			min(latency.Milliseconds(), 2_000_000_000), outcome)
		return err
	})
}

// outcomeOf maps a provider error to the usage outcome.
func outcomeOf(err error) string {
	switch {
	case err == nil:
		return "ok"
	case errors.Is(err, llm.ErrRateLimited):
		return "rate_limited"
	case errors.Is(err, llm.ErrRefused):
		return "blocked"
	case errors.Is(err, llm.ErrBadOutput), errors.Is(err, llm.ErrTruncated):
		return "rejected_output"
	default:
		return "provider_error"
	}
}

var errConfirm = apperr.FieldError("query.confirm", "Confirm that you want to delete all AI conversations.")
