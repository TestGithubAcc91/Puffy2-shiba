extends Node2D

# Physics properties
var velocity: Vector2 = Vector2.ZERO
var gravity: float = 500.0  # Gravity strength
var gravity_scale: float = 1.0  # Multiplier for gravity effect
var moving_left: bool = false

# Collision detection
var ray_cast_down: RayCast2D
var ray_cast_left: RayCast2D
var ray_cast_right: RayCast2D

# State management
var cleanup_timer: Timer
var is_disappearing: bool = false
var has_hit_ground: bool = false

func _ready():
	# Set up cleanup timer to prevent memory buildup
	cleanup_timer = Timer.new()
	cleanup_timer.wait_time = 8.0  # Longer timeout for parabolic projectiles
	cleanup_timer.one_shot = true
	cleanup_timer.timeout.connect(_on_timeout)
	add_child(cleanup_timer)
	cleanup_timer.start()
	
	# Create raycasts for collision detection
	setup_raycasts()
	
	# Connect collision detection for hitting players
	var area2d = get_area2d_node()
	if area2d:
		area2d.body_entered.connect(_on_body_entered)
		area2d.area_entered.connect(_on_area_entered)
		


func setup_raycasts():
	# Downward raycast for ground detection
	ray_cast_down = RayCast2D.new()
	ray_cast_down.target_position = Vector2(0, 5)  # Cast 5 pixels down
	ray_cast_down.enabled = true
	add_child(ray_cast_down)
	
	# Left raycast for wall detection
	ray_cast_left = RayCast2D.new()
	ray_cast_left.target_position = Vector2(-5, 0)  # Cast 5 pixels to the left
	ray_cast_left.enabled = true
	add_child(ray_cast_left)
	
	# Right raycast for wall detection
	ray_cast_right = RayCast2D.new()
	ray_cast_right.target_position = Vector2(5, 0)  # Cast 5 pixels to the right
	ray_cast_right.enabled = true
	add_child(ray_cast_right)

func _process(delta):
	# Only move if not disappearing
	if not is_disappearing:
		# Apply physics
		update_physics(delta)
		
		# Check for collisions
		check_collisions()

func update_physics(delta):
	# Apply gravity to vertical velocity
	velocity.y += gravity * gravity_scale * delta
	
	# Update position based on velocity
	position += velocity * delta
	
	# Update sprite rotation based on velocity direction
	update_sprite_rotation()

func update_sprite_rotation():
	# Find the sprite node and rotate it to match velocity direction
	var sprite = get_sprite_node()
	if sprite and velocity.length() > 0:
		var angle = velocity.angle()
		sprite.rotation = angle

func check_collisions():
	# Check for ground collision
	if ray_cast_down.is_colliding() and velocity.y > 0:
		handle_ground_collision()
		return
	
	# Check for wall collisions
	if (ray_cast_left.is_colliding() and velocity.x < 0) or (ray_cast_right.is_colliding() and velocity.x > 0):
		handle_wall_collision()
		return

func handle_ground_collision():
	if not has_hit_ground:
		has_hit_ground = true
		# Create a small bounce effect
		velocity.y = -velocity.y * 0.3  # Bounce with 30% of impact velocity
		velocity.x = velocity.x * 0.7   # Reduce horizontal velocity
		
		# If velocity is too small, start disappearing
		if abs(velocity.y) < 50:
			start_disappear_sequence()

func handle_wall_collision():
	start_disappear_sequence()

func initialize_parabolic_motion(initial_velocity: Vector2, grav_scale: float, facing_left: bool):
	velocity = initial_velocity
	gravity_scale = grav_scale
	moving_left = facing_left
	
	# Set initial sprite direction
	var sprite = get_sprite_node()
	if sprite:
		sprite.flip_h = facing_left

func set_direction(facing_left: bool):
	moving_left = facing_left
	
	# Try to find and flip the sprite node
	var sprite = get_sprite_node()
	if sprite:
		sprite.flip_h = facing_left

func get_sprite_node():
	# Check for common sprite node types
	if has_node("Sprite2D"):
		return get_node("Sprite2D")
	elif has_node("AnimatedSprite2D"):
		return get_node("AnimatedSprite2D")
	else:
		# Try to find any sprite child node
		for child in get_children():
			if child is Sprite2D or child is AnimatedSprite2D:
				return child
	return null

func get_area2d_node() -> Area2D:
	# Find the Area2D node
	if has_node("Area2D"):
		return get_node("Area2D")
	else:
		for child in get_children():
			if child is Area2D:
				return child
	return null

func _on_body_entered(body: Node2D):
	# Check if it hit a player (has HealthScript component)
	var health_component = body.get_node("HealthScript") if body.has_node("HealthScript") else null
	if health_component and health_component is Health:
		start_disappear_sequence()
		return

func _on_area_entered(area: Area2D):
	# Additional collision detection for other Area2D nodes if needed
	print("Parabolic projectile hit area: ", area.name)

func start_disappear_sequence():
	# Prevent multiple calls
	if is_disappearing:
		return
	
	# Stop movement
	is_disappearing = true
	velocity = Vector2.ZERO
	
	# Stop the cleanup timer since we're disappearing now
	if cleanup_timer and is_instance_valid(cleanup_timer):
		cleanup_timer.stop()
	
	# Deactivate Area2D to prevent damage during disappear animation
	var area2d = get_area2d_node()
	if area2d:
		area2d.set_deferred("monitoring", false)
		area2d.set_deferred("monitorable", false)
	
	# Find the animated sprite
	var animated_sprite = null
	
	if has_node("AnimatedSprite2D"):
		animated_sprite = get_node("AnimatedSprite2D")
	else:
		for child in get_children():
			if child is AnimatedSprite2D:
				animated_sprite = child
				break
	
	# Play disappear animation and delete after it finishes
	if animated_sprite:
		animated_sprite.play("Disappear")
		# Wait for the animation duration
		await get_tree().create_timer(5.0 / 9.0).timeout
		queue_free()
	else:
		queue_free()

func _on_timeout():
	start_disappear_sequence()
