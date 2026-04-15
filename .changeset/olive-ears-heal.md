---
"@cartesi/rollups": minor
---

Add definitions to `IConsensus` interface:
- `ClaimStatus` enumeration: unstaged, staged, and accepted
- `Claim` structure: status, staging block number, and staged outputs Merkle root
- `ClaimStaged` event: a submitted claim has met the consensus staging criteria
- `getClaimStagingPeriod` view function: get claim staging period in base-layer blocks
- `getNumberOfStagedClaims` view function: per-app counter of `ClaimStaged` events
- `getClaim` view function: claim information getter
- `acceptClaim` function: accepts staged claims
- `ClaimNotStaged` error: tried to accept unstaged or already-accepted claim
- `ClaimStagingPeriodNotOverYet` error: tried to accept claim during its staging period
