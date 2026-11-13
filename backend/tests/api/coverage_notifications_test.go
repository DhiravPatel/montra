package api_test

import (
	"encoding/json"
	"net/http"
	"net/url"
	"slices"
	"strconv"
	"strings"
	"testing"
	"time"

	"github.com/google/uuid"

	"montra/backend/internal/integrations"
	"montra/backend/internal/notifications"
	"montra/backend/internal/testutil/apitest"
)

// Coverage for notification read state, push endpoint removal and the
// public provider webhook receiver.

func cvUnread(t *testing.T, c *apitest.Client) float64 {
	t.Helper()
	return c.Do(t, http.MethodGet, "/notifications/unread-count", nil).Expect(t, http.StatusOK).Data()["unread"].(float64)
}

func TestCoverageNotificationUpdateAndReadAll(t *testing.T) {
	s := apitest.New(t, nil)
	addr, otherAddr := s.Register(t, "cvnotes"), s.Register(t, "cvnotesother")
	c, _ := s.Login(t, addr)
	other, _ := s.Login(t, otherAddr)
	uid, oid := userID(t, s, addr), userID(t, s, otherAddr)
	mk := func(user uuid.UUID, title string) string {
		return notify(t, s, notifications.Notification{UserID: user, Category: "goal", EventType: "goal.milestone", Title: title,
			Body: "Keep going.", DeepLink: "/goals", Priority: "normal"}).String()
	}
	n1, n2, n3 := mk(uid, "One"), mk(uid, "Two"), mk(uid, "Three")
	theirs := mk(oid, "Theirs")
	if u := cvUnread(t, c); u != 3 {
		t.Fatalf("unread before = %v", u)
	}

	// Mark read, then unread again; the change is the caller's only.
	r := c.Do(t, http.MethodPatch, "/notifications/"+n1, map[string]any{"read": true}).Expect(t, http.StatusOK).Data()
	if r["id"] != n1 || r["read_at"] == nil || r["archived_at"] != nil || r["title"] != "One" {
		t.Fatalf("read = %v", r)
	}
	readAt := r["read_at"]
	if again := c.Do(t, http.MethodPatch, "/notifications/"+n1, map[string]any{"read": true}).Expect(t, http.StatusOK).Data(); again["read_at"] != readAt {
		t.Fatalf("marking read twice moved read_at: %v -> %v", readAt, again["read_at"])
	}
	if u := cvUnread(t, c); u != 2 {
		t.Fatalf("unread after one read = %v", u)
	}
	if ur := c.Do(t, http.MethodPatch, "/notifications/"+n1, map[string]any{"read": false}).Expect(t, http.StatusOK).Data(); ur["read_at"] != nil {
		t.Fatalf("unread = %v", ur)
	}
	// Archive hides it from the default list (shown with archived=true)
	// and from the badge; an empty patch changes nothing.
	ar := c.Do(t, http.MethodPatch, "/notifications/"+n2, map[string]any{"archived": true}).Expect(t, http.StatusOK).Data()
	if ar["archived_at"] == nil || ar["read_at"] != nil {
		t.Fatalf("archived = %v", ar)
	}
	if l := ids(c.Do(t, http.MethodGet, "/notifications", nil).Expect(t, http.StatusOK).List(), "id"); contains(l, n2) || len(l) != 2 {
		t.Fatalf("default list after archive = %v", l)
	}
	if l := ids(c.Do(t, http.MethodGet, "/notifications?archived=true", nil).Expect(t, http.StatusOK).List(), "id"); len(l) != 1 || l[0] != n2 {
		t.Fatalf("archived list = %v", l)
	}
	if u := cvUnread(t, c); u != 2 {
		t.Fatalf("unread after archive = %v", u)
	}
	if same := c.Do(t, http.MethodPatch, "/notifications/"+n3, map[string]any{}).Expect(t, http.StatusOK).Data(); same["read_at"] != nil || same["archived_at"] != nil {
		t.Fatalf("empty patch changed the notification: %v", same)
	}
	c.Do(t, http.MethodPatch, "/notifications/"+n2, map[string]any{"archived": false}).Expect(t, http.StatusOK)
	// Owner only; malformed ids are validation errors.
	c.Do(t, http.MethodPatch, "/notifications/"+theirs, map[string]any{"read": true}).Expect(t, http.StatusNotFound)
	c.Do(t, http.MethodPatch, "/notifications/"+uuid.NewString(), map[string]any{"read": true}).Expect(t, http.StatusNotFound)
	if res := c.Do(t, http.MethodPatch, "/notifications/nope", map[string]any{"read": true}); res.Status != http.StatusUnprocessableEntity {
		t.Fatalf("malformed id: %d", res.Status)
	}
	if res := c.Do(t, http.MethodPatch, "/notifications/"+n3, map[string]any{"read": "yes"}); res.Status != http.StatusUnprocessableEntity {
		t.Fatalf("non-boolean read: %d", res.Status)
	}

	// Read all: counts what changed, touches only the caller's unread ones,
	// and is idempotent.
	c.Do(t, http.MethodPatch, "/notifications/"+n3, map[string]any{"read": true}).Expect(t, http.StatusOK)
	if res := c.Do(t, http.MethodPost, "/notifications/read-all", nil).Expect(t, http.StatusOK).Data(); res["updated"] != float64(2) {
		t.Fatalf("read-all = %v", res)
	}
	if u := cvUnread(t, c); u != 0 {
		t.Fatalf("unread after read-all = %v", u)
	}
	if l := c.Do(t, http.MethodGet, "/notifications?unread=true", nil).Expect(t, http.StatusOK).List(); len(l) != 0 {
		t.Fatalf("unread list after read-all = %v", l)
	}
	if res := c.Do(t, http.MethodPost, "/notifications/read-all", nil).Expect(t, http.StatusOK).Data(); res["updated"] != float64(0) {
		t.Fatalf("second read-all = %v", res)
	}
	if u := cvUnread(t, other); u != 1 {
		t.Fatalf("another user's notifications were marked read: %v", u)
	}
	s.NewClient("android").Do(t, http.MethodPost, "/notifications/read-all", nil).Expect(t, http.StatusUnauthorized)
}

func TestCoveragePushEndpointDelete(t *testing.T) {
	s := apitest.New(t, nil)
	addr := s.Register(t, "cvpushdel")
	phone, _ := s.Login(t, addr)
	laptop, _ := s.Login(t, addr)
	other, _ := s.Login(t, s.Register(t, "cvpushdelother"))
	svc, ts, _ := webPushServer(t, s)
	ep1 := phone.Do(t, http.MethodPost, "/me/push-endpoints", webPushBody("Phone", ts.URL+"/push/one")).Expect(t, http.StatusCreated).Data()["id"].(string)
	ep2 := laptop.Do(t, http.MethodPost, "/me/push-endpoints", webPushBody("Laptop", ts.URL+"/push/two")).Expect(t, http.StatusCreated).Data()["id"].(string)
	goalNotification(t, s, addr, "Both devices")
	if n := len(svc.requests()); n != 2 {
		t.Fatalf("pushes before delete = %d", n)
	}

	// Other users cannot remove it; the owner can remove any of their own
	// endpoints, including one registered by another session.
	other.Do(t, http.MethodDelete, "/me/push-endpoints/"+ep1, nil).Expect(t, http.StatusNotFound)
	laptop.Do(t, http.MethodDelete, "/me/push-endpoints/"+ep1, nil).Expect(t, http.StatusOK)
	phone.Do(t, http.MethodDelete, "/me/push-endpoints/"+ep1, nil).Expect(t, http.StatusNotFound)
	if l := phone.Do(t, http.MethodGet, "/me/push-endpoints", nil).Expect(t, http.StatusOK).List(); len(l) != 1 || l[0].(map[string]any)["id"] != ep2 {
		t.Fatalf("endpoints after delete = %v", l)
	}
	if n := workerCount(t, s, `select count(*) from push_endpoints where id = $1`, ep1); n != 0 {
		t.Fatal("deleted endpoint still stored")
	}
	// The removed device gets nothing more; the other still does.
	goalNotification(t, s, addr, "Laptop only")
	if n := len(svc.requests()); n != 3 {
		t.Fatalf("pushes after delete = %d (want one more, to the laptop only)", n)
	}
	if res := phone.Do(t, http.MethodDelete, "/me/push-endpoints/nope", nil); res.Status != http.StatusUnprocessableEntity {
		t.Fatalf("malformed endpoint id: %d", res.Status)
	}
}

func TestCoverageWebhookReceive(t *testing.T) {
	s := apitest.New(t, nil)
	bank := &sandboxBank{secret: []byte("cv-webhook-secret"), ref: "sbx-" + uuid.NewString()[:8], pages: map[string]integrations.Batch{}}
	s.Svcs.Integrations.Register(bank)
	s.WorkerSvcs.Integrations.Register(bank)
	// The webhook inbox is shared by every test in this binary (other tests
	// count its quarantined rows), so this test removes what it stored.
	t.Cleanup(func() {
		s.Env.ExecWorker(t, `delete from integration_webhook_events where provider = 'sandbox_bank'
			and (event_id like 'evt\_cv\_%' or event_id like 'invalid:%')`)
	})
	alice := newPerson(t, s, "cvhookalice", nil)
	acct := createAccount(t, alice.c, map[string]any{"name": "Sandbox", "account_type": "savings", "currency": "INR"})["id"].(string)
	started := alice.c.Do(t, http.MethodPost, "/integrations/sandbox_bank/connect", map[string]any{"account_id": acct, "consent_confirm": true}).
		Expect(t, http.StatusCreated).Data()
	conn := started["connection_id"].(string)
	au, err := url.Parse(started["authorize_url"].(string))
	if err != nil {
		t.Fatal(err)
	}
	state := url.QueryEscape(au.Query().Get("state"))
	alice.c.Do(t, http.MethodGet, "/integrations/sandbox_bank/callback?state="+state+"&code=good-code", nil).Expect(t, http.StatusOK)
	s.RunJobs(t)
	runs := func() int {
		return workerCount(t, s, `select count(*) from integration_sync_runs where connection_id = $1 and trigger = 'webhook'`, conn)
	}

	// The provider calls without a session; the signature covers the exact bytes.
	provider := s.NewClient("web")
	hook := func(name string, body []byte, sig string) *apitest.Response {
		return provider.Do(t, http.MethodPost, "/webhooks/"+name, json.RawMessage(body), "Sandbox-Signature", sig)
	}
	evt := []byte(`{"id":"evt_cv_1","type":"transactions.updated","ref":"` + bank.ref + `"}`)
	if r := hook("sandbox_bank", evt, bank.sign(evt, time.Now())).Expect(t, http.StatusAccepted); r.Data()["status"] != "accepted" {
		t.Fatalf("webhook = %s", r.Raw)
	}
	if st := workerString(t, s, `select status from integration_webhook_events where event_id = 'evt_cv_1'`); st != "received" {
		t.Fatalf("stored event status = %s", st)
	}
	// Replays (same event id, even freshly signed) are acknowledged once.
	if r := hook("sandbox_bank", evt, bank.sign(evt, time.Now().Add(time.Second))).Expect(t, http.StatusAccepted); r.Data()["status"] != "duplicate" {
		t.Fatalf("replay = %s", r.Raw)
	}
	s.RunJobs(t)
	if st := workerString(t, s, `select status from integration_webhook_events where event_id = 'evt_cv_1'`); st != "processed" {
		t.Fatalf("processed event status = %s", st)
	}
	if n := runs(); n != 1 {
		t.Fatalf("webhook sync runs = %d", n)
	}
	// Verified events for unknown connections are stored and ignored.
	stray := []byte(`{"id":"evt_cv_2","type":"transactions.updated","ref":"someone-else"}`)
	hook("sandbox_bank", stray, bank.sign(stray, time.Now())).Expect(t, http.StatusAccepted)
	s.RunJobs(t)
	if st := workerString(t, s, `select status from integration_webhook_events where event_id = 'evt_cv_2'`); st != "ignored" {
		t.Fatalf("stray event status = %s", st)
	}
	if n := runs(); n != 1 {
		t.Fatalf("a stray event started a sync: %d", n)
	}
	// Missing, forged and stale signatures are answered 401 and quarantined.
	bad := []byte(`{"id":"evt_cv_3","type":"transactions.updated","ref":"` + bank.ref + `"}`)
	for _, sig := range []string{"", "t=1,v1=00", bank.sign(bad, time.Now().Add(-10*time.Minute))} {
		if r := hook("sandbox_bank", bad, sig); r.Status != http.StatusUnauthorized || r.ErrorCode() != "UNAUTHENTICATED" {
			t.Fatalf("bad signature %q: %d %s", sig, r.Status, r.Raw)
		}
	}
	if n := workerCount(t, s, `select count(*) from integration_webhook_events where provider = 'sandbox_bank' and status = 'quarantined'
		and not signature_valid`); n < 1 {
		t.Fatalf("quarantined events = %d", n)
	}
	// A body signed for one payload does not verify another.
	if r := hook("sandbox_bank", stray, bank.sign(evt, time.Now())); r.Status != http.StatusUnauthorized {
		t.Fatalf("signature over other bytes: %d", r.Status)
	}
	s.RunJobs(t)
	if n := runs(); n != 1 {
		t.Fatalf("an invalid webhook started a sync: %d", n)
	}
	// Unknown providers are not found; oversized bodies are refused.
	hook("nobody", evt, bank.sign(evt, time.Now())).Expect(t, http.StatusNotFound)
	big := []byte(`{"id":"evt_big","pad":"` + strings.Repeat("x", 300<<10) + `"}`)
	if r := hook("sandbox_bank", big, bank.sign(big, time.Now())); r.Status != http.StatusRequestEntityTooLarge {
		t.Fatalf("oversized webhook: %d", r.Status)
	}
}

// pageAll follows next_cursor from path (which already has a query) with
// the given page size and returns every id in page order.
func pageAll(t *testing.T, c *apitest.Client, path string, limit int) []string {
	t.Helper()
	var out []string
	cursor := ""
	for range 20 {
		p := path + "&limit=" + strconv.Itoa(limit)
		if cursor != "" {
			p += "&cursor=" + url.QueryEscape(cursor)
		}
		r := c.Do(t, http.MethodGet, p, nil).Expect(t, http.StatusOK)
		page := ids(r.List(), "id")
		if len(page) > limit {
			t.Fatalf("%s returned %d rows for limit %d", p, len(page), limit)
		}
		out = append(out, page...)
		cursor, _ = r.Body["meta"].(map[string]any)["next_cursor"].(string)
		if cursor == "" {
			return out
		}
	}
	t.Fatalf("%s did not finish paging", path)
	return nil
}

// The first page and cursor pages use separate SQL texts (query plan review
// R-F); paging must still return every row once, in the unpaged order.
func TestNotificationCursorPagingMatchesUnpagedList(t *testing.T) {
	s := apitest.New(t, nil)
	addr, otherAddr := s.Register(t, "cvpager"), s.Register(t, "cvpagerother")
	c, _ := s.Login(t, addr)
	uid, oid := userID(t, s, addr), userID(t, s, otherAddr)
	for i := range 5 {
		cat := "goal"
		if i%2 == 1 {
			cat = "bill"
		}
		notify(t, s, notifications.Notification{UserID: uid, Category: cat, EventType: cat + ".test", Title: "N" + strconv.Itoa(i),
			Body: "Body.", DeepLink: "/notifications", Priority: "normal"})
	}
	notify(t, s, notifications.Notification{UserID: oid, Category: "goal", EventType: "goal.test", Title: "Theirs", Body: "Body.", Priority: "normal"})
	for _, path := range []string{"/notifications?archived=false", "/notifications?category=goal"} {
		all := ids(c.Do(t, http.MethodGet, path+"&limit=100", nil).Expect(t, http.StatusOK).List(), "id")
		want := 5
		if strings.Contains(path, "goal") {
			want = 3
		}
		if len(all) != want {
			t.Fatalf("%s listed %d, want %d", path, len(all), want)
		}
		for _, size := range []int{1, 2} {
			if got := pageAll(t, c, path, size); !slices.Equal(got, all) {
				t.Fatalf("%s paged by %d = %v, want %v", path, size, got, all)
			}
		}
	}
}
