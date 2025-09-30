extends Area2D

@export var checkpoint_id: int = 0
@export var activation_color: Color = Color.GREEN
@export var inactive_color: Color = Color.GRAY

var is_active: bool = false
var sprite: Sprite2D

signal checkpoint_activated(checkpoint_position: Vector2, checkpoint_id: int)

func _ready():
	body_entered.connect(_on_body_entered)
	
	# Get sprite reference for visual feedback
	if has_node("Sprite2D"):
		sprite = get_node("Sprite2D")
		if sprite:
			sprite.modulate = inactive_color

func _on_body_entered(body):
	if (body.name == "Player" or body is CharacterBody2D) and not is_active:
		activate_checkpoint()
		
		# Store checkpoint reference in the player
		if body.has_method("set_active_checkpoint"):
			body.set_active_checkpoint(global_position)

func activate_checkpoint():
	is_active = true
	
	# Visual feedback
	if sprite:
		sprite.modulate = activation_color
	
	# Emit signal for potential game manager usage
	checkpoint_activated.emit(global_position, checkpoint_id)
	
	print("Checkpoint ", checkpoint_id, " activated at position: ", global_position)

func deactivate():
	is_active = false
	if sprite:
		sprite.modulate = inactive_color
