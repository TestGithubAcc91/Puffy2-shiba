extends Node

# This script should be attached to a Node child under your Player
# Name the node "JetpackComponent" in the scene tree

# Jetpack movement parameters
@export var jetpack_thrust: float = 400.0  # Upward thrust force
@export var jetpack_horizontal_speed: float = 200.0  # Side-to-side movement speed
@export var jetpack_fuel_drain_rate: float = 10.0  # Fuel drained per second
@export var max_vertical_speed: float = 300.0  # Max upward speed
@export var gravity_when_not_thrusting: float = 0.5  # Gravity multiplier when not using thrust

# Visual/Audio
@export var jetpack_sound: AudioStream
@export var jetpack_particles_scene: PackedScene
@export var jetpack_sprite_node: Sprite2D  # Drag your existing Sprite2D node here!

var is_active: bool = false
var fuel_remaining: float = 100.0
var max_fuel: float = 100.0
var duration_timer: Timer
var jetpack_audio_player: AudioStreamPlayer
var jetpack_particles: Node2D
var jetpack_fire: AnimatedSprite2D  # Reference to the JetpackFire node

var player: CharacterBody2D
var original_gravity_scale: float = 1.0
var health_component: Node  # Reference to player's Health component

signal jetpack_activated
signal jetpack_deactivated
signal fuel_changed(current_fuel: float, max_fuel: float)

func _ready():
	player = get_parent() as CharacterBody2D
	
	# Get reference to Health component for flicker sync
	if player and player.has_node("Health"):
		health_component = player.get_node("Health")
		print("Jetpack found Health component for flicker sync!")
	
	# Hide jetpack sprite initially
	if jetpack_sprite_node:
		jetpack_sprite_node.visible = false
		
		# Get reference to JetpackFire AnimatedSprite2D
		if jetpack_sprite_node.has_node("JetpackFire"):
			jetpack_fire = jetpack_sprite_node.get_node("JetpackFire")
			jetpack_fire.visible = false
			print("JetpackFire node found and hidden!")
		else:
			print("Warning: JetpackFire node not found as child of jetpack sprite!")
	
	# Setup duration timer
	duration_timer = Timer.new()
	duration_timer.one_shot = true
	duration_timer.timeout.connect(_on_duration_timeout)
	add_child(duration_timer)
	
	# Setup audio
	jetpack_audio_player = AudioStreamPlayer.new()
	jetpack_audio_player.bus = "SFX"
	jetpack_audio_player.volume_db = -5.0
	if jetpack_sound:
		jetpack_audio_player.stream = jetpack_sound
	add_child(jetpack_audio_player)

func activate(duration: float, visual_sprite: Sprite2D = null):
	"""Activates the jetpack for a given duration"""
	if is_active:
		# If already active, just add to duration
		duration_timer.wait_time += duration
		fuel_remaining = min(fuel_remaining + (duration * 10.0), max_fuel)
	else:
		is_active = true
		fuel_remaining = duration * 10.0  # Convert duration to fuel
		max_fuel = fuel_remaining
		duration_timer.wait_time = duration
		duration_timer.start()
		
		# Show the jetpack sprite
		if jetpack_sprite_node:
			jetpack_sprite_node.visible = true
			# Sync alpha with player sprite immediately
			_sync_flicker_with_player()
			print("Jetpack sprite activated!")
		
		# Spawn particles if available
		if jetpack_particles_scene:
			jetpack_particles = jetpack_particles_scene.instantiate()
			player.add_child(jetpack_particles)
			jetpack_particles.position = Vector2(0, 10)  # Position below player
		
		jetpack_activated.emit()
	
	fuel_changed.emit(fuel_remaining, max_fuel)

func set_jetpack_visual(visual_sprite: Sprite2D):
	"""Legacy function - no longer needed with direct sprite reference"""
	pass

func deactivate():
	"""Deactivates the jetpack"""
	if not is_active:
		return
	
	is_active = false
	fuel_remaining = 0.0
	
	# Stop audio
	if jetpack_audio_player and jetpack_audio_player.playing:
		jetpack_audio_player.stop()
	
	# Remove particles
	if jetpack_particles and is_instance_valid(jetpack_particles):
		jetpack_particles.queue_free()
		jetpack_particles = null
	
	# Hide jetpack sprite and fire
	if jetpack_sprite_node:
		jetpack_sprite_node.visible = false
		print("Jetpack sprite deactivated!")
	
	if jetpack_fire:
		jetpack_fire.visible = false
		jetpack_fire.stop()
	
	duration_timer.stop()
	jetpack_deactivated.emit()
	fuel_changed.emit(fuel_remaining, max_fuel)

func _sync_flicker_with_player():
	"""Syncs the jetpack sprite's alpha/transparency with the player's main sprite"""
	if not player or not jetpack_sprite_node:
		return
	
	# Get the player's main sprite
	var main_sprite = null
	if player.has_node("MainSprite"):
		main_sprite = player.get_node("MainSprite")
	
	if main_sprite:
		# Copy the alpha value from the player sprite to the jetpack sprite
		jetpack_sprite_node.modulate.a = main_sprite.modulate.a
		
		# Also sync the jetpack fire if it exists
		if jetpack_fire:
			jetpack_fire.modulate.a = main_sprite.modulate.a

func _physics_process(delta: float):
	"""This is the CORE jetpack logic - runs every frame when active"""
	if not is_active or not player:
		return
	
	# Sync jetpack flicker with player sprite
	_sync_flicker_with_player()
	
	# Update jetpack sprite to follow player's facing direction
	if jetpack_sprite_node and is_instance_valid(jetpack_sprite_node):
		if player.has_node("MainSprite"):
			var main_sprite = player.get_node("MainSprite")
			jetpack_sprite_node.flip_h = main_sprite.flip_h
	
	# Check if player is trying to use jetpack
	var is_thrusting = Input.is_action_pressed("Jump") and fuel_remaining > 0
	
	if is_thrusting:
		# Drain fuel
		fuel_remaining -= jetpack_fuel_drain_rate * delta
		fuel_changed.emit(fuel_remaining, max_fuel)
		
		# Apply upward thrust (THIS IS THE KEY LINE - modifies player velocity)
		player.velocity.y -= jetpack_thrust * delta
		
		# Clamp vertical speed
		player.velocity.y = max(player.velocity.y, -max_vertical_speed)
		
		# Show and play jetpack fire animation
		if jetpack_fire:
			jetpack_fire.visible = true
			if not jetpack_fire.is_playing():
				jetpack_fire.play()
		
		# Play jetpack sound
		if jetpack_audio_player and jetpack_sound and not jetpack_audio_player.playing:
			jetpack_audio_player.play()
		
		# Update particles
		if jetpack_particles and jetpack_particles.has_method("set_emitting"):
			jetpack_particles.set_emitting(true)
	else:
		# Apply reduced gravity when not thrusting
		player.velocity += player.get_gravity() * gravity_when_not_thrusting * delta
		
		# Hide jetpack fire animation
		if jetpack_fire:
			jetpack_fire.visible = false
			jetpack_fire.stop()
		
		# Stop sound
		if jetpack_audio_player and jetpack_audio_player.playing:
			jetpack_audio_player.stop()
		
		# Update particles
		if jetpack_particles and jetpack_particles.has_method("set_emitting"):
			jetpack_particles.set_emitting(false)
	
	# Handle horizontal movement
	var horizontal_input = Input.get_axis("Move_Left", "Move_Right")
	if horizontal_input != 0:
		player.velocity.x = horizontal_input * jetpack_horizontal_speed
	else:
		# Slow down horizontal movement when no input
		player.velocity.x = move_toward(player.velocity.x, 0, jetpack_horizontal_speed * 0.3)
	
	# Check if out of fuel
	if fuel_remaining <= 0:
		deactivate()

func _on_duration_timeout():
	"""Called when the jetpack duration expires"""
	deactivate()

func get_fuel_percentage() -> float:
	"""Returns fuel as a percentage (0-100)"""
	if max_fuel <= 0:
		return 0.0
	return (fuel_remaining / max_fuel) * 100.0
