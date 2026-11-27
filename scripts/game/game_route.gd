class_name GameRoute
extends RefCounted
## Engine flag and scene routing (M1.3-C). Project setting `gameplay/engine` = legacy | v2,
## default legacy. legacy keeps the original Game.tscn / Rules / BoardView / Catalog route;
## v2 opens the unified GameScreen. Any other value falls back to legacy.

const ENGINE_SETTING := "gameplay/engine"
const LEGACY := "legacy"
const V2 := "v2"
const LEGACY_SCENE := "res://scenes/Game.tscn"
const V2_SCENE := "res://scenes/GameScreen.tscn"
const MENU_SCENE := "res://scenes/MainMenu.tscn"
const LEVELS_SCENE := "res://scenes/LevelSelect.tscn"
const EDITOR_SCENE := "res://scenes/Editor.tscn"

## Test seam, never set in production: when valid, go() calls it with the scene path
## instead of changing scene.
static var navigate_hook := Callable()

static func engine() -> String:
	var value := str(ProjectSettings.get_setting(ENGINE_SETTING, LEGACY))
	return V2 if value == V2 else LEGACY

static func uses_v2() -> bool:
	return engine() == V2

static func game_scene() -> String:
	return V2_SCENE if uses_v2() else LEGACY_SCENE

static func go(tree: SceneTree, path: String) -> void:
	if navigate_hook.is_valid():
		navigate_hook.call(path)
		return
	tree.change_scene_to_file(path)
