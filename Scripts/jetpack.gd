extends Area2D

@export var jetpack_duration: float = 10.0  # How long the jetpack lasts
@export var pickup_sound: AudioStream
@export var fade_in_duration: float = 0.5  # How long the fade-in takes

@onready var sprite: Sprite2D = $Sprite2D
@onready var collision: CollisionShape2D = $CollisionShape2D
@onready var particles: GPUParticles2D = $GPUParticles2D if has_node("GPUParticles2D") else null

var audio_player: AudioStreamPlayer
var is_collected: bool = false
var respawn_timer: Timer

func _ready():
	body_entered.connect(_on_body_entered)
	
	# Setup audio
	audio_player = AudioStreamPlayer.new()
	audio_player.bus = "SFX"
	audio_player.volume_db = 5.0  # Make pickup sound louder
	if pickup_sound:
		audio_player.stream = pickup_sound
	add_child(audio_player)
	
	# Setup respawn timer
	respawn_timer = Timer.new()
	respawn_timer.wait_time = 5.0
	respawn_timer.one_shot = true
	respawn_timer.timeout.connect(_on_respawn_timer_timeout)
	add_child(respawn_timer)

func _on_body_entered(body: Node2D):
	if is_collected:
		return
	
	if body.name == "Player" and body.has_method("activate_jetpack"):
		collect_jetpack(body)

func collect_jetpack(player: Node2D):
	is_collected = true
	
	# Play pickup sound
	if audio_player and pickup_sound:
		audio_player.play()
	
	# Activate jetpack on player
	player.activate_jetpack(jetpack_duration)
	
	# Hide pickup visuals
	if sprite:
		sprite.modulate.a = 0.0  # Set to transparent instead of hiding
		sprite.visible = true  # Keep visible for fade-in
	if collision:
		collision.set_deferred("disabled", true)
	if particles:
		particles.emitting = false
	
	# Start respawn timer
	respawn_timer.start()

func _on_respawn_timer_timeout():
	# Show pickup visuals again with fade-in
	if sprite:
		sprite.modulate.a = 0.0  # Start transparent
		
		# Create fade-in tween
		var tween = create_tween()
		tween.tween_property(sprite, "modulate:a", 1.0, fade_in_duration)
		
		# Wait for fade-in to complete before enabling collision and allowing collection
		tween.finished.connect(_on_fade_in_complete)
	
	if particles:
		particles.emitting = true

func _on_fade_in_complete():
	# Only re-enable collision and allow collection after fade-in is done
	is_collected = false
	if collision:
		collision.disabled = false
