extends Area2D

@onready var police_station: StaticBody2D = get_parent()
@onready var interaction_prompt: Label = police_station.get_node("InteractionPrompt")

func _ready() -> void:
	print("[Police Interaction Area] Ready, connecting signals...")
	# Connect area signals for interaction detection
	area_entered.connect(_on_player_entered)
	area_exited.connect(_on_player_exited)
	print("[Police Interaction Area] Signals connected")

func _on_player_entered(area: Area2D) -> void:
	print("[Police Interaction Area] Area entered: ", area.name, " Groups: ", area.get_groups())
	if area.is_in_group("player"):
		print("[Police Interaction Area] Player entered, showing prompt")
		_show_interaction_prompt()

func _on_player_exited(area: Area2D) -> void:
	print("[Police Interaction Area] Area exited: ", area.name)
	if area.is_in_group("player"):
		print("[Police Interaction Area] Player exited, hiding prompt")
		_hide_interaction_prompt()

func _show_interaction_prompt() -> void:
	if interaction_prompt:
		interaction_prompt.visible = true
		print("[Police Interaction Area] Prompt shown")
	else:
		print("[Police Interaction Area] ERROR: No interaction prompt found!")

func _hide_interaction_prompt() -> void:
	if interaction_prompt:
		interaction_prompt.visible = false
		print("[Police Interaction Area] Prompt hidden")

func interact(by: Node) -> void:
	print("[Police Interaction Area] Interact called by: ", by.name, " Groups: ", by.get_groups())
	
	# Get the police station reference
	var station = get_parent()
	print("[Police Interaction Area] Police station reference: ", station.name, " Type: ", station.get_class())
	
	# For testing, accept any interaction
	print("[Police Interaction Area] Accepting interaction for testing...")
	
	# Try the simple dialogue first, then fall back to test
	if station.has_method("simple_dialogue"):
		print("[Police Interaction Area] Calling simple dialogue")
		station.simple_dialogue()
	elif station.has_method("_handle_police_interaction"):
		print("[Police Interaction Area] Calling full police station interaction")
		station._handle_police_interaction()
	elif station.has_method("simple_interact"):
		print("[Police Interaction Area] Calling simple interaction")
		station.simple_interact()
	elif station.has_method("test_interact"):
		print("[Police Interaction Area] Calling test interaction")
		station.test_interact()
	else:
		print("[Police Interaction Area] No interaction methods found!")
		print("[Police Interaction Area] Available methods: ", station.get_method_list())
