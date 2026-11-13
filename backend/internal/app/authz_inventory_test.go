package app

import (
	"fmt"
	"net/http"
	"os"
	"sort"
	"strings"
	"testing"

	"github.com/danielgtaylor/huma/v2"

	"montra/backend/internal/platform/config"
	"montra/backend/internal/platform/httpx"
	"montra/backend/internal/platform/observability"
)

// publicOps are the only operations that may be called without a session.
// Adding a public operation must be a deliberate, reviewed change.
var publicOps = map[string]bool{
	"auth-register": true, "auth-login": true, "auth-refresh": true, "auth-mfa-verify": true, "auth-email-verify": true,
	"auth-email-resend": true, "auth-password-forgot": true, "auth-password-reset": true, "legal-versions": true,
	"currencies-list":           true,
	"files-download":            true, // signed, expiring URL bound to the requesting user (files-access)
	"notifications-unsubscribe": true, // signed, expiring token; optional categories only
	"webhooks-receive":          true, // provider signature verified by the adapter
	"support-contact":           true, // signed-out contact form: auth rate limit + captcha when configured
}

// staffOps are the only platform-staff operations, with the role each
// requires ("admin" admits admins only; "support" admits support and
// admins). Adding one must be a deliberate, reviewed change.
var staffOps = map[string]string{
	"admin-usage":                 "admin",
	"admin-jobs-list":             "admin", // JOB-007: operational job facts, never payloads
	"admin-jobs-get":              "admin",
	"admin-jobs-retry":            "admin", // audited, idempotent
	"support-queue":               "support",
	"support-queue-update":        "support",
	"moderation-platform-reports": "support",
	"moderation-platform-act":     "support",
	"moderation-platform-actions": "support",
	"moderation-platform-appeals": "support",
}

// TestAuthorizationInventory fails when an operation is public without being
// listed above, when a staff role differs from staffOps, or when a protected
// operation lacks security metadata, and
// prints docs/AUTHORIZATION_MATRIX.md's generated table when
// MONTRA_PRINT_AUTHZ=1.
func TestAuthorizationInventory(t *testing.T) {
	vals := map[string]string{
		"APP_ENV": "test", "DATABASE_URL": "postgres://unused/none", "DATA_ENCRYPTION_KEYS": "t1:KioqKioqKioqKioqKioqKioqKioqKioqKioqKioqKio=",
		"URL_SIGNING_KEY": "KioqKioqKioqKioqKioqKioqKioqKioqKioqKioqKio=", "EMAIL_PROVIDER": "dev_mailbox", "STORAGE_PROVIDER": "local_disk",
		"STORAGE_LOCAL_DIR": t.TempDir(), "AUTH_COOKIE_SECURE": "false",
	}
	cfg, err := config.LoadFrom(func(k string) (string, bool) { v, ok := vals[k]; return v, ok })
	if err != nil {
		t.Fatal(err)
	}
	d := Deps{Cfg: cfg, Metrics: observability.New("montra-authz")}
	svcs, err := NewServices(d)
	if err != nil {
		t.Fatal(err)
	}
	_, api := NewRouter(d, svcs)
	type row struct{ tag, method, path, id, auth, extra, rate string }
	var rows []row
	seenPublic, seenStaff := map[string]bool{}, map[string]bool{}
	for path, item := range api.OpenAPI().Paths {
		for _, op := range []struct {
			m   string
			hop *huma.Operation
		}{{http.MethodGet, item.Get}, {http.MethodPost, item.Post}, {http.MethodPut, item.Put}, {http.MethodPatch, item.Patch}, {http.MethodDelete, item.Delete}} {
			hop := op.hop
			if hop == nil {
				continue
			}
			auth, _ := hop.Metadata[httpx.MetaAuth].(string)
			switch auth {
			case "public":
				seenPublic[hop.OperationID] = true
				if !publicOps[hop.OperationID] {
					t.Errorf("%s %s (%s) is public but not in publicOps", op.m, path, hop.OperationID)
				}
			case "required":
				if len(hop.Security) == 0 {
					t.Errorf("%s %s is protected without security requirements", op.m, path)
				}
			default:
				t.Errorf("%s %s (%s) was registered without httpx.Public/Protected", op.m, path, hop.OperationID)
			}
			var extra []string
			role, _ := hop.Metadata[httpx.MetaRole].(string)
			if role != "" {
				extra = append(extra, "staff: "+role)
				seenStaff[hop.OperationID] = true
			}
			if want := staffOps[hop.OperationID]; want != role {
				t.Errorf("%s %s (%s) requires staff role %q; staffOps lists %q", op.m, path, hop.OperationID, role, want)
			}
			if r, _ := hop.Metadata[httpx.MetaReauth].(bool); r {
				extra = append(extra, "recent re-auth")
			}
			rate, _ := hop.Metadata[httpx.MetaRatePolicy].(string)
			if rate == "" {
				rate = "default"
			}
			tag := ""
			if len(hop.Tags) > 0 {
				tag = hop.Tags[0]
			}
			rows = append(rows, row{tag, op.m, path, hop.OperationID, auth, strings.Join(extra, ", "), rate})
		}
	}
	for id := range publicOps {
		if !seenPublic[id] {
			t.Errorf("publicOps lists %s, which is not a public operation", id)
		}
	}
	for id := range staffOps {
		if !seenStaff[id] {
			t.Errorf("staffOps lists %s, which is not a staff operation", id)
		}
	}
	if os.Getenv("MONTRA_PRINT_AUTHZ") != "1" {
		return
	}
	sort.Slice(rows, func(i, j int) bool {
		if rows[i].tag != rows[j].tag {
			return rows[i].tag < rows[j].tag
		}
		if rows[i].path != rows[j].path {
			return rows[i].path < rows[j].path
		}
		return rows[i].method < rows[j].method
	})
	var b strings.Builder
	tag := "\x00"
	for _, r := range rows {
		if r.tag != tag {
			tag = r.tag
			fmt.Fprintf(&b, "\n### %s\n\n| Method | Path | Operation | Session | Extra | Rate policy |\n|---|---|---|---|---|---|\n", tag)
		}
		fmt.Fprintf(&b, "| %s | `%s` | `%s` | %s | %s | %s |\n", r.method, r.path, r.id, r.auth, r.extra, r.rate)
	}
	t.Log("\n" + b.String())
}
