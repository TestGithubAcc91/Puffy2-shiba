extends Node2D

@export var camera: Camera2D
@export var parallax_speed: float = 1.0  # How fast the background moves relative to camera
@export var repeat_width: float = 1024.0  # Width of the background texture for seamless repeating

var initial_position: Vector2
var last_camera_x: float = 0.0

func _ready():
	if not camera:
		print("Warning: No camera assigned to parallax background!")
		return
	
	initial_position = global_position
	if camera:
		last_camera_x = camera.global_position.x

func _process(_delta):
	if not camera:
		return
	
	# Calculate camera position on X axis
	var camera_x = camera.global_position.x
	
	# Calculate parallax offset from camera movement
	var camera_offset = camera_x - last_camera_x
	var parallax_movement = camera_offset * parallax_speed
	
	# Move background and keep it centered around camera to prevent culling
	global_position.x += parallax_movement
	
	# Keep background centered around camera view to prevent disappearing
	var distance_from_camera = global_position.x - camera_x
	if abs(distance_from_camera) > 2000:  # Adjust threshold as needed
		global_position.x = camera_x + sign(distance_from_camera) * 2000
	
	# Handle seamless repeating (optional - remove if not needed)
	if repeat_width > 0:
		var parallax_offset = camera_x * parallax_speed
		if parallax_offset > repeat_width:
			var repeats = floor(parallax_offset / repeat_width)
			initial_position.x += repeats * repeat_width
		elif parallax_offset < -repeat_width:
			var repeats = floor(-parallax_offset / repeat_width)
			initial_position.x -= repeats * repeat_width
	
	# Update last camera position (not needed but kept for potential future use)
	last_camera_x = camera_x
