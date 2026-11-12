// Package users manages the signed-in user's profile, preferences,
// onboarding and consents (spec §4.1, §4.20, §20B.2). Changing base currency
// or timezone never rewrites historical transaction amounts or dates.
package users

import (
	"context"
	"encoding/json"
	"fmt"
	"net/http"
	"regexp"
	"strings"
	"time"
	"unicode/utf8"

	"github.com/danielgtaylor/huma/v2"
	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgtype"

	"montra/backend/internal/auth"
	"montra/backend/internal/domain/currency"
	"montra/backend/internal/platform/apperr"
	"montra/backend/internal/platform/audit"
	"montra/backend/internal/platform/database"
	"montra/backend/internal/platform/httpx"
	"montra/backend/internal/platform/identity"
	"montra/backend/internal/store/db"
)

// Service implements the /me endpoints.
type Service struct {
	DB   *database.DB
	Auth *auth.Service
}

// ProfileDTO is the user's own profile.
type ProfileDTO struct {
	DisplayName            string     `json:"display_name"`
	Username               *string    `json:"username,omitempty"`
	AvatarFileID           *uuid.UUID `json:"avatar_file_id,omitempty"`
	Bio                    *string    `json:"bio,omitempty"`
	Interests              []string   `json:"interests"`
	CoarseLocation         *string    `json:"coarse_location,omitempty"`
	ProfileVisibility      string     `json:"profile_visibility" enum:"private,connections,public"`
	DiscoverableByUsername bool       `json:"discoverable_by_username"`
	ShowAchievements       bool       `json:"show_achievements"`
	AllowFriendRequests    string     `json:"allow_friend_requests" enum:"everyone,friends_of_friends,nobody"`
	UpdatedAt              time.Time  `json:"updated_at"`
}

// PreferencesDTO mirrors user_preferences.
type PreferencesDTO struct {
	Locale              string     `json:"locale"`
	Timezone            string     `json:"timezone"`
	BaseCurrency        string     `json:"base_currency"`
	DisplayCurrency     *string    `json:"display_currency,omitempty"`
	Country             *string    `json:"country,omitempty"`
	DateFormat          string     `json:"date_format" enum:"locale,dmy,mdy,ymd"`
	NumberFormat        string     `json:"number_format" enum:"locale,indian,international"`
	WeekStart           int16      `json:"week_start" minimum:"0" maximum:"6" doc:"0 = Sunday"`
	MonthStartDay       int16      `json:"month_start_day" minimum:"1" maximum:"28"`
	Theme               string     `json:"theme" enum:"system,light,dark"`
	ReducedMotion       bool       `json:"reduced_motion"`
	HighContrast        bool       `json:"high_contrast"`
	TextScalePercent    int16      `json:"text_scale_percent"`
	DefaultDateRange    string     `json:"default_date_range"`
	DefaultAccountID    *uuid.UUID `json:"default_account_id,omitempty"`
	IncomeRange         *string    `json:"income_range,omitempty" enum:"prefer_not_to_say,under_25k,25k_50k,50k_1l,1l_2l,2l_5l,above_5l" doc:"Monthly take-home income in INR (k = thousand, l = lakh); optional and never shared"`
	QuietHoursEnabled   bool       `json:"quiet_hours_enabled"`
	QuietHoursStart     string     `json:"quiet_hours_start" doc:"HH:MM in the user's timezone"`
	QuietHoursEnd       string     `json:"quiet_hours_end"`
	EmailDigest         string     `json:"email_digest" enum:"off,daily,weekly"`
	AIEnabled           bool       `json:"ai_enabled" doc:"Change via /ai/preferences (requires consent)"`
	AnalyticsOptIn      bool       `json:"analytics_opt_in"`
	OnboardingCompleted bool       `json:"onboarding_completed"`
	UpdatedAt           time.Time  `json:"updated_at"`
}

// MeDTO is the combined account view.
type MeDTO struct {
	Account     auth.UserDTO   `json:"account"`
	Profile     ProfileDTO     `json:"profile"`
	Preferences PreferencesDTO `json:"preferences"`
}

func toProfile(r db.GetProfileRow) ProfileDTO {
	if r.Interests == nil {
		r.Interests = []string{}
	}
	return ProfileDTO{DisplayName: r.DisplayName, Username: r.Username, AvatarFileID: r.AvatarFileID, Bio: r.Bio,
		Interests: r.Interests, CoarseLocation: r.CoarseLocation, ProfileVisibility: r.ProfileVisibility,
		DiscoverableByUsername: r.DiscoverableByUsername, ShowAchievements: r.ShowAchievements,
		AllowFriendRequests: r.AllowFriendRequests, UpdatedAt: r.UpdatedAt}
}

func fmtTime(t pgtype.Time) string {
	if !t.Valid {
		return ""
	}
	m := t.Microseconds / 60_000_000
	return fmt.Sprintf("%02d:%02d", m/60, m%60)
}

func parseHHMM(field, s string) (pgtype.Time, error) {
	t, err := time.Parse("15:04", s)
	if err != nil {
		return pgtype.Time{}, apperr.FieldError(field, "Use 24-hour HH:MM.")
	}
	return pgtype.Time{Microseconds: int64(t.Hour()*60+t.Minute()) * 60_000_000, Valid: true}, nil
}

func toPrefs(p db.UserPreference) PreferencesDTO {
	return PreferencesDTO{Locale: p.Locale, Timezone: p.Timezone, BaseCurrency: p.BaseCurrency, DisplayCurrency: p.DisplayCurrency,
		Country: p.Country, DateFormat: p.DateFormat, NumberFormat: p.NumberFormat, WeekStart: p.WeekStart,
		MonthStartDay: p.MonthStartDay, Theme: p.Theme, ReducedMotion: p.ReducedMotion, HighContrast: p.HighContrast,
		TextScalePercent: p.TextScalePercent, DefaultDateRange: p.DefaultDateRange, DefaultAccountID: p.DefaultAccountID,
		IncomeRange: p.IncomeRange, QuietHoursEnabled: p.QuietHoursEnabled, QuietHoursStart: fmtTime(p.QuietHoursStart),
		QuietHoursEnd: fmtTime(p.QuietHoursEnd), EmailDigest: p.EmailDigest, AIEnabled: p.AiEnabled,
		AnalyticsOptIn: p.AnalyticsOptIn, OnboardingCompleted: p.OnboardingCompletedAt != nil, UpdatedAt: p.UpdatedAt}
}

// Me returns the account, profile and preferences.
func (s *Service) Me(ctx context.Context) (*MeDTO, error) {
	uid, err := identity.UserID(ctx)
	if err != nil {
		return nil, err
	}
	acct, err := s.Auth.AccountSummary(ctx)
	if err != nil {
		return nil, err
	}
	out := &MeDTO{Account: *acct}
	err = s.DB.WithUserReadTx(ctx, uid, func(tx pgx.Tx) error {
		q := db.New(tx)
		p, err := q.GetProfile(ctx, uid)
		if err != nil {
			return err
		}
		pr, err := q.GetPreferences(ctx, uid)
		if err != nil {
			return err
		}
		out.Profile, out.Preferences = toProfile(p), toPrefs(pr)
		return nil
	})
	return out, database.MapError(err)
}

// ProfilePatch updates profile fields; absent fields are unchanged.
type ProfilePatch struct {
	DisplayName            *string   `json:"display_name,omitempty" minLength:"1" maxLength:"80"`
	Username               *string   `json:"username,omitempty" maxLength:"31" doc:"3-30 of a-z 0-9 _ . (empty string clears); a leading @ is ignored, as in search"`
	Bio                    *string   `json:"bio,omitempty" maxLength:"280"`
	Interests              *[]string `json:"interests,omitempty" maxItems:"10" doc:"Up to 10, each up to 40 characters (422 too_long {max} on body.interests[i]); blank items are dropped"`
	CoarseLocation         *string   `json:"coarse_location,omitempty" maxLength:"80"`
	ProfileVisibility      *string   `json:"profile_visibility,omitempty" enum:"private,connections,public"`
	DiscoverableByUsername *bool     `json:"discoverable_by_username,omitempty"`
	ShowAchievements       *bool     `json:"show_achievements,omitempty"`
	AllowFriendRequests    *string   `json:"allow_friend_requests,omitempty" enum:"everyone,friends_of_friends,nobody"`
	AvatarFileID           *string   `json:"avatar_file_id,omitempty" doc:"A ready image you uploaded with purpose avatar (POST /files/upload-intent); empty string removes the avatar. The file is not deleted"`
}

var usernameRe = regexp.MustCompile(`^[a-z0-9_.]{3,30}$`)

// reservedUsernames cannot be claimed (impersonation protection).
var reservedUsernames = map[string]bool{"admin": true, "support": true, "montra": true, "security": true, "moderator": true,
	"help": true, "official": true, "staff": true, "system": true, "root": true}

// UpdateProfile applies a profile patch.
func (s *Service) UpdateProfile(ctx context.Context, in ProfilePatch) (*ProfileDTO, error) {
	uid, err := identity.UserID(ctx)
	if err != nil {
		return nil, err
	}
	params := db.UpdateProfileParams{UserID: uid, ProfileVisibility: in.ProfileVisibility, DiscoverableByUsername: in.DiscoverableByUsername,
		ShowAchievements: in.ShowAchievements, AllowFriendRequests: in.AllowFriendRequests}
	if in.DisplayName != nil {
		n := strings.TrimSpace(*in.DisplayName)
		if n == "" {
			return nil, apperr.FieldCode("body.display_name", "required", "Display name cannot be blank.", nil)
		}
		params.DisplayName = &n
	}
	if in.Username != nil {
		params.SetUsername = true
		// A leading @ is ignored, as in search and friend requests; "@" alone
		// is not a way to clear the username (send "" for that).
		raw := strings.TrimSpace(*in.Username)
		u := strings.ToLower(strings.TrimPrefix(raw, "@"))
		if raw != "" {
			if !usernameRe.MatchString(u) {
				return nil, apperr.FieldCode("body.username", "username_invalid", "Use 3-30 lowercase letters, digits, '_' or '.'.", nil)
			}
			if reservedUsernames[u] || strings.HasPrefix(u, "montra") {
				return nil, apperr.FieldCode("body.username", "username_reserved", "This username is reserved.", nil)
			}
			params.Username = &u
		}
	}
	if in.Bio != nil {
		params.SetBio = true
		if b := strings.TrimSpace(*in.Bio); b != "" {
			params.Bio = &b
		}
	}
	if in.CoarseLocation != nil {
		params.SetLocation = true
		if l := strings.TrimSpace(*in.CoarseLocation); l != "" {
			params.CoarseLocation = &l
		}
	}
	if in.Interests != nil {
		clean := []string{}
		for i, it := range *in.Interests {
			if it = strings.TrimSpace(it); it == "" {
				continue
			}
			// 40 characters (not bytes), so Hindi interests get the same room.
			if utf8.RuneCountInString(it) > 40 {
				return nil, apperr.FieldCode(fmt.Sprintf("body.interests[%d]", i), "too_long", "Keep each interest to 40 characters.",
					map[string]string{"max": "40"})
			}
			clean = append(clean, it)
		}
		params.Interests = clean
	}
	var avatar *uuid.UUID
	if in.AvatarFileID != nil && *in.AvatarFileID != "" {
		id, perr := uuid.Parse(*in.AvatarFileID)
		if perr != nil {
			return nil, apperr.FieldError("body.avatar_file_id", "Send the ID of an uploaded avatar image.")
		}
		avatar = &id
	}
	var out ProfileDTO
	err = s.DB.WithUserTx(ctx, uid, func(tx pgx.Tx) error {
		if in.AvatarFileID != nil {
			if avatar != nil {
				// Only your own finished avatar upload (owner RLS hides others').
				var ok bool
				if err := tx.QueryRow(ctx, `select exists (select 1 from files where id = $1 and owner_user_id = $2 and purpose = 'avatar' and status = 'ready')`,
					*avatar, uid).Scan(&ok); err != nil {
					return err
				}
				if !ok {
					return apperr.FieldCode("body.avatar_file_id", "avatar_file_invalid",
						"Upload the image with purpose avatar and finish the upload first.", nil)
				}
			}
			if _, err := tx.Exec(ctx, `update profiles set avatar_file_id = $2 where user_id = $1`, uid, avatar); err != nil {
				return err
			}
		}
		r, err := db.New(tx).UpdateProfile(ctx, params)
		if err != nil {
			return err
		}
		out = toProfile(db.GetProfileRow(r))
		return audit.Record(ctx, tx, audit.Event{UserID: &uid, ActorUserID: &uid, EntityType: "profile", EntityID: &uid, Action: "updated",
			Changes: map[string]any{"fields": changedProfileFields(in)}})
	})
	if database.IsUniqueViolation(err, "profiles_username_key") {
		return nil, apperr.New(apperr.CodeConflict, http.StatusConflict, "That username is taken.").WithDetails(apperr.Detail{Field: "body.username",
			Code: "username_taken", Message: "That username is taken."})
	}
	return &out, database.MapError(err)
}

func changedProfileFields(p ProfilePatch) []string {
	var f []string
	add := func(ok bool, name string) {
		if ok {
			f = append(f, name)
		}
	}
	add(p.DisplayName != nil, "display_name")
	add(p.Username != nil, "username")
	add(p.Bio != nil, "bio")
	add(p.Interests != nil, "interests")
	add(p.CoarseLocation != nil, "coarse_location")
	add(p.ProfileVisibility != nil, "profile_visibility")
	add(p.DiscoverableByUsername != nil, "discoverable_by_username")
	add(p.ShowAchievements != nil, "show_achievements")
	add(p.AllowFriendRequests != nil, "allow_friend_requests")
	add(p.AvatarFileID != nil, "avatar_file_id")
	return f
}

// PreferencesPatch updates preferences; absent fields are unchanged.
type PreferencesPatch struct {
	Locale            *string    `json:"locale,omitempty" maxLength:"10"`
	Timezone          *string    `json:"timezone,omitempty" maxLength:"64"`
	BaseCurrency      *string    `json:"base_currency,omitempty" pattern:"^[A-Z]{3}$"`
	DisplayCurrency   *string    `json:"display_currency,omitempty" doc:"ISO code; empty string clears"`
	Country           *string    `json:"country,omitempty" doc:"ISO 3166-1 alpha-2; empty clears"`
	DateFormat        *string    `json:"date_format,omitempty" enum:"locale,dmy,mdy,ymd"`
	NumberFormat      *string    `json:"number_format,omitempty" enum:"locale,indian,international"`
	WeekStart         *int16     `json:"week_start,omitempty" minimum:"0" maximum:"6"`
	MonthStartDay     *int16     `json:"month_start_day,omitempty" minimum:"1" maximum:"28"`
	Theme             *string    `json:"theme,omitempty" enum:"system,light,dark"`
	ReducedMotion     *bool      `json:"reduced_motion,omitempty"`
	HighContrast      *bool      `json:"high_contrast,omitempty"`
	TextScalePercent  *int16     `json:"text_scale_percent,omitempty" minimum:"80" maximum:"200"`
	DefaultDateRange  *string    `json:"default_date_range,omitempty" enum:"today,yesterday,this_week,this_month,this_year,last_7_days,last_30_days,last_90_days"`
	DefaultAccountID  *uuid.UUID `json:"default_account_id,omitempty"`
	ClearDefaultAcct  bool       `json:"clear_default_account,omitempty"`
	IncomeRange       *string    `json:"income_range,omitempty" enum:"prefer_not_to_say,under_25k,25k_50k,50k_1l,1l_2l,2l_5l,above_5l" doc:"Monthly take-home income in INR (k = thousand, l = lakh); optional"`
	QuietHoursEnabled *bool      `json:"quiet_hours_enabled,omitempty"`
	QuietHoursStart   *string    `json:"quiet_hours_start,omitempty" pattern:"^[0-2][0-9]:[0-5][0-9]$"`
	QuietHoursEnd     *string    `json:"quiet_hours_end,omitempty" pattern:"^[0-2][0-9]:[0-5][0-9]$"`
	EmailDigest       *string    `json:"email_digest,omitempty" enum:"off,daily,weekly"`
	AnalyticsOptIn    *bool      `json:"analytics_opt_in,omitempty"`
}

// UpdatePreferences validates and applies preference changes.
func (s *Service) UpdatePreferences(ctx context.Context, in PreferencesPatch) (*PreferencesDTO, error) {
	uid, err := identity.UserID(ctx)
	if err != nil {
		return nil, err
	}
	p := db.UpdatePreferencesParams{UserID: uid, Locale: in.Locale, DateFormat: in.DateFormat, NumberFormat: in.NumberFormat,
		WeekStart: in.WeekStart, MonthStartDay: in.MonthStartDay, Theme: in.Theme, ReducedMotion: in.ReducedMotion,
		HighContrast: in.HighContrast, TextScalePercent: in.TextScalePercent, DefaultDateRange: in.DefaultDateRange,
		QuietHoursEnabled: in.QuietHoursEnabled, EmailDigest: in.EmailDigest, AnalyticsOptIn: in.AnalyticsOptIn}
	if in.Locale != nil && !validLocale(*in.Locale) {
		return nil, apperr.FieldError("body.locale", "Unsupported locale.")
	}
	if in.Timezone != nil {
		if _, err := time.LoadLocation(*in.Timezone); err != nil || *in.Timezone == "Local" || *in.Timezone == "" {
			return nil, apperr.FieldError("body.timezone", "Unknown time zone.")
		}
		p.Timezone = in.Timezone
	}
	if in.BaseCurrency != nil {
		if !currency.Selectable(*in.BaseCurrency) {
			return nil, apperr.FieldError("body.base_currency", "Unsupported currency.")
		}
		p.BaseCurrency = in.BaseCurrency
	}
	if in.DisplayCurrency != nil {
		p.SetDisplayCurrency = true
		if *in.DisplayCurrency != "" {
			if !currency.Selectable(*in.DisplayCurrency) {
				return nil, apperr.FieldError("body.display_currency", "Unsupported currency.")
			}
			p.DisplayCurrency = in.DisplayCurrency
		}
	}
	if in.Country != nil {
		p.SetCountry = true
		if *in.Country != "" {
			if len(*in.Country) != 2 || strings.ToUpper(*in.Country) != *in.Country {
				return nil, apperr.FieldError("body.country", "Use an ISO 3166-1 alpha-2 code.")
			}
			p.Country = in.Country
		}
	}
	if in.IncomeRange != nil {
		p.SetIncomeRange = true
		p.IncomeRange = in.IncomeRange
	}
	if in.QuietHoursStart != nil {
		if p.QuietHoursStart, err = parseHHMM("body.quiet_hours_start", *in.QuietHoursStart); err != nil {
			return nil, err
		}
	}
	if in.QuietHoursEnd != nil {
		if p.QuietHoursEnd, err = parseHHMM("body.quiet_hours_end", *in.QuietHoursEnd); err != nil {
			return nil, err
		}
	}
	var out PreferencesDTO
	err = s.DB.WithUserTx(ctx, uid, func(tx pgx.Tx) error {
		q := db.New(tx)
		if in.ClearDefaultAcct {
			p.SetDefaultAccount = true
		} else if in.DefaultAccountID != nil {
			ok, err := q.AccountOwnedActive(ctx, db.AccountOwnedActiveParams{ID: *in.DefaultAccountID, UserID: uid})
			if err != nil {
				return err
			}
			if !ok {
				return apperr.FieldError("body.default_account_id", "Choose one of your active accounts.")
			}
			p.SetDefaultAccount = true
			p.DefaultAccountID = in.DefaultAccountID
		}
		r, err := q.UpdatePreferences(ctx, p)
		if err != nil {
			return err
		}
		out = toPrefs(r)
		return audit.Record(ctx, tx, audit.Event{UserID: &uid, ActorUserID: &uid, EntityType: "preferences", EntityID: &uid, Action: "updated"})
	})
	return &out, database.MapError(err)
}

func validLocale(l string) bool {
	lang, region, hasRegion := strings.Cut(l, "-")
	if len(lang) < 2 || len(lang) > 3 || strings.ToLower(lang) != lang {
		return false
	}
	return !hasRegion || (len(region) == 2 && strings.ToUpper(region) == region)
}

// OnboardingInput records onboarding progress. Every step is optional.
type OnboardingInput struct {
	CompletedSteps []string `json:"completed_steps" maxItems:"20" doc:"e.g. welcome, privacy, country, currency, timezone, income, goals, accounts, categories"`
	SkippedSteps   []string `json:"skipped_steps" maxItems:"20"`
	Complete       bool     `json:"complete" doc:"Mark onboarding finished (bank linking is never required)"`
}

// OnboardingDTO is the onboarding state.
type OnboardingDTO struct {
	CompletedSteps []string   `json:"completed_steps"`
	SkippedSteps   []string   `json:"skipped_steps"`
	CompletedAt    *time.Time `json:"completed_at,omitempty"`
}

var onboardingSteps = map[string]bool{"welcome": true, "privacy": true, "country": true, "currency": true, "timezone": true,
	"income": true, "goals": true, "accounts": true, "categories": true, "notifications": true}

// RecordOnboarding stores onboarding progress.
func (s *Service) RecordOnboarding(ctx context.Context, in OnboardingInput) (*OnboardingDTO, error) {
	uid, err := identity.UserID(ctx)
	if err != nil {
		return nil, err
	}
	for _, st := range append(append([]string{}, in.CompletedSteps...), in.SkippedSteps...) {
		if !onboardingSteps[st] {
			return nil, apperr.FieldError("body.completed_steps", "Unknown onboarding step: "+st)
		}
	}
	var out OnboardingDTO
	err = s.DB.WithUserTx(ctx, uid, func(tx pgx.Tx) error {
		// Progress merges with what was stored: a step once completed stays
		// completed; a skipped step becomes completed when finished later.
		cur, err := loadOnboarding(ctx, tx, uid, true)
		if err != nil {
			return err
		}
		completed := mergeSteps(cur.CompletedSteps, in.CompletedSteps, nil)
		skipped := mergeSteps(cur.SkippedSteps, in.SkippedSteps, completed)
		state, _ := json.Marshal(map[string]any{"completed_steps": completed, "skipped_steps": skipped})
		r, err := db.New(tx).SetOnboardingState(ctx, db.SetOnboardingStateParams{OnboardingState: state, Completed: in.Complete, UserID: uid})
		if err != nil {
			return err
		}
		out = OnboardingDTO{CompletedSteps: completed, SkippedSteps: skipped, CompletedAt: r.OnboardingCompletedAt}
		return nil
	})
	return &out, database.MapError(err)
}

// mergeSteps returns a ∪ b in first-seen order, without steps in exclude.
func mergeSteps(a, b, exclude []string) []string {
	skip := map[string]bool{}
	for _, x := range exclude {
		skip[x] = true
	}
	out := []string{}
	seen := map[string]bool{}
	for _, x := range append(append([]string{}, a...), b...) {
		if !seen[x] && !skip[x] {
			seen[x] = true
			out = append(out, x)
		}
	}
	return out
}

func loadOnboarding(ctx context.Context, tx pgx.Tx, uid uuid.UUID, lock bool) (*OnboardingDTO, error) {
	q := `select onboarding_state, onboarding_completed_at from user_preferences where user_id = $1`
	if lock {
		q += ` for update`
	}
	var raw []byte
	out := &OnboardingDTO{CompletedSteps: []string{}, SkippedSteps: []string{}}
	if err := tx.QueryRow(ctx, q, uid).Scan(&raw, &out.CompletedAt); err != nil {
		return nil, err
	}
	var st struct {
		Completed []string `json:"completed_steps"`
		Skipped   []string `json:"skipped_steps"`
	}
	if len(raw) > 0 && json.Unmarshal(raw, &st) == nil {
		for _, x := range st.Completed {
			if onboardingSteps[x] {
				out.CompletedSteps = append(out.CompletedSteps, x)
			}
		}
		for _, x := range st.Skipped {
			if onboardingSteps[x] {
				out.SkippedSteps = append(out.SkippedSteps, x)
			}
		}
	}
	return out, nil
}

// Onboarding returns the stored progress so clients can resume setup.
func (s *Service) Onboarding(ctx context.Context) (*OnboardingDTO, error) {
	uid, err := identity.UserID(ctx)
	if err != nil {
		return nil, err
	}
	var out *OnboardingDTO
	err = s.DB.WithUserReadTx(ctx, uid, func(tx pgx.Tx) error {
		var err error
		out, err = loadOnboarding(ctx, tx, uid, false)
		return err
	})
	return out, database.MapError(err)
}

// ConsentDTO is a consent record.
type ConsentDTO struct {
	ID          uuid.UUID  `json:"id"`
	ConsentType string     `json:"consent_type"`
	Version     string     `json:"version"`
	Scope       *string    `json:"scope,omitempty"`
	GrantedAt   time.Time  `json:"granted_at"`
	RevokedAt   *time.Time `json:"revoked_at,omitempty"`
}

// Consent types users manage directly (terms/privacy are recorded at sign-up).
var grantable = map[string]string{
	"ai_processing": "2026-11-01", "ai_receipt_processing": "2026-11-01", "marketing_email": "2026-11-01",
	"product_analytics": "2026-11-01", "location": "2026-11-01", "contacts_discovery": "2026-11-01",
	"push_notifications": "2026-11-01", "terms": auth.TermsVersion, "privacy_policy": auth.PrivacyVersion,
}

// CurrentConsentVersion returns the version users must accept for a type.
func CurrentConsentVersion(t string) (string, bool) { v, ok := grantable[t]; return v, ok }

// consentOrder is the published order of consent types.
var consentOrder = []string{"terms", "privacy_policy", "ai_processing", "ai_receipt_processing", "marketing_email", "product_analytics",
	"location", "contacts_discovery", "push_notifications"}

// ConsentVersionDTO is the current wording version of one consent type.
type ConsentVersionDTO struct {
	Type     string `json:"type" enum:"terms,privacy_policy,ai_processing,ai_receipt_processing,marketing_email,product_analytics,location,contacts_discovery,push_notifications"`
	Version  string `json:"version" doc:"Send this version in POST /me/consents"`
	Required bool   `json:"required" doc:"Accepted at sign-up and cannot be revoked (terms and privacy policy)"`
}

// LegalDTO is what GET /legal publishes: the document versions a new
// account accepts and the current version of every consent type.
type LegalDTO struct {
	TermsVersion   string              `json:"terms_version"`
	PrivacyVersion string              `json:"privacy_version"`
	Consents       []ConsentVersionDTO `json:"consents"`
}

// Legal returns the current legal and consent versions.
func Legal() LegalDTO {
	out := LegalDTO{TermsVersion: auth.TermsVersion, PrivacyVersion: auth.PrivacyVersion}
	for _, t := range consentOrder {
		out.Consents = append(out.Consents, ConsentVersionDTO{Type: t, Version: grantable[t], Required: t == "terms" || t == "privacy_policy"})
	}
	return out
}

// ListConsents lists consents (active, or full history).
func (s *Service) ListConsents(ctx context.Context, history bool) ([]ConsentDTO, error) {
	uid, err := identity.UserID(ctx)
	if err != nil {
		return nil, err
	}
	out := []ConsentDTO{}
	err = s.DB.WithUserReadTx(ctx, uid, func(tx pgx.Tx) error {
		q := db.New(tx)
		if history {
			rows, err := q.ListConsentHistory(ctx, uid)
			for _, r := range rows {
				out = append(out, ConsentDTO(r))
			}
			return err
		}
		rows, err := q.ListActiveConsents(ctx, uid)
		for _, r := range rows {
			out = append(out, ConsentDTO(r))
		}
		return err
	})
	return out, database.MapError(err)
}

// GrantConsent records consent (replacing an active consent of the same type).
func (s *Service) GrantConsent(ctx context.Context, consentType, version string, scope *string) (*ConsentDTO, error) {
	p, err := identity.Require(ctx)
	if err != nil {
		return nil, err
	}
	want, ok := grantable[consentType]
	if !ok || consentType == "integration" {
		return nil, apperr.FieldError("body.consent_type", "This consent type cannot be granted here.")
	}
	if version != want {
		msg := "Review the latest version (" + want + ") before consenting."
		return nil, apperr.Validation("", apperr.Detail{Field: "body.version", Code: "consent_version_outdated", Message: msg,
			Params: map[string]string{"version": want}})
	}
	var out ConsentDTO
	err = s.DB.WithUserTx(ctx, p.UserID, func(tx pgx.Tx) error {
		q := db.New(tx)
		if _, err := q.RevokeConsent(ctx, db.RevokeConsentParams{UserID: p.UserID, ConsentType: consentType, Scope: scope}); err != nil {
			return err
		}
		ck := p.ClientKind
		r, err := q.GrantConsent(ctx, db.GrantConsentParams{UserID: p.UserID, ConsentType: consentType, Version: version, Scope: scope, ClientKind: &ck})
		if err != nil {
			return err
		}
		out = ConsentDTO(r)
		return audit.Record(ctx, tx, audit.Event{UserID: &p.UserID, ActorUserID: &p.UserID, EntityType: "consent", EntityID: &r.ID, Action: "granted",
			Changes: map[string]any{"consent_type": consentType, "version": version}})
	})
	return &out, database.MapError(err)
}

// RevokeConsent revokes a consent. Revoking AI consent also disables AI.
func (s *Service) RevokeConsent(ctx context.Context, consentType string, scope *string) error {
	uid, err := identity.UserID(ctx)
	if err != nil {
		return err
	}
	if consentType == "terms" || consentType == "privacy_policy" {
		return apperr.Rule("required_consent", "Terms and privacy consent are required to use Montra. To withdraw, request account deletion.", nil)
	}
	return database.MapError(s.DB.WithUserTx(ctx, uid, func(tx pgx.Tx) error {
		q := db.New(tx)
		n, err := q.RevokeConsent(ctx, db.RevokeConsentParams{UserID: uid, ConsentType: consentType, Scope: scope})
		if err != nil {
			return err
		}
		if n == 0 {
			return apperr.NotFound("consent")
		}
		if consentType == "ai_processing" {
			if err := q.SetAIEnabled(ctx, db.SetAIEnabledParams{Enabled: false, UserID: uid}); err != nil {
				return err
			}
		}
		return audit.Record(ctx, tx, audit.Event{UserID: &uid, ActorUserID: &uid, EntityType: "consent", Action: "revoked",
			Changes: map[string]any{"consent_type": consentType}})
	}))
}

// Routes mounts the endpoints.
func (s *Service) Routes(api huma.API) {
	const tag = "Profile & preferences"
	httpx.Protected(api, httpx.Op("me-get", http.MethodGet, "/me", "Get account, profile and preferences", tag),
		func(ctx context.Context, _ *struct{}) (*httpx.Response[MeDTO], error) {
			me, err := s.Me(ctx)
			if err != nil {
				return nil, err
			}
			return httpx.OK(ctx, *me), nil
		})
	httpx.Protected(api, httpx.Op("me-update", http.MethodPatch, "/me", "Update profile", tag),
		func(ctx context.Context, in *struct{ Body ProfilePatch }) (*httpx.Response[ProfileDTO], error) {
			p, err := s.UpdateProfile(ctx, in.Body)
			if err != nil {
				return nil, err
			}
			return httpx.OK(ctx, *p), nil
		})
	httpx.Protected(api, httpx.Op("me-preferences-get", http.MethodGet, "/me/preferences", "Get preferences", tag),
		func(ctx context.Context, _ *struct{}) (*httpx.Response[PreferencesDTO], error) {
			me, err := s.Me(ctx)
			if err != nil {
				return nil, err
			}
			return httpx.OK(ctx, me.Preferences), nil
		})
	httpx.Protected(api, httpx.Op("me-preferences-update", http.MethodPatch, "/me/preferences", "Update preferences", tag),
		func(ctx context.Context, in *struct{ Body PreferencesPatch }) (*httpx.Response[PreferencesDTO], error) {
			p, err := s.UpdatePreferences(ctx, in.Body)
			if err != nil {
				return nil, err
			}
			return httpx.OK(ctx, *p), nil
		})
	httpx.Protected(api, httpx.Op("me-onboarding-get", http.MethodGet, "/me/onboarding", "Onboarding progress (to resume setup)", tag),
		func(ctx context.Context, _ *struct{}) (*httpx.Response[OnboardingDTO], error) {
			o, err := s.Onboarding(ctx)
			if err != nil {
				return nil, err
			}
			return httpx.OK(ctx, *o), nil
		})
	httpx.Protected(api, httpx.Op("me-onboarding", http.MethodPost, "/me/onboarding",
		"Record onboarding progress; steps merge with what was stored (all steps skippable)", tag),
		func(ctx context.Context, in *struct{ Body OnboardingInput }) (*httpx.Response[OnboardingDTO], error) {
			o, err := s.RecordOnboarding(ctx, in.Body)
			if err != nil {
				return nil, err
			}
			return httpx.OK(ctx, *o), nil
		})
	const ctag = "Privacy"
	httpx.Public(api, httpx.Op("legal-versions", http.MethodGet, "/legal",
		"Current terms and privacy policy versions (accepted at sign-up) and the current version of every consent type", "Reference"),
		func(ctx context.Context, _ *struct{}) (*httpx.Response[LegalDTO], error) {
			return httpx.OK(ctx, Legal()), nil
		})
	httpx.Protected(api, httpx.Op("me-consents-list", http.MethodGet, "/me/consents", "List consents", ctag),
		func(ctx context.Context, in *struct {
			History bool `query:"history" doc:"Include revoked consents"`
		}) (*httpx.Response[[]ConsentDTO], error) {
			list, err := s.ListConsents(ctx, in.History)
			if err != nil {
				return nil, err
			}
			return httpx.OK(ctx, list), nil
		})
	httpx.Protected(api, httpx.Created(httpx.Op("me-consents-grant", http.MethodPost, "/me/consents", "Grant a consent", ctag)),
		func(ctx context.Context, in *struct {
			Body struct {
				ConsentType string  `json:"consent_type" enum:"ai_processing,ai_receipt_processing,marketing_email,product_analytics,location,contacts_discovery,push_notifications,terms,privacy_policy"`
				Version     string  `json:"version" maxLength:"40"`
				Scope       *string `json:"scope,omitempty" maxLength:"80"`
			}
		}) (*httpx.Response[ConsentDTO], error) {
			c, err := s.GrantConsent(ctx, in.Body.ConsentType, in.Body.Version, in.Body.Scope)
			if err != nil {
				return nil, err
			}
			return httpx.OK(ctx, *c), nil
		})
	httpx.Protected(api, httpx.Op("me-consents-revoke", http.MethodDelete, "/me/consents/{consentType}", "Revoke a consent", ctag),
		func(ctx context.Context, in *struct {
			ConsentType string `path:"consentType" enum:"ai_processing,ai_receipt_processing,marketing_email,product_analytics,location,contacts_discovery,push_notifications"`
			Scope       string `query:"scope" maxLength:"80"`
		}) (*httpx.Response[httpx.Empty], error) {
			var scope *string
			if in.Scope != "" {
				scope = &in.Scope
			}
			if err := s.RevokeConsent(ctx, in.ConsentType, scope); err != nil {
				return nil, err
			}
			return httpx.Done(ctx), nil
		})
}
