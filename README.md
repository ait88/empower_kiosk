# Empower Kiosk

A lightweight, script-based Linux kiosk setup for accessing a job management portal (Empower Factory). Designed to replace insecure legacy PCs with a minimal Ubuntu-based kiosk environment.

---

##  Requirements

- Ubuntu 22.04 LTS (Server or Minimal Install)
- Network access (to download packages and update script)
- Basic hardware (dual-core CPU, 4GB+ RAM, 10GB+ disk recommended)

---

##  Installation

Run the following commands on a fresh Ubuntu 22.04 system:

```bash
curl -O https://git.aitdev.au/pm/empower_kiosk/raw/branch/main/setup-kiosk.sh
chmod +x setup-kiosk.sh
sudo ./setup-kiosk.sh
```

## Optional Cleanup

```bash
rm setup-kiosk.sh
```