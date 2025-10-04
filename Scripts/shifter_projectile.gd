extends RigidBody2D

var roll_speed: float = 150.0
var facing_left: bool = false
var projectile_radius: float = 8.0
var detect_ground: bool = true
var is_initialized: bool = false
var is_unparryable: bool = false  # Track if this projectile is unparryable

@export var damage_amount: int = 25

@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D  # Changed to AnimatedSprite2D
@onready var collision_shape: CollisionShape2D = $CollisionShape2D
@onready var damage_zone: Area2D = $KillzoneScript_Area  # Fixed: Use correct node name

func _ready():
	# Configure RigidBody2D properties for rolling
	gravity_scale = 1.0  # Normal gravity
	lock_rotation = false  # Allow rotation for rolling effect
	continuous_cd = CCD_MODE_CAST_RAY  # Better collision detection
	contact_monitor = true
	max_contacts_reported = 4
	
	# Set collision layers
	# Layer 2: Projectiles
	# Mask 0 (tilemap) and 1 (player)
	collision_layer = 2
	collision_mask = 1 | 1  # Detects physics layer 0 (tilemap) and layer 1 (player)
	
	# Add to projectile group for easy identification
	add_to_group("projectiles")
	
	# Setup damage zone if it exists
	if damage_zone:
		damage_zone.body_entered.connect(_on_damage_zone_body_entered)

func initialize_rolling_motion(speed: float, left: bool, radius: float, ground_detect: bool, unparryable: bool = false):
	roll_speed = speed
	facing_left = left
	projectile_radius = radius
	detect_ground = ground_detect
	is_unparryable = unparryable
	is_initialized = true
	
	# Set the animation based on parryable status
	if animated_sprite:
		var anim_name = "unparryable" if is_unparryable else "canParry"
		if animated_sprite.sprite_frames.has_animation(anim_name):
			animated_sprite.play(anim_name)
			print("Projectile playing animation: ", anim_name)
		else:
			print("Warning: Animation '", anim_name, "' not found in projectile!")
	
	# Configure damage zone based on parryable status
	if damage_zone:
		if damage_zone.has_method("set_unparryable"):
			damage_zone.set_unparryable(is_unparryable)
		if damage_zone.has_method("set_damage_amount"):
			damage_zone.set_damage_amount(damage_amount)
		# Alternative: Set as properties if they exist
		if "unparryable" in damage_zone:
			damage_zone.unparryable = is_unparryable
		if "damage_amount" in damage_zone:
			damage_zone.damage_amount = damage_amount
		print("Projectile damage zone configured: unparryable = ", is_unparryable)
	
	# Apply initial horizontal velocity
	var direction = -1 if facing_left else 1
	linear_velocity = Vector2(direction * roll_speed, 0)
	
	# Set initial angular velocity for rolling effect
	# Angular velocity = linear velocity / radius (for realistic rolling)
	angular_velocity = (direction * roll_speed) / projectile_radius
	
	print("Initialized rolling projectile: unparryable = ", is_unparryable)

func _physics_process(delta):
	if not is_initialized:
		return
	
	# Maintain constant horizontal speed (compensate for friction)
	var direction = -1 if facing_left else 1
	var current_speed = abs(linear_velocity.x)
	
	# If speed drops below threshold, reapply velocity
	if current_speed < roll_speed * 0.8:
		linear_velocity.x = direction * roll_speed
		angular_velocity = (direction * roll_speed) / projectile_radius
	
	# Check if projectile is on ground for realistic rolling
	if detect_ground and is_on_floor():
		# Ensure rolling motion matches ground movement
		angular_velocity = (linear_velocity.x) / projectile_radius

func is_on_floor() -> bool:
	# Raycast downward to detect ground
	var space_state = get_world_2d().direct_space_state
	var query = PhysicsRayQueryParameters2D.create(
		global_position,
		global_position + Vector2(0, projectile_radius + 2)
	)
	query.collision_mask = 1  # Physics layer 0 (tilemap)
	query.exclude = [self]
	
	var result = space_state.intersect_ray(query)
	return result.size() > 0

func _on_damage_zone_body_entered(body: Node2D):
	# The damage zone will handle damage dealing
	# Just destroy the projectile after hitting player
	if body.is_in_group("player"):
		print("Projectile hit player, destroying projectile")
		queue_free()

func _on_body_entered(body):
	# Optional: Destroy on wall collision
	if body is TileMap or (body.has_method("is_in_group") and body.is_in_group("walls")):
		print("Projectile hit wall, destroying")
		queue_free()

# Optional: Destroy projectile after timeout
func _on_timer_timeout():
	queue_free()
