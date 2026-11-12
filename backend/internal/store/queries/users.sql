-- Profiles, preferences, onboarding and consents (owner-scoped via RLS).

-- name: GetProfile :one
select user_id, display_name, username, avatar_file_id, bio, interests, coarse_location, profile_visibility,
       discoverable_by_username, show_achievements, allow_friend_requests, updated_at
from profiles where user_id = @user_id;

-- name: UpdateProfile :one
update profiles set
  display_name = coalesce(sqlc.narg('display_name'), display_name),
  username = case when @set_username::boolean then sqlc.narg('username') else username end,
  bio = case when @set_bio::boolean then sqlc.narg('bio') else bio end,
  interests = coalesce(sqlc.narg('interests')::text[], interests),
  coarse_location = case when @set_location::boolean then sqlc.narg('coarse_location') else coarse_location end,
  profile_visibility = coalesce(sqlc.narg('profile_visibility'), profile_visibility),
  discoverable_by_username = coalesce(sqlc.narg('discoverable_by_username'), discoverable_by_username),
  show_achievements = coalesce(sqlc.narg('show_achievements'), show_achievements),
  allow_friend_requests = coalesce(sqlc.narg('allow_friend_requests'), allow_friend_requests),
  avatar_file_id = case when @set_avatar::boolean then sqlc.narg('avatar_file_id')::uuid else avatar_file_id end
where user_id = @user_id
returning user_id, display_name, username, avatar_file_id, bio, interests, coarse_location, profile_visibility,
          discoverable_by_username, show_achievements, allow_friend_requests, updated_at;

-- name: GetPreferences :one
select * from user_preferences where user_id = @user_id;

-- name: UpdatePreferences :one
update user_preferences set
  locale = coalesce(sqlc.narg('locale'), locale),
  timezone = coalesce(sqlc.narg('timezone'), timezone),
  base_currency = coalesce(sqlc.narg('base_currency'), base_currency),
  display_currency = case when @set_display_currency::boolean then sqlc.narg('display_currency') else display_currency end,
  country = case when @set_country::boolean then sqlc.narg('country') else country end,
  date_format = coalesce(sqlc.narg('date_format'), date_format),
  number_format = coalesce(sqlc.narg('number_format'), number_format),
  week_start = coalesce(sqlc.narg('week_start')::smallint, week_start),
  month_start_day = coalesce(sqlc.narg('month_start_day')::smallint, month_start_day),
  theme = coalesce(sqlc.narg('theme'), theme),
  reduced_motion = coalesce(sqlc.narg('reduced_motion'), reduced_motion),
  high_contrast = coalesce(sqlc.narg('high_contrast'), high_contrast),
  text_scale_percent = coalesce(sqlc.narg('text_scale_percent')::smallint, text_scale_percent),
  default_date_range = coalesce(sqlc.narg('default_date_range'), default_date_range),
  default_account_id = case when @set_default_account::boolean then sqlc.narg('default_account_id')::uuid else default_account_id end,
  income_range = case when @set_income_range::boolean then sqlc.narg('income_range') else income_range end,
  quiet_hours_enabled = coalesce(sqlc.narg('quiet_hours_enabled'), quiet_hours_enabled),
  quiet_hours_start = coalesce(sqlc.narg('quiet_hours_start')::time, quiet_hours_start),
  quiet_hours_end = coalesce(sqlc.narg('quiet_hours_end')::time, quiet_hours_end),
  email_digest = coalesce(sqlc.narg('email_digest'), email_digest),
  analytics_opt_in = coalesce(sqlc.narg('analytics_opt_in'), analytics_opt_in)
where user_id = @user_id
returning *;

-- name: SetOnboardingState :one
update user_preferences set
  onboarding_state = @onboarding_state,
  onboarding_completed_at = case when @completed::boolean then coalesce(onboarding_completed_at, now()) else onboarding_completed_at end
where user_id = @user_id
returning onboarding_state, onboarding_completed_at;

-- name: AccountOwnedActive :one
select exists (select 1 from financial_accounts where id = @id and user_id = @user_id and status = 'active');

-- name: ListActiveConsents :many
select id, consent_type, version, scope, granted_at, revoked_at from user_consents
where user_id = @user_id and revoked_at is null order by consent_type;

-- name: ListConsentHistory :many
select id, consent_type, version, scope, granted_at, revoked_at from user_consents
where user_id = @user_id order by granted_at desc limit 200;

-- name: RevokeConsent :execrows
update user_consents set revoked_at = now()
where user_id = @user_id and consent_type = @consent_type and revoked_at is null
  and coalesce(scope, '') = coalesce(sqlc.narg('scope'), '');

-- name: GrantConsent :one
insert into user_consents (user_id, consent_type, version, scope, client_kind)
values (@user_id, @consent_type, @version, sqlc.narg('scope'), sqlc.narg('client_kind'))
returning id, consent_type, version, scope, granted_at, revoked_at;

-- name: HasActiveConsent :one
select exists (select 1 from user_consents where user_id = @user_id and consent_type = @consent_type and revoked_at is null);

-- name: SetAIEnabled :exec
update user_preferences set ai_enabled = @enabled where user_id = @user_id;
