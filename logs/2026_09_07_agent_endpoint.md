# Agent endpoint correction

- Server service is running; agent service remains activating with repeated CA-retrieval failures through its local proxy.
- Shell mDNS lookup/direct curl succeeded, while system DNS lookup failed. This supports a resolver-path mismatch as the leading diagnosis.
- Owner authorized direct-IP configuration. Verified bronco's LAN address privately; updated the public template and installer to prompt for an address without storing it in Git.
- Live endpoint edit and service restart are blocked by interactive sudo authentication. Documented a targeted edit that preserves the token-file setting; no reinstall is needed.
- Successful agent registration remains unverified.
