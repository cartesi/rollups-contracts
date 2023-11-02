---
"@cartesi/rollups": major
---

The ERC-20 portal now reverts whenever `transferFrom` returns `false`, instead of propagating this information to the DApp back-end. This change aims to prevent developers from accepting failed ERC-20 transfers. As a result, ERC-20 deposit inputs no longer contains the boolean `success` field.
