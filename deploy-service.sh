#!/usr/bin/env bash
set -euo pipefail

APP_NAME="task-api"
DEPLOY_DIR="/var/www/${APP_NAME}"
LOG_DIR="/var/log/${APP_NAME}"
SERVICE_USER="${APP_NAME}"
SERVICE_FILE="/etc/systemd/system/${APP_NAME}.service"
APP_PORT=80
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_FILE="${SCRIPT_DIR}/TaskApi/TaskApi.csproj"
ENV_VARS_FILE="${SCRIPT_DIR}/service.environment.variables.txt"

echo "=== Deploying ${APP_NAME} as a systemd service ==="

# Ensure running as root
if [[ $EUID -ne 0 ]]; then
    echo "This script must be run as root (use sudo)."
    exit 1
fi

# Verify dotnet is available
if ! command -v dotnet &>/dev/null; then
    echo "Error: 'dotnet' not found on PATH. Install the .NET SDK first."
    exit 1
fi

# Create service user if it doesn't exist
if ! id -u "${SERVICE_USER}" &>/dev/null; then
    echo "Creating service user '${SERVICE_USER}'..."
    useradd --system --no-create-home --shell /usr/sbin/nologin "${SERVICE_USER}"
fi

# Create directories
echo "Creating directories..."
mkdir -p "${DEPLOY_DIR}"
mkdir -p "${LOG_DIR}"

# Stop the service if it's already running (binary can't be overwritten while in use)
if systemctl is-active --quiet "${APP_NAME}.service" 2>/dev/null; then
    echo "Stopping running ${APP_NAME} service..."
    systemctl stop "${APP_NAME}.service"
fi

# Kill any leftover processes in case the stop wasn't clean
if pgrep -f "dotnet ${DEPLOY_DIR}/TaskApi.dll" &>/dev/null; then
    echo "Killing leftover TaskApi processes..."
    pkill -f "dotnet ${DEPLOY_DIR}/TaskApi.dll" || true
    sleep 1
    # Force kill if still running
    if pgrep -f "dotnet ${DEPLOY_DIR}/TaskApi.dll" &>/dev/null; then
        echo "Force killing remaining processes..."
        pkill -9 -f "dotnet ${DEPLOY_DIR}/TaskApi.dll" || true
        sleep 1
    fi
fi

# Publish the application
echo "Publishing application to ${DEPLOY_DIR}..."
dotnet publish "${PROJECT_FILE}" -c Debug -o "${DEPLOY_DIR}"

# Set ownership and permissions
echo "Setting permissions..."
chown -R "${SERVICE_USER}:${SERVICE_USER}" "${DEPLOY_DIR}"
chown -R "${SERVICE_USER}:${SERVICE_USER}" "${LOG_DIR}"
chmod 755 "${DEPLOY_DIR}"
chmod 755 "${LOG_DIR}"

# Create the systemd service unit
echo "Creating systemd service at ${SERVICE_FILE}..."

# Build extra environment lines from env vars file
EXTRA_ENV_LINES=""
if [[ -f "${ENV_VARS_FILE}" ]]; then
    while IFS= read -r line || [[ -n "$line" ]]; do
        # Skip empty lines and comments
        [[ -z "$line" || "$line" == \#* ]] && continue
        EXTRA_ENV_LINES+="${line}"$'\n'
    done < "${ENV_VARS_FILE}"
    echo "Loaded environment variables from ${ENV_VARS_FILE}"
else
    echo "Warning: ${ENV_VARS_FILE} not found, skipping extra environment variables."
fi

cat > "${SERVICE_FILE}" <<EOF
[Unit]
Description=Task API (.NET)
After=network.target

[Service]
Type=exec
User=${SERVICE_USER}
Group=${SERVICE_USER}
WorkingDirectory=${DEPLOY_DIR}
ExecStart=/usr/bin/dotnet ${DEPLOY_DIR}/TaskApi.dll
ExecStopPost=/bin/sh -c 'while ss -tlnp | grep -q ":${APP_PORT} "; do sleep 0.5; done'
KillMode=control-group
TimeoutStopSec=15
Environment=DOTNET_ENVIRONMENT=Production
Environment=APP_PORT=${APP_PORT}
Environment=APP_LOG_PATH=${LOG_DIR}
${EXTRA_ENV_LINES}AmbientCapabilities=CAP_NET_BIND_SERVICE
Restart=on-failure
RestartSec=5
KillSignal=SIGINT
SyslogIdentifier=${APP_NAME}

[Install]
WantedBy=multi-user.target
EOF

# Reload systemd, enable and start the service
echo "Enabling and starting service..."
systemctl daemon-reload
systemctl enable "${APP_NAME}.service"
systemctl restart "${APP_NAME}.service"

echo ""
echo "=== Deployment complete ==="
echo "Service status:"
systemctl status "${APP_NAME}.service" --no-pager || true
echo ""
echo "The API is listening on port ${APP_PORT}."
echo "Logs are written to ${LOG_DIR}."
echo ""
echo "Useful commands:"
echo "  sudo systemctl status ${APP_NAME}"
echo "  sudo systemctl restart ${APP_NAME}"
echo "  sudo journalctl -u ${APP_NAME} -f"
