---
"@cartesi/rollups": major
---

Add `claimStagingPeriod` parameter to functions in the following contracts: `AuthorityFactory`, `SelfHostedApplicationFactory`, and `QuorumFactory`.
This parameters controls how many base-layer blocks need to elapse before a staged claim can be accepted.
