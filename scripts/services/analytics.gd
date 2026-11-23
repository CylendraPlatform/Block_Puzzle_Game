extends Node
## Autoload "Analytics" — privacy-conscious event sink.
##
## Design: event DEFINITIONS live here; the SINK is pluggable. By default events
## are kept in a small in-memory ring and (optionally) appended to a LOCAL log
## file. No network, no device IDs, no PII. A real backend is added by setting
## `remote_sink` to a Callable — nothing is sent until you do that explicitly.
##
## Privacy: when Settings.analytics_opt_out is true, nothing is recorded at all.

## Canonical event names (keep params free of personal data).
const EVENTS := {
	"level_start": ["level"],
	"level_complete": ["level", "moves", "undos"],
	"level_restart": ["level"],
	"undo_used": ["level"],
	"ad_requested": ["placement"],
	"ad_shown": ["placement"],
	"ad_rewarded": ["placement"],
	"iap_purchase": ["product", "result"],
	"settings_changed": ["key", "value"],
}

const LOG_PATH := "user://analytics.log"
const RING_MAX := 200

var log_to_file := false          ## off by default; local file only, never network
var remote_sink: Callable = Callable()   ## set to a Callable(event:Dictionary) to forward
var _ring: Array = []

func log_event(name: String, params: Dictionary = {}) -> void:
	if Settings and Settings.analytics_opt_out:
		return
	if not EVENTS.has(name):
		push_warning("Analytics: undefined event '%s'" % name)
	var ev := {"t": int(Time.get_unix_time_from_system()), "event": name, "params": params}
	_ring.append(ev)
	if _ring.size() > RING_MAX:
		_ring.pop_front()
	if log_to_file:
		var f := FileAccess.open(LOG_PATH, FileAccess.READ_WRITE)
		if f == null:
			f = FileAccess.open(LOG_PATH, FileAccess.WRITE)
		if f:
			f.seek_end()
			f.store_line(JSON.stringify(ev))
	if remote_sink.is_valid():
		remote_sink.call(ev)

func recent() -> Array:
	return _ring.duplicate()

func clear_local() -> void:
	_ring.clear()
	if FileAccess.file_exists(LOG_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(LOG_PATH))
