#!/usr/bin/env bash
# Read-only checks; establish a localhost port-forward first. See docs/SETUP.md.
set -euo pipefail
endpoint="${1:-http://127.0.0.1:9095}"
endpoint="${endpoint%/}"
for tool in curl jq; do command -v "$tool" >/dev/null || { echo "Missing $tool" >&2; exit 1; }; done
fail() { echo "FAIL: $*" >&2; exit 1; }
http() { curl --fail --silent --show-error --connect-timeout 3 --max-time 15 "$@"; }
api() {
    local response
    response="$(http "$@")" || return 1
    jq -e '.status == "success"' <<< "$response" >/dev/null || fail 'Prometheus API returned an error'
    printf '%s\n' "$response"
}
http "$endpoint/-/ready" >/dev/null
config="$(api "$endpoint/api/v1/status/config")"
jq -e '.data.yaml | test("(?m)^  scrape_interval: 30s$")' <<< "$config" >/dev/null || fail 'Global interval is not 30s'
jq -e '[.data.yaml | scan("job_name: ([^\\n]+)") | .[0] | gsub("[\"\\r]"; "")] | sort == ["kube-state-metrics", "node-exporter", "prometheus"]' <<< "$config" >/dev/null || fail 'Unexpected configured scrape jobs'
targets="$(api "$endpoint/api/v1/targets")"
jq -e '
 .data.activeTargets as $t |
 ($t | length == 4) and
 ($t | all(.health == "up" and .scrapeInterval == "30s")) and
 ([$t[] | select(.labels.job == "node-exporter") | .labels.node] | sort == ["bronco", "yeti"]) and
 ([$t[] | select(.labels.job == "prometheus")] | length == 1) and
 ([$t[] | select(.labels.job == "kube-state-metrics")] | length == 1)
' <<< "$targets" >/dev/null || fail 'Expected healthy self, KSM and two host targets'
up="$(api --get --data-urlencode 'query=up{job="node-exporter"}' "$endpoint/api/v1/query")"
jq -e '(.data.result | length == 2) and (.data.result | all(.value[1] == "1")) and ([.data.result[].metric.node] | sort == ["bronco", "yeti"])' <<< "$up" >/dev/null || fail 'Exporter up series do not match both hosts'
queries=(
 'count by (node) (node_cpu_seconds_total{job="node-exporter"})'
 'count by (node) (node_memory_MemTotal_bytes{job="node-exporter"} > 0)'
 'count by (node) (node_memory_MemAvailable_bytes{job="node-exporter"} > 0)'
 'count by (node) (node_filesystem_size_bytes{job="node-exporter",mountpoint="/"} > 0)'
 'count by (node) (node_network_receive_bytes_total{job="node-exporter",device!="lo"})'
 'count by (node) (node_network_transmit_bytes_total{job="node-exporter",device!="lo"})'
 'count by (node) (rate(node_cpu_seconds_total{job="node-exporter",mode="idle"}[5m]) >= 0)'
 'count by (node) (rate(node_network_receive_bytes_total{job="node-exporter",device!="lo"}[5m]) >= 0)'
)
for query in "${queries[@]}"; do
    result="$(api --get --data-urlencode "query=$query" "$endpoint/api/v1/query")"
    jq -e '(.data.result | length == 2) and ([.data.result[].metric.node] | sort == ["bronco", "yeti"]) and (.data.result | all((.value[1] | tonumber) > 0))' <<< "$result" >/dev/null || fail "Missing host data: $query"
    printf 'PASS: %s\n' "$query"
done
ksm="$(api --get --data-urlencode 'query=up{job="kube-state-metrics"}' "$endpoint/api/v1/query")"
jq -e '(.data.result | length == 1) and (.data.result[0].value[1] == "1")' <<< "$ksm" >/dev/null || fail 'KSM is not healthy'
nodes="$(api --get --data-urlencode 'query=kube_node_status_condition{job="kube-state-metrics",condition="Ready",status="true"}' "$endpoint/api/v1/query")"
jq -e '(.data.result | length == 2) and ([.data.result[].metric.node] | sort == ["bronco", "yeti"]) and (.data.result | all(.value[1] == "1"))' <<< "$nodes" >/dev/null || fail 'KSM node readiness does not match the lab'
for query in \
 'kube_pod_info{job="kube-state-metrics",namespace="monitoring"}' \
 'kube_deployment_status_replicas_available{job="kube-state-metrics",namespace="it-tools",deployment="it-tools"} >= 1' \
 'kube_persistentvolumeclaim_status_phase{job="kube-state-metrics",namespace="monitoring",persistentvolumeclaim="prometheus-server",phase="Bound"} == 1'; do
    result="$(api --get --data-urlencode "query=$query" "$endpoint/api/v1/query")"
    jq -e '.data.result | length > 0' <<< "$result" >/dev/null || fail "Missing Kubernetes state data: $query"
    printf 'PASS: %s\n' "$query"
done
echo 'PASS: readiness, exact jobs/targets, 30s interval, host metrics and Kubernetes object state'
