module het.stream;

import het.utils, het.tokenizer, het.keywords, std.traits, std.meta;


//UDAs
struct STORED{}
struct HEX{}
struct BASE64{}


string toJson(bool dense=false, bool hex=false, string thisName="", Type)(auto ref in Type data){
  string st;
  streamAppend_json!(dense, hex, thisName, Type)(st, data);
  return st;
}

void fromJson(Type)(ref Type data, string st, string fileName="JSON"){
  Token[] tokens;
  auto error = tokenize(fileName, st, tokens);
  enforce(error=="", error);
  enforce(!tokens.empty, "fromJson(): Nothing to decode");

  discoverJsonHierarchy(tokens);

  //foreach(ref t; tokens) print(" ".replicate(t.level) ~ t.source);

  streamDecode_json(tokens, 0, data, fileName);
}


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


void streamDecode_json(Type)(ref Token[] tokens, int idx, ref Type data, string fileName=""){
  void error(string msg){ tokens[idx].raiseError(`Error decoding "%s": %s`.format(Type.stringof, msg), fileName); }

  bool isOp(char b)(){
         static if(b=='[') return tokens[idx].isOperator(opsquareBracketOpen); //this is lame
    else static if(b==']') return tokens[idx].isOperator(opsquareBracketClose);
    else static if(b=='{') return tokens[idx].isOperator(opcurlyBracketOpen);
    else static if(b=='}') return tokens[idx].isOperator(opcurlyBracketClose);
    else static if(b==',') return tokens[idx].isOperator(opcomma);
    else static if(b==':') return tokens[idx].isOperator(opcolon);
    else static if(b=='-') return tokens[idx].isOperator(opsub);
    else static assert(0, `Unhandled op "%s"`.format(b));
  }

  void expect(char b)(){
    if(!isOp!b) error(`"%s" expected`.format(b));
    idx++;
  }

  bool isNegative; //opt: is multiply with 1/-1 better?
  void getSign(){
    if(isOp!'-'){ isNegative = true; idx++; }
  }

  //switch all possible types
  alias T = Unqual!Type;
  /***/ static if(isFloatingPoint!T     ){
    getSign;
    try{
      //todo: error checking
      data = cast(Type)((tokens[idx].data).get!real);
      if(isNegative) data = -data;
    }catch(Throwable){ }
  }else static if(is(T == enum)         ){
    try{
      data = tokens[idx].data.get!string.to!Type;
    }catch(Throwable){ }
  }else static if(isIntegral!T          ){
    getSign;
    try{
      //todo: error checking
      static if(is(T == ulong)) auto L = tokens[idx].data.get!ulong;
                           else auto L = tokens[idx].data.get!long;
      if(isNegative) L = -L;
      data = L.to!Type;
    }catch(Throwable){ }
  }else static if(isSomeString!T        ){
    //todo: error checking
    try{
      data = tokens[idx].data.get!string.to!Type;
    }catch(Throwable){ }
  }else static if(isSomeChar!T          ){
    try{
      wstring s = tokens[idx].data.get!string.to!wstring;
      enforce(s.length>0);
      data = s[0].to!Type;
    }catch(Throwable){ } //todo: error handling
  }else static if(is(T == bool)         ){
    if(tokens[idx].isKeyword(kwfalse)) data = false;
    else if(tokens[idx].isKeyword(kwtrue)) data = true;
    else { } //todo: error handling
  }else static if(isAggregateType!T     ){ // Struct, Class
    //handle null for class
    static if(is(T == class)){
      if(tokens[idx].isKeyword(kwnull)){
        data = null; return;
      }else if(isOp!'{'){
        //create a new instance with the default creator if needed
        //TODO !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
        //Ezt at kell gondolni es a linkelt classt is meg kell tudni csinalni
        if(data is null){
          data = new Type; //continue with loading fields
        }
      }else{
        error("Class expected");
      }
    }

    int[string] elementMap; //opt: at first, do it with a linear list. when it fails, do a map.

    enum log = false;
    if(log) write("JSON discover fields: ");

    const level = tokens[idx].level;
    expect!'{';

    while(1){
      if(isOp!'}') break; //"}" right after "," or "{"

      if(tokens[idx].kind != TokenKind.LiteralString) error("Field name string literal expected.");
      auto fieldName = tokens[idx].data.to!string;
      idx++;

      expect!':';

      //remember the start of the element
      elementMap[fieldName] = idx;
      if(log) write(fieldName, " ", idx, " ");

      //skip until the next '}' or ','
      int idx0 = idx;
      while(tokens[idx].level>level) idx++; //skip to next thing. No error checking because validiti is already checked in the hierarchy building process.
      if(idx==idx0) error("Value expected");

      if(isOp!'}') break; //"}" at the end

      if(!isOp!',') error(`"}" or "," expected.`);
      idx++;
    }
    if(log) writeln;

    //select fields to store (all fields except if specified with STORED uda)
    enum bool hasStored(string fieldName) = hasUDA!(__traits(getMember, T, fieldName), STORED);
    enum fields = FieldNameTuple!T;
    static if(anySatisfy!(hasStored, fields)) enum storedFields = Filter!(hasStored, fields);
                                         else enum storedFields = fields;
    //recursive call for each field
    static foreach (fieldName; storedFields){{
      if(auto p = fieldName in elementMap){
        streamDecode_json(tokens, *p, __traits(getMember, data, fieldName), fileName);
      }
    }}

  }else static if(isArray!T){ // Array

    int cnt=0; //number of imported elements

    const level = tokens[idx].level;
    expect!'[';

    while(1){
      if(isOp!']') break; //"]" right after "," or "["

      //skip until the next '}' or ','
      int idx0 = idx;
      while(tokens[idx].level>level) idx++; //skip to next thing. No error checking because validiti is already checked in the hierarchy building process.
      if(idx==idx0) error("Value expected");

      static if(isDynamicArray!T){ if(cnt>=data.length) data.length = cnt+1; } //make room
      static if(isStaticArray!T){ enforce(cnt<data.length, "Array overflow"); } //check static array length

      streamDecode_json(tokens, idx0, data[cnt], fileName);
      cnt++;

      if(isOp!']') break; //"]" at the end

      if(!isOp!',') error(`"]" or "," expected.`);
      idx++;
    }

    static if(isDynamicArray!T) data.length = cnt; //cut back the array  !!!!!!!!!!!!!!!! what if these are classes !!!!!!!!!!!!!!!
    static if(isStaticArray!T) enforce(data.length == cnt);

  }else{
    static assert(0, "Unhandled type: "~T.stringof);
  }
}