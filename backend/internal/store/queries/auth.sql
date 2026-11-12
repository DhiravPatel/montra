-- Identity, sessions, tokens, MFA and login throttling.

-- name: InsertUser :exec
insert into users (id, email, email_normalized, date_of_birth_confirmed_adult)
values (@id, @email, @email_normalized, @confirmed_adult);

-- name: GetUser :one
select id, email, email_normalized, email_verified_at, status, platform_role, last_login_at, created_at
from users where id = @id;

-- name: MarkEmailVerified :exec
update users set email_verified_at = coalesce(email_verified_at, now()) where id = @id;

-- name: TouchLogin :exec
update users set last_login_at = now(), status = case when status = 'deactivated' then 'active' else status end,
  deactivated_at = case when status = 'deactivated' then null else deactivated_at end
where id = @id;

-- name: InsertCredential :exec
insert into user_credentials (user_id, password_hash) values (@user_id, @password_hash);

-- name: GetCredential :one
select password_hash from user_credentials where user_id = @user_id;

-- name: UpdatePassword :exec
update user_credentials set password_hash = @password_hash, password_changed_at = now() where user_id = @user_id;

-- name: InsertProfile :exec
insert into profiles (user_id, display_name) values (@user_id, @display_name);

-- name: InsertPreferences :exec
insert into user_preferences (user_id, locale, timezone, base_currency, country)
values (@user_id, @locale, @timezone, @base_currency, sqlc.narg('country'));

-- name: InsertConsent :exec
insert into user_consents (user_id, consent_type, version, client_kind) values (@user_id, @consent_type, @version, @client_kind);

-- name: InsertSession :exec
insert into user_sessions (id, user_id, access_token_hash, access_expires_at, refresh_token_hash, refresh_expires_at,
  absolute_expires_at, client_kind, device_name, user_agent, ip_hash, mfa_verified, last_reauth_at)
values (@id, @user_id, @access_token_hash, @access_expires_at, @refresh_token_hash, @refresh_expires_at,
  @absolute_expires_at, @client_kind, sqlc.narg('device_name'), sqlc.narg('user_agent'), sqlc.narg('ip_hash'), @mfa_verified, now());

-- name: RotateSession :execrows
update user_sessions set access_token_hash = @access_token_hash, access_expires_at = @access_expires_at,
  refresh_token_hash = @refresh_token_hash, refresh_expires_at = @refresh_expires_at, last_seen_at = now()
where id = @id and refresh_token_hash = @old_refresh_hash and revoked_at is null;

-- name: InsertRefreshHistory :exec
insert into user_session_refresh_history (token_hash, session_id, user_id) values (@token_hash, @session_id, @user_id)
on conflict (token_hash) do nothing;

-- name: GetRefreshRotatedAt :one
select rotated_at from user_session_refresh_history where token_hash = @token_hash;

-- name: TouchSession :exec
update user_sessions set last_seen_at = now() where id = @id and last_seen_at < now() - interval '5 minutes';

-- name: SetSessionReauth :exec
update user_sessions set last_reauth_at = now() where id = @id and revoked_at is null;

-- name: RevokeSession :execrows
update user_sessions set revoked_at = now(), revoked_reason = @reason
where id = @id and user_id = @user_id and revoked_at is null;

-- name: RevokeAllSessions :execrows
update user_sessions set revoked_at = now(), revoked_reason = @reason
where user_id = @user_id and revoked_at is null and (sqlc.narg('except_id')::uuid is null or id <> sqlc.narg('except_id')::uuid);

-- name: ListActiveSessions :many
select id, client_kind, device_name, created_at, last_seen_at, mfa_verified, access_expires_at, refresh_expires_at
from user_sessions
where user_id = @user_id and revoked_at is null and refresh_expires_at > now() and absolute_expires_at > now()
order by last_seen_at desc
limit 100;

-- name: InsertAuthToken :exec
insert into auth_tokens (user_id, purpose, token_hash, payload, expires_at) values (@user_id, @purpose, @token_hash, @payload, @expires_at);

-- name: ConsumeAuthToken :execrows
update auth_tokens set consumed_at = now() where id = @id and consumed_at is null and expires_at > now();

-- name: IncrementTokenAttempts :exec
update auth_tokens set attempts = attempts + 1 where id = @id;

-- name: InvalidateTokens :exec
update auth_tokens set consumed_at = now() where user_id = @user_id and purpose = @purpose and consumed_at is null;

-- name: LastTokenCreatedAt :one
select coalesce(max(created_at), 'epoch'::timestamptz)::timestamptz as created_at from auth_tokens where user_id = @user_id and purpose = @purpose;

-- name: InsertLoginAttempt :exec
insert into login_attempts (email_hash, ip_hash, succeeded) values (@email_hash, sqlc.narg('ip_hash'), @succeeded);

-- name: CountRecentFailuresByEmail :one
select count(*) from login_attempts
where email_hash = @email_hash and not succeeded and attempted_at > now() - make_interval(secs => @window_seconds::float8);

-- name: CountRecentFailuresByIP :one
select count(*) from login_attempts
where ip_hash = @ip_hash and not succeeded and attempted_at > now() - make_interval(secs => @window_seconds::float8);

-- name: ClearLoginFailures :exec
delete from login_attempts where email_hash = @email_hash and not succeeded;

-- name: GetActiveMFAFactor :one
select id, secret_ciphertext, key_id, last_used_step from mfa_factors where user_id = @user_id and status = 'active';

-- name: GetPendingMFAFactor :one
select id, secret_ciphertext, key_id from mfa_factors where user_id = @user_id and status = 'pending'
order by created_at desc limit 1;

-- name: InsertMFAFactor :exec
insert into mfa_factors (id, user_id, secret_ciphertext, key_id) values (@id, @user_id, @secret_ciphertext, @key_id);

-- name: DeletePendingMFAFactors :exec
delete from mfa_factors where user_id = @user_id and status = 'pending';

-- name: ActivateMFAFactor :exec
update mfa_factors set status = 'active', activated_at = now(), last_used_step = @last_used_step where id = @id;

-- name: SetMFALastStep :execrows
update mfa_factors set last_used_step = @step where id = @id and (last_used_step is null or last_used_step < @step);

-- name: DisableMFAFactors :exec
update mfa_factors set status = 'disabled', disabled_at = now() where user_id = @user_id and status in ('active','pending');

-- name: DeleteRecoveryCodes :exec
delete from mfa_recovery_codes where user_id = @user_id;

-- name: InsertRecoveryCode :exec
insert into mfa_recovery_codes (user_id, code_hash) values (@user_id, @code_hash);

-- name: UseRecoveryCode :execrows
update mfa_recovery_codes set used_at = now() where user_id = @user_id and code_hash = @code_hash and used_at is null;

-- name: CountUnusedRecoveryCodes :one
select count(*) from mfa_recovery_codes where user_id = @user_id and used_at is null;

-- name: GetAccountSummary :one
select u.id, u.email, u.email_verified_at, u.status, u.platform_role, u.created_at,
       p.display_name, p.username, p.avatar_file_id,
       pr.locale, pr.timezone, pr.base_currency, pr.onboarding_completed_at,
       exists (select 1 from mfa_factors f where f.user_id = u.id and f.status = 'active') as mfa_enabled
from users u
join profiles p on p.user_id = u.id
join user_preferences pr on pr.user_id = u.id
where u.id = @id;
