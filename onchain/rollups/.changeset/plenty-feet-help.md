---
"@cartesi/rollups": major
---

Removed the boolean `success` flag from ERC-20 deposit inputs.
This change was made because this flag would always be `true`, giving no extra information to the DApp back-end.
Consumers of this input should be aware of the new encoding.
