package auth

import (
	"context"
	"crypto/rand"
	"net/http"
	"strings"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"

	"montra/backend/internal/platform/apperr"
	"montra/backend/internal/platform/audit"
	"montra/backend/internal/platform/crypto"
	"montra/backend/internal/platform/database"
	"montra/backend/internal/platform/identity"
	"montra/backend/internal/platform/jobs"
	"montra/backend/internal/store/db"
)

// MFASetup is returned when TOTP enrollment starts.
type MFASetup struct {
	Secret     string `json:"secret" doc:"Base32 secret for manual entry"`
	OTPAuthURI string `json:"otpauth_uri" doc:"otpauth:// URI for QR codes"`
}

// MFAActivation contains one-time recovery codes.
type MFAActivation struct {
	RecoveryCodes []string `json:"recovery_codes" doc:"Shown once; store them safely"`
}

// StartTOTP creates a pending factor (requires recent re-authentication).
func (s *Service) StartTOTP(ctx context.Context) (*MFASetup, error) {
	p, err := identity.Require(ctx)
	if err != nil {
		return nil, err
	}
	secret, err := crypto.NewTOTPSecret()
	if err != nil {
		return nil, apperr.Internal(err)
	}
	var setup *MFASetup
	err = s.DB.WithUserTx(ctx, p.UserID, func(tx pgx.Tx) error {
		q := db.New(tx)
		if _, err := q.GetActiveMFAFactor(ctx, p.UserID); err == nil {
			return apperr.Conflict("Two-step verification is already enabled.")
		} else if !database.IsNoRows(err) {
			return err
		}
		u, err := q.GetUser(ctx, p.UserID)
		if err != nil {
			return err
		}
		if err := q.DeletePendingMFAFactors(ctx, p.UserID); err != nil {
			return err
		}
		id := uuid.New()
		ct, kid, err := s.Keyring.Encrypt(secret, []byte(id.String()))
		if err != nil {
			return apperr.Internal(err)
		}
		if err := q.InsertMFAFactor(ctx, db.InsertMFAFactorParams{ID: id, UserID: p.UserID, SecretCiphertext: ct, KeyID: kid}); err != nil {
			return err
		}
		setup = &MFASetup{Secret: crypto.TOTPSecretBase32(secret), OTPAuthURI: crypto.TOTPURI(s.Cfg.Auth.MFAIssuer, u.Email, secret)}
		return nil
	})
	return setup, database.MapError(err)
}

// ActivateTOTP verifies the first code, activates the factor and issues
// recovery codes.
func (s *Service) ActivateTOTP(ctx context.Context, code string) (*MFAActivation, error) {
	p, err := identity.Require(ctx)
	if err != nil {
		return nil, err
	}
	var out *MFAActivation
	err = s.DB.WithUserTx(ctx, p.UserID, func(tx pgx.Tx) error {
		q := db.New(tx)
		f, err := q.GetPendingMFAFactor(ctx, p.UserID)
		if database.IsNoRows(err) {
			return apperr.Conflict("Start two-step verification setup first.")
		}
		if err != nil {
			return err
		}
		secret, err := s.Keyring.Decrypt(f.SecretCiphertext, f.KeyID, []byte(f.ID.String()))
		if err != nil {
			return apperr.Internal(err)
		}
		step, ok := crypto.VerifyTOTP(secret, code, s.Now())
		if !ok {
			return apperr.FieldError("body.code", "The verification code is incorrect.")
		}
		st := int64(step)
		if err := q.ActivateMFAFactor(ctx, db.ActivateMFAFactorParams{LastUsedStep: &st, ID: f.ID}); err != nil {
			return err
		}
		codes, err := s.replaceRecoveryCodes(ctx, q, p.UserID)
		if err != nil {
			return err
		}
		out = &MFAActivation{RecoveryCodes: codes}
		if err := audit.Security(ctx, tx, s.ipSalt, audit.SecurityEvent{UserID: &p.UserID, Type: "mfa_enabled", Severity: "warning", SessionID: &p.SessionID}); err != nil {
			return err
		}
		_, _, err = jobs.Enqueue(ctx, tx, jobs.Spec{Type: JobSendSecurityEmail, UserID: &p.UserID, Payload: map[string]string{"template": "mfa_changed", "state": "enabled"}})
		return err
	})
	return out, database.MapError(err)
}

// DisableTOTP turns off MFA. The route requires recent re-authentication;
// a code is needed only when this session has not proved the second factor.
func (s *Service) DisableTOTP(ctx context.Context, code, recovery string) error {
	p, err := identity.Require(ctx)
	if err != nil {
		return err
	}
	return database.MapError(s.DB.WithUserTx(ctx, p.UserID, func(tx pgx.Tx) error {
		q := db.New(tx)
		if code == "" && recovery == "" {
			// The route requires a recent re-authentication; a session that
			// proved the second factor needs no further code.
			if !p.MFAVerified {
				return apperr.New(apperr.CodeMFARequired, http.StatusUnauthorized, "Enter a verification code or a recovery code.")
			}
		} else {
			ok, err := s.checkSecondFactor(ctx, q, p.UserID, code, recovery)
			if err != nil {
				return err
			}
			if !ok {
				return apperr.New(apperr.CodeMFACodeInvalid, http.StatusUnauthorized, "The verification or recovery code is incorrect or already used.")
			}
		}
		if err := q.DisableMFAFactors(ctx, p.UserID); err != nil {
			return err
		}
		if err := q.DeleteRecoveryCodes(ctx, p.UserID); err != nil {
			return err
		}
		if err := audit.Security(ctx, tx, s.ipSalt, audit.SecurityEvent{UserID: &p.UserID, Type: "mfa_disabled", Severity: "warning", SessionID: &p.SessionID}); err != nil {
			return err
		}
		_, _, err = jobs.Enqueue(ctx, tx, jobs.Spec{Type: JobSendSecurityEmail, UserID: &p.UserID, Payload: map[string]string{"template": "mfa_changed", "state": "disabled"}})
		return err
	}))
}

// RegenerateRecoveryCodes replaces all recovery codes.
func (s *Service) RegenerateRecoveryCodes(ctx context.Context) (*MFAActivation, error) {
	p, err := identity.Require(ctx)
	if err != nil {
		return nil, err
	}
	var out *MFAActivation
	err = s.DB.WithUserTx(ctx, p.UserID, func(tx pgx.Tx) error {
		q := db.New(tx)
		if _, err := q.GetActiveMFAFactor(ctx, p.UserID); database.IsNoRows(err) {
			return apperr.Conflict("Two-step verification is not enabled.")
		} else if err != nil {
			return err
		}
		codes, err := s.replaceRecoveryCodes(ctx, q, p.UserID)
		if err != nil {
			return err
		}
		out = &MFAActivation{RecoveryCodes: codes}
		return audit.Security(ctx, tx, s.ipSalt, audit.SecurityEvent{UserID: &p.UserID, Type: "mfa_recovery_regenerated", Severity: "warning"})
	})
	return out, database.MapError(err)
}

const recoveryAlphabet = "abcdefghjkmnpqrstuvwxyz23456789" // no ambiguous characters

func (s *Service) replaceRecoveryCodes(ctx context.Context, q *db.Queries, userID uuid.UUID) ([]string, error) {
	if err := q.DeleteRecoveryCodes(ctx, userID); err != nil {
		return nil, err
	}
	codes := make([]string, 10)
	for i := range codes {
		buf := make([]byte, 10)
		if _, err := rand.Read(buf); err != nil {
			return nil, err
		}
		var b strings.Builder
		for j, c := range buf {
			if j == 5 {
				b.WriteByte('-')
			}
			b.WriteByte(recoveryAlphabet[int(c)%len(recoveryAlphabet)])
		}
		codes[i] = b.String()
		if err := q.InsertRecoveryCode(ctx, db.InsertRecoveryCodeParams{UserID: userID, CodeHash: crypto.HashWithPepper(s.pepper, normalizeRecovery(codes[i]))}); err != nil {
			return nil, err
		}
	}
	return codes, nil
}
