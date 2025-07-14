extends Label

const ViceroyController = preload("res://objects/viceroy_controller.gd")

@onready var player : ViceroyController = get_tree().get_nodes_in_group("player").front()

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta: float) -> void:
	text = ""
	text += "Stamina: %.2f / %.2f\n" % [player.stamina, player.max_stamina] 
	text += "Horizontal speed: %.2f\n" % player._horizontal_velocity.length()
	text += "Vertical speed: %.2f\n" % absf(player._vertical_velocity)
