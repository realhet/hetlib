module het.stream;

import het.utils, het.tokenizer, het.keywords, std.traits, std.meta;


//UDAs
struct STORED{}
struct HEX{}
struct BASE64{}

enum ErrorHandling { ignore, raise, track }

private auto quoteIfNeeded(string s){ return s.canFind(" ") ? quoted(s) : s; } //todo: this is lame, must make it better in utils/filename routines

struct JsonDecoderState{
  string stream;
  string moduleName;
  ErrorHandling errorHandling;
  string srcFile, srcFunct; int srcLine;

  Token[] tokens;
  string[] errors;

  string errorMsg(string msg, int tokenIdx=-1){

    string location;
    if(tokenIdx.inRange(tokens)){
      auto t = &tokens[tokenIdx];
      location = format!`%s(%s:%s): `(quoteIfNeeded(moduleName), t.line+1, t.posInLine+1);
    }else if(moduleName!=""){
      location = quoteIfNeeded(moduleName) ~ ": ";
    }

    return (location ~ " " ~ msg).strip;
  }

  void raise(string msg, int tokenIdx=-1){
    throw new Exception(errorMsg(msg, tokenIdx), srcFile, srcLine);
  }

  void onError(string msg, int tokenIdx=-1){
    if(msg=="") return;

    with(ErrorHandling) final switch(errorHandling){
      case ignore: return;
      case raise: this.raise(msg, tokenIdx); break;
      case track: errors ~= errorMsg(msg, tokenIdx);
    }
  }

}

//Default version, errors are ignored.
alias fromJson = fromJson_ignore;
string[] fromJson_ignore(Type)(ref Type data, string st, string moduleName="unnamed_json", ErrorHandling errorHandling=ErrorHandling.ignore, string srcFile=__FILE__, string srcFunct=__FUNCTION__, int srcLine=__LINE__){
  auto state = JsonDecoderState(st, moduleName, errorHandling, srcFile, srcFunct, srcLine);

  try{
    //1. tokenize
    auto err = tokenize(state.moduleName, state.stream, state.tokens); //todo: tokenize throw errors
    if(err!="") throw new Exception(err);
    if(state.tokens.empty) throw new Exception("Empty json document.");

    //2. hierarchy
    discoverJsonHierarchy(state.tokens);

    //3. jsonParse
    streamDecode_json(state, 0, data);
  }catch(Throwable e){
    state.onError(e.msg);
  }

  return state.errors;
}

auto fromJson_raise(Type)(ref Type data, string st, string moduleName="", string srcFile=__FILE__, string srcFunct=__FUNCTION__, int srcLine=__LINE__){
  fromJson!(Type)(data, st, moduleName, ErrorHandling.raise, srcFile, srcFunct, srcLine); }

auto fromJson_track(Type)(ref Type data, string st, string moduleName="", string srcFile=__FILE__, string srcFunct=__FUNCTION__, int srcLine=__LINE__){
  return fromJson!(Type)(data, st, moduleName, ErrorHandling.track, srcFile, srcFunct, srcLine); }


string toJson(bool dense=false, bool hex=false, string thisName="", Type)(auto ref in Type data){
  string st;
  streamAppend_json!(dense, hex, thisName, Type)(st, data);
  return st;
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


//errorHandling: 0: no errors, 1:just collect the errors, 2:raise

void streamDecode_json(Type)(ref JsonDecoderState state, int idx, ref Type data){
  ref Token actToken(){ return state.tokens[idx]; }

  //this mapping is lame
  bool isOp(char b)(){
         static if(b=='[') return actToken.isOperator(opsquareBracketOpen);
    else static if(b==']') return actToken.isOperator(opsquareBracketClose);
    else static if(b=='{') return actToken.isOperator(opcurlyBracketOpen);
    else static if(b=='}') return actToken.isOperator(opcurlyBracketClose);
    else static if(b==',') return actToken.isOperator(opcomma);
    else static if(b==':') return actToken.isOperator(opcolon);
    else static if(b=='-') return actToken.isOperator(opsub);
    else static assert(0, `Unhandled op "%s"`.format(b));
  }

  void expect(char b)(){
    if(!isOp!b) throw new Exception(format!`"%s" expected.`(b));
    idx++;
  }

  bool isNegative; //opt: is multiply with 1/-1 better?
  void getSign(){
    if(isOp!'-'){ isNegative = true; idx++; }
  }

  alias T = Unqual!Type;

  try{ //the outermost exception handler calls state.onError

    //switch all possible types
    /*-*/ static if(isFloatingPoint!T     ){
      getSign;
      data = cast(Type)((actToken.data).get!real);
      if(isNegative) data = -data;
    }else static if(is(T == enum)         ){
      data = actToken.data.get!string.to!Type;
    }else static if(isIntegral!T          ){
      getSign;
      static if(is(T == ulong)) auto L = actToken.data.get!ulong;
                           else auto L = actToken.data.get!long;
      if(isNegative) L = -L;
      data = L.to!Type;
    }else static if(isSomeString!T        ){
      data = actToken.data.get!string.to!Type;
    }else static if(isSomeChar!T          ){
      dstring s = actToken.data.get!string.to!dstring;
      if(s.length!=1) throw new ConvException("Expecting 1 char only.");
      data = s[0].to!Type;
    }else static if(is(T == bool)         ){
      if(actToken.kind.among(TokenKind.literalInt, TokenKind.literalFloat))
        data = actToken.data != 0;
      else if(actToken.isKeyword(kwfalse)) data = false;
      else if(actToken.isKeyword(kwtrue)) data = true;
      else throw new ConvException(`Invalid bool value`);
    }else static if(isAggregateType!T     ){ // Struct, Class
      //handle null for class
      static if(is(T == class)){
        if(actToken.isKeyword(kwnull)){
          data = null; return;
        }else if(isOp!'{'){
          //create a new instance with the default creator if needed
          //TODO !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
          //Ezt at kell gondolni es a linkelt classt is meg kell tudni csinalni
          if(data is null){
            data = new Type; //continue with loading fields
          }
        }else{
          throw new Exception("Class expected for \"null\" token.");
        }
      }

      int[string] elementMap; //opt: at first, do it with a linear list. when it fails, do a map.

      enum log = false;
      if(log) write("JSON discover fields: ");

      const level = actToken.level;
      expect!'{';

      while(1){
        if(isOp!'}') break; //"}" right after "," or "{"

        if(actToken.kind != TokenKind.literalString) throw new Exception("Field name string literal expected.");
        auto fieldName = actToken.data.to!string;
        idx++;

        expect!':';

        //remember the start of the element
        elementMap[fieldName] = idx;
        if(log) write(fieldName, " ", idx, " ");

        //skip until the next '}' or ','
        int idx0 = idx;
        while(actToken.level>level) idx++; //skip to next thing. No error checking because validiti is already checked in the hierarchy building process.
        if(idx==idx0) throw new Exception("Value expected");

        if(isOp!'}') break; //"}" at the end

        if(!isOp!',') throw new Exception(`"}" or "," expected.`);
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
          streamDecode_json(state, *p, __traits(getMember, data, fieldName));
        }
      }}

    }else static if(isArray!T){ // Array

      int cnt=0; //number of imported elements

      const level = actToken.level;
      expect!'[';

      while(1){
        if(isOp!']') break; //"]" right after "," or "["

        //skip until the next '}' or ','
        int idx0 = idx;
        while(actToken.level>level){
          idx++; //skip to next thing. No error checking because validity is already checked in the hierarchy building process.
          assert(idx < state.tokens.length, "Fatal error: something is wrong with discoverJsonHierarchy()");
        }
        if(idx==idx0) throw new Exception("Value expected");

        //when array is too small
        if(cnt>=data.length){
          static if(isDynamicArray!T){
            data.length = cnt+1; //make room
          }else{
            if(state.errorHandling==ErrorHandling.raise){
              throw new Exception("Static array overflow.");
            }else{
              state.onError("Static array overflow."); //track or ignore
            }
            break; //stop processing when the static array is full, to avoid index overflow
          }
        }

        //decode array element
        streamDecode_json(state, idx0, data[cnt]);
        cnt++;

        if(isOp!']') break; //"]" at the end

        if(!isOp!',') throw new Exception(`"]" or "," expected.`);
        idx++;
      }

      static if(isDynamicArray!T){
        data.length = cnt; //todo: cut back the array  !!!!!!!!!!!!!!!! what if these are linked classes !!!!!!!!!!!!!!! managed resize array needed
      }else{
        if(data.length != cnt) throw new Exception("Static array size mismatch: %s < %s".format(cnt, data.length));
      }

    }else{
      static assert(0, "Unhandled type: "~T.stringof);
    }

  }catch(Throwable t){
    state.onError(t.msg, idx);
  }
}