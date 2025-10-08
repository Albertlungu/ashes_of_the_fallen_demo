shader_type sky;

// Sun/Moon settings
uniform vec3 sun_direction = vec3(0.0, 0.5, 0.5);
uniform vec3 moon_direction = vec3(0.0, -0.5, -0.5);

// Day colors - Proper blue tones for survival feel
uniform vec3 day_top_color : source_color = vec3(0.25, 0.35, 0.50);
uniform vec3 day_horizon_color : source_color = vec3(0.45, 0.50, 0.58);

// Night colors
uniform vec3 night_top_color : source_color = vec3(0.01, 0.01, 0.05);
uniform vec3 night_horizon_color : source_color = vec3(0.05, 0.05, 0.15);

// Sunset/Sunrise colors - More muted
uniform vec3 sunset_color : source_color = vec3(0.8, 0.35, 0.2);
uniform vec3 sunrise_color : source_color = vec3(0.9, 0.5, 0.3);

// Atmosphere settings
uniform float sun_size : hint_range(0.01, 0.5) = 0.04;
uniform float sun_intensity : hint_range(0.0, 10.0) = 1.2;
uniform float atmosphere_thickness : hint_range(0.0, 5.0) = 1.5;
uniform float horizon_glow : hint_range(0.0, 2.0) = 0.3;

// Stars
uniform float star_density : hint_range(0.0, 1.0) = 0.5;
uniform float star_brightness : hint_range(0.0, 2.0) = 1.0;

// Enhanced cloud settings
uniform bool enable_clouds = true;
uniform float cloud_speed : hint_range(0.0, 1.0) = 0.05;
uniform float cloud_coverage : hint_range(0.0, 1.0) = 0.35;
uniform float cloud_density : hint_range(0.0, 1.0) = 0.7;
uniform float cloud_scale : hint_range(0.1, 5.0) = 1.0;

// Fog settings
uniform vec3 fog_color : source_color = vec3(0.55, 0.60, 0.68);
uniform float fog_density : hint_range(0.0, 1.0) = 0.25;
uniform float fog_height : hint_range(0.0, 1.0) = 0.3;

// Simple noise function for stars and clouds
float hash(vec3 p) {
    p = fract(p * vec3(443.537, 537.247, 247.428));
    p += dot(p, p.yxz + 19.19);
    return fract((p.x + p.y) * p.z);
}

float noise(vec3 p) {
    vec3 i = floor(p);
    vec3 f = fract(p);
    f = f * f * (3.0 - 2.0 * f);
    
    return mix(
        mix(mix(hash(i), hash(i + vec3(1,0,0)), f.x),
            mix(hash(i + vec3(0,1,0)), hash(i + vec3(1,1,0)), f.x), f.y),
        mix(mix(hash(i + vec3(0,0,1)), hash(i + vec3(1,0,1)), f.x),
            mix(hash(i + vec3(0,1,1)), hash(i + vec3(1,1,1)), f.x), f.y),
        f.z
    );
}

// Fractal Brownian Motion for better clouds
float fbm(vec3 p) {
    float value = 0.0;
    float amplitude = 0.5;
    float frequency = 1.0;
    
    for(int i = 0; i < 4; i++) {
        value += amplitude * noise(p * frequency);
        frequency *= 2.0;
        amplitude *= 0.5;
    }
    
    return value;
}

void sky() {
    vec3 view_dir = normalize(EYEDIR);
    
    // Calculate sun position and time of day
    vec3 sun_dir = normalize(sun_direction);
    float sun_amount = max(dot(view_dir, sun_dir), 0.0);
    float sun_y = sun_dir.y;
    
    // Time of day factor (-1 = night, 0 = sunset/sunrise, 1 = day)
    float time_of_day = sun_y;
    
    // Atmospheric gradient
    float atmosphere = pow(1.0 - abs(view_dir.y), atmosphere_thickness);
    
    // Base sky color (day/night blend) - Proper blue tones
    vec3 sky_gradient_day = mix(day_horizon_color, day_top_color, max(view_dir.y, 0.0));
    vec3 sky_gradient_night = mix(night_horizon_color, night_top_color, max(view_dir.y, 0.0));
    vec3 sky_color = mix(sky_gradient_night, sky_gradient_day, smoothstep(-0.2, 0.2, time_of_day));
    
    // Reduce overall brightness
    sky_color *= 0.75;
    
    // Sunset/Sunrise glow at horizon - Reduced and only near horizon
    float sunset_amount = exp(-abs(sun_y) * 3.0) * smoothstep(-0.5, 0.5, sun_y);
    vec3 sunset_glow = sunset_amount * sunset_color * pow(atmosphere, 1.2) * horizon_glow;
    sky_color += sunset_glow * 0.4;
    
    // Sun disk - Less intense
    float sun_disk = smoothstep(sun_size, sun_size * 0.95, acos(sun_amount));
    vec3 sun_color = vec3(1.0, 0.95, 0.85) * sun_intensity * sun_disk;
    sun_color *= smoothstep(-0.1, 0.0, sun_y);
    
    // Sun corona/glow - Reduced
    float sun_glow = pow(sun_amount, 12.0) * 0.3;
    sun_color += sun_glow * vec3(0.9, 0.85, 0.7) * smoothstep(-0.1, 0.1, sun_y);
    
    // Stars (only visible at night)
    float star_visibility = smoothstep(0.2, -0.3, time_of_day);
    if (star_visibility > 0.01) {
        vec3 star_pos = view_dir * 100.0;
        float star_noise = hash(floor(star_pos));
        float star = step(1.0 - star_density * 0.01, star_noise);
        star *= pow(hash(floor(star_pos) + 0.1), 3.0) * star_brightness;
        sky_color += vec3(star) * star_visibility;
    }
    
    // Enhanced procedural clouds with more coverage
    if (enable_clouds && time_of_day > -0.3) {
        vec3 cloud_pos = view_dir * 30.0 * cloud_scale;
        cloud_pos.x += TIME * cloud_speed * 10.0;
        cloud_pos.z += TIME * cloud_speed * 5.0;
        
        // Multiple layers of clouds using FBM
        float cloud_noise1 = fbm(cloud_pos * 0.8);
        float cloud_noise2 = fbm(cloud_pos * 1.5 + vec3(100.0, 0.0, 100.0));
        float cloud_noise = (cloud_noise1 + cloud_noise2 * 0.5) / 1.5;
        
        // More aggressive cloud threshold for more coverage
        cloud_noise = smoothstep(cloud_coverage - 0.1, cloud_coverage + 0.4, cloud_noise);
        cloud_noise = pow(cloud_noise, 1.0 - cloud_density * 0.5);
        
        // Cloud color based on time of day - Cool gray/blue tones
        vec3 cloud_color = mix(vec3(0.2, 0.22, 0.28), vec3(0.70, 0.72, 0.78), smoothstep(-0.2, 0.3, time_of_day));
        cloud_color = mix(cloud_color, sunset_color * 0.7, sunset_amount * 0.3);
        
        // Blend clouds more heavily
        float cloud_alpha = cloud_noise * max(view_dir.y * 0.5 + 0.5, 0.0) * 0.95;
        sky_color = mix(sky_color, cloud_color, cloud_alpha);
    }
    
    // Atmospheric fog near horizon - Blue-gray tone
    float fog_factor = smoothstep(fog_height, -0.2, view_dir.y) * fog_density;
    vec3 fog_col = mix(fog_color, sunset_color * 0.4, sunset_amount * 0.25);
    fog_col = mix(fog_col, night_horizon_color, smoothstep(0.1, -0.2, time_of_day));
    sky_color = mix(sky_color, fog_col, fog_factor);
    
    // Final color with reduced sun intensity
    COLOR = sky_color + sun_color * 0.7;
}