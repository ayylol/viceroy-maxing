extends Label

const ViceroyController = preload("res://objects/viceroy_controller.gd")

@onready var player : ViceroyController = get_tree().get_nodes_in_group("player").front()

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta: float) -> void:
	text = ""
	text += "Horizontal speed: %.3f\n" % player._horizontal_velocity.length()
	text += "Vertical speed: %.3f\n" % player._vertical_velocity
