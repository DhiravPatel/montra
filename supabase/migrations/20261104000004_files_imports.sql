-- Files (Appwrite object metadata), receipts and extraction candidates,
-- transaction attachments, statement imports and reconciliation.
set local search_path = montra, extensions, public;

create table files (
  id                uuid primary key default gen_random_uuid(),
  owner_user_id     uuid not null references users(id) on delete cascade,
  group_id          uuid,
  storage_area      text not null check (storage_area in ('private','group','public_media','temp','exports')),
  provider          text not null check (provider in ('appwrite','local_disk')),
  bucket            text not null check (char_length(bucket) between 1 and 64),
  object_key        text not null check (object_key ~ '^[a-zA-Z0-9][a-zA-Z0-9._-]{0,35}$'),
  purpose           text not null check (purpose in ('receipt','bill_document','statement_import','group_attachment',
                      'trip_document','avatar','community_media','report_export','user_export','transaction_attachment',
                      'goal_attachment','subscription_invoice')),
  original_filename text check (char_length(original_filename) <= 255),
  declared_mime     text check (char_length(declared_mime) <= 127),
  detected_mime     text check (char_length(detected_mime) <= 127),
  extension         text check (extension ~ '^[a-z0-9]{1,10}$'),
  size_bytes        bigint check (size_bytes >= 0),
  expected_size_bytes bigint check (expected_size_bytes > 0),
  checksum_sha256   text check (checksum_sha256 ~ '^[0-9a-f]{64}$'),
  expected_checksum_sha256 text check (expected_checksum_sha256 ~ '^[0-9a-f]{64}$'),
  status            text not null default 'pending_upload'
                    check (status in ('pending_upload','uploaded','processing','ready','rejected','quarantined','deleting','deleted')),
  rejection_reason  text check (char_length(rejection_reason) <= 200),
  image_width       integer check (image_width > 0),
  image_height      integer check (image_height > 0),
  page_count        integer check (page_count > 0),
  scan_status       text not null default 'not_scanned' check (scan_status in ('not_scanned','clean','infected','error','skipped')),
  upload_token_hash bytea,
  upload_expires_at timestamptz,
  retention_until   timestamptz,
  deleted_at        timestamptz,
  created_at        timestamptz not null default now(),
  updated_at        timestamptz not null default now()
);
create unique index files_object_key on files (provider, bucket, object_key);
create unique index files_upload_token_key on files (upload_token_hash) where upload_token_hash is not null;
create index files_owner_idx on files (owner_user_id, purpose, created_at desc);
create index files_checksum_idx on files (owner_user_id, checksum_sha256) where checksum_sha256 is not null;
create index files_cleanup_idx on files (status, retention_until);
create index files_group_idx on files (group_id) where group_id is not null;
select add_touch_trigger('files');
select apply_owner_rls('files', 'owner_user_id');
revoke delete on files from montra_app;

alter table profiles add constraint profiles_avatar_file_fkey
  foreign key (avatar_file_id) references files(id) on delete set null;

create table transaction_attachments (
  id             uuid primary key default gen_random_uuid(),
  user_id        uuid not null references users(id) on delete cascade,
  transaction_id uuid not null references transactions(id) on delete cascade,
  file_id        uuid not null references files(id) on delete cascade,
  created_at     timestamptz not null default now()
);
create unique index transaction_attachments_key on transaction_attachments (transaction_id, file_id);
create index transaction_attachments_file_idx on transaction_attachments (file_id);
select apply_owner_rls('transaction_attachments');

create table receipts (
  id                    uuid primary key default gen_random_uuid(),
  user_id               uuid not null references users(id) on delete cascade,
  status                text not null default 'uploaded' check (status in ('uploaded','processing','needs_review','reviewed',
                          'matched','failed','discarded')),
  current_extraction_id uuid,
  transaction_id        uuid references transactions(id) on delete set null,
  duplicate_of_id       uuid references receipts(id) on delete set null,
  reviewed_by           uuid references users(id) on delete set null,
  reviewed_at           timestamptz,
  notes                 text check (char_length(notes) <= 1000),
  version               integer not null default 1,
  created_at            timestamptz not null default now(),
  updated_at            timestamptz not null default now()
);
create index receipts_user_idx on receipts (user_id, status, created_at desc);
select add_touch_trigger('receipts');
select apply_owner_rls('receipts');

create table receipt_files (
  receipt_id uuid not null references receipts(id) on delete cascade,
  file_id    uuid not null references files(id) on delete cascade,
  user_id    uuid not null references users(id) on delete cascade,
  page_no    smallint not null default 1 check (page_no between 1 and 50),
  primary key (receipt_id, file_id)
);
create unique index receipt_files_page_key on receipt_files (receipt_id, page_no);
select apply_owner_rls('receipt_files');

create table receipt_extractions (
  id                 uuid primary key default gen_random_uuid(),
  receipt_id         uuid not null references receipts(id) on delete cascade,
  user_id            uuid not null references users(id) on delete cascade,
  version            integer not null,
  method             text not null check (method in ('deterministic_text','ai_vision','manual')),
  provider           text,
  model              text,
  extractor_version  text not null,
  status             text not null default 'queued' check (status in ('queued','running','succeeded','failed')),
  merchant_name      text check (char_length(merchant_name) <= 200),
  receipt_date       date,
  receipt_time       time,
  currency           text references currencies(code),
  subtotal_minor     bigint check (subtotal_minor >= 0),
  tax_minor          bigint check (tax_minor >= 0),
  tip_minor          bigint check (tip_minor >= 0),
  discount_minor     bigint check (discount_minor >= 0),
  total_minor        bigint check (total_minor >= 0),
  payment_hint       text check (char_length(payment_hint) <= 60),
  receipt_number     text check (char_length(receipt_number) <= 80),
  field_confidence   jsonb not null default '{}'::jsonb,
  overall_confidence numeric(4,3) check (overall_confidence between 0 and 1),
  warnings           text[] not null default '{}',
  error_code         text,
  created_at         timestamptz not null default now(),
  completed_at       timestamptz
);
create unique index receipt_extractions_version_key on receipt_extractions (receipt_id, version);
select apply_owner_rls('receipt_extractions');
alter table receipts add constraint receipts_current_extraction_fkey
  foreign key (current_extraction_id) references receipt_extractions(id) on delete set null deferrable initially deferred;

create table receipt_line_items (
  id               uuid primary key default gen_random_uuid(),
  extraction_id    uuid not null references receipt_extractions(id) on delete cascade,
  user_id          uuid not null references users(id) on delete cascade,
  position         smallint not null check (position between 1 and 500),
  description      text check (char_length(description) <= 200),
  quantity         numeric(12,3) check (quantity > 0),
  unit_price_minor bigint check (unit_price_minor >= 0),
  amount_minor     bigint check (amount_minor >= 0),
  tax_minor        bigint check (tax_minor >= 0),
  confidence       numeric(4,3) check (confidence between 0 and 1)
);
create unique index receipt_line_items_pos_key on receipt_line_items (extraction_id, position);
select apply_owner_rls('receipt_line_items');

alter table transactions add constraint transactions_receipt_fkey
  foreign key (receipt_id) references receipts(id) on delete set null;

create table import_batches (
  id                   uuid primary key default gen_random_uuid(),
  user_id              uuid not null references users(id) on delete cascade,
  account_id           uuid not null references financial_accounts(id) on delete cascade,
  file_id              uuid references files(id) on delete set null,
  source_format        text check (source_format in ('csv','xlsx','ofx','qfx','pdf')),
  parser_version       text,
  status               text not null default 'awaiting_upload' check (status in ('awaiting_upload','uploaded','parsing',
                         'needs_mapping','preview_ready','confirmed','processing','completed','completed_with_errors',
                         'failed','cancelled')),
  detected_encoding    text,
  file_fingerprint     text check (file_fingerprint ~ '^[0-9a-f]{64}$'),
  mapping              jsonb not null default '{}'::jsonb,
  header_row           text[],
  total_rows           integer not null default 0,
  valid_rows           integer not null default 0,
  invalid_rows         integer not null default 0,
  duplicate_rows       integer not null default 0,
  imported_count       integer not null default 0,
  skipped_count        integer not null default 0,
  failed_count         integer not null default 0,
  statement_start_date date,
  statement_end_date   date,
  statement_opening_balance_minor bigint,
  statement_closing_balance_minor bigint,
  totals_check         jsonb not null default '{}'::jsonb,
  error_code           text,
  error_message        text check (char_length(error_message) <= 500),
  version              integer not null default 1,
  created_at           timestamptz not null default now(),
  updated_at           timestamptz not null default now(),
  confirmed_at         timestamptz,
  completed_at         timestamptz,
  cancelled_at         timestamptz
);
create index import_batches_user_idx on import_batches (user_id, created_at desc);
create index import_batches_status_idx on import_batches (status, updated_at);
create index import_batches_fingerprint_idx on import_batches (user_id, account_id, file_fingerprint) where file_fingerprint is not null;
select add_touch_trigger('import_batches');
select apply_owner_rls('import_batches');

create table import_rows (
  id                          uuid primary key default gen_random_uuid(),
  batch_id                    uuid not null references import_batches(id) on delete cascade,
  user_id                     uuid not null references users(id) on delete cascade,
  row_number                  integer not null check (row_number > 0),
  raw                         jsonb not null,
  posted_date                 date,
  amount_minor                bigint check (amount_minor > 0),
  direction                   text check (direction in ('inflow','outflow')),
  currency                    text references currencies(code),
  description                 text check (char_length(description) <= 500),
  reference                   text check (char_length(reference) <= 200),
  balance_minor               bigint,
  category_id                 uuid references categories(id) on delete set null,
  fingerprint                 text check (char_length(fingerprint) <= 128),
  status                      text not null default 'parsed' check (status in ('parsed','invalid','duplicate','ready',
                                'imported','skipped','failed')),
  error_code                  text,
  error_message               text check (char_length(error_message) <= 300),
  duplicate_of_transaction_id uuid references transactions(id) on delete set null,
  transaction_id              uuid references transactions(id) on delete set null,
  user_decision               text check (user_decision in ('import','skip')),
  raw_purged_at               timestamptz,
  created_at                  timestamptz not null default now(),
  updated_at                  timestamptz not null default now()
);
create unique index import_rows_number_key on import_rows (batch_id, row_number);
create index import_rows_status_idx on import_rows (batch_id, status);
create index import_rows_fingerprint_idx on import_rows (user_id, fingerprint) where fingerprint is not null;
select add_touch_trigger('import_rows');
select apply_owner_rls('import_rows');

alter table transactions add constraint transactions_import_row_fkey
  foreign key (import_row_id) references import_rows(id) on delete set null;

create table reconciliation_matches (
  id           uuid primary key default gen_random_uuid(),
  user_id      uuid not null references users(id) on delete cascade,
  account_id   uuid not null references financial_accounts(id) on delete cascade,
  kind         text not null check (kind in ('statement_to_ledger','pending_to_posted','manual_to_imported')),
  cardinality  text not null default 'one_to_one' check (cardinality in ('one_to_one','one_to_many','many_to_one')),
  status       text not null default 'suggested' check (status in ('suggested','confirmed','rejected','unmatched')),
  confidence   numeric(4,3) check (confidence between 0 and 1),
  reasons      jsonb not null default '[]'::jsonb,
  created_by   text not null default 'system' check (created_by in ('system','user')),
  confirmed_at timestamptz,
  unmatched_at timestamptz,
  created_at   timestamptz not null default now(),
  updated_at   timestamptz not null default now()
);
create index reconciliation_matches_user_idx on reconciliation_matches (user_id, account_id, status);
select add_touch_trigger('reconciliation_matches');
select apply_owner_rls('reconciliation_matches');

create table reconciliation_match_items (
  id             uuid primary key default gen_random_uuid(),
  match_id       uuid not null references reconciliation_matches(id) on delete cascade,
  user_id        uuid not null references users(id) on delete cascade,
  side           text not null check (side in ('statement','ledger')),
  import_row_id  uuid references import_rows(id) on delete cascade,
  transaction_id uuid references transactions(id) on delete cascade,
  amount_minor   bigint not null check (amount_minor > 0),
  constraint reconciliation_item_target check ((import_row_id is not null) <> (transaction_id is not null))
);
create index reconciliation_items_match_idx on reconciliation_match_items (match_id);
create index reconciliation_items_tx_idx on reconciliation_match_items (transaction_id) where transaction_id is not null;
create index reconciliation_items_row_idx on reconciliation_match_items (import_row_id) where import_row_id is not null;
select apply_owner_rls('reconciliation_match_items');

create table account_reconciliations (
  id                      uuid primary key default gen_random_uuid(),
  user_id                 uuid not null references users(id) on delete cascade,
  account_id              uuid not null references financial_accounts(id) on delete cascade,
  statement_date          date not null,
  statement_balance_minor bigint not null,
  ledger_balance_minor    bigint not null,
  difference_minor        bigint not null,
  status                  text not null check (status in ('balanced','unbalanced')),
  import_batch_id         uuid references import_batches(id) on delete set null,
  notes                   text check (char_length(notes) <= 1000),
  created_at              timestamptz not null default now()
);
create index account_reconciliations_idx on account_reconciliations (account_id, statement_date desc);
select apply_owner_rls('account_reconciliations');
