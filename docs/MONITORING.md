# TheBoosh.Zone Monitoring Guide

## Overview

TheBoosh.Zone uses Prometheus for metrics collection and Grafana for visualization, with AlertManager handling alerts via Discord webhooks and email.

## Architecture

```
Application (HelloPerld)
        |
        v
   /metrics endpoint
        |
        v
    Prometheus (port 9090)
        |
        +---> Grafana (port 3001)
        |
        +---> AlertManager (port 9093)
                    |
                    +---> Discord Webhook
                    +---> Email (SMTP)
```

## Access Information

### Development Environment

| Service | URL | Credentials |
|---------|-----|-------------|
| Prometheus | http://localhost:9090 | None |
| Grafana | http://localhost:3001 | `GF_SECURITY_ADMIN_USER`/`GF_SECURITY_ADMIN_PASSWORD` from `.env` |
| AlertManager | http://localhost:9093 | None |

### Production Environment

Access is restricted to internal networks. Use SSH tunneling for remote access:

```bash
# SSH tunnel to Prometheus
ssh -L 9090:localhost:9090 user@production.theboosh.zone

# SSH tunnel to Grafana
ssh -L 3001:localhost:3001 user@production.theboosh.zone
```

## Metrics Reference

### HTTP Metrics

| Metric | Type | Labels | Description |
|--------|------|--------|-------------|
| `http_requests_total` | Counter | method, endpoint, status | Total HTTP requests |
| `http_request_duration_seconds` | Histogram | method, endpoint | Request latency distribution |
| `http_requests_in_progress` | Gauge | - | Currently processing requests |

**Example Queries:**

```promql
# Request rate per second
rate(http_requests_total[5m])

# Average request duration
histogram_quantile(0.95, rate(http_request_duration_seconds_bucket[5m]))

# Error rate (5xx responses)
sum(rate(http_requests_total{status=~"5.."}[5m])) / sum(rate(http_requests_total[5m]))
```

### Database Metrics

| Metric | Type | Labels | Description |
|--------|------|--------|-------------|
| `app_database_connection_status` | Gauge | - | 1 = connected, 0 = disconnected |
| `app_database_queries_total` | Counter | operation | Total database queries |
| `app_database_query_duration_seconds` | Histogram | operation | Query latency distribution |

**Example Queries:**

```promql
# Database connectivity
app_database_connection_status

# Query rate by operation
rate(app_database_queries_total[5m])
```

### Business Metrics

| Metric | Type | Labels | Description |
|--------|------|--------|-------------|
| `app_articles_total` | Gauge | status | Article count (published/draft) |
| `app_media_files_total` | Gauge | - | Total media files |
| `app_tags_total` | Gauge | - | Total tags |
| `app_article_views_total` | Counter | article_id, ip_hash | Article view count |
| `app_article_views_by_ip_total` | Counter | ip_hash | Views per IP hash |

**Example Queries:**

```promql
# Published article count
app_articles_total{status="published"}

# Article view rate
rate(app_article_views_total[1h])

# Top viewed articles
topk(10, sum by (article_id) (rate(app_article_views_total[24h])))
```

### Application Metrics

| Metric | Type | Labels | Description |
|--------|------|--------|-------------|
| `app_info` | Gauge | version, environment | Application version info |
| `app_errors_total` | Counter | type | Application error count |
| `app_admin_login_attempts_total` | Counter | success | Admin login attempts |
| `app_active_sessions` | Gauge | - | Estimated active sessions |

**Example Queries:**

```promql
# Failed login rate
rate(app_admin_login_attempts_total{success="false"}[5m])

# Error rate by type
sum by (type) (rate(app_errors_total[5m]))
```

## IP Hashing for Privacy

Article view tracking uses IP hashing to limit cardinality while maintaining privacy:

- **IPv4**: Last octet replaced with `x` (e.g., `192.168.1.123` -> `192.168.1.x`)
- **IPv6**: First two groups preserved (e.g., `2001:db8::1` -> `2001:db8::x`)

This approach:
- Prevents high cardinality explosion in Prometheus
- Maintains geographic/network attribution capability
- Protects individual user privacy
- Complies with privacy best practices

## AlertManager Configuration

### Required Environment Variables

| Variable | Description | Example |
|----------|-------------|---------|
| `SMTP_FROM` | Sender email address | `alerts@theboosh.zone` |
| `SMTP_USERNAME` | SMTP authentication username | `apikey` |
| `SMTP_PASSWORD` | SMTP authentication password | `SG.xxxxx` |
| `ALERT_EMAIL` | Recipient email address | `admin@theboosh.zone` |
| `DISCORD_WEBHOOK_URL` | Discord webhook URL | `https://discord.com/api/webhooks/...` |

### Alert Rules

Alerts are configured in `prometheus/alert_rules.yml`:

1. **HighErrorRate**: Triggers when 5xx error rate exceeds 5% for 5 minutes
2. **HighLatency**: Triggers when 95th percentile latency exceeds 2 seconds
3. **DatabaseDown**: Triggers when database connection is lost
4. **HighRequestRate**: Triggers when request rate exceeds normal thresholds

### Alert Thresholds

| Alert | Warning | Critical | Duration |
|-------|---------|----------|----------|
| Error Rate | 1% | 5% | 5m |
| Latency (p95) | 1s | 2s | 5m |
| Database | - | Disconnected | 30s |
| Request Rate | 100/s | 500/s | 5m |

## Grafana Dashboards

### Pre-configured Dashboards

1. **Application Overview**: HTTP metrics, error rates, latency percentiles
2. **Database Performance**: Connection status, query rates, slow queries
3. **Business Metrics**: Article counts, view trends, media uploads
4. **System Resources**: CPU, memory, disk (via node-exporter)

### Dashboard Access

Dashboards are provisioned automatically from `grafana/provisioning/dashboards/`.

Default credentials are set via environment variables:
- Username: `GF_SECURITY_ADMIN_USER`
- Password: `GF_SECURITY_ADMIN_PASSWORD`

## Runbooks

### High Error Rate

1. Check application logs: `docker compose logs -f hello-perld`
2. Review recent deployments
3. Check database connectivity: `curl http://localhost:3000/health/ready`
4. Review error types in Prometheus: `sum by (type) (rate(app_errors_total[5m]))`

### Database Connection Lost

1. Check PostgreSQL status: `docker compose ps db`
2. Review database logs: `docker compose logs db`
3. Verify connection credentials in `.env`
4. Check database health: `docker exec db pg_isready`

### High Latency

1. Check in-progress requests: `http_requests_in_progress`
2. Review slow endpoints in Grafana
3. Check database query performance
4. Review application resource usage

### Disk Space Alert

1. Check uploads directory: `du -sh uploads/`
2. Run article views cleanup: `SELECT cleanup_old_article_views(730);`
3. Review old media files for cleanup
4. Check log rotation configuration

## Maintenance Tasks

### Article Views Cleanup

The `article_views` table has a 2-year retention policy. Run cleanup periodically:

```sql
-- Delete records older than 2 years
SELECT cleanup_old_article_views(730);

-- Check current table size
SELECT pg_size_pretty(pg_total_relation_size('article_views'));

-- Count records by age
SELECT
    CASE
        WHEN viewed_at > NOW() - INTERVAL '30 days' THEN 'Last 30 days'
        WHEN viewed_at > NOW() - INTERVAL '1 year' THEN 'Last year'
        ELSE 'Older than 1 year'
    END as age_bucket,
    COUNT(*) as count
FROM article_views
GROUP BY 1;
```

### Metrics Cache

Business metrics are cached with a 60-second TTL to reduce database load. Database connections are cached with a 30-second TTL. No manual intervention required.

### View Count Aggregation

Article view counts are permanently stored on the `articles.view_count` column via a scheduled incremental aggregation job running in a Docker cron container.

**How it works:**
1. Individual views are tracked in `article_views` table (with 2-year retention)
2. Each view has a `view_indexed` flag (FALSE = not yet counted)
3. Docker cron container runs `aggregate_article_view_counts()` every hour
4. The function:
   - Counts only views where `view_indexed = FALSE`
   - Increments `articles.view_count` by the new count
   - Marks processed views as `view_indexed = TRUE`
5. This incremental approach ensures counts persist after old views are cleaned up

**Why incremental?**
- Each view is only counted once (tracked via `view_indexed` flag)
- Counts survive the 2-year `article_views` cleanup
- More efficient (only processes new views, not full recount)

**Why Docker cron instead of pg_cron?**
- pg_cron on DigitalOcean managed PostgreSQL only works on `defaultdb`
- Docker cron container works identically across all environments
- Easier to monitor and debug via container logs

**Manual aggregation:**
```bash
# Run aggregation manually via Docker
docker compose exec cron /script/aggregate-views.sh

# Check cron container logs
docker compose logs cron

# Or run directly in database
docker compose exec db psql -U $POSTGRES_USER -d $POSTGRES_DB \
  -c "SELECT aggregate_article_view_counts();"
```

**SQL queries for debugging:**
```sql
-- Check current view counts
SELECT slug, view_count FROM articles ORDER BY view_count DESC;

-- Check unprocessed views
SELECT COUNT(*) FROM article_views WHERE view_indexed = FALSE;

-- Check views per article (unprocessed)
SELECT article_slug, COUNT(*) as pending_views
FROM article_views
WHERE view_indexed = FALSE
GROUP BY article_slug;
```

**Cron Container:**
- Runs on Alpine Linux with postgresql-client
- Schedule: Every hour at minute 0 (`0 * * * *`)
- Logs output to stdout (visible via `docker compose logs cron`)
- Automatically restarts on failure

## Troubleshooting

### Metrics Endpoint Returns Error

1. Check Prometheus::Tiny::Shared file permissions
2. Verify `/tmp/hello-perld-metrics` is writable
3. Review application logs for metric initialization errors

### AlertManager Not Sending Alerts

1. Verify environment variables are set
2. Check container logs: `docker compose logs alertmanager`
3. Test webhook manually: `curl -X POST $DISCORD_WEBHOOK_URL -d '{"content":"test"}'`
4. Verify SMTP credentials are valid

### Grafana Dashboards Not Loading

1. Check Grafana logs: `docker compose logs grafana`
2. Verify Prometheus datasource connectivity
3. Check provisioning file permissions
4. Restart Grafana: `docker compose restart grafana`

## Additional Resources

- [Prometheus Documentation](https://prometheus.io/docs/)
- [Grafana Documentation](https://grafana.com/docs/)
- [AlertManager Documentation](https://prometheus.io/docs/alerting/latest/alertmanager/)
- [PromQL Cheat Sheet](https://promlabs.com/promql-cheat-sheet/)
