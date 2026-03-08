extends Node
## Cosmetic day/night cycle that drives sky, sun, and ambient light changes.
## Time advances in real-time over CYCLE_DURATION seconds (one full day).
## Other scripts read get_lighting_state() to apply the current values.

const CYCLE_DURATION := 600.0  ## 10 minutes for a full day
const LUNAR_CYCLE_DAYS := 8.0  ## Full moon cycle over 8 in-game days

## Time of day as 0.0–1.0 (0=midnight, 0.25=sunrise, 0.5=noon, 0.75=sunset)
var time_of_day: float = 0.35  ## Start at morning
## Moon phase as 0.0–1.0 (0=new moon, 0.5=full moon, 1.0=new moon again)
var moon_phase: float = 0.5  ## Start at full moon
var paused: bool = false

# --- Keypoint tables ---
# Each array is sorted by time. Values are linearly interpolated between entries.
# Last entry wraps to first (both at time 0.0 and 1.0 for seamless loop).

var _sun_energy_keys: Array[Array] = [
	[0.00, 0.0],   # midnight
	[0.20, 0.0],   # late night — still dark
	[0.25, 0.4],   # pre-dawn
	[0.30, 0.8],   # sunrise
	[0.50, 1.2],   # noon
	[0.70, 0.8],   # sunset
	[0.75, 0.4],   # dusk
	[0.80, 0.0],   # night
	[1.00, 0.0],   # midnight wrap
]

var _ambient_energy_keys: Array[Array] = [
	[0.00, 0.15],
	[0.20, 0.15],
	[0.25, 0.2],
	[0.30, 0.3],
	[0.50, 0.4],
	[0.70, 0.3],
	[0.75, 0.2],
	[0.80, 0.15],
	[1.00, 0.15],
]

var _sun_pitch_keys: Array[Array] = [
	[0.00, 80.0],   # midnight — well below horizon
	[0.22, 15.0],   # pre-dawn — just below horizon
	[0.25, -10.0],  # dawn — just above horizon
	[0.35, -40.0],  # morning
	[0.50, -80.0],  # noon — nearly overhead
	[0.65, -40.0],  # afternoon
	[0.75, -10.0],  # dusk — just above horizon
	[0.78, 15.0],   # post-dusk — just below horizon
	[1.00, 80.0],   # midnight — well below horizon
]

var _sun_yaw_keys: Array[Array] = [
	[0.00, -90.0],  # midnight — north
	[0.25, -60.0],  # dawn — east
	[0.50, 30.0],   # noon — south
	[0.75, 120.0],  # dusk — west
	[1.00, -90.0],  # midnight — wrap back to start
]

# Moon — opposite the sun, cool white light visible at night
var _moon_energy_keys: Array[Array] = [
	[0.00, 0.18],   # midnight — brightest
	[0.20, 0.15],   # late night
	[0.25, 0.08],   # dawn — fading
	[0.30, 0.0],    # sunrise — gone
	[0.70, 0.0],    # sunset — still gone
	[0.75, 0.08],   # dusk — appearing
	[0.80, 0.15],   # evening
	[1.00, 0.18],   # midnight wrap
]

var _moon_pitch_keys: Array[Array] = [
	[0.00, -80.0],  # midnight — nearly overhead (mirrors sun at noon)
	[0.20, -40.0],  # late night — descending
	[0.25, -10.0],  # dawn — setting low on horizon
	[0.28, 15.0],   # post-dawn — below horizon
	[0.72, 15.0],   # pre-dusk — below horizon
	[0.75, -10.0],  # dusk — rising low on horizon
	[0.80, -40.0],  # evening — ascending
	[1.00, -80.0],  # midnight — wrap
]

## Moon yaw is computed as sun_yaw + 180° (always opposite the sun)

# Color keypoints: [time, Color]
var _sun_color_keys: Array[Array] = [
	[0.00, Color(0.5, 0.4, 0.6)],    # moonlight blue-purple
	[0.20, Color(0.5, 0.4, 0.6)],
	[0.25, Color(1.0, 0.6, 0.3)],    # dawn — warm orange
	[0.30, Color(1.0, 0.85, 0.6)],   # sunrise — golden
	[0.50, Color(1.0, 0.96, 0.88)],  # noon — white-warm (original)
	[0.70, Color(1.0, 0.7, 0.4)],    # sunset — orange
	[0.75, Color(0.9, 0.4, 0.3)],    # dusk — deep orange-red
	[0.80, Color(0.5, 0.4, 0.6)],    # night
	[1.00, Color(0.5, 0.4, 0.6)],
]

var _ambient_color_keys: Array[Array] = [
	[0.00, Color(0.1, 0.1, 0.2)],    # deep blue night
	[0.20, Color(0.1, 0.1, 0.2)],
	[0.25, Color(0.25, 0.2, 0.25)],  # pre-dawn purple
	[0.30, Color(0.3, 0.28, 0.3)],   # sunrise
	[0.50, Color(0.3, 0.3, 0.35)],   # noon (original)
	[0.70, Color(0.3, 0.25, 0.28)],  # sunset
	[0.75, Color(0.2, 0.15, 0.22)],  # dusk
	[0.80, Color(0.1, 0.1, 0.2)],
	[1.00, Color(0.1, 0.1, 0.2)],
]

var _sky_top_keys: Array[Array] = [
	[0.00, Color(0.02, 0.02, 0.08)],  # deep navy
	[0.20, Color(0.05, 0.05, 0.15)],  # dark blue
	[0.25, Color(0.15, 0.15, 0.4)],   # pre-dawn blue
	[0.30, Color(0.3, 0.45, 0.75)],   # sunrise blue
	[0.50, Color(0.4, 0.6, 0.9)],     # noon (original)
	[0.70, Color(0.35, 0.4, 0.7)],    # sunset blue
	[0.75, Color(0.15, 0.1, 0.35)],   # dusk purple
	[0.80, Color(0.05, 0.05, 0.15)],
	[1.00, Color(0.02, 0.02, 0.08)],
]

var _sky_horizon_keys: Array[Array] = [
	[0.00, Color(0.05, 0.05, 0.12)],  # dark horizon
	[0.20, Color(0.1, 0.08, 0.15)],
	[0.25, Color(0.8, 0.5, 0.3)],     # dawn — orange-pink
	[0.30, Color(0.85, 0.7, 0.5)],    # sunrise — golden
	[0.50, Color(0.7, 0.8, 0.95)],    # noon (original)
	[0.70, Color(0.9, 0.55, 0.3)],    # sunset — orange
	[0.75, Color(0.5, 0.2, 0.3)],     # dusk — purple-red
	[0.80, Color(0.1, 0.08, 0.15)],
	[1.00, Color(0.05, 0.05, 0.12)],
]

var _ground_horizon_keys: Array[Array] = [
	[0.00, Color(0.05, 0.06, 0.05)],
	[0.25, Color(0.3, 0.25, 0.2)],
	[0.50, Color(0.5, 0.55, 0.45)],   # noon (original)
	[0.75, Color(0.3, 0.2, 0.2)],
	[1.00, Color(0.05, 0.06, 0.05)],
]

var _ground_bottom_keys: Array[Array] = [
	[0.00, Color(0.02, 0.03, 0.02)],
	[0.25, Color(0.08, 0.1, 0.06)],
	[0.50, Color(0.15, 0.18, 0.12)],  # noon (original)
	[0.75, Color(0.08, 0.06, 0.06)],
	[1.00, Color(0.02, 0.03, 0.02)],
]


func _process(delta: float) -> void:
	if not paused:
		time_of_day = fmod(time_of_day + delta / CYCLE_DURATION, 1.0)
		# Moon phase advances once per full day cycle
		moon_phase = fmod(moon_phase + delta / (CYCLE_DURATION * LUNAR_CYCLE_DAYS), 1.0)


func get_moon_brightness() -> float:
	## Returns 0.0 (new moon) to 1.0 (full moon) based on current phase.
	## Uses cosine curve: 0.5 = full moon (cos=1), 0.0/1.0 = new moon (cos=-1).
	return (cos((moon_phase - 0.5) * TAU) + 1.0) * 0.5


func get_star_visibility() -> float:
	## Returns 0.0 (day, no stars) to 1.0 (deep night, full stars).
	## Based on inverse of sun energy — stars fade in as sun fades out.
	var sun_e: float = _sample_float(_sun_energy_keys, time_of_day)
	return clampf(1.0 - sun_e / 0.4, 0.0, 1.0)


func get_lighting_state() -> Dictionary:
	## Returns all interpolated lighting values for the current time_of_day.
	var base_moon: float = _sample_float(_moon_energy_keys, time_of_day)
	var phase_mult: float = get_moon_brightness()
	var sun_yaw_val: float = _sample_float(_sun_yaw_keys, time_of_day)
	return {
		"sun_energy": _sample_float(_sun_energy_keys, time_of_day),
		"sun_color": _sample_color(_sun_color_keys, time_of_day),
		"sun_pitch": _sample_float(_sun_pitch_keys, time_of_day),
		"sun_yaw": sun_yaw_val,
		"ambient_energy": _sample_float(_ambient_energy_keys, time_of_day),
		"ambient_color": _sample_color(_ambient_color_keys, time_of_day),
		"sky_top": _sample_color(_sky_top_keys, time_of_day),
		"sky_horizon": _sample_color(_sky_horizon_keys, time_of_day),
		"ground_horizon": _sample_color(_ground_horizon_keys, time_of_day),
		"ground_bottom": _sample_color(_ground_bottom_keys, time_of_day),
		"moon_energy": base_moon * phase_mult,
		"moon_pitch": _sample_float(_moon_pitch_keys, time_of_day),
		"moon_yaw": sun_yaw_val + 180.0,
		"star_visibility": get_star_visibility(),
	}


func save_state() -> void:
	GameManager.set_flag("time_of_day", time_of_day)
	GameManager.set_flag("moon_phase", moon_phase)


func restore_state() -> void:
	var saved: Variant = GameManager.get_flag("time_of_day", 0.35)
	if saved is float:
		time_of_day = saved
	elif saved is int:
		time_of_day = float(saved)
	var saved_phase: Variant = GameManager.get_flag("moon_phase", 0.5)
	if saved_phase is float:
		moon_phase = saved_phase
	elif saved_phase is int:
		moon_phase = float(saved_phase)


# --- Interpolation helpers ---

static func _sample_float(keys: Array[Array], t: float) -> float:
	if keys.is_empty():
		return 0.0
	if t <= keys[0][0]:
		return keys[0][1]
	for i in range(1, keys.size()):
		if t <= keys[i][0]:
			var t0: float = keys[i - 1][0]
			var t1: float = keys[i][0]
			var weight: float = (t - t0) / (t1 - t0) if t1 > t0 else 0.0
			return lerpf(keys[i - 1][1], keys[i][1], weight)
	return keys[keys.size() - 1][1]


static func _sample_color(keys: Array[Array], t: float) -> Color:
	if keys.is_empty():
		return Color.WHITE
	if t <= keys[0][0]:
		return keys[0][1]
	for i in range(1, keys.size()):
		if t <= keys[i][0]:
			var t0: float = keys[i - 1][0]
			var t1: float = keys[i][0]
			var weight: float = (t - t0) / (t1 - t0) if t1 > t0 else 0.0
			var c0: Color = keys[i - 1][1]
			var c1: Color = keys[i][1]
			return c0.lerp(c1, weight)
	return keys[keys.size() - 1][1]
