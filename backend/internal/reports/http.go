package reports

import (
	"context"
	"net/http"

	"github.com/danielgtaylor/huma/v2"
	"github.com/google/uuid"

	"montra/backend/internal/files"
	"montra/backend/internal/platform/httpx"
	"montra/backend/internal/platform/ratelimit"
)

// Routes mounts report endpoints.
func (s *Service) Routes(api huma.API) {
	const tag = "Reports"
	write := func(op huma.Operation) huma.Operation { return httpx.Rate(op, ratelimit.Write.Name) }
	httpx.Protected(api, httpx.Accepted(write(httpx.Op("reports-create", http.MethodPost, "/reports",
		"Generate a report or export (runs in the background)", tag))),
		func(ctx context.Context, in *struct{ Body ReportInput }) (*httpx.Response[ReportDTO], error) {
			r, err := s.Create(ctx, in.Body)
			if err != nil {
				return nil, err
			}
			return httpx.OK(ctx, *r), nil
		})
	httpx.Protected(api, httpx.Op("reports-list", http.MethodGet, "/reports", "Recent reports", tag),
		func(ctx context.Context, _ *struct{}) (*httpx.Response[[]ReportDTO], error) {
			l, err := s.List(ctx)
			if err != nil {
				return nil, err
			}
			return httpx.OK(ctx, l), nil
		})
	httpx.Protected(api, httpx.Created(write(httpx.Op("reports-schedules-create", http.MethodPost, "/reports/schedules",
		"Schedule a weekly or monthly report", tag))),
		func(ctx context.Context, in *struct{ Body ScheduleInput }) (*httpx.Response[ScheduleDTO], error) {
			r, err := s.CreateSchedule(ctx, in.Body)
			if err != nil {
				return nil, err
			}
			return httpx.OK(ctx, *r), nil
		})
	httpx.Protected(api, httpx.Op("reports-schedules-list", http.MethodGet, "/reports/schedules", "Scheduled reports", tag),
		func(ctx context.Context, _ *struct{}) (*httpx.Response[[]ScheduleDTO], error) {
			l, err := s.ListSchedules(ctx)
			if err != nil {
				return nil, err
			}
			return httpx.OK(ctx, l), nil
		})
	httpx.Protected(api, httpx.Op("reports-schedules-get", http.MethodGet, "/reports/schedules/{id}", "One scheduled report", tag),
		func(ctx context.Context, in *struct {
			ID uuid.UUID `path:"id"`
		}) (*httpx.Response[ScheduleDTO], error) {
			r, err := s.GetSchedule(ctx, in.ID)
			if err != nil {
				return nil, err
			}
			return httpx.OK(ctx, *r), nil
		})
	schedulePatch := write(httpx.Op("reports-schedules-update", http.MethodPatch, "/reports/schedules/{id}",
		"Edit, pause or resume a scheduled report", tag))
	schedulePatch.Description = "Changes only the fields sent: title, format, cadence, filters (replaced as a whole; the cadence sets the " +
		"dates) and enabled. enabled=false pauses the schedule; enabled=true resumes it from the next start of a week or month (periods " +
		"missed while paused are not back-filled), as does a new cadence. Send the version you read: a concurrent change answers 409 " +
		"VERSION_CONFLICT. Income and expense schedules accept only their own transaction types (422 on body.filters.types)."
	httpx.Protected(api, schedulePatch,
		func(ctx context.Context, in *struct {
			ID   uuid.UUID `path:"id"`
			Body SchedulePatch
		}) (*httpx.Response[ScheduleDTO], error) {
			r, err := s.UpdateSchedule(ctx, in.ID, in.Body)
			if err != nil {
				return nil, err
			}
			return httpx.OK(ctx, *r), nil
		})
	httpx.Protected(api, write(httpx.Op("reports-schedules-delete", http.MethodDelete, "/reports/schedules/{id}", "Delete a scheduled report", tag)),
		func(ctx context.Context, in *struct {
			ID uuid.UUID `path:"id"`
		}) (*httpx.Response[httpx.Empty], error) {
			if err := s.DeleteSchedule(ctx, in.ID); err != nil {
				return nil, err
			}
			return httpx.Done(ctx), nil
		})
	deleteOp := write(httpx.Op("reports-delete", http.MethodDelete, "/reports/{id}", "Delete a report and its file", tag))
	deleteOp.Description = "Owner only (others get 404). Works in any status: a queued or running generation is cancelled, and the " +
		"stored file is deleted durably (download links stop working). Audited."
	httpx.Protected(api, deleteOp,
		func(ctx context.Context, in *struct {
			ID uuid.UUID `path:"id"`
		}) (*httpx.Response[httpx.Empty], error) {
			if err := s.Delete(ctx, in.ID); err != nil {
				return nil, err
			}
			return httpx.Done(ctx), nil
		})
	httpx.Protected(api, httpx.Op("reports-get", http.MethodGet, "/reports/{id}", "Report status and metadata", tag),
		func(ctx context.Context, in *struct {
			ID uuid.UUID `path:"id"`
		}) (*httpx.Response[ReportDTO], error) {
			r, err := s.Get(ctx, in.ID)
			if err != nil {
				return nil, err
			}
			return httpx.OK(ctx, *r), nil
		})
	httpx.Protected(api, httpx.Errs(httpx.Op("reports-download", http.MethodGet, "/reports/{id}/download",
		"Short-lived signed download link for a completed report", tag), http.StatusGone),
		func(ctx context.Context, in *struct {
			ID uuid.UUID `path:"id"`
		}) (*httpx.Response[files.Access], error) {
			a, err := s.Download(ctx, in.ID)
			if err != nil {
				return nil, err
			}
			return httpx.OK(ctx, *a), nil
		})
}
