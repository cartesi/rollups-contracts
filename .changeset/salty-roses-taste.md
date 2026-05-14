---
"@cartesi/rollups": major
---

Make deployment addresses chain-independent

- Add `UsdWithdrawalOutputBuilderFactory` contract, which deploys `UsdWithdrawalOutputBuilder` contracts for any ERC-20 token
- Add `UsdWithdrawalOutputBuilderFactory` to Cannonfile and Forge deployment script
- Remove deployment of `UsdWithdrawalOutputBuilder` with chain-dependent USDC token contract address from Forge deployment script
