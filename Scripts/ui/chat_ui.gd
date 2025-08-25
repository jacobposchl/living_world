extends CanvasLayer
class_name ChatUI

signal send_pressed(text: String)
signal chat_closed
signal back_to_dialogue

@onready var header: HBoxContainer = $Box/Header
@onready var header_label: Label = $Box/Header/HeaderLabel
@onready var reputation_score: Label = $Box/Header/ReputationScore
@onready var transcript: RichTextLabel = $Box/Transcript
@onready var typing_indicator: HBoxContainer = $Box/TypingIndicator
@onready var entry: LineEdit = $Box/InputRow/Entry
@onready var send_btn: Button = $Box/InputRow/Send
@onready var close_btn: Button = null  # <-- new (resolved in _ensure_nodes)

# NEW: Typing indicator animation
var typing_timer: SceneTreeTimer = null
var typing_dots: Label = null

func _ready() -> void:
	visible = false
	_ensure_nodes()
	if send_btn:
		send_btn.pressed.connect(_on_send)
	if entry:
		entry.text_submitted.connect(_on_text_submitted)
	# if a Close button exists, wire it up
	if close_btn and not close_btn.pressed.is_connected(_on_close_pressed):
		close_btn.pressed.connect(_on_close_pressed)
		close_btn.tooltip_text = "Close (Esc)"

func _ensure_nodes() -> bool:
	if header == null:
		header = get_node_or_null("Box/Header") as HBoxContainer
	if header_label == null:
		header_label = get_node_or_null("Box/Header/HeaderLabel") as Label
	if reputation_score == null:
		reputation_score = get_node_or_null("Box/Header/ReputationScore") as Label
	if transcript == null:
		transcript = get_node_or_null("Box/Transcript") as RichTextLabel
	if typing_indicator == null:
		typing_indicator = get_node_or_null("Box/TypingIndicator") as HBoxContainer
	if entry == null:
		entry = get_node_or_null("Box/InputRow/Entry") as LineEdit
	if send_btn == null:
		send_btn = get_node_or_null("Box/InputRow/Send") as Button

	# try preferred and fallback locations for the close button
	if close_btn == null:
		close_btn = get_node_or_null("Box/Header/CloseBtn") as Button
	if close_btn == null:
		close_btn = get_node_or_null("Box/CloseBtn") as Button
	if close_btn == null:
		close_btn = get_node_or_null("CloseBtn") as Button

	# NEW: Get typing dots reference
	if typing_indicator:
		typing_dots = typing_indicator.get_node_or_null("TypingDots") as Label

	if header == null or header_label == null or reputation_score == null or transcript == null or entry == null or send_btn == null:
		push_error("ChatUI: Missing required nodes. Check node names/paths.")
		return false
	return true

func open(partner_name: String, reputation: int = 0) -> void:
	if not _ensure_nodes():
		return
	header_label.text = "Talking to: %s" % partner_name
	update_reputation_score(reputation)
	transcript.clear()
	entry.clear()
	hide_typing_indicator()
	visible = true
	entry.grab_focus()

func close() -> void:
	hide_typing_indicator()
	visible = false
	emit_signal("chat_closed")

func append_line(speaker: String, text: String) -> void:
	if not _ensure_nodes():
		return
	transcript.append_text("[b]%s:[/b] %s\n" % [speaker, text])

# NEW: Methods for typing indicator
func show_typing_indicator() -> void:
	if not _ensure_nodes() or not typing_indicator:
		return
	typing_indicator.visible = true
	_start_typing_animation()

func hide_typing_indicator() -> void:
	if not _ensure_nodes() or not typing_indicator:
		return
	typing_indicator.visible = false
	_stop_typing_animation()

func _start_typing_animation() -> void:
	if not typing_dots:
		return
	# Animate the dots
	typing_dots.text = "."
	typing_timer = get_tree().create_timer(0.5)
	if typing_timer and typing_timer.timeout.is_connected(_animate_typing_dots):
		typing_timer.timeout.disconnect(_animate_typing_dots)
	typing_timer.timeout.connect(_animate_typing_dots)

func _stop_typing_animation() -> void:
	if typing_timer and typing_timer.timeout.is_connected(_animate_typing_dots):
		typing_timer.timeout.disconnect(_animate_typing_dots)
		typing_timer = null

func _animate_typing_dots() -> void:
	if not typing_dots or not typing_indicator.visible:
		return
	
	# Cycle through: . -> .. -> ... -> .
	match typing_dots.text:
		".":
			typing_dots.text = ".."
		"..":
			typing_dots.text = "..."
		"...":
			typing_dots.text = "."
	
	# Continue animation only if still visible
	if typing_indicator.visible:
		typing_timer = get_tree().create_timer(0.5)
		if typing_timer:
			typing_timer.timeout.connect(_animate_typing_dots)

# NEW: Method to update reputation score
func update_reputation_score(reputation: int) -> void:
	if not _ensure_nodes() or not reputation_score:
		return
	
	var reputation_text = "Rep: %d" % reputation
	
	# Color code the reputation
	if reputation > 20:
		reputation_score.modulate = Color.GREEN  # Good reputation
	elif reputation < -20:
		reputation_score.modulate = Color.RED    # Bad reputation
	else:
		reputation_score.modulate = Color.YELLOW # Neutral reputation
	
	reputation_score.text = reputation_text

func _on_send() -> void:
	if not _ensure_nodes():
		return
	var txt: String = entry.text.strip_edges()
	if txt == "":
		return
	entry.clear()
	emit_signal("send_pressed", txt)

func _on_text_submitted(_txt: String) -> void:
	_on_send()

func is_open() -> bool:
	return visible

func _process(_dt: float) -> void:
	if visible and Input.is_action_just_pressed("ui_cancel"):
		close()

# --- new: handler for the X button ---
func _on_close_pressed() -> void:
	# NEW: Go back to dialogue options instead of closing chat
	emit_signal("back_to_dialogue")
	close()
