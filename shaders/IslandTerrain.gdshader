shader_type spatial;
render_mode diffuse_burley, cull_back;

varying vec3 world_pos;
varying float terrain_height;

float island_radius(vec2 p) {
    float a = atan(p.y, p.x);
    return 455.0 + 42.0 * sin(2.0 * a + 0.5) + 24.0 * sin(5.0 * a - 1.1) + 15.0 * sin(9.0 * a + 0.8);
}

float terrain_height_at(vec2 p) {
    vec2 q = vec2(p.x / 1.03, p.y / 0.94);
    float r = length(q);
    float boundary = island_radius(p);
    if (r > boundary) return -12.0;

    float edge = clamp((r - (boundary - 90.0)) / 90.0, 0.0, 1.0);
    float h = 2.4 * sin(p.x / 72.0) + 1.8 * sin(p.y / 79.0) + 1.0 * sin((p.x + p.y) / 61.0);
    h += 125.0 * exp(-pow((p.x - 175.0) / 175.0, 2.0) - pow((p.y + 175.0) / 155.0, 2.0));
    h += 22.0 * exp(-pow((p.x + 180.0) / 150.0, 2.0) - pow((p.y - 100.0) / 170.0, 2.0));
    h += 16.0 * exp(-pow((p.x - 260.0) / 120.0, 2.0) - pow((p.y - 60.0) / 130.0, 2.0));
    h *= 1.0 - edge * 0.84;

    vec2 d = p - vec2(175.0, -175.0);
    float rr = length(d);
    float aa = atan(d.y, d.x);
    if (aa < 0.0) aa += 6.2831853;
    float spiral_r = 55.0 + 15.0 * aa;
    float path = 1.0 - smoothstep(12.0, 22.0, abs(rr - spiral_r));
    h -= path * 7.0;
    return h;
}

void vertex() {
    terrain_height = terrain_height_at(VERTEX.xz);
    VERTEX.y = terrain_height;
    world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
    vec2 p = world_pos.xz;
    float boundary = island_radius(p);
    float radial = length(vec2(p.x / 1.03, p.y / 0.94));
    if (radial > boundary + 2.0) discard;

    float patch = sin(p.x / 37.0) * sin(p.y / 43.0) + 0.55 * sin((p.x - p.y) / 29.0) + 0.35 * sin((p.x + p.y) / 17.0);
    vec2 d = p - vec2(175.0, -175.0);
    float rr = length(d);
    float aa = atan(d.y, d.x);
    if (aa < 0.0) aa += 6.2831853;
    float spiral_r = 55.0 + 15.0 * aa;
    float path = 1.0 - smoothstep(12.0, 22.0, abs(rr - spiral_r));
    float shore = 1.0 - smoothstep(-1.0, 6.0, terrain_height);
    float soil = smoothstep(42.0, 70.0, terrain_height) * smoothstep(0.25, 0.55, patch);
    float light = smoothstep(0.60, 0.95, patch) * (1.0 - soil);

    vec3 deep_green = vec3(0.055, 0.25, 0.055);
    vec3 light_green = vec3(0.30, 0.62, 0.12);
    vec3 sand = vec3(0.82, 0.69, 0.40);
    vec3 soil_color = vec3(0.40, 0.23, 0.10);

    vec3 base = deep_green;
    base = mix(base, light_green, light);
    base = mix(base, soil_color, soil);
    base = mix(base, sand, max(shore, path));
    ALBEDO = base;
    ROUGHNESS = 0.96;
}
