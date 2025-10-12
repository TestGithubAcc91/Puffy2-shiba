extends Area2D
@onready var collision_shape = $CollisionShape2D
@onready var animated_sprite = $AnimatedSprite2D
@onready var static_body = $StaticBody2D
@onready var static_body_collision = $StaticBody2D/CollisionShape2D

# Audio properties
@export_group("Audio")
@export var break_sound: AudioStream

var player_node
var is_destroyed: bool = false
var player_touched_while_dashing: bool = false
var player_touched_while_high_jumping: bool = false
var is_high_jumping: bool = false

# Safety variables
var collision_was_disabled: bool = false
var safety_timer: Timer
var coroutine_running: bool = false

# Audio system
var break_audio_player: AudioStreamPlayer2D

func _ready():
	await get_tree().process_frame
	player_node = get_tree().root.find_child("Player", true, false)
	
	body_entered.connect(_on_body_entered)
	_setup_audio_system()
	_setup_safety_timer()
	
	# CRITICAL: Verify we have valid collision references
	if not static_body_collision:
		push_error("Crate missing StaticBody2D/CollisionShape2D!")
		return
	
	if player_node:
		if player_node.has_signal("dash_started"):
			call_deferred("_connect_to_player")
		if player_node.has_signal("high_jump_started"):
			call_deferred("_connect_high_jump_signal")

func _setup_safety_timer():
	safety_timer = Timer.new()
	safety_timer.wait_time = 3.0
	safety_timer.one_shot = true
	safety_timer.timeout.connect(_safety_restore_collision)
	add_child(safety_timer)

func _safety_restore_collision():
	# CRITICAL: Multiple safety checks
	if is_destroyed:
		return
	
	if not static_body_collision or not is_instance_valid(static_body_collision):
		return
	
	if not static_body or not is_instance_valid(static_body):
		return
	
	# Only restore if this crate actually disabled its own collision
	if collision_was_disabled:
		static_body_collision.disabled = false
		collision_was_disabled = false
		print("SAFETY: Restored crate collision at ", global_position)

func _setup_audio_system():
	break_audio_player = AudioStreamPlayer2D.new()
	break_audio_player.name = "BreakAudioPlayer2D"
	break_audio_player.bus = "SFX"
	add_child(break_audio_player)
	
	if break_sound:
		break_audio_player.stream = break_sound

func _play_break_sound():
	if break_audio_player and break_sound:
		break_audio_player.play()

func _connect_to_player():
	if player_node and player_node.has_signal("dash_started"):
		player_node.dash_started.connect(_on_player_dash_started)

func _connect_high_jump_signal():
	if player_node and player_node.has_signal("high_jump_started"):
		player_node.high_jump_started.connect(_on_player_high_jump_started)

func _on_body_entered(body):
	if body == player_node and not is_destroyed:
		if player_node.is_dashing:
			player_touched_while_dashing = true
			print("Player touched crate while dashing!")
			if animated_sprite and animated_sprite.sprite_frames.has_animation("destroy"):
				animated_sprite.play("destroy")
			_play_break_sound()
		elif is_high_jumping:
			player_touched_while_high_jumping = true
			print("Player touched crate while high jumping!")
			if animated_sprite and animated_sprite.sprite_frames.has_animation("destroy"):
				animated_sprite.play("destroy")
			_play_break_sound()

func _on_player_dash_started():
	# CRITICAL: Verify this crate's collision system is valid
	if is_destroyed or not _validate_collision_system():
		return
	
	# Cancel if already running
	if coroutine_running:
		return
	
	player_touched_while_dashing = false
	collision_was_disabled = true
	
	# Disable collision immediately, not deferred
	static_body_collision.disabled = true
	safety_timer.start()
	
	print("DASH STARTED - Crate collision disabled at ", global_position)
	coroutine_running = true
	await _dash_monitoring_coroutine()
	coroutine_running = false

func _on_player_high_jump_started():
	# CRITICAL: Verify this crate's collision system is valid
	if is_destroyed or not _validate_collision_system():
		return
	
	# Cancel if already running
	if coroutine_running:
		return
	
	player_touched_while_high_jumping = false
	is_high_jumping = true
	collision_was_disabled = true
	
	# Disable collision immediately, not deferred
	static_body_collision.disabled = true
	safety_timer.start()
	
	print("HIGH JUMP STARTED - Crate collision disabled at ", global_position)
	coroutine_running = true
	await _high_jump_monitoring_coroutine()
	coroutine_running = false

func _validate_collision_system() -> bool:
	if not static_body_collision or not is_instance_valid(static_body_collision):
		push_error("Invalid static_body_collision reference!")
		return false
	
	if not static_body or not is_instance_valid(static_body):
		push_error("Invalid static_body reference!")
		return false
	
	if static_body_collision.get_parent() != static_body:
		push_error("Collision shape parent mismatch!")
		return false
	
	return true

func _dash_monitoring_coroutine():
	# Add frame limit to prevent infinite loops
	var max_frames = 1000
	var frame_count = 0
	
	while player_node and is_instance_valid(player_node) and player_node.is_dashing and frame_count < max_frames:
		await get_tree().process_frame
		frame_count += 1
	
	if frame_count >= max_frames:
		push_error("Dash monitoring exceeded max frames - forcing end")
	
	safety_timer.stop()
	
	if not is_destroyed and is_instance_valid(self):
		check_if_should_destroy_dash()
		await get_tree().create_timer(0.5).timeout
		# Don't check if player is stuck - just restore collision
		_restore_collision_safe()

func _high_jump_monitoring_coroutine():
	# Add frame limit to prevent infinite loops
	var max_frames = 1000
	var frame_count = 0
	
	while player_node and is_instance_valid(player_node) and player_node.velocity.y < 0 and frame_count < max_frames:
		await get_tree().process_frame
		frame_count += 1
	
	if frame_count >= max_frames:
		push_error("High jump monitoring exceeded max frames - forcing end")
	
	is_high_jumping = false
	safety_timer.stop()
	
	if not is_destroyed and is_instance_valid(self):
		check_if_should_destroy_high_jump()
		await get_tree().create_timer(0.5).timeout
		# Don't check if player is stuck - just restore collision
		_restore_collision_safe()

func check_if_should_destroy_dash():
	if not _validate_collision_system():
		return
	
	print("=== CRATE DASH CHECK at ", global_position, " ===")
	
	if player_touched_while_dashing:
		print("DESTROYING CRATE at ", global_position)
		destroy_crate()

func check_if_should_destroy_high_jump():
	if not _validate_collision_system():
		return
	
	print("=== CRATE HIGH JUMP CHECK at ", global_position, " ===")
	
	if player_touched_while_high_jumping:
		print("DESTROYING CRATE at ", global_position)
		destroy_crate()

func _restore_collision_safe():
	if not is_destroyed and collision_was_disabled and _validate_collision_system():
		print("Restoring collision for crate at ", global_position)
		static_body_collision.disabled = false
		collision_was_disabled = false

func destroy_crate():
	if is_destroyed:
		return
	
	is_destroyed = true
	safety_timer.stop()
	
	# Disconnect from player signals
	if player_node and is_instance_valid(player_node):
		if player_node.has_signal("dash_started") and player_node.dash_started.is_connected(_on_player_dash_started):
			player_node.dash_started.disconnect(_on_player_dash_started)
		if player_node.has_signal("high_jump_started") and player_node.high_jump_started.is_connected(_on_player_high_jump_started):
			player_node.high_jump_started.disconnect(_on_player_high_jump_started)
	
	if static_body:
		static_body.queue_free()
	
	if animated_sprite:
		await animated_sprite.animation_finished
	
	queue_free()

func _exit_tree():
	if safety_timer and is_instance_valid(safety_timer):
		safety_timer.stop()
	
	# Final safety: restore collision on cleanup
	if collision_was_disabled and static_body_collision and is_instance_valid(static_body_collision):
		static_body_collision.disabled = false
