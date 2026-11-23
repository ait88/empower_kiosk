# Debian 13 appliance bootstrap

`bootstrap.sh` is the first step for a new Empower appliance (Debian 13,
`cage` + Chromium kiosk). It is the successor to the Ubuntu scripts in
`scripts/`, which are unchanged and still serve the legacy kiosks.

It only does what needs someone at the machine: sets the hostname, sets up
sudo, installs the management SSH key, and joins the management tunnel.
Everything else is provisioned remotely afterwards.

The script contains no secrets. The SSH public key is passed as an argument
and the single-use tunnel key is typed at a hidden prompt. Always run a
pinned commit, and check the SHA-256 you were given:

```
curl -fsSLo b.sh https://raw.githubusercontent.com/ait88/empower_kiosk/<commit>/appliance/bootstrap.sh
sha256sum b.sh
sudo bash b.sh <hostname> '<ssh-ed25519 public key>'
```
