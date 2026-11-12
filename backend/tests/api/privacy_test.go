package api_test

import (
	"archive/zip"
	"bytes"
	"context"
	"io"
	"net/http"
	"strings"
	"testing"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"

	"montra/backend/internal/platform/email"
	"montra/backend/internal/testutil/apitest"
)

func ageReauth(s *apitest.Server, t *testing.T) {
	s.Env.ExecWorker(t, `update user_sessions set last_reauth_at = now() - interval '1 hour'`)
}

func TestDataExportContainsDataButNoSecrets(t *testing.T) {
	s := apitest.New(t, nil)
	addr := s.Register(t, "exporter")
	c, _ := s.Login(t, addr)
	ageReauth(s, t)
	c.Do(t, http.MethodPost, "/me/export", nil).Expect(t, http.StatusUnauthorized) // re-auth required
	c.Do(t, http.MethodPost, "/auth/reauthenticate", map[string]any{"password": apitest.Password}).Expect(t, http.StatusOK)
	e := c.Do(t, http.MethodPost, "/me/export", nil).Expect(t, http.StatusAccepted).Data()
	id := e["id"].(string)
	again := c.Do(t, http.MethodPost, "/me/export", nil).Expect(t, http.StatusAccepted).Data()
	if again["id"] != id {
		t.Fatal("concurrent export requests should reuse the in-progress export")
	}
	s.RunJobs(t)
	done := c.Do(t, http.MethodGet, "/me/export/"+id, nil).Expect(t, http.StatusOK).Data()
	if done["status"] != "completed" || done["file_id"] == nil {
		t.Fatalf("export not completed: %v", done)
	}
	// Another user cannot read this export.
	other, _ := s.Login(t, s.Register(t, "snoop"))
	other.Do(t, http.MethodGet, "/me/export/"+id, nil).Expect(t, http.StatusNotFound)
	other.Do(t, http.MethodGet, "/files/"+done["file_id"].(string)+"/access", nil).Expect(t, http.StatusNotFound)

	acc := c.Do(t, http.MethodGet, "/files/"+done["file_id"].(string)+"/access", nil).Expect(t, http.StatusOK).Data()
	resp, err := http.Get(strings.Replace(acc["url"].(string), s.Cfg.HTTP.PublicBaseURL, s.URL, 1))
	if err != nil {
		t.Fatal(err)
	}
	raw, _ := io.ReadAll(resp.Body)
	_ = resp.Body.Close()
	zr, err := zip.NewReader(bytes.NewReader(raw), int64(len(raw)))
	if err != nil {
		t.Fatalf("export is not a zip: %v", err)
	}
	names := map[string]string{}
	for _, f := range zr.File {
		rc, _ := f.Open()
		b, _ := io.ReadAll(rc)
		_ = rc.Close()
		names[f.Name] = string(b)
	}
	for _, want := range []string{"manifest.json", "account.json", "profile.json", "categories.json", "transactions.json", "consents.json"} {
		if _, ok := names[want]; !ok {
			t.Errorf("export missing %s", want)
		}
	}
	all := strings.Join(func() []string {
		var v []string
		for _, x := range names {
			v = append(v, x)
		}
		return v
	}(), "\n")
	for _, secret := range []string{"password_hash", "argon2id", "access_token_hash", "refresh_token_hash", "secret_ciphertext", "token_hash"} {
		if strings.Contains(all, secret) {
			t.Errorf("export leaks %s", secret)
		}
	}
	if !strings.Contains(names["categories.json"], "groceries") {
		t.Error("starter categories missing from export")
	}
	// Export-ready notification was created.
	list := c.Do(t, http.MethodGet, "/notifications", nil).Expect(t, http.StatusOK).List()
	found := false
	for _, n := range list {
		if n.(map[string]any)["event_type"] == "data_export_ready" {
			found = true
		}
	}
	if !found {
		t.Fatal("no export-ready notification")
	}
}

func TestAccountDeletionLifecycle(t *testing.T) {
	s := apitest.New(t, nil)
	addr := s.Register(t, "leaver")
	c, _ := s.Login(t, addr)
	friendAddr := s.Register(t, "stayer")

	// Shared group where the leaver is owner and the friend is a member.
	var leaverID, friendID uuid.UUID
	ctx := context.Background()
	_ = s.Env.Worker.WithSystemTx(ctx, func(tx pgx.Tx) error {
		_ = tx.QueryRow(ctx, `select id from users where email_normalized = $1`, strings.ToLower(addr)).Scan(&leaverID)
		return tx.QueryRow(ctx, `select id from users where email_normalized = $1`, strings.ToLower(friendAddr)).Scan(&friendID)
	})
	g := uuid.New()
	s.Env.ExecWorker(t, `insert into groups (id, created_by, name, group_type, base_currency, timezone) values ($1,$2,'Flat','roommates','INR','Asia/Kolkata')`, g, leaverID)
	s.Env.ExecWorker(t, `insert into group_members (group_id, user_id, role, joined_at) values ($1,$2,'owner', now() - interval '2 days'),($1,$3,'member', now() - interval '1 day')`, g, leaverID, friendID)
	exp := uuid.New()
	s.Env.ExecWorker(t, `insert into group_expenses (id, group_id, created_by, description, amount_minor, currency, expense_date, split_method, split_input)
		values ($1,$2,$3,'Rent',100000,'INR',current_date,'equal','{}')`, exp, g, leaverID)
	s.Env.ExecWorker(t, `insert into group_expense_shares (expense_id, group_id, user_id, share_minor, position) values ($1,$2,$3,50000,1),($1,$2,$4,50000,2)`, exp, g, leaverID, friendID)
	s.Env.ExecWorker(t, `insert into financial_accounts (user_id, name, account_type, currency, opening_date) values ($1,'Private','bank','INR',current_date)`, leaverID)

	st := c.Do(t, http.MethodGet, "/me/deletion-request", nil).Expect(t, http.StatusOK).Data()
	if st["status"] != "none" || len(st["group_impact"].([]any)) != 1 || len(st["retained"].([]any)) == 0 {
		t.Fatalf("disclosure incomplete: %v", st)
	}
	ageReauth(s, t)
	c.Do(t, http.MethodPost, "/me/deletion-request", map[string]any{"confirm": "DELETE"}).Expect(t, http.StatusUnauthorized)
	c.Do(t, http.MethodPost, "/auth/reauthenticate", map[string]any{"password": apitest.Password}).Expect(t, http.StatusOK)
	c.Do(t, http.MethodPost, "/me/deletion-request", map[string]any{"confirm": "nope"}).Expect(t, http.StatusUnprocessableEntity)
	r := c.Do(t, http.MethodPost, "/me/deletion-request", map[string]any{"confirm": "DELETE", "reason": "test"}).Expect(t, http.StatusOK).Data()
	if r["status"] != "scheduled" {
		t.Fatalf("status = %v", r["status"])
	}
	c.Do(t, http.MethodPost, "/me/deletion-request", map[string]any{"confirm": "DELETE"}).Expect(t, http.StatusConflict)
	c.Do(t, http.MethodDelete, "/me/deletion-request", nil).Expect(t, http.StatusOK)
	c.Do(t, http.MethodPost, "/me/deletion-request", map[string]any{"confirm": "DELETE"}).Expect(t, http.StatusOK)

	// Grace period elapses; the scheduler picks it up.
	s.Env.ExecWorker(t, `update account_deletion_requests set scheduled_for = now() - interval '1 minute' where status = 'scheduled' and user_id = $1`, leaverID)
	s.Env.ExecWorker(t, `insert into jobs (type, dedupe_key) values ('privacy.deletion_due', 'test-due-' || gen_random_uuid())`)
	s.RunJobs(t)
	s.RunJobs(t)

	c.Do(t, http.MethodGet, "/auth/session", nil).Expect(t, http.StatusUnauthorized)
	s.NewClient("android").Do(t, http.MethodPost, "/auth/login", map[string]any{"email": addr, "password": apitest.Password}).Expect(t, http.StatusUnauthorized)

	var status, display string
	var accounts, shares int
	var owner uuid.UUID
	_ = s.Env.Worker.WithSystemTx(ctx, func(tx pgx.Tx) error {
		_ = tx.QueryRow(ctx, `select status from users where id = $1`, leaverID).Scan(&status)
		_ = tx.QueryRow(ctx, `select display_name from profiles where user_id = $1`, leaverID).Scan(&display)
		_ = tx.QueryRow(ctx, `select count(*) from financial_accounts where user_id = $1`, leaverID).Scan(&accounts)
		_ = tx.QueryRow(ctx, `select count(*) from group_expense_shares where expense_id = $1`, exp).Scan(&shares)
		return tx.QueryRow(ctx, `select user_id from group_members where group_id = $1 and role = 'owner' and status = 'active'`, g).Scan(&owner)
	})
	if status != "deleted" || display != "Deleted member" || accounts != 0 {
		t.Fatalf("deletion incomplete: status=%s display=%s accounts=%d", status, display, accounts)
	}
	if shares != 2 {
		t.Fatalf("shared group shares must be retained for other members (got %d)", shares)
	}
	if owner != friendID {
		t.Fatalf("group ownership was not transferred to the remaining member")
	}
	// The email address is freed (anonymized) and a completion email was sent.
	sent := false
	for _, m := range s.Mail.Messages(addr) {
		if m.Category == email.TplDeletionDone {
			sent = true
		}
	}
	if !sent {
		t.Fatal("no deletion completion email")
	}
	s.NewClient("android").Do(t, http.MethodPost, "/auth/register", registerBody(addr, apitest.Password)).Expect(t, http.StatusAccepted)
}
