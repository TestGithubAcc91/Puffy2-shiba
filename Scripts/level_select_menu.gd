# LevelSelectMenu.gd (attach this to your LevelSelectMenu node)
extends Node2D  # or whatever your LevelSelectMenu actually is

signal level_selected(level_number)

@export var curtains: Node2D
@export var tiles: Node2D
@export var label1: Label
@export var label2: Label
@export var label3: Label
@export var label4: Label
@export var curtain_speed: float = 50.0
@export var curtain_height_range: float = 100.0
@export var tile_rotation_speed: float = 30.0
@export var tile_orbit_radius: float = 150.0
@export var label_speed: float = 40.0
@export var label_height_range: float = 80.0

@onready var forest_background = $ForestBackground
@onready var beach_background = $BeachBackground
@onready var tutorial_background = $TutorialBackground
var tween: Tween

# Animation variables
var curtain_time: float = 0.0
var tile_time: float = 0.0
var label_time: float = 0.0

func _ready():
	# Setup all backgrounds - start invisible but visible
	forest_background.modulate.a = 0.0
	forest_background.visible = true
	
	beach_background.modulate.a = 0.0
	beach_background.visible = true
	
	tutorial_background.modulate.a = 0.0
	tutorial_background.visible = true
	
	# Connect Level 1 button signals
	$Level1Button.pressed.connect(_on_level_1_button_pressed)
	$Level1Button.mouse_entered.connect(_on_level_1_button_hover_start)
	$Level1Button.mouse_exited.connect(_on_level_1_button_hover_end)
	
	# Connect Level 2 button signals
	$Level2Button.pressed.connect(_on_level_2_button_pressed)
	$Level2Button.mouse_entered.connect(_on_level_2_button_hover_start)
	$Level2Button.mouse_exited.connect(_on_level_2_button_hover_end)
	
	# Connect Tutorial button signals
	$TutorialButton.pressed.connect(_on_tutorial_button_pressed)
	$TutorialButton.mouse_entered.connect(_on_tutorial_button_hover_start)
	$TutorialButton.mouse_exited.connect(_on_tutorial_button_hover_end)
	
	# Connect Level 3 button signals
	$Level3Button.pressed.connect(_on_level_3_button_pressed)
	$Level3Button.mouse_entered.connect(_on_level_3_button_hover_start)
	$Level3Button.mouse_exited.connect(_on_level_3_button_hover_end)
	
	# You can also connect additional level buttons here:
	# $Level4Button.pressed.connect(_on_level_4_button_pressed)

func _process(delta):
	_animate_curtains(delta)
	_animate_tiles(delta)
	_animate_labels(delta)

# Helper function to fade out all backgrounds
func _fade_out_all_backgrounds():
	if tween:
		tween.kill()
	
	tween = create_tween()
	tween.parallel().tween_property(forest_background, "modulate:a", 0.0, 0.3)
	tween.parallel().tween_property(beach_background, "modulate:a", 0.0, 0.3)
	tween.parallel().tween_property(tutorial_background, "modulate:a", 0.0, 0.3)

# Helper function to fade in a specific background
func _fade_in_background(background_node):
	if tween:
		tween.kill()
	
	tween = create_tween()
	# First fade out all backgrounds
	tween.parallel().tween_property(forest_background, "modulate:a", 0.0, 0.3)
	tween.parallel().tween_property(beach_background, "modulate:a", 0.0, 0.3)
	tween.parallel().tween_property(tutorial_background, "modulate:a", 0.0, 0.3)
	# Then fade in the target background
	tween.parallel().tween_property(background_node, "modulate:a", 1.0, 0.3)

# Level 1 button handlers (Forest theme)
func _on_level_1_button_pressed():
	level_selected.emit(1)

func _on_level_1_button_hover_start():
	_fade_in_background(forest_background)

func _on_level_1_button_hover_end():
	_fade_out_all_backgrounds()

# Level 2 button handlers (Beach theme)
func _on_level_2_button_pressed():
	level_selected.emit(2)

func _on_level_2_button_hover_start():
	_fade_in_background(beach_background)

func _on_level_2_button_hover_end():
	_fade_out_all_backgrounds()

# Tutorial button handlers
func _on_tutorial_button_pressed():
	# You might want to emit a different signal or handle tutorial differently
	# For example: tutorial_selected.emit() or change_scene("tutorial_scene")
	level_selected.emit(0)  # Using 0 for tutorial, or create a separate signal

func _on_tutorial_button_hover_start():
	_fade_in_background(tutorial_background)

func _on_tutorial_button_hover_end():
	_fade_out_all_backgrounds()

# Level 3 button handlers
func _on_level_3_button_pressed():
	level_selected.emit(3)

func _on_level_3_button_hover_start():
	_fade_in_background(forest_background)

func _on_level_3_button_hover_end():
	_fade_out_all_backgrounds()

# Animation functions
func _animate_curtains(delta):
	if not curtains:
		return
	
	curtain_time += delta * curtain_speed / 100.0
	
	# Use sine wave with smooth slowdown at edges
	var sine_value = sin(curtain_time)
	# Apply smoothstep for natural easing that slows at edges
	var abs_sine = abs(sine_value)
	var smoothed = smoothstep(0.0, 1.0, abs_sine)
	var eased_value = smoothed * sign(sine_value)
	
	# Calculate offset from original position
	var offset_y = eased_value * curtain_height_range
	
	# Animate all Sprite2D children under curtains - add to their original positions
	for child in curtains.get_children():
		if child is Sprite2D:
			# Store original position if not already stored
			if not child.has_meta("original_pos"):
				child.set_meta("original_pos", child.position)
			
			var original_pos = child.get_meta("original_pos")
			child.position.y = original_pos.y + offset_y

func _animate_tiles(delta):
	if not tiles:
		return
	
	tile_time += delta * deg_to_rad(tile_rotation_speed)
	
	# Circular motion
	var offset_x = cos(tile_time) * tile_orbit_radius
	var offset_y = sin(tile_time) * tile_orbit_radius
	
	# Animate all Sprite2D children under tiles - add to their original positions
	for child in tiles.get_children():
		if child is Sprite2D:
			# Store original position if not already stored
			if not child.has_meta("original_pos"):
				child.set_meta("original_pos", child.position)
			
			var original_pos = child.get_meta("original_pos")
			child.position = original_pos + Vector2(offset_x, offset_y)

func _animate_labels(delta):
	label_time += delta * label_speed / 100.0
	
	# Labels 1 and 3: Start moving upward (no phase offset)
	var sine_value_13 = sin(label_time)
	var abs_sine_13 = abs(sine_value_13)
	var smoothed_13 = smoothstep(0.0, 1.0, abs_sine_13)
	var eased_value_13 = smoothed_13 * sign(sine_value_13)
	var offset_y_13 = eased_value_13 * label_height_range
	
	# Labels 2 and 4: Start moving downward (π phase offset)
	var sine_value_24 = sin(label_time + PI)
	var abs_sine_24 = abs(sine_value_24)
	var smoothed_24 = smoothstep(0.0, 1.0, abs_sine_24)
	var eased_value_24 = smoothed_24 * sign(sine_value_24)
	var offset_y_24 = eased_value_24 * label_height_range
	
	# Animate labels 1 and 3 (upward first)
	for label in [label1, label3]:
		if label:
			if not label.has_meta("original_pos"):
				label.set_meta("original_pos", label.position)
			
			var original_pos = label.get_meta("original_pos")
			label.position.y = original_pos.y + offset_y_13
	
	# Animate labels 2 and 4 (downward first)
	for label in [label2, label4]:
		if label:
			if not label.has_meta("original_pos"):
				label.set_meta("original_pos", label.position)
			
			var original_pos = label.get_meta("original_pos")
			label.position.y = original_pos.y + offset_y_24
