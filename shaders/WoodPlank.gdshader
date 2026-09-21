shader_type spatial;
render_mode diffuse_toon, specular_disabled, cull_back;

uniform vec3 wood_base_color : source_color = vec3(0.70, 0.43, 0.22);
uniform vec3 wood_dark_color : source_color = vec3(0.46, 0.26, 0.12);
uniform vec3 wood_light_color : source_color = vec3(0.80, 0.52, 0.28);
uniform float grain_frequency = 14.0;
uniform float ring_frequency = 4.0;

varying vec3 v_local_pos;

void vertex() {
    v_local_pos = VERTEX;
}

void fragment() {
    // Procedural stylized wood grain along length (Z axis) and width (X axis)
    float z_scaled = v_local_pos.z * 1.8;
    float x_scaled = v_local_pos.x * 6.0;
    
    // Wave distortion for wood grain
    float grain_noise = sin(z_scaled * 0.8 + sin(x_scaled * 2.2) * 1.5);
    float fibers = sin((v_local_pos.x + grain_noise * 0.04) * grain_frequency * 8.0);
    fibers = smoothstep(0.3, 0.9, fibers * 0.5 + 0.5);
    
    float rings = sin(length(vec2(v_local_pos.x * 2.5, v_local_pos.y * 5.0)) * ring_frequency + z_scaled * 0.4);
    rings = smoothstep(0.2, 0.8, rings * 0.5 + 0.5);
    
    // Combine base, light highlight, and dark grain streaks
    vec3 col = mix(wood_base_color, wood_light_color, rings * 0.45);
    col = mix(col, wood_dark_color, fibers * 0.35);
    
    // Slight edge darkening on borders
    float edge = 1.0 - smoothstep(0.42, 0.52, abs(v_local_pos.x));
    col = mix(wood_dark_color * 0.85, col, edge);
    
    ALBEDO = col;
    ROUGHNESS = 0.75;
    SPECULAR = 0.08;
}
