#!/bin/bash
# Detect host architecture and output the matching Splunk UF arch string
ARCH=$(uname -m)
case "$ARCH" in
    arm64|aarch64) echo "arm64" ;;
    x86_64)        echo "amd64" ;;
    *)             echo "Unsupported architecture: $ARCH" >&2; exit 1 ;;
esac
