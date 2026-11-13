#!/usr/bin/env python3
"""Regenerate the Montra knowledge graph from the code (docs/knowledge-graph/).

The graph links feature domains, API operations, Go packages, database
tables and migrations, background jobs and outbox events, web and mobile
features and routes, requirements, decisions and docs. Everything is
extracted statically (regular expressions over the sources, the OpenAPI
contract and a few inventory tables in docs/), so it is fast, needs only the
standard library, and is deterministic: nodes and edges are sorted and no
timestamp is written unless --stamp is given.

Outputs:
  docs/knowledge-graph/graph.json         nodes + edges (one per line)
  docs/knowledge-graph/graph.schema.json  JSON Schema of graph.json
  docs/knowledge-graph/graph.cypher       Neo4j import (MERGE, idempotent)
  docs/knowledge-graph/graph.graphml      GraphML (yEd, Gephi, NetworkX)
  docs/KNOWLEDGE_GRAPH.md                 the GENERATED sections only

The curated DOMAINS table below assigns every backend package, contract tag,
web feature, mobile feature and requirement-ID prefix to one feature domain.
The generator fails when a folder, tag or prefix is not mapped (or a mapping
names something that no longer exists), so new code cannot silently drop
out of the graph.

Usage: python3 scripts/docs/gen_knowledge_graph.py [--check] [--stamp]
  --check  exit 1 when a committed output is out of date (for CI).
  --stamp  also record today's date as generated_at in graph.json (ignored
           by --check).
"""
import datetime
import json
import pathlib
import re
import sys
from collections import Counter, defaultdict
from xml.sax.saxutils import escape as xml_escape

ROOT = pathlib.Path(__file__).resolve().parents[2]
OUT_DIR = ROOT / "docs" / "knowledge-graph"
DOC = ROOT / "docs" / "KNOWLEDGE_GRAPH.md"
SCHEMA_VERSION = "1.0.0"

CONTRACT = "contracts/openapi/montra.v1.json"
AUTHZ_DOC = "docs/AUTHORIZATION_MATRIX.md"
JOBS_DOC = "docs/BACKGROUND_JOBS.md"
TRACE_DOC = "docs/REQUIREMENTS_TRACEABILITY.md"
DECISIONS_DOC = "docs/DECISIONS.md"
MIGRATIONS = "supabase/migrations"
GO_ROOTS = ("backend/internal", "backend/cmd")
WEB_SRC = "web/src"
WEB_ROUTER = "web/src/app/router/routes.tsx"
WEB_PATHS = "web/src/shared/config/paths.ts"
MOBILE_LIB = "mobile/lib"
MOBILE_ENDPOINTS = "mobile/lib/core/api/endpoints.dart"
MOBILE_ROUTES = "mobile/lib/app/router/app_routes.dart"
MOBILE_ROUTER_DIR = "mobile/lib/app/router"
GO_MODULE = "montra/backend"
CURATED = "scripts/docs/kg_curated.json"
FEATURES_DOC = "docs/FEATURES.md"
CONFIG_GO = "backend/internal/platform/config/config.go"
NOTIF_LINKS = "web/src/features/notifications/links.ts"

GENERATED_FROM = sorted([
    CONTRACT, AUTHZ_DOC, JOBS_DOC, TRACE_DOC, DECISIONS_DOC, MIGRATIONS + "/*.sql",
    "backend/internal/**/*.go", "backend/cmd/**/*.go", WEB_SRC + "/**/*.{ts,tsx}",
    MOBILE_LIB + "/**/*.dart", "docs/*.md", "scripts/docs/gen_knowledge_graph.py (DOMAINS)",
    CURATED, FEATURES_DOC, "backend/tests/**/*_test.go", "backend/**/*_test.go", "web/e2e/*.spec.ts",
    "web/src/**/*.test.{ts,tsx}", "mobile/test/**/*_test.dart", "mobile/integration_test/*_test.dart",
    ".github/workflows/*.yml", "Makefile", NOTIF_LINKS,
])

# ---------------------------------------------------------------- vocabulary
NODE_TYPES = {
    "feature": "Feature domain (curated DOMAINS table in this script).",
    "app": "Deliverable area: backend, web, mobile, database, contract.",
    "operation": "API operation from the OpenAPI contract.",
    "package": "Go package under backend/internal or backend/cmd.",
    "table": "Table created by a migration (create table).",
    "migration": "SQL migration file in supabase/migrations.",
    "job": "Background job type registered with reg.Register.",
    "event": "Outbox event type (outbox.Emit / relay.On).",
    "web_feature": "Web module: web/src/features/<x>, plus shared and app.",
    "web_route": "Web route from web/src/app/router/routes.tsx.",
    "mobile_feature": "Mobile module: mobile/lib/features/<x>, plus core and app.",
    "mobile_route": "Mobile GoRoute from mobile/lib/app/router.",
    "requirement": "Row of docs/REQUIREMENTS_TRACEABILITY.md.",
    "decision": "ADR heading in docs/DECISIONS.md.",
    "doc": "Markdown file in docs/.",
    "flow": "User journey (spec §14, curated) or feature flow (docs/FEATURES.md §3).",
    "step": "Ordered step of a flow.",
    "test": "Test: Go test function, web/mobile unit test file, e2e or integration test case.",
    "sql_function": "SQL function from create function in a migration.",
    "policy": "Row-level security policy (statement, loop or RLS helper).",
    "error_code": "API error code: top-level code or detail code raised by the backend.",
    "notification_type": "Notification category and event type created by the backend.",
    "config": "Environment variable read by backend/internal/platform/config.",
    "provider": "External service or adapter (curated).",
    "workflow": "GitHub Actions workflow file.",
    "ci_job": "Job in a GitHub Actions workflow.",
    "make_target": "Makefile target.",
}
NODE_LABELS = {  # Neo4j labels
    "feature": "Feature", "app": "App", "operation": "Operation", "package": "Package",
    "table": "Table", "migration": "Migration", "job": "Job", "event": "Event",
    "web_feature": "WebFeature", "web_route": "WebRoute", "mobile_feature": "MobileFeature",
    "mobile_route": "MobileRoute", "requirement": "Requirement", "decision": "Decision", "doc": "Doc",
    "flow": "Flow", "step": "Step", "test": "Test", "sql_function": "SqlFunction", "policy": "Policy",
    "error_code": "ErrorCode", "notification_type": "NotificationType", "config": "Config",
    "provider": "Provider", "workflow": "Workflow", "ci_job": "CiJob", "make_target": "MakeTarget",
}
NODE_PREFIX = {
    "feature": "feature:", "app": "app:", "operation": "op:", "package": "pkg:", "table": "table:",
    "migration": "migration:", "job": "job:", "event": "event:", "web_feature": "web:",
    "web_route": "webroute:", "mobile_feature": "mobile:", "mobile_route": "mobileroute:",
    "requirement": "req:", "decision": "adr:", "doc": "doc:", "flow": "flow:", "step": "step:",
    "test": "test:", "sql_function": "fn:", "policy": "policy:", "error_code": "err:",
    "notification_type": "notif:", "config": "config:", "provider": "provider:", "workflow": "workflow:",
    "ci_job": "ci:", "make_target": "make:",
}
EDGE_TYPES = {
    "includes": "feature -> package/web_feature/mobile_feature (curated DOMAINS); workflow -> ci_job.",
    "belongs_to": "operation/requirement/job/table/flow -> feature.",
    "part_of": "package/web_feature/mobile_feature/table/operation/migration/doc/test/sql_function/workflow -> app.",
    "implemented_in": "operation -> package that calls httpx.Op(\"<id>\").",
    "depends_on": "package -> package (Go import); requirement -> requirement/feature/decision (Deps); make_target/ci_job -> prerequisite.",
    "reads": "package/sql_function/policy -> table (from/join); step -> table (curated).",
    "writes": "package/sql_function -> table (insert into/update/delete from); step -> table (curated).",
    "created_in": "table -> migration with its create table.",
    "alters": "migration -> table it alters, indexes, or adds policies to later.",
    "handled_in": "job -> package that registers its handler.",
    "enqueues": "package -> job (jobs.Spec{Type: ...} outside relay routes).",
    "emits": "package/step/flow -> event (outbox.Emit with Type: ...).",
    "triggers": "event -> job (relay.On route).",
    "calls": "web_feature/mobile_feature/step/flow -> operation; package/sql_function -> sql_function.",
    "handled_by": "web_route/mobile_route -> web_feature/mobile_feature rendering it.",
    "located_in": "requirement -> package/web_feature/mobile_feature/doc/decision/feature/app (Location column).",
    "references": "requirement -> doc/decision mentioned in its row text.",
    "links_to": "doc -> doc (mentions another docs/*.md file).",
    "documented_in": "decision -> doc.",
    "redirects_to": "legacy web_route / mobile redirect route -> its target route.",
    "has_step": "flow -> step (props.order).",
    "next": "step -> following step.",
    "shown_on": "step/flow -> web_route or mobile_route.",
    "runs": "step/flow -> job; ci_job/make_target -> test.",
    "sends": "package/job/step -> notification_type.",
    "involves": "feature-flow step/flow -> table, config or package it names (verb not stated in the doc).",
    "verifies": "test -> flow (curated, or journey number in the test title).",
    "covers": "test -> operation/table/sql_function/package/web_feature/mobile_feature/web_route.",
    "verified_by": "requirement -> test named in its Tests/Evidence cells.",
    "defines": "migration -> sql_function/policy it creates first.",
    "redefines": "migration -> sql_function/policy it replaces later.",
    "protects": "policy -> table.",
    "uses": "policy/table -> sql_function (policy expression, trigger or helper call); step -> policy (curated).",
    "raises": "package -> error_code (props.http_status).",
    "defined_in": "error_code/config -> the platform package that defines it.",
    "opens": "notification_type -> web_route its category opens (notifications/links.ts).",
    "configures": "config -> package that reads that setting.",
    "integrates": "package -> provider.",
    "configured_by": "provider -> config.",
    "checks": "ci_job/make_target -> app it checks.",
    "mirrors": "ci_job -> make_target whose commands it runs.",
}

# ------------------------------------------------------------------ domains
# Every backend package, contract tag, web feature, mobile feature and
# requirement-ID prefix must appear exactly once. Review this table when
# folders are added or renamed; the generator fails until it is updated.
DOMAINS = {
    "identity": dict(
        area="Account",
        label="Identity, auth & profile",
        packages=["auth", "users", "platform/identity", "store/db"],
        tags=["Auth", "Account security", "Profile & preferences"],
        web=["auth", "account", "settings", "onboarding"],
        mobile=["auth", "settings", "onboarding"],
        reqs=["AUTH", "SET"],
    ),
    "ledger": dict(
        area="Money",
        label="Accounts, transactions & categories",
        packages=["finance", "categories", "domain/ledger"],
        tags=["Accounts", "Transactions", "Categories", "Merchants", "Tags", "Payment methods"],
        web=["accounts", "transactions", "categories", "payment-methods"],
        mobile=["accounts", "transactions", "labels", "payment_methods"],
        reqs=["ACCT", "TXN", "CAT", "TAG", "MER", "CALC"],
    ),
    "budgets": dict(
        area="Money",
        label="Budgets",
        packages=["budgets", "domain/budgetcalc", "domain/period"],
        tags=["Budgets"], web=["budgets"], mobile=["budgets"], reqs=["BUD"],
    ),
    "planning": dict(
        area="Money",
        label="Recurring, bills & calendar",
        packages=["recurring", "domain/recurrence"],
        tags=["Recurring & bills", "Planning"], web=["planning"],
        mobile=["bills", "recurring", "calendar"], reqs=["REC", "BILL"],
    ),
    "subscriptions": dict(
        area="Money",
        label="Subscriptions",
        packages=["subscriptions", "domain/subdetect"],
        tags=["Subscriptions"], web=["subscriptions"], mobile=["subscriptions"], reqs=["SUB"],
    ),
    "goals": dict(
        area="Money",
        label="Goals & savings",
        packages=["goals"], tags=["Goals"], web=["goals"], mobile=["goals"], reqs=["GOAL", "SAV"],
    ),
    "receipts": dict(
        area="Data in",
        label="Receipts & files",
        packages=["receipts", "files", "platform/storage"],
        tags=["Receipts", "Files"], web=["receipts"], mobile=["receipts"], reqs=["RCPT", "STOR"],
    ),
    "imports": dict(
        area="Data in",
        label="Imports & reconciliation",
        packages=["imports", "reconciliation", "domain/reconcile", "domain/statement"],
        tags=["Imports", "Reconciliation"], web=["imports", "reconciliation"],
        mobile=["imports", "reconciliation"], reqs=["IMP", "RECON"],
    ),
    "analytics": dict(
        area="Insight",
        label="Dashboard, analytics & reports",
        packages=["analytics", "reports", "reports/render"],
        tags=["Analytics", "Dashboard", "Reports"], web=["dashboard", "analytics", "reports"],
        mobile=["dashboard", "analytics", "reports"], reqs=["DASH", "ANL", "RPT", "EXP"],
    ),
    "insights": dict(
        area="Insight",
        label="Insights & AI",
        packages=["ai", "ai/llm", "insights"],
        tags=["AI", "Insights"], web=["insights"], mobile=["insights"], reqs=["AI", "ANOM"],
    ),
    "groups": dict(
        area="Together",
        label="Groups, splits & settlements",
        packages=["groups", "domain/split", "domain/settlement"],
        tags=["Groups"], web=["groups", "group-money"], mobile=["groups", "group_money"],
        reqs=["GRP", "SPLT", "BAL", "SETL", "TRIP", "HH"],
    ),
    "social": dict(
        area="Together",
        label="Friends & social graph",
        packages=["social"], tags=["Social"], web=["social"], mobile=["social", "people"],
        reqs=["FRND", "SOC"],
    ),
    "communities": dict(
        area="Together",
        label="Communities",
        packages=["communities"], tags=["Communities"], web=["communities"],
        mobile=["communities"], reqs=["COMM"],
    ),
    "challenges": dict(
        area="Together",
        label="Challenges",
        packages=["challenges"], tags=["Challenges"], web=["challenges"],
        mobile=["challenges"], reqs=["CHAL"],
    ),
    "moderation": dict(
        area="Together",
        label="Moderation",
        packages=["moderation"], tags=["Moderation"], web=["moderation"],
        mobile=["moderation"], reqs=["MOD"],
    ),
    "notifications": dict(
        area="Account",
        label="Notifications",
        packages=["notifications", "platform/email"], tags=["Notifications"],
        web=["notifications"], mobile=["notifications"], reqs=["NOTIF"],
    ),
    "integrations": dict(
        area="Data in",
        label="Integrations",
        packages=["integrations"], tags=["Integrations"], web=["integrations"],
        mobile=["integrations"], reqs=["INT"],
    ),
    "fx": dict(
        area="Money",
        label="Multi-currency",
        packages=["fx", "domain/currency"], tags=["Exchange rates"], web=["fx"], mobile=["fx"],
        reqs=["FX"],
    ),
    "search": dict(
        area="Insight",
        label="Search",
        packages=["search"], tags=["Search"], web=["search"], mobile=["search"], reqs=["SRCH"],
    ),
    "privacy": dict(
        area="Account",
        label="Privacy & fair use",
        packages=["privacy", "fairuse"], tags=["Privacy"], web=["privacy"], mobile=["privacy"],
        reqs=["PRIV"],
    ),
    "support": dict(
        area="Account",
        label="Help & support",
        packages=["support"], tags=["Support"], web=["support"], mobile=["support"], reqs=["HELP"],
    ),
    "admin": dict(
        area="Account",
        label="Admin & cost",
        packages=["admin"], tags=["Admin"], web=["admin"], mobile=[], reqs=["COST", "OPS"],
    ),
    "platform": dict(
        area="Platform",
        label="Platform & cross-cutting",
        packages=[
            "app", "apitypes", "domain/money", "domain/textsafe",
            "platform/apperr", "platform/audit", "platform/breaker", "platform/caps", "platform/config",
            "platform/crypto", "platform/database", "platform/httpx", "platform/idempotency",
            "platform/jobs", "platform/logging", "platform/migrate", "platform/observability",
            "platform/outbox", "platform/ratelimit", "testutil/apitest", "testutil/dbtest",
            "cmd/api", "cmd/worker", "cmd/migrate", "cmd/openapi", "cmd/loadtest", "cmd/seed", "seed",
        ],
        tags=["Reference"], web=["marketing", "_shared", "_app"], mobile=["_core", "_app"],
        reqs=[
            "GEN", "ARCH", "AUTHZ", "API", "BE", "DB", "JOB", "SEC", "DATA", "DEP", "TEST",
            "DOC", "WEB", "MOB", "PAR", "UX", "L10N", "A11Y", "PA", "DEC", "WF",
        ],
    ),
}

# Location-column aliases (`BE:x` names that are not package folders).
LOCATION_ALIASES = {
    "accounts": "finance", "transactions": "finance", "paymentmethods": "finance",
    "merchants": "finance", "tags": "finance", "bills": "recurring", "dashboard": "analytics",
    "worker": "cmd/worker", "jobs": "platform/jobs", "audit": "platform/audit",
    "authorization": "platform/identity", "platform/scheduler": "platform/jobs",
    "imports/testdata": "imports", "storage/appwrite": "platform/storage", "fx": "fx",
}
# Bare Location tokens that name a whole deliverable area.
LOCATION_APPS = {
    "be": ["backend"], "backend": ["backend"], "be:*": ["backend"], "be tests": ["backend"],
    "be validation": ["backend"], "be (sse)": ["backend"], "backend/tests": ["backend"],
    "w": ["web"], "web": ["web"], "m": ["mobile"], "mobile": ["mobile"], "db": ["database"],
    "rls": ["database"], "db files": ["database"], "supabase/": ["database"], "dm:*": ["backend"],
    "contracts/": ["contract"], "all": ["backend", "web", "mobile", "database"],
    "supabase seed": ["database"], "doc": ["docs"], "docs": ["docs"], "docs/": ["docs"],
    "repo": ["repo"], "makefile": ["repo"], "scripts": ["repo"], "scripts/db": ["repo"], "ci": ["repo"],
    ".github": ["repo"], ".github/workflows": ["repo"], ".gitignore": ["repo"], ".env.example": ["repo"],
    "readme.md": ["repo"], "*/readme.md": ["repo"], "depguard": ["repo"], "eslint rules": ["repo"],
}
# Deps tokens that are markers, not references (owner-only items).
DEPS_IGNORED = {"OWNER"}
APPS = {
    "backend": "Go API + worker (backend/)",
    "web": "React web portal (web/)",
    "mobile": "Flutter app (mobile/)",
    "database": "Postgres schema and RLS (supabase/migrations)",
    "contract": "OpenAPI contract (contracts/openapi)",
    "docs": "Documentation (docs/)",
    "repo": "Repository tooling: Makefile, scripts, CI, READMEs, env templates",
}
METHODS = ("GET", "POST", "PUT", "PATCH", "DELETE")


class GraphError(Exception):
    """Raised when the sources and the curated tables disagree."""


# ------------------------------------------------------------------ helpers
def rel(path):
    return path.relative_to(ROOT).as_posix()


def read(relpath):
    return (ROOT / relpath).read_text(encoding="utf-8")


def node_id(kind, key):
    return NODE_PREFIX[kind] + key


def match_close(text, start, open_ch="(", close_ch=")"):
    """Index just past the bracket matching text[start]; skips string literals."""
    depth, i, n = 0, start, len(text)
    while i < n:
        c = text[i]
        if c in "'\"`":
            quote = c
            if text.startswith(quote * 3, i):
                end = text.find(quote * 3, i + 3)
                i = n if end < 0 else end + 3
                continue
            i += 1
            while i < n and text[i] != quote:
                if text[i] == "\\" and quote != "`":
                    i += 1
                i += 1
        elif c == open_ch:
            depth += 1
        elif c == close_ch:
            depth -= 1
            if depth == 0:
                return i + 1
        i += 1
    return n


# ------------------------------------------------------------------ parsers
def parse_contract(spec):
    """[{id, method, path, tag, summary, auth}] from an OpenAPI document."""
    ops = []
    for path, item in spec.get("paths", {}).items():
        for method, op in item.items():
            if method.upper() not in METHODS or not isinstance(op, dict):
                continue
            security = op.get("security", spec.get("security"))
            ops.append(dict(
                id=op["operationId"], method=method.upper(), path=path,
                tag=(op.get("tags") or ["-"])[0], summary=op.get("summary", ""),
                auth=bool(security),
            ))
    return sorted(ops, key=lambda o: o["id"])


AUTHZ_ROW = re.compile(
    r"^\|\s*(GET|POST|PUT|PATCH|DELETE)\s*\|\s*`([^`]+)`\s*\|\s*`([^`]+)`\s*\|"
    r"\s*([^|]*)\|\s*([^|]*)\|\s*([^|]*)\|", re.M)


def parse_authz(text):
    """{operationId: {session, extra, rate_policy}} from AUTHORIZATION_MATRIX.md."""
    out = {}
    for _method, _path, oid, session, extra, rate in AUTHZ_ROW.findall(text):
        out[oid] = dict(session=session.strip(), extra=extra.strip(), rate_policy=rate.strip())
    return out


GO_OP = re.compile(r'\bOp\(\s*"([^"]*)"\s*(\+)?')
GO_OP_SUFFIX = re.compile(r'\bOp\(\s*\w+\s*\+\s*"([^"]+)"')
GO_IMPORT_BLOCK = re.compile(r"^import\s*\((.*?)^\)", re.S | re.M)
GO_IMPORT_ONE = re.compile(r'^import\s+(?:\w+\s+)?"([^"]+)"', re.M)
GO_STRING = re.compile(r'`[^`]*`|"(?:[^"\\\n]|\\.)*"')
GO_CONST = re.compile(r'\b([A-Za-z_]\w*)\s*(?:string\s*)?=\s*"([^"\n]+)"')


def go_imports(text):
    paths = []
    for block in GO_IMPORT_BLOCK.findall(text):
        paths += re.findall(r'"([^"]+)"', block)
    paths += GO_IMPORT_ONE.findall(text)
    return paths


SQL_REF = re.compile(
    r"\b(insert\s+into|delete\s+from|update|from|join)\s+(?:only\s+)?(?:montra\.)?\"?([a-z_][a-z0-9_]*)",
    re.I)


def sql_table_refs(sql, tables):
    """{"read"|"insert"|"update"|"delete": set(table)} for one SQL string.

    Only names of tables created by a migration count, so CTE names,
    functions (`from jsonb_array_elements(...)`) and `extract(x from col)`
    drop out. `on conflict ... do update set` names no table.
    """
    out = {"read": set(), "insert": set(), "update": set(), "delete": set()}
    for verb, name in SQL_REF.findall(sql):
        name = name.lower()
        if name not in tables:
            continue
        verb = verb.lower().split()[0]
        out[{"from": "read", "join": "read"}.get(verb, verb)].add(name)
    return out


def looks_like_sql(s):
    return bool(re.search(r"\b(select|insert|update|delete|with)\b", s, re.I))


CREATE_TABLE = re.compile(r"\bcreate\s+table\s+(?:if\s+not\s+exists\s+)?(?:montra\.)?([a-z_][a-z0-9_]*)", re.I)
ALTER_TABLE = re.compile(r"\balter\s+table\s+(?:if\s+exists\s+)?(?:only\s+)?(?:montra\.)?([a-z_][a-z0-9_]*)", re.I)
CREATE_INDEX = re.compile(r"\bcreate\s+(?:unique\s+)?index\s+(?:concurrently\s+)?(?:if\s+not\s+exists\s+)?\w*\s*on\s+(?:only\s+)?(?:montra\.)?([a-z_][a-z0-9_]*)", re.I)
CREATE_POLICY = re.compile(r"\bcreate\s+policy\s+\"?(\w+)\"?\s+on\s+(?:montra\.)?([a-z_][a-z0-9_]*)", re.I)
RLS_ENABLE = re.compile(r"\balter\s+table\s+(?:montra\.)?([a-z_][a-z0-9_]*)\s+enable\s+row\s+level\s+security", re.I)
RLS_HELPER = re.compile(r"\bapply_(owner|worker)_rls\(\s*'(?:montra\.)?([a-z_][a-z0-9_]*)'(?:\s*,\s*'(\w+)')?", re.I)
RLS_LOOP = re.compile(r"foreach\s+\w+\s+in\s+array\s+array\[(.*?)\]\s*loop(.*?)end\s+loop", re.I | re.S)
SQL_COMMENT = re.compile(r"--[^\n]*")


def parse_migrations(files):
    """files: [(name, sql)] in order -> {table: {...}} and {migration: altered tables}."""
    tables, altered = {}, defaultdict(set)
    for name, sql in files:
        sql = SQL_COMMENT.sub("", sql)
        for t in CREATE_TABLE.findall(sql):
            t = t.lower()
            tables.setdefault(t, dict(migration=name, rls=False, helpers=set(), policies=set()))
        for t in RLS_ENABLE.findall(sql):
            if t.lower() in tables:
                tables[t.lower()]["rls"] = True
        for kind, t, col in RLS_HELPER.findall(sql):
            t = t.lower()
            if t in tables:
                tables[t]["rls"] = True
                tables[t]["helpers"].add(f"owner({col or 'user_id'})" if kind.lower() == "owner" else "worker")
        for pol, t in CREATE_POLICY.findall(sql):
            if t.lower() in tables:
                tables[t.lower()]["policies"].add(pol)
        for names, body in RLS_LOOP.findall(sql):
            loop_tables = [n.lower() for n in re.findall(r"'([a-z_][a-z0-9_]*)'", names)]
            for t in loop_tables:
                if t in tables and "row level security" in body.lower():
                    tables[t]["rls"] = True
                    for pol in re.findall(r"create\s+policy\s+(\w+)", body, re.I):
                        tables[t]["policies"].add(pol + " (loop)")
        for t in set(ALTER_TABLE.findall(sql)) | set(CREATE_INDEX.findall(sql)) | {t for _, t in CREATE_POLICY.findall(sql)}:
            t = t.lower()
            if t in tables and tables[t]["migration"] != name:
                altered[name].add(t)
    return tables, altered


GO_REGISTER = re.compile(r"\breg\.Register\(\s*([\w.]+|\"[^\"]+\")")
GO_RELAY_ON = re.compile(r"\brelay\.On\(\s*([\w.]+|\"[^\"]+\")\s*,\s*")
GO_EMIT = re.compile(r"\boutbox\.Emit\([^{]*outbox\.Event\{\s*Type:\s*([\w.]+|\"[^\"]+\")")
GO_SPEC_TYPE = re.compile(r"\bSpec\{\{?\s*Type:\s*([\w.]+|\"[^\"]+\")")
GO_SPEC_TYPE_ANY = re.compile(r"\bType:\s*([\w.]+|\"[^\"]+\")")
GO_RANGE = re.compile(r"for\s+_\s*,\s*(\w+)\s*:=\s*range\s+\[\]string\{(.*?)\}", re.S)


def resolve_go_value(token, consts, pkg_consts, alias_to_pkg):
    """A Go string literal, local constant or pkg.Const -> value or None."""
    if token.startswith('"'):
        return token.strip('"')
    if "." in token:
        alias, name = token.split(".", 1)
        pkg = alias_to_pkg.get(alias)
        return pkg_consts.get(pkg, {}).get(name) if pkg else None
    return consts.get(token)


def parse_relay_routes(text, consts, pkg_consts, alias_to_pkg):
    """[(event, job)] for relay.On(...) routes in one Go file."""
    routes = []
    for m in GO_RELAY_ON.finditer(text):
        call_end = match_close(text, text.index("(", m.start()))
        handler = text[m.end():call_end - 1].strip()
        ev_tok = m.group(1)
        events = []
        value = resolve_go_value(ev_tok, consts, pkg_consts, alias_to_pkg)
        if value is not None:
            events = [value]
        else:  # loop variable over a []string{...} literal before the call
            for r in GO_RANGE.finditer(text, 0, m.start()):
                if r.group(1) == ev_tok:
                    events = [resolve_go_value(t, consts, pkg_consts, alias_to_pkg)
                              for t in re.findall(r'"[^"]+"|[\w.]+', r.group(2))]
            events = [e for e in events if e]
        body = handler
        ident = re.match(r"(\w+)", handler)
        if ident and not handler.startswith("func"):
            d = re.search(r"\b" + re.escape(ident.group(1)) + r"\s*:?=\s*func\b", text)
            if d:
                brace = text.index("{", d.end())
                body = text[d.start():match_close(text, brace, "{", "}")]
        jobs_ = {resolve_go_value(t, consts, pkg_consts, alias_to_pkg) for t in GO_SPEC_TYPE_ANY.findall(body)}
        for ev in events:
            for job in sorted(j for j in jobs_ if j):
                routes.append((ev, job))
    return routes


def parse_requirements(text):
    """Rows of the traceability matrix (tolerant to edits elsewhere in the file)."""
    reqs, section = [], ""
    for line in text.splitlines():
        if line.startswith("## "):
            section = line[3:].strip()
            continue
        if not line.startswith("|"):
            continue
        cells = [c.strip() for c in line.strip().strip("|").split("|")]
        if len(cells) < 6 or not re.fullmatch(r"[A-Z][A-Z0-9]*-[0-9A-Za-z.]+", cells[0]):
            continue
        cells += [""] * (8 - len(cells))
        status = re.match(r"[A-Z_]+", cells[5])
        reqs.append(dict(
            id=cells[0], text=cells[1], spec=cells[2], deps=cells[3], location=cells[4],
            status=status.group(0) if status else cells[5], tests=cells[6],
            evidence=" | ".join(cells[7:]), section=section, line=line,
        ))
    return reqs


def split_tokens(cell):
    return [t.strip() for t in re.split(r"[,;]| \+ ", cell) if t.strip() and t.strip() not in ("—", "-")]


def parse_web_routes(text):
    """[(path, feature, page, redirect, auth, redirect_to)] from routes.tsx.

    The tree is flat: layouts and guards have no `path`, so every `path:` is
    relative to `/`. A route requires a session when it appears after the
    `<RequireAuth />` branch starts.
    """
    imports = dict(re.findall(r"import\s*\{\s*(\w+)\s*\}\s*from\s*'@/features/([\w-]+)/", text))
    require_auth = text.find("<RequireAuth")
    marks = [(m.start(), m.group(1)) for m in re.finditer(r"\bpath:\s*'([^']*)'", text)]
    marks += [(m.start(), "") for m in re.finditer(r"\bindex:\s*true", text)]
    marks.sort()
    out = []
    for i, (pos, path) in enumerate(marks):
        end = marks[i + 1][0] if i + 1 < len(marks) else len(text)
        seg = text[pos:end]
        feat = re.search(r"@/features/([\w-]+)/(?:[\w-]+/)*(\w+)'", seg)
        feature, page = (feat.group(1), feat.group(2)) if feat else (None, None)
        if not feature:
            el = re.search(r"element:\s*<(\w+)", seg)
            if el and el.group(1) in imports:
                feature, page = imports[el.group(1)], el.group(1)
        redirect = "<LegacyRedirect" in seg
        target = None
        if redirect:
            tm = re.search(r"<LegacyRedirect\s+to=\{\([^)]*\)\s*=>\s*(`[^`]*`|'[^']*')", seg)
            if tm:
                # `/planning/bills/${p.billId ?? ''}` -> /planning/bills/:billId
                target = re.sub(r"\$\{\s*p\.(\w+)[^}]*\}", r":\1", tm.group(1)[1:-1])
        route = ("/" + path).replace("//", "/")
        out.append((route, feature, page, redirect, 0 <= require_auth < pos, target))
    return out


def parse_dart_routes(text, constants):
    """[(path, screen class, redirect target)] from GoRoute(...) calls, resolving nesting."""
    spans = []
    for m in re.finditer(r"\bGoRoute\(", text):
        open_at = m.end() - 1
        spans.append((m.start(), match_close(text, open_at)))
    out = []
    resolved = {}
    for start, end in spans:
        body = text[start:end]
        nested = body.find("GoRoute(", len("GoRoute("))
        head = body if nested < 0 else body[:nested]
        pm = re.search(r"\bpath:\s*(AppRoutes\.(\w+)|'([^']*)')", head)
        if not pm:
            continue
        path = constants.get(pm.group(2)) if pm.group(2) else pm.group(3)
        if path is None:
            continue
        parents = [s for s in spans if s[0] < start and s[1] >= end and s in resolved]
        if not path.startswith("/") and parents:
            parent = max(parents)
            path = resolved[parent].rstrip("/") + "/" + path
        resolved[(start, end)] = path
        sm = re.search(r"\b([A-Z]\w*(?:Screen|Page|View|Shell))\b", head)
        rm = re.search(r"\bredirect:\s*\([^)]*\)\s*=>\s*(?:AppRoutes\.(\w+)|'([^']*)')", head)
        target = (constants.get(rm.group(1)) if rm.group(1) else rm.group(2)) if rm else None
        out.append((path, sm.group(1) if sm else None, target))
    return out


# ------------------------------------------------------------------ builder
class Graph:
    def __init__(self):
        self.nodes, self.edges = {}, {}

    def node(self, ntype_, key, label, **props):
        nid = node_id(ntype_, key)
        if nid in self.nodes:
            raise GraphError(f"duplicate node id {nid}")
        self.nodes[nid] = dict(id=nid, type=ntype_, label=label, props=clean(props))
        return nid

    def edge(self, source, target, etype_, **props):
        k = (source, target, etype_)
        if k in self.edges:
            merged = self.edges[k]["props"]
            for name, value in clean(props).items():
                if isinstance(value, int) and not isinstance(value, bool) and name in merged:
                    merged[name] += value
                else:
                    merged.setdefault(name, value)
            return
        self.edges[k] = dict(source=source, target=target, type=etype_, props=clean(props))


def clean(props):
    out = {}
    for k, v in props.items():
        if isinstance(v, (set, frozenset)):
            v = sorted(v)
        if v is None or v == "" or v == [] or v == {}:
            continue
        out[k] = v
    return out


def go_packages():
    """{pkg key: [go files (non-test)]} for backend/internal/** and backend/cmd/**."""
    pkgs = defaultdict(list)
    for root in GO_ROOTS:
        for f in sorted((ROOT / root).rglob("*.go")):
            if f.name.endswith("_test.go"):
                continue
            d = f.parent.relative_to(ROOT / "backend")
            parts = d.parts
            key = "/".join(parts[1:]) if parts[0] == "internal" else "/".join(parts)
            pkgs[key].append(f)
    return dict(sorted(pkgs.items()))


def check_domains(packages, tags, web_feats, mobile_feats, req_prefixes):
    problems = []
    actual = {"packages": set(packages), "tags": set(tags), "web": set(web_feats),
              "mobile": set(mobile_feats), "reqs": set(req_prefixes)}
    for field, have in actual.items():
        seen = Counter(x for d in DOMAINS.values() for x in d[field])
        for name, count in sorted(seen.items()):
            if count > 1:
                problems.append(f"DOMAINS: {field} {name!r} is mapped {count} times")
            if name not in have:
                problems.append(f"DOMAINS: {field} {name!r} does not exist any more")
        for name in sorted(have - set(seen)):
            problems.append(f"DOMAINS: {field} {name!r} is not mapped to a domain")
    if problems:
        raise GraphError("\n".join(problems) + "\nEdit DOMAINS in scripts/docs/gen_knowledge_graph.py.")


def domain_of(field):
    return {x: dom for dom, d in DOMAINS.items() for x in d[field]}


def build():
    g = Graph()
    stats = defaultdict(list)  # extraction notes for the doc

    # Apps and feature domains.
    for key, label in APPS.items():
        g.node("app", key, label)
    for key, d in DOMAINS.items():
        g.node("feature", key, d["label"], req_prefixes=d["reqs"], tags=d["tags"])

    # Contract operations.
    spec = json.loads(read(CONTRACT))
    ops = parse_contract(spec)
    authz = parse_authz(read(AUTHZ_DOC))
    tags = sorted({o["tag"] for o in ops})

    # Go packages.
    packages = go_packages()
    web_feats = sorted(p.name for p in (ROOT / WEB_SRC / "features").iterdir() if p.is_dir()) + ["_shared", "_app"]
    mobile_feats = sorted(p.name for p in (ROOT / MOBILE_LIB / "features").iterdir() if p.is_dir()) + ["_core", "_app"]
    trace = read(TRACE_DOC)
    reqs = parse_requirements(trace)
    req_prefixes = sorted({r["id"].split("-")[0] for r in reqs})
    check_domains(packages, tags, web_feats, mobile_feats, req_prefixes)
    pkg_domain, tag_domain = domain_of("packages"), domain_of("tags")
    web_domain, mobile_domain, prefix_domain = domain_of("web"), domain_of("mobile"), domain_of("reqs")

    pkg_text = {k: {f: f.read_text(encoding="utf-8") for f in files} for k, files in packages.items()}
    for key, files in packages.items():
        kind = "cmd" if key.startswith("cmd/") else ("platform" if key.startswith("platform/") else
                                                     "domain" if key.startswith("domain/") else
                                                     "testutil" if key.startswith("testutil/") else "service")
        dir_ = ("backend/" + key) if key.startswith("cmd/") else ("backend/internal/" + key)
        nid = g.node("package", key, key, dir=dir_, kind=kind, files=len(files))
        g.edge(node_id("feature", pkg_domain[key]), nid, "includes")
        g.edge(nid, "app:backend", "part_of")

    # Package imports and constants.
    pkg_consts, pkg_aliases = {}, {}
    for key, texts in pkg_text.items():
        consts, aliases = {}, {}
        for f, text in texts.items():
            for name, value in GO_CONST.findall(text):
                consts.setdefault(name, value)
            for imp in go_imports(text):
                if not imp.startswith(GO_MODULE + "/"):
                    continue
                sub = imp[len(GO_MODULE) + 1:]
                target = sub[len("internal/"):] if sub.startswith("internal/") else sub
                if target in packages and target != key:
                    g.edge(node_id("package", key), node_id("package", target), "depends_on")
                    aliases[target.rsplit("/", 1)[-1]] = target
        pkg_consts[key], pkg_aliases[key] = consts, aliases

    # Operations -> packages.
    exact, prefixed, suffixed = {}, [], []
    for key, texts in pkg_text.items():
        for f, text in texts.items():
            for oid, concat in GO_OP.findall(text):
                if concat:
                    prefixed.append((oid, key))
                else:
                    exact.setdefault(oid, key)
            suffixed += [(suffix, key) for suffix in GO_OP_SUFFIX.findall(text)]
    for o in ops:
        a = authz.get(o["id"], {})
        nid = g.node("operation", o["id"], f'{o["method"]} {o["path"]}', method=o["method"], path=o["path"],
                     tag=o["tag"], summary=o["summary"], auth_required=o["auth"],
                     authz_session=a.get("session"), authz_extra=a.get("extra"), rate_policy=a.get("rate_policy"))
        g.edge(nid, node_id("feature", tag_domain[o["tag"]]), "belongs_to")
        g.edge(nid, "app:contract", "part_of")
        pkg, how = exact.get(o["id"]), "exact"
        if pkg is None:
            cands = sorted((p for p in prefixed if o["id"].startswith(p[0])), key=lambda p: (-len(p[0]), p[1]))
            pkg, how = (cands[0][1], "prefix") if cands else (None, None)
        if pkg is None:
            cands = sorted((p for p in suffixed if o["id"].endswith(p[0])), key=lambda p: (-len(p[0]), p[1]))
            pkg, how = (cands[0][1], "suffix") if cands else (None, None)
        if pkg:
            g.edge(nid, node_id("package", pkg), "implemented_in", match=how)
        else:
            stats["ops_without_package"].append(o["id"])

    # Tables and migrations.
    mig_files = sorted((ROOT / MIGRATIONS).glob("*.sql"))
    tables, altered = parse_migrations([(f.name, f.read_text(encoding="utf-8")) for f in mig_files])
    for f in mig_files:
        g.node("migration", f.stem, f.name, file=rel(f))
        g.edge(node_id("migration", f.stem), "app:database", "part_of")
    for t, info in sorted(tables.items()):
        nid = g.node("table", t, t, rls_enabled=info["rls"], rls_helpers=info["helpers"],
                     policy_count=len(info["policies"]))
        g.edge(nid, node_id("migration", info["migration"][:-4]), "created_in")
        g.edge(nid, "app:database", "part_of")
    for mig, ts in altered.items():
        for t in ts:
            g.edge(node_id("migration", mig[:-4]), node_id("table", t), "alters")

    # Package -> table reads/writes (SQL string literals).
    table_names = set(tables)
    usage = defaultdict(lambda: defaultdict(Counter))  # table -> pkg -> verb -> literals
    for key, texts in pkg_text.items():
        for f, text in texts.items():
            for lit in GO_STRING.findall(text):
                body = lit[1:-1]
                if not looks_like_sql(body):
                    continue
                for verb, names in sql_table_refs(body, table_names).items():
                    for t in names:
                        usage[t][key][verb] += 1
    for t in sorted(usage):
        for key, verbs in sorted(usage[t].items()):
            if verbs["read"]:
                g.edge(node_id("package", key), node_id("table", t), "reads", literals=verbs["read"])
            w = {v: verbs[v] for v in ("insert", "update", "delete") if verbs[v]}
            if w:
                g.edge(node_id("package", key), node_id("table", t), "writes", **w)
    for t in sorted(tables):
        # Owning domain: the package that inserts most, then updates, reads,
        # deletes (privacy deletes from everything); test helpers and
        # binaries never own a table.
        users = {k: v for k, v in usage.get(t, {}).items() if not k.startswith(("testutil/", "cmd/"))}
        if users:
            top = sorted(users.items(), key=lambda kv: (-kv[1]["insert"], -kv[1]["update"], -kv[1]["read"],
                                                       -kv[1]["delete"], kv[0]))[0][0]
            g.edge(node_id("table", t), node_id("feature", pkg_domain[top]), "belongs_to", via=top)
        else:
            stats["tables_without_package"].append(t)

    # Jobs and outbox events.
    job_doc = {m[0]: dict(schedule=m[1], timeout=m[2], concurrency=m[3]) for m in re.findall(
        r"^\|\s*`([a-z_.]+)`\s*\|\s*([^|]+?)\s*\|\s*([^|]+?)\s*\|\s*([^|]+?)\s*\|", read(JOBS_DOC), re.M)}
    jobs_, events_, routes, emits, enqueues = {}, set(), set(), set(), set()
    for key, texts in pkg_text.items():
        consts, aliases = pkg_consts[key], pkg_aliases[key]
        for f, text in texts.items():
            for tok in GO_REGISTER.findall(text):
                v = resolve_go_value(tok, consts, pkg_consts, aliases)
                if v and "." in v:
                    jobs_.setdefault(v, key)
            for ev, job in parse_relay_routes(text, consts, pkg_consts, aliases):
                routes.add((ev, job))
                events_.add(ev)
            for tok in GO_EMIT.findall(text):
                v = resolve_go_value(tok, consts, pkg_consts, aliases)
                if v:
                    emits.add((key, v))
                    events_.add(v)
                else:
                    stats["dynamic_emits"].append(f"{key}: {tok}")
            # jobs enqueued directly (Spec literals outside relay routes).
            spans = route_spans(text)
            for m in GO_SPEC_TYPE.finditer(text):
                if any(s <= m.start() < e for s, e in spans):
                    continue
                v = resolve_go_value(m.group(1), consts, pkg_consts, aliases)
                if v:
                    enqueues.add((key, v))
    for job, key in sorted(jobs_.items()):
        nid = g.node("job", job, job, **job_doc.get(job, {}))
        g.edge(nid, node_id("package", key), "handled_in")
        g.edge(nid, node_id("feature", pkg_domain[key]), "belongs_to")
    for ev in sorted(events_):
        g.node("event", ev, ev)
    for ev, job in sorted(routes):
        if job in jobs_:
            g.edge(node_id("event", ev), node_id("job", job), "triggers")
        else:
            stats["routes_to_unknown_jobs"].append(f"{ev} -> {job}")
    for key, ev in sorted(emits):
        g.edge(node_id("package", key), node_id("event", ev), "emits")
    for key, job in sorted(enqueues):
        if job in jobs_:
            g.edge(node_id("package", key), node_id("job", job), "enqueues")
    stats["events_without_emitter"] = sorted(events_ - {e for _, e in emits})
    stats["events_without_route"] = sorted(events_ - {e for e, _ in routes})
    stats["jobs_missing_from_doc"] = sorted(set(jobs_) - set(job_doc))

    # Operation lookup by (method, path).
    op_by_mp = {(o["method"], o["path"]): o["id"] for o in ops}

    # Web features, calls and routes.
    web_root = ROOT / WEB_SRC
    web_mod_files = defaultdict(list)
    for f in sorted(list(web_root.rglob("*.ts")) + list(web_root.rglob("*.tsx"))):
        name = f.name
        if ".test." in name or ".spec." in name or "__tests__" in f.parts or name.endswith(".d.ts"):
            continue
        parts = f.relative_to(web_root).parts
        if parts[0] == "features" and len(parts) > 2:
            mod = parts[1]
        elif parts[0] == "app":
            mod = "_app"
        else:
            mod = "_shared"
        web_mod_files[mod].append(f)
    call_re = re.compile(r"\.(GET|POST|PUT|PATCH|DELETE)\(\s*['\"`]([^'\"`]+)['\"`]")
    for mod in web_feats:
        path = {"_shared": "web/src (shared, i18n, root files)", "_app": "web/src/app"}.get(mod, f"web/src/features/{mod}")
        label = {"_shared": "web shared", "_app": "web app shell"}.get(mod, mod)
        nid = g.node("web_feature", mod, label, dir=path, files=len(web_mod_files.get(mod, [])))
        g.edge(node_id("feature", web_domain[mod]), nid, "includes")
        g.edge(nid, "app:web", "part_of")
        calls = Counter()
        for f in web_mod_files.get(mod, []):
            for method, p in call_re.findall(f.read_text(encoding="utf-8")):
                oid = op_by_mp.get((method, p))
                if oid:
                    calls[oid] += 1
                else:
                    stats["web_unmatched_calls"].append(f"{rel(f)}: {method} {p}")
        for oid, n in sorted(calls.items()):
            g.edge(nid, node_id("operation", oid), "calls", sites=n)
    path_consts = {v: k for k, v in re.findall(r"^\s*(\w+):\s*'(/[^']*)'", read(WEB_PATHS), re.M)}
    seen_routes = set()
    web_redirects = {}
    for route, feature, page, redirect, auth, target in parse_web_routes(read(WEB_ROUTER)):
        if route in seen_routes:
            continue
        seen_routes.add(route)
        if redirect:
            web_redirects[route] = target
        nid = g.node("web_route", route, route, legacy_redirect=redirect or None, requires_auth=auth,
                     paths_const=path_consts.get(route), page=None if redirect else page)
        if feature and not redirect:
            if feature not in web_feats:
                raise GraphError(f"{WEB_ROUTER}: route {route} renders unknown feature {feature}")
            g.edge(nid, node_id("web_feature", feature), "handled_by")
        elif not redirect and route != "/*":
            stats["web_routes_without_feature"].append(route)
    stats["web_paths_without_route"] = sorted(p for p in path_consts if p not in seen_routes)

    # Mobile features, calls and routes.
    endpoints = {m[0]: (m[1], m[2]) for m in re.findall(
        r"static\s+const\s+ApiEndpoint\s+(\w+)\s*=\s*ApiEndpoint\(\s*'(\w+)'\s*,\s*'([^']+)'", read(MOBILE_ENDPOINTS))}
    mobile_root = ROOT / MOBILE_LIB
    mobile_mod_files, class_mod = defaultdict(list), {}
    for f in sorted(mobile_root.rglob("*.dart")):
        parts = f.relative_to(mobile_root).parts
        if parts[0] == "features" and len(parts) > 2:
            mod = parts[1]
        elif parts[0] == "app":
            mod = "_app"
        else:
            mod = "_core"
        mobile_mod_files[mod].append(f)
        for cls in re.findall(r"^(?:abstract\s+|final\s+|sealed\s+|base\s+)*class\s+(\w+)", f.read_text(encoding="utf-8"), re.M):
            class_mod.setdefault(cls, mod)
    for mod in mobile_feats:
        path = {"_core": "mobile/lib (core, l10n, main)", "_app": "mobile/lib/app"}.get(mod, f"mobile/lib/features/{mod}")
        label = {"_core": "mobile core", "_app": "mobile app shell"}.get(mod, mod)
        nid = g.node("mobile_feature", mod, label, dir=path, files=len(mobile_mod_files.get(mod, [])))
        g.edge(node_id("feature", mobile_domain[mod]), nid, "includes")
        g.edge(nid, "app:mobile", "part_of")
        calls = Counter()
        for f in mobile_mod_files.get(mod, []):
            if rel(f) == MOBILE_ENDPOINTS:
                continue
            for name in re.findall(r"\bApiEndpoints\.(\w+)", f.read_text(encoding="utf-8")):
                if name == "all":
                    continue
                ep = endpoints.get(name)
                oid = op_by_mp.get(ep) if ep else None
                if oid:
                    calls[oid] += 1
                else:
                    stats["mobile_unmatched_calls"].append(f"{rel(f)}: ApiEndpoints.{name}")
        for oid, n in sorted(calls.items()):
            g.edge(nid, node_id("operation", oid), "calls", sites=n)
    for name, ep in sorted(endpoints.items()):
        if ep not in op_by_mp:
            stats["mobile_endpoints_not_in_contract"].append(f"{name}: {ep[0]} {ep[1]}")
    route_consts = dict(re.findall(r"static\s+const\s+String\s+(\w+)\s*=\s*'([^']*)'", read(MOBILE_ROUTES)))
    mroutes = {}
    for f in sorted((ROOT / MOBILE_ROUTER_DIR).rglob("*.dart")):
        for path, screen, target in parse_dart_routes(f.read_text(encoding="utf-8"), route_consts):
            mroutes.setdefault(path, (screen, rel(f), target))
    mobile_redirects = {}
    for path, (screen, src, target) in sorted(mroutes.items()):
        redirect = screen is None and target is not None
        if redirect:
            mobile_redirects[path] = target
        nid = g.node("mobile_route", path, path, screen=screen, redirect=redirect or None,
                     router_file=src)
        mod = class_mod.get(screen) if screen else None
        if mod:
            g.edge(nid, node_id("mobile_feature", mod), "handled_by")
        elif not redirect:
            stats["mobile_routes_without_feature"].append(path)

    # Docs and decisions.
    docs = sorted((ROOT / "docs").glob("*.md"))
    doc_names = {f.name for f in docs}
    # Generated blocks are dropped so this doc's own output cannot feed back
    # into the graph (the output would otherwise need two runs to settle).
    doc_text = {f.name: GENERATED_BLOCK.sub("", f.read_text(encoding="utf-8")) for f in docs}
    for f in docs:
        title = re.search(r"^#\s+(.+)$", doc_text[f.name], re.M)
        g.node("doc", f.name, f.name, title=title.group(1).strip() if title else None, file=rel(f))
        g.edge(node_id("doc", f.name), "app:docs", "part_of")
    for name, text in doc_text.items():
        for other in sorted(doc_names - {name}):
            if re.search(r"(?<![\w/-])(?:docs/)?" + re.escape(other) + r"\b", text):
                g.edge(node_id("doc", name), node_id("doc", other), "links_to")
    adrs = {}
    for num, title in re.findall(r"^##\s+(ADR-\d+)\s+(.+)$", doc_text.get("DECISIONS.md", ""), re.M):
        if num not in adrs:
            adrs[num] = title.strip()
            nid = g.node("decision", num, f"{num} {title.strip()}")
            g.edge(nid, "doc:DECISIONS.md", "documented_in")

    # Requirements.
    req_ids = {r["id"] for r in reqs}
    seen_req = set()
    for r in reqs:
        if r["id"] in seen_req:
            stats["duplicate_requirements"].append(r["id"])
            continue
        seen_req.add(r["id"])
        prefix = r["id"].split("-")[0]
        nid = g.node("requirement", r["id"], r["id"], text=r["text"], status=r["status"], spec_section=r["spec"],
                     section=r["section"], location=r["location"], deps=r["deps"] if r["deps"] not in ("", "—") else None)
        g.edge(nid, node_id("feature", prefix_domain[prefix]), "belongs_to")
        unresolved = []
        for tok in split_tokens(r["location"]):
            targets = location_targets(tok, packages, web_feats, mobile_feats, doc_names, adrs)
            if targets:
                for t in targets:
                    g.edge(nid, t, "located_in")
            else:
                unresolved.append(tok)
        if unresolved:
            g.nodes[nid]["props"]["location_unresolved"] = sorted(set(unresolved))
            stats["location_unresolved"] += unresolved
        for tok in split_tokens(r["deps"]):
            for part in tok.split():
                part = part.strip("()")
                if part in DEPS_IGNORED:
                    continue
                if part in req_ids and part != r["id"]:
                    g.edge(nid, node_id("requirement", part), "depends_on")
                elif part in adrs:
                    g.edge(nid, node_id("decision", part), "depends_on")
                elif part.startswith("DM:") and "domain/" + part[3:] in packages:
                    g.edge(nid, node_id("package", "domain/" + part[3:]), "depends_on")
                elif part.rstrip("-*") in prefix_domain:
                    g.edge(nid, node_id("feature", prefix_domain[part.rstrip("-*")]), "depends_on")
                elif re.fullmatch(r"[A-Z0-9:-]+\*?", part):
                    stats["deps_unresolved"].append(f"{r['id']}: {part}")
        row_text = " ".join([r["text"], r["deps"], r["location"], r["tests"], r["evidence"]])
        for name in sorted(doc_names):
            stem = name[:-3]
            if re.search(r"(?<![\w/-])(?:docs/)?" + re.escape(name) + r"\b|\bDOC:" + re.escape(stem) + r"\b", row_text):
                g.edge(nid, node_id("doc", name), "references")
        for num in sorted(set(re.findall(r"\bADR-\d+\b", row_text))):
            if num in adrs:
                g.edge(nid, node_id("decision", num), "references")
    # Redirect routes point at the route they send people to.
    for kind, redirects, known in (("web_route", web_redirects, seen_routes), ("mobile_route", mobile_redirects, set(mroutes))):
        by_key = defaultdict(list)
        for r in known:
            by_key[path_key(r)].append(r)
        for src, target in sorted(redirects.items()):
            hits = sorted(by_key.get(path_key(target or ""), [])) if target else []
            if len(hits) == 1:
                g.edge(node_id(kind, src), node_id(kind, hits[0]), "redirects_to")
            else:
                stats["redirects_unresolved"].append(f"{src} -> {target}")

    ctx = dict(ops=ops, op_by_mp=op_by_mp, packages=packages, pkg_text=pkg_text, pkg_consts=pkg_consts,
               pkg_aliases=pkg_aliases, pkg_domain=pkg_domain, tables=tables, table_names=table_names,
               jobs=jobs_, events=events_, web_feats=web_feats, mobile_feats=mobile_feats,
               web_routes=seen_routes, mobile_routes=set(mroutes), doc_names=doc_names, reqs=reqs,
               prefix_domain=prefix_domain, path_consts=path_consts, migrations=[f.name for f in mig_files])
    extend(g, stats, ctx)
    return g, stats


def path_key(path):
    """'/budgets/{id}' and '/budgets/:budgetId' -> ('budgets', '{}')."""
    segs = [x for x in path.split("?")[0].split("#")[0].strip("/").split("/") if x]
    return tuple("{}" if (x.startswith("{") and x.endswith("}")) or x.startswith(":") else x for x in segs)


def route_spans(text):
    """[(start, end)] of relay.On(...) calls and func(e outbox.Stored) bodies."""
    spans = []
    for m in GO_RELAY_ON.finditer(text):
        spans.append((m.start(), match_close(text, text.index("(", m.start()))))
    for m in re.finditer(r"func\(e outbox\.Stored\)", text):
        brace = text.index("{", m.end())
        spans.append((m.start(), match_close(text, brace, "{", "}")))
    return spans


def location_targets(tok, packages, web_feats, mobile_feats, doc_names, adrs):
    low = tok.lower()
    if low in LOCATION_APPS:
        return [node_id("app", a) for a in LOCATION_APPS[low]]
    m = re.match(r"(BE|DM|W|M|DOC):(\S+)(.*)$", tok)
    if m:
        kind, name, rest = m.groups()
        if kind in ("BE", "DM"):
            name = name.rstrip("/")
            if kind == "BE" and name == "platform":
                return [node_id("feature", "platform")]
            cands = [name] if kind == "BE" else ["domain/" + name]
            cands += [LOCATION_ALIASES.get(name, ""), "platform/" + name, "domain/" + name, "cmd/" + name]
            for c in cands:
                if c in packages:
                    return [node_id("package", c)]
            return []
        if kind == "W":
            return [node_id("web_feature", name)] if name in web_feats else []
        if kind == "M":
            return [node_id("mobile_feature", name)] if name in mobile_feats else []
        out = [node_id("doc", name + ".md")] if name + ".md" in doc_names else []
        out += [node_id("decision", a) for a in re.findall(r"ADR-\d+", rest) if a in adrs]
        return out
    for prefix, app in (("web/", "web"), ("mobile/", "mobile"), ("backend/", "backend"),
                        ("supabase/", "database"), ("contracts/", "contract")):
        if low.startswith(prefix):
            return [node_id("app", app)]
    if low in LOCATION_ALIASES and LOCATION_ALIASES[low] in packages:
        return [node_id("package", LOCATION_ALIASES[low])]
    if low.startswith("platform/") and low in packages:
        return [node_id("package", low)]
    if low.startswith("docs/") and low[5:] in doc_names:
        return [node_id("doc", low[5:])]
    return []


# ------------------------------------------------------------- extensions
# Behaviour layer: flows (journeys and feature flows), tests, SQL functions
# and policies, error codes, notifications, configuration, providers and CI.

HTTP_STATUS = {
    "StatusBadRequest": 400, "StatusUnauthorized": 401, "StatusForbidden": 403, "StatusNotFound": 404,
    "StatusConflict": 409, "StatusGone": 410, "StatusRequestEntityTooLarge": 413,
    "StatusUnsupportedMediaType": 415, "StatusUnprocessableEntity": 422, "StatusTooManyRequests": 429,
    "StatusInternalServerError": 500, "StatusServiceUnavailable": 503, "StatusGatewayTimeout": 504,
    "StatusPreconditionRequired": 428, "StatusRequestTimeout": 408, "StatusNotImplemented": 501,
    "StatusBadGateway": 502, "StatusLocked": 423, "StatusPreconditionFailed": 412,
}
GO_FUNC = re.compile(r"^func\s+(?:\([^)]*\)\s*)?(\w+)\s*\(", re.M)
GO_DO = re.compile(r"\.Do\(\s*\w+\s*,\s*http\.Method(\w+)\s*,\s*")
SQL_FN_CALL = re.compile(r"\bmontra\.(\w+)\s*\(", re.I)


def go_funcs(text):
    """{name: body} for top-level funcs and methods (gofmt layout)."""
    out = {}
    for m in GO_FUNC.finditer(text):
        brace = re.compile(r"\{[ \t]*\n").search(text, m.end())
        if not brace:
            continue
        out.setdefault(m.group(1), text[brace.start():match_close(text, brace.start(), "{", "}")])
    return out


def top_level_arg(text, start):
    """The expression from text[start] up to the next top-level ',' or ')'."""
    depth, i, n = 0, start, len(text)
    while i < n:
        c = text[i]
        if c in "\"`'":
            end = text.find(c, i + 1) if c == "`" else _string_end(text, i)
            i = (end if end > 0 else n) + 1
            continue
        if c in "([{":
            depth += 1
        elif c in ")]}":
            if depth == 0:
                break
            depth -= 1
        elif c == "," and depth == 0:
            break
        i += 1
    return text[start:i].strip()


def _string_end(text, i):
    q, j = text[i], i + 1
    while j < len(text) and text[j] != q:
        j += 2 if text[j] == "\\" else 1
    return j


def go_path_template(expr):
    """`"/budgets/"+id+"/members"` -> '/budgets/{}/members'; None when no literal."""
    parts, depth, cur = [], 0, ""
    i = 0
    while i < len(expr):
        c = expr[i]
        if c in "\"`":
            end = expr.find(c, i + 1) if c == "`" else _string_end(expr, i)
            cur += expr[i:end + 1]
            i = end + 1
            continue
        if c in "([{":
            depth += 1
        elif c in ")]}":
            depth -= 1
        if c == "+" and depth == 0:
            parts.append(cur.strip())
            cur = ""
        else:
            cur += c
        i += 1
    parts.append(cur.strip())
    out, literal = "", False
    for p in parts:
        sp = re.fullmatch(r'fmt\.Sprintf\(\s*"((?:[^"\\]|\\.)*)".*\)', p, re.S)
        if re.fullmatch(r'"(?:[^"\\]|\\.)*"|`[^`]*`', p):
            out += p[1:-1]
            literal = True
        elif sp:
            out += re.sub(r"%[-+ #0]*\d*[a-zA-Z]", "{}", sp.group(1))
            literal = True
        else:
            out += "{}"
    return out if literal and out.startswith("/") else None


def resolve_local(expr, body, pos, depth=0):
    """Replace a leading local variable (`path := "/x/"+id`) with its last assignment before pos."""
    m = re.match(r"([A-Za-z_]\w*)\s*(\+.*)?$", expr, re.S)
    if not m or depth > 3 or expr.startswith(("fmt.", "http.")):
        return expr
    assigns = list(re.finditer(r"\b" + re.escape(m.group(1)) + r"\s*:?=\s*", body[:pos]))
    if not assigns:
        return expr
    a = assigns[-1]
    value = top_level_arg(body, a.end()).split("\n")[0].strip()
    value = resolve_local(value, body, a.start(), depth + 1)
    return value + (" " + m.group(2) if m.group(2) else "")


def match_op(method, path, index):
    """Contract op for (method, concrete or templated path), or None if unknown/ambiguous."""
    best = match_ops(method, path, index)
    return best[0] if len(best) == 1 else None


def match_ops_in(method, path, index, context):
    """Ops for a templated path; when a placeholder stands for an action segment
    (`"/goals/"+id+"/"+action`), keep the actions quoted in the context."""
    best = match_ops(method, path, index)
    if len(best) == 1:
        return best
    key = path_key(path)
    loose = []
    for m, k, oid in index:
        if (method and m != method) or len(k) != len(key):
            continue
        if all(a == b or b == "{}" or (a == "{}" and '"' + b + '"' in context) for a, b in zip(key, k)):
            loose.append(oid)
    return sorted(set(loose))


def match_ops(method, path, index):
    key = path_key(path)
    best, score_best = [], -1
    for m, k, oid in index:
        if (method and m != method) or len(k) != len(key):
            continue
        score, ok = 0, True
        for a, b in zip(key, k):
            if a == b:
                score += 2 if a != "{}" else 1
            elif b != "{}":
                ok = False
                break
        if not ok:
            continue
        if score > score_best:
            best, score_best = [oid], score
        elif score == score_best:
            best.append(oid)
    return best


def sql_statements(sql):
    """Split SQL on top-level ';' (quotes, dollar quotes and comments respected)."""
    out, start, i, n = [], 0, 0, len(sql)
    while i < n:
        c = sql[i]
        if sql.startswith("--", i):
            j = sql.find("\n", i)
            i = n if j < 0 else j
            continue
        if sql.startswith("/*", i):
            j = sql.find("*/", i + 2)
            i = n if j < 0 else j + 2
            continue
        if c == "'":
            j = i + 1
            while j < n:
                if sql[j] == "'" and sql.startswith("''", j):
                    j += 2
                    continue
                if sql[j] == "'":
                    break
                j += 1
            i = j + 1
            continue
        if c == "$":
            m = re.match(r"\$(\w*)\$", sql[i:])
            if m:
                tag = m.group(0)
                j = sql.find(tag, i + len(tag))
                i = n if j < 0 else j + len(tag)
                continue
        if c == ";":
            out.append(sql[start:i].strip())
            start = i + 1
        i += 1
    tail = sql[start:].strip()
    if tail:
        out.append(tail)
    out = [re.sub(r"^(?:\s*--[^\n]*\n|\s*/\*.*?\*/)+", "", x, flags=re.S).strip() for x in out]
    return [x for x in out if x]


def dollar_body(stmt):
    """(body, statement without the body) for a dollar-quoted function body."""
    m = re.search(r"\$(\w*)\$", stmt)
    if not m:
        return "", stmt
    end = stmt.find(m.group(0), m.end())
    if end < 0:
        return stmt[m.end():], stmt[:m.start()]
    return stmt[m.end():end], stmt[:m.start()] + " " + stmt[end + len(m.group(0)):]


CREATE_FN = re.compile(r"^create\s+(?:or\s+replace\s+)?function\s+(?:montra\.)?(\w+)\s*\(", re.I)
POLICY_STMT = re.compile(
    r"create\s+policy\s+\"?(\w+)\"?\s+on\s+(?:montra\.)?(%I|%s|\w+)\s*(?:as\s+(permissive|restrictive)\s*)?"
    r"(?:for\s+(all|select|insert|update|delete)\s*)?(?:to\s+([\w\s,]+?)\s*)?(?=using\b|with\s+check\b|$)(.*)$",
    re.I | re.S)
DROP_POLICY = re.compile(r"^drop\s+policy\s+(?:if\s+exists\s+)?\"?(\w+)\"?\s+on\s+(?:montra\.)?(\w+)", re.I)
TRIGGER = re.compile(r"^create\s+(?:or\s+replace\s+)?(?:constraint\s+)?trigger\s+(\w+)\s+.*?\bon\s+(?:montra\.)?(\w+)\b.*?"
                     r"execute\s+(?:function|procedure)\s+(?:montra\.)?(\w+)\s*\(", re.I | re.S)
HELPER_CALL = re.compile(r"\bselect\s+(?:montra\.)?(\w+)\(\s*'(?:montra\.)?(\w+)'(?:\s*,\s*'(\w+)')?", re.I)
GRANT_ON = re.compile(r"^(?:grant|revoke)\s+[\w\s,()]+?\s+on\s+(?:table\s+)?(?:montra\.)?(\w+)\b", re.I)
FN_GRANT = re.compile(r"^grant\s+execute\s+on\s+function\s+(?:montra\.)?(\w+)\s*\([^)]*\)\s+to\s+([\w\s,]+)", re.I)
FORMAT_STR = re.compile(r"format\(\s*'((?:[^']|'')*)'", re.I)


def parse_policy(text):
    """dict(name, table, command, roles, mode, expr) from one create policy text."""
    m = POLICY_STMT.search(text)
    if not m:
        return None
    roles = sorted(r.strip() for r in (m.group(5) or "public").split(",") if r.strip())
    return dict(name=m.group(1), table=m.group(2).lower(), mode=(m.group(3) or "permissive").lower(),
                command=(m.group(4) or "all").lower(), roles=roles, expr=m.group(6))


# A create policy statement nested in a DO block (up to its ';').
GUARDED_POLICY = re.compile(r"(create\s+policy\s+.+?);", re.I | re.S)


def parse_sql_objects(files, tables):
    """Functions, policies, triggers and helper calls from migrations, in order."""
    functions, policies, uses, grants_alter = {}, {}, [], defaultdict(set)
    helper_templates = {}
    for name, sql in files:
        for stmt in sql_statements(sql):
            low = stmt.lower()
            fm = CREATE_FN.match(stmt)
            if fm:
                fn = fm.group(1).lower()
                body, head = dollar_body(stmt)
                flags = head.lower()
                vol = re.search(r"\b(stable|immutable|volatile)\b", flags)
                lang = re.search(r"\blanguage\s+(\w+)", flags)
                ret = re.search(r"\breturns\s+(.+?)\s+(?:language|as|security|stable|immutable|volatile|set|strict)\b", flags, re.S)
                info = functions.setdefault(fn, dict(defined=[], body=""))
                info["defined"].append(name)
                info.update(body=body, security_definer="security definer" in flags,
                            volatility=vol.group(1) if vol else "volatile", language=lang.group(1) if lang else None,
                            returns=" ".join(ret.group(1).split()) if ret else None)
                templates = []
                for fmt in FORMAT_STR.findall(body):
                    p = parse_policy(fmt.replace("''", "'"))
                    if p and p["table"] in ("%s", "%i"):
                        templates.append(p)
                if templates:
                    helper_templates[fn] = templates
                continue
            g = FN_GRANT.match(stmt)
            if g:
                functions.setdefault(g.group(1).lower(), dict(defined=[], body="")).setdefault("execute_roles", set()).update(
                    r.strip() for r in g.group(2).split(",") if r.strip())
                continue
            if low.startswith("create policy"):
                p = parse_policy(stmt)
                if p and p["table"] in tables:
                    _add_policy(policies, p, name, "statement")
                continue
            if low.startswith("do"):
                # Guarded creation inside a DO block:
                # if not exists (... pg_policies ...) then create policy ...; end if;
                body, _ = dollar_body(stmt)
                for inner in GUARDED_POLICY.findall(body or ""):
                    p = parse_policy(inner)
                    if p and p["table"] in tables:
                        _add_policy(policies, p, name, "guarded statement")
            d = DROP_POLICY.match(stmt)
            if d:
                key = (d.group(2).lower(), d.group(1))
                if key in policies:
                    policies[key]["dropped_in"] = name
                continue
            t = TRIGGER.match(stmt)
            if t:
                uses.append((t.group(2).lower(), t.group(3).lower(), "trigger " + t.group(1), name))
                continue
            gm = GRANT_ON.match(stmt)
            if gm and gm.group(1).lower() in tables:
                grants_alter[name].add(gm.group(1).lower())
            for loop_names, body in RLS_LOOP.findall(stmt):
                loop_tables = [x.lower() for x in re.findall(r"'([a-z_][a-z0-9_]*)'", loop_names)]
                for fmt in FORMAT_STR.findall(body):
                    p = parse_policy(fmt.replace("''", "'"))
                    if not p:
                        continue
                    for lt in loop_tables:
                        if lt in tables:
                            _add_policy(policies, dict(p, table=lt), name, "loop")
            for hfn, ht, col in HELPER_CALL.findall(stmt):
                hfn, ht = hfn.lower(), ht.lower()
                if ht not in tables:
                    continue
                uses.append((ht, hfn, "call", name))
                for tpl in helper_templates.get(hfn, []):
                    expr = tpl["expr"].replace("%I", col or "user_id")
                    _add_policy(policies, dict(tpl, table=ht, expr=expr), name, "helper " + hfn)
    return functions, policies, uses, grants_alter


def _add_policy(policies, p, migration, via):
    key = (p["table"], p["name"])
    prev = policies.get(key)
    if prev and not prev.get("dropped_in"):
        prev.setdefault("redefined_in", []).append(migration)
    entry = dict(p, defined_in=migration, via=via, history=(prev or {}).get("history", []) + [migration])
    if prev:
        entry["redefined_from"] = prev["defined_in"]
    policies[key] = entry


def fn_refs(text, known):
    """Montra function names called in a SQL text (qualified, or bare known names)."""
    found = {m.lower() for m in SQL_FN_CALL.findall(text)}
    for fn in known:
        if re.search(r"(?<![\w.])" + re.escape(fn) + r"\s*\(", text, re.I):
            found.add(fn)
    return {f for f in found if f in known}


# Error codes ---------------------------------------------------------------
APPERR_RULE = re.compile(r'apperr\.(Rule|ConflictCode)\(\s*"([a-z0-9_]+)"\s*,\s*(?:fmt\.Sprintf\(\s*)?"((?:[^"\\]|\\.)*)"')
APPERR_FIELD = re.compile(r'apperr\.FieldCode\(\s*[^,]+,\s*"([a-z0-9_]+)"\s*,\s*(?:fmt\.Sprintf\(\s*)?"((?:[^"\\]|\\.)*)"')
APPERR_DETAIL = re.compile(r'apperr\.Detail\{[^}]*?\bCode:\s*("[a-z0-9_]+"|\w+)')


def parse_apperr(text):
    """({const: CODE}, {constructor: (CODE, status)}) from the apperr package."""
    consts = dict(re.findall(r"^\s*(Code\w+)\s+Code\s*=\s*\"([A-Z_]+)\"", text, re.M))
    ctors = {}
    for name, body in go_funcs(text).items():
        m = re.search(r"Code:\s*(Code\w+),\s*Status:\s*http\.(Status\w+)", body)
        if m and m.group(1) in consts:
            ctors[name] = (consts[m.group(1)], HTTP_STATUS.get(m.group(2)))
    return consts, ctors


def error_codes_in(text, consts, ctors, local_consts):
    """[(code, top_code, status, message)] raised in one Go file."""
    out = []
    for kind, code, msg in APPERR_RULE.findall(text):
        top, st = ("DOMAIN_RULE_VIOLATION", 422) if kind == "Rule" else ("CONFLICT", 409)
        out.append((code, top, st, msg))
    for code, msg in APPERR_FIELD.findall(text):
        out.append((code, "VALIDATION_ERROR", 422, msg))
    for m in APPERR_DETAIL.finditer(text):
        tok = m.group(1)
        code = tok.strip('"') if tok.startswith('"') else local_consts.get(tok)
        if not code or not re.fullmatch(r"[a-z0-9_]+", code):
            continue
        stmt_start = max(text.rfind("return", 0, m.start()), text.rfind("\n\n", 0, m.start()), m.start() - 400)
        ctx = text[stmt_start:m.start()]
        new = re.search(r"apperr\.New\(\s*apperr\.(Code\w+)\s*,\s*http\.(Status\w+)", ctx)
        ctor = re.search(r"apperr\.(\w+)\(", ctx)
        if new and new.group(1) in consts:
            out.append((code, consts[new.group(1)], HTTP_STATUS.get(new.group(2)), ""))
        elif ctor and ctor.group(1) in ctors:
            out.append((code, ctors[ctor.group(1)][0], ctors[ctor.group(1)][1], ""))
        else:
            out.append((code, None, None, ""))
    for m in re.finditer(r"apperr\.New\(\s*apperr\.(Code\w+)\s*,\s*http\.(Status\w+)", text):
        if m.group(1) in consts:
            out.append((consts[m.group(1)], None, HTTP_STATUS.get(m.group(2)), ""))
    for name in re.findall(r"apperr\.(\w+)\(", text):
        if name in ctors:
            out.append((ctors[name][0], None, ctors[name][1], ""))
    return out


# Notifications -------------------------------------------------------------
def notification_literals(text):
    """[(category, event_type, func name)] from notifications.Notification{...} literals."""
    funcs = sorted((m.start(), m.group(1)) for m in GO_FUNC.finditer(text))
    out = []
    for m in re.finditer(r"\bNotification\{", text):
        body = text[m.end() - 1:match_close(text, m.end() - 1, "{", "}")]
        c = re.search(r"\bCategory:\s*([^,}\n]+)", body)
        e = re.search(r"\bEventType:\s*([^,}\n]+)", body)
        if not c:
            continue
        cat = c.group(1).strip()
        if not cat.startswith('"'):
            continue  # computed category (e.g. the groups activity table)
        ev = e.group(1).strip() if e else '"*"'
        lit = re.match(r'"([^"]*)"\s*(\+)?', ev)
        event = (lit.group(1) + "*" if lit.group(2) else lit.group(1)) if lit else "*"
        fn = [name for pos, name in funcs if pos < m.start()]
        out.append((cat.strip('"'), event, fn[-1] if fn else None))
    return out


# Configuration -------------------------------------------------------------
CONFIG_KEY = re.compile(r'\bl\.(\w+)\(\s*"([A-Z][A-Z0-9_]*)"|\(\s*l\s*,\s*"([A-Z][A-Z0-9_]*)"')


def parse_config(text):
    """{KEY: dict(path, loader, validation)} from config.go LoadFrom and validate."""
    load = text[text.find("func LoadFrom"):]
    load = load[:match_close(load, load.index("{"), "{", "}")]
    keys, stack = {}, []
    for line in load.splitlines():
        s = line.strip()
        sec = re.match(r"c\.(\w+)\s*=\s*\w+\{$", s) or re.match(r"(\w+):\s*\w+\{$", s)
        if sec:
            stack.append(sec.group(1))
            continue
        if s in ("}", "},"):
            if stack:
                stack.pop()
            continue
        for m in CONFIG_KEY.finditer(s):
            key = m.group(2) or m.group(3)
            loader = m.group(1) or ("keyring" if "Keyring" in s else "key")
            field = re.match(r"(\w+):", s)
            assign = re.match(r"c\.([\w.]+)\s*=", s)
            path = assign.group(1).split(".") if assign else stack + ([field.group(1)] if field else [])
            keys.setdefault(key, dict(path=path, loader=loader))
    vtext = text[text.find("func (c *Config) validate"):]
    messages = re.findall(r'(?:errors\.New|fmt\.Errorf)\(\s*"((?:[^"\\]|\\.)*)"', vtext)
    for key, info in keys.items():
        mentions = [msg for msg in messages if re.search(r"\b" + key + r"\b", msg)]
        info["validation"] = mentions
        info["required"] = info["loader"] == "required" or any(
            re.match(key + r" is required", msg) for msg in mentions)
        dev = [re.match(key + r"(?:=(\w+))? is only allowed when APP_ENV(?: is |=)development", msg) for msg in mentions]
        info["dev_only"] = any(d and not d.group(1) for d in dev)
        info["dev_only_values"] = sorted(d.group(1) for d in dev if d and d.group(1))
        info["required_when"] = sorted({rm.group(1) for msg in mentions
                                        for rm in [re.match(r"(\w+=\w+) requires (.+)$", msg)]
                                        if rm and re.search(r"\b" + key + r"\b", rm.group(2))})
        info["secret"] = bool(re.search(r"(_KEY|_KEYS|_SECRET|_SECRETS|_PASSWORD|_TOKEN|_CREDENTIALS_FILE)$", key)) and "PUBLIC" not in key
    return keys


# CI ------------------------------------------------------------------------
def parse_workflow(text):
    """{job: dict(name, needs, runs:[cmd], steps:[name])} from a GitHub workflow (indent based)."""
    jobs, cur, in_jobs, in_run = {}, None, False, None
    for line in text.splitlines():
        if re.match(r"^jobs:\s*$", line):
            in_jobs = True
            continue
        if in_jobs and re.match(r"^\S", line):
            in_jobs = False
        if not in_jobs:
            continue
        jm = re.match(r"^  ([\w-]+):\s*$", line)
        if jm:
            cur = jobs.setdefault(jm.group(1), dict(name=None, needs=[], runs=[], steps=[]))
            in_run = None
            continue
        if cur is None:
            continue
        if in_run is not None:
            if line.strip() and len(line) - len(line.lstrip()) > in_run:
                cur["runs"].append(line.strip())
                continue
            in_run = None
        nm = re.match(r"^    name:\s*(.+)$", line)
        if nm:
            cur["name"] = nm.group(1).strip()
        nd = re.match(r"^    needs:\s*\[?([^\]]+)\]?\s*$", line)
        if nd:
            cur["needs"] = [x.strip() for x in nd.group(1).split(",") if x.strip()]
        st = re.match(r"^\s+- name:\s*(.+)$", line)
        if st:
            cur["steps"].append(st.group(1).strip())
        rm = re.match(r"^(\s+)(?:- )?(?:run|script):\s*(.*)$", line)
        if rm:
            cmd = rm.group(2).strip()
            if cmd in ("|", ">", "|-", ">-"):
                in_run = len(rm.group(1))
            elif cmd:
                cur["runs"].append(cmd)
        um = re.match(r"^\s+- uses:\s*(\S+)", line)
        if um:
            cur["runs"].append("uses " + um.group(1))
    return jobs


def parse_makefile(text):
    """{target: dict(help, prereqs, recipe:[cmd])}."""
    targets, cur = {}, None
    for line in text.splitlines():
        m = re.match(r"^([a-zA-Z0-9_-]+):(?!=)\s*([^#]*?)\s*(?:##\s*(.*))?$", line)
        if m and not line.startswith("\t"):
            cur = targets.setdefault(m.group(1), dict(help=m.group(3) or "", prereqs=m.group(2).split(), recipe=[]))
            continue
        if line.startswith("\t") and cur is not None:
            cur["recipe"].append(line.strip())
        elif line.strip() and not line.startswith("#") and not line.startswith("."):
            cur = None
    return targets


# Which test kinds and apps a command exercises.
COMMAND_CHECKS = [
    (r"\bgo test\b.*\./internal", ["kind:go_unit"], ["backend"]),
    (r"\bgo test\b.*\./tests", ["kind:go_api", "kind:go_rls"], ["backend", "database"]),
    (r"\bgo test\b(?!.*\./(?:internal|tests))", ["kind:go_unit", "kind:go_api", "kind:go_rls"], ["backend", "database"]),
    (r"\bgo (?:vet|build)\b|gofmt|golangci|govulncheck|docker build", [], ["backend"]),
    (r"sqlc", [], ["backend", "database"]),
    (r"cmd/openapi|gen:api|gen_api\.dart|check:api", [], ["contract"]),
    (r"\bpnpm (?:test|exec vitest)\b|vitest", ["kind:web_unit"], ["web"]),
    (r"\bpnpm e2e\b|playwright test", ["kind:web_e2e"], ["web", "backend"]),
    (r"\bpnpm (?:typecheck|lint|build|audit|install|dev)\b", [], ["web"]),
    (r"flutter test integration_test", ["kind:mobile_integration"], ["mobile", "backend"]),
    (r"flutter test(?! integration_test)", ["kind:mobile_unit"], ["mobile"]),
    (r"flutter (?:analyze|build|run|pub)|dart (?:format|run)", [], ["mobile"]),
    (r"gen_error_codes|gen_knowledge_graph|test_gen_knowledge_graph|gen_rls_matrix", [], ["docs"]),
    (r"cmd/migrate|psql|migrate", [], ["database"]),
    (r"gitleaks|no-paywall|grep -", [], ["repo"]),
]


def command_checks(cmds):
    kinds, apps = set(), set()
    for cmd in cmds:
        for pattern, k, a in COMMAND_CHECKS:
            if re.search(pattern, cmd):
                kinds.update(k)
                apps.update(a)
    return kinds, apps


# Flows from docs/FEATURES.md ----------------------------------------------
OP_MENTION = re.compile(r"\b(GET|POST|PUT|PATCH|DELETE)\s+((?:…|\.\.\.)?/[^\s`,;)]*)")
TICKED = re.compile(r"`([^`\n]+)`")


def parse_feature_flows(text):
    """[dict(num, title, steps, endpoints, web, mobile, data, background)] from FEATURES.md §3."""
    flows = []
    for m in re.finditer(r"^### (3\.\d+)\s+(.+)$", text, re.M):
        end = text.find("\n### ", m.end())
        body = text[m.end():end if end > 0 else len(text)]
        subs = {}
        for s in re.finditer(r"^#### (.+)$", body, re.M):
            nxt = body.find("\n#### ", s.end())
            subs[s.group(1).strip()] = body[s.end():nxt if nxt > 0 else len(body)]
        how = subs.get("How it works end to end", "")
        steps, cur = [], None
        for line in how.splitlines():
            sm = re.match(r"^(\d+)\.\s+(.*)$", line)
            if sm:
                cur = [sm.group(2)]
                steps.append(cur)
            elif cur is not None and line.startswith("   ") and line.strip():
                cur.append(line.strip())
            elif line.strip() and not line.startswith(" "):
                cur = None
        endpoints = "\n".join(l for l in how.splitlines() if l.startswith("|"))
        flows.append(dict(num=m.group(1), title=m.group(2).strip(), steps=[" ".join(s) for s in steps],
                          endpoints=endpoints, web=subs.get("Web", ""), mobile=subs.get("Mobile", ""),
                          data=subs.get("Data", ""), background=subs.get("Background work", "")))
    return flows


def resolve_mentions(text, op_index, last_path=None):
    """[(op_id, raw)] for `METHOD /path` mentions; `…/x` resolves against the last full path."""
    out, unresolved = [], []
    for method, raw in OP_MENTION.findall(text):
        raw = raw.rstrip(".:")
        path = raw
        if raw.startswith(("…", "...")):
            suffix = raw.lstrip("….")
            cands = [(m, k, o) for m, k, o in op_index if m == method and _key_endswith(k, path_key(suffix))]
            if last_path and cands:
                pk = path_key(last_path)
                cands.sort(key=lambda c: (-_common_prefix(c[1], pk), c[2]))
                if len(cands) == 1 or _common_prefix(cands[0][1], pk) > _common_prefix(cands[1][1], pk):
                    out.append((cands[0][2], raw))
                    continue
            unresolved.append(f"{method} {raw}")
            continue
        oid = match_op(method, path, op_index)
        if oid:
            out.append((oid, raw))
            last_path = path
        else:
            unresolved.append(f"{method} {raw}")
    return out, unresolved, last_path


def _key_endswith(k, suffix):
    return len(k) >= len(suffix) and all(a == b or a == "{}" or b == "{}" for a, b in zip(k[-len(suffix):], suffix))


def _common_prefix(a, b):
    n = 0
    for x, y in zip(a, b):
        if x != y and "{}" not in (x, y):
            break
        n += 1
    return n


def route_mentions(text, routes):
    """Route ids for backticked `/paths` in a Web or Mobile section."""
    by_key = defaultdict(list)
    for r in routes:
        by_key[path_key(r)].append(r)
    found, unresolved = set(), []
    for tok in TICKED.findall(text):
        tok = tok.strip()
        if not tok.startswith("/") or " " in tok:
            continue
        hits = by_key.get(path_key(tok))
        if not hits:  # a literal segment may fill a route parameter (/analytics/cash-flow -> /analytics/:report)
            k = path_key(tok)
            hits = [r for r in routes if len(path_key(r)) == len(k)
                    and all(a == b or b == "{}" for a, b in zip(k, path_key(r)))]
        if hits and len(hits) == 1:
            found.add(hits[0])
        elif hits:
            found.add(tok if tok in hits else sorted(hits)[0])
        else:
            unresolved.append(tok)
    return found, unresolved


def ticked_names(text, names):
    """Backticked identifiers in text that are in names (wildcards like `transaction.*` expand)."""
    out = set()
    for tok in TICKED.findall(text):
        tok = tok.strip()
        if tok in names:
            out.add(tok)
        elif tok.endswith(".*") or tok.endswith("_*"):
            out.update(n for n in names if n.startswith(tok[:-1]))
    return out


def code_packages(text, packages):
    """Go packages named by backticked source paths (`backend/internal/x/...`, `internal/domain/split`)."""
    out = set()
    for tok in TICKED.findall(text):
        m = re.match(r"(?:backend/)?internal/([\w/]+?)(?:/[\w.]+\.go)?/?$", tok.strip())
        if not m:
            continue
        parts = m.group(1).split("/")
        for n in range(len(parts), 0, -1):
            if "/".join(parts[:n]) in packages:
                out.add("/".join(parts[:n]))
                break
    return out


def extend(g, stats, ctx):
    curated = json.loads(read(CURATED))
    op_index = [(o["method"], path_key(o["path"]), o["id"]) for o in ctx["ops"]]
    tables, known_tables = ctx["tables"], ctx["table_names"]
    pkg_text = ctx["pkg_text"]

    # ---- SQL functions and policies.
    mig_files = [(f, read(MIGRATIONS + "/" + f)) for f in ctx["migrations"]]
    functions, policies, uses, grants_alter = parse_sql_objects(mig_files, known_tables)
    known_fns = set(functions)
    for fn, info in sorted(functions.items()):
        if not info["defined"]:
            continue
        nid = g.node("sql_function", "montra." + fn, "montra." + fn, security_definer=info.get("security_definer"),
                     volatility=info.get("volatility"), language=info.get("language"), returns=info.get("returns"),
                     execute_roles=info.get("execute_roles"), defined_in=info["defined"][0])
        g.edge(nid, "app:database", "part_of")
        for i, mig in enumerate(info["defined"]):
            g.edge(node_id("migration", mig[:-4]), nid, "defines" if i == 0 else "redefines")
        refs = sql_table_refs(info["body"], known_tables)
        for t in sorted(refs["read"]):
            g.edge(nid, node_id("table", t), "reads")
        for verb in ("insert", "update", "delete"):
            for t in sorted(refs[verb]):
                g.edge(nid, node_id("table", t), "writes", **{verb: 1})
        for callee in sorted(fn_refs(info["body"], known_fns) - {fn}):
            g.edge(nid, node_id("sql_function", "montra." + callee), "calls")
    active = Counter(t for (t, _n), p in policies.items() if not p.get("dropped_in"))
    for t in tables:
        g.nodes[node_id("table", t)]["props"]["policy_count"] = active.get(t, 0)
    for (t, name), p in sorted(policies.items()):
        nid = g.node("policy", f"{t}.{name}", f"{name} on {t}", table=t, command=p["command"], roles=p["roles"],
                     mode=p["mode"], via=p["via"], defined_in=p["defined_in"], dropped_in=p.get("dropped_in"),
                     active=not p.get("dropped_in"))
        g.edge(nid, node_id("table", t), "protects")
        for i, mig in enumerate(p["history"]):
            g.edge(node_id("migration", mig[:-4]), nid, "defines" if i == 0 else "redefines")
        for fn in sorted(fn_refs(p["expr"], known_fns)):
            g.edge(nid, node_id("sql_function", "montra." + fn), "uses")
        for other in sorted(sql_table_refs(p["expr"], known_tables)["read"] - {t}):
            g.edge(nid, node_id("table", other), "reads")
    for t, fn, via, mig in uses:
        if fn in known_fns:
            g.edge(node_id("table", t), node_id("sql_function", "montra." + fn), "uses", via=via)
    for mig, ts in grants_alter.items():
        for t in ts:
            if tables[t]["migration"] != mig:
                g.edge(node_id("migration", mig[:-4]), node_id("table", t), "alters")
    for key, texts in pkg_text.items():
        called = Counter()
        for f, text in texts.items():
            for lit in GO_STRING.findall(text):
                if looks_like_sql(lit[1:-1]) or "montra." in lit:
                    called.update(fn_refs(lit[1:-1], known_fns))
        for fn, n in sorted(called.items()):
            g.edge(node_id("package", key), node_id("sql_function", "montra." + fn), "calls", literals=n)

    # ---- Error codes.
    apperr_text = "".join(pkg_text.get("platform/apperr", {}).values())
    consts, ctors = parse_apperr(apperr_text)
    codes = {}
    for const, code in sorted(consts.items()):
        codes[code] = dict(kind="top", statuses=set(), message="", top=None)
    raised = defaultdict(lambda: defaultdict(set))
    for key, texts in pkg_text.items():
        if key == "platform/apperr":
            continue
        for f, text in texts.items():
            for code, top, st, msg in error_codes_in(text, consts, ctors, ctx["pkg_consts"][key]):
                info = codes.setdefault(code, dict(kind="detail", statuses=set(), message="", top=None))
                if st:
                    info["statuses"].add(st)
                if top and info["kind"] == "detail":
                    info["top"] = info["top"] or top
                if msg and not info["message"]:
                    info["message"] = re.sub(r"%[-+ #0]*\d*(?:\.\d+)?[a-zA-Z]", "…", msg.replace('\\"', '"'))
                raised[key][code].update([st] if st else [])
    top_status = {code: st for code, st in ctors.values()}
    for code, info in sorted(codes.items()):
        statuses = sorted(info["statuses"] | ({top_status[code]} if code in top_status else set()))
        nid = g.node("error_code", code, code, kind=info["kind"], http_status=statuses, top_code=info["top"],
                     message=info["message"][:160] or None)
        if info["kind"] == "top":
            g.edge(nid, "pkg:platform/apperr", "defined_in")
    for key, cs in sorted(raised.items()):
        for code, sts in sorted(cs.items()):
            g.edge(node_id("package", key), node_id("error_code", code), "raises", http_status=sorted(sts))

    # ---- Notification types.
    notif = defaultdict(lambda: dict(packages=set(), funcs=defaultdict(set)))
    for key, texts in pkg_text.items():
        for f, text in texts.items():
            for cat, ev, fn in notification_literals(text):
                notif[(cat, ev)]["packages"].add(key)
                if fn:
                    notif[(cat, ev)]["funcs"][key].add(fn)
    groups_jobs = "".join(t for f, t in pkg_text.get("groups", {}).items() if f.name == "jobs.go")
    group_table = re.findall(r'^\s*"(\w+)":\s*\{\w+,\s*(?:true|false),\s*"(\w+)"', groups_jobs, re.M)
    for ev, cat in group_table:
        notif[(cat, ev)]["packages"].add("groups")
        notif[(cat, ev)]["job"] = "groups.notify_activity"
    homes = {}
    links = read(NOTIF_LINKS) if (ROOT / NOTIF_LINKS).exists() else ""
    home_block = re.search(r"categoryHome[^{]*\{(.*?)\};", links, re.S)
    for cat, const in re.findall(r"(\w+):\s*paths\.(\w+)", home_block.group(1) if home_block else ""):
        homes[cat] = const
    const_route = {v: k for k, v in ctx["path_consts"].items()}
    job_handlers = _job_handler_bodies(pkg_text, ctx)
    for (cat, ev), info in sorted(notif.items()):
        nid = g.node("notification_type", f"{cat}/{ev}", f"{cat}: {ev}", category=cat, event_type=ev,
                     dynamic=("*" in ev) or None)
        for key in sorted(info["packages"]):
            g.edge(node_id("package", key), nid, "sends")
        if info.get("job"):
            g.edge(node_id("job", info["job"]), nid, "sends")
        for key, fns in info["funcs"].items():
            reach = _callers_of(pkg_text[key], fns)
            for job, (jkey, body) in sorted(job_handlers.items()):
                if jkey == key and any(re.search(r"\b" + re.escape(fn) + r"\(", body) for fn in reach):
                    g.edge(node_id("job", job), nid, "sends")
        route = const_route.get(homes.get(cat))
        if route and route in ctx["web_routes"]:
            g.edge(nid, node_id("web_route", route), "opens")
        else:
            stats["notifications_without_link"].append(f"{cat}/{ev}")

    # ---- Configuration and providers.
    cfg = parse_config(read(CONFIG_GO))
    section_types = dict(re.findall(r"c\.(\w+)\s*=\s*(\w+Config)\{", read(CONFIG_GO)))
    sub_types = dict(re.findall(r"^\s*(\w+):\s*(\w+Config)\{", read(CONFIG_GO), re.M))
    for key, info in sorted(cfg.items()):
        nid = g.node("config", key, key, field=".".join(info["path"]), loader=info["loader"],
                     required=info["required"] or None, dev_only=info["dev_only"] or None,
                     required_when=info["required_when"], dev_only_values=info["dev_only_values"],
                     secret=info["secret"] or None, validation=info["validation"])
        g.edge(nid, "pkg:platform/config", "defined_in")
        path = info["path"]
        pats = []
        if len(path) >= 2:
            pats.append(r"\." + re.escape(path[-2]) + r"\." + re.escape(path[-1]) + r"\b")
        elif path:
            pats.append(r"\b\w*[cC]fg\." + re.escape(path[0]) + r"\b")
            if path[0] == "Env":
                pats.append(r"\bIsDevelopmentLike\(|\bIsProduction\(")
        for typ in (section_types.get(path[0]) if path else None, sub_types.get(path[1]) if len(path) > 2 else None):
            if typ:
                pats.append(r"\bconfig\." + typ + r"\b")
        for pkg, texts in pkg_text.items():
            if pkg == "platform/config":
                continue
            if any(re.search(p, t) for p in pats for t in texts.values()):
                g.edge(nid, node_id("package", pkg), "configures")
    for prov in curated["providers"]:
        nid = g.node("provider", prov["id"], prov["label"], status=prov["status"], dev=prov.get("dev"),
                     kind=prov.get("kind"))
        for pkg in prov["packages"]:
            _require(g, node_id("package", pkg), f"provider {prov['id']}")
            g.edge(node_id("package", pkg), nid, "integrates")
        for key in prov.get("configs", []):
            _require(g, node_id("config", key), f"provider {prov['id']}")
            g.edge(nid, node_id("config", key), "configured_by")

    # ---- Tests.
    tests = extract_tests(g, stats, ctx, op_index)

    # ---- CI and Makefile.
    make = parse_makefile(read("Makefile"))
    for t, info in sorted(make.items()):
        nid = g.node("make_target", t, "make " + t, help=info["help"] or None, recipe=info["recipe"])
        g.edge(nid, "app:repo", "part_of")
        kinds, apps = command_checks(info["recipe"])
        for a in sorted(apps):
            g.edge(nid, node_id("app", a), "checks")
        for k in sorted(kinds):
            for tid in tests.get(k, []):
                g.edge(nid, tid, "runs")
    for t, info in sorted(make.items()):
        for pre in info["prereqs"]:
            if pre in make:
                g.edge(node_id("make_target", t), node_id("make_target", pre), "depends_on")
        if not info["recipe"] and not info["prereqs"]:
            stats["make_targets_empty"].append(t)
    for wf in sorted((ROOT / ".github" / "workflows").glob("*.yml")):
        wid = g.node("workflow", wf.name, wf.name, file=rel(wf))
        g.edge(wid, "app:repo", "part_of")
        jobs = parse_workflow(wf.read_text(encoding="utf-8"))
        for job, info in sorted(jobs.items()):
            jid = g.node("ci_job", f"{wf.stem}/{job}", f"{wf.stem} / {info['name'] or job}", steps=info["steps"])
            g.edge(wid, jid, "includes")
            kinds, apps = command_checks(info["runs"] + info["steps"])
            for a in sorted(apps):
                g.edge(jid, node_id("app", a), "checks")
            for k in sorted(kinds):
                for tid in tests.get(k, []):
                    g.edge(jid, tid, "runs")
            for t, minfo in sorted(make.items()):
                recipe = [re.sub(r"^cd \w+ && ", "", r) for r in minfo["recipe"]]
                if recipe and all(r in info["runs"] for r in recipe):
                    g.edge(jid, node_id("make_target", t), "mirrors")
        for job, info in sorted(jobs.items()):
            for need in info["needs"]:
                if need in jobs:
                    g.edge(node_id("ci_job", f"{wf.stem}/{job}"), node_id("ci_job", f"{wf.stem}/{need}"), "depends_on")

    # ---- Flows (curated journeys, then FEATURES.md feature flows).
    build_flows(g, stats, ctx, curated, op_index, tests)


def _callers_of(texts, targets, depth=3):
    """Functions in a package that reach any target function within depth calls."""
    funcs = {}
    for text in texts.values():
        funcs.update(go_funcs(text))
    reach = set(targets)
    for _ in range(depth):
        new = {name for name, body in funcs.items()
               if name not in reach and any(re.search(r"\b" + re.escape(t) + r"\(", body) for t in reach)}
        if not new:
            break
        reach |= new
    return reach


def _require(g, nid, where):
    if nid not in g.nodes:
        raise GraphError(f"{CURATED}: {where} references {nid}, which is not a node")


def _job_handler_bodies(pkg_text, ctx):
    """{job: (package, handler text)} for reg.Register(job, handler) calls."""
    out = {}
    for key, texts in pkg_text.items():
        for f, text in texts.items():
            for m in GO_REGISTER.finditer(text):
                v = resolve_go_value(m.group(1), ctx["pkg_consts"][key], ctx["pkg_consts"], ctx["pkg_aliases"][key])
                if v:
                    out[v] = (key, text[m.start():match_close(text, text.index("(", m.start()))])
    return out


def extract_tests(g, stats, ctx, op_index):
    """Test nodes and covers edges; returns {kind: [test ids]} and {name: [ids]} under 'by_name'."""
    kinds = defaultdict(list)
    by_name, by_file = defaultdict(list), defaultdict(list)

    def add(tid, label, kind, app, file, **props):
        g.node("test", tid, label, kind=kind, file=file, **props)
        g.edge(node_id("test", tid), node_id("app", app), "part_of")
        kinds["kind:" + kind].append(node_id("test", tid))
        by_file[pathlib.PurePosixPath(file).name].append(node_id("test", tid))

    # Go: backend/tests/{api,rls} with package-local helpers (+ apitest), backend/internal unit tests.
    apitest = ROOT / "backend/internal/testutil/apitest/apitest.go"
    helper_funcs = go_funcs(apitest.read_text(encoding="utf-8")) if apitest.exists() else {}
    op_cover = Counter()
    for suite_dir, kind in (("backend/tests/api", "go_api"), ("backend/tests/rls", "go_rls")):
        files = sorted((ROOT / suite_dir).glob("*_test.go"))
        funcs, origin = dict(helper_funcs), {}
        for f in files:
            for name, body in go_funcs(f.read_text(encoding="utf-8")).items():
                funcs[name] = body
                origin[name] = rel(f)
        direct_ops, direct_tables, direct_fns = {}, {}, {}
        for name, body in funcs.items():
            ops_ = set()
            for m in GO_DO.finditer(body):
                tpl = go_path_template(resolve_local(top_level_arg(body, m.end()), body, m.start()))
                if tpl is None:
                    stats["test_calls_unresolved"].append(f"{origin.get(name, 'apitest')}:{name}")
                    continue
                found = match_ops_in(m.group(1).upper(), tpl, op_index, body)
                if found:
                    ops_.update(found)
                else:
                    stats["test_calls_unresolved"].append(f"{name}: {m.group(1).upper()} {tpl}")
            direct_ops[name] = ops_
            tabs, fns = set(), set()
            for lit in GO_STRING.findall(body):
                if looks_like_sql(lit[1:-1]):
                    r = sql_table_refs(lit[1:-1], ctx["table_names"])
                    tabs |= set().union(*r.values())
                    fns |= {x for x in SQL_FN_CALL.findall(lit)}
            direct_tables[name], direct_fns[name] = tabs, fns
        calls = {n: {c for c in re.findall(r"\b([A-Za-z_]\w*)\(", b) if c in funcs and c != n} for n, b in funcs.items()}
        for name in sorted(n for n in origin if re.match(r"(Test|Fuzz)[A-Z_]", n)):
            tid = f"{origin[name]}::{name}"
            add(tid, name, kind, "backend", origin[name])
            by_name[name].append(node_id("test", tid))
            seen, stack = set(), [name]
            while stack:
                cur = stack.pop()
                if cur in seen:
                    continue
                seen.add(cur)
                stack.extend(calls.get(cur, ()))
            ops_d = direct_ops[name]
            ops_all = set().union(*(direct_ops.get(x, set()) for x in seen))
            for oid in sorted(ops_all):
                g.edge(node_id("test", tid), node_id("operation", oid), "covers", direct=oid in ops_d)
                op_cover[oid] += 1
            if kind == "go_rls":
                for t in sorted(set().union(*(direct_tables.get(x, set()) for x in seen))):
                    g.edge(node_id("test", tid), node_id("table", t), "covers")
                for fn in sorted(set().union(*(direct_fns.get(x, set()) for x in seen))):
                    if node_id("sql_function", "montra." + fn.lower()) in g.nodes:
                        g.edge(node_id("test", tid), node_id("sql_function", "montra." + fn.lower()), "covers")
    for f in sorted((ROOT / "backend").rglob("*_test.go")):
        if "backend/tests/" in rel(f):
            continue
        pkg_dir = f.parent.relative_to(ROOT / "backend")
        pkg = "/".join(pkg_dir.parts[1:]) if pkg_dir.parts[0] == "internal" else "/".join(pkg_dir.parts)
        for name in re.findall(r"^func ((?:Test|Fuzz)[A-Z_]\w*)\(", f.read_text(encoding="utf-8"), re.M):
            tid = f"{rel(f)}::{name}"
            add(tid, name, "go_unit", "backend", rel(f))
            by_name[name].append(node_id("test", tid))
            if node_id("package", pkg) in g.nodes:
                g.edge(node_id("test", tid), node_id("package", pkg), "covers")
    stats["ops_backend_tested"] = len(op_cover)
    stats["ops_without_backend_test"] = sorted(o["id"] for o in ctx["ops"] if o["id"] not in op_cover)

    # Web unit test files -> web features (by location and imports).
    web_root = ROOT / WEB_SRC
    for f in sorted(list(web_root.rglob("*.test.ts")) + list(web_root.rglob("*.test.tsx"))):
        text = f.read_text(encoding="utf-8")
        parts = f.relative_to(web_root).parts
        mods = {parts[1]} if parts[0] == "features" and len(parts) > 2 else {"_app" if parts[0] == "app" else "_shared"}
        mods |= set(re.findall(r"@/features/([\w-]+)/", text))
        tid = rel(f)
        add(tid, f.name, "web_unit", "web", rel(f), cases=len(re.findall(r"\b(?:it|test)\(\s*['\"`]", text)))
        for mod in sorted(m for m in mods if m in ctx["web_feats"]):
            g.edge(node_id("test", tid), node_id("web_feature", mod), "covers")

    # Web e2e: one node per test(); routes from goto(), operations from /api/v1 literals.
    for f in sorted((ROOT / "web/e2e").glob("*.spec.ts")):
        text = f.read_text(encoding="utf-8")
        for m in re.finditer(r"\btest\(\s*(['\"`])(.*?)\1\s*,", text, re.S):
            body = text[m.start():match_close(text, m.start() + 4)]
            tid = f"{rel(f)}::{m.group(2)}"
            add(tid, m.group(2), "web_e2e", "web", rel(f))
            for _q, p in re.findall(r"goto\(\s*(['\"`])(/[^'\"`]*)\1", body):
                p = re.sub(r"\$\{[^}]*\}", "{}", p)
                hits = [r for r in ctx["web_routes"] if path_key(r) == path_key(p)]
                if len(hits) == 1:
                    g.edge(node_id("test", tid), node_id("web_route", hits[0]), "covers")
            for am in re.finditer(r"/api/v1(/[^'\"`\s?)]*)", body):
                p = re.sub(r"\$\{[^}]*\}", "{}", am.group(1))
                around = body[max(0, am.start() - 60):am.end() + 160]
                mm = re.search(r"\.(get|post|put|patch|delete)\(\s*['\"`][^'\"`]*$", body[max(0, am.start() - 60):am.start()], re.I) \
                    or re.search(r"method\(\)\s*===\s*'(\w+)'|method:\s*'(\w+)'", around)
                method = next((x for x in (mm.groups() if mm else ()) if x), None)
                oid = match_op(method.upper() if method else None, p, op_index)
                if oid:
                    g.edge(node_id("test", tid), node_id("operation", oid), "covers")

    # Mobile unit test files and integration journeys.
    for f in sorted((ROOT / "mobile/test").rglob("*_test.dart")):
        text = f.read_text(encoding="utf-8")
        parts = f.relative_to(ROOT / "mobile/test").parts
        mods = {parts[1]} if parts[0] == "features" and len(parts) > 2 else set()
        mods |= set(re.findall(r"package:montra_mobile/features/(\w+)/", text))
        if re.search(r"package:montra_mobile/(?:core|l10n)/", text) or parts[0] == "core":
            mods.add("_core")
        if re.search(r"package:montra_mobile/app/", text) or parts[0] == "app":
            mods.add("_app")
        tid = rel(f)
        add(tid, f.name, "mobile_unit", "mobile", rel(f), cases=len(re.findall(r"\b(?:test|testWidgets)\(\s*'", text)))
        for mod in sorted(m for m in mods if m in ctx["mobile_feats"]):
            g.edge(node_id("test", tid), node_id("mobile_feature", mod), "covers")
    for f in sorted((ROOT / "mobile/integration_test").glob("*_test.dart")):
        text = f.read_text(encoding="utf-8")
        for m in re.finditer(r"\btestWidgets\(\s*((?:'[^']*'\s*)+),", text):
            title = "".join(re.findall(r"'([^']*)'", m.group(1)))
            add(f"{rel(f)}::{title}", title, "mobile_integration", "mobile", rel(f))

    # Requirements -> tests (test names and test file names in the row).
    for r in ctx["reqs"]:
        rid = node_id("requirement", r["id"])
        if rid not in g.nodes:
            continue
        row = " ".join([r["tests"], r["evidence"], r["text"]])
        targets = set()
        for name in set(re.findall(r"\b((?:Test|Fuzz)[A-Z_]\w*)", row)):
            targets.update(by_name.get(name, []))
            if name not in by_name:
                stats["requirement_tests_unresolved"].append(f"{r['id']}: {name}")
        for fname in set(re.findall(r"[\w.-]+(?:\.test\.tsx?|\.spec\.ts|_test\.dart|_test\.go)\b", row)):
            targets.update(by_file.get(fname, []))
        for t in sorted(targets):
            g.edge(rid, t, "verified_by")
    out = dict(kinds)
    out["by_name"] = by_name
    return out


def build_flows(g, stats, ctx, curated, op_index, tests):
    kinds = {"web": "web_route", "mobile": "mobile_route", "ops": "operation", "reads": "table", "writes": "table",
             "events": "event", "jobs": "job", "notifications": "notification_type", "policies": "policy"}
    etype = {"web": "shown_on", "mobile": "shown_on", "ops": "calls", "reads": "reads", "writes": "writes",
             "events": "emits", "jobs": "runs", "notifications": "sends", "policies": "uses"}
    e2e_titles = {}
    for kind in ("kind:web_e2e", "kind:mobile_integration"):
        for tid in tests.get(kind, []):
            e2e_titles[tid] = g.nodes[tid]["label"]
    for j in curated["journeys"]:
        fid = node_id("flow", j["id"])
        dom = node_id("feature", j["domain"])
        _require(g, dom, j["id"])
        g.node("flow", j["id"], f"Journey {j['number']}: {j['title']}", source="spec §14", number=j["number"],
               status=j.get("status", "implemented"), note=j.get("note"))
        g.edge(fid, dom, "belongs_to")
        prev = None
        for i, step in enumerate(j["steps"], 1):
            sid = node_id("step", f"{j['id']}/{i:02d}")
            g.node("step", f"{j['id']}/{i:02d}", step["title"], order=i, flow=fid)
            g.edge(fid, sid, "has_step", order=i)
            if prev:
                g.edge(prev, sid, "next")
            prev = sid
            for field, kind in kinds.items():
                for ref in step.get(field, []):
                    target = node_id(kind, ref)
                    _require(g, target, f"{j['id']} step {i} {field}")
                    g.edge(sid, target, etype[field])
        for test in j.get("tests", []):
            tid = node_id("test", test)
            _require(g, tid, f"{j['id']} tests")
            g.edge(tid, fid, "verifies", via="curated")
    # Journey numbers named in e2e test titles, e.g. "(journeys 4 and 5)" or "12. import ...".
    journey_ids = {j["number"]: node_id("flow", j["id"]) for j in curated["journeys"]}
    for tid, title in sorted(e2e_titles.items()):
        nums = set()
        for grp in re.findall(r"\bjourneys?\s+([\d,\sand–-]+)", title):
            nums.update(int(x) for x in re.findall(r"\d+", grp))
        lead = re.match(r"(\d+)\.\s", title)
        if lead:
            nums.add(int(lead.group(1)))
        for n in sorted(nums):
            if n in journey_ids:
                g.edge(tid, journey_ids[n], "verifies", via="title")

    # Feature flows from docs/FEATURES.md §3 (resolved automatically).
    if not (ROOT / FEATURES_DOC).exists():
        stats["feature_flows_missing"].append(FEATURES_DOC)
        return
    area_domains = curated["feature_area_domains"]
    names = dict(
        table=set(ctx["table_names"]), job=set(ctx["jobs"]), event=set(ctx["events"]),
    )
    notif_by_cat = defaultdict(list)
    for nid, n in g.nodes.items():
        if n["type"] == "notification_type":
            notif_by_cat[n["props"]["category"]].append(nid)
    config_keys = {n["label"] for n in g.nodes.values() if n["type"] == "config"}
    flows = parse_feature_flows(read(FEATURES_DOC))
    seen_nums = set()
    for fl in flows:
        num = fl["num"]
        seen_nums.add(num)
        if num not in area_domains:
            raise GraphError(f"{FEATURES_DOC} §{num} ({fl['title']}) is not in feature_area_domains in {CURATED}")
        key = "feature-" + num
        fid = node_id("flow", key)
        deferred = "deferred" in fl["title"].lower()
        g.node("flow", key, f"§{num} {fl['title']}", source=f"{FEATURES_DOC} §{num}",
               status="deferred" if deferred else "implemented", steps=len(fl["steps"]))
        _require(g, node_id("feature", area_domains[num]), f"feature_area_domains {num}")
        g.edge(fid, node_id("feature", area_domains[num]), "belongs_to")
        prev, last_path = None, None
        step_ops = set()
        for i, text in enumerate(fl["steps"], 1):
            title = re.sub(r"\*\*(.+?)\*\*", r"\1", text)
            title = re.sub(r"\s+", " ", title)
            short = title if len(title) <= 160 else title[:157].rsplit(" ", 1)[0] + " …"
            sid = node_id("step", f"{key}/{i:02d}")
            g.node("step", f"{key}/{i:02d}", short, order=i, flow=fid)
            g.edge(fid, sid, "has_step", order=i)
            if prev:
                g.edge(prev, sid, "next")
            prev = sid
            before = len(g.edges)
            found, unresolved, last_path = resolve_mentions(text, op_index, last_path)
            for oid, _raw in found:
                g.edge(sid, node_id("operation", oid), "calls")
                step_ops.add(oid)
            stats["flow_steps_unresolved"] += [f"§{num}.{i}: {u}" for u in unresolved]
            for t in sorted(ticked_names(text, names["table"])):
                g.edge(sid, node_id("table", t), "involves")
            for jb in sorted(ticked_names(text, names["job"])):
                g.edge(sid, node_id("job", jb), "runs")
            for ev in sorted(ticked_names(text, names["event"])):
                g.edge(sid, node_id("event", ev), "emits")
            for ck in sorted(ticked_names(text, config_keys) | set(re.findall(r"`([A-Z][A-Z0-9_]+)=", text)) & config_keys):
                g.edge(sid, node_id("config", ck), "involves")
            for pkg in sorted(code_packages(text, ctx["packages"])):
                g.edge(sid, node_id("package", pkg), "involves")
            for cat in re.findall(r"`(\w+)`\s+notifications?\b", text):
                for nt in sorted(notif_by_cat.get(cat, [])):
                    g.edge(sid, nt, "sends")
            stats["flow_steps_total"].append(sid)
            if len(g.edges) > before:
                stats["flow_steps_resolved"].append(sid)
        # Flow-level: endpoint table, client routes, data and background work.
        for oid, _raw in resolve_mentions(fl["endpoints"], op_index)[0]:
            if oid not in step_ops:
                g.edge(fid, node_id("operation", oid), "calls")
        for section, kind in (("web", "web_route"), ("mobile", "mobile_route")):
            routes = ctx["web_routes"] if kind == "web_route" else ctx["mobile_routes"]
            found, unresolved = route_mentions(fl[section], routes)
            for r in sorted(found):
                g.edge(fid, node_id(kind, r), "shown_on")
            stats["flow_routes_unresolved"] += [f"§{num} {section}: {u}" for u in unresolved]
        for t in sorted(ticked_names(fl["data"], names["table"])):
            g.edge(fid, node_id("table", t), "involves")
        for jb in sorted(ticked_names(fl["background"], names["job"])):
            g.edge(fid, node_id("job", jb), "runs")
        for ev in sorted(ticked_names(fl["background"], names["event"])):
            g.edge(fid, node_id("event", ev), "emits")
    for num in sorted(set(area_domains) - seen_nums):
        stats["feature_area_domains_stale"].append(num)
    resolved = set(stats["flow_steps_resolved"])
    stats["flow_steps_prose_only"] = [x[5:] for x in stats["flow_steps_total"] if x not in resolved]


# --------------------------------------------------------------- validation
def validate(data):
    ids = [n["id"] for n in data["nodes"]]
    dupes = sorted(k for k, v in Counter(ids).items() if v > 1)
    if dupes:
        raise GraphError("duplicate node ids: " + ", ".join(dupes[:10]))
    known = set(ids)
    for n in data["nodes"]:
        if n["type"] not in NODE_TYPES:
            raise GraphError(f"unknown node type {n['type']} ({n['id']})")
        if not n["id"].startswith(NODE_PREFIX[n["type"]]):
            raise GraphError(f"node {n['id']} does not use the {NODE_PREFIX[n['type']]} prefix")
    linked = set()
    for e in data["edges"]:
        if e["type"] not in EDGE_TYPES:
            raise GraphError(f"unknown edge type {e['type']}")
        for end in (e["source"], e["target"]):
            if end not in known:
                raise GraphError(f"edge {e['source']} -{e['type']}-> {e['target']}: {end} is not a node")
            linked.add(end)
    orphans = sorted(known - linked)
    if orphans:
        raise GraphError(f"{len(orphans)} orphan node(s) with no edge: " + ", ".join(orphans[:20]))


# ------------------------------------------------------------------ outputs
def graph_data(g):
    nodes = sorted(g.nodes.values(), key=lambda n: n["id"])
    edges = sorted(g.edges.values(), key=lambda e: (e["source"], e["type"], e["target"]))
    counts = dict(
        nodes=len(nodes), edges=len(edges),
        node_types=dict(sorted(Counter(n["type"] for n in nodes).items())),
        edge_types=dict(sorted(Counter(e["type"] for e in edges).items())),
    )
    data = dict(schema_version=SCHEMA_VERSION, generated_from=GENERATED_FROM, counts=counts, nodes=nodes, edges=edges)
    validate(data)
    return data


def dumps(v):
    return json.dumps(v, sort_keys=True, ensure_ascii=False)


def render_json(data, stamp=None):
    lines = ["{"]
    lines.append(f' "schema_version": {dumps(data["schema_version"])},')
    if stamp:
        lines.append(f' "generated_at": {dumps(stamp)},')
    lines.append(f' "generated_from": {dumps(data["generated_from"])},')
    lines.append(f' "counts": {dumps(data["counts"])},')
    for key in ("nodes", "edges"):
        lines.append(f' "{key}": [')
        items = data[key]
        for i, item in enumerate(items):
            ordered = ({"id": item["id"], "type": item["type"], "label": item["label"], "props": item["props"]}
                       if key == "nodes" else
                       {"source": item["source"], "target": item["target"], "type": item["type"], "props": item["props"]})
            body = json.dumps(ordered, ensure_ascii=False)
            # keep key order of the record but sort props for stable diffs
            body = body.replace(json.dumps(item["props"], ensure_ascii=False), dumps(item["props"]))
            lines.append("  " + body + ("," if i < len(items) - 1 else ""))
        lines.append(" ]" + ("," if key == "nodes" else ""))
    lines.append("}")
    return "\n".join(lines) + "\n"


def render_schema():
    node_types = sorted(NODE_TYPES)
    edge_types = sorted(EDGE_TYPES)
    id_pattern = "^(" + "|".join(re.escape(NODE_PREFIX[t]) for t in node_types) + ").+$"
    schema = {
        "$schema": "https://json-schema.org/draft/2020-12/schema",
        "$id": "https://montra.local/docs/knowledge-graph/graph.schema.json",
        "title": "Montra knowledge graph",
        "description": "Generated by scripts/docs/gen_knowledge_graph.py. Node and edge types are "
                       "closed lists; see docs/KNOWLEDGE_GRAPH.md for definitions.",
        "type": "object",
        "required": ["schema_version", "generated_from", "counts", "nodes", "edges"],
        "additionalProperties": False,
        "properties": {
            "schema_version": {"type": "string", "pattern": r"^\d+\.\d+\.\d+$"},
            "generated_at": {"type": "string", "description": "Only with --stamp."},
            "generated_from": {"type": "array", "items": {"type": "string"}},
            "counts": {
                "type": "object",
                "required": ["nodes", "edges", "node_types", "edge_types"],
                "properties": {
                    "nodes": {"type": "integer", "minimum": 0},
                    "edges": {"type": "integer", "minimum": 0},
                    "node_types": {"type": "object", "propertyNames": {"enum": node_types},
                                   "additionalProperties": {"type": "integer"}},
                    "edge_types": {"type": "object", "propertyNames": {"enum": edge_types},
                                   "additionalProperties": {"type": "integer"}},
                },
            },
            "nodes": {"type": "array", "items": {"$ref": "#/$defs/node"}},
            "edges": {"type": "array", "items": {"$ref": "#/$defs/edge"}},
        },
        "$defs": {
            "node": {
                "type": "object",
                "required": ["id", "type", "label", "props"],
                "additionalProperties": False,
                "properties": {
                    "id": {"type": "string", "pattern": id_pattern},
                    "type": {"enum": node_types},
                    "label": {"type": "string"},
                    "props": {"type": "object"},
                },
            },
            "edge": {
                "type": "object",
                "required": ["source", "target", "type", "props"],
                "additionalProperties": False,
                "properties": {
                    "source": {"type": "string", "pattern": id_pattern},
                    "target": {"type": "string", "pattern": id_pattern},
                    "type": {"enum": edge_types},
                    "props": {"type": "object"},
                },
            },
        },
    }
    return json.dumps(schema, indent=1, sort_keys=False, ensure_ascii=False) + "\n"


def cypher_value(v):
    if isinstance(v, bool):
        return "true" if v else "false"
    if isinstance(v, (int, float)):
        return str(v)
    if isinstance(v, list) and all(isinstance(x, (str, int, float, bool)) for x in v):
        return "[" + ", ".join(cypher_value(x) for x in v) + "]"
    if isinstance(v, dict):
        return cypher_map(v)
    if isinstance(v, list):
        v = dumps(v)
    s = str(v).replace("\\", "\\\\").replace("'", "\\'").replace("\n", "\\n")
    return "'" + s + "'"


def neo_props(props):
    """Neo4j properties must be scalars or lists of scalars: nest as JSON text."""
    out = {}
    for k, v in props.items():
        flat = isinstance(v, list) and all(isinstance(x, (str, int, float, bool)) for x in v)
        out[k] = dumps(v) if isinstance(v, (dict, list)) and not flat else v
    return out


def cypher_map(d):
    return "{" + ", ".join(f"`{k}`: {cypher_value(v)}" for k, v in sorted(d.items())) + "}"


def render_cypher(data):
    out = [
        "// Montra knowledge graph: Neo4j import generated by scripts/docs/gen_knowledge_graph.py.",
        "// Idempotent (MERGE). Run with: cypher-shell -f docs/knowledge-graph/graph.cypher",
        "// Every node also carries the :Entity label so edges can MATCH on one indexed id.",
        "CREATE CONSTRAINT entity_id IF NOT EXISTS FOR (n:Entity) REQUIRE n.id IS UNIQUE;",
    ]
    by_type = defaultdict(list)
    for n in data["nodes"]:
        by_type[n["type"]].append(n)
    for t in sorted(by_type):
        rows = by_type[t]
        for i in range(0, len(rows), 250):
            chunk = rows[i:i + 250]
            items = ",\n  ".join(cypher_map(dict(id=n["id"], props=neo_props(dict(n["props"], label=n["label"], type=n["type"]))))
                                 for n in chunk)
            out.append(f"UNWIND [\n  {items}\n] AS row\nMERGE (n:Entity {{id: row.id}})\n"
                       f"SET n:{NODE_LABELS[t]}, n += row.props;")
    by_edge = defaultdict(list)
    for e in data["edges"]:
        by_edge[e["type"]].append(e)
    for t in sorted(by_edge):
        rows = by_edge[t]
        for i in range(0, len(rows), 500):
            chunk = rows[i:i + 500]
            items = ",\n  ".join(cypher_map(dict(s=e["source"], t=e["target"], props=neo_props(e["props"]))) for e in chunk)
            out.append(f"UNWIND [\n  {items}\n] AS row\nMATCH (a:Entity {{id: row.s}}), (b:Entity {{id: row.t}})\n"
                       f"MERGE (a)-[r:{t.upper()}]->(b)\nSET r += row.props;")
    return "\n".join(out) + "\n"


CYPHER_STARTS = ("CREATE ", "UNWIND ", "MATCH ", "MERGE ")


def check_cypher(text):
    """Syntactic check of the Cypher import: returns the statement count or raises GraphError.

    Strings ('...' with backslash escapes) and backtick names must close,
    brackets must balance outside them, every statement must end with ';'
    and start with CREATE, UNWIND, MATCH or MERGE; UNWIND batches must bind
    `AS row` and MERGE. This is not a Cypher parser; it catches the escaping
    and nesting errors a generator can make.
    """
    pairs = {")": "(", "]": "[", "}": "{"}
    stack, i, n, start, count, line = [], 0, len(text), 0, 0, 1
    while i < n:
        c = text[i]
        if c == "\n":
            line += 1
        if text.startswith("//", i) and not stack:
            j = text.find("\n", i)
            i = n if j < 0 else j
            continue
        if c in "'`":
            j = i + 1
            while j < n and text[j] != c:
                if c == "'" and text[j] == "\\":
                    j += 1
                elif text[j] == "\n":
                    raise GraphError(f"graph.cypher line {line}: unterminated {c} string")
                j += 1
            if j >= n:
                raise GraphError(f"graph.cypher line {line}: unterminated {c} string")
            i = j + 1
            continue
        if c in "([{":
            stack.append(c)
        elif c in ")]}":
            if not stack or stack.pop() != pairs[c]:
                raise GraphError(f"graph.cypher line {line}: unbalanced {c!r}")
        elif c == ";":
            if stack:
                raise GraphError(f"graph.cypher line {line}: ';' inside brackets")
            stmt = re.sub(r"^(?://[^\n]*\n|\s)+", "", text[start:i])
            if not stmt.startswith(CYPHER_STARTS):
                raise GraphError(f"graph.cypher line {line}: unexpected statement {stmt[:40]!r}")
            if stmt.startswith("UNWIND ") and (" AS row" not in stmt or "MERGE " not in stmt):
                raise GraphError(f"graph.cypher line {line}: UNWIND batch without AS row / MERGE")
            count += 1
            start = i + 1
        i += 1
    if stack:
        raise GraphError("graph.cypher: unclosed " + "".join(stack))
    if re.sub(r"(?://[^\n]*\n|\s)+", "", text[start:]):
        raise GraphError("graph.cypher: trailing text after the last ';'")
    return count


def render_graphml(data):
    out = [
        '<?xml version="1.0" encoding="UTF-8"?>',
        '<graphml xmlns="http://graphml.graphdrawing.org/xmlns">',
        '  <key id="label" for="node" attr.name="label" attr.type="string"/>',
        '  <key id="ntype" for="node" attr.name="type" attr.type="string"/>',
        '  <key id="nprops" for="node" attr.name="props" attr.type="string"/>',
        '  <key id="etype" for="edge" attr.name="type" attr.type="string"/>',
        '  <key id="eprops" for="edge" attr.name="props" attr.type="string"/>',
        '  <graph id="montra" edgedefault="directed">',
    ]
    attr = {'"': "&quot;"}
    for n in data["nodes"]:
        out.append(f'    <node id={xml_q(n["id"], attr)}><data key="label">{xml_escape(n["label"])}</data>'
                   f'<data key="ntype">{n["type"]}</data><data key="nprops">{xml_escape(dumps(n["props"]))}</data></node>')
    for e in data["edges"]:
        out.append(f'    <edge source={xml_q(e["source"], attr)} target={xml_q(e["target"], attr)}>'
                   f'<data key="etype">{e["type"]}</data><data key="eprops">{xml_escape(dumps(e["props"]))}</data></edge>')
    out += ["  </graph>", "</graphml>"]
    return "\n".join(out) + "\n"


def xml_q(s, attr):
    return '"' + xml_escape(s, attr) + '"'


# --------------------------------------------------------------- doc blocks
def doc_sections(data, stats):
    nodes = {n["id"]: n for n in data["nodes"]}
    out_e, in_e = defaultdict(list), defaultdict(list)
    for e in data["edges"]:
        out_e[e["source"]].append(e)
        in_e[e["target"]].append(e)

    def targets(nid, etype, prefix=""):
        return sorted(e["target"] for e in out_e[nid] if e["type"] == etype and e["target"].startswith(prefix))

    def sources(nid, etype, prefix=""):
        return sorted(e["source"] for e in in_e[nid] if e["type"] == etype and e["source"].startswith(prefix))

    sections = {}
    # Counts.
    c = data["counts"]
    lines = [f"**{c['nodes']} nodes, {c['edges']} edges.**", "", "| Node type | Count | Edge type | Count |", "|---|---|---|---|"]
    nt, et = list(c["node_types"].items()), list(c["edge_types"].items())
    for i in range(max(len(nt), len(et))):
        a = nt[i] if i < len(nt) else ("", "")
        b = et[i] if i < len(et) else ("", "")
        lines.append(f"| {('`' + a[0] + '`') if a[0] else ''} | {a[1]} | {('`' + b[0] + '`') if b[0] else ''} | {b[1]} |")
    sections["counts"] = "\n".join(lines)

    # Domain table.
    features = sorted(nid for nid in nodes if nid.startswith("feature:"))
    rows = ["| Domain | Backend packages | Ops | Tables | Jobs | Web features | Mobile features | Requirements (status counts) |",
            "|---|---|---|---|---|---|---|---|"]
    statuses = ["VERIFIED", "TESTED", "IMPLEMENTED", "IN_PROGRESS", "NOT_STARTED", "BLOCKED"]
    short = dict(VERIFIED="V", TESTED="T", IMPLEMENTED="I", IN_PROGRESS="P", NOT_STARTED="N", BLOCKED="B")
    edges_between = Counter()
    for f in features:
        key = f.split(":", 1)[1]
        pkgs = [p.split(":", 1)[1] for p in targets(f, "includes", "pkg:")]
        ops = sources(f, "belongs_to", "op:")
        tabs = sources(f, "belongs_to", "table:")
        jobs = sources(f, "belongs_to", "job:")
        web = [w.split(":", 1)[1] for w in targets(f, "includes", "web:")]
        mob = [m.split(":", 1)[1] for m in targets(f, "includes", "mobile:")]
        reqs = sources(f, "belongs_to", "req:")
        sc = Counter(nodes[r]["props"].get("status") for r in reqs)
        status = " ".join(f"{short.get(s, s)}{sc[s]}" for s in statuses if sc[s]) or "–"
        if key == "platform":
            pkg_cell = f"{len(pkgs)} (cmd/*, platform/*, store, testutil, …)"
        else:
            pkg_cell = ", ".join(f"`{p}`" for p in pkgs) or "–"
        rows.append(f"| **{nodes[f]['label']}** (`{key}`) | {pkg_cell} | {len(ops)} | {len(tabs)} | {len(jobs)} | "
                    f"{', '.join(web) or '–'} | {', '.join(mob) or '–'} | {len(reqs)}: {status} |")
    rows += ["", "Status letters: V verified, T tested, I implemented, P in progress, N not started, B blocked. "
             "Ops are counted by contract tag, tables by owning package (the one that inserts most, then "
             "updates, reads), jobs by the package that handles them, requirements by ID prefix."]
    sections["domains"] = "\n".join(rows)

    sections["overview"] = render_mermaid(data, nodes, features, out_e, in_e, sources)

    # Example query answers (kept in sync with the jq examples).
    ex = []
    bud_reads = sorted({e["target"].split(":", 1)[1] for e in data["edges"] if e["source"] == "pkg:budgets" and e["type"] in ("reads", "writes")})
    bud_writes = sorted({e["target"].split(":", 1)[1] for e in data["edges"] if e["source"] == "pkg:budgets" and e["type"] == "writes"})
    ex.append(f"- Tables `pkg:budgets` touches ({len(bud_reads)}): " + ", ".join(f"`{t}`" for t in bud_reads))
    ex.append(f"  - of which it writes ({len(bud_writes)}): " + ", ".join(f"`{t}`" for t in bud_writes))
    web_called = {e["target"] for e in data["edges"] if e["type"] == "calls" and e["source"].startswith("web:")}
    mob_called = {e["target"] for e in data["edges"] if e["type"] == "calls" and e["source"].startswith("mobile:")}
    called = web_called | mob_called
    orphan = sorted(n["id"] for n in data["nodes"] if n["type"] == "operation" and n["id"] not in called)
    ops_all = [n["id"] for n in data["nodes"] if n["type"] == "operation"]
    ex.append(f"- Operations with no web or mobile caller: **{len(orphan)}** of {len(ops_all)} "
              f"(web calls {len(web_called)}, mobile calls {len(mob_called)}, both {len(web_called & mob_called)}). "
              f"By tag: " + ", ".join(f"{t} {n}" for t, n in sorted(Counter(nodes[o]['props']['tag'] for o in orphan).items())))
    grp = sorted((n for n in data["nodes"] if n["type"] == "requirement" and
                  any(e["type"] == "belongs_to" and e["target"] == "feature:groups" for e in out_e[n["id"]]) and
                  n["props"].get("status") != "VERIFIED"), key=lambda n: n["id"])
    ex.append(f"- Requirements of `feature:groups` not VERIFIED ({len(grp)}): " +
              ", ".join(f"`{n['id']}` {n['props'].get('status')}" for n in grp))
    tested = {e["target"] for e in data["edges"] if e["type"] == "covers" and e["target"].startswith("op:")
              and nodes[e["source"]]["props"].get("kind") == "go_api"}
    untested = sorted(o for o in ops_all if o not in tested)
    ex.append(f"- Operations with no backend API test: **{len(untested)}** of {len(ops_all)} "
              f"({len(ops_all) - len(untested)} covered by `backend/tests/api`): " + ", ".join(f"`{o[3:]}`" for o in untested))
    chain = []
    for e in sorted(out_e["event:transaction.created"], key=lambda x: x["target"]):
        if e["type"] == "triggers":
            job = e["target"]
            pk = [x["target"] for x in out_e[job] if x["type"] == "handled_in"]
            sends = sorted(x["target"] for x in out_e[job] if x["type"] == "sends")
            chain.append(f"`{job}` (handled in {', '.join(f'`{p}`' for p in pk)}; sends {', '.join(f'`{n}`' for n in sends) or 'nothing'})")
    emitters = sorted(e["source"] for e in in_e["event:transaction.created"] if e["type"] == "emits" and e["source"].startswith("pkg:"))
    ex.append(f"- `event:transaction.created` is emitted by {', '.join(f'`{p}`' for p in emitters)} and triggers " + "; ".join(chain))
    pols = sorted(e["source"] for e in in_e["table:transactions"] if e["type"] == "protects")
    pol_fns = sorted({x["target"] for p in pols for x in out_e[p] if x["type"] == "uses"})
    ex.append(f"- Policies protecting `table:transactions`: " + ", ".join(f"`{p}`" for p in pols) +
              "; they use " + ", ".join(f"`{f}`" for f in pol_fns))
    st_cfg = sorted(e["target"] for e in out_e["provider:appwrite"] if e["type"] == "configured_by")
    ex.append(f"- `provider:appwrite` ({nodes['provider:appwrite']['props'].get('status')}) is configured by " +
              ", ".join(f"`{c[7:]}`" for c in st_cfg))
    sections["examples"] = "\n".join(ex)

    sections["flows"] = render_flow_tables(data, nodes, out_e, in_e)
    sections["flowdiagrams"] = "\n\n".join(render_flow_diagram(fid, title, nodes, out_e) for fid, title in FLOW_DIAGRAMS)

    # Extraction gaps.
    gap = []
    labels = [
        ("ops_without_package", "Operations with no `httpx.Op` match"),
        ("web_unmatched_calls", "Web API calls that match no contract operation"),
        ("mobile_unmatched_calls", "Mobile `ApiEndpoints` uses that match no contract operation"),
        ("mobile_endpoints_not_in_contract", "Mobile endpoints missing from the contract"),
        ("web_routes_without_feature", "Web routes with no feature module"),
        ("web_paths_without_route", "`paths.ts` constants with no router entry"),
        ("mobile_routes_without_feature", "Mobile routes whose screen class was not found"),
        ("tables_without_package", "Tables no Go SQL literal references"),
        ("events_without_emitter", "Routed events with no literal `outbox.Emit` (emitted with a computed type)"),
        ("events_without_route", "Emitted events with no `relay.On` route"),
        ("routes_to_unknown_jobs", "Relay routes to unregistered jobs"),
        ("jobs_missing_from_doc", "Jobs missing from docs/BACKGROUND_JOBS.md"),
        ("dynamic_emits", "`outbox.Emit` calls with a non-constant type"),
        ("location_unresolved", "Requirement Location tokens with no node (kept in `props.location_unresolved`)"),
        ("deps_unresolved", "Requirement Deps tokens with no node"),
        ("duplicate_requirements", "Duplicate requirement IDs (first row kept)"),
        ("redirects_unresolved", "Redirect routes whose target matches no route"),
        ("flow_steps_unresolved", "`METHOD /path` mentions in FEATURES.md flows that match no operation"),
        ("flow_steps_prose_only", "FEATURES.md flow steps with no resolvable reference (prose only)"),
        ("flow_routes_unresolved", "Routes in FEATURES.md Web/Mobile sections that match no route"),
        ("feature_area_domains_stale", "`feature_area_domains` entries with no FEATURES.md section"),
        ("test_calls_unresolved", "Backend test `c.Do` calls whose path could not be resolved"),
        ("requirement_tests_unresolved", "Test names in requirement rows with no test function"),
        ("notifications_without_link", "Notification types whose category has no web page"),
    ]
    gap += ["| Check | Count | Items |", "|---|---|---|"]
    for key, label in labels:
        items = stats.get(key, [])
        if key == "location_unresolved":
            cnt = Counter(items)
            shown_items = ", ".join(f"`{k}`×{v}" if v > 1 else f"`{k}`" for k, v in sorted(cnt.items()))
        else:
            shown_items = ", ".join(f"`{i}`" for i in sorted(set(items)))
        gap.append(f"| {label} | {len(items)} | {shown_items or '–'} |")
    sections["gaps"] = "\n".join(gap)
    return sections


# Domains most others use; arrows into them are summarised in the caption.
SHARED_DOMAINS = ("platform", "identity", "notifications", "fx")


def render_mermaid(data, nodes, features, out_e, in_e, sources):
    """Domain overview: Go imports, cross-domain SQL writes and event routes."""
    dom_of = {}
    for f in features:
        for e in out_e[f]:
            if e["type"] == "includes":
                dom_of[e["target"]] = f.split(":", 1)[1]
        for e in in_e[f]:
            if e["type"] == "belongs_to" and e["source"].startswith("table:"):
                dom_of[e["source"]] = f.split(":", 1)[1]
    emitter = defaultdict(set)
    for e in data["edges"]:
        if e["type"] == "emits" and e["source"] in dom_of:
            emitter[e["target"]].add(dom_of[e["source"]])
    job_dom = {e["source"]: e["target"].split(":", 1)[1] for e in data["edges"]
               if e["type"] == "belongs_to" and e["source"].startswith("job:")}
    links = defaultdict(set)
    for e in data["edges"]:
        if e["type"] == "depends_on" and e["source"].startswith("pkg:") and e["target"].startswith("pkg:"):
            pairs = [(dom_of.get(e["source"]), dom_of.get(e["target"]), "imports")]
        elif e["type"] == "writes":
            pairs = [(dom_of.get(e["source"]), dom_of.get(e["target"]), "writes")]
        elif e["type"] == "triggers":
            pairs = [(a, job_dom.get(e["target"]), "events") for a in emitter.get(e["source"], ())]
        else:
            continue
        for a, b, kind in pairs:
            if not a or not b or a == b or a == "platform" or b in SHARED_DOMAINS:
                continue
            if a == "privacy" and kind == "writes":
                continue  # account deletion erases rows everywhere
            links[(a, b)].add(kind)
    users = Counter()
    for e in data["edges"]:
        if e["type"] == "depends_on" and e["source"].startswith("pkg:") and e["target"].startswith("pkg:"):
            a, b = dom_of.get(e["source"]), dom_of.get(e["target"])
            if a and b and a != b and b in SHARED_DOMAINS and a != "platform":
                users[(b, a)] += 1
    mer = ["```mermaid", "flowchart LR"]
    by_area = defaultdict(list)
    for key, d in DOMAINS.items():
        by_area[d["area"]].append(key)
    for i, area in enumerate(sorted(by_area)):
        mer.append(f'  subgraph area{i}["{area}"]')
        for key in sorted(by_area[area]):
            n_ops = len(sources("feature:" + key, "belongs_to", "op:"))
            mer.append(f'    {key}["{DOMAINS[key]["label"]}<br/>{n_ops} ops"]')
        mer.append("  end")
    for (a, b), kinds in sorted(links.items()):
        label = "+".join(k for k in ("imports", "writes", "events") if k in kinds and k != "imports")
        mer.append(f"  {a} -->|{label}| {b}" if label else f"  {a} --> {b}")
    mer.append("```")
    shared = "; ".join(
        f"`{d}` is used by {len({a for (b, a) in users if b == d})} domains" for d in SHARED_DOMAINS if d != "platform")
    return "\n".join(mer + [
        "",
        "Arrows: the source domain's Go packages import the target's packages (plain), write SQL into "
        "tables the target owns (`writes`), or emit outbox events that trigger the target's jobs (`events`). "
        f"Not drawn: arrows into the shared domains ({shared}; every domain uses `platform`), "
        "`platform`'s own wiring (`cmd/*`, `app`), and `privacy` deleting rows in every domain.",
    ])


GENERATED_BLOCK = re.compile(r"<!-- BEGIN GENERATED: knowledge graph .*?<!-- END GENERATED: knowledge graph [a-z]+ -->", re.S)


# Journeys drawn as Mermaid diagrams in KNOWLEDGE_GRAPH.md.
FLOW_DIAGRAMS = [
    (["flow:journey-04"], "Add an expense (journey 4)"),
    (["flow:journey-15", "flow:journey-16", "flow:journey-17"], "A group expense through settlement (journeys 15-17)"),
    (["flow:journey-08"], "A budget alert (journey 8)"),
    (["flow:journey-23"], "A data export (journey 23)"),
]


def _steps(fid, out_e):
    return [e["target"] for e in sorted((e for e in out_e[fid] if e["type"] == "has_step"),
                                        key=lambda e: e["props"].get("order", 0))]


def render_flow_tables(data, nodes, out_e, in_e):
    rows = ["| Domain | Flow | Status | Steps | Ops | Tables | Jobs | Notifications | Verified by tests |",
            "|---|---|---|---|---|---|---|---|---|"]
    flows = sorted((n for n in data["nodes"] if n["type"] == "flow"),
                   key=lambda n: ([e["target"] for e in out_e[n["id"]] if e["type"] == "belongs_to"][0], n["id"]))
    for n in flows:
        fid = n["id"]
        dom = [e["target"][8:] for e in out_e[fid] if e["type"] == "belongs_to"][0]
        steps = _steps(fid, out_e)
        reach = [fid] + steps
        def tgt(etypes, prefix):
            return {e["target"] for s in reach for e in out_e[s] if e["type"] in etypes and e["target"].startswith(prefix)}
        tests = sorted({e["source"] for e in in_e[fid] if e["type"] == "verifies"})
        rows.append(f"| {dom} | `{fid[5:]}` {n['label']} | {n['props'].get('status')} | {len(steps)} | "
                    f"{len(tgt(('calls',), 'op:'))} | {len(tgt(('reads', 'writes', 'involves'), 'table:'))} | "
                    f"{len(tgt(('runs',), 'job:'))} | {len(tgt(('sends',), 'notif:'))} | {len(tests)} |")
    return "\n".join(rows + ["", "Journeys (`journey-NN`, spec §14) are curated in `scripts/docs/kg_curated.json`; "
                             "feature flows (`feature-3.N`) are read from the numbered steps of `docs/FEATURES.md` §3. "
                             "Counts include the flow's own links (endpoint table, Data and Background work sections)."])


def render_flow_diagram(fids, title, nodes, out_e):
    lines = [f"**{title}**", "", "```mermaid", "flowchart TD"]
    ids, prev = {}, None

    def nid(target, shape):
        if target not in ids:
            ids[target] = f"n{len(ids)}"
            label = nodes[target]["label"].replace('"', "'")
            if target.startswith("op:"):
                label = nodes[target]["label"]
            lines.append(f'  {ids[target]}{shape[0]}"{label}"{shape[1]}')
        return ids[target]

    k = 0
    for fid in fids:
        for sid in _steps(fid, out_e):
            k += 1
            ops = [e["target"] for e in out_e[sid] if e["type"] == "calls"]
            label = f"{k}. {nodes[sid]['label']}".replace('"', "'")
            if ops:
                label += "<br/>" + "<br/>".join(nodes[o]["label"] for o in ops[:3]) + (" …" if len(ops) > 3 else "")
            ids[sid] = f"s{k}"
            lines.append(f'  s{k}["{label}"]')
            if prev:
                lines.append(f"  {prev} --> s{k}")
            prev = f"s{k}"
            for e in sorted(out_e[sid], key=lambda e: e["target"]):
                t, typ = e["target"], e["type"]
                if typ == "writes":
                    lines.append(f"  s{k} -.->|writes| {nid(t, ('[(', ')]'))}")
                elif typ == "emits":
                    lines.append(f"  s{k} -.->|emits| {nid(t, ('>', ']'))}")
                elif typ == "runs":
                    lines.append(f"  s{k} -.->|runs| {nid(t, ('[[', ']]'))}")
                elif typ == "sends":
                    lines.append(f"  s{k} -.->|notifies| {nid(t, ('{{', '}}'))}")
    for ev in [t for t in ids if t.startswith("event:")]:
        for e in out_e[ev]:
            if e["type"] == "triggers" and e["target"] in ids:
                lines.append(f"  {ids[ev]} --> {ids[e['target']]}")
    lines.append("```")
    return "\n".join(lines)


def render_doc(current, sections):
    out = current
    for key, body in sections.items():
        begin = f"<!-- BEGIN GENERATED: knowledge graph {key} (scripts/docs/gen_knowledge_graph.py) -->"
        end = f"<!-- END GENERATED: knowledge graph {key} -->"
        if begin not in out or end not in out:
            raise GraphError(f"{rel(DOC)}: generated-section markers for {key!r} not found")
        head, rest = out.split(begin, 1)
        _, tail = rest.split(end, 1)
        out = head + begin + "\n\n" + body + "\n\n" + end + tail
    return out


# --------------------------------------------------------------------- main
def outputs(stamp=None):
    g, stats = build()
    data = graph_data(g)
    cypher = render_cypher(data)
    check_cypher(cypher)
    files = {
        OUT_DIR / "graph.json": render_json(data, stamp),
        OUT_DIR / "graph.schema.json": render_schema(),
        OUT_DIR / "graph.cypher": cypher,
        OUT_DIR / "graph.graphml": render_graphml(data),
    }
    if DOC.exists():
        files[DOC] = render_doc(DOC.read_text(encoding="utf-8"), doc_sections(data, stats))
    return files, data


def strip_stamp(text):
    return re.sub(r'^ "generated_at": .*\n', "", text, flags=re.M)


def main(argv):
    check = "--check" in argv
    stamp = datetime.date.today().isoformat() if "--stamp" in argv and not check else None
    try:
        files, data = outputs(stamp)
    except GraphError as err:
        sys.exit(f"gen_knowledge_graph: {err}")
    if check:
        stale = []
        for path, content in files.items():
            have = path.read_text(encoding="utf-8") if path.exists() else None
            if have is None or strip_stamp(have) != strip_stamp(content):
                stale.append(rel(path))
        if stale:
            sys.exit("knowledge graph is out of date (" + ", ".join(stale) +
                     "): run python3 scripts/docs/gen_knowledge_graph.py")
        return
    OUT_DIR.mkdir(parents=True, exist_ok=True)
    for path, content in files.items():
        path.write_text(content, encoding="utf-8")
    c = data["counts"]
    print(f"knowledge graph: {c['nodes']} nodes, {c['edges']} edges -> {rel(OUT_DIR)}")


if __name__ == "__main__":
    main(sys.argv[1:])
