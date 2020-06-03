tool
extends Node2D

var TEST = true

export var v = {}

# Declare member variables here. Examples:
# var a = 2
# var b = "text"


# Called when the node enters the scene tree for the first time.
func _ready():
	pass # Replace with function body.
	print(get_node("/root/Node2D/untitled/ScrollContainer/VBoxContainer/Label").get_meta("nestedshit")[3]["thisisdictkey1sfdgsf"])

# Called every frame. 'delta' is the elapsed time since the previous frame.
#func _process(delta):
#	pass
