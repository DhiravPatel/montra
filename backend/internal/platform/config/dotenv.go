package config

import (
	"bufio"
	"os"
	"strings"
)

// LoadDotEnv loads KEY=VALUE pairs from the first existing file in paths into
// the process environment without overriding variables that are already
// set. It is a local-development convenience; hosted environments inject
// configuration directly. Returns the file that was loaded, if any.
func LoadDotEnv(paths ...string) string {
	for _, p := range paths {
		f, err := os.Open(p) //nolint:gosec // local development env file path chosen by the operator
		if err != nil {
			continue
		}
		sc := bufio.NewScanner(f)
		for sc.Scan() {
			line := strings.TrimSpace(sc.Text())
			if line == "" || strings.HasPrefix(line, "#") {
				continue
			}
			line = strings.TrimPrefix(line, "export ")
			k, v, ok := strings.Cut(line, "=")
			if !ok {
				continue
			}
			k = strings.TrimSpace(k)
			v = strings.TrimSpace(v)
			if len(v) >= 2 && ((v[0] == '"' && v[len(v)-1] == '"') || (v[0] == '\'' && v[len(v)-1] == '\'')) {
				v = v[1 : len(v)-1]
			}
			if _, exists := os.LookupEnv(k); !exists {
				_ = os.Setenv(k, v)
			}
		}
		_ = f.Close()
		return p
	}
	return ""
}
