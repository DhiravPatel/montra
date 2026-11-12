package insights

import (
	"context"
	"net/http"
	"time"

	"github.com/danielgtaylor/huma/v2"
	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"

	"montra/backend/internal/notifications"
	"montra/backend/internal/platform/httpx"
	"montra/backend/internal/platform/jobs"
	"montra/backend/internal/platform/ratelimit"
)

// IDPath binds {id}.
type IDPath struct {
	ID uuid.UUID `path:"id"`
}

// GenerateResult reports a rules run.
type GenerateResult struct {
	Created  int          `json:"created"`
	Insights []InsightDTO `json:"insights"`
}

// Routes mounts insight endpoints.
func (s *Service) Routes(api huma.API) {
	const tag = "Insights"
	write := func(op huma.Operation) huma.Operation { return httpx.Rate(op, ratelimit.Write.Name) }

	httpx.Protected(api, httpx.Op("insights-list", http.MethodGet, "/insights",
		"Unusual activity and savings opportunities with their evidence (active by default; warnings first, then newest first)", tag),
		func(ctx context.Context, in *struct {
			All    bool   `query:"all" doc:"Include dismissed, expected, resolved and muted"`
			Kind   string `query:"kind" enum:"anomaly,savings,summary,forecast,budget,subscription,recurring,"`
			Cursor string `query:"cursor" maxLength:"512"`
			Limit  int    `query:"limit" minimum:"1" maximum:"200" default:"50"`
		}) (*httpx.Response[[]InsightDTO], error) {
			l, next, err := s.List(ctx, in.All, in.Kind, in.Cursor, in.Limit)
			if err != nil {
				return nil, err
			}
			return httpx.Page(ctx, l, next), nil
		})
	httpx.Protected(api, httpx.Op("insights-get", http.MethodGet, "/insights/{id}",
		"One of your insights in any status (for links from notifications)", tag),
		func(ctx context.Context, in *struct {
			ID uuid.UUID `path:"id"`
		}) (*httpx.Response[InsightDTO], error) {
			r, err := s.Get(ctx, in.ID)
			if err != nil {
				return nil, err
			}
			return httpx.OK(ctx, *r), nil
		})
	httpx.Protected(api, httpx.Rate(httpx.Op("ai-insights-generate", http.MethodPost, "/ai/insights/generate",
		"Check for unusual activity and savings opportunities now (deterministic rules; no AI provider needed)", tag), ratelimit.AI.Name),
		func(ctx context.Context, _ *struct{}) (*httpx.Response[GenerateResult], error) {
			n, l, err := s.GenerateNow(ctx)
			if err != nil {
				return nil, err
			}
			return httpx.OK(ctx, GenerateResult{Created: n, Insights: l}), nil
		})
	httpx.Protected(api, write(httpx.Op("insights-act", http.MethodPost, "/insights/{id}/actions",
		"Dismiss, snooze, mark expected or resolved, mute or reopen an insight (never changes your records)", tag)),
		func(ctx context.Context, in *struct {
			IDPath
			Body ActionInput
		}) (*httpx.Response[InsightDTO], error) {
			x, err := s.Act(ctx, in.ID, in.Body)
			if err != nil {
				return nil, err
			}
			return httpx.OK(ctx, *x), nil
		})
	httpx.Protected(api, write(httpx.Op("insights-feedback", http.MethodPost, "/insights/{id}/feedback",
		"Tell us whether an insight helped (one answer per insight; sending again updates it)", tag)),
		func(ctx context.Context, in *struct {
			IDPath
			Body FeedbackInput
		}) (*httpx.Response[InsightDTO], error) {
			x, err := s.Feedback(ctx, in.ID, in.Body)
			if err != nil {
				return nil, err
			}
			return httpx.OK(ctx, *x), nil
		})
	httpx.Protected(api, httpx.Op("insights-mutes-list", http.MethodGet, "/insights/mutes", "Kinds of insight you muted, and for which record", tag),
		func(ctx context.Context, _ *struct{}) (*httpx.Response[[]InsightMuteDTO], error) {
			l, err := s.Mutes(ctx)
			if err != nil {
				return nil, err
			}
			return httpx.OK(ctx, l), nil
		})
	httpx.Protected(api, write(httpx.Op("insights-unmute", http.MethodDelete, "/insights/mutes",
		"Stop muting a kind of insight; the insights it was hiding become active again", tag)),
		func(ctx context.Context, in *struct {
			Subtype string `query:"subtype" required:"true" minLength:"1" maxLength:"60"`
			Scope   string `query:"scope" maxLength:"64" doc:"Default * (all)"`
		}) (*httpx.Response[UnmuteResult], error) {
			scope := in.Scope
			if scope == "" {
				scope = "*"
			}
			r, err := s.Unmute(ctx, in.Subtype, scope)
			if err != nil {
				return nil, err
			}
			return httpx.OK(ctx, *r), nil
		})
}

// Job types.
const (
	JobGenerateAll = "insights.generate_all" // daily fan-out
	JobGenerate    = "insights.generate"     // one user
)

// RegisterJobs registers insight jobs.
func (s *Service) RegisterJobs(reg *jobs.Registry) {
	reg.Register(JobGenerateAll, func(ctx context.Context, _ jobs.Job) error { return s.fanOut(ctx) },
		jobs.WithTimeout(5*time.Minute), jobs.WithConcurrency(1))
	reg.Register(JobGenerate, func(ctx context.Context, j jobs.Job) error {
		var p struct {
			UserID uuid.UUID `json:"user_id"`
		}
		if err := j.Decode(&p); err != nil {
			return jobs.Permanent(err)
		}
		return s.generateAndNotify(ctx, p.UserID)
	}, jobs.WithTimeout(2*time.Minute), jobs.WithConcurrency(2))
}

func (s *Service) fanOut(ctx context.Context) error {
	day := s.now().UTC().Format("20060102")
	return s.DB.WithSystemTx(ctx, func(tx pgx.Tx) error {
		rows, err := tx.Query(ctx, `select distinct t.user_id from transactions t join users u on u.id = t.user_id
			where u.status = 'active' and t.created_at > now() - interval '35 days' limit 10000`)
		if err != nil {
			return err
		}
		ids, err := pgx.CollectRows(rows, pgx.RowTo[uuid.UUID])
		if err != nil {
			return err
		}
		for _, id := range ids {
			uid := id
			if _, _, err := jobs.Enqueue(ctx, tx, jobs.Spec{Type: JobGenerate, UserID: &uid, Payload: map[string]any{"user_id": uid},
				DedupeKey: "insights:" + uid.String() + ":" + day, Priority: 190}); err != nil {
				return err
			}
		}
		return nil
	})
}

// generateAndNotify runs the rules for one user (worker) and tells them
// about up to three new notable insights.
func (s *Service) generateAndNotify(ctx context.Context, uid uuid.UUID) error {
	started := s.now()
	return s.DB.WithSystemTx(ctx, func(tx pgx.Tx) error {
		n, err := s.Generate(ctx, tx, uid)
		if err != nil || n == 0 {
			return err
		}
		rows, err := tx.Query(ctx, `select id, title from insights where user_id = $1 and status = 'active' and severity in ('notice','warning')
			and created_at >= $2 order by created_at limit 3`, uid, started.Add(-time.Second))
		if err != nil {
			return err
		}
		type item struct {
			id    uuid.UUID
			title string
		}
		list, err := pgx.CollectRows(rows, func(r pgx.CollectableRow) (item, error) {
			var x item
			err := r.Scan(&x.id, &x.title)
			return x, err
		})
		if err != nil {
			return err
		}
		for _, x := range list {
			id := x.id
			if _, _, err := notifications.Create(ctx, tx, notifications.Notification{UserID: uid, Category: "insight", EventType: "insight_new",
				Title: "Something unusual in your spending", Body: "Open Insights to see what was noticed and why.", DeepLink: "/insights/" + id.String(),
				EntityType: "insight", EntityID: &id, DedupeKey: "insight:" + id.String()}); err != nil {
				return err
			}
		}
		return nil
	})
}
