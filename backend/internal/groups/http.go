package groups

import (
	"context"
	"net/http"
	"reflect"
	"strings"

	"github.com/danielgtaylor/huma/v2"
	"github.com/google/uuid"

	"montra/backend/internal/platform/apperr"
	"montra/backend/internal/platform/httpx"
	"montra/backend/internal/platform/ratelimit"
)

// IDPath binds {id}.
type IDPath struct {
	ID uuid.UUID `path:"id"`
}

// ExpensePath binds {id} and {expenseId}.
type ExpensePath struct {
	ID        uuid.UUID `path:"id"`
	ExpenseID uuid.UUID `path:"expenseId"`
}

// SettlementPath binds {id} and {settlementId}.
type SettlementPath struct {
	ID           uuid.UUID `path:"id"`
	SettlementID uuid.UUID `path:"settlementId"`
}

// RulePath binds {id} and {ruleId}.
type RulePath struct {
	ID     uuid.UUID `path:"id"`
	RuleID uuid.UUID `path:"ruleId"`
}

// MemberPath binds {id} and {userId}.
type MemberPath struct {
	ID     uuid.UUID `path:"id"`
	UserID uuid.UUID `path:"userId"`
}

// CSVOutput is a CSV download.
type CSVOutput struct {
	ContentType        string `header:"Content-Type"`
	ContentDisposition string `header:"Content-Disposition"`
	Body               []byte
}

// InvitationTokenInput carries a link invitation token in the body so the
// secret never appears in URLs or access logs.
type InvitationTokenInput struct {
	Token string `json:"token" minLength:"16" maxLength:"128"`
}

// JoinRequestInput asks to join a group.
type JoinRequestInput struct {
	Message string `json:"message,omitempty" maxLength:"300"`
}

// AddMemberInput invites a person; they join when they accept.
type AddMemberInput struct {
	Username      string     `json:"username,omitempty" minLength:"3" maxLength:"31" doc:"Someone who opted into username discovery (a leading @ is ignored)"`
	UserID        *uuid.UUID `json:"user_id,omitempty" doc:"One of your friends, found even when they turned username discovery off (anyone else answers 404). Send username or user_id"`
	ExpiresInDays int        `json:"expires_in_days,omitempty" minimum:"1" maximum:"30"`
}

// JoinOutput is the result of accepting an invitation link: 200 with the
// group (joined), or 202 with the pending join request (the group requires
// approval).
type JoinOutput struct {
	Status int
	Body   any
}

func describe(op huma.Operation, description string) huma.Operation {
	op.Description = description
	return op
}

// envelopeRef registers (once) and references the schema of a success
// envelope, for operations that answer with more than one body.
func envelopeRef[T any](api huma.API) *huma.Schema {
	t := reflect.TypeOf(httpx.Envelope[T]{})
	return api.OpenAPI().Components.Schemas.Schema(t, true, t.Name())
}

// TransferOwnershipInput names the new owner.
type TransferOwnershipInput struct {
	UserID uuid.UUID `json:"user_id"`
}

// GroupCommentInput adds a comment.
type GroupCommentInput struct {
	Body string `json:"body" minLength:"1" maxLength:"2000"`
}

// GroupDisputeInput opens a dispute.
type GroupDisputeInput struct {
	Reason string `json:"reason" minLength:"1" maxLength:"1000"`
}

// ResolveDisputeInput resolves or withdraws a dispute.
type ResolveDisputeInput struct {
	Resolution string `json:"resolution,omitempty" maxLength:"1000"`
	Withdraw   bool   `json:"withdraw,omitempty" doc:"The person who raised it withdraws it"`
}

// SettlementActionBody accompanies a settlement action.
type SettlementActionBody struct {
	Version   int32      `json:"version"`
	Reason    string     `json:"reason,omitempty" maxLength:"500" doc:"Required to dispute or void"`
	AccountID *uuid.UUID `json:"account_id,omitempty" doc:"mark-paid / confirm / record: record it in one of your accounts"`
}

// csvName turns a group name into a file-name-safe slug: lower-case ASCII
// letters, digits and single dashes, at most 60 characters ("group" when
// nothing is left).
func csvName(name string) string {
	var b strings.Builder
	dash := false
	for _, r := range strings.ToLower(name) {
		switch {
		case r >= 'a' && r <= 'z', r >= '0' && r <= '9':
			b.WriteRune(r)
			dash = false
		case (r == ' ' || r == '-' || r == '_') && !dash:
			b.WriteRune('-')
			dash = true
		}
	}
	s := strings.Trim(b.String(), "-")
	if len(s) > 60 {
		s = strings.TrimRight(s[:60], "-")
	}
	if s == "" {
		s = "group"
	}
	return s
}

// Routes mounts group endpoints.
func (s *Service) Routes(api huma.API) {
	const tag = "Groups"
	write := func(op huma.Operation) huma.Operation { return httpx.Rate(op, ratelimit.Write.Name) }
	social := func(op huma.Operation) huma.Operation { return httpx.Rate(op, ratelimit.Social.Name) }

	// Groups.
	httpx.Protected(api, describe(httpx.Op("groups-list", http.MethodGet, "/groups", "Your groups, households, trips and events", tag),
		"Each group carries my_net, your balance in the group currency (the same value as my_net in GET /groups/{id}/balances)."),
		func(ctx context.Context, in *struct {
			IncludeArchived bool `query:"include_archived"`
		}) (*httpx.Response[[]GroupDTO], error) {
			l, err := s.List(ctx, in.IncludeArchived)
			if err != nil {
				return nil, err
			}
			return httpx.OK(ctx, l), nil
		})
	httpx.Protected(api, httpx.Created(write(httpx.Op("groups-create", http.MethodPost, "/groups", "Create a group (you become its owner)", tag))),
		func(ctx context.Context, in *struct{ Body GroupInput }) (*httpx.Response[GroupDetail], error) {
			g, err := s.Create(ctx, in.Body)
			if err != nil {
				return nil, err
			}
			return httpx.OK(ctx, *g), nil
		})
	httpx.Protected(api, httpx.Op("groups-get", http.MethodGet, "/groups/{id}", "A group with its members", tag),
		func(ctx context.Context, in *IDPath) (*httpx.Response[GroupDetail], error) {
			g, err := s.Get(ctx, in.ID)
			if err != nil {
				return nil, err
			}
			return httpx.OK(ctx, *g), nil
		})
	httpx.Protected(api, write(describe(httpx.Op("groups-update", http.MethodPatch, "/groups/{id}",
		"Update settings (admins; the currency is fixed once expenses exist)", tag),
		"Changes only the fields sent; the others keep their values. Text fields and dates are cleared with an empty string. version is "+
			"required (409 VERSION_CONFLICT when stale). Changing base_currency after expenses, settlements or recurring bills exist answers "+
			"422 currency_locked; an archived group answers 409 group_archived.")),
		func(ctx context.Context, in *struct {
			IDPath
			Body GroupPatch
		}) (*httpx.Response[GroupDetail], error) {
			g, err := s.Update(ctx, in.ID, in.Body)
			if err != nil {
				return nil, err
			}
			return httpx.OK(ctx, *g), nil
		})
	httpx.Protected(api, write(httpx.Op("groups-delete", http.MethodDelete, "/groups/{id}",
		"Delete a group (owner; balances must be settled; records stay in members' history)", tag)),
		func(ctx context.Context, in *struct {
			IDPath
			Confirm bool `query:"confirm" doc:"Must be true: deleting a group cannot be undone"`
		}) (*httpx.Response[GroupDTO], error) {
			if !in.Confirm {
				return nil, apperr.FieldError("query.confirm", "Confirm that you want to delete this group.")
			}
			g, err := s.SetStatus(ctx, in.ID, "delete")
			if err != nil {
				return nil, err
			}
			return httpx.OK(ctx, *g), nil
		})
	for _, action := range []string{"archive", "restore"} {
		action := action
		httpx.Protected(api, write(describe(httpx.Op("groups-"+action, http.MethodPost, "/groups/{id}/"+action,
			map[string]string{"archive": "Archive a group (owner; read-only until restored)", "restore": "Restore an archived group (owner)"}[action], tag),
			map[string]string{"archive": "Pauses its recurring bills. Archiving an archived group answers 409 group_archived; while archived, changes answer 409 group_archived.",
				"restore": "Restoring a group that is not archived answers 409 group_not_archived."}[action])),
			func(ctx context.Context, in *IDPath) (*httpx.Response[GroupDTO], error) {
				g, err := s.SetStatus(ctx, in.ID, action)
				if err != nil {
					return nil, err
				}
				return httpx.OK(ctx, *g), nil
			})
	}

	// Invitations and joining.
	httpx.Protected(api, httpx.Op("groups-invitations-list", http.MethodGet, "/groups/{id}/invitations", "Invitations (admins: all; members: yours)", tag),
		func(ctx context.Context, in *struct {
			IDPath
			IncludeInactive bool `query:"include_inactive"`
		}) (*httpx.Response[[]GroupInvitationDTO], error) {
			l, err := s.Invitations(ctx, in.ID, in.IncludeInactive)
			if err != nil {
				return nil, err
			}
			return httpx.OK(ctx, l), nil
		})
	httpx.Protected(api, httpx.Created(social(describe(httpx.Op("groups-invitations-create", http.MethodPost, "/groups/{id}/invitations",
		"Invite by username or create a link (the link token is shown once)", tag),
		"kind username invites one person: by username (people who opted into username discovery) or by user_id (your friends, even when "+
			"they turned discovery off); anyone else answers 404 like an unknown user. Inviting a member answers 409 already_member. "+
			"A username invitation always joins directly when accepted; a link joins directly unless the group requires join approval."))),
		func(ctx context.Context, in *struct {
			IDPath
			Body GroupInvitationInput
		}) (*httpx.Response[GroupInvitationDTO], error) {
			inv, err := s.Invite(ctx, in.ID, in.Body)
			if err != nil {
				return nil, err
			}
			return httpx.OK(ctx, *inv), nil
		})
	httpx.Protected(api, write(describe(httpx.Op("groups-invitations-revoke", http.MethodDelete, "/groups/{id}/invitations/{invitationId}",
		"Revoke an invitation", tag), "Admins, or the member who created it. Revoking twice is harmless; an accepted or declined invitation "+
		"answers 409 invitation_used.")),
		func(ctx context.Context, in *struct {
			IDPath
			InvitationID uuid.UUID `path:"invitationId"`
		}) (*httpx.Response[httpx.Empty], error) {
			if err := s.RevokeInvitation(ctx, in.ID, in.InvitationID); err != nil {
				return nil, err
			}
			return httpx.Done(ctx), nil
		})
	httpx.Protected(api, httpx.Op("group-invitations-mine", http.MethodGet, "/group-invitations", "Invitations addressed to you", tag),
		func(ctx context.Context, _ *struct{}) (*httpx.Response[[]GroupInvitationDTO], error) {
			l, err := s.MyInvitations(ctx)
			if err != nil {
				return nil, err
			}
			return httpx.OK(ctx, l), nil
		})
	httpx.Protected(api, httpx.Errs(social(describe(httpx.Op("group-invitations-preview", http.MethodPost, "/group-invitations/preview",
		"See which group an invitation link is for", tag),
		"Returns the group (ID, name, type, active member count), who created the link (display name; username only when they are discoverable "+
			"or connected to you), whether you are already a member and whether joining needs the admins' approval. An unknown token, or a "+
			"link between people who blocked each other, answers 410.")), http.StatusGone),
		func(ctx context.Context, in *struct{ Body InvitationTokenInput }) (*httpx.Response[GroupInvitationPreview], error) {
			p, err := s.Preview(ctx, in.Body.Token)
			if err != nil {
				return nil, err
			}
			return httpx.OK(ctx, *p), nil
		})
	acceptLink := httpx.Errs(social(describe(httpx.Op("group-invitations-accept-link", http.MethodPost, "/group-invitations/accept",
		"Join with an invitation link token", tag),
		"200 with the group when you joined. When the group requires join approval, 202 with your pending join request instead (it "+
			"counts as one use of the link): the admins are notified and you join when one approves it. Already a member: 409 already_member; "+
			"a request already waiting: 409 join_request_pending; an expired, used-up or unknown link: 410.")), http.StatusGone)
	acceptLink.Responses = map[string]*huma.Response{
		"200": {Description: "Joined", Content: map[string]*huma.MediaType{"application/json": {Schema: envelopeRef[GroupDetail](api)}}},
		"202": {Description: "The group requires approval: join request created",
			Content: map[string]*huma.MediaType{"application/json": {Schema: envelopeRef[GroupJoinRequestDTO](api)}}},
	}
	httpx.Protected(api, acceptLink,
		func(ctx context.Context, in *struct{ Body InvitationTokenInput }) (*JoinOutput, error) {
			if _, err := uuid.Parse(in.Body.Token); err == nil {
				return nil, apperr.FieldError("body.token", "This is not an invitation link token.")
			}
			g, req, err := s.AcceptLink(ctx, in.Body.Token)
			if err != nil {
				return nil, err
			}
			if req != nil {
				return &JoinOutput{Status: http.StatusAccepted, Body: httpx.OK(ctx, *req).Body}, nil
			}
			return &JoinOutput{Status: http.StatusOK, Body: httpx.OK(ctx, *g).Body}, nil
		})
	httpx.Protected(api, httpx.Errs(social(describe(httpx.Op("group-invitations-accept", http.MethodPost, "/group-invitations/{invitationId}/accept",
		"Accept an invitation addressed to you", tag),
		"Joins directly, also when the group requires join approval (the invitation names you). Already a member: 409 already_member; "+
			"already accepted or declined: 409 invitation_used; expired, revoked or the group is no longer active: 410.")), http.StatusGone),
		func(ctx context.Context, in *struct {
			InvitationID uuid.UUID `path:"invitationId"`
		}) (*httpx.Response[GroupDetail], error) {
			g, err := s.AcceptInvitation(ctx, in.InvitationID)
			if err != nil {
				return nil, err
			}
			return httpx.OK(ctx, *g), nil
		})
	httpx.Protected(api, httpx.Errs(social(describe(httpx.Op("group-invitations-decline", http.MethodPost, "/group-invitations/{invitationId}/decline",
		"Decline an invitation addressed to you", tag),
		"Already accepted or declined: 409 invitation_used; expired or revoked: 410.")), http.StatusGone),
		func(ctx context.Context, in *struct {
			InvitationID uuid.UUID `path:"invitationId"`
		}) (*httpx.Response[httpx.Empty], error) {
			if err := s.DeclineInvitation(ctx, in.InvitationID); err != nil {
				return nil, err
			}
			return httpx.Done(ctx), nil
		})
	httpx.Protected(api, httpx.Created(social(describe(httpx.Op("groups-join-requests-create", http.MethodPost, "/groups/{id}/join-requests",
		"Ask to join a group (admins approve)", tag),
		"Already a member: 409 already_member; a request already waiting: 409 join_request_pending."))),
		func(ctx context.Context, in *struct {
			IDPath
			Body JoinRequestInput
		}) (*httpx.Response[GroupJoinRequestDTO], error) {
			r, err := s.RequestToJoin(ctx, in.ID, in.Body.Message)
			if err != nil {
				return nil, err
			}
			return httpx.OK(ctx, *r), nil
		})
	httpx.Protected(api, httpx.Op("groups-join-requests-list", http.MethodGet, "/groups/{id}/join-requests", "Pending join requests (admins)", tag),
		func(ctx context.Context, in *IDPath) (*httpx.Response[[]GroupJoinRequestDTO], error) {
			l, err := s.JoinRequests(ctx, in.ID)
			if err != nil {
				return nil, err
			}
			return httpx.OK(ctx, l), nil
		})
	for _, action := range []string{"approve", "decline"} {
		action := action
		httpx.Protected(api, write(httpx.Op("groups-join-requests-"+action, http.MethodPost, "/groups/{id}/join-requests/{requestId}/"+action,
			map[string]string{"approve": "Approve a join request (admins)", "decline": "Decline a join request (admins)"}[action], tag)),
			func(ctx context.Context, in *struct {
				IDPath
				RequestID uuid.UUID `path:"requestId"`
			}) (*httpx.Response[GroupDetail], error) {
				g, err := s.DecideJoinRequest(ctx, in.ID, in.RequestID, action == "approve")
				if err != nil {
					return nil, err
				}
				return httpx.OK(ctx, *g), nil
			})
	}

	// Members.
	httpx.Protected(api, httpx.Created(social(describe(httpx.Op("groups-members-add", http.MethodPost, "/groups/{id}/members",
		"Add someone by username or, for a friend, by user ID (they join when they accept the invitation)", tag),
		"Creates a username invitation. username finds people who opted into username discovery; user_id finds your friends even when they "+
			"turned discovery off. Anyone else answers 404 like an unknown user; a member answers 409 already_member."))),
		func(ctx context.Context, in *struct {
			IDPath
			Body AddMemberInput
		}) (*httpx.Response[GroupInvitationDTO], error) {
			inv, err := s.Invite(ctx, in.ID, GroupInvitationInput{Kind: "username", Username: in.Body.Username, UserID: in.Body.UserID,
				ExpiresInDays: in.Body.ExpiresInDays})
			if err != nil {
				return nil, err
			}
			return httpx.OK(ctx, *inv), nil
		})
	httpx.Protected(api, write(httpx.Op("groups-members-update", http.MethodPatch, "/groups/{id}/members/{userId}",
		"Change a role (admins) or your own notification level", tag)),
		func(ctx context.Context, in *struct {
			MemberPath
			Body GroupMemberUpdate
		}) (*httpx.Response[GroupDetail], error) {
			g, err := s.UpdateMember(ctx, in.ID, in.UserID, in.Body)
			if err != nil {
				return nil, err
			}
			return httpx.OK(ctx, *g), nil
		})
	httpx.Protected(api, write(describe(httpx.Op("groups-members-remove", http.MethodDelete, "/groups/{id}/members/{userId}",
		"Remove a member (admins) or leave (yourself; settle your balance first)", tag),
		"Leaving needs a zero balance (422 balance_open); the owner transfers ownership first (422 transfer_ownership_first). Admins may "+
			"remove a member whose balance is open. Removed-member balance policy: the removed member loses access at once, but their "+
			"expenses, shares and settlements stay in the records. Their balance keeps counting: it stays in GET /groups/{id}/balances "+
			"(member_status removed, under their name at removal), in original_debts and simplified, in settlement suggestions and in reports. "+
			"Any member can record a settlement with them: a payment they make is confirmed by the member who received it, and a payment to "+
			"them is confirmed by an admin on their behalf (they can no longer confirm it; verification stays user_reported). Their recurring "+
			"bills are paused for the admins.")),
		func(ctx context.Context, in *MemberPath) (*httpx.Response[httpx.Empty], error) {
			if err := s.RemoveMember(ctx, in.ID, in.UserID); err != nil {
				return nil, err
			}
			return httpx.Done(ctx), nil
		})
	httpx.Protected(api, write(httpx.Op("groups-transfer-ownership", http.MethodPost, "/groups/{id}/transfer-ownership",
		"Make another member the owner (you become an admin)", tag)),
		func(ctx context.Context, in *struct {
			IDPath
			Body TransferOwnershipInput
		}) (*httpx.Response[GroupDetail], error) {
			g, err := s.TransferOwnership(ctx, in.ID, in.Body.UserID)
			if err != nil {
				return nil, err
			}
			return httpx.OK(ctx, *g), nil
		})

	// Expenses.
	httpx.Protected(api, describe(httpx.Op("groups-expenses-list", http.MethodGet, "/groups/{id}/expenses", "Shared expenses, newest first", tag),
		"Pages newest first (expense date, then creation) with cursor and limit (default 50, at most 200); meta.next_cursor and "+
			"meta.has_more say whether more exist. Send the same filters with each page."),
		func(ctx context.Context, in *struct {
			IDPath
			IncludeDeleted bool   `query:"include_deleted" doc:"Also list deleted expenses (ignored when status is set)"`
			Status         string `query:"status" enum:"active,disputed,deleted," doc:"Only expenses with this status"`
			From           string `query:"from" doc:"YYYY-MM-DD: expense date on or after"`
			To             string `query:"to" doc:"YYYY-MM-DD: expense date on or before"`
			PayerUserID    string `query:"payer_user_id" format:"uuid" doc:"Only expenses this member paid, in full or in part"`
			CategoryKey    string `query:"category_key" pattern:"^([a-z_]{2,40})?$" doc:"Only this category; uncategorized for expenses without one (as in the report)"`
			Cursor         string `query:"cursor" maxLength:"512"`
			Limit          int    `query:"limit" minimum:"1" maximum:"200" default:"50"`
		}) (*httpx.Response[[]GroupExpenseDTO], error) {
			f := ExpenseFilter{Status: in.Status, IncludeDeleted: in.IncludeDeleted, CategoryKey: in.CategoryKey}
			var err error
			if f.From, f.To, err = reportRange(in.From, in.To); err != nil {
				return nil, err
			}
			if in.PayerUserID != "" {
				id, err := uuid.Parse(in.PayerUserID)
				if err != nil {
					return nil, apperr.FieldError("query.payer_user_id", "Invalid member.")
				}
				f.PayerUserID = &id
			}
			l, next, err := s.ListExpenses(ctx, in.ID, f, in.Cursor, in.Limit)
			if err != nil {
				return nil, err
			}
			return httpx.Page(ctx, l, next), nil
		})
	httpx.Protected(api, httpx.Created(write(describe(httpx.Op("groups-expenses-create", http.MethodPost, "/groups/{id}/expenses",
		"Add a shared expense (exact split in minor units; idempotent)", tag),
		"Foreign currency: send original_amount, original_currency and a rate. amount may then be left out: it is original_amount × fx_rate "+
			"rounded half away from zero to the group currency (as GET /fx/convert does) and is returned. fx_rate_source says where the rate "+
			"came from: manual (typed; default) or lookup (Montra's rate for the expense date; fx_rate may be left out). The expense keeps "+
			"the rate's real source (manual, ecb or provider) and fx_rate_at. No Montra rate for the date: 422 fx_rate_unavailable. "+
			"An archived group answers 409 group_archived."))),
		func(ctx context.Context, in *struct {
			IDPath
			httpx.IdemHeader
			Body GroupExpenseInput
		}) (*httpx.ReplayOutput[GroupExpenseDetail], error) {
			e, replayed, err := s.CreateExpense(ctx, in.Key, in.ID, in.Body)
			if err != nil {
				return nil, err
			}
			return httpx.Replay(ctx, *e, replayed), nil
		})
	httpx.Protected(api, httpx.Op("groups-expenses-get", http.MethodGet, "/groups/{id}/expenses/{expenseId}",
		"An expense with items, comments, disputes and edit-history count", tag),
		func(ctx context.Context, in *ExpensePath) (*httpx.Response[GroupExpenseDetail], error) {
			e, err := s.GetExpense(ctx, in.ID, in.ExpenseID)
			if err != nil {
				return nil, err
			}
			return httpx.OK(ctx, *e), nil
		})
	httpx.Protected(api, write(describe(httpx.Op("groups-expenses-update", http.MethodPatch, "/groups/{id}/expenses/{expenseId}",
		"Edit an expense (send the full expense with its version; history is kept)", tag),
		"Rates follow the create rules; an edit that keeps the original amount, currency, rate and date keeps the stored fx_rate_source. "+
			"A deleted expense answers 409 expense_deleted.")),
		func(ctx context.Context, in *struct {
			ExpensePath
			Body GroupExpenseInput
		}) (*httpx.Response[GroupExpenseDetail], error) {
			e, err := s.UpdateExpense(ctx, in.ID, in.ExpenseID, in.Body)
			if err != nil {
				return nil, err
			}
			return httpx.OK(ctx, *e), nil
		})
	httpx.Protected(api, write(httpx.Op("groups-expenses-delete", http.MethodDelete, "/groups/{id}/expenses/{expenseId}",
		"Delete an expense (its creator or admins; history is kept)", tag)),
		func(ctx context.Context, in *ExpensePath) (*httpx.Response[httpx.Empty], error) {
			if err := s.DeleteExpense(ctx, in.ID, in.ExpenseID); err != nil {
				return nil, err
			}
			return httpx.Done(ctx), nil
		})
	httpx.Protected(api, httpx.Created(write(httpx.Op("groups-expenses-comment", http.MethodPost, "/groups/{id}/expenses/{expenseId}/comments",
		"Comment on an expense", tag))),
		func(ctx context.Context, in *struct {
			ExpensePath
			Body GroupCommentInput
		}) (*httpx.Response[GroupCommentDTO], error) {
			c, err := s.Comment(ctx, in.ID, in.ExpenseID, in.Body.Body)
			if err != nil {
				return nil, err
			}
			return httpx.OK(ctx, *c), nil
		})
	httpx.Protected(api, httpx.Created(write(httpx.Op("groups-expenses-dispute", http.MethodPost, "/groups/{id}/expenses/{expenseId}/disputes",
		"Dispute an expense", tag))),
		func(ctx context.Context, in *struct {
			ExpensePath
			Body GroupDisputeInput
		}) (*httpx.Response[GroupDisputeDTO], error) {
			d, err := s.Dispute(ctx, in.ID, in.ExpenseID, in.Body.Reason)
			if err != nil {
				return nil, err
			}
			return httpx.OK(ctx, *d), nil
		})
	httpx.Protected(api, write(httpx.Op("groups-disputes-resolve", http.MethodPost, "/groups/{id}/disputes/{disputeId}/resolve",
		"Resolve (admins or the person who raised it) or withdraw a dispute", tag)),
		func(ctx context.Context, in *struct {
			IDPath
			DisputeID uuid.UUID `path:"disputeId"`
			Body      ResolveDisputeInput
		}) (*httpx.Response[httpx.Empty], error) {
			if err := s.ResolveDispute(ctx, in.ID, in.DisputeID, in.Body.Resolution, in.Body.Withdraw); err != nil {
				return nil, err
			}
			return httpx.Done(ctx), nil
		})
	httpx.Protected(api, write(describe(httpx.Op("groups-expenses-my-record", http.MethodPost, "/groups/{id}/expenses/{expenseId}/my-record",
		"Record your payment in one of your accounts, or remove that record (only your share counts as your spending)", tag),
		"link on a deleted expense: 409 expense_deleted; already recorded: 409 expense_already_recorded.")),
		func(ctx context.Context, in *struct {
			ExpensePath
			Body ExpenseRecordInput
		}) (*httpx.Response[GroupExpenseDetail], error) {
			e, err := s.ExpensePersonalRecord(ctx, in.ID, in.ExpenseID, in.Body)
			if err != nil {
				return nil, err
			}
			return httpx.OK(ctx, *e), nil
		})

	// Recurring shared expenses (household bills).
	httpx.Protected(api, httpx.Op("groups-recurring-list", http.MethodGet, "/groups/{id}/recurring-expenses",
		"Recurring shared expenses (rent, utilities) with recent and upcoming occurrences", tag),
		func(ctx context.Context, in *IDPath) (*httpx.Response[[]GroupRecurringDTO], error) {
			l, err := s.ListRecurring(ctx, in.ID)
			if err != nil {
				return nil, err
			}
			return httpx.OK(ctx, l), nil
		})
	httpx.Protected(api, httpx.Created(write(httpx.Op("groups-recurring-create", http.MethodPost, "/groups/{id}/recurring-expenses",
		"Create a recurring shared expense (added automatically or by a member when due; idempotent)", tag))),
		func(ctx context.Context, in *struct {
			IDPath
			httpx.IdemHeader
			Body GroupRecurringInput
		}) (*httpx.ReplayOutput[GroupRecurringDTO], error) {
			r, replayed, err := s.CreateRecurring(ctx, in.Key, in.ID, in.Body)
			if err != nil {
				return nil, err
			}
			return httpx.Replay(ctx, *r, replayed), nil
		})
	httpx.Protected(api, httpx.Op("groups-recurring-get", http.MethodGet, "/groups/{id}/recurring-expenses/{ruleId}", "A recurring shared expense", tag),
		func(ctx context.Context, in *RulePath) (*httpx.Response[GroupRecurringDTO], error) {
			r, err := s.GetRecurring(ctx, in.ID, in.RuleID)
			if err != nil {
				return nil, err
			}
			return httpx.OK(ctx, *r), nil
		})
	httpx.Protected(api, write(httpx.Op("groups-recurring-update", http.MethodPatch, "/groups/{id}/recurring-expenses/{ruleId}",
		"Change the name, amount, split or auto-add (its creator or admins; open occurrences take the new amount)", tag)),
		func(ctx context.Context, in *struct {
			RulePath
			Body GroupRecurringUpdate
		}) (*httpx.Response[GroupRecurringDTO], error) {
			r, err := s.UpdateRecurring(ctx, in.ID, in.RuleID, in.Body)
			if err != nil {
				return nil, err
			}
			return httpx.OK(ctx, *r), nil
		})
	for _, action := range []string{"pause", "resume", "stop"} {
		action := action
		httpx.Protected(api, write(httpx.Op("groups-recurring-"+action, http.MethodPost, "/groups/{id}/recurring-expenses/{ruleId}/"+action,
			map[string]string{"pause": "Pause a recurring shared expense", "resume": "Resume it (no back-filling)", "stop": "Stop it (history kept)"}[action], tag)),
			func(ctx context.Context, in *RulePath) (*httpx.Response[GroupRecurringDTO], error) {
				r, err := s.SetRecurringStatus(ctx, in.ID, in.RuleID, action)
				if err != nil {
					return nil, err
				}
				return httpx.OK(ctx, *r), nil
			})
	}
	httpx.Protected(api, httpx.Created(write(describe(httpx.Op("groups-recurring-occurrence-add", http.MethodPost,
		"/groups/{id}/recurring-expenses/{ruleId}/occurrences/{occurrenceId}/add", "Add this occurrence's expense now (any active member; idempotent)", tag),
		"Whoever adds it pays unless the split names payers. Already added or skipped: 409 occurrence_already_handled (params.status). "+
			"When someone who shares or pays it is no longer a member: 422 recurring_member_inactive (params.user_id); another problem with "+
			"the stored split: 422 recurring_template_invalid (params.field). Edit the recurring expense, then add it."))),
		func(ctx context.Context, in *struct {
			RulePath
			OccurrenceID uuid.UUID `path:"occurrenceId"`
			httpx.IdemHeader
		}) (*httpx.ReplayOutput[GroupExpenseDetail], error) {
			e, replayed, err := s.AddOccurrence(ctx, in.Key, in.ID, in.RuleID, in.OccurrenceID)
			if err != nil {
				return nil, err
			}
			return httpx.Replay(ctx, *e, replayed), nil
		})
	httpx.Protected(api, write(describe(httpx.Op("groups-recurring-occurrence-skip", http.MethodPost,
		"/groups/{id}/recurring-expenses/{ruleId}/occurrences/{occurrenceId}/skip", "Skip one occurrence (its creator or admins)", tag),
		"Already added or skipped: 409 occurrence_already_handled (params.status).")),
		func(ctx context.Context, in *struct {
			RulePath
			OccurrenceID uuid.UUID `path:"occurrenceId"`
		}) (*httpx.Response[GroupRecurringDTO], error) {
			r, err := s.SkipOccurrence(ctx, in.ID, in.RuleID, in.OccurrenceID)
			if err != nil {
				return nil, err
			}
			return httpx.OK(ctx, *r), nil
		})

	// Balances and settlements.
	httpx.Protected(api, httpx.Op("groups-balances", http.MethodGet, "/groups/{id}/balances",
		"Balances derived from expenses and confirmed settlements, with original and simplified debts", tag),
		func(ctx context.Context, in *IDPath) (*httpx.Response[GroupBalancesDTO], error) {
			b, err := s.Balances(ctx, in.ID)
			if err != nil {
				return nil, err
			}
			return httpx.OK(ctx, *b), nil
		})
	httpx.Protected(api, httpx.Op("groups-settlement-suggestions", http.MethodGet, "/groups/{id}/settlement-suggestions",
		"Suggested payments (never changes records; not a payment)", tag),
		func(ctx context.Context, in *struct {
			IDPath
			Mine bool `query:"mine" doc:"Only suggestions involving you"`
		}) (*httpx.Response[GroupSuggestionsDTO], error) {
			sg, err := s.Suggestions(ctx, in.ID, in.Mine)
			if err != nil {
				return nil, err
			}
			return httpx.OK(ctx, *sg), nil
		})
	httpx.Protected(api, httpx.Op("groups-settlements-list", http.MethodGet, "/groups/{id}/settlements", "Settlements, newest first", tag),
		func(ctx context.Context, in *struct {
			IDPath
			IncludeVoided bool `query:"include_voided"`
		}) (*httpx.Response[[]SettlementDTO], error) {
			l, err := s.ListSettlements(ctx, in.ID, in.IncludeVoided)
			if err != nil {
				return nil, err
			}
			return httpx.OK(ctx, l), nil
		})
	httpx.Protected(api, httpx.Created(write(httpx.Op("groups-settlements-create", http.MethodPost, "/groups/{id}/settlements",
		"Record an off-app payment or propose one (user-reported; idempotent)", tag))),
		func(ctx context.Context, in *struct {
			IDPath
			httpx.IdemHeader
			Body SettlementInput
		}) (*httpx.ReplayOutput[SettlementDTO], error) {
			x, replayed, err := s.CreateSettlement(ctx, in.Key, in.ID, in.Body)
			if err != nil {
				return nil, err
			}
			return httpx.Replay(ctx, *x, replayed), nil
		})
	httpx.Protected(api, httpx.Op("groups-settlements-get", http.MethodGet, "/groups/{id}/settlements/{settlementId}", "A settlement", tag),
		func(ctx context.Context, in *SettlementPath) (*httpx.Response[SettlementDTO], error) {
			x, err := s.GetSettlement(ctx, in.ID, in.SettlementID)
			if err != nil {
				return nil, err
			}
			return httpx.OK(ctx, *x), nil
		})
	actions := []struct{ path, action, summary, description string }{
		{"mark-paid", "mark_paid", "Payer: mark a proposed settlement as paid",
			"Not proposed: 409 settlement_not_proposed (params.status); voided: 409 settlement_voided."},
		{"confirm", "confirm", "Payee: confirm you received the payment (it then counts toward balances)",
			"When the payee is no longer a member (removed or left), an admin confirms on their behalf (confirmed_by is the admin; " +
				"verification stays user_reported). Not proposed, reported or disputed: 409 settlement_not_confirmable (params.status); " +
				"voided: 409 settlement_voided."},
		{"dispute", "dispute", "Dispute a reported or confirmed settlement",
			"Not reported or confirmed: 409 settlement_not_disputable (params.status); voided: 409 settlement_voided."},
		{"void", "void", "Void a settlement with a reason (either party or an admin)", "Already voided: 409 settlement_voided."},
		{"record", "record_personal", "Record this settlement in one of your accounts (never income or spending)",
			"Already recorded: 409 settlement_already_recorded; voided: 409 settlement_voided."},
		{"unlink", "unlink_personal", "Remove your account record of this settlement", ""},
	}
	for _, a := range actions {
		a := a
		httpx.Protected(api, write(describe(httpx.Op("groups-settlements-"+a.path, http.MethodPost, "/groups/{id}/settlements/{settlementId}/"+a.path,
			a.summary, tag), a.description)),
			func(ctx context.Context, in *struct {
				SettlementPath
				Body SettlementActionBody
			}) (*httpx.Response[SettlementDTO], error) {
				x, err := s.ActOnSettlement(ctx, in.ID, in.SettlementID, SettlementActionInput{Action: a.action, Version: in.Body.Version,
					Reason: in.Body.Reason, AccountID: in.Body.AccountID})
				if err != nil {
					return nil, err
				}
				return httpx.OK(ctx, *x), nil
			})
	}
	httpx.Protected(api, httpx.Created(write(describe(httpx.Op("groups-settlements-correct", http.MethodPost,
		"/groups/{id}/settlements/{settlementId}/correct", "Replace a settlement with a corrected one (the original is voided and kept; idempotent)", tag),
		"A voided settlement answers 409 settlement_voided (record a new one instead)."))),
		func(ctx context.Context, in *struct {
			SettlementPath
			httpx.IdemHeader
			Body SettlementInput
		}) (*httpx.ReplayOutput[SettlementDTO], error) {
			x, replayed, err := s.CorrectSettlement(ctx, in.Key, in.ID, in.SettlementID, in.Body)
			if err != nil {
				return nil, err
			}
			return httpx.Replay(ctx, *x, replayed), nil
		})

	// Activity, reports, export.
	httpx.Protected(api, describe(httpx.Op("groups-activity", http.MethodGet, "/groups/{id}/activity", "Activity history, newest first", tag),
		"kind is one of the listed values; summary carries the event's parameters (codes, IDs and names members typed, never amounts or "+
			"English text), so clients build the sentence from kind and summary."),
		func(ctx context.Context, in *struct {
			IDPath
			Before int64 `query:"before" minimum:"0" doc:"next_before from the previous page"`
		}) (*httpx.Response[GroupActivityPage], error) {
			p, err := s.Activity(ctx, in.ID, in.Before)
			if err != nil {
				return nil, err
			}
			return httpx.OK(ctx, *p), nil
		})
	httpx.Protected(api, httpx.Op("groups-reports", http.MethodGet, "/groups/{id}/reports",
		"Group report: totals by category, member and month, trip summary and settlement plan", tag),
		func(ctx context.Context, in *struct {
			IDPath
			From string `query:"from" doc:"YYYY-MM-DD"`
			To   string `query:"to" doc:"YYYY-MM-DD"`
		}) (*httpx.Response[GroupReportDTO], error) {
			r, err := s.Report(ctx, in.ID, in.From, in.To)
			if err != nil {
				return nil, err
			}
			return httpx.OK(ctx, *r), nil
		})
	export := httpx.Rate(describe(httpx.Op("groups-export", http.MethodGet, "/groups/{id}/export", "Download expenses and settlements as CSV", tag),
		"A text/csv (UTF-8 with a byte order mark) attachment named <group>-expenses-YYYY-MM-DD.csv: the group name in lower-case ASCII "+
			"letters, digits and dashes (\"group\" when none are left) and the group's local date. One row per expense (deleted ones "+
			"included, with their status), then one per settlement. Columns: record (expense or settlement), date, description, category, "+
			"amount, currency, original_amount, original_currency, fx_rate, split_method, paid_by, shares, status. Cells starting with =, +, "+
			"-, @, tab or carriage return are prefixed with ' so spreadsheets do not run them as formulas. Members only; never personal "+
			"account data."), ratelimit.Export.Name)
	export.Responses = map[string]*huma.Response{"200": {Description: "Expenses and settlements as CSV",
		Content: map[string]*huma.MediaType{"text/csv": {Schema: &huma.Schema{Type: huma.TypeString}}}}}
	httpx.Protected(api, export,
		func(ctx context.Context, in *IDPath) (*CSVOutput, error) {
			b, name, err := s.ExportCSV(ctx, in.ID)
			if err != nil {
				return nil, err
			}
			return &CSVOutput{ContentType: "text/csv; charset=utf-8", ContentDisposition: `attachment; filename="` + name + `"`, Body: b}, nil
		})
}
