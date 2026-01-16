#version 320 es
// GLSL Fragment Shader

#ifdef GL_ES
precision highp float;
#endif

in vec2 v_texcoord;
uniform sampler2D tex;
out vec4 fragColor;

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

  pixColor[0] = color[0];
  pixColor[1] = color[1];
  pixColor[2] = color[2];

  fragColor = pixColor;
}
