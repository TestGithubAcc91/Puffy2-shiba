extends Area2D

# Reference to the HIGH_JUMP_VELOCITY from the player script
const BALLOON_BOUNCE_VELOCITY = -350.0
# Optional: Add a cooldown to prevent multiple bounces
@export var bounce_cooldown: float = 0.5
@export var regenerate_time: float = 2.0
# Sound effects
@export var pop_sound: AudioStream
@export var regenerate_sound: AudioStream
var can_bounce: bool = true
var bounce_timer: Timer
var regenerate_timer: Timer
var audio_player: AudioStreamPlayer2D
# Optional: Visual feedback
@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D  # Adjust path as needed

func _ready():
	# Connect the body_entered signal
	body_entered.connect(_on_body_entered)
	
	# Setup audio player
	audio_player = AudioStreamPlayer2D.new()
	add_child(audio_player)
	
	# Setup cooldown timer
	bounce_timer = Timer.new()
	bounce_timer.wait_time = bounce_cooldown
	bounce_timer.one_shot = true
	bounce_timer.timeout.connect(_on_bounce_cooldown_timeout)
	add_child(bounce_timer)
	
	# Setup regenerate timer
	regenerate_timer = Timer.new()
	regenerate_timer.wait_time = regenerate_time
	regenerate_timer.one_shot = true
	regenerate_timer.timeout.connect(_on_regenerate_timeout)
	add_child(regenerate_timer)

func _on_body_entered(body):
	# Check if the entering body is the player and we can bounce
	if body.name == "Player" and can_bounce:
		bounce_player(body)

func bounce_player(player):
	# Apply the bounce velocity (same as high jump)
	player.velocity.y = BALLOON_BOUNCE_VELOCITY
	
	# Spawn the high jump air puff VFX
	if player.has_method("spawn_air_puffV"):
		player.spawn_air_puffV()
	
	# Play the whoosh sound (same as high jump)
	if player.has_method("_play_whoosh_sound"):
		player._play_whoosh_sound()
	
	# Start cooldown to prevent multiple bounces
	can_bounce = false
	bounce_timer.start()
	
	# Play pop animation and make balloon non-interactable
	pop_balloon()

func pop_balloon():
	# Play pop sound effect
	if pop_sound and audio_player:
		audio_player.stream = pop_sound
		audio_player.play()
	
	# Make balloon non-interactable but keep it visible for the animation
	set_deferred("monitoring", false)
	set_deferred("monitorable", false)
	
	# Play the pop animation
	if animated_sprite and animated_sprite.sprite_frames and animated_sprite.sprite_frames.has_animation("pop"):
		animated_sprite.play("pop")
		# Wait for pop animation to finish before hiding balloon
		if animated_sprite.animation_finished.is_connected(_on_pop_animation_finished):
			animated_sprite.animation_finished.disconnect(_on_pop_animation_finished)
		animated_sprite.animation_finished.connect(_on_pop_animation_finished)
	else:
		# If no pop animation, hide immediately and start regenerate timer
		modulate.a = 0.0
		regenerate_timer.start()

func _on_bounce_cooldown_timeout():
	can_bounce = true

func _on_pop_animation_finished():
	# Disconnect the signal to avoid multiple connections
	if animated_sprite.animation_finished.is_connected(_on_pop_animation_finished):
		animated_sprite.animation_finished.disconnect(_on_pop_animation_finished)
	
	# Now hide the balloon and start regenerate timer
	modulate.a = 0.0
	regenerate_timer.start()

func _on_regenerate_timeout():
	# Make balloon visible again before playing regenerate animation
	modulate.a = 1.0
	
	# Play regenerate sound effect
	if regenerate_sound and audio_player:
		audio_player.stream = regenerate_sound
		audio_player.play()
	
	# Play regenerate animation
	if animated_sprite and animated_sprite.sprite_frames and animated_sprite.sprite_frames.has_animation("regenerate"):
		animated_sprite.play("regenerate")
		# Wait for regenerate animation to finish before making balloon active
		if animated_sprite.animation_finished.is_connected(_on_regenerate_animation_finished):
			animated_sprite.animation_finished.disconnect(_on_regenerate_animation_finished)
		animated_sprite.animation_finished.connect(_on_regenerate_animation_finished)
	else:
		# If no regenerate animation, just restore immediately
		restore_balloon()

func _on_regenerate_animation_finished():
	# Disconnect the signal to avoid multiple connections
	if animated_sprite.animation_finished.is_connected(_on_regenerate_animation_finished):
		animated_sprite.animation_finished.disconnect(_on_regenerate_animation_finished)
	restore_balloon()

func restore_balloon():
	# Make balloon visible and interactable again using set_deferred
	modulate.a = 1.0  # Make visible
	set_deferred("monitoring", true)
	set_deferred("monitorable", true)
