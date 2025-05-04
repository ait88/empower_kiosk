#!/bin/bash
set -e

REPO_URL="https://git.aitdev.au/pm/empower_kiosk/raw/branch/main"
SCRIPT_NAME="update-kiosk.sh"

echo "🔄 Checking for updates..."

# Pull latest autostart config (example)
curl -fsSL "$REPO_URL/autostart" -o "$HOME/.config/openbox/autostart.new" || {
    echo "⚠️ Failed to fetch update. Keeping current config."
    exit 1
}

# Replace if different
if ! cmp -s "$HOME/.config/openbox/autostart" "$HOME/.config/openbox/autostart.new"; then
    mv "$HOME/.config/openbox/autostart.new" "$HOME/.config/openbox/autostart"
    chmod +x "$HOME/.config/openbox/autostart"
    echo "✅ Updated autostart configuration."
else
    rm "$HOME/.config/openbox/autostart.new"
    echo "✅ No changes detected."
fi

# Optional: pull other scripts/configs

echo "🟢 Kiosk update check complete."
