// Package storage abstracts object storage (ADR-009/010). Production uses
// Appwrite Storage; development may use the local-disk adapter, which the
// configuration refuses outside development/test. Object keys are generated
// server-side; user input never influences storage paths.
package storage

import (
	"context"
	"errors"
	"fmt"
	"io"
	"regexp"
	"strings"

	"github.com/google/uuid"

	"montra/backend/internal/platform/config"
)

// Area is a logical storage area (spec §4.9, §10).
type Area string

// Storage areas.
const (
	AreaPrivate     Area = "private"
	AreaGroup       Area = "group"
	AreaPublicMedia Area = "public_media"
	AreaTemp        Area = "temp"
	AreaExports     Area = "exports"
)

// Errors.
var (
	ErrNotFound    = errors.New("object not found")
	ErrUnavailable = errors.New("storage provider unavailable")
	ErrDisabled    = errors.New("storage is not configured")
	ErrInvalidKey  = errors.New("invalid object key")
)

var keyRe = regexp.MustCompile(`^[a-zA-Z0-9][a-zA-Z0-9._-]{0,35}$`)

// NewKey generates an opaque object key (Appwrite-compatible file ID).
func NewKey() string { return strings.ReplaceAll(uuid.NewString(), "-", "") }

// ValidKey reports whether a key is safe for every provider.
func ValidKey(k string) bool { return keyRe.MatchString(k) }

// Store is implemented by each provider adapter.
type Store interface {
	// Provider is "appwrite", "local_disk" or "disabled".
	Provider() string
	// Bucket returns the bucket/container name for an area.
	Bucket(a Area) string
	// Put stores the content of the file at srcPath (already validated).
	Put(ctx context.Context, a Area, key, srcPath, contentType string) error
	// Open returns a reader for the object.
	Open(ctx context.Context, a Area, key string) (io.ReadCloser, error)
	// Delete removes the object; deleting a missing object is not an error.
	Delete(ctx context.Context, a Area, key string) error
}

// New builds the configured store.
func New(cfg config.StorageConfig, env string) (Store, error) {
	switch cfg.Provider {
	case config.StorageAppwrite:
		return NewAppwrite(cfg)
	case config.StorageLocalDisk:
		if env != config.EnvDevelopment && env != config.EnvTest {
			return nil, fmt.Errorf("local_disk storage is only allowed in development/test")
		}
		return NewLocalDisk(cfg.LocalDir, cfg.Buckets)
	default:
		return Disabled{}, nil
	}
}

// Disabled rejects all operations.
type Disabled struct{}

// Provider implements Store.
func (Disabled) Provider() string { return "disabled" }

// Bucket implements Store.
func (Disabled) Bucket(Area) string { return "" }

// Put implements Store.
func (Disabled) Put(context.Context, Area, string, string, string) error { return ErrDisabled }

// Open implements Store.
func (Disabled) Open(context.Context, Area, string) (io.ReadCloser, error) { return nil, ErrDisabled }

// Delete implements Store.
func (Disabled) Delete(context.Context, Area, string) error { return ErrDisabled }

func bucketFor(b config.BucketNames, a Area) string {
	switch a {
	case AreaPrivate:
		return b.PrivateUser
	case AreaGroup:
		return b.Group
	case AreaPublicMedia:
		return b.PublicMedia
	case AreaTemp:
		return b.Temp
	case AreaExports:
		return b.Exports
	}
	return ""
}
