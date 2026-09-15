extends Label

func show_value(value: int) -> void:
	text = "+%d" % value
	_animate()

func show_message(message: String) -> void:
	text = message
	_animate()

func _animate() -> void:
	pivot_offset = size / 2.0
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(self, "position:y", position.y - 60.0, 0.6)
	tween.tween_property(self, "modulate:a", 0.0, 0.6)
	tween.chain().tween_callback(queue_free)

