module het.obj;

import het.utils, std.traits;

// from here it is deprecated ---->8----->8----->8----->8----->8-----

public import jsonizer; //todo: own system for serialization

/*
[ ] Field declarations
[ ] Static Field list
*/

/* old trash
mixin template FIELD(T, string name, T def = T.init){
  mixin(q{
    private $ f_# = %;
    @jsonize @property {
      $ #() const{ return f_#; }
      void #($ #) { if(f_# != #){ f_# = #; _propChanged("#"); } }
    }
  }.replace("#", name).replace("$", T.stringof).replace("%", def.stringof));
}

bool isStatement(string code){
  auto s = code.strip; return s.endsWith(";") || s.endsWith("}"); //It bugs with a // comment at the end
}

mixin template CALCED(string name, string expr){
  mixin(q{
    auto #() const{ %; }
  }.replace("#", name).replace("%", expr.isStatement ? expr : "return "~expr));
}

mixin template CACHED(string name, string expr){
  mixin(q{
    private auto _calc_#() const{ % }
    private ReturnType!_calc_# _cached_#;
    private bool _valid_#;
    auto #() { if(!_valid_#){ _cached_# = _calc_#(); _valid_# = true; } return _cached_#; }
  }.replace("#", name).replace("%", expr.isStatement ? expr : "return "~expr));
}


mixin template CACHED(string name, T def = T.init, alias fun){
  mixin(q{
    private $ c_#;
    $ #(){
      if(c_# == %) c_# = calc_#;
      return c_#;
    }
  }.replace("#", name).replace("$", T.stringof));
}

void testJetson(){

  static class TestClass{ mixin JsonizeMe; void _propChanged(string name){}
    @jsonize int field;

    double f_getset;
    @property @jsonize {
      auto getset(){ return f_getset; }
      void getset(in typeof(f_getset) a){ f_getset = a; }
    }

    mixin FIELD!(string, "str_field", "hello world");
    mixin CALCED!("calced", q{ field.text ~ str_field } );
    mixin CACHED!("cached", q{ return field.text ~ str_field ~ "cached"; } );
  }

  auto test = new TestClass;

  print("@jsonize members:", [typeof(test)._membersWithUDA!jsonize] );

  test._writeMember!(int, "field")(5);
  test._readMember!("field").print;
  test._writeMember!(double, "getset")(9);
  test._readMember!("getset").print;
  test._readMember!("str_field").print;
  test.calced.print;
  test.cached.print;
  test.cached.print;

}

*/


class HetObj {
  //UDA to declare serializable data
  enum STORED;
  //alias STORED = jsonize; //later it will be own stuff
  //           ^^^^^^ <---- This crap isn't compatible with jsonizer.

  ///UDA to declare a field
  struct FIELD{
/*    this(T...)(T args){
      static foreach()
    }*/
  }

  this(){ }

  //void dump(){ print(typeof(this).stringof); }

  void update(){ //centralized update for all hetObjs
    //currently every object are responsible to resresh its subObjects.
  }

  abstract{
    string dump();
    void initFields();
    bool loadFromJSON(string s, bool mustSucceed=true);
    string saveToJSON();
  }
}

mixin template HETOBJ(){ mixin JsonizeMe;

  override void initFields(){ // reInitialize class fields
    import std.traits;
    /*alias T = typeof(this);
    static foreach(n; FieldNameTuple!T){{
      mixin("enum def = (new T).@; @ = def;".replace("@", n));
    }}*/

    // https://forum.dlang.org/post/hhtshvhiqrwxwqqoemeu@forum.dlang.org
    static foreach(i, field; typeof(this).tupleof) {{
      alias t = typeof(field);
      // force compile-time evaluation:
      static if(is(t == class)){
        //subClass
        //initialization
//        enfocre(0, "notimpl");
      }else static if(isStaticArray!t){

        //static array of classes
/*        alias et = typeof(field[0]);
        static if(is(et == class))
          foreach(ref e; field) e = new et; //default constructor*/

      }else static if(isDynamicArray!t){
        field = [];
      }else{
        enum initValue = (new typeof(this)).tupleof[i]; //get the default struct/class initializer
        field = initValue;
      }
    }}
  }

  override string dump(){
    alias T = typeof(this);
    string[] s;
    static foreach(n; _membersWithUDA!STORED){{
      auto str = mixin(n ~ ".escape");
      s ~= n ~ " = " ~ str;
    }}

    return format!"%s(%-(%s, %))"(T.stringof, s);
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

