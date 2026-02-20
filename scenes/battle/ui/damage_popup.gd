extends Label
## Floating damage/heal number that rises and fades out.

var _velocity: Vector2 = Vector2(0, -60)


func setup(amount: int, popup_type: Enums.PopupType = Enums.PopupType.DAMAGE) -> void:
	match popup_type:
		Enums.PopupType.DAMAGE:
			text = str(amount)
			add_theme_color_override("font_color", Constants.COLOR_DAMAGE)
			add_theme_font_size_override("font_size", Constants.FONT_SIZE_POPUP)
		Enums.PopupType.CRIT:
			text = "%d!" % amount
			add_theme_color_override("font_color", Constants.COLOR_CRIT)
			add_theme_font_size_override("font_size", Constants.FONT_SIZE_POPUP_CRIT)
		Enums.PopupType.HEAL:
			text = "+%d" % amount
			add_theme_color_override("font_color", Constants.COLOR_HEAL)
			add_theme_font_size_override("font_size", Constants.FONT_SIZE_POPUP)

	# Add slight random horizontal offset
	_velocity.x = randf_range(-20, 20)

	# Animate: rise and fade over 1 second
	var tween: Tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(self, "position", position + Vector2(_velocity.x, _velocity.y), 0.8).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "modulate:a", 0.0, 0.8).set_delay(0.3)
	tween.set_parallel(false)
	tween.tween_callback(queue_free)
