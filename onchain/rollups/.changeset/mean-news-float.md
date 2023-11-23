---
"@cartesi/rollups": major
---

Inputs are now blockchain-agnostic and self-contained blobs. For example, inputs added by EVM contracts like `InputBox` contain EVM-specific metadata like `msg.sender` and `block.timestamp`.
