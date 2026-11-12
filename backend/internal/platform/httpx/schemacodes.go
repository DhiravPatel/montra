package httpx

import (
	"regexp"
	"strings"

	"montra/backend/internal/platform/apperr"
)

// schemaCodes give request-schema failures (Huma's English messages such
// as "expected length >= 3") the stable detail codes the services use, so
// clients can localize them; the message is kept as the fallback.
var schemaCodes = []struct {
	re    *regexp.Regexp
	code  string
	param string // params key for the first submatch
}{
	{regexp.MustCompile(`^expected length >= (\d+)$`), "too_short", "min"},
	{regexp.MustCompile(`^expected length <= (\d+)$`), "too_long", "max"},
	{regexp.MustCompile(`^expected array length >= (\d+)$`), "too_few", "min"},
	{regexp.MustCompile(`^expected array length <= (\d+)$`), "too_many", "max"},
	{regexp.MustCompile(`^expected number >=? (\S+)$`), "too_small", "min"},
	{regexp.MustCompile(`^expected number <=? (\S+)$`), "too_large", "max"},
	{regexp.MustCompile(`^expected required property (\S+) to be present$`), "required", "property"},
	{regexp.MustCompile(`^expected value to be one of "(.*)"$`), "invalid_choice", "allowed"},
	{regexp.MustCompile(`^expected string to (?:match pattern|be) `), "invalid_format", ""},
	{regexp.MustCompile(`^expected (?:boolean|number|integer|string|array|object)$`), "invalid_type", ""},
	{regexp.MustCompile(`^unexpected property$`), "unexpected_property", ""},
}

// schemaDetail converts one schema validation problem into a detail.
func schemaDetail(field, msg string) apperr.Detail {
	d := apperr.Detail{Field: field, Message: msg}
	for _, c := range schemaCodes {
		m := c.re.FindStringSubmatch(msg)
		if m == nil {
			continue
		}
		d.Code = c.code
		if c.param != "" && len(m) > 1 {
			d.Params = map[string]string{c.param: strings.TrimSpace(m[1])}
		}
		break
	}
	return d
}
