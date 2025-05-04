#!/bin/bash
set -e

# ---- Script Version ----
VERSION="0.01-$(date +%Y%m%d)"
echo "---------------------------------------------"
echo "Empower Kiosk Update - Ver: $VERSION"
echo "---------------------------------------------"

# ---- Ensure .xinitrc is up-to-date ----
XINITRC_LOCAL="/home/kiosk/.xinitrc"
XINITRC_REPO="https://git.aitdev.au/pm/empower_kiosk/raw/branch/main/xinitrc"

curl -fsSL "$XINITRC_REPO" -o /tmp/xinitrc.new

if ! cmp -s "$XINITRC_LOCAL" /tmp/xinitrc.new; then
    cp /tmp/xinitrc.new "$XINITRC_LOCAL"
    chown kiosk:kiosk "$XINITRC_LOCAL"
    chmod +x "$XINITRC_LOCAL"
    echo "✅ Updated .xinitrc from repo"
else
    echo "✅ .xinitrc already up-to-date"
fi


# ---- Config File ----
CONFIG_FILE="/home/kiosk/.kiosk-config"
AUTOSTART_FILE="/home/kiosk/.config/openbox/autostart"

# ---- Load Config ----
if [ -f "$CONFIG_FILE" ]; then
    source "$CONFIG_FILE"
else
    echo "⚠️  Config file not found: $CONFIG_FILE"
    exit 1
fi

echo "🖥️ Hostname      : $hostname"
echo "🌐 Portal URL    : $portal_url"
echo "🔒 Empower User  : $username"
echo

# ---- Update Chromium Autostart ----
UPDATED_AUTOSTART=$(cat <<EOF
# Prevent screen blanking
xset s off
xset -dpms
xset s noblank

# Launch Chromium in kiosk mode
chromium-browser --kiosk --no-first-run --disable-translate --noerrdialogs --disable-infobars "$portal_url"
EOF
)

# ---- Check + Update Autostart ----
if [ -f "$AUTOSTART_FILE" ]; then
    CURRENT=$(cat "$AUTOSTART_FILE")
    if [ "$CURRENT" != "$UPDATED_AUTOSTART" ]; then
        echo "$UPDATED_AUTOSTART" > "$AUTOSTART_FILE"
        chown kiosk:kiosk "$AUTOSTART_FILE"
        echo "✅ Updated autostart to match portal URL"
    else
        echo "✅ Autostart already up-to-date"
    fi
else
    echo "$UPDATED_AUTOSTART" > "$AUTOSTART_FILE"
    chown kiosk:kiosk "$AUTOSTART_FILE"
    echo "✅ Created missing autostart file"
fi

# ---- Future Add-ons: Apply themes, push updates, reboot if needed ----

echo "🟢 Kiosk update complete."
exit 0
