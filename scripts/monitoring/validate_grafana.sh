#!/usr/bin/env bash
# Run against a localhost port-forward; the password never appears in curl's argv.
set -euo pipefail
endpoint="${1:-http://127.0.0.1:3000}"
endpoint="${endpoint%/}"
repo_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)"
password_file="${2:-$repo_root/local/grafana/admin-password}"
for tool in curl jq; do command -v "$tool" >/dev/null || { echo "Missing $tool" >&2; exit 1; }; done
fail() { echo "FAIL: $*" >&2; exit 1; }
# Limit credential transmission to a local tunnel, not an arbitrary HTTP server.
[[ "$endpoint" =~ ^http://(127\.0\.0\.1|localhost):[0-9]+$ ]] || fail 'Use a localhost HTTP port-forward endpoint'
[[ -r "$password_file" ]] || fail 'Missing private password file'
password="$(tr -d '\r\n' < "$password_file")"
[[ "$password" =~ ^[a-f0-9]{64}$ ]] || fail 'Expected the documented 32-byte hex credential'
umask 077
curl_config="$(mktemp)"
trap 'rm -f -- "$curl_config"' EXIT
printf 'user = "admin:%s"\n' "$password" > "$curl_config"
unset password
http() { curl --fail --silent --show-error --connect-timeout 3 --max-time 15 "$@"; }
auth() { http --config "$curl_config" "$@"; }
health="$(http "$endpoint/api/health")"
jq -e '.database == "ok"' <<< "$health" >/dev/null || fail 'Grafana database is not healthy'
status="$(curl --silent --show-error --connect-timeout 3 --max-time 15 --output /dev/null --write-out '%{http_code}' "$endpoint/api/datasources")"
[[ "$status" == 401 ]] || fail 'Datasource API unexpectedly permits anonymous access'
datasource="$(auth "$endpoint/api/datasources/uid/prometheus")"
jq -e '.uid == "prometheus" and .type == "prometheus" and .isDefault == true and .readOnly == true and .url == "http://prometheus-server.monitoring.svc.cluster.local:80"' <<< "$datasource" >/dev/null || fail 'Datasource does not match provisioned configuration'
result="$(auth --get --data-urlencode 'query=up{job="node-exporter"}' "$endpoint/api/datasources/proxy/uid/prometheus/api/v1/query")"
jq -e '.status == "success" and (.data.result | length == 2) and ([.data.result[].metric.node] | sort == ["bronco", "yeti"]) and (.data.result | all(.value[1] == "1"))' <<< "$result" >/dev/null || fail 'Query through Grafana did not return both healthy exporters'
echo 'PASS: database health, anonymous rejection, admin authentication, provisioned datasource, and both exporters through Grafana'
