# Game.gd
extends Node

@onready var level_select_menu = $LevelSelectMenu
@onready var black_curtain = $BlackCurtain
var current_level_scene = null
var input_blocked = false

# Signal to communicate with player
signal movement_enabled
signal movement_disabled

# Countdown color settings (editable in inspector)
@export_group("Countdown Colors")
@export var ready_color: Color = Color.RED
@export var set_color: Color = Color.YELLOW
@export var go_color: Color = Color.GREEN

func _ready():
	level_select_menu.level_selected.connect(_on_level_selected)
	# Make sure the black curtain starts off-screen to the right
	if black_curtain:
		black_curtain.position.x = get_viewport().size.x

func _input(event):
	# Block all input when input_blocked is true
	if input_blocked:
		get_viewport().set_input_as_handled()

func _on_level_selected(level_number):
	# Start the curtain transition
	_start_curtain_transition(level_number)

func _start_curtain_transition(level_number):
	if not black_curtain:
		print("BlackCurtain node not found!")
		_load_level_directly(level_number)
		return
	
	# Create a tween to move the curtain
	var tween = create_tween()
	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_CUBIC)
	
	# Move curtain from right to cover the screen and beyond (moving left) - slower movement
	var viewport_width = get_viewport().size.x
	tween.tween_property(black_curtain, "position:x", -viewport_width, 2.5)
	
	# Wait 1 second after button press (while curtain is moving and covering screen)
	await get_tree().create_timer(1).timeout
	
	# Change the scene while view is covered by curtain
	_change_to_level(level_number)

func _change_to_level(level_number):
	# Remove current level if exists
	if current_level_scene:
		current_level_scene.queue_free()
	
	# Disable the level select menu's camera
	if level_select_menu.has_node("Camera2D"):
		level_select_menu.get_node("Camera2D").enabled = false
	
	# Hide menu
	level_select_menu.visible = false
	
	# Load the selected level
	match level_number:
		1:
			current_level_scene = preload("res://Scenes/level_1_holder.tscn").instantiate()
			add_child(current_level_scene)
			
			# Wait one frame for the scene to be properly added to the tree
			await get_tree().process_frame
			
			# Connect to player BEFORE starting countdown
			var player = find_player_in_scene()
			if player:
				# Connect the signals to the player's methods
				if not movement_disabled.is_connected(player._on_movement_disabled):
					movement_disabled.connect(player._on_movement_disabled)
				if not movement_enabled.is_connected(player._on_movement_enabled):
					movement_enabled.connect(player._on_movement_enabled)
				print("Player signals connected successfully")
			else:
				print("WARNING: Player not found - movement blocking may not work!")
			
			# Start countdown after player connection is established
			_start_countdown()
		
		# Add more levels as needed

func _start_countdown():
	# Block input during countdown
	input_blocked = true
	movement_disabled.emit()  # Tell player to stop accepting movement
	print("Movement disabled signal emitted")
	
	# Get the countdown label
	var countdown_label = null
	if current_level_scene and current_level_scene.has_node("UI/StartCountdown"):
		countdown_label = current_level_scene.get_node("UI/StartCountdown")
	else:
		print("StartCountdown label not found!")
		input_blocked = false
		movement_enabled.emit()  # Re-enable movement if countdown fails
		return
	
	# Make sure the label is visible
	countdown_label.visible = true
	
	# Countdown sequence
	countdown_label.text = "READY?"
	countdown_label.modulate = ready_color
	await get_tree().create_timer(1.0).timeout
	
	countdown_label.text = "SET..."
	countdown_label.modulate = set_color
	await get_tree().create_timer(1.0).timeout
	
	countdown_label.text = "GO!!"
	countdown_label.modulate = go_color
	await get_tree().create_timer(0.5).timeout
	
	# Hide the countdown label
	countdown_label.visible = false
	
	# Unblock input
	input_blocked = false
	movement_enabled.emit()  # Tell player movement is now allowed
	print("Movement enabled signal emitted")
	
	print("Countdown complete - input enabled!")

func find_player_in_scene() -> Node:
	# Look for player node in the current level scene
	if current_level_scene:
		# Try common player node paths
		var possible_paths = ["Player", "Player2D", "CharacterBody2D"]
		for path in possible_paths:
			if current_level_scene.has_node(path):
				var found_player = current_level_scene.get_node(path)
				print("Player found at path: ", path)
				return found_player
		
		# Fallback: search for any CharacterBody2D node (assuming that's your player)
		var nodes = current_level_scene.find_children("*", "CharacterBody2D", true, false)
		if nodes.size() > 0:
			print("Player found via CharacterBody2D search: ", nodes[0].name)
			return nodes[0]  # Return first CharacterBody2D found
	
	print("No player found in scene!")
	return null

func _load_level_directly(level_number):
	# Fallback function if BlackCurtain is not available
	_change_to_level(level_number)

func return_to_menu():
	# Reset input blocking when returning to menu
	input_blocked = false
	movement_enabled.emit()  # Make sure movement is enabled when returning to menu
	
	# Move curtain back off-screen when returning to menu
	if black_curtain:
		var tween = create_tween()
		tween.set_ease(Tween.EASE_IN)
		tween.set_trans(Tween.TRANS_CUBIC)
		tween.tween_property(black_curtain, "position:x", get_viewport().size.x, 0.8)
	
	if current_level_scene:
		current_level_scene.queue_free()
		current_level_scene = null
	
	# Re-enable the level select menu's camera
	if level_select_menu.has_node("Camera2D"):
		level_select_menu.get_node("Camera2D").enabled = true
	
	level_select_menu.visible = true
