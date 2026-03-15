# Systems Engineering Local Dev Environment Journey

A self-contained lab environment for practicing systems engineering fundamentals on macOS. Spins up three RHEL9 (UBI9) containers in Podman, manages them with Ansible from the Mac host, runs ICMP ping tests between nodes, and ships the results to a local Splunk Enterprise instance for analysis.

## Table of Contents

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

> Splunk Enterprise has no ARM64 image and runs under `--platform linux/amd64` via QEMU emulation on Apple Silicon. Startup takes 3-5 minutes.

## Quick Start

```bash
make all
```

This will:
1. Check that required ports are free
2. Create the Podman network (`10.89.0.0/24`)
3. Build the RHEL9 node image and start 3 containers
4. Start Splunk Enterprise, create the `ping_data` index, and enable receiving on port 9997
5. Install the Splunk Universal Forwarder on each node via Ansible
6. Run ICMP ping tests between all nodes and log results

Open Splunk at **http://localhost:8000** and search `index=ping_data` to see the forwarded ping results.

## Make Targets

```
make help            Show all available targets
make all             Full setup end-to-end
make check-ports     Verify ports 8000,8088,8089,9997,2221-2223 are free
make network         Create the lab-network (10.89.0.0/24)
make build-nodes     Build the RHEL9 node container image
make run-nodes       Start node1, node2, node3
make splunk          Start Splunk Enterprise container
make splunk-index    Create the ping_data index and enable receiving
make install-uf      Deploy Splunk Universal Forwarder to all nodes
make ping            Run ICMP ping tests between nodes
make status          Show container status
make stop            Stop all containers
make clean           Stop and remove all containers and network
```

## Project Structure

```
.
├── Makefile                              # Orchestrates the entire lab
├── containers/
│   └── rhel9/
│       └── Containerfile                 # UBI9 image with SSH, ping, sudo
├── ansible/
│   ├── ansible.cfg                       # Ansible configuration
│   ├── inventory.ini                     # Node inventory (localhost:2221-2223)
│   └── playbooks/
│       ├── install_splunk_uf.yml         # Deploys and configures Splunk UF
│       └── ping_test.yml                 # Runs ICMP pings, writes to /var/log/ping_logs/
└── scripts/
    ├── check_ports.sh                    # Pre-flight port availability check
    └── setup_splunk_index.sh             # Creates ping_data index via Splunk REST API
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
ssh -o StrictHostKeyChecking=no ansible@127.0.0.1 -p 2221   # node1
ssh -o StrictHostKeyChecking=no ansible@127.0.0.1 -p 2222   # node2
ssh -o StrictHostKeyChecking=no ansible@127.0.0.1 -p 2223   # node3
```

### Run the ping test

```bash
make ping
```

### Search ping data in Splunk

1. Open **http://localhost:8000**
2. Log in with `admin` / `ChangeMeNow1!`
3. Search: `index=ping_data sourcetype=ping_results`

### Check lab status

```bash
make status
```

## Credentials

| Service            | Username | Password      |
|--------------------|----------|---------------|
| Splunk Web         | admin    | ChangeMeNow1! |
| Node SSH (root)    | root     | changeme      |
| Node SSH (ansible) | ansible  | ansible       |

> Lab-only credentials. Do not use in any shared or production environment.

## Cleanup

```bash
make clean
```

## Troubleshooting

**Port conflict on startup** — Run `make check-ports` to identify which ports are occupied.

**Splunk takes a long time to start** — On Apple Silicon with amd64 emulation, initial startup takes 3-5 minutes. The `setup_splunk_index.sh` script polls until the web UI responds.

**Ansible connection refused** — Nodes need a few seconds after `podman run` for sshd to start. Wait a moment and retry.

**Splunk UF not forwarding data** — SSH into a node and check:
```bash
/opt/splunkforwarder/bin/splunk status
/opt/splunkforwarder/bin/splunk list forward-server
```

---

> *On Her Majesty's server. 2026-03-14*
