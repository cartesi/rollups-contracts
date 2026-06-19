.PHONY: build
.PHONY: codegen
.PHONY: coverage
.PHONY: deploy-all
.PHONY: deploy-arb-mainnet
.PHONY: deploy-arb-sepolia
.PHONY: deploy-base-mainnet
.PHONY: deploy-base-sepolia
.PHONY: deploy-eth-mainnet
.PHONY: deploy-eth-sepolia
.PHONY: deploy-livenets
.PHONY: deploy-mainnets
.PHONY: deploy-opt-mainnet
.PHONY: deploy-opt-sepolia
.PHONY: deploy-testnets
.PHONY: devnet
.PHONY: print-foundry-version
.PHONY: publish-soldeer-package
.PHONY: release-artifacts
.PHONY: rust-bindings

PROJECT_NAME := cartesi-rollups-contracts

PROJECT_MAJOR_VERSION  := 3
PROJECT_MINOR_VERSION  := 0
PROJECT_PATCH_VERSION  := 0
PROJECT_PRE_RELEASE    := alpha.6
PROJECT_BUILD_METADATA :=

PROJECT_VERSION := $(PROJECT_MAJOR_VERSION).$(PROJECT_MINOR_VERSION).$(PROJECT_PATCH_VERSION)
PROJECT_VERSION := $(PROJECT_VERSION)$(if $(PROJECT_PRE_RELEASE),-$(PROJECT_PRE_RELEASE))
PROJECT_VERSION := $(PROJECT_VERSION)$(if $(PROJECT_BUILD_METADATA),+$(PROJECT_BUILD_METADATA))

FOUNDRY_VERSION := 1.5.1
LCOV_VERSION    := 2.0

DIST := dist

BUNDLE_PREFIX               := $(DIST)/$(PROJECT_NAME)-$(PROJECT_VERSION)
ARTIFACTS_BUNDLE            := $(BUNDLE_PREFIX)-artifacts.tar.gz
DEPLOYMENT_ADDRESSES_BUNDLE := $(BUNDLE_PREFIX)-deployment-addresses.tar.gz
DEVNET_BUNDLE               := $(BUNDLE_PREFIX)-anvil-$(FOUNDRY_VERSION).tar.gz

MAKEFLAGS += --no-print-directory

ANVIL   := anvil
CAST    := cast
FORGE   := forge
GENHTML := genhtml
LCOV    := lcov

DEPLOY_CMD := $(FORGE) script script/Deployment.s.sol:DeploymentScript

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

ARB_MAINNET_RPC_URL   ?= https://arb1.arbitrum.io/rpc
ARB_SEPOLIA_RPC_URL   ?= https://sepolia-rollup.arbitrum.io/rpc
BASE_MAINNET_RPC_URL  ?= https://mainnet.base.org
BASE_SEPOLIA_RPC_URL  ?= https://sepolia.base.org
ETH_MAINNET_RPC_URL   ?= https://eth.drpc.org
ETH_SEPOLIA_RPC_URL   ?= https://sepolia.drpc.org
OPT_MAINNET_RPC_URL   ?= https://mainnet.optimism.io
OPT_SEPOLIA_RPC_URL   ?= https://sepolia.optimism.io

export ARB_MAINNET_RPC_URL
export ARB_SEPOLIA_RPC_URL
export BASE_MAINNET_RPC_URL
export BASE_SEPOLIA_RPC_URL
export ETH_MAINNET_RPC_URL
export ETH_SEPOLIA_RPC_URL
export OPT_MAINNET_RPC_URL
export OPT_SEPOLIA_RPC_URL

ANVIL_CHAIN_ID         := 31337
ARB_MAINNET_CHAIN_ID   := 42161
ARB_SEPOLIA_CHAIN_ID   := 421614
BASE_MAINNET_CHAIN_ID  := 8453
BASE_SEPOLIA_CHAIN_ID  := 84532
ETH_MAINNET_CHAIN_ID   := 1
ETH_SEPOLIA_CHAIN_ID   := 11155111
OPT_MAINNET_CHAIN_ID   := 10
OPT_SEPOLIA_CHAIN_ID   := 11155420

ARB_MAINNET_DEPLOY_OPTS   += --rpc-url arb_mainnet
ARB_MAINNET_DEPLOY_OPTS   += --chain-id $(ARB_MAINNET_CHAIN_ID)

ARB_SEPOLIA_DEPLOY_OPTS   += --rpc-url arb_sepolia
ARB_SEPOLIA_DEPLOY_OPTS   += --chain-id $(ARB_SEPOLIA_CHAIN_ID)

BASE_MAINNET_DEPLOY_OPTS  += --rpc-url base_mainnet
BASE_MAINNET_DEPLOY_OPTS  += --chain-id $(BASE_MAINNET_CHAIN_ID)

BASE_SEPOLIA_DEPLOY_OPTS  += --rpc-url base_sepolia
BASE_SEPOLIA_DEPLOY_OPTS  += --chain-id $(BASE_SEPOLIA_CHAIN_ID)

ETH_MAINNET_DEPLOY_OPTS   += --rpc-url eth_mainnet
ETH_MAINNET_DEPLOY_OPTS   += --chain-id $(ETH_MAINNET_CHAIN_ID)

ETH_SEPOLIA_DEPLOY_OPTS   += --rpc-url eth_sepolia
ETH_SEPOLIA_DEPLOY_OPTS   += --chain-id $(ETH_SEPOLIA_CHAIN_ID)

OPT_MAINNET_DEPLOY_OPTS   += --rpc-url opt_mainnet
OPT_MAINNET_DEPLOY_OPTS   += --chain-id $(OPT_MAINNET_CHAIN_ID)

OPT_SEPOLIA_DEPLOY_OPTS   += --rpc-url opt_sepolia
OPT_SEPOLIA_DEPLOY_OPTS   += --chain-id $(OPT_SEPOLIA_CHAIN_ID)

TESTNET_CHAIN_IDS  += $(ARB_SEPOLIA_CHAIN_ID)
TESTNET_CHAIN_IDS  += $(BASE_SEPOLIA_CHAIN_ID)
TESTNET_CHAIN_IDS  += $(ETH_SEPOLIA_CHAIN_ID)
TESTNET_CHAIN_IDS  += $(OPT_SEPOLIA_CHAIN_ID)

MAINNET_CHAIN_IDS  += $(ARB_MAINNET_CHAIN_ID)
MAINNET_CHAIN_IDS  += $(BASE_MAINNET_CHAIN_ID)
MAINNET_CHAIN_IDS  += $(ETH_MAINNET_CHAIN_ID)
MAINNET_CHAIN_IDS  += $(OPT_MAINNET_CHAIN_ID)

LIVENET_CHAIN_IDS  := $(TESTNET_CHAIN_IDS) $(MAINNET_CHAIN_IDS)

FORGE_BIND_OPTS  += --crate-name "$(PROJECT_NAME)"
FORGE_BIND_OPTS  += --crate-version "$(PROJECT_VERSION)"
FORGE_BIND_OPTS  += --crate-license "Apache-2.0"
FORGE_BIND_OPTS  += --crate-description "Rust bindings for Cartesi Rollups contracts"
FORGE_BIND_OPTS  += --alloy-version "1.0"

build:
	@$(FORGE) build

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

coverage:
	@echo "🚧 Generating coverage data..."
	@$(FORGE) coverage --ir-minimum --report lcov --lcov-version "$(LCOV_VERSION)"
	@echo "🚧 Generating coverage report..."
	@$(GENHTML) -o coverage lcov.info --rc derive_function_end_line=0
	@echo "✅ Successfully generated coverage report."

deploy-all: devnet deploy-livenets

devnet: build
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
	echo "🔨 Deploying to Anvil (Chain ID: $(ANVIL_CHAIN_ID))..."; \
	$(DEPLOY_CMD) $(ANVIL_DEPLOY_OPTS) ; \
	echo "✅ Successfully built Anvil devnet."

deploy-livenets: deploy-testnets deploy-mainnets

deploy-testnets: deploy-eth-sepolia
deploy-testnets: deploy-opt-sepolia
deploy-testnets: deploy-base-sepolia
deploy-testnets: deploy-arb-sepolia

deploy-mainnets: deploy-eth-mainnet
deploy-mainnets: deploy-opt-mainnet
deploy-mainnets: deploy-base-mainnet
deploy-mainnets: deploy-arb-mainnet

deploy-eth-sepolia: build
	@echo "🌐 Running deployment script against Ethereum Sepolia..."
	@$(DEPLOY_CMD) $(ETH_SEPOLIA_DEPLOY_OPTS) $(DEPLOY_OPTS)
	@echo "✅ Deployment script successfully ran against Ethereum Sepolia."

deploy-opt-sepolia: build
	@echo "🌐 Running deployment script against OP Sepolia..."
	@$(DEPLOY_CMD) $(OPT_SEPOLIA_DEPLOY_OPTS) $(DEPLOY_OPTS)
	@echo "✅ Deployment script successfully ran against OP Sepolia."

deploy-base-sepolia: build
	@echo "🌐 Running deployment script against Base Sepolia..."
	@$(DEPLOY_CMD) $(BASE_SEPOLIA_DEPLOY_OPTS) $(DEPLOY_OPTS)
	@echo "✅ Deployment script successfully ran against Base Sepolia."

deploy-arb-sepolia: build
	@echo "🌐 Running deployment script against Arbitrum Sepolia..."
	@$(DEPLOY_CMD) $(ARB_SEPOLIA_DEPLOY_OPTS) $(DEPLOY_OPTS)
	@echo "✅ Deployment script successfully ran against Arbitrum Sepolia."

deploy-eth-mainnet: build
	@echo "🌐 Running deployment script against Ethereum Mainnet..."
	@$(DEPLOY_CMD) $(ETH_MAINNET_DEPLOY_OPTS) $(DEPLOY_OPTS)
	@echo "✅ Deployment script successfully ran against Ethereum Mainnet."

deploy-opt-mainnet: build
	@echo "🌐 Running deployment script against OP Mainnet..."
	@$(DEPLOY_CMD) $(OPT_MAINNET_DEPLOY_OPTS) $(DEPLOY_OPTS)
	@echo "✅ Deployment script successfully ran against OP Mainnet."

deploy-base-mainnet: build
	@echo "🌐 Running deployment script against Base Mainnet..."
	@$(DEPLOY_CMD) $(BASE_MAINNET_DEPLOY_OPTS) $(DEPLOY_OPTS)
	@echo "✅ Deployment script successfully ran against Base Mainnet."

deploy-arb-mainnet: build
	@echo "🌐 Running deployment script against Arbitrum Mainnet..."
	@$(DEPLOY_CMD) $(ARB_MAINNET_DEPLOY_OPTS) $(DEPLOY_OPTS)
	@echo "✅ Deployment script successfully ran against Arbitrum Mainnet."

print-foundry-version:
	@echo "$(FOUNDRY_VERSION)"

publish-soldeer-package:
	@$(FORGE) soldeer push "$(PROJECT_NAME)~$(PROJECT_VERSION)" $(if $(DRY_RUN),--dry-run)

release-artifacts: $(ARTIFACTS_BUNDLE) $(DEPLOYMENT_ADDRESSES_BUNDLE) $(DEVNET_BUNDLE)

$(ARTIFACTS_BUNDLE): build | $(DIST)
	@set -eu; \
	echo "📦 Creating $@..."; \
	OUT_DIR=$$(mktemp -d); \
	trap 'rm -rf -- "$${OUT_DIR}"' EXIT; \
	$(FORGE) build --out "$${OUT_DIR}" src; \
	tar -czf $@ -C "$${OUT_DIR}" .; \
	echo "✅ Created $@."

$(DEPLOYMENT_ADDRESSES_BUNDLE): deploy-livenets | $(DIST)
	@echo "📦 Creating $@..."
	@tar -czf $@ $(foreach id, $(LIVENET_CHAIN_IDS), deployments/$(id))
	@echo "✅ Created $@."

$(DEVNET_BUNDLE): devnet | $(DIST)
	@echo "📦 Creating $@..."
	@tar -czf $@ deployments/$(ANVIL_CHAIN_ID) $(ANVIL_STATE)
	@echo "✅ Created $@."

$(DIST):
	mkdir -p "$@"

rust-bindings:
	@$(FORGE) bind $(FORGE_BIND_OPTS)
