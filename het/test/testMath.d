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


alias RGB8 = Vector!(ubyte, 3),  RGB  = RGB8;
alias RGBA8 = Vector!(ubyte, 4),  RGBA  = RGBA8;

enum isColor(T) = isVector!T && T.length>=3 && (is(T.ComponentType==ubyte) || is(T.ComponentType==float));

auto floatToRgb(T, int N)(in Vector!(T, N) x)  if(is(T == float)) { return Vector!(ubyte, N)(iround(x.clamp(0, 1)*255));  }
auto rgbToFloat(T, int N)(in Vector!(T, N) x)  if(is(T == ubyte)) { return x * (1.0f/255);                                }

auto hsvToRgb(A)(in A val) if(isColor!A){
  static if(A.length==4){
    return A(val.rgb.hsvToRgb, val.a); // preserve alpha
  }else{
    static if(is(A.ComponentType == float)) return hsvToRgb(val.x, val.y, val.z);
                                       else return val.rgbToFloat.hsvToRgb.floatToRgb;
  }
}

auto hsvToRgb(float H, float S, float V){ //0..1 range
  int sel;
  auto mod = modf(H * 6, sel),
       a = vec4(V,
                V * (1 - S),
                V * (1 - S * mod),
                V * (1 - S * (1 - mod)));
  switch(sel){
    case  0: return a.xwy;
    case  1: return a.zxy;
    case  2: return a.yxw;
    case  3: return a.yzx;
    case  4: return a.wyx;
    case  5: return a.xyz;
    default: return a.xwy;
  }
}

void main(){ //static import het.utils; het.utils.application.runConsole({
  het.math.unittest_main;

//  alias RGB8 = Vector!(ubyte, 3);

  RGB a = RGB(40, 80, 250);
  RGB b = RGB(1, 0, 1);

  import std.conv;

  writeln(a+b);
  writeln(mix(a, b, .5f)>>3);

  //import het.color;

  foreach(i; 0..30){
    //writeln(hsvToRgb(RGBA(i*255/30, 255, 255, 128)));
    auto c = hsvToRgb(vec4(i/30.0f, 1, 1, .5).floatToRgb);
    writeln(c, "  ", c ^ 255);
  }

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
