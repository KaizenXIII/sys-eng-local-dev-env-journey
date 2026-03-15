#!/bin/bash
# Create the ping_data index in Splunk and enable receiving on port 9997
set -e

SPLUNK_HOST="localhost"
SPLUNK_PORT="8000"
SPLUNK_MGMT_PORT="8089"
SPLUNK_USER="admin"
SPLUNK_PASS="ChangeMeNow1!"
INDEX_NAME="ping_data"

echo "Waiting for Splunk to be ready..."
until curl -sk -o /dev/null -w "%{http_code}" "http://${SPLUNK_HOST}:${SPLUNK_PORT}/en-US/account/login" 2>/dev/null | grep -q "200"; do
    echo "  Splunk not ready yet, retrying in 10s..."
    sleep 10
done
echo "Splunk is ready."

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

echo "Enabling receiving on port 9997..."
RESPONSE=$(curl -sk -u "${SPLUNK_USER}:${SPLUNK_PASS}" \
    "https://${SPLUNK_HOST}:${SPLUNK_MGMT_PORT}/servicesNS/nobody/system/data/inputs/splunktcp" \
    -d "name=9997" \
    -o /dev/null -w "%{http_code}")

if [ "$RESPONSE" = "201" ]; then
    echo "Receiving on port 9997 enabled."
elif [ "$RESPONSE" = "409" ]; then
    echo "Receiving on port 9997 already configured."
else
    echo "Warning: Got HTTP ${RESPONSE} when enabling listener. Continuing..."
fi

echo "Splunk setup complete."
