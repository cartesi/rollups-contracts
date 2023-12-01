---
"@cartesi/rollups": major
---

Removed `EtherTransferFailed()` error from `EtherPortal`.
We're now using OpenZeppelin's `Address` library for the Ether portal, which already raises `FailedInnerCall()` in case of failure.
Callers should now expect `FailedInnerCall()` instead of `EtherTransferFailed()` for failed Ether transfers.
