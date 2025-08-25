extends Node
var ui: DialogueUI

func _ready() -> void:
	var packed: PackedScene = preload("res://scenes/ui/DialogueUI.tscn")
	ui = packed.instantiate() as DialogueUI
	get_tree().root.call_deferred("add_child", ui)
	ui.hide()

func start(speaker: String, lines: Array[String]) -> void:
	if ui and not ui.visible:
		ui.start_dialogue(speaker, lines)

func is_active() -> bool:
	return ui != null and ui.is_active()

func choices(array_of_choices: Array, target: Object, method: String) -> void:
	# Wire the next one-off choice to a callback on your NPC or World
	if not ui: return
	for c in ui.choice_selected.get_connections():
		ui.choice_selected.disconnect(c.callable)
	ui.choice_selected.connect(func(id: String):
		if is_instance_valid(target) and target.has_method(method):
			target.call(method, id)
	)
	ui.show_choices(array_of_choices)
	
	
# --- NEW METHODS ---

# Force a new set of lines even if dialogue is already visible
func continue_dialogue(speaker: String, lines: Array[String]) -> void:
	if ui:
		ui.start_dialogue(speaker, lines)

# Quick helper for a single follow-up line
func say(speaker: String, line: String) -> void:
	continue_dialogue(speaker, [line])
	
func close() -> void:
	if ui:
		ui.hide()
		# emit "dialogue_ended" if your DialogueUI has that signal
		if ui.has_signal("dialogue_ended"):
			ui.dialogue_ended.emit()
