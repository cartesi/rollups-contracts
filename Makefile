# Forge is not safe to run concurrently: parallel invocations race on the
# compilation cache and on the solc downloads performed by svm-rs.
.NOTPARALLEL:

.PHONY: build
.PHONY: build-all
.PHONY: check-foundry-version
.PHONY: clean
.PHONY: codegen
.PHONY: coverage
.PHONY: deploy-livenets
.PHONY: deploy-mainnets
.PHONY: deploy-testnets
.PHONY: devnet
.PHONY: install-deps
.PHONY: install-foundry
.PHONY: print-foundry-version
.PHONY: publish-soldeer-package
.PHONY: release-artifacts
.PHONY: rust-bindings
.PHONY: verify-livenets
.PHONY: verify-mainnets
.PHONY: verify-testnets

# ------------------------------------------------------------------------------
# Auxiliary definitions
# ------------------------------------------------------------------------------

NOOP  =
SPACE = $(NOOP) $(NOOP)

TO_UPPER = $(subst a,A,$(subst b,B,$(subst c,C,$(subst d,D,$(subst e,E,\
           $(subst f,F,$(subst g,G,$(subst h,H,$(subst i,I,$(subst j,J,\
           $(subst k,K,$(subst l,L,$(subst m,M,$(subst n,N,$(subst o,O,\
           $(subst p,P,$(subst q,Q,$(subst r,R,$(subst s,S,$(subst t,T,\
           $(subst u,U,$(subst v,V,$(subst w,W,$(subst x,X,$(subst y,Y,\
           $(subst z,Z,$(1)))))))))))))))))))))))))))

KEBAB_TO_SCREAMING_SNAKE = $(call TO_UPPER,$(subst -,_,$(1)))

# ------------------------------------------------------------------------------
# Project metadata
# ------------------------------------------------------------------------------

PROJECT_NAME := cartesi-rollups-contracts

MAJOR_VERSION  := 3
MINOR_VERSION  := 0
PATCH_VERSION  := 0
PRE_RELEASE    := alpha.8
BUILD_METADATA :=

VERSION := $(MAJOR_VERSION).$(MINOR_VERSION).$(PATCH_VERSION)
VERSION := $(VERSION)$(if $(PRE_RELEASE),-$(PRE_RELEASE))
VERSION := $(VERSION)$(if $(BUILD_METADATA),+$(BUILD_METADATA))

# ------------------------------------------------------------------------------
# Dependency versions
# ------------------------------------------------------------------------------

FOUNDRY_VERSION := 1.5.1

# ------------------------------------------------------------------------------
# Release artifacts (bundles)
# ------------------------------------------------------------------------------

DIST := dist

BUNDLE_PREFIX               := $(DIST)/$(PROJECT_NAME)-$(VERSION)
ARTIFACTS_BUNDLE            := $(BUNDLE_PREFIX)-artifacts.tar.gz
DEPLOYMENT_ADDRESSES_BUNDLE := $(BUNDLE_PREFIX)-deployment-addresses.tar.gz
DEVNET_BUNDLE               := $(BUNDLE_PREFIX)-anvil-$(FOUNDRY_VERSION).tar.gz

RELEASE_ARTIFACTS += $(ARTIFACTS_BUNDLE)
RELEASE_ARTIFACTS += $(DEPLOYMENT_ADDRESSES_BUNDLE)
RELEASE_ARTIFACTS += $(DEVNET_BUNDLE)

# ------------------------------------------------------------------------------
# Dependencies
# ------------------------------------------------------------------------------

ANVIL     := anvil
CAST      := cast
FORGE     := forge
FOUNDRYUP := foundryup
GENHTML   := genhtml
GIT       := git

# ------------------------------------------------------------------------------
# Commands
# ------------------------------------------------------------------------------

CODEGEN_CMD  = $(FORGE) script script/CodeGeneration.s.sol:$(1)
DEPLOY_CMD  := $(FORGE) script script/Deployment.s.sol:DeploymentScript
VERIFY_CMD  := $(FORGE) verify-contract --guess-constructor-args --watch

# ------------------------------------------------------------------------------
# Anvil devnet
# ------------------------------------------------------------------------------

ANVIL_CHAIN_ID := 31337

ANVIL_PK0 := 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80

ANVIL_RPC_URL := http://127.0.0.1:8545
ANVIL_STATE   := state.json

ANVIL_RUNTIME_OPTS += --dump-state $(ANVIL_STATE)
ANVIL_RUNTIME_OPTS += --preserve-historical-states
ANVIL_RUNTIME_OPTS += --quiet

ANVIL_DEPLOY_OPTS += --private-key $(ANVIL_PK0)
ANVIL_DEPLOY_OPTS += --rpc-url $(ANVIL_RPC_URL)
ANVIL_DEPLOY_OPTS += --non-interactive
ANVIL_DEPLOY_OPTS += --broadcast
ANVIL_DEPLOY_OPTS += --slow

# ------------------------------------------------------------------------------
# Supported (live) networks
# ------------------------------------------------------------------------------

CHAIN_ID.arb-mainnet   := 42161
CHAIN_ID.arb-sepolia   := 421614
CHAIN_ID.base-mainnet  := 8453
CHAIN_ID.base-sepolia  := 84532
CHAIN_ID.eth-mainnet   := 1
CHAIN_ID.eth-sepolia   := 11155111
CHAIN_ID.opt-mainnet   := 10
CHAIN_ID.opt-sepolia   := 11155420

LABEL.arb-mainnet      := Arbitrum Mainnet
LABEL.arb-sepolia      := Arbitrum Sepolia
LABEL.base-mainnet     := Base Mainnet
LABEL.base-sepolia     := Base Sepolia
LABEL.eth-mainnet      := Ethereum Mainnet
LABEL.eth-sepolia      := Ethereum Sepolia
LABEL.opt-mainnet      := OP Mainnet
LABEL.opt-sepolia      := OP Sepolia

TESTNETS := arb-sepolia base-sepolia eth-sepolia opt-sepolia
MAINNETS := arb-mainnet base-mainnet eth-mainnet opt-mainnet
LIVENETS := $(TESTNETS) $(MAINNETS)

# The RPC URL alias is the chain name with underscores, as in foundry.toml
# $(1) = chain name, e.g. eth-mainnet
define CHAIN_OPTS_TEMPLATE
CHAIN_OPTS.$(1) := --rpc-url $(subst -,_,$(1)) --chain-id $(CHAIN_ID.$(1))
endef

# Define a CHAIN_OPTS.<chain> variable for each livenet
$(foreach n,$(LIVENETS),$(eval $(call CHAIN_OPTS_TEMPLATE,$(n))))

ifdef ALCHEMY_API_KEY
ALCHEMY_RPC_URL = https://$(1).g.alchemy.com/v2/$(ALCHEMY_API_KEY)
$(foreach n,$(LIVENETS),$(eval RPC_URL.$(n) := $(call ALCHEMY_RPC_URL,$(n))))
else
RPC_URL.arb-mainnet   := https://arb1.arbitrum.io/rpc
RPC_URL.arb-sepolia   := https://sepolia-rollup.arbitrum.io/rpc
RPC_URL.base-mainnet  := https://mainnet.base.org
RPC_URL.base-sepolia  := https://sepolia.base.org
RPC_URL.eth-mainnet   := https://eth.drpc.org
RPC_URL.eth-sepolia   := https://sepolia.drpc.org
RPC_URL.opt-mainnet   := https://mainnet.optimism.io
RPC_URL.opt-sepolia   := https://sepolia.optimism.io
endif

# The RPC URL environment variable name is the chain name converted to
# screaming snake case and suffixed with _RPC_URL as in foundry.toml
# $(1) = chain name, e.g. eth-mainnet
define RPC_URL_ENV_TEMPLATE
$(call KEBAB_TO_SCREAMING_SNAKE,$(1))_RPC_URL ?= $$(RPC_URL.$(1))
export $(call KEBAB_TO_SCREAMING_SNAKE,$(1))_RPC_URL
endef

# Define and export a <CHAIN>_RPC_URL variable for each livenet
$(foreach n,$(LIVENETS),$(eval $(call RPC_URL_ENV_TEMPLATE,$(n))))

TESTNET_CHAIN_IDS  := $(foreach n,$(TESTNETS),$(CHAIN_ID.$(n)))
MAINNET_CHAIN_IDS  := $(foreach n,$(MAINNETS),$(CHAIN_ID.$(n)))
LIVENET_CHAIN_IDS  := $(TESTNET_CHAIN_IDS) $(MAINNET_CHAIN_IDS)

# ------------------------------------------------------------------------------
# Contracts
# ------------------------------------------------------------------------------

DEPLOYED_CORE_CONTRACTS += ApplicationFactory
DEPLOYED_CORE_CONTRACTS += AuthorityFactory
DEPLOYED_CORE_CONTRACTS += Erc1155BatchPortal
DEPLOYED_CORE_CONTRACTS += Erc1155SinglePortal
DEPLOYED_CORE_CONTRACTS += Erc20Portal
DEPLOYED_CORE_CONTRACTS += Erc721Portal
DEPLOYED_CORE_CONTRACTS += EtherPortal
DEPLOYED_CORE_CONTRACTS += InputBox
DEPLOYED_CORE_CONTRACTS += QuorumFactory
DEPLOYED_CORE_CONTRACTS += RefundOutputBuilder
DEPLOYED_CORE_CONTRACTS += SafeErc20Transfer
DEPLOYED_CORE_CONTRACTS += SelfHostedApplicationFactory
DEPLOYED_CORE_CONTRACTS += UsdWithdrawalOutputBuilderFactory

PUBLIC_CONTRACTS += $(DEPLOYED_CORE_CONTRACTS)
PUBLIC_CONTRACTS += IApplication
PUBLIC_CONTRACTS += IApplicationFactory
PUBLIC_CONTRACTS += IAuthority
PUBLIC_CONTRACTS += IAuthorityFactory
PUBLIC_CONTRACTS += IConsensus
PUBLIC_CONTRACTS += IErc1155BatchPortal
PUBLIC_CONTRACTS += IErc1155SinglePortal
PUBLIC_CONTRACTS += IErc20Portal
PUBLIC_CONTRACTS += IErc721Portal
PUBLIC_CONTRACTS += IEtherPortal
PUBLIC_CONTRACTS += IInputBox
PUBLIC_CONTRACTS += IOutputsMerkleRootValidator
PUBLIC_CONTRACTS += IQuorum
PUBLIC_CONTRACTS += IQuorumFactory
PUBLIC_CONTRACTS += IRefundOutputBuilder
PUBLIC_CONTRACTS += ISafeErc20Transfer
PUBLIC_CONTRACTS += ISelfHostedApplicationFactory
PUBLIC_CONTRACTS += IUsdWithdrawalOutputBuilder
PUBLIC_CONTRACTS += IUsdWithdrawalOutputBuilderFactory
PUBLIC_CONTRACTS += IWithdrawalOutputBuilder
PUBLIC_CONTRACTS += Inputs
PUBLIC_CONTRACTS += Outputs
PUBLIC_CONTRACTS += TestFungibleToken
PUBLIC_CONTRACTS += TestMultiToken
PUBLIC_CONTRACTS += TestNonFungibleToken
PUBLIC_CONTRACTS += TestUsdc

# ------------------------------------------------------------------------------
# Solidity dependencies
# ------------------------------------------------------------------------------

DEPENDENCIES       := dependencies
DEPENDENCIES_STAMP := $(DEPENDENCIES)/.installed

# ------------------------------------------------------------------------------
# Rust bindings generation options
# ------------------------------------------------------------------------------

CRATE_DESCRIPTION := Rust bindings for Cartesi Rollups contracts

FORGE_BIND_OPTS  += --skip test
FORGE_BIND_OPTS  += --select "^($(subst $(SPACE),|,$(PUBLIC_CONTRACTS)))$$"
FORGE_BIND_OPTS  += --crate-name "$(PROJECT_NAME)"
FORGE_BIND_OPTS  += --crate-version "$(VERSION)"
FORGE_BIND_OPTS  += --crate-license "Apache-2.0"
FORGE_BIND_OPTS  += --crate-description "$(CRATE_DESCRIPTION)"
FORGE_BIND_OPTS  += --alloy-version 2

# ------------------------------------------------------------------------------
# Generated files
# ------------------------------------------------------------------------------

GENERATED_FILE_DEPLOYERS := script/utils/ContractDeployers.sol
GENERATED_FILE_VERSION   := src/common/Version.sol

GENERATED_FILES += $(GENERATED_FILE_DEPLOYERS)
GENERATED_FILES += $(GENERATED_FILE_VERSION)

# ------------------------------------------------------------------------------
# Tar deterministic archive-creation options
# ------------------------------------------------------------------------------

TAR_DETERMINISTIC_CREATE_OPTS += --sort=name
TAR_DETERMINISTIC_CREATE_OPTS += --mtime=@0
TAR_DETERMINISTIC_CREATE_OPTS += --owner=1000
TAR_DETERMINISTIC_CREATE_OPTS += --group=1000
TAR_DETERMINISTIC_CREATE_OPTS += --numeric-owner
TAR_DETERMINISTIC_CREATE_OPTS += --mode=a=rX,u+w

# ------------------------------------------------------------------------------
# Deployment artifacts
# ------------------------------------------------------------------------------

DEPLOYMENTS := deployments

DEVNET_DEPLOYMENTS_DIR   := $(DEPLOYMENTS)/$(ANVIL_CHAIN_ID)
LIVENET_DEPLOYMENTS_DIRS := $(addprefix $(DEPLOYMENTS)/, $(LIVENET_CHAIN_IDS))

# ------------------------------------------------------------------------------
# Rules
# ------------------------------------------------------------------------------

build: $(DEPENDENCIES_STAMP)
	@$(FORGE) build --skip test

build-all: $(DEPENDENCIES_STAMP)
	@$(FORGE) build

# -X honors personal (local or global) ignore rules
# -d removes directories recursively
# -ff removes git-sourced Soldeer dependencies
clean:
	@$(GIT) clean -Xdff

codegen: $(GENERATED_FILES)

$(GENERATED_FILE_DEPLOYERS): CODEGEN_SCRIPT := DeployersCodeGenerationScript

$(GENERATED_FILE_VERSION):   CODEGEN_SCRIPT := VersionCodeGenerationScript
$(GENERATED_FILE_VERSION):   CODEGEN_ARGS   += "$(MAJOR_VERSION)"
$(GENERATED_FILE_VERSION):   CODEGEN_ARGS   += "$(MINOR_VERSION)"
$(GENERATED_FILE_VERSION):   CODEGEN_ARGS   += "$(PATCH_VERSION)"
$(GENERATED_FILE_VERSION):   CODEGEN_ARGS   += "$(PRE_RELEASE)"
$(GENERATED_FILE_VERSION):   CODEGEN_ARGS   += "$(BUILD_METADATA)"

.PHONY: $(GENERATED_FILES)
$(GENERATED_FILES): $(DEPENDENCIES_STAMP)
	@echo "🚧 Generating $@..."
	@$(call CODEGEN_CMD,$(CODEGEN_SCRIPT)) -- $(CODEGEN_ARGS)
	@$(FORGE) fmt $@
	@echo "✅ Generated $@."

coverage: $(DEPENDENCIES_STAMP)
	@echo "🚧 Generating coverage data..."
	@$(FORGE) coverage --ir-minimum --report lcov --lcov-version 2.0
	@echo "🚧 Generating coverage report..."
	@$(GENHTML) -o coverage lcov.info --rc derive_function_end_line=0
	@echo "✅ Successfully generated coverage report."

devnet: check-foundry-version $(DEPENDENCIES_STAMP)
	@set -eu; \
	echo "🔨 Building Anvil devnet..." ; \
	cleanup() { \
		exit_code=$$?; \
		if kill -0 "$${anvil_pid}" 2>/dev/null; then \
			echo "🚧 Killing Anvil (PID $${anvil_pid})..."; \
			kill "$${anvil_pid}"; \
			echo "🚧 Waiting for Anvil to finish...."; \
			wait "$${anvil_pid}"; \
			errno=$$?; \
			if [ "$${errno}" -eq 0 ]; then \
				echo "✅ Anvil exited with code $${errno}"; \
			else \
				echo "❌ Anvil exited with code $${errno}"; \
				if [ "$${exit_code}" -eq 0 ]; then \
					exit_code=$${errno}; \
				fi; \
			fi; \
		else \
			echo "💡 Anvil (PID $${anvil_pid}) exited early"; \
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
		echo "❌ Anvil did not respond within 5s." >&2; \
		exit 1; \
	fi; \
	echo "🔨 Deploying to Anvil (Chain ID: $(ANVIL_CHAIN_ID))..."; \
	$(DEPLOY_CMD) $(ANVIL_DEPLOY_OPTS) ; \
	echo "✅ Successfully built Anvil devnet."

deploy-livenets: deploy-testnets deploy-mainnets
deploy-testnets: $(addprefix deploy-,$(TESTNETS))
deploy-mainnets: $(addprefix deploy-,$(MAINNETS))

# $(1) = chain name, e.g. eth-mainnet
define DEPLOY_CHAIN_RULE_TEMPLATE
.PHONY: deploy-$(1)
deploy-$(1): $$(DEPENDENCIES_STAMP)
	@echo "🌐 Running deployment script against $(LABEL.$(1))..."
	@$$(DEPLOY_CMD) $$(CHAIN_OPTS.$(1)) $$(DEPLOY_OPTS)
	@echo "✅ Deployment script successfully ran against $(LABEL.$(1))."
endef

# Define a deploy-<chain> rule for each livenet
$(foreach n,$(LIVENETS),$(eval $(call DEPLOY_CHAIN_RULE_TEMPLATE,$(n))))

check-foundry-version:
	@set -eu; \
	for tool in $(FORGE) $(CAST) $(ANVIL); do \
		if ! command -v "$${tool}" >/dev/null 2>&1; then \
			echo "❌ $${tool} not found in PATH." >&2; \
			exit 1; \
		fi; \
		installed=$$($${tool} --version 2>/dev/null | sed -nE \
			's/[^0-9]*([0-9]+\.[0-9]+\.[0-9]+).*/\1/p'); \
		if [ -z "$${installed}" ]; then \
			echo "❌ Could not parse $${tool} version." >&2; \
			exit 1; \
		fi; \
		if [ "$${installed}" != "$(FOUNDRY_VERSION)" ]; then \
			printf '❌ Found %s %s, expected %s.\n' $${tool} \
				"$${installed}" $(FOUNDRY_VERSION) >&2; \
			exit 1; \
		fi; \
	done; \
	echo "✅ Foundry $(FOUNDRY_VERSION) confirmed (forge, cast, anvil)."

install-deps: $(DEPENDENCIES_STAMP)

$(DEPENDENCIES_STAMP): foundry.toml soldeer.lock
	@$(FORGE) soldeer install
	@mkdir -p $(@D)
	@touch $@

install-foundry:
	@$(FOUNDRYUP) -i "$(FOUNDRY_VERSION)"

print-foundry-version:
	@echo "$(FOUNDRY_VERSION)"

publish-soldeer-package:
	@$(FORGE) soldeer push "$(PROJECT_NAME)~$(VERSION)" \
		$(if $(filter-out 0 n no false,$(DRY_RUN)),--dry-run)

release-artifacts: $(RELEASE_ARTIFACTS)

$(ARTIFACTS_BUNDLE): build
$(ARTIFACTS_BUNDLE): TAR_ARGS += -C out
$(ARTIFACTS_BUNDLE): TAR_ARGS += $(addsuffix .sol, $(PUBLIC_CONTRACTS))

$(DEPLOYMENT_ADDRESSES_BUNDLE): deploy-livenets
$(DEPLOYMENT_ADDRESSES_BUNDLE): TAR_ARGS += $(LIVENET_DEPLOYMENTS_DIRS)

$(DEVNET_BUNDLE): devnet
$(DEVNET_BUNDLE): TAR_ARGS += $(DEVNET_DEPLOYMENTS_DIR)
$(DEVNET_BUNDLE): TAR_ARGS += $(ANVIL_STATE)

$(RELEASE_ARTIFACTS): | $(DIST)
	@echo "📦 Creating $@..."
	@tar $(TAR_DETERMINISTIC_CREATE_OPTS) -czf $@ $(TAR_ARGS)
	@echo "✅ Created $@."

$(DIST):
	mkdir -p "$@"

rust-bindings: $(DEPENDENCIES_STAMP)
	@$(FORGE) bind $(FORGE_BIND_OPTS)

verify-livenets: verify-testnets verify-mainnets
verify-testnets: $(addprefix verify-,$(TESTNETS))
verify-mainnets: $(addprefix verify-,$(MAINNETS))

# $(1) = chain name, e.g. eth-mainnet
# $(2) = contract name, e.g. InputBox
define VERIFY_CONTRACT_RULE_TEMPLATE
.PHONY: verify-$(1)-$(2)
verify-$(1)-$(2): $(DEPLOYMENTS)/$(CHAIN_ID.$(1))/$(2).txt
	@echo "🔍 Verifying $(2) on $(LABEL.$(1))..."
	@$$(VERIFY_CMD) $$(CHAIN_OPTS.$(1)) $$(VERIFY_OPTS) -- \
		"$$$$(cat $$<)" "$(2)"
endef

# $(1) = chain name, e.g. eth-mainnet
define VERIFY_CHAIN_RULE_TEMPLATE
.PHONY: verify-$(1)
verify-$(1): $$(addprefix verify-$(1)-,$$(DEPLOYED_CORE_CONTRACTS))
	@echo "✅ Verified deployments on $(LABEL.$(1))."

$$(foreach c,$$(DEPLOYED_CORE_CONTRACTS),\
	$$(eval $$(call VERIFY_CONTRACT_RULE_TEMPLATE,$(1),$$(c))))
endef

# Define verify-<chain> and verify-<chain>-<contract> rules for each livenet
$(foreach n,$(LIVENETS),$(eval $(call VERIFY_CHAIN_RULE_TEMPLATE,$(n))))
