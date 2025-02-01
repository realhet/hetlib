module het.parser;  import het, std.regex, std.variant; 
version(/+$DIDE_REGION Tokenizer+/all)
{
	
	//Todo: size_t-re atallni
	//TEST: testTokenizer()
	
	const CompilerVersion = 100; 
	
	//Todo: __EOF__ means end of file , must work inside a comment as well
	
	//Todo: DIDE jegyezze meg a file kurzor/ablak-poziciokat is
	//Todo: kulon kezelni az in-t, mint operator es mint type modifier
	//Todo: ha elbaszott string van, a parsolas addigi eredmenye ne vesszen el, hogy a syntaxHighlighter tudjon vele mit kezdeni
	//Todo: syntax highlight: a specialis karakter \ dolgoknak a stringekben lehetne masmilyen szine.
	//Todo: syntax highlight: a tokenstring egesz hatter alapszine legyen masmilyen. Ezt valahogy bele kell vinni az uj editorba.
	//Todo: editor: save form position FFS
	//Todo: syntax: x"ab01" hex stringeket kezelni. Bugos
	
	//refactor to anonym -> ebben elvileg a delphi jobb.
	
	//Todo: camelCase
	
	//Todo: highlight escaped strings
	//Todo: highlight regex strings
	//Todo: nem kell a token.data-t azonnal kiszamolni. Csak lazy modon.
	//Todo: TokenKind. camelCase
	
	//Todo: "/+ newline //+ is bad.
	
	//Todo: detect 3 spaces exotic indent.
	
	enum TokenKind
	{ unknown, comment, identifier, keyword, special, operator, literalString, literalChar, literalInt, literalFloat} ; 
	
	@trusted string tokenize(string fileName, string sourceText, out Token[] tokens, WhitespaceStats* whitespaceStats=null) //returns error of any
	{ auto t = scoped!Tokenizer;  return t.tokenize(fileName, sourceText, tokens, whitespaceStats); } 
	
	deprecated("use SourceCode class") Token[] syntaxHighLight(string fileName, string src, ubyte* res, ushort* hierarchy, char* bigComments, int bigCommentsLen)
	{
		Token[] tokens; 
		tokenize("", src, tokens);    //Todo: nem jo, nincs error visszaadas
		syntaxHighLight(fileName, tokens, src.length, res, hierarchy, bigComments, bigCommentsLen); 
		
		return tokens; 
	} 
	
	auto decodeBigComments(char[] raw)
	{
		string[int] res; 
		foreach(s; raw.toStr.split("\n"))
		{
			string p0, p1; 
			s.split2(":", p0, p1); 
			res[p0.to!int] = p1; 
		}
		return res; 
	} 
	
	struct SourceLine
	{
		 //SourceLine ///////////////////////////////
		string sourceText; 
		ubyte[] syntax; 
		ushort[] hierarchy; 
	} 
	
	class SourceCode
	{
		 //SourceCode ///////////////////////////////
		File file; 
		string sourceText; 
		
		bool showError; 
		
		//results after process:
		Token[] tokens; 
		string error; 
		ubyte[] syntax; 
		ushort[] hierarchy; 
		string[int] bigComments; 
		WhitespaceStats whitespaceStats; 
		
		void	checkConsistency()
		{
			//enforce(text.length == lines.map!"a.length".sum + (max(lines.length.to!int-1, 0)), "text <> lines");
			//enforce(text.length == syntax.length, "text <> syntax");
			//enforce(text.length == hierarchy.length, "text <> hierarchy");
		} 
		
		private void clearResult()
		{
			tokens = []; 
			error = ``; 
			syntax.clear; 
			hierarchy.clear; 
			bigComments.clear; 
			whitespaceStats = WhitespaceStats.init; 
		} 
		
		void foreachLine(T)(T delegate(int idx, string line, ubyte[] syntax) callBack)
		if(is(T==void) || is(T==bool))
		{
			auto syn = syntax; 
			int idx; 
			foreach(line; sourceText.splitter('\n'))
			{
				auto synLine = syn.fetchFrontN(line.length+1/+newLine+/); 
				if(synLine.length > line.length)
				synLine.popBack; 
				
				if(line.endsWith('\r'))
				{ line.popBack; synLine.popBack; }
				
				static if(is(T==void))
				{ callBack(idx++, line, synLine); }else
				{
					if(!callBack(idx++, line, synLine))
					break; 
				}
			}
		} 
		
		int lineCount()
		{
			if(tokens.empty)
			return sourceText.count('\n').to!int+1; 
			return tokens[$-1].line + sourceText[tokens[$-1].pos..$].count('\n').to!int + 1; 
		} 
		
		auto seekLine(int lineDst)
		{
			int pos, line; 
			if(lineDst<=0)
			return pos; 
			if(!tokens.empty)
			{
				auto tokenIdx = tokens.map!"a.line".assumeSorted.lowerBound(lineDst-1).length.to!int-1; 
				if(tokenIdx>0)
				{
					pos	= tokens[tokenIdx].pos; 
					line	= tokens[tokenIdx].line; 
				}
			}
			
			if(line==lineDst)
			while(pos>0 && sourceText[pos-1]!='\n')
			pos--; 
			
			while(line<lineDst)
			{
				auto i = sourceText[pos..$].indexOf('\n'); 
				if(i<0)
				return sourceText.length.to!int; 
				
				pos += i+1; 
				line++; 
			}
			
			return pos; 
		} 
		
		int[2] getLineRange(int i)
		{
			if(i<0 || i>=lineCount)
			return (int[2]).init; 
			int pos = seekLine(i); 
			auto j = sourceText[pos..$].indexOf('\n'); 
			int pos2; 
			if(j<0)
			pos2 = sourceText.length.to!int; 
			else pos2 = pos + j.to!int; 
			return [pos, pos2]; 
		} 
		
		auto getLine(int i)
		{
			SourceLine res; 
			
			auto r = getLineRange(i); 
			if(r[0] < r[1])
			{
				res.sourceText	= sourceText[r[0]..r[1]]; 
				res.syntax	= syntax	[r[0]..r[1]]; 
				res.hierarchy	= hierarchy	[r[0]..r[1]]; 
			}
			
			return res; 
		} 
		
		auto getLineText	  (int i)	
		{ return getLine(i).sourceText	; } 
		auto getLineSyntax		(int i)
		{ return getLine(i).syntax	; } 
		auto getLineHierarchy(int i)
		{ return getLine(i).hierarchy	; } 
		
		this(string sourceText)
		{ this(sourceText, File("")); } 
		this(File file)
		{ this(file.readText(true), file); } 
		this(string sourceText, File file)
		{
			//lineOfs = chain([-1], lines.map!"cast(int)a.length".cumulativeFold!"a+b+1").array;
			
			this.sourceText = sourceText; 
			this.file = file; 
			
			process; 
		} 
		
		void process()
		{
			clearResult; 
			
			hierarchy.length = syntax.length = sourceText.length; 
			
			error = tokenize(file.fullName, sourceText, tokens, &whitespaceStats); 
			
			if(error == "")
			{
				auto bigc = new char[0x10000]; 
				error = syntaxHighLight(file.fullName, tokens, sourceText.length, syntax.ptr, hierarchy.ptr, bigc.ptr, bigc.length.to!int); 
				bigComments = decodeBigComments(bigc); 
			}
			
			if(showError)
			if(error != "")
			WARN(error); 
			
			checkConsistency; 
		} 
	} 
	
	
	struct Token
	{
		 //Token //////////////////////////////
		Variant data; 
		int id; //emuns: operator, keyword
		int pos, length; //Todo: length OR source is redundant
		int line, posInLine; 
		int preWhite, postWhite; //before and after this token
		int level; //hiehrarchy level in [] () {} q{}
		string source; 
		
		TokenKind kind; 
		bool isTokenString; //it is inside the outermost tokenstring. Calculated in Parser.tokenize.BracketHierarchy, not in tokenizer.
												//update: 210520: implemented in syntaxHighlighter too.
		
		bool isBuildMacro; ////@ comments right after a newline or at the beginning of the file. Calculated in parser.collectBuildMacros
		
		/*
			string toString() const{
					return "%-20s: %s %s".format(kind, level, source);//~" "~(!data ? "" : data.text);
				}
		*/
		
		static void dumpStruct()
		{
			 //Todo: make it accessible from utils
			foreach(name; FieldNameTuple!Token)
			{ print(format!"%-16s %4d %4d"(name, mixin(name, ".offsetof"), mixin(name, ".sizeof"))); }
		} 
		
		
		@property int endPos() const
		{ return pos+length; } 
		
		void toString(scope void delegate(const(char)[]) sink, FormatSpec!char fmt)
		{
					 if(fmt.spec == 'u')
			put(sink, format!"%-20s: %s %s"(kind, level, source)); 
			else if(fmt.spec == 't') put(sink, format!"%s\t%s\t%s"(kind, level, source)); 
			else put(sink, source ~ "("~level.text~")"); 
		} 
		
		bool isOperator(int op)           const
		{ return id==op && kind==TokenKind.operator; } 
		int isOperator(int op1, int op2) const
		{ return kind==TokenKind.operator ? cast(int)id.among(op1, op2) : 0; } 
		bool isKeyword ()		const	
		{ return kind==TokenKind.keyword; } 
		bool isKeyword (int	kw)		const
		{ return id==kw &&	kind==TokenKind.keyword; } 
		bool isIdentifier()	  const
		{ return kind==TokenKind.identifier; } 
		bool isIdentifier(string s)		const
		{ return isIdentifier && source==s; } 
		bool isIdentifier(string s, int level)   const
		{ return isIdentifier && this.level==level && source==s; } 
		bool isComment()	    const
		{ return kind==TokenKind.comment; } 
		bool isSlashSlasComment()	    const
		{ return isComment && source.startsWith("//"); } 
		bool isDoxigenComment()	    const
		{ return isComment && ["///", "/**", "/++"].map!(a => source.startsWith(a)).any; } 
		
		bool isString()	              const
		{ return kind==TokenKind.literalString; } 
		bool isChar()	              const
		{ return kind==TokenKind.literalChar; } 
		bool isInt()	              const
		{ return kind==TokenKind.literalInt; } 
		bool isFloat()	              const
		{ return kind==TokenKind.literalFloat; } 
		bool isNumeric()               const
		{ return isInt || isFloat; } 
		bool isLiteral()              const
		{ return isString || isChar || isInt || isFloat; } 
		
		bool isKeyword (in int[] kw)	 const
		{ return kind==TokenKind.keyword	&& kw.map!(k => id==k).any; } 
		bool isOperator(in int[] op)	 const
		{ return kind==TokenKind.operator	&& op.map!(o => id==o).any; } 
		
		bool isAttribute() const
		{
			immutable allAttributes = [
				kwextern, kwpublic, kwprivate, kwprotected, kwexport, kwpackage,
				kwstatic,
				kwoverride, kwfinal, kwabstract,
				kwalign, kwdeprecated, kwpragma,
				kwsynchronized,
				kwimmutable, kwconst, kwshared, kwinout, kw__gshared,
				kwauto, kwscope,
				kwref, kwreturn, /*return must handled manually inside statement blocks*/
				kwnothrow,
				kwpure,
			]; 
			return isKeyword(allAttributes); 
		} 
		
		bool isHierarchyOpen() const
		{
			 //Todo: slow
			return kind==TokenKind.operator && ["{","[","(","q{"].canFind(source); 
		} 
		
		bool isHierarchyClose() const
		{
			 //Todo: slow
			return kind==TokenKind.operator && ["}","]",")"].canFind(source); 
		} 
		
		//return the level. If the token is { ( [ q{, it decreases the result by 1. Doesn't care about: } ] )
		int baseLevel() const
		{ return level - (isHierarchyOpen ? 1 : 0); } 
		
		string comment() const
		{
			assert(kind == TokenKind.comment); 
			string s = source; 
			if(s.startsWith("//"))
			s = s[2..$]; 
			else if(s.startsWith("/*") ||  s.startsWith("/+")) s = s[2..$-2]; 
			else assert(0, "invalid comment source format"); 
			return s; 
		} 
		
		//shorthand
		//bool opEquals(string s) const { return source==s; } //todo: this conflicted with the linker when importing het.parser.
		
		void raiseError(string msg, string fileName="")
		{ throw new Exception(format(`%s(%d:%d): Error at "%s": %s`, fileName, line+1, posInLine+1, source, msg)); } 
		
		//intelligent checkers
		
		bool among_one(string op)() const
		{
					 static if(op=="(")
			return isOperator(oproundBracketOpen); 
			else static if(op==")") return isOperator(oproundBracketClose); 
			else static if(op=="[") return isOperator(opsquareBracketOpen); 
			else static if(op=="]") return isOperator(opsquareBracketClose); 
			else static if(op=="{") return isOperator(opcurlyBracketOpen); 
			else static if(op=="}") return isOperator(opcurlyBracketClose); 
			else static if(op==",") return isOperator(opcomma); 
			else static if(op==":") return isOperator(opcolon); 
			else static if(op==";") return isOperator(opsemiColon); 
			else static if(op=="!") return isOperator(opnot); 
			else static if(op=="@") return isOperator(opatSign); 
			else static if(op=="=") return isOperator(opassign); 
			else static if(op=="is") return isOperator(opis); 
			else static if(op=="alias") return isKeyword(kwalias); 
			else static if(op=="enum") return isKeyword(kwenum); 
			else static if(op=="struct") return isKeyword(kwstruct); 
			else static if(op=="union") return isKeyword(kwunion); 
			else static if(op=="class") return isKeyword(kwclass); 
			else static if(op=="interface") return isKeyword(kwinterface); 
			else static if(op=="template") return isKeyword(kwtemplate); 
			else static if(op=="module") return isKeyword(kwmodule); 
			else static if(op=="mixin") return isKeyword(kwmixin); 
			else static if(op=="import") return isKeyword(kwimport); 
			else static if(op=="unittest") return isKeyword(kwunittest); 
			else static assert(0, "Unknown operator string: "~op); 
		} 
		
		int among_idx(string ops)() const
		{
			static foreach(idx, op; ops.split(" "))
			if(among_one!op)
			return int(idx); 
			return -1; 
		} 
		
		bool among(string ops)() const
		{
			static if(ops.split(" ").length>1)
			return among_idx!ops >= 0; 
			else return among_one!ops; 
		} 
		
		bool among(string ops)(int level) const
		{ return this.level==level && among!ops; } 
		
	} 
	
	int baseLevel(in Token[] tokens)
	{ return tokens.length ? tokens[0].baseLevel : 0; } 
	
	//TokenRange //////////////////////////////////////////////////////////////////////////////
	
	struct TokenRange
	{
		Token[] allTokens; //the full range
		int st, en; //start, end(excluding), index
		
		void clamp()
		{
			st.maximize(0); 
			en.minimize(allTokens.length.to!int); 
		} 
		
		/// Access the original range. It is faster, but can't see out of itself.
		Token[] tokens()
		{
			clamp; 
			return allTokens[st..en]; 
		} 
		
		this(Token[] tokens)
		{
			allTokens = tokens; 
			st=0; 
			en = tokens.length.to!int; 
			clamp; 
		} 
		
		this(Token[] tokens, int start, int end)
		{
			allTokens = tokens; 
			st = start; 
			en = end; 
			clamp; 
		} 
		
		ref Token opIndex(int idx)
		{
			int i = st+idx; 
			if(!(i.inRange(allTokens)))
			ERR("out of bounds"); 
			return allTokens[i]; 
		} 
		
		int opDollar(size_t dim : 0)() const
		{ return length; } 
		
		int[2] opSlice(size_t dim : 0)(int start, int end)
		{ return [start, end]; } 
		
		auto opSlice()
		{ return this; } 
		
		auto opIndex(int[2] r)
		{
			r[] += st; 
			r[0].maximize(0); 
			r[1].minimize(allTokens.length.to!int); //automatic clamp
			return TokenRange(allTokens, r[0], r[1]); 
		} 
		
		@property int	length() const
		{ return max(en-st, 0); } 
		@property void	length(int newLength)
		{ en = min(st + max(newLength, 0), allTokens.length.to!int); } //it clamps automatically
		
		bool empty() const
		{ return st>=en; } 
		ref Token front()
		{ return allTokens[st  ]; } 	 void popFront()
		{ st++; } 
		ref Token back ()
		{ return allTokens[en-1]; } 	 void popBack ()
		{ en--; } 
		//ref Token front_safe(){ enforce( st   .inRange(allTokens), "TokenRange.front out of bounds"); return front; }
		//ref Token back_safe (){ enforce((en-1).inRange(allTokens), "TokenRange.back out of bounds" ); return back ; }
		auto save()
		{ return this; } 
		
		bool extendFront()
		{
			int i = prevNonComment(allTokens, st); 
			if(i.inRange(allTokens))
			{ st = i; return true; }
			return false; 
		} 
		
		bool extendBack()
		{
			int i = nextNonComment(allTokens, en-1); 
			if(i.inRange(allTokens))
			{ en = i+1; return true; }
			return false; 
		} 
	} 
	
	/// Seeks the front of the range until the condition is reached
	/// If fails, it preserves the original range
	
	bool seekStart(alias fun)(ref TokenRange range)
	{
		auto idx = range.tokens.countUntil!fun; //Note: For optimal speed, the Token[] must be exposed whenever it is possible.
		if(idx>=0)
		{ range.st += idx; 	return true; }
		else { return false; }
	} 
	
	/// Seek from the start of the range and set the end of the range to include the token satisfying the condition.
	/// If fails, it preserves the original range
	bool seekEnd(alias fun)(ref TokenRange range)
	{
		auto idx = range.tokens.countUntil!fun; 
		if(idx>=0)
		{ range.en = range.st + idx.to!int + 1; 	return true; }
		else { return false; }
	} 
	
	int nextNonComment(in Token[] tokens, int i)
	{
		if((i+1).inRange(tokens))
		do
		{ i++; }while(i<tokens.length && tokens[i].isComment); 
		return i; 
	} 
	
	int prevNonComment(in Token[] tokens, int i)
	{
		if((i-1).inRange(tokens))
		do
		{ i--; }while(i>=0 && tokens[i].isComment); 
		return i; 
	} 
	
	
	//helper functs ///////////////////////////////////////////////////////////////////////////
	
	string transformLeadingSpacesToTabs(string original, int spacesPerTab=2)
	in(original != "", "This is here to test a multiline header with a contract.")
	//out{ assert(1, "ouch"); }
	{
		
		string process(string s)
		{
			s = stripRight(s); 
			int cnt; 
			string spaces = " ".replicate(spacesPerTab); 
			while(s.startsWith(spaces))
			{
				s = s[spaces.length..$]; 
				cnt++; 
			}
			s = "\t".replicate(cnt) ~ s; 
			return s; 
		} 
		
		return original.splitter('\n').map!(s => process(s)).join('\n'); //Todo: this is bad for strings
	} 
	
	string stripAllLines(string original)
	{ return original.splitter('\n').map!strip.join('\n'); } 
	
	/// Returns a null token positioned on to the end of the token array
	ref Token getNullToken(ref Token[] tokens)
	{
		static Token nullToken; 
		nullToken.source = "<NULL>"; 
		nullToken.pos = tokens.length ? tokens[$-1].endPos : 0; 
		return nullToken; 
	} 
	
	/// Safely access a token in an array
	ref Token getAny(ref Token[] tokens, size_t idx)
	{
		 //Todo: bad naming!
		return idx<tokens.length ? tokens[idx]
														 : tokens.getNullToken; 
	} 
	
	/// Safely access a token, skip comments.
	ref Token getNonComment(ref Token[] tokens, size_t idx)
	{
		 //no comment version
		foreach(ref t; tokens)
		{
			if(t.isComment)
			continue; 
			if(!idx)
			return t; 
			idx--; 
		}
		return tokens.getNullToken; 
	} 
	
	/// helper template to check various things easily
	bool isOp(string what)(ref Token[] tokens)
	{
		auto t(size_t idx=0)
		{ return tokens.getAny(idx); } 
		auto tNC(size_t idx=0)
		{ return tokens.getNonComment(idx); } 
		
		//first check the combinations with the reduntant first part
		static if(what == "mixin template")
		return tokens.isOp!"mixin" && tNC(1).isKeyword(kwtemplate); //Todo: op es kw legyen enum vagy legyen osszevonva. Bugoskohoz vezet, mert atfedesben van.
		
		//check keywords
		enum keywords = ["module", "import", "alias", "enum", "unittest", "this", "out", "struct", "union", "interface", "class", "if", "mixin", "template"]; 
		static foreach(k; keywords)
		static if(k == what)
		mixin(q{return t.isKeyword(kw$); }.replace("$", k)); 
		
		//check operators
		enum operators = [
			"{" : "curlyBracketOpen" , "(" : "roundBracketOpen" , "[" : "squareBracketOpen" ,
			"}" : "curlyBracketClose", ")" : "roundBracketClose", "]" : "squareBracketClose",
			";" : "semiColon", ":" : "colon", "," : "coma", "@" : "atSign", "~" : "complement", "!" : "not",
			"is" : "is", "in" : "in", "new" : "new", "delete" : "delete" 
		]; 
		
		static foreach(k, v; operators)
		static if(what == k)
		mixin(q{return t.isOperator(op$); }.replace("$", v)); 
		
		//combinations
		static if(what.among("//", "/+", "/*"))
		return t.isComment; 
		static if(what == "@(")
		return tokens.isOp!"@" && tNC(1).isOperator(opcurlyBracketOpen); 
		static if(what == "~this")
		return tokens.isOp!"~" && tNC(1).isKeyword(kwthis); 
		
		static if(what == "attribute")
		return t.isAttribute; 
	} 
	
	Token[][] splitTokens(string delim)(Token[] tokens, int level)
	{
		if(tokens.empty)
		return []; 
		
		enum delimMap = ["," : opcomma, ";" : opsemiColon, ":" : opcolon, "=" : opassign]; 
		enum op = delimMap[delim]; //Todo: ezt az egeszet lehuzni a token beazonositas gyokereig
		
		return tokens.split!((in t) => t.level == level && t.isOperator(op)); 
	} 
	
	/// Extracts the source code of a token range. Adds a newline if the last comment is a // comment
	string tokensToStr(in Token[] tokens, SourceCode code)
	{
		if(tokens.empty)
		return ""; 
		auto s = code.text[tokens[0].pos .. tokens[$-1].endPos]; //not safe
		if(tokens[$-1].isSlashSlasComment)
		s ~= "\n"; //Add a newline if the last comment needs it
		return s; 
	} 
	
	auto splitDeclarations(Token[] tokens, bool isStatements=false)
	{
		Token[][] res; 
		
		const level = tokens.baseLevel; 
		
		while(tokens.length)
		{
			
			//collect the comments first
			if(tokens[0].isComment)
			{
				res ~= [tokens.front]; 
				tokens.popFront; 
				continue; 
			}
			
			//search for the end of the declaration
			auto findDeclarationEnd()
			{
				bool ignoreColon = isStatements, isAssignExpr; 
				foreach(i, ref t; tokens)
				{
					if(t.level == level)
					{
						 //base level
						
						//update state flags first
						if(!isAssignExpr	&& t.among!"=")
						isAssignExpr = true; 
						if(!ignoreColon	&& t.among!"= import enum class interface")
						ignoreColon = true; 
						
						if(t.among!";")
						return i;  //';' is always an end marker
						
						if(!ignoreColon && t.among!":")
						return i; //':' is NOT always an end marker (->import, class,  =)
						
					}else if(t.level == level+1)
					{
						 //bracket level
						if(!isAssignExpr && t.among!"}")
						return i; //'}' means end if unless it's an assign expression.
					}
				}
				//raise("Unable to find end of declaration."); it's not an error in enum
				return tokens.length-1; 
			} 
			
			auto lastIdx = findDeclarationEnd; 
			res ~= tokens[0..lastIdx+1]; 
			tokens = tokens[lastIdx+1..$]; 
			
			//Todo: 'else' and ':' is handled later.
		}
		
		return res; 
	} 
	
	auto splitHeaderAndBlock(Token[] tokens)
	{
		enforce(tokens.length && tokens[$-1].among!"}", "Invalid input for splitHeaderAndBlock()"); 
		const level = tokens.baseLevel; 
		auto st = tokens.countUntil!(t => t.level==level+1 && t.source=="{"); 
		enforce(st>=0, "No {} block found: "~tokens.map!"a.source".join(' ')); 
		struct Res
		{ Token[] header, block; bool isSingleLine; } 
		return Res(tokens[0..st], tokens[st+1..$-1], tokens[st].line==tokens[$-1].line); 
	} 
	
	auto stripLeadingAttributesAndComments(ref Token[] tokens)
	{
		auto attrs = getLeadingAttributesAndComments(tokens); 
		tokens = tokens[attrs.length..$]; 
	} 
	
	auto getLeadingAttributesAndComments(Token[] tokens)
	{
		auto orig = tokens; 
		
		ref Token t()
		{ assert(tokens.length); return tokens[0]; } 
		void advance()
		{ assert(tokens.length); tokens = tokens[1..$]; } 
		void skipComments()
		{
			while(t.isComment)
			advance; 
		} 
		void skipBlock()
		{
			auto level = t.level; while(!t.among!")"(level))
			advance; advance; 
		} 
		
		while(tokens.length)
		{
			if(t.isComment)
			{
				  //comments
				advance; 
			}else if(t.among!"@")
			{
				advance; skipComments; 
				if(t.isIdentifier)
				{
							 //@UDA
					advance; skipComments; 
					if(t.among!"(")
					skipBlock; //@UDA(params)
				}else if(t.among!"(")
				{
							 //@(params)
					skipBlock; 
				}else
				{
					WARN("Garbage after @");  //Todo: it is some garbage, what to do with the error
					break; 
				}
			}else if(t.isAttribute)
			{
					  //attr
				advance; skipComments; 
				if(t.among!"(")
				skipBlock;  //attr(params)
			}else
			{
				break; //reached the end normally
			}
		}
		
		return orig[0..$-tokens.length]; 
	} 
	
	struct WhitespaceStats
	{
		int tabCnt; 
		int spaceCnt0, spaceCnt1, spaceCnt2, spaceCnt4, spaceCnt8, spaceCntOther; 
		
		private int lastSpaceCnt; 
		
		void addSpaceCnt(int spaceCnt)
		{
			const actDelta = abs(spaceCnt-lastSpaceCnt); 
			lastSpaceCnt = spaceCnt; 
			switch(actDelta)
			{
				case 0	: spaceCnt0++; break; 
				case 1	: spaceCnt1++; break; 
				case 2	: spaceCnt2++; break; 
				case 4	: spaceCnt4++; break; 
				case 8	: spaceCnt8++; break; 
				default	: spaceCntOther++; break; 
			}
		} 
		
		int detectIndentSize(int defaultSpaceCnt=4)
		{
			const idx = [tabCnt, spaceCnt1, spaceCnt2, spaceCnt4, spaceCnt8].maxIndex; 
			if(idx==0)
			return defaultSpaceCnt; 
			else return 1 << (idx-1).to!int; 
		} 
	} 
	
	
	class Tokenizer
	{
		//Todo: rewrite this tokenizer using StructureScanner
		public: 
			string fileName; 
			string text; 
			int pos, textLength, line, posInLine; 
			dchar ch; //actual character
			int skipCh; //size oh ch (1..4)
			Token[] res;   //should rename to tokens
		
			WhitespaceStats whitespaceStats; 
		
			void error(string s)
		{ throw new Exception(format("%s(%d:%d): Tokenizer error: %s", fileName, line, posInLine, s)); } 
		
			static bool isEOF	(dchar ch)
		{ return ch==0 || ch=='\x1A'; } 
			static bool isNewLine	(dchar ch)
		{ return ch=='\r' || ch=='\n'; } 
			static bool isLetter	(dchar ch)
		{ import std.uni; return isAlpha(ch) || ch=='_'; } //ch>='a' && ch<='z' || ch>='A' && ch<='Z' || ch=='_'; }
			static bool isDigit	(dchar ch)
		{ return ch>='0' && ch<='9'; } 
			static bool isOctDigit	(dchar ch)
		{ return ch>='0' && ch<='7'; } 
			static bool isHexDigit	(dchar ch)
		{ return ch>='0' && ch<='9' || ch>='a' && ch<='f' || ch>='A' && ch<='F'; } 
		
			void initFetch()
		{
			pos = posInLine = line = skipCh = 0; 
			textLength = text.length.to!int; 
			
			fetch; 
		} 
		
			void fetch()
		{
			pos += skipCh; posInLine += skipCh; 
			if(pos<textLength)
			{
				size_t nextPos = pos; 
				//print("decoding at", pos);
				ch = decode!(Yes.useReplacementDchar)(text, nextPos); 
				skipCh = cast(int)nextPos - pos; 
				//print(">pos", pos, "char", ch, "skipCh", skipCh);
			}else
			{
				ch = 0;  //eof is ch
			}
		} 
		
			void fetch(int n)
		{
			for(int i=0; i<n; ++i)
			fetch; 
		} //Todo: atirni ezeket az int-eket size_t-re es benchmarkolni.
		
			dchar peek(uint n=1)
		{
			size_t p = pos; 
			dchar res = 0; 
			foreach(i; 0..n+1)
			{
				if(p<text.length)
				{ res = decode!(Yes.useReplacementDchar)(text, p); }else
				break; 
			}
			return res; 
		} 
		
			string fetchIdentifier()
		{
			string s; 
			if(isLetter(ch))
			{
				s ~= ch; fetch; 
				while(isLetter(ch) || isDigit(ch))
				{ s ~= ch; fetch; }
			}
			return s; 
		} 
		
			void incLine()
		{ line++;  posInLine = 0; } 
		
			int	 expectHexDigit(dchar ch)
		{
			if(isDigit(ch))
			return ch-'0'; if(ch>='a' && ch<='f')
			return ch-'a'; if(ch>='A' && ch<='F')
			return ch-'A'; error(`Hex digit expected instead of "%s".`.format(ch)); return -1; 
		} 
			int	 expectOctDigit(dchar ch)
		{
			if(isOctDigit(ch))
			return ch-'0'; error(`Octal digit expected instead of "%s".`.format(ch)); return -1; 
		} 
		
			bool isKeyword(string s)
		{ return kwLookup(s)>=0; } 
		
			void skipLineComment()
		{
			fetch; 
			while(1)
			{
				fetch; 
				if(isEOF(ch) || isNewLine(ch))
				break; //EOF of NL
			}
		} 
		
			void skipNewLineOnce()
		{
					 if(ch=='\r')
			{
				fetch; if(ch=='\n')
				fetch; incLine; 
			}
			else if(ch=='\n') {
				fetch; if(ch=='\r')
				fetch; incLine; 
			}
		} 
		
			void skipNewLineMulti()
		{
			while(1)
			{
						 if(ch=='\r')
				{
					fetch; if(ch=='\n')
					fetch; incLine; 
				}
				else if(ch=='\n') {
					fetch; if(ch=='\r')
					fetch; incLine; 
				}
				else break; 
			}
		} 
		
			void skipBlockComment()
		{
			fetch; 
			while(1)
			{
				fetch; 
				if(isEOF(ch))
				return; //error("BlockComment is not closed properly."); //EOF
				skipNewLineMulti; 
				if(ch=='*' && peek=='/')
				{
					fetch; fetch; 
					break; 
				}
			}
		} 
		
			void skipNestedComment()
		{
			fetch; 
			int cnt = 1; 
			while(1)
			{
				fetch; 
				if(isEOF(ch))
				return; //error("NestedComment is not closed properly."); //EOF
				skipNewLineMulti; 
				if(ch=='/' && peek=='+')
				{ fetch; cnt++; }else if(ch=='+' && peek=='/')
				{
					fetch; cnt--; 
					if(cnt<=0)
					{ fetch; break; }
				}
			}
		} 
		
			void skipSpaces()
		{
			while(1)
			{
				switch(ch)
				{
					default: return; 
					case ' ': case '\x09': case '\x0B': case '\x0C': { fetch; continue; }
				}
			}
		} 
		
			void skipSpacesAfterNewLine()
		{
			int spaceCnt=0; 
			while(ch==' ')
			{ fetch; spaceCnt++; }; 
			whitespaceStats.addSpaceCnt(spaceCnt); 
		} 
		
			bool skipWhiteSpaceAndComments() //returns true if eof
		{
			 //Todo: __EOF__ handling
			while(1)
			{
				switch(ch)
				{
					default: { return false; }
					case '\x00': case '\x1A': {
						 //EOF
						return true; 
					}
					case '\x09': {
						 //tab
						fetch; 
						whitespaceStats.tabCnt++; 
						break; 
					}
					case ' ', '\x0B', '\x0C': fetch; break; //whitespace
					
					case '\r': /+NewLine1+/ fetch; 	 if(ch=='\n')
					fetch; 	 incLine; 	 skipSpacesAfterNewLine; 	 break; 
					case '\n': /+NewLine2+/ fetch; 	 if(ch=='\r')
					fetch; 	 incLine; 	 skipSpacesAfterNewLine; 	 break; 
					
					case '/': {
						 //comment
						switch(peek)
						{
							default: return false; 
							case '/': newToken(TokenKind.comment); 	 skipLineComment; 	finalizeToken; break; 
							case '*': newToken(TokenKind.comment); 	 skipBlockComment; 	finalizeToken; break; 
							case '+': newToken(TokenKind.comment); 	 skipNestedComment; 	finalizeToken; break; 
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
			
			if(res.empty)
			{ tk.preWhite = pos; }else
			{
				tk.preWhite = pos-res[$-1].endPos; 
				res[$-1].postWhite = tk.preWhite; 
			}
			
			res ~= tk; 
		} 
		
			void finalizeToken()
		{
			Token *t = &res[$-1]; 
			t.length = pos-t.pos; 
			t.source = text[t.pos..pos]; 
			
			//print(t.line+1, t.posInLine+1);
		} 
		
			ref Token lastToken()
		{ return res[$-1]; } 
		
			void removeLastToken()
		{ res.length--; } 
		
			void seekToEOF()
		{ pos = textLength; ch = 0; } 
		
			void revealSpecialTokens()
		{
			with(lastToken)
			{
				if(kwIsSpecialKeyword(id))
				{
					switch(id)
					{
											default	: { error("Unhandled keyword specialtoken: "~source); break; }
											case kw__EOF__	: { seekToEOF; removeLastToken; break; }
											case kw__TIMESTAMP__	: { kind = TokenKind.literalString; data = now.text; break; }
											case kw__DATE__		: { kind = TokenKind.literalString; data = now.dateText; break; }
											case kw__TIME__		: { kind = TokenKind.literalString; data = now.timeText; break; }
											case kw__VENDOR__	: { kind = TokenKind.literalString; data = "realhet"; break; }
											case kw__VERSION__		: { kind = TokenKind.literalInt; data = CompilerVersion; break; }
											case kw__FILE__	: { import 	std.path; kind = TokenKind.literalString; data = baseName(fileName); break; }
											case kw__FILE_FULL_PATH__		: { kind = TokenKind.literalString; data = fileName; break; }
						
						//Todo: Ez kurvara nem igy megy: A function helyen kell ezt meghivni.
											case kw__LINE__	: { kind = TokenKind.literalInt; data = line+1; break; }
											case kw__MODULE__	: { kind = TokenKind.literalString; data = "module"; break; }//TODO
											case kw__FUNCTION__	: { kind = TokenKind.literalString; data = "function"; break; }//TODO
											case kw__PRETTY_FUNCTION__	: { kind = TokenKind.literalString; data = "pretty_function"; break; }//TODO
					}
				}else if(kwIsOperator(id))
				{
					switch(id)
					{
						default: { error("Unhandled keyword operator: "~source); break; }
						case kwin: case kwis: case kwnew: /*case kwdelete  deprecated:*/{
								kind = TokenKind.operator; 
								id = opParse(source); 
								if(!id)
							error("Cannot lookup keyword operator."); 
							break; 
						}
					}
				}
			}
		} 
		
			void parseIdentifier()
		{
			newToken(TokenKind.identifier); 
			
			fetch; 
			while(isLetter(ch) || isDigit(ch))
			fetch; 
			
			finalizeToken(); 
			
			with(lastToken)
			{
				 //set tokenkind kind
				
				//is it a keyword?
				int kw = kwLookup(source); 
				if(kw)
				{
					kind = TokenKind.keyword; 
					id = kw; 
					revealSpecialTokens; //is it a special keyword of operator?
				}
			}
		} 
		
			string parseEscapeChar()
		{
			fetch; 
			switch(ch)
			{
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
				case 'x': {
					fetch; //hexString is deprecated.  -> std.conv.hexString!
					int x = expectHexDigit(ch); fetch; 
					x = (x<<4) + expectHexDigit(ch); fetch; 
					return to!string(cast(char)x); 
				}
				case '0': ..case '7': {
					int o; 
					o = expectOctDigit(ch); fetch; 
					if(isOctDigit(ch))
					{
						o = (o<<3) + expectOctDigit(ch); fetch; 
						if(isOctDigit(ch))
						{ o = (o<<3) + expectOctDigit(ch); fetch; }
					}
					return to!string(cast(char)o); 
				}
				case 'u': case 'U': {
					int cnt = ch=='u' ? 4 : 8; 
					fetch; 
					int u;  for(int i=0; i<cnt; ++i)
					{ u = (u<<4)+expectHexDigit(ch); fetch; }
					return to!string(cast(dchar)u); 
				}
				case '&': {
					fetch; 
					auto s = fetchIdentifier; 
					if(ch!=';')
					error(`NamedCharacterEntry must be closed with ";".`); 
					fetch; 
					auto u = nceLookup(s); 
					if(!u)
					error(`Unknown NamedCharacterEntry "`~s~`".`); //Todo: this should be only a warning, not a complete failure
					
					return to!string(u); 
				}
			}
		} 
		
			void parseStringPosFix()
		{
			if(ch=='c' || ch=='w' || ch=='d')
			fetch; 
		} 
		
			void parseWysiwygString(bool handleEscapes=false, bool onlyOneChar=false)
		{
			newToken(TokenKind.literalString); 
			dchar ending; 
			if(ch=='r')
			{ ending = '"'; fetch; fetch; }
			else { ending = ch; fetch; }
			string s; 
			int cnt; 
			while(1)
			{
				cnt++; 
				if(isEOF(ch))
				error("Unexpected EOF in a StringLiteral"); 
				if(ch==ending)
				{ fetch; break; }
				if(isNewLine(ch))
				{ s ~= '\n'; skipNewLineOnce; continue; }
				if(handleEscapes && ch=='\\')
				{ s ~= parseEscapeChar; continue; }
				s ~= ch;  fetch; 
			}
			parseStringPosFix; 
			finalizeToken; 
			lastToken.data = s; 
			
			//this check should be optional, so it can process javascript as well
			if(onlyOneChar && cnt!=2)
			error("Character constant must contain exactly one character."); 
		} 
		
			void parseDoubleQuotedString()
		{ parseWysiwygString(true); } 
			void parseLiteralChar()
		{ parseWysiwygString(true, true); } 
		
		
			void parseDelimitedString()
		{
			newToken(TokenKind.literalString); 
			fetch; fetch; //q"..."
			
			string s; 
			if(isLetter(ch))
			{
				 //identifier ending
				string ending = fetchIdentifier ~ `"`; 
				if(!isNewLine(ch))
				error("Delimited string: there must be a NewLine right after the identifier."); 
				skipNewLineOnce; 
				
				while(1)
				{
					if(isEOF(ch))
					error("Unexpected EOF in a DelimitedString."); 
					
					if(isNewLine(ch))
					{
						skipNewLineOnce; 
						s ~= '\n'; 
						continue; 
					}
					
					if(posInLine==0)
					{
						bool found = true;  foreach(idx, c; ending)
						if(peek(cast(int)idx)!=c)
						{ found = false; break; }
						if(found)
						{
							fetch(cast(int)ending.length-1); //not including ending "
							break; 
						}
					}
					
					s ~= ch;  fetch; 
				}
			}else
			{
				 //single char ending
				/+
					Todo: Nesting is not handled properly (not handlet at all):  
					These should give an error: q"(foo(xxx)"  q"/foo/xxx/"
					But this should compile: q"((foo")"xxx)" 
				+/
				
				dchar ending; 
				switch(ch)
				{
					case '[': ending = ']'; break; 
					case '<': ending = '>'; break; 
					case '(': ending = ')'; break; 
					case '{': ending = '}'; break; 
					default: 
						if(ch.inRange(' ', '~'))
					ending = ch; 
					else error(`Invalid char "%s" used as delimiter in a DelimitedString`.format(ch)); 
				}
				fetch; 
				while(1)
				{
					if(isEOF(ch))
					error("Unexpected EOF in a DelimitedString."); 
					if(ch==ending && peek=='"')
					{ fetch; break; }
					if(isNewLine(ch))
					{ s ~= '\n'; skipNewLineOnce;  continue; }
					s ~= ch;  fetch; 
				}
			}
			
			if(ch!='"')
			error(`Expecting an " at the end of a DelimitedString instead of "%s".`.format(ch)); 
			fetch; 
			
			parseStringPosFix; 
			finalizeToken; 
			lastToken.data = s; 
		} 
		
			string parseInteger(int base)
		{
			string s; 
			if(base==10)
			{
				while(1)
				{
					if(isDigit(ch))
					{ s ~= ch; fetch; continue; }
					if(ch=='_')
					{ fetch; continue; }
					break; 
				}
			}else if(base==2)
			{
				while(1)
				{
					if(ch=='0' || ch=='1')
					{ s ~= ch; fetch; continue; }
					if(ch=='_')
					{ fetch; continue; }
					break; 
				}
			}else if(base==16)
			{
				while(1)
				{
					if(isHexDigit(ch))
					{ s ~= ch; fetch; continue; }
					if(ch=='_')
					{ fetch; continue; }
					break; 
				}
			}
			
			return s; 
		} 
		
			string expectInteger(int base)
		{
			auto s = parseInteger(base); 
			if(s is null)
			error("A number was expected (in base:%d).".format(base)); 
			return s; 
		} 
		
		/+
			deprecated void parseHexString(){
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
		+/
		
			void parseNumber()
		{
			
			ulong toULong(string s, int base)
			{
				ulong a; 
				if(base ==	2)
				foreach(ch;	s)
				{ a <<=  1; 	 a += ch-'0'; }else if(base == 10)
				foreach(ch; s)
				{ a *=  10; 	 a += ch-'0'; }else if(base == 16)
				foreach(ch; s)
				{
					 a <<=	4; 	 a += ch>='a' ? ch-'a'+10 :
					ch>='A' ?	ch-'A'+10 : ch-'0'; 
				}
				return a; 
			} 
			
			newToken(TokenKind.literalInt); 
			
			bool isFloat = false; 
			int base = 10; //get base
			string whole, fractional, exponent; 
			int expSign = 1; 
			
			//parse float header
			if(ch=='0')
			{
				dchar ch1 = peek; 
				if(ch1=='x' || ch1=='X')
				base = 16; else if(ch1=='b' || ch1=='B')
				base = 2; 
				if(base!=10)
				fetch(2); //skip the header
			}
			
			//parse fractional part
			bool exponentDisabled; 
			if(ch=='.' && peek!='.' && !isLetter(peek))
			{
				 //the number starts with a point
				whole = "0"; 
				isFloat = true;  fetch;  fractional = expectInteger(base); 
			}else
			{
				 //the number continues with a point
				whole = expectInteger(base); 
				if(ch=='.')
				{
					bool isNextDigit = isDigit(peek); 
					if(base==16)
					isNextDigit |= isHexDigit(peek); 
					if(isNextDigit)
					{
						isFloat = true; fetch;  fractional = parseInteger(base); //number is optional.
						if(fractional is null)
						exponentDisabled = true; 
					}
				}
			}
			
			//parse optional exponent
			if(!exponentDisabled)
			if(
				(base<=10 && (ch=='e' || ch=='E'))
						 ||(base<=16 && (ch=='p' || ch=='P'))
			)
			{
				isFloat = true; 
				fetch; 
				if(ch=='-')
				{ fetch; expSign = -1; }else if(ch=='+')
				fetch; //fetch expsign
				exponent = expectInteger(10); 
			}
			
			if(isFloat)
			{
				 //assemble float
				//process float postfixes
				int size = 8; 
				if(ch=='f' || ch=='F')
				{ fetch; size = 4; }
				else if(ch=='L') { fetch; size = 10; }
				
				enum isImag = false; //imaginary numbers are no longer supported.
				//if(ch=='i')            { fetch; isImag = true; }
				//Note: LDC2 -verrors-context: Imaginary numbers can generate deprecation message without a source code location, then the compiler crashes when attempting to generate a verrors-context for that.
				
				//put it together
				real rbase = base; 
				real num = toULong(whole, base); 
				if(fractional !is null)
				num += toULong(fractional, base)*(rbase^^(-cast(int)fractional.length)); 
				if(exponent !is null)
				num *= to!real(base==10?10:2)^^(expSign*to!int(toULong(exponent, 10))); 
				
				//place it into the correct type
				Variant v; 
				if(isImag)
				{
					/+
						if(size== 4) v = 1.0i * cast(float)num; else
										if(size== 8) v = 1.0i * cast(double)num; else
																 v = 1.0i * cast(real)num;
					+/
				}else
				{
					if(size== 4)
					v = cast(float) num; else if(size== 8)
					v = cast(double) num; else
					v = cast(real) num; 
				}
				
				finalizeToken; 	lastToken.data = v; 
			}else
			{
				 //assemble	integer
				ulong num = toULong(whole, base); 
				
				//fetch posfixes
				bool isLong, isUnsigned; 
				if(ch=='L')
				{ fetch; isLong = true; }
				if(ch=='u' || ch=='U')
				{ fetch; isUnsigned = true; }
				if(!isLong && ch=='L')
				{ fetch; isLong = true; }
				
				Variant v; 
				if(!isLong && !isUnsigned)
				{
					 //no postfixes
					if(num<=					     0x7FFF_FFFF)
					v = cast(int)num; else if(num<=					     0xFFFF_FFFF && base!=10)
					v = cast(uint)num; else if(
						num<=0x7FFF_FFFF_FFFF_FFFF           //hex/bin can be unsigned too to use the smallest size as possible
					)
					v = cast(long)num; 
					else v = num; 
				}else if(isLong && isUnsigned)
				{
					 //UL
					v = num; 
				}else if(isLong)
				{
					 //L
					if(num<=0x7FFF_FFFF_FFFF_FFFF)
					v = cast(long)num; 
					else v = num; 
				}else
				{
					 //U
					if(num<=	0xFFFF_FFFF)
					v = cast(uint)num; 
					else v = num; 
				}
				
				finalizeToken;  lastToken.data = v; 
			}
		} 
		
			bool tryParseOperator()
		{
			int len; 
			auto opId = opParse(text[pos..$], len); 
			if(!opId)
			return false; 
			
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
			string tokenize(in string fileName, in string text, out Token[] tokens, WhitespaceStats* whitespaceStats = null)
		{
			auto enc = encodingOf(text); 
			enforce(enc==TextEncoding.UTF8, "Tokenizer only works on UTF8 input. ("~enc.text~" detected)"); 
			
			this.fileName = fileName; 
			this.text = text; 
			
			initFetch; 
			
			res = []; 
			string errorStr; 
			try
			{
				while(1)
				{
					if(skipWhiteSpaceAndComments)
					break; //eof reached
					switch(ch)
					{
						case 'a': ..case 'z': case 'A': ..case 'Z': case '_': {
							dchar nc = peek; 
							if(nc=='"')
							{
								if(ch=='r')
								{ parseWysiwygString; break; }
								if(ch=='q')
								{ parseDelimitedString; break; }
								//deprecated if(ch=='x'){ parseHexString; break; }  //todo: x"" hexString can be an addon in the IDE.
							}else if(nc=='{')
							{
								if(ch=='q')
								{ tryParseOperator; break; }
							}
							parseIdentifier; 
							break; 
						}
						case '"': { parseDoubleQuotedString; break; }
						case '`': { parseWysiwygString; break; }
						case '\'': { parseLiteralChar; break; }
						case '0': ..case '9': { parseNumber; break; }
						case '.': {
							if(isDigit(peek))
							{ parseNumber; break; }
							goto default; //operator
						}
						case '#': {
							 //Special token sequences
							
							/*
								 This #line can broke the codeeditor. Rather disable it
														if(text[pos..$].startsWith("#line")){ //lineNumber/fileName override
															fetch("#line".length.to!int);  skipSpaces;
															this.line = to!int(expectInteger(10))-2;  skipSpaces;
															if(ch=='"'){ this.fileName = parseFilespec;  skipSpaces;  }
															if(!isNewLine(ch)) error("NewLine character expected after #line SpecialTokenSequence.");
								
															break;
														}
							*/
							if(text[pos..$].startsWith("#define"))
							{
								 //Todo: highlight #define macros
							}
							
							goto default; //operator
						}
						default: {
							if(tryParseOperator)
							continue; 
							if(isLetter(ch))
							{ parseIdentifier; continue; }//identifier with special letters
							//cannot identify it at all
							error(format("Invalid character [%s] hex:%x", ch, ch)); break; 
						}
					}
				}
			}catch(Throwable o)
			{ errorStr = o.toString; }
			
			//set the last postWhite counter
			if(res.length)
			res[$-1].postWhite = pos - res[$-1].endPos; 
			
			tokens = res; 
			
			if(whitespaceStats)
			*whitespaceStats = this.whitespaceStats; 
			
			return errorStr; 
		} 
		
	} 
	
	
	
	int highlightPrecedenceOf(string op, bool isUnary)
	{
			bool isBinary = !isUnary; 
		
		/*
			  if(op==";")return 1;
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
				if(op=="." || op=="(" || op==")" || op=="[" || op=="]")return 17;
		*/
		
			return 0; 
		
		//if(op=="!" && !isUnary) return 15;
		//if(op=="=>") return 14.5;
	} 
	
	private ushort calcHierarchyWord(const Token t)
	{
		if(t.isComment)
		return 0; 
		
		int h = t.level | 0x2000; //isToken
		
		return cast(ushort)h; 
	} 
	
	private ushort spreadHierarchyWord(ushort h, bool st, bool en)
	{
		if(!h)
		return 0; 
		
		if(st)
		h |= 0x4000; //isTokenBegin
		if(en)
		h |= 0x8000; //isTokenEnd
		
		return h; 
	} 
	
	struct TokenizeResult
	{
		Token[] tokens; 
		string error; 
		ubyte[] syntax; 
		ushort[] hierarchy; 
		string bigComments; 
	} 
	
	auto tokenize2(string src, string fileName="", bool raiseError=true)
	{
		 //it does the tokenizing and syntax highlighting
		TokenizeResult res; 
		
		res.error = tokenize(fileName, src, res.tokens); 
		enforce(!raiseError || res.error=="", "Tokenizer error: "~res.error); 
		
		res.syntax.length	= src.length; 
		res.hierarchy.length	= src.length; 
		
		auto bigTmp = new char[2048]; 
		syntaxHighLight(fileName, res.tokens, src.length, res.syntax.ptr, res.hierarchy.ptr, bigTmp.ptr, cast(int)bigTmp.length); 
		
		res.bigComments = bigTmp.ptr.toStr; 
		return res; 
	} 
	
	//Todo: ezt a kibaszottnagy mess-t rendberakni it fent
	
	
	
	string syntaxHighLight(string fileName, Token[] tokens, size_t srcLen, ubyte* res, ushort* hierarchy, char* bigComments, int bigCommentsLen) //SyntaxHighlight ////////////////////////////
	{
		string errors; 
		
		//Todo: a delphis } bracket pa'rkereso is bugos: a stringekben levo {-en is megall.
		//Todo: ezt az enumot kivinni es ubye tipusuva tenni, osszevonni
		enum 
		{
			 skWhiteSpace, skSelected, skFoundAct, skFoundAlso, skNavLink, skNumber, skString, skKeyword, skSymbol, skComment,
					skDirective, skIdentifier1, skIdentifier2, skIdentifier3, skIdentifier4, skIdentifier5, skIdentifier6, skLabel,
					skAttribute, skBasicType, skError, skBinary1 
		} 
		
		//clear
		res[0..srcLen]	= 0; 
		hierarchy[0..srcLen]	= 0; 
		
		//nested functs
		void fill(const Token t, ubyte cl)
		{
			auto h = calcHierarchyWord(t); 
			for(int j=0; j<t.length; j++)
			{
				res[t.pos+j] = cl; 
				hierarchy[t.pos+j] = spreadHierarchyWord(h, j==0, j==t.length-1); 
			}
		} 
		
		void overrideSyntaxHighLight(Token[] tokens)
		{
			//detect language
			string lang; 
			foreach(t; tokens)
			{
				if(t.kind==TokenKind.identifier)
				{
					if(isGLSLInstruction(t.source))
					{ lang="GLSL"; break; }
					if(isGCNInstruction (t.source))
					{ lang="GCN"; break; }
				}
			}
			
			if(lang=="GLSL")
			{
				foreach(t; tokens)
				{
					ubyte cl = GLSLInstructionKind(t.source); 
																 //0:do nothing, 1:keyword, 2:typeQual,  3:types,     4:values,    5:functs,      6:vars
					static ubyte[] remap = [0,            skKeyword, skAttribute, skBasicType, skBasicType, skIdentifier5, skIdentifier6]; 
					if(cl)
					fill(t, remap[cl]); 
				}
			}else if(lang=="GCN")
			{
				foreach(t; tokens)
				{
					ubyte cl = GCNInstructionKind(t.source); 
										 //vector, scalar, misc
					static ubyte[] remap2 = [0,   skIdentifier6, skIdentifier5, skIdentifier4]; //Todo: GCN_options
					if(cl)
					fill(t, remap2[cl]); 
				}
			}
		} 
		
		bool nextIdIsAttrib; 
		string[] nesting; 
		int[] nestingOpeningIdx; 
		int tokenStringLevel; 
		
		string[int] bigCommentsMap; 
		int lastBigCommentHeaderLine = -1; 
		
		string stripSlashes(string s)
		{
			s = s.strip; 
			while(s.startsWith('/'))
			s = s[1..$  ]; 
			while(s.endsWith  ('/'))
			s = s[0..$-1]; 
			return s.strip; 
		} 
		
		foreach(idx, ref t; tokens)
		with(TokenKind)
		{
			ubyte cl; 
			
			//detect big comments
			enum bigCommentMinLength = 30; 
			enum bigCommentMinSlashCount = 20; 
			enum bigCommentEnding = "/".replicate(bigCommentMinSlashCount); 
			if(t.isComment && t.source.length>bigCommentMinLength && t.source.startsWith("//"))
			{
				auto s = t.source.strip; 
				if(s.all!q{a=='/'})
				{ lastBigCommentHeaderLine = t.line; }else if(s.endsWith(bigCommentEnding))
				{
					//take '/'s off of both sides
					bigCommentsMap[t.line] = stripSlashes(s); 
				}else if(t.line==lastBigCommentHeaderLine+1 && s.startsWith("//") && s.endsWith("//"))
				{ bigCommentsMap[t.line] = "!"~stripSlashes(s); }
			}
			
			//nesting level calculation
			if(t.isHierarchyOpen)
			{
				nesting ~= t.source; 
				nestingOpeningIdx ~= cast(int)idx; //Todo: normalis nevet talalni ennek, vagy bele egy structba
				
				if(nesting.back=="q{")
				tokenStringLevel++; 
			}
			
			t.level = cast(int)nesting.length; 
			t.isTokenString = tokenStringLevel>0; 
			
			if(chkClear(nextIdIsAttrib) && t.kind==identifier)
			{ cl = skAttribute; }else
			switch(t.kind)
			{
				default: break; 
				case unknown		: cl = skError; break; 
				case comment		: cl = skComment; break; 
				case identifier	: cl = skIdentifier1; break; 
				case keyword	: 	{
					with(KeywordCat)
					switch(kwCatOf(t.source))
					{
						case Attribute	: cl = skAttribute; break; 
						case Value	: cl = skBasicType; break; 
						case BasicType	: cl = skBasicType; break; 
						case UserDefiniedType	: cl = skKeyword; break; 
						case SpecialFunct	: cl = skAttribute; break; 
						case SpecialKeyword	: cl = skKeyword; break; 
						default	: cl = skKeyword; break; 
					}
					
					break; 
				}
				case special		: 	break; 
				case operator		: {
							 if(t.source=="@")
					{ cl = skAttribute; nextIdIsAttrib = true; }
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
			if(t.isHierarchyClose)
			{
				string opening, closing; 
				if(!nesting.empty)
				opening = nesting[$-1]; 
				
						 if(opening=="{")
				closing = "}"; 
				else if(opening=="q{") closing = "}"; 
				else if(opening=="[") closing = "]"; 
				else if(opening=="(") closing = ")"; 
				
				if(t.source==closing)
				{
					if(opening=="q{")
					{
						cl = skString; 
						overrideSyntaxHighLight(tokens[nestingOpeningIdx[$-1]+1..idx]); 
					}
					
					//advance
					if(nesting.back=="q{")
					tokenStringLevel--; 
					nesting = nesting[0..$-1]; 
					nestingOpeningIdx = nestingOpeningIdx[0..$-1]; 
				}else
				{
					//nesting error
					cl = skError; 
					if(!nestingOpeningIdx.empty)
					fill(tokens[nestingOpeningIdx[$-1]], skError); 
					errors ~= format!"%s(%s,%s) Error: Bad nesting bracket.\n"(fileName, t.line+1, t.posInLine+1); 
				}
			}
			
			//fill it with the style
			fill(t, cl); 
		}
		
		
		foreach_reverse(i; nestingOpeningIdx)
		{
			fill(tokens[i], skError); 
			errors ~= format!"%s(%s,%s) Error: Missing closing bracket.\n"(fileName, tokens[i].line+1, tokens[i].posInLine+1); 
		}
		
		bigCommentsMap.rehash; //Todo: revisit strings
		auto sBigComments = bigCommentsMap.byKeyValue.map!(a => format(`%s:%s`, a.key, a.value)).join("\r\n"); 
		sBigComments.length = min(sBigComments.length, bigCommentsLen); 
		bigComments[0..sBigComments.length] = sBigComments[]; 
		bigComments[sBigComments.length] = '\0'; 
		
		return errors.strip; 
	} 
	
	//GPU text editor format
	
	
	////////////////////////////////////////////////////////////////////////////////
	
	//Todo: rendberakni a commenteket
	//Todo: unittest
	
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
	
	//JSON Support //////////////////////////////////////////////////
	
	//discovers field, the start of each element in a json array or a json map
	void discoverJsonHierarchy(ref Token[] tokens, string fileName="json_text")
	{
		if(tokens.empty)
		return; 
		
		int level = 0; 
		int[] expectStack; 
		
		foreach(ref t; tokens)
		{
			if(t.kind == TokenKind.operator)
			{
				switch(t.id)
				{
					case opsquareBracketOpen: case opcurlyBracketOpen: {
							t.level = level; 
							level += 1; 
						
							expectStack ~= t.id + 1; //closer op == opener op + 1
						break; 
					}
					case opsquareBracketClose: case opcurlyBracketClose: {
							if(expectStack.empty)
						t.raiseError("Unexpected closing token.", fileName); 
							if(expectStack[$-1] != t.id)
						t.raiseError("Mismatched closing token.", fileName); 
							expectStack.popBack; 
						
							level -= 1; 
							t.level = level; 
						break; 
					}
					case opcomma: {
							t.level = level - 1; 
						break; 
					}
					case opcolon: case opsub: {
							t.level = level; 
						break; 
					}
					default: t.raiseError("Invalid symbol", fileName); 
				}
			}else
			{
				if(
					t.kind.among(TokenKind.literalString, TokenKind.literalInt, TokenKind.literalFloat)
								||(t.kind==TokenKind.keyword && t.id.among(kwfalse, kwtrue, kwnull))
				)
				{ t.level = level; }else
				{ t.raiseError("Unknown token", fileName); }
			}
		}
		
		if(expectStack.length)
		tokens[$-1].raiseError("Expecting closing tokens. (%s)".format(expectStack.length), fileName); 
		enforce(level==0, "Fatal error: JsonHierarchy level!=0"); 
	} 
	
	//collectAndReplaceQuotedStrings() /////////////////////////////////////////
	
	/// Finds and collects "" quoted string literals and replaces them with a given string
	string[] collectAndReplaceQuotedStrings(ref string s, string replacement)
	{
		string[] res; 
		string processed, act = s; 
		while(1)
		{
			immutable quote = '"'; 
			auto idx = act.indexOf(quote); 
			if(idx<0)
			break; 
			
			processed ~= act[0..idx]; 
			act = act[idx..$]; 
			
			//find ending quote
			string qstr = act[0..1]; act = act[1..$]; 
			do
			{
				idx = act.indexOf(quote); 
				if(idx<0)
				throw new Exception("Unterminated string literal."); 
				qstr ~= act[0..idx+1]; 
				act = act[idx+1..$]; 
			}while(qstr.endsWith(`\"`)); 
			
			Token[] tokens; 
			auto error = tokenize("string literal tokenizer", qstr, tokens); 
			if(error!="")
			throw new Exception("Error decoding string literal: "~error); 
			enforce(tokens.length==1 && tokens[0].isString, "Error decoding string literal: String literal expected."); 
			
			res ~= tokens[0].data.to!string; 
			
			processed ~= replacement; //mark the position
		}
		processed ~= act; 
		s = processed; 
		return res; 
	} 
	
	//Big test //////////////////////////////////////////////
	
	void testTokenizer()
	{
		Time tTokenize = 0*second, tFull = 0*second; 
		int size; 
		
		string test(File f)
		{
			Token[] tokens; 
			auto s = f.readText; 
			size += s.length; 
			
			auto t0 = QPS; 
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
		print("tokenizer time:", tTokenize.value(second), "size:", size, "MB/s:", size/1024.0/1024.0/tTokenize.value(second)); 
		print("full time:", tFull.value(second)    , "size:", size, "MB/s:", size/1024.0/1024.0/tFull.value(second)    ); 
		enforce(File(path, `reference.txt`).readText == s, "Tokenizer correctness test failed."); 
		print("\33\12Tokenizer works correctly\33\7"); 
		
		/*
			 Known results:
					200415:
						tokenizer time: 0.0538597 size: 1104899 MB/s: 19.564
						full time: 0.126472 size: 1104899 MB/s: 8.3316
					200415: unicode support: std.uni works well
						tokenizer time: 0.0707722 size: 1447158 MB/s: 19.5008
						full time: 0.165943 size: 1447158 MB/s: 8.31683
		*/
		
	} 
}

version(/+$DIDE_REGION Keywords+/all)
{
	////////////////////////////////////////////////////////////////////////////////
	///  Basic Types                                                             ///
	////////////////////////////////////////////////////////////////////////////////
	
	//Todo: some types are no more. Complex numbers for example.
		 //|---> maps exactly to kwEnums
	enum BasicType:byte	
	{ Unknown,	Byte, UByte, Short, UShort, Int, UInt, Long,	ULong, Cent, UCent, Float, Double, Real, IFloat, IDouble, IReal, CFloat, CDouble, CReal, Bool, Char, WChar, DChar, Void	} 
	auto BasicTypeBytes	 =[0,	   1,	    1,     2,      2,	4,    4,    8,     8,   16,    16,     4,      8,	  10,      4,       8,	   10,      8,      16,    20,	   1,	   1,	2,     4,	   0]; 
	auto BasicTypeBits	 =[0,	   8,	    8,    16,     16,  32,   32,   64,    64,  128,   128,    32,     64,	  80,     32,      64,	   80,     64,     128,   160,	   8,	   8,    16,    32,	   0]; 
	
	bool isInteger	 (BasicType b)
	{ return b>=BasicType.Byte   && b<=BasicType.UCent; } 
	bool isSigned	 (BasicType b)
	{ return b&1; } 
	bool isFloat	 (BasicType b)
	{ return b>=BasicType.Float	&& b<=BasicType.CReal; } 
	bool isImag	 (BasicType b)
	{ return b>=BasicType.IFloat	&& b<=BasicType.IReal; } 
	bool isComplex	 (BasicType b)
	{ return b>=BasicType.CFloat	&& b<=BasicType.CReal; } 
	bool isBool	 (BasicType b)
	{ return b==BasicType.Bool; } 
	bool isChar	 (BasicType b)
	{ return b>=BasicType.Char   && b<=BasicType.DChar; } 
	bool isVoid	 (BasicType b)
	{ return b==BasicType.Void; } 
	
	////////////////////////////////////////////////////////////////////////////////
	///  Keywords                                                                ///
	////////////////////////////////////////////////////////////////////////////////
	
	private enum _keywordStrs = [
		 //last items of categories must be untouched!!!
		//attributes
			//TypeCTors
				"const","immutable","inout","shared",
			//StorageClasses
				"extern","align","deprecated","static","abstract","final","override","synchronized","auto","scope","nothrow","pure","__gshared","ref","lazy","out",
			//ProtectionAttributes
				"private","protected","public","export","package",
		
		//values
			"null","false","true","this","super",
		
		//basic types
			//ints
				"byte","ubyte",             "short","ushort",               "int","uint",       "long","ulong",         //these are deprecated: "cent","ucent",
			//floats
				"float","double","real",    //these are deprecated: "ifloat","idouble","ireal",     "cfloat","cdouble","creal",
			//others
				"bool",                         "char","wchar","dchar",
			/+popular aliases: +/
				"string", "wstring", "dstring",
				"size_t", "sizediff_t", "ptrdiff_t", "noreturn",
		
				"File", "Path", "DateTime", "Time",
		
				"Object",
		
				"Vector",
				"vec2", "dvec2", "ivec2", "uvec2", "bvec2", "RG",
				"vec3", "dvec3", "ivec3", "uvec3", "bvec3", "RGB",
				"vec4", "dvec4", "ivec4", "uvec4", "bvec4", "RGBA",
		
				"Matrix",
				"mat2", "mat3", "mat4", "mat2x3", "mat2x4", "mat3x2", "mat3x4", "mat4x2", "mat4x3",
				"dmat2", "dmat3", "dmat4", "dmat2x3", "dmat2x4", "dmat3x2", "dmat3x4", "dmat4x2", "dmat4x3",
		
				"Bounds",
				"bounds1", "dbounds1", "ibounds1",
				"bounds2", "dbounds2", "ibounds2",
				"bounds3", "dbounds3", "ibounds3",
		
			//the last basic type is void:
				"void",
		
		//user definied types
			"alias","enum","interface","struct","class","union","delegate","function",
		
		//program keywords
			"asm"/*,"body" deprecated */,"break","case","catch","continue","default","do","else","finally","for","foreach","foreach_reverse","goto",
			"if","invariant","module","return","switch","template","throw","try","unittest","while","with",
			"assert","debug","import","mixin","version",
		
		//special functions
			"cast","pragma","typeid","typeof","__traits","__parameters","__vector",
		
		//special keywords
			"__EOF__","__DATE__","__TIME__","__TIMESTAMP__","__DATETIME__"/+//EXTRA+/,"__VENDOR__","__VERSION__",
			"__FILE__","__FILE_FULL_PATH__","__MODULE__","__LINE__","__FUNCTION__","__PRETTY_FUNCTION__",
		
		//operators
			"in","is","new", /*"delete",*/
	]; 
	
	//enum declaration
	mixin("enum {kwUnknown, kw"~_keywordStrs.join(",kw")~"}"); 
	
	enum KeywordCat
	{ Unknown, Attribute, Value, BasicType, UserDefiniedType, Keyword, SpecialFunct, SpecialKeyword, Operator} 
	
	KeywordCat kwCatOf(int k)
	{
		with(KeywordCat)
		{
			if(k<=kwUnknown		)
			return Unknown	; 
			if(k<=kwpackage		)
			return Attribute	; 
			if(k<=kwsuper	)
			return Value	; 
			if(k<=kwvoid	)
			return BasicType	; 
			if(k<=kwfunction	)
			return UserDefiniedType	; 
			if(k<=kwversion	)
			return Keyword	; 
			if(k<=kw__vector	)
			return SpecialFunct	; 
			if(k<=kw__PRETTY_FUNCTION__	)
			return SpecialKeyword	; 
			if(k<=kwnew	)
			return Operator	; 
			return Unknown; 
		}
	} 
	
	bool kwIsValid	  (int k)
	{ return kwCatOf(k)!=KeywordCat.Unknown	; } 
	bool kwIsAttribute	  (int k)
	{ return kwCatOf(k)==KeywordCat.Attribute	; } 
	bool kwIsValue	  (int k)
	{ return kwCatOf(k)==KeywordCat.Value	; } 
	bool kwIsBasicType	  (int k)
	{ return kwCatOf(k)==KeywordCat.BasicType	; } 
	bool kwIsUserDefiniedType	  (int k)
	{ return kwCatOf(k)==KeywordCat.UserDefiniedType	; } 
	bool kwIsKeyword	  (int	k)
	{ return kwCatOf(k)==KeywordCat.Keyword	; } 
	bool kwIsSpecialFunct		(int k)
	{ return kwCatOf(k)==KeywordCat.SpecialFunct	; } 
	bool kwIsSpecialKeyword	  (int k)
	{ return kwCatOf(k)==KeywordCat.SpecialKeyword	; } 
	bool kwIsOperator	  (int k)
	{ return kwCatOf(k)==KeywordCat.Operator	; } 
	
	int kwLookup(string s)
	{
		auto p = tdKeywords.lookup(s); 
		return p ? *p+1 : kwUnknown; 
	} 
	
	KeywordCat kwCatOf(string s)
	{ return kwCatOf(kwLookup(s)); } 
	
	string kwStr(int kw)
	{ return tdKeywords.keyOf(kw); } 
	
	
	////////////////////////////////////////////////////////////////////////////////
	///  Operators                                                               ///
	////////////////////////////////////////////////////////////////////////////////
	
	//whitespace: 20,09,0A,0D
	//01234567890123456789012345678901
	//numbers:	0123456789aAbBcCdDeEfFgGhHiIjJkK
	//letters:	lLmMnNoOpPqQrRsStTuUvVwWxXyYzZ_
	//symbols:	@!"#$%&'()*+-./[\]^_{|}~` :;<=>?
	
	//@
	//! !=
	//# unused
	//$ unused
	//% %=
	//& &= &&
	//* *=
	
	//+ += ++
	//- -= --
	//. .. ...
	/// /=
	//\ unused
	//^ ^= ^^ ^^=
	//| |= ||
	//~ ~=
	//:
	//;
	//< << <<= <=
	//= ==
	//> >> >>> >= >>= >>>=
	//?
	//in is new delete
	
	private enum _operatorStrs = [
		 //Todo: make it a Map, after it has a working static initializer.
			"."	, "dot"	, ".."	, "dotDot"	,	"..."	, "dotDotDot"	,
			"?"	, "question"	, ","	, "comma"	, ";"	, "semiColon"	,
			":"	, "colon"	, "$"	, "dollar"	, "@"	, "atSign"	,
			"="	, "assign"	, "=>"	, "lambda"	, "#"	, "hashMark"	,
			"\\"	, "backSlash"	,				//backslash only allower for for quoted texts
									
			"("	, "roundBracketOpen"	, ")"	, "roundBracketClose"	,		
			"["	, "squareBracketOpen"	, "]"	, "squareBracketClose"	,		
			"{"	, "curlyBracketOpen"	, "}"	, "curlyBracketClose"	,		
			"q{"	, "tokenString"	,				
									
			"!"	, "not"	,				
			"&"	, "and"	, "&="	, "AndAssign"	, "&&"	, "andAnd"	,
			"|"	, "or"	, "|="	, "OrAssign"	, "||"	, "orOr"	,
			"^"	, "xor"	, "^="	, "XorAssign"	,		
			"~"	, "complement"	, "~="	, "ComplementAssign"	,		
									
			"-"	, "sub"	, "-="	, "SubAssign"	, "--"	, "subSub"	,
			"+"	, "add"	, "+="	, "AddAssign"	, "++"	, "addAdd"	,
			"*"	, "mul"	, "*="	, "MulAssign"	,
			"/"	, "div"	, "/="	, "DivAssign"	,
			"%"	, "mod"	, "%="	, "ModAssign"	,
			"^^"	, "power"	, "^^="	, "PowerAssign"	,
							
			"<<"	 ,"shl"	 , "<<="	 ,"ShlAssign"	,
			">>"	 ,"sar"	 , ">>="	 ,"SarAssign"	,
			">>>"	 ,"shr"	 , ">>>="	 ,"ShrAssign"	,
							
			"<"	 ,"less"	 , "<="	 ,"LessEqual"	,
			">"	 ,"greater"	 , ">="	 ,"GreaterEqual"	,
			"=="	 ,"equal"	 ,
			"!="	 ,"notEqual"	 ,
		
		/*
			  "<>"       ,"lessGreater",         "<>="      ,"LessGreaterEqual",
				"!<"					 ,"notLess",	     "!<="	    ,"notLessEqual",
				"!>"					 ,"notGreater",	     "!>="	    ,"notGreaterEqual",
				"!<>"	     ,"notLessGreater",	     "!<>="	    ,"notLessGreaterEqual", these unordered compares are deprecated
		*/
		
			"in"	 ,"in"	, "is"	, "is"	, "new"	, "new"	, "delete"	, "delete"
	]; 
	
	string[] _operatorEnums()
	{
			string[] r; 
			foreach(idx, s; _operatorStrs)
		if(idx&1)
		r ~= "op"~s; 
		return r; 
	} string[] _operatorMaps()
	{
			string[] r; 
			foreach(idx, s; _operatorStrs)
		if(idx&1)
		r ~= '`'~_operatorStrs[idx-1]~"`:op"~s; 
		return r; 
	} 
	
	//enum declaration
	mixin("enum {opUnknown, "~_operatorEnums.join(',')~'}'); 
	
	int opParse(string s, ref int len)
	{
		auto p = tdOperators.parse(s, len); 
		return p ? *p : opUnknown; 
	} int opParse(string s)
	{
		int len; 
		return opParse(s, len); 
	} 
	
	string opStr(int op)
	{ return tdOperators.keyOf(op); } 
	
	////////////////////////////////////////////////////////////////////////////////
	///  Named Character Entries                                                 ///
	////////////////////////////////////////////////////////////////////////////////
	
	dchar nceLookup(string s)
	{
		auto p = tdNamedCharEntries.lookup(s); 
		return p ? *cast(dchar*)(p) : replacementDchar; 
	} 
	
	
	////////////////////////////////////////////////////////////////////////////////
	///  Token Dictionaries                                                      ///
	////////////////////////////////////////////////////////////////////////////////
	
	private: __gshared: 
	struct TokenDictionary(T)
	{
		T[string] arr; 
		int maxLen; 
		
		void postInit()
		{
			arr.rehash; 
			maxLen = 0; 
			foreach(s; arr.keys)
			maximize(maxLen, cast(int)s.length); 
		} 
		
		T* parse(string s, ref int resLen)
		{
			foreach_reverse(len; 1..min(maxLen, s.length)+1)
			{
				if(auto p = s[0..len] in arr)
				{
					resLen = len; 
					return p; 
				}
			}
			return null; 
		} 
		
		T* lookup(string s)
		{ return s in arr; } 
		
		string keyOf(const T value)
		{
			foreach(const kv; arr.byKeyValue)
			if(kv.value==value)
			return kv.key; 
			return ""; 
		} 
	} 
	
	__gshared TokenDictionary!(int) tdKeywords, tdOperators, tdNamedCharEntries; 
	
	public void initializeKeywordDictionaries()
	{
		//initKeywords;
		foreach(idx, s; _keywordStrs)
		tdKeywords.arr[s] = idx.to!int; 
		tdKeywords.postInit; 
		
		//init operators
		tdOperators.arr = mixin("["~_operatorMaps.join(',')~"]"); 
		tdOperators.postInit; 
		
		//init named char entries
		tdNamedCharEntries.arr = 
		[
			"quot":34,"amp":38,"lt":60,"gt":62,"OElig":338,"oelig":339,"Scaron":352,"scaron":353,"Yuml":376,"circ":710,"tilde":732,"ensp":8194,"emsp":8195,"thinsp":8201,
			"zwnj":8204,"zwj":8205,"lrm":8206,"rlm":8207,"ndash":8211,"mdash":8212,"lsquo":8216,"rsquo":8217,"sbquo":8218,"ldquo":8220,"rdquo":8221,"bdquo":8222,
			"dagger":8224,"Dagger":8225,"permil":8240,"lsaquo":8249,"rsaquo":8250,"euro":8364,"nbsp":160,"iexcl":161,"cent":162,"pound":163,"curren":164,"yen":165,
			"brvbar":166,"sect":167,"uml":168,"copy":169,"ordf":170,"laquo":171,"not":172,"shy":173,"reg":174,"macr":175,"deg":176,"plusmn":177,"sup2":178,"sup3":179,
			"acute":180,"micro":181,"para":182,"middot":183,"cedil":184,"sup1":185,"ordm":186,"raquo":187,"frac14":188,"frac12":189,"frac34":190,"iquest":191,
			"Agrave":192,"Aacute":193,"Acirc":194,"Atilde":195,"Auml":196,"Aring":197,"AElig":198,"Ccedil":199,"Egrave":200,"Eacute":201,"Ecirc":202,"Euml":203,
			"Igrave":204,"Iacute":205,"Icirc":206,"Iuml":207,"ETH":208,"Ntilde":209,"Ograve":210,"Oacute":211,"Ocirc":212,"Otilde":213,"Ouml":214,"times":215,
			"Oslash":216,"Ugrave":217,"Uacute":218,"Ucirc":219,"Uuml":220,"Yacute":221,"THORN":222,"szlig":223,"agrave":224,"aacute":225,"acirc":226,"atilde":227,
			"auml":228,"aring":229,"aelig":230,"ccedil":231,"egrave":232,"eacute":233,"ecirc":234,"euml":235,"igrave":236,"iacute":237,"icirc":238,"iuml":239,"eth":240,
			"ntilde":241,"ograve":242,"oacute":243,"ocirc":244,"otilde":245,"ouml":246,"divide":247,"oslash":248,"ugrave":249,"uacute":250,"ucirc":251,"uuml":252,
			"yacute":253,"thorn":254,"yuml":255,"fnof":402,"Alpha":913,"Beta":914,"Gamma":915,"Delta":916,"Epsilon":917,"Zeta":918,"Eta":919,"Theta":920,"Iota":921,
			"Kappa":922,"Lambda":923,"Mu":924,"Nu":925,"Xi":926,"Omicron":927,"Pi":928,"Rho":929,"Sigma":931,"Tau":932,"Upsilon":933,"Phi":934,"Chi":935,"Psi":936,
			"Omega":937,"alpha":945,"beta":946,"gamma":947,"delta":948,"epsilon":949,"zeta":950,"eta":951,"theta":952,"iota":953,"kappa":954,"lambda":955,"mu":956,
			"nu":957,"xi":958,"omicron":959,"pi":960,"rho":961,"sigmaf":962,"sigma":963,"tau":964,"upsilon":965,"phi":966,"chi":967,"psi":968,"omega":969,"thetasym":977,
			"upsih":978,"piv":982,"bull":8226,"hellip":8230,"prime":8242,"Prime":8243,"oline":8254,"frasl":8260,"weierp":8472,"image":8465,"real":8476,"trade":8482,
			"alefsym":8501,"larr":8592,"uarr":8593,"rarr":8594,"darr":8595,"harr":8596,"crarr":8629,"lArr":8656,"uArr":8657,"rArr":8658,"dArr":8659,"hArr":8660,
			"forall":8704,"part":8706,"exist":8707,"empty":8709,"nabla":8711,"isin":8712,"notin":8713,"ni":8715,"prod":8719,"sum":8721,"minus":8722,"lowast":8727,
			"radic":8730,"prop":8733,"infin":8734,"ang":8736,"and":8743,"or":8744,"cap":8745,"cup":8746,"int":8747,"there4":8756,"sim":8764,"cong":8773,"asymp":8776,
			"ne":8800,"equiv":8801,"le":8804,"ge":8805,"sub":8834,"sup":8835,"nsub":8836,"sube":8838,"supe":8839,"oplus":8853,"otimes":8855,"perp":8869,"sdot":8901,
			"lceil":8968,"rceil":8969,"lfloor":8970,"rfloor":8971,"loz":9674,"spades":9824,"clubs":9827,"hearts":9829,"diams":9830,"lang":10216,"rang":10217
		]; 
		tdNamedCharEntries.postInit; 
	} 
	
	
	
	
	////////////////////////////////////////////////////////////////////////////////
	///  GCN instruction detector                                                ///
	////////////////////////////////////////////////////////////////////////////////
	
	public: 
	
	bool isGCNInstruction(string s)
	{ return GCNInstructionKind(s)!=0; } 
	
	//returns nonzero if found something. 1=vector, 2=scalar 3=misc
	ubyte GCNInstructionKind(string s)
	{
											 //0	1	2	3	4	5	6
		static GCNPrefix1 = ["buffer_",	"ds_",	"flat_",	"image_",	"s_",	"tbuffer_",	"v_"]; 
		
		ubyte type; 
		bool found; 
		
		foreach(i, p; GCNPrefix1)
		if(s.startsWith(p))
		{
			found = true; 
			type = i==6 ? 1 : i==4 ? 2 : 3; //vector, scalar, misc
			break; 
		}
		
		if(!found)
		return 0; 
		
		static GCNPrefix2 = [
			"buffer_atomic", "buffer_load", "buffer_store", "buffer_wbinvl1", "ds_add", "ds_and", "ds_append", "ds_bpermute", "ds_cmpst",
			"ds_condxchg32", "ds_consume", "ds_dec", "ds_gws", "ds_inc", "ds_max", "ds_min", "ds_mskor", "ds_nop", "ds_or", "ds_ordered", "ds_permute", "ds_read",
			"ds_read2", "ds_read2st64", "ds_rsub", "ds_sub", "ds_swizzle", "ds_wrap", "ds_write", "ds_write2", "ds_write2st64", "ds_wrxchg", "ds_wrxchg2",
			"ds_wrxchg2st64", "ds_xor", "flat_atomic", "flat_load", "flat_store", "image_atomic", "image_gather4", "image_get", "image_load", "image_sample",
			"image_store", "s_abs", "s_absdiff", "s_add", "s_addc", "s_addk", "s_and", "s_andn2", "s_ashr", "s_atc", "s_barrier", "s_bcnt0", "s_bcnt1", "s_bfe", "s_bfm",
			"s_bitcmp0", "s_bitcmp1", "s_bitset0", "s_bitset1", "s_branch", "s_brev", "s_buffer", "s_cbranch", "s_cmov", "s_cmovk", "s_cmp", "s_cmpk", "s_cselect",
			"s_dcache", "s_decperflevel", "s_endpgm", "s_ff0", "s_ff1", "s_flbit", "s_getpc", "s_getreg", "s_icache", "s_incperflevel", "s_load", "s_lshl", "s_lshr",
			"s_max", "s_memrealtime", "s_memtime", "s_min", "s_mov", "s_movk", "s_movreld", "s_movrels", "s_mul", "s_mulk", "s_nand", "s_nop", "s_nor", "s_not", "s_or",
			"s_orn2", "s_quadmask", "s_rfe", "s_sendmsg", "s_sendmsghalt", "s_set", "s_sethalt", "s_setkill", "s_setpc", "s_setprio", "s_setreg", "s_setvskip", "s_sext",
			"s_sleep", "s_store", "s_sub", "s_subb", "s_swappc", "s_trap", "s_ttracedata", "s_waitcnt", "s_wakeup", "s_wqm", "s_xnor", "s_xor", "tbuffer_load",
			"tbuffer_store", "v_add", "v_addc", "v_alignbit", "v_alignbyte", "v_and", "v_ashr", "v_ashrrev", "v_bcnt", "v_bfe", "v_bfi", "v_bfm", "v_bfrev", "v_ceil",
			"v_clrexcp", "v_cmp", "v_cmps", "v_cmpsx", "v_cmpx", "v_cndmask", "v_cos", "v_cubeid", "v_cubema", "v_cubesc", "v_cubetc", "v_cvt", "v_div", "v_exp", "v_ffbh",
			"v_ffbl", "v_floor", "v_fma", "v_fract", "v_frexp", "v_interp", "v_ldexp", "v_lerp", "v_log", "v_lshl", "v_lshlrev", "v_lshr", "v_lshrrev", "v_mac", "v_mad",
			"v_madak", "v_madmk", "v_max", "v_max3", "v_mbcnt", "v_med3", "v_min", "v_min3", "v_mov", "v_movreld", "v_movrels", "v_movrelsd", "v_mqsad", "v_msad", "v_mul",
			"v_mullit", "v_nop", "v_not", "v_or", "v_perm", "v_qsad", "v_rcp", "v_readfirstlane", "v_readlane", "v_rndne", "v_rsq", "v_sad", "v_sin", "v_sqrt", "v_sub",
			"v_subb", "v_subbrev", "v_subrev", "v_trig", "v_trunc", "v_writelane", "v_xor"
		]; 
		
		found = false; 
		foreach(p; GCNPrefix2)
		if(s.startsWith(p))
		{ found = true; break; }
		if(!found)
		return 0; 
		
		static GCNSuffix = [
			"add", "all", "and", "append", "b", "b128", "b16", "b32", "b64", "b8", "b96", "barrier", "br", "branch", "buffer", "byte", "c", "cd",
					"cdbgsys", "cdbguser", "cl", "clrexcp", "cmpswap", "consume", "count", "d", "dec", "decperflevel", "dword", "dwordx16", "dwordx2", "dwordx3", "dwordx4",
					"dwordx8", "endpgm", "execnz", "execz", "f16", "f32", "f64", "fcmpswap", "fmax", "fmin", "fork", "gather4", "i16", "i24", "i32", "i4", "i64", "i8", "idx",
					"inc", "incperflevel", "init", "inv", "join", "l", "load", "lod", "lz", "memrealtime", "memtime", "mip", "mode", "nop", "o", "off", "on", "or", "p", "pck",
					"probe", "resinfo", "rsub", "sample", "saved", "sbyte", "sc", "scc0", "scc1", "sendmsg", "sendmsghalt", "sethalt", "setkill", "setprio", "setvskip", "sgn",
					"short", "sleep", "smax", "smin", "sshort", "store", "sub", "swap", "trap", "ttracedata", "u16", "u24", "u32", "u64", "u8", "ubyte", "ubyte0", "ubyte1",
					"ubyte2", "ubyte3", "umax", "umin", "user", "ushort", "v", "vccnz", "vccz", "vol", "waitcnt", "wakeup", "wb", "wbinvl1", "x", "x2", "xor", "xy", "xyz", "xyzw"
		]; 
		
		found = false; 
		foreach(p; GCNSuffix)
		if(s.endsWith("_"~p))
		{ found = true; break; }
		if(!found)
		return 0; 
		
		return type; 
	} 
	
	
	////////////////////////////////////////////////////////////////////////////////
	///  GLSL instruction detector                                               ///
	////////////////////////////////////////////////////////////////////////////////
	
	bool isGLSLInstruction(string s)
	{
		return ["gl_Position", "gl_FragColor"].canFind(s); //Todo: atirni among()-ra
	} 
	
	ubyte GLSLInstructionKind(string s)
	{
		 //0:do nothing, 1:keyword, 2:typeQual, 3:types, 4:values, 5:functs, 6:vars
		static GLSLKeywords = ["break","case","continue","default","do","else","for","if","discard","return","struct","switch","while"]; 
		static GLSLTypeQualifiers = ["attribute","const","inout","invariant","in","out","varying","uniform","flat","noperspective","smooth","centroid","layout","patch","subroutine", "half"]; 
		static GLSLTypes = [
			"bool","void","double","float","int","uint","bvec2","bvec3","bvec4","mat2","mat2x2","mat2x3","mat2x4","mat3","mat3x2","mat3x3","mat3x4","mat4","mat4x2",
					"mat4x3","mat4x4","dmat2","dmat2x2","dmat2x3","dmat2x4","dmat3","dmat3x2","dmat3x3","dmat3x4","dmat4","dmat4x2","dmat4x3","dmat4x4","dvec2","dvec3","dvec4","uvec2","uvec3",
					"uvec4","vec2","vec3","vec4","ivec2","ivec3","ivec4","sampler1D","sampler1DArray","sampler1DArrayShadow","sampler1DShadow","sampler2D","sampler2DArray","sampler2DArrayShadow",
					"sampler2DMS","sampler2DMSArray","sampler2DRect","sampler2DRectShadow","sampler2DShadow","sampler3D","samplerBuffer","samplerCube","samplerCubeArray","samplerCubeArrayShadow",
					"samplerCubeShadow","usampler1D","usampler1DArray","usampler2D","usampler2DArray","usampler2DMS","usampler2DMSarray","usampler2DRect","usampler3D","usamplerBuffer","usamplerCube","usamplerCubeArray"
		]; 
		static GLSLValues = ["true","false"]; 
		static GLSLFuncts = ["sample","isampler1D","isampler1DArray","isampler2D","isampler2DArray","isampler2DMS","isampler2DMSArray","isampler2DRect","isampler3D","isamplerBuffer","isamplerCube","isamplerCubeArray"]; 
		static GLSLVars = [
			"gl_VertexID","gl_InstanceID","gl_Position","gl_PointSize","gl_ClipDistance","gl_PatchVerticesIn","gl_PrimitiveID","gl_InvocationID","gl_in","gl_TessLevelOuter",
					"gl_TessLevelInner","gl_out","gl_TessCoord","gl_PrimitiveIDIn","gl_FragColor","gl_FragCoord","gl_FragDepth","gl_FrontFacing","gl_PointCoord","gl_SamplePosition","gl_SampleMaskIn","gl_Layer","gl_ViewportIndex","gl_SampleMask"
		]; 
		
		//Todo: make it faster with a map
		
		if(GLSLKeywords.canFind(s))
		return 1; 
		if(GLSLTypeQualifiers.canFind(s))
		return 2; 
		if(GLSLTypes.canFind(s))
		return 3; 
		if(GLSLValues.canFind(s))
		return 4; 
		if(GLSLFuncts.canFind(s))
		return 5; 
		if(GLSLVars.canFind(s))
		return 6; 
		return 0; 
	} 
	
	////////////////////////////////////////////////////////////////////////////////
	///  Syntax highlight presets                                                ///
	////////////////////////////////////////////////////////////////////////////////
	
	struct SyntaxStyle
	{
		RGB fontColor, bkColor; 
		int fontFlags; //1:b, 2:i, 4:u
	} 
	
	static if(0)
	class SyntaxPreset_future
	{
		 //future
		SyntaxStyle
		//standard language things
			whitespace, number, binary1, string_, keyword, symbol, directive, label, attribute, basicType,
		//editor functionality
			selected, foundAct, foundAlso, navLink,
		//development stuff
			comment, error, warning, deprecation, todo, optimize,
		//extra language things
			identifier1, identifier2, identifier3, identifier4, identifier5, identifier6; 
		
		
		//testCode
		
		immutable testCode = q{
			@directive void get() const
			{
				 //comment
				return value + 123 + 5.6 + 0b1100101 * "42".to!int; 
			} 
			/*comment*/ /*Todo: ...*/ /*Opt: ...*/
			selected  foundAct	foundAlso  navLink
			error  warning  deprecation
			
			//GLSL
			
			//GCN ASM
			
			
		}; 
	} 
	
	
	struct SyntaxStyleRow
	{
		string kindName; 
		SyntaxStyle[] formats; 
	} 
	
	
	//Todo: these should be uploaded to the gpu
	//Todo: from the program this is NOT extendable
	immutable syntaxPresetNames =	             ["Default"             , "Classic"                         , "C64"                   , "Dark"                     ]; 
	immutable SyntaxStyleRow[] syntaxTable =[
		{"Whitespace"	, [{ clBlack	,clWhite	,0}, { clVgaYellow	,clVgaLowBlue	,0}, { clC64LBlue	,clC64Blue	,0}, { 0xc7c5c5	,0x2f2f2f ,0}]},
		{"Selected"	, [{ clWhite	,10841427	,0}, { clVgaLowBlue	,clVgaLightGray	,0}, { clC64Blue	,clC64LBlue	,0}, { clBlack	,clPink ,0}]},
		{"FoundAct"	, [{ 0xFCFDCD	,clBlack	,0}, { clVgaLightGray	,clVgaBlack	,0}, { clC64LGrey	,clC64Black	,0}, { clBlack	,clPink ,0}]},
		{"FoundAlso"	, [{ clBlack	,0x78AAFF	,0}, { clVgaLightGray	,clVgaBrown	,0}, { clC64LGrey	,clC64DGrey	,0}, { clBlack	,clPink.darken(.25) ,0}]},
		{"NavLink"	, [{ clBlue	,clWhite	,4}, { clVgaHighRed	,clVgaLowBlue	,4}, { clC64Red	,clC64Blue	,0}, { 0xFF8888	,0x2d2d2d ,4}]},
		{"Number"	, [{ clBlue	,clWhite	,0}, { clVgaYellow	,clVgaLowBlue	,0}, { clC64Yellow	,clC64Blue	,0}, { 0x0094FA	,0x2d2d2d ,0}]},
		{"String"	, [{ clBlue	,clSkyBlue	,0}, { clVgaHighCyan	,clVgaLowBlue	,0}, { clC64Cyan	,clC64Blue	,0}, { 0x64E000	,0x283f28 ,0}]},
		{"Keyword"	, [{ clNavy	,clWhite	,1}, { clVgaWhite	,clVgaLowBlue	,1}, { clC64White	,clC64Blue	,0}, { 0x5C00F6	,0x2d2d2d ,1}]},
		{"Symbol"	, [{ clBlack	,clWhite	,0}, { clVgaYellow	,clVgaLowBlue	,0}, { clC64Yellow	,clC64Blue	,0}, { 0x00E2E1	,0x2d2d2d ,0}]},
		{"Comment"	, [{ clNavy	,clYellow	,2}, { clVgaLightGray	,clVgaLowBlue	,2}, { clC64LGrey	,clC64Blue	,0}, { 0xf75Dd5	,0x442d44 ,2}]},
		{"Directive"	, [{ clTeal	,clWhite	,0}, { clVgaHighGreen	,clVgaLowBlue	,0}, { clC64Green	,clC64Blue	,0}, { 0x4Db5e6	,0x2d4444 ,0}]},
		{"Identifier1"	, [{ clBlack	,clWhite	,0}, { clVgaYellow	,clVgaLowBlue	,0}, { clC64Yellow	,clC64Blue	,0}, { 0xc7c5c5	,0x2d2d2d ,0}]},
		{"Identifier2"	, [{ clGreen	,clWhite	,0}, { clVgaHighGreen	,clVgaLowBlue	,0}, { clC64LGreen	,clC64Blue	,0}, { clGreen	,0x2d2d2d ,0}]},
		{"Identifier3"	, [{ clTeal	,clWhite	,0}, { clVgaHighCyan	,clVgaLowBlue	,0}, { clC64Cyan	,clC64Blue	,0}, { clTeal	,0x2d2d2d ,0}]},
		{"Identifier4"	, [{ clPurple	,clWhite	,0}, { clVgaHighMagenta	,clVgaLowBlue	,0}, { clC64Purple	,clC64Blue	,0}, { 0xf040e0	,0x2d2d2d ,0}]},
		{"Identifier5"	, [{ 0x0040b0	,clWhite	,0}, { clVgaBrown	,clVgaLowBlue	,0}, { clC64Orange	,clC64Blue	,0}, { 0x0060f0	,0x2d2d2d ,0}]},
		{"Identifier6"	, [{ 0xb04000	,clWhite	,0}, { clVgaHighBlue	,clVgaLowBlue	,0}, { clC64LBlue	,clC64Blue	,0}, { 0xf06000	,0x2d2d2d ,0}]},
		{"Label"	, [{ clBlack	,0xDDFFEE	,4}, { clBlack	,clVgaHighCyan	,0}, { clBlack	,clC64Cyan	,0}, { 0xFFA43B	,0x2d2d2d ,2}]},
		{"Attribute"	, [{ clPurple	,clWhite	,1}, { clVgaHighMagenta	,clVgaLowBlue	,1}, { clC64Purple	,clC64Blue	,1}, { 0xAAB42B	,0x2d2d2d ,1}]},
		{"BasicType"	, [{ clTeal	,clWhite	,1}, { clVgaHighCyan	,clVgaLowBlue	,1}, { clC64Cyan	,clC64Blue	,1}, { clWhite	,0x2d2d2d ,1}]},
		{"Binary1"	, [{ clWhite	,clBlue	,0}, { clVgaLowBlue	,clVgaYellow	,0}, { clC64Blue	,clC64Yellow	,0}, { 0x2d2d2d	,0x20bCFA ,0}]},
		{"Error"	, [SyntaxStyle(clWhite	,clRed     ,0)].replicate(4)},
		{"Exception"	, [SyntaxStyle(clYellow	,clRed     ,0)].replicate(4)},
		{"Warning"	, [SyntaxStyle(clBlack	,clYellow     ,0)].replicate(4)},
		{"Deprecation"	, [SyntaxStyle(clBlack	,clAqua      ,0)].replicate(4)},
		{"Note"	, [SyntaxStyle(clBlack	,clPostit,2)].replicate(4)},
		{"Todo"	, [SyntaxStyle(clWhite	,clWowBlue   ,2)].replicate(4)},
		{"Opt"	, [SyntaxStyle(clWhite	,clWowPurple	,2)].replicate(4)},
		{"Bug"	, [SyntaxStyle(clWhite	,clOrange	,2)].replicate(4)},
		{"Link"	, [SyntaxStyle(clWowBlue	,clWhite    ,4)].replicate(4)},
		{"Code"	, [SyntaxStyle(RGB(0xc7c5c5)	, mix(RGB(0x2f2f2f), RGB(0x442d44), .33) ,0)].replicate(4)}, //code is actually a codeComment, not compileable code.
		{"Console"	, [SyntaxStyle(clWhite ,clBlack,0)].replicate(4)},
		{"Interact"	, [SyntaxStyle(clBlack ,clWhite,0)].replicate(4)}
	]; 
	
	mixin(format!"enum SyntaxKind:ubyte   {%s}"(syntaxTable.map!"a.kindName".join(','))); 
	mixin(format!"enum SyntaxPreset {%s}"(syntaxPresetNames.join(','))); 
	
	static foreach(m; EnumMembers!SyntaxKind)
	mixin("alias sk* = SyntaxKind.*;".replace('*', m.text)); 
	
	__gshared defaultSyntaxPreset = SyntaxPreset.Dark; 
	
	//Todo: slow, needs a color theme struct
	auto syntaxFontColor(string syntax)
	{ return syntaxTable[syntax.to!SyntaxKind.to!int].formats[defaultSyntaxPreset].fontColor; } 
	auto syntaxBkColor  (string syntax)
	{ return syntaxTable[syntax.to!SyntaxKind.to!int].formats[defaultSyntaxPreset].bkColor; } 
	
	auto syntaxFontColor(SyntaxKind syntax)
	{ return syntaxTable[syntax].formats[defaultSyntaxPreset].fontColor; } 
	auto syntaxBkColor  (SyntaxKind syntax)
	{ return syntaxTable[syntax].formats[defaultSyntaxPreset].bkColor; } 
	
	//Opt: slow, needs a color theme struct, and needs an enum for the syntaxkind.
	//Todo: this is a good example for table view in DIDE2
	
	deprecated auto clEmptyLine()
	{ return mix(syntaxBkColor("Whitespace"), syntaxBkColor("Whitespace").l>0x80 ? clWhite : clBlack, 0.0625f); } 
	
	auto clCodeBackground	()
	{ return syntaxBkColor("Whitespace"); } 
	auto clCodeFont	()
	{ return syntaxFontColor("Identifier1"); } 
	auto clCodeBorder	()
	{ return mix(syntaxBkColor("Whitespace"), syntaxFontColor("Whitespace"), .4f); } 
	auto clGroupBackground()
	{ return mix(syntaxBkColor("Whitespace"), syntaxFontColor("Whitespace"), .1f); } 
	auto clGroupBorder    ()
	{ return mix(syntaxBkColor("Whitespace"), syntaxFontColor("Whitespace"), .4f); } 
}version(/+$DIDE_REGION D Parser+/all)
{
	struct CodeLocation
	{
		File file /+Note: Case Sensitive.  Must be the correct case.+/; 
		int lineIdx, columnIdx, mixinLineIdx; 
		uint moduleHash; 
		
		this(string file_, int lineIdx_, int columnIdx_=0, int mixinLineIdx_=0)
		{
			file 	= file_,
			lineIdx 	= lineIdx_,
			columnIdx 	= columnIdx_,
			mixinLineIdx 	= mixinLineIdx_; 
			recalcModuleHash; 
		} 
		
		this(string s_)
		{
			//example: onlineapp.d-mixin-4(4,4)
			
			version(/+$DIDE_REGION+/none) {
				import std.regex; 
				static rx = ctRegex!(`^([^\-\(]*)(?:\-mixin\-([0-9]+))?(?:\( *([0-9]+) *(?:, *([0-9]+))? *\) *)?$`); 
				auto m = s.matchFirst(rx); 
				if(m.length)
				{
					file 	= m[1].File,
					mixinLineIdx 	= m[2].to!int.ifThrown(0),
					lineIdx 	= m[3].to!int.ifThrown(0),
					columnIdx 	= m[4].to!int.ifThrown(0); 
				}
			}
			
			/+Opt: examine which is faster: regex or manual+/
			
			try
			{
				auto s = s_.strip; 
				if(s.length && s.back==')')
				{
					const i = s.countUntil('('); //Opt: count from the back.
					if(i>=0)
					{
						auto lc = s[i+1..$-1].splitter(','); 
						if(!lc.empty) { lineIdx = lc.front.strip.to!int; lc.popFront; }
						if(!lc.empty) columnIdx = lc.front.strip.to!int; 
						s = s[0..i]; 
					}
				}
				
				auto p = s.split("-mixin-"); 
				while(p.length>1)
				{
					mixinLineIdx = p.back.to!int; 
					p.popBack; 
					/+
						Todo: It only remembers the FIRST mixin line in the chain. 
						Should handle mixin chains differently.
						Currently it's not handled, just displayed.
						It could be a supplemental message like: "mixed in from" ...
					+/
				}
				if(p.length==1)
				file = File(p.front); 
			}
			catch(Exception e)
			{
				WARN("Can't decode CodePosition: "~s_.quoted); 
				this = typeof(this).init; 
			}
			
			recalcModuleHash; 
		} 
		
		
		void recalcModuleHash()
		{ moduleHash = file.fullName.xxh32; } 
		
		bool opCast(T:bool)() const
		{ return cast(bool)file; } 
		
		int opCmp(in CodeLocation b) const //case sens!!!
		{
			return 	cmp(file.fullName, b.file.fullName)
				.cmpChain(cmp(lineIdx, b.lineIdx))
				.cmpChain(cmp(columnIdx, b.columnIdx))
				.cmpChain(cmp(mixinLineIdx, b.mixinLineIdx)); 
		} 
		
		bool opEquals(in CodeLocation b) const //case sens!!!
		{
			return 	file.fullName == b.file.fullName &&
				lineIdx == b.lineIdx &&
				columnIdx == b.columnIdx &&
				mixinLineIdx == b.mixinLineIdx; 
		} 
		
		size_t toHash() const
		{ return file.fullName.hashOf(only(lineIdx, columnIdx, mixinLineIdx).hashOf); } 
		
		
		bool isMixin() const
		{ return !!mixinLineIdx; } 
		
		string lineText() const
		{ return (lineIdx ? format!"(%d)"(lineIdx) : ""); } 
		
		string lineColText() const
		{
			if(lineIdx && columnIdx) return format!"(%d,%d)"(lineIdx, columnIdx); 
			return lineText; 
		} 
		
		string mixinText() const
		{ return isMixin ? "-mixin-"~mixinLineIdx.text : ""; } 
		
		string toString() const
		{ return file.fullName ~ mixinText ~ lineColText; } 
		
	} 
	
	//Todo: editor: mouse back/fwd navigalas, mint delphiben
	//Todo: 8K, 8M, 8G should be valid numbers! Preprocessing job...
	
	//global thing to share compiler specific paths stuff
	struct DPaths
	{
		   //Todo: Path-osra atirni
		static __gshared: 
		/*
			  string installPath = `c:\D\dmd2\`; //todo: it's not good for LDC2
				string stdPath()				 { return installPath~`src\phobos\`; };
				string etcPath()				 { return installPath~`src\phobos\`; };
				string corePath()	    { return installPath~`src\druntime\src\`; };
				string libPath()	    { return installPath~`windows\lib\`; } //todo: 64bit DPaths.libPath
		*/
		
			//LDC 64bit paths
			string installPath = `c:\D\ldc2\`; 
			string stdImportPath()  
		{ return installPath~`import\`; } 
			string stdPath()				
		{ return stdImportPath~`std\`; } 
			string etcPath()				
		{ return stdImportPath~`etc\`; } 
			string corePath()	   
		{ return stdImportPath~`core\`; } 
			string ldcPath()				
		{ return stdImportPath~`ldc\`; } 
			string libPath()				
		{ return installPath~`lib64\`; } 
		
			string[] systemPaths()
		{ return [stdPath, corePath, etcPath, ldcPath]; } 
			string[] importPaths; 
			string[] allPaths()
		{ return importPaths ~ systemPaths; } 
		
			void init()
		{ importPaths.clear; } 
		
			void includeDelimiters()
		{
			foreach(ref p; importPaths)
			p = includeTrailingPathDelimiter(p); 
		} 
		
			void addImportPath(string path)
		{
			path = path.strip; 
			if(path.empty)
			return; 
			foreach(p; importPaths)
			if(samePath(path, p))
			return; 
			importPaths ~= path.includeTrailingPathDelimiter; 
		} 
		
			void addImportPathList(string paths)
		{
			foreach(path; paths.split(';'))
			{ addImportPath(path); }
		} 
		
			string getImportPathList()
		{
			includeDelimiters; 
			return importPaths.join(";"); 
		} 
		
			bool isStdFile(in File f)
		{ return f.fullName.isWild(stdImportPath~"*"); } 
	} 
	
	/// This is a nicer looking version than syntaxHighLight, but it lacks a lot of functionality.
	struct BracketHierarchyProcessor
	{
		public: 
			string fileName; //for error report
			string errorStr; 
			bool wasError() const
		{ return errorStr!=""; } 
		
			string process(string fileName, ref Token[] tokens)
		{
			this.fileName = fileName; 
			queue = null; 
			tokenStringLevel = 0; 
			errorStr = ""; 
			
			foreach(ref t; tokens)
			{
				process(t); 
				if(wasError)
				break; 
			}
			finalize; 
			return errorStr; 
		} 
		
		private: 
			struct QueueRec
		{
			Token* startToken; 
			bool isTokenString; 
			int endOp; 
		} 
		
			QueueRec[] queue; //ending prackets land here
			int tokenStringLevel; //greater than 0 means inside a tokenstring
		
			void addError(Token* token, string err)
		{
			if(!wasError && err!="")
			{ errorStr = format("%s(%s:%s): %s", fileName, token.line, token.posInLine, err); }
		} 
		
			void process(ref Token t)
		{
			if(isClosingBracket(t))
			{
				if(queue.empty)
				{ addError(&t, format(`Unpaired closing bracket "%s".`, t.source)); }else if(t.id!=queue.back.endOp)
				{ addError(&t, format(`Unpaired closing bracket "%s". Expected "%s".`, t.source, opStr(queue.back.endOp))); }else
				{
					if(queue.back.isTokenString)
					tokenStringLevel--; 
					queue.popBack; 
				}
			}
			
			t.level = queue.length.to!int; 
			t.isTokenString = tokenStringLevel>0; 
			
			if(int eb = endingBracketOf(t))
			{
				bool isTS = t.id==optokenString; 
				queue ~= QueueRec(&t, isTS, eb); 
				if(isTS)
				tokenStringLevel++; 
			}
		} 
		
			void finalize()
		{
			if(queue.length)
			with(queue.back)
			{ addError(startToken, format(`Closing bracket expected: "%s".`, opStr(endOp))); }
		} 
		
			static bool isClosingBracket(ref Token t)
		{
			if(t.kind!=TokenKind.operator)
			return false; 
			switch(t.id)
			{
				case oproundBracketClose: case opsquareBracketClose: case opcurlyBracketClose: return true; 
				default: return false; 
			}
		} 
			static int endingBracketOf(ref Token t)
		{
			if(t.kind!=TokenKind.operator)
			return 0; 
			switch(t.id)
			{
				case oproundBracketOpen: return oproundBracketClose; 
				case opsquareBracketOpen: return opsquareBracketClose; 
				case opcurlyBracketOpen: case optokenString: return opcurlyBracketClose; 
				default: return 0; 
			}
		} 
		
			unittest
		{
			bool test(string text)
			{
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
	struct ModuleFullName
	{
		string[] identifiers; 
		string fullName() const
		{ return identifiers.join('.'); } ; 
		string fileName() const
		{ return identifiers.length ? identifiers.join('\\')~".d" : ""; } ; 
	} 
	
	struct ImportBind
	{ string alias_, name; } 
	
	struct ImportDecl
	{
		ModuleFullName name; 
		string alias_; 
		bool isPublic, isStatic; 
		ImportBind[] binds; 
		
		private bool nameStartsWith(string s) const
		{ return name.identifiers.length && name.identifiers[0]==s; } 
		bool isStdModule () const
		{ return nameStartsWith("std"); } //Todo: make these automatic from list like "std, etc, ldc, code"
		bool isEtcModule () const
		{ return nameStartsWith("etc"); } 
		bool isCoreModule() const
		{ return nameStartsWith("core"); } 
		bool isLdcModule () const
		{ return nameStartsWith("ldc"); } 
		bool isUserModule() const
		{ return !isStdModule && !isCoreModule && !isEtcModule && !isLdcModule; } 
		
		File resolveFile(Path mainPath, string baseFileName, bool mustExists) const //returns "" if not found. Must handle outside.
		{
			 //Todo: use FileName, FilePath
			const fn = name.fileName; 
			string[] paths	= (
				 isStdModule	? [DPaths.stdPath] 
							: isEtcModule	? [DPaths.etcPath] 
							: isCoreModule	? [DPaths.corePath]
							: isLdcModule	? [DPaths.ldcPath]
								: [mainPath.fullPath]
			)
				~ DPaths.importPaths; 
			string s; 
			foreach(p; paths)
			{
				s = includeTrailingPathDelimiter(p)~fn; 
				if(File(s).exists)
				return File(s).actualFile; //it's a module
				s = File(s).otherExt("").fullName ~ `\package.d`; 
				if(File(s).exists)
				return File(s).actualFile; //it's a module
			}
			
			
			const err = "Module not found: "~fn~"  referenced from: "~baseFileName; 
			if(mustExists)	raise(err); 
			else	WARN(err); 
			
			return File.init; 
		} 
	} 
	
	//Todo: This must be realized with a table and include the help text too.
	enum BuildMacroCommand { exe, dll, res, def, win, compile, link, ldclink, run, import_, release, debug_, single, ldc} 
	static immutable validBuildMacroCommands = EnumMemberNames!BuildMacroCommand.map!(a=>a.withoutEnding('_')).array; 
	
	class Parser
	{
			
			string fileName, source; 
			Token[] tokens; 
		
			string[] buildMacros; 
			string[] todos; 
			ImportDecl[] importDecls; 
		
			string errorStr; 
			bool wasError() const	
		{ return errorStr!=""; } 
			private void error(string err)	
		{
			if(err)
			errorStr = join2(errorStr, "\n", err); 
		} 
			private void error(Token* t, string err)	
		{
			if(err)
			error(format("%s(%d:%d): %s", fileName, t.line, t.posInLine, err)); 
		} 
		
			//stats
			int sourceLines()    
		{ return tokens.empty ? 0 : tokens[$-1].line+1; } 
		
			//1. Tokenize
			void tokenize(string fileName)
		{ tokenize(fileName, File(fileName).readText); } 
			void tokenize(string fileName, string source)
		{
			this.fileName = fileName; 
			this.source = source; 
			
			buildMacros = []; 
			importDecls = []; 
			todos = []; 
			tokens = []; 
			errorStr = ""; 
			
			//Tokenizing
			auto tokenizer = scoped!Tokenizer; 
			string tokenizerError = tokenizer.tokenize(fileName, source, tokens); 
			if(tokenizerError!="")
			error(tokenizerError); 
			
			//Bracket Hierarchy
			if(!wasError)
			{
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
			auto extractUntilOp(int idx, int opEnd)
		{
			if(idx>=tokens.length)
			return null; 
			Token*[] res; 
			int level = tokens[idx].level; 
			for(; idx<tokens.length; idx++)
			{
				auto act = &tokens[idx]; 
				if(act.isComment)
				continue; 
				if(act.level<level)
				return null; //lost the scope too early
				if(act.isOperator(opEnd))
				return res; //gotcha
				res ~= act; //accumulate
			}
			return null; //can't find opEnd
		} 
		
			auto findAllKeywordIndices(int kw, bool insideTokenStringsToo = false)
		{
			int[] res; 
			foreach(i, ref t; tokens)
			{
				if(t.isTokenString && !insideTokenStringsToo)
				continue; 
				if(t.isKeyword(kw))
				res ~= i.to!int; 
			}
			return res; 
		} 
		
			auto findFirstKeywordIndex(int kw, bool insideTokenStringsToo = false)
		{
			foreach(i, ref t; tokens)
			{
				if(t.isTokenString && !insideTokenStringsToo)
				continue; 
				if(t.isKeyword(kw))
				return i.to!int; 
			}
			return -1; 
		} 
		
			//parse all module imports in the file   //todo: errol syntax highlight
			auto collectBuildMacrosAndTodos(out string[] macros, out string[] todos) //updates Token.isBuildCommant
		{
			//Todo: Multiline Todo: is NOT recognized by this preprocessor
			//Todo: Only slashcomment todos are recognized by this preprocessor
			/+
				Note: It is better to keep do the detection here, because 
				it collects all the todos for the compiled project, not just the opened structured files in DIDE.
			+/
			auto rxTodo	= ctRegex!(`\/\/todo:(.*)`, `gi`); 
			auto rxOpt	= ctRegex!(`\/\/opt:(.*)`, `gi`); 
			auto rxBug	= ctRegex!(`\/\/bug:(.*)`, `gi`); 
			
			foreach(ref cmt; tokens)
			{
				if(cmt.isComment)
				{
					if(cmt.source.startsWith("//@"))
					{
						auto 	line 	= cmt.source[3..$],
							command 	= line.wordAt(0).lc; 
						if(validBuildMacroCommands.canFind(command)/+valid buildmacro command?+/)
						{ cmt.isBuildMacro = true; macros ~= line; }
					}else
					{
						auto s = cmt.source[2..$].stripLeft; 
						foreach(kw; ["todo:", "bug:", "opt:"])
						if(s.map!toLower.startsWith(kw))
						{
							s = s[kw.length..$]; 
							if(s.startsWith(' ')) s = s[1..$]; //strip optional space after keyword
							if(cmt.source[1].among('+', '*')) s = s[0..$-2]; //strip closing comment token
							
							foreach(line; s.splitter('\n').map!strip.filter!"a.length".enumerate)
							{
								todos ~= 	i`$(fileName)($(cmt.line+1),$(cmt.posInLine+1)): `.text /+source location+/~
									((line.index==0)?(i`$(kw.capitalize) $(line.value)`.text/+main comment+/) :(i`       $(line.value)`.text/+supplemental comment+/)); 
							}
							
							break; 
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
		
			void seek(int n)
		{
			actIdx = n; 
			while(actIdx<tokens.length && tokens[actIdx].isComment)
			actIdx++; //skip comments
			eof = actIdx>=tokens.length; 
			sym = eof ? &nullToken : &tokens[actIdx]; 
		} 
		
			bool nextSym()
		{
			if(!eof)
			{ seek(actIdx+1); return true; }else
			{ return false; }
		} 
		
			bool acceptKw(int kw)
		{
			bool b = sym.isKeyword (kw); if(b)
			nextSym; return b; 
		} 
			bool acceptOp(int op)
		{
			bool b = sym.isOperator(op); if(b)
			nextSym; return b; 
		} 
		
			//Todo: ezt megcsinalni, hogy kozos id-je legyen az operatoroknak meg a keyworokdnek is
			void expectKw(int kw)
		{
			if(sym.isKeyword (kw))
			nextSym; else
			error(format(`"%s" expected.`, kwStr(kw))); 
		} 
			void expectOp(int op)
		{
			if(sym.isOperator(op))
			nextSym; else
			error(format(`"%s" expected.`, opStr(op))); 
		} 
		
			auto expectIdentifier()
		{
			if(!sym.isIdentifier)
			error("Identifier expected. "~format(`%s(%d,%d): %s`, fileName, sym.line+1, sym.posInLine+1, sym.source)); 
			auto s = sym.source; 
			nextSym; 
			return s; 
		} 
		
			auto expectIdentifierList(int opSeparator)
		{
			string[] res; 
			do
			{ res ~= expectIdentifier; }while(acceptOp(opSeparator)); 
			return res; 
		} 
		
			//end of parser stuff/////////////////////////////
		
			//find the module keyword and get the full module name.
			public auto getModuleFullName()
		{
			 string res; 
			 auto idx = findFirstKeywordIndex(kwmodule); 
			 if(idx>=0)
			{
				 idx++; 
				 while(idx<tokens.length && tokens[idx].isComment)
				idx++; 
				 while(idx<tokens.length && (tokens[idx].isIdentifier || tokens[idx].isOperator(opdot)))
				{
					 res ~= tokens[idx].source; 
					 idx++; 
				}
			}
			 return res; 
		} 
		
			//parse all module imports in the file
			auto collectImports()
		{
			//Todo: public/static/private imports
			ImportDecl[] res; 
			
			auto importTokensIndices = findAllKeywordIndices(kwimport, true); 
			foreach(idx; importTokensIndices)
			{
				
				seek(idx); 
				if(acceptKw(kwimport))
				{
					nextModule: 
					res.length++; 
					auto decl = &res.back; 
					
					//[alias =] module[full]name
					auto sl = expectIdentifierList(opdot); 
					if(acceptOp(opassign))
					{
						 //alias
						if(sl.length>1)
						error(`Alias can't contain multiple identifiers.`); 
						decl.alias_ = sl[0]; 
						decl.name.identifiers = expectIdentifierList(opdot); 
					}else
					{ decl.name.identifiers = sl; }
					
					if(acceptOp(opcomma))
					{
						 //has more modules
						goto nextModule; 
					}else if(acceptOp(opcolon))
					{
						 //current module has bindings
						nextBind: 
						decl.binds.length++; 
						auto bind = &decl.binds.back; 
						
						auto s = expectIdentifier; 
						if(acceptOp(opassign))
						{
							 //bind alias
							bind.alias_ = s; 
							bind.name = expectIdentifier; 
						}else
						{ bind.name = s; }
						
						if(acceptOp(opcomma))
						{
							 //has more binds
							goto nextBind; 
						}
					}
					expectOp(opsemiColon); 
				}
				
			}
			
			return res; 
		} 
		
		
		
	} 
}version(/+$DIDE_REGION+/all)
{
	struct StructureScanner
	{
		static: 
		
		///This version of startsWith() stops at the first needle, not returning the shortest needle (phobos version).
		///The result is 0 based.  -1 means not found.
		
		alias startsWithToken =
		//startsWithToken_X86
		startsWithToken_SSE42; 
		
		enum utils = /+Note: These can be injected into a function code with a local 'scanner'.+/
		q{
			string peek() => ((scanner.empty)?(""):(scanner.front.src)); 
			void skipWhite() { scanner.find!((a)=>(!a.src.all!isWhite)); } 
			auto expect(string[] a...) { const r = a.countUntil(peek); enforce(r>=0, a.text~" expected."); scanner.popFront; return r; } 
		}; 
		
		sizediff_t startsWithToken_X86(string[] tokens)(string s)
		{
			static foreach(tIdx, token; tokens)
			{
				{
					//Opt: slow linear search. Should use a char map for the first char. Or generate a switch statement.
					if(startsWith(s, token))
					return tIdx; 
				}
			}
			return -1; 
		} 
		
		sizediff_t startsWithToken_SSE42(string[] tokens_)(string s)
		{
			//Empty token ("") handing.
			static if(tokens_.canFind(""))
			{
				static assert(tokens_.back=="", `Empty token ("") is not at the end of tokens.`); 
				enum tokens = tokens_[0..$-1]; 
				static assert(!tokens.canFind(""), `Only one empty token ("") allowed.`); 
				enum DefaultResult = tokens.length; 
			}else
			{
				enum tokens = tokens_; 
				enum DefaultResult = -1; 
			}
			
			static if(tokens.length==1)
			{
				 //trivial case: only 1 token
				return (cast(ubyte[])s).startsWith(cast(ubyte[])tokens[0]) ? 0 : DefaultResult; 
			}else
			{
				//own version of startsWith is dealing with ubytes instead of codepoints.
				static bool startsWith(string s, string what)
				{ return .startsWith(cast(ubyte[])s, cast(ubyte[])what); } 
				
				//simple tokens are 1 byte long and no other tokens are starting with them.
				static bool isSimple(string tk)
				{ return tk.length==1 && tokens.filter!(t => t.startsWith(tk)).walkLength==1; } 
				static string i2str(T)(T i)
				{ return text(cast(char)(i.to!ubyte)); } 
				static immutable 	simpleTokens	= tokens.filter!isSimple.array,
					charSet	= tokens.map!"ubyte(a[0])".array.sort.uniq.array; 
				
				//generate arrays based on charSetIndex
				enum GEN(alias trueFun, alias falseFun) = charSet.map!i2str.map!(a => simpleTokens.canFind(a) ? a.unaryFun!trueFun : a.unaryFun!falseFun).array; 
				enum tokensStartingWith(alias tk) = tokens.filter!(a => startsWith(a, tk)); 
				static immutable 	simpleIdx 	= GEN!(tk => tokens.countUntil(tk)	, tk => -1 /+Note: It's complex, not DefaultResult. +/		),
					complexSubTokens	= GEN!(tk => string[].init	, tk => tokensStartingWith!tk.map!(a => a[1..$])	.array	),
					complexSubTokenIndices	= GEN!(tk => sizediff_t[].init	, tk => tokensStartingWith!tk.map!(a => tokens.countUntil(a))	.array	); 
				
				//debug dump of tables
				static if(0)
				{
					pragma(msg, format!"%s (%2d%s): %s"("tokens"	, tokens.length, DefaultResult>=0 ? "+empty" : "", tokens.join("  ").quoted	)); 
					enum charSetInfo = GEN!(tk => tk.quoted, tk => tokensStartingWith!tk.text); 
					pragma(msg, charSetInfo.enumerate.map!(e => format!"  %2d %s"(e.index, e.value)).join('\n')); 
					pragma(msg, format!"  Default: %d"(DefaultResult), " ", DefaultResult>=0 ? tokens_[DefaultResult] : ""); 
				}
				
				//do the actual processing
				if(s.length)
				{
					const cIdx = charSet.countUntil(cast(ubyte)s[0]); //Opt: <- pcmpestri
					if(cIdx>=0)
					{
						 //Todo: slow
						//first check for simple indices
						auto tIdx = simpleIdx[cIdx]; 
						if(tIdx>=0)
						return tIdx; 
						
						//then call complex tokens. This is compile time recursion.
						sw: switch(cIdx)
						{
							static foreach(i, subTokens; complexSubTokens)
							static if(subTokens.length)
							{
								case i: {
									auto sIdx = startsWithToken!subTokens(s[1..$]); 
									if(sIdx>=0)
									return complexSubTokenIndices[i][sIdx]; 
								}
								break sw; 
							}
							
							default: 
						}
					}
				}
				return DefaultResult; 
			}
		} 
		
		size_t skipUntilTokens(string[] tokens)(string s)
		{
			//This is an optimization skip, it's not a problem if it not skipping because of alignemt requirements not met.
			static assert(tokens.all!"a.length"); 
			static immutable charSet = tokens.map!"ubyte(a[0])".array.sort.uniq.array; 
			
			static if(0)
			{
				//reference version
				return s.length - (cast(ubyte[])s).findAmong(charSet).length; 
			}else
			{
				enum sseLengthLimit = 16; //SSE vector size limit
				
				//generate charSetVector: It contains all the chars the tokens can start with.
				static assert(charSet.length <= sseLengthLimit); 
				static immutable ubyte16 charSetVector = mixin(charSet.padRight(0, sseLengthLimit).text); 
				
				auto remaining = s.length, p0 = s.ptr, p = p0; 
				while(remaining>=16)
				{
					//Note: this padding solves the unaligned read from a 4k page boundary at the end of the string. No masked reads needed.
					const tmp = __asm!size_t(
						//no 16byte align needed.
						"pcmpestri $5,$3,$1"
						//   0   1  2   3  4  5
						, "={RCX},x,{RAX},*p,{RDX},i,~{flags}", 
						charSetVector, charSet.length, p, remaining, 0
					); 
					p += tmp; 
					if(tmp<16)
					break;  //Opt: Carry Flag signals if nothing found
					remaining -= tmp; 
				}
				return p-p0; 
			}
		} 
		
		/// Find the first location index and the token index in the string. 
		/// Returns s.length if can't find anything.
		/// If the token is marked with tmPreserve, then it will not skip it. (slashComment for example)
		struct IndexOfTokenResult
		{
			//Opt: int instead of size_t
			sizediff_t	tokenIdx=-1; //0based
			size_t	tokenLen, tokenStartIdx; 
			
			bool valid() const
			{ return tokenIdx>=0; } 
			auto opCast(b : bool)() const
			{ return valid; } 
			auto tokenEndIdx() const
			{ return tokenStartIdx+tokenLen; } 
		} //Opt: int-tel kiprobalni size_t helyett.
		
		auto indexOfToken(string[] tokens)(string s, size_t startIdx)
		{
			assert(startIdx<=s.length); 
			
			static if(!tokens.equal([""]))
			{
				//special case: [""] means: take everything, seek to the end.
				static assert(tokens.all!"a.length"); 
				
				do
				{
					//FastSkip
					static if(1)
					{
						const skipCnt = skipUntilTokens!tokens(s[startIdx..$]); 
						//print("QQ", skipCnt); static int cnt; if(cnt++==20) readln;
						///skipCnt.HIST!(20)+/
						startIdx += skipCnt; 
					}
					
					//check the tokens at startIdx
					const tIdx = startsWithToken!tokens(s[startIdx..$]); 
					if(tIdx>=0)
					return IndexOfTokenResult(tIdx, tokens[tIdx].length, startIdx); 
				}while(startIdx++ < s.length); 
			}
			
			//return a physical eof: 	Seek to the very end of the string, tokenLength is 0
			//idx is the index of "\0" if that token is searched, othewise -1.
			enum NullTokenIdx = tokens.countUntil("\0"); 
			return IndexOfTokenResult(NullTokenIdx, 0, s.length); 
		} 
		
		//StructureScanner //////////////////////////////////////////////////
		
		enum ScanOp
		{
			push, pop, 	//enter exit structure levels 
			trans, 	//transition, stays on the same level, but structure state can be changed
			content, 	//unstructured contents inside the structure hierarchy
			error,	//generated by @Error("tokens")
			error_underflow, 	//stack was empty when a pop or trans occured
			error_stopped1,
			error_stopped2,
			error_unclosed,
		} 
		
		struct ScanResult
		{
			ScanOp op; 
			string src; 
			@property bool valid() const
			{ return op < ScanOp.error; } 
		} 
		
		enum isScannerRange(R) = isInputRange!R && is(ElementType!R==ScanResult); 
		
		mixin template prologue()
		{
			static: 
			struct Transition
			{
				string token; 
				State dstState; 
				enum Op : ubyte {trans, push, pop, ignore, error} 
				Op op; 
				@property bool isTrans() const { return op==Op.trans; } 
				@property bool isPush() const { return op==op.push; } 
				@property bool isPop() const { return op==Op.pop; } 
				@property bool isIgnore() const { return op==Op.ignore; } 
				@property bool isError() const { return op==Op.error; } 
				
				string toString() const
				{
					const ot = op.text.capitalize; 
					if(isTrans || isPush) return format!"%s(%s, %s)"(ot, token.quoted, dstState); 
					return format!"%s(%s)"(ot, token.quoted); 
				} 
			} 
			
			auto Trans(string s, State dst, Transition.Op op = Transition.Op.trans)
			{
				return s.predSwitch(
					""	, [Transition(""	, dst, op)],	 //s=="" means take ALL chars from src
					" "	, [Transition(" "	, dst, op)],	 //space character is special
					s.split(' ').map!(t => Transition(t, dst, op)).array
				); 
			} 
			
			auto Push(string s, State dst) { return Trans(s, dst, Transition.Op.push); } 
			auto Pop(string s) { return Trans(s, State.init, Transition.Op.pop); } 
			auto Ignore(string s) { return Trans(s, State.init, Transition.Op.ignore); } 
			auto Error(string s) { return Trans(s, State.init, Transition.Op.error); } 
			
			
		} 
		
		
		mixin template epilogue()
		{
			static: 
			import std.concurrency : Generator, yield; //Ali Cehreli Fiber presentation: https://youtu.be/NWIU5wn1F1I?t=1624
			
			auto scanner(string src)
			{ return new Generator!(StructureScanner.ScanResult)({ scan(src); }); } 
			
			auto scan(string src)
			{
				with(StructureScanner)
				{
					enum log = 0; 
					
					static if(__traits(compiles, initialState))	State[] stack = [initialState]; 
					else	State[] stack = [State.init]; 
					
					ref State state()	
					{ return stack.back; } 
					int stackLen()	
					{ return cast(int)stack.length; } 
					
					while(src.length)
					{
						
						swState: 
						final switch(state)
						{
							static foreach(caseState; EnumMembers!State)
							{
								case caseState: 
								{
									static immutable	transitions	 = StateTransitions[caseState],
										tokens	 = transitions.map!"a.token".array; 
									//pragma(msg, caseState, "\n", transitions.map!(a => a.format!"  %s").join("\n"));
									if(log)
									{
										print("------------------------------------"); 
										print("SRC:", EgaColor.yellow(src.quoted)); 
										print("State:", state, "Stack:", stack.retro); 
										print("Looking for:", transitions.map!"a.token"); 
									}
									
									//terminal node
									
									static if(transitions.length)
									{
										auto match = indexOfToken!tokens(src, 0); 
										
										//skip ignored tokens
										enum ignoreTokenIdx = transitions.countUntil!(t => t.isIgnore); 
										static if(ignoreTokenIdx>=0)
										{
											while(match && transitions[match.tokenIdx].isIgnore)
											match = indexOfToken!tokens(src, match.tokenEndIdx); 
										}
										
										if(log)
										print(match); 
										if(match)
										{
											//found something
											auto	contents 	= src[0..match.tokenStartIdx],
												tokenStr 	= src[match.tokenStartIdx..match.tokenEndIdx]; 
											//tokenStr: the actual token from the string. The last "" is detected as "\0"
											
											src = src[match.tokenEndIdx..$]; //advance
											with(transitions[match.tokenIdx])
											{
												assert(!isIgnore, "Ignored tokens must be already skipped before this point."); 
												
												if(contents.length)
												yield(ScanResult(ScanOp.content, contents)); 
												
												//update stack
												if(isPush)
												{
													stack ~= dstState; 
													yield(ScanResult(ScanOp.push, tokenStr)); 
												}else
												{
													//pop or trans. Both needs a non-empty stack.
													if(isError)
													{
														yield(ScanResult(ScanOp.error, tokenStr ~ src)); 
														return; 
													}
													if(stack.length)
													{
														if(isPop)
														{
															stack.popBack; 
															yield(ScanResult(ScanOp.pop, tokenStr)); 
														}else
														{
															//transition
															state = dstState; 
															yield(ScanResult(ScanOp.trans, tokenStr)); 
														}
													}else
													{
														yield(ScanResult(ScanOp.error_underflow, tokenStr ~ src)); 
														return; 
													}
												}
											}
										}
										else
										{
											yield(ScanResult(ScanOp.error_stopped1, src)); 
											return; 
											/+assert(0, format!"Scanner error: Find nothing in state %s, and \0 is not even handled."(caseState));+/
										}
										break swState; //break from case
									}
									else
									{
										yield(ScanResult(ScanOp.error_stopped2, src)); 
										return; 
										/+
											static assert(caseState.among(State.pop, State.ignore, State.eof), 
												format!"Scanner State graph error: %s should reach State.eof."(caseState));
										+/
									}
								}
							}
						}
					}
					
					//Handle valid EOF after a // slashComment for example.
					if(src.empty && stack.length>=2)
					sw: switch(stack.back)
					{
						static foreach(s; EnumMembers!State)
						static if(StateTransitions[s].any!(t => t.token=="\0" && t.isPop))
						{ case s: stack.popBack; yield(ScanResult(ScanOp.pop, "\0")); break sw; }
						default: 
					}
					
					if(
						stack.length>1//Todo: this is not a complete error check
					)
					yield(ScanResult(ScanOp.error_unclosed, "Unclosed structure: "~stack.text)); 
				}
			} 
		} 
		//testing ///////////////////////////////////
		
		void test_validity(alias Scanner)()
		{
			auto _間=init間; 
			string res; 
			foreach(f; Path(`c:\d\ldc2\import\std`	).files("*.d", true) /+~ Path(`c:\d\libs\het`	).files("*.d")+/)
			{
				auto src = f.readText; 
				auto scanner = Scanner(src); 	
				size_t size, hash; 
				scanner.each!((a){
					size += a.src.length; 
					hash = a.src.hashOf(hash); 
				}); 
				res ~= format!"%10d %016x %s\n"(size, hash, f.fullName); 
			}
			((0x1DC5DFDEAC48D).檢(0x1D64BFDEAC48D)); 
			print("hash =", res.hashOf); 
			enforceDiff(3757513907, res.hashOf, "StructureScanner functional test failed."); 
		} 
		
		void test_speed(alias Scanner)()
		{
			auto files	= Path(`c:\d\ldc2\import\std`	).files("*.d", true)
				~ Path(`c:\d\libs\het`	).files("*.d"); 
			
			Time[2] totalTime = 0*second;  size_t[2] totalBytes; 
			foreach(file; files)
			{
				const src = file.readText; 
				static foreach(i; 0..2)
				{
					{
						size_t actBytes; 
						T0; 
						static if(i==0)
						{ { auto sc = new SourceCode(src); actBytes = sc.tokens.map!"a.source.length".sum; }}
						static if(i==1)
						{ { actBytes = Scanner(src).map!"a.src.length".sum; }}
						totalTime[i] += DT; 
						totalBytes[i] += src.length; 
						static if(i==1)
						if(actBytes!=src.length)
						ERR("StructureScanner is FUCKED UP:", i, file, actBytes, src.length); 
					}
				}
			}
			string measurement(int i)
			{
				const bps = totalBytes[i]/totalTime[i].value(second); 
				return (bps/1024^^2).format!"%.1fMiB/s"; 
			} 
			print(
				"Benchmark: ", 
						" old:", measurement(0), 
						" new:", measurement(1), 
						" gain:", EgaColor.yellow((totalTime[0].value(second)/totalTime[1].value(second)).format!"%.2fx"), 
						" Data: ", totalBytes[0].shortSizeText!1024.format!"%siB", 
						" Time(new):", siFormat("%.3fs", totalTime[1])
			); 
		} 
		
		void test_visual(alias Scanner)()
		{
			T0; 
			auto src = File(`c:\d\libs\het\`~`com`~`.d`).readText;           	DT.print; 
			auto scanner = Scanner(src); 	DT.print; 
			scanner.walkLength; 	DT.print; 
			{ cast(void)(new SourceCode(src)); }	DT.print; 
			print(src.length); 
			
			
			scanner = Scanner(src); 
			
			if(1)
			scanner	.take(80)
					//.filter!(a => !a.src.isWild(`*:\*`)) //a file neveket nem mutatom
					.each!((a){
				with(StructureScanner.ScanOp)
				with(EgaColor)
				write(
					a.op.predSwitch(
						content	, ltWhite	(a.src),
						push	, ltBlue	(a.src),
						pop	, ltGreen	(a.src),
						trans	, ltCyan	(a.src)
							, gray	(a.src) 
					)
				); 
					
				
			}); 
			
			
			print("\n--------------------------DONE------------------------------"); 
		} 
		
		void test(alias Scanner)()
		{
			test_validity!Scanner; 
			test_speed!Scanner; 
			test_visual!Scanner; 
		} 
		
		string test_extractStateGraph(Scanner)(bool flip=false)
		{
			string[] members, transitions; 
			static foreach(st; EnumMembers!(Scanner.State))
			{
				members ~= st.text; 
				transitions ~= Scanner.StateTransitions[st].map!text.join("\t, "); 
			}
			
			if(!flip)
			return format!q{enum State {%s} }("\n"~members.join(",\n")~"\n") ~ "\v\n" ~
			format!q{enum stateTransitions = [%s]; }("\n"~transitions.join(",\n")~"\n") ~ "\n"; 
			else
			return (members.map!`"/+note:"~a~"+/"`.join("\t"))~"\n"~
			(
				mixin(求map(q{i=0},q{<transitions.map!"a.split('\t').length".maxElement},q{
					(
						mixin(求map(q{j=0},q{<members.length},q{
							auto s = transitions[j].split('\t').get(i).withoutStarting(',').strip; 
							if(s=="") s = " "; 
							return s; 
						}))
					).join('\t')
				}))
			).join('\n'); 
		} 
		
	} 
	alias ScanOp = StructureScanner.ScanOp; 
	alias ScanResult = StructureScanner.ScanResult; 
	alias isScannerRange(R) = StructureScanner.isScannerRange!R; 
	
	alias DLangScanner = StructureScanner_DLang.scanner; 
	struct StructureScanner_DLang
	{
		mixin((
			(表([
				[q{/+Note: Enter+/},q{/+Note: State+/},q{/+Note: Transitions+/},q{/+Note: Leave+/},q{/+Note: EOF handling+/}],
				[q{"{"},q{structuredBlock},q{Error("] )") ~ EntryTransitions},q{"}"},q{StructuredEOF}],
				[q{"("},q{structuredList},q{Error("] }") ~ EntryTransitions},q{")"},q{StructuredEOF}],
				[q{"["},q{structuredIndex},q{Error(") }") ~ EntryTransitions},q{"]"},q{StructuredEOF}],
				[q{"q{"},q{structuredString},q{Error("] )") ~ EntryTransitions},q{CWD(`}`)},q{StructuredEOF}],
				[],
				[q{"//"},q{slashComment},q{Pop(NewLineTokens)},q{},q{Pop(EOFTokens)}],
				[q{"/*"},q{cComment},q{},q{"*/"},q{EOF}],
				[q{"/+"},q{dComment},q{Push("/+", dComment)},q{"+/"},q{EOF}],
				[],
				[q{"'"},q{cChar},q{Ignore(`\\ \'`)},q{CWD(`'`)},q{EOF}],
				[q{`"`},q{cString},q{Ignore(`\\ \"`)},q{CWD(`"`)},q{EOF}],
				[q{`r"`},q{rString},q{},q{CWD(`"`)},q{EOF}],
				[q{"`"},q{dString},q{},q{CWD("`")},q{EOF}],
				[],
				[q{`q"/`},q{qStringSlash},q{},q{CWD(`/"`)},q{EOF}],
				[],
				[q{`q"{`},q{qStringCurly},q{Push("{", qStringCurlyInner)},q{CWD(`}"`)},q{EOF}],
				[q{},q{qStringCurlyInner},q{Push("{", qStringCurlyInner)},q{`}`},q{EOF}],
				[q{`q"(`},q{qStringRound},q{Push("(", qStringRoundInner)},q{CWD(`)"`)},q{EOF}],
				[q{},q{qStringRoundInner},q{Push("(", qStringRoundInner)},q{`)`},q{EOF}],
				[q{`q"[`},q{qStringSquare},q{Push("[", qStringSquareInner)},q{CWD(`]"`)},q{EOF}],
				[q{},q{qStringSquareInner},q{Push("[", qStringSquareInner)},q{`]`},q{EOF}],
				[q{`q"<`},q{qStringAngle},q{Push("<", qStringAngleInner)},q{CWD(`>"`)},q{EOF}],
				[q{},q{qStringAngleInner},q{Push("<", qStringAngleInner)},q{`>`},q{EOF}],
				[],
				[q{`q"`},q{qStringBegin},q{Trans(NewLineTokens, qStringMain) },q{},q{EOF}],
				[q{},q{qStringMain},q{/+Todo: quoted identifier str+/ },q{},q{EOF}],
				[],
				[q{`x"`},q{hexString},q{},q{CWD(`"`)},q{EOF}],
				[],
				[q{`i"`},q{interpolatedCString},q{Push("$(", interpolationBlock) ~ Ignore(`\\ \" \$`)},q{CWD(`"`)},q{EOF}],
				[q{"i`"},q{interpolatedDString},q{Push("$(", interpolationBlock)},q{CWD("`")},q{EOF}],
				[q{"iq{"},q{interpolatedStructuredString},q{Error("] )") ~ EntryTransitions},q{CWD(`}`)},q{StructuredEOF}],
				[q{"$("},q{interpolationBlock},q{Error("] }") ~ EntryTransitions},q{")"},q{StructuredEOF}],
				[],
				[q{},q{unstructured},q{Trans("", unstructured)},q{},q{}],
			]))
		).GEN!q{
			GEN_StructureScanner
			(
				q{
					enum NewLineTokens 	= "\r\n \r \n \u2028 \u2029",
					EOFTokens 	= "\0" /+"\x1A" not supported because pcmpstri limit.+/
					,EOF 	= Trans(EOFTokens, State.unstructured),
					StructuredEOF 	= Trans(EOFTokens /+~ " __EOF__"+/, State.unstructured)
						/+Todo: __EOF__ is only valid when it is a complete keyword.+/; 
					
					string CWD(string s)
					{
						//append all string literal character size specifiers to a token
						return s.split(" ").map!((a)=>([a~"c", a~"w", a~"d", a])).join.join(" "); 
					} 
				}
			)
			
			/+
				Enter	A single /+Code: string+/ literal or nothing.  The are used to generate 
					EntryTransitions. These tokens can start scopes from structural blocks.
				State	The /+Code: identifier+/ of the enum member.
				Transitions 	An expression of type /+Code: Transition[]+/
						Error(sym)	If symbol is found, the scanning stops and an error raised.
						Ignore(sym)	Step over these symbols, do nothing.
						Trans(sym, state)	If symbol found, it will transition to the new state.
						Push(sym, state)	If symbol found, enters a new nested scope.
						Pop(sym)	If symbol found, exists the current scope.
						sym	Can be a single symbol or multiple symbols 
						separated by space.
							If the symbol is an empty string, it means the 
							whole remaining text.
							Examples: /+Code: "+" "+= +"+/ //the order is important.
				Leave	An expression of a symbol string.  It's generates a Pop() transition.
				EOF handling 	An expression of type /+Code: Transition[]+/.
			+/
		}); 
	} 
	
	bool isValidDLang(string src)
	{ return DLangScanner(src).all!"a.valid"; } 
	
	bool isValidDLang_singleToken(string src)
	{
		auto r = DLangScanner(src); 
		if(!r.empty && r.front.valid)
		{ r.popFront; return r.empty; }
		return false; 
	} 
	
	bool isSingleDComment(string src)
	{
		return src.length>=4 && src.startsWith("/+") && src.endsWith("+/") 
		&& src.isValidDLang_singleToken/+Opt: Redundant DLang scanning.+/; 
	} 
	
	
	alias DDocScanner = StructureScanner_DDoc.scanner; 
	struct StructureScanner_DDoc
	{
		mixin((
			(表([
				[q{/+Note: Entry+/},q{/+Note: State+/},q{/+Note: Transitions+/},q{/+Note: Leave+/},q{/+Note: EOF handling+/}],
				[q{},q{line},q{EntryTransitions ~ Trans(NewLineTokens~" \0", line)},q{},q{}],
				[q{"$("},q{element},q{EntryTransitions},q{`)`},q{}],
				[q{"`"},q{inline},q{Pop(NewLineTokens~" \0")},q{"`"},q{}],
			]))
		) .GEN!q{GEN_StructureScanner(q{enum NewLineTokens 	= "\r\n \r \n \u2028 \u2029"; })}); 
	} 
	
	version(none /+Note: This is just an example. Use het.fromJSON()!+/)
	struct StructureScanner_JSON
	{
		mixin(
			(
				(表([
					[q{/+Note: Enter+/},q{/+Note: State+/},q{/+Note: Transitions+/},q{/+Note: Leave+/}],
					[q{"{"},q{object},q{Error("] )") ~ EntryTransitions ~ Trans(": ,", object)},q{"}"}],
					[q{"["},q{array},q{Error(") }") ~ EntryTransitions ~ Trans(",", array)},q{"]"}],
					[q{"'"},q{sqString},q{Ignore(`\\ \'`)},q{`'`}],
					[q{`"`},q{dqString},q{Ignore(`\\ \"`)},q{`"`}],
				]))
			).調!GEN_StructureScanner
		); 
	} 
	
}