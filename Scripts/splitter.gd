extends Node2D

@export var projectile_scene: PackedScene
@export var fire_rate: float = 3.0  # Time between shots in seconds
@export var spawn_offset: Vector2 = Vector2(0, 4)  # Offset from enemy center to spawn projectiles
@export var facing_left: bool = false  # Toggle for direction

# Projectile launch properties
@export_group("Projectile Physics")
@export var launch_velocity: Vector2 = Vector2(150.0, -200.0)  # Initial velocity (x, y)
@export var gravity_scale: float = 1.0  # Multiplier for gravity effect

# Audio properties - ENHANCED to match helicopter
@export_group("Audio")
@export var shoot_sound: AudioStream  # Sound to play when shooting

var fire_timer: Timer
var animated_sprite: AnimatedSprite2D
var is_active: bool = true  # Flag to control enemy activity

# Audio system - ENHANCED
var shoot_audio_player: AudioStreamPlayer2D

func _ready():
	# Get the AnimatedSprite2D node (assumes it's a child of this node)
	animated_sprite = get_node("AnimatedSprite2D")
	
	# Set initial facing direction
	update_facing_direction()
	
	# Create and configure the firing timer
	fire_timer = Timer.new()
	fire_timer.wait_time = fire_rate
	fire_timer.autostart = true
	fire_timer.timeout.connect(_on_fire_timer_timeout)
	add_child(fire_timer)
	
	# Connect to player's death signal if available
	connect_to_player_signals()
	
	# Setup audio system - ENHANCED
	_setup_audio_system()

# ENHANCED: Setup the audio system to match helicopter
func _setup_audio_system():
	shoot_audio_player = AudioStreamPlayer2D.new()
	shoot_audio_player.name = "ShootAudioPlayer2D"
	shoot_audio_player.bus = "SFX"  # Use SFX bus like the main game
	
	# ENHANCED: Configure sound range and attenuation like helicopter
	shoot_audio_player.max_distance = 300.0  # Sound becomes inaudible beyond this distance
	shoot_audio_player.attenuation = 1.0  # How quickly sound fades (higher = faster fade)
	
	add_child(shoot_audio_player)
	
	if shoot_sound:
		shoot_audio_player.stream = shoot_sound
	
	print("Parabolic shooter audio system initialized")

# ENHANCED: Function to play shoot sound with debug output like helicopter
func _play_shoot_sound():
	if shoot_audio_player and shoot_sound:
		shoot_audio_player.play()
		print("Playing parabolic shooter sound effect")

func connect_to_player_signals():
	# Try to find the player and connect to its death signal
	var player = get_node_or_null("../Player")  # Adjust path as needed
	if not player:
		player = get_tree().get_first_node_in_group("player")  # Alternative method
	
	if player:
		var health_component = player.get_node_or_null("Health")
		if health_component and health_component.has_signal("died"):
			health_component.died.connect(_on_player_died)

func _on_player_died():
	# Stop all enemy activity when player dies
	is_active = false
	fire_timer.stop()
	
	# Stop any ongoing shooting sequences
	if animated_sprite:
		animated_sprite.stop()

func toggle_direction():
	if not is_active:
		return
	facing_left = !facing_left
	update_facing_direction()

func update_facing_direction():
	if animated_sprite and is_active:
		animated_sprite.flip_h = !facing_left

func _on_fire_timer_timeout():
	# Safety checks before executing
	if not is_active:
		return
	
	# Check if nodes still exist
	if not is_instance_valid(self) or not is_instance_valid(animated_sprite):
		return
		
	# Start the shooting sequence if the scene is assigned
	if projectile_scene and animated_sprite:
		start_shooting_sequence()

func start_shooting_sequence():
	# Additional safety checks
	if not is_active or not is_instance_valid(animated_sprite):
		return
		
	# Play the "Shoot" animation
	animated_sprite.play("Shoot")
	
	# Check if tree exists before creating timer
	var tree = get_tree()
	if not tree or not is_active:
		return
	
	# Wait 0.9 seconds then end shoot animation (0.1s before projectile spawn)
	await tree.create_timer(0.95).timeout
	
	# Check if still active after await
	if not is_active or not is_instance_valid(animated_sprite):
		return
		
	# Return to idle animation (0.1s before projectile spawn)
	animated_sprite.play("Idle")
	
	# Check tree again
	tree = get_tree()
	if not tree or not is_active:
		return
	
	# Wait the final 0.1 seconds before spawning projectile
	await tree.create_timer(0.1).timeout
	
	# Check if still active after await
	if not is_active:
		return
	
	# ENHANCED: Play shoot sound when spawning projectile (matches helicopter timing)
	_play_shoot_sound()
	
	spawn_projectile()

func spawn_projectile():
	# Safety checks
	if not is_active or not projectile_scene:
		return
		
	# Instance the projectile scene
	var projectile = projectile_scene.instantiate()
	
	# Get the parent scene (usually the main scene or level)
	var parent = get_parent()
	if parent and is_instance_valid(parent):
		# Add the projectile to the scene
		parent.add_child(projectile)
		
		# Calculate spawn position based on facing direction
		var adjusted_spawn_offset = spawn_offset
		if facing_left:
			adjusted_spawn_offset.x = -spawn_offset.x  # Flip the x offset when facing left
		
		# Set the projectile's position relative to the enemy
		projectile.global_position = global_position + adjusted_spawn_offset
		
		# Calculate launch velocity based on facing direction
		var adjusted_launch_velocity = launch_velocity
		if facing_left:
			adjusted_launch_velocity.x = -launch_velocity.x  # Flip horizontal velocity when facing left
		
		# Set the projectile's initial velocity and properties
		if projectile.has_method("initialize_parabolic_motion"):
			projectile.initialize_parabolic_motion(adjusted_launch_velocity, gravity_scale, facing_left)

# Method to manually stop enemy (can be called from other scripts)
func stop_enemy():
	is_active = false
	fire_timer.stop()
	if animated_sprite:
		animated_sprite.stop()

# Method to resume enemy activity
func resume_enemy():
	is_active = true
	fire_timer.start()
