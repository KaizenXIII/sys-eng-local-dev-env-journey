#!/bin/bash
# End-to-end validation of the lab environment
set -e

PASS=0
FAIL=0
SPLUNK_USER="admin"
SPLUNK_PASS="ChangeMeNow1!"

check() {
    local desc="$1"
    local cmd="$2"
    if eval "$cmd" > /dev/null 2>&1; then
        echo "  [PASS] $desc"
        PASS=$((PASS + 1))
    else
        echo "  [FAIL] $desc"
        FAIL=$((FAIL + 1))
    fi
}

echo ""
echo "═══════════════════════════════════════════════════"
echo "  END-TO-END VALIDATION"
echo "═══════════════════════════════════════════════════"
echo ""

# Containers running
echo "  Containers:"
check "node1 running" "podman ps --filter name=node1 --format '{{.Status}}' | grep -q Up"
check "node2 running" "podman ps --filter name=node2 --format '{{.Status}}' | grep -q Up"
check "node3 running" "podman ps --filter name=node3 --format '{{.Status}}' | grep -q Up"
check "splunk running" "podman ps --filter name=splunk-standalone --format '{{.Status}}' | grep -q Up"
echo ""

# SSH connectivity
echo "  SSH Connectivity:"
ANSIBLE_DIR="$(cd "$(dirname "$0")/../ansible" && pwd)"
check "node1 SSH" "cd $ANSIBLE_DIR && ansible node1 -m ping 2>/dev/null | grep -q pong"
check "node2 SSH" "cd $ANSIBLE_DIR && ansible node2 -m ping 2>/dev/null | grep -q pong"
check "node3 SSH" "cd $ANSIBLE_DIR && ansible node3 -m ping 2>/dev/null | grep -q pong"
echo ""

# Splunk services
echo "  Splunk Services:"
check "Splunk mgmt API (8089)" "curl -sk -u $SPLUNK_USER:$SPLUNK_PASS https://localhost:8089/services/server/info -o /dev/null -w '%{http_code}' | grep -q 200"
check "Splunk web UI (8000)" "curl -sk -o /dev/null -w '%{http_code}' http://localhost:8000/en-US/account/login | grep -q 200"
check "Index ping_data exists" "curl -sk -u $SPLUNK_USER:$SPLUNK_PASS https://localhost:8089/services/data/indexes/ping_data -o /dev/null -w '%{http_code}' | grep -q 200"
echo ""

# UF forwarding
echo "  Universal Forwarder:"
check "node1 UF forwarding" "podman exec node1 /opt/splunkforwarder/bin/splunk list forward-server -auth admin:$SPLUNK_PASS 2>/dev/null | grep -q 'Active forwards'"
check "node2 UF forwarding" "podman exec node2 /opt/splunkforwarder/bin/splunk list forward-server -auth admin:$SPLUNK_PASS 2>/dev/null | grep -q 'Active forwards'"
check "node3 UF forwarding" "podman exec node3 /opt/splunkforwarder/bin/splunk list forward-server -auth admin:$SPLUNK_PASS 2>/dev/null | grep -q 'Active forwards'"
echo ""

# Data in Splunk
echo "  Data Flow:"
EVENT_COUNT=$(curl -sk -u "$SPLUNK_USER:$SPLUNK_PASS" \
    "https://localhost:8089/services/search/jobs/export" \
    -d "search=search index=ping_data | stats count" \
    -d "output_mode=csv" 2>/dev/null | tail -1)
check "Events in ping_data index (count: $EVENT_COUNT)" "[ '$EVENT_COUNT' -gt 0 ] 2>/dev/null"
echo ""

# Summary
echo "═══════════════════════════════════════════════════"
echo "  Results: $PASS passed, $FAIL failed"
echo "═══════════════════════════════════════════════════"
echo ""

[ "$FAIL" -eq 0 ] && exit 0 || exit 1
