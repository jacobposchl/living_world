extends CharacterBody2D

enum MState { IDLE, MOVE, TALKING }

@export var speed: float = 50.0
@export var arrive_radius: float = 12.0
@export var wander_radius: float = 160.0
@export var idle_wait_seconds: float = 2.0
@export var player_chase_radius: float = 180.0
@export var stall_home: Vector2 = Vector2.ZERO

# --- NEW: chase tuning ---
@export var chase_probability: float = 0.35          # lower chance to chase
@export var chase_cooldown_seconds: float = 3.0      # must wait this long between chases
@export var approach_buffer: float = 80.0            # how far from the player to stop (no crowding)

# NEW: Individual NPC identification for reputation system
@export var npc_id: String = "Merchant_01"

@onready var agent: NavigationAgent2D = $Agent as NavigationAgent2D
@onready var talk_range: Area2D = $InteractArea as Area2D

var _state: MState = MState.IDLE
var _player: Node2D = null
var _idle_timer: SceneTreeTimer = null
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()

# --- NEW: chase cooldown bookkeeping ---
var _next_chase_time_s: float = 0.0

# -----------------------------
# NEW: INDIVIDUAL REPUTATION METHODS
# -----------------------------
func _initialize_reputation() -> void:
	"""
	Initialize this merchant's reputation if it doesn't exist yet.
	Merchants start with neutral reputation (business-minded, not judgmental).
	"""
	if State.get_npc_reputation(npc_id) == 0:  # Only initialize if not set
		State.set_npc_reputation(npc_id, 0)  # Start neutral
		print("[Merchant] Initialized reputation for ", npc_id, " to 0")

func get_player_reputation() -> int:
	"""
	Get this merchant's individual opinion of the player.
	Positive = good customer, Negative = bad customer, 0 = neutral
	"""
	return State.get_npc_reputation(npc_id, 0)

func update_player_reputation(amount: int) -> void:
	"""
	Update this merchant's opinion of the player.
	Positive amount increases reputation, negative decreases it.
	"""
	State.change_npc_reputation(npc_id, amount)
	print("[Merchant] ", npc_id, " reputation changed by ", amount, " (now: ", get_player_reputation(), ")")

func is_player_good_customer() -> bool:
	"""
	Check if this merchant considers the player a good customer.
	Based on individual reputation, not global flags.
	"""
	var reputation = get_player_reputation()
	return reputation > 15  # Positive reputation = good customer

func is_player_bad_customer() -> bool:
	"""
	Check if this merchant considers the player a bad customer.
	Based on individual reputation, not global flags.
	"""
	var reputation = get_player_reputation()
	return reputation < -15  # Negative reputation = bad customer

func is_player_neutral_customer() -> bool:
	"""
	Check if this merchant is neutral towards the player.
	Based on individual reputation, not global flags.
	"""
	var reputation = get_player_reputation()
	return reputation >= -15 and reputation <= 15  # Neutral range

# -----------------------------
# READY / PROCESS
# -----------------------------
func _ready() -> void:
	_rng.randomize()

	if agent == null:
		push_error("[Merchant] NavigationAgent2D child named 'Agent' not found.")
		set_process(false)
		set_physics_process(false)
		return

	# NEW: Initialize this merchant's reputation if it doesn't exist yet
	_initialize_reputation()

	if stall_home == Vector2.ZERO:
		stall_home = global_position

	# NEW: Wait for navigation to be ready before setting agent properties
	await get_tree().process_frame
	
	if agent and is_instance_valid(agent):
		agent.target_desired_distance = arrive_radius
	else:
		push_error("[Merchant] Agent became invalid after frame processing")
		set_process(false)
		set_physics_process(false)
		return

	if talk_range:
		talk_range.body_entered.connect(func(b: Node) -> void:
			if b.is_in_group("player") and b is Node2D:
				_player = b
		)
		talk_range.body_exited.connect(func(b: Node) -> void:
			if b == _player:
				_player = null
		)
	# Fallback: find a player by group if not already set
	if _player == null:
		var p: Node = get_tree().get_first_node_in_group("player")
		if p is Node2D:
			_player = p as Node2D

	_pick_next_action()

func _physics_process(_dt: float) -> void:
	# Hard-freeze while Chat UI is open OR Dialogue is active
	if (typeof(Chat) != TYPE_NIL and Chat.is_open()) \
	or (typeof(Dialogue) != TYPE_NIL and Dialogue.is_active()):
		if _state != MState.TALKING:
			_pause_for_dialogue()
		return

	# NEW: Decay reputation over time (gradually return to neutral)
	State.decay_reputation(npc_id, _dt)

	match _state:
		MState.TALKING:
			velocity = Vector2.ZERO
			move_and_slide()
		MState.IDLE:
			velocity = Vector2.ZERO
			move_and_slide()
		MState.MOVE:
			_move_along_path()

# -----------------------------
# MOVEMENT / PATH HELPERS
# -----------------------------
func _move_along_path() -> void:
	if agent.is_navigation_finished():
		_arrived()
		return

	var next_pos: Vector2 = agent.get_next_path_position()
	if next_pos == Vector2.ZERO:
		velocity = Vector2.ZERO
		move_and_slide()
		return

	var delta: Vector2 = next_pos - global_position
	if delta.length() <= 0.5:
		velocity = Vector2.ZERO
	else:
		velocity = delta.normalized() * speed
	move_and_slide()

func _arrived() -> void:
	velocity = Vector2.ZERO
	move_and_slide()
	_state = MState.IDLE
	_idle_timer = null
	# Restore normal arrival distance after any special chase approach
	agent.target_desired_distance = arrive_radius
	_idle_timer = get_tree().create_timer(idle_wait_seconds)
	_idle_timer.timeout.connect(_on_idle_timeout, Object.CONNECT_ONE_SHOT)

func _on_idle_timeout() -> void:
	_pick_next_action()

# -----------------------------
# ACTION SELECTION (BT-ish)
# -----------------------------
func _pick_next_action() -> void:
	if _state == MState.TALKING:
		return

	# Decide whether to "approach" the player, but:
	# - only if within radius
	# - only if past cooldown
	# - and with a probability gate
	if _player != null and is_instance_valid(_player):
		var dist_to_player := global_position.distance_to(_player.global_position)
		var now_s := float(Time.get_ticks_msec()) / 1000.0
		if dist_to_player <= player_chase_radius and now_s >= _next_chase_time_s and _rng.randf() < chase_probability:
			# Compute a target that stays approach_buffer away from the player (no crowding)
			var to_me := (global_position - _player.global_position)
			var d := to_me.length()
			if d > approach_buffer:
				var target := _player.global_position + to_me.normalized() * approach_buffer
				# Use a looser desired distance so we don't "needle-thread" to a single point next to the player
				_go_to_point(_project_to_nav(target), maxf(approach_buffer * 0.4, arrive_radius))
			else:
				# Already close enough; just idle this cycle
				_state = MState.IDLE
				_idle_timer = get_tree().create_timer(idle_wait_seconds)
				_idle_timer.timeout.connect(_on_idle_timeout, Object.CONNECT_ONE_SHOT)
			# Set cooldown so we don't keep picking the player again immediately
			_next_chase_time_s = now_s + chase_cooldown_seconds
			return

	# Otherwise: wander around stall or return home
	if _rng.randf() < 0.7:
		_go_to_point(_random_nav_point_around(stall_home, wander_radius))
	else:
		_go_to_point(_project_to_nav(stall_home))

func _go_to_point(target: Vector2, desired_distance: float = -1.0) -> void:
	if desired_distance >= 0.0:
		agent.target_desired_distance = desired_distance
	agent.target_position = target
	await get_tree().process_frame
	_state = MState.MOVE

func _random_nav_point_around(center: Vector2, radius: float) -> Vector2:
	var angle: float = _rng.randf() * TAU
	var r: float = _rng.randf_range(radius * 0.25, radius)
	return _project_to_nav(center + Vector2(cos(angle), sin(angle)) * r)

func _project_to_nav(pos: Vector2) -> Vector2:
	# NEW: Add safety check to prevent NavigationServer errors
	if not agent or not is_instance_valid(agent):
		return pos
		
	var map_rid: RID = agent.get_navigation_map()
	if map_rid.is_valid():
		# Check if navigation map is ready
		var iteration_id = NavigationServer2D.map_get_iteration_id(map_rid)
		if iteration_id > 0:  # Map is ready
			return NavigationServer2D.map_get_closest_point(map_rid, pos)
	
	# Fallback: return original position if navigation isn't ready
	return pos

# -----------------------------
# DIALOGUE + CHAT
# -----------------------------
func talk_to_player() -> void:
	# NEW: Check if chat is already open to prevent UI stacking
	if typeof(Chat) != TYPE_NIL and Chat.is_open():
		print("[Merchant] Chat already open, ignoring talk request")
		return

	_pause_for_dialogue()

	# Show immediate greeting to avoid delays
	var immediate_greeting = "Welcome traveler! Care to browse my wares?"
	Dialogue.start("Merchant", ["[b]Merchant:[/b] " + immediate_greeting])
	Dialogue.choices(
		[
			{"label":"Show me your goods", "id":"browse"},
			{"label":"Ask a question",      "id":"chat"},
			{"label":"Not today",           "id":"leave"}
		],
		self,
		"_on_dialogue_choice_merchant"
	)

	_bind_dialogue_resume_hooks() # resume when Dialogue ends (and Chat, if opened)
	
	# Optionally enhance the greeting with AI in the background (non-blocking)
	_enhance_greeting_async()

func _enhance_greeting_async() -> void:
	# This runs in the background and doesn't block the UI
	var ctx: Dictionary = {
		"lab_looted": State.get_flag("lab_looted"),
		"player_wanted": State.get_flag("player_wanted"),
		"player_reputation": get_player_reputation()
	}

	var enhanced_line: String = await LLM.generate_line(
		"village merchant: cheerful, eager to make a sale",
		"invite_player_to_shop",
		ctx,
		"Welcome traveler! Care to browse my wares?"
	)
	
	# If the dialogue is still open and we got a better response, update it
	if Dialogue.is_active() and enhanced_line != "Welcome traveler! Care to browse my wares?":
		Dialogue.start("Merchant", ["[b]Merchant:[/b] " + enhanced_line])
		Dialogue.choices(
			[
				{"label":"Show me your goods", "id":"browse"},
				{"label":"Ask a question",      "id":"chat"},
				{"label":"Not today",           "id":"leave"}
			],
			self,
			"_on_dialogue_choice_merchant"
		)

func _on_dialogue_choice_merchant(choice_id: String) -> void:
	match choice_id:
		"browse":
			# NEW: Update THIS merchant's individual opinion of the player
			update_player_reputation(10)  # Merchant likes customers who browse
			# Also update global reputation
			State.change_reputation(5)  # Village likes customers who browse
			print("[Merchant] Reputation: +10 individual, +5 global (Total: ", State.get_reputation(), ")")
			var ctx: Dictionary = {
				"lab_looted": State.get_flag("lab_looted"),
				"player_wanted": State.get_flag("player_wanted"),
				"player_reputation": get_player_reputation()
			}
			var sold_out: String = await LLM.generate_line(
				"village merchant: cheerful but absent-minded, just realized he sold out today",
				"apologize_for_no_goods",
				ctx,
				"Oh! I forgot—sold my whole stock earlier today. My apologies!"
			)
			State.add_event({ "type":"asked_for_goods", "by":"player" })
			Dialogue.start("Merchant", ["[b]Merchant:[/b] " + sold_out])
			_bind_dialogue_resume_hooks()

		"chat":
			# NEW: Check if chat is already open before opening new one
			if Chat.is_open():
				print("[Merchant] Chat already open, ignoring chat request")
				return
				
			# NEW: Update THIS merchant's individual opinion of the player
			update_player_reputation(5)  # Merchant likes customers who chat
			# Also update global reputation
			State.change_reputation(2)  # Village likes customers who chat
			print("[Merchant] Reputation: +5 individual, +2 global (Total: ", State.get_reputation(), ")")
			Dialogue.close()
			var persona: String = "village merchant: cheerful, chatty, a little pushy about sales"
			var ctx_provider := func() -> Dictionary:
				return {
					"lab_looted": State.get_flag("lab_looted"),
					"player_wanted": State.get_flag("player_wanted"),
					# NEW: Include individual reputation for personalized chat
					"player_reputation": get_player_reputation()
				}
			Chat.open("Merchant", persona, ctx_provider)
			_bind_chat_resume_hooks()

		"leave":
			# NEW: Update THIS merchant's individual opinion of the player immediately
			update_player_reputation(-15)  # Merchant dislikes customers who leave without buying
			# Also update global reputation
			State.change_reputation(-10)  # Village dislikes customers who waste merchant time
			print("[Merchant] Reputation: -15 individual, -10 global (Total: ", State.get_reputation(), ")")
			
			# Debug: Show current reputation values
			State.debug_reputations()
			
			# Show immediate grumpy response to avoid delays
			var immediate_response = "Hmph! Fine—don't waste my time then."
			Dialogue.start("Merchant", ["[b]Merchant:[/b] " + immediate_response])
			
			# Don't bind resume hooks for leave - just end the interaction
			# The dialogue will close when player clicks through it

# === pause/resume helpers ===
func _pause_for_dialogue() -> void:
	_state = MState.TALKING
	velocity = Vector2.ZERO
	move_and_slide()
	agent.target_position = global_position
	_idle_timer = null

func _bind_dialogue_resume_hooks() -> void:
	if typeof(Dialogue) != TYPE_NIL and Dialogue.ui != null:
		if not Dialogue.ui.dialogue_ended.is_connected(_on_dialogue_ended):
			Dialogue.ui.dialogue_ended.connect(_on_dialogue_ended, Object.CONNECT_ONE_SHOT)

func _bind_chat_resume_hooks() -> void:
	if typeof(Chat) != TYPE_NIL and Chat.ui:
		if not Chat.ui.chat_closed.is_connected(_on_chat_closed):
			Chat.ui.chat_closed.connect(_on_chat_closed, Object.CONNECT_ONE_SHOT)

func _on_dialogue_ended() -> void:
	await get_tree().process_frame
	_state = MState.IDLE
	_pick_next_action()

func _on_chat_closed() -> void:
	# NEW: Re-open dialogue options when chat closes
	print("[Merchant] Chat closed, re-opening dialogue options")
	# Small delay to ensure chat is fully closed
	await get_tree().create_timer(0.1).timeout
	# Re-open dialogue with the player
	talk_to_player()
