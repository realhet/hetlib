module het.stream;

import std.traits, std.meta, std.format, std.conv, std.array, std.algorithm, std.stdio;

struct STORED{} //UDA
struct HEX{}
struct BASE64{}

private string quote(string s){ return format!"%(%s%)"([s]); }
template isSomeChar(T){ enum isSomeChar = is(T == char) || is(T == wchar) || is(T == dchar); }

void streamAppend_json(bool dense=false, bool hex=false, string thisName="", Type)(ref string st, auto ref in Type data, string indent=""){
  //append ',' and newline(dense only) if needed
  static if(dense){
    if(st.length && !st[$-1].among('{', '[')) st ~= ",";
  }else{
    if(st.length && st[$-1]!='\n') st ~= ",\n";
    st ~= indent;
  }

  //append the associative name if there is one
  static if(thisName!=""){
    enum s = quote(thisName)~(dense ? ":" : ": ");
    st ~= s;
  }

  //switch all possible types
  alias T = Unqual!Type;
        static if(isFloatingPoint!T     ){ static if(T.sizeof>=8) st ~= format!"%.15g"(data); else st ~= format!"%.7g" (data);
  }else static if(is(T == enum)         ){ st ~= quote(data.text);
  }else static if(isIntegral!T          ){ static if(hex) st ~= format!"0x%X"(data); else st ~= data.text;
  }else static if(isSomeString!T        ){ st ~= quote(data);
  }else static if(isSomeChar!T          ){ st ~= quote([data]);
  }else static if(is(T == bool)         ){ st ~= data ? "true" : "false";
  }else static if(isAggregateType!T     ){ // Struct, Class
    //handle null for class
    static if(is(T == class)){
      if(data is null){ st ~= "null"; return; }
    }

    st ~= dense ? "{" : "{\n";                  //opening bracket {
    const nextIndent = dense ? "" : indent~"  ";

    //select fields to store (all fields except if specified with STORED uda)
    enum bool hasStored(string fieldName) = hasUDA!(__traits(getMember, T, fieldName), STORED);
    enum fields = FieldNameTuple!T;
    static if(anySatisfy!(hasStored, fields)) enum storedFields = Filter!(hasStored, fields);
                                         else enum storedFields = fields;
    //recursive call for each field
    static foreach (fieldName; storedFields){{
      enum hasHex = hasUDA!(__traits(getMember, T, fieldName), HEX);
      streamAppend_json!(dense, hex || hasHex, fieldName)(st, __traits(getMember, data, fieldName), nextIndent);
    }}

    st ~= dense ? "}" : "\n"~indent~"}";        //closing bracket }
  }else static if(isArray!T){ // Array
    if(data.empty){ st ~= "[]"; return; }

    st ~= dense ? "[" : "[\n";                  //opening bracket [
    const nextIndent = dense ? "" : indent~"  ";

    enum actHex = hex || hasUDA!(data, HEX);
    foreach(const val; data)
      streamAppend_json!(dense, actHex)(st, val, nextIndent);

    st ~= dense ? "]" : "\n"~indent~"]";        //closing bracket ]
  }else{
    static assert(0, "Unhandled type: "~T.stringof);
  }
}
