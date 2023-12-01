---
"@cartesi/rollups": major
---

Removed the `withdrawERC20Tokens` function from `Authority` contract.
This function was removed due to the lack of usage, and because implementing a similar function for `Quorum` would not be possible with `@openzeppelin/contracts@5.0.0`.
Users should not transfer ERC-20 tokens to `Authority` contracts, as it now no longer defines an entry point for withdrawing them, leaving them stuck there forever.
Users should not try to call this function, as it is no longer present in the contract.
