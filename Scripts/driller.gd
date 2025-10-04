extends Node2D

@export var horizontal_speed: float = 80.0
@export var movement_range: float = 200.0
@export var jump_force: float = 300.0
@export var gravity: float = 800.0
@export var ground_check_distance: float = 20.0
@export var random_jump_variance: float = 100.0  # How much to vary jump force randomly

var start_position: Vector2
var direction: int = 1  # 1 for right, -1 for left
var velocity: Vector2 = Vector2.ZERO
var is_grounded: bool = false

@onready var ground_raycast: RayCast2D = $GroundRayCast2D
@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D

func _ready():
	start_position = global_position
	setup_raycasts()
	randomize()  # Initialize random number generator

func setup_raycasts():
	# Create ground detection raycast
	if not ground_raycast:
		ground_raycast = RayCast2D.new()
		add_child(ground_raycast)
		ground_raycast.name = "GroundRayCast2D"
	
	ground_raycast.target_position = Vector2(0, ground_check_distance)
	ground_raycast.collision_mask = 1  # Only detect layer 0 (tilemap/ground)
	ground_raycast.enabled = true

func _process(delta):
	# Check for ground detection
	is_grounded = ground_raycast.is_colliding()
	
	# Apply gravity
	velocity.y += gravity * delta
	
	# Horizontal movement
	velocity.x = direction * horizontal_speed
	
	# Check if we've moved too far from start position
	var distance_from_start = global_position.x - start_position.x
	
	# Reverse direction if we've reached the movement range
	if distance_from_start >= movement_range:
		direction = -1
	elif distance_from_start <= -movement_range:
		direction = 1
	
	# Apply velocity
	global_position += velocity * delta
	
	# Check if we've landed on ground
	if is_grounded and velocity.y > 0:
		# Jump again with random variation
		var random_force = jump_force + randf_range(-random_jump_variance, random_jump_variance)
		velocity.y = -random_force
		
		# Randomly change direction sometimes
		if randf() < 0.3:  # 30% chance to change direction on landing
			direction *= -1
		
