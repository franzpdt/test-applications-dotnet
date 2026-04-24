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

# Extract registry host and region from DOCKER_REGISTRY (e.g. 123456.dkr.ecr.us-east-1.amazonaws.com/ns)
REGISTRY_HOST="$(echo "${DOCKER_REGISTRY}" | cut -d'/' -f1)"
AWS_REGION="$(echo "${REGISTRY_HOST}" | sed 's/.*\.ecr\.\([a-z0-9-]*\)\.amazonaws\.com/\1/')"

echo "Using container command: ${CONTAINER_COMMAND}"
echo "Registry:                ${DOCKER_REGISTRY}"
echo "Region:                  ${AWS_REGION}"
echo "API image:               ${API_IMAGE}"
echo "Caller image:            ${CALLER_IMAGE}"
echo ""

echo "==> Logging in to ECR"
# Clear any stale namespace-level credentials that would take precedence over the fresh registry-level token
"${CONTAINER_COMMAND}" logout "${REGISTRY_HOST}" 2>/dev/null || true
AWS_SHARED_CREDENTIALS_FILE="${AWS_CREDS_FILE}" \
    aws ecr get-login-password --region "${AWS_REGION}" \
    | "${CONTAINER_COMMAND}" login --username AWS --password-stdin "${REGISTRY_HOST}"

echo ""
echo "==> Building API image: ${API_IMAGE}"
"${CONTAINER_COMMAND}" build \
    --format docker \
    -f "${SCRIPT_DIR}/Dockerfile" \
    -t "${API_IMAGE}" \
    "${SCRIPT_DIR}"

echo ""
echo "==> Building caller image: ${CALLER_IMAGE}"
"${CONTAINER_COMMAND}" build \
    --format docker \
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
