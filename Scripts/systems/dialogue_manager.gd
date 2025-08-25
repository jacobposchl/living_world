extends Node

# This stub will later call OpenAI/Ollama.
# For now, it just returns a canned line based on "intent".

func request_line(npc_id: String, intent: String, context: Dictionary) -> String:
	match intent:
		"greet":
			return "Hello there. Watch your step around here."
		"warn":
			return "Halt! State your business."
		"thanks":
			return "You have my gratitude."
		_:
			return "..."
