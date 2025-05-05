#!/bin/bash

LOG_FILE="/tmp/chromium.log"

# Make sure DISPLAY is set (Openbox gives us this)
export DISPLAY=:0

# Start loop to re-launch chromium if it's killed or crashes
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
    --use-gl=desktop \
    --disable-session-crashed-bubble \
    --disable-component-update \
    --disable-extensions \
    "$portal_url" 2>&1 | tee -a "$LOG_FILE"

  echo "[!] Chromium crashed or was closed. Rebooting..." | tee -a "$LOG_FILE"
  sleep 2
  sudo reboot
done
