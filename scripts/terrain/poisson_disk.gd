class_name PoissonDisk
extends RefCounted
## Bridson's algorithm for 2D blue-noise point distribution.
## Guarantees minimum distance between all returned points.


static func sample_2d(bounds: Rect2, min_distance: float, rng: RandomNumberGenerator, max_attempts: int = 30) -> PackedVector2Array:
	## Returns points distributed within `bounds` such that no two points
	## are closer than `min_distance`. Uses seeded `rng` for reproducibility.
	var cell_size: float = min_distance / sqrt(2.0)
	var grid_w: int = ceili(bounds.size.x / cell_size)
	var grid_h: int = ceili(bounds.size.y / cell_size)
	var grid_size: int = grid_w * grid_h

	# Flat grid storing point index (-1 = empty)
	var grid: PackedInt32Array = PackedInt32Array()
	grid.resize(grid_size)
	grid.fill(-1)

	var points: PackedVector2Array = PackedVector2Array()
	var active: PackedInt32Array = PackedInt32Array()

	# Seed point
	var first := Vector2(
		rng.randf_range(bounds.position.x, bounds.end.x),
		rng.randf_range(bounds.position.y, bounds.end.y)
	)
	points.append(first)
	active.append(0)
	var gx: int = int((first.x - bounds.position.x) / cell_size)
	var gy: int = int((first.y - bounds.position.y) / cell_size)
	if gx >= 0 and gx < grid_w and gy >= 0 and gy < grid_h:
		grid[gy * grid_w + gx] = 0

	var dist_sq: float = min_distance * min_distance

	while active.size() > 0:
		var active_idx: int = rng.randi_range(0, active.size() - 1)
		var point_idx: int = active[active_idx]
		var center: Vector2 = points[point_idx]
		var found: bool = false

		for _attempt in range(max_attempts):
			var angle: float = rng.randf() * TAU
			var radius: float = rng.randf_range(min_distance, min_distance * 2.0)
			var candidate := Vector2(
				center.x + cos(angle) * radius,
				center.y + sin(angle) * radius
			)

			# Bounds check
			if candidate.x < bounds.position.x or candidate.x >= bounds.end.x:
				continue
			if candidate.y < bounds.position.y or candidate.y >= bounds.end.y:
				continue

			var cx: int = int((candidate.x - bounds.position.x) / cell_size)
			var cy: int = int((candidate.y - bounds.position.y) / cell_size)
			if cx < 0 or cx >= grid_w or cy < 0 or cy >= grid_h:
				continue

			# Check neighbours in 5x5 grid around candidate
			var too_close: bool = false
			for dy in range(-2, 3):
				if too_close:
					break
				for dx in range(-2, 3):
					var nx: int = cx + dx
					var ny: int = cy + dy
					if nx < 0 or nx >= grid_w or ny < 0 or ny >= grid_h:
						continue
					var neighbour_idx: int = grid[ny * grid_w + nx]
					if neighbour_idx < 0:
						continue
					if candidate.distance_squared_to(points[neighbour_idx]) < dist_sq:
						too_close = true
						break

			if too_close:
				continue

			# Accept candidate
			var new_idx: int = points.size()
			points.append(candidate)
			active.append(new_idx)
			grid[cy * grid_w + cx] = new_idx
			found = true
			break

		if not found:
			# Remove from active list (swap with last)
			var last: int = active.size() - 1
			active[active_idx] = active[last]
			active.resize(last)

	return points
