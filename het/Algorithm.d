module het.algorithm;

import het.utils;

// FloodFill, Blob detection ////////////////////////////////////////////////////////////////////

struct Blob{
  ivec2 pos;
  int id;
  int area;
}

static if(1) struct findBlobsDebug{ import het.draw2d, het.ui; static:
  struct Event{
    ivec2 actPos;
    Image!(ubyte, 2) src;
    Image!(int, 2) dst;
    int[int] idMap;
    Blob[int] blobs;

    void draw(Drawing dr){ with(dr){
      fontHeight = .8;

      void setColor(int i){ color = hsvToRgb(([i].xxh&255)/255.0f, 1, 1).floatToRgb; }

      foreach(y; 0..src.height) foreach(x; 0..src.width){
        translate(x, y);

        if(src[x, y]) setColor(dst[x, y]); else color = clBlack;
        drawRect(0.05, 0.05, 0.95, 0.95);

        if(dst[x, y]) textOut(0.1, 0.1, dst[x, y].to!string(36));

        pop;
      }

      color = clWhite;
      foreach(i, k; idMap.keys.sort.array){
        translate(src.width+2, i);
        textOut(0, 0, k.to!string(36) ~ " -> " ~ idMap[k].to!string(36));
        pop;
      }


      foreach(k, v; blobs){
        translate(v.pos);
        setColor(k);
        fontHeight = 0.8;
        textOut(0.1, 0.1, k.to!string(36));
        color = clWhite;
        fontHeight = 0.3;
        textOut(0.1, 0.7, v.area.text);
        circle(vec2(.5), 0.7);
        pop;
      }

    }}
  }

  Event[] events;

  void log(A...)(A a){ events ~= Event(a); }

  int actEventIdx;

  void UI(){ with(im) Row({
    Text("FindBlobs debug idx:");
    const r = range(0, events.length.to!int-1);
    IncDec(actEventIdx, r);
    Slider(actEventIdx, r, { width = fh*32; });
  });}

  void draw(Drawing dr){ events.get(actEventIdx).draw(dr); }
}

auto findBlobs(T1)(Image!(T1, 2) src){
  struct Res{
    Image!(int, 2) img;
    Blob[int] blobs;
    alias blobs this;
  }

  Res res;
  res.img = image2D(src.size, 0);

  int[int] map_;
  int map(int i){ if(auto a = i in map_) return *a; else return i; }

  int actId;

  //first pass: find the blobs based on top and left neighbors
  foreach(y; 0..src.height) foreach(x; 0..src.width) if(src[x, y]){
    bool leftSet(){ return x ? src[x-1, y]!=0 : false; }
    bool topSet (){ return y ? src[x, y-1]!=0 : false; }
    int leftId(){ return res.img[x-1, y]; }
    int topId (){ return res.img[x, y-1]; }
    int p;

    if(leftSet && topSet){
      p = map(topId);   //map is important for topId
      int l = leftId;   //leftId is alrteady mapped
      if(p!=l){
        sort(p, l);     //sort is to eliminate cyclic loops im map_[]
        map_[l] = p;    //from unmapped to mapped is good
      }
    }else if(topSet   ){  p = map(topId ); //map is important for topId
    }else if(leftSet  ){  p = leftId;      //leftId is already mapped
    }else              {  p = ++actId; res.blobs[p] = Blob(ivec2(x, y), p); }

    res.img[x, y] = p;
    res.blobs[p].area++;

    static if(is(findBlobsDebug)) findBlobsDebug.log(ivec2(x, y), src.dup, res.img.dup, map_.dup, res.blobs.dup);
  }

  {//make the map recursive
    //print("FUCK"); map_.keys.sort.each!(k => print(k, "->", map_[k]));
    int map_recursive(int id){
      while(1) if(auto a = id in map_)id = *a; else break; //todo: install latest LDC
      return id;
    }
    foreach(k; map_.keys) map_[k] = map_recursive(k);
    //remap the result id image
    foreach(ref p; res.img) if(p) p = map(p);
  }

  { //remap the result blobs
    int[] rem;
    foreach(k; res.blobs.keys){ //opt: maybe the .array is not needed
      int p = map(k);
      if(p!=k){
        res.blobs[p].area += res.blobs[k].area;
        rem ~= k;
      }
    }
    rem.each!(k => res.blobs.remove(k));
  }

  static if(is(findBlobsDebug)) findBlobsDebug.log(ivec2(-1), src.dup, res.img.dup, map_.dup, res.blobs.dup);

  return res;
}

