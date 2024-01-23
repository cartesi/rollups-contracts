---
"@cartesi/rollups": major
---

Modified the `ICartesiDApp` interface:

-   Renamed it as `IApplication`.

-   Made it inherit from:

    -   `IERC721Receiver`.
    -   `IERC1155Receiver` (which inherits from `IERC165`).

-   Modified the `executeVoucher` function:

    -   Errors raised by low-level calls are bubbled up.
    -   Changed the type of the `proof` parameter to `OutputValidityProof`.
    -   Removed the boolean return value.

-   Modified the `validateNotice` function:

    -   Changed type of the `proof` parameter to `OutputValidityProof`.
    -   Removed the boolean return value.

-   Modified the `VoucherExecuted` event:

    -   Split the `voucherId` parameter into `inputIndex` and `outputIndexWithinInput` parameters.

-   Added a `getInputBox` function.

-   Added a `getInputRelays` function.

-   Added an `InputIndexOutOfRange` error.

-   Added a `VoucherReexecutionNotAllowed` error.

-   Added an `IncorrectEpochHash` error.

-   Added an `IncorrectOutputsEpochRootHash` error.

-   Added an `IncorrectOutputHashesRootHash` error.
