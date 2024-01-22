---
"@cartesi/rollups": major
---

Changed the ERC-20 portal to revert whenever `transferFrom` returns `false`.
This change was made to prevent DApp back-end developers from blindly accepting failed transfers, if they did not check the `success` flag of ERC-20 deposit inputs.
