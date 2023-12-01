---
"@cartesi/rollups": major
---

Added a `getInputRelays` function to the `ICartesiDApp` interface.
Added `inputRelays` parameter to the functions and events of the `ICartesiDAppFactory` interface, and to the constructor of the `CartesiDApp` contract.
This change was made to allow the node to discover the input relay contracts that the DApp back-end may expect inputs from, just by calling the `getInputRelays` function from the `ICartesiDApp` interface.
Likewise, users can now know which input relay contracts they should add inputs through, in order to communicate with a given DApp.
Users of `ICartesiDAppFactory` should now pass an extra `inputRelays` array parameter on deployment.
Off-chain components should now listen to the new `ApplicationCreated` event.
