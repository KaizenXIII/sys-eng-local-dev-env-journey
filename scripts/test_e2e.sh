#!/bin/bash
# End-to-end validation of the lab environment
set -e

PASS=0
FAIL=0
SPLUNK_USER="admin"
SPLUNK_PASS="${LAB_SPLUNK_PASSWORD:-ChangeMeNow1!}"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ANSIBLE_DIR="$(cd "$SCRIPT_DIR/../ansible" && pwd)"

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
check "node1 SSH" "cd $ANSIBLE_DIR && ansible node1 -m ping 2>/dev/null | grep -q pong"
check "node2 SSH" "cd $ANSIBLE_DIR && ansible node2 -m ping 2>/dev/null | grep -q pong"
check "node3 SSH" "cd $ANSIBLE_DIR && ansible node3 -m ping 2>/dev/null | grep -q pong"
echo ""

# Splunk services (mgmt API only — web UI is too slow under amd64 emulation)
echo "  Splunk Services:"
check "Splunk mgmt API (8089)" "curl -sk -u $SPLUNK_USER:$SPLUNK_PASS https://localhost:8089/services/server/info -o /dev/null -w '%{http_code}' | grep -q 200"
check "Index ping_data exists" "curl -sk -u $SPLUNK_USER:$SPLUNK_PASS https://localhost:8089/services/data/indexes/ping_data -o /dev/null -w '%{http_code}' | grep -q 200"
check "Index ps_data exists" "curl -sk -u $SPLUNK_USER:$SPLUNK_PASS https://localhost:8089/services/data/indexes/ps_data -o /dev/null -w '%{http_code}' | grep -q 200"
echo ""

# UF forwarding
echo "  Universal Forwarder:"
check "node1 UF forwarding" "podman exec node1 /opt/splunkforwarder/bin/splunk list forward-server -auth admin:$SPLUNK_PASS 2>/dev/null | grep -q 'Active forwards'"
check "node2 UF forwarding" "podman exec node2 /opt/splunkforwarder/bin/splunk list forward-server -auth admin:$SPLUNK_PASS 2>/dev/null | grep -q 'Active forwards'"
check "node3 UF forwarding" "podman exec node3 /opt/splunkforwarder/bin/splunk list forward-server -auth admin:$SPLUNK_PASS 2>/dev/null | grep -q 'Active forwards'"
echo ""

# Data flow — lower minFreeSpace for search, generate fresh data, then verify
echo "  Data Flow:"
echo "    Configuring search dispatch limits..."
curl -sk -u "$SPLUNK_USER:$SPLUNK_PASS" \
    "https://localhost:8089/services/server/settings/settings" \
    -d "minFreeSpace=500" -o /dev/null 2>/dev/null

echo "    Generating fresh workload data..."
cd "$ANSIBLE_DIR" && ansible-playbook playbooks/ping_test.yml > /dev/null 2>&1
cd "$ANSIBLE_DIR" && ansible-playbook playbooks/ps_snapshot.yml > /dev/null 2>&1

echo "    Waiting for data to be indexed..."
DATA_ATTEMPTS=0
while true; do
    PING_EVENT_COUNT=$(curl -sk -u "$SPLUNK_USER:$SPLUNK_PASS" \
        "https://localhost:8089/services/search/jobs/export" \
        -d "search=search index=ping_data | stats count" \
        -d "output_mode=csv" 2>/dev/null | tail -1)
    if [ "$PING_EVENT_COUNT" -gt 0 ] 2>/dev/null; then
        break
    fi
    DATA_ATTEMPTS=$((DATA_ATTEMPTS + 1))
    if [ "$DATA_ATTEMPTS" -ge 18 ]; then
        break
    fi
    sleep 10
done
check "Events in ping_data index (count: $PING_EVENT_COUNT)" "[ '$PING_EVENT_COUNT' -gt 0 ] 2>/dev/null"
PS_EVENT_COUNT=$(curl -sk -u "$SPLUNK_USER:$SPLUNK_PASS" \
    "https://localhost:8089/services/search/jobs/export" \
    -d "search=search index=ps_data | stats count" \
    -d "output_mode=csv" 2>/dev/null | tail -1)
check "Events in ps_data index (count: $PS_EVENT_COUNT)" "[ '$PS_EVENT_COUNT' -gt 0 ] 2>/dev/null"
echo ""

# Summary
echo "═══════════════════════════════════════════════════"
echo "  Results: $PASS passed, $FAIL failed"
echo "═══════════════════════════════════════════════════"
echo ""

[ "$FAIL" -eq 0 ] && exit 0 || exit 1
