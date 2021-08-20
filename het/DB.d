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
  enum versionStr = "1.00";

  private uint lastIdIndex;
  Items items;
  Links links;

  private DBFileInterface dbFileInterface;

  bool autoCreateETypes   = true ,
       autoCreateVerbs    = true ,
       autoCreateEntities = false;

  //----------------------------------------------------------------------------------

  this(){
    items.db = links.db =this;

    //do critical unittests
    __gshared static bool tested;
    if(tested.chkSet) unittest_splitSentences;
  }

  this(DBFileInterface dbFileInterface){
    this();

    this.dbFileInterface = dbFileInterface;

    load;
  }

  this(File file){ this(new TextDBFile(file)); }
  this(string fileName){ this(File(fileName)); }

  //clear all the internal data. Does not change the dbFile.
  private void clear(){
    lastIdIndex = 0;
    links.clear;
    items.clear;
  }

  File file(){ return dbFileInterface ? dbFileInterface.file : File(""); }

  void error(string s) const{ throw new AMDBException(s); }

  static string autoQuoted(string s){
    //todo: slow
    if(s.canFind!(ch => ch<32 || ch.among('"', '\'', '`', '\\')) || s.canFind("  ") || s.canFind("..."))return s.quoted;
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

    bool valid() const { return id!=0; }
    bool opCast(B: bool)() const { return valid; }

    size_t toHash() const @safe pure nothrow{ return id; }
    bool opEquals(ref const Id b) const @safe pure nothrow{ return id==b.id; }

    string toString() const { return id.text; }

    long opCmp(in Id b) const{ return long(id)-long(b.id); }

    string serializeText() const{ return id.to!string(10); }
    void deserializeText(string s){ id = s.to!uint(10); }
  }

  private Id _internal_generateNextId(){ return Id(++lastIdIndex); }

  /// When an item is loaded
  private void _internal_maximizeNextId(in Id id){ lastIdIndex.maximize(id.id); }

  // Items /////////////////////////////

  struct Items{
    private AMDB db;
    private string[Id] byId;
    private Id[string] byItem;

    // data access -------------------------------------------

    auto ids(){ return byId.keys; }
    auto strings(){ return byItem.keys; }

    auto count() const{ return byId.length; }

    string get(in Id id                 ) const{ if(auto a = id in byId) return *a; else return "" ; }
    string get(in Id id, lazy string def) const{ if(auto a = id in byId) return *a; else return def; }

    string require(in Id id                 ) const{ if(auto a = id in byId) return *a; else{ db.error(format!"Required id %s not found."   (id     )); assert(0); } }
    string require(in Id id, lazy string msg) const{ if(auto a = id in byId) return *a; else{ db.error(format!"Required id %s not found. %s"(id, msg)); assert(0); } }

    Id get(string str             ) const{ if(auto a = str in byItem) return *a; else return Id.init; }
    Id get(string str, lazy Id def) const{ if(auto a = str in byItem) return *a; else return def    ; }

    Id require(string str                 ) const{ if(auto a = str in byItem) return *a; else{ db.error(format!"Required item %s not found."   (str.quoted     )); assert(0); } }
    Id require(string str, lazy string msg) const{ if(auto a = str in byItem) return *a; else{ db.error(format!"Required item %s not found. %s"(str.quoted, msg)); assert(0); } }

    auto opBinaryRight(string op)(in Id id) if(op=="in"){

      struct ItemResult{
        string str;
        bool valid;
        alias str this;
        bool opCast(B : bool)() const{ return valid; }
      }

      if(auto a = id in byId) return ItemResult(*a, true); else return ItemResult.init;
    }

    Id opBinaryRight(string op)(string str) if(op=="in"){ return get(str); }

    string opIndex(in Id id) const{ return require(id); }
    Id opIndex(string str) const{ return require(str); }

    // data manipulation -------------------------------------------------------

    //inserts into the lists, called by itemId_create and importItem
    private void _internal_createItem(in Id id, string name){
      byItem[name] = id;
      byId[id] = name;
    }

    private bool _internal_tryRemoveItem(in Id id){
      if(auto item = id in this){
        byId.remove(id);
        byItem.remove(item);
        return true;
      }
      return false;
    }

    private void clear(){ byId = null; byItem = null; }

    private Id create(string name, void delegate(Id) afterCreate = null){
      auto id = get(name);
      if(id) return id;

      id = db._internal_generateNextId;
      _internal_createItem(id, name);
      db.onItemCreated(id);
      if(afterCreate) afterCreate(id);
      return id;
    }

    private void load(in Id id, string data){
      if(!id) db.error("Invalid null id");
      if(id in db.links) db.error(format!"Load error: Item id already exists as a link. id=%s old=%s new=%s"(id, db.toStr(id), data));
      if(auto existing = id in this){
        if(existing==data) return; //already loaded, id is the same
        db.error(format!"Load error: Id already exists with different item data. id=%s old=%s new=%s"(id, db.toStr(id), data));
      }
      //id is free, check duplicated data
      if(get(data)) format!"Load error: Item already exists with different id. new=%s"(data);

      //good to go, create it
      db._internal_maximizeNextId(id);
      _internal_createItem(id, data);
    }
  }

  // Links //////////////////////////////////////

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

    bool valid() const { return sourceId.valid && verbId.valid; }
    bool opCast(B : bool)() const{ return valid; }
  }

  struct Links{
    private AMDB db;
    private Link[Id] byId;
    private Id[Link] byLink;

    // data access -------------------------------------------

    auto ids(){ return byId.keys; }
    auto links(){ return byLink.keys; }

    auto count() const{ return byId.length; }

    Link get(in Id id               ) const{ if(auto a = id in byId) return *a; else return Link.init; }
    Link get(in Id id, lazy Link def) const{ if(auto a = id in byId) return *a; else return def      ; }

    Link require(in Id id                 ) const{ if(auto a = id in byId) return *a; else{ db.error(format!"Required link %s not found."   (id     )); assert(0); } }
    Link require(in Id id, lazy string msg) const{ if(auto a = id in byId) return *a; else{ db.error(format!"Required link %s not found. %s"(id, msg)); assert(0); } }

    Id get(in Link link               ) const{ if(auto a = link in byLink) return *a; else return Id.init; }
    Id get(in Link link, lazy Id defId) const{ if(auto a = link in byLink) return *a; else return defId  ; }

    Id get(in Id sourceId, in Id verbId                ) const{ return get(Link(sourceId, verbId          )); }
    Id get(in Id sourceId, in Id verbId, in Id targetId) const{ return get(Link(sourceId, verbId, targetId)); }

    Id require(in Link link                 ) const{ if(auto a = link in byLink) return *a; else{ db.error(format!"Required link %s not found."   (link     )); assert(0); } }
    Id require(in Link link, lazy string msg) const{ if(auto a = link in byLink) return *a; else{ db.error(format!"Required link %s not found. %s"(link, msg)); assert(0); } }

    Id require(in Id sourceId, in Id verbId                ) const{ return require(Link(sourceId, verbId          )); }
    Id require(in Id sourceId, in Id verbId, in Id targetId) const{ return require(Link(sourceId, verbId, targetId)); }

    auto opBinaryRight(string op)(in Id id) if(op=="in"){ return get(id); }
    Id opBinaryRight(string op)(in Link link) if(op=="in"){ return get(link); }

    Link opIndex(in Id id) const{ return require(id); }
    Id opIndex(in Link link) const{ return require(link); }

    // data manipulation -------------------------------------------------------

    private void _internal_createLink(in Id id, in Link link){
      byId[id] = link;
      byLink[link] = id;
    }

    bool _internal_tryRemoveLink(in Id id){
      if(auto link = id in this){
        byId.remove(id);
        byLink.remove(link);
        return true;
      }
      return false;
    }

    private void clear(){ byId = null; byLink = null; }

    private Id create(in Id sourceId, in Id verbId, in Id targetId=Id.init){
      auto link = Link(sourceId, verbId, targetId);
      auto id = get(link);
      if(id) return id; //access if can

      id = db._internal_generateNextId;
      _internal_createLink(id, link);
      db.onLinkCreated(id);

      return id;
    }

    private void load(in Id id, in Link data){
      if(!id) db.error("Invalid null id");
      if(id in db.items) db.error(format!"Load error: Link id already exists as an item. id=%s old=%s new=%s"(id, db.toStr(id), data));
      if(auto link = id in this){
        if(link==data) return; //already loaded, id is the same
        db.error(format!"Load error: Id already exists with different link data. id=%s old=%s new=%s"(id, db.toStr(id), data));
      }
      //id is free, check duplicated data
      if(get(data)) format!"Load error: Link already exists with different id. new=%s"(data);

      //good to go, create it
      db._internal_maximizeNextId(id);
      _internal_createLink(id, data);
    }


  }

  // toStr //////////////////////////////////////////////////////////////////

  string toStr(in Id id, int recursion=0){
    if(!id) return "Null";
    if(auto item = id in items) return format!"Item(%s, %s)"(id, (item).quoted);
    if(auto link = id in links) with(link){
      if(recursion-->0){
        return format!"Link(%s, %s, %s, %s)"(id, toStr(sourceId, recursion), toStr(verbId, recursion), toStr(targetId, recursion));
      }else{
        return format!"Link(%s, %s, %s, %s)"(id, sourceId, verbId, targetId);
      }
    }
    return format!"Unknown(%s)"(id);
  }

  string colorizeItem(in Id id){
    return colorizeItem(items.get(id, id.text));
  }

  string colorizeItem(string s){
    if(isSystemVerb(s)) return EgaColor.ltWhite(s);
    if(isSystemType(s)) return EgaColor.ltGreen(s);

    if(auto id = s in items){
      if(isVerb(id)) return EgaColor.yellow(s);
      if(isEType(id)) return EgaColor.ltMagenta(s);
      if(isEntity(id)) return EgaColor.ltBlue(s);
    }
    return s;
  }

  ///this is an old version... Should use the new one below...
  /*string prettyStr(in Id id, bool recursion=true){
    if(!id) return "Null";
    if(auto item = id in items){
      string s = colorizeItem(autoQuoted(item));
      return recursion ? format!"%s : %s"(id, s) : s;
    }
    if(auto link = id in links) with(link){
      return recursion ? format!"%s : %s  %s  %s"(id, prettyStr(sourceId, false), prettyStr(verbId, false), prettyStr(targetId, false))
                       : format!"...%s"(id);
    }
    return format!"Unknown(%s)"(id);
  }*/

  string prettyStr(in Id id, bool recursion=true){
    if(!id) return "Null";
    if(auto item = id in items){
      return colorizeItem(autoQuoted(item));
    }
    if(auto link = id in links) with(link){
      return recursion ? format!"%s  %s  %s"(prettyStr(sourceId, false), prettyStr(verbId, false), prettyStr(targetId, false))
                       : "...";
    }
    return format!"Unknown(%s)"(id);
  }

  string prettyStr(in IdSequence seq){
    return seq.ids.map!(i => prettyStr(i, true)).join("  ");
  }

  bool isInstanceOf(string entity, in Id eTypeId){
    return exists(entity, "is a", eTypeId); //todo: "has supertype" handling
  }

  // Delete, modify (no commit handling)///////////////////////////////////////////////////

  auto referrers(Flag!"source" chkSource = Yes.source, Flag!"verb" chkVerb = Yes.verb, Flag!"target" chkTarget = Yes.target, alias retExpr="a.key")(in Id id){
    return links.byId.byKeyValue.filter!(a => chkSource && a.value.sourceId==id
                                           || chkVerb   && a.value.verbId  ==id
                                           || chkTarget && a.value.targetId==id).map!retExpr;
  }

  auto sourceReferrers(in Id id){ return referrers!(Yes.source, No .verb, No .target)(id); }
  auto verbReferrers  (in Id id){ return referrers!(No .source, Yes.verb, No .target)(id); }
  auto targetReferrers(in Id id){ return referrers!(No .source, No .verb, Yes.target)(id); }

  bool hasReferrers(in Id id){
    if(!id) return false;
    return !referrers(id).empty;
  }

  auto allReferrers(Flag!"source" chkSource = Yes.source, Flag!"verb" chkVerb = Yes.verb, Flag!"target" chkTarget = Yes.target, alias retExpr="a.key")(in Id id){
    bool[Id] found;

    void doit(in Id id){
      foreach(r; referrers!(chkSource, chkVerb, chkTarget, retExpr)(id)) if(r !in found){
        found[r]=true;
        doit(r);
      }
    }
    doit(id);

    return found.keys.sort.array;
  }

  auto allSourceReferrers(in Id id){ return referrers!(Yes.source, No .verb, No .target)(id); }
  auto allTargetReferrers(in Id id){ return referrers!(No .source, No .verb, Yes.target)(id); }


  void deleteThing(in Id id){
    if(!id) return; //no need to delete null
    enforce(!hasReferrers(id), "Can't delete, because it has rteferences:  "~prettyStr(id));
    if(items._internal_tryRemoveItem(id) || links._internal_tryRemoveLink(id)) return;
    raise("Can't delete thing. Id not found: "~id.text);
  }

  void _internal_replaceLink(in Id linkId, in Link oldLink, in Link newLink){
    links.byLink.remove(oldLink);
    links.byId[linkId] = newLink;
    links.byLink[newLink] = linkId;
  }

  void changeTargetTo(in Id linkId, in Id newTargetId){
    const oldLink = enforce(linkId in links, "CTT: Link not found: "~linkId.text);

    if(oldLink.targetId==newTargetId) return; //nothing changed
    const newLink = Link(oldLink.sourceId, oldLink.verbId, newTargetId);

    //check is the modified link already exists.
    const existingLinkId = newLink in links;
    if(existingLinkId) raise("CTT: modified link already exists: "~prettyStr(existingLinkId));

    //update the internal state
    _internal_replaceLink(linkId, oldLink, newLink);
  }

  // Central notification handling ////////////////////////////

  //called after create but not when loading
  void onItemCreated(in Id id){
    commitBuffer ~= serializeText(id);
    cancelBuffer ~= '~'~id.serializeText;
  }

  //called after create but not when loading
  void onLinkCreated(in Id id){
    commitBuffer ~= serializeText(id);
    cancelBuffer ~= '~'~id.serializeText;
  }

  // Commit buffer ////////////////////

  private string[] commitBuffer, cancelBuffer;

  bool inTransaction(){ return commitBuffer.length>0; }

  void commit(){
    if(!inTransaction) return;

    if(dbFileInterface)
      dbFileInterface.appendLines(commitBuffer); //todo: transaction header/footer

    commitBuffer = null;
    cancelBuffer = null;
  }

  void cancel(){
    if(!inTransaction) return;
    enforce(cancelBuffer.length == commitBuffer.length, "Cancel/commit buffer inconsistency: " ~ cancelBuffer.length.text ~ "!=" ~ commitBuffer.length.text);

    while(cancelBuffer.length){
      auto s = cancelBuffer[$-1];
      try{
        if(s.startsWith('~')){
          Id id;  id.deserializeText(s[1..$]);
          deleteThing(id);
        }else NOTIMPL;
      }finally{
        cancelBuffer = cancelBuffer[0..$-1];
        commitBuffer = commitBuffer[0..$-1];
      }
    }
  }

  // serialization ////////////////////////////////////////////

  string serializeText(in Id id){
    if(auto link = id in links){
      with(link) return id.serializeText ~" "~ sourceId.serializeText ~" "~ verbId.serializeText ~(targetId ? " "~targetId.serializeText : "");
    }else if(auto item = id in items){
      auto s = autoQuoted(item);
      //string is closed with newLine.  Only need to escape when it contains newLine or starts with the escape quote. But to make sure, escape it if it contains any special chars
      return id.serializeText~"="~s;
    }else error("Invalid Id to serialize:"~id.text);
    assert(0);
  }

  string serializeText(R)(in R r){ return r.map!(i => serializeText(i)~"\n").join; }

  void deserializeLine(string line){
    line = line.strip;
    if(line=="") return;
    const idx = line.map!(ch => ch==' ' || ch=='=').countUntil(true);
    enforce(idx>0, "Invalid text db line format: "~line.quoted);

    //get Id
    const id = Id(line[0..idx].to!uint);
    const lineType = line[idx];
    line = line[idx+1..$];

    switch(lineType){
      case '=':{ //Item
        items.load(id, autoUnquoted(line));
      }break;
      case ' ':{
        auto p = line.split(' ').map!(a => Id(a.to!uint)).array;
        enforce(p.length.among(2, 3), "Invalid link id count. "~line.quoted);
        if(p.length==2) p ~= Id.init;
        foreach(a; p) enforce(!a || a in items || a in links, "Invalid link id: "~a.text~" "~line.quoted);
        links.load(id, Link(p[0], p[1], p[2]));
      }break;
      default: raise("Unknown lineType. "~line.quoted);
    }
  }

  private void load(){
    try{
      clear;
      if(dbFileInterface) foreach(line; dbFileInterface.readLines) deserializeLine(line);
    }catch(Exception e){
      raise("AMDB load error: "~e.simpleMsg);
    }
  }


  // translations /////////////////////////////////////////

  string inputTranslateVerb(string s){
    if(s=="is an") s="is a";
    return s;
  }


  // systemTypes //////////////////////////////////////////

  immutable allSystemTypes = ["Verb", "EType", "AType", "String", "Int", "Float", "DateTime", "Date", "Time"];

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
    if(auto id = name in items) return id;
    if(isSystemVerb(name) || isSystemType(name)) return items.create(name);

    error("Invalid sysId name. Must be a systemVerb or a systemType. "~name.quoted);
    assert(0);
  }

  private void verifyETypeName(string s){
    enforce(s.length, "Invalid entity name. Empty string. "~s.quoted);
    auto ch = s.decodeFront;
    enforce(ch.isLetter && ch==ch.toUpper, "Invalid entity name. Must start with a capital letter. "~s.quoted);
    enforce(!isSystemType(s), "Invalid entity name. Can't be a system type. "~s.quoted);
    enforce(!isSystemVerb(s), "Invalid entity name. Can't be a system verb. "~s.quoted);
  }

  private void verifyVerbName(string s){
    enforce(s.length, "Invalid verb name. Empty string. "~s.quoted);
    auto olds = s; //todo: it's ugly
    auto ch = s.decodeFront;
    enforce(ch.isLetter && ch==ch.toLower, "Invalid verb name. Must start with a lower letter. "~olds.quoted);
    enforce(!isSystemType(s), "Invalid verb name. Can't be a system type. "~olds.quoted);
    enforce(!isSystemVerb(s), "Invalid verb name. Can't be a system verb. "~olds.quoted);
  }

  bool exists(S, V, T)(in S s, in V v, in T t){
    static if(is(S==Id)) auto si = s; else auto si = s in items;
    static if(is(V==Id)) auto vi = v; else auto vi = v in items;
    static if(is(T==Id)) auto ti = t; else auto ti = t in items;
    return (Link(si, vi, ti) in links).valid; //this is fast
  }

  bool exists(S, V)(in S s, in V v){ return exists(s, v, Id.init); }

  auto filter(S, V, T)(in S source, in V verb, in T target){
    bool test(in Link link){

      bool testOne(T)(in Id id, in T criteria){
        static if(isSomeString!T){
          if(!items.get(id).isWild(criteria)) return false;
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

    return links.byId.byKeyValue.filter!(a => test(a.value)).map!"a.key";
  }

  bool isAType(T)(in T a){ return exists(a, "is a", "AType"); }
  bool isEType(T)(in T a){ return exists(a, "is a", "EType"); }
  bool isVerb (T)(in T a){ return exists(a, "is a", "Verb" ); }

  bool isEntity(in Id id){ return filter(id, "is a", "*").any!(a => isEType(links[a].targetId)); }

  auto things()  { return chain(items.ids, links.ids); }
  auto verbs()   { return filter("*", "is a", "Verb" ).map!(a => links[a].sourceId); }
  auto eTypes()  { return filter("*", "is a", "EType").map!(a => links[a].sourceId); }
  auto aTypes()  { return filter("*", "is a", "AType").map!(a => links[a].sourceId); }

  auto entities()           { return eTypes                             .map!(e => filter("*", "is a", e).map!(e => links.get(e).sourceId)).join; }
  auto entities(string mask){ return eTypes.filter!(e => chkId(e, mask)).map!(e => filter("*", "is a", e).map!(e => links.get(e).sourceId)).join; }


  bool isSchema(in Id id){
    if(auto link = id in links) if(items.get(link.verbId)=="is a" || isAType(id)) return true;
    return false;
  }

  // create things /////////////////////////////

  private Id createEType(string s){
    verifyETypeName(s);
    return items.create(s, (id){ links.create(id, sysId("is a"), sysId("EType")); }); //implicit "* is a EType"
  }

  private Id resolveType(string s){
    if(isSystemType(s)) return sysId(s);

    if(auto id = s in items) if(exists(id, "is a", "EType")) return id;

    if(autoCreateETypes){
      return createEType(s);
    }else{
      enforce(0, "Unknown type: "~s.quoted);
      return Id.init;
    }
  }

  private Id createVerb(string s){
    verifyVerbName(s);
    return items.create(s, (id){ links.create(id, sysId("is a"), sysId("Verb"));} ); //implicit "* is a Verb"
  }

  private Id resolveVerb(string s){
    if(isSystemVerb(s)) return sysId(s); //system verbs are not asserted

    if(auto id = s in items) if(exists(id, "is a", "Verb")) return id;

    if(autoCreateVerbs){
      return createVerb(s);
    }else{
      enforce(0, "Unknown verb: "~s.quoted);
      return Id.init;
    }
  }

  private Id createVerbAssertion(string name){
    enforce(name!="...", "Verb Assertion source can't be a \"...\" association.");
    enforce(!isSystemType(name), "Verb Assertion source can't be a SystemType: "~name.quoted);
    enforce(!isSystemVerb(name), "Verb Assertion source can't be a SystemVerb: "~name.quoted);
    return createVerb(name);
  }

  private Id createETypeAssertion(string name){
    enforce(name!="...", "EType Assertion source can't be a \"...\" association.");
    enforce(!isSystemType(name), "EType Assertion source can't be a SystemType: "~name.quoted);
    enforce(!isSystemVerb(name), "EType Assertion source can't be a SystemVerb: "~name.quoted);
    return createEType(name);
  }

  private Id createEntityAssertion(string name, string type){
    enforce(name!="...", "Entity assertion source can't be a \"...\" association.");

    enforce(!isSystemType(name), "Entity assertion source can't be a SystemType: "~name.quoted);
    enforce(!isSystemVerb(name), "Entity assertion source can't be a SystemVerb: "~name.quoted);
    enforce(!exists(name, "is a", "EType"), "Entity assertion source can't be an EType: "~name.quoted);
    enforce(exists(type, "is a", "EType"), "Entity assertion target must be an EType: "~type.quoted);

    return links.create(items.create(name), sysId("is a"), items[type]);
  }

  // process //////////////////////////////

  /// Finds and collects "" quoted string literals and replaces them with a given string
  private static string[] replaceQuotedStrings(ref string s, string replacement){
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
    enforce(id || p[0]!="...", "Last Id is null at sentence:"~p.text);

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
      id = links.create(p[0]=="..." ? id : resolveType(p[0]),
                        resolveVerb(p[1]),
                        p.length>2 ? resolveType(p[2]) : Id.init);

      links.create(id, sysId("is a"), sysId("AType"));
    }
  }

  bool typeCheck(in Id typeId, string data){
    if(const typeName = typeId in items){
      if(isEType(typeId)){
        return isInstanceOf(data, typeId); //todo: supertypes
      }else if(isSystemType(typeName)){ //todo: slow
        switch(typeName){
          case "String": return true;
          case "Int": return data.to!int.collectException is null;
          case "DateTime": return data.DateTime.collectException is null;
          case "Date": return data.Date.collectException is null;
          case "Time": return data.Time.collectException is null;
          default:
        }
      }
    }

    error("Unhandled type: "~prettyStr(typeId)); //todo: prettyStr nem jo ide, mert az exceptionnal nincs szinezes
    return false;
  }

  private Id[] findATypesForSentence(string[] p, in Id lastTypeId){

    enforce(p.length.among(2, 3), "Invalid sentence length: "~p.text);
    enforce(isVerb(p[1]), "Unknown verb: "~p.text);
    Id verbId = items[p[1]];
    Id[] res;
    foreach(aid, link; links.byId) if(link.verbId==verbId) if(isAType(aid)){

      const sourceIsOk = p[0]=="..." && link.sourceId==lastTypeId || !isAType(link.sourceId) && typeCheck(link.sourceId, p[0]);
      if(!sourceIsOk) continue;

      const targetIsOk = p.length==2 && !link.targetId || p.length==3 && !isAType(link.targetId) && typeCheck(link.targetId, p[2]);
      if(!targetIsOk) continue;

      res ~= aid;
    }
    return res;
  }

  private bool walkToSourceAType(ref Id id){
    if(auto link = id in links) if(isAType(link.sourceId)){
        id = link.sourceId;
        return true;
      }
    return false;
  }

  private bool walkToSourceLink(ref Id id){
    if(auto link = id in links) if(link.sourceId in links){
        id = link.sourceId;
        return true;
      }
    return false;
  }

  void processDataSentence(string[] p, ref Id tid, ref Id id){
    enforce(p.length.among(2, 3), "Invalid sentence length: "~p.text);
    enforce(id || p[0]!="...", "Last Id is null at sentence:"~p.text);  //same until this point!!!!

    p[1] = inputTranslateVerb(p[1]);

    if(isSystemVerb(p[1])){
      if(p[1]=="is a"){ // Entity assertion
        enforce(p.length==3, "Entity assertion must have a target: "~p.text);
        id = createEntityAssertion(p[0], p[2]);
      }else{
        enforce(0, "Unhandled system verb in data: "~p.text);
      }
    }else{ //association
      //find a valid atype for this sentence. Try to step back to sourceId if that is an atype.
      Id[] aTypes;
      auto tempTid = tid, tempId = id;
      do{
        aTypes = findATypesForSentence(p, tempTid);
      }while(aTypes.empty && p[0]=="..." && walkToSourceAType(tempTid) && walkToSourceLink(tempId));

      //check if exactly one type found
      if(aTypes.empty) error("Unable to find AType for: "~p.text);
      if(aTypes.length>1) error("Ambiguous ATypes found for for: "~p.text~" ["~aTypes.map!(a => prettyStr(a)).join(", ")~"]");

      //ok to go. Actualize current id and tid after a possible step-back
      id = tempId;
      tid = tempTid;

      //create the link
      id = links.create(p[0]=="..." ? id : items.create(p[0]),
                        items[p[1]],
                        p.length>2 ? items.create(p[2]) : Id.init);
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

  /// own version of wildcard check specialized to AMDB
  private bool chkStr(string s, string mask){
    return s.isWild(mask);
  }

  private bool chkId(in Id id, string mask){
    string s;
    if(!id) s = "null";
    else if(auto a = id in items) s = a;
    else if(id in links) s = "...";
    else NOTIMPL;
    return chkStr(s, mask);
  }

  Id[] query(string[] p){ //works on a single sentence
    Id[] res;
    if(p.length==1){
      foreach(id, const link; links.byId){
        if(chkId(link.sourceId, p[0]) || chkId(link.verbId, p[0]) || chkId(link.targetId, p[0])) res ~= id; // x  ->  x can be at any place
      }
    }else if(p.length==2){
      foreach(id, const link; links.byId){
        if(!link.targetId && chkId(link.sourceId, p[0]) && chkId(link.verbId, p[1])) res ~= id; // target must be null
      }
    }else if(p.length==3){
      foreach(id, const link; links.byId){
        if(chkId(link.sourceId, p[0]) && chkId(link.verbId, p[1]) && chkId(link.targetId, p[2])) res ~= id;
      }
    }else NOTIMPL;
    return res;
  }

  /// Extends srcIds with referencing child links. Sentence must start with "..."
  Id[] query(Id[] sourceIds, string[] p){
    Id[] res;
    enforce(p.length.among(2, 3), `Invalid sentence for srcId based query. Invalid sentence length. `~p.text);
    enforce(p.get(0)=="...", `Invalid sentence for srcId based query. Source must be "...". `~p.text);
    if(p.length==2){
      foreach(sourceId; sourceIds){
        foreach(id, const link; links.byId){
          /* if(link.sourceId==sourceId && !link.targetId && chkId(link.verbId, p[1])) res ~= id; */
          if(link.sourceId==sourceId && (chkId(link.verbId, p[1]) || chkId(link.targetId, p[1]))) res ~= id;  // ...x  ->  x can be at any place
        }
      }
    }else if(p.length==3){
      foreach(sourceId; sourceIds){
        foreach(id, const link; links.byId){
          if(link.sourceId==sourceId && chkId(link.verbId, p[1]) && chkId(link.targetId, p[2])) res ~= id;
        }
      }
    }
    return res;
  }

  /// Extends srcIds with referencing child links. generalized recursive version, works with more than one sentence
  Id[] query(Id[] sourceIds, string[][] sentences){
    while(sentences.length) sourceIds = query(sourceIds, sentences.fetchFront);
    return sourceIds;
  }

  Id[] query(string[][] sentences){ //works on sentences
    Id[] res;

    if(sentences.length==0) return null; //empty query
    if(sentences.length==1) return query(sentences[0]); //one sentence
    return query(query(sentences[0]), sentences[1..$]); //many sentences in a chain
  }

  Id[] query(string input){
    return query(textToSentences(input));
  }

  static struct IdSequence{
    Id[] ids;
    alias ids this;
  }

  // extendLeft //////////////////////////////////////////////////////////

  private enum defaultExtendLeftRecursion = int.max;

  IdSequence extendLeft(IdSequence seq, int recursion=defaultExtendLeftRecursion){
    foreach(i; 0..recursion){
      if(seq.length)
        if(auto link = seq[0] in links.byId)
          if(link.sourceId in links){
            seq = IdSequence(link.sourceId ~ seq.ids);
            continue;
          }
      break;
    }
    return seq;
  }

  IdSequence extendLeft(Id id, int recursion=defaultExtendLeftRecursion){ return extendLeft(IdSequence([id]), recursion); }

  IdSequence[] extendLeft(IdSequence[] seqs, int recursion=defaultExtendLeftRecursion){ return seqs.map!(s => extendLeft(s, recursion)).array; }

  IdSequence[] extendLeft(Id[] ids, int recursion=defaultExtendLeftRecursion){ return ids.map!(i => extendLeft(i, recursion)).array; }

  // extendRight //////////////////////////////////////////////////////////

  Id[] linksBySourceId(in Id sourceId){
    Id[] res;
    foreach(id, const link; links.byId)
      if(link.sourceId==sourceId) res ~= id;
    return res.sort.array;
  }

  Id[] linksBySourceId_recursive(in Id sourceId){
    return linksBySourceId(sourceId).map!(i => i ~ linksBySourceId_recursive(i)).join;
  }

  IdSequence extendRight(IdSequence seq){
    return seq.length ? IdSequence(seq.ids ~ linksBySourceId_recursive(seq[$-1])) : seq;
  }

  IdSequence[] extendRight(IdSequence[] seq){
    return seq.map!(s => extendRight(s)).array;
  }

  // text mode interface ////////////////////////////////////////////

  void printFilteredSortedItems(R)(R r, string mask=""){
    r.filter!(i => mask=="" || chkId(i, mask)).array.sort!((a,b)=>icmp(items.get(a, ""), items.get(b, ""))<0).each!(i => print(prettyStr(i)));
  }

  //private char textCommandMode = 'q';

  int execTextCommand(string input){
    input = input.strip;
    try{
      string cmd = input.wordAt(0);
      input = input[cmd.length..$].strip;

      switch(cmd.lc){
        case "id": print(prettyStr(extendLeft(Id(input.to!uint)))); break;

        case "s", "schema": schema(input); break;
        case "d", "data": data(input); break;
        case "q", "query":{
          const eRight = input.endsWith  ("...");  if(eRight) input = input.withoutEnding  ("...");
          const eLeft  = input.startsWith("...");  if(eLeft ) input = input.withoutStarting("...");
          foreach(id; query(input).sort){
            auto seq = IdSequence([id]);
            if(eRight) seq = extendRight(seq);
            if(eLeft) seq = extendLeft(seq);
            print(prettyStr(seq));
          }
        }break;

        case "items"   : printFilteredSortedItems(items.ids, input); break;
        case "etypes"  : printFilteredSortedItems(eTypes   , input); break;
        case "verbs"   : printFilteredSortedItems(verbs    , input); break;
        case "entities": printFilteredSortedItems(entities(input=="" ? "*" : input)); break;

        case "commit": commit; break;
        case "cancel": cancel; break;

        case "info":
          print("Engine     : AMDB", versionStr);
          print("  Built    :", DateTime(__TIMESTAMP__).timestamp);
          writeln;
          print("File       :", file.fullName);
          print("  Size     :", format!"%.1f"(file.size/1024.0), "KB");
          print("  Created  :", file.created.timestamp);
          print("  Modified :", file.modified.timestamp);
          print("  Accessed :", file.accessed.timestamp);
          print("  Now      :", now.timestamp);
          writeln;
          const itemBytes = items.ids.map!(i => serializeText(i).length+1).sum; writefln!"Items: %8d %8.1f KB"(items.count, itemBytes/1024.0);
          const linkBytes = links.ids.map!(i => serializeText(i).length+1).sum; writefln!"Links: %8d %8.1f KB"(links.count, linkBytes/1024.0);
          writefln!"Total: %8d %8.1f KB"(items.count+links.count, (itemBytes+linkBytes)/1024.0);
          writeln;
          writeln("Commit buffer entries: ", commitBuffer.length ? EgaColor.red(commitBuffer.length.text) : "0");
        break;

        case "commitbuffer", "commitbuf": commitBuffer.each!print; break;
        case "cancelbuffer", "cancelbuf": cancelBuffer.each!print; break;

        case "exit": case "x": enforce(!inTransaction, "Pending transaction. Use \"commit\" or \"cancel\" before exiting."); return false;

        default: error("Unknown command: "~cmd.quoted);
      }
    }catch(Exception e){
      print(EgaColor.ltRed("ERROR:"), e.simpleMsg);
    }

    writeln;
    return true;
  }

  string inputTextCommand(){
    //prompt
    write(EgaColor.white(">"), format!" I:%d + L:%d = %d %s"(items.count, links.count, items.count+links.count, commitBuffer.length ? EgaColor.red("*"~commitBuffer.length.text~" ") : ""));

/*    switch(textCommandMode){
      case 's': write(EgaColor.ltMagenta("schema ")); break;
      case 'd': write(EgaColor.ltBlue   ("data ")); break;
      case 'q': write(EgaColor.ltGreen  ("query ")); break;
      default: raise("invalid mode");
    }*/
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