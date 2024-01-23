---
"@cartesi/rollups": major
---

Modified the `DAppAddressRelay` contract:

-   Renamed it as `ApplicationAddressRelay`.

-   Made it support the following interfaces (as in EIP-165):

    -   `IERC165`
    -   `IInputRelay`
    -   `IApplicationAddressRelay`
