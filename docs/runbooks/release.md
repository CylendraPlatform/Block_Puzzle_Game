# Android Release Runbook

1. Read docs/BUILD.md and verify installed Godot/export templates, Android SDK and JDK.
2. Confirm reproducible export from a fresh checkout. The existing docs reference `export_presets.cfg`, which is ignored by .gitignore; fix this safely in a dedicated task.
3. For beta, make a debug/test APK, verify package ID and install/launch.
4. Confirm UI device matrix, safe areas, touch interaction, startup logs, persistence and actual performance.
5. For Google Play, configure a protected release signing key, release AAB, store listing, compliance forms, privacy disclosures, tested billing/ads SDKs where approved.
6. Never include credentials, release keystores, personal information, or signing passwords in Git.
7. Track release evidence and outstanding risks in docs/tasks/CURRENT_TASK.md.
