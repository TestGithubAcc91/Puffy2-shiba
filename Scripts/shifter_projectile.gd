extends RigidBody2D

var roll_speed: float = 150.0
var facing_left: bool = false
var projectile_radius: float = 8.0
var detect_ground: bool = true
var is_initialized: bool = false

@onready var sprite: Sprite2D = $Sprite2D
@onready var collision_shape: CollisionShape2D = $CollisionShape2D

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

func initialize_rolling_motion(speed: float, left: bool, radius: float, ground_detect: bool, texture: Texture2D):
	roll_speed = speed
	facing_left = left
	projectile_radius = radius
	detect_ground = ground_detect
	is_initialized = true
	
	# Set sprite texture if provided
	if texture and sprite:
		sprite.texture = texture
	
	# Apply initial horizontal velocity
	var direction = -1 if facing_left else 1
	linear_velocity = Vector2(direction * roll_speed, 0)
	
	# Set initial angular velocity for rolling effect
	# Angular velocity = linear velocity / radius (for realistic rolling)
	angular_velocity = (direction * roll_speed) / projectile_radius

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

func _on_body_entered(body):
	# Handle collision with player
	if body.is_in_group("player"):
		damage_player(body)
		queue_free()
	
	# Optionally destroy on wall collision
	# if body is TileMap or body.is_in_group("walls"):
	#     queue_free()

func damage_player(player):
	# Try to find and call damage on player's health component
	var health = player.get_node_or_null("Health")
	if health and health.has_method("take_damage"):
		health.take_damage(1)  # Adjust damage value as needed

# Optional: Destroy projectile after timeout
func _on_timer_timeout():
	queue_free()
