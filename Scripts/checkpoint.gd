extends Area2D

@export var checkpoint_id: int = 0

var is_active: bool = false
var animated_sprite: AnimatedSprite2D

# Sound effect
@export var activation_sound: AudioStream

# Audio player
var activation_audio_player: AudioStreamPlayer2D

signal checkpoint_activated(checkpoint_position: Vector2, checkpoint_id: int)

func _ready():
	body_entered.connect(_on_body_entered)
	
	# Setup audio system
	_setup_audio_system()
	
	# Get animated sprite reference
	if has_node("AnimatedSprite2D"):
		animated_sprite = get_node("AnimatedSprite2D")
		if animated_sprite:
			# Play default animation initially
			if animated_sprite.sprite_frames.has_animation("default"):
				animated_sprite.play("default")
			else:
				print("Warning: 'default' animation not found for checkpoint ", checkpoint_id)

func _setup_audio_system():
	# Activation sound player
	activation_audio_player = AudioStreamPlayer2D.new()
	activation_audio_player.name = "ActivationAudioPlayer2D"
	activation_audio_player.bus = "SFX"
	activation_audio_player.max_distance = 300.0
	activation_audio_player.attenuation = 0.3
	add_child(activation_audio_player)
	
	# Assign stream if available
	if activation_sound:
		activation_audio_player.stream = activation_sound

func _on_body_entered(body):
	if (body.name == "Player" or body is CharacterBody2D) and not is_active:
		activate_checkpoint()
		
		# Store checkpoint reference in the player
		if body.has_method("set_active_checkpoint"):
			body.set_active_checkpoint(global_position)

func activate_checkpoint():
	is_active = true
	
	# Play activation sound
	_play_activation_sound()
	
	# Change to active animation
	if animated_sprite:
		if animated_sprite.sprite_frames.has_animation("active"):
			animated_sprite.play("active")
		else:
			print("Warning: 'active' animation not found for checkpoint ", checkpoint_id)
	
	# Emit signal for potential game manager usage
	checkpoint_activated.emit(global_position, checkpoint_id)
	
	print("Checkpoint ", checkpoint_id, " activated at position: ", global_position)

func deactivate():
	is_active = false
	
	if animated_sprite:
		if animated_sprite.sprite_frames.has_animation("default"):
			animated_sprite.play("default")
		else:
			print("Warning: 'default' animation not found for checkpoint ", checkpoint_id)

func _play_activation_sound():
	if activation_audio_player and activation_sound:
		activation_audio_player.play()
