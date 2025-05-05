#!/bin/bash
set -e

# ---- Script Version - Manually Updated ----
VERSION="1.05"

# ---- Default Values ----
KIOSK_USER="kiosk"
DEFAULT_HOSTNAME="empower_00"
DEFAULT_PORTAL_URL="https://factory.empowersoftware.co.nz/"
DEFAULT_WHITELIST="*.empowersoftware.co.nz"
DEFAULT_USERNAME="empower02"
DEFAULT_PASSWORD="xxxxxxxxx"
DEFAULT_BRANCH="main"

# ---- Prompt Loop ----
KIOSK_HOSTNAME=$DEFAULT_HOSTNAME
PORTAL_URL=$DEFAULT_PORTAL_URL
WHITELIST=$DEFAULT_WHITELIST
EMPOWER_USER=$DEFAULT_USERNAME
EMPOWER_PASS=$DEFAULT_PASSWORD
BRANCH=$DEFAULT_BRANCH

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
    echo "5. Empower Password      : $DEFAULT_PASSWORD"
    echo "6. Git Branch            : $BRANCH"
    echo
    read -rp "Select option [1-6] to edit, or ENTER to continue: " CHOICE

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
        6)
            read -rp "Enter git branch to use [main/dev/...]: " BRANCH
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
branch=$BRANCH
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
adduser --disabled-password --gecos "" $KIOSK_USER || true
usermod -aG video,audio $KIOSK_USER

# ---- Remove LightDM Autologin Config ----
systemctl disable lightdm.service || true
rm -f /etc/lightdm/lightdm.conf.d/50-myconfig.conf

# ---- Disable Plymouth ----
systemctl mask \
  plymouth-start.service \
  plymouth-quit.service \
  plymouth-quit-wait.service || true

# ---- Unmask and Auto-login to tty1 ----
systemctl unmask getty@tty1.service
mkdir -p /etc/systemd/system/getty@tty1.service.d
tee /etc/systemd/system/getty@tty1.service.d/override.conf >/dev/null <<EOF
[Service]
ExecStart=
ExecStart=-/sbin/agetty --autologin $KIOSK_USER --noclear %I \$TERM
EOF

# ---- Update GRUB ----
sed -i 's/\<splash\>//g; s/\<quiet\>//g' /etc/default/grub
sed -i 's/GRUB_CMDLINE_LINUX_DEFAULT="/GRUB_CMDLINE_LINUX_DEFAULT="quiet splash console=tty1 /' /etc/default/grub
update-grub

# ---- Write Openbox Autostart ----
AUTOSTART_FILE="/home/$KIOSK_USER/.config/openbox/autostart"
mkdir -p "$(dirname "$AUTOSTART_FILE")"
cat > "$AUTOSTART_FILE" <<EOF
# Prevent screen blanking
xset s off
xset -dpms
xset s noblank

# Launch Chromium via external script
/home/$KIOSK_USER/chromium.sh
EOF

chown $KIOSK_USER:$KIOSK_USER "$AUTOSTART_FILE"
chmod +x "$AUTOSTART_FILE"

# ---- Download Chromium Launcher ----
curl -fsSL "https://git.aitdev.au/pm/empower_kiosk/raw/${BRANCH}/main/chromium.sh" -o /home/$KIOSK_USER/chromium.sh
chmod +x /home/$KIOSK_USER/chromium.sh
chown $KIOSK_USER:$KIOSK_USER /home/$KIOSK_USER/chromium.sh


# ---- .xinitrc ----
tee /home/$KIOSK_USER/.xinitrc >/dev/null <<EOF
exec openbox-session
EOF

# ---- Kiosk Splash Script ----
tee /home/$KIOSK_USER/kiosk-startup.sh >/dev/null <<EOF
#!/bin/bash
clear
cat /home/$KIOSK_USER/logo.txt
echo -e " Checking for updates..."
sleep 3

# ---- Update Script URL ----
curl -fsSL "https://git.aitdev.au/pm/empower_kiosk/raw/branch/${BRANCH}/update-kiosk.sh" | bash

echo " [✓] System ready. Launching kiosk..."
sleep 5
startx
EOF

# ---- Download ASCII Logo ----
curl -fsSL "https://git.aitdev.au/pm/empower_kiosk/raw/${BRANCH}/main/logo.txt" -o /home/$KIOSK_USER/logo.txt

# ---- Permissions ----
usermod -aG tty $KIOSK_USER
chmod +x /home/$KIOSK_USER/kiosk-startup.sh
chown -R $KIOSK_USER:$KIOSK_USER /home/$KIOSK_USER

# ---- .bash_profile triggers startup ----
tee -a /home/$KIOSK_USER/.bash_profile >/dev/null <<EOF
[[ -z \$DISPLAY && \$XDG_VTNR -eq 1 ]] && bash ~/kiosk-startup.sh
EOF

# ---- Finalize ----
systemctl daemon-reexec
systemctl daemon-reload

echo -e "\n✅ Kiosk environment installed with your custom settings."
echo "🔁 Reboot now to test splash screen and kiosk launch."
