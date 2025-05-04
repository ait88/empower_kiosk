```markdown
# Empower Kiosk

A lightweight, script-driven Linux kiosk for accessing the Empower Factory job management portal. Designed to replace insecure legacy Windows PCs with a minimal, managed Ubuntu-based environment.

---

## ✅ Requirements

- Ubuntu **22.04 LTS** (minimal or server install recommended)
- Basic hardware (e.g., dual-core CPU, 4GB+ RAM, 10GB+ disk)
- Internet access (for setup and auto-updates)

---

## 🚀 Installation

Run the following commands on a fresh Ubuntu 22.04 system:

```bash
curl -O https://git.aitdev.au/pm/empower_kiosk/raw/branch/main/setup-kiosk.sh
chmod +x setup-kiosk.sh
sudo ./setup-kiosk.sh
```

This will:
- Install a minimal graphical environment with Chromium in kiosk mode
- Configure auto-login to a locked-down kiosk user
- Prompt for site and login details
- Schedule automatic updates at each boot

---

## 🔁 Automatic Updates

Each time the kiosk boots:
- The latest update script is pulled from this repo
- Config files (e.g. `autostart`, `.xprofile`) are patched as needed
- The kiosk environment is re-applied in an idempotent way

Logs are written to:  
`/home/kiosk/kiosk-update.log`

---

## 🧹 Optional Cleanup

```bash
rm setup-kiosk.sh
```

---

## 💡 Project Goals

- Fully self-updating
- Git-managed, replicable configuration
- Minimal attack surface
- Runs on older or low-spec hardware
```