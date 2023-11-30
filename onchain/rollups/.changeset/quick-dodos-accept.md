---
"@cartesi/rollups": major
---

Implemented EIP-165 for CartesiDApp contract.
Also updated `ICartesiDApp` to include `IERC721Receiver`, `IERC1155Receiver` (which inherits from `IERC165`).
We made the `ICartesiDApp` interface inherit from `ERC165` so that it would be possible to detect contracts that do not support such interface.
