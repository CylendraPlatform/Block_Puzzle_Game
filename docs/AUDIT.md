# Phase 0 — Repository & Environment Audit

_Date: 2026-11-23 · Project: Block Puzzle Game (original, Color Block Jam-inspired)_

## 1. Repository state (before this work)

- Working directory `D:\Block_Puzzle_Game` existed but was **empty** — no source, no assets, no docs.
- **No** `AGENTS.md`, `CLAUDE.md`, `.cursor/task.md`, or runbooks present.
- **Not** a git repository.

Action taken this phase (authorized by the project brief, Phase 0 step 6): initialized a git repo on branch `main`, created `docs/`. No tools installed, no external configs modified.

## 2. Toolchain inventory (verified)

| Tool | Status | Version / detail |
|------|--------|------------------|
| git | ok | 2.54.0.windows.1 |
| Java (JDK) | ok | 25.0.3 LTS |
| Node.js | ok | v22.22.3 |
| Python | ok | 3.14.5 |
| Android SDK | ok | `D:\Android\Sdk` (`ANDROID_HOME` + `ANDROID_SDK_ROOT` set) |
| - SDK platforms | ok | android-35, android-36, android-36.1 |
| - build-tools | ok | 35.0.0, 36.0.0, 36.1.0, 37.0.0 |
| - NDK | ok | 27.1.12297006 |
| - platform-tools / adb | ok | adb 1.0.41 (on disk; not on PATH) |
| - emulator + AVD | ok | AVD `Pixel_10_Pro_XL` present |
| - cmdline-tools (sdkmanager) | warn | **Missing** — cannot add new SDK packages via CLI, but required platforms already installed |
| Gradle (system) | warn | Not on PATH — fine, projects use the Gradle wrapper |
| **Godot** | missing | Not installed |
| **Unity** | missing | Not installed (no Hub, no Editor) |

**Conclusion:** A complete **native-Android** build chain (JDK + SDK + NDK + adb + emulator) is ready **now, with zero installs**. **No game engine is installed.**

## 3. Reverse-engineering capability

- **REA skill** (`reverse-engineer-anything`): available.
- **REA MCP server** (`rea`): connected. Android tooling present (adb inspection, APK/DEX analysis, resource decode, UI scenario capture, feature tracing, version compare).

REA is usable **only against a legally obtained artifact**. See Blockers.

## 4. Legal / IP guardrails (enforced from here on)

- No proprietary source, graphics, audio, fonts, or level data from Color Block Jam (Rollic) will be extracted or reused.
- Phase 1 reference spec is built from **publicly observable gameplay** and general genre knowledge, with verified observations separated from assumptions.
- All game code, art, branding, and levels will be **original**.
- No competitor APK will be pulled from third-party mirrors (untrusted-source + IP risk).

## 5. Blockers before implementation

| # | Blocker | Impact | Resolution needed from user |
|---|---------|--------|------------------------------|
| B1 | **Engine not chosen / not installed.** Godot and Unity are both absent. | Can't start engine-based dev. | Pick engine (see `docs/ENGINE_DECISION.md`) and authorize the install, **or** choose native-Kotlin (no install). |
| B2 | **No reference APK / device instance.** | REA deep-dive on the real app not possible without a legal artifact. | Optional: if you own the game, install it on the AVD/device so REA can observe it. Otherwise Phase 1 stays observation-based (sufficient for an original clone). |
| B3 | **cmdline-tools absent.** | New SDK packages can't be installed via `sdkmanager`. | Only matters if a chosen engine needs an SDK level not already present (35/36 cover it). Likely a non-issue. |

**None of B1-B3 block Phase 1.** B1 is the only hard gate before Phase 3 coding.
