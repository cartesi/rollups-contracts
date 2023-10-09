---
"@cartesi/rollups": major
---

Changed the behavior of the `executeVoucher` function from the `CartesiDApp` contract to propagate any errors raised by the message call.
This should allow users and developers to know the reason as to why a given voucher failed to execute.
Front-ends should propagate the error message to the user to improve the UX.
Smart contracts that call this function should either try to handle the error or propagate it.
