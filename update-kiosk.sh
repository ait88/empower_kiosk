#!/bin/bash
set -e

# ---- Script Version ----
VERSION="0.01-$(date +%Y%m%d)"
echo "---------------------------------------------"
echo "Empower Kiosk Update - Ver: $VERSION"
echo "---------------------------------------------"

# ---- Ensure .bash_profile is up-to-date ----
BASH_PROFILE_LOCAL="/home/kiosk/.bash_profile"
BASH_PROFILE_REPO="https://git.aitdev.au/pm/empower_kiosk/raw/branch/main/bash_profile"

curl -fsSL "$BASH_PROFILE_REPO" -o /tmp/bash_profile.new

if ! cmp -s "$BASH_PROFILE_LOCAL" /tmp/bash_profile.new; then
    cp /tmp/bash_profile.new "$BASH_PROFILE_LOCAL"
    chown kiosk:kiosk "$BASH_PROFILE_LOCAL"
    echo "✅ Updated .bash_profile from repo"
else
    echo "✅ .bash_profile already up-to-date"
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
