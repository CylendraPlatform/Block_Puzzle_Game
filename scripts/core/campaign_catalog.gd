class_name CampaignCatalog
extends RefCounted
## Campaigns with stable level ids (M1.3-B; docs/architecture/M1_3_UNIFIED_GAMEPLAY_PLAN.md).
## Read-only: no save access and no routing. Not wired to gameplay yet.
##
## Classic = the 100 legacy levels, in exactly the order Catalog uses for the legacy save
## index, with ids "legacy-<file id>" (the ids V1Adapter and ProgressStore.classic_id use).
## Chapter 1 has no content until M1.3-E.

const CLASSIC := "classic"
const CHAPTER1 := "chapter1"

## {"levels": [{id, campaign, order, path, par, legacy_id}], "diagnostics": PackedStringArray}.
## Any diagnostic means the stable-id mapping cannot be trusted (unreadable file, duplicate id,
## missing par, or a file id that no longer equals its save index + 1).
static func build(campaign: String) -> Dictionary:
	if campaign == CLASSIC:
		return _build_classic()
	if campaign == CHAPTER1:
		return {"levels": [], "diagnostics": PackedStringArray()}
	return {"levels": [], "diagnostics": PackedStringArray(["unknown campaign '%s'" % campaign])}

static func levels(campaign: String) -> Array:
	return build(campaign)["levels"]

## The entry for `id`, or {} when the campaign has no such level.
static func find(campaign: String, id: String) -> Dictionary:
	for entry in levels(campaign):
		if str(entry["id"]) == id:
			return entry
	return {}

static func _build_classic() -> Dictionary:
	var out: Array = []
	var diags := PackedStringArray()
	var seen := {}
	var paths := Catalog.list_paths()
	for order in paths.size():
		var path: String = paths[order]
		var json := JSON.new()
		if json.parse(FileAccess.get_file_as_string(path)) != OK or not json.data is Dictionary or not json.data.has("id"):
			diags.append("%s: unreadable or has no id" % path.get_file())
			continue
		var raw: Dictionary = json.data
		var legacy_id := int(raw["id"])
		var id := "legacy-%d" % legacy_id
		if seen.has(id):
			diags.append("%s: duplicate id %s" % [path.get_file(), id])
		seen[id] = true
		if id != ProgressStore.classic_id(order):
			diags.append("%s: id %s does not match save index %d" % [path.get_file(), id, order])
		var par := int(raw.get("par", 0))
		if par <= 0:
			diags.append("%s: missing par" % path.get_file())
		out.append({"id": id, "campaign": CLASSIC, "order": order, "path": path, "par": par, "legacy_id": legacy_id})
	return {"levels": out, "diagnostics": diags}
