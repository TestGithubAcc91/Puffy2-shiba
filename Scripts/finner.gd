extends Node2D
# Movement properties
@export var horizontal_distance: float = 100.0  # Distance to move left and right
@export var horizontal_speed: float = 60.0  # Speed of horizontal movement
@export var vertical_distance: float = 50.0  # Distance to move up and down during vertical phase
@export var vertical_speed: float = 80.0  # Speed of vertical movement
@export var vertical_chance: float = 0.3  # Chance (0.0 to 1.0) to trigger vertical movement at each horizontal end

# Audio properties - NEW
@export_group("Audio")
@export var splash_sound: AudioStream  # Sound to play when starting vertical movement

# Movement state
enum MovementState { HORIZONTAL, VERTICAL_SLOWDOWN, VERTICAL_UP, VERTICAL_DOWN }
var current_state: MovementState = MovementState.HORIZONTAL
var moving_right: bool = true
var initial_position: Vector2
var vertical_start_position: Vector2
var slowdown_timer: float = 0.0
var slowdown_duration: float = 0.5
var has_played_splash_sound: bool = false  # Flag to ensure sound plays only once per vertical cycle

@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D

# Audio system - NEW
var splash_audio_player: AudioStreamPlayer2D

func _ready():
	# Store the initial position
	initial_position = position
	
	# Setup audio system - NEW
	_setup_audio_system()

# NEW: Setup the audio system
func _setup_audio_system():
	splash_audio_player = AudioStreamPlayer2D.new()
	splash_audio_player.name = "SplashAudioPlayer2D"
	splash_audio_player.bus = "SFX"  # Use SFX bus like the main game
	add_child(splash_audio_player)
	
	if splash_sound:
		splash_audio_player.stream = splash_sound
	
	print("Finner splash audio system initialized")

# NEW: Function to play splash sound
func _play_splash_sound():
	if splash_audio_player and splash_sound:
		splash_audio_player.play()
		print("Playing splash sound effect")

func _process(delta: float):
	match current_state:
		MovementState.HORIZONTAL:
			handle_horizontal_movement(delta)
		MovementState.VERTICAL_SLOWDOWN:
			handle_vertical_slowdown(delta)
		MovementState.VERTICAL_UP:
			handle_vertical_up_movement(delta)
		MovementState.VERTICAL_DOWN:
			handle_vertical_down_movement(delta)

func handle_horizontal_movement(delta):
	var movement = horizontal_speed * delta
	
	if moving_right:
		position.x += movement
		if animated_sprite:
			animated_sprite.flip_h = true
			animated_sprite.rotation = 0  # Reset rotation for horizontal movement
		
		# Check if we've reached the right limit
		if position.x >= initial_position.x + horizontal_distance:
			position.x = initial_position.x + horizontal_distance
			moving_right = false
			check_for_vertical_movement()
	else:
		position.x -= movement
		if animated_sprite:
			animated_sprite.flip_h = false
			animated_sprite.rotation = 0  # Reset rotation for horizontal movement
		
		# Check if we've reached the left limit
		if position.x <= initial_position.x - horizontal_distance:
			position.x = initial_position.x - horizontal_distance
			moving_right = true
			check_for_vertical_movement()

func check_for_vertical_movement():
	# Randomly decide whether to do vertical movement
	if randf() < vertical_chance:
		# Start vertical slowdown before jumping
		vertical_start_position = position
		slowdown_timer = 0.0
		has_played_splash_sound = false  # Reset flag for new vertical cycle
		current_state = MovementState.VERTICAL_SLOWDOWN

func handle_vertical_slowdown(delta):
	# NEW: Play splash sound at the start of slowdown (0.5s before vertical movement)
	if not has_played_splash_sound:
		_play_splash_sound()
		has_played_splash_sound = true
	
	# Gradually slow down horizontal movement
	slowdown_timer += delta
	var slowdown_progress = slowdown_timer / slowdown_duration
	var speed_multiplier = 1.0 - slowdown_progress  # Goes from 1.0 to 0.0
	
	var movement = horizontal_speed * delta * speed_multiplier
	
	# Continue moving in the same direction but slower
	if moving_right:
		position.x += movement
	else:
		position.x -= movement
	
	# After slowdown duration, start moving up
	if slowdown_timer >= slowdown_duration:
		current_state = MovementState.VERTICAL_UP

func handle_vertical_up_movement(delta):
	
	var movement = vertical_speed * delta
	position.y -= movement
	
	# Rotate sprite to look upward, accounting for horizontal flip
	if animated_sprite:
		if animated_sprite.flip_h:
			animated_sprite.rotation = -PI/2  # When flipped, rotate counter-clockwise to face up
		else:
			animated_sprite.rotation = PI/2  # When not flipped, rotate clockwise to face up
	
	# Check if we've reached the upper limit
	if position.y <= vertical_start_position.y - vertical_distance:
		position.y = vertical_start_position.y - vertical_distance
		current_state = MovementState.VERTICAL_DOWN

func handle_vertical_down_movement(delta):
	var movement = vertical_speed * delta
	position.y += movement
	
	# Rotate sprite to look downward, accounting for horizontal flip
	if animated_sprite:
		if animated_sprite.flip_h:
			animated_sprite.rotation = PI/2  # When flipped, rotate clockwise to face down
		else:
			animated_sprite.rotation = -PI/2  # When not flipped, rotate counter-clockwise to face down
	
	# Check if we've returned to the starting vertical position
	if position.y >= vertical_start_position.y:
		position.y = vertical_start_position.y
		current_state = MovementState.HORIZONTAL

# Optional: Method to force vertical movement (for testing or special events)
func trigger_vertical_movement():
	if current_state == MovementState.HORIZONTAL:
		vertical_start_position = position
		slowdown_timer = 0.0
		has_played_splash_sound = false  # Reset flag for triggered vertical movement
		current_state = MovementState.VERTICAL_SLOWDOWN

# Optional: Method to get current movement state (for debugging or external scripts)
func get_movement_state() -> String:
	match current_state:
		MovementState.HORIZONTAL:
			return "horizontal"
		MovementState.VERTICAL_SLOWDOWN:
			return "vertical_slowdown"
		MovementState.VERTICAL_UP:
			return "vertical_up"
		MovementState.VERTICAL_DOWN:
			return "vertical_down"
		_:
			return "unknown"
