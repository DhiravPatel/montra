#!/usr/bin/env bash
# Montra local database bootstrap (idempotent, non-destructive).
#
# Uses the PostgreSQL server ALREADY installed on this machine. It:
#   1. prints the target server (host, port, version, admin user);
#   2. creates roles montra_owner, montra_app, montra_worker if missing;
#   3. creates databases montra_dev and montra_test (owner montra_owner) if missing;
#   4. restricts CONNECT on those databases to Montra roles;
#   5. writes connection settings to backend/.env.local (git-ignored).
# It never drops, renames or alters any non-Montra role or database.
#
# Environment overrides:
#   PG_BIN            directory with psql (default: Homebrew postgresql@18, then PATH)
#   PGADMIN_HOST      default localhost
#   PGADMIN_PORT      default 5432
#   PGADMIN_USER      default current OS user (must be able to CREATE ROLE/DATABASE)
#   PGADMIN_DB        default postgres
#   MONTRA_ROTATE=1   regenerate passwords for the montra_* roles
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
ENV_FILE="$ROOT_DIR/backend/.env.local"

if [ -z "${PG_BIN:-}" ]; then
  if [ -x /opt/homebrew/opt/postgresql@18/bin/psql ]; then
    PG_BIN=/opt/homebrew/opt/postgresql@18/bin
  else
    PG_BIN="$(dirname "$(command -v psql)")"
  fi
fi
PSQL="$PG_BIN/psql"
HOST="${PGADMIN_HOST:-localhost}"
PORT="${PGADMIN_PORT:-5432}"
ADMIN_USER="${PGADMIN_USER:-$(whoami)}"
ADMIN_DB="${PGADMIN_DB:-postgres}"

psql_admin() {
  "$PSQL" -X -q -v ON_ERROR_STOP=1 -h "$HOST" -p "$PORT" -U "$ADMIN_USER" -d "${1:-$ADMIN_DB}" "${@:2}"
}

echo "== Montra database bootstrap"
SERVER_VERSION="$(psql_admin "$ADMIN_DB" -Atc 'show server_version')"
echo "   target server : $HOST:$PORT (PostgreSQL $SERVER_VERSION)"
echo "   admin user    : $ADMIN_USER"
echo "   creates (if missing): roles montra_owner, montra_app, montra_worker; databases montra_dev, montra_test"
echo "   writes        : $ENV_FILE (managed block only)"

MAJOR="${SERVER_VERSION%%.*}"
if [ "$MAJOR" -lt 15 ]; then
  echo "error: PostgreSQL 15+ required (Supabase-compatible target); found $SERVER_VERSION" >&2
  exit 1
fi

gen_secret() { openssl rand -base64 "${1:-24}" | tr -d '\n'; }
gen_password() { openssl rand -hex 24; }

role_exists() {
  [ "$(psql_admin "$ADMIN_DB" -Atc "select 1 from pg_roles where rolname = '$1'")" = "1" ]
}

db_exists() {
  [ "$(psql_admin "$ADMIN_DB" -Atc "select 1 from pg_database where datname = '$1'")" = "1" ]
}

read_env_value() {
  # read KEY from the managed env file, if present
  [ -f "$ENV_FILE" ] || return 0
  grep -E "^$1=" "$ENV_FILE" | head -1 | cut -d= -f2- || true
}

extract_password() {
  # extract password from postgres://user:pass@host/db
  printf '%s' "$1" | sed -nE 's#^postgres(ql)?://[^:]+:([^@]+)@.*#\2#p'
}

ensure_role() {
  local role="$1" password="$2"
  if role_exists "$role"; then
    if [ "${MONTRA_ROTATE:-0}" = "1" ] || [ "${3:-}" = "reset-password" ]; then
      psql_admin "$ADMIN_DB" -c "alter role $role with login password '$password'"
      echo "   role $role: password updated"
    else
      echo "   role $role: exists"
    fi
  else
    psql_admin "$ADMIN_DB" -c "create role $role with login nosuperuser nocreatedb nocreaterole noinherit noreplication nobypassrls password '$password'"
    echo "   role $role: created"
  fi
}

# Reuse existing passwords from the env file where possible.
OWNER_PW="$(extract_password "$(read_env_value DATABASE_MIGRATION_URL)")"
APP_PW="$(extract_password "$(read_env_value DATABASE_URL)")"
WORKER_PW="$(extract_password "$(read_env_value WORKER_DATABASE_URL)")"
RESET_FLAG=""
if [ -z "$OWNER_PW" ] || [ -z "$APP_PW" ] || [ -z "$WORKER_PW" ] || [ "${MONTRA_ROTATE:-0}" = "1" ]; then
  OWNER_PW="$(gen_password)"; APP_PW="$(gen_password)"; WORKER_PW="$(gen_password)"
  RESET_FLAG="reset-password"
fi

ensure_role montra_owner "$OWNER_PW" "$RESET_FLAG"
ensure_role montra_app "$APP_PW" "$RESET_FLAG"
ensure_role montra_worker "$WORKER_PW" "$RESET_FLAG"

for db in montra_dev montra_test; do
  if db_exists "$db"; then
    echo "   database $db: exists"
  else
    psql_admin "$ADMIN_DB" -c "create database $db owner montra_owner encoding 'UTF8' template template0"
    echo "   database $db: created"
  fi
  psql_admin "$ADMIN_DB" -c "revoke connect, temporary on database $db from public"
  psql_admin "$ADMIN_DB" -c "grant connect on database $db to montra_owner, montra_app, montra_worker"
  # The runtime roles must not create objects in public.
  psql_admin "$db" -c "revoke create on schema public from public"
done

for role in montra_app montra_worker montra_owner; do
  psql_admin "$ADMIN_DB" -c "alter role $role set search_path = montra, extensions"
done

URL_DEV_OWNER="postgres://montra_owner:$OWNER_PW@$HOST:$PORT/montra_dev?sslmode=disable"
URL_DEV_APP="postgres://montra_app:$APP_PW@$HOST:$PORT/montra_dev?sslmode=disable"
URL_DEV_WORKER="postgres://montra_worker:$WORKER_PW@$HOST:$PORT/montra_dev?sslmode=disable"
URL_TEST_OWNER="postgres://montra_owner:$OWNER_PW@$HOST:$PORT/montra_test?sslmode=disable"
URL_TEST_APP="postgres://montra_app:$APP_PW@$HOST:$PORT/montra_test?sslmode=disable"
URL_TEST_WORKER="postgres://montra_worker:$WORKER_PW@$HOST:$PORT/montra_test?sslmode=disable"

DEK="$(read_env_value DATA_ENCRYPTION_KEYS)"
[ -n "$DEK" ] || DEK="dev1:$(gen_secret 32)"
USK="$(read_env_value URL_SIGNING_KEY)"
[ -n "$USK" ] || USK="$(gen_secret 32)"

BLOCK_START="# >>> montra-db (managed by scripts/db/bootstrap.sh)"
BLOCK_END="# <<< montra-db"
TMP="$(mktemp)"
if [ -f "$ENV_FILE" ]; then
  awk -v s="$BLOCK_START" -v e="$BLOCK_END" '$0==s{skip=1;next} $0==e{skip=0;next} !skip' "$ENV_FILE" > "$TMP"
else
  cat > "$TMP" <<'EOF'
# Local development configuration (git-ignored). See backend/.env.example.
APP_ENV=development
LOG_LEVEL=debug
LOG_FORMAT=text
HTTP_ADDR=:8080
HTTP_ENABLE_DOCS=true
PUBLIC_API_BASE_URL=http://localhost:8080
WEB_APP_URL=http://localhost:5173
CORS_ALLOWED_ORIGINS=http://localhost:5173
AUTH_COOKIE_SECURE=false
STORAGE_PROVIDER=local_disk
STORAGE_LOCAL_DIR=.data/storage
EMAIL_PROVIDER=dev_mailbox
DEV_MAIL_DIR=.data/mail
AUTH_DEV_AUTO_VERIFY_EMAIL=true
AI_PROVIDER=disabled
FX_PROVIDER=manual
EOF
fi
{
  cat "$TMP"
  echo "$BLOCK_START"
  echo "DATABASE_URL=$URL_DEV_APP"
  echo "WORKER_DATABASE_URL=$URL_DEV_WORKER"
  echo "DATABASE_MIGRATION_URL=$URL_DEV_OWNER"
  echo "TEST_DATABASE_MIGRATION_URL=$URL_TEST_OWNER"
  echo "TEST_DATABASE_APP_URL=$URL_TEST_APP"
  echo "TEST_DATABASE_WORKER_URL=$URL_TEST_WORKER"
  echo "DATA_ENCRYPTION_KEYS=$DEK"
  echo "URL_SIGNING_KEY=$USK"
  echo "$BLOCK_END"
} > "$ENV_FILE"
rm -f "$TMP"
chmod 600 "$ENV_FILE"

echo "== done. Next: make migrate"
echo "   note: this server uses 'trust' authentication for localhost (pg_hba.conf, unchanged);"
echo "         role passwords are set for parity with hosted environments."
