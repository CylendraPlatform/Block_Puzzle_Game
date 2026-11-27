# M1.3 — Final activation checklist (launch phase 1: Classic on v2)

**Status (2026-11-27): not activated.** `main` at `89c1a2e` ships `gameplay/engine = "legacy"`.
This checklist does not change the flag. Each box is ticked in the PR that completes it, or by
the owner. Background: `docs/tasks/M1_3_ACTIVATION_READINESS.md`.

## 1. Owner decisions (open)

- [ ] **Pearl visual sign-off (D3)** — **pending.** Review `docs/qa/pearl_signoff/00_contact_sheet.png`
      and tick the checklist in `docs/qa/pearl_signoff/README.md`.
- [ ] **Highest previously distributed versionCode** — **not confirmed.** The repository cannot
      answer this: `docs/release/RELEASES.md` lists only code 1 (debug-signed dev / QA builds), and
      it records only what has been written into it. It does not show Play Console history. The
      owner checks the Play Console (app list; if the app exists, *Releases overview* and *App
      bundle explorer* for every track, including internal testing) and any other channel an APK was
      shared through, then records one of:
      - "No Play Console app and no APK shared outside the developer's devices" — keep the plan:
        activation code 2, rollback code 3;
      - "Highest distributed code is N" — activation takes N+1, rollback N+2; update
        `ANDROID_VERSIONING_AND_ROLLBACK.md` and the ledger before the activation PR.
- [x] Release note D1 — approved (`M1_3_ACTIVATION_RELEASE_NOTE.md`).
- [ ] versionCode 2 / rollback 3 — provisionally approved; final after the item above.

## 2. Release key (owner, once)

- [ ] Create the release keystore per `docs/release/ANDROID_SIGNING.md`. Keep it **outside** the
      repository and back it up. Never commit it. Provide credentials only through the
      `GODOT_ANDROID_KEYSTORE_RELEASE_*` environment variables.
- [ ] Decide on Play App Signing (upload key vs app signing key) when the Play app is created.
- [ ] Record the release certificate SHA-256 (public, not secret) in the ledger row of the first
      release build.

## 3. Release tooling

- [x] Tracked `export_presets.cfg` with no secrets; CI guard (PR #24, merged).
- [ ] Ledger codes strictly increasing across every row, with a regression test
      (`tools/release/test_check_release_metadata.sh`). Release-hardening PR.
- [ ] Release export from a committed-files-only copy of `HEAD` outside the repository
      (`tools/release/stage_release_tree.sh`, `test_stage_release_tree.sh`). Release-hardening PR.
- [x] Player (release) builds hide Editor and QA entries — verified with a real release export
      (readiness report §7 D).

## 4. The activation PR (only after sections 1–3; needs its own owner approval)

Contents, and nothing else:
- [ ] `project.godot`: `gameplay/engine="v2"`.
- [ ] `test/test_game_screen.gd:197`: shipped-default assertion `legacy` → `v2`.
- [ ] `export_presets.cfg`: `version/code` and `version/name` per section 1 (planned 2 / `0.2.0`).
- [ ] `docs/release/RELEASES.md`: new last row (code, name, `v2`, release cert, distributed = not yet).
- [ ] No puzzle rule, save format or gameplay change.

Before merge:
- [ ] Full local regression: every headless script run by `.github/workflows/godot-ci.yml`, plus the
      windowed `test_layout` and shot tests. Record command, environment, exit code
      (`docs/runbooks/testing.md`).
- [ ] CI `headless` and `classic-compat` green **on the final head SHA**. Merge pinned to that SHA.

## 5. Release candidate build and device checks (after merge)

- [ ] `tools/release/build_android_release.sh` on the merged commit (clean tracked tree). It checks the
      ledger, exports a staged copy, verifies `versionCode`, and rejects the debug certificate.
      Keep the generated JSON metadata with the APK.
- [ ] **Device access:** use a phone only with exclusive access (no other adb client attached).
      Never `pm clear`, uninstall or reset app data. Use `adb install -r` only.
- [ ] **Signature:** a release-signed APK cannot be installed over the debug-signed install on the
      Galaxy M31 (`INSTALL_FAILED_UPDATE_INCOMPATIBLE`). If that error appears, STOP and report.
      Do not replace the M31 install. RC checks run on a device or Android user profile with no
      debug install, or through Play internal testing.
- [ ] Smoke test on the RC: menu shows Play / Levels / Settings only; Play resumes; one Classic level
      won; Undo, Restart, Pause, Next; saves written (no error status); no Godot script errors in
      logcat. Report the device, build SHA and results. Do not claim FPS without profiler evidence.

## 6. Rollback readiness (before rollout)

- [ ] Build the rollback candidate from the activation commit with only `gameplay/engine="legacy"`,
      the test assertion, and the next code (planned 3 / `0.2.1`), **same release key**. Keep it
      unpublished. Procedure: `ANDROID_VERSIONING_AND_ROLLBACK.md`.
- [ ] Rehearse `install -r` v2 RC → rollback RC on the RC device. Check that progress and stars
      are unchanged.

## 7. Rollout

- [ ] Play internal testing first, then a staged production rollout with the D1 release note.
- [ ] Watch crashes / ANRs before widening the rollout. If needed, roll back with section 6.

Out of scope: Chapter 1 / M1.3-E (separate approval), issue #22 (editor contents after Test,
non-blocking).
