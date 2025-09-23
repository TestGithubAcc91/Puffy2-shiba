# Game.gd - Enhanced curtain transitions with smooth black-to-black handoff
extends Node

@onready var level_select_menu = $LevelSelectMenu
@onready var black_curtain = $LevelSelectMenu/Camera2D/BlackCurtain
var current_level_scene = null
var input_blocked = false
var current_level_number = 0

# Game state tracking
var timer_running = false
var elapsed_time = 0.0
var timer_label = null
var damage_count = 0
var parry_count = 0
var glits_count = 0
var is_paused = false
var pause_button = null
var pause_screen = null
var finish_results = null
var is_tutorial_mode = false

# Audio system
var audio_player: AudioStreamPlayer
var connected_buttons = []

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

@export_group("Audio")
@export var button_click_sound: AudioStream

# Level medal requirements
var level_medal_times = {
	"tutorial": {"gold": 999999999.0, "silver": 9999999999999999999.0},
	1: {"gold": 43.0, "silver": 50.0}, 2: {"gold": 55.0, "silver": 70.0},
	3: {"gold": 40.0, "silver": 55.0}, 4: {"gold": 65.0, "silver": 80.0},
	5: {"gold": 50.0, "silver": 65.0}
}

func _ready():
	_setup_audio_system()
	level_select_menu.level_selected.connect(_on_level_selected)
	if level_select_menu.has_node("TutorialButton"):
		level_select_menu.get_node("TutorialButton").pressed.connect(_on_tutorial_button_pressed)
		_connect_button_sound(level_select_menu.get_node("TutorialButton"))
	
	if level_select_menu.has_node("Level1Button"):
		_connect_button_sound(level_select_menu.get_node("Level1Button"))
	
	_reset_curtain_position()
	_connect_menu_buttons_sound()

func _setup_audio_system():
	audio_player = AudioStreamPlayer.new()
	audio_player.name = "ButtonAudioPlayer"
	audio_player.bus = "SFX"
	add_child(audio_player)
	
	if button_click_sound:
		audio_player.stream = button_click_sound

func _connect_menu_buttons_sound():
	var level_buttons = level_select_menu.find_children("*", "BaseButton", true, false)
	for button in level_buttons:
		_connect_button_sound(button)

func _connect_button_sound(button: BaseButton):
	if not button or button in connected_buttons:
		return
	
	button.pressed.connect(_play_button_sound)
	connected_buttons.append(button)

func _play_button_sound():
	if audio_player and button_click_sound:
		audio_player.play()

func _reset_curtain_position():
	if black_curtain and level_select_menu.has_node("Camera2D"):
		var menu_camera = level_select_menu.get_node("Camera2D")
		if black_curtain.get_parent() != menu_camera:
			black_curtain.reparent(menu_camera)
		black_curtain.position.x = get_viewport().size.x

func _process(delta):
	if timer_running and timer_label and not is_paused:
		elapsed_time += delta
		timer_label.text = "%.2f" % elapsed_time

func _input(event):
	if input_blocked: get_viewport().set_input_as_handled()

func _on_level_selected(level_number):
	is_tutorial_mode = false
	_start_scene_change_curtain_transition(level_number)

func _on_tutorial_button_pressed():
	is_tutorial_mode = true
	_start_scene_change_curtain_transition("tutorial")

# ENHANCED: Scene change with smooth black-to-black transition
func _start_scene_change_curtain_transition(level_identifier):
	"""Enhanced curtain transition for scene changes with smooth black handoff"""
	if not black_curtain:
		_change_to_level(level_identifier)
		return
	
	print("Starting scene change curtain transition to: ", level_identifier)
	
	var menu_camera = level_select_menu.get_node("Camera2D")
	if menu_camera:
		menu_camera.enabled = true
		_reset_curtain_position()
	
	# Phase 1: Move curtain so the solid black rectangle part covers the entire screen
	var viewport_size = get_viewport().size
	var tween = create_tween()
	tween.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	
	# IMPROVED: Move curtain enough so solid black part covers screen completely
	# Account for left spikes - move curtain to where the solid rectangle covers the screen
	var cover_position = -viewport_size.x * 0.4  # Adjust based on your spike width
	tween.tween_property(black_curtain, "position:x", cover_position, 1.2)
	
	# Wait for curtain to reach covering position (black rectangle phase)
	await get_tree().create_timer(1.0).timeout  # Wait in black state
	
	# Phase 2: Load new scene with curtain already covering it
	_change_to_level_with_curtain_covering(level_identifier)

func _change_to_level_with_curtain_covering(level_identifier):
	"""Load new level with curtain already in covering position for smooth handoff"""
	var level_id_str = str(level_identifier)
	current_level_number = 0 if level_id_str == "tutorial" else int(level_identifier)
	is_tutorial_mode = (level_id_str == "tutorial")
	
	get_tree().paused = false
	input_blocked = false
	is_paused = false
	
	# Clean up old scene
	if current_level_scene:
		current_level_scene.queue_free()
		current_level_scene = null
		await get_tree().process_frame
	
	level_select_menu.visible = false
	
	# Load new level
	var level_path = "res://Scenes/tutorial_holder.tscn" if is_tutorial_mode else "res://Scenes/level_%d_holder.tscn" % int(level_identifier)
	current_level_scene = load(level_path).instantiate()
	add_child(current_level_scene)
	await get_tree().process_frame
	
	# DISABLE BlackCurtainTransition ColorRect after scene change
	if current_level_scene and current_level_scene.has_node("UI/BlackCurtainTransition"):
		var transition_rect = current_level_scene.get_node("UI/BlackCurtainTransition")
		transition_rect.visible = false
		print("Disabled BlackCurtainTransition ColorRect")
	
	# Switch cameras and position curtain to cover new scene
	_switch_to_player_camera_with_curtain_covering()
	_setup_connections()
	
	# Phase 3: Continue curtain animation in new scene (reveal new scene)
	await get_tree().create_timer(0.3).timeout  # Brief pause in black
	_continue_curtain_reveal_in_new_scene()


func _switch_to_player_camera_with_curtain_covering():
	"""Switch cameras and ensure curtain covers the new scene initially"""
	var menu_camera = level_select_menu.get_node("Camera2D")
	var player = find_player_in_scene()
	var player_camera = _find_player_camera(player) if player else null
	
	if black_curtain and player_camera:
		# Transfer curtain to new camera in covering position
		black_curtain.reparent(player_camera)
		
		# CRITICAL FIX: Position curtain at center (0,0) so the solid black part covers screen
		# Since the curtain was covering in the menu, keep it at center in player camera
		black_curtain.position = Vector2(0, 0)  # Solid black rectangle at screen center
		
		print("Curtain transferred to player camera at covering position: ", black_curtain.position)
	
	if menu_camera: menu_camera.enabled = false
	if player_camera: player_camera.enabled = true; player_camera.make_current()

func _continue_curtain_reveal_in_new_scene():
	"""Continue curtain animation to reveal the new scene"""
	var player = find_player_in_scene()
	var player_camera = _find_player_camera(player) if player else null
	var curtain = player_camera.get_node("BlackCurtain") if player_camera and player_camera.has_node("BlackCurtain") else null
	
	if not curtain:
		print("No curtain found in new scene, starting countdown directly")
		_start_countdown()
		return
	
	print("Continuing curtain reveal animation from position: ", curtain.position)
	
	# Phase 3: Move the existing curtain that's already covering the screen to the LEFT
	var tween = create_tween()
	tween.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	
	# CRITICAL FIX: Move curtain far enough LEFT to completely clear the camera view
	var viewport_size = get_viewport().size
	# Since the curtain is already positioned to cover the screen, move it way left
	# Account for the full width of curtain including all spikes
	var reveal_position = -viewport_size.x * 3.0  # Move 3 screen widths to the left
	
	print("Moving curtain from ", curtain.position.x, " to ", reveal_position)
	
	tween.tween_property(curtain, "position:x", reveal_position, 1.3)
	
	# Start countdown while curtain is revealing
	await get_tree().create_timer(0.5).timeout
	_start_countdown()

# ORIGINAL CHANGE_TO_LEVEL FOR NON-CURTAIN CASES
func _change_to_level(level_identifier):
	"""Original level change without curtain covering (fallback)"""
	var level_id_str = str(level_identifier)
	current_level_number = 0 if level_id_str == "tutorial" else int(level_identifier)
	is_tutorial_mode = (level_id_str == "tutorial")
	
	get_tree().paused = false
	input_blocked = false
	is_paused = false
	
	if current_level_scene:
		current_level_scene.queue_free()
		current_level_scene = null
		await get_tree().process_frame
	
	level_select_menu.visible = false
	
	var level_path = "res://Scenes/tutorial_holder.tscn" if is_tutorial_mode else "res://Scenes/level_%d_holder.tscn" % int(level_identifier)
	current_level_scene = load(level_path).instantiate()
	add_child(current_level_scene)
	await get_tree().process_frame
	
	_switch_to_player_camera()
	_setup_connections()
	_start_countdown()

func _switch_to_player_camera():
	"""Original camera switch without curtain management"""
	var menu_camera = level_select_menu.get_node("Camera2D")
	var player = find_player_in_scene()
	var player_camera = _find_player_camera(player) if player else null
	
	if black_curtain and player_camera:
		var curtain_global_pos = black_curtain.global_position
		black_curtain.reparent(player_camera)
		black_curtain.global_position = curtain_global_pos
	
	if menu_camera: menu_camera.enabled = false
	if player_camera: player_camera.enabled = true; player_camera.make_current()

func _find_player_camera(player):
	if not player: return null
	if player.has_node("Camera2D"): return player.get_node("Camera2D")
	var cameras = player.find_children("*", "Camera2D", true, false)
	return cameras[0] if cameras.size() > 0 else null

# ENHANCED: Within-scene curtain transitions (retry/home from level)
func _start_within_scene_curtain_transition(target_function: Callable):
	"""Enhanced curtain transition within the same scene type"""
	print("Starting within-scene curtain transition")
	
	var player = find_player_in_scene()
	if not player:
		print("No player found, executing target function directly")
		target_function.call()
		return
	
	var player_camera = _find_player_camera(player)
	if not player_camera:
		print("No player camera found, executing target function directly")
		target_function.call()
		return
	
	var player_curtain = player_camera.get_node("BlackCurtain") if player_camera.has_node("BlackCurtain") else null
	if not player_curtain:
		print("No curtain found, executing target function directly")
		target_function.call()
		return
	
	print("Found all components, starting within-scene curtain animation")
	
	# Block input and disable movement
	input_blocked = true
	movement_disabled.emit()
	
	# Ensure curtain can be animated 
	player_curtain.process_mode = Node.PROCESS_MODE_ALWAYS
	
	var viewport_size = get_viewport().size
	
	# Ensure curtain is child of camera for proper relative positioning
	if player_curtain.get_parent() != player_camera:
		player_curtain.reparent(player_camera)
	
	# Start from off-screen right
	player_curtain.position = Vector2(viewport_size.x, 0)
	
	print("Curtain positioned at: ", player_curtain.position, " (relative to camera)")
	
	# Phase 1: Move curtain to cover screen
	var tween = create_tween()
	tween.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tween.tween_property(player_curtain, "position:x", -viewport_size.x, 1.2)
	
	# Wait for curtain to fully cover screen (black state)
	await get_tree().create_timer(0.8).timeout
	
	# Phase 2: Execute the target function (load new content)
	target_function.call()
	
	# Phase 3: Continue curtain to reveal new content (if still in same scene type)
	await get_tree().create_timer(0.3).timeout
	
	# Check if we're still in a level scene (not returned to menu)
	if current_level_scene:
		_continue_curtain_reveal_after_within_scene_change()

func _continue_curtain_reveal_after_within_scene_change():
	"""Continue curtain reveal after within-scene change (like retry)"""
	var player = find_player_in_scene()
	var player_camera = _find_player_camera(player) if player else null
	var curtain = player_camera.get_node("BlackCurtain") if player_camera and player_camera.has_node("BlackCurtain") else null
	
	if not curtain:
		return
	
	print("Continuing curtain reveal after within-scene change")
	
	# Move curtain to reveal new content
	var tween = create_tween()
	tween.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tween.tween_property(curtain, "position:x", get_viewport().size.x, 1.3)

# UPDATE EXISTING FUNCTIONS TO USE NEW SYSTEM

func _on_retry_button_pressed():
	print("RETRY BUTTON PRESSED - Starting retry sequence")
	_hide_results_page()
	_start_within_scene_curtain_transition(_restart_level_after_curtain)

func _on_home_button_pressed():
	print("HOME BUTTON PRESSED - Starting home sequence")  
	_hide_results_page()
	_start_scene_change_curtain_transition_to_menu()

func _start_scene_change_curtain_transition_to_menu():
	"""Enhanced curtain transition from level to menu with smooth black handoff"""
	print("Starting scene change curtain transition to menu")
	
	# Find player and camera
	var player = find_player_in_scene()
	if not player:
		print("No player found, returning to menu directly")
		_return_to_menu_without_curtain()
		return
	
	var player_camera = _find_player_camera(player)
	if not player_camera:
		print("No player camera found, returning to menu directly")
		_return_to_menu_without_curtain()
		return
	
	var player_curtain = player_camera.get_node("BlackCurtain") if player_camera.has_node("BlackCurtain") else null
	if not player_curtain:
		print("No curtain found, returning to menu directly")
		_return_to_menu_without_curtain()
		return
	
	print("Found all components, starting level-to-menu curtain animation")
	
	# Block input and disable movement
	input_blocked = true
	movement_disabled.emit()
	
	# Ensure curtain can be animated 
	player_curtain.process_mode = Node.PROCESS_MODE_ALWAYS
	
	var viewport_size = get_viewport().size
	
	# Ensure curtain is child of camera for proper relative positioning
	if player_curtain.get_parent() != player_camera:
		player_curtain.reparent(player_camera)
	
	# Position curtain relative to camera
	player_curtain.position = Vector2(viewport_size.x, 0)
	
	print("Curtain positioned at: ", player_curtain.position, " (relative to camera)")
	
	# Phase 1: Move curtain to cover current level
	var tween = create_tween()
	tween.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tween.tween_property(player_curtain, "position:x", -viewport_size.x, 1.2)
	
	# Wait for curtain to cover screen (black state)
	await get_tree().create_timer(0.8).timeout
	
	# Phase 2: Switch to menu with curtain covering it
	_return_to_menu_with_curtain_covering()
	
	# Phase 3: Reveal menu
	await get_tree().create_timer(0.3).timeout
	_continue_curtain_reveal_menu()

func _return_to_menu_with_curtain_covering():
	"""Return to menu with curtain already covering for smooth transition"""
	timer_running = false
	input_blocked = false
	is_paused = false
	is_tutorial_mode = false
	movement_enabled.emit()
	get_tree().paused = false
	
	# Clean up level scene
	if current_level_scene:
		current_level_scene.queue_free()
		current_level_scene = null
	
	# Switch to menu camera and transfer curtain
	var menu_camera = level_select_menu.get_node("Camera2D")
	if menu_camera:
		menu_camera.enabled = true
		
		# Transfer curtain to menu camera in covering position
		if black_curtain:
			black_curtain.reparent(menu_camera)
			black_curtain.position = Vector2(-get_viewport().size.x, 0)  # Already covering
			print("Curtain transferred to menu camera in covering position")
	
	level_select_menu.visible = true

func _continue_curtain_reveal_menu():
	"""Continue curtain animation to reveal menu"""
	if not black_curtain:
		return
	
	print("Continuing curtain reveal for menu")
	
	# Reveal menu by moving curtain off-screen
	var tween = create_tween()
	tween.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tween.tween_property(black_curtain, "position:x", get_viewport().size.x, 1.3)

# UPDATE PAUSE SYSTEM HANDLERS
func _on_pause_retry_button_pressed():
	_unpause_game()
	_start_within_scene_curtain_transition(_restart_level_after_curtain)

func _on_pause_home_button_pressed():
	_unpause_game()
	_start_scene_change_curtain_transition_to_menu()

# KEEP ALL OTHER EXISTING FUNCTIONS UNCHANGED
func _setup_connections():
	var player = find_player_in_scene()
	if player:
		if not movement_disabled.is_connected(player._on_movement_disabled):
			movement_disabled.connect(player._on_movement_disabled)
		if not movement_enabled.is_connected(player._on_movement_enabled):
			movement_enabled.connect(player._on_movement_enabled)
		
		if player.has_node("HealthScript"):
			var health_script = player.get_node("HealthScript")
			if not health_script.health_decreased.is_connected(_on_player_damage_taken):
				health_script.health_decreased.connect(_on_player_damage_taken)
		
		if player.has_signal("parry_success") and not player.parry_success.is_connected(_on_player_parry_success):
			player.parry_success.connect(_on_player_parry_success)
	
	if current_level_scene and current_level_scene.has_node("LevelFinish"):
		var level_finish = current_level_scene.get_node("LevelFinish")
		if not level_finish.body_entered.is_connected(_on_level_finish_entered):
			level_finish.body_entered.connect(_on_level_finish_entered)
	
	_setup_pause_button()
	_connect_glits_tracking()
	_setup_timer()

func _setup_pause_button():
	if not (current_level_scene and current_level_scene.has_node("UI/PauseButton")): return
	
	pause_button = current_level_scene.get_node("UI/PauseButton")
	pause_screen = pause_button.get_node("PauseScreen") if pause_button.has_node("PauseScreen") else null
	pause_button.pressed.connect(_on_pause_button_pressed)
	_connect_button_sound(pause_button)
	
	if pause_screen:
		pause_screen.visible = false
		var pause_buttons = [
			{"node": "RetryButton", "method": "_on_pause_retry_button_pressed"},
			{"node": "ContinueButton", "method": "_on_continue_button_pressed"},
			{"node": "HomeButton", "method": "_on_pause_home_button_pressed"}
		]
		
		for btn in pause_buttons:
			if pause_screen.has_node(btn.node):
				var button = pause_screen.get_node(btn.node)
				button.pressed.connect(Callable(self, btn.method))
				_connect_button_sound(button)

func _connect_glits_tracking():
	var paths = ["CoinCounter", "ScoreManager", "UI/CoinCounter", "UI/ScoreManager"]
	for path in paths:
		if current_level_scene and current_level_scene.has_node(path):
			var coin_node = current_level_scene.get_node(path)
			var signal_name = "coin_collected" if coin_node.has_signal("coin_collected") else "point_added"
			if coin_node.has_signal(signal_name):
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
	
	_ensure_result_buttons_connected()
	
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
	
	await get_tree().create_timer(1.0).timeout
	_show_medal(finish_results)
	
	await get_tree().create_timer(1.0).timeout
	
	for button_name in ["RetryButton", "HomeButton"]:
		if finish_results.has_node(button_name):
			var button = finish_results.get_node(button_name)
			button.visible = true
			button.disabled = false
			button.mouse_filter = Control.MOUSE_FILTER_PASS
			print("Made button visible and clickable: ", button_name)
	
	input_blocked = false
	print("Input unblocked, buttons should be clickable now")
	
func _ensure_result_buttons_connected():
	if not finish_results: return
	
	if finish_results.has_node("RetryButton"):
		var retry_button = finish_results.get_node("RetryButton")
		if retry_button.pressed.is_connected(_on_retry_button_pressed):
			retry_button.pressed.disconnect(_on_retry_button_pressed)
		retry_button.pressed.connect(_on_retry_button_pressed)
		retry_button.disabled = false
		retry_button.mouse_filter = Control.MOUSE_FILTER_PASS
		print("Connected RetryButton")
	
	if finish_results.has_node("HomeButton"):
		var home_button = finish_results.get_node("HomeButton")
		if home_button.pressed.is_connected(_on_home_button_pressed):
			home_button.pressed.disconnect(_on_home_button_pressed)
		home_button.pressed.connect(_on_home_button_pressed)
		home_button.disabled = false
		home_button.mouse_filter = Control.MOUSE_FILTER_PASS
		print("Connected HomeButton")

func _hide_results_page():
	if finish_results:
		finish_results.visible = false
		finish_results.process_mode = Node.PROCESS_MODE_INHERIT

func _show_medal(finish_results):
	if finish_results.has_node("Results/Medal"):
		var medal_node = finish_results.get_node("Results/Medal")
		var medal_texture = _get_medal_texture_by_time(elapsed_time)
		if medal_texture and medal_node is Sprite2D:
			medal_node.texture = medal_texture
		medal_node.visible = true

func _get_medal_texture_by_time(time: float) -> Texture2D:
	var level_key = "tutorial" if is_tutorial_mode else current_level_number
	var times = level_medal_times.get(level_key, {"gold": 45.0, "silver": 60.0})
	
	if time <= times.gold: return gold_medal_texture
	elif time <= times.silver: return silver_medal_texture
	else: return bronze_medal_texture

func _get_current_coin_score() -> int:
	var paths = ["CoinCounter", "ScoreManager", "UI/CoinCounter", "UI/ScoreManager"]
	for path in paths:
		if current_level_scene and current_level_scene.has_node(path):
			var node = current_level_scene.get_node(path)
			if node.has_method("add_point") and "score" in node:
				return node.score
	
	var nodes = current_level_scene.find_children("*", "", true, false)
	for node in nodes:
		if node.has_method("add_point") and "score" in node:
			return node.score
	
	return glits_count

func find_player_in_scene() -> Node:
	if not current_level_scene: return null
	
	for path in ["Player", "Player2D", "CharacterBody2D"]:
		if current_level_scene.has_node(path):
			return current_level_scene.get_node(path)
	
	var nodes = current_level_scene.find_children("*", "CharacterBody2D", true, false)
	return nodes[0] if nodes.size() > 0 else null

func _on_pause_button_pressed():
	if not is_paused:
		_pause_game()
	else:
		_unpause_game()

func _pause_game():
	is_paused = true
	get_tree().paused = true
	movement_disabled.emit()
	
	if pause_screen:
		pause_screen.visible = true
		pause_screen.process_mode = Node.PROCESS_MODE_WHEN_PAUSED
		_set_ui_process_mode_recursive(pause_screen, Node.PROCESS_MODE_WHEN_PAUSED)
	
	if pause_button:
		pause_button.process_mode = Node.PROCESS_MODE_WHEN_PAUSED

func _unpause_game():
	is_paused = false
	get_tree().paused = false
	
	if pause_screen: pause_screen.visible = false
	if pause_button: pause_button.process_mode = Node.PROCESS_MODE_INHERIT
	if not input_blocked: movement_enabled.emit()

func _set_ui_process_mode_recursive(node: Node, process_mode: int):
	node.process_mode = process_mode
	for child in node.get_children():
		_set_ui_process_mode_recursive(child, process_mode)

func _on_continue_button_pressed():
	_unpause_game()

func _restart_level_after_curtain():
	get_tree().paused = false
	input_blocked = false
	is_paused = false
	_change_to_level("tutorial" if is_tutorial_mode else current_level_number)

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
func _on_player_damage_taken(): damage_count += 1
func _on_player_parry_success(): parry_count += 1
func _on_glit_collected(): glits_count += 1
