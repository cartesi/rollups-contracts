---
"@cartesi/rollups": major
---

Modified the `ICartesiDApp` interface:

-   Renamed it as `IApplication`.

-   Made it inherit from:

    -   `IERC721Receiver`.
    -   `IERC1155Receiver` (which inherits from `IERC165`).

-   Modified the `executeVoucher` function:

    -   Renamed it as `executeOutput`.
    -   Errors raised by low-level calls are bubbled up.
    -   Changed the type of the `proof` parameter to `OutputValidityProof`.
    -   Removed the boolean return value.

-   Modified the `validateNotice` function:

    -   Renamed it as `validateOutput`.
    -   Changed type of the `proof` parameter to `OutputValidityProof`.
    -   Removed the boolean return value.

-   Modified the `VoucherExecuted` event:

    -   Renamed it as `OutputExecuted`.
    -   Split the `voucherId` parameter into `inputIndex` and `outputIndexWithinInput` parameters.
    -   Added an `output` parameter.

-   Modified the `wasVoucherExecuted` function:

    -   Renamed it as `wasOutputExecuted`.

-   Added a `getInputBox` function.

-   Added a `getPortals` function.

-   Added an `InputIndexOutOfRange` error.

-   Added an `OutputNotExecutable` error.

-   Added an `OutputNotReexecutable` error.

-   Added an `IncorrectEpochHash` error.

-   Added an `IncorrectOutputsEpochRootHash` error.

-   Added an `IncorrectOutputHashesRootHash` error.
