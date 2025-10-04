extends RigidBody2D

var roll_speed: float = 150.0
var facing_left: bool = false
var projectile_radius: float = 8.0
var detect_ground: bool = true
var is_initialized: bool = false
var is_unparryable: bool = false  # Track if this projectile is unparryable
var is_disappearing: bool = false
var lifetime_timer: Timer
var sprite_rotation: float = 0.0  # Track sprite rotation manually

@export var damage_amount: int = 25
@export var disappear_vfx: PackedScene  # VFX scene to spawn when disappearing
@export var lifetime: float = 3.0  # Time before projectile disappears

@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var collision_shape: CollisionShape2D = $CollisionShape2D
@onready var damage_zone: Area2D = $KillzoneScript_Area
@onready var unparryable_warning: Label = $UnparryableWarning

func _ready():
	# Configure RigidBody2D properties for rolling
	gravity_scale = 1.0
	lock_rotation = true  # Keep the RigidBody2D rotation locked
	continuous_cd = CCD_MODE_CAST_RAY
	contact_monitor = true
	max_contacts_reported = 4
	
	# Set collision layers
	collision_layer = 2
	collision_mask = 1 | 1
	
	# Add to projectile group for easy identification
	add_to_group("projectiles")
	
	# Setup damage zone if it exists
	if damage_zone:
		damage_zone.body_entered.connect(_on_damage_zone_body_entered)
	
	# Hide the warning label initially
	if unparryable_warning:
		unparryable_warning.visible = false
	
	# Set up lifetime timer
	lifetime_timer = Timer.new()
	lifetime_timer.wait_time = lifetime
	lifetime_timer.one_shot = true
	lifetime_timer.timeout.connect(_on_lifetime_timeout)
	add_child(lifetime_timer)
	lifetime_timer.start()

func initialize_rolling_motion(speed: float, left: bool, radius: float, ground_detect: bool, unparryable: bool = false):
	roll_speed = speed
	facing_left = left
	projectile_radius = radius
	detect_ground = ground_detect
	is_unparryable = unparryable
	is_initialized = true
	
	# Show/hide warning based on unparryable status
	if unparryable_warning:
		unparryable_warning.visible = is_unparryable
	
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
		if "unparryable" in damage_zone:
			damage_zone.unparryable = is_unparryable
		if "damage_amount" in damage_zone:
			damage_zone.damage_amount = damage_amount
		print("Projectile damage zone configured: unparryable = ", is_unparryable)
	
	# Apply initial horizontal velocity
	var direction = -1 if facing_left else 1
	linear_velocity = Vector2(direction * roll_speed, 0)
	
	print("Initialized rolling projectile: unparryable = ", is_unparryable)

func _physics_process(delta):
	if not is_initialized or is_disappearing:
		return
	
	# Maintain constant horizontal speed
	var direction = -1 if facing_left else 1
	var current_speed = abs(linear_velocity.x)
	
	if current_speed < roll_speed * 0.8:
		linear_velocity.x = direction * roll_speed
	
	# Calculate sprite rotation based on movement
	var rotation_speed = (direction * roll_speed) / projectile_radius
	sprite_rotation += rotation_speed * delta
	
	# Apply rotation to sprite only
	if animated_sprite:
		animated_sprite.rotation = sprite_rotation
	
	# Keep the label upright (counter-rotate to cancel out any rotation)
	if unparryable_warning:
		unparryable_warning.rotation = 0

func is_on_floor() -> bool:
	var space_state = get_world_2d().direct_space_state
	var query = PhysicsRayQueryParameters2D.create(
		global_position,
		global_position + Vector2(0, projectile_radius + 2)
	)
	query.collision_mask = 1
	query.exclude = [self]
	
	var result = space_state.intersect_ray(query)
	return result.size() > 0

func _on_damage_zone_body_entered(body: Node2D):
	if body.is_in_group("player"):
		print("Projectile hit player, destroying projectile")
		start_disappear_sequence()

func _on_body_entered(body):
	if body is TileMap or (body.has_method("is_in_group") and body.is_in_group("walls")):
		print("Projectile hit wall, destroying")
		start_disappear_sequence()

func _on_lifetime_timeout():
	start_disappear_sequence()

func start_disappear_sequence():
	if is_disappearing:
		return
	
	is_disappearing = true
	
	# Hide warning label
	if unparryable_warning:
		unparryable_warning.visible = false
	
	# Stop the lifetime timer
	if lifetime_timer and is_instance_valid(lifetime_timer):
		lifetime_timer.stop()
	
	# Stop movement
	linear_velocity = Vector2.ZERO
	freeze = true
	
	# Disable damage zone
	if damage_zone:
		damage_zone.set_deferred("monitoring", false)
		damage_zone.set_deferred("monitorable", false)
	
	# Disable collision
	if collision_shape:
		collision_shape.set_deferred("disabled", true)
	
	# Spawn VFX if available
	if disappear_vfx:
		var vfx_instance = disappear_vfx.instantiate()
		get_parent().add_child(vfx_instance)
		vfx_instance.global_position = global_position
	
	# Play disappear animation
	if animated_sprite and animated_sprite.sprite_frames.has_animation("Disappear"):
		animated_sprite.play("Disappear")
		# Wait for animation to finish
		await animated_sprite.animation_finished
		queue_free()
	else:
		# If no disappear animation, just destroy after a short delay
		await get_tree().create_timer(0.1).timeout
		queue_free()
