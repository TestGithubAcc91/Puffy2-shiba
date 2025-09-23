# Game.gd - Simplified curtain transitions with root-level black curtain
extends Node

@onready var level_select_menu = $LevelSelectMenu
# SIMPLIFIED: Single black curtain on the root Game node
@onready var black_curtain = $CanvasLayer/BlackCurtain  # This should be a child of the Game node
var current_level_scene = null
var input_blocked = false
var current_level_number = 0

# Game state tracking - UNCHANGED
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

# Audio system - UNCHANGED
var audio_player: AudioStreamPlayer
var connected_buttons = []

# Signals - UNCHANGED
signal movement_enabled
signal movement_disabled

# Export settings - UNCHANGED
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

# Level medal requirements - UNCHANGED
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
	
	_setup_root_curtain()
	_connect_menu_buttons_sound()

func _setup_root_curtain():
	"""Initialize the root-level black curtain"""
	if not black_curtain:
		print("ERROR: BlackCurtain node not found! Please add a ColorRect named 'BlackCurtain' as child of Game node")
		return
	
	# Position curtain off-screen to the right with 100px offset
	black_curtain.position.x = get_viewport().size.x + 300
	black_curtain.z_index = 1000  # Ensure it's always on top
	
	print("Root curtain initialized at position: ", black_curtain.position)

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

func _process(delta):
	if timer_running and timer_label and not is_paused:
		elapsed_time += delta
		timer_label.text = "%.2f" % elapsed_time

func _input(event):
	if input_blocked: get_viewport().set_input_as_handled()

func _on_level_selected(level_number):
	is_tutorial_mode = false
	_start_curtain_transition_to_level(level_number)

func _on_tutorial_button_pressed():
	is_tutorial_mode = true
	_start_curtain_transition_to_level("tutorial")

# SIMPLIFIED: Single curtain transition function for scene changes to levels
func _start_curtain_transition_to_level(level_identifier):
	"""Simplified curtain transition using root-level curtain"""
	if not black_curtain:
		_change_to_level(level_identifier)
		return
	
	print("Starting curtain transition to level: ", level_identifier)
	
	# Block input during transition
	input_blocked = true
	movement_disabled.emit()
	
	# Ensure curtain is properly positioned and visible
	black_curtain.visible = true
	black_curtain.z_index = 1000
	var viewport_size = get_viewport().size
	
	# Start curtain off-screen to the right with 100px offset
	black_curtain.position.x = viewport_size.x + 300
	
	# Phase 1: Move curtain to cover screen
	var tween = create_tween()
	tween.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tween.tween_property(black_curtain, "position:x", 0, 1.2)
	
	# Wait for curtain to cover screen
	await tween.finished
	await get_tree().create_timer(0.5).timeout  # Brief pause in black
	
	# Phase 2: Change scene while covered
	_change_to_level(level_identifier)
	
	# Phase 3: Reveal new scene
	await get_tree().create_timer(0.3).timeout
	_reveal_scene_with_curtain()

func _reveal_scene_with_curtain():
	"""Move curtain to reveal the new scene"""
	if not black_curtain:
		return
	
	print("Revealing scene with curtain")
	
	var viewport_size = get_viewport().size
	var tween = create_tween()
	tween.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	
	# Move curtain off-screen to the left with 100px offset
	tween.tween_property(black_curtain, "position:x", -1700, 1.3)
	
	# Start countdown while curtain is revealing (if in level)
	if current_level_scene:
		await get_tree().create_timer(0.5).timeout
		_start_countdown()
	
	# Hide curtain when animation is complete
	await tween.finished
	black_curtain.visible = false

# SIMPLIFIED: Level change function (keeping original logic intact)
func _change_to_level(level_identifier):
	"""ORIGINAL level change logic - UNCHANGED"""
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
	
	# DISABLE any level-specific BlackCurtainTransition ColorRects
	if current_level_scene and current_level_scene.has_node("UI/BlackCurtainTransition"):
		var transition_rect = current_level_scene.get_node("UI/BlackCurtainTransition")
		transition_rect.visible = false
		print("Disabled level-specific BlackCurtainTransition ColorRect")
	
	_switch_to_player_camera()
	_setup_connections()

func _switch_to_player_camera():
	"""ORIGINAL camera switch logic - UNCHANGED (no curtain management)"""
	var menu_camera = level_select_menu.get_node("Camera2D") if level_select_menu.has_node("Camera2D") else null
	var player = find_player_in_scene()
	var player_camera = _find_player_camera(player) if player else null
	
	if menu_camera: 
		menu_camera.enabled = false
	if player_camera: 
		player_camera.enabled = true
		player_camera.make_current()

func _find_player_camera(player):
	if not player: return null
	if player.has_node("Camera2D"): return player.get_node("Camera2D")
	var cameras = player.find_children("*", "Camera2D", true, false)
	return cameras[0] if cameras.size() > 0 else null

# SIMPLIFIED: Retry function using root curtain
func _on_retry_button_pressed():
	print("RETRY BUTTON PRESSED - Using simplified retry")
	_hide_results_page()
	
	var level_identifier = "tutorial" if is_tutorial_mode else current_level_number
	_start_curtain_transition_to_level(level_identifier)

func _on_pause_retry_button_pressed():
	print("PAUSE RETRY BUTTON PRESSED - Using simplified retry")
	_unpause_game()
	
	var level_identifier = "tutorial" if is_tutorial_mode else current_level_number
	_start_curtain_transition_to_level(level_identifier)

func _on_home_button_pressed():
	print("HOME BUTTON PRESSED - Using simplified home transition")  
	_hide_results_page()
	_start_curtain_transition_to_menu()

func _start_curtain_transition_to_menu():
	"""Simplified curtain transition from level to menu"""
	if not black_curtain:
		return_to_menu()
		return
	
	print("Starting curtain transition to menu")
	
	# Block input during transition
	input_blocked = true
	movement_disabled.emit()
	
	# Ensure curtain is properly positioned and visible
	black_curtain.visible = true
	black_curtain.z_index = 1000
	var viewport_size = get_viewport().size
	
	# Start curtain off-screen to the right with 100px offset
	black_curtain.position.x = viewport_size.x + 300
	
	# Phase 1: Move curtain to cover current scene
	var tween = create_tween()
	tween.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tween.tween_property(black_curtain, "position:x", 0, 1.2)
	
	# Wait for curtain to cover screen
	await tween.finished
	await get_tree().create_timer(0.5).timeout
	
	# Phase 2: Return to menu while covered
	return_to_menu()
	
	# Phase 3: Reveal menu
	await get_tree().create_timer(0.3).timeout
	_reveal_menu_with_curtain()

	
	
func _reveal_menu_with_curtain():
	"""Move curtain to reveal the menu"""
	if not black_curtain:
		return
	
	print("Revealing menu with curtain")
	
	var viewport_size = get_viewport().size
	var tween = create_tween()
	tween.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	
	# Move curtain off-screen to the left with 100px offset to reveal menu
	tween.tween_property(black_curtain, "position:x", -1700, 1.3)
	
	# Hide curtain when animation is complete
	await tween.finished
	black_curtain.visible = false

# UPDATE PAUSE SYSTEM HANDLERS
func _on_pause_home_button_pressed():
	_unpause_game()
	_start_curtain_transition_to_menu()

# ORIGINAL return_to_menu function - COMPLETELY UNCHANGED
func return_to_menu():
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

# ALL OTHER EXISTING FUNCTIONS - COMPLETELY UNCHANGED
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

# Signal handlers - UNCHANGED
func _on_player_damage_taken(): damage_count += 1
func _on_player_parry_success(): parry_count += 1
func _on_glit_collected(): glits_count += 1
