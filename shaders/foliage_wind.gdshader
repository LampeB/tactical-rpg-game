shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_disabled, diffuse_burley, specular_schlick_ggx;

// Wind vertex displacement for grass, leaves, and small foliage.
// Apply as a material override or next_pass on foliage meshes.

group_uniforms wind;
uniform float wind_strength : hint_range(0.0, 1.0) = 0.15;
uniform float wind_speed : hint_range(0.0, 5.0) = 1.5;
uniform vec2 wind_direction = vec2(1.0, 0.5);
uniform float wind_turbulence : hint_range(0.0, 2.0) = 0.3;
/// Approximate height of the mesh in local units. Used to normalize height_factor.
/// 1.0 = grass, ~5.0 = bush, ~8.0–15.0 = tree. Trunk stays planted, only tips sway.
uniform float mesh_height : hint_range(0.1, 30.0) = 1.0;

group_uniforms appearance;
uniform sampler2D base_texture : source_color, filter_linear_mipmap;
uniform float alpha_scissor : hint_range(0.0, 1.0) = 0.5;

void vertex() {
	// Displacement increases with vertex height, normalized by mesh height so roots stay planted
	float height_factor = clamp(VERTEX.y / mesh_height, 0.0, 1.0);
	height_factor *= height_factor; // Quadratic — tips move more than base

	// World-space position for consistent wind across instances
	vec3 world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;

	// Primary wind sway
	float phase = dot(world_pos.xz, normalize(wind_direction)) * 0.5 + TIME * wind_speed;
	float sway = sin(phase) * wind_strength * height_factor;

	// Turbulence (higher frequency noise)
	float turb = sin(world_pos.x * 3.7 + TIME * wind_speed * 2.3)
				* cos(world_pos.z * 2.9 + TIME * wind_speed * 1.7)
				* wind_turbulence * height_factor * 0.3;

	VERTEX.x += sway * wind_direction.x + turb;
	VERTEX.z += sway * wind_direction.y + turb * 0.7;
}

void fragment() {
	vec4 tex = texture(base_texture, UV);
	ALBEDO = tex.rgb;
	ALPHA = tex.a;
	ALPHA_SCISSOR_THRESHOLD = alpha_scissor;
	ROUGHNESS = 0.8;
	METALLIC = 0.0;
}
