#!/bin/bash


while true; do
  openbox-session &
  chromium-browser \
    --no-first-run \
    --kiosk \
    --disable-translate \
    --disable-infobars \
    --disable-features=TranslateUI \
    --overscroll-history-navigation=0 \
    --noerrdialogs \
    "$portal_url"
  echo "[!] Chromium crashed or was closed. Rebooting..."
  sleep 2
  sudo reboot
done
