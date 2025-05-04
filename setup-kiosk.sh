#!/bin/bash
set -e

# ---- Script Version - Manually Updated ----
VERSION="0.01-$(date +%Y%m%d)"

# ---- Default Values ----
KIOSK_USER="kiosk"
DEFAULT_HOSTNAME="empower_00"
DEFAULT_PORTAL_URL="https://factory.empowersoftware.co.nz/"
DEFAULT_WHITELIST="*.empowersoftware.co.nz"
DEFAULT_USERNAME="empower02"
DEFAULT_PASSWORD=""

# ---- Prompt Loop ----
KIOSK_HOSTNAME=$DEFAULT_HOSTNAME
PORTAL_URL=$DEFAULT_PORTAL_URL
WHITELIST=$DEFAULT_WHITELIST
EMPOWER_USER=$DEFAULT_USERNAME
EMPOWER_PASS=$DEFAULT_PASSWORD

while true; do
    clear
    echo "------------------------------------------"
    echo "Empower Kiosk Setup - Ver: $VERSION"
    echo "------------------------------------------"
    echo
    echo "Please review the following configuration options."
    echo "Press the number to change a setting, or ENTER to continue with defaults."
    echo
    echo "1. Kiosk Name / hostname : $KIOSK_HOSTNAME"
    echo "2. Portal Home Page      : $PORTAL_URL"
    echo "3. Whitelist URLs        : $WHITELIST"
    echo "4. Empower Username      : $EMPOWER_USER"
    echo "5. Empower Password      : [hidden]"
    echo
    read -rp "Select option [1-5] to edit, or ENTER to continue: " CHOICE

    case "$CHOICE" in
        1)
            read -rp "Enter hostname for this kiosk: " KIOSK_HOSTNAME
            ;;
        2)
            read -rp "Enter portal URL: " PORTAL_URL
            ;;
        3)
            read -rp "Enter comma-separated whitelist URLs: " WHITELIST
            ;;
        4)
            read -rp "Enter Empower username: " EMPOWER_USER
            ;;
        5)
            read -rsp "Enter Empower password: " EMPOWER_PASS
            echo
            ;;
        "")
            break
            ;;
        *)
            echo "Invalid choice. Press ENTER to continue."
            read
            ;;
    esac
done

# ---- Apply Hostname ----
hostnamectl set-hostname "$KIOSK_HOSTNAME"

# ---- Save Config ----
CONFIG_FILE="/home/$KIOSK_USER/.kiosk-config"
mkdir -p "/home/$KIOSK_USER"
cat > "$CONFIG_FILE" <<EOF
hostname=$KIOSK_HOSTNAME
portal_url=$PORTAL_URL
whitelist=$WHITELIST
username=$EMPOWER_USER
password=$EMPOWER_PASS
EOF

# ---- Pre-accept Microsoft Fonts EULA ----
echo "ttf-mscorefonts-installer msttcorefonts/accepted-mscorefonts-eula select true" | sudo debconf-set-selections

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
mkdir -p /home/$KIOSK_USER/.config/openbox
tee /home/$KIOSK_USER/.config/openbox/autostart >/dev/null <<EOF
# Prevent screen blanking
xset s off
xset -dpms
xset s noblank

# Launch Chromium in kiosk mode
chromium-browser --kiosk --no-first-run --disable-translate --noerrdialogs --disable-infobars "$PORTAL_URL"
EOF

# ---- .xinitrc and .bash_profile ----
tee /home/$KIOSK_USER/.xinitrc >/dev/null <<EOF
exec openbox-session
EOF

tee -a /home/$KIOSK_USER/.bash_profile >/dev/null <<EOF
# Start X session automatically
[[ -z \$DISPLAY && \$XDG_VTNR -eq 1 ]] && startx

# Pull updates from repo
curl -fsSL "https://git.aitdev.au/pm/empower_kiosk/raw/branch/main/update-kiosk.sh" | bash || echo "⚠️ Kiosk update check failed."
EOF

echo -e "\n✅ Kiosk environment installed with your custom settings."
echo "🔁 Reboot now to test automatic login, kiosk mode, and update check."

# ---- Final Ownership Fix (ensure everything is clean) ----
chown -R $KIOSK_USER:$KIOSK_USER /home/$KIOSK_USER