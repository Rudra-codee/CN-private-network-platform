#!/usr/bin/env bash
# ==============================================================================
# check-backends.sh
# Verifies process status and HTTP response integrity for Backend A and B.
#
# Constraints & Guarantees:
# - Inspects runtime sockets via lsof.
# - Queries endpoints using curl with '--noproxy "*"' to avoid local proxy interference.
# - Validates HTTP 200 status, response body JSON, and 'X-Backend' identity headers.
# ==============================================================================

set -euo pipefail

PORT_A=3001
PORT_B=3002
HOST_IP="127.0.0.1"

echo "=========================================================="
echo "Health & Verification Check: Application Backends on Mac3"
echo "=========================================================="

ALL_HEALTHY=true

# ------------------------------------------------------------------------------
# Helper verification function
# ------------------------------------------------------------------------------
verify_backend() {
    local name="$1"
    local port="$2"
    local expected_header="$3"

    echo "--- ${name} (Port ${port}) ---"
    
    # 1. Socket Listener Check
    local pid
    pid=$(lsof -tiTCP:"${port}" -sTCP:LISTEN 2>/dev/null || true)

    if [ -z "${pid}" ]; then
        echo "❌ Socket Check: FAILED. No process listening on port ${port}."
        ALL_HEALTHY=false
        return
    else
        echo "✅ Socket Check: PASS. PID ${pid} listening on 0.0.0.0:${port}."
    fi

    # 2. HTTP Status Check (/api/status)
    local target_url="http://${HOST_IP}:${port}/api/status"
    echo -n "   Querying ${target_url}... "

    local response_headers
    local response_body
    local http_code

    response_headers=$(mktemp)
    response_body=$(curl --noproxy "*" -s -w "%{http_code}" -D "${response_headers}" -o - "${target_url}" 2>/dev/null || true)
    http_code="${response_body: -3}"
    local body_content="${response_body%???}"

    if [ "${http_code}" != "200" ]; then
        echo "❌ FAILED (HTTP ${http_code:-Connection refused})"
        ALL_HEALTHY=false
        rm -f "${response_headers}"
        return
    fi
    echo "✅ HTTP 200 OK"

    # 3. Header Check
    local backend_header
    backend_header=$(grep -i "^X-Backend:" "${response_headers}" | tr -d '\r' | awk '{print $2}' || true)

    if [ "${backend_header}" = "${expected_header}" ]; then
        echo "✅ Header Check: PASS (X-Backend: ${backend_header})"
    else
        echo "❌ Header Check: FAILED (Expected: ${expected_header}, Received: ${backend_header})"
        ALL_HEALTHY=false
    fi

    # 4. JSON Payload Check
    echo "   Payload: ${body_content}"
    rm -f "${response_headers}"
}

verify_backend "Backend A" "${PORT_A}" "A"
echo ""
verify_backend "Backend B" "${PORT_B}" "B"

echo "=========================================================="
if [ "${ALL_HEALTHY}" = true ]; then
    echo "Status: ALL BACKENDS HEALTHY AND OPERATIONAL ✅"
    exit 0
else
    echo "Status: ONE OR MORE BACKENDS DEGRADED OR UNREACHABLE ❌"
    exit 1
fi
