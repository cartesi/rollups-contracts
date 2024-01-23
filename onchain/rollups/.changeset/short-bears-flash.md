---
"@cartesi/rollups": major
---

Removed from the `Authority` contract:

-   `AuthorityWithdrawalFailed` error
-   `NewHistory` event
-   `getClaim` function
-   `getHistory` function
-   `join` function
-   `migrateHistoryToConsensus` function
-   `setHistory` function
-   `submitClaim(bytes)` function
-   `withdrawERC20Tokens` function

Note: the `submitClaim(bytes)` function was replaced by a `submitClaim(address,(uint64,uint64),bytes32)` function.
