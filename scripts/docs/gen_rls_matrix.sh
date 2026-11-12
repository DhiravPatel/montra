#!/usr/bin/env bash
# Regenerates the generated part of docs/RLS_POLICY_MATRIX.md from a LOCAL
# Montra database (read-only catalog queries; nothing is modified).
#
# Usage: scripts/docs/gen_rls_matrix.sh [database-url]
# Default URL: DATABASE_MIGRATION_URL from backend/.env.local (montra_dev).
# The output replaces everything after the "<!-- generated -->" marker.
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
DOC="$ROOT_DIR/docs/RLS_POLICY_MATRIX.md"
URL="${1:-}"
if [ -z "$URL" ]; then
  # shellcheck disable=SC1091
  set -a && . "$ROOT_DIR/backend/.env.local" && set +a
  URL="$DATABASE_MIGRATION_URL"
fi

q() { psql "$URL" -X -q -A -t -c "$1"; }

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
q "select coalesce(json_agg(json_build_object('t',tablename,'p',policyname,'roles',roles::text,'cmd',cmd,'q',qual,'c',with_check)
   order by tablename, policyname), '[]') from pg_policies where schemaname = 'montra'" > "$TMP/policies.json"
q "select coalesce(json_agg(json_build_object('t',c.relname,'rls',c.relrowsecurity,'force',c.relforcerowsecurity) order by c.relname), '[]')
   from pg_class c join pg_namespace n on n.oid = c.relnamespace where n.nspname = 'montra' and c.relkind = 'r'" > "$TMP/tables.json"
q "select coalesce(json_agg(json_build_object('t',table_name,'g',grantee,'p',privilege_type)), '[]') from information_schema.role_table_grants
   where table_schema = 'montra' and grantee in ('montra_app','montra_worker')" > "$TMP/grants.json"
q "select coalesce(json_agg(json_build_object('f',p.proname,'args',pg_get_function_identity_arguments(p.oid),
   'grants',coalesce((select string_agg(distinct a.grantee::regrole::text, ', ' order by a.grantee::regrole::text) from aclexplode(p.proacl) a
   where a.privilege_type = 'EXECUTE' and a.grantee <> 0 and a.grantee::regrole::text <> 'montra_owner'), '')) order by p.proname), '[]')
   from pg_proc p join pg_namespace n on n.oid = p.pronamespace where n.nspname = 'montra' and p.prosecdef" > "$TMP/functions.json"
q "select max(version) from montra.schema_migrations" > "$TMP/version.txt" 2>/dev/null || echo "unknown" > "$TMP/version.txt"

python3 -I - "$TMP" "$DOC" <<'PY'
import json, re, sys, pathlib
tmp, doc = pathlib.Path(sys.argv[1]), pathlib.Path(sys.argv[2])
pol = json.loads((tmp / "policies.json").read_text())
tables = json.loads((tmp / "tables.json").read_text())
grants = json.loads((tmp / "grants.json").read_text())
funcs = json.loads((tmp / "functions.json").read_text())
version = (tmp / "version.txt").read_text().strip()

def short(e):
    if not e:
        return ""
    e = re.sub(r"\s+", " ", e)
    e = e.replace("montra.current_user_id()", "me()").replace("current_user_id()", "me()").replace("montra.", "")
    e = re.sub(r"::(text|uuid|boolean|bigint|integer|timestamp with time zone|jsonb|text\[\])", "", e)
    while e.startswith("(") and e.endswith(")") and e.count("(") == e.count(")"):
        inner = e[1:-1]
        depth, ok = 0, True
        for ch in inner:
            depth += ch == "("
            depth -= ch == ")"
            if depth < 0:
                ok = False
                break
        if not ok:
            break
        e = inner
    return e if len(e) <= 160 else e[:157] + "…"

priv = {}
for g in grants:
    priv.setdefault((g["t"], g["g"]), set()).add(g["p"])
abbr = {"SELECT": "S", "INSERT": "I", "UPDATE": "U", "DELETE": "D", "TRUNCATE": "T", "REFERENCES": "R", "TRIGGER": "Tr"}
def privs(t, role):
    p = priv.get((t, role), set())
    return "".join(abbr[x] for x in ["SELECT", "INSERT", "UPDATE", "DELETE"] if x in p) or "—"

by_table = {}
for p in pol:
    by_table.setdefault(p["t"], []).append(p)

out = []
out.append(f"Generated from the local schema at migration `{version}` by `scripts/docs/gen_rls_matrix.sh`. "
           "`me()` is `montra.current_user_id()`; grants use S/I/U/D. Policies are permissive unless noted.\n")
out.append("### Security-definer helpers\n")
out.append("| Function | Arguments | Executable by |")
out.append("|---|---|---|")
for f in funcs:
    out.append(f"| `{f['f']}` | `{f['args'] or '—'}` | {f['grants'] or 'triggers only'} |")
out.append("")
out.append("### Tables\n")
out.append("| Table | RLS | API grants | Worker grants | API-role policies (command: condition) |")
out.append("|---|---|---|---|---|")
for t in tables:
    name = t["t"]
    rls = "forced" if t["force"] else ("on" if t["rls"] else "**off**")
    rows = []
    for p in by_table.get(name, []):
        if "montra_app" not in p["roles"]:
            continue
        cond = short(p["q"]) or "true"
        chk = short(p["c"])
        text = f"{p['cmd'].lower()}: {cond}"
        if chk and chk != cond:
            text += f" ⟂ check {chk}"
        rows.append(text.replace("|", "\\|"))
    out.append(f"| `{name}` | {rls} | {privs(name, 'montra_app')} | {privs(name, 'montra_worker')} | {'<br>'.join(rows) or 'none (no API access)'} |")
out.append("")

text = doc.read_text() if doc.exists() else "<!-- generated -->\n"
marker = "<!-- generated -->"
head = text.split(marker)[0] if marker in text else text
doc.write_text(head + marker + "\n\n" + "\n".join(out))
print(f"wrote {doc} ({len(tables)} tables, {len(pol)} policies, {len(funcs)} definer functions)")
PY
