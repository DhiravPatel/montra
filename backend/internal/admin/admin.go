// Package admin is the operator cost and usage dashboard (spec §17) and
// background job visibility (JOB-007): only platform admins, aggregate
// counts and operational job facts only.
package admin

import (
	"context"
	"encoding/json"
	"net/http"

	"github.com/danielgtaylor/huma/v2"
	"github.com/jackc/pgx/v5"

	"montra/backend/internal/platform/database"
	"montra/backend/internal/platform/httpx"
	"montra/backend/internal/platform/identity"
)

// Service implements the dashboard.
type Service struct {
	DB *database.DB
}

// DailyUsage is one day of activity.
type DailyUsage struct {
	Date         string `json:"date"`
	NewUsers     int64  `json:"new_users"`
	Transactions int64  `json:"transactions"`
	EmailsSent   int64  `json:"emails_sent"`
}

// Usage is aggregate platform usage for a window.
type Usage struct {
	WindowDays int `json:"window_days"`
	Users      struct {
		Active          int64 `json:"active"`
		New             int64 `json:"new"`
		PendingDeletion int64 `json:"pending_deletion"`
	} `json:"users"`
	Storage struct {
		Bytes int64 `json:"bytes"`
		Files int64 `json:"files"`
	} `json:"storage"`
	StorageByArea  map[string]int64 `json:"storage_by_area"`
	Notifications  map[string]int64 `json:"notifications" doc:"Deliveries by channel:status in the window"`
	Jobs           map[string]int64 `json:"jobs" doc:"Jobs by status in the window"`
	DeadJobsByType map[string]int64 `json:"dead_jobs_by_type"`
	AI             struct {
		Requests     int64 `json:"requests"`
		CostMicroUSD int64 `json:"cost_micro_usd"`
	} `json:"ai"`
	Imports             int64        `json:"imports"`
	Reports             int64        `json:"reports"`
	TransactionsCreated int64        `json:"transactions_created"`
	SupportOpen         int64        `json:"support_open"`
	Daily               []DailyUsage `json:"daily"`
}

// Usage returns the dashboard for the last n days (1-365).
func (s *Service) Usage(ctx context.Context, days int) (*Usage, error) {
	uid, err := identity.UserID(ctx)
	if err != nil {
		return nil, err
	}
	var raw []byte
	err = s.DB.WithUserReadTx(ctx, uid, func(tx pgx.Tx) error {
		return tx.QueryRow(ctx, `select montra.admin_usage($1)`, days).Scan(&raw)
	})
	if err != nil {
		return nil, database.MapError(err)
	}
	var out Usage
	if err := json.Unmarshal(raw, &out); err != nil {
		return nil, err
	}
	if out.Daily == nil {
		out.Daily = []DailyUsage{}
	}
	return &out, nil
}

// Routes mounts the admin endpoints.
func (s *Service) Routes(api huma.API) {
	httpx.Protected(api, httpx.Staff(httpx.Op("admin-usage", http.MethodGet, "/admin/usage",
		"Platform usage and cost indicators (admin; aggregate counts only)", "Admin"), "admin"),
		func(ctx context.Context, in *struct {
			Days int `query:"days" minimum:"1" maximum:"365" default:"30"`
		}) (*httpx.Response[Usage], error) {
			u, err := s.Usage(ctx, in.Days)
			if err != nil {
				return nil, err
			}
			return httpx.OK(ctx, *u), nil
		})
	s.jobRoutes(api)
}
