# syntax=docker/dockerfile:1
# One image for the Montra API, worker and migrator (ADR-011). Build from
# the repository root so the migrations directory is included:
#   docker build -f backend/Dockerfile -t montra-backend:<version> --build-arg APP_VERSION=<version> .
# Run the default command (API), or override the command with
# /usr/local/bin/worker, or /usr/local/bin/migrate up -yes (owner-run, see
# docs/DEPLOYMENT.md). Configuration comes only from environment variables
# injected by the host's secret store; no .env files are copied.

FROM golang:1.26.2-bookworm AS build
WORKDIR /src/backend
COPY backend/go.mod backend/go.sum ./
RUN go mod download
COPY backend/ ./
RUN CGO_ENABLED=0 GOOS=linux go build -trimpath -ldflags="-s -w" -o /out/api ./cmd/api \
 && CGO_ENABLED=0 GOOS=linux go build -trimpath -ldflags="-s -w" -o /out/worker ./cmd/worker \
 && CGO_ENABLED=0 GOOS=linux go build -trimpath -ldflags="-s -w" -o /out/migrate ./cmd/migrate

FROM gcr.io/distroless/static-debian12:nonroot
ARG APP_VERSION=0.0.0
ENV APP_VERSION=${APP_VERSION} APP_ENV=production HTTP_ADDR=:8080
WORKDIR /app
COPY --from=build /out/api /out/worker /out/migrate /usr/local/bin/
COPY supabase/migrations /app/supabase/migrations
USER nonroot:nonroot
EXPOSE 8080
CMD ["/usr/local/bin/api"]
