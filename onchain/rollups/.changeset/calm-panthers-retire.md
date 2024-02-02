---
"@cartesi/rollups": major
---

Modified the `OutputValidityProof` struct:

-   Collapsed the `vouchersEpochRootHash` and `noticesEpochRootHash` fields into a single `outputsEpochRootHash` field
-   Added an `inputRange` field
