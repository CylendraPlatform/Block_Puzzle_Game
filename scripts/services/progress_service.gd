extends Node
## Autoload "Progress" (M1.3-C). Opens ProgressStore once at startup — recovery, the v1 merge
## and the progress.save resync all run here, before the main scene and therefore before either
## gameplay route (legacy Catalog or v2 GameScreen) reads player progress.

var store: ProgressStore = null

func _ready() -> void:
	# Headless test scripts open their own isolated folder; they must never touch user://.
	if "--script" in OS.get_cmdline_args():
		return
	open_store("user://")

## Opens (or reopens) the store in `dir`. Tests pass an isolated folder.
func open_store(dir: String) -> ProgressStore:
	store = ProgressStore.open(dir, CampaignCatalog.levels(CampaignCatalog.CLASSIC).size())
	for warning in store.warnings:
		push_warning("ProgressStore: " + warning)
	return store

## The open store; opens user:// on first use if startup has not done it.
func get_store() -> ProgressStore:
	if store == null:
		open_store("user://")
	return store
