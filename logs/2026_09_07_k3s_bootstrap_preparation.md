# K3s bootstrap preparation

- Owner approved TLS SAN and secrets encryption, retained defaults otherwise, and accepted no backups for the disposable initial cluster.
- Resolved official stable channel to `v1.36.4+k3s1` and pinned both installer source tag and binary version.
- Added server/agent templates, an initial-install wrapper with a hidden token prompt, and verification/rebuild instructions.
- Confirmed curl on both laptops. Staged scripts and configuration in unique temporary directories on both hosts.
- Bash syntax checks passed on both hosts; staged script SHA256 values matched. The pinned upstream installer URL returned HTTP 200.
- Privileged installation has not run. Interactive sudo by the owner is required; node readiness, encryption, image pulls, and workload networking remain unverified.
