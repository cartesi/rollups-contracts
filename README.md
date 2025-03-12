# Cartesi Rollups Contracts

The Cartesi Rollups Contracts are a set of Solidity smart contracts
that provide Data Availability, Consensus and Settlement to Cartesi Rollups applications.
They are completely permissionless, and can be deployed by anyone to any EVM-compatible chain.
Nevertheless, the Cartesi Foundation, as a form of public good, kindly deploys them
to Ethereum, Arbitrum, Optimism, Base, and their respective testnets.

Data Availability of user transactions and Consensus over their order is provided by the `InputBox` contract,
while Settlement is provided by the `Application` contract in conjunction with a settlement module.
Currently, we have implemented an authority-based module (`Authority`) and a quorum-based module (`Quorum`).
In the near future, we plan to support our very own fraud proof system, [Dave].

The Cartesi Rollups Contracts are an integral part of the Cartesi Rollups SDK,
and are used by the [Cartesi Rollups Node], the [Cartesi Rollups Explorer],
and, of course, by Cartesi Rollups applications.
Through simple Solidity interfaces, one can easily send and list user transactions,
deposit assets, submit claims, execute asset withdrawal orders, and more.

## Features

- Supports deposits and withdrawals of several types of assets:
  - [ETH]: the native token of the chain
  - [ERC-20]: regular, fungible tokens
  - [ERC-721]: non-fungible tokens (NFTs)
  - [ERC-1155]: Multi-tokens, both single and batch transfers
- Supports the validation of outputs and output hashes
- Supports the execution of [`CALL`] and [`DELEGATECALL`] vouchers
- Supports Quorum and Authority-based settlement models
- Includes factory contracts for easy deployment

## Getting started

First, please ensure the following dependencies are installed:

- [corepack]
- [foundry] 1.0.0

Then, you may use [pnpm] and [Soldeer] to install
the Node.js and Solidity packages respectively.

> [!NOTE]
> If you're concerned about the version of these package managers, don't worry;
> Corepack will detect the version of pnpm used by the project,
> install it if necessary, and run it seamlessly.
> As for Soldeer, it is already baked into forge,
> which is part of the foundry toolkit.

```sh
pnpm install
forge soldeer install
```

[Cartesi Rollups Explorer]: https://github.com/cartesi/rollups-explorer
[Cartesi Rollups Node]: https://github.com/cartesi/rollups-node
[Dave]: https://github.com/cartesi/dave
[ERC-1155]: https://eips.ethereum.org/EIPS/eip-1155
[ERC-20]: https://eips.ethereum.org/EIPS/eip-20
[ERC-721]: https://eips.ethereum.org/EIPS/eip-721
[ETH]: https://ethereum.org/en/eth/
[Soldeer]: https://soldeer.xyz/
[`CALL`]: https://www.evm.codes/?fork=cancun#f1
[`DELEGATECALL`]: https://www.evm.codes/?fork=cancun#f4
[corepack]: https://nodejs.org/api/corepack.html
[foundry]: https://book.getfoundry.sh/getting-started/installation
[pnpm]: https://pnpm.io/
