module het.stream;

import std.traits, std.format, std.conv, std.array, std.algorithm;

struct STORED{ } //UDA

private string quote(string s){ return format!"%(%s%)"([s]); }
template isSomeChar(T){ enum isSomeChar = is(T == char) || is(T == wchar) || is(T == dchar); }

void streamAppend_json(string thisName="", Type)(ref string st, const Type data, string indent=""){
  if(st.length && !(st[$-1].among('\n'))) st~=",\n";
  st ~= indent;

  static if(thisName!=""){
    enum s = quote(thisName)~": ";
    st ~= s;
  }

  alias T = Unqual!Type;
  static if(isFloatingPoint!T){
    static if(T.sizeof>=8) st ~= format!"%.15g"(data);
                      else st ~= format!"%.7g" (data);
  }else static if(is(T == enum)){
    st ~= quote(data.text);
  }else static if(isIntegral!T){
    st ~= data.text;
  }else static if(isSomeString!T){
    st ~= quote(data);
  }else static if(isSomeChar!T){
    st ~= quote([data]);
  }else static if(is(T == bool)){
    st ~= data ? "true" : "false";
  }else static if(isAggregateType!T){

    st ~= "{\n";
    const nextIndent = indent~"  ";
    enum lastIdx = FieldNameTuple!T.length-1;
    static foreach(idx, fieldName; FieldNameTuple!T)
      mixin("streamAppend_json!(fieldName)(st, data.*, nextIndent);".replace("*", fieldName));
    st ~= "\n"~indent~"}";

  }else static if(isArray!T){

    if(data.empty){
      st ~= "[]";
    }else{
      st ~= "[\n";
      const nextIndent = indent~"  ";
      foreach(const val; data[0..$])
        streamAppend_json(st, val, nextIndent);
      st ~= "\n"~indent~"]";
    }

  }else{
    static assert(0, "Unhandled type: "~T.stringof);
  }
}
