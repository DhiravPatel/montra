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
            ("/", "marketing", "LandingPage", False, False),
            ("/sign-in", "auth", "SignInPage", False, False),
            ("/budgets/:budgetId", "budgets", "BudgetDetailPage", False, True),
            ("/bills/:billId", None, None, True, True),
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
            ("/", "<redirect>"),
            ("/profile", "ProfileScreen"),
            ("/profile/security", "SecurityScreen"),
            ("/profile/security/sessions", "SessionsScreen"),
            ("/budgets/:id", "BudgetDetailScreen"),
        ])


class GraphTest(unittest.TestCase):
    def test_validate_rejects_dangling_edges_and_bad_types(self):
        good = {"nodes": [{"id": "pkg:a", "type": "package", "label": "a", "props": {}}], "edges": []}
        kg.validate(good)
        bad_edge = dict(good, edges=[{"source": "pkg:a", "target": "table:missing", "type": "reads", "props": {}}])
        with self.assertRaises(kg.GraphError):
            kg.validate(bad_edge)
        bad_type = {"nodes": [{"id": "pkg:a", "type": "widget", "label": "a", "props": {}}], "edges": []}
        with self.assertRaises(kg.GraphError):
            kg.validate(bad_type)
        dupe = {"nodes": good["nodes"] * 2, "edges": []}
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
        for t in ("operation", "package", "table", "job", "requirement", "web_route", "mobile_route"):
            self.assertGreater(types.get(t, 0), 0, t)
        schema = json.loads(kg.render_schema())
        self.assertEqual(sorted(schema["$defs"]["node"]["properties"]["type"]["enum"]), sorted(kg.NODE_TYPES))
        self.assertEqual(sorted(schema["$defs"]["edge"]["properties"]["type"]["enum"]), sorted(kg.EDGE_TYPES))


if __name__ == "__main__":
    unittest.main()
