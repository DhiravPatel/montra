package search

import (
	"context"
	"net/http"

	"github.com/danielgtaylor/huma/v2"

	"montra/backend/internal/platform/httpx"
)

// DeletedDTO reports how many recent searches were cleared.
type DeletedDTO struct {
	Deleted int64 `json:"deleted"`
}

// Routes mounts search endpoints.
func (s *Service) Routes(api huma.API) {
	const tag = "Search"
	httpx.Protected(api, httpx.Op("search", http.MethodGet, "/search",
		"Search your transactions, merchants, accounts, groups, goals, categories, bills, subscriptions, recurring rules, budgets, readable community posts and discoverable people", tag),
		func(ctx context.Context, in *Input) (*httpx.Response[Results], error) {
			r, err := s.Search(ctx, *in)
			if err != nil {
				return nil, err
			}
			return httpx.OK(ctx, *r), nil
		})
	httpx.Protected(api, httpx.Op("search-recent", http.MethodGet, "/search/recent", "Your recent searches", tag),
		func(ctx context.Context, _ *struct{}) (*httpx.Response[[]RecentDTO], error) {
			l, err := s.Recent(ctx)
			if err != nil {
				return nil, err
			}
			return httpx.OK(ctx, l), nil
		})
	httpx.Protected(api, httpx.Op("search-recent-clear", http.MethodDelete, "/search/recent", "Clear your search history", tag),
		func(ctx context.Context, _ *struct{}) (*httpx.Response[DeletedDTO], error) {
			n, err := s.ClearRecent(ctx)
			if err != nil {
				return nil, err
			}
			return httpx.OK(ctx, DeletedDTO{Deleted: n}), nil
		})
}
