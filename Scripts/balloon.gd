extends Area2D

# Reference to the HIGH_JUMP_VELOCITY from the player script
const BALLOON_BOUNCE_VELOCITY = -350.0
# Optional: Add a cooldown to prevent multiple bounces
@export var bounce_cooldown: float = 0.5
@export var regenerate_time: float = 2.0

# Sound effects - Enhanced audio management
@export_group("Audio")
@export var pop_sound: AudioStream
@export var regenerate_sound: AudioStream
@export var ambient_sound: AudioStream  # Optional ambient/bobbing sound

# Bobbing animation settings
@export_group("Animation")
@export var bob_amplitude: float = 3.0  # How far up/down to bob (in pixels)
@export var bob_speed: float = 2.0      # How fast to bob (cycles per second)

var can_bounce: bool = true
var bounce_timer: Timer
var regenerate_timer: Timer

# Enhanced audio system - similar to beamer script
var pop_audio_player: AudioStreamPlayer2D
var regenerate_audio_player: AudioStreamPlayer2D
var ambient_audio_player: AudioStreamPlayer2D

# Optional: Visual feedback
@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D  # Adjust path as needed

# Bobbing animation variables
var initial_position: Vector2
var bob_time: float = 0.0
var is_bobbing: bool = true

func _ready():
	# Connect the body_entered signal
	body_entered.connect(_on_body_entered)
	
	# Store the initial position for bobbing reference
	initial_position = position
	
	# Setup enhanced audio system
	_setup_audio_system()
	
	# Setup cooldown timer
	bounce_timer = Timer.new()
	bounce_timer.wait_time = bounce_cooldown
	bounce_timer.one_shot = true
	bounce_timer.timeout.connect(_on_bounce_cooldown_timeout)
	add_child(bounce_timer)
	
	# Setup regenerate timer
	regenerate_timer = Timer.new()
	regenerate_timer.wait_time = regenerate_time
	regenerate_timer.one_shot = true
	regenerate_timer.timeout.connect(_on_regenerate_timeout)
	add_child(regenerate_timer)
	
	# Start ambient sound if available
	_start_ambient_sound()

# Enhanced audio system setup similar to beamer script
func _setup_audio_system():
	# Pop sound player
	pop_audio_player = AudioStreamPlayer2D.new()
	pop_audio_player.name = "PopAudioPlayer2D"
	pop_audio_player.bus = "SFX"  # Use SFX bus like the main game
	pop_audio_player.max_distance = 200.0  # Sound becomes inaudible beyond this distance
	pop_audio_player.attenuation = 0.4  # How quickly sound fades
	add_child(pop_audio_player)
	
	# Regenerate sound player
	regenerate_audio_player = AudioStreamPlayer2D.new()
	regenerate_audio_player.name = "RegenerateAudioPlayer2D"
	regenerate_audio_player.bus = "SFX"
	regenerate_audio_player.max_distance = 200.0
	regenerate_audio_player.attenuation = 0.4
	add_child(regenerate_audio_player)
	
	# Ambient sound player (for continuous bobbing sound if desired)
	ambient_audio_player = AudioStreamPlayer2D.new()
	ambient_audio_player.name = "AmbientAudioPlayer2D"
	ambient_audio_player.bus = "SFX"
	ambient_audio_player.max_distance = 150.0  # Shorter range for ambient
	ambient_audio_player.attenuation = 0.6  # Faster fade for ambient
	add_child(ambient_audio_player)
	
	# Assign streams if available
	if pop_sound:
		pop_audio_player.stream = pop_sound
	if regenerate_sound:
		regenerate_audio_player.stream = regenerate_sound
	if ambient_sound:
		ambient_audio_player.stream = ambient_sound
	
	print("Balloon audio system initialized")

# Start ambient sound (looping)
func _start_ambient_sound():
	if ambient_audio_player and ambient_sound and is_bobbing:
		ambient_audio_player.play()
		print("Starting balloon ambient sound")

# Stop ambient sound
func _stop_ambient_sound():
	if ambient_audio_player:
		ambient_audio_player.stop()
		print("Stopping balloon ambient sound")

# Play pop sound with enhanced management
func _play_pop_sound():
	if pop_audio_player and pop_sound:
		pop_audio_player.play()


# Play regenerate sound with enhanced management
func _play_regenerate_sound():
	if regenerate_audio_player and regenerate_sound:
		regenerate_audio_player.play()


func _process(delta):
	# Handle bobbing animation when balloon is active and visible
	if is_bobbing and modulate.a > 0.0:
		bob_time += delta
		var bob_offset = sin(bob_time * bob_speed * TAU) * bob_amplitude
		position.y = initial_position.y + bob_offset

func _on_body_entered(body):
	# Check if the entering body is the player and we can bounce
	if body.name == "Player" and can_bounce:
		bounce_player(body)

func bounce_player(player):
	# NEW: Override dash and high jump states before applying balloon bounce
	override_player_movement_states(player)
	
	# Apply the bounce velocity (same as high jump)
	player.velocity.y = BALLOON_BOUNCE_VELOCITY
	
	# Reset horizontal velocity to prevent dash momentum from interfering
	player.velocity.x = 0.0
	
	# Spawn the high jump air puff VFX
	if player.has_method("spawn_air_puffV"):
		player.spawn_air_puffV()
	
	# Play the whoosh sound (same as high jump)
	if player.has_method("_play_whoosh_sound"):
		player._play_whoosh_sound()
	
	# Start cooldown to prevent multiple bounces
	can_bounce = false
	bounce_timer.start()
	
	# Play pop animation and make balloon non-interactable
	pop_balloon()

# NEW: Function to override player movement states
func override_player_movement_states(player):
	# Check if player is dashing and cancel it
	if player.has_method("end_dash") and player.is_dashing:
		player.end_dash()
		print("Balloon: Canceling player dash")
	
	# Check if player is bouncing (wall bounce) and cancel it
	if player.has_method("end_bounce") and player.is_bouncing:
		player.end_bounce()
		print("Balloon: Canceling player bounce")
	
	# Reset dash-related flags
	if "is_dashing" in player:
		player.is_dashing = false
	if "dash_direction" in player:
		player.dash_direction = Vector2.ZERO
	if "is_vine_release_dash" in player:
		player.is_vine_release_dash = false
		
	# Reset bounce-related flags
	if "is_bouncing" in player:
		player.is_bouncing = false
	if "bounce_direction_vector" in player:
		player.bounce_direction_vector = Vector2.ZERO
	
	# Stop dash and bounce timers if they exist
	if "dash_timer" in player and player.dash_timer:
		player.dash_timer.stop()
	if "bounce_timer" in player and player.bounce_timer:
		player.bounce_timer.stop()
	
	# Reset any time scaling effects from dash/high jump
	if player.has_method("reset_timescale"):
		player.reset_timescale()
	
	print("Balloon: Player movement states overridden")

func pop_balloon():
	# Stop bobbing during pop sequence
	is_bobbing = false
	
	# Stop ambient sound when balloon pops
	_stop_ambient_sound()
	
	# Play pop sound effect with enhanced audio management
	_play_pop_sound()
	
	# Make balloon non-interactable but keep it visible for the animation
	set_deferred("monitoring", false)
	set_deferred("monitorable", false)
	
	# Play the pop animation
	if animated_sprite and animated_sprite.sprite_frames and animated_sprite.sprite_frames.has_animation("pop"):
		animated_sprite.play("pop")
		# Wait for pop animation to finish before hiding balloon
		if animated_sprite.animation_finished.is_connected(_on_pop_animation_finished):
			animated_sprite.animation_finished.disconnect(_on_pop_animation_finished)
		animated_sprite.animation_finished.connect(_on_pop_animation_finished)
	else:
		# If no pop animation, hide immediately and start regenerate timer
		modulate.a = 0.0
		regenerate_timer.start()

func _on_bounce_cooldown_timeout():
	can_bounce = true

func _on_pop_animation_finished():
	# Disconnect the signal to avoid multiple connections
	if animated_sprite.animation_finished.is_connected(_on_pop_animation_finished):
		animated_sprite.animation_finished.disconnect(_on_pop_animation_finished)
	
	# Now hide the balloon and start regenerate timer
	modulate.a = 0.0
	regenerate_timer.start()

func _on_regenerate_timeout():
	# Make balloon visible again before playing regenerate animation
	modulate.a = 1.0
	
	# Play regenerate sound effect with enhanced audio management
	_play_regenerate_sound()
	
	# Play regenerate animation
	if animated_sprite and animated_sprite.sprite_frames and animated_sprite.sprite_frames.has_animation("regenerate"):
		animated_sprite.play("regenerate")
		# Wait for regenerate animation to finish before making balloon active
		if animated_sprite.animation_finished.is_connected(_on_regenerate_animation_finished):
			animated_sprite.animation_finished.disconnect(_on_regenerate_animation_finished)
		animated_sprite.animation_finished.connect(_on_regenerate_animation_finished)
	else:
		# If no regenerate animation, just restore immediately
		restore_balloon()

func _on_regenerate_animation_finished():
	# Disconnect the signal to avoid multiple connections
	if animated_sprite.animation_finished.is_connected(_on_regenerate_animation_finished):
		animated_sprite.animation_finished.disconnect(_on_regenerate_animation_finished)
	restore_balloon()

func restore_balloon():
	# Make balloon visible and interactable again using set_deferred
	modulate.a = 1.0  # Make visible
	set_deferred("monitoring", true)
	set_deferred("monitorable", true)
	
	# Resume bobbing animation
	is_bobbing = true
	
	# Restart ambient sound when balloon is restored
	_start_ambient_sound()

# Cleanup function to ensure sounds stop if balloon is destroyed
func _exit_tree():
	_stop_ambient_sound()
	# Stop all other sounds as well
	if pop_audio_player:
		pop_audio_player.stop()
	if regenerate_audio_player:
		regenerate_audio_player.stop()

# Helper function to control ambient sound at runtime
func set_ambient_sound_enabled(enabled: bool):
	if enabled:
		_start_ambient_sound()
	else:
		_stop_ambient_sound()

# Helper function to adjust sound ranges at runtime
func set_sound_range(new_range: float):
	if pop_audio_player:
		pop_audio_player.max_distance = new_range
	if regenerate_audio_player:
		regenerate_audio_player.max_distance = new_range
	if ambient_audio_player:
		ambient_audio_player.max_distance = new_range * 0.75  # Ambient has shorter range
