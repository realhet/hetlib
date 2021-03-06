module het.stream;

import het.utils, het.tokenizer, het.keywords, std.traits, std.meta;

//todo: auto ref parameters.
//todo: srcFunct seems obsolete.
//todo: srcFunct seems obsolete.

//21.02.03
//todo: propertySet getters with typed defaults
//todo: propertySet getters with reference output
//todo: propertySet export to json with act values (or defaults)
//todo: propertySet import from json with act values (or defaults)
//todo: string.fromJson(`"hello"`),   int.fromJson("124");  ...
//todo: "hello".toJson(),   1234.toJson("fieldName");  ...  //must work on const!
//todo: import a struct from a propertySet

private __gshared string[string] classFullNameMap;

private alias LoaderFunc = void function(ref JsonDecoderState state, int idx, void*);
private alias SaverFunc = void function(ref string st, void* data, bool dense=false, bool hex=false, string thisName="", string indent="");

private __gshared LoaderFunc[string] classLoaderFunc;
private __gshared SaverFunc [string] classSaverFunc ;

void registerStoredClass(T)(){
  classFullNameMap[T.stringof] = fullyQualifiedName!T;

  classLoaderFunc[fullyQualifiedName!T] = cast(LoaderFunc) (&streamDecode_json!T);
  classSaverFunc [fullyQualifiedName!T] = cast(SaverFunc ) (&streamAppend_json!T);
}

private auto quoteIfNeeded(string s){ return s.canFind(" ") ? quoted(s) : s; } //todo: this is lame, must make it better in utils/filename routines

struct JsonDecoderState{ // JsonDecoderState
  string stream;
  string moduleName;
  ErrorHandling errorHandling;
  string srcFile, srcFunct; int srcLine;

  bool ldcXJsonImport; //if moduleName=="LDCXJSON", then it is set to true

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

//! fromJson ///////////////////////////////////

//Default version, errors are ignored.
//alias fromJson = fromJson_ignore;
string[] fromJson/*_ignore*/(Type)(ref Type data, string st, string moduleName="unnamed_json", ErrorHandling errorHandling=ErrorHandling.ignore, string srcFile=__FILE__, string srcFunct=__FUNCTION__, int srcLine=__LINE__){
  auto state = JsonDecoderState(st, moduleName, errorHandling, srcFile, srcFunct, srcLine);
  state.ldcXJsonImport = moduleName=="LDCXJSON";

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

//auto fromJson_raise(Type)(ref Type data, string st, string moduleName="", string srcFile=__FILE__, string srcFunct=__FUNCTION__, int srcLine=__LINE__){        fromJson!(Type)(data, st, moduleName, ErrorHandling.raise, srcFile, srcFunct, srcLine); }
//auto fromJson_track(Type)(ref Type data, string st, string moduleName="", string srcFile=__FILE__, string srcFunct=__FUNCTION__, int srcLine=__LINE__){ return fromJson!(Type)(data, st, moduleName, ErrorHandling.track, srcFile, srcFunct, srcLine); }

//todo: this should be a nonDestructive overwrite for not just classes but for assocArrays too.
//todo: New name: addJson or includeJson
auto fromJsonProps(Type)(Type data, string st, string moduleName="unnamed_json", ErrorHandling errorHandling=ErrorHandling.ignore, string srcFile=__FILE__, string srcFunct=__FUNCTION__, int srcLine=__LINE__)
if(is(Type == class))
{
  auto tmp = data;
  auto errors = fromJson(data, st, moduleName, errorHandling, srcFile, srcFunct, srcLine);

  if(data is null){
    auto msg = "fromJsonProps: Object was set to null. Did nothing..."; //todo: null should reset all fields
    with(ErrorHandling) final switch(errorHandling){
      case ignore: return;
      case raise: .raise(msg); break;
      case track: errors ~= msg;
    }
  }
}

//errorHandling: 0: no errors, 1:just collect the errors, 2:raise

void streamDecode_json(Type)(ref JsonDecoderState state, int idx, ref Type data){
  ref Token actToken(){ return state.tokens[idx]; }

  //todo: this mapping is lame
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

  /* old shit
  string peekClassName(){
    enum log = true;
    if(log) print("peekClassName------------");

    enforce(isOp!'{'); //must be at the start of a class
    const level = state.tokens[idx].level+1;

    string res;

    bool peekAt(int i, string cn){
      if(log) print("looking for:", cn, "level:", level, "in:", state.tokens[i..$].take(3));

      if(i+2 < state.tokens.length
      && state.tokens[i+0].level==level
      && state.tokens[i+1].isOperator(opcolon)
      && state.tokens[i+0].kind == TokenKind.literalString
      && state.tokens[i+2].kind == TokenKind.literalString
      && state.tokens[i+0].data == cn){
        res = state.tokens[i+2].data.to!string;
        if(log) print("found class declaration:", res);
        return true;
      }
      return false;
    }

    if(peekAt(idx+1, "class")) return res;

    if(peekAt(idx+1, "kind")) return res;
    if(peekAt(idx+3, "kind")) return res;

    return "";
  }*/

  string peekClassName(int[string] elementMap){
    string res;

    bool check(string cn){
      if(auto p = cn in elementMap){
        auto idx = *p;
        if(state.tokens[idx].isString){
          res = state.tokens[idx].data.to!string;
          //print("Json className found:", res);
          return true;
        }
      }
      return false;
    }

    if(state.ldcXJsonImport){
      if(check("kind")){
        res = res.split(' ').map!capitalize.join;
        //print("Found class kind:", res);
      }
    }else{
      if(check("class")) return res;
    }

    return res;
  }

  void expect(char b)(){
    if(!isOp!b) throw new Exception(format!`"%s" expected.`(b));
    idx++;
  }

  bool isNegative; //opt: is multiply with 1/-1 better?
  void getSign(){
    if(isOp!'-'){ isNegative = true; idx++; }
  }

  auto extractElements(){
    int[string] elementMap;

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
      elementMap[fieldName] = idx;              //opt: ez a megoldas igy qrvalassu
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

    return elementMap;
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
    }else static if(isVector!T){
      streamDecode_json(state, idx, data.components); //just forward reading the field: Vector.components
    }else static if(isMatrix!T){
      streamDecode_json(state, idx, data.columns); //just forward it to its internal array
    }else static if(isAggregateType!T     ){ // Struct, Class

      //handle null
      if(actToken.isKeyword(kwnull)){
        static if(is(T == class)){ //null class found
          data = null; return; //todo: what happens with old instance???!!!
        }else{
          data = T.init; //if it's a struct, reset it
        }
        return; //nothing else to expect after null
      }

      auto oldIdx = idx;
      auto elementMap = extractElements; //opt: with inherited classes it seeks twice. If the tokenizer would be hierarchical then it wouldn't take any time to extract.
      idx = oldIdx; //keep idx on the class instance,

      //handle null for class
      static if(is(T == class)){{
        //create a new instance with the default creator if needed
        //TODO !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
        //Ezt at kell gondolni es a linkelt classt is meg kell tudni csinalni

        //peek className   "class" : "name"
        auto className = peekClassName(elementMap),
             p = className in classFullNameMap,
             classFullName = p ? *p : "",
             currentClassFullName = data !is null ? typeid(data).to!string : "";

        //todo: error handling when there is no classloader for the class in json

        /*print("className in Json:", className);
        print("Trying to load class:", classFullName);
        print("Currently in Loader:", fullyQualifiedName!Type);
        print("Current Instance:", currentClassFullName);*/

        //call a different loader if needed
        if(classFullName.length && fullyQualifiedName!Type != classFullName){
          //print("Calling appropriate loader", classFullName);

          //todo: ezt felvinni a legtetejere es megcsinalni, hogy csak egyszer legyen a tipus ellenorizve
          //todo: Csak descendant classok letrehozasanak engedelyezese, kulonben accessviola

          auto fv = classLoaderFunc[classFullName]; //opt: inside here, elementMap is extracted once more
          fv(state, idx, &data);
          return;
        }

        //free if the class type is different.
        if(data !is null && classFullName.length && currentClassFullName != classFullName){
          data.free;
        }

        //create only if original is null
        if(data is null){
          static if(__traits(compiles, new Type)){
            data = new Type;
          }else{
            raise("fromJson: Unable to construct new instance of: "~Type.stringof);
          }
        }
      }}

      //recursive call for each field
      static foreach(fieldName; FieldNamesWithUDA!(T, STORED, true)){{

        //dirty fix for LDCXJSON reading. (not writing)
             static if(fieldName=="char_"   ) enum fn = "char"   ;
        else static if(fieldName=="align_"  ) enum fn = "align"  ;
        else static if(fieldName=="default_") enum fn = "default";
        else                                  enum fn = fieldName;

        if(auto p = fn in elementMap){
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

    }else static if(isAssociativeArray!T){

      //handle null
      if(actToken.isKeyword(kwnull)){
        data = T.init;
        return; //nothing else to expect after null
      }

      auto elementMap = extractElements;

      alias VT = Unqual!(ValueType!T),
            KT = Unqual!(KeyType!T);

      foreach(k, v; elementMap){
        VT tmp;
        streamDecode_json(state, v, tmp);
        data[k.to!KT] = tmp;
      }

    }else{
      static assert(0, "Unhandled type: "~T.stringof);
    }

  }catch(Throwable t){
    state.onError(t.msg, idx);
  }
}


//! toJson ///////////////////////////////////
string toJson(Type)(in Type data, bool dense=false, bool hex=false, string thisName=""){
  string st;
  streamAppend_json!(Type)(st, data, dense, hex, thisName);
  return st;
}

template isSomeChar(T){ enum isSomeChar = is(T == char) || is(T == wchar) || is(T == dchar); }

void streamAppend_json(Type)(ref string st, /*!!!!!*/in Type data, bool dense=false, bool hex=false, string thisName="", string indent=""){
  alias T = Unqual!Type;

  //call dynamic class writer. For example Type==Property and the actual class in data is StringProperty
  static if(is(T == class)){
    if(data !is null){
      const currentFullName = typeid(data).to!string; //todo: try to understand this
      if(currentFullName != fullyQualifiedName!T){ //use a different writer if needed
        auto p = currentFullName in classSaverFunc;
        if(p){
          (*p)(st, /*!!!!!*/cast(void*) data, dense, hex, thisName, indent);
          return;
        }else{
          //todo: error if there is no classSaver, throw error
          raise("toJson: unregisteded inherited class. Must call registerStoredClass!%s".format(currentFullName));
        }
      }
    }
  }

  //append ',' and newline(dense only) if needed
  {
    //get the last symbol before any whitespace
    char lastSymbol;
    auto s = st.stripRight;
    if(s.length) lastSymbol = s[$-1];
    //todo: this is unoptimal, but at least safe. It is possible to put this inside the [] and {} loop.

    const needComma = !lastSymbol.among('{', '[', ',', ':', '\xff'); //ff is empty stream, no comma needed
    if(dense){
      if(needComma) st ~= ",";
    }else{
      if(needComma) st ~= ",\n";
      st ~= indent;
    }
  }

  //append the associative name if there is one
  if(thisName!="")
    st ~= quoted(thisName)~(dense ? ":" : ": ");

  //switch all possible types
        static if(isFloatingPoint!T     ){ st ~= data.text_precise;
  }else static if(is(T == enum)         ){ st ~= quoted(data.text);
  }else static if(isIntegral!T          ){ if(hex) st ~= format!"0x%X"(data); else st ~= data.text;
  }else static if(isSomeString!T        ){ st ~= quoted(data);
  }else static if(isSomeChar!T          ){ st ~= quoted([data]);
  }else static if(is(T == bool)         ){ st ~= data ? "true" : "false";
  }else static if(isVector!T            ){ streamAppend_json(st, data.components, dense || true, hex, "", indent);
  }else static if(isMatrix!T            ){ streamAppend_json(st, data.columns   , dense || true, hex, "", indent);
  }else static if(isAggregateType!T     ){ // Struct, Class
    //handle null for class
    static if(is(T == class)){
      if(data is null){ st ~= "null"; return; }
    }

    st ~= dense ? "{" : "{\n";                  //opening bracket {
    const nextIndent = dense ? "" : indent~"  ";

    static if(is(T == class)){ //write class type name
      string s = T.stringof;
      streamAppend_json(st, s, dense, hex, "class", nextIndent);
    }

    //recursive call for each field
    static foreach (fieldName; FieldNamesWithUDA!(T, STORED, true)){{
      enum hasHex = hasUDA!(__traits(getMember, T, fieldName), HEX);
      streamAppend_json(st, __traits(getMember, data, fieldName), dense, hex || hasHex, fieldName, nextIndent);
    }}

    st ~= dense ? "}" : "\n"~indent~"}";        //closing bracket }
  }else static if(isArray!T){ // Array
    if(data.empty){ st ~= "[]"; return; }

    st ~= dense ? "[" : "[\n";                  //opening bracket [
    const nextIndent = dense ? "" : indent~"  ";

    const actHex = hex || hasUDA!(data, HEX);
    foreach(const val; data)
      streamAppend_json(st, val, dense, actHex, "", nextIndent);

    st ~= dense ? "]" : "\n"~indent~"]";        //closing bracket ]
  }else static if(isAssociativeArray!T){ // Associative array
    if(data.empty){ st ~= "null"; return; }

    st ~= dense ? "{" : "{\n";                  //opening bracket {
    const nextIndent = dense ? "" : indent~"  ";

    foreach(k, ref v; data)
      streamAppend_json(st, v, dense, hex, k.text, nextIndent);

    st ~= dense ? "}" : "\n"~indent~"}";        //closing bracket }
  }else{
    static assert(0, "Unhandled type: "~T.stringof);
  }
}


// tests /////////////////////////////////////////////////

private void unittest_JsonClassInheritance(){
  static class A{ int id; }
  static class B:A{ string bStr; }
  static class C:A{ string cStr;  }

  registerStoredClass!A;
  registerStoredClass!B;
  registerStoredClass!C;

  A[] arr;
  { auto a = new A; a.id = 9;               arr ~= a; }
  { auto b = new B; b.id = 1; b.bStr = "b"; arr ~= b; }
  { auto c = new C; c.id = 2; c.cStr = "c"; arr ~= c; }
  arr ~= null;

  auto json1 = arr.toJson;
  arr.clear;
  arr.fromJson(json1);
  auto json2 = arr.toJson;

  //json1.print; json2.print;

  assert(json1 == json2, "fromJson inherited classes fail.");
}

private void unittest_toJson(){
  //check formatting of 2d arrays
  assert([[1,2],[3,4]].toJson(true) == "[[1,2],[3,4]]");
  assert([[1,2],[3,4]].toJson(false) == "[\n  [\n    1,\n    2\n  ],\n  [\n    3,\n    4\n  ]\n]");
  assert(mat2(1,2,3,4).toJson(false) == [[1,2],[3,4]].toJson(true));
}

//! clearFields /////////////////////////////////////////

void clearFields(Type)(auto ref Type data)
if(is(Type==class) || __traits(isRef, data)) //only let classes not to be references  (auto ref template parameter)
{
  static if(is(Type==class)) if(data is null) return; //ignore empty null instances

  static string savedData = "\0"; //todo: use binaryJson
  if(savedData=="\0"){
    static Type temp;
    static if(is(Type==class)) temp = new Type;
    savedData = temp.toJson;

    print("Generate defaults for ", Type.stringof, "\n", savedData);
  }

  data.fromJson(savedData);
}


//! Properties //////////////////////////////////////////


class Property{
  @STORED{
    string name, caption, hint, unit;
    bool isReadOnly;
  }

  bool uiChanged; //stdUi sets this to true
  //todo: would be better to save the last value, than update this (and sometimes forget to update)

  string asText() { return ""; }
}

class StringProperty : Property {
  shared static this(){ registerStoredClass!(typeof(this)); }

  @STORED{
    string act, def;
    string[] choices;
  }

  override string asText(){ return act; }
}

class IntProperty : Property {
  shared static this(){ registerStoredClass!(typeof(this)); }

  @STORED int act, def, min, max, step=0;

  override string asText(){ return act.text; }
}

class FloatProperty : Property {
  shared static this(){ registerStoredClass!(typeof(this)); }

  @STORED float act=0, def=0, min=0, max=0, step=0;

  override string asText(){ return act.text; }
}

class BoolProperty : Property {
  shared static this(){ registerStoredClass!(typeof(this)); }

  @STORED bool act, def;

  override string asText(){ return act.text; }
}

class PropertySet : Property {
  shared static this(){ registerStoredClass!(typeof(this)); }

  @STORED Property[] properties;

  override string asText(){ return ""; }

  //copy paste from propArray --------------------------------------------------
  bool empty(){ return properties.empty; }

  auto access(T=void, bool mustExists=true)(string name){
    static if(is(T==void)) alias PT = Property;
    else static if(is(T : Property)) alias PT = T;
    else mixin("alias PT = ", T.stringof.capitalize ~ "Property;");

    auto p = cast(PT)findProperty(properties, name);
    static if(mustExists) enforce(p !is null, format!`%s not found: "%s"`(PT.stringof, name));
    return p;
  }

  auto get(T=void)(string name){ return access!(T, false)(name); }

  bool exists(string name){ return get(name) !is null; }
  //end of copy paste ----------------------------------------------------------

}

void expandPropertySets(char sep='.')(ref Property[] props){ //creates propertySets from properties named like "set.name"
  Property[] res;
  PropertySet[string] sets;

  foreach(prop; props){
    auto dir = prop.name.getFirstDir!sep;

    if(dir.length){
      auto set = dir in sets;  //todo: associativearray.update
      if(!set){
        auto ps = new PropertySet;
        ps.name = dir;
        res ~= ps;
        sets[dir] = ps;
        set = dir in sets;
      }
      set.properties ~= prop;
    }else{
      res ~= prop;
    }

    prop.name = prop.name.withoutFirstDir!sep;
  }

  //apply recursively
  foreach(ps; sets.values)
    ps.properties.expandPropertySets!sep;

  props = res;
}

string[] getPropertyValues(string filter = "true")(Property[] props, string rootPath=""){
  string[] res;
  foreach(a; props){
    auto fullName = join2(rootPath, ".", a.name);
    if(auto ps = cast(PropertySet)a){
      res ~= getChangedPropertyValues(ps.properties, fullName);
    }else{
      if(mixin(filter)){
        res ~= fullName ~ '=' ~ a.asText;
      }
    }
  }
  return res;
}

Property findProperty(Property[] props, string nameFilter, string rootPath=""){
  foreach(a; props){
    auto fullName = join2(rootPath, ".", a.name);
    if(fullName.isWild(nameFilter)) return a;
    if(auto ps = cast(PropertySet)a){
      auto res = ps.properties.findProperty(nameFilter, fullName);
      if(res) return res;
    }
  }
  return null;
}


Property[] findProperties(Property[] props, string nameFilter, string rootPath=""){
  Property[] res;
  foreach(a; props){
    auto fullName = join2(rootPath, ".", a.name);
    if(fullName.isWild(nameFilter)) res ~= a;
    if(auto ps = cast(PropertySet)a)
      res ~= ps.properties.findProperties(nameFilter, fullName);
  }
  return res;
}


string[] getChangedPropertyValues(Property[] props, string rootPath=""){
  return getPropertyValues!"chkClear(a.uiChanged)"(props, rootPath);
}


struct PropArray{ // PropArray ////////////////////////////////////////////
  string queryName; //name of the
  Property[] props;
  string pendingQuery; //url of changed settings

  bool pending(){ return !pendingQuery.empty; }
  void clear(){ props.clear; pendingQuery = ""; }

  bool empty(){ return props.empty; }

  auto access(T=void, bool mustExists=true)(string name){
    static if(is(T==void)) alias PT = Property;
    else static if(is(T : Property)) alias PT = T;
    else mixin("alias PT = ", T.stringof.capitalize ~ "Property;");

    auto p = cast(PT)findProperty(props, name);
    static if(mustExists) enforce(p !is null, format!`%s not found: "%s"`(PT.stringof, name));
    return p;
  }

  auto get(T=void)(string name){ return access!(T, false)(name); }

  auto get(T=void)(string name, string def){
    auto p = get(name);
    if(p is null) return def;
    return p.asText;
  }

  bool exists(string name){ return get(name) !is null; }

  void update(){
    auto s = props.getChangedPropertyValues;
    if(s.length){
      auto q = queryName~"?"~s.join("&");
      mergeUrlParams(pendingQuery, q);
    }
  }

  string fetchPendingQuery(){
    auto res = pendingQuery;
    pendingQuery = "";
    return res;
  }
}



void unittest_main(){
  //todo: more tests!
  unittest_JsonClassInheritance;
  unittest_toJson;

  // check the precision of jsonized vectors
  foreach(T; AliasSeq!(float, double, real)){
    auto v = vec3(1,2,3)*T(PI);
    auto s = v.toJson;
    Vector!(T, 3) v2; v2.fromJson(s);
    //print(v, s, v2);
    assert(v2 == v);
  }
}

unittest{ unittest_main; }