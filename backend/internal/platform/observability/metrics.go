// Package observability provides Prometheus metrics. Metric labels never
// contain user identifiers, amounts or other financial data (spec §13).
package observability

import (
	"crypto/subtle"
	"net/http"
	"strconv"
	"time"

	"github.com/prometheus/client_golang/prometheus"
	"github.com/prometheus/client_golang/prometheus/collectors"
	"github.com/prometheus/client_golang/prometheus/promhttp"
)

// Metrics holds the process metric collectors.
type Metrics struct {
	Registry *prometheus.Registry

	httpRequests *prometheus.CounterVec
	httpDuration *prometheus.HistogramVec

	JobsProcessed   *prometheus.CounterVec
	JobDuration     *prometheus.HistogramVec
	JobQueueDepth   *prometheus.GaugeVec
	JobRetries      *prometheus.CounterVec
	AuthEvents      *prometheus.CounterVec
	RLSDenials      prometheus.Counter
	ProviderCalls   *prometheus.CounterVec
	ProviderLatency *prometheus.HistogramVec
	AICostMicroUSD  *prometheus.CounterVec
	NotificationOut *prometheus.CounterVec
	StorageBytes    *prometheus.CounterVec
	ImportRows      *prometheus.CounterVec
	DeletionBacklog prometheus.Gauge

	breakerState       *prometheus.GaugeVec
	breakerTransitions *prometheus.CounterVec
	breakerRejections  *prometheus.CounterVec
}

// New registers all collectors on a private registry.
func New(service string) *Metrics {
	reg := prometheus.NewRegistry()
	reg.MustRegister(collectors.NewGoCollector(), collectors.NewProcessCollector(collectors.ProcessCollectorOpts{}))
	constLabels := prometheus.Labels{"service": service}
	m := &Metrics{
		Registry: reg,
		httpRequests: prometheus.NewCounterVec(prometheus.CounterOpts{
			Name: "montra_http_requests_total", Help: "HTTP requests by route and status class.", ConstLabels: constLabels,
		}, []string{"method", "route", "status"}),
		httpDuration: prometheus.NewHistogramVec(prometheus.HistogramOpts{
			Name: "montra_http_request_duration_seconds", Help: "HTTP request latency.", ConstLabels: constLabels,
			Buckets: []float64{.01, .025, .05, .1, .25, .5, .8, 1, 2.5, 5, 10},
		}, []string{"method", "route"}),
		JobsProcessed: prometheus.NewCounterVec(prometheus.CounterOpts{
			Name: "montra_jobs_processed_total", Help: "Jobs processed by type and outcome.", ConstLabels: constLabels,
		}, []string{"type", "outcome"}),
		JobDuration: prometheus.NewHistogramVec(prometheus.HistogramOpts{
			Name: "montra_job_duration_seconds", Help: "Job handler latency.", ConstLabels: constLabels,
			Buckets: prometheus.ExponentialBuckets(0.01, 3, 10),
		}, []string{"type"}),
		JobQueueDepth: prometheus.NewGaugeVec(prometheus.GaugeOpts{
			Name: "montra_job_queue_depth", Help: "Jobs by status.", ConstLabels: constLabels,
		}, []string{"status"}),
		JobRetries: prometheus.NewCounterVec(prometheus.CounterOpts{
			Name: "montra_job_retries_total", Help: "Job retries by type.", ConstLabels: constLabels,
		}, []string{"type"}),
		AuthEvents: prometheus.NewCounterVec(prometheus.CounterOpts{
			Name: "montra_auth_events_total", Help: "Authentication events by kind.", ConstLabels: constLabels,
		}, []string{"event"}),
		RLSDenials: prometheus.NewCounter(prometheus.CounterOpts{
			Name: "montra_rls_denials_total", Help: "Row-level security violations raised by PostgreSQL.", ConstLabels: constLabels,
		}),
		ProviderCalls: prometheus.NewCounterVec(prometheus.CounterOpts{
			Name: "montra_provider_calls_total", Help: "External provider calls by provider and outcome.", ConstLabels: constLabels,
		}, []string{"provider", "operation", "outcome"}),
		ProviderLatency: prometheus.NewHistogramVec(prometheus.HistogramOpts{
			Name: "montra_provider_latency_seconds", Help: "External provider latency.", ConstLabels: constLabels,
			Buckets: prometheus.ExponentialBuckets(0.05, 2, 10),
		}, []string{"provider", "operation"}),
		AICostMicroUSD: prometheus.NewCounterVec(prometheus.CounterOpts{
			Name: "montra_ai_cost_micro_usd_total", Help: "Estimated AI cost in micro-USD.", ConstLabels: constLabels,
		}, []string{"model", "feature"}),
		NotificationOut: prometheus.NewCounterVec(prometheus.CounterOpts{
			Name: "montra_notifications_total", Help: "Notification deliveries by channel and outcome.", ConstLabels: constLabels,
		}, []string{"channel", "outcome"}),
		StorageBytes: prometheus.NewCounterVec(prometheus.CounterOpts{
			Name: "montra_storage_bytes_total", Help: "Bytes written to object storage by area.", ConstLabels: constLabels,
		}, []string{"area"}),
		ImportRows: prometheus.NewCounterVec(prometheus.CounterOpts{
			Name: "montra_import_rows_total", Help: "Import rows by outcome.", ConstLabels: constLabels,
		}, []string{"outcome"}),
		DeletionBacklog: prometheus.NewGauge(prometheus.GaugeOpts{
			Name: "montra_account_deletion_backlog", Help: "Pending account deletions.", ConstLabels: constLabels,
		}),
		breakerState: prometheus.NewGaugeVec(prometheus.GaugeOpts{
			Name: "montra_circuit_breaker_state", Help: "Circuit breaker state per provider (0 closed, 1 half-open, 2 open).", ConstLabels: constLabels,
		}, []string{"breaker"}),
		breakerTransitions: prometheus.NewCounterVec(prometheus.CounterOpts{
			Name: "montra_circuit_breaker_transitions_total", Help: "Circuit breaker state changes by provider and new state.", ConstLabels: constLabels,
		}, []string{"breaker", "to"}),
		breakerRejections: prometheus.NewCounterVec(prometheus.CounterOpts{
			Name: "montra_circuit_breaker_rejections_total", Help: "Provider calls refused because the circuit breaker was open.", ConstLabels: constLabels,
		}, []string{"breaker"}),
	}
	reg.MustRegister(m.breakerState, m.breakerTransitions, m.breakerRejections)
	reg.MustRegister(m.httpRequests, m.httpDuration, m.JobsProcessed, m.JobDuration, m.JobQueueDepth,
		m.JobRetries, m.AuthEvents, m.RLSDenials, m.ProviderCalls, m.ProviderLatency, m.AICostMicroUSD,
		m.NotificationOut, m.StorageBytes, m.ImportRows, m.DeletionBacklog)
	return m
}

// ObserveHTTP records one request.
func (m *Metrics) ObserveHTTP(method, route string, status int, d time.Duration) {
	m.httpRequests.WithLabelValues(method, route, strconv.Itoa(status/100)+"xx").Inc()
	m.httpDuration.WithLabelValues(method, route).Observe(d.Seconds())
}

// breakerStateValue maps breaker state labels to the gauge value.
var breakerStateValue = map[string]float64{"closed": 0, "half_open": 1, "open": 2}

// BreakerStateChanged implements breaker.Observer. from is empty when a
// breaker is first published.
func (m *Metrics) BreakerStateChanged(name, from, to string) {
	m.breakerState.WithLabelValues(name).Set(breakerStateValue[to])
	if from != "" {
		m.breakerTransitions.WithLabelValues(name, to).Inc()
	}
}

// BreakerRejected implements breaker.Observer.
func (m *Metrics) BreakerRejected(name string) {
	m.breakerRejections.WithLabelValues(name).Inc()
}

// Handler exposes metrics, optionally protected by a bearer token.
func (m *Metrics) Handler(token string) http.Handler {
	h := promhttp.HandlerFor(m.Registry, promhttp.HandlerOpts{})
	if token == "" {
		return h
	}
	want := []byte("Bearer " + token)
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if subtle.ConstantTimeCompare([]byte(r.Header.Get("Authorization")), want) != 1 {
			w.WriteHeader(http.StatusUnauthorized)
			return
		}
		h.ServeHTTP(w, r)
	})
}
