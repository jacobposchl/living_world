extends Area2D

var bodies_in_range: Array = []

func _on_body_entered(body):
	if body.is_in_group("npc"):
		bodies_in_range.append(body)

func _on_body_exited(body):
	if body.is_in_group("npc"):
		bodies_in_range.erase(body)

@onready var interact_area: Area2D = $InteractArea as Area2D

func _process(_delta: float) -> void:
	if Dialogue.is_active():
		return
	if Input.is_action_just_pressed("interact"):
		var bodies := interact_area.get_overlapping_bodies()
		for b in bodies:
			if b.is_in_group("interactable") and b.has_method("interact"):
				b.interact(self)
				return
		for b in bodies:
			if b.is_in_group("npc") and b.has_method("talk_to_player"):
				b.talk_to_player()
				return
