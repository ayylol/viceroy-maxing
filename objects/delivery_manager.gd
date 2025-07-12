extends Node

@onready var sources := $DeliverySources
@onready var targets := $DeliveryTargets

@export var collectible_scene: PackedScene

var valid_sources := []
var valid_targets := []

var quests := {}

var quests_num = 0

func _ready():
	valid_sources = sources.get_children()
	valid_targets = targets.get_children()
	create_quest()


func create_quest():
	if valid_sources.is_empty() or valid_targets.is_empty():
		return
	var source = valid_sources.pick_random() 
	var target = valid_targets.pick_random()
	valid_sources.erase(source)
	valid_targets.erase(target)

	var collectible = prepare_collectible("source", quests_num)
	source.add_child(collectible)

	quests[quests_num] = [source, target]
	quests_num+=1

func prepare_collectible(type: String, quest_id: int):
	var collectible = collectible_scene.instantiate()
	collectible.add_to_group(type)
	collectible.body_entered.connect(
		func(x): collected_collectible(quest_id, collectible ,x)
		)
	collectible.get_child(2).text = str(quest_id)+" "+type
	return collectible

func collected_collectible(quest_id: int, this: Node3D, other: Node3D):
	if other.is_in_group("player"):
		if this.is_in_group("source"):
			var target = quests[quest_id][1]
			var collectible = prepare_collectible("target", quest_id)
			target.add_child(collectible)
		else:
			var quest = quests[quest_id]
			valid_sources.append(quest[0])
			valid_targets.append(quest[1])
		this.queue_free()
