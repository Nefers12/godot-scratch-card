shader_type spatial;
render_mode cull_disabled, blend_mix, depth_draw_opaque;

uniform sampler2D mask_texture : hint_default_black, filter_linear_mipmap;
uniform sampler2D reward_texture : hint_default_black, filter_linear_mipmap;

uniform vec4 top_color : source_color = vec4(0.7, 0.73, 0.78, 1.0);
uniform bool use_top_texture = false;
uniform sampler2D top_texture : hint_default_white, filter_linear_mipmap;

uniform float foil_metallic : hint_range(0.0, 1.0) = 0.8;
uniform float foil_roughness : hint_range(0.0, 1.0) = 0.3;

void fragment() {
	vec2 uv = UV;
	float mask_val = texture(mask_texture, uv).r;
	
	vec4 top_rgba = top_color;
	if (use_top_texture) {
		top_rgba = texture(top_texture, uv);
	}
	
	vec4 reward_rgba = texture(reward_texture, uv);
	vec4 final_color = mix(top_rgba, reward_rgba, mask_val);
	
	ALBEDO = final_color.rgb;
	METALLIC = mix(foil_metallic, 0.0, mask_val);
	ROUGHNESS = mix(foil_roughness, 0.9, mask_val);
}

