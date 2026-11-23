extends Node
## Autoload "Ads" — testable ad interface with NO real ad SDK.
##
## Providers:
##   - "none" (default): all calls no-op; ads are disabled.
##   - "fake": simulates ad flow for testing (interstitials "show" instantly,
##     rewarded grants the reward after a short delay). No network, no SDK.
## A real provider (AdMob/etc.) is added later behind this same API; nothing
## shows real ads until `provider` is switched and an SDK is integrated.

signal interstitial_closed(placement: String)
signal rewarded_result(placement: String, granted: bool)

@export var provider := "none"         ## "none" | "fake" | (future) "admob"
const REWARD_SIM_DELAY := 0.4

func is_enabled() -> bool:
	# Disabled if the user owns remove-ads, or no provider is set.
	if IAP and IAP.has_entitlement("remove_ads"):
		return false
	return provider != "none"

## Show an interstitial at a named placement (e.g. "level_complete").
func show_interstitial(placement: String) -> void:
	if Analytics: Analytics.log_event("ad_requested", {"placement": placement})
	if not is_enabled():
		interstitial_closed.emit(placement)
		return
	if Analytics: Analytics.log_event("ad_shown", {"placement": placement})
	await get_tree().process_frame
	interstitial_closed.emit(placement)

## Show a rewarded ad. Emits rewarded_result(placement, granted).
func show_rewarded(placement: String) -> void:
	if Analytics: Analytics.log_event("ad_requested", {"placement": placement})
	if not is_enabled():
		rewarded_result.emit(placement, false)
		return
	if Analytics: Analytics.log_event("ad_shown", {"placement": placement})
	await get_tree().create_timer(REWARD_SIM_DELAY).timeout
	if Analytics: Analytics.log_event("ad_rewarded", {"placement": placement})
	rewarded_result.emit(placement, true)
