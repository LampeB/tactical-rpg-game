shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_disabled, specular_schlick_ggx;

group_uniforms color;
uniform vec4 shallow_color : source_color = vec4(0.2, 0.5, 0.7, 0.6);
uniform vec4 deep_color : source_color = vec4(0.05, 0.15, 0.3, 0.85);
uniform float depth_fade : hint_range(0.1, 10.0) = 2.0;

group_uniforms waves;
uniform float wave_speed : hint_range(0.0, 2.0) = 0.3;
uniform float wave_strength : hint_range(0.0, 1.0) = 0.05;
uniform float wave_scale : hint_range(0.1, 20.0) = 4.0;

group_uniforms textures;
uniform sampler2D normal_map_a : hint_normal, filter_linear_mipmap, repeat_enable;
uniform sampler2D normal_map_b : hint_normal, filter_linear_mipmap, repeat_enable;
uniform float uv_scale : hint_range(0.1, 50.0) = 8.0;

group_uniforms surface;
uniform float metallic : hint_range(0.0, 1.0) = 0.1;
uniform float roughness : hint_range(0.0, 1.0) = 0.05;
uniform float specular : hint_range(0.0, 1.0) = 0.8;

// Screen texture for depth-based transparency
uniform sampler2D DEPTH_TEXTURE : hint_depth_texture, repeat_disable, filter_nearest;

void vertex() {
	// Vertex wave displacement
	float wave = sin(VERTEX.x * wave_scale + TIME * wave_speed * 3.0)
				* cos(VERTEX.z * wave_scale * 0.7 + TIME * wave_speed * 2.0);
	VERTEX.y += wave * wave_strength;
}

void fragment() {
	// Scrolling dual-layer normal map for ripple effect
	vec2 base_uv = UV * uv_scale;
	vec2 uv_a = base_uv + vec2(TIME * wave_speed * 0.3, TIME * wave_speed * 0.15);
	vec2 uv_b = base_uv * 0.8 + vec2(-TIME * wave_speed * 0.2, TIME * wave_speed * 0.25);

	vec3 normal_a = texture(normal_map_a, uv_a).rgb;
	vec3 normal_b = texture(normal_map_b, uv_b).rgb;
	NORMAL_MAP = normalize(normal_a + normal_b) * 0.5 + 0.5;
	NORMAL_MAP_DEPTH = 0.5;

	// Depth-based color blending
	float depth_raw = texture(DEPTH_TEXTURE, SCREEN_UV).r;
	vec4 world_pos = INV_PROJECTION_MATRIX * vec4(SCREEN_UV * 2.0 - 1.0, depth_raw, 1.0);
	world_pos.xyz /= world_pos.w;
	float water_depth = world_pos.z - VERTEX.z;
	float depth_factor = clamp(water_depth / depth_fade, 0.0, 1.0);

	vec4 col = mix(shallow_color, deep_color, depth_factor);
	ALBEDO = col.rgb;
	ALPHA = col.a;

	METALLIC = metallic;
	ROUGHNESS = roughness;
	SPECULAR = specular;
}
