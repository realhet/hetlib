module het.algorithm;

import het.utils, het.geometry;

import het.draw2d; //for testing only

//////////////////////////////////////////////////////////////////////
///  FloodFill, Blob detection                                     ///
//////////////////////////////////////////////////////////////////////

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

      void setColor(int i){ color = hsvToRgb(([i].xxh32&255)/255.0f, 1, 1).floatToRgb; }

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

//////////////////////////////////////////////////////////////////////
///  2D MaxRects Bin Packer                                        ///
//////////////////////////////////////////////////////////////////////

/* 2D MaxRects Bin Packer

Copyright (c) 2017 Shen Yiming

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.*/

alias RectangleData = int; //todo: a rectangle bele mehetne a binPacker classba es lehetne generic tipusu a data

class Rectangle{
  int x, y, width, height;
  RectangleData data;

  this(int x, int y, int width, int height) {
    this.x = x;
    this.y = y;
    this.width = width;
    this.height = height;
  }

  bool opEquals(const Rectangle r) const { return (this !is null) && (r !is null) && x==r.x && y==r.y && width==r.width && height==r.height; }

  int area() const { return this.width * this.height; }

  auto bounds() const { return ibounds2(x, y, x+width, y+height); }

  bool collide(Rectangle rect){ //intersection.area > 0
    return !(rect.x >= this.x + this.width || rect.x + rect.width <= this.x ||
            rect.y >= this.y + this.height || rect.y + rect.height <= this.y);
  }

  bool contain(Rectangle rect){ //the whole rect is inside this.
    return (rect.x >= this.x && rect.y >= this.y &&
            rect.x + rect.width <= this.x + this.width && rect.y + rect.height <= this.y + this.height);
  }

  override string toString() const { return bounds.text;}
}

private void splice(T)(ref T[] a, size_t i, size_t del = 0, T[] ins = []){
  a = a[0..i]~ins~a[i+del..$];
}

private bool collide(Rectangle first, Rectangle second) { return first.collide(second); }
private bool contain(Rectangle first, Rectangle second) { return first.contain(second); }

class MaxRectsBin{
    int width, height;
    const int maxWidth, maxHeight;
    Rectangle[] freeRects, rects;

    struct Options{ bool smart, pot, square;}
    const Options options;
    const int padding;

    private bool verticalExpand;
    private Rectangle stage;

    this(int initialWidth, int initialHeight, int maxWidth, int maxHeight, int padding=0, Options options = Options(true, true, false)){
        this.maxWidth = maxWidth;
        this.maxHeight = maxHeight;
        this.options = options;
        this.padding = padding;

        this.width  = this.options.smart ? initialWidth  : maxWidth ;
        this.height = this.options.smart ? initialHeight : maxHeight;
        this.freeRects ~= new Rectangle(0, 0, this.maxWidth + this.padding, this.maxHeight + this.padding);
        this.stage = new Rectangle(0, 0, this.width, this.height);
    }

    void reinitialize(){
      this.rects = [];
      this.freeRects = [new Rectangle(0, 0, this.maxWidth + this.padding, this.maxHeight + this.padding)];
      this.stage = new Rectangle(0, 0, this.width, this.height);
    }

    Rectangle add(int width, int height, RectangleData data = RectangleData.init){
        auto node = this.findNode(width + this.padding, height + this.padding);
        if (node) {
            this.updateBinSize(node);
            auto numRectToProcess = this.freeRects.length;
            auto i = 0;
            while (i < numRectToProcess) {
                if (this.splitNode(this.freeRects[i], node)) {
                    this.freeRects.splice(i, 1);
                    numRectToProcess--;
                    i--;
                }
                i++;
            }
            this.pruneFreeList();
            this.verticalExpand = this.width > this.height ? true : false;
            auto rect = new Rectangle(node.x, node.y, width, height);
            rect.data = data;
            this.rects ~= rect;
            return rect;
        } else if (!this.verticalExpand) {
            if (this.updateBinSize(new Rectangle(this.width + this.padding, 0, width + this.padding, height + this.padding))
                || this.updateBinSize(new Rectangle(0, this.height + this.padding, width + this.padding, height + this.padding))) {
                return this.add(width, height, data);
            }
        } else {
            if (this.updateBinSize(new Rectangle(
                0, this.height + this.padding,
                width + this.padding, height + this.padding
            )) || this.updateBinSize(new Rectangle(
                this.width + this.padding, 0,
                width + this.padding, height + this.padding
            ))) {
                return this.add(width, height, data);
            }
        }
        return null;
    }

// it bugs    sizediff_t find(in Rectangle     r)const { return rects.countUntil(r); }
    sizediff_t find(in RectangleData d)const { return rects.map!(r=>r.data).countUntil(d); }

    bool remove(sizediff_t idx){
      if(idx>=0){
        freeRects ~= rects[idx];
        rects = rects.remove(idx);
        return true;
      }else{
        return false;
      }
    }

// it bogs    bool remove(in Rectangle     r){ return remove(find(r)); }
    bool remove(in RectangleData d){ return remove(find(d)); }

  private:

    Rectangle findNode(int width, int height){
        auto score = int.max;
        int areaFit;
        Rectangle bestNode;
        foreach(r; freeRects) { //todo: ref if struct!!!
            if (r.width >= width && r.height >= height) {
                areaFit = r.width * r.height - width * height;
                if (areaFit < score) {
                    // bestNode.x = r.x;
                    // bestNode.y = r.y;
                    // bestNode.width = width;
                    // bestNode.height = height;
                    bestNode = new Rectangle(r.x, r.y, width, height);
                    score = areaFit;
                }
            }
        }
        return bestNode;
    }

    bool splitNode(Rectangle freeRect, Rectangle usedNode){
        // Test if usedNode intersect with freeRect
        if (!freeRect.collide(usedNode)) return false;

        // Do vertical split
        if (usedNode.x < freeRect.x + freeRect.width && usedNode.x + usedNode.width > freeRect.x) {
            // New node at the top side of the used node
            if (usedNode.y > freeRect.y && usedNode.y < freeRect.y + freeRect.height) {
                auto newNode = new Rectangle(freeRect.x, freeRect.y, freeRect.width, usedNode.y - freeRect.y);
                this.freeRects ~= newNode;
            }
            // New node at the bottom side of the used node
            if (usedNode.y + usedNode.height < freeRect.y + freeRect.height) {
                auto newNode = new Rectangle(
                    freeRect.x,
                    usedNode.y + usedNode.height,
                    freeRect.width,
                    freeRect.y + freeRect.height - (usedNode.y + usedNode.height)
                );
                this.freeRects ~= newNode;
            }
        }

        // Do Horizontal split
        if (usedNode.y < freeRect.y + freeRect.height &&
            usedNode.y + usedNode.height > freeRect.y) {
            // New node at the left side of the used node.
            if (usedNode.x > freeRect.x && usedNode.x < freeRect.x + freeRect.width) {
                auto newNode = new Rectangle(freeRect.x, freeRect.y, usedNode.x - freeRect.x, freeRect.height);
                this.freeRects ~= newNode;
            }
            // New node at the right side of the used node.
            if (usedNode.x + usedNode.width < freeRect.x + freeRect.width) {
                auto newNode = new Rectangle(
                    usedNode.x + usedNode.width,
                    freeRect.y,
                    freeRect.x + freeRect.width - (usedNode.x + usedNode.width),
                    freeRect.height
                );
                this.freeRects ~= newNode;
            }
        }
        return true;
    }

    void pruneFreeList () {
        // Go through each pair of freeRects and remove any rects that is redundant
        int i, j;
        auto len = this.freeRects.length;
        while (i < len) {
            j = i + 1;
            auto tmpRect1 = this.freeRects[i];
            while (j < len) {
                auto tmpRect2 = this.freeRects[j];
                if (tmpRect2.contain(tmpRect1)) {
                    this.freeRects.splice(i, 1);
                    i--;
                    len--;
                    break;
                }
                if (tmpRect1.contain(tmpRect2)) {
                    this.freeRects.splice(j, 1);
                    j--;
                    len--;
                }
                j++;
            }
            i++;
        }
    }

    bool updateBinSize(Rectangle node){
        if (!this.options.smart) return false;
        if (this.stage.contain(node)) return false;
        auto tmpWidth  = max(this.width , node.x + node.width  - this.padding);
        auto tmpHeight = max(this.height, node.y + node.height - this.padding);
        if (this.options.pot) {
            tmpWidth = nearest2NSize(tmpWidth);
            tmpHeight = nearest2NSize(tmpHeight);
        }
        if (this.options.square) {
            tmpWidth = tmpHeight = max(tmpWidth, tmpHeight);
        }
        if (tmpWidth > this.maxWidth + this.padding || tmpHeight > this.maxHeight + this.padding) {
            return false;
        }
        this.expandFreeRects(tmpWidth + this.padding, tmpHeight + this.padding);
        this.width = this.stage.width = tmpWidth;
        this.height = this.stage.height = tmpHeight;
        return true;
    }

    void expandFreeRects(int width, int height) {
        foreach(freeRect; this.freeRects){
            if (freeRect.x + freeRect.width >= min(this.width + this.padding, width)) {
                freeRect.width = width - freeRect.x;
            }
            if (freeRect.y + freeRect.height >= min(this.height + this.padding, height)) {
                freeRect.height = height - freeRect.y;
            }
        }
        this.freeRects ~= new Rectangle(this.width + this.padding, 0, width - this.width - this.padding, height);
        this.freeRects ~= new Rectangle(0, this.height + this.padding, width, height - this.height - this.padding);
        this.freeRects = this.freeRects.filter!(freeRect => !(freeRect.width <= 0 || freeRect.height <= 0)).array;
        this.pruneFreeList();
    }

public:

  void dump() const{
    writefln("BinPacker %s, %s, %s, %s", width, height, maxWidth, maxHeight);
    writeln("  rects: ", rects);
    writeln("  freeRects:", freeRects);
  }


  static string test(Drawing dr){ //test /////////////////////////////////
    import het.draw2d;

    auto mrb = new MaxRectsBin(0, 0, 1024, 1024);
    ivec2[] adds = [ivec2(1,1), ivec2(2,2), ivec2(7,3), ivec2(3,7), ivec2(1,1), ivec2(1,1)];

    RNG rng; rng.seed = 123;
    foreach(i; 0..60)
      adds ~= ivec2(rng.random(24)+1,rng.random(8)+1);

    foreach(i; 0..550)
      adds ~= ivec2(rng.random(2)+1,rng.random(2)+1);

    foreach(i, a; adds){
      mrb.add(a.x, a.y);

      if((i&3)==3){
        mrb.remove(rng.random(mrb.rects.length));
      }

      if(dr){
        dr.translate(cast(int)i * 65, 0);

        foreach(r; mrb.freeRects){
          dr.color = clGray;
          dr.drawRect(bounds2(r.bounds).inflated(-0.125));
        }

        dr.color = clWhite;  dr.drawRect(0, 0, mrb.width, mrb.height);

        foreach(j, r; mrb.rects){
          dr.color = clVga[(cast(int)j % ($-1))+1];
          dr.fillRect(r.bounds);
        }

        dr.pop;
      }
    }

    auto res = mrb.rects.text;

    enforce(res.xxh32==844746689, "MaxRectsBin add/remove test (2D Binpacking)");

    mrb.destroy;

    return res;
  }

}



