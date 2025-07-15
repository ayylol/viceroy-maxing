extends Node3D

const ViceroyController = preload("res://objects/viceroy_controller.gd")
@onready var player : ViceroyController = get_tree().get_nodes_in_group("player").front()

func _ready():
	player.transform.origin = transform.origin

func _physics_process(delta):
	if player.transform.origin.y < -25:
		player.transform.origin = transform.origin

