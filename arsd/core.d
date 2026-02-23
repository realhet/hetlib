module het.arsd.core; 

//Author: Adam D. Ruppe
//Link: https://github.com/adamdruppe/arsd
//Note: Here I collect a small subset of [arsd] modules which is maintained to be compatible with [hetlib].

import core.attribute : standalone; 
import core.time : MonoTime, Duration, hnsecs; 
import std.string; 


//OpenD has a new, optional synchronization.
static if(!__traits(hasMember, object, "SynchronizableObject"))
{
	alias SynchronizableObject = Object; 
	mixin template EnableSynchronization()
	{} 
}else
{
	alias SynchronizableObject = object.SynchronizableObject; 
	alias EnableSynchronization = Object.EnableSynchronization; 
}

/+
	======================
	ERROR HANDLING HELPERS
	======================
+/

/+
	 +
		arsd code shouldn't be using Exception. Really, I don't think any code should be - instead, construct an 
		appropriate object with structured information.
	
		If you want to catch someone else's Exception, use `catch(object.Exception e)`.
+/
//package deprecated struct Exception {}


/+
	+
		Base class representing my exceptions. You should almost never work with this directly, but you might catch 
		it as a generic thing. Catch it before generic `object.Exception` or `object.Throwable` in any catch chains.
	
	
		$(H3 General guidelines for exceptions)
	
		The purpose of an exception is to cancel a task that has proven to be impossible and give the programmer 
		enough information to use at a higher level to decide what to do about it.
	
		Cancelling a task is accomplished with the `throw` keyword. The transmission of information to a higher level 
		is done by the language runtime. The decision point is marked by the `catch` keyword. The part missing - 
		the job of the `Exception` class you construct and throw - is to gather the information that will be useful 
		at a later decision point.
	
		It is thus important that you gather as much useful information as possible and keep it in a way that the 
		code catching the exception can still interpret it when constructing an exception. Other concerns are secondary 
		to this to this primary goal.
	
		With this in mind, here's some guidelines for exception handling in arsd code.
	
		$(H4 Allocations and lifetimes)
	
		Don't get clever with exception allocations. You don't know what the catcher is going to do with an 
		exception and you don't want the error handling scheme to introduce its own tricky bugs. Remember, an 
		exception object's first job is to deliver useful information up the call chain in a way this code can use it. 
		You don't know what this code is or what it is going to do.
	
		Keep your memory management schemes simple and let the garbage collector do its job.
	
		$(LIST
			* All thrown exceptions should be allocated with the `new` keyword.
	
			* Members inside the exception should be value types or have infinite lifetime (that is, be GC managed).
	
			* While this document is concerned with throwing, you might want to add additional information to an 
			in-flight exception, and this is done by catching, so you need to know how that works too, and there 
			is a global compiler switch that can change things, so even inside arsd we can't completely avoid its 
			implications.
	
			DIP1008's presence complicates things a bit on the catch side - if you catch an exception and return it 
			from a function, remember to `ex.refcount = ex.refcount + 1;` so you don't introduce more use-after-free 
			woes for those unfortunate souls.
		)
	
		$(H4 Error strings)
	
		Strings can deliver useful information to people reading the message, but are often suboptimal for delivering 
		useful information to other chunks of code. Remember, an exception's first job is to be caught by another 
		block of code. Printing to users is a last resort; even if you want a user-readable error message, an exception 
		is not the ideal way to deliver one since it is constructed in the guts of a failed task, without the higher level 
		context of what the user was actually trying to do. User error messages ought to be made from information in 
		the exception, combined with higher level knowledge. This is best done in a `catch` block, not a `throw` statement.
	
		As such, I recommend that you:
	
		$(LIST
			* Don't concatenate error strings at the throw site. Instead, pass the data you would have used to build the 
			string as actual data to the constructor. This lets catchers see the original data without having to try to 
			extract it from a string. For unique data, you will likely need a unique exception type. More on this in the 
			next section.
	
			* Don't construct error strings in a constructor either, for the same reason. Pass the useful data up the call 
			chain, as exception members, to the maximum extent possible. Exception: if you are passed some data with 
			a temporary lifetime that is important enough to pass up the chain. You may `.idup` or `to!string` to preserve 
			as much data as you can before it is lost, but still store it in a separate member of the Exception subclass object.
	
			* $(I Do) construct strings out of public members in [getAdditionalPrintableInformation]. When this is called, 
			the user has requested as much relevant information as reasonable in string format. Still, avoid concatenation 
			- it lets you pass as many key/value pairs as you like to the caller. They can concatenate as needed. However, 
			note the words "public members" - everything you do in `getAdditionalPrintableInformation` ought to also be 
			possible for code that caught your exception via your public methods and properties.
		)
	
		$(H4 Subclasses)
	
		Any exception with unique data types should be a unique class. Whenever practical, this should be one you write 
		and document at the top-level of a module. But I know we get lazy - me too - and this is why in standard D 
		we'd often fall back to `throw new Exception("some string " ~ some info)`. To help resist these urges, I offer some 
		helper functions to use instead that better achieve the key goal of exceptions - passing structured data up a call 
		chain - while still being convenient to write.
	
		See: [ArsdException], [Win32Enforce]
	
+/
class ArsdExceptionBase : object.Exception
{
	/+
		+
				Don't call this except from other exceptions; this is essentially an abstract class.
		
				Params:
					operation = the specific operation that failed, throwing the exception
	+/
	package this(string operation, string file = __FILE__, size_t line = __LINE__, Throwable next = null)
	{ super(operation, file, line, next); } 
	
	/+
		+
				The toString method will print out several components:
		
				$(LIST
					* The file, line, static message, and object class name from the constructor. You can access these 
					independently with the members `file`, `line`, `msg`, and [printableExceptionName].
					* The generic category codes stored with this exception
					* Additional members stored with the exception child classes (e.g. platform error codes, associated 
					function arguments)
					* The stack trace associated with the exception. You can access these lines independently with 
					`foreach` over the `info` member.
				)
		
				This is meant to be read by the developer, not end users. You should wrap your user-relevant tasks in 
				a try/catch block and construct more appropriate error messages from context available there, using the 
				individual properties of the exception to add richness.
	+/
	final override void toString(scope void delegate(in char[]) sink) const
	{
		// class name and info from constructor
		sink(printableExceptionName); 
		sink("@"); 
		sink(file); 
		sink("("); 
		char[16] buffer; 
		sink(intToString(line, buffer[])); 
		sink("): "); 
		sink(message); 
		
		getAdditionalPrintableInformation((string name, in char[] value) {
			sink("\n"); 
			sink(name); 
			sink(": "); 
			sink(value); 
		}); 
		
		// full stack trace, if available
		if(info)
		{
			sink("\n----------------\n"); 
			foreach(str; info)
			{
				sink(str); 
				sink("\n"); 
			}
		}
	} 
	/// ditto
	final override string toString()
	{
		string s; 
		toString((in char[] chunk) { s ~= chunk; }); 
		return s; 
	} 
	
	/+
		+
				Users might like to see additional information with the exception. API consumers should pull this out 
				of properties on your child class, but the parent class might not be able to deal with the arbitrary 
				types at runtime the children can introduce, so bringing them all down to strings simplifies that.
		
				Overrides should always call `super.getAdditionalPrintableInformation(sink);` before adding additional 
				information by calling the sink with other arguments afterward.
		
				You should spare no expense in preparing this information - translate error codes, build rich strings, 
				whatever it takes - to make the information here useful to the reader.
	+/
	void getAdditionalPrintableInformation(scope void delegate(string name, in char[] value) sink) const
	{} 
	
	/+
		+
				This is the name of the exception class, suitable for printing. This should be static data (e.g. a string 
				literal). Override it in subclasses.
	+/
	string printableExceptionName() const
	{ return typeid(this).name; } 
	
	/// deliberately hiding `Throwable.msg`. Use [message] and [toString] instead.
	@disable final void msg()
	{} 
	
	override const(char)[] message() const
	{ return super.msg; } 
} 

/+
	=================
	STDIO REPLACEMENT
	=================
+/

private void appendToBuffer(ref char[] buffer, ref int pos, scope const(char)[] what)
{
	auto required = pos + what.length; 
	if(buffer.length < required)
	buffer.length = required; 
	buffer[pos .. pos + what.length] = what[]; 
	pos += what.length; 
} 

private void appendToBuffer(ref char[] buffer, ref int pos, long what)
{ appendToBuffer(buffer, pos, what, IntToStringArgs.init); } 
private void appendToBuffer(ref char[] buffer, ref int pos, long what, IntToStringArgs args)
{
	if(buffer.length < pos + 32)
	buffer.length = pos + 32; 
	auto sliced = intToString(what, buffer[pos .. $], args); 
	pos += sliced.length; 
} 

private void appendToBuffer(ref char[] buffer, ref int pos, double what)
{ appendToBuffer(buffer, pos, what, FloatToStringArgs.init); } 
private void appendToBuffer(ref char[] buffer, ref int pos, double what, FloatToStringArgs args)
{
	if(buffer.length < pos + 42)
	buffer.length = pos + 42; 
	auto sliced = floatToString(what, buffer[pos .. $], args); 
	pos += sliced.length; 
} 

private void writeIndividualArg(T)(ref char[] buffer, ref int pos, bool quoteStrings, T arg)
{
	static if(is(typeof(arg) == ValueWithFormattingArgs!V, V))
	{ appendToBuffer(buffer, pos, arg.value, arg.args); }else static if(is(typeof(arg) Base == enum))
	{
		appendToBuffer(buffer, pos, typeof(arg).stringof); 
		appendToBuffer(buffer, pos, "."); 
		appendToBuffer(buffer, pos, enumNameForValue(arg)); 
		appendToBuffer(buffer, pos, "("); 
		appendToBuffer(buffer, pos, cast(Base) arg); 
		appendToBuffer(buffer, pos, ")"); 
	}else static if(is(typeof(arg) : const char[]))
	{
		if(quoteStrings)
		{
			appendToBuffer(buffer, pos, "\""); 
			appendToBuffer(buffer, pos, arg); // FIXME: escape quote and backslash in there?
			appendToBuffer(buffer, pos, "\""); 
		}else
		{ appendToBuffer(buffer, pos, arg); }
	}else static if(is(typeof(arg) : arsd_stringz))
	{ appendToBuffer(buffer, pos, arg.borrow); }else static if(is(typeof(arg) : long))
	{ appendToBuffer(buffer, pos, arg); }else static if(is(typeof(arg) : double))
	{ appendToBuffer(buffer, pos, arg); }else static if(is(typeof(arg.toString()) : const char[]))
	{ appendToBuffer(buffer, pos, arg.toString()); }else static if(is(typeof(arg) A == struct))
	{
		appendToBuffer(buffer, pos, A.stringof); 
		appendToBuffer(buffer, pos, "("); 
		foreach(idx, item; arg.tupleof)
		{
			if(idx)
			appendToBuffer(buffer, pos, ", "); 
			appendToBuffer(buffer, pos, __traits(identifier, arg.tupleof[idx])); 
			appendToBuffer(buffer, pos, ": "); 
			writeIndividualArg(buffer, pos, true, item); 
		}
		appendToBuffer(buffer, pos, ")"); 
	}else static if(is(typeof(arg) == E[], E))
	{
		appendToBuffer(buffer, pos, "["); 
		foreach(idx, item; arg)
		{
			if(idx)
			appendToBuffer(buffer, pos, ", "); 
			writeIndividualArg(buffer, pos, true, item); 
		}
		appendToBuffer(buffer, pos, "]"); 
	}else static if(is(typeof(arg) == delegate))
	{
		appendToBuffer(buffer, pos, "<" ~ typeof(arg).stringof ~ "> "); 
		appendToBuffer(buffer, pos, cast(size_t) arg.ptr, IntToStringArgs().withRadix(16).withPadding(12, '0')); 
		appendToBuffer(buffer, pos, ", "); 
		appendToBuffer(buffer, pos, cast(size_t) arg.funcptr, IntToStringArgs().withRadix(16).withPadding(12, '0')); 
	}else static if(is(typeof(arg) : const void*))
	{
		appendToBuffer(buffer, pos, "<" ~ typeof(arg).stringof ~ "> "); 
		appendToBuffer(buffer, pos, cast(size_t) arg, IntToStringArgs().withRadix(16).withPadding(12, '0')); 
	}else
	{ appendToBuffer(buffer, pos, "<" ~ typeof(arg).stringof ~ ">"); }
} 

/+
	Purposes:
		* debugging
		* writing
		* converting single value to string?
+/
private string writeGuts(T...)(
	char[] buffer, string prefix, string suffix, string argSeparator, 
	bool printInterpolatedCode, bool quoteStrings, string function(scope char[] result) writer, T t
)
{
	int pos; 
	
	if(prefix.length)
	appendToBuffer(buffer, pos, prefix); 
	
	foreach(i, arg; t)
	{
		static if(i)
		if(argSeparator.length)
		appendToBuffer(buffer, pos, argSeparator); 
		
		static if(is(typeof(arg) == InterpolatedExpression!code, string code))
		{
			if(printInterpolatedCode)
			{
				appendToBuffer(buffer, pos, code); 
				appendToBuffer(buffer, pos, " = "); 
			}
		}else
		{ writeIndividualArg(buffer, pos, quoteStrings, arg); }
	}
	
	if(suffix.length)
	appendToBuffer(buffer, pos, suffix); 
	
	return writer(buffer[0 .. pos]); 
} 

private string makeString(scope char[] buffer) @safe
{ return buffer.idup; } 

/+
	+
		Shortcut for converting some types to string without invoking Phobos (but it may as a last resort).
	
		History:
			Moved from color.d to core.d in March 2023 (dub v11.0).
+/
string toStringInternal(T)(T t)
{
	char[256] bufferBacking; 
	return writeGuts(bufferBacking[], null, null, null, false, false, &makeString, t); 
	/+
		char[64] buffer;
		static if(is(typeof(t.toString) : string))
			return t.toString();
		else static if(is(T : string))
			return t;
		else static if(is(T == enum)) {
			switch(t) {
				foreach(memberName; __traits(allMembers, T)) {
					case __traits(getMember, T, memberName):
						return memberName;
				}
				default:
					return "<unknown>";
			}
		} else static if(is(T : long)) {
			return intToString(t, buffer[]).idup;
		} else static if(is(T : const E[], E)) {
			string ret = "[";
			foreach(idx, e; t) {
				if(idx)
					ret ~= ", ";
				ret ~= toStringInternal(e);
			}
			ret ~= "]";
			return ret;
		} else static if(is(T : double)) {
			import core.stdc.stdio;
			auto ret = snprintf(buffer.ptr, buffer.length, "%f", t);
			return buffer[0 .. ret].idup;
		} else {
			static assert(0, T.stringof ~ " makes compile too slow");
			// import std.conv; return to!string(t);
		}
	+/
} 

/+
	+
		This is a generic exception with attached arguments. It is used when I had to throw something but didn't want to write a new class.
	
		You can catch an ArsdException to get its passed arguments out.
	
		You can pass either a base class or a string as `Type`.
	
		See the examples for how to use it.
+/
template ArsdException(alias Type, DataTuple...)
{
	static if(DataTuple.length)
	alias Parent = ArsdException!(Type, DataTuple[0 .. $-1]); 
	else	alias Parent = ArsdExceptionBase; 
	
	class ArsdException : Parent
	{
		DataTuple data; 
		
		this(DataTuple data, string file = __FILE__, size_t line = __LINE__)
		{
			this.data = data; 
			static if(is(Parent == ArsdExceptionBase))
			super(null, file, line); 
			else	super(data[0 .. $-1], file, line); 
		} 
		
		static opCall(R...)(R r, string file = __FILE__, size_t line = __LINE__)
		{ return new ArsdException!(Type, DataTuple, R)(r, file, line); } 
		
		override string printableExceptionName() const
		{
			static if(DataTuple.length)
			enum str = "ArsdException!(" ~ Type.stringof ~ ", " ~ DataTuple.stringof[1 .. $-1] ~ ")"; 
			else	enum str = "ArsdException!" ~ Type.stringof; 
			return str; 
		} 
		
		override void getAdditionalPrintableInformation(scope void delegate(string name, in char[] value) sink) const
		{
			ArsdExceptionBase.getAdditionalPrintableInformation(sink); 
			
			foreach(idx, datum; data)
			{
				enum int lol = cast(int) idx; 
				enum key = "[" ~ lol.stringof ~ "] " ~ DataTuple[idx].stringof; 
				sink(key, toStringInternal(datum)); 
			}
		} 
	} 
} 

// enum stringz : const(char)* { init = null }

/+
	+
		A wrapper around a `const(char)*` to indicate that it is a zero-terminated C string.
+/
struct arsd_stringz
{
	private const(char)* raw; 
	
	/+
		+
				Wraps the given pointer in the struct. Note that it retains a copy of the pointer.
	+/
	this(const(char)* raw)
	{ this.raw = raw; } 
	
	/+
		+
				Returns the original raw pointer back out.
	+/
	const(char)* ptr() const
	{ return raw; } 
	
	/+
		+
				Borrows a slice of the pointer up to (but not including) the zero terminator.
	+/
	const(char)[] borrow() const @system
	{
		if(raw is null)
		return null; 
		
		const(char)* p = raw; 
		int length; 
		while(*p++)
		length++; 
		
		return raw[0 .. length]; 
	} 
} 

/+
	/+
		+
			A runtime tagged union, aka a sumtype.
		
			History:
				Added February 15, 2025
	+/
	struct Union(T...) {
		private uint contains_;
		private union {
			private T payload;
		}
	
		static foreach(index, type; T)
		@implicit public this(type t) {
			contains_ = index;
			payload[index] = t;
		}
	
		bool contains(Part)() const {
			static assert(indexFor!Part != -1);
			return contains_ == indexFor!Part;
		}
	
		inout(Part) get(Part)() inout {
			if(!contains!Part) {
				throw new ArsdException!"Dynamic type mismatch"(indexFor!Part, contains_);
			}
			return payload[indexFor!Part];
		}
	
		private int indexFor(Part)() {
			foreach(idx, thing; T)
				static if(is(T == Part))
					return idx;
			return -1;
		}
	}
+/

/+
	DateTime
		year: 16 bits (-32k to +32k)
		month: 4 bits
		day: 5 bits
	
		hour: 5 bits
		minute: 6 bits
		second: 6 bits
	
		total: 25 bits + 17 bits = 42 bits
	
		fractional seconds: 10 bits (about milliseconds)
	
		accuracy flags: date_valid | time_valid = 2 bits
	
		54 bits used, 8 bits remain. reserve 1 for signed.
	
		tz offset in 15 minute intervals = 96 slots... can fit in 7 remaining bits...
	
		would need 11 bits for minute-precise dt offset but meh. would need 10 bits for referring 
		back to tz database (and that's iffy to key, better to use a string tbh)
+/

/+
	+
		A packed date/time/datetime representation added for use with LimitedVariant.
	
		You should probably not use this much directly, it is mostly an internal storage representation.
+/
struct PackedDateTime
{
	private ulong packedData; 
	
	string toString() const
	{
		char[64] buffer; 
		size_t pos; 
		
		if(hasDate)
		{
			pos += intToString(year, buffer[pos .. $], IntToStringArgs().withPadding(4)).length; 
			buffer[pos++] = '-'; 
			pos += intToString(month, buffer[pos .. $], IntToStringArgs().withPadding(2)).length; 
			buffer[pos++] = '-'; 
			pos += intToString(day, buffer[pos .. $], IntToStringArgs().withPadding(2)).length; 
		}
		
		if(hasTime)
		{
			if(pos)
			buffer[pos++] = 'T'; 
			
			pos += intToString(hours, buffer[pos .. $], IntToStringArgs().withPadding(2)).length; 
			buffer[pos++] = ':'; 
			pos += intToString(minutes, buffer[pos .. $], IntToStringArgs().withPadding(2)).length; 
			buffer[pos++] = ':'; 
			pos += intToString(seconds, buffer[pos .. $], IntToStringArgs().withPadding(2)).length; 
			if(fractionalSeconds)
			{
				buffer[pos++] = '.'; 
				pos += intToString(fractionalSeconds, buffer[pos .. $], IntToStringArgs().withPadding(4)).length; 
			}
		}
		
		return buffer[0 .. pos].idup; 
	} 
	
	/+
		+
				Construction helpers
	+/
	static PackedDateTime withDate(int year, int month, int day)
	{
		PackedDateTime p; 
		p.setDate(year, month, day); 
		return p; 
	} 
	/// ditto
	static PackedDateTime withTime(int hours, int minutes, int seconds, int fractionalSeconds = 0)
	{
		PackedDateTime p; 
		p.setTime(hours, minutes, seconds, fractionalSeconds); 
		return p; 
	} 
	/// ditto
	static PackedDateTime withDateAndTime(int year, int month, int day = 1, int hours = 0, int minutes = 0, int seconds = 0, int fractionalSeconds = 0)
	{
		PackedDateTime p; 
		p.setDate(year, month, day); 
		p.setTime(hours, minutes, seconds, fractionalSeconds); 
		return p; 
	} 
	/// ditto
	static PackedDateTime lastDayOfMonth(int year, int month)
	{
		PackedDateTime p; 
		p.setDate(year, month, daysInMonth(year, month)); 
		return p; 
	} 
	/++ +/
	static bool isLeapYear(int year)
	{
		return 
			(year % 4) == 0
			&&
			(
			((year % 100) != 0)
			||
			((year % 400) == 0)
		)
		; 
	} 
	unittest
	{
		assert(isLeapYear(2024)); 
		assert(!isLeapYear(2023)); 
		assert(!isLeapYear(2025)); 
		assert(isLeapYear(2000)); 
		assert(!isLeapYear(1900)); 
	} 
	static immutable ubyte[12] daysInMonthTable = [
		31, 28, 31, 30, 31, 30,
		31, 31, 30, 31, 30, 31
	]; 
	
	static int daysInMonth(int year, int month)
	{
		assert(month >= 1 &&  month <= 12); 
		if(month == 2)
		return isLeapYear(year) ? 29 : 28; 
		else	return daysInMonthTable[month - 1]; 
	} 
	unittest
	{
		assert(daysInMonth(2025, 12) == 31); 
		assert(daysInMonth(2025, 2) == 28); 
		assert(daysInMonth(2024, 2) == 29); 
	} 
	static int daysInYear(int year)
	{ return isLeapYear(year) ? 366 : 365; } 
	
	/+
		+
				Sets the whole date and time portions in one function call.
		
				History:
					Added December 13, 2025
	+/
	void setTime(int hours, int minutes, int seconds, int fractionalSeconds = 0)
	{
		this.hours = hours; 
		this.minutes = minutes; 
		this.seconds = seconds; 
		this.fractionalSeconds = fractionalSeconds; 
		this.hasTime = true; 
	} 
	
	/// ditto
	void setDate(int year, int month, int day)
	{
		this.year = year; 
		this.month = month; 
		this.day = day; 
		this.hasDate = true; 
	} 
	
	/// ditto
	void clearTime()
	{
		this.hours = 0; 
		this.minutes = 0; 
		this.seconds = 0; 
		this.fractionalSeconds = 0; 
		this.hasTime = false; 
	} 
	
	/// ditto
	void clearDate()
	{
		this.year = 0; 
		this.month = 0; 
		this.day = 0; 
		this.hasDate = false; 
	} 
	
	/+++/
	int fractionalSeconds() const
	{ return getFromMask(00, 10); } 
	/// ditto
	void fractionalSeconds(int a)
	{     setWithMask(a, 00, 10); } 
	
	/// ditto
	int  seconds() const         
	{ return getFromMask(10,  6); } 
	/// ditto
	void seconds(int a)          
	{     setWithMask(a, 10,  6); } 
	/// ditto
	int  minutes() const         
	{ return getFromMask(16,  6); } 
	/// ditto
	void minutes(int a)          
	{     setWithMask(a, 16,  6); } 
	/// ditto
	int  hours() const           
	{ return getFromMask(22,  5); } 
	/// ditto
	void hours(int a)            
	{     setWithMask(a, 22,  5); } 
	
	/// ditto
	int  day() const             
	{ return getFromMask(27,  5); } 
	/// ditto
	void day(int a)              
	{     setWithMask(a, 27,  5); } 
	/// ditto
	int  month() const           
	{ return getFromMask(32,  4); } 
	/// ditto
	void month(int a)            
	{     setWithMask(a, 32,  4); } 
	/// ditto
	int  year() const            
	{ return getFromMask(36, 16); } 
	/// ditto
	void year(int a)             
	{     setWithMask(a, 36, 16); } 
	
	/// ditto
	bool hasTime() const         
	{ return cast(bool) getFromMask(52,  1); } 
	/// ditto
	void hasTime(bool a)         
	{     setWithMask(a, 52,  1); } 
	/// ditto
	bool hasDate() const         
	{ return cast(bool) getFromMask(53,  1); } 
	/// ditto
	void hasDate(bool a)         
	{     setWithMask(a, 53,  1); } 
	
	private void setWithMask(int a, int bitOffset, int bitCount)
	{
		auto mask = (1UL << bitCount) - 1; 
		
		packedData &= ~(mask << bitOffset); 
		packedData |= (a & mask) << bitOffset; 
	} 
	
	private int getFromMask(int bitOffset, int bitCount) const
	{
		ulong packedData = this.packedData; 
		packedData >>= bitOffset; 
		
		ulong mask = (1UL << bitCount) - 1; 
		
		return cast(int) (packedData & mask); 
	} 
	
	/+
		+
				Returns the day of week for the date portion.
		
				Throws AssertError if used when [hasDate] is false.
		
				Returns:
					0 == Sunday, 6 == Saturday
		
				History:
					Added December 13, 2025
	+/
	int dayOfWeek() const
	{
		assert(hasDate); 
		auto y = year; 
		auto m = month; 
		if(m == 1 || m == 2)
		{
			y--; 
			m += 12; 
		}
		return (
			day +
			(13 * (m+1) / 5) +
			(y % 100) +
			(y % 100) / 4 +
			(y / 100) / 4 -
			2 * (y / 100)
		) % 7; 
	} 
	
	long opCmp(PackedDateTime rhs) const
	{
		if(this.hasDate == rhs.hasDate && this.hasTime == rhs.hasTime)
		return cast(long) this.packedData - cast(long) rhs.packedData; 
		if(this.hasDate && rhs.hasDate)
		{
			PackedDateTime c1 = this; 
			c1.clearTime(); 
			rhs.clearTime(); 
			return c1.opCmp(rhs); 
		}
		// if one of them is just time, no date, we can't compare
		// but as long as there's two date components we can compare them.
		assert(0, "invalid comparison, one is a date, other is a time"); 
	} 
} 

unittest
{
	PackedDateTime dt; 
	dt.hours = 14; 
	dt.minutes = 30; 
	dt.seconds = 25; 
	dt.hasTime = true; 
	
	assert(dt.toString() == "14:30:25", dt.toString()); 
	
	dt.hasTime = false; 
	dt.year = 2024; 
	dt.month = 5; 
	dt.day = 31; 
	dt.hasDate = true; 
	
	assert(dt.toString() == "2024-05-31", dt.toString()); 
	dt.hasTime = true; 
	assert(dt.toString() == "2024-05-31T14:30:25", dt.toString()); 
	
	assert(dt.dayOfWeek == 6); 
} 

unittest
{
	PackedDateTime a; 
	PackedDateTime b; 
	a.setDate(2025, 01, 01); 
	b.setDate(2024, 12, 31); 
	assert(a > b); 
} 

/+
	+
		A `PackedInterval` can be thought of as the difference between [PackedDateTime]s, similarly to how a [Duration] is a difference between 
		[MonoTime]s or [SimplifiedUtcTimestamp]s.
	
	
		The key speciality is in how it treats months and days separately. Months are not a consistent length, and neither are days when you 
		consider daylight saving time. This thing assumes that if you add those, the month/day number will always increase, just the exact details 
		since then might be truncated. (E.g., January 31st + 1 month = February 28/29 depending on leap year). If you multiply, the parts are 
		done individually, so January 31st + 1 month * 2 = March 31st, despite + 1 month truncating to the shorter day in February.
	
		Internally, this stores months and days as 16 bit signed `short`s each, then the milliseconds is stored as a 32 bit signed `int`. It applies 
		by first adding months, truncating days as needed, then adding days, then adding milliseconds.
	
		If you iterate over intervals, be careful not to allow month truncation to change the result. (Jan 31st + 1 month) + 1 month will not 
		actually give the same result as Jan 31st + 2 months. You want to add to the interval, then apply to the original date again, not to 
		some accumulated date.
	
		History:
			Added December 13, 2025
+/
struct PackedInterval
{
	private ulong packedData; 
	
	this(int months, int days = 0, int milliseconds = 0)
	{
		this.months = months; 
		this.days = days; 
		this.milliseconds = milliseconds; 
	} 
	
	/+
		+
				Getters and setters for the components
	+/
	short months() const
	{ return cast(short)((packedData >> 48) & 0xffff); } 
	
	/// ditto
	short days() const
	{ return cast(short)((packedData >> 32) & 0xffff); } 
	
	/// ditto
	int milliseconds() const
	{ return cast(int)(packedData & 0xffff_ffff); } 
	
	/// ditto
	void months(int v)
	{
		short d = cast(short) v; 
		ulong s = d; 
		packedData &= ~(0xffffUL << 48); 
		packedData |= s << 48; 
	} 
	
	/// ditto
	void days(int v)
	{
		short d = cast(short) v; 
		ulong s = d; 
		packedData &= ~(0xffffUL << 32); 
		packedData |= s << 32; 
	} 
	
	/// ditto
	void milliseconds(int v)
	{
		packedData &= 0xffffffff_00000000UL; 
		packedData |= cast(ulong) v; 
	} 
	
	PackedInterval opBinary(string op : "*")(int iterations) const
	{ return PackedInterval(this.months * iterations, this.days * iterations, this.milliseconds * iterations); } 
} 

unittest
{
	PackedInterval pi = PackedInterval(1); 
	assert(pi.months == 1); 
	assert(pi.days == 0); 
	assert(pi.milliseconds == 0); 
} 

/+
	+
		Basically a Phobos SysTime but standing alone as a simple 64 bit integer (but wrapped) for 
		compatibility with LimitedVariant.
+/
struct SimplifiedUtcTimestamp
{
	long timestamp; 
	
	this(long hnsecTimestamp)
	{ this.timestamp = hnsecTimestamp; } 
	
	// this(PackedDateTime pdt)
	
	string toString() const
	{
		import core.stdc.time; 
		char[128] buffer; 
		auto ut = toUnixTime(); 
		tm* t = gmtime(&ut); 
		if(t is null)
		return "null time"; 
		
		return buffer[0 .. strftime(buffer.ptr, buffer.length, "%Y-%m-%dT%H:%M:%SZ", t)].idup; 
	} 
	
	version(Windows)
	alias time_t = int; 
	
	static SimplifiedUtcTimestamp fromUnixTime(time_t t)
	{ return SimplifiedUtcTimestamp(621_355_968_000_000_000L + t * 1_000_000_000L / 100); } 
	
	/+
		+
				History:
					Added November 22, 2025
	+/
	static SimplifiedUtcTimestamp now()
	{
		import core.stdc.time; 
		return SimplifiedUtcTimestamp.fromUnixTime(time(null)); 
	} 
	
	time_t toUnixTime() const
	{
		return cast(time_t) ((timestamp - 621_355_968_000_000_000L) / 1_000_000_0); // hnsec = 7 digits
	} 
	
	long stdTime() const
	{ return timestamp; } 
	
	SimplifiedUtcTimestamp opBinary(string op : "+")(Duration d) const
	{ return SimplifiedUtcTimestamp(this.timestamp + d.total!"hnsecs"); } 
} 

unittest
{
	SimplifiedUtcTimestamp sut = SimplifiedUtcTimestamp.fromUnixTime(86_400); 
	assert(sut.toString() == "1970-01-02T00:00:00Z"); 
} 

/+
	+
		A little builder pattern helper that is meant for use by other library code.
	
		History:
			Added October 31, 2025
+/
struct AdHocBuiltStruct(string tag, string[] names = [], T...)
{
	static assert(names.length == T.length); 
	
	T values; 
	
	auto opDispatch(string name, Arg)(Arg value)
	{ return AdHocBuiltStruct!(tag, names ~ name, T, Arg)(values, value); } 
} 

unittest
{
	AdHocBuiltStruct!"tag"()
		.id(5)
		.name("five")
	; 
} 

/+
	+
		Represents a generic raw element to be embedded in an interpolated sequence.
	
		Use with caution, its exact meaning is dependent on the specific function being called, but it generally 
		is meant to disable encoding protections the function normally provides.
	
		History:
			Added October 31, 2025
+/
struct iraw
{
	string s; 
	
	@system this(string s)
	{ this.s = s; } 
} 

/+
	+
		Counts the number of bits set to `1` in a value, using intrinsics when available.
	
		History:
			Added December 15, 2025
+/
int countOfBitsSet(ulong v)
{
	version(LDC)
	{
		import ldc.intrinsics; 
		return cast(int) llvm_ctpop(v); 
	}else
	{
		// kerninghan's algorithm
		int count = 0; 
		while(v)
		{
			v &= v - 1; 
			count++; 
		}
		return count; 
	}
} 

unittest
{
	assert(countOfBitsSet(0) == 0); 
	assert(countOfBitsSet(ulong.max) == 64); 
	assert(countOfBitsSet(0x0f0f) == 8); 
	assert(countOfBitsSet(0x0f0f2) == 9); 
} 

/+
	+
		A limited variant to hold just a few types. It is made for the use of packing a small amount of extra 
		data into error messages and some transit across virtual function boundaries.
	
		Note that empty strings and null values are indistinguishable unless you explicitly slice the end of some 
		other existing string!
+/
/+
	ALL OF THESE ARE SUBJECT TO CHANGE
	
	* if length and ptr are both 0, it is null
	* if ptr == 1, length is an integer
	* if ptr == 2, length is an unsigned integer (suggest printing in hex)
	* if ptr == 3, length is a combination of flags (suggest printing in binary)
	* if ptr == 4, length is a unix permission thing (suggest printing in octal)
	* if ptr == 5, length is a double float
	* if ptr == 6, length is an Object ref (reinterpret casted to void*)
	
	* if ptr == 7, length is a ticks count (from MonoTime)
	* if ptr == 8, length is a utc timestamp (hnsecs)
	* if ptr == 9, length is a duration (signed hnsecs)
	* if ptr == 10, length is a date or date time (bit packed, see flags in data to determine if it is a Date, Time, 
	or DateTime)
	* if ptr == 11, length is a decimal
	
	* if ptr == 12, length is a bool (redundant to int?)
	13, 14 reserved. maybe char?
	
	* if ptr == 15, length must be 0. this holds an empty, non-null, SSO string.
	* if ptr >= 16 && < 24, length is reinterpret-casted a small string of length of (ptr & 0x7) + 1
	
	* if length == size_t.max, ptr is interpreted as a stringz
	* if ptr >= 1024, it is a non-null D string or byte array. It is a string if the length high bit is clear, a byte 
	array if it is set. the length is what is left after you mask that out.
	
	All other ptr values are reserved for future expansion.
	
	It basically can store:
		null
			type details = must be 0
		int (actually long)
			type details = formatting hints
		float (actually double)
			type details = formatting hints
		dchar (actually enum - upper half is the type tag, lower half is the member tag)
			type details = ???
		decimal
			type details = precision specifier
		object
			type details = ???
		timestamp
			type details: ticks, utc timestamp, relative duration
	
		sso
		stringz
	
		or it is bytes or a string; a normal D array (just bytes has a high bit set on length).
	
	But there are subtypes of some of those; ints can just have formatting hints attached.
		Could reserve 0-7 as low level type flag (null, int, float, pointer, object)
		15-24 still can be the sso thing
	
		We have 10 bits really.
	
		00000 00000
		????? OOLLL
	
		The ????? are type details bits.
	
	64 bits decmial to 4 points of precision needs... 14 bits for the small part (so max of 4 digits)? so 50 bits 
	for the big part (max of about 1 quadrillion)
		...actually it can just be a dollars * 10000 + cents * 100.
	
+/

/// ditto
struct IntToStringArgs
{
	private
	{
		ubyte padTo; 
		char padWith; 
		ubyte radix; 
		char ten; 
		ubyte groupSize; 
		char separator; 
	} 
	
	IntToStringArgs withPadding(int padTo, char padWith = '0')
	{
		IntToStringArgs args = this; 
		args.padTo = cast(ubyte) padTo; 
		args.padWith = padWith; 
		return args; 
	} 
	
	IntToStringArgs withRadix(int radix, char ten = 'a')
	{
		IntToStringArgs args = this; 
		args.radix = cast(ubyte) radix; 
		args.ten = ten; 
		return args; 
	} 
	
	IntToStringArgs withGroupSeparator(int groupSize, char separator = '_')
	{
		IntToStringArgs args = this; 
		args.groupSize = cast(ubyte) groupSize; 
		args.separator = separator; 
		return args; 
	} 
} 

struct FloatToStringArgs
{
	private
	{
		// whole number component
		ubyte padTo; 
		char padWith; 
		ubyte groupSize; 
		char separator; 
		
		// for the fractional component
		ubyte minimumPrecision =  0; /+
			 will always show at least this many digits 
			after the decimal (if it is 0 there may be no decimal)
		+/
		ubyte maximumPrecision = 32; // will round to this many after the decimal
		
		bool useScientificNotation; /+
			 if this is true, note the whole number component will 
			always be exactly one digit, so the pad stuff applies to 
			the exponent only and it assumes pad with zero's to 
			two digits
		+/
	} 
	
	FloatToStringArgs withPadding(int padTo, char padWith = '0')
	{
		FloatToStringArgs args = this; 
		args.padTo = cast(ubyte) padTo; 
		args.padWith = padWith; 
		return args; 
	} 
	
	FloatToStringArgs withGroupSeparator(int groupSize, char separator = '_')
	{
		FloatToStringArgs args = this; 
		args.groupSize = cast(ubyte) groupSize; 
		args.separator = separator; 
		return args; 
	} 
	
	FloatToStringArgs withPrecision(int minDigits, int maxDigits = 0)
	{
		FloatToStringArgs args = this; 
		args.minimumPrecision = cast(ubyte) minDigits; 
		if(maxDigits < minDigits)
		maxDigits = minDigits; 
		args.maximumPrecision = cast(ubyte) maxDigits; 
		return args; 
	} 
	
	FloatToStringArgs withScientificNotation(bool enabled)
	{
		FloatToStringArgs args = this; 
		args.useScientificNotation = enabled; 
		return args; 
	} 
} 

/+
	+
		An int printing function that doesn't need to import Phobos. Can do some of the things std.conv.to and std.format.format do.
	
		The buffer must be sized to hold the converted number. 32 chars is enough for most anything.
	
		Returns: the slice of `buffer` containing the converted number.
+/
char[] intToString(long value, char[] buffer, IntToStringArgs args = IntToStringArgs.init)
{
	const int radix = args.radix ? args.radix : 10; 
	const int digitsPad = args.padTo; 
	const int groupSize = args.groupSize; 
	
	int pos; 
	
	bool needsOverflowFixup = false; 
	
	if(value == long.min)
	{
		// -long.min will overflow so we're gonna cheat
		value += 1; 
		needsOverflowFixup = true; 
	}
	
	if(value < 0)
	{
		buffer[pos++] = '-'; 
		value = -value; 
	}
	
	int start = pos; 
	int digitCount; 
	int groupCount; 
	
	void outputDigit(char c) {
		if(groupSize && groupCount == groupSize)
		{
			buffer[pos++] = args.separator; 
			groupCount = 0; 
		}
		
		buffer[pos++] = c; 
		groupCount++; 
		digitCount++; 
		
	}; 
	
	{
		do
		{
			auto remainder = value % radix; 
			value = value / radix; 
			if(needsOverflowFixup)
			{
				if(remainder + 1 == radix)
				{
					outputDigit('0'); 
					remainder = 0; 
					value += 1; 
				}else
				{ remainder += 1; }
				needsOverflowFixup = false; 
			}
			
			outputDigit(cast(char) (remainder < 10 ? (remainder + '0') : (remainder - 10 + args.ten))); 
		}
		while(value); 
	}
	if(digitsPad > 0)
	{
		while(digitCount < digitsPad)
		{
			if(groupSize && groupCount == groupSize)
			{
				buffer[pos++] = args.separator; 
				groupCount = 0; 
			}
			buffer[pos++] = args.padWith; 
			digitCount++; 
			groupCount++; 
		}
	}
	
	assert(pos >= 1); 
	assert(pos - start > 0); 
	
	auto reverseSlice = buffer[start .. pos]; 
	for(int i = 0; i < reverseSlice.length / 2; i++)
	{
		auto paired = cast(int) reverseSlice.length - i - 1; 
		char tmp = reverseSlice[i]; 
		reverseSlice[i] = reverseSlice[paired]; 
		reverseSlice[paired] = tmp; 
	}
	
	return buffer[0 .. pos]; 
} 




// the buffer should be at least 32 bytes long, maybe more with other args
char[] floatToString(double value, char[] buffer, FloatToStringArgs args = FloatToStringArgs.init)
{
	// actually doing this is pretty painful, so gonna pawn it off on the C lib
	import core.stdc.stdio; 
	// FIXME: what if there's a locale in place that changes the decimal point?
	auto ret = snprintf(buffer.ptr, buffer.length, args.useScientificNotation ? "%.*e" : "%.*f", args.maximumPrecision, value); 
	if(!args.useScientificNotation && (args.padTo || args.groupSize))
	{
		char[32] scratch = void; 
		auto idx = buffer[0 .. ret].indexOf("."); 
		
		int digitsOutput = 0; 
		int digitsGrouped = 0; 
		if(idx > 0)
		{
			// there is a whole number component
			int pos = cast(int) scratch.length; 
			
			auto splitPoint = idx; 
			
			while(idx)
			{
				if(args.groupSize && digitsGrouped == args.groupSize)
				{
					scratch[--pos] = args.separator; 
					digitsGrouped = 0; 
				}
				scratch[--pos] = buffer[--idx]; 
				
				digitsOutput++; 
				digitsGrouped++; 
			}
			
			if(args.padTo)
			while(digitsOutput < args.padTo)
			{
				if(args.groupSize && digitsGrouped == args.groupSize)
				{
					scratch[--pos] = args.separator; 
					digitsGrouped = 0; 
				}
				
				scratch[--pos] = args.padWith; 
				
				digitsOutput++; 
				digitsGrouped++; 
			}
			
			char[32] remainingBuffer; 
			remainingBuffer[0 .. ret - splitPoint]= buffer[splitPoint .. ret]; 
			
			buffer[0 .. scratch.length - pos] = scratch[pos .. $]; 
			buffer[scratch.length - pos .. scratch.length - pos + ret - splitPoint] = remainingBuffer[0 .. ret - splitPoint]; 
			
			ret = cast(int)(scratch.length - pos + ret - splitPoint); 
		}
	}
	
	// sprintf will always put zeroes on to the maximum precision, but if it is a bunch of trailing zeroes, we can trim them
	// if scientific notation, don't forget to bring the e back down though.
	int trailingZeroesStart = -1; 
	int dot = -1; 
	int trailingZeroesEnd; 
	bool inZone; 
	foreach(idx, ch; buffer[0 .. ret])
	{
		if(inZone)
		{
			if(ch == '0')
			{
				if(trailingZeroesStart == -1)
				{ trailingZeroesStart = cast(int) idx; }
			}else if(ch == 'e')
			{
				trailingZeroesEnd = cast(int) idx; 
				break; 
			}else
			{ trailingZeroesStart = -1; }
		}else
		{
			if(ch == '.')
			{
				inZone = true; 
				dot = cast(int) idx; 
			}
		}
	}
	if(trailingZeroesEnd == 0)
	trailingZeroesEnd = ret; 
	
		// 0.430000
		// end = $
		// dot = 1
		// start = 4
		// precision is thus 3-1 = 2
		// if min precision = 0
	if(dot != -1 && trailingZeroesStart > dot)
	{
		auto currentPrecision = trailingZeroesStart - dot - 1; 
		auto precWanted = (args.minimumPrecision > currentPrecision) ? args.minimumPrecision : currentPrecision; 
		auto sliceOffset = dot + precWanted + 1; 
		if(precWanted == 0)
		sliceOffset -= 1; // remove the dot
		char[] keep = buffer[trailingZeroesEnd .. ret]; 
		
		// slice copy doesn't allow overlapping and since it can, we need to memmove
		//buffer[sliceOffset .. sliceOffset + keep.length] = keep[];
		import core.stdc.string; 
		memmove(buffer[sliceOffset .. ret].ptr, keep.ptr, keep.length); 
		
		ret = cast(int) (sliceOffset + keep.length); 
	}
	/+
		if(minimumPrecision > 0) {
			auto idx = buffer[0 .. ret].indexOf(".");
			if(idx == -1) {
				buffer[ret++] = '.';
				idx = ret;
			}
		
			while(ret - idx < minimumPrecision)
				buffer[ret++] = '0';
		}
	+/
	return buffer[0 .. ret]; 
} 

struct LimitedVariant
{
	
	/+
		+
		
	+/
	enum Contains
	{
		null_,
		intDecimal,
		intHex,
		intBinary,
		intOctal,
		double_,
		object,
		
		monoTime,
		utcTimestamp,
		duration,
		dateTime,
		decimal,
		
		/+
			 FIXME interval like postgres? e.g. 30 days, 2 months. distinct from Duration, 
			which is a difference of monoTimes or utcTimestamps, interval is more like a 
			difference of PackedDateTime.
		+/
		// FIXME boolean? char? specializations of float for various precisions...
		
		// could do enums by way of a pointer but kinda iffy
		
		// maybe some kind of prefixed string too for stuff like xml and json or enums etc.
		
		// fyi can also use stringzs or length-prefixed string pointers
		emptySso,
		stringSso,
		stringz,
		string,
		bytes,
		
		invalid,
	} 
	
	/+
		+
				Each datum stored in the LimitedVariant has a tag associated with it.
		
				Each tag belongs to one or more data families.
	+/
	Contains contains() const
	{
		auto tag = cast(size_t) ptr; 
		if(ptr is null && length is null)
		return Contains.null_; 
		else
		switch(tag)
		{
			case 1: return Contains.intDecimal; 
			case 2: return Contains.intHex; 
			case 3: return Contains.intBinary; 
			case 4: return Contains.intOctal; 
			case 5: return Contains.double_; 
			case 6: return Contains.object; 
			
			case 7: return Contains.monoTime; 
			case 8: return Contains.utcTimestamp; 
			case 9: return Contains.duration; 
			case 10: return Contains.dateTime; 
			case 11: return Contains.decimal; 
			
			case 15: return length is null ? Contains.emptySso : Contains.invalid; 
			default: 
				if(tag >= 16 && tag < 24)
			{ return Contains.stringSso; }else if(tag >= 1024)
			{
				if(cast(size_t) length == size_t.max)
				return Contains.stringz; 
				else	return isHighBitSet ? Contains.bytes : Contains.string; 
			}else
			{ return isHighBitSet ? Contains.bytes : Contains.invalid; }
		}
		
	} 
	
	/// ditto
	bool containsNull() const
	{ return contains() == Contains.null_; } 
	
	/// ditto
	bool containsDecimal() const
	{ return contains() == Contains.decimal; } 
	
	/// ditto
	bool containsInt() const
	{
		with(Contains)
		switch(contains)
		{
			case intDecimal, intHex, intBinary, intOctal: 
				return true; 
			default: 
				return false; 
		}
	} 
	
	// all specializations of int...
	
	/// ditto
	bool containsMonoTime() const
	{ return contains() == Contains.monoTime; } 
	/// ditto
	bool containsUtcTimestamp() const
	{ return contains() == Contains.utcTimestamp; } 
	/// ditto
	bool containsDuration() const
	{ return contains() == Contains.duration; } 
	/// ditto
	bool containsDateTime() const
	{ return contains() == Contains.dateTime; } 
	
	// done int specializations
	
	/// ditto
	bool containsString() const
	{
		with(Contains)
		switch(contains)
		{
			case null_, emptySso, stringSso, string: 
			case stringz: 
				return true; 
			default: 
				return false; 
		}
	} 
	
	/// ditto
	bool containsDouble() const
	{
		with(Contains)
		switch(contains)
		{
			case double_: 
				return true; 
			default: 
				return false; 
		}
	} 
	
	/// ditto
	bool containsBytes() const
	{
		with(Contains)
		switch(contains)
		{
			case bytes, null_: 
				return true; 
			default: 
				return false; 
		}
	} 
	
	private const(void)* length; 
	private const(ubyte)* ptr; 
	
	private void Throw() const
	{ throw ArsdException!"LimitedVariant"(cast(size_t) length, cast(size_t) ptr); } 
	
	private bool isHighBitSet() const
	{ return (cast(size_t) length >> (size_t.sizeof * 8 - 1) & 0x1) != 0; } 
	
	/+
		+
				getString gets a reference to the string stored internally, which may be a temporary. 
				See [toString] to get a normal string representation or whatever is inside.
		
	+/
	const(char)[] getString() const return
	{
		with(Contains)
		switch(contains())
		{
			case null_: 
				return null; 
			case emptySso: 
				return (cast(const(char)*) ptr)[0 .. 0]; // zero length, non-null
			case stringSso: 
				auto len = ((cast(size_t) ptr) & 0x7) + 1; 
				return (cast(char*) &length)[0 .. len]; 
			case string: 
				return (cast(const(char)*) ptr)[0 .. cast(size_t) length]; 
			case stringz: 
				return arsd_stringz(cast(char*) ptr).borrow; 
			default: 
				Throw(); assert(0); 
		}
	} 
	
	/// ditto
	long getInt() const
	{
		if(containsInt)
		return cast(long) length; 
		else	Throw(); 
		assert(0); 
	} 
	
	/// ditto
	double getDouble() const
	{
		if(containsDouble)
		{
			floathack hack; 
			hack.e = cast(void*) length; // casting away const
			return hack.d; 
		}else
		Throw(); 
		assert(0); 
	} 
	
	/// ditto
	const(ubyte)[] getBytes() const
	{
		with(Contains)
		switch(contains())
		{
			case null_: 
				return null; 
			case bytes: 
				return ptr[0 .. (cast(size_t) length) & ((1UL << (size_t.sizeof * 8 - 1)) - 1)]; 
			default: 
				Throw(); assert(0); 
		}
	} 
	
	/// ditto
	Object getObject() const
	{
		with(Contains)
		switch(contains())
		{
			case null_: 
				return null; 
			case object: 
				return cast(Object) length; // FIXME const correctness sigh
			default: 
				Throw(); assert(0); 
		}
	} 
	
	/// ditto
	MonoTime getMonoTime() const
	{
		if(containsMonoTime)
		{
			MonoTime time; 
			__traits(getMember, time, "_ticks") = cast(long) length; 
			return time; 
		}else
		Throw(); 
		assert(0); 
	} 
	/// ditto
	SimplifiedUtcTimestamp getUtcTimestamp() const
	{
		if(containsUtcTimestamp)
		return SimplifiedUtcTimestamp(cast(long) length); 
		else	Throw(); 
		assert(0); 
	} 
	/// ditto
	Duration getDuration() const
	{
		if(containsDuration)
		return hnsecs(cast(long) length); 
		else	Throw(); 
		assert(0); 
	} 
	/// ditto
	PackedDateTime getDateTime() const
	{
		if(containsDateTime)
		return PackedDateTime(cast(long) length); 
		else	Throw(); 
		assert(0); 
	} 
	
	/// ditto
	DynamicDecimal getDecimal() const
	{
		if(containsDecimal)
		return DynamicDecimal(cast(long) length); 
		else	Throw(); 
		assert(0); 
	} 
	
	
	/+
		+
		
	+/
	string toString() const
	{
		
		string intHelper(string prefix, int radix)
		{
			char[128] buffer; 
			buffer[0 .. prefix.length] = prefix[]; 
			char[] toUse = buffer[prefix.length .. $]; 
			
			auto got = intToString(getInt(), toUse[], IntToStringArgs().withRadix(radix)); 
			
			return buffer[0 .. prefix.length + got.length].idup; 
		} 
		
		with(Contains)
		final switch(contains())
		{
			case null_: 
				return "<null>"; 
			case intDecimal: 
				return intHelper("", 10); 
			case intHex: 
				return intHelper("0x", 16); 
			case intBinary: 
				return intHelper("0b", 2); 
			case intOctal: 
				return intHelper("0o", 8); 
			case emptySso, stringSso, string, stringz: 
				return getString().idup; 
			case bytes: 
				auto b = getBytes(); 
			
				return "<bytes>"; // FIXME
			case object: 
				auto o = getObject(); 
				return o is null ? "null" : o.toString(); 
			case monoTime: 
				return getMonoTime.toString(); 
			case utcTimestamp: 
				return getUtcTimestamp().toString(); 
			case duration: 
				return getDuration().toString(); 
			case dateTime: 
				return getDateTime().toString(); 
			case decimal: 
				return getDecimal().toString(); 
			case double_: 
				auto d = getDouble(); 
			
				import core.stdc.stdio; 
				char[64] buffer; 
				auto count = snprintf(buffer.ptr, buffer.length, "%.17lf", d); 
				return buffer[0 .. count].idup; 
			case invalid: 
				return "<invalid>"; 
		}
	} 
	
	/+
		+
		Note for integral types that are not `int` and `long` (for example, `short` or `ubyte`), 
		you might want to explicitly convert them to `int`.
	+/
	this(string s)
	{
		ptr = cast(const(ubyte)*) s.ptr; 
		length = cast(void*) s.length; 
	} 
	
	/// ditto
	this(const(char)* stringz)
	{
		if(stringz !is null)
		{
			ptr = cast(const(ubyte)*) stringz; 
			length = cast(void*) size_t.max; 
		}else
		{
			ptr = null; 
			length = null; 
		}
	} 
	
	/// ditto
	this(const(ubyte)[] b)
	{
		ptr = cast(const(ubyte)*) b.ptr; 
		length = cast(void*) (b.length | (1UL << (size_t.sizeof * 8 - 1))); 
	} 
	
	/// ditto
	this(long l, int base = 10)
	{
		int tag; 
		switch(base)
		{
			case 10: tag = 1; break; 
			case 16: tag = 2; break; 
			case	 2: tag = 3; break; 
			case	 8: tag = 4; break; 
			default: assert(0, "You passed an invalid base to LimitedVariant"); 
		}
		ptr = cast(ubyte*) tag; 
		length = cast(void*) l; 
	} 
	
	/// ditto
	this(int i, int base = 10)
	{ this(cast(long) i, base); } 
	
	/// ditto
	this(bool i)
	{
		// FIXME?
		this(cast(long) i); 
	} 
	
	/// ditto
	this(double d)
	{
		// the reinterpret cast hack crashes dmd! omg
		ptr = cast(ubyte*) 5; 
		
		floathack h; 
		h.d = d; 
		
		this.length = h.e; 
	} 
	
	/// ditto
	this(Object o)
	{
		this.ptr = cast(ubyte*) 6; 
		this.length = cast(void*) o; 
	} 
	
	/// ditto
	this(MonoTime a)
	{
		this.ptr = cast(ubyte*) 7; 
		this.length = cast(void*) a.ticks; 
	} 
	
	/// ditto
	this(SimplifiedUtcTimestamp a)
	{
		this.ptr = cast(ubyte*) 8; 
		this.length = cast(void*) a.timestamp; 
	} 
	
	/// ditto
	this(Duration a)
	{
		this.ptr = cast(ubyte*) 9; 
		this.length = cast(void*) a.total!"hnsecs"; 
	} 
	
	/// ditto
	this(PackedDateTime a)
	{
		this.ptr = cast(ubyte*) 10; 
		this.length = cast(void*) a.packedData; 
	} 
	
	/// ditto
	this(DynamicDecimal a)
	{
		this.ptr = cast(ubyte*) 11; 
		this.length = cast(void*) a.storage; 
	} 
} 

unittest
{
	LimitedVariant v = LimitedVariant("foo"); 
	assert(v.containsString()); 
	assert(!v.containsInt()); 
	assert(v.getString() == "foo"); 
	
	LimitedVariant v2 = LimitedVariant(4); 
	assert(v2.containsInt()); 
	assert(!v2.containsString()); 
	assert(v2.getInt() == 4); 
	
	LimitedVariant v3 = LimitedVariant(cast(ubyte[]) [1, 2, 3]); 
	assert(v3.containsBytes()); 
	assert(!v3.containsString()); 
	assert(v3.getBytes() == [1, 2, 3]); 
} 

private union floathack
{
	// in 32 bit we'll use float instead since it at least fits in the void*
	static if(double.sizeof == (void*).sizeof)
	{ double d; }else
	{ float d; }
	void* e; 
} 

/+
	64 bit signed goes up to 9.22x10^18
	
	3 bit precision = 0-7
	60 bits remain for the value = 1.15x10^18.
	
	so you can use up to 10 digits decimal 7 digits.
	
	9,999,999,999.9999999
	
	math between decimals must always have the same precision on both sides.
	
	decimal and 32 bit int is always allowed assuming the int is a whole number.
	
	FIXME add this to LimitedVariant
+/
/+
	+
		A DynamicDecimal is a fixed-point object whose precision is dynamically typed.
	
	
		It packs everything into a 64 bit value. It uses one bit for sign, three bits
		for precision, then the rest of them for the value. This means the precision
		(that is, the number of digits after the decimal) can be from 0 to 7, and there
		can be a total of 18 digits.
	
		Numbers can be added and subtracted only if they have matching precision. They can
		be multiplied and divided only by whole numbers.
	
		History:
			Added December 12, 2025.
+/
struct DynamicDecimal
{
	private ulong storage; 
	
	private this(ulong storage)
	{ this.storage = storage; } 
	
	this(long value, int precision)
	{
		assert(precision >= 0 && precision <= 7); 
		bool isNeg = value < 0; 
		if(isNeg)
		value = -value; 
		assert((value & 0xf000_0000_0000_0000) == 0); 
		
		storage =
			(isNeg ? 0x8000_0000_0000_0000 : 0)
			|
			(cast(ulong) precision << 60)
			|
			(value)
		; 
	} 
	
	private bool isNegative()
	{ return (storage >> 63) ? true : false; } 
	
	/+++/
	int precision()
	{ return (storage >> 60) & 7; } 
	
	/+++/
	long value()
	{
		long omg = storage & 0x0fff_ffff_ffff_ffff; 
		if(isNegative)
		omg = -omg; 
		return omg; 
	} 
	
	/+
		+
				Some basic arithmetic operators are defined on this: +, -, *, and /, but only between
				numbers of the same precision. Note that division always returns the quotient and remainder
				together in one return and any overflowing operations will also throw.
	+/
	typeof(this) opBinary(string op)(typeof(this) rhs) if(op == "+" || op == "-")
	{
		assert(this.precision == rhs.precision); 
		return typeof(this)(mixin("this.value" ~ op ~ "rhs.value"), this.precision); 
	} 
	
	/// ditto
	typeof(this) opBinary(string op)(int rhs) if(op == "*")
	{
		// what if we overflow on the multiplication? FIXME
		return typeof(this)(this.value * rhs, this.precision); 
	} 
	
	/// ditto
	static struct DivisionResult
	{
		DynamicDecimal quotient; 
		DynamicDecimal remainder; 
	} 
	
	/// ditto
	DivisionResult opBinary(string op)(int rhs) if(op == "/")
	{ return DivisionResult(typeof(this)(this.value / rhs, this.precision), typeof(this)(this.value % rhs, this.precision)); } 
	
	/// ditto
	typeof(this) opUnary(string op : "-")()
	{ return typeof(this)(-this.value, this.precision); } 
	
	/// ditto
	long opCmp(typeof(this) rhs)
	{
		assert(this.precision == rhs.precision); 
		return this.value - rhs.value; 
	} 
	
	/+
		+
				Converts to a floating point type. There's potentially a loss of precision here.
	+/
	double toFloatingPoint()
	{
		long divisor = 1; 
		foreach(i; 0 .. this.precision)
		divisor *= 10; 
		return cast(double) this.value / divisor; 
	} 
	
	/+++/
	string toString(int minimumNumberOfDigitsLeftOfDecimal = 1) @system
	{
		char[64] buffer = void; 
		// FIXME: what about a group separator arg?
		IntToStringArgs args = IntToStringArgs().
			withPadding(minimumNumberOfDigitsLeftOfDecimal + this.precision); 
		auto got = intToString(this.value, buffer[], args); 
		assert(got.length >= this.precision); 
		int digitsLeftOfDecimal = cast(int) got.length - this.precision; 
		auto toShift = buffer[got.length - this.precision .. got.length]; 
		import core.stdc.string; 
		memmove(toShift.ptr + 1, toShift.ptr, toShift.length); 
		toShift[0] = '.'; 
		return buffer[0 .. got.length + 1].idup; 
	} 
} 

unittest
{
	DynamicDecimal a = DynamicDecimal(100, 2); 
	auto res = a / 3; 
	assert(res.quotient.value == 33); 
	assert(res.remainder.value == 1); 
	res = a / 2; 
	assert(res.quotient.value == 50); 
	assert(res.remainder.value == 0); 
	
	assert(res.quotient.toFloatingPoint == 0.50); 
	assert(res.quotient.toString() == "0.50"); 
	
	assert((a * 2).value == 200); 
	
	DynamicDecimal b = DynamicDecimal(1, 4); 
	assert(b.toFloatingPoint() == 0.0001); 
	assert(b.toString() == "0.0001"); 
	
	assert(a > (a / 2).quotient); 
} 