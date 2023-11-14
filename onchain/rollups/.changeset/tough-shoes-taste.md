---
"@cartesi/rollups": major
---

Changed the ERC-20 portal to revert whenever `transferFrom` returns `false`.
This change was made to prevent DApp back-end developers from accepting failed transfers by not checking the `success` flag of ERC-20 deposit inputs.
We used OpenZeppelin's `SafeERC20` to deliver an even safer and user-friendly experience through the ERC-20 portal.
