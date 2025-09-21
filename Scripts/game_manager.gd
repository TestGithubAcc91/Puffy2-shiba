extends Node
@export var coin_counter_label: Label
var score = 0 

# NEW: Signal to notify when a coin/glit is collected
signal coin_collected

func add_point():
	score += 1
	update_label()
	print("Score:" + str(score))
	
	# NEW: Emit signal when a point is added
	coin_collected.emit()

func update_label():
	if coin_counter_label:
		coin_counter_label.text = "x" + str(score)
