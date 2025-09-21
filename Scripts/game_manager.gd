extends Node

@export var coin_counter_label: Label
var score = 0 

# Signal to notify when a coin/glit is collected
signal coin_collected

func _ready():
	# Initialize the label on start
	update_label()
	
	# Debug: Print if label is found
	if coin_counter_label:
		print("Coin counter label found and initialized")
	else:
		print("Warning: coin_counter_label not assigned!")
		# Try to find the label automatically if not assigned
		_try_find_label()

func _try_find_label():
	# Look for the specific GlitNumber label path
	var possible_paths = [
		"GlitNumber",  # If this script is on the GlitCounter node
		"../GlitNumber",  # If this script is on a child of GlitCounter
		"GlitCounter/GlitNumber",  # If this script is on the UI node
		"../GlitCounter/GlitNumber",  # If this script is on a sibling of GlitCounter
		"../../UI/GlitCounter/GlitNumber",  # If this script is deeper in hierarchy
		"UI/GlitCounter/GlitNumber"  # If this script is on the root level scene
	]
	
	for path in possible_paths:
		if has_node(path):
			coin_counter_label = get_node(path)
			print("Auto-found glit counter label at: " + path)
			update_label()
			break
	
	# If still not found, search the entire scene tree
	if not coin_counter_label:
		var scene_root = get_tree().current_scene
		if scene_root:
			var labels = scene_root.find_children("GlitNumber", "Label", true, false)
			if labels.size() > 0:
				coin_counter_label = labels[0]
				print("Auto-found GlitNumber label in scene tree")
				update_label()
			else:
				# Fallback: look for any label with "glit" in the name
				labels = scene_root.find_children("*", "Label", true, false)
				for label in labels:
					if "glit" in label.name.to_lower():
						coin_counter_label = label
						print("Auto-found glit label: " + label.name)
						update_label()
						break

func add_point():
	score += 1
	update_label()
	print("Score: " + str(score))
	
	# Emit signal when a point is added
	coin_collected.emit()

func update_label():
	if coin_counter_label:
		coin_counter_label.text = "x" + str(score)
		print("Label updated to: " + coin_counter_label.text)
	else:
		print("Cannot update label - coin_counter_label is null")

# Method to reset score (useful for level restart)
func reset_score():
	score = 0
	update_label()

# Method to get current score
func get_score() -> int:
	return score
