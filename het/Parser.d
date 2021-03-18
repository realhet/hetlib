module het.parser;

import het.utils, het.tokenizer, het.keywords, std.regex;

//todo: editor: mouse back/fwd navigalas, mint delphiben
//todo: 8K, 8M, 8G should be valid numbers! Preprocessing job...

//global thing to share compiler specific paths stuff
struct DPaths{   //todo: Path-osra atirni
static __gshared:
/*  string installPath = `c:\D\dmd2\`; //todo: it's not good for LDC2
  string stdPath()      { return installPath~`src\phobos\`; };
  string etcPath()      { return installPath~`src\phobos\`; };
  string corePath()     { return installPath~`src\druntime\src\`; };
  string libPath()      { return installPath~`windows\lib\`; } //todo: 64bit DPaths.libPath*/

  //LDC 64bit paths
  string installPath = `c:\D\ldc2\`;
  string stdImportPath()   { return installPath~`import\`; }
  string stdPath()      { return stdImportPath~`std\`; }
  string etcPath()      { return stdImportPath~`etc\`; }
  string corePath()     { return stdImportPath~`core\`; }
  string ldcPath()      { return stdImportPath~`ldc\`; }
  string libPath()      { return installPath~`lib64\`; }

  string[] systemPaths(){ return [stdPath, corePath, etcPath, ldcPath]; }
  string[] importPaths;
  string[] allPaths(){ return importPaths ~ systemPaths; }

  void init(){
    importPaths.clear;
  }

  void includeDelimiters(){
    foreach(ref p; importPaths) p = includeTrailingPathDelimiter(p);
  }

  void addImportPath(string path){
    path = path.strip;
    if(path.empty) return;
    foreach(p; importPaths) if(samePath(path, p)) return;
    importPaths ~= path.includeTrailingPathDelimiter;
  }

  void addImportPathList(string paths){
    foreach(path; paths.split(';')){
      addImportPath(path);
    }
  }

  string getImportPathList(){
    includeDelimiters;
    return importPaths.join(";");
  }

  bool isStdFile(in File f){
    return f.fullName.isWild(stdImportPath~"*");
  }
}

//////////////////////////////////////////////////////////////////////////////
//  Bracket Hierarchy Processor                                             //
//////////////////////////////////////////////////////////////////////////////

struct BracketHierarchyProcessor{
public:
  string fileName; //for error report
  string errorStr;
  bool wasError() const { return errorStr!=""; }

  string process(string fileName, ref Token[] tokens){
    this.fileName = fileName;
    queue = null;
    tokenStringLevel = 0;
    errorStr = "";

    foreach(ref t; tokens){
      process(t);
      if(wasError) break;
    }
    finalize;
    return errorStr;
  }

private:
  struct QueueRec{
    Token* startToken;
    bool isTokenString;
    int endOp;
  }

  QueueRec[] queue; //ending prackets land here
  int tokenStringLevel; //greater than 0 means inside a tokenstring

  void addError(Token* token, string err)
  {
    if(!wasError && err!=""){
      errorStr = format("%s(%s:%s): %s", fileName, token.line, token.posInLine, err);
    }
  }

  void process(ref Token t)
  {
    if(isClosingBracket(t)){
      if(queue.empty){
        addError(&t, format(`Unpaired closing bracket "%s".`, t.source));
      }else if(t.id!=queue.back.endOp){
        addError(&t, format(`Unpaired closing bracket "%s". Expected "%s".`, t.source, opStr(queue.back.endOp)));
      }else{
        if(queue.back.isTokenString) tokenStringLevel--;
        queue.popBack;
      }
    }

    t.level = queue.length.to!int;
    t.isTokenString = tokenStringLevel>0;

    if(int eb = endingBracketOf(t)){
      bool isTS = t.id==optokenString;
      queue ~= QueueRec(&t, isTS, eb);
      if(isTS) tokenStringLevel++;
    }
  }

  void finalize(){
    if(queue.length) with(queue.back){
      addError(startToken, format(`Closing bracket expected: "%s".`, opStr(endOp)));
    }
  }

  static bool isClosingBracket(ref Token t){
    if(t.kind!=TokenKind.operator) return false;
    switch(t.id){
      case oproundBracketClose: case opsquareBracketClose: case opcurlyBracketClose: return true;
      default: return false;
    }
  }
  static int endingBracketOf(ref Token t) {
    if(t.kind!=TokenKind.operator) return 0;
    switch(t.id){
      case oproundBracketOpen : return oproundBracketClose;
      case opsquareBracketOpen: return opsquareBracketClose;
      case opcurlyBracketOpen: case optokenString: return opcurlyBracketClose;
      default: return 0;
    }
  }

  unittest{
    bool test(string text){
      Token[] tokens;
      auto err = tokenize("", text, tokens);
      BracketHierarchyProcessor bhp;
      return bhp.process("", tokens)=="";
    }
    assert(test("a"));
    assert(test("{}[]()q{}"));
    assert(test("{((a))[()]}"));
    assert(!test("}"));
    assert(!test("(}"));
    assert(!test("{"));
  }
}

//////////////////////////////////////////////////////////////////////////////
//  ImportDeclaration                                                       //
//////////////////////////////////////////////////////////////////////////////

struct ModuleFullName{
  string[] identifiers;
  string fullName() const { return identifiers.join('.'); };
  string fileName() const { return identifiers.length ? identifiers.join('\\')~".d" : ""; };
}

struct ImportBind{
  string alias_, name;
}

struct ImportDecl{
  ModuleFullName name;
  string alias_;
  bool isPublic, isStatic;
  ImportBind[] binds;

  private bool nameStartsWith(string s) const { return name.identifiers.length && name.identifiers[0]==s; }
  bool isStdModule () const { return nameStartsWith("std"); }
  bool isEtcModule () const { return nameStartsWith("etc"); }
  bool isCoreModule() const { return nameStartsWith("core"); }
  bool isUserModule() const { return !isStdModule && !isCoreModule; }

  string resolveFileName(string mainPath, string baseFileName, bool mustExists) const //returns "" if not found. Must handle outside.
  { //todo: use FileName, FilePath
    const fn = name.fileName;
    string[] paths = isStdModule  ? [ DPaths.stdPath ] :
                     isEtcModule  ? [ DPaths.etcPath ] :
                     isCoreModule ? [ DPaths.corePath ]
                                  : [ mainPath ] ~ DPaths.importPaths;
    string s;
    foreach(p; paths){
      s = includeTrailingPathDelimiter(p)~fn;
      if(File(s).exists) return s; //it's a module
      s = File(s).otherExt("").fullName ~ `\package.d`;
      if(File(s).exists) return s; //it's a module
    }

    if(mustExists) throw new Exception("Module not found: "~fn~"  referenced from: "~baseFileName);
    return "";
  }
}

//////////////////////////////////////////////////////////////////////////////
//  Parser                                                                  //
//////////////////////////////////////////////////////////////////////////////

class Parser{
  string fileName, source;
  Token[] tokens;

  string[] buildMacros;
  string[] todos;
  ImportDecl[] importDecls;

  string errorStr;
  bool wasError() const                    { return errorStr!=""; }
  private void error(string err)           { if(!wasError) errorStr = err; }
  private void error(Token* t, string err) { error(format("%s(%d:%d): %s", fileName, t.line, t.posInLine, err)); }

  //stats
  int sourceLines()     { return tokens.empty ? 0 : tokens[$-1].line+1; }

  //1. Tokenize
  void tokenize(string fileName){ tokenize(fileName, File(fileName).readText); }
  void tokenize(string fileName, string source){
    this.fileName = fileName;
    this.source = source;
    this.buildMacros.clear;
    this.todos.clear;

    //Tokenizing
    auto tokenizer = scoped!Tokenizer;
    string tokenizerError = tokenizer.tokenize(fileName, source, tokens);
    if(tokenizerError!="") error(tokenizerError);

    //Bracket Hierarchy
    if(!wasError){
      BracketHierarchyProcessor bhp;
      error(bhp.process(fileName, tokens));
    }

    //build macros //*compile //*run, etc
    collectBuildMacrosAndTodos(buildMacros, todos);

    //find all import declarations
    importDecls = collectImports;
  }

private: /////////////////////////////////////////////////////////////////////


  //parser functionality
  auto extractUntilOp(int idx, int opEnd){
    if(idx>=tokens.length) return null;
    Token*[] res;
    int level = tokens[idx].level;
    for(; idx<tokens.length; idx++){
      auto act = &tokens[idx];
      if(act.isComment) continue;
      if(act.level<level) return null; //lost the scope too early
      if(act.isOperator(opEnd)) return res; //gotcha
      res ~= act; //accumulate
    }
    return null; //can't find opEnd
  }

  auto findAllKeywordIndices(int kw, bool insideTokenStringsToo = false){
    int[] res;
    foreach(i, ref t; tokens){
      if(t.isTokenString && !insideTokenStringsToo) continue;
      if(t.isKeyword(kw)) res ~= i.to!int;
    }
    return res;
  }

  auto findFirstKeywordIndex(int kw, bool insideTokenStringsToo = false){
    foreach(i, ref t; tokens){
      if(t.isTokenString && !insideTokenStringsToo) continue;
      if(t.isKeyword(kw)) return i.to!int;
    }
    return -1;
  }

  //parse all module imports in the file   //todo: errol syntax highlight
  auto collectBuildMacrosAndTodos(out string[] macros, out string[] todos) //updates Token.isBuildCommant
  {
    auto rxTodo = ctRegex!(`\/\/todo:(.*)`, `gi`);
    auto rxOpt  = ctRegex!(`\/\/opt:(.*)`, `gi`);

    foreach(ref cmt; tokens){
      if(cmt.isComment){
        if(cmt.posInLine==0 && cmt.source.startsWith("//@")){  //todo: ezt berakni a tokenizerbe
          auto line = cmt.source[3..$];

          //extract command word
          int i = line.indexOf(' ').to!int;
          if(i<0) i = line.length.to!int;
          string command = lc(line[0..i]);

          //check if command is valid
          const validCmds = ["exe", "dll", "res", "def", "win", "compile", "link", "run", "import", "release", "single", "ldc"]; //todo: ezt szepen megcsinalni IDkkel
          if(validCmds.canFind(command)){
            cmt.isBuildMacro = true;
            macros ~= line;
          }
        }else{
          string s, t;
          auto m = cmt.source.matchFirst(rxTodo);
          if(!m.empty){
            t = "Todo";  s = m[1];
          }else{
            m = cmt.source.matchFirst(rxOpt);
            if(!m.empty){
              t = "Opt";  s = m[1];
            }
          }

          s = s.strip;
          if(!s.empty){
            todos ~= format(`%s(%d,%d): %s: %s`, fileName, cmt.line+1, cmt.posInLine+1, t, s);
          }
        }
      }
    }
  }

  //parser stuff////////////////////////////////////////////////////////////////////////
  int actIdx;
  Token* sym; //act symbol
  bool eof;
  Token nullToken;

  void seek(int n){
    actIdx = n;
    while(actIdx<tokens.length && tokens[actIdx].isComment) actIdx++; //skip comments
    eof = actIdx>=tokens.length;
    sym = eof ? &nullToken : &tokens[actIdx];
  }

  bool nextSym(){
    if(!eof){
      seek(actIdx+1); return true;
    }else{
      return false;
    }
  }

  bool acceptKw(int kw){ bool b = sym.isKeyword (kw); if(b) nextSym; return b; }
  bool acceptOp(int op){ bool b = sym.isOperator(op); if(b) nextSym; return b; }

  //todo: ezt megcsinalni, hogy kozos id-je legyen az operatoroknak meg a keyworokdnek is
  void expectKw(int kw){ if(sym.isKeyword (kw)) nextSym; else error(format(`"%s" expected.`, kwStr(kw))); }
  void expectOp(int op){ if(sym.isOperator(op)) nextSym; else error(format(`"%s" expected.`, opStr(op))); }

  auto expectIdentifier() {
    if(sym.kind!=TokenKind.identifier) error("Identifier expected.");
    string s = sym.source;  nextSym;
    return s;
  }

  auto expectIdentifierList(int opSeparator){
    string[] res;
    do{
      res ~= expectIdentifier;
    }while(acceptOp(opSeparator));
    return res;
  }

  //end of parser stuff/////////////////////////////

  //find the module keyword and get the full module name.
  public auto getModuleFullName()
  {
     string res;
     auto idx = findFirstKeywordIndex(kwmodule);
     if(idx>=0){
       idx++;
       while(idx<tokens.length && tokens[idx].isComment) idx++;
       while(idx<tokens.length && (tokens[idx].isIdentifier || tokens[idx].isOperator(opdot))){
         res ~= tokens[idx].source;
         idx++;
       }
     }
     return res;
  }

  //parse all module imports in the file
  auto collectImports()
  {
    //TODO:public/static/private imports
    ImportDecl[] res;

    auto importTokensIndices = findAllKeywordIndices(kwimport, true);
    foreach(idx; importTokensIndices){

      seek(idx);
      if(acceptKw(kwimport)){
        nextModule:
        res.length++;
        auto decl = &res.back;

        //[alias =] module[full]name
        auto sl = expectIdentifierList(opdot);
        if(acceptOp(opassign)){ //alias
          if(sl.length>1) error(`Alias can't contain multiple identifiers.`);
          decl.alias_ = sl[0];
          decl.name.identifiers = expectIdentifierList(opdot);
        }else{
          decl.name.identifiers = sl;
        }

        if(acceptOp(opcomma)){ //has more modules
          goto nextModule;
        }else if(acceptOp(opcolon)){ //current module has bindings
          nextBind:
          decl.binds.length++;
          auto bind = &decl.binds.back;

          auto s = expectIdentifier;
          if(acceptOp(opassign)){ //bind alias
            bind.alias_ = s;
            bind.name = expectIdentifier;
          }else{
            bind.name = s;
          }

          if(acceptOp(opcomma)){ //has more binds
            goto nextBind;
          }
        }
        expectOp(opsemiColon);
      }

    }
    return res;
  }



}