#!/bin/bash
set -e

# ---- Script Version ----
VERSION="0.04-$(date +%Y%m%d)"
echo ""
echo "---------------------------------------------"
echo "Empower Kiosk Update - Ver: $VERSION"
echo "---------------------------------------------"

# ---- Config File ----
CONFIG_FILE="/home/kiosk/.kiosk-config"
AUTOSTART_FILE="/home/kiosk/.config/openbox/autostart"
LOGO_FILE="/home/kiosk/logo.txt"
LOGO_URL="https://git.aitdev.au/pm/empower_kiosk/raw/branch/main/logo.txt"

# ---- Load Config ----
if [ -f "$CONFIG_FILE" ]; then
    source "$CONFIG_FILE"
else
    echo ""
    echo "[!] Config file not found: $CONFIG_FILE"
    exit 1
fi

echo "[Hostname     ] $hostname"
echo "[Portal URL   ] $portal_url"
echo "[Empower User ] $username"
echo

# ---- Update Chromium Autostart ----
# ---- Expected Autostart Template ----
EXPECTED_AUTOSTART=$(cat <<EOF
# Prevent screen blanking
xset s off
xset -dpms
xset s noblank

# Launch Chromium via external script
/home/kiosk/chromium.sh
EOF
)

# ---- Check + Update Autostart ----
if [ -f "$AUTOSTART_FILE" ]; then
    CURRENT=$(cat "$AUTOSTART_FILE")
    if [ "$CURRENT" != "$EXPECTED_AUTOSTART" ]; then
        echo "$EXPECTED_AUTOSTART" > "$AUTOSTART_FILE"
        chown kiosk:kiosk "$AUTOSTART_FILE"
        echo "[✓] Updated autostart to use chromium.sh"
    else
        echo "[✓] Autostart already up-to-date"
    fi
else
    echo "$EXPECTED_AUTOSTART" > "$AUTOSTART_FILE"
    chown kiosk:kiosk "$AUTOSTART_FILE"
    echo "[✓] Created missing autostart file"
fi

# ---- Check + Update Autostart ----
if [ -f "$AUTOSTART_FILE" ]; then
    CURRENT=$(cat "$AUTOSTART_FILE")
    if [ "$CURRENT" != "$UPDATED_AUTOSTART" ]; then
        echo ""    
        echo "$UPDATED_AUTOSTART" > "$AUTOSTART_FILE"
        chown kiosk:kiosk "$AUTOSTART_FILE"
        echo ""
        echo "[✓] Updated autostart to match portal URL"
    else
        echo ""
        echo "[✓] Autostart already up-to-date"
    fi
else
    echo ""
    echo "$UPDATED_AUTOSTART" > "$AUTOSTART_FILE"
    chown kiosk:kiosk "$AUTOSTART_FILE"
    echo ""
    echo "[✓] Created missing autostart file"
fi

# ---- Refresh Splash Logo ----
echo ""
echo -n "[~] Downloading splash logo... "
if curl -fsSL "$LOGO_URL" -o "$LOGO_FILE"; then
    chown kiosk:kiosk "$LOGO_FILE"
    echo ""
    echo "Done."
else
    echo ""
    echo "Failed to download. Keeping existing logo."
fi

# ---- Refresh Chromium Launcher Script ----
echo -n "[~] Checking chromium.sh... "
if curl -fsSL "https://git.aitdev.au/pm/empower_kiosk/raw/branch/main/chromium.sh" -o /tmp/chromium.sh; then
    if ! cmp -s /tmp/chromium.sh /home/kiosk/chromium.sh; then
        mv /tmp/chromium.sh /home/kiosk/chromium.sh
        chmod +x /home/kiosk/chromium.sh
        chown kiosk:kiosk /home/kiosk/chromium.sh
        echo "Updated."
    else
        echo "Already up-to-date."
    fi
else
    echo "Failed to download."
fi

# ---- Future Add-ons: Apply themes, push updates, reboot if needed ----
echo ""
echo "[OK] Kiosk update complete."
exit 0