package crypto

import (
	"bytes"
	"testing"
	"time"
)

func TestPasswordHashing(t *testing.T) {
	p := Argon2Params{Memory: 8 * 1024, Time: 1, Threads: 1, KeyLen: 32, SaltLen: 16} // fast params for tests
	h, err := HashPassword("correct horse battery", p)
	if err != nil {
		t.Fatal(err)
	}
	ok, _, err := VerifyPassword("correct horse battery", h, p)
	if err != nil || !ok {
		t.Fatal("expected match")
	}
	ok, _, _ = VerifyPassword("wrong", h, p)
	if ok {
		t.Fatal("expected mismatch")
	}
	_, rehash, _ := VerifyPassword("correct horse battery", h, DefaultArgon2)
	if !rehash {
		t.Fatal("weaker params should require rehash")
	}
	if _, _, err := VerifyPassword("x", "$bcrypt$junk", p); err == nil {
		t.Fatal("expected ErrBadHash")
	}
}

func TestKeyringRoundTripAndRotation(t *testing.T) {
	k1 := bytes.Repeat([]byte{1}, 32)
	k2 := bytes.Repeat([]byte{2}, 32)
	old, _ := NewKeyring([]Key{{ID: "k1", Key: k1}})
	ct, kid, err := old.Encrypt([]byte("secret"), []byte("row-1"))
	if err != nil || kid != "k1" {
		t.Fatal(err)
	}
	rotated, _ := NewKeyring([]Key{{ID: "k2", Key: k2}, {ID: "k1", Key: k1}})
	pt, err := rotated.Decrypt(ct, kid, []byte("row-1"))
	if err != nil || string(pt) != "secret" {
		t.Fatalf("decrypt after rotation: %v", err)
	}
	if _, err := rotated.Decrypt(ct, kid, []byte("row-2")); err == nil {
		t.Fatal("AAD mismatch must fail")
	}
	if rotated.PrimaryKeyID() != "k2" {
		t.Fatal("primary key should be first")
	}
}

func TestSignedURL(t *testing.T) {
	s := NewSigner(bytes.Repeat([]byte{9}, 32))
	now := time.Unix(1_700_000_000, 0)
	if !s.VerifyURL("/files/1/content", "user-a", "1700000300", s.Sign("url", "/files/1/content", "user-a", "1700000300"), now) {
		t.Fatal("valid signature rejected")
	}
	if s.VerifyURL("/files/1/content", "user-b", "1700000300", s.Sign("url", "/files/1/content", "user-a", "1700000300"), now) {
		t.Fatal("subject swap accepted")
	}
	if s.VerifyURL("/files/1/content", "user-a", "1699999999", s.Sign("url", "/files/1/content", "user-a", "1699999999"), now) {
		t.Fatal("expired URL accepted")
	}
}

// RFC 6238 Appendix B test vectors (SHA-1, 8 digits truncated to 6 here via
// HOTP's modulo of 10^6; vectors below are the last 6 digits).
func TestTOTPVectors(t *testing.T) {
	secret := []byte("12345678901234567890")
	vectors := map[int64]string{
		59:          "287082",
		1111111109:  "081804",
		1111111111:  "050471",
		1234567890:  "005924",
		2000000000:  "279037",
		20000000000: "353130",
	}
	for ts, want := range vectors {
		if got := HOTP(secret, TOTPStep(time.Unix(ts, 0))); got != want {
			t.Errorf("TOTP(%d) = %s, want %s", ts, got, want)
		}
	}
	step, ok := VerifyTOTP(secret, "287082", time.Unix(59+30, 0)) // previous step accepted
	if !ok || step != 1 {
		t.Fatalf("drift window failed: %d %v", step, ok)
	}
	if _, ok := VerifyTOTP(secret, "287082", time.Unix(59+120, 0)); ok {
		t.Fatal("stale code accepted")
	}
}
