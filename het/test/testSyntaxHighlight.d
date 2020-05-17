//@exe
//@import c:\d\libs
//@ldc
//@compile -m64 -mcpu=athlon64-sse3 -mattr=+ssse3
///@release
//@debug
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

//! Node hierarchy ///////////////////////////////////

class Node{ // Node ///////////////////////////////

  abstract void parse(Parser p);

  Node[] subNodes() { return []; }
  void clear() { }
  string id() { return ""; }

  // syntax highlighted output
  __gshared static ColoredOutput = true; //controls how toString works
  private{

    static string hl(int color)(string s){
      if(s=="") return s;
      if(ColoredOutput){
        const nl = s.endsWith('\n'); //take the last newline out
        if(nl) s = s.chomp;
        s = "\33" ~ (cast(char) color) ~ s ~ "\33\7" ~ (nl ? "\n" : "");
      }
      return s;
    }

    static string ind(string s){
      if(s=="") return s;
      if(ColoredOutput){
        const nl = s.endsWith('\n'); //take the last newline out
        if(nl) s = s.chomp;
        s = "\34\1" ~ s ~ "\34\2" ~ (nl ? "\n" : "");
      }
      return s;
    }

    static string blk(string s){
      if(s=="") return "{}";

      s = chomp(s); //one less newline is needed because the closing block will add it automatically

      if(ColoredOutput) s = "{\34\1\n" ~ s ~ "\34\2\n}";
                   else s = "{\n"      ~ s ~      "\n}";

      return s;
    }

    enum { gray=8, blue, green, aqua, red, purple, yellow, white }

    static string joinParts(T...)(T args){
      string res;
      foreach(a; args){
        string s = a.text.strip;

        if(s.empty) continue;

        const ch = res.length ? res[$-1] : ' ',
              nl = ch.among('\n', '\r'),
              wh = nl || ch.among(' ' , '\t');

        if(!wh) res ~= " ";
        res ~= s;
      }
      return res;
    }

  }
}


class Aggregate : Node { // Aggregate ///////////////////////////////
  string attrs;

  Node[] _subNodes;
  override Node[] subNodes(){ return _subNodes; }
  void append(N : Node)(N node){ if(node !is null) _subNodes ~= node; }
  override void clear() { _subNodes = []; }

  string contents() { "\n"~subNodes.map!text.join("\n"); }
  string contentsBlock() { "\n{"~ ind(contents.chomp) ~ "\n"; }
}


class Module : Aggregate { // Module /////////////////////////////
  string name;
  File file;

  override string id() { return name; }

  this(File file){
    this(new SourceCode(file));
  }

  this(SourceCode code){
    file = code.file;
    auto p = new Parser(code);
    parse(p);
  }

  override void parse(Parser p){
  }

  override string toString(){
    return joinParts(hl!aqua(attrs.chomp), ch!red("unittest"), name) ~ ";" ~ contents;
  }
}


class Comment : Node { // Comment ///////////////////////////
  //todo: doxigen
  //todo: linked to Node
  string text;

  this(string text){ this.text = text; }

  override string toString() const { return hl!gray(text)/+ ~ (text.startsWith("//") ? "\n" : "")+/; }
}

class AttributeSpecifier : Node { // AttributeSpecifier /////////////////////////////
  string attrs;

  this(string attrs){ this.attrs = attrs; }

  override string toString() const { return hl!aqua(attrs)~ " :"; }
}

class Import : Node { // Import /////////////////////////////////
  string attrs, text;

  this(string attrs, string text){ this.attrs = attrs; this.text = text; }

  override string toString() const {
    auto s = hl!red("import") ~ " " ~ ind(text) ~ ";";
    if(attrs.length) s = hl!aqua(attrs) ~ " " ~ s; //todo: this is too redundant
    return s;
  }
}

class Alias : Node { // Alias //////////////////////////////////
  string text;

  this(string text){ this.text = text; }

  override string toString() const {
    return hl!red("alias") ~ " " ~ ind(text) ~ ";";
  }
}

class Enum : Node {
  string attrs, name, type, values;

  this(string attrs, string name, string type, string values){
    this.attrs = attrs; this.name = name; this.type = type; this.values = values;
  }

  string nameType() const{ return name ~ (type.length ? " : "~type : ""); }

  override string id(){ return name; }

  override string toString(){
    auto s = hl!red("enum ");
    if(attrs.length) s = hl!aqua(attrs) ~ " " ~ s;
    if(nameType.length) s ~= [nameType, blk(values)].join(' ');
                   else s ~= values ~ ";";
    return s;
  }
}

class Contract : Node {
  bool isOut, isExpr;
  string identifier, body, message;

  override string toString(){
    string s = hl!red(isOut ? "out" : "in") ~ " ";

    if(isExpr){  //expression form
      if(isOut) s ~= "(" ~ identifier.strip ~ "; " ~ body;
           else s ~= "(" ~ body;
      if(message.length) s ~= ", " ~ message;  //optional message
      s ~= ")";
    }else{ //block statement form
      if(isOut) s ~= "(" ~ identifier ~ ")\n";
      s ~= blk(body);
    }

    return s;
  }
}

class Function : Node {
  string attrs, resultType, templateParams, params, memberAttrs;
  string[] constraints;
  Contract[] contracts;
  string body;
  bool forward;

  override string toString(){
    return "todo"; //todo
    /*auto s = hl!red("enum ");
    if(attrs.length) s = hl!aqua(attrs) ~ " " ~ s;
    if(nameType.length) s ~= [nameType, blk(values)].join(' ');
                   else s ~= values ~ ";";
    return s;*/
  }
}


class Mixin : Node { // Mixin ///////////////////////////////
  string attrs, templateName, params, varName;
  bool isStringMixin;

  override string id() { return varName; }

  override string toString(){
    if(isStringMixin) return joinParts(hl!aqua(attrs), hl!red("mixin"), ind("(" ~ params ~ ");"));
                 else return joinParts(hl!aqua(attrs), hl!red("mixin"), templateName ~ (params.length ? "!("~params~")" : ""), varName) ~ ";";
  }
}


class Group : Aggregate { // Group //////////////////////////////////
  override string toString(){
    auto s = joinParts(hl!aqua(attrs.chomp)) ~ contentsBlock;
  }
}

class Unittest : Aggregate {
  override string toString(){
    return joinParts(hl!aqua(attrs.chomp), ch!red("unittest")) ~ contentsBlock;
  }
}

class Template : Aggregate {
  string name, params, constraint;
  bool isMixinTemplate;

  override string id() { return name; }

  override string toString(){
    return joinParts(
      hl!aqua(attrs.chomp),
      isMixinTemplate ? hl!aqua("mixin") : "",
      hl!red("template"),
      name ~ "(" ~ params ~ ")",
      constraint.length ? ind("\n"~hl!red("if")~" ("~constraint~")") : ""
    ) ~ contentsBlock;
  }
}


/*class Aggregate : Node {
  enum Kind { group_, module_, class_, struct_, interface_, union_, unittest_, template_, mixinTemplate_ }

  Kind kind; //class, struct, module,
  string attrs, name, type, constraint;

  override string id() { return name; }

  string kindStr() const pure {
    if(kind==Kind.mixinTemplate_) return "mixin template";
    return kind == Kind.group_ ? "" : kind.text[0..$-1];
  }

  string nameTypeConstraint() const{
    if(kind.among(Kind.template_, Kind.mixinTemplate_))
      return name ~ " (" ~ type ~ ")" ~ (constraint.length ? ind("\n"~hl!red("if")~" ("~constraint~")") : "" );
    return name ~ (type.length ? " : "~type : "");
  }

  override string toString(){
    auto s = joinParts(hl!aqua(attrs.chomp), hl!red(kindStr), nameTypeConstraint);

    if(kind == Kind.module_) s ~= ";" ~ contents;
                        else s = s.chomp ~ "\n{" ~ ind(contents.chomp) ~ "\n}";

    return s;
  }
}      */

//! Parser ///////////////////////////////////////////////////////////////////////////

class Parser {
  Token[] tokens;
  string codeText;
  File file;

  this(Token[] tokens, string codeText, File file){
    this.tokens = tokens;
    this.codeText = codeText;
  }

  this(SourceCode code){
    this(code.tokens, code.text, code.file);
  }

  //fast access
  bool eof(){ return tokens.empty; }
  ref t  (size_t idx=0){ return tokens.getAny(idx); }
  ref tNC(size_t idx=0){ return tokens.getNonComment(idx); }
  bool isOp(string what)(){ return tokens.isOp!what; }
  void advance(size_t n=1){ tokens.popFrontN(n); } //opt: popFrontExactly?

  int findOp(string op)(int levelDelta=0){
    const minLevel = t.level,
          opLevel = minLevel + levelDelta;
    int i;
    for(auto act = tokens; !act.empty; act.popFront, i++){
      auto l = act[0].level;
      if(l<minLevel) break;
      if(l==opLevel && act.isOp!op) return cast(int) i;
    }
    return -1;
  }

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

  //must be on a { or at the start of a statement when called
  Token[] extractBlock(){
    //detect matching bracket
    int i = isOp!"{" ? findOp!"}" :
            isOp!"(" ? findOp!")" :
            isOp!"[" ? findOp!"]" : -1;

    enforce(i>=0, "Unable to find block ending token."); //todo: assert

    auto res = tokens[1..i];
    advance(i+1);

    return res;
  }

  Token[] extractStatement(){
    enforce(!isOp!"{"); //todo: assert
    auto i = findOp!";";
    enforce(i>=0); //todo: assert
    auto res = tokens[0..i];
    advance(i+1);
    return res;
  }

  string tokensToStr(in Token[] tokens){
    if(tokens.empty) return "";
    auto s = code.text[tokens[0].pos .. tokens[$-1].endPos];
    if(tokens[$-1].isSlashSlasComment) s ~= "\n"; //Add a newline if the last comment needs it
    return s;
  }

  string extractBlockStr    (){ return tokensToStr(extractBlock    ); }
  string extractStatementStr(){ return tokensToStr(extractStatement); }

  ///decide which is better from 2 filter operations
  auto nearest(T...)(auto ref T args){
    int res = -1;
    foreach(a; args) if(a>=0 && (res<0 || a<res)) res = a;
    return res;
  }

  ///Skip and combine multiple comments, keeping the newlines between them.
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

  void skipComments(){ while(t.isComment) advance; }

  string parseAttributesAndComments(){
    string res; if(eof) return res;

    auto orig = tokens;

    while(!eof){
      if(t.isComment){              //comments
        advance;
      }else if(isOp!"@"){
        advance; skipComments;
        if(t.isIdentifier){         //@UDA
          advance; skipComments;
          if(isOp!"(") extractBlock;//@UDA(params)
        }else if(isOp!"("){         //@(params)
          extractBlock;
        }else{
          WARN("Garbage after @");  //todo: it is some garbage, what to do with the error
          break;
        }
      }else if(t.isAttribute){      //attr
        advance; skipComments;
        if(isOp!"(") extractBlock;  //attr(params)
      }else{
        break; //reached the end normally
      }
    }

    auto block = orig[0..$-tokens.length];
    return tokensToStr(block);
  }

  //extracts a header and a block. If there is a ';' then it's only a header and an fwd declaration.
  auto extractHeaderAndBlock(){
    struct Res{
      Token[] header, block;
      bool isForward;
      auto headerStr() const { return tokensToStr(header); }
      auto blockStr () const { return tokensToStr(block ); }
    }
    Res res;

    auto baseLevel = t.level;
    if(t.isOperator([opcurlyBracketOpen, oproundBracketOpen, opsquareBracketOpen])) baseLevel--;

    auto idx = tokens.countUntil!((ref a) => a.level==baseLevel   && a.isOperator(opsemiColon)
                                          || a.level==baseLevel+1 && a.isOperator(opcurlyBracketOpen));
    enforce(idx>=0, `Bad structure: ";" or "{" expected.`);

    res.isForward = tokens[idx].isOperator(opsemiColon);

    if(res.isForward){
      res.header = tokens[0..idx];
      advance(idx+1);
    }else{
      res.header = tokens[0..idx];
      advance(idx);
      res.block = extractBlock;
    }

    return res;
  }
}


Aggregate parseAggregate(Aggregate.Kind aggregateKind, Token[] tokens, SourceCode code, int level, string outerAttrs=""){  //! parseAggregate //////////////////////////////
  Aggregate res = new Aggregate;

  res.kind = aggregateKind;
  res.attrs = outerAttrs;

  if(tokens.empty) return res;


  Enum parseEnum(string attrs)
  in(t.isKeyword(kwenum))
  {
    advance; //skip 'enum'

    string name, type, values;

    const a = extractHeaderAndBlock,
          anonym = a.isForward,
          s1     = a.headerStr;

    if(anonym){
      values = a.headerStr;
    }else{
      name = a.headerStr;
      values = a.blockStr.outdent;
    }

    //split nameType
    name.split2(":", name, type, true);

    return new Enum(attrs, name, type, values);
  }

  string parseFunctionConstraint()
  in(isOp!"if")
  {
    advance; skipComments; //todo: keep comments
    if(isOp!"("){
      return extractBlockStr;
    }else{
      WARN("Expected '(' after 'if'.");
      return "";
    }
  }

  Contract parseFunctionContract()
  in(isOp!"in" || isOp!"out")
  {
    auto res = new Contract;
    const delimiterLevel = t.level + 1;

    /// Returns if it has a ';' list or not
    bool parseContractExpression()
    in(isOp!"(")
    {
      res.isExpr = true;
      auto semiList = extractBlock.splitTokens!";"(delimiterLevel);

      void parseExprMessage(Token[] a){
        auto b = a.splitTokens!","(delimiterLevel);
        if(b.length >= 1) res.body    = tokensToStr(b[0]);
        if(b.length >= 2) res.message = tokensToStr(b[1]);
      }

      if(semiList.length == 1){
        parseExprMessage(semiList[0]);
      }else if(semiList.length >= 2){
        //extract identifier before ';'
        res.identifier = tokensToStr(semiList[0]);

        parseExprMessage(semiList[1]);

        return true; //has semiColon
      }

      return false;
    }

    void parseContractStatementBlock()
    in(isOp!"{")
    {
      res.isExpr = false;
      res.body = extractBlockStr;
    }

    if(isOp!"in"){
      res.isOut = false;
      advance; skipComments; //todo: keep comments

           if(isOp!"{") parseContractStatementBlock;
      else if(isOp!"(") parseContractExpression;
      else WARN(`Missing "in" contract expression or statement block.`);
    }else if(isOp!"out"){
      res.isOut = true;
      advance; skipComments; //todo: keep comments

      if(isOp!"{"){
        parseContractStatementBlock;
      }else if(isOp!"("){
        const hasSemiColon = parseContractExpression;

        if(!hasSemiColon){
          skipComments; //todo: keep comments

          res.identifier = res.body;  res.body = ""; //body was parsed from (), it's actually the (identifier)

          if(isOp!"{") parseContractStatementBlock;
                  else WARN(`"out" contract: missing statement block after (identifier).`);
        }
      }else{
        WARN(`Missing "out" contract expression or statement block.`);
      }
    }

    return res;
  }

  auto parseFunction(string attrs){
    //cursor is on the return type or this or ~this
    auto res = new Function;
    res.attrs = attrs;

    auto startTokens = tokens;
    auto startPos = t.pos;
    auto baseLevel = t.level;

/*    while(!eof){
      //LOG(t);

      if(isOp!";" && t.level == baseLevel){   //only a forward declaration
        res.header = tokensToStr(startTokens[0..$-tokens.length]);
        res.forward = true;
        advance;
        return res;
      }

      if(osOp!"in", t.level == baseLevel){ //constraint: in
        advance;
        if(t.level == baseLevel+1 && t.isOperator(opcurlyBracketOpen)){
          advance;
          //LOG("skipping in {}");
        }
        continue;
      }

      if(t.level == baseLevel && t.isKeyword(kwout)){ //constraint: out
        advance;
        if(t.level == baseLevel+1 && t.isOperator(oproundBracketOpen)){ //()
          //advanceBlock(oproundBracketClose);
          advance;
          //LOG("skipping out ()");
        }
        if(t.level == baseLevel+1 && t.isOperator(opcurlyBracketOpen)){  // optional {}
          advance;
          //LOG("skipping out {}");
        }
        continue;
      }

      if(t.level == baseLevel+1 && t.isOperator(opcurlyBracketOpen)){ //statement block {}
        res.header = code.text[startPos .. t.pos].strip;

        res.body = extractBlockStr;

        return res;
      }

      advance;
    }     */

    WARN("Incomplete function declaration");
    return res;
  }

  Aggregate parseTemplate(string attrs, Aggregate.Kind kind) // parseTemplate /////////////////////////
  {
    const baseLevel = t.level;

    //identifier
    enforce(t.isIdentifier, "Template identifier expected.");
    const name = t.source;
    advance; skipComments;  //todo: accumulate comments

    //template params
    enforce(isOp!"(", "Template parameters expected.");
    const params = extractBlockStr;
    skipComments;

    //constraint (opt)
    string constraint;
    if(isOp!("if")){
      advance; skipComments;
      enforce(isOp!"(", `Template constraint "(" expected after "if"`);
      constraint = extractBlockStr;
      skipComments;
    }

    //block
    enforce(isOp!"{", "Template block expected.");
    auto blk = extractBlock; skipComments;

    auto res = parseAggregate(kind, blk, code, baseLevel+1, attrs);
    res.name = name;
    res.type = params;
    res.constraint = constraint;
    return res;
  }

  Mixin parseMixin(string attrs)
  in(isOp!"mixin"){
    //mixin TemplateID!(param1, 2) identifier;
    advance; skipComments;

    auto res = new Mixin;
    res.attrs = attrs;

    if(isOp!"("){  //string mixin

      res.isStringMixin = true;
      res.params = extractBlockStr;
      skipComments;

    }else{ //template mixin

      //template identifier
      enforce(t.isIdentifier, "Identifier expected");
      string templateName = t.source;
      advance; skipComments;

      //params optional
      string templateParams;
      if(isOp!"!"){
        advance; skipComments;
        enforce(isOp!"(", "Template parameters expected.");
        templateParams = extractBlockStr;
        skipComments;
      }

      //variable name optional
      string varName;
      if(t.isIdentifier){
        varName = t.source;
        advance; skipComments;
      }

      res.templateName = templateName;
      res.params = templateParams;
      res.varName = varName;
    }

    enforce(isOp!";", `";" expected`);
    advance;

    return res;
  }

  bool parseDeclaration(){
    auto comments = parseComments.outdent,    //todo: standalone comments if there is more that one \n in between the thing and the comment
         attrs = parseAttributesAndComments.outdent;

    //foreach(s; comments) res.append(new Comment(s));
    if(comments.length) res.append(new Comment(comments));

    if(eof) return false;

    if(isOp!":"){                       //AttributeSpecifier :
      advance;
      res.append(new Attributes(attrs));
      return true;
    }else if(isOp!"{"){                 //AttributeSpecifier { }
      res.append(parseAggregate(Aggregate.Kind.group_, extractBlock, code, level+1, attrs));
      return true;
    }else if(isOp!"module"){            //ModuleDeclaration
      if(res.kind == Aggregate.Kind.module_){
        res.attrs = attrs; //ignores outerAttrs
        res.name = extractStatementStr.outdent;
      }else{
        WARN(`Can't declare a module here.`);
      }
      return true;
    }else if(isOp!"import"){            //ImportDeclaration
      res.append(new Import(attrs, extractStatementStr.outdent));
      return true;
    }else if(isOp!"alias"){
      res.append(new Alias(extractStatementStr.outdent)); //discard attrs
      return true;
    }else if(isOp!"enum"){              //EnumDeclaration
      res.append(parseEnum(attrs));
      return true;
    }else if(isOp!"unittest"){          //Unittest
      advance; skipComments; //todo: keep the comments
      if(isOp!"{"){
        auto a = parseAggregate(Aggregate.Kind.unittest_, extractBlock, code, level+1, attrs);
        res.append(a);
        return true;
      }else{
        WARN(`{ expected after "unittest"`);
      }
    }else if(isOp!"this" || isOp!"~this" || isOp!"new" || isOp!"delete"){ //Constructor/Destructor/Postblit/Allocator/Deallocator
      const isDestructor = t.isOperator([opcomplement, opdelete]);
      //auto f = parseFunctionDecl;
      //print(hl(aqua, attrs), hl(red, isDestructor ? "destructor" : "costructor"), f.header, hl(red, f.forward ? ";" : "body"), f.body);
      //todo
      return false;
    }else if(isOp!"mixin template"){
      advance; skipComments; //todo: keep the comments
      advance; skipComments; //todo: keep the comments
      res.append(parseTemplate(attrs, Aggregate.Kind.mixinTemplate_));
      return true;
    }else if(isOp!"template"){
      advance; skipComments; //todo: keep the comments
      res.append(parseTemplate(attrs, Aggregate.Kind.template_));
      return true;
    }else if(isOp!"mixin"){
      res.append(parseMixin(attrs));
      return true;
    }else if(isOp!"in" || isOp!"out"){ //THIS IS JUST FOR TESTING
      //contract test
      res.append(parseFunctionContract);
      return true;
    }else if(isOp!"if"){
      LOG("Constraint", parseFunctionConstraint);
      return true;
    }

    WARN("Don't know what to do with token:", escape(t.source));

    return false;
  }

  // do the actual parsing
  while(parseDeclaration){} //todo: do the append here

  return res;
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
    auto code = new SourceCode(File("parserTestText.d"));

/*    foreach(ref t; code.tokens)
      if(t.isComment && t.source.startsWith("//"))
        t.source = t.source[2..$];*/

    //auto root = parseAggregate(Aggregate.Kind.module_, code.tokens, code, 0);
    //root.writeln;

    auto root = new Module(code);
    root.writeln;
    readln;

    application.exit;

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


