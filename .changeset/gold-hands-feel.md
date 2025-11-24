---
"@cartesi/rollups": patch
---

Improve deployment Forge script

- Store deployments in directories indexed by chain
- Create abstract deployment script contract for code reuse
- Make script idempotent (skips deployment when address has code)
- Implement loading deployment functionality (to be used in dave repo)
