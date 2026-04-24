---
"@cartesi/rollups": minor
---

Add new definitions to `IApplicationWithdrawal` interface:

- `getAccountsDriveMerkleRoot` view function: checks whether the accounts drive Merkle root was proved, and its value
- `proveAccountsDriveMerkleRoot` function: proves the accounts drive Merkle root based on the last-finalized machine Merkle root
- `InvalidAccountsDriveMerkleRootProofSize` error: raised when accounts drive Merkle root proof size is invalid
- `AccountsDriveMerkleRootAlreadyProved` error: raised when trying to prove accounts drive Merkle root after it has already been proved
- `AccountsDriveMerkleRootNotProved` error: raised when trying to validate account before accounts drive Merkle root has been proved
- `InvalidAccountsDriveMerkleRoot` error: raised when account validity proof produces accounts drive Merkle root different from proved one
