#!/usr/bin/env python3
"""Unit tests for gen_data_dictionary.py (stdlib unittest, inline SQL fixtures).

Run: python3 -B -m unittest scripts/docs/test_gen_data_dictionary.py
"""
import pathlib
import sys
import unittest

sys.dont_write_bytecode = True  # keep scripts/docs free of __pycache__
sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent))
import gen_data_dictionary as dd  # noqa: E402

# Same shape as the foundation helpers in 20261104000001_foundation.sql.
HELPERS = """
alter default privileges in schema montra grant select, insert, update, delete on tables to montra_app, montra_worker;
create or replace function montra.current_user_id() returns uuid
language sql stable as $$ select nullif(current_setting('montra.user_id', true), '')::uuid $$;
create or replace function montra.apply_owner_rls(tbl regclass, owner_col text default 'user_id') returns void
language plpgsql as $$
begin
  execute format('alter table %s enable row level security', tbl);
  execute format('create policy app_owner_all on %s for all to montra_app using (%I = montra.current_user_id()) with check (%I = montra.current_user_id())', tbl, owner_col, owner_col);
  execute format('create policy worker_all on %s for all to montra_worker using (true) with check (true)', tbl);
end $$;
create or replace function montra.make_append_only(tbl regclass, allow_worker_delete boolean default true) returns void
language plpgsql as $$
begin
  execute format('revoke update, delete on %s from montra_app', tbl);
  execute format('revoke update on %s from montra_worker', tbl);
  if not allow_worker_delete then
    execute format('revoke delete on %s from montra_worker', tbl);
  end if;
end $$;
create table users (
  id uuid primary key default gen_random_uuid(),
  email text not null unique check (char_length(email) <= 320)
);
"""


def replay(*sqls):
    schema = dd.Schema()
    for k, sql in enumerate((HELPERS,) + sqls):
        schema.migration = f"2026010100000{k}_m.sql"
        schema.run_sql(sql, dd.preceding_comment)
    return schema


class CreateTableTest(unittest.TestCase):
    def test_columns_types_nullability_defaults(self):
        s = replay("""
-- Things a user owns.
create table things (
  id         bigint generated always as identity primary key,
  user_id    uuid not null references users(id) on delete cascade,
  amount     numeric(20, 6),
  tags       text[] not null default '{}',
  is_big     boolean not null generated always as (amount > 100) stored,
  created_at timestamptz not null default now(),
  constraint things_amount_positive check (amount > 0),
  unique (user_id, created_at)
);""")
        t = s.tables["things"]
        self.assertEqual(t.comment, "Things a user owns.")
        self.assertEqual(list(t.columns), ["id", "user_id", "amount", "tags", "is_big", "created_at"])
        self.assertFalse(t.columns["id"].nullable)
        self.assertEqual(t.columns["id"].identity, "always")
        self.assertEqual(t.columns["amount"].type, "numeric(20, 6)")
        self.assertTrue(t.columns["amount"].nullable)
        self.assertEqual(t.columns["tags"].type, "text[]")
        self.assertEqual(t.columns["tags"].default, "'{}'")
        self.assertEqual(t.columns["is_big"].generated, "amount > 100")
        self.assertEqual(t.columns["created_at"].default, "now()")
        self.assertEqual(sorted(t.constraints), [
            "things_amount_positive", "things_pkey", "things_user_id_created_at_key", "things_user_id_fkey"])
        fk = t.constraints["things_user_id_fkey"]
        self.assertEqual(fk.definition, "(user_id) → users(id) ON DELETE CASCADE")

    def test_postgres_constraint_names(self):
        s = replay("""
create table notes (
  id    uuid primary key,
  body  text check (char_length(body) <= 10),
  lo    integer,
  hi    integer,
  check (lo <= hi),
  check (lo >= 0)
);""")
        names = sorted(s.tables["notes"].constraints)
        # One referenced column -> <table>_<col>_check; several -> <table>_check.
        self.assertEqual(names, ["notes_body_check", "notes_check", "notes_lo_check", "notes_pkey"])
        self.assertEqual(sorted(s.tables["users"].constraints), ["users_email_check", "users_email_key", "users_pkey"])

    def test_long_names_are_truncated_like_postgres(self):
        self.assertEqual(len(dd.make_object_name("a" * 40, "b" * 40, "check")), 63)
        self.assertEqual(dd.make_object_name("tbl", "col", "fkey"), "tbl_col_fkey")
        self.assertEqual(dd.choose_name("t", "c", "check", {"t_c_check"}), "t_c_check1")


class AlterTest(unittest.TestCase):
    def test_later_migrations_change_the_table(self):
        s = replay(
            "create table jobs (id uuid primary key, kind text not null check (kind in ('a','b')));",
            """
alter table jobs add column note text check (char_length(note) <= 5),
  add column if not exists kind text;
alter table jobs drop constraint jobs_kind_check;
alter table jobs add constraint jobs_kind_check check (kind in ('a','b','c'));
alter table jobs alter column note set default 'x';
alter table jobs alter column note set not null;
create index if not exists jobs_note_idx on montra.jobs (note) where note is not null;
create index if not exists jobs_note_idx on jobs (note);
""")
        t = s.tables["jobs"]
        self.assertEqual(list(t.columns), ["id", "kind", "note"])
        self.assertFalse(t.columns["note"].nullable)
        self.assertEqual(t.columns["note"].default, "'x'")
        self.assertEqual(t.columns["note"].migration, "20260101000002_m.sql")
        self.assertEqual(t.constraints["jobs_kind_check"].definition, "kind in ('a', 'b', 'c')")
        self.assertIn("jobs_note_check", t.constraints)
        self.assertEqual(t.indexes["jobs_note_idx"]["where"], "note is not null")
        self.assertEqual(t.altered_in, ["20260101000002_m.sql"])

    def test_drop_column_and_index(self):
        s = replay("create table a (id uuid primary key, x text, y text);\n"
                   "create index a_x_idx on a (x);",
                   "alter table a drop column x; drop index if exists a_x_idx; drop index if exists nope;")
        self.assertEqual(list(s.tables["a"].columns), ["id", "y"])
        self.assertEqual(s.tables["a"].indexes, {})


class RlsTest(unittest.TestCase):
    def test_helpers_are_interpreted(self):
        s = replay("""
create table notes (id uuid primary key, owner_user_id uuid not null);
select apply_owner_rls('notes', 'owner_user_id');
select make_append_only('notes', false);
""")
        t = s.tables["notes"]
        self.assertTrue(t.rls)
        self.assertEqual(sorted(t.policies), ["app_owner_all", "worker_all"])
        self.assertEqual(t.policies["app_owner_all"]["using"], "owner_user_id = montra.current_user_id()")
        self.assertEqual(t.policies["app_owner_all"]["roles"], ["montra_app"])
        self.assertEqual(t.helpers, ["apply_owner_rls(owner_col=owner_user_id)",
                                     "make_append_only(allow_worker_delete=false)"])
        self.assertEqual(t.privs["montra_app"], {"select", "insert"})
        self.assertEqual(t.privs["montra_worker"], {"select", "insert"})

    def test_triggers(self):
        s = replay("""
create table notes (id uuid primary key, parent_id uuid);
create or replace function montra.notes_guard() returns trigger language plpgsql as $$ begin return new; end $$;
create trigger notes_guard before insert or update of parent_id on montra.notes
  for each row execute function montra.notes_guard();
""")
        self.assertEqual(s.tables["notes"].triggers["notes_guard"]["timing"], "before insert or update of parent_id")
        self.assertEqual(s.tables["notes"].triggers["notes_guard"]["function"], "notes_guard")

    def test_do_blocks_loops_and_guards(self):
        s = replay("""
create table g1 (id uuid primary key, group_id uuid);
create table g2 (id uuid primary key, group_id uuid);
do $$
declare t text;
begin
  foreach t in array array['g1','g2']
  loop
    execute format('alter table montra.%I enable row level security', t);
    execute format('create policy app_select on montra.%I for select to montra_app using (group_id is not null)', t);
  end loop;
end $$;
do $$
begin
  if not exists (select 1 from pg_policies where policyname = 'extra') then
    create policy extra on g1 for delete to montra_app using (true);
  end if;
end $$;
drop policy app_select on g2;
revoke delete on g1, g2 from montra_app;
""")
        self.assertEqual(sorted(s.tables["g1"].policies), ["app_select", "extra"])
        self.assertEqual(s.tables["g1"].policies["app_select"]["cmd"], "SELECT")
        self.assertEqual(sorted(s.tables["g2"].policies), [])
        self.assertTrue(s.tables["g2"].rls)
        self.assertNotIn("delete", s.tables["g1"].privs["montra_app"])

    def test_unsupported_statements_fail(self):
        with self.assertRaises(dd.SQLError):
            replay("create view v as select 1;")
        with self.assertRaises(dd.SQLError):
            replay("alter table users add column x text;\nalter table nope add column y text;")


class DomainsTest(unittest.TestCase):
    def test_domain_table(self):
        text = ("## Domains\n\n| Domain | Tables | Notes |\n|---|---|---|\n"
                "| Identity | `users`, `profiles` | x |\n| Planning | `budgets` | y |\n\n## Next\n")
        self.assertEqual(dd.domains(text), {"users": "Identity", "profiles": "Identity", "budgets": "Planning"})


class RepositoryTest(unittest.TestCase):
    def test_real_migrations_replay(self):
        schema, files = dd.load()
        self.assertGreater(len(files), 0)
        for t in schema.tables.values():
            self.assertTrue(t.rls, f"{t.name} has RLS disabled")
            self.assertTrue(any(c.kind == "PRIMARY KEY" for c in t.constraints.values()), f"{t.name} has no primary key")


if __name__ == "__main__":
    unittest.main()
