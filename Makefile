# Montra monorepo commands. Run `make help` for a list.
# Uses tools already installed locally (see docs/OPERATIONS.md).
SHELL := /bin/bash
GOBIN ?= $(HOME)/go/bin
GOLANGCI ?= $(shell command -v golangci-lint 2>/dev/null || echo $(GOBIN)/golangci-lint)
SQLC ?= $(shell command -v sqlc 2>/dev/null || echo $(GOBIN)/sqlc)
FLUTTER ?= $(shell command -v flutter 2>/dev/null || echo flutter)

.PHONY: help
help: ## Show this help
	@grep -E '^[a-zA-Z_-]+:.*?## ' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-20s\033[0m %s\n", $$1, $$2}'

# ---------------------------------------------------------------- database
.PHONY: db-bootstrap migrate migrate-status seed db-reset-dev migrate-test
db-bootstrap: ## Create Montra roles + montra_dev/montra_test on the EXISTING local PostgreSQL (prints target first)
	./scripts/db/bootstrap.sh

migrate: ## Apply migrations to montra_dev (prints target first)
	cd backend && go run ./cmd/migrate up

migrate-status: ## Show migration status for montra_dev
	cd backend && go run ./cmd/migrate status

seed: ## Load deterministic synthetic seed data into montra_dev
	cd backend && go run ./cmd/migrate seed

db-reset-dev: ## DESTRUCTIVE for montra_dev only: drop schema montra and re-migrate (asks for confirmation)
	@read -p "Type montra_dev to confirm reset of schema montra in montra_dev: " c; cd backend && go run ./cmd/migrate reset -confirm $$c

migrate-test: ## Apply migrations to montra_test
	cd backend && set -a && . ./.env.local && set +a && go run ./cmd/migrate up -url "$$TEST_DATABASE_MIGRATION_URL"

# ----------------------------------------------------------------- backend
.PHONY: api worker sqlc contract contract-check fmt lint test-backend test-integration load-test fuzz build-backend vuln
api: ## Run the Go API on :8080
	cd backend && go run ./cmd/api

worker: ## Run the Go worker (jobs, scheduler, outbox)
	cd backend && go run ./cmd/worker

sqlc: ## Regenerate sqlc query code from backend/internal/store/queries
	cd backend && $(SQLC) generate

contract: ## Regenerate contracts/openapi/montra.v1.json from the Go API
	cd backend && go run ./cmd/openapi -out ../contracts/openapi/montra.v1.json

contract-check: ## Fail if the committed contract is out of date
	cd backend && go run ./cmd/openapi -check -out ../contracts/openapi/montra.v1.json

.PHONY: docs docs-check
docs: ## Regenerate generated doc sections (error-code tables in docs/API.md)
	python3 scripts/docs/gen_error_codes.py

docs-check: ## Fail if generated doc sections are out of date
	python3 scripts/docs/gen_error_codes.py --check

fmt: ## Format Go code
	cd backend && gofmt -w ./cmd ./internal ./tests

lint: ## Lint Go code
	cd backend && go vet ./... && $(GOLANGCI) run ./...

test-backend: ## Go unit tests (no database)
	cd backend && go test ./internal/...

test-integration: ## Go integration + RLS + API tests against montra_test (sequential packages)
	cd backend && go test -p 1 -count=1 ./tests/... ./internal/...

load-test: ## Local load test against the dev API (refuses non-local targets; never production)
	cd backend && go run ./cmd/loadtest -users 10 -duration 60s -rate 2

fuzz: ## Short fuzz run for money and split allocation
	cd backend && go test ./internal/domain/money -run=^$$ -fuzz=FuzzParseFormatRoundTrip -fuzztime=20s
	cd backend && go test ./internal/domain/split -run=^$$ -fuzz=FuzzByWeights -fuzztime=20s

build-backend: ## Build api, worker and migrate binaries
	cd backend && CGO_ENABLED=0 go build -trimpath -o bin/api ./cmd/api && CGO_ENABLED=0 go build -trimpath -o bin/worker ./cmd/worker && CGO_ENABLED=0 go build -trimpath -o bin/migrate ./cmd/migrate

vuln: ## Dependency vulnerability scan (requires govulncheck)
	cd backend && go run golang.org/x/vuln/cmd/govulncheck@v1.1.4 ./...

# --------------------------------------------------------------------- web
.PHONY: web web-test web-build web-lint gen-web-api
web: ## Run the React portal on :5173 (proxies /api to :8080)
	cd web && pnpm dev

gen-web-api: ## Regenerate TypeScript API types from the contract
	cd web && pnpm gen:api

web-test: ## Web unit tests
	cd web && pnpm test

web-lint: ## Web typecheck + lint
	cd web && pnpm typecheck && pnpm lint

web-build: ## Production build of the web portal (no deploy)
	cd web && pnpm build

# ------------------------------------------------------------------ mobile
.PHONY: mobile mobile-test mobile-analyze gen-mobile-api
mobile: ## Run the Flutter app on the Android emulator (reaches the host API at 10.0.2.2; the app adds /api/v1)
	cd mobile && $(FLUTTER) run --dart-define=API_BASE_URL=http://10.0.2.2:8080

gen-mobile-api: ## Regenerate Dart models from the contract
	cd mobile && dart run tool/gen_api.dart

mobile-test: ## Flutter tests
	cd mobile && $(FLUTTER) test

mobile-analyze: ## Flutter static analysis
	cd mobile && $(FLUTTER) analyze

# --------------------------------------------------------------- aggregate
.PHONY: test check
test: test-backend test-integration web-test mobile-test ## All test suites

check: contract-check docs-check lint test web-lint web-build mobile-analyze ## Everything CI runs
