---
"@cartesi/rollups": major
---

Removed the `IHistory` interface.
This interface fell out of use with the new `IConsensus` interface and `AbstractConsensus` contract.
Components that used to interact with this interface should now consider interacting with the `IConsensus` interface instead.
