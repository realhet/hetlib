//@exe

import het;

immutable systemVerbs = ["as supertype", "has subset", "membership query", "abstract", "source", "target",
  "cardinality", "inverse cardinality", "inverse verb", "prohibited by", "required by", "is a",
  "equivalent to", "is deleted", "deleted by", "created by", "starts with", "followed by"];

auto systemVerbMap(){
  static int[string] m;
  if(!m){ foreach(idx, name; systemVerbs) m[name] = cast(int)idx + 1; m.rehash; }
  return m;
}

int systemVerbIdx(string name){
  return systemVerbMap.get(name, 0);
}

bool isSystemVerb(string name){
  return (name in systemVerbMap)!is null;
}

bool isSystemVerb(AMDB.Verb v) {
  return v && isSystemVerb(v.name);
}

bool isSystemVerb(AMDB.Thing t){
  if(auto v = cast(AMDB.Verb)t) return isSystemVerb(v); else return false;
}

class AMDB{
  protected enum ROFIELD (alias type, string name, string attr="const") = format!"protected %s %s_; @property auto %s() %s { return %s_; }"(type.stringof, name, name, attr, name);
  protected enum ROMFIELD(alias type, string name) = ROFIELD!(type, name, "");

  struct Id{
    uint id;
    @property bool isNull() const { return id==0; }
  }

  protected uint lastIdIndex;
  Id nextId(){ return Id(++lastIdIndex); }

  class Thing{
    mixin(ROMFIELD!(AMDB, "db"));
    mixin(ROFIELD!(Id, "id"));
    this(AMDB owner, Id id){
      db_ = owner;
      id_ = id;
    }
  }

  class Verb : Thing{
    mixin(ROFIELD!(string, "name"));

    this(AMDB owner, Id id, string name){
      super(owner, id);
      name_ = name;
    }

    override string toString() const {
      return name.quoted.format!"Verb(%s)";
    }
  }

  class Verbs{
    mixin(ROMFIELD!(AMDB, "db"));

    this(AMDB owner){ db_ = owner; }

    protected Verb[string] byName;
    Verb[] array;
    alias array this;
  }

/*  class Verbs{
    Verb[] array;

    //auto getArray(){ return array; }
    alias array this; //note: with getArray, 'filter!' not works, only 'each!'. This sucks

    this(){
    }
  }*/

  Verbs verbs;

  this(){
    verbs = new Verbs(this);
  }
}

void main(){
  auto db = new AMDB;
  with(db){

    verbs.each!writeln;
    verbs.filter!"true".each!writeln;
  }
}
