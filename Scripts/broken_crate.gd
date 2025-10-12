extends Area2D
@onready var collision_shape = $CollisionShape2D
@onready var animated_sprite = $AnimatedSprite2D
@onready var static_body = $StaticBody2D
@onready var static_body_collision = $StaticBody2D/CollisionShape2D

# Audio properties
@export_group("Audio")
@export var break_sound: AudioStream  # Sound to play when crate breaks

var player_node
var is_destroyed: bool = false
var player_touched_while_dashing: bool = false
var player_touched_while_high_jumping: bool = false
var is_high_jumping: bool = false

# NEW: Safety variables
var collision_was_disabled: bool = false
var original_collision_state: bool = false
var safety_timer: Timer

# Audio system
var break_audio_player: AudioStreamPlayer2D

func _ready():
	await get_tree().process_frame
	player_node = get_tree().root.find_child("Player", true, false)
	
	# Connect to Area2D body_entered signal
	body_entered.connect(_on_body_entered)
	
	# Setup audio system
	_setup_audio_system()
	
	# NEW: Setup safety timer
	_setup_safety_timer()
	
	if player_node:
		if player_node.has_signal("dash_started"):
			call_deferred("_connect_to_player")
		if player_node.has_signal("high_jump_started"):
			call_deferred("_connect_high_jump_signal")

# NEW: Setup safety timer to prevent permanent collision disable
func _setup_safety_timer():
	safety_timer = Timer.new()
	safety_timer.wait_time = 3.0  # 3 second safety net
	safety_timer.one_shot = true
	safety_timer.timeout.connect(_safety_restore_collision)
	add_child(safety_timer)

# NEW: Safety collision restoration
func _safety_restore_collision():
	# CRITICAL: Only restore if crate is NOT destroyed
	if not is_destroyed and static_body_collision and is_instance_valid(static_body_collision):
		static_body_collision.disabled = original_collision_state
		collision_was_disabled = false
		print("SAFETY: Restored crate collision at ", global_position)

# Setup the audio system
func _setup_audio_system():
	break_audio_player = AudioStreamPlayer2D.new()
	break_audio_player.name = "BreakAudioPlayer2D"
	break_audio_player.bus = "SFX"  # Use SFX bus like the main game
	add_child(break_audio_player)
	
	if break_sound:
		break_audio_player.stream = break_sound
	
	print("Crate break audio system initialized")

# Function to play break sound
func _play_break_sound():
	if break_audio_player and break_sound:
		break_audio_player.play()
		print("Playing crate break sound effect")

func _connect_to_player():
	if player_node and player_node.has_signal("dash_started"):
		player_node.dash_started.connect(_on_player_dash_started)

func _connect_high_jump_signal():
	if player_node and player_node.has_signal("high_jump_started"):
		player_node.high_jump_started.connect(_on_player_high_jump_started)

func _on_body_entered(body):
	"""Detect when player touches the Area2D while dashing or high jumping"""
	if body == player_node and not is_destroyed:
		if player_node.is_dashing:
			player_touched_while_dashing = true
			print("Player touched crate while dashing!")
			# Start destroy animation immediately
			if animated_sprite and animated_sprite.sprite_frames.has_animation("destroy"):
				animated_sprite.play("destroy")
			# Play break sound
			_play_break_sound()
		# Check if player is in high jump state
		elif is_high_jumping:
			player_touched_while_high_jumping = true
			print("Player touched crate while high jumping!")
			# Start destroy animation immediately
			if animated_sprite and animated_sprite.sprite_frames.has_animation("destroy"):
				animated_sprite.play("destroy")
			# Play break sound
			_play_break_sound()

func _on_player_dash_started():
	"""Called when player starts a dash - disable StaticBody2D collision immediately"""
	# CRITICAL: Don't process if crate is destroyed or collision is invalid
	if is_destroyed:
		return
	
	if not static_body_collision or not is_instance_valid(static_body_collision):
		return
	
	# Reset touch flag for this dash
	player_touched_while_dashing = false
	
	# NEW: Store original collision state ONLY if this is the first time we're disabling it
	if not collision_was_disabled:
		original_collision_state = static_body_collision.disabled
		collision_was_disabled = true
	
	# CRITICAL FIX: Disable collision immediately without waiting for next frame
	static_body_collision.disabled = true
	
	# NEW: Start safety timer
	safety_timer.start()
	
	print("DASH STARTED - Crate at ", global_position, " monitoring for collision")
	
	# Start monitoring for the duration of the dash
	_start_dash_monitoring()

func _on_player_high_jump_started():
	"""Called when player starts a high jump - disable StaticBody2D collision immediately"""
	# CRITICAL: Don't process if crate is destroyed or collision is invalid
	if is_destroyed:
		return
	
	if not static_body_collision or not is_instance_valid(static_body_collision):
		return
	
	# Reset touch flag for this high jump
	player_touched_while_high_jumping = false
	is_high_jumping = true
	
	# NEW: Store original collision state ONLY if this is the first time we're disabling it
	if not collision_was_disabled:
		original_collision_state = static_body_collision.disabled
		collision_was_disabled = true
	
	# CRITICAL FIX: Disable collision immediately without waiting for next frame
	static_body_collision.disabled = true
	
	# NEW: Start safety timer
	safety_timer.start()
	
	print("HIGH JUMP STARTED - Crate at ", global_position, " monitoring for collision")
	
	# Start monitoring for the duration of the high jump
	_start_high_jump_monitoring()

func _start_dash_monitoring():
	"""Monitor for player collision during dash"""
	# Start the monitoring coroutine
	_dash_monitoring_coroutine()

func _start_high_jump_monitoring():
	"""Monitor for player collision during high jump"""
	# Start the monitoring coroutine
	_high_jump_monitoring_coroutine()

func _dash_monitoring_coroutine():
	# Wait until player is no longer dashing
	while player_node and player_node.is_dashing:
		await get_tree().process_frame
	
	# NEW: Stop safety timer since we're handling collision normally
	safety_timer.stop()
	
	# Only check this specific crate instance
	if not is_destroyed and is_instance_valid(self):
		check_if_should_destroy_dash()

func _high_jump_monitoring_coroutine():
	# Wait until player velocity reaches 0 or starts falling (becomes positive)
	while player_node and player_node.velocity.y < 0:  # Monitor only while moving upward
		await get_tree().process_frame
	
	is_high_jumping = false
	
	# NEW: Stop safety timer since we're handling collision normally
	safety_timer.stop()
	
	# Only check this specific crate instance
	if not is_destroyed and is_instance_valid(self):
		check_if_should_destroy_high_jump()

func check_if_should_destroy_dash():
	"""Check if THIS specific crate was touched during the dash"""
	print("=== CRATE DASH CHECK at ", global_position, " ===")
	print("Player touched while dashing: ", player_touched_while_dashing)
	print("Is destroyed: ", is_destroyed)
	
	if player_touched_while_dashing:
		# Player touched THIS crate's Area2D while dashing - destroy only this crate
		print("DESTROYING CRATE at ", global_position, "!")
		destroy_crate()
	else:
		# Player didn't touch THIS crate - restore its StaticBody2D collision
		# CRITICAL: Only restore if crate is NOT destroyed
		if not is_destroyed:
			print("Restoring collision for crate at ", global_position)
			if is_instance_valid(static_body_collision) and collision_was_disabled:
				static_body_collision.disabled = original_collision_state
				collision_was_disabled = false  # Reset so next dash can track properly

func check_if_should_destroy_high_jump():
	"""Check if THIS specific crate was touched during the high jump"""
	print("=== CRATE HIGH JUMP CHECK at ", global_position, " ===")
	print("Player touched while high jumping: ", player_touched_while_high_jumping)
	print("Is destroyed: ", is_destroyed)
	
	if player_touched_while_high_jumping:
		# Player touched THIS crate's Area2D while high jumping - destroy only this crate
		print("DESTROYING CRATE at ", global_position, "!")
		destroy_crate()
	else:
		# Player didn't touch THIS crate - restore its StaticBody2D collision
		# CRITICAL: Only restore if crate is NOT destroyed
		if not is_destroyed:
			print("Restoring collision for crate at ", global_position)
			if is_instance_valid(static_body_collision) and collision_was_disabled:
				static_body_collision.disabled = original_collision_state
				collision_was_disabled = false  # Reset so next high jump can track properly

func destroy_crate():
	"""Permanently destroy the crate with destroy animation"""
	if is_destroyed:
		return
	
	is_destroyed = true
	
	# NEW: Stop safety timer
	safety_timer.stop()
	
	# CRITICAL: Disconnect from player signals to prevent future dash/high jump events
	if player_node and is_instance_valid(player_node):
		if player_node.has_signal("dash_started") and player_node.dash_started.is_connected(_on_player_dash_started):
			player_node.dash_started.disconnect(_on_player_dash_started)
		if player_node.has_signal("high_jump_started") and player_node.high_jump_started.is_connected(_on_player_high_jump_started):
			player_node.high_jump_started.disconnect(_on_player_high_jump_started)
	
	# Remove the static body immediately
	if static_body:
		static_body.queue_free()
	
	# Animation already started in _on_body_entered, just wait for it to finish
	if animated_sprite:
		await animated_sprite.animation_finished
	
	# Remove the crate
	queue_free()

# NEW: Ensure collision is restored if crate is removed for any reason
func _exit_tree():
	if safety_timer and is_instance_valid(safety_timer):
		safety_timer.stop()
	
	# If collision was disabled and we still have a valid static body, restore it
	if collision_was_disabled and static_body_collision and is_instance_valid(static_body_collision):
		static_body_collision.disabled = original_collision_state
		print("Exit tree: Restored crate collision at ", global_position)
