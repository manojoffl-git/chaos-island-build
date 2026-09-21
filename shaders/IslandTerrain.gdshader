shader_type spatial;
render_mode diffuse_burley, cull_back;

varying vec3 world_pos;
varying float terrain_height;

float island_radius(vec2 p) {
    float a = atan(p.y, p.x);
    return 410.0 + 28.0 * sin(2.0 * a + 0.4) + 18.0 * sin(5.0 * a - 1.1) + 10.0 * sin(9.0 * a + 0.7);
}

float terrain_height_at(vec2 p) {
    vec2 q = vec2(p.x / 1.03, p.y / 0.92);
    float r = length(q);
    float boundary = island_radius(p);
    if (r > boundary) return -18.0;

    float edge = clamp((r - (boundary - 75.0)) / 75.0, 0.0, 1.0);
    float h = 1.6 * sin(p.x / 65.0) + 1.2 * sin(p.y / 78.0);
    h += 0.8 * sin((p.x + p.y) / 52.0) + 0.5 * sin((p.x - p.y) / 31.0);

    // Main asymmetric mountain.
    h += 112.0 * exp(-pow((p.x - 150.0) / 190.0, 2.0) - pow((p.y + 120.0) / 165.0, 2.0));
    // Smaller secondary rise for an uneven island silhouette.
    h += 14.0 * exp(-pow((p.x + 210.0) / 150.0, 2.0) - pow((p.y - 170.0) / 120.0, 2.0));
    h *= 1.0 - edge * 0.78;

    // Winding climbable path from the lowlands toward the summit.
    vec2 d = p - vec2(150.0, -120.0);
    float rr = length(d);
    float aa = atan(d.y, d.x);
    if (aa < 0.0) aa += 6.2831853;
    float best = 999.0;
    for (int k = -1; k <= 4; k++) {
        float t = aa + 6.2831853 * float(k);
        best = min(best, abs(rr - (35.0 + 13.0 * t)));
    }
    float path = 1.0 - smoothstep(6.0, 16.0, best);
    h -= path * 2.8;

    if (rr < 24.0) h = max(h, 102.0);

    if (r > boundary - 12.0)
        h *= max(0.0, (boundary - r) / 12.0);

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
    float radial = length(vec2(p.x / 1.03, p.y / 0.92));
    if (radial > boundary + 1.5) discard;

    float patch = sin(p.x / 43.0) * sin(p.y / 49.0) + sin((p.x + p.y) / 41.0);

    vec2 d = p - vec2(150.0, -120.0);
    float rr = length(d);
    float aa = atan(d.y, d.x);
    if (aa < 0.0) aa += 6.2831853;
    float best = 999.0;
    for (int k = -1; k <= 4; k++) {
        float t = aa + 6.2831853 * float(k);
        best = min(best, abs(rr - (35.0 + 13.0 * t)));
    }
    float path = 1.0 - smoothstep(6.0, 16.0, best);
    float shore = 1.0 - smoothstep(-0.5, 5.0, terrain_height);
    float soil = smoothstep(18.0, 45.0, terrain_height) * smoothstep(0.05, 0.75, patch);
    float light = smoothstep(0.55, 0.95, patch) * (1.0 - soil);

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
