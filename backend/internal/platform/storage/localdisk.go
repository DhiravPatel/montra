package storage

import (
	"context"
	"errors"
	"fmt"
	"io"
	"io/fs"
	"os"
	"path/filepath"

	"montra/backend/internal/platform/config"
)

// LocalDisk stores objects under a directory. DEVELOPMENT ONLY — it is not
// Appwrite and is reported as "local_disk" everywhere.
type LocalDisk struct {
	root    string
	buckets config.BucketNames
}

// NewLocalDisk creates the adapter.
func NewLocalDisk(root string, b config.BucketNames) (*LocalDisk, error) {
	abs, err := filepath.Abs(root)
	if err != nil {
		return nil, err
	}
	if err := os.MkdirAll(abs, 0o700); err != nil {
		return nil, err
	}
	return &LocalDisk{root: abs, buckets: b}, nil
}

// Provider implements Store.
func (l *LocalDisk) Provider() string { return "local_disk" }

// Bucket implements Store.
func (l *LocalDisk) Bucket(a Area) string { return bucketFor(l.buckets, a) }

func (l *LocalDisk) path(a Area, key string) (string, error) {
	b := l.Bucket(a)
	if b == "" || !ValidKey(key) || !ValidKey(b) {
		return "", ErrInvalidKey
	}
	p := filepath.Join(l.root, b, key)
	if filepath.Dir(filepath.Dir(p)) != l.root { // defense in depth against traversal
		return "", ErrInvalidKey
	}
	return p, nil
}

// Put implements Store (atomic write via temp file + rename).
func (l *LocalDisk) Put(_ context.Context, a Area, key, srcPath, _ string) error {
	dst, err := l.path(a, key)
	if err != nil {
		return err
	}
	if err := os.MkdirAll(filepath.Dir(dst), 0o700); err != nil {
		return err
	}
	src, err := os.Open(srcPath) //nolint:gosec // server-created temp file
	if err != nil {
		return err
	}
	defer func() { _ = src.Close() }()
	tmp, err := os.CreateTemp(filepath.Dir(dst), ".upload-*")
	if err != nil {
		return err
	}
	if _, err := io.Copy(tmp, src); err != nil {
		_ = tmp.Close()
		_ = os.Remove(tmp.Name())
		return err
	}
	if err := tmp.Close(); err != nil {
		_ = os.Remove(tmp.Name())
		return err
	}
	if err := os.Chmod(tmp.Name(), 0o600); err != nil {
		return err
	}
	return os.Rename(tmp.Name(), dst)
}

// Open implements Store.
func (l *LocalDisk) Open(_ context.Context, a Area, key string) (io.ReadCloser, error) {
	p, err := l.path(a, key)
	if err != nil {
		return nil, err
	}
	f, err := os.Open(p) //nolint:gosec // path built from validated server-side key
	if errors.Is(err, fs.ErrNotExist) {
		return nil, ErrNotFound
	}
	if err != nil {
		return nil, fmt.Errorf("%w: %w", ErrUnavailable, err)
	}
	return f, nil
}

// Delete implements Store.
func (l *LocalDisk) Delete(_ context.Context, a Area, key string) error {
	p, err := l.path(a, key)
	if err != nil {
		return err
	}
	if err := os.Remove(p); err != nil && !errors.Is(err, fs.ErrNotExist) {
		return fmt.Errorf("%w: %w", ErrUnavailable, err)
	}
	return nil
}
