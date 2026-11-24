# ADR-001: Keep Godot and a single task source of truth

**Status:** Accepted as project working convention, 2026-11-24.

## Context
A functional Godot/GDScript puzzle already exists with 100 JSON levels and a growing test suite. Agents need common policies without contradicting one another.

## Decision
Keep the current Godot architecture unless comparative evidence supports a change. Use root `AGENTS.md` for shared engineering policy and `docs/tasks/CURRENT_TASK.md` for the canonical active task; Claude/Cursor files reference these rather than duplicating them.

## Consequences
Reduced handoff ambiguity and lower rewrite risk. New major technical decisions should have their own ADR. This is a process decision, not proof of release readiness.
