# Systems Engineering Local Dev Environment Journey

A self-contained lab environment for practicing systems engineering fundamentals on macOS. Spins up three RHEL9 (UBI9) containers in Podman, manages them with Ansible from the Mac host, runs ICMP ping tests and process snapshots across nodes, and ships all results to a local Splunk Enterprise instance for analysis.

## Table of Contents

- [Features](#features)
- [Architecture](#architecture)
- [Prerequisites](#prerequisites)
- [Quick Start](#quick-start)
- [Make Targets](#make-targets)
- [Project Structure](#project-structure)
- [Network Layout](#network-layout)
- [Usage](#usage)
- [Credentials](#credentials)
- [Cleanup](#cleanup)
- [Troubleshooting](#troubleshooting)

## Features

- **Three RHEL9 nodes** running as Podman containers with SSH, sudo, ping, and ps utilities
- **Ansible-managed** -- all node configuration driven by playbooks and a centralized inventory
- **SSH key authentication** -- ed25519 keypair generated at build time and baked into node images
- **ICMP ping tests** between all nodes with timestamped log files
- **Process snapshots** captured via `ps aux` on every node, sorted by memory usage
- **Splunk integration** -- Universal Forwarder on each node ships logs to a local Splunk Enterprise instance
- **Two Splunk indexes** -- `ping_data` for network tests, `ps_data` for process snapshots
- **End-to-end validation** -- automated test script checks containers, SSH, Splunk API, UF forwarding, and data flow
- **Single-command setup** -- `make all` takes the lab from zero to fully operational

## Architecture

```
┌──────────────────────────────────────────────────────────────┐
│  macOS Host (Ansible control node)                           │
│                                                              │
│  ┌──────────── Podman Network: lab-network ──────────────┐   │
│  │  10.89.0.0/24                                         │   │
│  │                                                       │   │
│  │  ┌─────────┐  ┌─────────┐  ┌─────────┐               │   │
│  │  │  node1   │  │  node2   │  │  node3   │              │   │
│  │  │ .0.11    │  │ .0.12    │  │ .0.13    │              │   │
│  │  │ :2221→22 │  │ :2222→22 │  │ :2223→22 │              │   │
│  │  │ RHEL9    │  │ RHEL9    │  │ RHEL9    │              │   │
│  │  │ + UF     │  │ + UF     │  │ + UF     │              │   │
│  │  └────┬─────┘  └────┬─────┘  └────┬─────┘              │   │
│  │       │    ICMP ping │             │                    │   │
│  │       └──────────────┼─────────────┘                    │   │
│  │                      │ TCP 9997                         │   │
│  │              ┌───────▼────────┐                         │   │
│  │              │ Splunk          │                         │   │
│  │              │ .0.10 (amd64)   │                         │   │
│  │              │ :8000 Web       │                         │   │
│  │              │ :8089 Mgmt      │                         │   │
│  │              │ :9997 Receiving  │                         │   │
│  │              └─────────────────┘                         │   │
│  └───────────────────────────────────────────────────────┘   │
└──────────────────────────────────────────────────────────────┘
```

## Prerequisites

| Tool     | Install                     |
|----------|-----------------------------|
| Homebrew | [brew.sh](https://brew.sh)  |
| Podman   | `brew install podman`       |
| Ansible  | `brew install ansible`      |

Initialize and start the Podman machine (first time only):

```bash
podman machine init
podman machine start
```

> **Apple Silicon note:** Splunk Enterprise has no ARM64 image and runs under `--platform linux/amd64` via QEMU emulation. Startup takes 3-5 minutes. The Splunk Universal Forwarder, however, uses a native ARM64 build (configured in `ansible/group_vars/all.yml`).

> **Intel Mac users:** Update `splunk_uf_url` in `ansible/group_vars/all.yml` to point to the `linux-amd64.tgz` package before running `make all`.

## Quick Start

```bash
make all
```

This will:
1. Check that required ports are free
2. Generate an SSH keypair for Ansible (ed25519, stored in `ansible/keys/`)
3. Create the Podman network (`10.89.0.0/24`)
4. Build the RHEL9 node image (with the public key baked in) and start 3 containers
5. Start Splunk Enterprise, create the `ping_data` and `ps_data` indexes, and enable receiving on port 9997
6. Install the Splunk Universal Forwarder on each node via Ansible (monitors both ping and ps logs)
7. Run ICMP ping tests between all nodes and log results
8. Run end-to-end validation to confirm everything is working

> **Note:** Process snapshots (`make ps`) are not included in `make all` and must be run separately.

Open Splunk at **http://localhost:8000** and search `index=ping_data` or `index=ps_data` to see forwarded results.

## Make Targets

```
make help            Show all available targets
make all             Full setup end-to-end with validation
make check-ports     Verify ports 8000,8088,8089,9997,2221-2223 are free
make ssh-keys        Generate SSH keypair for Ansible
make network         Create the lab-network (10.89.0.0/24)
make build-nodes     Build the RHEL9 node container image
make run-nodes       Start node1, node2, node3
make splunk          Start Splunk Enterprise container
make splunk-index    Create Splunk indexes and enable receiving
make install-uf      Deploy Splunk Universal Forwarder to all nodes
make ping            Run ICMP ping tests between nodes
make ps              Capture process snapshots on all nodes
make test            Run end-to-end validation
make status          Show container status
make stop            Stop all containers
make restart         Restart all containers
make clean           Stop and remove all containers and network
```

## Project Structure

```
.
├── Makefile                              # Orchestrates the entire lab
├── containers/
│   └── rhel9/
│       └── Containerfile                 # UBI9 image with SSH, ping, ps, sudo
├── ansible/
│   ├── ansible.cfg                       # Ansible configuration
│   ├── inventory.ini                     # Node inventory (localhost:2221-2223)
│   ├── group_vars/
│   │   └── all.yml                       # Shared variables (IPs, paths, Splunk config)
│   ├── keys/                             # Generated SSH keypair (git-ignored)
│   └── playbooks/
│       ├── install_splunk_uf.yml         # Deploys and configures Splunk UF
│       ├── ping_test.yml                 # Runs ICMP pings, writes to /var/log/ping_logs/
│       └── ps_snapshot.yml               # Captures process snapshots to /var/log/ps_logs/
└── scripts/
    ├── check_ports.sh                    # Pre-flight port availability check
    ├── generate_ssh_keys.sh              # Creates ed25519 keypair for Ansible
    ├── setup_splunk_index.sh             # Creates ping_data and ps_data indexes
    └── test_e2e.sh                       # End-to-end lab validation
```

## Network Layout

| Container         | Hostname | IP Address  | Host Port(s)             |
|-------------------|----------|-------------|--------------------------|
| node1             | node1    | 10.89.0.11  | 2221 -> 22 (SSH)         |
| node2             | node2    | 10.89.0.12  | 2222 -> 22 (SSH)         |
| node3             | node3    | 10.89.0.13  | 2223 -> 22 (SSH)         |
| splunk-standalone | splunk   | 10.89.0.10  | 8000, 8088, 8089, 9997   |

## Usage

### SSH into a node

```bash
ssh -i ansible/keys/lab_node -o StrictHostKeyChecking=no ansible@127.0.0.1 -p 2221   # node1
ssh -i ansible/keys/lab_node -o StrictHostKeyChecking=no ansible@127.0.0.1 -p 2222   # node2
ssh -i ansible/keys/lab_node -o StrictHostKeyChecking=no ansible@127.0.0.1 -p 2223   # node3
```

### Run the ping test

```bash
make ping
```

Results are written to `/var/log/ping_logs/` on each node and forwarded to the `ping_data` Splunk index.

### Capture process snapshots

```bash
make ps
```

Results are written to `/var/log/ps_logs/` on each node and forwarded to the `ps_data` Splunk index.

### Run end-to-end validation

```bash
make test
```

Validates containers, SSH connectivity, Splunk API, Universal Forwarder status, and data flow.

### Search data in Splunk

1. Open **http://localhost:8000**
2. Log in with `admin` / `ChangeMeNow1!`
3. Search: `index=ping_data sourcetype=ping_results`
4. Search: `index=ps_data sourcetype=ps_snapshot`

### Check lab status

```bash
make status
```

## Credentials

| Service            | Username | Password      |
|--------------------|----------|---------------|
| Splunk Web         | admin    | ChangeMeNow1! |
| Node SSH (root)    | root     | changeme      |
| Node SSH (ansible) | ansible  | key-based (ansible/keys/lab_node) |

> Lab-only credentials. Do not use in any shared or production environment.

## Cleanup

```bash
make clean
```

This stops and removes all containers (node1, node2, node3, splunk-standalone) and the `lab-network` Podman network. SSH keys in `ansible/keys/` are preserved so subsequent `make all` runs reuse them.

## Troubleshooting

**Port conflict on startup** -- Run `make check-ports` to identify which ports are occupied. Kill the offending process or change the port mapping in the Makefile.

**Splunk takes a long time to start** -- On Apple Silicon with amd64 emulation, initial startup takes 3-5 minutes. The `setup_splunk_index.sh` script polls the management API every 10 seconds until it responds.

**Ansible connection refused** -- Nodes need a few seconds after `podman run` for sshd to start. The Makefile includes a 3-second sleep, but if you still see failures, wait a moment and retry.

**Splunk UF not forwarding data** -- SSH into a node and check:

```bash
/opt/splunkforwarder/bin/splunk status
/opt/splunkforwarder/bin/splunk list forward-server -auth admin:ChangeMeNow1!
```

**No events in Splunk** -- After running `make ping` or `make ps`, allow 30-60 seconds for the Universal Forwarder to pick up and ship the log files. Verify the UF `inputs.conf` is monitoring the correct paths:

```bash
cat /opt/splunkforwarder/etc/system/local/inputs.conf
```

**Rebuilding from scratch** -- Run `make clean` followed by `make all` for a completely fresh environment.

---

> *The spy who logged me. 2026-03-15 13:32 PDT*
