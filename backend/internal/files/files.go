// Package files implements the upload/download workflow (spec §10, §20B.10):
// upload intent → backend-proxied upload with content validation → complete
// → per-request authorized, short-lived signed downloads → durable deletion.
// Clients never receive storage credentials or permanent links.
package files

import (
	"context"
	"crypto/sha256"
	"encoding/hex"
	"errors"
	"fmt"
	"io"
	"log/slog"
	"net/http"
	"os"
	"slices"
	"strconv"
	"strings"
	"time"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"

	"montra/backend/internal/platform/apperr"
	"montra/backend/internal/platform/audit"
	"montra/backend/internal/platform/config"
	"montra/backend/internal/platform/crypto"
	"montra/backend/internal/platform/database"
	"montra/backend/internal/platform/identity"
	"montra/backend/internal/platform/jobs"
	"montra/backend/internal/platform/observability"
	"montra/backend/internal/platform/outbox"
	"montra/backend/internal/platform/storage"
)

// Job types.
const (
	JobDelete  = "files.delete"
	JobCleanup = "files.cleanup"
)

// Policy constrains one upload purpose.
type Policy struct {
	Area     storage.Area
	Kinds    []Kind
	MaxBytes int64
	Group    bool // requires group_id and group membership
}

var images = []Kind{KindJPEG, KindPNG, KindWEBP, KindHEIC}

// Policies per purpose (system-generated purposes are not uploadable).
var Policies = map[string]Policy{
	"receipt":                {Area: storage.AreaPrivate, Kinds: append(slices.Clone(images), KindPDF), MaxBytes: 15 << 20},
	"bill_document":          {Area: storage.AreaPrivate, Kinds: append(slices.Clone(images), KindPDF), MaxBytes: 15 << 20},
	"transaction_attachment": {Area: storage.AreaPrivate, Kinds: append(slices.Clone(images), KindPDF), MaxBytes: 15 << 20},
	"goal_attachment":        {Area: storage.AreaPrivate, Kinds: append(slices.Clone(images), KindPDF), MaxBytes: 15 << 20},
	"subscription_invoice":   {Area: storage.AreaPrivate, Kinds: []Kind{KindPDF, KindJPEG, KindPNG}, MaxBytes: 15 << 20},
	"statement_import":       {Area: storage.AreaPrivate, Kinds: []Kind{KindCSV, KindXLSX, KindOFX, KindPDF}, MaxBytes: 10 << 20},
	"avatar":                 {Area: storage.AreaPrivate, Kinds: []Kind{KindJPEG, KindPNG, KindWEBP}, MaxBytes: 5 << 20},
	"group_attachment":       {Area: storage.AreaGroup, Kinds: append(slices.Clone(images), KindPDF), MaxBytes: 15 << 20, Group: true},
	"trip_document":          {Area: storage.AreaGroup, Kinds: append(slices.Clone(images), KindPDF), MaxBytes: 15 << 20, Group: true},
}

// Service implements file workflows.
type Service struct {
	DB      *database.DB
	Store   storage.Store
	Cfg     *config.Config
	Signer  *crypto.Signer
	Metrics *observability.Metrics
	TmpDir  string
	Now     func() time.Time
}

// FileDTO is file metadata returned to clients.
type FileDTO struct {
	ID               uuid.UUID  `json:"id"`
	Purpose          string     `json:"purpose"`
	Status           string     `json:"status" enum:"pending_upload,uploaded,processing,ready,rejected,quarantined,deleting,deleted"`
	OriginalFilename *string    `json:"original_filename,omitempty"`
	ContentType      *string    `json:"content_type,omitempty" doc:"Detected from file content"`
	SizeBytes        *int64     `json:"size_bytes,omitempty"`
	ChecksumSHA256   *string    `json:"checksum_sha256,omitempty"`
	GroupID          *uuid.UUID `json:"group_id,omitempty"`
	ImageWidth       *int32     `json:"image_width,omitempty"`
	ImageHeight      *int32     `json:"image_height,omitempty"`
	RejectionReason  *string    `json:"rejection_reason,omitempty"`
	CreatedAt        time.Time  `json:"created_at"`
}

// Row is the internal file row.
type Row struct {
	FileDTO
	OwnerID   uuid.UUID
	Area      string
	Provider  string
	Bucket    string
	ObjectKey string
	Expected  *string
	ExpSize   *int64
	TokenHash []byte
	TokenExp  *time.Time
}

const fileCols = `id, purpose, status, original_filename, detected_mime, size_bytes, checksum_sha256, group_id, image_width,
	image_height, rejection_reason, created_at, owner_user_id, storage_area, provider, bucket, object_key,
	expected_checksum_sha256, expected_size_bytes, upload_token_hash, upload_expires_at`

func scanRow(r pgx.Row) (*Row, error) {
	var f Row
	err := r.Scan(&f.ID, &f.Purpose, &f.Status, &f.OriginalFilename, &f.ContentType, &f.SizeBytes, &f.ChecksumSHA256, &f.GroupID,
		&f.ImageWidth, &f.ImageHeight, &f.RejectionReason, &f.CreatedAt, &f.OwnerID, &f.Area, &f.Provider, &f.Bucket, &f.ObjectKey,
		&f.Expected, &f.ExpSize, &f.TokenHash, &f.TokenExp)
	if err != nil {
		return nil, err
	}
	return &f, nil
}

// Get loads a file visible to the current RLS user (owner, group member for
// group files, or authorized profile viewer for avatars).
func Get(ctx context.Context, tx pgx.Tx, id uuid.UUID) (*Row, error) {
	f, err := scanRow(tx.QueryRow(ctx, `select `+fileCols+` from files where id = $1 and status <> 'deleted'`, id))
	if database.IsNoRows(err) {
		return nil, apperr.NotFound("file")
	}
	return f, database.MapError(err)
}

// UploadIntentInput requests an upload.
type UploadIntentInput struct {
	Purpose        string     `json:"purpose" enum:"receipt,bill_document,transaction_attachment,goal_attachment,subscription_invoice,statement_import,avatar,group_attachment,trip_document"`
	Filename       string     `json:"filename" minLength:"1" maxLength:"255"`
	ContentType    string     `json:"content_type" maxLength:"127" doc:"Declared type (verified server-side from content)"`
	SizeBytes      int64      `json:"size_bytes" minimum:"1"`
	ChecksumSHA256 string     `json:"checksum_sha256,omitempty" pattern:"^[0-9a-f]{64}$"`
	GroupID        *uuid.UUID `json:"group_id,omitempty"`
}

// UploadIntent tells the client how to upload.
type UploadIntent struct {
	File      FileDTO           `json:"file"`
	UploadURL string            `json:"upload_url"`
	Method    string            `json:"method" enum:"PUT"`
	Headers   map[string]string `json:"headers"`
	ExpiresAt time.Time         `json:"expires_at"`
	MaxBytes  int64             `json:"max_bytes"`
}

// CreateIntent authorizes and records an upload.
func (s *Service) CreateIntent(ctx context.Context, in UploadIntentInput) (*UploadIntent, error) {
	if s.Store.Provider() == "disabled" {
		return nil, apperr.Unavailable(apperr.CodeStorageUnavailable, "File storage is not configured in this environment.")
	}
	uid, err := identity.UserID(ctx)
	if err != nil {
		return nil, err
	}
	pol, ok := Policies[in.Purpose]
	if !ok {
		return nil, apperr.FieldError("body.purpose", "Unsupported upload purpose.")
	}
	maxBytes := min(pol.MaxBytes, s.Cfg.Storage.MaxUploadBytes)
	if in.SizeBytes > maxBytes {
		return nil, apperr.New(apperr.CodePayloadTooLarge, http.StatusRequestEntityTooLarge,
			fmt.Sprintf("Files for this purpose must be %d MB or smaller.", maxBytes>>20))
	}
	if pol.Group && in.GroupID == nil {
		return nil, apperr.FieldError("body.group_id", "A group is required for this upload.")
	}
	if !pol.Group && in.GroupID != nil {
		return nil, apperr.FieldError("body.group_id", "This upload purpose cannot belong to a group.")
	}
	name := SafeFilename(in.Filename)
	ext := strings.ToLower(strings.TrimPrefix(extOf(name), "."))
	if !allowedExt(pol, ext) {
		return nil, apperr.New(apperr.CodeUnsupportedMedia, http.StatusUnsupportedMediaType, "This file type is not accepted for this purpose.")
	}
	token := crypto.MustRandomToken(32)
	exp := s.now().Add(15 * time.Minute)
	var dto FileDTO
	err = s.DB.WithUserTx(ctx, uid, func(tx pgx.Tx) error {
		if q := s.Cfg.Storage.UserQuotaBytes; q > 0 {
			used, err := UsedBytes(ctx, tx, uid)
			if err != nil {
				return err
			}
			if used+in.SizeBytes > q {
				return apperr.Rule("storage_quota_exceeded", fmt.Sprintf("This upload would exceed your %d MB storage allowance. Delete files you no longer need first.", q>>20),
					map[string]string{"used_bytes": strconv.FormatInt(used, 10), "quota_bytes": strconv.FormatInt(q, 10)})
			}
		}
		if pol.Group {
			var member bool
			if err := tx.QueryRow(ctx, `select montra.is_group_member($1)`, *in.GroupID).Scan(&member); err != nil {
				return err
			}
			if !member {
				return apperr.NotFound("group")
			}
		}
		var checksum *string
		if in.ChecksumSHA256 != "" {
			checksum = &in.ChecksumSHA256
		}
		var declared *string
		if ct := strings.TrimSpace(in.ContentType); ct != "" {
			declared = &ct
		}
		f, err := scanRow(tx.QueryRow(ctx, `insert into files (owner_user_id, group_id, storage_area, provider, bucket, object_key, purpose,
			original_filename, declared_mime, extension, expected_size_bytes, expected_checksum_sha256, upload_token_hash, upload_expires_at,
			retention_until)
			values ($1,$2,$3,$4,$5,$6,$7,$8,$9,nullif($10,''),$11,$12,$13,$14, null)
			returning `+fileCols, uid, in.GroupID, string(pol.Area), s.Store.Provider(), s.Store.Bucket(pol.Area), storage.NewKey(),
			in.Purpose, name, declared, ext, in.SizeBytes, checksum, crypto.HashToken(token), exp))
		if err != nil {
			return err
		}
		dto = f.FileDTO
		return nil
	})
	if err != nil {
		return nil, database.MapError(err)
	}
	return &UploadIntent{File: dto, Method: http.MethodPut, ExpiresAt: exp, MaxBytes: maxBytes,
		UploadURL: strings.TrimRight(s.Cfg.HTTP.PublicBaseURL, "/") + "/api/v1/files/" + dto.ID.String() + "/content",
		Headers:   map[string]string{"X-Upload-Token": token, "Content-Type": "application/octet-stream"}}, nil
}

func extOf(name string) string {
	if i := strings.LastIndex(name, "."); i >= 0 {
		return name[i:]
	}
	return ""
}

func allowedExt(p Policy, ext string) bool {
	aliases := map[string]string{"jpeg": "jpg", "heif": "heic", "qfx": "ofx", "txt": "csv"}
	if a, ok := aliases[ext]; ok {
		ext = a
	}
	for _, k := range p.Kinds {
		if k.Ext == ext {
			return true
		}
	}
	return false
}

func (s *Service) now() time.Time {
	if s.Now != nil {
		return s.Now()
	}
	return time.Now()
}

// UploadContent receives the bytes for a pending upload, validates them and
// writes them to storage.
func (s *Service) UploadContent(ctx context.Context, id uuid.UUID, token, checksumHeader string, body []byte) (*FileDTO, error) {
	uid, err := identity.UserID(ctx)
	if err != nil {
		return nil, err
	}
	var f *Row
	err = s.DB.WithUserReadTx(ctx, uid, func(tx pgx.Tx) error {
		var err error
		f, err = Get(ctx, tx, id)
		return err
	})
	if err != nil {
		return nil, err
	}
	if f.OwnerID != uid {
		return nil, apperr.NotFound("file")
	}
	if f.Status != "pending_upload" || f.TokenHash == nil || f.TokenExp == nil || f.TokenExp.Before(s.now()) ||
		!crypto.ConstantTimeEqual(hex.EncodeToString(f.TokenHash), hex.EncodeToString(crypto.HashToken(token))) {
		return nil, apperr.New(apperr.CodeGone, http.StatusGone, "This upload link is invalid or has expired. Start a new upload.")
	}
	pol := Policies[f.Purpose]
	if int64(len(body)) == 0 {
		return nil, apperr.FieldError("body", "The file is empty.")
	}
	if int64(len(body)) > pol.MaxBytes {
		return nil, apperr.New(apperr.CodePayloadTooLarge, http.StatusRequestEntityTooLarge, "The file is too large.")
	}
	sum := sha256.Sum256(body)
	checksum := hex.EncodeToString(sum[:])
	reject := func(reason string) (*FileDTO, error) {
		_ = s.DB.WithUserTx(ctx, uid, func(tx pgx.Tx) error {
			_, err := tx.Exec(ctx, `update files set status = 'rejected', rejection_reason = $2, upload_token_hash = null where id = $1`, id, reason)
			return err
		})
		return nil, apperr.New(apperr.CodeUnsupportedMedia, http.StatusUnprocessableEntity, "The file was rejected: "+reason+".")
	}
	if (f.Expected != nil && *f.Expected != checksum) || (checksumHeader != "" && !strings.EqualFold(checksumHeader, checksum)) {
		return reject("checksum mismatch (the upload may be corrupted)")
	}
	if f.ExpSize != nil && *f.ExpSize != int64(len(body)) {
		return reject("size does not match the upload intent")
	}
	tmp, err := os.CreateTemp(s.TmpDir, "montra-upload-*")
	if err != nil {
		return nil, apperr.Internal(err)
	}
	defer func() { _ = os.Remove(tmp.Name()) }()
	if _, err := tmp.Write(body); err != nil {
		_ = tmp.Close()
		return nil, apperr.Internal(err)
	}
	if err := tmp.Close(); err != nil {
		return nil, apperr.Internal(err)
	}
	det, err := Sniff(tmp.Name(), int64(len(body)))
	if err != nil {
		return nil, apperr.Internal(err)
	}
	if det.Problem != "" {
		return reject(det.Problem)
	}
	if !slices.Contains(pol.Kinds, det.Kind) {
		return reject("the content is not an accepted type for this purpose")
	}
	if err := s.Store.Put(ctx, storage.Area(f.Area), f.ObjectKey, tmp.Name(), det.Kind.MIME); err != nil {
		slog.ErrorContext(ctx, "storage put failed", slog.String("provider", s.Store.Provider()), slog.Any("error", err))
		return nil, apperr.Unavailable(apperr.CodeStorageUnavailable, "File storage is temporarily unavailable. Try again shortly.").WithCause(err)
	}
	if s.Metrics != nil {
		s.Metrics.StorageBytes.WithLabelValues(f.Area).Add(float64(len(body)))
	}
	var dto FileDTO
	err = s.DB.WithUserTx(ctx, uid, func(tx pgx.Tx) error {
		var w, h *int
		if det.Width > 0 {
			w, h = &det.Width, &det.Height
		}
		row, err := scanRow(tx.QueryRow(ctx, `update files set status = 'uploaded', size_bytes = $2, checksum_sha256 = $3, detected_mime = $4,
			image_width = $5, image_height = $6, upload_token_hash = null, extension = $7, scan_status = 'skipped'
			where id = $1 and status = 'pending_upload' returning `+fileCols, id, len(body), checksum, det.Kind.MIME, w, h, det.Kind.Ext))
		if database.IsNoRows(err) {
			return apperr.Conflict("This upload was already completed.")
		}
		if err != nil {
			return err
		}
		dto = row.FileDTO
		return nil
	})
	return &dto, database.MapError(err)
}

// Complete finalizes an uploaded file and emits file.ready for processors.
func (s *Service) Complete(ctx context.Context, id uuid.UUID) (*FileDTO, error) {
	uid, err := identity.UserID(ctx)
	if err != nil {
		return nil, err
	}
	var dto FileDTO
	err = s.DB.WithUserTx(ctx, uid, func(tx pgx.Tx) error {
		f, err := Get(ctx, tx, id)
		if err != nil {
			return err
		}
		if f.OwnerID != uid {
			return apperr.NotFound("file")
		}
		switch f.Status {
		case "ready":
			dto = f.FileDTO
			return nil // idempotent
		case "uploaded":
		default:
			return apperr.Conflict("Upload the file content before completing it.")
		}
		row, err := scanRow(tx.QueryRow(ctx, `update files set status = 'ready' where id = $1 returning `+fileCols, id))
		if err != nil {
			return err
		}
		dto = row.FileDTO
		if err := audit.Record(ctx, tx, audit.Event{UserID: &uid, GroupID: f.GroupID, ActorUserID: &uid, EntityType: "file", EntityID: &id,
			Action: "uploaded", Changes: map[string]any{"purpose": f.Purpose, "size_bytes": f.SizeBytes}}); err != nil {
			return err
		}
		return outbox.Emit(ctx, tx, outbox.Event{Type: "file.ready", AggregateType: "file", AggregateID: id, UserID: &uid, GroupID: f.GroupID,
			Payload: map[string]any{"purpose": f.Purpose}})
	})
	return &dto, database.MapError(err)
}

// Access is a short-lived download capability.
type Access struct {
	URL         string    `json:"url"`
	ExpiresAt   time.Time `json:"expires_at"`
	ContentType string    `json:"content_type"`
	Filename    string    `json:"filename"`
}

// IssueAccess authorizes the caller and returns a signed URL valid for the
// configured TTL (≤ 5 minutes by default). No permanent links exist.
func (s *Service) IssueAccess(ctx context.Context, id uuid.UUID) (*Access, error) {
	uid, err := identity.UserID(ctx)
	if err != nil {
		return nil, err
	}
	var f *Row
	err = s.DB.WithUserReadTx(ctx, uid, func(tx pgx.Tx) error {
		var err error
		f, err = Get(ctx, tx, id)
		return err
	})
	if err != nil {
		return nil, err
	}
	if f.Status != "ready" && f.Status != "uploaded" && f.Status != "processing" {
		return nil, apperr.Conflict("This file is not available.")
	}
	path := "/api/v1/files/" + id.String() + "/content"
	ttl := s.Cfg.Storage.SignedURLTTL
	ct := "application/octet-stream"
	if f.ContentType != nil {
		ct = *f.ContentType
	}
	name := "file"
	if f.OriginalFilename != nil {
		name = *f.OriginalFilename
	}
	return &Access{URL: s.Signer.SignURL(s.Cfg.HTTP.PublicBaseURL, path, uid.String(), ttl, s.now()),
		ExpiresAt: s.now().Add(ttl), ContentType: ct, Filename: name}, nil
}

// OpenSigned validates a signed URL and re-checks authorization for the
// subject (so revoked group membership immediately blocks downloads).
func (s *Service) OpenSigned(ctx context.Context, id uuid.UUID, sub, exp, sig string) (*Row, io.ReadCloser, error) {
	path := "/api/v1/files/" + id.String() + "/content"
	if !s.Signer.VerifyURL(path, sub, exp, sig, s.now()) {
		return nil, nil, apperr.New(apperr.CodeGone, http.StatusGone, "This download link is invalid or has expired.")
	}
	uid, err := uuid.Parse(sub)
	if err != nil {
		return nil, nil, apperr.NotFound("file")
	}
	var f *Row
	err = s.DB.WithUserReadTx(ctx, uid, func(tx pgx.Tx) error {
		var err error
		f, err = Get(ctx, tx, id)
		return err
	})
	if err != nil {
		return nil, nil, err
	}
	rc, err := s.Store.Open(ctx, storage.Area(f.Area), f.ObjectKey)
	if errors.Is(err, storage.ErrNotFound) {
		return nil, nil, apperr.NotFound("file")
	}
	if err != nil {
		return nil, nil, apperr.Unavailable(apperr.CodeStorageUnavailable, "File storage is temporarily unavailable.").WithCause(err)
	}
	return f, rc, nil
}

// ReadOwned loads a ready file's content for server-side processing
// (imports, receipt extraction). The caller's transaction scope must see the
// file; ownership and purpose are checked explicitly and the size is capped.
func (s *Service) ReadOwned(ctx context.Context, tx pgx.Tx, id, owner uuid.UUID, purpose string, maxBytes int64) ([]byte, *Row, error) {
	f, err := Get(ctx, tx, id)
	if err != nil {
		return nil, nil, err
	}
	if f.OwnerID != owner || f.Purpose != purpose {
		return nil, nil, apperr.NotFound("file")
	}
	if f.Status != "ready" {
		return nil, nil, apperr.Conflict("The file is not ready yet.")
	}
	rc, err := s.Store.Open(ctx, storage.Area(f.Area), f.ObjectKey)
	if errors.Is(err, storage.ErrNotFound) {
		return nil, nil, apperr.NotFound("file")
	}
	if err != nil {
		return nil, nil, apperr.Unavailable(apperr.CodeStorageUnavailable, "File storage is temporarily unavailable.").WithCause(err)
	}
	defer func() { _ = rc.Close() }()
	data, err := io.ReadAll(io.LimitReader(rc, maxBytes+1))
	if err != nil {
		return nil, nil, apperr.Unavailable(apperr.CodeStorageUnavailable, "File storage is temporarily unavailable.").WithCause(err)
	}
	if int64(len(data)) > maxBytes {
		return nil, nil, apperr.New(apperr.CodePayloadTooLarge, http.StatusRequestEntityTooLarge, "The file is too large to process.")
	}
	return data, f, nil
}

// Delete marks a file for durable deletion (uploader only).
func (s *Service) Delete(ctx context.Context, id uuid.UUID) error {
	uid, err := identity.UserID(ctx)
	if err != nil {
		return err
	}
	return database.MapError(s.DB.WithUserTx(ctx, uid, func(tx pgx.Tx) error {
		f, err := Get(ctx, tx, id)
		if err != nil {
			return err
		}
		if f.OwnerID != uid {
			// Only the uploader deletes a file; group admins unlink attachments instead.
			return apperr.Forbidden()
		}
		return MarkDeleting(ctx, tx, f, uid)
	}))
}

// MarkDeleting schedules the durable deletion of a file inside the
// caller's transaction, which has already authorized actor: the row becomes
// deleting, attachment links are removed, the deletion is audited and the
// files.delete job removes the stored object, then marks the row deleted.
// Delete and the owners of generated files (report exports) share it.
func MarkDeleting(ctx context.Context, tx pgx.Tx, f *Row, actor uuid.UUID) error {
	if _, err := tx.Exec(ctx, `update files set status = 'deleting', deleted_at = now() where id = $1`, f.ID); err != nil {
		return err
	}
	if _, err := tx.Exec(ctx, `delete from transaction_attachments where file_id = $1`, f.ID); err != nil {
		return err
	}
	if err := audit.Record(ctx, tx, audit.Event{UserID: &f.OwnerID, GroupID: f.GroupID, ActorUserID: &actor, EntityType: "file", EntityID: &f.ID, Action: "deleted"}); err != nil {
		return err
	}
	_, _, err := jobs.Enqueue(ctx, tx, jobs.Spec{Type: JobDelete, UserID: &actor, Payload: map[string]string{"file_id": f.ID.String()},
		DedupeKey: "files.delete:" + f.ID.String()})
	return err
}

// RegisterJobs registers worker handlers (worker role, system scope).
func (s *Service) RegisterJobs(reg *jobs.Registry) {
	reg.Register(JobDelete, func(ctx context.Context, j jobs.Job) error {
		var p struct {
			FileID uuid.UUID `json:"file_id"`
		}
		if err := j.Decode(&p); err != nil {
			return err
		}
		return s.purge(ctx, p.FileID)
	}, jobs.WithTimeout(2*time.Minute))
	reg.Register(JobCleanup, func(ctx context.Context, _ jobs.Job) error { return s.cleanup(ctx) },
		jobs.WithTimeout(10*time.Minute), jobs.WithConcurrency(1))
}

// purge removes the stored object then marks the row deleted (idempotent).
func (s *Service) purge(ctx context.Context, id uuid.UUID) error {
	var area, key, status string
	err := s.DB.WithSystemTx(ctx, func(tx pgx.Tx) error {
		return tx.QueryRow(ctx, `select storage_area, object_key, status from files where id = $1`, id).Scan(&area, &key, &status)
	})
	if database.IsNoRows(err) || status == "deleted" {
		return nil
	}
	if err != nil {
		return err
	}
	if err := s.Store.Delete(ctx, storage.Area(area), key); err != nil && !errors.Is(err, storage.ErrDisabled) {
		return jobs.WithCode("storage_delete_failed", err)
	}
	return s.DB.WithSystemTx(ctx, func(tx pgx.Tx) error {
		_, err := tx.Exec(ctx, `update files set status = 'deleted', deleted_at = coalesce(deleted_at, now()), upload_token_hash = null where id = $1`, id)
		return err
	})
}

// PurgeUserFiles deletes every stored object of a user (account deletion).
func (s *Service) PurgeUserFiles(ctx context.Context, userID uuid.UUID) (int, error) {
	var ids []uuid.UUID
	err := s.DB.WithSystemTx(ctx, func(tx pgx.Tx) error {
		rows, err := tx.Query(ctx, `select id from files where owner_user_id = $1 and status <> 'deleted'`, userID)
		if err != nil {
			return err
		}
		defer rows.Close()
		for rows.Next() {
			var id uuid.UUID
			if err := rows.Scan(&id); err != nil {
				return err
			}
			ids = append(ids, id)
		}
		return rows.Err()
	})
	if err != nil {
		return 0, err
	}
	for _, id := range ids {
		if err := s.purge(ctx, id); err != nil {
			return 0, err
		}
	}
	return len(ids), nil
}

// cleanup expires abandoned uploads and purges objects past retention.
func (s *Service) cleanup(ctx context.Context) error {
	var stale []uuid.UUID
	err := s.DB.WithSystemTx(ctx, func(tx pgx.Tx) error {
		if _, err := tx.Exec(ctx, `update files set status = 'rejected', rejection_reason = 'upload not completed', upload_token_hash = null
			where status = 'pending_upload' and created_at < now() - make_interval(secs => $1)`, s.Cfg.Product.Retention.TempFiles.Seconds()); err != nil {
			return err
		}
		rows, err := tx.Query(ctx, `select id from files where (status in ('rejected','deleting') and updated_at < now() - interval '1 hour')
			or (retention_until is not null and retention_until < now() and status <> 'deleted') limit 500`)
		if err != nil {
			return err
		}
		defer rows.Close()
		for rows.Next() {
			var id uuid.UUID
			if err := rows.Scan(&id); err != nil {
				return err
			}
			stale = append(stale, id)
		}
		return rows.Err()
	})
	if err != nil {
		return err
	}
	for _, id := range stale {
		if err := s.purge(ctx, id); err != nil {
			return err
		}
	}
	return nil
}

// Metadata returns file metadata visible to the caller.
func (s *Service) Metadata(ctx context.Context, id uuid.UUID) (*FileDTO, error) {
	uid, err := identity.UserID(ctx)
	if err != nil {
		return nil, err
	}
	var out FileDTO
	err = s.DB.WithUserReadTx(ctx, uid, func(tx pgx.Tx) error {
		f, err := Get(ctx, tx, id)
		if err != nil {
			return err
		}
		out = f.FileDTO
		return nil
	})
	return &out, err
}

// UsedBytes is a user's stored file volume, counting uploads in flight at
// their declared size (so parallel uploads cannot bypass the allowance).
func UsedBytes(ctx context.Context, tx pgx.Tx, uid uuid.UUID) (int64, error) {
	var used int64
	err := tx.QueryRow(ctx, `select coalesce(sum(coalesce(size_bytes, expected_size_bytes, 0)), 0)::bigint from files
		where owner_user_id = $1 and status not in ('rejected','deleting','deleted')`, uid).Scan(&used)
	return used, err
}
