shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_disabled;

uniform vec4 tint_color : source_color = vec4(0.85, 0.94, 1.0, 0.52);
uniform vec4 outline_color : source_color = vec4(0.25, 0.85, 1.0, 1.0);
uniform float rim_power : hint_range(0.5, 6.0) = 2.2;
uniform float rim_intensity : hint_range(0.0, 5.0) = 2.2;

void fragment() {
    float ndotv = clamp(dot(normalize(NORMAL), normalize(VIEW)), 0.0, 1.0);
    float rim = pow(1.0 - ndotv, rim_power);
    
    vec3 base_col = tint_color.rgb;
    vec3 final_col = mix(base_col, outline_color.rgb, rim * 0.92);
    
    ALBEDO = final_col;
    EMISSION = outline_color.rgb * (rim * rim_intensity + 0.18);
    ALPHA = clamp(tint_color.a + rim * 0.45, 0.1, 0.98);
    ROUGHNESS = 0.25;
}
