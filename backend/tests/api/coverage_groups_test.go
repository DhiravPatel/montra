package api_test

import (
	"net/http"
	"slices"
	"testing"

	"montra/backend/internal/testutil/apitest"
)

// Coverage for group endpoints no other API test exercised: declining join
// requests, stopping recurring shared expenses, listing settlements and
// unlinking a settlement's personal account record.

// cvActivityKinds returns the kinds in a group's activity feed.
func cvActivityKinds(t *testing.T, c *apitest.Client, gid string) []string {
	t.Helper()
	var out []string
	for _, x := range c.Do(t, http.MethodGet, "/groups/"+gid+"/activity", nil).Expect(t, http.StatusOK).Data()["events"].([]any) {
		out = append(out, x.(map[string]any)["kind"].(string))
	}
	return out
}

func TestCoverageGroupJoinRequestDecline(t *testing.T) {
	s := apitest.New(t, nil)
	o := newPerson(t, s, "cvjrowner", nil)
	m := newPerson(t, s, "cvjrmember", nil)
	y := newPerson(t, s, "cvjrasker", nil)
	z := newPerson(t, s, "cvjrstranger", nil)
	gid := createGroup(t, o.c, map[string]any{"name": "Book club", "group_type": "friends", "base_currency": "INR"})["id"].(string)
	joinByLink(t, o, m, gid)

	jr := y.c.Do(t, http.MethodPost, "/groups/"+gid+"/join-requests", map[string]any{"message": "Hi"}).Expect(t, http.StatusCreated).Data()
	rid := jr["id"].(string)
	// Only admins decide: a plain member is refused, a non-member sees nothing.
	if r := m.c.Do(t, http.MethodPost, "/groups/"+gid+"/join-requests/"+rid+"/decline", nil); r.Status != http.StatusForbidden || r.ErrorCode() != "FORBIDDEN" {
		t.Fatalf("member declining: %d %s", r.Status, r.Raw)
	}
	z.c.Do(t, http.MethodPost, "/groups/"+gid+"/join-requests/"+rid+"/decline", nil).Expect(t, http.StatusNotFound)
	y.c.Do(t, http.MethodPost, "/groups/"+gid+"/join-requests/"+rid+"/decline", nil).Expect(t, http.StatusNotFound)

	d := o.c.Do(t, http.MethodPost, "/groups/"+gid+"/join-requests/"+rid+"/decline", nil).Expect(t, http.StatusOK).Data()
	if d["id"] != gid || d["member_count"] != float64(2) {
		t.Fatalf("decline result = %v", d)
	}
	// The requester did not join; the request is no longer pending and
	// cannot be decided again (approve included).
	y.c.Do(t, http.MethodGet, "/groups/"+gid, nil).Expect(t, http.StatusNotFound)
	if l := o.c.Do(t, http.MethodGet, "/groups/"+gid+"/join-requests", nil).Expect(t, http.StatusOK).List(); len(l) != 0 {
		t.Fatalf("pending requests after decline = %v", l)
	}
	o.c.Do(t, http.MethodPost, "/groups/"+gid+"/join-requests/"+rid+"/decline", nil).Expect(t, http.StatusNotFound)
	o.c.Do(t, http.MethodPost, "/groups/"+gid+"/join-requests/"+rid+"/approve", nil).Expect(t, http.StatusNotFound)
	if n := workerCount(t, s, `select count(*) from audit_events where entity_type = 'group_join_request' and entity_id = $1 and action = 'declined'
		and actor_user_id = $2`, rid, o.id); n != 1 {
		t.Fatalf("decline audit rows = %d", n)
	}
	if n := workerCount(t, s, `select count(*) from group_join_requests where id = $1 and status = 'declined' and decided_by = $2 and decided_at is not null`,
		rid, o.id); n != 1 {
		t.Fatal("declined request not persisted with its decider")
	}
	// A declined requester may ask again; that new request can be approved.
	again := y.c.Do(t, http.MethodPost, "/groups/"+gid+"/join-requests", map[string]any{}).Expect(t, http.StatusCreated).Data()
	if again["id"] == rid || again["status"] != "pending" {
		t.Fatalf("second request = %v", again)
	}
	o.c.Do(t, http.MethodPost, "/groups/"+gid+"/join-requests/"+again["id"].(string)+"/approve", nil).Expect(t, http.StatusOK)
	y.c.Do(t, http.MethodGet, "/groups/"+gid, nil).Expect(t, http.StatusOK)
	// Malformed request ids are validation errors.
	if r := o.c.Do(t, http.MethodPost, "/groups/"+gid+"/join-requests/nope/decline", nil); r.Status != http.StatusUnprocessableEntity {
		t.Fatalf("malformed request id: %d", r.Status)
	}
}

func TestCoverageGroupRecurringStop(t *testing.T) {
	s := apitest.New(t, nil)
	a := newPerson(t, s, "cvrsowner", nil)
	b := newPerson(t, s, "cvrsmember", nil)
	z := newPerson(t, s, "cvrsstranger", nil)
	gid := createGroup(t, a.c, map[string]any{"name": "Flat", "group_type": "household", "base_currency": "INR", "timezone": "UTC"})["id"].(string)
	joinByLink(t, a, b, gid)
	both := gfPeople(a, b)
	today := utcToday().Format("2006-01-02")
	rule := a.c.Do(t, http.MethodPost, "/groups/"+gid+"/recurring-expenses", map[string]any{"name": "Internet", "frequency": "weekly",
		"start_date": today, "amount": "700", "participants": both}, "Idempotency-Key", key()).Expect(t, http.StatusCreated).Data()
	rid := rule["rule"].(map[string]any)["id"].(string)
	generate(t, s, 1)
	got := a.c.Do(t, http.MethodGet, "/groups/"+gid+"/recurring-expenses/"+rid, nil).Expect(t, http.StatusOK).Data()
	occs := got["occurrences"].([]any)
	if len(occs) < 2 {
		t.Fatalf("occurrences before stop = %v", occs)
	}
	// Add today's occurrence so there is history to keep.
	first := occs[len(occs)-1].(map[string]any)
	if first["occurrence_date"] != today {
		t.Fatalf("first occurrence = %v", first)
	}
	exp := b.c.Do(t, http.MethodPost, "/groups/"+gid+"/recurring-expenses/"+rid+"/occurrences/"+first["id"].(string)+"/add", nil, "Idempotency-Key", key()).
		Expect(t, http.StatusCreated).Data()

	// Only the creator or an admin stops it; strangers see nothing.
	if r := b.c.Do(t, http.MethodPost, "/groups/"+gid+"/recurring-expenses/"+rid+"/stop", nil); r.Status != http.StatusForbidden {
		t.Fatalf("member stopping someone else's rule: %d %s", r.Status, r.Raw)
	}
	z.c.Do(t, http.MethodPost, "/groups/"+gid+"/recurring-expenses/"+rid+"/stop", nil).Expect(t, http.StatusNotFound)
	a.c.Do(t, http.MethodPost, "/groups/"+gid+"/recurring-expenses/"+key()+"/stop", nil).Expect(t, http.StatusNotFound)

	st := a.c.Do(t, http.MethodPost, "/groups/"+gid+"/recurring-expenses/"+rid+"/stop", nil).Expect(t, http.StatusOK).Data()
	r := st["rule"].(map[string]any)
	if r["status"] != "ended" || r["version"].(float64) <= rule["rule"].(map[string]any)["version"].(float64) {
		t.Fatalf("stopped rule = %v", r)
	}
	// Future open occurrences are removed; the added one and its expense stay.
	var open int
	var kept bool
	for _, x := range st["occurrences"].([]any) {
		o := x.(map[string]any)
		if o["status"] == "scheduled" && o["occurrence_date"].(string) > today {
			open++
		}
		if o["id"] == first["id"] && o["group_expense_id"] == exp["id"] {
			kept = true
		}
	}
	if open != 0 || !kept {
		t.Fatalf("occurrences after stop = %v", st["occurrences"])
	}
	b.c.Do(t, http.MethodGet, "/groups/"+gid+"/expenses/"+exp["id"].(string), nil).Expect(t, http.StatusOK)
	// The scheduler adds nothing more for a stopped rule.
	generate(t, s, 2)
	after := a.c.Do(t, http.MethodGet, "/groups/"+gid+"/recurring-expenses/"+rid, nil).Expect(t, http.StatusOK).Data()
	if len(after["occurrences"].([]any)) != len(st["occurrences"].([]any)) {
		t.Fatalf("occurrences generated after stop: %v", after["occurrences"])
	}
	// Ended is final: stopping or pausing again, or resuming, is refused.
	gfCoded(t, a.c.Do(t, http.MethodPost, "/groups/"+gid+"/recurring-expenses/"+rid+"/stop", nil), http.StatusUnprocessableEntity,
		"DOMAIN_RULE_VIOLATION", "invalid_status_transition")
	gfCoded(t, a.c.Do(t, http.MethodPost, "/groups/"+gid+"/recurring-expenses/"+rid+"/pause", nil), http.StatusUnprocessableEntity,
		"DOMAIN_RULE_VIOLATION", "invalid_status_transition")
	gfCoded(t, a.c.Do(t, http.MethodPost, "/groups/"+gid+"/recurring-expenses/"+rid+"/resume", nil), http.StatusConflict, "CONFLICT", "schedule_ended")
	if k := cvActivityKinds(t, b.c, gid); !slices.Contains(k, "recurring_expense_stopped") {
		t.Fatalf("activity after stop = %v", k)
	}
	// Still listed (history kept) with its ended status.
	l := b.c.Do(t, http.MethodGet, "/groups/"+gid+"/recurring-expenses", nil).Expect(t, http.StatusOK).List()
	if len(l) != 1 || l[0].(map[string]any)["rule"].(map[string]any)["id"] != rid || l[0].(map[string]any)["rule"].(map[string]any)["status"] != "ended" {
		t.Fatalf("recurring list after stop = %v", l)
	}
}

func TestCoverageGroupSettlementsListAndUnlink(t *testing.T) {
	s := apitest.New(t, nil)
	a := newPerson(t, s, "cvslpayee", nil)
	b := newPerson(t, s, "cvslpayer", nil)
	z := newPerson(t, s, "cvslstranger", nil)
	gid := createGroup(t, a.c, map[string]any{"name": "Trip", "group_type": "trip", "base_currency": "INR", "timezone": "UTC"})["id"].(string)
	joinByLink(t, a, b, gid)
	gfExpense(t, a, gid, map[string]any{"description": "Hotel", "amount": "3000", "split_method": "equal", "participants": gfPeople(a, b)})
	acctB := createAccount(t, b.c, map[string]any{"name": "B bank", "account_type": "bank", "currency": "INR", "opening_balance": "10000"})["id"].(string)
	settle := func(body map[string]any) map[string]any {
		body["payer_user_id"], body["payee_user_id"] = b.id, a.id
		return b.c.Do(t, http.MethodPost, "/groups/"+gid+"/settlements", body, "Idempotency-Key", key()).Expect(t, http.StatusCreated).Data()
	}
	s1 := settle(map[string]any{"amount": "500", "settled_on": "2026-10-01", "method": "upi", "account_id": acctB})
	s2 := settle(map[string]any{"amount": "300", "settled_on": "2026-10-05", "note": "Oops"})
	s3 := settle(map[string]any{"amount": "200", "settled_on": "2026-10-03", "state": "proposed"})
	cf := a.c.Do(t, http.MethodPost, "/groups/"+gid+"/settlements/"+s1["id"].(string)+"/confirm", map[string]any{"version": s1["version"]}).Expect(t, http.StatusOK).Data()
	a.c.Do(t, http.MethodPost, "/groups/"+gid+"/settlements/"+s2["id"].(string)+"/void", map[string]any{"version": s2["version"], "reason": "Duplicate"}).Expect(t, http.StatusOK)

	// List: newest settled first, voided hidden unless asked for; both
	// members see the same list; each sees only their own account record.
	l := a.c.Do(t, http.MethodGet, "/groups/"+gid+"/settlements", nil).Expect(t, http.StatusOK).List()
	if got := ids(l, "id"); !slices.Equal(got, []string{s3["id"].(string), s1["id"].(string)}) {
		t.Fatalf("settlements = %v", got)
	}
	first, second := l[0].(map[string]any), l[1].(map[string]any)
	if first["status"] != "proposed" || first["counted"] != false || money(first, "amount") != "200.00" || first["settled_on"] != "2026-10-03" {
		t.Fatalf("proposed settlement = %v", first)
	}
	if second["status"] != "confirmed" || second["counted"] != true || second["confirmed_by"] != a.id || second["method"] != "upi" ||
		second["my_transaction_id"] != nil {
		t.Fatalf("confirmed settlement as the payee = %v", second)
	}
	lb := b.c.Do(t, http.MethodGet, "/groups/"+gid+"/settlements", nil).Expect(t, http.StatusOK).List()
	if mine := gfFind(lb, "id", s1["id"].(string)); mine == nil || mine["my_transaction_id"] != s1["my_transaction_id"] || mine["my_transaction_id"] == nil {
		t.Fatalf("payer's view of the settlement = %v", mine)
	}
	all := a.c.Do(t, http.MethodGet, "/groups/"+gid+"/settlements?include_voided=true", nil).Expect(t, http.StatusOK).List()
	if got := ids(all, "id"); !slices.Equal(got, []string{s2["id"].(string), s3["id"].(string), s1["id"].(string)}) ||
		gfFind(all, "id", s2["id"].(string))["void_reason"] != "Duplicate" {
		t.Fatalf("settlements with voided = %v", all)
	}
	z.c.Do(t, http.MethodGet, "/groups/"+gid+"/settlements", nil).Expect(t, http.StatusNotFound)

	// Unlink: removes only the caller's account record; the settlement and
	// the group balances are untouched.
	if balance(t, b.c, acctB) != "9500.00" {
		t.Fatalf("payer balance with the record = %s", balance(t, b.c, acctB))
	}
	balBefore := netOf(a.c.Do(t, http.MethodGet, "/groups/"+gid+"/balances", nil).Expect(t, http.StatusOK).Data(), b.id)
	path := "/groups/" + gid + "/settlements/" + s1["id"].(string) + "/unlink"
	if r := b.c.Do(t, http.MethodPost, path, map[string]any{"version": 99}); r.ErrorCode() != "VERSION_CONFLICT" {
		t.Fatalf("stale unlink: %s", r.Raw)
	}
	a.c.Do(t, http.MethodPost, path, map[string]any{"version": cf["version"]}).Expect(t, http.StatusNotFound) // the payee has no record
	z.c.Do(t, http.MethodPost, path, map[string]any{"version": cf["version"]}).Expect(t, http.StatusNotFound)
	un := b.c.Do(t, http.MethodPost, path, map[string]any{"version": cf["version"]}).Expect(t, http.StatusOK).Data()
	if un["my_transaction_id"] != nil || un["status"] != "confirmed" || un["version"] != cf["version"] {
		t.Fatalf("after unlink = %v", un)
	}
	if balance(t, b.c, acctB) != "10000.00" {
		t.Fatalf("payer balance after unlink = %s", balance(t, b.c, acctB))
	}
	if tx := b.c.Do(t, http.MethodGet, "/transactions/"+s1["my_transaction_id"].(string), nil).Expect(t, http.StatusOK).Data(); tx["status"] != "voided" {
		t.Fatalf("unlinked record = %v", tx)
	}
	if after := netOf(a.c.Do(t, http.MethodGet, "/groups/"+gid+"/balances", nil).Expect(t, http.StatusOK).Data(), b.id); after != balBefore {
		t.Fatalf("group balance changed by unlink: %s -> %s", balBefore, after)
	}
	gfCodedNotFound(t, b.c.Do(t, http.MethodPost, path, map[string]any{"version": cf["version"]}))
	// Recording again works after an unlink.
	re := b.c.Do(t, http.MethodPost, "/groups/"+gid+"/settlements/"+s1["id"].(string)+"/record", map[string]any{"version": un["version"], "account_id": acctB}).
		Expect(t, http.StatusOK).Data()
	if re["my_transaction_id"] == nil || balance(t, b.c, acctB) != "9500.00" {
		t.Fatalf("record after unlink = %v (%s)", re["my_transaction_id"], balance(t, b.c, acctB))
	}
	// Unlink is the one action still allowed on a voided settlement.
	s4 := settle(map[string]any{"amount": "100", "account_id": acctB})
	v := b.c.Do(t, http.MethodPost, "/groups/"+gid+"/settlements/"+s4["id"].(string)+"/void", map[string]any{"version": s4["version"], "reason": "Wrong"}).
		Expect(t, http.StatusOK).Data()
	if v["my_transaction_id"] != nil { // voiding already removed the voider's record
		t.Fatalf("voided settlement still has the voider's record: %v", v)
	}
	gfCodedNotFound(t, b.c.Do(t, http.MethodPost, "/groups/"+gid+"/settlements/"+s4["id"].(string)+"/unlink", map[string]any{"version": v["version"]}))
	gfCoded(t, b.c.Do(t, http.MethodPost, "/groups/"+gid+"/settlements/"+s4["id"].(string)+"/record", map[string]any{"version": v["version"], "account_id": acctB}),
		http.StatusConflict, "CONFLICT", "settlement_voided")
}

func gfCodedNotFound(t *testing.T, r *apitest.Response) {
	t.Helper()
	if r.Status != http.StatusNotFound || r.ErrorCode() != "NOT_FOUND" {
		t.Fatalf("want 404 NOT_FOUND, got %d %s", r.Status, r.Raw)
	}
}
