extends Label
## Floating damage/heal number that rises and fades out.

var _velocity: Vector2 = Vector2(0, -60)


func setup(amount: int, popup_type: String = "damage") -> void:
	match popup_type:
		"damage":
			text = str(amount)
			add_theme_color_override("font_color", Color(1.0, 0.3, 0.3))
			add_theme_font_size_override("font_size", 20)
		"crit":
			text = "%d!" % amount
			add_theme_color_override("font_color", Color(1.0, 0.84, 0.0))
			add_theme_font_size_override("font_size", 26)
		"heal":
			text = "+%d" % amount
			add_theme_color_override("font_color", Color(0.3, 1.0, 0.3))
			add_theme_font_size_override("font_size", 20)
		"miss":
			text = "MISS"
			add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
			add_theme_font_size_override("font_size", 18)

	# Add slight random horizontal offset
	_velocity.x = randf_range(-20, 20)

	# Animate: rise and fade over 1 second
	var tween: Tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(self, "position", position + Vector2(_velocity.x, _velocity.y), 0.8).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "modulate:a", 0.0, 0.8).set_delay(0.3)
	tween.set_parallel(false)
	tween.tween_callback(queue_free)
