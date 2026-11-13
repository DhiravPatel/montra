package api_test

import (
	"fmt"
	"net/http"
	"strings"
	"testing"
	"time"

	"github.com/google/uuid"

	"montra/backend/internal/testutil/apitest"
)

// GET /dashboard/planning: budgets fullest first, overdue then upcoming
// items, goals by nearest target date, open group balances; the widget
// list offers the planning widgets; everything is the caller's own.
func TestDashboardPlanningCardsAndWidgets(t *testing.T) {
	s := apitest.New(t, nil)
	a := newPerson(t, s, "planner", nil)
	b := newPerson(t, s, "flatmate", nil)
	today := utcToday()
	a.c.Do(t, http.MethodPatch, "/me/preferences", map[string]any{"timezone": "UTC"}).Expect(t, http.StatusOK)

	// Empty: lists are present and empty.
	empty := a.c.Do(t, http.MethodGet, "/dashboard/planning", nil).Expect(t, http.StatusOK).Data()
	for _, k := range []string{"budgets", "upcoming", "goals", "group_balances"} {
		if l, ok := empty[k].([]any); !ok || len(l) != 0 {
			t.Fatalf("empty %s = %v", k, empty[k])
		}
	}
	if empty["today"] != today.Format(day) || empty["upcoming_through"] != today.AddDate(0, 0, 14).Format(day) {
		t.Fatalf("window = %v / %v", empty["today"], empty["upcoming_through"])
	}

	acct := createAccount(t, a.c, map[string]any{"name": "Bank", "account_type": "bank", "currency": "INR", "opening_balance": "50000"})["id"].(string)
	low := a.c.Do(t, http.MethodPost, "/budgets", map[string]any{"name": "Roomy", "budget_type": "total", "period": "monthly",
		"currency": "INR", "limit": "100000", "alert_forecast": false}).Expect(t, http.StatusCreated).Data()
	high := a.c.Do(t, http.MethodPost, "/budgets", map[string]any{"name": "Tight", "budget_type": "total", "period": "monthly",
		"currency": "INR", "limit": "1000", "alert_forecast": false}).Expect(t, http.StatusCreated).Data()
	createTx(t, a.c, map[string]any{"type": "expense", "account_id": acct, "amount": "1500"})

	a.c.Do(t, http.MethodPost, "/bills", map[string]any{"name": "Water", "provider_name": "City Water", "expected_amount": "400",
		"frequency": "monthly", "start_date": today.AddDate(0, 0, 3).Format(day), "timezone": "UTC"}, "Idempotency-Key", key()).
		Expect(t, http.StatusCreated)
	a.c.Do(t, http.MethodPost, "/bills", map[string]any{"name": "Far away", "provider_name": "Later Co", "expected_amount": "100",
		"frequency": "yearly", "start_date": today.AddDate(0, 0, 40).Format(day), "timezone": "UTC"}, "Idempotency-Key", key()).
		Expect(t, http.StatusCreated)

	soon := a.c.Do(t, http.MethodPost, "/goals", map[string]any{"name": "Soon", "goal_type": "custom", "target_amount": "1000",
		"target_date": today.AddDate(0, 2, 0).Format(day)}, "Idempotency-Key", key()).Expect(t, http.StatusCreated).Data()
	a.c.Do(t, http.MethodPost, "/goals", map[string]any{"name": "Someday", "goal_type": "custom", "target_amount": "5000"},
		"Idempotency-Key", key()).Expect(t, http.StatusCreated)

	gid := createGroup(t, a.c, map[string]any{"name": "Flat", "group_type": "roommates", "base_currency": "INR", "timezone": "UTC"})["id"].(string)
	joinByLink(t, a, b, gid)
	createGroup(t, a.c, map[string]any{"name": "Settled", "group_type": "friends", "base_currency": "INR", "timezone": "UTC"})
	gfExpense(t, a, gid, map[string]any{"description": "Rent", "amount": "3000", "split_method": "equal", "participants": gfPeople(a, b)})

	p := a.c.Do(t, http.MethodGet, "/dashboard/planning", nil).Expect(t, http.StatusOK).Data()
	bl := p["budgets"].([]any)
	if len(bl) != 2 || bl[0].(map[string]any)["id"] != high["id"] || bl[1].(map[string]any)["id"] != low["id"] ||
		p["budget_count"].(float64) != 2 || p["over_budget_count"].(float64) != 1 {
		t.Fatalf("budgets = %v (count %v, over %v)", bl, p["budget_count"], p["over_budget_count"])
	}
	up := p["upcoming"].([]any)
	if len(up) != 1 || up[0].(map[string]any)["title"] != "Water" || up[0].(map[string]any)["kind"] != "bill" ||
		up[0].(map[string]any)["date"] != today.AddDate(0, 0, 3).Format(day) || p["overdue_count"].(float64) != 0 {
		t.Fatalf("upcoming = %v", up)
	}
	gl := p["goals"].([]any)
	if len(gl) != 2 || gl[0].(map[string]any)["id"] != soon["id"] || p["goal_count"].(float64) != 2 {
		t.Fatalf("goals = %v", gl)
	}
	gb := p["group_balances"].([]any)
	if len(gb) != 1 || gb[0].(map[string]any)["group_id"] != gid || gfMap(gb[0].(map[string]any)["my_net"])["amount"] != "1500.00" ||
		p["group_count"].(float64) != 1 {
		t.Fatalf("group balances = %v", gb)
	}
	// The other member sees their own side, and none of the planner's records.
	pb := b.c.Do(t, http.MethodGet, "/dashboard/planning", nil).Expect(t, http.StatusOK).Data()
	if len(pb["budgets"].([]any)) != 0 || len(pb["goals"].([]any)) != 0 || len(pb["upcoming"].([]any)) != 0 ||
		gfMap(pb["group_balances"].([]any)[0].(map[string]any)["my_net"])["amount"] != "-1500.00" {
		t.Fatalf("other member's planning = %v", pb)
	}

	keys := map[string]bool{}
	for _, w := range a.c.Do(t, http.MethodGet, "/dashboard/widgets", nil).Expect(t, http.StatusOK).List() {
		keys[w.(map[string]any)["key"].(string)] = w.(map[string]any)["visible"] == true
	}
	for _, k := range []string{"budgets", "upcoming", "goals", "group_balances", "balances", "recent_transactions"} {
		if !keys[k] {
			t.Fatalf("widget %s missing or hidden: %v", k, keys)
		}
	}
}

// PATCH /me avatar_file_id: only your own finished avatar upload; "" clears.
func TestProfileAvatarOwnershipAndClear(t *testing.T) {
	s := apitest.New(t, nil)
	a := newPerson(t, s, "face", nil)
	b := newPerson(t, s, "other", nil)
	mine := uploadFile(t, a.c, "avatar", "me.png", "image/png", pngBytes(t))
	theirs := uploadFile(t, b.c, "avatar", "them.png", "image/png", append(pngBytes(t), 1))
	receipt := uploadFile(t, a.c, "receipt", "r.png", "image/png", append(pngBytes(t), 2))

	p := a.c.Do(t, http.MethodPatch, "/me", map[string]any{"avatar_file_id": mine}).Expect(t, http.StatusOK).Data()
	if p["avatar_file_id"] != mine {
		t.Fatalf("avatar = %v", p)
	}
	for _, id := range []string{theirs, receipt, uuid.NewString()} {
		r := a.c.Do(t, http.MethodPatch, "/me", map[string]any{"avatar_file_id": id})
		if r.Status != http.StatusUnprocessableEntity || detail(t, r)["code"] != "avatar_file_invalid" || detail(t, r)["field"] != "body.avatar_file_id" {
			t.Fatalf("avatar %s: %s", id, r.Raw)
		}
	}
	gfField(t, a.c.Do(t, http.MethodPatch, "/me", map[string]any{"avatar_file_id": "not-a-uuid"}), "body.avatar_file_id")
	if got := gfMap(a.c.Do(t, http.MethodGet, "/me", nil).Expect(t, http.StatusOK).Data()["profile"]); got["avatar_file_id"] != mine {
		t.Fatalf("a refused change replaced the avatar: %v", got["avatar_file_id"])
	}
	if p = a.c.Do(t, http.MethodPatch, "/me", map[string]any{"avatar_file_id": ""}).Expect(t, http.StatusOK).Data(); p["avatar_file_id"] != nil {
		t.Fatalf("cleared avatar = %v", p["avatar_file_id"])
	}
}

// Single reads (insight, report schedule), group_id on linked
// transactions, invitation share links and the newly coded errors.
func TestRound6ReadsLinksAndCodes(t *testing.T) {
	s := apitest.New(t, nil)
	a := newPerson(t, s, "reader", nil)
	b := newPerson(t, s, "stranger", nil)

	// GET /reports/schedules/{id}: own only.
	sch := a.c.Do(t, http.MethodPost, "/reports/schedules", map[string]any{"report_type": "monthly_summary", "format": "csv", "cadence": "monthly"}).
		Expect(t, http.StatusCreated).Data()
	if got := a.c.Do(t, http.MethodGet, "/reports/schedules/"+sch["id"].(string), nil).Expect(t, http.StatusOK).Data(); got["id"] != sch["id"] ||
		got["version"] != sch["version"] {
		t.Fatalf("schedule = %v", got)
	}
	b.c.Do(t, http.MethodGet, "/reports/schedules/"+sch["id"].(string), nil).Expect(t, http.StatusNotFound)

	// GET /insights/{id}: own only, any status.
	a.c.Do(t, http.MethodGet, "/insights/"+uuid.NewString(), nil).Expect(t, http.StatusNotFound)

	// group_id on a payer's linked transaction.
	acct := createAccount(t, a.c, map[string]any{"name": "Bank", "account_type": "bank", "currency": "INR", "opening_balance": "9000"})["id"].(string)
	gid := createGroup(t, a.c, map[string]any{"name": "Trip", "group_type": "trip", "base_currency": "INR", "timezone": "UTC"})["id"].(string)
	joinByLink(t, a, b, gid)
	e := gfExpense(t, a, gid, map[string]any{"description": "Taxi", "amount": "600", "split_method": "equal", "participants": gfPeople(a, b),
		"payer_account_id": acct})
	txID, _ := e["my_transaction_id"].(string)
	if txID == "" {
		t.Fatalf("no linked transaction: %v", e)
	}
	if tx := a.c.Do(t, http.MethodGet, "/transactions/"+txID, nil).Expect(t, http.StatusOK).Data(); tx["group_id"] != gid {
		t.Fatalf("transaction group_id = %v", tx["group_id"])
	}

	// Invitation links carry a share URL with the token in the fragment.
	inv := a.c.Do(t, http.MethodPost, "/groups/"+gid+"/invitations", map[string]any{"kind": "link"}).Expect(t, http.StatusCreated).Data()
	if u, _ := inv["share_url"].(string); !strings.HasSuffix(u, "/groups/join#token="+inv["token"].(string)) {
		t.Fatalf("group share_url = %v", inv["share_url"])
	}
	cid := createCommunity(t, a, map[string]any{"name": "Round Six Savers"})["id"].(string)
	cinv := a.c.Do(t, http.MethodPost, "/communities/"+cid+"/invitations", map[string]any{}).Expect(t, http.StatusCreated).Data()
	if u, _ := cinv["share_url"].(string); !strings.HasSuffix(u, "/communities/join#token="+cinv["token"].(string)) {
		t.Fatalf("community share_url = %v", cinv["share_url"])
	}
	if l := a.c.Do(t, http.MethodGet, "/communities/"+cid+"/invitations", nil).Expect(t, http.StatusOK).List(); l[0].(map[string]any)["share_url"] != nil {
		t.Fatalf("share_url shown again: %v", l)
	}

	// Coded errors.
	if r := a.c.Do(t, http.MethodPatch, "/me", map[string]any{"username": "x!"}); detail(t, r)["code"] != "username_invalid" {
		t.Fatalf("invalid username: %s", r.Raw)
	}
	if r := a.c.Do(t, http.MethodPatch, "/me", map[string]any{"username": "support"}); detail(t, r)["code"] != "username_reserved" {
		t.Fatalf("reserved username: %s", r.Raw)
	}
	if r := a.c.Do(t, http.MethodPatch, "/me", map[string]any{"username": b.user}); r.Status != http.StatusConflict || detail(t, r)["code"] != "username_taken" {
		t.Fatalf("taken username: %s", r.Raw)
	}
	if r := a.c.Do(t, http.MethodPatch, "/me", map[string]any{"display_name": "  "}); detail(t, r)["code"] != "required" {
		t.Fatalf("blank display name: %s", r.Raw)
	}
	// Interests are limited to 40 characters, not bytes (Hindi gets the same room).
	hindi40 := strings.Repeat("बचत", 13) + "क"
	if p := a.c.Do(t, http.MethodPatch, "/me", map[string]any{"interests": []string{hindi40, " "}}).Expect(t, http.StatusOK).Data(); len(p["interests"].([]any)) != 1 {
		t.Fatalf("interests = %v", p["interests"])
	}
	if r := a.c.Do(t, http.MethodPatch, "/me", map[string]any{"interests": []string{"ok", hindi40 + "क"}}); detail(t, r)["code"] != "too_long" ||
		detail(t, r)["field"] != "body.interests[1]" {
		t.Fatalf("long interest: %s", r.Raw)
	}
	if r := a.c.Do(t, http.MethodGet, "/users/search?q=ab", nil); detail(t, r)["code"] != "query_too_short" {
		t.Fatalf("short search: %s", r.Raw)
	}
	if r := a.c.Do(t, http.MethodPost, "/groups/"+gid+"/members", map[string]any{"username": b.user, "user_id": b.id}); detail(t, r)["code"] != "username_or_user_id" {
		t.Fatalf("both username and user_id: %s", r.Raw)
	}
	if r := a.c.Do(t, http.MethodPost, "/me/deletion-request", map[string]any{"confirm": "delete"}); detail(t, r)["code"] != "confirm_word_mismatch" {
		t.Fatalf("wrong confirm word: %s", r.Raw)
	}
	if r := a.c.Do(t, http.MethodDelete, "/me/deletion-request", nil); r.Status != http.StatusConflict || detail(t, r)["code"] != "no_deletion_scheduled" {
		t.Fatalf("cancelling nothing: %s", r.Raw)
	}

	// A member pausing a paused shared recurring expense: 422, like personal rules.
	rule := a.c.Do(t, http.MethodPost, "/groups/"+gid+"/recurring-expenses", map[string]any{"name": "Wifi", "frequency": "monthly",
		"start_date": utcToday().Format(day), "amount": "700", "participants": gfPeople(a, b)}, "Idempotency-Key", key()).
		Expect(t, http.StatusCreated).Data()
	rid := gfMap(rule["rule"])["id"].(string)
	a.c.Do(t, http.MethodPost, "/groups/"+gid+"/recurring-expenses/"+rid+"/pause", nil).Expect(t, http.StatusOK)
	p := gfCoded(t, a.c.Do(t, http.MethodPost, "/groups/"+gid+"/recurring-expenses/"+rid+"/pause", nil), http.StatusUnprocessableEntity,
		"DOMAIN_RULE_VIOLATION", "invalid_status_transition")
	if p["from"] != "paused" || p["to"] != "paused" {
		t.Fatalf("params = %v", p)
	}
	a.c.Do(t, http.MethodPost, "/groups/"+gid+"/recurring-expenses/"+rid+"/resume", nil).Expect(t, http.StatusOK)
}

// A group member who is not the owner of a members-visible group budget
// can list and open it (and their own budgets) with the same figures.
// Viewers never write snapshots: a refused write used to abort the
// transaction and answer 403 for the whole list.
func TestGroupBudgetVisibleToViewerMember(t *testing.T) {
	s := apitest.New(t, nil)
	a := newPerson(t, s, "hhowner", nil)
	b := newPerson(t, s, "hhmember", nil)
	gid := createGroup(t, a.c, map[string]any{"name": "Home", "group_type": "household", "base_currency": "INR", "timezone": "UTC"})["id"].(string)
	joinByLink(t, a, b, gid)
	gfExpense(t, a, gid, map[string]any{"description": "Groceries", "amount": "2000.50", "split_method": "equal", "participants": gfPeople(a, b)})
	own := b.c.Do(t, http.MethodPost, "/budgets", map[string]any{"name": "Mine", "budget_type": "total", "period": "monthly",
		"currency": "INR", "limit": "900"}).Expect(t, http.StatusCreated).Data()
	shared := a.c.Do(t, http.MethodPost, "/budgets", map[string]any{"name": "Household", "budget_type": "total", "period": "monthly",
		"currency": "INR", "limit": "5000", "group_id": gid, "visibility": "members"}).Expect(t, http.StatusCreated).Data()
	ownerView := a.c.Do(t, http.MethodGet, "/budgets/"+shared["id"].(string), nil).Expect(t, http.StatusOK).Data()

	for i := 0; i < 2; i++ { // twice: the second read must not depend on a cache the member wrote
		ids := map[string]map[string]any{}
		for _, x := range b.c.Do(t, http.MethodGet, "/budgets", nil).Expect(t, http.StatusOK).List() {
			ids[x.(map[string]any)["id"].(string)] = x.(map[string]any)
		}
		if ids[own["id"].(string)] == nil || ids[shared["id"].(string)] == nil {
			t.Fatalf("member's budget list = %v", ids)
		}
		got := b.c.Do(t, http.MethodGet, "/budgets/"+shared["id"].(string), nil).Expect(t, http.StatusOK).Data()
		if gfMap(gfMap(got["progress"])["spent"])["amount"] != gfMap(gfMap(ownerView["progress"])["spent"])["amount"] || got["access"] != "viewer" {
			t.Fatalf("member's view = %v, owner's = %v", got["progress"], ownerView["progress"])
		}
	}
	b.c.Do(t, http.MethodGet, "/dashboard/planning", nil).Expect(t, http.StatusOK)
}

// A username invitation to a community: the invitee is notified once and
// sees who invited them, even when the inviter is not discoverable.
func TestCommunityInvitationNoticeAndInviterName(t *testing.T) {
	s := apitest.New(t, nil)
	o := newPerson(t, s, "host", map[string]any{"display_name": "Asha Host"})
	inv := newPerson(t, s, "guest", nil)
	o.c.Do(t, http.MethodPatch, "/me", map[string]any{"discoverable_by_username": false}).Expect(t, http.StatusOK)
	cid := createCommunity(t, o, map[string]any{"name": "Invite Notice " + uuid.NewString()[:8], "visibility": "invite_only"})["id"].(string)
	o.c.Do(t, http.MethodPost, "/communities/"+cid+"/invitations", map[string]any{"username": inv.user}).Expect(t, http.StatusCreated)
	s.RunJobs(t)
	s.RunJobs(t)
	if n := notificationsOf(t, inv.c, "community", "community_invitation"); n != 1 {
		t.Fatalf("invitation notices = %d", n)
	}
	l := inv.c.Do(t, http.MethodGet, "/community-invitations", nil).Expect(t, http.StatusOK).List()
	if len(l) != 1 {
		t.Fatalf("my invitations = %v", l)
	}
	by := gfMap(l[0].(map[string]any)["invited_by"])
	// The real name and username, not the "Montra user" fallback shown to
	// people who may not see a profile.
	if by["user_id"] != o.id || by["display_name"] != "Asha Host" || by["username"] != o.user {
		t.Fatalf("inviter as the invitee sees them = %v", by)
	}
	// Once declined, the inviter's profile is private again.
	inv.c.Do(t, http.MethodPost, "/community-invitations/"+l[0].(map[string]any)["id"].(string)+"/decline", nil).Expect(t, http.StatusOK)
	if r := inv.c.Do(t, http.MethodGet, "/users/"+o.id, nil); r.Status == http.StatusOK && r.Data()["display_name"] != nil {
		t.Fatalf("inviter still visible after declining: %s", r.Raw)
	}
}

// GET /insights/{id}: your own insight in any status; anyone else's is 404.
func TestInsightSingleReadOwnAnyStatus(t *testing.T) {
	s := apitest.New(t, nil)
	c, _ := s.Login(t, s.Register(t, "oneinsight"))
	other, _ := s.Login(t, s.Register(t, "notmine"))
	today := todayIn(t, "Asia/Kolkata")
	acct := createAccount(t, c, map[string]any{"name": "Bank", "account_type": "bank", "currency": "INR", "opening_balance": "90000"})["id"].(string)
	groceries := categoryID(t, c, "Groceries")
	for i := 1; i <= 9; i++ {
		createTx(t, c, map[string]any{"type": "expense", "account_id": acct, "amount": "120.00", "merchant_name": "Corner Store", "category_id": groceries,
			"local_date": today.AddDate(0, 0, -i*15).Format(day)})
	}
	createTx(t, c, map[string]any{"type": "expense", "account_id": acct, "amount": "5200.00", "merchant_name": "FreshMart", "category_id": groceries})
	gen := c.Do(t, http.MethodPost, "/ai/insights/generate", nil).Expect(t, http.StatusOK).Data()["insights"].([]any)
	if len(gen) == 0 {
		t.Fatal("no insight generated")
	}
	id := gen[0].(map[string]any)["id"].(string)
	if got := c.Do(t, http.MethodGet, "/insights/"+id, nil).Expect(t, http.StatusOK).Data(); got["id"] != id || got["status"] != "active" {
		t.Fatalf("own insight = %v", got)
	}
	other.Do(t, http.MethodGet, "/insights/"+id, nil).Expect(t, http.StatusNotFound)
	// Dismissed insights leave the default list but still open by ID.
	c.Do(t, http.MethodPost, "/insights/"+id+"/actions", map[string]any{"action": "dismiss"}).Expect(t, http.StatusOK)
	if got := c.Do(t, http.MethodGet, "/insights/"+id, nil).Expect(t, http.StatusOK).Data(); got["status"] != "dismissed" {
		t.Fatalf("dismissed insight = %v", got)
	}
}

// GET /dashboard/planning alerts, renewals and recurring cards, and the
// widget layout: hide, reorder and reset persist per user only.
func TestDashboardAlertsRenewalsRecurringAndLayout(t *testing.T) {
	s := apitest.New(t, nil)
	a := newPerson(t, s, "cards", nil)
	b := newPerson(t, s, "layoutother", nil)
	today := utcToday()
	a.c.Do(t, http.MethodPatch, "/me/preferences", map[string]any{"timezone": "UTC"}).Expect(t, http.StatusOK)
	acct := createAccount(t, a.c, map[string]any{"name": "Bank", "account_type": "bank", "currency": "INR", "opening_balance": "50000"})["id"].(string)
	bud := a.c.Do(t, http.MethodPost, "/budgets", map[string]any{"name": "Tight", "budget_type": "total", "period": "monthly",
		"currency": "INR", "limit": "1000", "alert_forecast": false}).Expect(t, http.StatusCreated).Data()
	createTx(t, a.c, map[string]any{"type": "expense", "account_id": acct, "amount": "1500"})
	a.c.Do(t, http.MethodPost, "/subscriptions", map[string]any{"name": "StreamFlix", "amount": "649", "billing_frequency": "monthly",
		"start_date": today.AddDate(0, 0, 10).Format(day), "payment_account_id": acct}, "Idempotency-Key", key()).Expect(t, http.StatusCreated)
	a.c.Do(t, http.MethodPost, "/subscriptions", map[string]any{"name": "Far renewal", "amount": "100", "billing_frequency": "monthly",
		"start_date": today.AddDate(0, 0, 45).Format(day), "payment_account_id": acct}, "Idempotency-Key", key()).Expect(t, http.StatusCreated)
	a.c.Do(t, http.MethodPost, "/bills", map[string]any{"name": "Water", "provider_name": "City Water", "expected_amount": "400",
		"frequency": "monthly", "start_date": today.AddDate(0, 0, 3).Format(day), "timezone": "UTC"}, "Idempotency-Key", key()).Expect(t, http.StatusCreated)
	s.RunJobs(t)

	p := a.c.Do(t, http.MethodGet, "/dashboard/planning", nil).Expect(t, http.StatusOK).Data()
	al := p["alerts"].([]any)
	if len(al) == 0 || al[0].(map[string]any)["budget_id"] != bud["id"] || al[0].(map[string]any)["status"] != "active" ||
		p["alert_count"].(float64) != float64(len(al)) {
		t.Fatalf("alerts = %v (count %v)", al, p["alert_count"])
	}
	if p["renewals_through"] != today.AddDate(0, 0, 30).Format(day) {
		t.Fatalf("renewals_through = %v", p["renewals_through"])
	}
	rn := p["renewals"].([]any)
	if len(rn) != 1 || rn[0].(map[string]any)["title"] != "StreamFlix" || rn[0].(map[string]any)["kind"] != "subscription_renewal" ||
		p["renewal_count"].(float64) != 1 {
		t.Fatalf("renewals = %v", rn)
	}
	var bill map[string]any
	for _, x := range p["recurring"].([]any) {
		if x.(map[string]any)["kind"] == "bill" {
			bill = x.(map[string]any)
		}
	}
	if bill == nil || gfMap(bill["monthly_equivalent"])["amount"] != "400.00" || p["recurring_note_code"] != "fixed_amounts_expectations" {
		t.Fatalf("recurring = %v", p["recurring"])
	}
	if pb := b.c.Do(t, http.MethodGet, "/dashboard/planning", nil).Expect(t, http.StatusOK).Data(); len(pb["alerts"].([]any)) != 0 ||
		len(pb["renewals"].([]any)) != 0 || len(pb["recurring"].([]any)) != 0 {
		t.Fatalf("another user's planning = %v", pb)
	}

	// Layout: hide recurring, move goals first; persisted for this user only.
	layout := func(c *apitest.Client) []map[string]any {
		var out []map[string]any
		for _, w := range c.Do(t, http.MethodGet, "/dashboard/widgets", nil).Expect(t, http.StatusOK).List() {
			out = append(out, w.(map[string]any))
		}
		return out
	}
	def := layout(a.c)
	if len(def) != 15 || def[0]["key"] != "balances" || def[2]["key"] != "alerts" {
		t.Fatalf("default layout = %v", def)
	}
	var patch []any
	for i, w := range def {
		pos := i + 1
		if w["key"] == "goals" {
			pos = 0
		}
		patch = append(patch, map[string]any{"key": w["key"], "position": pos, "visible": w["key"] != "recurring"})
	}
	a.c.Do(t, http.MethodPatch, "/dashboard/widgets", map[string]any{"widgets": patch}).Expect(t, http.StatusOK)
	got := layout(a.c)
	if got[0]["key"] != "goals" {
		t.Fatalf("reordered layout = %v", got)
	}
	for _, w := range got {
		if (w["key"] == "recurring") == (w["visible"] == true) {
			t.Fatalf("visibility of %s = %v", w["key"], w["visible"])
		}
	}
	if other := layout(b.c); other[0]["key"] != "balances" {
		t.Fatalf("another user's layout changed: %v", other)
	}
	a.c.Do(t, http.MethodPatch, "/dashboard/widgets", map[string]any{"reset": true}).Expect(t, http.StatusOK)
	reset := layout(a.c)
	for i, w := range reset {
		if w["key"] != def[i]["key"] || w["visible"] != true {
			t.Fatalf("reset layout = %v", reset)
		}
	}
}

// A receipt made of several files keeps their page order, a PDF can be a
// page, a page belongs to one receipt only, and the dashboard summary says
// when it was computed.
func TestMultiPageReceiptAndSummaryTimestamp(t *testing.T) {
	s := apitest.New(t, nil)
	c, _ := s.Login(t, s.Register(t, "pages"))
	p1 := uploadFile(t, c, "receipt", "p1.png", "image/png", pngBytes(t))
	p2 := uploadFile(t, c, "receipt", "p2.pdf", "application/pdf", []byte("%PDF-1.4\n1 0 obj<</Type/Catalog>>endobj\ntrailer<</Root 1 0 R>>\n%%EOF\n"))
	p3 := uploadFile(t, c, "receipt", "p3.png", "image/png", append(pngBytes(t), 7))
	rc := c.Do(t, http.MethodPost, "/receipts", map[string]any{"file_ids": []string{p3, p1, p2}}, "Idempotency-Key", key()).
		Expect(t, http.StatusCreated).Data()
	fl := rc["files"].([]any)
	if len(fl) != 3 {
		t.Fatalf("files = %v", fl)
	}
	for i, want := range []string{p3, p1, p2} {
		if got := fl[i].(map[string]any)["file_id"]; got != want {
			t.Fatalf("page %d = %v, want %s (%v)", i, got, want, fl)
		}
	}
	if r := c.Do(t, http.MethodPost, "/receipts", map[string]any{"file_ids": []string{p1}}, "Idempotency-Key", key()); r.Status != http.StatusConflict ||
		detail(t, r)["code"] != "file_in_use" {
		t.Fatalf("a page reused in a second receipt: %d %s", r.Status, r.Raw)
	}

	before := time.Now().Add(-time.Minute)
	sum := c.Do(t, http.MethodGet, "/dashboard/summary", nil).Expect(t, http.StatusOK).Data()
	at, err := time.Parse(time.RFC3339Nano, fmt.Sprint(sum["generated_at"]))
	if err != nil || at.Before(before) || at.After(time.Now().Add(time.Minute)) {
		t.Fatalf("generated_at = %v (%v)", sum["generated_at"], err)
	}
}

// Weekly analytics buckets start on the user's week start; subscriptions
// count as recurring commitments; a trial's first charge on its end date is
// one calendar item.
func TestWeekStartBucketsSubscriptionsAndTrialEnd(t *testing.T) {
	s := apitest.New(t, nil)
	c, _ := s.Login(t, s.Register(t, "weeks"))
	acct := createAccount(t, c, map[string]any{"name": "Bank", "account_type": "bank", "currency": "INR", "opening_balance": "9000"})["id"].(string)
	createTx(t, c, map[string]any{"type": "expense", "account_id": acct, "amount": "10", "local_date": "2026-10-07"}) // a Wednesday
	weeks := func() []string {
		r := c.Do(t, http.MethodGet, "/analytics/cash-flow?from=2026-10-01&to=2026-10-31&granularity=week", nil).Expect(t, http.StatusOK).Data()
		var out []string
		for _, p := range r["series"].([]any) {
			out = append(out, p.(map[string]any)["bucket"].(string))
		}
		return out
	}
	for _, tc := range []struct {
		ws    int
		first string
		day   time.Weekday
	}{{1, "2026-09-28", time.Monday}, {0, "2026-09-27", time.Sunday}, {6, "2026-09-26", time.Saturday}} {
		c.Do(t, http.MethodPatch, "/me/preferences", map[string]any{"week_start": tc.ws}).Expect(t, http.StatusOK)
		w := weeks()
		if len(w) == 0 || w[0] != tc.first {
			t.Fatalf("week_start %d: buckets = %v", tc.ws, w)
		}
		for _, b := range w {
			if d, _ := time.Parse(day, b); d.Weekday() != tc.day {
				t.Fatalf("week_start %d: bucket %s is a %s", tc.ws, b, d.Weekday())
			}
		}
	}

	today := utcToday()
	c.Do(t, http.MethodPatch, "/me/preferences", map[string]any{"timezone": "UTC"}).Expect(t, http.StatusOK)
	c.Do(t, http.MethodPost, "/subscriptions", map[string]any{"name": "Yearly", "amount": "1200", "billing_frequency": "yearly",
		"start_date": today.AddDate(0, 0, 40).Format(day), "payment_account_id": acct}, "Idempotency-Key", key()).Expect(t, http.StatusCreated)
	trial := c.Do(t, http.MethodPost, "/subscriptions", map[string]any{"name": "Trialist", "amount": "300", "billing_frequency": "monthly",
		"start_date": today.AddDate(0, 0, 5).Format(day), "trial_ends_on": today.AddDate(0, 0, 5).Format(day), "payment_account_id": acct},
		"Idempotency-Key", key()).Expect(t, http.StatusCreated).Data()
	var sub map[string]any
	for _, x := range c.Do(t, http.MethodGet, "/analytics/recurring", nil).Expect(t, http.StatusOK).Data()["commitments"].([]any) {
		if x.(map[string]any)["kind"] == "subscription" {
			sub = x.(map[string]any)
		}
	}
	if sub == nil || gfMap(sub["monthly_equivalent"])["amount"] != "100.00" {
		t.Fatalf("subscription commitment (yearly 1200 = 100/month; trials not yet counted) = %v", sub)
	}
	var items []map[string]any
	for _, x := range c.Do(t, http.MethodGet, "/calendar", nil).Expect(t, http.StatusOK).List() {
		if m := x.(map[string]any); m["entity_id"] == trial["id"] && m["date"] == today.AddDate(0, 0, 5).Format(day) {
			items = append(items, m)
		}
	}
	if trial["status"] != "trial" || len(items) != 1 || items[0]["kind"] != "trial_end" || gfMap(items[0]["amount"])["amount"] != "300.00" {
		t.Fatalf("trial %v: items on its end date = %v", trial["status"], items)
	}
}

// A goal marked achieved by hand stays achieved after a withdrawal takes it
// below target; a goal achieved by reaching its target reopens.
func TestGoalAchievedByHandStaysAchieved(t *testing.T) {
	s := apitest.New(t, nil)
	c, _ := s.Login(t, s.Register(t, "goalstate"))
	contribute := func(gid, kind, amount string) {
		c.Do(t, http.MethodPost, "/goals/"+gid+"/contributions", map[string]any{"kind": kind, "amount": amount},
			"Idempotency-Key", key()).Expect(t, http.StatusCreated)
	}
	status := func(gid string) any {
		return c.Do(t, http.MethodGet, "/goals/"+gid, nil).Expect(t, http.StatusOK).Data()["status"]
	}
	manual := c.Do(t, http.MethodPost, "/goals", map[string]any{"name": "Close enough", "goal_type": "custom", "target_amount": "1000"},
		"Idempotency-Key", key()).Expect(t, http.StatusCreated).Data()["id"].(string)
	contribute(manual, "contribution", "800")
	c.Do(t, http.MethodPost, "/goals/"+manual+"/achieve", nil).Expect(t, http.StatusOK)
	contribute(manual, "withdrawal", "100")
	if st := status(manual); st != "achieved" {
		t.Fatalf("hand-achieved goal after a withdrawal = %v", st)
	}

	auto := c.Do(t, http.MethodPost, "/goals", map[string]any{"name": "Reached", "goal_type": "custom", "target_amount": "500"},
		"Idempotency-Key", key()).Expect(t, http.StatusCreated).Data()["id"].(string)
	contribute(auto, "contribution", "500")
	if st := status(auto); st != "achieved" {
		t.Fatalf("goal at its target = %v", st)
	}
	contribute(auto, "withdrawal", "50")
	if st := status(auto); st != "active" {
		t.Fatalf("target-reached goal below target again = %v", st)
	}
}
