package api_test

import (
	"context"
	"fmt"
	"net/http"
	"strconv"
	"strings"
	"testing"
	"time"

	"github.com/jackc/pgx/v5"

	"montra/backend/internal/platform/jobs"
	"montra/backend/internal/support"
	"montra/backend/internal/testutil/apitest"
)

func names(list []any, field string) []string {
	var out []string
	for _, x := range list {
		out = append(out, fmt.Sprint(x.(map[string]any)[field]))
	}
	return out
}

func TestGlobalSearchIsScopedToAuthorizedData(t *testing.T) {
	s := apitest.New(t, nil)
	a := newPerson(t, s, "alice", nil)
	b := newPerson(t, s, "bob", nil)
	fan := newPerson(t, s, "holidayfan", nil)
	hidden := newPerson(t, s, "holidayhidden", map[string]any{"discoverable_by_username": false})

	acct := createAccount(t, a.c, map[string]any{"name": "Holiday Savings", "account_type": "savings", "currency": "INR", "opening_balance": "5000"})["id"].(string)
	createTx(t, a.c, map[string]any{"type": "expense", "account_id": acct, "amount": "250", "description": "Holiday coffee", "merchant_name": "Blue Tokai"})
	bacct := createAccount(t, b.c, map[string]any{"name": "Holiday Private", "account_type": "bank", "currency": "INR"})["id"].(string)
	createTx(t, b.c, map[string]any{"type": "expense", "account_id": bacct, "amount": "99", "description": "Holiday secret"})
	a.c.Do(t, http.MethodPost, "/goals", map[string]any{"name": "Holiday 2027", "goal_type": "travel", "target_amount": "50000"}, "Idempotency-Key", key()).
		Expect(t, http.StatusCreated)
	gid := createGroup(t, a.c, map[string]any{"name": "Holiday trip", "group_type": "trip", "base_currency": "INR"})["id"].(string)
	_ = gid
	createGroup(t, b.c, map[string]any{"name": "Holiday elsewhere", "group_type": "trip", "base_currency": "INR"})

	r := a.c.Do(t, http.MethodGet, "/search?q=holiday&limit=10&save=true", nil).Expect(t, http.StatusOK).Data()
	if got := names(r["accounts"].([]any), "name"); len(got) != 1 || got[0] != "Holiday Savings" {
		t.Fatalf("accounts: %v", got)
	}
	if got := names(r["transactions"].([]any), "description"); len(got) != 1 || got[0] != "Holiday coffee" {
		t.Fatalf("transactions: %v", got)
	}
	if got := names(r["groups"].([]any), "name"); len(got) != 1 || got[0] != "Holiday trip" {
		t.Fatalf("groups: %v", got)
	}
	if got := names(r["goals"].([]any), "name"); len(got) != 1 || got[0] != "Holiday 2027" {
		t.Fatalf("goals: %v", got)
	}
	// People are found by their exact username only, never by a partial one.
	if got := r["users"].([]any); len(got) != 0 {
		t.Fatalf("a partial username found people: %v", got)
	}
	if got := names(a.c.Do(t, http.MethodGet, "/search?scope=users&save=false&q=@"+strings.ToUpper(fan.user), nil).Expect(t, http.StatusOK).Data()["users"].([]any),
		"user_id"); len(got) != 1 || got[0] != fan.id {
		t.Fatalf("exact username: %v (fan %s)", got, fan.id)
	}
	for _, q := range []string{hidden.user, a.user} {
		if got := a.c.Do(t, http.MethodGet, "/search?scope=users&save=false&q="+q, nil).Expect(t, http.StatusOK).Data()["users"].([]any); len(got) != 0 {
			t.Fatalf("users for %s (not discoverable, or yourself): %v", q, got)
		}
	}
	// Merchant names match too, and scope narrows the sections.
	m := a.c.Do(t, http.MethodGet, "/search?q=tokai&scope=merchants&save=true", nil).Expect(t, http.StatusOK).Data()
	if got := names(m["merchants"].([]any), "name"); len(got) != 1 || got[0] != "Blue Tokai" || len(m["transactions"].([]any)) != 0 {
		t.Fatalf("merchant scope: %v", m)
	}
	// Bob sees only his own records.
	rb := b.c.Do(t, http.MethodGet, "/search?q=holiday&save=true", nil).Expect(t, http.StatusOK).Data()
	if got := names(rb["transactions"].([]any), "description"); len(got) != 1 || got[0] != "Holiday secret" {
		t.Fatalf("bob transactions: %v", got)
	}
	// LIKE wildcards match literally.
	if w := a.c.Do(t, http.MethodGet, "/search?q=%25%25&save=true", nil).Expect(t, http.StatusOK).Data(); len(w["transactions"].([]any)) != 0 || len(w["accounts"].([]any)) != 0 {
		t.Fatalf("wildcards matched: %v", w)
	}
	a.c.Do(t, http.MethodGet, "/search?q=h", nil).Expect(t, http.StatusUnprocessableEntity)

	// Recent searches: remembered only on request (typing never leaves a
	// trace), deduplicated, clearable.
	a.c.Do(t, http.MethodGet, "/search?q=Holiday&limit=10&save=true", nil).Expect(t, http.StatusOK)
	a.c.Do(t, http.MethodGet, "/search?q=private", nil).Expect(t, http.StatusOK)
	a.c.Do(t, http.MethodGet, "/search?q=typing&save=false", nil).Expect(t, http.StatusOK)
	recent := a.c.Do(t, http.MethodGet, "/search/recent", nil).Expect(t, http.StatusOK).List()
	if got := names(recent, "query"); len(got) != 3 || contains(got, "private") || contains(got, "typing") || got[0] != "Holiday" {
		t.Fatalf("recent: %v", got)
	}
	if len(b.c.Do(t, http.MethodGet, "/search/recent", nil).Expect(t, http.StatusOK).List()) != 1 {
		t.Fatal("recent searches leaked between users")
	}
	if d := a.c.Do(t, http.MethodDelete, "/search/recent", nil).Expect(t, http.StatusOK).Data(); d["deleted"].(float64) != 3 {
		t.Fatalf("clear: %v", d)
	}
	if len(a.c.Do(t, http.MethodGet, "/search/recent", nil).Expect(t, http.StatusOK).List()) != 0 {
		t.Fatal("history not cleared")
	}
}

func TestSupportRequestsContactAndStaffQueue(t *testing.T) {
	s := apitest.New(t, nil)
	addr := s.Register(t, "helpme")
	c, _ := s.Login(t, addr)
	other := newPerson(t, s, "other", nil)

	// Payment secrets are refused with a code; normal requests get a reference.
	if r := c.Do(t, http.MethodPost, "/support/requests", map[string]any{"kind": "support", "subject": "Card issue",
		"body": "My card 4111 1111 1111 1111 was charged"}); r.Status != http.StatusUnprocessableEntity || detail(t, r)["code"] != "contains_secret" ||
		detail(t, r)["field"] != "body.body" {
		t.Fatalf("secret refusal: %d %s", r.Status, r.Raw)
	}
	r := c.Do(t, http.MethodPost, "/support/requests", map[string]any{"kind": "bug", "subject": "Export button",
		"body": "The CSV export spins forever."}).Expect(t, http.StatusCreated).Data()
	id := r["id"].(string)
	if r["status"] != "open" || len(r["reference"].(string)) != 8 {
		t.Fatalf("request: %v", r)
	}
	sec := c.Do(t, http.MethodPost, "/support/requests", map[string]any{"kind": "security", "subject": "Odd sign-in",
		"body": "I saw a sign-in I did not make."}).Expect(t, http.StatusCreated).Data()
	if got := c.Do(t, http.MethodGet, "/support/requests", nil).Expect(t, http.StatusOK).List(); len(got) != 2 {
		t.Fatalf("mine: %d", len(got))
	}
	other.c.Do(t, http.MethodGet, "/support/requests/"+id, nil).Expect(t, http.StatusNotFound)
	other.c.Do(t, http.MethodGet, "/support/queue", nil).Expect(t, http.StatusForbidden)

	// Signed-out contact form.
	anon := s.NewClient("web")
	anon.Do(t, http.MethodPost, "/support/contact", map[string]any{"kind": "support", "subject": "Cannot sign in",
		"body": "Locked out after travel.", "contact_email": "not-an-email"}).Expect(t, http.StatusUnprocessableEntity)
	ct := anon.Do(t, http.MethodPost, "/support/contact", map[string]any{"kind": "support", "subject": "Cannot sign in",
		"body": "Locked out after travel.", "contact_email": "Locked.Out@Example.com"}).Expect(t, http.StatusAccepted).Data()
	if len(ct["reference"].(string)) != 8 {
		t.Fatalf("contact: %v", ct)
	}

	// Staff queue: security first; status changes are audited.
	staff := newPerson(t, s, "staffer", nil)
	s.Env.ExecWorker(t, `update users set platform_role = 'support' where id = $1`, staff.id)
	q := staff.c.Do(t, http.MethodGet, "/support/queue?status=open", nil).Expect(t, http.StatusOK).List()
	if len(q) != 3 || q[0].(map[string]any)["kind"] != "security" || q[0].(map[string]any)["id"] != sec["id"] {
		t.Fatalf("queue: %v", q)
	}
	var anonRow map[string]any
	for _, x := range q {
		if x.(map[string]any)["signed_in"] == false {
			anonRow = x.(map[string]any)
		}
	}
	if anonRow == nil || anonRow["contact_email"] != "locked.out@example.com" {
		t.Fatalf("anonymous row: %v", anonRow)
	}
	up := staff.c.Do(t, http.MethodPatch, "/support/queue/"+id, map[string]any{"status": "resolved"}).Expect(t, http.StatusOK).Data()
	if up["status"] != "resolved" {
		t.Fatalf("update: %v", up)
	}
	if got := c.Do(t, http.MethodGet, "/support/requests/"+id, nil).Expect(t, http.StatusOK).Data(); got["status"] != "resolved" {
		t.Fatalf("author view: %v", got)
	}
	if n := workerCount(t, s, `select count(*) from audit_events where entity_type = 'support_request' and action = 'status_changed'`); n != 1 {
		t.Fatalf("audit: %d", n)
	}

	// The hourly staff email carries counts only, never request text.
	s.Env.ExecWorker(t, `update support_requests set created_at = date_trunc('hour', now()) - interval '30 minutes'`)
	ctx := context.Background()
	if err := s.Env.Worker.WithSystemTx(ctx, func(tx pgx.Tx) error {
		_, _, err := jobs.Enqueue(ctx, tx, jobs.Spec{Type: support.JobNotifyStaff, DedupeKey: fmt.Sprint("t", time.Now().UnixNano())})
		return err
	}); err != nil {
		t.Fatal(err)
	}
	s.RunJobs(t)
	inbox := s.Mail.Messages(s.Cfg.Product.SupportEmail)
	if len(inbox) != 1 || !strings.Contains(inbox[0].Subject, "2 new support requests") || strings.Contains(inbox[0].Text, "sign-in I did not make") {
		t.Fatalf("support inbox: %+v", inbox)
	}
	if len(s.Mail.Messages(s.Cfg.Product.SecurityEmail)) != 1 {
		t.Fatal("security inbox not told about the security report")
	}

	// Ten requests a day per account; the 429 is coded and says when to retry.
	for i := 0; i < 8; i++ {
		c.Do(t, http.MethodPost, "/support/requests", map[string]any{"kind": "feedback", "subject": fmt.Sprintf("Idea %d", i), "body": "More charts."}).
			Expect(t, http.StatusCreated)
	}
	capped := c.Do(t, http.MethodPost, "/support/requests", map[string]any{"kind": "feedback", "subject": "Idea 9", "body": "More charts."})
	assertDailyCap(t, capped, "support requests")
}

// assertDailyCap checks a coded daily-cap 429 with a Retry-After header.
func assertDailyCap(t *testing.T, r *apitest.Response, kind string) {
	t.Helper()
	if r.Status != http.StatusTooManyRequests || r.ErrorCode() != "RATE_LIMITED" {
		t.Fatalf("daily cap: %d %s", r.Status, r.Raw)
	}
	d := detail(t, r)
	if d["code"] != "daily_cap" || d["params"].(map[string]any)["limit"] != "10" || d["params"].(map[string]any)["kind"] != kind {
		t.Fatalf("daily cap detail: %v", d)
	}
	if secs, err := strconv.Atoi(r.Headers.Get("Retry-After")); err != nil || secs <= 0 || secs > 24*3600 {
		t.Fatalf("daily cap Retry-After = %q", r.Headers.Get("Retry-After"))
	}
}

// Planning records are searchable (owner-scoped), results can be sorted,
// and searches are remembered only on request.
func TestSearchPlanningSectionsAndSort(t *testing.T) {
	s := apitest.New(t, nil)
	c, _ := s.Login(t, s.Register(t, "planner"))
	other, _ := s.Login(t, s.Register(t, "outsider"))
	acct := createAccount(t, c, map[string]any{"name": "Holiday Savings", "account_type": "savings", "currency": "INR"})["id"].(string)
	createAccount(t, c, map[string]any{"name": "Big holiday fund", "account_type": "bank", "currency": "INR"})
	today := utcToday()
	c.Do(t, http.MethodPost, "/bills", map[string]any{"name": "Holiday insurance", "provider_name": "SafeTrip", "expected_amount": "2500",
		"frequency": "monthly", "start_date": today.AddDate(0, 0, 5).Format(day), "timezone": "UTC", "payment_account_id": acct}, "Idempotency-Key", key()).
		Expect(t, http.StatusCreated)
	c.Do(t, http.MethodPost, "/subscriptions", map[string]any{"name": "Streaming", "plan_name": "Holiday Plus", "amount": "199", "billing_frequency": "monthly",
		"start_date": today.Format(day), "payment_account_id": acct}, "Idempotency-Key", key()).Expect(t, http.StatusCreated)
	c.Do(t, http.MethodPost, "/recurring-rules", map[string]any{"kind": "expense", "name": "Holiday club", "frequency": "monthly",
		"start_date": today.AddDate(0, 0, 3).Format(day), "timezone": "UTC", "local_time": "09:00", "amount": "500", "account_id": acct, "auto_post": false},
		"Idempotency-Key", key()).Expect(t, http.StatusCreated)
	c.Do(t, http.MethodPost, "/budgets", map[string]any{"name": "Holiday budget", "budget_type": "total", "period": "monthly", "currency": "INR",
		"limit": "10000"}).Expect(t, http.StatusCreated)
	c.Do(t, http.MethodPost, "/categories", map[string]any{"name": "Holiday fund", "kind": "expense"}).Expect(t, http.StatusCreated)

	r := c.Do(t, http.MethodGet, "/search?q=holiday&limit=10", nil).Expect(t, http.StatusOK).Data()
	want := map[string][2]string{"bills": {"Holiday insurance", "active"}, "subscriptions": {"Streaming", "active"}, "recurring_rules": {"Holiday club", "expense"},
		"budgets": {"Holiday budget", "total"}, "categories": {"Holiday fund", "expense"}}
	for section, w := range want {
		got := r[section].([]any)
		if len(got) != 1 || got[0].(map[string]any)["name"] != w[0] || got[0].(map[string]any)["kind"] != w[1] || got[0].(map[string]any)["id"] == nil {
			t.Fatalf("%s: %v", section, got)
		}
	}
	if r["sort"] != "relevance" || names(r["accounts"].([]any), "name")[0] != "Holiday Savings" {
		t.Fatalf("relevance order: %v", r["accounts"])
	}
	// Provider and plan names match; scope narrows to one section.
	if p := c.Do(t, http.MethodGet, "/search?q=safetrip&scope=bills", nil).Expect(t, http.StatusOK).Data(); len(p["bills"].([]any)) != 1 || len(p["accounts"].([]any)) != 0 {
		t.Fatalf("provider match: %v", p)
	}
	if p := c.Do(t, http.MethodGet, "/search?q=holiday+plus&scope=subscriptions", nil).Expect(t, http.StatusOK).Data(); len(p["subscriptions"].([]any)) != 1 {
		t.Fatalf("plan match: %v", p)
	}
	// Sorting by name is alphabetical; by recent is newest first.
	if byName := c.Do(t, http.MethodGet, "/search?q=holiday&sort=name", nil).Expect(t, http.StatusOK).Data(); names(byName["accounts"].([]any), "name")[0] != "Big holiday fund" {
		t.Fatalf("name order: %v", byName["accounts"])
	}
	if recent := c.Do(t, http.MethodGet, "/search?q=holiday&sort=recent", nil).Expect(t, http.StatusOK).Data(); names(recent["accounts"].([]any), "name")[0] != "Big holiday fund" {
		t.Fatalf("recent order: %v", recent["accounts"])
	}
	// Other people see none of it.
	o := other.Do(t, http.MethodGet, "/search?q=holiday", nil).Expect(t, http.StatusOK).Data()
	for _, section := range []string{"bills", "subscriptions", "recurring_rules", "budgets", "categories", "accounts"} {
		if len(o[section].([]any)) != 0 {
			t.Fatalf("%s leaked: %v", section, o[section])
		}
	}
	// Nothing above was remembered; a submitted search is.
	if l := c.Do(t, http.MethodGet, "/search/recent", nil).Expect(t, http.StatusOK).List(); len(l) != 0 {
		t.Fatalf("searches remembered without save=true: %v", l)
	}
	c.Do(t, http.MethodGet, "/search?q=holiday&scope=bills&save=true", nil).Expect(t, http.StatusOK)
	if l := c.Do(t, http.MethodGet, "/search/recent", nil).Expect(t, http.StatusOK).List(); len(l) != 1 || l[0].(map[string]any)["scope"] != "bills" {
		t.Fatalf("recent: %v", l)
	}
}

// Requests have a message thread the requester and staff share; staff
// replies notify the requester without the text; everything is audited
// without the text; and the signed-out contact form has the same coded
// daily cap per address.
func TestSupportMessageThreadAndContactCap(t *testing.T) {
	s := apitest.New(t, nil)
	addr := s.Register(t, "threader")
	c, _ := s.Login(t, addr)
	other := newPerson(t, s, "bystander", nil)
	staff := newPerson(t, s, "agent", nil)
	s.Env.ExecWorker(t, `update users set platform_role = 'support' where id = $1`, staff.id)
	id := c.Do(t, http.MethodPost, "/support/requests", map[string]any{"kind": "support", "subject": "Sync question", "body": "Why is my balance off?"}).
		Expect(t, http.StatusCreated).Data()["id"].(string)
	messages := "/support/requests/" + id + "/messages"

	if l := c.Do(t, http.MethodGet, messages, nil).Expect(t, http.StatusOK).List(); len(l) != 0 {
		t.Fatalf("new thread: %v", l)
	}
	other.c.Do(t, http.MethodGet, messages, nil).Expect(t, http.StatusNotFound)
	other.c.Do(t, http.MethodPost, messages, map[string]any{"body": "Me too"}).Expect(t, http.StatusNotFound)
	if r := c.Do(t, http.MethodPost, messages, map[string]any{"body": "My OTP is 123456"}); r.Status != http.StatusUnprocessableEntity || detail(t, r)["code"] != "contains_secret" {
		t.Fatalf("secret in a message: %d %s", r.Status, r.Raw)
	}
	m1 := c.Do(t, http.MethodPost, messages, map[string]any{"body": "It happened after the import."}).Expect(t, http.StatusCreated).Data()
	if m1["author_role"] != "requester" || m1["mine"] != true || m1["request_id"] != id {
		t.Fatalf("requester message: %v", m1)
	}
	m2 := staff.c.Do(t, http.MethodPost, messages, map[string]any{"body": "Thanks, we are looking into it."}).Expect(t, http.StatusCreated).Data()
	if m2["author_role"] != "staff" || m2["mine"] != true {
		t.Fatalf("staff message: %v", m2)
	}
	s.RunJobs(t)
	thread := c.Do(t, http.MethodGet, messages, nil).Expect(t, http.StatusOK).List()
	if len(thread) != 2 || thread[0].(map[string]any)["mine"] != true || thread[1].(map[string]any)["mine"] != false ||
		thread[1].(map[string]any)["author_role"] != "staff" || thread[1].(map[string]any)["body"] != "Thanks, we are looking into it." {
		t.Fatalf("requester's thread: %v", thread)
	}
	if st := staff.c.Do(t, http.MethodGet, messages, nil).Expect(t, http.StatusOK).List(); len(st) != 2 || st[1].(map[string]any)["mine"] != true {
		t.Fatalf("staff's thread: %v", st)
	}
	var reply map[string]any
	for _, x := range c.Do(t, http.MethodGet, "/notifications?category=account", nil).Expect(t, http.StatusOK).List() {
		if m := x.(map[string]any); m["event_type"] == "support_reply" {
			reply = m
		}
	}
	if reply == nil || reply["deep_link"] != "/help/requests/"+id || reply["entity_id"] != id ||
		strings.Contains(reply["title"].(string)+reply["body"].(string), "looking into it") {
		t.Fatalf("reply notification: %v", reply)
	}
	if got := c.Do(t, http.MethodGet, "/support/requests/"+id, nil).Expect(t, http.StatusOK).Data(); got["message_count"] != float64(2) || got["last_message_at"] == nil {
		t.Fatalf("request thread summary: %v", got)
	}
	if n := workerCount(t, s, `select count(*) from audit_events where entity_type = 'support_request' and action = 'message_posted'`); n != 2 {
		t.Fatalf("audited posts: %d", n)
	}
	if n := workerCount(t, s, `select count(*) from audit_events where action = 'message_posted' and changes::text like '%looking into%'`); n != 0 {
		t.Fatal("audit event carries message text")
	}
	// Requesters get ten messages a day.
	for i := 0; i < 9; i++ {
		c.Do(t, http.MethodPost, messages, map[string]any{"body": fmt.Sprintf("Detail %d", i)}).Expect(t, http.StatusCreated)
	}
	assertDailyCap(t, c.Do(t, http.MethodPost, messages, map[string]any{"body": "One more"}), "support messages")
	// Closed requests take no more messages.
	staff.c.Do(t, http.MethodPatch, "/support/queue/"+id, map[string]any{"status": "closed"}).Expect(t, http.StatusOK)
	if r := staff.c.Do(t, http.MethodPost, messages, map[string]any{"body": "Closing note"}); r.Status != http.StatusUnprocessableEntity || detail(t, r)["code"] != "request_closed" {
		t.Fatalf("message on a closed request: %d %s", r.Status, r.Raw)
	}

	// Signed-out contact form: ten a day per address (from any device),
	// then the same coded 429.
	contact := func(email string) *apitest.Response {
		return s.NewClient("web").Do(t, http.MethodPost, "/support/contact", map[string]any{"kind": "support", "subject": "Cannot sign in",
			"body": "Locked out after travel.", "contact_email": email})
	}
	for i := 0; i < 10; i++ {
		contact("Capped@Example.com").Expect(t, http.StatusAccepted)
	}
	assertDailyCap(t, contact("capped@example.com"), "support requests")
	contact("someone.else@example.com").Expect(t, http.StatusAccepted)
}
