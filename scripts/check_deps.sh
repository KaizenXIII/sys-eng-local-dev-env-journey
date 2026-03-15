#!/bin/bash
# Verify all required tools are installed
set -e

MISSING=0

check_cmd() {
    local cmd="$1"
    local min_version="$2"
    local install_hint="$3"
    if command -v "$cmd" > /dev/null 2>&1; then
        local version
        version=$("$cmd" --version 2>&1 | head -1)
        echo "  [OK]   $cmd  ($version)"
    else
        echo "  [MISS] $cmd  — install with: $install_hint"
        MISSING=$((MISSING + 1))
    fi
}

echo ""
echo "═══════════════════════════════════════════════════"
echo "  DEPENDENCY CHECK"
echo "═══════════════════════════════════════════════════"
echo ""

check_cmd "podman"          "" "brew install podman"
check_cmd "ansible"         "" "brew install ansible"
check_cmd "ansible-playbook" "" "brew install ansible"
check_cmd "curl"            "" "brew install curl"
check_cmd "ssh"             "" "(included with macOS)"
check_cmd "make"            "" "xcode-select --install"

echo ""

if [ "$MISSING" -gt 0 ]; then
    echo "  $MISSING missing dependency(ies). Install them and retry."
    exit 1
else
    echo "  All dependencies present."
fi
echo ""
