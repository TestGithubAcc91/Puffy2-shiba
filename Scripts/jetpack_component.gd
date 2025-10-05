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

var is_active: bool = false
var fuel_remaining: float = 100.0
var max_fuel: float = 100.0
var duration_timer: Timer
var jetpack_audio_player: AudioStreamPlayer
var jetpack_particles: Node2D

var player: CharacterBody2D
var original_gravity_scale: float = 1.0

signal jetpack_activated
signal jetpack_deactivated
signal fuel_changed(current_fuel: float, max_fuel: float)

func _ready():
	player = get_parent() as CharacterBody2D
	
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

func activate(duration: float):
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
		
		# Spawn particles if available
		if jetpack_particles_scene:
			jetpack_particles = jetpack_particles_scene.instantiate()
			player.add_child(jetpack_particles)
			jetpack_particles.position = Vector2(0, 10)  # Position below player
		
		jetpack_activated.emit()
	
	fuel_changed.emit(fuel_remaining, max_fuel)

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
	
	duration_timer.stop()
	jetpack_deactivated.emit()
	fuel_changed.emit(fuel_remaining, max_fuel)

func _physics_process(delta: float):
	"""This is the CORE jetpack logic - runs every frame when active"""
	if not is_active or not player:
		return
	
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
		
		# Play jetpack sound
		if jetpack_audio_player and jetpack_sound and not jetpack_audio_player.playing:
			jetpack_audio_player.play()
		
		# Update particles
		if jetpack_particles and jetpack_particles.has_method("set_emitting"):
			jetpack_particles.set_emitting(true)
	else:
		# Apply reduced gravity when not thrusting
		player.velocity += player.get_gravity() * gravity_when_not_thrusting * delta
		
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
