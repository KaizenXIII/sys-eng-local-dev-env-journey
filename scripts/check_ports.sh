#!/bin/bash
# Check if required ports are available
set -e

PORTS=(8000 8088 8089 9997 2221 2222 2223)
ALL_CLEAR=true

for PORT in "${PORTS[@]}"; do
    if lsof -i ":${PORT}" > /dev/null 2>&1; then
        echo "ERROR: Port ${PORT} is already in use:"
        lsof -i ":${PORT}" | head -3
        ALL_CLEAR=false
    else
        echo "OK: Port ${PORT} is available"
    fi
done

if [ "$ALL_CLEAR" = false ]; then
    echo ""
    echo "Some ports are in use. Free them before proceeding."
    exit 1
fi

echo ""
echo "All ports are available."
