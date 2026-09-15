extends Node2D

## Reskin note: this defines the collectible's look only. Colors come
## from GameConfig (package_color / package_tape_color). Swap this
## script for a coin, gem, or food-item shape without touching
## collectible.gd's pickup logic.

func _ready() -> void:
	queue_redraw()

func _draw() -> void:
	var cfg: GameConfig = GameManager.config
	var package_color: Color = cfg.package_color
	var package_rarity: int = get_parent().rarity if get_parent() is Collectible else Collectible.Rarity.NORMAL
	var destination_label: String = get_parent().get_destination_label() if get_parent() is Collectible else "C"
	if package_rarity == Collectible.Rarity.BLUE:
		package_color = Color("4d9dff")
	elif package_rarity == Collectible.Rarity.GREEN:
		package_color = Color("45c96b")
	elif package_rarity == Collectible.Rarity.RED:
		package_color = Color("ed5252")

	# Drop shadow
	draw_colored_polygon(DrawUtils.ellipse_points(Vector2(0, 22), 22, 8, 12), Color(0, 0, 0, 0.25))

	# Side face (implies depth)
	draw_colored_polygon(PackedVector2Array([
		Vector2(22, -22), Vector2(30, -16), Vector2(30, 22), Vector2(22, 22),
	]), package_color.darkened(0.28))

	# Top face (implies depth)
	draw_colored_polygon(PackedVector2Array([
		Vector2(-22, -22), Vector2(22, -22), Vector2(30, -16), Vector2(-14, -16),
	]), package_color.lightened(0.22))

	# Front face
	draw_colored_polygon(DrawUtils.rounded_rect_points(Rect2(-22, -16, 44, 38), 4), package_color)

	# Tape cross on the front face
	draw_rect(Rect2(-22, 1, 44, 6), cfg.package_tape_color)
	draw_rect(Rect2(-2, -16, 6, 38), cfg.package_tape_color)

	# Highlight along the front top edge
	draw_rect(Rect2(-22, -16, 44, 4), package_color.lightened(0.35))
	draw_string(ThemeDB.fallback_font, Vector2(-8, 15), destination_label, HORIZONTAL_ALIGNMENT_CENTER, 16, 14, Color.WHITE)

