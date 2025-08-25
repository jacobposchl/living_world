# res://scripts/systems/llm.gd
extends Node
# Autoload this as "LLM"

# --- Config ---
var use_ollama: bool = true
var ollama_url: String = "http://127.0.0.1:11434/api/generate"
var ollama_model: String = "mistral"
var request_timeout_sec: float = 20.0  # Increased timeout for free chat

# --- Cache / rate limit ---
var _cache: Dictionary = {}                 # String key -> String text
var _last_call_by_key: Dictionary = {}      # String key -> float timestamp
var min_seconds_between_same_request: float = 2.0

func _key(persona: String, intent: String, context: Dictionary) -> String:
	return "%s|%s|%s" % [persona, intent, JSON.stringify(context)]

func _format_prompt(persona: String, intent: String, context: Dictionary) -> String:
	var facts := PackedStringArray()
	if context.get("lab_looted", false):
		facts.append("The lab was recently looted.")
	if context.get("player_wanted", false):
		facts.append("The player is currently wanted by town guards.")
	var world_text: String = "No notable events."
	if facts.size() > 0:
		world_text = ", ".join(facts)

	# New: include short chat history + latest user message when present
	var chat_context: String = String(context.get("chat_context", "")).strip_edges()
	var latest_user: String = String(context.get("player_text", "")).strip_edges()
	var convo_section: String = ""
	if chat_context != "":
		convo_section = "Recent dialogue (user=player, npc=you):\n%s\n" % chat_context
	var latest_section: String = ""
	if latest_user != "":
		latest_section = "Player just said: \"%s\"\n" % latest_user

	return """You are an NPC in a medieval-fantasy village.
Persona: %s
Intent: %s
World context: %s
%s%s
Instructions: Reply as the NPC, 1–2 short sentences, in-universe, no emojis, no quotes. Do not repeat yourself. Avoid echoing the player's words verbatim.
Output ONLY your line.
""" % [persona, intent, world_text, convo_section, latest_section]

# Call this with: var line := await LLM.generate_line(..., fallback)
func generate_line(persona: String, intent: String, context: Dictionary, fallback: String) -> String:
	var k: String = _key(persona, intent, context)
	var is_free_chat: bool = (intent == "free_chat")

	# Cooldown & cache: skip for free_chat so each turn is fresh
	if not is_free_chat:
		var now: float = Time.get_unix_time_from_system()
		if _last_call_by_key.has(k):
			var last: float = float(_last_call_by_key[k])
			if (now - last) < min_seconds_between_same_request:
				if _cache.has(k):
					return String(_cache[k])
				return fallback
		_last_call_by_key[k] = now

		# Serve from cache if exists
		if _cache.has(k):
			return String(_cache[k])

	var prompt: String = _format_prompt(persona, intent, context)

	# If not using Ollama yet, bail out with fallback (or call your other endpoint here)
	if not use_ollama:
		return fallback

	# --- Ollama HTTP request ---
	var req := HTTPRequest.new()
	add_child(req)
	req.timeout = int(ceil(request_timeout_sec))

	var headers := PackedStringArray(["Content-Type: application/json"])

	# New: add mild randomness so the model doesn't stick to one phrasing
	var body_dict: Dictionary = {
		"model": ollama_model,
		"prompt": prompt,
		"stream": false,
		"options": {
			"temperature": 0.8,       # light variety for chat
			"top_p": 0.9,
			"repeat_penalty": 1.1
		}
	}
	var body_json: String = JSON.stringify(body_dict)

	var err: int = req.request(ollama_url, headers, HTTPClient.METHOD_POST, body_json)
	if err != OK:
		req.queue_free()
		return fallback

	var result: Array = await req.request_completed  # [result, response_code, headers, body]
	var result_status: int = int(result[0])
	var response_code: int = int(result[1])
	var raw_body: PackedByteArray = result[3]

	var out_text: String = fallback
	if result_status == HTTPRequest.RESULT_SUCCESS and response_code >= 200 and response_code < 300:
		var txt: String = raw_body.get_string_from_utf8()
		var parsed: Variant = JSON.parse_string(txt)
		if typeof(parsed) == TYPE_DICTIONARY:
			var dict: Dictionary = parsed as Dictionary
			var resp: String = String(dict.get("response", "")).strip_edges()
			if resp != "":
				out_text = resp
				# Only cache non-chat intents; chat should feel fresh each turn
				if not is_free_chat:
					_cache[k] = out_text

	req.queue_free()
	return out_text
