//@exe

//@import c:\d

//summarizes token counts in D source files

import hetlib.utils, std.file, tokenizer;

Tuple!(string, int)[] aa_sort(int[string] aa){
   typeof(return) r=[];
   foreach(k,v;aa) r~=tuple(k,v);
   sort!q{a[1]>b[1]}(r);
   return r;
}

void main(){
  int[string] counts;

  void a(string s){
    const maxLen = 32;
    if(s.length>maxLen){
      s.length = maxLen; s~="...";
    }
    counts[s]++;
  }

  const paths = [`c:\d\hetlib`, `c:\d\hdmd`, `c:\D\dmd2\src`];
  foreach(DirEntry e; paths.map!(p => dirEntries(p, SpanMode.breadth)).join()){
    if(extractFileExt(e)==".d"){
      Token[] tokens;
      tokenize(e, fileReadStr(e), tokens);
      foreach(const t; tokens)with(TokenKind)switch(t.kind){
        case Identifier: a("ID: "~t.source); break;
        case Keyword: a("KW: "~t.source); break;
        case Operator: a("OP: "~t.source); break;
        case LiteralString: case LiteralChar: a("LI: "~t.source); break;
        default:
      }
    }
  }

  foreach(x; aa_sort(counts))
    if(x[1]>30)
      writefln("%s %s", x[1], x[0]);
}