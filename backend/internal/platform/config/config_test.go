package config

import (
	"strings"
	"testing"
)

func load(t *testing.T, extra map[string]string) error {
	t.Helper()
	vals := map[string]string{
		"DATABASE_URL": "postgres://unused/none?sslmode=verify-full", "DATA_ENCRYPTION_KEYS": "t1:KioqKioqKioqKioqKioqKioqKioqKioqKioqKioqKio=",
		"URL_SIGNING_KEY": "KioqKioqKioqKioqKioqKioqKioqKioqKioqKioqKio=", "STORAGE_PROVIDER": "disabled", "EMAIL_PROVIDER": "smtp", "SMTP_HOST": "smtp.invalid",
	}
	for k, v := range extra {
		vals[k] = v
	}
	_, err := LoadFrom(func(k string) (string, bool) { v, ok := vals[k]; return v, ok })
	return err
}

// The email-verification bypass exists only for local development, and
// verification can never be switched off in staging or production.
func TestEmailVerificationBypassIsDevelopmentOnly(t *testing.T) {
	if err := load(t, map[string]string{"APP_ENV": "development", "AUTH_DEV_AUTO_VERIFY_EMAIL": "true", "AUTH_COOKIE_SECURE": "false"}); err != nil {
		t.Fatalf("development bypass refused: %v", err)
	}
	for _, env := range []string{"test", "staging", "production"} {
		err := load(t, map[string]string{"APP_ENV": env, "AUTH_DEV_AUTO_VERIFY_EMAIL": "true"})
		if err == nil || !strings.Contains(err.Error(), "AUTH_DEV_AUTO_VERIFY_EMAIL") {
			t.Fatalf("%s accepted the bypass: %v", env, err)
		}
	}
	for _, env := range []string{"staging", "production"} {
		err := load(t, map[string]string{"APP_ENV": env, "AUTH_REQUIRE_EMAIL_VERIFIED": "false"})
		if err == nil || !strings.Contains(err.Error(), "AUTH_REQUIRE_EMAIL_VERIFIED") {
			t.Fatalf("%s accepted unverified sign-in: %v", env, err)
		}
	}
	if err := load(t, map[string]string{"APP_ENV": "production"}); err != nil {
		t.Fatalf("plain production config rejected: %v", err)
	}
}

// The relaxed auth rate limit for end-to-end runs exists only in
// development and test, within bounds.
func TestDevAuthRateIsDevelopmentOnly(t *testing.T) {
	if err := load(t, map[string]string{"APP_ENV": "development", "AUTH_COOKIE_SECURE": "false", "AUTH_DEV_RATE_PER_MINUTE": "600"}); err != nil {
		t.Fatalf("development override refused: %v", err)
	}
	for _, env := range []string{"staging", "production"} {
		err := load(t, map[string]string{"APP_ENV": env, "AUTH_DEV_RATE_PER_MINUTE": "600"})
		if err == nil || !strings.Contains(err.Error(), "AUTH_DEV_RATE_PER_MINUTE") {
			t.Fatalf("%s accepted the override: %v", env, err)
		}
	}
	if err := load(t, map[string]string{"APP_ENV": "development", "AUTH_COOKIE_SECURE": "false", "AUTH_DEV_RATE_PER_MINUTE": "-1"}); err == nil {
		t.Fatal("negative override accepted")
	}
}

// Staging and production refuse database URLs that would not verify the
// server certificate and host name (DB-002); development and test are not
// checked, so local plaintext URLs keep working.
func TestDatabaseTLSRequiredOutsideDevelopment(t *testing.T) {
	t.Setenv("PGSSLMODE", "") // pgx reads it when a URL sets no sslmode
	weak := map[string]string{
		"no sslmode (prefer)":         "postgres://app:secret@db.example.com:5432/montra",
		"disable":                     "postgres://app:secret@db.example.com:5432/montra?sslmode=disable",
		"allow":                       "postgres://app:secret@db.example.com:5432/montra?sslmode=allow",
		"prefer":                      "postgres://app:secret@db.example.com:5432/montra?sslmode=prefer",
		"require":                     "postgres://app:secret@db.example.com:5432/montra?sslmode=require",
		"verify-ca":                   "postgres://app:secret@db.example.com:5432/montra?sslmode=verify-ca",
		"ssl=true alias (require)":    "postgres://app:secret@db.example.com:5432/montra?ssl=true",
		"keyword/value require":       "host=db.example.com user=app password=secret dbname=montra sslmode=require",
		"later sslmode wins (prefer)": "postgres://app:secret@db.example.com:5432/montra?sslmode=verify-full&sslmode=prefer",
	}
	for _, env := range []string{"staging", "production"} {
		for name, url := range weak {
			for _, key := range []string{"DATABASE_URL", "DATABASE_MIGRATION_URL"} {
				err := load(t, map[string]string{"APP_ENV": env, key: url})
				if err == nil || !strings.Contains(err.Error(), key+" must use sslmode=verify-full") {
					t.Fatalf("%s accepted %s for %s: %v", env, name, key, err)
				}
				if strings.Contains(err.Error(), "secret") || strings.Contains(err.Error(), "db.example.com") {
					t.Fatalf("error leaks the connection string: %v", err)
				}
			}
		}
		for _, url := range []string{
			"postgres://app:secret@db.example.com:5432/montra?sslmode=verify-full",
			"postgres://app:secret@db1.example.com:5432,db2.example.com:5432/montra?sslmode=verify-full",
			"host=db.example.com user=app password=secret dbname=montra sslmode=verify-full",
		} {
			if err := load(t, map[string]string{"APP_ENV": env, "DATABASE_URL": url, "DATABASE_MIGRATION_URL": url}); err != nil {
				t.Fatalf("%s rejected verify-full: %v", env, err)
			}
		}
		if err := load(t, map[string]string{"APP_ENV": env, "DATABASE_URL": "::not a url::"}); err == nil ||
			!strings.Contains(err.Error(), "DATABASE_URL could not be parsed") {
			t.Fatalf("%s accepted an unparseable URL: %v", env, err)
		}
	}
	// A URL without sslmode follows PGSSLMODE, as pgx does.
	t.Setenv("PGSSLMODE", "verify-full")
	if err := load(t, map[string]string{"APP_ENV": "production", "DATABASE_URL": "postgres://app:secret@db.example.com:5432/montra"}); err != nil {
		t.Fatalf("PGSSLMODE=verify-full rejected: %v", err)
	}
	t.Setenv("PGSSLMODE", "")
	for _, env := range []string{"development", "test"} {
		if err := load(t, map[string]string{"APP_ENV": env, "AUTH_COOKIE_SECURE": "false",
			"DATABASE_URL": "postgres://app:secret@localhost:5432/montra_dev?sslmode=disable", "DATABASE_MIGRATION_URL": "postgres://owner@localhost/montra_dev"}); err != nil {
			t.Fatalf("%s refused a local plaintext URL: %v", env, err)
		}
	}
}
