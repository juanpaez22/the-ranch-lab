# Monitoring

This directory owns the versioned Prometheus and Grafana Helm values, chart-version pins, and Grafana dashboard sources. Private credentials and machine-specific scrape targets belong in ignored local files, not here.

Architecture and operational boundaries are in [MONITORING.md](../../docs/MONITORING.md). Prerequisites, installation, validation, rollback, and dashboard publishing are in [SETUP.md](../../docs/SETUP.md#prometheus-host-monitoring).
