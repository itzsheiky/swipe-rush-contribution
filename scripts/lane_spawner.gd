extends Node2D
class_name LaneSpawner

## Drives the "world scrolls toward player" illusion AND the spawn logic.
##
## PERSPECTIVE: items spawn tiny at the horizon and interpolate toward
## their real lane x-position and full scale as they approach the player,
## giving the pseudo-3D converging-lanes look. Only the visual x/scale is
## perspective-interpolated — the actual gameplay collision still lines
## up with the player exactly the way it did before, because by the time
## an item reaches the player's y it has fully resolved to its real lane
## position and scale 1.0.
##
## SOLVABLE SPAWNING: waves use a small set of readable patterns. Every
## pattern leaves at least one lane open, and the pattern tier follows
## distance rather than changing randomly from one extreme to another.

@export var obstacle_scene: PackedScene = preload("res://scenes/obstacle.tscn")
@export var collectible_scene: PackedScene = preload("res://scenes/collectible.tscn")
@export var player_path: NodePath

var config: GameConfig
var player: Player
var lane_positions: Array[float] = []
var active_items: Array[Node2D] = []
var wave_timer: float = 0.0

var horizon_y: float = 0.0
var floor_y: float = 0.0
var vanishing_x: float = 0.0
var pattern_index: int = 0

func _ready() -> void:
	config = GameManager.config
	player = get_node(player_path)
	lane_positions = player.lane_positions
	var size: Vector2 = get_viewport_rect().size
	horizon_y = size.y * config.horizon_ratio
	floor_y = player.position.y
	vanishing_x = size.x / 2.0
	set_process(false)

func begin_spawning() -> void:
	active_items.clear()
	wave_timer = config.wave_interval * 1.2  # brief grace period before first wave
	pattern_index = 0
	set_process(true)

func stop_spawning() -> void:
	set_process(false)
	for item in active_items:
		if is_instance_valid(item):
			item.queue_free()
	active_items.clear()

func _process(delta: float) -> void:
	GameManager.advance(delta)
	_scroll_items(delta)
	wave_timer -= delta
	if wave_timer <= 0.0:
		wave_timer = get_wave_interval()
		_spawn_wave()

func _scroll_items(delta: float) -> void:
	var despawn_y: float = get_viewport_rect().size.y + 150.0
	for i in range(active_items.size() - 1, -1, -1):
		var item := active_items[i]
		if not is_instance_valid(item):
			active_items.remove_at(i)
			continue

		item.position.y += GameManager.current_speed * delta

		var t: float = clampf((item.position.y - horizon_y) / max(1.0, floor_y - horizon_y), 0.0, 1.0)
		var lane_index: int = item.get_meta("lane_index")
		item.position.x = lerp(vanishing_x, lane_positions[lane_index], t)
		var s: float = lerp(config.item_min_scale, 1.0, t)
		item.scale = Vector2(s, s)

		if item.position.y > despawn_y:
			item.queue_free()
			active_items.remove_at(i)

func _spawn_wave() -> void:
	var lane_count: int = lane_positions.size()
	if lane_count <= 0:
		return

	var obstacle_lanes: Array[int] = get_obstacle_pattern(lane_count, GameManager.distance_traveled)
	var open_lanes: Array[int] = []
	for lane in range(lane_count):
		if not obstacle_lanes.has(lane):
			open_lanes.append(lane)

	for lane in obstacle_lanes:
		_spawn_at(obstacle_scene, lane)

	# Always make one reward path available; extra packages add variety only.
	var guaranteed_lane: int = open_lanes[pattern_index % open_lanes.size()]
	for lane in open_lanes:
		if lane == guaranteed_lane or randf() < config.collectible_fill_chance:
			_spawn_at(collectible_scene, lane)
	pattern_index += 1

func get_wave_interval() -> float:
	var multiplier: float = GameManager.get_difficulty_multiplier()
	return max(config.minimum_wave_interval, config.early_wave_interval / sqrt(multiplier))

func get_difficulty(distance: float) -> float:
	# Smoothstep keeps the opening forgiving and avoids a sudden late spike.
	var progress := clampf(distance / max(config.level_length, 1.0), 0.0, 1.0)
	return progress * progress * (3.0 - 2.0 * progress)

func get_obstacle_pattern(lane_count: int, distance: float) -> Array[int]:
	if lane_count <= 1:
		return []
	var patterns: Array[Array] = []
	for lane in range(lane_count):
		patterns.append([lane])
	var difficulty_multiplier: float = GameManager.get_difficulty_multiplier()
	if difficulty_multiplier >= 2.0:
		for lane in range(lane_count - 1):
			patterns.append([lane, lane + 1])
	if difficulty_multiplier >= 4.0 and lane_count >= 3:
		patterns.append([0, lane_count - 1])
	var selected: Array[int] = []
	for lane in patterns[pattern_index % patterns.size()]:
		selected.append(int(lane))
	return selected

func _spawn_at(scene: PackedScene, lane_index: int) -> void:
	var instance := scene.instantiate() as Node2D
	instance.position = Vector2(vanishing_x, horizon_y)
	instance.scale = Vector2(config.item_min_scale, config.item_min_scale)
	instance.set_meta("lane_index", lane_index)
	if instance is Collectible:
		instance.rarity = choose_package_rarity()
		instance.destination = choose_destination()
	add_child(instance)
	active_items.append(instance)

func choose_package_rarity() -> Collectible.Rarity:
	var roll := randf()
	if roll < config.red_package_chance:
		return Collectible.Rarity.RED
	roll -= config.red_package_chance
	if roll < config.green_package_chance:
		return Collectible.Rarity.GREEN
	roll -= config.green_package_chance
	if roll < config.blue_package_chance:
		return Collectible.Rarity.BLUE
	return Collectible.Rarity.NORMAL

func choose_destination() -> Collectible.Destination:
	return randi_range(0, 2)

