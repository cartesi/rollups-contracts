---
"@cartesi/rollups": major
---

Refactored the `IConsensus` interface for better interaction with the Cartesi Rollups node.
Added `InputIndexOutOfRange` error to `ICartesiDApp` interface to improve UX of voucher execution.
Updated the `AbstractConsensus` contract to partially implement the new `IConsensus` interface.
Updated the `Authority` contract to implement the new `IConsensus` interface.
Updated the `CartesiDApp` contract to call `getEpochHash` instead of `getClaim`, and to not call `join`.
Replaced the `bytes context` field from the `Proof` structure with an `InputRange inputRange` field.
Removed the `getHistory`, `setHistory` and `migrateHistoryToConsensus` functions and `NewHistory` event from the `Authority` contract.
Contracts that implemented the old `IConsensus` interface and wish to implement the new one must be adapted.
Contracts that implement the new `IConsensus` interface are not backwards compatible with old `CartesiDApp` contracts, since they expect the consensus to expose a `join` function.
Components that would call the `getClaim` function must now call the `getEpochHash` function while passing an input range instead of a "context" blob.
Components that would call the `join` function should not call it anymore, as it is no longer declared in the new interface.
Components that would listen to the `ApplicationJoined` event should not listen to it anymore, as it is no longer declared in the new interface.
