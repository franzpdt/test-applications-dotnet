#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Load .env
set -a
source "${SCRIPT_DIR}/.env"
set +a

# Derive image name from git repository name
REPO_NAME="$(basename "$(git -C "${SCRIPT_DIR}" remote get-url origin 2>/dev/null)" .git)"

API_IMAGE="${DOCKER_REGISTRY}/${REPO_NAME}"
CALLER_IMAGE="${DOCKER_REGISTRY}/${REPO_NAME}-caller"

echo "Using container command: ${CONTAINER_COMMAND}"
echo "Registry:                ${DOCKER_REGISTRY}"
echo "API image:               ${API_IMAGE}"
echo "Caller image:            ${CALLER_IMAGE}"
echo ""

echo "==> Building API image: ${API_IMAGE}"
"${CONTAINER_COMMAND}" build \
    -f "${SCRIPT_DIR}/Dockerfile" \
    -t "${API_IMAGE}" \
    "${SCRIPT_DIR}"

echo ""
echo "==> Building caller image: ${CALLER_IMAGE}"
"${CONTAINER_COMMAND}" build \
    -f "${SCRIPT_DIR}/Dockerfile.caller" \
    -t "${CALLER_IMAGE}" \
    "${SCRIPT_DIR}"

echo ""
echo "==> Pushing API image: ${API_IMAGE}"
"${CONTAINER_COMMAND}" push "${API_IMAGE}"

echo ""
echo "==> Pushing caller image: ${CALLER_IMAGE}"
"${CONTAINER_COMMAND}" push "${CALLER_IMAGE}"

echo ""
echo "Done. Images pushed:"
echo "  ${API_IMAGE}"
echo "  ${CALLER_IMAGE}"
