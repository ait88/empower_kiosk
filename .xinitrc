# ---- Kiosk .bash_profile ----

# Log update script run
echo "🛠️  Running kiosk update script..." | tee -a /home/kiosk/kiosk-update.log

# Download + run update script
curl -fsSL "https://git.aitdev.au/pm/empower_kiosk/raw/branch/main/update-kiosk.sh" -o /tmp/update-kiosk.sh
chmod +x /tmp/update-kiosk.sh
/tmp/update-kiosk.sh | tee -a /home/kiosk/kiosk-update.log

# Wait briefly so user can see results
sleep 2

# Start X if not already running
[[ -z $DISPLAY && $XDG_VTNR -eq 1 ]] && startx
