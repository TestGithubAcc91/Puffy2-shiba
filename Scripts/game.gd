# Game.gd
extends Node

@onready var level_select_menu = $LevelSelectMenu
@onready var black_curtain = $BlackCurtain
var current_level_scene = null
var input_blocked = false

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

func _ready():
	level_select_menu.level_selected.connect(_on_level_selected)
	# Make sure the black curtain starts off-screen to the right
	if black_curtain:
		black_curtain.position.x = get_viewport().size.x

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
			
			# Setup timer reference
			_setup_timer()
			
			# Start countdown after player connection is established
			_start_countdown()
		
		# Add more levels as needed

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

func _on_level_finish_entered(body):
	# Check if the body that entered is the player
	if body.name == "Player" or body is CharacterBody2D:
		print("Player reached finish! Stopping timer and freezing game.")
		_stop_timer()
		# Block all player inputs
		input_blocked = true
		movement_disabled.emit()  # Tell player to stop accepting movement
		
		# Show finish results UI BEFORE setting timescale to 0
		_show_finish_results()
		
		# Set timescale to 0 after the async function completes
		# This will be handled by _show_finish_results()

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


func _show_finish_results():
	# Find and show the finish results UI
	if current_level_scene and current_level_scene.has_node("UI/FinishResults"):
		var finish_results = current_level_scene.get_node("UI/FinishResults")
		finish_results.visible = true
		print("FinishResults UI shown")
		
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
		
		# Set timescale to 0 AFTER all labels are shown
		Engine.time_scale = 0
	else:
		print("WARNING: FinishResults UI not found at UI/FinishResults!")

func _load_level_directly(level_number):
	# Fallback function if BlackCurtain is not available
	_change_to_level(level_number)

func return_to_menu():
	# Stop timer and reset input blocking when returning to menu
	timer_running = false
	input_blocked = false
	movement_enabled.emit()  # Make sure movement is enabled when returning to menu
	
	# Reset time scale when returning to menu
	Engine.time_scale = 1.0
	
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
