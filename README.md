# Smart Contracts for Cartesi Rollups

This repository contains the on-chain part of Cartesi Rollups.

If you are interested in taking a look at the off-chain part, please, head over to [`cartesi/rollups-node`](https://github.com/cartesi/rollups-node).

## Table of contents

- [Dependencies](#dependencies)
- [Basic setup](#basic-setup)
- [Tests](#tests)
- [Documentation](#documentation)
- [Experimenting](#experimenting)
- [Talk with us](#talk-with-us)
- [Contributing](#contributing)
- [License](#license)

## Dependencies

- [Yarn](https://yarnpkg.com/getting-started/install)
- [Forge](https://book.getfoundry.sh/getting-started/installation)
- [Docker](https://docs.docker.com/get-docker/)

## Basic setup

This repository contains [git submodules](https://git-scm.com/book/en/v2/Git-Tools-Submodules).
In order to properly initialize them, please, run the following command.

```sh
git submodule update --init --recursive
```

This repository uses [Yarn](https://yarnpkg.com/getting-started/install) to manage JavaScript dependencies.
In order to install them, please, run the following commands.

```sh
cd onchain/rollups
yarn install
```

## Tests

If you plan to run the [Forge](https://book.getfoundry.sh/getting-started/installation) tests, there still some setup left to do.
Assuming you are on the `onchain/rollups` directory, and that [Docker Engine](https://docs.docker.com/get-docker/) is running on the background, you may run the following command.
This command will build the Cartesi Machine image necessary to build the proofs.

```sh
yarn proofs:setup
```

Now, you may run the tests!

```sh
yarn test
```

From this point on, after any change in the source code, you can update the proofs before running the tests again with the following command.

```sh
yarn proofs:update
```

## Documentation

ℹ️ Check the [official Cartesi Rollups documentation website](https://docs.cartesi.io/cartesi-rollups/overview/).

Cartesi Rollups is supported by several smart contracts,
each with clear responsibilities and well-defined interfaces.
The modules are depicted in the diagram below.
The yellow boxes correspond to the core contracts,
and the blue boxes correspond to externally-owned accounts (EOAs) and other contracts.

```mermaid
graph TD
    classDef core fill:#ffe95a,color:#000
    classDef external fill:#85b4ff,color:#000
    classDef hasLink text-decoration: underline

    InputBox[Input Box]:::core
    CartesiDApp[Cartesi DApp]:::core
    CartesiDAppFactory[Cartesi DApp Factory]:::core
    EtherPortal[Ether Portal]:::core
    ERC20Portal[ERC-20 Portal]:::core
    ERC721Portal[ERC-721 Portal]:::core
    ERC1155SinglePortal[ERC-1155 Single Transfer Portal]:::core
    ERC1155BatchPortal[ERC-1155 Batch Transfer Portal]:::core
    DAppAddressRelay[DApp Address Relay]:::core
    Consensus:::external

    ERC20[Any ERC-20 token]:::external
    ERC721[Any ERC-721 token]:::external
    ERC1155[Any ERC-1155 token]:::external
    DAppOwner[Cartesi DApp Owner]:::external
    Anyone1[Anyone]:::external
    Anyone2[Anyone]:::external
    Anyone3[Anyone]:::external

    Anyone1 -- executeVoucher --> CartesiDApp
    Anyone1 -. validateNotice .-> CartesiDApp
    Anyone1 -- newApplication --> CartesiDAppFactory
    DAppOwner -- migrateToConsensus ---> CartesiDApp
    CartesiDApp -. getClaim .-> Consensus
    CartesiDApp -- withdrawEther --> CartesiDApp
    CartesiDAppFactory == creates ==> CartesiDApp
    Anyone2 -- addInput -------> InputBox
    Anyone2 -- depositEther ---> EtherPortal
    EtherPortal -- "Ether transfer" ----> Anyone3
    EtherPortal -- addInput -----> InputBox
    Anyone2 -- depositERC20Tokens ---> ERC20Portal
    ERC20Portal -- transferFrom ----> ERC20
    ERC20Portal -- addInput -----> InputBox
    Anyone2 -- depositERC721Token ---> ERC721Portal
    ERC721Portal -- safeTransferFrom ----> ERC721
    ERC721Portal -- addInput -----> InputBox
    Anyone2 -- depositSingleERC1155Token ---> ERC1155SinglePortal
    ERC1155SinglePortal -- safeTransferFrom ----> ERC1155
    ERC1155SinglePortal -- addInput -----> InputBox
    Anyone2 -- depositBatchERC1155Token ---> ERC1155BatchPortal
    ERC1155BatchPortal -- safeBatchTransferFrom ----> ERC1155
    ERC1155BatchPortal -- addInput -----> InputBox
    Anyone2 -- relayDAppAddress ---> DAppAddressRelay
    DAppAddressRelay -- addInput -----> InputBox

    class ERC20,ERC721,ERC1155 hasLink
    click ERC20 href "https://eips.ethereum.org/EIPS/eip-20"
    click ERC721 href "https://eips.ethereum.org/EIPS/eip-721"
    click ERC1155 href "https://eips.ethereum.org/EIPS/eip-1155"
```

### Input Box

This module is the one responsible for receiving inputs from users that want to interact with DApps. For each DApp, the module keeps an append-only list of hashes. Each hash is derived from the input and some metadata, such as the input sender, and the block timestamp. All the data needed to reconstruct a hash is available forever on-chain. As a result, one does not need to trust data providers in order to sync the off-chain machine with the latest input. Note that this module is completely permissionless, and we leave the off-chain machine to judge whether an input is valid or not.

### Cartesi DApp

A Cartesi DApp contract, just like any other contract on Ethereum, has a unique address. With this address, a DApp can hold ownership over digital assets on the base layer like Ether, ERC-20 tokens, and NFTs. In the next sections, we'll explain how DApps are able to receive assets through portals, and perform arbitrary message calls, such as asset transfers, through vouchers.

Since there is no access control to execute a voucher, the caller must also provide a proof that such voucher was generated by the off-chain machine. This proof is checked on-chain against a claim, that is provided by the DApp's consensus. Therefore, a DApp must trust its consensus to only provide valid claims. However, if the consensus goes inactive or rogue, the DApp owner can migrate to a new consensus. In summary, DApp users must trust the DApp owner to choose a trustworthy consensus.

### Cartesi DApp Factory

The Cartesi DApp Factory allows anyone to deploy Cartesi DApp contracts with a simple function call, costing only 3.5% more gas than deploying the DApp contract directly. It also provides greater convenience to the deployer, and security to users and validators, as they know the bytecode could not have been altered maliciously.

### Portals

Portals, as the name suggests, are used to safely teleport assets from the base layer to the execution layer. It works in the following way. First, for some types of assets, the user has to allow the portal to deduct the asset(s) from their account. Second, the user tells the portal to transfer the asset(s) from their account to some DApp's account. The portal then adds an input to the DApp's input box to inform the machine of the transfer that just took place in the base layer. Finally, the off-chain machine is made aware of the transfer through the input sent by the portal. Note that the machine must know the address of the portal beforehand in order to validate such input.

The DApp developer can choose to do whatever they want with this information. For example, they might choose to create a wallet for each user in the execution layer, where assets can be managed at a much lower cost through inputs that are understood by the Linux logic. In this sense, one could think of the DApp contract as a wallet, owned by the off-chain machine. Anyone can deposit assets there but only the DApp—through vouchers—can decide on withdrawals.

The withdrawal process is quite simple from the user's perspective. Typically, the user would first send an input to the DApp requesting the withdrawal, which would then get processed and interpreted off-chain. If all goes well, the machine should generate a voucher that, once executed, transfers the asset(s) to the rightful recipient.

Currently, we support the following types of assets:

- [Ether](https://ethereum.org/en/eth/) (ETH)
- [ERC-20](https://ethereum.org/en/developers/docs/standards/tokens/erc-20/) (Fungible tokens)
- [ERC-721](https://ethereum.org/en/developers/docs/standards/tokens/erc-721/) (Non-fungible tokens)
- [ERC-1155](https://ethereum.org/en/developers/docs/standards/tokens/erc-1155/) (Multi-tokens)

#### Input encodings for deposits

As explained above, in order to teleport an asset from the base layer to the execution layer, you need the corresponding portal to add an input to the DApp's input box, which will then be interpreted and validated by the off-chain machine. To do that, the machine will need to decode the input payload.

The input payloads for deposits are always specified as packed ABI-encoded parameters, as detailed below. In Solidity, packed ABI-encoding is denoted by `abi.encodePacked(...)` and standard ABI-encoded is denoted by `abi.encode(...)`.

| Asset | Packed ABI-encoded payload fields | Standard ABI-encoded payload fields |
| :- | :- | :- |
| Ether | <ul><li>`address sender`,</li><li>`uint256 value`,</li><li>`bytes execLayerData`</li></ul> | none |
| ERC-20 | <ul><li>`bool success`,</li><li>`address token`,</li><li>`address sender`,</li><li>`uint256 amount`,</li><li>`bytes execLayerData`</li></ul> | none |
| ERC-721 | <ul><li>`address token`,</li><li>`address sender`,</li><li>`uint256 tokenId`,</li><li>standard ABI-encoded fields...</li></ul> | <ul><li>`bytes baseLayerData`,</li><li>`bytes execLayerData`</li></ul> |
| ERC-1155 (single) | <ul><li>`address token`,</li><li>`address sender`,</li><li>`uint256 tokenId`,</li><li>`uint256 value`,</li><li>standard ABI-encoded fields...</li></ul> | <ul><li>`bytes baseLayerData`,</li><li>`bytes execLayerData`</li></ul> |
| ERC-1155 (batch) | <ul><li>`address token`,</li><li>`address sender`,</li><li>standard ABI-encoded fields...</li></ul> | <ul><li>`uint256[] tokenIds`,</li><li>`uint256[] values`,</li><li>`bytes baseLayerData`,</li><li>`bytes execLayerData`</li></ul> |

As an example, the deposit of 100 Wei (of Ether) sent by address `0xf39fd6e51aad88f6f4ce6ab8827279cfffb92266` with data `0xabcd` would result in the following input payload:

```
0xf39fd6e51aad88f6f4ce6ab8827279cfffb922660000000000000000000000000000000000000000000000000000000000000064abcd
```

### Vouchers

Vouchers allow DApps in the execution layer to interact with contracts in the base layer through message calls. They are emitted by the off-chain machine, and executed by anyone in the base layer. Each voucher is composed of a destination address and a payload. In the case of vouchers destined to Solidity contracts, the payload generally encodes a function call.

A voucher can only be executed once the DApp's consensus submits a claim containing it. They can be executed in any order. Although the DApp contract is indifferent to the content of the voucher being executed, it enforces some sanity checks before allowing its execution. First, it checks whether the voucher has been successfully executed already. Second, it ensures that the voucher has been emitted by the off-chain machine, by requiring a validity proof.

Because of their generality, vouchers can be used in a wide range of applications: from withdrawing funds to providing liquidity in a DeFi protocol. Typically, DApps use vouchers to withdraw assets. Below, we show how vouchers can be used to withdraw several types of assets. You can find more information about a particular function by clicking on the :page_facing_up: emoji near it.

| Asset | Destination | Function signature |
| :- | :- |  :- |
| Ether | DApp contract | `withdrawEther(address,uint256)` [:page_facing_up:](./onchain/rollups/contracts/dapp/Application.sol) |
| ERC-20 | Token contract | `transfer(address,uint256)` [:page_facing_up:](https://eips.ethereum.org/EIPS/eip-20#methods) |
| ERC-20 | Token contract | `transferFrom(address,address,uint256)` [:page_facing_up:](https://eips.ethereum.org/EIPS/eip-20#methods) [^1] |
| ERC-721 | Token contract | `safeTransferFrom(address,address,uint256)` [:page_facing_up:](https://eips.ethereum.org/EIPS/eip-721#specification) |
| ERC-721 | Token contract | `safeTransferFrom(address,address,uint256,bytes)` [:page_facing_up:](https://eips.ethereum.org/EIPS/eip-721#specification) [^2] |
| ERC-1155 | Token contract | `safeTransferFrom(address,address,uint256,uint256,data)` [:page_facing_up:](https://eips.ethereum.org/EIPS/eip-1155#specification) |
| ERC-1155 | Token contract | `safeBatchTransferFrom(address,address,uint256[],uint256[],data)` [:page_facing_up:](https://eips.ethereum.org/EIPS/eip-1155#specification) [^3] |

Please note that the voucher payload should be encoded according to the [Ethereum ABI specification for calling contract functions](https://docs.soliditylang.org/en/v0.8.19/abi-spec.html). As such, it should start with the first four bytes of the Keccak-256 hash of the function signature string (as given in the table above), followed by the ABI-encoded parameter values.

As an example, the voucher for a simple ERC-20 transfer (2nd line in the table above) to address `0xf39fd6e51aad88f6f4ce6ab8827279cfffb92266` with amount 100 should specify the following payload:

```
0xa9059cbb000000000000000000000000f39fd6e51aad88f6f4ce6ab8827279cfffb922660000000000000000000000000000000000000000000000000000000000000064
```

[^1]: If the DApp owns the tokens, prefer to use `transfer(address,uint256)`
[^2]: If no data is being passed as an argument, prefer to use `safeTransferFrom(address,address,uint256)`
[^3]: If only one token is being transferred, prefer to use `safeTransferFrom(address,address,uint256,uint256,data)`

### DApp Address Relay

In the previous section, we showed how vouchers can be used to withdraw different types of assets. Most of those vouchers contain the address of the DApp contract, either as the destination address or as a function argument. So, the off-chain machine needs to "know" the DApp contract address at some point. If the off-chain machine knew the DApp contract address from the beginning, it would create a cyclical dependency between the initial machine state hash (also called "template hash") and the DApp contract address. This is due to the fact that the address of a DApp contract depends on its construction arguments, which include the template hash; and that the template hash is the Merkle root of the machine address space, which includes the DApp contract address.

This "chicken-and-egg" problem is circumvented by a very small permissionless contract in the base layer, the DApp Address Relay ([source](./onchain/rollups/contracts/relays/ApplicationAddressRelay.sol)). Its only job is to add an input to a DApp's input box with the DApp contract address. The off-chain machine then decodes this input and stores the address somewhere for future use. Just like in the case of portals, the machine must also know the address of the relay in order to validate the origin of the input.

### Notices

Notices are informational statements that can be proved by contracts in the base layer. They're emitted by the off-chain machine and contain a payload, in bytes. DApp developers are free to explore different use cases for notices, their generality and negligible cost of emission makes them a powerful tool to assist integration between DApps and contracts or even other DApps. Similar to vouchers, notices can only be proved once they've been finalized on-chain and if they're accompanied by a validity proof. A chess DApp could, for example, emit a notice informing the underlying blockchain of the winner of a tournament. While that information is not necessarily "actionable", it could be used by other applications for different purposes.

### Consensus

This module is responsible for providing valid claims to DApps after reaching some form of consensus. Each DApp has its own mapping of claims, each of which is mapped by the range of input indices of an epoch.

The module's interface aims to be as generic as possible to accommodate any consensus model, since there are plenty to choose from. The types of consensus currently implemented include:
- Authority: managed by a single address, who has complete power over the consensus. It is trivial to implement, yet quite vulnerable.
- Quorum: managed by a generally small, finite set of validators. Consensus is reached when the majority of the quorum agrees on any given claim.

### Dispute Resolution

Disputes occur when two validators claim different state updates to the same epoch. Because of the deterministic nature of our virtual machine and the fact that the inputs that constitute an epoch are agreed upon beforehand, conflicting claims imply dishonest behavior. When a conflict occurs, the module that mediates the interactions between both validators is the dispute resolution.

The code for rollups dispute resolution is not being published yet, but a big part of it is available on the Cartesi Rollups SDK, using the [Arbitration dlib](https://github.com/cartesi/arbitration-dlib/)

## Experimenting

To get a taste of how to use Cartesi to develop your DApp, check the following resources:
See Cartesi Rollups in action with the Simple Echo Examples in [C++](https://github.com/cartesi/rollups-examples/tree/main/echo-cpp), [JavaScript](https://github.com/cartesi/rollups-examples/tree/main/echo-js), [Lua](https://github.com/cartesi/rollups-examples/tree/main/echo-lua), [Rust](https://github.com/cartesi/rollups-examples/tree/main/echo-rust) and [Python](https://github.com/cartesi/rollups-examples/tree/main/echo-python).
To have a glimpse of how to develop your DApp locally using your favorite IDE and tools check our Host Environment in the [Rollups Examples](https://github.com/cartesi/rollups-examples) repository.

## Talk with us

If you're interested in developing with Cartesi, working with the team, or hanging out in our community, don't forget to [join us on Discord and follow along](https://discordapp.com/invite/Pt2NrnS).

Want to stay up to date? Make sure to join our [announcements channel on Telegram](https://t.me/CartesiAnnouncements) or [follow our Twitter](https://twitter.com/cartesiproject).

## Contributing

Thank you for your interest in Cartesi! Head over to our [Contributing Guidelines](CONTRIBUTING.md) for instructions on how to sign our Contributors Agreement and get started with Cartesi!

Please note we have a [Code of Conduct](CODE_OF_CONDUCT.md), please follow it in all your interactions with the project.

## License

Note: This component currently has dependencies that are licensed under the GNU GPL, version 3, and so you should treat this component as a whole as being under the GPL version 3. But all Cartesi-written code in this component is licensed under the Apache License, version 2, or a compatible permissive license, and can be used independently under the Apache v2 license. After this component is rewritten, the entire component will be released under the Apache v2 license.
The arbitration d-lib repository and all contributions are licensed under
[GPL 3](https://www.gnu.org/licenses/gpl-3.0.en.html). Please review our [COPYING](COPYING) file.
