# res://scripts/systems/chat.gd  (Autoload as Chat)
extends Node

var ui: ChatUI
var _persona: String = ""
var _ctx_provider: Callable = Callable()
var _history: Array[Dictionary] = []   # [{role:"user"/"npc", "text": String}]
const MAX_HISTORY := 6                 # last 6 lines (3 exchanges)

func _ready() -> void:
	var packed: PackedScene = preload("res://Scenes/ui/ChatUI.tscn")  # Fixed path with correct case
	ui = packed.instantiate() as ChatUI
	ui.layer = 2
	ui.process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().root.call_deferred("add_child", ui)
	ui.hide()
	# Connect here (once)
	ui.send_pressed.connect(_on_player_send)
	# NEW: Connect back to dialogue signal
	ui.back_to_dialogue.connect(_on_back_to_dialogue)
	print("[Chat] ready")

func open(partner_name: String, persona: String, ctx_provider: Callable = Callable()) -> void:
	# NEW: Check if chat is already open to prevent multiple windows
	if is_open():
		print("[Chat] Chat already open, ignoring new open request")
		return
	
	_history.clear()
	_persona = persona
	_ctx_provider = ctx_provider
	
	# Safety check: ensure UI is ready
	if not ui or not ui.is_inside_tree():
		print("[Chat] ERROR: UI not ready, cannot open chat")
		return
	
	# NEW: Get current reputation from context provider if available
	var current_reputation = 0
	if ctx_provider.is_valid():
		var ctx = ctx_provider.call() as Dictionary
		current_reputation = ctx.get("player_reputation", 0)
	
	if not ui.is_inside_tree():
		await get_tree().process_frame
		
	# Safety check: ensure UI has required methods
	if ui.has_method("open"):
		ui.open(partner_name, current_reputation)
		ui.show()
		print("[Chat] open ->", partner_name, "persona:", _persona, "reputation:", current_reputation)
	else:
		print("[Chat] ERROR: UI missing required methods")

func is_open() -> bool:
	return ui != null and ui.is_open()

func _on_player_send(text: String) -> void:
	# Safety check: ensure UI is ready
	if not ui or not ui.is_inside_tree():
		print("[Chat] ERROR: UI not ready, cannot send message")
		return
		
	ui.append_line("You", text)
	_history.append({"role":"user","text":text})
	# trim
	while _history.size() > MAX_HISTORY:
		_history.pop_front()

	# NEW: Show typing indicator while waiting for NPC response
	if ui.has_method("show_typing_indicator"):
		ui.show_typing_indicator()

	var ctx: Dictionary = {}
	if _ctx_provider.is_valid():
		ctx = _ctx_provider.call() as Dictionary

	# Build compact history string
	var convo := ""
	for h in _history:
		convo += ("%s: %s\n" % [String(h["role"]), String(h["text"])])

	ctx["chat_context"] = convo
	ctx["player_text"] = text  # latest message

	var reply: String = await LLM.generate_line(
		_persona,
		"free_chat",
		ctx,
		"(…no response…)"
	)

	# NEW: Hide typing indicator when NPC responds
	if ui.has_method("hide_typing_indicator"):
		ui.hide_typing_indicator()

	ui.append_line("NPC", reply)
	_history.append({"role":"npc","text":reply})
	while _history.size() > MAX_HISTORY:
		_history.pop_front()
	
	# NEW: Update reputation score if it changed
	if _ctx_provider.is_valid() and ui.has_method("update_reputation_score"):
		var updated_ctx = _ctx_provider.call() as Dictionary
		var updated_reputation = updated_ctx.get("player_reputation", 0)
		ui.update_reputation_score(updated_reputation)

# NEW: Handler for back to dialogue signal
func _on_back_to_dialogue() -> void:
	print("[Chat] Going back to dialogue options")
	# Close chat and re-open dialogue
	if ui and ui.has_method("close"):
		ui.close()
	# Re-open dialogue with the same NPC
	if _ctx_provider.is_valid():
		var _ctx = _ctx_provider.call() as Dictionary  # Fixed: prefixed with underscore
		# This will trigger the NPC to show dialogue options again
		print("[Chat] Chat closed, dialogue should re-open")

func close() -> void:
	if ui and ui.has_method("close"):
		ui.close()
		print("[Chat] Chat closed")
