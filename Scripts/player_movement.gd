extends CharacterBody2D

const SPEED = 150.0
const JUMP_VELOCITY = -200.0
const HIGH_JUMP_VELOCITY = -350.0

@onready var animated_sprite: AnimatedSprite2D = $MainSprite
@onready var glint_sprite: AnimatedSprite2D = $GlintSprite
@onready var zipline_friction: AnimatedSprite2D = $ZiplineFriction
@onready var parry_spark: Sprite2D = $ParrySpark
@onready var parry_ready_sprite: Sprite2D = $ParryReady
@onready var health_script = $HealthScript
@onready var vine_component = $VineComponent

@export var air_puff_scene: PackedScene
@export var air_puffV_scene: PackedScene
@export var parry_ready_texture: Texture2D
@export var parry_not_ready_texture: Texture2D

var whoosh_audio_player: AudioStreamPlayer
var parry_audio_player: AudioStreamPlayer
var zipline_audio_player: AudioStreamPlayer
var click_audio_player: AudioStreamPlayer
@export_group("Audio")
@export var whoosh_sound: AudioStream
@export var parry_success_sound: AudioStream
@export var zipline_sound: AudioStream
@export var click_sound: AudioStream

var last_attack_was_unparryable: bool = false
signal parry_success
signal player_died_trigger_retry

var parry_timer: Timer
var is_parrying: bool = false
@export var parry_duration: float = 0.4
@export var parry_success_cooldown: float = 0.0
@export var parry_fail_cooldown: float = 1.0
var parry_cooldown_timer: Timer
var can_parry: bool = true
var parry_was_successful: bool = false
var was_invulnerable_before_parry: bool = false

var parry_freeze_timer: Timer
var is_in_parry_freeze: bool = false
var parry_pre_freeze_timer: Timer
var is_in_pre_freeze_parry: bool = false
@export var parry_freeze_duration: float = 0.3
@export var parry_pre_freeze_duration: float = 0.1

var parry_safety_timer: Timer
@export var parry_safety_duration: float = 2.0

@export var max_parry_stacks: int = 3
var current_parry_stacks: int = 0
signal parry_stacks_changed(new_stacks: int)

@export var charge_texture_1: Texture2D
@export var charge_texture_2: Texture2D
@export var charge_texture_3: Texture2D
@export var charge_texture_4: Texture2D
@export var empty_charge_texture: Texture2D
@export var empty_charge_sprite_1: Sprite2D
@export var empty_charge_sprite_2: Sprite2D
@export var empty_charge_sprite_3: Sprite2D

var empty_charge_sprites: Array[Sprite2D] = []
var charge_textures: Array[Texture2D] = []
var assigned_textures: Array[Texture2D] = []

@export var dash_distance: float = 200.0
@export var dash_speed: float = 800.0
@export var dash_cooldown: float = 0.5
@export var wall_bounce_force: Vector2 = Vector2(300.0, -150.0)
@export var bounce_delay: float = 0.2
@export var bounce_distance: float = 150.0
@export var bounce_speed: float = 600.0
@export var high_jump_cooldown: float = 2.0

@export var coyote_time_duration: float = 0.1
var coyote_time_timer: Timer
var can_coyote_jump: bool = false

var high_jump_cooldown_timer: Timer
var can_high_jump: bool = true
var dash_timer: Timer
var dash_cooldown_timer: Timer
var bounce_timer: Timer
var is_dashing: bool = false
var can_dash: bool = true
var dash_direction: Vector2 = Vector2.ZERO
var dash_started_on_ground: bool = false
var was_on_ground_before_dash: bool = false
var dash_start_time: float = 0.0
var dash_duration: float = 0.0
var is_bouncing: bool = false
var bounce_start_time: float = 0.0
var bounce_duration: float = 0.0
var bounce_direction_vector: Vector2 = Vector2.ZERO

var is_vine_release_dash: bool = false

var zipline_in_range: Zipline = null
var is_on_zipline: bool = false
var current_zipline: Zipline = null
var zipline_grab_position: float = 0.0

var movement_blocked_by_game: bool = false
var original_time_scale: float = 1.0
var was_on_floor_last_frame: bool = false

var movement_blocked_at_level_start: bool = true

func _ready():
	original_time_scale = Engine.time_scale
	movement_blocked_at_level_start = true
	_setup_audio_system()
	health_script.died.connect(_on_player_died)
	setup_charge_system()
	setup_ui()
	setup_durations()
	setup_timers()
	update_parry_ready_sprite()

func _setup_audio_system():
	whoosh_audio_player = AudioStreamPlayer.new()
	whoosh_audio_player.name = "WhooshAudioPlayer"
	whoosh_audio_player.bus = "SFX"
	if whoosh_sound: whoosh_audio_player.stream = whoosh_sound
	add_child(whoosh_audio_player)
	
	parry_audio_player = AudioStreamPlayer.new()
	parry_audio_player.name = "ParryAudioPlayer"
	parry_audio_player.bus = "SFX"
	if parry_success_sound: parry_audio_player.stream = parry_success_sound
	add_child(parry_audio_player)
	
	zipline_audio_player = AudioStreamPlayer.new()
	zipline_audio_player.name = "ZiplineAudioPlayer"
	zipline_audio_player.bus = "SFX"
	if zipline_sound: zipline_audio_player.stream = zipline_sound
	add_child(zipline_audio_player)
	
	click_audio_player = AudioStreamPlayer.new()
	click_audio_player.name = "ClickAudioPlayer"
	click_audio_player.bus = "SFX"
	if click_sound: click_audio_player.stream = click_sound
	add_child(click_audio_player)

func enable_movement_at_level_start():
	movement_blocked_at_level_start = false

func _play_whoosh_sound():
	if whoosh_audio_player and whoosh_sound: whoosh_audio_player.play()

func _play_parry_success_sound():
	if parry_audio_player and parry_success_sound: parry_audio_player.play()

func _play_zipline_sound():
	if zipline_audio_player and zipline_sound and not zipline_audio_player.playing: zipline_audio_player.play()

func _stop_zipline_sound():
	if zipline_audio_player and zipline_audio_player.playing: zipline_audio_player.stop()

func _play_click_sound():
	if click_audio_player and click_sound: click_audio_player.play()

func setup_ui():
	if glint_sprite: glint_sprite.visible = false
	if zipline_friction: zipline_friction.visible = false
	if parry_spark: parry_spark.visible = false

func setup_durations():
	dash_duration = dash_distance / dash_speed
	bounce_duration = bounce_distance / bounce_speed

func setup_timers():
	var timer_configs = [
		{timer = "parry_timer", wait_time = parry_duration, callback = "_on_parry_timeout"},
		{timer = "parry_cooldown_timer", callback = "_on_parry_cooldown_timeout"},
		{timer = "parry_pre_freeze_timer", wait_time = parry_pre_freeze_duration, callback = "_on_parry_pre_freeze_timeout"},
		{timer = "parry_freeze_timer", wait_time = parry_freeze_duration, callback = "_on_parry_freeze_timeout"},
		{timer = "parry_safety_timer", wait_time = parry_safety_duration, callback = "_on_parry_safety_timeout"},
		{timer = "dash_timer", wait_time = dash_duration, callback = "_on_dash_timeout"},
		{timer = "dash_cooldown_timer", wait_time = dash_cooldown, callback = "_on_dash_cooldown_timeout"},
		{timer = "bounce_timer", wait_time = bounce_delay, callback = "_on_bounce_timeout"},
		{timer = "high_jump_cooldown_timer", wait_time = high_jump_cooldown, callback = "_on_high_jump_cooldown_timeout"},
		{timer = "coyote_time_timer", wait_time = coyote_time_duration, callback = "_on_coyote_time_timeout"}
	]
	
	for config in timer_configs:
		var timer = Timer.new()
		if "wait_time" in config: timer.wait_time = config.wait_time
		timer.one_shot = true
		timer.timeout.connect(Callable(self, config.callback))
		add_child(timer)
		set(config.timer, timer)

func update_parry_ready_sprite():
	if not parry_ready_sprite: return
	if can_parry:
		if parry_ready_texture: parry_ready_sprite.texture = parry_ready_texture
		parry_ready_sprite.visible = true
	else:
		if parry_not_ready_texture: parry_ready_sprite.texture = parry_not_ready_texture
		parry_ready_sprite.visible = true

func _physics_process(delta: float) -> void:
	_check_and_fix_timescale()
	_check_zipline_sound_state()
	handle_coyote_time()
	handle_input()
	handle_movement(delta)
	update_zipline_friction_vfx()

func _check_zipline_sound_state():
	if zipline_audio_player and zipline_audio_player.playing and not is_on_zipline: _stop_zipline_sound()

func _check_and_fix_timescale():
	if not is_parrying and not is_in_parry_freeze and not is_in_pre_freeze_parry:
		if Engine.time_scale != original_time_scale:
			Engine.time_scale = original_time_scale

func handle_coyote_time():
	var is_currently_on_floor = is_on_floor()
	if was_on_floor_last_frame and not is_currently_on_floor and not is_on_zipline:
		can_coyote_jump = true
		coyote_time_timer.start()
	elif is_currently_on_floor:
		can_coyote_jump = false
		coyote_time_timer.stop()
	was_on_floor_last_frame = is_currently_on_floor

func can_jump() -> bool:
	return is_on_floor() or can_coyote_jump

func handle_input():
	if movement_blocked_by_game or movement_blocked_at_level_start: return
	
	var is_on_vine = vine_component && vine_component.is_swinging
	var is_on_zipline_check = is_on_zipline
	
	if Input.is_action_just_pressed("Jump") and zipline_in_range and not is_on_vine and not is_on_zipline_check: grab_zipline()
	elif Input.is_action_just_pressed("Jump") and is_on_zipline_check: release_zipline()
	
	if Input.is_action_just_pressed("Dash") and can_dash and current_parry_stacks >= 1 and not is_on_vine and not is_on_zipline_check: activate_dash()
	
	if Input.is_action_just_pressed("Jump") and can_jump() and not is_on_zipline_check:
		velocity.y = JUMP_VELOCITY
		if can_coyote_jump and not is_on_floor():
			can_coyote_jump = false
			coyote_time_timer.stop()
	
	if Input.is_action_just_pressed("HighJump") and can_jump() and can_high_jump and current_parry_stacks >= 2 and not is_on_vine and not is_on_zipline_check:
		activate_high_jump()
		if can_coyote_jump and not is_on_floor():
			can_coyote_jump = false
			coyote_time_timer.stop()
	
	if Input.is_action_just_pressed("Parry") and can_parry and not is_on_vine: activate_parry()

func handle_movement(delta: float):
	if is_on_zipline: handle_zipline_movement(delta)
	elif is_dashing: handle_dash_movement(delta)
	elif is_bouncing: handle_bounce_movement(delta)
	else: handle_normal_movement(delta)

func handle_dash_movement(delta: float):
	velocity.x = dash_direction.x * (dash_distance / dash_duration)
	var current_time = Time.get_ticks_msec() / 1000.0
	var dash_elapsed = current_time - dash_start_time
	var dash_progress = dash_elapsed / dash_duration
	
	if is_vine_release_dash:
		if not is_on_floor(): velocity += get_gravity() * delta
	else:
		if dash_progress < 0.5: velocity.y = 0.0
		else:
			if not is_on_floor(): velocity += get_gravity() * delta
	
	move_and_slide()
	if is_on_wall_only():
		handle_wall_bounce()
		return
	check_dash_ground_landing()

func handle_bounce_movement(delta: float):
	var current_time = Time.get_ticks_msec() / 1000.0
	var bounce_elapsed = current_time - bounce_start_time
	
	if bounce_elapsed >= bounce_duration: end_bounce()
	else: velocity.x = bounce_direction_vector.x * (bounce_distance / bounce_duration)
	
	if not is_on_floor(): velocity += get_gravity() * delta
	move_and_slide()

func handle_normal_movement(delta: float):
	if not is_on_floor(): velocity += get_gravity() * delta
	var direction := get_effective_horizontal_input()
	update_sprite_direction(direction)
	update_animations(direction)
	
	if direction: velocity.x = direction * SPEED
	else: velocity.x = move_toward(velocity.x, 0, SPEED * 0.3)
	move_and_slide()

func get_effective_horizontal_input() -> float:
	if movement_blocked_by_game or movement_blocked_at_level_start: return 0.0
	if (vine_component and vine_component.is_swinging and vine_component.inputs_blocked) or is_on_zipline: return 0.0
	return Input.get_axis("Move_Left", "Move_Right")

func update_sprite_direction(direction: float):
	if direction > 0:
		animated_sprite.flip_h = false
		if glint_sprite: glint_sprite.position.x = abs(glint_sprite.position.x) * -1
		if zipline_friction: zipline_friction.flip_h = false
	elif direction < 0:
		animated_sprite.flip_h = true
		if glint_sprite: glint_sprite.position.x = abs(glint_sprite.position.x)
		if zipline_friction: zipline_friction.flip_h = true

func update_animations(direction: float):
	if not is_in_pre_freeze_parry and not is_dashing:
		if is_on_zipline:
			if is_parrying or is_in_parry_freeze: animated_sprite.play("Parry")
			else: animated_sprite.play("Jump")
		elif is_on_floor(): animated_sprite.play("Idle" if direction == 0 else "Run")
		else: animated_sprite.play("Jump")

func update_zipline_friction_vfx():
	if not zipline_friction: return
	if is_on_zipline and current_zipline:
		zipline_friction.visible = true
		if not zipline_friction.is_playing(): zipline_friction.play("default")
		if animated_sprite.flip_h: zipline_friction.position.x = abs(zipline_friction.position.x)
		else: zipline_friction.position.x = abs(zipline_friction.position.x) * -1
	else:
		if zipline_friction.visible:
			zipline_friction.visible = false
			zipline_friction.stop()

func spawn_air_puff(): spawn_air_effect(air_puff_scene, Vector2(0, -6), false)
func spawn_air_puffV(): spawn_air_effect(air_puffV_scene, Vector2(0, -6), true)

func spawn_air_effect(scene: PackedScene, offset: Vector2, is_vertical: bool):
	if not scene: return
	var air_puff = scene.instantiate()
	get_parent().add_child(air_puff)
	air_puff.global_position = global_position + offset
	
	if is_vertical: air_puff.rotation_degrees = -90
	elif air_puff.has_method("set_direction"): air_puff.set_direction(dash_direction)
	elif air_puff is AnimatedSprite2D: air_puff.flip_h = (dash_direction.x < 0)
	setup_air_puff_cleanup(air_puff)

func setup_air_puff_cleanup(air_puff):
	if air_puff is AnimatedSprite2D:
		air_puff.animation_finished.connect(func(): air_puff.queue_free())
		var cleanup_timer = Timer.new()
		cleanup_timer.wait_time = 2.0
		cleanup_timer.one_shot = true
		cleanup_timer.timeout.connect(func(): 
			if is_instance_valid(air_puff): air_puff.queue_free()
			cleanup_timer.queue_free()
		)
		air_puff.add_child(cleanup_timer)
		cleanup_timer.start()

func activate_parry():
	if not can_parry: return
	_reset_all_parry_states()
	was_invulnerable_before_parry = health_script.is_invulnerable
	is_parrying = true
	can_parry = false
	parry_was_successful = false
	health_script.is_invulnerable = true
	update_parry_ready_sprite()
	
	if glint_sprite:
		glint_sprite.visible = true
		glint_sprite.play("default")
	
	parry_timer.start()
	parry_safety_timer.start()
	if is_on_zipline: animated_sprite.play("Parry")

func _reset_all_parry_states():
	is_parrying = false
	is_in_parry_freeze = false
	is_in_pre_freeze_parry = false
	parry_was_successful = false
	
	if parry_timer: parry_timer.stop()
	if parry_pre_freeze_timer: parry_pre_freeze_timer.stop()
	if parry_freeze_timer: parry_freeze_timer.stop()
	if parry_safety_timer: parry_safety_timer.stop()
	
	if glint_sprite:
		glint_sprite.visible = false
		glint_sprite.stop()
	if parry_spark: parry_spark.visible = false
	Engine.time_scale = original_time_scale

func on_parry_success():
	parry_was_successful = true
	add_parry_stack()
	last_attack_was_unparryable = false
	is_parrying = false
	can_parry = true
	is_in_pre_freeze_parry = true
	update_parry_ready_sprite()
	_play_parry_success_sound()
	parry_pre_freeze_timer.start()
	call_deferred("_play_parry_animation")
	parry_success.emit()

func _play_parry_animation():
	if is_in_pre_freeze_parry:
		animated_sprite.play("Parry")
		if parry_spark: parry_spark.visible = true

func activate_dash():
	if not can_dash or is_dashing or current_parry_stacks < 1: return
	consume_parry_stack()
	dash_started_on_ground = is_on_floor()
	was_on_ground_before_dash = dash_started_on_ground
	dash_start_time = Time.get_ticks_msec() / 1000.0
	dash_direction = Vector2.LEFT if animated_sprite.flip_h else Vector2.RIGHT
	is_dashing = true
	can_dash = false
	is_vine_release_dash = false
	_play_whoosh_sound()
	spawn_air_puff()
	animated_sprite.play("Dash")
	dash_timer.start()
	dash_cooldown_timer.start()

func play_vine_dismount_sound(): _play_whoosh_sound()
func play_vine_mount_sound(): _play_click_sound()

func activate_high_jump():
	if not can_high_jump or current_parry_stacks < 2: return
	current_parry_stacks -= 2
	parry_stacks_changed.emit(current_parry_stacks)
	update_charge_sprites()
	velocity.y = HIGH_JUMP_VELOCITY
	can_high_jump = false
	high_jump_cooldown_timer.start()
	_play_whoosh_sound()
	spawn_air_puffV()

func handle_wall_bounce():
	var original_dash_direction = dash_direction
	end_dash()
	velocity.y = wall_bounce_force.y
	velocity.x = 0.0
	bounce_direction_vector = Vector2.LEFT if original_dash_direction.x > 0 else Vector2.RIGHT
	bounce_timer.start()

func check_dash_ground_landing():
	if is_on_floor() and not dash_started_on_ground: end_dash()
	elif dash_started_on_ground and not was_on_ground_before_dash and is_on_floor(): end_dash()
	was_on_ground_before_dash = is_on_floor()

func end_dash():
	if not is_dashing: return
	is_dashing = false
	dash_direction = Vector2.ZERO
	dash_start_time = 0.0
	is_vine_release_dash = false
	dash_timer.stop()

func end_bounce():
	is_bouncing = false
	bounce_direction_vector = Vector2.ZERO
	bounce_start_time = 0.0

func add_parry_stack():
	if current_parry_stacks < max_parry_stacks:
		current_parry_stacks += 1
		parry_stacks_changed.emit(current_parry_stacks)
		update_charge_sprites()

func consume_parry_stack():
	if current_parry_stacks > 0:
		current_parry_stacks -= 1
		parry_stacks_changed.emit(current_parry_stacks)
		update_charge_sprites()
		return true
	return false

func reset_parry_stacks():
	current_parry_stacks = 0
	parry_stacks_changed.emit(current_parry_stacks)
	update_charge_sprites()

func get_parry_stacks() -> int: return current_parry_stacks

func setup_charge_system():
	empty_charge_sprites = [empty_charge_sprite_1, empty_charge_sprite_2, empty_charge_sprite_3]
	charge_textures = [charge_texture_1, charge_texture_2, charge_texture_3, charge_texture_4]
	assigned_textures = [null, null, null]
	update_charge_sprites()

func update_charge_sprites():
	for i in range(empty_charge_sprites.size()):
		if empty_charge_sprites[i]:
			if i < current_parry_stacks:
				if assigned_textures[i] == null: assign_new_random_texture_to_sprite(i)
				else:
					empty_charge_sprites[i].texture = assigned_textures[i]
					empty_charge_sprites[i].modulate.a = 1.0
			else:
				assigned_textures[i] = null
				assign_empty_texture_to_sprite(i)
			empty_charge_sprites[i].visible = true

func get_currently_used_textures() -> Array[Texture2D]:
	var used_textures: Array[Texture2D] = []
	for i in range(current_parry_stacks):
		if assigned_textures[i] != null: used_textures.append(assigned_textures[i])
	return used_textures

func assign_new_random_texture_to_sprite(index: int):
	if index < empty_charge_sprites.size() and empty_charge_sprites[index]:
		var valid_textures = charge_textures.filter(func(texture): return texture != null)
		if valid_textures.size() > 0:
			var used_textures = get_currently_used_textures()
			var available_textures = valid_textures.filter(func(texture): return not texture in used_textures)
			if available_textures.size() == 0: available_textures = valid_textures
			var random_texture = available_textures[randi() % available_textures.size()]
			assigned_textures[index] = random_texture
			empty_charge_sprites[index].texture = random_texture
			empty_charge_sprites[index].modulate.a = 1.0

func assign_empty_texture_to_sprite(index: int):
	if index < empty_charge_sprites.size() and empty_charge_sprites[index]:
		if empty_charge_texture:
			empty_charge_sprites[index].texture = empty_charge_texture
			empty_charge_sprites[index].modulate.a = 1.0
		else: empty_charge_sprites[index].modulate.a = 0.3

func _on_parry_timeout():
	Engine.time_scale = original_time_scale
	if glint_sprite:
		glint_sprite.visible = false
		glint_sprite.stop()
	
	if not parry_was_successful:
		is_parrying = false
		parry_cooldown_timer.wait_time = parry_fail_cooldown
		parry_cooldown_timer.start()
		if was_invulnerable_before_parry and last_attack_was_unparryable: health_script.is_invulnerable = true
		else: health_script.is_invulnerable = false
	else:
		health_script.is_invulnerable = was_invulnerable_before_parry
		can_parry = true
		update_parry_ready_sprite()
	
	last_attack_was_unparryable = false
	was_invulnerable_before_parry = false
	if parry_safety_timer: parry_safety_timer.stop()

func _on_parry_cooldown_timeout():
	can_parry = true
	update_parry_ready_sprite()

func _on_parry_pre_freeze_timeout():
	is_in_pre_freeze_parry = false
	is_in_parry_freeze = true
	if parry_spark: parry_spark.visible = false
	parry_freeze_timer.start()

func _on_parry_freeze_timeout():
	is_in_parry_freeze = false
	Engine.time_scale = original_time_scale
	if parry_safety_timer: parry_safety_timer.stop()

func _on_parry_safety_timeout():
	_reset_all_parry_states()
	if was_invulnerable_before_parry: health_script.is_invulnerable = true
	else: health_script.is_invulnerable = false
	can_parry = true
	update_parry_ready_sprite()
	last_attack_was_unparryable = false
	was_invulnerable_before_parry = false

func _on_coyote_time_timeout(): can_coyote_jump = false
func reset_timescale(): Engine.time_scale = original_time_scale
func _on_dash_timeout(): end_dash()
func _on_dash_cooldown_timeout(): can_dash = true
func _on_bounce_timeout(): is_bouncing = true; bounce_start_time = Time.get_ticks_msec() / 1000.0
func _on_high_jump_cooldown_timeout(): can_high_jump = true

func set_last_attack_unparryable(unparryable: bool):
	last_attack_was_unparryable = unparryable
	if unparryable and is_parrying and was_invulnerable_before_parry: health_script.is_invulnerable = true

func _on_player_died():
	reset_timescale()
	_stop_zipline_sound()
	if click_audio_player and click_audio_player.playing: click_audio_player.stop()
	_reset_all_parry_states()
	is_dashing = false
	is_bouncing = false
	is_vine_release_dash = false
	can_coyote_jump = false
	was_on_floor_last_frame = false
	
	if is_on_zipline and current_zipline:
		current_zipline.release_player()
		is_on_zipline = false
		current_zipline = null
		zipline_in_range = null
	
	for timer in [parry_timer, parry_cooldown_timer, parry_freeze_timer, parry_pre_freeze_timer, parry_safety_timer, dash_timer, dash_cooldown_timer, bounce_timer, coyote_time_timer]:
		if timer: timer.stop()
	
	animated_sprite.modulate.a = 1.0
	bounce_direction_vector = Vector2.ZERO
	
	if glint_sprite:
		glint_sprite.visible = false
		glint_sprite.stop()
	if zipline_friction:
		zipline_friction.visible = false
		zipline_friction.stop()
	if parry_spark: parry_spark.visible = false
	
	reset_parry_stacks()
	Engine.time_scale = 0.2
	$CollisionShape2D.set_deferred("disabled", true)
	await get_tree().create_timer(1.0).timeout
	Engine.time_scale = 1.0
	emit_signal("player_died_trigger_retry")

func grab_vine(vine: Vine):
	if vine.player_in_grab_area and has_node("VineComponent"): $VineComponent.grab_vine(vine)

func handle_zipline_movement(delta: float):
	if current_zipline:
		var zipline_dir = current_zipline.get_zipline_direction_vector()
		update_sprite_direction(zipline_dir.x)
		update_animations(0.0)
	move_and_slide()

func grab_zipline():
	if not zipline_in_range: return false
	if zipline_in_range.grab_player(self, zipline_grab_position):
		is_on_zipline = true
		current_zipline = zipline_in_range
		if is_dashing: end_dash()
		_play_click_sound()
		_play_zipline_sound()
		return true
	return false

func release_zipline():
	if not is_on_zipline or not current_zipline: return
	_stop_zipline_sound()
	if current_parry_stacks >= 1:
		var zipline_dir = current_zipline.get_zipline_direction_vector()
		current_zipline.release_player()
		is_on_zipline = false
		current_zipline = null
	else:
		current_zipline.release_player()
		is_on_zipline = false
		current_zipline = null

func _on_movement_disabled(): movement_blocked_by_game = true
func _on_movement_enabled(): movement_blocked_by_game = false
