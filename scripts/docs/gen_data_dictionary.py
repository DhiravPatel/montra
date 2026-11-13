#!/usr/bin/env python3
"""Regenerate docs/DATA_DICTIONARY.md from supabase/migrations/*.sql.

The migrations are the only source of DDL (docs/DATA_MODEL.md), so the
dictionary is computed by replaying them in file order:

  create table / alter table (add, drop and alter column, add and drop
  constraint, row level security) / create and drop index / create and drop
  policy / create and drop trigger / grant and revoke on tables / alter
  default privileges / create function, and the RLS helper calls
  (`select apply_owner_rls('t')` and friends), whose plpgsql bodies are
  interpreted: every `execute format(...)` is rendered with the call's
  arguments and replayed. `do $$ ... $$` blocks are interpreted the same way
  (`foreach t in array array[...] loop`, and `if not exists (...) then`
  guards, which are true on a fresh database).

Unnamed constraints get the name PostgreSQL would choose (`<table>_pkey`,
`<table>_<col>_key`, `<table>_<col>_fkey`, `<table>_<col>_check` or
`<table>_check`, with the same 63-byte truncation and numeric suffixes), so a
later `drop constraint` by name works and the result can be compared with
pg_constraint.

The owning domain of each table comes from the "## Domains" table in
docs/DATA_MODEL.md. A table missing there is listed as unassigned.

Statements the replayer does not understand make it fail, so a migration
cannot silently drop out of the dictionary. Only the standard library is
used, and the output is deterministic (no timestamps).

Usage: python3 scripts/docs/gen_data_dictionary.py [--check]
  --check  exit 1 when docs/DATA_DICTIONARY.md is out of date (for CI).
"""
import pathlib
import re
import sys

ROOT = pathlib.Path(__file__).resolve().parents[2]
MIGRATIONS = ROOT / "supabase" / "migrations"
DOC = ROOT / "docs" / "DATA_DICTIONARY.md"
DATA_MODEL = ROOT / "docs" / "DATA_MODEL.md"
SCHEMA = "montra"
MAX_IDENT = 63  # NAMEDATALEN - 1
RUNTIME_ROLES = ("montra_app", "montra_worker")
ALL_PRIVS = ("select", "insert", "update", "delete")


class SQLError(Exception):
    """A statement the replayer cannot interpret."""


# --------------------------------------------------------------------- lexer

TOKEN_RE = re.compile(
    r"""
    (?P<ws>\s+)
  | (?P<line>--[^\n]*)
  | (?P<block>/\*.*?\*/)
  | (?P<dollar>\$(?:[A-Za-z_][A-Za-z_0-9]*)?\$)
  | (?P<str>[eE]?'(?:[^']|'')*')
  | (?P<qident>"(?:[^"]|"")*")
  | (?P<num>\d+(?:\.\d+)?)
  | (?P<param>\$\d+)
  | (?P<word>[A-Za-z_][A-Za-z_0-9$]*)
  | (?P<op>::|<>|<=|>=|!=|\|\||->>|->|~\*|!~\*|!~|:=|[(),;.\[\]=<>+\-*/%~!@\#^&|?:{}])
    """,
    re.S | re.X,
)


class Tok:
    __slots__ = ("kind", "text", "start", "end")

    def __init__(self, kind, text, start, end):
        self.kind, self.text, self.start, self.end = kind, text, start, end

    @property
    def low(self):
        return self.text.lower() if self.kind == "word" else self.text

    def __repr__(self):
        return f"Tok({self.kind},{self.text!r})"


def lex(src):
    """Returns (tokens, comments); comments are (start, end, text) spans."""
    toks, comments, pos = [], [], 0
    while pos < len(src):
        m = TOKEN_RE.match(src, pos)
        if not m:
            raise SQLError(f"cannot lex near: {src[pos:pos + 40]!r}")
        kind = m.lastgroup
        if kind == "dollar":
            tag = m.group(0)
            end = src.find(tag, m.end())
            if end < 0:
                raise SQLError(f"unterminated dollar quote {tag}")
            toks.append(Tok("dollar", src[m.end():end], m.start(), end + len(tag)))
            pos = end + len(tag)
            continue
        if kind in ("line", "block"):
            comments.append((m.start(), m.end(), m.group(0)))
        elif kind != "ws":
            toks.append(Tok(kind, m.group(0), m.start(), m.end()))
        pos = m.end()
    return toks, comments


def split_statements(toks):
    out, cur = [], []
    for t in toks:
        if t.kind == "op" and t.text == ";":
            if cur:
                out.append(cur)
            cur = []
        else:
            cur.append(t)
    if cur:
        out.append(cur)
    return out


def split_top(toks, sep=","):
    """Splits a token list on `sep` at parenthesis/bracket depth 0."""
    parts, cur, depth = [], [], 0
    for t in toks:
        if t.kind == "op" and t.text in "([":
            depth += 1
        elif t.kind == "op" and t.text in ")]":
            depth -= 1
        if depth == 0 and t.kind == "op" and t.text == sep:
            parts.append(cur)
            cur = []
        else:
            cur.append(t)
    if cur:
        parts.append(cur)
    return parts


def matching_paren(toks, i):
    """Index of the token closing the parenthesis at toks[i]."""
    depth = 0
    for j in range(i, len(toks)):
        if toks[j].kind == "op" and toks[j].text in "([":
            depth += 1
        elif toks[j].kind == "op" and toks[j].text in ")]":
            depth -= 1
            if depth == 0:
                return j
    raise SQLError("unbalanced parentheses")


SPACE_BEFORE_PAREN = {
    "in", "and", "or", "not", "as", "check", "using", "on", "exists", "any", "all", "then",
    "else", "when", "is", "values", "key", "references", "with", "between", "like", "ilike",
    "similar", "to", "by", "where", "select", "from", "case", "null", "array", "include",
}


def render(toks):
    """Canonical one-line text for an expression's tokens."""
    out, prev = [], None
    for t in toks:
        txt = t.text if t.kind in ("str", "qident", "dollar") else t.text.lower() if t.kind == "word" else t.text
        if t.kind == "dollar":
            txt = "$$" + t.text + "$$"
        if prev is not None:
            no_space = (
                (t.kind == "op" and t.text in (")", ",", ".", "::", "[", "]"))
                or (prev.kind == "op" and prev.text in ("(", ".", "::", "["))
                or (t.kind == "op" and t.text == "(" and prev.kind in ("word", "qident")
                    and prev.low not in SPACE_BEFORE_PAREN)
            )
            if not no_space:
                out.append(" ")
        out.append(txt)
        prev = t
    return "".join(out)


def ident(tok):
    if tok.kind == "qident":
        return tok.text[1:-1].replace('""', '"')
    if tok.kind == "word":
        return tok.text.lower()
    raise SQLError(f"expected identifier, got {tok.text!r}")


def qualified(toks, i):
    """Reads [schema.]name at toks[i]; returns (name, next index)."""
    name = ident(toks[i])
    i += 1
    if i < len(toks) and toks[i].kind == "op" and toks[i].text == ".":
        if name not in (SCHEMA, "public"):
            raise SQLError(f"object outside schema {SCHEMA}: {name}")
        name = ident(toks[i + 1])
        i += 2
    return name, i


def unquote(s):
    if s.startswith(("E'", "e'")):
        s = s[1:]
    return s[1:-1].replace("''", "'")


def words(toks, i, *expected):
    """True when the words at toks[i:] match `expected` (case-insensitive)."""
    if i + len(expected) > len(toks):
        return False
    return all(toks[i + k].kind == "word" and toks[i + k].low == w for k, w in enumerate(expected))


# ----------------------------------------------- PostgreSQL naming rules

def make_object_name(name1, name2, label):
    """Port of PostgreSQL's makeObjectName (63-byte names)."""
    overhead = (len(label) + 1 if label else 0) + (1 if name2 else 0)
    avail = MAX_IDENT - overhead
    n1, n2 = len(name1.encode()), len(name2.encode()) if name2 else 0
    while n1 + n2 > avail:
        if n1 > n2:
            n1 -= 1
        else:
            n2 -= 1
    name = name1.encode()[:n1].decode(errors="ignore")
    if name2:
        name += "_" + name2.encode()[:n2].decode(errors="ignore")
    if label:
        name += "_" + label
    return name


def choose_name(name1, name2, label, used):
    """Port of ChooseConstraintName/ChooseRelationName: suffix 1, 2, … on collision."""
    pass_no, mod = 0, label
    while True:
        cand = make_object_name(name1, name2, mod)
        if cand not in used:
            return cand
        pass_no += 1
        mod = f"{label}{pass_no}"


# ------------------------------------------------------------------- model

class Column:
    def __init__(self, name, type_, migration):
        self.name, self.type, self.migration = name, type_, migration
        self.nullable, self.default, self.generated, self.identity = True, None, None, None


class Constraint:
    def __init__(self, name, kind, definition, cols, migration):
        self.name, self.kind, self.definition, self.cols, self.migration = name, kind, definition, cols, migration


class Table:
    def __init__(self, name, migration, comment, default_privs):
        self.name, self.migration, self.comment = name, migration, comment
        self.altered_in = []
        self.columns = {}
        self.constraints = {}
        self.indexes = {}
        self.policies = {}
        self.triggers = {}
        self.rls = False
        self.force_rls = False
        self.helpers = []
        self.privs = {r: set(default_privs.get(r, ())) for r in RUNTIME_ROLES}

    def touch(self, migration):
        if migration != self.migration and migration not in self.altered_in:
            self.altered_in.append(migration)


class Function:
    def __init__(self, name, params, returns, language, secdef, body, migration):
        self.name, self.params, self.returns = name, params, returns
        self.language, self.secdef, self.body, self.migration = language, secdef, body, migration


class Schema:
    def __init__(self):
        self.tables = {}
        self.functions = {}
        self.default_privs = {}
        self.constraint_names = set()
        self.relation_names = set()
        self.migration = None
        self.statements = 0

    # ---------------------------------------------------------- helpers
    def table(self, name):
        if name not in self.tables:
            raise SQLError(f"unknown table {name}")
        t = self.tables[name]
        t.touch(self.migration)
        return t

    def add_constraint(self, t, con):
        if con.name in t.constraints:
            raise SQLError(f"duplicate constraint {con.name} on {t.name}")
        t.constraints[con.name] = con
        self.constraint_names.add(con.name)
        if con.kind in ("PRIMARY KEY", "UNIQUE"):
            self.relation_names.add(con.name)
        if con.kind == "PRIMARY KEY":
            for c in con.cols:
                t.columns[c].nullable = False

    # -------------------------------------------------------- statements
    def run_sql(self, sql, comment_lookup=None):
        toks, comments = lex(sql)
        prev_end = 0
        for stmt in split_statements(toks):
            comment = comment_lookup(sql, prev_end, stmt[0].start) if comment_lookup else ""
            prev_end = stmt[-1].end
            self.statement(stmt, comment)

    def statement(self, s, comment=""):
        self.statements += 1
        w = [t.low if t.kind == "word" else t.text for t in s[:6]] + [""] * 6
        if w[0] in ("set", "insert", "update", "delete", "analyze", "notify", "reset"):
            return
        if w[0] == "select":
            return self.select_call(s)
        if w[0] == "perform":
            return self.select_call(s)
        if w[0] == "do":
            return self.do_block(s)
        if w[0] == "comment":
            return  # comments on schema objects are not part of the dictionary
        if w[0] == "create":
            i = 1
            if words(s, i, "or", "replace"):
                i += 2
            kind = s[i].low
            if kind == "table":
                return self.create_table(s, i + 1, comment)
            if kind == "unique" or kind == "index":
                return self.create_index(s, i)
            if kind == "policy":
                return self.create_policy(s, i + 1)
            if kind == "function":
                return self.create_function(s, i + 1)
            if kind == "trigger":
                return self.create_trigger(s, i + 1)
            if kind in ("schema", "extension"):
                return
            raise SQLError("unsupported create: " + render(s[:6]))
        if w[0] == "alter":
            if w[1] == "table":
                return self.alter_table(s, 2)
            if w[1] == "default" and w[2] == "privileges":
                return self.default_privileges(s)
            raise SQLError("unsupported alter: " + render(s[:6]))
        if w[0] == "drop":
            return self.drop(s)
        if w[0] in ("grant", "revoke"):
            return self.grant(s)
        raise SQLError("unsupported statement: " + render(s[:8]))

    # ------------------------------------------------------- create table
    def create_table(self, s, i, comment):
        if words(s, i, "if", "not", "exists"):
            i += 3
        name, i = qualified(s, i)
        if name in self.tables:
            return  # `if not exists` on an existing table
        if not (s[i].kind == "op" and s[i].text == "("):
            raise SQLError(f"create table {name}: expected column list")
        close = matching_paren(s, i)
        if close != len(s) - 1:
            raise SQLError(f"create table {name}: unsupported table options " + render(s[close + 1:]))
        t = Table(name, self.migration, comment, self.default_privs)
        self.tables[name] = t
        self.relation_names.add(name)
        items = split_top(s[i + 1:close])
        pending = []
        for item in items:
            head = item[0].low if item[0].kind == "word" else ""
            if head in ("constraint", "unique", "check", "foreign", "exclude") or (
                    head == "primary" and words(item, 1, "key")):
                pending.append(item)
            else:
                self.column_def(t, item)
        # Table constraints are named after the columns exist.
        for item in pending:
            self.table_constraint(t, item)

    def column_def(self, t, toks):
        name = ident(toks[0])
        stops = {"not", "null", "default", "primary", "references", "check", "unique", "generated",
                 "constraint", "collate"}
        j = 1
        while j < len(toks) and not (toks[j].kind == "word" and toks[j].low in stops):
            if toks[j].kind == "op" and toks[j].text == "(":
                j = matching_paren(toks, j)
            j += 1
        type_ = render(toks[1:j])
        if not type_:
            raise SQLError(f"{t.name}.{name}: missing type")
        if name in t.columns:
            raise SQLError(f"duplicate column {t.name}.{name}")
        col = Column(name, type_, self.migration)
        t.columns[name] = col
        con_name = None
        later = []  # inline constraints, named once the column exists
        while j < len(toks):
            k = toks[j].low if toks[j].kind == "word" else toks[j].text
            if k == "constraint":
                con_name = ident(toks[j + 1])
                j += 2
                continue
            if k == "not" and words(toks, j + 1, "null"):
                col.nullable = False
                j += 2
            elif k == "null":
                j += 1
            elif k == "default":
                e = j + 1
                while e < len(toks):
                    tk = toks[e]
                    if tk.kind == "op" and tk.text == "(":
                        e = matching_paren(toks, e) + 1
                        continue
                    if tk.kind == "word" and e > j + 1 and (
                        tk.low in stops - {"not", "null"} or (tk.low == "not" and words(toks, e + 1, "null"))
                    ):
                        break
                    e += 1
                col.default = render(toks[j + 1:e])
                j = e
            elif k == "primary" and words(toks, j + 1, "key"):
                later.append((con_name, "PRIMARY KEY", None))
                j += 2
            elif k == "unique":
                j += 1
                if words(toks, j, "nulls", "not", "distinct"):
                    j += 3
                later.append((con_name, "UNIQUE", None))
            elif k == "check":
                close = matching_paren(toks, j + 1)
                later.append((con_name, "CHECK", toks[j + 2:close]))
                j = close + 1
                if words(toks, j, "no", "inherit"):
                    j += 2
            elif k == "references":
                ref, j = self.references(toks, j + 1)
                later.append((con_name, "FOREIGN KEY", ref))
            elif k == "generated":
                if words(toks, j + 1, "always", "as", "identity") or words(toks, j + 1, "by", "default", "as", "identity"):
                    col.identity = "always" if toks[j + 1].low == "always" else "by default"
                    col.nullable = False
                    j += 4 if col.identity == "always" else 5
                    if j < len(toks) and toks[j].text == "(":
                        j = matching_paren(toks, j) + 1
                elif words(toks, j + 1, "always", "as"):
                    close = matching_paren(toks, j + 3)
                    col.generated = render(toks[j + 4:close])
                    j = close + 1
                    if words(toks, j, "stored"):
                        j += 1
                else:
                    raise SQLError(f"{t.name}.{name}: unsupported generated clause")
            elif k == "collate":
                j += 2
            else:
                raise SQLError(f"{t.name}.{name}: unexpected {toks[j].text!r} in column definition")
            con_name = None
        for cname, kind, extra in later:
            if kind == "PRIMARY KEY":
                self.key_constraint(t, cname, "PRIMARY KEY", [name])
            elif kind == "UNIQUE":
                self.key_constraint(t, cname, "UNIQUE", [name])
            elif kind == "CHECK":
                self.check_constraint(t, cname, extra)
            else:
                self.fk_constraint(t, cname, [name], extra)
        return col

    def references(self, toks, j):
        target, j = qualified(toks, j)
        cols = []
        if j < len(toks) and toks[j].text == "(":
            close = matching_paren(toks, j)
            cols = [ident(p[0]) for p in split_top(toks[j + 1:close])]
            j = close + 1
        opts = []
        while j < len(toks):
            if words(toks, j, "on", "delete") or words(toks, j, "on", "update"):
                action_end = j + 3
                if words(toks, j + 2, "set", "null") or words(toks, j + 2, "set", "default") or words(toks, j + 2, "no", "action"):
                    action_end = j + 4
                opts.append(render(toks[j:action_end]).upper())
                j = action_end
            elif words(toks, j, "deferrable"):
                opts.append("DEFERRABLE")
                j += 1
            elif words(toks, j, "not", "deferrable"):
                j += 2
            elif words(toks, j, "initially"):
                opts.append(render(toks[j:j + 2]).upper())
                j += 2
            elif words(toks, j, "match"):
                opts.append(render(toks[j:j + 2]).upper())
                j += 2
            else:
                break
        if target not in self.tables:
            raise SQLError(f"foreign key to unknown table {target}")
        if not cols:
            pk = [c for c in self.tables[target].constraints.values() if c.kind == "PRIMARY KEY"]
            if not pk:
                raise SQLError(f"foreign key to {target} without a primary key")
            cols = pk[0].cols
        return (target, cols, opts), j

    def column_refs(self, t, toks):
        refs = []
        for k, tk in enumerate(toks):
            if tk.kind not in ("word", "qident"):
                continue
            name = ident(tk)
            if name not in t.columns:
                continue
            if k + 1 < len(toks) and toks[k + 1].text == "(":
                continue
            if k > 0 and toks[k - 1].text in (".", "::"):
                continue
            if name not in refs:
                refs.append(name)
        return refs

    def check_constraint(self, t, cname, expr):
        if cname is None:
            refs = self.column_refs(t, expr)
            cname = choose_name(t.name, refs[0] if len(refs) == 1 else None, "check", self.constraint_names)
        self.add_constraint(t, Constraint(cname, "CHECK", render(expr), self.column_refs(t, expr), self.migration))

    def key_constraint(self, t, cname, kind, cols):
        for c in cols:
            if c not in t.columns:
                raise SQLError(f"{kind} on unknown column {t.name}.{c}")
        if cname is None:
            if kind == "PRIMARY KEY":
                cname = choose_name(t.name, None, "pkey", self.relation_names | self.constraint_names)
            else:
                cname = choose_name(t.name, "_".join(cols), "key", self.relation_names | self.constraint_names)
        self.add_constraint(t, Constraint(cname, kind, "(" + ", ".join(cols) + ")", cols, self.migration))

    def fk_constraint(self, t, cname, cols, ref):
        target, tcols, opts = ref
        if cname is None:
            cname = choose_name(t.name, "_".join(cols), "fkey", self.constraint_names)
        definition = f"({', '.join(cols)}) → {target}({', '.join(tcols)})"
        if opts:
            definition += " " + " ".join(opts)
        self.add_constraint(t, Constraint(cname, "FOREIGN KEY", definition, cols, self.migration))

    def table_constraint(self, t, toks):
        cname = None
        if toks[0].low == "constraint":
            cname = ident(toks[1])
            toks = toks[2:]
        k = toks[0].low
        if k == "primary" or k == "unique":
            j = 2 if k == "primary" else 1
            if words(toks, j, "nulls", "not", "distinct"):
                j += 3
            close = matching_paren(toks, j)
            cols = [ident(p[0]) for p in split_top(toks[j + 1:close])]
            self.key_constraint(t, cname, "PRIMARY KEY" if k == "primary" else "UNIQUE", cols)
        elif k == "check":
            close = matching_paren(toks, 1)
            self.check_constraint(t, cname, toks[2:close])
        elif k == "foreign":
            close = matching_paren(toks, 2)
            cols = [ident(p[0]) for p in split_top(toks[3:close])]
            if not words(toks, close + 1, "references"):
                raise SQLError(f"{t.name}: foreign key without references")
            ref, _ = self.references(toks, close + 2)
            self.fk_constraint(t, cname, cols, ref)
        elif k == "exclude":
            if cname is None:
                raise SQLError(f"{t.name}: unnamed exclusion constraints are not supported")
            self.add_constraint(t, Constraint(cname, "EXCLUDE", render(toks[1:]), [], self.migration))
        else:
            raise SQLError(f"{t.name}: unsupported table constraint " + render(toks[:4]))

    # -------------------------------------------------------- alter table
    def alter_table(self, s, i):
        if words(s, i, "if", "exists"):
            i += 2
        if words(s, i, "only"):
            i += 1
        name, i = qualified(s, i)
        t = self.table(name)
        for act in split_top(s[i:]):
            self.alter_action(t, act)

    def alter_action(self, t, a):
        if words(a, 0, "add", "column") or (words(a, 0, "add") and not (a[1].kind == "word" and a[1].low in (
                "constraint", "primary", "unique", "check", "foreign", "exclude"))):
            j = 2 if words(a, 0, "add", "column") else 1
            if words(a, j, "if", "not", "exists"):
                j += 3
                if ident(a[j]) in t.columns:
                    return
            self.column_def(t, a[j:])
        elif words(a, 0, "add"):
            self.table_constraint(t, a[1:])
        elif words(a, 0, "drop", "constraint"):
            j = 2
            if_exists = words(a, j, "if", "exists")
            if if_exists:
                j += 2
            cname = ident(a[j])
            if cname not in t.constraints:
                if if_exists:
                    return
                raise SQLError(f"drop of unknown constraint {t.name}.{cname}")
            del t.constraints[cname]
            self.constraint_names.discard(cname)
            self.relation_names.discard(cname)
        elif words(a, 0, "drop", "column") or words(a, 0, "drop"):
            j = 2 if words(a, 0, "drop", "column") else 1
            if_exists = words(a, j, "if", "exists")
            if if_exists:
                j += 2
            cname = ident(a[j])
            if cname not in t.columns:
                if if_exists:
                    return
                raise SQLError(f"drop of unknown column {t.name}.{cname}")
            del t.columns[cname]
            for con in [c for c in t.constraints.values() if cname in c.cols]:
                del t.constraints[con.name]
            for idx in [n for n, ix in t.indexes.items() if re.search(r"\b" + re.escape(cname) + r"\b", ix["definition"])]:
                del t.indexes[idx]
        elif words(a, 0, "alter"):
            j = 2 if words(a, 0, "alter", "column") else 1
            col = t.columns.get(ident(a[j]))
            if col is None:
                raise SQLError(f"alter of unknown column {t.name}.{ident(a[j])}")
            j += 1
            if words(a, j, "set", "default"):
                col.default = render(a[j + 2:])
            elif words(a, j, "drop", "default"):
                col.default = None
            elif words(a, j, "set", "not", "null"):
                col.nullable = False
            elif words(a, j, "drop", "not", "null"):
                col.nullable = True
            elif words(a, j, "type") or words(a, j, "set", "data", "type"):
                j += 1 if a[j].low == "type" else 3
                e = j
                while e < len(a) and not words(a, e, "using") and not words(a, e, "collate"):
                    e += 1
                col.type = render(a[j:e])
            else:
                raise SQLError(f"unsupported alter column on {t.name}: " + render(a))
        elif words(a, 0, "rename", "column") or (words(a, 0, "rename") and words(a, 2, "to")):
            j = 2 if words(a, 0, "rename", "column") else 1
            old, new = ident(a[j]), ident(a[j + 2])
            col = t.columns.pop(old)
            col.name = new
            t.columns[new] = col
        elif words(a, 0, "enable", "row", "level", "security"):
            t.rls = True
        elif words(a, 0, "force", "row", "level", "security"):
            t.force_rls = True
        elif words(a, 0, "disable", "row", "level", "security"):
            t.rls = False
        elif words(a, 0, "enable", "trigger") or words(a, 0, "disable", "trigger"):
            pass  # temporary toggles around data fixes
        else:
            raise SQLError(f"unsupported alter table action on {t.name}: " + render(a))

    # --------------------------------------------------------- indexes
    def create_index(self, s, i):
        unique = False
        if s[i].low == "unique":
            unique = True
            i += 1
        if s[i].low != "index":
            raise SQLError("expected index")
        i += 1
        if words(s, i, "concurrently"):
            i += 1
        if_not_exists = words(s, i, "if", "not", "exists")
        if if_not_exists:
            i += 3
        name = None
        if not words(s, i, "on"):
            name, i = qualified(s, i)
        if not words(s, i, "on"):
            raise SQLError("create index: expected on")
        i += 1
        if words(s, i, "only"):
            i += 1
        table, i = qualified(s, i)
        t = self.table(table)
        if name is None:
            raise SQLError(f"unnamed index on {table}: name every index")
        if name in self.relation_names:
            if if_not_exists:
                return
            raise SQLError(f"duplicate relation name {name}")
        method = "btree"
        if words(s, i, "using"):
            method = s[i + 1].low
            i += 2
        close = matching_paren(s, i)
        cols = render(s[i:close + 1])
        rest = s[close + 1:]
        include, where = "", ""
        j = 0
        if words(rest, 0, "include"):
            c2 = matching_paren(rest, 1)
            include = render(rest[1:c2 + 1])
            j = c2 + 1
        if words(rest, j, "nulls"):
            j += 3 if words(rest, j + 1, "not") else 2
        if words(rest, j, "where"):
            where = render(rest[j + 1:])
        elif j < len(rest):
            raise SQLError(f"index {name}: unsupported clause " + render(rest[j:]))
        definition = (f"using {method} " if method != "btree" else "") + cols
        if include:
            definition += " include " + include
        t.indexes[name] = {"unique": unique, "definition": definition, "where": where, "migration": self.migration}
        self.relation_names.add(name)

    # -------------------------------------------------------- policies
    def create_policy(self, s, i):
        name = ident(s[i])
        if not words(s, i + 1, "on"):
            raise SQLError(f"policy {name}: expected on")
        table, j = qualified(s, i + 2)
        t = self.table(table)
        cmd, roles, using, check, kind = "all", ["public"], "", "", "permissive"
        while j < len(s):
            if words(s, j, "as"):
                kind = s[j + 1].low
                j += 2
            elif words(s, j, "for"):
                cmd = s[j + 1].low
                j += 2
            elif words(s, j, "to"):
                j += 1
                roles = []
                while j < len(s) and s[j].kind in ("word", "qident") and s[j].low not in ("using", "with"):
                    roles.append(ident(s[j]))
                    j += 1
                    if j < len(s) and s[j].text == ",":
                        j += 1
            elif words(s, j, "using"):
                close = matching_paren(s, j + 1)
                using = render(s[j + 2:close])
                j = close + 1
            elif words(s, j, "with", "check"):
                close = matching_paren(s, j + 2)
                check = render(s[j + 3:close])
                j = close + 1
            else:
                raise SQLError(f"policy {name}: unexpected {s[j].text!r}")
        if name in t.policies:
            raise SQLError(f"duplicate policy {name} on {table}")
        t.policies[name] = {"cmd": cmd.upper(), "roles": roles, "using": using, "check": check,
                            "kind": kind, "migration": self.migration}

    # -------------------------------------------------------- triggers
    def create_trigger(self, s, i):
        name = ident(s[i])
        on = i + 1
        while on < len(s) and not words(s, on, "on"):
            on += 1
        table, j = qualified(s, on + 1)
        t = self.table(table)
        timing = render(s[i + 1:on])  # e.g. "before insert or update of parent_id"
        fn = ""
        for k in range(j, len(s)):
            if words(s, k, "execute", "function") or words(s, k, "execute", "procedure"):
                fn, _ = qualified(s, k + 2)
        t.triggers[name] = {"timing": timing, "function": fn, "migration": self.migration}

    # ------------------------------------------------------- functions
    def create_function(self, s, i):
        name, i = qualified(s, i)
        close = matching_paren(s, i)
        params = []
        for p in split_top(s[i + 1:close]):
            k = 0
            if p and p[0].low in ("in", "out", "inout", "variadic"):
                k = 1
            pname = ident(p[k])
            rest = p[k + 1:]
            default = None
            for d in range(len(rest)):
                if rest[d].low == "default" or rest[d].text == "=":
                    default = rest[d + 1:]
                    rest = rest[:d]
                    break
            params.append((pname, render(rest), default))
        j = close + 1
        returns, language, secdef, body = "", "", False, None
        while j < len(s):
            tk = s[j]
            if words(s, j, "returns"):
                e = j + 1
                while e < len(s) and not (s[e].kind == "word" and s[e].low in (
                        "language", "as", "security", "stable", "immutable", "volatile", "strict", "set",
                        "parallel", "leakproof", "cost", "called")) and s[e].kind != "dollar":
                    if s[e].text == "(":
                        e = matching_paren(s, e)
                    e += 1
                returns = render(s[j + 1:e])
                j = e
                continue
            if words(s, j, "language"):
                language = s[j + 1].low
                j += 2
                continue
            if words(s, j, "security", "definer"):
                secdef = True
            if tk.kind == "dollar":
                body = tk.text
            elif tk.kind == "str" and j > 0 and s[j - 1].low == "as":
                body = unquote(tk.text)
            j += 1
        args = ", ".join(f"{n} {t}".strip() for n, t, _ in params)
        self.functions[name] = Function(name, params, returns, language, secdef, body, self.migration)
        self.functions[name].args = args

    # ------------------------------------------------- helper interpreter
    def select_call(self, s):
        j = 1
        if not (len(s) > j and s[j].kind in ("word", "qident")):
            return
        try:
            name, j = qualified(s, j)
        except SQLError:
            return
        if name not in self.functions or j >= len(s) or s[j].text != "(":
            return
        fn = self.functions[name]
        if fn.language != "plpgsql" or fn.body is None or "execute" not in fn.body.lower():
            return
        close = matching_paren(s, j)
        args = [self.literal(a) for a in split_top(s[j + 1:close])] if close > j + 1 else []
        env = {}
        for k, (pname, _ptype, default) in enumerate(fn.params):
            if k < len(args):
                env[pname] = args[k]
            elif default is not None:
                env[pname] = self.literal(default)
            else:
                raise SQLError(f"call to {name}: missing argument {pname}")
        if args and isinstance(args[0], str):
            table = args[0].split(".")[-1]
            if table in self.tables:
                extra = [f"{p}={str(env[p]).lower() if isinstance(env[p], bool) else env[p]}"
                         for p, _t, _d in fn.params[1:]]
                self.tables[table].helpers.append(f"{name}({', '.join(extra)})")
                self.tables[table].touch(self.migration)
        btoks, _ = lex(fn.body)
        self.exec_block(btoks, env)

    @staticmethod
    def literal(toks):
        if len(toks) == 1 and toks[0].kind == "str":
            return unquote(toks[0].text)
        if len(toks) == 1 and toks[0].kind == "word" and toks[0].low in ("true", "false"):
            return toks[0].low == "true"
        if len(toks) == 1 and toks[0].kind == "num":
            return toks[0].text
        if len(toks) == 3 and toks[0].kind == "str" and toks[1].text == "::":
            return unquote(toks[0].text)
        raise SQLError("unsupported helper argument " + render(toks))

    def do_block(self, s):
        body = next((t for t in s if t.kind == "dollar"), None)
        if body is None:
            raise SQLError("do block without a body")
        btoks, _ = lex(body.text)
        self.exec_block(btoks, {})

    def exec_block(self, toks, env):
        i = 0
        while i < len(toks):
            t = toks[i]
            if words(toks, i, "declare"):
                while i < len(toks) and not words(toks, i, "begin"):
                    i += 1
                continue
            if words(toks, i, "begin"):
                i += 1
                continue
            if words(toks, i, "end") and (i + 1 == len(toks) or toks[i + 1].text == ";"):
                i += 2
                continue
            if words(toks, i, "if"):
                then = i + 1
                while not words(toks, then, "then"):
                    if toks[then].text == "(":
                        then = matching_paren(toks, then)
                    then += 1
                end = self.block_end(toks, then + 1, "if")
                if self.condition(toks[i + 1:then], env):
                    self.exec_block(toks[then + 1:end], env)
                i = end + 3  # end if ;
                continue
            if words(toks, i, "foreach"):
                var = ident(toks[i + 1])
                if not words(toks, i + 2, "in", "array", "array"):
                    raise SQLError("unsupported foreach")
                close = matching_paren(toks, i + 5)
                items = [self.literal(p) for p in split_top(toks[i + 6:close])]
                if not words(toks, close + 1, "loop"):
                    raise SQLError("foreach without loop")
                end = self.block_end(toks, close + 2, "loop")
                for item in items:
                    self.exec_block(toks[close + 2:end], dict(env, **{var: item}))
                i = end + 3
                continue
            # one plpgsql statement up to ';'
            e = i
            while e < len(toks) and toks[e].text != ";":
                e += 1
            stmt = toks[i:e]
            i = e + 1
            if not stmt:
                continue
            head = stmt[0].low
            if head == "raise" or head == "return" or head == "null":
                continue
            if words(stmt, 0, "execute", "format"):
                close = matching_paren(stmt, 2)
                parts = split_top(stmt[3:close])
                fmt = unquote(parts[0][0].text)
                values = []
                for p in parts[1:]:
                    if len(p) == 1 and p[0].kind == "word" and p[0].low in env:
                        values.append(env[p[0].low])
                    else:
                        values.append(self.literal(p))
                self.run_sql(self.format(fmt, values))
                continue
            if head == "execute":
                raise SQLError("dynamic execute other than execute format(...) is not supported")
            if any(tk.text == ":=" for tk in stmt[:3]):
                raise SQLError("plpgsql assignment in a DDL helper is not supported")
            self.statement(stmt)

    @staticmethod
    def block_end(toks, i, kind):
        """Index of the `end` that closes an if/loop body starting at i."""
        depth = 0
        while i < len(toks):
            if words(toks, i, "end", kind):
                if depth == 0:
                    return i
                depth -= 1
                i += 2
                continue
            if words(toks, i, kind) and not (i > 0 and toks[i - 1].low == "end"):
                # A nested `if` starts a statement; `drop … if exists` does not.
                starts = i == 0 or toks[i - 1].text == ";" or toks[i - 1].low in ("then", "loop", "begin", "else")
                if kind == "loop" or starts:
                    depth += 1
            i += 1
        raise SQLError(f"unterminated {kind}")

    @staticmethod
    def condition(toks, env):
        # Existence guards (`if not exists (select … from pg_policies …)`) are
        # true on a fresh database, which is what the dictionary describes.
        if words(toks, 0, "not", "exists"):
            return True
        if words(toks, 0, "exists"):
            return False
        neg = words(toks, 0, "not")
        rest = toks[1:] if neg else toks
        if len(rest) == 1 and rest[0].kind == "word" and rest[0].low in env:
            val = bool(env[rest[0].low])
            return not val if neg else val
        raise SQLError("unsupported condition in plpgsql block: " + render(toks))

    @staticmethod
    def format(fmt, values):
        out, k, i = [], 0, 0
        while i < len(fmt):
            c = fmt[i]
            if c == "%" and i + 1 < len(fmt):
                spec = fmt[i + 1]
                if spec == "%":
                    out.append("%")
                else:
                    v = values[k]
                    k += 1
                    if spec == "I":
                        v = str(v)
                        out.append(v if re.fullmatch(r"[a-z_][a-z0-9_$]*", v) else '"' + v.replace('"', '""') + '"')
                    elif spec == "L":
                        out.append("'" + str(v).replace("'", "''") + "'")
                    elif spec == "s":
                        out.append(str(v))
                    else:
                        raise SQLError(f"unsupported format specifier %{spec}")
                i += 2
                continue
            out.append(c)
            i += 1
        return "".join(out)

    # ----------------------------------------------- drop / grant / privs
    def drop(self, s):
        kind = s[1].low
        j = 2
        if_exists = words(s, j, "if", "exists")
        if if_exists:
            j += 2
        if kind == "index":
            name, _ = qualified(s, j)
            for t in self.tables.values():
                if name in t.indexes:
                    del t.indexes[name]
                    t.touch(self.migration)
                    self.relation_names.discard(name)
                    return
            if not if_exists:
                raise SQLError(f"drop of unknown index {name}")
        elif kind in ("policy", "trigger"):
            name = ident(s[j])
            table, _ = qualified(s, j + 2)
            t = self.table(table)
            store = t.policies if kind == "policy" else t.triggers
            if name in store:
                del store[name]
            elif not if_exists:
                raise SQLError(f"drop of unknown {kind} {name} on {table}")
        elif kind == "function":
            name, _ = qualified(s, j)
            self.functions.pop(name, None)
        else:
            raise SQLError("unsupported drop: " + render(s[:5]))

    def grant(self, s):
        verb = s[0].low
        j = 1
        privs = []
        while not words(s, j, "on"):
            if s[j].kind == "word":
                privs.append(s[j].low)
            j += 1
        j += 1
        if s[j].kind == "word" and s[j].low in ("schema", "function", "functions", "sequence", "sequences", "all"):
            return
        if words(s, j, "table"):
            j += 1
        tables = []
        while not (s[j].kind == "word" and s[j].low in ("to", "from")):
            if s[j].text != ",":
                name, j = qualified(s, j)
                tables.append(name)
                continue
            j += 1
        roles = [ident(t) for t in s[j + 1:] if t.kind in ("word", "qident")]
        if "all" in privs:
            privs = list(ALL_PRIVS)
        for name in tables:
            if name == "schema_migrations":
                continue  # created by cmd/migrate, not by the migrations
            t = self.table(name)
            for r in roles:
                if r not in t.privs:
                    continue
                if verb == "grant":
                    t.privs[r] |= set(privs)
                else:
                    t.privs[r] -= set(privs)

    def default_privileges(self, s):
        j = 0
        while not words(s, j, "grant"):
            j += 1
        privs, j = [], j + 1
        while not words(s, j, "on"):
            if s[j].kind == "word":
                privs.append(s[j].low)
            j += 1
        if s[j + 1].low != "tables":
            return
        roles = [ident(t) for t in s[j + 3:] if t.kind in ("word", "qident")]
        for r in roles:
            self.default_privs.setdefault(r, set()).update(privs)


# ------------------------------------------------------------- comments

def preceding_comment(src, prev_end, start):
    """The `--` comment block directly above a statement (no blank line between)."""
    lines = src[prev_end:start].split("\n")
    block = []
    for line in reversed(lines[:-1] if lines and not lines[-1].strip() else lines):
        s = line.strip()
        if s.startswith("--"):
            text = s[2:].strip()
            if text and not re.fullmatch(r"-+", text):
                block.append(text)
            elif re.fullmatch(r"-*", text) and block:
                break
            continue
        if not s and not block:
            continue
        break
    return " ".join(reversed(block))


# ------------------------------------------------------------- loading

def load(migration_dir=MIGRATIONS):
    schema = Schema()
    files = sorted(migration_dir.glob("*.sql"))
    if not files:
        sys.exit(f"no migrations in {migration_dir}")
    for f in files:
        schema.migration = f.name
        try:
            schema.run_sql(f.read_text(encoding="utf-8"), preceding_comment)
        except SQLError as e:
            sys.exit(f"{f.name}: {e}")
    return schema, [f.name for f in files]


def domains(text):
    """Table -> domain from the "## Domains" table in docs/DATA_MODEL.md."""
    out = {}
    m = re.search(r"^## Domains\n(.*?)(?=^## )", text, re.S | re.M)
    if not m:
        return out
    for line in m.group(1).splitlines():
        cells = [c.strip() for c in line.strip().strip("|").split("|")]
        if len(cells) < 2 or cells[0] in ("Domain", "") or set(cells[0]) <= {"-"}:
            continue
        for name in re.findall(r"`([a-z_][a-z0-9_]*)`", cells[1]):
            out.setdefault(name, cells[0])
    return out


# ------------------------------------------------------------- rendering

def cell(s):
    return (s or "").replace("|", "\\|").replace("\n", " ")


def code(s):
    if not s:
        return ""
    s = s.replace("|", "\\|")
    return f"``{s}``" if "`" in s else f"`{s}`"


def anchor(name):
    return name  # GitHub heading anchors keep lowercase letters, digits and underscores


def priv_text(privs):
    if set(privs) >= set(ALL_PRIVS):
        return "all"
    if not privs:
        return "none"
    return ", ".join(p.upper() for p in ALL_PRIVS if p in privs)


def column_notes(t, col):
    notes = []
    for con in t.constraints.values():
        if con.cols == [col.name] and con.kind == "PRIMARY KEY":
            notes.append("PK")
        elif con.cols == [col.name] and con.kind == "UNIQUE":
            notes.append("unique")
        elif con.kind == "FOREIGN KEY" and con.cols == [col.name]:
            notes.append("FK → " + con.definition.split("→ ")[1].split("(")[0])
    if col.identity:
        notes.append(f"identity ({col.identity})")
    if col.generated:
        notes.append(f"generated: {code(col.generated)}")
    if col.migration != t.migration:
        notes.append("added in " + col.migration.split("_")[0])
    return ", ".join(notes)


def render_doc(schema, files, owner):
    tables = schema.tables
    by_domain = {}
    for name in tables:
        by_domain.setdefault(owner.get(name, "Unassigned"), []).append(name)
    domain_order = []
    for d in owner.values():
        if d not in domain_order:
            domain_order.append(d)
    if "Unassigned" in by_domain:
        domain_order.append("Unassigned")
    n_cols = sum(len(t.columns) for t in tables.values())
    n_cons = sum(len(t.constraints) for t in tables.values())
    n_idx = sum(len(t.indexes) for t in tables.values())
    n_key = sum(1 for t in tables.values() for c in t.constraints.values() if c.kind in ("PRIMARY KEY", "UNIQUE"))
    n_pol = sum(len(t.policies) for t in tables.values())
    out = [
        "# Montra — Data Dictionary",
        "",
        "<!-- GENERATED by scripts/docs/gen_data_dictionary.py from supabase/migrations; do not edit by hand. -->",
        "",
        "Every table in schema `montra`, computed by replaying",
        f"`supabase/migrations/*.sql` in order ({len(files)} files, `{files[0]}` to `{files[-1]}`).",
        "The migrations are the source of truth: regenerate with `make docs`, and",
        "`make docs-check` (CI) fails when this file is stale. Entities, invariants and",
        "domain notes are in [DATA_MODEL.md](DATA_MODEL.md); the live policy and grant",
        "matrix is in [RLS_POLICY_MATRIX.md](RLS_POLICY_MATRIX.md); retention is in",
        "[PRIVACY.md](PRIVACY.md) and [BACKGROUND_JOBS.md](BACKGROUND_JOBS.md).",
        "",
        f"**Totals:** {len(tables)} tables, {n_cols} columns, {n_cons} named constraints",
        f"(primary key, foreign key, unique, check), {n_idx} explicit indexes (plus {n_key} that back",
        f"primary-key and unique constraints), {n_pol} RLS policies.",
        "`schema_migrations` is created by `cmd/migrate`, not by the migrations, and is not listed.",
        "",
        "How to read a table entry:",
        "",
        "- **Domain** comes from the Domains table in DATA_MODEL.md.",
        "- **Null** is `no` for `NOT NULL` columns (primary-key and identity columns included).",
        "- **Constraints** use the names PostgreSQL assigns when a migration does not name",
        "  one. `NOT NULL` is shown per column, not repeated as a constraint.",
        "- **RLS helper** is the foundation helper that created the standard policies:",
        "  `apply_owner_rls(owner_col=…)` (API role sees rows whose owner column is",
        "  `montra.current_user_id()`, worker sees all) or `apply_worker_rls()` (worker only;",
        "  API access comes from the table's own policies). `make_append_only(…)` revokes",
        "  UPDATE and DELETE from the API role and UPDATE from the worker (DELETE too",
        "  when `allow_worker_delete=false`).",
        "- **Privileges** are the table privileges left for `montra_app` (API) and",
        "  `montra_worker` after the default grants and every `grant`/`revoke`.",
        "",
        "## Tables by domain",
        "",
        "| Domain | Tables |",
        "|---|---|",
    ]
    for d in domain_order:
        names = sorted(by_domain.get(d, []))
        if names:
            out.append(f"| {d} | " + ", ".join(f"[`{n}`](#{anchor(n)})" for n in names) + " |")
    out.append("")
    unassigned = sorted(by_domain.get("Unassigned", []))
    if unassigned:
        out += ["Unassigned tables (add them to the Domains table in DATA_MODEL.md): "
                + ", ".join(f"`{n}`" for n in unassigned), ""]
    missing = sorted(n for n in owner if n not in tables)
    if missing:
        out += ["Listed in DATA_MODEL.md but not created by any migration: "
                + ", ".join(f"`{n}`" for n in missing), ""]

    out += ["## Tables", ""]
    for name in sorted(tables):
        t = tables[name]
        out.append(f"### {name}")
        out.append("")
        meta = [f"**Domain:** {owner.get(name, 'Unassigned')}", f"**Created in:** `{t.migration}`"]
        if t.altered_in:
            meta.append("**Changed in:** " + ", ".join(f"`{m}`" for m in t.altered_in))
        out.append(" · ".join(meta))
        out.append("")
        if t.comment:
            out += [t.comment, ""]
        rls = "enabled" if t.rls else "**disabled**"
        if t.force_rls:
            rls += " (forced)"
        helpers = sorted({h for h in t.helpers if h.split("(")[0] in ("apply_owner_rls", "apply_worker_rls", "make_append_only")})
        line = f"**RLS:** {rls}"
        if helpers:
            line += " · **RLS helper:** " + ", ".join(f"`{h}`" for h in helpers)
        line += f" · **Privileges:** API {priv_text(t.privs['montra_app'])}; worker {priv_text(t.privs['montra_worker'])}"
        out += [line, ""]
        out += ["| Column | Type | Null | Default | Notes |", "|---|---|---|---|---|"]
        for col in t.columns.values():
            out.append(f"| `{col.name}` | {cell(col.type)} | {'yes' if col.nullable else 'no'} | "
                       f"{code(col.default)} | {column_notes(t, col)} |")
        out.append("")
        if t.constraints:
            out += ["Constraints:", "", "| Name | Type | Definition |", "|---|---|---|"]
            order = {"PRIMARY KEY": 0, "FOREIGN KEY": 1, "UNIQUE": 2, "CHECK": 3, "EXCLUDE": 4}
            for con in sorted(t.constraints.values(), key=lambda c: (order[c.kind], c.name)):
                out.append(f"| `{con.name}` | {con.kind} | {code(con.definition)} |")
            out.append("")
        if t.indexes:
            out += ["Indexes:", "", "| Name | Unique | Definition | Where |", "|---|---|---|---|"]
            for iname in sorted(t.indexes):
                ix = t.indexes[iname]
                out.append(f"| `{iname}` | {'yes' if ix['unique'] else ''} | {code(ix['definition'])} | {code(ix['where'])} |")
            out.append("")
        if t.policies:
            out += ["Policies:", "", "| Policy | Command | Roles | USING | WITH CHECK |", "|---|---|---|---|---|"]
            for pname in sorted(t.policies):
                p = t.policies[pname]
                kind = " (restrictive)" if p["kind"] == "restrictive" else ""
                out.append(f"| `{pname}`{kind} | {p['cmd']} | {', '.join(p['roles'])} | {code(p['using'])} | {code(p['check'])} |")
            out.append("")
        if t.triggers:
            out.append("Triggers: " + ", ".join(
                f"`{n}` ({t.triggers[n]['timing']} → `{t.triggers[n]['function']}()`)" for n in sorted(t.triggers)))
            out.append("")

    helpers = sorted(schema.functions)
    out += [
        "## Functions",
        "",
        "Functions defined by the migrations (latest definition). `security definer`",
        "functions run with the owner's rights and are the RLS access checks the",
        "policies call (for example `is_group_member`); see SECURITY.md and",
        "RLS_POLICY_MATRIX.md for their grants.",
        "",
        "| Function | Returns | Language | Security definer | Defined in |",
        "|---|---|---|---|---|",
    ]
    for fname in helpers:
        f = schema.functions[fname]
        out.append(f"| `{fname}({cell(f.args)})` | {cell(f.returns)} | {f.language} | {'yes' if f.secdef else ''} | `{f.migration}` |")
    out.append("")
    return "\n".join(out)


def main(argv):
    check = "--check" in argv[1:]
    schema, files = load()
    owner = domains(DATA_MODEL.read_text(encoding="utf-8"))
    text = render_doc(schema, files, owner)
    current = DOC.read_text(encoding="utf-8") if DOC.exists() else ""
    if check:
        if current != text:
            print("docs/DATA_DICTIONARY.md is out of date; run: python3 scripts/docs/gen_data_dictionary.py",
                  file=sys.stderr)
            return 1
        return 0
    if current != text:
        DOC.write_text(text, encoding="utf-8")
        print(f"wrote {DOC.relative_to(ROOT)} ({len(schema.tables)} tables)")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
