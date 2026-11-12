// Package rls_test verifies PostgreSQL row-level security as defense in
// depth (spec §3, §9): every table has RLS, users are isolated, group
// membership never exposes personal records, and append-only tables cannot
// be modified by the API role.
package rls_test

import (
	"context"
	"errors"
	"testing"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgconn"

	"montra/backend/internal/testutil/dbtest"
)

func countAsUser(t *testing.T, env *dbtest.Env, user uuid.UUID, sql string, args ...any) int {
	t.Helper()
	var n int
	ctx := context.Background()
	err := env.App.WithUserTx(ctx, user, func(tx pgx.Tx) error {
		return tx.QueryRow(ctx, sql, args...).Scan(&n)
	})
	if err != nil {
		t.Fatalf("query as user: %v", err)
	}
	return n
}

func execAsUser(env *dbtest.Env, user uuid.UUID, sql string, args ...any) (int64, error) {
	ctx := context.Background()
	var n int64
	err := env.App.WithUserTx(ctx, user, func(tx pgx.Tx) error {
		tag, err := tx.Exec(ctx, sql, args...)
		n = tag.RowsAffected()
		return err
	})
	return n, err
}

func pgCode(err error) string {
	var pe *pgconn.PgError
	if errors.As(err, &pe) {
		return pe.Code
	}
	return ""
}

func TestEveryTableHasRLSAndNoPublicAccess(t *testing.T) {
	env := dbtest.Setup(t)
	ctx := context.Background()
	err := env.Worker.WithSystemTx(ctx, func(tx pgx.Tx) error {
		rows, err := tx.Query(ctx, `select c.relname from pg_class c join pg_namespace n on n.oid = c.relnamespace
			where n.nspname = 'montra' and c.relkind = 'r' and not c.relrowsecurity and c.relname <> 'schema_migrations'`)
		if err != nil {
			return err
		}
		defer rows.Close()
		for rows.Next() {
			var name string
			_ = rows.Scan(&name)
			t.Errorf("table montra.%s does not have row level security enabled", name)
		}
		var publicGrants int
		if err := tx.QueryRow(ctx, `select count(*) from information_schema.role_table_grants
			where table_schema = 'montra' and grantee = 'PUBLIC'`).Scan(&publicGrants); err != nil {
			return err
		}
		if publicGrants != 0 {
			t.Errorf("PUBLIC has %d table grants in schema montra", publicGrants)
		}
		return rows.Err()
	})
	if err != nil {
		t.Fatal(err)
	}
}

func TestOwnerIsolation(t *testing.T) {
	env := dbtest.Setup(t)
	a := env.CreateUser(t, "Owner A")
	b := env.CreateUser(t, "Owner B")
	acctB := uuid.New()
	env.ExecWorker(t, `insert into financial_accounts (id, user_id, name, account_type, currency, opening_date)
		values ($1, $2, 'B Savings', 'savings', 'INR', current_date)`, acctB, b.ID)

	if n := countAsUser(t, env, a.ID, `select count(*) from financial_accounts where id = $1`, acctB); n != 0 {
		t.Fatalf("user A can read user B's account (%d rows)", n)
	}
	if n := countAsUser(t, env, b.ID, `select count(*) from financial_accounts where id = $1`, acctB); n != 1 {
		t.Fatalf("owner cannot read own account (%d rows)", n)
	}
	if n, err := execAsUser(env, a.ID, `update financial_accounts set name = 'hijacked' where id = $1`, acctB); err != nil || n != 0 {
		t.Fatalf("user A update of B's account: rows=%d err=%v", n, err)
	}
	_, err := execAsUser(env, a.ID, `insert into financial_accounts (user_id, name, account_type, currency, opening_date)
		values ($1, 'forged', 'cash', 'INR', current_date)`, b.ID)
	if pgCode(err) != "42501" {
		t.Fatalf("inserting a row owned by another user must violate RLS (42501), got %v", err)
	}
	// Users table: own row only; never another user's email.
	if n := countAsUser(t, env, a.ID, `select count(*) from users where id = $1`, b.ID); n != 0 {
		t.Fatal("user A can read user B's users row")
	}
}

func TestNoIdentitySeesNothing(t *testing.T) {
	env := dbtest.Setup(t)
	u := env.CreateUser(t, "Anon Probe")
	env.ExecWorker(t, `insert into financial_accounts (user_id, name, account_type, currency, opening_date)
		values ($1, 'Cash', 'cash', 'INR', current_date)`, u.ID)
	ctx := context.Background()
	for _, table := range []string{"users", "financial_accounts", "user_preferences", "user_sessions", "notifications", "profiles"} {
		var n int
		if err := env.App.WithAnonTx(ctx, func(tx pgx.Tx) error {
			return tx.QueryRow(ctx, `select count(*) from `+pgx.Identifier{table}.Sanitize()).Scan(&n)
		}); err != nil {
			t.Fatal(err)
		}
		if n != 0 {
			t.Errorf("unauthenticated context sees %d rows in %s", n, table)
		}
	}
}

func TestGroupMembershipBoundaries(t *testing.T) {
	env := dbtest.Setup(t)
	a := env.CreateUser(t, "Group A")
	b := env.CreateUser(t, "Group B")
	c := env.CreateUser(t, "Outsider C")
	g := uuid.New()
	env.ExecWorker(t, `insert into groups (id, created_by, name, group_type, base_currency, timezone) values ($1,$2,'Flat','roommates','INR','Asia/Kolkata')`, g, a.ID)
	env.ExecWorker(t, `insert into group_members (group_id, user_id, role) values ($1,$2,'owner'),($1,$3,'member')`, g, a.ID, b.ID)
	exp := uuid.New()
	env.ExecWorker(t, `insert into group_expenses (id, group_id, created_by, description, amount_minor, currency, expense_date, split_method, split_input)
		values ($1,$2,$3,'Groceries',30000,'INR',current_date,'equal','{}')`, exp, g, a.ID)
	// A's private personal account must stay invisible to co-member B.
	acctA := uuid.New()
	env.ExecWorker(t, `insert into financial_accounts (id, user_id, name, account_type, currency, opening_date) values ($1,$2,'A Private','bank','INR',current_date)`, acctA, a.ID)

	if n := countAsUser(t, env, b.ID, `select count(*) from group_expenses where id = $1`, exp); n != 1 {
		t.Fatalf("member B cannot see group expense (%d)", n)
	}
	if n := countAsUser(t, env, c.ID, `select count(*) from group_expenses where id = $1`, exp); n != 0 {
		t.Fatalf("outsider C can see group expense (%d)", n)
	}
	if n := countAsUser(t, env, b.ID, `select count(*) from financial_accounts where id = $1`, acctA); n != 0 {
		t.Fatal("group membership exposed a personal account")
	}
	// Outsider cannot write into the group.
	_, err := execAsUser(env, c.ID, `insert into group_expenses (group_id, created_by, description, amount_minor, currency, expense_date, split_method, split_input)
		values ($1,$2,'x',100,'INR',current_date,'equal','{}')`, g, c.ID)
	if pgCode(err) != "42501" {
		t.Fatalf("outsider insert into group must be denied, got %v", err)
	}
	// Outsider cannot add themselves without a validated invitation.
	_, err = execAsUser(env, c.ID, `insert into group_members (group_id, user_id, role) values ($1,$2,'member')`, g, c.ID)
	if pgCode(err) != "42501" {
		t.Fatalf("self-join without invitation must be denied, got %v", err)
	}
	// Removed member loses access.
	env.ExecWorker(t, `update group_members set status = 'removed' where group_id = $1 and user_id = $2`, g, b.ID)
	if n := countAsUser(t, env, b.ID, `select count(*) from group_expenses where id = $1`, exp); n != 0 {
		t.Fatal("removed member can still read group expenses")
	}
}

func TestHouseholdSharedAccountIsReadOnlyForMembers(t *testing.T) {
	env := dbtest.Setup(t)
	a := env.CreateUser(t, "House A")
	b := env.CreateUser(t, "House B")
	g := uuid.New()
	env.ExecWorker(t, `insert into groups (id, created_by, name, group_type, base_currency, timezone) values ($1,$2,'Home','household','INR','Asia/Kolkata')`, g, a.ID)
	env.ExecWorker(t, `insert into group_members (group_id, user_id, role) values ($1,$2,'owner'),($1,$3,'member')`, g, a.ID, b.ID)
	acct := uuid.New()
	env.ExecWorker(t, `insert into financial_accounts (id, user_id, group_id, shared_with_group, name, account_type, currency, opening_date)
		values ($1,$2,$3,true,'Household pot','household_ledger','INR',current_date)`, acct, a.ID, g)
	if n := countAsUser(t, env, b.ID, `select count(*) from financial_accounts where id = $1`, acct); n != 1 {
		t.Fatal("member cannot see explicitly shared household account")
	}
	if n, err := execAsUser(env, b.ID, `update financial_accounts set name = 'mine' where id = $1`, acct); err != nil || n != 0 {
		t.Fatalf("member must not modify shared account: rows=%d err=%v", n, err)
	}
	// Transactions in the shared account are readable; a personal record
	// that merely carries the group (as group-linked records do) is not.
	personal := uuid.New()
	env.ExecWorker(t, `insert into financial_accounts (id, user_id, name, account_type, currency, opening_date)
		values ($1,$2,'Personal','bank','INR',current_date)`, personal, a.ID)
	shared, linked := uuid.New(), uuid.New()
	env.ExecWorker(t, `insert into transactions (id, user_id, account_id, group_id, type, direction, amount_minor, currency, occurred_at, local_date, timezone)
		values ($1,$2,$3,$4,'expense','outflow',100,'INR',now(),current_date,'Asia/Kolkata'),
		       ($5,$2,$6,$4,'expense','outflow',200,'INR',now(),current_date,'Asia/Kolkata')`, shared, a.ID, acct, g, linked, personal)
	if n := countAsUser(t, env, b.ID, `select count(*) from transactions where id = $1`, shared); n != 1 {
		t.Fatal("member cannot read a transaction in the shared household account")
	}
	if n := countAsUser(t, env, b.ID, `select count(*) from transactions where id = $1`, linked); n != 0 {
		t.Fatal("member can read another member's personal record that carries the group")
	}
	if n := countAsUser(t, env, a.ID, `select count(*) from transactions where id = any($1)`, []uuid.UUID{shared, linked}); n != 2 {
		t.Fatal("owner must read both")
	}
}

func TestAppendOnlyTables(t *testing.T) {
	env := dbtest.Setup(t)
	u := env.CreateUser(t, "Ledger")
	acct, tx := uuid.New(), uuid.New()
	env.ExecWorker(t, `insert into financial_accounts (id, user_id, name, account_type, currency, opening_date) values ($1,$2,'Cash','cash','INR',current_date)`, acct, u.ID)
	env.ExecWorker(t, `insert into transactions (id, user_id, account_id, type, direction, amount_minor, currency, occurred_at, local_date, timezone)
		values ($1,$2,$3,'expense','outflow',1000,'INR',now(),current_date,'Asia/Kolkata')`, tx, u.ID, acct)
	env.ExecWorker(t, `insert into account_ledger_entries (user_id, account_id, transaction_id, transaction_version, entry_kind, amount_minor, currency, effective_date)
		values ($1,$2,$3,1,'post',-1000,'INR',current_date)`, u.ID, acct, tx)
	env.ExecWorker(t, `insert into audit_events (user_id, actor_user_id, entity_type, action) values ($1,$1,'test','created')`, u.ID)

	for _, stmt := range []string{
		`update account_ledger_entries set amount_minor = 1 where user_id = $1`,
		`delete from account_ledger_entries where user_id = $1`,
		`update audit_events set action = 'x' where user_id = $1`,
		`delete from audit_events where user_id = $1`,
		`delete from transactions where user_id = $1`,
	} {
		if _, err := execAsUser(env, u.ID, stmt, u.ID); pgCode(err) != "42501" {
			t.Errorf("%q must be denied for montra_app, got %v", stmt, err)
		}
	}
}

func TestProfileVisibility(t *testing.T) {
	env := dbtest.Setup(t)
	a := env.CreateUser(t, "Private A")
	stranger := env.CreateUser(t, "Stranger")
	mate := env.CreateUser(t, "Mate")
	env.ExecWorker(t, `update profiles set profile_visibility = 'private' where user_id = $1`, a.ID)
	if n := countAsUser(t, env, stranger.ID, `select count(*) from profiles where user_id = $1`, a.ID); n != 0 {
		t.Fatal("stranger can see a private profile")
	}
	g := uuid.New()
	env.ExecWorker(t, `insert into groups (id, created_by, name, group_type, base_currency, timezone) values ($1,$2,'Trip','trip','INR','Asia/Kolkata')`, g, a.ID)
	env.ExecWorker(t, `insert into group_members (group_id, user_id, role) values ($1,$2,'owner'),($1,$3,'member')`, g, a.ID, mate.ID)
	if n := countAsUser(t, env, mate.ID, `select count(*) from profiles where user_id = $1`, a.ID); n != 1 {
		t.Fatal("group co-member cannot see member profile name")
	}
	// Blocking hides profiles even from co-members.
	env.ExecWorker(t, `insert into user_blocks (blocker_id, blocked_id) values ($1,$2)`, a.ID, mate.ID)
	if n := countAsUser(t, env, mate.ID, `select count(*) from profiles where user_id = $1`, a.ID); n != 0 {
		t.Fatal("blocked user can still see blocker's profile")
	}
}

// The discovery and minimal-profile helpers (SECURITY DEFINER) expose only
// name/username/avatar, honour blocks and opt-outs, and need an identity.
func TestDiscoveryHelpersExposeOnlyMinimalProfiles(t *testing.T) {
	env := dbtest.Setup(t)
	me := env.CreateUser(t, "Seeker")
	open := env.CreateUser(t, "Open")
	shy := env.CreateUser(t, "Shy")
	blocker := env.CreateUser(t, "Blocker")
	env.ExecWorker(t, `update profiles set username = 'open_one', bio = 'secret bio', profile_visibility = 'private', discoverable_by_username = true
		where user_id = $1`, open.ID)
	env.ExecWorker(t, `update profiles set username = 'shy_one' where user_id = $1`, shy.ID) // discovery is off by default
	env.ExecWorker(t, `update profiles set username = 'open_two', discoverable_by_username = true where user_id = $1`, blocker.ID)
	env.ExecWorker(t, `insert into user_blocks (blocker_id, blocked_id) values ($1,$2)`, blocker.ID, me.ID)

	// Exact usernames only (case-insensitive, a leading @ ignored).
	for q, want := range map[string]int{"open_one": 1, " @OPEN_ONE ": 1, "open_": 0, "open": 0, "open_on": 0, "open_two": 0, "shy_one": 0} {
		if n := countAsUser(t, env, me.ID, `select count(*) from montra.search_discoverable($1, 20)`, q); n != want {
			t.Fatalf("search_discoverable(%q) found %d, want %d (exact, opted-in, unblocked users only)", q, n, want)
		}
	}
	var shyDefault bool
	if err := env.Worker.WithSystemTx(context.Background(), func(tx pgx.Tx) error {
		return tx.QueryRow(context.Background(), `select discoverable_by_username from profiles where user_id = $1`, shy.ID).Scan(&shyDefault)
	}); err != nil || shyDefault {
		t.Fatalf("new profiles must not be discoverable by default: %v %v", shyDefault, err)
	}
	if n := countAsUser(t, env, me.ID, `select count(*) from montra.minimal_profile($1)`, shy.ID); n != 0 {
		t.Fatal("minimal profile of an unrelated, non-discoverable user is visible")
	}
	if n := countAsUser(t, env, me.ID, `select count(*) from montra.minimal_profile($1)`, blocker.ID); n != 0 {
		t.Fatal("minimal profile visible across a block")
	}
	// Discoverable but private: the minimal profile is visible, the full row (bio) is not.
	if n := countAsUser(t, env, me.ID, `select count(*) from montra.minimal_profile($1)`, open.ID); n != 1 {
		t.Fatal("discoverable user's minimal profile is not visible")
	}
	if n := countAsUser(t, env, me.ID, `select count(*) from profiles where user_id = $1`, open.ID); n != 0 {
		t.Fatal("private profile row (with bio) visible to a stranger")
	}
	var id *uuid.UUID
	ctx := context.Background()
	if err := env.App.WithUserTx(ctx, me.ID, func(tx pgx.Tx) error {
		return tx.QueryRow(ctx, `select montra.discoverable_user_id('open_two')`).Scan(&id)
	}); err != nil {
		t.Fatal(err)
	}
	if id != nil {
		t.Fatal("exact lookup found a user who blocked the caller")
	}
	// Without an identity the helpers return nothing.
	var n int
	if err := env.App.WithAnonTx(ctx, func(tx pgx.Tx) error {
		return tx.QueryRow(ctx, `select count(*) from montra.search_discoverable('open', 20)`).Scan(&n)
	}); err != nil || n != 0 {
		t.Fatalf("anonymous search returned %d (%v)", n, err)
	}
	// Settlements are group-scoped like expenses.
	g := uuid.New()
	env.ExecWorker(t, `insert into groups (id, created_by, name, group_type, base_currency, timezone) values ($1,$2,'Flat','roommates','INR','Asia/Kolkata')`, g, open.ID)
	env.ExecWorker(t, `insert into group_members (group_id, user_id, role) values ($1,$2,'owner'),($1,$3,'member')`, g, open.ID, shy.ID)
	env.ExecWorker(t, `insert into settlements (group_id, payer_user_id, payee_user_id, amount_minor, currency, settled_on) values ($1,$2,$3,100,'INR',current_date)`,
		g, shy.ID, open.ID)
	if n := countAsUser(t, env, me.ID, `select count(*) from settlements where group_id = $1`, g); n != 0 {
		t.Fatal("outsider can read settlements")
	}
	if n := countAsUser(t, env, shy.ID, `select count(*) from settlements where group_id = $1`, g); n != 1 {
		t.Fatal("member cannot read settlements")
	}
	if _, err := execAsUser(env, shy.ID, `delete from settlements where group_id = $1`, g); pgCode(err) != "42501" {
		t.Fatalf("settlements must not be deletable by the API role, got %v", err)
	}
}

// Guard triggers stop the API role from self-promotion, self-unbanning and
// undoing moderator decisions even though the update policies allow own-row
// updates.
func TestCommunityAndGroupGuards(t *testing.T) {
	env := dbtest.Setup(t)
	owner := env.CreateUser(t, "Owner")
	member := env.CreateUser(t, "Member")
	banned := env.CreateUser(t, "Banned")
	outsider := env.CreateUser(t, "Outsider")
	c := uuid.New()
	env.ExecWorker(t, `insert into communities (id, slug, name, created_by) values ($1,'guarded','Guarded',$2)`, c, owner.ID)
	env.ExecWorker(t, `insert into community_members (community_id, user_id, role, status) values ($1,$2,'owner','active'),($1,$3,'member','active'),
		($1,$4,'member','banned')`, c, owner.ID, member.ID, banned.ID)
	denied := func(label string, user uuid.UUID, sql string, args ...any) {
		t.Helper()
		if _, err := execAsUser(env, user, sql, args...); pgCode(err) != "42501" {
			t.Fatalf("%s: expected insufficient_privilege, got %v", label, err)
		}
	}
	denied("self-promotion", member.ID, `update community_members set role = 'moderator' where community_id = $1 and user_id = $2`, c, member.ID)
	denied("self-unban", banned.ID, `update community_members set status = 'active' where community_id = $1 and user_id = $2`, c, banned.ID)
	env.ExecWorker(t, `update community_members set restricted_until = now() + interval '1 day' where community_id = $1 and user_id = $2`, c, member.ID)
	denied("clearing a restriction", member.ID, `update community_members set restricted_until = null where community_id = $1 and user_id = $2`, c, member.ID)
	if _, err := execAsUser(env, member.ID, `update community_members set status = 'left' where community_id = $1 and user_id = $2`, c, member.ID); err != nil {
		t.Fatalf("leaving must stay allowed: %v", err)
	}
	p := uuid.New()
	env.ExecWorker(t, `insert into community_posts (id, community_id, author_id, title, body, status, removed_reason) values ($1,$2,$3,'Removed post','x','removed','spam')`,
		p, c, member.ID)
	denied("re-publishing a removed post", member.ID, `update community_posts set status = 'published' where id = $1`, p)
	denied("self-pinning", member.ID, `update community_posts set pinned = true where id = $1`, p)
	if _, err := execAsUser(env, member.ID, `update community_posts set status = 'deleted' where id = $1`, p); err != nil {
		t.Fatalf("authors may delete their content: %v", err)
	}
	// Poll votes need membership.
	poll, opt := uuid.New(), uuid.New()
	env.ExecWorker(t, `insert into community_polls (id, post_id, community_id, question) values ($1,$2,$3,'Which?')`, poll, p, c)
	env.ExecWorker(t, `insert into community_poll_options (id, poll_id, community_id, position, label) values ($1,$2,$3,1,'A')`, opt, poll, c)
	denied("outsider voting", outsider.ID, `insert into community_poll_votes (poll_id, option_id, community_id, user_id) values ($1,$2,$3,$4)`, poll, opt, c, outsider.ID)

	// Groups: members cannot promote themselves; invitations cannot be retargeted.
	g, g2 := uuid.New(), uuid.New()
	env.ExecWorker(t, `insert into groups (id, created_by, name, group_type, base_currency, timezone) values ($1,$2,'Flat','roommates','INR','UTC'),
		($3,$2,'Other','friends','INR','UTC')`, g, owner.ID, g2)
	env.ExecWorker(t, `insert into group_members (group_id, user_id, role) values ($1,$2,'owner'),($1,$3,'member'),($4,$2,'owner')`, g, owner.ID, member.ID, g2)
	denied("group self-promotion", member.ID, `update group_members set role = 'owner' where group_id = $1 and user_id = $2`, g, member.ID)
	if _, err := execAsUser(env, member.ID, `update group_members set notification_level = 'none' where group_id = $1 and user_id = $2`, g, member.ID); err != nil {
		t.Fatalf("own notification level must stay editable: %v", err)
	}
	inv := uuid.New()
	env.ExecWorker(t, `insert into group_invitations (id, group_id, invited_by, kind, invitee_user_id, max_uses, expires_at)
		values ($1,$2,$3,'username',$4,1,now() + interval '1 day')`, inv, g, owner.ID, outsider.ID)
	denied("retargeting an invitation", outsider.ID, `update group_invitations set group_id = $2 where id = $1`, inv, g2)
	if _, err := execAsUser(env, outsider.ID, `update group_invitations set status = 'declined' where id = $1`, inv); err != nil {
		t.Fatalf("declining must stay allowed: %v", err)
	}
}

// The webhook inbox is write-only for the API role, and the definer helper
// queues a job only for a verified event that is still waiting.
func TestWebhookInboxIsWriteOnlyAndQueuingIsNarrow(t *testing.T) {
	env := dbtest.Setup(t)
	ctx := context.Background()
	valid, invalid := uuid.New(), uuid.New()
	anon := func(sql string, args ...any) error {
		return env.App.WithAnonTx(ctx, func(tx pgx.Tx) error {
			_, err := tx.Exec(ctx, sql, args...)
			return err
		})
	}
	if err := anon(`insert into integration_webhook_events (id, provider, event_id, signature_valid, payload_sha256, status)
		values ($1,'sandbox','evt_1',true,repeat('a',64),'received'), ($2,'sandbox','invalid:bb',false,repeat('b',64),'quarantined')`, valid, invalid); err != nil {
		t.Fatalf("anonymous inbox insert: %v", err)
	}
	if err := anon(`select count(*) from integration_webhook_events`); pgCode(err) != "42501" {
		t.Fatalf("API role must not read the inbox, got %v", err)
	}
	if err := anon(`insert into jobs (type, payload) values ('integrations.webhook', '{}')`); pgCode(err) != "42501" {
		t.Fatalf("anonymous job insert must be refused, got %v", err)
	}
	if err := anon(`select montra.enqueue_webhook_event($1)`, invalid); pgCode(err) != "P0002" {
		t.Fatalf("quarantined events must not be queued, got %v", err)
	}
	if err := anon(`select montra.enqueue_webhook_event($1)`, uuid.New()); pgCode(err) != "P0002" {
		t.Fatalf("unknown events must not be queued, got %v", err)
	}
	for i := 0; i < 2; i++ { // idempotent
		if err := anon(`select montra.enqueue_webhook_event($1)`, valid); err != nil {
			t.Fatalf("queue verified event: %v", err)
		}
	}
	var n int
	if err := env.Worker.WithSystemTx(ctx, func(tx pgx.Tx) error {
		return tx.QueryRow(ctx, `select count(*) from jobs where type = 'integrations.webhook' and user_id is null and payload->>'event_id' = $1`,
			valid.String()).Scan(&n)
	}); err != nil || n != 1 {
		t.Fatalf("queued jobs: %d (%v)", n, err)
	}
}

// The block-list helper shows only the blocker the name and username of the
// people they blocked; block and mute rows are visible to their owner only.
func TestBlockListHelperAndOwnBlockRows(t *testing.T) {
	env := dbtest.Setup(t)
	blocker := env.CreateUser(t, "List Blocker")
	target := env.CreateUser(t, "List Target")
	other := env.CreateUser(t, "List Other")
	env.ExecWorker(t, `update profiles set username = 'list_target', bio = 'secret bio' where user_id = $1`, target.ID)
	env.ExecWorker(t, `insert into user_blocks (blocker_id, blocked_id) values ($1,$2)`, blocker.ID, target.ID)
	env.ExecWorker(t, `insert into user_mutes (muter_id, muted_id) values ($1,$2)`, blocker.ID, other.ID)

	var name, username string
	ctx := context.Background()
	if err := env.App.WithUserTx(ctx, blocker.ID, func(tx pgx.Tx) error {
		return tx.QueryRow(ctx, `select display_name, username from montra.blocked_user_profile($1)`, target.ID).Scan(&name, &username)
	}); err != nil || name != "Test List Target" || username != "list_target" {
		t.Fatalf("blocker's view of the blocked person: %q %q (%v)", name, username, err)
	}
	// Nobody else learns anything through the helper: not the blocked
	// person, not a third user, not without an identity.
	if n := countAsUser(t, env, target.ID, `select count(*) from montra.blocked_user_profile($1)`, blocker.ID); n != 0 {
		t.Fatal("the blocked person sees the blocker through the block-list helper")
	}
	if n := countAsUser(t, env, other.ID, `select count(*) from montra.blocked_user_profile($1)`, target.ID); n != 0 {
		t.Fatal("a third user sees a blocked person through the block-list helper")
	}
	var n int
	if err := env.App.WithAnonTx(ctx, func(tx pgx.Tx) error {
		return tx.QueryRow(ctx, `select count(*) from montra.blocked_user_profile($1)`, target.ID).Scan(&n)
	}); err != nil || n != 0 {
		t.Fatalf("anonymous block-list lookup returned %d (%v)", n, err)
	}
	// Blocks still hide the profile row (bio) and the minimal profile.
	if n := countAsUser(t, env, blocker.ID, `select count(*) from profiles where user_id = $1`, target.ID); n != 0 {
		t.Fatal("blocker sees the blocked person's profile row")
	}
	if n := countAsUser(t, env, blocker.ID, `select count(*) from montra.minimal_profile($1)`, target.ID); n != 0 {
		t.Fatal("blocker sees the blocked person's minimal profile")
	}
	// Own rows only: the blocked or muted person never sees the row.
	for _, c := range []struct {
		user uuid.UUID
		sql  string
		want int
	}{
		{blocker.ID, `select count(*) from user_blocks`, 1},
		{target.ID, `select count(*) from user_blocks`, 0},
		{blocker.ID, `select count(*) from user_mutes`, 1},
		{other.ID, `select count(*) from user_mutes`, 0},
	} {
		if n := countAsUser(t, env, c.user, c.sql); n != c.want {
			t.Fatalf("%s as %s = %d, want %d", c.sql, c.user, n, c.want)
		}
	}
}

// Payment hints are masked by the database too, whichever role writes them.
func TestPaymentHintsAreMaskedOnWrite(t *testing.T) {
	env := dbtest.Setup(t)
	u := env.CreateUser(t, "Hint Owner")
	rid, wid, aid := uuid.New(), uuid.New(), uuid.New()
	env.ExecWorker(t, `insert into receipts (id, user_id, status) values ($1,$2,'needs_review')`, rid, u.ID)
	env.ExecWorker(t, `insert into receipt_extractions (id, receipt_id, user_id, version, method, extractor_version, status, payment_hint)
		values ($1,$2,$3,1,'ai_vision','t','succeeded','Visa 4111 1111 1111 1111')`, wid, rid, u.ID)
	if _, err := execAsUser(env, u.ID, `insert into receipt_extractions (id, receipt_id, user_id, version, method, extractor_version, status, payment_hint)
		values ($1,$2,$3,2,'manual','t','succeeded','4111-1111-1111-1111')`, aid, rid, u.ID); err != nil {
		t.Fatal(err)
	}
	if _, err := execAsUser(env, u.ID, `update receipt_extractions set payment_hint = 'acct 1234.5678.9012' where id = $1`, aid); err != nil {
		t.Fatal(err)
	}
	want := map[uuid.UUID]string{wid: "Visa •••• 1111", aid: "acct •••• 9012"}
	for id, w := range want {
		var got string
		if err := env.Worker.WithSystemTx(context.Background(), func(tx pgx.Tx) error {
			return tx.QueryRow(context.Background(), `select payment_hint from receipt_extractions where id = $1`, id).Scan(&got)
		}); err != nil || got != w {
			t.Fatalf("stored hint = %q, want %q (%v)", got, w, err)
		}
	}
	for in, w := range map[string]string{"card ending 1234": "card ending 1234", "4111111111111111": "•••• 1111", "12345": "•••• 2345",
		"•••• 1111": "•••• 1111", "1234 x 5678": "1234 x 5678", "UPI 98765 43210": "UPI •••• 3210"} {
		var got string
		if err := env.Worker.WithSystemTx(context.Background(), func(tx pgx.Tx) error {
			return tx.QueryRow(context.Background(), `select montra.mask_payment_hint($1)`, in).Scan(&got)
		}); err != nil || got != w {
			t.Fatalf("mask_payment_hint(%q) = %q, want %q (%v)", in, got, w, err)
		}
	}
}
