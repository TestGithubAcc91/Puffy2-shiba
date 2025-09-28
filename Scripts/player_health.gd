extends Node
class_name Health

signal health_changed(new_health: int)
signal died
signal iframe_started
signal iframe_ended
signal damage_taken  # Signal emitted when player actually takes damage
signal health_decreased  # NEW: Signal emitted only when health actually decreases

@export var max_health: int = 100
@export var current_health: int = 100
@export var iframe_duration: float = 1.0
@export var flicker_interval: float = 0.1

var is_invulnerable: bool = false
var iframe_timer: Timer
var flicker_timer: Timer
var is_flickering: bool = false

# Reference to the animated sprite for flickering
var animated_sprite: AnimatedSprite2D

# NEW: Audio system for damage sounds
var damage_audio_player: AudioStreamPlayer
@export_group("Audio")
@export var damage_sound: AudioStream

# NEW: Track if player should remain invisible (for lifesaver compatibility)
var force_invisible: bool = false

func _ready():
	current_health = max_health
	
	# Get reference to the animated sprite from parent
	var parent = get_parent()
	if parent.has_node("MainSprite"):
		animated_sprite = parent.get_node("MainSprite")
	
	# NEW: Setup audio system
	_setup_audio_system()
	
	# Create iframe timer
	iframe_timer = Timer.new()
	iframe_timer.wait_time = iframe_duration
	iframe_timer.one_shot = true
	iframe_timer.timeout.connect(_on_iframe_timeout)
	add_child(iframe_timer)
	
	# Create flicker timer
	flicker_timer = Timer.new()
	flicker_timer.wait_time = flicker_interval
	flicker_timer.timeout.connect(_on_flicker_timeout)
	add_child(flicker_timer)

# NEW: Setup audio system (following the same pattern as Player.gd)
func _setup_audio_system():
	# Create dedicated AudioStreamPlayer for damage sounds
	damage_audio_player = AudioStreamPlayer.new()
	damage_audio_player.name = "DamageAudioPlayer"
	damage_audio_player.bus = "SFX"
	if damage_sound:
		damage_audio_player.stream = damage_sound
	add_child(damage_audio_player)
	
	print("Health audio system setup complete - Damage: ", damage_sound != null)

# NEW: Play damage sound effect
func _play_damage_sound():
	if damage_audio_player and damage_sound:
		damage_audio_player.play()
		print("Playing damage sound")

# NEW: Set whether the player should be forced to remain invisible
func set_force_invisible(invisible: bool):
	force_invisible = invisible
	if force_invisible and animated_sprite:
		animated_sprite.modulate.a = 0.0
	elif not force_invisible:
		# When no longer forced invisible, reset transparency if not flickering
		_reset_sprite_transparency()

# NEW: Centralized function to reset sprite transparency
func _reset_sprite_transparency():
	if animated_sprite and not force_invisible:
		animated_sprite.modulate.a = 1.0
		print("Sprite transparency reset to full opacity")

func take_damage(amount: int, ignore_iframes: bool = false):
	# Store health before damage
	var health_before = current_health
	
	# NEW: Check if this is an unparryable attack while player is parrying
	var player = get_parent()
	var is_unparryable_vs_parry = false
	
	if player and "is_parrying" in player and "last_attack_was_unparryable" in player:
		is_unparryable_vs_parry = player.is_parrying and player.last_attack_was_unparryable
	
	# Check if damage should be blocked by existing iframes
	if is_invulnerable and not ignore_iframes:
		# SPECIAL CASE: If it's an unparryable attack vs parrying player, and the invulnerability
		# is from parrying (not from existing i-frames), allow the damage through
		if is_unparryable_vs_parry and player and "was_invulnerable_before_parry" in player:
			if not player.was_invulnerable_before_parry:
				print("Unparryable attack vs parry - allowing damage through parry invulnerability!")
				# Continue with damage processing
			else:
				print("Player is invulnerable from existing i-frames, damage blocked!")
				return
		else:
			print("Player is invulnerable, damage blocked!")
			return
	
	if ignore_iframes and is_invulnerable:
		print("Damage ignoring i-frames!")
	
	print("Taking damage: ", amount, " | Health before: ", current_health)
	current_health = max(0, current_health - amount)
	print("Health after damage: ", current_health)
	health_changed.emit(current_health)
	
	# NEW: Only emit health_decreased if health actually went down
	if current_health < health_before:
		health_decreased.emit()
	
	# Always emit damage_taken when damage function is called
	damage_taken.emit()
	
	# NEW: Play damage sound effect when damage is actually taken
	_play_damage_sound()
	
	# Stop any current flickering before starting new iframes
	if is_flickering:
		is_flickering = false
		flicker_timer.stop()
		_reset_sprite_transparency()
	
	# ALWAYS grant invulnerability and start visual iframes after taking damage
	# This ensures the player gets iframes even when parrying unparryable attacks
	is_invulnerable = true
	iframe_timer.start()
	
	# Start flickering effect (but only if not forced invisible)
	if not force_invisible:
		is_flickering = true
		flicker_timer.start()
	
	iframe_started.emit()
	print("I-frames activated for ", iframe_duration, " seconds")
	
	if current_health <= 0:
		print("Player died!")
		died.emit()

func _on_iframe_timeout():
	is_invulnerable = false
	is_flickering = false
	flicker_timer.stop()
	
	# Always reset sprite transparency when iframes end (unless forced invisible)
	_reset_sprite_transparency()
	
	iframe_ended.emit()  # Signal that iframes have ended
	print("I-frames ended, player can take damage again")

func _on_flicker_timeout():
	# Only flicker if we're supposed to be flickering AND not forced invisible
	if is_flickering and animated_sprite and not force_invisible:
		if animated_sprite.modulate.a > 0.5:
			animated_sprite.modulate.a = 0.3
		else:
			animated_sprite.modulate.a = 1.0
		
		flicker_timer.start()

func heal(amount: int):
	current_health = min(max_health, current_health + amount)
	health_changed.emit(current_health)

func get_health_percentage() -> float:
	return float(current_health) / float(max_health)

func is_alive() -> bool:
	return current_health > 0

# NEW: Public method to force reset transparency (can be called from Player script)
func force_reset_transparency():
	if not force_invisible:
		is_flickering = false
		if flicker_timer:
			flicker_timer.stop()
		_reset_sprite_transparency()
		print("Transparency forcibly reset")
