shader_type canvas_item;
render_mode unshaded;
// Draw travelling ash behind the vitals/turn controls and keep cards readable.
uniform vec2 hud_band = vec2(0.0);
uniform float hand_top = 100000.0;
varying vec2 canvas_position;
void vertex() {
	canvas_position = VERTEX;
}
void fragment() {
	if ((canvas_position.y >= hud_band.x && canvas_position.y <= hud_band.y) || canvas_position.y >= hand_top) {
		COLOR.a = 0.0;
	}
}
