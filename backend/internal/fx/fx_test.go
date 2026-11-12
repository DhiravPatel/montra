package fx

import (
	"errors"
	"testing"
	"time"

	"montra/backend/internal/platform/apperr"
)

func zone(t *testing.T, name string) *time.Location {
	t.Helper()
	l, err := time.LoadLocation(name)
	if err != nil {
		t.Fatal(err)
	}
	return l
}

func TestNormalizeDecimal(t *testing.T) {
	for in, want := range map[string]string{
		"83.123400000000":                 "83.1234",
		"83.000000000000":                 "83",
		"0.500000000000":                  "0.5",
		"0.000000000001":                  "0.000000000001",
		".5":                              "0.5",
		"007.50":                          "7.5",
		"1":                               "1",
		"10":                              "10",
		"100.000":                         "100",
		"0.000000000000":                  "0",
		"-2.50":                           "-2.5",
		" 1.20 ":                          "1.2",
		"123456789012345678.000000000000": "123456789012345678",
		"":                                "",
		"abc":                             "abc",
		"1.2.3":                           "1.2.3",
		"1e5":                             "1e5",
	} {
		if got := NormalizeDecimal(in); got != want {
			t.Errorf("NormalizeDecimal(%q) = %q, want %q", in, got, want)
		}
	}
}

func TestParseAsOfBareDateUsesTheUsersZone(t *testing.T) {
	ist := zone(t, "Asia/Kolkata")
	tonga := zone(t, "Pacific/Tongatapu") // UTC+13, no DST
	kiri := zone(t, "Pacific/Kiritimati") // UTC+14
	// 02:00 UTC is 07:30 in India and 15:00 in Tonga on 5 November.
	now := time.Date(2026, 11, 5, 2, 0, 0, 0, time.UTC)
	cases := []struct {
		name string
		in   string
		loc  *time.Location
		want time.Time
	}{
		// Today's date is accepted before noon UTC (the old 12:00 UTC pin
		// called it the future) and starts at local midnight.
		{"IST today", "2026-11-05", ist, time.Date(2026, 11, 4, 18, 30, 0, 0, time.UTC)},
		{"IST past", "2026-10-31", ist, time.Date(2026, 10, 30, 18, 30, 0, 0, time.UTC)},
		// In UTC+13 the date is not shifted to the next local day.
		{"UTC+13 today", "2026-11-05", tonga, time.Date(2026, 11, 4, 11, 0, 0, 0, time.UTC)},
		{"UTC+13 yesterday", "2026-11-04", tonga, time.Date(2026, 11, 3, 11, 0, 0, 0, time.UTC)},
		{"UTC+14 today", "2026-11-05", kiri, time.Date(2026, 11, 4, 10, 0, 0, 0, time.UTC)},
		{"UTC today", "2026-11-05", time.UTC, time.Date(2026, 11, 5, 0, 0, 0, 0, time.UTC)},
		// RFC 3339 instants are kept as sent.
		{"instant", "2026-11-04T09:15:00+05:30", ist, time.Date(2026, 11, 4, 3, 45, 0, 0, time.UTC)},
		{"instant within the hour", "2026-11-05T02:45:00Z", tonga, time.Date(2026, 11, 5, 2, 45, 0, 0, time.UTC)},
		{"default now", "", ist, now},
	}
	for _, c := range cases {
		got, err := parseAsOf(c.in, now, c.loc)
		if err != nil || !got.Equal(c.want) {
			t.Errorf("%s: parseAsOf(%q) = %v, %v; want %v", c.name, c.in, got.UTC(), err, c.want)
		}
		// A conversion dated that local day finds the rate; the previous day does not.
		if c.in != "" && len(c.in) == len(time.DateOnly) {
			d, _ := time.ParseInLocation(time.DateOnly, c.in, c.loc)
			if end := EndOfDay(d); got.After(end) {
				t.Errorf("%s: rate at %v is after the end of its own day %v", c.name, got.UTC(), end.UTC())
			}
			if prevEnd := EndOfDay(d.AddDate(0, 0, -1)); !got.After(prevEnd) {
				t.Errorf("%s: rate at %v already applies to the previous day (ends %v)", c.name, got.UTC(), prevEnd.UTC())
			}
		}
	}
}

func TestParseAsOfRejectsFutureAndMalformed(t *testing.T) {
	now := time.Date(2026, 11, 5, 2, 0, 0, 0, time.UTC)
	tonga := zone(t, "Pacific/Tongatapu")
	ist := zone(t, "Asia/Kolkata")
	for _, c := range []struct {
		in   string
		loc  *time.Location
		want string
	}{
		{"2026-11-06", ist, "A rate cannot be dated in the future."},
		{"2026-11-06", tonga, "A rate cannot be dated in the future."},
		{"2026-11-05T03:30:00Z", ist, "A rate cannot be dated in the future."},
		{"5/11/2026", ist, "Use RFC 3339 or YYYY-MM-DD."},
		{"2026-11-31", ist, "Use RFC 3339 or YYYY-MM-DD."},
		{"1960-01-01", ist, "Date is out of range."},
	} {
		_, err := parseAsOf(c.in, now, c.loc)
		var ae *apperr.Error
		if !errors.As(err, &ae) || len(ae.Details) != 1 || ae.Details[0].Field != "body.as_of" || ae.Details[0].Message != c.want {
			t.Errorf("parseAsOf(%q in %s) = %v, want %q", c.in, c.loc, err, c.want)
		}
	}
	// Late in the UTC day it is already tomorrow in Tonga: that date is today there.
	late := time.Date(2026, 11, 5, 12, 0, 0, 0, time.UTC) // 01:00 on 6 November in Tonga
	if got, err := parseAsOf("2026-11-06", late, tonga); err != nil || !got.Equal(time.Date(2026, 11, 5, 11, 0, 0, 0, time.UTC)) {
		t.Fatalf("Tonga's today rejected: %v %v", got, err)
	}
	if _, err := parseAsOf("2026-11-06", late, ist); err == nil {
		t.Fatal("India's tomorrow accepted")
	}
}

func TestEndOfDayFollowsDST(t *testing.T) {
	ny := zone(t, "America/New_York")
	for _, c := range []struct {
		day   time.Time
		hours float64
	}{
		{time.Date(2026, 3, 8, 0, 0, 0, 0, ny), 23},  // spring forward
		{time.Date(2026, 11, 1, 0, 0, 0, 0, ny), 25}, // fall back
		{time.Date(2026, 6, 1, 0, 0, 0, 0, ny), 24},
	} {
		end := EndOfDay(c.day)
		if got := end.Sub(c.day) + time.Microsecond; got.Hours() != c.hours {
			t.Errorf("%v lasts %v, want %vh", c.day, got, c.hours)
		}
		if l := end.In(ny); l.Day() != c.day.Day() || l.Hour() != 23 || l.Minute() != 59 {
			t.Errorf("end of %v = %v", c.day, l)
		}
	}
}
