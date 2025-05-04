#!/bin/bash
set -e

# ---- Configurable ----
KIOSK_USER="kiosk"
UPDATE_SCRIPT_URL="https://git.aitdev.au/pm/empower_kiosk/raw/branch/main/update-kiosk.sh"

# ---- Prompt for Portal URL ----
read -rp "Enter the job management portal URL (e.g. https://factory.empowersoftware.co.nz/): " PORTAL_URL

# ---- Base Packages ----
apt update
apt install -y --no-install-recommends \
    xorg xinit openbox chromium-browser \
    fonts-dejavu ttf-mscorefonts-installer \
    lightdm

# ---- Create Kiosk User ----
adduser --disabled-password --gecos "" $KIOSK_USER
usermod -aG video,audio $KIOSK_USER

# ---- LightDM Autologin ----
mkdir -p /etc/lightdm/lightdm.conf.d
cat > /etc/lightdm/lightdm.conf.d/50-myconfig.conf <<EOF
[Seat:*]
autologin-user=$KIOSK_USER
autologin-user-timeout=0
user-session=openbox
EOF

# ---- Openbox Autostart ----
sudo -u $KIOSK_USER mkdir -p /home/$KIOSK_USER/.config/openbox
sudo -u $KIOSK_USER tee /home/$KIOSK_USER/.config/openbox/autostart >/dev/null <<EOF
# Prevent screen blanking
xset s off
xset -dpms
xset s noblank

# Launch Chromium in kiosk mode
chromium-browser --kiosk --no-first-run --disable-translate --noerrdialogs --disable-infobars "$PORTAL_URL"
EOF

# ---- .xinitrc and .bash_profile ----
sudo -u $KIOSK_USER tee /home/$KIOSK_USER/.xinitrc >/dev/null <<EOF
exec openbox-session
EOF

sudo -u $KIOSK_USER tee -a /home/$KIOSK_USER/.bash_profile >/dev/null <<EOF
# Start X session automatically
[[ -z \$DISPLAY && \$XDG_VTNR -eq 1 ]] && startx

# Pull updates from repo
curl -fsSL "$UPDATE_SCRIPT_URL" | bash || echo "⚠️ Kiosk update check failed."
EOF

# ---- Final Permissions ----
chown -R $KIOSK_USER:$KIOSK_USER /home/$KIOSK_USER

echo -e "\n✅ Kiosk environment installed."
echo "🔁 Reboot now to test automatic login, kiosk mode, and update check."
