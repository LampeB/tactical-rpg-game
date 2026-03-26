shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_burley, specular_schlick_ggx;

// Splatmap 1 — channels 0-3 via vertex color
// Splatmap 2 — channels 4-7 via texture sampled at chunk UV
// Splatmap 3 — channels 8-11 via texture sampled at chunk UV
uniform sampler2D splatmap2_tex : filter_linear, repeat_disable;
uniform sampler2D splatmap3_tex : filter_linear, repeat_disable;

// Terrain texture layers — albedo + normal + roughness + metallic per layer
group_uniforms layer0;
uniform sampler2D albedo_0 : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D normal_0 : hint_normal, filter_linear_mipmap, repeat_enable;
uniform sampler2D roughness_0 : filter_linear_mipmap, repeat_enable;
// uniform sampler2D metallic_0 : filter_linear_mipmap, repeat_enable;
uniform float uv_scale_0 : hint_range(0.1, 100.0) = 10.0;

group_uniforms layer1;
uniform sampler2D albedo_1 : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D normal_1 : hint_normal, filter_linear_mipmap, repeat_enable;
uniform sampler2D roughness_1 : filter_linear_mipmap, repeat_enable;
// uniform sampler2D metallic_1 : filter_linear_mipmap, repeat_enable;
uniform float uv_scale_1 : hint_range(0.1, 100.0) = 10.0;

group_uniforms layer2;
uniform sampler2D albedo_2 : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D normal_2 : hint_normal, filter_linear_mipmap, repeat_enable;
uniform sampler2D roughness_2 : filter_linear_mipmap, repeat_enable;
// uniform sampler2D metallic_2 : filter_linear_mipmap, repeat_enable;
uniform float uv_scale_2 : hint_range(0.1, 100.0) = 10.0;

group_uniforms layer3;
uniform sampler2D albedo_3 : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D normal_3 : hint_normal, filter_linear_mipmap, repeat_enable;
uniform sampler2D roughness_3 : filter_linear_mipmap, repeat_enable;
// uniform sampler2D metallic_3 : filter_linear_mipmap, repeat_enable;
uniform float uv_scale_3 : hint_range(0.1, 100.0) = 10.0;

group_uniforms layer4;
uniform sampler2D albedo_4 : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D normal_4 : hint_normal, filter_linear_mipmap, repeat_enable;
uniform sampler2D roughness_4 : filter_linear_mipmap, repeat_enable;
// uniform sampler2D metallic_4 : filter_linear_mipmap, repeat_enable;
uniform float uv_scale_4 : hint_range(0.1, 100.0) = 10.0;

group_uniforms layer5;
uniform sampler2D albedo_5 : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D normal_5 : hint_normal, filter_linear_mipmap, repeat_enable;
uniform sampler2D roughness_5 : filter_linear_mipmap, repeat_enable;
// uniform sampler2D metallic_5 : filter_linear_mipmap, repeat_enable;
uniform float uv_scale_5 : hint_range(0.1, 100.0) = 10.0;

group_uniforms layer6;
uniform sampler2D albedo_6 : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D normal_6 : hint_normal, filter_linear_mipmap, repeat_enable;
uniform sampler2D roughness_6 : filter_linear_mipmap, repeat_enable;
// uniform sampler2D metallic_6 : filter_linear_mipmap, repeat_enable;
uniform float uv_scale_6 : hint_range(0.1, 100.0) = 10.0;

group_uniforms layer7;
uniform sampler2D albedo_7 : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D normal_7 : hint_normal, filter_linear_mipmap, repeat_enable;
uniform sampler2D roughness_7 : filter_linear_mipmap, repeat_enable;
// uniform sampler2D metallic_7 : filter_linear_mipmap, repeat_enable;
uniform float uv_scale_7 : hint_range(0.1, 100.0) = 10.0;

group_uniforms layer8;
uniform sampler2D albedo_8 : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D normal_8 : hint_normal, filter_linear_mipmap, repeat_enable;
uniform sampler2D roughness_8 : filter_linear_mipmap, repeat_enable;
// uniform sampler2D metallic_8 : filter_linear_mipmap, repeat_enable;
uniform float uv_scale_8 : hint_range(0.1, 100.0) = 10.0;

group_uniforms layer9;
uniform sampler2D albedo_9 : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D normal_9 : hint_normal, filter_linear_mipmap, repeat_enable;
uniform sampler2D roughness_9 : filter_linear_mipmap, repeat_enable;
// uniform sampler2D metallic_9 : filter_linear_mipmap, repeat_enable;
uniform float uv_scale_9 : hint_range(0.1, 100.0) = 10.0;

group_uniforms layer10;
uniform sampler2D albedo_10 : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D normal_10 : hint_normal, filter_linear_mipmap, repeat_enable;
uniform sampler2D roughness_10 : filter_linear_mipmap, repeat_enable;
// uniform sampler2D metallic_10 : filter_linear_mipmap, repeat_enable;
uniform float uv_scale_10 : hint_range(0.1, 100.0) = 10.0;

group_uniforms layer11;
uniform sampler2D albedo_11 : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D normal_11 : hint_normal, filter_linear_mipmap, repeat_enable;
uniform sampler2D roughness_11 : filter_linear_mipmap, repeat_enable;
// uniform sampler2D metallic_11 : filter_linear_mipmap, repeat_enable;
uniform float uv_scale_11 : hint_range(0.1, 100.0) = 10.0;

// Vertex color carries splatmap1 weights: R=layer0, G=layer1, B=layer2, A=layer3
varying vec4 splat1;

void vertex() {
	splat1 = COLOR;
}

void fragment() {
	// Splatmap2 from texture (channels 4-7)
	vec4 splat2 = texture(splatmap2_tex, UV);
	// Splatmap3 from texture (channels 8-11)
	vec4 splat3 = texture(splatmap3_tex, UV);

	// Normalize all 12 weights together so they sum to 1.0
	vec4 w1 = splat1;
	vec4 w2 = splat2;
	vec4 w3 = splat3;
	float total = w1.r + w1.g + w1.b + w1.a + w2.r + w2.g + w2.b + w2.a
	            + w3.r + w3.g + w3.b + w3.a;
	if (total > 0.001) {
		w1 /= total;
		w2 /= total;
		w3 /= total;
	} else {
		w1 = vec4(1.0, 0.0, 0.0, 0.0);
		w2 = vec4(0.0);
		w3 = vec4(0.0);
	}

	// Sample each layer at its own UV scale
	vec2 uv0 = UV * uv_scale_0;
	vec2 uv1 = UV * uv_scale_1;
	vec2 uv2 = UV * uv_scale_2;
	vec2 uv3 = UV * uv_scale_3;
	vec2 uv4 = UV * uv_scale_4;
	vec2 uv5 = UV * uv_scale_5;
	vec2 uv6 = UV * uv_scale_6;
	vec2 uv7 = UV * uv_scale_7;
	vec2 uv8 = UV * uv_scale_8;
	vec2 uv9 = UV * uv_scale_9;
	vec2 uv10 = UV * uv_scale_10;
	vec2 uv11 = UV * uv_scale_11;

	// Albedo
	ALBEDO = texture(albedo_0, uv0).rgb * w1.r
	       + texture(albedo_1, uv1).rgb * w1.g
	       + texture(albedo_2, uv2).rgb * w1.b
	       + texture(albedo_3, uv3).rgb * w1.a
	       + texture(albedo_4, uv4).rgb * w2.r
	       + texture(albedo_5, uv5).rgb * w2.g
	       + texture(albedo_6, uv6).rgb * w2.b
	       + texture(albedo_7, uv7).rgb * w2.a
	       + texture(albedo_8, uv8).rgb * w3.r
	       + texture(albedo_9, uv9).rgb * w3.g
	       + texture(albedo_10, uv10).rgb * w3.b
	       + texture(albedo_11, uv11).rgb * w3.a;

	// Normal maps
	NORMAL_MAP = texture(normal_0, uv0).rgb * w1.r
	           + texture(normal_1, uv1).rgb * w1.g
	           + texture(normal_2, uv2).rgb * w1.b
	           + texture(normal_3, uv3).rgb * w1.a
	           + texture(normal_4, uv4).rgb * w2.r
	           + texture(normal_5, uv5).rgb * w2.g
	           + texture(normal_6, uv6).rgb * w2.b
	           + texture(normal_7, uv7).rgb * w2.a
	           + texture(normal_8, uv8).rgb * w3.r
	           + texture(normal_9, uv9).rgb * w3.g
	           + texture(normal_10, uv10).rgb * w3.b
	           + texture(normal_11, uv11).rgb * w3.a;
	NORMAL_MAP_DEPTH = 1.0;

	// Roughness (read from R channel of roughness maps)
	ROUGHNESS = texture(roughness_0, uv0).r * w1.r
	          + texture(roughness_1, uv1).r * w1.g
	          + texture(roughness_2, uv2).r * w1.b
	          + texture(roughness_3, uv3).r * w1.a
	          + texture(roughness_4, uv4).r * w2.r
	          + texture(roughness_5, uv5).r * w2.g
	          + texture(roughness_6, uv6).r * w2.b
	          + texture(roughness_7, uv7).r * w2.a
	          + texture(roughness_8, uv8).r * w3.r
	          + texture(roughness_9, uv9).r * w3.g
	          + texture(roughness_10, uv10).r * w3.b
	          + texture(roughness_11, uv11).r * w3.a;

	// Terrain is never metallic
	METALLIC = 0.0;
}
