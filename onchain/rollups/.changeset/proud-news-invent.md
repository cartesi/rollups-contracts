---
"@cartesi/rollups": major
---

Added a `getInputBox` function to the `ICartesiDApp` interface.
Added an `IInputBox` parameter to the functions and events of the `ICartesiDAppFactory` interface, and to the constructor of the `CartesiDApp` contract.
This change was made to allow the node to discover the `IInputBox` contract to listen `InputAdded` events from, just by calling the function from the `ICartesiDApp` interface.
Likewise, users can now know which `IInputBox` contract they should add inputs to, directly or indirectly, in order to communicate with a given DApp.
Users of `ICartesiDAppFactory` should now pass an extra `IInputBox` parameter on deployment.
Off-chain components should now listen to the new `ApplicationCreated` event.
