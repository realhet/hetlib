module het.math; /+DIDE+/

version(/+$DIDE_REGION+/all)
{
	//Vector ////////////////////////////////////
	
	//Todo: vec2 lvalue-be lehessen assignolni ivec2 rvalue-t!
	//Todo: ldc fast math http://johanengelen.github.io/ldc/2016/10/11/Math-performance-LDC.html
	//Todo: implicit cast from int to float in function args: vect, bounds, miageci van még...
	
	
	//This module replaces and extends the interface of std.math.
	//Anything usefull in std.math should wrapped here to support vector/scalar operations.
	//This is to ensure, that there will be no conflicting orevload sets between this module and std.math.
	//
	//Notes:
	//Avoid importing std.moth in projects, or else it will lead to ambiguity errors because the function names are the same.
	//Don't use het.utils in this module, het.utils will use this and publicly import this.
	
	//imports ///////////////////////////////////////////
	
	//static import because all imported and extended names must be fully qualified.
	static import std.math; 
	
	//important constants from std.math
	public import std.math : E, PI;  enum Ef = float(E), PIf = float(PI); 
	enum π = PIf, ℯ = Ef; 
	
	public import std.math: NaN, getNaNPayload, hypot, evalPoly = poly, isClose; 
	
	static import std.complex; 
	public import std.complex : Complex, norm, arg, fromPolar, expi; 
	enum isComplex(T) = is(T==Complex!F, F); 
	alias ℂ = Complex!float; 
	
	//publicly import std modules whose functions are gonna be overloaded/extended/hijacked here.
	public import std.string, std.uni;    //std.string publicly imports std.algorithm, so it MUST be publicly imported from here.
	public import std.algorithm; //extends : cmp, any, all, equal, min, max, sort
	public import std.functional; //extends: lessThan, greaterThan, not
	
	//import locally used things.     //must not import het.utils to keep het.math simle and standalone
	import std.format : format; 
	import std.conv : text, stdto = to; 
	import std.array : replicate, split, replace, join, array, staticArray; 
	import std.range : iota, isInputRange, ElementType, empty, front, popFront, take, padRight, join, retro; 
	import std.traits : 	Unqual, isDynamicArray, isStaticArray, isNumeric, isSomeString, isIntegral, isUnsigned, isFloatingPoint, 
		CommonType, ReturnType, isPointer; 
	import std.meta	: AliasSeq, allSatisfy, anySatisfy; 
	
	import std.exception	: enforce; 
	import std.stdio	: write, writeln; 
	
	//quantities support
	
	/*
		import quantities.compiletime;
		
		enum isFloatingPointOrQuantity(T) = isFloatingPoint!T || isQuantity!T;
		enum isNumericOrQuantity(T) = isNumeric!T || isQuantity!T;
	*/
	
	//utility stuff ////////////////////////////////////////////////////
	
	private enum approxEqualDefaultDiff = 1e-3f; 
	
	//Todo: use Phobos's isClose instead of my own approxEqual!
	
	//Todo: std.conv.to is flexible, but can be slow, because it calls functions and it checks value ranges. Must be tested and optimized if needed with own version.
	
	/+
		Todo: anonym structs ans unions
		/+
			Code: struct vec2
			{
			    float x, y;
			}
			
			struct vec3
			{
			    union {
			        struct { 
														 float x; 
														 union { 
			                struct { 
			                    float y, z; 
																		 } 
																		 vec2 yz; 
			            } 
										 }
										 struct { 
			            vec2 xy; 
			        }
			    }
			}
			
			void main()
			{
						 auto v = vec3(1, 2, 3);
						 
						 writeln(v); writeln(v.x); writeln(v.y); writeln(v.z); writeln(v.xy);
						 writeln(&v.yz); writeln(&v.x); writeln(&v.y); writeln(&v.z); writeln(&v.xy);
						 writeln(&v.yz);
						 
			}
		+/
	+/
	
	version(none)
	{
		struct vec2
		{
			float 	x,
				y; 
		} 
		
		struct vec3
		{
			union 
			{
				struct 
				{
					float x; 
					union 
					{
						struct 
						{
							float 	y,
								z; 
						} 
						vec2 yz; 
					} 
				} 
				struct 
				{ vec2 xy; } 
			} 
		} 
		
		
		
		struct vec4
		{
			union 
			{
				struct 
				{
					vec3 xyz; 
					float w; 
				} 
				struct 
				{
					float _x; 
					vec3 yzw; 
				} 
				struct 
				{
					float _xy; 
					vec2 zw; 
				} 
			} 
		} 
		
	}
	
	version(/+$DIDE_REGION GenericArg+/all)
	{
		public {
			struct GenericArg(string N="", T)
			{
				alias type = T; enum name = N; 
				
				T value; 
				alias value this; 
			} 
			
			alias 名 = genericArg; //Todo: This way it can be compressed. Only 3 chars instead of 10.
			
			enum isGenericArg(A) = is(A==GenericArg!(N, T), string N, T); 
			enum isGenericArg(A, string name) = is(A==GenericArg!(N, T), string N, T) && N==name; 
			
			/// pass a generic arg to a function
			auto genericArg(string N="", T)(in T p)
			{ return GenericArg!(N, T)(p); } 
			
			/// cast anything to GenericArg
			auto asGenericArg(A)(in A a)
			{ static if(isGenericArg!A) return a; else return genericArg(a); } 
			
			auto asGenericArgValue(A)(in A a)
			{ static if(isGenericArg!A) return a.value; else return a; } 
		} 
	}
	
	/// myto: scalar conversion used in smart-constructors
	private Tout myto(Tout, Tin)(in Tin a)
	{
		static if(is(Tin==bool))	return Tout(a ? 1 : 0); 
		else	return a.stdto!Tout; 
	} 
	
	
	/// converts numbers to text, includes all the digits stored in the original type.
	string text_precise(T)(in T a)
	{
		static if(isFloatingPoint!T)
		{
			//Note: Dlang .dig property reports less digits than actually needed to cover all mantissa bits.
			static if(is(Unqual!T == float ))
			return a.format!"%.8g"; 
			else
			return a.format!"%.17g"; 
		}
		else static if(isIntegral!T)
		{ return a.text; }
		else
		static assert(0, "invalid type"); 
	} 
	
	private enum swizzleRegs = ["xyzw", "rgba", "stpq"]; 
	
	private enum ComponentTypePrefix(CT) =	 is(CT==float	) ? ""	:  //rgb and rgba handled specially
		 is(CT==double	) ? "d"	:
		 is(CT==bool	) ? "b"	:
		 is(CT==int	) ? "i"	:
		 is(CT==uint	) ? "u"	:
		 "UNDEF"; 
	
	private bool validRvalueSwizzle(string def)
	{
		if(def.startsWith('_')) return validRvalueSwizzle(def[1..$]); //_ is allowed at the start because of the constants 0 and 1
		
		if(!def.length.inRange(1, 4)) return false; //too small or too long
		
		//LvalueSwizzles are not included. Those are midex in.  (LValue swizzle examples: x, xy, yzw, those that stay on a contiguous memory area)
		if(def.validLvalueSwizzle) return false; 
		
		return swizzleRegs.map!(r => def.map!(ch => "01lL".canFind(ch) || r.canFind(ch.toLower)).all).any; 
	} 
	
	private bool validLvalueSwizzle(string def)
	{ return def.length.inRange(1, 4) && swizzleRegs.any!((r)=>(r.canFind(def))); } 
	
	
	enum isVector(T) = is(T==Vector!(CT, N), CT, int N); 
	enum isScalar(T) = is(T==bool) || isNumeric!T; 
	
	
	private enum anyVector(T...) = anySatisfy!(isVector, T); 
	
	private int FirstVectorLength(T...)() {
		int res; 
		static foreach(t; T)
		static if(isVector!t) res = cast(int) t.length; 
		return res; 
	} 
	
	private template OperationResultType(string op, A, B)
	{
		static if(op.among("<<", ">>", ">>>"))	alias OperationResultType = A; 
		else	alias OperationResultType = CommonType!(A, B); 
	} 
	
	/// T is a combination of vector and scalar parameters
	/// returns the common vector length if there is one, otherwise stops with an assert;
	int CommonVectorLength(T...)()
	{
		static if(!T.length)	return 0; 
		else static if(!anyVector!T)	return 1; 
		else	{
			enum len = FirstVectorLength!T; 
			foreach(t; T) static assert(!isVector!t || t.length==len, "vector dimension mismatch"); 
			return len; //assume all are scalar
		}
	} 
	
	alias VectorLength = CommonVectorLength; 
	
	template ScalarType(T) {
		static if(isVector!T)	alias A = T.ComponentType; 
		else static if(isMatrix!T)	alias A = T.ComponentType; 
		else static if(isBounds!T)	alias A = T.VT.ComponentType; 
		else	alias A = T; 
		
		alias ScalarType = Unqual!A; 
	} 
	
	template CommonScalarType(T...)
	{
		static assert(T.length>=1); 
		static if(T.length==1)	alias CommonScalarType = ScalarType!(T[0]); 
		else	alias CommonScalarType = CommonType!(ScalarType!(T[0]), CommonScalarType!(T[1..$])); 
	} 
	
	private alias CommonVectorType(Types...) = Vector!(CommonScalarType!Types, CommonVectorLength!Types); 
	
	/// helper to access scalar and vector components in arguments.
	auto vectorAccess(int idx, T)(in T a) {
		static if(isVector!T) return a[idx]; 
		else return a; 
	} 
	
	private void unittest_utilityStuff()
	{
		assert(validRvalueSwizzle("_01yx") && validRvalueSwizzle("bgr1")); 
		assert(!validRvalueSwizzle("xy")); //false: this is Lvalue swizzle
		assert(!validRvalueSwizzle("xa")); //false: mixture of divverent swizzle variables
		
		assert(!anyVector!(int, float) && anyVector!(float, vec2)); 
		assert(FirstVectorLength!(float, vec3)==3 && FirstVectorLength!(float, int)==0); 
		assert(CommonVectorLength!()==0 && CommonVectorLength!(int)==1 && CommonVectorLength!(int, vec3)==3); 
		
		assert(is(CommonScalarType!(int, float, dvec3, mat2)==double)); 
		
		assert(vectorAccess!2(5)==5 && vectorAccess!2(vec3(1,2,3))==3); 
	} 
}version(/+$DIDE_REGION+/all)
{
	//Vector ////////////////////////////////////
		
	template Vector(CT, int N) //this template enables 1 element vectors.  Those are the type itself.
	if(N == 1)
	{ alias Vector = CT; } 
	
	struct Vector(CT, int N)
	if(N.inRange(2, 4))
	{
		version(/+$DIDE_REGION+/all)
		{
			alias VectorType	= typeof(this); 
			alias ComponentType	= CT; 
			enum VectorTypeName	=	is(VectorType==Vector!(ubyte, 2))	? "RG"	:
					is(VectorType==Vector!(ubyte, 3))	? "RGB"	:
					is(VectorType==Vector!(ubyte, 4))	? "RGBA"	:
					ComponentTypePrefix!CT != "UNDEF" 	? ComponentTypePrefix!CT ~ "vec" ~ N.stringof 	:
					VectorType.stringof; 
					
			static if(isFloatingPoint!CT)
			{
				CT[N] components = CT(0); //default is 0,0,0, not NaN.  Just like in GLSL.
			}
			else
			{ CT[N] components; }
					
			enum length = N; 
					
			alias components this; 
					
			//note : alias this enables inplicit conversion, but fucks up the ~ concat operator
			//ref auto opIndex(size_t i){ return components[i]; } const opIndex(size_t i){ return components[i]; }
					
			string toString() const
			{ return VectorTypeName ~ "(" ~ components[].map!text.join(", ") ~ ")"; } 
			
			private enum isAcceptableScalar(T) = isNumeric!T || is(T==bool); 
			
			version(all)
			{
				private void construct(int i, T, Tail...)(in T head, in Tail tail)
				{
					//pragma(msg, "$RECURSIVEBUG:", __PRETTY_FUNCTION__); 
					//this is based on the gl3n package
					static if(i >= length)
					{ static assert(false, "Vector constructor: Too many arguments"); }
					else static if(isDynamicArray!T)
					{
						static assert((Tail.length == 0), "Vector constructor: Dynamic array can only be the last argument"); 
						enforce(i+head.length <= components.length, "Vector constructor: Dynamic array too large"); 
						foreach(j; 0..head.length) components[i+j] = head[j].myto!CT; 
						//further construction stops, the length is unknown in CT
					}
					else static if(isStaticArray!T)
					{
						static foreach(j; 0..head.length) components[i+j] = head[j].myto!CT; 
						construct!(i + head.length)(tail); 
					}
					else static if(isVector!T /+Same code as static array+/)
					{
						static foreach(j; 0..head.length) components[i+j] = head[j].myto!CT; 
						construct!(i + head.length)(tail); 
					}
					else static if(isScalar!T)
					{
						components[i] = head.myto!CT; 
						construct!(i+1)(tail); 
					}
					else
					{
						//Todo: it sometimes give this as false error
						static assert(false, "Vector constructor: Unable to process argument of type. "~T.stringof); 
					}
				} 
				
				private void construct(int i)()
				{
					//pragma(msg, "$RECURSIVEBUG:", __PRETTY_FUNCTION__); 
					static if(
						/+handle the rare case of RGB -> RGBA conversion:+/
						is(CT==ubyte) && i==3 && length==4
					)
					{
						a = 255; //set default opaque alpha
					}
					else {
						/+Otherwise, the number of vector elements must match with this vector.+/
						static assert(i == length, "Vector constructor: Not enough arguments"); 
						//Todo: show the error's place in source: __ctor!(int, int, int)
					}
				} 
			}
			
			this(A...)(in A args)
			{
				//pragma(msg, "$RECURSIVEBUG:", __PRETTY_FUNCTION__); 
				static if(args.length==1 && is(ComponentType==ubyte) && (is(A[0]==int) || is(A[0]==uint) || isSomeString!(A[0])))
				{
					//special case for RG, RGB and RGBA: decodes it from one value
					static if(isSomeString!(A[0]))
					{ static assert(0, "not impl"); }
					else static if(is(A[0]==int) || is(A[0]==uint))
					{
						//Opt: raw data copy
						//Todo: kulonvalasztani a compile time es a runtime konvertalast. Ha egyaltalan lehet.
						//runtime: components = *(cast(typeof(components)*) &(args[0]));
						
						static foreach(i; 0..length) components[i] = (args[0]>>>(i*8)) & 0xFF; 
					}
					else
					{ static assert(0, "unhandler type: "~(A[0]).stringof); }
					//if the above version would be not ok... -> static foreach(i; 0..length) components[i] = cast(ubyte) args[0]>>(i*8);
				}
				else static if(args.length==1 && isScalar!(A[0])/+&& __traits(compiles, setAll(args[0]))+/)
				{
					//One can also use one number in the constructor to set all components to the same value
					components[] = args[0].myto!CT; 
				}
				else static if(args.length>1 && allSatisfy!(isScalar, A))
				{
					//Special case: All params are scalar.  Don't call construct() to avoid template recursion.
					static assert(args.length==length, "Invalid number of scalar arguments."); 
					static foreach(i; 0..length) components[i] = args[i].myto!CT; 
				}
				else static if(args.length==1 && isVector!(A[0]) && A[0].length>=length)
				{
					//Casting a higher-dimensional vector to a lower-dimensional vector is also achieved with these constructors:
					//Smaller vectors will go through construct()
					static foreach(i; 0..length) components[i] = args[0][i].myto!CT; 
				}
				else static if(args.length==1 && isDynamicArray!(A[0]))
				{
					enforce(args[0].length <= components.length, "Vector constructor: Dynamic array too large"); 
					foreach(i; 0..args[0].length) components[i] = args[0][i].myto!CT; 
				}
				else static if(args.length==1 && isStaticArray!(A[0]))
				{
					static assert(args[0].length <= components.length, "Vector constructor: Static array too large"); 
					static foreach(i; 0..args[0].length) components[i] = args[0][i].myto!CT; 
				}
				else
				{ construct!0(args); }
			} 
					
			auto opCast(T)() const
			{ static if(is(T==bool)) return !isnull(this); else return T(this); } 
					
			bool opEquals(T)(in T other) const
			{
				static if(isVector!T)
				{
					//vector==vector
					static assert(T.length == length); 
					static if(__traits(compiles, components==other.components))
					return other.components == components; 
					else
					return components.equal(other.components); 
				}
				else static if(__traits(compiles, components[0]==other))
				{
					//vector==scalar
					return components[0]==other; 
				}
				else
				static assert(0, "Incompatible types: "~typeof(this).stringof~" and "~T.stringof); 
			} 
			
			size_t toHash() const nothrow @safe
			{ return hashOf(components); } 
		}version(/+$DIDE_REGION+/all)
		{
			//raw data access for ubyte vectors.
			static if(is(ComponentType==ubyte))
			{
				static if(length==4)
				{
					uint raw() const
					{ return *(cast(uint*) &components); } 
					ref uint raw()
					{ return *(cast(uint*) &components); } 
				}
				else
				{
					@property uint raw() const
					{
						uint data = 0x00000000; 
						*(cast(Unqual!(typeof(components))*) &data) = components; 
						return data; 
					} 
					@property void raw(uint data)
					{ components = *(cast(Unqual!(typeof(components))*) &data); } 
				}
			}
					
			static auto basis(int n)
			{ VectorType v;  v[n] = ComponentType(1);  return v; } 
					
			//swizzling ///////////////////////
			
			//Todo: syntax highlight the swizzles. Colorize + monospace. Red, Green, Blue, Gray(Luma), White(1), Black(0)
			
			static foreach(regs; swizzleRegs)
			static foreach(len; 1..N+1)
			static foreach(i; 0..N-len+1)
			static if(len==1)
			{ mixin(format!q{inout ref %s() { return components[%s]; } }(regs[i], i)); }
			else
			{ mixin(format!q{inout ref %s() { return *cast(Vector!(CT, %s)*)(&components[%s]); } }(regs[i..i+len], len, i)); }
			
			//lumonosity swizzle
			@property auto l() const
			{
				static if(N>=3)
				return cast(CT) dot(rgb, grayscaleWeights); 
				else
				return r; 
			} 
					
			@property void l(A)(in A x)
			{
				r = cast(CT)x; 
				static if(N>=3) {
					g = r; 
					b = r; 
				}
			} 
					
			private template swizzleDecode(char ch)
			{
				enum lowerCh = ch.toLower; 
				enum isLower = ch==lowerCh; 
				static if(is(ComponentType==ubyte))
				{
					//for ubyte: 1 means 255, UpperCase means 255^
					enum swizzleDecode = ch=='1' ? "255" : cast(string)[lowerCh] ~ (isLower ? "" : "^255"); 
				}
				else
				{ enum swizzleDecode = (isLower ? "" : "-") ~ cast(string)[lowerCh]; }
			} 
					
			const opDispatch(string def)()
			if(def.validRvalueSwizzle)
			{
				static if(def.startsWith('_'))
				{ return opDispatch!(def[1..$]); }
				else
				{
					static if(def.length==1)
					{
						//Scalar value output
						return mixin(swizzleDecode!(def[0])); 
					}
					else
					{
						Vector!(CT, mixin(def.length)) res; //vector output
						static foreach(i, ch; def)
						res[i] = mixin(swizzleDecode!ch); 
						return res; 
					}
				}
			} 
					
			auto opUnary(string op)() const
			{
				VectorType res; 
				static foreach(i; 0..length) mixin(format!"res[%s] = cast(CT)(%s this[%s]);"(i, op, i)); 
				return res; 
			} 
					
			auto opUnary(string op)() if(op.among("++", "--"))
			{
				//same as above but NOT const
				VectorType res; 
				static foreach(i; 0..length) mixin(format!"res[%s] = cast(CT)(%s this[%s]);"(i, op, i)); 
				return res; 
			} 
					
			private static binaryVectorScalarOp(string op, A, B)(in A a, in B b)
			{
				alias CT = OperationResultType!(op, ScalarType!A, ScalarType!B); 
				return generateVector!(CT, (a, b) => mixin("a", op, "b") )(a, b); 
			} 
			
			auto opBinary(string op, T)(in T other) const
			{
				//Todo: associative array for right operand
				
				/+
					Todo: Use different approach: example in std.complex.Complax!T.opAssign
					It uses ref results.
					ref Complex opOpAssign(string op, C)(const C z)
				+/
				
				static if(isNumeric!T || isVector!T)
				{
					//vector * (vector/scalar)
					return binaryVectorScalarOp!op(this, other); 
				}
				else static if(op=="*" && isMatrix!T && T.height==length)
				{
					//vector * matrix
					return other.transpose * this; 
					//Opt: this is slow if it is not unrolled.
				}
				else static if(op=="in" && isBounds!T && T.VectorLength == length)
				{ return other.contains(this); }
				else static if(op=="in" && isImage!T && T.Dimension == length)
				{ return other.contains(this); }
				else static if(op.among("+", "*") && isBounds!T && T.VectorLength == length)
				{ return other.opBinary!op(this); }
				else
				{ static assert(false, "Unhandled operation: "~op~" "~T.stringof); }
			} 
					
			auto opBinaryRight(string op, T)(in T other) const
			{
				static if(isNumeric!T)
				return generateVector!(CommonScalarType!(VectorType, T), (a, b) => mixin("a", op, "b") )(other, this); 
				else
				static assert(0, "invalid operation"); 
			} 
					
			auto opOpAssign(string op, T)(in T other)
			{
				this = mixin("this", op, "other"); 
				return this; 
			} 
					
			bool approxEqual(T)(in T other, float maxDiff = approxEqualDefaultDiff) const
			{
				static assert(isVector!T && T.length==length); 
				static foreach(i; 0..length) if(abs(this[i]-other[i]) > maxDiff) return false; //Todo: refact
				return true; 
			} 
			
			static if(N==2)
			auto area() const
			{ return x*y; } 
			
			static if(N==3)
			auto volume() const
			{ return x*y*z; } 
			
					
		}
	} 
	
	private alias vectorElementTypes = AliasSeq!(float, double, bool, int, uint); 
	private enum vectorElementCounts = [2, 3, 4]; 
	
	static foreach(T; vectorElementTypes)
	static foreach(N; vectorElementCounts)
	mixin(format!q{alias %s = %s; }(Vector!(T, N).VectorTypeName, Vector!(T, N).stringof)); 
	
	//define aliases for colors
	
	alias RG8	= Vector!(ubyte, 2)	, RG	= RG8	,
	RGB8	= Vector!(ubyte, 3)	, RGB	= RGB8	,
	RGBA8 	= Vector!(ubyte, 4)	, RGBA 	= RGBA8	; 
	
	auto BGR (T...)(in T args)
	{ return RGB (args).bgr; } 
	auto BGRA(T...)(in T args)
	{ return RGBA(args).bgra; } 
	
	enum isColor(T) = isVector!T && T.length>=3 && (is(T.ComponentType==ubyte) || is(T.ComponentType==float)); 
	
	struct CardinalDirs
	{
		static immutable ivec2 = [.ivec2(0, 1), .ivec2(1, 0), .ivec2(0, -1), .ivec2(-1, 0)]; 
		static immutable vec2 = ivec2.map!(.vec2).array; 
		alias ivec2 this; 
		struct flipped
		{
			static immutable ivec2 = [.ivec2(0, -1), .ivec2(1, 0), .ivec2(0, 1), .ivec2(-1, 0)]; 
			static immutable vec2 = ivec2.map!(.vec2).array; 
			alias ivec2 this; 
		} 
	} 
	
	struct OrdinalDirs
	{
		private enum q = 0.70710678118; 
		static immutable ivec2 = [.ivec2(0, 1), .ivec2(1, 1), .ivec2(1, 0), .ivec2(1, -1), .ivec2(0, -1), .ivec2(-1, -1), .ivec2(-1, 0), .ivec2(-1, 1)]; 
		static immutable vec2 = [.vec2(0, 1), .vec2(q, q), .vec2(1, 0), .vec2(q, -q), .vec2(0, -1), .vec2(-q, -q), .vec2(-1, 0), .vec2(-q, q)]; 
		alias ivec2 this; 
		struct flipped
		{
			static immutable ivec2 = [.ivec2(0, -1), .ivec2(1, -1), .ivec2(1, 0), .ivec2(1, 1), .ivec2(0, 1), .ivec2(-1, 1), .ivec2(-1, 0), .ivec2(-1, -1)]; 
			static immutable vec2 = [.vec2(0, -1), .vec2(q, -q), .vec2(1, 0), .vec2(q, q), .vec2(0, 1), .vec2(-q, q), .vec2(-1, 0), .vec2(-q, -q)]; 
			alias ivec2 this; 
		} 
	} 
	
}version(/+$DIDE_REGION+/all)
{
	private void unittest_Vectors()
	{
		{
			//various tests of mine
			immutable v1 = vec4(1,2,3,0); 
			assert(v1.text == "vec4(1, 2, 3, 0)"); 
			Unqual!(typeof(v1)) v2 = v1; 	 assert(v1.z == 3); 
			v2.z++; 	 assert(v2.b == 4); 
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
			assert(bvec3.basis(2) == bvec3(false, false, true)); //bool basis vector test
				
			vec4 b;  b.yz	= [5, 6]; 	   assert(b == vec4(0, 5, 6, 0)); 
			b.yz = 55; 		assert(b	== vec4(0, 55, 55, 0)); 	//side effect: b.y and b.y both = 55
			b *= vec4(5)._11xx; 		assert(b == vec4(0, 55, 275, 0)); 	//55*5 = 275
				
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
				
			//the result type for shifting
			assert(is(typeof(ubyte(1) << ubyte(2)) == int));  //Dlang: is int at minimum
			assert(is(typeof(ubyte(1) << 2) == int)); 
			assert(is(typeof(Vector!(ubyte, 2)(1, 2)<<2) == Vector!(ubyte, 2) )); //with vectors: it preserves the type of the left hand operand.
				
			assert(~RGB(1,2,3) == RGB(254, 253, 252)); //unary ~
		}
		{
			//color vector tests
			RGB a = RGB(40, 80, 250); 
			RGB b = RGB(1, 0, 1); 
			static assert(is(typeof(a-b)==typeof(a))); //no int promotion, it stays byte
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
			assert(RGB(0x10).rR10 == RGBA(0x10, 255-0x10, 255, 0)); //-x -> 255-x  ;  1 -> 255
		}
		{
			//implicit conversions
			uvec2 a0 = ivec2(1, 2); 
			uvec3 a1 = ivec3(1, 2, 3); 
			uvec4 a2 = ivec4(1, 2, 3, 4); 
			vec2 a3 = ivec2(1, 2); 
			vec2 a4 = uvec2(1, 2); 
			dvec2 a5 = ivec2(1, 2); 
			dvec2 a6 = uvec2(1, 2); 
			dvec2 a7 = vec2(1, 2); 
		}
			
		//https://en.wikibooks.org/wiki/GLSL_Programming/Vector_and_Matrix_Operations
		{
			//Vectors can be initialized and converted by constructors of the same name as the data type:
			vec2 a = vec2(1.0, 2.0); 
			vec3 b = vec3(-1.0, 0.0, 0.0); 
			vec4 c = vec4(0.0, 0.0, 0.0, 1.0); 
			assert(a==vec2(1, 2) && b==vec3(-1, 0, 0) && c==vec4(0, 0, 0, 1)); 
		}
		{
			//One can also use one floating-point number in the constructor to set all components to the same value:
			vec4 a = vec4(4.0); 
			assert(a == vec4(4, 4, 4, 4)); 
		}
		{
			//Casting a higher-dimensional vector to a lower-dimensional vector is also achieved with these constructors:
			vec4 a = vec4(-1.0, 2.5, 4.0, 1.0); 
			vec3 b = vec3(a); //= vec3(-1.0, 2.5, 4.0)
			vec2 c = vec2(b); //= vec2(-1.0, 2.5)
			assert(c == b.xy && b == a.rgb && a==vec4(-1, 2.5, 4, 1) && b==vec3(-1, 2.5, 4) && c==vec2(-1, 2.5)); 
		}
		{
			//Casting a lower-dimensional vector to a higher-dimensional vector is achieved by supplying
			//these constructors with the correct number of components:
			vec2 a = vec2(0.1, 0.2); 
			vec3 b = vec3(0.0, a); //= vec3(0.0, 0.1, 0.2)
			vec4 c = vec4(b, 1.0); //= vec4(0.0, 0.1, 0.2, 1.0)
			assert(b == a._0xy && c == b.stp1 && a==vec2(0.1, 0.2) && b==vec3(0, 0.1, 0.2) && c==vec4(0, 0.1, 0.2, 1)); 
		}
		{
			//Components of vectors are accessed by array indexing with the []-operator (indexing starts with 0)
			//or with the .-operator and the element names x, y, z, w or r, g, b, a or s, t, p, q
			vec4 v = vec4(1.1, 2.2, 3.3, 4.4); 
			float a = v[3]; //= 4.4
			float b = v.w; //= 4.4
			float c = v.a; //= 4.4
			float d = v.q; //= 4.4
			assert([a,b,c,d].map!"a==4.4f".all); 
		}
		{
			//It is also possible to construct new vectors by extending the .-notation ("swizzling"):
			vec4 v = vec4(1.1, 2.2, 3.3, 4.4); 
			vec3 a = v.xyz; //= vec3(1.1, 2.2, 3.3)
			vec3 b = v.bgr; //= vec3(3.3, 2.2, 1.1)
			vec2 c = v.tt; //= vec2(2.2, 2.2)
			assert(a==vec3(1.1, 2.2, 3.3) && b==vec3(3.3, 2.2, 1.1) && c==vec2(2.2, 2.2)); 
		}
		{
			//Operators: If the binary operators *, /, +, -, =, *=, /=, +=, -= are used between vectors of the same type, they just work component-wise:
			vec3 a = vec3(1.0, 2.0, 3.0); 
			vec3 b = vec3(0.1, 0.2, 0.3); 
			vec3 c = a + b; //= vec3(1.1, 2.2, 3.3)
			vec3 d = a * b; //= vec3(0.1, 0.4, 0.9)
			assert(c == vec3(1.1, 2.2, 3.3) && d.approxEqual(vec3(0.1, 0.4, 0.9))); 
		}
	} 
}version(/+$DIDE_REGION Vector relational+/all)
{
	//Vector relational functions //////////////////////////////////////////
	
	//Todo: !!!!!!!!!!!!!!! atirni az osszes in-t auto ref-re es merni a sebesseget egy reprezentativ teszt segitsegevel.
	//A lessThan-ra eleg az in is. nem kell a safeOp!">"-ban levo auto ref.
	//Asm-ban a lessThan-t megneztem: azt szanaszet optimizalta, nem is volt lessThan a belso loopban.
	//de lehet, hogy az auto ref valamiert jobb. Nem veletlenul azt hasznaljak az std.functional.safeOp-ban.
	
	/// this is an extension to std.functional.safeOp. (lessThan, greaterThan, etc.)
	private auto mySafeOp(string op, A, B)(in A a, in B b)
	{
		static if(anyVector!(A, B))
		return generateVector!(bool, (a, b) => mixin("a"~op~"b") )(a, b); 
		else
		return std.functional.safeOp!op(a, b); 
	} 
	
	auto lessThan(A, B)(in A a, in B b)
	{ return mySafeOp!"<" (a, b); } 	 auto lessThanEqual(A, B)(in A a, in B b)
	{ return mySafeOp!"<="(a, b); } 
	auto greaterThan(A, B)(in A a, in B b)
	{ return mySafeOp!">" (a, b); } 	 auto greaterThanEqual(A, B)(in A a, in B b)
	{ return mySafeOp!">="(a, b); } 
	
	public import std.algorithm : equal; 
	auto equal(A, B)(in A a, in B b)
	if((isNumeric!A || isVector!A) || (isNumeric!B || isVector!B))
	{ return a == b; } 
	
	auto notEqual(A, B)(in A a, in B b)
	{ return !equal(a, b); } 
	
	public import std.algorithm: all; 
	bool all(alias pred = "a", A)(in A a)
	if(is(Unqual!A == bool) || isVector!A)
	{
		static if(isVector!A)
		return std.algorithm.all!pred(a[]); 
		else
		return std.algorithm.all!pred([a]); 
	} 
	
	public import std.algorithm: any; 
	bool any(alias pred = "a", A)(in A a)
	if(is(Unqual!A == bool) || isVector!A)
	{
		static if(isVector!A)
		return std.algorithm.any!pred(a[]); 
		else
		return std.algorithm.any!pred([a]); 
	} 
	
	public import std.functional: not; 
	auto not(alias pred = "a", A)(in A a)
	if(is(Unqual!A == bool) || isVector!A)
	{
		static if(isVector!A)
		return a.generateVector!(bool, a => !a); 
		else
		return !a; 
	} 
	
	private void unittest_VectorRelationalFunctions()
	{
		{
			assert(lessThan   (1, 2)); //original functionality
			assert(greaterThan(2, 1)); 
			
			assert([3,1,2].sort!lessThan   .equal([1,2,3])); //lessThan	as a predicate in sort()
			assert([3,1,2].sort!greaterThan.equal([3,2,1])); //greaterThan	as a predicate in sort()
			const a = vec3(1,2,3),	b = uvec3(3,2,1); 
			assert(lessThan	(a, b) == bvec3(true, false, false)); 
			assert(lessThanEqual	(a, b) == bvec3(true, true , false)); 
			assert(greaterThan	(b, a) == bvec3(true, false, false)); 
			assert(greaterThanEqual(b, a) == bvec3(true, true , false)); 
		}
		{
			 //original equal. Copied from Dlang documentation
			int[4] a = [1, 2, 4, 3]; 
			assert(!equal(a[], a[1..$])); 
			assert(equal(a[], a[])); 
			assert(equal!((a, b) => a == b)(a[], a[])); 
			
			//different types
			double[4] b = [1.0, 2, 4, 3]; 
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
		
		assert("   H".find!(not!(unaryFun!`a==' '`)) == "H"); //original std.functional.not functionality
		assert(bvec3(0,1,0).not == bvec3(1,0,1)); 
		assert(vec3(0,1,0).not == bvec3(1,0,1)); //vec -> bvec
		assert(vec3(vec3(0,1,0).not) == bvec3(1,0,1)); //casts bool -> vec
		assert(not(true) == false); 
	} 
	
}version(/+$DIDE_REGION+/all)
{
	///  Matrix /////////////////////////////////////////////////////
	
	enum isMatrix(T) = is(T==Matrix!(CT, N, M), CT, int N, int M); 
	
	struct Matrix(CT, int N, int M)
	if(N.inRange(2, 4) && M.inRange(2, 4))
	{
		version(/+$DIDE_REGION+/all)
		{
			alias MatrixType = typeof(this); 
			alias ComponentType = CT; 
			alias VectorType = Vector!(CT, M); 
			enum MatrixTypeName = 	ComponentTypePrefix!CT != "UNDEF"
				? ComponentTypePrefix!CT ~ "mat" ~ (N==M ? N.text : N.text ~ 'x' ~ M.text)
				: MatrixType.stringof; 
					
			//mat N x M: A matrix with N columns and M rows. OpenGL uses column-major matrices, which is standard for mathematics users.
			VectorType[N] columns; 
			enum width = N, height = M; 
			enum length = N; 
					
			alias columns this; 
					
			//legendary matrices
			static auto identity()
			{ return typeof(this)(1); } 
			static auto translation(CT)(in Vector!(CT, N-1) v) if(N>2)
			{ auto res = identity; res[N-1][0..$-1] = v[]; return res; } 
			
			void translate(V)(V v)
			{
				this = translation(v) * this; 
				//Opt: this is not so optimal...
			} 
			
			//note : alias this enables inplicit conversion, but fucks up the ~ concat operator
			//ref auto opIndex(size_t i){ return columns[i]; } const opIndex(size_t i){ return columns[i]; }
			
			string toString() const
			{ return MatrixTypeName ~ "(" ~ columns[].map!text.join(", ") ~ ")"; } 
					
			private void construct(int i, T, Tail...)(T head, Tail tail)
			{
				 //this is from gl3n library
				static if(i >= M*N)
				{ static assert(false, "Matrix constructor: Too many arguments passed to constructor"); }
				else static if(isNumeric!T)
				{
					columns[i / M][i % M] = head.myto!CT; 
					construct!(i + 1)(tail); 
				}
				else static if(isVector!T && i+head.length<=N*M)
				{
					static foreach(j; 0..head.length) {
						//just inject the vector
						columns[(i+j) / M][(i+j) % M] = head[j].myto!CT; 
					}
					construct!(i + T.length)(tail); 
				}
				else static if(isDynamicArray!T)
				{
					foreach(j; 0..N*M)
					columns[j / N][j % N] = head[j]; 
					//no more constructs, because dynamic array
				}
				else
				{ static assert(false, "Matrix constructor: Argument must be of type " ~ CT.stringof ~ " or Vector, not " ~ T.stringof); }
			} 
					
			private void construct(int i)()
			{
				 //terminate
				static assert(i == N*M, "Matrix constructor: Not enough arguments passed to constructor."); 
			} 
					
			this(Args...)(in Args args)
			{
				void setIdentity(T)(in T val)
				{
					static foreach(i; 0 .. min(N, M))
					this[i][i] = val.myto!CT; 
				} 
						
				static if(Args.length==1 && isNumeric!(Args[0]))
				{
					//Identity matrix
					setIdentity(args[0]); 
				}
				else static if(Args.length==1 && isMatrix!(Args[0]))
				{
					enum N2 = Args[0].width, M2 = Args[0].height; //cast matrices
					static foreach(i; 0..N)
					static foreach(j; 0..M)
					static if(i<N2 && j<M2)
					this[i][j] = args[0][i][j].myto!CT; 
					else
					this[i][j] = (i==j ? 1 : 0).myto!CT; 
				}
				else
				{ construct!0(args); }
			} 
					
			//set or get as consequtive array. Column-mayor order, just like OpenGL.
			@property auto asArray() const
			{
				CT[] res; res.reserve(N*M); 
				foreach(i; 0..N) foreach(j; 0..M) res ~= this[i][j]; 
				return res; 
			} 
					
			@property void asArray(in CT[] arr)
			{
				int idx; 
				foreach(i; 0..N) foreach(j; 0..M) this[i][j] = arr[idx++]; 
			} 
					
			private static auto generateBinaryOpMatrix(string op, string payload, A, B)(in A a, in B b)
			{
				Matrix!(OperationResultType!(op, ScalarType!A, ScalarType!B), N, M) res; 
				static foreach(i; 0..N) res[i] = mixin(payload); 
				return res; 
			} 
		}version(/+$DIDE_REGION+/all)
		{
			auto opBinary(string op, T)(in T other) const
			{
				static if(isNumeric!T)
				{
					//Matrix op Scalar
					return generateBinaryOpMatrix!(op, "a[i]" ~ op ~ "b")(this, other); 
				}
				else static if(isMatrix!T)
				{
					//Matrix * Matrix
					static if(op=="*")
					{
						static assert(T.height==width, "Incompatible matrices for multiplication. "~typeof(this).stringof~" * "~T.stringof); 
						Matrix!(CommonType!(ComponentType, T.ComponentType), T.width, height) res; 
						static foreach(j; 0..T.width)
						static foreach(i; 0..height) {
							{
								typeof(res).ComponentType sum = 0; 
								static foreach(k; 0..T.height)
								sum += this[k][i] * other[j][k]; 
								res[j][i] = sum; 
							}
						}
						
						return res; 
					}
					else
					{
						 //op!="*"    Matrix op Matrix
						static assert(T.width==width && T.height==height, "Size of matrices must be the same."); 
						return generateBinaryOpMatrix!(op, "a[i]" ~ op ~ "b[i]")(this, other); 
					}
				}
				else static if(isVector!T&& op=="*")
				{
					//Matrix op Vector
					static assert(T.length==width, "Incompatible matrix-vector for multiplication. "~typeof(this).stringof~" * "~T.stringof); 
					Vector!(CommonType!(ComponentType, T.ComponentType), T.length) res; 
					static foreach(i; 0..width) {
						{
							typeof(res).ComponentType sum = 0; 
							static foreach(k; 0..height)
							sum += columns[k][i] * other[k]; 
							res.components[i] = sum; 
						}
					}
					return res; 
				}
				else
				{ static assert(false, "invalid operation"); }
			} 
					
			auto opBinaryRight(string op, T)(in T other) const
			{
				static if(isNumeric!T)
				{
					//Scalar op Matrix
					return generateBinaryOpMatrix!(op, "a" ~ op ~ "b[i]")(other, this); //input arguments must be in computational order!!!
				}
				else
				{ static assert(false, "invalid operation"); }
			} 
					
			auto opOpAssign(string op, T)(in T other)
			{
				this = mixin("this", op, "other"); 
				return this; 
			} 
					
			bool approxEqual(T)(in T other, float maxDiff = approxEqualDefaultDiff) const
			{
				static assert(isMatrix!T && T.width==width && T.height==height); 
				static foreach(j; 0..height)
				static foreach(i; 0..width)
				if(abs(this[i][j]-other[i][j]) > maxDiff) return false; 
				  //Todo: verify abs
				return true; 
			} 
					
			//create special matrices
					
			static if(N==M && N==2 && isFloatingPoint!CT)
			{
				//only for mat2
				
				static auto rotation(CommonType!(CT, float) rad) {
					auto c = cos(rad), s = sin(rad); 
					return MatrixType(c, s, -s, c); 
				} 
				
				static auto rotation90 ()		 { return MatrixType(0, -1, 1, 0); } 
				static auto rotation270()		 { return MatrixType(0, 1, 0, -1); } 
			}
					
			//this is based on the gl3n package
			static if(N==M && N>=3 && isFloatingPoint!CT)
			{
				//only for mat3 and mat4
				
				static Matrix rotation(V)(in V axis_, CT alpha)
				{
					CT cosa = cos(alpha),  sina = sin(alpha); 
					auto axis = normalize(Vector!(CT, 3)(axis_)); 
					auto temp = (1 - cosa)*axis; 
					
					return cast(Matrix) Matrix!(CT, 3, 3)
						(
						temp.x * axis.x + cosa	, temp.x * axis.y + sina * axis.z 	, temp.x * axis.z - sina * axis.y 	,
						temp.y * axis.x - sina * axis.z	, temp.y * axis.y + cosa	, temp.y * axis.z + sina * axis.x	,
						temp.z * axis.x + sina * axis.y 	, temp.z * axis.y - sina * axis.x	, temp.z * axis.z + cosa	
					); 
				} 
				
				static Matrix rotationx(CT alpha)
				{
					CT cosa = cos(alpha), sina = sin(alpha); 
					
					auto m = Matrix(1); 
					m[1][1] = cosa; 	 m[1][2] = -sina; 
					m[2][1] = sina; 	 m[2][2] =  cosa; 
					return m; 
				} 
				
				static Matrix rotationy(CT alpha)
				{
					CT cosa = cos(alpha), sina = sin(alpha); 
					
					auto m	= Matrix(1); 
					m[0][0] =	cosa; 	 m[0][2] = sina; 
					m[2][0] = -sina; 	 m[2][2] = cosa; 
					return m; 
				} 
				
				static Matrix rotationz(CT alpha)
				{
					CT cosa = cos(alpha), sina = sin(alpha); 
					
					auto m = Matrix(1); 
					m[0][0] = cosa; 	 m[0][1] = -sina; 
					m[1][0] = sina; 	 m[1][1] =  cosa; 
					return m; 
				} 
				
				void rotate(V)(in V axis, CT alpha)
				{ this = rotation(axis, alpha)*this; } 
				void rotatex(CT alpha)
				{ this = rotationx(alpha)*this; } 
				void rotatey(CT alpha)
				{ this = rotationy(alpha)*this; } 
				void rotatez(CT alpha)
				{ this = rotationz(alpha)*this; } 
			}
		}version(/+$DIDE_REGION+/all)
		{
			static if(M==4 && N==4 && is(CT==float))
			{
				//source: https://github.com/Dav1dde/gl3n/blob/master/gl3n/linalg.d
				
				static MatrixType lookAt(in vec3 eye, in vec3 target, in vec3 up)
				{
					auto forward = target - eye; 
					if((magnitude(forward))==0) return mat4.identity; 
					forward = (normalize(forward)); 
					
					auto side = (normalize(((forward).cross(up)))); 
					auto upVector = ((side).cross(forward)); 
					
					return MatrixType(
						vec4(side, 0), 
						vec4(upVector, 0), 
						vec4(-forward, 0), 
						vec4(eye, 1)
					).inverse; 
				} 
				
				static MatrixType perspective(float left, float right, float bottom, float top, float near, float far)
				{
					return MatrixType(
						((2*near)/(right-left))	, 0	, ((right+left)/(right-left))	, 0,
						0	, ((2*near)/(top-bottom))	, ((top+bottom)/(top-bottom))	, 0,
						0	, 0	, -((far+near)/(far-near))	, -((2*far*near)/(far-near)),
						0	, 0	, -1	, 0
					).transpose; 
				} 
				
				static MatrixType perspective(float width, float height, float fov, float near, float far)
				{
					float 	aspect 	= width/height,
						top 	= near * tan(fov*(PIf/360.0f)),
						bottom 	= -top,
						right 	= top * aspect,
						left 	= -right; 
					return perspective(left, right, bottom, top, near, far); 
				} 
				
				//Todo: do this with dmat4
			}
			/+
				
							unittest {
									assert(mat4.xrotation(0).matrix == [	[1.0f, 0.0f, 0.0f, 0.0f],
										[0.0f, 1.0f, 0.0f, 0.0f],
										[0.0f, 0.0f, 1.0f, 0.0f],
										[0.0f, 0.0f, 0.0f, 1.0f] ]);
									assert(mat4.yrotation(0).matrix == [	[1.0f, 0.0f, 0.0f, 0.0f],
										[0.0f, 1.0f, 0.0f, 0.0f],
										[0.0f, 0.0f, 1.0f, 0.0f],
										[0.0f, 0.0f, 0.0f, 1.0f] ]);
									assert(mat4.zrotation(0).matrix == [	[1.0f, 0.0f, 0.0f, 0.0f],
										[0.0f, 1.0f, 0.0f, 0.0f],
										[0.0f, 0.0f, 1.0f, 0.0f],
										[0.0f, 0.0f, 0.0f, 1.0f] ]);
									mat4 xro = mat4.identity;
									xro.rotatex(0);
									assert(mat4.xrotation(0).matrix == xro.matrix);
									assert(xro.matrix == mat4.identity.rotatex(0).matrix);
									assert(xro.matrix == mat4.rotation(0, vec3(1.0f, 0.0f, 0.0f)).matrix);
									mat4 yro = mat4.identity;
									yro.rotatey(0);
									assert(mat4.yrotation(0).matrix == yro.matrix);
									assert(yro.matrix == mat4.identity.rotatey(0).matrix);
									assert(yro.matrix == mat4.rotation(0, vec3(0.0f, 1.0f, 0.0f)).matrix);
									mat4 zro = mat4.identity;
									xro.rotatez(0);
									assert(mat4.zrotation(0).matrix == zro.matrix);
									assert(zro.matrix == mat4.identity.rotatez(0).matrix);
									assert(zro.matrix == mat4.rotation(0, vec3(0.0f, 0.0f, 1.0f)).matrix);
							}
						
						
					/// Sets the translation of the matrix (nxn matrices, n >= 3).
					void set_translation(CT[] values...) // intended to be a property
							in { assert(values.length >= (rows-1)); }
							body {
									foreach(r; TupleRange!(0, rows-1)) {
											matrix[r][rows-1] = values[r];
									}
							}
						
					/// Copyies the translation from mat to the current matrix (nxn matrices, n >= 3).
					void set_translation(Matrix mat) {
							foreach(r; TupleRange!(0, rows-1)) {
									matrix[r][rows-1] = mat.matrix[r][rows-1];
							}
					}
						
					/// Returns an identity matrix with the current translation applied (nxn matrices, n >= 3)..
					Matrix get_translation() const {
							Matrix ret = Matrix.identity;
						
							foreach(r; TupleRange!(0, rows-1)) {
									ret.matrix[r][rows-1] = matrix[r][rows-1];
							}
						
							return ret;
					}
						
					unittest {
							mat3 m3 = mat3(0.0f, 1.0f, 2.0f,
														 3.0f, 4.0f, 5.0f,
														 6.0f, 7.0f, 1.0f);
							assert(m3.get_translation().matrix == [[1.0f, 0.0f, 2.0f], [0.0f, 1.0f, 5.0f], [0.0f, 0.0f, 1.0f]]);
							m3.set_translation(mat3.identity);
							assert(mat3.identity.matrix == m3.get_translation().matrix);
							m3.set_translation([2.0f, 5.0f]);
							assert(m3.get_translation().matrix == [[1.0f, 0.0f, 2.0f], [0.0f, 1.0f, 5.0f], [0.0f, 0.0f, 1.0f]]);
							assert(mat3.identity.matrix == mat3.identity.get_translation().matrix);
						
							mat4 m4 = mat4(0.0f, 1.0f, 2.0f, 3.0f,
														 4.0f, 5.0f, 6.0f, 7.0f,
														 8.0f, 9.0f, 10.0f, 11.0f,
														 12.0f, 13.0f, 14.0f, 1.0f);
							assert(m4.get_translation().matrix == [	[1.0f, 0.0f, 0.0f,	 3.0f],
								[0.0f, 1.0f, 0.0f,	 7.0f],
								[0.0f, 0.0f, 1.0f, 11.0f],
								[0.0f, 0.0f, 0.0f,  1.0f]]);
							m4.set_translation(mat4.identity);
							assert(mat4.identity.matrix == m4.get_translation().matrix);
							m4.set_translation([3.0f, 7.0f, 11.0f]);
							assert(m4.get_translation().matrix == [[1.0f, 0.0f, 0.0f, 3.0f],
																				 [0.0f, 1.0f, 0.0f, 7.0f],
																				 [0.0f, 0.0f, 1.0f, 11.0f],
																				 [0.0f, 0.0f, 0.0f, 1.0f]]);
							assert(mat4.identity.matrix == mat4.identity.get_translation().matrix);
					}
						
					/// Sets the scale of the matrix (nxn matrices, n >= 3).
					void set_scale(mt[] values...)
							in { assert(values.length >= (rows-1)); }
							body {
									foreach(r; TupleRange!(0, rows-1)) {
											matrix[r][r] = values[r];
									}
							}
						
					/// Copyies the scale from mat to the current matrix (nxn matrices, n >= 3).
					void set_scale(Matrix mat) {
							foreach(r; TupleRange!(0, rows-1)) {
									matrix[r][r] = mat.matrix[r][r];
							}
					}
						
					/// Returns an identity matrix with the current scale applied (nxn matrices, n >= 3).
					Matrix get_scale() {
							Matrix ret = Matrix.identity;
						
							foreach(r; TupleRange!(0, rows-1)) {
									ret.matrix[r][r] = matrix[r][r];
							}
						
							return ret;
					}
						
					unittest {
							mat3 m3 = mat3(0.0f, 1.0f, 2.0f,
														 3.0f, 4.0f, 5.0f,
														 6.0f, 7.0f, 1.0f);
							assert(m3.get_scale().matrix == [[0.0f, 0.0f, 0.0f], [0.0f, 4.0f, 0.0f], [0.0f, 0.0f, 1.0f]]);
							m3.set_scale(mat3.identity);
							assert(mat3.identity.matrix == m3.get_scale().matrix);
							m3.set_scale([0.0f, 4.0f]);
							assert(m3.get_scale().matrix == [[0.0f, 0.0f, 0.0f], [0.0f, 4.0f, 0.0f], [0.0f, 0.0f, 1.0f]]);
							assert(mat3.identity.matrix == mat3.identity.get_scale().matrix);
						
							mat4 m4 = mat4(0.0f, 1.0f, 2.0f, 3.0f,
														 4.0f, 5.0f, 6.0f, 7.0f,
														 8.0f, 9.0f, 10.0f, 11.0f,
														 12.0f, 13.0f, 14.0f, 1.0f);
							assert(m4.get_scale().matrix == [[0.0f, 0.0f, 0.0f, 0.0f],
																				 [0.0f, 5.0f, 0.0f, 0.0f],
																				 [0.0f, 0.0f, 10.0f, 0.0f],
																				 [0.0f, 0.0f, 0.0f, 1.0f]]);
							m4.set_scale(mat4.identity);
							assert(mat4.identity.matrix == m4.get_scale().matrix);
							m4.set_scale([0.0f, 5.0f, 10.0f]);
							assert(m4.get_scale().matrix == [[0.0f, 0.0f, 0.0f, 0.0f],
																				 [0.0f, 5.0f, 0.0f, 0.0f],
																				 [0.0f, 0.0f, 10.0f, 0.0f],
																				 [0.0f, 0.0f, 0.0f, 1.0f]]);
							assert(mat4.identity.matrix == mat4.identity.get_scale().matrix);
					}
						
					/// Copies rot into the upper left corner, the translation (nxn matrices, n >= 3).
					void set_rotation(Matrix!(mt, 3, 3) rot) {
							foreach(r; TupleRange!(0, 3)) {
									foreach(c; TupleRange!(0, 3)) {
											matrix[r][c] = rot[r][c];
									}
							}
					}
						
					/// Returns an identity matrix with the current rotation applied (nxn matrices, n >= 3).
					Matrix!(mt, 3, 3) get_rotation() {
							Matrix!(mt, 3, 3) ret = Matrix!(mt, 3, 3).identity;
						
							foreach(r; TupleRange!(0, 3)) {
									foreach(c; TupleRange!(0, 3)) {
											ret.matrix[r][c] = matrix[r][c];
									}
							}
						
							return ret;
					}
						
					unittest {
							mat3 m3 = mat3(0.0f, 1.0f, 2.0f,
														 3.0f, 4.0f, 5.0f,
														 6.0f, 7.0f, 1.0f);
							assert(m3.get_rotation().matrix == [[0.0f, 1.0f, 2.0f], [3.0f, 4.0f, 5.0f], [6.0f, 7.0f, 1.0f]]);
							m3.set_rotation(mat3.identity);
							assert(mat3.identity.matrix == m3.get_rotation().matrix);
							m3.set_rotation(mat3(0.0f, 1.0f, 2.0f, 3.0f, 4.0f, 5.0f, 6.0f, 7.0f, 1.0f));
							assert(m3.get_rotation().matrix == [[0.0f, 1.0f, 2.0f], [3.0f, 4.0f, 5.0f], [6.0f, 7.0f, 1.0f]]);
							assert(mat3.identity.matrix == mat3.identity.get_rotation().matrix);
						
							mat4 m4 = mat4(0.0f, 1.0f, 2.0f, 3.0f,
														 4.0f, 5.0f, 6.0f, 7.0f,
														 8.0f, 9.0f, 10.0f, 11.0f,
														 12.0f, 13.0f, 14.0f, 1.0f);
							assert(m4.get_rotation().matrix == [[0.0f, 1.0f, 2.0f], [4.0f, 5.0f, 6.0f], [8.0f, 9.0f, 10.0f]]);
							m4.set_rotation(mat3.identity);
							assert(mat3.identity.matrix == m4.get_rotation().matrix);
							m4.set_rotation(mat3(0.0f, 1.0f, 2.0f, 4.0f, 5.0f, 6.0f, 8.0f, 9.0f, 10.0f));
							assert(m4.get_rotation().matrix == [[0.0f, 1.0f, 2.0f], [4.0f, 5.0f, 6.0f], [8.0f, 9.0f, 10.0f]]);
							assert(mat3.identity.matrix == mat4.identity.get_rotation().matrix);
					}
				
				}   
			+/
					
		}
	} 
	
	private alias matrixElementTypes = AliasSeq!(float, double); 
	private enum matrixSizes = [2, 3, 4]; 
	
	static foreach(T; matrixElementTypes)
	{
		static foreach(N; matrixSizes)
		{
			static foreach(M; matrixSizes)
			mixin(format!q{alias %smat%sx%s = Matrix!(%s, %s, %s); }(ComponentTypePrefix!T, N, M, T.stringof, N, M)); 
				
			//symmetric matrices
			mixin(format!q{alias %smat%s = %smat%sx%s; }(ComponentTypePrefix!T, N, ComponentTypePrefix!T, N, N)); 
		}
	}
	
}version(/+$DIDE_REGION+/all)
{
	private void unittest_Matrices()
	{
		{
			//Similarly, matrices can be initialized and constructed. Note that the values specified in
			//a matrix constructor are consumed to fill the first column, then the second column, etc.:
			mat3 m = mat3(
				 1.1, 2.1, 3.1,	//first column (not row!)
				 1.2, 2.2, 3.2,	//second column
				 1.3, 2.3, 3.3	//third column
			); 
			assert(m == mat3(vec3(1.1, 2.1, 3.1), vec3(1.2, 2.2, 3.2), vec3(1.3, 2.3, 3.3))); 
				
			mat3 id = mat3(1.0); //puts 1.0 on the diagonal, all other components are 0.0
			assert(id == mat3(vec3(1, 0, 0), vec3(0, 1, 0), vec3(0, 0, 1))); 
				
			vec3 column0 = vec3(1.1, 2.1, 3.1); 
			vec3 column1 = vec3(1.2, 2.2, 3.2); 
			vec3 column2 = vec3(1.3, 2.3, 3.3); 
			mat3 n = mat3(column0, column1, column2); //sets columns of matrix n
			assert(m == n); 
		}
		{
			//If a larger matrix is constructed from a smaller matrix, the additional rows and columns are
			//set to the values they would have in an identity matrix:
			mat2 m2x2 = mat2(
				1.1, 2.1,
				1.2, 2.2
			); 
			mat3 m3x3 = mat3(m2x2); //= mat3(
			assert(m3x3 == mat3(vec3(1.1, 2.1, 0), vec3(1.2, 2.2, 0), vec3(0, 0, 1))); 
			mat2 mm2x2 = mat2(m3x3); //= m2x2
			assert(mm2x2 == m2x2); 
		}
		{
			//Matrices are considered to consist of column vectors, which are accessed by array indexing with the []-operator.
			//Elements of the resulting (column) vector can be accessed as discussed above:
			mat3 m = mat3(
				1.1, 2.1, 3.1,	//first column
				1.2, 2.2, 3.2,	//second column
				1.3, 2.3, 3.3	//third column
			); 
			vec3 column3 = m[2]; //= vec3(1.3, 2.3, 3.3)
			float m20 = m[2][0]; //= 1.3
			float m21 = m[2].y; //= 2.3
			assert(column3 == vec3(1.3, 2.3, 3.3) && m20==1.3f && m21==2.3f); 
		}
		{
			//Operators: For matrices, these operators also work component-wise, except for the *-operator, which represents a matrix-matrix product
			mat2 a = mat2(1., 2.,  3., 4.); 
			mat2 b = mat2(10., 20.,  30., 40.); 
			mat2 c = a * b; 
			mat2 expected = mat2(
				1. * 10. + 3. * 20., 2. * 10. + 4. * 20.,
				1. * 30. + 3. * 40., 2. * 30. + 4. * 40.
			); 
			assert(c == expected); 
		}
		{
			//For a component-wise matrix product, the built-in function matrixCompMult is provided.
			auto a = mat2x3(vec3(1,2,3), vec3(4,5,6)); 
			auto b = mat2x3(vec3(10,20,30), vec3(40,50,60)); 
			assert(matrixCompMult(a, b) == mat2x3(vec3(10, 40, 90), vec3(160, 250, 360))); 
		}
		{
			//The *-operator can also be used to multiply a floating-point value (i.e. a scalar) to all components of a vector or matrix (from left or right):
			vec3 a = vec3(1.0, 2.0, 3.0); 
			mat3 m = mat3(1.0); 
			float s = 10.0; 
			vec3 b = s * a; 	 assert(b == vec3(10.0, 20.0, 30.0)); 
			vec3 c = a * s; 	 assert(c == vec3(10.0, 20.0, 30.0)); 
			mat3 m2 = s * m; 	 assert(m2 == mat3(10.0)); 
			mat3 m3 = m * s; 	 assert(m3 == mat3(10.0)); 
		}
		{
			//more complex matrix multiplication test from https://people.richland.edu/james/lecture/m116/matrices/multiplication.html
			auto a = mat3x2(1, 4, -2, 5, 3, -2),
					 b = mat4x3(vec3(1, -3, 6), vec3(-8, 6, 5), 4, 7, -1, vec3(-3, 2, 4)); 
			assert(a*b == mat4x2(vec2(25, -23), vec2(-5, -12), vec2(-13, 53), vec2(5, -10))); 
		}
		{
			//Furthermore, the *-operator can be used for matrix-vector products of the corresponding dimension
			vec2 v = vec2(10., 20.); 
			mat2 m = mat2(1., 2.,  3., 4.); 
			assert(m*v == vec2(1. * 10. + 3. * 20., 2. * 10. + 4. * 20.)); 
			assert(v*m == vec2(1. * 10. + 2. * 20., 3. * 10. + 4. * 20.)); 
			//multiplying a vector from the left to a matrix corresponds to multiplying it from the right to the transposed matrix:
		}
		{
			//https://www.varsitytutors.com/hotmath/hotmath_help/topics/multiplying-vector-by-a-matrix#:~:text=
			//continued-> Example%20%3A,number%20of%20rows%20in%20y%20.&text=First%2C%20multiply%20Row%201%20of,Column%201%20of%20the%20vector.
				auto m = mat3(1, 4, 7, 2, 5, 8, 3, 6, 9); 
				auto v = vec3(2, 1, 3); 
				assert(m*v == vec3(13, 31, 49)); 
		}
		
		{
			//Various tests of mine
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
	
}version(/+$DIDE_REGION Matrix fun.+/all)
{
	//Matrix functions //////////////////////////////////////////
	
	auto matrixCompMult(T, U)(in T a, in U b)
	{
		static assert(isMatrix!T && isMatrix!U); 
		static assert(T.width==U.width && T.height==U.height); 
		Matrix!(CommonType!(T.ComponentType, U.ComponentType), T.width, T.height) res; 
		static foreach(i; 0..T.width)
		static foreach(j; 0..T.height)
		res[i][j] = a[i][j] * b[i][j]; 
		return res; 
	} 
	
	auto outerProduct(U, V)(in U u, in V v) if(isVector!U && isVector!V)
	{
		//https://www.chegg.com/homework-help/definitions/outer-product-33
		Matrix!(CommonType!(U.ComponentType, V.ComponentType), V.length, U.length) res; 
		static foreach(i; 0..V.length)
		res[i] = u*v[i]; 
		return res; 
	} 
	
	auto transpose(CT, int M, int N)(in Matrix!(CT, N, M) m)
	{
		Matrix!(CT, M, N) a; 
		foreach(i; 0..M)
		foreach(j; 0..N)
		a[i][j] = m[j][i]; 
		return a; 
	} 
	
	/// Removes the column i and row j
	auto minorMatrix(int i, int j, T, int N, int M)(in Matrix!(T, N, M) m)
	{
		Matrix!(T, N-1, M-1) res; 
		foreach(x; 0..N)
		if(x!=i)
		foreach(y; 0..M)
		if(y!=j)
		res[x<i ? x : x-1][y<j ? y : y-1] = m[x][y]; 
		return res; 
	} 
	
	private auto checkerSign(int i, T)(in T a)
	{ return i&1 ? -a : a; } 
	
	auto determinant(T)(in T m) if(isMatrix!T && T.width==T.height)
	{
		enum N = T.width; //Todo: check mat4.det in asm
		//https://www.mathsisfun.com/algebra/matrix-determinant.html
		typeof(m[0][0]+1) res = 0; 
		static if(N==2)
		res = m[0][0]*m[1][1] - m[1][0]*m[0][1]; 
		else
		static foreach(i; 0..T.width)
		res += checkerSign!i(m[i][0] * determinant(m.minorMatrix!(i, 0))); 
		return res; 
	} 
	
	auto inverse(T)(in T m) if(isMatrix!T && T.width==T.height)
	{
		enum N = T.width; 
		//https://www.mathsisfun.com/algebra/matrix-inverse.html
		//https://www.mathsisfun.com/algebra/matrix-inverse-minors-cofactors-adjugate.html
		const d = determinant(m); 
		if(d==0) return T(0); //return 0 matrix if determinant is zero
		
		T minors; 
		static if(N==2)
		minors = T(m[1][1], -m[0][1], -m[1][0], m[0][0]); 
		else
		static foreach(i; 0..N)
		static foreach(j; 0..N)
		minors[i][j] = m.minorMatrix!(j, i).determinant.checkerSign!(i+j); 
		return minors * (1.0f/d); 
	} 
	
	
	private void unittest_MatrixFunctions()
	{
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
		assert(mat2(4,2,7,6).inverse.approxEqual(mat2(.6, -.2, -.7, .4))); 
		assert(mat3(3,2,0, 0,0,1, 2,-2,1).inverse.approxEqual(mat3(.2,-.2,.2, .2,.3,-.3, 0,1,0))); 
		assert(mat4(-3,-3,-2,1, -1,1,3,-2, 2,2,0,-3, -3,-2,1,1).inverse.approxEqual(mat4(-1.571, -2.142, 2, 3.285,  2,3,-3,-5, -1,-1,1,2, 0.285,0.571,-1,-1.142))); 
	} 
	
}
version(/+$DIDE_REGION+/all)
{
	/// Bounds /////////////////////////////////////////////
	enum isBounds(T) = is(T.BoundsType); 
	
	template CommonBoundsType(A...)
	{
		static if(CommonVectorLength!A > 1)
		alias CommonBoundsType = Bounds!(CommonVectorType!A); 
		else
		alias CommonBoundsType = Bounds!(CommonScalarType!A); 
	} 
	
	struct Bounds(VT)
	{
		version(/+$DIDE_REGION+/all)
		{
			VT low = 0, high = -1; //A bounds is invalid when high<low. And empty when high<=low. The extend operator '|' handles these cases accordingly.
			
			alias BoundsType = typeof(this); 
			alias VectorType = VT; 
			alias ComponentType = ScalarType!VT; 
			enum VectorLength = CommonVectorLength!VT; 
			enum BoundsTypeName = 	(ComponentTypePrefix!ComponentType.among("UNDEF", "u", "b"))
				? VT.stringof
				: ComponentTypePrefix!ComponentType ~ "bounds" ~ (VectorLength>1 ? VectorLength.stringof : ""); 
			enum Null = Bounds!VT.init; 
			
			this(A...)(in A a)
			{
				alias CT = ComponentType; 
				
				static if(A.length==0)
				{
					//default invalid bounds
				}
				else static if(A.length==1 && isBounds!(A[0]))
				{
					//another Bounds
					static assert(
						VectorLength == A[0].VectorLength, 
						"dimension mismatch "~VectorLength.text~" != "~A[0].VectorLength.text
					); 
					low = a[0].low; 
					high = a[0].high; 
				}
				else static if(A.length==2)
				{
					//2 vectors or scalars.  GenericArgs are allowed here.
					low = a[0].asGenericArgValue; 
					high = a[1].asGenericArgValue; 
					
					version(/+$DIDE_REGION handle center: size: radius: namedParams.+/all)
					{
						enum a0_is_center 	= __traits(compiles, a[0].name=="center") && a[0].name=="center",
						a1_is_size 	= __traits(compiles, a[1].name=="size"  ) && a[1].name=="size",
						a1_is_radius 	= __traits(compiles, a[1].name=="radius") && a[1].name=="radius"; 
						static if(a0_is_center || a1_is_radius /+centered+/)
						{
							static if(a1_is_size)	{ low -= high/2; high = low + high; }
							else static if(a1_is_radius)	{ low -= high; high = low + high*2; }
							else	static assert(0, "Must specify size: or radius: after center:"); 
						}
						else
						{
							//non centered: topleft is the origin of size
							static if(a1_is_size) high += low; 
						}
					}
					
				}
				else static if(A.length==4 && VectorLength==2)
				{
					//4 scalars
					//cast is needed to be able to pass foreach index variables (long)
					low [0] = cast(CT)a[0]; low [1] = cast(CT)a[1]; 
					high[0] = cast(CT)a[2]; high[1] = cast(CT)a[3]; 
				}
				else static if(A.length==6 && VectorLength==3)
				{
					//6 scalars
					low [0] = cast(CT)a[0]; low [1] = cast(CT)a[1]; low [2] = cast(CT)a[2]; 
					high[0] = cast(CT)a[3]; high[1] = cast(CT)a[4]; high[2] = cast(CT)a[5]; 
				}
				else
				{ static assert(0, "invalid arguments"); }
			} 
			
			this(R)(R r)
			if(isInputRange!R)
			{
				Bounds!(typeof(r.front)) bnd; 
				r.each!(v => bnd |= v); 
				this = bnd; 
			} 
			
			static if(VectorLength==2)
			{
				auto width	() const { return high.x-low.x; 	}   	auto halfWidth	() const { return cast(ComponentType) width	*0.5f; } 
				auto height	() const { return high.y-low.y; 	} 	auto halfHeight	() const { return cast(ComponentType) height	*0.5f; } 
								
				auto center	() const { return avg(low, high); 	} 		
				auto area	() const { return size.x*size.y; 	} 		
								
				auto smallDiameter	() const { return min(width, height); 	} 	auto smallRadius	() const { return cast(ComponentType) smallDiameter	*0.5f; } 
				auto largeDiameter	() const { return max(width, height); 	} 	auto largeRadius	() const { return cast(ComponentType) largeDiameter	*0.5f; } 
								
				auto left	() const { return low .x; 	} 	ref left	() { return low .x; 	}    	alias x0 = left; 
				auto right	() const { return high.x; 	} 	ref right	() { return high.x; 	} 	alias y0 = top; 
				auto top	() const { return low .y; 	} 	ref top	() { return low .y; 	} 	alias x1 = right; 
				auto bottom	() const { return high.y; 	} 	ref bottom	() { return high.y; 	} 	alias y1 = bottom; 
										
				auto topLeft	() const { return low; 	} 	ref topLeft	() { return low; 	} 	alias v0 = low; 
				auto topRight	() const { return VT(high.x, low .y); 	} 				
				auto bottomLeft	() const { return VT(low .x, high.y); 	} 				
				auto bottomRight	() const { return high; 	} 	ref bottomRight	() { return high; 	} 	alias v1 = high; 
						
				auto topCenter	() const { return VT(center.x, top   ); 	} 	
				auto bottomCenter	() const { return VT(center.x, bottom); 	} 	
				auto leftCenter	() const { return VT(left , center.y); 	} 
				auto rightCenter	() const { return VT(right, center.y); 	} 
			}
			
			
			auto sorted()
			{
				//it ignores validity! Don't use on invalid bounds!
				return typeof(this)(min(low, high), max(low, high)); 
			} 
			
			string toString() const
			{
				static if(VectorLength==1)
				return format!"%s(%s, %s)"(BoundsTypeName, low, high); 
				else
				return format!"%s(%(%s, %))"(BoundsTypeName, low[]~high[]); 
			} 
			
			bool valid() const
			{
				return all(lessThanEqual(low, high)); 
				//a zero size bounds is valid because it contains the first point of expansion
			} 
			
			auto opCast(T)() const
			{
				static if(is(T==bool))
				return valid; 
				else
				return T(this); 
			} 
			
			//multidimensional size
			auto size() const
			{ return max(high-low, 0); } 
			
			bool empty() const
			{ return size.lessThanEqual(0).any; } //not empty means, that it has an >0 area
		}version(/+$DIDE_REGION+/all)
		{
			auto opBinary(string op, T)(in T other) const
			{
				static if(op=="|")
				{
					//extend with other bounds
					static if(isBounds!T)
					{
						return other.valid	? this | other.low | other.high
							: this; 
					}
					else static if(isInputRange!T)
					{
						 //extend to array elements
						Unqual!(typeof(this)) bnd = this; 
						other.each!(a => bnd|=a); //Opt: can be optimized for valid() checking
						return bnd; 
					}
					else
					{
						 //extend with a single element
						Bounds!(CommonVectorType!(typeof(low), T)) res; 
						if(valid) {
							res.low	= min(low , other),
							res.high	= max(high, other); 
						}else { res.low = res.high = other; }
						return res; 
					}
				}
				else static if(op=="&")
				{
					//union
					static assert(isBounds!T); 
					Bounds!(CommonVectorType!(typeof(low), typeof(T.low))) res; 
					if(valid && other.valid)
					{
						res.low	= max(low , other.low ); 
						res.high	= min(high, other.high); 
						if(any(greaterThanEqual(res.low, res.high))) res = typeof(res).init; 
					}
					return res; 
				}
				else static if(op.among("+", "-", "*", "/"))
				{
					//shift, scale
					CommonBoundsType!(typeof(low), T) res; 
					if(valid) {
						res.low	= mixin("low" , op, "other"); 
						res.high	= mixin("high", op, "other"); 
					}
					return res; 
				}
				else
				{ static assert(0, "invalid operation"); }
			} 
					
			auto opOpAssign(string op, T)(in T other)
			{
				this = mixin("this", op, "other"); 
				return this; 
			} 
					
			bool opEquals(T)(in T other) const
			{
				return valid	? low==other.low && high==other.high
					: !other.valid; 
			} 
					
			bool approxEqual(T)(in T other, float maxDiff = approxEqualDefaultDiff) const
			{
				static assert(isBounds!T && __traits(compiles, low == other.low)); 
				return low.approxEqual(other.low) && high.approxEqual(other.high); 
			} 
					
			bool contains(string cfg = "[)", T)(in T other) const
			{
				//from 230626: inclusive..exclusive.  Before it was incl incl.  It is now better for window handling.
				static assert(cfg.length==2 && "[(".canFind(cfg[0]) && "])".canFind(cfg[1]), "invalid open/close config. // [] closed, () open"); 
				
				static if(cfg[0]=='[') alias f1 = greaterThanEqual; else alias f1 = greaterThan; 
				static if(cfg[1]==']') alias f2 = lessThanEqual; else alias f2 = lessThan; 
				
				static if(isBounds!T)
				{
					//return contains!cfg(other.low) && contains!cfg(other.high); 
					return !empty && ((this & other)==other); 
					//for bounds it always do Windows style rect handling
				}
				else
				return all(f1(other, low) & f2(other, high)); 
			} 
					
			bool overlaps(T)(in T other) const
			{
				 //intersection.area > 0
				static if(VectorLength==1)
				{ if(other.low >= high || other.high <= low) return false; }
				else static if(VectorLength==2) {
					if(other.low.x >= high.x || other.high.x <= low.x) return false; 
					if(other.low.y >= high.y || other.high.y <= low.y) return false; 
				}
				else
				static assert(0, "NOTIMPL"); 
				return true; 
			} 
					
			static if(VectorLength==1 && is(ComponentType==int))
			{
				int opApply(int delegate(int i) dg) const
				{
					int result = 0; 
					foreach(i; low..high) {
						result = dg(i); 
						if(result) break; 
					}
					return result; 
				} 
			}
					
			static if(VectorLength==2 && is(ComponentType==int))
			{
				private int myOpApply(string payload, DG)(DG dg) const
				{
					int result = 0; 
					outer: foreach(y; low.y..high.y)
					{
						foreach(x; low.x..high.x)
						{
							result = mixin(payload); 
							if(result) break outer; 
						}
					}
					return result; 
				} 
						
				int opApply(int delegate(int x, int y) dg) const
				{ return myOpApply!"dg(x, y)"(dg); } 
				int opApply(int delegate(ivec2 p) dg) const
				{ return myOpApply!"dg(ivec2(x, y))"(dg); } 
			}
		}
	} 
	
	static foreach(T; AliasSeq!(float, double, int))
	static foreach(N; [1, 2, 3])
	static if(N==1) mixin(format!q{alias %sbounds1 = %s; }(ComponentTypePrefix!T, (Bounds!T).stringof)); 
	else mixin(format!q{alias %sbounds%s = %s; }(ComponentTypePrefix!T, N, Bounds!(Vector!(T, N)).stringof)); 
	//Todo: bounds helyett bounds1 jobb lenne, mert a bounds az sokszor masra is hasznalva van: pl. bmp.bounds.  Esetleg interval lehetne a neve.
	
	//functions with bounds ////////////////////////////////
	
	auto bounds2_center(A, B, C, D)(A xcenter, B ycenter, C xsize, D ysize)
	{
		const xsizeh = xsize * .5f, ysizeh = ysize * .5f; 
		return bounds2(
			xcenter-xsizeh, ycenter-ysizeh,
			xcenter+xsizeh, ycenter+ysizeh
		); 
	} 
	
	auto bounds2_center(A, B)(in A center, in B size)
	{ return bounds2_center(center.x, center.y, size.x, size.y); } 
	
	auto manhattanDistance(B, V)(in B bnd, in V v) if(isBounds!B && isVector!V)
	{ ERR("TODO"); } 
	
	auto ifloorceil(VT)(in Bounds!VT b)
	{ return Bounds!(Vector!(int, VT.length))(b.low.ifloor, b.high.iceil); } 
	
	auto lfloorceil(VT)(in Bounds!VT b)
	{ return Bounds!(Vector!(long, VT.length))(b.low.lfloor, b.high.lceil); } 
	
	
	private void unittest_Bounds()
	{
		static assert(__traits(compiles, bounds3(1, 2)) && bounds3(1, 2)==bounds3(vec3(1), vec3(2)) ); 
		static assert(!__traits(compiles, bounds3(1, 2, 3, 4))); 
		static assert(__traits(compiles, bounds3(1, 2, 3, 4, 5, 6))); 
			
		auto b1 = bounds1(1, 2); //must include dimension=1, so the word 'bounds' can be used for general purposes
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
			
		{
			//extend tests   op=="|"
			bounds2 bnd; 
			vec2[] arr = [vec2(3, 4), vec2(9, 11), vec2(14, 2)]; 
			arr.each!(a => bnd|=a); 
			assert(bnd == bounds2(min(arr), max(arr))); //this also tests min[] for ranges
			assert((bounds2.init | arr) == bnd); //| operator for ranges
			assert(bounds2(arr) == bnd); //constructor
		}
		{
			//intersection test  op=="&"
			assert((ibounds2(9, 19, 15, 25) & ibounds2(9, 19, 15, 25)) == ibounds2(9, 19, 15, 25)); 
			assert((ibounds2(11, 19, 17, 25) & ibounds2(12, 18, 18, 24)) == ibounds2(12, 19, 17, 24)); 
			assert((ibounds2(19, 4, 25, 10) & ibounds2(18, 0, 24, 6)) == ibounds2(19, 4, 24, 6)); 
			assert((ibounds2(-1, 4, 5, 10) & ibounds2(0, -1, 6, 5)) == ibounds2(0, 4, 5, 5)); 
			assert(!(ibounds2(16, 13, 22, 19) & ibounds2(18, 5, 24, 11)).valid); 
		}
		{
			//opApply tests
			int[] a; foreach(x, y; ibounds2(ivec2(1, 5), ivec2(3, 8))) a ~= [x, y]; assert(a.equal([1, 5, 2, 5, 1, 6, 2, 6, 1, 7, 2, 7])); 
			int[] b; foreach(p		 ; ibounds2(1, 5, 3, 8)) with(p) b ~= [x, y]; assert(b.equal(a)); 
			int[] c; foreach(i		 ; ibounds1 (2, 6)) c ~= i; assert(c.equal([2, 3, 4, 5])); 
		}
		{
			static assert
			(
				[
					//topLeft is the origin of size
					bounds2(100, 200, 120, 250),
					bounds2(vec2(100, 200), vec2(120, 250)),
					bounds2(vec2(100, 200), ((5).genericArg!q{size})),
					//center is the origin of size/radius
					bounds2(vec2(100, 200), ((5).genericArg!q{radius})),
					bounds2(((vec2(100, 200)).genericArg!q{center}), ((5).genericArg!q{size})),
					bounds2(((vec2(100, 200)).genericArg!q{center}), ((5).genericArg!q{radius}))
				]==[
					bounds2(100, 200, 120, 250), 
					bounds2(100, 200, 120, 250), 
					bounds2(100, 200, 105, 205), 
					
					
					bounds2(95, 195, 105, 205),
					bounds2(97.5, 197.5, 102.5, 202.5), 
					bounds2(95, 195, 105, 205)
				]
			); 
		}
	} 
	
}version(/+$DIDE_REGION+/all)
{
	//Image ///////////////////////////////////////////////////////
	enum isImage(A) = is(A.ImageType); //not nice
	
	template ImageDimension(A)
	{
		static if(isImage!A)	enum ImageDimension = A.Dimension; 
		else	enum ImageDimension = 0; 
	} 
	
	enum isImage1D(A) = ImageDimension!A == 1; 
	enum isImage2D(A) = ImageDimension!A == 2; 
	enum isImage3D(A) = ImageDimension!A == 3; 
	
	alias Image2D(T) = Image!(T, 2); 
	
	//tells the elementType of an 1D range.  Returns void if can't.
	template ElementType1D(R)
	{
		static if(!isVector!R)	alias ElementType1D = ElementType!R; 
		else	alias ElementType1D = void; 
	} 
	
	template ElementType2D(R)
	{
		alias T = ElementType1D!R; 
		static if(!is(T==void) && !isVector!T)	alias ElementType2D = ElementType!T; 
		else	alias ElementType2D = void; 
	} 
	
	template ElementType3D(R)
	{
		alias T = ElementType2D!R; 
		static if(!is(T==void) && !isVector!T)	alias ElementType3D = ElementType!T; 
		else	alias ElementType3D = void; 
	} 
	
	template RangeDimension(R)
	{
		static if(!is(ElementType3D!R == void))	enum RangeDimension = 3; 
		else static if(!is(ElementType2D!R == void))	enum RangeDimension = 2; 
		else static if(!is(ElementType1D!R == void))	enum RangeDimension = 1; 
		else	enum RangeDimension = 0; 
	} 
	
	template InnerElementType(R)
	{
		static if(RangeDimension!R==3)	alias InnerElementType = ElementType3D!R; 
		else static if(RangeDimension!R==2)	alias InnerElementType = ElementType2D!R; 
		else static if(RangeDimension!R==1)	alias InnerElementType = ElementType1D!R; 
		else	alias InnerElementType = R; 
	} 
	
	private void unittest_ImageElementType()
	{
		static assert(is(ElementType1D!(RGB  ) == void)); 
		static assert(is(ElementType1D!(RGB[]) == RGB)); 
			
		static assert(is(ElementType2D!(RGB[]  ) == void)); 
		static assert(is(ElementType2D!(RGB[][]) == RGB)); 
			
		static assert(is(ElementType3D!(RGB[][]  ) == void)); 
		static assert(is(ElementType3D!(RGB[][][]) == RGB)); 
			
		alias Types = AliasSeq!(RGB, RGB[], RGB[][], RGB[][][]); 
		static foreach(i, T; Types) {
			static assert(RangeDimension!T == i); 
			static assert(is(InnerElementType!T == RGB)); 
		}
	} 
	
	private auto maxImageSize2D(A...)(A args)
	{
		auto res = ivec2(0); 
		void extendSize(ivec2 act) { maximize(res, act); } 
			
		static foreach(a; args)
		{
			{
				alias T = Unqual!(typeof(a)); 
				alias E = ElementType2D!T; 
				static if(isImage2D!T)
				{
					//an actual 2D image
					extendSize(a.size); 
				}else static if(!is(E==void))
				{
					//nested 2D array
					extendSize(ivec2(a.map!(a => cast(int) a.length).maxElement, a.length)); 
				}
				else
				{
					extendSize(ivec2(1)); //a single pixel
				}
			}
		}
		return res; 
	} 
	
	private void enforceImageSize2D(A...)(in ivec2 size, A args)
	{
		static foreach(a; args)
		{
			{
				alias T = Unqual!(typeof(a)); 
				static if(isImage2D!T)
				{
					//an actual 2D image
					enforce(a.size == size, format!"Image size mismatch: (this)%s != (other)%s"(size, a.size) ); 
				}
				//other types are clipped or used as uniform
			}
		}
	} 
	
	private auto getDefaultArg(T, A...)(A a)
	{
		//gets a default if can, ensures that the type is T
		static if(A.length>=1)
		return cast(T) a[0]; 
		else
		return T.init; 
	} 
	
	private auto image2DfromRanges(R, D...)(in ivec2 size, R range, D def)
	{
		static assert(D.length<=1, "too many args. Expected a multidimensional range and optionally a default."); 
		
		//try to get an image from 1D or 2D ranges
		enum Dim = RangeDimension!R; 
		static if(Dim.among(1, 2))
		{
			alias T = Unqual!(InnerElementType!R); 
			Unqual!T filler = getDefaultArg!T(def); //Unqual needed for padRight
			static if(Dim == 2)
			auto arr = join(range.take(size.y).map!(a => a.padRight(filler, size.x).array)); 
			else
			auto arr = range.array; 
			arr = arr.padRight(filler, size[].product).array; //Opt: this is fucking unoptimal!
			return Image!(T, 2)(size, cast()cast(T[])arr); 
		}
		else
		static assert(0, "invalid args"); 
	} 
	
	enum isIntOrUint(T) = is(Unqual!T==int) || is(Unqual!T==uint); 
	
	auto image2D(alias fun="", A...)(A args)
	{
		//image2D constructor //////////////////////////////////
		static assert(A.length>0, "invalid args"); 
		
		//Todo: nem lehet kombinalni az img.retro-t az img.rgb swizzlinggel.   img2 = img.rows.retro.image2D.image2D!"a.b1g";   <-  2x image2D needed
		//Todo: img2 = image2D(img.size, (x, y) => img[x, img.height-1-y].lll);  az (x, y) forma sem megy csak az (ivec2 p)
		
		static if(A.length>=2 && isIntOrUint!(A[0]) && isIntOrUint!(A[1]))
		{
			//Starts with 2 ints: width, height
			return image2D!fun(ivec2(args[0], args[1]), args[2..$]); 
		}
		else static if(is(Unqual!(A[0])==ivec2))
		{
			//Starts with known ivec2 size
			ivec2 size = args[0]; 
			
			static assert(A.length>1, "not enough args"); 
			
			alias funIsStr = isSomeString!(typeof(fun)); 
			
			static if(funIsStr && fun=="")
			{
				//default behaviour: one bitmap, optional default
				alias R = Unqual!(A[1]); 
				static if(RangeDimension!R.among(1, 2))
				{
					return image2DfromRanges(size, args[1..$]); //1D, 2D range
				}
				else
				{
					static assert(A.length<=2, "too many args"); 
					static if(__traits(compiles, args[1](size)))
					{
						//delegate or function (ivec2)
						alias RT = Unqual!(typeof(args[1](size))); 
						static if(is(RT == void))
						{
							//return is void, just call the delegate.
							foreach(pos; size.iota2D) args[1](pos); 
							return; //the result is void
						}
						else
						{
							return Image!(RT, 2)(size, cast(RT[])(size.iota2D.map!(p => args[1](p)).array)); 
							//return type is something, make an Image out of it.
						}
					}
					else static if(isPointer!(A[1]))
					{
						alias E = Unqual!(typeof(*args[1])); 
						return Image!(E, 2)(size, cast(E[])(args[1][0..size.area])); 
					}
					else
					{
						//non-callable
						Unqual!R tmp = args[1]; 
						return Image!(Unqual!R, 2)(size, [tmp].replicate(size[].product)); 
						//one pixel stretched all over the size
					}
				}
			}
			else
			{
				//fun is specified
				enforceImageSize2D(size, args[1..$]); 
				
				return image2D
				(
					size, (ivec2 pos)
					{
						//generate all the access functions
						static auto importArg(T)(int i)
						{
							string index; 
							static if(isImage2D!T) index = "[pos.x, pos.y]"; 
							return format!"auto ref %s(){ return args[i+1]%s; }"(cast(char)('a'+i), index); 
						} 
						static foreach(i, T; A[1..$]) mixin(importArg!T(i)); 
						
						static if(funIsStr)
						{
							//Note: if the fun has a return statement, it will make an image. Otherwise return void.
							enum isStatement = __traits(compiles, {mixin(fun);}); 
							static if(isStatement)	{ mixin(fun); }
							else	{ return mixin(fun); }
						}
						else
						{
							return mixin(
								"fun(", (
									(A.length-1)	.iota
									.map!(i => cast(string)[cast(char)('a'+i)])
									//Todo: use .text
									.join(",")
								), ")"
							); 
						}
					}
				); 
			}
		}
		else
		{
			 //automatically calculate size from args
			return image2D!fun(maxImageSize2D(args), args); 
		}
	} 
	
}version(/+$DIDE_REGION+/all) {
	struct Image(E, int N) //Image struct //////////////////////////////////
	{
		version(/+$DIDE_REGION+/all)
		{
			//copied from dlang opSlice() documentation
			static assert(N == 2); 
			
			alias ImageType = typeof(this); 
			alias ElementType = E; 
			enum Dimension = N; 
			
			static if(N>1)
			{
				Vector!(int, N) size; 
				//Todo: it's not 1D compatible.  Vector!(T, 1) should be equal to an alias=T.  In Bounds as well.
			}
			else { int size; }
			
			int stride; 
			//here 4 bytes extra data can fit: a change-hash for example
			E[] impl; 
			
			auto ptr() { return impl.ptr; } 
			
			//size properties
			static foreach(i, name; ["width", "height", "depth"].take(N))
			mixin(
				"ref auto @(){ return size[#]; }  auto @() const { return size[#]; }"
							.replace("@", name).replace("#", i.text) 
			); 
			
			
			
			static if(N>=2)
			auto area() const
			{ return width*height; } 
			
			static if(N>=3)
			auto volume() const
			{ return area*depth; } 
			
				
			this(in ivec2 size, E[] initialData = [], int stride=0)
			{
				//from array. stride is optional
				if(stride<=0)
				stride = size.x; 
				else enforce(stride>=size.x); 
				
				this.size = size; 
				this.stride = stride; 
				impl = initialData; 
				impl.length = stride * size.y; 
			} 
			
			bool empty() const
			{ return size.lessThanEqual(0).any; } 
			bool opCast(B : bool)() const
			{ return !empty; } 
			
			auto toString() const
			{
				static if(N==1)
				return format!"image1D(%s)"(impl); 
				else static if(N==2) return "image2D([\n" ~ rows.map!(r => "  " ~ r.text).join(",\n") ~ "\n])"; 
				else static assert(0, "not impl"); 
			} 
			
			auto bounds() const
			{
				Bounds!(Unqual!(typeof(size))) b; 
				b.high = size; 
				return b; 
			} 
				
			//these returning single arrays / maps of arrays
			auto row(int y) const
			{ return impl[stride*y .. stride*y + width]; } 	auto row(int y)
			{ return impl[stride*y .. stride*y + width]; } 
			
			auto rows() const
			{ return height.iota.map!(y => row(y)); } 	auto rows()
			{ return height.iota.map!(y => row(y)); } 
			
			auto column(int x) const
			{ return height.iota.map!(y => cast(E)(impl[stride*y + x])).array; } //cast needed to remove constness
			auto columns() const
			{ return width.iota.map!(x => column(x)); } 
				
			void regenerate(E delegate(ivec2) generator)
			{ impl = size.iota2D.map!generator.array; } 
				
			@property auto asArray()
			{
				if(size.x==stride)
				return impl; else
				return rows.join; 
			} 
				
			@property auto asArray() const
			{
				//Todo: ezt nem lehet egyszerubben? const vagy nem const. Peldaul "const auto"
				if(size.x==stride)
				return impl; else
				return rows.join; 
			} 
				
			@property void asArray(A)(A a) //creates a same size image from 'a' and copies it into itself.
			{ this[0, 0] = image2D(size, a); } 
				
			auto dup(string op="")() const
			{
				//optional predfix op
				static if(op=="")
				{
					//return Image!(E, N)(size, height.iota.map!(i => impl[i*stride..i*stride+width].dup).join); //todo:2D only
					if(stride==width)
					return Image!(E, N)(size, impl.dup); 
					else return Image!(E, N)(size, rows.map!(r => r.dup).join); //Todo: 2D only
					//Todo: check this r.dup.join in disassembler
				}
				else {
					auto tmp = this.dup; 
					foreach(ref a; tmp.impl)
					a = cast(E) (mixin(op, "a")); //transform all the elements manually
					return tmp; 
				}
			} 
				
			//Index a single element, e.g., arr[0, 1]
			ref E opIndex(int i, int j)
			{ return impl[i + stride*j]; } 	E opIndex(int i, int j) const
			{ return impl[i + stride*j]; } 
			ref E opIndex(in ivec2 p)
			{ return this[p.x, p.y]; } 	E opIndex(in ivec2 p) const
			{ return this[p.x, p.y]; } 
				
			//Array slicing, e.g., arr[1..2, 1..2], arr[2, 0..$], arr[0..$, 1].
			auto opIndex(int[2] r1, int[2] r2)
			{
				ImageType result; 
					
				auto startOffset = r1[0] + r2[0]*stride; 
				auto endOffset = r1[1] + (r2[1] - 1)*stride; 
				result.impl = this.impl[startOffset .. endOffset]; 
					
				result.stride	= this.stride; 
				result.width	= r1[1] - r1[0]; 
				result.height	= r2[1] - r2[0]; 
					
				return result; 
			} 
			auto opIndex(int[2] r1, int j)
			{ return opIndex(r1, [j, j+1]); } auto opIndex(int i, int[2] r2)
			{ return opIndex([i, i+1], r2); } 
				
			//ivec and ibounds slicing
			auto opIndex(in ivec2 mi, in ivec2 ma)
			{ return opIndex([mi.x, ma.x], [mi.y, ma.y]); } auto opIndex(in ibounds2 b)
			{ return opIndex(b.low, b.high); } 
				
			//Support for `x..y` notation in slicing operator for the given dimension.
			int[2] opSlice(size_t dim)(int start, int end)
			if (dim >= 0 && dim < 2)
			in //Todo: DIDE interpret invariants
			{ assert(start >= 0 && end <= this.opDollar!dim); }
			do
			{ return [start, end]; } 
				
			auto opSlice() const
			{ return this; } 
				
			//Support `$` in slicing notation, e.g., arr[1..$, 0..$-1].
			@property
			{
				static if(N==1)
				int opDollar(size_t dim : 0)()
				{ return size; } else
				int opDollar(size_t dim : 0)()
				{ return size[0]; 	} 
				
				static if(N>=2)
				int opDollar(size_t dim : 1)()
				{ return size[1]; } 
				
				static if(N>=3)
				int opDollar(size_t dim : 2)()
				{ return size[2]; } 
				
			} 
			
			bool contains(ivec2 p) const
			
			{
				return (
					(cast(uint)(p.x)) < width && 
					(cast(uint)(p.y)) < height
				); 
			} 	bool contains(int x, int y) const
			{ return contains(ivec2(x, y)); } 
			auto safeGet(ivec2 p, E def = E.init)
			{ return ((contains(p))?(this[p]):(def)); } 	auto safeGet(int x, int y, E def = E.init)
			{ return safeGet(ivec2(x, y), def); } 
			
			
			void safeSet(ivec2 p, E val)
			{
				if(contains(p))
				cast()impl[p.y*stride + p.x] = val; 
				//Bug: This fucking fucker wont compile without the fucking cast(). Prolly some immutable debug fuck calls it...
			} 
			
			void safeSet(int x, int y, E val)
			{ safeSet(ivec2(x, y), val); } 
			
			import std.traits : isSomeChar; 
			static if(!isSomeChar!E/+Bug: Ez a gecifos beszarik ha char az elementtype.  A .array dchar-rá rakja ossze a chart.+/)
			{
				auto safeGet(ibounds2 b, E def = E.init)
				{
					if((b & bounds)==b) return this[b]; 
					return image2D(b.size, b.size.iota2D.map!(p=>safeGet(b.topLeft+p, def))); 
				} 
			}
			
			bool opBinaryRight(string op : "in", A)(A p) const
			{ return p.x>=0 && p.y>=0 && p.x<width && p.y<height; } 
			
			
		}version(/+$DIDE_REGION+/all) {
			//Index/Slice assign
				
			/*
				private void clampx(ref int x){ x = x.clamp(0, width -1); }
						private void clampy(ref int y){ y = y.clamp(0, height-1); }
						private void clampx(ref int[2] x){ x[0].clampx; x[1].clampx; }
						private void clampy(ref int[2] y){ y[0].clampy; y[1].clampy; }
			*/
				
			private void assignHorizontal(string op, A)(A a, int[2] r1, int j)
			{
				//Todo: optimizalasi kiserlet: tesztelni az optimizalt eredmenyt,
				//ha ezt kivaltom az assignRectangular-al.
				static if(isImage2D!A)
				{ return assignHorizontal!op(a.rows.join, r1, j); }
				else
				{
					const ofs = j*stride; 
					static if(!isInputRange!A) const casted = cast(E) a; 
					foreach(ref val; impl[ofs+r1[0]..ofs+r1[1]])
					{
						static if(!isInputRange!A)
						{ mixin("val", op, "= casted;"); }
						else
						{
							if(a.empty) return; 
							mixin("val", op, "= cast(E) a.front;"); 
							a.popFront; 
						}
					}
				}
			} 
				
			private void assignVertical(string op, A)(A a, int i, int[2] r2)
			{
				static if(isImage2D!A)
				{ return assignVertical!op(a.rows.join, i, r2); }
				else
				{
					auto ofs = i + r2[0]*stride; 
					static if(!isInputRange!A) const casted = cast(E) a; 
					foreach(_; r2[0]..r2[1])
					{
						static if(!isInputRange!A)
						{ mixin("impl[ofs]", op, "= casted;"); }
						else
						{
							if(a.empty) return; 
							mixin("impl[ofs]", op, "= cast(E) a.front;"); 
							a.popFront; 
						}
						ofs += stride; 
					}
				}
			} 
				
			private void assignRectangular(string op, A)(A a, int[2] r1, int[2] r2)
			{
				static if(isImage2D!A)
				{
					//adjust slice to topLeft if the source is smaller
					minimize(r1[1], r1[0]+a.width ); 	 const w = r1[1]-r1[0]; 
					minimize(r2[1], r2[0]+a.height); 	 const h = r2[1]-r2[0]; 
					
					auto dstOfs = r1[0] + r2[0]*stride,  srcOfs = 0; 
					
					foreach(j; 0..h) {
						foreach(i; 0..w)
						mixin("impl[dstOfs+i]", op, "= cast(E) a.impl[srcOfs+i];"); 
						
						srcOfs += a.stride;  dstOfs += stride; 
					}
				}
				else static if(isInputRange!A)
				{
					//fill with continuous range. Break on empty.
					const w = r1[1]-r1[0]; 
					const h = r2[1]-r2[0]; 
					
					auto dstOfs = r1[0] + r2[0]*stride; 
					
					foreach(j; 0..h) {
						foreach(i; 0..w)
						{
							if(a.empty) return; 
							mixin("impl[dstOfs+i]", op, "= cast(E) a.front;"); 
							a.popFront; 
						}
						dstOfs += stride; 
					}
					
				}
				else
				{
					//single value
					foreach(j; r2[0]..r2[1])
					assignHorizontal!op(a, r1, j); 
				}
			} 
				
			void opIndexAssign(A)(A a, int i, int j)
			{
				static if(isImage2D!A)
				{
					 //simplified way to copy an image. dst[3, 5] = src.
					this[i..min($, i+a.width), j..min($, j+a.height)] = a; 
				}
				else static if(RangeDimension!A == 1)
				{
					 //insert a line
					foreach(x; i..width) {
						if(a.empty) break; 
						opIndex(x, j) = cast(E) a.front; 
						a.popFront; 
					}
				}
				else
				{
					 //set a pixel
					opIndex(i, j) = cast(E) a; 
				}
			} 
			
			void opIndexAssign(A)(in	A a,	int[2] r1, int j)
			{ assignHorizontal!""(a,	r1,	j); } 
			void opIndexAssign(A)(in	A a,	int i, int[2] r2)
			{ assignVertical	!""(a,	i, r2); } 
			void opIndexAssign(A)(in	A a, int[2] r1, int[2] r2)
			{ assignRectangular!""(a, r1, r2); } 
			void opIndexAssign(A)(in A a)
			{ this[0..$, 0..$] = a; } 
				
			void opIndexAssign(string op, A)(in A a, int i, int j)
			{ mixin("this[i, j]", op, "= a;"); } 
			void opIndexAssign(string op, A)(in A a, int[2] r1, int j)
			{ assignHorizontal	!op(a, r1,  j); } 
			void opIndexAssign(string op, A)(in A a, int i, int[2] r2)
			{ assignVertical	!op(a,  i, r2); } 
			void opIndexAssign(string op, A)(in A a, int[2] r1, int[2] r2)
			{ assignRectangular!op(a, r1, r2); } 
			void opIndexAssign(string op, A)(in A a)
			{ mixin("this[0..$, 0..$]", op, "= a;"); } 
			
			//Index/Slice unary ops. All non-const, I don't wanna suck with constness
			auto opIndexUnary(string op)(int i, int j)
			{ return mixin(op, "this[i, j]"); } 
			auto opIndexUnary(string op)(int[2] r1,	int j)
			{ return this[r1[0]..r1[1], j	].dup!op; } 
			auto opIndexUnary(string op)(int i, int[2] r2)
			{ return this[i           , r2[0]..r2[1]].dup!op; } 
			auto opIndexUnary(string op)(int[2] r1, int[2] r2)
			{ return this[r1[0]..r1[1], r2[0]..r2[1]].dup!op; } 
			auto opIndexUnary(string op)()
			{ return mixin(op, "this[0..$, 0..$]"); } 
			
			auto opIndexBinary(string op, A)(other A)
			{ return mixin(op, "this[0..$, 0..$]"); } 
			
			//operations on the whole image
			auto opUnary(string op)()
			{ return mixin(op, "this[]"); } 
			
			auto opBinary(string op, bool reverse=false, A)(in A a)
			{
				//Todo: refactor this in the same way as generateVector()
				static if(isImage2D!A)
				{
					alias T = Unqual!(typeof(mixin("this[0,0]", op, "a[0,0]"))); 
					if(a.size == size)
					{
						 //elementwise operations
						return image2D(
							size, (ivec2 p)
							{
								return reverse	? mixin("a   [p.x, p.y]", op, "this[p.x, p.y]")
									: mixin("this[p.x, p.y]", op, "a   [p.x, p.y]"); 
								//Opt: too much index calculations
							}
						); 
					}
					else
					{
						enforce(0, "incompatible image size"); 
						assert(0); 
					}
				}
				else
				{
					 //single element
					alias T = Unqual!(typeof(mixin("this[0,0]", op, "a"))); 
					return image2D(
						size, (ivec2 p)
						{
							return reverse 	? mixin("a", op, "this[p.x, p.y]")
								: mixin("this[p.x, p.y]", op, "a"); 
							//Opt: too much index calculations
						}
					); 
				}
			} 
				
			auto opBinaryRight(string op, A)(in A a)
			{ return opBinary!(op, true)(a); } 
				
			bool opEquals(A)(in A a) const
			{
				static assert(isImage2D!A); 
				return (size == a.size) && size.iota2D.map!(p => this[p.x, p.y] == a[p.x, p.y]).all; 
			} 
				
			static if(N==2)
			{
				private int myOpApply(string payload, DG)(DG dg)
				{
					int result = 0, lineOfs = 0; 
					outer: foreach(y; 0..height) {
						foreach(x; 0..width) {
							result = mixin(payload); 
							if(result) break outer; 
						}
						lineOfs += stride; 
					}
					return result; 
				} 
					
				//int opApply(int delegate(int x, int y) dg)	 { return myOpApply!"dg(x, y)"(dg); }	it maches 2 declarations
				//int opApply(int delegate(ivec2 pos) dg)	 { return myOpApply!"dg(ivec2(x, y)"(dg);	}
					
				//only able to support 1, 2 or 3 param versions.
				int opApply(int delegate(ref E) dg)
				{ return myOpApply!"dg(impl[lineOfs+x])"(dg); } 
				int opApply(int delegate(ivec2 pos , ref E) dg)
				{ return myOpApply!"dg(ivec2(x, y), impl[lineOfs+x])"(dg); } 
				int opApply(int delegate(int x, int y, ref E) dg)
				{ return myOpApply!"dg(x, y, impl[lineOfs+x])"(dg); } 
			}
			
			static if(N==2)
			{
				void saveTo(F)(in F file)
				{
					//Todo: make it const
					//Note: saveTo() must be a member function in order to work
					//Todo: this is fucking nasty! Should not import hetlib into here!!!
					//Should use a global funct instead which is initialized by het.bitmaps.
					//Todo: must do this with a global function!!! 
					//The problem is that need to pass the type and elementcount to it.
					mixin("import het.bitmap : serialize;"); 
					mixin("import het : File, saveTo, withoutStarting;"); 
					auto f = File(file); 
					saveTo(this.serialize(f.ext.withoutStarting('.')), f); 
				} 
			}
		}
	} 
}version(/+$DIDE_REGION+/all)
{
	private void unittest_Image() //image2D tests /////////////////////////////////
	{
		
		//have some colors to test immutable vectors
		static immutable RGB clRed = 0x0000FF, clGreen = 0x008000,  clBlue = 0xFF0000, clWhite = 0xFFFFFF; 
		
		version(/+$DIDE_REGION various image constructors+/all)
		{
			
			version(/+$DIDE_REGION size = 2x2, default fill value = -1+/all)
			{ assert(image2D(2, 2, [1, 2, 3], -1).rows.equal([[1,2],[3,-1]])); }
			
			version(/+$DIDE_REGION size = 2x2, 2D range+/all)
			{ assert(image2D(2, 2, [[1, 2], [3,-1]]).rows.equal([[1,2],[3,-1]])); }
			
			version(/+$DIDE_REGION size = automatic, 2D range, default fill value = -1+/all)
			{ assert(image2D([[1, 2], [3]], -1).rows.equal([[1,2],[3,-1]])); }
			
			assert(image2D(2, 1, clRed) == image2D(2, 1, [clRed], clRed)); 
			assert(__traits(compiles, image2D(2, 2, [clRed, clGreen, clBlue].dup, clWhite))); 
		}
		
		auto img = image2D(
			4, 3, [
				0,	1,	2,	 3,
				4,	5,	6,	 7,
				8,	9, 10, 11
			]
		); 
		
		assert(img.width == 4 && img.height == 3); 
		
		assert(image2D(img.size, img.asArray.ptr).asArray.equal(img.asArray)); //image as pointer
		
		//indexing: img[x, y]
		assert([img[0,0], img[$-1, 0], img[$-1, $-1]] == [0, 3, 11]); 
			
		//slicing, rows(), columns() access
		assert(img[1, 1..$].rows.array == [[5], [9]] && img[0..$, 2].rows.equal([[8, 9, 10, 11]])); //vert/horz slice
		assert(img[2..$, 1..$].rows.join == [6, 7, 10, 11]); //rectangular slice
		assert(img[2..3, 0..$].columns.array == [[2, 6, 10]]); 
		
		//some calculations on arrays:
		assert(img.columns.map!sum.equal([12, 15, 18, 21])); 
		assert(img.rows.map!sum.equal([6, 22, 38])); 
		
		//opIndexAssign tests
		auto saved = img.dup; //dup test
		img[0, 0..$] = 0; 	 img[$-1, 0..$] = 0; //columns
		img[0..$, 0] = 0; 	 img[0..$, $-1] = 0; //rows
		img[0..2, 0..3] = 9; //rect
		img[$-1, $-1] = 8; //point
		assert(img.rows.equal([[9,9,0,0], [9,9,6,0], [9,9,0,8]])); 
		img = saved; 
		
		//various flips
		assert(image2D(img.columns).rows.equal([[0,4,8],[1,5,9],[2,6,10],[3,7,11]])); //diagonal flip
		assert(image2D(img.rows.map!retro).rows[0].equal([3,2,1,0])); //horizontal flip
		assert(image2D(img.rows.retro).columns[0].equal([8,4,0])); //vertical flip
		
		//updating slices with slices
		img[] = 1; //fill all
		img[0..$, $-1] = [1, 2, 3, 4]; 	//set the bottom line to an array
		img[2, 0..$] = -img[2, 0..$]; 	//flip the sign of 3rd column
		img[0..$, 2] = -img[0..$, 2]; 	//flip the sign of last row
		img[0..2, 0..2] = -img[0..2, 0..2]; 	//flip a rectangular area
		img = -img[]; 
		assert(img == image2D([[1, 1, 1, -1], [1, 1, 1, -1], [1, 2, -3, 4]])); 
			
		//test opBinary
		img[0,0..$] = img[0,0..$] + 10; 
		img = img + 100; 
		img[0,0] = -img[2..4, 1..3]/2; //copy subimage. The destination can be a point too, not just a slice
		img = 500-img; 
		assert(img == image2D([[550, 549, 399, 401], [548, 552, 399, 401], [389, 398, 403, 396]])); 
		assert(img[0..1, 0..1]*0.25f == image2D(1, 1, (float[]).init, 137.5f)); 
			
		{
			 //insert rows/columns at a specific location
			auto i1 = image2D(2,	2, [1, 2, 3, 4]); 
			i1[0, 0] = [5, 6]; 	assert(i1 == image2D(2, 2, [5, 6, 3, 4])); 
			i1[1, 0] = image2D(1, 2, [7, 8]); 	assert(i1 == image2D(2, 2, [5, 7, 3, 8])); 
			i1[0, 0] = image2D(2, 2, 3); 	assert(i1 == image2D(2, 2, 3)); 
				
			//access/modify as array
			assert(i1.asArray.equal([3,3,3,3])); 
			
			//if stride==width, it elements can be modified too.
			i1.asArray[1..3] = [4, 5]; 	assert(i1.asArray.equal([3,4,5,3])); 
			
			//set the first 3 elements. The remaining elements will be cleared with T.init.
			i1.asArray = [1, 2, 3]; 	assert(i1.asArray.equal([1,2,3,0])); 
		}
			
		assert(is(typeof(img[0..1, 0..1]*0.25f) == Image!(float, 2))); //float promotion
		assert((){ auto sum = 0; img.each!(a => sum += a); return sum; }() == 5385); //.each test
			
		{
			 //foreach tests
			int sum1; foreach(x, y,	ref v; img) sum1 += v+x+y; 	assert(sum1 == 5415); 
			int sum2; foreach(pos ,	ref v; img) sum2 += v+pos.x+pos.y; 	assert(sum2 == 5415); 
			int sum3; foreach(ref v; img) sum3 += v; 	assert(sum3 == 5385); 
		}
			
		{
			 //image2D operations
			auto im1 = image2D([[1, 2],[3, 4]]); 
			auto im2 = image2D([[4, 3],[2, 1]]); 
			const target = image2D([[11, 12], [12, 11]]); 
				
			assert(image2D!"min(a, b)+c"(im1, im2, 10) == target); //mixin string function
				
			const increment = 10; 
			assert(image2D!((a,b) => min(a, b)+increment)(im1, im2) == target); //delegate
			assert(image2D!((a) => 123)(im1) == image2D(2, 2, 123) ); //return is a const
				
			//check simple function and delegate
			auto del = (ivec2 pos) { return increment; }; 
			auto fun = (ivec2 pos) { return cast(const)10; }; //cast because increment is const too
			assert([image2D(2, 2, fun), image2D(2, 2, del)].map!(i => i == image2D(2,2,10)).all); 
		}
			
		{
			//delegate with void result: operation on Images
			static assert(is(typeof(image2D(2, 2, (ivec2 pos){})) == void)); //inside image2D() it produces void results
				
			auto im1 = image2D(2, 2, (ivec2 p) => (p.x+1) + 10*(p.y+1) ); 
			auto im3 = im1.dup; 
			const im2 = image2D(2, 2, 10 ); 
			const target = image2D([[115, 125], [215, 225]]); 
				
			//minimal delegate form
			image2D!((ref a, b, c){ a = a*b+c; }) (im1, im2, 5);  assert(im1 == target); 
				
			//string form, but with an extra return statement.
			assert(
				image2D!q{a = a*b+c; return vec2(1,2); } (im3, im2, 5)
								==
								image2D(2, 2, vec2(1, 2)) && im3 == target
			); 
		}
			
		{
			 //complex image text with char type
			auto subImg = image2D(15, 20, '.'); //img[5..20, 10..30];
			foreach(y; 0..subImg.height)
			foreach(x; 0..subImg.width)
			subImg[x, y] = (x^y)&4 ? '.' : ' '; 
				
			//draw a border
			subImg[0  , 0..$] = '|'; subImg[$-1, 0..$] = '|'; 
			subImg[0..$, 0  ] = '-'; subImg[0..$, $-1] = '-'; 
				
			//fill a subRect
			subImg[2..$-2, 2..5] = '@'; 
			subImg[4..$, 2] = "Hello World..."; 
			subImg[2, 4..$] = "Hello World..."; 
				
			subImg[3..6, 4..6] = "123456"; 	 //contiguous fill
			subImg[10..13, 4..6] = '~'; 	 //constant fill
			subImg[10..15, 15..20] = subImg[0..5-1, 0..5+1]; //copy rectangle
			subImg[10, 10] = subImg[0..4, 0..5]; //also copy rectangle. Size is taken form source image
				
			//display the image (it's upside down)
			import std.digest.crc; //Todo: use own crc32
			assert(subImg.asArray.hexDigest!CRC32 == "BB6C00F4"); 
		}
	} 
	
}version(/+$DIDE_REGION Functions+/all)
{
	version(/+$DIDE_REGION+/all)
	{
		///  Functions /////////////////////////////////////////////////////
		
		immutable grayscaleWeights = vec3(0.299, 0.586, 1-(0.299+0.586)); 
		
		/// this is my approxEqual. The one in std.math is too complicated
		bool approxEqual(A, B, C)(in A a, in B b, in C maxDiff = approxEqualDefaultDiff)
		{ return abs(a-b) <= maxDiff; } 
		
		/// generates a vector or scalar from a function that can have any number of vector/scalar parameters
		auto generateVector(CT, alias fun, T...)(in T args)
		{
			static if(anyVector!T)
			{
				Vector!(CT, CommonVectorLength!T) res; 
				static foreach(i; 0..res.length)
				res[i] = cast(CT) mixin("fun(", T.length.iota.map!(j => "args["~j.text~"].vectorAccess!i").join(','), ")"); 
				return res; 
			}
			else
			{ return cast(CT) fun(args); }
		} 
		
		//Angle & Trig. functions ///////////////////////////////////
		
		auto radians(real scale = PI/180, A)(in A a)
		{
			alias CT = CommonScalarType!(A, float); 	//common type is at least float
			alias fun = a => a * cast(CT) scale; //degrade the real enum if needed
			return a.generateVector!(CT, fun); 
		} 
		auto degrees(A)(in A a)
		{ return radians!(180/PI)(a); } 
		
		private enum _normalizeAngle = 
		q{
			if(x>=-half && x<half) return x;
			return cast(T)(
				x>=0 	?    (x + half) % (2*half)   - half
					: -(-(x + half) % (2*half)) + half
			);
		}; 
		
		T normalizeAngle_deg(T)(T x)
		{
			enum half = 180; mixin(_normalizeAngle); 
			//Todo: unittest
		} 
		
		T normalizeAngle_rad(T)(T x)
		{
			enum half = PI; mixin(_normalizeAngle); 
			//Todo: unittest
		} 
		
		auto angleAbsDiff_rad(A, B)(A a, B b)
		{ return normalizeAngle_rad(b-a).abs; } ; 
		
		auto angleAbsDiff_deg(A, B)(A a, B b)
		{ return normalizeAngle_deg(b-a).abs; } ; 
		
		/// Mixins an std.math funct that will work on scalar or vector data. Cast the parameter at least to a float and calls fun()
		private enum UnaryStdMathFunct(string name) = 
		q{
			auto #(A)(in A a){
				static if(isComplex!A) 
				{return std.complex.#(a);}
				else
				{
					alias CT = CommonScalarType!(A, float);
					alias fun = a => std.math.#(cast(CT) a);
					return a.generateVector!(CT, fun);
				}
			}
		}.replace('#', name); 
		
		static foreach(s; "sin cos tan asin acos sinh cosh tanh asinh acosh atan".split(' '))
		mixin(UnaryStdMathFunct!s); 
		
		auto atan(A, B)(in A a, in B b)
		{
			//atan is GLSL
			alias CT = CommonScalarType!(A, B, float); 
			alias fun = (a, b) => std.math.atan2(cast(CT) a, cast(CT) b); 
			return generateVector!(CT, fun)(a, b); 
		} 
		
		//auto atan2(A, B)(in A a, in B b){ return atan(a, b); }
		//this improves std.math.atan2. No, rather stick to GLSL compatibility to force GLSL-DLang compatibility more
		
		private void unittest_AngleAndTrigFunctions()
		{
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
			static assert(is(typeof(cos(dvec2(1, 2))) == dvec2)); 
			assert(cos(dvec2(1, 2.5)).approxEqual(vec2(0.5403, -0.8011))); 
			assert(tan(ivec2(1, 2)).approxEqual(vec2(1.5574, -2.1850))); 
			assert(asin(.5).approxEqual(PI/6)); 
			assert(acos(vec2(0, .5)).approxEqual(vec2(1.5707, PI/3))); 
			//hiperbolic functions are skipped, those are mixins anyways
			assert(atan(ivec2(1,2)).approxEqual(vec2(0.7853, 1.1071))); 
			assert(atan(vec2(1,2), 3).approxEqual(vec2(.3217, .588))); 
			assert(atan(vec2(1,2), 3) == atan(vec2(1,2), 3)); //atan is the overload in GLSL, not atan2
		} 
		
		
		//Exponential functions /////////////////////////////////////
		
		auto pow(A, B)(in A a, in B b)
		{
			alias CT = typeof(ScalarType!A.init ^^ ScalarType!B.init); 
			alias fun = (a, b) => a ^^ b; 
			return generateVector!(CT, fun)(a, b); 
		} 
		
		auto root(A, B)(in A a, in B b)
		{
			alias CT = typeof(ScalarType!A.init ^^ ScalarType!B.init); 
			alias fun = (a, b) => a ^^ (1.0f/b); 
			return generateVector!(CT, fun)(a, b); 
		} 
		
		static foreach(s; "exp log log2 log10 sqrt".split(' '))
		mixin(UnaryStdMathFunct!s); 
		
		auto exp2 (A)(in A a)
		{ return pow(2, a); } auto exp10(A)(in A a)
		{ return pow(10, a); } 
		
		auto sqr(A)(in A a)
		{
			alias CT = typeof(ScalarType!A.init ^^ 2); 
			return a.generateVector!(CT, a => a ^^ 2); 
		} 
		
		auto signedsqr(A)(in A a)
		{
			alias CT = typeof(- ScalarType!A.init ^^ 2); 
			return a.generateVector!(CT, a => a<0 ? -(a ^^ 2) : a ^^ 2); 
		} 
		
		auto inversesqrt(A)(in A a)
		{
			alias CT = CommonScalarType!(A, float); 
			return a.generateVector!(CT, a => 1 / sqrt(a)); 
		} 
		
		
		private void unittest_ExponentialFunctions()
		{
			static assert(is(typeof(pow(ivec2(2, 10), 2)) == ivec2)); 
			assert(pow(ivec2(2, 10), 2) == ivec2(4, 100)); 
			assert(pow(vec2(2.5, 10), 2) == vec2(6.25, 100)); 
			assert(exp(0)==1 && exp2(2)==4 && exp10(3)==1000); 
			assert(log(5).approxEqual(1.6094) && log2(8)==3 && log10(1000)==3); 
					
			static assert(is(typeof(sqr(5))==int)); 
			static assert(is(typeof(sqr(5.0))==double)); 
					
			assert(atan(sqrt(3.0)).approxEqual(PI/3)); 
			assert(atan(sqrt(3)).approxEqual(PI/3)); 
					
			assert(sqr(5)==25 && sqr(vec2(2, 3))==vec2(4, 9)); 
			assert(signedsqr(vec2(-5, 3))==vec2(-25, 9)); 
					
			assert(sqrt(4)==2); 
			assert(inversesqrt(4)==.5); 
			static assert(is(typeof(inversesqrt(4))==float)); 
		} 
	}version(/+$DIDE_REGION+/all)
	{
		//Geometric functions ///////////////////////////////////////
		
		//need a new sum because the original is summing with double, not float. The vector module is mainly float.
		auto sum(R)(R r)
		{
			alias T = Unqual!(ElementType!R); 
			typeof(T(0)+T(0)) sum = 0;  //the initial value is Type*2
			foreach(a; r) sum += a; 
			return sum; 
		} 
		
		//Todo: check these in asm and learn about the compiler.
		auto length(T, int N)(in Vector!(T, N) a)
		{ return sqrt(sqrLength(a)); } 
		auto sqrLength(T, int N)(in Vector!(T, N) a)
		{ return (a^^2)[].sum; } 
		auto manhattanLength(T, int N)(in Vector!(T, N) a)
		{ return a[].map!abs.sum; } 
		
		auto distance(A, B)(in A a, in B b) if(isVector!A && isVector!B)
		{ return length	     (a-b); } 
		auto sqrDistance(A, B)(in A a, in B b) if(isVector!A && isVector!B)
		{ return sqrLength	     (a-b); } 
		auto manhattanDistance(A, B)(in A a, in B b) if(isVector!A && isVector!B)
		{ return manhattanLength(a-b); } 
		
		auto dot(A, B)(in A a, in B b)
		{
			//Todo: make prettier errors, this needs more IDE integration
			static assert(CommonVectorLength!(A, B) > 1, "Dot product needs at least 1 vector argument."); 
			return (a*b)[].sum; 
		} 
		
		auto cross(A, B)(in A a, in B b)
		{
			alias len = CommonVectorLength!(A, B); 
			static if(len==2)
			{ return cross(a.xy0, b.xy0); }
			else static if(len==3)
			{
				alias V = Vector!(CommonScalarType!(A, B), 3); 
				return V(
					a.y*b.z - b.y*a.z,
					a.z*b.x - b.z*a.x,
					a.x*b.y - b.x*a.y
				); 
			}
			else
			static assert(0, "Cross product needs at least on 2D or 3D vector argument."); 
		} 
		
		auto crossZ(A, B)(in A a, in B b)
		{ return cross(a.xy0, b.xy0).z; } 
		
		auto normalize(A)(in A a)
		{
			static if(isComplex!A)
			{ return a*(1.0f/abs(a)); }
			else
			{
				static assert(isVector!A, "Normalize needs a vector argument."); 
				return a*(1.0f/length(a)); 
			}
		} 
		
		auto normalize_safe(A)(in A a)
		{ return a==A(0) ? typeof(a.normalize)(0) : a.normalize; } 
		
		auto magnitude(A)(in A a)
		{
			static if(isVector!A) return length(a); 
			else return abs(a); 
			//Todo: magnitude of complex numbers
		} 
		
		auto negateX(V)(in V a)
		{
			V res = a; 
			res.x = -res.x; 
			return res; 
		} 	 auto negateY(V)(in V a)
		{
			V res = a; 
			res.y = -res.y; 
			return res; 
		} 	 auto negateZ(V)(in V a)
		{
			V res = a; 
			res.z = -res.z; 
			return res; 
		} 	 auto negateW(V)(in V a)
		{
			V res = a; 
			res.w = -res.w; 
			return res; 
		} 
		
		/// Orients a vector to point away from a surface as defined by its normal.
		auto faceforward(A, B, C)(in A N, in B I, in C Nref)
		{ return dot(Nref, I) < 0 ? N : -N; } 
		
		/// For a given incident vector I and surface normal N reflect returns the reflection direction.
		/// N should be normalized in order to achieve the desired result.
		auto reflect(A, B)(in A I, in B N)
		{ return I - 2 * dot(N, I) * N; } 
		
		/// For a given incident vector I, surface normal N and ratio of indices of refraction, eta, refract returns the refraction vector, R.
		/// The input parameters I and N should be normalized in order to achieve the desired result.
		auto refract(A, B)(in A I, in B N)
		{
			const 	dotNI 	= dot(N, I),
				k	= 1 - eta * eta * (1 - dotNI^^2); 
			return k < 0.0 	? CommonVectorType!(A, B).Null
				: eta * I - (eta * dotNI + sqrt(k)) * N; 
		} 
		
		//Removes vector component i
		auto minorVector(int i, T, int N)(in Vector!(T, N) v)
		{
			Vector!(T, N-1) res; 
			foreach(k; 0..N) if(k!=i) res[k<i ? k : k-1] = v[k]; 
			return res; 
		} 
		
		
		//2D rotation
		
		auto rotate(T, U)(in Vector!(T, 2) v, U rad)
		{
			auto m = Matrix!(T, 2, 2).rotation(rad); 
			return m * v; 
		} 
		
		auto rotate90 (T)(in Vector!(T, 2) v)
		{ return v.Yx; } 
		
		auto rotate270(T)(in Vector!(T, 2) v)
		{ return v.yX; } 
		
		auto rotate180 (T)(in Vector!(T, 2) v)
		{ return -v; } 
		
		auto rotate90 (T)(in Vector!(T, 2) v, int n)
		{
			switch(n&3)
			{
				case 1: 	return v.rotate90; 
				case 2: 	return v.rotate180; 
				case 3: 	return v.rotate270; 
				default: 	return v; 
			}
		} 
		
		//Todo: unittest this with mat2.rotation270*v
		
		private void unittest_GeometricFunctions()
		{
			//length()
			auto v = [vec2(1,2), vec2(-2, -1), vec2(5, 0)]; 
			static assert(vec2.length == 2 && v[0].length == 2); //length property of static arrays
			
			//dynamic array length must ONLY returned as a property, not as a function()
			static assert(!__traits(compiles, length(v)) && __traits(compiles, v.length)); 
			
			//my custom sum()
			static assert(is(typeof([1   ].sum)==int	)); 
			static assert(is(typeof([0.5f].sum)==float	)); //std.sum would return a double here.
			static assert(is(typeof([0.5 ].sum)==double)); 
			static assert(is(typeof([0.5L].sum)==real  )); 
			//std.algorithm.sum would alwaysreturn a double. My sum is just summing floats as floats.
			
			static assert(is(typeof(length(vec2(1,2)))==float)); 
			
			assert(v.length == 3); //dynamic length test
			assert(v[0].length == 2); //static vector length
			assert(
				length(v[0]).approxEqual(sqrt(1^^2 + 2^^2))
								&& length(v[0])==length(v[1]) && length(v[2])==5
			); 
			assert(v.map!manhattanLength.equal([3, 3, 5])); 
			
			//distance()
			const a = ivec2(1, -4),	b = vec2(12.5, 73.4); 
			assert(distance	(a, b) == length	     (a-b)); 
			assert(sqrDistance	(a, b) == sqrLength	     (b-a)); 
			assert(manhattanDistance(a, b) == manhattanLength(a-b)); 
			
			assert(dot(vec2(3, 7), 2) == 3*2 + 7*2); 
			
			assert(cross(a, b) == vec3(0, 0, determinant(mat2(a, b)))); 
			assert(cross(vec3(3,-3,1), vec3(4,9,2)) == vec3(-15,-2,39)); 
			assert(crossZ(vec2(1, 0), vec2(0, 1)) == 1); 
			
			assert(normalize(vec2(-0.5, 2)).approxEqual(vec2(-0.242536, 0.970143))); 
			
			assert(magnitude(vec2(1, -1)).approxEqual(sqrt(2))); 
			assert(magnitude(-5) == 5); 
			
			//Todo: faceforward, reflect, refract
			
			//minorVector
			assert(vec3(1,2,3).minorVector!0 == vec2(2,3)); 
			assert(vec3(1,2,3).minorVector!1 == vec2(1,3)); 
			assert(vec3(1,2,3).minorVector!2 == vec2(1,2)); 
		} 
		
		//MSE, PNSR //////////////////////////
		
		///Squared Error
		auto SE(A, B)(in A a, in B b)
		{ return (a-b)^^2; } 
		
		auto MSE(T)(in T[] a, in T[] b)
		{
			static if(isVector!T)
			{
				//vector components can be flattened to an array
				alias CT = T.ComponentType; 
				return MSE(cast(CT[])a, cast(CT[])b); 
			}
			else static if(isNumeric!T)
			{
				import std.range; 
				return zip(StoppingPolicy.requireSameLength, a, b).map!(a => SE(a[])).sum*(1.0f/float(a.length)); 
			}
			else
			static assert(0, "Invalid type for MSE()"); 
		} 
		
		auto MSE(E)(in Image!(E, 2) a, in Image!(E, 2) b)
		{ return MSE(a.asArray, b.asArray); } 
		
		auto PSNR(T)(in T a, in T b, int max)
		{ return 10*log10(max^^2/MSE(a, b)); } 
		
		void unittest_Other()
		{
			auto a = [1, 2, 3, 4], b = [3, 2, 1, -1], mse = 8.25f; 
			assert(MSE(a, b)==mse); 
			assert(MSE(image2D(2,2,a), image2D(2,2,b))==mse); 
			assert(PSNR(image2D(2,2,a), image2D(2,2,b), 255).approxEqual(38.9663)); 
		} 
		
	}version(/+$DIDE_REGION+/all)
	{
		//Common functions //////////////////////////////////////////
		
		auto abs(A)(in A a)
		{
			static if(isComplex!A)	return std.complex.abs(a); 
			else	return max(a, -a); 
		} 
		
		auto sign(A)(in A a)
		{ alias CT = ScalarType!A; return a.generateVector!(CT, a => a==0 ? 0 : a<0 ? -1 : 1 ); } 
		
		private auto floatReductionOp(alias fun, CT, A)(in A a)
		{
			static if(isBounds!A)
			{
				auto 	low 	= a.low	.generateVector!(CT, fun),
					high 	= a.high	.generateVector!(CT, fun); 
				return Bounds!(typeof(low))(low, high); 
			}
			else
			{
				static assert(isFloatingPoint!(ScalarType!A)); 
				return a.generateVector!(CT, fun); 
			}
		} 
		
		auto floor(A, CT=ScalarType!A)(in A a)
		{ return a.floatReductionOp!(std.math.floor	, CT, A); } 
		auto ceil(A, CT=ScalarType!A)(in A a)
		{ return a.floatReductionOp!(std.math.ceil	, CT, A); } 
		auto trunc(A, CT=ScalarType!A)(in A a)
		{ return a.floatReductionOp!(std.math.trunc	, CT, A); } 
		auto round(A, CT=ScalarType!A)(in A a)
		{ return a.floatReductionOp!(std.math.round	, CT, A); } 
		auto roundEven(A, CT=ScalarType!A)(in A a)
		{ return a.floatReductionOp!(std.math.lrint	, CT, A); } //Note: depens on roundingMode: default is even
		
		auto vectorCast(CT, A)(A a)
		{
			auto fun(A a) { return (cast(T)(a)); } 
			a.generateVector!(fun, CT); //Todo: unittest
		} 
		
		auto vectorClampCast(CT, CT mi = CT.min, CT ma = CT.max, A)(A a)
		{
			auto fun(A a) { return (cast(CT)(a.clamp(mi, ma))); } 
			return a.generateVector!(CT, fun); //Todo: unittest
		} 
		
		//generate int, and long versions
		static foreach(T; AliasSeq!(int, long))
		static foreach(F; AliasSeq!(floor, ceil, trunc, round, roundEven))
		mixin(q{auto %s(A)(in A a) { return a.%s!(A, %s); } }.format(T.stringof[0]~__traits(identifier, F), __traits(identifier, F), T.stringof)); 
		
		auto fract(A)(in A a)
		{ static assert(isFloatingPoint!(ScalarType!A)); return a-floor(a); } 
		
		auto mod(A, B)(in A x, in B y)
		{
			//this is the cyclic modulo for floats.  (% is the symmetric)
			alias CT = CommonScalarType!(A, B); 
			static if(isFloatingPoint!CT)
			return x - y * floor(x*(1.0f/y)); 
			else
			return cast(CT) (x - y*(x/y)); 
		} 
		
		auto modf(A, B)(in A a, out B b)
		{
			const floora = floor(a); 
			b = cast(Unqual!B) floora; 
			return a-floora; 
		} 
		
		auto modw(A, B)(in A a, in B b)
		{
			//cyclic (wrapped) modulo for ints
			return generateVector!(
				CommonScalarType!(A, B),
				(a, b) => a>=0 ? a%b : b-1+(a+1)%b
			)(a, b); 
		} 
		
		private auto minMax(bool isMin, T, U)(in T a, in U b)
		{
			return generateVector!(
				CommonScalarType!(T, U),
								(a, b) => isMin ? std.algorithm.min(a, b) : std.algorithm.max(a, b)
			)(a, b); 
		} 
		
		auto min(T...)(in T args)
		{
			//Note: std.algorithm.min is (T t)
			static if(T.length==1 && isInputRange!(T[0]))
			{ return args[0].fold!((a, b) => min(a, b)); }
			else static if(anyVector!T)
			{
				static if(T.length==2)
				return minMax!1(args[0], args[1]); 
				else
				return min(min(args[0..$-1]), args[$-1]); 
			}
			else
			return cast()std.algorithm.min(args); 
		} 
		
		auto max(T...)(in T args)
		{
			//Note: std.algorithm.max is (T t)
			static if(T.length==1 && isInputRange!(T[0]))
			{ return args[0].fold!((a, b) => max(a, b)); }
			else static if(anyVector!T)
			{
				static if(T.length==2)
				return minMax!0(args[0], args[1]); 
				else
				return max(max(args[0..$-1]), args[$-1]); 
			}else
			return cast()std.algorithm.max(args); 
		} 
		
		bool minimize(A, B)(ref A a, in B b)
		{ const n = min(a, b), res = a != n; a = n; return res; } 
		bool maximize(A, B)(ref A a, in B b)
		{ const n = max(a, b), res = a != n; a = n; return res; } 
			
		bool inRange(V, L, H)(in V value, in L lower, in H higher)
		{
			static if(CommonVectorLength!(V, V, H)==1)
			return value>=lower && value<=higher; 
			else
			return all(greaterThanEqual(value, lower)) && all(lessThanEqual(value, higher)); 
		} 
		
		auto enforceRange(V, L, H)(in V value, in L lower, in H higher, string name="")
		{
			enforce(inRange(value, lower, higher), format!"Out of range: %s (%s !in [%s, %s])"(name, value, lower, higher)); 
			return value; 
		} 
		
		/// bounds can be unsorted
		bool inRange_sorted(V, L, H)(in V value, in L r1, in H r2)
		{ return inRange(value, min(r1, r2), max(r1, r2)); } 
		
		/// checking for valid index in arrays
		bool inRange(V, A)(in V index, in A[] arr)
		{ return index>=0 && index<arr.length; } 
		
		//apply it to intervals
		bool inRange(V, I)(in V value, in I bounds)
		if(__traits(compiles, (value in bounds)))
		{ return value in bounds; } 
		
		auto clamp(T1, T2, T3)(in T1 val, in T2 lower, in T3 upper)
		{
			static if(anyVector!(T1, T2, T3))
			return max(lower, min(upper,val)); 
			else
			return std.algorithm.clamp(val, cast(T1)lower, cast(T1)upper); 
		} 
		
		
		public import std.algorithm	: cmp; 
		public import std.math	: cmp; 
		
		auto cmp(A, B)(in A a, in B b)
		if(
			!(isInputRange!A && isInputRange!B)		//exclude std.algorithm.cmp
					&&	!(isFloatingPoint!A && isFloatingPoint!B)	  //exclude std.math.cmp
		)
		{
			//a<b -> -1
			//a>b -> +1    -> sgn(a-b)
			//a==0 -> 0
			static if((isNumeric!A || isVector!A) && (isNumeric!B || isVector!B))
			{ return generateVector!(int, (a, b) => a==b ? 0 : a<b ? -1 : 1)(a, b); }
			else
			{
				return a==b ? 0 : a<b ? -1 : 1; //last resort
			}
		} 
		
		
		auto cmpChain(int c1, lazy int c2)
		{ return c1 ? c1 : c2; } 
		auto cmpChain(int c1, lazy int c2, lazy int c3)
		{ return c1 ? c1 : c2 ? c2 : c3; } 
		auto cmpChain(int c1, lazy int c2, lazy int c3, lazy int c4)
		{ return c1 ? c1 : c2 ? c2 : c3 ? c3 : c4; } 
		//Note: Use multiSort instead of cmpChain!
		
		public import std.algorithm: sort; 
		void sort(T)(ref T a, ref T b)
		{ if(a>b) swap(a,b); } 
		
		void sort(T)(ref T a, ref T b, ref T c)
		{
			sort(a, b); 
			sort(a, c); 
			sort(b, c); 
		} 
		
		
		import std.range : hasSwappableElements; 
		auto mySort(string Order, SwapStrategy ss=SwapStrategy.unstable, Range)(Range r)
		if (hasSwappableElements!Range)
		{
			//Order example:  "value -name"
			auto fieldName(string s)
			{ return ((s.startsWith('-'))?(s[1..$]):(s)); } 
			auto relation(string s)
			{ return ((s.startsWith('-'))?('>'):('<')); } 
			enum preds = Order.splitter(' ').map!(
				s => format!`"a.%1$s%2$sb.%1$s"`
				(fieldName(s), relation(s))
			).join(','); 
			return mixin(`multiSort!(`, preds, `,ss)(r)`); 
		} 
		
		auto mix(A, B, T)(in A a, in B b, in T t)
		{
			//result type is the common of A and B, not influenced by T
			static if(is(Unqual!T==bool))
			return mix(a, b, int(t)); 
			else static if(isBounds!A && isBounds!B)
			return bounds2(mix(a.low, b.low, t), mix(a.high, b.high, t)); 
			else static if(isBounds!A && isVector!B)
			return bounds2(mix(a.low, b, t), mix(a.high, b, t)); 
			else static if(isVector!A && isBounds!B)
			return bounds2(mix(a, b.low, t), mix(a, b.high, t)); 
			else
			{
				alias CT = CommonScalarType!(A, B); //type of result NOT depends on t
				return generateVector!(CT, (a, b, t) => a*(1-t) + b*t)(a, b, t); 
			}
		} 
		
		auto avg(A...)(in A a)
		{
			//return type is casted to common source type
			static assert(A.length>0); 
			static if(isInputRange!(A[0]) && !isVector!(A[0]) && !isMatrix!(A[0]))
			{
				//an array
				assert(A.length == 1); 
				alias RT = Unqual!(ElementType!(A[0])); 
				return cast(RT) (a[0][].sum * (1.0f / a[0].length)); 
				//Todo: it's not for ranges, just arrays because []!!! MSE() can't use it.
			}
			else
			{
				//arguments
				alias 	RT = Unqual!(CommonVectorType!A); 
				alias 	T = typeof(RT(0) * 1.0f); 
				T res	= a[0]; 
				static foreach(i; 1..a.length) res += a[i]; 
				return cast(RT) (res * (1.0f / A.length)); 
			}
		} 
		
		auto unmix(A, B, T)(in A a, in B b, in X x)
		{
			//inverse of mix
			alias CT = CommonScalarType!(A, B); //type of result NOT depends on x
			return generateVector!(CT, (a, b, x) => (x-a)/(b-a) ); 
		} 
	}version(/+$DIDE_REGION+/all)
	{
		auto step(A, B)(in A edge, in B x)
		{
			alias CT = CommonScalarType!(A, B); 
			return generateVector!(CT, (edge, x) => x<edge ? 0 : 1 )(edge, x); 
		} 
		
		auto smoothstep(string fun="t * t * (3 - 2 * t)", A, B, C)(in A edge0, in B edge1, in C x)
		{
			alias CT = CommonScalarType!(A, B, C, float); //result is at least float. In the range: 0..1
			return generateVector!(
				CT, (edge0, edge1, x)
							{
					auto t = clamp(((x - edge0)*1.0f) / (edge1 - edge0), 0, 1); 
					//division is forced to at least float with that *1.0f
					
					return mixin(fun); 
				}
			)(edge0, edge1, x); 
		} 
		
		auto smootherstep(A, B, C)(in A edge0, in B edge1, in C x)
		{ return smoothstep!("t * t * t * (t * (t * 6 - 15) + 10)")(edge0, edge1, x); } 
		
		
		auto isnan(A)(in A a)
		{ return a.generateVector!(bool, a => std.math.isNaN(a) ); } 
		auto isinf(A)(in A a)
		{ return a.generateVector!(bool, a => std.math.isInfinity(a) ); } 
		auto isfin(A)(in A a)
		{ return a.generateVector!(bool, a => std.math.isFinite	(a) ); } 
		
		//Todo: ifnan(a, 0) -> returns 0 if a is nan. For vectors is shouls use .any automatically.
		
		
		auto isnull(A)(in A a)
		{
			static if(isBounds!A)
			return !a.valid; 
			else static if(isVector!A)
			return a == A.init; 
			else static if(isMatrix!A)
			return a == A(0); 
			else
			static assert(0, "invalid argument type"); 
		} 
		
		auto isPowerOf2(A)(in A a)
		{ return a.generateVector!(bool, a => std.math.isPowerOf2(a) ); } 
		
		auto nextPow2(A)(in A a)
		{ return a.generateVector!(ScalarType!A, a => std.math.nextPow2	(a) ); } 
		auto truncPow2(A)(in A a)
		{ return a.generateVector!(ScalarType!A, a => std.math.truncPow2	(a) ); } 
		auto prevPow2(A)(in A a)
		{ return a.generateVector!(ScalarType!A, a => isPowerOf2(a) ? a/2 : std.math.truncPow2(a) ); } 
		
		auto nextUp(A)(in A a)
		{
			alias CT = ScalarType!A; static assert(isFloatingPoint!CT); 
			return a.generateVector!(CT, a => std.math.nextUp(a) ); 
		} 
		auto nextDown(A)(in A a)
		{
			alias CT = ScalarType!A; static assert(isFloatingPoint!CT); 
			return a.generateVector!(CT, a => std.math.nextDown(a) ); 
		} 
		
		auto nextAfter(A, B)(in A a, in B b)
		{
			//a goes towads b
			alias CT = CommonScalarType!(A, B); static assert(isFloatingPoint!CT); 
			return generateVector!(CT, (a, b) => std.math.nextafter(a, cast(A) b) )(a, b); 
		} 
		
		private auto floatBitsTo(T, A)(in A a)
		{
			static assert(is(ScalarType!A==float), "Unsupported type. float expected."); 
			static if(isVector!A)
			return *(cast(Vector!(T, A.length)*) (&a)); 
			else
			return *(cast(T*) (&a)); 
		} 
		
		auto floatBitsToInt(A)(in A a)
		{ return floatBitsTo!int (a); } auto floatBitsToUint(A)(in A a)
		{ return floatBitsTo!uint(a); } 
		
		private auto bitsToFloat(T, A)(in A a)
		{
			static assert(is(ScalarType!A==T), "Unsupported type. "~T.stringof~" expected."); 
			static if(isVector!A)
			return *(cast(Vector!(float, A.length)*) (&a)); 
			else
			return *(cast(float*) (&a)); 
		} 
		
		auto intBitsToFloat(A)(in A a)
		{ return bitsToFloat!int (a); } auto uintBitsToFloat(A)(in A a)
		{ return bitsToFloat!uint(a); } 
		
		auto fma(A, B, C)(in A a, in B b, in C c)
		{
			//no extra precision. it's just here for compatibility.
			return generateVector!(CommonScalarType!(A, B, C), (a, b, c) => a * b + c)(a, b, c); 
		} 
		
		auto absDiff(A, B)(in A a, in B b)
		{
			alias CT = CommonScalarType!(A, B); 
			static if(isUnsigned!CT)
			return max(a, b)-min(a, b); 
			else
			return abs(a-b); 
		} 
		
		auto sad(A, B)(in A a, in B b)
		{ return absDiff(a, b)[].sum; } 
		
		auto quantize(int levels, A)(in A a)
		{
			static assert(levels>=1); 
			return (a*levels).ifloor.clamp(0, levels-1); 
		} 
		
		auto dequantize(int levels, A)(in A a)
		{
			static assert(levels>=1); 
			return a*(1.0f/(levels-1)); 
		} 
		
		
		auto product(A)(A a) if(isInputRange!A)
		{
			//similar to std.sum()
			Unqual!(ElementType!A) tmp; 
			if(a.empty) return tmp; 
			tmp = a.front; a.popFront; 
			foreach(x; a) tmp *= x; 
			return tmp; 
		} 
		
		
		//2D iota()
		auto iota2D(B, E, S)(in B b, in E e, in S s)
		{
			alias CT = CommonScalarType!(B, E, S); 
			return cartesianProduct(
				iota(b.vectorAccess!1, e.vectorAccess!1, s.vectorAccess!1),
				iota(b.vectorAccess!0, e.vectorAccess!0, s.vectorAccess!0)
			).map!(a => Vector!(CT, 2)(a[1], a[0])); 
		} 
		
		auto iota2D(B, E)(in B b, in E e)
		{ return iota2D(b, e, 1); } 
		
		auto iota2D(E)(in E e)
		{ return iota2D(0, e); } 
		
		//Todo: Make better animater following using Euler interpolation
		
		/*
			**********************************
					 * Calculates an interpolating constant 't' from a deltaTime.
					 * Its aim is to provide similar animation smoothess at different FPS.
					 * Params:
					 *					 dt =	Delta time in seconds
					 *					 speed =	speed constant. 0.0 = never, 0.1 slow, 0.9 fast, 1.0 immediate.  //todo: this is not working
					 *					 maxDt =	Maximum allowed deltaTime. Above this, the smhooth animation is disabled, restulting a value of 1.0.
					 * Returns:
					 *      Interpolation constant used in follow() functions.
					 * See_Also:
					 *      follow
		*/
		
		float calcAnimationT(float dt, float speed, float maxDt = 0.1f)
		{
			return dt<maxDt 	? 1-pow(speed, dt*30)
				: 1; 
			//Todo: Upgrade to https://val-sagrario.github.io/Dynamics%20of%20First%20Order%20Systems%20for%20game%20devs%20-%20Jan%202020.pdf
			//Todo: also upgrade https://youtu.be/LSNQuFEDOyQ?t=2981 - Freya Holmér - Lerp smoothing is broken -> expDecay
		} 
		
		/*
			**********************************
					 * Interpolate smooth animation between act and target positions.
					 * Params:
					 *					 act =	 Actual position.
					 *					 target =	 Target position, act will go towards that.
					 *					 t =	 Interpolation constant. 1.0 means immediate transition to target.
					 *		 Use calcAnimationT() to calculate it from deltaTime.
					 *      snapDistance =	 Below this distance, act will immediatelly snap to target.
					 *
					 * Returns:	            True if the act reached the target
					 *
					 * See_Also:            calcAnimationT
		*/
		
		bool follow(A)(ref A act, in A target, float t, float snapDistance)
		{
			if(act==target) return true; //fast path, nothing to do
			
			static if(isFloatingPoint!A)
			{
				//scalar
				auto last = act; 
				act = mix(act, target, t); 
				if(absDiff(act, target) <= snapDistance) act = target; 
				return act == target; 
			}
			else static if(isVector!A)
			{
				//vector, including colors. Works with RGB(ubyte) too because absDiff
				bool res = true; 
				static foreach(i; 0..A.length) {
					if(!follow(act[i], target[i], t, snapDistance)) res = false; 
					//no escape here, must do all the interpolations!
				}
				return res; 
			}
			else static if(isMatrix!A)
			{ static assert(0, "not impl"); }
			else
			static assert(0, "unhandled type: "~A.stringof); 
		} 
		
		//snorm, unorm confersion.
		//Link: https://registry.khronos.org/vulkan/specs/1.0/html/vkspec.html#fundamentals-fixedconv
		
		auto to_unorm(A)(A a)
		{ return a.generateVector!(ubyte, a=>cast(ubyte)(iround(a.clamp(0, 1)*0xFF))); } 
		auto from_unorm(A)(A a)
		{ return a.generateVector!(float, a=>a*(1.0f/0xFF)); } 
		
		auto to_snorm(A)(A a)
		{ return a.generateVector!(ubyte, a=>cast(ubyte)(iround(a.clamp(-1, 1)*0x7F))); } 
		auto from_snorm(A)(A a)
		{ return a.generateVector!(float, a=>max((cast(byte)a)*(1.0f/0x7F), -1)); } 
		
		auto to_unorm16(A)(A a)
		{ return a.generateVector!(ushort, a=>cast(ushort)(iround(a.clamp(0, 1)*0xFFFF))); } 
		auto from_unorm16(A)(A a)
		{ return a.generateVector!(float, a=>a*(1.0f/0xFFFF)); } 
		
		auto to_snorm16(A)(A a)
		{ return a.generateVector!(ushort, a=>cast(ushort)(iround(a.clamp(-1, 1)*0x7FFF))); } 
		auto from_snorm16(A)(A a)
		{ return a.generateVector!(float, a=>max((cast(short)a)*(1.0f/0x7FFF), -1)); } 
	}version(/+$DIDE_REGION+/all)
	{
		private void unittest_CommonFunctions()
		{
			assert(abs(vec2(-5, 5))==vec2(5, 5)); 
			assert(sign(Vector!(byte, 3)(-5, 0, 5)) == vec3(-1, 0, 1)); 
					
			static assert(is(typeof(iceil (5.4 )) == int	)); 
			static assert(is(typeof(lfloor(5.4 )) == long	)); 
			static assert(is(typeof(floor (5.4f)) == float	)); 
			static assert(is(typeof(floor (5.0 )) == double)); 
			auto vf = vec4(0.1,	-.5, 1.5, 1.6); 
			assert(vf.floor	== vec4(0, -1, 1, 1)); 
			assert(vf.iceil	== ivec4(1, 0, 2, 2)); 
			assert(vf.ltrunc	== uvec4(0, 0, 1, 1)); 
			assert(vf.round	== vec4(0, -1, 2, 2)); 
			assert(vf.roundEven	== vec4(0, 0, 2, 2)); 
			assert(vf.fract.approxEqual(vf-floor(vf))); 
					
			{
				//modulo tests
				const m = .7f; 
				assert((vf % m).approxEqual(vec4(0.1, -0.5, 0.1, 0.2))); //%:   symmetric mod
				assert(vf.mod(m).approxEqual(vf-m*floor(vf/m)));      //mod: cyclic mod
				assert(vf.mod(m).approxEqual(vec4(0.1, 0.2, 0.1, 0.2))); 
						
				const	a = 4.1f; 
				const	r1 = vec4(0.41, 0.95, 0.15, 0.56), r2 = ivec4(0, -3, 6, 6); 
				ivec4	ires; 	 assert(modf(vf*a, ires).approxEqual(r1) && ires==r2); 
				vec4	fres; 	 assert(modf(vf*a, fres).approxEqual(r1) && fres==r2); 
			}
			
			assert(
				cmp("abc", "abc")==0 && cmp("abc", "abcd")<0 && cmp("bbc", "abc"w)>0
								&& cmp([1L, 2, 3], [1, 2])>0 && cmp!"a<b"([1L, 2, 3], [1, 2])>0
			); 
			assert(cmp([1,2,3], [1,2]) > 0); 
			assert(cmp([1,2], [1,2,3]) < 0); 
			assert(cmp(-100.0, -0.5) < 0); 
			assert((cmp(1, 2)>0)==(std.math.cmp(1.0,2.0)>0)); 
			assert(cmp(1, 1)==0); 
			assert((cmp(2, 1)>0)==(std.math.cmp(2.0,1.0)>0)); 
			assert(
				cmp(vec2(1),1)==vec2(cmp(1,1)) && cmp(vec2(1),2)==vec2(cmp(1,2))
								&& cmp(vec2(2),1)==vec2(cmp(2,1))
			); 
			
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
						
				//min()/max() works for ranges too (unlike std.min. It's the reasonable way
				//to do minEpement on vectors.
				//MinElement uses componentwise opCmp, it's just for sorting.
				alias arr = AliasSeq!(vec2(3, 4), vec2(9, 11), vec2(14, 2)); 
				static assert(is(typeof([arr]) == vec2[])); 
				assert(min([arr]) == min(arr)); 
				assert(max([arr]) == max(arr)); 
			}
					
			{
				auto a = vec2(1,2); 
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
					
			assert(avg(vec2(1,2), vec2(3,4), vec2(5)).approxEqual(vec2(1+3+5, 2+4+5)/3.0)); 
			assert(avg([vec2(1,2), vec2(3,4), vec2(5)]).approxEqual(vec2(1+3+5, 2+4+5)/3.0)); 
					
			assert(is(typeof(mix(ubyte.init, ubyte.init, 0.0)) == ubyte)); 
			//result type depends only on the first 2 parameters
					
			{
				//test if avg() and mix() keeps the right types
				static immutable RGB clRed = 0xFF, clBlue = 0xFF0000; 
				auto x = RGB(127, 0, 127); 
				{ auto a = mix(clRed, clBlue, .5); 	 assert(a==x && is(typeof(a)==RGB)); }
				{ auto a = avg(clRed, clBlue); 	 assert(a==x && is(typeof(a)==RGB)); }
				{ auto a = avg([clRed, clBlue]); 	 assert(a==x && is(typeof(a)==RGB)); }
			}
					
			assert(step(vec3(1, 2, 3), 2) == vec3(1, 1, 0)); 
			assert(is(typeof(step(1,2 ))==int)); 
			assert(is(typeof(step(vec2(1), 2.))==dvec2)); 
					
			assert(
				8.iota.map!(i => (smoothstep(ivec2(0, 2), 9, i)*100).iround )
								.equal(
					[
						ivec2(0, 0), ivec2(3, 0), ivec2(13, 0), ivec2(26, 6),
										ivec2(42, 20), ivec2(58, 39), ivec2(74, 61), ivec2(87, 80)
					] 
				)
			); 
					
			{
				//nan, inf handling
				assert(float.init.isnan); 
				assert(!float.init.isfin); 
				const n = vec4(1, NaN(5421), -float.infinity, float.init); 
				assert(n.isnan == bvec4(0, 1, 0, 1)); 
				assert(n.isinf == bvec4(0, 0, 1, 0)); 
				assert(n.isfin == bvec4(1, 0, 0, 0)); 
			}
					
			{
				//std.math only things
				assert(isPowerOf2(vec4(1,2,3,4))==bvec4(true, true, false, true)); 
				static assert(is(typeof(nextPow2(2))==int)); 
				static assert(is(typeof(truncPow2(2.5L))==real)); 
				assert(nextPow2(2)==4 && nextPow2(3.5)==4); 
				assert(prevPow2(2)==1 && prevPow2(2.5)==2); 
				assert(truncPow2(3.5)==2 && truncPow2(2)==2); 
				assert(nextUp(1.0f)>1 && nextDown(1.0)<1); 
				assert(nextAfter(5.0, 6)>5 && nextAfter(5.0, 4)<5); 
			}
			{
				//Bit conversions
				const v = vec4(1, -2, 3, PI); 
				assert(v.floatBitsToInt == ivec4(1065353216, -1073741824, 1077936128, 1078530011)); 
				assert(-2.0f.floatBitsToUint == 3221225472); 
				assert(1078530011.intBitsToFloat.approxEqual(PI)); 
				assert(uvec2(1077936128, 1078530011).uintBitsToFloat.approxEqual(vec2(3, PI))); 
			}
					
			assert(fma(2, 3, vec2(10, 20))==vec2(16, 26)); 
			assert(absDiff(vec2(1, 15), 10) == vec2(9, 5)); 
			assert(absDiff(Vector!(ushort, 3)(1, 2, 3), Vector!(ushort, 3)(3, 2, 1)) == Vector!(ushort, 3)(2, 0, 2)); 
			assert(sad(Vector!(ubyte, 2)(250, 240), 10) == 240+230); //must not summarize on ubyte, but int.
					
			assert(vec4(-1, 0.4, 0.6, 2).quantize!3 == ivec4(0, 1, 1, 2)); 
			assert(RGBA(0, 1, 2, 3).dequantize!4 .approxEqual(vec4(0, 0.333, 0.666, 1))); 
			assert(Vector!(ubyte, 2)(0, 255).dequantize!256 .approxEqual(vec2(0, 1))); 
					
			assert([2	  ].product == 2	 ); 
			assert([2, 3	  ].product == 2*3	 ); 
			assert([2, 3, 4].product == 2*3*4); 
					
			assert(iota2D(ivec2(3, 2)).equal([ivec2(0, 0), ivec2(1, 0), ivec2(2, 0), ivec2(0, 1), ivec2(1, 1), ivec2(2, 1)])); 
		} 
	}
}
////////////////////////////////////////////////////////////////////////////////
///  Tests                                                                   ///
////////////////////////////////////////////////////////////////////////////////


//Todo: when the ide supports unit testing, this should be private. Also needs real unittest{} blocks.
void unittest_main() {
	//version(assert) {}else enforce(0, "Turn on debug build for asserts."); 
	version(assert)
	{
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
		unittest_ImageElementType; 
		unittest_Image; 
		unittest_Other; 
	}
} 

unittest { unittest_main; } 