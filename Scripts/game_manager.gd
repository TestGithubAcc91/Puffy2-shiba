extends Node

@export var coin_counter_label: Label

var score = 0 

func add_point():
	score += 1
	update_label()
	print("Score:" + str(score))

func update_label():
	if coin_counter_label:
		coin_counter_label.text = "x" + str(score)
