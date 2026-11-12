package api_test

import (
	"crypto/ecdh"
	"crypto/ecdsa"
	"crypto/elliptic"
	"crypto/rand"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"
	"time"

	"montra/backend/internal/notifications"
	"montra/backend/internal/testutil/apitest"
)

// webPushServer wires a local push service and VAPID keys into the API
// (push-config, host allow-list) and the worker (delivery).
func webPushServer(t *testing.T, s *apitest.Server) (*pushService, *httptest.Server, string) {
	t.Helper()
	svc := &pushService{}
	ts := httptest.NewTLSServer(svc)
	t.Cleanup(ts.Close)
	vapid, err := ecdsa.GenerateKey(elliptic.P256(), rand.Reader)
	if err != nil {
		t.Fatal(err)
	}
	vpub, _ := vapid.PublicKey.ECDH()
	pubB64 := b64u.EncodeToString(vpub.Bytes())
	vpriv, err := vapid.Bytes()
	if err != nil {
		t.Fatal(err)
	}
	wp, err := notifications.NewWebPush(pubB64, b64u.EncodeToString(vpriv), "mailto:ops@montra.test", []string{"127.0.0.1"})
	if err != nil {
		t.Fatal(err)
	}
	wp.SetHTTPClient(ts.Client())
	s.WorkerSvcs.Notify.WebPush = wp
	s.Svcs.Notify.WebPush = wp
	s.Svcs.Notify.PushHostsExtra = []string{"127.0.0.1"}
	return svc, ts, pubB64
}

// webPushBody is a browser subscription registration with fresh keys.
func webPushBody(label, endpoint string) map[string]any {
	ua, _ := ecdh.P256().GenerateKey(rand.Reader)
	auth := make([]byte, 16)
	_, _ = rand.Read(auth)
	return map[string]any{"kind": "webpush", "device_label": label, "subscription": map[string]any{"endpoint": endpoint,
		"keys": map[string]any{"p256dh": b64u.EncodeToString(ua.PublicKey().Bytes()), "auth": b64u.EncodeToString(auth)}}}
}

func goalNotification(t *testing.T, s *apitest.Server, addr, title string) {
	t.Helper()
	notify(t, s, notifications.Notification{UserID: userID(t, s, addr), Category: "goal", EventType: "goal.milestone", Title: title,
		Body: "Keep going.", DeepLink: "/goals", Priority: "normal"})
	s.RunJobs(t)
}

// Browser push: the VAPID public key is served (only when configured), the
// endpoint list never shows endpoints or keys, and a browser registered by
// a session stops receiving pushes when that session ends (sign-out,
// revoke, sign-out everywhere), so a shared browser never keeps getting
// the previous person's notifications.
func TestPushConfigEndpointListAndSessionBinding(t *testing.T) {
	s := apitest.New(t, nil)
	addr := s.Register(t, "pushsessions")
	phone, _ := s.Login(t, addr)
	uid := userID(t, s, addr)
	endpoints := func(c *apitest.Client) []any {
		return c.Do(t, http.MethodGet, "/me/push-endpoints", nil).Expect(t, http.StatusOK).List()
	}

	// Without VAPID keys browser push is honestly unavailable: no key is served.
	cfg := phone.Do(t, http.MethodGet, "/notifications/push-config", nil).Expect(t, http.StatusOK).Data()["web_push"].(map[string]any)
	if cfg["available"] != false || cfg["vapid_public_key"] != nil {
		t.Fatalf("push-config without VAPID: %v", cfg)
	}
	svc, ts, pubB64 := webPushServer(t, s)
	r := phone.Do(t, http.MethodGet, "/notifications/push-config", nil).Expect(t, http.StatusOK)
	cfg = r.Data()["web_push"].(map[string]any)
	if cfg["available"] != true || cfg["vapid_public_key"] != pubB64 || len(cfg) != 2 {
		t.Fatalf("push-config: %v", cfg)
	}

	// Each session registers its own browser; the list shows labels and
	// state only, never the endpoint URL or the browser's keys.
	ep1 := phone.Do(t, http.MethodPost, "/me/push-endpoints", webPushBody("Phone browser", ts.URL+"/push/one")).Expect(t, http.StatusCreated).Data()["id"]
	tablet, _ := s.Login(t, addr)
	ep2 := tablet.Do(t, http.MethodPost, "/me/push-endpoints", webPushBody("Tablet browser", ts.URL+"/push/two")).Expect(t, http.StatusCreated).Data()["id"]
	list := phone.Do(t, http.MethodGet, "/me/push-endpoints", nil).Expect(t, http.StatusOK)
	if items := list.List(); len(items) != 2 {
		t.Fatalf("endpoints: %v", items)
	}
	for _, x := range list.List() {
		m := x.(map[string]any)
		if m["kind"] != "webpush" || m["created_at"] == nil || m["disabled_at"] != nil || m["current_session"] != (m["id"] == ep1) ||
			(m["device_label"] != "Phone browser" && m["device_label"] != "Tablet browser") {
			t.Fatalf("endpoint: %v", m)
		}
	}
	if raw := string(list.Raw); strings.Contains(raw, "/push/") || strings.Contains(raw, "p256dh") || strings.Contains(raw, "subscription") ||
		strings.Contains(raw, "endpoint\"") {
		t.Fatalf("endpoint list leaks the subscription: %s", raw)
	}
	goalNotification(t, s, addr, "Both browsers")
	if n := len(svc.requests()); n != 2 {
		t.Fatalf("push requests: %d", n)
	}

	// Signing out of the phone removes its browser: the next notification
	// reaches only the tablet.
	phone.Do(t, http.MethodPost, "/auth/logout", nil).Expect(t, http.StatusOK)
	if n := workerCount(t, s, `select count(*) from push_endpoints where id = $1`, ep1); n != 0 {
		t.Fatal("the phone's browser survived sign-out")
	}
	if l := endpoints(tablet); len(l) != 1 || l[0].(map[string]any)["id"] != ep2 || l[0].(map[string]any)["current_session"] != true {
		t.Fatalf("endpoints after sign-out: %v", l)
	}
	goalNotification(t, s, addr, "Tablet only")
	if n := len(svc.requests()); n != 3 {
		t.Fatalf("push requests after sign-out: %d", n)
	}

	// Revoking a session from another device removes its browser too.
	laptop, _ := s.Login(t, addr)
	ep3 := laptop.Do(t, http.MethodPost, "/me/push-endpoints", webPushBody("Laptop browser", ts.URL+"/push/three")).Expect(t, http.StatusCreated).Data()["id"]
	var laptopSession string
	for _, x := range tablet.Do(t, http.MethodGet, "/me/sessions", nil).Expect(t, http.StatusOK).List() {
		if m := x.(map[string]any); m["current"] != true {
			laptopSession = m["id"].(string)
		}
	}
	tablet.Do(t, http.MethodDelete, "/me/sessions/"+laptopSession, nil).Expect(t, http.StatusOK)
	if n := workerCount(t, s, `select count(*) from push_endpoints where id = $1`, ep3); n != 0 {
		t.Fatal("the laptop's browser survived revocation")
	}

	// A browser registered before sessions were recorded cannot be told
	// apart from a shared one: the account's next session end removes it.
	s.Env.ExecWorker(t, `update push_endpoints set session_id = null where id = $1`, ep2)
	ghost, _ := s.Login(t, addr)
	ghost.Do(t, http.MethodPost, "/auth/logout", nil).Expect(t, http.StatusOK)
	if n := workerCount(t, s, `select count(*) from push_endpoints where user_id = $1`, uid); n != 0 {
		t.Fatalf("unattributed endpoints after a session end: %d", n)
	}

	// Sign-out everywhere leaves nothing registered.
	last, _ := s.Login(t, addr)
	last.Do(t, http.MethodPost, "/me/push-endpoints", webPushBody("Last browser", ts.URL+"/push/four")).Expect(t, http.StatusCreated)
	last.Do(t, http.MethodPost, "/auth/logout-all", nil).Expect(t, http.StatusOK)
	if n := workerCount(t, s, `select count(*) from push_endpoints where user_id = $1`, uid); n != 0 {
		t.Fatalf("endpoints after sign-out everywhere: %d", n)
	}
	goalNotification(t, s, addr, "Nobody")
	if n := len(svc.requests()); n != 3 {
		t.Fatalf("push requests after sign-out everywhere: %d", n)
	}
}

// PATCH /notifications/preferences changes only the fields an item sends.
func TestNotificationPreferencePatchKeepsOmittedFields(t *testing.T) {
	s := apitest.New(t, nil)
	c, _ := s.Login(t, s.Register(t, "prefpatch"))
	patch := func(items ...map[string]any) *apitest.Response {
		return c.Do(t, http.MethodPatch, "/notifications/preferences", map[string]any{"items": items})
	}
	find := func(list []any, category, channel string, group any) map[string]any {
		for _, x := range list {
			m := x.(map[string]any)
			if m["category"] == category && m["channel"] == channel && m["group_id"] == group {
				return m
			}
		}
		t.Fatalf("no %s/%s preference in %v", category, channel, list)
		return nil
	}
	// Digest alone keeps enabled (goal emails are off by default).
	p := find(patch(map[string]any{"category": "goal", "channel": "email", "digest": "weekly"}).Expect(t, http.StatusOK).List(), "goal", "email", nil)
	if p["enabled"] != false || p["digest"] != "weekly" {
		t.Fatalf("after digest-only patch: %v", p)
	}
	// Enabled alone keeps the digest.
	p = find(patch(map[string]any{"category": "goal", "channel": "email", "enabled": true}).Expect(t, http.StatusOK).List(), "goal", "email", nil)
	if p["enabled"] != true || p["digest"] != "weekly" {
		t.Fatalf("after enabled-only patch: %v", p)
	}
	// An item that changes nothing is a validation error.
	if r := patch(map[string]any{"category": "goal", "channel": "email"}); r.Status != http.StatusUnprocessableEntity || detail(t, r)["field"] != "body.items[0]" || detail(t, r)["code"] != "required" {
		t.Fatalf("empty item: %d %s", r.Status, r.Raw)
	}
	// A new group override starts from the category's saved preference.
	patch(map[string]any{"category": "group", "channel": "email", "enabled": true}).Expect(t, http.StatusOK)
	gid := createGroup(t, c, map[string]any{"name": "Flatmates", "group_type": "roommates", "base_currency": "INR"})["id"]
	p = find(patch(map[string]any{"category": "group", "channel": "email", "group_id": gid, "digest": "daily"}).Expect(t, http.StatusOK).List(), "group", "email", gid)
	if p["enabled"] != true || p["digest"] != "daily" {
		t.Fatalf("group override: %v", p)
	}
	// Security and account notifications stay on.
	patch(map[string]any{"category": "security", "channel": "email", "enabled": false}).Expect(t, http.StatusUnprocessableEntity)
}

// A category set to a weekly digest is sent weekly (Mondays) even when the
// account digest is daily, and a daily category goes out daily when the
// account digest is weekly: the category setting wins for that category.
func TestPerCategoryDigestCadence(t *testing.T) {
	s := apitest.New(t, nil)
	addr := s.Register(t, "cadence")
	c, _ := s.Login(t, addr)
	uid := userID(t, s, addr)
	c.Do(t, http.MethodPatch, "/me/preferences", map[string]any{"email_digest": "daily"}).Expect(t, http.StatusOK)
	c.Do(t, http.MethodPatch, "/notifications/preferences", map[string]any{"items": []any{
		map[string]any{"category": "goal", "channel": "email", "enabled": true, "digest": "weekly"},
		map[string]any{"category": "budget", "channel": "email", "enabled": true, "digest": "daily"},
		map[string]any{"category": "subscription", "channel": "email", "enabled": true}}}).Expect(t, http.StatusOK)
	held := func(category, title string) {
		id := notify(t, s, notifications.Notification{UserID: uid, Category: category, EventType: category + ".update", Title: title, Body: "x", Priority: "normal"})
		s.RunJobs(t)
		if st, reason := deliveryOf(t, s, id, "email"); st != "skipped" || reason != "digest" {
			t.Fatalf("%s: %s/%s", title, st, reason)
		}
	}
	held("goal", "Weekly goal update")
	held("budget", "Daily budget update")

	// 08:00 in Asia/Kolkata is 02:30 UTC. Tuesday: only the daily category.
	base := time.Now().UTC()
	for base.Weekday() != time.Tuesday {
		base = base.AddDate(0, 0, 1)
	}
	tuesday := time.Date(base.Year(), base.Month(), base.Day(), 2, 30, 0, 0, time.UTC)
	digestAt := func(at time.Time) []string {
		before := len(s.Mail.Messages(addr))
		if err := s.WorkerSvcs.Notify.DigestScan(t.Context(), at); err != nil {
			t.Fatal(err)
		}
		s.RunJobs(t)
		var texts []string
		for _, m := range s.Mail.Messages(addr)[before:] {
			texts = append(texts, m.Text)
		}
		return texts
	}
	got := digestAt(tuesday)
	if len(got) != 1 || !strings.Contains(got[0], "Daily budget update") || strings.Contains(got[0], "Weekly goal update") {
		t.Fatalf("Tuesday digest: %q", got)
	}
	// Monday: the weekly category joins the digest.
	got = digestAt(tuesday.AddDate(0, 0, 6))
	if len(got) != 1 || !strings.Contains(got[0], "Weekly goal update") {
		t.Fatalf("Monday digest: %q", got)
	}

	// Account on weekly: the daily category still goes out on a Tuesday,
	// the rest waits for Monday.
	c.Do(t, http.MethodPatch, "/me/preferences", map[string]any{"email_digest": "weekly"}).Expect(t, http.StatusOK)
	held("goal", "Second goal update")
	held("budget", "Second budget update")
	held("subscription", "Subscription update") // no category digest: follows the account (weekly)
	got = digestAt(tuesday.AddDate(0, 0, 7))
	if len(got) != 1 || !strings.Contains(got[0], "Second budget update") || strings.Contains(got[0], "Second goal update") ||
		strings.Contains(got[0], "Subscription update") {
		t.Fatalf("Tuesday digest with a weekly account: %q", got)
	}
	got = digestAt(tuesday.AddDate(0, 0, 13))
	if len(got) != 1 || !strings.Contains(got[0], "Second goal update") || !strings.Contains(got[0], "Subscription update") {
		t.Fatalf("Monday digest with a weekly account: %q", got)
	}
}

// The badge count keeps its JSON shape; deep links are web routes that
// carry IDs only.
func TestUnreadCountAndDeepLinksAreWebRoutes(t *testing.T) {
	s := apitest.New(t, nil)
	addr := s.Register(t, "deeplinks")
	c, _ := s.Login(t, addr)
	uid := userID(t, s, addr)
	notify(t, s, notifications.Notification{UserID: uid, Category: "goal", EventType: "goal.milestone", Title: "One", Body: "x"})
	notify(t, s, notifications.Notification{UserID: uid, Category: "goal", EventType: "goal.milestone", Title: "Two", Body: "x"})
	r := c.Do(t, http.MethodGet, "/notifications/unread-count", nil).Expect(t, http.StatusOK)
	if r.Data()["unread"] != float64(2) || !strings.Contains(string(r.Raw), `"unread":2`) {
		t.Fatalf("unread count: %s", r.Raw)
	}
	link := func(c *apitest.Client, category, event string) string {
		t.Helper()
		for _, x := range c.Do(t, http.MethodGet, "/notifications?category="+category, nil).Expect(t, http.StatusOK).List() {
			if m := x.(map[string]any); m["event_type"] == event {
				l, _ := m["deep_link"].(string)
				return l
			}
		}
		t.Fatalf("no %s/%s notification", category, event)
		return ""
	}

	// Bills and recurring rules live under /planning on the web.
	acct := createAccount(t, c, map[string]any{"name": "Bank", "account_type": "bank", "currency": "INR", "opening_balance": "50000"})["id"].(string)
	today := utcToday()
	bid := c.Do(t, http.MethodPost, "/bills", map[string]any{"name": "Electricity", "provider_name": "Power Co", "expected_amount": "2500",
		"frequency": "monthly", "start_date": today.AddDate(0, 0, 2).Format(day), "timezone": "UTC", "reminder_days_before": []int{3},
		"payment_account_id": acct}, "Idempotency-Key", key()).Expect(t, http.StatusCreated).Data()["id"].(string)
	rid := c.Do(t, http.MethodPost, "/recurring-rules", map[string]any{"kind": "expense", "name": "Gym", "frequency": "monthly",
		"start_date": today.AddDate(0, 0, 2).Format(day), "timezone": "UTC", "local_time": "09:00", "amount": "999", "account_id": acct,
		"auto_post": false, "reminder_days_before": []int{3}}, "Idempotency-Key", key()).Expect(t, http.StatusCreated).Data()["id"].(string)
	generate(t, s, 2)
	if l := link(c, "bill", "bill_due_soon"); l != "/planning/bills/"+bid {
		t.Fatalf("bill deep link: %s", l)
	}
	if l := link(c, "recurring", "recurring_due_soon"); l != "/planning/recurring/"+rid {
		t.Fatalf("recurring deep link: %s", l)
	}

	// Community join requests lead to the community's settings; moderation
	// outcomes to the person's moderation settings.
	host := newPerson(t, s, "host", nil)
	joiner := newPerson(t, s, "joiner", nil)
	member := newPerson(t, s, "member", nil)
	cid := createCommunity(t, host, map[string]any{"name": "Quiet Savers", "visibility": "private"})["id"].(string)
	joiner.c.Do(t, http.MethodPost, "/communities/"+cid+"/join", nil).Expect(t, http.StatusOK)
	s.RunJobs(t)
	if l := link(host.c, "community", "community_join_request"); l != "/communities/"+cid+"/settings" {
		t.Fatalf("join request deep link: %s", l)
	}
	pub := createCommunity(t, host, map[string]any{"name": "Open Savers"})["id"].(string)
	member.c.Do(t, http.MethodPost, "/communities/"+pub+"/join", nil).Expect(t, http.StatusOK)
	host.c.Do(t, http.MethodPost, "/communities/"+pub+"/moderation/actions", map[string]any{"action": "warn", "target_type": "member",
		"target_id": member.id, "reason": "Keep it friendly"}).Expect(t, http.StatusOK)
	s.RunJobs(t)
	if l := link(member.c, "community", "moderation_warn"); l != "/settings/moderation" {
		t.Fatalf("moderation deep link: %s", l)
	}
}
