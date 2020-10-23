module het.math;

// This module replaces and extends the interface of std.math.
// Anything usefull in std.math should wrapped here to support vector/scalar operations.
// This is to ensure, that there will be no conflicting orevload sets between this module and std.math.
//
// Notes:
// Avoid importing std.moth in projects, or else it will lead to ambiguity errors because the function names are the same.
// Don't use het.utils in this module, het.utils will use this and publicly import this.

// imports ///////////////////////////////////////////

// static import because all imported and extended names must be fully qualified.
static import std.math;

// important constants from std.math
public import std.math : E, PI;  enum Ef = float(E), PIf = float(PI);
public import std.math: NaN, getNaNPayload, hypot, evalPoly = poly;

// publicly import std modules whose functions are gonna be overloaded/extended/hijacked here.
public import std.algorithm; //extends: cmp, any, all, equal, min, max

public import std.functional; //extends: lessThan, greaterThan, not

// import locally used things.     //must not import het.utils to keep it simle and standalone
import std.format : format;
import std.conv : text, stdto = to;
import std.uni : toLower;
import std.array : replicate, split, replace, join;
import std.range : iota, isInputRange, ElementType, front;
import std.traits : Unqual, isDynamicArray, isStaticArray, isNumeric, isSomeString, isIntegral, isUnsigned, isFloatingPoint, stdCommonType = CommonType;
import std.meta : AliasSeq;

import std.exception : enforce;
import std.stdio : write, writeln;


// utility stuff ////////////////////////////////////////////////////

private enum approxEqualDefaultDiff = 1e-3f;

//todo: std.conv.to is flexible, but can be slow, because it calls functions and it checks value ranges. Must be tested and optimized if needed with own version.
alias myto(T) = stdto!T;
//auto myto(T)(in T a){ return cast(T) a; }

private enum swizzleRegs = ["xyzw", "rgba", "stpq"];

private enum ComponentTypePrefix(CT) = is(CT==float ) ? "" :  //rgb and rgba handled specially
                                       is(CT==double) ? "d" :
                                       is(CT==bool  ) ? "b" :
                                       is(CT==int   ) ? "i" :
                                       is(CT==uint  ) ? "u" :
                                       "UNDEF";

private bool validRvalueSwizzle(string def){
  if(def.startsWith('_')) return validRvalueSwizzle(def[1..$]); //_ is allowed at the start because of the constants 0 and 1

  if(!def.length.inRange(1, 4)) return false; //too small or too long

  //LvalueSwizzles are not included. Those are midex in.  (LValue swizzle examples: x, xy, yzw, those that stay on a contiguous memory area)
  if(swizzleRegs.map!(r => r.canFind(def)).any) return false;

  return swizzleRegs.map!(r => def.map!(ch => "01".canFind(ch) || r.canFind(ch.toLower)).all).any;
}


enum isVector(T) = is(T) && is(T.VectorType);

private bool anyVector(T...)(){
  static foreach(t; T)
    static if(isVector!t) return true;
  return false;
}

private int FirstVectorLength(T...)(){
  static foreach(t; T)
    static if(isVector!t) return cast(int) t.length;
  return 0;
}

private template CommonType(A...){
  //todo: ubyte + ushort should be ushort, not int
  alias CommonType = stdCommonType!(A);
}

private template OperationResultType(string op, A, B){
  static if(op.among("<<", ">>", ">>>")) alias OperationResultType = A; //for shift operation only the left operand counts
  else alias OperationResultType = CommonType!(A, B);
}

/// T is a combination of vector and scalar parameters
/// returns the common vector length if there is one, otherwise stops with an assert;
private int CommonVectorLength(T...)(){
  static if(!T.length) return 0;
  static if(!anyVector!T) return 1; // assume all are scalar
  enum len = FirstVectorLength!T;
  static foreach(t; T)
    static assert(!isVector!t || t.length==len, "vector dimension mismatch");
  return len;
}

private template ScalarType(T){
       static if(isVector!T) alias A = T.ComponentType;
  else static if(isMatrix!T) alias A = T.ComponentType;
  else                       alias A = T;

  alias ScalarType = Unqual!A;
}

private template CommonScalarType(T...){
  static assert(T.length>=1);
  static if(T.length==1) alias CommonScalarType = ScalarType!(T[0]);
                    else alias CommonScalarType = CommonType!(ScalarType!(T[0]), CommonScalarType!(T[1..$]));
}

private alias CommonVectorType(Types...) = Vector!(CommonScalarType!Types, CommonVectorLength!Types);

/// helper to access scalar and vector components in arguments.
private auto vectorAccess(int idx, T)(in T a){
  static if(isVector!T) return a[idx];
                   else return a;
}

private void unittest_utilityStuff(){
  assert(validRvalueSwizzle("_01yx") && validRvalueSwizzle("bgr1"));
  assert(!validRvalueSwizzle("xy")); //false: this is Lvalue swizzle
  assert(!validRvalueSwizzle("xa")); //false: mixture of divverent swizzle variables

  assert(!anyVector!(int, float) && anyVector!(float, vec2));
  assert(FirstVectorLength!(float, vec3)==3 && FirstVectorLength!(float, int)==0);
  assert(CommonVectorLength!()==0 && CommonVectorLength!(int)==1 && CommonVectorLength!(int, vec3)==3);

  assert(is(CommonScalarType!(int, float, dvec3, mat2)==double));

  assert(vectorAccess!2(5)==5 && vectorAccess!2(vec3(1,2,3))==3);
}

////////////////////////////////////////////////////////////////////////////////
///  Vector                                                                  ///
////////////////////////////////////////////////////////////////////////////////

struct Vector(CT, int N)
if(N.inRange(2, 4)){
  alias VectorType = typeof(this);
  alias ComponentType = CT;
  enum VectorTypeName = is(VectorType==Vector!(ubyte, 3)) ? "RGB" :
                        is(VectorType==Vector!(ubyte, 4)) ? "RGBA" :
                        ComponentTypePrefix!CT != "UNDEF" ? ComponentTypePrefix!CT ~ "vec" ~ N.stringof
                                                          : VectorType.stringof;

  CT[N] components = [0].replicate(N); //default is 0,0,0, not NaN.  Just like in GLSL.
  enum length = N;

  alias components this;

  //note : alias this enables inplicit conversion, but fucks up the ~ concat operator
  //ref auto opIndex(size_t i){ return components[i]; } const opIndex(size_t i){ return components[i]; }

  string toString() const { return VectorTypeName ~ "(" ~ components[].map!text.join(", ") ~ ")"; }

  private void construct(int i, T, Tail...)(in T head, in Tail tail){ // this is based on the gl3n package
    static if(i >= length){
      static assert(false, "Vector constructor: Too many arguments");
    }else static if(isDynamicArray!T) {
      static assert((Tail.length == 0), "Vector constructor: Dynamic array can only be the last argument");
      enforce(i+head.length <= components.length, "Vector constructor: Dynamic array too large");
      components[i..i+head.length] = head[].myto!(CT[]);
      //further construction stops
    }else static if(isStaticArray!T){
      static foreach(j; 0..head.length) components[i+j] = head[j].myto!CT;
      construct!(i + head.length)(tail);
    }else static if(isVector!T){ //another vec
      construct!i(head.components, tail);
    }else static if(isNumeric!T){
      components[i] = head.myto!CT;
      construct!(i+1)(tail);
    }else static if(is(T==bool)){
      components[i] = head ? 1 : 0;
      construct!(i+1)(tail);
    }else{
      //todo: it sometimes give this as false error
      static assert(false, "Vector constructor: Unable to process argument of type: " ~ T.stringof);
    }
  }

  private void construct(int i)() {
    static assert(i == length, "Vector constructor: Not enough arguments"); //todo: show the error's place in source: __ctor!(int, int, int)
  }

  this(A...)(in A args){

    void setAll(T)(in T a){ components[] = a.myto!CT; }

    static if(is(ComponentType==ubyte) && args.length==1 && (is(A[0]==int) || is(A[0]==uint) || isSomeString!(A[0]))){
      //special case for RG, RGB and RGBA: decodes it from one value
      static if(isSomeString!(A[0])){
        static assert("not impl");
      }else static if(is(A[0]==int) || is(A[0]==uint)){
        // raw data copy
        //todo: kulonvalasztani a compile time es a runtime konvertalast. Ha egyaltalan lehet.
        //runtime: components = *(cast(typeof(components)*) &(args[0]));

        //CTFE version
        //todo: put this in a loop
        //static foreach(i; 0..length) components[i] == 128;//cast(ubyte)(((args[0]>>(i*8)) & 0xFF));
        static if(length==2){ components = [args[0]&0xFF, (args[0]>>>8)&0xFF]; }
        static if(length==3){ components = [args[0]&0xFF, (args[0]>>>8)&0xFF, (args[0]>>>16)&0xFF]; }
        static if(length==4){ components = [args[0]&0xFF, (args[0]>>>8)&0xFF, (args[0]>>>16)&0xFF, args[0]>>>24]; }
      }else{
        static assert(0, "unhandler type: "~(A[0]).stringof);
      }
      // if the above version would be not ok... -> static foreach(i; 0..length) components[i] = cast(ubyte) args[0]>>(i*8);
    }else static if(args.length==1 && __traits(compiles, setAll(args[0]))){
      //One can also use one number in the constructor to set all components to the same value
      setAll(args[0]);
    }else static if(args.length==1 && isVector!(A[0]) && A[0].length>=length){
      //Casting a higher-dimensional vector to a lower-dimensional vector is also achieved with these constructors:
      static foreach(i; 0..length) components[i] = args[0].components[i].myto!CT;
    }else{
      construct!0(args);
    }
  }

  bool opEquals(T)(in T other) const {
    static if(isVector!T){ // vector==vector
      static assert(T.length == length);
      static if(__traits(compiles, components==other.components))
        return other.components == components;
      else
        return components.equal(other.components);
    }else static if(__traits(compiles, components[0]==other)){ // vector==scalar
      return components[0]==other;
    }else static assert("Incompatible types: "~typeof(this).stringof~" and "~T.stringof);
  }

  // raw data access for ubyte vectors.
  static if(is(ComponentType==ubyte)){
    static if(length==4){

          uint raw() const { return *(cast(uint*) &components); }
      ref uint raw()       { return *(cast(uint*) &components); }

    }else{

      @property uint raw() const{
        uint data = 0x00000000;
        *(cast(Unqual!(typeof(components))*) &data) = components;
        return data;
      }

      @property void raw(uint data){
        components = *(cast(Unqual!(typeof(components))*) &data);
      }

    }
  }

  static auto basis(int n){ VectorType v;  v[n] = ComponentType(1);  return v; }

  // swizzling ///////////////////////

  static foreach(regs; swizzleRegs)
    static foreach(len; 1..N+1)
      static foreach(i; 0..N-len+1)
        static if(len==1){
          mixin(format!q{auto %s() const { return components[%s]; }}(regs[i], i));
          mixin(format!q{ref  %s()       { return components[%s]; }}(regs[i], i));
        }else{
          mixin(format!q{auto %s() const { return        Vector!(CT, %s)   (components[%s..%s]) ; }}(regs[i..i+len], len, i, i+len));
          mixin(format!q{ref  %s()       { return *(cast(Vector!(CT, %s)*) (components[%s..%s])); }}(regs[i..i+len], len, i, i+len));
        }

  private template swizzleDecode(char ch){
    enum lowerCh = ch.toLower;
    enum isLower = ch==lowerCh;
    static if(is(ComponentType==ubyte)){
      //for ubyte: 1 means 255, UpperCase means 255^
      enum swizzleDecode = ch=='1' ? "255" : cast(string)[lowerCh] ~ (isLower ? "" : "^255");
    }else{
      enum swizzleDecode = (isLower ? "" : "-") ~ cast(string)[lowerCh];
    }
  }

  auto opDispatch(string def)() const
  if(validRvalueSwizzle(def))
  {
    static if(def.startsWith('_')){
      return opDispatch!(def[1..$]);
    }else{
      static if(def.length==1){ // Scalar value output
        return mixin( swizzleDecode!(def[0]) );
      }else{
        Vector!(CT, mixin(def.length)) res; // vector output
        static foreach(i, ch; def)
          res[i] = mixin( swizzleDecode!ch );
        return res;
      }
    }
  }

  auto opUnary(string op)() const{
    VectorType res;
    static foreach(i; 0..length) mixin(format!"res[%s] = %s this[%s];"(i, op, i));
    return res;
  }

  auto opUnary(string op)() if(op.among("++", "--")) {  //this one is NOT const
    VectorType res;
    static foreach(i; 0..length) mixin(format!"res[%s] = %s this[%s];"(i, op, i));
    return res;
  }

  private static binaryVectorScalarOp(string op, A, B)(in A a, in B b){
    alias CT = OperationResultType!(op, ScalarType!A, ScalarType!B);
    return generateVector!(CT, (a, b) => mixin("a", op, "b") )(a, b);
  }

  auto opBinary(string op, T)(in T other) const
  {
    static if(isNumeric!T || isVector!T){ // vector * (vector/scalar)
      return binaryVectorScalarOp!op(this, other);
    }else static if(op=="*" && isMatrix!T && T.height==length){ // vector * matrix
      return other.transpose * this;
    }else static if(op=="in" && isBounds!T && T.VectorLength == length){
      return other.contain(this);
    }else{
      static assert(false, "invalid operation");
    }
  }

  auto opBinaryRight(string op, T)(in T other) const
  {
    static if(isNumeric!T) return generateVector!(CommonScalarType!(VectorType, T), (a, b) => mixin("a", op, "b") )(other, this);
                      else static assert(0, "invalid operation");
  }

  auto opOpAssign(string op, T)(in T other){
    this = mixin("this", op, "other");
    return this;
  }

  bool approxEqual(T)(in T other, float maxDiff = approxEqualDefaultDiff) const{
    static assert(isVector!T && T.length==length);
    static foreach(i; 0..length) if(abs(this[i]-other[i]) > maxDiff) return false; //todo: refact
    return true;
  }

}

private alias vectorElementTypes = AliasSeq!(float, double, bool, int, uint);
private enum vectorElementCounts = [2, 3, 4];

static foreach(T; vectorElementTypes)
  static foreach(N; vectorElementCounts)
    mixin(format!q{alias %s = %s;}(Vector!(T, N).VectorTypeName, Vector!(T, N).stringof));

// define aliases for colors

alias RGB8 = Vector!(ubyte, 3),  RGB  = RGB8;
alias RGBA8 = Vector!(ubyte, 4),  RGBA  = RGBA8;

enum isColor(T) = isVector!T && T.length>=3 && (is(T.ComponentType==ubyte) || is(T.ComponentType==float));

private void unittest_Vectors(){
  { // various tests of mine
    immutable v1 = vec4(1,2,3,0);
    assert(v1.text == "vec4(1, 2, 3, 0)");
    Unqual!(typeof(v1)) v2 = v1;  assert(v1.z == 3);
    v2.z++;                       assert(v2.b == 4);
    assert(v1.gb == vec2(2, 3));
    assert(v2 == vec4(1, 2, 4, 0));
    v2.gba = vec3(10, [119, 12]);
    auto f = dvec4(vec2([1,2]).yx, vec2(5, 6).y1);
    assert(f == dvec4(2, 1, 6, 1));
    assert(v2.rR01 == vec4(1, -1, 0, 1)); //Capital letter means negative
    assert(vec2(4, 5).Y == -5); //Scalar swizzle result
    assert(Vector!(ubyte, 2)(4, 5).rG01 == vec4(4, 255-5, 0, 255)); //special '255' rules for RGB swizzles
    assert(vec3(1,2,3)+dvec3(5,6,7) == dvec3(6, 8, 10));
    assert(vec3(1,2,3)*10.5f == vec3(10.5, 21, 31.5));
    assert(10.5*vec3(1,2,3) == vec3(10.5, 21, 31.5));
    assert(bvec3.basis(2) == bvec3(false, false, true)); // bool basis vector test

    vec4 b;  b.yz = [5, 6];    assert(b == vec4(0, 5, 6, 0));
    b.yz = 55;                 assert(b == vec4(0, 55, 55, 0));  //side effect: b.y and b.y both = 55
    b *= vec4(5)._11xx;        assert(b == vec4(0, 55, 275, 0)); //55*5 = 275

    auto i1 = ivec2(2, 3);  i1 <<= 3;  i1 = -i1 + 5;  i1 = ++i1;  i1 = ~i1;  i1++;
    assert(i1 == ivec2(10, 18));
    const i2 = i1;
    assert(-i2 == ivec2(-10, -18));
    assert(!__traits(compiles, ++i2) && __traits(compiles, ++i1)); //const and nonconst

    vec3[] va = [vec3(4)] ~ [vec3(5)]; //always have to use [], because of alias this
    va ~= vec3(6);
    assert(va == [vec3(4), vec3(5), vec3(6)]);

    //bitwise ops
    assert((ivec2(3, 5) & ivec2(2)) == ivec2(3&2, 5&2));
    assert(~RGB(0, 1, 255) == RGB(255, 254, 0));

    // the result type for shifting
    assert(is(typeof(ubyte(1) << ubyte(2)) == int));  //Dlang: is int at minimum
    assert(is(typeof(ubyte(1) << 2) == int));
    assert(is(typeof(Vector!(ubyte, 2)(1, 2)<<2) == Vector!(ubyte, 2) )); // with vectors: it preserves the type of the left hand operand.

    assert(~RGB(1,2,3) == RGB(254, 253, 252)); //unary ~
  }
  { // color vector tests
    RGB a = RGB(40, 80, 250);
    RGB b = RGB(1, 0, 1);
    static assert(is(typeof(a-b)==typeof(a))); // no int promotion, it stays byte
    assert(absDiff(a, b) == a-b && absDiff(a, b) == absDiff(b, a)); //absDifference works well
    assert(a-b != abs(b-a)); //no automatic int promotion for ubyte
    assert(a-b == abs(ivec3(b)-a)); //with manual int promotion it works

    //RGB raw(uint) access
    assert(RGB(0x30, 0x40, 0x55)==RGB(0x554030));
    a.raw = 0x554030;  assert(a.raw == 0x554030);
    RGBA d = 0xFF028801; assert(d.raw == 0xFF028801);
    d.raw = 0xF0605040; assert(d.raw == 0xF0605040);
    const e = d; static assert(!__traits(compiles, e.raw = 1)); assert(e.raw == 0xF0605040);

    //Special RGB swizzling
    assert(RGB(0x10).rR10 == RGBA(0x10, 255-0x10, 255, 0)); // -x -> 255-x  ;  1 -> 255
  }
  { // implicit conversions
    uvec2 a0 = ivec2(1, 2);
    uvec3 a1 = ivec3(1, 2, 3);
    uvec4 a2 = ivec4(1, 2, 3, 4);
    vec2 a3 = ivec2(1, 2);
    vec2 a4 = uvec2(1, 2);
    dvec2 a5 = ivec2(1, 2);
    dvec2 a6 = uvec2(1, 2);
    dvec2 a7 = vec2(1, 2);
  }

  // https://en.wikibooks.org/wiki/GLSL_Programming/Vector_and_Matrix_Operations
  { // Vectors can be initialized and converted by constructors of the same name as the data type:
    vec2 a = vec2(1.0, 2.0);
    vec3 b = vec3(-1.0, 0.0, 0.0);
    vec4 c = vec4(0.0, 0.0, 0.0, 1.0);
    assert(a==vec2(1, 2) && b==vec3(-1, 0, 0) && c==vec4(0, 0, 0, 1));
  }
  { // One can also use one floating-point number in the constructor to set all components to the same value:
    vec4 a = vec4(4.0);
    assert(a == vec4(4, 4, 4, 4));
  }
  { // Casting a higher-dimensional vector to a lower-dimensional vector is also achieved with these constructors:
    vec4 a = vec4(-1.0, 2.5, 4.0, 1.0);
    vec3 b = vec3(a); // = vec3(-1.0, 2.5, 4.0)
    vec2 c = vec2(b); // = vec2(-1.0, 2.5)
    assert(c == b.xy && b == a.rgb && a==vec4(-1, 2.5, 4, 1) && b==vec3(-1, 2.5, 4) && c==vec2(-1, 2.5));
  }
  { // Casting a lower-dimensional vector to a higher-dimensional vector is achieved by supplying
    // these constructors with the correct number of components:
    vec2 a = vec2(0.1, 0.2);
    vec3 b = vec3(0.0, a); // = vec3(0.0, 0.1, 0.2)
    vec4 c = vec4(b, 1.0); // = vec4(0.0, 0.1, 0.2, 1.0)
    assert(b == a._0xy && c == b.stp1 && a==vec2(0.1, 0.2) && b==vec3(0, 0.1, 0.2) && c==vec4(0, 0.1, 0.2, 1));
  }
  { // Components of vectors are accessed by array indexing with the []-operator (indexing starts with 0)
    // or with the .-operator and the element names x, y, z, w or r, g, b, a or s, t, p, q
    vec4 v = vec4(1.1, 2.2, 3.3, 4.4);
    float a = v[3]; // = 4.4
    float b = v.w; // = 4.4
    float c = v.a; // = 4.4
    float d = v.q; // = 4.4
    assert([a,b,c,d].map!"a==4.4f".all);
  }
  { // It is also possible to construct new vectors by extending the .-notation ("swizzling"):
    vec4 v = vec4(1.1, 2.2, 3.3, 4.4);
    vec3 a = v.xyz; // = vec3(1.1, 2.2, 3.3)
    vec3 b = v.bgr; // = vec3(3.3, 2.2, 1.1)
    vec2 c = v.tt; // = vec2(2.2, 2.2)
    assert(a==vec3(1.1, 2.2, 3.3) && b==vec3(3.3, 2.2, 1.1) && c==vec2(2.2, 2.2));
  }
  { // Operators: If the binary operators *, /, +, -, =, *=, /=, +=, -= are used between vectors of the same type, they just work component-wise:
    vec3 a = vec3(1.0, 2.0, 3.0);
    vec3 b = vec3(0.1, 0.2, 0.3);
    vec3 c = a + b; // = vec3(1.1, 2.2, 3.3)
    vec3 d = a * b; // = vec3(0.1, 0.4, 0.9)
    assert(c == vec3(1.1, 2.2, 3.3) && d.approxEqual(vec3(0.1, 0.4, 0.9)));
  }
}

////////////////////////////////////////////////////////////////////////////////
///  Matrix                                                                  ///
////////////////////////////////////////////////////////////////////////////////

enum isMatrix(T) = is(T.MatrixType);

struct Matrix(CT, int N, int M)
if(N.inRange(2, 4) && M.inRange(2, 4)){
  alias MatrixType = typeof(this);
  alias ComponentType = CT;
  enum MatrixTypeName = ComponentTypePrefix!CT != "UNDEF" ? ComponentTypePrefix!CT ~ "mat" ~ (N==M ? N.text : N.text ~ 'x' ~ M.text)
                                                          : MatrixType.stringof;

  //mat N x M: A matrix with N columns and M rows. OpenGL uses column-major matrices, which is standard for mathematics users.
  Vector!(CT, M)[N] columns;
  enum width = N, height = M;
  enum length = N;

  alias columns this;

  // legendary matrices
  static auto identity(){ return typeof(this)(1); }
  static auto translation(CT)(in Vector!(CT, N-1) v) if(N>2) { auto res = identity; res[N-1][0..$-1] = v[]; return res; }

  //note : alias this enables inplicit conversion, but fucks up the ~ concat operator
  //ref auto opIndex(size_t i){ return columns[i]; } const opIndex(size_t i){ return columns[i]; }

  string toString() const { return MatrixTypeName ~ "(" ~ columns[].map!text.join(", ") ~ ")"; }

  private void construct(int i, T, Tail...)(T head, Tail tail) { // this is from gl3n library
    static if(i >= M*N) {
      static assert(false, "Matrix constructor: Too many arguments passed to constructor");
    }else static if(isNumeric!T) {
      columns[i / M][i % M] = head.myto!CT;
      construct!(i + 1)(tail);
    }else static if(isVector!T && i+head.length<=N*M) {
      static foreach(j; 0..head.length) //just inject the vector
        columns[(i+j) / M][(i+j) % M] = head[j].myto!CT;
      construct!(i + T.length)(tail);
    }else static if(isDynamicArray!T) {
      foreach(j; 0..N*M)
        columns[j / N][j % N] = head[j];
      //no more constructs, because dynamic array
    }else{
      static assert(false, "Matrix constructor: Argument must be of type " ~ CT.stringof ~ " or Vector, not " ~ T.stringof);
    }
  }

  private void construct(int i)() { // terminate
    static assert(i == N*M, "Matrix constructor: Not enough arguments passed to constructor.");
  }

  this(Args...)(in Args args){

    void setIdentity(T)(in T val){
      static foreach(i; 0 .. min(N, M))
        this[i][i] = val.myto!CT;
    }

    static if(Args.length==1 && isNumeric!(Args[0])){ // Identity matrix
      setIdentity(args[0]);
    }else static if(Args.length==1 && isMatrix!(Args[0])){
      enum N2 = Args[0].width, M2 = Args[0].height; //cast matrices
      static foreach(i; 0..N)
        static foreach(j; 0..M)
          static if(i<N2 && j<M2) this[i][j] = args[0][i][j].myto!CT;
                             else this[i][j] = (i==j ? 1 : 0).myto!CT;
    }else{
      construct!0(args);
    }
  }

  //set or get as consequtive array. Column-mayor order, just like OpenGL.
  @property auto asArray() const {
    CT[] res; res.reserve(N*M);
    foreach(i; 0..N) foreach(j; 0..M) res ~= this[i][j];
    return res;
  }

  @property void asArray(in CT[] arr) {
    int idx;
    foreach(i; 0..N) foreach(j; 0..M) this[i][j] = arr[idx++];
  }

  private static auto generateBinaryOpMatrix(string op, string payload, A, B)(in A a, in B b){
    Matrix!(OperationResultType!(op, ScalarType!A, ScalarType!B), N, M) res;
    static foreach(i; 0..N) res[i] = mixin(payload);
    return res;
  }

  auto opBinary(string op, T)(in T other) const{
    static if(isNumeric!T){ // Matrix op Scalar
      return generateBinaryOpMatrix!(op, "a[i]" ~ op ~ "b")(this, other);
    }else static if(isMatrix!T){ // Matrix * Matrix
      static if(op=="*"){
        static assert(T.height==width, "Incompatible matrices for multiplication. "~typeof(this).stringof~" * "~T.stringof);
        Matrix!(CommonType!(ComponentType, T.ComponentType), T.width, height) res;
        static foreach(j; 0..T.width) static foreach(i; 0..height){{
          typeof(res).ComponentType sum = 0;
          static foreach(k; 0..T.height)
            sum += this[k][i] * other[j][k];
          res[j][i] = sum;
        }}
        return res;
      }else{ // op!="*"    Matrix op Matrix
        static assert(T.width==width && T.height==height, "Size of matrices must be the same.");
        return generateBinaryOpMatrix!(op, "a[i]" ~ op ~ "b[i]")(this, other);
      }
    }else static if(isVector!T&& op=="*"){  // Matrix op Vector
      static assert(T.length==width, "Incompatible matrix-vector for multiplication. "~typeof(this).stringof~" * "~T.stringof);
      Vector!(CommonType!(ComponentType, T.ComponentType), T.length) res;
      static foreach(i; 0..width){{
        typeof(res).ComponentType sum = 0;
        static foreach(k; 0..height)
          sum += columns[k][i] * other[k];
        res.components[i] = sum;
      }}
      return res;
    }else{
      static assert(false, "invalid operation");
    }
  }

  auto opBinaryRight(string op, T)(in T other) const{
    static if(isNumeric!T){ // Scalar op Matrix
      return generateBinaryOpMatrix!(op, "a" ~ op ~ "b[i]")(other, this); //input arguments must be in computational order!!!
    }else{
      static assert(false, "invalid operation");
    }
  }

  auto opOpAssign(string op, T)(in T other){
    this = mixin("this", op, "other");
    return this;
  }

  bool approxEqual(T)(in T other, float maxDiff = approxEqualDefaultDiff) const{
    static assert(isMatrix!T && T.width==width && T.height==height);
    static foreach(j; 0..height)static foreach(i; 0..width)
      if(abs(this[i][j]-other[i][j]) > maxDiff) return false;  //todo: verify abs
    return true;
  }
}

private alias matrixElementTypes = AliasSeq!(float, double);
private enum matrixSizes = [2, 3, 4];

static foreach(T; matrixElementTypes){
  static foreach(N; matrixSizes){
    static foreach(M; matrixSizes)
      mixin(format!q{alias %smat%sx%s = Matrix!(%s, %s, %s);}(ComponentTypePrefix!T, N, M, T.stringof, N, M));

    //symmetric matrices
    mixin(format!q{alias %smat%s = %smat%sx%s;}(ComponentTypePrefix!T, N, ComponentTypePrefix!T, N, N));
  }
}


private void unittest_Matrices(){
  { // Similarly, matrices can be initialized and constructed. Note that the values specified in
    // a matrix constructor are consumed to fill the first column, then the second column, etc.:
    mat3 m = mat3(
       1.1, 2.1, 3.1, // first column (not row!)
       1.2, 2.2, 3.2, // second column
       1.3, 2.3, 3.3  // third column
    );
    assert(m == mat3(vec3(1.1, 2.1, 3.1), vec3(1.2, 2.2, 3.2), vec3(1.3, 2.3, 3.3)));

    mat3 id = mat3(1.0); // puts 1.0 on the diagonal, all other components are 0.0
    assert(id == mat3(vec3(1, 0, 0), vec3(0, 1, 0), vec3(0, 0, 1)));

    vec3 column0 = vec3(1.1, 2.1, 3.1);
    vec3 column1 = vec3(1.2, 2.2, 3.2);
    vec3 column2 = vec3(1.3, 2.3, 3.3);
    mat3 n = mat3(column0, column1, column2); // sets columns of matrix n
    assert(m == n);
  }
  { // If a larger matrix is constructed from a smaller matrix, the additional rows and columns are
    // set to the values they would have in an identity matrix:
    mat2 m2x2 = mat2(
      1.1, 2.1,
      1.2, 2.2
    );
    mat3 m3x3 = mat3(m2x2); // = mat3(
    assert(m3x3 == mat3(vec3(1.1, 2.1, 0), vec3(1.2, 2.2, 0), vec3(0, 0, 1)));
    mat2 mm2x2 = mat2(m3x3); // = m2x2
    assert(mm2x2 == m2x2);
  }
  { // Matrices are considered to consist of column vectors, which are accessed by array indexing with the []-operator.
    // Elements of the resulting (column) vector can be accessed as discussed above:
    mat3 m = mat3(
      1.1, 2.1, 3.1, // first column
      1.2, 2.2, 3.2, // second column
      1.3, 2.3, 3.3  // third column
    );
    vec3 column3 = m[2]; // = vec3(1.3, 2.3, 3.3)
    float m20 = m[2][0]; // = 1.3
    float m21 = m[2].y; // = 2.3
    assert(column3 == vec3(1.3, 2.3, 3.3) && m20==1.3f && m21==2.3f);
  }
  { // Operators: For matrices, these operators also work component-wise, except for the *-operator, which represents a matrix-matrix product
    mat2 a = mat2(1., 2.,  3., 4.);
    mat2 b = mat2(10., 20.,  30., 40.);
    mat2 c = a * b;
    mat2 expected = mat2(
      1. * 10. + 3. * 20., 2. * 10. + 4. * 20.,
      1. * 30. + 3. * 40., 2. * 30. + 4. * 40.
    );
    assert(c == expected);
  }
  { // For a component-wise matrix product, the built-in function matrixCompMult is provided.
    auto a = mat2x3(vec3(1,2,3), vec3(4,5,6));
    auto b = mat2x3(vec3(10,20,30), vec3(40,50,60));
    assert(matrixCompMult(a, b) == mat2x3(vec3(10, 40, 90), vec3(160, 250, 360)));
  }
  { // The *-operator can also be used to multiply a floating-point value (i.e. a scalar) to all components of a vector or matrix (from left or right):
    vec3 a = vec3(1.0, 2.0, 3.0);
    mat3 m = mat3(1.0);
    float s = 10.0;
    vec3 b = s * a;   assert(b == vec3(10.0, 20.0, 30.0));
    vec3 c = a * s;   assert(c == vec3(10.0, 20.0, 30.0));
    mat3 m2 = s * m;  assert(m2 == mat3(10.0));
    mat3 m3 = m * s;  assert(m3 == mat3(10.0));
  }
  { // more complex matrix multiplication test from https://people.richland.edu/james/lecture/m116/matrices/multiplication.html
    auto a = mat3x2(1, 4, -2, 5, 3, -2),
         b = mat4x3(vec3(1, -3, 6), vec3(-8, 6, 5), 4, 7, -1, vec3(-3, 2, 4));
    assert(a*b == mat4x2(vec2(25, -23), vec2(-5, -12), vec2(-13, 53), vec2(5, -10)));
  }
  { // Furthermore, the *-operator can be used for matrix-vector products of the corresponding dimension
    vec2 v = vec2(10., 20.);
    mat2 m = mat2(1., 2.,  3., 4.);
    assert(m*v == vec2(1. * 10. + 3. * 20., 2. * 10. + 4. * 20.));
    assert(v*m == vec2(1. * 10. + 2. * 20., 3. * 10. + 4. * 20.)); //multiplying a vector from the left to a matrix corresponds to multiplying it from the right to the transposed matrix:
  }
  { // https://www.varsitytutors.com/hotmath/hotmath_help/topics/multiplying-vector-by-a-matrix#:~:text=Example%20%3A,number%20of%20rows%20in%20y%20.&text=First%2C%20multiply%20Row%201%20of,Column%201%20of%20the%20vector.
    auto m = mat3(1, 4, 7, 2, 5, 8, 3, 6, 9);
    auto v = vec3(2, 1, 3);
    assert(m*v == vec3(13, 31, 49));
  }

  { // Various tests of mine
    static assert(is(dmat2 == Matrix!(double, 2, 2)));

    assert(3*mat2(2) == mat2(6, 0, 0, 6));
    assert(mat2(1)+mat2(2) == mat2(3, 0, 0, 3));

    assert(mat2x3(vec2(1,2), 3, 4, vec2(5,6)) == mat2x3(1,2,3,4,5,6));
    assert(mat2(vec4(3)) == mat2(3,3,3,3));

    dmat2 m1 = mat2(vec4(1));
    assert(m1 == mat2(1,1,1,1));

    assert(mat2(1,2,3,4).asArray.equal([1,2,3,4]));
    m1.asArray = [9,2,3,4];  assert(m1 == mat2(9,2,3,4));

    assert(mat2(1,2,3,4).text == "mat2(vec2(1, 2), vec2(3, 4))");
    assert(mat2(1) == mat2.identity);
  }
}

//! Functions /////////////////////////////////////////////////

/// this is my approxEqual. The one in std.math is too complicated
bool approxEqual(A, B, C)(in A a, in B b, in C maxDiff = approxEqualDefaultDiff) {
  return abs(a-b) <= maxDiff;
}

/// generates a vector or scalar from a function that can have any number of vector/scalar parameters
private auto generateVector(CT, alias fun, T...)(in T args){
  static if(anyVector!T){
    Vector!(CT, CommonVectorLength!T) res;
    static foreach(i; 0..res.length) res[i] = cast(CT) mixin("fun(", T.length.iota.map!(j => "args["~j.text~"].vectorAccess!i").join(','), ")");
    return res;
  }else{
    return cast(CT) fun(args);
  }
}

// Angle & Trig. functions ///////////////////////////////////

auto radians(real scale = PI/180, A)(in A a){
  alias CT = CommonScalarType!(A, float);  //common type is at least float
  alias fun = a => a * cast(CT) scale;         //degrade the real enum if needed
  return a.generateVector!(CT, fun);
}
auto degrees(A)(in A a){ return radians!(180/PI)(a); }

/// Mixins an std.math funct that will work on scalar or vector data. Cast the parameter at least to a float and calls fun()
private enum UnaryStdMathFunct(string name) = q{
  auto #(A)(in A a){
    alias CT = CommonScalarType!(A, float);
    alias fun = a => std.math.#(cast(CT) a);
    return a.generateVector!(CT, fun);
  }
}.replace('#', name);

static foreach(s; "sin cos tan asin acos sinh cosh tanh asinh acosh atan".split(' ')) mixin(UnaryStdMathFunct!s);

auto atan(A, B)(in A a, in B b){ //atan is GLSL
  alias CT = CommonScalarType!(A, B, float);
  alias fun = (a, b) => std.math.atan2(cast(CT) a, cast(CT) b);
  return generateVector!(CT, fun)(a, b);
}

//auto atan2(A, B)(in A a, in B b){ return atan(a, b); }
//this improves std.math.atan2. No, rather stick to GLSL compatibility to force GLSL-DLang compatibility more

private void unittest_AngleAndTrigFunctions() {
  static assert(is(typeof(radians(1   ))==float ));
  static assert(is(typeof(radians(1.0f))==float ));
  static assert(is(typeof(radians(1.0 ))==double));
  static assert(is(typeof(radians(1.0L))==real  ));

  assert(format!"%.15f"(PI) == "3.141592653589793"); //check PI for at least double precision
  assert(360.radians.approxEqual(6.28319, 1e-5));
  assert(7592.radians.degrees.approxEqual(7592));
  assert(vec2(180, 360).radians.approxEqual(vec2(6.28319/2, 6.28319), 1e-5));
  assert(PI.degrees == 180 && is(typeof(PI.degrees)==real));

  assert(sin(5).approxEqual(-0.95892));
  static assert(is( typeof(cos(dvec2(1, 2))) == dvec2 ));
  assert(cos(dvec2(1, 2.5)).approxEqual(vec2(0.5403, -0.8011)));
  assert(tan(ivec2(1, 2)).approxEqual(vec2(1.5574, -2.1850)));
  assert(asin(.5).approxEqual(PI/6));
  assert(acos(vec2(0, .5)).approxEqual(vec2(1.5707, PI/3)));
  // hiperbolic functions are skipped, those are mixins anyways
  assert(atan(ivec2(1,2)).approxEqual(vec2(0.7853, 1.1071)));
  assert(atan(vec2(1,2), 3).approxEqual(vec2(.3217, .588)));
  assert(atan(vec2(1,2), 3) == atan(vec2(1,2), 3)); //atan is the overload in GLSL, not atan2
}


// Exponential functions /////////////////////////////////////

auto pow(A, B)(in A a, in B b){
  alias CT = typeof(ScalarType!A.init ^^ ScalarType!B.init);
  alias fun = (a, b) => a ^^ b;
  return generateVector!(CT, fun)(a, b);
}

static foreach(s; "exp log log2 log10 sqrt".split(' ')) mixin(UnaryStdMathFunct!s);

auto exp2 (A)(in A a){ return pow( 2, a); }
auto exp10(A)(in A a){ return pow(10, a); }

auto sqr(A)(in A a){
  alias CT = typeof(ScalarType!A.init ^^ 2);
  return a.generateVector!(CT, a => a ^^ 2);
}

auto signedsqr(A)(in A a){
  alias CT = typeof(- ScalarType!A.init ^^ 2);
  return a.generateVector!(CT, a => a<0 ? -(a ^^ 2) : a ^^ 2);
}

auto inversesqrt(A)(in A a){
  alias CT = CommonScalarType!(A, float);
  return a.generateVector!(CT, a => 1 / sqrt(a));
}


private void unittest_ExponentialFunctions(){
  static assert(is( typeof(pow(ivec2(2, 10), 2)) == ivec2 ));
  assert(pow(ivec2(2, 10), 2) == ivec2(4, 100));
  assert(pow(vec2(2.5, 10), 2) == vec2(6.25, 100));
  assert(exp(0)==1 && exp2(2)==4 && exp10(3)==1000);
  assert(log(5).approxEqual(1.6094) && log2(8)==3 && log10(1000)==3);

  static assert(is( typeof(sqr(5))==int ));
  static assert(is( typeof(sqr(5.0))==double ));

  assert(atan(sqrt(3.0)).approxEqual(PI/3));
  assert(atan(sqrt(3)).approxEqual(PI/3));

  assert(sqr(5)==25 && sqr(vec2(2, 3))==vec2(4, 9));
  assert(signedsqr(vec2(-5, 3))==vec2(-25, 9));

  assert(sqrt(4)==2);
  assert(inversesqrt(4)==.5);
  static assert(is( typeof(inversesqrt(4))==float ));
}


// Common functions //////////////////////////////////////////

auto abs    (A)(in A a) { return max(a, -a); }

auto sign   (A)(in A a) { alias CT = ScalarType!A; return a.generateVector!(CT, a => a==0 ? 0 : a<0 ? -1 : 1 ); }

private auto floatReductionOp(alias fun, CT, A)(in A a){
  static assert(isFloatingPoint!(ScalarType!A));
  return a.generateVector!(CT, fun);
}

auto floor    (A, CT=ScalarType!A)(in A a) { return a.floatReductionOp!(std.math.floor, CT, A); }
auto ceil     (A, CT=ScalarType!A)(in A a) { return a.floatReductionOp!(std.math.ceil , CT, A); }
auto trunc    (A, CT=ScalarType!A)(in A a) { return a.floatReductionOp!(std.math.trunc, CT, A); }
auto round    (A, CT=ScalarType!A)(in A a) { return a.floatReductionOp!(std.math.round, CT, A); }
auto roundEven(A, CT=ScalarType!A)(in A a) { return a.floatReductionOp!(std.math.lrint, CT, A); } //note: depens on roundingMode: default is even

// generate int, and long versions
static foreach(T; AliasSeq!(int, long))
  static foreach(F; AliasSeq!(floor, ceil, trunc, round, roundEven))
    mixin(q{ auto %s(A)(in A a) { return a.%s!(A, %s); } }.format(T.stringof[0]~__traits(identifier, F), __traits(identifier, F), T.stringof));

auto fract(A)(in A a) { static assert(isFloatingPoint!(ScalarType!A)); return a-floor(a); }

auto mod(A, B)(in A x, in B y) {
  // this is the cyclic modulo.  (% is the symmetric)
  alias CT = CommonScalarType!(A, B);
  static if(isFloatingPoint!CT) return x - y * floor(x*(1.0f/y));
                           else return cast(CT) (x - y*(x/y));
}

auto modf(A, B)(in A a, out B b) {
  const floora = floor(a);
  b = cast(Unqual!B) floora;
  return a-floora;
}

private auto minMax(bool isMin, T, U)(in T a, in U b){
  return generateVector!(CommonScalarType!(T, U),
    (a, b) => isMin ? std.algorithm.min(a, b) : std.algorithm.max(a, b)
  )(a, b); //maybe it's better than a tenary ?: operation.
}

auto min(T...)(in T args){ //note: std.algorithm.min is (T t)
  static if(T.length==1 && isInputRange!(T[0])){
    return args[0].fold!((a, b) => min(a, b));
  }else static if(anyVector!T){
    static if(T.length==2) return minMax!1(args[0], args[1]);
                      else return min(min(args[0..$-1]), args[$-1]);
  }else return std.algorithm.min(args);
}

auto max(T...)(in T args){ //note: std.algorithm.max is (T t)
  static if(T.length==1 && isInputRange!(T[0])){
    return args[0].fold!((a, b) => max(a, b));
  }else static if(anyVector!T){
    static if(T.length==2) return minMax!0(args[0], args[1]);
                      else return max(max(args[0..$-1]), args[$-1]);
  }else return std.algorithm.max(args);
}

bool minimize(A, B)(ref A a, in B b) { const n = min(a, b), res = a != n; a = n; return res; }
bool maximize(A, B)(ref A a, in B b) { const n = max(a, b), res = a != n; a = n; return res; }

bool inRange(V, L, H)(in V value, in L lower, in H higher){
  static if(CommonVectorLength!(V, V, H)==1) return value>=lower && value<=higher;
                                        else return all(greaterThanEqual(value, lower)) && all(lessThanEqual(value, higher));
}

/// bounds can be unsorted
bool inRange_sorted(V, L, H)(in V value, in L r1, in H r2){ return inRange(value, min(r1, r2), max(r1, r2)); }

/// checking for valid index in arrays
bool inRange(V, A)(in V index, in A[] arr){ return index>=0 && index<arr.length; }

// apply it to intervals
bool inRange(V, I)(in V value, in I bounds) if(__traits(compiles, (value in bounds))){ return value in bounds; }

auto clamp(T1, T2, T3)(in T1 val, in T2 lower, in T3 upper){
  static if(anyVector!(T1, T2, T3)) return max(lower, min(upper,val));
                               else return std.algorithm.clamp(val, lower, upper);
}

//note: cmp is extending/hijacking std.algorihtm.cmp's functionality with vector/scalar mode.
public import std.algorithm: cmp;
auto cmp(A, B)(in A a, in B b) if((isNumeric!A || isVector!A) && (isNumeric!B || isVector!B)) { //no predicate, optional vector/scalar mode
//  static if((isNumeric!A || isVector!A) && (isNumeric!B || isVector!B)){ // scalar vector combo? This function will serve it.
    return generateVector!(int, (a, b) => a==b ? 0 : a<b ? -1 : 1)(a, b); // std.math.cmp(a, b) can only work on the excat same type.
//  }else return std.algorithm.cmp(a, b); //this works on input ranges. Only if het.math cannot serve it.
}

auto mix(A, B, T)(in A a, in B b, in T t){
  static if(is(Unqual!T==bool)) return mix(a, b, int(t));
  alias CT = CommonScalarType!(A, B); //type of result NOT depends on t
  return generateVector!(CT, (a, b, t) => a*(1-t) + b*t)(a, b, t);
}

auto unmix(A, B, T)(in A a, in B b, in X x){ //inverse of mix
  alias CT = CommonScalarType!(A, B); //type of result NOT depends on x
  return generateVector!(CT, (a, b, x) => (x-a)/(b-a) );
}

auto step(A, B)(in A edge, in B x){
  alias CT = CommonScalarType!(A, B);
  return generateVector!(CT, (edge, x) => x<edge ? 0 : 1 )(edge, x);
}

auto smoothstep(A, B, C)(in A edge0, in B edge1, in C x){
  alias CT = CommonScalarType!(A, B, C, float); //result is at least float. In the range: 0..1
  return generateVector!(CT, (edge0, edge1, x){
    auto t = clamp(((x - edge0)*1.0f) / (edge1 - edge0), 0, 1); //difision is forced to float with that *1.0f
    return t * t * (3 - 2 * t);
  })(edge0, edge1, x);
}

auto isnan(A)(in A a){ return a.generateVector!(bool, a => std.math.isNaN     (a) ); }
auto isinf(A)(in A a){ return a.generateVector!(bool, a => std.math.isInfinity(a) ); }
auto isfin(A)(in A a){ return a.generateVector!(bool, a => std.math.isFinite  (a) ); }

auto isnull(A)(in A a){
  static if(isBounds!A) return !a.valid;
  else static if(isVector!A){ return a == A(0); }
  else static if(isMatrix!A){ return a == A(0); }
  else static assert("invalid argument type");
}

auto isPowerOf2(A)(in A a){ return a.generateVector!(bool, a => std.math.isPowerOf2(a) ); }

auto nextPow2 (A)(in A a){ return a.generateVector!(ScalarType!A, a => std.math.nextPow2 (a) ); }
auto truncPow2(A)(in A a){ return a.generateVector!(ScalarType!A, a => std.math.truncPow2(a) ); }
auto prevPow2 (A)(in A a){ return a.generateVector!(ScalarType!A, a => isPowerOf2(a) ? a/2 : std.math.truncPow2(a) ); }

auto nextUp   (A)(in A a){ static assert(isFloatingPoint!(ScalarType!A)); return a.generateVector!(A, a => std.math.nextUp  (a) ); }
auto nextDown (A)(in A a){ static assert(isFloatingPoint!(ScalarType!A)); return a.generateVector!(A, a => std.math.nextDown(a) ); }

auto nextAfter(A, B)(in A a, in B b){ //a goes towads b
  static assert(isFloatingPoint!(ScalarType!A));
  return generateVector!(A, (a, b) => std.math.nextafter(a, cast(A) b) )(a, b);
}

private auto floatBitsTo(T, A)(in A a){
  static assert(is(ScalarType!A==float), "Unsupported type. float expected.");
  static if(isVector!A) return *(cast(Vector!(T, A.length)*) (&a));
                   else return *(cast(T*) (&a));
}

auto floatBitsToInt (A)(in A a){ return floatBitsTo!int (a); }
auto floatBitsToUint(A)(in A a){ return floatBitsTo!uint(a); }

private auto bitsToFloat(T, A)(in A a){
  static assert(is(ScalarType!A==T), "Unsupported type. "~T.stringof~" expected.");
  static if(isVector!A) return *(cast(Vector!(float, A.length)*) (&a));
                   else return *(cast(float*) (&a));
}

auto intBitsToFloat (A)(in A a){ return bitsToFloat!int (a); }
auto uintBitsToFloat(A)(in A a){ return bitsToFloat!uint(a); }

auto fma(A, B, C)(in A a, in B b, in C c){ // no extra precision. it's just here for compatibility.
  return generateVector!(CommonScalarType!(A, B, C), (a, b, c) => a * b + c)(a, b, c);
}

auto absDiff(A, B)(in A a, in B b) {
  alias CT = CommonScalarType!(A, B);
  static if(isUnsigned!CT) return max(a, b)-min(a, b);
                      else return abs(a-b);
}

auto sad(A, B)(in A a, in B b) { return absDiff(a, b)[].sum; }

private void unittest_CommonFunctions(){
  assert(abs(vec2(-5, 5))==vec2(5, 5));
  assert(sign(Vector!(byte, 3)(-5, 0, 5)) == vec3(-1, 0, 1));

  static assert(is(typeof(iceil (5.4 )) == int   ));
  static assert(is(typeof(lfloor(5.4 )) == long  ));
  static assert(is(typeof(floor (5.4f)) == float ));
  static assert(is(typeof(floor (5.0 )) == double));
  auto vf = vec4(0.1, -.5, 1.5, 1.6);
  assert(vf.floor     == vec4(0, -1, 1, 1));
  assert(vf.iceil     == ivec4(1, 0, 2, 2));
  assert(vf.ltrunc    == uvec4(0, 0, 1, 1));
  assert(vf.round     == vec4(0, -1, 2, 2));
  assert(vf.roundEven == vec4(0, 0, 2, 2));
  assert(vf.fract.approxEqual( vf-floor(vf) ));

  { // modulo tests
    const m = .7f;
    assert((vf % m).approxEqual(vec4(0.1, -0.5, 0.1, 0.2))); //%:   symmetric mod
    assert(vf.mod(m).approxEqual(vf-m*floor(vf/m)));      //mod: cyclic mod
    assert(vf.mod(m).approxEqual(vec4(0.1, 0.2, 0.1, 0.2)));

    const a = 4.1f;
    const r1 = vec4(0.41, 0.95, 0.15, 0.56), r2 = ivec4(0, -3, 6, 6);
    ivec4 ires;  assert(modf(vf*a, ires).approxEqual(r1) && ires==r2);
    vec4  fres;  assert(modf(vf*a, fres).approxEqual(r1) && fres==r2);
  }

  assert(cmp("abc", "abc")==0 && cmp("abc", "abcd")<0 && cmp("bbc", "abc"w)>0 && cmp([1L, 2, 3], [1, 2])>0 && cmp!"a<b"([1L, 2, 3], [1, 2])>0);
  assert(cmp([1,2,3], [1,2]) > 0);
  assert(cmp([1,2], [1,2,3]) < 0);
  assert(cmp(-100.0, -0.5) < 0);
  assert((cmp(1, 2)>0)==(std.math.cmp(1.0,2.0)>0));
  assert(cmp(1, 1)==0);
  assert((cmp(2, 1)>0)==(std.math.cmp(2.0,1.0)>0));
  assert(cmp(vec2(1),1)==vec2(cmp(1,1)) && cmp(vec2(1),2)==vec2(cmp(1,2)) && cmp(vec2(2),1)==vec2(cmp(2,1)));

  {
    assert(min(1, 2.0)==1 && max(1, 2)==2);
    const a = vec3(1, 2, 3), b = vec3(4, 0, 6);
    assert(min(a, b) == vec3(1, 0, 3));
    assert(min(a, 2) == vec3(1, 2, 2));
    assert(min(b, 5) == vec3(4, 0, 5));
    assert(max(b, 5) == vec3(5, 5, 6));
    assert(min(2, a) == vec3(1, 2, 2));
    assert(min(5, b) == vec3(4, 0, 5));
    assert(max(5, b) == vec3(5, 5, 6));
    assert(max(a, b, 3) == vec3(4, 3, 6));
    assert(min(a, b, 2) == vec3(1, 0, 2));

    // min()/max() works for ranges too (unlike std.min. It's the reasonable way to do minEpement on vectors.
    // MinElement uses componentwise opCmp, it's just for sorting.
    alias arr = AliasSeq!(vec2(3, 4), vec2(9, 11), vec2(14, 2));
    static assert(is(typeof([arr]) == vec2[]));
    assert(min([arr]) == min(arr));
    assert(max([arr]) == max(arr));
  }

  { auto a = vec2(1,2);
    assert(maximize(a, vec2(3, 4)) && a==vec2(3, 4));
    assert(minimize(a, 3) && a==vec2(3, 3));
    assert(!maximize(a, 2) && a==3);
  }

  assert(vec3(1,2,3).clamp(1.5, 2.5) == vec3(1.5, 2, 2.5));
  assert(ivec3(8).clamp(1.5, vec3(4, 5, 6)) == vec3(4, 5, 6));

  assert(inRange(1,1,1) && !inRange(0, 1, 2) && inRange(1, 0, 2));
  assert(inRange_sorted(1, 3, 0));
  assert(inRange(1,[0, 1]) && !inRange(-1, [0, 1]) && !inRange(2L, [0, 1]));

  assert(mix(vec2(1,2), vec2(2, 4), 0.5f) == vec2(1.5, 3));
  assert(mix(vec2(1,2), 2, 0.5) == vec2(1.5, 2));
  assert(mix(Vector!(ubyte, 2)(2,3), Vector!(ubyte, 2)(4,5), false) == vec2(2, 3));
  assert(mix(Vector!(ubyte, 2)(2,3), Vector!(ubyte, 2)(4,5), true ) == vec2(4, 5));

  assert(is(typeof(mix(ubyte.init, ubyte.init, 0.0)) == ubyte)); // result type depends only on the first 2 parameters

  assert(step(vec3(1, 2, 3), 2) == vec3(1, 1, 0));
  assert(is(typeof(step(1,2 ))==int));
  assert(is(typeof(step(vec2(1), 2.))==dvec2));

  assert(8.iota.map!(i => (smoothstep(ivec2(0, 2), 9, i)*100).iround ).equal(
    [ivec2(0, 0), ivec2(3, 0), ivec2(13, 0), ivec2(26, 6), ivec2(42, 20), ivec2(58, 39), ivec2(74, 61), ivec2(87, 80)] ));

  {// nan, inf handling
    assert(float.init.isnan);
    assert(!float.init.isfin);
    const n = vec4(1, NaN(5421), -float.infinity, float.init);
    assert(n.isnan == bvec4(0, 1, 0, 1));
    assert(n.isinf == bvec4(0, 0, 1, 0));
    assert(n.isfin == bvec4(1, 0, 0, 0));
  }

  {// std.math only things
    assert(isPowerOf2(vec4(1,2,3,4))==bvec4(true, true, false, true));
    static assert(is(typeof(nextPow2(2))==int));
    static assert(is(typeof(truncPow2(2.5L))==real));
    assert(nextPow2(2)==4 && nextPow2(3.5)==4);
    assert(prevPow2(2)==1 && prevPow2(2.5)==2);
    assert(truncPow2(3.5)==2 && truncPow2(2)==2);
    assert(nextUp(1.0f)>1 && nextDown(1.0)<1);
    assert(nextAfter(5.0, 6)>5 && nextAfter(5.0, 4)<5);
  }
  {// Bit conversions
    const v = vec4(1, -2, 3, PI);
    assert(v.floatBitsToInt  == ivec4(1065353216, -1073741824, 1077936128, 1078530011));
    assert(-2.0f.floatBitsToUint == 3221225472);
    assert(1078530011.intBitsToFloat.approxEqual(PI));
    assert(uvec2(1077936128, 1078530011).uintBitsToFloat.approxEqual(vec2(3, PI)));
  }

  assert(fma(2, 3, vec2(10, 20))==vec2(16, 26));
  assert(absDiff(vec2(1, 15), 10) == vec2(9, 5));
  assert(absDiff(Vector!(ushort, 3)(1, 2, 3), Vector!(ushort, 3)(3, 2, 1)) == Vector!(ushort, 3)(2, 0, 2)); //must work with unsigneds too
  assert(sad(Vector!(ubyte, 2)(250, 240), 10) == 240+230); //must not summarize on ubyte, but int.
}

// Geometric functions ///////////////////////////////////////

// need a new sum because the original is summing with double, not float. The vector module is mainly float.
auto sum(R)(R r){
  import std.range : ElementType;
  alias T = ElementType!R;
  typeof(T(0)*2) sum = 0;  //the initial value is Type*2
  foreach(a; r) sum += a;
  return sum;
}

//todo: check these in asm and learn about the compiler.
auto length             (T, int N)(in Vector!(T, N) a) { return sqrt(sqrLength(a)); }
auto sqrLength          (T, int N)(in Vector!(T, N) a) { return (a^^2)[].sum; }
auto manhattanLength    (T, int N)(in Vector!(T, N) a) { return a[].map!abs.sum; }

auto distance           (A, B)(in A a, in B b) { return length         (a-b); }
auto sqrDistance        (A, B)(in A a, in B b) { return sqrLength      (a-b); }
auto manhattanDistance  (A, B)(in A a, in B b) { return manhattanLength(a-b); }

auto dot(A, B)(in A a, in B b) {
  //todo: make prettier errors, this needs more IDE integration
  static assert(CommonVectorLength!(A, B) > 1, "Dot product needs at least 1 vector argument.");
  return (a*b)[].sum;
}

auto cross(A, B)(in A a, in B b) {
  alias len = CommonVectorLength!(A, B);
  static if(len==2){
    return cross(a.xy0, b.xy0);
  }else static if(len==3){
    alias V = Vector!(CommonScalarType!(A, B), 3);
    return V(a.y*b.z - b.y*a.z,
             a.z*b.x - b.z*a.x,
             a.x*b.y - b.x*a.y);
  }else static assert(0, "Cross product needs at least on 2D or 3D vector argument.");
}

auto normalize(A)(in A a){
  static assert(isVector!A, "Normalize needs a vector argument.");
  return a*(1.0f/length(a));
}

/// Orients a vector to point away from a surface as defined by its normal.
auto faceforward(A, B, C)(in A N, in B I, in C Nref){ return dot(Nref, I) < 0 ? N : -N; }

/// For a given incident vector I and surface normal N reflect returns the reflection direction.
/// N should be normalized in order to achieve the desired result.
auto reflect(A, B)(in A I, in B N){
  return I - 2 * dot(N, I) * N;
}

/// For a given incident vector I, surface normal N and ratio of indices of refraction, eta, refract returns the refraction vector, R.
/// The input parameters I and N should be normalized in order to achieve the desired result.
auto refract(A, B)(in A I, in B N){
  const dotNI = dot(N, I),
        k = 1 - eta * eta * (1 - dotNI^^2);
  return k < 0.0 ? CommonVectorType!(A, B).Null
                 : eta * I - (eta * dotNI + sqrt(k)) * N;
}

// Removes vector component i
auto minorVector(int i, T, int N)(in Vector!(T, N) v){
  Vector!(T, N-1) res;
  foreach(k; 0..N) if(k!=i) res[k<i ? k : k-1] = v[k];
  return res;
}


private void unittest_GeometricFunctions(){
  // length()
  auto v = [vec2(1,2), vec2(-2, -1), vec2(5, 0)];
  static assert(vec2.length == 2 && v[0].length == 2); //length property of static arrays

  //dynamic array length must ONLY returned as a property, not as a function()
  static assert(!__traits(compiles, length(v)) && __traits(compiles, v.length));

  // my custom sum()
  static assert(is(typeof([1   ].sum)==int   ));
  static assert(is(typeof([0.5f].sum)==float )); // std.sum would return a double here.
  static assert(is(typeof([0.5 ].sum)==double));
  static assert(is(typeof([0.5L].sum)==real  ));

  static assert(is(typeof(length(vec2(1,2)))==float)); // std.algorithm.sum would return a double. My sum is just summing floats as floats.
  assert(v.length == 3); //dynamic length test
  assert(v[0].length == 2); //static vector length
  assert(length(v[0]).approxEqual(sqrt(1^^2 + 2^^2)) && length(v[0])==length(v[1]) && length(v[2])==5); //veryfy length calculations
  assert(v.map!manhattanLength.equal([3, 3, 5]));

  // distance()
  const a = ivec2(1, -4), b = vec2(12.5, 73.4);
  assert(distance         (a, b) == length         (a-b));
  assert(sqrDistance      (a, b) == sqrLength      (b-a));
  assert(manhattanDistance(a, b) == manhattanLength(a-b));

  assert(dot(vec2(3, 7), 2) == 3*2 + 7*2);

  assert(cross(a, b) == vec3(0, 0, determinant(mat2(a, b))));
  assert(cross(vec3(3,-3,1), vec3(4,9,2)) == vec3(-15,-2,39));

  assert(normalize(vec2(-0.5, 2)).approxEqual(vec2(-0.242536, 0.970143)));

  //todo: faceforward, reflect, refract

  //minorVector
  assert(vec3(1,2,3).minorVector!0 == vec2(2,3));
  assert(vec3(1,2,3).minorVector!1 == vec2(1,3));
  assert(vec3(1,2,3).minorVector!2 == vec2(1,2));
}

// Matrix functions //////////////////////////////////////////

auto matrixCompMult(T, U)(in T a, in U b){
  static assert(isMatrix!T && isMatrix!U);
  static assert(T.width==U.width && T.height==U.height);
  Matrix!(CommonType!(T.ComponentType, U.ComponentType), T.width, T.height) res;
  static foreach(i; 0..T.width) static foreach(j; 0..T.height)
    res[i][j] = a[i][j] * b[i][j];
  return res;
}

auto outerProduct(U, V)(in U u, in V v) if(isVector!U && isVector!V){
  //https://www.chegg.com/homework-help/definitions/outer-product-33
  Matrix!(CommonType!(U.ComponentType, V.ComponentType), V.length, U.length) res;
  static foreach(i; 0..V.length) res[i] = u*v[i];
  return res;
}

auto transpose(CT, int M, int N)(in Matrix!(CT, N, M) m){
  Matrix!(CT, M, N) a;
  foreach(i; 0..M) foreach(j; 0..N) a[i][j] = m[j][i];
  return a;
}

/// Removes the column i and row j
auto minorMatrix(int i, int j, T, int N, int M)(in Matrix!(T, N, M) m){
  Matrix!(T, N-1, M-1) res;
  foreach(x; 0..N) if(x!=i) foreach(y; 0..M) if(y!=j) res[x<i ? x : x-1][y<j ? y : y-1] = m[x][y];
  return res;
}

private auto checkerSign(int i, T)(in T a){ return i&1 ? -a : a; }

auto determinant(T)(in T m) if(isMatrix!T && T.width==T.height){ enum N = T.width; //todo: check mat4.det in asm
  // https://www.mathsisfun.com/algebra/matrix-determinant.html
  typeof(m[0][0]+1) res = 0;
  static if(N==2) res = m[0][0]*m[1][1] - m[1][0]*m[0][1];
             else static foreach(i; 0..T.width) res += checkerSign!i( m[i][0] * determinant(m.minorMatrix!(i, 0)) );
  return res;
}

auto inverse(T)(in T m) if(isMatrix!T && T.width==T.height){ enum N = T.width;
  // https://www.mathsisfun.com/algebra/matrix-inverse.html
  // https://www.mathsisfun.com/algebra/matrix-inverse-minors-cofactors-adjugate.html
  const d = determinant(m);
  if(d==0) return T(0); //return 0 matrix if determinant is zero

  T minors;
  static if(N==2) minors = T( m[1][1], -m[0][1], -m[1][0], m[0][0] );
             else static foreach(i; 0..N) static foreach(j; 0..N) minors[i][j] = m.minorMatrix!(j, i).determinant.checkerSign!(i+j);
  return minors * (1.0f/d);
}


private void unittest_MatrixFunctions(){
  assert(matrixCompMult(mat2(1, 2, 3, 4), mat2(vec4(2))) == mat2(2, 4, 6, 8));

  //transpose
  assert(mat2x3(vec3(1,2,3),vec3(4,5,6)).transpose == mat3x2(1,4,2,5,3,6));
  assert(mat2x3(vec3(1,2,3),vec3(4,5,6)).transpose.transpose == mat2x3(vec3(1,2,3),vec3(4,5,6)));

  //outer product
  assert(outerProduct(vec3(3,2,1), vec4(7,2,3,1)) == mat4x3(21,14,7, 6,4,2, 9,6,3, 3,2,1));

  //minorMatrix (no GLSL)
  assert(mat3(1,2,3,4,5,6,7,8,9).minorMatrix!(1,1) == mat2(1,3,7,9));

  //determinant
  assert(determinant(mat2(4, 3, 6, 8)) == 14);
  assert(mat3(6,4,2,1,-2,8,1,5,7).determinant == -306);
  assert(mat4(4,0,0,0, 3,1,-1,3, 2,-3,3,1, 2,3,3,1).determinant == -240);

  //inverse
  assert(mat2(4,2,7,6).inverse.approxEqual( mat2(.6, -.2, -.7, .4) ));
  assert(mat3(3,2,0, 0,0,1, 2,-2,1).inverse.approxEqual( mat3(.2,-.2,.2, .2,.3,-.3, 0,1,0) ));
  assert(mat4(-3,-3,-2,1, -1,1,3,-2, 2,2,0,-3, -3,-2,1,1).inverse.approxEqual(mat4(-1.571, -2.142, 2, 3.285,  2,3,-3,-5, -1,-1,1,2, 0.285,0.571,-1,-1.142)));
}

// Vector relational functions //////////////////////////////////////////

//todo: !!!!!!!!!!!!!!! atirni az osszes in-t auto ref-re es merni a sebesseget egy reprezentativ teszt segitsegevel.
//A lessThan-ra eleg az in is. nem kell a safeOp!">"-ban levo auto ref.
//Asm-ban a lessThan-t megneztem: azt szanaszet optimizalta, nem is volt lessThan a belso loopban.
//de lehet, hogy az auto ref valamiert jobb. Nem veletlenul azt hasznaljak az std.functional.safeOp-ban.

/// this is an extension to std.functional.safeOp. (lessThan, greaterThan, etc.)
private auto mySafeOp(string op, A, B)(in A a, in B b){
  static if(anyVector!(A, B)) return generateVector!(bool, (a, b) => mixin("a"~op~"b") )(a, b);
                         else return std.functional.safeOp!op(a, b);
}

auto lessThan        (A, B)(in A a, in B b){ return mySafeOp!"<" (a, b); }
auto lessThanEqual   (A, B)(in A a, in B b){ return mySafeOp!"<="(a, b); }
auto greaterThan     (A, B)(in A a, in B b){ return mySafeOp!">" (a, b); }
auto greaterThanEqual(A, B)(in A a, in B b){ return mySafeOp!">="(a, b); }

public import std.algorithm : equal;
auto equal(A, B)(in A a, in B b) if((isNumeric!A || isVector!A) || (isNumeric!B || isVector!B)) { return a == b; }

auto notEqual(A, B)(in A a, in B b){ return !equal(a, b); }

public import std.algorithm: all;
bool all(alias pred = "a", A)(in A a)
if(is(Unqual!A == bool) || isVector!A)
{
  static if(isVector!A) return std.algorithm.all!pred(a[]);
                   else return std.algorithm.all!pred([a]);
}

public import std.algorithm: any;
bool any(alias pred = "a", A)(in A a)
if(is(Unqual!A == bool) || isVector!A)
{
  static if(isVector!A) return std.algorithm.any!pred(a[]);
                   else return std.algorithm.any!pred([a]);
}

public import std.functional: not;
auto not(alias pred = "a", A)(in A a)
if(is(Unqual!A == bool) || isVector!A)
{
  static if(isVector!A) return a.generateVector!(bool, a => !a); //returns bvec, not vec, like in opengl
                   else return !a;
}

private void unittest_VectorRelationalFunctions(){
  {
    assert(lessThan   (1, 2)); //original functionality
    assert(greaterThan(2, 1));

    assert([3,1,2].sort!lessThan   .equal([1,2,3])); //lessThan    as a predicate in sort()
    assert([3,1,2].sort!greaterThan.equal([3,2,1])); //greaterThan as a predicate in sort()
    const a = vec3(1,2,3), b = uvec3(3,2,1);
    assert(lessThan        (a, b) == bvec3(true, false, false));
    assert(lessThanEqual   (a, b) == bvec3(true, true , false));
    assert(greaterThan     (b, a) == bvec3(true, false, false));
    assert(greaterThanEqual(b, a) == bvec3(true, true , false));
  }
  { // original equal. Copied from Dlang documentation
    int[4] a = [ 1, 2, 4, 3 ];
    assert(!equal(a[], a[1..$]));
    assert(equal(a[], a[]));
    assert(equal!((a, b) => a == b)(a[], a[]));

    // different types
    double[4] b = [ 1.0, 2, 4, 3];
    assert(!equal(a[], b[1..$]));
    assert(equal(a[], b[]));
  }

  assert(!equal(1,2) && equal(2,2)); //extended functionality: works for scalar too
  assert(equal([1,2],[1.0,2])); //but it works well for ranges.
  assert(equal(vec2(2,2), 2) && equal(2, vec2(2,2)));
  assert(equal(vec2(1,3), uvec2(1,3)));
  assert(!notEqual(vec2(1,3), uvec2(1,3)));
  assert(notEqual(vec2(0,3), uvec2(1,3)));

  assert([true, true, true].all);
  assert([false, false].all!"!a");
  assert(![true, false].all);
  assert(all(bvec3(1)) && !all(vec2(0,1)));
  assert(all(true)); //new functionality to enable vectorScalar usage

  assert([9, 0].any!"a==9");
  assert([true, false].any && !([0].any));
  assert(any(bvec3(0,1,0)) && !any(vec2(0)));

  assert("   H".find!(not!(unaryFun!`a==' '`)) == "H"); // original std.functional.not functionality
  assert(bvec3(0,1,0).not == bvec3(1,0,1));
  assert( vec3(0,1,0).not == bvec3(1,0,1)); // vec -> bvec
  assert( vec3(vec3(0,1,0).not) == bvec3(1,0,1)); //casts bool -> vec
  assert(not(true) == false);
}


////////////////////////////////////////////////////////////////////////////////
///  Bounds                                                                  ///
////////////////////////////////////////////////////////////////////////////////


enum isBounds(T) = is(T) && __traits(compiles, T.low, T.high, T.VectorLength);

template CommonBoundsType(A...){
  static if(CommonVectorLength!A > 1) alias CommonBoundsType = Bounds!(CommonVectorType!A);
                                 else alias CommonBoundsType = Bounds!(CommonScalarType!A);
}

struct Bounds(VT){
  VT low = 0, high = -1;

  enum VectorLength = CommonVectorLength!VT;
  alias ComponentType = ScalarType!VT;
  enum BoundsTypeName = (ComponentTypePrefix!ComponentType.among("UNDEF", "u", "b")) ? VT.stringof
                      : ComponentTypePrefix!ComponentType ~ "bounds" ~ (VectorLength>1 ? VectorLength.stringof : "");
  enum Null = Bounds!VT.init;

  this(A...)(in A a){
    static if(A.length==0){
      //default invalid bounds
    }else static if(A.length==1 && isBounds!(A[0])){ //another Bounds
      static assert(VectorLength == A[0].VectorLength, "dimension mismatch");
      low  = a[0].low ;
      high = a[0].high;
    }else static if(A.length==2){ //2 vectors or scalars
      low  = a[0];
      high = a[1];
    }else static if(A.length==4 && VectorLength==2){ // 4 scalars
      low [0] = a[0]; low [1] = a[1];
      high[0] = a[2]; high[1] = a[3];
    }else static if(A.length==6 && VectorLength==3){ // 6 scalars
      low [0] = a[0]; low [1] = a[1]; low [2] = a[2];
      high[0] = a[3]; high[1] = a[4]; high[2] = a[5];
    }else{
      static assert(0, "invalid arguments");
    }
  }

  this(R)(R r)
  if(isInputRange!R)
  {
    Bounds!(typeof(r.front)) bnd;
    r.each!(v => bnd |= v);
    this = bnd;
  }

  auto sorted(){
    typeof(this) res;
    if(valid){
      res.low  = min(low, high);
      res.high = max(low, high);
    }
    return res;
  }

  string toString() const {
    static if(VectorLength==1) return format!"%s(%s, %s)"(BoundsTypeName, low, high);
                          else return format!"%s(%(%s, %))"(BoundsTypeName, low[]~high[]);
  }

  bool valid() const{
    return all(lessThanEqual(low, high)); // a zero size bounds is valid because it contains the first point of expansion
  }

  // multidimensional size
  auto size() const{ return max(high-low, 0); }

  static if(VectorLength==2) auto area  () const{ with(size) return x*y; }
  static if(VectorLength==3) auto volume() const{ with(size) return x*y*z; }

  auto opBinary(string op, T)(in T other) const
  {
    static if(op=="|"){ // extend with other bounds
      static if(isBounds!T){
        return other.valid ? this | other.low | other.high
                           : typeof(this | other.low).init;
      }static if(isInputRange!T){ //extend to array elements
        Unqual!(typeof(this)) bnd = this;
        other.each!(a => bnd|=a); //opt: can be optimized for valid() checking
        return bnd;
      }else{ //extend with a single element
        Bounds!(CommonVectorType!(typeof(low), T)) res;
        if(valid){
          res.low  = min(low , other),
          res.high = max(high, other);
        }else{
          res.low = res.high = other;
        }
        return res;
      }
    }else static if(op=="&"){ // union
      static assert(isBounds!T);
      Bounds!(CommonVectorType!(typeof(low), typeof(T.low))) res;
      if(valid && other.valid){
        res.low  = max(low , other.low );
        res.high = min(high, other.high);
        if(any(greaterThanEqual(res.low, res.high))) res = typeof(res).init;
      }
      return res;
    }else static if(op.among("+", "-", "*", "/")){ //shift, scale
      CommonBoundsType!(typeof(low), T) res;
      if(valid){
        res.low  = mixin("low" , op, "other");
        res.high = mixin("high", op, "other");
      }
      return res;
    }else{
      static assert(0, "invalid operation");
    }
  }

  auto opOpAssign(string op, T)(in T other){
    this = mixin("this", op, "other");
    return this;
  }

  bool opEquals(T)(in T other) const {
    return valid ? low==other.low && high==other.high
                 : !other.valid;
  }

  bool approxEqual(T)(in T other, float maxDiff = approxEqualDefaultDiff) const{
    static assert(isBounds!T && __traits(compiles, low == other.low));
    return low.approxEqual(other.low) && high.approxEqual(other.high);
  }

  bool contain(string cfg = "[]", T)(in T other) const{ //closed closed
    static assert(cfg.length==2 && "[(".canFind(cfg[0]) && "])".canFind(cfg[1]), "invalid open/close config. // [] closed, () open");

    static if(cfg[0]=='[') alias f1 = greaterThanEqual; else alias f1 = greaterThan;
    static if(cfg[1]==']') alias f2 = lessThanEqual   ; else alias f2 = lessThan   ;

    static if(isBounds!T) return contain!cfg(other.low) && contain!cfg(other.high);
                     else return all(f1(other, low) & f2(other, high));
  }

}

static foreach(T; AliasSeq!(float, double, int))
  static foreach(N; [1, 2, 3])
    static if(N==1) mixin(format!q{alias %sbounds = %s;}(ComponentTypePrefix!T, (Bounds!T).stringof));
               else mixin(format!q{alias %sbounds%s = %s;}(ComponentTypePrefix!T, N, Bounds!(Vector!(T, N)).stringof));

private void unittest_Bounds(){
  static assert(__traits(compiles, bounds3(1, 2)) && bounds3(1, 2)==bounds3(vec3(1), vec3(2)) );
  static assert(!__traits(compiles, bounds3(1, 2, 3, 4)));
  static assert(__traits(compiles, bounds3(1, 2, 3, 4, 5, 6)));

  auto b1 = bounds(1, 2);
  assert(b1.text == "bounds(1, 2)");

  auto b3 = ibounds3(1, 2, 3, 4, 5, 6);
  assert(b3.text == "ibounds3(1, 2, 3, 4, 5, 6)");

  auto b2 = dbounds2(1, 2, 3, 4);
  static assert(isBounds!(typeof(b2)));
  assert(b2.text == "dbounds2(1, 2, 3, 4)");

  assert(ivec2(2, 4)/2 == ivec2(1, 2));

  assert(b2 + ivec2(100, 200) == bounds2(101, 202, 103, 204));
  assert(b2 - ivec2(100, 200) == bounds2(-99, -198, -97, -196));
  assert(b2 / 2 == bounds2(vec2(0.5, 1), vec2(1.5, 2)));
  assert(b2 * vec2(1000, 1000)== bounds2(1000, 2000, 3000, 4000));

  assert(bounds2(1, 2, 3, 4) == bounds2(1.0, 2, 3, 4));
  assert(bounds2(1, 2, 3, 4).approxEqual(bounds2(1.0001, 2, 3, 4.0001)));

  {// extend tests   op=="|"
    bounds2 bnd;
    vec2[] arr = [vec2(3, 4), vec2(9, 11), vec2(14, 2)];
    arr.each!(a => bnd|=a);
    assert(bnd == bounds2(min(arr), max(arr))); //this also tests min[] for ranges
    assert((bounds2.init | arr) == bnd); // | operator for ranges
    assert(bounds2(arr) == bnd); // constructor
  }
  {// intersection test  op=="&"
    assert((ibounds2(9, 19, 15, 25) & ibounds2(9, 19, 15, 25)) == ibounds2(9, 19, 15, 25));
    assert((ibounds2(11, 19, 17, 25) & ibounds2(12, 18, 18, 24)) == ibounds2(12, 19, 17, 24));
    assert((ibounds2(19, 4, 25, 10) & ibounds2(18, 0, 24, 6)) == ibounds2(19, 4, 24, 6));
    assert((ibounds2(-1, 4, 5, 10) & ibounds2(0, -1, 6, 5)) == ibounds2(0, 4, 5, 5));
    assert(!(ibounds2(16, 13, 22, 19) & ibounds2(18, 5, 24, 11)).valid);
  }
}

////////////////////////////////////////////////////////////////////////////////
///  Tests                                                                   ///
////////////////////////////////////////////////////////////////////////////////


//todo: when the ide supports unit testing, this should be private. Also needs real unittest{} blocks.
void unittest_main(){
  version(assert){}else enforce(0, "Turn on debug build for asserts.");

  unittest_utilityStuff;
  unittest_Vectors;
  unittest_Matrices;
  unittest_AngleAndTrigFunctions;
  unittest_ExponentialFunctions;
  unittest_CommonFunctions;
  unittest_GeometricFunctions;
  unittest_MatrixFunctions;
  unittest_VectorRelationalFunctions;
  unittest_Bounds;
}

unittest{ unittest_main; }