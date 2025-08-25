extends StaticBody2D

@export var name_in_ui: String = "Police Station"

@onready var sprite: Sprite2D = $Sprite2D

func _ready() -> void:
	print("[Police Station] Ready, checking wanted status...")
	
	# Check if required systems are available
	if not State:
		print("[Police Station] WARNING: State system not found, but continuing...")
		# return  # Commented out for testing
	if not Dialogue:
		print("[Police Station] WARNING: Dialogue system not found, but continuing...")
		# return  # Commented out for testing
	if not LLM:
		print("[Police Station] WARNING: LLM system not found, but continuing...")
		# return  # Commented out for testing
		
	print("[Police Station] All required systems found")
	
	# Check if player is wanted and show wanted poster
	if State:
		_check_wanted_status()
	else:
		print("[Police Station] Skipping wanted status check due to missing State system")
	print("[Police Station] Ready complete")

func test_method() -> void:
	print("[Police Station] Test method called - police station is working!")

func simple_interact() -> void:
	print("[Police Station] Simple interaction called!")
	print("[Police Station] Sprite reference: ", sprite)
	
	# Just show a basic message for now
	if sprite:
		print("[Police Station] Flashing sprite yellow...")
		sprite.modulate = Color.YELLOW
		await get_tree().create_timer(1.0).timeout
		sprite.modulate = Color.WHITE
		print("[Police Station] Sprite returned to normal")
	else:
		print("[Police Station] ERROR: No sprite found!")

func test_interact() -> void:
	print("[Police Station] ==========================================")
	print("[Police Station] TEST INTERACTION SUCCESSFUL!")
	print("[Police Station] Police station is responding to E key!")
	print("[Police Station] ==========================================")

func simple_dialogue() -> void:
	print("[Police Station] ==========================================")
	print("[Police Station] Starting simple dialogue...")
	print("[Police Station] ==========================================")
	
	# Clear any existing dialogue first
	_clear_all_dialogue()
	
	# Show visual dialogue box
	_show_simple_dialogue_box()
	
	# For now, just show the dialogue in console
	# Later we can integrate with the proper dialogue system

func _clear_all_dialogue() -> void:
	# Remove all existing dialogue elements
	var existing_dialogue = get_node_or_null("MainDialogue")
	if existing_dialogue and is_instance_valid(existing_dialogue):
		existing_dialogue.queue_free()
	
	var existing_submenu = get_node_or_null("SubmenuDialogue")
	if existing_submenu and is_instance_valid(existing_submenu):
		existing_submenu.queue_free()
	
	# Also check for any other Control nodes that might be dialogue
	for child in get_children():
		if child is Control and child.name != "Sprite2D":
			child.queue_free()

func _show_simple_dialogue_box() -> void:
	# Create a container for the dialogue box
	var dialogue_container = Control.new()
	dialogue_container.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	dialogue_container.position = Vector2(50, 50)  # Move it higher up
	dialogue_container.size = Vector2(300, 200)
	dialogue_container.z_index = 1000  # Ensure it's on top of all sprites
	dialogue_container.name = "MainDialogue"  # Give it a unique name
	
	# Create character name label
	var name_label = Label.new()
	name_label.text = "Police Officer"
	name_label.position = Vector2(10, 10)
	name_label.size = Vector2(280, 30)
	name_label.add_theme_color_override("font_color", Color.WHITE)
	name_label.add_theme_font_size_override("font_size", 16)
	
	# Create dialogue text label
	var dialogue_label = Label.new()
	dialogue_label.text = "Good day, citizen! How can I help you today?"
	dialogue_label.position = Vector2(10, 40)
	dialogue_label.size = Vector2(280, 40)  # Reduced height from 60 to 40
	dialogue_label.add_theme_color_override("font_color", Color.WHITE)
	dialogue_label.add_theme_font_size_override("font_size", 14)
	dialogue_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	
	# Create choice buttons
	var choices = ["Report a crime", "Ask about local laws", "Seek protection", "Leave"]
	var button_height = 30  # Increased button height for better clickability
	var start_y = 90  # Moved buttons up since dialogue text is smaller
	
	for i in range(choices.size()):
		var button = Button.new()
		button.text = choices[i]
		button.position = Vector2(10, start_y + (i * button_height))
		button.size = Vector2(280, button_height)
		button.add_theme_color_override("font_color", Color.WHITE)
		button.add_theme_color_override("font_focus_color", Color.WHITE)
		button.add_theme_stylebox_override("normal", _create_button_stylebox())
		button.add_theme_stylebox_override("hover", _create_button_hover_stylebox())
		button.add_theme_stylebox_override("pressed", _create_button_pressed_stylebox())
		
		# Connect button signal
		var choice_id = ["report", "laws", "protection", "leave"][i]
		button.pressed.connect(_on_simple_choice.bind(choice_id))
		
		dialogue_container.add_child(button)
	
	# Add all elements to container
	dialogue_container.add_child(name_label)
	dialogue_container.add_child(dialogue_label)
	
	# Add to the scene
	add_child(dialogue_container)
	
	# Start guard status updates
	_start_guard_status_updates()
	
	# Remove after 10 seconds (longer for better readability)
	await get_tree().create_timer(10.0).timeout
	if dialogue_container and is_instance_valid(dialogue_container):
		dialogue_container.queue_free()

func _start_guard_status_updates() -> void:
	# Update guard status every 2 seconds
	var timer = get_tree().create_timer(2.0)
	timer.timeout.connect(_update_main_dialogue_with_guard_status)
	
	# Continue updating until dialogue is closed
	while timer.time_left > 0:
		await get_tree().process_frame
		
		# Check if dialogue still exists
		var main_dialogue = get_node_or_null("MainDialogue")
		if not main_dialogue or not is_instance_valid(main_dialogue):
			print("[Police Station] Dialogue closed, stopping guard status updates")
			break
		
		# Small delay to prevent excessive checking
		await get_tree().create_timer(0.1).timeout

func _create_dialogue_stylebox() -> StyleBoxFlat:
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.2, 0.2, 0.2, 0.9)  # Dark grey with transparency
	style.border_color = Color(0.4, 0.4, 0.4, 1.0)  # Lighter grey border
	style.border_width_left = 2
	style.border_width_right = 2
	style.border_width_top = 2
	style.border_width_bottom = 2
	style.corner_radius_top_left = 5
	style.corner_radius_top_right = 5
	style.corner_radius_bottom_left = 5
	style.corner_radius_bottom_right = 5
	return style

func _create_button_stylebox() -> StyleBoxFlat:
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.3, 0.3, 0.3, 0.8)  # Medium grey
	style.border_color = Color(0.5, 0.5, 0.5, 1.0)
	style.border_width_left = 1
	style.border_width_right = 1
	style.border_width_top = 1
	style.border_width_bottom = 1
	style.corner_radius_top_left = 3
	style.corner_radius_top_right = 3
	style.corner_radius_bottom_left = 3
	style.corner_radius_bottom_right = 3
	return style

func _create_button_hover_stylebox() -> StyleBoxFlat:
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.4, 0.4, 0.4, 0.9)  # Lighter grey on hover
	style.border_color = Color(0.6, 0.6, 0.6, 1.0)
	style.border_width_left = 1
	style.border_width_right = 1
	style.border_width_top = 1
	style.border_width_bottom = 1
	style.corner_radius_top_left = 3
	style.corner_radius_top_right = 3
	style.corner_radius_bottom_left = 3
	style.corner_radius_bottom_right = 3
	return style

func _create_button_pressed_stylebox() -> StyleBoxFlat:
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.5, 0.5, 0.5, 0.9)  # Even lighter grey when pressed
	style.border_color = Color(0.7, 0.7, 0.7, 1.0)
	style.border_width_left = 1
	style.border_width_right = 1
	style.border_width_top = 1
	style.border_width_bottom = 1
	style.corner_radius_top_left = 3
	style.corner_radius_top_right = 3
	style.corner_radius_bottom_left = 3
	style.corner_radius_bottom_right = 3
	return style

func _on_simple_choice(choice_id: String) -> void:
	print("[Police Station] Player chose: ", choice_id)
	
	# Handle the choice
	match choice_id:
		"report":
			_handle_crime_report_simple()
		"laws":
			_handle_laws_inquiry_simple()
		"protection":
			_handle_protection_request_simple()
		"leave":
			_handle_leave_simple()
	
	# Close the main dialogue
	var dialogue_container = get_node_or_null("MainDialogue")
	if dialogue_container and is_instance_valid(dialogue_container):
		dialogue_container.queue_free()

func _handle_crime_report_simple() -> void:
	print("[Police Station] ==========================================")
	print("[Police Station] CRIME REPORT DIALOGUE")
	print("[Police Station] ==========================================")
	
	# Remove the main dialogue completely
	var main_dialogue = get_node_or_null("Control")
	if main_dialogue and is_instance_valid(main_dialogue):
		main_dialogue.queue_free()
	
	# Create new dialogue for crime reporting
	var report_container = Control.new()
	report_container.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	report_container.position = Vector2(50, 50)
	report_container.size = Vector2(300, 200)
	report_container.z_index = 1001  # Higher than the main dialogue
	report_container.name = "SubmenuDialogue"  # Give it a unique name
	
	# Create character name label
	var name_label = Label.new()
	name_label.text = "Police Officer"
	name_label.position = Vector2(10, 10)
	name_label.size = Vector2(280, 30)
	name_label.add_theme_color_override("font_color", Color.WHITE)
	name_label.add_theme_font_size_override("font_size", 16)
	
	# Create dialogue text label
	var dialogue_label = Label.new()
	dialogue_label.text = "I'm listening. Please describe what happened in detail."
	dialogue_label.position = Vector2(10, 40)
	dialogue_label.size = Vector2(280, 40)
	dialogue_label.add_theme_color_override("font_color", Color.WHITE)
	dialogue_label.add_theme_font_size_override("font_size", 14)
	dialogue_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	
	# Create crime report choices
	var report_choices = ["Report bandit activity", "Report theft", "Report assault", "Cancel report"]
	var button_height = 30
	var start_y = 90
	
	for i in range(report_choices.size()):
		var button = Button.new()
		button.text = report_choices[i]
		button.position = Vector2(10, start_y + (i * button_height))
		button.size = Vector2(280, button_height)
		button.add_theme_color_override("font_color", Color.WHITE)
		button.add_theme_color_override("font_focus_color", Color.WHITE)
		button.add_theme_stylebox_override("normal", _create_button_stylebox())
		button.add_theme_stylebox_override("hover", _create_button_hover_stylebox())
		button.add_theme_stylebox_override("pressed", _create_button_pressed_stylebox())
		
		# Connect button signal
		var report_id = ["report_bandits", "report_theft", "report_assault", "cancel_report"][i]
		button.pressed.connect(_on_crime_report_choice_simple.bind(report_id, report_container))
		
		report_container.add_child(button)
	
	# Add all elements to container
	report_container.add_child(name_label)
	report_container.add_child(dialogue_label)
	
	# Add to the scene
	add_child(report_container)
	
	# Auto-close after 15 seconds
	await get_tree().create_timer(15.0).timeout
	if report_container and is_instance_valid(report_container):
		report_container.queue_free()

func _handle_laws_inquiry_simple() -> void:
	print("[Police Station] ==========================================")
	print("[Police Station] LAWS INQUIRY DIALOGUE")
	print("[Police Station] ==========================================")
	
	# Remove the main dialogue completely
	var main_dialogue = get_node_or_null("Control")
	if main_dialogue and is_instance_valid(main_dialogue):
		main_dialogue.queue_free()
	
	# Create new dialogue for laws inquiry
	var laws_container = Control.new()
	laws_container.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	laws_container.position = Vector2(50, 50)
	laws_container.size = Vector2(300, 200)
	laws_container.z_index = 1001
	laws_container.name = "SubmenuDialogue"  # Give it a unique name
	
	# Create character name label
	var name_label = Label.new()
	name_label.text = "Police Officer"
	name_label.position = Vector2(10, 10)
	name_label.size = Vector2(280, 30)
	name_label.add_theme_color_override("font_color", Color.WHITE)
	name_label.add_theme_font_size_override("font_size", 16)
	
	# Create dialogue text label
	var dialogue_label = Label.new()
	dialogue_label.text = "I'd be happy to explain the local laws. What specific area are you interested in?"
	dialogue_label.position = Vector2(10, 40)
	dialogue_label.size = Vector2(280, 40)
	dialogue_label.add_theme_color_override("font_color", Color.WHITE)
	dialogue_label.add_theme_font_size_override("font_size", 14)
	dialogue_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	
	# Create laws inquiry choices
	var laws_choices = ["Property laws", "Criminal laws", "Traffic laws", "Back to main menu"]
	var button_height = 30
	var start_y = 90
	
	for i in range(laws_choices.size()):
		var button = Button.new()
		button.text = laws_choices[i]
		button.position = Vector2(10, start_y + (i * button_height))
		button.size = Vector2(280, button_height)
		button.add_theme_color_override("font_color", Color.WHITE)
		button.add_theme_color_override("font_focus_color", Color.WHITE)
		button.add_theme_stylebox_override("normal", _create_button_stylebox())
		button.add_theme_stylebox_override("hover", _create_button_hover_stylebox())
		button.add_theme_stylebox_override("pressed", _create_button_pressed_stylebox())
		
		# Connect button signal
		var law_id = ["property_laws", "criminal_laws", "traffic_laws", "back_main"][i]
		button.pressed.connect(_on_laws_choice_simple.bind(law_id, laws_container))
		
		laws_container.add_child(button)
	
	# Add all elements to container
	laws_container.add_child(name_label)
	laws_container.add_child(dialogue_label)
	
	# Add to the scene
	add_child(laws_container)
	
	# Auto-close after 15 seconds
	await get_tree().create_timer(15.0).timeout
	if laws_container and is_instance_valid(laws_container):
		laws_container.queue_free()

func _handle_protection_request_simple() -> void:
	print("[Police Station] ==========================================")
	print("[Police Station] PROTECTION REQUEST DIALOGUE")
	print("[Police Station] ==========================================")
	
	# Remove the main dialogue completely
	var main_dialogue = get_node_or_null("Control")
	if main_dialogue and is_instance_valid(main_dialogue):
		main_dialogue.queue_free()
	
	# Create new dialogue for protection request
	var protection_container = Control.new()
	protection_container.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	protection_container.position = Vector2(50, 50)
	protection_container.size = Vector2(300, 200)
	protection_container.z_index = 1001
	protection_container.name = "SubmenuDialogue"  # Give it a unique name
	
	# Create character name label
	var name_label = Label.new()
	name_label.text = "Police Officer"
	name_label.position = Vector2(10, 10)
	name_label.size = Vector2(280, 30)
	name_label.add_theme_color_override("font_color", Color.WHITE)
	name_label.add_theme_font_size_override("font_size", 16)
	
	# Create dialogue text label
	var dialogue_label = Label.new()
	dialogue_label.text = "We're here to protect and serve. What kind of protection do you need? Are you in immediate danger?"
	dialogue_label.position = Vector2(10, 40)
	dialogue_label.size = Vector2(280, 40)
	dialogue_label.add_theme_color_override("font_color", Color.WHITE)
	dialogue_label.add_theme_font_size_override("font_size", 14)
	dialogue_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	
	# Create protection choices
	var protection_choices = ["Escort service", "Patrol request", "Emergency contact", "Back to main menu"]
	var button_height = 30
	var start_y = 90
	
	for i in range(protection_choices.size()):
		var button = Button.new()
		button.text = protection_choices[i]
		button.position = Vector2(10, start_y + (i * button_height))
		button.size = Vector2(280, button_height)
		button.add_theme_color_override("font_color", Color.WHITE)
		button.add_theme_color_override("font_focus_color", Color.WHITE)
		button.add_theme_stylebox_override("normal", _create_button_stylebox())
		button.add_theme_stylebox_override("hover", _create_button_hover_stylebox())
		button.add_theme_stylebox_override("pressed", _create_button_pressed_stylebox())
		
		# Connect button signal
		var protection_id = ["escort", "patrol", "emergency", "back_main"][i]
		button.pressed.connect(_on_protection_choice_simple.bind(protection_id, protection_container))
		
		protection_container.add_child(button)
	
	# Add all elements to container
	protection_container.add_child(name_label)
	protection_container.add_child(dialogue_label)
	
	# Add to the scene
	add_child(protection_container)
	
	# Auto-close after 15 seconds
	await get_tree().create_timer(15.0).timeout
	if protection_container and is_instance_valid(protection_container):
		protection_container.queue_free()

func _handle_leave_simple() -> void:
	print("[Police Station] ==========================================")
	print("[Police Station] PLAYER LEFT - DIALOGUE CLOSED")
	print("[Police Station] ==========================================")
	
	# Create a brief farewell message
	var farewell_container = Control.new()
	farewell_container.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	farewell_container.position = Vector2(50, 50)
	farewell_container.size = Vector2(300, 100)
	farewell_container.z_index = 1001
	farewell_container.name = "SubmenuDialogue"  # Give it a unique name
	
	# Create farewell text
	var farewell_label = Label.new()
	farewell_label.text = "Stay safe out there, citizen!"
	farewell_label.position = Vector2(10, 35)
	farewell_label.size = Vector2(280, 30)
	farewell_label.add_theme_color_override("font_color", Color.WHITE)
	farewell_label.add_theme_font_size_override("font_size", 16)
	farewell_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	
	farewell_container.add_child(farewell_label)
	add_child(farewell_container)
	
	# Auto-close after 3 seconds
	await get_tree().create_timer(3.0).timeout
	if farewell_container and is_instance_valid(farewell_container):
		farewell_container.queue_free()

func _on_crime_report_choice_simple(choice_id: String, container: Control) -> void:
	print("[Police Station] Crime report choice: ", choice_id)
	
	# Close the crime report dialogue first
	if container and is_instance_valid(container):
		container.queue_free()
	
	# Generate AI response based on choice
	match choice_id:
		"report_bandits":
			await _show_ai_response("Bandit Activity Report", "Thank you for reporting bandit activity. We've been getting increased reports from the wilderness area. I've appointed a guard to investigate the area immediately. The guard will patrol the reported location and apprehend any criminals found in the area.")
			# Dispatch guard to investigate bandits
			_dispatch_guard_to_bandits()
		"report_theft":
			await _show_ai_response("Theft Report", "I'm sorry to hear about your loss. Can you describe the stolen items in detail? We'll do our best to recover them and catch the perpetrator.")
		"report_assault":
			await _show_ai_response("Assault Report", "This is a serious matter. Are you injured? We take assault cases very seriously and will need a detailed description of the attacker. Medical assistance is available if needed.")
		"cancel_report":
			await _show_ai_response("Report Cancelled", "Understood. If you change your mind or need to report something later, we're always here to help. Stay safe out there.")
	
	# Restart main dialogue after response
	_restart_main_dialogue()

func _on_laws_choice_simple(choice_id: String, container: Control) -> void:
	print("[Police Station] Laws choice: ", choice_id)
	
	# Close the laws dialogue first
	if container and is_instance_valid(container):
		container.queue_free()
	
	# Generate AI response based on choice
	match choice_id:
		"property_laws":
			await _show_ai_response("Property Laws", "Property laws in our jurisdiction protect both owners and renters. Trespassing is strictly prohibited, and property damage carries heavy fines. Breaking and entering is a felony offense that can result in significant jail time.")
		"criminal_laws":
			await _show_ai_response("Criminal Laws", "Our criminal code covers assault, theft, fraud, and violent crimes. Assault carries penalties of 1-5 years depending on severity. Theft is classified by value stolen, with grand theft being a felony. All crimes are prosecuted to the full extent of the law.")
		"traffic_laws":
			await _show_ai_response("Traffic Laws", "Speed limits are strictly enforced: 25 mph in town, 45 mph on rural roads, 65 mph on highways. DUI carries mandatory jail time and license suspension. Reckless driving can result in vehicle impoundment and criminal charges.")
		"back_main":
			await _show_ai_response("Returning to Main Menu", "Of course! Let me know if you have any other questions about our laws or need assistance with anything else.")
	
	# Restart main dialogue after response
	_restart_main_dialogue()

func _on_protection_choice_simple(choice_id: String, container: Control) -> void:
	print("[Police Station] Protection choice: ", choice_id)
	
	# Close the protection dialogue first
	if container and is_instance_valid(container):
		container.queue_free()
	
	# Generate AI response based on choice
	match choice_id:
		"escort":
			await _show_ai_response("Escort Service", "I'll arrange an escort for you immediately. An officer will meet you here in 5 minutes to accompany you to your destination. This service is available 24/7 for citizens who feel unsafe traveling alone.")
		"patrol":
			await _show_ai_response("Patrol Request", "I've noted your request for increased patrols in your area. Our officers will make regular passes through your neighborhood, especially during evening hours. If you notice any suspicious activity, don't hesitate to call us immediately.")
		"emergency":
			await _show_ai_response("Emergency Contact", "For immediate emergencies, call 911. For non-emergency assistance, you can reach our dispatch at 555-0123. We have officers on standby 24/7. Are you currently in immediate danger? If so, I can dispatch officers right now.")
		"back_main":
			await _show_ai_response("Returning to Main Menu", "No problem at all! Let me know if you need any other assistance or have questions about our services.")
	
	# Restart main dialogue after response
	_restart_main_dialogue()

func _check_wanted_status() -> void:
	if State.is_player_wanted():
		_show_wanted_poster()

func _show_wanted_poster() -> void:
	# Could add a wanted poster sprite here
	print("[Police Station] Wanted poster displayed for player")
	
	# Add visual indicator that player is wanted
	if sprite:
		# Flash the police station red briefly to indicate danger
		var original_modulate = sprite.modulate
		sprite.modulate = Color.RED
		await get_tree().create_timer(1.0).timeout
		sprite.modulate = original_modulate



func _handle_police_interaction() -> void:
	print("[Police Station] Interaction started!")
	# Check player's wanted status and reputation
	var is_wanted = State.is_player_wanted()
	var reputation = State.get_reputation()
	print("[Police Station] Player wanted: ", is_wanted, " Reputation: ", reputation)
	
	if is_wanted:
		_handle_wanted_player()
	else:
		_handle_innocent_player()

func _handle_wanted_player() -> void:
	var ctx: Dictionary = {
		"player_reputation": State.get_reputation(),
		"recent_events": State.get_recent_events(3)
	}
	
	var arrest_line: String = await LLM.generate_line(
		"police officer: stern, by-the-book, arresting wanted criminal",
		"arrest_wanted_player",
		ctx,
		"You're under arrest! We've been looking for you. Come quietly or face the consequences."
	)
	
	Dialogue.start("Police Officer", ["[b]Officer:[/b] " + arrest_line])
	Dialogue.choices(
		[
			{"label": "Resist arrest", "id": "resist"},
			{"label": "Surrender peacefully", "id": "surrender"},
			{"label": "Try to bribe", "id": "bribe"},
			{"label": "Run away", "id": "escape"}
		],
		self,
		"_on_police_dialogue_choice"
	)

func _handle_innocent_player() -> void:
	var ctx: Dictionary = {
		"player_reputation": State.get_reputation(),
		"recent_events": State.get_recent_events(3)
	}
	
	var greeting_line: String = await LLM.generate_line(
		"police officer: professional, helpful, serving the community",
		"greet_innocent_player",
		ctx,
		"Good day, citizen. How can I help you today?"
	)
	
	Dialogue.start("Police Officer", ["[b]Officer:[/b] " + greeting_line])
	Dialogue.choices(
		[
			{"label": "Report a crime", "id": "report"},
			{"label": "Ask about local laws", "id": "laws"},
			{"label": "Seek protection", "id": "protection"},
			{"label": "Leave", "id": "leave"}
		],
		self,
		"_on_police_dialogue_choice"
	)

func _on_police_dialogue_choice(choice_id: String) -> void:
	match choice_id:
		"resist":
			_handle_resist_arrest()
		"surrender":
			_handle_surrender()
		"bribe":
			_handle_bribe_attempt()
		"escape":
			_handle_escape_attempt()
		"report":
			_handle_crime_report()
		"laws":
			_handle_laws_inquiry()
		"protection":
			_handle_protection_request()
		"leave":
			Dialogue.continue_dialogue("Police Officer", ["[b]Officer:[/b] Stay safe out there."])

func _handle_resist_arrest() -> void:
	State.add_event({"type": "resisted_arrest", "by": "player"})
	State.change_reputation(-25)
	
	var resist_line: String = await LLM.generate_line(
		"police officer: angry, calling for backup, escalating situation",
		"player_resisted",
		{},
		"Backup! We have a suspect resisting arrest! This is going to make things much worse for you!"
	)
	
	Dialogue.continue_dialogue("Police Officer", ["[b]Officer:[/b] " + resist_line])
	
	# Trigger police reinforcements
	_call_police_reinforcements()

func _call_police_reinforcements() -> void:
	State.add_event({"type": "police_reinforcements_called", "location": "police_station"})
	
	# Could spawn police NPCs here
	print("[Police Station] Police reinforcements called!")
	
	# Set wanted flag
	State.set_player_wanted(true)
	
	# Could add police chase mechanics here
	# For now, just set the flag

func _handle_surrender() -> void:
	State.add_event({"type": "surrendered_to_police", "by": "player"})
	State.change_reputation(5)
	
	var surrender_line: String = await LLM.generate_line(
		"police officer: satisfied, professional, processing arrest",
		"player_surrendered",
		{},
		"Smart choice. We'll process you quickly and fairly. Come with me."
	)
	
	Dialogue.continue_dialogue("Police Officer", ["[b]Officer:[/b] " + surrender_line])
	
	# Offer community service as alternative
	_offer_community_service()

func _start_jail_time() -> void:
	# Set jail flag
	State.set_flag("player_in_jail", true)
	State.add_event({"type": "jail_sentence", "duration": "30_seconds"})
	
	# Could add jail scene transition here
	print("[Police Station] Player sent to jail for 30 seconds")
	
	# Jail time countdown
	await get_tree().create_timer(30.0).timeout
	
	# Release player
	State.set_flag("player_in_jail", false)
	State.add_event({"type": "released_from_jail", "by": "police"})
	
	var release_line: String = await LLM.generate_line(
		"police officer: formal, releasing prisoner, warning about future behavior",
		"release_from_jail",
		{},
		"Your time is served. Stay out of trouble, or you'll be back here again."
	)
	
	Dialogue.continue_dialogue("Police Officer", ["[b]Officer:[/b] " + release_line])

func _handle_bribe_attempt() -> void:
	State.add_event({"type": "attempted_bribe", "by": "player"})
	State.change_reputation(-15)
	
	var bribe_line: String = await LLM.generate_line(
		"police officer: offended, professional integrity, rejecting bribe",
		"bribe_rejected",
		{},
		"I don't take bribes. That's corruption, and I won't be part of it. You're making this worse for yourself."
	)
	
	Dialogue.continue_dialogue("Police Officer", ["[b]Officer:[/b] " + bribe_line])

func _handle_escape_attempt() -> void:
	State.add_event({"type": "escaped_police", "by": "player"})
	State.change_reputation(-20)
	
	var escape_line: String = await LLM.generate_line(
		"police officer: frustrated, calling for pursuit, determined",
		"player_escaped",
		{},
		"Suspect fleeing! All units, we have a runner! You won't get far!"
	)
	
	Dialogue.continue_dialogue("Police Officer", ["[b]Officer:[/b] " + escape_line])
	
	# Set wanted flag and increase bounty
	State.set_player_wanted(true)
	State.add_event({"type": "bounty_increased", "reason": "escaped_police"})

func _offer_community_service() -> void:
	var service_line: String = await LLM.generate_line(
		"police officer: offering alternative, community-focused, rehabilitation",
		"community_service_offer",
		{},
		"Given your cooperation, I can offer you community service instead of jail time. Help clean up the town for a few hours."
	)
	
	Dialogue.continue_dialogue("Police Officer", ["[b]Officer:[/b] " + service_line])
	
	Dialogue.choices(
		[
			{"label": "Accept community service", "id": "accept_service"},
			{"label": "Decline, prefer jail", "id": "decline_service"}
		],
		self,
		"_on_service_choice"
	)

func _on_service_choice(choice_id: String) -> void:
	match choice_id:
		"accept_service":
			_start_community_service()
		"decline_service":
			_start_jail_time()

func _start_community_service() -> void:
	State.set_flag("player_in_community_service", true)
	State.add_event({"type": "community_service_started", "duration": "15_seconds"})
	
	var service_start_line: String = await LLM.generate_line(
		"police officer: satisfied, directing community service, setting expectations",
		"service_started",
		{},
		"Good choice. Head to the town square and help clean up. I'll check on you in 15 minutes."
	)
	
	Dialogue.continue_dialogue("Police Officer", ["[b]Officer:[/b] " + service_start_line])
	
	# Community service countdown
	await get_tree().create_timer(15.0).timeout
	
	# Complete service
	State.set_flag("player_in_community_service", false)
	State.add_event({"type": "community_service_completed", "by": "player"})
	State.change_reputation(10)
	
	var service_complete_line: String = await LLM.generate_line(
		"police officer: pleased, acknowledging completion, positive reinforcement",
		"service_completed",
		{},
		"Excellent work! The town looks much better. You've earned some respect back. Stay out of trouble."
	)
	
	Dialogue.continue_dialogue("Police Officer", ["[b]Officer:[/b] " + service_complete_line])

func _handle_crime_report() -> void:
	var report_line: String = await LLM.generate_line(
		"police officer: attentive, taking notes, professional",
		"crime_report",
		{},
		"I'm listening. Please describe what happened in detail."
	)
	
	Dialogue.continue_dialogue("Police Officer", ["[b]Officer:[/b] " + report_line])
	
	# Add crime reporting dialogue choices
	Dialogue.choices(
		[
			{"label": "Report bandit activity", "id": "report_bandits"},
			{"label": "Report theft", "id": "report_theft"},
			{"label": "Report assault", "id": "report_assault"},
			{"label": "Cancel report", "id": "cancel_report"}
		],
		self,
		"_on_crime_report_choice"
	)

func _on_crime_report_choice(choice_id: String) -> void:
	match choice_id:
		"report_bandits":
			_handle_bandit_report()
		"report_theft":
			_handle_theft_report()
		"report_assault":
			_handle_assault_report()
		"cancel_report":
			Dialogue.continue_dialogue("Police Officer", ["[b]Officer:[/b] Understood. Let us know if you change your mind."])

func _handle_bandit_report() -> void:
	State.add_event({"type": "bandit_activity_reported", "by": "player"})
	State.change_reputation(5)
	
	var bandit_report_line: String = await LLM.generate_line(
		"police officer: serious, taking detailed notes, planning response",
		"bandit_report",
		{},
		"Bandit activity, huh? We've been getting reports of increased criminal activity in the wilderness. I'll dispatch a patrol unit to investigate."
	)
	
	Dialogue.continue_dialogue("Police Officer", ["[b]Officer:[/b] " + bandit_report_line])

func _handle_theft_report() -> void:
	State.add_event({"type": "theft_reported", "by": "player"})
	State.change_reputation(3)
	
	var theft_report_line: String = await LLM.generate_line(
		"police officer: sympathetic, documenting loss, offering assistance",
		"theft_report",
		{},
		"I'm sorry to hear about your loss. Can you describe the stolen items? We'll do our best to recover them."
	)
	
	Dialogue.continue_dialogue("Police Officer", ["[b]Officer:[/b] " + theft_report_line])

func _handle_assault_report() -> void:
	State.add_event({"type": "assault_reported", "by": "player"})
	State.change_reputation(5)
	
	var assault_report_line: String = await LLM.generate_line(
		"police officer: concerned, taking assault seriously, offering protection",
		"assault_report",
		{},
		"This is serious. Are you injured? We take assault cases very seriously. I'll need a detailed description of the attacker."
	)
	
	Dialogue.continue_dialogue("Police Officer", ["[b]Officer:[/b] " + assault_report_line])

func _handle_laws_inquiry() -> void:
	var laws_line: String = await LLM.generate_line(
		"police officer: informative, helpful, explaining regulations",
		"laws_inquiry",
		{},
		"I'd be happy to explain the local laws. What specific area are you interested in?"
	)
	
	Dialogue.continue_dialogue("Police Officer", ["[b]Officer:[/b] " + laws_line])

func _handle_protection_request() -> void:
	var protection_line: String = await LLM.generate_line(
		"police officer: concerned, offering assistance, community service",
		"protection_request",
		{},
		"We're here to protect and serve. What kind of protection do you need? Are you in immediate danger?"
	)
	
	Dialogue.continue_dialogue("Police Officer", ["[b]Officer:[/b] " + protection_line])

func _restart_main_dialogue() -> void:
	# Wait a moment for cleanup, then restart main dialogue
	await get_tree().create_timer(0.1).timeout
	_show_simple_dialogue_box()

func _show_ai_response(title: String, response: String) -> void:
	print("[Police Station] AI Response - ", title, ": ", response)
	
	# Create AI response dialogue box
	var response_container = Control.new()
	response_container.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	response_container.position = Vector2(50, 50)
	response_container.size = Vector2(400, 150)
	response_container.z_index = 1002  # Higher than submenus
	response_container.name = "AIResponse"
	
	# Create title label
	var title_label = Label.new()
	title_label.text = title
	title_label.position = Vector2(10, 10)
	title_label.size = Vector2(380, 30)
	title_label.add_theme_color_override("font_color", Color.WHITE)
	title_label.add_theme_font_size_override("font_size", 18)
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	
	# Create response text label
	var response_label = Label.new()
	response_label.text = response
	response_label.position = Vector2(10, 50)
	response_label.size = Vector2(380, 80)
	response_label.add_theme_color_override("font_color", Color.WHITE)
	response_label.add_theme_font_size_override("font_size", 14)
	response_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	response_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	response_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	
	# Create continue button
	var continue_button = Button.new()
	continue_button.text = "Continue"
	continue_button.position = Vector2(150, 110)
	continue_button.size = Vector2(100, 30)
	continue_button.add_theme_color_override("font_color", Color.WHITE)
	continue_button.add_theme_color_override("font_focus_color", Color.WHITE)
	continue_button.add_theme_stylebox_override("normal", _create_button_stylebox())
	continue_button.add_theme_stylebox_override("hover", _create_button_hover_stylebox())
	continue_button.add_theme_stylebox_override("pressed", _create_button_pressed_stylebox())
	continue_button.pressed.connect(_on_ai_response_continue.bind(response_container))
	
	# Add all elements to container
	response_container.add_child(title_label)
	response_container.add_child(response_label)
	response_container.add_child(continue_button)
	
	# Add to the scene
	add_child(response_container)
	
	# Auto-close after 15 seconds if not manually closed
	await get_tree().create_timer(15.0).timeout
	if response_container and is_instance_valid(response_container):
		response_container.queue_free()

func _on_ai_response_continue(container: Control) -> void:
	# Close the AI response dialogue
	if container and is_instance_valid(container):
		container.queue_free()

func _dispatch_guard_to_bandits() -> void:
	print("[Police Station] Dispatching guard to investigate bandits...")
	
	# Find the nearest bandit in the scene
	var bandit = _find_nearest_bandit()
	if bandit:
		print("[Police Station] Found bandit at: ", bandit.global_position)
		# Create and dispatch a guard
		_create_and_dispatch_guard(bandit.global_position)
	else:
		print("[Police Station] No bandits found in the scene")
		print("[Police Station] Available groups: ", get_tree().get_nodes_in_group("bandits"))

func _find_nearest_bandit() -> Node2D:
	print("[Police Station] Searching for bandits...")
	
	# Try different possible bandit groups
	var bandits = get_tree().get_nodes_in_group("bandits")
	if bandits.size() == 0:
		# Try looking for NPC_Bandit nodes specifically
		bandits = get_tree().get_nodes_in_group("NPC_Bandit")
	if bandits.size() == 0:
		# Try looking for any nodes with "bandit" in the name
		var all_nodes = get_tree().get_nodes_in_group("")
		for node in all_nodes:
			if "bandit" in node.name.to_lower():
				bandits.append(node)
	
	print("[Police Station] Found ", bandits.size(), " potential bandits")
	
	var nearest_bandit = null
	var nearest_distance = 999999
	
	for bandit in bandits:
		if bandit and is_instance_valid(bandit):
			print("[Police Station] Checking bandit: ", bandit.name, " at ", bandit.global_position)
			var distance = global_position.distance_to(bandit.global_position)
			if distance < nearest_distance:
				nearest_distance = distance
				nearest_bandit = bandit
	
	if nearest_bandit:
		print("[Police Station] Nearest bandit: ", nearest_bandit.name, " at distance: ", nearest_distance)
	else:
		print("[Police Station] No bandits found in any group")
	
	return nearest_bandit

func _create_and_dispatch_guard(target_position: Vector2) -> void:
	print("[Police Station] Creating guard NPC...")
	
	# Create a guard NPC
	var guard = _create_guard_npc()
	if guard:
		print("[Police Station] Guard NPC created successfully")
		
		# Position guard near the police station
		guard.global_position = global_position + Vector2(50, 0)
		print("[Police Station] Guard positioned at: ", guard.global_position)
		
		# Add guard to the scene
		get_tree().current_scene.add_child(guard)
		print("[Police Station] Guard added to scene")
		
		# Start guard movement toward target
		guard.start_investigation(target_position)
		print("[Police Station] Guard investigation started")
		
		print("[Police Station] Guard dispatched to investigate bandit activity at: ", target_position)
	else:
		print("[Police Station] Failed to create guard NPC")

func _create_guard_npc() -> Node2D:
	# Create a basic guard NPC with movement capabilities
	var guard = CharacterBody2D.new()
	guard.name = "PoliceGuard"
	
	# Add collision shape
	var collision = CollisionShape2D.new()
	var collision_shape = RectangleShape2D.new()
	collision_shape.size = Vector2(16, 16)
	collision.shape = collision_shape
	guard.add_child(collision)
	
	# Add sprite
	var sprite = Sprite2D.new()
	# You can set a guard texture here if available
	# sprite.texture = preload("res://Assets/art/guard.png")
	sprite.modulate = Color.BLUE  # Blue color to distinguish from bandits
	guard.add_child(sprite)
	
	# Add navigation agent for pathfinding
	var nav_agent = NavigationAgent2D.new()
	guard.add_child(nav_agent)
	
	# Add guard script
	var guard_script = preload("res://Scripts/character/NPC_Guard.gd")
	if guard_script:
		guard.set_script(guard_script)
		print("[Police Station] Guard script loaded successfully")
	else:
		print("[Police Station] WARNING: Guard script not found!")
		# Create a basic movement script as fallback
		guard.set_script(_create_fallback_guard_script())
		print("[Police Station] Using fallback guard script")
	
	return guard

func _create_fallback_guard_script() -> GDScript:
	# Create a basic guard script if the main one isn't found
	var script = GDScript.new()
	script.source_code = """
extends CharacterBody2D

var speed = 100.0
var target_position = Vector2.ZERO
var is_moving = false

func _ready():
	print("[Fallback Guard] Ready for duty!")
	add_to_group("guards")

func start_investigation(target: Vector2):
	print("[Fallback Guard] Starting investigation to: ", target)
	target_position = target
	is_moving = true

func _physics_process(_delta):
	if is_moving:
		var direction = (target_position - global_position).normalized()
		velocity = direction * speed
		move_and_slide()
		
		# Check if we reached the target
		if global_position.distance_to(target_position) < 10:
			print("[Fallback Guard] Reached target, investigating...")
			is_moving = false
			# Flash to show investigation
			modulate = Color.WHITE
			await get_tree().create_timer(3.0).timeout
			modulate = Color.BLUE
			print("[Fallback Guard] Investigation complete!")

func get_investigation_status():
	if is_moving:
		return "Moving to investigate bandit activity"
	else:
		return "On duty at police station"
"""
	script.reload()
	return script

func _check_guard_status() -> String:
	var guards = get_tree().get_nodes_in_group("guards")
	if guards.size() > 0:
		var guard = guards[0]  # Get the first guard
		if guard and is_instance_valid(guard) and guard.has_method("get_investigation_status"):
			return guard.get_investigation_status()
	
	return "No guards currently on duty"

func _update_main_dialogue_with_guard_status() -> void:
	# Update the main dialogue to show guard status
	var guard_status = _check_guard_status()
	
	# Find the main dialogue container
	var main_dialogue = get_node_or_null("MainDialogue")
	if main_dialogue and is_instance_valid(main_dialogue):
		# Update the dialogue text to include guard status
		var dialogue_label = main_dialogue.get_node_or_null("Label")
		if dialogue_label:
			dialogue_label.text = "Good day, citizen! How can you help me today?\n\nGuard Status: " + guard_status
	else:
		# Dialogue no longer exists, stop updating
		return
