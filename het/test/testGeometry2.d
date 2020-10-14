//@exe
//@import c:\d\libs
//@ldc
//@compile -m64 -mcpu=athlon64-sse3 -mattr=+ssse3
///@release
//@debug

import het.utils, std.traits;

// publicly import std modules whose functions are gonna be overloaded here.
public import std.algorithm, std.math;

private enum swizzleRegs = ["xyzw", "rgba", "stpq"];
private bool validLvalueSwizzle(string def){ return swizzleRegs.map!(r => canFind(r, def)).any; }
private enum ComponentTypePrefix(CT) = is(CT==float) ? "" : is(CT==double) ? "d" : is(CT==bool) ? "b" : is(CT==int) ? "i" : is(CT==uint) ? "u" : CT.stringof;

private bool validRvalueSwizzle(string def){
  if(def.startsWith('_')) def = def[1..$]; //_ is allowed at the start because of the constants 0 and 1
  if(!def.length.inRange(1, 4) || validLvalueSwizzle(def)) return false;

  return swizzleRegs.map!(r => def.map!(ch => "01".canFind(ch) || r.canFind(ch.lc)).all).any;
}


////////////////////////////////////////////////////////////////////////////////
///  Vector                                                                  ///
////////////////////////////////////////////////////////////////////////////////

enum isVector(T) = is(T.VectorType);

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
                   else alias A = T;
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

struct Vector(CT, int N)
if(N.inRange(2, 4)){
  alias VectorType = typeof(this);
  alias ComponentType = CT;
  enum VectorTypeName = ComponentTypePrefix!CT ~ "vec" ~ N.text;

  CT[N] array = [0].replicate(N).array; //default is 0,0,0, not NaN.  Just like in GLSL.
  enum length = N;

  alias array this;

  //note : alias this enables inplicit conversion, but fucks up the ~ concat operator
  //ref auto opIndex(size_t i){ return array[i]; } const opIndex(size_t i){ return array[i]; }

  string toString() const { return VectorTypeName ~ "(" ~ array[].map!text.join(", ") ~ ")"; }

  private void construct(int i, T, Tail...)(in T head, in Tail tail){ // this is based on the gl3n package
    static if(i >= length){
      static assert(false, "Vector constructor: Too many arguments");
    }else static if(isDynamicArray!T) {
      static assert((Tail.length == 0), "Vector constructor: Dynamic array can only be the last argument");
      enforce(i+head.length <= array.length, "Vector constructor: Dynamic array too large");
      array[i..i+head.length] = head[].to!(CT[]);
      //further construction stops
    }else static if(isStaticArray!T){
      static foreach(j; 0..head.length) array[i+j] = head[j].to!CT;
      construct!(i + head.length)(tail);
    }else static if(isVector!T){ //another vec
      construct!i(head.array, tail);
    }else static if(isNumeric!T){
      array[i] = head.to!CT;
      construct!(i+1)(tail);
    }else static if(is(T==bool)){
      array[i] = head ? 1 : 0;
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

    void setAll(T)(in T a){ array[] = a.to!CT; }

    static if(args.length==1 && __traits(compiles, setAll(args[0]))){
      //One can also use one number in the constructor to set all components to the same value
      setAll(args[0]);
    }else static if(args.length==1 && isVector!(A[0]) && A[0].length>=length){
      //Casting a higher-dimensional vector to a lower-dimensional vector is also achieved with these constructors:
      static foreach(i; 0..length) array[i] = args[0].array[i];
    }else{
      construct!0(args);
    }
  }

  enum Null = typeof(this).init;
  enum NaN (){ return Vector!(CT, N)(float.init); }
  bool isNull() const { return this == Null; }
  bool isNaN() const { static if(is(CT==bool) || isIntegral!CT) return false; else { return std.math.isNaN(array[0]); } }

  bool opEquals(T)(in T other) const { return other.array == array; }

  static auto basis(int n){ VectorType v;  v[n] = 1.to!ComponentType;  return v; }

  // swizzling ///////////////////////

  static foreach(regs; swizzleRegs)
    static foreach(len; 1..N+1)
      static foreach(i; 0..N-len+1)
        static if(len==1){
          mixin(format!q{auto %s() const { return array[%s]; }}(regs[i], i));
          mixin(format!q{ref  %s()       { return array[%s]; }}(regs[i], i));
        }else{
          mixin(format!q{auto %s() const { return        Vector!(CT, %s)   (array[%s..%s]) ; }}(regs[i..i+len], len, i, i+len));
          mixin(format!q{ref  %s()       { return *(cast(Vector!(CT, %s)*) (array[%s..%s])); }}(regs[i..i+len], len, i, i+len));
        }

  auto opDispatch(string def)() const
  if(validRvalueSwizzle(def))
  {
    static if(def.startsWith('_')){
      return opDispatch!(def[1..$]);
    }else{
      static if(def.length==1){
        return mixin(def[0]);
      }else{
        Vector!(CT, mixin(def.length)) res;
        static foreach(i, ch; def)
          res[i] = mixin(ch==ch.lc ? "" : "-", ch.lc);
        return res;
      }
    }
  }

  auto opUnary(string op)() if(op.among("++", "--")) {
    VectorType res;
    static foreach(i; 0..length) mixin(format!"res[%s] = %s array[%s];"(i, op, i));
    return res;
  }

  auto opUnary(string op)() const{
    VectorType res;
    static foreach(i; 0..length) mixin(format!"res[%s] = %s array[%s];"(i, op, i));
    return res;
  }

  auto opBinary(string op, T)(in T other) const{
    static if(op=="~"){ //concat
      return [this] ~ other; //todo: this fails
    }else{
      static if(isNumeric!T){
        CommonVectorType!(VectorType, T) res;
        static foreach(i; 0..length) res[i] = mixin(format!"this[%d] %s other"(i, op));
      }else static if(isVector!T){
        CommonVectorType!(VectorType, T) res;
        static foreach(i; 0..length) res[i] = mixin(format!"this[%d] %s other[%s]"(i, op, i));
      }else static if(op=="*" && isMatrix!T && T.height==length){ // vector * matrix
        auto res = other.transpose * this;
      }else{
        static assert(false, "invalid operation");
      }
      return res;
    }
  }

  auto opBinaryRight(string op, T)(in T other) const{
    static if(isNumeric!T){
      CommonVectorType!(VectorType, T) res;
      static foreach(i; 0..length) res[i] = mixin(format!"other %s this[%d]"(op, i));
    }else{
      static assert(false, "invalid operation");
    }
    return res;
  }

  auto opOpAssign(string op, T)(in T other){
    this = mixin("this", op, "other");
    return this;
  }

  bool approxEqual(T)(in T other, float maxDiff = 1e-3) const{
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


////////////////////////////////////////////////////////////////////////////////
///  Matrix                                                                  ///
////////////////////////////////////////////////////////////////////////////////

enum isMatrix(T) = is(T.MatrixType);

struct Matrix(CT, int N, int M)
if(N.inRange(2, 4) && M.inRange(2, 4)){
  alias MatrixType = typeof(this);
  alias ComponentType = CT;
  enum MatrixTypeName = "mat" ~ (N==M ? N.text : N.text ~ 'x' ~ M.text);

  //mat N x M: A matrix with N columns and M rows. OpenGL uses column-major matrices, which is standard for mathematics users.
  Vector!(CT, M)[N] columns;
  enum width = N, height = M;
  enum length = N;

  alias columns this;

  //note : alias this enables inplicit conversion, but fucks up the ~ concat operator
  //ref auto opIndex(size_t i){ return columns[i]; } const opIndex(size_t i){ return columns[i]; }

  string toString() const { return MatrixTypeName ~ "(" ~ columns[].map!text.join(", ") ~ ")"; }

  private void construct(int i, T, Tail...)(T head, Tail tail) { // this is from gl3n library
    static if(i >= M*N) {
      static assert(false, "Matrix constructor: Too many arguments passed to constructor");
    }else static if(isNumeric!T) {
      columns[i / M][i % M] = head.to!CT;
      construct!(i + 1)(tail);
    }else static if(isVector!T && i+head.length<=N*M) {
      static foreach(j; 0..head.length) //just inject the vector
        columns[(i+j) / M][(i+j) % M] = head[j].to!CT;
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
        this[i][i] = val.to!CT;
    }

    static if(Args.length==1 && isNumeric!(Args[0])){ // Identity matrix
      setIdentity(args[0]);
    }else static if(Args.length==1 && isMatrix!(Args[0])){
      enum N2 = Args[0].width, M2 = Args[0].height; //cast matrices
      static foreach(i; 0..N)
        static foreach(j; 0..M)
          static if(i<N2 && j<M2) this[i][j] = args[0][i][j].to!CT;
                             else this[i][j] = (i==j ? 1 : 0).to!CT;
    }else{
      construct!0(args);
    }
  }

  //set or get as consequtive array. Automatically transposes back and forth.
  @property auto asArray() const {
    CT[] res;  res.reserve(N*M);
    foreach(j; 0..M) foreach(i; 0..N) res ~= this[i][j];
    return res;
  }

  @property void asArray(in CT[] arr) {
    int idx;
    foreach(j; 0..M) foreach(i; 0..N) this[i][j] = arr[idx++];
  }


  auto opBinary(string op, T)(in T other) const{
    static if(isNumeric!T){
      Matrix!(CommonType!(ComponentType, T), N, M) res;
      static foreach(i; 0..N) static foreach(j; 0..M) res[i][j] = mixin(format!"this[%d][%d] %s other"(i, j, op));
    }else static if(isMatrix!T){
      static if(op=="*"){
        static assert(T.height==width, "Incompatible matrices for multiplication. "~typeof(this).stringof~" * "~T.stringof);
        Matrix!(CommonType!(ComponentType, T.ComponentType), T.width, height) res;
        static foreach(j; 0..T.width) static foreach(i; 0..height){{
          typeof(res).ComponentType sum = 0;
          static foreach(k; 0..T.height)
            sum += this[k][i] * other[j][k];
          res[j][i] = sum;
        }}
      }else{
        static assert(T.width==width && T.height==height, "Size of matrices must be the same.");
        Matrix!(CommonType!(ComponentType, T.ComponentType), N, M) res;
        static foreach(i; 0..N) static foreach(j; 0..M) res[i][j] = mixin(format!"this[%d][%d] %s other[%d][%d]"(i, j, op, i, j));
      }
    }else static if(isVector!T&& op=="*"){
      static assert(T.length==width, "Incompatible matrix-vector for multiplication. "~typeof(this).stringof~" * "~T.stringof);
      Vector!(CommonType!(ComponentType, T.ComponentType), T.length) res;
      static foreach(i; 0..width){{
        typeof(res).ComponentType sum = 0;
        static foreach(k; 0..height)
          sum += columns[k][i] * other[k];
        res.array[i] = sum;
      }}
    }else{
      static assert(false, "invalid operation");
    }
    return res;
  }

  auto opBinaryRight(string op, T)(in T other) const{
    static if(isNumeric!T){
      Matrix!(CommonType!(ComponentType, T), N, M) res;
      static foreach(i; 0..N) static foreach(j; 0..M) res[i][j] = mixin(format!"other %s this[%d][%d]"(op, i, j));
      return res;
    }else{
      static assert(false, "invalid operation");
    }
  }

  auto opOpAssign(string op, T)(in T other){
    this = mixin("this", op, "other");
    return this;
  }

  bool approxEqual(T)(in T other, float maxDiff = 1e-3) const{
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
    mixin(format!q{alias %smat%s = mat%sx%s;}(ComponentTypePrefix!T, N, N, N));
  }
}


//! Functons /////////////////////////////////////////////////

//auto toRad(T)(T d){ return d*(PI/180); }
//auto toDeg(T)(T d){ return d*(180/PI); }

bool approxEqual(A, B, C)(in A a, in B b, in C maxDiff = 1e-3) { //this is my approxEqual. The one in std.math is too complicated
  return abs(a-b) <= maxDiff;
}


// todo: implement this
mixin template UnaryVectorCreate(CT, int N, string fun){
  enum _f(int i) = fun.replace("#", i.text);
  //StaticRange(0, N).StaticMap!(_f).stringof
  static if(N==2) mixin("Vector!(Unqual!CT, N)(%s, %s)"        .format(_f!0, _f!1            ));
  static if(N==3) mixin("Vector!(Unqual!CT, N)(%s, %s, %s)"    .format(_f!0, _f!1, _f!2      ));
  static if(N==4) mixin("Vector!(Unqual!CT, N)(%s, %s, %s, %s)".format(_f!0, _f!1, _f!2, _f!3));
}

// return mixin UnaryVectorCreate!(CT, A.length, "radians(a[#])");

private auto vectorScale(real factor, A)(in A a){  //scales a vector or scalar with factor on the input's precision
  static if(isVector!A){
    Vector!(typeof(vectorScale!factor(a[0])), A.length) res;
    static foreach(i; 0..A.length) res[i] = vectorScale!factor(a[i]);
    return res;
  }else{
    return a * cast(CommonType!(A, float)) factor;
  }
}

auto radians(A)(in A a){ return vectorScale!(PI/180)(a); }
auto degrees(A)(in A a){ return vectorScale!(180/PI)(a); }

// Angle & Trig. functions ///////////////////////////////////

// Exponential functions /////////////////////////////////////

// Common functionc //////////////////////////////////////////

private auto minMax(bool isMin, T, U)(in T a, in U b){

  auto comp(T, U)(in T a, in U b){
    return isMin ? std.algorithm.min(a, b) : std.algorithm.max(a, b);
  }

  static if(isNumeric!T && isNumeric!U){
    return comp(a, b);
  }else static if(isVector!T && isNumeric!U){
    CommonVectorType!(T, U) res;
    static foreach(i; 0..T.length) res.array[i] = comp(a.array[i], b);
    return res;
  }else static if(isNumeric!T && isVector!U){
    return minMax!isMin(b, a); //same but different order
  }else static if(isVector!T && isVector!U){
    static assert(T.length == U.length, "vector dimension mismatch");
    CommonVectorType!(T, U) res;
    static foreach(i; 0..T.length) res.array[i] = comp(a.array[i], b.array[i]);
    return res;
  }else{
    static assert("Invalid operation");
  }
}

// this is how to overload std stuff

auto min(T...)(in T args){ //note: std.algorithm.min is (T t)
  static if(anyVector!T)
    static if(T.length==2) return minMax!1(args[0], args[1]);
                      else return min(min(args[0..$-1]), args[$-1]);
  else return std.algorithm.min(args);
}

auto max(T...)(in T args){ //note: std.algorithm.max is (T t)
  static if(anyVector!T)
    static if(T.length==2) return minMax!0(args[0], args[1]);
                      else return max(max(args[0..$-1]), args[$-1]);
  else return std.algorithm.max(args);
}

auto clamp(T1, T2, T3)(in T1 val, in T2 lower, in T3 upper){
  static if(anyVector!(T1, T2, T3)) return max(lower, min(upper,val));
                               else return std.algorithm.clamp(val, lower, upper);
}

auto cmp(string pred, A, B)(in A a, in B b){ return std.algorithm.cmp!pred(a, b); }

auto cmp(A, B)(in A a, in B b){
  static if((std.traits.isNumeric!A || isVector!A) && (std.traits.isNumeric!B || isVector!B)){
    static if(anyVector!(A, B)){
      Vector!(int, CommonVectorLength!(A, B)) res;
      static foreach(i; 0..res.length) res[i] = cmp(a.vectorAccess!i, b.vectorAccess!i);
      return res;
    }else return a==b ? 0 : a<b ? -1 : 1;   //std.math.cmp(a, b); can only work on the excat same type.
  }else return std.algorithm.cmp(a, b);
}

auto mix(A, B, T)(in A a, in B b, in T t){
  static if(is(Unqual!T==bool)) return mix(a, b, int(t));
  static if(anyVector!(A, B, T)){
    CommonVectorType!(A, B, T) res;
    static foreach(i; 0..res.length) res[i] = mix(vectorAccess!i(a), vectorAccess!i(b), vectorAccess!i(t));
    return res;
  }else return a*(1-t) + b*t;
}


// Matrix functionc //////////////////////////////////////////

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

// Removes element i
auto minorVector(int i, T, int N)(in Vector!(T, N) v){
  Vector!(T, N-1) res;
  foreach(k; 0..N) if(k!=i) res[k<i ? k : k-1] = v[k];
  return res;
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


////////////////////////////////////////////////////////////////////////////////
///  Tests                                                                   ///
////////////////////////////////////////////////////////////////////////////////


void testVectorsAndMatrices(){
  // https://en.wikibooks.org/wiki/GLSL_Programming/Vector_and_Matrix_Operations

  forceAssertions;

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

  { // Operators: If the binary operators *, /, +, -, =, *=, /=, +=, -= are used between vectors of the same type, they just work component-wise:
    vec3 a = vec3(1.0, 2.0, 3.0);
    vec3 b = vec3(0.1, 0.2, 0.3);
    vec3 c = a + b; // = vec3(1.1, 2.2, 3.3)
    vec3 d = a * b; // = vec3(0.1, 0.4, 0.9)
    assert(c == vec3(1.1, 2.2, 3.3) && d.approxEqual(vec3(0.1, 0.4, 0.9)));
  }
  { // For matrices, these operators also work component-wise, except for the *-operator, which represents a matrix-matrix product
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

  { // various tests of mine
    immutable v1 = vec4(1,2,3,0);
    Unqual!(typeof(v1)) v2 = v1;  assert(v1.z == 3);
    v2.z++;                       assert(v2.b == 4);
    assert(v1.gb == vec2(2, 3));
    assert(v2 == vec4(1, 2, 4, 0));
    v2.gba = vec3(10, [119, 12]);
    auto f = dvec4(vec2([1,2]).yx, vec2(5, 6).y1);
    assert(f == dvec4(2, 1, 6, 1));
    assert(v2.rR01 == vec4(1, -1, 0, 1)); //Capital letter means negative
    assert(vec3(1,2,3)+dvec3(5,6,7) == dvec3(6, 8, 10));
    assert(vec3(1,2,3)*10.5f == vec3(10.5, 21, 31.5));
    assert(10.5*vec3(1,2,3) == vec3(10.5, 21, 31.5));
    assert(bvec3.basis(2) == bvec3(false, false, true)); // bool basis vector test

    vec4 b;  b.yz = [5, 6];    assert(b == vec4(0, 5, 6, 0));
    b.yz = 55;                 assert(b == vec4(0, 55, 55, 0));  //side effect: b.y and b.y both = 55
    b *= vec4(5)._11xx;        assert(b == vec4(0, 55, 275, 0)); //55*5 = 275

    auto i1 = ivec2(2, 3);  i1 <<= 3;  i1 = -i1 + 5;  i1 = ++i1;  i1 = ~i1;  i1++;
    assert(i1 == ivec2(10, 18));

    vec3[] va = [vec3(4)] ~ [vec3(5)]; //always have to use [], because of alias this
    va ~= vec3(6);
    assert(va == [vec3(4), vec3(5), vec3(6)]);

    assert(3*mat2(2) == mat2(6, 0, 0, 6));
    assert(mat2(1)+mat2(2) == mat2(3, 0, 0, 3));

    assert(mat2x3(vec2(1,2), 3, 4, vec2(5,6)) == mat2x3(1,2,3,4,5,6));
    assert(mat2(vec4(3)) == mat2(3,3,3,3));
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
    dmat2 m1 = mat2(vec4(1));
  }
  { // Angle & Trig. functions
    static assert(is(typeof(radians(1   ))==float ));
    static assert(is(typeof(radians(1.0f))==float ));
    static assert(is(typeof(radians(1.0 ))==double));
    static assert(is(typeof(radians(1.0L))==real  ));

    assert(format!"%.15f"(PI) == "3.141592653589793"); //check PI for at least double precision
    assert(360.radians.approxEqual(6.28319, 1e-5));
    assert(7592.radians.degrees.approxEqual(7592));
    assert(vec2(180, 360).radians.approxEqual(vec2(6.28319/2, 6.28319), 1e-5));
    assert(PI.degrees == 180 && is(typeof(PI.degrees)==real));


  }
  { // Exponential functions

  }
  { // Common functions
    auto a = vec3(1, 2, 3);
    auto b = vec3(4, 0, 6);
    assert(min(a, b) == vec3(1, 0, 3));
    assert(min(a, 2) == vec3(1, 2, 2));
    assert(min(b, 5) == vec3(4, 0, 5));
    assert(max(b, 5) == vec3(5, 5, 6));
    assert(min(2, a) == vec3(1, 2, 2));
    assert(min(5, b) == vec3(4, 0, 5));
    assert(max(5, b) == vec3(5, 5, 6));

    assert(vec3(1,2,3).clamp(1.5, 2.5) == vec3(1.5, 2, 2.5));
    assert(ivec3(8).clamp(1.5, vec3(4, 5, 6)) == vec3(4, 5, 6));

    assert(mix(vec2(1,2), vec2(2, 4), 0.5f) == vec2(1.5, 3));
    assert(mix(vec2(1,2), 2, 0.5) == vec2(1.5, 2));

    assert(mix(Vector!(ubyte, 2)(2,3), Vector!(ubyte, 2)(4,5), false) == vec2(2, 3));
    assert(mix(Vector!(ubyte, 2)(2,3), Vector!(ubyte, 2)(4,5), true ) == vec2(4, 5));

    assert(cmp("abc", "abc")==0 && cmp("abc", "abcd")<0 && cmp("bbc", "abc"w)>0 && cmp([1L, 2, 3], [1, 2])>0 && cmp!"a<b"([1L, 2, 3], [1, 2])>0);
    assert((cmp(1, 2)>0)==(std.math.cmp(1.0,2.0)>0));
    assert(cmp(vec2(1),1)==vec2(cmp(1,1)) && cmp(vec2(1),2)==vec2(cmp(1,2)) && cmp(vec2(2),1)==vec2(cmp(2,1)));

    //assert(step(vec2(1, 2, 3), 2) == vec2(0, 1, 1));
  }
  { // Matrix functions
    assert(matrixCompMult(mat2(1, 2, 3, 4), mat2(vec4(2))) == mat2(2, 4, 6, 8));

    //transpose
    assert(mat2x3(vec3(1,2,3),vec3(4,5,6)).transpose == mat3x2(1,4,2,5,3,6));
    assert(mat2x3(vec3(1,2,3),vec3(4,5,6)).transpose.transpose == mat2x3(vec3(1,2,3),vec3(4,5,6)));

    //outer product
    assert(outerProduct(vec3(3,2,1), vec4(7,2,3,1)) == mat4x3(21,14,7, 6,4,2, 9,6,3, 3,2,1));

    //determinant
    assert(determinant(mat2(4, 3, 6, 8)) == 14);
    assert(mat3(6,4,2,1,-2,8,1,5,7).determinant == -306);
    assert(mat4(4,0,0,0, 3,1,-1,3, 2,-3,3,1, 2,3,3,1).determinant == -240);

    //inverse
    assert(mat2(4,2,7,6).inverse.approxEqual( mat2(.6, -.2, -.7, .4) ));
    assert(mat3(3,2,0, 0,0,1, 2,-2,1).inverse.approxEqual( mat3(.2,-.2,.2, .2,.3,-.3, 0,1,0) ));
    assert(mat4(-3,-3,-2,1, -1,1,3,-2, 2,2,0,-3, -3,-2,1,1).inverse.approxEqual(mat4(-1.571, -2.142, 2, 3.285,  2,3,-3,-5, -1,-1,1,2, 0.285,0.571,-1,-1.142)));
  }

  //https://www.shadertoy.com/view/XsjGDt

}

void main(){ application.runConsole({
  //__traits(allMembers, vec4).stringof.print;

  testVectorsAndMatrices;

}); }
