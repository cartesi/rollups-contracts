---
"@cartesi/rollups": major
---

Updated encoding of inputs added by portals and relays to use `abi.encode` instead of `abi.encodePacked`.
This change was made to simplify the decoding of inputs into its fields through the `abi.decode` function.
DApp developers should update their input decoding code to use `abi.decode` for inputs added by portals and relays.
