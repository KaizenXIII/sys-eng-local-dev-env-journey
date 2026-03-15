#!/bin/bash
# Create Splunk indexes via the management API (port 8089)
# The mgmt API comes up before the web UI, making this faster during startup.
set -e

SPLUNK_HOST="localhost"
SPLUNK_MGMT_PORT="8089"
SPLUNK_USER="admin"
SPLUNK_PASS="${LAB_SPLUNK_PASSWORD:-ChangeMeNow1!}"
INDEXES=("ping_data" "ps_data")

echo "Waiting for Splunk management API to be ready..."
until curl -sk -o /dev/null -w "%{http_code}" \
    "https://${SPLUNK_HOST}:${SPLUNK_MGMT_PORT}/services/server/info" \
    -u "${SPLUNK_USER}:${SPLUNK_PASS}" 2>/dev/null | grep -q "200"; do
    echo "  Splunk mgmt API not ready yet, retrying in 10s..."
    sleep 10
done
echo "Splunk management API is ready."

for INDEX_NAME in "${INDEXES[@]}"; do
    echo "Creating index '${INDEX_NAME}'..."
    RESPONSE=$(curl -sk -u "${SPLUNK_USER}:${SPLUNK_PASS}" \
        "https://${SPLUNK_HOST}:${SPLUNK_MGMT_PORT}/services/data/indexes" \
        -d "name=${INDEX_NAME}" \
        -d "datatype=event" \
        -o /dev/null -w "%{http_code}")

    if [ "$RESPONSE" = "201" ]; then
        echo "Index '${INDEX_NAME}' created successfully."
    elif [ "$RESPONSE" = "409" ]; then
        echo "Index '${INDEX_NAME}' already exists."
    else
        echo "Warning: Got HTTP ${RESPONSE} when creating index. Continuing..."
    fi
done

# The Splunk container auto-configures splunktcp on 9997 during provisioning.
# Verify it's there; create via cooked endpoint if missing.
echo "Verifying receiving on port 9997..."
CHECK=$(curl -sk -u "${SPLUNK_USER}:${SPLUNK_PASS}" \
    "https://${SPLUNK_HOST}:${SPLUNK_MGMT_PORT}/services/data/inputs/tcp/cooked/9997" \
    -o /dev/null -w "%{http_code}")

if [ "$CHECK" = "200" ]; then
    echo "Receiving on port 9997 already configured."
else
    echo "Enabling receiving on port 9997..."
    curl -sk -u "${SPLUNK_USER}:${SPLUNK_PASS}" \
        "https://${SPLUNK_HOST}:${SPLUNK_MGMT_PORT}/services/data/inputs/tcp/cooked" \
        -d "name=9997" \
        -o /dev/null -w "" 2>/dev/null
    echo "Receiving on port 9997 enabled."
fi

echo "Splunk setup complete."
