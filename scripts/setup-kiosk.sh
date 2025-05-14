#!/bin/bash
set -e

# ---- Script Version - Manually Updated ----
VERSION="1.07"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_FILE="/var/log/kiosk-setup.log"

# ---- Default Values ----
KIOSK_USER="kiosk"
DEFAULT_HOSTNAME="empower_00"
DEFAULT_PORTAL_URL="https://factory.empowersoftware.co.nz/"
DEFAULT_WHITELIST="*.empowersoftware.co.nz"
DEFAULT_USERNAME="empower02"
DEFAULT_PASSWORD="xxxxxxxxx"
DEFAULT_BRANCH="main"
DEFAULT_DISTRO="minimal"  # Options: minimal, lubuntu, xubuntu, debian-minimal

# ---- Logging Functions ----
function log_info() {
    echo -e "\e[36m[INFO]\e[0m $1"
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] INFO: $1" >> "$LOG_FILE"
}

function log_success() {
    echo -e "\e[32m[SUCCESS]\e[0m $1"
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] SUCCESS: $1" >> "$LOG_FILE"
}

function log_warning() {
    echo -e "\e[33m[WARNING]\e[0m $1" >&2
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] WARNING: $1" >> "$LOG_FILE"
}

function log_error() {
    echo -e "\e[31m[ERROR]\e[0m $1" >&2
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] ERROR: $1" >> "$LOG_FILE"
}

function log_progress() {
    local message="$1"
    local progress="$2"
    local total="$3"
    
    if [[ -n "$progress" && -n "$total" ]]; then
        local percent=$((progress * 100 / total))
        echo -ne "\e[36m[PROGRESS]\e[0m $message ($progress/$total) - $percent% \r"
    else
        echo -e "\e[36m[PROGRESS]\e[0m $message"
    fi
}

# ---- Error Handling ----
function handle_error() {
    log_error "Setup failed at step: $1"
    log_error "Please check the log file at $LOG_FILE for details"
    exit 1
}

# Set up error trap
trap 'handle_error "$BASH_COMMAND"' ERR

# ---- System Check Functions ----
function check_system_requirements() {
    log_info "Checking system requirements..."
    
    # Check if running as root
    if [[ $EUID -ne 0 ]]; then
        log_error "This script must be run as root"
        exit 1
    fi
    
    # Check Ubuntu version
    if ! grep -q "Ubuntu\|Debian" /etc/os-release; then
        log_warning "This system may not be running Ubuntu or Debian"
        read -rp "Continue anyway? (y/n): " CONTINUE
        if [[ "$CONTINUE" != "y" ]]; then
            log_info "Setup aborted by user"
            exit 0
        fi
    fi
    
    # Check for minimum disk space (5GB free)
    local free_space=$(df -m / | awk 'NR==2 {print $4}')
    if [[ "$free_space" -lt 5120 ]]; then
        log_warning "Less than 5GB of free disk space available ($free_space MB)"
        read -rp "Continue anyway? (y/n): " CONTINUE
        if [[ "$CONTINUE" != "y" ]]; then
            log_info "Setup aborted by user"
            exit 0
        fi
    fi
    
    # Check for internet connectivity
    if ! ping -c 1 google.com &>/dev/null; then
        log_warning "Internet connectivity check failed"
        read -rp "Continue anyway? (y/n): " CONTINUE
        if [[ "$CONTINUE" != "y" ]]; then
            log_info "Setup aborted by user"
            exit 0
        fi
    fi
    
    log_success "System requirements check passed"
}

# ---- Configuration Functions ----
function get_configuration() {
    # Initialize variables with defaults
    KIOSK_HOSTNAME=$DEFAULT_HOSTNAME
    PORTAL_URL=$DEFAULT_PORTAL_URL
    WHITELIST=$DEFAULT_WHITELIST
    EMPOWER_USER=$DEFAULT_USERNAME
    EMPOWER_PASS=$DEFAULT_PASSWORD
    BRANCH=$DEFAULT_BRANCH
    DISTRO=$DEFAULT_DISTRO
    
    while true; do
        clear
        echo "------------------------------------------"
        echo "Empower Kiosk Setup - Ver: $VERSION"
        echo "------------------------------------------"
        echo
        echo "Please review the following configuration options."
        echo "Press the number to change a setting, or ENTER to continue with these settings."
        echo
        echo "1. Kiosk Name / hostname : $KIOSK_HOSTNAME"
        echo "2. Portal Home Page      : $PORTAL_URL"
        echo "3. Whitelist URLs        : $WHITELIST"
        echo "4. Empower Username      : $EMPOWER_USER"
        echo "5. Empower Password      : $(echo "$EMPOWER_PASS" | sed 's/./*/g')"
        echo "6. Git Branch            : $BRANCH"
        echo "7. Distro Type           : $DISTRO"
        echo
        read -rp "Select option [1-7] to edit, or ENTER to continue: " CHOICE
        
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
            7)
                echo "Distribution options:"
                echo "  minimal         - Minimal graphical environment (smallest, fastest)"
                echo "  lubuntu         - Lubuntu core packages (lightweight desktop)"
                echo "  xubuntu         - Xubuntu core packages (slightly heavier)"
                echo "  debian-minimal  - Debian-based minimal install (experimental)"
                read -rp "Select distribution type: " DISTRO
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
    
    log_info "Configuration complete"
    log_info "Hostname: $KIOSK_HOSTNAME"
    log_info "Portal URL: $PORTAL_URL"
    log_info "Distribution: $DISTRO"
}

# ---- Installation Functions ----
function determine_packages() {
    log_info "Selecting packages for $DISTRO installation..."
    
    # Base packages required for all installations
    BASE_PACKAGES="curl wget git"
    
    case "$DISTRO" in
        minimal)
            PACKAGES="$BASE_PACKAGES xorg xinit openbox chromium-browser fonts-dejavu ttf-mscorefonts-installer lightdm"
            ;;
        lubuntu)
            PACKAGES="$BASE_PACKAGES lubuntu-core chromium-browser ttf-mscorefonts-installer"
            ;;
        xubuntu)
            PACKAGES="$BASE_PACKAGES xubuntu-core chromium-browser ttf-mscorefonts-installer"
            ;;
        debian-minimal)
            # For Debian, package names might differ
            if grep -q "Debian" /etc/os-release; then
                PACKAGES="$BASE_PACKAGES xorg openbox chromium fonts-dejavu fonts-liberation lightdm"
            else
                log_warning "Not running on Debian, falling back to minimal Ubuntu packages"
                PACKAGES="$BASE_PACKAGES xorg xinit openbox chromium-browser fonts-dejavu ttf-mscorefonts-installer lightdm"
            fi
            ;;
        *)
            log_warning "Unknown distribution type: $DISTRO, using minimal setup"
            PACKAGES="$BASE_PACKAGES xorg xinit openbox chromium-browser fonts-dejavu ttf-mscorefonts-installer lightdm"
            ;;
    esac
    
    log_info "Selected packages: $PACKAGES"
}

function install_packages() {
    log_info "Preparing to install packages..."
    
    # Pre-accept Microsoft Fonts EULA
    echo "ttf-mscorefonts-installer msttcorefonts/accepted-mscorefonts-eula select true" | sudo debconf-set-selections
    
    # Update package lists
    log_progress "Updating package lists..."
    apt update
    
    # Count total packages for progress tracking
    TOTAL_PKGS=$(echo "$PACKAGES" | wc -w)
    CURRENT=0
    
    # Install packages with progress indicator
    for pkg in $PACKAGES; do
        CURRENT=$((CURRENT + 1))
        log_progress "Installing $pkg" "$CURRENT" "$TOTAL_PKGS"
        apt install -y --no-install-recommends "$pkg" >> "$LOG_FILE" 2>&1
    done
    
    echo # Add a newline after progress display
    log_success "Package installation complete"
}

function setup_kiosk_user() {
    log_info "Setting up kiosk user..."
    
    # Create kiosk user if it doesn't exist
    if ! id "$KIOSK_USER" &>/dev/null; then
        adduser --disabled-password --gecos "" "$KIOSK_USER"
        log_success "Created user: $KIOSK_USER"
    else
        log_info "User $KIOSK_USER already exists"
    fi
    
    # Add user to necessary groups
    usermod -aG video,audio,tty "$KIOSK_USER"
    
    # Save configuration
    CONFIG_FILE="/home/$KIOSK_USER/.kiosk-config"
    cat > "$CONFIG_FILE" <<EOF
hostname=$KIOSK_HOSTNAME
portal_url=$PORTAL_URL
whitelist=$WHITELIST
username=$EMPOWER_USER
password=$EMPOWER_PASS
branch=$BRANCH
distro=$DISTRO
EOF
    chown "$KIOSK_USER:$KIOSK_USER" "$CONFIG_FILE"
    chmod 600 "$CONFIG_FILE"  # More secure permissions
    
    log_success "Kiosk user configuration saved"
}

function configure_autologin() {
    log_info "Configuring auto-login..."
    
    # Disable LightDM (we'll use direct login to console)
    systemctl disable lightdm.service || true
    rm -f /etc/lightdm/lightdm.conf.d/50-myconfig.conf
    
    # Disable Plymouth splash screen
    systemctl mask \
      plymouth-start.service \
      plymouth-quit.service \
      plymouth-quit-wait.service || true
    
    # Set up auto-login to tty1
    systemctl unmask getty@tty1.service
    mkdir -p /etc/systemd/system/getty@tty1.service.d
    cat > /etc/systemd/system/getty@tty1.service.d/override.conf <<EOF
[Service]
ExecStart=
ExecStart=-/sbin/agetty --autologin $KIOSK_USER --noclear %I \$TERM
EOF
    
    # Update GRUB for cleaner boot
    sed -i 's/\<splash\>//g; s/\<quiet\>//g' /etc/default/grub
    sed -i 's/GRUB_CMDLINE_LINUX_DEFAULT="/GRUB_CMDLINE_LINUX_DEFAULT="quiet splash console=tty1 /' /etc/default/grub
    update-grub
    
    log_success "Auto-login configuration complete"
}

function setup_openbox_environment() {
    log_info "Setting up Openbox environment..."
    
    # Base URL for resources
    RAW_BASE="https://raw.githubusercontent.com/yourusername/empower-kiosk/$BRANCH"
    
    # Create Openbox autostart
    AUTOSTART_DIR="/home/$KIOSK_USER/.config/openbox"
    mkdir -p "$AUTOSTART_DIR"
    
    cat > "$AUTOSTART_DIR/autostart" <<EOF
# Prevent screen blanking
xset s off
xset -dpms
xset s noblank

# Launch Chromium via external script
/home/$KIOSK_USER/chromium.sh
EOF
    
    # Create minimal rc.xml to disable context menus
    cat > "$AUTOSTART_DIR/rc.xml" <<EOF
<openbox_config>
  <mouse>
    <context name="Desktop">
      <mousebind button="Right" action="Press"/>
      <mousebind button="Middle" action="Press"/>
      <mousebind button="Up" action="Click"/>
      <mousebind button="Down" action="Click"/>
      <mousebind button="Left" action="Click"/>
    </context>
  </mouse>
</openbox_config>
EOF
    
    # Download Chromium launcher
    curl -fsSL "$RAW_BASE/scripts/chromium.sh" -o "/home/$KIOSK_USER/chromium.sh" || {
        log_warning "Failed to download chromium.sh from GitHub, using local copy"
        cp "$SCRIPT_DIR/chromium.sh" "/home/$KIOSK_USER/chromium.sh" 2>/dev/null || {
            log_error "No chromium.sh found locally. Creating a basic version."
            cat > "/home/$KIOSK_USER/chromium.sh" <<EOF
#!/bin/bash
source /home/$KIOSK_USER/.kiosk-config    
LOG_FILE="/tmp/chromium.log"

export DISPLAY=:0                       

while true; do
  echo "[*] Launching Chromium..." | tee -a "\$LOG_FILE"

  /usr/bin/chromium-browser \
    --no-first-run \
    --kiosk \
    --disable-translate \
    --disable-infobars \
    --disable-features=TranslateUI \
    --overscroll-history-navigation=0 \
    --noerrdialogs \
    --disable-pinch \
    --disable-session-crashed-bubble \
    --disable-component-update \
    --disable-extensions \
    "\$portal_url" 2>&1 | tee -a "\$LOG_FILE"

  echo "[!] Chromium crashed or closed - rebooting." | tee -a "\$LOG_FILE"
  sleep 2
  sudo reboot
done
EOF
        }
    }
    
    # Create xinitrc
    cat > "/home/$KIOSK_USER/.xinitrc" <<EOF
exec openbox-session
EOF
    
    # Create startup script
    cat > "/home/$KIOSK_USER/kiosk-startup.sh" <<EOF
#!/bin/bash
source ~/.kiosk-config
BRANCH=\${branch:-main}
RAW_BASE="https://raw.githubusercontent.com/yourusername/empower-kiosk/\$BRANCH"

clear
if [ -f ~/logo.txt ]; then
    cat ~/logo.txt
else
    echo "=== Empower Kiosk ==="
fi

echo -e " Checking for updates..."
sleep 2

# Run update script
if curl -fsSL "\$RAW_BASE/scripts/update-kiosk.sh" -o /tmp/update-kiosk.sh; then
    bash /tmp/update-kiosk.sh 2>&1 | tee -a ~/kiosk-update.log
else
    echo "[!] Failed to download update script" | tee -a ~/kiosk-update.log
fi

echo " [✓] System ready. Launching kiosk..."
sleep 2
startx
EOF
    
    # Download ASCII logo
    curl -fsSL "$RAW_BASE/assets/logo.txt" -o "/home/$KIOSK_USER/logo.txt" || {
        log_warning "Failed to download logo.txt, using local copy"
        cp "$SCRIPT_DIR/logo.txt" "/home/$KIOSK_USER/logo.txt" 2>/dev/null || {
            log_info "No logo.txt found. The kiosk will use a simple text header."
        }
    }
    
    # Set permissions
    chmod +x "/home/$KIOSK_USER/chromium.sh"
    chmod +x "/home/$KIOSK_USER/kiosk-startup.sh"
    chown -R "$KIOSK_USER:$KIOSK_USER" "/home/$KIOSK_USER"
    
    # Update bash_profile to start kiosk on login
    cat > "/home/$KIOSK_USER/.bash_profile" <<EOF
[[ -z \$DISPLAY && \$XDG_VTNR -eq 1 ]] && bash ~/kiosk-startup.sh
EOF
    
    log_success "Openbox environment setup complete"
}

function setup_network_optimization() {
    log_info "Setting up network optimizations..."
    
    # Set up DNS caching
    if ! dpkg -l | grep -q dnsmasq; then
        apt install -y dnsmasq
        
        # Configure dnsmasq for caching
        cat > /etc/dnsmasq.conf <<EOF
# DNS caching configuration
cache-size=1000
no-negcache
min-cache-ttl=3600
EOF
        
        # Restart dnsmasq
        systemctl restart dnsmasq
        
        # Configure system to use local DNS
        cat > /etc/resolv.conf <<EOF
# Generated by Empower Kiosk setup
nameserver 127.0.0.1
# Fallback to Google DNS
nameserver 8.8.8.8
nameserver 8.8.4.4
EOF
        
        # Protect resolv.conf from being overwritten
        chattr +i /etc/resolv.conf
    else
        log_info "DNS caching already configured"
    fi
    
    # Set up web content caching if squid is installed
    if dpkg -l | grep -q squid; then
        log_info "Configuring Squid for web caching"
        # Squid configuration would go here
    fi
    
    log_success "Network optimizations complete"
}

function finalize_setup() {
    log_info "Finalizing setup..."
    
    # Reload systemd configuration
    systemctl daemon-reexec
    systemctl daemon-reload
    
    # Create a cleanup script to remove installation artifacts
    cat > /tmp/kiosk-cleanup.sh <<EOF
#!/bin/bash
# Clean up unnecessary packages to save space
apt-get autoremove -y
apt-get clean

# Clear apt cache
rm -rf /var/lib/apt/lists/*

# Remove install logs older than 7 days
find /var/log -type f -name "*.gz" -mtime +7 -delete
EOF
    
    # Make the script executable
    chmod +x /tmp/kiosk-cleanup.sh
    
    # Run the cleanup script
    bash /tmp/kiosk-cleanup.sh
    
    log_success "Setup finalized"
}

# ---- Main Execution ----
function main() {
    # Create log directory if it doesn't exist
    mkdir -p "$(dirname "$LOG_FILE")"
    
    log_info "Starting Empower Kiosk setup (Version $VERSION)"
    
    # Run setup steps
    check_system_requirements
    get_configuration
    determine_packages
    install_packages
    setup_kiosk_user
    configure_autologin
    setup_openbox_environment
    setup_network_optimization
    finalize_setup
    
    log_success "==============================================="
    log_success "✅ Kiosk environment installed successfully!"
    log_success "🔁 Reboot now to test the kiosk environment."
    log_success "==============================================="
}

# Run the main function
main