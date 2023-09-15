---
name: ⬆️  Dependency bump
about: Checklist for bumping dependencies
title: ""
labels: T-bump
assignees: ""
---

## 📚 Context

Which dependencies should be bumped, and to which versions?
Are there any clear benefits? (new features were added, bugs were fixed, etc)
Are there any clear downsides? (requires refactoring, bugs were introduced, etc)

## 📈 Subtasks

- [ ] Update major versions in `packages.json`.
- [ ] If an update requires major work, create the corresponding issue.
- [ ] Update the dependencies in `yarn.lock`.
- [ ] Verify whether everything is working as expected.
