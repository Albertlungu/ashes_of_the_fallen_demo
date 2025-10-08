shader_type spatial;

uniform sampler2D water_texture : source_color;
uniform sampler2D normal_map : hint_normal;
uniform vec2 uv_offset = vec2(0.0, 0.0);
uniform vec4 water_tint : source_color = vec4(0.7, 0.85, 1.0, 0.01);
uniform float metallic : hint_range(0.0, 1.0) = 0.1;
uniform float roughness : hint_range(0.0, 1.0) = 0.5;
uniform float normal_strength : hint_range(0.0, 2.0) = 1.0;
uniform float normal_speed_multiplier : hint_range(0.0, 2.0) = 0.7;

// NEW: Reflection controls
uniform float reflection_strength : hint_range(0.0, 1.0) = 1;
uniform float fresnel_power : hint_range(0.0, 5.0) = 2.0;

void fragment() {
	vec2 uv = UV + uv_offset;
	vec2 normal_uv = UV + (uv_offset * normal_speed_multiplier);
	
	vec4 tex = texture(water_texture, uv);
	vec3 normal_tex = texture(normal_map, normal_uv).rgb;
	
	// Fresnel effect (more reflection at grazing angles)
	float fresnel = pow(1.0 - dot(VIEW, NORMAL), fresnel_power);
	
	ALBEDO = tex.rgb * water_tint.rgb;
	ALPHA = water_tint.a;
	
	// Blend metallic based on viewing angle for realistic water
	METALLIC = mix(metallic, 1.0, fresnel * reflection_strength);
	ROUGHNESS = roughness;
	
	NORMAL_MAP = normal_tex;
	NORMAL_MAP_DEPTH = normal_strength;
}