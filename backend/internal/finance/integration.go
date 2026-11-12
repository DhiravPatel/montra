package finance

import (
	"context"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"

	"montra/backend/internal/domain/ledger"
	"montra/backend/internal/platform/apperr"
	"montra/backend/internal/platform/outbox"
)

// ProviderPostInTx marks a pending provider transaction posted once the
// provider confirms it. Pending already counts toward balances, so the
// ledger does not change; the audit trail and events do. It reports
// whether anything changed.
func (s *Service) ProviderPostInTx(ctx context.Context, tx pgx.Tx, uid, id uuid.UUID) (bool, error) {
	t, err := lockTx(ctx, tx, id, uid)
	if err != nil {
		return false, err
	}
	if t.Status != ledger.StatusPending {
		return false, nil
	}
	nv := t.Version + 1
	if _, err := tx.Exec(ctx, `update transactions set status = 'posted', posted_at = coalesce(posted_at, now()), version = $2 where id = $1`,
		id, nv); err != nil {
		return false, err
	}
	if err := txAudit(ctx, tx, uid, id, "integration", "updated", nv, diff{"status": {"from": ledger.StatusPending, "to": ledger.StatusPosted}}); err != nil {
		return false, err
	}
	return true, outbox.Emit(ctx, tx, outbox.Event{Type: "transaction.updated", AggregateType: "transaction", AggregateID: id, UserID: &uid,
		Payload: map[string]any{"account_id": t.AccountID, "local_date": LocalDateString(t.LocalDate), "previous_local_date": LocalDateString(t.LocalDate)}})
}

// ProviderVoidInTx voids a transaction its provider reversed (a declined or
// cancelled charge). Transactions the user has since linked refunds to are
// left alone. It reports whether anything changed.
func (s *Service) ProviderVoidInTx(ctx context.Context, tx pgx.Tx, uid, id uuid.UUID) (bool, error) {
	t, err := lockTx(ctx, tx, id, uid)
	if err != nil {
		return false, err
	}
	if t.Status == ledger.StatusVoided {
		return false, nil
	}
	if t.TransferID != nil || t.Type == ledger.TypeGroupExpense || t.Type == ledger.TypeSettlement {
		return false, apperr.Rule("linked_not_reversible", "Linked transactions are not changed by a provider reversal.", nil)
	}
	var active int
	if err := tx.QueryRow(ctx, `select count(*) from transactions where original_transaction_id = $1 and deleted_at is null`, id).Scan(&active); err != nil {
		return false, err
	}
	if active > 0 {
		return false, apperr.Rule("has_linked_refunds", "This transaction has linked refunds; review it manually.", nil)
	}
	return true, voidRowAs(ctx, tx, uid, t, "integration", map[string]any{"reason": "provider_reversed"})
}
