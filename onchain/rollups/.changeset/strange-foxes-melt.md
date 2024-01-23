---
"@cartesi/rollups": major
---

Completely modified the `IConsensus` interface:

-   Removed the `join` function
-   Removed the `getClaim` function
-   Removed the `ApplicationJoined` event
-   Added a `submitClaim` function
-   Added a `getEpochHash` function
-   Added a `ClaimSubmission` event
-   Added a `ClaimAcceptance` event
