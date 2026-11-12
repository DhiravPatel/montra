package email

import (
	"bytes"
	"fmt"
	htmltpl "html/template"
	"strings"
	texttpl "text/template"
)

// Template identifiers.
const (
	TplVerifyEmail      = "verify_email"
	TplPasswordReset    = "password_reset"
	TplPasswordChanged  = "password_changed"
	TplAccountExists    = "account_exists"
	TplNewSignIn        = "new_sign_in"
	TplDeletionSchedule = "deletion_scheduled"
	TplDeletionDone     = "deletion_completed"
	TplExportReady      = "export_ready"
	TplNotification     = "notification"
	TplMFAChanged       = "mfa_changed"
	TplDigest           = "digest"
)

type tplDef struct {
	subject string
	body    string // text/template; {{.Link}}, {{.Name}}, {{.Body}} …
	action  string // button label for HTML
}

// Localized catalog. Keys are locale language tags; "en" is the fallback.
// Bodies never contain financial details (spec §4.17).
var catalog = map[string]map[string]tplDef{
	"en": {
		TplVerifyEmail: {subject: "Verify your Montra email", action: "Verify email",
			body: "Hi {{.Name}},\n\nConfirm your email address to finish setting up Montra:\n{{.Link}}\n\nThis link expires in {{.Expiry}}. If you didn't create a Montra account, you can ignore this email."},
		TplPasswordReset: {subject: "Reset your Montra password", action: "Reset password",
			body: "Hi {{.Name}},\n\nWe received a request to reset your password. Use this link to choose a new one:\n{{.Link}}\n\nThis link expires in {{.Expiry}}. If you didn't ask for this, you can ignore this email; your password won't change."},
		TplPasswordChanged: {subject: "Your Montra password was changed",
			body: "Hi {{.Name}},\n\nYour password was changed and other sessions were signed out. If this wasn't you, reset your password immediately and contact {{.Support}}."},
		TplAccountExists: {subject: "Sign-up attempt for your Montra account", action: "Sign in",
			body: "Hi,\n\nSomeone tried to create a Montra account with this email address, which already has an account. If it was you, sign in or reset your password:\n{{.Link}}\n\nIf it wasn't you, no action is needed."},
		TplNewSignIn: {subject: "New sign-in to your Montra account",
			body: "Hi {{.Name}},\n\nYour account was signed in on a new device ({{.Device}}) at {{.When}}. If this wasn't you, sign out all sessions from Settings → Security and change your password."},
		TplMFAChanged: {subject: "Two-step verification settings changed",
			body: "Hi {{.Name}},\n\nTwo-step verification was {{.Body}} for your Montra account. If this wasn't you, secure your account immediately."},
		TplDeletionSchedule: {subject: "Your Montra account deletion is scheduled", action: "Cancel deletion",
			body: "Hi {{.Name}},\n\nYour account is scheduled for deletion on {{.When}}. You can cancel before then from Settings → Privacy:\n{{.Link}}"},
		TplDeletionDone: {subject: "Your Montra account has been deleted",
			body: "Hi,\n\nYour Montra account and associated data have been deleted, except records we must retain as described in our privacy policy. Thank you for using Montra."},
		TplExportReady: {subject: "Your Montra data export is ready", action: "Download export",
			body: "Hi {{.Name}},\n\nYour data export is ready. Sign in to download it before {{.When}}:\n{{.Link}}"},
		TplNotification: {subject: "{{.Subject}}", action: "Open Montra",
			body: "Hi {{.Name}},\n\n{{.Body}}\n\n{{.Link}}{{if .Unsubscribe}}\n\nTo stop these emails: {{.Unsubscribe}}{{end}}"},
		TplDigest: {subject: "{{.Subject}}", action: "Open Montra",
			body: "Hi {{.Name}},\n\n{{.Body}}\n\n{{.Link}}{{if .Unsubscribe}}\n\nTo change how often you get this digest: {{.Unsubscribe}}{{end}}"},
	},
	"hi": {
		TplVerifyEmail: {subject: "अपना Montra ईमेल सत्यापित करें", action: "ईमेल सत्यापित करें",
			body: "नमस्ते {{.Name}},\n\nMontra सेटअप पूरा करने के लिए अपना ईमेल पता सत्यापित करें:\n{{.Link}}\n\nयह लिंक {{.Expiry}} में समाप्त हो जाएगा। यदि आपने खाता नहीं बनाया है, तो इस ईमेल को अनदेखा करें।"},
		TplPasswordReset: {subject: "अपना Montra पासवर्ड रीसेट करें", action: "पासवर्ड रीसेट करें",
			body: "नमस्ते {{.Name}},\n\nनया पासवर्ड चुनने के लिए इस लिंक का उपयोग करें:\n{{.Link}}\n\nयह लिंक {{.Expiry}} में समाप्त हो जाएगा। यदि आपने यह अनुरोध नहीं किया है, तो इसे अनदेखा करें।"},
	},
}

// Data is the template input.
type Data struct {
	Name        string
	Link        string
	Unsubscribe string // one-click unsubscribe link (optional emails only)
	Expiry      string
	Support     string
	Device      string
	When        string
	Body        string
	Subject     string
}

var htmlLayout = htmltpl.Must(htmltpl.New("layout").Parse(`<!doctype html>
<html><body style="font-family:-apple-system,Segoe UI,Roboto,sans-serif;background:#f6f7f9;margin:0;padding:24px;color:#1b1f24">
<div style="max-width:520px;margin:0 auto;background:#ffffff;border-radius:12px;padding:28px">
<p style="font-size:18px;font-weight:600;margin:0 0 16px">Montra</p>
{{range .Paragraphs}}<p style="font-size:15px;line-height:1.5;margin:0 0 12px">{{.}}</p>{{end}}
{{if .Link}}<p style="margin:20px 0"><a href="{{.Link}}" style="background:#1f6f5c;color:#ffffff;padding:10px 18px;border-radius:8px;text-decoration:none;display:inline-block">{{.Action}}</a></p>{{end}}
<p style="font-size:12px;color:#5b6470;margin-top:24px">This is an automated message from Montra. Montra will never ask for your password, PIN, OTP or card details.</p>
</div></body></html>`))

// Build renders a localized message. Unknown locales fall back to English.
func Build(tpl, locale, to string, d Data) (Message, error) {
	lang := strings.ToLower(strings.SplitN(locale, "-", 2)[0])
	def, ok := catalog[lang][tpl]
	if !ok {
		def, ok = catalog["en"][tpl]
		if !ok {
			return Message{}, fmt.Errorf("unknown email template %q", tpl)
		}
	}
	subject, err := execText(def.subject, d)
	if err != nil {
		return Message{}, err
	}
	text, err := execText(def.body, d)
	if err != nil {
		return Message{}, err
	}
	var paragraphs []string
	for _, p := range strings.Split(text, "\n\n") {
		if strings.TrimSpace(p) != "" && strings.TrimSpace(p) != d.Link {
			paragraphs = append(paragraphs, strings.ReplaceAll(p, d.Link, ""))
		}
	}
	var hb bytes.Buffer
	if err := htmlLayout.Execute(&hb, map[string]any{"Paragraphs": paragraphs, "Link": d.Link, "Action": def.action}); err != nil {
		return Message{}, err
	}
	return Message{To: to, Subject: subject, Text: text, HTML: hb.String(), Category: tpl}, nil
}

func execText(src string, d Data) (string, error) {
	t, err := texttpl.New("t").Parse(src)
	if err != nil {
		return "", err
	}
	var b bytes.Buffer
	if err := t.Execute(&b, d); err != nil {
		return "", err
	}
	return b.String(), nil
}
