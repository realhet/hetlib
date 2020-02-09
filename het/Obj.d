module het.obj;

import het.utils, jsonizer, std.traits;

class HetObj {
  this(){ }

  void dump(){ print(typeof(this).stringof); }

  abstract{
    void initFields();
    bool loadFromJSON(string s, bool mustSucceed=true);
    string saveToJSON();
  }
}

mixin template HETOBJ(){ mixin JsonizeMe;

  override void initFields(){ // reInitialize class fields
    alias T = typeof(this);
    foreach(n; FieldNameTuple!T){{
      mixin("enum def = (new T).@; @ = def;".replace("@", n));
    }}
  }

  override string saveToJSON(){
    return this.toJSONString; //this must be placed BEFORE this.populate
  }

  override bool loadFromJSON(string s, bool mustSucceed=true){
    initFields; //opt: init and json reader 2 in 1 would be faster.

    if(s=="") return true; //empty db is a successful load;

    try{
      auto tmp = this; //populate needs a ref.
      populate(tmp, s, JsonizeOptions.init); //this must be placed AFTER this.toJSONSring
      return true;
    }catch(Throwable t){
      if(mustSucceed) throw t;
    }
    return false;
  }

  static this(){

  }
}

