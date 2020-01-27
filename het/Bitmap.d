module het.bitmap;

/*import het.utils;

class Bitmap {
  int width;
  int height;
  ubyte[] data;
  int[] rgba;

  this(File fn) {
    load(fn);
  }

  this(int w, int h) {
    width = w; height = h;
    data = new ubyte[w * h];
  }

  void load(File fn) {
    if(lc(fn.ext)==".ppm") {
      loadPPM(fn);
    }
  }

  void loadPPM(File fn) {
    ulong fsize = fn.size;

    data = fn.read;

    int i, ec;
    while(i<fsize) {
      if(data[i] == '\n') {
        ec++;
        if(ec == 3) break;
      }
      i++;
    }

    enforce(ec == 3);

    auto header = cast(string)data[0..i];

    data = data[i+1..$];

    auto list = header.split('\n')
               .map!(a => to!string(a).strip)
               .filter!(a => !a.empty)
               .array;

    enforce(list.length == 3);

    auto dim = list[1].split(' ')
               .map!(a => to!int(a))
               .filter!(a => a>0)
               .array;

    enforce(dim.length == 2);

    width = dim[0];
    height = dim[1];

    rgba = new int[width*height];
    for(i=0; i<width*height; i++) {
      ubyte R,G,B;
      R = data[3*i];
      G = data[3*i+1];
      B = data[3*i+2];

      rgba[i] = 0xFF << 24 | B << 16 | G << 8 | R;
    }
  }
}
  */