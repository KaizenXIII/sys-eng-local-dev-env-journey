#!/usr/bin/env bash
set -e

if [ $(id -u) -ge 500 ]; then
    echo "awx:x:$(id -u):$(id -g):,,,:/var/lib/awx:/bin/bash" >> /tmp/passwd
    cat /tmp/passwd > /etc/passwd
    rm /tmp/passwd
fi

echo "[launch_awx_task] Waiting for migrations..."
attempt=0
while true; do
    if awx-manage showmigrations 2>/dev/null | grep -q '\[ \]'; then
        attempt=$((attempt + 1))
        echo "[launch_awx_task] Unapplied migrations found, waiting... (attempt $attempt)"
        sleep 5
    else
        echo "[launch_awx_task] All migrations applied."
        break
    fi
    if [ $attempt -ge 120 ]; then
        echo "[launch_awx_task] ERROR: Timed out waiting for migrations"
        exit 1
    fi
done

echo "[launch_awx_task] Provisioning instance..."
awx-manage provision_instance --hostname=awx-task --node_type=hybrid 2>&1 || true
awx-manage register_queue --queuename=default --hostnames=awx-task 2>&1 || true

# Install receptor if not present
if ! command -v receptor &>/dev/null; then
    echo "[launch_awx_task] Installing receptor..."
    ARCH=$(uname -m)
    if [ "$ARCH" = "aarch64" ]; then
        RECEPTOR_ARCH="arm64"
    else
        RECEPTOR_ARCH="amd64"
    fi
    curl -sL "https://github.com/ansible/receptor/releases/download/v1.6.4/receptor_1.6.4_linux_${RECEPTOR_ARCH}.tar.gz" \
        | tar xz -C /usr/local/bin receptor
    chmod +x /usr/local/bin/receptor
    echo "[launch_awx_task] Receptor installed."
fi

mkdir -p /var/run/receptor
rm -f /var/run/receptor/receptor.sock /var/run/receptor/receptor.sock.lock

echo "[launch_awx_task] Starting supervisord..."
exec supervisord -c /opt/awx/supervisord_task.conf
