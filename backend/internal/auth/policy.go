package auth

import (
	"net/mail"
	"strings"
	"unicode/utf8"

	"montra/backend/internal/platform/apperr"
)

// commonPasswords is a small deny-list of the most common passwords (all
// lower-cased); length rules already exclude most weak choices.
var commonPasswords = map[string]struct{}{}

func init() {
	for _, p := range strings.Fields(`password password1 password123 passw0rd 1234567890 12345678910 qwertyuiop
	qwerty123 qwerty1234 iloveyou123 welcome123 letmein123 admin12345 administrator abc1234567 1q2w3e4r5t
	1qaz2wsx3edc zaq12wsxcde football123 baseball123 sunshine123 princess123 monkey12345 dragon12345
	trustno1234 superman123 starwars123 whatever123 freedom123 changeme123 montra1234 montra12345 india12345
	password@123 Password@123 pass@12345 asdfghjkl1 zxcvbnm123 qazwsxedc1 11111111111 00000000000 9876543210
	welcome@123 test123456 testtest12 secret12345 mypassword1 summer2024 winter2024 spring2025 autumn2025`) {
		commonPasswords[strings.ToLower(p)] = struct{}{}
	}
}

// ValidatePassword enforces the password policy (docs/SECURITY.md); errors
// name the request field that holds the password.
func ValidatePassword(pw, email string, minLen int, field string) error {
	n := utf8.RuneCountInString(pw)
	if n < minLen {
		return apperr.FieldError(field, "Password must be at least "+itoa(minLen)+" characters.")
	}
	if n > 128 {
		return apperr.FieldError(field, "Password must be at most 128 characters.")
	}
	lower := strings.ToLower(pw)
	if _, bad := commonPasswords[lower]; bad {
		return apperr.FieldError(field, "This password is too common. Choose a less predictable one.")
	}
	if local, _, ok := strings.Cut(strings.ToLower(email), "@"); ok && len(local) >= 4 && strings.Contains(lower, local) {
		return apperr.FieldError(field, "Password must not contain your email address.")
	}
	if strings.TrimSpace(pw) == "" || len(strings.Fields(pw)) == 0 {
		return apperr.FieldError(field, "Password must not be blank.")
	}
	distinct := map[rune]struct{}{}
	for _, r := range pw {
		distinct[r] = struct{}{}
	}
	if len(distinct) < 4 {
		return apperr.FieldError(field, "Password needs more variety of characters.")
	}
	return nil
}

// NormalizeEmail validates and lower-cases an email address.
func NormalizeEmail(raw string) (display, normalized string, err error) {
	raw = strings.TrimSpace(raw)
	addr, perr := mail.ParseAddress(raw)
	if perr != nil || addr.Name != "" || addr.Address != raw || len(raw) > 320 || !strings.Contains(raw, ".") {
		return "", "", apperr.FieldError("body.email", "Enter a valid email address.")
	}
	return raw, strings.ToLower(raw), nil
}

func itoa(n int) string {
	if n == 0 {
		return "0"
	}
	var b []byte
	for n > 0 {
		b = append([]byte{byte('0' + n%10)}, b...)
		n /= 10
	}
	return string(b)
}
