.PHONY: codegen
.PHONY: deploy
.PHONY: deploy-all
.PHONY: deploy-arbitrum-mainnet
.PHONY: deploy-arbitrum-sepolia
.PHONY: deploy-base-mainnet
.PHONY: deploy-base-sepolia
.PHONY: deploy-ethereum-mainnet
.PHONY: deploy-ethereum-sepolia
.PHONY: deploy-mainnets
.PHONY: deploy-op-mainnet
.PHONY: deploy-op-sepolia
.PHONY: deploy-testnets
.PHONY: devnet

PROJECT_MAJOR_VERSION  := 3
PROJECT_MINOR_VERSION  := 0
PROJECT_PATCH_VERSION  := 0
PROJECT_PRE_RELEASE    := alpha.6
PROJECT_BUILD_METADATA :=

MAKEFLAGS += --no-print-directory

ANVIL := anvil
CAST  := cast
FORGE := forge

ANVIL_RPC_URL := http://127.0.0.1:8545
ANVIL_PK      := 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80
ANVIL_STATE   := state.json

ANVIL_RUNTIME_OPTS += --dump-state $(ANVIL_STATE)
ANVIL_RUNTIME_OPTS += --preserve-historical-states
ANVIL_RUNTIME_OPTS += --quiet

ANVIL_DEPLOY_OPTS += --private-key $(ANVIL_PK)
ANVIL_DEPLOY_OPTS += --rpc-url $(ANVIL_RPC_URL)
ANVIL_DEPLOY_OPTS += --non-interactive
ANVIL_DEPLOY_OPTS += --broadcast
ANVIL_DEPLOY_OPTS += --slow

ARBITRUM_MAINNET_RPC_URL  ?= https://arb1.arbitrum.io/rpc
ARBITRUM_SEPOLIA_RPC_URL  ?= https://sepolia-rollup.arbitrum.io/rpc
BASE_MAINNET_RPC_URL      ?= https://mainnet.base.org
BASE_SEPOLIA_RPC_URL      ?= https://sepolia.base.org
ETHEREUM_MAINNET_RPC_URL  ?= https://eth.drpc.org
ETHEREUM_SEPOLIA_RPC_URL  ?= https://sepolia.drpc.org
OP_MAINNET_RPC_URL        ?= https://mainnet.optimism.io
OP_SEPOLIA_RPC_URL        ?= https://sepolia.optimism.io

export ARBITRUM_MAINNET_RPC_URL
export ARBITRUM_SEPOLIA_RPC_URL
export BASE_MAINNET_RPC_URL
export BASE_SEPOLIA_RPC_URL
export ETHEREUM_MAINNET_RPC_URL
export ETHEREUM_SEPOLIA_RPC_URL
export OP_MAINNET_RPC_URL
export OP_SEPOLIA_RPC_URL

codegen:
	@echo "🚧 Generating code..."
	@$(FORGE) script script/CodeGeneration.s.sol:DeployersCodeGenerationScript
	@$(FORGE) script script/CodeGeneration.s.sol:VersionCodeGenerationScript \
		--sig 'run(uint64,uint64,uint64,string,string)' -- \
		"$(PROJECT_MAJOR_VERSION)" \
		"$(PROJECT_MINOR_VERSION)" \
		"$(PROJECT_PATCH_VERSION)" \
		"$(PROJECT_PRE_RELEASE)" \
		"$(PROJECT_BUILD_METADATA)"
	@echo "🚧 Formatting generated code..."
	@$(FORGE) fmt \
		script/utils/ContractDeployers.sol \
		src/common/Version.sol
	@echo "✅ Successfully generated and formatted code."

deploy:
	@$(FORGE) script script/Deployment.s.sol:DeploymentScript $(DEPLOY_OPTS)

deploy-all: devnet deploy-testnets deploy-mainnets

devnet:
	@set -eu; \
	echo "🔨 Building Anvil devnet..." ; \
	cleanup() { \
		exit_code=$$?; \
		if kill -0 "$${anvil_pid}" 2>/dev/null; then \
			echo "🚧 Killing Anvil (PID $${anvil_pid})..."; \
			kill "$${anvil_pid}"; \
			echo "🚧 Waiting for Anvil to finish...."; \
			wait "$${anvil_pid}"; \
			anvil_exit_code=$$?; \
			if [ "$${anvil_exit_code}" -eq 0 ]; then \
				echo "✅ Anvil exited with code $${anvil_exit_code}"; \
			else \
				echo "❌ Anvil exited with code $${anvil_exit_code}"; \
				if [ "$${exit_code}" -eq 0 ]; then \
					exit_code=$${anvil_exit_code}; \
				fi; \
			fi; \
		else \
			echo "💡 Anvil (PID $${anvil_pid}) exited prematurely"; \
		fi; \
		exit "$${exit_code}"; \
	}; \
	trap cleanup EXIT; \
	echo "🚧 Spawning Anvil..."; \
	$(ANVIL) $(ANVIL_RUNTIME_OPTS) & \
	anvil_pid=$$!; \
	echo "✅ Anvil spawned!"; \
	listening=0; \
	i=0; \
	while [ "$$i" -lt 5 ]; do \
		echo "🚧 Pinging Anvil..."; \
		if $(CAST) chain-id >/dev/null 2>/dev/null; then \
			echo "✅ Anvil is listening!"; \
			listening=1; \
			break; \
		else \
			echo "🚧 Anvil is not listening yet. Waiting 1s..."; \
			sleep 1; \
		fi; \
		i=$$((i+1)); \
	done; \
	if [ "$${listening}" -eq 0 ]; then \
		echo "❌ Anvil did not respond within a reasonable amount of time." >&2; \
		exit 1; \
	fi; \
	echo "🔨 Deploying to Anvil (Chain ID: 31337)..."; \
	$(MAKE) deploy DEPLOY_OPTS="$(ANVIL_DEPLOY_OPTS)" ; \
	echo "✅ Successfully built Anvil devnet."

deploy-testnets: deploy-ethereum-sepolia
deploy-testnets: deploy-op-sepolia
deploy-testnets: deploy-base-sepolia
deploy-testnets: deploy-arbitrum-sepolia

deploy-mainnets: deploy-ethereum-mainnet
deploy-mainnets: deploy-op-mainnet
deploy-mainnets: deploy-base-mainnet
deploy-mainnets: deploy-arbitrum-mainnet

deploy-ethereum-sepolia:
	@echo "🌐 Running deployment script against Ethereum Sepolia..."
	@$(MAKE) deploy DEPLOY_OPTS="--chain-id 11155111 --rpc-url ethereum_sepolia $(DEPLOY_OPTS)"
	@echo "✅ Deployment script successfully ran against Ethereum Sepolia."

deploy-op-sepolia:
	@echo "🌐 Running deployment script against OP Sepolia..."
	@$(MAKE) deploy DEPLOY_OPTS="--chain-id 11155420 --rpc-url op_sepolia $(DEPLOY_OPTS)"
	@echo "✅ Deployment script successfully ran against OP Sepolia."

deploy-base-sepolia:
	@echo "🌐 Running deployment script against Base Sepolia..."
	@$(MAKE) deploy DEPLOY_OPTS="--chain-id 84532 --rpc-url base_sepolia $(DEPLOY_OPTS)"
	@echo "✅ Deployment script successfully ran against Base Sepolia."

deploy-arbitrum-sepolia:
	@echo "🌐 Running deployment script against Arbitrum Sepolia..."
	@$(MAKE) deploy DEPLOY_OPTS="--chain-id 421614 --rpc-url arbitrum_sepolia $(DEPLOY_OPTS)"
	@echo "✅ Deployment script successfully ran against Arbitrum Sepolia."

deploy-ethereum-mainnet:
	@echo "🌐 Running deployment script against Ethereum Mainnet..."
	@$(MAKE) deploy DEPLOY_OPTS="--chain-id 1 --rpc-url ethereum_mainnet $(DEPLOY_OPTS)"
	@echo "✅ Deployment script successfully ran against Ethereum Mainnet."

deploy-op-mainnet:
	@echo "🌐 Running deployment script against OP Mainnet..."
	@$(MAKE) deploy DEPLOY_OPTS="--chain-id 10 --rpc-url op_mainnet $(DEPLOY_OPTS)"
	@echo "✅ Deployment script successfully ran against OP Mainnet."

deploy-base-mainnet:
	@echo "🌐 Running deployment script against Base Mainnet..."
	@$(MAKE) deploy DEPLOY_OPTS="--chain-id 8453 --rpc-url base_mainnet $(DEPLOY_OPTS)"
	@echo "✅ Deployment script successfully ran against Base Mainnet."

deploy-arbitrum-mainnet:
	@echo "🌐 Running deployment script against Arbitrum Mainnet..."
	@$(MAKE) deploy DEPLOY_OPTS="--chain-id 42161 --rpc-url arbitrum_mainnet $(DEPLOY_OPTS)"
	@echo "✅ Deployment script successfully ran against Arbitrum Mainnet."
