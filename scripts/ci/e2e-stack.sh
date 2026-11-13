#!/usr/bin/env bash
# Starts (or stops) a throwaway Montra API + worker for end-to-end tests.
#
# Used by the e2e jobs in .github/workflows/ci.yml and for reproducing them
# locally next to a running dev stack. It:
#   1. builds the api, worker and migrate binaries into the state directory;
#   2. generates throwaway encryption/URL-signing keys (never committed);
#   3. applies supabase/migrations with the project's own migrate command;
#   4. starts the API and the worker from the state directory, so a
#      developer's backend/.env.local is never loaded, and waits until the API
#      reports ready.
# Development-only adapters are used: local_disk storage, dev_mailbox email,
# AI disabled, manual FX, auto-verified email and a relaxed auth rate limit.
#
# Usage: scripts/ci/e2e-stack.sh start|stop
#
# Required environment (owner, API and worker roles; see scripts/db/bootstrap.sh):
#   E2E_DATABASE_MIGRATION_URL   postgres://montra_owner:...@localhost:5432/<db>
#   E2E_DATABASE_URL             postgres://montra_app:...@localhost:5432/<db>
#   E2E_WORKER_DATABASE_URL      postgres://montra_worker:...@localhost:5432/<db>
# Optional:
#   E2E_API_HOST            listen host (default 127.0.0.1)
#   E2E_API_PORT            listen port (default 8080)
#   E2E_WEB_ORIGIN          web origin for CORS and email links (default http://localhost:5199)
#   E2E_WORKER_METRICS_ADDR worker metrics listener (default 127.0.0.1:9191)
#   E2E_STATE_DIR           binaries, keys, storage, mailbox, logs, pids
#                           (default <repo>/.data/e2e-stack, git-ignored)
#
# The database must be local (localhost/127.0.0.1) and its name must end in
# _test or _dev (the migrate command refuses anything else without -yes).
# `stop` stops only the processes this script started (pid files).
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
STATE_DIR="${E2E_STATE_DIR:-$ROOT_DIR/.data/e2e-stack}"
API_HOST="${E2E_API_HOST:-127.0.0.1}"
API_PORT="${E2E_API_PORT:-8080}"
WEB_ORIGIN="${E2E_WEB_ORIGIN:-http://localhost:5199}"
WORKER_METRICS_ADDR="${E2E_WORKER_METRICS_ADDR:-127.0.0.1:9191}"

log() { echo "[e2e-stack] $*"; }
die() { echo "[e2e-stack] error: $*" >&2; exit 1; }

require_local_db() {
  local name="$1" url="$2" host
  [ -n "$url" ] || die "$name is required"
  host="$(printf '%s' "$url" | sed -nE 's#^postgres(ql)?://[^@]*@([^:/?]+).*#\2#p')"
  case "$host" in
    localhost | 127.0.0.1 | '[::1]') ;;
    *) die "$name must point at a local database (host was '${host:-unparsed}')" ;;
  esac
}

stop_pid() {
  local file="$STATE_DIR/$1.pid" pid
  [ -f "$file" ] || return 0
  pid="$(cat "$file")"
  if kill -0 "$pid" 2>/dev/null; then
    kill "$pid" 2>/dev/null || true
    for _ in $(seq 1 50); do
      kill -0 "$pid" 2>/dev/null || break
      sleep 0.2
    done
    kill -9 "$pid" 2>/dev/null || true
    log "stopped $1 (pid $pid)"
  fi
  rm -f "$file"
}

export_runtime_env() {
  # shellcheck disable=SC1091
  . "$STATE_DIR/keys.env"
  export APP_ENV=development
  export LOG_LEVEL=info LOG_FORMAT=text APP_VERSION=e2e
  export HTTP_ADDR="$API_HOST:$API_PORT"
  export PUBLIC_API_BASE_URL="http://localhost:$API_PORT"
  export WEB_APP_URL="$WEB_ORIGIN"
  export CORS_ALLOWED_ORIGINS="$WEB_ORIGIN"
  export HTTP_ENABLE_DOCS=false
  export DATABASE_URL="$E2E_DATABASE_URL"
  export WORKER_DATABASE_URL="$E2E_WORKER_DATABASE_URL"
  export DATABASE_MAX_CONNS=10
  export DATA_ENCRYPTION_KEYS URL_SIGNING_KEY
  export AUTH_COOKIE_SECURE=false
  export AUTH_REQUIRE_EMAIL_VERIFIED=true
  export AUTH_DEV_AUTO_VERIFY_EMAIL=true
  export AUTH_DEV_RATE_PER_MINUTE=600
  export STORAGE_PROVIDER=local_disk STORAGE_LOCAL_DIR="$STATE_DIR/storage"
  export EMAIL_PROVIDER=dev_mailbox DEV_MAIL_DIR="$STATE_DIR/mail"
  export AI_PROVIDER=disabled FX_PROVIDER=manual
  export WORKER_CONCURRENCY=4 WORKER_SCHEDULER_ENABLED=true
  export WORKER_METRICS_ADDR
}

cmd_start() {
  require_local_db E2E_DATABASE_MIGRATION_URL "${E2E_DATABASE_MIGRATION_URL:-}"
  require_local_db E2E_DATABASE_URL "${E2E_DATABASE_URL:-}"
  require_local_db E2E_WORKER_DATABASE_URL "${E2E_WORKER_DATABASE_URL:-}"
  command -v openssl >/dev/null || die "openssl is required"
  command -v go >/dev/null || die "go is required"
  if curl -fsS -o /dev/null "http://$API_HOST:$API_PORT/health/live" 2>/dev/null; then
    die "something already answers on $API_HOST:$API_PORT; pick another E2E_API_PORT"
  fi

  mkdir -p "$STATE_DIR/bin" "$STATE_DIR/storage" "$STATE_DIR/mail"
  log "state dir: $STATE_DIR"

  log "building api, worker, migrate"
  (cd "$ROOT_DIR/backend" && CGO_ENABLED=0 go build -trimpath -o "$STATE_DIR/bin/" ./cmd/api ./cmd/worker ./cmd/migrate)

  if [ ! -f "$STATE_DIR/keys.env" ]; then
    umask 077
    {
      echo "DATA_ENCRYPTION_KEYS=e2e1:$(openssl rand -base64 32 | tr -d '\n')"
      echo "URL_SIGNING_KEY=$(openssl rand -base64 32 | tr -d '\n')"
    } > "$STATE_DIR/keys.env"
    log "generated throwaway keys"
  fi

  # Run from the state directory so no .env.local is picked up.
  cd "$STATE_DIR"
  log "migrating"
  env -i PATH="$PATH" HOME="${HOME:-/tmp}" DATABASE_MIGRATION_URL="$E2E_DATABASE_MIGRATION_URL" \
    ./bin/migrate up -dir "$ROOT_DIR/supabase/migrations"

  export_runtime_env

  log "starting api on $HTTP_ADDR"
  nohup ./bin/api > "$STATE_DIR/api.log" 2>&1 &
  echo $! > "$STATE_DIR/api.pid"

  local ready=0
  for _ in $(seq 1 120); do
    if curl -fs -o /dev/null "http://$API_HOST:$API_PORT/health/ready"; then
      ready=1
      break
    fi
    kill -0 "$(cat "$STATE_DIR/api.pid")" 2>/dev/null || break
    sleep 0.5
  done
  if [ "$ready" != 1 ]; then
    tail -n 50 "$STATE_DIR/api.log" >&2 || true
    die "API did not become ready"
  fi
  log "api ready"

  log "starting worker (metrics on $WORKER_METRICS_ADDR)"
  nohup ./bin/worker > "$STATE_DIR/worker.log" 2>&1 &
  echo $! > "$STATE_DIR/worker.pid"
  sleep 2
  if ! kill -0 "$(cat "$STATE_DIR/worker.pid")" 2>/dev/null; then
    tail -n 50 "$STATE_DIR/worker.log" >&2 || true
    die "worker exited during start-up"
  fi
  log "worker running"
  log "dev mailbox: $STATE_DIR/mail (set MONTRA_DEV_MAILBOX to this for Playwright)"
}

cmd_stop() {
  stop_pid worker
  stop_pid api
}

case "${1:-}" in
  start) cmd_start ;;
  stop) cmd_stop ;;
  *) die "usage: $0 start|stop" ;;
esac
