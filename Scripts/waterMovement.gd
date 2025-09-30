extends TileMapLayer

@export_group("Movement Settings")
@export var movement_speed: float = 1.0  # Oscillation speed
@export var movement_range: float = 10.0  # How far to move from center

var initial_position: Vector2
var time: float = 0.0

func _ready():
	# Store the initial position
	initial_position = position

func _process(delta):
	time += delta
	
	# Use sine wave for smooth back-and-forth movement
	# This automatically eases at the edges
	var oscillation = sin(time * movement_speed) * movement_range
	position.x = initial_position.x + oscillation
