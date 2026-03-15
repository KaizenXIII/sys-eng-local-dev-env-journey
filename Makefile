.PHONY: all check-deps check-ports ssh-keys build-nodes up down splunk-index \
       install-uf ping ps test clean stop restart status logs log-rotate help

PODMAN := podman
ANSIBLE_DIR := ansible
SCRIPTS_DIR := scripts
SPLUNK_UF_ARCH := $(shell bash $(SCRIPTS_DIR)/detect_arch.sh)
IMAGE_NAME := lab-rhel9-node
SSH_KEY := $(ANSIBLE_DIR)/keys/lab_node
LAB_SPLUNK_PASSWORD ?= ChangeMeNow1!
LAB_ROOT_PASSWORD ?= changeme
LAB_HEC_TOKEN ?= a1b2c3d4-e5f6-7890-abcd-ef1234567890

# Export for compose.yml env var substitution
export LAB_SPLUNK_PASSWORD
export LAB_HEC_TOKEN

help: ## Show this help
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | \
		awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-15s\033[0m %s\n", $$1, $$2}'

all: check-deps check-ports ssh-keys build-nodes up splunk-index install-uf ping ps test ## Full setup end-to-end with validation

check-deps: ## Verify required tools are installed
	@bash $(SCRIPTS_DIR)/check_deps.sh

check-ports: ## Check if required ports are available
	@bash $(SCRIPTS_DIR)/check_ports.sh

ssh-keys: ## Generate SSH keypair for Ansible
	@bash $(SCRIPTS_DIR)/generate_ssh_keys.sh

build-nodes: ssh-keys ## Build the RHEL9 node container image
	@echo "Building container image '$(IMAGE_NAME)'..."
	$(PODMAN) build -t $(IMAGE_NAME) \
		--build-arg SSH_PUB_KEY="$$(cat $(SSH_KEY).pub)" \
		--build-arg ROOT_PASSWORD="$(LAB_ROOT_PASSWORD)" \
		containers/rhel9/

up: ## Start all containers (nodes + Splunk) via compose
	@echo "Starting lab environment..."
	$(PODMAN) compose up -d
	@echo "Waiting for SSH to be ready..."
	@sleep 3
	@echo "Lab environment is up."

down: ## Stop and remove all containers via compose
	$(PODMAN) compose down

splunk-index: ## Create Splunk indexes (waits for readiness)
	@LAB_SPLUNK_PASSWORD=$(LAB_SPLUNK_PASSWORD) bash $(SCRIPTS_DIR)/setup_splunk_index.sh

install-uf: ## Install Splunk Universal Forwarder on all nodes
	@echo "Installing Splunk UF on lab nodes (arch: $(SPLUNK_UF_ARCH))..."
	cd $(ANSIBLE_DIR) && ansible-playbook playbooks/install_splunk_uf.yml -e "splunk_uf_arch=$(SPLUNK_UF_ARCH)" -e "lab_splunk_password=$(LAB_SPLUNK_PASSWORD)"

ping: ## Run ICMP ping test and log results
	@echo "Running ping test..."
	cd $(ANSIBLE_DIR) && ansible-playbook playbooks/ping_test.yml

ps: ## Capture process snapshots and log results
	@echo "Running process snapshot..."
	cd $(ANSIBLE_DIR) && ansible-playbook playbooks/ps_snapshot.yml

log-rotate: ## Prune old logs (keep newest 50 per node)
	@echo "Rotating logs..."
	cd $(ANSIBLE_DIR) && ansible-playbook playbooks/log_rotate.yml

test: ## Run end-to-end validation
	@LAB_SPLUNK_PASSWORD=$(LAB_SPLUNK_PASSWORD) bash $(SCRIPTS_DIR)/test_e2e.sh

logs: ## Show recent ping and ps logs from all nodes
	@for NODE in node1 node2 node3; do \
		echo ""; \
		echo "═══ $$NODE — ping logs ═══"; \
		$(PODMAN) exec $$NODE bash -c 'FILE=$$(ls -t /var/log/ping_logs/ping_*.log 2>/dev/null | head -1); [ -f "$$FILE" ] && tail -20 "$$FILE" || echo "  (no ping logs)"' 2>/dev/null; \
		echo ""; \
		echo "═══ $$NODE — ps logs ═══"; \
		$(PODMAN) exec $$NODE bash -c 'FILE=$$(ls -t /var/log/ps_logs/ps_*.log 2>/dev/null | head -1); [ -f "$$FILE" ] && tail -20 "$$FILE" || echo "  (no ps logs)"' 2>/dev/null; \
	done

status: ## Show status of all containers
	@echo "=== All Podman Containers ==="
	@$(PODMAN) ps -a --filter "name=node" --filter "name=splunk" \
		--format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"

stop: ## Stop all containers
	$(PODMAN) compose stop

restart: ## Restart all containers
	$(PODMAN) compose restart
	@echo "Waiting for SSH to be ready..."
	@sleep 3
	@echo "All containers restarted."

clean: ## Stop and remove all containers, network, and images
	$(PODMAN) compose down --remove-orphans 2>/dev/null || true
	@echo "Cleanup complete."
