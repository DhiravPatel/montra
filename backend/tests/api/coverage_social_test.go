package api_test

import (
	"net/http"
	"slices"
	"testing"

	"montra/backend/internal/testutil/apitest"
)

// Coverage for social endpoints no other API test exercised: comment edit,
// delete and reactions, community archive/restore, ownership transfer and
// join-request rejection, friend-request decline and the staff appeal queue.

func TestCoverageCommentEditDeleteAndReactions(t *testing.T) {
	s := apitest.New(t, nil)
	o := newPerson(t, s, "cvcmowner", nil)
	a := newPerson(t, s, "cvcmauthor", nil)
	r := newPerson(t, s, "cvcmreactor", nil)
	v := newPerson(t, s, "cvcmvisitor", nil)
	cid := createCommunity(t, o, map[string]any{"name": "Frugal Cooks"})["id"].(string)
	for _, p := range []person{a, r} {
		p.c.Do(t, http.MethodPost, "/communities/"+cid+"/join", nil).Expect(t, http.StatusOK)
	}
	pid := post(t, o, cid, map[string]any{"title": "Cheap dinners"})["id"].(string)
	cm := a.c.Do(t, http.MethodPost, "/posts/"+pid+"/comments", map[string]any{"body": "Dal and rice"}).Expect(t, http.StatusCreated).Data()
	cmid := cm["id"].(string)
	reply := r.c.Do(t, http.MethodPost, "/posts/"+pid+"/comments", map[string]any{"body": "Agreed", "parent_comment_id": cmid}).Expect(t, http.StatusCreated).Data()

	// Edit: author only; text is cleaned and validated; edited_at is set.
	ed := a.c.Do(t, http.MethodPatch, "/comments/"+cmid, map[string]any{"body": "  Dal, rice and pickle\u202e "}).Expect(t, http.StatusOK).Data()
	if ed["id"] != cmid || ed["body"] != "Dal, rice and pickle" || ed["edited_at"] == nil || ed["mine"] != true || ed["status"] != "published" {
		t.Fatalf("edited comment = %v", ed)
	}
	if res := o.c.Do(t, http.MethodPatch, "/comments/"+cmid, map[string]any{"body": "Moderated"}); res.Status != http.StatusForbidden {
		t.Fatalf("owner editing someone else's comment: %d %s", res.Status, res.Raw)
	}
	gfField(t, a.c.Do(t, http.MethodPatch, "/comments/"+cmid, map[string]any{"body": "   "}), "body.body")
	a.c.Do(t, http.MethodPatch, "/comments/"+key(), map[string]any{"body": "x"}).Expect(t, http.StatusNotFound)

	// Reactions on a comment: idempotent add, counts and the caller's own.
	r.c.Do(t, http.MethodPost, "/comments/"+cmid+"/reactions", map[string]any{"kind": "helpful"}).Expect(t, http.StatusOK)
	r.c.Do(t, http.MethodPost, "/comments/"+cmid+"/reactions", map[string]any{"kind": "helpful"}).Expect(t, http.StatusOK)
	rc := r.c.Do(t, http.MethodPost, "/comments/"+cmid+"/reactions", map[string]any{"kind": "like"}).Expect(t, http.StatusOK).Data()
	if rc["helpful"] != float64(1) || rc["like"] != float64(1) || !slices.Equal(strList(rc["my_reactions"]), []string{"helpful", "like"}) {
		t.Fatalf("comment reactions = %v", rc)
	}
	oc := o.c.Do(t, http.MethodPost, "/comments/"+cmid+"/reactions", map[string]any{"kind": "like"}).Expect(t, http.StatusOK).Data()
	if oc["like"] != float64(2) || !slices.Equal(strList(oc["my_reactions"]), []string{"like"}) {
		t.Fatalf("second reactor's view = %v", oc)
	}
	gfField(t, r.c.Do(t, http.MethodPost, "/comments/"+cmid+"/reactions", map[string]any{"kind": "love"}), "body.kind")
	// Non-members of a public community can read but not react.
	gfCoded(t, v.c.Do(t, http.MethodPost, "/comments/"+cmid+"/reactions", map[string]any{"kind": "like"}), http.StatusUnprocessableEntity,
		"DOMAIN_RULE_VIOLATION", "join_community_first")
	detail := a.c.Do(t, http.MethodGet, "/posts/"+pid, nil).Expect(t, http.StatusOK).Data()
	c0 := gfFind(detail["comments"].([]any), "id", cmid)
	if c0["reactions"].(map[string]any)["like"] != float64(2) || len(c0["my_reactions"].([]any)) != 0 {
		t.Fatalf("comment in post detail = %v", c0)
	}
	// Remove: only the caller's own reaction goes; removing again is a no-op.
	rm := r.c.Do(t, http.MethodDelete, "/comments/"+cmid+"/reactions/like", nil).Expect(t, http.StatusOK).Data()
	if rm["like"] != float64(1) || rm["helpful"] != float64(1) || !slices.Equal(strList(rm["my_reactions"]), []string{"helpful"}) {
		t.Fatalf("after removing a reaction = %v", rm)
	}
	if again := r.c.Do(t, http.MethodDelete, "/comments/"+cmid+"/reactions/like", nil).Expect(t, http.StatusOK).Data(); again["like"] != float64(1) {
		t.Fatalf("removing twice = %v", again)
	}
	if res := r.c.Do(t, http.MethodDelete, "/comments/"+cmid+"/reactions/love", nil); res.Status != http.StatusUnprocessableEntity {
		t.Fatalf("removing an unknown kind: %d", res.Status)
	}
	r.c.Do(t, http.MethodDelete, "/comments/"+key()+"/reactions/like", nil).Expect(t, http.StatusNotFound)

	// Delete: author only; the comment is kept as deleted (no text), replies stay.
	if res := r.c.Do(t, http.MethodDelete, "/comments/"+cmid, nil); res.Status != http.StatusForbidden {
		t.Fatalf("deleting someone else's comment: %d", res.Status)
	}
	a.c.Do(t, http.MethodDelete, "/comments/"+cmid, nil).Expect(t, http.StatusOK)
	detail = o.c.Do(t, http.MethodGet, "/posts/"+pid, nil).Expect(t, http.StatusOK).Data()
	d0 := gfFind(detail["comments"].([]any), "id", cmid)
	if d0 == nil || d0["status"] != "deleted" || d0["body"] != "" || gfFind(detail["comments"].([]any), "id", reply["id"].(string))["status"] != "published" {
		t.Fatalf("comments after delete = %v", detail["comments"])
	}
	// Deleted comments can be neither edited, deleted again nor reacted to.
	gfCoded(t, a.c.Do(t, http.MethodPatch, "/comments/"+cmid, map[string]any{"body": "Back"}), http.StatusUnprocessableEntity, "DOMAIN_RULE_VIOLATION", "comment_locked")
	gfCoded(t, a.c.Do(t, http.MethodDelete, "/comments/"+cmid, nil), http.StatusUnprocessableEntity, "DOMAIN_RULE_VIOLATION", "comment_locked")
	gfCoded(t, o.c.Do(t, http.MethodPost, "/comments/"+cmid+"/reactions", map[string]any{"kind": "support"}), http.StatusUnprocessableEntity,
		"DOMAIN_RULE_VIOLATION", "content_unavailable")

	// Archived communities are read-only: no edits or new reactions.
	o.c.Do(t, http.MethodPost, "/communities/"+cid+"/archive", nil).Expect(t, http.StatusOK)
	gfCoded(t, r.c.Do(t, http.MethodPatch, "/comments/"+reply["id"].(string), map[string]any{"body": "Edited"}), http.StatusUnprocessableEntity,
		"DOMAIN_RULE_VIOLATION", "not_accepting_posts")
	gfCoded(t, a.c.Do(t, http.MethodPost, "/comments/"+reply["id"].(string)+"/reactions", map[string]any{"kind": "like"}), http.StatusUnprocessableEntity,
		"DOMAIN_RULE_VIOLATION", "not_accepting_posts")
}

func TestCoverageCommunityArchiveRestoreAndOwnershipTransfer(t *testing.T) {
	s := apitest.New(t, nil)
	o := newPerson(t, s, "cvcoowner", nil)
	m := newPerson(t, s, "cvcomember", nil)
	md := newPerson(t, s, "cvcomod", nil)
	v := newPerson(t, s, "cvcovisitor", nil)
	c := createCommunity(t, o, map[string]any{"name": "Index Investors"})
	cid := c["id"].(string)
	for _, p := range []person{m, md} {
		p.c.Do(t, http.MethodPost, "/communities/"+cid+"/join", nil).Expect(t, http.StatusOK)
	}
	o.c.Do(t, http.MethodPatch, "/communities/"+cid+"/members/"+md.id, map[string]any{"role": "moderator"}).Expect(t, http.StatusOK)
	pid := post(t, m, cid, map[string]any{"title": "Nifty 50 or Next 50?"})["id"].(string)

	// Archive: owner only (moderators and outsiders are refused).
	for _, p := range []person{md, m, v} {
		if res := p.c.Do(t, http.MethodPost, "/communities/"+cid+"/archive", nil); res.Status != http.StatusForbidden {
			t.Fatalf("non-owner archiving: %d %s", res.Status, res.Raw)
		}
	}
	ar := o.c.Do(t, http.MethodPost, "/communities/"+cid+"/archive", nil).Expect(t, http.StatusOK).Data()
	if ar["status"] != "archived" || ar["version"].(float64) <= c["version"].(float64) {
		t.Fatalf("archived = %v", ar)
	}
	// Read-only: members still read; nobody posts or comments.
	m.c.Do(t, http.MethodGet, "/posts/"+pid, nil).Expect(t, http.StatusOK)
	m.c.Do(t, http.MethodGet, "/communities/"+cid+"/posts", nil).Expect(t, http.StatusOK)
	gfCoded(t, m.c.Do(t, http.MethodPost, "/communities/"+cid+"/posts", map[string]any{"title": "Still here?"}), http.StatusUnprocessableEntity,
		"DOMAIN_RULE_VIOLATION", "not_accepting_posts")
	gfCoded(t, o.c.Do(t, http.MethodPost, "/posts/"+pid+"/comments", map[string]any{"body": "Closed"}), http.StatusUnprocessableEntity,
		"DOMAIN_RULE_VIOLATION", "not_accepting_posts")
	// Restore: owner only, back to active and writable.
	if res := md.c.Do(t, http.MethodPost, "/communities/"+cid+"/restore", nil); res.Status != http.StatusForbidden {
		t.Fatalf("moderator restoring: %d", res.Status)
	}
	rs := o.c.Do(t, http.MethodPost, "/communities/"+cid+"/restore", nil).Expect(t, http.StatusOK).Data()
	if rs["status"] != "active" {
		t.Fatalf("restored = %v", rs)
	}
	m.c.Do(t, http.MethodPost, "/posts/"+pid+"/comments", map[string]any{"body": "Next 50"}).Expect(t, http.StatusCreated)
	for _, action := range []string{"archived", "active"} {
		if n := workerCount(t, s, `select count(*) from audit_events where entity_type = 'community' and entity_id = $1 and action = $2`, cid, action); n != 1 {
			t.Fatalf("%s audit rows = %d", action, n)
		}
	}
	// Suspended communities can only be restored by staff.
	s.Env.ExecWorker(t, `update communities set status = 'suspended' where id = $1`, cid)
	gfCoded(t, o.c.Do(t, http.MethodPost, "/communities/"+cid+"/restore", nil), http.StatusUnprocessableEntity, "DOMAIN_RULE_VIOLATION", "community_suspended")
	s.Env.ExecWorker(t, `update communities set status = 'active' where id = $1`, cid)

	// Ownership transfer: owner only, to another active member.
	if res := md.c.Do(t, http.MethodPost, "/communities/"+cid+"/transfer-ownership", map[string]any{"user_id": md.id}); res.Status != http.StatusForbidden {
		t.Fatalf("moderator transferring: %d", res.Status)
	}
	if res := o.c.Do(t, http.MethodPost, "/communities/"+cid+"/transfer-ownership", map[string]any{"user_id": o.id}); res.Status != http.StatusUnprocessableEntity ||
		detail(t, res)["field"] != "body.user_id" || detail(t, res)["code"] != "self_not_allowed" {
		t.Fatalf("transfer to self: %d %s", res.Status, res.Raw)
	}
	o.c.Do(t, http.MethodPost, "/communities/"+cid+"/transfer-ownership", map[string]any{"user_id": v.id}).Expect(t, http.StatusNotFound)
	tr := o.c.Do(t, http.MethodPost, "/communities/"+cid+"/transfer-ownership", map[string]any{"user_id": m.id}).Expect(t, http.StatusOK).Data()
	if tr["my_role"] != "moderator" {
		t.Fatalf("previous owner's role after transfer = %v", tr["my_role"])
	}
	if got := m.c.Do(t, http.MethodGet, "/communities/"+cid, nil).Expect(t, http.StatusOK).Data(); got["my_role"] != "owner" {
		t.Fatalf("new owner's view = %v", got["my_role"])
	}
	// Owner powers move with it.
	if res := o.c.Do(t, http.MethodPost, "/communities/"+cid+"/archive", nil); res.Status != http.StatusForbidden {
		t.Fatalf("previous owner archiving: %d", res.Status)
	}
	m.c.Do(t, http.MethodPost, "/communities/"+cid+"/archive", nil).Expect(t, http.StatusOK)
	m.c.Do(t, http.MethodPost, "/communities/"+cid+"/restore", nil).Expect(t, http.StatusOK)
	// The new owner cannot leave without handing it on; the previous one can.
	gfCoded(t, m.c.Do(t, http.MethodPost, "/communities/"+cid+"/leave", nil), http.StatusUnprocessableEntity, "DOMAIN_RULE_VIOLATION", "transfer_ownership_first")
	var owners int
	for _, x := range m.c.Do(t, http.MethodGet, "/communities/"+cid+"/members", nil).Expect(t, http.StatusOK).List() {
		if x.(map[string]any)["role"] == "owner" {
			owners++
			if x.(map[string]any)["user_id"] != m.id {
				t.Fatalf("owner listed = %v", x)
			}
		}
	}
	if owners != 1 {
		t.Fatalf("owners after transfer = %d", owners)
	}
	o.c.Do(t, http.MethodPost, "/communities/"+cid+"/leave", nil).Expect(t, http.StatusOK)
	if n := workerCount(t, s, `select count(*) from audit_events where entity_type = 'community' and entity_id = $1 and action = 'ownership_transferred'
		and actor_user_id = $2 and user_id = $3`, cid, o.id, m.id); n != 1 {
		t.Fatalf("transfer audit rows = %d", n)
	}
}

func TestCoverageCommunityJoinRequestRejectAndFriendDecline(t *testing.T) {
	s := apitest.New(t, nil)
	host := newPerson(t, s, "cvcrhost", nil)
	md := newPerson(t, s, "cvcrmod", nil)
	mem := newPerson(t, s, "cvcrmember", nil)
	j := newPerson(t, s, "cvcrjoiner", nil)
	priv := createCommunity(t, host, map[string]any{"name": "Salary Talk", "visibility": "private"})["id"].(string)
	for _, p := range []person{md, mem} {
		p.c.Do(t, http.MethodPost, "/communities/"+priv+"/join", nil).Expect(t, http.StatusOK)
		host.c.Do(t, http.MethodPost, "/communities/"+priv+"/members/"+p.id+"/approve", nil).Expect(t, http.StatusOK)
	}
	host.c.Do(t, http.MethodPatch, "/communities/"+priv+"/members/"+md.id, map[string]any{"role": "moderator"}).Expect(t, http.StatusOK)
	if got := j.c.Do(t, http.MethodPost, "/communities/"+priv+"/join", nil).Expect(t, http.StatusOK).Data(); got["my_status"] != "pending" {
		t.Fatalf("join request = %v", got)
	}
	// Moderators decide; plain members and the requester cannot.
	if res := mem.c.Do(t, http.MethodPost, "/communities/"+priv+"/members/"+j.id+"/reject", nil); res.Status != http.StatusForbidden {
		t.Fatalf("member rejecting: %d %s", res.Status, res.Raw)
	}
	if res := j.c.Do(t, http.MethodPost, "/communities/"+priv+"/members/"+j.id+"/reject", nil); res.Status != http.StatusForbidden {
		t.Fatalf("requester rejecting themselves: %d %s", res.Status, res.Raw)
	}
	md.c.Do(t, http.MethodPost, "/communities/"+priv+"/members/"+j.id+"/reject", nil).Expect(t, http.StatusOK)
	// Not a member, nothing pending; deciding again is not found.
	if got := j.c.Do(t, http.MethodGet, "/communities/"+priv, nil).Expect(t, http.StatusOK).Data(); got["my_status"] == "active" || got["my_status"] == "pending" {
		t.Fatalf("rejected requester's status = %v", got["my_status"])
	}
	if res := j.c.Do(t, http.MethodGet, "/communities/"+priv+"/posts", nil); res.Status != http.StatusForbidden {
		t.Fatalf("rejected requester reading posts: %d", res.Status)
	}
	if l := host.c.Do(t, http.MethodGet, "/communities/"+priv+"/members?status=pending", nil).Expect(t, http.StatusOK).List(); len(l) != 0 {
		t.Fatalf("pending after reject = %v", l)
	}
	md.c.Do(t, http.MethodPost, "/communities/"+priv+"/members/"+j.id+"/reject", nil).Expect(t, http.StatusNotFound)
	host.c.Do(t, http.MethodPost, "/communities/"+priv+"/members/"+j.id+"/approve", nil).Expect(t, http.StatusNotFound)
	md.c.Do(t, http.MethodPost, "/communities/"+priv+"/members/"+mem.id+"/reject", nil).Expect(t, http.StatusNotFound) // already active
	// Side effects: a moderation log entry, an audit row and a notice.
	if n := workerCount(t, s, `select count(*) from moderation_actions where community_id = $1 and target_user_id = $2 and action = 'reject_member'
		and moderator_id = $3`, priv, j.id, md.id); n != 1 {
		t.Fatalf("moderation log rows = %d", n)
	}
	if n := workerCount(t, s, `select count(*) from audit_events where entity_type = 'community_member' and entity_id = $1 and action = 'reject_member'
		and user_id = $2`, priv, j.id); n != 1 {
		t.Fatalf("reject audit rows = %d", n)
	}
	s.RunJobs(t)
	var declined bool
	for _, x := range j.c.Do(t, http.MethodGet, "/notifications?category=community", nil).Expect(t, http.StatusOK).List() {
		n := x.(map[string]any)
		if n["event_type"] == "community_membership" && n["entity_id"] == priv {
			declined = n["title"] == "Your request to join Salary Talk was declined"
		}
	}
	if !declined {
		t.Fatal("the requester was not told the request was declined")
	}
	// They may ask again.
	if got := j.c.Do(t, http.MethodPost, "/communities/"+priv+"/join", nil).Expect(t, http.StatusOK).Data(); got["my_status"] != "pending" {
		t.Fatalf("second join request = %v", got)
	}

	// Friend request decline: only the addressee, only while pending.
	a := newPerson(t, s, "cvfrfrom", nil)
	b := newPerson(t, s, "cvfrto", nil)
	fr := a.c.Do(t, http.MethodPost, "/friend-requests", map[string]any{"username": b.user}).Expect(t, http.StatusCreated).Data()
	fid := fr["id"].(string)
	a.c.Do(t, http.MethodPost, "/friend-requests/"+fid+"/decline", nil).Expect(t, http.StatusNotFound) // the requester cancels instead
	j.c.Do(t, http.MethodPost, "/friend-requests/"+fid+"/decline", nil).Expect(t, http.StatusNotFound)
	dec := b.c.Do(t, http.MethodPost, "/friend-requests/"+fid+"/decline", nil).Expect(t, http.StatusOK).Data()
	if dec["status"] != "declined" || dec["id"] != fid {
		t.Fatalf("declined request = %v", dec)
	}
	b.c.Do(t, http.MethodPost, "/friend-requests/"+fid+"/decline", nil).Expect(t, http.StatusNotFound)
	b.c.Do(t, http.MethodPost, "/friend-requests/"+fid+"/accept", nil).Expect(t, http.StatusNotFound)
	for _, p := range []person{a, b} {
		if l := p.c.Do(t, http.MethodGet, "/friend-requests", nil).Expect(t, http.StatusOK).List(); len(l) != 0 {
			t.Fatalf("pending requests after decline = %v", l)
		}
		if l := p.c.Do(t, http.MethodGet, "/connections", nil).Expect(t, http.StatusOK).List(); len(l) != 0 {
			t.Fatalf("connections after decline = %v", l)
		}
	}
	// A declined request does not block a later one.
	again := a.c.Do(t, http.MethodPost, "/friend-requests", map[string]any{"user_id": b.id}).Expect(t, http.StatusCreated).Data()
	if again["id"] == fid || again["status"] != "pending" {
		t.Fatalf("new request after decline = %v", again)
	}
}

func TestCoverageStaffAppealQueue(t *testing.T) {
	s := apitest.New(t, nil)
	o1 := newPerson(t, s, "cvapowner1", nil)
	o2 := newPerson(t, s, "cvapowner2", nil)
	a := newPerson(t, s, "cvapauthor", nil)
	staff := newPerson(t, s, "cvapstaff", nil)
	s.Env.ExecWorker(t, `update users set platform_role = 'support' where id = $1`, staff.id)
	appealIn := func(owner person, name string) (string, string) {
		cid := createCommunity(t, owner, map[string]any{"name": name})["id"].(string)
		a.c.Do(t, http.MethodPost, "/communities/"+cid+"/join", nil).Expect(t, http.StatusOK)
		pid := post(t, a, cid, map[string]any{"title": "Off topic " + name})["id"].(string)
		act := owner.c.Do(t, http.MethodPost, "/communities/"+cid+"/moderation/actions", map[string]any{"action": "remove", "target_type": "post",
			"target_id": pid, "reason": "Off topic"}).Expect(t, http.StatusOK).Data()
		ap := a.c.Do(t, http.MethodPost, "/moderation/actions/"+act["id"].(string)+"/appeals", map[string]any{"statement": "It was on topic"}).
			Expect(t, http.StatusCreated).Data()
		return cid, ap["id"].(string)
	}
	c1, ap1 := appealIn(o1, "Budget Travel")
	_, ap2 := appealIn(o2, "Credit Cards")

	// Staff see every open appeal across communities, oldest first.
	l := staff.c.Do(t, http.MethodGet, "/moderation/appeals", nil).Expect(t, http.StatusOK).List()
	if got := ids(l, "id"); !slices.Equal(got, []string{ap1, ap2}) {
		t.Fatalf("staff appeal queue = %v", got)
	}
	first := l[0].(map[string]any)
	if first["status"] != "open" || first["statement"] != "It was on topic" || first["community_id"] != c1 ||
		first["action"].(map[string]any)["moderator_id"] != o1.id || first["action"].(map[string]any)["target_user_id"] != a.id {
		t.Fatalf("staff appeal view = %v", first)
	}
	// Everyone else is refused, including community owners and the appellant.
	for _, p := range []person{o1, a} {
		if res := p.c.Do(t, http.MethodGet, "/moderation/appeals", nil); res.Status != http.StatusForbidden || res.ErrorCode() != "FORBIDDEN" {
			t.Fatalf("non-staff reading the platform queue: %d %s", res.Status, res.Raw)
		}
	}
	// Decided appeals leave the queue.
	staff.c.Do(t, http.MethodPost, "/moderation/appeals/"+ap1+"/decide", map[string]any{"decision": "overturned", "note": "Relevant"}).Expect(t, http.StatusOK)
	if got := ids(staff.c.Do(t, http.MethodGet, "/moderation/appeals", nil).Expect(t, http.StatusOK).List(), "id"); !slices.Equal(got, []string{ap2}) {
		t.Fatalf("queue after a decision = %v", got)
	}
}
