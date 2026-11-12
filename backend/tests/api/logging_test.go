package api_test

import (
	"bytes"
	"log/slog"
	"net/http"
	"strings"
	"sync"
	"testing"

	"github.com/google/uuid"

	"montra/backend/internal/platform/email"
	"montra/backend/internal/platform/logging"
	"montra/backend/internal/testutil/apitest"
)

type lockedBuffer struct {
	mu sync.Mutex
	b  bytes.Buffer
}

func (l *lockedBuffer) Write(p []byte) (int, error) {
	l.mu.Lock()
	defer l.mu.Unlock()
	return l.b.Write(p)
}

func (l *lockedBuffer) String() string {
	l.mu.Lock()
	defer l.mu.Unlock()
	return l.b.String()
}

// Logs (production logger, debug level) never contain credentials, tokens,
// email addresses, amounts or user-entered text, across API and worker
// flows including failures (spec §12, ADR-007).
func TestLogsNeverContainPersonalValues(t *testing.T) {
	buf := &lockedBuffer{}
	prev := slog.Default()
	slog.SetDefault(logging.New(buf, "debug", "json"))
	t.Cleanup(func() { slog.SetDefault(prev) })

	s := apitest.New(t, nil)
	tag := strings.ToUpper(uuid.NewString()[:6])
	secret := map[string]string{
		"description": "LEAKDESC" + tag, "notes": "LEAKNOTE" + tag, "merchant": "LEAKMERCH" + tag, "amount": "4321.77",
		"group": "LEAKGROUP" + tag, "expense": "LEAKEXP" + tag, "question": "LEAKQ" + tag, "hook": "LEAKHOOK" + tag,
		"account": "LEAKACCT" + tag, "password": apitest.Password,
	}
	addr := s.Register(t, "leakcheck")
	secret["email"] = addr
	c, refresh := s.Login(t, addr)
	secret["access"], secret["refresh"] = c.Bearer, refresh

	// Failures log too: wrong password, unknown user, invalid tokens.
	anon := s.NewClient("android")
	anon.Do(t, http.MethodPost, "/auth/login", map[string]any{"email": addr, "password": "Wrong-Pass-2026!"})
	anon.Do(t, http.MethodPost, "/auth/login", map[string]any{"email": "nobody." + tag + "@example.com", "password": "Wrong-Pass-2026!"})
	anon.Do(t, http.MethodPost, "/auth/password/forgot", map[string]any{"email": addr}).Expect(t, http.StatusAccepted)
	s.RunJobs(t)
	secret["reset"] = s.Mail.LatestToken(t, addr, email.TplPasswordReset)
	anon.Do(t, http.MethodPost, "/auth/password/reset", map[string]any{"token": secret["reset"] + "x", "new_password": "Brand-New-Pass-2026"})

	// Financial writes with user-entered text and amounts.
	acct := createAccount(t, c, map[string]any{"name": secret["account"], "account_type": "bank", "currency": "INR", "opening_balance": "1000"})["id"].(string)
	createTx(t, c, map[string]any{"type": "expense", "account_id": acct, "amount": secret["amount"], "description": secret["description"],
		"notes": secret["notes"], "merchant_name": secret["merchant"]})
	c.Do(t, http.MethodPost, "/transactions", map[string]any{"type": "expense", "account_id": acct, "amount": "-1", "description": secret["description"]},
		"Idempotency-Key", key())
	gid := createGroup(t, c, map[string]any{"name": secret["group"], "group_type": "friends", "base_currency": "INR"})["id"].(string)
	c.Do(t, http.MethodPost, "/groups/"+gid+"/expenses", map[string]any{"description": secret["expense"], "amount": "300", "split_method": "equal",
		"participants": []any{map[string]any{"user_id": userID(t, s, addr).String()}}, "payer_account_id": acct}, "Idempotency-Key", key()).
		Expect(t, http.StatusCreated)
	c.Do(t, http.MethodPost, "/ai/ask", map[string]any{"question": secret["question"] + " how much did I spend this month?"}).Expect(t, http.StatusOK)
	postWebhook(t, s, "nobody", []byte(`{"id":"`+secret["hook"]+`"}`), "t=1,v1=00")
	s.RunJobs(t)

	logs := buf.String()
	for _, want := range []string{"http request", "job finished", "/groups/{id}/expenses", "/webhooks/{provider}"} {
		if !strings.Contains(logs, want) {
			t.Fatalf("log capture is missing %q", want)
		}
	}
	for name, v := range secret {
		if v != "" && strings.Contains(logs, v) {
			i := strings.Index(logs, v)
			lo, hi := max(0, i-120), min(len(logs), i+len(v)+40)
			t.Errorf("logs contain the %s value: …%s…", name, logs[lo:hi])
		}
	}
}
