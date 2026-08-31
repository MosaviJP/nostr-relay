package main

import (
	"context"
	"log/slog"
	"sync/atomic"
	"time"
)

// fanoutMetrics collects runtime metrics for cross-instance event fanout via
// Redis Pub/Sub: atomic counters + a periodic log line (counters are swapped
// to zero each period).
type fanoutMetrics struct {
	PubOK   atomic.Int64 // BroadcastEvent publishes succeeded
	PubFail atomic.Int64 // BroadcastEvent publishes failed

	RecvTotal     atomic.Int64 // messages received from other instances
	UnmarshalFail atomic.Int64 // envelope unmarshal failures

	DropQueueFull atomic.Int64 // dropped: inject queue full
	DropExpired   atomic.Int64 // dropped: exceeded TTL while queued
	DropTimeout   atomic.Int64 // dropped: timed out waiting for downstream
	Delivered     atomic.Int64 // successfully injected into relayer

	// Fanout latency: remote publish -> local injection complete. Depends on
	// the envelope ts_us field; messages from older instances lack it and are
	// not counted.
	LatCount atomic.Int64 // deliveries with a latency sample
	LatSumUS atomic.Int64 // total latency (microseconds)
	LatMaxUS atomic.Int64 // max single-message latency in the period (microseconds)
}

// observeLatency records one fanout latency sample in microseconds.
// Negative values from clock skew are clamped to zero.
func (m *fanoutMetrics) observeLatency(us int64) {
	if us < 0 {
		us = 0
	}
	m.LatCount.Add(1)
	m.LatSumUS.Add(us)
	for {
		cur := m.LatMaxUS.Load()
		if us <= cur || m.LatMaxUS.CompareAndSwap(cur, us) {
			return
		}
	}
}

const fanoutLogEvery = 30 * time.Second

// runLogger periodically logs one snapshot line. Counters are swapped to zero,
// so logged values are deltas over the past period.
func (m *fanoutMetrics) runLogger(ctx context.Context) {
	ticker := time.NewTicker(fanoutLogEvery)
	defer ticker.Stop()
	for {
		select {
		case <-ctx.Done():
			return
		case <-ticker.C:
			cnt := m.LatCount.Swap(0)
			sumUS := m.LatSumUS.Swap(0)
			maxUS := m.LatMaxUS.Swap(0)
			var avgUS int64
			if cnt > 0 {
				avgUS = sumUS / cnt
			}
			slog.Info("[fanout-metrics]",
				"pub_ok", m.PubOK.Swap(0),
				"pub_fail", m.PubFail.Swap(0),
				"recv", m.RecvTotal.Swap(0),
				"unmarshal_fail", m.UnmarshalFail.Swap(0),
				"delivered", m.Delivered.Swap(0),
				"drop_queue_full", m.DropQueueFull.Swap(0),
				"drop_expired", m.DropExpired.Swap(0),
				"drop_timeout", m.DropTimeout.Swap(0),
				"lat_us_avg", avgUS,
				"lat_us_max", maxUS,
			)
		}
	}
}
