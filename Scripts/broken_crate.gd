extends Area2D
@onready var collision_shape = $CollisionShape2D
@onready var animated_sprite = $AnimatedSprite2D
@onready var static_body = $StaticBody2D
@onready var static_body_collision = $StaticBody2D/CollisionShape2D

# Audio properties
@export_group("Audio")
@export var break_sound: AudioStream  # Sound to play when crate breaks

var player_node
var is_destroyed: bool = false
var player_touched_while_dashing: bool = false

# Audio system
var break_audio_player: AudioStreamPlayer2D

func _ready():
	await get_tree().process_frame
	player_node = get_tree().root.find_child("Player", true, false)
	
	# Connect to Area2D body_entered signal
	body_entered.connect(_on_body_entered)
	
	# Setup audio system
	_setup_audio_system()
	
	if player_node and player_node.has_signal("dash_started"):
		call_deferred("_connect_to_player")

# Setup the audio system
func _setup_audio_system():
	break_audio_player = AudioStreamPlayer2D.new()
	break_audio_player.name = "BreakAudioPlayer2D"
	break_audio_player.bus = "SFX"  # Use SFX bus like the main game
	add_child(break_audio_player)
	
	if break_sound:
		break_audio_player.stream = break_sound
	
	print("Crate break audio system initialized")

# Function to play break sound
func _play_break_sound():
	if break_audio_player and break_sound:
		break_audio_player.play()
		print("Playing crate break sound effect")

func _connect_to_player():
	if player_node and player_node.has_signal("dash_started"):
		player_node.dash_started.connect(_on_player_dash_started)

func _on_body_entered(body):
	"""Detect when player touches the Area2D while dashing"""
	if body == player_node and player_node.is_dashing and not is_destroyed:
		player_touched_while_dashing = true
		print("Player touched crate while dashing!")
		# Start destroy animation immediately
		if animated_sprite and animated_sprite.sprite_frames.has_animation("destroy"):
			animated_sprite.play("destroy")
		# Play break sound
		_play_break_sound()

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
	"""Permanently destroy the crate with destroy animation"""
	if is_destroyed:
		return
	
	is_destroyed = true
	
	# Remove the static body immediately
	if static_body:
		static_body.queue_free()
	
	# Animation already started in _on_body_entered, just wait for it to finish
	if animated_sprite:
		await animated_sprite.animation_finished
	
	# Remove the crate
	queue_free()
