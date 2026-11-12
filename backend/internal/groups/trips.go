package groups

import (
	"context"
	"time"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"

	"montra/backend/internal/notifications"
	"montra/backend/internal/platform/jobs"
)

// JobTripReminders sends trip/event reminders (hourly; spec §4.17 "Trip
// events"): the day before a trip starts, and the day after it ends when
// balances are still open. Reminders go out during local daytime only and
// never include amounts.
const JobTripReminders = "groups.trip_reminders"

// RegisterTripJobs registers the reminder job.
func (s *Service) RegisterTripJobs(reg *jobs.Registry) {
	reg.Register(JobTripReminders, func(ctx context.Context, _ jobs.Job) error { return s.TripReminders(ctx) },
		jobs.WithTimeout(5*time.Minute), jobs.WithConcurrency(1))
}

// TripReminders sends due trip reminders (exported for tests/operations).
func (s *Service) TripReminders(ctx context.Context) error {
	now := s.now()
	type trip struct {
		id         uuid.UUID
		kind, tz   string
		start, end *time.Time
	}
	var trips []trip
	if err := s.DB.WithSystemTx(ctx, func(tx pgx.Tx) error {
		rows, err := tx.Query(ctx, `select id, group_type, timezone, start_date, end_date from groups
			where status = 'active' and group_type in ('trip','event') and (start_date is not null or end_date is not null)
			and coalesce(end_date, start_date) >= $1::date - 2 and coalesce(start_date, end_date) <= $1::date + 2`, now.UTC())
		if err != nil {
			return err
		}
		defer rows.Close()
		for rows.Next() {
			var t trip
			if err := rows.Scan(&t.id, &t.kind, &t.tz, &t.start, &t.end); err != nil {
				return err
			}
			trips = append(trips, t)
		}
		return rows.Err()
	}); err != nil {
		return err
	}
	for _, t := range trips {
		loc, err := time.LoadLocation(t.tz)
		if err != nil {
			loc = time.UTC
		}
		local := now.In(loc)
		if local.Hour() < 9 || local.Hour() >= 21 {
			continue // daytime only
		}
		today := time.Date(local.Year(), local.Month(), local.Day(), 0, 0, 0, 0, time.UTC)
		if t.start != nil && t.start.Equal(today.AddDate(0, 0, 1)) {
			if err := s.tripStarting(ctx, t.id, t.kind, *t.start); err != nil {
				return err
			}
		}
		if t.end != nil && t.end.Equal(today.AddDate(0, 0, -1)) {
			if err := s.tripEnded(ctx, t.id, t.kind, *t.end); err != nil {
				return err
			}
		}
	}
	return nil
}

func tripWord(kind string) string {
	if kind == "event" {
		return "event"
	}
	return "trip"
}

func (s *Service) tripStarting(ctx context.Context, gid uuid.UUID, kind string, start time.Time) error {
	return s.DB.WithSystemTx(ctx, func(tx pgx.Tx) error {
		ms, err := members(ctx, tx, gid)
		if err != nil {
			return err
		}
		id := gid
		for _, m := range ms {
			if m.Status != "active" {
				continue
			}
			if _, _, err := notifications.Create(ctx, tx, notifications.Notification{UserID: m.UserID, Category: "trip", EventType: "trip_starting",
				Title: "Your " + tripWord(kind) + " starts tomorrow", Body: "Add shared expenses in the group as you go so balances stay clear.",
				DeepLink: "/groups/" + gid.String(), EntityType: "group", EntityID: &id, GroupID: &id,
				DedupeKey: "trip_starting:" + gid.String() + ":" + start.Format("2006-01-02")}); err != nil {
				return err
			}
		}
		return nil
	})
}

func (s *Service) tripEnded(ctx context.Context, gid uuid.UUID, kind string, end time.Time) error {
	return s.DB.WithSystemTx(ctx, func(tx pgx.Tx) error {
		g, err := loadGroup(ctx, tx, gid)
		if err != nil {
			return err
		}
		b, err := s.balances(ctx, tx, g)
		if err != nil {
			return err
		}
		id := gid
		for _, m := range b.Balances {
			if m.MemberStatus != "active" || m.Net.AmountMinor == 0 {
				continue
			}
			if _, _, err := notifications.Create(ctx, tx, notifications.Notification{UserID: m.UserID, Category: "trip", EventType: "trip_ended_unsettled",
				Title: "Your " + tripWord(kind) + " has ended", Body: "Some balances are still open. Open the group to see who owes whom and settle up.",
				DeepLink: "/groups/" + gid.String() + "/balances", EntityType: "group", EntityID: &id, GroupID: &id, Priority: "normal",
				DedupeKey: "trip_ended:" + gid.String() + ":" + end.Format("2006-01-02")}); err != nil {
				return err
			}
		}
		return nil
	})
}
