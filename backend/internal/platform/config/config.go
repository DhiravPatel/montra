// Package config loads and validates process configuration from environment
// variables. Configuration is validated once at startup; the process refuses
// to start with an invalid or unsafe configuration (for example a
// development-only adapter in production).
package config

import (
	"crypto/tls"
	"encoding/base64"
	"errors"
	"fmt"
	"net/url"
	"os"
	"strconv"
	"strings"
	"time"

	"github.com/jackc/pgx/v5/pgconn"
)

// Environment names.
const (
	EnvDevelopment = "development"
	EnvTest        = "test"
	EnvStaging     = "staging"
	EnvProduction  = "production"
)

// Storage providers.
const (
	StorageAppwrite  = "appwrite"
	StorageLocalDisk = "local_disk"
	StorageDisabled  = "disabled"
)

// Email providers.
const (
	EmailSMTP       = "smtp"
	EmailDevMailbox = "dev_mailbox"
	EmailDisabled   = "disabled"
)

// AI providers.
const (
	AIAnthropic = "anthropic"
	AIDisabled  = "disabled"
)

// Config is the complete validated process configuration.
type Config struct {
	Env         string
	ServiceName string
	Version     string
	LogLevel    string
	LogFormat   string

	HTTP     HTTPConfig
	Database DatabaseConfig
	Auth     AuthConfig
	Security SecurityConfig
	Storage  StorageConfig
	Email    EmailConfig
	Push     PushConfig
	AI       AIConfig
	FX       FXConfig
	Jobs     JobsConfig
	Product  ProductConfig
}

// HTTPConfig configures the API server.
type HTTPConfig struct {
	Addr               string
	PublicBaseURL      string // externally reachable API origin, e.g. https://api.montra.example
	WebAppURL          string // web portal origin used in emails and deep links
	CORSAllowedOrigins []string
	ReadTimeout        time.Duration
	WriteTimeout       time.Duration
	IdleTimeout        time.Duration
	RequestTimeout     time.Duration
	ShutdownTimeout    time.Duration
	MaxJSONBodyBytes   int64
	TrustProxyHeaders  bool
	EnableDocs         bool
	MetricsToken       string // optional bearer token protecting /metrics
}

// DatabaseConfig configures PostgreSQL connectivity.
type DatabaseConfig struct {
	URL              string // runtime role (montra_app or montra_worker)
	MigrationURL     string // owner role used only by cmd/migrate
	MaxConns         int32
	MinConns         int32
	MaxConnLifetime  time.Duration
	MaxConnIdleTime  time.Duration
	StatementTimeout time.Duration
	SimpleProtocol   bool // set when using a transaction-mode pooler
}

// AuthConfig configures sessions and credentials.
type AuthConfig struct {
	AccessTokenTTL       time.Duration
	RefreshTokenTTL      time.Duration
	RefreshAbsoluteTTL   time.Duration
	EmailVerificationTTL time.Duration
	PasswordResetTTL     time.Duration
	CookieDomain         string
	CookieSecure         bool
	RequireEmailVerified bool
	// DevAutoVerifyEmail marks accounts verified without an email
	// (APP_ENV=development only; refused anywhere else).
	DevAutoVerifyEmail bool
	// DevAuthRatePerMinute relaxes the per-IP auth rate limit (normally
	// ~10/min) for local end-to-end runs. 0 keeps the default; only
	// allowed when APP_ENV is development or test.
	DevAuthRatePerMinute int
	TurnstileSecretKey   string
	LoginMaxFailures     int
	LoginFailureWindow   time.Duration
	LoginLockoutDuration time.Duration
	ReauthWindow         time.Duration
	PasswordMinLength    int
	MFAIssuer            string
	AllowRegistration    bool
	MinimumAgeYears      int
}

// SecurityConfig holds key material.
type SecurityConfig struct {
	// DataEncryptionKeys is an ordered keyring "kid:base64key,kid2:base64key";
	// the first key encrypts, all keys decrypt (rotation support).
	DataEncryptionKeys []EncryptionKey
	// URLSigningKey signs short-lived download/upload URLs.
	URLSigningKey []byte
	// WebhookSecrets maps provider name to its webhook signing secret.
	WebhookSecrets map[string]string
}

// EncryptionKey is a single AES-256 key with a key ID.
type EncryptionKey struct {
	ID  string
	Key []byte
}

// StorageConfig configures object storage.
type StorageConfig struct {
	Provider          string
	LocalDir          string
	AppwriteEndpoint  string
	AppwriteProjectID string
	AppwriteAPIKey    string
	AppwriteTimeout   time.Duration
	Buckets           BucketNames
	SignedURLTTL      time.Duration
	MaxUploadBytes    int64
	// UserQuotaBytes caps one user's stored files (fair use; 0 = no cap).
	UserQuotaBytes int64
}

// BucketNames lists the logical storage areas (spec §4.9, §10).
type BucketNames struct {
	PrivateUser string
	Group       string
	PublicMedia string
	Temp        string
	Exports     string
}

// EmailConfig configures transactional email.
type EmailConfig struct {
	Provider     string
	From         string
	SMTPHost     string
	SMTPPort     int
	SMTPUsername string
	SMTPPassword string
	DevMailDir   string
}

// PushConfig configures web/native push.
type PushConfig struct {
	VAPIDPublicKey  string
	VAPIDPrivateKey string
	VAPIDSubject    string
	FCMProjectID    string
	FCMCredentials  string // path to service-account JSON
}

// AIConfig configures the AI provider.
type AIConfig struct {
	Provider        string
	APIKey          string
	Model           string
	VisionModel     string
	Timeout         time.Duration
	MaxOutputTokens int
	DailyRequestCap int
}

// FXConfig configures exchange-rate sourcing.
type FXConfig struct {
	Provider string // manual | ecb
	ECBURL   string
}

// JobsConfig configures the worker.
type JobsConfig struct {
	Concurrency     int
	PollInterval    time.Duration
	LeaseDuration   time.Duration
	MaxAttempts     int
	SchedulerEnable bool
}

// ProductConfig holds product-level settings.
type ProductConfig struct {
	SupportEmail    string
	SecurityEmail   string
	StatusPageURL   string
	DefaultLocale   string
	DefaultCurrency string
	DefaultTimezone string
	Retention       RetentionConfig
}

// RetentionConfig defines data retention windows (ADR-021).
type RetentionConfig struct {
	DeletionGrace  time.Duration
	TempFiles      time.Duration
	ExportFiles    time.Duration
	ImportRawRows  time.Duration
	SecurityEvents time.Duration
	AIHistory      time.Duration
}

// IsDevelopmentLike reports whether development-only adapters are allowed.
func (c *Config) IsDevelopmentLike() bool {
	return c.Env == EnvDevelopment || c.Env == EnvTest
}

// IsProduction reports whether the process runs in production.
func (c *Config) IsProduction() bool { return c.Env == EnvProduction }

// Load reads configuration from the environment and validates it.
func Load() (*Config, error) {
	return LoadFrom(os.LookupEnv)
}

// LookupFunc matches os.LookupEnv; injectable for tests.
type LookupFunc func(string) (string, bool)

type loader struct {
	lookup LookupFunc
	errs   []error
}

func (l *loader) str(key, def string) string {
	if v, ok := l.lookup(key); ok && strings.TrimSpace(v) != "" {
		return strings.TrimSpace(v)
	}
	return def
}

func (l *loader) required(key string) string {
	v := l.str(key, "")
	if v == "" {
		l.errs = append(l.errs, fmt.Errorf("%s is required", key))
	}
	return v
}

func (l *loader) integer(key string, def int) int {
	v := l.str(key, "")
	if v == "" {
		return def
	}
	n, err := strconv.Atoi(v)
	if err != nil {
		l.errs = append(l.errs, fmt.Errorf("%s must be an integer", key))
		return def
	}
	return n
}

func (l *loader) boolean(key string, def bool) bool {
	v := l.str(key, "")
	if v == "" {
		return def
	}
	b, err := strconv.ParseBool(v)
	if err != nil {
		l.errs = append(l.errs, fmt.Errorf("%s must be a boolean", key))
		return def
	}
	return b
}

func (l *loader) duration(key string, def time.Duration) time.Duration {
	v := l.str(key, "")
	if v == "" {
		return def
	}
	d, err := time.ParseDuration(v)
	if err != nil || d < 0 {
		l.errs = append(l.errs, fmt.Errorf("%s must be a non-negative duration (e.g. 15m)", key))
		return def
	}
	return d
}

func (l *loader) list(key string, def []string) []string {
	v := l.str(key, "")
	if v == "" {
		return def
	}
	var out []string
	for _, p := range strings.Split(v, ",") {
		if p = strings.TrimSpace(p); p != "" {
			out = append(out, p)
		}
	}
	return out
}

// LoadFrom builds a Config using the provided lookup function.
func LoadFrom(lookup LookupFunc) (*Config, error) {
	l := &loader{lookup: lookup}
	c := &Config{}

	c.Env = l.str("APP_ENV", EnvDevelopment)
	c.ServiceName = l.str("SERVICE_NAME", "montra-api")
	c.Version = l.str("APP_VERSION", "0.1.0-dev")
	c.LogLevel = l.str("LOG_LEVEL", "info")
	c.LogFormat = l.str("LOG_FORMAT", "json")

	c.HTTP = HTTPConfig{
		Addr:               l.str("HTTP_ADDR", ":8080"),
		PublicBaseURL:      l.str("PUBLIC_API_BASE_URL", "http://localhost:8080"),
		WebAppURL:          l.str("WEB_APP_URL", "http://localhost:5173"),
		CORSAllowedOrigins: l.list("CORS_ALLOWED_ORIGINS", []string{"http://localhost:5173"}),
		ReadTimeout:        l.duration("HTTP_READ_TIMEOUT", 15*time.Second),
		WriteTimeout:       l.duration("HTTP_WRITE_TIMEOUT", 60*time.Second),
		IdleTimeout:        l.duration("HTTP_IDLE_TIMEOUT", 120*time.Second),
		RequestTimeout:     l.duration("HTTP_REQUEST_TIMEOUT", 30*time.Second),
		ShutdownTimeout:    l.duration("HTTP_SHUTDOWN_TIMEOUT", 20*time.Second),
		MaxJSONBodyBytes:   int64(l.integer("HTTP_MAX_JSON_BODY_BYTES", 1<<20)),
		TrustProxyHeaders:  l.boolean("HTTP_TRUST_PROXY_HEADERS", false),
		EnableDocs:         l.boolean("HTTP_ENABLE_DOCS", false),
		MetricsToken:       l.str("METRICS_TOKEN", ""),
	}

	c.Database = DatabaseConfig{
		URL:              l.required("DATABASE_URL"),
		MigrationURL:     l.str("DATABASE_MIGRATION_URL", ""),
		MaxConns:         int32(l.integer("DATABASE_MAX_CONNS", 10)),
		MinConns:         int32(l.integer("DATABASE_MIN_CONNS", 1)),
		MaxConnLifetime:  l.duration("DATABASE_MAX_CONN_LIFETIME", 30*time.Minute),
		MaxConnIdleTime:  l.duration("DATABASE_MAX_CONN_IDLE_TIME", 5*time.Minute),
		StatementTimeout: l.duration("DATABASE_STATEMENT_TIMEOUT", 15*time.Second),
		SimpleProtocol:   l.boolean("DATABASE_SIMPLE_PROTOCOL", false),
	}

	c.Auth = AuthConfig{
		AccessTokenTTL:       l.duration("AUTH_ACCESS_TOKEN_TTL", 15*time.Minute),
		RefreshTokenTTL:      l.duration("AUTH_REFRESH_TOKEN_TTL", 30*24*time.Hour),
		RefreshAbsoluteTTL:   l.duration("AUTH_REFRESH_ABSOLUTE_TTL", 90*24*time.Hour),
		EmailVerificationTTL: l.duration("AUTH_EMAIL_VERIFICATION_TTL", 24*time.Hour),
		PasswordResetTTL:     l.duration("AUTH_PASSWORD_RESET_TTL", time.Hour),
		CookieDomain:         l.str("AUTH_COOKIE_DOMAIN", ""),
		CookieSecure:         l.boolean("AUTH_COOKIE_SECURE", true),
		RequireEmailVerified: l.boolean("AUTH_REQUIRE_EMAIL_VERIFIED", true),
		DevAutoVerifyEmail:   l.boolean("AUTH_DEV_AUTO_VERIFY_EMAIL", false),
		DevAuthRatePerMinute: l.integer("AUTH_DEV_RATE_PER_MINUTE", 0),
		TurnstileSecretKey:   l.str("TURNSTILE_SECRET_KEY", ""),
		LoginMaxFailures:     l.integer("AUTH_LOGIN_MAX_FAILURES", 5),
		LoginFailureWindow:   l.duration("AUTH_LOGIN_FAILURE_WINDOW", 15*time.Minute),
		LoginLockoutDuration: l.duration("AUTH_LOGIN_LOCKOUT", 15*time.Minute),
		ReauthWindow:         l.duration("AUTH_REAUTH_WINDOW", 10*time.Minute),
		PasswordMinLength:    l.integer("AUTH_PASSWORD_MIN_LENGTH", 10),
		MFAIssuer:            l.str("AUTH_MFA_ISSUER", "Montra"),
		AllowRegistration:    l.boolean("AUTH_ALLOW_REGISTRATION", true),
		MinimumAgeYears:      l.integer("AUTH_MINIMUM_AGE_YEARS", 18),
	}

	c.Security.DataEncryptionKeys = parseKeyring(l, "DATA_ENCRYPTION_KEYS")
	c.Security.URLSigningKey = decodeKey(l, "URL_SIGNING_KEY", 32)
	c.Security.WebhookSecrets = parseMap(l.str("WEBHOOK_SECRETS", ""))

	c.Storage = StorageConfig{
		Provider:          l.str("STORAGE_PROVIDER", StorageLocalDisk),
		LocalDir:          l.str("STORAGE_LOCAL_DIR", ".data/storage"),
		AppwriteEndpoint:  l.str("APPWRITE_ENDPOINT", ""),
		AppwriteProjectID: l.str("APPWRITE_PROJECT_ID", ""),
		AppwriteAPIKey:    l.str("APPWRITE_API_KEY", ""),
		AppwriteTimeout:   l.duration("APPWRITE_TIMEOUT", 30*time.Second),
		Buckets: BucketNames{
			PrivateUser: l.str("APPWRITE_BUCKET_PRIVATE", "private-user-docs"),
			Group:       l.str("APPWRITE_BUCKET_GROUP", "group-docs"),
			PublicMedia: l.str("APPWRITE_BUCKET_PUBLIC_MEDIA", "public-media"),
			Temp:        l.str("APPWRITE_BUCKET_TEMP", "temp-processing"),
			Exports:     l.str("APPWRITE_BUCKET_EXPORTS", "exports"),
		},
		SignedURLTTL:   l.duration("STORAGE_SIGNED_URL_TTL", 5*time.Minute),
		MaxUploadBytes: int64(l.integer("STORAGE_MAX_UPLOAD_BYTES", 20<<20)),
		UserQuotaBytes: int64(l.integer("STORAGE_USER_QUOTA_BYTES", 2<<30)),
	}

	c.Email = EmailConfig{
		Provider:     l.str("EMAIL_PROVIDER", EmailDevMailbox),
		From:         l.str("EMAIL_FROM", "Montra <no-reply@montra.example>"),
		SMTPHost:     l.str("SMTP_HOST", ""),
		SMTPPort:     l.integer("SMTP_PORT", 587),
		SMTPUsername: l.str("SMTP_USERNAME", ""),
		SMTPPassword: l.str("SMTP_PASSWORD", ""),
		DevMailDir:   l.str("DEV_MAIL_DIR", ".data/mail"),
	}

	c.Push = PushConfig{
		VAPIDPublicKey:  l.str("VAPID_PUBLIC_KEY", ""),
		VAPIDPrivateKey: l.str("VAPID_PRIVATE_KEY", ""),
		VAPIDSubject:    l.str("VAPID_SUBJECT", ""),
		FCMProjectID:    l.str("FCM_PROJECT_ID", ""),
		FCMCredentials:  l.str("FCM_CREDENTIALS_FILE", ""),
	}

	c.AI = AIConfig{
		Provider:        l.str("AI_PROVIDER", AIDisabled),
		APIKey:          l.str("ANTHROPIC_API_KEY", ""),
		Model:           l.str("AI_MODEL", "claude-opus-5-5"),
		VisionModel:     l.str("AI_VISION_MODEL", "claude-opus-5-5"),
		Timeout:         l.duration("AI_TIMEOUT", 45*time.Second),
		MaxOutputTokens: l.integer("AI_MAX_OUTPUT_TOKENS", 1500),
		DailyRequestCap: l.integer("AI_DAILY_REQUEST_CAP_PER_USER", 200),
	}

	c.FX = FXConfig{
		Provider: l.str("FX_PROVIDER", "manual"),
		ECBURL:   l.str("FX_ECB_URL", "https://www.ecb.europa.eu/stats/eurofxref/eurofxref-daily.xml"),
	}

	c.Jobs = JobsConfig{
		Concurrency:     l.integer("WORKER_CONCURRENCY", 4),
		PollInterval:    l.duration("WORKER_POLL_INTERVAL", time.Second),
		LeaseDuration:   l.duration("WORKER_LEASE_DURATION", 5*time.Minute),
		MaxAttempts:     l.integer("WORKER_MAX_ATTEMPTS", 8),
		SchedulerEnable: l.boolean("WORKER_SCHEDULER_ENABLED", true),
	}

	c.Product = ProductConfig{
		SupportEmail:    l.str("SUPPORT_EMAIL", "support@montra.example"),
		SecurityEmail:   l.str("SECURITY_EMAIL", "security@montra.example"),
		StatusPageURL:   l.str("STATUS_PAGE_URL", ""),
		DefaultLocale:   l.str("DEFAULT_LOCALE", "en-IN"),
		DefaultCurrency: l.str("DEFAULT_CURRENCY", "INR"),
		DefaultTimezone: l.str("DEFAULT_TIMEZONE", "Asia/Kolkata"),
		Retention: RetentionConfig{
			DeletionGrace:  l.duration("RETENTION_DELETION_GRACE", 7*24*time.Hour),
			TempFiles:      l.duration("RETENTION_TEMP_FILES", 24*time.Hour),
			ExportFiles:    l.duration("RETENTION_EXPORT_FILES", 7*24*time.Hour),
			ImportRawRows:  l.duration("RETENTION_IMPORT_RAW_ROWS", 180*24*time.Hour),
			SecurityEvents: l.duration("RETENTION_SECURITY_EVENTS", 365*24*time.Hour),
			AIHistory:      l.duration("RETENTION_AI_HISTORY", 90*24*time.Hour),
		},
	}

	c.validate(l)
	if len(l.errs) > 0 {
		return nil, errors.Join(l.errs...)
	}
	return c, nil
}

func (c *Config) validate(l *loader) {
	switch c.Env {
	case EnvDevelopment, EnvTest, EnvStaging, EnvProduction:
	default:
		l.errs = append(l.errs, fmt.Errorf("APP_ENV must be one of development, test, staging, production"))
	}
	switch c.Storage.Provider {
	case StorageAppwrite:
		if c.Storage.AppwriteEndpoint == "" || c.Storage.AppwriteProjectID == "" || c.Storage.AppwriteAPIKey == "" {
			l.errs = append(l.errs, errors.New("STORAGE_PROVIDER=appwrite requires APPWRITE_ENDPOINT, APPWRITE_PROJECT_ID and APPWRITE_API_KEY"))
		} else if u, err := url.Parse(c.Storage.AppwriteEndpoint); err != nil || u.Scheme != "https" {
			l.errs = append(l.errs, errors.New("APPWRITE_ENDPOINT must be an https URL"))
		}
	case StorageLocalDisk:
		if !c.IsDevelopmentLike() {
			l.errs = append(l.errs, errors.New("STORAGE_PROVIDER=local_disk is only allowed when APP_ENV is development or test"))
		}
	case StorageDisabled:
	default:
		l.errs = append(l.errs, errors.New("STORAGE_PROVIDER must be appwrite, local_disk or disabled"))
	}
	switch c.Email.Provider {
	case EmailSMTP:
		if c.Email.SMTPHost == "" {
			l.errs = append(l.errs, errors.New("EMAIL_PROVIDER=smtp requires SMTP_HOST"))
		}
	case EmailDevMailbox:
		if !c.IsDevelopmentLike() {
			l.errs = append(l.errs, errors.New("EMAIL_PROVIDER=dev_mailbox is only allowed when APP_ENV is development or test"))
		}
	case EmailDisabled:
		if c.Auth.RequireEmailVerified {
			l.errs = append(l.errs, errors.New("EMAIL_PROVIDER=disabled cannot be combined with AUTH_REQUIRE_EMAIL_VERIFIED=true (users could never verify)"))
		}
	default:
		l.errs = append(l.errs, errors.New("EMAIL_PROVIDER must be smtp, dev_mailbox or disabled"))
	}
	switch c.AI.Provider {
	case AIAnthropic:
		if c.AI.APIKey == "" {
			l.errs = append(l.errs, errors.New("AI_PROVIDER=anthropic requires ANTHROPIC_API_KEY"))
		}
	case AIDisabled:
	default:
		l.errs = append(l.errs, errors.New("AI_PROVIDER must be anthropic or disabled"))
	}
	switch c.FX.Provider {
	case "manual", "ecb":
	default:
		l.errs = append(l.errs, errors.New("FX_PROVIDER must be manual or ecb"))
	}
	if len(c.Security.DataEncryptionKeys) == 0 {
		l.errs = append(l.errs, errors.New("DATA_ENCRYPTION_KEYS is required (format kid:base64-32-byte-key)"))
	}
	if len(c.Security.URLSigningKey) == 0 {
		l.errs = append(l.errs, errors.New("URL_SIGNING_KEY is required (base64, 32 bytes)"))
	}
	if c.Auth.DevAuthRatePerMinute != 0 && !c.IsDevelopmentLike() {
		l.errs = append(l.errs, errors.New("AUTH_DEV_RATE_PER_MINUTE is only allowed when APP_ENV is development or test"))
	}
	if c.Auth.DevAuthRatePerMinute < 0 || c.Auth.DevAuthRatePerMinute > 6000 {
		l.errs = append(l.errs, errors.New("AUTH_DEV_RATE_PER_MINUTE must be between 0 and 6000"))
	}
	if c.Auth.DevAutoVerifyEmail && c.Env != EnvDevelopment {
		l.errs = append(l.errs, errors.New("AUTH_DEV_AUTO_VERIFY_EMAIL=true is only allowed when APP_ENV=development"))
	}
	if !c.IsDevelopmentLike() {
		if !c.Auth.RequireEmailVerified {
			l.errs = append(l.errs, errors.New("AUTH_REQUIRE_EMAIL_VERIFIED must be true outside development and test"))
		}
		if !c.Auth.CookieSecure {
			l.errs = append(l.errs, errors.New("AUTH_COOKIE_SECURE must be true outside development"))
		}
		for _, o := range c.HTTP.CORSAllowedOrigins {
			if o == "*" {
				l.errs = append(l.errs, errors.New("CORS_ALLOWED_ORIGINS must not contain * outside development"))
			}
		}
	}
	if c.Auth.PasswordMinLength < 10 || c.Auth.PasswordMinLength > 64 {
		// The contract advertises a 10-character minimum; the server may be stricter, never looser.
		l.errs = append(l.errs, errors.New("AUTH_PASSWORD_MIN_LENGTH must be between 10 and 64"))
	}
	if c.Jobs.Concurrency < 1 || c.Jobs.Concurrency > 64 {
		l.errs = append(l.errs, errors.New("WORKER_CONCURRENCY must be between 1 and 64"))
	}
	if c.Database.MaxConns < 1 {
		l.errs = append(l.errs, errors.New("DATABASE_MAX_CONNS must be at least 1"))
	}
	for _, db := range []struct{ key, url string }{{"DATABASE_URL", c.Database.URL}, {"DATABASE_MIGRATION_URL", c.Database.MigrationURL}} {
		if db.url == "" {
			continue
		}
		if err := CheckDatabaseTLS(c.Env, db.key, db.url); err != nil {
			l.errs = append(l.errs, err)
		}
	}
}

// CheckDatabaseTLS refuses, in staging and production, a PostgreSQL
// connection string (named by key in the error) that would not verify the
// server certificate and host name, i.e. anything weaker than
// sslmode=verify-full (DB-002, docs/DEPLOYMENT.md §1.1). It inspects the TLS
// settings pgx itself derives from the string, so a missing sslmode (pgx
// then uses PGSSLMODE, or prefer), the ssl=true alias (require) and every
// host of a multi-host string are judged as they would connect. There is no
// override. Development and test are not checked. The error never contains
// the connection string.
func CheckDatabaseTLS(env, key, dsn string) error {
	if env != EnvStaging && env != EnvProduction {
		return nil
	}
	cfg, err := pgconn.ParseConfig(dsn)
	if err != nil {
		return fmt.Errorf("%s could not be parsed to check its TLS settings (the value is not printed)", key)
	}
	verified := func(t *tls.Config) bool { return t != nil && !t.InsecureSkipVerify }
	ok := verified(cfg.TLSConfig)
	for _, fb := range cfg.Fallbacks {
		ok = ok && verified(fb.TLSConfig)
	}
	if ok {
		return nil
	}
	hint := ""
	if !strings.Contains(dsn, "sslmode") {
		hint = "; it sets no sslmode, so pgx would use PGSSLMODE or prefer"
	}
	return fmt.Errorf("%s must use sslmode=verify-full in %s (DB-002): it would not verify the server certificate and host name%s", key, env, hint)
}

func decodeKey(l *loader, key string, size int) []byte {
	v := l.str(key, "")
	if v == "" {
		return nil
	}
	b, err := base64.StdEncoding.DecodeString(v)
	if err != nil || len(b) != size {
		l.errs = append(l.errs, fmt.Errorf("%s must be base64 encoding of exactly %d bytes", key, size))
		return nil
	}
	return b
}

func parseKeyring(l *loader, key string) []EncryptionKey {
	v := l.str(key, "")
	if v == "" {
		return nil
	}
	var keys []EncryptionKey
	seen := map[string]bool{}
	for _, part := range strings.Split(v, ",") {
		part = strings.TrimSpace(part)
		id, b64, ok := strings.Cut(part, ":")
		if !ok || id == "" {
			l.errs = append(l.errs, fmt.Errorf("%s entries must be kid:base64key", key))
			return nil
		}
		b, err := base64.StdEncoding.DecodeString(b64)
		if err != nil || len(b) != 32 {
			l.errs = append(l.errs, fmt.Errorf("%s key %q must be base64 of 32 bytes", key, id))
			return nil
		}
		if seen[id] {
			l.errs = append(l.errs, fmt.Errorf("%s has duplicate key id %q", key, id))
			return nil
		}
		seen[id] = true
		keys = append(keys, EncryptionKey{ID: id, Key: b})
	}
	return keys
}

func parseMap(v string) map[string]string {
	out := map[string]string{}
	for _, part := range strings.Split(v, ",") {
		k, val, ok := strings.Cut(strings.TrimSpace(part), "=")
		if ok && k != "" && val != "" {
			out[k] = val
		}
	}
	return out
}
