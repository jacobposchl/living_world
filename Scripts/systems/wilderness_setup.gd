extends Node
# Helper script to set up wilderness area and bandit NPC
# Run this once to add the necessary nodes to your world

func setup_wilderness_area(world_node: Node2D) -> void:
	print("[WildernessSetup] Setting up wilderness area...")
	print("[WildernessSetup] World node: ", world_node.name, " at position: ", world_node.global_position)
	
	# Add patrol markers
	var patrol_positions = [
		Vector2(800, 200),   # WildernessPatrolA
		Vector2(1000, 300),  # WildernessPatrolB
		Vector2(900, 500),   # WildernessPatrolC
		Vector2(700, 400)    # WildernessPatrolD
	]
	
	var marker_names = ["WildernessPatrolA", "WildernessPatrolB", "WildernessPatrolC", "WildernessPatrolD"]
	
	for i in range(patrol_positions.size()):
		var marker = Marker2D.new()
		marker.name = marker_names[i]
		marker.position = patrol_positions[i]
		world_node.add_child(marker)
		print("[WildernessSetup] Added patrol marker: ", marker_names[i], " at ", patrol_positions[i])
		print("[WildernessSetup] Marker global position: ", marker.global_position)
	
	print("[WildernessSetup] Wilderness area setup complete!")

func add_bandit_to_world(world_node: Node2D) -> void:
	print("[WildernessSetup] Adding bandit to world...")
	
	# Check if bandit scene file exists
	var bandit_path = "res://Scenes/character/NPC_Bandit.tscn"
	var file_check = FileAccess.file_exists(bandit_path)
	print("[WildernessSetup] Bandit scene file exists: ", file_check)
	print("[WildernessSetup] Bandit scene path: ", bandit_path)
	
	# Load the bandit scene
	var bandit_scene = preload("res://Scenes/character/NPC_Bandit.tscn")
	if bandit_scene == null:
		print("[WildernessSetup] ERROR: Failed to preload bandit scene!")
		return
	
	print("[WildernessSetup] Bandit scene loaded successfully")
	
	var bandit = bandit_scene.instantiate()
	if bandit == null:
		print("[WildernessSetup] ERROR: Failed to instantiate bandit!")
		return
	
	print("[WildernessSetup] Bandit instantiated successfully")
	
	# Position the bandit
	bandit.position = Vector2(850, 350)
	print("[WildernessSetup] Bandit positioned at: ", bandit.position)
	
	# Set patrol targets
	var patrol_targets = [
		NodePath("WildernessPatrolA"),
		NodePath("WildernessPatrolB"),
		NodePath("WildernessPatrolC"),
		NodePath("WildernessPatrolD")
	]
	bandit.patrol_targets = patrol_targets
	print("[WildernessSetup] Patrol targets set: ", patrol_targets)
	
	# Add to world
	world_node.add_child(bandit)
	print("[WildernessSetup] Bandit added to world as child of: ", world_node.name)
	print("[WildernessSetup] Bandit is in tree: ", bandit.is_inside_tree())
	print("[WildernessSetup] Bandit global position: ", bandit.global_position)
	print("[WildernessSetup] Bandit added at position (850, 350)")

# Call this from your world script to set everything up
func setup_complete_wilderness(world_node: Node2D) -> void:
	print("[WildernessSetup] Starting complete wilderness setup...")
	print("[WildernessSetup] World node type: ", world_node.get_class())
	print("[WildernessSetup] World node name: ", world_node.name)
	
	setup_wilderness_area(world_node)
	add_bandit_to_world(world_node)
	print("[WildernessSetup] Complete wilderness setup finished!")
