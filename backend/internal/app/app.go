// Package app wires services, routes, middleware and job handlers. It is
// shared by cmd/api, cmd/worker and cmd/openapi (contract generation runs
// without a database: route registration never touches dependencies).
package app

import (
	"context"
	"encoding/json"
	"fmt"
	"net/http"
	"time"

	"github.com/danielgtaylor/huma/v2"
	"github.com/go-chi/chi/v5"

	"montra/backend/internal/admin"
	"montra/backend/internal/ai"
	"montra/backend/internal/ai/llm"
	"montra/backend/internal/analytics"
	"montra/backend/internal/auth"
	"montra/backend/internal/budgets"
	"montra/backend/internal/categories"
	"montra/backend/internal/challenges"
	"montra/backend/internal/communities"
	"montra/backend/internal/fairuse"
	"montra/backend/internal/files"
	"montra/backend/internal/finance"
	"montra/backend/internal/fx"
	"montra/backend/internal/goals"
	"montra/backend/internal/groups"
	"montra/backend/internal/imports"
	"montra/backend/internal/insights"
	"montra/backend/internal/integrations"
	"montra/backend/internal/moderation"
	"montra/backend/internal/notifications"
	"montra/backend/internal/platform/apperr"
	"montra/backend/internal/platform/breaker"
	"montra/backend/internal/platform/config"
	"montra/backend/internal/platform/crypto"
	"montra/backend/internal/platform/database"
	"montra/backend/internal/platform/email"
	"montra/backend/internal/platform/httpx"
	"montra/backend/internal/platform/identity"
	"montra/backend/internal/platform/jobs"
	"montra/backend/internal/platform/observability"
	"montra/backend/internal/platform/ratelimit"
	"montra/backend/internal/platform/storage"
	"montra/backend/internal/privacy"
	"montra/backend/internal/receipts"
	"montra/backend/internal/reconciliation"
	"montra/backend/internal/recurring"
	"montra/backend/internal/reports"
	"montra/backend/internal/search"
	"montra/backend/internal/social"
	"montra/backend/internal/subscriptions"
	"montra/backend/internal/support"
	"montra/backend/internal/users"
)

// Deps are process-level dependencies.
type Deps struct {
	Cfg     *config.Config
	DB      *database.DB // nil when generating the contract
	Metrics *observability.Metrics
	// AppDB is an RLS-enforcing (montra_app) pool for user-scoped reads in
	// the worker (report generation as the report owner). The API process
	// leaves it nil and uses DB, which is already the app role.
	AppDB *database.DB
	// Worker marks the worker process (DB is the RLS-bypassing worker role).
	Worker bool
}

// Services holds application services.
type Services struct {
	Keyring     *crypto.Keyring
	Auth        *auth.Service
	Users       *users.Service
	Store       storage.Store
	Files       *files.Service
	Notify      *notifications.Service
	Privacy     *privacy.Service
	Finance     *finance.Service
	Analytics   *analytics.Service
	Budgets     *budgets.Service
	Recurring   *recurring.Service
	Subs        *subscriptions.Service
	Goals       *goals.Service
	Imports     *imports.Service
	Receipts    *receipts.Service
	Recon       *reconciliation.Service
	FX          *fx.Service
	Reports     *reports.Service
	Social      *social.Service
	Groups      *groups.Service
	Communities *communities.Service
	Moderation  *moderation.Service
	Challenges  *challenges.Service
	AI          *ai.Service
	Insights    *insights.Service
	// Integrations has no provider adapters unless the owner registers one
	// with real credentials (ADR-016); the core works without them.
	Integrations *integrations.Service
	Search       *search.Service
	Support      *support.Service
	FairUse      *fairuse.Service
	Admin        *admin.Service
}

// NewServices constructs all services.
func NewServices(d Deps) (*Services, error) {
	if d.Metrics != nil {
		m := d.Metrics
		database.OnPermissionDenied(func() { m.RLSDenials.Inc() })
		breaker.SetObserver(m)
	}
	keys := make([]crypto.Key, 0, len(d.Cfg.Security.DataEncryptionKeys))
	for _, k := range d.Cfg.Security.DataEncryptionKeys {
		keys = append(keys, crypto.Key{ID: k.ID, Key: k.Key})
	}
	kr, err := crypto.NewKeyring(keys)
	if err != nil {
		return nil, err
	}
	s := &Services{Keyring: kr}
	s.Auth = auth.NewService(d.DB, d.Cfg, kr, d.Metrics)
	s.Auth.Initializer = []auth.UserInitializer{categories.SeedStarter}
	s.Users = &users.Service{DB: d.DB, Auth: s.Auth}
	store, err := storage.New(d.Cfg.Storage, d.Cfg.Env)
	if err != nil {
		return nil, err
	}
	s.Store = store
	s.Files = &files.Service{DB: d.DB, Store: store, Cfg: d.Cfg, Signer: s.Auth.Signer, Metrics: d.Metrics}
	s.Notify = &notifications.Service{DB: d.DB, Cfg: d.Cfg, Keyring: kr, Metrics: d.Metrics, Signer: s.Auth.Signer}
	// Push channels need owner-provided credentials (ADR-014); invalid
	// configuration fails start-up instead of silently dropping pushes.
	if d.Cfg.Push.VAPIDPrivateKey != "" {
		wp, err := notifications.NewWebPush(d.Cfg.Push.VAPIDPublicKey, d.Cfg.Push.VAPIDPrivateKey, d.Cfg.Push.VAPIDSubject, nil)
		if err != nil {
			return nil, err
		}
		s.Notify.WebPush = wp
	}
	if d.Cfg.Push.FCMProjectID != "" && d.Cfg.Push.FCMCredentials != "" {
		fcm, err := notifications.NewFCM(d.Cfg.Push.FCMProjectID, d.Cfg.Push.FCMCredentials, "")
		if err != nil {
			return nil, err
		}
		s.Notify.FCM = fcm
	}
	s.Privacy = &privacy.Service{DB: d.DB, Cfg: d.Cfg, Store: store, Files: s.Files, IPSalt: s.Auth.IPSalt(), Metrics: d.Metrics}
	s.Finance = &finance.Service{DB: d.DB}
	s.Analytics = &analytics.Service{DB: d.DB}
	s.Budgets = &budgets.Service{DB: d.DB}
	s.Recurring = &recurring.Service{DB: d.DB, Finance: s.Finance}
	s.Subs = &subscriptions.Service{DB: d.DB, Finance: s.Finance}
	s.Goals = &goals.Service{DB: d.DB}
	s.Imports = &imports.Service{DB: d.DB, Finance: s.Finance, Files: s.Files, Metrics: d.Metrics}
	s.Receipts = &receipts.Service{DB: d.DB, Files: s.Files, Finance: s.Finance, Extractor: receipts.NotConfigured{}}
	s.Recon = &reconciliation.Service{DB: d.DB, Finance: s.Finance}
	s.FX = &fx.Service{DB: d.DB, Cfg: d.Cfg.FX, Breaker: fx.NewBreaker()}
	s.Reports = &reports.Service{DB: d.DB, Files: s.Files, Store: store, Cfg: d.Cfg}
	s.Social = &social.Service{DB: d.DB}
	s.Groups = &groups.Service{DB: d.DB, Finance: s.Finance, Recurring: s.Recurring, WebAppURL: d.Cfg.HTTP.WebAppURL}
	s.Recurring.GroupPoster = s.Groups.PostDueRecurring
	s.Communities = &communities.Service{DB: d.DB, WebAppURL: d.Cfg.HTTP.WebAppURL}
	s.Moderation = &moderation.Service{DB: d.DB}
	s.Challenges = &challenges.Service{DB: d.DB}
	// AI is optional and off unless configured (ADR-012): every feature has
	// a deterministic path.
	var provider llm.Provider = llm.Disabled{}
	if d.Cfg.AI.Provider == config.AIAnthropic && d.Cfg.AI.APIKey != "" {
		provider = llm.WithBreaker(llm.NewAnthropic(llm.AnthropicConfig{APIKey: d.Cfg.AI.APIKey, Model: d.Cfg.AI.Model, Timeout: d.Cfg.AI.Timeout, Retries: 2}), nil)
	}
	s.AI = &ai.Service{DB: d.DB, Provider: provider, Analytics: s.Analytics,
		Planning: &analytics.Planning{Budgets: s.Budgets, Subs: s.Subs, Goals: s.Goals}, Finance: s.Finance, Subs: s.Subs,
		DailyCap: d.Cfg.AI.DailyRequestCap, MaxTokens: d.Cfg.AI.MaxOutputTokens, RefKey: []byte(s.Auth.IPSalt()), Metrics: d.Metrics}
	if provider.Configured() {
		s.Receipts.Extractor = ai.ReceiptExtractor{AI: s.AI}
	}
	s.Imports.PDF = ai.StatementReader{AI: s.AI}
	s.Insights = &insights.Service{DB: d.DB, Budgets: s.Budgets}
	s.Integrations = &integrations.Service{DB: d.DB, Finance: s.Finance, Keyring: kr, RedirectURL: d.Cfg.HTTP.WebAppURL}
	s.Privacy.Integrations = s.Integrations
	s.Search = &search.Service{DB: d.DB}
	s.FairUse = &fairuse.Service{DB: d.DB, Cfg: d.Cfg}
	s.Admin = &admin.Service{DB: d.DB}
	s.Support = &support.Service{DB: d.DB, Cfg: d.Cfg, Captcha: s.Auth.Captcha}
	// User-scoped report reads must go through the RLS-enforcing app role:
	// the API's own pool, or the worker's separate app-role pool. Without one
	// the worker refuses to generate reports (fail closed).
	if readDB := d.AppDB; readDB != nil || !d.Worker {
		if readDB == nil {
			readDB = d.DB
		}
		s.Reports.Readers = &reports.Readers{Analytics: &analytics.Service{DB: readDB}, Budgets: &budgets.Service{DB: readDB},
			Subs: &subscriptions.Service{DB: readDB, Finance: &finance.Service{DB: readDB}}, Goals: &goals.Service{DB: readDB}}
	}
	return s, nil
}

// RegisterRoutes mounts every API operation.
func RegisterRoutes(api huma.API, s *Services) {
	s.Auth.Routes(api)
	s.Users.Routes(api)
	s.Files.Routes(api)
	s.Notify.Routes(api)
	s.Privacy.Routes(api)
	s.Finance.Routes(api)
	s.Analytics.Routes(api, s.Finance)
	s.Analytics.CompareRoutes(api)
	s.Budgets.Routes(api, s.Finance)
	s.Recurring.Routes(api)
	s.Subs.Routes(api)
	s.Goals.Routes(api)
	s.Imports.Routes(api)
	s.Receipts.Routes(api)
	s.Recon.Routes(api)
	s.FX.Routes(api)
	s.Reports.Routes(api)
	s.Social.Routes(api)
	s.Groups.Routes(api)
	s.Communities.Routes(api)
	s.Moderation.Routes(api)
	s.Challenges.Routes(api)
	s.AI.Routes(api)
	s.Insights.Routes(api)
	s.Integrations.Routes(api)
	s.Search.Routes(api)
	s.FairUse.Routes(api)
	s.Admin.Routes(api)
	s.Support.Routes(api)
	s.Analytics.PlanningRoutes(api, &analytics.Planning{Budgets: s.Budgets, Subs: s.Subs, Goals: s.Goals})
	s.Analytics.PlanningCardRoutes(api, &analytics.PlanningCards{Budgets: s.Budgets, Goals: s.Goals, Recurring: s.Recurring, Groups: s.Groups})
}

// NewRouter builds the HTTP handler: global middleware, health, metrics and
// the versioned API.
func NewRouter(d Deps, s *Services) (http.Handler, huma.API) {
	cfg := d.Cfg
	r := chi.NewRouter()
	r.Use(httpx.RequestID)
	r.Use(httpx.ClientContext(cfg.HTTP.TrustProxyHeaders))
	r.Use(httpx.Recoverer)
	r.Use(httpx.AccessLog(d.Metrics))
	r.Use(httpx.SecurityHeaders(cfg.IsProduction()))
	r.Use(httpx.CORS(cfg.HTTP.CORSAllowedOrigins))
	r.Use(httpx.BodyLimit(cfg.Storage.MaxUploadBytes + (1 << 20)))
	r.Use(httpx.Timeout(cfg.HTTP.RequestTimeout, "/api/v1/files/"))

	r.Get("/health/live", func(w http.ResponseWriter, _ *http.Request) {
		writeJSON(w, http.StatusOK, map[string]any{"status": "ok"})
	})
	r.Get("/health/ready", readiness(d))
	if d.Metrics != nil {
		r.Handle("/metrics", d.Metrics.Handler(cfg.HTTP.MetricsToken))
	}
	r.NotFound(func(w http.ResponseWriter, r *http.Request) {
		httpx.WriteError(w, r, apperr.NotFound("route"))
	})

	var api huma.API
	httpx.SetCursorKey(cfg.Security.URLSigningKey)
	r.Route("/api/v1", func(sub chi.Router) {
		sub.Use(httpx.NoStore)
		sub.Use(httpx.SingleQueryValues)
		sub.Use(s.Auth.Authenticate)
		api = httpx.NewAPI(sub, cfg.HTTP.EnableDocs)
		var overrides []ratelimit.Policy
		if n := cfg.Auth.DevAuthRatePerMinute; n > 0 && cfg.IsDevelopmentLike() {
			overrides = append(overrides, ratelimit.Policy{Name: ratelimit.Auth.Name, Every: time.Minute / time.Duration(n), Burst: n})
		}
		limiter := ratelimit.New(overrides...)
		api.UseMiddleware(ratelimit.Middleware(api, limiter, rateSubject, func(ctx huma.Context, retry time.Duration) {
			ctx.SetHeader("Retry-After", httpx.RetryAfter(retry))
			e := apperr.RateLimited()
			_ = huma.WriteErr(api, ctx, e.Status, e.Message, e)
		}))
		api.UseMiddleware(s.Auth.RequireAuth(api))
		RegisterRoutes(api, s)
		httpx.DocumentConventions(api)
	})
	return r, api
}

func rateSubject(ctx huma.Context) string {
	if p, ok := identity.From(ctx.Context()); ok {
		return "u:" + p.UserID.String()
	}
	return "ip:" + httpx.Client(ctx.Context()).IP
}

// RegisterJobs registers worker job handlers.
func RegisterJobs(reg *jobs.Registry, s *Services, sender email.Sender) {
	s.Auth.RegisterJobs(reg, sender)
	s.Files.RegisterJobs(reg)
	s.Notify.RegisterJobs(reg, sender)
	s.Privacy.Sender = sender
	s.Privacy.RegisterJobs(reg)
	s.Budgets.RegisterJobs(reg)
	s.Recurring.RegisterJobs(reg)
	s.Subs.RegisterJobs(reg)
	s.Goals.RegisterJobs(reg)
	s.Imports.RegisterJobs(reg)
	s.Receipts.RegisterJobs(reg)
	s.FX.RegisterJobs(reg)
	s.Reports.RegisterJobs(reg)
	s.Social.RegisterJobs(reg)
	s.Groups.RegisterJobs(reg)
	s.Communities.RegisterJobs(reg)
	s.Moderation.RegisterJobs(reg)
	s.Challenges.RegisterJobs(reg)
	s.Insights.RegisterJobs(reg)
	s.Integrations.RegisterJobs(reg)
	s.Support.RegisterJobs(reg, sender)
}

// Periodic lists scheduler jobs (ADR-008).
func Periodic() []jobs.Periodic {
	return []jobs.Periodic{
		{Name: "retention.cleanup", Every: time.Hour, JobType: JobRetentionCleanup, Priority: 200},
		{Name: "files.cleanup", Every: time.Hour, JobType: files.JobCleanup, Priority: 200},
		{Name: "privacy.deletion_due", Every: 15 * time.Minute, JobType: privacy.JobDeletionDue, Priority: 60},
		{Name: "recurring.generate", Every: 15 * time.Minute, JobType: recurring.JobGenerate, Priority: 50},
		{Name: "subscriptions.renewals", Every: time.Hour, JobType: subscriptions.JobRenewals, Priority: 120},
		{Name: "subscriptions.detect_all", Every: 24 * time.Hour, JobType: subscriptions.JobDetectAll, Priority: 190},
		{Name: "goals.reminders", Every: 6 * time.Hour, JobType: goals.JobReminders, Priority: 150},
		{Name: "fx.refresh", Every: 6 * time.Hour, JobType: fx.JobRefresh, Priority: 170},
		{Name: "reports.schedules", Every: time.Hour, JobType: reports.JobSchedules, Priority: 160},
		{Name: "insights.generate_all", Every: 24 * time.Hour, JobType: insights.JobGenerateAll, Priority: 195},
		{Name: "notifications.digest_scan", Every: time.Hour, JobType: notifications.JobDigestScan, Priority: 165},
		{Name: "integrations.schedule", Every: 30 * time.Minute, JobType: integrations.JobSchedule, Priority: 140},
		{Name: "support.notify_staff", Every: time.Hour, JobType: support.JobNotifyStaff, Priority: 150},
		{Name: "groups.trip_reminders", Every: time.Hour, JobType: groups.JobTripReminders, Priority: 160},
	}
}

// Job types owned by the app package.
const (
	JobRetentionCleanup = "platform.retention_cleanup"
)

func readiness(d Deps) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		checks := map[string]any{}
		status := http.StatusOK
		if d.DB == nil {
			checks["database"] = "not_configured"
			status = http.StatusServiceUnavailable
		} else {
			ctx, cancel := context.WithTimeout(r.Context(), 2*time.Second)
			defer cancel()
			if err := d.DB.Ping(ctx); err != nil {
				checks["database"] = "unavailable"
				status = http.StatusServiceUnavailable
			} else {
				checks["database"] = "ok"
			}
		}
		checks["storage"] = storageStatus(d.Cfg)
		checks["email"] = d.Cfg.Email.Provider
		checks["ai"] = d.Cfg.AI.Provider
		checks["environment"] = d.Cfg.Env
		label := "ok"
		if status != http.StatusOK {
			label = "unavailable"
		}
		writeJSON(w, status, map[string]any{"status": label, "version": d.Cfg.Version, "checks": checks})
	}
}

func storageStatus(cfg *config.Config) string {
	switch cfg.Storage.Provider {
	case config.StorageLocalDisk:
		return "local_disk (development only — not Appwrite)"
	case config.StorageAppwrite:
		return "appwrite (configured; live connectivity verified only in hosted environments)"
	default:
		return "disabled"
	}
}

func writeJSON(w http.ResponseWriter, status int, v any) {
	w.Header().Set("Content-Type", "application/json")
	w.Header().Set("Cache-Control", "no-store")
	w.WriteHeader(status)
	if err := json.NewEncoder(w).Encode(v); err != nil {
		_, _ = fmt.Fprint(w, `{"status":"error"}`)
	}
}
