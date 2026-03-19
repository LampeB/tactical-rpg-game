shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_disabled, specular_schlick_ggx;

group_uniforms color;
uniform vec4 shallow_color : source_color = vec4(0.22, 0.50, 0.65, 0.45);
uniform vec4 deep_color : source_color = vec4(0.06, 0.16, 0.32, 0.75);

group_uniforms flow;
uniform float flow_speed : hint_range(0.0, 3.0) = 0.4;
uniform float wave_strength : hint_range(0.0, 0.5) = 0.02;
uniform float wave_scale : hint_range(0.1, 10.0) = 3.0;

group_uniforms textures;
uniform sampler2D normal_map_a : hint_normal, filter_linear_mipmap, repeat_enable;
uniform sampler2D normal_map_b : hint_normal, filter_linear_mipmap, repeat_enable;
uniform float uv_scale : hint_range(0.1, 20.0) = 4.0;

group_uniforms surface;
uniform float metallic : hint_range(0.0, 1.0) = 0.1;
uniform float roughness : hint_range(0.0, 1.0) = 0.08;
uniform float specular_val : hint_range(0.0, 1.0) = 0.7;

group_uniforms foam;
uniform vec4 foam_color : source_color = vec4(0.85, 0.92, 0.95, 0.8);
uniform float foam_width : hint_range(0.01, 0.3) = 0.10;
uniform float foam_intensity : hint_range(0.0, 1.0) = 0.45;

group_uniforms fresnel;
uniform float fresnel_power : hint_range(1.0, 10.0) = 3.0;
uniform float fresnel_opacity_boost : hint_range(0.0, 0.5) = 0.25;
uniform vec4 fresnel_reflect_color : source_color = vec4(0.5, 0.6, 0.7, 1.0);
uniform float fresnel_reflect_strength : hint_range(0.0, 1.0) = 0.2;

// Turbulence passed via vertex COLOR (R = curvature 0-1)
varying float v_curvature;

void vertex() {
	v_curvature = COLOR.r;
	// Gentle vertex wave — boost at bends via curvature
	float curve_boost = 1.0 + v_curvature * 2.0;
	float wave = sin(VERTEX.x * wave_scale + TIME * flow_speed * 2.0)
				* cos(VERTEX.z * wave_scale * 0.5 + TIME * flow_speed * 1.5);
	VERTEX.y += wave * wave_strength * curve_boost;
}

// Smooth value noise for foam (no harsh hash artifacts)
float value_noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	// Smooth hermite interpolation
	f = f * f * (3.0 - 2.0 * f);
	// Four corner hashes
	float a = fract(sin(dot(i, vec2(127.1, 311.7))) * 43758.5453);
	float b = fract(sin(dot(i + vec2(1.0, 0.0), vec2(127.1, 311.7))) * 43758.5453);
	float c = fract(sin(dot(i + vec2(0.0, 1.0), vec2(127.1, 311.7))) * 43758.5453);
	float d = fract(sin(dot(i + vec2(1.0, 1.0), vec2(127.1, 311.7))) * 43758.5453);
	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

void fragment() {
	// Directional flow: UV.y scrolls downstream, UV.x spans bank-to-bank
	vec2 base_uv = UV * uv_scale;

	// Primary flow layer — scrolls downstream (negative Y = downstream direction)
	vec2 uv_a = base_uv + vec2(0.0, -TIME * flow_speed * 0.5);
	// Secondary layer — slower, slight lateral drift for turbulence
	vec2 uv_b = base_uv * 0.7 + vec2(TIME * flow_speed * 0.08, -TIME * flow_speed * 0.35);

	// Blend normal maps — unpack from 0..1 to -1..1, average, repack
	vec3 normal_a = texture(normal_map_a, uv_a).rgb * 2.0 - 1.0;
	vec3 normal_b = texture(normal_map_b, uv_b).rgb * 2.0 - 1.0;
	NORMAL_MAP = normalize(normal_a + normal_b) * 0.5 + 0.5;
	NORMAL_MAP_DEPTH = 0.4;

	// --- Depth from UV.x (bank-to-center) — works in editor and all renderers ---
	// UV.x = 0 at left bank, 1 at right bank → center = 0.5
	float bank_dist = 1.0 - abs(UV.x * 2.0 - 1.0);  // 0 at edges, 1 at center
	float depth_factor = bank_dist * bank_dist;  // Quadratic: deeper toward center

	vec4 col = mix(shallow_color, deep_color, depth_factor);

	// --- Fresnel effect: glancing angles reflect more, steep angles show riverbed ---
	float n_dot_v = clamp(dot(NORMAL, VIEW), 0.0, 1.0);
	float fresnel = pow(1.0 - n_dot_v, fresnel_power);
	// Blend in reflection tint at glancing angles
	col.rgb = mix(col.rgb, fresnel_reflect_color.rgb, fresnel * fresnel_reflect_strength);
	// Boost opacity at glancing angles (water looks more solid from the side)
	col.a = clamp(col.a + fresnel * fresnel_opacity_boost, 0.0, 0.95);

	ALBEDO = col.rgb;
	ALPHA = col.a;

	// --- Shore foam line: animated froth at bank edges ---
	float edge_dist = min(UV.x, 1.0 - UV.x);  // 0 at banks, 0.5 at center
	float foam_mask = smoothstep(foam_width, foam_width * 0.2, edge_dist);

	// Smooth animated noise for organic foam breakup
	vec2 foam_uv = UV * 6.0 + vec2(TIME * flow_speed * 0.2, -TIME * flow_speed * 0.5);
	float foam_noise = value_noise(foam_uv * 3.0);
	float foam_noise2 = value_noise(foam_uv * 5.7 + vec2(13.5, 27.3));
	float foam_pattern = foam_noise * 0.6 + foam_noise2 * 0.4;
	// Only show foam where noise is high enough (breaks up the stripe)
	foam_mask *= smoothstep(0.35, 0.65, foam_pattern);

	// Turbulence foam at bends: only sharp bends get visible foam
	float turb_mask = smoothstep(0.3, 0.8, v_curvature) * 0.3 * smoothstep(0.35, 0.65, foam_pattern);
	foam_mask = max(foam_mask, turb_mask);

	// Apply foam — opaque frothy surface, not a color tint
	foam_mask *= foam_intensity;
	ALBEDO = mix(ALBEDO, foam_color.rgb, foam_mask);
	// Foam is opaque — it sits on top of the water
	ALPHA = mix(ALPHA, 1.0, foam_mask);

	// Foam gets its own bumpy normal (breaks up the smooth water reflection)
	if (foam_mask > 0.05) {
		vec3 foam_normal = vec3(
			value_noise(foam_uv * 8.0) * 2.0 - 1.0,
			1.0,
			value_noise(foam_uv * 8.0 + vec2(5.0, 3.0)) * 2.0 - 1.0
		);
		NORMAL_MAP = mix(NORMAL_MAP, normalize(foam_normal) * 0.5 + 0.5, foam_mask * 0.7);
	}

	// Fade out at banks for soft edge blending
	float edge_fade = smoothstep(0.0, 0.12, edge_dist);
	ALPHA *= edge_fade;

	METALLIC = mix(metallic, 0.0, foam_mask);  // Foam is not metallic
	ROUGHNESS = mix(roughness, 0.85, foam_mask);  // Foam is very rough (matte froth)
	SPECULAR = mix(specular_val, 0.1, foam_mask);  // Foam barely reflects
}
