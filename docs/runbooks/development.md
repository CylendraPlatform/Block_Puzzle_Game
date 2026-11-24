# Development Runbook
1. Read AGENTS.md, docs/tasks/CURRENT_TASK.md and relevant architecture/design docs.
2. Inspect current branch, git status and latest commits.
3. Locate affected implementation and tests before changing code.
4. Create a scoped branch and a bounded implementation plan.
5. Keep rules, rendering, presentation, and service adapters independently testable.
6. Run relevant checks and capture evidence.
7. Update canonical task and related technical docs if behavior changes.
8. Review diff for unrelated changes, secrets, assets, generated output and regression risk.
9. Commit scoped changes; open a PR. Never merge without approval.
