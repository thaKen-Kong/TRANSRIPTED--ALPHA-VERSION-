extends Node2D

@onready var player_ref: Node2D = get_tree().get_first_node_in_group("player")
@onready var label: Label = $CanvasLayer/Label

var base_name := "[E] TO "
var active_areas: Array[InteractionArea] = []
var can_interact := true


func register_area(area: InteractionArea) -> void:
	if area and not active_areas.has(area):
		active_areas.append(area)


func unregister_area(area: InteractionArea) -> void:
	if area and active_areas.has(area):
		active_areas.erase(area)


func _process(_delta: float) -> void:
	if not can_interact or active_areas.is_empty():
		label.hide()
		return

	# Remove invalid areas (freed nodes)
	active_areas = active_areas.filter(func(a): return is_instance_valid(a))

	if active_areas.is_empty():
		label.hide()
		return

	active_areas.sort_custom(_sort_areas)

	var closest := active_areas[0]
	label.text = base_name + closest.action_name
	label.show()


func _sort_areas(a: InteractionArea, b: InteractionArea) -> bool:
	if not player_ref:
		return false
	return (
		player_ref.global_position.distance_squared_to(a.global_position)
		< player_ref.global_position.distance_squared_to(b.global_position)
	)


func _input(event: InputEvent) -> void:
	if not can_interact:
		return

	if event.is_action_pressed("e") and not active_areas.is_empty():
		var area := active_areas[0]
		if not is_instance_valid(area):
			return

		can_interact = false
		label.hide()

		await area.interact.call()

		can_interact = true
