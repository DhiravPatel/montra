# Montra API contract (`contracts/`)

[`openapi/montra.v1.json`](openapi/montra.v1.json) is the OpenAPI 3.1
description of the Montra HTTP API (`/api/v1`). The web portal and the
Flutter app depend on this file, never on the Go code (ADR-005,
[`docs/API.md`](../docs/API.md)). Today it describes 424 operations on 334
paths and 598 schemas.

It covers:

- every operation, with an `operationId` such as `budgets-list`, a tag and
  its security (bearer token or session cookie);
- request and response schemas, including money as exact decimal strings
  and the response envelope;
- the error object, whose `code` is a closed enum, plus the error
  statuses each operation documents;
- client headers such as `Idempotency-Key` and the CSRF header.

The domain error codes (`error.details[0].code`) are listed in
[`docs/API.md`](../docs/API.md), generated from the Go sources by
`make docs`.

## How it is produced

The file is **generated, never edited by hand**. Huma builds the document
from the operations each feature registers in `backend/internal/<feature>/http.go`.
`backend/cmd/openapi` wires the application with throwaway configuration
(no database or provider is contacted) and writes the result as indented
JSON:

```sh
make contract          # cd backend && go run ./cmd/openapi -out ../contracts/openapi/montra.v1.json
```

Commit the regenerated file in the same change as the Go handlers.

The clients generate their types from it:

```sh
make gen-web-api       # web: openapi-typescript -> web/src/shared/api/schema.d.ts
make gen-mobile-api    # mobile: dart run tool/gen_api.dart -> mobile/lib/core/api/generated/models.dart
```

`mobile/tool/gen_api.dart` fails loudly on any schema construct it does
not support, so a contract change cannot silently produce wrong models.

## Drift checks

Each check fails the build when the contract and code disagree:

| Check | Where | Fails when |
|---|---|---|
| `go run ./cmd/openapi -check` (`make contract-check`) | CI `backend` job, `make check` | the committed contract differs from what the Go handlers generate |
| `pnpm gen:api && git diff --exit-code src/shared/api` | CI `web` job | `schema.d.ts` is stale against the contract |
| `dart run tool/gen_api.dart && git diff --exit-code lib/core/api/generated` | CI `mobile` job (`--check` locally) | the Dart models are stale against the contract |
| `mobile/test/core/api/endpoints_contract_test.dart` | `flutter test` | an endpoint the app calls is missing or has a different method or auth requirement, a declared client header is not sent, or an error status the app handles is undocumented |
| `mobile/test/core/api/generated_models_test.dart` | `flutter test` | the generated models no longer match the contract |
| `backend/tests/api/contract_test.go`, `client_contract_test.go` | `make test-integration`, CI | behaviors the clients rely on regress (auth flows, retired currencies, the contract fixes reported by the clients) |
| `scripts/docs/gen_knowledge_graph.py --check` | `make docs-check`, CI | the knowledge graph (which reads the contract's operations) is stale |

The CI jobs for web and mobile run whenever `contracts/**` changes.

## Changing the API

1. Change the handler or DTO in Go. Keep changes additive (new optional
   fields and new operations). A breaking change needs a new versioned path
   and a decision record ([`docs/DECISIONS.md`](../docs/DECISIONS.md)).
2. Run `make contract`, `make gen-web-api`, `make gen-mobile-api` and
   `make docs`.
3. Update the clients and their tests in the same change, and commit the
   contract with them.
