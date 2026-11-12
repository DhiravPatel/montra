package app

import (
	"fmt"
	"os"
	"strings"
	"testing"

	"montra/backend/internal/platform/config"
	"montra/backend/internal/platform/jobs"
	"montra/backend/internal/platform/observability"
	"montra/backend/internal/platform/outbox"
)

// TestJobInventory checks that every scheduled job type has a handler and
// prints the inventory for docs/BACKGROUND_JOBS.md when
// MONTRA_PRINT_JOBS=1. Registration needs no database.
func TestJobInventory(t *testing.T) {
	vals := map[string]string{
		"APP_ENV": "test", "DATABASE_URL": "postgres://unused/none", "DATA_ENCRYPTION_KEYS": "t1:KioqKioqKioqKioqKioqKioqKioqKioqKioqKioqKio=",
		"URL_SIGNING_KEY": "KioqKioqKioqKioqKioqKioqKioqKioqKioqKioqKio=", "EMAIL_PROVIDER": "dev_mailbox", "STORAGE_PROVIDER": "local_disk",
		"STORAGE_LOCAL_DIR": t.TempDir(), "AUTH_COOKIE_SECURE": "false",
	}
	cfg, err := config.LoadFrom(func(k string) (string, bool) { v, ok := vals[k]; return v, ok })
	if err != nil {
		t.Fatal(err)
	}
	d := Deps{Cfg: cfg, Metrics: observability.New("montra-inventory"), Worker: true}
	svcs, err := NewServices(d)
	if err != nil {
		t.Fatal(err)
	}
	reg := jobs.NewRegistry()
	RegisterJobs(reg, svcs, nil)
	RegisterPlatformJobs(reg, d)
	relay := outbox.NewRelay(nil)
	RegisterOutboxRoutes(relay)

	handlers := map[string]jobs.HandlerInfo{}
	for _, h := range reg.Describe() {
		handlers[h.Type] = h
	}
	for _, p := range Periodic() {
		if _, ok := handlers[p.JobType]; !ok {
			t.Errorf("periodic %s enqueues %s, which has no handler", p.Name, p.JobType)
		}
	}
	if len(relay.Events()) == 0 {
		t.Error("no outbox routes registered")
	}
	if os.Getenv("MONTRA_PRINT_JOBS") != "1" {
		return
	}
	every := map[string]string{}
	for _, p := range Periodic() {
		every[p.JobType] = p.Every.String()
	}
	var b strings.Builder
	b.WriteString("| Job type | Schedule | Timeout | Concurrency |\n|---|---|---|---|\n")
	for _, h := range reg.Describe() {
		sched := every[h.Type]
		if sched == "" {
			sched = "on demand"
		}
		conc := "default"
		if h.Concurrency > 0 {
			conc = fmt.Sprint(h.Concurrency)
		}
		fmt.Fprintf(&b, "| `%s` | %s | %s | %s |\n", h.Type, sched, h.Timeout, conc)
	}
	b.WriteString("\nOutbox events with routes: `" + strings.Join(relay.Events(), "`, `") + "`\n")
	t.Log("\n" + b.String())
}
