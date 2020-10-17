//@exe
//@import c:\d\libs
//@ldc
//@compile -m64 -mcpu=athlon64-sse3 -mattr=+ssse3
///@release
//@debug

///@compile --unittest  //this is broken because of my shitty linker usage

import het.math, std.stdio : writeln;

void main(){ static import het.utils; het.utils.application.runConsole({
  unittest_main;

  { // length, distance
    auto v = [vec2(1,2), vec2(-2, -1), vec2(5, 0)];
    static assert(vec2.length == 2 && v[0].length == 2); //length property of static arrays

    //dynamic array length must ONLY returned as a property, not as a function()
    static assert(!__traits(compiles, length(v)) && __traits(compiles, v.length));

    assert(v.length == 3); //dynamic length test
    assert(v[0].length == 2); //static vector length
    assert(length(v[0]).approxEqual(sqrt(1^^2 + 2^^2)) && length(v[0])==length(v[1]) && length(v[2])==5); //veryfy length calculations
    assert(v.map!manhattanLength.equal([3, 3, 5]));

    const a = ivec2(1, -4), b = vec2(12.5, 73.4);
    assert(distance         (a, b) == length         (a-b));
    assert(sqrDistance      (a, b) == sqrLength      (b-a));
    assert(manhattanDistance(a, b) == manhattanLength(a-b));

    assert(dot(vec2(3, 7), 2) == 3*2 + 7*2);

    assert(cross(a, b) == vec3(0, 0, determinant(mat2(a, b))));
    assert(cross(vec3(3,-3,1), vec3(4,9,2)) == vec3(-15,-2,39));

    assert(normalize(vec2(-0.5, 2)).approxEqual(vec2(-0.242536, 0.970143)));
  }


  writeln([true, true].all);
  writeln([true, false].all);
  writeln([false, false].any);
  writeln([true, false].any);

  writeln("done main");
}); }
