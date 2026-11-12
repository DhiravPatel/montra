package storage

import (
	"context"
	"encoding/json"
	"errors"
	"io"
	"net/http"
	"net/http/httptest"
	"os"
	"path/filepath"
	"strings"
	"sync"
	"testing"
	"time"

	"montra/backend/internal/platform/config"
)

// fakeAppwrite is a deterministic test double emulating the documented
// Appwrite Storage REST endpoints used by the SDK. It never contacts Appwrite.
type fakeAppwrite struct {
	mu        sync.Mutex
	objects   map[string][]byte // bucket/id → content
	failNext  int               // number of 503s to return before succeeding
	badKey    bool
	seenHdrs  http.Header
	deletes   int
	uploadReq int
}

func (f *fakeAppwrite) ServeHTTP(w http.ResponseWriter, r *http.Request) {
	f.mu.Lock()
	defer f.mu.Unlock()
	f.seenHdrs = r.Header.Clone()
	writeErr := func(code int, typ string) {
		w.Header().Set("Content-Type", "application/json")
		w.WriteHeader(code)
		_ = json.NewEncoder(w).Encode(map[string]any{"message": typ, "code": code, "type": typ})
	}
	if r.Header.Get("X-Appwrite-Project") != "proj-test" {
		writeErr(http.StatusBadRequest, "project_missing")
		return
	}
	if f.badKey || r.Header.Get("X-Appwrite-Key") != "server-key-test" {
		writeErr(http.StatusUnauthorized, "general_unauthorized_scope")
		return
	}
	if f.failNext > 0 {
		f.failNext--
		writeErr(http.StatusServiceUnavailable, "general_server_error")
		return
	}
	parts := strings.Split(strings.TrimPrefix(r.URL.Path, "/v1/storage/buckets/"), "/")
	switch {
	case r.Method == http.MethodGet && len(parts) == 3 && parts[1] == "files": // resumable-upload probe / metadata
		if _, ok := f.objects[parts[0]+"/"+parts[2]]; !ok {
			writeErr(http.StatusNotFound, "storage_file_not_found")
			return
		}
		w.Header().Set("Content-Type", "application/json")
		_ = json.NewEncoder(w).Encode(map[string]any{"$id": parts[2], "chunksUploaded": 1, "chunksTotal": 1})
	case r.Method == http.MethodPost && len(parts) == 2 && parts[1] == "files":
		f.uploadReq++
		if err := r.ParseMultipartForm(32 << 20); err != nil {
			writeErr(http.StatusBadRequest, "invalid_multipart")
			return
		}
		id := r.FormValue("fileId")
		fh, _, err := r.FormFile("file")
		if err != nil {
			writeErr(http.StatusBadRequest, "file_missing")
			return
		}
		data, _ := io.ReadAll(fh)
		f.objects[parts[0]+"/"+id] = data
		w.Header().Set("Content-Type", "application/json")
		w.WriteHeader(http.StatusCreated)
		_ = json.NewEncoder(w).Encode(map[string]any{"$id": id, "bucketId": parts[0], "name": id, "sizeOriginal": len(data),
			"chunksTotal": 1, "chunksUploaded": 1, "$permissions": []string{}})
	case r.Method == http.MethodGet && len(parts) == 4 && parts[3] == "download":
		data, ok := f.objects[parts[0]+"/"+parts[2]]
		if !ok {
			writeErr(http.StatusNotFound, "storage_file_not_found")
			return
		}
		w.Header().Set("Content-Type", "application/octet-stream")
		_, _ = w.Write(data)
	case r.Method == http.MethodDelete && len(parts) == 3:
		f.deletes++
		if _, ok := f.objects[parts[0]+"/"+parts[2]]; !ok {
			writeErr(http.StatusNotFound, "storage_file_not_found")
			return
		}
		delete(f.objects, parts[0]+"/"+parts[2])
		w.WriteHeader(http.StatusNoContent)
	default:
		writeErr(http.StatusNotFound, "route_not_found")
	}
}

func newFake(t *testing.T) (*fakeAppwrite, *Appwrite) {
	t.Helper()
	fake := &fakeAppwrite{objects: map[string][]byte{}}
	srv := httptest.NewServer(fake)
	t.Cleanup(srv.Close)
	a, err := NewAppwriteWithEndpoint(srv.URL+"/v1", "proj-test", "server-key-test",
		config.BucketNames{PrivateUser: "private-user-docs", Group: "group-docs", PublicMedia: "public-media", Temp: "temp-processing", Exports: "exports"},
		5*time.Second)
	if err != nil {
		t.Fatal(err)
	}
	return fake, a
}

func writeTemp(t *testing.T, content string) string {
	t.Helper()
	p := filepath.Join(t.TempDir(), "obj")
	if err := os.WriteFile(p, []byte(content), 0o600); err != nil {
		t.Fatal(err)
	}
	return p
}

func TestAppwriteRoundTrip(t *testing.T) {
	fake, a := newFake(t)
	ctx := context.Background()
	key := NewKey()
	if err := a.Put(ctx, AreaPrivate, key, writeTemp(t, "%PDF-1.7 synthetic receipt"), "application/pdf"); err != nil {
		t.Fatalf("put: %v", err)
	}
	if fake.seenHdrs.Get("X-Appwrite-Key") != "server-key-test" || fake.seenHdrs.Get("X-Appwrite-Response-Format") == "" {
		t.Fatalf("missing server headers: %v", fake.seenHdrs)
	}
	if _, ok := fake.objects["private-user-docs/"+key]; !ok {
		t.Fatal("object not stored in the private bucket")
	}
	rc, err := a.Open(ctx, AreaPrivate, key)
	if err != nil {
		t.Fatalf("open: %v", err)
	}
	b, _ := io.ReadAll(rc)
	_ = rc.Close()
	if string(b) != "%PDF-1.7 synthetic receipt" {
		t.Fatalf("content mismatch: %q", b)
	}
	if err := a.Delete(ctx, AreaPrivate, key); err != nil {
		t.Fatalf("delete: %v", err)
	}
	if err := a.Delete(ctx, AreaPrivate, key); err != nil {
		t.Fatalf("delete must be idempotent: %v", err)
	}
	if _, err := a.Open(ctx, AreaPrivate, key); !errors.Is(err, ErrNotFound) {
		t.Fatalf("expected ErrNotFound, got %v", err)
	}
}

func TestAppwriteRetriesTransientFailures(t *testing.T) {
	fake, a := newFake(t)
	fake.failNext = 2 // two 503s then success
	key := NewKey()
	if err := a.Put(context.Background(), AreaExports, key, writeTemp(t, "{}"), "application/json"); err != nil {
		t.Fatalf("expected retry to succeed: %v", err)
	}
	fake.failNext = 10
	if err := a.Put(context.Background(), AreaExports, NewKey(), writeTemp(t, "{}"), "application/json"); !errors.Is(err, ErrUnavailable) {
		t.Fatalf("expected ErrUnavailable after retries, got %v", err)
	}
}

func TestAppwriteAuthErrorsAreNotRetried(t *testing.T) {
	fake, a := newFake(t)
	fake.badKey = true
	err := a.Put(context.Background(), AreaPrivate, NewKey(), writeTemp(t, "x"), "text/plain")
	if err == nil || errors.Is(err, ErrUnavailable) {
		t.Fatalf("auth failure must be a non-retryable rejection, got %v", err)
	}
}

func TestAppwriteRejectsInvalidKeys(t *testing.T) {
	_, a := newFake(t)
	for _, k := range []string{"../etc/passwd", "", strings.Repeat("a", 40), ".hidden", "a/b"} {
		if err := a.Put(context.Background(), AreaPrivate, k, writeTemp(t, "x"), "text/plain"); !errors.Is(err, ErrInvalidKey) {
			t.Errorf("key %q accepted", k)
		}
	}
}

func TestLocalDiskRejectsTraversalAndRoundTrips(t *testing.T) {
	l, err := NewLocalDisk(t.TempDir(), config.BucketNames{PrivateUser: "private-user-docs", Exports: "exports"})
	if err != nil {
		t.Fatal(err)
	}
	ctx := context.Background()
	if err := l.Put(ctx, AreaPrivate, "../../escape", writeTemp(t, "x"), ""); !errors.Is(err, ErrInvalidKey) {
		t.Fatalf("traversal key accepted: %v", err)
	}
	k := NewKey()
	if err := l.Put(ctx, AreaPrivate, k, writeTemp(t, "hello"), ""); err != nil {
		t.Fatal(err)
	}
	rc, err := l.Open(ctx, AreaPrivate, k)
	if err != nil {
		t.Fatal(err)
	}
	b, _ := io.ReadAll(rc)
	_ = rc.Close()
	if string(b) != "hello" {
		t.Fatal("content mismatch")
	}
	if err := l.Delete(ctx, AreaPrivate, k); err != nil {
		t.Fatal(err)
	}
	if _, err := l.Open(ctx, AreaPrivate, k); !errors.Is(err, ErrNotFound) {
		t.Fatalf("expected not found, got %v", err)
	}
}

func TestLocalDiskRefusedOutsideDevelopment(t *testing.T) {
	if _, err := New(config.StorageConfig{Provider: config.StorageLocalDisk, LocalDir: t.TempDir()}, config.EnvProduction); err == nil {
		t.Fatal("local_disk must be refused in production")
	}
}
