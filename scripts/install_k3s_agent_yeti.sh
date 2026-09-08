#!/usr/bin/env bash
# Run from the repository root: sudo bash scripts/install_k3s_agent_yeti.sh
set -euo pipefail
umask 077

test ! -e /etc/rancher/k3s/config.yaml
version=$(cat configs/k3s/version.txt)
read -r -p 'Bronco reserved IPv4 address: ' server_ip
[[ $server_ip =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}$ ]]
read -r -s -p 'Paste bronco join token (hidden): ' token
printf '\n'
test -n "$token"

install -D -m 0600 configs/k3s/agent.yaml /etc/rancher/k3s/config.yaml
sed -i "s/SERVER_IP/$server_ip/" /etc/rancher/k3s/config.yaml
printf '%s\n' "$token" > /etc/rancher/k3s/join-token
chmod 0600 /etc/rancher/k3s/join-token
unset token

curl -fsSL "https://raw.githubusercontent.com/k3s-io/k3s/$version/install.sh" |
  INSTALL_K3S_VERSION="$version" sh -s - agent
