---
"@cartesi/rollups": major
---

Removed parameters from `Application` contracts

- `IInputBox` (not used)

- `IPortals[]` (wasted gas on `SSTORE`, not used)
