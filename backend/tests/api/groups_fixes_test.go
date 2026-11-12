package api_test

import (
	"fmt"
	"net/http"
	"net/url"
	"regexp"
	"slices"
	"strconv"
	"strings"
	"testing"
	"time"

	"github.com/google/uuid"

	"montra/backend/internal/testutil/apitest"
)

// Regression tests for the groups issues reported by the web client
// (groups, members, invitations, expenses, settlements, recurring bills).

// gfCoded asserts an error's status, top-level code and detail code, and
// returns the detail params.
func gfCoded(t *testing.T, r *apitest.Response, status int, code, reason string) map[string]any {
	t.Helper()
	if r.Status != status || r.ErrorCode() != code || detail(t, r)["code"] != reason {
		t.Fatalf("want %d %s/%s, got %d %s", status, code, reason, r.Status, r.Raw)
	}
	p, _ := detail(t, r)["params"].(map[string]any)
	return p
}

// gfField asserts a validation error naming one request field.
func gfField(t *testing.T, r *apitest.Response, field string) {
	t.Helper()
	if r.Status != http.StatusUnprocessableEntity || r.ErrorCode() != "VALIDATION_ERROR" || detail(t, r)["field"] != field {
		t.Fatalf("want 422 on %s, got %d %s", field, r.Status, r.Raw)
	}
}

// gfLinks returns the deep links (and entity types) of a person's
// notifications of one event type.
func gfLinks(t *testing.T, c *apitest.Client, category, event string) []string {
	t.Helper()
	var out []string
	for _, x := range c.Do(t, http.MethodGet, "/notifications?category="+category, nil).Expect(t, http.StatusOK).List() {
		n := x.(map[string]any)
		if n["event_type"] == event {
			out = append(out, fmt.Sprint(n["deep_link"], " ", n["entity_type"]))
		}
	}
	return out
}

func gfMap(v any) map[string]any {
	m, _ := v.(map[string]any)
	return m
}

func gfFind(list []any, field, value string) map[string]any {
	for _, x := range list {
		if m := gfMap(x); m[field] == value {
			return m
		}
	}
	return nil
}

func gfPeople(ps ...person) []any {
	out := make([]any, len(ps))
	for i, p := range ps {
		out[i] = map[string]any{"user_id": p.id}
	}
	return out
}

func gfExpense(t *testing.T, p person, gid string, body map[string]any) map[string]any {
	t.Helper()
	return p.c.Do(t, http.MethodPost, "/groups/"+gid+"/expenses", body, "Idempotency-Key", key()).Expect(t, http.StatusCreated).Data()
}

// G1 and G4: the caller's balance in the group list, and a partial PATCH.
func TestGroupsMyNetAndPartialSettingsUpdate(t *testing.T) {
	s := apitest.New(t, nil)
	a := newPerson(t, s, "netter", nil)
	b := newPerson(t, s, "owing", nil)
	g := createGroup(t, a.c, map[string]any{"name": "Goa Trip", "group_type": "trip", "base_currency": "INR", "timezone": "UTC",
		"description": "Beach week", "rules": "Split fuel equally", "default_split_method": "shares", "simplify_debts": false,
		"allow_member_invites": false, "start_date": "2026-12-20", "end_date": "2026-12-24", "destination": "Goa"})
	gid := g["id"].(string)
	if g["require_join_approval"] != false || money(g, "my_net") != "0.00" {
		t.Fatalf("new group = %v", g)
	}
	joinByLink(t, a, b, gid)
	both := gfPeople(a, b)

	// my_net counts expenses that are not deleted and confirmed settlements
	// only, exactly like the balances.
	gfExpense(t, a, gid, map[string]any{"description": "Hotel", "amount": "100", "split_method": "equal", "participants": both})
	snacks := gfExpense(t, b, gid, map[string]any{"description": "Snacks", "amount": "30", "split_method": "equal", "participants": both})
	b.c.Do(t, http.MethodDelete, "/groups/"+gid+"/expenses/"+snacks["id"].(string), nil).Expect(t, http.StatusOK)
	if st := a.c.Do(t, http.MethodPost, "/groups/"+gid+"/settlements", map[string]any{"payer_user_id": b.id, "payee_user_id": a.id, "amount": "20"},
		"Idempotency-Key", key()).Expect(t, http.StatusCreated).Data(); st["status"] != "confirmed" {
		t.Fatalf("payee-recorded settlement = %v", st)
	}
	b.c.Do(t, http.MethodPost, "/groups/"+gid+"/settlements", map[string]any{"payer_user_id": b.id, "payee_user_id": a.id, "amount": "5"},
		"Idempotency-Key", key()).Expect(t, http.StatusCreated)
	for _, x := range []struct {
		p    person
		want string
	}{{a, "30.00"}, {b, "-30.00"}} {
		listed := gfFind(x.p.c.Do(t, http.MethodGet, "/groups", nil).Expect(t, http.StatusOK).List(), "id", gid)
		bal := x.p.c.Do(t, http.MethodGet, "/groups/"+gid+"/balances", nil).Expect(t, http.StatusOK).Data()
		got := x.p.c.Do(t, http.MethodGet, "/groups/"+gid, nil).Expect(t, http.StatusOK).Data()
		if listed == nil || money(listed, "my_net") != x.want || money(bal, "my_net") != x.want || money(got, "my_net") != x.want ||
			gfMap(listed["my_net"])["currency"] != "INR" {
			t.Fatalf("%s: list %v, balances %v, detail %v; want %s", x.p.user, listed["my_net"], bal["my_net"], got["my_net"], x.want)
		}
	}

	// PATCH changes only what is sent: the editor's time zone (Asia/Kolkata)
	// and the defaults (true, equal) no longer replace omitted settings.
	up := a.c.Do(t, http.MethodPatch, "/groups/"+gid, map[string]any{"name": "Goa 2026", "version": g["version"]}).Expect(t, http.StatusOK).Data()
	if up["name"] != "Goa 2026" || up["description"] != "Beach week" || up["rules"] != "Split fuel equally" || up["timezone"] != "UTC" ||
		up["default_split_method"] != "shares" || up["simplify_debts"] != false || up["allow_member_invites"] != false ||
		up["require_join_approval"] != false || up["start_date"] != "2026-12-20" || up["end_date"] != "2026-12-24" ||
		up["destination"] != "Goa" || up["base_currency"] != "INR" || up["group_type"] != "trip" {
		t.Fatalf("partial update = %v", up)
	}
	// "" clears text and dates; booleans change only when sent.
	up = a.c.Do(t, http.MethodPatch, "/groups/"+gid, map[string]any{"description": "", "end_date": "", "destination": "", "simplify_debts": true,
		"version": up["version"]}).Expect(t, http.StatusOK).Data()
	if up["description"] != nil || up["end_date"] != nil || up["destination"] != nil || up["simplify_debts"] != true ||
		up["rules"] != "Split fuel equally" || up["start_date"] != "2026-12-20" || up["allow_member_invites"] != false {
		t.Fatalf("clearing = %v", up)
	}
	if r := a.c.Do(t, http.MethodPatch, "/groups/"+gid, map[string]any{"name": "No version"}); r.Status != http.StatusUnprocessableEntity {
		t.Fatalf("PATCH without version: %d %s", r.Status, r.Raw)
	}
	if r := a.c.Do(t, http.MethodPatch, "/groups/"+gid, map[string]any{"name": "Stale", "version": g["version"]}); r.ErrorCode() != "VERSION_CONFLICT" {
		t.Fatalf("stale PATCH: %s", r.Raw)
	}
	// The create validation applies to what is sent.
	gfField(t, a.c.Do(t, http.MethodPatch, "/groups/"+gid, map[string]any{"timezone": "Mars/Olympus", "version": up["version"]}), "body.timezone")
	gfField(t, a.c.Do(t, http.MethodPatch, "/groups/"+gid, map[string]any{"end_date": "2026-12-01", "version": up["version"]}), "body.end_date")
	gfField(t, a.c.Do(t, http.MethodPatch, "/groups/"+gid, map[string]any{"start_date": "2026-13-01", "version": up["version"]}), "body.start_date")
	gfCoded(t, a.c.Do(t, http.MethodPatch, "/groups/"+gid, map[string]any{"base_currency": "EUR", "version": up["version"]}),
		http.StatusUnprocessableEntity, "DOMAIN_RULE_VIOLATION", "currency_locked")
	if r := b.c.Do(t, http.MethodPatch, "/groups/"+gid, map[string]any{"name": "Hijack", "version": up["version"]}); r.Status != http.StatusForbidden {
		t.Fatalf("member PATCH: %d", r.Status)
	}
	// Before any record the currency can still change, and only it changes.
	other := createGroup(t, a.c, map[string]any{"name": "Empty", "group_type": "friends", "base_currency": "INR", "timezone": "UTC"})
	moved := a.c.Do(t, http.MethodPatch, "/groups/"+other["id"].(string), map[string]any{"base_currency": "EUR", "version": other["version"]}).
		Expect(t, http.StatusOK).Data()
	if moved["base_currency"] != "EUR" || moved["timezone"] != "UTC" || moved["name"] != "Empty" || gfMap(moved["my_net"])["currency"] != "EUR" {
		t.Fatalf("currency change = %v", moved)
	}
}

// G2, G3, G5, G6 and G7: link previews, join approval, people in
// invitations, friends by user ID, and coded invitation conflicts.
func TestGroupJoinApprovalPreviewAndInvitations(t *testing.T) {
	s := apitest.New(t, nil)
	o := newPerson(t, s, "host", nil)
	x := newPerson(t, s, "linkholder", map[string]any{"discoverable_by_username": false})
	d := newPerson(t, s, "named", nil)
	f := newPerson(t, s, "buddy", map[string]any{"discoverable_by_username": false})
	stranger := newPerson(t, s, "stranger", map[string]any{"discoverable_by_username": false})
	g := createGroup(t, o.c, map[string]any{"name": "Flat 9", "group_type": "roommates", "base_currency": "INR"})
	gid := g["id"].(string)

	// Groups no longer require approval unless an admin turns it on (the
	// column default is false as well).
	if g["require_join_approval"] != false {
		t.Fatalf("new group = %v", g)
	}
	raw := uuid.New()
	s.Env.ExecWorker(t, `insert into groups (id, created_by, name, group_type, base_currency, timezone) values ($1,$2,'Raw','friends','INR','UTC')`, raw, o.id)
	if workerCount(t, s, `select count(*) from groups where id = $1 and not require_join_approval`, raw) != 1 {
		t.Fatal("the column default must be false")
	}

	// The preview names the group, its size and who shared the link.
	inv := o.c.Do(t, http.MethodPost, "/groups/"+gid+"/invitations", map[string]any{"kind": "link", "max_uses": 3}).Expect(t, http.StatusCreated).Data()
	tok := map[string]any{"token": inv["token"]}
	pv := x.c.Do(t, http.MethodPost, "/group-invitations/preview", tok).Expect(t, http.StatusOK).Data()
	by := gfMap(pv["invited_by"])
	if pv["group_id"] != gid || pv["group_name"] != "Flat 9" || pv["group_type"] != "roommates" || pv["member_count"] != float64(1) ||
		pv["already_member"] != false || pv["requires_approval"] != false || pv["status"] != "active" ||
		by["display_name"] != "Test host" || by["username"] != o.user || by["user_id"] != nil {
		t.Fatalf("preview = %v", pv)
	}

	// With approval on, accepting the link creates a join request (202).
	cur := o.c.Do(t, http.MethodGet, "/groups/"+gid, nil).Expect(t, http.StatusOK).Data()
	o.c.Do(t, http.MethodPatch, "/groups/"+gid, map[string]any{"require_join_approval": true, "version": cur["version"]}).Expect(t, http.StatusOK)
	if x.c.Do(t, http.MethodPost, "/group-invitations/preview", tok).Expect(t, http.StatusOK).Data()["requires_approval"] != true {
		t.Fatal("preview must say approval is required")
	}
	jr := x.c.Do(t, http.MethodPost, "/group-invitations/accept", tok).Expect(t, http.StatusAccepted).Data()
	if jr["status"] != "pending" || jr["group_id"] != gid || jr["user_id"] != x.id || jr["invitation_id"] != inv["id"] ||
		jr["display_name"] != "Test linkholder" {
		t.Fatalf("join request = %v", jr)
	}
	if r := x.c.Do(t, http.MethodGet, "/groups/"+gid, nil); r.Status != http.StatusNotFound {
		t.Fatalf("a pending requester must not be a member: %d", r.Status)
	}
	gfCoded(t, x.c.Do(t, http.MethodPost, "/group-invitations/accept", tok), http.StatusConflict, "CONFLICT", "join_request_pending")
	gfCoded(t, x.c.Do(t, http.MethodPost, "/groups/"+gid+"/join-requests", map[string]any{}), http.StatusConflict, "CONFLICT", "join_request_pending")
	s.RunJobs(t)
	if l := gfLinks(t, o.c, "group", "join_requested"); len(l) != 1 || l[0] != "/groups/"+gid+"/settings group_join_request" {
		t.Fatalf("join request notification links = %v", l)
	}
	reqs := o.c.Do(t, http.MethodGet, "/groups/"+gid+"/join-requests", nil).Expect(t, http.StatusOK).List()
	if len(reqs) != 1 || gfMap(reqs[0])["invitation_id"] != inv["id"] || gfMap(reqs[0])["group_id"] != gid {
		t.Fatalf("join requests = %v", reqs)
	}
	o.c.Do(t, http.MethodPost, "/groups/"+gid+"/join-requests/"+jr["id"].(string)+"/approve", nil).Expect(t, http.StatusOK)
	if x.c.Do(t, http.MethodGet, "/groups/"+gid, nil).Expect(t, http.StatusOK).Data()["my_role"] != "member" {
		t.Fatal("approved requester is not a member")
	}
	gfCoded(t, x.c.Do(t, http.MethodPost, "/group-invitations/accept", tok), http.StatusConflict, "CONFLICT", "already_member")
	if x.c.Do(t, http.MethodPost, "/group-invitations/preview", tok).Expect(t, http.StatusOK).Data()["already_member"] != true {
		t.Fatal("preview must say you are a member")
	}

	// A username invitation names the person: it joins directly even with
	// approval on, and shows both people's minimal profiles.
	ui := o.c.Do(t, http.MethodPost, "/groups/"+gid+"/members", map[string]any{"username": d.user}).Expect(t, http.StatusCreated).Data()
	if p := gfMap(ui["invitee"]); p["user_id"] != d.id || p["display_name"] != "Test named" || p["username"] != d.user ||
		gfMap(ui["invited_by"])["display_name"] != "Test host" || ui["invitee_user_id"] != d.id {
		t.Fatalf("username invitation = %v", ui)
	}
	s.RunJobs(t)
	if l := gfLinks(t, d.c, "group", "invitation_created"); len(l) != 1 || l[0] != "/groups group_invitation" {
		t.Fatalf("invitation notification links = %v", l)
	}
	mine := d.c.Do(t, http.MethodGet, "/group-invitations", nil).Expect(t, http.StatusOK).List()
	if len(mine) != 1 || gfMap(gfMap(mine[0])["invited_by"])["display_name"] != "Test host" || gfMap(mine[0])["group_name"] != "Flat 9" {
		t.Fatalf("my invitations = %v", mine)
	}
	if d.c.Do(t, http.MethodPost, "/group-invitations/"+ui["id"].(string)+"/accept", nil).Expect(t, http.StatusOK).Data()["my_role"] != "member" {
		t.Fatal("username invitation must join directly")
	}
	gfCoded(t, d.c.Do(t, http.MethodPost, "/group-invitations/"+ui["id"].(string)+"/accept", nil), http.StatusConflict, "CONFLICT", "invitation_used")
	gfCoded(t, d.c.Do(t, http.MethodPost, "/group-invitations/"+ui["id"].(string)+"/decline", nil), http.StatusConflict, "CONFLICT", "invitation_used")
	gfCoded(t, o.c.Do(t, http.MethodDelete, "/groups/"+gid+"/invitations/"+ui["id"].(string), nil), http.StatusConflict, "CONFLICT", "invitation_used")
	gfCoded(t, o.c.Do(t, http.MethodPost, "/groups/"+gid+"/members", map[string]any{"username": d.user}), http.StatusConflict, "CONFLICT", "already_member")

	// Friends who turned discovery off are invited by user ID; strangers
	// stay undiscoverable both ways.
	for _, body := range []map[string]any{{"username": f.user}, {"user_id": f.id}, {"user_id": stranger.id}} {
		if r := o.c.Do(t, http.MethodPost, "/groups/"+gid+"/members", body); r.Status != http.StatusNotFound {
			t.Fatalf("inviting %v before being friends: %d %s", body, r.Status, r.Raw)
		}
	}
	fr := o.c.Do(t, http.MethodPost, "/friend-requests", map[string]any{"user_id": f.id}).Expect(t, http.StatusCreated).Data()
	f.c.Do(t, http.MethodPost, "/friend-requests/"+fr["id"].(string)+"/accept", nil).Expect(t, http.StatusOK)
	fi := o.c.Do(t, http.MethodPost, "/groups/"+gid+"/members", map[string]any{"user_id": f.id}).Expect(t, http.StatusCreated).Data()
	if p := gfMap(fi["invitee"]); p["display_name"] != "Test buddy" || p["username"] != f.user {
		t.Fatalf("friend invitation = %v", fi)
	}
	if r := o.c.Do(t, http.MethodPost, "/groups/"+gid+"/invitations", map[string]any{"kind": "username", "user_id": stranger.id}); r.Status != http.StatusNotFound {
		t.Fatalf("stranger by user ID: %d", r.Status)
	}
	gfField(t, o.c.Do(t, http.MethodPost, "/groups/"+gid+"/members", map[string]any{"username": d.user, "user_id": f.id}), "body.user_id")
	gfField(t, o.c.Do(t, http.MethodPost, "/groups/"+gid+"/members", map[string]any{}), "body.username")
	f.c.Do(t, http.MethodPost, "/group-invitations/"+fi["id"].(string)+"/accept", nil).Expect(t, http.StatusOK)
	gfCoded(t, o.c.Do(t, http.MethodPost, "/groups/"+gid+"/members", map[string]any{"user_id": f.id}), http.StatusConflict, "CONFLICT", "already_member")

	// The admins' list carries both people; revoking is idempotent.
	list := o.c.Do(t, http.MethodGet, "/groups/"+gid+"/invitations?include_inactive=true", nil).Expect(t, http.StatusOK).List()
	link := gfFind(list, "id", inv["id"].(string))
	if link == nil || link["use_count"] != float64(1) || gfMap(link["invited_by"])["display_name"] != "Test host" || link["invitee"] != nil ||
		gfMap(gfFind(list, "id", fi["id"].(string))["invitee"])["display_name"] != "Test buddy" {
		t.Fatalf("invitations = %v", list)
	}
	for i := 0; i < 2; i++ {
		o.c.Do(t, http.MethodDelete, "/groups/"+gid+"/invitations/"+inv["id"].(string), nil).Expect(t, http.StatusOK)
	}
	if r := x.c.Do(t, http.MethodPost, "/group-invitations/accept", tok); r.Status != http.StatusGone {
		t.Fatalf("revoked link: %d", r.Status)
	}

	// Blocks hide a link: it looks invalid to the person on the other side.
	inv2 := o.c.Do(t, http.MethodPost, "/groups/"+gid+"/invitations", map[string]any{"kind": "link"}).Expect(t, http.StatusCreated).Data()
	blocker := newPerson(t, s, "blocker", nil)
	blocker.c.Do(t, http.MethodPost, "/users/"+o.id+"/block", nil).Expect(t, http.StatusOK)
	for _, p := range []string{"/group-invitations/preview", "/group-invitations/accept"} {
		if r := blocker.c.Do(t, http.MethodPost, p, map[string]any{"token": inv2["token"]}); r.Status != http.StatusGone {
			t.Fatalf("%s across a block: %d %s", p, r.Status, r.Raw)
		}
	}
}

// GM1 and GM2: any active member adds an occurrence (the rule lock no
// longer fails under RLS), and creating a recurring expense is idempotent.
func TestGroupRecurringOrdinaryMemberAddsOccurrence(t *testing.T) {
	s := apitest.New(t, nil)
	a := newPerson(t, s, "boss", nil)
	b := newPerson(t, s, "creator", nil)
	c := newPerson(t, s, "ordinary", nil)
	d := newPerson(t, s, "leaver", nil)
	gid := createGroup(t, a.c, map[string]any{"name": "Home", "group_type": "household", "base_currency": "INR", "timezone": "UTC"})["id"].(string)
	for _, p := range []person{b, c, d} {
		joinByLink(t, a, p, gid)
	}
	today := utcToday()
	body := map[string]any{"name": "Internet", "frequency": "weekly", "start_date": today.Format(day), "amount": "700",
		"participants": gfPeople(b, c)}
	if r := b.c.Do(t, http.MethodPost, "/groups/"+gid+"/recurring-expenses", body); r.Status != http.StatusUnprocessableEntity {
		t.Fatalf("create without Idempotency-Key: %d %s", r.Status, r.Raw)
	}
	k := key()
	first := b.c.Do(t, http.MethodPost, "/groups/"+gid+"/recurring-expenses", body, "Idempotency-Key", k).Expect(t, http.StatusCreated)
	again := b.c.Do(t, http.MethodPost, "/groups/"+gid+"/recurring-expenses", body, "Idempotency-Key", k).Expect(t, http.StatusCreated)
	ruleID := gfMap(first.Data()["rule"])["id"].(string)
	if again.Headers.Get("Idempotent-Replayed") != "true" || gfMap(again.Data()["rule"])["id"] != ruleID {
		t.Fatal("a retried create must replay the first rule")
	}
	if n := len(b.c.Do(t, http.MethodGet, "/groups/"+gid+"/recurring-expenses", nil).Expect(t, http.StatusOK).List()); n != 1 {
		t.Fatalf("recurring expenses after a retry = %d", n)
	}
	if r := b.c.Do(t, http.MethodPost, "/groups/"+gid+"/recurring-expenses", map[string]any{"name": "Other", "frequency": "weekly",
		"start_date": today.Format(day), "amount": "1", "participants": gfPeople(b)}, "Idempotency-Key", k); r.ErrorCode() != "IDEMPOTENCY_CONFLICT" {
		t.Fatalf("key reused for another body: %s", r.Raw)
	}
	generate(t, s, 1)
	occs := gfMap(b.c.Do(t, http.MethodGet, "/groups/"+gid+"/recurring-expenses/"+ruleID, nil).Expect(t, http.StatusOK).Data())["occurrences"].([]any)
	firstOcc, second := gfMap(occs[len(occs)-1]), gfMap(occs[len(occs)-2])
	if firstOcc["occurrence_date"] != today.Format(day) {
		t.Fatalf("first occurrence = %v", firstOcc)
	}

	// c is neither the creator nor an admin: adding used to fail with 500.
	add := c.c.Do(t, http.MethodPost, "/groups/"+gid+"/recurring-expenses/"+ruleID+"/occurrences/"+firstOcc["id"].(string)+"/add", nil,
		"Idempotency-Key", key()).Expect(t, http.StatusCreated).Data()
	if add["created_by"] != c.id || money(add, "my_paid") != "700.00" || money(add, "amount") != "700.00" {
		t.Fatalf("added expense = %v", add)
	}
	got := c.c.Do(t, http.MethodGet, "/groups/"+gid+"/recurring-expenses/"+ruleID, nil).Expect(t, http.StatusOK).Data()
	rule := gfMap(got["rule"])
	posted := gfFind(got["occurrences"].([]any), "id", firstOcc["id"].(string))
	if posted["status"] != "posted" || posted["group_expense_id"] != add["id"] {
		t.Fatalf("occurrence after add = %v", posted)
	}
	// The rule's progress is recorded too (completed count, next date).
	if rule["completed_count"] != float64(1) || rule["next_occurrence"] != today.AddDate(0, 0, 7).Format(day) || rule["status"] != "active" {
		t.Fatalf("rule after add = %v", rule)
	}
	p := gfCoded(t, c.c.Do(t, http.MethodPost, "/groups/"+gid+"/recurring-expenses/"+ruleID+"/occurrences/"+firstOcc["id"].(string)+"/add", nil,
		"Idempotency-Key", key()), http.StatusConflict, "CONFLICT", "occurrence_already_handled")
	if p["status"] != "posted" {
		t.Fatalf("params = %v", p)
	}
	// Skipping stays with the creator and the admins.
	if r := c.c.Do(t, http.MethodPost, "/groups/"+gid+"/recurring-expenses/"+ruleID+"/occurrences/"+second["id"].(string)+"/skip", nil); r.Status != http.StatusForbidden {
		t.Fatalf("ordinary member skipping: %d", r.Status)
	}
	b.c.Do(t, http.MethodPost, "/groups/"+gid+"/recurring-expenses/"+ruleID+"/occurrences/"+second["id"].(string)+"/skip", nil).Expect(t, http.StatusOK)
	gfCoded(t, c.c.Do(t, http.MethodPost, "/groups/"+gid+"/recurring-expenses/"+ruleID+"/occurrences/"+second["id"].(string)+"/add", nil,
		"Idempotency-Key", key()), http.StatusConflict, "CONFLICT", "occurrence_already_handled")

	// The add request has no body: a split that no longer works is a coded
	// rule, never a body field.
	rent := a.c.Do(t, http.MethodPost, "/groups/"+gid+"/recurring-expenses", map[string]any{"name": "Rent", "frequency": "monthly",
		"start_date": today.Format(day), "amount": "900", "participants": gfPeople(a, c, d)}, "Idempotency-Key", key()).Expect(t, http.StatusCreated).Data()
	d.c.Do(t, http.MethodDelete, "/groups/"+gid+"/members/"+d.id, nil).Expect(t, http.StatusOK)
	rentOccs := rent["occurrences"].([]any)
	rentOcc := gfMap(rentOccs[len(rentOccs)-1])["id"].(string)
	p = gfCoded(t, c.c.Do(t, http.MethodPost, "/groups/"+gid+"/recurring-expenses/"+gfMap(rent["rule"])["id"].(string)+"/occurrences/"+rentOcc+"/add",
		nil, "Idempotency-Key", key()), http.StatusUnprocessableEntity, "DOMAIN_RULE_VIOLATION", "recurring_member_inactive")
	if p["user_id"] != d.id {
		t.Fatalf("params = %v", p)
	}
	s.RunJobs(t)
	if l := gfLinks(t, c.c, "group", "recurring_expense_created"); len(l) != 2 || l[0] != "/groups/"+gid+"/recurring group_recurring_expense" {
		t.Fatalf("recurring notification links = %v", l)
	}
}

// GM3, GM4 and GM7: expense pages and filters, derived foreign-currency
// amounts with rate provenance, and the request's own field names.
func TestGroupExpensePagesFiltersAndForeignCurrency(t *testing.T) {
	s := apitest.New(t, nil)
	a := newPerson(t, s, "pager", nil)
	b := newPerson(t, s, "payer", nil)
	gid := createGroup(t, a.c, map[string]any{"name": "Trip", "group_type": "trip", "base_currency": "INR", "timezone": "UTC"})["id"].(string)
	joinByLink(t, a, b, gid)
	both := gfPeople(a, b)
	add := func(p person, desc, date, cat string) string {
		body := map[string]any{"description": desc, "amount": "100", "expense_date": date, "split_method": "equal", "participants": both}
		if cat != "" {
			body["category_key"] = cat
		}
		return gfExpense(t, p, gid, body)["id"].(string)
	}
	e1 := add(a, "Taxi", "2026-10-01", "transport")
	e2 := add(b, "Dinner", "2026-10-02", "food_dining")
	e3 := add(a, "Snacks", "2026-10-02", "")
	e4 := add(b, "Museum", "2026-10-03", "entertainment")
	e5 := add(a, "Groceries", "2026-10-04", "groceries")
	a.c.Do(t, http.MethodDelete, "/groups/"+gid+"/expenses/"+e1, nil).Expect(t, http.StatusOK)
	b.c.Do(t, http.MethodPost, "/groups/"+gid+"/expenses/"+e2+"/disputes", map[string]any{"reason": "Wrong total"}).Expect(t, http.StatusCreated)

	walk := func(query string, limit int) []string {
		t.Helper()
		var out []string
		cursor := ""
		for page := 0; page < 20; page++ {
			path := "/groups/" + gid + "/expenses?limit=" + strconv.Itoa(limit) + query
			if cursor != "" {
				path += "&cursor=" + url.QueryEscape(cursor)
			}
			r := a.c.Do(t, http.MethodGet, path, nil).Expect(t, http.StatusOK)
			list, meta := r.List(), gfMap(r.Body["meta"])
			if len(list) > limit {
				t.Fatalf("page of %d with limit %d", len(list), limit)
			}
			out = append(out, ids(list, "id")...)
			next, _ := meta["next_cursor"].(string)
			if meta["has_more"] != (next != "") {
				t.Fatalf("meta = %v", meta)
			}
			if next == "" {
				return out
			}
			cursor = next
		}
		t.Fatal("too many pages")
		return nil
	}
	for _, x := range []struct {
		query string
		want  []string
	}{
		{"", []string{e5, e4, e3, e2}}, // newest expense date first, then newest created
		{"&include_deleted=true", []string{e5, e4, e3, e2, e1}},
		{"&status=disputed", []string{e2}},
		{"&status=deleted", []string{e1}},
		{"&from=2026-10-02&to=2026-10-03", []string{e4, e3, e2}},
		{"&payer_user_id=" + b.id, []string{e4, e2}},
		{"&category_key=groceries", []string{e5}},
		{"&category_key=uncategorized", []string{e3}},
		{"&payer_user_id=" + a.id + "&from=2026-10-02", []string{e5, e3}},
	} {
		for _, limit := range []int{1, 2, 50} {
			if got := walk(x.query, limit); !slices.Equal(got, x.want) {
				t.Fatalf("expenses%s (limit %d) = %v, want %v", x.query, limit, got, x.want)
			}
		}
	}
	gfField(t, a.c.Do(t, http.MethodGet, "/groups/"+gid+"/expenses?cursor=bogus", nil), "query.cursor")
	gfField(t, a.c.Do(t, http.MethodGet, "/groups/"+gid+"/expenses?from=2026-10-05&to=2026-10-01", nil), "query.to")
	if r := a.c.Do(t, http.MethodGet, "/groups/"+gid+"/expenses?payer_user_id=nobody", nil); r.Status != http.StatusUnprocessableEntity {
		t.Fatalf("invalid payer filter: %d", r.Status)
	}

	// Foreign currency: without an amount, it is original × rate rounded half
	// away from zero (0.50 × 49.93 = 24.965 → 24.97) and returned.
	fx := gfExpense(t, a, gid, map[string]any{"description": "Boat", "original_amount": "0.50", "original_currency": "USD", "fx_rate": "49.93",
		"split_method": "equal", "participants": both})
	if money(fx, "amount") != "24.97" || fx["fx_rate"] != "49.93" || fx["fx_rate_source"] != "manual" || fx["fx_rate_at"] == nil ||
		gfMap(fx["original_amount"])["amount"] != "0.50" || gfMap(fx["original_amount"])["currency"] != "USD" {
		t.Fatalf("derived amount = %v", fx)
	}
	fxBody := func(extra map[string]any) map[string]any {
		body := map[string]any{"description": "Ferry", "expense_date": "2026-10-01", "original_amount": "10", "original_currency": "USD",
			"split_method": "equal", "participants": both}
		for k, v := range extra {
			body[k] = v
		}
		return body
	}
	post := func(body map[string]any) *apitest.Response {
		return a.c.Do(t, http.MethodPost, "/groups/"+gid+"/expenses", body, "Idempotency-Key", key())
	}
	gfField(t, post(fxBody(map[string]any{"fx_rate": "49.93", "original_amount": "0.50", "amount": "24.96"})), "body.fx_rate")
	gfField(t, post(fxBody(nil)), "body.fx_rate")
	gfField(t, post(map[string]any{"description": "Nothing", "participants": both}), "body.amount")
	gfField(t, post(map[string]any{"description": "Rate only", "amount": "10", "fx_rate": "2", "participants": both}), "body.original_currency")

	// Montra's rate: looked up for the expense date and stored with its
	// real source and time. (Scoped to this person so no other test sees it.)
	asOf := time.Date(2026, 9, 30, 16, 0, 0, 0, time.UTC)
	s.Env.ExecWorker(t, `insert into fx_rates (user_id, base_currency, quote_currency, rate, source, as_of) values ($1,'USD','INR',83.5,'ecb',$2)`,
		uuid.MustParse(a.id), asOf)
	lk := post(fxBody(map[string]any{"fx_rate_source": "lookup"})).Expect(t, http.StatusCreated).Data()
	at, _ := time.Parse(time.RFC3339Nano, fmt.Sprint(lk["fx_rate_at"]))
	if money(lk, "amount") != "835.00" || lk["fx_rate"] != "83.5" || lk["fx_rate_source"] != "ecb" || !at.Equal(asOf) {
		t.Fatalf("looked-up rate = %v", lk)
	}
	if r := post(fxBody(map[string]any{"fx_rate": "83.5", "fx_rate_source": "ecb"})).Expect(t, http.StatusCreated).Data(); r["fx_rate_source"] != "ecb" {
		t.Fatalf("sending Montra's rate back = %v", r)
	}
	gfField(t, post(fxBody(map[string]any{"fx_rate": "83.4", "fx_rate_source": "lookup"})), "body.fx_rate")
	p := gfCoded(t, post(fxBody(map[string]any{"original_currency": "GBP", "fx_rate_source": "lookup"})), http.StatusUnprocessableEntity,
		"DOMAIN_RULE_VIOLATION", "fx_rate_unavailable")
	if p["from"] != "GBP" || p["to"] != "INR" || p["date"] != "2026-10-01" {
		t.Fatalf("params = %v", p)
	}
	gfCoded(t, post(fxBody(map[string]any{"expense_date": "2026-09-29", "fx_rate_source": "lookup"})), http.StatusUnprocessableEntity,
		"DOMAIN_RULE_VIOLATION", "fx_rate_unavailable")

	// A single payer may leave out their amount: the server derives it, so
	// the client never converts money. Several payers must each send one.
	one := post(fxBody(map[string]any{"fx_rate_source": "lookup", "payers": []any{map[string]any{"user_id": b.id}}})).Expect(t, http.StatusCreated).Data()
	if pl := one["payers"].([]any); len(pl) != 1 || pl[0].(map[string]any)["user_id"] != b.id || gfMap(pl[0].(map[string]any)["paid"])["amount"] != "835.00" {
		t.Fatalf("single payer without an amount = %v", one["payers"])
	}
	gfField(t, post(fxBody(map[string]any{"fx_rate_source": "lookup", "payers": []any{map[string]any{"user_id": a.id}, map[string]any{"user_id": b.id}}})),
		"body.payers[0].amount")

	// Edits that keep the rate keep its provenance; a typed rate is manual.
	edit := func(extra map[string]any, version any) map[string]any {
		body := fxBody(extra)
		body["version"] = version
		return a.c.Do(t, http.MethodPatch, "/groups/"+gid+"/expenses/"+lk["id"].(string), body).Expect(t, http.StatusOK).Data()
	}
	ed := edit(map[string]any{"description": "Ferry ride", "fx_rate": lk["fx_rate"], "fx_rate_source": lk["fx_rate_source"]}, lk["version"])
	if ed["fx_rate_source"] != "ecb" || ed["fx_rate_at"] != lk["fx_rate_at"] || money(ed, "amount") != "835.00" {
		t.Fatalf("round trip = %v", ed)
	}
	ed = edit(map[string]any{"fx_rate": "83.5"}, ed["version"])
	if ed["fx_rate_source"] != "ecb" {
		t.Fatalf("edit without a source = %v", ed)
	}
	ed = edit(map[string]any{"fx_rate": "84"}, ed["version"])
	if ed["fx_rate_source"] != "manual" || money(ed, "amount") != "840.00" {
		t.Fatalf("typed rate = %v", ed)
	}

	// Errors name the request's own fields.
	usd := createAccount(t, a.c, map[string]any{"name": "USD", "account_type": "bank", "currency": "USD"})["id"].(string)
	gfField(t, post(map[string]any{"description": "Hotel", "amount": "3000", "participants": both, "payer_account_id": usd}), "body.payer_account_id")
}

// G8: removing a member with an open balance keeps their balance visible
// and settleable.
func TestGroupRemovedMemberBalanceStaysSettleable(t *testing.T) {
	s := apitest.New(t, nil)
	a := newPerson(t, s, "keeper", nil)
	b := newPerson(t, s, "removed", nil)
	c := newPerson(t, s, "member", nil)
	gid := createGroup(t, a.c, map[string]any{"name": "Flat", "group_type": "roommates", "base_currency": "INR"})["id"].(string)
	joinByLink(t, a, b, gid)
	joinByLink(t, a, c, gid)
	// b paid 300 for all three; c paid 60 for b and c.
	// Nets: b +300 − 100 − 30 = +170; a −100; c +60 − 100 − 30 = −70.
	gfExpense(t, b, gid, map[string]any{"description": "Groceries", "amount": "300", "split_method": "equal", "participants": gfPeople(a, b, c)})
	gfExpense(t, c, gid, map[string]any{"description": "Cab", "amount": "60", "split_method": "equal", "participants": gfPeople(b, c)})

	gfCoded(t, b.c.Do(t, http.MethodDelete, "/groups/"+gid+"/members/"+b.id, nil), http.StatusUnprocessableEntity, "DOMAIN_RULE_VIOLATION", "balance_open")
	a.c.Do(t, http.MethodDelete, "/groups/"+gid+"/members/"+b.id, nil).Expect(t, http.StatusOK)
	if r := b.c.Do(t, http.MethodGet, "/groups/"+gid+"/balances", nil); r.Status != http.StatusNotFound {
		t.Fatalf("a removed member keeps access: %d", r.Status)
	}
	s.RunJobs(t)
	if l := gfLinks(t, b.c, "group", "member_removed"); len(l) != 1 || l[0] != "/groups group" {
		t.Fatalf("removal notification links = %v", l)
	}

	// Everyone left still sees the balance, under the name it had.
	bal := c.c.Do(t, http.MethodGet, "/groups/"+gid+"/balances", nil).Expect(t, http.StatusOK).Data()
	row := gfFind(bal["balances"].([]any), "user_id", b.id)
	if row == nil || row["member_status"] != "removed" || row["display_name"] != "Test removed" || money(row, "net") != "170.00" {
		t.Fatalf("removed member's balance = %v", row)
	}
	toB := func(list []any) int64 {
		var n int64
		for _, x := range list {
			if tr := gfMap(x); tr["to_user_id"] == b.id {
				n += int64(gfMap(tr["amount"])["amount_minor"].(float64))
			}
		}
		return n
	}
	if toB(bal["simplified"].([]any)) != 17000 || toB(bal["original_debts"].([]any)) != 17000 {
		t.Fatalf("debts to the removed member: simplified %v original %v", bal["simplified"], bal["original_debts"])
	}
	sg := c.c.Do(t, http.MethodGet, "/groups/"+gid+"/settlement-suggestions?mine=true", nil).Expect(t, http.StatusOK).Data()
	if toB(sg["suggestions"].([]any)) != 7000 {
		t.Fatalf("c's suggestions = %v", sg)
	}

	// c pays b off-app. b cannot confirm any more, so an admin confirms for b.
	st := c.c.Do(t, http.MethodPost, "/groups/"+gid+"/settlements", map[string]any{"payer_user_id": c.id, "payee_user_id": b.id, "amount": "70"},
		"Idempotency-Key", key()).Expect(t, http.StatusCreated).Data()
	if st["status"] != "user_reported_paid" || st["payee_name"] != "Test removed" {
		t.Fatalf("settlement with a removed member = %v", st)
	}
	if r := c.c.Do(t, http.MethodPost, "/groups/"+gid+"/settlements/"+st["id"].(string)+"/confirm", map[string]any{"version": st["version"]}); r.Status != http.StatusForbidden {
		t.Fatalf("payer confirming for the removed payee: %d", r.Status)
	}
	acct := createAccount(t, a.c, map[string]any{"name": "Bank", "account_type": "bank", "currency": "INR", "opening_balance": "1000"})["id"].(string)
	gfField(t, a.c.Do(t, http.MethodPost, "/groups/"+gid+"/settlements/"+st["id"].(string)+"/confirm", map[string]any{"version": st["version"],
		"account_id": acct}), "body.account_id")
	cf := a.c.Do(t, http.MethodPost, "/groups/"+gid+"/settlements/"+st["id"].(string)+"/confirm", map[string]any{"version": st["version"]}).
		Expect(t, http.StatusOK).Data()
	if cf["status"] != "confirmed" || cf["confirmed_by"] != a.id || cf["verification"] != "user_reported" || cf["counted"] != true {
		t.Fatalf("admin confirmation = %v", cf)
	}
	// An admin who pays the removed member records and confirms it the same way.
	st2 := a.c.Do(t, http.MethodPost, "/groups/"+gid+"/settlements", map[string]any{"payer_user_id": a.id, "payee_user_id": b.id, "amount": "100"},
		"Idempotency-Key", key()).Expect(t, http.StatusCreated).Data()
	a.c.Do(t, http.MethodPost, "/groups/"+gid+"/settlements/"+st2["id"].(string)+"/confirm", map[string]any{"version": st2["version"]}).Expect(t, http.StatusOK)
	bal = c.c.Do(t, http.MethodGet, "/groups/"+gid+"/balances", nil).Expect(t, http.StatusOK).Data()
	for _, p := range []person{a, b, c} {
		if netOf(bal, p.id) != "0.00" {
			t.Fatalf("after settling, %s = %s", p.user, netOf(bal, p.id))
		}
	}
	if row := gfFind(bal["balances"].([]any), "user_id", b.id); row == nil || row["member_status"] != "removed" {
		t.Fatalf("the removed member's history must stay listed: %v", bal["balances"])
	}
	// A payee who is still a member confirms for themselves only.
	st3 := c.c.Do(t, http.MethodPost, "/groups/"+gid+"/settlements", map[string]any{"payer_user_id": c.id, "payee_user_id": a.id, "amount": "1",
		"state": "proposed"}, "Idempotency-Key", key()).Expect(t, http.StatusCreated).Data()
	joinByLink(t, a, newPerson(t, s, "admin2", nil), gid)
	if r := c.c.Do(t, http.MethodPost, "/groups/"+gid+"/settlements/"+st3["id"].(string)+"/confirm", map[string]any{"version": st3["version"]}); r.Status != http.StatusForbidden {
		t.Fatalf("confirming for an active payee: %d", r.Status)
	}
}

// G5, G9, G10 and GM6: coded conflicts, deep links, the activity contract
// and the CSV export.
func TestGroupConflictCodesLinksAndContract(t *testing.T) {
	s := apitest.New(t, map[string]string{"HTTP_ENABLE_DOCS": "true"})
	a := newPerson(t, s, "codes", nil)
	b := newPerson(t, s, "other", nil)
	gid := createGroup(t, a.c, map[string]any{"name": "Flat 4B / Goa ☀", "group_type": "household", "base_currency": "INR", "timezone": "UTC"})["id"].(string)
	joinByLink(t, a, b, gid)
	both := gfPeople(a, b)
	acct := createAccount(t, a.c, map[string]any{"name": "Bank", "account_type": "bank", "currency": "INR", "opening_balance": "1000"})["id"].(string)
	expBody := map[string]any{"description": "Rent", "amount": "500", "split_method": "equal", "participants": both}
	e := gfExpense(t, a, gid, map[string]any{"description": "Rent", "amount": "500", "split_method": "equal", "participants": both, "payer_account_id": acct})
	eid := e["id"].(string)

	// Expenses.
	gfCoded(t, a.c.Do(t, http.MethodPost, "/groups/"+gid+"/expenses/"+eid+"/my-record", map[string]any{"action": "link", "account_id": acct}),
		http.StatusConflict, "CONFLICT", "expense_already_recorded")
	a.c.Do(t, http.MethodDelete, "/groups/"+gid+"/expenses/"+eid, nil).Expect(t, http.StatusOK)
	upd := map[string]any{"version": e["version"]}
	for k, v := range expBody {
		upd[k] = v
	}
	gfCoded(t, a.c.Do(t, http.MethodPatch, "/groups/"+gid+"/expenses/"+eid, upd), http.StatusConflict, "CONFLICT", "expense_deleted")
	gfCoded(t, b.c.Do(t, http.MethodPost, "/groups/"+gid+"/expenses/"+eid+"/disputes", map[string]any{"reason": "Too much"}),
		http.StatusConflict, "CONFLICT", "expense_deleted")
	gfCoded(t, a.c.Do(t, http.MethodPost, "/groups/"+gid+"/expenses/"+eid+"/my-record", map[string]any{"action": "link", "account_id": acct}),
		http.StatusConflict, "CONFLICT", "expense_deleted")

	// Settlements.
	set := func(p person, id, action string, body map[string]any) *apitest.Response {
		return p.c.Do(t, http.MethodPost, "/groups/"+gid+"/settlements/"+id+"/"+action, body)
	}
	st := b.c.Do(t, http.MethodPost, "/groups/"+gid+"/settlements", map[string]any{"payer_user_id": b.id, "payee_user_id": a.id, "amount": "50"},
		"Idempotency-Key", key()).Expect(t, http.StatusCreated).Data()
	sid := st["id"].(string)
	if p := gfCoded(t, set(b, sid, "mark-paid", map[string]any{"version": st["version"]}), http.StatusConflict, "CONFLICT", "settlement_not_proposed"); p["status"] != "user_reported_paid" {
		t.Fatalf("params = %v", p)
	}
	cf := set(a, sid, "confirm", map[string]any{"version": st["version"]}).Expect(t, http.StatusOK).Data()
	if p := gfCoded(t, set(a, sid, "confirm", map[string]any{"version": cf["version"]}), http.StatusConflict, "CONFLICT", "settlement_not_confirmable"); p["status"] != "confirmed" {
		t.Fatalf("params = %v", p)
	}
	pr := a.c.Do(t, http.MethodPost, "/groups/"+gid+"/settlements", map[string]any{"payer_user_id": a.id, "payee_user_id": b.id, "amount": "10",
		"state": "proposed"}, "Idempotency-Key", key()).Expect(t, http.StatusCreated).Data()
	if p := gfCoded(t, set(b, pr["id"].(string), "dispute", map[string]any{"version": pr["version"], "reason": "Never agreed"}),
		http.StatusConflict, "CONFLICT", "settlement_not_disputable"); p["status"] != "proposed" {
		t.Fatalf("params = %v", p)
	}
	set(a, sid, "record", map[string]any{"version": cf["version"], "account_id": acct}).Expect(t, http.StatusOK)
	gfCoded(t, set(a, sid, "record", map[string]any{"version": cf["version"], "account_id": acct}), http.StatusConflict, "CONFLICT", "settlement_already_recorded")
	vd := set(a, sid, "void", map[string]any{"version": cf["version"], "reason": "Recorded twice"}).Expect(t, http.StatusOK).Data()
	gfCoded(t, set(a, sid, "void", map[string]any{"version": vd["version"], "reason": "Again"}), http.StatusConflict, "CONFLICT", "settlement_voided")
	gfCoded(t, set(b, sid, "mark-paid", map[string]any{"version": vd["version"]}), http.StatusConflict, "CONFLICT", "settlement_voided")
	gfCoded(t, a.c.Do(t, http.MethodPost, "/groups/"+gid+"/settlements/"+sid+"/correct", map[string]any{"payer_user_id": b.id, "payee_user_id": a.id,
		"amount": "40"}, "Idempotency-Key", key()), http.StatusConflict, "CONFLICT", "settlement_voided")

	// Archived groups.
	gfCoded(t, a.c.Do(t, http.MethodPost, "/groups/"+gid+"/restore", nil), http.StatusConflict, "CONFLICT", "group_not_archived")
	a.c.Do(t, http.MethodPost, "/groups/"+gid+"/archive", nil).Expect(t, http.StatusOK)
	gfCoded(t, a.c.Do(t, http.MethodPost, "/groups/"+gid+"/archive", nil), http.StatusConflict, "CONFLICT", "group_archived")
	gfCoded(t, b.c.Do(t, http.MethodPost, "/groups/"+gid+"/expenses", expBody, "Idempotency-Key", key()), http.StatusConflict, "CONFLICT", "group_archived")
	gfCoded(t, a.c.Do(t, http.MethodPost, "/groups/"+gid+"/invitations", map[string]any{"kind": "link"}), http.StatusConflict, "CONFLICT", "group_archived")
	a.c.Do(t, http.MethodPost, "/groups/"+gid+"/restore", nil).Expect(t, http.StatusOK)

	// Deep links are web routes with IDs only.
	e2 := gfExpense(t, a, gid, expBody)["id"].(string)
	dsp := b.c.Do(t, http.MethodPost, "/groups/"+gid+"/expenses/"+e2+"/disputes", map[string]any{"reason": "Check"}).Expect(t, http.StatusCreated).Data()
	a.c.Do(t, http.MethodPost, "/groups/"+gid+"/disputes/"+dsp["id"].(string)+"/resolve", map[string]any{"resolution": "Checked"}).Expect(t, http.StatusOK)
	s.RunJobs(t)
	if l := gfLinks(t, b.c, "group", "dispute_resolved"); len(l) != 1 || l[0] != "/groups/"+gid+"/expenses/"+e2+" group_expense" {
		t.Fatalf("dispute notification links = %v", l)
	}
	if l := gfLinks(t, b.c, "group", "expense_added"); !slices.Contains(l, "/groups/"+gid+"/expenses/"+e2+" group_expense") {
		t.Fatalf("expense notification links = %v", l)
	}

	// The activity contract: every kind written is in the enum, and the
	// summary carries typed parameters.
	doc := a.c.Do(t, http.MethodGet, "/openapi.json", nil).Expect(t, http.StatusOK).Body
	schemas := gfMap(gfMap(doc["components"])["schemas"])
	prop := func(schema, field string) map[string]any {
		t.Helper()
		p := gfMap(gfMap(gfMap(schemas[schema])["properties"])[field])
		if p == nil {
			t.Fatalf("%s.%s missing", schema, field)
		}
		return p
	}
	enumOf := func(schema, field string) []string {
		var out []string
		for _, v := range prop(schema, field)["enum"].([]any) {
			out = append(out, v.(string))
		}
		return out
	}
	kinds := enumOf("GroupActivityDTO", "kind")
	events := a.c.Do(t, http.MethodGet, "/groups/"+gid+"/activity", nil).Expect(t, http.StatusOK).Data()["events"].([]any)
	seen := map[string]bool{}
	for _, ev := range events {
		m := gfMap(ev)
		seen[m["kind"].(string)] = true
		if !slices.Contains(kinds, m["kind"].(string)) || !slices.Contains(enumOf("GroupActivityDTO", "entity_type"), m["entity_type"].(string)) {
			t.Fatalf("activity outside the contract: %v", m)
		}
		switch m["kind"] {
		case "group_created":
			if gfMap(m["summary"])["type"] != "household" {
				t.Fatalf("group_created summary = %v", m["summary"])
			}
		case "member_joined":
			if gfMap(m["summary"])["via"] != "invitation" {
				t.Fatalf("member_joined summary = %v", m["summary"])
			}
		case "dispute_resolved":
			if gfMap(m["summary"])["target"] != e2 {
				t.Fatalf("dispute_resolved summary = %v", m["summary"])
			}
		}
	}
	for _, k := range []string{"group_created", "member_joined", "expense_added", "expense_deleted", "settlement_voided", "group_archived",
		"group_restored", "dispute_resolved"} {
		if !seen[k] {
			t.Fatalf("activity %s missing from %v", k, seen)
		}
	}
	if enumOf("GroupActivitySummary", "via")[0] != "invitation" || prop("GroupActivitySummary", "description")["type"] != "string" {
		t.Fatalf("summary schema = %v", schemas["GroupActivitySummary"])
	}

	// Other contract shapes clients adopt.
	paths := gfMap(doc["paths"])
	op := func(path, method string) map[string]any {
		t.Helper()
		o := gfMap(gfMap(paths[path])[method])
		if o == nil {
			t.Fatalf("%s %s missing", method, path)
		}
		return o
	}
	content := gfMap(gfMap(gfMap(op("/groups/{id}/export", "get")["responses"])["200"])["content"])
	if _, ok := content["text/csv"]; !ok || len(content) != 1 {
		t.Fatalf("export content = %v", content)
	}
	accept := gfMap(op("/group-invitations/accept", "post")["responses"])
	ref := func(code string) string {
		return fmt.Sprint(gfMap(gfMap(gfMap(gfMap(accept[code])["content"])["application/json"])["schema"])["$ref"])
	}
	if !strings.HasSuffix(ref("200"), "/EnvelopeGroupDetail") || !strings.HasSuffix(ref("202"), "/EnvelopeGroupJoinRequestDTO") {
		t.Fatalf("accept-link responses = %v", accept)
	}
	body := fmt.Sprint(gfMap(gfMap(gfMap(op("/groups/{id}", "patch")["requestBody"])["content"])["application/json"])["schema"])
	if !strings.Contains(body, "GroupPatch") || !slices.Contains(gfMap(schemas["GroupPatch"])["required"].([]any), any("version")) {
		t.Fatalf("PATCH /groups/{id} body = %s", body)
	}
	params := map[string]bool{}
	for _, x := range op("/groups/{id}/expenses", "get")["parameters"].([]any) {
		if n, ok := gfMap(x)["name"].(string); ok {
			params[n] = true
		}
	}
	for _, n := range []string{"cursor", "limit", "status", "from", "to", "payer_user_id", "category_key", "include_deleted"} {
		if !params[n] {
			t.Fatalf("expense list parameters = %v", params)
		}
	}
	idem := false
	for _, x := range op("/groups/{id}/recurring-expenses", "post")["parameters"].([]any) {
		if m := gfMap(x); m["name"] == "Idempotency-Key" && m["required"] == true {
			idem = true
		}
	}
	if !idem {
		t.Fatal("POST /groups/{id}/recurring-expenses must require Idempotency-Key")
	}
	if fmt.Sprint(enumOf("GroupExpenseInput", "fx_rate_source")) != "[manual lookup ecb provider]" ||
		fmt.Sprint(enumOf("GroupExpenseDTO", "fx_rate_source")) != "[manual ecb provider]" {
		t.Fatalf("fx_rate_source enums = %v / %v", prop("GroupExpenseInput", "fx_rate_source"), prop("GroupExpenseDTO", "fx_rate_source"))
	}
	for _, f := range [][2]string{{"GroupDTO", "my_net"}, {"GroupInvitationPreview", "group_id"}, {"GroupInvitationPreview", "invited_by"},
		{"GroupInvitationPreview", "member_count"}, {"GroupInvitationPreview", "already_member"}, {"GroupInvitationPreview", "requires_approval"},
		{"GroupInvitationDTO", "invitee"}, {"GroupInvitationDTO", "invited_by"}, {"GroupJoinRequestDTO", "group_id"}, {"GroupExpenseDTO", "fx_rate_at"},
		{"AddMemberInput", "user_id"}, {"GroupInvitationInput", "user_id"}} {
		prop(f[0], f[1])
	}

	// The export is a CSV download with a safe file name.
	ex := a.c.Do(t, http.MethodGet, "/groups/"+gid+"/export", nil).Expect(t, http.StatusOK)
	name := regexp.MustCompile(`^attachment; filename="flat-4b-goa-expenses-\d{4}-\d{2}-\d{2}\.csv"$`)
	if !strings.HasPrefix(ex.Headers.Get("Content-Type"), "text/csv") || !name.MatchString(ex.Headers.Get("Content-Disposition")) {
		t.Fatalf("export headers = %v", ex.Headers)
	}
}
