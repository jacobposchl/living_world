extends CanvasLayer
class_name DialogueUI

signal dialogue_started
signal dialogue_ended
signal choice_selected(choice_id: String)

@onready var speaker_lbl: Label = $Box/Speaker
@onready var text_lbl: RichTextLabel = $Box/Text
@onready var choices_row: HBoxContainer = $Box/Choices

var _lines: Array[String] = []
var _idx := 0
var _active := false
var _pending_choices: Array = []  # [{label:String, id:String}, ...]

func start_dialogue(speaker: String, lines: Array[String]) -> void:
	if lines.is_empty(): return
	_lines = lines
	_idx = 0
	_active = true
	visible = true
	speaker_lbl.text = speaker
	_render_choices([]) # clear
	emit_signal("dialogue_started")
	_show_current()

func is_active() -> bool: return _active

func next() -> void:
	if not _active: return
	# Don’t advance if there are choices on screen
	if _pending_choices.size() > 0: return
	_idx += 1
	if _idx >= _lines.size(): _end()
	else: _show_current()

func show_choices(choices: Array) -> void:
	# choices = [{ "label": "Confess", "id": "confess" }, ...]
	_pending_choices = choices
	_render_choices(choices)

func _render_choices(choices: Array) -> void:
	# Clear old
	for c in choices_row.get_children():
		c.queue_free()
	if choices.is_empty():
		return
	# Create buttons
	for ch in choices:
		var b := Button.new()
		b.text = String(ch.get("label", "Option"))
		var id := String(ch.get("id", ""))
		b.pressed.connect(func():
			_pending_choices.clear()
			_render_choices([])
			emit_signal("choice_selected", id)
		)
		choices_row.add_child(b)

func _show_current() -> void:
	text_lbl.bbcode_text = _lines[_idx]

func _end() -> void:
	_active = false
	visible = false
	_lines.clear()
	_idx = 0
	_render_choices([])
	emit_signal("dialogue_ended")

func _unhandled_input(event: InputEvent) -> void:
	if not _active: return
	if (event.is_action_pressed("interact")
		or (event is InputEventKey and event.pressed and (event.keycode == KEY_ENTER or event.keycode == KEY_SPACE))
		or (event is InputEventMouseButton and event.pressed)):
		next()
