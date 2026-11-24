class_name DevAccess
extends RefCounted
## Player release builds hide development tools. The editor and the v2 pilot
## are available in the Godot editor, in a debug export, or when the game is
## launched with the user arg `--dev`. A release export stays hidden.
## force: -1 automatic, 0 off, 1 on (layout tests).

static var force := -1

static func enabled() -> bool:
	if force == 0:
		return false
	if force == 1:
		return true
	if OS.has_feature("editor") or OS.is_debug_build():
		return true
	for arg in OS.get_cmdline_user_args():
		if arg == "--dev":
			return true
	return false
