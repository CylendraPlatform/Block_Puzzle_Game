# Monetization & Analytics (stub architecture)

All monetization and analytics are **disabled by default** and ship with **no real
SDKs, no billing, and no network calls**. The interfaces exist so real providers
can be plugged in later without touching gameplay code. Nothing charges anyone or
sends data until explicitly configured **and approved**.

## Ads — `scripts/services/ads_service.gd` (autoload `Ads`)

Testable interface, no ad SDK.

- `provider` (default `"none"`): `"none"` = all calls no-op; `"fake"` = simulates the
  flow for testing (interstitials close instantly, rewarded grants after a short delay).
  A real `"admob"`/etc. provider is added behind this same API later.
- `show_interstitial(placement)` -> emits `interstitial_closed(placement)`.
- `show_rewarded(placement)` -> emits `rewarded_result(placement, granted)`.
- `is_enabled()` is false when `provider == "none"` **or** the player owns `remove_ads`.

Wired placement: an interstitial *opportunity* fires every 3rd level in `game.gd`
(`_on_next`). With the default provider it is a silent no-op.

**To enable real ads:** integrate an ad SDK as a Godot Android plugin, add a provider
branch in `ads_service.gd`, set `provider`, and complete store/consent requirements.

## In-app purchases — `scripts/services/iap_service.gd` (autoload `IAP`)

Purchase **architecture** with no real billing.

- `provider` (default `"stub"`): the stub grants products locally **without charging**
  so the flow is testable. A real `"play_billing"` provider is added later.
- `CATALOG`: `remove_ads` (non-consumable), `coins_small`, `coins_large` (consumable).
- `purchase(product_id)` -> emits `purchase_result(product_id, success)`.
- `has_entitlement(id)`, `restore()`, `coins`. Entitlements persist to
  `user://entitlements.save`.

`remove_ads` disables ads via `Ads.is_enabled()`. A "Remove Ads" button lives in the
Settings screen (stub purchase).

**Real purchases stay OFF** until `provider` is switched to a real billing integration
and the change is explicitly approved.

## Analytics — `scripts/services/analytics.gd` (autoload `Analytics`)

Privacy-conscious, **local-only by default**.

- Event **definitions** in `EVENTS`: `level_start`, `level_complete`, `level_restart`,
  `undo_used`, `ad_requested`, `ad_shown`, `ad_rewarded`, `iap_purchase`,
  `settings_changed`.
- `log_event(name, params)` keeps a small in-memory ring; optionally appends to a
  **local** `user://analytics.log` (`log_to_file`, default off). **No network, no device
  IDs, no PII.**
- A real backend is added by setting `remote_sink` to a `Callable(event)`. Until then,
  nothing leaves the device.
- **Opt-out:** when `Settings.analytics_opt_out` is true, nothing is recorded at all.
  Exposed as the "Share Analytics" toggle in Settings (on by default; opting out is
  one tap).

### Privacy stance
- No personal data is collected; event params carry only gameplay facts (level number,
  move/undo counts, placement names).
- Default state is local-only with an easy opt-out, matching a privacy-first posture.
- Before shipping any remote analytics, add a consent flow and a privacy policy and
  review platform requirements.
