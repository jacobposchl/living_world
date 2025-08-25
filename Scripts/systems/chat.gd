# res://scripts/systems/chat.gd  (Autoload as Chat)
extends Node

var ui: ChatUI
var _persona: String = ""
var _ctx_provider: Callable = Callable()
var _history: Array[Dictionary] = []   # [{role:"user"/"npc", "text": String}]
const MAX_HISTORY := 6                 # last 6 lines (3 exchanges)

func _ready() -> void:
	var packed: PackedScene = preload("res://scenes/ui/ChatUI.tscn")  # fix path if needed
	ui = packed.instantiate() as ChatUI
	ui.layer = 2
	ui.process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().root.call_deferred("add_child", ui)
	ui.hide()
	# Connect here (once)
	ui.send_pressed.connect(_on_player_send)
	print("[Chat] ready")

func open(partner_name: String, persona: String, ctx_provider: Callable = Callable()) -> void:
	_history.clear()
	_persona = persona
	_ctx_provider = ctx_provider
	if not ui.is_inside_tree():
		await get_tree().process_frame
	ui.open(partner_name)
	ui.show()
	print("[Chat] open ->", partner_name, "persona:", _persona)

func is_open() -> bool:
	return ui != null and ui.is_open()


func _on_player_send(text: String) -> void:
	ui.append_line("You", text)
	_history.append({"role":"user","text":text})
	# trim
	while _history.size() > MAX_HISTORY:
		_history.pop_front()

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

	ui.append_line("NPC", reply)
	_history.append({"role":"npc","text":reply})
	while _history.size() > MAX_HISTORY:
		_history.pop_front()
