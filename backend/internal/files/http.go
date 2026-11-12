package files

import (
	"context"
	"io"
	"log/slog"
	"mime"
	"net/http"
	"strconv"
	"strings"

	"github.com/danielgtaylor/huma/v2"
	"github.com/google/uuid"

	"montra/backend/internal/platform/httpx"
	"montra/backend/internal/platform/ratelimit"
)

// Routes mounts the file endpoints.
func (s *Service) Routes(api huma.API) {
	const tag = "Files"
	upload := func(op huma.Operation) huma.Operation { return httpx.Rate(op, ratelimit.Upload.Name) }

	httpx.Protected(api, httpx.Created(upload(httpx.Op("files-upload-intent", http.MethodPost, "/files/upload-intent",
		"Authorize an upload and receive a single-use upload URL", tag))),
		func(ctx context.Context, in *struct{ Body UploadIntentInput }) (*httpx.Response[UploadIntent], error) {
			out, err := s.CreateIntent(ctx, in.Body)
			if err != nil {
				return nil, err
			}
			return httpx.OK(ctx, *out), nil
		})

	maxBody := int64(20 << 20)
	if s.Cfg != nil && s.Cfg.Storage.MaxUploadBytes > 0 {
		maxBody = s.Cfg.Storage.MaxUploadBytes
	}
	httpx.Protected(api, httpx.MaxBody(upload(httpx.Op("files-upload-content", http.MethodPut, "/files/{fileId}/content",
		"Upload file bytes (validated by content, size and checksum)", tag)), maxBody),
		func(ctx context.Context, in *struct {
			FileID   uuid.UUID `path:"fileId"`
			Token    string    `header:"X-Upload-Token" required:"true" maxLength:"128"`
			Checksum string    `header:"X-Upload-Checksum" maxLength:"64" doc:"Optional SHA-256 hex of the content"`
			RawBody  []byte    `contentType:"application/octet-stream"`
		}) (*httpx.Response[FileDTO], error) {
			out, err := s.UploadContent(ctx, in.FileID, in.Token, in.Checksum, in.RawBody)
			if err != nil {
				return nil, err
			}
			return httpx.OK(ctx, *out), nil
		})

	httpx.Protected(api, httpx.Op("files-complete", http.MethodPost, "/files/{fileId}/complete", "Finalize an uploaded file", tag),
		func(ctx context.Context, in *struct {
			FileID uuid.UUID `path:"fileId"`
		}) (*httpx.Response[FileDTO], error) {
			out, err := s.Complete(ctx, in.FileID)
			if err != nil {
				return nil, err
			}
			return httpx.OK(ctx, *out), nil
		})

	httpx.Protected(api, httpx.Op("files-get", http.MethodGet, "/files/{fileId}", "Get file metadata", tag),
		func(ctx context.Context, in *struct {
			FileID uuid.UUID `path:"fileId"`
		}) (*httpx.Response[FileDTO], error) {
			out, err := s.Metadata(ctx, in.FileID)
			if err != nil {
				return nil, err
			}
			return httpx.OK(ctx, *out), nil
		})

	httpx.Protected(api, httpx.Op("files-access", http.MethodGet, "/files/{fileId}/access",
		"Issue a short-lived download URL (authorization checked on every call)", tag),
		func(ctx context.Context, in *struct {
			FileID uuid.UUID `path:"fileId"`
		}) (*httpx.Response[Access], error) {
			out, err := s.IssueAccess(ctx, in.FileID)
			if err != nil {
				return nil, err
			}
			return httpx.OK(ctx, *out), nil
		})

	httpx.Public(api, httpx.Op("files-download", http.MethodGet, "/files/{fileId}/content",
		"Download via a signed URL from /files/{fileId}/access", tag),
		func(ctx context.Context, in *struct {
			FileID uuid.UUID `path:"fileId"`
			Exp    string    `query:"exp" maxLength:"20"`
			Sub    string    `query:"sub" maxLength:"64"`
			Sig    string    `query:"sig" maxLength:"128"`
		}) (*huma.StreamResponse, error) {
			f, rc, err := s.OpenSigned(ctx, in.FileID, in.Sub, in.Exp, in.Sig)
			if err != nil {
				return nil, err
			}
			ct := "application/octet-stream"
			if f.ContentType != nil {
				ct = *f.ContentType
			}
			name := "file"
			if f.OriginalFilename != nil {
				name = *f.OriginalFilename
			}
			disp := "attachment"
			if strings.HasPrefix(ct, "image/") {
				disp = "inline"
			}
			return &huma.StreamResponse{Body: func(hctx huma.Context) {
				defer func() { _ = rc.Close() }()
				hctx.SetHeader("Content-Type", ct)
				hctx.SetHeader("Content-Disposition", mime.FormatMediaType(disp, map[string]string{"filename": name}))
				hctx.SetHeader("X-Content-Type-Options", "nosniff")
				hctx.SetHeader("Content-Security-Policy", "sandbox; default-src 'none'")
				if f.SizeBytes != nil {
					hctx.SetHeader("Content-Length", strconv.FormatInt(*f.SizeBytes, 10))
				}
				hctx.SetStatus(http.StatusOK)
				if _, err := io.Copy(hctx.BodyWriter(), rc); err != nil {
					slog.WarnContext(ctx, "download interrupted", slog.Any("error", err))
				}
			}}, nil
		})

	httpx.Protected(api, httpx.Op("files-delete", http.MethodDelete, "/files/{fileId}", "Delete a file (removed from storage by a durable job)", tag),
		func(ctx context.Context, in *struct {
			FileID uuid.UUID `path:"fileId"`
		}) (*httpx.Response[httpx.Empty], error) {
			if err := s.Delete(ctx, in.FileID); err != nil {
				return nil, err
			}
			return httpx.Done(ctx), nil
		})
}
