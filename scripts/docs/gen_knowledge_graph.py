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

GENERATED_FROM = sorted([
    CONTRACT, AUTHZ_DOC, JOBS_DOC, TRACE_DOC, DECISIONS_DOC, MIGRATIONS + "/*.sql",
    "backend/internal/**/*.go", "backend/cmd/**/*.go", WEB_SRC + "/**/*.{ts,tsx}",
    MOBILE_LIB + "/**/*.dart", "docs/*.md", "scripts/docs/gen_knowledge_graph.py (DOMAINS)",
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
}
NODE_LABELS = {  # Neo4j labels
    "feature": "Feature", "app": "App", "operation": "Operation", "package": "Package",
    "table": "Table", "migration": "Migration", "job": "Job", "event": "Event",
    "web_feature": "WebFeature", "web_route": "WebRoute", "mobile_feature": "MobileFeature",
    "mobile_route": "MobileRoute", "requirement": "Requirement", "decision": "Decision", "doc": "Doc",
}
NODE_PREFIX = {
    "feature": "feature:", "app": "app:", "operation": "op:", "package": "pkg:", "table": "table:",
    "migration": "migration:", "job": "job:", "event": "event:", "web_feature": "web:",
    "web_route": "webroute:", "mobile_feature": "mobile:", "mobile_route": "mobileroute:",
    "requirement": "req:", "decision": "adr:", "doc": "doc:",
}
EDGE_TYPES = {
    "includes": "feature -> package/web_feature/mobile_feature (curated DOMAINS).",
    "belongs_to": "operation/requirement/job/table -> feature.",
    "part_of": "package/web_feature/mobile_feature/table -> app.",
    "implemented_in": "operation -> package that calls httpx.Op(\"<id>\").",
    "depends_on": "package -> package (Go import); requirement -> requirement/feature/decision (Deps).",
    "reads": "package -> table (from/join in SQL string literals).",
    "writes": "package -> table (insert into/update/delete from in SQL string literals).",
    "created_in": "table -> migration with its create table.",
    "alters": "migration -> table it alters, indexes, or adds policies to later.",
    "handled_in": "job -> package that registers its handler.",
    "enqueues": "package -> job (jobs.Spec{Type: ...} outside relay routes).",
    "emits": "package -> event (outbox.Emit with Type: ...).",
    "triggers": "event -> job (relay.On route).",
    "calls": "web_feature/mobile_feature -> operation (API path literal / ApiEndpoints).",
    "handled_by": "web_route/mobile_route -> web_feature/mobile_feature rendering it.",
    "located_in": "requirement -> package/web_feature/mobile_feature/doc/decision/feature/app (Location column).",
    "references": "requirement -> doc/decision mentioned in its row text.",
    "links_to": "doc -> doc (mentions another docs/*.md file).",
    "documented_in": "decision -> doc.",
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
            "platform/apperr", "platform/audit", "platform/caps", "platform/config",
            "platform/crypto", "platform/database", "platform/httpx", "platform/idempotency",
            "platform/jobs", "platform/logging", "platform/migrate", "platform/observability",
            "platform/outbox", "platform/ratelimit", "testutil/apitest", "testutil/dbtest",
            "cmd/api", "cmd/worker", "cmd/migrate", "cmd/openapi", "cmd/loadtest",
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
    """[(path, feature, page, redirect, auth)] from routes.tsx.

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
        route = ("/" + path).replace("//", "/")
        out.append((route, feature, page, redirect, 0 <= require_auth < pos))
    return out


def parse_dart_routes(text, constants):
    """[(path, screen class)] from GoRoute(...) calls, resolving nesting."""
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
        redirect = sm is None and re.search(r"\bredirect:", head) is not None
        out.append((path, sm.group(1) if sm else ("<redirect>" if redirect else None)))
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
    for route, feature, page, redirect, auth in parse_web_routes(read(WEB_ROUTER)):
        if route in seen_routes:
            continue
        seen_routes.add(route)
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
        for path, screen in parse_dart_routes(f.read_text(encoding="utf-8"), route_consts):
            mroutes.setdefault(path, (screen, rel(f)))
    for path, (screen, src) in sorted(mroutes.items()):
        redirect = screen == "<redirect>"
        nid = g.node("mobile_route", path, path, screen=None if redirect else screen, redirect=redirect or None,
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
    return g, stats


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
    for e in data["edges"]:
        if e["type"] not in EDGE_TYPES:
            raise GraphError(f"unknown edge type {e['type']}")
        for end in (e["source"], e["target"]):
            if end not in known:
                raise GraphError(f"edge {e['source']} -{e['type']}-> {e['target']}: {end} is not a node")


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
    called = {e["target"] for e in data["edges"] if e["type"] == "calls"}
    orphan = sorted(n["id"] for n in data["nodes"] if n["type"] == "operation" and n["id"] not in called)
    web_called = {e["target"] for e in data["edges"] if e["type"] == "calls" and e["source"].startswith("web:")}
    mob_called = {e["target"] for e in data["edges"] if e["type"] == "calls" and e["source"].startswith("mobile:")}
    ops_all = [n["id"] for n in data["nodes"] if n["type"] == "operation"]
    ex.append(f"- Operations with no web or mobile caller: **{len(orphan)}** of {len(ops_all)} "
              f"(web calls {len(web_called)}, mobile calls {len(mob_called)}, both {len(web_called & mob_called)}). "
              f"By tag: " + ", ".join(f"{t} {n}" for t, n in sorted(Counter(nodes[o]['props']['tag'] for o in orphan).items())))
    grp = sorted((n for n in data["nodes"] if n["type"] == "requirement" and
                  any(e["type"] == "belongs_to" and e["target"] == "feature:groups" for e in out_e[n["id"]]) and
                  n["props"].get("status") != "VERIFIED"), key=lambda n: n["id"])
    ex.append(f"- Requirements of `feature:groups` not VERIFIED ({len(grp)}): " +
              ", ".join(f"`{n['id']}` {n['props'].get('status')}" for n in grp))
    sections["examples"] = "\n".join(ex)

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
    files = {
        OUT_DIR / "graph.json": render_json(data, stamp),
        OUT_DIR / "graph.schema.json": render_schema(),
        OUT_DIR / "graph.cypher": render_cypher(data),
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
