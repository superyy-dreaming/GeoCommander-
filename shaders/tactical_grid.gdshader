shader_type canvas_item;
render_mode unshaded;
uniform bool reduced_motion = false;
uniform vec2 world_size = vec2(3200.0, 2150.0);
uniform vec2 world_origin = vec2(-400.0);
void fragment() {
 vec2 world = UV * world_size + world_origin;
 vec2 cell = abs(fract(world / 60.0 + 0.5) - 0.5) * 60.0;
 float grid = 1.0 - smoothstep(0.65, 1.3, min(cell.x, cell.y));
 vec3 base = vec3(0.0022, 0.0028, 0.0045);
 vec3 ink = vec3(0.0065, 0.011, 0.025);
 float pulse = reduced_motion ? 0.0 : pow(max(0.0, 1.0 - abs(mod(length(world - vec2(1200.0,675.0)) - TIME * 90.0, 1300.0) - 650.0) / 75.0), 3.0);
 COLOR = vec4(mix(base, ink, grid) + vec3(0.0, 0.014, 0.026) * pulse, 1.0);
}
