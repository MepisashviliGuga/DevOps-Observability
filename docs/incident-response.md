# Incident Response Runbook

This runbook covers the most likely failure scenarios for the observability stack.

---

## Severity Levels

| Level    | Definition                                       | Response Time |
|----------|--------------------------------------------------|---------------|
| CRITICAL | App returns no responses / data loss risk        | Immediate     |
| HIGH     | Error rate > 5/min or key service unreachable    | < 5 minutes   |
| MEDIUM   | Degraded performance, partial data loss          | < 30 minutes  |
| LOW      | Minor anomaly, no user impact                    | Next business day |

---

## Incident 1 — High Error Rate (CRITICAL alert fires)

**Alert:** `HighErrorRate` — `rate(app_errors_total[1m]) * 60 > 5`

**Symptoms:** Grafana alert turns Firing; `/error` endpoint flooding.

**Steps:**
1. Confirm alert in Grafana → Alerting → Alert rules.
2. Check recent logs in Grafana → Explore → Loki:
   ```
   {service="app", level="error"}
   ```
3. Inspect app container logs:
   ```bash
   docker compose logs app --tail=50
   ```
4. If caused by a bad deploy, **rollback**:
   ```bash
   bash scripts/rollback.sh <previous-git-ref>
   ```
5. If caused by traffic spike, restart the app:
   ```bash
   docker compose restart app
   ```
6. Verify recovery: `bash scripts/validate.sh`

---

## Incident 2 — Application Container Down

**Alert:** `AppDown` — `up{job="app"} == 0`

**Symptoms:** `http://localhost:3000` unreachable.

**Steps:**
1. Check container status:
   ```bash
   docker compose ps
   docker compose logs app --tail=30
   ```
2. Attempt restart:
   ```bash
   docker compose restart app
   ```
3. If restart fails, rebuild:
   ```bash
   docker compose up --build -d app
   ```
4. If the image is broken, rollback:
   ```bash
   bash scripts/rollback.sh HEAD~1
   ```

---

## Incident 3 — Grafana Unreachable

**Symptoms:** `http://localhost:3001` returns 502/connection refused.

**Steps:**
1. Check container status:
   ```bash
   docker compose ps grafana
   docker compose logs grafana --tail=30
   ```
2. Restart Grafana (alert provisioning issue on first boot is common):
   ```bash
   docker compose restart grafana
   ```
3. If the `grafana-data` volume is corrupted, reset it (loses dashboards — they will re-provision):
   ```bash
   docker compose down
   docker volume rm <project>_grafana-data
   docker compose up -d
   ```

---

## Incident 4 — Loki / Promtail Log Gap

**Symptoms:** Loki Explore shows no logs for a time window.

**Steps:**
1. Check Promtail is running and connected:
   ```bash
   docker compose logs promtail --tail=30
   ```
2. Verify the log file exists in the shared volume:
   ```bash
   docker compose exec app ls -lh /app/logs/
   ```
3. Restart Promtail to re-establish the tail:
   ```bash
   docker compose restart promtail
   ```

---

## Rollback Procedure (Summary)

```bash
# Roll back to a specific git commit or tag
bash scripts/rollback.sh <git-ref>

# Roll back to the previous commit
bash scripts/rollback.sh HEAD~1
```

The script: takes the stack down → checks out the target ref → rebuilds → waits for health → validates.

---

## Service Level Objectives

| SLO                        | Target   | Measurement                               |
|----------------------------|----------|-------------------------------------------|
| App availability           | ≥ 99%    | `up{job="app"}` in Prometheus             |
| Error rate                 | < 1%     | `rate(app_errors_total) / rate(app_requests_total)` |
| Health check response time | < 200 ms | `app_http_duration_seconds` histogram     |

---

## Post-Incident Checklist

- [ ] Alert resolved and back to Normal in Grafana
- [ ] `bash scripts/validate.sh` passes clean
- [ ] Root cause identified in Loki logs
- [ ] `docker compose ps` shows all services Up
- [ ] Incident notes added to this doc (date, impact, resolution)
