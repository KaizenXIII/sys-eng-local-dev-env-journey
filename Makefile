.PHONY: all check-ports network build-nodes run-nodes splunk splunk-index \
       install-uf ping clean stop status help

PODMAN := podman
ANSIBLE_DIR := ansible
SCRIPTS_DIR := scripts
NETWORK := lab-network
IMAGE_NAME := lab-rhel9-node
SPLUNK_IMAGE := docker.io/splunk/splunk:latest
SPLUNK_NAME := splunk-standalone
SPLUNK_IP := 10.89.0.10

help: ## Show this help
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | \
		awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-15s\033[0m %s\n", $$1, $$2}'

all: check-ports network build-nodes run-nodes splunk splunk-index install-uf ping ## Full setup: build everything, configure, and run ping test

check-ports: ## Check if required ports are available
	@bash $(SCRIPTS_DIR)/check_ports.sh

network: ## Create Podman network for lab nodes
	@echo "Creating Podman network '$(NETWORK)'..."
	@$(PODMAN) network create $(NETWORK) --subnet 10.89.0.0/24 2>/dev/null || \
		echo "Network '$(NETWORK)' already exists."

build-nodes: ## Build the RHEL9 node container image
	@echo "Building container image '$(IMAGE_NAME)'..."
	$(PODMAN) build -t $(IMAGE_NAME) containers/rhel9/

run-nodes: ## Start the 3 lab node containers
	@echo "Starting lab node containers..."
	@$(PODMAN) run -d --name node1 --hostname node1 \
		--network $(NETWORK) --ip 10.89.0.11 \
		-p 2221:22 $(IMAGE_NAME) 2>/dev/null || \
		echo "node1 already running"
	@$(PODMAN) run -d --name node2 --hostname node2 \
		--network $(NETWORK) --ip 10.89.0.12 \
		-p 2222:22 $(IMAGE_NAME) 2>/dev/null || \
		echo "node2 already running"
	@$(PODMAN) run -d --name node3 --hostname node3 \
		--network $(NETWORK) --ip 10.89.0.13 \
		-p 2223:22 $(IMAGE_NAME) 2>/dev/null || \
		echo "node3 already running"
	@echo "Waiting for SSH to be ready..."
	@sleep 3
	@echo "Lab nodes are up."

splunk: ## Start Splunk standalone container in Podman
	@echo "Starting Splunk in Podman..."
	@$(PODMAN) run -d --name $(SPLUNK_NAME) --hostname splunk \
		--platform linux/amd64 \
		--network $(NETWORK) --ip $(SPLUNK_IP) \
		-p 8000:8000 -p 8088:8088 -p 8089:8089 -p 9997:9997 \
		-e SPLUNK_START_ARGS=--accept-license \
		-e SPLUNK_GENERAL_TERMS=--accept-sgt-current-at-splunk-com \
		-e SPLUNK_PASSWORD=ChangeMeNow1! \
		-e SPLUNK_HEC_TOKEN=a1b2c3d4-e5f6-7890-abcd-ef1234567890 \
		$(SPLUNK_IMAGE) 2>/dev/null || \
		echo "$(SPLUNK_NAME) already running"
	@echo "Splunk starting at http://localhost:8000 (admin / ChangeMeNow1!)"

splunk-index: ## Create ping_data index in Splunk
	@bash $(SCRIPTS_DIR)/setup_splunk_index.sh

install-uf: ## Install Splunk Universal Forwarder on all nodes
	@echo "Installing Splunk UF on lab nodes..."
	cd $(ANSIBLE_DIR) && ansible-playbook playbooks/install_splunk_uf.yml

ping: ## Run ICMP ping test and log results
	@echo "Running ping test..."
	cd $(ANSIBLE_DIR) && ansible-playbook playbooks/ping_test.yml

status: ## Show status of all containers
	@echo "=== All Podman Containers ==="
	@$(PODMAN) ps -a --filter "name=node" --filter "name=splunk" \
		--format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"

stop: ## Stop all containers
	@echo "Stopping all containers..."
	@$(PODMAN) stop node1 node2 node3 $(SPLUNK_NAME) 2>/dev/null || true
	@echo "All containers stopped."

clean: stop ## Stop and remove all containers, network, and volumes
	@echo "Removing all containers..."
	@$(PODMAN) rm -f node1 node2 node3 $(SPLUNK_NAME) 2>/dev/null || true
	@echo "Removing network..."
	@$(PODMAN) network rm $(NETWORK) 2>/dev/null || true
	@echo "Cleanup complete."
