package api_test

import (
	"net/http"
	"strconv"
	"strings"
	"testing"
	"time"

	"montra/backend/internal/testutil/apitest"
)

// Community fixes reported by the web client: can_moderate, partial PATCH
// with version, field detail codes, hidden comments for moderators, reaction
// state, feed cursors, and invitation preview / decline / list / revoke.
func TestCommunityPatchCodesFeedAndInvitationFixes(t *testing.T) {
	s := apitest.New(t, nil)
	o := newPerson(t, s, "owner", nil)
	mod := newPerson(t, s, "mod", nil)
	m := newPerson(t, s, "member", nil)
	reader := newPerson(t, s, "reader", nil)
	inv := newPerson(t, s, "invitee", nil)
	w := newPerson(t, s, "writer", nil)
	staff := newPerson(t, s, "staff", nil)
	s.Env.ExecWorker(t, `update users set platform_role = 'support' where id = $1`, staff.id)
	seasoned(t, s, o)
	seasoned(t, s, m)
	seasoned(t, s, w)

	c := createCommunity(t, o, map[string]any{"name": "Saving Circle", "description": "Tips", "topics": []string{"saving"}})
	cid := c["id"].(string)
	if c["version"].(float64) != 1 || c["can_moderate"] != true {
		t.Fatalf("community = %v", c)
	}
	for _, p := range []person{mod, m, reader, w} {
		p.c.Do(t, http.MethodPost, "/communities/"+cid+"/join", nil).Expect(t, http.StatusOK)
	}
	o.c.Do(t, http.MethodPatch, "/communities/"+cid+"/members/"+mod.id, map[string]any{"role": "moderator"}).Expect(t, http.StatusOK)

	// CO5: staff moderate everywhere without a membership role.
	if got := staff.c.Do(t, http.MethodGet, "/communities/"+cid, nil).Expect(t, http.StatusOK).Data(); got["my_role"] != "none" || got["can_moderate"] != true {
		t.Fatalf("staff view = %v", got)
	}
	if got := m.c.Do(t, http.MethodGet, "/communities/"+cid, nil).Expect(t, http.StatusOK).Data(); got["can_moderate"] != false || got["my_role"] != "member" {
		t.Fatalf("member view = %v", got)
	}

	// CO4: PATCH changes only what is sent and needs the current version.
	up := o.c.Do(t, http.MethodPatch, "/communities/"+cid, map[string]any{"rules": "Be kind", "version": 1}).Expect(t, http.StatusOK).Data()
	if up["rules"] != "Be kind" || up["description"] != "Tips" || len(up["topics"].([]any)) != 1 || up["version"].(float64) != 2 {
		t.Fatalf("patched = %v", up)
	}
	if r := mod.c.Do(t, http.MethodPatch, "/communities/"+cid, map[string]any{"description": "Stale", "version": 1}); r.ErrorCode() != "VERSION_CONFLICT" {
		t.Fatalf("stale version: %s", r.Raw)
	}
	if r := mod.c.Do(t, http.MethodPatch, "/communities/"+cid, map[string]any{"visibility": "private", "version": 2}); r.Status != http.StatusForbidden {
		t.Fatalf("moderator changing visibility: %d", r.Status)
	}
	cleared := mod.c.Do(t, http.MethodPatch, "/communities/"+cid, map[string]any{"description": "", "version": 2}).Expect(t, http.StatusOK).Data()
	if cleared["description"] != nil || cleared["rules"] != "Be kind" || cleared["version"].(float64) != 3 {
		t.Fatalf("cleared = %v", cleared)
	}
	if r := m.c.Do(t, http.MethodPatch, "/communities/"+cid, map[string]any{"name": "Mine now", "version": 3}); r.Status != http.StatusForbidden {
		t.Fatalf("member editing: %d", r.Status)
	}
	if r := o.c.Do(t, http.MethodPatch, "/communities/"+cid, map[string]any{"name": "Renamed"}); r.ErrorCode() != "VALIDATION_ERROR" {
		t.Fatalf("patch without version: %s", r.Raw)
	}

	// CO7: field problems carry stable codes; the English message stays.
	codeOf := func(r *apitest.Response, field, code string) map[string]any {
		t.Helper()
		d := detail(t, r)
		if r.ErrorCode() != "VALIDATION_ERROR" || d["field"] != field || d["code"] != code || d["message"] == "" {
			t.Fatalf("want %s %s, got %d %s", field, code, r.Status, r.Raw)
		}
		p, _ := d["params"].(map[string]any)
		return p
	}
	if p := codeOf(o.c.Do(t, http.MethodPatch, "/communities/"+cid, map[string]any{"name": "ab", "version": 3}), "body.name", "too_short"); p["min"] != "3" {
		t.Fatalf("schema too_short params = %v", p)
	}
	if p := codeOf(w.c.Do(t, http.MethodPost, "/communities/"+cid+"/posts", map[string]any{"title": "ab\u200b\u200b"}), "body.title", "too_short"); p["min"] != "3" {
		t.Fatalf("textsafe too_short params = %v", p)
	}
	codeOf(w.c.Do(t, http.MethodPost, "/communities/"+cid+"/posts", map[string]any{"title": "Help", "body": "My card is 4111 1111 1111 1111"}), "body.body", "contains_secret")
	codeOf(w.c.Do(t, http.MethodPost, "/communities/"+cid+"/posts", map[string]any{"title": "Bad link", "kind": "resource", "link_url": "http://insecure.example"}),
		"body.link_url", "insecure_link")
	if p := codeOf(w.c.Do(t, http.MethodPost, "/communities/"+cid+"/posts", map[string]any{"title": "Linkfest",
		"body": "https://a.com https://b.com https://c.com https://d.com"}), "body.body", "too_many_links"); p["max"] != "3" {
		t.Fatalf("too_many_links params = %v", p)
	}
	codeOf(m.c.Do(t, http.MethodPost, "/communities/"+cid+"/posts", map[string]any{"title": "Official", "label": "verified_guidance"}), "body.label", "moderators_only")
	codeOf(w.c.Do(t, http.MethodPost, "/communities/"+cid+"/posts", map[string]any{"title": "Link", "kind": "resource"}), "body.link_url", "link_required")

	// CO3: moderators and staff read hidden comments; other members never see them.
	p := post(t, m, cid, map[string]any{"title": "Grocery haul", "body": "Saved by planning"})
	pid := p["id"].(string)
	cm := m.c.Do(t, http.MethodPost, "/posts/"+pid+"/comments", map[string]any{"body": "Secret recipe"}).Expect(t, http.StatusCreated).Data()
	mod.c.Do(t, http.MethodPost, "/communities/"+cid+"/moderation/actions", map[string]any{"action": "hide", "target_type": "comment", "target_id": cm["id"],
		"reason": "Off topic"}).Expect(t, http.StatusOK)
	firstComment := func(p person) map[string]any {
		t.Helper()
		l := p.c.Do(t, http.MethodGet, "/posts/"+pid, nil).Expect(t, http.StatusOK).Data()["comments"].([]any)
		if len(l) == 0 {
			return nil
		}
		return l[0].(map[string]any)
	}
	for who, p := range map[string]person{"moderator": mod, "staff": staff, "author": m} {
		if x := firstComment(p); x == nil || x["status"] != "hidden" || x["body"] != "Secret recipe" {
			t.Fatalf("%s's view of the hidden comment = %v", who, x)
		}
	}
	if x := firstComment(reader); x != nil {
		t.Fatalf("member sees a hidden comment: %v", x)
	}

	// CO8: reactions answer the caller's own reactions; the feed pages with cursors.
	rc := reader.c.Do(t, http.MethodPost, "/posts/"+pid+"/reactions", map[string]any{"kind": "helpful"}).Expect(t, http.StatusOK).Data()
	if rc["helpful"].(float64) != 1 || len(rc["my_reactions"].([]any)) != 1 || rc["my_reactions"].([]any)[0] != "helpful" {
		t.Fatalf("reaction = %v", rc)
	}
	if rc = reader.c.Do(t, http.MethodDelete, "/posts/"+pid+"/reactions/helpful", nil).Expect(t, http.StatusOK).Data(); rc["helpful"].(float64) != 0 || len(rc["my_reactions"].([]any)) != 0 {
		t.Fatalf("after removing = %v", rc)
	}
	post(t, w, cid, map[string]any{"title": "Second"})
	post(t, w, cid, map[string]any{"title": "Third"})
	meta := func(r *apitest.Response) (string, bool) {
		mt, _ := r.Body["meta"].(map[string]any)
		cur, _ := mt["next_cursor"].(string)
		more, _ := mt["has_more"].(bool)
		return cur, more
	}
	for _, sort := range []string{"new", "top", "active"} {
		p1 := reader.c.Do(t, http.MethodGet, "/communities/"+cid+"/posts?sort="+sort+"&limit=2", nil).Expect(t, http.StatusOK)
		cur, more := meta(p1)
		if len(p1.List()) != 2 || !more || cur == "" {
			t.Fatalf("%s page 1 = %v %v", sort, p1.List(), p1.Body["meta"])
		}
		p2 := reader.c.Do(t, http.MethodGet, "/communities/"+cid+"/posts?sort="+sort+"&limit=2&cursor="+cur, nil).Expect(t, http.StatusOK)
		if _, more := meta(p2); len(p2.List()) != 1 || more {
			t.Fatalf("%s page 2 = %v %v", sort, p2.List(), p2.Body["meta"])
		}
		seen := map[string]bool{}
		for _, x := range append(p1.List(), p2.List()...) {
			seen[x.(map[string]any)["id"].(string)] = true
		}
		if len(seen) != 3 {
			t.Fatalf("%s pages overlap or miss posts: %v", sort, seen)
		}
		if r := reader.c.Do(t, http.MethodGet, "/communities/"+cid+"/posts?sort="+map[string]string{"new": "top", "top": "active", "active": "new"}[sort]+"&cursor="+cur, nil); r.ErrorCode() != "VALIDATION_ERROR" {
			t.Fatalf("cursor reused with another sort: %s", r.Raw)
		}
	}
	if _, more := meta(reader.c.Do(t, http.MethodGet, "/communities/"+cid+"/posts", nil).Expect(t, http.StatusOK)); more {
		t.Fatal("has_more on the only page")
	}

	// CO1 / CO2: invitation preview, decline, list and revoke.
	icid := createCommunity(t, o, map[string]any{"name": "Invite Vault", "visibility": "invite_only"})["id"].(string)
	link := o.c.Do(t, http.MethodPost, "/communities/"+icid+"/invitations", map[string]any{}).Expect(t, http.StatusCreated).Data()
	if link["kind"] != "link" || link["status"] != "active" || link["token"] == nil {
		t.Fatalf("link = %v", link)
	}
	pv := inv.c.Do(t, http.MethodPost, "/community-invitations/preview", map[string]any{"token": link["token"]}).Expect(t, http.StatusOK).Data()
	if pv["community_name"] != "Invite Vault" || pv["slug"] != "invite-vault" || pv["member_count"].(float64) != 1 || pv["status"] != "active" ||
		pv["already_member"] != false || pv["requires_approval"] != false || pv["invited_by"].(map[string]any)["display_name"] != "Test owner" {
		t.Fatalf("preview = %v", pv)
	}
	if r := inv.c.Do(t, http.MethodGet, "/communities/"+icid, nil); r.Status != http.StatusNotFound {
		t.Fatalf("preview must not open the community: %d", r.Status)
	}
	if r := inv.c.Do(t, http.MethodPost, "/community-invitations/preview", map[string]any{"token": "not-a-real-token-at-all"}); r.Status != http.StatusGone {
		t.Fatalf("unknown token: %d", r.Status)
	}
	uinv := o.c.Do(t, http.MethodPost, "/communities/"+icid+"/invitations", map[string]any{"username": inv.user}).Expect(t, http.StatusCreated).Data()
	if uinv["kind"] != "username" || uinv["invitee"].(map[string]any)["user_id"] != inv.id || uinv["invited_by"].(map[string]any)["user_id"] != o.id {
		t.Fatalf("username invitation = %v", uinv)
	}
	if l := o.c.Do(t, http.MethodGet, "/communities/"+icid+"/invitations", nil).Expect(t, http.StatusOK).List(); len(l) != 2 || l[0].(map[string]any)["token"] != nil {
		t.Fatalf("invitations = %v", l)
	}
	if r := m.c.Do(t, http.MethodGet, "/communities/"+icid+"/invitations", nil); r.Status != http.StatusNotFound {
		t.Fatalf("outsider listing invitations: %d", r.Status)
	}
	inv.c.Do(t, http.MethodPost, "/community-invitations/"+uinv["id"].(string)+"/decline", nil).Expect(t, http.StatusOK)
	if r := inv.c.Do(t, http.MethodPost, "/community-invitations/"+uinv["id"].(string)+"/decline", nil); r.Status != http.StatusConflict || detail(t, r)["code"] != "invitation_used" {
		t.Fatalf("declining twice: %s", r.Raw)
	}
	if r := inv.c.Do(t, http.MethodPost, "/community-invitations/"+uinv["id"].(string)+"/accept", nil); r.Status != http.StatusGone {
		t.Fatalf("accepting a declined invitation: %d", r.Status)
	}
	if l := inv.c.Do(t, http.MethodGet, "/community-invitations", nil).Expect(t, http.StatusOK).List(); len(l) != 0 {
		t.Fatalf("declined invitation still listed: %v", l)
	}
	all := o.c.Do(t, http.MethodGet, "/communities/"+icid+"/invitations?include_inactive=true", nil).Expect(t, http.StatusOK).List()
	statuses := map[string]string{}
	for _, x := range all {
		statuses[x.(map[string]any)["id"].(string)] = x.(map[string]any)["status"].(string)
	}
	if statuses[uinv["id"].(string)] != "declined" || statuses[link["id"].(string)] != "active" {
		t.Fatalf("statuses = %v", statuses)
	}
	if l := o.c.Do(t, http.MethodGet, "/communities/"+icid+"/invitations", nil).Expect(t, http.StatusOK).List(); len(l) != 1 {
		t.Fatalf("active invitations = %v", l)
	}
	if r := m.c.Do(t, http.MethodDelete, "/communities/"+icid+"/invitations/"+link["id"].(string), nil); r.Status != http.StatusNotFound {
		t.Fatalf("outsider revoking: %d", r.Status)
	}
	o.c.Do(t, http.MethodDelete, "/communities/"+icid+"/invitations/"+link["id"].(string), nil).Expect(t, http.StatusOK)
	if r := o.c.Do(t, http.MethodDelete, "/communities/"+icid+"/invitations/"+link["id"].(string), nil); r.Status != http.StatusConflict || detail(t, r)["code"] != "invitation_inactive" {
		t.Fatalf("revoking twice: %s", r.Raw)
	}
	if pv = inv.c.Do(t, http.MethodPost, "/community-invitations/preview", map[string]any{"token": link["token"]}).Expect(t, http.StatusOK).Data(); pv["status"] != "revoked" {
		t.Fatalf("revoked preview = %v", pv)
	}
	if r := inv.c.Do(t, http.MethodPost, "/community-invitations/accept", map[string]any{"token": link["token"]}); r.Status != http.StatusGone {
		t.Fatalf("accepting a revoked link: %d", r.Status)
	}
	link2 := o.c.Do(t, http.MethodPost, "/communities/"+icid+"/invitations", map[string]any{}).Expect(t, http.StatusCreated).Data()
	inv.c.Do(t, http.MethodPost, "/community-invitations/accept", map[string]any{"token": link2["token"]}).Expect(t, http.StatusOK)
	if r := o.c.Do(t, http.MethodPost, "/communities/"+icid+"/invitations", map[string]any{"username": inv.user}); r.Status != http.StatusConflict || detail(t, r)["code"] != "already_member" {
		t.Fatalf("inviting a member: %s", r.Raw)
	}
	if pv = inv.c.Do(t, http.MethodPost, "/community-invitations/preview", map[string]any{"token": link2["token"]}).Expect(t, http.StatusOK).Data(); pv["status"] != "used" || pv["already_member"] != true {
		t.Fatalf("used preview = %v", pv)
	}
	// A member reopening a spent link hears "already a member", not "gone".
	if r := inv.c.Do(t, http.MethodPost, "/community-invitations/accept", map[string]any{"token": link2["token"]}); r.Status != http.StatusConflict ||
		detail(t, r)["code"] != "already_member" {
		t.Fatalf("reusing a link as a member: %s", r.Raw)
	}
}

// Moderation fixes: reported-author fields for moderators, appeal_until,
// appeals embedding their action and shown to the appellant (with the
// outcome notice), the staff action list, and group report dismissal.
func TestModerationAppealsStaffActionsAndGroupReports(t *testing.T) {
	s := apitest.New(t, nil)
	o := newPerson(t, s, "owner", nil)
	mod := newPerson(t, s, "mod", nil)
	a := newPerson(t, s, "author", nil)
	rep := newPerson(t, s, "reporter", nil)
	staff := newPerson(t, s, "staff", nil)
	s.Env.ExecWorker(t, `update users set platform_role = 'support' where id = $1`, staff.id)
	cid := createCommunity(t, o, map[string]any{"name": "Careful Spenders"})["id"].(string)
	for _, p := range []person{mod, a, rep} {
		p.c.Do(t, http.MethodPost, "/communities/"+cid+"/join", nil).Expect(t, http.StatusOK)
	}
	o.c.Do(t, http.MethodPatch, "/communities/"+cid+"/members/"+mod.id, map[string]any{"role": "moderator"}).Expect(t, http.StatusOK)
	sid := post(t, a, cid, map[string]any{"title": "Buy my course"})["id"].(string)
	cm := a.c.Do(t, http.MethodPost, "/posts/"+sid+"/comments", map[string]any{"body": "Also message me"}).Expect(t, http.StatusCreated).Data()
	cmid := cm["id"].(string)

	// M6: moderators learn the post of a reported comment and who wrote it; reporters do not.
	rpt := rep.c.Do(t, http.MethodPost, "/content-reports", map[string]any{"target_type": "comment", "target_id": cmid, "reason": "spam"}).Expect(t, http.StatusCreated).Data()
	if mine := rep.c.Do(t, http.MethodGet, "/content-reports", nil).Expect(t, http.StatusOK).List(); mine[0].(map[string]any)["post_id"] != nil || mine[0].(map[string]any)["target_user_id"] != nil {
		t.Fatalf("reporter's view = %v", mine)
	}
	q := mod.c.Do(t, http.MethodGet, "/communities/"+cid+"/moderation/reports", nil).Expect(t, http.StatusOK).List()
	if len(q) != 1 || q[0].(map[string]any)["post_id"] != sid || q[0].(map[string]any)["target_user_id"] != a.id {
		t.Fatalf("moderator queue = %v", q)
	}

	// M2 / M4 / M1: the action says until when it can be appealed; the appeal
	// embeds the action; the appellant sees it on their history and in
	// their appeals, and is told the outcome.
	act := mod.c.Do(t, http.MethodPost, "/communities/"+cid+"/moderation/actions", map[string]any{"action": "remove", "target_type": "comment", "target_id": cmid,
		"reason": "Advertising", "report_id": rpt["id"]}).Expect(t, http.StatusOK).Data()
	until, err := time.Parse(time.RFC3339Nano, act["appeal_until"].(string))
	created, _ := time.Parse(time.RFC3339Nano, act["created_at"].(string))
	if err != nil || !until.Equal(created.Add(30*24*time.Hour)) || act["appealable"] != true || act["appeal"] != nil {
		t.Fatalf("action = %v", act)
	}
	actID := act["id"].(string)
	ap := a.c.Do(t, http.MethodPost, "/moderation/actions/"+actID+"/appeals", map[string]any{"statement": "It was relevant"}).Expect(t, http.StatusCreated).Data()
	if sum := ap["action"].(map[string]any); sum["id"] != actID || sum["action"] != "remove" || sum["target_type"] != "comment" || sum["target_id"] != cmid ||
		sum["reason"] != "Advertising" || sum["created_at"] == nil || sum["moderator_id"] != nil {
		t.Fatalf("appeal action summary = %v", ap)
	}
	if r := a.c.Do(t, http.MethodPost, "/moderation/actions/"+actID+"/appeals", map[string]any{"statement": "Again"}); r.Status != http.StatusConflict ||
		detail(t, r)["code"] != "appeal_pending" {
		t.Fatalf("second appeal: %s", r.Raw)
	}
	hist := a.c.Do(t, http.MethodGet, "/me/moderation", nil).Expect(t, http.StatusOK).List()
	if st := hist[0].(map[string]any)["appeal"]; st == nil || st.(map[string]any)["id"] != ap["id"] || st.(map[string]any)["status"] != "open" {
		t.Fatalf("history appeal state = %v", hist[0])
	}
	if l := a.c.Do(t, http.MethodGet, "/me/moderation/appeals", nil).Expect(t, http.StatusOK).List(); len(l) != 1 || l[0].(map[string]any)["id"] != ap["id"] ||
		l[0].(map[string]any)["action"].(map[string]any)["reason"] != "Advertising" || l[0].(map[string]any)["action"].(map[string]any)["moderator_id"] != nil {
		t.Fatalf("my appeals = %v", l)
	}
	if l := rep.c.Do(t, http.MethodGet, "/me/moderation/appeals", nil).Expect(t, http.StatusOK).List(); len(l) != 0 {
		t.Fatalf("someone else's appeals visible: %v", l)
	}
	if l := o.c.Do(t, http.MethodGet, "/communities/"+cid+"/moderation/appeals", nil).Expect(t, http.StatusOK).List(); len(l) != 1 ||
		l[0].(map[string]any)["action"].(map[string]any)["target_user_id"] != a.id || l[0].(map[string]any)["action"].(map[string]any)["moderator_id"] != mod.id {
		t.Fatalf("open appeals = %v", l)
	}
	dec := o.c.Do(t, http.MethodPost, "/moderation/appeals/"+ap["id"].(string)+"/decide", map[string]any{"decision": "upheld", "note": "The rules are clear"}).
		Expect(t, http.StatusOK).Data()
	if dec["status"] != "upheld" || dec["action"].(map[string]any)["reversed_at"] != nil {
		t.Fatalf("decision = %v", dec)
	}
	if r := o.c.Do(t, http.MethodPost, "/moderation/appeals/"+ap["id"].(string)+"/decide", map[string]any{"decision": "overturned"}); r.Status != http.StatusConflict ||
		detail(t, r)["code"] != "appeal_already_decided" {
		t.Fatalf("deciding twice: %s", r.Raw)
	}
	s.RunJobs(t)
	if n := notificationsOf(t, a.c, "community", "moderation_appeal_upheld"); n != 1 {
		t.Fatalf("appeal outcome notices = %d", n)
	}
	hist = a.c.Do(t, http.MethodGet, "/me/moderation", nil).Expect(t, http.StatusOK).List()
	if st := hist[0].(map[string]any)["appeal"].(map[string]any); st["status"] != "upheld" || st["decision_note"] != "The rules are clear" || st["decided_at"] == nil {
		t.Fatalf("decided appeal on the history = %v", st)
	}
	found := false
	for _, x := range mod.c.Do(t, http.MethodGet, "/communities/"+cid+"/moderation/actions", nil).Expect(t, http.StatusOK).List() {
		if x.(map[string]any)["id"] == actID {
			found = x.(map[string]any)["appeal"].(map[string]any)["status"] == "upheld"
		}
	}
	if !found {
		t.Fatal("the moderation log does not show the appeal's outcome")
	}

	// M3: staff list platform actions with filters and cursor pages.
	warn := staff.c.Do(t, http.MethodPost, "/moderation/actions", map[string]any{"action": "warn", "target_type": "profile", "target_id": a.id,
		"reason": "Keep it friendly"}).Expect(t, http.StatusOK).Data()
	rs := staff.c.Do(t, http.MethodPost, "/moderation/actions", map[string]any{"action": "restrict", "target_type": "profile", "target_id": a.id,
		"reason": "Cool off", "duration_hours": 24}).Expect(t, http.StatusOK).Data()
	if r := mod.c.Do(t, http.MethodGet, "/moderation/actions", nil); r.Status != http.StatusForbidden {
		t.Fatalf("non-staff listing platform actions: %d", r.Status)
	}
	mine := "/moderation/actions?target_user_id=" + a.id
	all := staff.c.Do(t, http.MethodGet, mine, nil).Expect(t, http.StatusOK)
	if l := all.List(); len(l) != 2 || l[0].(map[string]any)["id"] != rs["id"] || l[1].(map[string]any)["id"] != warn["id"] || all.Body["meta"].(map[string]any)["has_more"] != false {
		t.Fatalf("platform actions for the person = %s", all.Raw)
	}
	ids := map[string]bool{}
	for _, x := range staff.c.Do(t, http.MethodGet, "/moderation/actions", nil).Expect(t, http.StatusOK).List() {
		ids[x.(map[string]any)["id"].(string)] = true
		if x.(map[string]any)["community_id"] != nil {
			t.Fatalf("community action in the platform list: %v", x)
		}
	}
	if !ids[rs["id"].(string)] || !ids[warn["id"].(string)] || ids[actID] {
		t.Fatalf("platform list ids = %v", ids)
	}
	page := staff.c.Do(t, http.MethodGet, mine+"&limit=1", nil).Expect(t, http.StatusOK)
	cursor, _ := page.Body["meta"].(map[string]any)["next_cursor"].(string)
	if len(page.List()) != 1 || cursor == "" || page.Body["meta"].(map[string]any)["has_more"] != true {
		t.Fatalf("page 1 = %s", page.Raw)
	}
	if l := staff.c.Do(t, http.MethodGet, mine+"&limit=1&cursor="+cursor, nil).Expect(t, http.StatusOK).List(); len(l) != 1 || l[0].(map[string]any)["id"] != warn["id"] {
		t.Fatalf("page 2 = %v", l)
	}
	if l := staff.c.Do(t, http.MethodGet, mine+"&action=warn", nil).Expect(t, http.StatusOK).List(); len(l) != 1 || l[0].(map[string]any)["id"] != warn["id"] {
		t.Fatalf("by action = %v", l)
	}
	staff.c.Do(t, http.MethodPost, "/moderation/actions/"+rs["id"].(string)+"/reverse", map[string]any{}).Expect(t, http.StatusOK)
	if l := staff.c.Do(t, http.MethodGet, mine+"&status=reversed", nil).Expect(t, http.StatusOK).List(); len(l) != 1 || l[0].(map[string]any)["id"] != rs["id"] {
		t.Fatalf("reversed = %v", l)
	}
	if l := staff.c.Do(t, http.MethodGet, mine+"&status=active", nil).Expect(t, http.StatusOK).List(); len(l) != 1 || l[0].(map[string]any)["id"] != warn["id"] {
		t.Fatalf("active for the person = %v", l)
	}
	if l := staff.c.Do(t, http.MethodGet, mine+"&target_type=community", nil).Expect(t, http.StatusOK).List(); len(l) != 0 {
		t.Fatalf("by target type = %v", l)
	}

	// M5: a reported group is resolved by dismissing its report.
	gid := createGroup(t, o.c, map[string]any{"name": "Flatmates", "group_type": "roommates", "base_currency": "INR"})["id"].(string)
	joinByLink(t, o, rep, gid)
	grp := rep.c.Do(t, http.MethodPost, "/content-reports", map[string]any{"target_type": "group", "target_id": gid, "reason": "scam"}).Expect(t, http.StatusCreated).Data()
	if r := staff.c.Do(t, http.MethodPost, "/moderation/actions", map[string]any{"action": "ban", "target_type": "group", "target_id": gid, "reason": "x",
		"report_id": grp["id"]}); r.ErrorCode() != "VALIDATION_ERROR" {
		t.Fatalf("banning a group: %s", r.Raw)
	}
	if r := staff.c.Do(t, http.MethodPost, "/moderation/actions", map[string]any{"action": "dismiss_report", "target_type": "group", "target_id": gid}); r.ErrorCode() != "VALIDATION_ERROR" {
		t.Fatalf("group dismissal without the report: %s", r.Raw)
	}
	if r := mod.c.Do(t, http.MethodPost, "/communities/"+cid+"/moderation/actions", map[string]any{"action": "dismiss_report", "target_type": "group",
		"target_id": gid, "report_id": grp["id"]}); r.ErrorCode() != "VALIDATION_ERROR" {
		t.Fatalf("community moderator dismissing a group report: %s", r.Raw)
	}
	dis := staff.c.Do(t, http.MethodPost, "/moderation/actions", map[string]any{"action": "dismiss_report", "target_type": "group", "target_id": gid,
		"report_id": grp["id"]}).Expect(t, http.StatusOK).Data()
	if dis["target_type"] != "group" || dis["appealable"] != false || dis["appeal_until"] != nil {
		t.Fatalf("dismissal = %v", dis)
	}
	for _, x := range rep.c.Do(t, http.MethodGet, "/content-reports", nil).Expect(t, http.StatusOK).List() {
		if x.(map[string]any)["id"] == grp["id"] && x.(map[string]any)["status"] != "dismissed" {
			t.Fatalf("group report = %v", x)
		}
	}
	for _, x := range staff.c.Do(t, http.MethodGet, "/moderation/reports", nil).Expect(t, http.StatusOK).List() {
		if x.(map[string]any)["id"] == grp["id"] {
			t.Fatal("dismissed group report still queued")
		}
	}
}

// Challenge fixes: partial PATCH with version, group and community refs,
// the daily creation cap with Retry-After, and cursor pages.
func TestChallengePatchRefsCapAndPaging(t *testing.T) {
	s := apitest.New(t, nil)
	a := newPerson(t, s, "saver", nil)
	b := newPerson(t, s, "buddy", nil)
	today := todayIn(t, "Asia/Kolkata")
	gid := createGroup(t, a.c, map[string]any{"name": "Savers", "group_type": "friends", "base_currency": "INR"})["id"].(string)
	joinByLink(t, a, b, gid)
	ccid := createCommunity(t, a, map[string]any{"name": "Savers Club"})["id"].(string)
	b.c.Do(t, http.MethodPost, "/communities/"+ccid+"/join", nil).Expect(t, http.StatusOK)
	dates := map[string]any{"starts_on": today.AddDate(0, 0, -3).Format(day), "ends_on": today.AddDate(0, 0, 10).Format(day)}
	mk := func(p person, body map[string]any) map[string]any {
		t.Helper()
		for k, v := range dates {
			body[k] = v
		}
		return p.c.Do(t, http.MethodPost, "/challenges", body).Expect(t, http.StatusCreated).Data()
	}

	// C3: group and community refs.
	gc := mk(a, map[string]any{"title": "Meal plan streak", "challenge_type": "meal_planning", "metric": "streak", "target_value": 5, "group_id": gid,
		"leaderboard_enabled": true, "description": "Plan meals", "rules": "Check in daily"})
	gcid := gc["id"].(string)
	if g := gc["group"].(map[string]any); g["id"] != gid || g["name"] != "Savers" || gc["version"].(float64) != 1 || gc["community"] != nil {
		t.Fatalf("group challenge = %v", gc)
	}
	cc := mk(a, map[string]any{"title": "Cook at home", "challenge_type": "custom", "metric": "days", "target_value": 5, "community_id": ccid})
	if c := cc["community"].(map[string]any); c["id"] != ccid || c["name"] != "Savers Club" || cc["group"] != nil {
		t.Fatalf("community challenge = %v", cc)
	}
	if got := b.c.Do(t, http.MethodGet, "/challenges/"+gcid, nil).Expect(t, http.StatusOK).Data(); got["group"].(map[string]any)["name"] != "Savers" {
		t.Fatalf("member's view = %v", got)
	}

	// C1: PATCH changes only what is sent and needs the current version.
	up := a.c.Do(t, http.MethodPatch, "/challenges/"+gcid, map[string]any{"title": "Meal plan streak!", "version": 1}).Expect(t, http.StatusOK).Data()
	if up["title"] != "Meal plan streak!" || up["description"] != "Plan meals" || up["rules"] != "Check in daily" || up["leaderboard_enabled"] != true || up["version"].(float64) != 2 {
		t.Fatalf("patched = %v", up)
	}
	if r := a.c.Do(t, http.MethodPatch, "/challenges/"+gcid, map[string]any{"title": "Stale", "version": 1}); r.ErrorCode() != "VERSION_CONFLICT" {
		t.Fatalf("stale version: %s", r.Raw)
	}
	if r := a.c.Do(t, http.MethodPatch, "/challenges/"+gcid, map[string]any{"title": "x", "version": 2}); detail(t, r)["code"] != "too_short" || detail(t, r)["params"].(map[string]any)["min"] != "3" {
		t.Fatalf("short title: %s", r.Raw)
	}
	cleared := a.c.Do(t, http.MethodPatch, "/challenges/"+gcid, map[string]any{"description": "", "leaderboard_enabled": false, "version": 2}).Expect(t, http.StatusOK).Data()
	if cleared["description"] != nil || cleared["rules"] != "Check in daily" || cleared["leaderboard_enabled"] != false || cleared["version"].(float64) != 3 {
		t.Fatalf("cleared = %v", cleared)
	}
	if r := b.c.Do(t, http.MethodPatch, "/challenges/"+gcid, map[string]any{"title": "Hijack", "version": 3}); r.Status != http.StatusForbidden {
		t.Fatalf("participant editing: %d", r.Status)
	}
	if r := a.c.Do(t, http.MethodPatch, "/challenges/"+gcid, map[string]any{"ends_on": today.AddDate(0, 0, 5).Format(day), "version": 3}); r.ErrorCode() != "VALIDATION_ERROR" {
		t.Fatalf("shortening: %s", r.Raw)
	}
	if r := a.c.Do(t, http.MethodGet, "/challenges/"+gcid+"/leaderboard", nil); r.ErrorCode() != "DOMAIN_RULE_VIOLATION" || detail(t, r)["code"] != "no_leaderboard" {
		t.Fatalf("leaderboard turned off: %s", r.Raw)
	}

	// C5: cursor pages in a stable order (active first, then by end date and title).
	mk(a, map[string]any{"title": "Alone time", "challenge_type": "no_spend", "metric": "days", "target_value": 2})
	p1 := a.c.Do(t, http.MethodGet, "/challenges?limit=2", nil).Expect(t, http.StatusOK)
	m1 := p1.Body["meta"].(map[string]any)
	cursor, _ := m1["next_cursor"].(string)
	if len(p1.List()) != 2 || m1["has_more"] != true || cursor == "" {
		t.Fatalf("page 1 = %s", p1.Raw)
	}
	p2 := a.c.Do(t, http.MethodGet, "/challenges?limit=2&cursor="+cursor, nil).Expect(t, http.StatusOK)
	if len(p2.List()) != 1 || p2.Body["meta"].(map[string]any)["has_more"] != false {
		t.Fatalf("page 2 = %s", p2.Raw)
	}
	var titles []string
	for _, x := range append(p1.List(), p2.List()...) {
		titles = append(titles, x.(map[string]any)["title"].(string))
	}
	if strings.Join(titles, "|") != "Alone time|Cook at home|Meal plan streak!" {
		t.Fatalf("order = %v", titles)
	}
	if r := a.c.Do(t, http.MethodGet, "/challenges?cursor=bogus", nil); r.ErrorCode() != "VALIDATION_ERROR" {
		t.Fatalf("bogus cursor: %s", r.Raw)
	}

	// C4: the daily cap says when it resets.
	capper := newPerson(t, s, "capper", nil)
	for i := 0; i < 10; i++ {
		mk(capper, map[string]any{"title": "Challenge " + strconv.Itoa(i), "challenge_type": "custom", "metric": "days", "target_value": 3})
	}
	r := capper.c.Do(t, http.MethodPost, "/challenges", map[string]any{"title": "One too many", "challenge_type": "custom", "metric": "days", "target_value": 3,
		"starts_on": dates["starts_on"], "ends_on": dates["ends_on"]})
	secs, err := strconv.Atoi(r.Headers.Get("Retry-After"))
	if r.ErrorCode() != "RATE_LIMITED" || err != nil || secs <= 0 || secs > 86400 {
		t.Fatalf("challenge cap: Retry-After=%q %s", r.Headers.Get("Retry-After"), r.Raw)
	}
	if d := detail(t, r); d["code"] != "daily_cap" || d["params"].(map[string]any)["limit"] != "10" || d["params"].(map[string]any)["resource"] != "challenges" ||
		d["params"].(map[string]any)["retry_at"] == nil {
		t.Fatalf("daily cap detail = %v", d)
	}
}
