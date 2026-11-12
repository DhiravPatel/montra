// Command openapi exports the generated OpenAPI 3.1 contract (ADR-005).
//
//	openapi -out ../contracts/openapi/montra.v1.json   # write
//	openapi -check -out ../contracts/openapi/montra.v1.json   # CI drift check
package main

import (
	"bytes"
	"encoding/base64"
	"encoding/json"
	"flag"
	"fmt"
	"os"
	"path/filepath"

	"montra/backend/internal/app"
	"montra/backend/internal/platform/config"
)

func main() {
	out := flag.String("out", "../contracts/openapi/montra.v1.json", "output file")
	check := flag.Bool("check", false, "fail if the committed contract differs from the generated one")
	flag.Parse()

	key := base64.StdEncoding.EncodeToString(bytes.Repeat([]byte{7}, 32))
	cfg, err := config.LoadFrom(func(k string) (string, bool) {
		switch k {
		case "APP_ENV":
			return "test", true
		case "DATABASE_URL":
			return "postgres://contract-generation-only/none", true
		case "DATA_ENCRYPTION_KEYS":
			return "contract:" + key, true
		case "URL_SIGNING_KEY":
			return key, true
		case "EMAIL_PROVIDER":
			return "dev_mailbox", true
		case "STORAGE_PROVIDER":
			return "disabled", true
		}
		return "", false
	})
	if err != nil {
		fail(err)
	}
	deps := app.Deps{Cfg: cfg}
	svcs, err := app.NewServices(deps)
	if err != nil {
		fail(err)
	}
	_, api := app.NewRouter(deps, svcs)
	spec, err := json.MarshalIndent(api.OpenAPI(), "", "  ")
	if err != nil {
		fail(err)
	}
	spec = append(spec, '\n')
	if *check {
		current, err := os.ReadFile(*out)
		if err != nil {
			fail(fmt.Errorf("read committed contract: %w", err))
		}
		if !bytes.Equal(current, spec) {
			fail(fmt.Errorf("contract drift: %s is out of date; run `make contract`", *out))
		}
		fmt.Println("contract up to date")
		return
	}
	if err := os.MkdirAll(filepath.Dir(*out), 0o750); err != nil {
		fail(err)
	}
	if err := os.WriteFile(*out, spec, 0o600); err != nil {
		fail(err)
	}
	fmt.Printf("wrote %s (%d bytes)\n", *out, len(spec))
}

func fail(err error) {
	fmt.Fprintln(os.Stderr, "error:", err)
	os.Exit(1)
}
