extends SceneTree
## Headless checks for the monetization/analytics stubs.
##   godot --headless --path . --script res://test/test_services.gd
## Autoloads are fetched via the tree (a directly-run --script cannot reference
## autoload global names at compile time).

var _fails := 0

func _ok(c: bool, m: String) -> void:
	if c:
		print("  PASS  ", m)
	else:
		print("  FAIL  ", m)
		_fails += 1

func _initialize() -> void:
	print("== test_services ==")
	await process_frame   # let autoloads run _ready

	var S := root.get_node_or_null("Settings")
	var A := root.get_node_or_null("Analytics")
	var I := root.get_node_or_null("IAP")
	var D := root.get_node_or_null("Ads")
	_ok(S != null and A != null and I != null and D != null, "autoloads present")
	if S == null or A == null or I == null or D == null:
		quit(1)
		return

	S.analytics_opt_out = false
	A.clear_local()
	A.log_event("level_start", {"level": 1})
	_ok(A.recent().size() == 1, "analytics records when opted in")
	S.analytics_opt_out = true
	A.log_event("level_start", {"level": 2})
	_ok(A.recent().size() == 1, "analytics ignores events when opted out")
	S.analytics_opt_out = false

	D.provider = "none"
	_ok(D.is_enabled() == false, "ads disabled by default (provider none)")

	I.purchase("remove_ads")
	await process_frame
	_ok(I.has_entitlement("remove_ads") == true, "stub purchase grants remove_ads")

	D.provider = "fake"
	_ok(D.is_enabled() == false, "remove_ads keeps ads disabled")

	var before: int = I.coins
	I.purchase("coins_small")
	await process_frame
	_ok(I.coins == before + 100, "coin pack adds coins")

	if FileAccess.file_exists(I.SAVE_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(I.SAVE_PATH))

	print("== done: %d failure(s) ==" % _fails)
	quit(_fails)
