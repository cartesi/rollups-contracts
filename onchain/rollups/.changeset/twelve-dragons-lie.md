---
"@cartesi/rollups": major
---

Changed the type of the `dapp` parameter of the `depositEther` function from `address` to `address payable`.
This change was made because we're now using OpenZeppelin's `Address` library internally to do the Ether transfer.
It also makes sense for this address to be payable since we are transfering Ether to it.
Callers should cast their addresses as `payable` to call this function now.
