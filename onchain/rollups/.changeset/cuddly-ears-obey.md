---
"@cartesi/rollups": major
---

Renamed `inputIndex` as `index`, and `input` as `payload`.
This change was made to draw a clear distinction between input and payload, in the context of the `InputBox` contract.
When a user submits a payload, it is encoded along with metadata to form an input blob, which is then forwarded to the Cartesi Machine.
The `InputAdded` event now emits the input blob instead of the payload.
As a result, you can now feed the machine with the input blob as-is, and let it be decoded in user space.
