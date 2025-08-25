extends CanvasLayer
class_name ChatUI

signal send_pressed(text: String)
signal chat_closed
signal back_to_dialogue

# NEW: Updated node references for simplified UI structure
@onready var header_label: Label = null
@onready var reputation_score: Label = null
@onready var transcript: RichTextLabel = null
@onready var typing_indicator: HBoxContainer = null
@onready var typing_container: PanelContainer = null
@onready var entry: LineEdit = null
@onready var send_btn: Button = null
@onready var close_btn: Button = null

# NEW: Typing indicator animation
var typing_timer: SceneTreeTimer = null
var typing_dots: Label = null

func _ready() -> void:
	visible = false
	_ensure_nodes()
	_connect_signals()

func _connect_signals() -> void:
	# Connect send button
	if send_btn and not send_btn.pressed.is_connected(_on_send):
		send_btn.pressed.connect(_on_send)
		print("[ChatUI] Send button signal connected")
	elif not send_btn:
		print("[ChatUI] ERROR: Send button not found for signal connection!")
	
	# Connect entry field for Enter key functionality
	if entry and not entry.text_submitted.is_connected(_on_text_submitted):
		entry.text_submitted.connect(_on_text_submitted)
		print("[ChatUI] Entry text_submitted signal connected")
	elif not entry:
		print("[ChatUI] ERROR: Entry field not found for signal connection!")
	
	# Connect close button
	if close_btn and not close_btn.pressed.is_connected(_on_close_pressed):
		close_btn.pressed.connect(_on_close_pressed)
		print("[ChatUI] Close button signal connected")
	elif not close_btn:
		print("[ChatUI] ERROR: Close button not found for signal connection!")

func _ensure_nodes() -> bool:
	print("[ChatUI] _ensure_nodes() called - checking node paths...")
	
	# Try primary paths first, then fallback to searching entire tree
	if header_label == null:
		header_label = get_node_or_null("ChatBox/MainContainer/Header/HeaderRow/LeftSection/Title") as Label
		if header_label == null:
			header_label = _find_node_by_name("Title") as Label
		print("[ChatUI] HeaderLabel found: ", header_label != null)
	
	if reputation_score == null:
		reputation_score = get_node_or_null("ChatBox/MainContainer/Header/HeaderRow/RightSection/Reputation") as Label
		if reputation_score == null:
			reputation_score = _find_node_by_name("Reputation") as Label
		print("[ChatUI] ReputationScore found: ", reputation_score != null)
	
	if transcript == null:
		transcript = get_node_or_null("ChatBox/MainContainer/ChatArea/Messages/MessageMargin/MessageText") as RichTextLabel
		if transcript == null:
			transcript = _find_node_by_name("MessageText") as RichTextLabel
		print("[ChatUI] Transcript found: ", transcript != null)
	
	if typing_indicator == null:
		typing_indicator = get_node_or_null("ChatBox/MainContainer/ChatArea/TypingArea/TypingMargin/TypingRow") as HBoxContainer
		if typing_indicator == null:
			typing_indicator = _find_node_by_name("TypingRow") as HBoxContainer
		print("[ChatUI] TypingIndicator found: ", typing_indicator != null)
	
	if typing_container == null:
		typing_container = get_node_or_null("ChatBox/MainContainer/ChatArea/TypingArea") as PanelContainer
		if typing_container == null:
			typing_container = _find_node_by_name("TypingArea") as PanelContainer
		print("[ChatUI] TypingContainer found: ", typing_container != null)
	
	if entry == null:
		entry = get_node_or_null("ChatBox/MainContainer/InputArea/InputMargin/InputRow/TextInput") as LineEdit
		if entry == null:
			entry = _find_node_by_name("TextInput") as LineEdit
		print("[ChatUI] Entry found: ", entry != null)
	
	if send_btn == null:
		send_btn = get_node_or_null("ChatBox/MainContainer/InputArea/InputMargin/InputRow/SendButton") as Button
		if send_btn == null:
			send_btn = _find_node_by_name("SendButton") as Button
		print("[ChatUI] Send button found: ", send_btn != null)
	
	if close_btn == null:
		close_btn = get_node_or_null("ChatBox/MainContainer/Header/HeaderRow/RightSection/BackButton") as Button
		if close_btn == null:
			close_btn = _find_node_by_name("BackButton") as Button
		print("[ChatUI] Close button found: ", close_btn != null)

	# NEW: Get typing dots reference with new path
	if typing_indicator:
		typing_dots = typing_indicator.get_node_or_null("TypingDots") as Label
		if typing_dots == null:
			typing_dots = _find_node_by_name("TypingDots") as Label
		print("[ChatUI] TypingDots found: ", typing_dots != null)

	# Check essential nodes
	if header_label == null or reputation_score == null or transcript == null or entry == null or send_btn == null:
		push_error("ChatUI: Missing required nodes. Check node names/paths in redesigned UI.")
		print("[ChatUI] FAILED - Missing essential nodes:")
		print("  HeaderLabel: ", header_label != null)
		print("  ReputationScore: ", reputation_score != null) 
		print("  Transcript: ", transcript != null)
		print("  Entry: ", entry != null)
		print("  Send button: ", send_btn != null)
		return false
	
	print("[ChatUI] _ensure_nodes() SUCCESS - All nodes found!")
	return true

# Helper function to find nodes by name anywhere in the tree
func _find_node_by_name(node_name: String) -> Node:
	return _search_children_recursive(self, node_name)

func _search_children_recursive(node: Node, target_name: String) -> Node:
	if node.name == target_name:
		return node
	
	for child in node.get_children():
		var result = _search_children_recursive(child, target_name)
		if result:
			return result
	
	return null

func open(partner_name: String, reputation: int = 0) -> void:
	# Re-ensure nodes and connections in case they were moved
	if not _ensure_nodes():
		print("[ChatUI] ERROR: Cannot open chat - missing essential nodes")
		return
	
	# Reconnect signals in case nodes were moved
	_connect_signals()
	
	header_label.text = "Talking to: %s" % partner_name
	update_reputation_score(reputation)
	transcript.clear()
	entry.clear()
	hide_typing_indicator()
	visible = true
	# Ensure entry field has focus for Enter key functionality
	call_deferred("_grab_entry_focus")

func close() -> void:
	hide_typing_indicator()
	visible = false
	emit_signal("chat_closed")

func _grab_entry_focus() -> void:
	if entry:
		entry.grab_focus()
		print("[ChatUI] Entry field focus grabbed")
	else:
		print("[ChatUI] ERROR: Cannot grab focus - entry field not found")

func append_line(speaker: String, text: String) -> void:
	if not _ensure_nodes():
		return
	transcript.append_text("[b]%s:[/b] %s\n" % [speaker, text])

# NEW: Methods for typing indicator
func show_typing_indicator() -> void:
	if not _ensure_nodes() or not typing_container:
		return
	typing_container.visible = true
	_start_typing_animation()

func hide_typing_indicator() -> void:
	if not _ensure_nodes() or not typing_container:
		return
	typing_container.visible = false
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
	if not typing_dots or not typing_container or not typing_container.visible:
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
	if typing_container.visible:
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
	print("[ChatUI] _on_send() called")
	if not _ensure_nodes():
		print("[ChatUI] ERROR: _ensure_nodes() failed in _on_send")
		return
	var txt: String = entry.text.strip_edges()
	print("[ChatUI] Message text: '", txt, "'")
	if txt == "":
		print("[ChatUI] Empty message, ignoring")
		return
	entry.clear()
	print("[ChatUI] Emitting send_pressed signal with text: '", txt, "'")
	emit_signal("send_pressed", txt)

func _on_text_submitted(txt: String) -> void:
	print("[ChatUI] Text submitted via Enter key: '", txt, "'")
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
