package fx

import (
	"context"
	"net/http"

	"github.com/danielgtaylor/huma/v2"
	"github.com/google/uuid"

	"montra/backend/internal/platform/httpx"
	"montra/backend/internal/platform/ratelimit"
)

// Routes mounts exchange-rate endpoints.
func (s *Service) Routes(api huma.API) {
	const tag = "Exchange rates"
	write := func(op huma.Operation) huma.Operation { return httpx.Rate(op, ratelimit.Write.Name) }
	httpx.Protected(api, httpx.Op("fx-rates-list", http.MethodGet, "/fx/rates", "Latest rates per pair and source (provider and your overrides)", tag),
		func(ctx context.Context, in *struct {
			Base  string `query:"base" pattern:"^([A-Z]{3})?$"`
			Quote string `query:"quote" pattern:"^([A-Z]{3})?$"`
		}) (*httpx.Response[[]RateDTO], error) {
			l, err := s.ListRates(ctx, in.Base, in.Quote)
			if err != nil {
				return nil, err
			}
			return httpx.OK(ctx, l), nil
		})
	httpx.Protected(api, httpx.Created(write(httpx.Op("fx-rates-set", http.MethodPost, "/fx/rates",
		"Add a manual rate override (history is kept)", tag))),
		func(ctx context.Context, in *struct{ Body ManualRateInput }) (*httpx.Response[RateDTO], error) {
			r, err := s.SetManualRate(ctx, in.Body)
			if err != nil {
				return nil, err
			}
			return httpx.OK(ctx, *r), nil
		})
	httpx.Protected(api, write(httpx.Op("fx-rates-delete", http.MethodDelete, "/fx/rates/{id}", "Delete one of your manual rates", tag)),
		func(ctx context.Context, in *struct {
			ID uuid.UUID `path:"id"`
		}) (*httpx.Response[httpx.Empty], error) {
			if err := s.DeleteManualRate(ctx, in.ID); err != nil {
				return nil, err
			}
			return httpx.Done(ctx), nil
		})
	httpx.Protected(api, httpx.Op("fx-convert", http.MethodGet, "/fx/convert", "Convert an amount with a disclosed rate", tag),
		func(ctx context.Context, in *struct {
			Amount string `query:"amount" required:"true"`
			From   string `query:"from" required:"true" pattern:"^[A-Z]{3}$"`
			To     string `query:"to" required:"true" pattern:"^[A-Z]{3}$"`
			Policy string `query:"policy" enum:"historical,current,"`
			Date   string `query:"date" doc:"YYYY-MM-DD; required for the historical policy"`
		}) (*httpx.Response[ConversionDTO], error) {
			c, err := s.Convert(ctx, in.Amount, in.From, in.To, in.Date, in.Policy)
			if err != nil {
				return nil, err
			}
			return httpx.OK(ctx, *c), nil
		})
}
