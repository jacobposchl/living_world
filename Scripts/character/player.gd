extends CharacterBody2D

var speed: float = 100.0
@onready var interact_area: Area2D = $"InteractArea"

func _physics_process(_delta: float) -> void:
	# Block movement if Dialogue OR Chat is active
	if (typeof(Dialogue) != TYPE_NIL and Dialogue.is_active()) \
	or (typeof(Chat) != TYPE_NIL and Chat.is_open()):
		velocity = Vector2.ZERO
		move_and_slide()
		return

	var move_dir := Vector2(
		Input.get_axis("move_left", "move_right"),
		Input.get_axis("move_up", "move_down")
	)
	velocity = (speed * move_dir.normalized()) if move_dir != Vector2.ZERO else Vector2.ZERO
	move_and_slide()

func _process(delta: float) -> void:
	# Block interactions if Dialogue OR Chat is active
	if (typeof(Dialogue) != TYPE_NIL and Dialogue.is_active()) \
	or (typeof(Chat) != TYPE_NIL and Chat.is_open()):
		return

	if Input.is_action_just_pressed("interact"):
		var interacted := false

		var body_list := interact_area.get_overlapping_bodies()
		var area_list := interact_area.get_overlapping_areas()
		print("Interact: bodies=", body_list.size(), " areas=", area_list.size())

		for b in body_list:
			print(" body:", b.name, " groups=", b.get_groups())
			if b.is_in_group("interactable") and b.has_method("interact"):
				print(" -> interacting with BODY:", b.name)
				b.interact(self)
				interacted = true
				break
			if b.is_in_group("npc") and b.has_method("talk_to_player"):
				print(" -> talking to NPC BODY:", b.name)
				b.talk_to_player()
				interacted = true
				break
		if interacted:
			return

		for a in area_list:
			print(" area:", a.name, " groups=", a.get_groups())
			if a.is_in_group("interactable") and a.has_method("interact"):
				print(" -> interacting with AREA:", a.name)
				a.interact(self)
				break
