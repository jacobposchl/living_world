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

@onready var agent: NavigationAgent2D = $Agent as NavigationAgent2D
@onready var talk_range: Area2D = $InteractArea as Area2D

var _state: MState = MState.IDLE
var _player: Node2D = null
var _idle_timer: SceneTreeTimer = null
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()

# --- NEW: chase cooldown bookkeeping ---
var _next_chase_time_s: float = 0.0

func _ready() -> void:
	_rng.randomize()

	if agent == null:
		push_error("[Merchant] NavigationAgent2D child named 'Agent' not found.")
		set_process(false)
		set_physics_process(false)
		return

	if stall_home == Vector2.ZERO:
		stall_home = global_position

	agent.target_desired_distance = arrive_radius

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
	# Hard-freeze while Chat UI is open
	if typeof(Chat) != TYPE_NIL and Chat.is_open():
		if _state != MState.TALKING:
			_pause_for_dialogue()
		return

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
	var map_rid: RID = agent.get_navigation_map()
	if map_rid.is_valid():
		return NavigationServer2D.map_get_closest_point(map_rid, pos)
	else:
		return pos

# -----------------------------
# DIALOGUE + CHAT
# -----------------------------
func talk_to_player() -> void:
	# Don't stack UIs
	if typeof(Chat) != TYPE_NIL and Chat.is_open():
		return

	_pause_for_dialogue()

	var ctx: Dictionary = {
		"lab_looted": State.get_flag("lab_looted"),
		"player_wanted": State.get_flag("player_wanted")
	}

	var line: String = await LLM.generate_line(
		"village merchant: cheerful, eager to make a sale",
		"invite_player_to_shop",
		ctx,
		"Welcome traveler! Care to browse my wares?"
	)

	Dialogue.start("Merchant", ["[b]Merchant:[/b] " + line])
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

func _on_dialogue_choice_merchant(choice_id: String) -> void:
	match choice_id:
		"browse":
			var ctx: Dictionary = {
				"lab_looted": State.get_flag("lab_looted"),
				"player_wanted": State.get_flag("player_wanted")
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
			Dialogue.close()
			var persona: String = "village merchant: cheerful, chatty, a little pushy about sales"
			var ctx_provider := func() -> Dictionary:
				return {
					"lab_looted": State.get_flag("lab_looted"),
					"player_wanted": State.get_flag("player_wanted")
				}
			Chat.open("Merchant", persona, ctx_provider)
			_bind_chat_resume_hooks()

		"leave":
			var ctx2: Dictionary = {
				"lab_looted": State.get_flag("lab_looted"),
				"player_wanted": State.get_flag("player_wanted")
			}
			var mad_line: String = await LLM.generate_line(
				"village merchant: easily offended, grumpy when rejected",
				"scold_customer_for_leaving_without_purchase",
				ctx2,
				"Hmph! Fine—don't waste my time then."
			)
			Dialogue.start("Merchant", ["[b]Merchant:[/b] " + mad_line])
			_bind_dialogue_resume_hooks()

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
	_on_dialogue_ended()
