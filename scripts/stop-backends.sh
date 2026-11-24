#!/usr/bin/env bash
# ==============================================================================
# stop-backends.sh
# Safely stops Backend A (port 3001) and Backend B (port 3002) on Mac3.
#
# Constraints & Guarantees:
# - Targets ONLY the exact processes bound to ports 3001 and 3002.
# - Never uses broad process killers such as 'killall node'.
# - Sends graceful SIGTERM first, waiting for termination before SIGKILL.
# ==============================================================================

set -euo pipefail

PORT_A=3001
PORT_B=3002

stop_service_on_port() {
    local name="$1"
    local port="$2"

    echo -n "[${name}] Inspecting port ${port}... "
    local pid
    pid=$(lsof -tiTCP:"${port}" -sTCP:LISTEN 2>/dev/null || true)

    if [ -z "${pid}" ]; then
        echo "No active process listening on port ${port}."
        return 0
    fi

    echo "Found PID ${pid}. Sending SIGTERM..."
    kill -TERM "${pid}" 2>/dev/null || true

    local count=0
    local max_wait=5
    while [ "${count}" -lt "${max_wait}" ]; do
        if ! lsof -tiTCP:"${port}" -sTCP:LISTEN >/dev/null 2>&1; then
            echo "[${name}] PID ${pid} stopped cleanly."
            return 0
        fi
        sleep 1
        count=$((count + 1))
    done

    echo "[${name}] Process ${pid} did not exit within ${max_wait}s. Sending SIGKILL..."
    kill -9 "${pid}" 2>/dev/null || true
    sleep 1

    if lsof -tiTCP:"${port}" -sTCP:LISTEN >/dev/null 2>&1; then
        echo "[${name}] ERROR: Failed to free port ${port}!" >&2
        return 1
    else
        echo "[${name}] Forcefully stopped. Port ${port} is now free."
        return 0
    fi
}

echo "=========================================================="
echo "Stopping Application Backends on Mac3 (Ports 3001, 3002)"
echo "=========================================================="

stop_service_on_port "Backend A" "${PORT_A}"
stop_service_on_port "Backend B" "${PORT_B}"

echo "=========================================================="
echo "Backend stop sequence completed."
echo "=========================================================="
