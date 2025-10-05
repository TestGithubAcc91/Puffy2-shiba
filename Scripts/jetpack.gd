extends Area2D

@export var jetpack_duration: float = 10.0  # How long the jetpack lasts
@export var pickup_sound: AudioStream
@export var can_respawn: bool = false
@export var respawn_time: float = 30.0

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
	if pickup_sound:
		audio_player.stream = pickup_sound
	add_child(audio_player)
	
	# Setup respawn timer if needed
	if can_respawn:
		respawn_timer = Timer.new()
		respawn_timer.wait_time = respawn_time
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
		sprite.visible = false
	if collision:
		collision.set_deferred("disabled", true)
	if particles:
		particles.emitting = false
	
	# Handle respawn or deletion
	if can_respawn and respawn_timer:
		respawn_timer.start()
	else:
		# Wait for sound to finish then delete
		await get_tree().create_timer(2.0).timeout
		queue_free()

func _on_respawn_timer_timeout():
	is_collected = false
	
	# Show pickup visuals again
	if sprite:
		sprite.visible = true
	if collision:
		collision.disabled = false
	if particles:
		particles.emitting = true
