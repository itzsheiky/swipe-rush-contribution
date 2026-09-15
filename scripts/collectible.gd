extends Area2D
class_name Collectible

## Reskin note: swap the "Visual" child's script for a coin, gem, or food
## item shape (see scripts/visuals/package_visual.gd). The pickup logic
## below never needs to change.

enum Rarity { NORMAL, BLUE, GREEN, RED }
enum Destination { LEFT, CENTER, RIGHT }

@export var value: int = 10
@export var rarity: Rarity = Rarity.NORMAL
@export var destination: Destination = Destination.CENTER
@onready var visual: Node2D = $Visual

var collected: bool = false

func _ready() -> void:
	if value <= 0:
		value = GameManager.config.collectible_value
	value = get_rarity_value(GameManager.config.collectible_value, rarity)
	visual.queue_redraw()

func get_destination_lane() -> int:
	var mapping := GameManager.config.destination_lane_indices
	if int(destination) < mapping.size():
		return mapping[int(destination)]
	return clampi(int(destination), 0, 2)

func get_destination_label() -> String:
	var labels := GameManager.config.destination_labels
	if int(destination) < labels.size():
		return labels[int(destination)]
	return ["L", "C", "R"][clampi(int(destination), 0, 2)]

static func get_rarity_value(base_value: int, package_rarity: Rarity) -> int:
	return base_value * (1 << int(package_rarity))

func _on_body_entered(body: Node2D) -> void:
	if collected or not body.has_method("collect_item") or GameManager.delivery_pending:
		return
	collected = true
	body.collect_item(value)
	GameManager.begin_delivery(self, body as Player)
	_spawn_pickup_feedback()
	_play_pickup_animation()

func _spawn_pickup_feedback() -> void:
	var popup := preload("res://scenes/score_popup.tscn").instantiate()
	get_tree().current_scene.add_child(popup)
	popup.global_position = global_position
	popup.show_value(value)

	var burst := preload("res://scenes/particle_burst.tscn").instantiate()
	get_tree().current_scene.add_child(burst)
	burst.global_position = global_position
	burst.burst(GameManager.config.package_tape_color)

func _play_pickup_animation() -> void:
	set_deferred("monitoring", false)
	var tween := create_tween()
	tween.tween_property(visual, "scale", Vector2(1.4, 1.4), 0.08)
	tween.tween_property(visual, "scale", Vector2(0.0, 0.0), 0.12)
	tween.tween_callback(queue_free)

