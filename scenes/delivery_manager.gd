extends Node

@onready var sources = $DeliverySources
@onready var targets = $DeliveryTargets

@export var collectible_scene: PackedScene

var to_collect_quests = {}
var to_deliver_quests = []

func _ready():
	create_quest()
	print(to_collect_quests)

func create_quest():
	var source = sources.get_children().pick_random() 
	var target = targets.get_children().pick_random()

	var collectible = collectible_scene.instantiate()
	source.add_child(collectible)

	collectible.body_entered.connect(func(x): collected_collectible(collectible,x))

	to_collect_quests[collectible] = target

func collected_collectible(id: Node3D, body: Node3D):
	if body.is_in_group("player"):
		var target = to_collect_quests[id]
		to_deliver_quests.append(target)
		id.queue_free()
