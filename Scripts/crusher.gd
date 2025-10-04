extends Node2D

@onready var area_2d = $Area2D
@onready var animated_sprite = $AnimatedSprite2D

var player = null
var crush_clone = null
var is_active = false

func _ready():
	area_2d.body_entered.connect(_on_body_entered)
	animated_sprite.play("inactive")

func _process(delta):
	if crush_clone and player:
		crush_clone.global_position = player.global_position
		crush_clone.global_position.y -= 15

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
			crush_clone.global_position.y -= 15
			crush_clone.z_index = 1
			crush_clone.modulate.a = 0.0
			
			# Fade in the clone
			var tween = create_tween()
			tween.tween_property(crush_clone, "modulate:a", 0.7, 0.5)
