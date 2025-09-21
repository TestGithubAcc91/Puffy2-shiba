# Game.gd
extends Node

@onready var level_select_menu = $LevelSelectMenu
# Updated reference to BlackCurtain under LevelSelectMenu's Camera2D
@onready var black_curtain = $LevelSelectMenu/Camera2D/BlackCurtain
var current_level_scene = null
var input_blocked = false
var current_level_number = 0  # NEW: Track current level for retry functionality

# Timer variables
var timer_running = false
var elapsed_time = 0.0
var timer_label = null

# Tracking variables
var damage_count = 0
var parry_count = 0  # Track successful parries
var glits_count = 0  # NEW: Track collected coins/glits

# Signal to communicate with player
signal movement_enabled
signal movement_disabled

# Countdown color settings (editable in inspector)
@export_group("Countdown Colors")
@export var ready_color: Color = Color.RED
@export var set_color: Color = Color.YELLOW
@export var go_color: Color = Color.GREEN

# Medal system settings (editable in inspector)
@export_group("Medal System")
@export var gold_time_threshold: float = 45.0
@export var silver_time_threshold: float = 50.0
@export var gold_medal_texture: Texture2D
@export var silver_medal_texture: Texture2D
@export var bronze_medal_texture: Texture2D

func _ready():
	level_select_menu.level_selected.connect(_on_level_selected)
	# Make sure the black curtain starts off-screen to the right
	if black_curtain:
		var menu_camera = level_select_menu.get_node("Camera2D")
		if menu_camera:
			# Position curtain relative to the camera's view
			black_curtain.position.x = get_viewport().size.x
		else:
			print("WARNING: Menu Camera2D not found!")

func _process(delta):
	# Update timer if running
	if timer_running and timer_label:
		elapsed_time += delta
		_update_timer_display()

func _input(event):
	# Block all input when input_blocked is true
	if input_blocked:
		get_viewport().set_input_as_handled()

func _on_level_selected(level_number):
	# Start the curtain transition
	_start_curtain_transition(level_number)

func _start_curtain_transition(level_number):
	if not black_curtain:
		print("BlackCurtain node not found under LevelSelectMenu/Camera2D!")
		_load_level_directly(level_number)
		return
	
	# Make sure the menu camera is enabled for the transition
	var menu_camera = level_select_menu.get_node("Camera2D")
	if menu_camera:
		menu_camera.enabled = true
		# Make sure the curtain is positioned correctly for the transition
		black_curtain.position.x = get_viewport().size.x
	
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
	# Store current level number for retry functionality
	current_level_number = level_number
	
	# Reset pause state and input blocking before loading new level (no more time_scale)
	get_tree().paused = false
	input_blocked = false
	
	# Remove current level if exists
	if current_level_scene:
		current_level_scene.queue_free()
		current_level_scene = null
		# Wait one frame for the old scene to be fully removed
		await get_tree().process_frame
	
	# Keep the menu camera enabled temporarily to maintain curtain visibility
	var menu_camera = level_select_menu.get_node("Camera2D")
	if menu_camera:
		menu_camera.enabled = true
	
	# Hide menu but keep camera active for curtain
	level_select_menu.visible = false
	
	# Load the selected level
	match level_number:
		1:
			current_level_scene = preload("res://Scenes/level_1_holder.tscn").instantiate()
			add_child(current_level_scene)
			
			# Wait one frame for the scene to be properly added to the tree
			await get_tree().process_frame
			
			# Now switch cameras - disable menu camera and enable player camera
			_switch_to_player_camera()
			
			# Connect to player BEFORE starting countdown
			var player = find_player_in_scene()
			if player:
				# Connect the signals to the player's methods
				if not movement_disabled.is_connected(player._on_movement_disabled):
					movement_disabled.connect(player._on_movement_disabled)
				if not movement_enabled.is_connected(player._on_movement_enabled):
					movement_enabled.connect(player._on_movement_enabled)
				print("Player signals connected successfully")
				
				# Connect to player's health script for damage tracking
				_connect_damage_tracking(player)
				
				# Connect to player for parry tracking
				_connect_parry_tracking(player)
				
				# Connect to coin system for glits tracking
				_connect_glits_tracking()
			else:
				print("WARNING: Player not found - movement blocking may not work!")
			
			# Connect to level finish area
			_connect_level_finish()
			
			# Connect to retry button
			_connect_retry_button()
			
			# Setup timer reference
			_setup_timer()
			
			# Start countdown after player connection is established
			_start_countdown()
		
		# Add more levels as needed

func _switch_to_player_camera():
	"""
	Switch from menu camera to player camera while maintaining BlackCurtain visibility
	"""
	var menu_camera = level_select_menu.get_node("Camera2D")
	var player = find_player_in_scene()
	
	if not player:
		print("WARNING: Cannot switch to player camera - player not found!")
		return
	
	# Find the player's camera
	var player_camera = null
	if player.has_node("Camera2D"):
		player_camera = player.get_node("Camera2D")
	else:
		# Search for camera in player's children
		var cameras = player.find_children("*", "Camera2D", true, false)
		if cameras.size() > 0:
			player_camera = cameras[0]
	
	if not player_camera:
		print("WARNING: Player camera not found!")
		return
	
	# Reparent the BlackCurtain to the player's camera to maintain visibility
	if black_curtain and player_camera:
		# Store current global position
		var curtain_global_pos = black_curtain.global_position
		
		# Reparent curtain to player camera
		black_curtain.reparent(player_camera)
		
		# Restore position relative to the new parent camera
		black_curtain.global_position = curtain_global_pos
		
		print("BlackCurtain reparented to player camera successfully")
	
	# Now switch the cameras
	if menu_camera:
		menu_camera.enabled = false
	if player_camera:
		player_camera.enabled = true
		player_camera.make_current()
	
	print("Switched to player camera")

func _connect_level_finish():
	# Find and connect to the LevelFinish area
	if current_level_scene and current_level_scene.has_node("LevelFinish"):
		var level_finish = current_level_scene.get_node("LevelFinish")
		if level_finish is Area2D:
			# Connect the body_entered signal
			if not level_finish.body_entered.is_connected(_on_level_finish_entered):
				level_finish.body_entered.connect(_on_level_finish_entered)
				print("LevelFinish area connected successfully")
		else:
			print("WARNING: LevelFinish node is not an Area2D!")
	else:
		print("WARNING: LevelFinish node not found!")

func _connect_retry_button():
	# Find and connect to the RetryButton
	if current_level_scene and current_level_scene.has_node("UI/FinishResults/RetryButton"):
		var retry_button = current_level_scene.get_node("UI/FinishResults/RetryButton")
		if retry_button is TextureButton:
			# Connect the pressed signal
			if not retry_button.pressed.is_connected(_on_retry_button_pressed):
				retry_button.pressed.connect(_on_retry_button_pressed)
				print("RetryButton (TextureButton) connected successfully")
		else:
			print("WARNING: RetryButton node is not a TextureButton!")
	else:
		print("WARNING: RetryButton not found at UI/FinishResults/RetryButton!")

func _on_retry_button_pressed():
	print("Retry button pressed! Starting curtain transition for level restart...")
	
	# Start the curtain transition for retry using player's camera curtain
	_start_retry_curtain_transition()

func _start_retry_curtain_transition():
	"""
	Start curtain transition specifically for retry functionality using the player's existing BlackCurtain
	"""
	# First, unpause the game so transitions can work
	get_tree().paused = false
	
	var player = find_player_in_scene()
	if not player:
		print("Player not found! Restarting level directly...")
		_restart_level_directly()
		return
	
	# Find player's camera and their existing BlackCurtain
	var player_camera = null
	var player_curtain = null
	
	if player.has_node("Camera2D"):
		player_camera = player.get_node("Camera2D")
		if player_camera.has_node("BlackCurtain"):
			player_curtain = player_camera.get_node("BlackCurtain")
	else:
		var cameras = player.find_children("*", "Camera2D", true, false)
		if cameras.size() > 0:
			player_camera = cameras[0]
			if player_camera.has_node("BlackCurtain"):
				player_curtain = player_camera.get_node("BlackCurtain")
	
	if not player_curtain:
		print("Player's BlackCurtain not found! Restarting level directly...")
		_restart_level_directly()
		return
	
	# Block input during transition
	input_blocked = true
	movement_disabled.emit()
	
	print("Starting retry curtain transition with player's existing BlackCurtain")
	
	# Duplicate the existing BlackCurtain and move it to a CanvasLayer so it survives scene reload
	var temp_curtain = player_curtain.duplicate()
	
	# Create a CanvasLayer to ensure the curtain survives the scene reload
	var canvas_layer = CanvasLayer.new()
	canvas_layer.layer = 100  # High layer to be on top of everything
	add_child(canvas_layer)
	
	# Add the duplicated curtain to the canvas layer
	canvas_layer.add_child(temp_curtain)
	
	# Position the curtain off-screen to the right (it's already properly scaled)
	temp_curtain.position.x = get_viewport().size.x
	temp_curtain.position.y = 0
	
	print("BlackCurtain duplicated and positioned at: ", temp_curtain.position)
	
	# Create a tween to move the curtain across the screen
	var tween = create_tween()
	tween.set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_CUBIC)
	
	# Move curtain from right to cover the screen and beyond (moving left)
	var viewport_width = get_viewport().size.x
	var target_x = -viewport_width
	print("Animating BlackCurtain from ", temp_curtain.position.x, " to ", target_x)
	
	tween.tween_property(temp_curtain, "position:x", target_x, 2.5)  # Match original curtain speed
	
	# Wait for curtain to cover the screen before reloading
	await get_tree().create_timer(1.0).timeout  # Adjusted timing to match original
	
	# Restart the level while view is covered by curtain
	_restart_level_after_curtain()
	
	# Wait for the new level to fully load and start, then let curtain finish
	await get_tree().create_timer(1.5).timeout  # Let curtain complete its animation
	
	# Remove the temporary curtain and canvas layer after the transition is complete
	if canvas_layer and is_instance_valid(canvas_layer):
		canvas_layer.queue_free()
		print("BlackCurtain transition completed and cleaned up")

func _restart_level_after_curtain():
	"""
	Restart the level after the curtain has covered the screen
	"""
	print("Restarting level ", current_level_number, " after curtain transition...")
	
	# Reset pause state before restarting (no more time_scale manipulation)
	get_tree().paused = false
	input_blocked = false
	
	# Use the same level generation process as the main menu
	# This will completely regenerate the level instead of trying to reset it
	_change_to_level(current_level_number)

func _restart_level_directly():
	"""
	Fallback method to restart level without curtain effect
	"""
	print("Restarting level directly without curtain effect...")
	
	# Reset pause state (no more time_scale manipulation)
	get_tree().paused = false
	input_blocked = false
	
	# Restart the level
	_change_to_level(current_level_number)

func _prepare_curtain_for_retry():
	"""
	Prepare the BlackCurtain for a retry transition by moving it back to menu camera
	"""
	var menu_camera = level_select_menu.get_node("Camera2D")
	var player = find_player_in_scene()
	
	if black_curtain and menu_camera and player:
		# Find player camera
		var player_camera = null
		if player.has_node("Camera2D"):
			player_camera = player.get_node("Camera2D")
		else:
			var cameras = player.find_children("*", "Camera2D", true, false)
			if cameras.size() > 0:
				player_camera = cameras[0]
		
		if player_camera:
			# Store global position
			var curtain_global_pos = black_curtain.global_position
			
			# Reparent back to menu camera
			black_curtain.reparent(menu_camera)
			
			# Position for retry transition (off-screen right)
			black_curtain.position.x = get_viewport().size.x
			
			print("BlackCurtain prepared for retry transition")

func _on_level_finish_entered(body):
	# Check if the body that entered is the player
	if body.name == "Player" or body is CharacterBody2D:
		print("Player reached finish! Stopping timer and pausing gameplay.")
		_stop_timer()
		# Block all player inputs
		input_blocked = true
		movement_disabled.emit()  # Tell player to stop accepting movement
		
		# Show finish results UI and pause only gameplay, not UI
		_show_finish_results()

func _setup_timer():
	# Reset timer variables
	timer_running = false
	elapsed_time = 0.0
	timer_label = null
	
	# Reset tracking variables
	damage_count = 0
	parry_count = 0  # Reset parry count
	glits_count = 0  # NEW: Reset glits count
	
	# Find the timer label in the UI
	if current_level_scene and current_level_scene.has_node("UI/TimerBackground/TimerNumber"):
		timer_label = current_level_scene.get_node("UI/TimerBackground/TimerNumber")
		timer_label.text = "0.00"
		print("Timer label found and initialized")
	else:
		print("TimerNumber label not found at UI/TimerBackground/TimerNumber!")

func _update_timer_display():
	if timer_label:
		# Format time as seconds with 2 decimal places
		timer_label.text = "%.2f" % elapsed_time

func _start_timer():
	timer_running = true
	elapsed_time = 0.0
	print("Timer started!")

func _stop_timer():
	timer_running = false
	print("Timer stopped at: %.2f seconds" % elapsed_time)

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
	
	# Unblock input and start timer
	input_blocked = false
	movement_enabled.emit()  # Tell player movement is now allowed
	_start_timer()  # Start the timer when movement is enabled
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

func _connect_damage_tracking(player):
	# Connect to player's health script for damage tracking
	if player.has_node("HealthScript"):
		var health_script = player.get_node("HealthScript")
		if not health_script.health_decreased.is_connected(_on_player_damage_taken):
			health_script.health_decreased.connect(_on_player_damage_taken)
			print("Damage tracking connected successfully")
	else:
		print("WARNING: HealthScript not found on player!")

func _connect_parry_tracking(player):
	# Connect to player for parry tracking - we'll listen to the on_parry_success method
	# Since we can't directly connect to a method call, we'll need to add a signal to the player
	# For now, we'll connect using a different approach - checking if the player has a parry success signal
	if player.has_signal("parry_success"):
		if not player.parry_success.is_connected(_on_player_parry_success):
			player.parry_success.connect(_on_player_parry_success)
			print("Parry tracking connected successfully")
	else:
		print("WARNING: Player doesn't have parry_success signal - parry tracking disabled")
		print("Note: Add 'signal parry_success' to player script and emit it in on_parry_success() method")

func _on_player_damage_taken():
	damage_count += 1
	print("Player took damage! Total damage count: ", damage_count)

func _connect_glits_tracking():
	# Find the coin counter/score system in the current level
	# Look for common node names where the coin system might be
	var possible_coin_nodes = ["CoinCounter", "ScoreManager", "UI/CoinCounter", "UI/ScoreManager", "YourActualNodeName"]
	
	for node_path in possible_coin_nodes:
		if current_level_scene and current_level_scene.has_node(node_path):
			var coin_node = current_level_scene.get_node(node_path)
			# Check if the node has a signal for coin collection
			if coin_node.has_signal("coin_collected") or coin_node.has_signal("point_added"):
				var signal_name = "coin_collected" if coin_node.has_signal("coin_collected") else "point_added"
				if not coin_node.get(signal_name).is_connected(_on_glit_collected):
					coin_node.get(signal_name).connect(_on_glit_collected)
					print("Glits tracking connected successfully to: ", node_path)
					return
			# If no signal, we'll need to check the score periodically or connect differently
			elif coin_node.has_method("add_point"):
				print("Found coin system at: ", node_path, " but no signal available")
				print("Note: Add 'signal coin_collected' or 'signal point_added' to the coin script and emit it in add_point()")
				return
	
	print("WARNING: Coin system not found - glits tracking disabled")
	print("Note: Make sure your coin system has a 'coin_collected' or 'point_added' signal")

func _on_player_parry_success():
	parry_count += 1
	print("Player successful parry! Total parry count: ", parry_count)

func _on_glit_collected():
	glits_count += 1
	print("Glit collected! Total glits count: ", glits_count)

func _get_current_coin_score() -> int:
	# Try to find the coin system and get its current score
	var possible_coin_nodes = ["CoinCounter", "ScoreManager", "UI/CoinCounter", "UI/ScoreManager"]
	
	for node_path in possible_coin_nodes:
		if current_level_scene and current_level_scene.has_node(node_path):
			var coin_node = current_level_scene.get_node(node_path)
			if coin_node.has_method("add_point") and "score" in coin_node:
				print("Found coin system score: ", coin_node.score)
				return coin_node.score
	
	# Broader search if not found in common locations
	var all_nodes = current_level_scene.find_children("*", "", true, false)
	for node in all_nodes:
		if node.has_method("add_point") and "score" in node:
			print("Found coin system score via broad search: ", node.score, " from node: ", node.name)
			return node.score
	
	print("Could not find coin system score")
	return glits_count  # Fallback to tracked count

func _get_medal_texture_by_time(time: float) -> Texture2D:
	# Determine which medal texture to use based on completion time
	if time <= gold_time_threshold:
		print("Gold medal earned! Time: %.2f <= %.2f" % [time, gold_time_threshold])
		return gold_medal_texture
	elif time <= silver_time_threshold:
		print("Silver medal earned! Time: %.2f <= %.2f" % [time, silver_time_threshold])
		return silver_medal_texture
	else:
		print("Bronze medal earned! Time: %.2f > %.2f" % [time, silver_time_threshold])
		return bronze_medal_texture

func _pause_gameplay_only():
	# Method to pause only gameplay elements while keeping UI responsive
	# Instead of setting Engine.time_scale = 0, we'll pause specific nodes
	
	if current_level_scene:
		# Find and pause gameplay nodes but NOT UI nodes
		var nodes_to_pause = []
		
		# Get all nodes except UI
		var all_nodes = current_level_scene.find_children("*", "", true, false)
		for node in all_nodes:
			# Don't pause UI nodes or their children
			if not _is_ui_node(node):
				nodes_to_pause.append(node)
		
		# Set process mode to DISABLED for gameplay nodes
		for node in nodes_to_pause:
			if node.has_method("set_process_mode"):
				node.set_process_mode(Node.PROCESS_MODE_DISABLED)

func _is_ui_node(node: Node) -> bool:
	# Helper function to check if a node is part of the UI
	var current = node
	while current:
		if current.name == "UI" or current.name.begins_with("UI"):
			return true
		if current.name == "FinishResults" or current.name == "RetryButton":
			return true
		current = current.get_parent()
	return false

func _show_finish_results():
	# Find and show the finish results UI
	if current_level_scene and current_level_scene.has_node("UI/FinishResults"):
		var finish_results = current_level_scene.get_node("UI/FinishResults")
		finish_results.visible = true
		print("FinishResults UI shown")
		
		# Set the UI to process even when paused
		finish_results.process_mode = Node.PROCESS_MODE_WHEN_PAUSED
		_set_ui_process_mode_recursive(finish_results, Node.PROCESS_MODE_WHEN_PAUSED)
		
		# Add delay before showing the Time label
		await get_tree().create_timer(1.0).timeout
		
		# Update the Time label under Results
		if finish_results.has_node("Results/Time"):
			var time_label = finish_results.get_node("Results/Time")
			time_label.visible = true
			time_label.text = "TIME................%.2f" % elapsed_time
			print("Time label updated with: %.2f seconds" % elapsed_time)
		else:
			print("WARNING: Time label not found at Results/Time!")
		
		# Add delay before showing the Damage label
		await get_tree().create_timer(0.5).timeout
		
		# Update the Damage label under Results
		if finish_results.has_node("Results/Damage"):
			var damage_label = finish_results.get_node("Results/Damage")
			print("Found Damage label, making visible...")
			damage_label.visible = true
			damage_label.text = "DAMAGE.............%d" % damage_count
			print("Damage label updated with: %d damage instances" % damage_count)
		else:
			print("WARNING: Damage label not found at Results/Damage!")
		
		# Add delay before showing the Parries label
		await get_tree().create_timer(0.5).timeout
		
		# Update the Parries label under Results
		if finish_results.has_node("Results/Parries"):
			var parries_label = finish_results.get_node("Results/Parries")
			print("Found Parries label, making visible...")
			parries_label.visible = true
			parries_label.text = "PARRIES............%d" % parry_count
			print("Parries label updated with: %d successful parries" % parry_count)
		else:
			print("WARNING: Parries label not found at Results/Parries!")
		
		# Add delay before showing the Glits label
		await get_tree().create_timer(0.5).timeout
		
		# Update the Glits label under Results
		if finish_results.has_node("Results/Glits"):
			var glits_label = finish_results.get_node("Results/Glits")
			print("Found Glits label, making visible...")
			glits_label.visible = true
			
			# Get the actual current coin score instead of tracked count
			var actual_coin_score = _get_current_coin_score()
			glits_label.text = "GLITS...............%d" % actual_coin_score
			print("Glits label updated with: %d collected glits (actual coin score)" % actual_coin_score)
		else:
			print("WARNING: Glits label not found at Results/Glits!")
		
		# Add delay before showing the FinalResult label
		await get_tree().create_timer(1.0).timeout
		
		# Show the FinalResult label
		if finish_results.has_node("Results/FinalResult"):
			var final_result_label = finish_results.get_node("Results/FinalResult")
			print("Found FinalResult label, making visible...")
			final_result_label.visible = true
			print("FinalResult label displayed")
		else:
			print("WARNING: FinalResult label not found at Results/FinalResult!")
		
		# Add delay before showing the Medal (1 second after FinalResult)
		await get_tree().create_timer(1.0).timeout
		
		# Show the Medal with appropriate texture based on completion time
		if current_level_scene and current_level_scene.has_node("UI/FinishResults/Results/Medal"):
			var medal_node = current_level_scene.get_node("UI/FinishResults/Results/Medal")
			print("Found Medal node, setting texture and making visible...")
			
			# Set the appropriate medal texture based on completion time
			var medal_texture = _get_medal_texture_by_time(elapsed_time)
			if medal_texture and medal_node is Sprite2D:
				medal_node.texture = medal_texture
				print("Medal texture set successfully")
			elif not medal_texture:
				print("WARNING: No medal texture assigned for this time!")
			elif not medal_node is Sprite2D:
				print("WARNING: Medal node is not a Sprite2D!")
			
			medal_node.visible = true
			print("Medal displayed")
		else:
			print("WARNING: Medal not found at UI/FinishResults/Results/Medal!")
		
		# Add delay before showing the Retry button (after medal is shown)
		await get_tree().create_timer(1.0).timeout
		
		# Show the Retry button
		if current_level_scene and current_level_scene.has_node("UI/FinishResults/RetryButton"):
			var retry_button = current_level_scene.get_node("UI/FinishResults/RetryButton")
			print("Found RetryButton, making visible...")
			retry_button.visible = true
			print("RetryButton displayed")
		else:
			print("WARNING: RetryButton not found at UI/FinishResults/RetryButton!")
		
		# Now pause the game using the get_tree().paused approach instead of time_scale
		get_tree().paused = true
	else:
		print("WARNING: FinishResults UI not found at UI/FinishResults!")

func _set_ui_process_mode_recursive(node: Node, process_mode: int):
	# Recursively set process mode for UI nodes and their children
	node.process_mode = process_mode
	for child in node.get_children():
		_set_ui_process_mode_recursive(child, process_mode)

func _load_level_directly(level_number):
	# Fallback function if BlackCurtain is not available
	_change_to_level(level_number)

func return_to_menu():
	# Stop timer and reset input blocking when returning to menu
	timer_running = false
	input_blocked = false
	movement_enabled.emit()  # Make sure movement is enabled when returning to menu
	
	# Reset pause state when returning to menu (no more time_scale)
	get_tree().paused = false
	
	# Move curtain back to menu camera and position it off-screen
	_return_curtain_to_menu()
	
	if current_level_scene:
		current_level_scene.queue_free()
		current_level_scene = null
	
	# Re-enable the level select menu's camera
	if level_select_menu.has_node("Camera2D"):
		level_select_menu.get_node("Camera2D").enabled = true
	
	level_select_menu.visible = true

func _return_curtain_to_menu():
	"""
	Return the BlackCurtain to the menu camera when returning to menu
	"""
	if not black_curtain:
		return
	
	var menu_camera = level_select_menu.get_node("Camera2D")
	if not menu_camera:
		return
	
	var player = find_player_in_scene()
	var player_camera = null
	
	if player:
		if player.has_node("Camera2D"):
			player_camera = player.get_node("Camera2D")
		else:
			var cameras = player.find_children("*", "Camera2D", true, false)
			if cameras.size() > 0:
				player_camera = cameras[0]
	
	# If curtain is currently under player camera, move it back to menu camera
	if player_camera and black_curtain.get_parent() == player_camera:
		# Store global position
		var curtain_global_pos = black_curtain.global_position
		
		# Reparent back to menu camera
		black_curtain.reparent(menu_camera)
		
		print("BlackCurtain returned to menu camera")
	
	# Animate curtain moving off-screen to the right
	if black_curtain:
		var tween = create_tween()
		tween.set_ease(Tween.EASE_IN)
		tween.set_trans(Tween.TRANS_CUBIC)
		tween.tween_property(black_curtain, "position:x", get_viewport().size.x, 0.8)
