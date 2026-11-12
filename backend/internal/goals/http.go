package goals

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

// CSVOutput is a CSV download.
type CSVOutput struct {
	ContentType        string `header:"Content-Type"`
	ContentDisposition string `header:"Content-Disposition"`
	Body               []byte
}

func describe(op huma.Operation, description string) huma.Operation {
	op.Description = description
	return op
}

const statusRules = " Owner only. Any other status answers 422 DOMAIN_RULE_VIOLATION with details[0].code invalid_status_transition " +
	"(params from, to). Send ?version= to fail with 409 VERSION_CONFLICT when the goal changed meanwhile."

// Routes mounts goal endpoints.
func (s *Service) Routes(api huma.API) {
	const tag = "Goals"
	write := func(op huma.Operation) huma.Operation { return httpx.Rate(op, ratelimit.Write.Name) }

	httpx.Protected(api, describe(httpx.Op("goals-list", http.MethodGet, "/goals", "List your own and shared goals with progress", tag),
		"Without status, every goal that is not archived; status=all includes archived ones. Active first, then paused, achieved and the "+
			"rest; by priority, target date and name; at most 200."),
		func(ctx context.Context, in *struct {
			Status string `query:"status" enum:"active,paused,achieved,cancelled,archived,all," doc:"Default (empty): all except archived; all: every status"`
		}) (*httpx.Response[[]GoalDTO], error) {
			l, err := s.List(ctx, in.Status)
			if err != nil {
				return nil, err
			}
			return httpx.OK(ctx, l), nil
		})
	httpx.Protected(api, httpx.Created(write(httpx.Op("goals-create", http.MethodPost, "/goals", "Create a goal", tag))),
		func(ctx context.Context, in *struct {
			httpx.IdemHeader
			Body GoalInput
		}) (*httpx.ReplayOutput[GoalDTO], error) {
			g, replayed, err := s.Create(ctx, in.Key, in.Body)
			if err != nil {
				return nil, err
			}
			return httpx.Replay(ctx, *g, replayed), nil
		})
	httpx.Protected(api, httpx.Op("goals-get", http.MethodGet, "/goals/{id}", "Get a goal", tag),
		func(ctx context.Context, in *IDPath) (*httpx.Response[GoalDTO], error) {
			g, err := s.Get(ctx, in.ID)
			if err != nil {
				return nil, err
			}
			return httpx.OK(ctx, *g), nil
		})
	httpx.Protected(api, write(describe(httpx.Op("goals-update", http.MethodPatch, "/goals/{id}",
		"Update a goal (only the fields sent); contributions are never rewritten", tag),
		"Fields that are not sent keep their values (milestones and the starting amount included). Empty strings clear optional text, "+
			"dates and amounts; clear lists optional links to remove (422 when a field is both sent and cleared). version is optional: "+
			"when sent and stale, 409 VERSION_CONFLICT. Sending the full record still works. Owner only.")),
		func(ctx context.Context, in *struct {
			IDPath
			Body GoalPatch
		}) (*httpx.Response[GoalDTO], error) {
			g, err := s.Update(ctx, in.ID, in.Body)
			if err != nil {
				return nil, err
			}
			return httpx.OK(ctx, *g), nil
		})
	httpx.Protected(api, write(describe(httpx.Op("goals-delete", http.MethodDelete, "/goals/{id}", "Archive a goal (history kept)", tag),
		"Allowed from active, paused, achieved or cancelled; the goal becomes archived and leaves the default list (resume reopens it)."+statusRules)),
		func(ctx context.Context, in *VersionedIDPath) (*httpx.Response[GoalDTO], error) {
			g, err := s.SetStatus(ctx, in.ID, "archive", in.Version)
			if err != nil {
				return nil, err
			}
			return httpx.OK(ctx, *g), nil
		})
	statusDocs := map[string]string{
		"pause": "Allowed from active; the goal becomes paused (no contributions or reminders until it is resumed).",
		"resume": "Allowed from paused, cancelled or archived (resume also reopens cancelled and archived goals); the goal becomes active, " +
			"or achieved right away when the saved amount already reaches the target.",
		"achieve": "Allowed from active or paused; the goal becomes achieved (withdrawals are still accepted).",
		"cancel":  "Allowed from active, paused or achieved; the goal becomes cancelled (history kept; resume reopens it).",
	}
	for _, action := range []string{"pause", "resume", "achieve", "cancel"} {
		action := action
		httpx.Protected(api, write(describe(httpx.Op("goals-"+action, http.MethodPost, "/goals/{id}/"+action, action+" a goal", tag), statusDocs[action]+statusRules)),
			func(ctx context.Context, in *VersionedIDPath) (*httpx.Response[GoalDTO], error) {
				g, err := s.SetStatus(ctx, in.ID, action, in.Version)
				if err != nil {
					return nil, err
				}
				return httpx.OK(ctx, *g), nil
			})
	}
	httpx.Protected(api, describe(httpx.Op("goals-contributions-list", http.MethodGet, "/goals/{id}/contributions",
		"Contribution history (each contributor's visibility choice applies)", tag),
		"Newest first, a page at a time (meta.next_cursor / has_more). Contributions someone hides from others are left out "+
			"(they still count in progress)."),
		func(ctx context.Context, in *struct {
			IDPath
			Cursor string `query:"cursor" maxLength:"512"`
			Limit  int    `query:"limit" minimum:"1" maximum:"500" default:"500"`
		}) (*httpx.Response[[]GoalContributionDTO], error) {
			l, next, err := s.ListContributions(ctx, in.ID, in.Cursor, in.Limit)
			if err != nil {
				return nil, err
			}
			return httpx.Page(ctx, l, next), nil
		})
	httpx.Protected(api, httpx.Created(write(describe(httpx.Op("goals-contributions-add", http.MethodPost, "/goals/{id}/contributions",
		"Record a contribution or withdrawal (link a transaction to verify it)", tag),
		"A transaction already backing a contribution answers 409 DUPLICATE with details[0].code transaction_already_counted."))),
		func(ctx context.Context, in *struct {
			IDPath
			httpx.IdemHeader
			Body GoalContributionInput
		}) (*httpx.ReplayOutput[GoalContributionDTO], error) {
			c, replayed, err := s.AddContribution(ctx, in.Key, in.ID, in.Body)
			if err != nil {
				return nil, err
			}
			return httpx.Replay(ctx, *c, replayed), nil
		})
	httpx.Protected(api, write(describe(httpx.Op("goals-contributions-record", http.MethodPost, "/goals/{id}/contributions/{contributionId}/record",
		"Record one of your planned contributions (it is counted once, not added again)", tag),
		"The planned contribution (or planned withdrawal) itself becomes recorded, or verified with transaction_id, so it is counted "+
			"exactly once. Your own planned contributions only (404 otherwise). One that is already recorded answers 409 CONFLICT "+
			"contribution_not_planned (contribution_voided when voided); a transaction already backing a contribution, 409 DUPLICATE "+
			"transaction_already_counted.")),
		func(ctx context.Context, in *struct {
			IDPath
			ContributionID uuid.UUID `path:"contributionId"`
			httpx.IdemHeader
			Body *GoalContributionRecordInput
		}) (*httpx.ReplayOutput[GoalContributionDTO], error) {
			var body GoalContributionRecordInput
			if in.Body != nil {
				body = *in.Body
			}
			c, replayed, err := s.RecordContribution(ctx, in.Key, in.ID, in.ContributionID, body)
			if err != nil {
				return nil, err
			}
			return httpx.Replay(ctx, *c, replayed), nil
		})
	httpx.Protected(api, write(httpx.Op("goals-contributions-void", http.MethodPost, "/goals/{id}/contributions/{contributionId}/void",
		"Void your own contribution (kept in the audit history)", tag)),
		func(ctx context.Context, in *struct {
			IDPath
			ContributionID uuid.UUID `path:"contributionId"`
		}) (*httpx.Response[GoalDTO], error) {
			g, err := s.VoidContribution(ctx, in.ID, in.ContributionID)
			if err != nil {
				return nil, err
			}
			return httpx.OK(ctx, *g), nil
		})
	httpx.Protected(api, httpx.Op("goals-forecast", http.MethodGet, "/goals/{id}/forecast", "Required pace and projected completion with assumptions", tag),
		func(ctx context.Context, in *IDPath) (*httpx.Response[GoalForecast], error) {
			f, err := s.GetForecast(ctx, in.ID)
			if err != nil {
				return nil, err
			}
			return httpx.OK(ctx, *f), nil
		})
	export := describe(httpx.Op("goals-export", http.MethodGet, "/goals/{id}/export", "Download the contribution history as CSV", tag),
		"A text/csv (UTF-8) attachment named goal-contributions-YYYY-MM-DD.csv (your local date). Columns: date, contributor, kind, status, "+
			"amount, currency, share_of_target_percent, voided, note. Each contributor's visibility choice applies, and cells starting with "+
			"=, +, -, @, tab or carriage return are prefixed with ' so spreadsheets do not run them as formulas.")
	export.Responses = map[string]*huma.Response{"200": {Description: "Contribution history as CSV",
		Content: map[string]*huma.MediaType{"text/csv": {Schema: &huma.Schema{Type: huma.TypeString}}}}}
	httpx.Protected(api, export,
		func(ctx context.Context, in *IDPath) (*CSVOutput, error) {
			b, name, err := s.ExportCSV(ctx, in.ID)
			if err != nil {
				return nil, err
			}
			return &CSVOutput{ContentType: "text/csv; charset=utf-8", ContentDisposition: `attachment; filename="` + name + `"`, Body: b}, nil
		})
	httpx.Protected(api, write(describe(httpx.Op("goals-members-add", http.MethodPost, "/goals/{id}/members", "Share with a friend or group member", tag),
		"Owner only. Send ?version= to fail with 409 VERSION_CONFLICT when the goal changed meanwhile.")),
		func(ctx context.Context, in *struct {
			VersionedIDPath
			Body GoalMemberInput
		}) (*httpx.Response[GoalDTO], error) {
			g, err := s.AddMember(ctx, in.ID, in.Version, in.Body)
			if err != nil {
				return nil, err
			}
			return httpx.OK(ctx, *g), nil
		})
	httpx.Protected(api, write(describe(httpx.Op("goals-members-update", http.MethodPatch, "/goals/{id}/members/{userId}",
		"Change a member's role (owner) or your contribution visibility", tag),
		"The owner changes roles; everyone, the owner included (userId = owner_user_id), sets only their own contribution_visibility "+
			"(422 member_controls_visibility otherwise). The owner's role cannot change (422 owner_role_fixed). Send ?version= to fail "+
			"with 409 VERSION_CONFLICT when the goal changed meanwhile.")),
		func(ctx context.Context, in *struct {
			VersionedIDPath
			UserID uuid.UUID `path:"userId"`
			Body   GoalMemberUpdate
		}) (*httpx.Response[GoalDTO], error) {
			g, err := s.UpdateMember(ctx, in.ID, in.UserID, in.Version, in.Body)
			if err != nil {
				return nil, err
			}
			return httpx.OK(ctx, *g), nil
		})
	httpx.Protected(api, write(describe(httpx.Op("goals-members-remove", http.MethodDelete, "/goals/{id}/members/{userId}",
		"Remove a member, or leave (your past contributions stay in the history)", tag),
		"The owner removes anyone; members remove themselves. The owner cannot leave (422 owner_cannot_leave). Send ?version= to fail "+
			"with 409 VERSION_CONFLICT when the goal changed meanwhile.")),
		func(ctx context.Context, in *struct {
			VersionedIDPath
			UserID uuid.UUID `path:"userId"`
		}) (*httpx.Response[httpx.Empty], error) {
			if err := s.RemoveMember(ctx, in.ID, in.UserID, in.Version); err != nil {
				return nil, err
			}
			return httpx.Done(ctx), nil
		})
}
