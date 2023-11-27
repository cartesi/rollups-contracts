---
"@cartesi/rollups": major
---

Removed the boolean return value from the functions `executeVoucher` and `validateNotice` of the `ICartesiDApp` interface.
This change was made because these functions would never return `false`.
Contracts and EOAs that called these functions now shouldn't expect a boolean return value.
