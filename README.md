# Smart Contracts for Cartesi Rollups

This repository contains the on-chain part of Cartesi Rollups.

If you are interested in taking a look at the off-chain part, please, head over to [`cartesi/rollups-node`](https://github.com/cartesi/rollups-node).

## 🧩 Dependencies

- [pnpm](https://pnpm.io/installation)
- [Forge](https://book.getfoundry.sh/getting-started/installation)

## 💡 Basic setup

This repository uses [pnpm](https://pnpm.io/installation) to manage JavaScript dependencies.
In order to install them, please, run the following command.

```sh
pnpm install
```

This repository uses [Soldeer](https://soldeer.xyz/) to manage Solidity dependencies.
In order to install them, please, run the following command.

```sh
forge soldeer install
```

## 🚀 Deployment

This repository uses [Cannon](https://usecannon.com/) to manage smart contract deployment.
In order to build the Cannon package, please, run the following command.

```sh
pnpm cannon build
```

## 🧪 Tests

If you want to run the tests, please run the following command.

```sh
forge test -vvv
```

## 📚 Documentation

🚀 Smart contract documentation is kept up-to-date and deployed [**here**](https://cartesi.github.io/rollups-contracts).

ℹ️ You may also want to check the [official Cartesi Rollups documentation website](https://docs.cartesi.io/cartesi-rollups/overview/).

🔎 For an in-depth view of the on-chain architecture, we invite you to take a look at the [`CONTRACTS.md`](https://github.com/cartesi/rollups-contracts/blob/main/CONTRACTS.md) file.

## 🎨 Experimenting

To get a taste of how to use Cartesi to develop your DApp, check the following resources:
See Cartesi Rollups in action with the Simple Echo Examples in [C++](https://github.com/cartesi/rollups-examples/tree/main/echo-cpp), [JavaScript](https://github.com/cartesi/rollups-examples/tree/main/echo-js), [Lua](https://github.com/cartesi/rollups-examples/tree/main/echo-lua), [Rust](https://github.com/cartesi/rollups-examples/tree/main/echo-rust) and [Python](https://github.com/cartesi/rollups-examples/tree/main/echo-python).
To have a glimpse of how to develop your DApp locally using your favorite IDE and tools check our Host Environment in the [Rollups Examples](https://github.com/cartesi/rollups-examples) repository.

## 💬 Talk with us

If you're interested in developing with Cartesi, working with the team, or hanging out in our community, don't forget to [join us on Discord and follow along](https://discord.com/invite/cartesi).

Want to stay up to date? Make sure to join our [announcements channel on Telegram](https://t.me/CartesiAnnouncements) or [follow our X (formerly Twitter)](https://x.com/cartesiproject).

## 🤝 Contributing

Thank you for your interest in Cartesi! Head over to our [Contributing Guidelines](docs/contributing.md) for instructions on how to sign our Contributors Agreement and get started with Cartesi!

Please note we have a [Code of Conduct](docs/code-of-conduct.md), please follow it in all your interactions with the project.

## 📜 License

Note: This component currently has dependencies that are licensed under the GNU GPL, version 3, and so you should treat this component as a whole as being under the GPL version 3. But all Cartesi-written code in this component is licensed under the Apache License, version 2, or a compatible permissive license, and can be used independently under the Apache v2 license. After this component is rewritten, the entire component will be released under the Apache v2 license.
The arbitration d-lib repository and all contributions are licensed under
[GPL 3](https://www.gnu.org/licenses/gpl-3.0.en.html). Please review our [COPYING](COPYING) file.
