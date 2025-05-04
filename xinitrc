#!/bin/bash

# Run update before launching Openbox
echo "🛠️  Running kiosk update script..." | tee -a /home/kiosk/kiosk-update.log
curl -fsSL "https://git.aitdev.au/pm/empower_kiosk/raw/branch/main/update-kiosk.sh" -o /tmp/update-kiosk.sh
chmod +x /tmp/update-kiosk.sh
/tmp/update-kiosk.sh | tee -a /home/kiosk/kiosk-update.log

sleep 2  # Give user a moment to see log output

# Start Openbox session
exec openbox-session
