package api_test

import (
	"net/http"
	"slices"
	"testing"

	"montra/backend/internal/testutil/apitest"
)

// Coverage for goal listing and the achieve action, and the subscription
// actions cancellation-started, reactivate and verify.

func TestCoverageGoalsListAndAchieve(t *testing.T) {
	s := apitest.New(t, nil)
	o := newPerson(t, s, "cvgoalowner", nil)
	mate := newPerson(t, s, "cvgoalmate", nil)
	z := newPerson(t, s, "cvgoalstranger", nil)
	gid := createGroup(t, o.c, map[string]any{"name": "Savers", "group_type": "friends", "base_currency": "INR"})["id"].(string)
	joinByLink(t, o, mate, gid)
	mk := func(name string, priority int, extra map[string]any) map[string]any {
		body := map[string]any{"name": name, "goal_type": "custom", "target_amount": "1000", "priority": priority}
		for k, v := range extra {
			body[k] = v
		}
		return sgCreateGoal(t, o.c, body)
	}
	bike := mk("Bike", 2, nil)
	laptop := mk("Laptop", 1, map[string]any{"starting_amount": "250"})
	trip := mk("Trip", 1, nil)
	fund := mk("Fund", 3, nil)
	old := mk("Old", 1, nil)
	o.c.Do(t, http.MethodPost, "/goals/"+trip["id"].(string)+"/pause", nil).Expect(t, http.StatusOK)
	o.c.Do(t, http.MethodPost, "/goals/"+fund["id"].(string)+"/cancel", nil).Expect(t, http.StatusOK)
	o.c.Do(t, http.MethodDelete, "/goals/"+old["id"].(string), nil).Expect(t, http.StatusOK)

	// Achieve: from active (any saved amount), version-checked, audited.
	if r := o.c.Do(t, http.MethodPost, "/goals/"+laptop["id"].(string)+"/achieve?version=99", nil); r.ErrorCode() != "VERSION_CONFLICT" {
		t.Fatalf("stale achieve: %s", r.Raw)
	}
	z.c.Do(t, http.MethodPost, "/goals/"+laptop["id"].(string)+"/achieve", nil).Expect(t, http.StatusNotFound)
	ach := o.c.Do(t, http.MethodPost, "/goals/"+laptop["id"].(string)+"/achieve?version="+sgVersion(laptop), nil).Expect(t, http.StatusOK).Data()
	if ach["status"] != "achieved" || ach["achieved_at"] == nil || ach["version"].(float64) != laptop["version"].(float64)+1 ||
		money(ach["progress"].(map[string]any), "saved") != "250.00" {
		t.Fatalf("achieved goal = %v", ach)
	}
	if n := workerCount(t, s, `select count(*) from audit_events where entity_type = 'goal' and entity_id = $1 and action = 'achieve'
		and changes->>'from' = 'active' and changes->>'to' = 'achieved'`, laptop["id"]); n != 1 {
		t.Fatalf("achieve audit rows = %d", n)
	}
	// Also from paused; not from achieved, cancelled or archived.
	o.c.Do(t, http.MethodPost, "/goals/"+trip["id"].(string)+"/achieve", nil).Expect(t, http.StatusOK)
	for _, g := range []map[string]any{laptop, fund, old} {
		gfCoded(t, o.c.Do(t, http.MethodPost, "/goals/"+g["id"].(string)+"/achieve", nil), http.StatusUnprocessableEntity, "DOMAIN_RULE_VIOLATION",
			"invalid_status_transition")
	}
	p := gfCoded(t, o.c.Do(t, http.MethodPost, "/goals/"+fund["id"].(string)+"/achieve", nil), http.StatusUnprocessableEntity, "DOMAIN_RULE_VIOLATION",
		"invalid_status_transition")
	if p["from"] != "cancelled" || p["to"] != "achieved" {
		t.Fatalf("transition params = %v", p)
	}

	// List: everything but archived by default, active first then paused,
	// achieved and the rest; by priority then name within a status.
	names := func(path string) []string {
		return fieldsOf(o.c.Do(t, http.MethodGet, path, nil).Expect(t, http.StatusOK).List(), "name")
	}
	if got := names("/goals"); !slices.Equal(got, []string{"Bike", "Laptop", "Trip", "Fund"}) {
		t.Fatalf("default goal list = %v", got)
	}
	if got := names("/goals?status=all"); !slices.Equal(got, []string{"Bike", "Laptop", "Trip", "Old", "Fund"}) {
		t.Fatalf("all goals = %v", got)
	}
	if got := names("/goals?status=achieved"); !slices.Equal(got, []string{"Laptop", "Trip"}) {
		t.Fatalf("achieved goals = %v", got)
	}
	if got := names("/goals?status=archived"); !slices.Equal(got, []string{"Old"}) {
		t.Fatalf("archived goals = %v", got)
	}
	gfField(t, o.c.Do(t, http.MethodGet, "/goals?status=done", nil), "query.status")
	l := o.c.Do(t, http.MethodGet, "/goals?status=achieved", nil).Expect(t, http.StatusOK).List()
	if lp := gfFind(l, "name", "Laptop"); money(lp["progress"].(map[string]any), "saved") != "250.00" || lp["access"] != "owner" ||
		lp["achieved_at"] == nil {
		t.Fatalf("listed goal progress = %v", lp)
	}
	// Shared goals appear in members' lists with their access; strangers see none.
	if got := fieldsOf(mate.c.Do(t, http.MethodGet, "/goals", nil).Expect(t, http.StatusOK).List(), "name"); len(got) != 0 {
		t.Fatalf("mate's goals before sharing = %v", got)
	}
	o.c.Do(t, http.MethodPost, "/goals/"+bike["id"].(string)+"/members", map[string]any{"user_id": mate.id, "role": "viewer"}).Expect(t, http.StatusOK)
	ml := mate.c.Do(t, http.MethodGet, "/goals", nil).Expect(t, http.StatusOK).List()
	if len(ml) != 1 || ml[0].(map[string]any)["id"] != bike["id"] || ml[0].(map[string]any)["access"] != "viewer" ||
		ml[0].(map[string]any)["owner_user_id"] != o.id {
		t.Fatalf("mate's goals after sharing = %v", ml)
	}
	// A viewer cannot change the goal's status.
	if r := mate.c.Do(t, http.MethodPost, "/goals/"+bike["id"].(string)+"/achieve", nil); r.Status != http.StatusNotFound && r.Status != http.StatusForbidden {
		t.Fatalf("viewer achieving a shared goal: %d %s", r.Status, r.Raw)
	}
	if l := z.c.Do(t, http.MethodGet, "/goals?status=all", nil).Expect(t, http.StatusOK).List(); len(l) != 0 {
		t.Fatalf("stranger's goals = %v", l)
	}
	// Achieved goals still accept withdrawals.
	o.c.Do(t, http.MethodPost, "/goals/"+laptop["id"].(string)+"/contributions", map[string]any{"kind": "withdrawal", "amount": "50"},
		"Idempotency-Key", key()).Expect(t, http.StatusCreated)
}

func TestCoverageSubscriptionCancellationReactivateAndVerify(t *testing.T) {
	s := apitest.New(t, nil)
	c, _ := s.Login(t, s.Register(t, "cvsubs"))
	other, _ := s.Login(t, s.Register(t, "cvsubssnoop"))
	today := todayIn(t, "Asia/Kolkata")
	sub := sgCreateSub(t, c, map[string]any{"name": "StreamFlix", "amount": "499", "billing_frequency": "monthly",
		"start_date":             today.AddDate(0, -3, 0).Format(day),
		"cancellation_checklist": []map[string]any{{"item": "Download history", "done": false}}})
	sid := sub["id"].(string)

	// Verify: any status, records last_verified_at, optionally version-checked.
	if r := c.Do(t, http.MethodPost, "/subscriptions/"+sid+"/verify?version=99", nil); r.ErrorCode() != "VERSION_CONFLICT" {
		t.Fatalf("stale verify: %s", r.Raw)
	}
	other.Do(t, http.MethodPost, "/subscriptions/"+sid+"/verify", nil).Expect(t, http.StatusNotFound)
	v := c.Do(t, http.MethodPost, "/subscriptions/"+sid+"/verify?version="+sgVersion(sub), map[string]any{"note": "Checked the bank app"}).
		Expect(t, http.StatusOK).Data()
	if v["last_verified_at"] == nil || v["status"] != "active" || v["version"].(float64) != sub["version"].(float64)+1 {
		t.Fatalf("verified = %v", v)
	}
	if ev := sgEvents(v, "verified"); len(ev) != 1 || ev[0]["note"] != "Checked the bank app" {
		t.Fatalf("verify events = %v", v["events"])
	}

	// Cancellation started: active → cancellation_pending, checklist kept,
	// renewal kept (it may still renew until the provider confirms).
	gfField(t, c.Do(t, http.MethodPost, "/subscriptions/"+sid+"/cancellation-started", map[string]any{"cancelled_on": today.Format(day)}), "body.cancelled_on")
	other.Do(t, http.MethodPost, "/subscriptions/"+sid+"/cancellation-started", nil).Expect(t, http.StatusNotFound)
	cs := c.Do(t, http.MethodPost, "/subscriptions/"+sid+"/cancellation-started", map[string]any{"effective_on": today.AddDate(0, 0, -1).Format(day)}).
		Expect(t, http.StatusOK).Data()
	if cs["status"] != "cancellation_pending" || cs["next_renewal_date"] == nil || len(cs["cancellation_checklist"].([]any)) != 1 {
		t.Fatalf("cancellation started = %v", cs)
	}
	if ev := sgEvents(cs, "cancellation_started"); len(ev) != 1 || ev[0]["occurred_on"] != today.AddDate(0, 0, -1).Format(day) {
		t.Fatalf("cancellation_started events = %v", cs["events"])
	}
	gfCoded(t, c.Do(t, http.MethodPost, "/subscriptions/"+sid+"/cancellation-started", nil), http.StatusUnprocessableEntity, "DOMAIN_RULE_VIOLATION",
		"invalid_status_transition")
	// Verify works while pending too.
	c.Do(t, http.MethodPost, "/subscriptions/"+sid+"/verify", nil).Expect(t, http.StatusOK)

	// Reactivate from cancellation_pending: back to active.
	ra := c.Do(t, http.MethodPost, "/subscriptions/"+sid+"/reactivate", nil).Expect(t, http.StatusOK).Data()
	if ra["status"] != "active" || ra["next_renewal_date"] == nil || ra["next_renewal_date"].(string) < today.Format(day) {
		t.Fatalf("reactivated from pending = %v", ra)
	}
	gfCoded(t, c.Do(t, http.MethodPost, "/subscriptions/"+sid+"/reactivate", nil), http.StatusUnprocessableEntity, "DOMAIN_RULE_VIOLATION",
		"invalid_status_transition")
	// Reactivate from cancelled: the renewal date comes back on or after today.
	cx := c.Do(t, http.MethodPost, "/subscriptions/"+sid+"/cancelled", map[string]any{"confirm": true}).Expect(t, http.StatusOK).Data()
	if cx["next_renewal_date"] != nil || cx["cancelled_on"] == nil {
		t.Fatalf("cancelled = %v", cx)
	}
	c.Do(t, http.MethodPost, "/subscriptions/"+sid+"/verify", nil).Expect(t, http.StatusOK) // verify also works once cancelled
	if r := c.Do(t, http.MethodPost, "/subscriptions/"+sid+"/reactivate?version=1", nil); r.ErrorCode() != "VERSION_CONFLICT" {
		t.Fatalf("stale reactivate: %s", r.Raw)
	}
	other.Do(t, http.MethodPost, "/subscriptions/"+sid+"/reactivate", nil).Expect(t, http.StatusNotFound)
	re := c.Do(t, http.MethodPost, "/subscriptions/"+sid+"/reactivate", map[string]any{"note": "Signed up again"}).Expect(t, http.StatusOK).Data()
	if re["status"] != "active" || re["cancelled_on"] != nil || re["cancelled_at"] != nil || re["next_renewal_date"] == nil ||
		re["next_renewal_date"].(string) < today.Format(day) {
		t.Fatalf("reactivated from cancelled = %v", re)
	}
	if ev := sgEvents(re, "reactivated"); len(ev) != 2 || ev[0]["note"] != "Signed up again" && ev[1]["note"] != "Signed up again" {
		t.Fatalf("reactivated events = %v", re["events"])
	}
	for action, want := range map[string]int{"cancellation_started": 1, "reactivate": 2, "verify": 3} {
		if n := workerCount(t, s, `select count(*) from audit_events where entity_type = 'subscription' and entity_id = $1 and action = $2`, sid, action); n != want {
			t.Fatalf("%s audit rows = %d, want %d", action, n, want)
		}
	}
	// Paused subscriptions can start cancelling; a paused one cannot be reactivated.
	c.Do(t, http.MethodPost, "/subscriptions/"+sid+"/pause", nil).Expect(t, http.StatusOK)
	gfCoded(t, c.Do(t, http.MethodPost, "/subscriptions/"+sid+"/reactivate", nil), http.StatusUnprocessableEntity, "DOMAIN_RULE_VIOLATION",
		"invalid_status_transition")
	c.Do(t, http.MethodPost, "/subscriptions/"+sid+"/cancellation-started", nil).Expect(t, http.StatusOK)
}
