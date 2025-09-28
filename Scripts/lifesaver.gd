extends Area2D

@export var exit_force_magnitude: float = 400.0  # Magnitude of force applied when jumping out
@export var stick_offset: Vector2 = Vector2(0, 0)   # Offset from lifesaver center where player sticks
@export var rotation_speed: float = 2.0  # Time between rotations in seconds
@export var use_dash_for_horizontal: bool = true  # Use dash instead of velocity for left/right

# Sound effects
@export var mount_click_sound: AudioStream  # Sound when player enters lifesaver

@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D

var player_in_lifesaver: bool = false
var current_player: CharacterBody2D = null
var player_original_sprite_alpha: float = 1.0
var player_was_movement_blocked: bool = false

# Audio player for sound effects
var audio_player: AudioStreamPlayer2D

# Rotation system - now instant snapping
var current_rotation_index: int = 0  # 0=up, 1=right, 2=down, 3=left
var rotation_timer: Timer

signal player_entered_lifesaver(player)
signal player_exited_lifesaver(player)

func _ready():
	# Connect the area signals
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	
	# Setup audio player
	audio_player = AudioStreamPlayer2D.new()
	add_child(audio_player)
	
	# Setup rotation timer
	rotation_timer = Timer.new()
	rotation_timer.wait_time = rotation_speed
	rotation_timer.timeout.connect(_on_rotation_timer_timeout)
	rotation_timer.autostart = true
	add_child(rotation_timer)

func _physics_process(delta: float):
	if player_in_lifesaver and current_player:
		# Keep player stuck to lifesaver position
		current_player.global_position = global_position + stick_offset
		
		# Override player velocity to keep them stationary
		current_player.velocity = Vector2.ZERO
		
		# Handle jump input to exit lifesaver
		if Input.is_action_just_pressed("Jump"):
			_release_player()
	
	# Debug check: verify player is still valid
	if player_in_lifesaver and (not current_player or not is_instance_valid(current_player)):
		print("Player became invalid, cleaning up lifesaver state")
		_cleanup_invalid_player()

func _on_body_entered(body):
	# Check if it's the player (assuming it's a CharacterBody2D with specific properties)
	if body is CharacterBody2D and body.has_method("_on_movement_disabled"):
		_capture_player(body)

func _on_body_exited(body):
	# If player exits the area without jumping out (shouldn't normally happen due to sticking)
	# but just in case, we'll handle it
	if body == current_player and player_in_lifesaver:
		print("Player exited lifesaver area unexpectedly")
		# Force release without jump force since they already left
		_force_release_without_jump()

func _capture_player(player: CharacterBody2D):
	if player_in_lifesaver:
		return  # Already have a player
	
	current_player = player
	player_in_lifesaver = true
	
	# Play click sound when player mounts the lifesaver
	if mount_click_sound and audio_player:
		audio_player.stream = mount_click_sound
		audio_player.play()
	
	# Store original sprite alpha and make sprite invisible
	if player.has_node("MainSprite"):
		var sprite = player.get_node("MainSprite")
		player_original_sprite_alpha = sprite.modulate.a
		sprite.modulate.a = 0.0  # Make invisible
	
	# NEW: Tell health script to force invisibility
	if player.has_node("HealthScript"):
		var health_script = player.get_node("HealthScript")
		health_script.set_force_invisible(true)
	
	# Store original movement state and disable most movement
	player_was_movement_blocked = player.movement_blocked_by_game
	player._on_movement_disabled()
	
	# Stop any current movement states
	if player.has_method("end_dash") and player.is_dashing:
		player.end_dash()
	
	if player.has_method("end_bounce") and player.is_bouncing:
		player.end_bounce()
	
	# If player is on zipline, release them
	if player.is_on_zipline:
		player.release_zipline()
	
	# Reset any vine swinging
	if player.vine_component and player.vine_component.is_swinging:
		player.vine_component.release_vine()
	
	# Position player at lifesaver
	player.global_position = global_position + stick_offset
	
	# Switch lifesaver animation to show player inside
	if animated_sprite and animated_sprite.sprite_frames.has_animation("withPlayer"):
		animated_sprite.play("withPlayer")
	
	# Emit signal
	player_entered_lifesaver.emit(player)

func _release_player():
	if not player_in_lifesaver or not current_player:
		return
	
	var player = current_player
	
	# NEW: Tell health script to stop forcing invisibility
	if player.has_node("HealthScript"):
		var health_script = player.get_node("HealthScript")
		health_script.set_force_invisible(false)
	
	# Restore sprite visibility
	if player.has_node("MainSprite"):
		var sprite = player.get_node("MainSprite")
		sprite.modulate.a = player_original_sprite_alpha
	
	# Restore movement controls
	if not player_was_movement_blocked:
		player._on_movement_enabled()
	
	# Apply exit force based on current rotation
	_apply_directional_exit_force(player)
	
	# Play whoosh sound if available
	if player.has_method("_play_whoosh_sound"):
		player._play_whoosh_sound()
	
	# Spawn appropriate air puff effect based on direction
	_spawn_directional_air_puff(player)
	
	# Switch lifesaver animation back to default
	if animated_sprite and animated_sprite.sprite_frames.has_animation("default"):
		animated_sprite.play("default")
	
	# Emit signal
	player_exited_lifesaver.emit(player)
	
	# Clear references
	player_in_lifesaver = false
	current_player = null
	player_original_sprite_alpha = 1.0
	player_was_movement_blocked = false

# Rotation system methods - now instant snapping
func _on_rotation_timer_timeout():
	"""Instantly snap to next direction"""
	current_rotation_index = (current_rotation_index + 1) % 4
	var target_rotation_degrees = current_rotation_index * 90.0
	
	# Instant snap instead of gradual rotation
	rotation = deg_to_rad(target_rotation_degrees)
	

func _apply_directional_exit_force(player: CharacterBody2D):
	"""Apply force in the direction the lifesaver is facing - FREE for all directions"""
	var exit_vector: Vector2
	
	match current_rotation_index:
		0:  # Up
			exit_vector = Vector2(0, -exit_force_magnitude)
			player.velocity = exit_vector
		1:  # Right - FREE dash functionality
			if use_dash_for_horizontal and player.has_method("activate_dash"):
				# Face right and trigger FREE dash
				player.animated_sprite.flip_h = false
				_activate_free_dash(player)
			else:
				exit_vector = Vector2(exit_force_magnitude, 0)
				player.velocity = exit_vector
		2:  # Down
			exit_vector = Vector2(0, exit_force_magnitude)
			player.velocity = exit_vector
		3:  # Left - FREE dash functionality
			if use_dash_for_horizontal and player.has_method("activate_dash"):
				# Face left and trigger FREE dash
				player.animated_sprite.flip_h = true
				_activate_free_dash(player)
			else:
				exit_vector = Vector2(-exit_force_magnitude, 0)
				player.velocity = exit_vector

func _activate_free_dash(player: CharacterBody2D):
	"""Activate dash without consuming parry stacks - FREE lifesaver dismount"""
	# Store original parry stacks
	var original_stacks = player.current_parry_stacks
	
	# Temporarily set dash availability and provide a temporary stack if needed
	var original_can_dash = player.can_dash
	player.can_dash = true
	
	# If player has no stacks, temporarily give them one for the dash
	var gave_temporary_stack = false
	if original_stacks < 1:
		player.current_parry_stacks = 1
		gave_temporary_stack = true
	
	# Activate the dash
	player.activate_dash()
	
	# If we gave a temporary stack, restore the original count after dash activation
	# Since activate_dash() consumes one stack, we need to add it back
	if gave_temporary_stack:
		player.current_parry_stacks = original_stacks
		player.parry_stacks_changed.emit(player.current_parry_stacks)
		player.update_charge_sprites()
	else:
		# Player had stacks but we want lifesaver dismount to be free
		# So we give back the consumed stack
		player.current_parry_stacks = original_stacks
		player.parry_stacks_changed.emit(player.current_parry_stacks)
		player.update_charge_sprites()

func _get_direction_name() -> String:
	"""Get readable name for current direction"""
	match current_rotation_index:
		0: return "Up"
		1: return "Right"
		2: return "Down"
		3: return "Left"
		_: return "Unknown"

func get_current_direction() -> Vector2:
	"""Get the current direction vector the lifesaver is facing"""
	match current_rotation_index:
		0: return Vector2(0, -1)  # Up
		1: return Vector2(1, 0)   # Right
		2: return Vector2(0, 1)   # Down
		3: return Vector2(-1, 0)  # Left
		_: return Vector2(0, -1)

# Public methods for external control
func force_release_player():
	"""Force release the player (useful for external triggers)"""
	_release_player()

func is_player_inside() -> bool:
	"""Check if a player is currently in the lifesaver"""
	return player_in_lifesaver

func get_current_player() -> CharacterBody2D:
	"""Get the current player in the lifesaver"""
	return current_player

func set_rotation_speed(new_speed: float):
	"""Change the rotation speed (time between rotations)"""
	rotation_speed = new_speed
	if rotation_timer:
		rotation_timer.wait_time = rotation_speed

func pause_rotation():
	"""Pause automatic rotation"""
	if rotation_timer:
		rotation_timer.paused = true

func resume_rotation():
	"""Resume automatic rotation"""
	if rotation_timer:
		rotation_timer.paused = false

func _force_release_without_jump():
	"""Internal method to release player without applying jump force"""
	if not player_in_lifesaver or not current_player:
		return
	
	var player = current_player
	
	# NEW: Tell health script to stop forcing invisibility
	if player.has_node("HealthScript"):
		var health_script = player.get_node("HealthScript")
		health_script.set_force_invisible(false)
	
	# Restore sprite visibility
	if player.has_node("MainSprite"):
		var sprite = player.get_node("MainSprite")
		sprite.modulate.a = player_original_sprite_alpha
	
	# Restore movement controls
	if not player_was_movement_blocked:
		player._on_movement_enabled()
	
	# Switch lifesaver animation back to default
	if animated_sprite and animated_sprite.sprite_frames.has_animation("default"):
		animated_sprite.play("default")
	
	# Emit signal
	player_exited_lifesaver.emit(player)
	
	# Clear references
	player_in_lifesaver = false
	current_player = null
	player_original_sprite_alpha = 1.0
	player_was_movement_blocked = false

func _cleanup_invalid_player():
	"""Clean up state when player becomes invalid"""
	# Switch lifesaver animation back to default
	if animated_sprite and animated_sprite.sprite_frames.has_animation("default"):
		animated_sprite.play("default")
	
	# Clear references
	player_in_lifesaver = false
	current_player = null
	player_original_sprite_alpha = 1.0
	player_was_movement_blocked = false

func _spawn_directional_air_puff(player: CharacterBody2D):
	"""Spawn appropriate air puff effect based on lifesaver direction"""
	match current_rotation_index:
		0:  # Up - use vertical air puff
			if player.has_method("spawn_air_puffV"):
				player.spawn_air_puffV()
		1:  # Right - use horizontal air puff (already spawned by dash)
			# Dash will handle its own air puff, but we can spawn additional if needed
			pass
		2:  # Down - use vertical air puff flipped vertically
			_spawn_flipped_vertical_air_puff(player)
		3:  # Left - use horizontal air puff (already spawned by dash)
			# Dash will handle its own air puff, but we can spawn additional if needed
			pass

func _spawn_flipped_vertical_air_puff(player: CharacterBody2D):
	"""Spawn a vertical air puff that's flipped vertically for downward direction"""
	if not player.air_puffV_scene:
		return
	
	var air_puff = player.air_puffV_scene.instantiate()
	get_parent().add_child(air_puff)
	air_puff.global_position = player.global_position + Vector2(0, -6)
	
	# Flip vertically for downward direction
	air_puff.rotation_degrees = 90  # Instead of -90, use 90 to flip it
	air_puff.flip_v = true  # Also flip vertically if the sprite supports it
	
	# Setup cleanup (copied from player script logic)
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
