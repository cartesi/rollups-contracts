---
"@cartesi/rollups": major
---

Added a `getInputBox` function to the `ICartesiDApp` interface.
Added an `IInputBox` parameter to the functions and events of the `ICartesiDAppFactory` interface, and to the constructor of the `CartesiDApp` contract.
This change was made to allow the node to discover the `IInputBox` contract to listen to `InputAdded` events, just from the `ICartesiDApp` contract.
Likewise, users can now know which `IInputBox` contract it should add inputs to, directly or indirectly, in order to communicate with a given DApp.
Users of `ICartesiDAppFactory` should now pass an extra `IInputBox` parameter on deployment.
Off-chain components should now listen to the new `ApplicationCreated` event.
