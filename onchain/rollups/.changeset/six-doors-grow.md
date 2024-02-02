---
"@cartesi/rollups": major
---

Modified the `IInputBox` interface:

-   Modified the `InputAdded` event:

    -   Removed the `sender` parameter.
    -   Changed the semantics of the `input` parameter.

-   Added an `InputTooLarge` error.
