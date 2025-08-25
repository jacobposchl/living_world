extends Area2D
@export var name_in_ui: String = "Lab Crate"

var used: bool = false

func interact(_by: Node) -> void:
	if used:
		return
	used = true
	# Persist a world consequence
	State.set_flag("lab_looted", true)
	State.add_event({ "type": "lab_looted", "by": "player" })
	# Optional: visual cue
	if has_node("Label"):
		$"Label".text = "You took supplies."
	# Optional: remove or change sprite
	# queue_free() # if you want it gone
