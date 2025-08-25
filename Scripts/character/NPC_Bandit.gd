extends CharacterBody2D

enum BanditState { PATROL, CHASE, ATTACK, FLEE, DEFEATED }

@export var speed: float = 50.0
@export var arrive_radius: float = 16.0
@export var patrol_targets: Array[NodePath] = []
@export var chase_speed: float = 80.0
@export var sight_range: float = 200.0
@export var attack_range: float = 50.0
@export var health: float = 100.0
@export var max_health: float = 100.0

@onready var agent: NavigationAgent2D = $Agent
@onready var sight_area: Area2D = $SightArea
@onready var attack_area: Area2D = $AttackArea
@onready var result_label: Label = $CombatResultLabel
@onready var sprite: Sprite2D = $Sprite2D

var state: BanditState = BanditState.PATROL
var patrol_points: Array[Vector2] = []
var patrol_i: int = 0
var seen_player: Node = null
var last_known_player_pos: Vector2 = Vector2.ZERO
var flee_target: Vector2 = Vector2.ZERO
var is_defeated: bool = false

var combat_wins: int = 0
var combat_losses: int = 0

# NEW: Individual NPC identification for reputation system
@export var npc_id: String = "Bandit_01"

# -----------------------------
# NEW: INDIVIDUAL REPUTATION METHODS
# -----------------------------
func _initialize_reputation() -> void:
	"""
	Initialize this bandit's reputation if it doesn't exist yet.
	Bandits start with slightly negative reputation (suspicious of strangers).
	"""
	if State.get_npc_reputation(npc_id) == 0:  # Only initialize if not set
		State.set_npc_reputation(npc_id, -10)  # Start slightly suspicious
		print("[Bandit] Initialized reputation for ", npc_id, " to -10")

func get_player_reputation() -> int:
	"""
	Get this bandit's individual opinion of the player.
	Positive = friendly, Negative = hostile, 0 = neutral
	"""
	return State.get_npc_reputation(npc_id, 0)

func update_player_reputation(amount: int) -> void:
	"""
	Update this bandit's opinion of the player.
	Positive amount increases reputation, negative decreases it.
	"""
	State.change_npc_reputation(npc_id, amount)
	print("[Bandit] ", npc_id, " reputation changed by ", amount, " (now: ", get_player_reputation(), ")")

func is_player_friend() -> bool:
	"""
	Check if this bandit considers the player a friend.
	Based on individual reputation, not global reputation.
	"""
	var reputation = get_player_reputation()
	return reputation > 20  # Positive reputation = friend

func is_player_enemy() -> bool:
	"""
	Check if this bandit considers the player an enemy.
	Based on individual reputation, not global reputation.
	"""
	var reputation = get_player_reputation()
	return reputation < -20  # Negative reputation = enemy

func is_player_neutral() -> bool:
	"""
	Check if this bandit is neutral towards the player.
	Based on individual reputation, not global reputation.
	"""
	var reputation = get_player_reputation()
	return reputation >= -20 and reputation <= 20  # Neutral range

# -----------------------------
# READY / PROCESS
# -----------------------------
func _ready() -> void:
	if agent == null:
		push_error("[Bandit] NavigationAgent2D child named 'Agent' not found.")
		set_process(false); set_physics_process(false)
		return
	
	# NEW: Initialize this bandit's reputation if it doesn't exist yet
	_initialize_reputation()
	
	patrol_points.clear()
	for path in patrol_targets:
		var n := get_node_or_null(path)
		if n is Node2D:
			patrol_points.append(n.global_position)
	
	if patrol_points.is_empty():
		_generate_wilderness_patrol()
	
	agent.target_desired_distance = arrive_radius
	_set_next_patrol_target()
	
	if sight_area:
		sight_area.body_entered.connect(_on_sight_area_body_entered)
		sight_area.body_exited.connect(_on_sight_area_body_exited)
	
	if attack_area:
		attack_area.body_entered.connect(_on_attack_area_body_entered)

func _physics_process(_delta: float) -> void:
	if is_defeated:
		return
	if Dialogue.is_active() or (typeof(Chat) != TYPE_NIL and Chat.is_open()):
		velocity = Vector2.ZERO
		move_and_slide()
		return
		
	# NEW: Decay reputation over time (gradually return to neutral)
	State.decay_reputation(npc_id, _delta)
		
	match state:
		BanditState.PATROL:   _handle_patrol()
		BanditState.CHASE:    _handle_chase()
		BanditState.ATTACK:   _handle_attack()
		BanditState.FLEE:     _handle_flee()
		BanditState.DEFEATED: _handle_defeated()

# -----------------------------
# MOVEMENT HELPERS
# -----------------------------
func _handle_patrol() -> void:
	if agent.is_navigation_finished():
		_set_next_patrol_target()
	_step_towards_next_path_pos()

func _handle_chase() -> void:
	if not seen_player or not seen_player.is_inside_tree():
		state = BanditState.PATROL
		_set_next_patrol_target()
		return
	agent.target_position = seen_player.global_position
	last_known_player_pos = seen_player.global_position
	if global_position.distance_to(seen_player.global_position) <= attack_range:
		state = BanditState.ATTACK
		return
	_step_towards_next_path_pos()

func _handle_attack() -> void:
	if not seen_player or not seen_player.is_inside_tree():
		state = BanditState.CHASE
		return
	velocity = Vector2.ZERO
	if global_position.distance_to(seen_player.global_position) > attack_range:
		state = BanditState.CHASE
		return
	if not Dialogue.is_active() and (typeof(Chat) == TYPE_NIL or not Chat.is_open()):
		_threaten_player()

func _handle_flee() -> void:
	if agent.is_navigation_finished():
		state = BanditState.PATROL
		_set_next_patrol_target()
		return
	_step_towards_next_path_pos()

func _handle_defeated() -> void:
	velocity = Vector2.ZERO
	move_and_slide()

func _step_towards_next_path_pos() -> void:
	var next_pos: Vector2 = agent.get_next_path_position()
	if next_pos == Vector2.ZERO and agent.is_navigation_finished():
		velocity = Vector2.ZERO
		move_and_slide()
		return
	velocity = (next_pos - global_position).normalized() * speed
	move_and_slide()

func _set_next_patrol_target() -> void:
	if patrol_points.is_empty():
		_generate_wilderness_patrol()
		return
	var target: Vector2 = patrol_points[patrol_i]
	patrol_i = (patrol_i + 1) % patrol_points.size()
	agent.target_position = target

func _generate_wilderness_patrol() -> void:
	var center = Vector2(800, 400)
	var radius = 200.0
	for i in range(4):
		var angle = (i * PI / 2) + randf() * PI / 4
		var r = randf_range(radius * 0.3, radius)
		var point = center + Vector2(cos(angle), sin(angle)) * r
		patrol_points.append(point)

# -----------------------------
# DETECTION
# -----------------------------
func _on_sight_area_body_entered(body: Node) -> void:
	if body.is_in_group("player") and not is_defeated:
		seen_player = body
		
		# NEW: Use individual reputation instead of global wanted status for behavior
		var player_reputation = get_player_reputation()
		
		if State.is_player_wanted():
			# Player is wanted by law - check individual bandit's opinion
			if player_reputation > 30:  # High reputation with THIS bandit
				_offer_alliance()
			elif player_reputation > -10:  # Neutral to slightly positive with THIS bandit
				if randf() < 0.3:  # 30% chance to offer alliance
					_offer_alliance()
				else:
					state = BanditState.CHASE
			else:  # Low reputation with THIS bandit
				state = BanditState.CHASE
		else:
			# Player is not wanted by law - check individual bandit's opinion
			if player_reputation < -30:  # Very negative with THIS bandit
				state = BanditState.CHASE
			elif player_reputation < -10:  # Slightly negative with THIS bandit
				if randf() < 0.7:  # 70% chance to chase
					state = BanditState.CHASE
				else:
					state = BanditState.PATROL
			else:  # Neutral or positive with THIS bandit
				state = BanditState.PATROL

func _on_sight_area_body_exited(body: Node) -> void:
	if body == seen_player:
		seen_player = null

func _on_attack_area_body_entered(body: Node) -> void:
	if body.is_in_group("player") and not is_defeated:
		state = BanditState.ATTACK

# -----------------------------
# DIALOGUE + CHAT
# -----------------------------
func _threaten_player() -> void:
	var ctx: Dictionary = {
		"player_wanted": State.is_player_wanted(),
		"bandit_health": health,
		# NEW: Use individual reputation instead of global
		"player_reputation": get_player_reputation()
	}
	var threat_line: String = await LLM.generate_line(
		"wilderness bandit: aggressive, threatening, demands tribute",
		"threaten_player",
		ctx,
		"Hand over your gold, or face the consequences!"
	)
	Dialogue.start("Bandit", ["[b]Bandit:[/b] " + threat_line])
	Dialogue.choices(
		[
			{"label": "Fight back", "id": "fight"},
			{"label": "Pay tribute", "id": "pay"},
			{"label": "Try to escape", "id": "escape"},
			{"label": "View combat record", "id": "stats"},
			{"label": "Ask a question", "id": "chat"}   # <-- NEW CHAT BUTTON
		],
		self,
		"_on_dialogue_choice_bandit"
	)

func _offer_alliance() -> void:
	var ctx: Dictionary = {
		"player_wanted": State.is_player_wanted(),
		# NEW: Use individual reputation instead of global
		"player_reputation": get_player_reputation()
	}
	var alliance_line: String = await LLM.generate_line(
		"wilderness bandit: opportunistic, sees potential ally",
		"offer_alliance",
		ctx,
		"Ah, a fellow outlaw! Perhaps we could work together..."
	)
	Dialogue.start("Bandit", ["[b]Bandit:[/b] " + alliance_line])
	Dialogue.choices(
		[
			{"label": "Accept alliance", "id": "accept"},
			{"label": "Decline", "id": "decline"},
			{"label": "Ask a question", "id": "chat"}   # <-- CHAT OPTION HERE TOO
		],
		self,
		"_on_dialogue_choice_bandit"
	)

func _on_dialogue_choice_bandit(choice_id: String) -> void:
	match choice_id:
		"fight":   _start_combat()
		"pay":     _demand_tribute()
		"escape":  _allow_escape()
		"accept":  _form_alliance()
		"decline": _become_hostile()
		"stats":   _show_combat_stats()
		"chat":
			# NEW: Check if chat is already open before opening new one
			if Chat.is_open():
				print("[Bandit] Chat already open, ignoring chat request")
				return
				
			# Close dialogue and open Chat UI
			Dialogue.close()
			var persona: String = "wilderness bandit: gruff, opportunistic, aggressive, but will talk if pressed"
			var ctx_provider := func() -> Dictionary:
				return {
					"player_wanted": State.is_player_wanted(),
					"bandit_health": health,
					"combat_wins": combat_wins,
					"combat_losses": combat_losses,
					# NEW: Include individual reputation for chat UI
					"player_reputation": get_player_reputation()
				}
			Chat.open("Bandit", persona, ctx_provider)
			# NEW: Connect to chat closed signal to re-open dialogue
			if Chat.ui and Chat.ui.has_signal("chat_closed"):
				Chat.ui.chat_closed.connect(_on_chat_closed)
			if typeof(Chat) != TYPE_NIL and Chat.ui:
				if not Chat.ui.chat_closed.is_connected(_on_chat_closed):
					Chat.ui.chat_closed.connect(_on_chat_closed, Object.CONNECT_ONE_SHOT)

func _on_chat_closed() -> void:
	# NEW: Re-open dialogue options when chat closes
	print("[Bandit] Chat closed, re-opening dialogue options")
	# Small delay to ensure chat is fully closed
	await get_tree().create_timer(0.1).timeout
	# Re-open dialogue with the player
	talk_to_player()

# -----------------------------
# (Combat + damage methods unchanged from your version)
# -----------------------------

func _start_combat() -> void:
	state = BanditState.ATTACK
	
	# Randomly determine combat outcome
	var player_won = randf() < 0.5  # 50% chance player wins
	
	if player_won:
		_handle_player_victory()
	else:
		_handle_bandit_victory()

func _handle_player_victory() -> void:
	# Player won the fight
	combat_losses += 1
	State.add_event({"type": "defeated_bandit", "by": "player"})
	# NEW: Update THIS bandit's individual opinion of the player
	update_player_reputation(-25)  # Bandit dislikes being defeated
	
	# Show combat result to player
	_show_combat_result("Victory!", "You defeated the bandit!", Color.GREEN)
	
	# Visual feedback - bandit flashes red briefly and shakes
	_flash_bandit(Color.RED)
	_shake_bandit()
	
	var victory_line: String = await LLM.generate_line(
		"wilderness bandit: defeated, humiliated, trying to save face",
		"bandit_defeated",
		{},
		"You got lucky this time! But I'll be back, and next time I won't be so merciful!"
	)
	
	Dialogue.continue_dialogue("Bandit", ["[b]Bandit:[/b] " + victory_line])
	
	# Bandit flees after being defeated
	_flee_from_player()
	
	# Add some delay before returning to patrol
	await get_tree().create_timer(3.0).timeout
	state = BanditState.PATROL
	_set_next_patrol_target()

func _handle_bandit_victory() -> void:
	# Bandit won the fight
	combat_wins += 1
	State.add_event({"type": "robbed_by_bandit", "by": "player"})
	# NEW: Update THIS bandit's individual opinion of the player
	update_player_reputation(15)  # Bandit likes winning against the player
	
	# Show combat result to player
	_show_combat_result("Defeat!", "The bandit robbed you!", Color.RED)
	
	# Visual feedback - bandit flashes green briefly and shakes
	_flash_bandit(Color.GREEN)
	_shake_bandit()
	
	var robbery_line: String = await LLM.generate_line(
		"wilderness bandit: victorious, arrogant, taking player's belongings",
		"bandit_victory",
		{},
		"Ha! You thought you could take me on? Hand over everything you've got, or this will get much worse!"
	)
	
	Dialogue.continue_dialogue("Bandit", ["[b]Bandit:[/b] " + robbery_line])
	
	# Bandit returns to patrol after robbing player
	state = BanditState.PATROL
	_set_next_patrol_target()

func _demand_tribute() -> void:
	# Check if player has gold (implement inventory system later)
	var has_gold = true  # Placeholder
	
	if has_gold:
		State.add_event({"type": "paid_tribute", "to": "bandit", "amount": 50})
		# NEW: Update THIS bandit's individual opinion of the player
		update_player_reputation(20)  # Bandit likes getting tribute
		
		var thanks_line: String = await LLM.generate_line(
			"wilderness bandit: satisfied, slightly less hostile",
			"accept_tribute",
			{},
			"Smart choice. Now get lost before I change my mind."
		)
		
		Dialogue.continue_dialogue("Bandit", ["[b]Bandit:[/b] " + thanks_line])
		state = BanditState.PATROL
		_set_next_patrol_target()
	else:
		Dialogue.continue_dialogue("Bandit", ["[b]Bandit:[/b] No gold? Then you'll pay with your life!"])
		state = BanditState.ATTACK

func _allow_escape() -> void:
	state = BanditState.PATROL
	_set_next_patrol_target()
	Dialogue.continue_dialogue("Bandit", ["[b]Bandit:[/b] Run while you can!"])

func _form_alliance() -> void:
	State.add_event({"type": "allied_with_bandit", "by": "player"})
	# NEW: Update THIS bandit's individual opinion of the player
	update_player_reputation(40)  # Bandit really likes forming alliances
	
	var alliance_line: String = await LLM.generate_line(
		"wilderness bandit: pleased, now considers player an ally",
		"alliance_formed",
		{},
		"Excellent! We'll make a fine team. Meet me at the old ruins tomorrow."
	)
	
	Dialogue.continue_dialogue("Bandit", ["[b]Bandit:[/b] " + alliance_line])
	state = BanditState.PATROL
	_set_next_patrol_target()

func _become_hostile() -> void:
	Dialogue.continue_dialogue("Bandit", ["[b]Bandit:[/b] Your loss! Now you'll pay!"])
	state = BanditState.CHASE

func take_damage(amount: float) -> void:
	health -= amount
	print("[Bandit] Took damage: ", amount, " Health: ", health)
	
	if health <= 0:
		_defeat()
	elif health < max_health * 0.3:  # Below 30% health
		_flee_from_player()

func _defeat() -> void:
	is_defeated = true
	state = BanditState.DEFEATED
	
	State.add_event({"type": "bandit_defeated", "by": "player"})
	# NEW: Update THIS bandit's individual opinion of the player
	update_player_reputation(-30)  # Bandit really dislikes being defeated
	
	# Could add defeated dialogue here
	print("[Bandit] Defeated!")

func _flee_from_player() -> void:
	if seen_player:
		# Calculate flee direction (away from player)
		var flee_dir = (global_position - seen_player.global_position).normalized()
		flee_target = global_position + flee_dir * 300.0
		
		agent.target_position = flee_target
		state = BanditState.FLEE
		print("[Bandit] Fleeing!")

func talk_to_player() -> void:
	if is_defeated:
		return
	
	# NEW: Check if chat is already open to prevent UI stacking
	if Chat.is_open():
		print("[Bandit] Chat already open, ignoring talk request")
		return
		
	if state == BanditState.ATTACK:
		_threaten_player()
	elif State.is_player_wanted() and randf() < 0.5:
		_offer_alliance()
	else:
		_threaten_player()

func _show_combat_stats() -> void:
	var stats_text = "Combat Record:\nWins: " + str(combat_wins) + "\nLosses: " + str(combat_losses)
	
	if result_label:
		result_label.text = stats_text
		result_label.modulate = Color.YELLOW
		result_label.visible = true
		
		# Hide the stats after 4 seconds
		await get_tree().create_timer(4.0).timeout
		result_label.visible = false

func _show_combat_result(title: String, message: String, color: Color) -> void:
	if result_label:
		result_label.text = title + "\n" + message
		result_label.modulate = color
		result_label.visible = true
		
		# Hide the result after 3 seconds
		await get_tree().create_timer(3.0).timeout
		result_label.visible = false

func _flash_bandit(color: Color) -> void:
	if sprite:
		var original_modulate = sprite.modulate
		sprite.modulate = color
		
		# Flash for 0.5 seconds then return to normal
		await get_tree().create_timer(0.5).timeout
		sprite.modulate = original_modulate

func _shake_bandit() -> void:
	if sprite:
		var original_pos = sprite.position
		
		# Shake effect
		for i in range(6):
			var shake_offset = Vector2(randf_range(-3, 3), randf_range(-3, 3))
			sprite.position = original_pos + shake_offset
			await get_tree().create_timer(0.1).timeout
		
		sprite.position = original_pos
