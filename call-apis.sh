#!/usr/bin/env bash
set -euo pipefail

BASE_URL="${1:-http://localhost:80}"
INTERVAL=10

echo "Calling Task API at ${BASE_URL} every ${INTERVAL}s (Ctrl+C to stop)"

echo "Waiting for API to be ready..."
until curl -sf "${BASE_URL}/api/tasks" -o /dev/null; do
    sleep 2
done
echo "API is ready."

while true; do
    echo ""
    echo "=== $(date '+%Y-%m-%d %H:%M:%S') ==="

    # GET all tasks
    echo "--- GET /api/tasks ---"
    curl -s "${BASE_URL}/api/tasks" | head -c 500
    echo ""

    # GET single task (id=1)
    echo "--- GET /api/tasks/1 ---"
    curl -s "${BASE_URL}/api/tasks/1" | head -c 500
    echo ""

    # POST create a new task
    echo "--- POST /api/tasks ---"
    curl -s -X POST "${BASE_URL}/api/tasks" \
        -H "Content-Type: application/json" \
        -d '{"title":"Generated task","description":"Created by load script","isCompleted":false}' \
        | head -c 500
    echo ""

    # PUT update task (id=1)
    echo "--- PUT /api/tasks/1 ---"
    curl -s -X PUT "${BASE_URL}/api/tasks/1" \
        -H "Content-Type: application/json" \
        -d '{"title":"Updated task","description":"Updated by load script","isCompleted":true}' \
        | head -c 500
    echo ""

    # DELETE the most recently created task
    echo "--- DELETE latest task ---"
    LATEST_ID=$(curl -s "${BASE_URL}/api/tasks" | grep -o '"id":[0-9]*' | tail -1 | grep -o '[0-9]*')
    if [[ -n "${LATEST_ID}" ]]; then
        curl -s -X DELETE "${BASE_URL}/api/tasks/${LATEST_ID}" -w "HTTP %{http_code}"
        echo ""
    else
        echo "No task found to delete"
    fi

    # GET CPU stress (1 second, lightweight)
    echo "--- GET /api/stress/cpu?seconds=1 ---"
    curl -s "${BASE_URL}/api/stress/cpu?seconds=1" | head -c 500
    echo ""

    # GET memory stress (1 second, lightweight)
    echo "--- GET /api/stress/memory?seconds=1 ---"
    curl -s "${BASE_URL}/api/stress/memory?seconds=1" | head -c 500
    echo ""

    sleep "${INTERVAL}"
done
