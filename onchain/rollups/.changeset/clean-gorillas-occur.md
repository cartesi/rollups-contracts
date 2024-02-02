---
"@cartesi/rollups": major
---

Modified the `CanonicalMachine` library:

-   Collapsed the `VOUCHER_METADATA_LOG2_SIZE` and `NOTICE_METADATA_LOG2_SIZE` constants into a single `OUTPUT_METADATA_LOG2_SIZE` constant (with the same value).
-   Collapsed the `EPOCH_VOUCHER_LOG2_SIZE` and `EPOCH_NOTICE_LOG2_SIZE` constants into a single `EPOCH_OUTPUT_LOG2_SIZE` constant (with the same value).
-   Updated the value of the `INPUT_MAX_SIZE` constant to reflect a change in the off-chain machine.
