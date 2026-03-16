class_name TerrainErosion
extends RefCounted
## Post-processing erosion for heightmap terrain.
## Applies thermal erosion (material slides downhill) and simplified hydraulic
## erosion (water droplets carve drainage channels) to create natural-looking
## valleys, ridges, and drainage patterns from raw noise terrain.

## Thermal erosion: max slope angle before material slides (tangent of talus angle).
## ~0.6 ≈ 31 degrees. Lower = smoother terrain, higher = more rugged.
const THERMAL_TALUS: float = 0.6
## Thermal erosion: fraction of excess height transferred per iteration.
const THERMAL_TRANSFER: float = 0.4
## Thermal erosion: number of iterations over the full grid.
const THERMAL_ITERATIONS: int = 4

## Hydraulic erosion: number of water droplets to simulate.
const HYDRO_DROPLETS: int = 800
## Hydraulic erosion: max steps a droplet can travel before evaporating.
const HYDRO_MAX_STEPS: int = 120
## Hydraulic erosion: inertia factor (0 = pure gradient, 1 = pure momentum).
const HYDRO_INERTIA: float = 0.3
## Hydraulic erosion: sediment capacity multiplier.
const HYDRO_CAPACITY: float = 8.0
## Hydraulic erosion: fraction of capacity deficit picked up per step.
const HYDRO_EROSION: float = 0.3
## Hydraulic erosion: fraction of excess sediment deposited per step.
const HYDRO_DEPOSITION: float = 0.3
## Hydraulic erosion: speed decay per step.
const HYDRO_FRICTION: float = 0.05
## Hydraulic erosion: minimum speed before droplet dies.
const HYDRO_MIN_SPEED: float = 0.01
## Hydraulic erosion: radius of erosion/deposition brush (in vertices).
const HYDRO_RADIUS: int = 2
## Hydraulic erosion: gravity constant for speed calculation.
const HYDRO_GRAVITY: float = 4.0


static func apply(data: HeightmapData, map_seed: int) -> void:
	## Runs erosion passes on the heightmap data in-place.
	_thermal_erosion(data)
	_hydraulic_erosion(data, map_seed)


# ---------------------------------------------------------------------------
# Thermal Erosion
# ---------------------------------------------------------------------------

static func _thermal_erosion(data: HeightmapData) -> void:
	## For each vertex, if the slope to any neighbor exceeds the talus angle,
	## transfer material from the higher vertex to the lower one.
	## This smooths jagged ridges and creates natural scree slopes.
	var w: int = data.width
	var h: int = data.height
	var sx: float = data.terrain_scale.x
	var sy: float = data.terrain_scale.y
	# Talus threshold in heightmap units (not world units)
	var talus: float = THERMAL_TALUS * sx / sy

	# 4-connected neighbor offsets
	var offsets: Array[Vector2i] = [
		Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)
	]

	for _iter in range(THERMAL_ITERATIONS):
		for z in range(1, h - 1):
			for x in range(1, w - 1):
				var ch: float = data.get_height_at(x, z)
				var max_diff: float = 0.0
				var total_diff: float = 0.0
				var diffs: Array[float] = [0.0, 0.0, 0.0, 0.0]

				for ni in range(offsets.size()):
					var nx: int = x + offsets[ni].x
					var nz: int = z + offsets[ni].y
					var nh: float = data.get_height_at(nx, nz)
					var diff: float = ch - nh
					if diff > talus:
						diffs[ni] = diff - talus
						total_diff += diffs[ni]
						if diff > max_diff:
							max_diff = diff

				if total_diff <= 0.0:
					continue

				# Distribute material proportionally to neighbors below talus
				var move: float = max_diff * THERMAL_TRANSFER * 0.5
				for ni in range(offsets.size()):
					if diffs[ni] <= 0.0:
						continue
					var fraction: float = diffs[ni] / total_diff
					var transfer: float = move * fraction
					var nx: int = x + offsets[ni].x
					var nz: int = z + offsets[ni].y
					data.set_height_at(x, z, data.get_height_at(x, z) - transfer)
					data.set_height_at(nx, nz, data.get_height_at(nx, nz) + transfer)


# ---------------------------------------------------------------------------
# Hydraulic Erosion (particle-based)
# ---------------------------------------------------------------------------

static func _hydraulic_erosion(data: HeightmapData, map_seed: int) -> void:
	## Simulates water droplets rolling downhill. Each droplet picks up sediment
	## on steep slopes and deposits it on flat areas, carving drainage channels.
	var w: int = data.width
	var h: int = data.height
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = map_seed + 6000

	# Margin to avoid spawning on edge walls/ocean
	@warning_ignore("integer_division")
	var margin: int = maxi(w / 10, 8)

	for _drop in range(HYDRO_DROPLETS):
		# Spawn at random interior position
		var px: float = rng.randf_range(float(margin), float(w - margin - 1))
		var pz: float = rng.randf_range(float(margin), float(h - margin - 1))
		var dir_x: float = 0.0
		var dir_z: float = 0.0
		var speed: float = 1.0
		var sediment: float = 0.0
		var water: float = 1.0

		for _step in range(HYDRO_MAX_STEPS):
			var ix: int = floori(px)
			var iz: int = floori(pz)
			if ix < 1 or ix >= w - 2 or iz < 1 or iz >= h - 2:
				break

			# Bilinear gradient at current position
			var fx: float = px - float(ix)
			var fz: float = pz - float(iz)
			var h00: float = data.get_height_at(ix, iz)
			var h10: float = data.get_height_at(ix + 1, iz)
			var h01: float = data.get_height_at(ix, iz + 1)
			var h11: float = data.get_height_at(ix + 1, iz + 1)

			# Gradient (direction of steepest ascent)
			var grad_x: float = (h10 - h00) * (1.0 - fz) + (h11 - h01) * fz
			var grad_z: float = (h01 - h00) * (1.0 - fx) + (h11 - h10) * fx

			# Update direction with inertia
			dir_x = dir_x * HYDRO_INERTIA - grad_x * (1.0 - HYDRO_INERTIA)
			dir_z = dir_z * HYDRO_INERTIA - grad_z * (1.0 - HYDRO_INERTIA)

			# Normalize direction
			var dir_len: float = sqrt(dir_x * dir_x + dir_z * dir_z)
			if dir_len < 0.0001:
				# Random direction if flat
				var angle: float = rng.randf_range(0.0, TAU)
				dir_x = cos(angle)
				dir_z = sin(angle)
			else:
				dir_x /= dir_len
				dir_z /= dir_len

			# Move droplet
			var new_px: float = px + dir_x
			var new_pz: float = pz + dir_z

			var nix: int = floori(new_px)
			var niz: int = floori(new_pz)
			if nix < 1 or nix >= w - 2 or niz < 1 or niz >= h - 2:
				break

			# Height at new position (bilinear)
			var nfx: float = new_px - float(nix)
			var nfz: float = new_pz - float(niz)
			var nh00: float = data.get_height_at(nix, niz)
			var nh10: float = data.get_height_at(nix + 1, niz)
			var nh01: float = data.get_height_at(nix, niz + 1)
			var nh11: float = data.get_height_at(nix + 1, niz + 1)
			var new_h: float = nh00 * (1.0 - nfx) * (1.0 - nfz) + nh10 * nfx * (1.0 - nfz) + nh01 * (1.0 - nfx) * nfz + nh11 * nfx * nfz
			var old_h: float = h00 * (1.0 - fx) * (1.0 - fz) + h10 * fx * (1.0 - fz) + h01 * (1.0 - fx) * fz + h11 * fx * fz
			var h_diff: float = new_h - old_h

			# Sediment capacity based on speed, slope, and water volume
			var capacity: float = maxf(-h_diff, 0.01) * speed * water * HYDRO_CAPACITY

			if sediment > capacity or h_diff > 0.0:
				# Deposit sediment
				var deposit: float = 0.0
				if h_diff > 0.0:
					# Uphill: deposit enough to fill the hole (or all sediment)
					deposit = minf(h_diff, sediment)
				else:
					deposit = (sediment - capacity) * HYDRO_DEPOSITION
				sediment -= deposit
				_deposit_at(data, ix, iz, fx, fz, deposit)
			else:
				# Erode terrain
				var erode: float = minf((capacity - sediment) * HYDRO_EROSION, -h_diff)
				sediment += erode
				_erode_at(data, ix, iz, erode, w, h)

			# Update speed
			speed = sqrt(maxf(speed * speed + h_diff * HYDRO_GRAVITY, 0.0))
			speed *= (1.0 - HYDRO_FRICTION)
			water *= 0.99  # Evaporation

			if speed < HYDRO_MIN_SPEED:
				break

			px = new_px
			pz = new_pz


static func _deposit_at(data: HeightmapData, ix: int, iz: int,
		fx: float, fz: float, amount: float) -> void:
	## Deposits sediment using bilinear weights at the 4 surrounding vertices.
	data.set_height_at(ix, iz, data.get_height_at(ix, iz) + amount * (1.0 - fx) * (1.0 - fz))
	data.set_height_at(ix + 1, iz, data.get_height_at(ix + 1, iz) + amount * fx * (1.0 - fz))
	data.set_height_at(ix, iz + 1, data.get_height_at(ix, iz + 1) + amount * (1.0 - fx) * fz)
	data.set_height_at(ix + 1, iz + 1, data.get_height_at(ix + 1, iz + 1) + amount * fx * fz)


static func _erode_at(data: HeightmapData, cx: int, cz: int, amount: float,
		map_w: int, map_h: int) -> void:
	## Erodes terrain in a small brush radius around (cx, cz), weighted by distance.
	var total_weight: float = 0.0
	var weights: Array[float] = []
	var coords: Array[Vector2i] = []

	for dz in range(-HYDRO_RADIUS, HYDRO_RADIUS + 1):
		for dx in range(-HYDRO_RADIUS, HYDRO_RADIUS + 1):
			var nx: int = cx + dx
			var nz: int = cz + dz
			if nx < 0 or nx >= map_w or nz < 0 or nz >= map_h:
				continue
			var dist: float = sqrt(float(dx * dx + dz * dz))
			if dist > float(HYDRO_RADIUS):
				continue
			var w: float = maxf(0.0, float(HYDRO_RADIUS) - dist)
			weights.append(w)
			coords.append(Vector2i(nx, nz))
			total_weight += w

	if total_weight <= 0.0:
		return

	for i in range(coords.size()):
		var c: Vector2i = coords[i]
		var fraction: float = weights[i] / total_weight
		var erode_amount: float = amount * fraction
		data.set_height_at(c.x, c.y, data.get_height_at(c.x, c.y) - erode_amount)
