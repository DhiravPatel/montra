#!/usr/bin/env python3
"""Unit tests for gen_knowledge_graph.py parsers (stdlib unittest, inline fixtures).

Run: python3 -m unittest scripts/docs/test_gen_knowledge_graph.py
"""
import json
import pathlib
import sys
import unittest

sys.dont_write_bytecode = True  # keep scripts/docs free of __pycache__
sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent))
import gen_knowledge_graph as kg  # noqa: E402


class ContractTest(unittest.TestCase):
    def test_operations_and_security(self):
        spec = {"paths": {
            "/budgets": {
                "get": {"operationId": "budgets-list", "tags": ["Budgets"], "summary": "List",
                        "security": [{"bearerAuth": []}]},
                "parameters": [],  # path-level keys are not operations
            },
            "/currencies": {"get": {"operationId": "currencies-list", "tags": ["Reference"]}},
        }}
        ops = kg.parse_contract(spec)
        self.assertEqual([o["id"] for o in ops], ["budgets-list", "currencies-list"])
        self.assertTrue(ops[0]["auth"])
        self.assertFalse(ops[1]["auth"])
        self.assertEqual(ops[0]["method"], "GET")
        self.assertEqual(ops[1]["tag"], "Reference")

    def test_authz_rows(self):
        text = (
            "| Method | Path | Operation | Session | Extra | Rate policy |\n"
            "|---|---|---|---|---|---|\n"
            "| POST | `/me/mfa/totp/disable` | `me-mfa-totp-disable` | required | recent re-auth | auth |\n"
        )
        self.assertEqual(kg.parse_authz(text), {"me-mfa-totp-disable": {
            "session": "required", "extra": "recent re-auth", "rate_policy": "auth"}})


class GoTest(unittest.TestCase):
    def test_imports(self):
        src = 'package x\n\nimport (\n\t"context"\n\tdb "montra/backend/internal/platform/database"\n)\n'
        self.assertEqual(kg.go_imports(src), ["context", "montra/backend/internal/platform/database"])
        self.assertEqual(kg.go_imports('package x\nimport "montra/backend/internal/fx"\n'),
                         ["montra/backend/internal/fx"])

    def test_op_patterns(self):
        src = ('httpx.Op("budgets-list", m, "/budgets", "s", tag)\n'
               'httpx.Op("accounts-"+a.path, m, "/accounts/{id}/"+a.path)\n'
               'httpx.Op(target+"-reactions-add", m, "/x")\n')
        self.assertEqual(kg.GO_OP.findall(src), [("budgets-list", ""), ("accounts-", "+")])
        self.assertEqual(kg.GO_OP_SUFFIX.findall(src), ["-reactions-add"])

    def test_match_close_skips_strings(self):
        text = 'f(a, ")", `(`, g(b))tail'
        self.assertEqual(text[:kg.match_close(text, 1)], 'f(a, ")", `(`, g(b))')

    def test_resolve_values(self):
        consts = {"JobEvaluate": "budgets.evaluate"}
        pkg_consts = {"finance": {"EventCreated": "transaction.created"}}
        aliases = {"finance": "finance"}
        self.assertEqual(kg.resolve_go_value('"x.y"', consts, pkg_consts, aliases), "x.y")
        self.assertEqual(kg.resolve_go_value("JobEvaluate", consts, pkg_consts, aliases), "budgets.evaluate")
        self.assertEqual(kg.resolve_go_value("finance.EventCreated", consts, pkg_consts, aliases),
                         "transaction.created")
        self.assertIsNone(kg.resolve_go_value("ev", consts, pkg_consts, aliases))

    def test_relay_routes(self):
        src = '''
const JobEvaluate = "budgets.evaluate"
const JobNotify = "goals.notify_member"
func Routes(relay *outbox.Relay) {
	route := func(e outbox.Stored) []jobs.Spec {
		return []jobs.Spec{{Type: JobEvaluate, Payload: map[string]any{"a": 1}}}
	}
	for _, ev := range []string{"transaction.created", EventVoided} {
		relay.On(ev, route)
	}
	relay.On("goal.member_added", func(e outbox.Stored) []jobs.Spec {
		return []jobs.Spec{{Type: JobNotify}}
	})
}
'''
        consts = {"JobEvaluate": "budgets.evaluate", "JobNotify": "goals.notify_member",
                  "EventVoided": "transaction.voided"}
        routes = kg.parse_relay_routes(src, consts, {}, {})
        self.assertEqual(sorted(routes), [
            ("goal.member_added", "goals.notify_member"),
            ("transaction.created", "budgets.evaluate"),
            ("transaction.voided", "budgets.evaluate"),
        ])
        spans = kg.route_spans(src)
        inside = src.index("Type: JobNotify")
        self.assertTrue(any(s <= inside < e for s, e in spans))


class SqlTest(unittest.TestCase):
    TABLES = {"budgets", "transactions", "categories", "budget_alerts"}

    def test_reads_and_writes(self):
        sql = ("with recent as (select * from transactions t join categories c on c.id = t.category_id) "
               "insert into budget_alerts (id) select id from recent "
               "on conflict (id) do update set id = excluded.id")
        refs = kg.sql_table_refs(sql, self.TABLES)
        self.assertEqual(refs["read"], {"transactions", "categories"})  # `recent` is a CTE, not a table
        self.assertEqual(refs["insert"], {"budget_alerts"})
        self.assertEqual(refs["update"], set())  # do update set names no table

    def test_update_delete_schema_and_noise(self):
        refs = kg.sql_table_refs("UPDATE montra.budgets SET x = 1; delete from budgets where "
                                 "extract(year from created_at) = 1", self.TABLES)
        self.assertEqual(refs["update"], {"budgets"})
        self.assertEqual(refs["delete"], {"budgets"})
        self.assertEqual(refs["read"], set())  # `from created_at` is not a table

    def test_looks_like_sql(self):
        self.assertTrue(kg.looks_like_sql("select 1"))
        self.assertFalse(kg.looks_like_sql("budgets.evaluate"))


class MigrationTest(unittest.TestCase):
    def test_tables_rls_and_alters(self):
        m1 = """
create table budgets (id uuid primary key);
create table if not exists montra.group_expenses (id uuid);
create table settlements (id uuid);
select apply_owner_rls('budgets', 'owner_user_id');
create policy budgets_read on budgets for select using (true);
-- create table commented_out (id int);
do $$
declare t text;
begin
  foreach t in array array['group_expenses','settlements']
  loop
    execute format('alter table montra.%I enable row level security', t);
    execute format('create policy member_read on montra.%I for select using (true)', t);
  end loop;
end $$;
"""
        m2 = "alter table budgets add column note text;\ncreate index budgets_note on budgets (note);\n"
        tables, altered = kg.parse_migrations([("001_a.sql", m1), ("002_b.sql", m2)])
        self.assertEqual(sorted(tables), ["budgets", "group_expenses", "settlements"])
        self.assertEqual(tables["budgets"]["helpers"], {"owner(owner_user_id)"})
        self.assertEqual(tables["budgets"]["policies"], {"budgets_read"})
        self.assertTrue(tables["settlements"]["rls"])
        self.assertEqual(tables["group_expenses"]["policies"], {"member_read (loop)"})
        self.assertEqual(dict(altered), {"002_b.sql": {"budgets"}})


class RequirementsTest(unittest.TestCase):
    TEXT = """
## 8. Budgets (§4.6)

| ID | Requirement | § | Deps | Location | Status | Tests | Evidence / limitations |
|---|---|---|---|---|---|---|---|
| BUD-008 | Shared budgets | §4.6 | TXN, ADR-016 | BE:budgets, W:budgets, DOC:API | VERIFIED | `x_test.go` | see docs/TESTING.md |
| not a row | x | y | z | w | v |
| BUD-009 | Short row | §4.6 | — | DB | TESTED (web only) |
"""

    def test_rows(self):
        reqs = kg.parse_requirements(self.TEXT)
        self.assertEqual([r["id"] for r in reqs], ["BUD-008", "BUD-009"])
        self.assertEqual(reqs[0]["status"], "VERIFIED")
        self.assertEqual(reqs[1]["status"], "TESTED")
        self.assertEqual(reqs[0]["section"], "8. Budgets (§4.6)")
        self.assertEqual(kg.split_tokens(reqs[0]["location"]), ["BE:budgets", "W:budgets", "DOC:API"])
        self.assertEqual(kg.split_tokens("—"), [])

    def test_location_targets(self):
        packages = {"finance": [], "budgets": [], "platform/jobs": [], "domain/money": []}
        args = (packages, ["budgets"], ["budgets"], {"API.md", "DECISIONS.md"}, {"ADR-002": "x"})
        self.assertEqual(kg.location_targets("BE:budgets", *args), ["pkg:budgets"])
        self.assertEqual(kg.location_targets("BE:transactions", *args), ["pkg:finance"])  # alias
        self.assertEqual(kg.location_targets("BE:jobs", *args), ["pkg:platform/jobs"])
        self.assertEqual(kg.location_targets("DM:money", *args), ["pkg:domain/money"])
        self.assertEqual(kg.location_targets("W:budgets", *args), ["web:budgets"])
        self.assertEqual(kg.location_targets("M:ai", *args), [])
        self.assertEqual(kg.location_targets("DOC:DECISIONS ADR-002", *args),
                         ["doc:DECISIONS.md", "adr:ADR-002"])
        self.assertEqual(kg.location_targets("all", *args),
                         ["app:backend", "app:web", "app:mobile", "app:database"])
        self.assertEqual(kg.location_targets("web/src/shared/api", *args), ["app:web"])


class ClientRoutesTest(unittest.TestCase):
    def test_web_routes(self):
        src = """
import { LandingPage } from '@/features/marketing/pages/LandingPage';
export const routes = [{ children: [
  { index: true, element: <LandingPage /> },
  { path: 'sign-in', lazy: async () => ({ Component: (await import('@/features/auth/pages/SignInPage')).SignInPage }) },
  { element: <RequireAuth />, children: [
    { path: 'budgets/:budgetId', lazy: async () => ({ Component: (await import('@/features/budgets/pages/BudgetDetailPage')).BudgetDetailPage }) },
    { path: 'bills/:billId', element: <LegacyRedirect to={(p) => `/planning/bills/${p.billId}`} /> },
  ]},
]}];
"""
        self.assertEqual(kg.parse_web_routes(src), [
            ("/", "marketing", "LandingPage", False, False, None),
            ("/sign-in", "auth", "SignInPage", False, False, None),
            ("/budgets/:budgetId", "budgets", "BudgetDetailPage", False, True, None),
            ("/bills/:billId", None, None, True, True, "/planning/bills/:billId"),
        ])

    def test_dart_routes_nested_and_redirect(self):
        src = """
List<RouteBase> r() => <RouteBase>[
  GoRoute(path: AppRoutes.root, redirect: (c, s) => AppRoutes.splash),
  GoRoute(
    path: AppRoutes.profile,
    pageBuilder: (c, s) => _page(s, const ProfileScreen()),
    routes: <RouteBase>[
      GoRoute(
        path: 'security',
        pageBuilder: (c, s) => _page(s, const SecurityScreen()),
        routes: <RouteBase>[
          GoRoute(path: 'sessions', pageBuilder: (c, s) => _page(s, const SessionsScreen())),
        ],
      ),
    ],
  ),
  GoRoute(path: '/budgets/:id', pageBuilder: (c, s) => routePage(s, BudgetDetailScreen(budgetId: '1'))),
];
"""
        routes = kg.parse_dart_routes(src, {"root": "/", "splash": "/splash", "profile": "/profile"})
        self.assertEqual(routes, [
            ("/", None, "/splash"),
            ("/profile", "ProfileScreen", None),
            ("/profile/security", "SecurityScreen", None),
            ("/profile/security/sessions", "SessionsScreen", None),
            ("/budgets/:id", "BudgetDetailScreen", None),
        ])


OPS = [("GET", kg.path_key("/budgets"), "budgets-list"), ("GET", kg.path_key("/budgets/{id}"), "budgets-get"),
       ("POST", kg.path_key("/budgets/{id}/pause"), "budgets-pause"),
       ("POST", kg.path_key("/budgets/{id}/resume"), "budgets-resume"),
       ("GET", kg.path_key("/notifications/preferences"), "prefs-get"),
       ("GET", kg.path_key("/notifications/{notificationId}"), "notif-get"),
       ("POST", kg.path_key("/groups/{id}/expenses/{expenseId}/comments"), "gx-comment"),
       ("POST", kg.path_key("/posts/{id}/comments"), "post-comment")]


class PathMatchingTest(unittest.TestCase):
    def test_go_path_templates(self):
        self.assertEqual(kg.go_path_template('"/budgets/"+bid+"/pause"'), "/budgets/{}/pause")
        self.assertEqual(kg.go_path_template('fmt.Sprintf("/budgets/%s", id)'), "/budgets/{}")
        self.assertEqual(kg.go_path_template('"/transactions?type=expense"'), "/transactions?type=expense")
        self.assertIsNone(kg.go_path_template("path"))

    def test_resolve_local_variable(self):
        body = 'path := "/budgets/"+id\n\tc.Do(t, http.MethodGet, path+"?x=1", nil)'
        expr = kg.top_level_arg(body, body.index("path+"))
        self.assertEqual(kg.go_path_template(kg.resolve_local(expr, body, body.index("c.Do"))), "/budgets/{}?x=1")

    def test_match_ops(self):
        self.assertEqual(kg.match_op("GET", "/budgets/123", OPS), "budgets-get")
        self.assertEqual(kg.match_op("GET", "/notifications/preferences", OPS), "prefs-get")  # literal wins
        self.assertIsNone(kg.match_op("POST", "/budgets/{}/{}", OPS))  # ambiguous action
        body = 'for _, a := range []string{"pause"} { c.Do(t, http.MethodPost, "/budgets/"+id+"/"+a, nil) }'
        self.assertEqual(kg.match_ops_in("POST", "/budgets/{}/{}", OPS, body), ["budgets-pause"])

    def test_feature_flow_mentions(self):
        text = "`POST /groups/{id}/expenses/{expenseId}/comments` then `POST …/comments` and `GET /nope`"
        found, unresolved, last = kg.resolve_mentions(text, OPS)
        self.assertEqual([f[0] for f in found], ["gx-comment", "gx-comment"])
        self.assertEqual(unresolved, ["GET /nope"])


class SqlObjectsTest(unittest.TestCase):
    MIG1 = """
-- helpers
create or replace function montra.current_user_id() returns uuid language sql stable as $$
  select nullif(current_setting('montra.user_id', true), '')::uuid
$$;
create or replace function montra.apply_owner_rls(tbl regclass, owner_col text default 'user_id') returns void
language plpgsql as $$
begin
  execute format('alter table %s enable row level security', tbl);
  execute format('create policy app_owner_all on %s for all to montra_app using (%I = montra.current_user_id())', tbl, owner_col);
end $$;
create or replace function montra.is_member(g uuid) returns boolean language sql stable security definer as $$
  select exists (select 1 from members m where m.group_id = g and m.user_id = montra.current_user_id());
$$;
grant execute on function montra.is_member(uuid) to montra_app;
create table budgets (id uuid);
create table members (group_id uuid, user_id uuid);
create table posts (id uuid);
select apply_owner_rls('budgets', 'owner_user_id');
create policy members_read on members for select to montra_app using (montra.is_member(group_id));
create trigger t_touch before update on montra.posts for each row execute function montra.current_user_id();
do $$
declare t text;
begin
  foreach t in array array['posts']
  loop
    execute format('create policy app_post_read on montra.%I for select to montra_app using (montra.is_member(id))', t);
  end loop;
end $$;
"""
    MIG2 = "drop policy members_read on members;\ngrant delete on budgets to montra_app;\n"

    def test_statements_respect_quotes_and_dollar_bodies(self):
        stmts = kg.sql_statements("select ';'; create function f() returns int as $x$ select 1; $x$; -- c;\nselect 2;")
        self.assertEqual(len(stmts), 3)
        self.assertTrue(stmts[1].startswith("create function"))

    def test_functions_policies_triggers(self):
        tables = {"budgets", "members", "posts"}
        fns, pols, uses, grants = kg.parse_sql_objects([("001.sql", self.MIG1), ("002.sql", self.MIG2)], tables)
        self.assertTrue(fns["is_member"]["security_definer"])
        self.assertEqual(fns["is_member"]["volatility"], "stable")
        self.assertEqual(fns["is_member"]["execute_roles"], {"montra_app"})
        self.assertEqual(kg.sql_table_refs(fns["is_member"]["body"], tables)["read"], {"members"})
        self.assertEqual(sorted(pols), [("budgets", "app_owner_all"), ("members", "members_read"), ("posts", "app_post_read")])
        self.assertEqual(pols[("budgets", "app_owner_all")]["via"], "helper apply_owner_rls")
        self.assertIn("owner_user_id", pols[("budgets", "app_owner_all")]["expr"])
        self.assertEqual(pols[("members", "members_read")]["command"], "select")
        self.assertEqual(pols[("members", "members_read")]["roles"], ["montra_app"])
        self.assertEqual(pols[("members", "members_read")]["dropped_in"], "002.sql")
        self.assertEqual(pols[("posts", "app_post_read")]["via"], "loop")
        self.assertIn(("posts", "current_user_id", "trigger t_touch", "001.sql"), uses)
        self.assertIn(("budgets", "apply_owner_rls", "call", "001.sql"), uses)
        self.assertEqual(dict(grants), {"002.sql": {"budgets"}})
        self.assertEqual(kg.fn_refs(pols[("members", "members_read")]["expr"], set(fns)), {"is_member"})


    def test_guarded_policy_in_do_block(self):
        # Later migrations create policies inside DO blocks guarded by
        # "if not exists (... pg_policies ...)"; they must be counted.
        mig = """do $$
begin
  if not exists (select 1 from pg_policies where tablename = 'notes' and policyname = 'app_notes_select') then
    create policy app_notes_select on notes for select to montra_app
      using (owner_id = montra.current_user_id());
  end if;
  if not exists (select 1 from pg_policies where tablename = 'notes' and policyname = 'worker_all') then
    create policy worker_all on notes for all to montra_worker using (true) with check (true);
  end if;
end $$;
"""
        _, pols, _, _ = kg.parse_sql_objects([("009.sql", mig)], {"notes"})
        self.assertEqual(sorted(pols), [("notes", "app_notes_select"), ("notes", "worker_all")])
        self.assertEqual(pols[("notes", "app_notes_select")]["command"], "select")
        self.assertEqual(pols[("notes", "app_notes_select")]["via"], "guarded statement")


class BackendSourcesTest(unittest.TestCase):
    APPERR = """
const (
	CodeValidation Code = "VALIDATION_ERROR"
	CodeNotFound   Code = "NOT_FOUND"
	CodeDuplicate  Code = "DUPLICATE"
)
func NotFound(resource string) *Error {
	return &Error{Code: CodeNotFound, Status: http.StatusNotFound, Message: "x"}
}
"""

    def test_error_codes(self):
        consts, ctors = kg.parse_apperr(self.APPERR)
        self.assertEqual(ctors, {"NotFound": ("NOT_FOUND", 404)})
        src = """
	return apperr.Rule("zero_based_unallocated", "Allocate the full limit.")
	return apperr.FieldCode("body.limit", "limit_too_low", "Too low.", nil)
	return apperr.New(apperr.CodeDuplicate, http.StatusConflict, msg).WithDetails(apperr.Detail{Code: "dup_receipt", Message: msg})
	return apperr.NotFound("budget")
"""
        got = {(c, t, s) for c, t, s, _m in kg.error_codes_in(src, consts, ctors, {})}
        self.assertEqual(got, {("zero_based_unallocated", "DOMAIN_RULE_VIOLATION", 422),
                               ("limit_too_low", "VALIDATION_ERROR", 422), ("dup_receipt", "DUPLICATE", 409),
                               ("DUPLICATE", None, 409), ("NOT_FOUND", None, 404)})

    def test_notification_literals(self):
        src = """
func (s *Service) raise(ctx context.Context) error {
	_, _, err := notifications.Create(ctx, tx, notifications.Notification{UserID: u, Category: "budget", EventType: "budget_" + a.kind})
	_, _, err = notifications.Create(ctx, tx, notifications.Notification{Category: "goal", EventType: "goal_shared"})
	_, _, err = notifications.Create(ctx, tx, notifications.Notification{Category: n.category, EventType: kind})
	return err
}
"""
        self.assertEqual(kg.notification_literals(src), [("budget", "budget_*", "raise"), ("goal", "goal_shared", "raise")])

    def test_config(self):
        src = """
func LoadFrom(lookup LookupFunc) (*Config, error) {
	c.Env = l.str("APP_ENV", EnvDevelopment)
	c.Storage = StorageConfig{
		Provider: l.str("STORAGE_PROVIDER", StorageLocalDisk),
		APIKey:   l.str("APPWRITE_API_KEY", ""),
		Buckets: BucketsConfig{
			Temp: l.str("APPWRITE_BUCKET_TEMP", "temp"),
		},
	}
	c.Database = DatabaseConfig{
		URL: l.required("DATABASE_URL"),
	}
	c.Security.URLSigningKey = decodeKey(l, "URL_SIGNING_KEY", 32)
	return c, nil
}
func (c *Config) validate(l *loader) {
	l.errs = append(l.errs, errors.New("STORAGE_PROVIDER=appwrite requires APPWRITE_API_KEY"))
	l.errs = append(l.errs, errors.New("STORAGE_PROVIDER=local_disk is only allowed when APP_ENV is development or test"))
	l.errs = append(l.errs, errors.New("URL_SIGNING_KEY is required (base64, 32 bytes)"))
}
"""
        cfg = kg.parse_config(src)
        self.assertEqual(cfg["APPWRITE_BUCKET_TEMP"]["path"], ["Storage", "Buckets", "Temp"])
        self.assertEqual(cfg["APP_ENV"]["path"], ["Env"])
        self.assertEqual(cfg["URL_SIGNING_KEY"]["path"], ["Security", "URLSigningKey"])
        self.assertTrue(cfg["DATABASE_URL"]["required"])
        self.assertTrue(cfg["URL_SIGNING_KEY"]["required"] and cfg["URL_SIGNING_KEY"]["secret"])
        self.assertEqual(cfg["APPWRITE_API_KEY"]["required_when"], ["STORAGE_PROVIDER=appwrite"])
        self.assertEqual(cfg["STORAGE_PROVIDER"]["dev_only_values"], ["local_disk"])
        self.assertFalse(cfg["STORAGE_PROVIDER"]["dev_only"])

    def test_go_funcs(self):
        src = "func A(t *testing.T) {\n\tB(t)\n}\n\nfunc (c *Client) B(t testing.TB) {\n\tx := map[string]any{}\n}\n"
        funcs = kg.go_funcs(src)
        self.assertEqual(sorted(funcs), ["A", "B"])
        self.assertIn("map[string]any{}", funcs["B"])


class CiTest(unittest.TestCase):
    def test_workflow_and_make(self):
        wf = """name: ci
on: { push: {} }
jobs:
  changes:
    runs-on: ubuntu-latest
  backend:
    needs: changes
    steps:
      - name: Unit
        run: go test -race ./internal/...
      - name: Many
        run: |
          go vet ./...
          python3 scripts/docs/gen_error_codes.py --check
      - uses: some/emulator@v2
        with:
          script: flutter test integration_test -d x
"""
        jobs = kg.parse_workflow(wf)
        self.assertEqual(jobs["backend"]["needs"], ["changes"])
        self.assertIn("go vet ./...", jobs["backend"]["runs"])
        self.assertIn("flutter test integration_test -d x", jobs["backend"]["runs"])
        kinds, apps = kg.command_checks(jobs["backend"]["runs"])
        self.assertEqual(kinds, {"kind:go_unit", "kind:mobile_integration"})
        self.assertTrue({"backend", "docs", "mobile"} <= apps)
        mk = "docs-check: ## Check docs\n\tpython3 scripts/docs/gen_error_codes.py --check\n\ncheck: docs-check lint ## All\n"
        targets = kg.parse_makefile(mk)
        self.assertEqual(targets["docs-check"]["recipe"], ["python3 scripts/docs/gen_error_codes.py --check"])
        self.assertEqual(targets["check"]["prereqs"], ["docs-check", "lint"])


class FeatureFlowsTest(unittest.TestCase):
    def test_parse_sections(self):
        text = """### 3.7 Budgets and alerts

#### How it works end to end

1. `POST /budgets` with type and limit,
   continued here.
2. Any change runs `budgets.evaluate` and writes `budget_alerts`.

| Endpoint | Purpose |
|---|---|
| `GET /budgets` | List |

#### Web

`/budgets`, `/budgets/:budgetId`.

#### Data

`budgets`, `budget_alerts`.

### 3.8 Next
"""
        flows = kg.parse_feature_flows(text)
        self.assertEqual([f["num"] for f in flows], ["3.7", "3.8"])
        self.assertEqual(flows[0]["steps"][0], "`POST /budgets` with type and limit, continued here.")
        self.assertEqual(len(flows[0]["steps"]), 2)
        self.assertIn("`GET /budgets`", flows[0]["endpoints"])
        self.assertEqual(kg.ticked_names(flows[0]["steps"][1], {"budgets.evaluate", "budget_alerts", "x"}),
                         {"budgets.evaluate", "budget_alerts"})
        found, missing = kg.route_mentions(flows[0]["web"], {"/budgets", "/budgets/:budgetId", "/analytics/:report"})
        self.assertEqual(found, {"/budgets", "/budgets/:budgetId"})
        self.assertEqual(kg.route_mentions("`/analytics/cash-flow`", {"/analytics/:report"})[0], {"/analytics/:report"})
        self.assertEqual(kg.ticked_names("`transaction.*`", {"transaction.created", "goal.changed"}), {"transaction.created"})
        self.assertEqual(kg.code_packages("see `backend/internal/insights/insights.go` and `internal/domain/split`",
                                          {"insights": [], "domain/split": []}), {"insights", "domain/split"})


class GraphChecksTest(unittest.TestCase):
    def test_cypher_check(self):
        good = "CREATE CONSTRAINT x IF NOT EXISTS FOR (n:Entity) REQUIRE n.id IS UNIQUE;\n" \
               "UNWIND [\n  {`id`: 'a\\'b', `props`: {`l`: ['x; y']}}\n] AS row\nMERGE (n:Entity {id: row.id});\n"
        self.assertEqual(kg.check_cypher(good), 2)
        for bad in ("UNWIND [{`id`: 'a'] AS row MERGE (n {id: row.id});",   # unbalanced
                    "MATCH (n) RETURN 'open;",                              # unterminated string
                    "DROP INDEX x;",                                        # unexpected statement
                    "MATCH (n) RETURN n"):                                  # no terminator
            with self.assertRaises(kg.GraphError, msg=bad):
                kg.check_cypher(bad)
        data = {"nodes": [{"id": "pkg:a", "type": "package", "label": "it's", "props": {"m": {"x": 1}, "l": ["a"]}},
                          {"id": "pkg:b", "type": "package", "label": "b", "props": {}}],
                "edges": [{"source": "pkg:a", "target": "pkg:b", "type": "depends_on", "props": {"n": 1}}]}
        self.assertGreater(kg.check_cypher(kg.render_cypher(data)), 2)

    def test_orphans_rejected(self):
        data = {"nodes": [{"id": "pkg:a", "type": "package", "label": "a", "props": {}},
                          {"id": "pkg:b", "type": "package", "label": "b", "props": {}}], "edges": []}
        with self.assertRaises(kg.GraphError) as ctx:
            kg.validate(data)
        self.assertIn("orphan", str(ctx.exception))

    def test_curated_reference_must_exist(self):
        g = kg.Graph()
        g.node("package", "a", "a")
        kg._require(g, "pkg:a", "test")
        with self.assertRaises(kg.GraphError):
            kg._require(g, "op:missing", "journey-99 step 1 ops")

    def test_validate_rejects_dangling_edges_and_bad_types(self):
        good = {"nodes": [{"id": "pkg:a", "type": "package", "label": "a", "props": {}},
                          {"id": "app:backend", "type": "app", "label": "b", "props": {}}],
                "edges": [{"source": "pkg:a", "target": "app:backend", "type": "part_of", "props": {}}]}
        kg.validate(good)
        bad_edge = dict(good, edges=[{"source": "pkg:a", "target": "table:missing", "type": "reads", "props": {}}])
        with self.assertRaises(kg.GraphError):
            kg.validate(bad_edge)
        bad_type = dict(good, nodes=[dict(good["nodes"][0], type="widget"), good["nodes"][1]])
        with self.assertRaises(kg.GraphError):
            kg.validate(bad_type)
        dupe = dict(good, nodes=good["nodes"] * 2)
        with self.assertRaises(kg.GraphError):
            kg.validate(dupe)

    def test_duplicate_node_and_edge_merge(self):
        g = kg.Graph()
        g.node("package", "a", "a", files={1, 2}, empty=set())
        self.assertEqual(g.nodes["pkg:a"]["props"], {"files": [1, 2]})
        with self.assertRaises(kg.GraphError):
            g.node("package", "a", "a")
        g.edge("pkg:a", "pkg:b", "depends_on", sites=1)
        g.edge("pkg:a", "pkg:b", "depends_on", sites=2)
        self.assertEqual(g.edges[("pkg:a", "pkg:b", "depends_on")]["props"], {"sites": 3})

    def test_check_domains_fails_loudly(self):
        with self.assertRaises(kg.GraphError) as ctx:
            kg.check_domains(["auth", "brand_new_pkg"], [], [], [], [])
        self.assertIn("'brand_new_pkg' is not mapped", str(ctx.exception))
        self.assertIn("does not exist any more", str(ctx.exception))

    def test_cypher_escaping(self):
        self.assertEqual(kg.cypher_value("it's \\ ok"), "'it\\'s \\\\ ok'")
        self.assertEqual(kg.cypher_value(["a", 1, True]), "['a', 1, true]")
        self.assertEqual(kg.cypher_map({"b": 1, "a": "x"}), "{`a`: 'x', `b`: 1}")
        self.assertEqual(kg.cypher_value({"props": {"n": [1, 2]}}), "{`props`: {`n`: [1, 2]}}")
        self.assertEqual(kg.neo_props({"m": {"x": 1}, "l": ["a"]}), {"m": '{"x": 1}', "l": ["a"]})

    def test_json_rendering_is_stable_and_parseable(self):
        data = {"schema_version": "1.0.0", "generated_from": ["x"], "counts": {"nodes": 1, "edges": 0},
                "nodes": [{"id": "pkg:a", "type": "package", "label": "a", "props": {"z": 1, "a": 2}}],
                "edges": []}
        text = kg.render_json(data)
        self.assertEqual(json.loads(text)["nodes"][0]["props"], {"a": 2, "z": 1})
        self.assertIn('"props": {"a": 2, "z": 1}', text)
        stamped = kg.render_json(data, "2026-11-13")
        self.assertEqual(kg.strip_stamp(stamped), text)


class RepositoryTest(unittest.TestCase):
    """The real repository builds into a valid graph (fast: well under a second)."""

    def test_build(self):
        g, _stats = kg.build()
        data = kg.graph_data(g)  # validates ids, types and edge endpoints
        types = data["counts"]["node_types"]
        for t in ("operation", "package", "table", "job", "requirement", "web_route", "mobile_route", "flow", "step",
                  "test", "sql_function", "policy", "error_code", "notification_type", "config", "provider",
                  "workflow", "ci_job", "make_target"):
            self.assertGreater(types.get(t, 0), 0, t)
        self.assertGreaterEqual(sum(1 for n in data["nodes"] if n["type"] == "flow" and n["id"].startswith("flow:journey-")), 26)
        schema = json.loads(kg.render_schema())
        self.assertEqual(sorted(schema["$defs"]["node"]["properties"]["type"]["enum"]), sorted(kg.NODE_TYPES))
        self.assertEqual(sorted(schema["$defs"]["edge"]["properties"]["type"]["enum"]), sorted(kg.EDGE_TYPES))


if __name__ == "__main__":
    unittest.main()
