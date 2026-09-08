#!/usr/bin/env bash
# Run from the repository root: sudo bash scripts/install_k3s_server_bronco.sh
set -euo pipefail

# Refuse to overwrite an existing installation's configuration.
test ! -e /etc/rancher/k3s/config.yaml
version=$(cat configs/k3s/version.txt)
install -D -m 0600 configs/k3s/server.yaml /etc/rancher/k3s/config.yaml

curl -fsSL "https://raw.githubusercontent.com/k3s-io/k3s/$version/install.sh" |
  INSTALL_K3S_VERSION="$version" sh -s - server
