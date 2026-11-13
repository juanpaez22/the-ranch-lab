# Monitoring

Status: supported deployment across the k3s cluster and Longhorn exporters.

This app owns the Prometheus and Grafana Helm values, chart and exporter version pins, dashboards, exporter service definitions, and monitoring-specific automation.

- `prometheus/` and `grafana/`: Kubernetes deployment configuration and dashboards.
- `exporters/`: pinned versions and service definitions for host exporters.
- `scripts/`: installation, publication, and validation helpers.

Architecture and operational boundaries are in [MONITORING.md](../../docs/MONITORING.md). Prerequisites, installation, validation, rollback, and dashboard publishing are in [SETUP.md](../../docs/SETUP.md#prometheus-host-monitoring).

Keep credentials, exact scrape addresses, installed-file backups, and diagnostic output in ignored `local/monitoring/`. Repository changes do not alter the live cluster or hosts. Use the linked runbooks to validate or roll back each component, and uninstall exporters or Helm releases only with explicit operational authorization.
