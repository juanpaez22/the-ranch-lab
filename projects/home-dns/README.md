# Home DNS proposal

Status: proposal for review, not an adopted design or deployed service.

Goal: choose and pilot a maintainable household DNS and application naming design.

Next decision: confirm the router's DNS handoff behavior and approve or reject a one-client Pi-hole pilot.

Promotion targets: deployment files in `apps/home-dns/`; adopted architecture and procedures in `docs/ARCHITECTURE.md` and `docs/SETUP.md`.

Private inputs: exact LAN addresses, router exports, and pilot overrides belong in ignored `local/home-dns/`.

## Recommendation

Run Pi-hole as a standalone, DNS-only container on `bronco`, outside k3s. Keep the RAX45 as the DHCP server, use `home.arpa` for host names and `apps.home.arpa` for application names, and add explicit Traefik Ingress rules for web applications.

Start with one manually configured client. Do not make Pi-hole the household resolver until the router handoff, Bronco reboot behavior, service recovery, and rollback have all been tested.

This is a good fit because it gives the network one friendly place to manage local names, adds optional ad and tracker blocking, and does not turn the GPIO-capable Raspberry Pi into an always-on household dependency. It is not highly available: if Bronco or Pi-hole is down after household rollout, local names and possibly ordinary internet name resolution will fail.

## The beginner version

Three separate jobs are involved:

1. **DHCP gives a device its network settings.** The router currently gives clients an address, a gateway, and a DNS resolver.
2. **DNS turns a name into an address.** Pi-hole could answer that `grafana.apps.home.arpa` should go to the cluster's LAN entry point.
3. **Ingress sends a web request to the right application.** Traefik sees the requested name and forwards it to Grafana, IT-Tools, or another Kubernetes Service.

```text
laptop or phone
      |
      | "Where is grafana.apps.home.arpa?"
      v
Pi-hole on bronco
      |
      | returns the cluster LAN entry-point address
      v
Traefik on the k3s nodes, ports 80/443
      |
      | matches the requested hostname
      v
Grafana Kubernetes Service -> Grafana pod
```

DNS alone does not open a port, create a route, or make an application available. For example, mapping `inference.apps.home.arpa` directly to Longhorn would still require `:19331` in the URL. Hiding that port would require a reverse proxy in front of the inference API, which is a separate decision.

## Current state

Repository documentation and read-only checks on 2026-11-01 established:

- The RAX45 provides DHCP, and the three main machines have reserved addresses.
- `bronco` is the single k3s server and also runs workloads. `yeti` is a worker. Both nodes were Ready during this review.
- k3s CoreDNS resolves names only for workloads inside Kubernetes. It is not household DNS.
- Traefik and ServiceLB expose ports 80 and 443 on the LAN nodes. K3s uses all nodes for this by default.
- IT-Tools has the only Ingress, and it has no hostname. Grafana does not yet have a LAN Ingress.
- Host-name behavior is inconsistent: Windows and mDNS cover some hosts, while WSL has not reliably resolved `.local` names.
- No household DNS service is deployed.
- Bronco has been up for about seven weeks, but it currently has neither Docker nor Podman installed. Its active `systemd-resolved` service already listens on loopback port 53.

The desired state is one predictable naming system for ordinary LAN clients:

| Name | Meaning | Destination pattern |
| --- | --- | --- |
| `bronco.home.arpa` | A physical host | Bronco's reserved address |
| `yeti.home.arpa` | A physical host | Yeti's reserved address |
| `grafana.apps.home.arpa` | A web application | Traefik, then Grafana Ingress |
| `it-tools.apps.home.arpa` | A web application | Traefik, then IT-Tools Ingress |
| `inference.apps.home.arpa` | A nonstandard-port API | Longhorn directly at first |

`home.arpa` is specifically reserved for names with meaning only inside a home network. It avoids collisions associated with invented suffixes such as `.lan`, while `.local` remains associated with multicast DNS. See [RFC 8375](https://www.rfc-editor.org/info/rfc8375/).

## Proposed components

| Component | Job | Proposed responsibility |
| --- | --- | --- |
| RAX45 router | DHCP, gateway, Wi-Fi | Keep assigning addresses and reservations. Point clients toward Pi-hole if the firmware supports a safe method. |
| Pi-hole on Bronco | LAN DNS resolver and optional filtering | Answer local records, cache results, and forward public queries to chosen upstream resolvers. Do not enable its DHCP server initially. |
| Upstream resolver | Public internet DNS | Resolve names Pi-hole does not own. This could remain the current provider or a chosen public resolver. |
| Local DNS records | Friendly private names | Store host and application mappings beneath `home.arpa`. Keep exact addresses in ignored `local/` configuration, not public Git. |
| Traefik Ingress | Web application routing | Match each `*.apps.home.arpa` HTTP host and forward it to the correct Kubernetes Service. |
| Clients | Use the resolver | Receive or temporarily set Pi-hole as their DNS server, then use friendly names. |

Pi-hole supports custom host records and a local-only DNS domain. Its official container publishes TCP and UDP port 53 and persists configuration in a volume. The relevant references are [Pi-hole configuration](https://docs.pi-hole.net/ftldns/configfile/), [Docker deployment](https://docs.pi-hole.net/docker/), and [post-install client setup](https://docs.pi-hole.net/main/post-install/).

## Why standalone on Bronco

**Advantages**

- Bronco is already an always-on, reserved-address machine.
- It keeps the Raspberry Pi available for GPIO experiments and safe to reboot or reimage.
- A Compose deployment is easier to inspect, back up, stop, and remove than adding household DNS to Kubernetes.
- DNS can keep working through an ordinary application failure inside k3s.
- Pi-hole's web interface is approachable for learning and troubleshooting.

**Costs and risks**

- Bronco becomes a household DNS dependency in addition to being the only k3s control-plane node.
- Pi-hole does not make DNS highly available. One host and one container are still one failure domain.
- Docker Engine and Compose would be new Bronco dependencies. Their networking and firewall behavior must be checked against k3s before adoption.
- Port 53 needs special care. Pi-hole documents a conflict with Ubuntu's `systemd-resolved` stub when a container publishes port 53 on every interface. Prefer testing a bind to Bronco's LAN address only before considering any resolver change. Docker supports an explicit `HOST_IP:HOST_PORT:CONTAINER_PORT` mapping. See [Pi-hole's port 53 guidance](https://docs.pi-hole.net/docker/tips-and-tricks/) and [Docker port publishing](https://docs.docker.com/get-started/docker-concepts/running-containers/publishing-ports/).
- Traefik already owns the cluster's LAN web entry points. Put the Pi-hole administration page on a separate, LAN-restricted high port rather than competing for 80/443.
- DNS query logs reveal browsing patterns. Retention and access should be kept modest and private.

These are reasons for a careful pilot, not reasons to reject Bronco.

## Router limitation to resolve first

The RAX45 manual says its DHCP service gives clients the router's own LAN address as their DNS server. It documents custom upstream DNS under internet settings, but not a separate LAN DHCP DNS field. Therefore, do not assume it can directly advertise Bronco as DNS.

During the pilot, determine which of these works on the installed firmware:

1. The router accepts Pi-hole as its upstream DNS and forwards client queries to it. This is simple, but Pi-hole may see most queries as coming from the router rather than individual clients.
2. The router can advertise Pi-hole directly through a firmware option not reflected in the manual.
3. Neither works. Keep the router unchanged for the pilot and set DNS manually on one client. If household rollout is still wanted later, evaluate moving DHCP to Pi-hole as a separate, higher-risk change.

The router manual is the authority for its current DHCP behavior: [RAX45 user manual](https://www.downloads.netgear.com/files/GDC/RAX45/RAX45_UM_EN.pdf). Pi-hole's guidance says to keep router DHCP when it can direct clients to Pi-hole, and to use Pi-hole DHCP only when the router cannot do so.

Do not configure an unrelated public resolver as a client-visible secondary DNS server. Clients may choose it instead of Pi-hole, producing intermittent failures for local names and bypassing filtering.

## Safe rollout

### Phase 1: prove DNS without household impact

1. Record the router's current DHCP/DNS settings and export its configuration if supported.
2. Confirm the exact Bronco port bindings, firewall behavior, and Docker/k3s compatibility before installing anything.
3. Create a pinned, persistent Compose definition with DNS bound only where intended and its administration page on a nonconflicting port.
4. Add a small initial record set, such as the host names and `it-tools.apps.home.arpa`.
5. Add an explicit hostname to the IT-Tools Ingress. Add Grafana Ingress only when its LAN exposure and authentication policy are accepted.
6. Manually point one test client at Pi-hole. Verify local names, ordinary internet names, blocked and allowed queries, both TCP and UDP DNS, and behavior after restarting Pi-hole.
7. Stop Pi-hole and prove the client rollback before touching the router.

### Phase 2: limited network adoption

1. Use the safest router-supported integration identified in Phase 1.
2. Renew DHCP on a few devices rather than waiting for old leases to expire.
3. Verify Windows, WSL, Linux, a phone, and the Yeti browser separately. Browser secure-DNS features can bypass the operating system resolver.
4. Reboot Bronco and verify DNS, k3s, and Pi-hole recovery.
5. Test the documented router rollback while Pi-hole is intentionally stopped.

### Phase 3: household use and resilience

Move the rest of the network only after the outage test is understood. If DNS availability becomes important, add a second resolver on a different physical host with the same local records. Do not call two resolvers redundant if only one knows the private names.

## Rollback model

Rollback must not depend on Pi-hole being healthy:

1. Restore the router's prior DNS setting, or restore the test client's prior automatic DNS setting.
2. Renew the client's DHCP lease or reconnect it to Wi-Fi.
3. Verify a public lookup through the restored resolver.
4. Stop the Pi-hole container. Leave its persistent data in place until the trial is formally abandoned.
5. Remove application Ingress names only if they are no longer useful; they are harmless when household DNS no longer publishes them.

## Other options

| Option | Good fit when | Main tradeoff here |
| --- | --- | --- |
| **AdGuard Home on Bronco** | A polished single-binary or container service with local DNS rewrites and filtering is preferred. | Similar single-host and port-53 risks. It is a credible alternative, but offers no decisive benefit for this first use case. See [AdGuard Home setup](https://adguard-dns.io/kb/adguard-home/getting-started/). |
| **Technitium DNS Server** | The goal is to learn DNS deeply, manage authoritative zones, wildcards, forwarding, or future multi-server operation. | More DNS capability and more concepts than are needed for friendly names. See [Technitium DNS Server](https://technitium.com/dns/). |
| **dnsmasq or another minimal resolver** | Only a few local records are needed and a web interface or filtering is unwanted. | Lightweight, but configuration and troubleshooting are file-oriented, and a native install is more entangled with Bronco's host resolver. |
| **Dedicated Raspberry Pi** | The Pi can become a stable appliance that is rarely rebooted or reimaged. | Excellent fault separation, but it would constrain the only GPIO-capable machine. |
| **Pi-hole inside k3s** | DNS is only experimental or the cluster has proven recovery and an independent fallback resolver. | A cluster or control-plane problem could also break household DNS. This is not recommended initially. |
| **Router names only** | The router provides reliable local records and service aliases. | The RAX45 documentation does not show the service-level DNS records needed for names such as `grafana.apps.home.arpa`. |
| **Per-machine hosts files** | An immediate zero-service experiment on one or two computers is enough. | Simple but duplicated, easy to drift, and awkward for phones and other appliances. |
| **mDNS `.local` names** | Discovering physical devices on one local link is sufficient. | It is already inconsistent in WSL and does not provide a clean service namespace or centralized records. |

## Decision requested

Approve, revise, or reject this initial direction:

- Pi-hole on Bronco as standalone Compose, not in k3s
- DNS only, with DHCP left on the RAX45
- `home.arpa` for hosts and `apps.home.arpa` for services
- one-client pilot before router or household changes
- explicit Traefik Ingress per web application

If approved, the next task should be an implementation plan and preflight check, including the router's actual firmware options, Docker/k3s coexistence, exact port ownership, firewall scope, version pin, persistence, validation, and rollback. No operational change was made as part of this proposal.
