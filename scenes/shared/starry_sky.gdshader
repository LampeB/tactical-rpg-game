shader_type sky;

// Sky gradient colors (driven by DayNightCycle)
uniform vec3 sky_top_color : source_color = vec3(0.4, 0.6, 0.9);
uniform vec3 sky_horizon_color : source_color = vec3(0.7, 0.8, 0.95);
uniform vec3 ground_bottom_color : source_color = vec3(0.15, 0.18, 0.12);
uniform vec3 ground_horizon_color : source_color = vec3(0.5, 0.55, 0.45);

// Star parameters
uniform float star_visibility : hint_range(0.0, 1.0) = 0.0;
uniform float moon_brightness : hint_range(0.0, 1.0) = 1.0;

// Sun disc
uniform vec3 sun_direction = vec3(0.0, 0.5, -0.866);
uniform vec3 sun_disk_color : source_color = vec3(1.0, 0.95, 0.8);
uniform float sun_energy_value : hint_range(0.0, 1.5) = 1.0;

// Moon disc
uniform vec3 moon_direction = vec3(0.0, 0.5, 0.866);
uniform float moon_phase_angle : hint_range(-1.0, 1.0) = 1.0;

// Hash functions for pseudo-random star placement
float hash(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

float hash2(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453123);
}

void sky() {
	// --- Sky gradient (matches ProceduralSkyMaterial behavior) ---
	float y = EYEDIR.y;

	vec3 sky_color;
	if (y >= 0.0) {
		// Above horizon: blend horizon → top
		float t = clamp(y / 0.8, 0.0, 1.0);
		t = t * t; // Ease-in for more horizon area
		sky_color = mix(sky_horizon_color, sky_top_color, t);
	} else {
		// Below horizon: blend horizon → bottom
		float t = clamp(-y / 0.6, 0.0, 1.0);
		t = t * t;
		sky_color = mix(ground_horizon_color, ground_bottom_color, t);
	}

	// --- Sun disc (only above horizon) ---
	if (y > -0.01 && sun_energy_value > 0.01) {
		vec3 sun_dir = normalize(sun_direction);
		float cos_angle = dot(normalize(EYEDIR), sun_dir);

		// Outer glow — soft warm halo
		float glow = smoothstep(0.985, 0.9995, cos_angle);
		sky_color += sun_disk_color * glow * 0.4 * sun_energy_value;

		// Inner disc — bright core
		float disc = smoothstep(0.9994, 0.9998, cos_angle);
		sky_color += sun_disk_color * disc * 2.0 * sun_energy_value;
	}

	// --- Moon disc (only above horizon) ---
	if (y > -0.01 && moon_brightness > 0.01) {
		vec3 moon_dir = normalize(moon_direction);
		float cos_angle = dot(normalize(EYEDIR), moon_dir);

		// Moon disc — slightly larger than sun
		float disc = smoothstep(0.9990, 0.9996, cos_angle);

		if (disc > 0.0) {
			// Phase shadow: offset a shadow circle to create crescent/gibbous
			// Build a local tangent frame on the moon disc
			vec3 up = vec3(0.0, 1.0, 0.0);
			vec3 tangent = normalize(cross(up, moon_dir));

			// Project EYEDIR onto the moon's local 2D plane
			vec3 to_eye = normalize(EYEDIR) - moon_dir * cos_angle;
			float local_x = dot(to_eye, tangent);
			float local_y = dot(to_eye, normalize(cross(moon_dir, tangent)));
			float moon_radius = 0.001; // approximate angular radius in direction space
			vec2 local_uv = vec2(local_x, local_y) / moon_radius;

			// Shadow circle offset by phase: 0 offset = full, large offset = crescent
			// moon_phase_angle: 1.0 = full moon, -1.0 = new moon
			float shadow_offset = (1.0 - moon_phase_angle) * 1.2;
			float shadow_dist = length(local_uv - vec2(shadow_offset, 0.0));
			float moon_uv_dist = length(local_uv);

			// The shadow circle eats into the moon disc
			float shadow = smoothstep(0.8, 1.0, shadow_dist / max(moon_uv_dist + 0.01, 0.01));
			float phase_mask = mix(shadow, 1.0, clamp(moon_phase_angle, 0.0, 1.0));

			// For negative phase angles (waning), flip the shadow side
			if (moon_phase_angle < 0.0) {
				float shadow_offset_neg = (1.0 + moon_phase_angle) * 1.2;
				float shadow_dist_neg = length(local_uv + vec2(shadow_offset_neg, 0.0));
				float shadow_neg = smoothstep(0.8, 1.0, shadow_dist_neg / max(moon_uv_dist + 0.01, 0.01));
				phase_mask = mix(shadow_neg, 1.0, clamp(-moon_phase_angle, 0.0, 1.0));
			}

			vec3 moon_color = vec3(0.85, 0.87, 0.92);
			sky_color += moon_color * disc * phase_mask * moon_brightness * 1.5;

			// Subtle moon glow
			float moon_glow = smoothstep(0.996, 0.9992, cos_angle);
			sky_color += moon_color * moon_glow * 0.15 * moon_brightness;
		}
	}

	// --- Stars (only above horizon) ---
	if (y > 0.0 && star_visibility > 0.0) {
		// Project sky direction to a stable 2D coordinate for star grid
		vec2 sky_uv = EYEDIR.xz / (EYEDIR.y + 0.001);
		sky_uv *= 80.0; // Star density — higher = more stars

		// Grid cell for this fragment
		vec2 cell = floor(sky_uv);
		vec2 frac_uv = fract(sky_uv) - 0.5;

		// Per-cell random values
		float rand_val = hash(cell);
		float rand_brightness = hash2(cell);
		float rand_size = hash(cell + vec2(42.0, 17.0));

		// Only some cells have stars (~30% density)
		if (rand_val > 0.7) {
			// Star center offset within cell (jittered)
			vec2 star_offset = vec2(hash(cell + vec2(1.0, 0.0)), hash(cell + vec2(0.0, 1.0))) - 0.5;
			float dist = length(frac_uv - star_offset * 0.4);

			// Star size: 3 tiers — bright large (5%), medium (15%), dim small (80%)
			float star_radius;
			float base_brightness;
			if (rand_size > 0.95) {
				// Bright large stars — always visible at night
				star_radius = 0.12;
				base_brightness = 1.0;
			} else if (rand_size > 0.80) {
				// Medium stars — visible in darker nights
				star_radius = 0.08;
				base_brightness = 0.6;
			} else {
				// Dim small stars — only visible on dark (new moon) nights
				star_radius = 0.05;
				base_brightness = 0.25;
			}

			// Moon wash-out: bright moon hides dim stars
			// moon_brightness 1.0 (full moon) hides dim stars
			// moon_brightness 0.0 (new moon) shows all stars
			float moon_wash = moon_brightness * 0.7;
			float effective_brightness = max(base_brightness - moon_wash, 0.0);

			// Slight twinkle from time
			float twinkle = 0.85 + 0.15 * sin(TIME * (1.5 + rand_brightness * 3.0) + rand_val * TAU);

			float star_intensity = smoothstep(star_radius, 0.0, dist) * effective_brightness * twinkle;

			// Warm tint for brightest stars, blue for dimmer ones
			vec3 star_color;
			if (rand_brightness > 0.8) {
				star_color = vec3(1.0, 0.95, 0.8); // Warm white
			} else if (rand_brightness > 0.5) {
				star_color = vec3(0.9, 0.92, 1.0); // Cool white
			} else {
				star_color = vec3(0.7, 0.8, 1.0); // Blue-ish
			}

			sky_color += star_color * star_intensity * star_visibility;
		}
	}

	COLOR = sky_color;
}
