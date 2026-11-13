package storage

import (
	"bytes"
	"context"
	"errors"
	"fmt"
	"io"
	"net/http"
	"path/filepath"
	"time"

	"github.com/appwrite/sdk-for-go/appwrite"
	"github.com/appwrite/sdk-for-go/client"
	"github.com/appwrite/sdk-for-go/file"
	awstorage "github.com/appwrite/sdk-for-go/storage"

	"montra/backend/internal/platform/breaker"
	"montra/backend/internal/platform/config"
)

// Appwrite is the production storage adapter built on the official Appwrite
// Go SDK v1.0.0 (response format 1.8.0). Objects are created with NO client
// permissions: buckets must have file security enabled and grant nothing to
// end users, so only this server key can read or write (ADR-009). Access for
// users is always mediated by the backend.
//
// Local development never constructs this adapter against a real project;
// its behavior is verified with an httptest double (appwrite_test.go).
type Appwrite struct {
	svc     *awstorage.Storage
	buckets config.BucketNames
	timeout time.Duration
	retries int
	breaker *breaker.Breaker
}

// storageFailure counts only provider unavailability (network, timeouts,
// 429 and 5xx) against the breaker; a missing object or a rejected request
// says nothing about the provider's health.
func storageFailure(err error) bool {
	return breaker.DefaultIsFailure(err) && errors.Is(err, ErrUnavailable)
}

// NewAppwrite builds the adapter from configuration.
func NewAppwrite(cfg config.StorageConfig) (*Appwrite, error) {
	return NewAppwriteWithEndpoint(cfg.AppwriteEndpoint, cfg.AppwriteProjectID, cfg.AppwriteAPIKey, cfg.Buckets, cfg.AppwriteTimeout)
}

// NewAppwriteWithEndpoint allows an explicit endpoint (tests use an
// httptest server; configuration validation requires https in deployments).
func NewAppwriteWithEndpoint(endpoint, project, key string, b config.BucketNames, timeout time.Duration) (*Appwrite, error) {
	if endpoint == "" || project == "" || key == "" {
		return nil, errors.New("appwrite endpoint, project and key are required")
	}
	if timeout <= 0 {
		timeout = 30 * time.Second
	}
	c := appwrite.NewClient(
		appwrite.WithEndpoint(endpoint),
		appwrite.WithProject(project),
		appwrite.WithKey(key),
		appwrite.WithTimeout(timeout),
	)
	return &Appwrite{svc: awstorage.New(c), buckets: b, timeout: timeout, retries: 2,
		breaker: breaker.New("storage.appwrite", breaker.Options{IsFailure: storageFailure})}, nil
}

// Provider implements Store.
func (a *Appwrite) Provider() string { return "appwrite" }

// Bucket implements Store.
func (a *Appwrite) Bucket(ar Area) string { return bucketFor(a.buckets, ar) }

// classify maps SDK errors to storage errors.
func classify(err error) error {
	if err == nil {
		return nil
	}
	var ae *client.AppwriteError
	if errors.As(err, &ae) {
		switch code := ae.GetStatusCode(); {
		case code == http.StatusNotFound:
			return ErrNotFound
		case code == http.StatusTooManyRequests || code >= 500:
			return fmt.Errorf("%w: appwrite status %d", ErrUnavailable, code)
		default:
			return fmt.Errorf("appwrite request rejected (status %d): %s", code, ae.GetMessage())
		}
	}
	return fmt.Errorf("%w: %w", ErrUnavailable, err)
}

func retryable(err error) bool { return errors.Is(err, ErrUnavailable) }

// call runs an SDK call (which has no context support) with a deadline and
// bounded retries for transient failures, through the storage circuit
// breaker: while Appwrite keeps failing, calls fail fast with
// ErrUnavailable (STORAGE_UNAVAILABLE for API callers; jobs retry with
// backoff).
func (a *Appwrite) call(ctx context.Context, fn func() error) error {
	err := a.breaker.Do(ctx, func(ctx context.Context) error { return a.callWithRetries(ctx, fn) })
	if breaker.IsOpen(err) {
		return fmt.Errorf("%w: %w", ErrUnavailable, err)
	}
	return err
}

func (a *Appwrite) callWithRetries(ctx context.Context, fn func() error) error {
	var last error
	for attempt := 0; attempt <= a.retries; attempt++ {
		if attempt > 0 {
			select {
			case <-ctx.Done():
				return ctx.Err()
			case <-time.After(time.Duration(attempt*attempt) * 250 * time.Millisecond):
			}
		}
		done := make(chan error, 1)
		go func() { done <- classify(fn()) }()
		select {
		case <-ctx.Done():
			return fmt.Errorf("%w: %w", ErrUnavailable, ctx.Err())
		case last = <-done:
		}
		if last == nil || !retryable(last) {
			return last
		}
	}
	return last
}

// Put implements Store. The SDK streams the file from disk in 5 MiB chunks
// (resumable via the file ID).
func (a *Appwrite) Put(ctx context.Context, ar Area, key, srcPath, _ string) error {
	b := a.Bucket(ar)
	if b == "" || !ValidKey(key) {
		return ErrInvalidKey
	}
	return a.call(ctx, func() error {
		_, err := a.svc.CreateFile(b, key, file.NewInputFile(srcPath, filepath.Base(key)))
		return err
	})
}

// Open implements Store. The SDK returns the full object in memory; Montra
// upload limits (≤ 20 MiB) bound this.
func (a *Appwrite) Open(ctx context.Context, ar Area, key string) (io.ReadCloser, error) {
	b := a.Bucket(ar)
	if b == "" || !ValidKey(key) {
		return nil, ErrInvalidKey
	}
	var data *[]byte
	err := a.call(ctx, func() error {
		var err error
		data, err = a.svc.GetFileDownload(b, key)
		return err
	})
	if err != nil {
		return nil, err
	}
	if data == nil {
		return nil, ErrNotFound
	}
	return io.NopCloser(bytes.NewReader(*data)), nil
}

// Delete implements Store (idempotent).
func (a *Appwrite) Delete(ctx context.Context, ar Area, key string) error {
	b := a.Bucket(ar)
	if b == "" || !ValidKey(key) {
		return ErrInvalidKey
	}
	err := a.call(ctx, func() error {
		_, err := a.svc.DeleteFile(b, key)
		return err
	})
	if errors.Is(err, ErrNotFound) {
		return nil
	}
	return err
}
