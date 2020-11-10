module het.tokenizer;
import het.utils, het.keywords, std.variant;
                                          //todo: size_t-re atallni
//TEST: testTokenizer()

const CompilerVersion = 100;

//TODO: __EOF__ means end of file , must work inside a comment as well

//TODO: DIDE jegyezze meg a file kurzor/ablak-poziciokat is
//TODO: kulon kezelni az in-t, mint operator es mint type modifier
//TODO: ha elbaszott string van, a parsolas addigi eredmenye ne vesszen el, hogy a syntaxHighlighter tudjon vele mit kezdeni
//TODO: syntax highlight: a specialis karakter \ dolgoknak a stringekben lehetne masmilyen szine.
//TODO: syntax highlight: a tokenstring egesz hatter alapszine legyen masmilyen. Ezt valahogy bele kell vinni az uj editorba.
//TODO: editor: save form position FFS
//todo: syntax: x"ab01" hex stringeket kezelni. Bugos

//refactor to anonym -> ebben elvileg a delphi jobb.

//todo: camelCase

//todo: highlight escaped strings
//todo: highlight regex strings
//todo: nem kell a token.data-t azonnal kiszamolni. Csak lazy modon.
//todo: TokenKind. camelCase


enum TokenKind {unknown, comment, identifier, keyword, special, operator, literalString, literalChar, literalInt, literalFloat};

@trusted string tokenize(string fileName, string text, out Token[] tokens) //returns error of any
{
  auto t = scoped!Tokenizer;  return t.tokenize(fileName, text, tokens);
}

Token[] syntaxHighLight(string fileName, string src, ubyte* res, ushort* hierarchy, char* bigComments, int bigCommentsLen)
{
  Token[] tokens;
  tokenize("", src, tokens);    //todo: nem jo, nincs error visszaadas
  syntaxHighLight(fileName, tokens, src.length, res, hierarchy, bigComments, bigCommentsLen);

  return tokens;
}

auto decodeBigComments(char[] raw){
  string[int] res;
  foreach(s; raw.toStr.split("\n")){
    string p0, p1;
    s.split2(":", p0, p1);
    res[p0.to!int] = p1;
  }
  return res;
}

struct SourceLine{ //SourceLine ///////////////////////////////
  string text;
  ubyte[] syntax;
  ushort[] hierarchy;
}

class SourceCode{ // SourceCode ///////////////////////////////
  File file;
  string text;

  //results after process:
  Token[] tokens;
  string error;
  ubyte[] syntax;
  ushort[] hierarchy;
  string[int] bigComments;

  void checkConsistency(){
//    enforce(text.length == lines.map!"a.length".sum + (max(lines.length.to!int-1, 0)), "text <> lines");
//    enforce(text.length == syntax.length, "text <> syntax");
//    enforce(text.length == hierarchy.length, "text <> hierarchy");
  }

  private void clearResult(){
    tokens = [];
    error = ``;
    syntax.clear;
    hierarchy.clear;
    bigComments.clear;
  }

  int lineCount(){
    if(tokens.empty) return text.count('\n').to!int+1;
    return tokens[$-1].line + text[tokens[$-1].pos..$].count('\n').to!int + 1;
  }

  auto seekLine(int lineDst){
    int pos, line;
    if(lineDst<=0) return pos;
    if(!tokens.empty){
      auto tokenIdx = tokens.map!"a.line".assumeSorted.lowerBound(lineDst-1).length.to!int-1;
      if(tokenIdx>0){
        pos  = tokens[tokenIdx].pos ;
        line = tokens[tokenIdx].line;
      }
    }

    if(line==lineDst) while(pos>0 && text[pos-1]!='\n') pos--;

    while(line<lineDst){
      auto i = text[pos..$].indexOf('\n');
      if(i<0) return text.length.to!int;

      pos += i+1;
      line++;
    }

    return pos;
  }

  int[2] getLineRange(int i){
    if(i<0 || i>=lineCount) return (int[2]).init;
    int pos = seekLine(i);
    auto j = text[pos..$].indexOf('\n');
    int pos2;
    if(j<0) pos2 = text.length.to!int;
       else pos2 = pos + j.to!int;
    return [pos, pos2];
  }

  auto getLine(int i){
    SourceLine res;

    auto r = getLineRange(i);
    if(r[0] < r[1]){
      res.text      = text     [r[0]..r[1]];
      res.syntax    = syntax   [r[0]..r[1]];
      res.hierarchy = hierarchy[r[0]..r[1]];
    }

    return res;
  }

  auto getLineText     (int i){ return getLine(i).text     ; }
  auto getLineSyntax   (int i){ return getLine(i).syntax   ; }
  auto getLineHierarchy(int i){ return getLine(i).hierarchy; }

  this(string text, File file){
    //lineOfs = chain([-1], lines.map!"cast(int)a.length".cumulativeFold!"a+b+1").array;

    this.text = text;
    this.file = file;

    process;
  }

  this(string text){ this(text, File("")); }
  this(File file){ this(file.readText, file); }

  void process(){
    clearResult;

    hierarchy.length = syntax.length = text.length;

    error = tokenize(file.fullName, text, tokens);

    if(error == ""){
      auto bigc = new char[0x10000];
      syntaxHighLight(file.fullName, tokens, text.length, syntax.ptr, hierarchy.ptr, bigc.ptr, bigc.length.to!int);
      bigComments = decodeBigComments(bigc);
    }else{
      WARN(error);
    }

    checkConsistency;
  }
}


struct Token{ // Token //////////////////////////////
  Variant data;
  int id; //emuns: operator, keyword
  int pos, length; //todo: length OR source is redundant
  int line, posInLine;
  int level; //hiehrarchy level in [] () {} q{}
  string source;

  @property int endPos() const{ return pos+length; }

  TokenKind kind;
  bool isTokenString; //it is inside the outermost tokenstring. Calculated in Parser.tokenize.BracketHierarchy, not in tokenizer.
  bool isBuildMacro; // //@ comments right after a newline or at the beginning of the file. Calculated in parser.collectBuildMacros

  /*string toString() const{
    return "%-20s: %s %s".format(kind, level, source);//~" "~(!data ? "" : data.text);
  }*/

  void toString(scope void delegate(const(char)[]) sink, FormatSpec!char fmt){
         if(fmt.spec == 'u') put(sink, format!"%-20s: %s %s"(kind, level, source));
    else if(fmt.spec == 't') put(sink, format!"%s\t%s\t%s"(kind, level, source));
    else put(sink, source ~ "("~level.text~")");
  }

  bool isOperator(int op)       const { return id==op && kind==TokenKind.operator; }
  bool isKeyword (int kw)       const { return id==kw && kind==TokenKind.keyword ; }
  bool isIdentifier()           const { return kind==TokenKind.identifier; }
  bool isIdentifier(string s)   const { return isIdentifier && source==s; }
  bool isComment()              const { return kind==TokenKind.comment; }
  bool isSlashSlasComment()     const { return isComment && source.startsWith("//"); }
  bool isDoxigenComment()       const { return isComment && ["///", "/**", "/++"].map!(a => source.startsWith(a)).any; }

  bool isString()               const { return kind==TokenKind.literalString; }
  bool isChar()                 const { return kind==TokenKind.literalChar; }
  bool isInt()                  const { return kind==TokenKind.literalInt; }
  bool isFloat()                const { return kind==TokenKind.literalFloat; }
  bool isNumeric()               const { return isInt || isFloat; }
  bool isLiteral()              const { return isString || isChar || isInt || isFloat; }

  bool isKeyword (in int[] kw)  const { return kind==TokenKind.keyword  && kw.map!(k => id==k).any; }
  bool isOperator(in int[] op)  const { return kind==TokenKind.operator && op.map!(o => id==o).any; }

  bool isAttribute() const {
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
    return isKeyword(allAttributes);
  }

  //shorthand
  //bool opEquals(string s) const { return source==s; } //note this conflicted with the linker when importing het.parser.

  void raiseError(string msg, string fileName=""){ throw new Exception(format(`%s(%d:%d): Error at "%s": %s`, fileName, line+1, posInLine+1, source, msg)); }
}


// token array helper functs ///////////////////////////////////////////////////////////////////////////

/// Returns a null token positioned on to the end of the token array
ref Token getNullToken(ref Token[] tokens){
  static Token nullToken;
  nullToken.source = "<NULL>";
  nullToken.pos = tokens.length ? tokens[$-1].endPos : 0;
  return nullToken;
}

/// Safely access a token in an array
ref Token getAny(ref Token[] tokens, size_t idx){
  return idx<tokens.length ? tokens[idx]
                           : tokens.getNullToken;
}

/// Safely access a token, skip comments
ref Token getNonComment(ref Token[] tokens, size_t idx){ //no comment version
  foreach(ref t; tokens){
    if(t.isComment) continue;
    if(!idx) return t;
    idx--;
  }
  return tokens.getNullToken;
}

/// helper template to check various things easily
bool isOp(string what)(ref Token[] tokens){
  auto t(size_t idx=0){ return tokens.getAny(idx); }
  auto tNC(size_t idx=0){ return tokens.getNonComment(idx); }

  //first check the combinations with the reduntant first part
  static if(what == "mixin template") return tokens.isOp!"mixin" && tNC(1).isKeyword(kwtemplate); //todo: op es kw legyen enum vagy legyen osszevonva. Bugoskohoz vezet, mert atfedesben van.

  //check keywords
  enum keywords = ["module", "import", "alias", "enum", "unittest", "this", "out", "struct", "union", "interface", "class", "if", "mixin", "template"];
  static foreach(k; keywords)
    static if(k == what) mixin( q{ return t.isKeyword(kw$); }.replace("$", k) );

  //check operators
  enum operators = [
    "{" : "curlyBracketOpen" , "(" : "roundBracketOpen" , "[" : "squareBracketOpen" ,
    "}" : "curlyBracketClose", ")" : "roundBracketClose", "]" : "squareBracketClose",
    ";" : "semiColon", ":" : "colon", "," : "coma", "@" : "atSign", "~" : "complement", "!" : "not",
    "is" : "is", "in" : "in", "new" : "new", "delete" : "delete" ];

  static foreach(k, v; operators)
    static if(what == k) mixin( q{ return t.isOperator(op$); }.replace("$", v) );

  //combinations
  static if(what.among("//", "/+", "/*")) return t.isComment;
  static if(what == "@("   ) return tokens.isOp!"@" && tNC(1).isOperator(opcurlyBracketOpen);
  static if(what == "~this") return tokens.isOp!"~" && tNC(1).isKeyword(kwthis);

  static if(what == "attribute") return t.isAttribute;
}

Token[][] splitTokens(string delim)(Token[] tokens, int level){
  if(tokens.empty) return [];

  enum delimMap = ["," : opcomma, ";" : opsemiColon, ":" : opcolon, "=" : opassign];
  enum op = delimMap[delim]; //todo: ezt az egeszet lehuzni a token beazonositas gyokereig

  return tokens.split!((in t) => t.level == level && t.isOperator(op));
}


class Tokenizer{ // Tokenizer ///////////////////////////////
public:
  string fileName;
  string text;
  int pos, textLength, line, posInLine;
  dchar ch; //actual character
  int skipCh; //size oh ch (1..4)
  Token[] res;   //should rename to tokens

  void error(string s){ throw new Exception(format("%s(%d:%d): Tokenizer error: %s", fileName, line, posInLine, s)); }

  static bool isEOF      (dchar ch) { return ch==0 || ch=='\x1A'; }
  static bool isNewLine  (dchar ch) { return ch=='\r' || ch=='\n'; }
  static bool isLetter   (dchar ch) { import std.uni; return isAlpha(ch) || ch=='_'; }//ch>='a' && ch<='z' || ch>='A' && ch<='Z' || ch=='_'; }
  static bool isDigit    (dchar ch) { return ch>='0' && ch<='9'; }
  static bool isOctDigit (dchar ch) { return ch>='0' && ch<='7'; }
  static bool isHexDigit (dchar ch) { return ch>='0' && ch<='9' || ch>='a' && ch<='f' || ch>='A' && ch<='F'; }

  void initFetch(){
    pos = posInLine = line = skipCh = 0;
    textLength = text.length.to!int;

    fetch;
  }

  void fetch(){
    pos += skipCh; posInLine += skipCh;
    if(pos<textLength){
      size_t nextPos = pos;
      //print("decoding at", pos);
      ch = decode!(Yes.useReplacementDchar)(text, nextPos);
      skipCh = cast(int)nextPos - pos;
      //print(">pos", pos, "char", ch, "skipCh", skipCh);
    }else{
      ch = 0;  //eof is ch
    }
  }

  void fetch(int n){ for(int i=0; i<n; ++i) fetch; } //todo: atirni ezeket az int-eket size_t-re es benchmarkolni.

  dchar peek(uint n=1){
    size_t p = pos;
    dchar res = 0;
    foreach(i; 0..n+1){
      if(p<text.length){
        res = decode!(Yes.useReplacementDchar)(text, p);
      }else
        break;
    }
    return res;
  }

  string fetchIdentifier() {
    string s;
    if(isLetter(ch)){
      s ~= ch; fetch;
      while(isLetter(ch) || isDigit(ch)){ s ~= ch; fetch; }
    }
    return s;
  }

  void incLine() { line++;  posInLine = 0; }

  int  expectHexDigit(dchar ch) { if(isDigit(ch)) return ch-'0'; if(ch>='a' && ch<='f') return ch-'a'; if(ch>='A' && ch<='F') return ch-'A'; error(`Hex digit expected instead of "%s".`.format(ch)); return -1; }
  int  expectOctDigit(dchar ch) { if(isOctDigit(ch)) return ch-'0'; error(`Octal digit expected instead of "%s".`.format(ch)); return -1; }

  bool isKeyword(string s) {
    return kwLookup(s)>=0;
  }

  void skipLineComment()
  {
    fetch;
    while(1){
      fetch;
      if(isEOF(ch) || isNewLine(ch)) break; //EOF of NL
    }
  }

  void skipNewLineOnce()
  {
         if(ch=='\r'){ fetch; if(ch=='\n') fetch; incLine; }
    else if(ch=='\n'){ fetch; if(ch=='\r') fetch; incLine; }
  }

  void skipNewLineMulti()
  {
    while(1){
           if(ch=='\r'){ fetch; if(ch=='\n') fetch; incLine; }
      else if(ch=='\n'){ fetch; if(ch=='\r') fetch; incLine; }
      else break;
    }
  }

  void skipBlockComment()
  {
    fetch;
    while(1){
      fetch;
      if(isEOF(ch)) return;//error("BlockComment is not closed properly."); //EOF
      skipNewLineMulti;
      if(ch=='*' && peek=='/'){
        fetch; fetch;
        break;
      }
    }
  }

  void skipNestedComment()
  {
    fetch;
    int cnt = 1;
    while(1){
      fetch;
      if(isEOF(ch)) return;//error("NestedComment is not closed properly."); //EOF
      skipNewLineMulti;
      if(ch=='/' && peek=='+'){
        fetch; cnt++;
      }else if(ch=='+' && peek=='/'){
        fetch; cnt--;
        if(cnt<=0) { fetch; break; }
      }
    }
  }

  void skipSpaces()
  {
    while(1){
      switch(ch){
        default: return;
        case ' ': case '\x09': case '\x0B': case '\x0C': { fetch; continue; }
      }
    }
  }

  bool skipWhiteSpaceAndComments() //returns true if eof
  {
    while(1){
      switch(ch){
        default:{
          return false;
        }
        case '\x00': case '\x1A':{ //EOF
          return true;
        }
        case ' ': case '\x09': case '\x0B': case '\x0C':{ //whitespace
          fetch;
          break;
        }
        case '\r':{ //NewLine1
          fetch;
          if(ch=='\n') fetch;
          incLine;
          break;
        }
        case '\n':{ //NewLine2
          fetch;
          if(ch=='\r') fetch;
          incLine;
          break;
        }
        case '/':{ //comment
          switch(peek){
            default: return false;
            case '/': newToken(TokenKind.comment); skipLineComment  ; finalizeToken; break;
            case '*': newToken(TokenKind.comment); skipBlockComment ; finalizeToken; break;
            case '+': newToken(TokenKind.comment); skipNestedComment; finalizeToken; break;
          }
          break;
        }
      }
    }
  }

  void newToken(TokenKind kind)
  {
    Token tk;
    tk.kind = kind;
    tk.pos = pos;
    tk.line = line;
    tk.posInLine = posInLine;
    res ~= tk;
  }

  void finalizeToken()
  {
    Token *t = &res[$-1];
    t.length = pos-t.pos;
    t.source = text[t.pos..pos];

    //print(t.line+1, t.posInLine+1);
  }

  ref Token lastToken() { return res[$-1]; }

  void removeLastToken() { res.length--; }

  void seekToEOF() { pos = textLength; ch = 0; }

  void revealSpecialTokens(){
    with(lastToken){
      if(kwIsSpecialKeyword(id)){
        switch(id){
          default                     :{ error("Unhandled keyword specialtoken: "~source); break; }
          case kw__EOF__              :{ seekToEOF; removeLastToken; break; }
          case kw__TIMESTAMP__        :{ kind = TokenKind.literalString; data = now.text; break; }
          case kw__DATE__             :{ kind = TokenKind.literalString; data = today.text; break; }
          case kw__TIME__             :{ kind = TokenKind.literalString; data = time.text; break; }
          case kw__VENDOR__           :{ kind = TokenKind.literalString; data = "realhet"; break; }
          case kw__VERSION__          :{ kind = TokenKind.literalInt   ; data = CompilerVersion;break; }
          case kw__FILE__             :{ import std.path; kind = TokenKind.literalString; data = baseName(fileName); break; }
          case kw__FILE_FULL_PATH__   :{ kind = TokenKind.literalString; data = fileName; break; }

//TODO: Ez kurvara nem igy megy: A function helyen kell ezt meghivni.
          case kw__LINE__             :{ kind = TokenKind.literalInt   ; data = line+1; break; }
          case kw__MODULE__           :{ kind = TokenKind.literalString; data = "module"; break; } //TODO
          case kw__FUNCTION__         :{ kind = TokenKind.literalString; data = "function"; break; } //TODO
          case kw__PRETTY_FUNCTION__  :{ kind = TokenKind.literalString; data = "pretty_function"; break; } //TODO
        }
      }else if(kwIsOperator(id)){
        switch(id){
          default: { error("Unhandled keyword operator: "~source); break; }
          case kwin: case kwis: case kwnew: case kwdelete:{
            kind = TokenKind.operator;
            id = opParse(source);
            if(!id) error("Cannot lookup keyword operator.");
          break; }
        }
      }
    }
  }

  void parseIdentifier() {
    newToken(TokenKind.identifier);

    fetch;
    while(isLetter(ch) || isDigit(ch)) fetch;

    finalizeToken();

    with(lastToken){ //set tokenkind kind

      //is it a keyword?
      int kw = kwLookup(source);
      if(kw){
        kind = TokenKind.keyword;
        id = kw;
        revealSpecialTokens; //is it a special keyword of operator?
      }
    }
  }

  string parseEscapeChar()
  {
    fetch;
    switch(ch){
      default: {
        //named character entries
        error(format(`Invalid char in escape sequence "%s" hex:%d`, ch, ch)); return "";
      }
      case '\'': case '\"': case '?': case '\\': { auto res = to!string(ch); fetch; return res; }
      case 'a': { fetch; return "\x07"; }
      case 'b': { fetch; return "\x08"; }
      case 'f': { fetch; return "\x0C"; }
      case 'n': { fetch; return "\x0A"; }
      case 'r': { fetch; return "\x0D"; }
      case 't': { fetch; return "\x09"; }
      case 'v': { fetch; return "\x0B"; }
      case 'x': { fetch;
        int x = expectHexDigit(ch); fetch;
        x = (x<<4) + expectHexDigit(ch); fetch;
        return to!string(cast(char)x);
      }
      case '0':..case '7': {
        int o;
        o = expectOctDigit(ch); fetch;
        if(isOctDigit(ch)) {
          o = (o<<3) + expectOctDigit(ch); fetch;
          if(isOctDigit(ch)) {
            o = (o<<3) + expectOctDigit(ch); fetch;
          }
        }
        return to!string(cast(char)o);
      }
      case 'u': case 'U':{
        int cnt = ch=='u' ? 4 : 8;
        fetch;
        int u;  for(int i=0; i<cnt; ++i){ u = (u<<4)+expectHexDigit(ch); fetch; }
        return to!string(cast(dchar)u);
      }
      case '&':{
        fetch;
        auto s = fetchIdentifier;
        if(ch!=';') error(`NamedCharacterEntry must be closed with ";".`);
        fetch;
        auto u = nceLookup(s);
        if(!u) error(`Unknown NamedCharacterEntry "`~s~`".`); //todo: this should be only a warning, not a complete failure

        return to!string(u);
      }
    }
  }

  void parseStringPosFix() {
    if(ch=='c' || ch=='w' || ch=='d') fetch;
  }

  void parseWysiwygString(bool handleEscapes=false, bool onlyOneChar=false){
    newToken(TokenKind.literalString);
    dchar ending;
    if(ch=='r'){ ending = '"'; fetch; fetch; }
          else { ending = ch; fetch; }
    string s;
    int cnt;
    while(1){
      cnt++;
      if(isEOF(ch)) error("Unexpected EOF in a WysiwygString.");
      if(ch==ending) { fetch; break; }
      if(isNewLine(ch)) { s ~= '\n'; skipNewLineOnce; continue; }
      if(handleEscapes && ch=='\\'){ s ~= parseEscapeChar; continue; }
      s ~= ch;  fetch;
    }
    parseStringPosFix;
    finalizeToken;
    lastToken.data = s;

    if(onlyOneChar && cnt!=2) error("Character constant must contain exactly one character.");
  }

  void parseDoubleQuotedString(){ parseWysiwygString(true); }
  void parseLiteralChar(){ parseWysiwygString(true, true); }

  void parseHexString(){
    newToken(TokenKind.literalString);
    fetch; fetch;
    bool phase;  string s;  int act;
    while(1){
      //EXTRA: Comments can be placed into hex strings.
      if(skipWhiteSpaceAndComments) error("Unexpected EOF in a HexString.");
      if(ch=='"') { fetch; break; }
      if(isHexDigit(ch)){
        int d = expectHexDigit(ch); fetch;
        if(!phase){
          act = d<<4;
        }else{
          act |= d;
          s ~= cast(char)act;
        }
        phase = !phase;
        continue;
      }
      error(`Invalid char in hex string literal: "%s"`.format(ch));
    }
    if(phase) error("HexString must contain an even number of digits.");
    parseStringPosFix;
    finalizeToken;
    lastToken.data = s;
  }

  void parseDelimitedString(){
    newToken(TokenKind.literalString);
    fetch; fetch; //q"..."

    string s;
    if(isLetter(ch)){ //identifier ending
      string ending = fetchIdentifier ~ `"`;
      if(!isNewLine(ch)) error("Delimited string: there must be a NewLine right after the identifier.");
      skipNewLineOnce;

      while(1){
        if(isEOF(ch)) error("Unexpected EOF in a DelimitedString.");

        if(isNewLine(ch)){
          skipNewLineOnce;
          s ~= '\n';
          continue;
        }

        if(posInLine==0){
          bool found = true;  foreach(idx, c; ending) if(peek(cast(int)idx)!=c){ found = false; break; }
          if(found){
            fetch(cast(int)ending.length-1); //not including ending "
            break;
          }
        }

        s ~= ch;  fetch;
      }
    }else{ //single char ending
      dchar ending;
      switch(ch){
        case '[': ending = ']'; break;
        case '<': ending = '>'; break;
        case '(': ending = ')'; break;
        case '{': ending = '}'; break;
        default:
          if(ch.inRange(' ', '~')) ending = ch;
                              else error(`Invalid char "%s" used as delimiter in a DelimitedString`.format(ch));
      }
      fetch;

      while(1){
        if(isEOF(ch)) error("Unexpected EOF in a DelimitedString.");
        if(ch==ending && peek=='"') { fetch; break; }
        if(isNewLine(ch)) { s ~= '\n'; skipNewLineOnce;  continue; }
        s ~= ch;  fetch;
      }
    }

    if(ch!='"') error(`Expecting an " at the end of a DelimitedString instead of "%s".`.format(ch));
    fetch;

    parseStringPosFix;
    finalizeToken;
    lastToken.data = s;
  }

  string parseInteger(int base)
  {
    string s;
    if(base==10){
      while(1){
        if(isDigit(ch)) { s ~= ch; fetch; continue; }
        if(ch=='_') { fetch; continue; }
        break;
      }
    }else if(base==2){
      while(1){
        if(ch=='0' || ch=='1') { s ~= ch; fetch; continue; }
        if(ch=='_') { fetch; continue; }
        break;
      }
    }else if(base==16){
      while(1){
        if(isHexDigit(ch)) { s ~= ch; fetch; continue; }
        if(ch=='_') { fetch; continue; }
        break;
      }
    }

    return s;
  }

  string expectInteger(int base)
  {
    auto s = parseInteger(base);
    if(s is null) error("A number was expected (in base:%d).".format(base));
    return s;
  }


  void parseNumber()
  {

    ulong toULong(string s, int base)
    {
      ulong a;
      if(base ==  2) foreach(ch; s) { a <<=  1;  a += ch-'0'; } else
      if(base == 10) foreach(ch; s) { a *=  10;  a += ch-'0'; } else
      if(base == 16) foreach(ch; s) { a <<=  4;  a += ch>='a' ? ch-'a'+10 :
                                                      ch>='A' ? ch-'A'+10 : ch-'0'; }
      return a;
    }

    newToken(TokenKind.literalInt);

    bool isFloat = false;
    int base = 10; //get base
    string whole, fractional, exponent;
    int expSign = 1;

    //parse float header
    if(ch=='0'){
      dchar ch1 = peek;
      if(ch1=='x' || ch1=='X') base = 16; else
      if(ch1=='b' || ch1=='B') base = 2;
      if(base!=10) fetch(2);//skip the header
    }

    //parse fractional part
    bool exponentDisabled;
    if(ch=='.' && peek!='.' && !isLetter(peek)){ //the number starts with a point
      whole = "0";
      isFloat = true;  fetch;  fractional = expectInteger(base);
    }else{ //the number continues with a point
      whole = expectInteger(base);
      if(ch=='.'){
        bool isNextDigit = isDigit(peek);
        if(base==16) isNextDigit |= isHexDigit(peek);
        if(isNextDigit){
          isFloat = true; fetch;  fractional = parseInteger(base); //number is optional.
          if(fractional is null) exponentDisabled = true;
        }
      }
    }

    //parse optional exponent
    if(!exponentDisabled)
    if((base<=10 && (ch=='e' || ch=='E'))
     ||(base<=16 && (ch=='p' || ch=='P'))) {
      isFloat = true;
      fetch;
      if(ch=='-') { fetch; expSign = -1; } else if(ch=='+') fetch; //fetch expsign
      exponent = expectInteger(10);
    }

    if(isFloat){ //assemble float
      //process float postfixes
      int size = 8;
      if(ch=='f' || ch=='F') { fetch; size = 4; }
      else if(ch=='L')       {  fetch; size = 10; }

      bool isImag;
      if(ch=='i')            { fetch; isImag = true; }

      //put it together
      real rbase = base;
      real num = toULong(whole, base);
      if(fractional !is null) num += toULong(fractional, base)*(rbase^^(-cast(int)fractional.length));
      if(exponent !is null) num *= to!real(base==10?10:2)^^(expSign*to!int(toULong(exponent, 10)));

      //place it into the correct type
      Variant v;
      if(isImag){
        if(size== 4) v = 1.0i * cast(float)num; else
        if(size== 8) v = 1.0i * cast(double)num; else
                     v = 1.0i * cast(real)num;
      }else{
        if(size== 4) v = cast(float) num; else
        if(size== 8) v = cast(double) num; else
                     v = cast(real) num;
      }

      finalizeToken;  lastToken.data = v;
    }else{ //assemble integer
      ulong num = toULong(whole, base);

      //fetch posfixes
      bool isLong, isUnsigned;
      if(ch=='L') { fetch; isLong = true; }
      if(ch=='u' || ch=='U') { fetch; isUnsigned = true; }
      if(!isLong && ch=='L') { fetch; isLong = true; }

      Variant v;
      if(!isLong && !isUnsigned){ //no postfixes
        if(num<=          0x7FFF_FFFF            ) v = cast(int)num; else
        if(num<=          0xFFFF_FFFF && base!=10) v = cast(uint)num; else //hex/bin can be unsigned too to use the smallest size as possible
        if(num<=0x7FFF_FFFF_FFFF_FFFF            ) v = cast(long)num;
                                              else v = num;
      }else if(isLong && isUnsigned){ //UL
        v = num;
      }else if(isLong){ //L
        if(num<=0x7FFF_FFFF_FFFF_FFFF) v = cast(long)num;
                                  else v = num;
      }else/*if(isUnsigned)*/{ //U
        if(num<=          0xFFFF_FFFF) v = cast(uint)num;
                                  else v = num;
      }

      finalizeToken;  lastToken.data = v;
    }
  }

  bool tryParseOperator()
  {
    int len;
    auto opId = opParse(text[pos..$], len);
    if(!opId) return false;

    newToken(TokenKind.operator);
    fetch(len);
    finalizeToken;
    lastToken.id = opId;

    return true;
  }

  string parseFilespec() //used in #line specialSequence
  {
    parseWysiwygString;
    auto res = to!string(lastToken.data);
    removeLastToken;
    return res;
  }

public:
  //returns the error or ""
  string tokenize(in string fileName, in string text, out Token[] tokens){
    auto enc = encodingOf(text);
    enforce(enc==TextEncoding.UTF8, "Tokenizer only works on UTF8 input. ("~enc.text~" detected)");

    this.fileName = fileName;
    this.text = text;

    initFetch;

    res = [];
    string errorStr;
    try{
      while(1){
        if(skipWhiteSpaceAndComments) break; //eof reached
        switch(ch){
          case 'a':..case 'z': case 'A':..case 'Z': case '_':{
            dchar nc = peek;
            if(nc=='"'){
              if(ch=='r'){ parseWysiwygString; break; }
              if(ch=='q'){ parseDelimitedString; break; }
              if(ch=='x'){ parseHexString; break; }
            }else if(nc=='{'){
              if(ch=='q'){ tryParseOperator; break; }
            }
            parseIdentifier;
            break;
          }
          case '"':{ parseDoubleQuotedString; break; }
          case '`':{ parseWysiwygString; break; }
          case '\'':{ parseLiteralChar; break; }
          case '0':..case '9':{ parseNumber; break; }
          case '.':{
            if(isDigit(peek)){ parseNumber; break; }
            goto default; //operator
          }
          case '#':{ //Special token sequences

            /* This #line can broke the codeeditor. Rather disable it
            if(text[pos..$].startsWith("#line")){ //lineNumber/fileName override
              fetch("#line".length.to!int);  skipSpaces;
              this.line = to!int(expectInteger(10))-2;  skipSpaces;
              if(ch=='"'){ this.fileName = parseFilespec;  skipSpaces;  }
              if(!isNewLine(ch)) error("NewLine character expected after #line SpecialTokenSequence.");

              break;
            }*/
            if(text[pos..$].startsWith("#define")){ //todo: highlight #define macros
            }

            goto default; //operator
          }
          default:{
            if(tryParseOperator) continue;
            if(isLetter(ch)){ parseIdentifier; continue; } //identifier with special letters
            //cannot identify it at all
            error(format("Invalid character [%s] hex:%x", ch, ch)); break;
          }
        }
      }
    }catch(Throwable o){
      errorStr = o.toString;
    }

    tokens = res;
    return errorStr;
  }

}//struct Tokenizer


int highlightPrecedenceOf(string op, bool isUnary)
{
  bool isBinary = !isUnary;

/*  if(op==";")return 1;
  if(op=="..")return 2;
  if(op==",")return 3;
  if(op=="=>")return 4;
  if(op=="=" || op=="-=" || op=="+=" || op=="<<=" || op==">>=" || op==">>>=" || op=="*=" || op=="/=" || op=="%=" || op=="^=" || op=="^^=" || op=="~=")return 5;
  if(op=="?" || op==":")return 6;
  if(op=="||")return 7;
  if(op=="&&")return 8;
  if(op=="|")return 9;
  if(op=="^")return 10;
  if(op=="&")return 11;
  if(op=="==" || op=="!=" || op==">" || op=="<" || op==">=" || op=="<=" || op=="!>" || op=="!<" || op=="!<=" || op=="!>=" || op=="<>" || op=="!<>" || op=="<>="  || op=="!<>="
    ||op=="is" || op=="in")return 12; //Todo: !is !in
  if(op=="<<" || op==">>" || op==">>>")return 13;
  if(isBinary) if(op=="+" || op=="-" || op=="~")return 14;
  if(isBinary) if(op=="*" || op=="/" || op=="%")return 15;
//no unary
  if(op=="^^")return 16;
  if(op=="." || op=="(" || op==")" || op=="[" || op=="]")return 17;*/

  return 0;

//  if(op=="!" && !isUnary) return 15;
//  if(op=="=>") return 14.5;
}

private ushort calcHierarchyWord(const Token t){
  if(t.isComment) return 0;

  int h = t.level | 0x2000; //isToken

  return cast(ushort)h;
}

private ushort spreadHierarchyWord(ushort h, bool st, bool en){
  if(!h) return 0;

  if(st) h |= 0x4000; //isTokenBegin
  if(en) h |= 0x8000; //isTokenEnd

  return h;
}

struct TokenizeResult{
  Token[] tokens;
  string error;
  ubyte[] syntax;
  ushort[] hierarchy;
  string bigComments;
}

auto tokenize2(string src, string fileName="", bool raiseError=true){ //it does the tokenizing and syntax highlighting
  TokenizeResult res;

  res.error = tokenize(fileName, src, res.tokens);
  enforce(!raiseError || res.error=="", "Tokenizer error: "~res.error);

  res.syntax.length    = src.length;
  res.hierarchy.length = src.length;

  auto bigTmp = new char[2048];
  syntaxHighLight(fileName, res.tokens, src.length, res.syntax.ptr, res.hierarchy.ptr, bigTmp.ptr, cast(int)bigTmp.length);

  res.bigComments = bigTmp.ptr.toStr;
  return res;
}

//todo: ezt a kibaszottnagy mess-t rendberakni it fent



void syntaxHighLight(string fileName, Token[] tokens, size_t srcLen, ubyte* res, ushort* hierarchy, char* bigComments, int bigCommentsLen) // SyntaxHighlight ////////////////////////////
{
  //todo: a delphis } bracket pa'rkereso is bugos: a stringekben levo {-en is megall.
  //todo: ezt az enumot kivinni es ubye tipusuva tenni, osszevonni
  enum { skWhiteSpace, skSelected, skFoundAct, skFoundAlso, skNavLink, skNumber, skString, skKeyword, skSymbol, skComment,
    skDirective, skIdentifier1, skIdentifier2, skIdentifier3, skIdentifier4, skIdentifier5, skIdentifier6, skLabel,
    skAttribute, skBasicType, skError, skBinary1 }

  //clear
  res[0..srcLen]       = 0;
  hierarchy[0..srcLen] = 0;

  //nested functs
  void fill(const Token t, ubyte cl){
    auto h = calcHierarchyWord(t);
    for(int j=0; j<t.length; j++){
      res[t.pos+j] = cl;
      hierarchy[t.pos+j] = spreadHierarchyWord(h, j==0, j==t.length-1);
    }
  }

  void overrideSyntaxHighLight(Token[] tokens)
  {
    //detect language
    string lang;
    foreach(t; tokens){
      if(t.kind==TokenKind.identifier){
        if(isGLSLInstruction(t.source)){ lang="GLSL"; break; }
        if(isGCNInstruction (t.source)){ lang="GCN"; break; }
      }
    }

    if(lang=="GLSL"){
      foreach(t; tokens){
        ubyte cl = GLSLInstructionKind(t.source);
                               //0:do nothing, 1:keyword, 2:typeQual,  3:types,     4:values,    5:functs,      6:vars
        static ubyte[] remap = [0,            skKeyword, skAttribute, skBasicType, skBasicType, skIdentifier5, skIdentifier6];
        if(cl) fill(t, remap[cl]);
      }
    }else if(lang=="GCN"){
      foreach(t; tokens){
        ubyte cl = GCNInstructionKind(t.source);
                   //vector, scalar, misc
        static ubyte[] remap2 = [0,   skIdentifier6, skIdentifier5, skIdentifier4]; //todo:GCN_options
        if(cl) fill(t, remap2[cl]);
      }
    }
  }

  bool nextIdIsAttrib;
  string[] nesting;
  int[] nestingOpeningIdx;

  string[int] bigCommentsMap;
  int lastBigCommentHeaderLine = -1;

  string stripSlashes(string s){
    s = s.strip;
    while(s.startsWith('/')) s = s[1..$  ];
    while(s.endsWith  ('/')) s = s[0..$-1];
    return s.strip;
  }

  foreach(idx, ref t; tokens)with(TokenKind){
    ubyte cl;

    //detect big comments
    enum bigCommentMinLength = 30;
    enum bigCommentMinSlashCount = 20;
    enum bigCommentEnding = "/".replicate(bigCommentMinSlashCount);
    if(t.isComment && t.source.length>bigCommentMinLength && t.source.startsWith("//")){
      auto s = t.source.strip;
      if(s.all!q{a=='/'}){
        lastBigCommentHeaderLine = t.line;
      }else if(s.endsWith(bigCommentEnding)){
        //take '/'s off of both sides
        bigCommentsMap[t.line] = stripSlashes(s);
      }else if(t.line==lastBigCommentHeaderLine+1 && s.startsWith("//") && s.endsWith("//")){
        bigCommentsMap[t.line] = "!"~stripSlashes(s);
      }
    }

    //nesting level calculation
    if(t.kind==operator){
      if(["{","[","(","q{"].canFind(t.source)){
        nesting ~= t.source;
        nestingOpeningIdx ~= cast(int)idx; //todo: normalis nevet talalni ennek, vagy bele egy structba
      }
    }

    t.level = cast(int)nesting.length;

    if(chkClear(nextIdIsAttrib) && t.kind==identifier){
      cl = skAttribute;
    }else switch(t.kind){
      default: break;
      case unknown      : cl = skError; break;
      case comment      : cl = skComment; break;
      case identifier   : cl = skIdentifier1; break;
      case keyword      : {
        with(KeywordCat) switch(kwCatOf(t.source)){
          case Attribute         : cl = skAttribute; break;
          case Value             : cl = skBasicType; break;
          case BasicType         : cl = skBasicType; break;
          case UserDefiniedType  : cl = skKeyword; break;
          case SpecialFunct      : cl = skAttribute; break;
          case SpecialKeyword    : cl = skKeyword; break;
          default                : cl = skKeyword; break;
        }
        break;
      }
      case special      : break;
      case operator     :{
             if(t.source=="@") { cl = skAttribute; nextIdIsAttrib = true; }
        else if(t.source=="#") { cl = skAttribute; nextIdIsAttrib = true; }
        else if(t.source=="q{") cl = skString;
        else if(t.source[0]>='a' && t.source[0]<='z') cl = skKeyword;
        else cl = skSymbol;

        break;
      }

      case literalString, literalChar: cl = skString; break;
      case literalInt, literalFloat: cl = skNumber; break;
    }

    //process nesting.closing errors
    if(t.kind==operator){
      if(["}","]",")"].canFind(t.source)){
        string opening, closing;
        if(!nesting.empty) opening = nesting[$-1];

             if(opening=="{" ) closing = "}";
        else if(opening=="q{") closing = "}";
        else if(opening=="[" ) closing = "]";
        else if(opening=="(" ) closing = ")";

        if(t.source==closing){
          if(opening=="q{"){
            cl = skString;
            overrideSyntaxHighLight(tokens[nestingOpeningIdx[$-1]+1..idx]);
          }

          //advance
          nesting = nesting[0..$-1];
          nestingOpeningIdx = nestingOpeningIdx[0..$-1];
        }else{
          //nesting error
          cl = skError;
          if(!nestingOpeningIdx.empty) fill(tokens[nestingOpeningIdx[$-1]], skError);
        }
      }
    }

    //fill it with the style
    fill(t, cl);
  }

  bigCommentsMap.rehash; //todo: revisit strings
  auto sBigComments = bigCommentsMap.byKeyValue.map!(a => format(`%s:%s`, a.key, a.value)).join("\r\n");
  sBigComments.length = min(sBigComments.length, bigCommentsLen);
  bigComments[0..sBigComments.length] = sBigComments[];
  bigComments[sBigComments.length] = '\0';
}

//GPU text editor format


////////////////////////////////////////////////////////////////////////////////

//TODO: rendberakni a commenteket
//TODO: unittest

/+
void main(string[] args)
{

  string s = q"END
    __LINE__ __FILE__
    a = b+c;

    /+/+nested comment+/+//*block comment*///line comment
    identifier case __FILE__

    r"wysiwygString1"c`wysiwygString2`w"doubleQuotedString"d //strings with optional posfixes
    x"40 /*hello*/ 41" //hex string with a comment
    '\u0040' '\u0177' "\U00000177\u03C0\x1fa\'a\b\b" //unicode chars
    "\&gt;\&amp;" //named character entries

    __DATE__ __TIME__ __TIMESTAMP__ __VENDOR__ __VERSION__ __FILE__ __LINE__ __DATETIME__

    0 1 12
    0.1 .1 1.
    0.12 .12 12.
    1e10 1e-10
    1.e30f
    11.5i
    0b11.1e1L
    0xff.0p-1

    //usual decimal notation (int, long, long ulong)
    2_147_483_647
    4_294_967_295
    9_223_372_036_854_775_807
    18_446_744_073_709_551_615
    //decimal with suffixes (long ulong uint ulong ulong
    9_223_372_036_854_775_807L
    18_446_744_073_709_551_615L
    4_294_967_295U
    9_223_372_036_854_775_807U
    4Lu
    //hex without suffix (int uint long, ulong)
    0x7FFF_FFFF
    0x8000_0000
    0x7FFF_FFFF_FFFF_FFFF
    0x8000_0000_0000_0000

    __LINE__
    __LINE__
    #line 6
    __LINE__
    __LINE__
    #line 66 "c:\override.d"
    __LINE__
    __LINE__ __FILE__

    //__EOF__

    q{tokenstring}
    q"{delimited{string}}"
END";



  s ~= `q"AHH
another delimited string
AHH"
`;//Note: it bugs in DMD: restarts the string from this string and adds another newline at the end.

  Tokenizer t;
  auto tokens = t.tokenize("testFileName.d", s);

  foreach(tk; tokens)writeln(format("%-14s %-32s %-20s %s", tk.kind, tk.source, to!string(tk.data.type), to!string(tk.data)));
  writeln("done");

//writeln(s);

//todo: optional string postfixes
}
+/

// JSON Support //////////////////////////////////////////////////

//discovers field, the start of each element in a json array or a json map
void discoverJsonHierarchy(ref Token[] tokens, string fileName="json_text"){
  if(tokens.empty) return;

  int level = 0;
  int[] expectStack;

  foreach(ref t; tokens){
    if(t.kind == TokenKind.operator){
      switch(t.id){
        case opsquareBracketOpen: case opcurlyBracketOpen:{
          t.level = level;
          level += 1;

          expectStack ~= t.id + 1; //closer op == opener op + 1
        break; }
        case opsquareBracketClose: case opcurlyBracketClose:{
          if(expectStack.empty) t.raiseError("Unexpected closing token.", fileName);
          if(expectStack[$-1] != t.id) t.raiseError("Mismatched closing token.", fileName);
          expectStack.popBack;

          level -= 1;
          t.level = level;
        break; }
        case opcomma:{
          t.level = level - 1;
        break; }
        case opcolon: case opsub:{
          t.level = level;
        break; }
        default: t.raiseError("Invalid symbol", fileName);
      }
    }else{
      if(t.kind.among(TokenKind.literalString, TokenKind.literalInt, TokenKind.literalFloat)
      ||(t.kind==TokenKind.keyword && t.id.among(kwfalse, kwtrue, kwnull))){
        t.level = level;
      }else{
        t.raiseError("Unknown token", fileName);
      }
    }
  }

  if(expectStack.length) tokens[$-1].raiseError("Expecting closing tokens. (%s)".format(expectStack.length), fileName);
  enforce(level==0, "Fatal error: JsonHierarchy level!=0");
}

// Big test //////////////////////////////////////////////

void testTokenizer(){
  double tTokenize = 0, tFull = 0;
  int size;

  string test(File f){
    Token[] tokens;
    auto s = f.readText;
    size += s.length;

    double t0 = QPS;
    tokenize(f.fullName, s, tokens);
    tTokenize += QPS-t0;

    t0 = QPS;
    auto res = tokenize2(s, f.fullName);
    tFull += QPS-t0;

    return res.text;
  }

  print("\n\nTesting tokenizer & syntax highlighter...");

  auto path = Path(`c:\d\libs\het\test\testTokenizerData`);
  auto s = path.files(`*.d`).map!(f => test(f)).join;

  File(path, `result.txt`).write(s);
  print("tokenizer time:", tTokenize, "size:", size, "MB/s:", size/1024.0/1024.0/tTokenize);
  print("full time:", tFull    , "size:", size, "MB/s:", size/1024.0/1024.0/tFull    );
  enforce(File(path, `reference.txt`).readText == s, "Tokenizer correctness test failed.");
  print("\33\12Tokenizer works correctly\33\7");

  /* Known results:
    200415:
      tokenizer time: 0.0538597 size: 1104899 MB/s: 19.564
      full time: 0.126472 size: 1104899 MB/s: 8.3316
    200415: unicode support: std.uni works well
      tokenizer time: 0.0707722 size: 1447158 MB/s: 19.5008
      full time: 0.165943 size: 1447158 MB/s: 8.31683
  */

}
