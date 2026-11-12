package subscriptions

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

func describe(op huma.Operation, description string) huma.Operation {
	op.Description = description
	return op
}

const transitionConflict = " Any other status answers 422 DOMAIN_RULE_VIOLATION with details[0].code invalid_status_transition (params from, to). " +
	"Send ?version= to fail with 409 VERSION_CONFLICT when the subscription changed meanwhile."

// Routes mounts subscription endpoints.
func (s *Service) Routes(api huma.API) {
	const tag = "Subscriptions"
	write := func(op huma.Operation) huma.Operation { return httpx.Rate(op, ratelimit.Write.Name) }

	httpx.Protected(api, describe(httpx.Op("subscriptions-list", http.MethodGet, "/subscriptions", "List subscriptions with normalized costs", tag),
		"Without status, every subscription that is not cancelled; status=all includes cancelled ones. Ordered by next renewal, then name; at most 500."),
		func(ctx context.Context, in *struct {
			Status string `query:"status" enum:"trial,active,paused,cancellation_pending,cancelled,all," doc:"Default (empty): all except cancelled; all: every status"`
		}) (*httpx.Response[[]SubscriptionDTO], error) {
			l, err := s.List(ctx, in.Status)
			if err != nil {
				return nil, err
			}
			return httpx.OK(ctx, l), nil
		})
	httpx.Protected(api, httpx.Op("subscriptions-summary", http.MethodGet, "/subscriptions/summary",
		"Monthly and annual totals, upcoming renewals and trials ending", tag),
		func(ctx context.Context, _ *struct{}) (*httpx.Response[SubscriptionSummary], error) {
			sm, err := s.Summary(ctx)
			if err != nil {
				return nil, err
			}
			return httpx.OK(ctx, *sm), nil
		})
	httpx.Protected(api, httpx.Created(write(httpx.Op("subscriptions-create", http.MethodPost, "/subscriptions", "Add a subscription manually", tag))),
		func(ctx context.Context, in *struct {
			httpx.IdemHeader
			Body SubscriptionInput
		}) (*httpx.ReplayOutput[SubscriptionDetail], error) {
			d, replayed, err := s.Create(ctx, in.Key, in.Body)
			if err != nil {
				return nil, err
			}
			return httpx.Replay(ctx, *d, replayed), nil
		})
	httpx.Protected(api, describe(httpx.Op("subscriptions-detections", http.MethodGet, "/subscriptions/detections",
		"Possible subscriptions found in your transactions, with evidence and confidence", tag),
		"Default status pending. Highest confidence first; at most 100."),
		func(ctx context.Context, in *struct {
			Status string `query:"status" enum:"pending,confirmed,dismissed," doc:"Default pending"`
		}) (*httpx.Response[[]DetectionCandidateDTO], error) {
			l, err := s.ListCandidates(ctx, in.Status)
			if err != nil {
				return nil, err
			}
			return httpx.OK(ctx, l), nil
		})
	httpx.Protected(api, httpx.Accepted(httpx.Rate(httpx.Op("subscriptions-detections-refresh", http.MethodPost, "/subscriptions/detections/refresh",
		"Look for new recurring charges now (runs in the background)", tag), ratelimit.Write.Name)),
		func(ctx context.Context, _ *struct{}) (*httpx.Response[httpx.Empty], error) {
			if err := s.RequestDetection(ctx); err != nil {
				return nil, err
			}
			return httpx.Done(ctx), nil
		})
	httpx.Protected(api, httpx.Created(write(describe(httpx.Op("subscriptions-detection-confirm", http.MethodPost, "/subscriptions/detections/{id}/confirm",
		"Create a subscription from a detection (your confirmation is required)", tag),
		"The supporting charges become linked payments (note_code matched_by_detection), except charges already linked to another subscription. "+
			"A detection that was already confirmed or dismissed answers 409 CONFLICT detection_already_decided; one whose charges are gone, "+
			"409 CONFLICT detection_evidence_missing."))),
		func(ctx context.Context, in *struct {
			IDPath
			Body DetectionConfirmInput
		}) (*httpx.Response[SubscriptionDetail], error) {
			d, err := s.Confirm(ctx, in.ID, in.Body)
			if err != nil {
				return nil, err
			}
			return httpx.OK(ctx, *d), nil
		})
	httpx.Protected(api, write(httpx.Op("subscriptions-detection-dismiss", http.MethodPost, "/subscriptions/detections/{id}/dismiss",
		"Dismiss a detection (it will not be suggested again)", tag)),
		func(ctx context.Context, in *IDPath) (*httpx.Response[httpx.Empty], error) {
			if err := s.Dismiss(ctx, in.ID); err != nil {
				return nil, err
			}
			return httpx.Done(ctx), nil
		})
	httpx.Protected(api, httpx.Op("subscriptions-get", http.MethodGet, "/subscriptions/{id}", "Get a subscription with price and payment history", tag),
		func(ctx context.Context, in *IDPath) (*httpx.Response[SubscriptionDetail], error) {
			d, err := s.Get(ctx, in.ID)
			if err != nil {
				return nil, err
			}
			return httpx.OK(ctx, *d), nil
		})
	httpx.Protected(api, write(describe(httpx.Op("subscriptions-update", http.MethodPatch, "/subscriptions/{id}",
		"Update a subscription (only the fields sent); price changes are kept in history", tag),
		"Fields that are not sent keep their values. Empty strings clear optional text and dates; clear lists optional links to remove "+
			"(422 when a field is both sent and cleared). version is optional: when sent and stale, 409 VERSION_CONFLICT. "+
			"Sending the full record still works.")),
		func(ctx context.Context, in *struct {
			IDPath
			Body SubscriptionPatch
		}) (*httpx.Response[SubscriptionDetail], error) {
			d, err := s.Update(ctx, in.ID, in.Body)
			if err != nil {
				return nil, err
			}
			return httpx.OK(ctx, *d), nil
		})
	actions := map[string]string{
		"pause": "pause", "resume": "resume", "cancellation-started": "cancellation_started",
		"cancelled": "cancelled", "reactivate": "reactivate", "verify": "verify",
	}
	summaries := map[string]string{
		"pause": "Pause tracking", "resume": "Resume", "cancellation-started": "Start cancelling (checklist)",
		"cancelled": "Mark cancelled after the provider confirmed it (confirm=true required)", "reactivate": "Reactivate",
		"verify": "Confirm the details are still accurate",
	}
	descriptions := map[string]string{
		"pause":                "Allowed from trial or active; the subscription becomes paused (no renewal reminders, left out of totals)." + transitionConflict,
		"resume":               "Allowed from paused; becomes active and a passed renewal date moves to the next upcoming renewal." + transitionConflict,
		"cancellation-started": "Allowed from trial, active or paused; becomes cancellation_pending while you work through the cancellation checklist." + transitionConflict,
		"cancelled": "Allowed from trial, active, paused or cancellation_pending; becomes cancelled and the renewal date is removed. " +
			"confirm=true is required (you confirm the provider cancelled it; Montra never cancels): otherwise 422 VALIDATION_ERROR with " +
			"details[0].code cancellation_confirmation_required. cancelled_on (or effective_on) is the cancellation date, default today." + transitionConflict,
		"reactivate": "Allowed from cancelled or cancellation_pending; becomes active and a passed renewal date moves to the next upcoming renewal." + transitionConflict,
		"verify":     "Allowed in every status; records that you checked the details (last_verified_at). Send ?version= to fail with 409 VERSION_CONFLICT when the subscription changed meanwhile.",
	}
	for path, action := range actions {
		action := action
		httpx.Protected(api, write(describe(httpx.Op("subscriptions-"+path, http.MethodPost, "/subscriptions/{id}/"+path, summaries[path], tag), descriptions[path])),
			func(ctx context.Context, in *struct {
				VersionedIDPath
				Body *SubscriptionActionInput
			}) (*httpx.Response[SubscriptionDetail], error) {
				var body SubscriptionActionInput
				if in.Body != nil {
					body = *in.Body
				}
				d, err := s.Act(ctx, in.ID, action, in.Version, body)
				if err != nil {
					return nil, err
				}
				return httpx.OK(ctx, *d), nil
			})
	}
	httpx.Protected(api, write(describe(httpx.Op("subscriptions-checklist-item-update", http.MethodPatch, "/subscriptions/{id}/cancellation-checklist/{index}",
		"Tick, untick or rename one cancellation checklist item", tag),
		"index is the item's position in cancellation_checklist, from 0 (404 when there is no such item). Replace the whole checklist with PATCH /subscriptions/{id}.")),
		func(ctx context.Context, in *struct {
			IDPath
			Index int `path:"index" minimum:"0" maximum:"19"`
			Body  ChecklistItemPatch
		}) (*httpx.Response[SubscriptionDetail], error) {
			d, err := s.UpdateChecklistItem(ctx, in.ID, in.Index, in.Body)
			if err != nil {
				return nil, err
			}
			return httpx.OK(ctx, *d), nil
		})
	httpx.Protected(api, httpx.Created(write(describe(httpx.Op("subscriptions-payments-record", http.MethodPost, "/subscriptions/{id}/payments",
		"Record a payment by linking one of your transactions", tag),
		"A transaction backs at most one subscription payment: 409 DUPLICATE with details[0].code payment_already_linked (this subscription) "+
			"or payment_linked_elsewhere (another one). update_price=true records a price change when the charge differs from the price."))),
		func(ctx context.Context, in *struct {
			IDPath
			httpx.IdemHeader
			Body SubscriptionPaymentInput
		}) (*httpx.ReplayOutput[SubscriptionDetail], error) {
			d, replayed, err := s.RecordPayment(ctx, in.Key, in.ID, in.Body)
			if err != nil {
				return nil, err
			}
			return httpx.Replay(ctx, *d, replayed), nil
		})
	httpx.Protected(api, write(describe(httpx.Op("subscriptions-payments-unlink", http.MethodDelete, "/subscriptions/{id}/payments/{transactionId}",
		"Unlink a recorded payment (the transaction is not changed)", tag),
		"The history keeps the payment_recorded entry and gains a payment_unlinked one; the transaction can be linked again. "+
			"404 when the transaction is not a linked payment of this subscription (also on a repeated call).")),
		func(ctx context.Context, in *struct {
			IDPath
			TransactionID uuid.UUID `path:"transactionId"`
		}) (*httpx.Response[SubscriptionDetail], error) {
			d, err := s.UnlinkPayment(ctx, in.ID, in.TransactionID)
			if err != nil {
				return nil, err
			}
			return httpx.OK(ctx, *d), nil
		})
	httpx.Protected(api, describe(httpx.Op("subscriptions-payment-candidates", http.MethodGet, "/subscriptions/{id}/payment-candidates",
		"Unlinked expenses that may be this subscription's payments", tag),
		"Recent expenses in the subscription currency that are not linked to any subscription and share its merchant or name, or cost "+
			"within 25% of the price. Same merchant first, then name, closest amount and closest expected renewal date; at most 20. "+
			"Empty for cancelled subscriptions. Owner only."),
		func(ctx context.Context, in *IDPath) (*httpx.Response[[]SubscriptionPaymentCandidate], error) {
			l, err := s.PaymentCandidates(ctx, in.ID)
			if err != nil {
				return nil, err
			}
			return httpx.OK(ctx, l), nil
		})
}
