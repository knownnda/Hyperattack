shader_type canvas_item;
// sits over the 3d view. "hit" = the freeze on a big hit, "gray" = time stop

uniform sampler2D screen_tex : hint_screen_texture, filter_linear;
uniform float hit = 0.0;
uniform float gray = 0.0;
uniform vec4 tint : source_color = vec4(1.0, 0.25, 0.35, 1.0);
uniform vec2 center = vec2(0.5);
uniform float aspect = 1.7778;
uniform float seed = 0.0;

float hash(float n) {
	return fract(sin(n) * 43758.5453);
}

void fragment() {
	vec3 c = texture(screen_tex, SCREEN_UV).rgb;
	float l = dot(c, vec3(0.299, 0.587, 0.114));

	// time stop: everything goes cold and washed out
	vec3 cold = mix(vec3(l), vec3(0.45, 0.6, 1.0) * l * 1.5, 0.5);
	c = mix(c, cold, gray);

	// big hit: world drains out and darkens, a bit of the hitter's colour bleeds in,
	// and faint speed lines come off the ball
	vec2 d = SCREEN_UV - center;
	d.x *= aspect;
	float dist = length(d);
	vec3 drained = mix(vec3(l * 0.5), tint.rgb * l, 0.3);
	drained *= mix(1.0, 0.55, smoothstep(0.15, 0.9, dist));
	float ang = atan(d.y, d.x);
	float slice = floor((ang + 3.14159) * 40.0);
	float lines = step(0.86, hash(slice + seed)) * smoothstep(0.18, 0.7, dist);
	drained = mix(drained, vec3(1.0), lines * 0.22);

	c = mix(c, drained, hit * 0.9);
	COLOR = vec4(c, 1.0);
}
