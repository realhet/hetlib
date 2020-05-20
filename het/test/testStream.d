//@exe
//@import c:\d\libs
//@ldc
//@compile -m64 -mcpu=athlon64-sse3 -mattr=+ssse3
///@release
//@debug

import het.utils, het.stream, het.geometry;

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
  DataStruct[2] data;
  data[0].vectArray = [V2f(1,2), V2f(1,3), V2f(6,4)];
  data[0].class1 = new MyClass;
  data[0].class1.a = 42;
  data[1].clear;

  LOG("Original data:",
    "\nFilled:", data[0],
    "\nCleared:", data[1]);

  string original;
  original ~= data[0].text;  string st0 = data[0].toJson;
  original ~= data[1].text;  string st1 = data[1].toJson;

  DataStruct[2] rdata;
  string restored;
  rdata[0].fromJson_raise(st0);  restored ~= rdata[0].text;
  rdata[1].fromJson_raise(st1);  restored ~= rdata[1].text;

  LOG("Restored data:",
    "\nFilled:", rdata[0],
    "\nCleared:", rdata[1]);

  enforce(original == restored, "Json is fucked up. original!=restored.");
  LOG("\33\12JSON test successful.");

/*  enforce(0, " Error: FUCK");
  raise("FUCK");
  throw new Exception("FUCK");*/

  try{
    rdata[0].fromJson_raise(`{ "byteVal" : 300 }`);
    raise("Overflow test failed");
  }catch(Throwable){
    LOG("\33\12Overflow test successful.");
  }
}



class Property{
  @STORED string name, caption, hint;

  this(){}
  //this(string name, string caption, string hint){ this.name = name; this.caption = caption; this.hint = hint; }

}

class StringProperty : Property {
  @STORED{
    string act, def;
    string[] choices;
  }
  shared static this(){ registerStoredClass!(typeof(this)); }
}

class IntProperty : Property {
  @STORED int act, def, min, max, step=0;
  shared static this(){ registerStoredClass!(typeof(this)); }
}

class FloatProperty : Property {
  @STORED float act=0, def=0, min=0, max=0, step=0;
  shared static this(){ registerStoredClass!(typeof(this)); }
}



/*struct Property { @STORED:
  string name, caption, hint;
  Variant act, def, min, max;
  string[] choices;
}*/

void testProperty(){
/*  auto intProp = Property("cap.width", "caption", "hint", Variant(640), Variant(640), Variant(32), Variant(8192));
  auto floatProp = Property("floatprop", "", "", Variant(0.15), Variant(0.5), Variant(0.001), Variant(2));
  auto stringProp = Property("fileName", "", "", Variant(`c:\file.name`));
  auto choiceProp = Property("choices", "", "", Variant("yes"), Variant("no"), Variant(""), Variant(""), ["yes", "no", "maybe"]);*/

  auto s = q{{
        "class": "StringProperty",
        "name": "cap.type",
        "hint": "Type of capture source.",
        "act": "file",
        "def": "auto",
        "choices": [
            "auto",
            "file",
            "dshow",
            "gstreamer",
            "v4l2",
            "ueye",
            "any"
        ]
    }};

  Property prop;

  print("load 1");
  prop.fromJson_raise(s);
  print("load 2");
  prop.fromJson_raise(s);

  print(prop.toJson);

  print("-----------------------");

  Property[] props;
  props.fromJson_ignore(File(`c:\dl\props.json`).readText);

  print(props.toJson);

}

void main(){ application.runConsole({
  test;
  testProperty;
}); }
