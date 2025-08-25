extends CharacterBody2D

enum GuardState { PATROL, ALERT, CHASE }

@export var speed: float = 110.0
@export var arrive_radius: float = 16.0
@export var patrol_targets: Array[NodePath] = []  # Drop markers here in the inspector

@onready var agent: NavigationAgent2D = $Agent
var state: GuardState = GuardState.PATROL
var patrol_points: Array[Vector2] = []
var patrol_i: int = 0
var seen_player: Node = null

func _ready() -> void:
	if agent == null:
		push_error("NavigationAgent2D child named 'Agent' not found.")
		return
	
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
		if State.get_flag("player_wanted"):
			state = GuardState.CHASE
		else:
			state = GuardState.ALERT


func _on_SightArea_body_exited(body: Node) -> void:
	if body == seen_player:
		seen_player = null
		
func talk_to_player() -> void:
	# If chat is already open, don't stack UIs
	if Chat.is_open():
		return

	# Build LLM line for the normal greeting/accuse opener
	var lab_looted: bool = State.get_flag("lab_looted")
	var intent: String = "accuse_after_theft" if lab_looted else "greet_patrol"
	var fallback: String = "Stop right there. The lab's missing supplies." if lab_looted else "Evening. Keep to the lit streets."
	var ctx: Dictionary = {
		"lab_looted": lab_looted,
		"player_wanted": State.get_flag("player_wanted")
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
			# (your existing confess logic)
			State.set_flag("player_wanted", true)
			var line_conf: String = await LLM.generate_line(
				"guard: firm and dutiful", "arrest_after_confession",
				{"lab_looted": true, "player_wanted": true},
				"You'll come with me. Do not resist."
			)
			Dialogue.start("Guard", ["[b]Guard:[/b] " + line_conf])
			state = GuardState.CHASE

		"deny":
			# (your existing deny logic)
			State.set_flag("player_suspect", true)
			var line_deny: String = await LLM.generate_line(
				"guard: skeptical", "warn_after_denial",
				{"lab_looted": true, "player_wanted": false},
				"We'll be watching you. Don't leave town."
			)
			Dialogue.start("Guard", ["[b]Guard:[/b] " + line_deny])

		"chat":
			# Close Dialogue and open ChatUI with persona + live context
			Dialogue.close()
			var guard_persona: String = "village guard: calm, vigilant, terse"
			var ctx_provider := func() -> Dictionary:
				return {
					"lab_looted": State.get_flag("lab_looted"),
					"player_wanted": State.get_flag("player_wanted")
				}
			Chat.open("Guard", guard_persona, ctx_provider)

		"noop":
			# Do nothing for placeholder buttons when lab isn't looted
			pass
