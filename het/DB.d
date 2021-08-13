module het.db;

import het.utils;


/////////////////////////////////////////////////////////////////////
/// AMDB                                                          ///
/////////////////////////////////////////////////////////////////////


class AMDBException : Exception {
  this(string s){ super(s); }
}

interface DBFileInterface{
  File file();
  string[] readLines(); //reads the whole file
  void appendLines(string[] lines); //appends some lines
}

class TextDBFile : DBFileInterface{
  private File file_;

  this(File file){
    this.file_ = file;
  }

  File file(){ return file_; }

  string[] readLines(){ return file_.readLines; }

  void appendLines(string[] lines){ file_.append("\n"~lines.join("\n")~"\n"); }
}

class AMDB{
  private DBFileInterface dbFileInterface;

  File file(){ return dbFileInterface ? dbFileInterface.file : File(""); }

  this(){
    //do critical unittests
    __gshared static bool tested;
    if(tested.chkSet) unittest_splitSentences;
  }

  this(DBFileInterface dbFileInterface){
    this();

    this.dbFileInterface = dbFileInterface;

    //load
    try{
      if(dbFileInterface) foreach(line; dbFileInterface.readLines){
        line = line.strip;
        if(line=="") continue;
        const idx = line.map!(ch => ch==' ' || ch=='=').countUntil(true);
        enforce(idx>0, "Invalid text db line format: "~line.quoted);

        //get Id
        const id = Id(line[0..idx].to!uint);
        enforce(id, "Invalid null id");
        enforce(!(id in itemById), id.text~" already exists as an item. "~line.quoted);
        enforce(!(id in linkById), id.text~" already exists as a link. "~line.quoted);

        const lineType = line[idx];
        line = line[idx+1..$];

        switch(lineType){
          case '=':{ //Item
            _internalCreateItem(id, autoUnquoted(line));
          }break;
          case ' ':{
            auto p = line.split(' ').map!(a => Id(a.to!uint)).array;
            enforce(p.length.among(2, 3), "Invalid link id count. "~line.quoted);
            if(p.length==2) p ~= Id.init;
            foreach(a; p) enforce(!a || a in itemById || a in linkById, "Invalid link id: "~a.text~" "~line.quoted);
            _internalCreateLink(id, Link(p[0], p[1], p[2]));

          }break;
          default: raise("Unknown lineType. "~line.quoted);
        }

        lastIdIndex.maximize(id.id);

      }
    }catch(Exception e){
      raise("AMDB load error: "~e.simpleMsg);
    }
  }

  this(File file){ this(new TextDBFile(file)); }
  this(string fileName){ this(File(fileName)); }

  bool autoCreateETypes   = true;
  bool autoCreateVerbs    = true;
  bool autoCreateEntities = false;

  void error(string s) const{ throw new AMDBException(s); }

  static string autoQuoted(string s){
    //todo: slow
    if(s.canFind!(ch => ch<32 || ch.among('"', '\'', '`')) || s.canFind("  ") || s.canFind("..."))return s.quoted;
    else return s;
  }

  static string autoUnquoted(string s){
    if(s.startsWith('"')){
      import het.tokenizer; //todo: agyuval verebre...
      Token[] t;
      string err = tokenize("", s, t);
      enforce(err=="" && t.length, "Error decoding quoted string: "~err);
      return t[0].data.to!string;
    }else return s;
  }

  // Id ////////////////////////////////////

  struct Id{
    uint id;

    @property bool isNull() const { return id==0; }
    T opCast(T: bool)() const { return this.id != 0; }

    size_t toHash() const @safe pure nothrow{ return id; }
    bool opEquals(ref const Id b) const @safe pure nothrow{ return id==b.id; }

    string toString() const { return id.text; }

    long opCmp(in Id b) const{ return long(id)-long(b.id); }

    string serializeText() const{ return id.to!string(10); }
    void deserializeText(string s){ id = s.to!uint(10); }
  }

  protected uint lastIdIndex;

  Id nextId(){
    return Id(++lastIdIndex);
  }

  // When an item is imported
  void updateNextId(in Id id){
    lastIdIndex.maximize(id.id);
  }

  // Commit buffer ////////////////////

  private string[] commitBuffer;

  bool inTransaction(){ return commitBuffer.length>0; }

  void commit(){
    if(!inTransaction) return;

    if(dbFileInterface){
      dbFileInterface.appendLines(commitBuffer);
    }

    commitBuffer = null;
  }

  void cancel(){
    if(!inTransaction) return;

    NOTIMPL;
  }

  // Item /////////////////////////////

  private string[Id] itemById;
  private Id[string] idByItem;

  private enum Access{ get, require, create }

  // returns Id.null if not found
  Id itemId_get(string name)                                    { if(auto id = name in idByItem) return *id; else return Id.init; }

  // return defaault id if not found
  Id itemId_get(string name, lazy Id def)                       { if(auto id = name in idByItem) return *id; else return def; }

  // throws an exception if not found
  Id itemId_require(string name, lazy string errorMsg="")       { if(auto id = name in idByItem) return *id;
                                                                                            else{ error(format!"Required item %s not found. %s"(name, errorMsg)); assert(0); } }

  //inserts into the lists, called by itemId_create and importItem
  protected void _internalCreateItem(in Id id, string name){
    idByItem[name] = id;
    itemById[id] = name;
  }

  // auto-create if not found
  Id itemId_create(string name, void delegate(Id) onCreate = null){
    if(auto res = itemId_get(name)) return res;

    auto id = nextId;
    _internalCreateItem(id, name);
    onItemCreated(id);
    if(onCreate !is null) onCreate(id);
    return id;
  }


  bool isItem(in Id id   ) const{ return (id in itemById)!is null; }
  bool isItem(string name) const{ return (name in idByItem)!is null; }

  string itemStr(in Id id) const{
    if(auto a = id in itemById) return *a;
    error("Item doesn't exists: "~id.text);
    assert(0);
  }

  string itemStr(in Id id, lazy string def) const{
    if(auto a = id in itemById) return *a;
    return def;
  }

  size_t itemCount() const { return itemById.length; }
  // Link //////////////////////////////////////

  struct Link{
    Id sourceId, verbId, targetId;

    size_t toHash() const @safe pure nothrow{
      return sourceId.hashOf(verbId.hashOf(targetId.hashOf));
    }

    bool opEquals(ref const Link b) const @safe pure nothrow{
      return sourceId==b.sourceId
          && verbId  ==b.verbId
          && targetId==b.targetId;
    }
  }

  Link[Id] linkById;
  Id[Link] idByLink;

  string toStr(in Id id, int recursion=0){
    if(!id) return "Null";
    if(auto item = id in itemById) return format!"Item(%s, %s)"(id, (*item).quoted);
    if(auto link = id in linkById) with(*link){
      if(recursion-->0){
        return format!"Link(%s, %s, %s, %s)"(id, toStr(sourceId, recursion), toStr(verbId, recursion), toStr(targetId, recursion));
      }else{
        return format!"Link(%s, %s, %s, %s)"(id, sourceId, verbId, targetId);
      }
    }
    return format!"Unknown(%s)"(id);
  }

  string prettyStr(in Id id, bool recursion=false){
    if(!id) return "Null";
    if(auto item = id in itemById){
      string s = *item;
      if(isSystemVerb(s)) return EgaColor.ltWhite(s);
      if(isSystemType(s)) return EgaColor.ltGreen(s);
      if(isVerb(id))      return EgaColor.yellow(s);
      if(isEType(id))     return EgaColor.ltMagenta(s);
      if(isEntity(id))    return EgaColor.ltBlue(s);
      return s;
    }
    if(auto link = id in linkById) with(*link){
      if(recursion){
        return format!"...%s"(id);
      }else{
        return format!"%s : %s  %s  %s"(id, prettyStr(sourceId, true), prettyStr(verbId, true), prettyStr(targetId, true));
      }
    }
    return format!"Unknown(%s)"(id);
  }

  protected void _internalCreateLink(in Id id, in Link link){
    linkById[id] = link;
    idByLink[link] = id;
  }

  Id linkId(in Id sourceId, in Id verbId, in Id targetId=Id.init, bool createNew=true){
    auto link = Link(sourceId, verbId, targetId);
    if(auto id = link in idByLink){
      //print(format!"Link accessed: %s"(linkToStr(*id, link)));
      return *id;
    }
    if(createNew){
      auto id = nextId;
      _internalCreateLink(id, link);
      onLinkCreated(id);
      return id;
    }else{
      return Id.init;
    }
  }

  bool isLink(in Id id) const{ return (id in linkById)!is null; }

  bool isInstanceOf(string entity, in Id eTypeId){
    return exists(entity, "is a", eTypeId); //todo: "has supertype" handling
  }

  size_t linkCount() const { return linkById.length; }

  // Central notification handling ////////////////////////////

  //called after create but not when loading
  void onItemCreated(in Id id){
    commitBuffer ~= serializeText(id);
  }

  //called after create but not when loading
  void onLinkCreated(in Id id){
    commitBuffer ~= serializeText(id);
  }

  // serialization ////////////////////////////////////////////

  protected void loadItem(in Id id, string data){
    if(isLink(id)) error(format!"Load error: Item id already exists as a link. id=%s old=%s new=%s"(id, toStr(id), data));
    if(auto item = id in itemById){
      if(*item==data) return; //already loaded, id is the same
      error(format!"Load error: Id already exists with different item data. id=%s old=%s new=%s"(id, toStr(id), data));
    }
    //id is free, check duplicated data
    if(data in idByItem) format!"Load error: Item already exists with different id. new=%s"(data);

    //good to go, create it
    _internalCreateItem(id, data);
    updateNextId(id);
  }

  protected void loadLink(in Id id, in Link data){
    if(isItem(id)) error(format!"Load error: Link id already exists as an item. id=%s old=%s new=%s"(id, toStr(id), data));
    if(auto link = id in linkById){
      if(*link==data) return; //already loaded, id is the same
      error(format!"Load error: Id already exists with different link data. id=%s old=%s new=%s"(id, toStr(id), data));
    }
    //id is free, check duplicated data
    if(data in idByLink) format!"Load error: Link already exists with different id. new=%s"(data);

    //good to go, create it
    _internalCreateLink(id, data);
    updateNextId(id);
  }

  string serializeText(in Id id){


    if(auto link = id in linkById){
      with(*link) return id.serializeText ~" "~ sourceId.serializeText ~" "~ verbId.serializeText ~(targetId ? " "~targetId.serializeText : "");
    }else if(auto item = id in itemById){
      auto s = autoQuoted(*item);
      //string is closed with newLine.  Only need to escape when it contains newLine or starts with the escape quote. But to make sure, escape it if it contains any special chars
      return id.serializeText~"="~s;
    }else error("Invalid Id to serialize:"~id.text);
    assert(0);
  }

  string serializeText(R)(in R r){ return r.map!(i => serializeText(i)~"\n").join; }

  void deserializeText(string input){
    if(input.strip=="") return;

    //todo: 2passes: 1. prepare, 2. if no error: import... Option to ignore errors
    foreach(line; input.splitLines){
      auto p0 = line.map!(a => a.among(' ', '=')).countUntil(true);
      if(p0<=0) WARN("Invalid AMDB text format: "~line.quoted);
      const isItem = line[p0]=='=';
      Id id; id.deserializeText(line[0..p0]);
      line = line[p0+1..$];
      if(isItem){
        loadItem(id, autoUnquoted(line));
      }else{
        Link link;
        auto p = line.split(' ');
        enforce(p.length.among(2, 3), "Invalid link serialization format");
        link.sourceId                   .deserializeText(p[0]);
        link.verbId                     .deserializeText(p[1]);
        if(p.length==3) link.targetId   .deserializeText(p[2]);

        loadLink(id, link);
      }
    }
  }


  // translations /////////////////////////////////////////

  string inputTranslateVerb(string s){
    if(s=="is an") s="is a";
    return s;
  }


  // systemTypes //////////////////////////////////////////

  immutable allSystemTypes = ["Verb", "EType", "AType", "String", "Int", "Float", "DateTime"];

  auto systemTypeMap(){
    static int[string] m;
    if(!m){ foreach(idx, name; allSystemTypes) m[name] = cast(int)idx + 1; m.rehash; }
    return m;
  }

  int systemTypeIdx(string name){ return systemTypeMap.get(name, 0); }
  bool isSystemType(string name){ return (name in systemTypeMap)!is null; }

  // systemVerbs //////////////////////////////////////////

  immutable allSystemVerbs = ["is a"];

  auto systemVerbMap(){
    static int[string] m;
    if(!m){ foreach(idx, name; allSystemVerbs) m[name] = cast(int)idx + 1; m.rehash; }
    return m;
  }

  int systemVerbIdx(string name){ return systemVerbMap.get(name, 0); }
  bool isSystemVerb(string name){ return (name in systemVerbMap)!is null; }

  Id sysId(string name){
    if(auto id = itemId_get(name)) return id;
    if(isSystemVerb(name) || isSystemType(name)) return itemId_create(name);

    error("Invalid sysId name. Must be a systemVerb or a systemType. "~name.quoted);
    assert(0);
  }

  protected void verifyETypeName(string s){
    enforce(s.length, "Invalid entity name. Empty string. "~s.quoted);
    auto ch = s.decodeFront;
    enforce(ch.isLetter && ch==ch.toUpper, "Invalid entity name. Must start with a capital letter. "~s.quoted);
    enforce(!isSystemType(s), "Invalid entity name. Can't be a system type. "~s.quoted);
    enforce(!isSystemVerb(s), "Invalid entity name. Can't be a system verb. "~s.quoted);
  }

  protected void verifyVerbName(string s){
    enforce(s.length, "Invalid verb name. Empty string. "~s.quoted);
    auto olds = s; //todo: it's ugly
    auto ch = s.decodeFront;
    enforce(ch.isLetter && ch==ch.toLower, "Invalid verb name. Must start with a lower letter. "~olds.quoted);
    enforce(!isSystemType(s), "Invalid verb name. Can't be a system type. "~olds.quoted);
    enforce(!isSystemVerb(s), "Invalid verb name. Can't be a system verb. "~olds.quoted);
  }

  bool exists(S, V, T)(in S s, in V v, in T t){
    static if(is(S==Id)) auto si = s; else auto si = itemId_get(s);
    static if(is(V==Id)) auto vi = v; else auto vi = itemId_get(v);
    static if(is(T==Id)) auto ti = t; else auto ti = itemId_get(t);
    return (Link(si, vi, ti) in idByLink) !is null;
  }

  bool exists(S, V)(in S s, in V v){ return exists(s, v); }

  auto filter(S, V, T)(in S source, in V verb, in T target){
    bool test(in Link link){

      bool testOne(T)(in Id id, in T criteria){
        static if(isSomeString!T){
          if(!itemById.get(id).isWild(criteria)) return false;
        }else static if(is(Unqual!T == Id)){
          if(source && id != criteria) return false;
        }else static assert(0, "Invalid params");
        return true;
      }

      if(!testOne(link.sourceId, source)) return false;
      if(!testOne(link.verbId  , verb  )) return false;
      if(!testOne(link.targetId, target)) return false;
      return true;
    }

    return linkById.byKeyValue.filter!(a => test(a.value)).map!"a.key";
  }

  bool isAType(T)(in T a){ return exists(a, "is a", "AType"); }
  bool isEType(T)(in T a){ return exists(a, "is a", "EType"); }
  bool isVerb (T)(in T a){ return exists(a, "is a", "Verb" ); }

  bool isEntity(in Id id){ return filter(id, "is a", "*").any!(a => isEType(linkById[a].targetId)); }

  auto items(){ return itemById.keys; }
  auto links(){ return linkById.keys; }
  auto things(){ return chain(items, links); }
  auto verbs() { return filter("*", "is a", "Verb" ).map!(a => linkById[a].sourceId); }
  auto eTypes(){ return filter("*", "is a", "EType").map!(a => linkById[a].sourceId); }
  auto aTypes(){ return filter("*", "is a", "AType").map!(a => linkById[a].sourceId); }

  // create things /////////////////////////////

  protected Id createEType(string s){
    verifyETypeName(s);
    return itemId_create(s, (id){ linkId(id, sysId("is a"), sysId("EType")); }); //implicit "* is a EType"
  }

  protected Id resolveType(string s){
    if(isSystemType(s)) return sysId(s);

    if(auto id = itemId_get(s)) if(exists(id, "is a", "EType")) return id;

    if(autoCreateETypes){
      return createEType(s);
    }else{
      enforce(0, "Unknown type: "~s.quoted);
      return Id.init;
    }
  }

  protected Id createVerb(string s){
    verifyVerbName(s);
    return itemId_create(s, (id){ linkId(id, sysId("is a"), sysId("Verb"));} ); //implicit "* is a Verb"
  }

  protected Id resolveVerb(string s){
    if(isSystemVerb(s)) return sysId(s); //system verbs are not asserted

    if(auto id = itemId_get(s)) if(exists(id, "is a", "Verb")) return id;

    if(autoCreateVerbs){
      return createVerb(s);
    }else{
      enforce(0, "Unknown verb: "~s.quoted);
      return Id.init;
    }
  }

  protected Id createVerbAssertion(string name){
    enforce(name!="...", "Verb Assertion source can't be a \"...\" association.");
    enforce(!isSystemType(name), "Verb Assertion source can't be a SystemType: "~name.quoted);
    enforce(!isSystemVerb(name), "Verb Assertion source can't be a SystemVerb: "~name.quoted);
    return createVerb(name);
  }

  protected Id createETypeAssertion(string name){
    enforce(name!="...", "EType Assertion source can't be a \"...\" association.");
    enforce(!isSystemType(name), "EType Assertion source can't be a SystemType: "~name.quoted);
    enforce(!isSystemVerb(name), "EType Assertion source can't be a SystemVerb: "~name.quoted);
    return createEType(name);
  }

  protected Id createEntityAssertion(string name, string type){
    enforce(name!="...", "Entity assertion source can't be a \"...\" association.");

    enforce(!isSystemType(name), "Entity assertion source can't be a SystemType: "~name.quoted);
    enforce(!isSystemVerb(name), "Entity assertion source can't be a SystemVerb: "~name.quoted);
    enforce(!exists(name, "is a", "EType"), "Entity assertion source can't be an EType: "~name.quoted);
    enforce(exists(type, "is a", "EType"), "Entity assertion target must be an EType: "~type.quoted);

    return linkId(itemId_create(name), sysId("is a"), itemId_require(type));
  }

  // process //////////////////////////////

  /// Finds and collects "" quoted string literals and replaces them with a given string
  protected static string[] replaceQuotedStrings(ref string s, string replacement){
    string[] res;
    string processed, act = s;
    while(1){
      immutable quote = '"';
      auto idx = act.indexOf(quote);
      if(idx<0) break;

      processed ~= act[0..idx];
      act = act[idx..$];

      //find ending quote
      string qstr = act[0..1]; act = act[1..$];
      do{
        idx = act.indexOf(quote);
        if(idx<0) throw new Exception("Unterminated string literal.");
        qstr ~= act[0..idx+1];
        act = act[idx+1..$];
      }while(qstr.endsWith(`\"`));

      import het.tokenizer;
      Token[] tokens;
      auto error = tokenize("string literal tokenizer", qstr, tokens);
      if(error!="") throw new Exception("Error decoding string literal: "~error);
      enforce(tokens.length==1 && tokens[0].isString, "Error decoding string literal: String literal expected.");

      res ~= tokens[0].data.to!string;

      processed ~= replacement; //mark the position
    }
    processed ~= act;
    s = processed;
    return res;
  }

  static string[][] textToSentences(string input){

    auto quotedStrings = replaceQuotedStrings(input, `  "  `);
    string fetchQStr(){
      enforce(quotedStrings.length, "Quoted string literals: Array is empty.");
      return quotedStrings.fetchFront;
    }

    string[][] lineToSentences(string line){
      //strip at "..."
      auto p = line.strip.split("...").map!strip.array;

      //handle the first special case.
      foreach(i; 1..p.length) p[i] = "...  "~p[i]; //put back the "...", it will be processed later
      if(p.length && p[0]=="") p = p[1..$]; //is it allowed to start a new line with "...".

      //split the sentences to words. Separator is double space.
      string[] splitSentence(string s){
        return s.strip.split("  ").map!strip.filter!"a.length".map!(a => a==`"` ? fetchQStr : a).array; //todo: empty string encoded as ""
      }
      return p.map!(a => splitSentence(a)).array;
    }

    return input.splitLines.map!(line => lineToSentences(line)).join;
  }


  void processSchemaSentence(string[] p, ref Id id){
    enforce(p.length.among(2, 3), "Invalid sentence length: "~p.text);
    enforce(!id.isNull || p[0]!="...", "Last Id is null at sentence:"~p.text);

    p[1] = inputTranslateVerb(p[1]);

    if(isSystemVerb(p[1])){
      if(p[1]=="is a"){ //Verb and EType assertion
        enforce(p.length==3, "Assertion must have a target: "~p.text);

        switch(p.get(2)){
          case "Verb" : id = createVerbAssertion(p[0]); break;
          case "EType": id = createETypeAssertion(p[0]); break;
          default: enforce(0, "Invalid schema assertion: "~p.text);
        }
      }else{
        enforce(0, "Unhandled system verb in schema: "~p.text);
      }
    }else{
      //association type
      id = linkId(p[0]=="..." ? id : resolveType(p[0]),
                 resolveVerb(p[1]),
                 p.length>2 ? resolveType(p[2]) : Id.init);

      linkId(id, sysId("is a"), sysId("AType"));
    }
  }

  bool typeCheck(in Id typeId, string data){
    if(isItem(typeId)){
      const typeName = itemStr(typeId);
      if(isEType(typeId)){
        return isInstanceOf(data, typeId); //todo: supertypes
      }else if(isSystemType(typeName)){ //todo: slow
        switch(typeName){
          case "String": return true;
          case "Int": return data.to!int.collectException is null;
          case "DateTime": return data.DateTime.collectException is null;
          default:
        }
      }
    }

    error("Unhandled type: "~prettyStr(typeId)); //todo: prettyStr nem jo ide, mert az exceptionnal nincs szinezes
    return false;
  }

  protected Id[] findATypesForSentence(string[] p, in Id lastTypeId){

    enforce(p.length.among(2, 3), "Invalid sentence length: "~p.text);
    enforce(isVerb(p[1]), "Unknown verb: "~p.text);
    Id verbId = itemId_require(p[1]);
    Id[] res;
    foreach(aid, link; linkById) if(link.verbId==verbId) if(isAType(aid)){

      const sourceIsOk = p[0]=="..." && link.sourceId==lastTypeId || !isAType(link.sourceId) && typeCheck(link.sourceId, p[0]);
      if(!sourceIsOk) continue;

      const targetIsOk = p.length==2 && !link.targetId || p.length==3 && !isAType(link.targetId) && typeCheck(link.targetId, p[2]);
      if(!targetIsOk) continue;

      res ~= aid;
    }
    return res;
  }

  void processDataSentence(string[] p, ref Id tid, ref Id id){
    enforce(p.length.among(2, 3), "Invalid sentence length: "~p.text);
    enforce(!id.isNull || p[0]!="...", "Last Id is null at sentence:"~p.text);  //same until this point!!!!

    p[1] = inputTranslateVerb(p[1]);

    if(isSystemVerb(p[1])){
      if(p[1]=="is a"){ // Entity assertion
        enforce(p.length==3, "Entity assertion must have a target: "~p.text);
        id = createEntityAssertion(p[0], p[2]);
      }else{
        enforce(0, "Unhandled system verb in data: "~p.text);
      }
    }else{
      //association
      auto aTypes = findATypesForSentence(p, tid);
      if(aTypes.empty) error("Unable to find AType for: "~p.text);
      if(aTypes.length>1) error("Ambiguous ATypes found for for: "~p.text~" ["~aTypes.map!(a => prettyStr(a)).join(", ")~"]");

      id = linkId(p[0]=="..." ? id : itemId_create(p[0]),
                  itemId_require(p[1]),
                  p.length>2 ? itemId_create(p[2]) : Id.init);
      tid = aTypes[0];
    }
  }


  // multiline bulk processing
  private Id lastSchemaId;

  void schema(string input){
    lastDataTypeId = lastDataId = Id.init; //reset the state of other input categories

    foreach(s; textToSentences(input)) processSchemaSentence(s, lastSchemaId);
  }

  private Id lastDataId, lastDataTypeId;

  void data(string input){
    lastSchemaId = Id.init; //reset the state of other input categories

    foreach(s; textToSentences(input)) processDataSentence(s, lastDataTypeId, lastDataId);
  }

  Id[] query(string input){
    auto sentences = textToSentences(input);
    print(sentences);

    Id[] res;

    bool chkStr(string s, string mask){
      return s.isWild(mask);
    }

    bool chkId(in Id id, string mask){
      string s;
      if(!id) s = "null";
      else if(isItem(id)) s = itemStr(id);
      else if(isLink(id)) s = "...";
      else NOTIMPL;
      return chkStr(s, mask);
    }

    if(sentences.length==1){
      auto p = sentences[0];
      if(p.length==1){
        foreach(id, const item; itemById){
          if(chkStr(item, p[0])) res ~= id;
        }
      }else if(p.length==2){
        foreach(id, const link; linkById){
          if(!link.targetId && chkId(link.sourceId, p[0]) && chkId(link.verbId, p[1])) res ~= id;
        }
      }else if(p.length==3){
        foreach(id, const link; linkById){
          if(chkId(link.sourceId, p[0]) && chkId(link.verbId, p[1]) && chkId(link.targetId, p[2])) res ~= id;
        }
      }else NOTIMPL;
    }else if(sentences.length==2){
      //todo: recursive

      //todo: this should be the first parameter of a specialized query: it refines a list by sourceId match
      auto baseIds = query(sentences[0].join("  ")); //todo: don't join them again or use escaping!
      auto p = sentences[1];
      assert(p[0]=="...");
      if(p.length==2){
        foreach(baseId; baseIds){
          foreach(id, const link; linkById){
            if(link.sourceId==baseId && !link.targetId && chkId(link.verbId, p[1])) res ~= id;
          }
        }
      }else if(p.length==3){
        foreach(baseId; baseIds){
          foreach(id, const link; linkById){
            if(link.sourceId==baseId && chkId(link.verbId, p[1]) && chkId(link.targetId, p[2])) res ~= id;
          }
        }
      }else NOTIMPL;
    }else NOTIMPL;

    return res;
  }

  // text mode interface ////////////////////////////////////////////

  private char textCommandMode = 'q';

  int execTextCommand(string input){
    input = input.strip;
    try{
      switch(input){
        case "data": case "d": case "schema": case "s": case "query": case "q": textCommandMode = input[0]; break;
        case "commit": commit; break;
        case "cancel": cancel; break;

        case "info":
        break;

        case "exit": case "x":{
          enforce(!inTransaction, "Pending transaction. Use \"commit\" or \"cancel\" before exiting.");
          return false;
        }
        default:
          switch(textCommandMode){
            case 's': schema(input); break;
            case 'd': data(input); break;
            case 'q': query(input).sort.each!(i => print(prettyStr(i))); break;
            default: raise("invalid mode: "~textCommandMode);
          }
      }
    }catch(Exception e){
      print(EgaColor.ltRed("ERROR:"), e.simpleMsg);
    }

    writeln;
    return true;
  }

  string inputTextCommand(){
    //prompt
    write(EgaColor.white(">"), format!" I:%d + L:%d = %d %s"(itemCount, linkCount, itemCount+linkCount, commitBuffer.length ? EgaColor.red("*"~commitBuffer.length.text~" ") : ""));

    switch(textCommandMode){
      case 's': write(EgaColor.ltMagenta("schema ")); break;
      case 'd': write(EgaColor.ltBlue   ("data ")); break;
      case 'q': write(EgaColor.ltGreen  ("query ")); break;
      default: raise("invalid mode");
    }
    write(EgaColor.white("> "));

    return readln;
  }

  void textCommandLoop(){
    while(execTextCommand(inputTextCommand)){}
  }

}

//! Unittest //////////////////////////////////////

void unittest_splitSentences(){
  uint h;
  void a(string s){
    auto r = AMDB.textToSentences(s).text; h = r.xxh(h);
    //print(s, "|", r);
  }

  a("One part");
  a("Part one  Part two");
  a("Part 1  Part 2     Part 3");
  a("Part 1  Part 2  Part 3  Part 4");

  a("One part...2nd sentence.");
  a("Part one  Part two...2nd");
  a("Part 1  Part 2     Part 3  ...  2nd");

  a("Part one  Part two\n...2nd");

  a("Part one  Part two\nNew     sentence  ...next");

  a(`a"c"d"e  e"..."f  f\""""g`);   //c style "" string literals are decoded as a word.

  //print(h);
  enforce(h==1522071754, "AMDB.textToSentences test FAIL");
}

void unittest_main(){
  unittest_splitSentences;
}