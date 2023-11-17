---
"@cartesi/rollups": major
---

Removed the boolean return value from the `executeVoucher` and `validateNotice` functions of the `CartesiDApp` contract.
This change was made because these functions would never return `false`.
Contracts that call these functions now shouldn't expect a boolean return value.
