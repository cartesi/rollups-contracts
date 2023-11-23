---
"@cartesi/rollups": major
---

Removed `sender` from `InputAdded` event.
We removed this parameter because it will be encoded in the input blob.
Off-chain components should listen to this new event instead.
