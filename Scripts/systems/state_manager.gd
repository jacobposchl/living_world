extends Node

var flags: Dictionary = {}  # Changed from Dictionary[String, bool] to support mixed types
var events: Array[Dictionary] = []

# NEW: Individual NPC reputation system
var npc_reputations: Dictionary = {}  # "NPC_ID" -> reputation_score
var npc_relationships: Dictionary = {} # "NPC_ID" -> {"other_NPC_ID" -> score}

# NEW: Reputation decay settings
var reputation_decay_rate: float = 0.5  # Points per second
var max_reputation: int = 100
var min_reputation: int = -100

func set_flag(flag_name: String, value) -> void:  # Changed from bool to any type
	flags[flag_name] = value

func get_flag(flag_name: String, default_value = false):
	if flags.has(flag_name):
		return flags[flag_name]
	return default_value

# OLD: Global reputation system (keeping for backward compatibility)
func set_reputation(value: int) -> void:
	flags["player_reputation"] = value

func get_reputation() -> int:
	return flags.get("player_reputation", 0)

func change_reputation(amount: int) -> void:
	var current = get_reputation()
	set_reputation(current + amount)

# NEW: Individual NPC reputation methods
func get_npc_reputation(npc_id: String, default_value: int = 0) -> int:
	"""
	Get the reputation score a specific NPC has for the player.
	Positive = friendly, Negative = hostile, 0 = neutral
	"""
	return npc_reputations.get(npc_id, default_value)

func set_npc_reputation(npc_id: String, value: int) -> void:
	"""
	Set the reputation score a specific NPC has for the player.
	Automatically clamps the value between min_reputation and max_reputation.
	"""
	npc_reputations[npc_id] = clamp(value, min_reputation, max_reputation)

func change_npc_reputation(npc_id: String, amount: int) -> void:
	"""
	Change the reputation score a specific NPC has for the player.
	Positive amount increases reputation, negative decreases it.
	"""
	var current = get_npc_reputation(npc_id)
	set_npc_reputation(npc_id, current + amount)

func decay_reputation(npc_id: String, delta_time: float) -> void:
	"""
	Gradually decay reputation over time towards neutral (0).
	Positive reputation decreases, negative reputation increases.
	"""
	var current = get_npc_reputation(npc_id)
	if current != 0:  # Only decay if not already neutral
		var decay_amount = reputation_decay_rate * delta_time
		if current > 0:
			set_npc_reputation(npc_id, current - decay_amount)
		else:
			set_npc_reputation(npc_id, current + decay_amount)

# NEW: NPC-to-NPC relationship methods
func get_npc_relationship(npc_id: String, other_npc_id: String, default_value: int = 0) -> int:
	"""
	Get how one NPC feels about another NPC.
	Positive = friendly, Negative = hostile, 0 = neutral
	"""
	if npc_relationships.has(npc_id) and npc_relationships[npc_id].has(other_npc_id):
		return npc_relationships[npc_id][other_npc_id]
	return default_value

func set_npc_relationship(npc_id: String, other_npc_id: String, value: int) -> void:
	"""
	Set how one NPC feels about another NPC.
	"""
	if not npc_relationships.has(npc_id):
		npc_relationships[npc_id] = {}
	npc_relationships[npc_id][other_npc_id] = clamp(value, min_reputation, max_reputation)

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
