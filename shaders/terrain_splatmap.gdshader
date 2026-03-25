shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_burley, specular_schlick_ggx;

// Splatmap 1 — channels 0-3 via vertex color
// Splatmap 2 — channels 4-7 via texture sampled at chunk UV
uniform sampler2D splatmap2_tex : filter_linear, repeat_disable;

// Terrain texture layers — albedo + normal for each of 8 splatmap channels
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

group_uniforms layer4;
uniform sampler2D albedo_4 : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D normal_4 : hint_normal, filter_linear_mipmap, repeat_enable;
uniform float uv_scale_4 : hint_range(0.1, 100.0) = 10.0;

group_uniforms layer5;
uniform sampler2D albedo_5 : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D normal_5 : hint_normal, filter_linear_mipmap, repeat_enable;
uniform float uv_scale_5 : hint_range(0.1, 100.0) = 10.0;

group_uniforms layer6;
uniform sampler2D albedo_6 : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D normal_6 : hint_normal, filter_linear_mipmap, repeat_enable;
uniform float uv_scale_6 : hint_range(0.1, 100.0) = 10.0;

group_uniforms layer7;
uniform sampler2D albedo_7 : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D normal_7 : hint_normal, filter_linear_mipmap, repeat_enable;
uniform float uv_scale_7 : hint_range(0.1, 100.0) = 10.0;

// Vertex color carries splatmap1 weights: R=layer0, G=layer1, B=layer2, A=layer3
varying vec4 splat1;

void vertex() {
	splat1 = COLOR;
}

void fragment() {
	// Splatmap2 from texture (channels 4-7)
	vec4 splat2 = texture(splatmap2_tex, UV);

	// Normalize all 8 weights together so they sum to 1.0
	vec4 w1 = splat1;
	vec4 w2 = splat2;
	float total = w1.r + w1.g + w1.b + w1.a + w2.r + w2.g + w2.b + w2.a;
	if (total > 0.001) {
		w1 /= total;
		w2 /= total;
	} else {
		w1 = vec4(1.0, 0.0, 0.0, 0.0);
		w2 = vec4(0.0);
	}

	// Sample each layer at its own UV scale
	vec3 col0 = texture(albedo_0, UV * uv_scale_0).rgb;
	vec3 col1 = texture(albedo_1, UV * uv_scale_1).rgb;
	vec3 col2 = texture(albedo_2, UV * uv_scale_2).rgb;
	vec3 col3 = texture(albedo_3, UV * uv_scale_3).rgb;
	vec3 col4 = texture(albedo_4, UV * uv_scale_4).rgb;
	vec3 col5 = texture(albedo_5, UV * uv_scale_5).rgb;
	vec3 col6 = texture(albedo_6, UV * uv_scale_6).rgb;
	vec3 col7 = texture(albedo_7, UV * uv_scale_7).rgb;

	ALBEDO = col0 * w1.r + col1 * w1.g + col2 * w1.b + col3 * w1.a
	       + col4 * w2.r + col5 * w2.g + col6 * w2.b + col7 * w2.a;

	// Blend normals
	vec3 n0 = texture(normal_0, UV * uv_scale_0).rgb;
	vec3 n1 = texture(normal_1, UV * uv_scale_1).rgb;
	vec3 n2 = texture(normal_2, UV * uv_scale_2).rgb;
	vec3 n3 = texture(normal_3, UV * uv_scale_3).rgb;
	vec3 n4 = texture(normal_4, UV * uv_scale_4).rgb;
	vec3 n5 = texture(normal_5, UV * uv_scale_5).rgb;
	vec3 n6 = texture(normal_6, UV * uv_scale_6).rgb;
	vec3 n7 = texture(normal_7, UV * uv_scale_7).rgb;

	NORMAL_MAP = n0 * w1.r + n1 * w1.g + n2 * w1.b + n3 * w1.a
	           + n4 * w2.r + n5 * w2.g + n6 * w2.b + n7 * w2.a;
	NORMAL_MAP_DEPTH = 1.0;

	ROUGHNESS = 0.85;
	METALLIC = 0.0;
}
