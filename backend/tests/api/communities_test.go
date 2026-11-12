package api_test

import (
	"net/http"
	"strconv"
	"strings"
	"testing"
	"time"

	"montra/backend/internal/testutil/apitest"
)

// seasoned makes an account older than a day (new accounts have tighter
// spam limits and cannot post links).
func seasoned(t *testing.T, s *apitest.Server, p person) {
	t.Helper()
	s.Env.ExecWorker(t, `update users set created_at = now() - interval '30 days' where id = $1`, p.id)
}

func createCommunity(t *testing.T, p person, body map[string]any) map[string]any {
	t.Helper()
	return p.c.Do(t, http.MethodPost, "/communities", body).Expect(t, http.StatusCreated).Data()
}

func post(t *testing.T, p person, cid string, body map[string]any) map[string]any {
	t.Helper()
	return p.c.Do(t, http.MethodPost, "/communities/"+cid+"/posts", body).Expect(t, http.StatusCreated).Data()
}

func TestCommunitiesMembershipPostsPollsAndSafety(t *testing.T) {
	s := apitest.New(t, nil)
	o := newPerson(t, s, "founder", nil)
	m := newPerson(t, s, "member", nil)
	out := newPerson(t, s, "visitor", nil)
	// Social actions are rate limited per person (burst 15), so the poll and
	// membership flows use their own people.
	voter := newPerson(t, s, "voter", nil)
	joiner := newPerson(t, s, "joiner", nil)
	host := newPerson(t, s, "host", nil)
	seasoned(t, s, o)

	pub := createCommunity(t, o, map[string]any{"name": "Debt Free India", "description": "Paying off loans together", "topics": []string{"Debt", "loans"}})
	cid := pub["id"].(string)
	if pub["slug"] != "debt-free-india" || pub["my_role"] != "owner" || pub["visibility"] != "public" || pub["member_count"].(float64) != 1 {
		t.Fatalf("community = %v", pub)
	}
	if r := o.c.Do(t, http.MethodPost, "/communities", map[string]any{"name": "Debt Free India"}); r.Status != http.StatusConflict {
		t.Fatalf("duplicate URL name: %d", r.Status)
	}
	if got := out.c.Do(t, http.MethodGet, "/communities/debt-free-india", nil).Expect(t, http.StatusOK).Data(); got["id"] != cid || got["my_status"] != "none" {
		t.Fatalf("by slug = %v", got)
	}
	if l := out.c.Do(t, http.MethodGet, "/communities?topic=debt", nil).Expect(t, http.StatusOK).List(); len(l) != 1 {
		t.Fatalf("topic discovery = %v", l)
	}
	m.c.Do(t, http.MethodPost, "/communities/"+cid+"/join", nil).Expect(t, http.StatusOK)
	voter.c.Do(t, http.MethodPost, "/communities/"+cid+"/join", nil).Expect(t, http.StatusOK)

	// Posting: members only; plain text cleaned; secrets refused.
	p1 := post(t, m, cid, map[string]any{"title": "My first \u202Eloan\u202C payoff", "body": "Paid off the bike loan <script>alert(1)</script>"})
	if p1["title"] != "My first loan payoff" || !strings.Contains(p1["body"].(string), "<script>") || p1["label"] != "personal_experience" {
		t.Fatalf("post = %v (text is stored as plain text; clients escape it)", p1)
	}
	if r := out.c.Do(t, http.MethodPost, "/communities/"+cid+"/posts", map[string]any{"title": "Hello there"}); r.ErrorCode() != "DOMAIN_RULE_VIOLATION" {
		t.Fatalf("non-member posting: %s", r.Raw)
	}
	if r := m.c.Do(t, http.MethodPost, "/communities/"+cid+"/posts", map[string]any{"title": "Help", "body": "My card is 4111 1111 1111 1111"}); r.ErrorCode() != "VALIDATION_ERROR" {
		t.Fatalf("card number in a post: %s", r.Raw)
	}
	if r := m.c.Do(t, http.MethodPost, "/communities/"+cid+"/posts", map[string]any{"title": "Official", "label": "verified_guidance"}); r.ErrorCode() != "VALIDATION_ERROR" {
		t.Fatalf("member labelling verified guidance: %s", r.Raw)
	}
	if r := m.c.Do(t, http.MethodPost, "/communities/"+cid+"/posts", map[string]any{"title": "Useful link", "kind": "resource", "link_url": "https://rbi.org.in"}); r.ErrorCode() != "DOMAIN_RULE_VIOLATION" {
		t.Fatalf("new account posting a link: %s", r.Raw)
	}
	if r := m.c.Do(t, http.MethodPost, "/communities/"+cid+"/posts", map[string]any{"title": "My first loan payoff"}); r.Status != http.StatusConflict {
		t.Fatalf("duplicate post: %d", r.Status)
	}
	g := post(t, o, cid, map[string]any{"title": "RBI guidance on loan prepayment", "kind": "resource", "label": "verified_guidance",
		"link_url": "https://rbi.org.in/scripts/faq.aspx"})
	if g["label"] != "verified_guidance" || g["link_url"] != "https://rbi.org.in/scripts/faq.aspx" {
		t.Fatalf("guidance post = %v", g)
	}
	if r := o.c.Do(t, http.MethodPost, "/communities/"+cid+"/posts", map[string]any{"title": "Bad link", "kind": "resource", "link_url": "http://insecure.example"}); r.ErrorCode() != "VALIDATION_ERROR" {
		t.Fatalf("http link: %s", r.Raw)
	}
	// New accounts: at most 3 posts a day; the cap says when it resets.
	post(t, m, cid, map[string]any{"title": "Second post"})
	post(t, m, cid, map[string]any{"title": "Third post"})
	capped := m.c.Do(t, http.MethodPost, "/communities/"+cid+"/posts", map[string]any{"title": "Fourth post"})
	if secs, err := strconv.Atoi(capped.Headers.Get("Retry-After")); capped.ErrorCode() != "RATE_LIMITED" || err != nil || secs <= 0 || secs > 86400 {
		t.Fatalf("new-account post cap: Retry-After=%q %s", capped.Headers.Get("Retry-After"), capped.Raw)
	}
	if d := detail(t, capped); d["code"] != "daily_cap" || d["params"].(map[string]any)["limit"] != "3" || d["params"].(map[string]any)["resource"] != "posts" {
		t.Fatalf("daily cap detail = %v", d)
	}

	// Polls: aggregate results only; one choice unless multiple allowed.
	poll := post(t, o, cid, map[string]any{"title": "Which payoff method?", "kind": "poll",
		"poll": map[string]any{"question": "Avalanche or snowball?", "options": []string{"Avalanche", "Snowball", "Neither"}}})
	opts := poll["poll"].(map[string]any)["options"].([]any)
	pid := poll["id"].(string)
	v := voter.c.Do(t, http.MethodPost, "/posts/"+pid+"/poll/votes", map[string]any{"option_ids": []string{opts[0].(map[string]any)["id"].(string)}}).
		Expect(t, http.StatusOK).Data()
	if v["total_votes"].(float64) != 1 || len(v["my_votes"].([]any)) != 1 {
		t.Fatalf("vote = %v", v)
	}
	v = voter.c.Do(t, http.MethodPost, "/posts/"+pid+"/poll/votes", map[string]any{"option_ids": []string{opts[1].(map[string]any)["id"].(string)}}).
		Expect(t, http.StatusOK).Data()
	if v["options"].([]any)[0].(map[string]any)["votes"].(float64) != 0 || v["options"].([]any)[1].(map[string]any)["votes"].(float64) != 1 {
		t.Fatalf("changed vote = %v", v)
	}
	if r := voter.c.Do(t, http.MethodPost, "/posts/"+pid+"/poll/votes", map[string]any{"option_ids": []string{opts[0].(map[string]any)["id"].(string),
		opts[1].(map[string]any)["id"].(string)}}); r.ErrorCode() != "VALIDATION_ERROR" {
		t.Fatalf("two votes in a single-choice poll: %s", r.Raw)
	}
	if r := out.c.Do(t, http.MethodPost, "/posts/"+pid+"/poll/votes", map[string]any{"option_ids": []string{opts[0].(map[string]any)["id"].(string)}}); r.ErrorCode() != "DOMAIN_RULE_VIOLATION" {
		t.Fatalf("non-member voting: %s", r.Raw)
	}
	s.Env.ExecWorker(t, `update community_polls set closes_at = now() - interval '1 minute' where post_id = $1`, pid)
	if r := voter.c.Do(t, http.MethodPost, "/posts/"+pid+"/poll/votes", map[string]any{"option_ids": []string{opts[2].(map[string]any)["id"].(string)}}); r.ErrorCode() != "DOMAIN_RULE_VIOLATION" {
		t.Fatalf("voting in a closed poll: %s", r.Raw)
	}

	// Comments, replies, reactions and reply notifications.
	p1id := p1["id"].(string)
	c1 := o.c.Do(t, http.MethodPost, "/posts/"+p1id+"/comments", map[string]any{"body": "Congratulations!"}).Expect(t, http.StatusCreated).Data()
	m.c.Do(t, http.MethodPost, "/posts/"+p1id+"/comments", map[string]any{"body": "Thanks!", "parent_comment_id": c1["id"]}).Expect(t, http.StatusCreated)
	rc := o.c.Do(t, http.MethodPost, "/posts/"+p1id+"/reactions", map[string]any{"kind": "support"}).Expect(t, http.StatusOK).Data()
	o.c.Do(t, http.MethodPost, "/posts/"+p1id+"/reactions", map[string]any{"kind": "support"}).Expect(t, http.StatusOK)
	if rc["support"].(float64) != 1 {
		t.Fatalf("reactions = %v", rc)
	}
	detail := m.c.Do(t, http.MethodGet, "/posts/"+p1id, nil).Expect(t, http.StatusOK).Data()
	if len(detail["comments"].([]any)) != 2 || detail["reactions"].(map[string]any)["support"].(float64) != 1 || detail["author"].(map[string]any)["display_name"] != "Test member" {
		t.Fatalf("post detail = %v", detail)
	}
	if rc := o.c.Do(t, http.MethodDelete, "/posts/"+p1id+"/reactions/support", nil).Expect(t, http.StatusOK).Data(); rc["support"].(float64) != 0 {
		t.Fatalf("after removing the reaction = %v", rc)
	}
	s.RunJobs(t)
	if n := notificationsOf(t, m.c, "community", "comment_on_post"); n != 1 {
		t.Fatalf("post author comment notifications = %d", n)
	}
	if n := notificationsOf(t, o.c, "community", "reply_to_comment"); n != 1 {
		t.Fatalf("reply notifications = %d", n)
	}
	// Authors edit and delete only their own content.
	if r := o.c.Do(t, http.MethodPatch, "/posts/"+p1id, map[string]any{"title": "Hijacked"}); r.Status != http.StatusForbidden {
		t.Fatalf("editing someone else's post: %d", r.Status)
	}
	ed := m.c.Do(t, http.MethodPatch, "/posts/"+p1id, map[string]any{"title": "My first loan payoff!", "body": "Updated"}).Expect(t, http.StatusOK).Data()
	if ed["edited_at"] == nil || ed["body"] != "Updated" {
		t.Fatalf("edited = %v", ed)
	}
	// Blocking hides the other person's posts.
	out.c.Do(t, http.MethodPost, "/users/"+m.id+"/block", nil).Expect(t, http.StatusOK)
	for _, x := range out.c.Do(t, http.MethodGet, "/communities/"+cid+"/posts", nil).Expect(t, http.StatusOK).List() {
		if x.(map[string]any)["author"].(map[string]any)["user_id"] == m.id {
			t.Fatal("blocked author's post visible")
		}
	}
	if r := out.c.Do(t, http.MethodGet, "/posts/"+p1id, nil); r.Status != http.StatusNotFound {
		t.Fatalf("blocked author's post by ID: %d", r.Status)
	}
	m.c.Do(t, http.MethodDelete, "/posts/"+p1id, nil).Expect(t, http.StatusOK)
	if mine := m.c.Do(t, http.MethodGet, "/posts/"+p1id, nil).Expect(t, http.StatusOK).Data(); mine["status"] != "deleted" || mine["body"] != "" {
		t.Fatalf("deleted post = %v", mine)
	}

	// Private: join requests are approved by moderators.
	priv := createCommunity(t, host, map[string]any{"name": "Salary Negotiation Circle", "visibility": "private"})["id"].(string)
	if j := joiner.c.Do(t, http.MethodPost, "/communities/"+priv+"/join", nil).Expect(t, http.StatusOK).Data(); j["my_status"] != "pending" {
		t.Fatalf("private join = %v", j)
	}
	if r := joiner.c.Do(t, http.MethodGet, "/communities/"+priv+"/posts", nil); r.Status != http.StatusForbidden {
		t.Fatalf("pending member reading private posts: %d", r.Status)
	}
	s.RunJobs(t)
	if n := notificationsOf(t, host.c, "community", "community_join_request"); n != 1 {
		t.Fatalf("moderator join-request notifications = %d", n)
	}
	if l := host.c.Do(t, http.MethodGet, "/communities/"+priv+"/members?status=pending", nil).Expect(t, http.StatusOK).List(); len(l) != 1 || l[0].(map[string]any)["display_name"] != "Test joiner" {
		t.Fatalf("pending members = %v", l)
	}
	host.c.Do(t, http.MethodPost, "/communities/"+priv+"/members/"+joiner.id+"/approve", nil).Expect(t, http.StatusOK)
	joiner.c.Do(t, http.MethodGet, "/communities/"+priv+"/posts", nil).Expect(t, http.StatusOK)
	s.RunJobs(t)
	if n := notificationsOf(t, joiner.c, "community", "community_membership"); n != 1 {
		t.Fatalf("approval notifications = %d", n)
	}
	// Members see only the moderators list.
	if l := joiner.c.Do(t, http.MethodGet, "/communities/"+priv+"/members", nil).Expect(t, http.StatusOK).List(); len(l) != 1 || l[0].(map[string]any)["role"] != "owner" {
		t.Fatalf("member's view of members = %v", l)
	}

	// Invite-only: unlisted; joining needs an invitation.
	inv := createCommunity(t, host, map[string]any{"name": "Founders Only", "visibility": "invite_only"})["id"].(string)
	if r := out.c.Do(t, http.MethodGet, "/communities/"+inv, nil); r.Status != http.StatusNotFound {
		t.Fatalf("invite-only community visible to outsiders: %d", r.Status)
	}
	for _, c := range out.c.Do(t, http.MethodGet, "/communities", nil).Expect(t, http.StatusOK).List() {
		if c.(map[string]any)["id"] == inv {
			t.Fatal("invite-only community listed")
		}
	}
	link := host.c.Do(t, http.MethodPost, "/communities/"+inv+"/invitations", map[string]any{}).Expect(t, http.StatusCreated).Data()
	if j := out.c.Do(t, http.MethodPost, "/community-invitations/accept", map[string]any{"token": link["token"]}).Expect(t, http.StatusOK).Data(); j["my_status"] != "active" {
		t.Fatalf("invitation join = %v", j)
	}
	if r := joiner.c.Do(t, http.MethodPost, "/community-invitations/accept", map[string]any{"token": link["token"]}); r.Status != http.StatusGone {
		t.Fatalf("reused invitation: %d", r.Status)
	}
	uinv := host.c.Do(t, http.MethodPost, "/communities/"+inv+"/invitations", map[string]any{"username": joiner.user}).Expect(t, http.StatusCreated).Data()
	mine := joiner.c.Do(t, http.MethodGet, "/community-invitations", nil).Expect(t, http.StatusOK).List()
	if len(mine) != 1 || mine[0].(map[string]any)["community_name"] != "Founders Only" {
		t.Fatalf("my community invitations = %v", mine)
	}
	joiner.c.Do(t, http.MethodPost, "/community-invitations/"+uinv["id"].(string)+"/accept", nil).Expect(t, http.StatusOK)

	// Owners transfer before leaving; members leave freely.
	if r := o.c.Do(t, http.MethodPost, "/communities/"+cid+"/leave", nil); r.ErrorCode() != "DOMAIN_RULE_VIOLATION" {
		t.Fatalf("owner leaving: %s", r.Raw)
	}
	m.c.Do(t, http.MethodPost, "/communities/"+cid+"/leave", nil).Expect(t, http.StatusOK)
	if r := m.c.Do(t, http.MethodPost, "/communities/"+cid+"/posts", map[string]any{"title": "After leaving"}); r.ErrorCode() != "DOMAIN_RULE_VIOLATION" {
		t.Fatalf("posting after leaving: %s", r.Raw)
	}
}

func TestModerationReportsActionsSanctionsAndAppeals(t *testing.T) {
	s := apitest.New(t, nil)
	o := newPerson(t, s, "owner", nil)
	mod := newPerson(t, s, "mod", nil)
	a := newPerson(t, s, "author", nil)
	r1 := newPerson(t, s, "reporter1", nil)
	r2 := newPerson(t, s, "reporter2", nil)
	r3 := newPerson(t, s, "reporter3", nil)
	staff := newPerson(t, s, "staff", nil)
	s.Env.ExecWorker(t, `update users set platform_role = 'support' where id = $1`, staff.id)
	cid := createCommunity(t, o, map[string]any{"name": "Frugal Living"})["id"].(string)
	for _, p := range []person{mod, a, r1, r2, r3} {
		p.c.Do(t, http.MethodPost, "/communities/"+cid+"/join", nil).Expect(t, http.StatusOK)
	}
	o.c.Do(t, http.MethodPatch, "/communities/"+cid+"/members/"+mod.id, map[string]any{"role": "moderator"}).Expect(t, http.StatusOK)
	spam := post(t, a, cid, map[string]any{"title": "Buy my course"})
	sid := spam["id"].(string)

	// Three different reporters hide the post pending review.
	rep := r1.c.Do(t, http.MethodPost, "/posts/"+sid+"/reports", map[string]any{"reason": "spam"}).Expect(t, http.StatusCreated).Data()
	if r := r1.c.Do(t, http.MethodPost, "/posts/"+sid+"/reports", map[string]any{"reason": "spam"}); r.Status != http.StatusConflict {
		t.Fatalf("duplicate report: %d", r.Status)
	}
	if r := a.c.Do(t, http.MethodPost, "/posts/"+sid+"/reports", map[string]any{"reason": "spam"}); r.ErrorCode() != "DOMAIN_RULE_VIOLATION" {
		t.Fatalf("reporting own post: %s", r.Raw)
	}
	r2.c.Do(t, http.MethodPost, "/content-reports", map[string]any{"target_type": "post", "target_id": sid, "reason": "scam"}).Expect(t, http.StatusCreated)
	s.RunJobs(t)
	if st := r1.c.Do(t, http.MethodGet, "/communities/"+cid+"/posts", nil).Expect(t, http.StatusOK).List(); len(st) != 1 {
		t.Fatalf("two reports must not hide the post: %d", len(st))
	}
	r3.c.Do(t, http.MethodPost, "/posts/"+sid+"/reports", map[string]any{"reason": "spam", "details": "Same link everywhere"}).Expect(t, http.StatusCreated)
	s.RunJobs(t)
	if l := r1.c.Do(t, http.MethodGet, "/communities/"+cid+"/posts", nil).Expect(t, http.StatusOK).List(); len(l) != 0 {
		t.Fatalf("auto-hide after three reports: %v", l)
	}
	if own := a.c.Do(t, http.MethodGet, "/posts/"+sid, nil).Expect(t, http.StatusOK).Data(); own["status"] != "hidden" || own["removed_reason"] != nil {
		t.Fatalf("author's view of the hidden post = %v", own)
	}
	if n := notificationsOf(t, a.c, "community", "moderation_hide"); n != 1 {
		t.Fatalf("author hide notifications = %d", n)
	}
	q := mod.c.Do(t, http.MethodGet, "/communities/"+cid+"/moderation/reports", nil).Expect(t, http.StatusOK).List()
	if len(q) != 3 || q[0].(map[string]any)["open_reports"].(float64) != 3 || q[0].(map[string]any)["preview"] == nil {
		t.Fatalf("moderator queue = %v", q)
	}
	if r := r1.c.Do(t, http.MethodGet, "/communities/"+cid+"/moderation/reports", nil); r.Status != http.StatusForbidden {
		t.Fatalf("member reading the queue: %d", r.Status)
	}
	// The moderator restores it; the reports are dismissed together.
	mod.c.Do(t, http.MethodPost, "/communities/"+cid+"/moderation/actions", map[string]any{"action": "restore", "target_type": "post", "target_id": sid,
		"report_id": rep["id"]}).Expect(t, http.StatusOK)
	if mr := r1.c.Do(t, http.MethodGet, "/content-reports", nil).Expect(t, http.StatusOK).List(); mr[0].(map[string]any)["status"] != "dismissed" {
		t.Fatalf("reporter's view = %v", mr)
	}
	if l := mod.c.Do(t, http.MethodGet, "/communities/"+cid+"/moderation/reports", nil).Expect(t, http.StatusOK).List(); len(l) != 0 {
		t.Fatalf("queue after review = %v", l)
	}

	// Removal needs a reason; the author appeals; another moderator decides.
	if r := mod.c.Do(t, http.MethodPost, "/communities/"+cid+"/moderation/actions", map[string]any{"action": "remove", "target_type": "post", "target_id": sid}); r.ErrorCode() != "VALIDATION_ERROR" {
		t.Fatalf("removal without reason: %s", r.Raw)
	}
	act := mod.c.Do(t, http.MethodPost, "/communities/"+cid+"/moderation/actions", map[string]any{"action": "remove", "target_type": "post", "target_id": sid,
		"reason": "Advertising is not allowed"}).Expect(t, http.StatusOK).Data()
	if own := a.c.Do(t, http.MethodGet, "/posts/"+sid, nil).Expect(t, http.StatusOK).Data(); own["status"] != "removed" || own["removed_reason"] != "Advertising is not allowed" {
		t.Fatalf("removed post = %v", own)
	}
	hist := a.c.Do(t, http.MethodGet, "/me/moderation", nil).Expect(t, http.StatusOK).List()
	if len(hist) != 2 || hist[0].(map[string]any)["moderator_id"] != nil || hist[0].(map[string]any)["appealable"] != true {
		t.Fatalf("author's moderation history = %v", hist)
	}
	ap := a.c.Do(t, http.MethodPost, "/moderation/actions/"+act["id"].(string)+"/appeals", map[string]any{"statement": "It was a free guide"}).
		Expect(t, http.StatusCreated).Data()
	if r := a.c.Do(t, http.MethodPost, "/moderation/actions/"+act["id"].(string)+"/appeals", map[string]any{"statement": "Again"}); r.Status != http.StatusConflict {
		t.Fatalf("second appeal: %d", r.Status)
	}
	if r := mod.c.Do(t, http.MethodPost, "/moderation/appeals/"+ap["id"].(string)+"/decide", map[string]any{"decision": "upheld"}); r.ErrorCode() != "DOMAIN_RULE_VIOLATION" {
		t.Fatalf("moderator deciding the appeal of their own action: %s", r.Raw)
	}
	if l := o.c.Do(t, http.MethodGet, "/communities/"+cid+"/moderation/appeals", nil).Expect(t, http.StatusOK).List(); len(l) != 1 {
		t.Fatalf("open appeals = %v", l)
	}
	dec := o.c.Do(t, http.MethodPost, "/moderation/appeals/"+ap["id"].(string)+"/decide", map[string]any{"decision": "overturned", "note": "Guide was free"}).
		Expect(t, http.StatusOK).Data()
	if dec["status"] != "overturned" {
		t.Fatalf("decision = %v", dec)
	}
	if own := a.c.Do(t, http.MethodGet, "/posts/"+sid, nil).Expect(t, http.StatusOK).Data(); own["status"] != "published" {
		t.Fatalf("overturned removal must restore the post: %v", own["status"])
	}

	// Restrictions stop posting until reversed; bans exclude; owners are safe.
	rs := mod.c.Do(t, http.MethodPost, "/communities/"+cid+"/moderation/actions", map[string]any{"action": "restrict", "target_type": "member",
		"target_id": r1.id, "reason": "Cool off", "duration_hours": 24}).Expect(t, http.StatusOK).Data()
	if r := r1.c.Do(t, http.MethodPost, "/communities/"+cid+"/posts", map[string]any{"title": "Still here"}); r.ErrorCode() != "DOMAIN_RULE_VIOLATION" {
		t.Fatalf("restricted member posting: %s", r.Raw)
	}
	mod.c.Do(t, http.MethodPost, "/moderation/actions/"+rs["id"].(string)+"/reverse", map[string]any{"note": "Lifted early"}).Expect(t, http.StatusOK)
	post(t, r1, cid, map[string]any{"title": "Back again"})
	if r := mod.c.Do(t, http.MethodPost, "/communities/"+cid+"/moderation/actions", map[string]any{"action": "ban", "target_type": "member", "target_id": o.id,
		"reason": "x"}); r.Status != http.StatusForbidden {
		t.Fatalf("moderator banning the owner: %d", r.Status)
	}
	mod.c.Do(t, http.MethodPost, "/communities/"+cid+"/moderation/actions", map[string]any{"action": "ban", "target_type": "member", "target_id": r2.id,
		"reason": "Repeated scams"}).Expect(t, http.StatusOK)
	if r := r2.c.Do(t, http.MethodPost, "/communities/"+cid+"/posts", map[string]any{"title": "Let me back"}); r.Status != http.StatusForbidden {
		t.Fatalf("banned member posting: %d", r.Status)
	}
	if r := r2.c.Do(t, http.MethodPost, "/communities/"+cid+"/join", nil); r.Status != http.StatusForbidden {
		t.Fatalf("banned member rejoining: %d", r.Status)
	}
	if r := r3.c.Do(t, http.MethodPost, "/communities/"+cid+"/moderation/actions", map[string]any{"action": "warn", "target_type": "member", "target_id": a.id,
		"reason": "x"}); r.Status != http.StatusForbidden {
		t.Fatalf("member using moderation: %d", r.Status)
	}
	mod2 := newPerson(t, s, "mod2", nil)
	mod2.c.Do(t, http.MethodPost, "/communities/"+cid+"/join", nil).Expect(t, http.StatusOK)
	o.c.Do(t, http.MethodPatch, "/communities/"+cid+"/members/"+mod2.id, map[string]any{"role": "moderator"}).Expect(t, http.StatusOK)
	if r := mod2.c.Do(t, http.MethodPost, "/communities/"+cid+"/moderation/actions", map[string]any{"action": "ban", "target_type": "member",
		"target_id": mod.id, "reason": "x"}); r.Status != http.StatusForbidden {
		t.Fatalf("moderator banning a moderator: %d", r.Status)
	}
	if l := o.c.Do(t, http.MethodGet, "/communities/"+cid+"/moderation/actions", nil).Expect(t, http.StatusOK).List(); len(l) < 5 {
		t.Fatalf("moderation log = %d entries", len(l))
	}

	// Platform staff: profile reports and account-wide sanctions.
	r3.c.Do(t, http.MethodPost, "/content-reports", map[string]any{"target_type": "profile", "target_id": a.id, "reason": "impersonation"}).Expect(t, http.StatusCreated)
	if r := r3.c.Do(t, http.MethodGet, "/moderation/reports", nil); r.Status != http.StatusForbidden {
		t.Fatalf("non-staff platform queue: %d", r.Status)
	}
	pq := staff.c.Do(t, http.MethodGet, "/moderation/reports", nil).Expect(t, http.StatusOK).List()
	if len(pq) != 1 || pq[0].(map[string]any)["target_type"] != "profile" {
		t.Fatalf("platform queue = %v", pq)
	}
	ban := staff.c.Do(t, http.MethodPost, "/moderation/actions", map[string]any{"action": "restrict", "target_type": "profile", "target_id": a.id,
		"reason": "Impersonating a bank", "duration_hours": 72, "report_id": pq[0].(map[string]any)["id"]}).Expect(t, http.StatusOK).Data()
	if r := a.c.Do(t, http.MethodPost, "/communities/"+cid+"/posts", map[string]any{"title": "Can I post?"}); r.ErrorCode() != "DOMAIN_RULE_VIOLATION" {
		t.Fatalf("platform-restricted account posting: %s", r.Raw)
	}
	s.RunJobs(t)
	if n := notificationsOf(t, a.c, "community", "moderation_restrict"); n != 1 {
		t.Fatalf("sanction notifications = %d", n)
	}
	staff.c.Do(t, http.MethodPost, "/moderation/actions/"+ban["id"].(string)+"/reverse", map[string]any{}).Expect(t, http.StatusOK)
	post(t, a, cid, map[string]any{"title": "Thanks for the review"})
}

func TestChallengesOptInProgressAndLeaderboard(t *testing.T) {
	s := apitest.New(t, nil)
	a := newPerson(t, s, "saver", nil)
	b := newPerson(t, s, "buddy", nil)
	c := newPerson(t, s, "outsider", nil)
	// Registration sets Asia/Kolkata; dates below use that calendar.
	today := todayIn(t, "Asia/Kolkata")
	gid := createGroup(t, a.c, map[string]any{"name": "Savers", "group_type": "friends", "base_currency": "INR"})["id"].(string)
	joinByLink(t, a, b, gid)

	// Private challenge: progress is private and counts check-in days.
	pc := a.c.Do(t, http.MethodPost, "/challenges", map[string]any{"title": "No-spend week", "challenge_type": "no_spend", "metric": "days", "target_value": 3,
		"starts_on": today.AddDate(0, 0, -5).Format(day), "ends_on": today.AddDate(0, 0, 2).Format(day)}).Expect(t, http.StatusCreated).Data()
	pid := pc["id"].(string)
	if pc["visibility"] != "private" || pc["me"].(map[string]any)["share_progress"] != false {
		t.Fatalf("private challenge = %v", pc)
	}
	a.c.Do(t, http.MethodPost, "/challenges/"+pid+"/progress", map[string]any{}).Expect(t, http.StatusOK)
	got := a.c.Do(t, http.MethodPost, "/challenges/"+pid+"/progress", map[string]any{"date": today.AddDate(0, 0, -1).Format(day)}).Expect(t, http.StatusOK).Data()
	if me := got["me"].(map[string]any); me["progress_value"].(float64) != 2 || me["current_streak"].(float64) != 2 || me["percent_complete"].(float64) != 66 {
		t.Fatalf("after two check-ins = %v", me)
	}
	if r := a.c.Do(t, http.MethodPost, "/challenges/"+pid+"/progress", map[string]any{"date": today.AddDate(0, 0, 1).Format(day)}); r.ErrorCode() != "VALIDATION_ERROR" {
		t.Fatalf("future check-in: %s", r.Raw)
	}
	if r := a.c.Do(t, http.MethodPost, "/challenges/"+pid+"/progress", map[string]any{"date": today.AddDate(0, 0, -9).Format(day)}); r.ErrorCode() != "VALIDATION_ERROR" {
		t.Fatalf("check-in before the start: %s", r.Raw)
	}
	// Correcting a day replaces it (0 = missed).
	got = a.c.Do(t, http.MethodPost, "/challenges/"+pid+"/progress", map[string]any{"date": today.AddDate(0, 0, -1).Format(day), "value": 0}).Expect(t, http.StatusOK).Data()
	if me := got["me"].(map[string]any); me["progress_value"].(float64) != 1 {
		t.Fatalf("after correction = %v", me)
	}
	if r := c.c.Do(t, http.MethodGet, "/challenges/"+pid, nil); r.Status != http.StatusNotFound {
		t.Fatalf("outsider reading a private challenge: %d", r.Status)
	}
	if r := a.c.Do(t, http.MethodPost, "/challenges", map[string]any{"title": "Everyone", "challenge_type": "custom", "metric": "days", "target_value": 5,
		"visibility": "public", "starts_on": today.Format(day), "ends_on": today.AddDate(0, 0, 9).Format(day)}); r.ErrorCode() != "VALIDATION_ERROR" {
		t.Fatalf("user-created public challenge: %s", r.Raw)
	}
	if r := a.c.Do(t, http.MethodPost, "/challenges", map[string]any{"title": "Trip fund", "challenge_type": "travel_savings", "metric": "percent", "target_value": 150,
		"starts_on": today.Format(day), "ends_on": today.AddDate(0, 0, 9).Format(day)}); r.ErrorCode() != "VALIDATION_ERROR" {
		t.Fatalf("percent target over 100: %s", r.Raw)
	}

	// Group challenge with a consent-based leaderboard.
	gc := a.c.Do(t, http.MethodPost, "/challenges", map[string]any{"title": "Meal plan streak", "challenge_type": "meal_planning", "metric": "streak",
		"target_value": 2, "group_id": gid, "leaderboard_enabled": true, "starts_on": today.AddDate(0, 0, -3).Format(day), "ends_on": today.AddDate(0, 0, 10).Format(day)}).
		Expect(t, http.StatusCreated).Data()
	gcid := gc["id"].(string)
	if g, _ := gc["group"].(map[string]any); g == nil || g["id"] != gid || g["name"] != "Savers" {
		t.Fatalf("group ref = %v", gc["group"])
	}
	if l := b.c.Do(t, http.MethodGet, "/challenges?scope=discover", nil).Expect(t, http.StatusOK).List(); len(l) != 1 || l[0].(map[string]any)["id"] != gcid {
		t.Fatalf("discover = %v", l)
	}
	// "Mine" (also the default scope) lists what you created or joined.
	for _, path := range []string{"/challenges?scope=mine", "/challenges"} {
		mine := a.c.Do(t, http.MethodGet, path, nil).Expect(t, http.StatusOK).List()
		found := false
		for _, x := range mine {
			found = found || x.(map[string]any)["id"] == gcid
		}
		if !found {
			t.Fatalf("%s did not list the creator's challenge: %v", path, mine)
		}
	}
	if r := c.c.Do(t, http.MethodPost, "/challenges/"+gcid+"/join", map[string]any{}); r.Status != http.StatusNotFound {
		t.Fatalf("outsider joining a group challenge: %d", r.Status)
	}
	if r := b.c.Do(t, http.MethodPost, "/challenges/"+gcid+"/join", map[string]any{"show_on_leaderboard": true}); r.ErrorCode() != "VALIDATION_ERROR" {
		t.Fatalf("leaderboard without sharing: %s", r.Raw)
	}
	b.c.Do(t, http.MethodPost, "/challenges/"+gcid+"/join", map[string]any{"share_progress": true, "show_on_leaderboard": true}).Expect(t, http.StatusOK)
	b.c.Do(t, http.MethodPost, "/challenges/"+gcid+"/progress", map[string]any{"date": today.AddDate(0, 0, -1).Format(day)}).Expect(t, http.StatusOK)
	a.c.Do(t, http.MethodPost, "/challenges/"+gcid+"/progress", map[string]any{}).Expect(t, http.StatusOK)
	// Seeing the leaderboard is mutual: the creator has not opted in yet.
	if r := a.c.Do(t, http.MethodGet, "/challenges/"+gcid+"/leaderboard", nil); r.ErrorCode() != "DOMAIN_RULE_VIOLATION" || detail(t, r)["code"] != "leaderboard_opt_in_required" {
		t.Fatalf("leaderboard before the creator opts in: %s", r.Raw)
	}
	if r := c.c.Do(t, http.MethodGet, "/challenges/"+gcid+"/leaderboard", nil); r.Status != http.StatusNotFound {
		t.Fatalf("outsider reading the leaderboard: %d", r.Status)
	}
	lb := b.c.Do(t, http.MethodGet, "/challenges/"+gcid+"/leaderboard", nil).Expect(t, http.StatusOK).List()
	if len(lb) != 1 || lb[0].(map[string]any)["display_name"] != "Test buddy" || lb[0].(map[string]any)["percent_complete"].(float64) != 50 {
		t.Fatalf("leaderboard seen by an opted-in participant = %v", lb)
	}
	for k := range lb[0].(map[string]any) {
		if k == "progress_value" || k == "note" || k == "user_id" {
			t.Fatalf("leaderboard exposes %q", k)
		}
	}
	a.c.Do(t, http.MethodPatch, "/challenges/"+gcid+"/participation", map[string]any{"share_progress": true, "show_on_leaderboard": true}).Expect(t, http.StatusOK)
	done := b.c.Do(t, http.MethodPost, "/challenges/"+gcid+"/progress", map[string]any{}).Expect(t, http.StatusOK).Data()
	if done["me"].(map[string]any)["status"] != "completed" {
		t.Fatalf("two-day streak target = %v", done["me"])
	}
	lb = b.c.Do(t, http.MethodGet, "/challenges/"+gcid+"/leaderboard", nil).Expect(t, http.StatusOK).List()
	if len(lb) != 2 || lb[0].(map[string]any)["display_name"] != "Test buddy" || lb[0].(map[string]any)["completed"] != true || lb[0].(map[string]any)["is_me"] != true {
		t.Fatalf("leaderboard = %v", lb)
	}
	s.RunJobs(t)
	if n := notificationsOf(t, b.c, "challenge", "challenge_completed"); n != 1 {
		t.Fatalf("completion notifications = %d", n)
	}
	b.c.Do(t, http.MethodPost, "/challenges/"+gcid+"/leave", nil).Expect(t, http.StatusOK)
	if lb = a.c.Do(t, http.MethodGet, "/challenges/"+gcid+"/leaderboard", nil).Expect(t, http.StatusOK).List(); len(lb) != 1 {
		t.Fatalf("leaving removes you from the leaderboard: %v", lb)
	}
	if r := b.c.Do(t, http.MethodPost, "/challenges/"+gcid+"/cancel", nil); r.Status != http.StatusForbidden {
		t.Fatalf("participant cancelling: %d", r.Status)
	}
	if st := a.c.Do(t, http.MethodPost, "/challenges/"+gcid+"/cancel", nil).Expect(t, http.StatusOK).Data()["status"]; st != "cancelled" {
		t.Fatalf("cancel = %v", st)
	}
}

func todayIn(t *testing.T, zone string) time.Time {
	t.Helper()
	loc, err := time.LoadLocation(zone)
	if err != nil {
		t.Fatal(err)
	}
	n := time.Now().In(loc)
	return time.Date(n.Year(), n.Month(), n.Day(), 0, 0, 0, 0, time.UTC)
}

// @mentions notify mentioned members only: never non-members, blocked or
// muting people, the author, or people already told about a comment.
func TestCommunityMentions(t *testing.T) {
	s := apitest.New(t, nil)
	author := newPerson(t, s, "author", nil)
	friend := newPerson(t, s, "friend", nil)
	outsider := newPerson(t, s, "outsider", nil)
	blocker := newPerson(t, s, "blocker", nil)
	muter := newPerson(t, s, "muter", nil)
	seasoned(t, s, author)
	cid := createCommunity(t, author, map[string]any{"name": "Frugal Folks"})["id"].(string)
	for _, p := range []person{friend, blocker, muter} {
		p.c.Do(t, http.MethodPost, "/communities/"+cid+"/join", nil).Expect(t, http.StatusOK)
	}
	blocker.c.Do(t, http.MethodPost, "/users/"+author.id+"/block", nil).Expect(t, http.StatusOK)
	muter.c.Do(t, http.MethodPost, "/users/"+author.id+"/mute", map[string]any{"muted": true}).Expect(t, http.StatusOK)

	p := post(t, author, cid, map[string]any{"title": "Budget wins", "body": "Shout-out to @" + friend.user + ", @" + outsider.user +
		", @" + blocker.user + ", @" + muter.user + " and myself @" + author.user})
	s.RunJobs(t)
	for who, want := range map[string]int{"friend": 1, "outsider": 0, "blocker": 0, "muter": 0, "author": 0} {
		c := map[string]person{"friend": friend, "outsider": outsider, "blocker": blocker, "muter": muter, "author": author}[who]
		if got := notificationsOf(t, c.c, "community", "mention"); got != want {
			t.Fatalf("%s mention notifications: %d, want %d", who, got, want)
		}
	}
	// A comment mentioning the post author tells them once (as the comment).
	friend.c.Do(t, http.MethodPost, "/posts/"+p["id"].(string)+"/comments", map[string]any{"body": "Great work @" + author.user}).
		Expect(t, http.StatusCreated)
	s.RunJobs(t)
	if got := notificationsOf(t, author.c, "community", "mention"); got != 0 {
		t.Fatalf("post author double-notified: %d", got)
	}
	if got := notificationsOf(t, author.c, "community", "comment_on_post"); got != 1 {
		t.Fatalf("comment notification: %d", got)
	}
}

// Challenges encourage once at halfway (never again, never after
// completing) and congratulate on completion.
func TestChallengeHalfwayMilestone(t *testing.T) {
	s := apitest.New(t, nil)
	a := newPerson(t, s, "saver", nil)
	today := todayIn(t, "Asia/Kolkata")
	c := a.c.Do(t, http.MethodPost, "/challenges", map[string]any{"title": "Cook at home", "challenge_type": "custom", "metric": "days",
		"target_value": 4, "starts_on": today.AddDate(0, 0, -6).Format(day), "ends_on": today.Format(day)}).Expect(t, http.StatusCreated).Data()
	id := c["id"].(string)
	check := func(daysAgo int) {
		a.c.Do(t, http.MethodPost, "/challenges/"+id+"/progress", map[string]any{"date": today.AddDate(0, 0, -daysAgo).Format(day)}).Expect(t, http.StatusOK)
		s.RunJobs(t)
	}
	check(5) // 25%
	if got := notificationsOf(t, a.c, "challenge", "challenge_milestone"); got != 0 {
		t.Fatalf("milestone too early: %d", got)
	}
	check(4) // 50%
	check(3) // 75%: no second notice
	if got := notificationsOf(t, a.c, "challenge", "challenge_milestone"); got != 1 {
		t.Fatalf("halfway notices: %d", got)
	}
	check(2) // 100%
	if got := notificationsOf(t, a.c, "challenge", "challenge_completed"); got != 1 {
		t.Fatalf("completion notices: %d", got)
	}
}
