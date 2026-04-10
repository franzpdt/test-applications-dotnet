#!/usr/bin/env bash
set -euo pipefail

: "${APP_PORT:=5000}"
: "${APP_LOG_PATH:=./logs}"

export APP_PORT
export APP_LOG_PATH

echo "Starting TaskApi on port $APP_PORT, logs at $APP_LOG_PATH"
dotnet run --project "$(dirname "$0")/TaskApi"
