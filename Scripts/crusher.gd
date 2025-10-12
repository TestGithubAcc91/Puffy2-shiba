extends Node2D

@onready var area_2d = $Area2D
@onready var animated_sprite = $AnimatedSprite2D

# Audio properties
@export_group("Audio")
@export var crush_sound: AudioStream  # Sound to play when clone appears/disappears
@export var prepare_sound: AudioStream  # Sound to play when crushPrepare2 starts

var player = null
var crush_clone = null
var crush_area = null
var is_active = false
var clone_timer = 0.0
var killzone_activated = false

# Audio system
var crush_audio_player: AudioStreamPlayer2D
var prepare_audio_player: AudioStreamPlayer2D
var prepare2_played = false  # Track if prepare2 sound has been played

# Tween management for cleanup
var active_tweens: Array = []
var crush_sequence_running = false

func _ready():
	area_2d.body_entered.connect(_on_body_entered)
	animated_sprite.play("inactive")
	
	# Setup audio system
	_setup_audio_system()

# Setup the audio system
func _setup_audio_system():
	crush_audio_player = AudioStreamPlayer2D.new()
	crush_audio_player.name = "CrushAudioPlayer2D"
	crush_audio_player.bus = "SFX"
	add_child(crush_audio_player)
	
	if crush_sound:
		crush_audio_player.stream = crush_sound
	
	prepare_audio_player = AudioStreamPlayer2D.new()
	prepare_audio_player.name = "PrepareAudioPlayer2D"
	prepare_audio_player.bus = "SFX"
	add_child(prepare_audio_player)
	
	if prepare_sound:
		prepare_audio_player.stream = prepare_sound
	
	print("Crusher audio system initialized")

# Function to play crush sound
func _play_crush_sound():
	if crush_audio_player and crush_sound:
		crush_audio_player.play()

# Function to play prepare sound
func _play_prepare_sound():
	if prepare_audio_player and prepare_sound:
		prepare_audio_player.play()

# Helper function to get offset based on rotation
func _get_offset() -> float:
	# Check if rotated 180 degrees (upside down)
	# Normalize rotation to 0-360 range
	var normalized_rotation = fmod(rotation_degrees, 360.0)
	if normalized_rotation < 0:
		normalized_rotation += 360.0
	
	# If rotation is approximately 180 degrees (with some tolerance), use offset of 10
	if abs(normalized_rotation - 180.0) < 10.0:
		return 2.0  # Upside down offset
	else:
		return -16.0  # Normal offset

func _process(delta):
	if crush_clone and player and not killzone_activated:
		var offset = _get_offset()
		
		if crush_area:
			crush_area.global_position = player.global_position
			crush_area.global_position.y += offset
		else:
			crush_clone.global_position = player.global_position
			crush_clone.global_position.y += offset
		
		clone_timer += delta
		
		# Play crusherPrepare2 at 1.5s (0.5s before damage at 2.0s)
		if clone_timer >= 1.5 and clone_timer < 1.9:
			if crush_clone.animation != "crushPrepare2":
				crush_clone.play("crushPrepare2")
				if not prepare2_played:
					_play_prepare_sound()
					prepare2_played = true
		
		# Play crush at 1.9s (0.1s before damage)
		elif clone_timer >= 1.9 and clone_timer < 2.0:
			if crush_clone.animation != "crush":
				crush_clone.play("crush")
				_play_crush_sound()
		
		if clone_timer >= 2.0:
			activate_killzone()
	elif crush_area and player and killzone_activated:
		var offset = _get_offset()
		crush_area.global_position = player.global_position
		crush_area.global_position.y += offset

# Kill all active tweens
func _kill_all_tweens():
	for tween in active_tweens:
		if tween and tween.is_valid():
			tween.kill()
	active_tweens.clear()

# Track a new tween
func _track_tween(tween: Tween) -> Tween:
	active_tweens.append(tween)
	return tween

func _on_body_entered(body):
	if body.is_in_group("player") or body.name == "Player":
		# Prevent multiple crush sequences from overlapping
		if crush_sequence_running:
			return
		
		player = body
		animated_sprite.play("active")
		is_active = true
		crush_sequence_running = true
		
		if not crush_clone:
			var offset = _get_offset()
			
			crush_clone = animated_sprite.duplicate()
			add_child(crush_clone)
			crush_clone.play("crushPrepare")
			crush_clone.global_position = player.global_position
			crush_clone.global_position.y += offset
			crush_clone.z_index = 1
			crush_clone.modulate.a = 0.0
			
			# Play sound when clone appears
			_play_crush_sound()
			
			var tween = create_tween()
			_track_tween(tween)
			tween.tween_property(crush_clone, "modulate:a", 0.7, 0.5)
			
			clone_timer = 0.0
			killzone_activated = false
			prepare2_played = false  # Reset the flag for next cycle

func activate_killzone():
	killzone_activated = true
	var clone_position = crush_clone.global_position
	
	# Load the killzone scene instead of creating Area2D manually
	var killzone_scene = load("res://Scenes/killzone.tscn")  # Adjust path if needed
	if killzone_scene == null:
		push_error("Could not load killzone.tscn!")
		_cleanup_crush_sequence()
		return
	
	crush_area = killzone_scene.instantiate()
	add_child(crush_area)
	crush_area.global_position = clone_position
	
	# Add collision shape to the killzone Area2D
	var collision_shape = CollisionShape2D.new()
	var shape = CircleShape2D.new()
	shape.radius = 50
	collision_shape.shape = shape
	crush_area.add_child(collision_shape)
	
	# Add the animated sprite clone as a child to show visual
	remove_child(crush_clone)
	crush_area.add_child(crush_clone)
	crush_clone.position = Vector2.ZERO
	
	# Set killzone properties
	crush_area.damage_amount = 25
	crush_area.ignore_iframes = false
	crush_area.unparryable = false
	
	var fade_tween = create_tween()
	_track_tween(fade_tween)
	fade_tween.tween_property(crush_clone, "modulate:a", 0.0, 0.5)
	await fade_tween.finished
	
	_cleanup_crush_sequence()

# Centralized cleanup function
func _cleanup_crush_sequence():
	# Kill all active tweens
	_kill_all_tweens()
	
	# Reset variables
	animated_sprite.play("inactive")
	
	if crush_area and is_instance_valid(crush_area):
		crush_area.queue_free()
		crush_area = null
	
	crush_clone = null
	player = null
	is_active = false
	crush_sequence_running = false
	killzone_activated = false
	clone_timer = 0.0

# Cleanup on exit
func _exit_tree():
	_kill_all_tweens()
