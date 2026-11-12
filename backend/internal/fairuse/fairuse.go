// Package fairuse publishes the fair-use limits that apply to everyone
// (spec §0.2, §17): Montra has no paid tiers, so the same limits and each
// user's own usage are shown transparently.
package fairuse

import (
	"context"
	"net/http"
	"time"

	"github.com/danielgtaylor/huma/v2"
	"github.com/jackc/pgx/v5"

	"montra/backend/internal/domain/statement"
	"montra/backend/internal/files"
	"montra/backend/internal/platform/caps"
	"montra/backend/internal/platform/config"
	"montra/backend/internal/platform/database"
	"montra/backend/internal/platform/httpx"
	"montra/backend/internal/platform/identity"
	"montra/backend/internal/platform/ratelimit"
	"montra/backend/internal/support"
)

// Service reports limits.
type Service struct {
	DB  *database.DB
	Cfg *config.Config
}

// RateLimit is one request-rate policy.
type RateLimit struct {
	Policy    string `json:"policy" enum:"default,auth,write,upload,ai,export,social"`
	PerMinute int    `json:"per_minute" doc:"Sustained requests per minute"`
	Burst     int    `json:"burst" doc:"Short bursts allowed above the sustained rate"`
}

// Limits are the fair-use limits plus the caller's usage.
type Limits struct {
	StorageQuotaBytes     int64       `json:"storage_quota_bytes" doc:"0 means no cap"`
	StorageUsedBytes      int64       `json:"storage_used_bytes"`
	MaxUploadBytes        int64       `json:"max_upload_bytes" doc:"Largest single file; some purposes are smaller"`
	ImportMaxRows         int         `json:"import_max_rows"`
	MaxOpenRecurringRules int         `json:"max_open_recurring_rules" doc:"Recurring rules that are not ended (bills' schedules included)"`
	MaxOpenBills          int         `json:"max_open_bills" doc:"Bills that are not archived"`
	MaxOpenSubscriptions  int         `json:"max_open_subscriptions" doc:"Subscriptions that are not cancelled"`
	MaxOpenGoals          int         `json:"max_open_goals" doc:"Goals that are not archived"`
	SupportRequestsPerDay int         `json:"support_requests_per_day"`
	RateLimits            []RateLimit `json:"rate_limits"`
	DeletionGraceDays     int         `json:"deletion_grace_days"`
	ExportDownloadDays    int         `json:"export_download_days" doc:"How long export and report downloads stay available"`
	AIRequestsPerDay      int         `json:"ai_requests_per_day" doc:"0 when AI is off"`
	Note                  string      `json:"note" doc:"English; localize with note_code"`
	NoteCode              string      `json:"note_code" enum:"fair_use_same_for_everyone" doc:"Stable code for note"`
}

func perMinute(p ratelimit.Policy) int { return int(time.Minute / p.Every) }

// Get returns the limits and the caller's usage.
func (s *Service) Get(ctx context.Context) (*Limits, error) {
	uid, err := identity.UserID(ctx)
	if err != nil {
		return nil, err
	}
	out := &Limits{
		StorageQuotaBytes: s.Cfg.Storage.UserQuotaBytes, MaxUploadBytes: s.Cfg.Storage.MaxUploadBytes, ImportMaxRows: statement.DefaultLimits.MaxRows,
		MaxOpenRecurringRules: caps.OpenRecurringRules, MaxOpenBills: caps.OpenBills,
		MaxOpenSubscriptions: caps.OpenSubscriptions, MaxOpenGoals: caps.OpenGoals,
		SupportRequestsPerDay: support.DailyCap, DeletionGraceDays: int(s.Cfg.Product.Retention.DeletionGrace / (24 * time.Hour)),
		ExportDownloadDays: int(s.Cfg.Product.Retention.ExportFiles / (24 * time.Hour)),
		Note:               "Every feature is free for everyone. These limits keep Montra fast and affordable to run; they are the same for all users.",
		NoteCode:           "fair_use_same_for_everyone",
	}
	if s.Cfg.AI.Provider != config.AIDisabled {
		out.AIRequestsPerDay = s.Cfg.AI.DailyRequestCap
	}
	for _, p := range []ratelimit.Policy{ratelimit.Default, ratelimit.Write, ratelimit.Upload, ratelimit.Export, ratelimit.Social, ratelimit.Auth} {
		out.RateLimits = append(out.RateLimits, RateLimit{Policy: p.Name, PerMinute: perMinute(p), Burst: p.Burst})
	}
	err = s.DB.WithUserReadTx(ctx, uid, func(tx pgx.Tx) error {
		var err error
		out.StorageUsedBytes, err = files.UsedBytes(ctx, tx, uid)
		return err
	})
	return out, database.MapError(err)
}

// Routes mounts the limits endpoint.
func (s *Service) Routes(api huma.API) {
	httpx.Protected(api, httpx.Op("limits-get", http.MethodGet, "/limits", "Fair-use limits (the same for everyone) and your usage", "Reference"),
		func(ctx context.Context, _ *struct{}) (*httpx.Response[Limits], error) {
			l, err := s.Get(ctx)
			if err != nil {
				return nil, err
			}
			return httpx.OK(ctx, *l), nil
		})
}
