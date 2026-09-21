shader_type spatial;
render_mode diffuse_burley, cull_back;

varying float terrain_height;
varying vec3 world_pos;

float island_radius(vec2 p) {
    float a = atan(p.y, p.x);
    return 430.0 + 38.0 * sin(2.0 * a + 0.4) + 22.0 * sin(5.0 * a - 1.2) + 14.0 * sin(9.0 * a + 0.7);
}

float spiral_distance(vec2 p) {
    vec2 d = p - vec2(220.0, -180.0);
    float r = length(d);
    if (r < 0.001) return 0.0;
    float a = atan(d.y, d.x);
    if (a < 0.0) a += 6.2831853;
    float best = 9999.0;
    for (int k = 0; k < 3; k++) {
        float t = a + 6.2831853 * float(k);
        best = min(best, abs(r - (55.0 + 12.0 * t)));
    }
    return best;
}

float terrain_height_at(vec2 p) {
    float r = length(vec2(p.x / 1.02, p.y / 0.92));
    float boundary = island_radius(p);
    if (r > boundary) return -18.0;
    float edge = clamp((r - (boundary - 65.0)) / 65.0, 0.0, 1.0);
    float h = 1.3 * sin(p.x / 78.0) + sin(p.y / 69.0) + 0.65 * sin((p.x + p.y) / 49.0);
    h += 60.0 * exp(-pow((p.x - 220.0) / 145.0, 2.0) - pow((p.y + 180.0) / 130.0, 2.0));
    h *= 1.0 - edge * 0.65;
    float sd = spiral_distance(p);
    float rr = length(p - vec2(220.0, -180.0));
    if (rr < 250.0 && sd < 20.0) h -= min(7.5, (20.0 - sd) * 0.38);
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
    float radial = length(vec2(p.x / 1.02, p.y / 0.92));
    if (radial > boundary + 2.0) discard;

    float sd = spiral_distance(p);
    float patch = sin(p.x / 43.0) * sin(p.y / 49.0) + sin((p.x + p.y) / 41.0);
    float shore = smoothstep(boundary - 34.0, boundary - 4.0, radial);
    float path = 1.0 - smoothstep(17.0, 30.0, sd);
    float soil = smoothstep(16.0, 30.0, terrain_height) * smoothstep(0.05, 0.45, patch);
    float light = smoothstep(0.42, 0.82, patch) * (1.0 - soil);

    vec3 deep_green = vec3(0.075, 0.28, 0.055);
    vec3 light_green = vec3(0.30, 0.58, 0.12);
    vec3 sand = vec3(0.76, 0.64, 0.34);
    vec3 soil_color = vec3(0.38, 0.20, 0.08);

    vec3 base = deep_green;
    base = mix(base, light_green, light);
    base = mix(base, soil_color, soil);
    base = mix(base, sand, max(shore, path));

    ALBEDO = base;
    ROUGHNESS = 0.96;
}
