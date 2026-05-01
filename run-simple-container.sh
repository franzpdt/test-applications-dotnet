#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

CONTAINER_CMD="${CONTAINER_COMMAND:-docker}"
if ! command -v "${CONTAINER_CMD}" &>/dev/null; then
    CONTAINER_CMD="$(command -v podman 2>/dev/null || command -v docker 2>/dev/null)"
fi

VERSION="$(cat "${SCRIPT_DIR}/VERSION" | tr -d '[:space:]')"
REPO_NAME="$(basename "$(git -C "${SCRIPT_DIR}" remote get-url origin 2>/dev/null)" .git)"

API_IMAGE="${REPO_NAME}:${VERSION}"
CALLER_IMAGE="${REPO_NAME}-caller:${VERSION}"
NETWORK="taskapi-net"
API_CONTAINER="taskapi"
CALLER_CONTAINER="taskapi-caller"

echo "Container tool: ${CONTAINER_CMD}"
echo "Version:        ${VERSION}"
echo "API image:      ${API_IMAGE}"
echo "Caller image:   ${CALLER_IMAGE}"
echo ""

# Remove existing containers
for name in "${API_CONTAINER}" "${CALLER_CONTAINER}"; do
    if "${CONTAINER_CMD}" inspect "${name}" &>/dev/null; then
        echo "==> Removing existing container: ${name}"
        "${CONTAINER_CMD}" rm -f "${name}"
    fi
done

# Create network if it doesn't exist
if ! "${CONTAINER_CMD}" network inspect "${NETWORK}" &>/dev/null; then
    echo "==> Creating network: ${NETWORK}"
    "${CONTAINER_CMD}" network create "${NETWORK}"
fi

echo ""
echo "==> Starting API container: ${API_CONTAINER}"
"${CONTAINER_CMD}" run -d \
    --name "${API_CONTAINER}" \
    --network "${NETWORK}" \
    --restart=always \
    -p 5000:5000 \
    "${API_IMAGE}"

echo ""
echo "==> Starting caller container: ${CALLER_CONTAINER}"
"${CONTAINER_CMD}" run -d \
    --name "${CALLER_CONTAINER}" \
    --network "${NETWORK}" \
    --restart=always \
    -e BASE_URL="http://${API_CONTAINER}:5000" \
    "${CALLER_IMAGE}"

echo ""
echo "Done. Running containers:"
echo "  ${API_CONTAINER}    → http://localhost:5000"
echo "  ${CALLER_CONTAINER} → calling ${API_CONTAINER}:5000 every 10s"
echo ""
echo "Logs:"
echo "  ${CONTAINER_CMD} logs -f ${API_CONTAINER}"
echo "  ${CONTAINER_CMD} logs -f ${CALLER_CONTAINER}"
