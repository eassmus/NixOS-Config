#version 320 es
// GLSL Fragment Shader
// GLSL Fragment Shader

#ifdef GL_ES
precision highp float;
#endif

in vec2 v_texcoord;
uniform sampler2D tex;
out vec4 fragColor;

const float temperature = 2600.0;
const float temperatureStrength = 0.6;

const float LuminancePreservationFactor = 1.0;

vec3 colorTemperatureToRGB(const in float temperature) {
    mat3 m = (temperature <= 6500.0) ? mat3(vec3(0.0, -2902.1955373783176, -8257.7997278925690),
                                            vec3(0.0, 1669.5803561666639, 2575.2827530017594),
                                            vec3(1.0, 1.3302673723350029, 1.8993753891711275))
                                     : mat3(vec3(1745.0425298314172, 1216.6168361476490, -8257.7997278925690),
                                            vec3(-2666.3474220535695, -2173.1012343082230, 2575.2827530017594),
                                            vec3(0.55995389139931482, 0.70381203140554553, 1.8993753891711275));
    return mix(clamp(vec3(m[0] / (vec3(clamp(temperature, 1000.0, 40000.0)) + m[1]) + m[2]), vec3(0.0), vec3(1.0)), vec3(1.0), smoothstep(1000.0, 0.0, temperature));
}

void main() {
  vec4 pixColor = texture(tex, v_texcoord);
  vec3 color = vec3(pixColor[0], pixColor[1], pixColor[2]);

  ivec2 size = textureSize(tex, 0);

  float screenWidth = float(size.x);
  float screenHeight = float(size.y);

  vec2 scaled_loc = v_texcoord * vec2(screenWidth, screenHeight);

  vec2 top_left = vec2(0.0, 0.0);
  vec2 top_right = vec2(screenWidth, 0.0);
  vec2 bottom_left = vec2(0.0, screenHeight);
  vec2 bottom_right = vec2(screenWidth, screenHeight);

  float min_distance = min(min(distance(scaled_loc, top_left), distance(scaled_loc, top_right)), min(distance(scaled_loc, bottom_left), distance(scaled_loc, bottom_right)));

  float radius = 20.0;

  vec2 top_left_center2 = vec2(radius, radius);
  vec2 top_right_center2 = vec2(screenWidth - radius, radius);
  vec2 bottom_left_center2 = vec2(radius, screenHeight - radius);
  vec2 bottom_right_center2 = vec2(screenWidth - radius, screenHeight - radius);

  float min_distance3 = min(min(distance(scaled_loc, top_left_center2), distance(scaled_loc, top_right_center2)), min(distance(scaled_loc, bottom_left_center2), distance(scaled_loc, bottom_right_center2)));

  if (min_distance < radius && min_distance3 > radius) {
    color = vec3(0.0, 0.0, 0.0);
  }

  color = mix(color, color * colorTemperatureToRGB(temperature), temperatureStrength);
  color = vec3(color[0], color[1], color[2] * 0.7);
  vec4 outCol = vec4(0.75 * color, pixColor[3]);

  fragColor = outCol;
}
