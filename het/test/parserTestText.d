//ModuleDeclaration

deprecated("just a test") module test.modul;

/*comment1*//*comment2*/
/+/+comment3
end+/
+/ //hello
//last

// AttributeSpecifier
  extern extern(C) extern(C++) extern(C++, name.space) extern(D) extern(Windows) extern(System) extern(Objective-C)
  public private protected export package package(pkg.mod)
  static override final abstract align(4) deprecated ("because") pragma(id, args)
    synchronized immutable const shared inout __gshared
  auto scope ref return ref auto ref
  @property @nogc nothrow pure @safe @trusted @system @disable //debil comment
  {
    //all the possible attributes

    //here's some more
    @hello @(1,2,3) align/*pragma comment*/ pragma(4) : //attribute specifier
    @attr2 { /*body*/ @another(params): /*last comment*/ } //attributed block
  }
  @/*help*/("unittest UDA")
  {
  }


// Declaration.ImportDeclaration

  import fmt = std.format, std.stdio : a = func1, c = func2,
         f3, f4 //idiotic // comment before ";"
  ;
  static import m1 = het.utils, std.stdio : a = func1,
    c = func2, f3, f4;
  public import std.exception;

// Declaration.AliasDeclaration

  alias myint = int,
        mybytearray = byte[];
  alias int(string p) Fun;   //old alias format without =

// AliasThis

  alias blabla this;

// Declaration.EnumDeclaration

  enum F;
  enum A = 3;
  enum B
  {
      A = A // error, circular reference
  }
  enum C
  {
      A = B,  // A = 4
      B = D,  // B = 4
      C = 3,  // C = 3
      D       // D = 4
  }
  enum E : C
  {
      E1 = C.D,
      E2      // error, C.D is C.max
  }
  enum : D { Ax, Bx }

  enum X=5, Y=10, Z="hello"//comment
  ;

// Constructor/Destructor

  static shared this(int param1, int param2=5) const immutable inout return shared nothrow pure @property{ statement1; statement2; }
  this(); //just a forward declaration
  static ~this() if(blabla) { /*destructor*/ }
  this(templateParam)() const if(constraint) if(constraint2) in{ blabla; } out(val){ blabla; } do{ /+constructor template+/ }

// postblit / allocator / deallocator (all deprecated)

  deprecated this(this){ a = a.dup; /*postblit*/ }
  deprecated new(){}
  deprecated delete(){}

  @uda unittest{ hello; }
