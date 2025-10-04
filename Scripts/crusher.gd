extends Node2D
@onready var area_2d = $Area2D
@onready var animated_sprite = $AnimatedSprite2D
var player = null
var crush_clone = null
var crush_area = null
var is_active = false
var clone_timer = 0.0
var killzone_activated = false

func _ready():
	area_2d.body_entered.connect(_on_body_entered)
	animated_sprite.play("inactive")

func _process(delta):
	if crush_clone and player and not killzone_activated:
		if crush_area:
			crush_area.global_position = player.global_position
			crush_area.global_position.y -= 12
		else:
			crush_clone.global_position = player.global_position
			crush_clone.global_position.y -= 12
		
		clone_timer += delta
		print("Clone timer: ", clone_timer)
		
		# Play crusherPrepare2 at 1.5s (0.5s before damage at 2.0s)
		if clone_timer >= 1.0 and clone_timer < 1.9:
			if crush_clone.animation != "crushPrepare2":
				crush_clone.play("crushPrepare2")
				print("Playing crushPrepare2 animation")
		
		# Play crush at 1.9s (0.1s before damage)
		elif clone_timer >= 1.9 and clone_timer < 2.0:
			if crush_clone.animation != "crush":
				crush_clone.play("crush")
				print("Playing crush animation")
		
		if clone_timer >= 2.0:
			activate_killzone()
	elif crush_area and player and killzone_activated:
		crush_area.global_position = player.global_position
		crush_area.global_position.y -= 12
		print("Killzone following player at: ", crush_area.global_position)

func _on_body_entered(body):
	if body.is_in_group("player") or body.name == "Player":
		player = body
		animated_sprite.play("active")
		is_active = true
		
		if not crush_clone:
			crush_clone = animated_sprite.duplicate()
			add_child(crush_clone)
			crush_clone.play("crushPrepare")
			crush_clone.global_position = player.global_position
			crush_clone.global_position.y -= 12
			crush_clone.z_index = 1
			crush_clone.modulate.a = 0.0
			
			var tween = create_tween()
			tween.tween_property(crush_clone, "modulate:a", 0.7, 0.5)
			
			clone_timer = 0.0
			killzone_activated = false

func activate_killzone():
	killzone_activated = true
	print("=== CRUSHER KILLZONE ACTIVATION START ===")
	print("Crusher killzone activated!")
	
	var clone_position = crush_clone.global_position
	print("Clone position before conversion: ", clone_position)
	
	# Load the killzone scene instead of creating Area2D manually
	var killzone_scene = load("res://Scenes/killzone.tscn")  # Adjust path if needed
	if killzone_scene == null:
		push_error("Could not load killzone.tscn!")
		return
	
	crush_area = killzone_scene.instantiate()
	add_child(crush_area)
	crush_area.global_position = clone_position
	print("Instantiated killzone.tscn at position: ", crush_area.global_position)
	
	# Add collision shape to the killzone Area2D
	var collision_shape = CollisionShape2D.new()
	var shape = CircleShape2D.new()
	shape.radius = 50
	collision_shape.shape = shape
	crush_area.add_child(collision_shape)
	print("Added collision shape with radius: ", shape.radius)
	
	# Add the animated sprite clone as a child to show visual
	remove_child(crush_clone)
	crush_area.add_child(crush_clone)
	crush_clone.position = Vector2.ZERO
	print("Added crush_clone sprite to killzone")
	
	# Set killzone properties
	crush_area.damage_amount = 25
	crush_area.ignore_iframes = false
	crush_area.unparryable = false
	
	print("Killzone properties:")
	print("  - damage_amount: ", crush_area.damage_amount)
	print("  - unparryable: ", crush_area.unparryable)
	print("  - collision_mask: ", crush_area.collision_mask)
	
	print("=== CRUSHER KILLZONE ACTIVATION COMPLETE ===")
	print("Starting fade out sequence...")
	
	var fade_tween = create_tween()
	fade_tween.tween_property(crush_clone, "modulate:a", 0.0, 0.5)
	await fade_tween.finished
	
	print("=== FADE OUT COMPLETE, CLEANING UP ===")
	animated_sprite.play("inactive")
	print("Main sprite set to inactive")
	
	if crush_area and is_instance_valid(crush_area):
		print("Freeing crush_area (killzone instance)...")
		crush_area.queue_free()
		crush_area = null
		print("crush_area freed")
	else:
		print("WARNING: crush_area was already freed or invalid")
	
	crush_clone = null
	player = null
	is_active = false
	killzone_activated = false
	clone_timer = 0.0
	print("=== CRUSHER RESET COMPLETE ===")
	print("")
