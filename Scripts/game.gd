# Game.gd - PRESERVES ORIGINAL CURTAIN SPRITES
# Fixes positioning to prevent culling while keeping your spike-end curtain design
extends Node

@onready var level_select_menu = $LevelSelectMenu
@onready var black_curtain = $LevelSelectMenu/Camera2D/BlackCurtain
var current_level_scene = null
var input_blocked = false
var current_level_number = 0

# Timer and tracking variables
var timer_running = false
var elapsed_time = 0.0
var timer_label = null
var damage_count = 0
var parry_count = 0
var glits_count = 0

# Pause variables
var is_paused = false
var pause_button = null
var pause_screen = null

# Results variables
var finish_results = null

# Tutorial variables
var is_tutorial_mode = false

# Signals
signal movement_enabled
signal movement_disabled

# Export settings
@export_group("Countdown Colors")
@export var ready_color: Color = Color.RED
@export var set_color: Color = Color.YELLOW
@export var go_color: Color = Color.GREEN

@export_group("Medal System")
@export var gold_medal_texture: Texture2D
@export var silver_medal_texture: Texture2D
@export var bronze_medal_texture: Texture2D

# Level-specific medal time requirements
var level_medal_times = {
	"tutorial": {"gold": 999999999.0, "silver": 9999999999999999999.0},
	1: {"gold": 43.0, "silver": 50.0},
	2: {"gold": 55.0, "silver": 70.0},
	3: {"gold": 40.0, "silver": 55.0},
	4: {"gold": 65.0, "silver": 80.0},
	5: {"gold": 50.0, "silver": 65.0},
	# Add more levels as needed
}

func _ready():
	level_select_menu.level_selected.connect(_on_level_selected)
	
	# Connect tutorial button if it exists
	if level_select_menu.has_node("TutorialButton"):
		var tutorial_button = level_select_menu.get_node("TutorialButton")
		if not tutorial_button.pressed.is_connected(_on_tutorial_button_pressed):
			tutorial_button.pressed.connect(_on_tutorial_button_pressed)
	
	# Initialize curtain position
	_reset_curtain_position()

func _reset_curtain_position():
	"""Ensure the curtain is in the correct starting position"""
	if black_curtain and level_select_menu.has_node("Camera2D"):
		# Make sure curtain is parented to menu camera
		var menu_camera = level_select_menu.get_node("Camera2D")
		if black_curtain.get_parent() != menu_camera:
			black_curtain.reparent(menu_camera)
		
		# Reset position to off-screen right
		black_curtain.position.x = get_viewport().size.x
		print("Reset curtain position to: ", black_curtain.position.x)

func _process(delta):
	if timer_running and timer_label and not is_paused:
		elapsed_time += delta
		timer_label.text = "%.2f" % elapsed_time

func _input(event):
	if input_blocked:
		get_viewport().set_input_as_handled()

func _on_level_selected(level_number):
	is_tutorial_mode = false
	_start_curtain_transition(level_number)

func _on_tutorial_button_pressed():
	is_tutorial_mode = true
	_start_curtain_transition("tutorial")

func _start_curtain_transition(level_identifier):
	if not black_curtain:
		_load_level_directly(level_identifier)
		return
	
	var menu_camera = level_select_menu.get_node("Camera2D")
	if menu_camera:
		menu_camera.enabled = true
		
		# CRITICAL FIX: Always reset curtain position and parent before starting transition
		_reset_curtain_position()
	
	print("Starting curtain transition from position: ", black_curtain.position.x)
	
	var tween = create_tween()
	tween.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tween.tween_property(black_curtain, "position:x", -get_viewport().size.x, 2.5)
	
	await get_tree().create_timer(1).timeout
	_change_to_level(level_identifier)

func _change_to_level(level_identifier):
	# Convert to string for consistent comparison
	var level_id_str = str(level_identifier)
	
	if level_id_str == "tutorial":
		current_level_number = 0  # Special identifier for tutorial
		is_tutorial_mode = true
	else:
		current_level_number = int(level_identifier)
		is_tutorial_mode = false
	
	get_tree().paused = false
	input_blocked = false
	is_paused = false
	
	if current_level_scene:
		current_level_scene.queue_free()
		current_level_scene = null
		await get_tree().process_frame
	
	level_select_menu.visible = false
	
	if level_id_str == "tutorial":
		current_level_scene = preload("res://Scenes/tutorial_holder.tscn").instantiate()
		add_child(current_level_scene)
		await get_tree().process_frame
		
		_switch_to_player_camera()
		_setup_connections()
		_start_countdown()
	else:
		match int(level_identifier):
			1:
				current_level_scene = preload("res://Scenes/level_1_holder.tscn").instantiate()
				add_child(current_level_scene)
				await get_tree().process_frame
				
				_switch_to_player_camera()
				_setup_connections()
				_start_countdown()

func _switch_to_player_camera():
	var menu_camera = level_select_menu.get_node("Camera2D")
	var player = find_player_in_scene()
	if not player: return
	
	var player_camera = _find_player_camera(player)
	if not player_camera: return
	
	if black_curtain and player_camera:
		var curtain_global_pos = black_curtain.global_position
		black_curtain.reparent(player_camera)
		black_curtain.global_position = curtain_global_pos
	
	if menu_camera: menu_camera.enabled = false
	if player_camera:
		player_camera.enabled = true
		player_camera.make_current()

func _find_player_camera(player):
	if player.has_node("Camera2D"):
		return player.get_node("Camera2D")
	var cameras = player.find_children("*", "Camera2D", true, false)
	return cameras[0] if cameras.size() > 0 else null

func _setup_connections():
	var player = find_player_in_scene()
	if player:
		# Connect movement signals
		if not movement_disabled.is_connected(player._on_movement_disabled):
			movement_disabled.connect(player._on_movement_disabled)
		if not movement_enabled.is_connected(player._on_movement_enabled):
			movement_enabled.connect(player._on_movement_enabled)
		
		# Connect damage tracking
		if player.has_node("HealthScript"):
			var health_script = player.get_node("HealthScript")
			if not health_script.health_decreased.is_connected(_on_player_damage_taken):
				health_script.health_decreased.connect(_on_player_damage_taken)
		
		# Connect parry tracking
		if player.has_signal("parry_success") and not player.parry_success.is_connected(_on_player_parry_success):
			player.parry_success.connect(_on_player_parry_success)
	
	# Connect level finish
	if current_level_scene and current_level_scene.has_node("LevelFinish"):
		var level_finish = current_level_scene.get_node("LevelFinish")
		if not level_finish.body_entered.is_connected(_on_level_finish_entered):
			level_finish.body_entered.connect(_on_level_finish_entered)
	
	# Connect retry button
	if current_level_scene and current_level_scene.has_node("UI/FinishResults/RetryButton"):
		var retry_button = current_level_scene.get_node("UI/FinishResults/RetryButton")
		if not retry_button.pressed.is_connected(_on_retry_button_pressed):
			retry_button.pressed.connect(_on_retry_button_pressed)
	
	# Connect home button
	if current_level_scene and current_level_scene.has_node("UI/FinishResults/HomeButton"):
		var home_button = current_level_scene.get_node("UI/FinishResults/HomeButton")
		if not home_button.pressed.is_connected(_on_home_button_pressed):
			home_button.pressed.connect(_on_home_button_pressed)
	
	# Connect pause button
	_setup_pause_button()
	
	# Connect glits tracking
	_connect_glits_tracking()
	
	# Setup timer
	_setup_timer()

func _setup_pause_button():
	if current_level_scene and current_level_scene.has_node("UI/PauseButton"):
		pause_button = current_level_scene.get_node("UI/PauseButton")
		pause_screen = pause_button.get_node("PauseScreen") if pause_button.has_node("PauseScreen") else null
		
		if pause_button and not pause_button.pressed.is_connected(_on_pause_button_pressed):
			pause_button.pressed.connect(_on_pause_button_pressed)
		
		# Make sure pause screen starts hidden
		if pause_screen:
			pause_screen.visible = false
			
			# Connect pause screen buttons
			if pause_screen.has_node("RetryButton"):
				var pause_retry_button = pause_screen.get_node("RetryButton")
				if not pause_retry_button.pressed.is_connected(_on_pause_retry_button_pressed):
					pause_retry_button.pressed.connect(_on_pause_retry_button_pressed)
			
			if pause_screen.has_node("ContinueButton"):
				var continue_button = pause_screen.get_node("ContinueButton")
				if not continue_button.pressed.is_connected(_on_continue_button_pressed):
					continue_button.pressed.connect(_on_continue_button_pressed)
			
			if pause_screen.has_node("HomeButton"):
				var pause_home_button = pause_screen.get_node("HomeButton")
				if not pause_home_button.pressed.is_connected(_on_pause_home_button_pressed):
					pause_home_button.pressed.connect(_on_pause_home_button_pressed)

func _on_pause_button_pressed():
	if not is_paused:
		_pause_game()
	else:
		_unpause_game()

func _pause_game():
	is_paused = true
	get_tree().paused = true
	movement_disabled.emit()
	
	# Show pause screen
	if pause_screen:
		pause_screen.visible = true
		pause_screen.process_mode = Node.PROCESS_MODE_WHEN_PAUSED
		_set_ui_process_mode_recursive(pause_screen, Node.PROCESS_MODE_WHEN_PAUSED)
	
	# Keep pause button working while paused
	if pause_button:
		pause_button.process_mode = Node.PROCESS_MODE_WHEN_PAUSED

func _connect_glits_tracking():
	var possible_paths = ["CoinCounter", "ScoreManager", "UI/CoinCounter", "UI/ScoreManager"]
	for path in possible_paths:
		if current_level_scene and current_level_scene.has_node(path):
			var coin_node = current_level_scene.get_node(path)
			var signal_name = "coin_collected" if coin_node.has_signal("coin_collected") else "point_added"
			if coin_node.has_signal(signal_name) and not coin_node.get(signal_name).is_connected(_on_glit_collected):
				coin_node.get(signal_name).connect(_on_glit_collected)
				return

func _setup_timer():
	timer_running = false
	elapsed_time = 0.0
	damage_count = 0
	parry_count = 0
	glits_count = 0
	
	if current_level_scene and current_level_scene.has_node("UI/TimerBackground/TimerNumber"):
		timer_label = current_level_scene.get_node("UI/TimerBackground/TimerNumber")
		timer_label.text = "0.00"

func _start_countdown():
	input_blocked = true
	movement_disabled.emit()
	
	var countdown_label = current_level_scene.get_node("UI/StartCountdown") if current_level_scene and current_level_scene.has_node("UI/StartCountdown") else null
	if not countdown_label:
		input_blocked = false
		movement_enabled.emit()
		return
	
	countdown_label.visible = true
	
	# Countdown sequence
	var countdown_data = [
		{"text": "READY?", "color": ready_color, "time": 1.0},
		{"text": "SET...", "color": set_color, "time": 1.0},
		{"text": "GO!!", "color": go_color, "time": 0.5}
	]
	
	for data in countdown_data:
		countdown_label.text = data.text
		countdown_label.modulate = data.color
		await get_tree().create_timer(data.time).timeout
	
	countdown_label.visible = false
	input_blocked = false
	movement_enabled.emit()
	_start_timer()

func _start_timer():
	timer_running = true
	elapsed_time = 0.0

func _stop_timer():
	timer_running = false

func _on_level_finish_entered(body):
	if body.name == "Player" or body is CharacterBody2D:
		_stop_timer()
		input_blocked = true
		movement_disabled.emit()
		_show_finish_results()

func _show_finish_results():
	if not (current_level_scene and current_level_scene.has_node("UI/FinishResults")): return
	
	finish_results = current_level_scene.get_node("UI/FinishResults")
	finish_results.visible = true
	finish_results.process_mode = Node.PROCESS_MODE_WHEN_PAUSED
	_set_ui_process_mode_recursive(finish_results, Node.PROCESS_MODE_WHEN_PAUSED)
	
	# Show results with delays
	var results_data = [
		{"path": "Results/Time", "text": "TIME................%.2f" % elapsed_time, "delay": 1.0},
		{"path": "Results/Damage", "text": "DAMAGE.............%d" % damage_count, "delay": 0.5},
		{"path": "Results/Parries", "text": "PARRIES............%d" % parry_count, "delay": 0.5},
		{"path": "Results/Glits", "text": "GLITS...............%d" % _get_current_coin_score(), "delay": 0.5},
		{"path": "Results/FinalResult", "text": "", "delay": 1.0}
	]
	
	for data in results_data:
		await get_tree().create_timer(data.delay).timeout
		if finish_results.has_node(data.path):
			var label = finish_results.get_node(data.path)
			label.visible = true
			if data.text: label.text = data.text
	
	# Show medal and retry button
	await get_tree().create_timer(1.0).timeout
	_show_medal(finish_results)
	
	await get_tree().create_timer(1.0).timeout
	if finish_results.has_node("RetryButton"):
		finish_results.get_node("RetryButton").visible = true

	# Show home button alongside retry button
	if finish_results.has_node("HomeButton"):
		finish_results.get_node("HomeButton").visible = true
	
	get_tree().paused = true

func _show_medal(finish_results):
	if finish_results.has_node("Results/Medal"):
		var medal_node = finish_results.get_node("Results/Medal")
		var medal_texture = _get_medal_texture_by_time(elapsed_time)
		if medal_texture and medal_node is Sprite2D:
			medal_node.texture = medal_texture
		medal_node.visible = true

func _get_medal_texture_by_time(time: float) -> Texture2D:
	var current_level_key = "tutorial" if is_tutorial_mode else current_level_number
	var medal_times = level_medal_times.get(current_level_key, {"gold": 45.0, "silver": 60.0})
	
	if time <= medal_times.gold:
		return gold_medal_texture
	elif time <= medal_times.silver:
		return silver_medal_texture
	else:
		return bronze_medal_texture

func _get_current_coin_score() -> int:
	var possible_paths = ["CoinCounter", "ScoreManager", "UI/CoinCounter", "UI/ScoreManager"]
	for path in possible_paths:
		if current_level_scene and current_level_scene.has_node(path):
			var coin_node = current_level_scene.get_node(path)
			if coin_node.has_method("add_point") and "score" in coin_node:
				return coin_node.score
	
	# Broader search
	var all_nodes = current_level_scene.find_children("*", "", true, false)
	for node in all_nodes:
		if node.has_method("add_point") and "score" in node:
			return node.score
	
	return glits_count

func find_player_in_scene() -> Node:
	if not current_level_scene: return null
	
	var possible_paths = ["Player", "Player2D", "CharacterBody2D"]
	for path in possible_paths:
		if current_level_scene.has_node(path):
			return current_level_scene.get_node(path)
	
	var nodes = current_level_scene.find_children("*", "CharacterBody2D", true, false)
	return nodes[0] if nodes.size() > 0 else null

func _hide_results_page():
	"""Hide the results page similar to how the pause menu is hidden"""
	if finish_results:
		finish_results.visible = false
		# Reset process mode
		finish_results.process_mode = Node.PROCESS_MODE_INHERIT

func _on_retry_button_pressed():
	_hide_results_page()
	_unpause_game()
	_start_retry_curtain_transition()

func _on_home_button_pressed():
	_hide_results_page()
	_unpause_game()
	_start_home_curtain_transition()

# FIXED HOME BUTTON TRANSITION - Uses camera-relative positioning
func _start_home_curtain_transition():
	print("Starting home curtain transition - Tutorial mode: ", is_tutorial_mode, " Level: ", current_level_number)
	
	# Find player and camera
	var player = find_player_in_scene()
	if not player:
		print("No player found, returning to menu directly")
		return_to_menu()
		return
	
	var player_camera = _find_player_camera(player)
	if not player_camera:
		print("No player camera found, returning to menu directly")
		return_to_menu()
		return
	
	var player_curtain = player_camera.get_node("BlackCurtain") if player_camera.has_node("BlackCurtain") else null
	if not player_curtain:
		print("No curtain found, returning to menu directly")
		return_to_menu()
		return
	
	print("Found all components, starting curtain animation")
	
	# Block input and disable movement
	input_blocked = true
	movement_disabled.emit()
	
	# Ensure curtain can be animated even if coming from paused state
	player_curtain.process_mode = Node.PROCESS_MODE_ALWAYS
	
	# CRITICAL FIX: Use camera-relative positioning instead of world positioning
	var viewport_size = get_viewport().size
	
	# Ensure curtain is child of camera for proper relative positioning
	if player_curtain.get_parent() != player_camera:
		player_curtain.reparent(player_camera)
	
	# Position curtain relative to camera (screen coordinates) - prevents culling
	player_curtain.position = Vector2(viewport_size.x, 0)  # Just off-screen right
	
	print("Curtain positioned at: ", player_curtain.position, " (relative to camera)")
	
	# Create tween that works regardless of pause state
	var tween = create_tween()
	tween.set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
	tween.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	
	# Move curtain to cover screen (relative to camera)
	tween.tween_property(player_curtain, "position:x", -viewport_size.x, 2.5)
	
	print("Curtain target position: ", -viewport_size.x, " (relative to camera)")
	
	# Wait for curtain to cover screen
	await get_tree().create_timer(0.8).timeout
	
	# Store reference to curtain before returning to menu
	var temp_curtain_ref = player_curtain
	
	# Return to menu without curtain animation (we already did it)
	_return_to_menu_without_curtain()
	
	# Wait for the full curtain animation to complete
	await get_tree().create_timer(1.7).timeout
	
	# Cleanup curtain if it still exists
	if is_instance_valid(temp_curtain_ref):
		print("Cleaning up curtain after animation completion")
		temp_curtain_ref.queue_free()

func _start_retry_curtain_transition():
	# Find player and camera
	var player = find_player_in_scene()
	if not player:
		_restart_level_directly()
		return
	
	var player_camera = _find_player_camera(player)
	var player_curtain = player_camera.get_node("BlackCurtain") if player_camera and player_camera.has_node("BlackCurtain") else null
	
	if not player_curtain:
		_restart_level_directly()
		return
	
	input_blocked = true
	movement_disabled.emit()
	
	# Ensure curtain can be animated even if coming from paused state
	player_curtain.process_mode = Node.PROCESS_MODE_ALWAYS
	
	# CRITICAL FIX: Use camera-relative positioning instead of world positioning
	var viewport_size = get_viewport().size
	
	# Ensure curtain is child of camera
	if player_curtain.get_parent() != player_camera:
		player_curtain.reparent(player_camera)
	
	# Position relative to camera (not world coordinates) - prevents culling
	player_curtain.position = Vector2(viewport_size.x, 0)
	
	print("Retry curtain positioned at: ", player_curtain.position, " (camera-relative)")
	
	# Create tween
	var tween = create_tween()
	tween.set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
	tween.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	
	# Animate to cover screen
	tween.tween_property(player_curtain, "position:x", -viewport_size.x, 2.5)
	
	# Wait for curtain to cover screen
	await get_tree().create_timer(0.8).timeout
	
	_restart_level_after_curtain()
	
	# Wait for new level to load and animation to complete
	await get_tree().create_timer(1.7).timeout

func _restart_level_after_curtain():
	get_tree().paused = false
	input_blocked = false
	is_paused = false
	
	if is_tutorial_mode:
		_change_to_level("tutorial")
	else:
		_change_to_level(current_level_number)

func _restart_level_directly():
	get_tree().paused = false
	input_blocked = false
	is_paused = false
	
	if is_tutorial_mode:
		_change_to_level("tutorial")
	else:
		_change_to_level(current_level_number)

func _set_ui_process_mode_recursive(node: Node, process_mode: int):
	node.process_mode = process_mode
	for child in node.get_children():
		_set_ui_process_mode_recursive(child, process_mode)

func _load_level_directly(level_identifier):
	_change_to_level(level_identifier)

func return_to_menu():
	timer_running = false
	input_blocked = false
	is_paused = false
	is_tutorial_mode = false
	movement_enabled.emit()
	get_tree().paused = false
	_return_curtain_to_menu()
	
	if current_level_scene:
		current_level_scene.queue_free()
		current_level_scene = null
	
	if level_select_menu.has_node("Camera2D"):
		level_select_menu.get_node("Camera2D").enabled = true
	
	level_select_menu.visible = true

func _return_to_menu_without_curtain():
	"""Return to menu without playing curtain animation (used when curtain was already animated)"""
	timer_running = false
	input_blocked = false
	is_paused = false
	is_tutorial_mode = false
	movement_enabled.emit()
	get_tree().paused = false
	
	if current_level_scene:
		current_level_scene.queue_free()
		current_level_scene = null
	
	if level_select_menu.has_node("Camera2D"):
		level_select_menu.get_node("Camera2D").enabled = true
	
	level_select_menu.visible = true
	
	# Reset curtain position when returning to menu
	_reset_curtain_position()

func _return_curtain_to_menu():
	if not black_curtain: return
	
	var menu_camera = level_select_menu.get_node("Camera2D")
	if not menu_camera: return
	
	var player = find_player_in_scene()
	var player_camera = _find_player_camera(player) if player else null
	
	if player_camera and black_curtain.get_parent() == player_camera:
		black_curtain.reparent(menu_camera)
	
	if black_curtain:
		var tween = create_tween()
		tween.set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_CUBIC)
		tween.tween_property(black_curtain, "position:x", get_viewport().size.x, 0.8)

# Signal handlers
func _on_player_damage_taken():
	damage_count += 1

func _on_player_parry_success():
	parry_count += 1

func _on_glit_collected():
	glits_count += 1

# Pause screen button handlers
func _on_pause_retry_button_pressed():
	_unpause_game()
	_start_retry_curtain_transition()

func _on_continue_button_pressed():
	_unpause_game()

func _on_pause_home_button_pressed():
	_unpause_game()
	_start_home_curtain_transition()

func _unpause_game():
	is_paused = false
	get_tree().paused = false
	
	# Hide pause screen
	if pause_screen:
		pause_screen.visible = false
	
	# Reset pause button process mode so it can be pressed again
	if pause_button:
		pause_button.process_mode = Node.PROCESS_MODE_INHERIT
	
	# Re-enable movement if not blocked by other systems
	if not input_blocked:
		movement_enabled.emit()
