---
"@cartesi/rollups": major
---

Modified the `Authority` contract:

-   Removed the `AuthorityWithdrawalFailed` error
-   Removed the `NewHistory` event
-   Removed the `getClaim` function
-   Removed the `getHistory` function
-   Removed the `join` function
-   Removed the `migrateHistoryToConsensus` function
-   Removed the `setHistory` function
-   Removed the `submitClaim(bytes)` function
-   Removed the `withdrawERC20Tokens` function
-   Implemented the `submitClaim(address,bytes32)` function
