shader_type spatial;
render_mode diffuse_toon, specular_disabled, cull_back;

varying vec3 v_world_pos;
varying vec4 v_vertex_color;

void vertex() {
    v_world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
    v_vertex_color = COLOR;
}

void fragment() {
    vec3 col = v_vertex_color.rgb;
    
    // Safety fallback
    if (length(col) < 0.05) {
        col = vec3(0.20, 0.58, 0.18);
    }
    
    ALBEDO = col;
    ROUGHNESS = 0.90;
    SPECULAR = 0.05;
}
