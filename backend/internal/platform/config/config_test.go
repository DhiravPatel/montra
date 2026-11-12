package config

import (
	"strings"
	"testing"
)

func load(t *testing.T, extra map[string]string) error {
	t.Helper()
	vals := map[string]string{
		"DATABASE_URL": "postgres://unused/none", "DATA_ENCRYPTION_KEYS": "t1:KioqKioqKioqKioqKioqKioqKioqKioqKioqKioqKio=",
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
