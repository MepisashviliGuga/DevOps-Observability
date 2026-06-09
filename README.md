# DevOps Observability Lab

A complete, single-command observability stack for a containerized Node.js service. It combines metrics collection, log aggregation, dashboards, and automated alerting using industry-standard open-source tools.

| Concern        | Tool                  |
|----------------|-----------------------|
| Metrics        | Prometheus            |
| Visualization  | Grafana               |
| Logging        | Loki + Promtail       |
| Instrumentation| Node.js + prom-client |
| Orchestration  | Docker Compose        |

## Project Structure

```
Devops-observability/
├── docker-compose.yml          # One-command deployment of the whole stack
├── README.md
├── src/                        # Instrumented Node.js application
│   ├── index.js                # /, /error, /metrics endpoints + JSON logger
│   ├── package.json
│   └── Dockerfile
├── config/                     # All stack configuration, grouped by tool
│   ├── prometheus/
│   │   ├── prometheus.yml       # Scrape targets
│   │   └── alerts.yml           # CRITICAL error-rate rule
│   ├── loki/
│   │   └── loki-config.yml
│   ├── promtail/
│   │   └── promtail-config.yml  # Tails JSON logs, parses fields into labels
│   └── grafana/
│       └── provisioning/        # Auto-provisioned on first boot
│           ├── datasources/     # Prometheus + Loki data sources
│           ├── dashboards/      # Custom metrics dashboard
│           └── alerting/        # Grafana-managed alert rule
└── docs/
    └── images/                  # Evidence screenshots
```

The layout separates the three responsibilities cleanly: application code lives in `src/`, every piece of stack configuration lives under `config/<tool>/`, and documentation assets live in `docs/`.

## Architecture

```
┌─────────────────────────────────────────────────────────────────────┐
│                    Docker Network (observability)                     │
│                                                                       │
│  ┌──────────────────┐  scrape /metrics  ┌───────────────────────┐    │
│  │   Node.js App    │◄──────────────────│      Prometheus       │    │
│  │   (port 3000)    │     every 15s     │      (port 9090)      │    │
│  │                  │                   └───────────┬───────────┘    │
│  │  GET /           │                               │ query metrics  │
│  │  GET /error      │               ┌───────────────▼───────────┐    │
│  │  GET /metrics    │◄── browser    │         Grafana           │    │
│  └────────┬─────────┘               │        (port 3001)        │    │
│           │ JSON logs               └───────────────────────────┘    │
│           ▼ (stdout + volume)                     ▲                   │
│  ┌──────────────────┐  tail *.log ┌───────────────┴────────────┐     │
│  │   app-logs       │◄────────────│         Promtail           │     │
│  │  Docker Volume   │             └───────────────┬────────────┘     │
│  └──────────────────┘                             │ push             │
│                                   ┌───────────────▼────────────┐     │
│                                   │            Loki            │     │
│                                   │        (port 3100)         │     │
│                                   └───────────────────────────┘      │
└─────────────────────────────────────────────────────────────────────┘
```

**Data flow**

- **Metrics:** the app exposes `/metrics`; Prometheus pulls it every 15s; Grafana queries Prometheus for dashboards and alert evaluation.
- **Logs:** the app writes one JSON object per line to a shared Docker volume; Promtail tails the file, parses the JSON, and pushes labeled streams to Loki; Grafana queries Loki in Explore.
- **Alerts:** the error-rate rule is evaluated continuously; when the rate crosses the threshold the alert moves to Firing and appears in Grafana Alerting and Prometheus.

## Quick Start

The entire system deploys with a single command:

```bash
docker compose up --build -d
```

Wait roughly 30 seconds for all services to become healthy, then open:

| Service    | URL                     | Credentials   |
|------------|-------------------------|---------------|
| App        | http://localhost:3000   | none          |
| Grafana    | http://localhost:3001   | admin / admin |
| Prometheus | http://localhost:9090   | none          |
| Loki API   | http://localhost:3100   | none          |

To tear everything down (including volumes):

```bash
docker compose down -v
```

> **First-boot note:** if the Grafana alert rule shows an error immediately after startup, run `docker compose restart grafana`. This guarantees the "Observability" folder exists before the alert rule is registered.

## Instrumentation

The service in `src/index.js` exposes three endpoints and two custom Prometheus counters:

| Endpoint   | Purpose                                   | Counters incremented            |
|------------|-------------------------------------------|---------------------------------|
| `GET /`    | Healthy request                           | `app_requests_total`            |
| `GET /error` | Simulated failure (HTTP 500)            | `app_requests_total`, `app_errors_total` |
| `GET /metrics` | Prometheus exposition format          | none                            |

Every request also emits a structured JSON log line containing `timestamp`, `level`, `message`, `endpoint`, `method`, and `status`.

## Implementation Details

### Logging Strategy

This lab uses **structured JSON logging** shipped through the **Promtail + Loki** pipeline:

- The Node.js app writes each log entry as a single-line JSON object to both **stdout** and a file inside a shared Docker named volume (`app-logs` mounted at `/app/logs/app.log`).
- **Promtail** mounts the same volume read-only, tails `*.log`, and ships every line to Loki. A pipeline stage parses the JSON and promotes `level` and `endpoint` into indexed Loki labels.
- **Loki** stores the raw log lines compressed on disk, indexed only by labels. This keeps storage small while keeping label-based queries fast.
- **Grafana Explore** (Loki data source) runs filtered queries such as `{service="app", level="error"}` in real time.

The file-and-volume approach (rather than reading the Docker socket) keeps the setup fully cross-platform across Linux, macOS, and Windows Docker Desktop.

### Triggering the CRITICAL Alert

The alert fires when the error rate exceeds **5 errors per minute**, expressed as `rate(app_errors_total[1m]) * 60 > 5`.

**1. Confirm the stack is running:**
```bash
docker compose ps
```

**2. Send a burst of errors:**

PowerShell:
```powershell
for ($i = 0; $i -lt 20; $i++) {
    Invoke-WebRequest -Uri http://localhost:3000/error -UseBasicParsing | Out-Null
}
```

Bash / Git Bash:
```bash
for i in {1..20}; do curl -s http://localhost:3000/error > /dev/null; done
```

**3. Watch it fire:**
- Grafana: **Alerting → Alert rules**, the rule "CRITICAL - High Error Rate" turns **Firing**.
- Prometheus: http://localhost:9090/alerts shows the rule active.

**4. Watch it resolve:**
- Stop sending requests; after about a minute the rate drops below the threshold and the alert returns to **Normal**.

## Evidence

### 1. Grafana dashboard with custom application metrics
![Grafana Dashboard](./docs/images/grafana-dashboard.png)

### 2. Loki log analysis showing filtered JSON logs
![Loki Logs](./docs/images/loki-logs.png)

### 3. Grafana Alerting tab with the active alert rule
![Alert Rule](./docs/images/grafana-alert.png)

## Analysis

### Why is JSON-structured logging more efficient than plain text?

JSON logging stores each entry as a machine-parseable set of key-value fields rather than a free-form string. Aggregators such as Loki and Elasticsearch can therefore index or filter on specific fields (`level`, `endpoint`, `status`) without running expensive regular expressions at query time. Filtering becomes an exact match (`level="error"`) instead of a full-text scan, which is faster and more reliable as log volume grows. It also enables type-aware, field-level filtering in Grafana with no additional parsing configuration, and it makes logs trivial to forward into other systems that expect structured input.

### What is the fundamental difference between Prometheus (metrics) and Loki (logging)?

**Prometheus** is a time-series database that **pulls** numeric samples from targets on a fixed interval. Each sample is a single float64 value tagged with labels and a timestamp; no free text is stored. It is built for mathematical aggregation (`rate()`, `histogram_quantile()`) and threshold-based alerting.

**Loki** is a log aggregation system that **receives pushed** text events. It indexes only the labels attached to each log stream, not the content of the log lines, and stores the raw text compressed in chunks. It is built for full-text search and event correlation over time.

The two are complementary: Prometheus tells you **that** something is wrong (error rate above 5 per minute), while Loki tells you **why** (the exact error and stack trace at that timestamp).

### How would you handle long-term log retention (for example 6 months) without exhausting disk?

Three complementary strategies:

1. **Retention policies.** Enable Loki's compactor with `retention_enabled: true` and `retention_period: 4320h` (180 days). The compactor garbage-collects chunks older than the window on a schedule, so disk usage stays bounded.

2. **Tiered object storage.** Replace Loki's local filesystem backend with an S3-compatible store (AWS S3, GCS, or MinIO) and move older chunks there automatically. Object storage costs roughly 10 to 20 times less per GB than local SSD and scales without manual intervention.

3. **Log volume reduction.** Avoid logging every request at `DEBUG` in production. Use `INFO` and `WARN` for steady-state operations, rely on Prometheus counters for per-request metrics rather than log lines, and add Promtail `drop` stages to discard high-frequency low-value entries (such as health-check pings) before they reach Loki.
