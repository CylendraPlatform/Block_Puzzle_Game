extends Node
## Autoload "IAP" — in-app purchase ARCHITECTURE with NO real billing.
##
## Purchases never charge anyone: the default "stub" provider just grants the
## product locally so the flow can be exercised and tested. A real store
## (Google Play Billing) is added behind this same API later; real purchases
## stay OFF until `provider` is switched, billing is integrated, and it is
## explicitly approved. Entitlements persist locally.

signal purchase_result(product_id: String, success: bool)
signal products_changed

const SAVE_PATH := "user://entitlements.save"

## Catalog. `type` = "nonconsumable" (entitlement) or "consumable" (coins etc.).
const CATALOG := {
	"remove_ads": {"type": "nonconsumable", "title": "Remove Ads", "price": "$2.99"},
	"coins_small": {"type": "consumable", "title": "100 Coins", "price": "$0.99", "coins": 100},
	"coins_large": {"type": "consumable", "title": "600 Coins", "price": "$3.99", "coins": 600},
}

@export var provider := "stub"         ## "stub" (default, no charge) | (future) "play_billing"

var _entitlements := {}                 ## product_id -> true
var coins := 0

func _ready() -> void:
	_load()

func has_entitlement(product_id: String) -> bool:
	return _entitlements.get(product_id, false)

## Begin a purchase. With the stub provider it "succeeds" without charging.
func purchase(product_id: String) -> void:
	if not CATALOG.has(product_id):
		purchase_result.emit(product_id, false)
		return
	var ok := provider == "stub"   # real billing would be async via the store
	if ok:
		_grant(product_id)
	if Analytics:
		Analytics.log_event("iap_purchase", {"product": product_id, "result": "stub_ok" if ok else "unavailable"})
	purchase_result.emit(product_id, ok)

func restore() -> void:
	# stub: entitlements already local; a real store would re-query here.
	products_changed.emit()

func _grant(product_id: String) -> void:
	var info: Dictionary = CATALOG[product_id]
	if info["type"] == "consumable":
		coins += int(info.get("coins", 0))
	else:
		_entitlements[product_id] = true
	_save()
	products_changed.emit()

func _load() -> void:
	var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if f == null:
		return
	var data: Variant = JSON.parse_string(f.get_as_text())
	if typeof(data) == TYPE_DICTIONARY:
		_entitlements = data.get("entitlements", {})
		coins = int(data.get("coins", 0))

func _save() -> void:
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify({"entitlements": _entitlements, "coins": coins}))
