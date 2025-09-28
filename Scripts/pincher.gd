extends Node2D

@export var speed: float = 100.0
@export var movement_range: float = 200.0
@export var detection_range: float = 150.0
@export var dash_speed: float = 300.0
@export var dash_distance: float = 80.0
@export var recoil_distance: float = 60.0
@export var detection_pause_time: float = 0.5

# NEW: Reference to the killzone to control parryability
@export var killzone: Area2D
# NEW: Reference to the unparryable warning label
@export var unparryable_warning: Label

var start_position: Vector2
var direction: int = 1  # 1 for right, -1 for left
var player_detected: bool = false
var dash_position: Vector2
var state: String = "patrolling"  # "patrolling", "detected", "dashing", "recoiling"
var dash_start_position: Vector2
var recoil_start_position: Vector2
var detection_timer: float = 0.0

@onready var raycast: RayCast2D = $RayCast2D
@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D

func _ready():
	start_position = global_position
	setup_raycast()

func setup_raycast():
	# Create RayCast2D node if it doesn't exist
	if not raycast:
		raycast = RayCast2D.new()
		add_child(raycast)
		raycast.name = "RayCast2D"
	
	# Setup raycast pointing left (facing direction)
	raycast.target_position = Vector2(-detection_range, 0)
	raycast.collision_mask = 2  # Only detect layer 2 (player)
	raycast.enabled = true

func _process(delta):
	# Check for player detection
	player_detected = raycast.is_colliding()
	
	match state:
		"patrolling":
			handle_patrolling(delta)
		"detected":
			handle_detected(delta)
		"dashing":
			handle_dashing(delta)
		"recoiling":
			handle_recoiling(delta)

func handle_patrolling(delta):
	if player_detected:
		# Start detection phase
		state = "detected"
		detection_timer = detection_pause_time
		if animated_sprite:
			animated_sprite.play("Detected")
		return
	
	# Normal patrol movement
	global_position.x += direction * speed * delta
	
	# Check if we've moved too far from start position
	var distance_from_start = global_position.x - start_position.x
	
	# Reverse direction if we've reached the movement range
	if distance_from_start >= movement_range:
		direction = -1
	elif distance_from_start <= -movement_range:
		direction = 1

func handle_detected(delta):
	# Count down the detection timer
	detection_timer -= delta
	
	# Stay still during detection phase
	if detection_timer <= 0.0:
		# Start dash attack
		state = "dashing"
		dash_start_position = global_position
		dash_position = global_position + Vector2(-dash_distance, 0)  # Dash left (facing direction)
		
		# NEW: Make the attack parryable during dash
		if killzone:
			killzone.unparryable = false
			print("Pincher dash started - attack is now PARRYABLE")
		
		# NEW: Hide the unparryable warning during dash
		if unparryable_warning:
			unparryable_warning.visible = false
			print("Unparryable warning hidden during dash")
		
		if animated_sprite:
			animated_sprite.play("Dash")

func handle_dashing(delta):
	# Calculate distance traveled and progress (0.0 to 1.0)
	var total_distance = dash_start_position.distance_to(dash_position)
	var current_distance = dash_start_position.distance_to(global_position)
	var progress = current_distance / total_distance
	
	# Spring-like easing: slow down as we get further left (higher progress)
	# Custom ease_out: 1 - (1 - x)^2
	var speed_multiplier = 1.0 - pow(progress, 2)  # Starts at 1.0, decelerates
	speed_multiplier = max(speed_multiplier, 0.2)  # Minimum speed to ensure we reach the target
	
	# Move towards dash position with variable speed
	var dash_direction = (dash_position - global_position).normalized()
	global_position += dash_direction * dash_speed * speed_multiplier * delta
	
	# Check if we've reached the dash position
	if global_position.distance_to(dash_position) < 5.0:
		state = "recoiling"
		# Set recoil start position and target position
		recoil_start_position = global_position
		dash_position = dash_start_position + Vector2(recoil_distance, 0)  # Recoil right
		
		# NEW: Make the attack unparryable during recoil
		if killzone:
			killzone.unparryable = true
			print("Pincher recoil started - attack is now UNPARRYABLE")
		
		# NEW: Show the unparryable warning during recoil
		if unparryable_warning:
			unparryable_warning.visible = true
			print("Unparryable warning shown during recoil")

func handle_recoiling(delta):
	# Calculate distance traveled and progress (0.0 to 1.0)
	var total_distance = recoil_start_position.distance_to(dash_position)
	var current_distance = recoil_start_position.distance_to(global_position)
	var progress = current_distance / total_distance
	
	# Same spring-like easing as dash: slow down as we get further from start (higher progress)
	# Custom ease_out: 1 - (1 - x)^2
	var speed_multiplier = 1.0 - pow(progress, 2)  # Starts at 1.0, decelerates
	speed_multiplier = max(speed_multiplier, 0.2)  # Minimum speed to ensure we reach the target
	
	# Move towards recoil position with variable speed
	var recoil_direction = (dash_position - global_position).normalized()
	global_position += recoil_direction * dash_speed * speed_multiplier * delta
	
	# Check if we've reached the recoil position
	if global_position.distance_to(dash_position) < 5.0:
		state = "patrolling"  # Return to normal patrol
		if animated_sprite:
			animated_sprite.play("default")
