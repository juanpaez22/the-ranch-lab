#!/usr/bin/env python3
"""Publish repository dashboard JSON, or check saved definitions and literal queries."""
import argparse
import base64
import json
import math
from pathlib import Path
import re
import sys
from urllib.error import HTTPError, URLError
from urllib.parse import urlencode
from urllib.request import ProxyHandler, Request, build_opener

ROOT = Path(__file__).resolve().parents[2]
DASHBOARDS = ROOT / "apps/monitoring/grafana/dashboards"


def matches(source, saved):
    # Grafana owns numeric IDs/revisions; the repository owns its authored fields.
    return all(saved.get(k) == v for k, v in source.items() if k not in {"id", "version"})


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("files", nargs="*", type=Path, help="Default: all repository dashboards")
    parser.add_argument("--endpoint", default="http://127.0.0.1:3000")
    parser.add_argument("--password-file", type=Path, default=ROOT / "local/grafana/admin-password")
    parser.add_argument("--check", action="store_true", help="Read-only definition and query checks")
    args = parser.parse_args()
    endpoint = args.endpoint.rstrip("/")
    if not re.fullmatch(r"http://(?:127\.0\.0\.1|localhost):[0-9]+", endpoint):
        raise ValueError("Use a localhost HTTP port-forward endpoint")
    files = args.files or sorted(DASHBOARDS.glob("*.json"))
    if not files:
        raise ValueError("No dashboard files found")
    sources = [json.loads(p.read_text()) for p in files]
    uids = set()
    for source in sources:
        uid = source.get("uid", "")
        if not re.fullmatch(r"[A-Za-z0-9_-]{1,40}", uid) or uid in uids:
            raise ValueError("Each dashboard needs a unique, stable UID")
        uids.add(uid)
        if not source.get("title") or not isinstance(source.get("panels"), list):
            raise ValueError(f"Invalid dashboard structure: {uid}")
        if source.get("id") is not None or source.get("version", 0) != 0:
            raise ValueError(f"Remove instance-specific id/version fields: {uid}")
    password = args.password_file.read_text().strip()
    if not re.fullmatch(r"[a-f0-9]{64}", password):
        raise ValueError("Expected the documented private 32-byte hex credential")
    authorization = "Basic " + base64.b64encode(f"admin:{password}".encode()).decode()
    opener = build_opener(ProxyHandler({}))

    def api(path, payload=None):
        request = Request(endpoint + path, data=None if payload is None else json.dumps(payload).encode())
        request.add_header("Authorization", authorization)
        request.add_header("Content-Type", "application/json")
        try:
            with opener.open(request, timeout=15) as response:
                return json.load(response)
        except HTTPError as error:
            # Do not print request headers, credentials, or arbitrary response bodies.
            raise RuntimeError(f"Grafana HTTP {error.code} at {path.split('?')[0]}") from None

    for source in sources:
        uid = source["uid"]
        path = f"/api/dashboards/uid/{uid}"
        try:
            saved = api(path)
        except RuntimeError as error:
            if not str(error).startswith("Grafana HTTP 404 ") or args.check:
                raise
            saved = None
        if not args.check and (saved is None or not matches(source, saved["dashboard"])):
            result = api("/api/dashboards/db", {"dashboard": source, "overwrite": True,
                                               "message": "Apply repository dashboard"})
            if result.get("status") != "success" or result.get("uid") != uid:
                raise RuntimeError(f"Dashboard save failed: {uid}")
            saved = api(path)
            action = "Published"
        else:
            action = "Checked" if args.check else "Unchanged"
        if saved is None or not matches(source, saved["dashboard"]):
            raise RuntimeError(f"Saved dashboard differs from repository: {uid}")
        if args.check:
            queries = 0
            # Literal queries only. Template-variable dashboards need explicit query bindings.
            pending = list(source["panels"])
            while pending:
                panel = pending.pop(0)
                pending.extend(panel.get("panels", []))
                for target in panel.get("targets", []):
                    expression = target.get("expr")
                    if not expression:
                        continue
                    if re.search(r"\$[A-Za-z_{]", expression):
                        raise ValueError(f"Bind template variables before checking {uid}")
                    datasource = target.get("datasource", panel.get("datasource", {}))
                    if datasource.get("uid") != "prometheus":
                        raise ValueError(f"Unsupported datasource in {uid}")
                    result = api("/api/datasources/proxy/uid/prometheus/api/v1/query?" + urlencode({"query": expression}))
                    rows = result.get("data", {}).get("result", [])
                    if result.get("status") != "success" or not rows:
                        raise RuntimeError(f"Empty or failed query in {uid}, panel {panel.get('id')}")
                    if not all("value" in row and math.isfinite(float(row["value"][1])) for row in rows):
                        raise RuntimeError(f"Non-finite/non-vector result in {uid}")
                    queries += 1
            if not queries:
                raise ValueError(f"No Prometheus expressions checked: {uid}")
            print(f"PASS: {uid}: saved definition and {queries} queries")
        else:
            print(f"{action}: {endpoint}{saved['meta']['url']}")


if __name__ == "__main__":
    try:
        main()
    except (ValueError, KeyError, OSError, RuntimeError, URLError) as error:
        print(f"FAIL: {error}", file=sys.stderr)
        sys.exit(1)
