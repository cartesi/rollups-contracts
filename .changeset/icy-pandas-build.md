---
"@cartesi/rollups": major
---

Reduce account validity proof size by splitting the validation process into two:
- First, the accounts drive Merkle root is validated through the new `proveAccountsDriveMerkleRoot` function
- Second, the account is validated based on the proved accounts drive Merkle root
