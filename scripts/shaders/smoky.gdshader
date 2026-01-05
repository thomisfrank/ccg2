shader_type canvas_item;

// --- Uniforms (Settings you can change in the Inspector) ---
uniform vec4 base_color : source_color = vec4(0.1, 0.1, 0.1, 1.0);
uniform vec4 smoke_color : source_color = vec4(0.4, 0.4, 0.4, 1.0);
uniform float speed : hint_range(0.0, 1.0) = 0.05;
uniform float density : hint_range(0.0, 2.0) = 1.0;
uniform float softness : hint_range(0.0, 1.0) = 0.5;
uniform float time_offset = 0.0;

// --- Random and Noise Functions ---
// A simple pseudo-random function
float random(vec2 uv) {
    return fract(sin(dot(uv.xy, vec2(12.9898, 78.233))) * 43758.5453123);
}

// Value noise function to create smooth transitions
float noise(vec2 uv) {
    vec2 i = floor(uv);
    vec2 f = fract(uv);

    // Four corners in 2D of a tile
    float a = random(i);
    float b = random(i + vec2(1.0, 0.0));
    float c = random(i + vec2(0.0, 1.0));
    float d = random(i + vec2(1.0, 1.0));

    // Cubic Hermite Spline (smoothstep) for smoother interpolation
    vec2 u = f * f * (3.0 - 2.0 * f);

    return mix(a, b, u.x) +
            (c - a)* u.y * (1.0 - u.x) +
            (d - b) * u.x * u.y;
}

// Fractal Brownian Motion: Layering noise to make it look like clouds
float fbm(vec2 uv) {
    float value = 0.0;
    float amplitude = 0.5;
    
    // Loop for octaves (detail levels)
    for (int i = 0; i < 5; i++) {
        value += amplitude * noise(uv);
        uv *= 2.0; // Increase frequency
        amplitude *= 0.5; // Decrease amplitude
    }
    return value;
}

void fragment() {
    // 1. Correct Aspect Ratio (Optional, keeps smoke square even if panel is wide)
    // vec2 uv = UV;
    // uv.x *= SCREEN_PIXEL_SIZE.y / SCREEN_PIXEL_SIZE.x; 
    
    // 2. Movement
    // We shift the noise coordinates over time
    float t = TIME + time_offset;
    vec2 movement = vec2(t * speed, t * (speed * 0.5));
    
    // 3. Domain Warping
    // We use one noise layer to distort the coordinates of the next.
    // This creates the "swirly" fluid look.
    vec2 warp = vec2(
        fbm(UV * density + movement),
        fbm(UV * density + movement + vec2(5.2, 1.3))
    );
    
    // 4. Calculate Final Cloud Value
    float cloud_val = fbm(UV * density + warp + movement);
    
    // 5. Apply Softness/Contrast
    // This helps define the edges of the smoke wisps
    cloud_val = smoothstep(1.0 - softness, 1.0, cloud_val);

    // 6. Mix Colors
    vec4 final_color = mix(base_color, smoke_color, cloud_val);
    
    COLOR = final_color;
}
