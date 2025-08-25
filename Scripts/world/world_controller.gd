extends Node2D
# World controller script to set up wilderness area and bandit

@onready var wilderness_setup = preload("res://Scripts/systems/wilderness_setup.gd").new()

func _ready() -> void:
	print("[WorldController] Starting world setup...")
	print("[WorldController] World node name: ", name)
	print("[WorldController] World node type: ", get_class())
	print("[WorldController] World node position: ", global_position)
	print("[WorldController] Wilderness setup script loaded: ", wilderness_setup != null)
	
	# Wait a frame to ensure all nodes are ready
	await get_tree().process_frame
	
	print("[WorldController] Frame processed, setting up wilderness...")
	
	# Set up wilderness area and bandit
	wilderness_setup.setup_complete_wilderness(self)
	
	print("[WorldController] World setup complete!")
	print("[WorldController] Total children: ", get_child_count())
	
	# List all children to see what was added
	for i in range(get_child_count()):
		var child = get_child(i)
		print("[WorldController] Child ", i, ": ", child.name, " (", child.get_class(), ") at ", child.global_position)
