#!/usr/bin/env bash
set -euo pipefail
if [[ "$EUID" -ne 0 ]]; then
  echo "Run with sudo after copying this deployment bundle to the VM." >&2
  exit 1
fi
bundle_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
build_dir="${1:?Usage: sudo ./install-server.sh /absolute/path/to/linux-build}"
test -f "$build_dir/party-knight.x86_64"
test -f "$build_dir/party-knight.pck"
id party-knight >/dev/null 2>&1 || useradd --system --home-dir /var/lib/party-knight --create-home --shell /usr/sbin/nologin party-knight
install -d -o root -g root /opt/party-knight/current
systemctl stop party-knight.service 2>/dev/null || true
install -m 755 "$build_dir/party-knight.x86_64" /opt/party-knight/current/
install -m 644 "$build_dir/party-knight.pck" /opt/party-knight/current/
install -m 644 "$bundle_dir/party-knight.service" /etc/systemd/system/party-knight.service
if [[ ! -f /etc/party-knight.env ]]; then
  install -m 644 "$bundle_dir/party-knight.env.example" /etc/party-knight.env
fi
systemctl daemon-reload
systemctl enable --now party-knight.service
systemctl --no-pager status party-knight.service
echo "Allow UDP 7000 in the VM and Vultr firewalls; keep SSH access allowed."
