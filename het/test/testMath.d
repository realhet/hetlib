//@exe
//@import c:\d\libs
//@ldc
//@compile -m64 -mcpu=athlon64-sse3 -mattr=+ssse3
///@release
//@debug

///@compile --unittest  //this is broken because of my shitty linker usage

import het.math, /*het.color, */std.stdio : write, writeln;

/+
// ShaderToy inputs
vec2 iResolution;


/**
 * @author jonobr1 / http://jonobr1.com/
 */

/**
 * Convert r, g, b to normalized vec3
 */
vec3 rgb(float r, float g, float b) {
  return vec3(r / 255.0, g / 255.0, b / 255.0);
}

/**
 * Draw a circle at vec2 `pos` with radius `rad` and
 * color `color`.
 */
vec4 circle(vec2 uv, vec2 pos, float rad, vec3 color) {
  float d = length(pos - uv) - rad;
  float t = clamp(d, 0.0, 1.0);
  return vec4(color, 1.0 - t);
}

void mainImage(out vec4 fragColor, in vec2 fragCoord ) {
  vec2 uv = fragCoord.xy;

  vec2 center = iResolution.xy * 0.5;
  float radius = 0.25 * iResolution.y;

    // Background layer
  vec4 layer1 = vec4(rgb(210.0, 222.0, 228.0), 1.0);

  // Circle
  vec3 red = rgb(225.0, 95.0, 60.0);
  vec4 layer2 = circle(uv, center, radius, red);

  // Blend the two
  fragColor = mix(layer1, layer2, layer2.a);
}
+/


void main(){ //static import het.utils; het.utils.application.runConsole({
//  import het.utils;

  het.math.unittest_main;
  import het.color;

  writeln("done main");


/+  iResolution = vec2(40, 25);
  foreach(y; 0..iResolution.y){
    foreach(x; 0..iResolution.x){
      vec2 fragCoord = vec2(x, y);
      vec4 fragColor;
      mainImage(fragColor, fragCoord);

      write(fragColor.g>50 ? "#" : ".");
    }
    writeln;
  }
  +/

}
