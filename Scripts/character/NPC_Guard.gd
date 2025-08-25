extends CharacterBody2D

enum GuardState { PATROL, ALERT, CHASE }

@export var speed: float = 110.0
@export var arrive_radius: float = 16.0
@export var patrol_targets: Array[NodePath] = []  # Drop markers here in the inspector

# NEW: Individual NPC identification for reputation system
@export var npc_id: String = "Guard_01"

@onready var agent: NavigationAgent2D = $Agent
var state: GuardState = GuardState.PATROL
var patrol_points: Array[Vector2] = []
var patrol_i: int = 0
var seen_player: Node = null

# -----------------------------
# NEW: INDIVIDUAL REPUTATION METHODS
# -----------------------------
func _initialize_reputation() -> void:
	"""
	Initialize this guard's reputation if it doesn't exist yet.
	Guards start with slightly positive reputation (trusting of citizens).
	"""
	if State.get_npc_reputation(npc_id) == 0:  # Only initialize if not set
		State.set_npc_reputation(npc_id, 10)  # Start slightly trusting
		print("[Guard] Initialized reputation for ", npc_id, " to 10")

func get_player_reputation() -> int:
	"""
	Get this guard's individual opinion of the player.
	Positive = trusting, Negative = suspicious, 0 = neutral
	"""
	return State.get_npc_reputation(npc_id, 0)

func update_player_reputation(amount: int) -> void:
	"""
	Update this guard's opinion of the player.
	Positive amount increases reputation, negative decreases it.
	"""
	State.change_npc_reputation(npc_id, amount)
	print("[Guard] ", npc_id, " reputation changed by ", amount, " (now: ", get_player_reputation(), ")")

func is_player_trusted() -> bool:
	"""
	Check if this guard considers the player trustworthy.
	Based on individual reputation, not global flags.
	"""
	var reputation = get_player_reputation()
	return reputation > 20  # Positive reputation = trusted

func is_player_suspicious() -> bool:
	"""
	Check if this guard considers the player suspicious.
	Based on individual reputation, not global flags.
	"""
	var reputation = get_player_reputation()
	return reputation < -20  # Negative reputation = suspicious

func is_player_neutral() -> bool:
	"""
	Check if this guard is neutral towards the player.
	Based on individual reputation, not global flags.
	"""
	var reputation = get_player_reputation()
	return reputation >= -20 and reputation <= 20  # Neutral range

# -----------------------------
# READY / PROCESS
# -----------------------------
func _ready() -> void:
	if agent == null:
		push_error("NavigationAgent2D child named 'Agent' not found.")
		return
	
	# NEW: Initialize this guard's reputation if it doesn't exist yet
	_initialize_reputation()
	
	# Resolve NodePaths into world positions
	patrol_points.clear()
	for path in patrol_targets:
		var n := get_node_or_null(path)
		if n is Node2D:
			patrol_points.append(n.global_position)
	
	if patrol_points.is_empty():
		print("[Guard] No patrol points set!")
		return
	
	agent.target_desired_distance = arrive_radius
	_set_next_patrol_target()
	print("[Guard] ready; patrol points:", patrol_points)

func _physics_process(_delta: float) -> void:
	if agent == null:
		return

	# NEW: Decay reputation over time (gradually return to neutral)
	State.decay_reputation(npc_id, _delta)

	match state:
		GuardState.PATROL:
			if agent.is_navigation_finished():
				_set_next_patrol_target()
			_step_towards_next_path_pos()

		GuardState.ALERT:
			if seen_player:
				state = GuardState.CHASE

		GuardState.CHASE:
			if seen_player and seen_player.is_inside_tree():
				agent.target_position = seen_player.global_position
				_step_towards_next_path_pos()
			else:
				seen_player = null
				state = GuardState.PATROL
				_set_next_patrol_target()

func _step_towards_next_path_pos() -> void:
	var next_pos: Vector2 = agent.get_next_path_position()
	if next_pos == Vector2.ZERO and agent.is_navigation_finished():
		velocity = Vector2.ZERO
		move_and_slide()
		return
	
	var desired: Vector2 = (next_pos - global_position).normalized() * speed
	velocity = desired
	move_and_slide()

func _set_next_patrol_target() -> void:
	if patrol_points.is_empty():
		return
	var target: Vector2 = patrol_points[patrol_i]
	patrol_i = (patrol_i + 1) % patrol_points.size()
	agent.target_position = target
	print("[Guard] new patrol target:", target)

# Optional sight handlers if you wire an Area2D named SightArea:
func _on_SightArea_body_entered(body: Node) -> void:
	if body.is_in_group("player"):
		seen_player = body
		
		# NEW: Use individual reputation instead of global wanted status for behavior
		var player_reputation = get_player_reputation()
		
		if State.get_flag("player_wanted"):
			# Player is wanted by law - check individual guard's opinion
			if player_reputation < -30:  # Very suspicious of THIS player
				state = GuardState.CHASE
			elif player_reputation < -10:  # Suspicious of THIS player
				state = GuardState.ALERT
			else:  # Neutral or trusting of THIS player
				state = GuardState.PATROL
		else:
			# Player is not wanted by law - check individual guard's opinion
			if player_reputation < -20:  # Suspicious of THIS player
				state = GuardState.ALERT
			else:  # Neutral or trusting of THIS player
				state = GuardState.PATROL


func _on_SightArea_body_exited(body: Node) -> void:
	if body == seen_player:
		seen_player = null
		
func talk_to_player() -> void:
	# NEW: Check if chat is already open to prevent UI stacking
	if Chat.is_open():
		print("[Guard] Chat already open, ignoring talk request")
		return

	# Build LLM line for the normal greeting/accuse opener
	var lab_looted: bool = State.get_flag("lab_looted")
	var intent: String = "accuse_after_theft" if lab_looted else "greet_patrol"
	var fallback: String = "Stop right there. The lab's missing supplies." if lab_looted else "Evening. Keep to the lit streets."
	var ctx: Dictionary = {
		"lab_looted": lab_looted,
		"player_wanted": State.get_flag("player_wanted"),
		# NEW: Include individual reputation for more personalized dialogue
		"player_reputation": get_player_reputation()
	}

	var line: String = await LLM.generate_line(
		"village guard: calm but vigilant, speaks tersely",
		intent,
		ctx,
		fallback
	)

	# Start Dialogue with a new "Ask a question" choice
	Dialogue.start("Guard", ["[b]Guard:[/b] " + line])
	Dialogue.choices(
		[
			{"label": "Confess" if lab_looted else "…", "id": "confess" if lab_looted else "noop"},
			{"label": "Deny"    if lab_looted else "…", "id": "deny"    if lab_looted else "noop"},
			{"label": "Ask a question",                 "id": "chat"}  # <--- opens ChatUI
		],
		self,
		"_on_dialogue_choice_guard"
	)



func _on_dialogue_choice_guard(choice_id: String) -> void:
	print("[Guard] choice:", choice_id)
	match choice_id:
		"confess":
			# NEW: Update THIS guard's individual opinion of the player
			update_player_reputation(-40)  # Guard really dislikes thieves
			State.set_flag("player_wanted", true)
			var line_conf: String = await LLM.generate_line(
				"guard: firm and dutiful", "arrest_after_confession",
				{"lab_looted": true, "player_wanted": true, "player_reputation": get_player_reputation()},
				"You'll come with me. Do not resist."
			)
			Dialogue.start("Guard", ["[b]Guard:[/b] " + line_conf])
			state = GuardState.CHASE

		"deny":
			# NEW: Update THIS guard's individual opinion of the player
			update_player_reputation(-20)  # Guard becomes suspicious of denials
			State.set_flag("player_suspect", true)
			var line_deny: String = await LLM.generate_line(
				"guard: skeptical", "warn_after_denial",
				{"lab_looted": true, "player_wanted": false, "player_reputation": get_player_reputation()},
				"We'll be watching you. Don't leave town."
			)
			Dialogue.start("Guard", ["[b]Guard:[/b] " + line_deny])

		"chat":
			# NEW: Check if chat is already open before opening new one
			if Chat.is_open():
				print("[Guard] Chat already open, ignoring chat request")
				return
				
			# Close Dialogue and open ChatUI with persona + live context
			Dialogue.close()
			var guard_persona: String = "village guard: calm, vigilant, terse"
			var ctx_provider := func() -> Dictionary:
				return {
					"lab_looted": State.get_flag("lab_looted"),
					"player_wanted": State.get_flag("player_wanted"),
					# NEW: Include individual reputation for personalized chat
					"player_reputation": get_player_reputation()
				}
			Chat.open("Guard", guard_persona, ctx_provider)
			# NEW: Connect to chat closed signal to re-open dialogue
			if Chat.ui and Chat.ui.has_signal("chat_closed"):
				Chat.ui.chat_closed.connect(_on_chat_closed)

		"noop":
			# Do nothing for placeholder buttons when lab isn't looted
			pass

# NEW: Handler for when chat closes - re-open dialogue
func _on_chat_closed() -> void:
	print("[Guard] Chat closed, re-opening dialogue options")
	# Small delay to ensure chat is fully closed
	await get_tree().create_timer(0.1).timeout
	# Re-open dialogue with the player
	talk_to_player()
