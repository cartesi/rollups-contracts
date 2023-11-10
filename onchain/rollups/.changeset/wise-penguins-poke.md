---
"@cartesi/rollups": major
---

Removed the `success` field from ERC-20 deposit inputs.
This change was made to avoid confusion, since the ERC-20 portal guarantees this field to be `true`.
Consumers of this input (such as DApp back-ends and front-ends, high-level frameworks and explorers) should update their decoding schema accordingly.
