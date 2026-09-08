#!/usr/bin/env bash
# Initial installation only. Run with sudo from an interactive terminal.
set -euo pipefail
set +x
umask 077

fail() { printf '%s\n' "$*" >&2; exit 1; }
[[ $EUID -eq 0 ]] || fail 'Run with sudo bash scripts/install-k3s.sh server|agent'
role=${1:-}
case "$role" in
  server) expected_host=bronco ;;
  agent) expected_host=yeti ;;
  *) fail 'Usage: sudo bash scripts/install-k3s.sh server|agent' ;;
esac
[[ $(hostname -s) == "$expected_host" ]] || fail "This role is intended for $expected_host."
repo_root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
version=$(tr -d '\r\n' < "$repo_root/configs/k3s/version.txt")
[[ $version =~ ^v[0-9]+\.[0-9]+\.[0-9]+\+k3s[0-9]+$ ]] || fail 'Invalid version pin.'
command -v curl >/dev/null || fail 'Install curl first.'
if command -v k3s >/dev/null || [[ -e /var/lib/rancher/k3s/server/db ]]; then
  fail 'Existing k3s detected. This script is for initial installation, not upgrades or resets.'
fi
if command -v ufw >/dev/null && ufw status | grep -q '^Status: active'; then
  fail 'UFW is active. Review cluster firewall rules before installing; this script does not change UFW.'
fi
if [[ $role == agent ]]; then
  getent ahostsv4 bronco.local >/dev/null || fail 'Cannot resolve bronco.local.'
fi
config=/etc/rancher/k3s/config.yaml
if [[ -e $config ]] && ! cmp -s "$repo_root/configs/k3s/$role.yaml" "$config"; then
  fail 'Existing configuration differs; inspect it before proceeding.'
fi
if [[ -d /etc/rancher/k3s/config.yaml.d ]] &&
   find /etc/rancher/k3s/config.yaml.d -name '*.yaml' -print -quit | grep -q .; then
  fail 'Existing configuration drop-ins found; inspect them before proceeding.'
fi

installer=$(mktemp /tmp/ranch-k3s-installer.XXXXXX)
trap 'rm -f -- "$installer"' EXIT
# Pin the upstream installer source as well as its binary release.
curl --fail --silent --show-error --location --retry 2 \
  --connect-timeout 15 --max-time 120 \
  "https://raw.githubusercontent.com/k3s-io/k3s/$version/install.sh" -o "$installer"
sh -n "$installer"

install -d -m 0755 /etc/rancher/k3s
install -m 0600 "$repo_root/configs/k3s/$role.yaml" "$config"
if [[ $role == agent ]]; then
  printf 'Paste the server join token (hidden input), then press Enter: ' >/dev/tty
  IFS= read -r -s token </dev/tty
  printf '\n' >/dev/tty
  [[ $token == K10*::* ]] || fail 'Expected the full secure join token from the server.'
  printf '%s\n' "$token" > /etc/rancher/k3s/join-token
  chmod 0600 /etc/rancher/k3s/join-token
  unset token
fi
env -i PATH="$PATH" INSTALL_K3S_VERSION="$version" sh "$installer" "$role"
if [[ $role == server ]]; then
  systemctl is-active k3s
  k3s kubectl wait --for=condition=Ready node/bronco --timeout=180s
  k3s secrets-encrypt status
else
  systemctl is-active k3s-agent
fi
printf 'Installed %s role using %s. Follow docs/K3S_INSTALL.md for cluster verification.\n' "$role" "$version"
