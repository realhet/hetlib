//@exe
//@import c:\d\libs
//@ldc
//@compile -m64 -mcpu=athlon64-sse3 -mattr=+ssse3
//@release
///@debug

import het.utils, het.stream, het.geometry;

void main(){ application.runConsole({ test; }); }

class MyClass{
  int a;
}

struct DataStruct{
  enum MyEnum:ubyte { Enum0, Enum1, Enum5=5 }
  @STORED:
  int intValue = 42;
  @(STORED){
    MyClass class0;
    MyClass class1;
    ulong ulongVal = 0xFFFF_FFFF_FFFF_FFFF;
    @HEX uint uintVal = 0x12345678;
    byte byteVal = -128;
    short shortVal = -128;
    float floatVal = -1e-30;
  }
  double doubleVale = 123456789.012345e80;
  string strValue = "Foo\x09\"";
  char charValue = 'C';
  bool boolvalue = true;
  MyEnum enumValue = MyEnum.Enum5;
  @STORED V3f vect;
  V2f[] vectArray;
  @STORED Bounds2f bounds2d;
  @STORED @HEX ubyte[3] ubyteStaticArray = [1, 2, 255];
  string[3][2] stringArray2D;
  float[] emptyArray1, emptyArray2;
  @STORED{
    ubyte[] compressedArr = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10];
  }

  void clear(){
    auto arr = cast(ubyte*)(&this);
    arr[0..typeof(this).sizeof] = 0;
  }
}


import std.variant;

/*class JsonNode{
}

class JsonValue{
}

class JsonArray{
}

class JsonField{
}*/

void test(){
  string original, restored;

  DataStruct data;

  data.vectArray = [V2f(1,2), V2f(1,3), V2f(6,4)];

  data.class1 = new MyClass;
  data.class1.a = 42;


  writeln("\n\n saved values ---------------------------");
  original ~= data.text;
  data.writeln;
  string st0 = data.toJson;
  //st0.writeln;
  writeln("\n\n saved zeroes ---------------------------");
  data.clear;
  original ~= data.text;
  data.writeln;
  string st1 = data.toJson;
  //st1.writeln;

  writeln("\n\n restored values ---------------------------");
  data.fromJson(st0);
  restored ~= data.text;
  data.writeln;

  writeln("\n\n restored zeroes ---------------------------");
  data.fromJson(st1);
  restored ~= data.text;
  data.writeln;

  enforce(original == restored, "Json is fucked up. original!=restored.");
  print("\33\12JSON test successful.\33\7");
}


