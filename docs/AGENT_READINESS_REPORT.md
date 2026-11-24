# Agent Readiness Change — Prepared 2026-11-24

Baseline: `71432387bbca5ed73d234bd0bb621a5812b38c70`.
Branch: `chore/agent-ready-repository`.

This documentation-only change adds root AGENTS.md, Claude Code scoped rules and project skills, Cursor rules/task pointer, canonical task ledger, runbooks, ADR, GitHub issue/PR templates, and editor policies. Existing CLAUDE.md and source code are intentionally preserved.

It does **not** add unverified CI or modify Android export settings. Current README still has stale Phase 0–1 status; `export_presets.cfg` is ignored; both are tracked in BP-101.

No Godot runtime tests or IDE startup checks are claimed by this documentation change. Validate agent recognition and project tests on the development machine before merge. Existing published test results are reported in docs/PRODUCTION_UPGRADE_REPORT.md, not re-run here.
