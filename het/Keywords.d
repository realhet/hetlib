module het.keywords;

import het.utils;

////////////////////////////////////////////////////////////////////////////////
///  Basic Types                                                             ///
////////////////////////////////////////////////////////////////////////////////

//todo: some types are no more. Complex numbers for example.
	 //	|---> maps exactly to kwEnums
enum BasicType:byte	 {Unknown,	Byte, UByte, Short, UShort, Int, UInt, Long, ULong, Cent, UCent, Float, Double, Real, IFloat, IDouble, IReal, CFloat, CDouble, CReal, Bool, Char, WChar, DChar, Void }
auto BasicTypeBytes	 =[	    0,	   1,	    1,     2,      2,   4,    4,    8,     8,   16,    16,     4,      8,	  10,      4,       8,	   10,      8,      16,    20,	   1,	   1,     2,     4,	   0];
auto BasicTypeBits	 =[	    0,	   8,	    8,    16,     16,  32,   32,   64,    64,  128,   128,    32,     64,	  80,     32,      64,	   80,     64,     128,   160,	   8,	   8,    16,    32,	   0];

bool isInteger	 (BasicType b) { return b>=BasicType.Byte   && b<=BasicType.UCent; }
bool isSigned	 (BasicType b) { return b&1; }
bool isFloat	 (BasicType b) { return b>=BasicType.Float	&& b<=BasicType.CReal; }
bool isImag	 (BasicType b) { return b>=BasicType.IFloat	&& b<=BasicType.IReal; }
bool isComplex	 (BasicType b) { return b>=BasicType.CFloat	&& b<=BasicType.CReal; }
bool isBool	 (BasicType b) { return b==BasicType.Bool; }
bool isChar	 (BasicType b) { return b>=BasicType.Char   && b<=BasicType.DChar; }
bool isVoid	 (BasicType b) { return b==BasicType.Void; }

////////////////////////////////////////////////////////////////////////////////
///  Keywords                                                                ///
////////////////////////////////////////////////////////////////////////////////

private enum _keywordStrs = [ //last items of categories must be untouched!!!
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

		"Vector",
		"vec2", "dvec2", "ivec2", "uvec2", "bvec2", "RG",
		"vec3", "dvec3", "ivec3", "uvec3", "bvec3", "RGB",
		"vec4", "dvec4", "ivec4", "uvec4", "bvec4", "RGBA",

		"Matrix",
		 "mat2" , "mat3" , "mat4" , "mat2x3",  "mat2x4",  "mat3x2",  "mat3x4",  "mat4x2",  "mat4x3",
		"dmat2", "dmat3", "dmat4", "dmat2x3", "dmat2x4", "dmat3x2", "dmat3x4", "dmat4x2", "dmat4x3",

		"Bounds",
		"bounds" , "dbounds" , "ibounds" ,
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

enum KeywordCat { Unknown, Attribute, Value, BasicType, UserDefiniedType, Keyword, SpecialFunct, SpecialKeyword, Operator }

KeywordCat kwCatOf(int k)
{with(KeywordCat){
	if(k<=kwUnknown		) return Unknown	  ;
	if(k<=kwpackage		) return Attribute	  ;
	if(k<=kwsuper	  )	return Value	  ;
	if(k<=kwvoid	  ) return BasicType	  ;
	if(k<=kwfunction	  ) return UserDefiniedType	  ;
	if(k<=kwversion	  ) return Keyword	  ;
	if(k<=kw__vector	  ) return SpecialFunct	  ;
	if(k<=kw__PRETTY_FUNCTION__	  ) return SpecialKeyword	  ;
	if(k<=kwnew	  ) return Operator	  ;
	return Unknown;
}}

bool kwIsValid	  (int k) { return kwCatOf(k)!=KeywordCat.Unknown	   ; }
bool kwIsAttribute	  (int k) { return kwCatOf(k)==KeywordCat.Attribute	   ; }
bool kwIsValue	  (int k) { return kwCatOf(k)==KeywordCat.Value	   ; }
bool kwIsBasicType	  (int k) { return kwCatOf(k)==KeywordCat.BasicType	   ; }
bool kwIsUserDefiniedType	  (int k) { return kwCatOf(k)==KeywordCat.UserDefiniedType	   ; }
bool kwIsKeyword	  (int	k) { return kwCatOf(k)==KeywordCat.Keyword	   ; }
bool kwIsSpecialFunct		(int k) { return kwCatOf(k)==KeywordCat.SpecialFunct	   ; }
bool kwIsSpecialKeyword	  (int k) { return kwCatOf(k)==KeywordCat.SpecialKeyword	   ; }
bool kwIsOperator	  (int k) { return kwCatOf(k)==KeywordCat.Operator	   ; }

int kwLookup(string s)
{
	auto p = tdKeywords.lookup(s);
	return p ? *p+1 : kwUnknown;
}

KeywordCat kwCatOf(string s)
{
	return kwCatOf(kwLookup(s));
}

string kwStr(int kw) { return tdKeywords.keyOf(kw); }


////////////////////////////////////////////////////////////////////////////////
///  Operators                                                               ///
////////////////////////////////////////////////////////////////////////////////

//whitespace: 20,09,0A,0D
//	01234567890123456789012345678901
//numbers:	0123456789aAbBcCdDeEfFgGhHiIjJkK
//letters:	lLmMnNoOpPqQrRsStTuUvVwWxXyYzZ_
//symbols:	@!"#$%&'()*+-./[\]^_{|}~` :;<=>?

// @
// ! !=
// # unused
// $ unused
// % %=
// & &= &&
// * *=
// + += ++
// - -= --
// . .. ...
// / /=
// \ unused
// ^ ^= ^^ ^^=
// | |= ||
// ~ ~=
// :
// ;
// < << <<= <=
// = ==
// > >> >>> >= >>= >>>=
// ?
// in is new delete

private enum _operatorStrs = [ //TODO: make it a Map, after it has a working static initializer.
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

/*  "<>"       ,"lessGreater",         "<>="      ,"LessGreaterEqual",
	"!<"					 ,"notLess",	     "!<="	    ,"notLessEqual",
	"!>"					 ,"notGreater",	     "!>="	    ,"notGreaterEqual",
	"!<>"	     ,"notLessGreater",	     "!<>="	    ,"notLessGreaterEqual", these unordered compares are deprecated*/

	"in"	 ,"in"	, "is"	, "is"	, "new"	, "new"	, "delete"	, "delete"
];

string[] _operatorEnums() { string[] r;
	foreach(idx, s; _operatorStrs) if(idx&1) r ~= "op"~s;
return r; }

string[] _operatorMaps() { string[] r;
	foreach(idx, s; _operatorStrs) if(idx&1) r ~= '`'~_operatorStrs[idx-1]~"`:op"~s;
return r; }

//enum declaration
mixin("enum {opUnknown, "~_operatorEnums.join(',')~'}');

int opParse(string s, ref int len)
{
	auto p = tdOperators.parse(s, len);
	return p ? *p : opUnknown;
}

int opParse(string s)
{
	int len;
	return opParse(s, len);
}

string opStr(int op) { return tdOperators.keyOf(op); }

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
struct TokenDictionary(T){
	T[string] arr;
	int maxLen;

	void postInit(){
		arr.rehash;
		maxLen = 0;
		foreach(s; arr.keys) maximize(maxLen, cast(int)s.length);
	}

	T* parse(string s, ref int resLen){
		foreach_reverse(len; 1..min(maxLen, s.length)+1){
			if(auto p = s[0..len] in arr){
				resLen = len;
				return p;
			}
		}
		return null;
	}

	T* lookup(string s) { return s in arr; }

	string keyOf(const T value) {
		foreach(const kv; arr.byKeyValue) if(kv.value==value) return kv.key;
		return "";
	}
}

__gshared TokenDictionary!(int) tdKeywords, tdOperators, tdNamedCharEntries;

struct moduleInit{
	shared static this(){
		//initKeywords;
		foreach(idx, s; _keywordStrs) tdKeywords.arr[s] = idx.to!int;
		tdKeywords.postInit;

		//init operators
		tdOperators.arr = mixin("["~_operatorMaps.join(',')~"]");
		tdOperators.postInit;

		//init named char entries
		tdNamedCharEntries.arr = [
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
}


////////////////////////////////////////////////////////////////////////////////
///  GCN instruction detector                                                ///
////////////////////////////////////////////////////////////////////////////////

public:

bool isGCNInstruction(string s){
	return GCNInstructionKind(s)!=0;
}

//returns nonzero if found something. 1=vector, 2=scalar 3=misc
ubyte GCNInstructionKind(string s){
										 //0	1	2	3	4	5	6
	static GCNPrefix1 = ["buffer_",	"ds_",	"flat_",	"image_",	"s_",	"tbuffer_",	"v_"];

	ubyte type;
	bool found;

	foreach(i, p; GCNPrefix1) if(s.startsWith(p)) {
		found = true;
		type = i==6 ? 1 : i==4 ? 2 : 3; //vector, scalar, misc
		break;
	}
	if(!found) return 0;

	static GCNPrefix2 = ["buffer_atomic", "buffer_load", "buffer_store", "buffer_wbinvl1", "ds_add", "ds_and", "ds_append", "ds_bpermute", "ds_cmpst",
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
		"v_subb", "v_subbrev", "v_subrev", "v_trig", "v_trunc", "v_writelane", "v_xor"];

	found = false;
	foreach(p; GCNPrefix2) if(s.startsWith(p)) { found = true; break; }
	if(!found) return 0;

	static GCNSuffix = ["add", "all", "and", "append", "b", "b128", "b16", "b32", "b64", "b8", "b96", "barrier", "br", "branch", "buffer", "byte", "c", "cd",
		"cdbgsys", "cdbguser", "cl", "clrexcp", "cmpswap", "consume", "count", "d", "dec", "decperflevel", "dword", "dwordx16", "dwordx2", "dwordx3", "dwordx4",
		"dwordx8", "endpgm", "execnz", "execz", "f16", "f32", "f64", "fcmpswap", "fmax", "fmin", "fork", "gather4", "i16", "i24", "i32", "i4", "i64", "i8", "idx",
		"inc", "incperflevel", "init", "inv", "join", "l", "load", "lod", "lz", "memrealtime", "memtime", "mip", "mode", "nop", "o", "off", "on", "or", "p", "pck",
		"probe", "resinfo", "rsub", "sample", "saved", "sbyte", "sc", "scc0", "scc1", "sendmsg", "sendmsghalt", "sethalt", "setkill", "setprio", "setvskip", "sgn",
		"short", "sleep", "smax", "smin", "sshort", "store", "sub", "swap", "trap", "ttracedata", "u16", "u24", "u32", "u64", "u8", "ubyte", "ubyte0", "ubyte1",
		"ubyte2", "ubyte3", "umax", "umin", "user", "ushort", "v", "vccnz", "vccz", "vol", "waitcnt", "wakeup", "wb", "wbinvl1", "x", "x2", "xor", "xy", "xyz", "xyzw"];

	found = false;
	foreach(p; GCNSuffix) if(s.endsWith("_"~p)) { found = true; break; }
	if(!found) return 0;

	return type;
}


////////////////////////////////////////////////////////////////////////////////
///  GLSL instruction detector                                               ///
////////////////////////////////////////////////////////////////////////////////

bool isGLSLInstruction(string s){
	return ["gl_Position", "gl_FragColor"].canFind(s); //todo: atirni among()-ra
}

ubyte GLSLInstructionKind(string s){ //0:do nothing, 1:keyword, 2:typeQual, 3:types, 4:values, 5:functs, 6:vars
	static GLSLKeywords = ["break","case","continue","default","do","else","for","if","discard","return","struct","switch","while"];
	static GLSLTypeQualifiers = ["attribute","const","inout","invariant","in","out","varying","uniform","flat","noperspective","smooth","centroid","layout","patch","subroutine", "half"];
	static GLSLTypes = ["bool","void","double","float","int","uint","bvec2","bvec3","bvec4","mat2","mat2x2","mat2x3","mat2x4","mat3","mat3x2","mat3x3","mat3x4","mat4","mat4x2",
		"mat4x3","mat4x4","dmat2","dmat2x2","dmat2x3","dmat2x4","dmat3","dmat3x2","dmat3x3","dmat3x4","dmat4","dmat4x2","dmat4x3","dmat4x4","dvec2","dvec3","dvec4","uvec2","uvec3",
		"uvec4","vec2","vec3","vec4","ivec2","ivec3","ivec4","sampler1D","sampler1DArray","sampler1DArrayShadow","sampler1DShadow","sampler2D","sampler2DArray","sampler2DArrayShadow",
		"sampler2DMS","sampler2DMSArray","sampler2DRect","sampler2DRectShadow","sampler2DShadow","sampler3D","samplerBuffer","samplerCube","samplerCubeArray","samplerCubeArrayShadow",
		"samplerCubeShadow","usampler1D","usampler1DArray","usampler2D","usampler2DArray","usampler2DMS","usampler2DMSarray","usampler2DRect","usampler3D","usamplerBuffer","usamplerCube","usamplerCubeArray"];
	static GLSLValues = ["true","false"];
	static GLSLFuncts = ["sample","isampler1D","isampler1DArray","isampler2D","isampler2DArray","isampler2DMS","isampler2DMSArray","isampler2DRect","isampler3D","isamplerBuffer","isamplerCube","isamplerCubeArray"];
	static GLSLVars = ["gl_VertexID","gl_InstanceID","gl_Position","gl_PointSize","gl_ClipDistance","gl_PatchVerticesIn","gl_PrimitiveID","gl_InvocationID","gl_in","gl_TessLevelOuter",
		"gl_TessLevelInner","gl_out","gl_TessCoord","gl_PrimitiveIDIn","gl_FragColor","gl_FragCoord","gl_FragDepth","gl_FrontFacing","gl_PointCoord","gl_SamplePosition","gl_SampleMaskIn","gl_Layer","gl_ViewportIndex","gl_SampleMask"];

	//TODO: make it faster with a map

	if(GLSLKeywords.canFind(s)) return 1;
	if(GLSLTypeQualifiers.canFind(s)) return 2;
	if(GLSLTypes.canFind(s)) return 3;
	if(GLSLValues.canFind(s)) return 4;
	if(GLSLFuncts.canFind(s)) return 5;
	if(GLSLVars.canFind(s)) return 6;
	return 0;
}

////////////////////////////////////////////////////////////////////////////////
///  Syntax highlight presets                                                ///
////////////////////////////////////////////////////////////////////////////////

struct SyntaxStyle{
	RGB fontColor, bkColor;
	int fontFlags; //1:b, 2:i, 4:u
}

static if(0) class SyntaxPreset_future{ //future
	SyntaxStyle
	//standard language things
		whitespace, number, binary1, string_, keyword, symbol, directive, label, attribute, basicType,
	//editor functionality
		selected, foundAct, foundAlso, navLink,
	// development stuff
		comment, error, warning, deprecation, todo, optimize,
	//extra language things
		identifier1, identifier2, identifier3, identifier4, identifier5, identifier6;


	//testCode

	immutable testCode = q{
		@directive void get() const { //comment
			return value + 123 + 5.6 + 0b1100101 * "42".to!int;
		}
		/*comment*/ /*todo:	...*/ /*opt: ...*/
		selected  foundAct	foundAlso  navLink
		error  warning  deprecation

		//GLSL

		//GCN ASM


	};
}

struct SyntaxStyleRow{
	string kindName;
	SyntaxStyle[] formats;
}


//todo: these should be uploaded to the gpu
//todo: from the program this is NOT extendable
immutable syntaxPresetNames =	             ["Default"             , "Classic"                         , "C64"                   , "Dark"                     ];
immutable SyntaxStyleRow[] syntaxTable =[	
	{"Whitespace"	, [{clBlack	,clWhite	,0}, {clVgaYellow	,clVgaLowBlue	,0}, {clC64LBlue	,clC64Blue	,0}, {0xc7c5c5	,0x2f2f2f ,0}]},
	{"Selected"	, [{clWhite	,10841427	,0}, {clVgaLowBlue	,clVgaLightGray	,0}, {clC64Blue	,clC64LBlue	,0}, {clBlack	,0xc7c5c5 ,0}]},
	{"FoundAct"	, [{0xFCFDCD	,clBlack	,0}, {clVgaLightGray	,clVgaBlack	,0}, {clC64LGrey	,clC64Black	,0}, {clBlack	,0xffffff ,0}]},
	{"FoundAlso"	, [{clBlack	,0x78AAFF	,0}, {clVgaLightGray	,clVgaBrown	,0}, {clC64LGrey	,clC64DGrey	,0}, {clBlack	,0xa7a5a5 ,0}]},
	{"NavLink"	, [{clBlue	,clWhite	,4}, {clVgaHighRed	,clVgaLowBlue	,4}, {clC64Red	,clC64Blue	,0}, {0xFF8888	,0x2d2d2d ,4}]},
	{"Number"	, [{clBlue	,clWhite	,0}, {clVgaYellow	,clVgaLowBlue	,0}, {clC64Yellow	,clC64Blue	,0}, {0x0094FA	,0x2d2d2d ,0}]},
	{"String"	, [{clBlue	,clSkyBlue	,0}, {clVgaHighCyan	,clVgaLowBlue	,0}, {clC64Cyan	,clC64Blue	,0}, {0x64E000	,0x283f28 ,0}]},
	{"Keyword"	, [{clNavy	,clWhite	,1}, {clVgaWhite	,clVgaLowBlue	,1}, {clC64White	,clC64Blue	,0}, {0x5C00F6	,0x2d2d2d ,1}]},
	{"Symbol"	, [{clBlack	,clWhite	,0}, {clVgaYellow	,clVgaLowBlue	,0}, {clC64Yellow	,clC64Blue	,0}, {0x00E2E1	,0x2d2d2d ,0}]},
	{"Comment"	, [{clNavy	,clYellow	,2}, {clVgaLightGray	,clVgaLowBlue	,2}, {clC64LGrey	,clC64Blue	,0}, {0xf75Dd5	,0x442d44 ,2}]},
	{"Directive"	, [{clTeal	,clWhite	,0}, {clVgaHighGreen	,clVgaLowBlue	,0}, {clC64Green	,clC64Blue	,0}, {0x4Db5e6	,0x2d4444 ,0}]},
	{"Identifier1"	, [{clBlack	,clWhite	,0}, {clVgaYellow	,clVgaLowBlue	,0}, {clC64Yellow	,clC64Blue	,0}, {0xc7c5c5	,0x2d2d2d ,0}]},
	{"Identifier2"	, [{clGreen	,clWhite	,0}, {clVgaHighGreen	,clVgaLowBlue	,0}, {clC64LGreen	,clC64Blue	,0}, {clGreen	,0x2d2d2d ,0}]},
	{"Identifier3"	, [{clTeal	,clWhite	,0}, {clVgaHighCyan	,clVgaLowBlue	,0}, {clC64Cyan	,clC64Blue	,0}, {clTeal	,0x2d2d2d ,0}]},
	{"Identifier4"	, [{clPurple	,clWhite	,0}, {clVgaHighMagenta	,clVgaLowBlue	,0}, {clC64Purple	,clC64Blue	,0}, {0xf040e0	,0x2d2d2d ,0}]},
	{"Identifier5"	, [{0x0040b0	,clWhite	,0}, {clVgaBrown	,clVgaLowBlue	,0}, {clC64Orange	,clC64Blue	,0}, {0x0060f0	,0x2d2d2d ,0}]},
	{"Identifier6"	, [{0xb04000	,clWhite	,0}, {clVgaHighBlue	,clVgaLowBlue	,0}, {clC64LBlue	,clC64Blue	,0}, {0xf06000	,0x2d2d2d ,0}]},
	{"Label"	, [{clBlack	,0xDDFFEE	,4}, {clBlack	,clVgaHighCyan	,0}, {clBlack	,clC64Cyan	,0}, {0xFFA43B	,0x2d2d2d ,2}]},
	{"Attribute"	, [{clPurple	,clWhite	,1}, {clVgaHighMagenta	,clVgaLowBlue	,1}, {clC64Purple	,clC64Blue	,1}, {0xAAB42B	,0x2d2d2d ,1}]},
	{"BasicType"	, [{clTeal	,clWhite	,1}, {clVgaHighCyan	,clVgaLowBlue	,1}, {clC64Cyan	,clC64Blue	,1}, {clWhite	,0x2d2d2d ,1}]},
	{"Error"	, [{clRed	,clWhite	,4}, {clVgaHighRed	,clVgaLowBlue	,4}, {clC64Red	,clC64Blue	,0}, {0x00FFEF	,0x2d2dFF ,0}]},
	{"Binary1"	, [{clWhite	,clBlue	,0}, {clVgaLowBlue	,clVgaYellow	,0}, {clC64Blue	,clC64Yellow	,0}, {0x2d2d2d	,0x20bCFA ,0}]},
];

mixin(format!"enum SyntaxKind:ubyte   {%s}"(syntaxTable.map!"a.kindName".join(',')));
mixin(format!"enum SyntaxPreset {%s}"(syntaxPresetNames.join(',')));

static foreach(m; EnumMembers!SyntaxKind) mixin("alias sk* = SyntaxKind.*;".replace('*', m.text));

__gshared defaultSyntaxPreset = SyntaxPreset.Dark;

//todo: slow, needs a color theme struct
auto syntaxFontColor(string syntax){ return syntaxTable[syntax.to!SyntaxKind.to!int].formats[defaultSyntaxPreset].fontColor; }
auto syntaxBkColor  (string syntax){ return syntaxTable[syntax.to!SyntaxKind.to!int].formats[defaultSyntaxPreset].bkColor  ; }

auto syntaxFontColor(SyntaxKind syntax){ return syntaxTable[syntax].formats[defaultSyntaxPreset].fontColor; }
auto syntaxBkColor  (SyntaxKind syntax){ return syntaxTable[syntax].formats[defaultSyntaxPreset].bkColor  ; }

//opt: slow, needs a color theme struct, and needs an enum for the syntaxkind.
//todo: this is a good example for table view in DIDE2

deprecated auto clEmptyLine(){ return mix(syntaxBkColor("Whitespace"), syntaxBkColor("Whitespace").l>0x80 ? clWhite : clBlack, 0.0625f); }

auto clCodeBackground	(){ return syntaxBkColor("Whitespace"); }
auto clCodeFont	(){ return syntaxFontColor("Identifier1"); }
auto clCodeBorder	(){ return mix(syntaxBkColor("Whitespace"), syntaxFontColor("Whitespace"), .4f); }
auto clGroupBackground(){ return mix(syntaxBkColor("Whitespace"), syntaxFontColor("Whitespace"), .1f); }
auto clGroupBorder    (){ return mix(syntaxBkColor("Whitespace"), syntaxFontColor("Whitespace"), .4f); }
