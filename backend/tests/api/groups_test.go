package api_test

import (
	"bytes"
	"context"
	"encoding/csv"
	"net/http"
	"strings"
	"testing"
	"time"

	"github.com/google/uuid"

	"montra/backend/internal/testutil/apitest"
)

type person struct {
	c    *apitest.Client
	id   string
	user string
}

// newPerson registers someone with a username who opted into username
// discovery (off by default); pass "discoverable_by_username": false in
// profile for someone who did not.
func newPerson(t *testing.T, s *apitest.Server, name string, profile map[string]any) person {
	t.Helper()
	c, _ := s.Login(t, s.Register(t, name))
	p := person{c: c, user: strings.ToLower(name) + "_" + uuid.NewString()[:6]}
	body := map[string]any{"username": p.user, "discoverable_by_username": true}
	for k, v := range profile {
		body[k] = v
	}
	c.Do(t, http.MethodPatch, "/me", body).Expect(t, http.StatusOK)
	p.id = c.Do(t, http.MethodGet, "/me", nil).Expect(t, http.StatusOK).Data()["account"].(map[string]any)["id"].(string)
	return p
}

func ids(list []any, field string) []string {
	var out []string
	for _, x := range list {
		out = append(out, x.(map[string]any)[field].(string))
	}
	return out
}

func contains(list []string, v string) bool {
	for _, x := range list {
		if x == v {
			return true
		}
	}
	return false
}

func TestSocialGraphRequestsControlsBlocksAndMutes(t *testing.T) {
	s := apitest.New(t, nil)
	a := newPerson(t, s, "alice", nil)
	b := newPerson(t, s, "bob", nil)
	hidden := newPerson(t, s, "hidden", map[string]any{"discoverable_by_username": false})
	closed := newPerson(t, s, "closed", map[string]any{"allow_friend_requests": "nobody"})
	// Social actions are rate limited per user (burst 15), so discovery
	// checks run as a separate user.
	d := newPerson(t, s, "dana", nil)

	// Discovery: opted-in users are found by their exact username only, with
	// their minimal profile; partial usernames and non-discoverable users
	// find nobody.
	found := d.c.Do(t, http.MethodGet, "/users/search?q="+b.user, nil).Expect(t, http.StatusOK).List()
	if len(found) != 1 || found[0].(map[string]any)["user_id"] != b.id || found[0].(map[string]any)["display_name"] != "Test bob" ||
		found[0].(map[string]any)["connection"] != "none" {
		t.Fatalf("exact search for bob = %v", found)
	}
	if l := d.c.Do(t, http.MethodGet, "/users/search?q="+b.user[:5], nil).Expect(t, http.StatusOK).List(); len(l) != 0 {
		t.Fatalf("a username prefix found people: %v", l)
	}
	if l := d.c.Do(t, http.MethodGet, "/users/search?q="+hidden.user, nil).Expect(t, http.StatusOK).List(); len(l) != 0 {
		t.Fatalf("non-discoverable user found: %v", l)
	}
	// LIKE wildcards are literal: "_" must not match any character.
	if l := d.c.Do(t, http.MethodGet, "/users/search?q=bo__", nil).Expect(t, http.StatusOK).List(); len(l) != 0 {
		t.Fatalf("wildcard query matched: %v", l)
	}
	if r := d.c.Do(t, http.MethodPost, "/friend-requests", map[string]any{"username": hidden.user}); r.Status != http.StatusNotFound {
		t.Fatalf("request to non-discoverable username: %d %s", r.Status, r.Raw)
	}
	if r := d.c.Do(t, http.MethodPost, "/friend-requests", map[string]any{"username": closed.user}); r.ErrorCode() != "DOMAIN_RULE_VIOLATION" {
		t.Fatalf("request to someone not accepting requests: %s", r.Raw)
	}

	// Request → notification → accept → connected both ways.
	req := a.c.Do(t, http.MethodPost, "/friend-requests", map[string]any{"username": "@" + b.user, "message": "Hi"}).Expect(t, http.StatusCreated).Data()
	if req["status"] != "pending" || req["to"].(map[string]any)["display_name"] != "Test bob" {
		t.Fatalf("request = %v", req)
	}
	if r := a.c.Do(t, http.MethodPost, "/friend-requests", map[string]any{"user_id": b.id}); r.Status != http.StatusConflict || detail(t, r)["code"] != "request_pending" {
		t.Fatalf("duplicate pending request: %d %s", r.Status, r.Raw)
	}
	s.RunJobs(t)
	if n := notificationsOf(t, b.c, "social", "friend_request"); n != 1 {
		t.Fatalf("bob friend_request notifications = %d", n)
	}
	if l := b.c.Do(t, http.MethodGet, "/friend-requests", nil).Expect(t, http.StatusOK).List(); len(l) != 1 {
		t.Fatalf("bob's requests = %v", l)
	}
	if r := a.c.Do(t, http.MethodPost, "/friend-requests/"+req["id"].(string)+"/accept", nil); r.Status != http.StatusNotFound {
		t.Fatalf("requester accepting own request: %d", r.Status)
	}
	acc := b.c.Do(t, http.MethodPost, "/friend-requests/"+req["id"].(string)+"/accept", nil).Expect(t, http.StatusOK).Data()
	if acc["status"] != "accepted" {
		t.Fatalf("accept = %v", acc)
	}
	fa := a.c.Do(t, http.MethodGet, "/connections", nil).Expect(t, http.StatusOK).List()
	fb := b.c.Do(t, http.MethodGet, "/connections", nil).Expect(t, http.StatusOK).List()
	if !contains(ids(fa, "user_id"), b.id) || !contains(ids(fb, "user_id"), a.id) || fa[0].(map[string]any)["connection"] != "friend" {
		t.Fatalf("connections: alice=%v bob=%v", fa, fb)
	}
	if r := a.c.Do(t, http.MethodPost, "/friend-requests", map[string]any{"user_id": b.id}); r.Status != http.StatusConflict || detail(t, r)["code"] != "already_friends" {
		t.Fatalf("request to an existing friend: %d %s", r.Status, r.Raw)
	}
	a.c.Do(t, http.MethodDelete, "/connections/"+b.id, nil).Expect(t, http.StatusOK)
	if l := b.c.Do(t, http.MethodGet, "/connections", nil).Expect(t, http.StatusOK).List(); len(l) != 0 {
		t.Fatalf("removal must be mutual: %v", l)
	}

	// friends_of_friends: only people with a mutual friend may ask.
	c3 := newPerson(t, s, "carol", map[string]any{"allow_friend_requests": "friends_of_friends"})
	if r := a.c.Do(t, http.MethodPost, "/friend-requests", map[string]any{"user_id": c3.id}); r.ErrorCode() != "DOMAIN_RULE_VIOLATION" {
		t.Fatalf("friends_of_friends without a mutual friend: %s", r.Raw)
	}
	r1 := c3.c.Do(t, http.MethodPost, "/friend-requests", map[string]any{"user_id": b.id}).Expect(t, http.StatusCreated).Data()
	b.c.Do(t, http.MethodPost, "/friend-requests/"+r1["id"].(string)+"/accept", nil).Expect(t, http.StatusOK)
	r2 := a.c.Do(t, http.MethodPost, "/friend-requests", map[string]any{"user_id": b.id}).Expect(t, http.StatusCreated).Data()
	b.c.Do(t, http.MethodPost, "/friend-requests/"+r2["id"].(string)+"/accept", nil).Expect(t, http.StatusOK)
	a.c.Do(t, http.MethodPost, "/friend-requests", map[string]any{"user_id": c3.id}).Expect(t, http.StatusCreated)

	// Blocking removes the connection, hides both ways and is not disclosed.
	b.c.Do(t, http.MethodPost, "/users/"+a.id+"/block", nil).Expect(t, http.StatusOK)
	if l := a.c.Do(t, http.MethodGet, "/connections", nil).Expect(t, http.StatusOK).List(); contains(ids(l, "user_id"), b.id) {
		t.Fatal("block must remove the connection")
	}
	if l := a.c.Do(t, http.MethodGet, "/users/search?q="+b.user, nil).Expect(t, http.StatusOK).List(); len(l) != 0 {
		t.Fatalf("blocked user still searchable: %v", l)
	}
	if r := a.c.Do(t, http.MethodPost, "/friend-requests", map[string]any{"user_id": b.id}); r.Status != http.StatusNotFound {
		t.Fatalf("request across a block: %d (blocks must look like a missing user)", r.Status)
	}
	if r := b.c.Do(t, http.MethodPost, "/friend-requests", map[string]any{"user_id": a.id}); r.Status != http.StatusNotFound {
		t.Fatalf("blocker requesting the blocked user: %d", r.Status)
	}
	b.c.Do(t, http.MethodDelete, "/users/"+a.id+"/block", nil).Expect(t, http.StatusOK)
	if l := a.c.Do(t, http.MethodGet, "/users/search?q="+b.user, nil).Expect(t, http.StatusOK).List(); len(l) != 1 {
		t.Fatalf("unblocked user not searchable: %v", l)
	}

	// Muting stops notifications from that person; cancel works for the sender.
	b.c.Do(t, http.MethodPost, "/users/"+a.id+"/mute", map[string]any{"muted": true}).Expect(t, http.StatusOK)
	before := notificationsOf(t, b.c, "social", "friend_request")
	r3 := a.c.Do(t, http.MethodPost, "/friend-requests", map[string]any{"user_id": b.id}).Expect(t, http.StatusCreated).Data()
	s.RunJobs(t)
	if n := notificationsOf(t, b.c, "social", "friend_request"); n != before {
		t.Fatalf("muted sender still notified: %d → %d", before, n)
	}
	if r := b.c.Do(t, http.MethodPost, "/friend-requests/"+r3["id"].(string)+"/cancel", nil); r.Status != http.StatusNotFound {
		t.Fatalf("addressee cancelling: %d", r.Status)
	}
	if st := a.c.Do(t, http.MethodPost, "/friend-requests/"+r3["id"].(string)+"/cancel", nil).Expect(t, http.StatusOK).Data()["status"]; st != "cancelled" {
		t.Fatalf("cancel status = %v", st)
	}
}

func createGroup(t *testing.T, c *apitest.Client, body map[string]any) map[string]any {
	t.Helper()
	return c.Do(t, http.MethodPost, "/groups", body).Expect(t, http.StatusCreated).Data()
}

// joinByLink makes p a member through a fresh link invitation.
func joinByLink(t *testing.T, owner, p person, gid string) {
	t.Helper()
	inv := owner.c.Do(t, http.MethodPost, "/groups/"+gid+"/invitations", map[string]any{"kind": "link"}).Expect(t, http.StatusCreated).Data()
	p.c.Do(t, http.MethodPost, "/group-invitations/accept", map[string]any{"token": inv["token"]}).Expect(t, http.StatusOK)
}

func TestGroupMembershipInvitationsRolesAndIsolation(t *testing.T) {
	s := apitest.New(t, nil)
	o := newPerson(t, s, "owner", nil)
	b := newPerson(t, s, "member", nil)
	x := newPerson(t, s, "linker", nil)
	y := newPerson(t, s, "joiner", nil)
	out := newPerson(t, s, "outsider", nil)

	g := createGroup(t, o.c, map[string]any{"name": "Goa Trip", "group_type": "trip", "base_currency": "INR", "start_date": "2026-12-20",
		"end_date": "2026-12-24", "destination": "Goa"})
	gid := g["id"].(string)
	if g["my_role"] != "owner" || g["member_count"].(float64) != 1 {
		t.Fatalf("group = %v", g)
	}
	// Non-members cannot learn the group exists.
	for _, p := range []string{"/groups/" + gid, "/groups/" + gid + "/expenses", "/groups/" + gid + "/balances", "/groups/" + gid + "/activity"} {
		if r := out.c.Do(t, http.MethodGet, p, nil); r.Status != http.StatusNotFound {
			t.Fatalf("outsider GET %s = %d", p, r.Status)
		}
	}

	// Link invitation: preview, accept; the token is shown once.
	inv := o.c.Do(t, http.MethodPost, "/groups/"+gid+"/invitations", map[string]any{"kind": "link", "max_uses": 2}).Expect(t, http.StatusCreated).Data()
	tok := inv["token"].(string)
	if l := o.c.Do(t, http.MethodGet, "/groups/"+gid+"/invitations", nil).Expect(t, http.StatusOK).List(); len(l) != 1 || l[0].(map[string]any)["token"] != nil {
		t.Fatalf("invitation list must not repeat the token: %v", l)
	}
	pv := x.c.Do(t, http.MethodPost, "/group-invitations/preview", map[string]any{"token": tok}).Expect(t, http.StatusOK).Data()
	if pv["group_name"] != "Goa Trip" || pv["status"] != "active" {
		t.Fatalf("preview = %v", pv)
	}
	x.c.Do(t, http.MethodPost, "/group-invitations/accept", map[string]any{"token": tok}).Expect(t, http.StatusOK)
	// A member may change only their own notification level.
	x.c.Do(t, http.MethodPatch, "/groups/"+gid+"/members/"+x.id, map[string]any{"notification_level": "none"}).Expect(t, http.StatusOK)
	if r := x.c.Do(t, http.MethodPatch, "/groups/"+gid+"/members/"+o.id, map[string]any{"notification_level": "none"}); r.Status != http.StatusForbidden {
		t.Fatalf("member changing someone else's level: %d", r.Status)
	}
	if r := x.c.Do(t, http.MethodPost, "/group-invitations/accept", map[string]any{"token": tok}); r.Status != http.StatusConflict || detail(t, r)["code"] != "already_member" {
		t.Fatalf("re-accepting must answer already_member: %d %s", r.Status, r.Raw)
	}

	// Username invitation → invitee notification → accept.
	ui := o.c.Do(t, http.MethodPost, "/groups/"+gid+"/members", map[string]any{"username": b.user}).Expect(t, http.StatusCreated).Data()
	s.RunJobs(t)
	if n := notificationsOf(t, b.c, "group", "invitation_created"); n != 1 {
		t.Fatalf("invitee notifications = %d", n)
	}
	mine := b.c.Do(t, http.MethodGet, "/group-invitations", nil).Expect(t, http.StatusOK).List()
	if len(mine) != 1 || mine[0].(map[string]any)["group_name"] != "Goa Trip" {
		t.Fatalf("my invitations = %v", mine)
	}
	if r := out.c.Do(t, http.MethodPost, "/group-invitations/"+ui["id"].(string)+"/accept", nil); r.Status == http.StatusOK {
		t.Fatal("someone else must not accept a username invitation")
	}
	d := b.c.Do(t, http.MethodPost, "/group-invitations/"+ui["id"].(string)+"/accept", nil).Expect(t, http.StatusOK).Data()
	if d["member_count"].(float64) != 3 || d["my_role"] != "member" {
		t.Fatalf("after accept = %v", d)
	}

	// Roles: members cannot administer.
	if r := b.c.Do(t, http.MethodPatch, "/groups/"+gid, map[string]any{"name": "Hijack", "group_type": "trip", "version": g["version"]}); r.Status != http.StatusForbidden {
		t.Fatalf("member editing settings: %d", r.Status)
	}
	if r := b.c.Do(t, http.MethodDelete, "/groups/"+gid+"/members/"+x.id, nil); r.Status != http.StatusForbidden {
		t.Fatalf("member removing a member: %d", r.Status)
	}
	o.c.Do(t, http.MethodPatch, "/groups/"+gid+"/members/"+b.id, map[string]any{"role": "admin"}).Expect(t, http.StatusOK)
	s.RunJobs(t)
	if n := notificationsOf(t, b.c, "group", "member_role_changed"); n != 1 {
		t.Fatalf("role change notifications = %d", n)
	}
	// Join request by a non-member: admins are notified and see the name.
	jr := y.c.Do(t, http.MethodPost, "/groups/"+gid+"/join-requests", map[string]any{"message": "Count me in"}).Expect(t, http.StatusCreated).Data()
	s.RunJobs(t)
	if n := notificationsOf(t, o.c, "group", "join_requested"); n != 1 {
		t.Fatalf("admin join_requested notifications = %d", n)
	}
	reqs := o.c.Do(t, http.MethodGet, "/groups/"+gid+"/join-requests", nil).Expect(t, http.StatusOK).List()
	if len(reqs) != 1 || reqs[0].(map[string]any)["display_name"] != "Test joiner" {
		t.Fatalf("join requests = %v", reqs)
	}
	if r := x.c.Do(t, http.MethodGet, "/groups/"+gid+"/join-requests", nil); r.Status != http.StatusForbidden {
		t.Fatalf("member listing join requests: %d", r.Status)
	}
	o.c.Do(t, http.MethodPost, "/groups/"+gid+"/join-requests/"+jr["id"].(string)+"/approve", nil).Expect(t, http.StatusOK)
	s.RunJobs(t)
	if n := notificationsOf(t, y.c, "group", "join_approved"); n != 1 {
		t.Fatalf("approved requester notifications = %d", n)
	}
	if n := notificationsOf(t, x.c, "group", "member_joined"); n != 0 {
		t.Fatalf("member with level none was notified: %d", n)
	}

	// Revoked links stop working.
	o.c.Do(t, http.MethodDelete, "/groups/"+gid+"/invitations/"+inv["id"].(string), nil).Expect(t, http.StatusOK)
	if r := out.c.Do(t, http.MethodPost, "/group-invitations/accept", map[string]any{"token": tok}); r.Status == http.StatusOK {
		t.Fatal("revoked link accepted")
	}

	// Ownership transfer; the owner cannot leave before transferring.
	if r := o.c.Do(t, http.MethodDelete, "/groups/"+gid+"/members/"+o.id, nil); r.ErrorCode() != "DOMAIN_RULE_VIOLATION" {
		t.Fatalf("owner leaving: %s", r.Raw)
	}
	t2 := o.c.Do(t, http.MethodPost, "/groups/"+gid+"/transfer-ownership", map[string]any{"user_id": b.id}).Expect(t, http.StatusOK).Data()
	if t2["my_role"] != "admin" {
		t.Fatalf("previous owner role = %v", t2["my_role"])
	}
	if b.c.Do(t, http.MethodGet, "/groups/"+gid, nil).Expect(t, http.StatusOK).Data()["my_role"] != "owner" {
		t.Fatal("new owner role")
	}

	// Leaving with a zero balance works and ends access.
	y.c.Do(t, http.MethodDelete, "/groups/"+gid+"/members/"+y.id, nil).Expect(t, http.StatusOK)
	if r := y.c.Do(t, http.MethodGet, "/groups/"+gid, nil); r.Status != http.StatusNotFound {
		t.Fatalf("former member still reads the group: %d", r.Status)
	}
	members := b.c.Do(t, http.MethodGet, "/groups/"+gid, nil).Expect(t, http.StatusOK).Data()["members"].([]any)
	var left bool
	for _, m := range members {
		if m.(map[string]any)["user_id"] == y.id {
			left = m.(map[string]any)["status"] == "left" && m.(map[string]any)["display_name"] == "Test joiner"
		}
	}
	if !left {
		t.Fatalf("former member must stay visible by name: %v", members)
	}

	// Group membership never exposes personal records.
	acct := createAccount(t, o.c, map[string]any{"name": "Private", "account_type": "bank", "currency": "INR", "opening_balance": "5000"})["id"].(string)
	if r := x.c.Do(t, http.MethodGet, "/accounts/"+acct, nil); r.Status != http.StatusNotFound {
		t.Fatalf("group member read another member's account: %d", r.Status)
	}

	// Archive makes it read-only; delete needs explicit confirmation.
	b.c.Do(t, http.MethodPost, "/groups/"+gid+"/archive", nil).Expect(t, http.StatusOK)
	if r := b.c.Do(t, http.MethodPost, "/groups/"+gid+"/invitations", map[string]any{"kind": "link"}); r.Status != http.StatusConflict || detail(t, r)["code"] != "group_archived" {
		t.Fatalf("invite in archived group: %d %s", r.Status, r.Raw)
	}
	b.c.Do(t, http.MethodPost, "/groups/"+gid+"/restore", nil).Expect(t, http.StatusOK)
	if r := b.c.Do(t, http.MethodDelete, "/groups/"+gid, nil); r.ErrorCode() != "VALIDATION_ERROR" {
		t.Fatalf("delete without confirm: %s", r.Raw)
	}
	b.c.Do(t, http.MethodDelete, "/groups/"+gid+"?confirm=true", nil).Expect(t, http.StatusOK)
	if r := x.c.Do(t, http.MethodGet, "/groups/"+gid, nil); r.Status != http.StatusNotFound {
		t.Fatalf("deleted group still readable: %d", r.Status)
	}
}

func shareOf(e map[string]any, uid string) string {
	for _, sh := range e["shares"].([]any) {
		if sh.(map[string]any)["user_id"] == uid {
			return sh.(map[string]any)["share"].(map[string]any)["amount"].(string)
		}
	}
	return "-"
}

func netOf(b map[string]any, uid string) string {
	for _, x := range b["balances"].([]any) {
		if x.(map[string]any)["user_id"] == uid {
			return x.(map[string]any)["net"].(map[string]any)["amount"].(string)
		}
	}
	return "-"
}

func TestGroupSplitsBalancesAndSettlementLifecycle(t *testing.T) {
	s := apitest.New(t, nil)
	a := newPerson(t, s, "ana", nil)
	b := newPerson(t, s, "ben", nil)
	c := newPerson(t, s, "cy", nil)
	gid := createGroup(t, a.c, map[string]any{"name": "Flat 4B", "group_type": "household", "base_currency": "INR"})["id"].(string)
	joinByLink(t, a, b, gid)
	joinByLink(t, a, c, gid)
	exp := func(p person, body map[string]any) map[string]any {
		t.Helper()
		return p.c.Do(t, http.MethodPost, "/groups/"+gid+"/expenses", body, "Idempotency-Key", key()).Expect(t, http.StatusCreated).Data()
	}
	all := []any{map[string]any{"user_id": a.id}, map[string]any{"user_id": b.id}, map[string]any{"user_id": c.id}}

	// Equal: 100.00 / 3 → the remainder paisa goes to the first participant.
	e1 := exp(a, map[string]any{"description": "Groceries", "amount": "100", "split_method": "equal", "participants": all, "category_key": "groceries"})
	if shareOf(e1, a.id) != "33.34" || shareOf(e1, b.id) != "33.33" || shareOf(e1, c.id) != "33.33" || e1["my_paid"].(map[string]any)["amount"] != "100.00" {
		t.Fatalf("equal split = %v", e1["shares"])
	}
	// Exact (excluding cy) paid by ben.
	exp(b, map[string]any{"description": "Movie", "amount": "50", "split_method": "exact",
		"participants": []any{map[string]any{"user_id": a.id, "value": "20"}, map[string]any{"user_id": b.id, "value": "30"}}})
	if r := b.c.Do(t, http.MethodPost, "/groups/"+gid+"/expenses", map[string]any{"description": "Bad", "amount": "50", "split_method": "exact",
		"participants": []any{map[string]any{"user_id": a.id, "value": "20"}, map[string]any{"user_id": b.id, "value": "20"}}}, "Idempotency-Key", key()); r.ErrorCode() != "DOMAIN_RULE_VIOLATION" {
		t.Fatalf("exact split not summing to total: %s", r.Raw)
	}
	// Percentages must total exactly 100.
	e3 := exp(c, map[string]any{"description": "Internet", "amount": "999.99", "split_method": "percentage",
		"participants": []any{map[string]any{"user_id": a.id, "value": "33.33"}, map[string]any{"user_id": b.id, "value": "33.33"}, map[string]any{"user_id": c.id, "value": "33.34"}}})
	if shareOf(e3, a.id) != "333.30" || shareOf(e3, b.id) != "333.30" || shareOf(e3, c.id) != "333.39" {
		t.Fatalf("percentage split = %v", e3["shares"])
	}
	if r := c.c.Do(t, http.MethodPost, "/groups/"+gid+"/expenses", map[string]any{"description": "Bad", "amount": "10", "split_method": "percentage",
		"participants": []any{map[string]any{"user_id": a.id, "value": "50"}, map[string]any{"user_id": b.id, "value": "49.99"}}}, "Idempotency-Key", key()); r.ErrorCode() != "DOMAIN_RULE_VIOLATION" {
		t.Fatalf("percentages not totalling 100: %s", r.Raw)
	}
	// Shares 2:1:1 with two payers.
	e4 := exp(a, map[string]any{"description": "Electricity", "amount": "1000", "split_method": "shares",
		"participants": []any{map[string]any{"user_id": a.id, "value": "2"}, map[string]any{"user_id": b.id, "value": "1"}, map[string]any{"user_id": c.id, "value": "1"}},
		"payers":       []any{map[string]any{"user_id": a.id, "amount": "600"}, map[string]any{"user_id": b.id, "amount": "400"}}})
	if shareOf(e4, a.id) != "500.00" || shareOf(e4, b.id) != "250.00" || len(e4["payers"].([]any)) != 2 {
		t.Fatalf("shares split = %v payers=%v", e4["shares"], e4["payers"])
	}
	if r := a.c.Do(t, http.MethodPost, "/groups/"+gid+"/expenses", map[string]any{"description": "Bad", "amount": "1000", "split_method": "equal", "participants": all,
		"payers": []any{map[string]any{"user_id": a.id, "amount": "600"}}}, "Idempotency-Key", key()); r.ErrorCode() != "DOMAIN_RULE_VIOLATION" {
		t.Fatalf("payers not totalling the amount: %s", r.Raw)
	}
	// Itemized with tax/tip shared in proportion to item subtotals.
	e5 := exp(c, map[string]any{"description": "Dinner", "amount": "880", "split_method": "itemized", "participants": all,
		"items": []any{
			map[string]any{"description": "Pizza", "amount": "600", "shared_by": []any{map[string]any{"user_id": a.id}, map[string]any{"user_id": b.id}}},
			map[string]any{"description": "Drinks", "amount": "200", "shared_by": []any{map[string]any{"user_id": c.id}}},
		}})
	if shareOf(e5, a.id) != "330.00" || shareOf(e5, b.id) != "330.00" || shareOf(e5, c.id) != "220.00" {
		t.Fatalf("itemized split = %v", e5["shares"])
	}
	if items := e5["items"].([]any); len(items) != 2 || len(items[0].(map[string]any)["shares"].([]any)) != 2 {
		t.Fatalf("items = %v", e5["items"])
	}
	// Non-members cannot be participants.
	out := newPerson(t, s, "stranger", nil)
	if r := a.c.Do(t, http.MethodPost, "/groups/"+gid+"/expenses", map[string]any{"description": "Bad", "amount": "10", "split_method": "equal",
		"participants": []any{map[string]any{"user_id": out.id}}}, "Idempotency-Key", key()); r.ErrorCode() != "VALIDATION_ERROR" {
		t.Fatalf("non-member participant: %s", r.Raw)
	}

	// Balances: paid − share. ana paid 100 + 600 = 700, share 33.34+20+333.30+500+330 = 1216.64 → −516.64
	// ben paid 50 + 400 = 450, share 33.33+30+333.30+250+330 = 976.63 → −526.63
	// cy paid 999.99 + 880 = 1879.99, share 33.33+333.39+250+220 = 836.72 → +1043.27
	bal := a.c.Do(t, http.MethodGet, "/groups/"+gid+"/balances", nil).Expect(t, http.StatusOK).Data()
	if netOf(bal, a.id) != "-516.64" || netOf(bal, b.id) != "-526.63" || netOf(bal, c.id) != "1043.27" || bal["my_net"].(map[string]any)["amount"] != "-516.64" {
		t.Fatalf("balances = %v", bal["balances"])
	}
	var simplifiedTotal int64
	for _, tr := range bal["simplified"].([]any) {
		simplifiedTotal += int64(tr.(map[string]any)["amount"].(map[string]any)["amount_minor"].(float64))
	}
	if simplifiedTotal != 104327 || len(bal["original_debts"].([]any)) == 0 {
		t.Fatalf("simplified = %v original = %v", bal["simplified"], bal["original_debts"])
	}
	sg := b.c.Do(t, http.MethodGet, "/groups/"+gid+"/settlement-suggestions?mine=true", nil).Expect(t, http.StatusOK).Data()
	if sg["mode"] != "simplified" || len(sg["suggestions"].([]any)) != 1 {
		t.Fatalf("ben's suggestions = %v", sg)
	}

	// Leaving or deleting with open balances is refused.
	if r := b.c.Do(t, http.MethodDelete, "/groups/"+gid+"/members/"+b.id, nil); r.ErrorCode() != "DOMAIN_RULE_VIOLATION" {
		t.Fatalf("leaving with a balance: %s", r.Raw)
	}
	if r := a.c.Do(t, http.MethodDelete, "/groups/"+gid+"?confirm=true", nil); r.ErrorCode() != "DOMAIN_RULE_VIOLATION" {
		t.Fatalf("deleting with balances: %s", r.Raw)
	}

	// Settlement: ben reports paying cy 500 (partial) → pending until cy confirms.
	k := key()
	st := b.c.Do(t, http.MethodPost, "/groups/"+gid+"/settlements", map[string]any{"payer_user_id": b.id, "payee_user_id": c.id, "amount": "500",
		"method": "upi"}, "Idempotency-Key", k).Expect(t, http.StatusCreated)
	sd := st.Data()
	if sd["status"] != "user_reported_paid" || sd["verification"] != "user_reported" || sd["counted"] != false {
		t.Fatalf("settlement = %v", sd)
	}
	again := b.c.Do(t, http.MethodPost, "/groups/"+gid+"/settlements", map[string]any{"payer_user_id": b.id, "payee_user_id": c.id, "amount": "500",
		"method": "upi"}, "Idempotency-Key", k).Expect(t, http.StatusCreated)
	if again.Headers.Get("Idempotent-Replayed") != "true" || again.Data()["id"] != sd["id"] {
		t.Fatal("settlement retry must replay")
	}
	sid := sd["id"].(string)
	bal = a.c.Do(t, http.MethodGet, "/groups/"+gid+"/balances", nil).Expect(t, http.StatusOK).Data()
	if netOf(bal, b.id) != "-526.63" {
		t.Fatalf("unconfirmed settlement must not count: %v", netOf(bal, b.id))
	}
	s.RunJobs(t)
	if n := notificationsOf(t, c.c, "settlement", "settlement_reported"); n != 1 {
		t.Fatalf("payee settlement notifications = %d", n)
	}
	if r := b.c.Do(t, http.MethodPost, "/groups/"+gid+"/settlements/"+sid+"/confirm", map[string]any{"version": sd["version"]}); r.Status != http.StatusForbidden {
		t.Fatalf("payer confirming own payment: %d", r.Status)
	}
	if r := c.c.Do(t, http.MethodPost, "/groups/"+gid+"/settlements/"+sid+"/confirm", map[string]any{"version": 99}); r.ErrorCode() != "VERSION_CONFLICT" {
		t.Fatalf("stale version: %s", r.Raw)
	}
	cd := c.c.Do(t, http.MethodPost, "/groups/"+gid+"/settlements/"+sid+"/confirm", map[string]any{"version": sd["version"]}).Expect(t, http.StatusOK).Data()
	if cd["status"] != "confirmed" || cd["counted"] != true {
		t.Fatalf("confirmed = %v", cd)
	}
	bal = a.c.Do(t, http.MethodGet, "/groups/"+gid+"/balances", nil).Expect(t, http.StatusOK).Data()
	if netOf(bal, b.id) != "-26.63" || netOf(bal, c.id) != "543.27" {
		t.Fatalf("after confirmation: ben %v cy %v", netOf(bal, b.id), netOf(bal, c.id))
	}

	// Dispute → confirm resolves; void needs a reason; correction keeps history.
	dd := c.c.Do(t, http.MethodPost, "/groups/"+gid+"/settlements/"+sid+"/dispute", map[string]any{"version": cd["version"], "reason": "Only got 450"}).
		Expect(t, http.StatusOK).Data()
	if dd["status"] != "disputed" || dd["counted"] != false {
		t.Fatalf("disputed = %v", dd)
	}
	if r := b.c.Do(t, http.MethodPost, "/groups/"+gid+"/settlements/"+sid+"/void", map[string]any{"version": dd["version"]}); r.ErrorCode() != "VALIDATION_ERROR" {
		t.Fatalf("void without reason: %s", r.Raw)
	}
	corr := b.c.Do(t, http.MethodPost, "/groups/"+gid+"/settlements/"+sid+"/correct", map[string]any{"payer_user_id": b.id, "payee_user_id": c.id,
		"amount": "450", "method": "upi"}, "Idempotency-Key", key()).Expect(t, http.StatusCreated).Data()
	if corr["corrects_settlement_id"] != sid || corr["status"] != "user_reported_paid" {
		t.Fatalf("correction = %v", corr)
	}
	old := a.c.Do(t, http.MethodGet, "/groups/"+gid+"/settlements/"+sid, nil).Expect(t, http.StatusOK).Data()
	if old["status"] != "voided" || old["corrected_by_settlement_id"] != corr["id"] || old["void_reason"] != "Corrected" {
		t.Fatalf("original after correction = %v", old)
	}
	c.c.Do(t, http.MethodPost, "/groups/"+gid+"/settlements/"+corr["id"].(string)+"/confirm", map[string]any{"version": corr["version"]}).Expect(t, http.StatusOK)
	bal = a.c.Do(t, http.MethodGet, "/groups/"+gid+"/balances", nil).Expect(t, http.StatusOK).Data()
	if netOf(bal, b.id) != "-76.63" {
		t.Fatalf("after correction ben = %v", netOf(bal, b.id))
	}
	// The payee recording receipt confirms immediately; a proposal is a plan.
	pr := c.c.Do(t, http.MethodPost, "/groups/"+gid+"/settlements", map[string]any{"payer_user_id": a.id, "payee_user_id": c.id, "amount": "100",
		"state": "proposed"}, "Idempotency-Key", key()).Expect(t, http.StatusCreated).Data()
	if pr["status"] != "proposed" {
		t.Fatalf("proposal = %v", pr)
	}
	mp := a.c.Do(t, http.MethodPost, "/groups/"+gid+"/settlements/"+pr["id"].(string)+"/mark-paid", map[string]any{"version": pr["version"]}).Expect(t, http.StatusOK).Data()
	if mp["status"] != "user_reported_paid" {
		t.Fatalf("mark paid = %v", mp)
	}
	rc := c.c.Do(t, http.MethodPost, "/groups/"+gid+"/settlements", map[string]any{"payer_user_id": a.id, "payee_user_id": c.id, "amount": "16.64"},
		"Idempotency-Key", key()).Expect(t, http.StatusCreated).Data()
	if rc["status"] != "confirmed" {
		t.Fatalf("payee-recorded settlement = %v", rc)
	}
	c.c.Do(t, http.MethodPost, "/groups/"+gid+"/settlements/"+mp["id"].(string)+"/void", map[string]any{"version": mp["version"], "reason": "Paid in cash instead"}).
		Expect(t, http.StatusOK)

	// Comments and disputes on expenses; edit history is kept.
	e1id := e1["id"].(string)
	b.c.Do(t, http.MethodPost, "/groups/"+gid+"/expenses/"+e1id+"/comments", map[string]any{"body": "Includes my oat milk?"}).Expect(t, http.StatusCreated)
	dsp := b.c.Do(t, http.MethodPost, "/groups/"+gid+"/expenses/"+e1id+"/disputes", map[string]any{"reason": "Wrong total"}).Expect(t, http.StatusCreated).Data()
	got := a.c.Do(t, http.MethodGet, "/groups/"+gid+"/expenses/"+e1id, nil).Expect(t, http.StatusOK).Data()
	if got["status"] != "disputed" || len(got["comments"].([]any)) != 1 || len(got["disputes"].([]any)) != 1 || got["revisions"].(float64) != 1 {
		t.Fatalf("expense detail = %v", got)
	}
	if r := c.c.Do(t, http.MethodPost, "/groups/"+gid+"/disputes/"+dsp["id"].(string)+"/resolve", map[string]any{"resolution": "x"}); r.Status != http.StatusForbidden {
		t.Fatalf("uninvolved member resolving: %d", r.Status)
	}
	upd := a.c.Do(t, http.MethodPatch, "/groups/"+gid+"/expenses/"+e1id, map[string]any{"description": "Groceries", "amount": "90", "split_method": "equal",
		"participants": all, "version": got["version"]}).Expect(t, http.StatusOK).Data()
	if upd["revisions"].(float64) != 2 || shareOf(upd, a.id) != "30.00" {
		t.Fatalf("edited expense = %v", upd)
	}
	a.c.Do(t, http.MethodPost, "/groups/"+gid+"/disputes/"+dsp["id"].(string)+"/resolve", map[string]any{"resolution": "Fixed the total"}).Expect(t, http.StatusOK)
	resolved := false
	for _, x := range a.c.Do(t, http.MethodGet, "/groups/"+gid+"/activity", nil).Expect(t, http.StatusOK).Data()["events"].([]any) {
		ev := x.(map[string]any)
		if ev["kind"] == "dispute_resolved" {
			sum := ev["summary"].(map[string]any)
			resolved = sum["target"] == e1id && sum["target_type"] == "expense"
		}
	}
	if !resolved {
		t.Fatal("dispute_resolved activity does not name its expense target and type")
	}
	if st := a.c.Do(t, http.MethodGet, "/groups/"+gid+"/expenses/"+e1id, nil).Expect(t, http.StatusOK).Data()["status"]; st != "active" {
		t.Fatalf("status after resolution = %v", st)
	}
	if r := a.c.Do(t, http.MethodPatch, "/groups/"+gid+"/expenses/"+e1id, map[string]any{"description": "Stale", "amount": "90", "split_method": "equal",
		"participants": all, "version": got["version"]}); r.ErrorCode() != "VERSION_CONFLICT" {
		t.Fatalf("stale edit: %s", r.Raw)
	}
	// Only the creator or an admin deletes.
	if r := c.c.Do(t, http.MethodDelete, "/groups/"+gid+"/expenses/"+e1id, nil); r.Status != http.StatusForbidden {
		t.Fatalf("non-creator deleting: %d", r.Status)
	}

	// Report and export.
	rep := b.c.Do(t, http.MethodGet, "/groups/"+gid+"/reports", nil).Expect(t, http.StatusOK).Data()
	if rep["expense_count"].(float64) != 5 || rep["total_spent"].(map[string]any)["amount"] != "3019.99" || len(rep["by_member"].([]any)) != 3 ||
		rep["settlements"].(map[string]any)["count"].(float64) != 2 {
		t.Fatalf("report = %v", rep)
	}
	exp(a, map[string]any{"description": "=HYPERLINK(\"http://x\")", "amount": "1", "split_method": "equal", "participants": all[:1]})
	csvResp := a.c.Do(t, http.MethodGet, "/groups/"+gid+"/export", nil).Expect(t, http.StatusOK)
	rd := csv.NewReader(bytes.NewReader(bytes.TrimPrefix(csvResp.Raw, []byte("\xef\xbb\xbf"))))
	rd.FieldsPerRecord = -1
	rows, err := rd.ReadAll()
	if err != nil {
		t.Fatal(err)
	}
	var injected bool
	for _, row := range rows {
		if len(row) > 2 && strings.HasPrefix(row[2], "=") {
			injected = true
		}
	}
	if len(rows) != 1+6+4 || injected {
		t.Fatalf("export rows = %d (injection=%v)", len(rows), injected)
	}

	// Activity log and member notifications.
	if act := a.c.Do(t, http.MethodGet, "/groups/"+gid+"/activity", nil).Expect(t, http.StatusOK).Data()["events"].([]any); len(act) < 10 {
		t.Fatalf("activity = %d events", len(act))
	}
	s.RunJobs(t)
	if n := notificationsOf(t, b.c, "group", "expense_added"); n < 4 {
		t.Fatalf("ben expense notifications = %d", n)
	}
}

func TestGroupLinkedPersonalRecordsStayInSync(t *testing.T) {
	s := apitest.New(t, nil)
	a := newPerson(t, s, "payer", nil)
	b := newPerson(t, s, "friend", nil)
	gid := createGroup(t, a.c, map[string]any{"name": "Trip", "group_type": "trip", "base_currency": "INR"})["id"].(string)
	joinByLink(t, a, b, gid)
	acctA := createAccount(t, a.c, map[string]any{"name": "Bank", "account_type": "bank", "currency": "INR", "opening_balance": "10000"})["id"].(string)
	acctB := createAccount(t, b.c, map[string]any{"name": "Bank", "account_type": "bank", "currency": "INR", "opening_balance": "10000"})["id"].(string)
	usd := createAccount(t, a.c, map[string]any{"name": "USD", "account_type": "bank", "currency": "USD"})["id"].(string)
	both := []any{map[string]any{"user_id": a.id}, map[string]any{"user_id": b.id}}

	if r := a.c.Do(t, http.MethodPost, "/groups/"+gid+"/expenses", map[string]any{"description": "Hotel", "amount": "3000", "split_method": "equal",
		"participants": both, "payer_account_id": usd}, "Idempotency-Key", key()); r.ErrorCode() != "VALIDATION_ERROR" {
		t.Fatalf("account in another currency: %s", r.Raw)
	}
	if r := b.c.Do(t, http.MethodPost, "/groups/"+gid+"/expenses", map[string]any{"description": "Hotel", "amount": "3000", "split_method": "equal",
		"participants": both, "payer_account_id": acctB, "payers": []any{map[string]any{"user_id": a.id, "amount": "3000"}}}, "Idempotency-Key", key()); r.Status == http.StatusCreated {
		t.Fatal("a non-payer must not record the payment in their account")
	}
	e := a.c.Do(t, http.MethodPost, "/groups/"+gid+"/expenses", map[string]any{"description": "Hotel", "amount": "3000", "split_method": "equal",
		"participants": both, "payer_account_id": acctA}, "Idempotency-Key", key()).Expect(t, http.StatusCreated).Data()
	eid := e["id"].(string)
	txID, _ := e["my_transaction_id"].(string)
	if txID == "" {
		t.Fatalf("payer's linked record missing: %v", e)
	}
	if bv := b.c.Do(t, http.MethodGet, "/groups/"+gid+"/expenses/"+eid, nil).Expect(t, http.StatusOK).Data(); bv["my_transaction_id"] != nil {
		t.Fatal("another member must never see the payer's personal record")
	}
	if r := b.c.Do(t, http.MethodGet, "/transactions/"+txID, nil); r.Status != http.StatusNotFound {
		t.Fatalf("member read the payer's transaction: %d", r.Status)
	}
	for _, x := range b.c.Do(t, http.MethodGet, "/transactions?include_shared=true&status=all", nil).Expect(t, http.StatusOK).List() {
		if x.(map[string]any)["id"] == txID {
			t.Fatal("include_shared exposed another member's linked personal record")
		}
	}
	tx := a.c.Do(t, http.MethodGet, "/transactions/"+txID, nil).Expect(t, http.StatusOK).Data()
	if tx["type"] != "group_expense" || money(tx, "amount") != "3000.00" || money(tx, "personal_share") != "1500.00" || balance(t, a.c, acctA) != "7000.00" {
		t.Fatalf("linked record = %v balance=%s", tx, balance(t, a.c, acctA))
	}
	if r := a.c.Do(t, http.MethodDelete, "/transactions/"+txID, nil); r.ErrorCode() != "DOMAIN_RULE_VIOLATION" {
		t.Fatalf("group-linked record deleted directly: %s", r.Raw)
	}

	// Another member edits the expense: the worker re-syncs the payer's record.
	b.c.Do(t, http.MethodPatch, "/groups/"+gid+"/expenses/"+eid, map[string]any{"description": "Hotel", "amount": "3600", "split_method": "exact",
		"participants": []any{map[string]any{"user_id": a.id, "value": "1000"}, map[string]any{"user_id": b.id, "value": "2600"}},
		"payers":       []any{map[string]any{"user_id": a.id, "amount": "3600"}}, "version": e["version"]}).Expect(t, http.StatusOK)
	s.RunJobs(t)
	tx = a.c.Do(t, http.MethodGet, "/transactions/"+txID, nil).Expect(t, http.StatusOK).Data()
	if money(tx, "amount") != "3600.00" || money(tx, "personal_share") != "1000.00" || balance(t, a.c, acctA) != "6400.00" {
		t.Fatalf("after edit: %v balance=%s", tx, balance(t, a.c, acctA))
	}
	if n := notificationsOf(t, a.c, "group", "group_record_synced"); n != 1 {
		t.Fatalf("sync notifications = %d", n)
	}
	audit := a.c.Do(t, http.MethodGet, "/transactions/"+txID+"/audit", nil).Expect(t, http.StatusOK).List()
	var synced bool
	for _, ev := range audit {
		if ev.(map[string]any)["action"] == "updated" && ev.(map[string]any)["actor_kind"] == "system" {
			synced = true
		}
	}
	if !synced {
		t.Fatalf("sync must be audited as system: %v", audit)
	}
	// Deleting the expense voids the payer's record.
	a.c.Do(t, http.MethodDelete, "/groups/"+gid+"/expenses/"+eid, nil).Expect(t, http.StatusOK)
	s.RunJobs(t)
	if st := a.c.Do(t, http.MethodGet, "/transactions/"+txID, nil).Expect(t, http.StatusOK).Data()["status"]; st != "voided" || balance(t, a.c, acctA) != "10000.00" {
		t.Fatalf("after delete: status=%v balance=%s", st, balance(t, a.c, acctA))
	}

	// Link later and unlink via the group.
	e2 := a.c.Do(t, http.MethodPost, "/groups/"+gid+"/expenses", map[string]any{"description": "Cab", "amount": "800", "split_method": "equal",
		"participants": both}, "Idempotency-Key", key()).Expect(t, http.StatusCreated).Data()
	l := a.c.Do(t, http.MethodPost, "/groups/"+gid+"/expenses/"+e2["id"].(string)+"/my-record", map[string]any{"action": "link", "account_id": acctA}).
		Expect(t, http.StatusOK).Data()
	if l["my_transaction_id"] == nil || balance(t, a.c, acctA) != "9200.00" {
		t.Fatalf("link later: %v balance=%s", l["my_transaction_id"], balance(t, a.c, acctA))
	}
	if r := b.c.Do(t, http.MethodPost, "/groups/"+gid+"/expenses/"+e2["id"].(string)+"/my-record", map[string]any{"action": "link", "account_id": acctB}); r.ErrorCode() != "DOMAIN_RULE_VIOLATION" {
		t.Fatalf("non-payer linking: %s", r.Raw)
	}
	a.c.Do(t, http.MethodPost, "/groups/"+gid+"/expenses/"+e2["id"].(string)+"/my-record", map[string]any{"action": "unlink"}).Expect(t, http.StatusOK)
	if balance(t, a.c, acctA) != "10000.00" {
		t.Fatalf("after unlink balance=%s", balance(t, a.c, acctA))
	}

	// Settlement records on both sides; a void by one side reaches the other.
	st := b.c.Do(t, http.MethodPost, "/groups/"+gid+"/settlements", map[string]any{"payer_user_id": b.id, "payee_user_id": a.id, "amount": "400",
		"account_id": acctB}, "Idempotency-Key", key()).Expect(t, http.StatusCreated).Data()
	if st["my_transaction_id"] == nil || balance(t, b.c, acctB) != "9600.00" {
		t.Fatalf("payer settlement record: %v balance=%s", st, balance(t, b.c, acctB))
	}
	cf := a.c.Do(t, http.MethodPost, "/groups/"+gid+"/settlements/"+st["id"].(string)+"/confirm", map[string]any{"version": st["version"], "account_id": acctA}).
		Expect(t, http.StatusOK).Data()
	if cf["my_transaction_id"] == nil || cf["my_transaction_id"] == st["my_transaction_id"] || balance(t, a.c, acctA) != "10400.00" {
		t.Fatalf("payee settlement record: %v balance=%s", cf, balance(t, a.c, acctA))
	}
	stx := b.c.Do(t, http.MethodGet, "/transactions/"+st["my_transaction_id"].(string), nil).Expect(t, http.StatusOK).Data()
	if stx["type"] != "settlement" || stx["direction"] != "outflow" {
		t.Fatalf("settlement record = %v", stx)
	}
	a.c.Do(t, http.MethodPost, "/groups/"+gid+"/settlements/"+st["id"].(string)+"/void", map[string]any{"version": cf["version"], "reason": "Recorded twice"}).
		Expect(t, http.StatusOK)
	if balance(t, a.c, acctA) != "10000.00" {
		t.Fatalf("voider's own record must be voided in the request: %s", balance(t, a.c, acctA))
	}
	s.RunJobs(t)
	if balance(t, b.c, acctB) != "10000.00" {
		t.Fatalf("other party's record must be voided by the worker: %s", balance(t, b.c, acctB))
	}
	if n := notificationsOf(t, b.c, "settlement", "group_record_synced"); n != 1 {
		t.Fatalf("settlement sync notifications = %d", n)
	}
}

func TestGroupRecurringSharedBillsAndForeignCurrency(t *testing.T) {
	s := apitest.New(t, nil)
	a := newPerson(t, s, "host", nil)
	b := newPerson(t, s, "flatmate", nil)
	gid := createGroup(t, a.c, map[string]any{"name": "Home", "group_type": "household", "base_currency": "INR", "timezone": "UTC"})["id"].(string)
	joinByLink(t, a, b, gid)
	both := []any{map[string]any{"user_id": a.id}, map[string]any{"user_id": b.id}}
	today := utcToday()
	ctx := context.Background()

	// Auto-added rent: due today, added once by the scheduler as its creator.
	rent := a.c.Do(t, http.MethodPost, "/groups/"+gid+"/recurring-expenses", map[string]any{"name": "Rent", "frequency": "monthly",
		"start_date": today.Format(day), "local_time": "00:00", "amount": "30000", "auto_add": true, "split_method": "equal", "participants": both},
		"Idempotency-Key", key()).Expect(t, http.StatusCreated).Data()
	rentID := rent["rule"].(map[string]any)["id"].(string)
	if r := a.c.Do(t, http.MethodPost, "/groups/"+gid+"/recurring-expenses", map[string]any{"name": "Bad", "frequency": "monthly",
		"start_date": today.Format(day), "amount": "100", "split_method": "itemized", "participants": both}, "Idempotency-Key", key()); r.ErrorCode() != "VALIDATION_ERROR" {
		t.Fatalf("itemized recurring template: %s", r.Raw)
	}
	for i := 0; i < 2; i++ {
		if err := s.WorkerSvcs.Recurring.Generate(ctx); err != nil {
			t.Fatalf("generate: %v", err)
		}
	}
	list := b.c.Do(t, http.MethodGet, "/groups/"+gid+"/expenses", nil).Expect(t, http.StatusOK).List()
	if len(list) != 1 {
		t.Fatalf("scheduler must add the rent exactly once, got %d", len(list))
	}
	e := list[0].(map[string]any)
	if e["description"] != "Rent" || money(e, "amount") != "30000.00" || shareOf(e, b.id) != "15000.00" || e["created_by"] != a.id {
		t.Fatalf("auto-added expense = %v", e)
	}
	got := b.c.Do(t, http.MethodGet, "/groups/"+gid+"/recurring-expenses/"+rentID, nil).Expect(t, http.StatusOK).Data()
	occ := got["occurrences"].([]any)
	var posted bool
	for _, o := range occ {
		if o.(map[string]any)["status"] == "posted" && o.(map[string]any)["group_expense_id"] == e["id"] {
			posted = true
		}
	}
	if !posted {
		t.Fatalf("occurrence not linked: %v", occ)
	}
	// Members see it; only its creator or admins change it.
	if r := b.c.Do(t, http.MethodPatch, "/groups/"+gid+"/recurring-expenses/"+rentID, map[string]any{"name": "Rent", "amount": "1",
		"participants": both, "version": got["rule"].(map[string]any)["version"]}); r.Status != http.StatusForbidden {
		t.Fatalf("member editing someone else's recurring expense: %d", r.Status)
	}
	// Group rules never leak into personal recurring endpoints.
	for _, l := range a.c.Do(t, http.MethodGet, "/recurring-rules", nil).Expect(t, http.StatusOK).List() {
		if l.(map[string]any)["id"] == rentID {
			t.Fatal("group rule listed as a personal rule")
		}
	}
	if r := a.c.Do(t, http.MethodGet, "/recurring-rules/"+rentID, nil); r.Status != http.StatusNotFound {
		t.Fatalf("group rule through the personal endpoint: %d", r.Status)
	}
	occID := occ[len(occ)-1].(map[string]any)["id"].(string)
	if r := a.c.Do(t, http.MethodPost, "/recurring-occurrences/"+occID+"/actions", map[string]any{"action": "skip"}, "Idempotency-Key", key()); r.Status != http.StatusNotFound {
		t.Fatalf("group occurrence through the personal endpoint: %d", r.Status)
	}
	// Shared bills show on members' calendars.
	cal := b.c.Do(t, http.MethodGet, "/calendar?from="+today.Format(day)+"&to="+today.AddDate(0, 0, 40).Format(day), nil).Expect(t, http.StatusOK).List()
	var onCal bool
	for _, it := range cal {
		if it.(map[string]any)["kind"] == "group_expense" && it.(map[string]any)["group_id"] == gid {
			onCal = true
		}
	}
	if !onCal {
		t.Fatalf("shared bill missing from a member's calendar: %v", cal)
	}

	// Manually added internet: any member adds it once; the creator skips.
	inet := b.c.Do(t, http.MethodPost, "/groups/"+gid+"/recurring-expenses", map[string]any{"name": "Internet", "frequency": "weekly",
		"start_date": today.Format(day), "amount": "700", "participants": both}, "Idempotency-Key", key()).Expect(t, http.StatusCreated).Data()
	inetID := inet["rule"].(map[string]any)["id"].(string)
	if err := s.WorkerSvcs.Recurring.Generate(ctx); err != nil {
		t.Fatal(err)
	}
	inet = b.c.Do(t, http.MethodGet, "/groups/"+gid+"/recurring-expenses/"+inetID, nil).Expect(t, http.StatusOK).Data()
	occs := inet["occurrences"].([]any)
	first := occs[len(occs)-1].(map[string]any)
	if first["status"] != "scheduled" || first["group_expense_id"] != nil {
		t.Fatalf("manual rule must not be auto-added: %v", first)
	}
	k := key()
	add := a.c.Do(t, http.MethodPost, "/groups/"+gid+"/recurring-expenses/"+inetID+"/occurrences/"+first["id"].(string)+"/add", nil, "Idempotency-Key", k).
		Expect(t, http.StatusCreated)
	again := a.c.Do(t, http.MethodPost, "/groups/"+gid+"/recurring-expenses/"+inetID+"/occurrences/"+first["id"].(string)+"/add", nil, "Idempotency-Key", k).
		Expect(t, http.StatusCreated)
	if again.Headers.Get("Idempotent-Replayed") != "true" || again.Data()["id"] != add.Data()["id"] {
		t.Fatal("adding an occurrence must be idempotent")
	}
	if r := b.c.Do(t, http.MethodPost, "/groups/"+gid+"/recurring-expenses/"+inetID+"/occurrences/"+first["id"].(string)+"/add", nil, "Idempotency-Key", key()); r.Status != http.StatusConflict {
		t.Fatalf("adding an occurrence twice: %d", r.Status)
	}
	if ex := add.Data(); ex["my_paid"].(map[string]any)["amount"] != "700.00" {
		t.Fatalf("the member who adds it pays by default: %v", ex["payers"])
	}
	second := occs[len(occs)-2].(map[string]any)
	if r := a.c.Do(t, http.MethodPost, "/groups/"+gid+"/recurring-expenses/"+inetID+"/occurrences/"+second["id"].(string)+"/skip", nil); r.Status != http.StatusOK {
		t.Fatalf("owner skipping: %d %s", r.Status, r.Raw)
	}
	paused := b.c.Do(t, http.MethodPost, "/groups/"+gid+"/recurring-expenses/"+inetID+"/pause", nil).Expect(t, http.StatusOK).Data()
	if paused["rule"].(map[string]any)["status"] != "paused" {
		t.Fatalf("pause = %v", paused["rule"])
	}

	// A participant leaves the group: next month's automatic rent fails once,
	// the creator is told, and the occurrence waits for a member.
	a.c.Do(t, http.MethodDelete, "/groups/"+gid+"/members/"+b.id, nil).Expect(t, http.StatusOK)
	sim := time.Now().UTC().AddDate(0, 1, 1)
	s.WorkerSvcs.Recurring.Now = func() time.Time { return sim }
	for i := 0; i < 2; i++ {
		if err := s.WorkerSvcs.Recurring.Generate(ctx); err != nil {
			t.Fatalf("generate with a failing occurrence must not fail the run: %v", err)
		}
	}
	s.RunJobs(t)
	if n := notificationsOf(t, a.c, "group", "group_recurring_failed"); n != 1 {
		t.Fatalf("creator failure notifications = %d", n)
	}
	if n := len(a.c.Do(t, http.MethodGet, "/groups/"+gid+"/expenses", nil).Expect(t, http.StatusOK).List()); n != 2 {
		t.Fatalf("expenses after the failed auto-add = %d", n)
	}

	// Foreign-currency expense: the rate is disclosed and must reconcile exactly.
	if r := a.c.Do(t, http.MethodPost, "/groups/"+gid+"/expenses", map[string]any{"description": "Airport taxi", "amount": "8300",
		"original_amount": "100", "original_currency": "USD", "fx_rate": "83.25", "participants": []any{map[string]any{"user_id": a.id}}},
		"Idempotency-Key", key()); r.ErrorCode() != "VALIDATION_ERROR" {
		t.Fatalf("amount not matching original × rate: %s", r.Raw)
	}
	fxe := a.c.Do(t, http.MethodPost, "/groups/"+gid+"/expenses", map[string]any{"description": "Airport taxi", "amount": "8325",
		"original_amount": "100", "original_currency": "USD", "fx_rate": "83.25", "participants": []any{map[string]any{"user_id": a.id}}},
		"Idempotency-Key", key()).Expect(t, http.StatusCreated).Data()
	if fxe["fx_rate_source"] != "manual" || fxe["original_amount"].(map[string]any)["amount"] != "100.00" || fxe["fx_rate"] == nil {
		t.Fatalf("fx expense = %v", fxe)
	}
	rep := a.c.Do(t, http.MethodGet, "/groups/"+gid+"/reports", nil).Expect(t, http.StatusOK).Data()
	oc := rep["original_currencies"].([]any)
	if len(oc) != 1 || oc[0].(map[string]any)["currency"] != "USD" || oc[0].(map[string]any)["converted"].(map[string]any)["amount"] != "8325.00" {
		t.Fatalf("original currencies = %v", oc)
	}
	// Currency is fixed once records exist; archiving pauses recurring bills.
	g := a.c.Do(t, http.MethodGet, "/groups/"+gid, nil).Expect(t, http.StatusOK).Data()
	if r := a.c.Do(t, http.MethodPatch, "/groups/"+gid, map[string]any{"name": "Home", "group_type": "household", "base_currency": "EUR",
		"version": g["version"]}); r.ErrorCode() != "DOMAIN_RULE_VIOLATION" {
		t.Fatalf("currency change with records: %s", r.Raw)
	}
	a.c.Do(t, http.MethodPost, "/groups/"+gid+"/archive", nil).Expect(t, http.StatusOK)
	if st := a.c.Do(t, http.MethodGet, "/groups/"+gid+"/recurring-expenses/"+rentID, nil).Expect(t, http.StatusOK).Data()["rule"].(map[string]any)["status"]; st != "paused" {
		t.Fatalf("rent after archive = %v", st)
	}
}

// Trip reminders: the day before a trip starts, and the day after it ends
// while balances are open; daytime only, once each, never with amounts.
func TestTripReminders(t *testing.T) {
	s := apitest.New(t, nil)
	a := newPerson(t, s, "traveller", nil)
	b := newPerson(t, s, "companion", nil)
	loc, _ := time.LoadLocation("Asia/Kolkata")
	n := time.Now().In(loc)
	today := time.Date(n.Year(), n.Month(), n.Day(), 0, 0, 0, 0, loc)
	at := func(h int) time.Time { return today.Add(time.Duration(h) * time.Hour) }

	upcoming := createGroup(t, a.c, map[string]any{"name": "Goa", "group_type": "trip", "base_currency": "INR",
		"start_date": today.AddDate(0, 0, 1).Format(day), "end_date": today.AddDate(0, 0, 4).Format(day)})["id"].(string)
	joinByLink(t, a, b, upcoming)
	ended := createGroup(t, a.c, map[string]any{"name": "Pune", "group_type": "trip", "base_currency": "INR",
		"start_date": today.AddDate(0, 0, -3).Format(day), "end_date": today.AddDate(0, 0, -1).Format(day)})["id"].(string)
	joinByLink(t, a, b, ended)
	acct := createAccount(t, a.c, map[string]any{"name": "Bank", "account_type": "bank", "currency": "INR", "opening_balance": "5000"})["id"].(string)
	a.c.Do(t, http.MethodPost, "/groups/"+ended+"/expenses", map[string]any{"description": "Hotel", "amount": "2000", "split_method": "equal",
		"participants": []any{map[string]any{"user_id": a.id}, map[string]any{"user_id": b.id}}, "payer_account_id": acct}, "Idempotency-Key", key()).
		Expect(t, http.StatusCreated)

	run := func(when time.Time) {
		s.WorkerSvcs.Groups.Now = func() time.Time { return when }
		if err := s.WorkerSvcs.Groups.TripReminders(context.Background()); err != nil {
			t.Fatal(err)
		}
		s.RunJobs(t)
	}
	run(at(3)) // 03:00 local: nothing at night
	if notificationsOf(t, b.c, "trip", "trip_starting") != 0 {
		t.Fatal("night-time trip reminder")
	}
	run(at(10))
	run(at(11)) // deduplicated
	for _, p := range []person{a, b} {
		if got := notificationsOf(t, p.c, "trip", "trip_starting"); got != 1 {
			t.Fatalf("trip starting reminders for %s: %d", p.user, got)
		}
		if got := notificationsOf(t, p.c, "trip", "trip_ended_unsettled"); got != 1 {
			t.Fatalf("trip ended reminders for %s: %d", p.user, got)
		}
	}
}
