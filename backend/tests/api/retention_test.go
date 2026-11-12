package api_test

import (
	"context"
	"fmt"
	"net/http"
	"testing"
	"time"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"

	"montra/backend/internal/app"
	"montra/backend/internal/platform/jobs"
	"montra/backend/internal/testutil/apitest"
)

// The hourly retention job enforces the configured windows (ADR-021):
// AI history, raw statement cells of finished imports and abandoned
// uploads; recent data is untouched.
func TestRetentionCleanupEnforcesConfiguredWindows(t *testing.T) {
	s := apitest.New(t, nil)
	addr := s.Register(t, "retain")
	c, _ := s.Login(t, addr)
	uid := userID(t, s, addr)
	acct := createAccount(t, c, map[string]any{"name": "Main", "account_type": "bank", "currency": "INR"})["id"].(string)

	oldConv, newConv := uuid.New(), uuid.New()
	s.Env.ExecWorker(t, `insert into ai_conversations (id, user_id, title, created_at, updated_at)
		values ($1,$3,'old',now() - interval '120 days',now() - interval '100 days'), ($2,$3,'recent',now(),now())`, oldConv, newConv, uid)
	oldBatch, newBatch, openBatch := uuid.New(), uuid.New(), uuid.New()
	s.Env.ExecWorker(t, `insert into import_batches (id, user_id, account_id, status, created_at) values
		($1,$4,$5,'completed',now() - interval '200 days'), ($2,$4,$5,'completed',now()), ($3,$4,$5,'preview_ready',now() - interval '200 days')`,
		oldBatch, newBatch, openBatch, uid, acct)
	s.Env.ExecWorker(t, `insert into import_rows (batch_id, user_id, row_number, raw) values
		($1,$4,1,'["2026-01-01","-10.00","Old"]'), ($2,$4,1,'["2026-11-01","-5.00","New"]'), ($3,$4,1,'["2026-01-02","-7.00","Open"]')`,
		oldBatch, newBatch, openBatch, uid)
	staleFile, freshFile := uuid.New(), uuid.New()
	s.Env.ExecWorker(t, `insert into files (id, owner_user_id, storage_area, provider, bucket, object_key, purpose, status, created_at) values
		($1,$3,'private','local_disk','montra','o'||substr(md5(random()::text),1,20),'receipt','pending_upload',now() - interval '2 days'),
		($2,$3,'private','local_disk','montra','o'||substr(md5(random()::text),1,20),'receipt','pending_upload',now())`, staleFile, freshFile, uid)

	ctx := context.Background()
	if err := s.Env.Worker.WithSystemTx(ctx, func(tx pgx.Tx) error {
		for _, jt := range []string{app.JobRetentionCleanup, "files.cleanup"} {
			if _, _, err := jobs.Enqueue(ctx, tx, jobs.Spec{Type: jt, DedupeKey: jt + ":" + fmt.Sprint(time.Now().UnixNano())}); err != nil {
				return err
			}
		}
		return nil
	}); err != nil {
		t.Fatal(err)
	}
	s.RunJobs(t)

	if n := workerCount(t, s, `select count(*) from ai_conversations where id = $1`, oldConv); n != 0 {
		t.Fatal("old AI conversation kept past the retention window")
	}
	if n := workerCount(t, s, `select count(*) from ai_conversations where id = $1`, newConv); n != 1 {
		t.Fatal("recent AI conversation deleted")
	}
	raw := func(batch uuid.UUID) string {
		return workerString(t, s, `select raw::text from import_rows where batch_id = $1`, batch)
	}
	if got := raw(oldBatch); got != "[]" {
		t.Fatalf("old finished import kept raw cells: %s", got)
	}
	if got := raw(newBatch); got == "[]" {
		t.Fatal("recent import lost its raw cells")
	}
	if got := raw(openBatch); got == "[]" {
		t.Fatal("an unfinished import lost its raw cells")
	}
	if st := workerString(t, s, `select status from files where id = $1`, staleFile); st != "rejected" {
		t.Fatalf("abandoned upload status: %s", st)
	}
	if st := workerString(t, s, `select status from files where id = $1`, freshFile); st != "pending_upload" {
		t.Fatalf("fresh upload status: %s", st)
	}
	// The import rows endpoint still works for a cleared batch.
	c.Do(t, http.MethodGet, "/imports/"+oldBatch.String()+"/rows", nil).Expect(t, http.StatusOK)
}
