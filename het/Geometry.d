module het.geometry;

import het.utils;

//TODO: implement fast sse approximations
//todo: migrate with gl3n
//todo: sortBounds() ez nem tul jo nev
/+

alias Point = vec2;
alias Rect = Bounds2f;
alias Size = Typedef!(vec2, vec2.init, "Size");

//todo: a Rect az size-t kap, a bounds csak bound-okat.
auto Rect2f(float x0, float y0, float xs, float ys){ return Bounds2f(x0, y0, x0+xs, y0+ys); }
auto Rect2i(int   x0, int   y0, int   xs, int   ys){ return Bounds2i(x0, y0, x0+xs, y0+ys); }

auto Rect2f(in vec2  topLeft, in vec2  size){ return Bounds2f(topLeft, topLeft+size); }
auto Rect2i(in ivec2 topLeft, in ivec2 size){ return Bounds2i(topLeft, topLeft+size); }


bool isVectorType(T)() { return is(T==V2i) || is(T==V2f) || is(T==V2d) || is(T==V3i) || is(T==V3f) || is(T==V3d); }
bool isMatrixType(T)() { return false; }

////////////////////////////////////////////////////////////////////////////////////////////
///  Vector templates                                                                    ///
////////////////////////////////////////////////////////////////////////////////////////////

private:

mixin template V2Members(V, E){  //vector type, element type
  mixin JsonizeMe;

  @jsonize E x=0, y=0;
  ref E opIndex(int n)                        { return *((&x)+n); }

  enum axisX = V(1,0);
  enum axisY = V(0,1);
  static V axis(int n) { return n==0 ? axisX : n==1 ? axisY : Null; }

  enum Null = typeof(this).init;
  bool isNull() const{ return this == typeof(this).init; }

  V opUnary(string op)()                    const { return mixin("V("~op~"x, "~op~"y)"); }
  V opBinary(string op)(V b)                const { return mixin("V(x"~op~"b.x, y"~op~"b.y)"); }
  V opBinary(string op)(const E b)          const { return mixin("V(x"~op~"b  , y"~op~"b  )"); }
  V opOpAssign(string op)(const V b)        { mixin("x"~op~"=b.x; y"~op~"=b.y;"); return this; }
  V opOpAssign(string op)(const E b)        { mixin("x"~op~"=b  ; y"~op~"=b  ;"); return this; }
  bool opEquals()(const V b)                const { return x==b.x && y==b.y; }
  auto opCmp(const V b)                     const { E n=x-b.x; if(!n) return n; return y-b.y; }

  E lenSq()   const { return vDot(this, this); }  //todo: len-rol atirni vLen-re
  E lenManh() const { return vAbs(this).sum; }

  E sum()     const { return x+y; }
  V yx()      const { return V(y, x); }
}

mixin template V3Members(V, E){  //vector type, element type
  mixin JsonizeMe;

  @jsonize E x=0, y=0, z=0;
  ref E opIndex(int n)                        { return *((&x)+n); }

  enum axisX = V(1,0,0);
  enum axisY = V(0,1,0);
  enum axisZ = V(0,0,1);
  static V axis(int n) { return n==0 ? axisX : n==1 ? axisY : n==2 ? axisZ : Null; }

  enum Null = typeof(this).init;
  bool isNull() const{ return this == typeof(this).init; }

  V opUnary(string op)()                    const { return mixin("V("~op~"x, "~op~"y, "~op~"z)"); }
  V opBinary(string op)(V b)                const { return mixin("V(x"~op~"b.x, y"~op~"b.y, z"~op~"b.z)"); }
  V opBinary(string op)(const E b)          const { return mixin("V(x"~op~"b  , y"~op~"b  , z"~op~"b  )"); }
  V opOpAssign(string op)(const V b)        { mixin("x"~op~"=b.x; y"~op~"=b.y; z"~op~"=b.z;"); return this; }
  V opOpAssign(string op)(const E b)        { mixin("x"~op~"=b  ; y"~op~"=b  ; z"~op~"=b  ;"); return this; }
  bool opEquals()(const V b)                const { return x==b.x && y==b.y && z==b.z; }
//  auto opCmp(const V b)                     const { E n=x-b.x; if(!n) return n; return y-b.y; }

  E lenSq()   const { return vDot(this, this); }  //todo: len-rol atirni vLen-re
  E lenManh() const { return vAbs(this).sum; }

  E sum()     const { return x+y; }
  V yxz()     const { return V(y, x, z); }
}

mixin template V2IntMembers(V, E){ //only for ints
  mixin V2Members!(V, E);

  auto toF() const { return V2f(x, y); }
  auto toD() const { return V2d(x, y); }

  float len_prec()              const { return sqrt(cast(float)lenSq); }
  float lenRcp_prec()           const { return 1.0f/len_prec; } //TODO: faster version

  int flatten(int width)        const { return y*width+x; } //calculates an offset in a bitmap
}

mixin template V3IntMembers(V, E){ //only for ints
  mixin V3Members!(V, E);

  auto toF() const { return V3f(x, y, z); }
  auto toD() const { return V3d(x, y, z); }

  float len_prec()              const { return sqrt(cast(float)lenSq); }
  float lenRcp_prec()           const { return 1.0f/len_prec; } //TODO: faster version

  int flatten(int width, int height) const { return (z*height + y)*width + x; } //calculates an offset in a bitmap
}

mixin template V2FloatMembers(V, E){ //only for floats
  mixin V2Members!(V, E);

  auto toF() const { return V2f(x, y); }
  auto toD() const { return V2d(x, y); }

  E len_prec()    const { return sqrt(lenSq); }
  E len_fast()    const { return sqrt(lenSq); } //todo: sse approx
  E lenRcp_prec() const { return 1/len_prec; }
  E lenRcp_fast() const { return 1/len_prec; } //todo: sse approx
}

mixin template V3FloatMembers(V, E){ //only for floats
  mixin V3Members!(V, E);

  auto toF() const { return V3f(x, y, z); }
  auto toD() const { return V3d(x, y, z); }

  E len_prec()    const { return sqrt(lenSq); }
  E len_fast()    const { return sqrt(lenSq); } //todo: sse approx
  E lenRcp_prec() const { return 1/len_prec; }
  E lenRcp_fast() const { return 1/len_prec; } //todo: sse approx
}

mixin template V2Functs(V, E){ //for ints and for floats
  V opBinary(string op)(E a, const V b)      const { return mixin("V(a.x"~op~"b.x, a.y"~op~"b.y)"); }

  E vDot    (const V a, const V b)           { return a.x*b.x + a.y*b.y; }
  E vCrossZ (const V a, const V b)           { return a.x*b.y - a.y*b.x; }
  V vMin    (const V a, const V b)           { return V(.min(a.x, b.x), .min(a.y, b.y)); }
  V vMax    (const V a, const V b)           { return V(max(a.x, b.x), max(a.y, b.y)); }
  V vAbs    (const V a)                      { return V(abs(a.x), abs(a.y)); }
  void vSort   (  ref V a, ref   V b)        { sort(a.x, b.x); sort(a.y, b.y); }
  V vClamp  (const V a, E mi=0, E ma=1)      { return V(clamp(a.x, mi, ma), clamp(a.y, mi, ma)); }
  V vRot90  (const V v)                      { return V(-v.y, v.x); }
  V vRot270 (const V v)                      { return V(v.y, -v.x); }
}

mixin template V3Functs(V, E){ //for ints and for floats
  V opBinary(string op)(E a, const V b)      const { return mixin("V(a.x"~op~"b.x, a.y"~op~"b.y), a.z"~op~"b.z)"); }

  E vDot    (const V a, const V b)           { return a.x*b.x + a.y*b.y + a.z*b.z; }
//  E vCrossZ (const V a, const V b)           { return a.x*b.y - a.y*b.x; }
  V vMin    (const V a, const V b)           { return V(.min(a.x, b.x), .min(a.y, b.y), .min(a.z, b.z)); }
  V vMax    (const V a, const V b)           { return V(max(a.x, b.x), max(a.y, b.y), max(a.z, b.z)); }
  V vAbs    (const V a)                      { return V(abs(a.x), abs(a.y), abs(a.z)); }
  void vSort   (  ref V a, ref   V b)        { sort(a.x, b.x); sort(a.y, b.y); sort(a.z, b.z); }
  V vClamp  (const V a, E mi=0, E ma=1)      { return V(clamp(a.x, mi, ma), clamp(a.y, mi, ma), clamp(a.z, mi, ma)); }
//  V vRot90  (const V v)                      { return V(-v.y, v.x); }
//  V vRot270 (const V v)                      { return V(v.y, -v.x); }
}

mixin template V2IntFuncts(V, E){ //only for floats
  mixin V2Functs!(V, E);
  V vSetLen (const V a, E len)               { V2f f = a.toF; return vRound(f*(f.lenRcp_prec*len)); }
  V vLerp   (const V a, const V b, float t)  { return vRound(a.toF*(1-t)+b.toF*t); }
  V vAvg    (const V a, const V b)           { return (a+b)>>1; }
  V vRot(const V v, float rad) {
    float s = sin(rad), c = cos(rad);
    auto f = v.toF;
    return V(iround(c*f.x -s*f.y), iround(s*f.x +c*f.y));
  }

  V alignUp(const V v, E align_)     { return V(het.utils.alignUp(v.x, align_), het.utils.alignUp(v.y, align_)); }
}

mixin template V3IntFuncts(V, E){ //only for floats
  mixin V3Functs!(V, E);
  V vSetLen (const V a, E len)               { V3f f = a.toF; return vRound(f*(f.lenRcp_prec*len)); }
  V vLerp   (const V a, const V b, float t)  { return vRound(a.toF*(1-t)+b.toF*t); }
  V vAvg    (const V a, const V b)           { return (a+b)>>1; }
/*  V vRot(const V v, float rad) {
    float s = sin(rad), c = cos(rad);
    auto f = v.toF;
    return V(iRound(c*f.x -s*f.y), iRound(s*f.x +c*f.y));
  }*/

  V alignUp(const V v, E align_)     { return V(het.utils.alignUp(v.x, align_), het.utils.alignUp(v.y, align_), het.utils.alignUp(v.z, align_)); }
}

mixin template V2FloatFuncts(V, E){ //only for floats
  mixin V2Functs!(V, E);

  V vNormal (const V a)                      { return a*a.lenRcp_prec; }
  V vNormalLen(const V a, ref E _len)        { _len = cast(E)a.len_prec; return vNormal(a); } //OPT: not too optimal
  V vSetLen (const V a, E len)               { return a*(a.lenRcp_prec*len); }
  V vLerp   (const V a, const V b, E t)      { return a*(1-t)+b*t; }
  V vAvg    (const V a, const V b)           { return (a+b)*0.5f; }
  E vDist_prec(in V a, in V b)               { return (a-b).len_prec; }
  E vDist_fast(in V a, in V b)               { return (a-b).len_fast; }
  auto vRound  (const V a)                   { return V2i(iround(a.x), iround(a.y)); } //todo: a vFloor-t meg az iFloor-t egy kalap ala hozni.
  auto vTrunc  (const V a)                   { return V2i(itrunc(a.x), itrunc(a.y)); }
  auto vFloor  (const V a)                   { return V2i(ifloor(a.x), ifloor(a.y)); }
  auto vCeil   (const V a)                   { return V2i(iceil (a.x), iceil (a.y)); }
  V vRot(const V v, E rad) {
    E s = sin(rad), c = cos(rad);
    return V(c*v.x -s*v.y, s*v.x +c*v.y);
  }
  bool follow(ref V act, const V target, const float t, const float maxd) {
    return het.utils.follow(act.x, target.x, t, maxd)|
           het.utils.follow(act.y, target.y, t, maxd);
  }
  E vPerpDistance_prec(const V P1, const V P2, const V p) {
    return abs((P2.y-P1.y)*p.x - (P2.x-P1.x)*p.y + P2.x*P1.y - P2.y*P1.x) /
           sqrt((P2.y-P1.y)^^2 + (P2.x-P1.x)^^2);
  }

  V vSum(in V[] a){ V s = V.Null; foreach(e; a) s += e; return s; }  //todo: normal sum not working on V2f... Why the fuck?!
  V vMean(in V[] a){ return a.length ? a.vSum*((cast(E)1)/a.length) : V.Null; }
  alias vAvg = vMean;
}

mixin template V3FloatFuncts(V, E){ //only for floats
  mixin V3Functs!(V, E);

  V vNormal (const V a)                      { return a*a.lenRcp_prec; }
  V vNormalLen(const V a, ref E _len)        { _len = cast(E)a.len_prec; return vNormal(a); } //OPT: not too optimal
  V vSetLen (const V a, E len)               { return a*(a.lenRcp_prec*len); }
  V vLerp   (const V a, const V b, E t)      { return a*(1-t)+b*t; }
  V vAvg    (const V a, const V b)           { return (a+b)*0.5f; }
  E vDist_prec(const V a, const V b)         { return (a-b).len_prec; }
  E vDist_fast(const V a, const V b)         { return (a-b).len_fast; }
  auto vRound  (const V a)                   { return V3i(iround(a.x), iround(a.y), iround(a.z)); }
  auto vTrunc  (const V a)                   { return V3i(itrunc(a.x), itrunc(a.y), itrunc(a.z)); }
  auto vFloor  (const V a)                   { return V3i(ifloor(a.x), ifloor(a.y), ifloor(a.z)); }
  auto vCeil   (const V a)                   { return V3i(iceil (a.x), iceil (a.y), iceil (a.z)); }
/*  V vRot(const V v, E rad) {
    E s = sin(rad), c = cos(rad);
    return V(c*v.x -s*v.y, s*v.x +c*v.y);
  }*/
  bool follow(ref V act, const V target, const float t, const float maxd) {
    return het.utils.follow(act.x, target.x, t, maxd)|
           het.utils.follow(act.y, target.y, t, maxd)|
           het.utils.follow(act.z, target.z, t, maxd);
  }
/*  E vPerpDistance_prec(const V P1, const V P2, const V p) {
    return abs((P2.y-P1.y)*p.x - (P2.x-P1.x)*p.y + P2.x*P1.y - P2.y*P1.x) /
           sqrt((P2.y-P1.y)^^2 + (P2.x-P1.x)^^2);
  }*/

  V vSum(in V[] a){ V s = V.Null; foreach(e; a) s += e; return s; }  //todo: normal sum not working on V2f... Why the fuck?!
  V vMean(in V[] a){ return a.length ? a.vSum*((cast(E)1)/a.length) : V.Null; }
  alias vAvg = vMean;
}


mixin template B2Members(B, V, E){ //BoundsType, VectorType, ElementType
  mixin JsonizeMe;

  @jsonize V bMin=V.Null, bMax=V.Null;

  this(const V v)                   { bMin = bMax = v; }
  this(const V v, E radius)         { this(v); inflate(radius); }
  this(const V mi, const V ma, bool doSort = false)  { bMin = mi; bMax = ma; if(doSort) sortBounds; }
  this(E x0, E y0, E x1, E y1, bool doSort = false)  { bMin = V(x0, y0); bMax = V(x1, y1); if(doSort) sortBounds; }
  this(const V[] v)                 { this = calcBounds(v); }
  this(const B[] b)                 { this = calcBounds(b); }

  this(const int i)                 { enforce(i==0); bMin = bMax = V.Null; } //initializer for sum! template

  bool opEquals()(const B b) const  { return b.bMin==bMin && b.bMax==bMax; }

  bool empty() const                { return bMin.x==bMax.x || bMin.y==bMax.y; }
  bool valid() const                { return bMin.x< bMax.x || bMin.y< bMax.y; }

  enum Null = typeof(this).init;
  bool isNull() const{ return this == typeof(this).init; }

  static calcBounds(const V[] v)  {
    B b;
    if(v.length>0){
      b = B(v[0]);
      foreach(const p; v[1..$]) b.expandToFast(p);
    }
    return b;
  }

  static calcBounds(const B[] a)  {
    B b;
    if(a.length>0){
      b = a[0];
      foreach(const aa; a[1..$]) b.expandToFast(aa);
    }
    return b;
  }


  auto width() const     { return bMax.x-bMin.x; }
  auto height() const    { return bMax.y-bMin.y; }

  auto halfWidth() const { return width*0.5f; }
  auto halfHeight() const{ return height*0.5f; }

  auto size() const      { return bMax - bMin; }
  auto center() const    { return vAvg(bMax, bMin); }
  auto area() const      { return size.x*size.y; }

  auto smallDiameter() const { return min(width, height); }
  auto largeDiameter() const { return max(width, height); }
  auto smallRadius() const { return smallDiameter*0.5f; }
  auto largeRadius() const { return largeDiameter*0.5f; }

/*  alias bMin.x left  , x0, x;
  alias bMin.y top   , y0, y;
  alias bMax.x right , x1;
  alias bMax.y bottom, y1;*/

/*  alias left   = bMin.x;
  alias top    = bMin.y;
  alias right  = bMax.x;
  alias bottom = bMax.y;*/

  auto left  () const { return bMin.x; }   //this seems to be working: const and ref variants in one time
  auto right () const { return bMax.x; }
  auto top   () const { return bMin.y; }
  auto bottom() const { return bMax.y; }

  ref left  () { return bMin.x; }
  ref right () { return bMax.x; }
  ref top   () { return bMin.y; }
  ref bottom() { return bMax.y; }

  alias x0 = left;  alias x = left;
  alias y0 = top;   alias y = top;
  alias x1 = right;
  alias y1 = bottom;

  auto topLeft    () const { return bMin; }                alias v0 = bMin;
  auto topRight   () const { return V(bMax.x, bMin.y); }
  auto bottomLeft () const { return V(bMin.x, bMax.y); }
  auto bottomRight() const { return bMax; }                alias v1 = bMax;

  auto topCenter()    const { return V(center.x, top   ); }
  auto bottomCenter() const { return V(center.x, bottom); }
  auto leftCenter()   const { return V(left , center.y); }
  auto rightCenter()  const { return V(right, center.y); }

  auto distManh(const V p) const { return max(max(left-p.x, p.x-right, 0), max(top-p.y, p.y-bottom, 0)); }
  auto distManh(E x, E y) const { return distManh(V(x, y)); }

  V[] corners() const { return [topLeft, topRight, bottomRight, bottomLeft]; }

  void sortBounds()      { vSort(bMin, bMax); }

  void inflate(const V v)           { bMin -= v;  bMax += v; }
  auto inflated(const V v) const    { B b = this; b.inflate(v); return b; }
  void inflate(E f)                 { V v = {f, f}; inflate(v); }
  auto inflated(E f) const          { V v = {f, f}; return inflated(v); }
  void inflate(E x, E y)            { inflate(V(x, y)); }
  auto inflated(E x, E y) const     { return inflated(V(x, y)); }

  void translate(const V v)         { bMin += v; bMax += v; }
  auto translated(const V v) const  { B b = this; b.translate(v); return b; }

  void translate(E x, E y)          { translate(V(x, y)); }
  auto translated(E x, E y) const   { return translated(V(x, y)); }

  private{
    void expandToFast(const V v)          { if(!minimize(bMin.x, v.x     )) maximize(bMax.x, v.x     );
                                            if(!minimize(bMin.y, v.y     )) maximize(bMax.y, v.y     ); }
    void expandToFast(const B b)          { if(!minimize(bMin.x, b.bMin.x)) maximize(bMax.x, b.bMax.x);
                                            if(!minimize(bMin.y, b.bMin.y)) maximize(bMax.y, b.bMax.y); }
    void expandToFast(const V[] a)        { foreach(const v; a) expandToFast(v); }
  }

  //opt: ez az isFirst megneheziti a dolgokat. Kene valami jobb jelzes a bounds uressegre, pl. NAN bounds.
  void expandTo(const V v, ref bool isFirst)   { if(isFirst){ bMin = bMax = v; isFirst = false; } else expandToFast(v); }
  void expandTo(const B b, ref bool isFirst)   { expandTo(b.bMin, isFirst); expandTo(b.bMax, isFirst); }
  void expandTo(const V[] a, ref bool isFirst) { foreach(const v; a) expandTo(v, isFirst); }

  //todo: rendberakni ezeket a contain, touch, intersect, collide cuccokat.
  bool checkInside(const V v) const        { return inRange(v.x, x0, x1) && inRange(v.y, y0, y1); }
  bool checkInsideRect(const V v) const    { return x0<=v.x && v.x<x1 && y0<=v.y && v.y<y1; }
  bool checkInsideAll(const B b) const     { return checkInside(b.bMin) && checkInside(b.bMax); }
  bool checkInsidePartial(const B b) const { return b.bMin.x <= bMax.x && bMin.x <= b.bMax.x
                                                     && b.bMin.y <= bMax.y && bMin.y <= b.bMax.y; }
  bool checkIntersect(const B b) const { return !(b.bMax.x<bMin.x || bMax.x<b.bMin.x || b.bMax.y<bMin.y || bMax.y<b.bMin.y); }

  /*bool touch(in B b) const{ //intersection.area > 0
    return !(b.x >= x1 || b.x1 <= x || b.y >= y1 || b.y1 <= y);
  }*/

  bool collide(in B b) const{ //intersection.area > 0
    //return !(b.x >= x1 || b.x1 <= x || b.y >= y1 || b.y1 <= y);

    return b.x < x1 && b.x1 > x
        && b.y < y1 && b.y1 > y;
  }

  bool contain(in B b) const{ //the whole b is inside this.
    return b.x  >= x  && b.y  >= y
        && b.x1 <= x1 && b.y1 <= y1;
  }

  B clamp(const B b) const { return B(clamp(b.bMin), clamp(b.bMax)); }
  V clamp(const V v) const { return V(het.utils.clamp(v.x, bMin.x, bMax.x), het.utils.clamp(v.y, bMin.y, bMax.y)); }

  B opBinary(string op)(const B b) const if(op=="+"){ //Union of Bounds
    B tmp = this;  tmp.expandTo(b);  return tmp; }//todo: ezt at kene gondolni jobban

  B opBinary(string op)(const V v) const if(op=="+"){ //Union of Bound and point
    B tmp = this;  tmp.expandTo(v);  return tmp; } //todo: ezt at kene gondolni jobban

  B opOpAssign(string op)(const B b) if(op=="+") { this = this+b; return this; }
  B opOpAssign(string op)(const V v) if(op=="+") { this = this+v; return this; }

  bool lineClip(ref V a, ref V b) const { return _lineClip!(V, E, float)(bMin, bMax, a, b); }

  bool overlapsWith(const B b) const {
    return !clamp(b).empty;
  }

  bool overlapsWith(const B[] bb) const {
    foreach(const b; bb) if(overlapsWith(b)) return true;
    return false;
  }
}

mixin template B3Members(B, V, E){ //BoundsType, VectorType, ElementType
  mixin JsonizeMe;

  @jsonize V bMin=V.Null, bMax=V.Null;

  this(const V v)                   { bMin = bMax = v; }
  this(const V v, E radius)         { this(v); inflate(radius); }
  this(const V mi, const V ma, bool doSort = false)  { bMin = mi; bMax = ma; if(doSort) sortBounds; }
  this(E x0, E y0, E z0, E x1, E y1, E z1, bool doSort = false)  { bMin = V(x0, y0, z0); bMax = V(x1, y1, z1); if(doSort) sortBounds; }
  this(const V[] v)                 { this = calcBounds(v); }
  this(const B[] b)                 { this = calcBounds(b); }

  this(const int i)                 { enforce(i==0); bMin = bMax = V.Null; } //initializer for sum! template

  bool opEquals()(const B b) const  { return b.bMin==bMin && b.bMax==bMax; }

  bool empty() const                { return bMin.x==bMax.x || bMin.y==bMax.y || bMin.z==bMax.z; }

  enum Null = typeof(this).init;
  bool isNull() const{ return this == typeof(this).init; }

  static calcBounds(const V[] v)  {
    B b;
    if(v.length>0){
      b = B(v[0]);
      foreach(const p; v[1..$]) b.expandToFast(p);
    }
    return b;
  }

  static calcBounds(const B[] a)  {
    B b;
    if(a.length>0){
      b = a[0];
      foreach(const aa; a[1..$]) b.expandToFast(aa);
    }
    return b;
  }


  auto width() const     { return bMax.x-bMin.x; }
  auto height() const    { return bMax.y-bMin.y; }
  auto depth() const     { return bMax.z-bMin.z; }

  auto halfWidth() const { return width*0.5f; }
  auto halfHeight() const{ return height*0.5f; }
  auto halfDepth()  const{ return depth*0.5f; }

  auto size() const      { return bMax - bMin; }
  auto center() const    { return vAvg(bMax, bMin); }
  auto area() const      { return size.x*size.y*size.z; }

  auto smallDiameter() const { return min(width, height, depth); }
  auto largeDiameter() const { return max(width, height, depth); }
  auto smallRadius() const { return smallDiameter*0.5f; }
  auto largeRadius() const { return largeDiameter*0.5f; }

/*  alias bMin.x left  , x0, x;
  alias bMin.y top   , y0, y;
  alias bMax.x right , x1;
  alias bMax.y bottom, y1;*/

/*  alias left   = bMin.x;
  alias top    = bMin.y;
  alias right  = bMax.x;
  alias bottom = bMax.y;*/

  auto left  () const { return bMin.x; }   //this seems to be working: const and ref variants in one time
  auto right () const { return bMax.x; }
  auto top   () const { return bMin.y; }
  auto bottom() const { return bMax.y; }
  auto near  () const { return bMin.z; }
  auto far   () const { return bMax.z; }

  ref left  () { return bMin.x; }
  ref right () { return bMax.x; }
  ref top   () { return bMin.y; }
  ref bottom() { return bMax.y; }
  ref near  () { return bMin.z; }
  ref far   () { return bMax.z; }

  alias x0 = left;  alias x = left;
  alias y0 = top;   alias y = top;
  alias z0 = near;  alias z = near;
  alias x1 = right;
  alias y1 = bottom;
  alias z1 = far;

  auto topLeft    () const { return bMin; }                //alias v0 = bMin;
  auto topRight   () const { return V(bMax.x, bMin.y); }
  auto bottomLeft () const { return V(bMin.x, bMax.y); }
  auto bottomRight() const { return bMax; }                //alias v1 = bMax;

  auto topCenter()    const { return V(center.x, top   ); }
  auto bottomCenter() const { return V(center.x, bottom); }
  auto leftCenter()   const { return V(left , center.y); }
  auto rightCenter()  const { return V(right, center.y); }

  auto distManh(const V p) const { return max(max(left-p.x, p.x-right, 0), max(top-p.y, p.y-bottom, 0), max(top-p.z, p.z-bottom, 0)); }
  auto distManh(E x, E y, E z) const { return distManh(V(x, y, z)); }

//  V[] corners() const { return [topLeft, topRight, bottomRight, bottomLeft]; }

  void sortBounds()      { vSort(bMin, bMax); }

  void inflate(const V v)           { bMin -= v;  bMax += v; }
  auto inflated(const V v) const    { B b = this; b.inflate(v); return b; }
  void inflate(E f)                 { V v = {f, f, f}; inflate(v); }
  auto inflated(E f) const          { V v = {f, f, f}; return inflated(v); }
  void inflate(E x, E y, E z)            { inflate(V(x, y, z)); }
  auto inflated(E x, E y, E z) const     { return inflated(V(x, y, z)); }

  void translate(const V v)         { bMin += v; bMax += v; }
  auto translated(const V v) const  { B b = this; b.translate(v); return b; }

  void expandToFast(const V v)          { if(!minimize(bMin.x, v.x     )) maximize(bMax.x, v.x     );
                                          if(!minimize(bMin.y, v.y     )) maximize(bMax.y, v.y     );
                                          if(!minimize(bMin.z, v.z     )) maximize(bMax.z, v.z     ); }
  void expandToFast(const B b)          { if(!minimize(bMin.x, b.bMin.x)) maximize(bMax.x, b.bMax.x);
                                          if(!minimize(bMin.y, b.bMin.y)) maximize(bMax.y, b.bMax.y);
                                          if(!minimize(bMin.z, b.bMin.z)) maximize(bMax.z, b.bMax.z); }

  void expandTo(const V v)          { if(isNull) { bMin = bMax = v; return; }
                                      if(!minimize(bMin.x, v.x     )) maximize(bMax.x, v.x     );
                                      if(!minimize(bMin.y, v.y     )) maximize(bMax.y, v.y     );
                                      if(!minimize(bMin.z, v.z     )) maximize(bMax.z, v.z     ); }
  void expandTo(const B b)          { if(isNull) { this = b; return; }
                                      if(!minimize(bMin.x, b.bMin.x)) maximize(bMax.x, b.bMax.x);
                                      if(!minimize(bMin.y, b.bMin.y)) maximize(bMax.y, b.bMax.y);
                                      if(!minimize(bMin.z, b.bMin.z)) maximize(bMax.z, b.bMax.z); }
  void expandTo(const V[] v)        { auto b = B(v); if(!b.isNull) { if(isNull) this = b; else expandToFast(b); } }

  //todo: rendberakni ezeket a contain, touch, intersect, collide cuccokat.
  bool checkInside(const V v) const        { return inRange(v.x, x0, x1) && inRange(v.y, y0, y1) && inRange(v.z, z0, z1); }
  bool checkInsideAll(const B b) const     { return checkInside(b.bMin) && checkInside(b.bMax); }
  bool checkInsidePartial(const B b) const { return b.bMin.x <= bMax.x && bMin.x <= b.bMax.x
                                                 && b.bMin.y <= bMax.y && bMin.y <= b.bMax.y
                                                 && b.bMin.z <= bMax.z && bMin.z <= b.bMax.z; }
  bool checkIntersect(const B b) const { return !(b.bMax.x<bMin.x || bMax.x<b.bMin.x
                                               || b.bMax.y<bMin.y || bMax.y<b.bMin.y
                                               || b.bMax.z<bMin.y || bMax.z<b.bMin.z); }

  /*bool touch(in B b) const{ //intersection.area > 0
    return !(b.x >= x1 || b.x1 <= x || b.y >= y1 || b.y1 <= y);
  }*/

  bool collide(in B b) const{ //intersection.area > 0
    //return !(b.x >= x1 || b.x1 <= x || b.y >= y1 || b.y1 <= y);

    return b.x < x1 && b.x1 > x
        && b.y < y1 && b.y1 > y
        && b.z < z1 && b.z1 > z;
  }

  bool contain(in B b) const{ //the whole b is inside this.
    return b.x  >= x  && b.y  >= y && b.z  >= z
        && b.x1 <= x1 && b.y1 <= y1 && b.z1 <= z1;
  }

  B clamp(const B b) const { return B(clamp(b.bMin), clamp(b.bMax)); }
  V clamp(const V v) const { return V(het.utils.clamp(v.x, bMin.x, bMax.x), het.utils.clamp(v.y, bMin.y, bMax.y), het.utils.clamp(v.z, bMin.z, bMax.z)); }

  B opBinary(string op)(const B b) const if(op=="+"){ //Union of Bounds
    B tmp = this;  tmp.expandTo(b);  return tmp; }//todo: ezt at kene gondolni jobban

  B opBinary(string op)(const V v) const if(op=="+"){ //Union of Bound and point
    B tmp = this;  tmp.expandTo(v);  return tmp; } //todo: ezt at kene gondolni jobban

  B opOpAssign(string op)(const B b) if(op=="+") { this = this+b; return this; }
  B opOpAssign(string op)(const V v) if(op=="+") { this = this+v; return this; }

  /*auto toPoints(bool clockwise) const
  {
    V[] v = [bMin, V(bMax.x, bMin.y, bMin.z), bMax, V(bMin.x, bMax.y, bMax.z)];
    if(!clockwise) v.retro;
    return v;
  }
  auto toSegs(bool clockwise) const { return toPoints(clockWise).toSegs(true); }*/


  bool lineClip(ref V a, ref V b) const { return _lineClip!(V, E, float)(bMin, bMax, a, b); }

  bool overlapsWith(const B b) const {
    return !clamp(b).empty;
  }

  bool overlapsWith(const B[] bb) const {
    foreach(const b; bb) if(overlapsWith(b)) return true;
    return false;
  }
}

mixin template B2FMembers(B, V, E){ //BoundsType, VectorType, ElementType
  auto toI() const { return Bounds2i(ifloor(bMin.x), ifloor(bMin.y), iceil(bMax.x), iceil(bMax.y)); }
}

mixin template B2IMembers(B, V, E){ //BoundsType, VectorType, ElementType
  auto toF() const { return Bounds2f(bMin.x, bMin.y, bMax.x, bMax.y); }
  auto toD() const { return Bounds2d(bMin.x, bMin.y, bMax.x, bMax.y); }
}

mixin template B3FMembers(B, V, E){ //BoundsType, VectorType, ElementType
  auto toI() const { return Bounds3i(ifloor(bMin.x), ifloor(bMin.y), ifloor(bMin.z), iceil(bMax.x), iceil(bMax.y), iceil(bMax.z)); }
}

mixin template B3IMembers(B, V, E){ //BoundsType, VectorType, ElementType
  auto toF() const { return Bounds3f(bMin.x, bMin.y, bMin.z, bMax.x, bMax.y, bMax.z); }
  auto toD() const { return Bounds3d(bMin.x, bMin.y, bMin.z, bMax.x, bMax.y, bMax.z); }
}

/// Vector/Bounds/Matrix declarations ///////////////////////////////////////////////////////
public:

struct V2i { mixin V2IntMembers  !(V2i, int   ); } mixin V2IntFuncts  !(V2i, int   );
struct V2f { mixin V2FloatMembers!(V2f, float ); } mixin V2FloatFuncts!(V2f, float );
struct V2d { mixin V2FloatMembers!(V2d, double); } mixin V2FloatFuncts!(V2d, double);

struct Bounds2i { mixin B2Members!(Bounds2i, V2i, int   ); mixin B2IMembers!(Bounds2i, V2i, float ); }
struct Bounds2f { mixin B2Members!(Bounds2f, V2f, float ); mixin B2FMembers!(Bounds2f, V2f, float ); }
struct Bounds2d { mixin B2Members!(Bounds2d, V2d, double); mixin B2FMembers!(Bounds2d, V2d, double); }

struct V3i { mixin V3IntMembers  !(V3i, int   ); } mixin V3IntFuncts  !(V3i, int   );
struct V3f { mixin V3FloatMembers!(V3f, float ); } mixin V3FloatFuncts!(V3f, float );
struct V3d { mixin V3FloatMembers!(V3d, double); } mixin V3FloatFuncts!(V3d, double);

struct Bounds3i { mixin B3Members!(Bounds3i, V3i, int   ); mixin B3IMembers!(Bounds3i, V3i, float ); }
struct Bounds3f { mixin B3Members!(Bounds3f, V3f, float ); mixin B3FMembers!(Bounds3f, V3f, float ); }
struct Bounds3d { mixin B3Members!(Bounds3d, V3d, double); mixin B3FMembers!(Bounds3d, V3d, double); }


V2f xy(in V3f v){ return V2f(v.x, v.y); } //swizzles
+/

struct seg2 { //todo: make a Segment template struct
  vec2[2] p;
  alias p this;

  this(in vec2 a, in vec2 b) { p = [a, b]; }
  this(float x0, float y0, float x1, float y1) { this(vec2(x0, y0), vec2(x1, y1)); }

  vec2 diff() const { return p[1]-p[0]; }
  float length() const { return .length(diff); }
  vec2 dir() const { return diff*(1/length); }
}

auto toSegs(in vec2[] p, bool circular){ //todo: rewrite with functional.slide
  seg2[] res;
  res.reserve(p.length);
  if(p.length<=1) return res;
  foreach(i; 0..p.length-1+(circular ? 1 : 0)){
    auto j = i+1;
    if(j == p.length) j = 0;
    res ~= seg2(p[i], p[j]);
  }
  return res;
}

auto toPoints(in bounds2 bnd, bool clockwise=true){ with(bnd){
  auto res = [low, vec2(high.x, low.y), high, vec2(low.x, high.y)];
  return clockwise ? res
                   : res.retro.array;
}}

auto toSegs(in bounds2 bnd, bool clockwise=true) { return bnd.toPoints(clockwise).toSegs(true); }


//todo: these should be done with CTCG
bounds2 inflated(in bounds2 b, in vec2 v){  return b.valid ? bounds2(b.low-v, b.high+v) : bounds2.init; } //todo: support this for all bounds
bounds2 inflated(in bounds2 b, in float x, in float y){  return b.inflated(vec2(x, y)); }
bounds2 inflated(in bounds2 b, float f){  return b.inflated(f, f); } //todo: support this for all bounds

bounds2 inflated(in ibounds2 b, in vec2 v){  return b.valid ? bounds2(b.low-v, b.high+v) : bounds2.init; } //todo: support this for all bounds
bounds2 inflated(in ibounds2 b, in float x, in float y){  return b.inflated(vec2(x, y)); }
bounds2 inflated(in ibounds2 b, float f){  return b.inflated(f, f); } //todo: support this for all bounds

ibounds2 inflated(in ibounds2 b, in ivec2 v){ return b.valid ? ibounds2(b.low-v, b.high+v) : ibounds2.init; } //todo: support this for all bounds
ibounds2 inflated(in ibounds2 b, int x, int y){ return b.inflated(ivec2(x, y)); } //todo: support this for all bounds
ibounds2 inflated(in ibounds2 b, int a){ return b.inflated(a, a); } //todo: support this for all bounds

auto fittingSquare(in bounds2 b){
  auto diff = (b.size.x-b.size.y)*0.5f;
  if(diff<0) return b.inflated(0    , diff);
        else return b.inflated(-diff,    0);
}

// float - int combinations ///////////////////////////////////////

////////////////////////////////////////////////////////////////////////////////////////////
///  Graphics algorithms                                                                 ///
////////////////////////////////////////////////////////////////////////////////////////////

///  Intersections, primitive distances  ///////////////////////////////////////////////////

vec2 intersectLines_noParallel_prec(in seg2 S0, in seg2 S1)  //todo: all of these variation should be refactored with static ifs.
{
  auto S     = S1.p[0]-S0.p[0],
       T     = S0.p[1]-S0.p[0],
       U     = S1.p[0]-S1.p[1],
       det   = crossZ(T, U),
       detA  = crossZ(S, U),
       alpha = detA/det;        //opt: alpha = detA*rcpf_fast(det);

  return S0.p[0]+T*alpha;
}

bool intersectSegs_noParallel_prec(in seg2 S0, in seg2 S1, ref vec2 P){
  vec2 S = S1.p[0]-S0.p[0],
      T = S0.p[1]-S0.p[0],
      U = S1.p[0]-S1.p[1];
  float det  = crossZ(T, U),
        detA = crossZ(S, U);

  if(inRange_sorted(detA, 0.0f, det)){  //have one intersection
    float detB = crossZ(T, S);
    if(inRange_sorted(detB, 0.0f, det)){

      float alpha = detA/det;
      //alpha = detA*rcpf_fast(det); //rather not
      P = S0.p[0]+T*alpha;

      return true;
    }
  }
  return false;
}

bool intersectSegs_noParallel_prec(in seg2 S0, in seg2 S1){
  vec2 S = S1.p[0]-S0.p[0],
      T = S0.p[1]-S0.p[0],
      U = S1.p[0]-S1.p[1];
  float det  = crossZ(T, U),
        detA = crossZ(S, U);

  if(inRange_sorted(detA, 0.0f, det)){  //have one intersection
    float detB = crossZ(T, S);
    if(inRange_sorted(detB, 0.0f, det)){
      float alpha = detA/det;
      return true;
    }
  }
  return false;
}

bool intersectSegs_falseParallel_prec(in seg2 S0, in seg2 S1){
  vec2 S = S1.p[0]-S0.p[0],
      T = S0.p[1]-S0.p[0],
      U = S1.p[0]-S1.p[1];
  float det  = crossZ(T, U);

  if(abs(det)<0.001f) return false;  //todo: this is lame

  float detA = crossZ(S, U);

  if(inRange_sorted(detA, 0.0f, det)){  //have one intersection
    float detB = crossZ(T, S);
    if(inRange_sorted(detB, 0.0f, det)){
      float alpha = detA/det;
      return true;
    }
  }
  return false;
}

float segmentPointDistance_prec(const vec2 v, const vec2 w, const vec2 p){
  // Return minimum distance between line segment vw and point p
  const l2 = sqrLength(v-w);    // i.e. |w-v|^2 -  avoid a sqrt
  if (!l2) return distance(p, v); // v == w case
  // Consider the line extending the segment, parameterized as v + t (w - v).
  // We find projection of point p onto the line.
  // It falls where t = [(p-v) . (w-v)] / |w-v|^2
  // We clamp t from [0,1] to handle points outside the segment vw.
  const t = max(0, min(1, dot(p - v, w - v) / l2));
  const projection = v + (w - v)*t;  // Projection falls on the segment
  return distance(p, projection);
}

//todo: segmentPointDistance 3d
/*
  vec3 segmentNearestPoint(vec3 S0, vec3 S1, vec3 P){
    vec3 v = S1 - S0;
    vec3 w = P - S0;

    float c1 = dot(w,v);
    if(c1<=0.0) return S0;

    float c2 = dot(v,v);
    if(c2<=c1) return S1;

    float b = c1 / c2;
    vec3 Pb = S0 + b * v;
    return Pb;
  }


  float segmentPointDistance(vec3 S0, vec3 S1, vec3 P){
    return distance(P, segmentNearestPoint(S0, S1, P));
  }
*/

///  Cohen Sutherland line-rect Clipping ///////////////////////////////////////////////////////////////
///  Ported to Delphi from wikipedia C code by Omar Reis - 2012                          ///
///  Ported back to C by realhet 2013, lol                                               ///
///  Ported finally to D by realhet 2016, lol**2                                         ///

bool _lineClip(V, E, F)(in V bMin, in V bMax, ref V a, ref V b)
{
  const INSIDE = 0, // 0000
        LEFT   = 1, // 0001
        RIGHT  = 2, // 0010
        BOTTOM = 4, // 0100
        TOP    = 8; // 1000

  int computeOutCode(const V v) const{
    int res = INSIDE; // initialised as being inside of clip window

    if(v.x < bMin.x) res |= LEFT;         // to the left of clip window
      else if(v.x > bMax.x) res |= RIGHT; // to the right of clip window

    if(v.y < bMin.y) res |= BOTTOM;       // below the clip window
      else if(v.y > bMax.y) res |= TOP;   // above the clip window

    return res;
  }

  // compute outcodes for P0, P1, and whatever point lies outside the clip rectangle
  int outcode0 = computeOutCode(a);
  int outcode1 = computeOutCode(b);
  while(1){
    if((outcode0 | outcode1)==0){ // Bitwise OR is 0. Trivially result and get out of loop
      return true;
    }else if(outcode0 & outcode1){ // Bitwise AND is not 0. Trivially reject and get out of loop
      return false;
    }else{
      // failed both tests, so calculate the line segment to clip
      // from an outside point to an intersection with clip edge
      // At least one endpoint is outside the clip rectangle; pick it.
      int outcodeOut = outcode0 ? outcode0 : outcode1;
      // Now find the intersection point;
      // use formulas y = a.y + slope * (x - a.x), x = a.x + (1 / slope) * (y - a.y)
      F x,y;
      if(outcodeOut & TOP){           // point is above the clip rectangle
        x = a.x + (b.x - a.x) * (bMax.y - a.y) / (b.y - a.y);
        y = bMax.y;
      }else if(outcodeOut & BOTTOM){  // point is below the clip rectangle
        x = a.x + (b.x - a.x) * (bMin.y - a.y) / (b.y - a.y);
        y = bMin.y;
      }else if(outcodeOut & RIGHT){  // point is to the right of clip rectangle
        y = a.y + (b.y - a.y) * (bMax.x - a.x) / (b.x - a.x);
        x = bMax.x;
      }else /*if(outcodeOut & LEFT)*/{   // point is to the left of clip rectangle
        y = a.y + (b.y - a.y) * (bMin.x - a.x) / (b.x - a.x);
        x = bMin.x;
      }

      /* NOTE:if you follow this algorithm exactly(at least for c#), then you will fall into an infinite loop
      in case a line crosses more than two segments. to avoid that problem, leave out the last else
      if(outcodeOut & LEFT) and just make it else */

      // Now we move outside point to intersection point to clip
      // and get ready for next pass.
      if(outcodeOut==outcode0){
        a.x = cast(E)x;
        a.y = cast(E)y;
        outcode0 = computeOutCode(a);
      }else{
        b.x = cast(E)x;
        b.y = cast(E)y;
        outcode1 = computeOutCode(b);
      }
    }
  }
}//lineClip()

///  Bresenham line drawing /////////////////////////////////////////////////////////////////////

void line_bresenham(in ivec2 a, in ivec2 b, bool skipFirst, void delegate(in ivec2) dot){
  auto d = b-a,
       d1 = abs(d),
       p = ivec2(2*d1.y-d1.x,
                 2*d1.x-d1.y),
       i = (d.x<0)==(d.y<0) ? 1 : -1;
  d1 *= 2;

  void dot2(in ivec2 p){ if(!skipFirst || p!=a) dot(p); }

  int e; ivec2 v;
  if(d1.y<=d1.x){
    if(d.x>=0){ v=a; e=b.x; }
          else{ v=b; e=a.x; }
    dot2(v);
    while(v.x<e){
      ++v.x;
      if(p.x<0){ p.x += d1.y;                 }
           else{ p.x += d1.y-d1.x;  v.y += i; }
      dot2(v);
    }
  }else{
    if(d.y>=0){ v=a; e=b.y; }
          else{ v=b; e=a.y; }
    dot2(v);
    while(v.y<e){
      ++v.y;
      if(p.y<0){ p.y += d1.x;                 }
           else{ p.y += d1.x-d1.y;  v.x += i; }
      dot2(v);
    }
  }
}

/// Nearest finders ///////////////////////////////////////////////////////////////

int distManh(in ibounds2 b, in ivec2 p){
  with(b) return max(max(left-p.x, p.x-right, 0), max(top-p.y, p.y-bottom, 0));
}

auto findNearestManh(in ibounds2[] b, in ivec2 p){
  auto idx = b.map!(r => r.distManh(p)).array.minIndex;
  if(idx<0) return ibounds2();
       else return b[idx];
}

auto findNearestManh(ibounds2[] b, in ivec2 p, int maxDist, int* actDist=null){
  auto idx = b.map!(r => r.distManh(p)).array.minIndex;
  if(idx<0){
    if(actDist) *actDist = int.max;
    return ibounds2();
  }else{
    int d = b[idx].distManh(p);
    if(actDist) *actDist = d;
    if(d>maxDist) return ibounds2();
             else return b[idx];
  }
}

// Linear fit ///////////////////////////////////////////////////////////////////////

struct LinearFitResult{
  vec2[] points;
  float slope=0;
  float intercept=0;

  float deviation = 0;
  int worstIdx = -1;
  bool isGood; //optimizer fills it

  bool isNull() const{ return !slope && !intercept; }

  float y(float x){ return intercept+x*slope; }
}

auto linearFit(in vec2[] data){
  auto xSum  = data.map!"a.x".sum,
       ySum  = data.map!"a.y".sum,
       xxSum = data.map!"a.x*a.x".sum,
       xySum = data.map!"a.x*a.y".sum,
       len = data.length.to!float;

  LinearFitResult res;

  if(data.length>=2){
    res.points = data.dup;
    res.slope = (len*xySum - xSum*ySum) / (len * xxSum - xSum * xSum);
    res.intercept = (ySum - res.slope * xSum) / len;
  }else{
    if(data.length==1){
      res.intercept = data[0].y;
    }else{
      return res;
    }
  }

  auto error(in vec2 p){ return res.y(p.x)-p.y; }
  res.deviation = sqrt(data.map!(p => error(p)^^2).sum/(data.length.to!int-1));
  res.worstIdx = data.map!(p => abs(error(p))).maxIndex.to!int;

  return res;
}

auto linearFit(in vec2[] data, int requiredPoints, float maxDeviation){
  auto fit = linearFit(data);

  while(1){
    fit.isGood = fit.points.length>=requiredPoints && fit.deviation<maxDeviation;
    if(fit.isGood) break;
    if(fit.points.length<=requiredPoints) break;
    fit = linearFit(fit.points.remove(fit.worstIdx));
  }

  return fit;
}

// Quadratic fit ///////////////////////////////////////////////////////////////////////

struct QuadraticFitResult{    //todo: combine Quadratic and linear fitter
  vec2[] points;
  float a=0, b=0, c=0;

  float deviation = 0;
  int worstIdx = -1;
  bool isGood; //optimizer fills it

  bool isNull() const{ return !a && !b && !c; }

  float y(float x){ return a*x^^2 + b*x + c; }
}

private float det(float a, float b, float c, float d){ return a*d-c*b; }
private float det(float a, float b, float c, float d, float e, float f, float g, float h, float i){
  return +a*det(e, f, h, i)
         -d*det(b, c, h, i)
         +g*det(b, c, e, f);
}

auto quadraticFit(in vec2[] data){
  QuadraticFitResult res;
  if(data.length<3){
    if(data.length==2){
      auto lin = linearFit(data); //get it from linear
      res.b = lin.slope;
      res.c = lin.intercept;
      res.deviation = lin.deviation;
      res.worstIdx = lin.worstIdx;
    }
    return res;
  }

  //https://www.codeproject.com/Articles/63170/Least-Squares-Regression-for-Quadratic-Curve-Fitti
  //notation sjk to mean the sum of x_i^j*y_i^k.
  //todo: optimize this with .tee or something to access x and y only once
  float s40 = data.map!"a.x^^4".sum, //sum of x^4
        s30 = data.map!"a.x^^3".sum, //sum of x^3
        s20 = data.map!"a.x^^2".sum, //sum of x^2
        s10 = data.map!"a.x".sum,    //sum of x
        s00 = data.length,           //sum of x^0 * y^0  ie 1 * number of entries
        s21 = data.map!"a.x^^2*a.y".sum, //sum of x^2*y
        s11 = data.map!"a.x*a.y".sum,  //sum of x*y
        s01 = data.map!"a.y".sum;    //sum of y

  auto D = det(s40, s30, s20,
               s30, s20, s10,
               s20, s10, s00);
  res.a  = det(s21, s30, s20,
               s11, s20, s10,
               s01, s10, s00)/D;
  res.b  = det(s40, s21, s20,
               s30, s11, s10,
               s20, s01, s00)/D;
  res.c  = det(s40, s30, s21,
               s30, s20, s11,
               s20, s10, s01)/D;

  res.points = data.dup;

  //copied from lin
  auto error(in vec2 p){ return res.y(p.x)-p.y; }
  res.deviation = sqrt(data.map!(p => error(p)^^2).sum/(data.length.to!int-1));
  res.worstIdx = data.map!(p => abs(error(p))).maxIndex.to!int;

  return res;
}


////////////////////////////////////////////////
///  GLSL compatible stuff                   ///
////////////////////////////////////////////////
/+
/*template isFloadVec (T){ enum isFloatVec  = is(T==V2f) || is(T==V3f) || is(T==V4f); }
template isDoubleVec(T){ enum isDoubleVec = is(T==V2d) || is(T==V3d) || is(T==V4d); }
template isIntVec   (T){ enum isIntVec    = is(T==V2i) || is(T==V3i) || is(T==V4i); }
template isUintVec  (T){ enum isUintVec   = is(T==V2u) || is(T==V3u) || is(T==V4u); }

template isVec2     (T){ enum isVec2 = is(T==V2f) || is(T==V2f) || is(T==V2i) || is(T==V2u); }
template isVec3     (T){ enum isVec3 = is(T==V3f) || is(T==V3f) || is(T==V3i) || is(T==V3u); }
template isVec4     (T){ enum isVec4 = is(T==V4f) || is(T==V4f) || is(T==V4i) || is(T==V4u); }*/


template isVec2     (T){ enum isVec2 = is(T==V2f) || is(T==V2d) || is(T==V2i); }
template isVec3     (T){ enum isVec3 = is(T==V3f) || is(T==V3d) || is(T==V3i); }

/*
This fucks up things
import std.math: sqrt;
float sqrt(int a){ return sqrt(float(a)); } //dlang patch: (int) matches both: (float), (real)
*/

auto dot(V)(in V p) if(isVec2!V){ return p.x*p.x + p.y*p.y; }
auto dot(V)(in V p) if(isVec3!V){ return p.x*p.x + p.y*p.y + p.z*p.z; }

auto length(V)(in V p) if(isVec2!V) { return sqrt(p.x^^2 + p.y^^2); }
auto length(V)(in V p) if(isVec3!V) { return sqrt(p.x^^2 + p.y^^2 + p.z^^2); }

auto distance(V0, V1)(in V0 p0, in V1 p1) if(isVec2!V0 && isVec2!V1) { return sqrt((p0.x-p1.x)^^2 + (p0.y-p1.y)^^2); } //note: azert van igy kiirva, mert a subtract az meg nem jo barmilyen tipusra.
auto distance(V0, V1)(in V0 p0, in V1 p1) if(isVec3!V0 && isVec3!V1) { return sqrt((p0.x-p1.x)^^2 + (p0.y-p1.y)^^2 + (p0.z-p1.z)^^2); }

auto distance(V0, V1)(in V0 p, in V1[] a) if(isVec2!V0 && isVec2!V1 || isVec3!V0 && isVec3!V1) { return a.map!(e => distance(e, p)).minElement; }
  auto distance(V0, V1)(in V0[] a, in V1 p) if(isVec2!V0 && isVec2!V1 || isVec3!V0 && isVec3!V1) { return distance(p, a); }

auto distance(in Seg2f s, in V2f p){ return segmentPointDistance_prec(s.p[0], s.p[1], p); }
  auto distance(in V2f p, in Seg2f s){ return distance(s, p); }

auto distance(in Seg2f[] a, in V2f p){ return a.map!(s => distance(s, p)).minElement; }
  auto distance(in V2f p, in Seg2f[] a){ return distance(a, p); }


float rectPointSignedDistance(in V2f tl, in V2f br, in V2f uv){ //https://stackoverflow.com/questions/30545052/calculate-signed-distance-between-point-and-rectangle
  auto d = vMax(tl-uv, uv-br);
  return length(vMax(V2f(0, 0), d)) + min(0.0, max(d.x, d.y));
}

auto distance(in Bounds2f b, in V2f p){ return rectPointSignedDistance(b.bMin, b.bMax, p); }
  auto distance(in V2f p, in Bounds2f b){ return distance(b, p); }


  +/