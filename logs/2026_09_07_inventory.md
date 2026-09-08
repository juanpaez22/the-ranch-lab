# Laptop inventory after SSH key setup

## Actions

- Retested both hosts using noninteractive SSH with strict host-key checking and host-key updates disabled; both returned their expected hostnames.
- Read CPU, memory, disk, model, OS, kernel, uptime, failed-unit status, reboot markers, and logind configuration.
- Added a sanitized inventory to the architecture document and marked the earlier SSH access blockers resolved.

## Outcome

- Verified hardware and OS details for both laptops without changing their configuration.
- Both have reboot-required markers. `bronco` reports a failed `grub2-common.service`; `yeti` reports no failed system units.
- No explicit active lid-handling assignments were returned by the logind configuration check. Physical lid behavior remains untested.

## Pending

- Diagnose the failed boot-record service on `bronco`.
- Reboot at an approved time and verify SSH, service health, and closed-lid behavior.
- Keep WSL hostname resolution and cluster readiness as separate checks.
