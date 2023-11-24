---
"@cartesi/rollups": major
---

Moved the definition of the `Proof` structure to its own file.
This change was made to avoid coupling this structure with the `ICartesiDApp` interface.
Contracts that imported this structure from `contracts/dapp/ICartesiDApp.sol` must now import it from `contracts/common/Proof.sol`.
