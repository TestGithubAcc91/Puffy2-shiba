extends Area2D
@onready var collision_shape = $CollisionShape2D
@onready var sprite = $Sprite2D
@onready var static_body = $StaticBody2D
@onready var static_body_collision = $StaticBody2D/CollisionShape2D
var player_node
var is_destroyed: bool = false
var player_touched_while_dashing: bool = false

func _ready():
	await get_tree().process_frame
	player_node = get_tree().root.find_child("Player", true, false)
	
	# Connect to Area2D body_entered signal
	body_entered.connect(_on_body_entered)
	
	if player_node and player_node.has_signal("dash_started"):
		call_deferred("_connect_to_player")

func _connect_to_player():
	if player_node and player_node.has_signal("dash_started"):
		player_node.dash_started.connect(_on_player_dash_started)

func _on_body_entered(body):
	"""Detect when player touches the Area2D while dashing"""
	if body == player_node and player_node.is_dashing and not is_destroyed:
		player_touched_while_dashing = true
		print("Player touched crate while dashing!")

func _on_player_dash_started():
	"""Called when player starts a dash - disable StaticBody2D collision only"""
	if is_destroyed or not static_body_collision:
		return
	
	# Reset touch flag for this dash
	player_touched_while_dashing = false
	
	# Only disable the StaticBody2D collision, leave Area2D collision_shape active
	static_body_collision.disabled = true
	
	print("DASH STARTED - Crate at ", global_position, " monitoring for collision")
	
	# Wait until player is no longer dashing
	while player_node and player_node.is_dashing:
		await get_tree().process_frame
	
	# Only check this specific crate instance
	if not is_destroyed and is_instance_valid(self):
		check_if_should_destroy()

func check_if_should_destroy():
	"""Check if THIS specific crate was touched during the dash"""
	print("=== CRATE CHECK at ", global_position, " ===")
	print("Player touched while dashing: ", player_touched_while_dashing)
	
	if player_touched_while_dashing:
		# Player touched THIS crate's Area2D while dashing - destroy only this crate
		print("DESTROYING CRATE at ", global_position, "!")
		destroy_crate()
	else:
		# Player didn't touch THIS crate - restore its StaticBody2D collision
		print("Restoring collision for crate at ", global_position)
		if is_instance_valid(static_body_collision):
			static_body_collision.disabled = false

func destroy_crate():
	"""Permanently destroy the crate with fade animation"""
	if is_destroyed:
		return
	
	is_destroyed = true
	
	# Fade out animation
	if sprite:
		var tween = create_tween()
		tween.tween_property(sprite, "modulate:a", 0.0, 0.3)
	
	# Remove the static body completely
	if static_body:
		static_body.queue_free()
	
	# Wait for fade to complete, then remove
	await get_tree().create_timer(0.3).timeout
	queue_free()
