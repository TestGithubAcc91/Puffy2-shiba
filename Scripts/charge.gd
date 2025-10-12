extends Area2D

# Inspector variables
@export var vfx_scene: PackedScene  # VFX scene for pickup effect
@export var enable_regeneration: bool = false  # Toggle regeneration on/off (default: off)
@export var respawn_time: float = 5.0  # Time before charge regenerates
@export var fade_in_duration: float = 0.5  # Duration of fade-in effect
@export var pickup_sound: AudioStream  # Sound to play when collected
@export var respawn_sound: AudioStream  # Sound to play when respawning (optional)

# Node references
@onready var game_manager: Node = %GameManager
@onready var sprite: Node2D = $Sprite2D if has_node("Sprite2D") else ($AnimatedSprite2D if has_node("AnimatedSprite2D") else null)
@onready var collision: CollisionShape2D = $CollisionShape2D

# Runtime variables
var is_collected: bool = false
var respawn_timer: Timer
var audio_player: AudioStreamPlayer

func _ready():
	# Connect the body_entered signal
	body_entered.connect(_on_body_entered)
	
	# Setup respawn timer if regeneration is enabled
	if enable_regeneration:
		respawn_timer = Timer.new()
		respawn_timer.wait_time = respawn_time
		respawn_timer.one_shot = true
		respawn_timer.timeout.connect(_on_respawn_timer_timeout)
		add_child(respawn_timer)
	
	# Setup audio player
	audio_player = AudioStreamPlayer.new()
	audio_player.bus = "SFX"
	audio_player.volume_db = -5.0  # Lowered volume from 5.0 to -5.0
	add_child(audio_player)

func _on_body_entered(body: Node2D):
	# Skip if already collected and regeneration is enabled
	if is_collected and enable_regeneration:
		return
	
	# Add point to game manager
	game_manager.add_point()
	
	# Add parry stack to player if they have the method
	if body.has_method("add_parry_stack"):
		body.add_parry_stack()
	
	# Immediately hide the sprite and disable collision
	if sprite:
		sprite.visible = false
	if collision:
		collision.set_deferred("disabled", true)
	
	# Disable any particles if present
	var particles = get_node_or_null("GPUParticles2D")
	if particles:
		particles.emitting = false
	
	# Play pickup sound
	if pickup_sound:
		audio_player.stream = pickup_sound
		audio_player.play()
	
	# Spawn VFX if a scene is assigned
	if vfx_scene:
		spawn_vfx()
	
	# Handle regeneration or permanent removal
	if enable_regeneration:
		start_regeneration_cycle()
	else:
		# If regeneration is disabled, wait for sound to finish then remove
		if pickup_sound:
			await audio_player.finished
		queue_free()

func spawn_vfx():
	var vfx_instance = vfx_scene.instantiate()
	get_parent().add_child(vfx_instance)
	vfx_instance.global_position = global_position
	
	# Try to find an AnimationPlayer first
	var vfx_animation_player = vfx_instance.get_node_or_null("AnimationPlayer")
	if vfx_animation_player:
		vfx_animation_player.play()
		await vfx_animation_player.animation_finished
		vfx_instance.queue_free()
	else:
		# If no AnimationPlayer, try AnimatedSprite2D
		var vfx_animated_sprite = vfx_instance.get_node_or_null("AnimatedSprite2D")
		if vfx_animated_sprite:
			vfx_animated_sprite.play()
			await vfx_animated_sprite.animation_finished
			vfx_instance.queue_free()
		else:
			# Fallback: free after 1 second
			await get_tree().create_timer(1.0).timeout
			vfx_instance.queue_free()

func start_regeneration_cycle():
	is_collected = true
	
	# Hide the pickup (make it transparent)
	if sprite:
		sprite.modulate.a = 0.0
		sprite.visible = true  # Keep visible for fade-in later
		
		# If it's an AnimatedSprite2D, stop the animation
		if sprite is AnimatedSprite2D:
			sprite.stop()
	
	# Start respawn timer
	if respawn_timer:
		respawn_timer.start()

func _on_respawn_timer_timeout():
	# Play respawn sound if available
	if respawn_sound:
		audio_player.stream = respawn_sound
		audio_player.play()
	
	# Begin fade-in effect
	if sprite:
		sprite.visible = true  # Ensure sprite is visible
		sprite.modulate.a = 0.0  # Start transparent
		
		# If it's an AnimatedSprite2D, restart the animation
		if sprite is AnimatedSprite2D:
			sprite.play()
		
		# Create fade-in tween
		var tween = create_tween()
		tween.tween_property(sprite, "modulate:a", 1.0, fade_in_duration)
		
		# Wait for fade-in to complete before enabling collision
		tween.finished.connect(_on_fade_in_complete)
	else:
		# If no sprite, just re-enable immediately
		_on_fade_in_complete()
	
	# Re-enable particles if present
	var particles = get_node_or_null("GPUParticles2D")
	if particles:
		particles.emitting = true

func _on_fade_in_complete():
	# Re-enable collision and allow collection
	is_collected = false
	if collision:
		collision.disabled = false

# Optional: Method to toggle regeneration during runtime
func set_regeneration_enabled(enabled: bool):
	enable_regeneration = enabled
	
	# If disabling regeneration and timer exists, stop and remove it
	if not enabled and respawn_timer:
		respawn_timer.stop()
		respawn_timer.queue_free()
		respawn_timer = null
	
	# If enabling regeneration and timer doesn't exist, create it
	elif enabled and not respawn_timer:
		respawn_timer = Timer.new()
		respawn_timer.wait_time = respawn_time
		respawn_timer.one_shot = true
		respawn_timer.timeout.connect(_on_respawn_timer_timeout)
		add_child(respawn_timer)
