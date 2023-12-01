---
"@cartesi/rollups": major
---

Removed `AuthorityWithdrawalFailed` error from the `Authority` contract.
This error was removed because it would only be raised by the `withdrawERC20Tokens` function, which was removed.
