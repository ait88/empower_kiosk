#!/bin/bash
set -e

# ---- Script Version - Manually Updated ----
VERSION="1.02"

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

# ---- Remove LightDM Autologin Config ----
systemctl disable lightdm.service || true
rm -f /etc/lightdm/lightdm.conf.d/50-myconfig.conf

# ---- Disable Plymouth and getty on tty1 ----
systemctl mask \
  plymouth-start.service \
  plymouth-quit.service \
  plymouth-quit-wait.service \
    getty@tty1.service || true

# ---- Remove splash and quiet from GRUB and set clean params ----
sed -i 's/\<splash\>//g; s/\<quiet\>//g' /etc/default/grub
sed -i 's/GRUB_CMDLINE_LINUX_DEFAULT="/&quiet splash console=tty1 /' /etc/default/grub
update-grub

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

# ---- .xinitrc ----
tee /home/$KIOSK_USER/.xinitrc >/dev/null <<EOF
exec openbox-session
EOF

# ---- Kiosk Startup Splash Script ----
tee /home/$KIOSK_USER/kiosk-startup.sh >/dev/null <<EOF
#!/bin/bash
clear
cat /home/$KIOSK_USER/logo.txt
echo -e "\n🔍 Checking for updates..."
sleep 1

# Uncomment below when ready
# curl -fsSL "https://git.aitdev.au/pm/empower_kiosk/raw/branch/main/update-kiosk.sh" | bash

echo "✅ System ready. Launching kiosk..."
sleep 3

sudo chown kiosk:tty /dev/tty1 2>/dev/null || true
sleep 1
startx
EOF

# ---- Download ASCII Logo ----
curl -fsSL "https://git.aitdev.au/pm/empower_kiosk/raw/branch/main/logo.txt" -o /home/$KIOSK_USER/logo.txt
chown $KIOSK_USER:$KIOSK_USER /home/$KIOSK_USER/logo.txt

# ---- Update Permissions ----
usermod -aG tty $KIOSK_USER
chmod +x /home/$KIOSK_USER/kiosk-startup.sh
chown -R $KIOSK_USER:$KIOSK_USER /home/$KIOSK_USER

# ---- Systemd Splash Service ----
tee /etc/systemd/system/kiosk-splash.service >/dev/null <<EOF
[Unit]
Description=Kiosk Splash Screen
After=local-fs.target
Before=getty@tty1.service

[Service]
User=kiosk
Type=oneshot
ExecStart=/home/kiosk/kiosk-startup.sh
StandardOutput=tty
StandardError=tty
TTYPath=/dev/tty1
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
EOF

# ---- Enable Service AFTER it exists ----
systemctl daemon-reload
systemctl enable kiosk-splash.service

# ---- Final Ownership Fix ----
chown -R $KIOSK_USER:$KIOSK_USER /home/$KIOSK_USER

echo -e "\n✅ Kiosk environment installed with your custom settings."
echo "🔁 Reboot now to test splash screen and kiosk launch."
