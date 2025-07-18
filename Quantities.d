module het.quantities; 

/+
	This modified version contains all the modules of the quantities package in a single D module.
	This way my incremental build system builds it faster.
	
	Copyright: Copyright 2013-2018, Nicolas Sicard
	Authors: Nicolas Sicard
	License: $(LINK www.boost.org/LICENSE_1_0.txt, Boost License 1.0)
	Source: $(LINK https://github.com/biozic/quantities)
+/

/+
	+
	Importing `quantities.si` instantiate all the definitions of the SI units,
	prefixes, parsing functions and formatting functions, both at run-time and
	compile-time, storint their values as a `double`.
	
	Copyright: Copyright 2013-2018, Nicolas Sicard
	Authors: Nicolas Sicard
	License: $(LINK www.boost.org/LICENSE_1_0.txt, Boost License 1.0)
	Standards: $(LINK http://www.bipm.org/en/si/si_brochure/)
	Source: $(LINK https://github.com/biozic/quantities)
+/

mixin SIDefinitions!double; 

private: 

version(/+$DIDE_REGION Common+/all)
{
	/+
		+
		Creates a new prefix function that multiplies a QVariant by a factor.
	+/
	template prefix(alias fact)
	{
		import std.traits : isNumeric; 
		
		alias N = typeof(fact); 
		static assert(isNumeric!N, "Incompatible type: " ~ N.stringof); 
		
		/// The prefix factor
		enum factor = fact; 
		
		/// The prefix function
		auto prefix(Q)(auto ref const Q base)
				if (isQVariantOrQuantity!Q)
		{ return base * fact; } 
	} 
	///
	@safe pure unittest
	{
		auto meter = unit!double("L"); 
		alias milli = prefix!1e-3; 
		assert(milli(meter) == 1e-3 * meter); 
	} 
}
version(/+$DIDE_REGION Dimensions+/all)
{
	/+
		+
		Structs used to define units: rational numbers and dimensions.
		
		Copyright: Copyright 2013-2018, Nicolas Sicard
		Authors: Nicolas Sicard
		License: $(LINK www.boost.org/LICENSE_1_0.txt, Boost License 1.0)
		Source: $(LINK https://github.com/biozic/quantities)
	+/ 
	//module quantities.dimensions
	
	import std.algorithm : countUntil, remove, isSorted; 
	import std.array; 
	import std.conv; 
	import std.exception; 
	import std.format; 
	import std.math; 
	import std.string; 
	import std.traits; 
	
	import std.math: abs; 
	
	alias rank_t = size_t; //230916 realhet
	
	/// Reduced implementation of a rational number
	struct Rational
	{
		private: 
			int num = 0; 
			int den = 1; 
		
			invariant
		{ assert(den != 0); } 
		
			void normalize() @safe pure nothrow
		{
			if(den == 1)
			return; 
			if(den < 0)
			{
				num = -num; 
				den = -den; 
			}
			immutable g = gcd(num, den); 
			num /= g; 
			den /= g; 
		} 
		
			bool isNormalized() @safe pure nothrow const
		{ return den >= 0 && gcd(num, den) == 1; } 
		
		public: 
			/+
			+
				Create a rational number.
			
				Params:
					num = The numerator
					den = The denominator
		+/
			this(int num, int den = 1) @safe pure nothrow
		{
			assert(den != 0, "Denominator is zero"); 
			this.num = num; 
			this.den = den; 
			normalize(); 
		} 
		
			bool isInt() @property @safe pure nothrow const
		{ return den == 1; } 
		
			Rational inverted() @property @safe pure nothrow const
		{
			Rational result; 
			result.num = den; 
			result.den = num; 
			assert(isNormalized); 
			return result; 
		} 
		
			void opOpAssign(string op)(Rational other) @safe pure nothrow
					if (op == "+" || op == "-" || op == "*" || op == "/")
		{
			mixin("this = this" ~ op ~ "other;"); 
			assert(isNormalized); 
		} 
		
			void opOpAssign(string op)(int value) @safe pure nothrow
					if (op == "+" || op == "-" || op == "*" || op == "/")
		{
			mixin("this = this" ~ op ~ "value;"); 
			assert(isNormalized); 
		} 
		
			Rational opUnary(string op)() @safe pure nothrow const
					if (op == "+" || op == "-")
			out (result)
		{ assert(result.isNormalized); } 
			body
		{ return Rational(mixin(op ~ "num"), den); } 
		
			Rational opBinary(string op)(Rational other) @safe pure nothrow const
					if (op == "+" || op == "-")
		{
			auto ret = Rational(mixin("num * other.den" ~ op ~ "other.num * den"), den * other.den); 
			ret.normalize(); 
			return ret; 
		} 
		
			Rational opBinary(string op)(Rational other) @safe pure nothrow const
					if (op == "*")
		{
			auto ret = Rational(num * other.num, den * other.den); 
			ret.normalize(); 
			return ret; 
		} 
		
			Rational opBinary(string op)(Rational other) @safe pure nothrow const
					if (op == "/")
		{
			auto ret = Rational(num * other.den, den * other.num); 
			ret.normalize(); 
			return ret; 
		} 
		
			Rational opBinary(string op)(int value) @safe pure nothrow const
					if (op == "+" || op == "-" || op == "*" || op == "/")
			out
		{ assert(isNormalized); } 
			body
		{ return mixin("this" ~ op ~ "Rational(value)"); } 
		
			bool opEquals(Rational other) @safe pure nothrow const
		{ return num == other.num && den == other.den; } 
		
			bool opEquals(int value) @safe pure nothrow const
		{ return num == value && den == 1; } 
		
			int opCmp(Rational other) @safe pure nothrow const
		{
			immutable diff = (num / cast(double) den) - (other.num / cast(double) other.den); 
			if(diff == 0)
			return 0; 
			if(diff > 0)
			return 1; 
			return -1; 
		} 
		
			int opCmp(int value) @safe pure nothrow const
		{ return opCmp(Rational(value)); } 
		
			T opCast(T)() @safe pure nothrow const
					if (isNumeric!T)
		{ return num / cast(T) den; } 
		
			void toString(scope void delegate(const(char)[]) sink) const
		{
			sink.formattedWrite!"%d"(num); 
			if(den != 1)
			{
				sink("/"); 
				sink.formattedWrite!"%d"(den); 
			}
		} 
	} 
	
	private int gcd(int x, int y) @safe pure nothrow
	{
		if(x == 0 || y == 0)
		return 1; 
		
		int tmp; 
		int a = abs(x); 
		int b = abs(y); 
		while(a > 0)
		{
			tmp = a; 
			a = b % a; 
			b = tmp; 
		}
		return b; 
	} 
	
	/// Struct describing properties of a dimension in a dimension vector.
	struct Dim
	{
		string symbol; /// The symbol of the dimension
		Rational power; /// The power of the dimension
		rank_t rank = rank_t.max; /// The rank of the dimension in the vector
		
		this(string symbol, Rational power, rank_t rank = rank_t.max) @safe pure nothrow
		{
			this.symbol = symbol; 
			this.power = power; 
			this.rank = rank; 
		} 
		
		this(string symbol, int power, rank_t rank = rank_t.max) @safe pure nothrow
		{ this(symbol, Rational(power), rank); } 
		
		int opCmp(Dim other) @safe pure nothrow const
		{
			if(rank == other.rank)
			{
				if(symbol < other.symbol)
				return -1; 
				else if(symbol > other.symbol) return 1; 
				else return 0; 
			}
			else {
				if(rank < other.rank)
				return -1; 
				else if(rank > other.rank) return 1; 
				else assert(false); 
			}
		} 
		
		///
		void toString(scope void delegate(const(char)[]) sink) const
		{
			if(power == 0)
			return; 
			if(power == 1)
			sink(symbol); 
			else {
				sink.formattedWrite!"%s"(symbol); 
				sink("^"); 
				sink.formattedWrite!"%s"(power); 
			}
		} 
	} 
	
	private immutable(Dim)[] inverted(immutable(Dim)[] source) @safe pure nothrow
	{
		Dim[] target = source.dup; 
		foreach(ref dim; target)
		dim.power = -dim.power; 
		return target.immut; 
	} 
	
	private void insertAndSort(ref Dim[] list, string symbol, Rational power, rank_t rank) @safe pure
	{
		auto pos = list.countUntil!(d => d.symbol == symbol)(); 
		if(pos >= 0)
		{
			//Merge the dimensions
			list[pos].power += power; 
			if(list[pos].power == 0)
			{
				try
				list = list.remove(pos); 
				catch(
					Exception//remove only throws when it has multiple arguments
				) assert(false); 
				
				//Necessary to compare dimensionless values
				if(!list.length)
				list = null; 
			}
		}
		else {
			//Insert the new dimension
			auto dim = Dim(symbol, power, rank); 
			pos = list.countUntil!(d => d > dim); 
			if(pos < 0)
			pos = list.length; 
			list.insertInPlace(pos, dim); 
		}
		assert(list.isSorted); 
	} 
	
	private immutable(Dim)[] immut(Dim[] source) @trusted pure nothrow
	{
		if(__ctfe)
		return source.idup; 
		else return source.assumeUnique; 
	} 
	
	private immutable(Dim)[] insertSorted(
		immutable(Dim)[] source, string symbol,
			Rational power, rank_t rank
	) @safe pure
	{
		if(power == 0)
		return source; 
		
		if(!source.length)
		return [Dim(symbol, power, rank)].immut; 
		
		Dim[] list = source.dup; 
		insertAndSort(list, symbol, power, rank); 
		return list.immut; 
	} 
	private immutable(Dim)[] insertSorted(immutable(Dim)[] source, immutable(Dim)[] other) @safe pure
	{
		Dim[] list = source.dup; 
		foreach(dim; other)
		insertAndSort(list, dim.symbol, dim.power, dim.rank); 
		return list.immut; 
	} 
	
	/// A vector of dimensions
	struct Dimensions
	{
		private: 
			immutable(Dim)[] _dims; 
		
		package(quantities): 
			static Dimensions mono(string symbol, rank_t rank) @safe pure nothrow
		{
			if(!symbol.length)
			return Dimensions(null); 
			return Dimensions([Dim(symbol, 1, rank)].immut); 
		} 
		
		public: 
			this(this) @safe pure nothrow
		{ _dims = _dims.idup; } 
		
			ref Dimensions opAssign()(auto ref const Dimensions other) @safe pure nothrow
		{
			_dims = other._dims.idup; 
			return this; 
		} 
		
			/// The dimensions stored in this vector
			immutable(Dim)[] dims() @safe pure nothrow const
		{ return _dims; } 
		
			alias dims this; 
		
			bool empty() @safe pure nothrow const
		{ return _dims.empty; } 
		
			Dimensions inverted() @safe pure nothrow const
		{ return Dimensions(_dims.inverted); } 
		
			Dimensions opUnary(string op)() @safe pure nothrow const
					if (op == "~")
		{ return Dimensions(_dims.inverted); } 
			Dimensions opBinary(string op)(const Dimensions other) @safe pure const
					if (op == "*")
		{ return Dimensions(_dims.insertSorted(other._dims)); } 
		
			Dimensions opBinary(string op)(const Dimensions other) @safe pure const
					if (op == "/")
		{ return Dimensions(_dims.insertSorted(other._dims.inverted)); } 
			Dimensions pow(Rational n) @safe pure nothrow const
		{
			if(n == 0)
			return Dimensions.init; 
			
			auto list = _dims.dup; 
			foreach(ref dim; list)
			dim.power = dim.power * n; 
			return Dimensions(list.immut); 
		} 
		
			Dimensions pow(int n) @safe pure nothrow const
		{ return pow(Rational(n)); } 
		
			Dimensions powinverse(Rational n) @safe pure nothrow const
		{
			import std.exception : enforce; 
			import std.string : format; 
			
			auto list = _dims.dup; 
			foreach(ref dim; list)
			dim.power = dim.power / n; 
			return Dimensions(list.immut); 
		} 
		
			Dimensions powinverse(int n) @safe pure nothrow const
		{ return powinverse(Rational(n)); } 
		
			void toString(scope void delegate(const(char)[]) sink) const
		{ sink.formattedWrite!"[%(%s %)]"(_dims); } 
	} 
	
	//Tests
	
	
	@("Rational") unittest
	{
		const r = Rational(6, -8); 
		assert(r.text == "-3/4"); 
		assert((+r).text == "-3/4"); 
		assert((-r).text == "3/4"); 
		
		const r1 = Rational(4, 3) + Rational(2, 5); 
		assert(r1.text == "26/15"); 
		const r2 = Rational(4, 3) - Rational(2, 5); 
		assert(r2.text == "14/15"); 
		const r3 = Rational(8, 7) * Rational(3, -2); 
		assert(r3.text == "-12/7"); 
		const r4 = Rational(8, 7) / Rational(3, -2); 
		assert(r4.text == "-16/21"); 
		
		auto r5 = Rational(4, 3); 
		r5 += Rational(2, 5); 
		assert(r5.text == "26/15"); 
		
		auto r6 = Rational(8, 7); 
		r6 /= Rational(2, -3); 
		assert(r6.text == "-12/7"); 
		
		assert(Rational(8, 7) == Rational(-16, -14)); 
		assert(Rational(2, 5) < Rational(3, 7)); 
	} 
	
	@("Dim[].inverted")@safe pure nothrow unittest
	{
		auto list = [Dim("A", 2), Dim("B", -2)].idup; 
		auto inv = [Dim("A", -2), Dim("B", 2)].idup; 
		assert(list.inverted == inv); 
	} 
	
	@("Dim[].insertAndSort")@safe pure unittest
	{
		Dim[] list; 
		list.insertAndSort("A", Rational(1), 1); 
		assert(list == [Dim("A", 1, 1)]); 
		list.insertAndSort("A", Rational(1), 1); 
		assert(list == [Dim("A", 2, 1)]); 
		list.insertAndSort("A", Rational(-2), 1); 
		assert(list.length == 0); 
		list.insertAndSort("B", Rational(1), 3); 
		assert(list == [Dim("B", 1, 3)]); 
		list.insertAndSort("C", Rational(1), 1); 
		assert(Dim("C", 1, 1) < Dim("B", 1, 3)); 
		assert(list == [Dim("C", 1, 1), Dim("B", 1, 3)]); 
	} 
	
	@("Dimensions *") @safe pure unittest
	{
		auto dim1 = Dimensions([Dim("a", 1), Dim("b", -2)]); 
		auto dim2 = Dimensions([Dim("a", -1), Dim("c", 2)]); 
		assert(dim1 * dim2 == Dimensions([Dim("b", -2), Dim("c", 2)])); 
	} 
	
	@("Dimensions /")@safe pure unittest
	{
		auto dim1 = Dimensions([Dim("a", 1), Dim("b", -2)]); 
		auto dim2 = Dimensions([Dim("a", 1), Dim("c", 2)]); 
		assert(dim1 / dim2 == Dimensions([Dim("b", -2), Dim("c", -2)])); 
	} 
	
	@("Dimensions pow")@safe pure nothrow unittest
	{
		auto dim = Dimensions([Dim("a", 5), Dim("b", -2)]); 
		assert(dim.pow(Rational(2)) == Dimensions([Dim("a", 10), Dim("b", -4)])); 
		assert(dim.pow(Rational(0)) == Dimensions.init); 
	} 
	
	@("Dimensions.powinverse") @safe pure nothrow unittest
	{
		auto dim = Dimensions([Dim("a", 6), Dim("b", -2)]); 
		assert(dim.powinverse(Rational(2)) == Dimensions([Dim("a", 3), Dim("b", -1)])); 
	} 
	
	@("Dimensions.toString") unittest
	{
		auto dim = Dimensions([Dim("a", 1), Dim("b", -2)]); 
		assert(dim.text == "[a b^-2]"); 
		assert(Dimensions.init.text == "[]"); 
	} 
}version(/+$DIDE_REGION Compiletime+/all)
{
	/+
		+
		This module defines quantities that are statically checked for dimensional
		consistency at compile-time.
		
		The dimensions are part of their types, so that the compilation fails if an
		operation or a function call is not dimensionally consistent.
		
		Copyright: Copyright 2013-2018, Nicolas Sicard
		Authors: Nicolas Sicard
		License: $(LINK www.boost.org/LICENSE_1_0.txt, Boost License 1.0)
		Source: $(LINK https://github.com/biozic/quantities)
	+/ 
	//module quantities.compiletime
	///
	unittest
	{
		import std.format : format; 
		import std.math : isClose; 
		
		//Introductory example
		{
			//Use the predefined quantity types (in module quantities.si)
			Volume volume; 
			Concentration concentration; 
			Mass mass; 
			
			//Define a new quantity type
			alias MolarMass = typeof(kilogram / mole); 
			
			//I have to make a new solution at the concentration of 5 mmol/L
			concentration = 5.0 * milli(mole) / liter; 
			
			//The final volume is 100 ml.
			volume = 100.0 * milli(liter); 
			
			//The molar mass of my compound is 118.9 g/mol
			MolarMass mm = 118.9 * gram / mole; 
			
			//What mass should I weigh?
			mass = concentration * volume * mm; 
			assert(format("%s", mass) == "5.945e-05 [M]"); 
			//Wait! That's not really useful!
			assert(siFormat!"%.1f mg"(mass) == "59.5 mg"); 
		}
		
		//Working with predefined units
		{
			auto distance = 384_400 * kilo(meter); //From Earth to Moon
			auto speed = 299_792_458 * meter / second; //Speed of light
			auto time = distance / speed; 
			assert(time.siFormat!"%.3f s" == "1.282 s"); 
		}
		
		//Dimensional correctness is check at compile-time
		{
			Mass mass; 
			assert(!__traits(compiles, mass = 15 * meter)); 
			assert(!__traits(compiles, mass = 1.2)); 
		}
		
		//Calculations can be done at compile-time
		{
			enum distance = 384_400 * kilo(meter); //From Earth to Moon
			enum speed = 299_792_458 * meter / second; //Speed of light
			enum time = distance / speed; 
			/*static*/
			assert(time.siFormat!"%.3f s" == "1.282 s"); 
			//NB. Phobos can't format floating point values at run-time.
		}
		
		//Create a new unit from the predefined ones
		{
			auto inch = 2.54 * centi(meter); 
			auto mile = 1609 * meter; 
			assert(mile.value(inch).isClose(63_346)); //inches in a mile
			//NB. Cannot use siFormatter, because inches are not SI units
		}
		
		//Create a new unit with new dimensions
		{
			//Create a new base unit of currency
			auto euro = unit!(double, "C"); //C is the chosen dimension symol (for currency...)
			
			auto dollar = euro / 1.35; 
			auto price = 2000 * dollar; 
			assert(price.value(euro).isClose(1481)); //Price in euros
		}
		
		//Compile-time parsing
		{
			enum distance = si!"384_400 km"; 
			enum speed = si!"299_792_458 m/s"; 
			assert(is(typeof(distance) == Length)); 
			assert(is(typeof(speed) == Speed)); 
		}
		
		//Run-time parsing of statically typed Quantities
		{
			auto data = ["distance-to-the-moon" : "384_400 km", "speed-of-light" : "299_792_458 m/s"]; 
			auto distance = parseSI!Length(data["distance-to-the-moon"]); 
			auto speed = parseSI!Speed(data["speed-of-light"]); 
		}
	} 
	import std.format; 
	import std.math; 
	import std.traits : isNumeric, isIntegral; 
	
	/+
		+
		A quantity checked at compile-time for dimensional consistency.
		
		Params:
			N = the numeric type of the quantity.
		
		See_Also:
			QVariant has the same public members and overloaded operators as Quantity.
	+/
	struct Quantity(N, alias dims)
	{
		
		//realhet 22.05.09:
			bool opCast() const
		{ return _value!=0; } 
		
			static assert(isNumeric!N); 
			static assert(is(typeof(dims) : Dimensions)); 
			static assert(Quantity.sizeof == N.sizeof); 
		
		private: 
			N _value; 
		
			//Creates a new quantity with non-empty dimensions
			static Quantity make(T)(T scalar)
					if (isNumeric!T)
		{
			Quantity result; 
			result._value = scalar; 
			return result; 
		} 
		
			void ensureSameDim(const Dimensions d)() const
		{
			static assert(
				dimensions == d,
								"Dimension error: %s is not consistent with %s".format(dimensions, d)
			); 
		} 
		
			void ensureEmpty(const Dimensions d)() const
		{ static assert(d.empty, "Dimension error: %s instead of no dimensions".format(d)); } 
		
		package(quantities): 
			alias valueType = N; 
		
			N rawValue() const
		{ return _value; } 
		
		public: 
			/+
			+
				Creates a new quantity from another one with the same dimensions.
			
				If Q is a QVariant, throws a DimensionException if the parsed quantity
				doesn't have the same dimensions as Q. If Q is a Quantity, inconsistent
				dimensions produce a compilation error.
		+/
			this(Q)(auto ref const Q qty)
					if (isQuantity!Q)
		{
			ensureSameDim!(Q.dimensions); 
			_value = qty._value; 
		} 
		
			/// ditto
			this(Q)(auto ref const Q qty)
					if (isQVariant!Q)
		{
			import std.exception; 
			
			enforce(
				dimensions == qty.dimensions,
								new DimensionException("Incompatible dimensions", dimensions, qty.dimensions)
			); 
			_value = qty.rawValue; 
		} 
		
			/// Creates a new dimensionless quantity from a number
			this(T)(T scalar)
					if (isNumeric!T && isDimensionless)
		{ _value = scalar; } 
		
			/// The dimensions of the quantity
			enum dimensions = dims; 
		
			/+
			+
				Implicitly convert a dimensionless value to the value type.
		+/
			static if(isDimensionless)
		{
			N get() const
			{ return _value; } 
			
			alias get this; 
		}
		
			/+
			+
				Gets the _value of this quantity when expressed in the given target unit.
			
				If Q is a QVariant, throws a DimensionException if the parsed quantity
				doesn't have the same dimensions as Q. If Q is a Quantity, inconsistent
				dimensions produce a compilation error.
		+/
			N value(Q)(auto ref const Q target) const
					if (isQuantity!Q)
		{
			mixin ensureSameDim!(Q.dimensions); 
			return _value / target._value; 
		} 
		
			/// ditto
			N value(Q)(auto ref const Q target) const
					if (isQVariant!Q)
		{
			import std.exception; 
			
			enforce(
				dimensions == target.dimensions,
				new DimensionException("Incompatible dimensions", dimensions, target.dimensions)
			); 
			return _value / target.rawValue; 
		} 
		
			/+
			+
				Test whether this quantity is dimensionless
		+/
			enum bool isDimensionless = dimensions.length == 0; 
		
			/+
			+
				Tests wheter this quantity has the same dimensions as another one.
		+/
			bool isConsistentWith(Q)(auto ref const Q qty) const
					if (isQVariantOrQuantity!Q)
		{ return dimensions == qty.dimensions; } 
		
			/+
			+
				Returns the base unit of this quantity.
		+/
			Quantity baseUnit() @property const
		{ return Quantity.make(1); } 
		
			/+
			+
				Cast a dimensionless quantity to a numeric type.
			
				The cast operation will throw DimensionException if the quantity is not
				dimensionless.
		+/
			static if(isDimensionless)
		{
			T opCast(T)() const
				if (isNumeric!T)
			{ return _value; } 
		}
		
			//Assign from another quantity
			/// Operator overloading
			ref Quantity opAssign(Q)(auto ref const Q qty)
					if (isQuantity!Q)
		{
			ensureSameDim!(Q.dimensions); 
			_value = qty._value; 
			return this; 
		} 
		
			/// ditto
			ref Quantity opAssign(Q)(auto ref const Q qty)
					if (isQVariant!Q)
		{
			import std.exception; 
			
			enforce(
				dimensions == qty.dimensions,
								new DimensionException("Incompatible dimensions", dimensions, qty.dimensions)
			); 
			_value = qty.rawValue; 
			return this; 
		} 
		
			//Assign from a numeric value if this quantity is dimensionless
			/// ditto
			ref Quantity opAssign(T)(T scalar)
					if (isNumeric!T)
		{
			ensureEmpty!dimensions; 
			_value = scalar; 
			return this; 
		} 
		
			//Unary + and -
			/// ditto
			Quantity opUnary(string op)() const
					if (op == "+" || op == "-")
		{ return Quantity.make(mixin(op ~ "_value")); } 
		
			//Unary ++ and --
			/// ditto
		
			Quantity opUnary(string op)()
					if (op == "++" || op == "--")
		{
			mixin(op ~ "_value;"); 
			return this; 
		} 
		
			//Add (or substract) two quantities if they share the same dimensions
			/// ditto
			Quantity opBinary(string op, Q)(auto ref const Q qty) const
					if (isQuantity!Q && (op == "+" || op == "-"))
		{
			ensureSameDim!(Q.dimensions); 
			return Quantity.make(mixin("_value" ~ op ~ "qty._value")); 
		} 
		
			//Add (or substract) a dimensionless quantity and a number
			/// ditto
			Quantity opBinary(string op, T)(T scalar) const
					if (isNumeric!T && (op == "+" || op == "-"))
		{
			ensureEmpty!dimensions; 
			return Quantity.make(mixin("_value" ~ op ~ "scalar")); 
		} 
		
			/// ditto
			Quantity opBinaryRight(string op, T)(T scalar) const
					if (isNumeric!T && (op == "+" || op == "-"))
		{
			ensureEmpty!dimensions; 
			return Quantity.make(mixin("scalar" ~ op ~ "_value")); 
		} 
		
			//Multiply or divide a quantity by a number
			/// ditto
			Quantity opBinary(string op, T)(T scalar) const
					if (isNumeric!T && (op == "*" || op == "/" || op == "%"))
		{ return Quantity.make(mixin("_value" ~ op ~ "scalar")); } 
		
			/// ditto
			Quantity opBinaryRight(string op, T)(T scalar) const
					if (isNumeric!T && op == "*")
		{ return Quantity.make(mixin("scalar" ~ op ~ "_value")); } 
		
			/// ditto
			auto opBinaryRight(string op, T)(T scalar) const
					if (isNumeric!T && (op == "/" || op == "%"))
		{
			alias RQ = Quantity!(N, dimensions.inverted()); 
			return RQ.make(mixin("scalar" ~ op ~ "_value")); 
		} 
		
			//Multiply or divide two quantities
			/// ditto
			auto opBinary(string op, Q)(auto ref const Q qty) const
					if (isQuantity!Q && (op == "*" || op == "/"))
		{
			alias RQ = Quantity!(N, mixin("dimensions" ~ op ~ "Q.dimensions")); 
			return RQ.make(mixin("_value" ~ op ~ "qty._value")); 
		} 
		
			/// ditto
			Quantity opBinary(string op, Q)(auto ref const Q qty) const
					if (isQuantity!Q && (op == "%"))
		{
			ensureSameDim!(Q.dimensions); 
			return Quantity.make(mixin("_value" ~ op ~ "qty._value")); 
		} 
		
			//Add/sub assign with a quantity that shares the same dimensions
			/// ditto
			void opOpAssign(string op, Q)(auto ref const Q qty)
					if (isQuantity!Q && (op == "+" || op == "-"))
		{
			ensureSameDim!(Q.dimensions); 
			mixin("_value " ~ op ~ "= qty._value;"); 
		} 
		
			//Add/sub assign a number to a dimensionless quantity
			/// ditto
			void opOpAssign(string op, T)(T scalar)
					if (isNumeric!T && (op == "+" || op == "-"))
		{
			ensureEmpty!dimensions; 
			mixin("_value " ~ op ~ "= scalar;"); 
		} 
		
			//Mul/div assign another dimensionless quantity to a dimensionsless quantity
			/// ditto
			void opOpAssign(string op, Q)(auto ref const Q qty)
					if (isQuantity!Q && (op == "*" || op == "/" || op == "%"))
		{
			ensureEmpty!dimensions; 
			mixin("_value" ~ op ~ "= qty._value;"); 
		} 
		
			//Mul/div assign a number to a quantity
			/// ditto
			void opOpAssign(string op, T)(T scalar)
					if (isNumeric!T && (op == "*" || op == "/"))
		{ mixin("_value" ~ op ~ "= scalar;"); } 
		
			/// ditto
			void opOpAssign(string op, T)(T scalar)
					if (isNumeric!T && op == "%")
		{
			ensureEmpty!dimensions; 
			mixin("_value" ~ op ~ "= scalar;"); 
		} 
		
			//Exact equality between quantities
			/// ditto
			bool opEquals(Q)(auto ref const Q qty) const
					if (isQuantity!Q)
		{
			ensureSameDim!(Q.dimensions); 
			return _value == qty._value; 
		} 
		
			//Exact equality between a dimensionless quantity and a number
			/// ditto
			bool opEquals(T)(T scalar) const
					if (isNumeric!T)
		{
			ensureEmpty!dimensions; 
			return _value == scalar; 
		} 
		
			//Comparison between two quantities
			/// ditto
			int opCmp(Q)(auto ref const Q qty) const
					if (isQuantity!Q)
		{
			ensureSameDim!(Q.dimensions); 
			if(_value == qty._value)
			return 0; 
			if(_value < qty._value)
			return -1; 
			return 1; 
		} 
		
			//Comparison between a dimensionless quantity and a number
			/// ditto
			int opCmp(T)(T scalar) const
					if (isNumeric!T)
		{
			ensureEmpty!dimensions; 
			if(_value < scalar)
			return -1; 
			if(_value > scalar)
			return 1; 
			return 0; 
		} 
		
			void toString(scope void delegate(const(char)[]) sink, FormatSpec!char fmt) const
		{
			sink.formatValue(_value, fmt); 
			sink(" "); 
			sink.formattedWrite!"%s"(dimensions); 
		} 
	} 
	
	/+
		+
		Creates a new monodimensional unit as a Quantity.
		
		Params:
			N = The numeric type of the value part of the quantity.
		
			dimSymbol = The symbol of the dimension of this quantity.
		
			rank = The rank of the dimensions of this quantity in the dimension vector,
				   when combining this quantity with other oned.
	+/
	auto unit(N, string dimSymbol, rank_t rank = rank_t.max)()
	{
		enum dims = Dimensions.mono(dimSymbol, rank); 
		return Quantity!(N, dims).make(1); 
	} 
	///
	unittest
	{
		enum meter = unit!(double, "L", 1); 
		enum kilogram = unit!(double, "M", 2); 
		//Dimensions will be in this order: L M
	} 
	
	/// Tests whether T is a quantity type.
	template isQuantity(T)
	{
		import std.traits : Unqual; 
		
		alias U = Unqual!T; 
		static if(is(U == Quantity!X, X...))
		enum isQuantity = true; 
		else enum isQuantity = false; 
	} 
	
	/// Basic math functions that work with Quantity.
	auto square(Q)(auto ref const Q quantity)
		if (isQuantity!Q)
	{ return Quantity!(Q.valueType, Q.dimensions.pow(2)).make(quantity._value ^^ 2); } 
	
	/// ditto
	auto sqrt(Q)(auto ref const Q quantity)
		if (isQuantity!Q)
	{ return Quantity!(Q.valueType, Q.dimensions.powinverse(2)).make(std.math.sqrt(quantity._value)); } 
	
	/// ditto
	auto cubic(Q)(auto ref const Q quantity)
		if (isQuantity!Q)
	{ return Quantity!(Q.valueType, Q.dimensions.pow(3)).make(quantity._value ^^ 3); } 
	
	/// ditto
	auto cbrt(Q)(auto ref const Q quantity)
		if (isQuantity!Q)
	{ return Quantity!(Q.valueType, Q.dimensions.powinverse(3)).make(std.math.cbrt(quantity._value)); } 
	
	/// ditto
	auto pow(int n, Q)(auto ref const Q quantity)
		if (isQuantity!Q)
	{ return Quantity!(Q.valueType, Q.dimensions.pow(n)).make(std.math.pow(quantity._value, n)); } 
	
	/// ditto
	auto nthRoot(int n, Q)(auto ref const Q quantity)
		if (isQuantity!Q)
	{ return Quantity!(Q.valueType, Q.dimensions.powinverse(n)).make(std.math.pow(quantity._value, 1.0 / n)); } 
	
	/// ditto
	Q abs(Q)(auto ref const Q quantity)
		if (isQuantity!Q)
	{ return Q.make(std.math.fabs(quantity._value)); } 
}version(/+$DIDE_REGION Runtime+/all)
{
	/+
		+
		This module defines dimensionally variant quantities, mainly for use at run-time.
		
		The dimensions are stored in a field, along with the numerical value of the
		quantity. Operations and function calls fail if they are not dimensionally
		consistent, by throwing a `DimensionException`.
		
		Copyright: Copyright 2013-2018, Nicolas Sicard
		Authors: Nicolas Sicard
		License: $(LINK www.boost.org/LICENSE_1_0.txt, Boost License 1.0)
		Source: $(LINK https://github.com/biozic/quantities)
	+/ 
	//module quantities.runtime; 
	 
	///
	unittest
	{
		import std.format : format; 
		import std.math : isClose; 
		
		//Note: the types of the predefined SI units (gram, mole, liter...)
		//are Quantity instances, not QVariant instance.
		
		//Introductory example
		{
			//I have to make a new solution at the concentration of 5 mmol/L
			QVariant!double concentration = 5.0 * milli(mole) / liter; 
			
			//The final volume is 100 ml.
			QVariant!double volume = 100.0 * milli(liter); 
			
			//The molar mass of my compound is 118.9 g/mol
			QVariant!double molarMass = 118.9 * gram / mole; 
			
			//What mass should I weigh?
			QVariant!double mass = concentration * volume * molarMass; 
			assert(format("%s", mass) == "5.945e-05 [M]"); 
			//Wait! That's not really useful!
			assert(siFormat!"%.1f mg"(mass) == "59.5 mg"); 
		}
		
		//Working with predefined units
		{
			QVariant!double distance = 384_400 * kilo(meter); //From Earth to Moon
			QVariant!double speed = 299_792_458 * meter / second; //Speed of light
			QVariant!double time = distance / speed; 
			assert(time.siFormat!"%.3f s" == "1.282 s"); 
		}
		
		//Dimensional correctness
		{
			import std.exception : assertThrown; 
			
			QVariant!double mass = 4 * kilogram; 
			assertThrown!DimensionException(mass + meter); 
			assertThrown!DimensionException(mass == 1.2); 
		}
		
		//Create a new unit from the predefined ones
		{
			QVariant!double inch = 2.54 * centi(meter); 
			QVariant!double mile = 1609 * meter; 
			assert(mile.value(inch).isClose(63_346)); //inches in a mile
			//NB. Cannot use siFormatter, because inches are not SI units
		}
		
		//Create a new unit with new dimensions
		{
			//Create a new base unit of currency
			QVariant!double euro = unit!double("C"); //C is the chosen dimension symol (for currency...)
			
			QVariant!double dollar = euro / 1.35; 
			QVariant!double price = 2000 * dollar; 
			assert(price.value(euro).isClose(1481)); //Price in euros
		}
		
		//Run-time parsing
		{
			auto data = ["distance-to-the-moon" : "384_400 km", "speed-of-light" : "299_792_458 m/s"]; 
			QVariant!double distance = parseSI(data["distance-to-the-moon"]); 
			QVariant!double speed = parseSI(data["speed-of-light"]); 
			QVariant!double time = distance / speed; 
		}
	} 
	
	import std.conv; 
	import std.exception; 
	import std.format; 
	import std.math; 
	import std.string; 
	import std.traits; 
	
	/+
		+
		Exception thrown when operating on two units that are not interconvertible.
	+/
	class DimensionException : Exception
	{
		/// Holds the dimensions of the quantity currently operated on
		Dimensions thisDim; 
		/// Holds the dimensions of the eventual other operand
		Dimensions otherDim; 
		
		mixin basicExceptionCtors; 
		
		this(
			string msg, Dimensions thisDim, Dimensions otherDim,
						string file = __FILE__, size_t line = __LINE__, Throwable next = null
		) @safe pure nothrow
		{
			super(msg, file, line, next); 
			this.thisDim = thisDim; 
			this.otherDim = otherDim; 
		} 
	} 
	///
	unittest
	{
		import std.exception : assertThrown; 
		
		enum meter = unit!double("L"); 
		enum second = unit!double("T"); 
		assertThrown!DimensionException(meter + second); 
	} 
	
	/+
		+
		A dimensionnaly variant quantity.
		
		Params:
			N = the numeric type of the quantity.
		
		See_Also:
			QVariant has the same public members and overloaded operators as Quantity.
	+/
	struct QVariant(N)
	{
			static assert(isNumeric!N, "Incompatible type: " ~ N.stringof); 
		
		private: 
			N _value; 
			Dimensions _dimensions; 
		
			void checkDim(Dimensions dim) @safe pure const
		{
			enforce(
				_dimensions == dim,
				new DimensionException("Incompatible dimensions", _dimensions, dim)
			); 
		} 
		
			void checkDimensionless() @safe pure const
		{
			enforce(
				_dimensions.empty, new DimensionException(
					"Not dimensionless",
					_dimensions, Dimensions.init
				)
			); 
		} 
		
		package(quantities): 
			alias valueType = N; 
		
			N rawValue() const
		{ return _value; } 
		
		public: 
			//Creates a new quantity with non-empty dimensions
			this(T)(T scalar, const Dimensions dim)
					if (isNumeric!T)
		{
			_value = scalar; 
			_dimensions = dim; 
		} 
		
			/// Creates a new quantity from another one with the same dimensions
			this(Q)(auto ref const Q qty)
					if (isQVariant!Q)
		{
			_value = qty._value; 
			_dimensions = qty._dimensions; 
		} 
		
			/// ditto
			this(Q)(auto ref const Q qty)
					if (isQuantity!Q)
		{ this = qty.qVariant; } 
		
			/// Creates a new dimensionless quantity from a number
			this(T)(T scalar)
					if (isNumeric!T)
		{
			_dimensions = Dimensions.init; 
			_value = scalar; 
		} 
		
			/// Returns the dimensions of the quantity
			Dimensions dimensions() @property const
		{ return _dimensions; } 
		
			/+
			+
				Implicitly convert a dimensionless value to the value type.
			
				Calling get will throw DimensionException if the quantity is not
				dimensionless.
		+/
			N get() const
		{
			checkDimensionless; 
			return _value; 
		} 
		
			alias get this; 
		
			/+
			+
				Gets the _value of this quantity when expressed in the given target unit.
		+/
			N value(Q)(auto ref const Q target) const 
					if (isQVariantOrQuantity!Q)
		{
			checkDim(target.dimensions); 
			return _value / target.rawValue; 
		} 
			///
			@safe pure unittest
		{
			auto minute = unit!int("T"); 
			auto hour = 60 * minute; 
			
			QVariant!int time = 120 * minute; 
			assert(time.value(hour) == 2); 
			assert(time.value(minute) == 120); 
		} 
		
			/+
			+
				Test whether this quantity is dimensionless
		+/
			bool isDimensionless() @property const
		{ return _dimensions.empty; } 
		
			/+
			+
				Tests wheter this quantity has the same dimensions as another one.
		+/
			bool isConsistentWith(Q)(auto ref const Q qty) const 
					if (isQVariantOrQuantity!Q)
		{ return _dimensions == qty.dimensions; } 
			///
			@safe pure unittest
		{
			auto second = unit!double("T"); 
			auto minute = 60 * second; 
			auto meter = unit!double("L"); 
			
			assert(minute.isConsistentWith(second)); 
			assert(!meter.isConsistentWith(second)); 
		} 
		
			/+
			+
				Returns the base unit of this quantity.
		+/
			QVariant baseUnit() @property const
		{ return QVariant(1, _dimensions); } 
		
			/+
			+
				Cast a dimensionless quantity to a numeric type.
			
				The cast operation will throw DimensionException if the quantity is not
				dimensionless.
		+/
			T opCast(T)() const 
					if (isNumeric!T)
		{
			checkDimensionless; 
			return _value; 
		} 
		
			//Assign from another quantity
			/// Operator overloading
			ref QVariant opAssign(Q)(auto ref const Q qty)
					if (isQVariantOrQuantity!Q)
		{
			_dimensions = qty.dimensions; 
			_value = qty.rawValue; 
			return this; 
		} 
		
			//Assign from a numeric value if this quantity is dimensionless
			/// ditto
			ref QVariant opAssign(T)(T scalar)
					if (isNumeric!T)
		{
			_dimensions = Dimensions.init; 
			_value = scalar; 
			return this; 
		} 
		
			//Unary + and -
			/// ditto
			QVariant!N opUnary(string op)() const 
					if (op == "+" || op == "-")
		{ return QVariant(mixin(op ~ "_value"), _dimensions); } 
		
			//Unary ++ and --
			/// ditto
			QVariant!N opUnary(string op)()
					if (op == "++" || op == "--")
		{
			mixin(op ~ "_value;"); 
			return this; 
		} 
		
			//Add (or substract) two quantities if they share the same dimensions
			/// ditto
			QVariant!N opBinary(string op, Q)(auto ref const Q qty) const 
					if (isQVariantOrQuantity!Q && (op == "+" || op == "-"))
		{
			checkDim(qty.dimensions); 
			return QVariant(mixin("_value" ~ op ~ "qty.rawValue"), _dimensions); 
		} 
		
			/// ditto
			QVariant!N opBinaryRight(string op, Q)(auto ref const Q qty) const 
					if (isQVariantOrQuantity!Q && (op == "+" || op == "-"))
		{
			checkDim(qty.dimensions); 
			return QVariant(mixin("qty.rawValue" ~ op ~ "_value"), _dimensions); 
		} 
		
			//Add (or substract) a dimensionless quantity and a number
			/// ditto
			QVariant!N opBinary(string op, T)(T scalar) const 
					if (isNumeric!T && (op == "+" || op == "-"))
		{
			checkDimensionless; 
			return QVariant(mixin("_value" ~ op ~ "scalar"), _dimensions); 
		} 
		
			/// ditto
			QVariant!N opBinaryRight(string op, T)(T scalar) const 
					if (isNumeric!T && (op == "+" || op == "-"))
		{
			checkDimensionless; 
			return QVariant(mixin("scalar" ~ op ~ "_value"), _dimensions); 
		} 
		
			//Multiply or divide a quantity by a number
			/// ditto
			QVariant!N opBinary(string op, T)(T scalar) const 
					if (isNumeric!T && (op == "*" || op == "/" || op == "%"))
		{ return QVariant(mixin("_value" ~ op ~ "scalar"), _dimensions); } 
		
			/// ditto
			QVariant!N opBinaryRight(string op, T)(T scalar) const 
					if (isNumeric!T && op == "*")
		{ return QVariant(mixin("scalar" ~ op ~ "_value"), _dimensions); } 
		
			/// ditto
			QVariant!N opBinaryRight(string op, T)(T scalar) const 
					if (isNumeric!T && (op == "/" || op == "%"))
		{ return QVariant(mixin("scalar" ~ op ~ "_value"), ~_dimensions); } 
		
			//Multiply or divide two quantities
			/// ditto
			QVariant!N opBinary(string op, Q)(auto ref const Q qty) const 
					if (isQVariantOrQuantity!Q && (op == "*" || op == "/"))
		{
			return QVariant(
				mixin("_value" ~ op ~ "qty.rawValue"),
								mixin("_dimensions" ~ op ~ "qty.dimensions")
			); 
		} 
		
			/// ditto
			QVariant!N opBinaryRight(string op, Q)(auto ref const Q qty) const 
					if (isQVariantOrQuantity!Q && (op == "*" || op == "/"))
		{
			return QVariant(
				mixin("qty.rawValue" ~ op ~ "_value"),
								mixin("qty.dimensions" ~ op ~ "_dimensions")
			); 
		} 
		
			/// ditto
			QVariant!N opBinary(string op, Q)(auto ref const Q qty) const 
					if (isQVariantOrQuantity!Q && (op == "%"))
		{
			checkDim(qty.dimensions); 
			return QVariant(_value % qty.rawValue, _dimensions); 
		} 
		
			/// ditto
			QVariant!N opBinaryRight(string op, Q)(auto ref const Q qty) const 
					if (isQVariantOrQuantity!Q && (op == "%"))
		{
			checkDim(qty.dimensions); 
			return QVariant(qty.rawValue % _value, _dimensions); 
		} 
		
			/// ditto
			QVariant!N opBinary(string op, T)(T power) const 
					if (isIntegral!T && op == "^^")
		{ return QVariant(_value ^^ power, _dimensions.pow(Rational(power))); } 
		
			/// ditto
			QVariant!N opBinary(string op)(Rational power) const 
					if (op == "^^")
		{
			static if(isIntegral!N)
			auto newValue = std.math.pow(_value, cast(real) power).roundTo!N; 
			else static if(isFloatingPoint!N) auto newValue = std.math.pow(_value, cast(real) power); 
			else static assert(false, "Operation not defined for " ~ QVariant!N.stringof); 
			return QVariant(newValue, _dimensions.pow(power)); 
		} 
		
			//Add/sub assign with a quantity that shares the same dimensions
			/// ditto
			void opOpAssign(string op, Q)(auto ref const Q qty)
					if (isQVariantOrQuantity!Q && (op == "+" || op == "-"))
		{
			checkDim(qty.dimensions); 
			mixin("_value " ~ op ~ "= qty.rawValue;"); 
		} 
		
			//Add/sub assign a number to a dimensionless quantity
			/// ditto
			void opOpAssign(string op, T)(T scalar)
					if (isNumeric!T && (op == "+" || op == "-"))
		{
			checkDimensionless; 
			mixin("_value " ~ op ~ "= scalar;"); 
		} 
		
			//Mul/div assign another quantity to a quantity
			/// ditto
			void opOpAssign(string op, Q)(auto ref const Q qty)
					if (isQVariantOrQuantity!Q && (op == "*" || op == "/" || op == "%"))
		{
			mixin("_value" ~ op ~ "= qty.rawValue;"); 
			static if(op == "*")
			_dimensions = _dimensions * qty.dimensions; 
			else _dimensions = _dimensions / qty.dimensions; 
		} 
		
			//Mul/div assign a number to a quantity
			/// ditto
			void opOpAssign(string op, T)(T scalar)
					if (isNumeric!T && (op == "*" || op == "/"))
		{ mixin("_value" ~ op ~ "= scalar;"); } 
		
			/// ditto
			void opOpAssign(string op, T)(T scalar)
					if (isNumeric!T && op == "%")
		{
			checkDimensionless; 
			mixin("_value" ~ op ~ "= scalar;"); 
		} 
		
			//Exact equality between quantities
			/// ditto
			bool opEquals(Q)(auto ref const Q qty) const 
					if (isQVariantOrQuantity!Q)
		{
			checkDim(qty.dimensions); 
			return _value == qty.rawValue; 
		} 
		
			//Exact equality between a dimensionless quantity and a number
			/// ditto
			bool opEquals(T)(T scalar) const 
					if (isNumeric!T)
		{
			checkDimensionless; 
			return _value == scalar; 
		} 
		
			//Comparison between two quantities
			/// ditto
			int opCmp(Q)(auto ref const Q qty) const 
					if (isQVariantOrQuantity!Q)
		{
			checkDim(qty.dimensions); 
			if(_value == qty.rawValue)
			return 0; 
			if(_value < qty.rawValue)
			return -1; 
			return 1; 
		} 
		
			//Comparison between a dimensionless quantity and a number
			/// ditto
			int opCmp(T)(T scalar) const 
					if (isNumeric!T)
		{
			checkDimensionless; 
			if(_value < scalar)
			return -1; 
			if(_value > scalar)
			return 1; 
			return 0; 
		} 
		
			void toString(scope void delegate(const(char)[]) sink, FormatSpec!char fmt) const
		{
			sink.formatValue(_value, fmt); 
			sink(" "); 
			sink.formattedWrite!"%s"(_dimensions); 
		} 
	} 
	
	/+
		+
		Creates a new monodimensional unit as a QVariant.
		
		Params:
			N = The numeric type of the value part of the quantity.
		
			dimSymbol = The symbol of the dimension of this quantity.
		
			rank = The rank of the dimensions of this quantity in the dimension vector,
				   when combining this quantity with other oned.
	+/
	QVariant!N unit(N)(string dimSymbol, rank_t rank = rank_t.max)
	{ return QVariant!N(N(1), Dimensions.mono(dimSymbol, rank)); } 
	///
	unittest
	{
		enum meter = unit!double("L", 1); 
		enum kilogram = unit!double("M", 2); 
		//Dimensions will be in this order: L M
	} 
	
	//Tests whether T is a quantity type
	template isQVariant(T)
	{
		alias U = Unqual!T; 
		static if(is(U == QVariant!X, X...))
		enum isQVariant = true; 
		else enum isQVariant = false; 
	} 
	
	enum isQVariantOrQuantity(T) = isQVariant!T || isQuantity!T; 
	
	/// Turns a Quantity into a QVariant
	auto qVariant(Q)(auto ref const Q qty)
		if (isQuantity!Q)
	{ return QVariant!(Q.valueType)(qty.rawValue, qty.dimensions); } 
	
	/// Turns a scalar into a dimensionless QVariant
	auto qVariant(N)(N scalar)
		if (isNumeric!N)
	{ return QVariant!N(scalar, Dimensions.init); } 
	
	/// Basic math functions that work with QVariant.
	auto square(Q)(auto ref const Q quantity)
		if (isQVariant!Q)
	{ return Q(quantity._value ^^ 2, quantity._dimensions.pow(2)); } 
	
	/// ditto
	auto sqrt(Q)(auto ref const Q quantity)
		if (isQVariant!Q)
	{ return Q(std.math.sqrt(quantity._value), quantity._dimensions.powinverse(2)); } 
	
	/// ditto
	auto cubic(Q)(auto ref const Q quantity)
		if (isQVariant!Q)
	{ return Q(quantity._value ^^ 3, quantity._dimensions.pow(3)); } 
	
	/// ditto
	auto cbrt(Q)(auto ref const Q quantity)
		if (isQVariant!Q)
	{ return Q(std.math.cbrt(quantity._value), quantity._dimensions.powinverse(3)); } 
	
	/// ditto
	auto pow(Q)(auto ref const Q quantity, Rational r)
		if (isQVariant!Q)
	{ return quantity ^^ r; } 
	
	auto pow(Q, I)(auto ref const Q quantity, I n)
		if (isQVariant!Q && isIntegral!I)
	{ return quantity ^^ Rational(n); } 
	
	/// ditto
	auto nthRoot(Q)(auto ref const Q quantity, Rational r)
		if (isQVariant!Q)
	{ return quantity ^^ r.inverted; } 
	
	auto nthRoot(Q, I)(auto ref const Q quantity, I n)
		if (isQVariant!Q && isIntegral!I)
	{ return nthRoot(quantity, Rational(n)); } 
	
	/// ditto
	Q abs(Q)(auto ref const Q quantity)
		if (isQVariant!Q)
	{ return Q(std.math.fabs(quantity._value), quantity._dimensions); } 
}version(/+$DIDE_REGION Parsing+/all)
{
	/+
		+
		This module defines functions to parse units and quantities.
		
		Copyright: Copyright 2013-2018, Nicolas Sicard  
		Authors: Nicolas Sicard  
		License: $(LINK www.boost.org/LICENSE_1_0.txt, Boost License 1.0)  
		Source: $(LINK https://github.com/biozic/quantities)  
	+/ 
	//module quantities.parsing; 
	
	import std.conv : parse; 
	import std.exception : basicExceptionCtors, enforce; 
	import std.format : format; 
	import std.traits : isNumeric, isSomeString; 
	
	/+
		+
		Contains the symbols of the units and the prefixes that a parser can handle.
	+/
	struct SymbolList(N)
		if (isNumeric!N)
	{
		static assert(isNumeric!N, "Incompatible type: " ~ N.stringof); 
		
		package
		{
			QVariant!N[string] units; 
			N[string] prefixes; 
			size_t maxPrefixLength; 
		} 
		
		/// Adds (or replaces) a unit in the list
		auto addUnit(Q)(string symbol, Q unit)
				if (isQVariantOrQuantity!Q)
		{
			static if(isQVariant!Q)
			units[symbol] = unit; 
			else static if(isQuantity!Q) units[symbol] = unit.qVariant; 
			else static assert(false); 
			return this; 
		} 
		
		/// Adds (or replaces) a prefix in the list
		auto addPrefix(N)(string symbol, N factor)
				if (isNumeric!N)
		{
			prefixes[symbol] = factor; 
			if(symbol.length > maxPrefixLength)
			maxPrefixLength = symbol.length; 
			return this; 
		} 
	} 
	
	/+
		+
		A quantity parser.
		
		Params:
			N = The numeric type of the quantities.
			numberParser = a function that takes a reference to any kind of string and
				returns the parsed number.
	+/
	struct Parser(N, alias numberParser = (ref s) => parse!N(s))
		if (isNumeric!N)
	{
		/// A list of registered symbols for units and prefixes.
		SymbolList!N symbolList; 
		
		/+
			+
				Parses a QVariant from str.
		+/
		QVariant!N parse(S)(S str)
				if (isSomeString!S)
		{ return parseQuantityImpl!(N, numberParser)(str, symbolList); } 
	} 
	///
	unittest
	{
		//From http://en.wikipedia.org/wiki/List_of_humorous_units_of_measurement
		
		import std.conv : parse; 
		
		auto century = unit!real("T"); 
		alias LectureLength = typeof(century); 
		
		auto symbolList = SymbolList!real().addUnit("Cy", century).addPrefix("µ", 1e-6L); 
		alias numberParser = (ref s) => parse!real(s); 
		auto parser = Parser!(real, numberParser)(symbolList); 
		
		auto timing = 1e-6L * century; 
		assert(timing == parser.parse("1 µCy")); 
	} 
	
	/// Exception thrown when parsing encounters an unexpected token.
	class ParsingException : Exception
	{ mixin basicExceptionCtors; } 
	
	package(quantities): 
	
	QVariant!N parseQuantityImpl(N, alias numberParser, S)(S input, SymbolList!N symbolList)
		if (isSomeString!S)
	{
		import std.range.primitives : empty; 
		
		N value; 
		try
		value = numberParser(input); 
		catch(Exception) value = 1; 
		
		if(input.empty)
		return QVariant!N(value, Dimensions.init); 
		
		auto parser = QuantityParser!(N, S)(input, symbolList); 
		return value * parser.parsedQuantity(); 
	} 
	
	//A parser that can parse a text for a unit or a quantity
	struct QuantityParser(N, S)
		if (isNumeric!N && isSomeString!S)
	{
		import std.conv : to; 
		import std.exception : enforce; 
		import std.format : format; 
		import std.range.primitives : empty, front, popFront; 
		
		private
		{
			S input; 
			SymbolList!N symbolList; 
			Token[] tokens; 
		} 
		
		this(S input, SymbolList!N symbolList)
		{
			this.input = input; 
			this.symbolList = symbolList; 
			lex(input); 
		} 
		
		QVariant!N parsedQuantity()
		{ return parseCompoundUnit(); } 
		
		QVariant!N parseCompoundUnit(bool inParens = false)
		{
			QVariant!N ret = parseExponentUnit(); 
			if(tokens.empty || (inParens && tokens.front.type == Tok.rparen))
			return ret; 
			
			do
			{
				check(); 
				auto cur = tokens.front; 
				
				bool multiply = true; 
				if(cur.type == Tok.div)
				multiply = false; 
				
				if(cur.type == Tok.mul || cur.type == Tok.div)
				{
					advance(); 
					check(); 
					cur = tokens.front; 
				}
				
				QVariant!N rhs = parseExponentUnit(); 
				if(multiply)
				ret *= rhs; 
				else ret /= rhs; 
				
				if(tokens.empty || (inParens && tokens.front.type == Tok.rparen))
				break; 
				
				cur = tokens.front; 
			}
			while(!tokens.empty); 
			
			return ret; 
		} 
		
		QVariant!N parseExponentUnit()
		{
			QVariant!N ret = parseUnit(); 
			
			//If no exponent is found
			if(tokens.empty)
			return ret; 
			
			//The next token should be '^', an integer or a superior integer
			auto next = tokens.front; 
			if(next.type != Tok.exp && next.type != Tok.integer && next.type != Tok.supinteger)
			return ret; 
			
			//Skip the '^' if present, and expect an integer
			if(next.type == Tok.exp)
			advance(Tok.integer); 
			
			Rational r = parseRationalOrInteger(); 
			return ret ^^ r; 
		} 
		
		Rational parseRationalOrInteger()
		{
			int num = parseInteger(); 
			int den = 1; 
			if(tokens.length && tokens.front.type == Tok.div)
			{
				advance(); 
				den = parseInteger(); 
			}
			return Rational(num, den); 
		} 
		
		int parseInteger()
		{
			check(Tok.integer, Tok.supinteger); 
			int n = tokens.front.integer; 
			if(tokens.length)
			advance(); 
			return n; 
		} 
		
		QVariant!N parseUnit()
		{
			if(!tokens.length)
			return QVariant!N(1, Dimensions.init); 
			
			if(tokens.front.type == Tok.lparen)
			{
				advance(); 
				auto ret = parseCompoundUnit(true); 
				check(Tok.rparen); 
				advance(); 
				return ret; 
			}
			else return parsePrefixUnit(); 
		} 
		
		QVariant!N parsePrefixUnit()
		{
			check(Tok.symbol); 
			auto str = input[tokens.front.begin .. tokens.front.end].to!string; 
			if(tokens.length)
			advance(); 
			
			//Try a standalone unit symbol (no prefix)
			auto uptr = str in symbolList.units; 
			if(uptr)
			return *uptr; 
			
			//Try with prefixes, the longest prefix first
			N* factor; 
			for(size_t i = symbolList.maxPrefixLength; i > 0; i--)
			{
				if(str.length >= i)
				{
					string prefix = str[0 .. i].to!string; 
					factor = prefix in symbolList.prefixes; 
					if(factor)
					{
						string unit = str[i .. $].to!string; 
						enforce!ParsingException(
							unit.length,
							"Expecting a unit after the prefix " ~ prefix
						); 
						uptr = unit in symbolList.units; 
						if(uptr)
						return *factor * *uptr; 
					}
				}
			}
			
			throw new ParsingException("Unknown unit symbol: '%s'".format(str)); 
		} 
		
		enum Tok
		{
			none,
			symbol,
			mul,
			div,
			exp,
			integer,
			supinteger,
			rparen,
			lparen
		} 
		
		struct Token
		{
			Tok type; 
			size_t begin; 
			size_t end; 
			int integer = int.max; 
		} 
		
		void lex(S input) @safe
		{
			import std.array : appender; 
			import std.conv : parse; 
			import std.exception : enforce; 
			import std.utf : codeLength; 
			
			enum State
			{
				none,
				symbol,
				integer,
				supinteger
			} 
			
			auto tokapp = appender(tokens); 
			size_t i, j; 
			State state = State.none; 
			auto intapp = appender!string; 
			
			void pushToken(Tok type)
			{
				tokapp.put(Token(type, i, j)); 
				i = j; 
				state = State.none; 
			} 
			
			void pushInteger(Tok type)
			{
				int n; 
				auto slice = intapp.data; 
				try
				{
					n = parse!int(slice); 
					assert(slice.empty); 
				}
				catch(Exception) throw new ParsingException("Unexpected integer format: %s".format(slice)); 
				
				tokapp.put(Token(type, i, j, n)); 
				i = j; 
				state = State.none; 
				intapp = appender!string; 
			} 
			
			void push()
			{
				if(state == State.symbol)
				pushToken(Tok.symbol); 
				else if(state == State.integer) pushInteger(Tok.integer); 
				else if(state == State.supinteger) pushInteger(Tok.supinteger); 
			} 
			
			
			foreach(dchar cur; input)
			{
				auto len = cur.codeLength!char; 
				switch(cur)
				{
					case ' ': 
					case '\t': 
					case '\u00A0': 
					case '\u2000': .. case '\u200A': 
					case '\u202F': 
					case '\u205F': 
						push(); 
						j += len; 
						i = j; 
						break; 
					
					case '(': 
						push(); 
						j += len; 
						pushToken(Tok.lparen); 
						break; 
					case ')': 
						push(); 
						j += len; 
						pushToken(Tok.rparen); 
						break; 
					
					case '*': //Asterisk
					case '.': //Dot
					case '\u00B7': //Middle dot (·)         
					case '\u00D7': //Multiplication sign (×)
					case '\u2219': //Bullet operator (∙)    
					case '\u22C5': //Dot operator (⋅)       
					case '\u2022': //Bullet (•)             
					
					case '\u2715': //Multiplication X (✕)   
						push(); 
						j += len; 
						pushToken(Tok.mul); 
						break; 
					
					case '/': //Slash
					case '\u00F7': //Division sign (÷)
					case '\u2215': //Division slash (∕)
						push(); 
						j += len; 
						pushToken(Tok.div); 
						break; 
					
					case '^': 
						push(); 
						j += len; 
						pushToken(Tok.exp); 
						break; 
					
					case '-': //Hyphen
					case '\u2212': //Minus sign (−)
					case '\u2012': //Figure dash (‒)
					case '\u2013': //En dash (–)
						intapp.put('-'); 
						goto PushIntChar; 
					case '+': //Plus sign
						intapp.put('+'); 
						goto PushIntChar; 
					case '0': .. case '9': 
						intapp.put(cur); 
					PushIntChar: 
						if(state != State.integer)
					push(); 
						state = State.integer; 
						j += len; 
						break; 
					
					case '⁰': 
						intapp.put('0'); 
						goto PushSupIntChar; 
					case '¹': 
						intapp.put('1'); 
						goto PushSupIntChar; 
					case '²': 
						intapp.put('2'); 
						goto PushSupIntChar; 
					case '³': 
						intapp.put('3'); 
						goto PushSupIntChar; 
					case '⁴': 
						intapp.put('4'); 
						goto PushSupIntChar; 
					case '⁵': 
						intapp.put('5'); 
						goto PushSupIntChar; 
					case '⁶': 
						intapp.put('6'); 
						goto PushSupIntChar; 
					case '⁷': 
						intapp.put('7'); 
						goto PushSupIntChar; 
					case '⁸': 
						intapp.put('8'); 
						goto PushSupIntChar; 
					case '⁹': 
						intapp.put('9'); 
						goto PushSupIntChar; 
					case '⁻': 
						intapp.put('-'); 
						goto PushSupIntChar; 
					case '⁺': 
						intapp.put('+'); 
					PushSupIntChar: 
						if(state != State.supinteger)
					push(); 
						state = State.supinteger; 
						j += len; 
						break; 
					
					default: 
						if(state == State.integer || state == State.supinteger)
					push(); 
						state = State.symbol; 
						j += len; 
						break; 
				}
			}
			push(); 
			tokens = tokapp.data; 
		} 
		void advance(Types...)(Types types)
		{
			enforce!ParsingException(!tokens.empty, "Unexpected end of input"); 
			tokens.popFront(); 
			
			static if(Types.length)
			check(types); 
		} 
		
		void check()
		{ enforce!ParsingException(tokens.length, "Unexpected end of input"); } 
		
		void check(Tok tok)
		{
			check(); 
			enforce!ParsingException(
				tokens[0].type == tok,
								format(
					"Found '%s' while expecting %s", input[tokens[0].begin .. tokens[0].end],
										tok
				)
			); 
		} 
		
		void check(Tok tok1, Tok tok2)
		{
			check(); 
			enforce!ParsingException(
				tokens[0].type == tok1 || tokens[0].type == tok2,
								format(
					"Found '%s' while expecting %s or %s",
										input[tokens[0].begin .. tokens[0].end], tok1, tok2
				)
			); 
		} 
		
	} 
	//Tests
	
		@("Generic parsing") unittest
	{
		import std.exception : assertThrown; 
		
		auto meter = unit!double("L"); 
		auto kilogram = unit!double("M"); 
		auto second = unit!double("T"); 
		auto one = meter / meter; 
		auto unknown = one; 
		
		auto siSL = SymbolList!double().addUnit("m", meter).addUnit("kg", kilogram)
			.addUnit("s", second).addPrefix("c", 0.01L).addPrefix("m", 0.001L); 
		
		bool checkParse(S, Q)(S input, Q quantity)
		{
			import std.conv : parse; 
			
			return parseQuantityImpl!(double, (ref s) => parse!double(s))(input, siSL) == quantity; 
		} 
		
		assert(checkParse("1    m    ", meter)); 
		assert(checkParse("1m", meter)); 
		assert(checkParse("1 mm", 0.001 * meter)); 
		assert(checkParse("1 m2", meter * meter)); 
		assert(checkParse("1 m^-1", 1 / meter)); 
		assert(checkParse("1 m-1", 1 / meter)); 
		assert(checkParse("1 m^1/1", meter)); 
		assert(checkParse("1 m^-1/1", 1 / meter)); 
		assert(checkParse("1 m²", meter * meter)); 
		assert(checkParse("1 m⁺²", meter * meter)); 
		assert(checkParse("1 m⁻¹", 1 / meter)); 
		assert(checkParse("1 (m)", meter)); 
		assert(checkParse("1 (m^-1)", 1 / meter)); 
		assert(checkParse("1 ((m)^-1)^-1", meter)); 
		assert(checkParse("1 (s/(s/m))", meter)); 
		assert(checkParse("1 m*m", meter * meter)); 
		assert(checkParse("1 m m", meter * meter)); 
		assert(checkParse("1 m.m", meter * meter)); 
		assert(checkParse("1 m⋅m", meter * meter)); 
		assert(checkParse("1 m×m", meter * meter)); 
		assert(checkParse("1 m/m", meter / meter)); 
		assert(checkParse("1 m÷m", meter / meter)); 
		assert(checkParse("1 m.s", second * meter)); 
		assert(checkParse("1 m s", second * meter)); 
		assert(checkParse("1 m²s", meter * meter * second)); 
		assert(checkParse("1 m*m/m", meter)); 
		assert(checkParse("0.8 m⁰", 0.8 * one)); 
		assert(checkParse("0.8", 0.8 * one)); 
		assert(checkParse("0.8 ", 0.8 * one)); 
		
		assertThrown!ParsingException(checkParse("1 c m", unknown)); 
		assertThrown!ParsingException(checkParse("1 c", unknown)); 
		assertThrown!ParsingException(checkParse("1 Qm", unknown)); 
		assertThrown!ParsingException(checkParse("1 m + m", unknown)); 
		assertThrown!ParsingException(checkParse("1 m/", unknown)); 
		assertThrown!ParsingException(checkParse("1 m^", unknown)); 
		assertThrown!ParsingException(checkParse("1 m^m", unknown)); 
		assertThrown!ParsingException(checkParse("1 m ) m", unknown)); 
		assertThrown!ParsingException(checkParse("1 m * m) m", unknown)); 
		assertThrown!ParsingException(checkParse("1 m^²", unknown)); 
		assertThrown!ParsingException(checkParse("1-⁺⁵", unknown)); 
	} 
}version(/+$DIDE_REGION SIDefinitions+/all)
{
	/+
		+
		This module only contains the template mixins that define
		SI units, prefixes and symbols for use at compile-time and/or
		at run-time.
		
		Copyright: Copyright 2013-2018, Nicolas Sicard
		Authors: Nicolas Sicard
		License: $(LINK www.boost.org/LICENSE_1_0.txt, Boost License 1.0)
		Source: $(LINK https://github.com/biozic/quantities)
	+/ 
	//module quantities.internal.si; 
		
	/+
		+
		Generates SI units, prefixes and several utility functions
		(parsing and formatting) usable at compile-time and/or at run-time.
	+/
	mixin template SIDefinitions(N)
	{
		import std.conv : parse; 
		import std.math : PI; 
		import std.traits : isNumeric, isSomeString; 
		
		static assert(isNumeric!N); 
		
		/// The dimensionless unit 1.
		enum one = unit!(N, "", 0); 
		
		/// Base SI units.
		enum meter = unit!(N, "L", 1); 
		alias metre = meter; /// ditto
		enum kilogram = unit!(N, "M", 2); /// ditto
		enum second = unit!(N, "T", 3); /// ditto
		enum ampere = unit!(N, "I", 4); /// ditto
		enum kelvin = unit!(N, "Θ", 5); /// ditto
		enum mole = unit!(N, "N", 6); /// ditto
		enum candela = unit!(N, "J", 7); /// ditto
		
		/// Derived SI units
		enum radian = meter / meter; //ditto
		enum steradian = square(meter) / square(meter); /// ditto
		enum hertz = 1 / second; /// ditto
		enum newton = kilogram * meter / square(second); /// ditto
		enum pascal = newton / square(meter); /// ditto
		enum joule = newton * meter; /// ditto
		enum watt = joule / second; /// ditto
		enum coulomb = second * ampere; /// ditto
		enum volt = watt / ampere; /// ditto
		enum farad = coulomb / volt; /// ditto
		enum ohm = volt / ampere; /// ditto
		enum siemens = ampere / volt; /// ditto
		enum weber = volt * second; /// ditto
		enum tesla = weber / square(meter); /// ditto
		enum henry = weber / ampere; /// ditto
		/+
			enum celsius = kelvin ; /// ditto
			230916 realhet: 	It's wrong, because no way to implement 
				the 273.15 shift in this system.
		+/
		enum lumen = candela / steradian; /// ditto
		enum lux = lumen / square(meter); /// ditto
		enum becquerel = 1 / second; /// ditto
		enum gray = joule / kilogram; /// ditto
		enum sievert = joule / kilogram; /// ditto
		enum katal = mole / second; /// ditto
		
		/// Units compatible with the SI
		enum gram = 1e-3 * kilogram; 
		enum minute = 60 * second; /// ditto
		enum hour = 60 * minute; /// ditto
		enum day = 24 * hour; /// ditto
		enum bpm = 1 / minute; /// ditto
		enum degreeOfAngle = PI / 180 * radian; /// ditto
		enum minuteOfAngle = degreeOfAngle / 60; /// ditto
		enum secondOfAngle = minuteOfAngle / 60; /// ditto
		enum hectare = 1e4 * square(meter); /// ditto
		enum liter = 1e-3 * cubic(meter); /// ditto
		alias litre = liter; /// ditto
		enum ton = 1e3 * kilogram; /// ditto
		enum electronVolt = 1.60217653e-19 * joule; /// ditto
		enum dalton = 1.66053886e-27 * kilogram; /// ditto
		
		/// SI prefixes.
		alias yotta = prefix!1e24; 
		alias zetta = prefix!1e21; /// ditto
		alias exa = prefix!1e18; /// ditto
		alias peta = prefix!1e15; /// ditto
		alias tera = prefix!1e12; /// ditto
		alias giga = prefix!1e9; /// ditto
		alias mega = prefix!1e6; /// ditto
		alias kilo = prefix!1e3; /// ditto
		alias hecto = prefix!1e2; /// ditto
		alias deca = prefix!1e1; /// ditto
		alias deci = prefix!1e-1; /// ditto
		alias centi = prefix!1e-2; /// ditto
		alias milli = prefix!1e-3; /// ditto
		alias micro = prefix!1e-6; /// ditto
		alias nano = prefix!1e-9; /// ditto
		alias pico = prefix!1e-12; /// ditto
		alias femto = prefix!1e-15; /// ditto
		alias atto = prefix!1e-18; /// ditto
		alias zepto = prefix!1e-21; /// ditto
		alias yocto = prefix!1e-24; /// ditto
		
		/// Predefined quantity type templates for SI quantities
		alias Dimensionless = typeof(one); 
		alias Length = typeof(meter); 
		alias Mass = typeof(kilogram); /// ditto
		alias Time = typeof(second); /// ditto
		alias ElectricCurrent = typeof(ampere); /// ditto
		alias Temperature = typeof(kelvin); /// ditto
		alias AmountOfSubstance = typeof(mole); /// ditto
		alias LuminousIntensity = typeof(candela); /// ditto
		
		alias Area = typeof(square(meter)); /// ditto
		alias Surface = Area; 
		alias Volume = typeof(cubic(meter)); /// ditto
		alias Speed = typeof(meter / second); /// ditto
		alias Acceleration = typeof(meter / square(second)); /// ditto
		alias MassDensity = typeof(kilogram / cubic(meter)); /// ditto
		alias CurrentDensity = typeof(ampere / square(meter)); /// ditto
		alias MagneticFieldStrength = typeof(ampere / meter); /// ditto
		alias Concentration = typeof(mole / cubic(meter)); /// ditto
		alias MolarConcentration = Concentration; /// ditto
		alias MassicConcentration = typeof(kilogram / cubic(meter)); /// ditto
		alias Luminance = typeof(candela / square(meter)); /// ditto
		alias RefractiveIndex = typeof(kilogram); /// ditto
		
		alias Angle = typeof(radian); /// ditto
		alias SolidAngle = typeof(steradian); /// ditto
		alias Frequency = typeof(hertz); /// ditto
		alias Force = typeof(newton); /// ditto
		alias Pressure = typeof(pascal); /// ditto
		alias Energy = typeof(joule); /// ditto
		alias Work = Energy; /// ditto
		alias Heat = Energy; /// ditto
		alias Power = typeof(watt); /// ditto
		alias ElectricCharge = typeof(coulomb); /// ditto
		alias ElectricPotential = typeof(volt); /// ditto
		alias Capacitance = typeof(farad); /// ditto
		alias ElectricResistance = typeof(ohm); /// ditto
		alias ElectricConductance = typeof(siemens); /// ditto
		alias MagneticFlux = typeof(weber); /// ditto
		alias MagneticFluxDensity = typeof(tesla); /// ditto
		alias Inductance = typeof(henry); /// ditto
		alias LuminousFlux = typeof(lumen); /// ditto
		alias Illuminance = typeof(lux); /// ditto
		/+
			alias CelsiusTemperature = typeof(celsius); /// ditto
			230916 realhet: 	Removed because the 273.15 shift is not implemented.
				Until that use kelvin for everything.
		+/
		alias Radioactivity = typeof(becquerel); /// ditto
		alias AbsorbedDose = typeof(gray); /// ditto
		alias DoseEquivalent = typeof(sievert); /// ditto
		alias CatalyticActivity = typeof(katal); /// ditto
		
		/// A list of common SI symbols and prefixes
		//dfmt off
		enum siSymbolList = SymbolList!N()
			.addUnit("m", meter)
			.addUnit("kg", kilogram)
			.addUnit("s", second)
			.addUnit("A", ampere)
			.addUnit("K", kelvin)
			.addUnit("mol", mole)
			.addUnit("cd", candela)
			.addUnit("rad", radian)
			.addUnit("°", degreeOfAngle) /+230916 realhet+/
			.addUnit("sr", steradian)
			.addUnit("Hz", hertz)
			.addUnit("bpm", bpm)
			.addUnit("N", newton)
			.addUnit("Pa", pascal)
			.addUnit("J", joule)
			.addUnit("W", watt)
			.addUnit("C", coulomb)
			.addUnit("V", volt)
			.addUnit("F", farad)
			.addUnit("Ω", ohm)
			.addUnit("S", siemens)
			.addUnit("Wb", weber)
			.addUnit("T", tesla)
			.addUnit("H", henry)
			.addUnit("lm", lumen)
			.addUnit("lx", lux)
			.addUnit("Bq", becquerel)
			.addUnit("Gy", gray)
			.addUnit("Sv", sievert)
			.addUnit("kat", katal)
			.addUnit("g", gram)
			.addUnit("min", minute)
			.addUnit("h", hour)
			.addUnit("d", day)
			.addUnit("l", liter)
			.addUnit("L", liter)
			.addUnit("t", ton)
			.addUnit("eV", electronVolt)
			.addUnit("Da", dalton)
		
			.addPrefix("Y", 1e24)
			.addPrefix("Z", 1e21)
			.addPrefix("E", 1e18)
			.addPrefix("P", 1e15)
			.addPrefix("T", 1e12)
			.addPrefix("G", 1e9)
			.addPrefix("M", 1e6)
			.addPrefix("k", 1e3)
			.addPrefix("h", 1e2)
			.addPrefix("da", 1e1)
			.addPrefix("d", 1e-1)
			.addPrefix("c", 1e-2)
			.addPrefix("m", 1e-3)
			.addPrefix("µ", 1e-6)
			.addPrefix("n", 1e-9)
			.addPrefix("p", 1e-12)
			.addPrefix("f", 1e-15)
			.addPrefix("a", 1e-18)
			.addPrefix("z", 1e-21)
			.addPrefix("y", 1e-24); 
		//dfmt on
		
		/// A list of common SI symbols and prefixes
		static
		{
			SymbolList!N siSymbols; 
			Parser!(N, (ref s) => parse!N(s)) siParser; 
		} 
		static this()
		{
			siSymbols = siSymbolList; 
			siParser = typeof(siParser)(siSymbols); 
		} 
		
		/+
			+
				Parses a statically-typed Quantity from a string at run time.
			
				Throws a DimensionException if the parsed quantity doesn't have the same
				dimensions as Q.
			
				Params:
					Q = the type of the returned quantity.
					str = the string to parse.
		+/
		Q parseSI(Q, S)(S str)
				if (isQuantity!Q && isSomeString!S)
		{ return Q(siParser.parse(str)); } 
		///
		unittest
		{
			alias Time = typeof(second); 
			Time t = parseSI!Time("90 min"); 
			assert(t == 90 * minute); 
			t = parseSI!Time("h"); 
			assert(t == 1 * hour); 
		} 
		
		/+
			+
				Creates a Quantity from a string at compile-time.
		+/
		template si(string str)
		{
			enum ctSIParser = Parser!(N, (ref s) => parse!N(s))(siSymbolList); 
			enum qty = ctSIParser.parse(str); 
			enum si = Quantity!(N, qty.dimensions())(qty); 
		} 
		///
		unittest
		{
			alias Time = typeof(second); 
			enum t = si!"90 min"; 
			assert(is(typeof(t) == Time)); 
			assert(si!"h" == 60 * 60 * second); 
		} 
		
		/+
			+
				Parses a string for a quantity at run time.
			
				Params:
					str = the string to parse.
		+/
		QVariant!N parseSI(S)(S str)
				if (isSomeString!S)
		{
			if(__ctfe)
			{
				import std.conv : parse; 
				
				auto ctSIParser = Parser!(N, (ref s) => parse!N(s))(siSymbolList); 
				return ctSIParser.parse(str); 
			}
			return siParser.parse(str); 
		} 
		///
		unittest
		{
			auto t = parseSI("90 min"); 
			assert(t == 90 * minute); 
			t = parseSI("h"); 
			assert(t == 1 * hour); 
			
			auto v = parseSI("2"); 
			assert(v == (2 * meter) / meter); 
		} 
		
		/+
			+
				A struct able to format a SI quantity.
		+/
		struct SIFormatter(S)
				if (isSomeString!S)
		{
			import std.range : ElementEncodingType; 
			
			alias Char = ElementEncodingType!S; 
			
			private
			{
				S fmt; 
				QVariant!double unit; 
			} 
			
			/+
				+
					Creates the formatter.
				
					Params:
					format = The format string. Must start with a format specification
										 for the value of the quantity (a numeric type), that must be 
										 followed by the symbol of a SI unit.
			+/
			this(S format)
			{
				import std.format : FormatSpec; 
				import std.array : appender; 
				
				fmt = format; 
				auto spec = FormatSpec!Char(format); 
				auto app = appender!S; 
				spec.writeUpToNextSpec(app); 
				unit = parseSI(spec.trailing); 
			} 
			
			void write(Writer, Q)(auto ref Writer writer, auto ref Q quantity) const 
				if (isQVariantOrQuantity!Q)
			{
				import std.format : formattedWrite; 
				
				formattedWrite(writer, fmt, quantity.value(unit)); 
			} 
		} 
		
		/+
			+
				Formats a SI quantity according to a format string known at run-time.
			
				Params:
					format = The format string. Must start with a format specification
							 for the value of the quantity (a numeric type), that must be 
							 followed by the symbol of a SI unit.
					quantity = The quantity that must be formatted.
		+/
		S siFormat(S, Q)(S format, Q quantity)
				if (isSomeString!S && isQVariantOrQuantity!Q)
		{
			import std.array : appender; 
			
			auto formatter = SIFormatter!S(format); 
			auto app = appender!S; 
			formatter.write(app, quantity); 
			return app.data; 
		} 
		///
		unittest
		{
			QVariant!double speed = 12.5 * kilo(meter) / hour; 
			assert("%.2f m/s".siFormat(speed) == "3.47 m/s"); 
		} 
		
		/+
			+
				Formats a SI quantity according to a format string known at compile-time.
			
				Params:
					format = The format string. Must start with a format specification
							 for the value of the quantity (a numeric type), that must be 
							 followed by the symbol of a SI unit.
					quantity = The quantity that must be formatted.
		+/
		auto siFormat(alias format, Q)(Q quantity)
				if (isSomeString!(typeof(format)) && isQVariantOrQuantity!Q)
		{ return siFormat(format, quantity); } 
		///
		unittest
		{
			enum speed = 12.5 * kilo(meter) / hour; 
			assert(siFormat!"%.2f m/s"(speed) == "3.47 m/s"); 
		} 
	} 
}