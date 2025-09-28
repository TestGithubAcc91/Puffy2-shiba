extends Area2D
@export var heal_amount: int = 25  # Amount of health to restore

# Audio properties
@export_group("Audio")
@export var pickup_sound: AudioStream  # Sound to play when picked up

@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D

# Audio system
var pickup_audio_player: AudioStreamPlayer2D

func _ready():
	# Setup audio system
	_setup_audio_system()

# Setup the audio system
func _setup_audio_system():
	pickup_audio_player = AudioStreamPlayer2D.new()
	pickup_audio_player.name = "PickupAudioPlayer2D"
	pickup_audio_player.bus = "SFX"  # Use SFX bus like the main game
	
	# Configure sound range and attenuation
	pickup_audio_player.max_distance = 300.0  # Sound becomes inaudible beyond this distance
	pickup_audio_player.attenuation = 1.0  # How quickly sound fades (higher = faster fade)
	
	add_child(pickup_audio_player)
	
	if pickup_sound:
		pickup_audio_player.stream = pickup_sound
	
	print("Health pickup audio system initialized")

# Function to play pickup sound
func _play_pickup_sound():
	if pickup_audio_player and pickup_sound:
		pickup_audio_player.play()
		print("Playing health pickup sound effect")

func _on_body_entered(body: Node2D):
	# Check if the body has a health component
	var health_component = body.get_node_or_null("HealthScript")
	if health_component:
		# Only heal if player isn't already at max health
		if health_component.current_health < health_component.max_health:
			health_component.heal(heal_amount)
			print("Player healed for ", heal_amount, " HP. Current health: ", health_component.current_health)
			
			# Play collect animation for 0.2 seconds
			animated_sprite.play("collect")
			
			# Play pickup sound
			_play_pickup_sound()
			
			# Wait for 0.2 seconds then hide the sprite
			await get_tree().create_timer(0.2).timeout
			animated_sprite.visible = false
			
			# Wait for audio to finish before deleting
			if pickup_audio_player.playing:
				await pickup_audio_player.finished
			
			queue_free()
		else:
			print("Player already at max health, heart not collected")
	else:
		print("Body doesn't have a Health component")
