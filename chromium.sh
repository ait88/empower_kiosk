#!/bin/bash
source /home/kiosk/.kiosk-config    
BRANCH="${branch:-main}"    
LOG_FILE="/tmp/chromium.log"

export DISPLAY=:0                       

while true; do
  echo "[*] Launching Chromium..." | tee -a "$LOG_FILE"

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
    "$portal_url" 2>&1 | tee -a "$LOG_FILE"

  echo "[!] Chromium crashed or closed - rebooting." | tee -a "$LOG_FILE"
  sleep 2
  sudo reboot
done
