shader_type canvas_item;

uniform float border_width : hint_range(0.005, 0.2) = 0.03;
uniform float dot_spacing : hint_range(0.02, 0.5) = 0.15;
uniform float dot_length : hint_range(0.01, 0.3) = 0.08;
uniform vec4 border_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform vec4 bg_color : source_color = vec4(0.0, 0.0, 0.0, 0.0);

void fragment() {
	vec2 pixel_pos = UV;
	
	bool is_border = false;
	bool show_dot = false;
	
	// Check if we're on an edge
	bool on_top = pixel_pos.y < border_width;
	bool on_bottom = pixel_pos.y > 1.0 - border_width;
	bool on_left = pixel_pos.x < border_width;
	bool on_right = pixel_pos.x > 1.0 - border_width;
	
	// Top or bottom border
	if (on_top || on_bottom) {
		is_border = true;
		float x_pattern = mod(pixel_pos.x, dot_spacing);
		show_dot = x_pattern < dot_length;
	}
	
	// Left or right border (but not if we already showed a dot from top/bottom)
	if ((on_left || on_right) && !show_dot) {
		is_border = true;
		float y_pattern = mod(pixel_pos.y, dot_spacing);
		show_dot = y_pattern < dot_length;
	}
	
	// Only show dots on the border
	if (is_border && show_dot) {
		COLOR = border_color;
	} else {
		COLOR = bg_color;
	}
}
