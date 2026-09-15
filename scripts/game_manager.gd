extends Node

## Autoload singleton (see project.godot [autoload]).
## Holds all run-time game state and fires signals the UI/scenes listen to.
## This is also where ad-SDK / analytics calls should eventually be plugged in
## — see _log_analytics_event() at the bottom.

signal score_changed(new_score: int)
signal combo_changed(multiplier: float)
signal distance_changed(distance: float, total: float)
signal game_started
signal game_won
signal game_lost
signal obstacle_hit
signal delivery_started(label: String)
signal delivery_success(bonus: int, combo: int)
signal delivery_failed

var config: GameConfig = preload("res://config/default_config.tres")

const SAVE_PATH := "user://rooftop_rush_save.dat"

var score: int = 0
var best_score: int = 0
var combo_multiplier: float = 1.0
var combo_timer: float = 0.0
var distance_traveled: float = 0.0
var survival_seconds: float = 0.0
var current_speed: float = 0.0
var is_game_active: bool = false
var last_checkpoint: float = 0.0
var active_delivery: Collectible = null
var delivery_pending: bool = false
var active_delivery_lane: int = -1
var active_delivery_player: Player = null
var delivery_combo: int = 0
var delivery_last_lane: int = -1

func _ready() -> void:
	_load_best_score()

func _load_best_score() -> void:
	if FileAccess.file_exists(SAVE_PATH):
		var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
		if file:
			best_score = file.get_32()
			file.close()

func _save_best_score() -> void:
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file:
		file.store_32(best_score)
		file.close()

func _check_best_score() -> void:
	if score > best_score:
		best_score = score
		_save_best_score()

func _process(delta: float) -> void:
	if not is_game_active:
		return
	if combo_multiplier > 1.0:
		combo_timer -= delta
		if combo_timer <= 0.0:
			combo_multiplier = 1.0
			combo_changed.emit(combo_multiplier)
	if delivery_pending and is_instance_valid(active_delivery_player):
		var current_lane := active_delivery_player.current_lane
		if current_lane != delivery_last_lane:
			_resolve_delivery(current_lane)

func start_game() -> void:
	score = 0
	combo_multiplier = 1.0
	combo_timer = 0.0
	distance_traveled = 0.0
	survival_seconds = 0.0
	last_checkpoint = 0.0
	active_delivery = null
	delivery_pending = false
	active_delivery_lane = -1
	active_delivery_player = null
	delivery_combo = 0
	delivery_last_lane = -1
	current_speed = config.forward_speed
	is_game_active = true
	score_changed.emit(score)
	combo_changed.emit(combo_multiplier)
	distance_changed.emit(distance_traveled, config.level_length)
	game_started.emit()
	_log_analytics_event("game_start", {})

func begin_delivery(package: Collectible, player: Player) -> void:
	if delivery_pending:
		return
	active_delivery = package
	delivery_pending = true
	active_delivery_lane = package.get_destination_lane()
	active_delivery_player = player
	delivery_last_lane = player.current_lane
	delivery_started.emit(package.get_destination_label())

func _resolve_delivery(current_lane: int) -> void:
	if not delivery_pending:
		return
	delivery_last_lane = current_lane
	var player_position := active_delivery_player.global_position
	if current_lane == active_delivery_lane:
		delivery_combo += 1
		add_score(config.delivery_bonus)
		delivery_success.emit(config.delivery_bonus, delivery_combo)
		_show_delivery_feedback("DELIVERED! +%d  COMBO x%d" % [config.delivery_bonus, delivery_combo], player_position)
	else:
		delivery_combo = 0
		delivery_failed.emit()
		_show_delivery_feedback("WRONG DESTINATION  COMBO LOST", player_position)
	active_delivery = null
	delivery_pending = false
	active_delivery_lane = -1
	active_delivery_player = null
	delivery_last_lane = -1

func _show_delivery_feedback(message: String, position: Vector2) -> void:
	var popup := preload("res://scenes/score_popup.tscn").instantiate()
	get_tree().current_scene.add_child(popup)
	popup.global_position = position
	popup.show_message(message)

func add_score(base_value: int) -> void:
	if not is_game_active:
		return
	var earned := int(base_value * combo_multiplier)
	score += earned
	combo_multiplier = min(combo_multiplier + config.combo_multiplier_step, config.combo_max_multiplier)
	combo_timer = config.combo_reset_time
	score_changed.emit(score)
	combo_changed.emit(combo_multiplier)

func advance(delta: float) -> void:
	if not is_game_active:
		return
	survival_seconds += delta
	var speed_difficulty: float = min(get_difficulty_multiplier(), 8.0)
	current_speed = min(current_speed + config.speed_increase_per_second * speed_difficulty * delta, config.max_forward_speed)
	distance_traveled += current_speed * delta
	distance_changed.emit(distance_traveled, config.level_length)

	if distance_traveled - last_checkpoint >= config.checkpoint_interval:
		last_checkpoint = distance_traveled
		_log_analytics_event("checkpoint_reached", {"distance": distance_traveled})

	if distance_traveled >= config.level_length:
		win_game()

func get_difficulty_multiplier() -> float:
	# Exact doubling at each completed 10-second survival band.
	return pow(2.0, floor(survival_seconds / 10.0))

func lose_game() -> void:
	if not is_game_active:
		return
	is_game_active = false
	obstacle_hit.emit()
	_check_best_score()
	_log_analytics_event("game_lose", {"score": score, "distance": distance_traveled})
	game_lost.emit()

func win_game() -> void:
	if not is_game_active:
		return
	is_game_active = false
	_check_best_score()
	_log_analytics_event("game_win", {"score": score, "distance": distance_traveled})
	game_won.emit()

func _log_analytics_event(event_name: String, params: Dictionary) -> void:
	# STUB — replace this with a real ad-network / analytics SDK call
	# (e.g. AppsFlyer, Facebook Ads SDK, playable-ad host bridge, etc.)
	# Keeping every event funneled through here means integration later
	# is a one-function change, not a project-wide search-and-replace.
	print("[ANALYTICS] %s %s" % [event_name, params])

