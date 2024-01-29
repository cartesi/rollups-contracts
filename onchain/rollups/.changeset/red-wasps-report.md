---
"@cartesi/rollups": major
---

Modified the `CartesiDApp` contract:

-   Renamed it as `Application`.

-   Added the following parameters to its constructor:

    -   `inputBox`
    -   `inputRelays`

-   Made it support the following interfaces (as in EIP-165):

    -   `IApplication`
    -   `IERC721Receiver`

-   Removed the `withdrawEther` function.

-   Removed the `OnlyApplication` error.

-   Removed the `EtherTransferFailed` error.
