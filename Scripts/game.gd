extends Node

@onready var level_select_menu = $LevelSelectMenu
@onready var black_curtain = $CanvasLayer/BlackCurtain
var current_level_scene = null
var input_blocked = false
var current_level_number = 0
var curtain_transitioning = false

# Game state
var timer_running = false
var elapsed_time = 0.0
var timer_label = null
var damage_count = 0
var parry_count = 0
var glits_count = 0
var is_paused = false
var pause_button = null
var pause_screen = null
var settings_button = null
var settings_screen = null
var finish_results = null
var is_tutorial_mode = false

# Audio
var audio_player: AudioStreamPlayer
var results_audio_player: AudioStreamPlayer
var go_audio_player: AudioStreamPlayer
var music_player: AudioStreamPlayer
var connected_buttons = []
var current_music_theme = ""
var music_fade_tween: Tween
var default_music_volume = 0.0
var is_music_fading = false

signal movement_enabled
signal movement_disabled
signal player_died

# Exports
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
@export var results_thud_sound: AudioStream
@export var go_sound: AudioStream

@export_group("Music Themes")
@export var level_select_theme: AudioStream
@export var forest_theme: AudioStream
@export var beach_theme: AudioStream

@export_group("Music Settings")
@export var music_fade_duration: float = 1.5
@export var music_volume_db: float = 0.0

# Medal requirements
var level_medal_times = {
	"tutorial": {"gold": 999999999.0, "silver": 9999999999999999999.0},
	1: {"gold": 43.0, "silver": 50.0}, 
	2: {"gold": 59.0, "silver": 70.0},
	3: {"gold": 40.0, "silver": 55.0}, 
	4: {"gold": 65.0, "silver": 80.0},
	5: {"gold": 50.0, "silver": 65.0}
}

func _ready():
	_setup_audio_system()
	level_select_menu.level_selected.connect(_on_level_selected)
	
	for button_name in ["TutorialButton", "Level1Button", "Level2Button"]:
		if level_select_menu.has_node(button_name):
			var btn = level_select_menu.get_node(button_name)
			_connect_button_sound(btn)
			if button_name == "TutorialButton":
				btn.pressed.connect(_on_tutorial_button_pressed)
	
	_setup_root_curtain()
	_connect_menu_buttons_sound()
	_play_music("level_select", true)

func _setup_root_curtain():
	if not black_curtain:
		print("ERROR: BlackCurtain node not found!")
		return
	_reset_curtain_position()
	black_curtain.z_index = 1000

func _reset_curtain_position():
	if not black_curtain: return
	black_curtain.position.x = get_viewport().size.x + 300
	black_curtain.visible = false
	curtain_transitioning = false

func _setup_audio_system():
	var players = [
		{"name": "ButtonAudioPlayer", "stream": button_click_sound, "var": "audio_player"},
		{"name": "ResultsAudioPlayer", "stream": results_thud_sound, "var": "results_audio_player"},
		{"name": "GoAudioPlayer", "stream": go_sound, "var": "go_audio_player"}
	]
	
	for p in players:
		var player = AudioStreamPlayer.new()
		player.name = p.name
		player.bus = "SFX"
		if p.stream: player.stream = p.stream
		add_child(player)
		set(p.var, player)
	
	music_player = AudioStreamPlayer.new()
	music_player.name = "MusicPlayer"
	music_player.bus = "Music"
	music_player.volume_db = music_volume_db
	default_music_volume = music_volume_db
	add_child(music_player)

func _play_music(theme_name: String, fade_in: bool = true):
	if current_music_theme == theme_name and music_player.playing and not is_music_fading:
		return
	
	var themes = {"level_select": level_select_theme, "forest": forest_theme, "beach": beach_theme}
	var theme_stream = themes.get(theme_name)
	
	if not theme_stream: return
	if music_player.playing and current_music_theme != theme_name:
		await _fade_out_current_music()
	
	if music_fade_tween: music_fade_tween.kill()
	
	music_player.stream = theme_stream
	current_music_theme = theme_name
	
	if fade_in:
		music_player.volume_db = -80.0
		music_player.play()
		_fade_in_music()
	else:
		music_player.volume_db = default_music_volume
		music_player.play()

func _fade_in_music():
	if not music_player.playing: return
	is_music_fading = true
	music_fade_tween = create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	music_fade_tween.tween_property(music_player, "volume_db", default_music_volume, music_fade_duration)
	await music_fade_tween.finished
	is_music_fading = false

func _fade_out_current_music() -> void:
	if not music_player.playing: return
	is_music_fading = true
	music_fade_tween = create_tween().set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_CUBIC)
	music_fade_tween.tween_property(music_player, "volume_db", -80.0, music_fade_duration)
	await music_fade_tween.finished
	music_player.stop()
	is_music_fading = false

func _connect_menu_buttons_sound():
	for button in level_select_menu.find_children("*", "BaseButton", true, false):
		_connect_button_sound(button)

func _connect_button_sound(button: BaseButton):
	if not button or button in connected_buttons: return
	button.pressed.connect(_play_button_sound)
	connected_buttons.append(button)

func _play_button_sound():
	if audio_player and button_click_sound: audio_player.play()

func _play_results_thud_sound():
	if results_audio_player and results_thud_sound: results_audio_player.play()

func _play_go_sound():
	if go_audio_player and go_sound: go_audio_player.play()

func _process(delta):
	if timer_running and timer_label and not is_paused:
		elapsed_time += delta
		timer_label.text = "%.2f" % elapsed_time

func _input(event):
	if input_blocked: get_viewport().set_input_as_handled()

func _on_level_selected(level_number):
	if curtain_transitioning or level_number not in [1, 2, 3, 4, 5]: return
	is_tutorial_mode = false
	_start_curtain_transition_to_level(level_number)

func _on_tutorial_button_pressed():
	if curtain_transitioning: return
	is_tutorial_mode = true
	_start_curtain_transition_to_level("tutorial")

func _start_curtain_transition_to_level(level_identifier):
	if not black_curtain:
		_change_to_level(level_identifier)
		return
	
	if curtain_transitioning: return
	curtain_transitioning = true
	input_blocked = true
	movement_disabled.emit()
	
	black_curtain.visible = true
	black_curtain.z_index = 1000
	_reset_curtain_position()
	black_curtain.visible = true
	curtain_transitioning = true
	
	var tween = create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tween.tween_property(black_curtain, "position:x", 0, 1.2)
	await tween.finished
	await get_tree().create_timer(0.5).timeout
	
	_change_to_level(level_identifier)
	await get_tree().create_timer(0.3).timeout
	_reveal_scene_with_curtain()

func _reveal_scene_with_curtain():
	if not black_curtain: return
	
	var tween = create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tween.tween_property(black_curtain, "position:x", -1700, 1.3)
	
	if current_level_scene:
		await get_tree().create_timer(0.5).timeout
		_start_countdown()
	
	await tween.finished
	_reset_curtain_position()

func _change_to_level(level_identifier):
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
	
	var level_paths = {
		"tutorial": "res://Scenes/tutorial_holder.tscn",
		1: "res://Scenes/level_1_holder.tscn",
		2: "res://Scenes/level_2_holder.tscn",
		3: "res://Scenes/level_3_holder.tscn",
		4: "res://Scenes/level_4_holder.tscn",
		5: "res://Scenes/level_5_holder.tscn"
	}
	
	var level_path = level_paths.get(level_identifier if is_tutorial_mode else int(level_identifier))
	if not level_path or not ResourceLoader.exists(level_path):
		print("ERROR: Scene file not found: ", level_path)
		return
	
	current_level_scene = load(level_path).instantiate()
	add_child(current_level_scene)
	await get_tree().process_frame
	
	if current_level_scene and current_level_scene.has_node("UI/BlackCurtainTransition"):
		current_level_scene.get_node("UI/BlackCurtainTransition").visible = false
	
	_switch_to_player_camera()
	_setup_connections()
	_switch_level_music(level_identifier)

func _switch_level_music(level_identifier):
	var theme = "forest"
	if level_identifier == 2:
		theme = "beach"
	_play_music(theme, true)

func _switch_to_player_camera():
	var menu_camera = level_select_menu.get_node("Camera2D") if level_select_menu.has_node("Camera2D") else null
	var player = find_player_in_scene()
	var player_camera = _find_player_camera(player) if player else null
	
	if menu_camera: menu_camera.enabled = false
	if player_camera: 
		player_camera.enabled = true
		player_camera.make_current()

func _find_player_camera(player):
	if not player: return null
	if player.has_node("Camera2D"): return player.get_node("Camera2D")
	var cameras = player.find_children("*", "Camera2D", true, false)
	return cameras[0] if cameras.size() > 0 else null

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
		{"text": "READY?", "color": ready_color, "time": 1.0, "sound": "thud"},
		{"text": "SET...", "color": set_color, "time": 1.0, "sound": "thud"},
		{"text": "GO!!", "color": go_color, "time": 0.5, "sound": "go"}
	]
	
	for data in countdown_data:
		countdown_label.text = data.text
		countdown_label.modulate = data.color
		
		if data.sound == "go": _play_go_sound()
		else: _play_results_thud_sound()
		
		await get_tree().create_timer(data.time).timeout
		
		if data.text == "GO!!":
			var player = find_player_in_scene()
			if player and player.has_method("enable_movement_at_level_start"):
				player.enable_movement_at_level_start()
	
	countdown_label.visible = false
	input_blocked = false
	movement_enabled.emit()
	_start_timer()

func _on_retry_button_pressed():
	if curtain_transitioning: return
	_hide_results_page()
	_start_curtain_transition_to_level("tutorial" if is_tutorial_mode else current_level_number)

func _on_pause_retry_button_pressed():
	if curtain_transitioning: return
	_unpause_game()
	_start_curtain_transition_to_level("tutorial" if is_tutorial_mode else current_level_number)

func _on_home_button_pressed():
	if curtain_transitioning: return
	_hide_results_page()
	_start_curtain_transition_to_menu()

func _start_curtain_transition_to_menu():
	if not black_curtain:
		return_to_menu()
		return
	
	if curtain_transitioning: return
	curtain_transitioning = true
	input_blocked = true
	movement_disabled.emit()
	
	black_curtain.visible = true
	black_curtain.z_index = 1000
	_reset_curtain_position()
	black_curtain.visible = true
	curtain_transitioning = true
	
	var tween = create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tween.tween_property(black_curtain, "position:x", 0, 1.2)
	await tween.finished
	await get_tree().create_timer(0.5).timeout
	
	return_to_menu()
	await get_tree().create_timer(0.3).timeout
	_reveal_menu_with_curtain()

func _reveal_menu_with_curtain():
	if not black_curtain: return
	var tween = create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tween.tween_property(black_curtain, "position:x", -1700, 1.3)
	await tween.finished
	_reset_curtain_position()

func _on_pause_home_button_pressed():
	if curtain_transitioning: return
	_unpause_game()
	_start_curtain_transition_to_menu()

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
	_play_music("level_select", true)

func _setup_connections():
	var player = find_player_in_scene()
	if player:
		if not movement_disabled.is_connected(player._on_movement_disabled):
			movement_disabled.connect(player._on_movement_disabled)
		if not movement_enabled.is_connected(player._on_movement_enabled):
			movement_enabled.connect(player._on_movement_enabled)
		if not player.player_died_trigger_retry.is_connected(_on_player_died_trigger_retry):
			player.player_died_trigger_retry.connect(_on_player_died_trigger_retry)
		
		if player.has_node("HealthScript"):
			var health_script = player.get_node("HealthScript")
			if not health_script.died.is_connected(_on_player_died):
				health_script.died.connect(_on_player_died)
			if not health_script.health_decreased.is_connected(_on_player_damage_taken):
				health_script.health_decreased.connect(_on_player_damage_taken)
		
		if player.has_signal("parry_success") and not player.parry_success.is_connected(_on_player_parry_success):
			player.parry_success.connect(_on_player_parry_success)
	
	if current_level_scene and current_level_scene.has_node("LevelFinish"):
		var level_finish = current_level_scene.get_node("LevelFinish")
		if not level_finish.body_entered.is_connected(_on_level_finish_entered):
			level_finish.body_entered.connect(_on_level_finish_entered)
	
	_setup_pause_button()
	_setup_settings_button()
	_connect_glits_tracking()
	_setup_timer()

# Replace _on_player_died_trigger_retry() in your game manager with:
func _on_player_died_trigger_retry():
	if curtain_transitioning: return
	_stop_timer()
	input_blocked = true
	movement_disabled.emit()
	
	# Check if player has an active checkpoint
	var player = find_player_in_scene()
	if player and player.has_method("respawn_at_checkpoint") and player.has_active_checkpoint:
		# Respawn at checkpoint instead of restarting level
		await get_tree().create_timer(0.5).timeout
		await _respawn_player_at_checkpoint(player)
	else:
		# No checkpoint - restart level as before
		_start_curtain_transition_to_level("tutorial" if is_tutorial_mode else current_level_number)

# Replace _on_player_died() in your game manager with:
func _on_player_died():
	if curtain_transitioning: return
	_stop_timer()
	input_blocked = true
	movement_disabled.emit()
	
	await get_tree().create_timer(1.5).timeout
	
	# Check if player has an active checkpoint
	var player = find_player_in_scene()
	if player and player.has_method("respawn_at_checkpoint") and player.has_active_checkpoint:
		# Respawn at checkpoint instead of restarting level
		await _respawn_player_at_checkpoint(player)
	else:
		# No checkpoint - restart level as before
		_start_curtain_transition_to_level("tutorial" if is_tutorial_mode else current_level_number)

func _respawn_player_at_checkpoint(player):
	# Reset timescale FIRST
	Engine.time_scale = 1.0
	
	# Disable collision temporarily
	if player.has_node("CollisionShape2D"):
		player.get_node("CollisionShape2D").disabled = true
	
	# Move player to checkpoint position
	player.respawn_at_checkpoint()
	
	# Reset player state
	if player.has_method("reset_player_state"):
		player.reset_player_state()
	
	# Wait for physics to settle
	await get_tree().process_frame
	await get_tree().process_frame
	
	# Reset health with FULL invulnerability
	if player.has_node("HealthScript"):
		var health_script = player.get_node("HealthScript")
		health_script.current_health = health_script.max_health
		health_script.health_changed.emit(health_script.current_health)
		health_script.is_invulnerable = true  # Grant invulnerability
		health_script.is_flickering = false
		
		# Stop any timers
		if health_script.iframe_timer:
			health_script.iframe_timer.stop()
		if health_script.flicker_timer:
			health_script.flicker_timer.stop()
		
		# Force reset transparency
		if health_script.has_method("force_reset_transparency"):
			health_script.force_reset_transparency()
		
		# Start a respawn invulnerability period (2 seconds)
		health_script.iframe_timer.wait_time = 2.0
		health_script.iframe_timer.start()
	
	# Re-enable collision
	if player.has_node("CollisionShape2D"):
		player.get_node("CollisionShape2D").disabled = false
	
	# Wait one more frame
	await get_tree().process_frame
	
	# Re-enable movement
	input_blocked = false
	movement_enabled.emit()
	_start_timer()  # Resume timer from where it was
	
	print("Player respawned at checkpoint with 2s invulnerability")


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

func _setup_settings_button():
	if not (current_level_scene and current_level_scene.has_node("UI/SettingsButton")): return
	
	settings_button = current_level_scene.get_node("UI/SettingsButton")
	settings_screen = settings_button.get_node("SettingsScreen") if settings_button.has_node("SettingsScreen") else null
	settings_button.pressed.connect(_on_settings_button_pressed)
	_connect_button_sound(settings_button)
	
	if settings_screen:
		settings_screen.visible = false
		# Only connect Continue button for settings
		if settings_screen.has_node("ContinueButton"):
			var button = settings_screen.get_node("ContinueButton")
			button.pressed.connect(_on_settings_continue_button_pressed)
			_connect_button_sound(button)

func _connect_glits_tracking():
	for path in ["CoinCounter", "ScoreManager", "UI/CoinCounter", "UI/ScoreManager"]:
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
		{"path": "Results/Time", "text": "TIME................%.2f" % elapsed_time, "delay": 1.0, "play_sound": true},
		{"path": "Results/Damage", "text": "DAMAGE.............%d" % damage_count, "delay": 0.5, "play_sound": true},
		{"path": "Results/Parries", "text": "PARRIES............%d" % parry_count, "delay": 0.5, "play_sound": true},
		{"path": "Results/Glits", "text": "GLITS...............%d" % _get_current_coin_score(), "delay": 0.5, "play_sound": true},
		{"path": "Results/FinalResult", "text": "", "delay": 1.0, "play_sound": false}
	]
	
	for data in results_data:
		await get_tree().create_timer(data.delay).timeout
		if finish_results.has_node(data.path):
			var label = finish_results.get_node(data.path)
			label.visible = true
			if data.text: label.text = data.text
			if data.play_sound: _play_results_thud_sound()
	
	await get_tree().create_timer(1.0).timeout
	_show_medal(finish_results)
	await get_tree().create_timer(1.0).timeout
	
	for button_name in ["RetryButton", "HomeButton"]:
		if finish_results.has_node(button_name):
			var button = finish_results.get_node(button_name)
			button.visible = true
			button.disabled = false
			button.mouse_filter = Control.MOUSE_FILTER_PASS
	
	input_blocked = false

func _ensure_result_buttons_connected():
	if not finish_results: return
	
	for btn_data in [{"name": "RetryButton", "func": _on_retry_button_pressed}, {"name": "HomeButton", "func": _on_home_button_pressed}]:
		if finish_results.has_node(btn_data.name):
			var button = finish_results.get_node(btn_data.name)
			if button.pressed.is_connected(btn_data.func):
				button.pressed.disconnect(btn_data.func)
			button.pressed.connect(btn_data.func)
			button.disabled = false
			button.mouse_filter = Control.MOUSE_FILTER_PASS
			_connect_button_sound(button)

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
		_play_results_thud_sound()

func _get_medal_texture_by_time(time: float) -> Texture2D:
	var level_key = "tutorial" if is_tutorial_mode else current_level_number
	var times = level_medal_times.get(level_key, {"gold": 45.0, "silver": 60.0})
	
	if time <= times.gold: return gold_medal_texture
	elif time <= times.silver: return silver_medal_texture
	else: return bronze_medal_texture

func _get_current_coin_score() -> int:
	for path in ["CoinCounter", "ScoreManager", "UI/CoinCounter", "UI/ScoreManager"]:
		if current_level_scene and current_level_scene.has_node(path):
			var node = current_level_scene.get_node(path)
			if node.has_method("add_point") and "score" in node:
				return node.score
	
	for node in current_level_scene.find_children("*", "", true, false):
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
	if not is_paused: _pause_game()
	else: _unpause_game()

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

func _on_settings_button_pressed():
	if not is_paused: _pause_game_for_settings()
	else: _unpause_game_from_settings()

func _pause_game_for_settings():
	is_paused = true
	get_tree().paused = true
	movement_disabled.emit()
	
	if settings_screen:
		settings_screen.visible = true
		settings_screen.process_mode = Node.PROCESS_MODE_WHEN_PAUSED
		_set_ui_process_mode_recursive(settings_screen, Node.PROCESS_MODE_WHEN_PAUSED)
	
	if settings_button:
		settings_button.process_mode = Node.PROCESS_MODE_WHEN_PAUSED

func _on_settings_continue_button_pressed():
	_unpause_game_from_settings()

func _unpause_game_from_settings():
	is_paused = false
	get_tree().paused = false
	if settings_screen: settings_screen.visible = false
	if settings_button: settings_button.process_mode = Node.PROCESS_MODE_INHERIT
	if not input_blocked: movement_enabled.emit()

func _on_player_damage_taken(): damage_count += 1
func _on_player_parry_success(): parry_count += 1
func _on_glit_collected(): glits_count += 1
