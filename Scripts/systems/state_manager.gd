extends Node

var flags: Dictionary = {}  # Changed from Dictionary[String, bool] to support mixed types
var events: Array[Dictionary] = []

func set_flag(name: String, value) -> void:  # Changed from bool to any type
	flags[name] = value

func get_flag(name: String, default_value = false):
	if flags.has(name):
		return flags[name]
	return default_value

# New methods for reputation system
func set_reputation(value: int) -> void:
	flags["player_reputation"] = value

func get_reputation() -> int:
	return flags.get("player_reputation", 0)

func change_reputation(amount: int) -> void:
	var current = get_reputation()
	set_reputation(current + amount)

# New methods for bandit system
func is_player_wanted() -> bool:
	return get_flag("player_wanted", false)

func set_player_wanted(wanted: bool) -> void:
	set_flag("player_wanted", wanted)

func has_allied_with_bandits() -> bool:
	return get_flag("allied_with_bandits", false)

func set_allied_with_bandits(allied: bool) -> void:
	set_flag("allied_with_bandits", allied)

func add_event(e: Dictionary) -> void:
	e["time_ms"] = Time.get_ticks_msec()
	events.append(e)

func get_recent_events(limit: int = 5) -> Array[Dictionary]:
	var start: int = max(0, events.size() - limit) as int
	var arr: Array = events.slice(start, events.size())
	return arr as Array[Dictionary]
