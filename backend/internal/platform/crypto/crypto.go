// Package crypto provides Montra's security primitives: random tokens,
// token hashing, Argon2id password hashing, AES-256-GCM envelope encryption
// with a rotating keyring, HMAC URL signing and TOTP (RFC 6238).
package crypto

import (
	"crypto/aes"
	"crypto/cipher"
	"crypto/hmac"
	"crypto/rand"
	"crypto/sha1" //nolint:gosec // RFC 6238 TOTP mandates HMAC-SHA1 for interoperability with authenticator apps.
	"crypto/sha256"
	"crypto/subtle"
	"encoding/base32"
	"encoding/base64"
	"encoding/binary"
	"errors"
	"fmt"
	"net/url"
	"strconv"
	"strings"
	"time"

	"golang.org/x/crypto/argon2"
)

// RandomToken returns a URL-safe random token with n bytes of entropy.
func RandomToken(n int) (string, error) {
	b := make([]byte, n)
	if _, err := rand.Read(b); err != nil {
		return "", err
	}
	return base64.RawURLEncoding.EncodeToString(b), nil
}

// MustRandomToken panics if the system RNG fails (unrecoverable).
func MustRandomToken(n int) string {
	t, err := RandomToken(n)
	if err != nil {
		panic(err)
	}
	return t
}

// HashToken returns SHA-256(token); tokens are stored only as hashes.
func HashToken(token string) []byte {
	sum := sha256.Sum256([]byte(token))
	return sum[:]
}

// HashWithPepper hashes an identifier (e.g. normalized email) with a secret
// pepper for throttling keys that must not reveal the identifier.
func HashWithPepper(pepper []byte, value string) []byte {
	m := hmac.New(sha256.New, pepper)
	m.Write([]byte(value))
	return m.Sum(nil)
}

// ConstantTimeEqual compares secrets in constant time.
func ConstantTimeEqual(a, b string) bool {
	return subtle.ConstantTimeCompare([]byte(a), []byte(b)) == 1
}

// ---------------------------------------------------------------------------
// Argon2id password hashing (PHC string format).
// ---------------------------------------------------------------------------

// Argon2Params are the cost parameters.
type Argon2Params struct {
	Memory  uint32 // KiB
	Time    uint32
	Threads uint8
	KeyLen  uint32
	SaltLen int
}

// DefaultArgon2 follows OWASP guidance (m=64 MiB, t=3, p=2).
var DefaultArgon2 = Argon2Params{Memory: 64 * 1024, Time: 3, Threads: 2, KeyLen: 32, SaltLen: 16}

// HashPassword returns an encoded Argon2id hash.
func HashPassword(password string, p Argon2Params) (string, error) {
	salt := make([]byte, p.SaltLen)
	if _, err := rand.Read(salt); err != nil {
		return "", err
	}
	key := argon2.IDKey([]byte(password), salt, p.Time, p.Memory, p.Threads, p.KeyLen)
	return fmt.Sprintf("$argon2id$v=%d$m=%d,t=%d,p=%d$%s$%s", argon2.Version, p.Memory, p.Time, p.Threads,
		base64.RawStdEncoding.EncodeToString(salt), base64.RawStdEncoding.EncodeToString(key)), nil
}

// ErrBadHash indicates a malformed stored hash.
var ErrBadHash = errors.New("malformed password hash")

// VerifyPassword checks a password against an encoded hash. needsRehash
// reports whether the hash uses weaker parameters than p.
func VerifyPassword(password, encoded string, p Argon2Params) (ok bool, needsRehash bool, err error) {
	parts := strings.Split(encoded, "$")
	if len(parts) != 6 || parts[1] != "argon2id" {
		return false, false, ErrBadHash
	}
	var version int
	if _, err := fmt.Sscanf(parts[2], "v=%d", &version); err != nil || version != argon2.Version {
		return false, false, ErrBadHash
	}
	var mem, t uint32
	var th uint8
	if _, err := fmt.Sscanf(parts[3], "m=%d,t=%d,p=%d", &mem, &t, &th); err != nil {
		return false, false, ErrBadHash
	}
	salt, err := base64.RawStdEncoding.DecodeString(parts[4])
	if err != nil {
		return false, false, ErrBadHash
	}
	want, err := base64.RawStdEncoding.DecodeString(parts[5])
	if err != nil || len(want) == 0 {
		return false, false, ErrBadHash
	}
	got := argon2.IDKey([]byte(password), salt, t, mem, th, uint32(len(want)))
	ok = subtle.ConstantTimeCompare(got, want) == 1
	needsRehash = mem < p.Memory || t < p.Time || th < p.Threads
	return ok, needsRehash, nil
}

// dummyHash is used to equalize timing when an account does not exist.
var dummyHash, _ = HashPassword("montra-timing-equalizer", DefaultArgon2)

// BurnPasswordCheck performs a password verification against a dummy hash so
// that unknown accounts take the same time as known ones.
func BurnPasswordCheck(password string) {
	_, _, _ = VerifyPassword(password, dummyHash, DefaultArgon2)
}

// ---------------------------------------------------------------------------
// AES-256-GCM keyring encryption.
// ---------------------------------------------------------------------------

// Key is an AES-256 key with an identifier.
type Key struct {
	ID  string
	Key []byte
}

// Keyring encrypts with the first key and decrypts with any key.
type Keyring struct {
	keys []Key
	byID map[string][]byte
}

// NewKeyring builds a keyring; at least one 32-byte key is required.
func NewKeyring(keys []Key) (*Keyring, error) {
	if len(keys) == 0 {
		return nil, errors.New("keyring requires at least one key")
	}
	kr := &Keyring{keys: keys, byID: map[string][]byte{}}
	for _, k := range keys {
		if len(k.Key) != 32 {
			return nil, fmt.Errorf("key %q must be 32 bytes", k.ID)
		}
		kr.byID[k.ID] = k.Key
	}
	return kr, nil
}

// PrimaryKeyID returns the ID used for new encryptions.
func (k *Keyring) PrimaryKeyID() string { return k.keys[0].ID }

// Encrypt seals plaintext with associated data (e.g. the owning row ID),
// returning nonce||ciphertext and the key ID used.
func (k *Keyring) Encrypt(plaintext, aad []byte) ([]byte, string, error) {
	key := k.keys[0]
	block, err := aes.NewCipher(key.Key)
	if err != nil {
		return nil, "", err
	}
	gcm, err := cipher.NewGCM(block)
	if err != nil {
		return nil, "", err
	}
	nonce := make([]byte, gcm.NonceSize())
	if _, err := rand.Read(nonce); err != nil {
		return nil, "", err
	}
	return gcm.Seal(nonce, nonce, plaintext, aad), key.ID, nil
}

// ErrDecrypt indicates the ciphertext could not be authenticated.
var ErrDecrypt = errors.New("decryption failed")

// Decrypt opens ciphertext produced by Encrypt.
func (k *Keyring) Decrypt(ciphertext []byte, keyID string, aad []byte) ([]byte, error) {
	keyBytes, ok := k.byID[keyID]
	if !ok {
		return nil, ErrDecrypt
	}
	block, err := aes.NewCipher(keyBytes)
	if err != nil {
		return nil, err
	}
	gcm, err := cipher.NewGCM(block)
	if err != nil {
		return nil, err
	}
	if len(ciphertext) < gcm.NonceSize() {
		return nil, ErrDecrypt
	}
	pt, err := gcm.Open(nil, ciphertext[:gcm.NonceSize()], ciphertext[gcm.NonceSize():], aad)
	if err != nil {
		return nil, ErrDecrypt
	}
	return pt, nil
}

// ---------------------------------------------------------------------------
// HMAC signing for short-lived URLs and CSRF tokens.
// ---------------------------------------------------------------------------

// Signer produces and verifies HMAC-SHA256 signatures.
type Signer struct{ key []byte }

// NewSigner creates a signer.
func NewSigner(key []byte) *Signer { return &Signer{key: key} }

// Sign returns a base64url signature of the message parts.
func (s *Signer) Sign(parts ...string) string {
	m := hmac.New(sha256.New, s.key)
	for i, p := range parts {
		if i > 0 {
			m.Write([]byte{0})
		}
		m.Write([]byte(p))
	}
	return base64.RawURLEncoding.EncodeToString(m.Sum(nil))
}

// Verify checks a signature in constant time.
func (s *Signer) Verify(sig string, parts ...string) bool {
	return ConstantTimeEqual(sig, s.Sign(parts...))
}

// SignURL appends exp and sig query parameters binding the path, the
// subject (e.g. user ID) and expiry.
func (s *Signer) SignURL(base, path, subject string, ttl time.Duration, now time.Time) string {
	exp := strconv.FormatInt(now.Add(ttl).Unix(), 10)
	sig := s.Sign("url", path, subject, exp)
	q := url.Values{}
	q.Set("exp", exp)
	q.Set("sub", subject)
	q.Set("sig", sig)
	return strings.TrimRight(base, "/") + path + "?" + q.Encode()
}

// VerifyURL validates a signed URL's parameters for the given path.
func (s *Signer) VerifyURL(path, subject, exp, sig string, now time.Time) bool {
	e, err := strconv.ParseInt(exp, 10, 64)
	if err != nil || now.Unix() > e {
		return false
	}
	return s.Verify(sig, "url", path, subject, exp)
}

// ---------------------------------------------------------------------------
// TOTP (RFC 6238): HMAC-SHA1, 6 digits, 30-second step.
// ---------------------------------------------------------------------------

// NewTOTPSecret returns 20 random bytes (160 bits).
func NewTOTPSecret() ([]byte, error) {
	b := make([]byte, 20)
	_, err := rand.Read(b)
	return b, err
}

// TOTPSecretBase32 encodes a secret for authenticator apps.
func TOTPSecretBase32(secret []byte) string {
	return strings.TrimRight(base32.StdEncoding.EncodeToString(secret), "=")
}

// TOTPURI builds an otpauth:// URI for QR provisioning.
func TOTPURI(issuer, account string, secret []byte) string {
	label := url.PathEscape(issuer) + ":" + url.PathEscape(account)
	q := url.Values{}
	q.Set("secret", TOTPSecretBase32(secret))
	q.Set("issuer", issuer)
	q.Set("algorithm", "SHA1")
	q.Set("digits", "6")
	q.Set("period", "30")
	return "otpauth://totp/" + label + "?" + q.Encode()
}

// HOTP computes the RFC 4226 code for a counter.
func HOTP(secret []byte, counter uint64) string {
	var msg [8]byte
	binary.BigEndian.PutUint64(msg[:], counter)
	m := hmac.New(sha1.New, secret)
	m.Write(msg[:])
	sum := m.Sum(nil)
	off := sum[len(sum)-1] & 0x0f
	code := (uint32(sum[off])&0x7f)<<24 | uint32(sum[off+1])<<16 | uint32(sum[off+2])<<8 | uint32(sum[off+3])
	return fmt.Sprintf("%06d", code%1_000_000)
}

// TOTPStep returns the time step for t.
func TOTPStep(t time.Time) uint64 { return uint64(t.Unix() / 30) }

// VerifyTOTP checks code within ±1 step and returns the matched step. The
// caller must reject steps <= the last used step (replay protection).
func VerifyTOTP(secret []byte, code string, now time.Time) (uint64, bool) {
	code = strings.TrimSpace(code)
	if len(code) != 6 {
		return 0, false
	}
	step := TOTPStep(now)
	for _, d := range []int64{0, -1, 1} {
		s := uint64(int64(step) + d)
		if subtle.ConstantTimeCompare([]byte(HOTP(secret, s)), []byte(code)) == 1 {
			return s, true
		}
	}
	return 0, false
}
