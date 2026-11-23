#!/bin/bash
# Remote bootstrap for a fresh Debian 13 appliance Overview can't reach.
# Does only what needs someone at (or SSH'd into) the box: hostname,
# sudo, Overview's SSH key, and the Headscale tunnel. The rest (OS
# upgrade, setup.sh, checks) is done from Overview over the tunnel.
# Overview-side playbook: empower-dash appliance/ROLLOUT.md, step 1b.
#
# Usage (as root):  bootstrap.sh <hostname> 'ssh-ed25519 AAAA... comment'
# Naming: portal = empower-dash-NN, kiosk (factory floor) = emp-kiosk-NN.
# The pre-auth key is read from the terminal (hidden), never from argv.
# Paste-safe on purpose: lines under 80 chars and NO backslashes anywhere
# (some copy/paste paths mangle them). Keep it that way when editing.
set -euo pipefail
# The body is one function, called on the last line, so bash reads the
# whole script before running any of it (safe with curl ... | bash).

HEADSCALE_URL=https://hs.aitops.au
die() { echo "$*" >&2; exit 1; }

main() {
HOST="${1:-}"
PUBKEY="${2:-}"
HOST_RE='^[a-z0-9]([a-z0-9-]{0,61}[a-z0-9])?$'
KEY_RE='^ssh-ed25519 [A-Za-z0-9+/=]+( .*)?$'

[[ $EUID -eq 0 ]] || die "Run as root (sudo bash $0 ...)"
[[ $HOST =~ $HOST_RE ]] || die "Usage: $0 <hostname> 'ssh-ed25519 ...'"
[[ $PUBKEY =~ $KEY_RE ]] || die "Second argument must be an ssh-ed25519 key"
ADMIN="${SUDO_USER:-sysadmin}"
[[ $ADMIN != root ]] || ADMIN=sysadmin
id "$ADMIN" &>/dev/null || die "User $ADMIN not found"
# Subshell: os-release sets NAME, VERSION etc., which must not leak here.
# shellcheck source=/dev/null
CODENAME="$(. /etc/os-release && echo "$VERSION_CODENAME")"
[[ -n $CODENAME ]] || die "No VERSION_CODENAME in /etc/os-release"
export DEBIAN_FRONTEND=noninteractive

echo "[1/5] Hostname: $HOST"
hostnamectl set-hostname "$HOST"
sed -i '/^127.0.1.1/d' /etc/hosts
echo "127.0.1.1 $HOST" >> /etc/hosts

echo "[2/5] Packages and passwordless sudo for $ADMIN"
apt-get update -qq
apt-get install -y -qq --no-install-recommends sudo curl ca-certificates
usermod -aG sudo "$ADMIN"
SUDOERS=/etc/sudoers.d/90-empower-admin
echo "$ADMIN ALL=(ALL) NOPASSWD:ALL" > "$SUDOERS"
chmod 440 "$SUDOERS"
if ! visudo -cf "$SUDOERS" >/dev/null; then
  rm -f "$SUDOERS"
  die "sudoers check failed"
fi

echo "[3/5] Overview SSH key for $ADMIN"
HOME_DIR="$(getent passwd "$ADMIN" | cut -d: -f6)"
install -d -m 700 -o "$ADMIN" -g "$ADMIN" "$HOME_DIR/.ssh"
AK="$HOME_DIR/.ssh/authorized_keys"
touch "$AK"
grep -qxF "$PUBKEY" "$AK" || echo "$PUBKEY" >> "$AK"
chown "$ADMIN:$ADMIN" "$AK"
chmod 600 "$AK"

echo "[4/5] Tailscale client"
if ! command -v tailscale >/dev/null; then
  PKG="https://pkgs.tailscale.com/stable/debian/$CODENAME"
  RING=/usr/share/keyrings/tailscale-archive-keyring.gpg
  LIST=/etc/apt/sources.list.d/tailscale.list
  install -d -m 755 /usr/share/keyrings
  curl -fsSL "$PKG.noarmor.gpg" -o "$RING"
  curl -fsSL "$PKG.tailscale-keyring.list" -o "$LIST"
  apt-get update -qq
  apt-get install -y -qq tailscale
fi
systemctl enable --now tailscaled

echo "[5/5] Join $HEADSCALE_URL"
if tailscale ip -4 &>/dev/null; then
  echo "Already joined."
else
  KEYFILE="$(mktemp)"
  chmod 600 "$KEYFILE"
  # shellcheck disable=SC2064
  trap "shred -u $KEYFILE 2>/dev/null || rm -f $KEYFILE" EXIT
  read -rsp "Pre-auth key (hidden): " key </dev/tty
  echo
  [[ -n $key ]] || die "No key entered"
  echo "$key" > "$KEYFILE"
  unset key
  # Same flags as setup.sh: no DNS takeover, no routes, no Tailscale SSH.
  UP=(--login-server "$HEADSCALE_URL" --auth-key "file:$KEYFILE")
  UP+=(--hostname "$HOST" --accept-dns=false --accept-routes=false)
  UP+=(--ssh=false)
  timeout 90 tailscale up "${UP[@]}"
fi

echo
echo "=== Read these back to Overview ==="
echo "Tunnel IP : $(tailscale ip -4 | head -n1)"
echo "Host key  : $(ssh-keygen -lf /etc/ssh/ssh_host_ed25519_key.pub)"
PRODUCT="$(cat /sys/class/dmi/id/product_name 2>/dev/null || echo unknown)"
echo "Model     : $PRODUCT"
}

main "$@"
