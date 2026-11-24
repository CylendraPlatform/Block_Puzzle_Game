class_name LevelLoader
extends RefCounted
## Version-aware entry. schema_version missing or 1 keeps Level.from_dict.
## Version 2 is validated and never written back over a v1 file.

static func schema_version_of(data: Dictionary) -> int:
	if not data.has("schema_version"):
		return 1
	return int(data["schema_version"])

static func load_definition(data: Dictionary) -> Dictionary:
	var version := schema_version_of(data)
	if version == 1:
		var legacy := Level.from_dict(data)
		var definition := V1Adapter.to_v2(data)
		var diags := LevelValidator.validate_v2(definition)
		return {
			"ok": diags.is_empty() and legacy.is_valid(),
			"source": "v1",
			"legacy": legacy,
			"definition": definition,
			"diagnostics": diags,
		}
	if version == 2:
		var diags := LevelValidator.validate_v2(data)
		return {
			"ok": diags.is_empty(),
			"source": "v2",
			"legacy": null,
			"definition": data,
			"diagnostics": diags,
		}
	return {
		"ok": false,
		"source": "rejected",
		"legacy": null,
		"definition": {},
		"diagnostics": [LevelValidator._diag("UNSUPPORTED_VERSION", "schema_version", "Unsupported schema_version %d." % version)],
	}
