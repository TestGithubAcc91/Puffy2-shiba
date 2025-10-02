extends Control
@onready var input_button_scene = preload("res://Scenes/input_button.tscn")
@onready var action_list = $PanelContainer/MarginContainer/VBoxContainer/ScrollContainer/ActionList

const KEYBINDINGS_SAVE_PATH = "user://keybindings.save"

var is_remapping = false
var action_to_remap = null
var remapping_button = null

var input_actions = {
	"Jump": "Jump",
	"Move_Left": "Move Left",
	"Move_Right": "Move Right",
	"Parry": "Parry",
	"HighJump": "High Jump",
	"Dash": "Dash",
}

func _ready():
	load_keybindings()
	create_action_list()

func create_action_list():
	for item in action_list.get_children():
		item.queue_free()
	
	for action in input_actions:
		var button = input_button_scene.instantiate()
		var action_label = button.find_child("LabelAction")
		var input_label = button.find_child("LabelInput")
		
		action_label.text = input_actions[action]  # Uses the friendly name from dictionary
		
		var events = InputMap.action_get_events(action)
		if events.size() > 0:
			input_label.text = events[0].as_text().trim_suffix(" (Physical)")
		else:
			input_label.text = ""
		
		action_list.add_child(button)
		button.pressed.connect(_on_input_button_pressed.bind(button, action))

func _on_input_button_pressed(button, action):
	if !is_remapping:
		is_remapping = true
		action_to_remap = action
		remapping_button = button
		button.find_child("LabelInput").text = "Press key to bind!"

func _input(event):
	if is_remapping:
		if (event is InputEventKey || (event is InputEventMouseButton && event.pressed)):
			if event is InputEventMouseButton && event.double_click:
				event.double_click = false
			
			InputMap.action_erase_events(action_to_remap)
			InputMap.action_add_event(action_to_remap, event)
			update_action_list(remapping_button, event)
			
			is_remapping = false
			action_to_remap = null
			remapping_button = null
			
			# Save the new keybindings
			save_keybindings()
			
			accept_event()

func update_action_list(button, event):
	button.find_child("LabelInput").text = event.as_text().trim_suffix(" (Physical)")

func _on_reset_button_pressed():
	# Reset to default project settings
	InputMap.load_from_project_settings()
	create_action_list()
	# Save the reset keybindings
	save_keybindings()

func save_keybindings():
	var file = FileAccess.open(KEYBINDINGS_SAVE_PATH, FileAccess.WRITE)
	if file == null:
		print("Error: Could not save keybindings")
		return
	
	var keybindings_data = {}
	
	for action in input_actions.keys():
		var events = InputMap.action_get_events(action)
		var events_array = []
		
		for event in events:
			var event_data = {}
			if event is InputEventKey:
				event_data["type"] = "key"
				event_data["keycode"] = event.keycode
				event_data["physical_keycode"] = event.physical_keycode
				event_data["pressed"] = event.pressed
			elif event is InputEventMouseButton:
				event_data["type"] = "mouse_button"
				event_data["button_index"] = event.button_index
				event_data["pressed"] = event.pressed
			
			events_array.append(event_data)
		
		keybindings_data[action] = events_array
	
	file.store_var(keybindings_data)
	file.close()
	print("Keybindings saved successfully")

func load_keybindings():
	if not FileAccess.file_exists(KEYBINDINGS_SAVE_PATH):
		print("No saved keybindings found, using defaults")
		return
	
	var file = FileAccess.open(KEYBINDINGS_SAVE_PATH, FileAccess.READ)
	if file == null:
		print("Error: Could not load keybindings")
		return
	
	var keybindings_data = file.get_var()
	file.close()
	
	if typeof(keybindings_data) != TYPE_DICTIONARY:
		print("Invalid keybindings data")
		return
	
	# Apply loaded keybindings
	for action in keybindings_data.keys():
		if InputMap.has_action(action):
			InputMap.action_erase_events(action)
			
			for event_data in keybindings_data[action]:
				var event = null
				
				if event_data["type"] == "key":
					event = InputEventKey.new()
					event.keycode = event_data["keycode"]
					event.physical_keycode = event_data["physical_keycode"]
					event.pressed = event_data["pressed"]
				elif event_data["type"] == "mouse_button":
					event = InputEventMouseButton.new()
					event.button_index = event_data["button_index"]
					event.pressed = event_data["pressed"]
				
				if event != null:
					InputMap.action_add_event(action, event)
	
	print("Keybindings loaded successfully")
