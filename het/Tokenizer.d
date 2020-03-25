module het.tokenizer;
import het.utils, het.keywords, std.variant;
                                          //todo: size_t-re atallni

const CompilerVersion = 100;

//TODO: DIDE jegyezze meg a file kurzor/ablak-poziciokat is
//TODO: kulon kezelni az in-t, mint operator es mint type modifier
//TODO: ha elbaszott string van, a parsolas addigi eredmenye ne vesszen el, hogy a syntaxHighlighter tudjon vele mit kezdeni
//TODO: syntax highlight: a specialis karakter \ dolgoknak a stringekben lehetne masmilyen szine.
//TODO: syntax highlight: a tokenstring egesz hatter alapszine legyen masmilyen. Ezt valahogy bele kell vinni az uj editorba.
//TODO: editor: save form position FFS
//todo: syntax: x"ab01" hex stringeket kezelni. Bugos

//refactor to anonym -> ebben elvileg a delphi jobb.

//todo: camelCase
enum TokenKind {Unknown, Comment, Identifier, Keyword, Special, Operator, LiteralString, LiteralChar, LiteralInt, LiteralFloat};

@trusted string tokenize(string fileName, string text, out Token[] tokens)
{ Tokenizer t;  return t.tokenize(fileName, text, tokens); }

Token[] syntaxHighLight(string fileName, string src, ubyte* res, ushort* hierarchy, char* bigComments, int bigCommentsLen)
{
  Token[] tokens;
  tokenize("", src, tokens);    //todo: nem jo, nincs error visszaadas

  syntaxHighLight(fileName, tokens, src.length, res, hierarchy, bigComments, bigCommentsLen);

  return tokens;
}

struct Token{
  Variant data;
  int id; //emuns: operator, keyword
  int pos, length, line, posInLine;
  int level; //hiehrarchy level in [] () {} q{}
  string source;

  TokenKind kind;
  bool isTokenString; //it is inside the outermost tokenstring. Calculated in Parser.tokenize.BracketHierarchy, not in tokenizer.
  bool isBuildMacro; // //@ comments right after a newline or at the beginning of the file. Calculated in parser.collectBuildMacros

  /*string toString() const{
    return "%-20s: %s %s".format(kind, level, source);//~" "~(!data ? "" : data.text);
  }*/

  void toString(scope void delegate(const(char)[]) sink, FormatSpec!char fmt){
    if(fmt.spec == 't') put(sink, format!"%s\t%s\t%s"(kind, level, source));
                   else put(sink, format!"%-20s: %s %s"(kind, level, source));
  }

  bool isOperator(int op)       const { return id==op && kind==TokenKind.Operator; }
  bool isKeyword (int kw)       const { return id==kw && kind==TokenKind.Keyword ; }
  bool isIdentifier()           const { return kind==TokenKind.Identifier; }
  bool isIdentifier(string s)   const { return isIdentifier && source==s; }
  bool isComment()              const { return kind==TokenKind.Comment; }
}

class Tokenizer{
public:
  string fileName;
  string text;
  int pos, line, posInLine;
  char ch; //actual character
  Token[] res;   //should rename to tokens

  void error(string s){ throw new Exception(format("%s(%d:%d): Tokenizer error: %s", fileName, line, posInLine, s)); }

  void fetch(){
    pos++; posInLine++;
    if(pos>=text.length){
      ch=0;  //eof is ch
    }else{
      ch = text[pos];
    }
  }

  void fetch(int n){ for(int i=0; i<n; ++i) fetch; } //todo: atirni ezeket az int-eket size_t-re es benchmarkolni.

  char peek(int n=1){
    if(pos+n>=text.length) return 0;
                      else return text[pos+n];
  }

  void incLine() { line++;  posInLine = 0; }

  static bool isEOF      (char ch) { return ch==0 || ch=='\x1A'; }
  static bool isNewLine  (char ch) { return ch=='\r' || ch=='\n'; }
  static bool isLetter   (char ch) { return ch>='a' && ch<='z' || ch>='A' && ch<='Z' || ch=='_'; }
  static bool isDigit    (char ch) { return ch>='0' && ch<='9'; }
  static bool isOctDigit (char ch) { return ch>='0' && ch<='7'; }
  static bool isHexDigit (char ch) { return ch>='0' && ch<='9' || ch>='a' && ch<='f' || ch>='A' && ch<='F'; }
  int  expectHexDigit(char ch) { if(isDigit(ch)) return ch-'0'; if(ch>='a' && ch<='f') return ch-'a'; if(ch>='A' && ch<='F') return ch-'A'; error(`Hex digit expected instead of "`~ch~`".`); return -1; }
  int  expectOctDigit(char ch) { if(isOctDigit(ch)) return ch-'0'; error(`Octal digit expected instead of "`~ch~`".`); return -1; }

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

  void skipBlockComment()
  {
    fetch;
    while(1){
      fetch;
      if(isEOF(ch)) return;//error("BlockComment is not closed properly."); //EOF
      skipNewLine;
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
      skipNewLine;
      if(ch=='/' && peek=='+'){
        fetch; cnt++;
      }else if(ch=='+' && peek=='/'){
        fetch; cnt--;
        if(cnt<=0) { fetch; break; }
      }
    }
  }

  void skipNewLine()
  {
         if(ch=='\r'){ fetch; if(ch=='\n') fetch; incLine; }
    else if(ch=='\n'){ fetch; if(ch=='\r') fetch; incLine; }
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
            case '/': newToken(TokenKind.Comment); skipLineComment  ; finalizeToken; break;
            case '*': newToken(TokenKind.Comment); skipBlockComment ; finalizeToken; break;
            case '+': newToken(TokenKind.Comment); skipNestedComment; finalizeToken; break;
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
  }

  ref Token lastToken() { return res[$-1]; }

  void removeLastToken() { res.length--; }

  void seekToEOF() { pos = cast(int)text.length; ch = 0; }

  string fetchIdentifier() {
    string s;
    if(isLetter(ch)){
      s ~= ch; fetch;
      while(isLetter(ch) || isDigit(ch)){ s ~= ch; fetch; }
    }
    return s;
  }

  string peekIdentifier(int pos) {
    string s;
    char ch = peek(pos++);
    if(!isLetter(ch)) return s;
    s ~= ch;
    while(1){
      ch = peek(pos++);
      if(!isLetter(ch) && !isDigit(ch)) break;
      s ~= ch;
    }
    return s;
  }

  void revealSpecialTokens(){
    with(lastToken){
      if(kwIsSpecialKeyword(id)){
        switch(id){
          default                     :{ error("Unhandled keyword specialtoken: "~source); break; }
          case kw__EOF__              :{ seekToEOF; removeLastToken; break; }
          case kw__TIMESTAMP__        :{ kind = TokenKind.LiteralString; data = now.text; break; }
          case kw__DATE__             :{ kind = TokenKind.LiteralString; data = today.text; break; }
          case kw__TIME__             :{ kind = TokenKind.LiteralString; data = time.text; break; }
          case kw__VENDOR__           :{ kind = TokenKind.LiteralString; data = "realhet"; break; }
          case kw__VERSION__          :{ kind = TokenKind.LiteralInt   ; data = CompilerVersion;break; }
          case kw__FILE__             :{ import std.path; kind = TokenKind.LiteralString; data = baseName(fileName); break; }
          case kw__FILE_FULL_PATH__   :{ kind = TokenKind.LiteralString; data = fileName; break; }

//TODO: Ez kurvara nem igy megy: A function helyen kell ezt meghivni.
          case kw__LINE__             :{ kind = TokenKind.LiteralInt   ; data = line+1; break; }
          case kw__MODULE__           :{ kind = TokenKind.LiteralString; data = "module"; break; } //TODO
          case kw__FUNCTION__         :{ kind = TokenKind.LiteralString; data = "function"; break; } //TODO
          case kw__PRETTY_FUNCTION__  :{ kind = TokenKind.LiteralString; data = "pretty_function"; break; } //TODO
        }
      }else if(kwIsOperator(id)){
        switch(id){
          default: { error("Unhandled keyword operator: "~source); break; }
          case kwin: case kwis: case kwnew: case kwdelete:{
            kind = TokenKind.Operator;
            id = opParse(source);
            if(!id) error("Cannot lookup keyword operator.");
          break; }
        }
      }
    }
  }

  void parseIdentifier() {
    newToken(TokenKind.Identifier);

    fetch;
    while(isLetter(ch) || isDigit(ch)) fetch;

    finalizeToken();

    with(lastToken){ //set tokenkind kind

      //is it a keyword?
      int kw = kwLookup(source);
      if(kw){
        kind = TokenKind.Keyword;
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
        if(!u) error(`Unknown NamedCharacterEntry "`~s~`".`);

        return to!string(u);
      }
    }
  }

  void parseStringPosFix() {
    if(ch=='c' || ch=='w' || ch=='d') fetch;
  }

  void parseWysiwygString(bool handleEscapes=false, bool onlyOneChar=false){
    newToken(TokenKind.LiteralString);
    char ending;
    if(ch=='r'){ ending = '"'; fetch; fetch; }
          else { ending = ch; fetch; }
    string s;
    int cnt;
    while(1){
      cnt++;
      if(isEOF(ch)) error("Unexpected EOF in a WysiwygString.");
      if(ch==ending) { fetch; break; }
      if(isNewLine(ch)) { s ~= '\n'; skipNewLine; continue; }
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
    newToken(TokenKind.LiteralString);
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
      error("Invalid char in hex string literal: ["~ch~"]");
    }
    if(phase) error("HexString must contain an even number of digits.");
    parseStringPosFix;
    finalizeToken;
    lastToken.data = s;
  }

  void parseDelimitedString(){
    newToken(TokenKind.LiteralString);
    fetch; fetch; //q"..."

    string s;
    if(isLetter(ch)){ //identifier ending
      string ending = fetchIdentifier;
      if(!isNewLine(ch)) error("Delimited string: there must be a NewLine right after the identifier.");
      skipNewLine;

      while(1){
        if(isEOF(ch)) error("Unexpected EOF in a DelimitedString.");
        if(isNewLine(ch)){
          skipNewLine;

          bool found = true;  foreach(idx, c; ending) if(peek(idx.to!int)!=c){ found = false; break; }
          if(found){
            fetch(cast(int)ending.length);
            break;
          }

          s ~= '\n';
          continue;
        }
        s ~= ch;  fetch;
      }
    }else{ //single char ending
      char ending;
           if(ch=='[') ending = ']';
      else if(ch=='<') ending = '>';
      else if(ch=='(') ending = ')';
      else if(ch=='{') ending = '}';
      else if(ch>=' ' || ch<='~') ending = ch;
      else error(`Invalid char "`~ch~`" used as delimiter in a delimited string`);
      fetch;

      while(1){
        if(isEOF(ch)) error("Unexpected EOF in a DelimitedString.");
        if(ch==ending && peek=='"') { fetch; break; }
        if(isNewLine(ch)) { s ~= '\n'; skipNewLine;  continue; }
        s ~= ch;  fetch;
      }
    }

    if(ch!='"') error(`Expecting an " at the end of a DelimitedString instead of "`~ch~`".`);
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

    newToken(TokenKind.LiteralInt);

    bool isFloat = false;
    int base = 10; //get base
    string whole, fractional, exponent;
    int expSign = 1;

    //parse float header
    if(ch=='0'){
      char ch1 = peek;
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

    newToken(TokenKind.Operator);
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
  string tokenize(const string fileName, const string text, out Token[] tokens){
    this.fileName = fileName;
    this.text = text;
    line = 0;
    pos = posInLine = -1; fetch; //fetch the first char
    res = null;
    string errorStr;
    try{
      while(1){
        if(skipWhiteSpaceAndComments) break; //eof reached
        switch(ch){
          default:{
            if(tryParseOperator) continue;
            //cannot identify it at all
            error(format("Invalid character [%s] hex:%x", ch, ch)); break;
          }
          case 'a':..case 'z': case 'A':..case 'Z': case '_':{
            char nc = peek;
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
            auto s = peekIdentifier(1);
            if(s=="line"){ //lineNumber/fileName override
              fetch(1+line.sizeof);  skipSpaces;
              this.line = to!int(expectInteger(10))-2;  skipSpaces;
              if(ch=='"'){ this.fileName = parseFilespec;  skipSpaces;  }
              if(!isNewLine(ch)) error("NewLine character expected after #line SpecialTokenSequence.");

              break;
            }
            goto default; //operator
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



void syntaxHighLight(string fileName, Token[] tokens, size_t srcLen, ubyte* res, ushort* hierarchy, char* bigComments, int bigCommentsLen)
{
  //todo: a delphis } bracket pa'rkereso is bugos: a stringekben levo {-en is megall.

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
      if(t.kind==TokenKind.Identifier){
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
    const bigCommentMinLength = 30;
    const bigCommentMinSlashCount = 20;
    if(t.isComment && t.source.length>bigCommentMinLength && t.source.startsWith("//")){
      if(t.source.strip.all!q{a=='/'}){
        lastBigCommentHeaderLine = t.line;
      }else if(t.source.strip.endsWith("/".replicate(bigCommentMinSlashCount))){
        //take '/'s off of both sides
        bigCommentsMap[t.line] = stripSlashes(t.source);
      }else if(t.line==lastBigCommentHeaderLine+1 && t.source.startsWith("//") && t.source.endsWith("//")){
        bigCommentsMap[t.line] = "!"~stripSlashes(t.source);
      }
    }

    //nesting level calculation
    if(t.kind==Operator){
      if(["{","[","(","q{"].canFind(t.source)){
        nesting ~= t.source;
        nestingOpeningIdx ~= idx.to!int; //todo: normalis nevet talalni ennek, vagy bele egy structba
      }
    }

    t.level = cast(int)nesting.length;

    if(chkClear(nextIdIsAttrib) && t.kind==Identifier){
      cl = skSymbol;
    }else switch(t.kind){
      default: break;
      case Unknown      : cl = skError; break;
      case Comment      : cl = skComment; break;
      case Identifier   : cl = skIdentifier1; break;
      case Keyword      : {
        with(KeywordCat) switch(kwCatOf(t.source)){
          default                : cl = skKeyword; break;
          case Attribute         : cl = skAttribute; break;
          case Value             : cl = skBasicType; break;
          case BasicType         : cl = skBasicType; break;
          case UserDefiniedType  : cl = skKeyword; break;
          case SpecialFunct      : cl = skAttribute; break;
          case SpecialKeyword    : cl = skKeyword; break;
        }
        break;
      }
      case Special      : break;
      case Operator     :{
             if(t.source=="@") { cl = skSymbol; nextIdIsAttrib = true; }
        else if(t.source=="q{") cl = skString;
        else if(t.source[0]>='a' && t.source[0]<='z') cl = skKeyword;
        else cl = skSymbol;

        break;
      }

      case LiteralString: case LiteralChar: cl = skString; break;
      case LiteralInt: case LiteralFloat: cl = skNumber; break;
    }

    //process nesting.closing errors
    if(t.kind==Operator){
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
