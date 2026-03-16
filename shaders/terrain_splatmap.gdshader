shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_burley, specular_schlick_ggx;

// Terrain texture layers — albedo + normal for each of 4 splatmap channels
group_uniforms layer0;
uniform sampler2D albedo_0 : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D normal_0 : hint_normal, filter_linear_mipmap, repeat_enable;
uniform float uv_scale_0 : hint_range(0.1, 100.0) = 10.0;

group_uniforms layer1;
uniform sampler2D albedo_1 : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D normal_1 : hint_normal, filter_linear_mipmap, repeat_enable;
uniform float uv_scale_1 : hint_range(0.1, 100.0) = 10.0;

group_uniforms layer2;
uniform sampler2D albedo_2 : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D normal_2 : hint_normal, filter_linear_mipmap, repeat_enable;
uniform float uv_scale_2 : hint_range(0.1, 100.0) = 10.0;

group_uniforms layer3;
uniform sampler2D albedo_3 : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D normal_3 : hint_normal, filter_linear_mipmap, repeat_enable;
uniform float uv_scale_3 : hint_range(0.1, 100.0) = 10.0;

// Vertex color carries splatmap weights: R=layer0, G=layer1, B=layer2, A=layer3
varying vec4 splat_weights;

void vertex() {
	splat_weights = COLOR;
}

void fragment() {
	// Normalize weights so they sum to 1.0 (handles edge cases)
	vec4 w = splat_weights;
	float weight_sum = w.r + w.g + w.b + w.a;
	if (weight_sum > 0.0) {
		w /= weight_sum;
	} else {
		w = vec4(1.0, 0.0, 0.0, 0.0);
	}

	// Sample each layer at its own UV scale
	vec2 uv0 = UV * uv_scale_0;
	vec2 uv1 = UV * uv_scale_1;
	vec2 uv2 = UV * uv_scale_2;
	vec2 uv3 = UV * uv_scale_3;

	vec3 col0 = texture(albedo_0, uv0).rgb;
	vec3 col1 = texture(albedo_1, uv1).rgb;
	vec3 col2 = texture(albedo_2, uv2).rgb;
	vec3 col3 = texture(albedo_3, uv3).rgb;

	ALBEDO = col0 * w.r + col1 * w.g + col2 * w.b + col3 * w.a;

	// Blend normals
	vec3 n0 = texture(normal_0, uv0).rgb;
	vec3 n1 = texture(normal_1, uv1).rgb;
	vec3 n2 = texture(normal_2, uv2).rgb;
	vec3 n3 = texture(normal_3, uv3).rgb;

	NORMAL_MAP = n0 * w.r + n1 * w.g + n2 * w.b + n3 * w.a;
	NORMAL_MAP_DEPTH = 1.0;

	ROUGHNESS = 0.85;
	METALLIC = 0.0;
}
