module het.amdb; 

import het; 


version(/+$DIDE_REGION+/all) {
	struct SER
	{
		align(1) static: 
		
		version(/+$DIDE_REGION+/all)
		{
			version(/+$DIDE_REGION+/all)
			{
				struct Null {} 
				struct Bool(bool val) {} 
				struct FN/+field name+/ { char ch; } 
				struct Assoc(IT) { IT source, verb, target; } 
				struct EType(IT) { IT source, verb, target; } 
				struct AType(IT) { IT source, verb, target; } 
			}
			enum TypeMatrix = 
			(表([
				[q{/+Note:+/},q{/+Note: _0+/},q{/+Note: _1+/},q{/+Note: _2+/},q{/+Note: _3+/},q{/+Note: _4+/},q{/+Note: _5+/},q{/+Note: _6+/},q{/+Note: _7+/},q{/+Note: _8+/},q{/+Note: _9+/},q{/+Note: _A+/},q{/+Note: _B+/},q{/+Note: _C+/},q{/+Note: _D+/},q{/+Note: _E+/},q{/+Note: _F+/}],
				[q{/+Note: 0_+/},q{Null},q{},q{},q{},q{},q{},q{},q{},q{},q{},q{},q{},q{},q{},q{},q{}],
				[q{/+Note: 1_+/},q{},q{},q{},q{},q{},q{},q{},q{},q{},q{},q{},q{},q{},q{},q{},q{}],
				[q{/+Note: 2_+/},q{},q{},q{},q{},q{},q{},q{},q{},q{},q{},q{},q{},q{},q{},q{},q{}],
				[q{/+Note: 3_+/},q{},q{},q{},q{},q{},q{},q{},q{},q{},q{},q{},q{},q{},q{},q{},q{}],
				[q{/+Note: 4_+/},q{},q{},q{},q{},q{},q{},q{},q{},q{},q{},q{},q{},q{},q{},q{},q{}],
				[q{/+Note: 5_+/},q{},q{},q{},q{},q{},q{},q{},q{},q{},q{},q{},q{},q{},q{},q{},q{}],
				[q{/+Note: 6_+/},q{},q{},q{},q{},q{},q{},q{},q{},q{},q{},q{},q{},q{},q{},q{},q{}],
				[q{/+Note: 7_+/},q{},q{},q{},q{},q{},q{},q{},q{},q{},q{},q{},q{},q{},q{},q{},q{}],
				[q{/+Note: 8_+/},q{EType!ubyte},q{EType!ushort},q{EType!uint},q{EType!ulong},q{Assoc!ubyte},q{Assoc!ushort},q{Assoc!uint},q{Assoc!ulong},q{},q{},q{},q{},q{},q{RG},q{RGB},q{RGBA}],
				[q{/+Note: 9_+/},q{AType!ubyte},q{AType!ushort},q{AType!uint},q{AType!ulong},q{},q{},q{},q{},q{FN[ubyte]},q{FN[ushort]},q{FN[uint]},q{FN[ulong]},q{},q{ivec2},q{ivec3},q{ivec4}],
				[q{/+Note: A_+/},q{byte},q{short},q{int},q{long},q{float},q{double},q{Bool!false},q{Bool!true},q{char[ubyte]},q{char[ushort]},q{char[uint]},q{char[ulong]},q{},q{vec2},q{vec3},q{vec4}],
				[q{/+Note: B_+/},q{ubyte},q{ushort},q{uint},q{ulong},q{},q{},q{DateTime},q{Date},q{ubyte[ubyte]},q{ubyte[ushort]},q{ubyte[uint]},q{ubyte[ulong]},q{},q{dvec2},q{dvec3},q{dvec4}],
				[q{/+Note: C_+/},q{char[0]},q{char[1]},q{char[2]},q{char[3]},q{char[4]},q{char[5]},q{char[6]},q{char[7]},q{char[8]},q{char[9]},q{char[10]},q{char[11]},q{char[12]},q{char[13]},q{char[14]},q{char[15]}],
				[q{/+Note: D_+/},q{char[16]},q{char[17]},q{char[18]},q{char[19]},q{char[20]},q{char[21]},q{char[22]},q{char[23]},q{char[24]},q{char[25]},q{char[26]},q{char[27]},q{char[28]},q{char[29]},q{char[30]},q{char[31]}],
				[q{/+Note: E_+/},q{FN[0]},q{FN[1]},q{FN[2]},q{FN[3]},q{FN[4]},q{FN[5]},q{FN[6]},q{FN[7]},q{FN[8]},q{FN[9]},q{FN[10]},q{FN[11]},q{FN[12]},q{FN[13]},q{FN[14]},q{FN[15]}],
				[q{/+Note: F_+/},q{FN[16]},q{FN[17]},q{FN[18]},q{FN[19]},q{FN[20]},q{FN[21]},q{FN[22]},q{FN[23]},q{FN[24]},q{FN[25]},q{FN[26]},q{FN[27]},q{FN[28]},q{FN[29]},q{FN[30]},q{FN[31]}],
			])),
				/+⚠must synchronize manually! -> +/ TinyStringMaxLength = 31, TinyFieldNameMaxLength = 31, TinyBlobMaxLength = -1/+completely disabled+/,
			TypeDefs = TypeMatrix.rows.map!"a[1..$]".join.array; 
			mixin(iq{alias Types = AliasSeq!($(TypeDefs.map!"a==`` ? `void` : a".join(','))); }.text); static assert(Types.length==0x100); 
			template TypeCode(T) { enum code = staticIndexOf!(Unqual!T, Types); static assert(code>=0, "Can't find type in TypeMatrix: "~T.stringof); enum TypeCode = (cast(ubyte)(code)); } 
		}
		version(/+$DIDE_REGION Serialization+/all)
		{
			enum OptimizeSerialization = (常!(bool)(1)); 
			
			private static serializeTypedLen(R, CH)(R stream, size_t len)
			{
				void doit(ST)()
				{
					stream.put(TypeCode!(CH[ST])); 
					stream.put((cast(ubyte*)(&len))[0..ST.sizeof]); 
				} if(len<=ubyte.max)	{ doit!ubyte; }
				else if(len<=ushort.max)	{ doit!ushort; }
				else if(len<=uint.max)	{ doit!uint; }
				else	{ doit!ulong; }
			} 
			
			private static serializeBlob_impl(R, CH, int TinyMaxLen)(R stream, in immutable(CH)[] data)
			{
				const len = data.length; 
				if(
					TinyMaxLen>=0 &&
					len<=TinyMaxLen
				)	{ static if(TinyMaxLen>=0) stream.put((cast(ubyte)(TypeCode!(CH[0]) + len))); }
				else	{ serializeTypedLen!(R, CH)(stream, len); }
				stream.put(cast(ubyte[])(data)); 
			} 
			
			static serializeString(R)(R stream, in string data)
			{ serializeBlob_impl!(R, char, TinyStringMaxLength)(stream, data); } 
			private static serializeFieldName(R)(R stream, in string data)
			{ serializeBlob_impl!(R, FN, TinyFieldNameMaxLength)(stream, (cast(immutable(FN)[])(data))); } 
			private static serializeBlob(R)(R stream, in ubyte[] data)
			{ serializeBlob_impl!(R, ubyte, TinyBlobMaxLength)(stream, (cast(immutable)(data))); } 
			
			static serializeIntegral(R, T)(R stream, in T data)
			{
				static if(OptimizeSerialization)
				{
					alias TLarge = 
					AliasSeq!
					(
						ulong, 
						uint, 
						ushort, 
						long, 
						int, 
						short
					),
					TSmall = 
					AliasSeq!
					(
						uint, 
						ushort, 
						ubyte, 
						int, 
						short, 
						byte
					); static foreach(i; 0..TLarge.length)
					{
						static if(is(T==TLarge[i]))
						{
							if((cast(TSmall[i])(data))==data)
							{
								serializeIntegral(stream, (cast(TSmall[i])(data))); 
								return; 
							}
						}
					}
				}
				stream.put(TypeCode!T); stream.put((cast(ubyte*)(&data))[0..T.sizeof]); 
			} 
			
			static serializeFloating(R, T)(R stream, in T data)
			{
				static if(OptimizeSerialization)
				{ static if(is(T==double)) { if((cast(float)(data))==data) { serializeIntegral(stream, (cast(float)(data))); return; }}}
				stream.put(TypeCode!T); stream.put((cast(ubyte*)(&data))[0..T.sizeof]); 
			} 
			
			static serializeBool(R)(R stream, in bool data)
			{ stream.put(((data)?(TypeCode!(Bool!true)):(TypeCode!(Bool!false)))); } 
			
			static serializeDateTime(R, T)(R stream, in T data)
			{
				stream.put(TypeCode!T); 
				static if(is(T==DateTime)) { stream.put((cast(ubyte*)(&data.raw))[0..8]); }
				else static if(is(T==Date)) { stream.put((cast(ubyte*)(&data.raw))[0..3/+⚠ not 4!+/]); }
				else static assert(0, "Unhandled type: "~T.stringof); 
			} 
			static serializeVector(R, CT, int N)(R stream, in Vector!(CT, N) data)
			{
				alias VT = typeof(data); 
				stream.put(TypeCode!VT); stream.put((cast(ubyte*)(&data))[0..VT.sizeof]); 
			} 
			
			static serializeAssoc(R, T)(R stream, in T data)
			{
				alias AT = mixin(Unqual!T.stringof.split('!')[0]); 
				static if(is(T==AT!Idx, Idx))
				{
					static if(OptimizeSerialization)
					{
						static maxIndex(T)(in T a) => max(a.source, a.verb, a.target); 
						auto downgrade(Idx)()
						=> AT!Idx((cast(Idx)(data.source)), (cast(Idx)(data.verb)), (cast(Idx)(data.target))); 
						alias Types=AliasSeq!(uint, ushort, ubyte); 
						static foreach(i; 0..Types.length-1)
						static if(is(Idx==Types[i]))
						{
							if(maxIndex(data)<=Types[i+1].max)
							{
								const tmp = downgrade!(Types[i+1]); 
								serializeAssoc(stream, tmp); return; 
							}
						}
					}
					
					stream.put(TypeCode!T); 
					stream.put((cast(ubyte*)(&data))[0..T.sizeof]); 
				}
				else static assert(0, "Unhandled type: "~T.stringof); 
			} 
			
			static serialize(R, T)(R stream, in T data)
			if(isOutputRange!(R, ubyte))
			{
				static if(is(T==Null))	{ stream.put(TypeCode!Null); }
				else static if(is(T==string))	{ serializeString(stream, data); }
				else static if(isSomeString!T)	{ serializeString(stream, data.text); }
				else static if(is(T==ubyte[]))	{ serializeBlob(stream, data); }
				else static if(isIntegral!T)	{ serializeIntegral(stream, data); }
				else static if(isFloatingPoint!T)	{ serializeFloating(stream, data); }
				else static if(is(T==bool))	{ serializeBool(stream, data); }
				else static if(
					is(T==DateTime)||
					is(T==Date)
				)	{ serializeDateTime(stream, data); }
				else static if(isVector!T)	{ serializeVector(stream, data); }
				else static if(
					is(T==Assoc!X, X)||
					is(T==EType!X, X)||
					is(T==AType!X, X)
				)	{ serializeAssoc(stream, data); }
				else static assert(0, "Unhandled type: "~T.stringof); 
			} 
		}
		version(/+$DIDE_REGION Deserialization+/all)
		{
			static T deserialize(T)(ubyte[] stream)
			{} 
		}
	} 
	
	static struct AMToken
	{
		enum Type { unknown, ppp, newLine, tabs, words, verb, str, expr} 
		Type type; string src; 
	} 
	
	static void parseAMSentences(in string sourceText, void delegate(AMToken[]) onSentence, string sourceFile="noname")
	{
		version(/+$DIDE_REGION Input+/all)
		{
			import het.parser : DLangScanner, ScanOp; 
			auto scanner = DLangScanner(sourceText); 
			size_t tokenPos; 
		}version(/+$DIDE_REGION Output+/all)
		{
			alias Type = AMToken.Type; 
			auto lastType = Type.unknown; 
			auto sentence = appender!(AMToken[]); 
		}
		try
		{
			void appendToken(Type type, string str="")
			{
				void append() { sentence ~= AMToken(type, str); } 
				
				if(type==Type.newLine)
				{
					if(!sentence.empty)
					onSentence(sentence[]); sentence.clear; 
				}
				else if(type==Type.ppp)
				{
					auto s = sentence[]; 
					if(s.length==1 && s[0].type==Type.tabs)
					{
						/+... at the start of a line+/
						append; 
					}
					else
					{
						/+... at the end of a sentence on the same line+/
						enforce(!s.empty, "Invalid usage of `...`."); 
						onSentence(s); 
						sentence.clear; append; 
					}
				}
				else
				{ append; }
				
				lastType = type; 
			} 
			
			void parseBlock(Type type, size_t openingTokenSize)
			{
				int level=1; tokenPos += openingTokenSize; 
				while(!scanner.empty)
				{
					const token = scanner.front; scanner.popFront; tokenPos += token.src.length; 
					enforce(token.valid, "Invalid syntax: "~token.text); 
					if(token.op==ScanOp.push)	level++; 
					else if(token.op==ScanOp.pop)	if(!--level) break; 
				}
			} 
			
			void appendBlock(Type type, size_t openingTokenSize)
			{
				const st = tokenPos; 
				parseBlock(type, openingTokenSize); 
				const en = tokenPos; 
				
				if(type!=Type.unknown)
				appendToken(type, sourceText[st..en]); 
			} 
			
			void appendWords(string s)
			{
				/+It splits newLines and `...`s. Detects tabs right after newLines.+/
				const basePos = tokenPos; size_t pos; int pointCnt; 
				
				void add(string s)
				{
					if(s.length && s.all!"a=='\t'")
					{
						if(lastType==Type.newLine)
						appendToken(Type.tabs, s); 
					}
					else
					{
						s = s.strip; 
						if(s.length) appendToken(Type.words, s); 
					}
				} 
				
				void addMarker(Type type)
				{
					if(mixin(等(q{type},q{Type.newLine},q{lastType}))) return; 
					appendToken(type); 
				} 
				
				foreach(i; 0..s.length)
				{
					const ch = s[i]; 
					
					if(ch=='\n')
					{
						tokenPos = basePos + pos; 
						add(s[pos..i].withoutEnding('\r')); 
						addMarker(Type.newLine); pos = i+1; 
					}
					
					if(ch=='.')
					{
						pointCnt++; 
						if(pointCnt==3)
						{
							tokenPos = basePos + pos; 
							add(s[pos..i-2]); 
							addMarker(Type.ppp); pos = i+1; 
						}
					}
					else pointCnt = 0; 
				}
				
				tokenPos = basePos + pos; 
				add(s[pos..$]); 
			} 
			
			while(!scanner.empty)
			{
				auto token = scanner.front; scanner.popFront; 
				const st = tokenPos, en = st + token.src.length; void advance() { tokenPos = en; } 
				
				switch(token.op)
				{
					case ScanOp.content, ScanOp.trans: 
						appendWords(sourceText[st..en]); advance; 
					break; 
					
					case ScanOp.push: 
						const tlen = token.src.length; 
						switch(token.src)
					{
						case "(": 	appendBlock(Type.expr, tlen); 	break; 
						case "[": 	appendBlock(Type.verb, tlen); 	break; 
						case `"`, "`"/+Todo: `r"`+/: 	appendBlock(Type.str, tlen); 	break; 
						case "//", "/*", "/+": 	appendBlock(Type.unknown, tlen); 	break; 
						default: 	enforce(0, "Invalid block: "~token.text); 
					}
					break; 
					
					default: enforce(0, "Invalid syntax: "~token.text); 
				}
			}
			
			//flush last line
			if(lastType && lastType!=Type.newLine)
			appendToken(Type.newLine); 
		}
		catch(Exception e) {
			const lineIdx = sourceText.byChar.take(tokenPos).count('\n') + 1; 
			throw e; 
			throw new Exception(i"AMDB Error: $(sourceFile)($(lineIdx)): $(e.simpleMsg) $(sentence[])".text); 
		}
	} 
	void processAMSentences(in string src, in string[] sysVerbs, void delegate(in AMToken, in AMToken, in AMToken) processAssociation)
	{
		alias TT = AMToken.Type; 
		
		static splitSingleSpace(int N)(string s)
		if(N.among(2, 3))
		{
			const st0 = s.indexOf(" "); 
			if(st0>0)
			{
				auto en0 = st0 + 1; 
				if(en0 < s.length)
				{
					const st1 = s.indexOf(" ", en0); 
					static if(N==2)
					{
						if(st1<0) {
							string[N] res = [s[0..st0], s[en0..$]]; 
							if(res[0].length && res[1].length)
							return nullable(res); 
						}
					}
					else static if(N==3)
					{
						auto en1 = st1 + 1; 
						if(en1 < s.length)
						{
							const st2 = s.indexOf(" ", en1); 
							if(st2<0) {
								string[N] res = [s[0..st0], s[en0..st1], s[en1..$]]; 
								if(res[0].length && res[1].length && res[2].length)
								return nullable(res); 
							}
						}
					}
				}
			}
			return (Nullable!(string[N])).init; 
		} 
		
		static splitDoubleSpace(int N)(string s)
		if(N.among(2, 3))
		{
			const st0 = s.indexOf("  "); 
			if(st0>0)
			{
				auto en0 = st0 + 2; while(s.get(en0)==' ') en0++; 
				if(en0 < s.length)
				{
					const st1 = s.indexOf("  ", en0); 
					static if(N==2)
					{
						if(st1<0) {
							string[N] res = [s[0..st0], s[en0..$]]; 
							if(res[0].length && res[1].length)
							return nullable(res); 
						}
					}
					else static if(N==3)
					{
						auto en1 = st1 + 2; while(s.get(en1)==' ') en1++; 
						if(en1 < s.length)
						{
							const st2 = s.indexOf("  ", en1); 
							if(st2<0) {
								string[N] res = [s[0..st0], s[en0..st1], s[en1..$]]; 
								if(res[0].length && res[1].length && res[2].length)
								return nullable(res); 
							}
						}
					}
				}
			}
			return (Nullable!(string[N])).init; 
		} 
		
		string[2] split_SourceVerb(string words)
		{
			foreach(const verb; sysVerbs)
			{
				if(words.endsWith(verb) && words.get(words.length-verb.length-1)==' ')
				return [words[0 .. $-verb.length-1].stripRight, verb]; 
			}
			
			{ auto parts = splitDoubleSpace!2(words); if(parts) return parts.get; }
			{ auto parts = splitSingleSpace!2(words); if(parts) return parts.get; }
			
			enforce(0, "Cannot split source, verb: "~words.quoted); assert(0); 
		} 
		
		string[2] split_VerbTarget(string words)
		{
			foreach(const verb; sysVerbs)
			{
				if(words.startsWith(verb) && words.get(verb.length)==' ')
				return [verb, words[verb.length+1 .. $].stripLeft]; 
			}
			
			{ auto parts = splitDoubleSpace!2(words); if(parts) return parts.get; }
			{ auto parts = splitSingleSpace!2(words); if(parts) return parts.get; }
			
			enforce(0, "Cannot split verb, target: "~words.quoted); assert(0); 
		} 
		
		string[3] split_SourceVerbTarget(string words)
		{
			foreach(const verb; sysVerbs)
			{
				const idx = words.indexOf(verb); 
				if(idx>=0 && words.get(idx-1)==' ' && words.get(idx+verb.length)==' ')
				return [words[0..idx-1].stripRight, verb, words[idx+verb.length+1 .. $].stripLeft]; 
			}
			
			{ auto a = splitDoubleSpace!3(words); if(a) return a.get; }
			{ auto a = splitSingleSpace!3(words); if(a) return a.get; }
			
			enforce(0, "Cannot split source, verb, target: "~words.quoted); assert(0); 
		} 
		void processFullSentenceTokens(AMToken[] tokens)
		{
			enforce(tokens.length, "Empty sentence."); 
			
			switch(tokens.length)
			{
				case 3: // Direct mapping - easiest case!
				
				return processAssociation(tokens[0], tokens[1], tokens[2]); 
				
				case 2: // Need to split one token
				if(tokens[0].type == TT.words)
				{
					// Split T1 into source + verb, T2 is target
					const parts = split_SourceVerb(tokens[0].src); 
					return processAssociation(AMToken(TT.words, parts[0]), AMToken(TT.verb, parts[1]), tokens[1]); 
				}
				else if(tokens[1].type == TT.words)
				{
					// T1 is source, split T2 into verb + target
					const parts = split_VerbTarget(tokens[1].src); 
					return processAssociation(tokens[0], AMToken(TT.verb, parts[0]), AMToken(TT.words, parts[1])); 
				}
				enforce(0, i"Cannot parse 2-token sentence.".text); 
				break; 
				
				case 1: 
				// Single token - must be words, need NLP split
				enforce(tokens[0].type==TT.words, i"Single token must be Type.words".text); 
				const parts = split_SourceVerbTarget(tokens[0].src); 
				return processAssociation(AMToken(TT.words, parts[0]), AMToken(TT.verb, parts[1]), AMToken(TT.words, parts[2])); 
				
				default: enforce(0, "Invalid number of tokens"); 
			}
		} 
		
		void processLinkedSentenceTokens(AMToken level, AMToken[] tokens)
		{
			enforce(tokens.length, "Empty linked sentence."); 
			
			switch(tokens.length)
			{
				case 2: 
				if(tokens[0].type == TT.verb)
				{ return processAssociation(level, tokens[0], tokens[1]); }
				if(tokens[0].type == TT.words)
				{ return processAssociation(level, AMToken(TT.verb, tokens[0].src), tokens[1]); }
				enforce(0, i"Cannot parse 2 token linked sentence.".text); 
				break; 
				
				case 1: 
				// Single token - must be words, need NLP split
				enforce(tokens[0].type==TT.words, i"Single token must be Type.words".text); 
				const parts = split_VerbTarget(tokens[0].src); 
				return processAssociation(level, AMToken(TT.verb, parts[0]), AMToken(TT.words, parts[1])); 
				
				default: enforce(0, "Invalid number of tokens"); 
			}
		} 
		
		void processSentenceTokens(AMToken[] sentence)
		{
			enforce(!sentence.empty, "Empty sentence."); 
			if(sentence[0].type==TT.tabs)
			{
				enforce(
					sentence.length>=2 && 
					sentence[1].type==TT.ppp, "`...` expected after TABs."
				); 
				processLinkedSentenceTokens(sentence[0], sentence[2..$]); 
			}
			else if(sentence[0].type==TT.ppp)
			{ processLinkedSentenceTokens(sentence[0], sentence[1..$]); }
			else
			{ processFullSentenceTokens(sentence); }
		} 
		
		return .parseAMSentences(src, &processSentenceTokens); 
		
		
	} 
	void testSER()
	{
		with(SER)
		{
			auto 試(A...)(A args) { auto arr = appender!(ubyte[]); serialize(arr, args); return arr[].hexDump; } 
			((0x49FAEB4AA1C7).檢 (試("a"w))),((0x4A1DEB4AA1C7).檢 (試("abcá"))),((0x4A43EB4AA1C7).檢 (試("Hello 🌍!\0"w.replicate(2)))),
			((0x4A84EB4AA1C7).檢 (試(false))),((0x4AA8EB4AA1C7).檢 (試(true))),((0x4ACBEB4AA1C7).檢 (試(Null()))),
			((0x4AF5EB4AA1C7).檢 (試(42))),((0x4B16EB4AA1C7).檢 (試(7848))),((0x4B39EB4AA1C7).檢 (試(437928932))),((0x4B61EB4AA1C7).檢 (試(437928932437928932))),
			((0x4B97EB4AA1C7).檢 (試(-42))),((0x4BB9EB4AA1C7).檢 (試(-7848))),((0x4BDDEB4AA1C7).檢 (試(-437928932))),((0x4C06EB4AA1C7).檢 (試(-437928932437928932))),
			((0x4C3DEB4AA1C7).檢 (試(1.5))),((0x4C5FEB4AA1C7).檢 (試(1.51))),((0x4C82EB4AA1C7).檢 (試(1.51f))),
			((0x4CABEB4AA1C7).檢 (試(now))),((0x4CCDEB4AA1C7).檢 (試(now.date))),
			((0x4CF9EB4AA1C7).檢 (試(vec2(1, 2)))),((0x4D22EB4AA1C7).檢 (試((RGB(54,60,175))))),((0x4D51EB4AA1C7).檢 (試(ivec4(1, 2, 3, 4)))),((0x4D81EB4AA1C7).檢 (試(dvec2((sqrt(π)), ((π)^^(2)))))),
			((0x4DC3EB4AA1C7).檢 (試(AType!ubyte(1, 2, 3)))),((0x4DF6EB4AA1C7).檢 (試(Assoc!ushort(4, 256, 6)))),((0x4E2CEB4AA1C7).檢 (試(EType!uint(7, 8, 65536)))),
			((0x4E67EB4AA1C7).檢 (試(Assoc!ubyte(1, 2, 3)))),((0x4E9AEB4AA1C7).檢 (試(EType!ushort(4, 5, 6)))),((0x4ECEEB4AA1C7).檢 (試(AType!uint(7, 8, 9)))); 
		}
	} 
	
	void testSentenceProcessor()
	{
		class AMDBTest
		{
			alias Idx = uint; 
			static struct Link { Idx idx; } 
			
			static struct LinkedLevel { uint level; } 
			
			enum Mode {schema, data} Mode mode /+state used by processAssociation()+/; 
			string dump; 
			
			void processAssociation(in AMToken source_, in AMToken verb_, in AMToken target_)
			{
				alias TT = AMToken.Type; 
				
				static string evalToken(in AMToken token)
				{
					switch(token.type)
					{
						case 	TT.words, 
							TT.str, TT.expr: 	return token.src; 
						case TT.ppp: 	return "!..."; 
						case TT.tabs: 	return "  ".replicate(token.src.length)~"..."; 
						default:  enforce(0, i"Failed to evaluate token: $(token)".text); assert(0); 
					}
				} 
				static string getVerb(in AMToken token)
				{
					switch(token.type)
					{
						case TT.verb, TT.words: 	return token.src; 
						default:  enforce(0, i"Failed to get verb from token: $(token)".text); assert(0); 
					}
				} 
				
				string 	source 	= evalToken	(source_),
					verb 	= getVerb	(verb_),
					target 	= evalToken	(target_); 
				
				static if(is(S==LinkedLevel))
				{
					const 	level = source_.level,
						hdr = ((level==0)?(" ... "):("\n"~"\t".replicate(level) ~ "... ")); 
					dump ~= i"$(hdr) $(verb)  $(target)".text; 
				}
				else
				{
					if(dump.length && !dump.endsWith('\n')) dump~='\n'; 
					dump ~= i"$(source)  $(verb)  $(target)".text; 
				}
			} 
			
			static immutable 
				schemaSysVerbs 	= ["is a subtype of", "subtype of", "is an", "is a"],
				dataSysVerbs 	= ["is an", "is a"]
				/+
				⚠Order is important!
				if there are multiple verbs with the same prefix, 
				the longer verb must be at an earlier location!
			+/; 
			
			
			void schema(string src)
			{ mode = Mode.schema; processAMSentences(src, schemaSysVerbs, &processAssociation); } 
			
			void data(string src)
			{ mode = Mode.data; processAMSentences(src, dataSysVerbs, &processAssociation); } 
			
			
			
		} 
		
		const schemaSrc =
		`Legal entity is an Entity
龍 is an Entity
"Book" is an Entity
Person is an "Entity"
"Points" is an "Integer"
Country [is a] String
Price [is a] "Float"

Legal entity [sells] Book1
"Legal entity" sells "Book2"
"Legal entity" [sells] Book3
Legal entity [sells] "Book4"
Legal entity  sells  Book5
"Legal entity" sells  Book6
Legal entity  sells "Book7"

Legal entity   sells  Book ...has property  Short code
//...illegal to have zero TABS on a new line.
	... worth  Points
		... in  Country
		... from  Date
			... at  Price

Person  lives in  Country
Person  customer of  Legal entity ... has earned  Points
	... orders  Book
		... on  Date
			...  at Price`,
		dataSrc = 
		`Amazon is a Legal entity
Bookpages is a Legal entity
Britain is a Country
America is a Country
Dr No is a Book
Michael Peters is a Person
Michael Peters  lives in  Britain
Mary Davis is a Person
Mary Davis  lives in  America
Spycatcher is a Book

Amazon  sells  Dr No
	... worth  75 points
	... in Britain
		... from 1-Jan-98
			... at £10
	... in America
		... from 1-Mar-98
			... at $16
Amazon sells Spycatcher
	... worth  50 points
	... in Britain
		... from 1-Jun-98
			... at £7
	... in America
		... from 1-Jun-98
			... at $12
Bookpages  sells  Dr No
	... worth  75 points
	... in Britain
		... from 1-Jan-98
			... at £8
	... in America
		... from 1-Jan-98
			... at $14
Bookpages sells Spycatcher
	... worth  35 points
	... in America
		... from 1-Jun-98
			... at $13

Michael Peters  customer of  Bookpages
	... has earned  1,200 points
		... orders "Dr No"
			... on 10-Oct-98
				... at £10 
Mary Davis  customer of  Amazon
	... has earned  750 points
		... orders Spycatcher
			... on 19-Oct-98
				... at $12`; {
			auto am = new AMDBTest; 
			am.schema(schemaSrc); 
			am.data(dataSrc); 
			((0x5E85EB4AA1C7).檢 (am.dump)); 
		}
	} 
}
version(/+$DIDE_REGION+/all) {
	private static sortKeywords(R)(R r) => r.sort!((a,b)=>(a.length>b.length ? true : a.length<b.length ? false : a>b))/+longer comes first, the alphabetical order.+/; 
	class AMDB
	{
		alias This = typeof(this), Idx = uint, TT = AMToken.Type; 
		
		SchemaManager schema; //Opt: All managers must be a locally accessible struct. (one less indirection)
		DataManager data; 
		
		this()
		{
			//create nested management classes
			schema 	= new SchemaManager,
			data 	= new DataManager; 
			
			stream.reset; 
		} 
		
		struct Association
		{
			Idx source, verb, target; 
			
			bool isNull() const => !source; 
			bool opCast(B : bool)() const => !isNull; 
			
			
			/+
				alias This = typeof(this); 
				int opCmp!(string order="SVT")(in This other) const
				{
					static assert(
						order.byDchar.array.sort.text=="STV", 
						"Invalid sort order spec."
					); 
					static foreach(c; order)
					{
						static if(c=='S') {
							if(source<other.source) return -1; 
							if(source>other.source) return 1; 
						}
						static if(c=='V') {
							if(verb<other.verb) return -1; 
							if(verb>other.verb) return 1; 
						}
						static if(c=='T') {
							if(target<other.target) return -1; 
							if(target>other.target) return 1; 
						}
					}
					return 0; 
				} 
			+/
		} 
		
		static evalStr(in AMToken token)
		{
			alias TT = AMToken.Type; 
			switch(token.type)
			{
				case TT.words: 	return token.src; 
				case TT.str: 	return token.src.withoutStartingEnding(token.src[0])
				/+Todo: proper string handling with escapes+/; 
				case TT.expr: 	return token.src.withoutStartingEnding('(', ')')
				/+Todo: proper expression handling+/; 
				case TT.verb: 	return token.src.withoutStartingEnding('[', ']'); 
				case TT.ppp: 	return "..."; 
				case TT.tabs: 	return "\t".replicate(token.src.length)~"..."; 
				default: enforce(0, i"Failed to evaluate token: $(token)".text); 
				assert(0); 
			}
		} 
		
		
		protected
		{
			version(/+$DIDE_REGION SysVerbs+/all)
			{
				public
				{
					mixin((
						(表([
							[q{/+Note: SysVerb : ubyte+/},q{/+Note: _S+/},q{/+Note: _D+/},q{/+Note: fullName+/},q{/+Note: synonyms+/}],
							[q{unknown},q{(常!(bool)(0))},q{(常!(bool)(0))},q{""},q{[]}],
							[q{subtype_of},q{(常!(bool)(1))},q{(常!(bool)(0))},q{"is a subtype of"},q{["subtype of", "is a", "is an"]}],
							[q{inverse_verb},q{(常!(bool)(1))},q{(常!(bool)(0))},q{"inverse verb"},q{[]}],
							[q{instance_of},q{(常!(bool)(0))},q{(常!(bool)(1))},q{"is an instance of"},q{["instance of", "is a", "is an"]}],
							[q{/+
								Regardless of processing schema or data, all SysVerbs must be the same!
								Because `mode` must not select different sets of verbs, the sentence
								splitting operation must be deterministic.
							+/}],
						]))
					).調!(GEN_enumTable)); 
				} 
				
				static string GEN_verbDict(alias mode)()
				=> iq{
					static immutable dict =
						[
						$(
							[EnumMembers!SysVerb]
							.drop(1/+skip `unknown`+/).filter!((verb)=>(mode[verb]))
								.map!((verb)=>(
								chain(
									sysVerbFullName[verb].only,
									sysVerbSynonyms[verb]
								)
									.map!((syn)=>(syn.quoted~':'~verb.text)).array
							))
							.joiner.join(',')
						)
					]; 
				}.text; 
				
				static immutable allSysVerbNames = 
					sysVerbFullName.drop(1/+skip `unknown`+/)
					.chain(sysVerbSynonyms.join)
					.array.sortKeywords/+⚠Order is important!+/
					.uniq.array; 
				
				static SysVerb lookupSysVerb(alias mode)(string s)
				{
					with(SysVerb)
					{ mixin(GEN_verbDict!mode); auto a = s in dict; return a ? *a : unknown; }
				} 
				
				alias schemaSysVerb 	= lookupSysVerb!sysVerb_S,
				dataSysVerb	= lookupSysVerb!sysVerb_D; 
			}
			
			
			
			version(/+$DIDE_REGION SysTypes+/all)
			{
				enum SysType {
					Entity, //must be the first, handled differently
					
					/+
						All DType names are the same as in DLang, 
						just with capital starting letter.
					+/
					String, Int, Bool, Float, Double, 
					Decimal, Money,
					DateTime, Date, Time,
					Blob, Bitmap, Audio, Video
				} 
				
				static immutable 	sysTypeNames = EnumMemberNames!SysType,
					sysTypeNameMap = EnumAssocArray!SysType; 
			}
			
			version(/+$DIDE_REGION Comparison+/all)
			{
				bool assocLessThan_SVT(Idx a, Idx b)
				{
					const 	assocA = explore(a).assoc,
						assocB = explore(b).assoc; 
					
					if(assocA.source != assocB.source)
					return assocA.source < assocB.source; 
					if(assocA.verb != assocB.verb)
					return assocA.verb < assocB.verb; 
					return assocA.target < assocB.target; 
				} 
				bool assocLessThan_TVS(Idx a, Idx b)
				{
					auto 	assocA = explore(a).assoc,
						assocB = explore(b).assoc; 
					
					if(assocA.target != assocB.target)
					return assocA.target < assocB.target; 
					if(assocA.verb != assocB.verb)
					return assocA.verb < assocB.verb; 
					return assocA.source < assocB.source; 
				} 
			}
			
			///Extracts a name form anything. It can be a string or an AMToken.
			static string asName(T)(in T a)
			{
				static if(is(T==AMToken)) return evalStr(a); 
				else return a.text; 
			} 
			
			Stream stream; 
			struct Stream
			{
				Appender!(ubyte[]) stream; 
				
				void reset()
				{
					stream = appender!(ubyte[]); //release the previous array
					stream ~= ubyte(0); //The first byte is the Null value
				} 
				
				Idx append(T)(in T data)
				{
					const res = stream[].length.to!Idx; 
					SER.serialize(stream, data); 
					return res; 
				} 
				
				Idx append(in Idx source, in Idx verb, in Idx target)
				=> append(SER.Assoc!Idx(source, verb, target)); 
				
				string hexDump() const => stream[].hexDump; 
			} 
			
			public string streamDump() => stream.hexDump; 
			public ubyte[] streamBytes() => stream.stream[]; 
			
			Indices indices; 
			struct Indices
			{
				import het.db : SortedAssocArray; 
				SortedAssocArray!(string, Idx) strings; 
				
				//SortedAssocArray!(Assoc!(Idx, "SVT"), Idx) svtIndex; 
				
				Idx[SysType.max+1] sysTypes; 
				Idx entityIdx; 
				
				Idx[SysVerb.max+1] sysVerbs; 
				
				
				Idx[string] 	TypeIdx_by_name,
						ETypeIdx_by_name,
						DTypeIdxByName; string[Idx] 	TypeName_by_idx,
						ETypeName_by_idx,
						DTypeName_by_dx; 
				/+
					EType: Entity,  DType: Data,  Type: EType ∪ DType
					AType: Attribute type, not included in Type
				+/
				/+
					NameByIdx -> This can be done by an explore() operation, 
					but the hashtable can also tell that the idx is valid or not.
				+/
				
				Idx[Idx[2]] ATypeIdx_by_sourceVerbIdx; Idx[2][Idx] ATypeSourceVerbIdx_by_idx; 
				bool[Idx] ATypeIsCompositeKey; 
				Idx[Idx] inverseVerbIdx_by_ATypeIdx, ATypeIdx_by_inverseVerbIdx; 
				Idx[][Idx] inverseVerbs_by_EType; 
				
				private void addMaps(alias MKV, alias MVK, K, V)(K key, V value)
				{
					assert(key !in MKV); 	MKV[key] = value; 
					assert(value !in MVK); 	MVK[value] = key; 
				} 
				
				void addEType(string name, Idx idx)
				{
					addMaps!(
						ETypeIdx_by_name, 
						ETypeName_by_idx
					)(
						name, 
						idx
					); addMaps!(
						TypeIdx_by_name, 
						TypeName_by_idx
					)(
						name, 
						idx
					); 
				} 
				
				void addDType(string name, Idx idx)
				{
					addMaps!(
						DTypeIdxByName, 
						DTypeName_by_dx
					)(
						name, 
						idx
					); addMaps!(
						TypeIdx_by_name, 
						TypeName_by_idx
					)(
						name, 
						idx
					); 
				} 
				
				void addAType(Idx[2] sourceVerbIdx, Idx idx)
				{
					addMaps!(
						ATypeIdx_by_sourceVerbIdx,
						ATypeSourceVerbIdx_by_idx
					)(
						sourceVerbIdx,
						idx
					); 
				} 
				
				Idx[] 	associations_by_SVT_impl, 
					associations_by_TVS_impl; 
				
				uint[Idx] entityCount_by_ETypeIdx;  //Todo: make counters for total EType population with inheritance
			} 
			
			version(/+$DIDE_REGION is* functions+/all)
			{
				private struct _IS_FUNCTIONS; 
				@_IS_FUNCTIONS
				{
					version(/+$DIDE_REGION+/all) {
						bool isType(Idx idx)
						=> !!(idx in indices.TypeName_by_idx); 
						bool isEType(Idx idx)
						=> !!(idx in indices.ETypeName_by_idx); 
						bool isDType(Idx idx)
						=> !!(idx in indices.DTypeName_by_dx); 
						bool isAType(Idx idx)
						=> !!(idx in indices.ATypeSourceVerbIdx_by_idx); 
						bool isInverseVerb(Idx idx)
						=> !!(idx in indices.ATypeIdx_by_inverseVerbIdx); 
						
						bool isATypeCompositeKey(Idx idx)
						=> !!(idx in indices.ATypeIsCompositeKey); 
					}
					
					bool isEntity(Idx idx)
					{ if(const verbIdx = get(mixin(舉!((SysVerb),q{instance_of})))) return explore(idx).verb.idx==verbIdx; return 0; } 
					
					bool isAttribute(Idx idx)
					=> !!(explore(idx).verb.idx in indices.ATypeSourceVerbIdx_by_idx); 
					
					bool hasInverseVerbs(Idx idx/+idx must be an EType+/) 
					=> !!(idx in indices.inverseVerbs_by_EType); 
				} 
			}
		} 
		version(/+$DIDE_REGION+/all) {
			Idx get(string data)
			{
				if(auto a = data in indices.strings)	return *a; 
				else	return 0; 
			} 
			
			Idx access(string data)
			{
				if(auto a = data in indices.strings) return *a; 
				const idx = stream.append(data); 
				indices.strings[data] = idx; return idx; 
				
				/+
					
					
					Link createThing(T)(T val)
					{
						Thing thing; 
						const idx = things.length.to!Idx; 
						
						void appendSimple()
						{ things ~= thing; } 
						
						static if(is(T : long))
						{ thing.type = Thing.Type.Long; thing.data_long = val; appendSimple; }
						else static if(is(T : double))
						{ thing.type = Thing.Type.Double; thing.data_double = val;  appendSimple; }
						else static if(is(T : string))
						{
							thing.type = Thing.Type.String; 
							if(val.length <= thing.data_ubytes.length-1)
							{
								thing.data_ubytes[0] = (cast(ubyte)(val.length)); 
								thing.data_ubytes[1..1+(cast(ubyte)(val.length))] = cast(ubyte[])(val); 
								appendSimple; 
							}
							else
							{
								thing.data_ubytes[0] = 0x8; 
								/+ *(cast(uint*)(&thing.data_ubytes[1])) = cast(uint) +/
							}
						}
						else static if(isSomeString!T) { thing = createThing(val.text); }
						else static assert(0, "Unhandled type: "~T.stringof); 
						
						return idx; 
					} 
				+/
			} 
			
			Idx access(SysVerb verb)
			{
				enforce(verb, "Cannot access null sysVerb"); 
				
				ref idx = indices.sysVerbs[verb]; 
				if(!idx)
				{
					const name = sysVerbFullName[verb]; 
					idx = access(name); 
					
					version(/+$DIDE_REGION Add to cache+/all)
					{ with(indices) { sysVerbs[verb] = idx; }}
				}
				assert(idx); return idx; 
			} 
			
			Idx get(SysVerb verb)
			=> indices.sysVerbs.get(verb, Idx.init); 
			
			Idx access(in Idx sourceIdx, in Idx verbIdx, in Idx targetIdx)
			{
				Idx idx = findAssociation(sourceIdx, verbIdx, targetIdx); 
				if(!idx) {
					idx = stream.append(SER.Assoc!Idx(sourceIdx, verbIdx, targetIdx)); 
					insertAssociation(idx); 
				}
				return idx; 
			} 
			
			version(/+$DIDE_REGION+/all) {
				auto associations_by_SVT()
				=> indices.associations_by_SVT_impl
					.assumeSorted!((a, b)=>(assocLessThan_SVT(a, b))); 
				auto associations_by_TVS()
				=> indices.associations_by_TVS_impl
					.assumeSorted!((a, b)=>(assocLessThan_TVS(a, b))); 
				
				void insertAssociation(Idx assocIdx)
				{
					const svtPos = associations_by_SVT.lowerBound(assocIdx).length; 
					indices.associations_by_SVT_impl.insertInPlace(svtPos, assocIdx); 
					
					const tvsPos = associations_by_TVS.lowerBound(assocIdx).length; 
					indices.associations_by_TVS_impl.insertInPlace(tvsPos, assocIdx); 
				} 
				
				Idx findAssociation(in Idx sourceIdx, in Idx verbIdx, in Idx targetIdx)
				{
					bool assocLessThan_SVT(Idx a)
					{
						const assocA = explore(a).assoc; 
						if(assocA.source != sourceIdx) return assocA.source < sourceIdx; 
						if(assocA.verb != verbIdx) return assocA.verb < verbIdx; 
						return assocA.target < targetIdx; 
					} 
					
					auto items = associations_by_SVT; 
					
					//Binary search implementation
					size_t low = 0, high = items.length; 
					while(low < high)
					{
						size_t mid = low + (high - low) / 2; 
						const currentAssoc = explore(items[mid]).assoc; 
						
						// Check for exact match
						if(
							currentAssoc.source 	== sourceIdx 	&&
							currentAssoc.verb 	== verbIdx 	&&
							currentAssoc.target 	== targetIdx
						) { return items[mid]; }
						
						// Determine which half to search
						if(assocLessThan_SVT(items[mid]))	{ low = mid + 1; }
						else	{ high = mid; }
					}
					
					return 0; // Not found
				} 
			}
			
			auto findAssociationsBySourceVerb(in Idx sourceIdx, in Idx verbIdx)
			{
				bool assocLessThan_SV(in Idx idx)
				{
					const assoc = explore(idx).assoc; 
					if(assoc.source != sourceIdx) return assoc.source < sourceIdx; 
					return assoc.verb < verbIdx; 
				} 
				
				bool assocLessThanOrEqual_SV(in Idx idx)
				{
					const assoc = explore(idx).assoc; 
					if(assoc.source != sourceIdx) return assoc.source <= sourceIdx; 
					return assoc.verb <= verbIdx; 
				} 
				
				auto items = associations_by_SVT; 
				
				version(/+$DIDE_REGION Find lower bound (first matching element)+/all)
				{
					size_t low = 0, high = items.length; 
					while(low < high)
					{
						size_t mid = low + (high - low) / 2; 
						if(assocLessThan_SV(items[mid]))	{ low = mid + 1; }
						else	{ high = mid; }
					}
					size_t lowerBound = low; 
				}
				
				version(/+$DIDE_REGION Find upper bound (first element beyond matching range)+/all)
				{
					high = items.length; 
					while(low < high)
					{
						size_t mid = low + (high - low) / 2; 
						if(assocLessThanOrEqual_SV(items[mid]))	{ low = mid + 1; }
						else	{ high = mid; }
					}
					size_t upperBound = low; 
				}
				
				return ((lowerBound < upperBound)?(items[lowerBound..upperBound]) :(items[0..0])); 
			} auto findAssociationsByVerbTarget(in Idx verbIdx, in Idx targetIdx)
			{
				bool assocLessThan_TV(in Idx idx)
				{
					const assoc = explore(idx).assoc; 
					if(assoc.target != targetIdx) return assoc.target < targetIdx; 
					return assoc.verb < verbIdx; 
				} 
				
				bool assocLessThanOrEqual_TV(in Idx idx)
				{
					const assoc = explore(idx).assoc; 
					if(assoc.target != targetIdx) return assoc.target <= targetIdx; 
					return assoc.verb <= verbIdx; 
				} 
				
				auto items = associations_by_TVS; 
				
				version(/+$DIDE_REGION Find lower bound (first matching element)+/all)
				{
					size_t low = 0, high = items.length; 
					while(low < high)
					{
						size_t mid = low + (high - low) / 2; 
						if(assocLessThan_TV(items[mid]))	{ low = mid + 1; }
						else	{ high = mid; }
					}
					size_t lowerBound = low; 
				}
				
				version(/+$DIDE_REGION Find upper bound (first element beyond matching range)+/all)
				{
					high = items.length; 
					while(low < high)
					{
						size_t mid = low + (high - low) / 2; 
						if(assocLessThanOrEqual_TV(items[mid]))	{ low = mid + 1; }
						else	{ high = mid; }
					}
					size_t upperBound = low; 
				}
				
				return ((lowerBound < upperBound)?(items[lowerBound..upperBound]) :(items[0..0])); 
			} 
			
			auto findAssociationsBySource(in Idx sourceIdx)
			{
				bool assocLessThan_S(in Idx idx)
				=> explore(idx).assoc.source < sourceIdx; 
				
				bool assocLessThanOrEqual_S(in Idx idx)
				=> explore(idx).assoc.source <= sourceIdx; 
				
				auto items = associations_by_SVT; 
				version(/+$DIDE_REGION Find lower bound (first matching element)+/all)
				{
					size_t low = 0, high = items.length; 
					while(low < high)
					{
						size_t mid = low + (high - low) / 2; 
						if(assocLessThan_S(items[mid])) { low = mid + 1; }
						else { high = mid; }
					}
					size_t lowerBound = low; 
				}
				
				version(/+$DIDE_REGION Find upper bound (first element beyond matching range)+/all)
				{
					high = items.length; 
					while(low < high)
					{
						size_t mid = low + (high - low) / 2; 
						if(assocLessThanOrEqual_S(items[mid])) { low = mid + 1; }
						else { high = mid; }
					}
					size_t upperBound = low; 
				}
				
				return ((lowerBound < upperBound)?(items[lowerBound..upperBound]) :(items[0..0])); 
			} auto findAssociationsByTarget(in Idx targetIdx)
			{
				bool assocLessThan_T(in Idx idx)
				=> explore(idx).assoc.target < targetIdx; 
				
				bool assocLessThanOrEqual_T(in Idx idx)
				=> explore(idx).assoc.target <= targetIdx; 
				
				auto items = associations_by_TVS; 
				version(/+$DIDE_REGION Find lower bound (first matching element)+/all)
				{
					size_t low = 0, high = items.length; 
					while(low < high)
					{
						size_t mid = low + (high - low) / 2; 
						if(assocLessThan_T(items[mid])) { low = mid + 1; }
						else { high = mid; }
					}
					size_t lowerBound = low; 
				}
				
				version(/+$DIDE_REGION Find upper bound (first element beyond matching range)+/all)
				{
					high = items.length; 
					while(low < high)
					{
						size_t mid = low + (high - low) / 2; 
						if(assocLessThanOrEqual_T(items[mid])) { low = mid + 1; }
						else { high = mid; }
					}
					size_t upperBound = low; 
				}
				
				return ((lowerBound < upperBound)?(items[lowerBound..upperBound]) :(items[0..0])); 
			} 
			/+Todo: Later when it is well tested, these binary search functions must be templatized.+/
			static struct Explorer
			{
				This db; Idx idx; 
				
				bool isNull() const
				=> !idx;  bool opCast(B : bool)()
				=> !isNull; 
				
				bool isAssociation() const => mixin(界3(q{
					SER.TypeCode!
					(SER.Assoc!ubyte)
				},q{db.stream.stream[][idx]},q{
					SER.TypeCode!
					(SER.Assoc!uint)
				})); 
				
				auto assoc() const
				{
					Association res; 
					if(!isNull)
					{
						const 	st = db.stream.stream[],
							type = st[idx]; 
						switch(type)
						{
							case SER.TypeCode!
							(SER.Assoc!ubyte): 	res.source 	= st[idx+1+0],
							res.verb 	= st[idx+1+1],
							res.target 	= st[idx+1+2]; 	break; 
							case SER.TypeCode!
							(SER.Assoc!ushort): 	res.source 	= *(cast(ushort*)(&st[idx+1+0])),
							res.verb 	= *(cast(ushort*)(&st[idx+1+2])),
							res.target 	= *(cast(ushort*)(&st[idx+1+4])); 	break; 
							case SER.TypeCode!
							(SER.Assoc!uint): 	res.source 	= *(cast(uint*)(&st[idx+1+0])),
							res.verb 	= *(cast(uint*)(&st[idx+1+4])),
							res.target 	= *(cast(uint*)(&st[idx+1+8])); 	break; 
							default: 
						}
					}
					return res; 
				} 
				
				version(/+$DIDE_REGION+/all) {
					auto source() => Explorer(db, assoc.source); 
					auto verb() => Explorer(db, assoc.verb); 
					auto target() => Explorer(db, assoc.target); 
					
					auto sourceOrThis() => ((isAssociation)?(source):(this)); 
					auto verbOrThis() => ((isAssociation)?(verb):(this)); 
					auto targetOrThis() => ((isAssociation)?(target):(this)); 
				}
				
				ref indices() 
				=> db.indices; 
				
				static foreach(fn; FieldAndFunctionNamesWithUDA!(AMDB, AMDB._IS_FUNCTIONS, false))
				mixin(iq{bool $(fn)() => db.$(fn)(idx); }.text); 
				
				string toString() const
				{
					with(cast()this)
					{
						const st = db.stream.stream[], type = st[idx]; 
						switch(type)
						{
							case SER.TypeCode!
							(SER.Null): 	return "null"; 
							case SER.TypeCode!
							(SER.Assoc!ubyte): case SER.TypeCode!
							(SER.Assoc!ushort): case SER.TypeCode!
							(SER.Assoc!uint): 	return i"assoc($(idx))".text; 
							case SER.TypeCode!
							(char[0]): .. case SER.TypeCode!
							(char[SER.TinyStringMaxLength]): 	return (cast(string)(
								st[idx+1 .. $][
									0 .. type-(
										SER.TypeCode!
										(char[0])
									)
								]
							)); 
							default: return type.format!"unknown(%02X)"; 
						}
					}
				} 
				
				string dump()
				{
					const st = db.stream.stream[], type = st[idx], id = i"($(idx)):".text; 
					switch(type)
					{
						case SER.TypeCode!
						(SER.Null): 	return id~"null"; 
						case SER.TypeCode!
						(SER.Assoc!ubyte): case SER.TypeCode!
						(SER.Assoc!ushort): case SER.TypeCode!
						(SER.Assoc!uint): 	return id~i"assoc($(source.dump), $(verb.dump), $(target.dump))".text; 
						case SER.TypeCode!
						(char[0]): .. case SER.TypeCode!
						(char[SER.TinyStringMaxLength]): 	return id~(cast(string)(
							st[idx+1 .. $][
								0 .. type-(
									SER.TypeCode!
									(char[0])
								)
							]
						)).quoted; 
						default: return id~type.format!"unknown(%02X)"; 
					}
				} 
			} 
			
			auto explore(in Idx idx)
			=> Explorer(this, idx); 
			
			auto exploreTypes()
			=> indices.TypeIdx_by_name.byValue.map!((i)=>(explore(i))).cache; 
			auto exploreETypes()
			=> indices.ETypeIdx_by_name.byValue.map!((i)=>(explore(i))).cache; 
			auto exploreDTypes()
			=> indices.DTypeIdxByName.byValue.map!((i)=>(explore(i))).cache; 
			auto exploreATypes()
			=> indices.ATypeIdx_by_sourceVerbIdx.byValue.map!((i)=>(explore(i))).cache; 
			
			bool hasAnyTypes() const => !indices.TypeIdx_by_name.empty; 
			auto getInverseVerbATypes_of_EType(Idx idx) const => idx in indices.inverseVerbs_by_EType; 
			
			void visitChildETypes(Idx parentIdx, void delegate(Idx) onChild)
			{
				if(parentIdx && isEType(parentIdx))
				if(const subtype_of = get(mixin(舉!((SysVerb),q{subtype_of}))))
				foreach(a; findAssociationsByVerbTarget(subtype_of, parentIdx))
				onChild(a); 
			} 
			
			auto getEntityCount_of_EType(Idx idx, bool includeChildren) 
			{
				if(!isEType(idx)) return 0; 
				uint res = indices.entityCount_by_ETypeIdx.get(idx, 0); 
				if(includeChildren)
				{ visitChildETypes(idx, ((Idx cIdx){ res += indices.entityCount_by_ETypeIdx.get(cIdx, 0); })); }
				return res; 
			} 
			
		}
		version(/+$DIDE_REGION+/all) {
			protected SentenceStack!Idx sentenceStack 
			/+
				internal state that required while processing sentences. 
				⚠ AMDB is not thread safe. It's MAIN THREAD ONLY!!!!
			+/; 
			
			static struct SentenceStack(Idx, int N = 16)
			{
				Idx last; 
				uint stackLen; 
				Idx[N] stack; //stack[0] is always the last item.  stack[1] is the first level.
				
				void reset() { last = Idx.init; stackLen = 0; } 
				
				void dump() { writeln("stack: ",stack[].take(stackLen), " last: ", last); } 
				  
				Idx accessLast()
				{
					enforce(stackLen>0, "StentenceStack is empty"); 
					return last; 
				} 
				
				void updateLast(Idx idx)
				{ last = idx; } 
				
				Idx accessLevel(int level)
				{
					enforce(level>=0 && level<stackLen, i"SentenceStack idx out of range: $(level)".text); 
					return stack[level]; 
				} 
				
				void updateLevel(int level, Idx idx)
				{
					enforce(level>=0, "SentenceStack underflow"); 
					enforce(level<N, "SentenceStack overflow"); 
					enforce(level<stackLen+1, "SentenceStack nesting too deep"); 
					
					stackLen = level+1; 
					stack[level] = idx; 
					
					updateLast(idx); 
				} 
				
				static selfTest()
				{
					SentenceStack!Idx ss; void dump() => ss.dump; 
					//add 3 items
					ss.updateLevel(0, 1); dump; 
					ss.updateLevel(0, 2); dump; 
					ss.updateLevel(0, 3); dump; 
					//add same-line links to the last one
					writeln("prev: ", ss.accessLast); ss.updateLast(5); dump; 
					writeln("prev: ", ss.accessLast); ss.updateLast(6); dump; 
					writeln("prev: ", ss.accessLast); ss.updateLast(7); dump; 
					//add nested links
					writeln("prev: ", ss.accessLevel(0)); ss.updateLevel(1, 11); dump; 
					writeln("prev: ", ss.accessLevel(0)); ss.updateLevel(1, 12); dump; 
					writeln("prev: ", ss.accessLevel(0)); ss.updateLevel(1, 13); dump; 
					//nest recursively nest more items 
					writeln("prev: ", ss.accessLevel(1)); ss.updateLevel(2, 21); dump; 
					writeln("prev: ", ss.accessLevel(2)); ss.updateLevel(3, 22); dump; 
					writeln("prev: ", ss.accessLevel(3)); ss.updateLevel(4, 23); dump; 
					//add more
					writeln("prev: ", ss.accessLevel(1)); ss.updateLevel(2, 32); dump; 
					writeln("prev: ", ss.accessLevel(2)); ss.updateLevel(3, 33); dump; 
					//add nested links
					writeln("prev: ", ss.accessLevel(0)); ss.updateLevel(1, 41); dump; 
					writeln("prev: ", ss.accessLevel(0)); ss.updateLevel(1, 42); dump; 
					writeln("prev: ", ss.accessLevel(0)); ss.updateLevel(1, 43); dump; 
					ss.updateLevel(0, 1); dump; 
					ss.updateLevel(0, 2); dump; 
					ss.updateLevel(0, 3); dump; 
				} 
			} 
			
			class SchemaManager
			{
				void opCall(string src)
				{ sentenceStack.reset; processAMSentences(src, allSysVerbNames, &accessSchemaAssociation); }  void opIndex(string src)
				{ sentenceStack.reset; processAMSentences(src, allSysVerbNames, &getSchemaAssociation); } 
				
				protected
				{
					version(/+$DIDE_REGION Naming checks+/all)
					{
						void enforceValidName(string h_, bool chkUpper, bool chkLower)(string name)
						{
							const h = h_~": "; 
							enforce(name.strip==name, h~"Invalid leading/trailing whitespace "~name.quoted); 
							enforce(name!="", h~"Empty name."); 
							enforce(name.byDchar.front.isDLangIdentifierStart, h~"First char must be a letter."); 
							
							{
								const ch = name.byDchar.front; 
								if(ch.toUpper != ch.toLower)
								{
									if(chkUpper) enforce(ch.isUpper, h~"First char must be uppercase."); 
									if(chkLower) enforce(ch.isLower, h~"First char must be lowercase."); 
								}
							}
							
							foreach(ch; name.byDchar.drop(1))
							enforce(
								ch.isDLangIdentifierCont || ch.among(' ', '_'), 
								i"Invalid identifier char: $(ch.text.quoted), ($((cast(uint)(ch))))".text
							); 
						} 
						
						void enforceValidTypeName(string name)
						{ enforceValidName!("Type name", true, false)(name); } 
						
						void enforceValidVerbName(string name)
						{ enforceValidName!("Verb name", false, true)(name); } 
					}
					
					auto expect(alias fun, Args...)(in Args args)
					=> fun(args).enforce(i"AMDB.schema: Failed to get $(fun.stringof)($(args.text))".text); 
					
					version(/+$DIDE_REGION Access types+/all)
					{
						/+note : get* methods are automatically creating system types.+/
						
						version(/+$DIDE_REGION+/all)
						{
							Idx accessSysType(SysType type)
							{
								ref idx = indices.sysTypes[type]; 
								if(!idx) {
									const name = sysTypeNames[type]; 
									idx = access(name); 
									
									with(indices) {
										if(type==SysType.Entity)	addEType(name, idx); 
										else	addDType(name, idx); 
									}
								}
								assert(idx); return idx; 
							} 
							
							Idx accessSysEntity()
							{
								with(indices) {
									if(!entityIdx) { entityIdx = accessSysType(SysType.Entity); }
									assert(entityIdx); return entityIdx; 
								}
							} 
							
							Idx accessSysEntityType(T)(in T name)
							{
								if(asName(name)=="Entity") { return accessSysEntity; }
								return 0; 
							} 
							
							Idx expectEType(T)(in T a) => expect!getEType(a); 
							Idx getEType(T)(in T name_)
							{
								const name = asName(name_); 
								if(const idx = name in indices.ETypeIdx_by_name) return *idx; 
								if(const idx = accessSysEntityType(name)) { return idx; }
								return 0; 
							} 
						}
						
						version(/+$DIDE_REGION+/all)
						{
							Idx accessSysDataType(T)(in T name)
							{
								if(const a = asName(name) in sysTypeNameMap)
								{
									if(const type = *a/+Entity is the 0th sysType and that's not a DType+/)
									{ return accessSysType(type); }
								}
								return 0; 
							} 
							
							Idx expectDType(T)(in T a) => expect!accessDType(a); 
							Idx getDType(T)(in T name_)
							{
								const name = asName(name_); 
								if(const idx = name in indices.DTypeIdxByName) return *idx; 
								if(const idx = accessSysDataType(name)) return idx; 
								return 0; 
							} 
						}
						
						Idx expectType(T)(in T a) => expect!getType(a); 
						Idx getType(T)(in T name_)
						{
							const name = asName(name_); 
							return getEType(name).ifz(getDType(name)); 
						} 
						
					}
					
					Idx access_subtype_of(in AMToken sourceToken, in AMToken targetToken)
					{
						const name = evalStr(sourceToken); 
						if(auto tidx = name in indices.TypeIdx_by_name)
						{
							const idx = *tidx, targetStr = evalStr(targetToken); 
							auto existingTarget = explore(idx).target; 
							enforce(
								existingTarget.idx==getType(targetStr), 
								i"Error redefining type: `$(name)` from `$(existingTarget
	.sourceOrThis.text)` to `$(targetStr)`".text
							); 
							assert(idx); return idx; 
						}
						else
						{
							enforce(name!="Entity", i"Restricted source name: `$(name)`.".text); 
							enforceValidTypeName(name); 
							const targetIdx = expectType(targetToken); 
							const idx = 	access(access(name), access(mixin(舉!((SysVerb),q{subtype_of}))), targetIdx)
								.enforce("Failed to access Type"); 
							if(
								explore(targetIdx).isDType
								/+Todo: if I use usEtype here, it fails+/
							)	indices.addDType(name, idx); 
							else	indices.addEType(name, idx); 
							assert(idx); return idx; 
						}
					} 
					
					Idx access_AType(in AMToken sourceToken, in string verbStr, in AMToken targetToken)
					{
						enforce(sourceToken.type.among(TT.words, TT.str), "AType source must be some string"); 
						const sourceStr = evalStr(sourceToken); 
						if(const sourceIdx = sourceStr in indices.ETypeIdx_by_name)
						{ return access_AType(*sourceIdx, verbStr, targetToken); }
						else { enforce(0, i"AType source `$(sourceStr)` is not an EType.".text); assert(0); }
					} 
					
					Idx access_AType(in Idx sourceIdx, in string verbStr, in AMToken targetToken)
					{
						enforce(sourceIdx, "AType source must be non-null"); 
						
						enforceValidVerbName(verbStr); const verbIdx = access(verbStr); 
						
						const 	targetName 	= asName(targetToken), 
							targetNameFirstChar 	= targetName.byDchar.frontOr,
							targetIsType 	= targetNameFirstChar==targetNameFirstChar.toUpper; 
						
						Idx doit(Idx targetIdx, bool isCompositeKey=false)
						{
							Idx idx; 
							if(auto aidx = [sourceIdx, verbIdx] in indices.ATypeIdx_by_sourceVerbIdx)
							{
								idx = *aidx; auto existingTarget = explore(idx).target; 
								enforce(
									existingTarget.idx==targetIdx, 
									i"AType `$(explore(sourceIdx).sourceOrThis)` [$(verbStr)]".text ~
									" cannot be redefined with another type: " ~
									i"$(existingTarget.sourceOrThis)` -> `$(explore(targetIdx).sourceOrThis)`".text
								); 
							}
							else
							{
								idx = access(sourceIdx, verbIdx, targetIdx); 
								indices.addAType([sourceIdx, verbIdx], idx); 
								if(isCompositeKey) indices.ATypeIsCompositeKey[idx] = true; 
							}
							assert(idx); return idx; 
						} 
						
						if(targetIsType)
						{
							const targetIdx = expectType(targetToken); 
							return doit(targetIdx); 
						}
						else
						{
							/+Target is a verb. It can be a composite key.+/
							enforceValidVerbName(targetName); 
							
							Idx parentIdx; 
							with(explore(sourceIdx))
							{
								/+
									Parent association example: 
									- Must be an AType and .target must be an EType
									/+
										Code: assoc(
											assoc(
												"Employee",
												"is a subtype of",
												"Entity"
											), "job", assoc(
												"Job",
												"is a subtype of",
												"Entity"
											)
										)
									+/
								+/
								
								if(!(isAType && (target.isEType || target.isAType)))
								((0xDEB4EB4AA1C7).檢(dump)); 
								
								/+
									AI: /+
										User: Reformat this, so I can see the structure better!
										/+Code: (128):assoc((124):assoc((116):assoc((107):"Employee", (16):"is a subtype of", (1):"Entity"), (120):"job", (40):assoc((36):"Job", (16):"is a subtype of", (1):"Entity")), (44):"grade", (54):assoc((40):assoc((36):"Job", (16):"is a subtype of", (1):"Entity"), (44):"grade", (50):"Int"))+/
									+/
									/+
										Assistant: /+
											Structured: /+
												Code: assoc(
													assoc(
														assoc(
															(107):"Employee",
															(16):"is a subtype of",
															(1):"Entity"
														),
														"job",
														assoc(
															(36):"Job",
															(16):"is a subtype of",
															(1):"Entity"
														)
													),
													"grade",
													assoc(
														assoc(
															(36):"Job",
															(16):"is a subtype of",
															(1):"Entity"
														),
														"grade",
														"Int"
													)
												)
											+/
										+/
										
										/+Note: Usage(prompt_hit: 64, prompt_miss: 254, completion: 178, HUF: 0.04, price: 100%)+/
									+/
								+/
								
								enforce(isAType && (target.isEType || target.isAType), "Expected a source property that points to an EType."); 
								parentIdx = target.idx; 
							}
							
							const targetVerbIdx = get(targetName); 
							enforce(targetVerbIdx, i"Target verb $(targetName.quoted) must exist already. ".text); 
							const parentATypeIdx = indices.ATypeIdx_by_sourceVerbIdx.get([parentIdx, targetVerbIdx]); 
							enforce(
								parentATypeIdx, i"Target verb $(targetName.quoted) not found ".text ~
								i"in EType $(explore(parentIdx).sourceOrThis.text.quoted)".text
							); 
							
							/+The target of this AType is a field ATtype in the source Entity+/
							const retIdx = doit(parentATypeIdx, isCompositeKey: true); 
							
							((0xE6DBEB4AA1C7).檢(explore(retIdx).dump)); 
							/+
								Expected result:
								/+
									Code: assoc(
										assoc(
											assoc(
												"Employee",
												"is a subtype of",
												"Entity"
											),
											"job",
											assoc(
												"Job",
												"is a subtype of",
												"Entity"
											)
										), "grade", assoc(
											assoc(
												"Job",
												"is a subtype of",
												"Entity"
											),
											"grade",
											"Int"
										)
									)
								+/
								2nd level:
								/+
									Code: assoc(
										assoc(
											assoc(
												assoc(
													"Employee",
													"is a subtype of",
													"Entity"
												),
												"job",
												assoc(
													"Job",
													"is a subtype of",
													"Entity"
												)
											), 
											"grade", 
											assoc(
												assoc(
													"Job",
													"is a subtype of",
													"Entity"
												),
												"grade",
												"Int"
											)
										), "country", assoc(
											assoc(
												assoc(
													"Job",
													"is a subtype of",
													"Entity"
												),
												"grade",
												"Int"
											), 
											"country", 
											assoc(
												"Country",
												"is a subtype of",
												"Entity"
											)
										)
									)
								+/
							+/
							
							return retIdx; 
						}
					} 
					
					Idx access_inverse_verb(Idx aTypeIdx, in AMToken targetToken)
					{
						/+
							AType	: Shop 	⟶ [sells] 	⟶ Product
							InverseVerb definition	: AType 	⟶ [inverse verb] 	⟶ "sold by"
							Meaning	: Product 	⟶ [sold by] 	⟶ Shop
						+/
						
						auto aType = explore(aTypeIdx); 	enforce(aType.isAType, "Inverse verb: Source must be an AType."); 
						auto aTypeSource = aType.source; 	enforce(aTypeSource.isEType, "Inverse verb: AType source must be an EType."); 
						auto aTypeTarget = aType.target; 	enforce(aTypeTarget.isEType, "Inverse verb: AType target must be an EType."); 
						enforce(aType.verb.idx!=get(mixin(舉!((SysVerb),q{inverse_verb}))), "Inverse verb cannot have an inverse."); 
						
						enforce(targetToken.type==TT.words, "Words expected for inverse verb target."); 
						const inverseVerbStr = evalStr(targetToken); 
						enforceValidVerbName(inverseVerbStr); 
						enforce(aType.verb.text!=inverseVerbStr, "Inverse verb must differ from forward verb."); 
						
						Idx idx; 
						if(const a = aTypeIdx in indices.inverseVerbIdx_by_ATypeIdx)
						{
							idx = *a; 
							const 	existingVerbStrIdx 	= explore(idx).target.idx,
								newVerbStrIdx 	= inverseVerbStr in indices.strings; 
							enforce(
								newVerbStrIdx && existingVerbStrIdx==*newVerbStrIdx,
								i"Inverse verb already exists with a different name: `$(explore(existingVerbStrIdx).text)`".text
							); 
						}
						else
						{
							idx = access(aTypeIdx, access(mixin(舉!((SysVerb),q{inverse_verb}))), access(inverseVerbStr)); 
							indices.inverseVerbIdx_by_ATypeIdx[aTypeIdx] = idx; 
							indices.ATypeIdx_by_inverseVerbIdx[idx] = aTypeIdx; 
							indices.inverseVerbs_by_EType[aTypeTarget.idx] ~= idx /+
								Todo: this is bad. I should stop making
								theese assoc arrays and use binary searches.
							+/; 
						}
						assert(idx); return idx; 
					} 
					
					void processSchemaAssociation(bool canCreate)
						(in AMToken sourceToken, in AMToken verbToken, in AMToken targetToken)
					{
						const level = sourceToken.type.predSwitch(TT.ppp, -1, TT.tabs, sourceToken.src.length.to!int, 0); 
						
						enforce(verbToken.type==TT.verb, "Verb expected."); 
						const verbStr = evalStr(verbToken); 
						
						Idx idx; 
						
						if(level!=0 /+This is a linked sentence: ... verb targer+/)
						{
							const sourceIdx = ((level<0)?(sentenceStack.accessLast/+same line+/) :(sentenceStack.accessLevel(level-1))); 
							if(const sysVerb = schemaSysVerb(verbStr))
							{
								with(SysVerb)
								switch(sysVerb)
								{
									case inverse_verb: 	idx = access_inverse_verb(sourceIdx, targetToken); 	break; 
									default: 	enforce(0, i"Invalid schema verb usage: $(sysVerb)".text); 
								}
							}
							else
							{ idx = access_AType(sourceIdx, verbStr, targetToken); }
						}
						else
						{
							if(const sysVerb = schemaSysVerb(verbStr))
							{
								with(SysVerb)
								switch(sysVerb)
								{
									case subtype_of: 	idx = access_subtype_of(sourceToken, targetToken); 	break; 
									case inverse_verb: 	enforce(0, "Inverse verb requires an AType as source."); 	break; 
									case instance_of: 	enforce(0, "Cannot create instances in Schema mode."); 	break; 
									default: 	enforce(0, i"Invalid data verb usage: $(sysVerb)".text); 
								}
							}
							else
							{ idx = access_AType(sourceToken, verbStr, targetToken); }
						}
						
						if(level<0)	sentenceStack.updateLast(idx)/+same line+/; 
						else	sentenceStack.updateLevel(level, idx); 
						//sentenceStack.dump; 
					} 
					alias accessSchemaAssociation 	= processSchemaAssociation!true,
					getSchemaAssociation 	= processSchemaAssociation!false; 
					
				} 
			} 
			class DataManager
			{
				void opCall(string src)
				{ sentenceStack.reset; processAMSentences(src, allSysVerbNames, &accessDataAssociation); }  void opIndex(string src)
				{ sentenceStack.reset; processAMSentences(src, allSysVerbNames, &getDataAssociation); } 
				
				protected
				{
					Idx access_instance_of(in AMToken sourceToken, in AMToken targetToken)
					{
						const eTypeIdx = schema.expectEType(targetToken); 
						
						const sourceStr = evalStr(sourceToken); 
						Idx sourceIdx = get(sourceStr); 
						
						Idx verbIdx = get(mixin(舉!((SysVerb),q{instance_of}))); 
						
						version(/+$DIDE_REGION Search for existing instance+/all)
						{
							Idx idx; 
							if(sourceIdx && verbIdx)
							{
								idx = findAssociationsBySourceVerb(sourceIdx, verbIdx).frontOr(0); 
								//Opt: Reuse the known position from the this `find` in the `access` later. 
								enforce(
									explore(idx).target.idx==eTypeIdx,
									i"Entity $(sourceStr.quoted) already exists with different type. ".text
								); 
							}
						}
						
						if(!idx) {
							version(/+$DIDE_REGION Create new instance with item and verb+/all)
							{
								if(!sourceIdx) sourceIdx = access(sourceStr); 
								if(!verbIdx) verbIdx = access(mixin(舉!((SysVerb),q{instance_of}))); 
								idx = access(sourceIdx, verbIdx, eTypeIdx); 
								
								indices.entityCount_by_ETypeIdx[eTypeIdx]++; 
							}
						}
						
						static if((常!(bool)(0)))
						print(
							"\33\13", explore(idx), explore(idx).source, 
							explore(idx).verb, explore(idx).target.sourceOrThis, "\33\7"
						); 
						
						
						assert(idx); return idx; 
					} 
					
					auto expect(alias fun, Args...)(in Args args)
					=> fun(args).enforce(i"AMDB.data: Failed to get $(fun.stringof)($(args.text))".text); 
					
					Idx expectEntity(T)(in T a) => expect!getEntity(a); 
					Idx getEntity(T)(in T name_)
					{
						static if(is(T==Idx))
						{
							if(const nameIdx = name_)
							if(const verbIdx = get(mixin(舉!((SysVerb),q{instance_of}))))
							return findAssociationsBySourceVerb(nameIdx, verbIdx).frontOr(0)
							/+Todo: what's when there are multiple instances with the same name?+/; 
						}
						else
						{
							const 	name 	= asName(name_),
								nameIdx 	= get(name); 
							return getEntity(nameIdx); 
						}
						return 0; 
					} 
					
					Idx access_attribute(in AMToken sourceToken, in string verbStr, in AMToken targetToken)
					=> access_attribute(expectEntity(sourceToken), verbStr, targetToken); 
					
					Idx access_attribute(in Idx sourceIdx, in string verbStr, in AMToken targetToken)
					{
						static if((常!(bool)(0))) print("...ATTRIBUTE", sourceIdx, verbStr, targetToken); 
						
						Idx accessTarget(Idx aTypeIdx)
						{
							const targetStr = evalStr(targetToken); 
							auto aType = explore(aTypeIdx); enforce(aType.isAType); 
							if(aType.target.isEType)	{ return expectEntity(targetToken); }
							else {
								//Todo: implement proper type handling
								return access(asName(targetToken)); 
							}
						} 
						
						Idx idx; 
						if(isEntity(sourceIdx))
						{
							const eTypeIdx = explore(sourceIdx).target.idx; 
							const verbIdx = get(verbStr)/+it should exists because the AType defined it already+/; 
							const aTypeIdx = ([eTypeIdx, verbIdx] in indices.ATypeIdx_by_sourceVerbIdx)
								.enforce(i"Unknown association [$(explore(eTypeIdx).sourceOrThis)].[$(verbStr)]".text); 
							
							//Todo: check cardinality
							const targetIdx = accessTarget(*aTypeIdx); 
							idx = access(sourceIdx, *aTypeIdx, targetIdx); 
						}
						else if(isAttribute(sourceIdx))
						{
							const verbIdx = get(verbStr)/+it should exists because the AType defined it already+/; 
							const prevATypeIdx = explore(sourceIdx).verb.idx; 
							const aTypeIdx = ([prevATypeIdx, verbIdx] in indices.ATypeIdx_by_sourceVerbIdx)
								.enforce(i"Unknown association [$(explore(prevATypeIdx).verb)]...[$(verbStr)]".text); 
							
							//Todo: check cardinality
							const targetIdx = accessTarget(*aTypeIdx); 
							idx = access(sourceIdx, *aTypeIdx, targetIdx); 
						}
						else enforce(0, i"EType or AType expected instead of $(sourceIdx)".text); 
						assert(idx); return idx; 
					} 
					
					void processDataAssociation(bool canCreate)
						(in AMToken sourceToken, in AMToken verbToken, in AMToken targetToken)
					{
						const level = sourceToken.type.predSwitch(TT.ppp, -1, TT.tabs, sourceToken.src.length.to!int, 0); 
						
						enforce(verbToken.type==TT.verb, "Verb expected."); 
						const verbStr = evalStr(verbToken); 
						
						Idx idx; 
						
						if(level!=0 /+This is a linked sentence: ... verb targer+/)
						{
							const sourceIdx = ((level<0)?(sentenceStack.accessLast/+same line+/) :(sentenceStack.accessLevel(level-1))); 
							if(const sysVerb = dataSysVerb(verbStr))
							{
								with(SysVerb)
								switch(sysVerb)
								{ default: 	enforce(0, i"Invalid verb usage: $(sysVerb)".text); }
							}
							else
							{
								/+Todo: inverse verbs!+/
								idx = access_attribute(sourceIdx, verbStr, targetToken); 
							}
						}
						else
						{
							if(const sysVerb = dataSysVerb(verbStr))
							{
								with(SysVerb)
								switch(sysVerb)
								{
									case instance_of: 	idx = access_instance_of(sourceToken, targetToken); 	break; 
									case subtype_of: 	enforce(0, i"Cannot create subtypes in data mode.".text); 	break; 
									default: 	enforce(0, i"Invalid verb usage: $(sysVerb)".text); 
								}
							}
							else
							{
								/+Todo: inverse verb+/
								idx = access_attribute(sourceToken, verbStr, targetToken); 
							}
						}
						
						if(level<0)	sentenceStack.updateLast(idx)/+same line+/; 
						else	sentenceStack.updateLevel(level, idx); 
						//sentenceStack.dump; 
					} 
					alias accessDataAssociation 	= processDataAssociation!true,
					getDataAssociation 	= processDataAssociation!false; 
				} 
			} 
		}
	} 
}