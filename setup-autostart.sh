#!/usr/bin/env bash
set -euo pipefail

PLIST_LABEL="com.taskapi.podman-machine"
PLIST_PATH="${HOME}/Library/LaunchAgents/${PLIST_LABEL}.plist"
PODMAN="$(command -v podman 2>/dev/null || true)"

if [[ -z "${PODMAN}" ]]; then
    echo "Error: podman not found in PATH" >&2
    exit 1
fi

mkdir -p "${HOME}/Library/LaunchAgents"

cat > "${PLIST_PATH}" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>${PLIST_LABEL}</string>
    <key>ProgramArguments</key>
    <array>
        <string>${PODMAN}</string>
        <string>machine</string>
        <string>start</string>
    </array>
    <key>RunAtLoad</key>
    <true/>
    <key>StandardOutPath</key>
    <string>/tmp/${PLIST_LABEL}.log</string>
    <key>StandardErrorPath</key>
    <string>/tmp/${PLIST_LABEL}-error.log</string>
</dict>
</plist>
EOF

launchctl unload "${PLIST_PATH}" 2>/dev/null || true
launchctl load "${PLIST_PATH}"

echo "Autostart configured."
echo "  Plist: ${PLIST_PATH}"
echo "  Podman machine will start on next login and after every reboot."
echo "  Containers with --restart=always will come up automatically once the machine is running."
echo ""
echo "To remove autostart:"
echo "  launchctl unload ${PLIST_PATH} && rm ${PLIST_PATH}"
