#!/usr/bin/env bash
# ==============================================================================
# start-backends.sh
# Safely starts Backend A (port 3001) and Backend B (port 3002) on Mac3.
#
# Constraints & Guarantees:
# - Checks whether ports 3001 and 3002 are already occupied before starting.
# - Spawns processes in the background with output redirected to local log files.
# - Never kills unrelated processes.
# - Verifies successful socket binding after launch.
# ==============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

BACKEND_A_DIR="${REPO_ROOT}/backend-a"
BACKEND_B_DIR="${REPO_ROOT}/backend-b"

PORT_A=3001
PORT_B=3002

echo "=========================================================="
echo "Starting Application Backends on Mac3 (10.7.24.216)"
echo "=========================================================="

# ------------------------------------------------------------------------------
# 1. Start Backend A (Port 3001)
# ------------------------------------------------------------------------------
echo -n "[Backend A] Checking port ${PORT_A}... "
PID_A=$(lsof -tiTCP:${PORT_A} -sTCP:LISTEN 2>/dev/null || true)

if [ -n "${PID_A}" ]; then
    echo "ALREADY RUNNING (PID ${PID_A}). Skipping."
else
    echo "Not running. Starting..."
    if [ ! -d "${BACKEND_A_DIR}" ]; then
        echo "Error: Directory ${BACKEND_A_DIR} does not exist!" >&2
        exit 1
    fi
    (
        cd "${BACKEND_A_DIR}"
        nohup node server.js >> "${BACKEND_A_DIR}/backend-a.log" 2>&1 &
    )
    sleep 1

    NEW_PID_A=$(lsof -tiTCP:${PORT_A} -sTCP:LISTEN 2>/dev/null || true)
    if [ -n "${NEW_PID_A}" ]; then
        echo "[Backend A] Started successfully (PID ${NEW_PID_A}) on 0.0.0.0:${PORT_A}."
    else
        echo "[Backend A] ERROR: Failed to bind to port ${PORT_A}. Check ${BACKEND_A_DIR}/backend-a.log" >&2
        exit 1
    fi
fi

# ------------------------------------------------------------------------------
# 2. Start Backend B (Port 3002)
# ------------------------------------------------------------------------------
echo -n "[Backend B] Checking port ${PORT_B}... "
PID_B=$(lsof -tiTCP:${PORT_B} -sTCP:LISTEN 2>/dev/null || true)

if [ -n "${PID_B}" ]; then
    echo "ALREADY RUNNING (PID ${PID_B}). Skipping."
else
    echo "Not running. Starting..."
    if [ ! -d "${BACKEND_B_DIR}" ]; then
        echo "Error: Directory ${BACKEND_B_DIR} does not exist!" >&2
        exit 1
    fi
    (
        cd "${BACKEND_B_DIR}"
        nohup node server.js >> "${BACKEND_B_DIR}/backend-b.log" 2>&1 &
    )
    sleep 1

    NEW_PID_B=$(lsof -tiTCP:${PORT_B} -sTCP:LISTEN 2>/dev/null || true)
    if [ -n "${NEW_PID_B}" ]; then
        echo "[Backend B] Started successfully (PID ${NEW_PID_B}) on 0.0.0.0:${PORT_B}."
    else
        echo "[Backend B] ERROR: Failed to bind to port ${PORT_B}. Check ${BACKEND_B_DIR}/backend-b.log" >&2
        exit 1
    fi
fi

echo "=========================================================="
echo "Both backends are running and ready for traffic."
echo "=========================================================="
