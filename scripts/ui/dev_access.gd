class_name DevAccess
extends RefCounted
## Player builds hide development tools. The editor stays in the project and
## opens from the Godot editor, or from a game launched with the user arg `--dev`.
## force: -1 automatic, 0 off, 1 on (layout tests).

static var force := -1

static func enabled() -> bool:
	if force == 0:
		return false
	if force == 1:
		return true
	if OS.has_feature("editor"):
		return true
	for arg in OS.get_cmdline_user_args():
		if arg == "--dev":
			return true
	return false
