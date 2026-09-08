# Connection interruption review

- Owner reported brief SSH interruptions to both laptops after changing the agent endpoint.
- Read-only logs confirm yeti registered with the server around 21:23, lost cluster connectivity around 21:24-21:26, and recovered automatically at 21:26:19-20 (Pacific time).
- Neither machine rebooted; both SSH services remained running since boot. No failed system units, observed OOM events, or observed suspend events in the inspected interval. Memory and disk availability were healthy; swap was unused.
- Yeti logged a NetworkManager assertion at 21:24:41, but the service did not restart. This is a correlation, not a confirmed cause. No physical Wi-Fi disconnect was found in the inspected laptop logs. Windows event queries returned no matching records.
- Subsequent five-packet peer tests had zero packet loss, but latency varied substantially (roughly 3-309 ms across both tests). The limited sample does not establish sustained network reliability.
- Server and agent services are active. Both API paths responded with authentication-required responses; no further matching k3s warnings/errors appeared in the checked post-recovery interval.
- Full node/pod readiness and encryption status could not be inspected because sudo requires interactive authentication. The owner should run the documented kubectl checks on bronco.
- No remote settings changed. Exact cause of the simultaneous SSH interruptions remains unconfirmed.
