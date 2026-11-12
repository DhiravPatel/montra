package recurring

import (
	"context"
	"net/http"

	"github.com/danielgtaylor/huma/v2"
	"github.com/google/uuid"

	"montra/backend/internal/platform/httpx"
	"montra/backend/internal/platform/ratelimit"
)

// IDPath binds {id}.
type IDPath struct {
	ID uuid.UUID `path:"id"`
}

// VersionedIDPath binds {id} and an optional ?version= for state changes.
type VersionedIDPath struct {
	IDPath
	Version int32 `query:"version" minimum:"0" doc:"Current version; when sent, a concurrent change answers 409 VERSION_CONFLICT"`
}

var billActionSummary = map[string]string{
	"pause":   "Pause a bill (no reminders until resumed)",
	"resume":  "Resume a paused bill from today",
	"archive": "Archive a bill (history kept)",
	"restore": "Restore an archived bill",
}

// Routes mounts recurring rule, occurrence, bill and calendar endpoints.
func (s *Service) Routes(api huma.API) {
	const tag = "Recurring & bills"
	write := func(op huma.Operation) huma.Operation { return httpx.Rate(op, ratelimit.Write.Name) }

	httpx.Protected(api, httpx.Op("recurring-list", http.MethodGet, "/recurring-rules", "List recurring rules", tag),
		func(ctx context.Context, in *struct {
			Kind   string `query:"kind" enum:"expense,income,transfer,bill,"`
			Status string `query:"status" enum:"active,paused,ended,"`
		}) (*httpx.Response[[]RecurringRuleDTO], error) {
			l, err := s.ListRules(ctx, in.Kind, in.Status)
			if err != nil {
				return nil, err
			}
			return httpx.OK(ctx, l), nil
		})
	httpx.Protected(api, httpx.Created(write(httpx.Op("recurring-create", http.MethodPost, "/recurring-rules",
		"Create a recurring income, expense or transfer", tag))),
		func(ctx context.Context, in *struct {
			httpx.IdemHeader
			Body RecurringRuleInput
		}) (*httpx.ReplayOutput[RecurringRuleDTO], error) {
			r, replayed, err := s.CreateRule(ctx, in.Key, in.Body)
			if err != nil {
				return nil, err
			}
			return httpx.Replay(ctx, *r, replayed), nil
		})
	httpx.Protected(api, httpx.Op("recurring-get", http.MethodGet, "/recurring-rules/{id}", "Get a rule with occurrence history", tag),
		func(ctx context.Context, in *IDPath) (*httpx.Response[RecurringRuleDetail], error) {
			r, err := s.GetRule(ctx, in.ID)
			if err != nil {
				return nil, err
			}
			return httpx.OK(ctx, *r), nil
		})
	httpx.Protected(api, write(httpx.Op("recurring-update", http.MethodPatch, "/recurring-rules/{id}",
		"Edit this and future occurrences (only the fields sent change)", tag)),
		func(ctx context.Context, in *struct {
			IDPath
			Body RecurringRulePatch
		}) (*httpx.Response[RecurringRuleDTO], error) {
			r, err := s.PatchRule(ctx, in.ID, in.Body)
			if err != nil {
				return nil, err
			}
			return httpx.OK(ctx, *r), nil
		})
	httpx.Protected(api, write(httpx.Op("recurring-delete", http.MethodDelete, "/recurring-rules/{id}",
		"Delete an unused rule, or end one that has history", tag)),
		func(ctx context.Context, in *IDPath) (*httpx.Response[RecurringDeleteResult], error) {
			r, err := s.DeleteRule(ctx, in.ID)
			if err != nil {
				return nil, err
			}
			return httpx.OK(ctx, *r), nil
		})
	for _, action := range []string{"pause", "resume", "stop"} {
		action := action
		httpx.Protected(api, write(httpx.Op("recurring-"+action, http.MethodPost, "/recurring-rules/{id}/"+action, action+" a recurring rule", tag)),
			func(ctx context.Context, in *VersionedIDPath) (*httpx.Response[RecurringRuleDTO], error) {
				r, err := s.SetRuleStatus(ctx, in.ID, action, in.Version)
				if err != nil {
					return nil, err
				}
				return httpx.OK(ctx, *r), nil
			})
	}
	httpx.Protected(api, write(httpx.Op("recurring-skip-next", http.MethodPost, "/recurring-rules/{id}/skip-next", "Skip the next occurrence", tag)),
		func(ctx context.Context, in *VersionedIDPath) (*httpx.Response[RecurringRuleDTO], error) {
			r, err := s.SkipNext(ctx, in.ID, in.Version)
			if err != nil {
				return nil, err
			}
			return httpx.OK(ctx, *r), nil
		})
	httpx.Protected(api, write(httpx.Op("recurring-occurrence-act", http.MethodPost, "/recurring-occurrences/{id}/actions",
		"Skip, reopen, postpone, set the amount, confirm (record) or link a transaction for one occurrence", tag)),
		func(ctx context.Context, in *struct {
			IDPath
			httpx.IdemHeader
			Body OccurrenceAction
		}) (*httpx.ReplayOutput[OccurrenceDTO], error) {
			o, replayed, err := s.ActOnOccurrence(ctx, in.Key, in.ID, in.Body)
			if err != nil {
				return nil, err
			}
			return httpx.Replay(ctx, *o, replayed), nil
		})

	httpx.Protected(api, httpx.Op("bills-list", http.MethodGet, "/bills", "List bills with payment state", tag),
		func(ctx context.Context, in *struct {
			Status string `query:"status" enum:"active,paused,archived,all,"`
		}) (*httpx.Response[[]BillDTO], error) {
			l, err := s.ListBills(ctx, in.Status)
			if err != nil {
				return nil, err
			}
			return httpx.OK(ctx, l), nil
		})
	httpx.Protected(api, httpx.Created(write(httpx.Op("bills-create", http.MethodPost, "/bills", "Create a bill", tag))),
		func(ctx context.Context, in *struct {
			httpx.IdemHeader
			Body BillInput
		}) (*httpx.ReplayOutput[BillDetail], error) {
			b, replayed, err := s.CreateBill(ctx, in.Key, in.Body)
			if err != nil {
				return nil, err
			}
			return httpx.Replay(ctx, *b, replayed), nil
		})
	httpx.Protected(api, httpx.Op("bills-get", http.MethodGet, "/bills/{id}", "Get a bill with payment history", tag),
		func(ctx context.Context, in *IDPath) (*httpx.Response[BillDetail], error) {
			b, err := s.GetBill(ctx, in.ID)
			if err != nil {
				return nil, err
			}
			return httpx.OK(ctx, *b), nil
		})
	httpx.Protected(api, write(httpx.Op("bills-update", http.MethodPatch, "/bills/{id}",
		"Update a bill and its future schedule (only the fields sent change)", tag)),
		func(ctx context.Context, in *struct {
			IDPath
			Body BillPatch
		}) (*httpx.Response[BillDetail], error) {
			b, err := s.PatchBill(ctx, in.ID, in.Body)
			if err != nil {
				return nil, err
			}
			return httpx.OK(ctx, *b), nil
		})
	for _, action := range []string{"pause", "resume", "archive", "restore"} {
		httpx.Protected(api, write(httpx.Op("bills-"+action, http.MethodPost, "/bills/{id}/"+action, billActionSummary[action], tag)),
			func(ctx context.Context, in *VersionedIDPath) (*httpx.Response[BillDetail], error) {
				b, err := s.SetBillStatus(ctx, in.ID, action, in.Version)
				if err != nil {
					return nil, err
				}
				return httpx.OK(ctx, *b), nil
			})
	}
	httpx.Protected(api, write(httpx.Op("bills-mark-paid", http.MethodPost, "/bills/{id}/mark-paid",
		"Mark paid by linking the recorded payment, or record a new payment", tag)),
		func(ctx context.Context, in *struct {
			IDPath
			httpx.IdemHeader
			Body MarkPaidInput
		}) (*httpx.ReplayOutput[BillDetail], error) {
			b, replayed, err := s.MarkPaid(ctx, in.Key, in.ID, in.Body)
			if err != nil {
				return nil, err
			}
			return httpx.Replay(ctx, *b, replayed), nil
		})
	httpx.Protected(api, write(httpx.Op("bills-skip", http.MethodPost, "/bills/{id}/skip", "Skip an occurrence (default: the oldest unpaid)", tag)),
		func(ctx context.Context, in *struct {
			IDPath
			Body struct {
				OccurrenceID *uuid.UUID `json:"occurrence_id,omitempty"`
			}
		}) (*httpx.Response[BillDetail], error) {
			b, err := s.SkipBill(ctx, in.ID, in.Body.OccurrenceID)
			if err != nil {
				return nil, err
			}
			return httpx.OK(ctx, *b), nil
		})
	httpx.Protected(api, httpx.Errs(httpx.Op("bills-payment-candidates", http.MethodGet, "/bills/{id}/payment-candidates",
		"Recorded transactions that may be this bill's payment (link instead of duplicating); empty when nothing is unpaid. "+
			"409 occurrence_not_open when the requested occurrence is already paid or skipped", tag), http.StatusConflict),
		func(ctx context.Context, in *struct {
			IDPath
			OccurrenceID string `query:"occurrence_id" format:"uuid"`
		}) (*httpx.Response[[]BillPaymentCandidate], error) {
			var occ *uuid.UUID
			if in.OccurrenceID != "" {
				id, err := uuid.Parse(in.OccurrenceID)
				if err != nil {
					return nil, huma.Error422UnprocessableEntity("occurrence_id must be a UUID")
				}
				occ = &id
			}
			l, err := s.PaymentCandidates(ctx, in.ID, occ)
			if err != nil {
				return nil, err
			}
			return httpx.OK(ctx, l), nil
		})
	httpx.Protected(api, httpx.Op("calendar", http.MethodGet, "/calendar",
		"Upcoming bills, recurring items, subscription renewals, trial ends and goal dates", "Planning"),
		func(ctx context.Context, in *struct {
			From string `query:"from" doc:"YYYY-MM-DD, default today"`
			To   string `query:"to" doc:"YYYY-MM-DD, default today + 30 (range at most 93 days)"`
		}) (*httpx.Response[[]CalendarItem], error) {
			l, err := s.Calendar(ctx, in.From, in.To)
			if err != nil {
				return nil, err
			}
			return httpx.OK(ctx, l), nil
		})
}
