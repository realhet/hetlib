//@exe
//@import c:\d\libs
//@ldc
//@compile -m64 -mcpu=athlon64-sse3 -mattr=+ssse3
///@release
//@debug

///@run $ > c:\dl\a.a

import het.utils;


// the helper for easier aliasing we'll need in step 3
alias helper(alias T) = T;
// This function writes details about all members of what it
// is passed. The string before argument is related to
// indenting the data it prints.

import std.traits;
private enum maxInspectLevel = 10;

void inspect(alias T)(string before="", int level=0) {
  // step 2
  foreach(memberName; __traits(allMembers, T)) {
    // step 3
    alias member = helper!(__traits(getMember, T, memberName));
    // step 4 - inspecting types
    static if(is(member)) {
      string specifically;
      static if(is(member == struct))
        specifically = "struct";
      else static if(is(member == class))
        specifically = "class";
      else static if(is(member == enum))
        specifically = "enum";
      writeln(before, fullyQualifiedName!member, " is a type (", specifically, ")");
      // drill down (step 1 again)
      static if(is(member == struct) || is(member == class) || is(member == enum)){
        if(level<maxInspectLevel) //no recursion
          inspect!member(before ~ "\t", level+1);
      }else{
        writeln(before ~"\t", fullyQualifiedName!member, " : ", member.stringof);
      }
    } else static if(is(typeof(member) == function)) {
      // step 5, inspecting functions
      writeln(before, fullyQualifiedName!member, " is a function typed ", typeof(member).stringof);
    } else {
      // step 6, everything else

        static if(__traits(compiles, member.stringof)) enum s = member.stringof; else enum s = "";

        static if(s.startsWith("module "))
          writeln(before, fullyQualifiedName!member, " is a module");
        else static if(s.startsWith("package "))
          writeln(before, fullyQualifiedName!member, " is a package");
        else static if(is(typeof(member.init)))
          writeln(before, fullyQualifiedName!member, " is a variable typed ", typeof(member).stringof);
        else{
          string fn = memberName;
          static if(__traits(compiles, fullyQualifiedName!member)) fn = fullyQualifiedName!member;
          writeln(before, fn, " is template ", s);
        }
    }
  }
}

void inspect2(alias T)(string before="", int level=0) {
  foreach(memberName; __traits(allMembers, T)) {
    print(memberName);
//    alias member = helper!(__traits(getMember, T, memberName));

  //  string name; static if(__traits(compiles, member.stringof)) name = member.stringof;
  //  string fullName; static if(__traits(compiles, fullyQualifiedName!member)) fullName = fullyQualifiedName!member;

  //  print(format("%-50s| %s", fullName, name));
  }
}

/*mixin(`
void inspectModule(string moduleName)(){
  static if(__traits(compiles, import `, moduleName, `)){
    import `,moduleName, `;
    inspect2!(`, moduleName, `);
  }else{
    print("Unknown module: ", `, moduleName, `);
  }
}
`);*/


mixin template ReflBase() {

  override string toString(){
    string[] attrs;
    foreach(idx, fn; AllFieldNames!(typeof(this))){
      mixin("alias a = " ~ fn ~ ";");
      alias T = typeof(a);

      /* */ static if(is(T==string))
        attrs ~= a.toJson;
      else
        attrs ~= a.text;
    }

    return typeof(this).stringof ~ "(" ~ attrs.join(", ") ~ ")";
  }

}

@("REFL"){

  class Module{ mixin ReflBase;
    string name, file;
    Member[] members;
  }

  class Parameter{ mixin ReflBase;
    string name;
    string kind; //template
    string deco;
    string default_;
    string[] storageClass;
  }

  class Member{ mixin ReflBase;
    string kind;
    string name;
    string file;
    int line;
    int char_;
    int endline;
    int endchar;
    string protection;
    string constraint;
    string[] storageClass;
    string linkage;
    string base; //baseclass
    string[] interfaces;
    string deco;
    string type;
    string originalType;
    string overrides;
    string init;
    int offset, align_;
    Member[] members;
    Parameter[] parameters;

    string[] selective;
    //string[string] renamed; //todo: map

    void dump(string prefix){
      write(prefix);

      writec(int c, string s){ write("\33"~hfdsghfew

      switch(kind){
        case "import": case "static import":{
          write("\33\11"~kind~"\33\7 ", toString);

        break; }

        default:
      }


      writeln;
    }
  }

/*  class Import: Member { mixin ReflBase;
    string name;
    int line; //todo: int char; keyword, FUCK!
    string protection;
  }*/

}

import het.stream;


void main(){ application.runConsole({
  //import gl3n.linalg; inspect!(gl3n.linalg);
  //import het.geometry; inspect!(het.geometry);

  auto str = File(`c:\Users\backup\temp\Animacio.json`).readText;

  if(0){ //"kind" statistics
    int[string] kindStats;
    foreach(s; str.splitter('\n').map!strip){
      if(s.isWild(`"kind" : "*"*`)){
        kindStats[wild[0]]++;
      }
    }

    foreach(k, v; kindStats){
      print(k, v);
    }
  }

  foreach(sym; getSymbolsByUDA!(mixin(__MODULE__), "REFL")) registerStoredClass!sym;

  Module[] modules;

  auto t0 = QPS;
  modules.fromJson(str, "LDCXJSON");
  print("LDCXJSON fromJson time:", QPS-t0);

  int[string] unhandledKinds;
  foreach(module_; modules){
    print("\33\14module\33\7", module_.name, module_.file);

    foreach(member; module_.members){
      member.dump("  ");
    }

    //break;
  }

  unhandledKinds.print;



  //modules.toJson.print;

/*
  module 25
    import 170
    static import 1
    enum 65
      enum member 1591
    struct 188
    union 4
    class 98
      constructor 197
      destructor 29
    interface 20
    function 3106
    generated function 2 //opAssign generated by D
    variable 1730
    alias 175
    template 451
      tuple 46 //template parameter type
      type 392
      value 188
    mixin 56  //instantiation of a mixin */




  readln;
});}