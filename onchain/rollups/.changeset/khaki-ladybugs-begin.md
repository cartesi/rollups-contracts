---
"@cartesi/rollups": major
---

Changed `VoucherExecuted` event to have `inputIndex` and `outputIndexWithinInput` as parameters instead of `voucherPosition`.
This change was made due to an internal change that involved transitioning from the homebrew `Bitmask` library to OpenZeppelin's `BitMaps` library.
It is now easier for the off-chain to reason about `VoucherExecuted` events, since they don't have to decode `voucherPosition` into `inputIndex` and `outputIndexWithinInput` anymore.
Off-chain components that listened to `VoucherExecuted` must now listen to the new event instead.
