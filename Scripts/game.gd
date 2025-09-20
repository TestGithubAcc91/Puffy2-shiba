# Game.gd
extends Node

@onready var level_select_menu = $LevelSelectMenu
@onready var black_curtain = $BlackCurtain
var current_level_scene = null

func _ready():
	level_select_menu.level_selected.connect(_on_level_selected)
	# Make sure the black curtain starts off-screen to the right
	if black_curtain:
		black_curtain.position.x = get_viewport().size.x

func _on_level_selected(level_number):
	# Start the curtain transition
	_start_curtain_transition(level_number)

func _start_curtain_transition(level_number):
	if not black_curtain:
		print("BlackCurtain node not found!")
		_load_level_directly(level_number)
		return
	
	# Create a tween to move the curtain
	var tween = create_tween()
	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_CUBIC)
	
	# Move curtain from right to cover the screen and beyond (moving left) - slower movement
	var viewport_width = get_viewport().size.x
	tween.tween_property(black_curtain, "position:x", -viewport_width, 2.5)
	
	# Wait 1.5 seconds after button press (while curtain is moving and covering screen)
	await get_tree().create_timer(1).timeout
	
	# Change the scene while view is covered by curtain
	_change_to_level(level_number)

func _change_to_level(level_number):
	# Remove current level if exists
	if current_level_scene:
		current_level_scene.queue_free()
	
	# Disable the level select menu's camera
	if level_select_menu.has_node("Camera2D"):
		level_select_menu.get_node("Camera2D").enabled = false
	
	# Hide menu
	level_select_menu.visible = false
	
	# Load the selected level
	match level_number:
		1:
			current_level_scene = preload("res://Scenes/level_1_holder.tscn").instantiate()
			add_child(current_level_scene)
		
		# Add more levels as needed

func _load_level_directly(level_number):
	# Fallback function if BlackCurtain is not available
	_change_to_level(level_number)

func return_to_menu():
	# Move curtain back off-screen when returning to menu
	if black_curtain:
		var tween = create_tween()
		tween.set_ease(Tween.EASE_IN)
		tween.set_trans(Tween.TRANS_CUBIC)
		tween.tween_property(black_curtain, "position:x", get_viewport().size.x, 0.8)
	
	if current_level_scene:
		current_level_scene.queue_free()
		current_level_scene = null
	
	# Re-enable the level select menu's camera
	if level_select_menu.has_node("Camera2D"):
		level_select_menu.get_node("Camera2D").enabled = true
	
	level_select_menu.visible = true
