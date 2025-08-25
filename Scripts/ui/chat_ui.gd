extends CanvasLayer
class_name ChatUI

signal send_pressed(text: String)
signal chat_closed

@onready var header: Label = $Box/Header
@onready var transcript: RichTextLabel = $Box/Transcript
@onready var entry: LineEdit = $Box/InputRow/Entry
@onready var send_btn: Button = $Box/InputRow/Send
@onready var close_btn: Button = null  # <-- new (resolved in _ensure_nodes)

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
		header = get_node_or_null("Box/Header") as Label
	if transcript == null:
		transcript = get_node_or_null("Box/Transcript") as RichTextLabel
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

	if header == null or transcript == null or entry == null or send_btn == null:
		push_error("ChatUI: Missing Box/Header, Transcript, Entry, or Send. Check node names/paths.")
		return false
	return true

func open(partner_name: String) -> void:
	if not _ensure_nodes():
		return
	header.text = "Talking to: %s" % partner_name
	transcript.clear()
	entry.clear()
	visible = true
	entry.grab_focus()

func close() -> void:
	visible = false
	emit_signal("chat_closed")

func append_line(speaker: String, text: String) -> void:
	if not _ensure_nodes():
		return
	transcript.append_text("[b]%s:[/b] %s\n" % [speaker, text])

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
	close()
