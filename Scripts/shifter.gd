extends Node2D

@export var projectile_scene: PackedScene
@export var fire_rate: float = 3.0  # Time between shots in seconds
@export var spawn_offset: Vector2 = Vector2(0, 4)  # Offset from enemy center to spawn projectiles
@export var facing_left: bool = false  # Toggle for direction

# Rolling projectile properties
@export_group("Rolling Physics")
@export var roll_speed: float = 150.0  # Speed of rolling projectile
@export var projectile_radius: float = 8.0  # Radius for rolling rotation calculation
@export var detect_ground: bool = true  # Enable ground detection on physics layer 0

# Projectile appearance
@export_group("Projectile Visuals")
@export var projectile_sprite_parryable: Texture2D  # Sprite for parryable projectile
@export var projectile_sprite_unparryable: Texture2D  # Sprite for unparryable projectile

# Parry/Unparryable system
@export_group("Attack Pattern")
@export var random_parry_pattern: bool = true  # Randomly choose between parryable/unparryable
@export var unparryable_chance: float = 0.5  # Chance of shooting unparryable (0.0 to 1.0)

# Audio properties
@export_group("Audio")
@export var shoot_sound: AudioStream  # Sound to play when shooting

var fire_timer: Timer
var animated_sprite: AnimatedSprite2D
var is_active: bool = true  # Flag to control enemy activity
var next_shot_unparryable: bool = false  # Track what type of shot is next

# Audio system
var shoot_audio_player: AudioStreamPlayer2D

# Unparryable warning label
@onready var unparryable_warning: Label = $UnparryableWarning

func _ready():
	# DEBUGGING: Check if projectile scene is assigned
	if not projectile_scene:
		push_error("ERROR: projectile_scene is not assigned in the Inspector!")
	
	# Get the AnimatedSprite2D node (assumes it's a child of this node)
	animated_sprite = get_node_or_null("AnimatedSprite2D")
	if not animated_sprite:
		push_error("ERROR: AnimatedSprite2D node not found as child!")
		return
	
	print("Enemy shooter initialized successfully")
	
	# Set initial facing direction
	update_facing_direction()
	
	# Create and configure the firing timer
	fire_timer = Timer.new()
	fire_timer.wait_time = fire_rate
	fire_timer.autostart = true
	fire_timer.timeout.connect(_on_fire_timer_timeout)
	add_child(fire_timer)
	
	print("Fire timer started with rate: ", fire_rate, " seconds")
	
	# Connect to player's death signal if available
	connect_to_player_signals()
	
	# Setup audio system
	_setup_audio_system()
	
	# Hide the warning label initially
	unparryable_warning = get_node_or_null("UnparryableWarning")
	if unparryable_warning:
		unparryable_warning.visible = false
	
	# Decide first shot type
	decide_next_shot_type()

# Setup the audio system
func _setup_audio_system():
	shoot_audio_player = AudioStreamPlayer2D.new()
	shoot_audio_player.name = "ShootAudioPlayer2D"
	shoot_audio_player.bus = "SFX"  # Use SFX bus like the main game
	
	# Configure sound range and attenuation
	shoot_audio_player.max_distance = 500.0  # Sound becomes inaudible beyond this distance
	shoot_audio_player.attenuation = 1.0  # How quickly sound fades (higher = faster fade)
	
	add_child(shoot_audio_player)
	
	if shoot_sound:
		shoot_audio_player.stream = shoot_sound
	
	print("Rolling shooter audio system initialized")

# Function to play shoot sound
func _play_shoot_sound():
	if shoot_audio_player and shoot_sound:
		shoot_audio_player.play()

# Decide whether next shot will be parryable or unparryable
func decide_next_shot_type():
	if random_parry_pattern:
		next_shot_unparryable = randf() < unparryable_chance
		print("Next shot type decided: ", "UNPARRYABLE" if next_shot_unparryable else "PARRYABLE")
	else:
		next_shot_unparryable = false

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
	
	# Hide warning label
	if unparryable_warning:
		unparryable_warning.visible = false
	
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
	
	# Determine which animation to play based on shot type
	var anim_name = "canParry" if not next_shot_unparryable else "unparryable"
	
	# Show unparryable warning if this is an unparryable attack
	if next_shot_unparryable and unparryable_warning:
		unparryable_warning.visible = true
	
	# Check if the animation exists
	if animated_sprite.sprite_frames.has_animation(anim_name):
		animated_sprite.play(anim_name)
		print("Playing animation: ", anim_name)
	else:
		# Fallback warning
		print("Warning: Animation '", anim_name, "' not found!")
		return
	
	# Check if tree exists before creating timer
	var tree = get_tree()
	if not tree or not is_active:
		return
	
	# Wait for the animation to complete (adjust timing as needed for your animation length)
	await tree.create_timer(1.0).timeout
	
	# Check if still active after await
	if not is_active:
		return
	
	# Play shoot sound when spawning projectile
	_play_shoot_sound()
	
	spawn_projectile()
	
	# Play shrink animation after shooting
	var shrink_anim = "canParryShrink" if not next_shot_unparryable else "unparryableShrink"
	if animated_sprite.sprite_frames.has_animation(shrink_anim):
		animated_sprite.play(shrink_anim)
		await tree.create_timer(0.2).timeout
	
	# Check if still active after shrink
	if not is_active:
		return
	
	# Hide unparryable warning after shrinking
	if unparryable_warning:
		unparryable_warning.visible = false
	
	# Wait 1 second before growing
	await tree.create_timer(1.0).timeout
	
	# Check if still active after wait
	if not is_active:
		return
	
	# Play grow animation
	var grow_anim = "canParryGrow" if not next_shot_unparryable else "unparryableGrow"
	if animated_sprite.sprite_frames.has_animation(grow_anim):
		animated_sprite.play(grow_anim)
		await tree.create_timer(0.2).timeout
	
	# Check if still active after grow
	if not is_active:
		return
	
	# Return to idle animation
	if animated_sprite.sprite_frames.has_animation(anim_name):
		animated_sprite.play(anim_name)
	
	# Decide next shot type for the following attack
	decide_next_shot_type()

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
		
		# Initialize rolling projectile with properties
		if projectile.has_method("initialize_rolling_motion"):
			projectile.initialize_rolling_motion(
				roll_speed,
				facing_left,
				projectile_radius,
				detect_ground,
				next_shot_unparryable  # Pass unparryable status
			)
		
		print("Spawned ", "UNPARRYABLE" if next_shot_unparryable else "PARRYABLE", " projectile")

# Method to manually stop enemy (can be called from other scripts)
func stop_enemy():
	is_active = false
	fire_timer.stop()
	
	# Hide warning label
	if unparryable_warning:
		unparryable_warning.visible = false
	
	if animated_sprite:
		animated_sprite.stop()

# Method to resume enemy activity
func resume_enemy():
	is_active = true
	fire_timer.start()
