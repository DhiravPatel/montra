-- Payment methods get optimistic concurrency like other editable records.
alter table payment_methods add column if not exists version integer not null default 1 check (version >= 1);
