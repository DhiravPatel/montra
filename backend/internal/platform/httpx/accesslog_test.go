package httpx

import (
	"bytes"
	"log/slog"
	"net/http"
	"net/http/httptest"
	"strconv"
	"strings"
	"testing"
)

// The access log names an error's stable codes and field, never its
// message or values.
func TestAccessLogRecordsErrorCodesOnly(t *testing.T) {
	var buf bytes.Buffer
	prev := slog.Default()
	slog.SetDefault(slog.New(slog.NewJSONHandler(&buf, nil)))
	defer slog.SetDefault(prev)

	h := AccessLog(nil)(http.HandlerFunc(func(w http.ResponseWriter, _ *http.Request) {
		w.Header().Set("Content-Type", "application/json")
		w.WriteHeader(http.StatusUnprocessableEntity)
		_, _ = w.Write([]byte(`{"error":{"code":"VALIDATION_ERROR","message":"secret note text",` +
			`"details":[{"field":"body.amount","code":"too_long","message":"Keep it short","params":{"max":"40"}}]}}`))
	}))
	h.ServeHTTP(httptest.NewRecorder(), httptest.NewRequest(http.MethodPost, "/api/v1/transactions", nil))
	line := buf.String()
	for _, want := range []string{`"error_code":"VALIDATION_ERROR"`, `"detail_code":"too_long"`, `"detail_field":"body.amount"`, `"status":422`} {
		if !strings.Contains(line, want) {
			t.Fatalf("log line misses %s: %s", want, line)
		}
	}
	for _, never := range []string{"secret note text", "Keep it short", `"max"`} {
		if strings.Contains(line, never) {
			t.Fatalf("log line leaks %q: %s", never, line)
		}
	}

	// A large validation error (many details) still yields its codes.
	buf.Reset()
	big := AccessLog(nil)(http.HandlerFunc(func(w http.ResponseWriter, _ *http.Request) {
		w.WriteHeader(http.StatusUnprocessableEntity)
		body := `{"error":{"code":"VALIDATION_ERROR","message":"m","details":[`
		for i := 0; i < 200; i++ {
			if i > 0 {
				body += ","
			}
			body += `{"field":"body.items[` + strconv.Itoa(i) + `].amount","code":"required","message":"Enter an amount for this line item please."}`
		}
		_, _ = w.Write([]byte(body + `]}}`))
	}))
	big.ServeHTTP(httptest.NewRecorder(), httptest.NewRequest(http.MethodPost, "/api/v1/receipts", nil))
	if !strings.Contains(buf.String(), `"detail_field":"body.items[0].amount"`) {
		t.Fatalf("large error body lost its codes: %.300s", buf.String())
	}

	buf.Reset()
	ok := AccessLog(nil)(http.HandlerFunc(func(w http.ResponseWriter, _ *http.Request) { _, _ = w.Write([]byte(`{"data":{"note":"x"}}`)) }))
	ok.ServeHTTP(httptest.NewRecorder(), httptest.NewRequest(http.MethodGet, "/api/v1/me", nil))
	if strings.Contains(buf.String(), "error_code") {
		t.Fatalf("success logged an error code: %s", buf.String())
	}
}
