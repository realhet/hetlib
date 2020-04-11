//@exe
//@import c:\d\libs
//@ldc
//@compile -m64 -mcpu=athlon64-sse3 -mattr=+ssse3
///@release
//@debug

import het.utils, het.stream, het.geometry;

void main(){ application.runConsole({ test; }); }

struct DataStruct{
  enum MyEnum:ubyte { Enum0, Enum1, Enum5=5 }
  int intValue = 42;
  ulong ulongVal = 0xFFFF_FFFF_FFFF_FFFF;
  short shortVal = -128;
  float floatVal = -1e-30;
  double doubleVale = 123456789.012345e80;
  string strValue = "Foo\x09\"";
  char charValue = 'C';
  bool boolvalue = true;
  MyEnum enumValue = MyEnum.Enum5;
  V3f vect;
  V2f[] vectArray;
  Bounds2f bounds2d;
  ubyte[3] ubyteStaticArray;
  string[3][2] stringArray2D;
  float[] emptyArray1, emptyArray2;
}


void test(){
   DataStruct data;

   data.vectArray = [V2f(1,2), V2f(1,3), V2f(6,4)];

   string st;
   st.streamAppend_json(data);

   st.writeln;
}


