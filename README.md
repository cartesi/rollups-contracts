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
- [foundry] 1.4.3

Then, you may clone the repository...

```sh
git clone https://github.com/cartesi/rollups-contracts.git
```

... and install the Node.js and Solidity packages.

```sh
pnpm install
forge soldeer install
```

Having done that, you can run a local devnet with Cannon.
It will be listening to `127.0.0.1:8545`.

```sh
pnpm start
```

You can interact with the contracts by
pressing `i` on the terminal running Cannon,
or by running `cast` commands on another terminal.
The following command, for example,
calls the `getDeploymentBlockNumber` function
of the `InputBox` contract
deployed to the local devnet.

```sh
cast call $(jq -r .address deployments/InputBox.json) 'getDeploymentBlockNumber()(uint256)'
```

## Documentation

A more in-depth documentation on the contracts can be found [here](./docs/contracts.md).

## Use cases

The Cartesi Rollups Contracts are used by the Cartesi Rollups SDK.
They offer an extensible framework for input relays and output execution.
Here are some examples of use cases:

- Trustless relaying of on-chain information
- Trustless locking of on-chain assets
- Withdrawal of on-chain assets
- Minting of on-chain assets
- Scheduling of on-chain actions
- Liquidity for on-chain assets

## Related projects

The contracts are used by several other projects in the Cartesi ecosystem:

- [Cartesi CLI]
- [Cartesi Rollups Node]
- [Cartesi Rollups Explorer]

## Authors

- Guilherme Dantas ([guidanoli])
- Pedro Argento ([pedroargento])
- Zehui Zheng ([ZzzzHui])

## License

The project is licensed under Apache-2.0.

[Cartesi CLI]: https://github.com/cartesi/cli
[Cartesi Rollups Explorer]: https://github.com/cartesi/rollups-explorer
[Cartesi Rollups Node]: https://github.com/cartesi/rollups-node
[Dave]: https://github.com/cartesi/dave
[ERC-1155]: https://eips.ethereum.org/EIPS/eip-1155
[ERC-20]: https://eips.ethereum.org/EIPS/eip-20
[ERC-721]: https://eips.ethereum.org/EIPS/eip-721
[ETH]: https://ethereum.org/en/eth/
[ZzzzHui]: https://github.com/ZzzzHui
[`CALL`]: https://www.evm.codes/?fork=cancun#f1
[`DELEGATECALL`]: https://www.evm.codes/?fork=cancun#f4
[corepack]: https://nodejs.org/api/corepack.html
[foundry]: https://book.getfoundry.sh/getting-started/installation
[guidanoli]: https://github.com/guidanoli
[pedroargento]: https://github.com/pedroargento
