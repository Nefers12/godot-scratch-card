shader_type canvas_item;

uniform sampler2D mask_texture : hint_default_black, filter_linear;
uniform sampler2D reward_texture : hint_default_black, filter_linear;

uniform vec4 top_color : source_color = vec4(0.7, 0.73, 0.78, 1.0);
uniform bool use_top_texture = false;
uniform sampler2D top_texture : hint_default_white, filter_linear;

void fragment() {
	vec2 uv = UV;
	float mask_val = texture(mask_texture, uv).r;
	
	vec4 top_rgba = top_color;
	if (use_top_texture) {
		top_rgba = texture(top_texture, uv);
	}
	
	vec4 reward_rgba = texture(reward_texture, uv);
	vec4 final_color = mix(top_rgba, reward_rgba, mask_val);
	
	COLOR = final_color;
}

