//@exe
//@import c:\d\libs
//@ldc
//@compile -m64 -mcpu=athlon64-sse3 -mattr=+ssse3
//@release
///@debug
///@run $ c:\d\libs\het\utils.d
///@run $ c:\d\libs\het\draw3d.d
///@run $ c:\D\ldc2\import\std\format.d
///@run $ c:\D\ldc2\import\std\uni.d
///@run $ c:\d\libs\het\test\syntaxTestText.d
//@run $ c:\D\ldc2\import\std\datetime\systime.d


/*
[x] oacute bug
[ ] mark tokens
[ ] Consolas font for decimals and for escaped strings
*/

import het, het.ui, het.tokenizer, het.keywords;


string transformLeadingSpacesToTabs(string original, int spacesPerTab=2){

  string process(string s){
    s = stripRight(s);
    int cnt;
    string spaces = " ".replicate(spacesPerTab);
    while(s.startsWith(spaces)){
      s = s[spaces.length..$];
      cnt++;
    }
    s = "\t".replicate(cnt) ~ s;
    return s;
  }

  return original.split('\n').map!(s => process(s)).join('\n'); //todo: this is bad for strings
}

struct SyntaxStyle{
  RGB fontColor, bkColor;
  int fontFlags; //1:b, 2:i, 4:u
}

struct SyntaxStyleRow{
  string kindName;
  SyntaxStyle[] formats;
}


//todo: these should be uploaded to the gpu
//todo: from the program this is NOT extendable
immutable syntaxPresetNames =
                   ["Default"                 , "Classic"                          , "C64"                     , "Dark"                     ];
immutable SyntaxStyleRow[] syntaxTable = [
  {"Whitespace"  , [{clBlack  ,clWhite   ,0}, {clVgaYellow      ,clVgaLowBlue   ,0}, {clC64LBlue  ,clC64Blue   ,0}, {0xc7c5c5 ,0x2d2d2d ,0}]},
  {"Selected"    , [{clWhite  ,10841427  ,0}, {clVgaLowBlue     ,clVgaLightGray ,0}, {clC64Blue   ,clC64LBlue  ,0}, {clBlack  ,0xc7c5c5 ,0}]},
  {"FoundAct"    , [{0xFCFDCD ,clBlack   ,0}, {clVgaLightGray   ,clVgaBlack     ,0}, {clC64LGrey  ,clC64Black  ,0}, {clBlack  ,0xffffff ,0}]},
  {"FoundAlso"   , [{clBlack  ,0x78AAFF  ,0}, {clVgaLightGray   ,clVgaBrown     ,0}, {clC64LGrey  ,clC64DGrey  ,0}, {clBlack  ,0xa7a5a5 ,0}]},
  {"NavLink"     , [{clBlue   ,clWhite   ,4}, {clVgaHighRed     ,clVgaLowBlue   ,4}, {clC64Red    ,clC64Blue   ,0}, {0xFF8888 ,0x2d2d2d ,4}]},
  {"Number"      , [{clBlue   ,clWhite   ,0}, {clVgaYellow      ,clVgaLowBlue   ,0}, {clC64Yellow ,clC64Blue   ,0}, {0x0094FA ,0x2d2d2d ,0}]},
  {"String"      , [{clBlue   ,clSkyBlue ,0}, {clVgaHighCyan    ,clVgaLowBlue   ,0}, {clC64Cyan   ,clC64Blue   ,0}, {0x64E000 ,0x283f28 ,0}]},
  {"Keyword"     , [{clNavy   ,clWhite   ,1}, {clVgaWhite       ,clVgaLowBlue   ,1}, {clC64White  ,clC64Blue   ,0}, {0x5C00F6 ,0x2d2d2d ,1}]},
  {"Symbol"      , [{clBlack  ,clWhite   ,0}, {clVgaYellow      ,clVgaLowBlue   ,0}, {clC64Yellow ,clC64Blue   ,0}, {0x00E2E1 ,0x2d2d2d ,0}]},
  {"Comment"     , [{clNavy   ,clYellow  ,2}, {clVgaLightGray   ,clVgaLowBlue   ,2}, {clC64LGrey  ,clC64Blue   ,0}, {0xf75Dd5 ,0x442d44 ,2}]},
  {"Directive"   , [{clTeal   ,clWhite   ,0}, {clVgaHighGreen   ,clVgaLowBlue   ,0}, {clC64Green  ,clC64Blue   ,0}, {0x4Db5e6 ,0x2d4444 ,0}]},
  {"Identifier1" , [{clBlack  ,clWhite   ,0}, {clVgaYellow      ,clVgaLowBlue   ,0}, {clC64Yellow ,clC64Blue   ,0}, {0xc7c5c5 ,0x2d2d2d ,0}]},
  {"Identifier2" , [{clGreen  ,clWhite   ,0}, {clVgaHighGreen   ,clVgaLowBlue   ,0}, {clC64LGreen ,clC64Blue   ,0}, {clGreen  ,0x2d2d2d ,0}]},
  {"Identifier3" , [{clTeal   ,clWhite   ,0}, {clVgaHighCyan    ,clVgaLowBlue   ,0}, {clC64Cyan   ,clC64Blue   ,0}, {clTeal   ,0x2d2d2d ,0}]},
  {"Identifier4" , [{clPurple ,clWhite   ,0}, {clVgaHighMagenta ,clVgaLowBlue   ,0}, {clC64Purple ,clC64Blue   ,0}, {0xf040e0 ,0x2d2d2d ,0}]},
  {"Identifier5" , [{0x0040b0 ,clWhite   ,0}, {clVgaBrown       ,clVgaLowBlue   ,0}, {clC64Orange ,clC64Blue   ,0}, {0x0060f0 ,0x2d2d2d ,0}]},
  {"Identifier6" , [{0xb04000 ,clWhite   ,0}, {clVgaHighBlue    ,clVgaLowBlue   ,0}, {clC64LBlue  ,clC64Blue   ,0}, {0xf06000 ,0x2d2d2d ,0}]},
  {"Label"       , [{clBlack  ,0xDDFFEE  ,4}, {clBlack          ,clVgaHighCyan  ,0}, {clBlack     ,clC64Cyan   ,0}, {clBlack  ,0x2d2d2d ,4}]},
  {"Attribute"   , [{clPurple ,clWhite   ,1}, {clVgaHighMagenta ,clVgaLowBlue   ,1}, {clC64Purple ,clC64Blue   ,1}, {0xAAB42B ,0x2d2d2d ,1}]},
  {"BasicType"   , [{clTeal   ,clWhite   ,1}, {clVgaHighCyan    ,clVgaLowBlue   ,1}, {clC64Cyan   ,clC64Blue   ,1}, {clWhite  ,0x2d2d2d ,1}]},
  {"Error"       , [{clRed    ,clWhite   ,4}, {clVgaHighRed     ,clVgaLowBlue   ,4}, {clC64Red    ,clC64Blue   ,0}, {0x00FFEF ,0x2d2dFF ,0}]},
  {"Binary1"     , [{clWhite  ,clBlue    ,0}, {clVgaLowBlue     ,clVgaYellow    ,0}, {clC64Blue   ,clC64Yellow ,0}, {0x2d2d2d ,0x20bCFA ,0}]},
];

mixin(format!"enum SyntaxKind   {%s}"(syntaxTable.map!"a.kindName".join(',')));
mixin(format!"enum SyntaxPreset {%s}"(syntaxPresetNames.join(',')));

__gshared defaultSyntaxPreset = SyntaxPreset.Dark;

/// Lookup a syntax style and apply it to a TextStyle reference
void applySyntax(ref TextStyle ts, ubyte syntax, SyntaxPreset preset)
in(syntax<syntaxTable.length)
{
  auto fmt = &syntaxTable[syntax].formats[preset];
  ts.fontColor = fmt.fontColor;
  ts.bkColor   = fmt.bkColor;
  ts.bold      = fmt.fontFlags.getBit(0);
  ts.italic    = fmt.fontFlags.getBit(1);
  ts.underline = fmt.fontFlags.getBit(2);
}

/// Shorthand with global default preset
void applySyntax(ref TextStyle ts, ubyte syntax){
  applySyntax(ts, syntax, defaultSyntaxPreset);
}


class CodeRow: Row{ //CodeRow //////////////////////////////////////
  SourceCode code;
  int lineIdx;

  this(SourceCode code, int lineIdx, ref TextStyle ts){
    super(ts); //this overwrites bkColor

    this.code = code;
    this.lineIdx = lineIdx;
    bkColor = syntaxTable[0].formats[defaultSyntaxPreset].bkColor; //this also

    flags.canWrap = false;

    auto line = code.getLine(lineIdx);
    this.appendCode(line.text, line.syntax, (s){ ts.applySyntax(s); }, ts);

    //empty row height is half
    if(subCells.empty) {
      innerHeight = ts.fontHeight*0.5;
      bkColor = lerp(bkColor, bkColor.l>0x80 ? clWhite : clBlack, 0.0625);
    }
  }
}

struct CodeMarker{
  int line, col;
}

/// A block of codeRows or codeBlocks aligned like a Column
class CodeBlock : Column { //CodeBlock /////////////////////////////////////
  SourceCode code;

  Drawing cachedDrawing;

  CodeMarker[] markers;

  this(SourceCode code){
    this.code = code;

    auto ts = tsNormal;  ts.applySyntax(0);

    super(ts); //this overwrites bkColor

    auto codeRows = iota(code.lineCount).map!(i => new CodeRow(code, i, ts)).array;
    append(cast(Cell[]) codeRows);
  }

  //Measure only once
  bool measured; override void measure(){ if(measured.chkSet) super.measure; }

  void addMarker(in Token t){
    markers ~= CodeMarker(t.line, t.posInLine);
  }

  void addMarker(size_t i){
    if(i.inRange(code.tokens))
      addMarker(code.tokens[i]);
  }

  auto getMarkerPos(in CodeMarker m){
    V2f res;
    if(auto codeRow = cast(CodeRow) subCells.get(m.line)){
      if(auto cell = codeRow.subCells.get(m.col)){
        res = codeRow.outerPos + cell.outerPos + cell.innerSize/2;
      }
    }
    return res;
  }

  void drawMarkers(Drawing dr){
    dr.translate(innerPos);
    dr.color = clOrange;
    dr.pointSize = -((sin(QPS.fract*PI*4)+1)^^2*5);
    dr.alpha = 1;

    foreach(ref m; markers){
      auto p = getMarkerPos(m);
      if(!p.isNull){
        dr.point(p);
      }
    }

    dr.alpha = 1;

    dr.pop;
  }

  override void draw(Drawing dr){
    if(0){
      super.draw(dr);
    }else{
      if(cachedDrawing is null){
        cachedDrawing = dr.clone;
        super.draw(cachedDrawing);
      }
      dr.draw(cachedDrawing);
    }

    if(markers.length){
      auto dr2 = dr.clone;
      drawMarkers(dr2);
      dr.draw(dr2);
    }
  }
}



// Experimental parseModule ////////////////////////////////


/+
//extern
  [ ] extern          //https://dlang.org/spec/declaration.html#extern

  ( ) extern(C)
  ( ) extern(C++)
  ( ) extern(C++, namespace.namespace)
  ( ) extern(D)
  ( ) extern(Windows)
  ( ) extern(System)
  ( ) extern(Objective-C)

//visibility    //https://dlang.org/spec/attribute.html#VisibilityAttribute
  ( ) public
  ( ) private
  ( ) protected
  ( ) export
  ( ) package
  ( ) package(package.module)

  [ ] static       //functs, data   https://dlang.org/spec/attribute.html#static

//inheritance
  ( ) override     //virtual functs                         https://dlang.org/spec/attribute.html#override
  ( ) final        //virtual functs, classes
  ( ) abstract     //virtual functs, classes                https://dlang.org/spec/attribute.html#abstract

//other
  [ ] align opt(AssignExpression)             //data             https://dlang.org/spec/attribute.html#align
  [ ] deprecated opt(AssignExpression)                         //https://dlang.org/spec/attribute.html#deprecated
  [+] pragma(identifier, optArgumentList)

  [ ] synchronized   //classes, structs, functs


//storage types / type qualifiers
  //TypeCtor s
  ( ) immutable  //data                                                    //https://dlang.org/spec/const3.html#immutable_storage_class
  ( ) const  //data funct                                                    https://dlang.org/spec/const3.html#const_storage_class
  ( ) shared  //https://dlang.org/spec/attribute.html#shared
  ( ) inout  //param, result

  ( ) shared const
  ( ) inout const
  ( ) inout shared
  ( ) inout shared const
  ( ) __gshared     //https://dlang.org/spec/attribute.html#gshared

  [.] auto  //functs, data, if no attribute but type inference is needed    https://dlang.org/spec/attribute.html#auto
  [ ] scope //auto destructors                                              https://dlang.org/spec/attribute.html#scope

  ( ) ref          //param
  ( ) return ref   //param
  ( ) auto ref     //param

//functions
  [ ] @property
  [ ] @disable                //https://dlang.org/spec/attribute.html#disable
  [ ] @nogc
  [ ] nothrow
  [ ] pure
  [ ] @safe
  [ ] @trusted
  [ ] @system

//UDA
@Type
@Type(123)
@("hello") struct SSS { }
public @(3) {
  @(4) @EEE @SSS int foo;
}
+/

void parseAggregate(Token[] tokens, SourceCode code, int level){
  void print(T...)(auto ref T args){ .print("  ".replicate(level+1), args); }

  level--; print("parsing aggregate at level", level+1); level++;
  if(tokens.empty) return;

  Token nullToken;
  nullToken.source = "EOF";
  nullToken.pos = tokens[$-1].endPos;

  bool eof(){ return tokens.empty; }
  ref t(size_t idx=0){ return idx<tokens.length ? tokens[idx] : nullToken; }
  void advance(size_t n=1){ tokens = tokens[n..$]; }

  bool advanceUntilOperator(int op, int level){
    while(!eof){
      if(t.isOperator(op) && (level<0 || t.level==level)){ return true; }
      advance;
    }
    return false;
  }

  bool advancePastOperator(int op, int level){
    auto a = advanceUntilOperator(op, level);
    if(a) advance;
    return a;
  }

  //must be on a { when called
  Token[] advanceBlock(int closingOp){
    auto baseLevel = t.level;
    auto cnt = tokens.countUntil!(t => t.level==baseLevel && t.isOperator(closingOp));
    enforce(cnt>0);
    auto res = tokens[1..cnt];
    tokens = tokens[cnt+1..$];
    return res;
  }

  int findOp(int op, int levelDelta=0){
    auto baseLevel = t.level + levelDelta;
    return cast(int) tokens.countUntil!(t => t.level==baseLevel && t.isOperator(op));
  }

  auto nearest(T...)(auto ref T args){
    int res = -1;
    foreach(a; args) if(a>=0 && (res<0 || a<res)) res = a;
    return res;
  }

  auto parseEnum(){
    assert(t.isKeyword(kwenum));
    struct Res{ string name, items; }
    Res res;

    auto idx = nearest(findOp(opcurlyBracketOpen, 1), findOp(opsemiColon)); //todo: needs a special parser here for smaller memory usage

    if(idx<0){
      advance;
      WARN("Incomplete enum structure"); //todo: what's with fatal structural errors?
      return res;
    }

    const anonym = tokens[idx].isOperator(opsemiColon),
          s1     = res.items = code.text[tokens[1].pos .. tokens[idx-1].endPos];

    if(anonym){
      res.items = s1;
      tokens = tokens[idx+1 .. $];
    }else{
      res.name = s1;
      tokens = tokens[idx..$];

      auto block = advanceBlock(opcurlyBracketClose);
      if(block.length){ res.items = code.text[block[0].pos .. block[$-1].endPos]; }
    }

    return res;
  }

  //Skip and combine multiple comments, keeping the newlines between them.
  string parseComments(){
    string res; if(eof) return res;

    int lastLine = t.line;
    while(t.isComment){
      res ~= "\n".replicate(t.line-lastLine) ~ t.source;
      lastLine = t.line + cast(int) t.source.count('\n');
      advance;
    }

    return res;
  }

  string parseAttributesAndComments(){
    string res; if(eof) return res;

    immutable allAttributes = [
      kwextern, kwpublic, kwprivate, kwprotected, kwexport, kwpackage,
      kwstatic,
      kwoverride, kwfinal, kwabstract,
      kwalign, kwdeprecated, kwpragma,
      kwsynchronized,
      kwimmutable, kwconst, kwshared, kwinout, kw__gshared,
      kwauto, kwscope,
      kwref, kwreturn, /* return must handled manually inside statement blocks*/
      kwnothrow,
      kwpure,
    ];

    size_t startPos = t.pos;

    while(!eof){
      if(t.isComment){                                  // comments
        advance;
      }else if(t.isOperator(opatSign)){                 // @
        advance;
        if(t.isIdentifier){                             // @UDA
          advance;
          if(t.isOperator(oproundBracketOpen)){         // @UDA(params)
            advancePastOperator(oproundBracketClose, t.level);
          }
        }else if(t.isOperator(oproundBracketOpen)){     //@(params)
          advancePastOperator(oproundBracketClose, t.level);
        }else{
          WARN("Garbage after @"); //todo: it is some garbage, what to do with the error
          break;
        }
      }else if(t.isKeyword(allAttributes)){             //attribute
        advance;
        if(t.isOperator(oproundBracketOpen)){           //(params)
          advancePastOperator(oproundBracketClose, t.level);
        }
      }else{
        break; //reached the end normally
      }
    }

    size_t endPos = eof ? code.text.length : t.pos;

    return code.text[startPos..endPos].strip;
  }

  bool parseDeclaration(){

    string getBlockStr(int closingOp){
      auto block = advanceBlock(closingOp);
      return code.text[block[0].pos .. block[$-1].endPos];
    }

    auto comments = parseComments,    //todo: standalone comments if there is more that one \n in between the thing and the comment
         attrs = parseAttributesAndComments;

    if(comments.length) print("comment:", comments);

    if(eof) return false;

    if(t.isOperator(opcolon)){                  //AttributeSpecifier :
      advance;

      print("attribute specifier:", attrs);
      return true;
    }else if(t.isOperator(opcurlyBracketOpen)){ //AttributeSpecifier { }
      print("attribute block:", attrs);
      auto block = advanceBlock(opcurlyBracketClose);
      parseAggregate(block, code, level+1);
      return true;
    }else if(t.isKeyword(kwmodule)){            //ModuleDeclaration
      auto s = getBlockStr(opsemiColon);
      print(attrs, "module:", s);
      return true;
    }else if(t.isKeyword(kwimport)){            //ImportDeclaration
      auto s = getBlockStr(opsemiColon);
      print(attrs, "import:", s);
      return true;
    }else if(t.isKeyword(kwalias)){
      auto s = getBlockStr(opsemiColon);
      print(attrs, "alias:", s);  //there should be no alias 'though'
      return true;
    }else if(t.isKeyword(kwenum)){              //EnumDeclaration
      auto e = parseEnum;
      print(attrs, "enum:", e);
      return true;
    }

    WARN("Don't know what to do with token:", escape(t.source));

    return false;
  }

  while(parseDeclaration){}
}





class FrmMain: GLWindow { mixin autoCreate; // !FrmMain ////////////////////////////
  SourceCode code;
  CodeBlock codeBlock;

  void reload(){
    auto file = File(application.args(1));
    string text;


    foreach(batch; 0..2){
      print("------------------batch #", batch);
      PERF("load, syntaxHighLight", {
        text = file.readText;
      });
      PERF("processLeadingSpaces", {
        text = text.transformLeadingSpacesToTabs;
      });
      PERF("tokenize/syntaxHighlight", {
        code = new SourceCode(text, file);
      });
      PERF("create CodeBlock", {
        codeBlock = new CodeBlock(code);
      });
      PERF("CodeBlock.measure", {
        codeBlock.measure;
      });

      PERF.report.writeln;
    }

    //parseDeclarations(code);

    bool ignoreColon = false;
    int[] delims;
    foreach(idx, const t; code.tokens){
      void add(){ delims ~= cast(int)idx; }
      if(t.level==0 && t.source==";" || t.level==1 && t.source=="}" && code.syntax[t.pos]==8/*skSymbol*/){ add; ignoreColon = false; }
      else if(t.level==0 && t.source.among("class", "enum", "import", "interface")) ignoreColon = true;
      else if(!ignoreColon && t.level==0 && t.source==":") add;
    }                                      //todo: tenary:, struct initializer:, static if():

    foreach(i; delims){
      codeBlock.addMarker(i);
    }

  }

  override void onCreate(){ // create /////////////////////////////////
    auto code = new SourceCode(q{
//ModuleDeclaration

deprecated("just a test") module test.modul;

/*comment1*//*comment2*/
/+/+comment3
end+/
+/ //hello
//last

extern extern(C) extern(C++) extern(C++, name.space) extern(D) extern(Windows) extern(System) extern(Objective-C)
public private protected export package package(pkg.mod)
static override final abstract align(4) deprecated ("because") pragma(id, args)
synchronized immutable const shared inout __gshared
auto scope ref return ref auto ref
@property @nogc nothrow pure @safe @trusted @system @disable
{
  //all the possible attributes

  //here's some more
  @hello @(1,2,3) align/*pragma comment*/ pragma(4) : //attribute specifier
  @attr2 { /*body*/ @another(params): /*last comment*/ } //attributed block
}

//ImportDeclaration

import fmt = std.format, std.stdio : a = func1, c = func2,
       f3, f4;
static import m1 = het.utils, std.stdio : a = func1, c = func2, f3, f4;
public import std.exception;

//alias declarations

alias myint = int,
      mybytearray = byte[];
alias int(string p) Fun;   //old alias format without =

//enums

enum F;
enum A = 3;
enum B
{
    A = A // error, circular reference
}
enum C
{
    A = B,  // A = 4
    B = D,  // B = 4
    C = 3,  // C = 3
    D       // D = 4
}
enum E : C
{
    E1 = C.D,
    E2      // error, C.D is C.max
}

});

    parseAggregate(code.tokens, code, 0);
    readln;

    reload;
  }

  override void onDestroy(){ // destroy //////////////////////////////
  }

  override void onUpdate(){ // update ////////////////////////////////
    invalidate; //todo: opt
    view.navigate(!im.wantKeys, !im.wantMouse);

    caption = FPS.text;

    with(im) Panel({
      //width = clientWidth;
      //vScroll;

      style.applySyntax(0);
//      Row({ style.fontHeight=50; Text("FUCK"); });

      actContainer.append(codeBlock);
    });

    if(inputs.Space.pressed){
      reload;
      foreach(const t; code.tokens[0..10]){
        print(t.line, t.kind);
      }
    }
  }

  override void onPaint(){ // paint //////////////////////////////////////
    //auto t0 = QPS;

    dr.clear(clBlack);
    drGUI.clear;

    im.draw(dr);

    //drGUI.glDraw(viewGUI);
    //drGUI.clear;


    //update, beginPaint, paint   , endPaint, swapBuffers
    //clBlue, clLime    , clYellow, clRed   , clGray
    //drawFpsTimeLine(drGUI);


    /*drGUI.glDraw(viewGUI);*/
    //{ auto t = ((QPS-t0)*1000).to!int; if(t) writefln("%s %3d ms", this.classinfo.name, t); }
  }

}


