module het.bitmap; /+DIDE+/

version(/+$DIDE_REGION+/all)
{
	//This is the new replacement of het.image.d
	
	pragma(lib, "gdi32.lib"); 
	
	//Todo: icons have a black background since windows update installed near 22.11.15
	
	import het; 
	
	private mixin asmFunctions; 
	
	enum smallSpace = "\u2008"; 
	
	__gshared size_t BitmapCacheMaxSizeBytes = 512<<20; 
	/+251017: lowered from 768MB to 512MB. Vulkan texture pool ditto.+/
	
	__gshared BitmapLoaderUsesTaskPool = true /+251005: default: true+/; 
	
	import std.uni: isAlphaNum; 
	import core.sys.windows.windows :	HBITMAP, HDC, BITMAPINFO, GetDC, CreateCompatibleDC, CreateCompatibleBitmap, 
		SelectObject, BITMAPINFOHEADER, BI_RGB, DeleteObject, GetDIBits, SetDIBits,
		DIB_RGB_COLORS,	HRESULT, WCHAR, BOOL, RECT, IID,
		BITMAP, GetObject; 
	
	//turn Direct2D linkage on/off
	version = D2D_FONT_RENDERER; 
	
	enum BitmapQueryCommand
	{ access, access_delayed, finishWork, finishTransformation, remove, stats, details, garbageCollect, set, access_delayed_multi} 
	
	/+
		{ //handle thumbnails
			immutable thumbStr = "?thumb";
			// ?thumb32w		 specifies maximum width
			// ?thumb32h		 specifies maximum height
			// ?thumb32wh	  specifies maximum width and maximum height
			// ?thumb32	  ditto
			//todo: ?thumb32x24  different maxwidth and maxheight
			//todo: keep aspect or not
			//todo: ?thumb=32w is not possible because processMarkupCommandLine() 
			//     uses the = pro parameters and it can't passed into this filename.
			//todo: cache decoded full size image
			//todo: turboJpeg small size extract
		
			string thumbDef;
			if(fn.split2(thumbStr, fn, thumbDef, false/+must not strip!+/)){
				//get the original bitmap
				auto orig = newBitmap_internal(fn, mustSucceed);
				if(orig is null) return orig; //silently failed
		
				//get width/height posfixes
				bool maxWidthSpecified, maxHeightSpecified;
				while(1){
					if(thumbDef.endsWith("w")){ maxWidthSpecified	= true; thumbDef.popBack; continue; }
					if(thumbDef.endsWith("h")){ maxHeightSpecified	= true; thumbDef.popBack; continue; }
					break;
				}
				const maxAllSpecified = maxWidthSpecified == maxHeightSpecified;
				if(maxAllSpecified)
					maxWidthSpecified = maxHeightSpecified = true;
		
				auto value = thumbDef.to!int;
				enforce(value>=1);
		
				float minScale = 1;
				if(maxWidthSpecified ) minScale.minimize(float(value) / orig.size.x);
				if(maxHeightSpecified) minScale.minimize(float(value) / orig.size.y);
		
				if(minScale < 1){
					ivec2 newSize = round(orig.size*minScale);
					//print("THUMB", fn, thumbDef, "oldSize", orig.size, "newSize", newSize);
					orig.resize_nearest(newSize); //todo: mipmapped bilinear/trilinear
					return orig;
				}
		
				return orig; //todo: same size as the original... stored 2x in the texture. Not effective.
			}
		}
	+/
	
	struct BitmapCacheStats
	{
		size_t count; 
		size_t allSizeBytes, nonUnloadableSizeBytes, residentSizeBytes; 
		Bitmap[] bitmaps; //pnly when detailed stats requested
		
		string toString()
		{
			auto res = 	format!"BitmapCacheStats: count: %6d  residentSize: %4s allSize: %4s"
				(count, residentSizeBytes.shortSizeText!1024, allSizeBytes.shortSizeText!1024); 
			
			if(bitmaps.length)
			res ~= "\n" ~ bitmaps.sort!((a, b) => a.file < b.file).map!text.join("\n"); 
			
			return res; 
		} 
	} 
	
	//A tool to import raw bitmap fonts. Result is a hexString literal.
	string importFontMap_raw(ubyte[] raw, ivec2 charSize)
	{
		enforce(charSize.x.inRange(2, 16)); 
		enforce(charSize.y.inRange(1, 100)); 
		const 	paddedWidth = charSize.x.alignUp(8),
			rowBytes = paddedWidth/8,
			charBytes = paddedWidth/8*charSize.y,
			N = raw.length.to!int/charBytes; 
		
		ubyte[] res; 
		foreach(ci; 0..N)
		foreach(y; 0..charSize.y)
		foreach(x; 0..charSize.x)
		{
			const xi = paddedWidth-1-x; 
			res ~= ubyte((
				raw[
					ci * charBytes + 
					y * rowBytes + xi/8
				]
				.getBit(xi%8)
			)?(255):(0)); 
		}
		
		auto img = image2D(charSize.x, charSize.y*N, res); 
		auto compr = img.serializeImage("webp quality=999"); 
		auto hexLiteral = `x"`~compr.toHex.chunks(80).join('\n').text~`"`; 
		return hexLiteral; 
	} 
	
	//Load a bitmap immediately with optional error handling. No caching, no thumbnail/transformations.
	auto newBitmap(File file, ErrorHandling errorHandling, Flag!"fx" fx = No.fx)
	{
		
		const hasFx = !file.driveIs("font") & file.hasQueryString; 
		
		if(hasFx && !fx) WARN("newBitmap fileName has fx but fx flag is not set. "~file.text); 
		
		static Bitmap newBitmap_internal(File file)
		{
			enum mustSucceed=true; //This function either must return a non-null bitmap or throw an exception.
			auto fn = file.fullName; 
			auto prefix = fn.until!(not!isAlphaNum).text; 
			if(prefix.length>1 && fn[prefix.length..$].startsWith(`:\`))
			{
				//strip off prefix:\ and call a loader with the remaining text
				fn = fn[prefix.length+2..$]; 
				auto loader = prefix in bitmapLoaders.functions; 
				if(!loader) raise("Unknown BitmapLoader prefix: "~prefix~`:\`); 
				return (*loader)(fn).enforce("Unable to load bitmap (null returned by loader): "~fn.quoted); 
			}
			else
			{
				//threat it as a normal file
				auto bmp = File(fn).deserialize!Bitmap(mustSucceed); 
				bmp.modified = File(fn).modified; 
				return bmp; 
			}
		} 
		
		Bitmap res; 
		final switch(errorHandling)
		{
			case ErrorHandling.raise: {
				try { res = newBitmap_internal(file); }
				catch(Exception e) { throw e; }
			}	break; 
			case 	ErrorHandling.track,
				ErrorHandling.warn: {
				try { res = newBitmap_internal(file); }
				catch(Exception e) { WARN(e.simpleMsg); res = newErrorBitmap(e.simpleMsg); }
			}	break; 
			case ErrorHandling.ignore: {
				try { res = newBitmap_internal(file); }
				catch(Exception e) { res = newErrorBitmap(e.simpleMsg); }
			}	break; 
		}
		
		if(hasFx && fx) res = applyEffects(res, file); 
		
		//bitmap.name is always the same as the name passed to this loader
		res.file = file; 
		
		return res; 
	} 
	
	auto newBitmap(File file, Flag!"fx" fx = No.fx)
	{ return newBitmap(file, ErrorHandling.track, fx); } 
	
	Bitmap newBitmap(HBITMAP hBitmap)
	{
		Bitmap res; 
		BITMAP bmp; 
		ivec2 size; 
		int bits; 
		if(GetObject(hBitmap, BITMAP.sizeof, &bmp))
		{
			size = ivec2(bmp.bmWidth, bmp.bmHeight); 
			bits = bmp.bmBitsPixel; 
			
			__gshared HDC hdcMem; 
			if(!hdcMem) hdcMem  = CreateCompatibleDC(GetDC(null)); 
			
			BITMAPINFO bmi; 
			with(bmi.bmiHeader) {
				biSize	= BITMAPINFOHEADER.sizeof; 
				biWidth	= size.x; 
				biHeight	= -size.y; 
				biPlanes	= 1; 
				biBitCount	= 32; 
				biCompression	= BI_RGB; 
				biSizeImage	= size.x*size.y*4; 
			}
			
			auto img = image2D(size, RGBA(0)); //Todo: uninitialized image, or copy manually
			if(!img.empty)
			{
				if(!GetDIBits(hdcMem, hBitmap, 0, size.y, img.asArray.ptr, &bmi, DIB_RGB_COLORS))
				raiseLastError; 
				img.asArray.rgba_to_bgra_inplace; 
			}
			
			res = new Bitmap(img); 
		}
		return res; 
	} 
	
	//Todo: ezt is bepakolni a Bitmap class-ba... De kell a delayed betoltes lehetosege is talan...
	auto isFontDeclaration(string s)
	{ return s.startsWith(`font:\`); } 
	
	private Bitmap newSpecialBitmap(string error="")
	{
		const loading = error=="loading"; 
		auto bmp = new Bitmap(image2D(1, 1, loading ? RGBA(0xFFC0C0C0) : RGBA(0xFFFF00FF))); 
		bmp.markChanged; 
		if(loading) { bmp.loading = true; }else { if(error) bmp.error = error; }
		return bmp; 
	} 
	
	Bitmap newErrorBitmap(string cause)
	{ return newSpecialBitmap(cause); } 
	private Bitmap newLoadingBitmap()
	{ return newSpecialBitmap("loading"); } 
	
	/// Gets the modified time of any given filename. Including real/virtual files, fonts, transformed images, thumbnails
	/// returns null if unknown
	//realhet
	auto getLatestModifiedTime(in File file, Flag!"virtualOnly" virtualOnly = Yes.virtualOnly/*Todo: preproc*/)
	{
		if(file) {
			auto drive = file.drive; 
			if(!virtualOnly || drive!="virtual:") { return file.withoutQueryString.modified; }
		}
		return DateTime.init; 
	} 
	
	
	mixin template PluginTemplate(string name, string postfix, alias Function_, alias UDA)
	{
		static: 
		
		alias Function = Function_; 
		
		private __gshared Function[string] functions; 
		
		void register(string prefix, Function fun) //Todo: make it threadsafe
		{
			enforce(prefix.length>=2, "Invalid prefix string."); 
			//Note: prefix names are case sensitive. File drives are NOT.
			if(prefix in functions) WARN(name ~ " already registered . Prefix: "~prefix); 
			functions[prefix] = fun; 
			static if((常!(bool)(0))) LOG(name ~ " successfully registered:", prefix); 
		} 
		
		void registerStaticFunction(alias fun)()
		{
			static assert(__traits(isStaticFunction, fun)); 
			enum name = __traits(identifier, fun); static assert(name.endsWith(postfix)); 
			enum prefix = name.withoutEnding(postfix); /+static assert(prefix == prefix.lc);+/
			register(prefix, toDelegate(&fun)); 
		} 
		
		void registerMarkedFunctions(alias obj)()
		{
			foreach(name; __traits(allMembers, obj))
			{
				alias member = __traits(getMember, obj, name); 
				static if(
					__traits(isStaticFunction, member) && hasUDA2!(member, UDA)
					&& __traits(compiles, mixin(iq{{ Bitmap b = .$(name)("a"); }}.text))
				)
				registerStaticFunction!member; 
			}
		} 
	} 
	
	struct BITMAPLOADER; //uda
	struct bitmapLoaders
	{ mixin PluginTemplate!("BitmapLoader", "Bitmap", Bitmap delegate(string), BITMAPLOADER); } 
	
	struct BITMAPEFFECT; //uda
	struct bitmapEffects
	{ mixin PluginTemplate!("BitmapEffect", "Effect", Bitmap delegate(Bitmap, in QueryString), BITMAPEFFECT); } 
	
	
	
	
	@BITMAPLOADER
	{
		/+
			Note: HETLIB Resource Identifier format specification
			
			/+Code: customLoaderId:\+//+Code: drive:\path\name.ext+//+Code: &opt1&opt2=val+//+Code: ?opt3&opt4=val+/
			
			* optional custom loader:	/+Code: customLoaderId:\+/ (a..z are reserved for drive letters)
			* required filename:   	/+Code: dirve:\path\name.ext+/ or /+Code: http://a.com/index.html+/	
			* optional resource options: 	/+Code: &name&key=value& ...+/ (up until this it can be processed as a queryString)
			* optional queryString:	/+Code: ?name&key=value& ...+/ (this is thequeryString after the ?)
			
			Restrictions: ⚠Some CustomLoaders are using '&' to locate their parameters. Avoid using '&' in those filenames!
			
			Custom loaders:
			
			/+Code: font:\+//+Code: Times New Roman\64\x3\ct+//+Code: &ABC 123+/   Note: No queryString is processed after font:/
			path elements:
				 * fontname:	(req.)
				 * number:	(req.) height in pixels
				 * x2:	horizontal resolution: double
				 * x3:	horizontal resolution: triple
				 * ct	ClearType (otherwise: RGB)
				& marks the beginning of the text to be rendered.
				⚠No ?queryString is processed after the "font" customloader. <- This is an odd behavior.
				/+Todo: Encode special with url percent encoder  %20, ....  &, ?, % must be encoded at least.+/
			
			/+Code: temp:\+//+Code: custom filename+/
			A new bitmap is created and returned.
			The bitmap is resident in memory, it will never be deallocated upon GC.
			Application must ensure thread safety or create a new bitmap and update it with bitmaps.set(...).
			
			/+Code: virtual:\+//+Code: custom filename+/
			Virtual files are not just bitmaps, they are stored in memory. 
			Bitmap system can access them like OS files. 
			Most File() operations are working on them and they generate automatic change/refresh cotifications.
			
			/+Code: desktop:\+/ Captures the current desktop image.
			/+Code: monitor:\+/ Captures the current main monitor image.
			
			/+Code: clipboard:\+/ Reads the bitmap from the clipboard, if there is one.
			
			/+Code: debug:\+/ 	Some kind if calculated test patterns.	/+Todo: These are the example of why a plugin system is needed here.+/
			
			/+Code: icon:\+//+Code: .bat+/	extension icon
			/+Code: icon:\+//+Code: c:\+/	dive icon
			/+Code: icon:\+//+Code: folder\+/	general folder icon ("folder" is a literal text, not a specific, existing folder)
			options:
				* /+Code: &large+/, /+Code: &32+/ (default)
				* /+Code: &small+/, /+Code: &16+/
				
			/+Code: cmap:\+/ Generates a palette from a named Python matplotlib ColorMap. Example: viridis
		+/
		
		Bitmap fontBitmap(string name)
		{
			//Todo: font and icon should be put in a list that ensures the following: bitmap.resident, no delayed load
			version(D2D_FONT_RENDERER)
			{
				auto res = bitmapFontRenderer.renderDecl(`font:\` ~ name); 
				if(res.valid) res.resident = true; //dont garbagecollect fonts because they are slow to generate
				return res; 
			}
			else {
				enforce(0, "No font renderer linked into the exe. Use version D2D_FONT_RENDERER!"); 
				return null; 
			}
		} 
		
		Bitmap tempBitmap(string name)
		{
			auto b = new Bitmap; 
			b.resident = true; 
			b.modified = now; 
			return b; 
		} 
		
		Bitmap virtualBitmap(string name)
		{
			//Just forward it to the fileSystem, that will handle the 'virtual:\' prefix.
			return File(`virtual:\` ~ name).deserialize!Bitmap(true); 
			
			//Todo: this forwarding should only be don inside the filesystem.
		} 
		
		Bitmap desktopBitmap(string name)
		{ return getDesktopSnapshot; } 
		
		Bitmap monitorBitmap(string name)
		{
			//Todo: monitor indexing
			return getPrimaryMonitorSnapshot; 
		} 
		
		Bitmap clipboardBitmap(string name)
		{
			if(clipboard.hasBitmap)
			{
				Bitmap res; 
				clipboard.getBitmapHandle((HBITMAP hBitmap){ res = newBitmap(hBitmap); }); 
				if(!res) raise("Clipboard has no bitmap."); 
				return res; 
			}
			
			return null; 
		} 
		
		Bitmap debugBitmap(string name)
		{
			//debug images
			uint color = (name.to!int)>>1; 
			color = color | (255-color)<<8; 
			return new Bitmap(image2D(1600, 1200, RGBA(0xFF000000 | color))); 
		} 
		
		Bitmap iconBitmap(string name)
		{
			//folder: icon:\folder\    //"folder" is a literal!!!
			//drive: icon:\d:\
			//file: icon:\.bat
			//Todo: not works for individual files
			
			//Todo: LoadIcon from dll/exe
			
			//options: ?small ?16 ?large ?32
			
			auto res = getAssociatedIconBitmap(
				name.replace('&', '?')
				/+Todo: This is a nasty and inefficient  hack+/
			); 
			if(!res) raise("Unable to get associated icon for " ~ name.quoted); 
			
			if(res.valid) res.resident = true; 
			return res; 
		} 
		
		Bitmap cmapBitmap(string name)
		{ return cmapRawData[name.to!cmap].deserialize!Bitmap(true); } 
		Bitmap fontmapBitmap(string name)
		{
			Bitmap load(string bin)
			{
				auto bmp = bin.deserialize!Bitmap(true); 
				bmp.set(image2D(bmp.size, bmp.access!RGB.asArray.map!"a.g".array)); //convert 24 -> 8bit
				return bmp; 
			}  Bitmap inverseDuplicate(Bitmap bmp)
			{
				auto half = bmp.access!ubyte.asArray; //generate the chars at 128..255 from inverse of 0..127
				bmp.set(image2D(bmp.width, bmp.height*2, half ~ half.map!((a)=>((cast(ubyte)(~a)))).array)); 
				return bmp; 
			} 
			
			switch(name)
			{
				case "VGA_9x16": 
				return load(
					/+
						source: Bm437 Trident 9x16 
						/+Link: https://int10h.org/oldschool-pc-fonts/fontlist/font?trident_9x16+/
						tool: 'Fony' font editor
						import script: /+Code: importFontMap_raw(File(`c:\dl\Bm437 Trident 9x16.bin`), ivec2(9, 16));+/
					+/
					x"524946468E060000574542505650384C820600002F08C0FF030F30FFF33FFFF31F78B0ACFE9F1BCB
CEB769D0DC20CE8DB6CB1CD1EDBC1608E4032D6AF2ACBCCD511781DAB1A7E1A60907C9D97E857900
C757C83987ED405A3AE79C059AAAFFFF5FED1788E8BF04B7911C49E201EBCE4546D42BE00018F830
9FE6C3B32F732BF8F1A0E69AB8C334FB263F679A0DA0AA19239E828740F510053E2195A399FD3C70
0B4763CA354417BB389739BD03D124FA39DF0C9B132168E8B930EB698CB9BFC92DBE1C2CF34D35F7
35F6BC8537B0A28AAC40BB28D2E0A2E610FD871FF11FF2C8118F710644FFE33B0F3E447EC6CFD9B2
D41A9FDD09966BB8A3DEB560C9191E63CDC83AB869C90204E768D9738D53464E830E5BCE99567791
C1B06D2F0B73A8BDDD09DCE7B60081A723A3A0A69BD514947478301A4307E865B0E492195673B65E
D5742523250E8C7232463272305A4646307A0D3D133DAF01938728667E36329AF7F0F820DD43904E
DFED8178117597EF042E41927A36524B3F5636F5745C6489A7E5193ABC6179B848176C9A93D1F10C
888AE092821D1BAAC04EDE3B90815D788FC851AA2FC651C6A29418F4344C34F4F6F56693DC684A3E
F365301DE69D186F3B472BECB66401224F377B96F7CFB6C15FF3EA1D052B9C68D0732B57758CA65C
2D4DF04D6BB8ABE484869A8A9132700D4423CBC059F6C6DC055994AB8B782D7778B7FCBE4CBD7778
6B6E21CF401BE55FD9B696574FCE95834C5C2DC751D282C9187FA38BF34AF94DBD95E19B899B3125
BB19D8B0547B7F88823A4836D245109DA50F78FAC8591035F45C6419B9484F03A23535BDA866ADF6
DD738597B2E2A5645CA1674CC91578CC7CF7CDA0B39E7780A8A3535BEDD4DC4EA3F6768D52500556
20DA065DD6AC58450D6F41F41859CCD8EB37F939137766DF8CA9BD6DB9CAC84D9EB5F516BE1A514D
617E37997137AFA47E3F37F194EC2DB985F7B335E5CE282869E9661E2441A7B79276ED0CBC96CBD0
EA43DA6E823BB3899EDE90BB0EF216D4D486DDFA4863EE65E29B7C9D961247CE27F82613884EC955
A7A058B0E40C47149CB0A7E59C9ABBD588B91F8A5E15FF071340D08283835851E2A9023B109D219B
ADA8E9231B30F0742C1F30BC9B13CA59434D15DF65CE3D1A7317D4BC8E8CC7C8228F81C18E4AE029
A95829BDD5ECE8235B10391C50E0CCEFAE9DC19E5612A46F94BB7A6A56ACA8B5BBA48BB4BB0CB64C
DC1160B0A197587713F8E4DC3E5C2F71B7926B6AEE1D57E2DDCD7767149486BB1F229F9D258F7C80
1330A8443B30E8050D0E0CBE19B8339B8CBB74D414819ACE964B34D052B206D148852327A36304D1
1E1738C245F62089D3487F44EB4DC8BB17521DA92F6203C91E8AFAEC0CAD4043CF4596818BC16E25
2D5E5E3C69F712471EBDAB31C8DEE10D17C38A126F7C37155552AE8C1C97922BB8AAB0DC65EA3623
135A6DB45EF4DEF417A7E7D27B49CCDDCFA0C0091AE5D535965CFA5D49B93A3AF1558DE1DBD25749
C8E5C8C98031D8C547DB8C60F00277B9CDC0311B7E07A253EA60ED912AF22CD8760DD9769573D976
4DCA95B3A2022AD14ECFADE732DDDD89065A4A5671AA78B7484D614B6DEEC5452F2B8B366D822428
2FE375643C4616D9721644DF8CD20EE10735F759FA99E70A3D7FA30FFC14047B6E4759079CE09823
A1979C0C5851E24DBB94413228C4D40D809C5B7F177AAEC4DD776C800DBD44CDD4B1E52A23377936
BA0C41433D3B05063029825C05E0C128278FBEC958C6BD998C2C239873B5112441CE8B7454D102CF
F27D5A4AFE61CCD5F32C6FE53FB4FC415CCE41BC78C081C18FE8A9E8F9111855F45136449FE25589
1FBEC01B133F7C91DF257E7007B64ECB64CCF501C5553EA0D15F464AAE03DC7595F6C15D8726DF6C
CBADDE358246CB66C965D885446B5CA27F2C0C7729A605A49916C977E9B9F4DC07B83BED26D35DEA
6EBF5988BB1B32E5FC27A5D739539E98FBF70BB53753A7BF4FBBDB76979CDB76977CB7ED2E69337B
6ED9017A9B0EF06E3E4012CBAE86770366D677A5BF8DE4BBA7C45DC20F69D690C6D4CBB448A5EFA6
7B8C547F5824325C9962C786E3C0861D189CA50B3E749C651920320669960A540B466A11004AF28C
1C474E46C7080603C7822350F5024F365B9A5A7512C34D8E26CADDE018405150D3D1450DD714C654
1D75E445105D0B1A2D3915BA698CBDDE090C60F0355A06FECC1D7ECA6068F5843CE8DA9305724E40
E1E954FAAF51FBC6C0CD2661B1096451AF2D65F072D0BB8BF264613E43AE3DB767EE30ECEF2E6A64
8AFF88C98E4DFC8DE1D5D414902EBCE900C950FD8152F0FAE0C6467917C7D4024C8E7879B0D953AC
218157703800"
				); 
				
				case "CGA_8x8": 
				return load(
					/+
						source: Bm437 Trident 8x8 
						/+Link: https://int10h.org/oldschool-pc-fonts/fontlist/font?trident_8x8+/
						tool: 'Fony' font editor
						import script: /+Code: importFontMap_raw(File(`c:\dl\Bm437 Trident 8x8.bin`), ivec2(8));+/
					+/
					x"524946467C040000574542505650384C6F0400002F07C0FF010F30FFF33FFFF31F7806CAEEFFB76D
A4FF40003D85B0B72F67A3A1B69F9A160434062C48DBFBB5D72C04C85B0227DB5B20611E230FB0F5
017ADF99D9D39CB7B753EFBD053110FF9967F8FD22FA0FC16D234792375CBEA2FD0C89D21D7A1A6F
6C1CEA38FF8487BF9E77454F56E96E615AA9FB6995F6BC667715412A812B09C19C5F1F06E794B2BD
142C657E78E30DE2F0FC972FF966207DD992A5EBB0796CD372381A6CBD07F2AB69B2716BF9354B6C
EC1A647D36805CBCB6DE63ED62716507B0444B92426C7D82CF3F2465FDBDB420EEAED546A4F2B1C4
5C390171505C81CB7B3801ACE98D058084EC019CDDCEDBB38105784E01C805738738121027050900
20FBED37C27549B55C3B41139C6D1B490BCC26016269B4D71AD2428C75008DA02DE7650BC0A103E2
52B00274C00E0E59CE9D35C92EA91E7A6A75DA54628724598B0F796A82BE9FD3CBB82C429F3F2E75
92E50B476A922CD04B1D726749F1818B2FC0C02A774381C3CEDFB6A0498C85AA4D60B1CFA2B1946D
AE76AE9AA730492AB13EB026A56E5991B5946D42B625B2A2258B0CFD95A7F853AEECF57D3352AE87
DADB25282EC55B92F4783C0702BD4CDBC217ED1423435ED9F6D23C46DEDF409AE9EA530F3590B468
00A6AAA7E148AA06B8BF5A538E85B76A067E0D95D4E7EB3E41A5D6F7BD45B370F6852CF06C204A43
8FBEB9C85DDFF6E20D497A2C46CF972F16EF0080B23B2D1AD921985B3AD1F17915663230AC5A4E04
F021091EE31C55E04C39EAC44B5A9C3B328400B3C02ACF06A698B59C8AC550ED932FA4817E60DAC2
1753A521BD00A1E7FD04702090543D480F60D2B232A3A8C7E382C9EC4AD5AB4A86E34C76DB9A3CCF
0910A8FBEBDD01BD3BD0504F19D40E827ABF3DB796B1E5C0720C07A86F0F2C1714CC26A2B33B2D1A
F4523509AA7CB99200D56B1CEDDB1D2A97D7DB4F25C0E75598C920BA6FA9EF6321F679BAED6B3B53
4A88BC83E87E508B7BA92E491D50CA207234BBABA607C47201A48C511B6F20C056BE1520EB45E803
1F127F8630D00321BA3FD0F77986DE0783E83EA1F63EECCA9625F47CF470E81276405A9C3B32D35A
02BDAD0966817735BF3787D73E7425B0341C477BA6D12E18473DC751AF0C070229B5F0603D095216
5C970E480B422A811307DB9602A04E28EA7E0E41139656DEBFEC8C5F0E37E1931F5EFCFDED85AF24
04C7DAD04280D01E63105C7EBC7E7BE106FDF6DA4FFACDED980C004010C00AC9D5155200F4EA7EEC
595DE6CA0EA1A08F1CABE8055821D903507ED1A1D3F9477980B9E830F63840396257A4F927EAFF83
EAF583DD54DA4D6AC7CFA2FDC4CFDAA53C82390860DBA53C0EB1838C9D8C7B46DB6D0AA07A2A97EE
AB1A5267AEFD207432412404E6510400498EA2FC12253601B3C9899C097CC84296107548480AD017
245107634D8000DD123914B4242B936C731D00A9AD0FF41669D1F4285249D9807C4CC6D655815E80
EE1350B09CF313D024A949B2C4407C50013A10041C080861ACA3915A9C351652CBDA87743B648943
857358CC25330AD282101D871820C02F3970B028C7A7A9F580E17E6B32A52A49220E0000"
				); 
				
				case "EverexME_5x8": 
				return load(
					/+
						source: Bm437 EverexME 5x8 
						//Link: https://int10h.org/oldschool-pc-fonts/fontlist/font?everexme_5x8
						tool: 'Fony' font editor
						import script: /+Code: importFontMap_raw(File(`c:\dl\Bm437 EverexME 5x8.bin`), ivec2(5, 8));+/
					+/
					x"5249464682030000574542505650384C760300002F04C0FF010F30FFF33FFFF31F78060AB66DD76D
9B0BE8F103CA06ACD4CACF8E39FF69960F1EC3B911FD87E0B69123C91B2E5FD17E86A6F4C7C7E37C
A27E3ECFC7073A4EDB3D44F4E91F859F7405FD7474417442D81F0F7F9C8638C88EA7FF777CFE7EAF
0B4E1A7AE8F3FD33D6ED76DD7FFFF9DF6FC5F3F8E0192AB76DF856F4F6FBF38BDF6F57CDC03D0E00
1DFA7AFAE73BE8E5471CD156A50C92CF3D4C0F0005401A683F770451CF8A80C299B087514A742CDC
094D995644A105313113B4F6B2EE5B15B4701371043F9B1575F2FA0A720058B475B809821E28A7BA
0886E6D8EC0E2ECEDA5EEFB02A0CD0E5B6472D23DD77F22C8C40A36C7B72D4B25DCE71F96CAD0D83
E546DFBD0A2A18C0B96FB838F51FB9B863A72AF542A1FEF8F7A45C7D190DB4350CD6DA0A345F0EC0
1A05C398EE73B95E1BABDAECAD5736F62B9767B999864ACA50D281DADDAF06AD0DC8BDA61E705F7A
722CC955BC5FAE9A4203A69EE0E9FE686AD8801E3E02D0D8A316867AE2A26207BBB50580B5367D9F
B33A94B3EEBD7515B6B43357F366EDEE0D7A726C65551C75AB7672D0F7B5B0DC1BA892F7D9B1DD58
0BAF69BF5BE26C401B0D046E4076E3EC7041F4AB87C5722F20E865DD37D554F30568F07A08F2EE90
7787664376F47D13236A197AA9BE5DDE6A639B5BF002371D8B72E278F89CD6DD57B5A957FB665FEF
BD7535E5FB35F2FD353B12B847D5DA92F31B6F8D7C9F26075D9EEED7D0AD7A4BBED1909D008A3ACA
C610DCDFFBF2579F473BE18FEAA2B591FD0DABC6747F519B1C6D7235FABE261ED37E58442FF4501C
75AB6DE8719C61D0D6CCBFFF7BEDEFD163A90AE71DA3E67DD294585173AFE3555B83EBFEFDB5A175
E91A0237A7FBA1A0B655701604E037036DA9ECD1AFFBEDE56B57C5DE5C811F8D1F02DA0FDAA5C86F
C733BF7D74FFBABE5DBFCD2DFF59BA7F007740C048F767CF7DBFF34D106372781F82031882E427C7
35E72B79EC931CCF9E6A27C7EC9A345F53FFBF0038B9C1353B3E9213CC4776258F3871EAFF913CD5
B30366A7E79E474EDEE36BEEF5CD0E5F93EBCCFE690F7FB3E7E53BA700D8F636E573CA6C82B763E1
AF58DB860BA31500C1793F40A3D5701B82BE80F352DD45FC5D02C45617BC5DEED1B0E80F5FDBAEA5
AEC9C1F134827D7DBDAF45F4324A17B8018891DE207AA88B52C34543E1E2B8EE1FD8B60248BD5786
529DE5FA02372BC7DF00005E029635745B4080A36E4AB1CD3701"
				); 
				
				case "C64_lower": 
				return inverseDuplicate
				(
					load(
						/+
							source: /+Link: https://www.pagetable.com/c64ref/charset+/
							import script: /+Code: importFontMap_raw(File(`c:\dl\c64_us_lower.bin`).read, ivec2(8)).print; +/
						+/
						x"5249464614020000574542505650384C070200002F07C0FF000F30FFF33FFFF31F78063A926DBB76
9B4377E95E81E921257D4DE1C9BB534F194AC378722792F991ECAF5B9A066783081163C48A14B214
7AB8772E3885B523FAEFC86D1B49F2ADB719AA9E11F983DA7118683D2446D392C2209A14B0724861
10D95BC0DE0F0E061B675DAA5386DBEBCEE6B4159035BDBF7B3FD934C5439E73766AB0A4A4D22145
75D03474602C6A92C141B12E8677606F90AAFD92C20D4ECFCE0FDF1864B8B27A0EF3CEE8B34FDD62
92A460FE6C5A74FCA9C50C20C3D501ECC1748E1ED8B862C12DA5E2902EF22285977CB7E39C7DCA2F
2C325EFF23FFB375F6E29B7D92984D3E83CBC8B8882C211D6E889A0CFA8D91C6C93AFBD42CF287EF
5261CEEB0EDD22D7796AE5FF3F24C3D6FD4F79BE62BD2D2B19A66C4B2AACE75C8E2A5291C5A3C3E6
022F17E0A577CFD426F6255BC091CFEBEC47A5CF2BF0428047F6946C9190D8FAA40C76EFA7F4FE8E
DEB46BEAC3FF6B73FD900A52D51B0E20FB6906DE7FDDAEAD477A3FAD95754E5F9E9F49B2FCAEEB87
94454A5294CED25118FBE2D8BC912DD60CEB5E662969E894C2ED543A3B7F29DB104A59D180F575F6
A97573B810704793B6DB0C7BC13B0289E7CAEDB60D7B32CC800B49E215D39D61839A93610614CBF3
17B9DD1E3D0E7FE160C09F928AC3CADED4E08192577C803462BCACF8C6DEFBC37E1F36225F714292
7E3B59DFDF1DB51BCE726B36A0740C961B4D0200"
					)
				); 
				
				case "C64_upper": 
				return inverseDuplicate
				(
					load(
						/+
							source: /+Link: https://www.pagetable.com/c64ref/charset+/
							import script: /+Code: importFontMap_raw(File(`c:\dl\c64_us_upper.bin`).read, ivec2(8)).print; +/
						+/
						x"5249464616020000574542505650384C090200002F07C0FF000F30FFF33FFFF31F7806B9B26DBB6D
733D98015580A1BC85C22F3C278EC21DAAD3F833146FE5C0CA91F3EC4FCBAE5CAB6665751A968E50
C07DD02F9C13D17F466EDB46D2B19D45F233CC5FB23E30517A765266244888794DBA6173EAE47413
B9E666CD5CFC9F9DD74BA7C1197D4D3B28AF1380E9BADCBA8E3875A90319DF2FDB7392E2CF335F3A
C5BCC34267EC2069F3E0D1F99AD776E8265903E2248B4ED254BE93E7ED25C5694AA7041B40F261D2
A6CE624D87213D69663CD8174B1D1428438AAC352DB82625C105A10F1DE4955F39A18BDA0E672A07
9EB4F16331B7F59FFE4F0E9306BFA40D8924D40428056E57E62124033D518D00B93752F0310C24E6
2F9F3B4D14EB0A64313F4C61373FDC869B1CCE5F7B7B08C9F5EC106E42AF674E93EC294C654EF3E0
C345E70584F98AFFA399A3A91BCC4336018C341D261D853E8D82570430D95EB4E042B4A0F0B9FB43
3D0A4D412A1060305E5700DBAB6598767D3C10A00A5CB11A8CD6B7E7CB8FC47C7B7D34A8AE581A7D
0C886592D613F6B40516DB13A90B002C57DB8A2F17D9982F20969DD9A07002268705B7FB055F05AE
08A062C3EEB8674F7C5C3C7F4AB96AFFFD5A2D3F7E90827141CC26893B6055F0903F40021F0B0440
E771F57E7F6B3CA8EE953E0AFC42E8045624838704B6A840CFC040F0034096321A087E55C1A06059
504ADEB110C98F812B965BAE480A80D051B8F43A1100"
					)
				); 
				
				default: raise("Unknown fontmap: "~name.quoted); return null; 
			}
		} 
		
	} 
	
	
	
	
	
	
	
	struct BitmapTransformation
	{
		File originalFile, transformedFile; 
		size_t sizeBytes; //used by bitmapQuery/detailed stats
		bool isEffect; 
		
		this(File file)
		{
			transformedFile = file; 
			if(
				!file.driveIs(`font`)
				/+
					Todo: 🛑 Ez igy osszeutkozne.
					A fontban a kerdojel utan nem effekt van, hanem a karaktersorozat nyersen.
					Ezt a kivetelt meg kell szuntetni.
				+/
			)
			{
				if(file.hasQueryString)
				{
					originalFile = file.withoutQueryString; 
					isEffect = true; 
				}
			}
		} 
		
		alias needTransform this; 
		bool needTransform()
		{ return isEffect; } 
		
		Bitmap transform(Bitmap orig)
		{
			if(!orig || !orig.valid) return newErrorBitmap("Invalid source for BitmapTransform."); 
			
			sizeBytes = orig.sizeBytes; //used by bitmapQuery/detailed stats
			
			Bitmap doIt()
			{
				try
				{
					if(isEffect)
					{ return orig.applyEffects(transformedFile); }
				}
				catch(Exception e) WARN(e.simpleMsg); 
				return orig.dup; 
			} 
			
			//set filename and copy the modified time
			auto res = doIt; 
			res.file = transformedFile; 
			res.modified = orig.modified; 
			return res; 
		} 
		
	} 
	
	Bitmap applyEffects(Bitmap bmp, File effects)
	{ return bmp.applyEffects(effects.queryStringMulti); } 
	
	Bitmap applyEffects(R)(Bitmap bmp, R effects)
	if(is(ElementType!R==QueryString))
	{
		auto file = bmp.file; 
		
		foreach(qs; effects)
		{
			const prefix = qs.command; 
			if(prefix!="")
			{
				if(auto a = prefix in bitmapEffects.functions)
				{
					bmp = (*a)(bmp, qs); 
					
					//always update the proper filename of the bitmap. Some effects may use it.
					file = file ~ ("?" ~qs.text); 
					bmp.file = file; 
					bmp.modified = now; //As the effect just modified it.
				}
				else
				WARN("Unknown bitmapEffect prefix: "~prefix.quoted~" "~qs.text); 
			}
			else
			WARN("Missing bitmapEffect prefix: "~qs.text); 
		}
		return bmp; 
	} 
	
	
	@BITMAPEFFECT
	{
		/+
			Note: BitmapTransformers:
			
			/+Code: ?thumb+/
				* number: (req.) Is the size of the thumbnail image.
				* postfixes:
					* /+Code: ?thumb&d=n+/ float number, max width and height = original.size / n
					* /+Code: ?thumb&w=n+/ number specifies maximum width
					* /+Code: ?thumb&h=n+/ number specifies maximum height
					* /+Code: ?thumb=n+/ number specifies maximum width and height.
			
			/+Code: ?histogram+/	 Calculate RGB histogram of the image.
			/+Code: ?histogram&gray+/	 Calculate lumonocity histogram og the image.
			/+Code: ?grayscale+/	 Calculate grayscale image.
			/+Code: ?invertRGB+/	 Inverts RGB, leaves alpha as is.
		+/
		
		Bitmap thumbEffect(Bitmap original, in QueryString params)
		{
			if(original.size.area<=1) return original; 
			
			//Todo: If the original bitmap is refreshed, this bitmap should be also invalidated.
			//Todo: Find a way to weekly link this image to the original image to detect changes.
			
			ivec2 maxSize; 
			
			float divisor=0; 
			params("d", divisor); 
			if(divisor) { maxSize = iround(original.size / divisor); maxSize.LOG("D"); }
			
			params("thumb", (int a){ maxSize = ivec2(a); }); 
			params("w", maxSize.x); 
			params("h", maxSize.y); 
			
			float scale = 1; 
			if(maxSize.x>0) scale.minimize(float(maxSize.x) / original.size.x); 
			if(maxSize.y>0) scale.minimize(float(maxSize.y) / original.size.y); 
			
			//print(maxSize, original.size, scale, params);
			
			enum rationalScale = false; 
			if(rationalScale) scale = 1/floor(1/scale); //divide it to even parts
			
			if(scale<=.5f) {
				ivec2 newSize = iround(original.size*scale); 
				return original.resize_nearest(newSize); //Todo: mipmapped bilinear/trilinear
			}
			else
			{ return original.shallowDup; }
		} 
		
		Bitmap histogramEffect(Bitmap original, in QueryString params)
		{
			const isGray = params.names.canFind("gray"); 
			
			if(!isGray)
			{
				auto img = original.accessOrGet!RGB; 
				uint[3][256] histogram; 
				foreach(p; img.asArray) foreach(i; 0..3) histogram[p[i]][i]++; 
				uint histogramMax = histogram[].map!(h => h[].max).array.max; 
				float sc = 255.0f/histogramMax; 
				return new Bitmap(image2D(256, 1, histogram[].map!(p => RGB(p[0]*sc, p[1]*sc, p[2]*sc)))); 
			}
			else
			{
				auto img = original.accessOrGet!ubyte; 
				uint[256] histogram; 
				foreach(p; img.asArray) histogram[p]++; 
				uint histogramMax = histogram[].max; 
				float sc = 255.0f/histogramMax; 
				return new Bitmap(image2D(256, 1, histogram[].map!(p => cast(ubyte)((p*sc).iround)))); 
			}
		} 
		Bitmap grayscaleEffect(Bitmap original, in QueryString params)
		{ return new Bitmap(original.accessOrGet!ubyte); } 
		
		Bitmap invertRGBEffect(Bitmap original, in QueryString params)
		{ return new Bitmap(image2D(original.size, original.accessOrGet!RGBA.asArray.rgba_invert_rgb)); } 
	} 
	
	/+
		Todo: Implement this monitor, clipboard auto updater somehow.
		/+
			Code: spawn(
				{
					while(1)
					{
						static uint cSeq = -1; 
						if(cSeq.chkSet(clipboard.sequenceNumber))
						{ bitmaps.refresh(`clipboard:\`); }
						bitmaps.refresh(`monitor:\`); 
						sleep(100); 
					}
				}
			); 
		+/
		
	+/
	
	private BitmapCacheStats _bitmapCacheStats; //this is a result
	
	private __gshared File[] bitmap_access_delayed_multi_files; 
	private __gshared Bitmap[] bitmap_access_delayed_multi_bitmaps; 
	
	Bitmap[] bitmapQuery_accessDelayedMulti(File[] files)
	{
		//this must be called from main thread only!!!
		bitmap_access_delayed_multi_files = files; 
		bitmapQuery(BitmapQueryCommand.access_delayed_multi, File.init, ErrorHandling.ignore); 
		return bitmap_access_delayed_multi_bitmaps; 
	} 
	
	Bitmap bitmapQuery(BitmapQueryCommand cmd, File file, ErrorHandling errorHandling, Bitmap bmpIn=null)
	{
		static if((常!(bool)(0))) { auto _間=init間; scope(exit) ((0x80E7B8E2CB5D).檢((update間(_間)))); }
		/+
			Bug: Ha WM_MOVE van, akkor ez 50x lassabb!!!
			Tesztelés: DIDE -> File Outline panel tele kis file/folder ikonokkal.
			
			ChatGPT answer:
			
			
			The issue you’re experiencing—where performance drops significantly while moving the window—suggests that Windows is deprioritizing your thread’s execution when a window is being dragged. This is a known behavior in the Windows GUI system.
			
			Possible Causes:
			Windows GUI Thread Starvation
			When a window is being dragged, Windows gives higher priority to the thread handling UI events (such as the one processing WM_MOUSEMOVE). This can cause other threads, especially those not explicitly marked as high priority, to experience delays.
			
			Synchronization Overhead (synchronized)
			Your function is wrapped in a synchronized block, which means that while the function is executing, it might be blocking access to shared resources. If the UI thread tries to access any of these resources while dragging, it could cause contention, further slowing down execution.
			
			Thread Scheduling Delays
			Your code spawns worker threads via taskPool.put(task!worker_load(...)) and spawn(...). These threads might be getting scheduled with a lower priority when the window is being dragged.
			
			Windows "Input Lag Reduction" Mode
			When you move a window, Windows sometimes lowers the priority of background threads to ensure smooth UI updates. This is especially noticeable if the program has a single-threaded message loop that isn't processing messages quickly.
			
			Increased Message Pump Overhead
			If your application uses PeekMessage or GetMessage in the main thread, the increased rate of UI messages (like WM_MOUSEMOVE or WM_SETCURSOR) might be consuming more CPU cycles, reducing available time for other threads.
			
			
		+/
		//auto _ = PROBE("bitmapQuery");
		synchronized
		{
			//disable delayed
			//if(cmd==BitmapQueryCommand.access_delayed) cmd = BitmapQueryCommand.access;
			
			import std.parallelism; 
			enum log = false; 
			
			Bitmap res; 
			
			__gshared Bitmap[File] cache, loading; 
			__gshared  BitmapTransformation[][File] transformationQueue; 
			shared static int activeBackgroundLoaderCount = 0; 
			
			/// Allocate new file in cache , mark it as "loading"
			static auto startLoading(File file)
			{
				auto b = newLoadingBitmap; 
				b.file = file; 
				cache[file] = b; 
				loading[file] = b; 
				return b; 
			} 
			
			/// Allocate new file in cache and launch the loader thread
			static auto startDelayedLoad(File file)
			{
				auto bmp = startLoading(file); 
				
				static void worker_load(shared Bitmap bmp/+"loading" bitmap that is holding filename to load+/)
				{
					const errorHandling = ErrorHandling.ignore; //track;
					
					auto file = bmp.file; //it receives the original unloaded Bitmap and monitors the .removed field too.
					
					//Todo: no need to limit parallelism, taskPool is good. The slow bottleneck is convert and upload to gpu.
					version(/+$DIDE_REGION limit max number of loader threads+/none)
					{
						const maxWorkers = 9999; 
						while(cast()activeBackgroundLoaderCount >= maxWorkers)
						{
							sleep(3); 
							//Todo: this sleep is not threadsafe
						}
						//import core.atomic;
						//later use -> atomicOp!"+="(activeBackgroundLoaderCount, 1);
						//LOG(cast()activeBackgroundLoaderCount, bmp.file.name);
					}
					
					
					if(bmp.removed)
					{
						if(log)
						LOG("Bitmap has been removed before delayed loader. Cancelling operation.", bmp); 
						return; 
					}
					
					auto newBmp = newBitmap(file, errorHandling); 
					
					bitmapQuery(BitmapQueryCommand.finishWork, file, errorHandling, newBmp); 
				} 
				
				if(BitmapLoaderUsesTaskPool) taskPool.put(task!worker_load(cast(shared)bmp)); 
				else spawn(&worker_load, cast(shared)bmp); 
				
				return bmp; //returns a "loading" placeholder bitmap
			} 
			
			/// Allocate new transformed file in cache and launch the transformer thread
			static auto startDelayedTransformation(Bitmap originalBmp, Bitmap transformedBmp, BitmapTransformation tr)
			{
				
				static void worker_transform(shared Bitmap originalBmp, shared Bitmap transformedBmp, shared BitmapTransformation tr)
				{
					if(transformedBmp.removed)
					{
						if(log)
						LOG("Bitmap has been removed before delayed transformation. Canceling operation.", cast()transformedBmp); 
						return; 
					}
					
					ignoreExceptions
					(
						{
							auto newBmp = (cast()tr).transform(cast()originalBmp); 
							bitmapQuery(BitmapQueryCommand.finishTransformation, (cast()tr).transformedFile, ErrorHandling.track, newBmp); 
						}
					); 
				} 
				
				if(BitmapLoaderUsesTaskPool) taskPool.put(task!worker_transform(cast(shared)originalBmp, cast(shared)transformedBmp, cast(shared)tr)); 
				else spawn(&worker_transform, cast(shared)originalBmp, cast(shared)transformedBmp, cast(shared)tr); 
			} 
			
			//Loads and transforms a file, and updates the caches. Works in delayed and immediate mode.
			//   requiredOriginalTime : optional check for the transformation's original file modified time
			Bitmap loadAndTransform(File file, bool delayed_, DateTime requiredOriginalTime = DateTime.init)
			{
				Bitmap res; 
				
				const delayed = (){
					if(!delayed_) return false; 
					const fn = file.fullName; 
					if(fn.length>=2 && fn[1]==':') return true; //simple drive
					const drv = file.drive.withoutEnding(':'); 
					if(drv.among("virtual")) return true; 
					if(1)
					if(drv.among("S1", "S2", "S3")) return true; 
						/+Todo: plugins should provide delayed flag+/
					
					return false; 
				}(); 
				
				auto tr = file.BitmapTransformation; 
				
				bool checkRequiredModifiedTime(Bitmap bmp)
				{
					if(requiredOriginalTime.isNull) return true; 
					return requiredOriginalTime == bmp.modified; 
				} 
				
				if(delayed) {
					 //delayed load
					if(tr) {
						res = startLoading(tr.transformedFile); 
						if(auto originalBmp = tr.originalFile in cache)
						{
							if(checkRequiredModifiedTime(*originalBmp) && !(*originalBmp).loading)
							{
								//original bmp is up to date
								startDelayedTransformation(*originalBmp, res, tr); 
							}
							else
							{
								//original is an old version
								auto lastBmp = *originalBmp; 
								//preserve it in the cache, so it can be displayed while loading the new
								
								transformationQueue[tr.originalFile] ~= tr; 
								startDelayedLoad(tr.originalFile); 
								
								cache[tr.originalFile] = lastBmp; 
								lastBmp.loading = true; 
							}
						}
						else {
							transformationQueue[tr.originalFile] ~= tr; 
							startDelayedLoad(tr.originalFile); 
						}
					}
					else { res = startDelayedLoad(file); }
				}
				else {
					 //immediate load
					if(tr) {
						//get the original file
						/+
							Note: it doesn't look at delayed caches: loaded[] and transformQueue[]. 
												Those will complete later if there are any.
						+/
						Bitmap orig; 
						auto originalBmp = tr.originalFile in cache; 
						if(originalBmp && checkRequiredModifiedTime(*originalBmp))
						{ orig = *originalBmp; }
						else
						{
							orig = newBitmap(tr.originalFile, errorHandling); 
							cache[tr.originalFile] = orig; 
						}
						
						//and transform it
						assert(orig !is null); 
						res = tr.transform(orig); 
						res.file = file; //set the correct name
					}
					else { res = newBitmap(file, errorHandling); }
					cache[file] = res; 
				}
				
				return res; 
			} 
			
			Bitmap access(bool autoRefresh)(File file, bool delayed)
			{
				if(auto p = file in cache)
				{
					 //already in cache
					auto res = *p; 
					
					//check for a refreshed version
					static if(autoRefresh)
					{
						if(!res.loading)
						{
							//current bitmap is NOT loading
							if(auto t = file.getLatestModifiedTime)
							{
								//the modified time is accessible
								if(t != res.modified)
								{
									//it has a new version, must load...
									if(delayed)
									{
										loadAndTransform(file, delayed, t); 
										//put back the original file into the cache and mark that it is loading
										cache[file] = res; 
										res.loading = true; 
									}
									else
									{ res = loadAndTransform(file, delayed, t); }
								}
							}
						}
					}
					return res; 
				}
				else
				{
					//new thing, must be loaded
					return loadAndTransform(file, delayed); 
				}
			} 
			
			final switch(cmd)
			{
				
				case BitmapQueryCommand.access, BitmapQueryCommand.access_delayed: 
				{
					if(bmpIn) {
						//just put the image into the cache
						
						res = bmpIn; 
						cache[file] = res; 
						
					}
					else {
						//try to load the file from the fileSystem
						res = access!true(file, cmd==BitmapQueryCommand.access_delayed); 
					}
				}
				break; 
				
				case BitmapQueryCommand.access_delayed_multi: 
				{
					//batch processing used bny timeview.
					bitmap_access_delayed_multi_bitmaps = bitmap_access_delayed_multi_files
					.map!((file){
						res = access!false(file, true); 
						if(res) res.accessed_tick = application.tick; 
						return res; 
					}).array; 
				}
				break; 
				
				case BitmapQueryCommand.finishWork, BitmapQueryCommand.finishTransformation: 
				{
					loading.remove(file); 
					
					if(auto p = file in cache)
					{
						*p = bmpIn; 
						//swap in the new bitmap and let the GC free up the previous one. The GC will know if there is no references left.
						
						//optionally start a transformation
						if(cmd==BitmapQueryCommand.finishWork)
						if(auto tr = file in transformationQueue)
						{
							foreach(t; *tr) startDelayedTransformation(bmpIn, cache[t.transformedFile], t); 
							transformationQueue.remove(file); 
						}
					}
					else
					{ if(log) LOG("Bitmap was removed after delayed ", cmd.text.withoutStarting("finish").lc, " has started. ", bmpIn); }
				}
				break; 
				
				case BitmapQueryCommand.remove: 
				{
					if(auto p = file in cache) (*p).removed = true; 
					loading.remove(file); 
					transformationQueue.remove(file); 
					cache.remove(file); 
				}
				break; 
				
				case BitmapQueryCommand.stats, BitmapQueryCommand.details: 
				{
					_bitmapCacheStats.count = cache.length; 
					_bitmapCacheStats.allSizeBytes	= cache.byValue                       .map!"a.sizeBytes".sum; 
					_bitmapCacheStats.nonUnloadableSizeBytes	= cache.byValue.filter!"!a.unloadable".map!"a.sizeBytes".sum; 
					_bitmapCacheStats.residentSizeBytes	= cache.byValue.filter!"a.resident"   .map!"a.sizeBytes".sum; 
					
					_bitmapCacheStats.bitmaps = cmd==BitmapQueryCommand.details ? _bitmapCacheStats.bitmaps = cache.values.dup : null; 
				}
				break; 
				
				case BitmapQueryCommand.garbageCollect: 
				{
					//T0;
					auto	list = cache.byValue.filter!"a.unloadable".array; 
					const	sizeBytes = list.map!(b => b.sizeBytes).sum; 
					
					
					static if(0)
					{
						LOG("BITMAP GC StATISTICS"); 
						void printStats(alias f)()
						{
							auto filtered = cache.byValue.filter!f; 
							print(format!"%-20s %5d %5sB"(f.stringof, filtered.walkLength, filtered.map!"a.sizeBytes".sum.shortSizeText)); 
						} 
						foreach(f; AliasSeq!("a.resident", "!a.resident", "a.loading" , "a.removed", "true")) printStats!f; 
						
						//dump some statistics
						print(
							"b[].accessed: ",
							cache.byValue	.filter!(b => !b.resident && !b.loading && !b.removed && b.width>400)
								.array
								.sort!((a,b) => icmp(a.file.fullName, b.file.fullName)<0)
								.map!(
								b => format!"%s %6siB %s"(
									b.unloadable ? "PROT" : "----",
									b.sizeBytes.shortSizeText,
									b.file.name
								)
							)
								.join('\n')
						); 
					}
					
					if(sizeBytes > BitmapCacheMaxSizeBytes)
					{
						auto _2 = PROBE("bitmapQuery.GC"); 
						
						//ascending by access time
						list = list.sort!((a, b)=>a.accessed_tick<b.accessed_tick).array; 
						
						const targetSize = BitmapCacheMaxSizeBytes; 
						size_t remaining = sizeBytes; 
						//LOG("Bitmap cache GC", remaining.shortSizeText, targetSize.shortSizeText);
						foreach(b; list) {
							//print("removing", b);
							
							remaining -= b.sizeBytes; 
							cache.remove(b.file); 
							b.removed = true; 
							
							if(remaining<=targetSize) break; 
						}
						
						//LOG(DT);
					}
				}
				break; 
				case BitmapQueryCommand.set: 
				{
					if(bmpIn)
					{
						cache[file] = bmpIn; 
						
						bmpIn.loading = false; 
						loading.remove(file); 
						
						//file removed, -> also the transformations quued for the file
						transformationQueue.remove(file); 
					}
				}
				break; 
			}
			
			if(res) res.accessed_tick = application.tick; 
			
			return res; 
		} 
	} 
	
	struct bitmaps
	{
		__gshared static: 
		//bitmaps(fn) = delayed access
		//bitmaps[fn] = immediate access
		auto opCall(F)(F file, Flag!"delayed" delayed=Yes.delayed, ErrorHandling errorHandling=ErrorHandling.track, Bitmap bmp=null)
		{ return bitmapQuery(delayed ? BitmapQueryCommand.access_delayed : BitmapQueryCommand.access, File(file), errorHandling, bmp); } 
		auto opCall(F)(F file, ErrorHandling errorHandling, Flag!"delayed" delayed=Yes.delayed, Bitmap bmp=null)
		{ return opCall(file, delayed, errorHandling, bmp); } 
		
		auto opIndex(F)(F file)
		{ return opCall(file, No.delayed, ErrorHandling.raise); } 
		
		auto opIndexAssign(F)(Bitmap bmp, F file)
		{/*enforce(bmp && bmp.valid);*/ return opCall(file, No.delayed, ErrorHandling.raise, bmp); } 
		
		auto opIndexAssign(F, I)(I img, F file) if(isImage2D!I)
		{ return opindexAssign(file, No.delayed, ErrorHandling.raise, new Bitmap(img)); } 
		
		void remove (F)(F file)
		{ bitmapQuery(BitmapQueryCommand.remove, File(file), ErrorHandling.ignore); } 
		
		BitmapCacheStats stats()
		{ bitmapQuery(BitmapQueryCommand.stats  , File(), ErrorHandling.ignore); return _bitmapCacheStats; } 
		BitmapCacheStats details()
		{ bitmapQuery(BitmapQueryCommand.details, File(), ErrorHandling.ignore); return _bitmapCacheStats; } 
		
		void garbageCollect()
		{ bitmapQuery(BitmapQueryCommand.garbageCollect, File(), ErrorHandling.ignore); } 
		
		void set(F)(F file, Bitmap bmp)
		{
			auto f = File(file); 
			enforce(f); 
			enforce(bmp); 
			
			bitmapQuery(BitmapQueryCommand.set, f, ErrorHandling.ignore, bmp); 
		} 
		
		void set(Bitmap bmp)
		{
			enforce(bmp); 
			set(bmp.file, bmp); 
		} 
		
		Bitmap set(T)(File f, DateTime m, Image!(T, 2) img)
		{
			auto b = new Bitmap(img); b.file = f; b.modified = m; 
			set(b); 
			return b; 
		} 
		
		void refresh(F)(F file)
		{
			auto f = File(file); 
			auto b = newBitmap(f, ErrorHandling.track); //Todo: this reallocates the buffer, it's a waste of GC
			b.modified = now; 
			bitmaps.set(f, b); 
		} 
		
	} 
	
	ivec2 bitmapSize(T)(in T a, in ivec2 invalidSize = ivec2(0))
	{
		static if(is(T==Bitmap))	return a ? a.size : invalidSize; 
		else	{
			const b = bitmaps(a.File); 
			return b.valid ? b.size : invalidSize; 
		}
	} 
	
	void testBitmaps()
	{
		print("\nStarting bitmap() tests.----------------------------------------"); 
		
		void doIt(string title, Bitmap delegate() fun)
		{
			writeln("bitmap() test: \33\16"~title~"\33\7"); 
			const t0 = QPS; 
			Bitmap b = fun(); 
			if(b.loading) {
				print("  first access    :", b); 
				while(b.loading) {
					sleep(10); 
					b = fun(); 
				}
				print("  loaded          :", b); 
			}else { print("  immediate access:", b); }
			print("  time              :\33\12", (QPS-t0)*1e3, "ms\33\7"); 
		} 
		
		auto file	= File(`c:\dl\BaiLing0.jpg`); 
		auto thumb	= File(file.fullName~"?thumb64"); 
		enforce(file.exists); 
		
		doIt("immediate"                    , ()=>bitmaps(file, No.delayed)); 	 bitmaps.remove(file); 
		doIt("immediate again, after remove", ()=>bitmaps(file, No.delayed)); 	 bitmaps.remove(file); 
		doIt("delayed first (cache miss)"	  , ()=>bitmaps(file, Yes.delayed)); 
		doIt("delayed again (cache hit)"		 , ()=>bitmaps(file, Yes.delayed)); 	 bitmaps.remove(file); 
		doIt("delayed again (removed  )"		 , ()=>bitmaps(file, Yes.delayed)); 	 bitmaps.remove(file); 
		
		print("Thumb immediate tests:"); 
		bitmaps.remove(file); bitmaps.remove(thumb); 
		doIt("immediate originalFile (miss)", ()=>bitmaps(file , No.delayed)); 
		doIt("immediate thumb"              , ()=>bitmaps(thumb, No.delayed)); 
		//bitmaps(thumb).saveTo(`c:\dl\thumb.bmp`);   { auto b = new Bitmap; b.loadFrom(`c:\dl\thumb.bmp`); b.print; }
		
		bitmaps.remove(file); bitmaps.remove(thumb); 
		doIt("immediate thumb"	, ()=>bitmaps(thumb, No.delayed)); 
		doIt("immediate originalFile (hit)"	, ()=>bitmaps(file , No.delayed)); 
		
		print("Thumb delayed tests:"); 
		bitmaps.remove(file); bitmaps.remove(thumb); 
		doIt("delayed originalFile (miss)", ()=>bitmaps(file , Yes.delayed)); 
		doIt("delayed thumb"              , ()=>bitmaps(thumb, Yes.delayed)); 
		bitmaps.remove(file); bitmaps.remove(thumb); 
		doIt("delayed thumb"	, ()=>bitmaps(thumb, Yes.delayed)); 
		doIt("delayed originalFile (hit)"	, ()=>bitmaps(file , Yes.delayed)); 
		
		print("\nBitmap cache statistics"); 
		bitmaps.details; 
		print("All bitmap() tests done.----------------------------------------\n"); 
		readln; 
	} 
	
	
	
	
	
	
	//old utility stuff //////////////////////////////////////////////////////////
	
	
	float cubicInterpolate(float[4] p, float x)
	{
		//http://www.paulinternet.nl/?page=bicubic
		return p[1] + 0.5f * x*(p[2] - p[0] + x*(2*p[0] - 5*p[1] + 4*p[2] - p[3] + x*(3*(p[1] - p[2]) + p[3] - p[0]))); 
	} 
	
	T cubicInterpolate(T)(T[4] p, float x) if(__traits(isIntegral, T))
	{
		//http://www.paulinternet.nl/?page=bicubic
		float f = (p[1] + 0.5f * x*(p[2] - p[0] + x*(2*p[0] - 5*p[1] + 4*p[2] - p[3] + x*(3*(p[1] - p[2]) + p[3] - p[0])))); 
		return cast(T) f.iround.clamp(T.min, T.max); 
	} 
	
	T bicubicInterpolate (T)(T[4][4] p, float x, float y)
	{
		 //unoptimized recursive version
		T[4] a = [
			cubicInterpolate(p[0], x),
			cubicInterpolate(p[1], x),
			cubicInterpolate(p[2], x),
			cubicInterpolate(p[3], x) 
		]; 
		return cubicInterpolate(a, y); 
	} 
	
	//Extract a sub-region of a given image
	//x,y :	 top, left coordinate of the rect
	//w,h :	 size of the output image
	//xs, ys:	 stepSize int x, y directions  <1 means magnification
	Image!(T, 2) extract_bicubic(T)(Image!(T, 2) iSrc, float x0, float y0, int w, int h, float xs=1, float ys=1)
	{
		auto res = image2D(w, h, T.init); 
		auto x00 = x0; 
		
		foreach(int y; 0..h)
		{
			auto yt = y0.iFloor,
					 yf = y0-yt; 
			
			x0 = x00; //advance row
			foreach(int x; 0..w)
			{
				auto xt = x0.iFloor,
						 xf = x0-xt; 
				
				//get a sample form x0, y0
				T[4][4] a; foreach(j; 0..4) foreach(i; 0..4) a[j][i] = iSrc[iSrc.ofs_safe(i+xt-1, j+yt-1)]; 
				
				res[x, y] = bicubicInterpolate(a, xf, yf); 
				
				x0 += xs; 
			}
			y0 += ys; 
		}
		
		return res; 
	} 
	
	T linearInterpolate(T)(T[2] p, float x) if(__traits(isIntegral, T))
	{
		//http://www.paulinternet.nl/?page=bicubic
		float f = p[1]*x + p[0]*(1-x); 
		return cast(T) f.iround.clamp(T.min, T.max); 
	} 
	
	T bilinearInterpolate (T)(T[2][2] p, float x, float y)
	{
		 //unoptimized recursive version
		T[2] a = [
			linearInterpolate(p[0], x),
			linearInterpolate(p[1], x) 
		]; 
		return linearInterpolate(a, y); 
	} 
	
	Image!(T, 2) extract_bilinear(T)(Image!(T, 2) iSrc, float x0, float y0, int w, int h, float xs=1, float ys=1)
	{
		auto res = image2D(w, h, T.init); 
		auto x00 = x0; 
		
		foreach(int y; 0..h)
		{
			auto yt = y0.iFloor,
					 yf = y0-yt; 
			
			x0 = x00; //advance row
			foreach(int x; 0..w)
			{
				auto xt = x0.iFloor,
						 xf = x0-xt; 
				
				//get a sample form x0, y0
				T[2][2] a; foreach(j; 0..2) foreach(i; 0..2) a[j][i] = iSrc[iSrc.ofs_safe(i+xt, j+yt)]; 
				
				res[x, y] = bilinearInterpolate(a, xf, yf); 
				
				x0 += xs; 
			}
			y0 += ys; 
		}
		
		return res; 
	} 
	
	auto resample_linear(R)(R src, int dstSize, float srcStartPos=0, float srcStep=1) if(isRandomAccessRange!R)
	{
		alias T = ElementType!R; 
		if(dstSize<=0) return (T[]).init; 
		const srcSize = src.length.to!int; if(!srcSize) return [T.init].replicate(dstSize); 
		
		T doSample(int index)
		{
			const srcPos = srcStartPos + index * srcStep, t = (ifloor(srcPos)), f = srcPos-t; 
			if(t>=0 && t+1<srcSize) { return mix(src[t], src[t+1], f); }
			else {
				return mix(
					src[clamp(t+0, 0, srcSize-1)], 
					src[clamp(t+1, 0, srcSize-1)], f
				); 
			}
		} 
		
		return iota(dstSize).map!((i)=>(doSample(i))).array; 
		/+Note: tested: OK 250625+/
	} 
	
	auto stretch_linear(R)(R src, int dstSize) if(isRandomAccessRange!R)
	=> src.resample_linear(dstSize, 0, (float(src.length.to!int-1)) / max(dstSize-1, 1)); 
	
	auto scale_linear(R)(R src, float ratio) if(isRandomAccessRange!R)
	=> src.resample_linear(dstSize, 0, (iround(src.length * ratio))); 
	
	/+Todo: testcases for all these image extractors!!!+/
	
	
	auto sample_nearest(T)(Image!(T, 2) iSrc, ivec2 p)
	{
		  //Todo: unsafe/safe versions, safe with boundary mode and color -> openCV
		if(p.x<0 || p.y<0 || p.x>=iSrc.width || p.y>=iSrc.height) return T.init; 
		return iSrc[p]; 
	} 
	
	auto sample_nearest(T)(Image!(T, 2) iSrc, vec2 p)
	{ return iSrc.sample_nearest(p.ifloor); } 
	
	auto extract_nearest(T)(Image!(T, 2) iSrc, float x0, float y0, int w, int h, float xs=1, float ys=1)
	{
		return image2D(w, h, (ivec2 p) => iSrc.sample_nearest(p*vec2(xs, ys)+vec2(x0, y0))); //Opt: it's slow, but universal
		
		/*
			Image!(T, 2) resize_halve(T)(Image!(T, 2) iSrc, ivec2 newSize){
				}
			
				Image!(T, 2) resize_bilinear(T)(Image!(T, 2) iSrc, ivec2 newSize){
				}
		*/
		
		/*
			  auto res = image2D(w, h, T.init);
			auto x00 = x0;
			
			foreach(int y; 0..h){
				auto yt = y0.ifloor,
						 yf = y0-yt;
			
				x0 = x00; //advance row
				foreach(int x; 0..w){
					auto xt = x0.ifloor,
							 xf = x0-xt;
			
					res[x, y] = iSrc[iSrc.ofs_safe(xt, yt)];
			
					x0 += xs;
				}
				y0 += ys;
			}
			
			return res;
		*/
	} 
	
	Image!(T, 2) resize_nearest(T)(Image!(T, 2) iSrc, ivec2 newSize)
	{
		//Todo: What about pixel center 0.5?  It is now shifting the image.
		return extract_nearest(iSrc, 0, 0, newSize.x, newSize.y, iSrc.size.x/float(newSize.x), iSrc.size.y/float(newSize.y)); 
	} 
	
	//This is a special one: it only processes the first 2 ubytes of an uint
	//Todo: should be refactored to an image that handles RGBA types
	/+
		Image!(uint, 2) extract_bilinear_rg00(Image!(uint, 2) iSrc, float x0, float y0, int w, int h, float xs=1, float ys=1){
			auto res = image2D(w, h, 0u);
			auto x00 = x0;
		
			foreach(int y; 0..h){
				auto yt = y0.ifloor,
						 yf = y0-yt;
		
				x0 = x00; //advance row
				foreach(int x; 0..w){
					auto xt = x0.ifloor,
							 xf = x0-xt;
		
					//get a sample form x0, y0
					ubyte[2][2] a;
		
					//r
					foreach(j; 0..2) foreach(i; 0..2) a[j][i] = iSrc[iSrc.ofs_safe(i+xt, j+yt)] & 0xFF;
					res[x, y] = bilinearInterpolate(a, xf, yf);
		
					//g
					foreach(j; 0..2) foreach(i; 0..2) a[j][i] = (iSrc[iSrc.ofs_safe(i+xt, j+yt)]>>8) & 0xFF;
					res[x, y] |= bilinearInterpolate(a, xf, yf)<<8;
		
					x0 += xs;
				}
				y0 += ys;
			}
		
			return res;
		}
	+/
	
	
	/+
		Image!(uint, 2) extract_bicubic_rg00(Image!(uint, 2) iSrc, float x0, float y0, int w, int h, float xs=1, float ys=1){
			auto res = image2D(w, h, 0u);
			auto x00 = x0;
		
			foreach(int y; 0..h){
				auto yt = y0.ifloor,
						 yf = y0-yt;
		
				x0 = x00; //advance row
				foreach(int x; 0..w){
					auto xt = x0.ifloor,
							 xf = x0-xt;
		
					//get a sample form x0, y0
					ubyte[4][4] a;
		
					foreach(j; 0..4) foreach(i; 0..4) a[j][i] = cast(ubyte)(iSrc[iSrc.ofs_safe(i+xt-1, j+yt-1)] & 0xFF);
					res[x, y] = bicubicInterpolate(a, xf, yf);
		
					foreach(j; 0..4) foreach(i; 0..4) a[j][i] = cast(ubyte)((iSrc[iSrc.ofs_safe(i+xt-1, j+yt-1)]>>8) & 0xFF);
					res[x, y] |= bicubicInterpolate(a, xf, yf)<<8;
		
					x0 += xs;
				}
				y0 += ys;
			}
		
			return res;
		} 
	+/
	
	//old Bitmap image processing -> should be imageprocessing ////////////////////////////
	
	/*
		bool isGrayscale() const {
			if(empty || channels<=2) return true;
			return channels==3 ? i3.cdata.all!(c => c.r==c.g && c.r==c.b)
												 : i4.cdata.all!(c => c.r==c.g && c.r==c.b);
		}
		
		void invert(){
			//todo: az ilyen int3 debuggolasra kitalalni valami jobbat.
			cast(ubyte[])(data)[] ^= 0xff;  //todo: Bitmap.invert optimizaciojat megvizsgalni
		}
		
		Bitmap copyRect(int x0, int y0, int xs, int ys)const{
			if(x0<0 || x0+xs>width || y0+ys>height) raise("Out of range");
			if(xs<=0 || ys<=0) return null; //empty selection
		
			const ch = channels,
						dstLineSize = xs*ch,
						srcLineSize = width*ch,
						srcBase = x0*ch;
		
			Bitmap res = new Bitmap(xs, ys, ch);
		
			int srcOfs = (width*y0+x0)*ch, dstOfs;
			foreach(y; 0..ys){
				res.data[dstOfs..dstOfs+srcLineSize] = cdata[srcOfs..srcOfs+srcLineSize];
				srcOfs += srcLineSize;
				dstOfs += dstLineSize;
			}
		
			return res;
		}
	*/
	
	//Image utilites: convert, interpolate, etc /////////////////////////////////////////////////////////
	
	auto convertImage(Dst, T)(Image!(T, 2) src)
	{
		//compile time image convert
		scope auto bmp = new Bitmap; 
		bmp.set(src); 
		return bmp.get!Dst; 
	} 
	
	/// converts it to ubyte and remaps chn using a chn expression string
	private auto convertImage_ubyte_chnRemap(int[4] chnRemap, T)(Image!(T, 2) a)
	{
		enum chn = VectorLength!T,
		newChn = chnRemap[chn-1]; 
		static assert(newChn.inRange(1,4)); 
		
		static if(is(ScalarType!T == ubyte) && chn == newChn) return a; 
		else return a.convertImage!(Vector!(ubyte, newChn)); 
	} 
	
	auto interpolate_bilinear(A)(in A a00, in A a10, in A a01, in A a11, in vec2 p)
	{
		return mix(
			mix(a00, a10, p.x),
			mix(a01, a11, p.x), p.y
		); 
	} 
	
	auto interpolate_bilinear_safe(A)(Image!(A, 2) im, in vec2 p)
	{
		if(im.empty) return A.init; 
		auto 	limit 	= im.size-1,
			p0	= p.ifloor.clamp(ivec2(0), limit),
			p1	= min(p0+1, limit); 
		return interpolate_bilinear(
			im[p0      ], im[p1.x, p0.y],
			im[p0.x, p1.y], im[p1      ], p.fract
		); 
	} 
	
	auto peakDetect(T)(Image!T img, int border=1, T minValue=T.min)
	{
		with(img) {
			ivec2[] peaks; 
			foreach(int y; border..height-border)
			{
				 int o0 = y*width; 
				foreach(int x; border..width-border) {
					 auto o = o0+x, val = data[o]; 
					if(val>minValue && img.isPeak(o))
					peaks ~= ivec2(x, y); 
				}
			}
			return peaks; 
		}
	} 
	
	void maskAll(T)(Image!T img, T mask)
	{ with(img) { data[] &= mask; }} 
	
	void mask(T)(Image!T img, Bounds2i b, T msk)
	{
		with(img) {
			with(bounds.clamp(b))
			{
				if(isNull) return; 
				foreach(int y; bMin.y..bMax.y)
				{
					int o0 = y*width_; 
					foreach(int o; o0+bMin.x..o0+bMax.x) { data_[o] &= msk; }
				}
				
			}
		}
	} 
	
	void maskBorder(T)(Image!T img, int border, T mask)
	{
		with(img) {
			if(border*2>=width || border*2>=height) img.maskAll(mask); 
			
			data[0..width*border] &= mask; 
			data[$-width*border..$] &= mask; 
			foreach(int y; border..height-border) {
				int o = y*width; 
				data[o..o+border] &= mask; 
				data[o+width-border..o+width] &= mask; 
			}
		}
	} 
	
	bool isPeak(T)(Image!T img, int o)
	{
		with(img) {
			const center = data[o]; 
			bool g(int delta) {
				const val = data[o+delta]; 
				return center>val || (center==val && delta>0); 
			} 
			
			return g(-1) && g(1) &&
						 g(-width  ) && g(width  )	&&
						 g(width-1) && g(width+1)	&&
						 g(-width-1) && g(-width+1); 
		}
	} 
	
	
	
	auto transpose16x16b(ubyte* p, sizediff_t stride)
	{
		static punpckZip(string ending, int len)()
		{
			return "tuple(" ~ len.iota.map!(
				i=>	q{
					punpcklwd(a[0], b[0]),
					punpckhwd(a[0], b[0]),
				}
					.replace("0", i.text)
					.replace("wd", ending)
			).join ~ ")"; 
		} 
		
		static fetch8(ubyte* p, sizediff_t stride)
		{
			static fetch4(ubyte* p, sizediff_t stride)
			{
				static fetch2(ubyte* p, sizediff_t stride)
				{
					const a = *(cast(ubyte16*)(p)), b = *(cast(ubyte16*)(p+stride)); 
					return tuple(punpcklbw(a, b), punpckhbw(a, b)); 
				} 
				
				const a = fetch2(p, stride), b = fetch2(p+2*stride, stride); 
				return mixin(punpckZip!("wd", 2)); 
			} 
			
			const a = fetch4(p, stride), b = fetch4(p+4*stride, stride); 
			return mixin(punpckZip!("dq", 4)); 
		} 
		
		const a = fetch8(p, stride), b = fetch8(p+8*stride, stride); 
		return mixin(punpckZip!("qdq", 8)); 
		
		//Todo: unittest
		/+
			{
				auto img = bitmaps[`c:\d\16x16gray.png`].get!ubyte; 
				image2D(16, 16, cast(ubyte[])(transpose16x16b(img.ptr, img.stride).array)).saveTo(`c:\d\16x16gray_flip.png`); 
			}
		+/
	} 
}
version(/+$DIDE_REGION Imageformats, turboJpeg, libWebp+/all)
{
	public
	{
		version(/+$DIDE_REGION Imageformats+/all)
		{
			//Copyright (c) 2014-2018 Tero Hänninen
			
			//Boost Software License - Version 1.0 - August 17th, 2003
			//module imageformats; 
			
			import std.stdio	: StdIOFile=File, SEEK_SET, SEEK_CUR, SEEK_END; 
			import std.string	: toLower, lastIndexOf; 
			import std.typecons : scoped; 
			//public import imageformats.png; 
			//public import imageformats.tga; 
			//public import imageformats.bmp; 
			
			//public import imageformats.jpeg; 
			//230916 realhet : JPEG support disabled in here. I prefer turboJpeg.
			
			/// Image with 8-bit channels.
			struct IFImage
			{
				/// width
				int         w; 
				/// height
				int         h; 
				/// channels
				ColFmt      c; 
				/// buffer
				ubyte[]     pixels; 
			} 
			
			/// Image with 16-bit channels.
			struct IFImage16
			{
				/// width
				int         w; 
				/// height
				int         h; 
				/// channels
				ColFmt      c; 
				/// buffer
				ushort[]    pixels; 
			} 
			
			/// Color format which you can pass to the read and write functions.
			enum ColFmt
			{
				Y = 1,	  /// Gray
				YA = 2,	  /// Gray + Alpha
				RGB = 3,	  /// Truecolor
				RGBA = 4,	  /// Truecolor + Alpha
			} 
			
			/// Reads an image from file. req_chans defines the format of returned image
			/// (you can use ColFmt here).
			IFImage read_image(in char[] file, long req_chans = 0)
			{
				auto reader = scoped!FileReader(file); 
				return read_image_from_reader(reader, req_chans); 
			} 
			
			/// Reads an image from a buffer. req_chans defines the format of returned
			/// image (you can use ColFmt here).
			IFImage read_image_from_mem(in ubyte[] source, long req_chans = 0)
			{
				auto reader = scoped!MemReader(source); 
				return read_image_from_reader(reader, req_chans); 
			} 
			
			/// Writes an image to file. req_chans defines the format the image is saved in
			/// (you can use ColFmt here).
			void write_image(in char[] file, long w, long h, in ubyte[] data, long req_chans = 0)
			{
				const char[] ext = extract_extension_lowercase(file); 
				
				void function(Writer, long, long, in ubyte[], long) write_image; 
				switch(ext)
				{
					case "png": write_image = &write_png; break; 
					case "tga": write_image = &write_tga; break; 
					case "bmp": write_image = &write_bmp; break; 
					default: throw new ImageIOException("unknown image extension/type"); 
				}
				auto writer = scoped!FileWriter(file); 
				write_image(writer, w, h, data, req_chans); 
			} 
			
			/// Returns width, height and color format information via w, h and chans.
			/// If number of channels is unknown chans is set to zero, otherwise chans
			/// values map to those of ColFmt.
			void read_image_info(in char[] file, out int w, out int h, out int chans)
			{
				auto reader = scoped!FileReader(file); 
				try
				{ return read_png_info(reader, w, h, chans); }catch(Throwable)
				{ reader.seek(0, SEEK_SET); }
				try
				{ return read_jpeg_info(reader, w, h, chans); }catch(Throwable)
				{ reader.seek(0, SEEK_SET); }
				try
				{ return read_bmp_info(reader, w, h, chans); }catch(Throwable)
				{ reader.seek(0, SEEK_SET); }
				try
				{ return read_tga_info(reader, w, h, chans); }catch(Throwable)
				{ reader.seek(0, SEEK_SET); }
				throw new ImageIOException("unknown image type"); 
			} 
			
			//Added by realhet
			
			void read_image_info_from_mem(in ubyte[] source, out int w, out int h, out int chans)
			{
				auto reader = scoped!MemReader(source); 
				try
				{ return read_png_info(reader, w, h, chans); }catch(Throwable)
				{ reader.seek(0, SEEK_SET); }
				try
				{ return read_jpeg_info(reader, w, h, chans); }catch(Throwable)
				{ reader.seek(0, SEEK_SET); }
				try
				{ return read_bmp_info(reader, w, h, chans); }catch(Throwable)
				{ reader.seek(0, SEEK_SET); }
				try
				{ return read_tga_info(reader, w, h, chans); }catch(Throwable)
				{ reader.seek(0, SEEK_SET); }
				throw new ImageIOException("unknown image type"); 
			} 
			
			/// Thrown from all the functions...
			class ImageIOException : Exception
			{
				@safe pure const
					 this(string msg, string file = __FILE__, size_t line = __LINE__)
				{   super(msg, file, line); } 
			} 
			
			private: 
			
			IFImage read_image_from_reader(Reader reader, long req_chans)
			{
				if(detect_png(reader))
				return read_png(reader, req_chans); 
				/+
					if(detect_jpeg(reader))
						return read_jpeg(reader, req_chans); 
				+/
				if(detect_bmp(reader))
				return read_bmp(reader, req_chans); 
				if(detect_tga(reader))
				return read_tga(reader, req_chans); 
				throw new ImageIOException("unknown image type"); 
			} 
			
			//--------------------------------------------------------------------------------
			//Conversions
			
			package enum _ColFmt : int
			{
				Unknown = 0,
				Y = 1,
				YA,
				RGB,
				RGBA,
				BGR,
				BGRA,
			} 
			
			package alias LineConv(T) = void function(in T[] src, T[] tgt); 
			
			package LineConv!T get_converter(T)(long src_chans, long tgt_chans) pure
			{
				long combo(long a, long b) pure nothrow
				{ return a*16 + b; } 
				
				if(src_chans == tgt_chans)
				return &copy_line!T; 
				
				switch(combo(src_chans, tgt_chans))
				with(_ColFmt)
				{
					case combo(Y, YA): return &Y_to_YA!T; 
					case combo(Y, RGB): return &Y_to_RGB!T; 
					case combo(Y, RGBA): return &Y_to_RGBA!T; 
					case combo(Y, BGR): return &Y_to_BGR!T; 
					case combo(Y, BGRA)	: 	return &Y_to_BGRA!T; 
					case combo(YA, Y)	: 	return &YA_to_Y!T; 
					case combo(YA, RGB)	: 	return &YA_to_RGB!T; 
					case combo(YA, RGBA): return &YA_to_RGBA!T; 
					case combo(YA, BGR): return &YA_to_BGR!T; 
					case combo(YA, BGRA): 	return &YA_to_BGRA!T; 
					case combo(RGB, Y)	: return &RGB_to_Y!T; 
					case combo(RGB, YA)	: return &RGB_to_YA!T; 
					case combo(RGB, RGBA): 	return &RGB_to_RGBA!T; 
					case combo(RGB, BGR): return &RGB_to_BGR!T; 
					case combo(RGB, BGRA): 	return &RGB_to_BGRA!T; 
					case combo(RGBA, Y)	: return &RGBA_to_Y!T; 
					case combo(RGBA, YA): return &RGBA_to_YA!T; 
					case combo(RGBA, RGB)	: return &RGBA_to_RGB!T; 
					case combo(RGBA, BGR)	: return &RGBA_to_BGR!T; 
					case combo(RGBA, BGRA): 	return &RGBA_to_BGRA!T; 
					case combo(BGR, Y)	: return &BGR_to_Y!T; 
					case combo(BGR, YA): return &BGR_to_YA!T; 
					case combo(BGR, RGB): return &BGR_to_RGB!T; 
					case combo(BGR, RGBA): 	return &BGR_to_RGBA!T; 
					case combo(BGRA, Y)	: return &BGRA_to_Y!T; 
					case combo(BGRA, YA): return &BGRA_to_YA!T; 
					case combo(BGRA, RGB): return &BGRA_to_RGB!T; 
					case combo(BGRA, RGBA): return &BGRA_to_RGBA!T; 
					default	: throw new ImageIOException("internal error"); 
				}
				
			} 
			
			void copy_line(T)(in T[] src, T[] tgt) pure nothrow
			{ tgt[0..$] = src[0..$]; } 
			
			T luminance(T)(T r, T g, T b) pure nothrow
			{
				return cast(T) (0.21*r + 0.64*g + 0.15*b); //somewhat arbitrary weights
			} 
			
			void Y_to_YA(T)(in T[] src, T[] tgt) pure nothrow
			{
				for(size_t k, t;   k < src.length;   k+=1, t+=2)
				{
					tgt[t] = src[k]; 
					tgt[t+1] = T.max; 
				}
			} 
			
			alias Y_to_BGR = Y_to_RGB; 
			void Y_to_RGB(T)(in T[] src, T[] tgt) pure nothrow
			{
				for(size_t k, t;   k < src.length;   k+=1, t+=3)
				tgt[t .. t+3] = src[k]; 
			} 
			
			alias Y_to_BGRA = Y_to_RGBA; 
			void Y_to_RGBA(T)(in T[] src, T[] tgt) pure nothrow
			{
				for(size_t k, t;   k < src.length;   k+=1, t+=4)
				{
					tgt[t .. t+3] = src[k]; 
					tgt[t+3] = T.max; 
				}
			} 
			
			void YA_to_Y(T)(in T[] src, T[] tgt) pure nothrow
			{
				for(size_t k, t;   k < src.length;   k+=2, t+=1)
				tgt[t] = src[k]; 
			} 
			
			alias YA_to_BGR = YA_to_RGB; 
			void YA_to_RGB(T)(in T[] src, T[] tgt) pure nothrow
			{
				for(size_t k, t;   k < src.length;   k+=2, t+=3)
				tgt[t .. t+3] = src[k]; 
			} 
			
			alias YA_to_BGRA = YA_to_RGBA; 
			void YA_to_RGBA(T)(in T[] src, T[] tgt) pure nothrow
			{
				for(size_t k, t;   k < src.length;   k+=2, t+=4)
				{
					tgt[t .. t+3] = src[k]; 
					tgt[t+3] = src[k+1]; 
				}
			} 
			
			void RGB_to_Y(T)(in T[] src, T[] tgt) pure nothrow
			{
				for(size_t k, t;   k < src.length;   k+=3, t+=1)
				tgt[t] = luminance(src[k], src[k+1], src[k+2]); 
			} 
			
			void RGB_to_YA(T)(in T[] src, T[] tgt) pure nothrow
			{
				for(size_t k, t;   k < src.length;   k+=3, t+=2)
				{
					tgt[t] = luminance(src[k], src[k+1], src[k+2]); 
					tgt[t+1] = T.max; 
				}
			} 
			
			void RGB_to_RGBA(T)(in T[] src, T[] tgt) pure nothrow
			{
				for(size_t k, t;   k < src.length;   k+=3, t+=4)
				{
					tgt[t .. t+3] = src[k .. k+3]; 
					tgt[t+3] = T.max; 
				}
			} 
			
			void RGBA_to_Y(T)(in T[] src, T[] tgt) pure nothrow
			{
				for(size_t k, t;   k < src.length;   k+=4, t+=1)
				tgt[t] = luminance(src[k], src[k+1], src[k+2]); 
			} 
			
			void RGBA_to_YA(T)(in T[] src, T[] tgt) pure nothrow
			{
				for(size_t k, t;   k < src.length;   k+=4, t+=2)
				{
					tgt[t] = luminance(src[k], src[k+1], src[k+2]); 
					tgt[t+1] = src[k+3]; 
				}
			} 
			
			void RGBA_to_RGB(T)(in T[] src, T[] tgt) pure nothrow
			{
				for(size_t k, t;   k < src.length;   k+=4, t+=3)
				tgt[t .. t+3] = src[k .. k+3]; 
			} 
			
			void BGR_to_Y(T)(in T[] src, T[] tgt) pure nothrow
			{
				for(size_t k, t;   k < src.length;   k+=3, t+=1)
				tgt[t] = luminance(src[k+2], src[k+1], src[k+1]); 
			} 
			
			void BGR_to_YA(T)(in T[] src, T[] tgt) pure nothrow
			{
				for(size_t k, t;   k < src.length;   k+=3, t+=2)
				{
					tgt[t] = luminance(src[k+2], src[k+1], src[k+1]); 
					tgt[t+1] = T.max; 
				}
			} 
			
			alias RGB_to_BGR = BGR_to_RGB; 
			void BGR_to_RGB(T)(in T[] src, T[] tgt) pure nothrow
			{
				for(size_t k;   k < src.length;   k+=3)
				{
					tgt[k  ] = src[k+2]; 
					tgt[k+1] = src[k+1]; 
					tgt[k+2] = src[k  ]; 
				}
			} 
			
			alias RGB_to_BGRA = BGR_to_RGBA; 
			void BGR_to_RGBA(T)(in T[] src, T[] tgt) pure nothrow
			{
				for(size_t k, t;   k < src.length;   k+=3, t+=4)
				{
					tgt[t  ] = src[k+2]; 
					tgt[t+1] = src[k+1]; 
					tgt[t+2] = src[k  ]; 
					tgt[t+3] = T.max; 
				}
			} 
			
			void BGRA_to_Y(T)(in T[] src, T[] tgt) pure nothrow
			{
				for(size_t k, t;   k < src.length;   k+=4, t+=1)
				tgt[t] = luminance(src[k+2], src[k+1], src[k]); 
			} 
			
			void BGRA_to_YA(T)(in T[] src, T[] tgt) pure nothrow
			{
				for(size_t k, t;   k < src.length;   k+=4, t+=2)
				{
					tgt[t] = luminance(src[k+2], src[k+1], src[k]); 
					tgt[t+1] = T.max; 
				}
			} 
			
			alias RGBA_to_BGR = BGRA_to_RGB; 
			void BGRA_to_RGB(T)(in T[] src, T[] tgt) pure nothrow
			{
				for(size_t k, t;   k < src.length;   k+=4, t+=3)
				{
					tgt[t  ] = src[k+2]; 
					tgt[t+1] = src[k+1]; 
					tgt[t+2] = src[k  ]; 
				}
			} 
			
			alias RGBA_to_BGRA = BGRA_to_RGBA; 
			void BGRA_to_RGBA(T)(in T[] src, T[] tgt) pure nothrow
			{
				for(size_t k, t;   k < src.length;   k+=4, t+=4)
				{
					tgt[t  ] = src[k+2]; 
					tgt[t+1] = src[k+1]; 
					tgt[t+2] = src[k  ]; 
					tgt[t+3] = src[k+3]; 
				}
			} 
			
			//--------------------------------------------------------------------------------
			
			package interface Reader
			{
				void readExact(ubyte[], size_t); 
				void seek(ptrdiff_t, int); 
			} 
			
			package interface Writer
			{
				void rawWrite(in ubyte[]); 
				void flush(); 
			} 
			
			package class FileReader : Reader
			{
				this(in char[] filename)
				{ this(StdIOFile(filename.idup, "rb")); } 
				
				this(StdIOFile f)
				{
					if(!f.isOpen)
					throw new ImageIOException("File not open"); 
					this.f = f; 
				} 
				
				void readExact(ubyte[] buffer, size_t bytes)
				{
					auto slice = this.f.rawRead(buffer[0..bytes]); 
					if(slice.length != bytes)
					throw new Exception("not enough data"); 
				} 
				
				void seek(ptrdiff_t offset, int origin)
				{ this.f.seek(offset, origin); } 
				
				private StdIOFile f; 
			} 
			
			package class MemReader : Reader
			{
				this(in ubyte[] source)
				{ this.source = source; } 
				
				void readExact(ubyte[] buffer, size_t bytes)
				{
					if(source.length - cursor < bytes)
					throw new Exception("not enough data"); 
					buffer[0..bytes] = source[cursor .. cursor+bytes]; 
					cursor += bytes; 
				} 
				
				void seek(ptrdiff_t offset, int origin)
				{
					switch(origin)
					{
						case SEEK_SET: 
							if(offset < 0 || source.length <= offset)
						throw new Exception("seek error"); 
							cursor = offset; 
							break; 
						case SEEK_CUR: 
							ptrdiff_t dst = cursor + offset; 
							if(dst < 0 || source.length <= dst)
						throw new Exception("seek error"); 
							cursor = dst; 
							break; 
						case SEEK_END: 
							if(0 <= offset || source.length < -offset)
						throw new Exception("seek error"); 
							cursor = cast(ptrdiff_t) source.length + offset; 
							break; 
						default: assert(0); 
					}
				} 
				
				private const ubyte[] source; 
				private ptrdiff_t cursor; 
			} 
			
			package class FileWriter : Writer
			{
				this(in char[] filename)
				{ this(StdIOFile(filename.idup, "wb")); } 
				
				this(StdIOFile f)
				{
					if(!f.isOpen)
					throw new ImageIOException("File not open"); 
					this.f = f; 
				} 
				
				void rawWrite(in ubyte[] block)
				{ this.f.rawWrite(block); } 
				void flush()
				{ this.f.flush(); } 
				
				private StdIOFile f; 
			} 
			
			package class MemWriter : Writer
			{
				this()
				{} 
				
				ubyte[] result()
				{ return buffer; } 
				
				void rawWrite(in ubyte[] block)
				{ this.buffer ~= block; } 
				void flush()
				{} 
				
				private ubyte[] buffer; 
			} 
			
			const(char)[] extract_extension_lowercase(in char[] filename)
			{
				ptrdiff_t di = filename.lastIndexOf('.'); 
				return (0 < di && di+1 < filename.length) ? filename[di+1..$].toLower() : ""; 
			} 
			
			unittest
			{
				//The TGA and BMP files are not as varied in format as the PNG files, so
				//not as well tested.
				string png_path = "tests/pngsuite/"; 
				string tga_path = "tests/pngsuite-tga/"; 
				string bmp_path = "tests/pngsuite-bmp/"; 
				
				auto files = [
					"basi0g08",			 //PNG image data, 32 x 32, 8-bit grayscale, interlaced
					"basi2c08",			 //PNG image data, 32 x 32, 8-bit/color RGB, interlaced
					"basi3p08",			 //PNG image data, 32 x 32, 8-bit colormap, interlaced
					"basi4a08",			 //PNG image data, 32 x 32, 8-bit gray+alpha, interlaced
					"basi6a08",			 //PNG image data, 32 x 32, 8-bit/color RGBA, interlaced
					"basn0g08",			 //PNG image data, 32 x 32, 8-bit grayscale, non-interlaced
					"basn2c08",			 //PNG image data, 32 x 32, 8-bit/color RGB, non-interlaced
					"basn3p08",			 //PNG image data, 32 x 32, 8-bit colormap, non-interlaced
					"basn4a08",			 //PNG image data, 32 x 32, 8-bit gray+alpha, non-interlaced
					"basn6a08",			 //PNG image data, 32 x 32, 8-bit/color RGBA, non-interlaced
				]; 
				
				foreach(file; files)
				{
					//writefln("%s", file);
					auto a = read_image(png_path ~ file ~ ".png", ColFmt.RGBA); 
					auto b = read_image(tga_path ~ file ~ ".tga", ColFmt.RGBA); 
					auto c = read_image(bmp_path ~ file ~ ".bmp", ColFmt.RGBA); 
					assert(a.w == b.w && a.w == c.w); 
					assert(a.h == b.h && a.h == c.h); 
					assert(a.pixels.length == b.pixels.length && a.pixels.length == c.pixels.length); 
					foreach(i; 0 .. a.pixels.length)
					{
						assert(a.pixels[i] == b.pixels[i], "png/tga"); 
						assert(a.pixels[i] == c.pixels[i], "png/bmp"); 
					}
				}
			} 
		}version(/+$DIDE_REGION BMP+/all)
		{
			//module imageformats.bmp; 
			
			import std.bitmanip	: littleEndianToNative, nativeToLittleEndian; 
			import std.typecons	: scoped; 
			//import imageformats; 
			
			private: 
			
			immutable bmp_header = ['B', 'M']; 
			
			/// Reads a BMP image. req_chans defines the format of returned image
			/// (you can use ColFmt here).
			public IFImage read_bmp(in char[] filename, long req_chans = 0)
			{
				auto reader = scoped!FileReader(filename); 
				return read_bmp(reader, req_chans); 
			} 
			
			/// Reads an image from a buffer containing a BMP image. req_chans defines the
			/// format of returned image (you can use ColFmt here).
			public IFImage read_bmp_from_mem(in ubyte[] source, long req_chans = 0)
			{
				auto reader = scoped!MemReader(source); 
				return read_bmp(reader, req_chans); 
			} 
			
			/// Returns the header of a BMP file.
			public BMP_Header read_bmp_header(in char[] filename)
			{
				auto reader = scoped!FileReader(filename); 
				return read_bmp_header(reader); 
			} 
			
			/// Reads the image header from a buffer containing a BMP image.
			public BMP_Header read_bmp_header_from_mem(in ubyte[] source)
			{
				auto reader = scoped!MemReader(source); 
				return read_bmp_header(reader); 
			} 
			
			/// Header of a BMP file.
			public struct BMP_Header
			{
				uint file_size; 
				uint pixel_data_offset; 
				
				uint dib_size; 
				int width; 
				int height; 
				ushort planes; 
				int bits_pp; 
				uint dib_version; 
				DibV1 dib_v1; 
				DibV2 dib_v2; 
				uint dib_v3_alpha_mask; 
				DibV4 dib_v4; 
				DibV5 dib_v5; 
			} 
			
			/// Part of BMP header, not always present.
			public struct DibV1
			{
				uint compression; 
				uint idat_size; 
				uint pixels_per_meter_x; 
				uint pixels_per_meter_y; 
				uint palette_length; 
				uint important_color_count; 
			} 
			
			/// Part of BMP header, not always present.
			public struct DibV2
			{
				uint red_mask; 
				uint green_mask; 
				uint blue_mask; 
			} 
			
			/// Part of BMP header, not always present.
			public struct DibV4
			{
				uint color_space_type; 
				ubyte[36] color_space_endpoints; 
				uint gamma_red; 
				uint gamma_green; 
				uint gamma_blue; 
			} 
			
			/// Part of BMP header, not always present.
			public struct DibV5
			{
				uint icc_profile_data; 
				uint icc_profile_size; 
			} 
			
			/// Returns width, height and color format information via w, h and chans.
			public void read_bmp_info(in char[] filename, out int w, out int h, out int chans)
			{
				auto reader = scoped!FileReader(filename); 
				return read_bmp_info(reader, w, h, chans); 
			} 
			
			/// Returns width, height and color format information via w, h and chans.
			public void read_bmp_info_from_mem(in ubyte[] source, out int w, out int h, out int chans)
			{
				auto reader = scoped!MemReader(source); 
				return read_bmp_info(reader, w, h, chans); 
			} 
			
			/// Writes a BMP image into a file.
			public void write_bmp(in char[] file, long w, long h, in ubyte[] data, long tgt_chans = 0)
			{
				auto writer = scoped!FileWriter(file); 
				write_bmp(writer, w, h, data, tgt_chans); 
			} 
			
			/// Writes a BMP image into a buffer.
			public ubyte[] write_bmp_to_mem(long w, long h, in ubyte[] data, long tgt_chans = 0)
			{
				auto writer = scoped!MemWriter(); 
				write_bmp(writer, w, h, data, tgt_chans); 
				return writer.result; 
			} 
			
			//Detects whether a BMP image is readable from stream.
			package bool detect_bmp(Reader stream)
			{
				try
				{
					ubyte[18] tmp = void;  //bmp header + size of dib header
					stream.readExact(tmp, tmp.length); 
					size_t ds = littleEndianToNative!uint(tmp[14..18]); 
					return (
						tmp[0..2] == bmp_header
									&& (ds == 12 || ds == 40 || ds == 52 || ds == 56 || ds == 108 || ds == 124)
					); 
				}catch(Throwable)
				{ return false; }finally
				{ stream.seek(0, SEEK_SET); }
			} 
			
			BMP_Header read_bmp_header(Reader stream)
			{
				ubyte[18] tmp = void;  //bmp header + size of dib header
				stream.readExact(tmp[], tmp.length); 
				
				if(tmp[0..2] != bmp_header)
				throw new ImageIOException("corrupt header"); 
				
				uint dib_size = littleEndianToNative!uint(tmp[14..18]); 
				uint dib_version; 
				switch(dib_size)
				{
					case 12: dib_version = 0; break; 
					case 40: dib_version = 1; break; 
					case 52: dib_version = 2; break; 
					case 56: dib_version = 3; break; 
					case 108: dib_version = 4; break; 
					case 124: dib_version = 5; break; 
					default: throw new ImageIOException("unsupported dib version"); 
				}
				auto dib_header = new ubyte[dib_size-4]; 
				stream.readExact(dib_header[], dib_header.length); 
				
				DibV1 dib_v1; 
				DibV2 dib_v2; 
				uint dib_v3_alpha_mask; 
				DibV4 dib_v4; 
				DibV5 dib_v5; 
				
				if(1 <= dib_version)
				{
					DibV1 v1 = {
						compression	: littleEndianToNative!uint(dib_header[12..16]),
						idat_size	: littleEndianToNative!uint(dib_header[16..20]),
						pixels_per_meter_x	: littleEndianToNative!uint(dib_header[20..24]),
						pixels_per_meter_y	: littleEndianToNative!uint(dib_header[24..28]),
						palette_length	: littleEndianToNative!uint(dib_header[28..32]),
						important_color_count	: littleEndianToNative!uint(dib_header[32..36]),
					}; 
					dib_v1 = v1; 
				}
				
				if(2 <= dib_version)
				{
					DibV2 v2 = {
						red_mask	           :	littleEndianToNative!uint(dib_header[36..40]),
						green_mask		: littleEndianToNative!uint(dib_header[40..44]),
						blue_mask	           : littleEndianToNative!uint(dib_header[44..48]),
					}; 
					dib_v2 = v2; 
				}
				
				if(3 <= dib_version)
				{ dib_v3_alpha_mask = littleEndianToNative!uint(dib_header[48..52]); }
				
				if(4 <= dib_version)
				{
					DibV4 v4 = {
						color_space_type	: littleEndianToNative!uint(dib_header[52..56]),
						color_space_endpoints	: dib_header[56..92],
						gamma_red	: littleEndianToNative!uint(dib_header[92..96]),
						gamma_green	: littleEndianToNative!uint(dib_header[96..100]),
						gamma_blue	: littleEndianToNative!uint(dib_header[100..104]),
					}; 
					dib_v4 = v4; 
				}
				
				if(5 <= dib_version)
				{
					DibV5 v5 = {
						icc_profile_data					 : littleEndianToNative!uint(dib_header[108..112]),
						icc_profile_size					 : littleEndianToNative!uint(dib_header[112..116]),
					}; 
					dib_v5 = v5; 
				}
				
				int width, height; ushort planes; int bits_pp; 
				if(0 == dib_version)
				{
					width = littleEndianToNative!ushort(dib_header[0..2]); 
					height = littleEndianToNative!ushort(dib_header[2..4]); 
					planes = littleEndianToNative!ushort(dib_header[4..6]); 
					bits_pp = littleEndianToNative!ushort(dib_header[6..8]); 
				}else
				{
					width = littleEndianToNative!int(dib_header[0..4]); 
					height = littleEndianToNative!int(dib_header[4..8]); 
					planes = littleEndianToNative!ushort(dib_header[8..10]); 
					bits_pp = littleEndianToNative!ushort(dib_header[10..12]); 
				}
				
				BMP_Header header = {
					file_size	    : littleEndianToNative!uint(tmp[2..6]),
					pixel_data_offset	    : littleEndianToNative!uint(tmp[10..14]),
					width	    : width,
					height				 : height,
					planes				 : planes,
					bits_pp	    : bits_pp,
					dib_version	    : dib_version,
					dib_v1				 : dib_v1,
					dib_v2				 : dib_v2,
					dib_v3_alpha_mask	    : dib_v3_alpha_mask,
					dib_v4				 : dib_v4,
					dib_v5				 : dib_v5,
				}; 
				return header; 
			} 
			
			enum CMP_RGB	= 0; 
			enum CMP_BITS	= 3; 
			
			package IFImage read_bmp(Reader stream, long req_chans = 0)
			{
				if(req_chans < 0 || 4 < req_chans)
				throw new ImageIOException("unknown color format"); 
				
				BMP_Header hdr = read_bmp_header(stream); 
				
				if(hdr.width < 1 || hdr.height == 0)
				{ throw new ImageIOException("invalid dimensions"); }
				if(
					hdr.pixel_data_offset < (14 + hdr.dib_size)
						|| hdr.pixel_data_offset > 0xffffff /*arbitrary*/
				)
				{ throw new ImageIOException("invalid pixel data offset"); }
				if(hdr.planes != 1)
				{ throw new ImageIOException("not supported"); }
				
				auto bytes_pp						 = 1; 
				bool paletted						 = true; 
				size_t palette_length = 256; 
				bool rgb_masked	   = false; 
				auto pe_bytes_pp	   = 3; 
				
				if(1 <= hdr.dib_version)
				{
					if(256 < hdr.dib_v1.palette_length)
					throw new ImageIOException("ivnalid palette length"); 
					if(
						hdr.bits_pp <= 8 &&
								   (hdr.dib_v1.palette_length == 0 || hdr.dib_v1.compression != CMP_RGB)
					)
					throw new ImageIOException("unsupported format"); 
					if(hdr.dib_v1.compression != CMP_RGB && hdr.dib_v1.compression != CMP_BITS)
					throw new ImageIOException("unsupported compression"); 
					
					switch(hdr.bits_pp)
					{
						case 8	: bytes_pp = 1; paletted = true; break; 
						case 24	: bytes_pp = 3; paletted = false; break; 
						case 32	: bytes_pp = 4; paletted = false; break; 
						default: throw new ImageIOException("not supported"); 
					}
					
					palette_length = hdr.dib_v1.palette_length; 
					rgb_masked = hdr.dib_v1.compression == CMP_BITS; 
					pe_bytes_pp = 4; 
				}
				
				size_t mask_to_idx(uint mask)
				{
					switch(mask)
					{
						case 0xff00_0000: return 3; 
						case 0x00ff_0000: return 2; 
						case 0x0000_ff00: return 1; 
						case 0x0000_00ff: return 0; 
						default: throw new ImageIOException("unsupported mask"); 
					}
				} 
				
				size_t redi = 2; 
				size_t greeni = 1; 
				size_t bluei = 0; 
				if(rgb_masked && hdr.dib_version>1)
				{
					 //het: version 1 has no specific masks
					if(hdr.dib_version < 2)
					throw new ImageIOException("invalid format"); 
					redi = mask_to_idx(hdr.dib_v2.red_mask); 
					greeni = mask_to_idx(hdr.dib_v2.green_mask); 
					bluei = mask_to_idx(hdr.dib_v2.blue_mask); 
				}
				
				bool alpha_masked = false; 
				size_t alphai = 0; 
				if(bytes_pp == 4 && 3 <= hdr.dib_version && hdr.dib_v3_alpha_mask != 0)
				{
					alpha_masked = true; 
					alphai = mask_to_idx(hdr.dib_v3_alpha_mask); 
				}
				
				ubyte[] depaletted_line = null; 
				ubyte[] palette = null; 
				if(paletted)
				{
					depaletted_line = new ubyte[hdr.width * pe_bytes_pp]; 
					palette = new ubyte[palette_length * pe_bytes_pp]; 
					stream.readExact(palette[], palette.length); 
				}
				
				stream.seek(hdr.pixel_data_offset, SEEK_SET); 
				
				immutable tgt_chans = (0 < req_chans) ? req_chans
													  : (alpha_masked) ? _ColFmt.RGBA
																	   : _ColFmt.RGB; 
				
				const src_fmt = (!paletted || pe_bytes_pp == 4) ? _ColFmt.BGRA : _ColFmt.BGR; 
				const LineConv!ubyte convert = get_converter!ubyte(src_fmt, tgt_chans); 
				
				immutable size_t src_linesize = hdr.width * bytes_pp;  //without padding
				immutable size_t src_pad = 3 - ((src_linesize-1) % 4); 
				immutable ptrdiff_t tgt_linesize = (hdr.width * cast(int) tgt_chans); 
				
				immutable ptrdiff_t tgt_stride	= (hdr.height < 0) ? tgt_linesize : -tgt_linesize; 
				ptrdiff_t ti	= (hdr.height < 0) ? 0 : (hdr.height-1) * tgt_linesize; 
				
				auto src_line_buf	= new ubyte[src_linesize + src_pad]; 
				auto bgra_line_buf	= (paletted) ? null : new ubyte[hdr.width * 4]; 
				auto result	= new ubyte[hdr.width * abs(hdr.height) * cast(int) tgt_chans]; 
				
				foreach(_; 0 .. abs(hdr.height))
				{
					stream.readExact(src_line_buf[], src_line_buf.length); 
					auto src_line = src_line_buf[0..src_linesize]; 
					
					if(paletted)
					{
						size_t ps = pe_bytes_pp; 
						size_t di = 0; 
						foreach(idx; src_line[])
						{
							if(idx > palette_length)
							throw new ImageIOException("invalid palette index"); 
							size_t i = idx * ps; 
							depaletted_line[di .. di+ps] = palette[i .. i+ps]; 
							if(ps == 4)
							{ depaletted_line[di+3] = 255; }
							di += ps; 
						}
						convert(depaletted_line[], result[ti .. (ti+tgt_linesize)]); 
					}else
					{
						for(size_t si, di;   si < src_line.length;   si+=bytes_pp, di+=4)
						{
							bgra_line_buf[di + 0] = src_line[si + bluei]; 
							bgra_line_buf[di + 1] = src_line[si + greeni]; 
							bgra_line_buf[di + 2] = src_line[si + redi]; 
							bgra_line_buf[di + 3] = (alpha_masked) ? src_line[si + alphai]
																   : 255; 
						}
						convert(bgra_line_buf[], result[ti .. (ti+tgt_linesize)]); 
					}
					
					ti += tgt_stride; 
				}
				
				IFImage ret = {
					w	: hdr.width,
					h	: abs(hdr.height),
					c	: cast(ColFmt) tgt_chans,
					pixels	: result,
				}; 
				return ret; 
			} 
			
			package void read_bmp_info(Reader stream, out int w, out int h, out int chans)
			{
				BMP_Header hdr = read_bmp_header(stream); 
				w = abs(hdr.width); 
				h = abs(hdr.height); 
				chans = (hdr.dib_version >= 3 && hdr.dib_v3_alpha_mask != 0 && hdr.bits_pp == 32)
						 ? ColFmt.RGBA
						 : ColFmt.RGB; 
			} 
			
			//----------------------------------------------------------------------
			//BMP encoder
			
			//Writes RGB or RGBA data.
			void write_bmp(Writer stream, long w, long h, in ubyte[] data, long tgt_chans = 0)
			{
				if(w < 1 || h < 1 || 0x7fff < w || 0x7fff < h)
				throw new ImageIOException("invalid dimensions"); 
				size_t src_chans = data.length / cast(size_t) w / cast(size_t) h; 
				if(src_chans < 1 || 4 < src_chans)
				throw new ImageIOException("invalid channel count"); 
				if(tgt_chans != 0 && tgt_chans != 3 && tgt_chans != 4)
				throw new ImageIOException("unsupported format for writing"); 
				if(src_chans * w * h != data.length)
				throw new ImageIOException("mismatching dimensions and length"); 
				
				if(tgt_chans == 0)
				tgt_chans = (src_chans == 1 || src_chans == 3) ? 3 : 4; 
				
				const dib_size = 108; 
				const size_t tgt_linesize = cast(size_t) (w * tgt_chans); 
				const size_t pad = 3 - ((tgt_linesize-1) & 3); 
				const size_t idat_offset = 14 + dib_size; 	//bmp file header + dib header
				const size_t filesize = idat_offset + cast(size_t) h *	(tgt_linesize + pad); 
				if(filesize > 0xffff_ffff)
				{ throw new ImageIOException("image too large"); }
				
				ubyte[14+dib_size] hdr; 
				hdr[0] = 0x42; 
				hdr[1] = 0x4d; 
				hdr[2..6] = nativeToLittleEndian(cast(uint) filesize); 
				hdr[6..10] = 0;                                                //reserved
				hdr[10..14] = nativeToLittleEndian(cast(uint) idat_offset);    //offset of pixel data
				hdr[14..18] = nativeToLittleEndian(cast(uint) dib_size);       //dib header size
				hdr[18..22] = nativeToLittleEndian(cast(int) w); 
				hdr[22..26] = nativeToLittleEndian(cast(int) h);            //positive -> bottom-up
				hdr[26..28] = nativeToLittleEndian(cast(ushort) 1);         //planes
				hdr[28..30] = nativeToLittleEndian(cast(ushort) (tgt_chans * 8)); //bits per pixel
				hdr[30..34] = nativeToLittleEndian((tgt_chans == 3) ? CMP_RGB : CMP_BITS); 
				hdr[34..54] = 0;                                          //rest of dib v1
				if(tgt_chans == 3)
				{
					hdr[54..70] = 0;    //dib v2 and v3
				}else
				{
					static immutable ubyte[16] b =
					[
						0, 0, 0xff, 0,
						0, 0xff, 0, 0,
						0xff, 0, 0, 0,
						0, 0, 0, 0xff
					]; 
					hdr[54..70] = b; 
				}
				static immutable ubyte[4] BGRs = ['B', 'G', 'R', 's']; 
				hdr[70..74] = BGRs; 
				hdr[74..122] = 0; 
				stream.rawWrite(hdr); 
				
				const LineConv!ubyte convert =
					get_converter!ubyte(src_chans, (tgt_chans == 3) ? _ColFmt.BGR : _ColFmt.BGRA); 
				
				auto tgt_line = new ubyte[tgt_linesize + pad]; 
				const size_t src_linesize = cast(size_t) w * src_chans; 
				size_t si = cast(size_t) h * src_linesize; 
				
				foreach(_; 0..h)
				{
					si -= src_linesize; 
					convert(data[si .. si + src_linesize], tgt_line[0..tgt_linesize]); 
					stream.rawWrite(tgt_line); 
				}
				
				stream.flush(); 
			} 
		}version(/+$DIDE_REGION PNG+/all)
		{
			//module imageformats.png; 
			
			import std.algorithm	: reverse; 
			import std.bitmanip	: bigEndianToNative, nativeToBigEndian; 
			import std.digest.crc	: CRC32, crc32Of; 
			import std.zlib	: UnCompress, HeaderFormat, compress; 
			import std.typecons	: scoped; 
			
			private: 
			
			/// Header of a PNG file.
			public struct PNG_Header
			{
				int width; 
				int height; 
				ubyte bit_depth; 
				ubyte color_type; 
				ubyte compression_method; 
				ubyte filter_method; 
				ubyte interlace_method; 
			} 
			
			/// Returns the header of a PNG file.
			public PNG_Header read_png_header(in char[] filename)
			{
				auto reader = scoped!FileReader(filename); 
				return read_png_header(reader); 
			} 
			
			/// Returns the header of the image in the buffer.
			public PNG_Header read_png_header_from_mem(in ubyte[] source)
			{
				auto reader = scoped!MemReader(source); 
				return read_png_header(reader); 
			} 
			
			/// Reads an 8-bit or 16-bit PNG image and returns it as an 8-bit image.
			/// req_chans defines the format of returned image (you can use ColFmt here).
			public IFImage read_png(in char[] filename, long req_chans = 0)
			{
				auto reader = scoped!FileReader(filename); 
				return read_png(reader, req_chans); 
			} 
			
			/// Reads an 8-bit or 16-bit PNG image from a buffer and returns it as an
			/// 8-bit image.  req_chans defines the format of returned image (you can use
			/// ColFmt here).
			public IFImage read_png_from_mem(in ubyte[] source, long req_chans = 0)
			{
				auto reader = scoped!MemReader(source); 
				return read_png(reader, req_chans); 
			} 
			
			/// Reads an 8-bit or 16-bit PNG image and returns it as a 16-bit image.
			/// req_chans defines the format of returned image (you can use ColFmt here).
			public IFImage16 read_png16(in char[] filename, long req_chans = 0)
			{
				auto reader = scoped!FileReader(filename); 
				return read_png16(reader, req_chans); 
			} 
			
			/// Reads an 8-bit or 16-bit PNG image from a buffer and returns it as a
			/// 16-bit image.  req_chans defines the format of returned image (you can use
			/// ColFmt here).
			public IFImage16 read_png16_from_mem(in ubyte[] source, long req_chans = 0)
			{
				auto reader = scoped!MemReader(source); 
				return read_png16(reader, req_chans); 
			} 
			
			/// Writes a PNG image into a file.
			public void write_png(in char[] file, long w, long h, in ubyte[] data, long tgt_chans = 0)
			{
				auto writer = scoped!FileWriter(file); 
				write_png(writer, w, h, data, tgt_chans); 
			} 
			
			/// Writes a PNG image into a buffer.
			public ubyte[] write_png_to_mem(long w, long h, in ubyte[] data, long tgt_chans = 0)
			{
				auto writer = scoped!MemWriter(); 
				write_png(writer, w, h, data, tgt_chans); 
				return writer.result; 
			} 
			
			/// Returns width, height and color format information via w, h and chans.
			public void read_png_info(in char[] filename, out int w, out int h, out int chans)
			{
				auto reader = scoped!FileReader(filename); 
				return read_png_info(reader, w, h, chans); 
			} 
			
			/// Returns width, height and color format information via w, h and chans.
			public void read_png_info_from_mem(in ubyte[] source, out int w, out int h, out int chans)
			{
				auto reader = scoped!MemReader(source); 
				return read_png_info(reader, w, h, chans); 
			} 
			
			///Detects whether a PNG image is readable from stream.
			package bool detect_png(Reader stream)
			{
				try
				{
					ubyte[8] tmp = void; 
					stream.readExact(tmp, tmp.length); 
					return (tmp[0..8] == png_file_header[0..$]); 
				}catch(Throwable)
				{ return false; }finally
				{ stream.seek(0, SEEK_SET); }
			} 
			
			PNG_Header read_png_header(Reader stream)
			{
				ubyte[33] tmp = void;  //file header, IHDR len+type+data+crc
				stream.readExact(tmp, tmp.length); 
				
				ubyte[4] crc = crc32Of(tmp[12..29]); 
				reverse(crc[]); 
				if(
					tmp[0..8] != png_file_header[0..$] ||
					tmp[8..16] != png_image_header ||
					crc != tmp[29..33]
				)
				throw new ImageIOException("corrupt header"); 
				
				return (
					mixin(體!((PNG_Header),q{
						width	: bigEndianToNative!int(tmp[16..20]),
						height	: bigEndianToNative!int(tmp[20..24]),
						bit_depth	: tmp[24],
						color_type	: tmp[25],
						compression_method	: tmp[26],
						filter_method	: tmp[27],
						interlace_method	: tmp[28],
					}))
				); 
			} 
			
			package IFImage read_png(Reader stream, long req_chans = 0)
			{
				PNG_Decoder dc = init_png_decoder(stream, req_chans, 8); 
				return (
					mixin(體!((IFImage),q{
						w	: dc.w,
						h	: dc.h,
						c	: (cast(ColFmt)(dc.tgt_chans)),
						pixels	: decode_png(dc).bpc8
					}))
				); 
			} 
			
			IFImage16 read_png16(Reader stream, long req_chans = 0)
			{
				PNG_Decoder dc = init_png_decoder(stream, req_chans, 16); 
				return (
					mixin(體!((IFImage16),q{
						w	: dc.w,
						h	: dc.h,
						c	: (cast(ColFmt)(dc.tgt_chans)),
						pixels	: decode_png(dc).bpc16
					}))
				); 
			} 
			
			PNG_Decoder init_png_decoder(Reader stream, long req_chans, int req_bpc)
			{
				if(req_chans < 0 || 4 < req_chans)
				throw new ImageIOException("come on..."); 
				
				PNG_Header hdr = read_png_header(stream); 
				
				if(
					hdr.width < 1 || hdr.height < 1 || 
					int.max < (cast(ulong)(hdr.width * hdr.height))
				)
				throw new ImageIOException("invalid dimensions"); 
				if(
					(hdr.bit_depth != 8 && hdr.bit_depth != 16) ||
					(req_bpc != 8 && req_bpc != 16)
				)
				throw new ImageIOException("only 8-bit and 16-bit images supported"); 
				if(
					! (
						hdr.color_type == PNG_ColorType.Y	||
						hdr.color_type == PNG_ColorType.RGB 	||
						hdr.color_type == PNG_ColorType.Idx	||
						hdr.color_type == PNG_ColorType.YA	||
						hdr.color_type == PNG_ColorType.RGBA
					)
				)
				throw new ImageIOException("color type not supported"); 
				if(
					hdr.compression_method != 0 || hdr.filter_method != 0 ||
					(hdr.interlace_method != 0 && hdr.interlace_method != 1)
				)
				throw new ImageIOException("not supported"); 
				
				auto dc = (
					mixin(體!((PNG_Decoder),q{
						stream	: stream,
						src_indexed	: (hdr.color_type == PNG_ColorType.Idx),
						src_chans	: channels(cast(PNG_ColorType)(hdr.color_type)),
						bpc	: hdr.bit_depth,
						req_bpc	: req_bpc,
						ilace	: hdr.interlace_method,
						w	: hdr.width,
						h	: hdr.height,
					}))
				); 
				dc.tgt_chans = ((req_chans == 0)?(dc.src_chans) :((cast(int)(req_chans)))); 
				return dc; 
			} 
			
			immutable ubyte[8] png_file_header =
				[0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a]; 
			
			immutable ubyte[8] png_image_header = 
				[0x0, 0x0, 0x0, 0xd, 'I','H','D','R']; 
			
			int channels(PNG_ColorType ct) pure nothrow
			{
				final switch(ct)
				with(PNG_ColorType)
				{
					case Y: 	return 1; 
					case RGB: 	return 3; 
					case YA: 	return 2; 
					case RGBA, Idx: 	return 4; 
				}
				
			} 
			
			PNG_ColorType color_type(long channels) pure nothrow
			{
				switch(channels)
				{
					case 1: 	return PNG_ColorType.Y; 
					case 2: 	return PNG_ColorType.YA; 
					case 3: 	return PNG_ColorType.RGB; 
					case 4: 	return PNG_ColorType.RGBA; 
					default: 	assert(0); 
				}
			} 
			
			struct PNG_Decoder
			{
				Reader stream; 
				bool src_indexed; 
				int src_chans; 
				int tgt_chans; 
				int bpc; 
				int req_bpc; 
				int w, h; 
				ubyte ilace; 
				
				UnCompress uc; 
				CRC32 crc; 
				ubyte[12] chunkmeta;  //crc | length and type
				ubyte[] read_buf; 
				ubyte[] uc_buf;     //uncompressed
				ubyte[] palette; 
				ubyte[] transparency; 
			} 
			
			Buffer decode_png(ref PNG_Decoder dc)
			{
				dc.uc = new UnCompress(HeaderFormat.deflate); 
				dc.read_buf = new ubyte[4096]; 
				
				enum Stage
				{
					IHDR_parsed,
					PLTE_parsed,
					IDAT_parsed,
					IEND_parsed,
				} 
				
				Buffer result; 
				auto stage = Stage.IHDR_parsed; 
				dc.stream.readExact(dc.chunkmeta[4..$], 8);  //next chunk's len and type
				
				while(stage != Stage.IEND_parsed)
				{
					int len = bigEndianToNative!int(dc.chunkmeta[4..8]); 
					if(len < 0)
					throw new ImageIOException("chunk too long"); 
					
					//standard allows PLTE chunk for non-indexed images too but we don't
					dc.crc.put(dc.chunkmeta[8..12]);  //type
					switch(cast(char[]) dc.chunkmeta[8..12])
					{
							//chunk type
						case "IDAT": 
							if(
							! (
								stage == Stage.IHDR_parsed ||
								(stage == Stage.PLTE_parsed && dc.src_indexed)
							)
						)
						throw new ImageIOException("corrupt chunk stream"); 
							result = read_IDAT_stream(dc, len); 
							stage = Stage.IDAT_parsed; 
							break; 
						case "PLTE": 
							if(stage != Stage.IHDR_parsed)
						throw new ImageIOException("corrupt chunk stream"); 
							int entries = len / 3; 
							if(len % 3 != 0 || 256 < entries)
						throw new ImageIOException("corrupt chunk"); 
							dc.palette = new ubyte[len]; 
							dc.stream.readExact(dc.palette, dc.palette.length); 
							dc.crc.put(dc.palette); 
							dc.stream.readExact(dc.chunkmeta, 12); //crc | len, type
							ubyte[4] crc = dc.crc.finish; 
							reverse(crc[]); 
							if(crc != dc.chunkmeta[0..4])
						throw new ImageIOException("corrupt chunk"); 
							stage = Stage.PLTE_parsed; 
							break; 
						case "tRNS": 
							if(
							! (
								stage == Stage.IHDR_parsed ||
								(stage == Stage.PLTE_parsed && dc.src_indexed)
							)
						)
						throw new ImageIOException("corrupt chunk stream"); 
							if(dc.src_indexed)
						{
							size_t entries = dc.palette.length / 3; 
							if(len > entries)
							throw new ImageIOException("corrupt chunk"); 
						}
							dc.transparency = new ubyte[len]; 
							dc.stream.readExact(dc.transparency, dc.transparency.length); 
							dc.stream.readExact(dc.chunkmeta, 12); 
							dc.crc.put(dc.transparency); 
							ubyte[4] crc = dc.crc.finish; 
							reverse(crc[]); 
							if(crc != dc.chunkmeta[0..4])
						throw new ImageIOException("corrupt chunk"); 
							break; 
						case "IEND": 
							if(stage != Stage.IDAT_parsed)
						throw new ImageIOException("corrupt chunk stream"); 
							dc.stream.readExact(dc.chunkmeta, 4); //crc
							static immutable ubyte[4] expectedCRC = [0xae, 0x42, 0x60, 0x82]; 
							if(len != 0 || dc.chunkmeta[0..4] != expectedCRC)
						throw new ImageIOException("corrupt chunk"); 
							stage = Stage.IEND_parsed; 
							break; 
						case "IHDR": 
							throw new ImageIOException("corrupt chunk stream"); 
						default: 
							//unknown chunk, ignore but check crc
							while(0 < len)
						{
							size_t bytes = min(len, dc.read_buf.length); 
							dc.stream.readExact(dc.read_buf, bytes); 
							len -= bytes; 
							dc.crc.put(dc.read_buf[0..bytes]); 
						}
							dc.stream.readExact(dc.chunkmeta, 12); //crc | len, type
							ubyte[4] crc = dc.crc.finish; 
							reverse(crc[]); 
							if(crc != dc.chunkmeta[0..4])
						throw new ImageIOException("corrupt chunk"); 
					}
				}
				
				return result; 
			} 
			
			enum PNG_ColorType : ubyte
			{
				Y	= 0,
				RGB	= 2,
				Idx	= 3,
				YA	= 4,
				RGBA	= 6,
			} 	 enum PNG_FilterType : ubyte
			{
				None	= 0,
				Sub	= 1,
				Up	= 2,
				Average	= 3,
				Paeth	= 4,
			} 	 enum InterlaceMethod
			{ None = 0, Adam7 = 1} 	 
			
			union Buffer
			{
				ubyte[] bpc8; 
				ushort[] bpc16; 
			} 
			
			Buffer read_IDAT_stream(ref PNG_Decoder dc, int len)
			{
				assert(dc.req_bpc == 8 || dc.req_bpc == 16); 
				
				bool metaready = false;     //chunk len, type, crc
				
				immutable size_t filter_step = dc.src_indexed ? 1 : dc.src_chans * ((dc.bpc == 8) ? 1 : 2); 
				
				ubyte[] depaletted = dc.src_indexed ? new ubyte[dc.w * 4] : null; 
				
				auto cline = new ubyte[dc.w * filter_step + 1]; //+1 for filter type byte
				auto pline = new ubyte[dc.w * filter_step + 1]; //+1 for filter type byte
				auto cline8 = (dc.req_bpc == 8 && dc.bpc != 8) ? new ubyte[dc.w * dc.src_chans] : null; 
				auto cline16 = (dc.req_bpc == 16)	? new ushort[dc.w * dc.src_chans] : null; 
				ubyte[]	result8	= (dc.req_bpc == 8)  ? new ubyte[dc.w * dc.h * dc.tgt_chans] : null; 
				ushort[]	result16	= (dc.req_bpc == 16) ? new ushort[dc.w * dc.h * dc.tgt_chans] : null; 
				
				const LineConv!ubyte convert8	= get_converter!ubyte(dc.src_chans, dc.tgt_chans); 
				const LineConv!ushort convert16	= get_converter!ushort(dc.src_chans, dc.tgt_chans); 
				
				if(dc.ilace == InterlaceMethod.None)
				{
					immutable size_t src_linelen = dc.w * dc.src_chans; 
					immutable size_t tgt_linelen = dc.w * dc.tgt_chans; 
					
					size_t ti = 0;    //target index
					foreach(j; 0 .. dc.h)
					{
						uncompress_line(dc, len, metaready, cline); 
						ubyte filter_type = cline[0]; 
						
						recon(cline[1..$], pline[1..$], filter_type, filter_step); 
						
						ubyte[] bytes;  //defiltered bytes or 8-bit samples from palette
						if(dc.src_indexed)
						{
							depalette(dc.palette, dc.transparency, cline[1..$], depaletted); 
							bytes = depaletted[0 .. src_linelen]; 
						}else
						{ bytes = cline[1..$]; }
						
						//convert colors
						if(dc.req_bpc == 8)
						{
							line8_from_bytes(bytes, dc.bpc, cline8); 
							convert8(cline8[0 .. src_linelen], result8[ti .. ti + tgt_linelen]); 
						}else
						{
							line16_from_bytes(bytes, dc.bpc, cline16); 
							convert16(cline16[0 .. src_linelen], result16[ti .. ti + tgt_linelen]); 
						}
						
						ti += tgt_linelen; 
						
						ubyte[] _swap = pline; 
						pline = cline; 
						cline = _swap; 
					}
				}else
				{
					//Adam7 interlacing
					
					immutable size_t[7] redw = 
						[
						(dc.w + 7) / 8,
						(dc.w + 3) / 8,
						(dc.w + 3) / 4,
						(dc.w + 1) / 4,
						(dc.w + 1) / 2,
						(dc.w + 0) / 2,
						(dc.w + 0) / 1
					]; immutable size_t[7] redh = 
						[
						(dc.h + 7) / 8,
						(dc.h + 7) / 8,
						(dc.h + 3) / 8,
						(dc.h + 3) / 4,
						(dc.h + 1) / 4,
						(dc.h + 1) / 2,
						(dc.h + 0) / 2
					]; 
					
					auto redline8 = (dc.req_bpc == 8) ? new ubyte[dc.w * dc.tgt_chans] : null; 
					auto redline16 = (dc.req_bpc == 16) ? new ushort[dc.w * dc.tgt_chans] : null; 
					
					foreach(pass; 0 .. 7)
					{
						const A7_Catapult tgt_px = a7_catapults[pass];   //target pixel
						const size_t src_linelen = redw[pass] * dc.src_chans; 
						ubyte[] cln = cline[0 .. redw[pass] * filter_step + 1]; 
						ubyte[] pln = pline[0 .. redw[pass] * filter_step + 1]; 
						pln[] = 0; 
						
						foreach(j; 0 .. redh[pass])
						{
							uncompress_line(dc, len, metaready, cln); 
							ubyte filter_type = cln[0]; 
							
							recon(cln[1..$], pln[1..$], filter_type, filter_step); 
							
							ubyte[] bytes;  //defiltered bytes or 8-bit samples from palette
							if(dc.src_indexed)
							{
								depalette(dc.palette, dc.transparency, cln[1..$], depaletted); 
								bytes = depaletted[0 .. src_linelen]; 
							}else
							{ bytes = cln[1..$]; }
							
							//convert colors and sling pixels from reduced image to final buffer
							if(dc.req_bpc == 8)
							{
								line8_from_bytes(bytes, dc.bpc, cline8); 
								convert8(cline8[0 .. src_linelen], redline8[0 .. redw[pass]*dc.tgt_chans]); 
								for(size_t i, redi; i < redw[pass]; ++i, redi += dc.tgt_chans)
								{
									size_t tgt = tgt_px(i, j, dc.w) * dc.tgt_chans; 
									result8[tgt .. tgt + dc.tgt_chans] =
										redline8[redi .. redi + dc.tgt_chans]; 
								}
							}else
							{
								line16_from_bytes(bytes, dc.bpc, cline16); 
								convert16(cline16[0 .. src_linelen], redline16[0 .. redw[pass]*dc.tgt_chans]); 
								for(size_t i, redi; i < redw[pass]; ++i, redi += dc.tgt_chans)
								{
									size_t tgt = tgt_px(i, j, dc.w) * dc.tgt_chans; 
									result16[tgt .. tgt + dc.tgt_chans] =
										redline16[redi .. redi + dc.tgt_chans]; 
								}
							}
							
							ubyte[] _swap = pln; 
							pln = cln; 
							cln = _swap; 
						}
					}
				}
				
				if(!metaready)
				{
					dc.stream.readExact(dc.chunkmeta, 12);   //crc | len & type
					ubyte[4] crc = dc.crc.finish; 
					reverse(crc[]); 
					if(crc != dc.chunkmeta[0..4])
					throw new ImageIOException("corrupt chunk"); 
				}
				
				Buffer result; 
				switch(dc.req_bpc)
				{
					case 8: result.bpc8 = result8; return result; 
					case 16: result.bpc16 = result16; return result; 
					default: throw new ImageIOException("internal error"); 
				}
			} 
			
			void line8_from_bytes(ubyte[] src, int bpc, ref ubyte[] tgt)
			{
				switch(bpc)
				{
					case 8: 
						tgt = src; 
						break; 
					case 16: 
						for(size_t k, t;   k < src.length;   k+=2, t+=1)
					{ tgt[t] = src[k]; /*truncate*/}
						break; 
					default: throw new ImageIOException("unsupported bit depth (and bug)"); 
				}
			} 
			
			void line16_from_bytes(in ubyte[] src, int bpc, ushort[] tgt)
			{
				switch(bpc)
				{
					case 8: 
						for(size_t k;   k < src.length;   k+=1)
					{ tgt[k] = src[k] * 256 + 128; }
						break; 
					case 16: 
						for(size_t k, t;   k < src.length;   k+=2, t+=1)
					{ tgt[t] = src[k] << 8 | src[k+1]; }
						break; 
					default: throw new ImageIOException("unsupported bit depth (and bug)"); 
				}
			} 
			
			void depalette(
				in ubyte[] palette, in ubyte[] transparency, 
				in ubyte[] src_line, ubyte[] depaletted
			) pure
			{
				for(size_t s, d;  s < src_line.length;  s+=1, d+=4)
				{
					ubyte pid = src_line[s]; 
					size_t pidx = pid * 3; 
					if(palette.length < pidx + 3)
					throw new ImageIOException("palette index wrong"); 
					depaletted[d .. d+3] = palette[pidx .. pidx+3]; 
					depaletted[d+3] = (pid < transparency.length) ? transparency[pid] : 255; 
				}
			} 
			
			alias A7_Catapult = size_t function(size_t redx, size_t redy, size_t dstw); 
			immutable A7_Catapult[7] a7_catapults = [
				&a7_red1_to_dst,
				&a7_red2_to_dst,
				&a7_red3_to_dst,
				&a7_red4_to_dst,
				&a7_red5_to_dst,
				&a7_red6_to_dst,
				&a7_red7_to_dst,
			]; 
			
			pure nothrow
			{
				size_t a7_red1_to_dst(size_t redx, size_t redy, size_t dstw)
				{ return redy*8*dstw + redx*8;     } 
				size_t a7_red2_to_dst(size_t redx, size_t redy, size_t dstw)
				{ return redy*8*dstw + redx*8+4;   } 
				size_t a7_red3_to_dst(size_t redx, size_t redy, size_t dstw)
				{ return (redy*8+4)*dstw + redx*4; } 
				size_t a7_red4_to_dst(size_t redx, size_t redy, size_t dstw)
				{ return redy*4*dstw + redx*4+2;   } 
				size_t a7_red5_to_dst(size_t redx, size_t redy, size_t dstw)
				{ return (redy*4+2)*dstw + redx*2; } 
				size_t a7_red6_to_dst(size_t redx, size_t redy, size_t dstw)
				{ return redy*2*dstw + redx*2+1;   } 
				size_t a7_red7_to_dst(size_t redx, size_t redy, size_t dstw)
				{ return (redy*2+1)*dstw + redx;   } 
			} 
			
			void uncompress_line(ref PNG_Decoder dc, ref int length, ref bool metaready, ubyte[] dst)
			{
				size_t readysize = min(dst.length, dc.uc_buf.length); 
				dst[0 .. readysize] = dc.uc_buf[0 .. readysize]; 
				dc.uc_buf = dc.uc_buf[readysize .. $]; 
				
				if(readysize == dst.length)
				return; 
				
				while(readysize != dst.length)
				{
					//need new data for dc.uc_buf...
					if(length <= 0)
					{
						  //IDAT is read -> read next chunks meta
						dc.stream.readExact(dc.chunkmeta, 12);   //crc | len & type
						ubyte[4] crc = dc.crc.finish; 
						reverse(crc[]); 
						if(crc != dc.chunkmeta[0..4])
						throw new ImageIOException("corrupt chunk"); 
						
						length = bigEndianToNative!int(dc.chunkmeta[4..8]); 
						if(dc.chunkmeta[8..12] != "IDAT")
						{
							//no new IDAT chunk so flush, this is the end of the IDAT stream
							metaready = true; 
							dc.uc_buf = cast(ubyte[]) dc.uc.flush(); 
							size_t part2 = dst.length - readysize; 
							if(dc.uc_buf.length < part2)
							throw new ImageIOException("not enough data"); 
							dst[readysize .. readysize+part2] = dc.uc_buf[0 .. part2]; 
							dc.uc_buf = dc.uc_buf[part2 .. $]; 
							return; 
						}
						if(
							length <= 0//empty IDAT chunk
						)
						throw new	ImageIOException("not enough data"); 
						dc.crc.put(dc.chunkmeta[8..12]); 	//type
					}
					
					size_t bytes = min(length, dc.read_buf.length); 
					dc.stream.readExact(dc.read_buf, bytes); 
					length -= bytes; 
					dc.crc.put(dc.read_buf[0..bytes]); 
					
					if(bytes <= 0)
					throw new ImageIOException("not enough data"); 
					
					dc.uc_buf = cast(ubyte[]) dc.uc.uncompress(dc.read_buf[0..bytes].dup); 
					
					size_t part2 = min(dst.length - readysize, dc.uc_buf.length); 
					dst[readysize .. readysize+part2] = dc.uc_buf[0 .. part2]; 
					dc.uc_buf = dc.uc_buf[part2 .. $]; 
					readysize += part2; 
				}
			} 
			
			void recon(ubyte[] cline, in ubyte[] pline, ubyte ftype, size_t fstep) pure
			{
				switch(ftype)
				with(PNG_FilterType)
				{
					case None: 
						break; 
					case Sub: 
						foreach(k; fstep .. cline.length)
					cline[k] += cline[k-fstep]; 
						break; 
					case Up: 
						foreach(k; 0 .. cline.length)
					cline[k] += pline[k]; 
						break; 
					case Average: 
						foreach(k; 0 .. fstep)
					cline[k] += pline[k] / 2; 
						foreach(k; fstep .. cline.length)
					cline[k] += cast(ubyte)
					((cast(uint) cline[k-fstep] + cast(uint) pline[k]) / 2); 
						break; 
					case Paeth: 
						foreach(i; 0 .. fstep)
					cline[i] += paeth(0, pline[i], 0); 
						foreach(i; fstep .. cline.length)
					cline[i] += paeth(cline[i-fstep], pline[i], pline[i-fstep]); 
						break; 
					default: 
						throw new ImageIOException("filter type not supported"); 
				}
				
			} 
			
			ubyte paeth(ubyte a, ubyte b, ubyte c) pure nothrow
			{
				int pc = cast(int) c; 
				int pa = cast(int) b - pc; 
				int pb = cast(int) a - pc; 
				pc = pa + pb; 
				if(pa < 0)
				pa = -pa; 
				if(pb < 0)
				pb = -pb; 
				if(pc < 0)
				pc = -pc; 
				
				if(pa <= pb && pa <= pc)
				{ return a; }else if(pb <= pc)
				{ return b; }
				return c; 
			} 
			
			//----------------------------------------------------------------------
			//PNG encoder
			
			void write_png(Writer stream, long w, long h, in ubyte[] data, long tgt_chans = 0)
			{
				if(w < 1 || h < 1 || int.max < w || int.max < h)
				throw new ImageIOException("invalid dimensions"); 
				uint src_chans = cast(uint) (data.length / w / h); 
				if(src_chans < 1 || 4 < src_chans || tgt_chans < 0 || 4 < tgt_chans)
				throw new ImageIOException("invalid channel count"); 
				if(src_chans * w * h != data.length)
				throw new ImageIOException("mismatching dimensions and length"); 
				
				PNG_Encoder ec = {
					stream	: stream,
					w	: cast(size_t) w,
					h	: cast(size_t) h,
					src_chans	: src_chans,
					tgt_chans	: tgt_chans ? cast(uint) tgt_chans : src_chans,
					data	: data,
				}; 
				
				write_png(ec); 
				stream.flush(); 
			} 
			
			struct PNG_Encoder
			{
				Writer stream; 
				size_t w, h; 
				uint src_chans; 
				uint tgt_chans; 
				const(ubyte)[] data; 
				
				CRC32 crc; 
				
				uint writelen; 	//how much written of current idat data
				ubyte[] chunk_buf; 		//len type data crc
				ubyte[] data_buf; 	 //slice of chunk_buf, for just chunk data
			} 
			
			void write_png(ref PNG_Encoder ec)
			{
				ubyte[33] hdr = void; 
				hdr[0 ..  8] = png_file_header; 
				hdr[8 .. 16] = png_image_header; 
				hdr[16 .. 20] = nativeToBigEndian(cast(uint) ec.w); 
				hdr[20 .. 24] = nativeToBigEndian(cast(uint) ec.h); 
				hdr[24      ] = 8;  //bit depth
				hdr[25      ] = color_type(ec.tgt_chans); 
				hdr[26 .. 29] = 0;  //compression, filter and interlace methods
				ec.crc.start(); 
				ec.crc.put(hdr[12 .. 29]); 
				ubyte[4] crc = ec.crc.finish(); 
				reverse(crc[]); 
				hdr[29 .. 33] = crc; 
				ec.stream.rawWrite(hdr); 
				
				write_IDATs(ec); 
				
				static immutable ubyte[12] iend =
					[0, 0, 0, 0, 'I','E','N','D', 0xae, 0x42, 0x60, 0x82]; 
				ec.stream.rawWrite(iend); 
			} 
			
			void write_IDATs(ref PNG_Encoder ec)
			{
				immutable long max_idatlen = 4 * 4096; 
				ec.writelen = 0; 
				ec.chunk_buf = new ubyte[8 + max_idatlen + 4]; 
				ec.data_buf = ec.chunk_buf[8 .. 8 + max_idatlen]; 
				static immutable ubyte[4] IDAT = ['I','D','A','T']; 
				ec.chunk_buf[4 .. 8] = IDAT; 
				
				immutable size_t linesize = ec.w * ec.tgt_chans + 1; //+1 for filter type
				ubyte[] cline = new ubyte[linesize]; 
				ubyte[] pline = new ubyte[linesize];    //initialized to 0
				
				ubyte[] filtered_line = new ubyte[linesize]; 
				ubyte[] filtered_image; 
				
				const LineConv!ubyte convert = get_converter!ubyte(ec.src_chans, ec.tgt_chans); 
				
				immutable size_t filter_step = ec.tgt_chans;   //step between pixels, in bytes
				immutable size_t src_linesize = ec.w * ec.src_chans; 
				
				size_t si = 0; 
				foreach(j; 0 .. ec.h)
				{
					convert(ec.data[si .. si+src_linesize], cline[1..$]); 
					si += src_linesize; 
					
					foreach(i; 1 .. filter_step+1)
					filtered_line[i] = cast(ubyte) (cline[i] - paeth(0, pline[i], 0)); 
					foreach(i; filter_step+1 .. cline.length)
					filtered_line[i] = cast(ubyte)
						(cline[i] - paeth(cline[i-filter_step], pline[i], pline[i-filter_step])); 
					
					filtered_line[0] = PNG_FilterType.Paeth; 
					
					filtered_image ~= filtered_line; 
					
					ubyte[] _swap = pline; 
					pline = cline; 
					cline = _swap; 
				}
				
				const (void)[] xx = compress(filtered_image, 6); 
				
				ec.write_to_IDAT_stream(xx); 
				if(0 < ec.writelen)
				ec.write_IDAT_chunk(); 
			} 
			
			void write_to_IDAT_stream(ref PNG_Encoder ec, in void[] _compressed)
			{
				ubyte[] compressed = cast(ubyte[]) _compressed; 
				while(compressed.length)
				{
					size_t space_left = ec.data_buf.length - ec.writelen; 
					size_t writenow_len = min(space_left, compressed.length); 
					ec.data_buf[ec.writelen .. ec.writelen + writenow_len] =
						compressed[0 .. writenow_len]; 
					ec.writelen += writenow_len; 
					compressed = compressed[writenow_len .. $]; 
					if(ec.writelen == ec.data_buf.length)
					ec.write_IDAT_chunk(); 
				}
			} 
			
			//chunk: len type data crc, type is already in buf
			void write_IDAT_chunk(ref PNG_Encoder ec)
			{
				ec.chunk_buf[0 .. 4] = nativeToBigEndian!uint(ec.writelen); 
				ec.crc.put(ec.chunk_buf[4 .. 8 + ec.writelen]);   //crc of type and data
				ubyte[4] crc = ec.crc.finish(); 
				reverse(crc[]); 
				ec.chunk_buf[8 + ec.writelen .. 8 + ec.writelen + 4] = crc; 
				ec.stream.rawWrite(ec.chunk_buf[0 .. 8 + ec.writelen + 4]); 
				ec.writelen = 0; 
			} 
			
			package void read_png_info(Reader stream, out int w, out int h, out int chans)
			{
				PNG_Header hdr = read_png_header(stream); 
				w = hdr.width; 
				h = hdr.height; 
				chans = channels(cast(PNG_ColorType) hdr.color_type); 
			} 
		}
		version(/+$DIDE_REGION TGA+/all)
		{
			//module imageformats.tga; 
			
			import std.bitmanip	: littleEndianToNative, nativeToLittleEndian; 
			import std.typecons	: scoped; 
			
			private: 
			
			/// Header of a TGA file.
			public struct TGA_Header
			{
				 ubyte id_length; 
				 ubyte palette_type; 
				 ubyte data_type; 
				 ushort palette_start; 
				 ushort palette_length; 
				 ubyte palette_bits; 
				 ushort x_origin; 
				 ushort y_origin; 
				 ushort width; 
				 ushort height; 
				 ubyte bits_pp; 
				 ubyte flags; 
			} 
			
			/// Returns the header of a TGA file.
			public TGA_Header read_tga_header(in char[] filename)
			{
				auto reader = scoped!FileReader(filename); 
				return read_tga_header(reader); 
			} 
			
			/// Reads the image header from a buffer containing a TGA image.
			public TGA_Header read_tga_header_from_mem(in ubyte[] source)
			{
				auto reader = scoped!MemReader(source); 
				return read_tga_header(reader); 
			} 
			
			/// Reads a TGA image. req_chans defines the format of returned image
			/// (you can use ColFmt here).
			public IFImage read_tga(in char[] filename, long req_chans = 0)
			{
				auto reader = scoped!FileReader(filename); 
				return read_tga(reader, req_chans); 
			} 
			
			/// Reads an image from a buffer containing a TGA image. req_chans defines the
			/// format of returned image (you can use ColFmt here).
			public IFImage read_tga_from_mem(in ubyte[] source, long req_chans = 0)
			{
				auto reader = scoped!MemReader(source); 
				return read_tga(reader, req_chans); 
			} 
			
			/// Writes a TGA image into a file.
			public void write_tga(in char[] file, long w, long h, in ubyte[] data, long tgt_chans = 0)
			{
				auto writer = scoped!FileWriter(file); 
				write_tga(writer, w, h, data, tgt_chans); 
			} 
			
			/// Writes a TGA image into a buffer.
			public ubyte[] write_tga_to_mem(long w, long h, in ubyte[] data, long tgt_chans = 0)
			{
				auto writer = scoped!MemWriter(); 
				write_tga(writer, w, h, data, tgt_chans); 
				return writer.result; 
			} 
			
			/// Returns width, height and color format information via w, h and chans.
			public void read_tga_info(in char[] filename, out int w, out int h, out int chans)
			{
				auto reader = scoped!FileReader(filename); 
				return read_tga_info(reader, w, h, chans); 
			} 
			
			/// Returns width, height and color format information via w, h and chans.
			public void read_tga_info_from_mem(in ubyte[] source, out int w, out int h, out int chans)
			{
				auto reader = scoped!MemReader(source); 
				return read_tga_info(reader, w, h, chans); 
			} 
			
			//Detects whether a TGA image is readable from stream.
			package bool detect_tga(Reader stream)
			{
				try
				{
					auto hdr = read_tga_header(stream); 
					return true; 
				}catch(Throwable)
				{ return false; }finally
				{ stream.seek(0, SEEK_SET); }
			} 
			
			TGA_Header read_tga_header(Reader stream)
			{
				ubyte[18] tmp = void; 
				stream.readExact(tmp, tmp.length); 
				
				TGA_Header hdr = {
					id_length	 : tmp[0],
					palette_type	 : tmp[1],
					data_type	 : tmp[2],
					palette_start	 : littleEndianToNative!ushort(tmp[3..5]),
					palette_length	 : littleEndianToNative!ushort(tmp[5..7]),
					palette_bits	 : tmp[7],
					x_origin	 : littleEndianToNative!ushort(tmp[8..10]),
					y_origin	 : littleEndianToNative!ushort(tmp[10..12]),
					width	 : littleEndianToNative!ushort(tmp[12..14]),
					height	 : littleEndianToNative!ushort(tmp[14..16]),
					bits_pp	 : tmp[16],
					flags	 : tmp[17],
				}; 
				
				if(
					hdr.width < 1 || hdr.height < 1 || hdr.palette_type > 1
						|| (
						hdr.palette_type == 0 && (
							hdr.palette_start
																 || hdr.palette_length
																 || hdr.palette_bits
						)
					)
						|| (4 <= hdr.data_type && hdr.data_type <= 8) || 12 <= hdr.data_type
				)
				throw new ImageIOException("corrupt TGA header"); 
				
				return hdr; 
			} 
			
			package IFImage read_tga(Reader stream, long req_chans = 0)
			{
				if(req_chans < 0 || 4 < req_chans)
				throw new ImageIOException("come on..."); 
				
				TGA_Header hdr = read_tga_header(stream); 
				
				if(hdr.width < 1 || hdr.height < 1)
				throw new ImageIOException("invalid dimensions"); 
				if(
					hdr.flags & 0xc0//two bits
				)
				throw new ImageIOException("interlaced TGAs not supported"); 
				if(hdr.flags & 0x10)
				throw new ImageIOException("right-to-left TGAs not supported"); 
				ubyte attr_bits_pp = (hdr.flags & 0xf); 
				if(
					! (attr_bits_pp == 0 || attr_bits_pp == 8)//some set it 0 although data has 8
				)
				throw new ImageIOException("only 8-bit alpha/attribute(s) supported"); 
				if(hdr.palette_type)
				throw new ImageIOException("paletted TGAs not supported"); 
				
				bool rle = false; 
				switch(hdr.data_type)
				with(TGA_DataType)
				{
					//case 1: ;   // paletted, uncompressed
					case TrueColor: 
						if(! (hdr.bits_pp == 24 || hdr.bits_pp == 32))
					throw new ImageIOException("not supported"); 
						break; 
					case Gray: 
						if(! (hdr.bits_pp == 8 || (hdr.bits_pp == 16 && attr_bits_pp == 8)))
					throw new ImageIOException("not supported"); 
						break; 
					//case 9: ;   // paletted, RLE
					case TrueColor_RLE: 
						if(! (hdr.bits_pp == 24 || hdr.bits_pp == 32))
					throw new ImageIOException("not supported"); 
						rle = true; 
						break; 
					case Gray_RLE: 
						if(! (hdr.bits_pp == 8 || (hdr.bits_pp == 16 && attr_bits_pp == 8)))
					throw new ImageIOException("not supported"); 
						rle = true; 
						break; 
					default: throw new ImageIOException("data type not supported"); 
				}
				
				
				int src_chans = hdr.bits_pp / 8; 
				
				if(hdr.id_length)
				stream.seek(hdr.id_length, SEEK_CUR); 
				
				TGA_Decoder dc = {
					stream	 : stream,
					w	 : hdr.width,
					h	 : hdr.height,
					origin_at_top	 : cast(bool) (hdr.flags & 0x20),
					bytes_pp	 : hdr.bits_pp / 8,
					rle	 : rle,
					tgt_chans	 : (req_chans == 0) ? src_chans : cast(int) req_chans,
				}; 
				
				switch(dc.bytes_pp)
				{
					case 1: dc.src_fmt = _ColFmt.Y; break; 
					case 2: dc.src_fmt = _ColFmt.YA; break; 
					case 3: dc.src_fmt = _ColFmt.BGR; break; 
					case 4: dc.src_fmt = _ColFmt.BGRA; break; 
					default: throw new ImageIOException("TGA: format not supported"); 
				}
				
				IFImage result = {
					w	: dc.w,
					h	: dc.h,
					c	: cast(ColFmt) dc.tgt_chans,
					pixels	: decode_tga(dc),
				}; 
				return result; 
			} 
			
			void write_tga(Writer stream, long w, long h, in ubyte[] data, long tgt_chans = 0)
			{
				if(w < 1 || h < 1 || ushort.max < w || ushort.max < h)
				throw new ImageIOException("invalid dimensions"); 
				ulong src_chans = data.length / w / h; 
				if(src_chans < 1 || 4 < src_chans || tgt_chans < 0 || 4 < tgt_chans)
				throw new ImageIOException("invalid channel count"); 
				if(src_chans * w * h != data.length)
				throw new ImageIOException("mismatching dimensions and length"); 
				
				TGA_Encoder ec = {
					stream	: stream,
					w	: cast(ushort) w,
					h	: cast(ushort) h,
					src_chans	: cast(int) src_chans,
					tgt_chans	: cast(int) ((tgt_chans) ? tgt_chans : src_chans),
					rle	: true,
					data	: data,
				}; 
				
				write_tga(ec); 
				stream.flush(); 
			} 
			
			struct TGA_Decoder
			{
				Reader stream; 
				int w, h; 
				bool origin_at_top;    //src
				uint bytes_pp; 
				bool rle;   //run length compressed
				_ColFmt src_fmt; 
				uint tgt_chans; 
			} 
			
			ubyte[] decode_tga(ref TGA_Decoder dc)
			{
				auto result = new ubyte[dc.w * dc.h * dc.tgt_chans]; 
				
				immutable size_t tgt_linesize = dc.w * dc.tgt_chans; 
				immutable size_t src_linesize = dc.w * dc.bytes_pp; 
				auto src_line = new ubyte[src_linesize]; 
				
				immutable ptrdiff_t tgt_stride	= (dc.origin_at_top) ? tgt_linesize : -tgt_linesize; 
				ptrdiff_t ti	= (dc.origin_at_top) ? 0 : (dc.h-1) * tgt_linesize; 
				
				const LineConv!ubyte convert = get_converter!ubyte(dc.src_fmt, dc.tgt_chans); 
				
				if(!dc.rle)
				{
					foreach(_j; 0 .. dc.h)
					{
						dc.stream.readExact(src_line, src_linesize); 
						convert(src_line, result[ti .. ti + tgt_linesize]); 
						ti += tgt_stride; 
					}
					return result; 
				}
				
				//----- RLE  -----
				
				auto rbuf = new ubyte[src_linesize]; 
				size_t plen = 0; 	//packet length
				bool its_rle = false; 	
				
				foreach(_j; 0 .. dc.h)
				{
					//fill src_line with uncompressed data (this works like a stream)
					size_t wanted = src_linesize; 
					while(wanted)
					{
						if(plen == 0)
						{
							dc.stream.readExact(rbuf, 1); 
							its_rle = cast(bool) (rbuf[0] & 0x80); 
							plen = ((rbuf[0] & 0x7f) + 1) * dc.bytes_pp; //length in bytes
						}
						const size_t gotten = src_linesize - wanted; 
						const size_t copysize = min(plen, wanted); 
						if(its_rle)
						{
							dc.stream.readExact(rbuf, dc.bytes_pp); 
							for(size_t p = gotten; p < gotten+copysize; p += dc.bytes_pp)
							src_line[p .. p+dc.bytes_pp] = rbuf[0 .. dc.bytes_pp]; 
						}else
						{
								//it's raw
							auto slice = src_line[gotten .. gotten+copysize]; 
							dc.stream.readExact(slice, copysize); 
						}
						wanted -= copysize; 
						plen -= copysize; 
					}
					
					convert(src_line, result[ti .. ti + tgt_linesize]); 
					ti += tgt_stride; 
				}
				
				return result; 
			} 
			
			//----------------------------------------------------------------------
			//TGA encoder
			
			immutable ubyte[18] tga_footer_sig =
				['T','R','U','E','V','I','S','I','O','N','-','X','F','I','L','E','.', 0]; 
			
			struct TGA_Encoder
			{
				Writer stream; 
				ushort w, h; 
				int src_chans; 
				int tgt_chans; 
				bool rle;   //run length compression
				const(ubyte)[] data; 
			} 
			
			void write_tga(ref TGA_Encoder ec)
			{
				ubyte data_type; 
				bool has_alpha = false; 
				switch(ec.tgt_chans)
				with(TGA_DataType)
				{
					case 1: data_type = ec.rle ? Gray_RLE : Gray; 	break; 
					case 2: data_type = ec.rle ? Gray_RLE : Gray; 	has_alpha = true; 	break; 
					case 3: data_type = ec.rle ? TrueColor_RLE : TrueColor; 		break; 
					case 4: data_type = ec.rle ? TrueColor_RLE : TrueColor; 	has_alpha = true; 	break; 
					default: throw new ImageIOException("internal error"); 
				}
				
				
				ubyte[18] hdr = void; 	
				hdr[0] = 0; 				//id length
				hdr[1] = 0; 				//palette type
				hdr[2] = data_type; 	
				hdr[3..8] = 0; 	//palette start (2), len (2), bits per palette entry (1)
				hdr[8..12] = 0;     //x origin (2), y origin (2)
				hdr[12..14] = nativeToLittleEndian(ec.w); 
				hdr[14..16] = nativeToLittleEndian(ec.h); 
				hdr[16] = cast(ubyte) (ec.tgt_chans * 8);     //bits per pixel
				hdr[17] = (has_alpha) ? 0x8 : 0x0;     //flags: attr_bits_pp = 8
				ec.stream.rawWrite(hdr); 
				
				write_image_data(ec); 
				
				ubyte[26] ftr = void; 
				ftr[0..4] = 0; 		 //extension area offset
				ftr[4..8] = 0; 		 //developer directory offset
				ftr[8..26] = tga_footer_sig; 
				ec.stream.rawWrite(ftr); 
			} 
			
			void write_image_data(ref TGA_Encoder ec)
			{
				_ColFmt tgt_fmt; 
				switch(ec.tgt_chans)
				{
					case 1: tgt_fmt = _ColFmt.Y; break; 
					case 2: tgt_fmt = _ColFmt.YA; break; 
					case 3: tgt_fmt = _ColFmt.BGR; break; 
					case 4: tgt_fmt = _ColFmt.BGRA; break; 
					default: throw new ImageIOException("internal error"); 
				}
				
				const LineConv!ubyte convert = get_converter!ubyte(ec.src_chans, tgt_fmt); 
				
				immutable size_t src_linesize = ec.w * ec.src_chans; 
				immutable size_t tgt_linesize = ec.w * ec.tgt_chans; 
				auto tgt_line = new ubyte[tgt_linesize]; 
				
				ptrdiff_t si = (ec.h-1) * src_linesize;     //origin at bottom
				
				if(!ec.rle)
				{
					foreach(_; 0 .. ec.h)
					{
						convert(ec.data[si .. si + src_linesize], tgt_line); 
						ec.stream.rawWrite(tgt_line); 
						si -= src_linesize; //origin at bottom
					}
					return; 
				}
				
				//----- RLE  -----
				
				immutable bytes_pp = ec.tgt_chans; 
				immutable size_t max_packets_per_line = (tgt_linesize+127) / 128; 
				auto tgt_cmp = new ubyte[tgt_linesize + max_packets_per_line];  //compressed line
				foreach(_; 0 .. ec.h)
				{
					convert(ec.data[si .. si + src_linesize], tgt_line); 
					ubyte[] compressed_line = rle_compress(tgt_line, tgt_cmp, ec.w, bytes_pp); 
					ec.stream.rawWrite(compressed_line); 
					si -= src_linesize; //origin at bottom
				}
			} 
			
			ubyte[] rle_compress(in ubyte[] line, ubyte[] tgt_cmp, in size_t w, in int bytes_pp) pure
			{
				immutable int rle_limit = (1 < bytes_pp) ? 2 : 3;  //run len worth an RLE packet
				size_t runlen = 0; 
				size_t rawlen = 0; 
				size_t raw_i = 0; //start of raw packet data in line
				size_t cmp_i = 0; 
				size_t pixels_left = w; 
				const (ubyte)[]	px; 
				for(size_t i = bytes_pp; pixels_left; i += bytes_pp)
				{
					runlen = 1; 
					px = line[i-bytes_pp .. i]; 
					while(i < line.length && line[i .. i+bytes_pp] == px[0..$] && runlen < 128)
					{
						++runlen; 
						i += bytes_pp; 
					}
					pixels_left -= runlen; 
					
					if(runlen < rle_limit)
					{
						//data goes to raw packet
						rawlen += runlen; 
						if(128 <= rawlen)
						{
								 //full packet, need to store it
							size_t copysize = 128 * bytes_pp; 
							tgt_cmp[cmp_i++] = 0x7f; //raw packet header
							tgt_cmp[cmp_i .. cmp_i+copysize] = line[raw_i .. raw_i+copysize]; 
							cmp_i += copysize; 
							raw_i += copysize; 
							rawlen -= 128; 
						}
					}else
					{
						//RLE packet is worth it
						
						//store raw packet first, if any
						if(rawlen)
						{
							assert(rawlen < 128); 
							size_t copysize = rawlen * bytes_pp; 
							tgt_cmp[cmp_i++] = cast(ubyte) (rawlen-1); //raw packet header
							tgt_cmp[cmp_i .. cmp_i+copysize] = line[raw_i .. raw_i+copysize]; 
							cmp_i += copysize; 
							rawlen = 0; 
						}
						
						//store RLE packet
						tgt_cmp[cmp_i++] = cast(ubyte) (0x80 | (runlen-1)); //packet header
						tgt_cmp[cmp_i .. cmp_i+bytes_pp] = px[0..$];       //packet data
						cmp_i += bytes_pp; 
						raw_i = i; 
					}
				}	//for
				
				if(rawlen)
				{
					   //last packet of the line
					size_t copysize = rawlen * bytes_pp; 
					tgt_cmp[cmp_i++] = cast(ubyte) (rawlen-1); //raw packet header
					tgt_cmp[cmp_i .. cmp_i+copysize] = line[raw_i .. raw_i+copysize]; 
					cmp_i += copysize; 
				}
				return tgt_cmp[0 .. cmp_i]; 
			} 
			
			enum TGA_DataType : ubyte
			{
				Idx	= 1,
				TrueColor	= 2,
				Gray	= 3,
				Idx_RLE	= 9,
				TrueColor_RLE	= 10,
				Gray_RLE	= 11,
			} 
			
			package void read_tga_info(Reader stream, out int w, out int h, out int chans)
			{
				TGA_Header hdr = read_tga_header(stream); 
				w = hdr.width; 
				h = hdr.height; 
				
				//TGA is awkward...
				auto dt = hdr.data_type; 
				if(
					(
						dt == TGA_DataType.TrueColor     || dt == TGA_DataType.Gray ||
								 dt == TGA_DataType.TrueColor_RLE || dt == TGA_DataType.Gray_RLE
					)
							 && (hdr.bits_pp % 8) == 0
				)
				{
					chans = hdr.bits_pp / 8; 
					return; 
				}else if(dt == TGA_DataType.Idx || dt == TGA_DataType.Idx_RLE)
				{
					switch(hdr.palette_bits)
					{
						case 15: chans = 3; return; 
						case 16: chans = 3; return; //one bit could be for some "interrupt control"
						case 24: chans = 3; return; 
						case 32: chans = 4; return; 
						default: 
					}
				}
				chans = 0; 	//unknown
			} 
			
		}version(/+$DIDE_REGION Jpeg detector+/all)
		{
			/// Reads an image from a buffer containing a JPEG image. req_chans defines the
			/// format of returned image (you can use ColFmt here).
			
			/// Returns width, height and color format information via w, h and chans.
			public void read_jpeg_info(in char[] filename, out int w, out int h, out int chans)
			{
				auto reader = scoped!FileReader(filename); 
				return read_jpeg_info(reader, w, h, chans); 
			} 
			
			/// Returns width, height and color format information via w, h and chans.
			public void read_jpeg_info_from_mem(in ubyte[] source, out int w, out int h, out int chans)
			{
				auto reader = scoped!MemReader(source); 
				return read_jpeg_info(reader, w, h, chans); 
			} 
			
			// Detects whether a JPEG image is readable from stream.
			package bool detect_jpeg(Reader stream)
			{
				try {
					int w, h, c; 
					read_jpeg_info(stream, w, h, c); 
					return true; 
				}
				catch(Throwable)
				{ return false; }
				finally
				{ stream.seek(0, SEEK_SET); }
			} 
			
			package void read_jpeg_info(Reader stream, out int w, out int h, out int chans)
			{
				enum Marker : ubyte {
					 SOI = 0xd8,	   // start of image
					 SOF0 = 0xc0,	   // start of frame / baseline DCT
					 //SOF1 = 0xc1,    // start of frame / extended seq.
					 //SOF2 = 0xc2,    // start of frame / progressive DCT
					 SOF3 = 0xc3,			 // start of frame / lossless
					 SOF9 = 0xc9,			 // start of frame / extended seq., arithmetic
					 SOF11 = 0xcb,    // start of frame / lossless, arithmetic
					 DHT = 0xc4,			 // define huffman tables
					 DQT = 0xdb,			 // define quantization tables
					 DRI = 0xdd,			 // define restart interval
					 SOS = 0xda,			 // start of scan
					 DNL = 0xdc,			 // define number of lines
					 RST0 = 0xd0,	   // restart entropy coded data
					 // ...
					 RST7 = 0xd7,			 // restart entropy coded data
					 APP0 = 0xe0,			 // application 0 segment
					 // ...
					 APPf = 0xef,    // application f segment
					 //DAC = 0xcc,     // define arithmetic conditioning table
					 COM = 0xfe,				 // comment
					 EOI = 0xd9,				 // end of image
				} 
				
				ubyte[2] marker = void; 
				stream.readExact(marker, 2); 
				
				// SOI
				if(marker[0] != 0xff || marker[1] != Marker.SOI)
				throw new ImageIOException("not JPEG"); 
				
				while(true)
				{
					stream.readExact(marker, 2); 
					
					if(marker[0] != 0xff)
					throw new ImageIOException("no frame header"); 
					while(marker[1] == 0xff)
					stream.readExact(marker[1..$], 1); 
					
					switch(marker[1])
					with(Marker)
					{
						case SOF0: .. case SOF3: 
						case SOF9: .. case SOF11: 
							ubyte[8] tmp; 
							stream.readExact(tmp[0..8], 8); 
							//int len = bigEndianToNative!ushort(tmp[0..2]);
							w = bigEndianToNative!ushort(tmp[5..7]); 
							h = bigEndianToNative!ushort(tmp[3..5]); 
							chans = tmp[7]; 
							return; 
						case SOS, EOI: throw new ImageIOException("no frame header"); 
						case DRI, DHT, DQT, COM: 
						case APP0: .. case APPf: 
							ubyte[2] lenbuf = void; 
							stream.readExact(lenbuf, 2); 
							int skiplen = bigEndianToNative!ushort(lenbuf) - 2; 
							stream.seek(skiplen, SEEK_CUR); 
							break; 
						default: throw new ImageIOException("unsupported marker"); 
					}
				}
				assert(0); 
			} 
			
			
			
		}version(/+$DIDE_REGION turboJPEG+/all)
		{
			//module turbojpeg.turbojpeg; 
				
			//Source:        https://github.com/rtbo/turbojpeg-d/blob/master/source/turbojpeg/turbojpeg.d
			//Documentation: https://github.com/D-Programming-Deimos/jpeg-turbo/blob/master/source/libjpeg/turbojpeg.d
			
			
			/+
				MIT License
				
				Copyright (c) 2018 Remi Thebault
				
				Permission is hereby granted, free of charge, to any person obtaining a copy
				of this software and associated documentation files (the "Software"), to deal
				in the Software without restriction, including without limitation the rights
				to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
				copies of the Software, and to permit persons to whom the Software is
				furnished to do so, subject to the following conditions:
				
				The above copyright notice and this permission notice shall be included in all
				copies or substantial portions of the Software.
				
				THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
				IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
				FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
				AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
				LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
				OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
				SOFTWARE.
			+/
			
			//extra stuff for the integration with hetlib ////////////////////////////////////
			
			pragma(lib, "turbojpeg-static.lib"); 
			
			void tjChk(tjhandle h, int res, string what)
			{
				if(res==0)
				return; 
				import std.format; 
				throw new Exception(format!"TurboJpeg Error: %s %s"(what, tjGetErrorStr2(h))); 
			} 
			
			//Auto-create a separate instance for each thread
			import std.exception : enforce; 
			auto tjDecoder()
			{
				static tjhandle h; if(!h)
				{ h = tjInitDecompress; enforce(h, "tjInitDecompress() fail."); }return h; 
			} 
			auto tjEncoder()
			{
				static tjhandle h; if(!h)
				{ h = tjInitCompress; enforce(h, "tjInitCompress() fail."  ); }return h; 
			} 
			
			//original stuff //////////////////////////////////////////////////////////////////
			
			import core.stdc.config : c_ulong; 
			
			extern (C) nothrow @nogc: 
			
			enum TJ_NUMSAMP = 6; 
			
			enum TJSAMP
			{
				TJSAMP_444 = 0,
				TJSAMP_422,
				TJSAMP_420,
				TJSAMP_GRAY,
				TJSAMP_440,
				TJSAMP_411
			} 
			
			alias TJSAMP_444 = TJSAMP.TJSAMP_444; 
			alias TJSAMP_422 = TJSAMP.TJSAMP_422; 
			alias TJSAMP_420 = TJSAMP.TJSAMP_420; 
			alias TJSAMP_GRAY = TJSAMP.TJSAMP_GRAY; 
			alias TJSAMP_440 = TJSAMP.TJSAMP_440; 
			alias TJSAMP_411 = TJSAMP.TJSAMP_411; 
			
			immutable int[TJ_NUMSAMP] tjMCUWidth = [8, 16, 16, 8, 8, 32]; 
			immutable int[TJ_NUMSAMP] tjMCUHeight = [8, 8, 16, 8, 16, 8]; 
			
			enum TJ_NUMPF = 12; 
			
			enum TJPF
			{
				TJPF_RGB = 0,
				TJPF_BGR,
				TJPF_RGBX,
				TJPF_BGRX,
				TJPF_XBGR,
				TJPF_XRGB,
				TJPF_GRAY,
				TJPF_RGBA,
				TJPF_BGRA,
				TJPF_ABGR,
				TJPF_ARGB,
				TJPF_CMYK,
				TJPF_UNKNOWN = -1
			} 
			
			alias TJPF_RGB = TJPF.TJPF_RGB; 
			alias TJPF_BGR = TJPF.TJPF_BGR; 
			alias TJPF_RGBX = TJPF.TJPF_RGBX; 
			alias TJPF_BGRX = TJPF.TJPF_BGRX; 
			alias TJPF_XBGR = TJPF.TJPF_XBGR; 
			alias TJPF_XRGB = TJPF.TJPF_XRGB; 
			alias TJPF_GRAY = TJPF.TJPF_GRAY; 
			alias TJPF_RGBA = TJPF.TJPF_RGBA; 
			alias TJPF_BGRA = TJPF.TJPF_BGRA; 
			alias TJPF_ABGR = TJPF.TJPF_ABGR; 
			alias TJPF_ARGB = TJPF.TJPF_ARGB; 
			alias TJPF_CMYK = TJPF.TJPF_CMYK; 
			alias TJPF_UNKNOWN = TJPF.TJPF_UNKNOWN; 
			
			immutable int[TJ_NUMPF] tjRedOffset = [0, 2, 0, 2, 3, 1, -1, 0, 2, 3, 1, -1]; 
			immutable int[TJ_NUMPF] tjGreenOffset = [1, 1, 1, 1, 2, 2, -1, 1, 1, 2, 2, -1]; 
			immutable int[TJ_NUMPF] tjBlueOffset = [2, 0, 2, 0, 1, 3, -1, 2, 0, 1, 3, -1]; 
			immutable int[TJ_NUMPF] tjAlphaOffset = [-1, -1, -1, -1, -1, -1, -1, 3, 3, 0, 0, -1]; 
			immutable int[TJ_NUMPF] tjPixelSize = [3, 3, 4, 4, 4, 4, 1, 4, 4, 4, 4, 4]; 
			
			enum TJ_NUMCS = 5; 
			
			enum TJCS
			{
				TJCS_RGB = 0,
				TJCS_YCbCr,
				TJCS_GRAY,
				TJCS_CMYK,
				TJCS_YCCK
			} 
			
			alias TJCS_RGB = TJCS.TJCS_RGB; 
			alias TJCS_YCbCr = TJCS.TJCS_YCbCr; 
			alias TJCS_GRAY = TJCS.TJCS_GRAY; 
			alias TJCS_CMYK = TJCS.TJCS_CMYK; 
			alias TJCS_YCCK = TJCS.TJCS_YCCK; 
			
			enum TJFLAG_BOTTOMUP = 2; 
			enum TJFLAG_FASTUPSAMPLE = 256; 
			enum TJFLAG_NOREALLOC = 1024; 
			enum TJFLAG_FASTDCT = 2048; 
			enum TJFLAG_ACCURATEDCT = 4096; 
			enum TJFLAG_STOPONWARNING = 8192; 
			enum TJFLAG_PROGRESSIVE = 16384; 
			
			enum TJ_NUMERR = 2; 
			
			enum TJERR
			{
				TJERR_WARNING = 0,
				TJERR_FATAL
			} 
			
			alias TJERR_WARNING = TJERR.TJERR_WARNING; 
			alias TJERR_FATAL = TJERR.TJERR_FATAL; 
			
			enum TJ_NUMXOP = 8; 
			
			enum TJXOP
			{
				TJXOP_NONE = 0,
				TJXOP_HFLIP,
				TJXOP_VFLIP,
				TJXOP_TRANSPOSE,
				TJXOP_TRANSVERSE,
				TJXOP_ROT90,
				TJXOP_ROT180,
				TJXOP_ROT270
			} 
			
			alias TJXOP_NONE = TJXOP.TJXOP_NONE; 
			alias TJXOP_HFLIP = TJXOP.TJXOP_HFLIP; 
			alias TJXOP_VFLIP = TJXOP.TJXOP_VFLIP; 
			alias TJXOP_TRANSPOSE = TJXOP.TJXOP_TRANSPOSE; 
			alias TJXOP_TRANSVERSE = TJXOP.TJXOP_TRANSVERSE; 
			alias TJXOP_ROT90 = TJXOP.TJXOP_ROT90; 
			alias TJXOP_ROT180 = TJXOP.TJXOP_ROT180; 
			alias TJXOP_ROT270 = TJXOP.TJXOP_ROT270; 
			
			enum TJXOPT_PERFECT = 1; 
			enum TJXOPT_TRIM = 2; 
			enum TJXOPT_CROP = 4; 
			enum TJXOPT_GRAY = 8; 
			enum TJXOPT_NOOUTPUT = 16; 
			enum TJXOPT_PROGRESSIVE = 32; 
			enum TJXOPT_COPYNONE = 64; 
			
			struct tjscalingfactor
			{
				int num; 
				int denom; 
			} 
			
			struct tjregion
			{
				int x; 
				int y; 
				int w; 
				int h; 
			} 
			
			struct tjtransform
			{
				tjregion r; 
				int op; 
				int options; 
				void* data; 
				int function(
					short* coeffs, tjregion arrayRegion, tjregion planeRegion,
								int componentIndex, int transformIndex, tjtransform* transform
				) customFilter; 
			} 
			
			alias tjhandle = void*; 
			
			extern (D) auto TJPAD(W)(in W width)
			{ return (width + 3) & (~3); } 
			
			extern (D) auto TJSCALED(D)(in D dimension, in tjscalingfactor scalingFactor)
			{ return (dimension * scalingFactor.num + scalingFactor.denom - 1) / scalingFactor.denom; } 
			
			tjhandle tjInitCompress(); 
			
			int tjCompress2(
				tjhandle handle, const(ubyte)* srcBuf, int width, int pitch,
					int height, int pixelFormat, ubyte** jpegBuf, c_ulong* jpegSize,
					int jpegSubsamp, int jpegQual, int flags
			); 
			
			int tjCompressFromYUV(
				tjhandle handle, const(ubyte)* srcBuf, int width, int pad,
					int height, int subsamp, ubyte** jpegBuf, c_ulong* jpegSize, int jpegQual, int flags
			); 
			
			int tjCompressFromYUVPlanes(
				tjhandle handle, const(ubyte)** srcPlanes,
					int width, const(int)* strides, int height, int subsamp, ubyte** jpegBuf,
					c_ulong* jpegSize, int jpegQual, int flags
			); 
			
			c_ulong tjBufSize(int width, int height, int jpegSubsamp); 
			
			c_ulong tjBufSizeYUV2(int width, int pad, int height, int subsamp); 
			
			c_ulong tjPlaneSizeYUV(int componentID, int width, int stride, int height, int subsamp); 
			
			int tjPlaneWidth(int componentID, int width, int subsamp); 
			
			int tjPlaneHeight(int componentID, int height, int subsamp); 
			
			int tjEncodeYUV3(
				tjhandle handle, const(ubyte)* srcBuf, int width, int pitch,
					int height, int pixelFormat, ubyte* dstBuf, int pad, int subsamp, int flags
			); 
			
			int tjEncodeYUVPlanes(
				tjhandle handle, const(ubyte)* srcBuf, int width, int pitch,
					int height, int pixelFormat, ubyte** dstPlanes, int* strides, int subsamp, int flags
			); 
			
			tjhandle tjInitDecompress(); 
			
			int tjDecompressHeader3(
				tjhandle handle, const(ubyte)* jpegBuf, c_ulong jpegSize,
					int* width, int* height, int* jpegSubsamp, int* jpegColorspace
			); 
			
			tjscalingfactor* tjGetScalingFactors(int* numscalingfactors); 
			
			int tjDecompress2(
				tjhandle handle, const(ubyte)* jpegBuf, c_ulong jpegSize,
					ubyte* dstBuf, int width, int pitch, int height, int pixelFormat, int flags
			); 
			
			int tjDecompressToYUV2(
				tjhandle handle, const(ubyte)* jpegBuf, c_ulong jpegSize,
					ubyte* dstBuf, int width, int pad, int height, int flags
			); 
			
			int tjDecompressToYUVPlanes(
				tjhandle handle, const(ubyte)* jpegBuf,
					c_ulong jpegSize, ubyte** dstPlanes, int width, int* strides, int height, int flags
			); 
			
			int tjDecodeYUV(
				tjhandle handle, const(ubyte)* srcBuf, int pad, int subsamp,
					ubyte* dstBuf, int width, int pitch, int height, int pixelFormat, int flags
			); 
			
			int tjDecodeYUVPlanes(
				tjhandle handle, const(ubyte)** srcPlanes,
					const int* strides, int subsamp, ubyte* dstBuf, int width, int pitch,
					int height, int pixelFormat, int flags
			); 
			
			tjhandle tjInitTransform(); 
			
			int tjTransform(
				tjhandle handle, const(ubyte)* jpegBuf, c_ulong jpegSize, int n,
					ubyte** dstBufs, c_ulong* dstSizes, tjtransform* transforms, int flags
			); 
			
			int tjDestroy(tjhandle handle); 
			
			ubyte* tjAlloc(int bytes); 
			
			ubyte* tjLoadImage(
				const(char)* filename, int* width, int alignment,
					int* height, int* pixelFormat, int flags
			); 
			
			int tjSaveImage(
				const(char)* filename, ubyte* buffer, int width, int pitch,
					int height, int pixelFormat, int flags
			); 
			
			void tjFree(ubyte* buffer); 
			
			char* tjGetErrorStr2(tjhandle handle); 
			
			int tjGetErrorCode(tjhandle handle); 
			
			
			//deprecated:  //24087 why was it marked deprecated?!!
			
			c_ulong TJBUFSIZE(int width, int height); 
			
			c_ulong TJBUFSIZEYUV(int width, int height, int jpegSubsamp); 
			
			c_ulong tjBufSizeYUV(int width, int height, int subsamp); 
			
			int tjCompress(
				tjhandle handle, ubyte *srcBuf, int width,
										 int pitch, int height, int pixelSize,
										 ubyte *dstBuf, c_ulong *compressedSize,
										 int jpegSubsamp, int jpegQual, int flags
			); 
			
			int tjEncodeYUV(
				tjhandle handle, ubyte *srcBuf, int width,
											 int pitch, int height, int pixelSize,
											 ubyte *dstBuf, int subsamp, int flags
			); 
			
			int tjEncodeYUV2(
				tjhandle	handle, ubyte *srcBuf, int width,
											int pitch, int height, int pixelFormat,
											ubyte *dstBuf, int subsamp, int flags
			); 
			
			int tjDecompressHeader(
				tjhandle handle, ubyte *jpegBuf,
												 c_ulong jpegSize, int *width,
												 int *height
			); 
			
			int tjDecompressHeader2(
				tjhandle handle, ubyte *jpegBuf,
													 c_ulong jpegSize, int *width,
													 int *height, int *jpegSubsamp
			); 
			
			int tjDecompress(
				tjhandle	handle, ubyte *jpegBuf,
											c_ulong jpegSize, ubyte *dstBuf,
											int width, int pitch, int height, int pixelSize,
											int flags
			); 
			
			int tjDecompressToYUV(
				tjhandle handle, ubyte *jpegBuf,
												c_ulong jpegSize, ubyte *dstBuf,
												int flags
			); 
			
			char *tjGetErrorStr(); 
		}version(/+$DIDE_REGION WEBP+/all)
		{
			pragma(lib, "libwebp.lib"); 
			version(none)
			{
				extern (C)
				{
					//Copyright 2011 Google Inc. All Rights Reserved.
					//
					//Use of this source code is governed by a BSD-style license
					//that can be found in the COPYING file in the root of the source
					//tree. An additional intellectual property rights grant can be found
					//in the file PATENTS. All contributing project authors may
					//be found in the AUTHORS file in the root of the source tree.
					//-----------------------------------------------------------------------------
					//
					//   WebP encoder: main interface
					//
					//Author: Skal (pascal.massimino@gmail.com)
						
					//public import webp.types;
					
					enum WEBP_ENCODER_ABI_VERSION = 0x0202;    //MAJOR(8b) + MINOR(8b)
					
					//Return the encoder's version number, packed in hexadecimal using 8bits for
					//each of major/minor/revision. E.g: v2.5.7 is 0x020507.
					int WebPGetEncoderVersion(); 
					
					//------------------------------------------------------------------------------
					//One-stop-shop call! No questions asked:
					
					//Returns the size of the compressed data (pointed to by *output), or 0 if
					//an error occurred. The compressed data must be released by the caller
					//using the call 'free(*output)'.
					//These functions compress using the lossy format, and the quality_factor
					//can go from 0 (smaller output, lower quality) to 100 (best quality,
					//larger output).
					size_t WebPEncodeRGB(
						const ubyte*	rgb,
						int width, int height, int stride,
						float quality_factor, ubyte** output
					); 
					size_t WebPEncodeBGR(
						const ubyte*	bgr,
						int width, int height, int stride,
						float quality_factor, ubyte** output
					); 
					size_t WebPEncodeRGBA(
						const ubyte* rgba,
						int width, int height, int stride,
						float quality_factor, ubyte** output
					); 
					size_t WebPEncodeBGRA(
						const ubyte* bgra,
						int width, int height, int stride,
						float quality_factor, ubyte** output
					); 
					
					//These functions are the equivalent of the above, but compressing in a
					//lossless manner. Files are usually larger than lossy format, but will
					//not suffer any compression loss.
					size_t WebPEncodeLosslessRGB(
						const ubyte* rgb,
						int width, int height, int stride,
						ubyte** output
					); 
					size_t WebPEncodeLosslessBGR(
						const ubyte* bgr,
						int width, int height, int stride,
						ubyte** output
					); 
					size_t WebPEncodeLosslessRGBA(
						const ubyte* rgba,
						int width, int height, int stride,
						ubyte** output
					); 
					size_t WebPEncodeLosslessBGRA(
						const ubyte* bgra,
						int width, int height, int stride,
						ubyte** output
					); 
					
					//------------------------------------------------------------------------------
					//Coding parameters
					
					//Image characteristics hint for the underlying encoder.
					enum WebPImageHint
					{
						WEBP_HINT_DEFAULT = 0,	 //default preset.
						WEBP_HINT_PICTURE,	 //digital picture, like portrait, inner shot
						WEBP_HINT_PHOTO,	 //outdoor photograph, with natural lighting
						WEBP_HINT_GRAPH,	 //Discrete tone image (graph, map-tile etc).
						WEBP_HINT_LAST
					} 
					
					//Compression parameters.
					struct WebPConfig
					{
						int lossless; 	         //Lossless encoding (0=lossy(default), 1=lossless).
						float quality; 	         //between 0 (smallest file) and 100 (biggest)
						int method; 	         //quality/speed trade-off (0=fast, 6=slower-better)
						
						WebPImageHint image_hint;  //Hint for image type (lossless only for now).
						
						//Parameters related to lossy compression only:
						int target_size; 	 //if non-zero, set the desired target size in bytes.
							//Takes precedence over the 'compression' parameter.
						float target_PSNR; 	 //if non-zero, specifies the minimal distortion to
							//try to achieve. Takes precedence over target_size.
						int segments; 	 //maximum number of segments to use, in [1..4]
						int sns_strength; 	 //Spatial Noise Shaping. 0=off, 100=maximum.
						int filter_strength; 	 //range: [0 = off .. 100 = strongest]
						int filter_sharpness; 	 //range: [0 = off .. 7 = least sharp]
						int filter_type; 	 //filtering type: 0 = simple, 1 = strong (only used
							//if filter_strength > 0 or autofilter > 0)
						int autofilter; 	 //Auto adjust filter's strength [0 = off, 1 = on]
						int alpha_compression; 	 //Algorithm for encoding the alpha plane (0 = none,
							//1 = compressed with WebP lossless). Default is 1.
						int alpha_filtering; 	 //Predictive filtering method for alpha plane.
							//0: none, 1: fast, 2: best. Default if 1.
						int alpha_quality; 	 //Between 0 (smallest size) and 100 (lossless).
							//Default is 100.
						int pass; 	 //number of entropy-analysis passes (in [1..10]).
						
						int show_compressed; 	 //if true, export the compressed picture back.
							//In-loop filtering is not applied.
						int preprocessing; 	 //preprocessing filter:
							//0=none, 1=segment-smooth, 2=pseudo-random dithering
						int partitions; 	 //log2(number of token partitions) in [0..3]. Default
							//is set to 0 for easier progressive decoding.
						int partition_limit; 	 //quality degradation allowed to fit the 512k limit
							//on prediction modes coding (0: no degradation,
							//100: maximum possible degradation).
						int emulate_jpeg_size; 	 //If true, compression parameters will be remapped
							//to better match the expected output size from
							//JPEG compression. Generally, the output size will
							//be similar but the degradation will be lower.
						int thread_level; 	 //If non-zero, try and use multi-threaded encoding.
						int low_memory; 	 //If set, reduce memory usage (but increase CPU use).
						
						uint[5] pad;            //padding for later use
					} 
					
					//Enumerate some predefined settings for WebPConfig, depending on the type
					//of source picture. These presets are used when calling WebPConfigPreset().
					enum WebPPreset
					{
						WEBP_PRESET_DEFAULT = 0,	 //default preset.
						WEBP_PRESET_PICTURE,	 //digital picture, like portrait, inner shot
						WEBP_PRESET_PHOTO,	 //outdoor photograph, with natural lighting
						WEBP_PRESET_DRAWING,	 //hand or line drawing, with high-contrast details
						WEBP_PRESET_ICON,	 //small-sized colorful images
						WEBP_PRESET_TEXT	 //text-like
					} 
					
					//Internal, version-checked, entry point
					int WebPConfigInitInternal(WebPConfig*, WebPPreset, float, int); 
					
					//Should always be called, to initialize a fresh WebPConfig structure before
					//modification. Returns false in case of version mismatch. WebPConfigInit()
					//must have succeeded before using the 'config' object.
					//Note that the default values are lossless=0 and quality=75.
					int WebPConfigInit(WebPConfig* config)
					{
						return WebPConfigInitInternal(
							config, WebPPreset.WEBP_PRESET_DEFAULT, 75.0f,
							WEBP_ENCODER_ABI_VERSION
						); 
					} 
					
					//This function will initialize the configuration according to a predefined
					//set of parameters (referred to by 'preset') and a given quality factor.
					//This function can be called as a replacement to WebPConfigInit(). Will
					//return false in case of error.
					int WebPConfigPreset(
						WebPConfig* config,
						WebPPreset preset, float quality
					)
					{
						return WebPConfigInitInternal(
							config, preset, quality,
							WEBP_ENCODER_ABI_VERSION
						); 
					} 
					
					//Returns true if 'config' is non-NULL and all configuration parameters are
					//within their valid ranges.
					int WebPValidateConfig(const WebPConfig* config); 
					
					//------------------------------------------------------------------------------
					//Input / Output
					//Structure for storing auxiliary statistics (mostly for lossy encoding).
					
					struct WebPAuxStats
					{
						int coded_size; 	//final size
							
						float[5] PSNR; 	//peak-signal-to-noise ratio for Y/U/V/All/Alpha
						int[3] block_count; 	//number of intra4/intra16/skipped macroblocks
						int[2] header_bytes; 	//approximate number of bytes spent for header
							//and mode-partition #0
						int[3][4] residual_bytes; 	//approximate number of bytes spent for
							//DC/AC/uv coefficients for each (0..3) segments.
						int[4] segment_size; 	//number of macroblocks in each segments
						int[4] segment_quant; 	//quantizer values for each segments
						int[4] segment_level; 	//filtering strength for each segments [0..63]
							
						int alpha_data_size; 	//size of the transparency data
						int layer_data_size; 	//size of the enhancement layer data
						
						//lossless encoder statistics
						uint lossless_features; 	//bit0:predictor bit1:cross-color transform
							//bit2:subtract-green bit3:color indexing
						int histogram_bits; 	//number of precision bits of histogram
						int transform_bits; 	//precision bits for transform
						int cache_bits; 	//number of bits for color cache lookup
						int palette_size; 	//number of color in palette, if used
						int lossless_size; 	//final lossless size
							
						uint[4] pad; 	//padding for later use
					} 
					
					//Signature for output function. Should return true if writing was successful.
					//data/data_size is the segment of data to write, and 'picture' is for
					//reference (and so one can make use of picture->custom_ptr).
					alias int function(
						const ubyte* data, size_t data_size,
						const WebPPicture* picture
					) WebPWriterFunction; 
					
					//WebPMemoryWrite: a special WebPWriterFunction that writes to memory using
					//the following WebPMemoryWriter object (to be set as a custom_ptr).
					struct WebPMemoryWriter
					{
						ubyte* mem; 	 //final buffer (of size 'max_size', larger than 'size').
						size_t		 size; 	 //final size
						size_t		 max_size; 	 //total capacity
						uint[1] pad;        //padding for later use
					} 
					
					//The following must be called first before any use.
					void WebPMemoryWriterInit(WebPMemoryWriter* writer); 
					
					//The custom writer to be used with WebPMemoryWriter as custom_ptr. Upon
					//completion, writer.mem and writer.size will hold the coded data.
					//if (WEBP_ENCODER_ABI_VERSION > 0x0203)
					//writer.mem must be freed by calling WebPMemoryWriterClear.
					
					//} else {
					//writer.mem must be freed by calling 'free(writer.mem)'.
					//}
					int WebPMemoryWrite(
						const ubyte* data, size_t data_size,
						const WebPPicture* picture
					); 
					
					//Progress hook, called from time to time to report progress. It can return
					//false to request an abort of the encoding process, or true otherwise if
					//everything is OK.
					alias int function(int percent, const WebPPicture* picture) WebPProgressHook; 
					
					//Color spaces.
					enum WebPEncCSP
					{
						//chroma sampling
						WEBP_YUV420	= 0,	  //4:2:0
						WEBP_YUV420A	= 4,	  //alpha channel variant
						WEBP_CSP_UV_MASK = 3,	  //bit-mask to get the UV sampling factors
						WEBP_CSP_ALPHA_BIT = 4	  //bit that is set if alpha is present
					} 
					
					//Encoding error conditions.
					enum WebPEncodingError
					{
						VP8_ENC_OK = 0,
						VP8_ENC_ERROR_OUT_OF_MEMORY,	 //memory error allocating objects
						VP8_ENC_ERROR_BITSTREAM_OUT_OF_MEMORY,	 //memory error while flushing bits
						VP8_ENC_ERROR_NULL_PARAMETER,	 //a pointer parameter is NULL
						VP8_ENC_ERROR_INVALID_CONFIGURATION,	 //configuration is invalid
						VP8_ENC_ERROR_BAD_DIMENSION,	 //picture has invalid width/height
						VP8_ENC_ERROR_PARTITION0_OVERFLOW,	 //partition is bigger than 512k
						VP8_ENC_ERROR_PARTITION_OVERFLOW,	 //partition is bigger than 16M
						VP8_ENC_ERROR_BAD_WRITE,	 //error while flushing bytes
						VP8_ENC_ERROR_FILE_TOO_BIG,	 //file is bigger than 4G
						VP8_ENC_ERROR_USER_ABORT,	 //abort request by user
						VP8_ENC_ERROR_LAST	 //list terminator. always last.
					} 
					
					//maximum width/height allowed (inclusive), in pixels
					enum WEBP_MAX_DIMENSION = 16383; 
					
					//Main exchange structure (input samples, output bytes, statistics)
					struct WebPPicture
					{
						//   INPUT
						//////////////
						//Main flag for encoder selecting between ARGB or YUV input.
						//It is recommended to use ARGB input (*argb, argb_stride) for lossless
						//compression, and YUV input (*y, *u, *v, etc.) for lossy compression
						//since these are the respective native colorspace for these formats.
						int use_argb; 
						
						//YUV input (mostly used for input to lossy compression)
						WebPEncCSP colorspace; 		  //colorspace: should be YUV420 for now (=Y'CbCr).
						int width, height; 			//dimensions (less or equal to WEBP_MAX_DIMENSION)
						ubyte* y, u, v; 		//pointers to luma/chroma planes.
						int y_stride, uv_stride; 	  //luma/chroma strides.
						ubyte* a; 	  //pointer to the alpha plane
						int a_stride; 	  //stride of the alpha plane
						uint[2] pad1;              //padding for later use
						
						//ARGB input (mostly used for input to lossless compression)
						uint* argb; 	          //Pointer to argb (32 bit) plane.
						int argb_stride; 	          //This is stride in pixels units, not bytes.
						uint[3] pad2;              //padding for later use
						
						//   OUTPUT
						///////////////
						//Byte-emission hook, to store compressed bytes as they are ready.
						WebPWriterFunction writer; 	 //can be NULL
						void* custom_ptr; 	 //can be used by the writer.
						
						//map for extra information (only for lossy compression mode)
						int extra_info_type; 	   //1: intra type, 2: segment, 3: quant
								 //4: intra-16 prediction mode,
								 //5: chroma prediction mode,
								 //6: bit cost, 7: distortion
						ubyte* extra_info; 	   //if not NULL, points to an array of size
								 //((width + 15) / 16) * ((height + 15) / 16) that
								 //will be filled with a macroblock map, depending
								 //on extra_info_type.
						
						//   STATS AND REPORTS
						///////////////////////////
						//Pointer to side statistics (updated only if not NULL)
						WebPAuxStats* stats; 
						
						//Error code for the latest error encountered during encoding
						WebPEncodingError error_code; 
						
						//If not NULL, report progress during encoding.
						WebPProgressHook progress_hook; 
						
						void* user_data; 	       //this field is free to be set to any value and
						       //used during callbacks (like progress-report e.g.).
						
						uint[3] pad3;           //padding for later use
						
						//Unused for now: original samples (for non-YUV420 modes)
						ubyte* pad4, pad5; 
						uint[8] pad6; 
						
						//PRIVATE FIELDS
						////////////////////
						void* memory_; 		//row chunk of memory for yuva planes
						void* memory_argb_; 		    //and for argb too.
						void*[2] pad7;          //padding for later use
					} 
					
					//Internal, version-checked, entry point
					int WebPPictureInitInternal(WebPPicture*, int); 
					
					//Should always be called, to initialize the structure. Returns false in case
					//of version mismatch. WebPPictureInit() must have succeeded before using the
					//'picture' object.
					//Note that, by default, use_argb is false and colorspace is WEBP_YUV420.
					int WebPPictureInit(WebPPicture* picture)
					{ return WebPPictureInitInternal(picture, WEBP_ENCODER_ABI_VERSION); } 
					
					//------------------------------------------------------------------------------
					//WebPPicture utils
					
					//Convenience allocation / deallocation based on picture->width/height:
					//Allocate y/u/v buffers as per colorspace/width/height specification.
					//Note! This function will free the previous buffer if needed.
					//Returns false in case of memory error.
					int WebPPictureAlloc(WebPPicture* picture); 
					
					//Release the memory allocated by WebPPictureAlloc() or WebPPictureImport*().
					//Note that this function does _not_ free the memory used by the 'picture'
					//object itself.
					//Besides memory (which is reclaimed) all other fields of 'picture' are
					//preserved.
					void WebPPictureFree(WebPPicture* picture); 
					
					//Copy the pixels of *src into *dst, using WebPPictureAlloc. Upon return, *dst
					//will fully own the copied pixels (this is not a view). The 'dst' picture need
					//not be initialized as its content is overwritten.
					//Returns false in case of memory allocation error.
					int WebPPictureCopy(const WebPPicture* src, WebPPicture* dst); 
					
					//Compute PSNR, SSIM or LSIM distortion metric between two pictures.
					//Result is in dB, stores in result[] in the Y/U/V/Alpha/All order.
					//Returns false in case of error (src and ref don't have same dimension, ...)
					//Warning : this function is rather CPU-intensive.
					int WebPPictureDistortion(
						const WebPPicture* src, const WebPPicture* _ref,
						int metric_type, //0 = PSNR, 1 = SSIM, 2 = LSIM
						float* result
					); //[5]
					
					//self-crops a picture to the rectangle defined by top/left/width/height.
					//Returns false in case of memory allocation error, or if the rectangle is
					//outside of the source picture.
					//The rectangle for the view is defined by the top-left corner pixel
					//coordinates (left, top) as well as its width and height. This rectangle
					//must be fully be comprised inside the 'src' source picture. If the source
					//picture uses the YUV420 colorspace, the top and left coordinates will be
					//snapped to even values.
					int WebPPictureCrop(
						WebPPicture* picture,
						int left, int top, int width, int height
					); 
					
					//Extracts a view from 'src' picture into 'dst'. The rectangle for the view
					//is defined by the top-left corner pixel coordinates (left, top) as well
					//as its width and height. This rectangle must be fully be comprised inside
					//the 'src' source picture. If the source picture uses the YUV420 colorspace,
					//the top and left coordinates will be snapped to even values.
					//Picture 'src' must out-live 'dst' picture. Self-extraction of view is allowed
					//('src' equal to 'dst') as a mean of fast-cropping (but note that doing so,
					//the original dimension will be lost). Picture 'dst' need not be initialized
					//with WebPPictureInit() if it is different from 'src', since its content will
					//be overwritten.
					//Returns false in case of memory allocation error or invalid parameters.
					int WebPPictureView(
						const WebPPicture* src,
						int left, int top, int width, int height,
						WebPPicture* dst
					); 
					
					//Returns true if the 'picture' is actually a view and therefore does
					//not own the memory for pixels.
					int WebPPictureIsView(const WebPPicture* picture); 
					
					//Rescale a picture to new dimension width x height.
					//If either 'width' or 'height' (but not both) is 0 the corresponding
					//dimension will be calculated preserving the aspect ratio.
					//No gamma correction is applied.
					//Returns false in case of error (invalid parameter or insufficient memory).
					int WebPPictureRescale(WebPPicture* pic, int width, int height); 
					
					//Colorspace conversion function to import RGB samples.
					//Previous buffer will be free'd, if any.
					//*rgb buffer should have a size of at least height * rgb_stride.
					//Returns false in case of memory error.
					int WebPPictureImportRGB(WebPPicture* picture, const ubyte* rgb, int rgb_stride); 
					//Same, but for RGBA buffer.
					int WebPPictureImportRGBA(WebPPicture* picture, const ubyte* rgba, int rgba_stride); 
					//Same, but for RGBA buffer. Imports the RGB direct from the 32-bit format
					//input buffer ignoring the alpha channel. Avoids needing to copy the data
					//to a temporary 24-bit RGB buffer to import the RGB only.
					
					int WebPPictureImportRGBX(WebPPicture* picture, const ubyte* rgbx, int rgbx_stride); 
					
					//Variants of the above, but taking BGR(A|X) input.
					int WebPPictureImportBGR(WebPPicture* picture, const ubyte* bgr, int bgr_stride); 
					int WebPPictureImportBGRA(WebPPicture* picture, const ubyte* bgra, int bgra_stride); 
					int WebPPictureImportBGRX(WebPPicture* picture, const ubyte* bgrx, int bgrx_stride); 
					
					//Converts picture->argb data to the YUV420A format. The 'colorspace'
					//parameter is deprecated and should be equal to WEBP_YUV420.
					//Upon return, picture->use_argb is set to false. The presence of real
					//non-opaque transparent values is detected, and 'colorspace' will be
					//adjusted accordingly. Note that this method is lossy.
					//Returns false in case of error.
					int WebPPictureARGBToYUVA(
						WebPPicture* picture,
						WebPEncCSP colorspace
					); 
					
					//Same as WebPPictureARGBToYUVA(), but the conversion is done using
					//pseudo-random dithering with a strength 'dithering' between
					//0.0 (no dithering) and 1.0 (maximum dithering). This is useful
					//for photographic picture.
					int WebPPictureARGBToYUVADithered(WebPPicture* picture, WebPEncCSP colorspace, float dithering); 
					
					//Converts picture->yuv to picture->argb and sets picture->use_argb to true.
					//The input format must be YUV_420 or YUV_420A.
					//Note that the use of this method is discouraged if one has access to the
					//raw ARGB samples, since using YUV420 is comparatively lossy. Also, the
					//conversion from YUV420 to ARGB incurs a small loss too.
					//Returns false in case of error.
					int WebPPictureYUVAToARGB(WebPPicture* picture); 
					
					//Helper function: given a width x height plane of RGBA or YUV(A) samples
					//clean-up the YUV or RGB samples under fully transparent area, to help
					//compressibility (no guarantee, though).
					void WebPCleanupTransparentArea(WebPPicture* picture); 
					
					//Scan the picture 'picture' for the presence of non fully opaque alpha values.
					//Returns true in such case. Otherwise returns false (indicating that the
					//alpha plane can be ignored altogether e.g.).
					int WebPPictureHasTransparency(const WebPPicture* picture); 
					
					//Remove the transparency information (if present) by blending the color with
					//the background color 'background_rgb' (specified as 24bit RGB triplet).
					//After this call, all alpha values are reset to 0xff.
					void WebPBlendAlpha(WebPPicture* pic, uint background_rgb); 
					
					//------------------------------------------------------------------------------
					//Main call
					
					//Main encoding call, after config and picture have been initialized.
					//'picture' must be less than 16384x16384 in dimension (cf WEBP_MAX_DIMENSION),
					//and the 'config' object must be a valid one.
					//Returns false in case of error, true otherwise.
					//In case of error, picture->error_code is updated accordingly.
					//'picture' can hold the source samples in both YUV(A) or ARGB input, depending
					//on the value of 'picture->use_argb'. It is highly recommended to use
					//the former for lossy encoding, and the latter for lossless encoding
					//(when config.lossless is true). Automatic conversion from one format to
					//another is provided but they both incur some loss.
					int WebPEncode(const WebPConfig* config, WebPPicture* picture); 
					
					//------------------------------------------------------------------------------
					
				} extern (C)
				{
					//Copyright 2010 Google Inc. All Rights Reserved.
					//
					//Use of this source code is governed by a BSD-style license
					//that can be found in the COPYING file in the root of the source
					//tree. An additional intellectual property rights grant can be found
					//in the file PATENTS. All contributing project authors may
					//be found in the AUTHORS file in the root of the source tree.
					//-----------------------------------------------------------------------------
					//
					//Main decoding functions for WebP images.
					//
					//Author: Skal (pascal.massimino@gmail.com)
					
					import std.typecons; 
					
					enum WEBP_DECODER_ABI_VERSION = 0x0203;    //MAJOR(8b) + MINOR(8b)
					
					
					alias WebPIDecoder = Typedef!(void*); 
					
					
					//Return the decoder's version number, packed in hexadecimal using 8bits for
					//each of major/minor/revision. E.g: v2.5.7 is 0x020507.
					int WebPGetDecoderVersion(); 
					
					//Retrieve basic header information: width, height.
					//This function will also validate the header and return 0 in
					//case of formatting error.
					//Pointers 'width' and 'height' can be passed NULL if deemed irrelevant.
					int WebPGetInfo(const ubyte* data, size_t data_size, int* width, int* height); 
					
					//Decodes WebP images pointed to by 'data' and returns RGBA samples, along
					//with the dimensions in *width and *height. The ordering of samples in
					//memory is R, G, B, A, R, G, B, A... in scan order (endian-independent).
					//The returned pointer should be deleted calling free().
					//Returns NULL in case of error.
					ubyte* WebPDecodeRGBA(const ubyte* data, size_t data_size, int* width, int* height); 
					
					//Same as WebPDecodeRGBA, but returning A, R, G, B, A, R, G, B... ordered data.
					ubyte* WebPDecodeARGB(const ubyte* data, size_t data_size, int* width, int* height); 
					
					//Same as WebPDecodeRGBA, but returning B, G, R, A, B, G, R, A... ordered data.
					ubyte* WebPDecodeBGRA(const ubyte* data, size_t data_size, int* width, int* height); 
					
					//Same as WebPDecodeRGBA, but returning R, G, B, R, G, B... ordered data.
					//If the bitstream contains transparency, it is ignored.
					ubyte* WebPDecodeRGB(const ubyte* data, size_t data_size, int* width, int* height); 
					
					//Same as WebPDecodeRGB, but returning B, G, R, B, G, R... ordered data.
					ubyte* WebPDecodeBGR(const ubyte* data, size_t data_size, int* width, int* height); 
					
					
					//Decode WebP images pointed to by 'data' to Y'UV format(*). The pointer
					//returned is the Y samples buffer. Upon return, *u and *v will point to
					//the U and V chroma data. These U and V buffers need NOT be free()'d,
					//unlike the returned Y luma one. The dimension of the U and V planes
					//are both (*width + 1) / 2 and (*height + 1)/ 2.
					//Upon return, the Y buffer has a stride returned as '*stride', while U and V
					//have a common stride returned as '*uv_stride'.
					//Return NULL in case of error.
					//(*) Also named Y'CbCr. See: http://en.wikipedia.org/wiki/YCbCr
					ubyte* WebPDecodeYUV(
						const ubyte* data, size_t data_size,
						int* width, int* height,
						ubyte** u, ubyte** v,
						int* stride, int* uv_stride
					); 
					
					//These five functions are variants of the above ones, that decode the image
					//directly into a pre-allocated buffer 'output_buffer'. The maximum storage
					//available in this buffer is indicated by 'output_buffer_size'. If this
					//storage is not sufficient (or an error occurred), NULL is returned.
					//Otherwise, output_buffer is returned, for convenience.
					//The parameter 'output_stride' specifies the distance (in bytes)
					//between scanlines. Hence, output_buffer_size is expected to be at least
					//output_stride x picture-height.
					ubyte* WebPDecodeRGBAInto(
						const ubyte* data, size_t data_size,
						ubyte* output_buffer, size_t output_buffer_size, int output_stride
					); 
					ubyte* WebPDecodeARGBInto(
						const ubyte* data, size_t data_size,
						ubyte* output_buffer, size_t output_buffer_size, int output_stride
					); 
					ubyte* WebPDecodeBGRAInto(
						const ubyte* data, size_t data_size,
						ubyte* output_buffer, size_t output_buffer_size, int output_stride
					); 
					
					//RGB and BGR variants. Here too the transparency information, if present,
					//will be dropped and ignored.
					ubyte* WebPDecodeRGBInto(
						const ubyte* data, size_t data_size,
						ubyte* output_buffer, size_t output_buffer_size, int output_stride
					); 
					ubyte* WebPDecodeBGRInto(
						const ubyte* data, size_t data_size,
						ubyte* output_buffer, size_t output_buffer_size, int output_stride
					); 
					
					//WebPDecodeYUVInto() is a variant of WebPDecodeYUV() that operates directly
					//into pre-allocated luma/chroma plane buffers. This function requires the
					//strides to be passed: one for the luma plane and one for each of the
					//chroma ones. The size of each plane buffer is passed as 'luma_size',
					//'u_size' and 'v_size' respectively.
					//Pointer to the luma plane ('*luma') is returned or NULL if an error occurred
					//during decoding (or because some buffers were found to be too small).
					
					ubyte* WebPDecodeYUVInto(
						const ubyte* data, size_t data_size,
						ubyte* luma, size_t luma_size, int luma_stride,
						ubyte* u, size_t u_size, int u_stride,
						ubyte* v, size_t v_size, int v_stride
					); 
					
					//------------------------------------------------------------------------------
					//Output colorspaces and buffer
					
					//Colorspaces
					//Note: the naming describes the byte-ordering of packed samples in memory.
					//For instance, MODE_BGRA relates to samples ordered as B,G,R,A,B,G,R,A,...
					//Non-capital names (e.g.:MODE_Argb) relates to pre-multiplied RGB channels.
					//RGBA-4444 and RGB-565 colorspaces are represented by following byte-order:
					//RGBA-4444: [r3 r2 r1 r0 g3 g2 g1 g0], [b3 b2 b1 b0 a3 a2 a1 a0], ...
					//RGB-565: [r4 r3 r2 r1 r0 g5 g4 g3], [g2 g1 g0 b4 b3 b2 b1 b0], ...
					//In the case WEBP_SWAP_16BITS_CSP is defined, the bytes are swapped for
					//these two modes:
					//RGBA-4444: [b3 b2 b1 b0 a3 a2 a1 a0], [r3 r2 r1 r0 g3 g2 g1 g0], ...
					//RGB-565: [g2 g1 g0 b4 b3 b2 b1 b0], [r4 r3 r2 r1 r0 g5 g4 g3], ...
					
					enum WEBP_CSP_MODE
					{
						MODE_RGB = 0, MODE_RGBA = 1,
						MODE_BGR = 2, MODE_BGRA = 3,
						MODE_ARGB = 4, MODE_RGBA_4444 = 5,
						MODE_RGB_565 = 6,
						//RGB-premultiplied transparent modes (alpha value is preserved)
						MODE_rgbA = 7,
						MODE_bgrA = 8,
						MODE_Argb = 9,
						MODE_rgbA_4444 = 10,
						//YUV modes must come after RGB ones.
						MODE_YUV = 11, MODE_YUVA = 12,  //yuv 4:2:0
						MODE_LAST = 13
					} 
					
					//Some useful macros:
					static int WebPIsPremultipliedMode(WEBP_CSP_MODE mode)
					{
						return (
							mode == WEBP_CSP_MODE.MODE_rgbA || 
							mode == WEBP_CSP_MODE.MODE_bgrA || 
							mode == WEBP_CSP_MODE.MODE_Argb ||
							mode == WEBP_CSP_MODE.MODE_rgbA_4444
						); 
					} 
					
					static int WebPIsAlphaMode(WEBP_CSP_MODE mode)
					{
						return (
							mode == WEBP_CSP_MODE.MODE_RGBA || 
							mode == WEBP_CSP_MODE.MODE_BGRA || 
							mode == WEBP_CSP_MODE.MODE_ARGB ||
							mode == WEBP_CSP_MODE.MODE_RGBA_4444 || 
							mode == WEBP_CSP_MODE.MODE_YUVA ||
							WebPIsPremultipliedMode(mode)
						); 
					} 
					
					static int WebPIsRGBMode(WEBP_CSP_MODE mode)
					{ return (mode < WEBP_CSP_MODE.MODE_YUV); } 
					
					//------------------------------------------------------------------------------
					//WebPDecBuffer: Generic structure for describing the output sample buffer.
					
					struct WebPRGBABuffer
					{
							//view as RGBA
						ubyte* rgba;    //pointer to RGBA samples
						int stride; 	     //stride in bytes from one scanline to the next.
						size_t size; 	     //total size of the *rgba buffer.
					}; 
					
					struct WebPYUVABuffer
					{
												//view as YUVA
						ubyte* y; 
						ubyte *u; 
						ubyte *v; 
						ubyte *a; 	//pointer to luma, chroma U/V, alpha samples
						int y_stride; 		    //luma stride
						int u_stride,	v_stride; 	    //chroma strides
						int a_stride; 					 //alpha stride
						size_t y_size; 				 //luma plane size
						size_t u_size, v_size; 	    //chroma planes size
						size_t a_size; 	    //alpha-plane size
					}; 
					
					//Output buffer
					struct WebPDecBuffer
					{
						WEBP_CSP_MODE colorspace; 	//Colorspace.
						int width, height; 	//Dimensions.
						int is_external_memory; 	//If true, 'internal_memory' pointer is not used.
						union u
						{
							WebPRGBABuffer RGBA; 
							WebPYUVABuffer YUVA; 
						} //Nameless union of buffer parameters.
						uint[4] pad;               //padding for later use
						
						ubyte* private_memory; 	//Internally allocated memory (only when
							//is_external_memory is false). Should not be used
							//externally, but accessed via the buffer union.
					}; 
					
					//Internal, version-checked, entry point
					int WebPInitDecBufferInternal(WebPDecBuffer*, int); 
					
					//Initialize the structure as empty. Must be called before any other use.
					//Returns false in case of version mismatch
					static int WebPInitDecBuffer(WebPDecBuffer* buffer)
					{ return WebPInitDecBufferInternal(buffer, WEBP_DECODER_ABI_VERSION); } 
					
					//Free any memory associated with the buffer. Must always be called last.
					//Note: doesn't free the 'buffer' structure itself.
					void WebPFreeDecBuffer(WebPDecBuffer* buffer); 
					
					//------------------------------------------------------------------------------
					//Enumeration of the status codes
					
					enum VP8StatusCode
					{
						VP8_STATUS_OK = 0,
						VP8_STATUS_OUT_OF_MEMORY,
						VP8_STATUS_INVALID_PARAM,
						VP8_STATUS_BITSTREAM_ERROR,
						VP8_STATUS_UNSUPPORTED_FEATURE,
						VP8_STATUS_SUSPENDED,
						VP8_STATUS_USER_ABORT,
						VP8_STATUS_NOT_ENOUGH_DATA
					} 
					
					//------------------------------------------------------------------------------
					//Incremental decoding
					//
					//This API allows streamlined decoding of partial data.
					//Picture can be incrementally decoded as data become available thanks to the
					//WebPIDecoder object. This object can be left in a SUSPENDED state if the
					//picture is only partially decoded, pending additional input.
					//Code example:
					//
					//   WebPInitDecBuffer(&buffer);
					//   buffer.colorspace = mode;
					//   ...
					//   WebPIDecoder* idec = WebPINewDecoder(&buffer);
					//   while (has_more_data) {
					//// ... (get additional data)
					//status = WebPIAppend(idec, new_data, new_data_size);
					//if (status != VP8_STATUS_SUSPENDED ||
					//   break;
					//}
					//
					//// The above call decodes the current available buffer.
					//// Part of the image can now be refreshed by calling to
					//// WebPIDecGetRGB()/WebPIDecGetYUVA() etc.
					//   }
					//   WebPIDelete(idec);
					
					//Creates a new incremental decoder with the supplied buffer parameter.
					//This output_buffer can be passed NULL, in which case a default output buffer
					//is used (with MODE_RGB). Otherwise, an internal reference to 'output_buffer'
					//is kept, which means that the lifespan of 'output_buffer' must be larger than
					//that of the returned WebPIDecoder object.
					//The supplied 'output_buffer' content MUST NOT be changed between calls to
					//WebPIAppend() or WebPIUpdate() unless 'output_buffer.is_external_memory' is
					//set to 1. In such a case, it is allowed to modify the pointers, size and
					//stride of output_buffer.u.RGBA or output_buffer.u.YUVA, provided they remain
					//within valid bounds.
					//All other fields of WebPDecBuffer MUST remain constant between calls.
					//Returns NULL if the allocation failed.
					WebPIDecoder* WebPINewDecoder(WebPDecBuffer* output_buffer); 
					
					//This function allocates and initializes an incremental-decoder object, which
					//will output the RGB/A samples specified by 'csp' into a preallocated
					//buffer 'output_buffer'. The size of this buffer is at least
					//'output_buffer_size' and the stride (distance in bytes between two scanlines)
					//is specified by 'output_stride'.
					//Additionally, output_buffer can be passed NULL in which case the output
					//buffer will be allocated automatically when the decoding starts. The
					//colorspace 'csp' is taken into account for allocating this buffer. All other
					//parameters are ignored.
					//Returns NULL if the allocation failed, or if some parameters are invalid.
					WebPIDecoder* WebPINewRGB(
						WEBP_CSP_MODE csp,
						ubyte* output_buffer, size_t output_buffer_size, 
						int output_stride
					); 
					
					//This function allocates and initializes an incremental-decoder object, which
					//will output the raw luma/chroma samples into a preallocated planes if
					//supplied. The luma plane is specified by its pointer 'luma', its size
					//'luma_size' and its stride 'luma_stride'. Similarly, the chroma-u plane
					//is specified by the 'u', 'u_size' and 'u_stride' parameters, and the chroma-v
					//plane by 'v' and 'v_size'. And same for the alpha-plane. The 'a' pointer
					//can be pass NULL in case one is not interested in the transparency plane.
					//Conversely, 'luma' can be passed NULL if no preallocated planes are supplied.
					//In this case, the output buffer will be automatically allocated (using
					//MODE_YUVA) when decoding starts. All parameters are then ignored.
					
					//Returns NULL if the allocation failed or if a parameter is invalid.
					WebPIDecoder* WebPINewYUVA(
						ubyte* luma, size_t luma_size, int luma_stride,
						ubyte* u, size_t u_size, int u_stride,
						ubyte* v, size_t v_size, int v_stride,
						ubyte* a, size_t a_size, int a_stride
					); 
					
					//Deprecated version of the above, without the alpha plane.
					//Kept for backward compatibility.
					WebPIDecoder* WebPINewYUV(
						ubyte* luma, size_t luma_size, int luma_stride,
						ubyte* u, size_t u_size, int u_stride,
						ubyte* v, size_t v_size, int v_stride
					); 
					
					//Deletes the WebPIDecoder object and associated memory. Must always be called
					//if WebPINewDecoder, WebPINewRGB or WebPINewYUV succeeded.
					void WebPIDelete(WebPIDecoder* idec); 
					
					//Copies and decodes the next available data. Returns VP8_STATUS_OK when
					//the image is successfully decoded. Returns VP8_STATUS_SUSPENDED when more
					//data is expected. Returns error in other cases.
					VP8StatusCode WebPIAppend(WebPIDecoder* idec, const ubyte* data, size_t data_size); 
					
					//A variant of the above function to be used when data buffer contains
					//partial data from the beginning. In this case data buffer is not copied
					//to the internal memory.
					//Note that the value of the 'data' pointer can change between calls to
					//WebPIUpdate, for instance when the data buffer is resized to fit larger data.
					VP8StatusCode WebPIUpdate(WebPIDecoder* idec, const ubyte* data, size_t data_size); 
					
					//Returns the RGB/A image decoded so far. Returns NULL if output params
					//are not initialized yet. The RGB/A output type corresponds to the colorspace
					//specified during call to WebPINewDecoder() or WebPINewRGB().
					//*last_y is the index of last decoded row in raster scan order. Some pointers
					//(*last_y, *width etc.) can be NULL if corresponding information is not
					//needed.
					ubyte* WebPIDecGetRGB(
						const WebPIDecoder* idec, int* last_y,
						int* width, int* height, int* stride
					); 
					
					//Same as above function to get a YUVA image. Returns pointer to the luma
					//plane or NULL in case of error. If there is no alpha information
					//the alpha pointer '*a' will be returned NULL.
					ubyte* WebPIDecGetYUVA(
						const WebPIDecoder* idec, int* last_y,
						ubyte** u, ubyte** v, ubyte** a,
						int* width, int* height, int* stride, int* uv_stride, int* a_stride
					); 
					
					//Deprecated alpha-less version of WebPIDecGetYUVA(): it will ignore the
					//alpha information (if present). Kept for backward compatibility.
					static ubyte* WebPIDecGetYUV(
						const WebPIDecoder* idec, int* last_y, ubyte** u, ubyte** v,
						int* width, int* height, int* stride, int* uv_stride
					)
					{
						return WebPIDecGetYUVA(
							idec, last_y, u, v, null, width, height,
													 stride, uv_stride, null
						); 
					} 
					
					//Generic call to retrieve information about the displayable area.
					//If non NULL, the left/right/width/height pointers are filled with the visible
					//rectangular area so far.
					//Returns NULL in case the incremental decoder object is in an invalid state.
					//Otherwise returns the pointer to the internal representation. This structure
					//is read-only, tied to WebPIDecoder's lifespan and should not be modified.
					
					//Todo: Review. I don't know, is this correct.
					//WEBP_EXTERN(const WebPDecBuffer*) WebPIDecodedArea(
					//const WebPIDecoder* idec, int* left, int* top, int* width, int* height);
					WebPDecBuffer* WebPIDecodedArea(const WebPIDecoder* idec, int* left, int* top, int* width, int* height); 
					
					//------------------------------------------------------------------------------
					//Advanced decoding parametrization
					//
					//Code sample for using the advanced decoding API
					/*
						 // A) Init a configuration object
						 WebPDecoderConfig config;
						 CHECK(WebPInitDecoderConfig(&config));
						
						 // B) optional: retrieve the bitstream's features.
						 CHECK(WebPGetFeatures(data, data_size, &config.input) == VP8_STATUS_OK);
						
						 // C) Adjust 'config', if needed
						 config.no_fancy_upsampling = 1;
						 config.output.colorspace = MODE_BGRA;
						 // etc.
						
						 // Note that you can also make config.output point to an externally
						 // supplied memory buffer, provided it's big enough to store the decoded
						 // picture. Otherwise, config.output will just be used to allocate memory
						 // and store the decoded picture.
						
						 // D) Decode!
						 CHECK(WebPDecode(data, data_size, &config) == VP8_STATUS_OK);
						
						 // E) Decoded image is now in config.output (and config.output.u.RGBA)
						
						 // F) Reclaim memory allocated in config's object. It's safe to call
						 // this function even if the memory is external and wasn't allocated
						 // by WebPDecode().
						 WebPFreeDecBuffer(&config.output);
					*/
					
					//Features gathered from the bitstream
					struct WebPBitstreamFeatures
					{
						int width; 	 //Width in pixels, as read from the bitstream.
						int height; 	 //Height in pixels, as read from the bitstream.
						int has_alpha; 	 //True if the bitstream contains an alpha channel.
						int has_animation; 	 //True if the bitstream is an animation.
						int format; 	 //0 = undefined (/mixed), 1 = lossy, 2 = lossless
						
						//Unused for now:
						int no_incremental_decoding; 	 //if true, using incremental decoding is not
						 //recommended.
						int rotate; 	 //TODO(later)
						int uv_sampling; 	 //should be 0 for now. TODO(later)
						uint[2] pad;              //padding for later use
					}; 
					
					//Internal, version-checked, entry point
					VP8StatusCode WebPGetFeaturesInternal(const ubyte*, size_t, WebPBitstreamFeatures*, int); 
					
					//Retrieve features from the bitstream. The *features structure is filled
					//with information gathered from the bitstream.
					//Returns VP8_STATUS_OK when the features are successfully retrieved. Returns
					//VP8_STATUS_NOT_ENOUGH_DATA when more data is needed to retrieve the
					//features from headers. Returns error in other cases.
					static VP8StatusCode WebPGetFeatures(
						const ubyte* data, size_t data_size,
						WebPBitstreamFeatures* features
					)
					{
						return WebPGetFeaturesInternal(
							data, data_size, features,
							WEBP_DECODER_ABI_VERSION
						); 
					} 
					
					//Decoding options
					struct WebPDecoderOptions
					{
						int bypass_filtering; 	   //if true, skip the in-loop filtering
						int no_fancy_upsampling; 	   //if true, use faster pointwise upsampler
						int use_cropping; 	   //if true, cropping is applied _first_
						int crop_left, crop_top; 	   //top-left position for cropping.
						   //Will be snapped to even values.
						int crop_width, crop_height; 	   //dimension of the cropping area
						int use_scaling; 	   //if true, scaling is applied _afterward_
						int scaled_width, scaled_height; 	   //final resolution
						int use_threads; 	   //if true, use multi-threaded decoding
						int dithering_strength; 	   //dithering strength (0=Off, 100=full)
						
						//Unused for now:
						int force_rotation; 																 //forced rotation (to be applied _last_)
						int no_enhancement; 																 //if true, discard enhancement layer
						uint[4] pad;                        //padding for later use
					} 
					
					//Main object storing the configuration for advanced decoding.
					struct WebPDecoderConfig
					{
						WebPBitstreamFeatures input; 	 //Immutable bitstream features (optional)
						WebPDecBuffer output; 	 //Output buffer (can point to external mem)
						WebPDecoderOptions options; 	 //Decoding options
					}; 
					
					//Internal, version-checked, entry point
					int WebPInitDecoderConfigInternal(WebPDecoderConfig*, int); 
					
					//Initialize the configuration as empty. This function must always be
					//called first, unless WebPGetFeatures() is to be called.
					//Returns false in case of mismatched version.
					static int WebPInitDecoderConfig(WebPDecoderConfig* config)
					{ return WebPInitDecoderConfigInternal(config, WEBP_DECODER_ABI_VERSION); } 
					
					//Instantiate a new incremental decoder object with the requested
					//configuration. The bitstream can be passed using 'data' and 'data_size'
					//parameter, in which case the features will be parsed and stored into
					//config->input. Otherwise, 'data' can be NULL and no parsing will occur.
					//Note that 'config' can be NULL too, in which case a default configuration
					//is used.
					//The return WebPIDecoder object must always be deleted calling WebPIDelete().
					//Returns NULL in case of error (and config->status will then reflect
					//the error condition).
					WebPIDecoder* WebPIDecode(
						const ubyte* data, size_t data_size,
						WebPDecoderConfig* config
					); 
					
					//Non-incremental version. This version decodes the full data at once, taking
					//'config' into account. Returns decoding status (which should be VP8_STATUS_OK
					//if the decoding was successful).
					VP8StatusCode WebPDecode(
						const ubyte* data, size_t data_size,
						WebPDecoderConfig* config
					); 
					
				} 
			}
			
		}
	} 
}

version(/+$DIDE_REGION+/all)
{
	immutable supportedBitmapExts = ["webp", "png", "jpg", "jpeg", "bmp", "tga", "gif"]; 
	immutable supportedBitmapFilter = supportedBitmapExts.map!(a=>"*."~a).join(';'); 
	
	File[] bitmapFiles(in Path p)
	{ return p.files(supportedBitmapFilter); } 
	
	struct BitmapInfo
	{
		string format; 
		ivec2 size; 
		int chn; 
		
		bool valid() const
		{ return supportedBitmapExts.canFind(format) && chn.inRange(1, 4) && size.area>0; } 
		
		int numPixels() const
		{ return size[].product; } 
		
		const ref auto width()
		{ return size.x; } 
		const ref auto height()
		{ return size.y; } 
		
		private static
		{
			
			//Todo: there should be isWebp() accessible from the outside. And the below stuff should be named detectWebp
			
			bool isWebp(in ubyte[] s)
			{
				return 	s.length>16 && s[0..4].equal("RIFF") && s[8..15].equal("WEBPVP8") 
					&& s[15].among(' ', 'L', 'X'); 
			} 
			bool isJpg (in ubyte[] s)
			{ return s.startsWith([0xff, 0xd8, 0xff]); } 
			bool isPng (in ubyte[] s)
			{ return s.startsWith([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a]); } 
			bool isBmp (in ubyte[] s)
			{
				return 	s.length>18 && s[0..2].equal("BM") 
					&& (cast(uint[])s[14..18])[0].among(12, 40, 52, 56, 108, 124); 
			} 
			bool isGif (in ubyte[] s)
			{
				return 	s.length>=6+7 && s[0..4].equal("GIF8") 
					&& s[4].among('7', '9') && s[5]=='a'; 
			} 
			
			bool isTga (in ubyte[] s)
			{
				 //tga detection is really loose, so it's on the last place...
				if(s.length>18)
				{
					auto us(int i)
					{ return (cast(ushort[])s[i..i+2])[0]; } 
					const badTga = 
					(
						us(12) < 1 || us(14) < 1 || s[1] > 1
						|| (s[1] == 0 && (us(3) || us(5) || s[7])) //palette is off, but has palette info
						|| (4 <= s[2] && s[2] <= 8) || 12 <= s[2]
					); 
					if(!badTga) return true; 
				}
				return false; 
			} 
			
			string detectFormat(in File fileName, in ubyte[] stream)
			{
				 alias s = stream; 
				if(!stream.empty)
				{
					if(isJpg (s)) return "jpg"; 
					if(isPng (s)) return "png"; 
					if(isBmp (s)) return "bmp"; 
					if(isWebp(s)) return "webp"; 
					if(isTga (s)) return "tga"; 
					if(isGif (s)) return "gif"; 
				}
				
				//unable to detect from stream, try fileExt
				if(stream.empty)
				{
					string e = fileName.ext.lc; 
					if(e.startsWith(".")) e = e[1..$]; 
					
					if(supportedBitmapExts.canFind(e))
					{
						if(e=="jpeg") e = "jpg"; //synonim
						return e; 
					}
				}
				
				return ""; 
			} 
			
		} 
		
		private: 
		
		void detectInfo(in ubyte[] stream)
		{
			if(stream.empty) return; 
			if(format=="webp")
			{
				WebPBitstreamFeatures features; 
				if(WebPGetFeatures(stream.ptr, stream.length, &features)==VP8StatusCode.VP8_STATUS_OK)
				{
					size = ivec2(features.width, features.height); 
					chn = features.has_alpha ? 4 : 3; 
				}
			}
			else if(format=="gif")
			{
				try {
					enforce(stream.length>=10); 
					const us = cast(ushort[])stream[0..10]; 
					size = ivec2(us[3], us[4]); 
					chn = 4; 
				}catch(Exception) {}
			}
			else if(supportedBitmapExts.canFind(format))
			{
				 //use imageFormats package. It should be good for libjpeg-turbo as well.
				try { read_image_info_from_mem(stream, size.x, size.y, chn); }catch(Exception) {}
			}
		} 
		
		public: 
		
		this(in File fileName, in ubyte[] stream)
		{
			format = detectFormat(fileName, stream); 
			
			if(format.empty) return; 
			detectInfo(stream); 
		} 
		
		this(in ubyte[] stream)
		{ this(File(""), stream); } 
		/+
			this(in File fileName)
			{
				enum peekSize = 64; 
				//todo: it's not enough for jpeg.
				this(fileName, fileName.read(false, 0, peekSize)); 
			} 
		+/
	} 
	
	
	class Bitmap
	{
		//Todo: Bitmaps as const (in) parameters. Currentrly they are useles.
		
		private
		{
			ubyte[] data_; /+
				Todo: this storage can't handle stride. It should be pitch and in bytes.
				Also do this in image!
				
				250616: Image has stride! But this doesn't needs it. 
				It is simple to upload as a texture if it has no stride.
				Bitmap is more like a storage and image is like a reference.
			+/
			string type_ = "ubyte"; //Todo: This must be an enum!
			
			/+Todo: _data storage type must be ubyte[]  !!! Because void[] is searched by GC!!!!!+/
			//Todo: 1, 2, 4 bit modes!
			
			int width_, height_, channels_=4; 
		} 
		
		File file; 
		DateTime modified; 
		string error; 
		bool loading, removed; 	//Todo: these are managed by bitmaps(). Should be protected and readonly.
		bool processed; 	//user flag. Can do postprocessing after the image is loaded
		bool resident; 	//if true, garbageCollector will nor free this
		
		uint accessed_tick; //garbageCollect using it
		
		Object extraData; 
		
		@property bool unloadable() const
		{
			enum recentlyUsedTicks = 3; 
			return 	!resident
				&& !loading
				&& !removed
				&& accessed_tick+recentlyUsedTicks <= application.tick; 
		} 
		
		bool valid()
		{ return !empty && !loading && error==""; } 
		//Todo: this is not the best because first must check for (this !is null) from the outside
		
		bool canProcess()
		{ return valid && !processed; } 
		
		void markChanged()
		{ modified.actualize; } 
		
		//Todo: constraints
		//Todo: fileName
		//Todo: GLResource linking
		//Todo: subTexture ID linking
		//Todo: delayed load
		
		//constructors
		this()
		{} 
		this(T)(Image!(T, 2) img)
		{ set(img); } 
		//in general: use newBitmap() to create a bitmap
		
		bool empty()
		{ return data_.length==0 || width<=0 || height<=0 || channels<=0; } 
		size_t sizeBytes() const
		{ return data_.length; } 
		
		void waitFor()
		{ while(loading) sleep(3); } 
		
		@property width	 () const
		{ return width_	; } 
		@property height () const
		{ return height_	; } 
		@property size () const
		{ return ivec2(width, height); } 
		@property bounds	 () const
		{ return ibounds2(ivec2(0), size); } 
		@property channels() const
		{ return channels_; } 
		@property type    () const
		{ return type_; } 
		
		ubyte[] getRaw()
		=> data_; 
		
		void setRaw(void[] data, int width, int height, int channels, string type)
		{
			//check consistency
			auto chSize = type.predSwitch("ubyte", 1, "float", 4, "int", 4, "ushort", 2, 0); 
			enforce(
				chSize>0 ,
				type.format!`Invalid bitmap component type: "%s"`
			); 
			enforce(
				channels.inRange(1, 4), 
				channels.format!`Invalid number of bitmap channels: "%s"`
			); 
			enforce(
				width>=0, 
				width.format!`Invalid bitmap width: "%s"`
			); 
			enforce(
				height>=0, 
				height.format!`Invalid bitmap height: "%s"`
			); 
			enforce(
				width*height*channels*chSize == data.length,
				format!"Inconsistent bitmap size: %s{w} * %s{h} * %s{ch} * %s != %s{bytes}"
				(width, height, channels, chSize, data.length)
			); 
			data_ = (cast(ubyte[])(data)); 
			width_ = width; 
			height_ = height; 
			channels_ = channels; 
			type_ = type; 
		} 
		
		
		void set(E)(Image!(E, 2) im)
		{
			const typeStr = (ScalarType!E).stringof; 
			setRaw(im.asArray, im.width, im.height, VectorLength!E, typeStr); 
		} 
		
		private auto getImage_unsafe(E)()
		{ return Image2D!(Unqual!E)(ivec2(width_, height_), cast(Unqual!E[]) data_); } 
		
		auto access(E)()
		{
			//If the format is matching, it retuns a reference to the stored image. Otherwise it throws.
			enforce(
				VectorLength!E == channels,
				format!"channel mismatch (reqd, present): (%s, %s)"(VectorLength!E, channels)
			); 
			enforce(
				(ScalarType!E).stringof == type,
				"type mismatch"
			); 
			return getImage_unsafe!E; 
		} 
		
		auto get(E)() const
		{
			//it duplicates and converts if needed
			
			static foreach(T; AliasSeq!(ubyte, RG, RGB, RGBA, float, vec2, vec3, vec4))
			{
				{
					alias CT = ScalarType   !T,
					len = VectorLength!T; 
					if(type==CT.stringof && len==channels)
					{
						auto im = (cast()this).getImage_unsafe!T; 
						static if(is(T==E))	return im.dup; 
						else static if(is(T==RGB) && is(E==RGBA))	{ return image2D(size, im.asArray.rgb_to_rgba); }
						else static if(is(T==ubyte) && is(E==RGBA))	{ return image2D(size, im.asArray.l_to_rgba); }
						else	{
							return im.image2D!(
								a => a.convertPixel!E
								/+the slowest way+/
							); 
						}
					}
				}
			}
			
			raise("unsupported bitmap format"); assert(0); 
		} 
		
		auto accessOrGet(E)()
		{
			//First it tries to access(), and if is not possible uses get() to convert.
			//It always returns somthing, and when the format matches, it returns the reference of the stored image.
			if(VectorLength!E == channels && (ScalarType!E).stringof == type) return getImage_unsafe!E; 
			return get!E; 
		} 
		
		void resizeInPlace_nearest(ivec2 newSize)
		{
			static foreach(T; AliasSeq!(ubyte, RG, RGB, RGBA, float, vec2, vec3, vec4))
			{
				{
					alias CT = ScalarType   !T,
					len = VectorLength!T; 
					if(CT.stringof == type && len==channels) {
						set(access!T.resize_nearest(newSize)); 
						return; 
					}
				}
			}
			
			raise("unsupported bitmap format"); assert(0); 
		} 
		
		auto resize_nearest(ivec2 newSize)
		{
			static foreach(T; AliasSeq!(ubyte, RG, RGB, RGBA, float, vec2, vec3, vec4))
			{
				{
					 //Todo: redundant
					alias CT = ScalarType!T,
					len = VectorLength!T; 
					if(CT.stringof == type && len==channels) {
						auto b = new Bitmap(access!T.resize_nearest(newSize)); 
						b.file = file; //Todo: redundant
						b.modified = modified; 
						b.error = error; 
						return b; 
					}
				}
			}
			raise("unsupported bitmap format"); assert(0); 
		} 
		
		override string toString() const
		{
			return format(
				"Bitmap(%s, %d, %d, %d, %s, %s, %s, %s)",
				file, width, height, channels, type.quoted, modified.timestamp,
				"["~ [loading?"loading":"", removed?"removed":""].join(", " ) ~"]",
				error ? "error: "~error : ""
			); 
		} 
		
		string details()
		{
			return format!"%-50s   res: %-11s   MP: %5.1f   chn: %s   compr.size: %4sB   uncompr.size: %4sB   ratio:%4.1f%%   bpp:%6.2f"
			(
				file.fullName, width.text~"x"~height.text, double(width)*height/1_000_000, channels, file.size.shortSizeText!1024,
				sizeBytes.shortSizeText!1024, double(file.size)*100/sizeBytes, double(file.size)/width/height*8
			); 
		} 
		
		void assign(Bitmap b)
		{
			enforce(b); 
			setRaw(b.data_, b.width_, b.height_, b.channels_, b.type_); 
			error = b.error; 
			markChanged; 
		} 
		
		Bitmap dup(Flag!"shallow" shallow = No.shallow)
		{
			auto b = new Bitmap; 
			b.file = file; 
			b.modified = modified; 
			b.error = error; 
			b.setRaw(shallow ? data_ : data_.dup, width, height, channels, type); 
			return b; 
		} 
		
		Bitmap shallowDup()
		{ return dup(Yes.shallow); } 
		
		void saveTo(F)(in F file)
		{
			auto f = File(file); 
			this.serialize(f.ext.withoutStarting('.')).saveTo(f); 
		} 
		
		void loadFrom(F)(in F file)
		{
			auto f = File(file); 
			auto b = f.read.deserialize!Bitmap; 
			copyFrom(b); //Todo: mi a faszom ez a copyFrom????
		} 
		
		void update(E)(Image!(E, 2) im)
		{
			set(im); 
			markChanged; 
			bitmaps.set(this); 
		} 
		
		void update(File f)
		{
			file = f; 
			markChanged; 
			bitmaps.set(this); 
		} 
		
		
		//advanced image handling
		
		
	} 
	
	//Bitmap/Image serializer //////////////////////////////////////////
	
	immutable serializeImage_supportedFormats = ["webp", "png", "bmp", "tga", "jpg"]; 
	
	__gshared serializeImage_defaultFormat = "png"; 
	//png is the best because it knows 1..4 components and it's moderately compressed.
	
	private static ubyte[] write_webp_to_mem(int width, int height, ubyte[] data, int quality)
	{
		//Reasonable quality=95,  best=100,  worst=0,  lossless=101 and up
		//Note: the header is in the same syntax like in the imageformats module.
		
		ubyte* output; 
		size_t size; 
		const lossy = quality<=100; //101 and up means lossless
		const channels = data.length.to!int/(width*height); 
		enforce(data.length = width*height*channels, "invalid image data"); 
		
		switch(channels)
		{
			case 4: 	size = ((lossy)?(WebPEncodeRGBA       (data.ptr, width, height, width*channels, quality, &output)) :(WebPEncodeLosslessRGBA(data.ptr, width, height, width*channels,        &output))); 	break; 
			case 3: 	size = ((lossy)?(WebPEncodeRGB        (data.ptr, width, height, width*channels, quality, &output)) :(WebPEncodeLosslessRGB (data.ptr, width, height, width*channels,        &output))); 	break; 
			default: 	enforce(0, "8/16bit webp not supported"); //Todo: Y, YA plane-kkal megoldani ezeket is
		}
		
		//Todo: tovabbi info a webp-rol: az alpha az csak lossless modon van tomoritve. Lehet, hogy azt is egy Y-al kene megoldani...
		
		enforce(size, "WebPEncode failed."); 
		
		ubyte[] res = output[0..size].dup; //unoptimal copy
		
		import core.stdc.stdlib : free; 
		free(output); //free the memory that was allocated by LibWebP using malloc()
		
		return res; 
	} 
	
	private static ubyte[] write_jpg_to_mem(int width, int height, ubyte[] data, int quality)
	{
		enforce(quality<=100, "TJPARAM_LOSSLESS not supported yet."); 
		
		const 	channels 	= data.length.to!int/(width*height),
			pitch 	= width*channels; 
		enforce(data.length = pitch*height, "invalid image data"); 
		const pixelFormat = channels.predSwitch(1, TJPF_GRAY, 3, TJPF_RGB); //Todo: alpha
		const subsamp = TJSAMP_420; //Todo: subsamp-ot kihozni
		
		ubyte* jpegBuf; 
		uint jpegSize; 
		tjChk(
			tjEncoder, tjCompress2(
				tjEncoder, data.ptr, width, pitch,
				height, pixelFormat, &jpegBuf, &jpegSize, subsamp, quality, 0
			), "tjCompress2"
		); 
		
		scope(exit) tjFree(jpegBuf); 
		auto res = uninitializedArray!(ubyte[])(jpegSize); 
		res[] = jpegBuf[0..jpegSize]; 
		return res; 
	} 
	
	ubyte[] serializeImage(T)(Image!(T, 2) img, string format="")
	{
		//compile time version
		
		enum chn = VectorLength!T,
		type = (ScalarType!T).stringof; 
		if(format=="") format = serializeImage_defaultFormat; 
		auto fmt = format.commandLineToMap; 
		
		auto getQuality()
		{
			return ("quality" in fmt) 	? fmt["quality"].to!int.clamp(0, 101)
				: 95 /+Default quality for jpeg and webp+/; 
		} 
		
		//Todo: validate parameters for each formats
		
		//Todo: support 8bit bmp
		
		switch(fmt["0"])
		{
			case "bmp": 	return write_bmp_to_mem 
			(
				img.width, img.height, cast(ubyte[])
				img.convertImage_ubyte_chnRemap!([3,4,3,4]).asArray
			); //only 3 and 4 chn supported
			case "png": 	return write_png_to_mem 
			(
				img.width, img.height, cast(ubyte[])
				img.convertImage_ubyte_chnRemap!([1,2,3,4]).asArray
			); //all chn supported
			case "tga": 	return write_tga_to_mem  
			(
				img.width, img.height, cast(ubyte[])
				img.convertImage_ubyte_chnRemap!([1,4,3,4]).asArray
			); //all except 2 chn supported
			case "webp": 	return write_webp_to_mem
			(
				img.width, img.height, cast(ubyte[])
				img.convertImage_ubyte_chnRemap!([3,4,3,4]).asArray, getQuality
			); //only 3 and 4 chn
			case "jpg": 	return write_jpg_to_mem  
			(
				img.width, img.height, cast(ubyte[])
				img.convertImage_ubyte_chnRemap!([1,1,3,3]).asArray, getQuality
			); //losts alpha
			default: 	raise("invalid image serialization format: "~format); return []; 
		}
	} 
	
	ubyte[] serializeImage(Bitmap bmp, string format="")
	{
		//runtime version
		
		//Todo: this runtime code generator should be centralized in Bitmap
		static foreach(T; AliasSeq!(ubyte, RG, RGB, RGBA, float, vec2, vec3, vec4))
		{
			{
				alias CT = ScalarType   !T,
				len = VectorLength!T; 
				if(CT.stringof == bmp.type && len==bmp.channels)
				return mixin("serializeImage(bmp.access!(", T.stringof, "), format)"); 
			}
		}
		
		raise("invalid bitmap format"); assert(0); 
	} 
	
	
	//combined compress function
	ubyte[] serialize(A)(A a, string format="")
	{
		static if(is(A==Bitmap)	) return a.serializeImage(format); 
		else static if(
			isImage2D!A	//Bitmap
		)
		return a.serializeImage(format); 
		else
		static assert(0, "invalid arg"); 
		
	} 
	
	//Todo: implement PPM image codec /////////////////////////////////
	/*
		class Bitmap {
			int width;
			int height;
			ubyte[] data;
			int[] rgba;
		
			this(File fn) {
				load(fn);
			}
		
			this(int w, int h) {
				width = w; height = h;
				data = new ubyte[w * h];
			}
		
			void load(File fn) {
				if(lc(fn.ext)==".ppm") {
					loadPPM(fn);
				}
			}
		
			void loadPPM(File fn) {
				ulong fsize = fn.size;
		
				data = fn.read;
		
				int i, ec;
				while(i<fsize) {
					if(data[i] == '\n') {
						ec++;
						if(ec == 3) break;
					}
					i++;
				}
		
				enforce(ec == 3);
		
				auto header = cast(string)data[0..i];
		
				data = data[i+1..$];
		
				auto list = header.split('\n')
									 .map!(a => to!string(a).strip)
									 .filter!(a => !a.empty)
									 .array;
		
				enforce(list.length == 3);
		
				auto dim = list[1].split(' ')
									 .map!(a => to!int(a))
									 .filter!(a => a>0)
									 .array;
		
				enforce(dim.length == 2);
		
				width = dim[0];
				height = dim[1];
		
				rgba = new int[width*height];
				for(i=0; i<width*height; i++) {
					ubyte R,G,B;
					R = data[3*i];
					G = data[3*i+1];
					B = data[3*i+2];
		
					rgba[i] = 0xFF << 24 | B << 16 | G << 8 | R;
				}
			}
		}
	*/
	
	//Bitmap deserialize ///////////////////////////////////
	
	Bitmap deserialize(T : Bitmap)(in File file, bool mustSucceed=false)
	{
		auto b = deserialize!T(file.read(mustSucceed), mustSucceed); 
		if(b) b.modified = file.modified; 
		return b; 
	} 
	
	Bitmap deserialize(T : Bitmap)(in void[] stream_, bool mustSucceed=false)
	{
		const stream = (cast(const(ubyte[]))(stream_)); 
		Bitmap bmp; 
		try {
			auto info = BitmapInfo(stream); 
			enforce(info.valid, "Invalid bitmap format"); 
			
			bmp = new Bitmap; 
			bmp.modified = now; 
			
			void doWebp()
			{
				switch(info.chn)
				{
					case 3: {
						auto data = uninitializedArray!(RGB [])(info.numPixels); 
						WebPDecodeRGBInto(stream.ptr, stream.length, cast(ubyte*)data.ptr, data.length*3, info.size.x*3); 
						bmp.set(image2D(info.size, data)); 
					}break; 
					case 4: {
						auto data = uninitializedArray!(RGBA[])(info.numPixels); 
						WebPDecodeRGBAInto(stream.ptr, stream.length, cast(ubyte*)data.ptr, data.length*4, info.size.x*4); 
						bmp.set(image2D(info.size, data)); 
					}break; 
					/+
						Opt: WebPDecodeYUVInto-val megcsinalni az 1 es 2 channelt.
						es/vagy  optimizalni specialis functokkal: toFastGrayscale(), toFast1bit()
					+/
					default: raise("webp 1-2chn not impl"); 
				}
			} 
			
			void doImageFormats()
			{
				 //imageFormats package
				auto img = read_image_from_mem(stream); 
				exit: switch(info.chn)
				{
					static foreach(i, T; AliasSeq!(ubyte, RG, RGB, RGBA))
					{ case i+1: bmp.set(image2D(img.w, img.h, cast(T[])img.pixels)); break exit; }
					default: raise("imgformat: fatal error: channels out of range"); 
				}
			} 
			
			void doWebpConversion()
			{
				const s = [QPS].xxh32.to!string(36).text; 
				const tempFileSrc = File(tempPath, `$` ~ s ~ ".src" ); scope(exit) tempFileSrc.remove; 
				const tempFileDst = File(tempPath, `$` ~ s ~ ".webp"); scope(exit) tempFileDst.remove; 
				
				tempFileSrc.write(stream); 
				auto res = execute(["cwebp", "-preset", "photo", "-q", "85", tempFileSrc.fullName, "-o", tempFileDst.fullName]); 
				if(res.status==0) {
					LOG("\n"~res.output); 
					bmp = deserialize!Bitmap(tempFileDst); 
				}
				else { raise("Webp conversion failed:"~ res.output); }
			} 
			
			void doTurboJpeg()
			{
				switch(info.chn)
				{
					case 1, 3: {
						//PERF("tjd"); foreach(i; 0..10) actBitmap = data.deserialize!Bitmap(true); print(PERF.report);
						//turbojpeg/classic release/debug performance: 43, 47, 335, 1941
						auto 	pixelFormat 	= info.chn.predSwitch(3, TJPF_RGB, 1, TJPF_GRAY),
							pitch	= tjPixelSize[pixelFormat]*info.width,
							data	= uninitializedArray!(ubyte[])(info.height*pitch); 
						try {
							tjChk(
								tjDecoder, 
								tjDecompress2(
									tjDecoder, stream.ptr, stream.length.to!int, data.ptr, 
									info.width, pitch, info.height, pixelFormat, 0
								),
								"tjDecompress2"
							); 
							bmp.setRaw(data, info.width, info.height, info.chn, "ubyte"); 
						}
						catch(Exception e) {
							WARN("TurboJpeg decode failed: "~e.simpleMsg); 
							try {
								//doImageFormats;
								doWebpConversion; 
							}catch(Exception e) { throw e; }
						}
						
					}break; 
					//Todo: Tobb jpeg-bol osszekombinalni a 2-4 channelt.
					default: raise("jpg 2-4chn not impl"); 
				}
			} 
			
			void doGif()
			{ raise("GIF decoder NOTIMPL"); } 
			
			if(info.format=="webp") doWebp; 
			else if(info.format=="jpg") doTurboJpeg; 
			else if(info.format=="gif") doGif; 
			else doImageFormats; 
			
			return bmp; 
		}
		catch(Exception e) { if(mustSucceed) throw e; }
		
		return null; 
	} 
	
	Image2D!T deserializeImage(T)(in void[] stream)
	{
		auto bmp = stream.deserialize!Bitmap(true); 
		return bmp.accessOrGet!T; 
	} 
	
	
	
	//Bitmap convert and serializer tests //////////////////////////////
	
	auto makeRgbaTestBitmap(in ivec2 tileSize)
	{
		return new Bitmap(
			image2D(
				tileSize, (ivec2 p) => interpolate_bilinear(
					RGBA(clRed, 255), RGBA(clGreen, 255),
					RGBA(clBlue,255), RGBA(clWhite,   0), vec2(p)/tileSize
				) 
			)
		); 
	} 
	
	auto makeAlphaTestBackgroundImage(in ivec2 size, int mask=4)
	{
		mask = nextPow2(mask-1); 
		return image2D(size, (ivec2 p) { auto b = (p.x^p.y)&mask ? 50 : 200; return RGBA(b,b,b,255); }); 
	} 
	
	auto makeConversionTestImage(int size=32)
	{
		const tileSize = ivec2(64, 64); 
		
		auto bmp = makeRgbaTestBitmap(tileSize); 
		auto img = makeAlphaTestBackgroundImage(tileSize*4, 4); 
		
		alias ComponentTypes = AliasSeq!(ubyte, RG, RGB, RGBA); 
		static foreach(i, SrcType; ComponentTypes)
		{
			{
				auto bmp2 = new Bitmap; 
				bmp2.set(bmp.get!SrcType); 
				static foreach(j, DstType; ComponentTypes)
				{
					{
						auto bounds = ibounds2(i, j, i+1, j+1)*tileSize; 
						auto dst = img[bounds]; 
						auto src = bmp2.get!DstType; 
						
						//foreach(x, y, ref a; dst){  auto b = src[x, y].convertPixel!RGBA;  a = RGBA(mix(a.rgb, b.rgb, a.a*(1/255.0f)), 255);  }
						
						image2D!"a = RGBA(mix(a.rgb, b.rgb, b.a*(1/255.0f)), 255);"(dst, src.convertImage!RGBA); 
						
					}
				}
			}
		}
		
		return img; 
	} 
	
	void testImageBilinearAndSerialize()
	{
		//Todo: make a unittest out of these
		//makeConversionTestImage(32).serialize("webp quality=20").saveTo(File(`c:\dl\imageConvTest.webp`));
		
		/*
			auto img2 = image2D(img.size, (ivec2 p) => img.interpolate_bilinear_safe(p * 0.3f - 5));
			img2.serialize("png").saveTo(File(`c:\dl\bilinear.png`));
			
			img.serialize("png").saveTo(File(`c:\dl\test.png`));
			
			//try to save them all
			foreach(ext; serializeImage_supportedFormats) static foreach(Type; AliasSeq!(ubyte, RG, RGB, RGBA)){{
				auto data = bmp.get!Type.serialize(ext);
			
				print(typeof(data).stringof, data.length);
			
				data.saveTo(File(`c:\dl\a`~(Type.sizeof*8).text~`.`~ext));
			}}
		*/
		
		//some bitmap tests
		/*
			auto name = "brg";
			enforce(name in colorMaps);
			auto width = 128;
			auto raw = colorMaps[name].toArray(width);
			auto img = image2D(width, 1, raw);
			img.serialize("webp").saveTo(File(`c:\dl\brg.webp`));
			
			File(`c:\dl\a32.tga`)
				.deserialize!Bitmap
				.serialize("png")
				.saveTo(`c:\dl\a.png`);
			
			newBitmap(`font:\Times New Roman\64?Hello World`~"\U0001F4A9").serialize("webp").saveTo(`c:\dl\text.webp`); 
		*/
		
	} 
	
	
	import core.sys.windows.windows : 	GetDeviceCaps, GetSystemMetrics, ReleaseDC, BitBlt, HORZRES, VERTRES, 
		SM_CXVIRTUALSCREEN, SM_CYVIRTUALSCREEN, SM_XVIRTUALSCREEN, SM_YVIRTUALSCREEN, SRCCOPY; 
	
	//Screenshot //////////////////////////
	
	auto getPrimaryMonitorSize()
	{
		 //Note: it's just the primary monitor area
		HDC hScreenDC = GetDC(null); //CreateDC("DISPLAY", NULL, NULL, NULL);
		scope(exit) ReleaseDC(null, hScreenDC);  //This is needed and returns 1, so it is working.
		return ivec2(GetDeviceCaps(hScreenDC, HORZRES), GetDeviceCaps(hScreenDC, VERTRES)); 
	} 
	
	auto getPrimaryMonitorBounds()
	{ return ibounds2(ivec2(0), getPrimaryMonitorSize); } 
	
	auto getDesktopSize()
	{ return ivec2(GetSystemMetrics(SM_CXVIRTUALSCREEN), GetSystemMetrics(SM_CYVIRTUALSCREEN)); } 
	
	auto getDesktopBounds()
	{
		auto pos = ivec2(GetSystemMetrics(SM_XVIRTUALSCREEN), GetSystemMetrics(SM_YVIRTUALSCREEN)); 
		return ibounds2(pos, pos+getDesktopSize); 
	} 
	
	auto getDesktopSnapshot(in ibounds2 bnd)
	{
		auto gBmp = new GdiBitmap(bnd.size); scope(exit) gBmp.destroy; 
		auto dc = GetDC(null); scope(exit) ReleaseDC(null, dc); 
		BitBlt(gBmp.hdcMem, 0, 0, bnd.width, bnd.height, dc, bnd.left, bnd.top, SRCCOPY); 
		auto img = gBmp.toImage; 
		img.asArray.rgba_to_bgra_inplace; 
		auto bmp = new Bitmap(img); 
		bmp.modified = now; 
		return bmp; 
	} 
	
	auto getDesktopSnapshot()
	{ return getDesktopSnapshot(getDesktopBounds); } 
	auto getPrimaryMonitorSnapshot()
	{ return getDesktopSnapshot(getPrimaryMonitorBounds); } 
	
	
	private HICON getAssociatedIcon(string fn)
	{
		import core.sys.windows.shellapi, core.sys.windows.winnt; 
		HICON hIcon; 
		
		bool opt(string o) {
			const res = fn.endsWith('?'~o); 
			if(res) fn = fn[0..$-o.length-1]; 
			return res; 
		} 
		
		bool isSmall; 
		if(opt("small")) isSmall = true; 
		if(opt("16"   )) isSmall = true; 
		if(opt("large")) isSmall = false; 
		if(opt("32"   )) isSmall = false; 
		
		if(fn.canFind('?')) {
			raise("Unknown option: `"~fn~"`"); 
			return null; 
		}
		
		if(
			!(
				fn == `folder\`
				|| fn.length==3 && fn.endsWith(`:\`)
				|| fn.length>=2 && fn.startsWith(".")
			)
		)
		raise(format!q"<getAssociatedIcon: icon name must be a `c:\` (c is optional) or `folder\` (folder is "folder") or  `.ext` (ext is optional). Instead of `%s`");>"(fn)); 
		
		/*
			ushort dummy;
			hIcon = ExtractAssociatedIconA(mainWindow.hwnd, fn.toPChar, &dummy);
			//note: this deprecated crap freezes on non-existing files.
		*/
		
		//https://stackoverflow.com/questions/524137/get-icons-for-common-file-types
		SHFILEINFOW fi; 
		uint file_attribute = FILE_ATTRIBUTE_NORMAL; 
		//Todo: specify file attributes too that was accessed in FileEntry -> SHGFI_USEFILEATTRIBUTES
		
		if(fn.endsWith(pathDelimiter))
		file_attribute = FILE_ATTRIBUTE_DIRECTORY; 
		
		//Note: SHGFI_USEFILEATTRIBUTES means: do not access the disk, just the filename
		
		if(
			SHGetFileInfoW(
				fn.toPWChar, file_attribute, &fi, typeof(fi).sizeof.to!uint, 
				SHGFI_ICON | (
					isSmall 	? SHGFI_SMALLICON 
						: SHGFI_LARGEICON
				) | SHGFI_USEFILEATTRIBUTES
			)
		)
		hIcon = fi.hIcon; 
		//must free it with DestroyIcon
		
		//Note: this is not the same icon as in TotalCmd
		//Todo: large 48*48 icon with proper alpha channel.
		//Note: fi.szTypeName -> when SHGFI_TYPENAME used, it returns the typename
		return hIcon; 
	} 
	
	private Bitmap getAssociatedIconBitmap(string fn)
	{
		auto hIcon = getAssociatedIcon(fn); 
		if(!hIcon) return null; 
		
		import core.sys.windows.winuser, core.sys.windows.wingdi; 
		
		scope(exit) DestroyIcon(hIcon); 
		
		ICONINFO ii; 
		if(GetIconInfo(hIcon, &ii))
		{
			scope(exit) {
				if(ii.hbmColor) DeleteObject(ii.hbmColor); 
				if(ii.hbmMask) DeleteObject(ii.hbmMask); 
			}
			if(ii.hbmColor)
			{
				 //Icon has colour plane
				BITMAPINFOHEADER bi; 
				if(GetObject(ii.hbmColor, typeof(bi).sizeof.to!int, &bi))
				{
					//print("hbmColor", bi.biWidth, bi.biHeight);
					auto gBmp = scoped!GdiBitmap(bi.biWidth, bi.biHeight); 
					auto doit(uint flags) {
						DrawIconEx(gBmp.hdcMem, 0, 0, hIcon, bi.biWidth, bi.biHeight, 0, null, DI_MASK | DI_IMAGE); 
						return gBmp.toImage; 
					} 
					
					version(none)
					{
						/+Note: This version only works at me.  On karc machine the DI_MASK produces only RGBA(0, 0, 0, 0) everywhere.+/
						auto imMask = doit(DI_MASK); 
						auto imColor = doit(DI_IMAGE); 
						//swap blue-red, gray if transparent.
						auto imAlpha = image2D!((i, m) => m.g ? RGBA(127, 127, 127, 0) : RGBA(i.b, i.g, i.r, 255))(imColor, imMask); 
					}
					
					version(all)
					{
						//Note: DI_MASK is broken on some computers. To avoid handling bitplaned masks, I just hack the shit out of it.
						gBmp.fill(clBlack); 	auto imMask0 = doit(DI_IMAGE | DI_MASK); 
						gBmp.fill(clWhite); 	auto imMask1 = doit(DI_MASK | DI_IMAGE); 
						gBmp.fill(het.RGB(0x7f7f7f)); 	auto imPlain = doit(DI_MASK | DI_IMAGE); 
						//Partial RGB information is lost... Could be recovered but I aint got no time for this shieeet...
						
						auto imAlpha = image2D!((i, m0, m1) => RGBA(i.b, i.g, i.r, (m1.g-m0.g)^0xFF))(imPlain, imMask0, imMask1); 
					}
					
					//swap blue-red!!!
					
					auto bmp = new Bitmap(imAlpha); 
					assert(!fn.startsWith(`icon:\`)); 
					bmp.file = File(`icon:\`~fn); 
					bmp.modified = now; 
					return bmp; 
				}
			}
		}
		
		return null; 
	} 
	class GdiBitmap
	{
		//holds a windows gdi bitmap and makes it accessible as a normal RGBA Image or Bitmap object
		ivec2 size; 
		HBITMAP hBitmap; 
		static HDC hdcMem, hdcScreen; //needs only one of these
		BITMAPINFO bmi; 
		
		this(in ivec2 size)
		{
			
			this.size = size; 
			
			if(!hdcScreen) hdcScreen = GetDC(null); 
			if(!hdcMem) hdcMem  = CreateCompatibleDC(hdcScreen); 
			
			hBitmap = CreateCompatibleBitmap(hdcScreen, size.x, size.y); 
			                             //^^^^^^^^^ must be hdcScreen, otherwise 1bit monochrome
			
			SelectObject(hdcMem, hBitmap); 
			
			with(bmi.bmiHeader) {
				biSize	= BITMAPINFOHEADER.sizeof; 
				biWidth	= size.x; 
				biHeight	= -size.y; 
				biPlanes	= 1; 
				biBitCount	= 32; 
				biCompression	= BI_RGB; 
				biSizeImage	= size.x*size.y*4; 
			}
		} 
		
		this(int width, int height)
		{ this(ivec2(width, height)); } 
		
		~this()
		{
			DeleteObject(hBitmap); 
			//hdcScreen and hdcMem are static
		} 
		
		auto toImage()
		{
			auto img = image2D(size, RGBA(0)); 
			if(!img.empty)
			{
				if(!GetDIBits(hdcMem, hBitmap, 0, size.y, img.asArray.ptr, &bmi, DIB_RGB_COLORS))
				raiseLastError; 
			}
			
			return img; 
		} 
		
		Bitmap toBitmap()
		{ return new Bitmap(toImage); } 
		
		void fill(RGB color)
		{ SetDIBits(hdcMem, hBitmap, 0, size.y, [RGBA(color, 0xFF)].replicate(size.area).ptr, &bmi, DIB_RGB_COLORS); } 
		
	} 
	
	
	//FontDeclaration ///////////////////////////////
	
	struct BitmapFontProps
	{
		string fontName = "Tahoma"; 
		int height = 32; 
		int xScale = 1; 
		bool clearType = false; 
	} 
	
	auto decodeFontDeclaration(string s, out string text)
	{
		BitmapFontProps res; 
		
		enforce(s.isFontDeclaration, `Not a font declaration. "%s" `.format(s)); 
		//example: `font:\Times New Roman\64\x3\ct?text`
		//^ fontName
		//optional size,	x3: width*=3, x2, ct=clearType
		//last part is the text to write after the '?'
		
		s.split2("?", s, text, false/*no strip*/); 
		
		auto p = s.split('\\').array; 
		enforce(p.length>=2, `Invalid format. "%s"`.format(s)); 
		
		res.fontName = p[1]; 
		foreach(a; p[2..$])
		{
			int i; bool ok; 
			try { i = a.to!int; ok = true; }catch(Throwable) {}
			if(ok) {
				enforce(i.inRange(0, 0x10000), `Height out of range %d in "%s"`.format(i, s)); 
				res.height = i; 
			}
			else if(a=="ct") { res.clearType = true; }
			else if(a=="x3") { res.xScale = 3; }
			else if(a=="x2") { res.xScale = 2; }
			else if(a=="") {
				//empty is ok. Easier to make conditional declarations that way
			}
			else { enforce(0, `Invalid param "%s" in "%s"`.format(a, s)); }
		}
		
		return res; 
	} 
	
	
	void toBGRA(
		Bitmap bmp, 
		RGBA[] delegate(int) onAlloc = (int area) => uninitializedArray!(RGBA[])(area)
	)
	{
		if(!bmp || !bmp.valid || bmp.channels==4) return; 
		
		//48 -> 64 byte
		
		switch(bmp.channels)
		{
			case 1: {
				auto img = bmp.access!ubyte; 
				auto src = cast(byte16[])(img.asArray);  //Opt: handle un-strided images too
				auto dst = cast(byte16[])(onAlloc(img.area)); 
				LtoBGRA(src.ptr, dst.ptr, src.length); //Bug: unaligned ofs and size!!!
				bmp.set(Image2D!RGBA(img.size, cast(RGBA[])dst)); 
				break; 
			}
			case 3: {
				auto img = bmp.access!RGB; 
				auto src = cast(byte16[])(img.asArray);  //Opt: handle un-strided images too
				auto dst = cast(byte16[])(onAlloc(img.area)); 
				RGBtoBGRA(src.ptr, dst.ptr, src.length); //Bug: unaligned ofs and size!!!
				bmp.set(Image2D!RGBA(img.size, cast(RGBA[])dst)); 
				break; 
			}
			default: NOTIMPL; 
		}
	} 
	
	
	private enum INSPECT_format = /+"webp quality=101"+/ "bmp"; 
	
	
	private enum INSPECT_ext = '.' ~ INSPECT_format.splitter(' ').take(1).front; 
	
	string INSPECT(T)(string name, lazy Image!(T, 2) a)
	{
		const f = File(appPath, name~INSPECT_ext); 
		a.serialize(INSPECT_format).saveTo(f); 
		return "$DIDE_CODE /+$DIDE_IMG "~f.fullName.quoted~" maxHeight=96+/"; 
	} 
	
	string INSPECT(string name, lazy Bitmap a)
	{
		const f = File(appPath, name~INSPECT_ext); 
		a.serialize(INSPECT_format).saveTo(f); 
		return "$DIDE_CODE /+$DIDE_IMG "~f.fullName.quoted~" maxHeight=96+/"; 
	} 
	
	Image2D!RGB splitChn(T)(Image!(T, 2) src)
	{
		static if(is(T==RGB))	enum chns = ["rgb", "r00", "_0g0", "_00b"]; 
		else static if(is(T==RGBA))	enum chns = ["rgb", "r00", "_0g0", "_00b", "aaa"]; 
		
		auto dst = image2D(src.width*(cast(int)(chns.length)), src.height, clBlack); 
		static foreach(i, chn; chns)
		dst[src.width * (cast(int)(i)), 0] = src.image2D!("a."~chn); 
		return dst; 
	} 
	
	Image2D!RGB splitChn(T)(Bitmap a)
	{
		auto src = a.get!T; 
		return src.splitChn!T; 
	} 
	
	
	version(/+$DIDE_REGION Color maps+/all)
	{
		string _import_matplotlib_cmaps()
		{
			/+
				Note: /+Bold: Step 1:+/ 	Go to /+Link: https://matplotlib.org/stable/gallery/color/colormap_reference.html+/
					Copy the cmaps listing declarations and update quantized colorbar counts.
				/+Bold: Step 2:+/ 	Download all the 7 colormap images into DownloadPath.
				/+Bold: Step 3:+/ 	Fill out Settings, verify pixel locations, execute this function.
				/+Bold: Step 4:+/ 	Copy and Paste the generated code right after this function.
			+/
			enum cmaps_decl = 
			`[('Perceptually Uniform Sequential', [
	   'viridis', 'plasma', 'inferno', 'magma', 'cividis']),
	('Sequential', [
	   'Greys', 'Purples', 'Blues', 'Greens', 'Oranges', 'Reds',
	   'YlOrBr', 'YlOrRd', 'OrRd', 'PuRd', 'RdPu', 'BuPu',
	   'GnBu', 'PuBu', 'YlGnBu', 'PuBuGn', 'BuGn', 'YlGn']),
	('Sequential (2)', [
	   'binary', 'gist_yarg', 'gist_gray', 'gray', 'bone', 'pink',
	   'spring', 'summer', 'autumn', 'winter', 'cool', 'Wistia',
	   'hot', 'afmhot', 'gist_heat', 'copper']),
	('Diverging', [
	   'PiYG', 'PRGn', 'BrBG', 'PuOr', 'RdGy', 'RdBu',
	   'RdYlBu', 'RdYlGn', 'Spectral', 'coolwarm', 'bwr', 'seismic',
	   'berlin', 'managua', 'vanimo']),
	('Cyclic', ['twilight', 'twilight_shifted', 'hsv']),
	('Qualitative', [
	   'Pastel1', 'Pastel2', 'Paired', 'Accent',
	   'Dark2', 'Set1', 'Set2', 'Set3',
	   'tab10', 'tab20', 'tab20b', 'tab20c']),
	('Miscellaneous', [
	   'flag', 'prism', 'ocean', 'gist_earth', 'terrain', 'gist_stern',
	   'gnuplot', 'gnuplot2', 'CMRmap', 'cubehelix', 'brg',
	   'gist_rainbow', 'rainbow', 'jet', 'turbo', 'nipy_spectral',
	   'gist_ncar'])]`; 
			
			struct Settings
			{
				static {
					Path DownloadPath = `c:\dl`; 
					string DownloadFileMask = `sphx_glr_colormap_reference_00?.webp`; 
					
					int 	x0 = 128, y0 = 34, 	//colorbar topleft on downloadedimage
						x1 = 634, 	//colorbar ends here at the right. (exclusive)
						yh = 20, ys = 24 	/+colorbar height and stride+/; 
					int GradientSadSeparator = 6; 	//Max SAD difference between adjacent pixels.
					int GradientMinLength = 20; 	//Minimum color gradient group width in pixels.
					int GradientMaxAdjacentSadReq = 50; 	//Minimum requirement form the max adj. sad.
					int GradientMaxCount = 40; 	//Max color gradient groups
					
					float MaxMSE = 2.0f; 	/+
						Controls reducement quality. (non quantitative only)
						The lower, the nicer. The higher, the smaller.
					+/
				} 
			} 
			
			static struct CmapCategory { string name; string[] items; } 
			mixin(
				"static immutable CmapCategory[] cmapCategories="~
				cmaps_decl.replace('\'', '"').replace("(", "CmapCategory(")~";"
			); 
			mixin("enum cmap{"~cmapCategories.map!((c)=>(c.items.join(", "))).join(", ")~"}"); 
			print(cmapCategories); 
			
			Image2D!RGB[] originalBars; 
			with(Settings)
			{
				foreach(file; listFiles(DownloadPath, DownloadFileMask).map!"a.file")
				{
					auto img = bitmaps[file].get!RGB; 
					for(int j = 0; y0 + ys*j + yh < img.height; j++)
					{ originalBars ~= img[x0..x1, y0 + ys*j + yh/2]; }
				}
			}
			
			i"Loaded $(originalBars.length) cmap bitmaps. Expecting $(cmap.max+1).".print; 
			enforce(originalBars.length==cmap.max+1, "cmap count mismatch"); 
			with(Settings)
			{
				
				string[] cmapAsHex; int[] cmapNumGradients; 
				foreach(cmapIdx; 0..originalBars.length.to!int)
				{
					auto imSrc = originalBars[cmapIdx]; 
					
					Image2D!RGB imDst; 
					write(i"Importing: $(cmapIdx.format!"%2d") $(cmapIdx.to!cmap.format!"%-18s"): "); 
					
					version(/+$DIDE_REGION Detect Quantitative color count+/all)
					{
						const maxAdjacentSad = imSrc 	.asArray.slide!(No.withPartial)(2)
							.map!((a)=>(sad(a[0],a[1]))).maxElement; 
						/+
							const groupCnt = imSrc.asArray	.group!((a,b)=>(sad(a,b)<=GradientMaxSad))
								.filter!((a)=>(a[1]>=GradientMinLength))
								.walkLength.to!int; 
						+/
						const groupCnt = imSrc.asArray	.splitWhen!((a,b)=>(sad(a,b)>GradientSadSeparator))
							.filter!((a)=>(a.walkLength>=GradientMinLength))
							.walkLength.to!int; 
						write(
							i"MAS:$(maxAdjacentSad
	.format!"%3d") GrC:$(groupCnt
	.format!"%3d") "
						); 
						const numGradients = ((
							maxAdjacentSad>=GradientMaxAdjacentSadReq &&
							groupCnt.inRange(2, GradientMaxCount)
						)?(groupCnt):(0)); 
						cmapNumGradients ~= numGradients; 
					}
					if(const N = numGradients)
					{
						imDst = image2D(N, 1, iota(N).map!((i)=>(imSrc[(ifloor(((i+0.5f)/(N*imSrc.width)))), 0])).array); 
						write("gradients: ", imDst.width, "  "); 
					}
					else
					{
						foreach(N; 1..imSrc.width+1)
						{
							auto imNew = image2D(N, 1, imSrc.asArray.stretch_linear(N)); 
							auto imReconstructed = image2D(
								imSrc.width, 1, 
								imNew.asArray.stretch_linear(imSrc.width)
							); 
							auto mse = MSE(imSrc.asArray, imReconstructed.asArray); 
							if(mse <= MaxMSE)
							{
								imDst = imNew; 
								write(
									i"reduced width: $(imDst.width
	.format!"%-3d")  MSE: $(mse)"
								); 
								break; 
							}
						}
					}
					
					const success = !imDst.empty; 
					cmapAsHex ~= success ? imDst.serializeImage("webp quality=101")
						.map!q{a.format!"%02X"}.join : ""; 
					writeln(((success)?(""):("\34\4FAIL\34\0"))); 
				}
				
				enforce(
					cmapAsHex.length==originalBars.length && cmapAsHex.all!q{a!=""}, 
					"Failed to import all cmap bars."
				); 
				enforce(
					cmapAsHex.length==cmapNumGradients.length, 
					"Failed to import cmap quantitative info."
				); 
				
				enum wr = 80; 
				return iq{
					enum cmap {
						$(
							cmapCategories.map!
							((cat)=>(
								"//"~cat.name~"\n"~
								cat.items.map!q{a~", "}.join.wrap(wr)
							))
							.join.strip.withoutEnding(',')
						)
					} 
					static immutable int[] cmapNumGradients = 
					$(cmapNumGradients.text.wrap(wr).strip); 
					static immutable string[] cmapCategoryNames =
					[
						$(
							cmapCategories.map!((n)=>(n.name.quoted.replace(' ', '\1')))
							.join(", ").wrap(wr).strip.replace('\1', ' ')
						)
					]; 
					static immutable cmap[2][] cmapCategoryRanges =
					[
						$(
							cmapCategories.map!((n)=>(
								"[cmap."~n.items.front~",\1"~
								"cmap."~n.items.back~"]"
							))
							.join(", ").wrap(wr).strip.replace('\1', ' ')
						)
					]; 
					static immutable ubyte[][] cmapRawData = 
					[$(cmapAsHex.map!((data)=>(`x"`~data.chunks(wr).join('\n')~`"`)).join(",\n"))]; 
				}.text
				.splitLines.map!strip.join("\n"); 
			}
		} 
		
		enum cmap {
			//Perceptually Uniform Sequential
			viridis, plasma, inferno, magma, cividis,
			//Sequential
			Greys, Purples, Blues, Greens, Oranges, Reds, YlOrBr, YlOrRd, OrRd, PuRd, RdPu,
			BuPu, GnBu, PuBu, YlGnBu, PuBuGn, BuGn, YlGn,
			//Sequential CmapCategory(2)
			binary, gist_yarg, gist_gray, gray, bone, pink, spring, summer, autumn, winter,
			cool, Wistia, hot, afmhot, gist_heat, copper,
			//Diverging
			PiYG, PRGn, BrBG, PuOr, RdGy, RdBu, RdYlBu, RdYlGn, Spectral, coolwarm, bwr,
			seismic, berlin, managua, vanimo,
			//Cyclic
			twilight, twilight_shifted, hsv,
			//Qualitative
			Pastel1, Pastel2, Paired, Accent, Dark2, Set1, Set2, Set3, tab10, tab20, tab20b,
			tab20c,
			//Miscellaneous
			flag, prism, ocean, gist_earth, terrain, gist_stern, gnuplot, gnuplot2, CMRmap,
			cubehelix, brg, gist_rainbow, rainbow, jet, turbo, nipy_spectral, gist_ncar
		} 
		static immutable int[] cmapNumGradients =
		[
			0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
				0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
				0, 0, 0, 0, 9, 8, 12, 8, 8, 9, 8, 12, 10, 20, 20, 20, 0, 0, 0, 0, 0, 0, 0, 0, 0,
				0, 0, 0, 0, 0, 0, 0, 0
		]; 
		static immutable string[] cmapCategoryNames =
		[
			"Perceptually Uniform Sequential", "Sequential", "Sequential CmapCategory(2)",
			"Diverging", "Cyclic", "Qualitative", "Miscellaneous"
		]; 
		static immutable cmap[2][] cmapCategoryRanges =
		[
			[cmap.viridis, cmap.cividis], [cmap.Greys, cmap.YlGn],
			[cmap.binary, cmap.copper], [cmap.PiYG, cmap.vanimo], [cmap.twilight, cmap.hsv],
			[cmap.Pastel1, cmap.tab20c], [cmap.flag, cmap.gist_ncar]
		]; 
		static immutable ubyte[][] cmapRawData =
		[
			x"524946466A000000574542505650384C5D0000002F0D0000006FA0A08D24C5BFD0637A06278ADBB6
	71D293BBFDC7AADF1BE086A880D2004013249168C4F9FF672DAEBACC7FD02F7F9B5E89D670FA34B9
	546E11CA3290C7E7F990E8881B781508324C7696586289259658F28BE87F7C8D0500",
			x"5249464660000000574542505650384C540000002F090000004FA0A8912465C9BF373AC6F7293829
	6A22C96D10883F240188A52A55D136008F920040908466A7F1FF180BC8F31F7FB70248DFF4D74E96
	13E37A7BA6989EE00199B46D906AA9966A999645F43FBE04",
			x"5249464672000000574542505650384C660000002F0E00000077C020008024747783ADFF377A436D
	2349CD471E4FE4A1FF0AC9501BC956F23FD202B946E4B440FF65B8643E33FF018016DEC2DDF9AFA0
	17A7D6A7D662D7945AD56B7686E8C1E9FBD2F7BCA5010824201EC8165B6CB1C5165B0C8BE87F504E
	7700",
			x"5249464660000000574542505650384C530000002F0B0000005FA0A6912434F6D851F91650410020
	093980070DFF0FAAD2485218420D0C05E0A2A4FF8E5038C4FC0700376B12434F6533DBE773CA57DB
	7B15FBCD3E0782001285586299659659268DE87F60BA0300",
			x"5249464660000000574542505650384C540000002F0C00000067A0A06D1B863FD29EFDA151D0B60D
	53FE008BE16D633049512349CAF2E18FAC9C7F21278433FF811F63BA52D1C93ACE56ECA0DDE5EEFA
	7E2772648F0904012431CC32CB2CB3CC326844FFE36B2C00",
			x"524946464C000000574542505650384C400000002F070000003FA024001A364A07241AF6D4940440
	C346E98044C39E9A920068D8281D9068D8539BFF007077FDBF24EE8E6D92900481081A6B96596639
	A2FF7102",
			x"524946464A000000574542505650384C3E0000002F050000002F40266D9BAC8D6AD83B01638ADAB6
	81B33CFAACFA3CB62198A2B68D1806FDF6F6E279DCE73FF83FA6EBF4424C0220904D433B4B2C45F4
	3F0E",
			x"524946464E000000574542505650384C420000002F070000003FA0A46D0438E6E1D0D1979F9A0040
	D3240E25ECE59D286923098EF2DDBD9F9D8E7375F31F8F3F3EEB951DFA89276000091088A0B16699
	659623FA1F27",
			x"5249464650000000574542505650384C440000002F070000003FA0B4911438AE4F3D80C381A50C14
	3592A406972CAC04867B9FA2B68DD8148ADE7EEE9BFF78B027B0116642FF54EFD11AD4402082C69A
	6596598EE87F9C00",
			x"5249464658000000574542505650384C4B0000002F0800000047A0A89124C5BFC6A53FD39D17C36C
	24ADBFDB0A2CC101DCBF6ADA466274CF9FD88F9DC08F95C2FCC7D747518EC384804F722F4B7600B2
	6CE4E07AE3B11CCBB37C44FFC3760000",
			x"5249464652000000574542505650384C450000002F0800000047A02400103449D6C6018706A10666
	76E72D8669210FA58DA4C0697B777C1D80C511E63FE05E0758F094F758D6714ACF6820C8B6CD8D61
	2C6339CB23FA1F5F0200",
			x"5249464656000000574542505650384C4A0000002F0800000047A0240010E4FF4048DE349168DC20
	0820C9DFED19265821458D2429D9F5AF695DF01F8ECFC2FCC79B4F3530878001BFD0BE08DA029065
	2307D71B8FE5589EE523FA1FB603",
			x"5249464658000000574542505650384C4B0000002F0800000047A0109215EAF9533D80049A00FEA5
	9006410049FE5C532CB0C5296ADB06529FE54FABCFA92C761398FF78F50C83A9660C3EC99E971000
	59367270BDF1588EE5593EA2FF613B00",
			x"5249464654000000574542505650384C470000002F0800000047A0A8912435B70E18251CBFCE301B
	4929C0FE1760118EEFD8D5B48DC4E60EC38F75EAFFF31FF008076FEE778D90EB35660E0A20C8B6CD
	8D612C6339CB23FA1F5F0200",
			x"524946465C000000574542505650384C4F0000002F0800000047A02600D084FEB548C067099C4919
	250180209107FCDF43E205C9B5AA692405F2EFED0CDC0102DE1ACAF98FFF7FE2B036DB459810C805
	9616700059367270BDF1588EE5593EA2FF613B00",
			x"5249464654000000574542505650384C470000002F0800000047A0A86D2336D7A2B8F53F005B211B
	49707277EF284EE29738358D24A1B1F6A96432F8F31FF88F123C509936D8BB4AB1E011391064DBE6
	C63096B19CE511FD8F2F0100",
			x"5249464658000000574542505650384C4C0000002F0800000047A02892D4388B03F85118B8AF444D
	1B496EF2F2F5B93E0C8FE3D5349202A7EB7BA0BAD0E3001FCC7FC0FFF8CEF795128D4323F84CAED1
	0208B26D736318CB58CEF288FEC79700",
			x"5249464656000000574542505650384C4A0000002F0800000047A02600D0A47F44E4E6759806511A
	0009C3FFE74105FBEA56858C24310677FE620751BE20CC7FFCFFAB639F859F8A840009AE05109065
	2307D71B8FE5589EE523FA1FB603",
			x"5249464652000000574542505650384C460000002F0800000047A0A88D14386A61971B5EE002320D
	C8F4A8E095C0650A50D4460A1C7DEF0578C0026298FF78FEC309AEED980F9B59246C108020DB3637
	86B18CE52C8FE87F7C09",
			x"524946465E000000574542505650384C510000002F0800000047A0349214A6FFE2DE92749648146D
	988D24E3FFD17F3B626518A1580BD404009AE0D23F131DA0C12CC28EF98FFF79D7B689A79B4A361F
	62213DB30564D9C8C1F5C663399667F988FE87ED0000",
			x"5249464652000000574542505650384C450000002F0800000047A0A86D233608A1BD3DFE47E58804
	20B36C502D10194051DB466CEEDFDEC2700CF6FCC7F31F52B0606F1BFCC24362081108B26D736318
	CB58CEF288FEC7970000",
			x"5249464656000000574542505650384C4A0000002F0800000047A0349224352AAFCE8364FA405E51
	DB486E7031ECAFF73B026BC46D5441EAFCE5DC1D20D184F98F0FF501695BF9E37FE416DD40124000
	41B66D6E0C6319CB591ED1FFF812",
			x"5249464656000000574542505650384C490000002F0800000047A0349224357AE44EC2B3E2485E49
	23496CF2E889B86FF86953D348129A33F0F98EA1C7F98F8F3E814681676E7CC943AC898A091F08B2
	6D736318CB58CEF288FEC7970000",
			x"524946461E000000574542505650384C120000002F010000000F30FFF33FFFF31F78C888FE07",
			x"524946461E000000574542505650384C120000002F010000000F30FFF33FFFF31F78C888FE07",
			x"5249464620000000574542505650384C130000002F010000000F30FFF33FFFF31F78A84044FF0300",
			x"5249464620000000574542505650384C130000002F010000000F30FFF33FFFF31F78A84044FF0300",
			x"5249464640000000574542505650384C330000002F040000002740986D1C9BD50670CF23C8B64DCD
	6A3BC9850464CA2C5937FF01D4AD7CEA8242B611E0D4EE0138968BE87FEC0500",
			x"5249464658000000574542505650384C4C0000002F130000009988E87F6C0A12D1FF80823692D4D8
	313C938F57D448921A3CEA7B32A38653DC369292EF42FFA5F241043CFEE71D66A7276AA238AAFF97
	D836273D6C0FBA3395354C3131AE8822",
			x"5249464620000000574542505650384C130000002F010000000F30FFF3BFFFF31F1EA84044FF0300",
			x"5249464620000000574542505650384C130000002F010000000F70C0FFFD1FB3F98F076444FF0300",
			x"524946461E000000574542505650384C120000002F010000000F30FFF31FF31F0E2A10D1FF00",
			x"5249464620000000574542505650384C130000002F010000000F30FF71C0FFF90F071588E87F0000",
			x"5249464620000000574542505650384C130000002F010000000FB0FFF33FFFF31F2DA84044FF0300",
			x"5249464640000000574542505650384C330000002F0400000027A0A66D03067B40F65E57211148DA
	B0FE491762BF4080D0E1D4B08EF98FCF623B1C302010A04C158E88E87FEC0500",
			x"5249464646000000574542505650384C3A0000002F080000004760A66DDB98AFF26B37456DDBC021
	BF07EE9E81B46DB2FDB67FEDF31F428727C9E3518BC70159367270BDF1588EE5593EA2FF613B",
			x"5249464634000000574542505650384C280000002F0400000027201048568F7C0D0141D175CB0904
	08E9949BFF087F8B2540209B867696448AE87F1C",
			x"524946463E000000574542505650384C310000002F080000004720104861664F906D9B1AC24DB60B
	088A2C777DFE0312419CE325360359367270BDF1588EE5593EA2FF613B00",
			x"5249464638000000574542505650384C2B0000002F050000002F201048E136A7206D0336B4E36B9D
	4020856BF4FC47EA03F8800281401A5288659623FA1F1A00",
			x"5249464666000000574542505650384C5A0000002F0A00000057A02892A446C4B9C9BECF05D94186
	2F5A940600D22422FF7FC2111B8C5EB1B52A698008EA1F802A3421009EE1EE91F31FFFEF05AFDEB0
	335E23C4D7597C540B0BFD0001C8A46DA3F4AC95D99887595A44FF63A117",
			x"524946466A000000574542505650384C5D0000002F0A00000057A02400D0A60839484A0DEC6FF02C
	6E3596454900A04D0EFA37C19201F541B1AB9544B24205789AFE797038088043FD1D33F31FFFDF37
	0976907E28820E249B23C6400AD59A0399B40D7DEB6706666696263DA2FFB1D00B00",
			x"5249464668000000574542505650384C5C0000002F0A00000057A0A06D1B462A9322187F169FC118
	ACE3A22892D4A8D0741A813F3611717AC93F6A1A4981AA338084F3EF000F3F94B840C0FC87DE3F30
	38DA3C0A352EBCC2FCF2B6A860482093B6A157FD4CC67CCCD3A447F43F5E3201",
			x"524946466A000000574542505650384C5D0000002F0A00000057A0169224285B956538819FF5802E
	5E876351144952736A72040C61180FB8E089D94832663EFD361E0D08B5AC1295C88D78FEE3DFD73D
	C071BF652F7219135B6121E9806F82624692E0E05C5403321E8BB111FD8FAF6E0100",
			x"524946466C000000574542505650384C600000002F0A00000057A02400D046D1E113E325A0BFC623
	1761399444B242E9D7E1C957820ABF2878BA22E9C1288A24A9B9F43D011990C11FFF06B04251F31F
	FF7F65BA12E86AB4BC416D9BF71338E0CCEE0532691BFA55CFC44CC94CCD7144FF23F305",
			x"5249464668000000574542505650384C5B0000002F0A00000057602400921B9C201119C06EABCD23
	46B6A8892449D17210A28E7B728F42FE5335916C350A7E9903A1C405C2F18193D4CD7FF49D7FBFCA
	B67F191B084C23784E4810EE2E10C8A46DB3D0B38E266042A66611FD8F875500",
			x"5249464668000000574542505650384C5B0000002F0A00000057A0260090260A27EF06F7E81FC4DF
	346ADA3682D4B1003A96C27DFC211C87C3719BA2465298A0A33A2018C0BF0384F4EFFCC7BFFFB6E0
	071A308C2E95C0005C4EDA522508C8024CDE9D6389259660228FE87FA4F30000",
			x"5249464664000000574542505650384C570000002F0A00000057A02692144602FE25D145030CE557
	D44987A2365220056B616D630703F0BCBD809A002018FD3B89A083067B5DCC7FFCE17C420B60AC74
	B53C5044BB41E150E20764D236F4AB9E999981A99AF288FEC74B2600",
			x"5249464668000000574542505650384C5C0000002F0A00000057A02400D0A61629A9F4F5F3481C7E
	7239D40400C1141040FF1A1AB8157089B0879A064C98F4AE83CA432836D68904C24B32FFF1CF3F6B
	872B3E908F56723E036609301F88804CDA06FAD5CFB4CCC75C4D7244FFA36117",
			x"5249464668000000574542505650384C5C0000002F0C00000067A0249215AAFB8B450FD41FDC9348
	9A288924C981E75FCCC9C9F99F3EFF521A499272FEF4E51F19C3A37EF762FEC389FF924BC4001B4F
	E5E593801F41ED57F68CDE22BE802CC04460572CB1C4114E2C9146F43F627507",
			x"5249464624000000574542505650384C180000002F020000001730FEF32F2049F0FFE79AFFE07250
	8C88FE07",
			x"524946463A000000574542505650384C2D0000002F040000002740906DB3EDFEC8F710901072DC73
	09488832D05AFB34FF01679C4D51402040992A2C10D1FFE80700",
			x"5249464670000000574542505650384C630000002F0C00000067C026008034B817B01FC292D075CB
	A4260090A6065C04D8508016F44F807AF92A8D64ABF9414534430B991AE90F472DD8F90F0312E127
	890529223789B77F4279D7FC4FDEE37462BDE295814CC0E2DE278B2C5228A294A011FD8F77720000",
			x"5249464664000000574542505650384C580000002F0A00000057A0269224C5C459B8BA08FD8B8087
	1055BC15B301506C6D85FF1FB3C90F766A224952249C028C51D6D9BFA7EC83F98FF89E3BA69735CF
	EBEF1BC01944212A2EE285401660F2EF1A4B2CB1C4127A44FFC37407",
			x"5249464672000000574542505650384C650000002F0D0000006FA02892D4480AF78FC20926AEA88D
	96088812C5912425AF93100497C80898BFC682A248929AE7453248B8C212B6939CA36AFEE37E9F36
	7C00C04E84882A7385D7A9D6F7E6E363916E2299F33610049038A434CB4E3B2CB1C56A11FD8F35C8
	0700",
			x"524946467C000000574542505650384C700000002F1200000050535B4BD6013646665A809AC46392
	FF16EE2630829323D194C4B61545FA1D561AE018E41A810E4440D3010F8E00B8DF444D00204D2C5E
	0A807EA43086118C6004CFBD13F86B92FE87DBFFF7DE79766F35C51C8306CFDE020A0280436A2443
	A7A5CB9675CC79EEFDE1F600",
			x"524946467C000000574542505650384C700000002F1200000050535B4BD601981819A9C1210A51FE
	6AB81AC1048E8E4653535B4B16890E7F15D8388C1C3250810C8E763080C7C9008E3651134952E4EA
	2E3C036F0422D081013C2081F08F50800094F43F1010308A66B31ADE32FAAA73C67DE7FDFFEF3BFB
	96D92956F069DACEC9204400",
			x"5249464666000000574542505650384C590000002F200000009988E87F6C22A2FF61500849923310
	A7F1C19FE21E2053FD288D24296A77F212399EFCA3008D260D50144952D36F0A29D1BF8A0C6AA88A
	E02B741AFEB8D85894137809150DD52926039397189894FAC443C7101300",
			x"524946461E000000574542505650384C110000002F080000000750DAEAD7B5FF8188E87F0000",
			x"524946461E000000574542505650384C110000002F070000000750F1CEB6B9FF8188E87F0000",
			x"524946461E000000574542505650384C110000002F0B0000000750E79A76BCFF8188E87F0000",
			x"524946461E000000574542505650384C110000002F0700000007D0E4FEF5AFFF8188E87F0000",
			x"524946461E000000574542505650384C110000002F070000000750CF6EF4AEFF8188E87F0000",
			x"524946461E000000574542505650384C110000002F0800000007508D9297A3FF8188E87F0000",
			x"524946461E000000574542505650384C110000002F070000000750E19A95B4FF8188E87F0000",
			x"524946461E000000574542505650384C110000002F0B00000007D0E936F6B8FF8188E87F0000",
			x"524946461E000000574542505650384C110000002F0900000007D0BB7A94B6FF8188E87F0000",
			x"524946461E000000574542505650384C110000002F1300000007D0BB7A94B6FF8188E87F0000",
			x"524946461E000000574542505650384C110000002F1300000007D09DE634AFFF8188E87F0000",
			x"524946461E000000574542505650384C110000002F130000000750C1C6B4B7FF8188E87F0000",
			x"5249464654040000574542505650384C470400002FF9010000901D0B0001472F67DB367BB0CD3662
	3B5DD84E0F363AB0BFD73BE3AB43726DDBA66D8DF3F6C3B7EEAF3F1B31D80CC26612B683B01983CD
	B2CD830939B66DD3D67CFCF66FDB8CC16610B693B01984CD186CB66DDE7BDFEA7F10A7E5FD4F19F9
	CA1E56F7A87AF7B41BD07E567FE9270537B4BDA29156F535292F593FE375CAE8106F38C0267AD186
	2CA4C0E637E29089267463057BB0B9EB86FCF0924A55D8A7D6490DEF683DA8B3ACFE12D766F450AB
	B39AED537BB52A73F43E5237BE784E98075C6109E3A8470962E1EBBF43280A508E614CE1947D0FB6
	E776F86B45D5A9A245350B9A5AD57C543769E7257965C4CFB53CAEC5513596A8BE482F82F5E48F79
	D83CE216B39842152A10C184FA6B17826294610C93B8E0D895F3B11BF446D10DAA6851ED92A657B4
	10D76DF2F321F360858FB536A99941B596A9324F6F42F4C4F78F4F9C6311A3A843316298505F1085
	1CD4A20FF338E4C48DFDB25C5F9454A6FC2EB54E697043EB11EF24E93E676D0576B4BBA2D14E0D34
	AA205DBFE374FD9760E210DBE84527B291067F068948410BDAB0864DF6BF704AEEBFCAC853D690BA
	47D4B3ABDD80F633FA49BF2AB0A19D558DB46AA059B9C9FA9DA89301DACF27F6B08D1E7420136970
	F88904A4A3199D58C30E5C6E2AE8B7528A9437A88E710DEE6A2BA093FF3292375664CFB3BEA0A96E
	75D6AA34539FA3753940C7FD1E718E158CA011458887379F4318F2508901CCE0989C679ED9E16F15
	55ADB256D5CE69724D0B115D67DCB7C4A5113FD7F2A49646D554A6FA22BD0AD1A3DFD651F3805BCC
	611AD5A84024BF10FF1C82518C528C6102171CB9763C75425E29AA41954DAA59D2CCB2E6E3BA4BDA
	0FE93B2B72AA9509CD0DABB95435057A15AC67BEFF7DD61BAE308F71D4A01451FCC37C4304F25185
	41CCE28413578E1B9EF7472554AAA8434DB31A59D36AD43B4F3A8FD90F05F6B4BDA8891EF5D5AB38
	533F623C77FE5830708C2D0CA01DB94841200BF1484513DAB1822D0E3D725A8EDF4ACF53D6803A47
	D5B3A39DA0F6D3FACC7C28B0A1DD758DB469A845B929FA9BA45341C237F6B0831E742113E970F986
	44A4A205ED58C3166CAEC8FFAFD20A9433A4CE51F5EF6927A0A3ACACE49DC23BDA5CD244A77A1A54
	94A66FB13A6F74DC7AC609D6308816E423112EFFEC2291831AF4610E8778E5B11DF64131152A6957
	FDB4C6D6B518D245C6FB4C5C1AF133AD4C6971582D15AA2FD49B303DF8691D33F7B8C53CA651830A
	44B182F81C825184528C6202E71CBAB13FB3435F2AB241954DAA5ED4F4B2E662BA4DDA8FA91B337A
	A695092D8CA8A95475457A19ACE73EE380F5826BCC6112D5284724FF303F6DC250880A0C631A679C
	B872DCF17CDF29AE56A56D6A58D0F8AA96E2BA4AD80FD9574FF0509B739AEA53778DCA72F425D2F3
	E09F893F9C621D436845019258C10C629186067462093B1CBDE78C6C3F945AA0AC3E758CA9774B5B
	211DA4F49EB515D8D2DE9A46DA35D4A2BC54FD4BD4F96FC21FF6B18B1E74210B19F00600",
			x"52494646A8030000574542505650384C9C0300002FF9010000098020FCAF1B88E87FEA0B456DDB40
	E68F76AF11B8210CFFE0F73F0122C02A9C01BE094AE1C0B66DB339BF416D5BF31F926D4475530D22
	7F058224DBAA938EFB97B8EBFE9714DCF9C483C3872049B2692B9FCD6FDBDEFF1E6C9BCFEF9B37D4
	B66DC3B8ED89BE20059E4689381D927449D0224E8D0879B44FDA96D8E30A5BBEBBC50D676BFFC038
	75AE92C9C34FFFEC7B7EAB776272AB7322BF652E706B2102C468A11BD045BF4ABFC6E08EFE3D8373
	BAD7E48EC95DA289D7103A75B234F065862A498AC452F16FFA0FAEB0C30576FCD79E7DE37A0CAF1E
	3BEDF7DC78B766FE76F52D19CA3DD3867CCF8093491855AF52881EEA98A0F1C3A245F8CAEA82B0CE
	629F6A9578936C0D87F883287552B449D3427A094AC4C820F602CFC41B6EF18A3BCFC4F381B1757C
	B13F8C6D76D3EBBFD1D5FFF8C2F0D2E042CF4AF726933C64134468A08B286088162615DA6DA657B4
	EA8C4E089FB08D27BCE337459836D2972D92D4885324F42F72A07CE2027BAC71201F47C71B97737C
	FE38627D95C6A73523EDEC5B3C29F64D9E6406BAAFF9C8B5812AFA083046F4C1BC4ADC607E415C61
	7640E981CA2E99066E050A596AE4A893A74A8E126972C45271C4339EF0C893EEB3FB937B62FF9A30
	B689E56EEE701E9EA5333BFD63E33BDD23FD07855D2176CE4568A38E218280D93BE1378B6BA226CB
	23821AFD2DCA15ACA3090A45A27449D221498B38752214D07FE80971C405F6A4BBC795EBC1EE9E7D
	CECF5F668C9FAEF1E7CA51E7D0EC417AA070141AF12A2342802EE280115A2D264F749E195FD1B963
	7842EE8ADC1199365A3A414A78653E5BC4CF9223998AFE08FFE2166FB8213D77C3B973DD5B3F7758
	C7CC74BF627CF70C2D9C74F54D1E9506064C29A31A7A1442F450C3048D3F162DC2775617044D567B
	D46AC49BE46BD8C717046990E07B98DF244E85083994B3C023B1F325F9DA7ADC72F6764F4EA7BEE5
	DBE2FEAF7FF637B7D53B31BED531D17FC8243699248D10119A68A3FB4BEF8F7E4532BCA1774FFF8C
	F6350E71850F7CC78950274B13DF4B5325499E682A7CA27DFA2779BA75394616CFC3D647617C5A33
	FE3AFB160DE59EC9936C5FCF251BBB04DC32FAA8638AE09B6585A0CDEA8CB0CE628F7285EA26D926
	AE847F85382DD27CB6C9976491484A8A2D6E91F82C77EE89DB23631BDF2789DD716CB39F5EA5A32B
	630B5D4B9D7385B5DC31CFCCA189067A8803469FB4BE99DCD1AE333DA5F94C779FFAC3872402419E
	186D527C1F9DA0469402A13F7A22F08E350E7CF7804B7C01",
			x"5249464630000000574542505650384C230000002F030000001F20102028976E434050E4FF680212
	62A593F2D1FCC7DF9040A84D44FF0300",
			x"5249464682000000574542505650384C750000002F300000009988E87F6C620C08246DF1B6BFFFF1
	3030682449D16799EECEBFD6271BBB0AD3B6617310833B194592A468B38FF9FEA7ECFCABE088E88B
	5339162A0A898A4086C3C3D0C28F5C83B97BA607EFA30F3E7830700B3418380526D0F975274F72C7
	4B872EEC42CEE2AA2EE91EEEE5BEDD8F1B00",
			x"5249464668000000574542505650384C5C0000002F140000009988E87F6C6A517F02495BBCEDEF7F
	DCA0A86D24E73F8BA097A370FCB1EC1EAC53D0B60D836265B1CF1F51466192A246529817C9158A5F
	F480CF88EBDBE8A003E58FFFA903838F050A7B183087050FA4BAAD5BD3EAB206",
			x"5249464664000000574542505650384C570000002F36000000CD4444FF631311FD0F0399B4CDD3F8
	B7BF296ADB48329EE1B227FF5F0B445124A9518E9DBC00FF0A61054440C45AF2E9A392F78A2212AE
	520C01D0000D8E605C1C33A37106D331B37CF2448A223FE24F9D0000",
			x"5249464668000000574542505650384C5B0000002F160000009988E87F6C22AADFFF30309024C9D0
	DAB64EFFFFF085A2B68DD8D4BFB73792630D4992AC94588655D8EFD3F90678040FE239BC881F7C07
	97412668116AC002D347E8A5F470BA0243E2D76089874432E96490236EF60900",
			x"5249464658000000574542505650384C4C0000002F0C00000067A0A06D1B2652D19C8D3FBB8D8699
	B66D5C56BD57FE9866206D9B6D6E2EE8D2FBBB19F31F50D4BF9DD01513EFA528C4296C061608324C
	B6734412472CB184116E44FFE34A6700",
			x"5249464652000000574542505650384C460000002F0800000047A0260001865F0E3546FF506A1004
	9044B3C700FB238C91810044EC70C00D6BFC74C3989AFF0078DF947C0A99680F635A814CDA36482D
	554B05CCCD22FA1FBB01",
			x"5249464674000000574542505650384C670000002F0F0000007FC0A091244597F36F929919FF6D28
	8D64ABF9FF93E9BF2C140A89CA3490511C495272F63B2CFF942004CFC0DFCC7F0080FFFF5A9C6245
	7C32A42F6A9B70929D22E8B3DF3D3D283D02F204158BD9030802201EB468D1A2458B160D7222FA1F
	5F631100",
			x"524946462A000000574542505650384C1D0000002F0200000017201048DA1F7A8DF1171014F93FDA
	FC075F0A8A11D1FF0000",
			x"5249464666000000574542505650384C5A0000002F230000009988E87F6C22A2FF6160084992A494
	5883DF5F66EF4EE1807A14B491143541002EEEF16FE6C0031A40D4486A46041AE0FCCB817F5D3489
	F0C3757F91CDE2D01E87E1322A3461AAC8AF2EC94BBE45D0244D50ECC702",
			x"5249464660000000574542505650384C540000002F0C00000067A026009086930C342000E74C3EF4
	34800DCC601402018AF6F07F8AEE60100060D9D86C9BC7FC071C4C3ECA4FFE611FE4865BFE9A6772
	F54EB51DA6828120802486596699659659068DE87F7C8D05",
			x"524946465E000000574542505650384C510000002F1A0000009988E87F6C22A2FF6140D3485246C8
	8796F76F8737408B9A43411B494A9F5CA07F3B2C4751DB488ED9EC758A47B5B2B84F0493CA208A66
	93B4BFEA3296B9CC1D6399FBCD37C570C8CFFD2C0E00",
			x"5249464680000000574542505650384C740000002F1300000050130020632520840A4E456613AF18
	12E8E017C1EB756E72280900A689B100B31BA0AF8310442104298840061AE069F0F4849A00401AC6
	C54F0612E04E601CAB18C02E46B08319BC3CFA1FD43411A74AC7E717EDCF782BEC4EEB94F15B1F23
	B415CAA9493C88B9AF720B9FCC3A924A",
			x"524946465E000000574542505650384C510000002F140000005010D93675DEAFF10BF344A0820854
	1041056A20886C433B23B20E42C9A0820857C1296824A9199AF36A010BAF0509E0A5FF0164A70E11
	78E997D7C5B09B3C397C5EBBCF3AF57158316DCF0500",
			x"52494646CA000000574542505650384CBD0000002F480000009988E87F6C62E807BFFF011B5C47B2
	6D5AEBDE2FDBBE19F8E69F8B9F6DA6710EA3489214E56BE198D9BF3532718E23DB56A243B9938E4B
	68C4E9B083A53B331190BBFA50EDEB64C7424817A23FAF418E16195468D05C9CF167F81BFF062859
	15A340539EB7FBB4705EF98D881129224681AF6CA673D039E85C7407FA19DDF4EEE77B781EB8E34E
	7810EF24B245E71D7C64EDBFC3017BDC849042863F961E4D7A906F94EF67CF2F752EC91C242D4A7A
	140955A3644449891200"
		]; 
		
	}
}
version(/+$DIDE_REGION+/all)
{
	version(D2D_FONT_RENDERER)
	{
		 private: 
			//Direct2D stuff ////////////////////////////////////////////////////////
		
			pragma(lib, "D2d1.lib"); 
			pragma(lib, "DWrite.lib"); 
		
			alias FLOAT = float, UINT32 = uint, UINT64 = ulong, D2D1_TAG = UINT64; 
		
			struct D2D_RECT_F
		{ float left=0, top=0, right=0, bottom=0; } 
			alias D2D1_RECT_F = D2D_RECT_F; 
			struct D2D1_COLOR_F
		{ float r=0, g=0, b=0, a=1; } 
			alias DWRITE_COLOR_F = D2D1_COLOR_F; 
			struct D2D1_POINT_2F
		{ float x=0, y=0; } 
			alias D2D1_SIZE_F = D2D1_POINT_2F; 
			struct D2D1_SIZE_U
		{ uint x=0, y=0; } 
			struct D2D1_MATRIX_3X2_F
		{ float m11=1, m12=0, m21=0, m22=1, dx=0, dy=0; } 
			struct DWRITE_TEXT_RANGE
		{ uint start, length; } 
		
			struct D2D1_RENDER_TARGET_PROPERTIES
		{
			int type, pixelFormat, alphaMode; 
			float dpiX=0, dpiY=0; 
			int usage, minLevel; 
		} 
			auto DCRenderTargetProps()
		{
			return D2D1_RENDER_TARGET_PROPERTIES(
				0, 
				87 /*DXGI_FORMAT_B8G8R8A8_UNORM*/, 
				3 /*3:IGNORE, 2:STRAIGHT(unsupported)*/
			); 
		} 
		
			mixin(uuid!(ID2D1Factory, "06152247-6f50-465a-9245-118bfd3b6007")); 
			interface ID2D1Factory : IUnknown
		{
			HRESULT ReloadSystemMetrics(); 
			void GetDesktopDpi(/*out*/ FLOAT *dpiX,/*out*/ FLOAT *dpiY); 
			HRESULT CreateRectangleGeometry(/**/); 
			HRESULT CreateRoundedRectangleGeometry(/**/); 
			HRESULT CreateEllipseGeometry(/**/); 
			HRESULT CreateGeometryGroup(/**/); 
			HRESULT CreateTransformedGeometry(/**/); 
			HRESULT CreatePathGeometry(/**/); 
			HRESULT CreateStrokeStyle(/**/); 
			HRESULT CreateDrawingStateBlock(/**/); 
			HRESULT CreateWicBitmapRenderTarget(/**/); 
			HRESULT CreateHwndRenderTarget(/**/); 
			HRESULT CreateDxgiSurfaceRenderTarget(/**/); 
			HRESULT CreateDCRenderTarget(
				const D2D1_RENDER_TARGET_PROPERTIES renderTargetProperties, 
				out ID2D1DCRenderTarget dcRenderTarget
			); 
		} 
		
			enum D2D1_FACTORY_TYPE:uint
		{ SINGLE_THREADED, MULTI_THREADED, FORCE_DWORD = 0xffffffff} 
		
			extern(Windows) HRESULT D2D1CreateFactory(
			D2D1_FACTORY_TYPE factoryType, 
			REFIID riid, void* pFactoryOptions, out ID2D1Factory
		); 
		
			enum D2D1_ANTIALIAS_MODE:uint
		{ PER_PRIMITIVE, ALIASED, FORCE_DWORD = 0xffffffff} 
			enum D2D1_DRAW_TEXT_OPTIONS:uint
		{ NONE=0, NO_SNAP=1, CLIP=2, ENABLE_COLOR_FONT=4, FORCE_DWORD=0xffffffff} 
			enum D2D1_TEXT_ANTIALIAS_MODE:uint
		{ DEFAULT, CLEARTYPE, GRAYSCALE, ALIASED, FORCE_DWORD = 0xffffffff} 
		
			enum DWRITE_TEXT_ALIGNMENT :int
		{ LEADING, TRAILING, CENTER, JUSTIFIED} 
			enum DWRITE_PARAGRAPH_ALIGNMENT :int
		{ NEAR, FAR, CENTER} 
			enum DWRITE_WORD_WRAPPING :int
		{ WRAP, NO_WRAP, EMERGENCY_BREAK, WHOLE_WORD, CHARACTER} 
			enum DWRITE_READING_DIRECTION :int
		{ LEFT_TO_RIGHT, RIGHT_TO_LEFT, TOP_TO_BOTTOM, BOTTOM_TO_TOP} 
			enum DWRITE_FLOW_DIRECTION :int
		{ TOP_TO_BOTTOM, BOTTOM_TO_TOP, LEFT_TO_RIGHT, RIGHT_TO_LEFT} 
			enum DWRITE_TRIMMING_GRANULARITY :int
		{ NONE, CHARACTER, WORD} 
			enum DWRITE_LINE_SPACING_METHOD :int
		{ DEFAULT, UNIFORM} 
			enum DWRITE_FONT_WEIGHT :int
		{
			THIN=100, EXTRA_LIGHT=200, ULTRA_LIGHT=200, LIGHT=300, SEMI_LIGHT=350, NORMAL=400, 
			REGULAR=400, MEDIUM=500, DEMI_BOLD=600, SEMI_BOLD=600, BOLD=700, EXTRA_BOLD=800, 
			ULTRA_BOLD=800, BLACK=900, HEAVY=900, EXTRA_BLACK=950, ULTRA_BLACK=950
		} 
			enum DWRITE_FONT_STRETCH :int
		{
			UNDEFINED=0, ULTRA_CONDENSED=1, EXTRA_CONDENSED=2, CONDENSED=3, SEMI_CONDENSED=4, 
			NORMAL=5, MEDIUM=5, SEMI_EXPANDED=6, EXPANDED=7, EXTRA_EXPANDED=8, ULTRA_EXPANDED=9
		} 
			enum DWRITE_FONT_STYLE :int
		{ NORMAL, OBLIQUE, ITALIC} 
		
			struct DWRITE_TEXT_METRICS
		{
			float 	left, top,
				width, widthIncludingTrailingWhitespace,
				height,
				layoutWidth, layoutHeight; 
			uint maxBidiReorderingDepth, lineCount; 
		} 
		
			mixin(uuid!(IDWriteTextFormat, "9c906818-31d7-4fd3-a151-7c5e225db55a")); 
			interface IDWriteTextFormat : IUnknown
		{
			HRESULT SetTextAlignment(DWRITE_TEXT_ALIGNMENT textAlignment); 
			HRESULT SetParagraphAlignment(DWRITE_PARAGRAPH_ALIGNMENT paragraphAlignment); 
			HRESULT SetWordWrapping(DWRITE_WORD_WRAPPING wordWrapping); 
			HRESULT SetReadingDirection(DWRITE_READING_DIRECTION readingDirection); 
			HRESULT SetFlowDirection(DWRITE_FLOW_DIRECTION flowDirection); 
			HRESULT SetIncrementalTabStop(FLOAT incrementalTabStop); 
			HRESULT SetTrimming(/**/); 
			HRESULT SetLineSpacing(DWRITE_LINE_SPACING_METHOD lineSpacingMethod, FLOAT lineSpacing, FLOAT baseline); 
			DWRITE_TEXT_ALIGNMENT GetTextAlignment(); 
			DWRITE_PARAGRAPH_ALIGNMENT GetParagraphAlignment(); 
			DWRITE_WORD_WRAPPING GetWordWrapping(); 
			DWRITE_READING_DIRECTION GetReadingDirection(); 
			DWRITE_FLOW_DIRECTION GetFlowDirection(); 
			FLOAT GetIncrementalTabStop(); 
			HRESULT GetTrimming(/**/); 
			HRESULT GetLineSpacing(/*out*/ DWRITE_LINE_SPACING_METHOD* lineSpacingMethod, /*out*/ FLOAT* lineSpacing, /*out*/ FLOAT* baseline); 
			HRESULT GetFontCollection(/**/); 
			UINT32 GetFontFamilyNameLength(); 
			HRESULT GetFontFamilyName(/*out*/ WCHAR* fontFamilyName, UINT32 nameSize); 
			DWRITE_FONT_WEIGHT GetFontWeight(); 
			DWRITE_FONT_STYLE GetFontStyle(); 
			DWRITE_FONT_STRETCH GetFontStretch(); 
			FLOAT GetFontSize(); 
			UINT32 GetLocaleNameLength(); 
			HRESULT GetLocaleName(/*out*/ WCHAR* localeName, UINT32 nameSize); 
		} 
		
			struct D2D1_BRUSH_PROPERTIES
		{
			FLOAT opacity = 1; 
			D2D1_MATRIX_3X2_F transform; 
		} 
		
			mixin(uuid!(ID2D1Brush, "2cd906a8-12e2-11dc-9fed-001143a055f9")); 
			interface ID2D1Brush : ID2D1Resource
		{
			//extern(Windows): 
			void SetOpacity(FLOAT opacity); 
			void SetTransform(const D2D1_MATRIX_3X2_F transform); 
			FLOAT GetOpacity() const; 
			void GetTransform(out D2D1_MATRIX_3X2_F transform) const; 
		} 
		
			mixin(uuid!(ID2D1SolidColorBrush, "2cd906a9-12e2-11dc-9fed-001143a055f9")); 
			interface ID2D1SolidColorBrush : ID2D1Brush
		{
			//extern(Windows): 
			void SetColor(const D2D1_COLOR_F color); 
			ref D2D1_COLOR_F GetColor() const; //Bug: got crash? see ID2D1RenderTarget.GetSize()
		} 
		
			mixin(uuid!(ID2D1Resource, "2cd90691-12e2-11dc-9fed-001143a055f9")); 
			interface ID2D1Resource : IUnknown
		{
			//extern(Windows): 
			void GetFactory(out ID2D1Factory factory) const; 
		} 
		
			mixin(uuid!(ID2D1RenderTarget, "2cd90694-12e2-11dc-9fed-001143a055f9")); 
			interface ID2D1RenderTarget : ID2D1Resource
		{
			HRESULT CreateBitmap(/**/); 
			HRESULT CreateBitmapFromWicBitmap(/**/); 
			HRESULT CreateSharedBitmap(/**/); 
			HRESULT CreateBitmapBrush(/**/); 
			HRESULT CreateSolidColorBrush(
				const D2D1_COLOR_F color, 
				const D2D1_BRUSH_PROPERTIES brushProperties, 
				out ID2D1SolidColorBrush solidColorBrush
			); 
			HRESULT CreateGradientStopCollection(/**/); 
			HRESULT CreateLinearGradientBrush(/**/); 
			HRESULT CreateRadialGradientBrush(/**/); 
			HRESULT CreateCompatibleRenderTarget(/**/); 
			HRESULT CreateLayer(/**/); 
			HRESULT CreateMesh(/**/); 
			void DrawLine(/**/); 
			void DrawRectangle(/**/); 
			void FillRectangle(const D2D1_RECT_F rect, ID2D1Brush brush); 
			void DrawRoundedRectangle(/**/); 
			void FillRoundedRectangle(/**/); 
			void DrawEllipse(/**/); 
			void FillEllipse(/**/); 
			void DrawGeometry(/**/); 
			void FillGeometry(/**/); 
			void FillMesh(/**/); 
			void FillOpacityMask(/**/); 
			void DrawBitmap(/**/); 
			void DrawText(/**/); 
			
			void DrawTextLayout(
				D2D1_POINT_2F origin, IDWriteTextLayout textLayout, ID2D1Brush defaultForegroundBrush,
							D2D1_DRAW_TEXT_OPTIONS options = D2D1_DRAW_TEXT_OPTIONS.NONE
			); 
			
			void DrawGlyphRun(/**/); 
			
			void SetTransform(const D2D1_MATRIX_3X2_F transform); 
			void GetTransform(out D2D1_MATRIX_3X2_F transform) const; 
			void SetAntialiasMode(D2D1_ANTIALIAS_MODE antialiasMode); 
			D2D1_ANTIALIAS_MODE GetAntialiasMode() const; 
			void SetTextAntialiasMode(D2D1_TEXT_ANTIALIAS_MODE textAntialiasMode); 
			D2D1_TEXT_ANTIALIAS_MODE GetTextAntialiasMode() const; 
			void SetTextRenderingParams(/**/); /*
				Todo: SetTextRenderingParams gdi classic-ra allitani, 
								hogy szebb legyen az ui font, ekkor a 3x 
								miatt pont cleartype-ra fog illeszkedni.
			*/
			void GetTextRenderingParams(/**/) const; 
			void SetTags(D2D1_TAG tag1, D2D1_TAG tag2); 
			void GetTags(/*out*/ D2D1_TAG *tag1 = null, /*out*/ D2D1_TAG *tag2 = null) const; 
			void PushLayer(/**/); 
			void PopLayer(); 
			HRESULT Flush(/*out*/ D2D1_TAG *tag1 = null, /*out*/ D2D1_TAG *tag2 = null); 
			void SaveDrawingState(/**/) const; 
			void RestoreDrawingState(/**/); 
			void PushAxisAlignedClip(/**/); 
			void PopAxisAlignedClip(); 
			
			void Clear(const D2D1_COLOR_F clearColor); 
			
			void BeginDraw(); 
			HRESULT EndDraw(/*out*/ D2D1_TAG *tag1 = null,/*out*/ D2D1_TAG *tag2 = null); 
			
			void GetPixelFormat(/**/) const; 
			void SetDpi(/**/); 
			void GetDpi(/*out*/ FLOAT *dpiX,/*out*/ FLOAT *dpiY) const; 
			void GetSize(D2D1_SIZE_F* outSize) const; //<-- NOTE: ABI bug workaround, see D2D1_SIZE_F GetSize() below
			void GetPixelSize(D2D1_SIZE_U* outSize) const; //<-- NOTE: ABI bug workaround, see D2D1_SIZE_U GetPixelSize() below
			UINT32 GetMaximumBitmapSize() const; 
			BOOL IsSupported(const(D2D1_RENDER_TARGET_PROPERTIES)* renderTargetProperties) const; 
		} 
		
			//------------------------------------------------------------------------------
			mixin(uuid!(ID2D1DCRenderTarget, "1c51bc64-de61-46fd-9899-63a5d8f03950")); 
			interface ID2D1DCRenderTarget : ID2D1RenderTarget
		{ HRESULT BindDC(const HDC  hDC, const(RECT)* pSubRect); } 
		
			mixin(uuid!(IDWriteFactory, "b859ee5a-d838-4b5b-a2e8-1adc7d93db48")); 
			interface IDWriteFactory : IUnknown
		{
			HRESULT GetSystemFontCollection(/**/); 
			HRESULT CreateCustomFontCollection(/**/); 
			HRESULT RegisterFontCollectionLoader(/**/); 
			HRESULT UnregisterFontCollectionLoader(/**/); 
			HRESULT CreateFontFileReference(/**/); 
			HRESULT CreateCustomFontFileReference(/**/); 
			HRESULT CreateFontFace(/**/); 
			HRESULT CreateRenderingParams(/**/); 
			HRESULT CreateMonitorRenderingParams(/**/); 
			HRESULT CreateCustomRenderingParams(/**/); 
			HRESULT RegisterFontFileLoader(/**/); 
			HRESULT UnregisterFontFileLoader(/**/); 
			
			HRESULT CreateTextFormat(
				const(WCHAR)* fontFamilyName, void* fontCollection,
				DWRITE_FONT_WEIGHT fontWeight, DWRITE_FONT_STYLE fontStyle, 
				DWRITE_FONT_STRETCH fontStretch,
				FLOAT fontSize, const(WCHAR)* localeName, 
				out IDWriteTextFormat textFormat
			); 
			
			HRESULT CreateTypography(/**/); 
			HRESULT GetGdiInterop(/**/); 
			
			HRESULT CreateTextLayout(
				const(WCHAR)* string, UINT32 stringLength, 
				IDWriteTextFormat textFormat, FLOAT maxWidth, FLOAT maxHeight, 
				out IDWriteTextLayout textLayout
			); 
			
			HRESULT CreateGdiCompatibleTextLayout(/**/); 
			HRESULT CreateEllipsisTrimmingSign(/**/); 
			HRESULT CreateTextAnalyzer(/**/); 
			HRESULT CreateNumberSubstitution(/**/); 
			HRESULT CreateGlyphRunAnalysis(/**/); 
		} 
		
			enum DWRITE_FACTORY_TYPE : int { SHARED, ISOLATED} 
		
			export extern(C) HRESULT DWriteCreateFactory(DWRITE_FACTORY_TYPE factoryType, REFIID iid, out IDWriteFactory factory); 
		
			mixin(uuid!(IDWriteTextLayout, "53737037-6d14-410b-9bfe-0b182bb70961")); 
			interface IDWriteTextLayout : IDWriteTextFormat
		{
			HRESULT SetMaxWidth(FLOAT maxWidth); 
			HRESULT SetMaxHeight(FLOAT maxHeight); 
			HRESULT SetFontCollection(/**/); 
			HRESULT SetFontFamilyName(const(WCHAR)* fontFamilyName, DWRITE_TEXT_RANGE textRange); 
			HRESULT SetFontWeight(DWRITE_FONT_WEIGHT fontWeight, DWRITE_TEXT_RANGE textRange); 
			HRESULT SetFontStyle(DWRITE_FONT_STYLE fontStyle, DWRITE_TEXT_RANGE textRange); 
			HRESULT SetFontStretch(DWRITE_FONT_STRETCH fontStretch, DWRITE_TEXT_RANGE textRange); 
			HRESULT SetFontSize(FLOAT fontSize, DWRITE_TEXT_RANGE textRange); 
			HRESULT SetUnderline(BOOL hasUnderline, DWRITE_TEXT_RANGE textRange); 
			HRESULT SetStrikethrough(BOOL hasStrikethrough, DWRITE_TEXT_RANGE textRange); 
			HRESULT SetDrawingEffect(IUnknown drawingEffect, DWRITE_TEXT_RANGE textRange); 
			HRESULT SetInlineObject(/**/); 
			HRESULT SetTypography(/**/); 
			HRESULT SetLocaleName(const(WCHAR)* localeName, DWRITE_TEXT_RANGE textRange); 
			FLOAT GetMaxWidth(); 
			FLOAT GetMaxHeight(); 
			HRESULT GetFontCollection(/**/); 
			HRESULT GetFontFamilyNameLength(UINT32 currentPosition, UINT32* nameLength, /*out*/ DWRITE_TEXT_RANGE* textRange = null); 
			HRESULT GetFontFamilyName(UINT32 currentPosition, /*out*/ WCHAR* fontFamilyName, UINT32 nameSize, DWRITE_TEXT_RANGE* textRange = null); 
			HRESULT GetFontWeight(UINT32 currentPosition, /*out*/ DWRITE_FONT_WEIGHT* fontWeight, /*out*/ DWRITE_TEXT_RANGE* textRange = null); 
			HRESULT GetFontStyle(UINT32 currentPosition, /*out*/ DWRITE_FONT_STYLE* fontStyle, /*out*/ DWRITE_TEXT_RANGE* textRange = null); 
			HRESULT GetFontStretch(UINT32 currentPosition,/*out*/ DWRITE_FONT_STRETCH* fontStretch, /*out*/ DWRITE_TEXT_RANGE* textRange = null); 
			HRESULT GetFontSize(UINT32 currentPosition, /*out*/ FLOAT* fontSize, /*out*/ DWRITE_TEXT_RANGE* textRange = null); 
			HRESULT GetUnderline(UINT32 currentPosition,/*out*/ BOOL* hasUnderline, /*out*/ DWRITE_TEXT_RANGE* textRange = null); 
			HRESULT GetStrikethrough(UINT32 currentPosition, /*out*/ BOOL* hasStrikethrough, /*out*/ DWRITE_TEXT_RANGE* textRange = null); 
			HRESULT GetDrawingEffect(UINT32 currentPosition, /*out*/ IUnknown* drawingEffect, /*out*/ DWRITE_TEXT_RANGE* textRange = null); 
			HRESULT GetInlineObject(/**/); 
			HRESULT GetTypography(/**/); 
			HRESULT GetLocaleNameLength(UINT32 currentPosition, /*out*/ UINT32* nameLength, /*out*/ DWRITE_TEXT_RANGE* textRange = null); 
			HRESULT GetLocaleName(UINT32 currentPosition, /*out*/ WCHAR* localeName, UINT32 nameSize, /*out*/ DWRITE_TEXT_RANGE* textRange = null); 
			HRESULT Draw(/**/); 
			HRESULT GetLineMetrics(/**/); 
			HRESULT GetMetrics(out DWRITE_TEXT_METRICS textMetrics); 
			HRESULT GetOverhangMetrics(/**/); 
			HRESULT GetClusterMetrics(/**/); 
			HRESULT DetermineMinWidth(/*out*/ FLOAT* minWidth); 
			HRESULT HitTestPoint(/**/); 
			HRESULT HitTestTextPosition(/**/); 
			HRESULT HitTestTextRange(/**/); 
		} 
		
		
			class BitmapFontRenderer
		{
			private: 
				BitmapFontProps props; 
				alias props this; 
				bool isSegoeAssets, isLucidaConsole; 
			
				ID2D1Factory d2dFactory; 
				IDWriteFactory dwFactory; 
			
				ID2D1DCRenderTarget dcrt; 
			
				IDWriteTextFormat textFormat; 
				ID2D1SolidColorBrush brush; 
			
				bool mustRebuild = true; 
			
				const 	white	= D2D1_COLOR_F(1, 1, 1),
				black	= D2D1_COLOR_F(0, 0, 0),
				heightScale 	= 0.75f; 
			
				void initialize()
			{
				//Create factories
				D2D1CreateFactory(
					D2D1_FACTORY_TYPE.SINGLE_THREADED, 
					&IID_ID2D1Factory, null, d2dFactory
				).hrChk("D2D1CreateFactory"); 
				DWriteCreateFactory(
					DWRITE_FACTORY_TYPE.SHARED, 
					&IID_IDWriteFactory, dwFactory
				).hrChk("DWriteCreateFactory"); 
				
				//Create DCRenderTarget
				d2dFactory.CreateDCRenderTarget(DCRenderTargetProps, dcrt).hrChk("CreateDCRenderTarget"); 
				
				//Create brush
				dcrt.CreateSolidColorBrush(black, D2D1_BRUSH_PROPERTIES(1), brush).hrChk("CreateSolidColorBrush"); 
			} 
			
				void rebuild()
			{
				if(!chkClear(mustRebuild)) return; 
				
				isSegoeAssets = fontName=="Segoe MDL2 Assets"; 
				isLucidaConsole = fontName=="Lucida Console"; 
				
				//Create font
				SafeRelease(textFormat); 
				dwFactory.CreateTextFormat(
					fontName.toPWChar, 
					null/*fontCollection*/,
					DWRITE_FONT_WEIGHT.REGULAR, 
					DWRITE_FONT_STYLE.NORMAL, 
					DWRITE_FONT_STRETCH.NORMAL,
					height*heightScale, 
					"".toPWChar/*locale*/, 
					textFormat
				).hrChk("CreateTextFormat"); 
				
				dcrt.SetTransform(D2D1_MATRIX_3X2_F(xScale, 0, 0, 1, 0, 0)); 
				dcrt.SetTextAntialiasMode(
					clearType 	? D2D1_TEXT_ANTIALIAS_MODE.CLEARTYPE 
						: D2D1_TEXT_ANTIALIAS_MODE.GRAYSCALE
				); 
			} 
			
				void finalize()
			{
				SafeRelease(textFormat); 
				SafeRelease(brush); 
				SafeRelease(dcrt); 
				SafeRelease(d2dFactory); 
				SafeRelease(dwFactory); 
			} 
			public: 
				this()
			{ initialize; } 
			
				~this()
			{ finalize; } 
			
				void setProps(in BitmapFontProps props_)
			{
				if(props==props_) return; 
				props = props_; 
				mustRebuild = true; 
			} 
			
				Bitmap render(in BitmapFontProps props_, string text)
			{
				setProps(props_); 
				return renderText(text); 
			} 
			
				Bitmap renderDecl(string fontDecl)
			{
				string text; 
				setProps(decodeFontDeclaration(fontDecl, text)); 
				return renderText(text); 
			} 
			
				Bitmap renderText(string text)
			{
				enforce(!text.empty, "Nothing to render."); 
				
				if(mustRebuild) rebuild; 
				
				//a single space character needs special care
				const spaceIdx = text.among(" ", /*"\u2000", "\u2001", "\u2004",*/ smallSpace); 
				//Todo: measure the width of spaces. For example put 2 well known chars around it.
				
				const spaceScale =  [1,	1 , /*2	    , 4	      , 0.666f	 ,*/ 0.4f    ][spaceIdx]; 
								 //1/4em	1/2em	    1em	      1/6em	 1/4em      thin
				const isSpace = spaceIdx>0; 
				if(isSpace) text = "j";  //a letter used to emulate the width of a space.
				//Todo: get space width from DirectWrite
				
				//Create text layout
				IDWriteTextLayout textLayout; 
				auto ws = text.toUTF16; 
				
				dwFactory.CreateTextLayout(
					ws.ptr, cast(uint)ws.length, 
					textFormat, float.max, height, textLayout
				).hrChk("CreateTextLayout"); 
				scope(exit) SafeRelease(textLayout); 
				
				//get text extents
				DWRITE_TEXT_METRICS metrics; 
				textLayout.GetMetrics(metrics).hrChk("GetMetrics"); 
				
				auto bmpSize()
				{ return ivec2((metrics.width*props.xScale*spaceScale).iround, props.height).max(ivec2(1)); } 
				
				if(isSpace) { return new Bitmap(image2D(bmpSize, ubyte(0))); }
				
				Bitmap doRender(bool inverse=false)
				{
					auto gBmp = new GdiBitmap(bmpSize); 
					scope(exit) gBmp.destroy; 
					
					//draw
					auto rect = RECT(0, 0, gBmp.size.x, gBmp.size.y); //Todo: this can be null???
					dcrt.BindDC(gBmp.hdcMem, &rect).hrChk("BindDC"); 
					
					dcrt.BeginDraw; 
						dcrt.Clear(inverse ? white : black); 
						brush.SetColor(inverse ? black : white); 
					
						float y = 0; 
						if(isLucidaConsole) y = props.height*0.16f; else if(!isSegoeAssets)
					y = props.height*((-1.425f)/18); 
					
						dcrt.DrawTextLayout(
						D2D1_POINT_2F(0, y), textLayout, brush, 
						D2D1_DRAW_TEXT_OPTIONS.ENABLE_COLOR_FONT
					); 
					dcrt.EndDraw.hrChk("EndDraw"); 
					
					return gBmp.toBitmap; 
				} 
				
				auto res = doRender; 
				
				static bool isGrayscale(in RGBA color)
				{ return color.rg==color.gb; } 
				
				if(
					res.access!RGBA.asArray.map!isGrayscale.all && 
					!text.among("➕", "➖", "➗", "✖", "⚙", "🧾", "📄")
					/+Opt: faster lookup with more exceptions+/
					/+Todo: Get the alpha mask with IDWriteGlyphRunAnalysis+/
				)
				{
					res.set(res.get!ubyte); //convert it to 1 channel
				}
				else
				{
					auto res2 = doRender(true); 
					
					//ha ide betuk keverednek, akkor aszoknak zajos lesz a konturjuk ugyanis
					//nem csak a hatterszin valtozik, hanem az eloteszin is. Az mar duplaannyi, mint kene.
					
					static RGBA process(RGBA a, RGBA b)
					{
						ubyte alpha = cast(ubyte)(~(b.r - a.r)); 
						return alpha<0xff 	? RGBA(0,0,0, alpha)
							: RGBA(b.bgr, alpha); 
					} 
					res.set(image2D!process(res.access!RGBA, res2.access!RGBA)); 
					
				}
				
				if(isSegoeAssets)
				{
					 //align the assets font vertically with letters
					int ysh = iround(res.height*0.125f); //scroll down that many pixels
					
					auto img = res.access!ubyte; 
					img = img.extract_nearest(0, -ysh, res.width, res.height); 
					res.set(img); 
				}
				
				return res; 
			} 
		} 
		
			alias bitmapFontRenderer = Singleton!BitmapFontRenderer; 
	}
	
	//Segoe Symbol database ////////////////////////////////
	dchar segoeSymbolByName(string name)
	{
		immutable tableData =
			"Wifi2=59507;UnderscoreSpace=59229;MailReply=59594;IBeam=59699;FolderHorizontal=61739;WifiCallBars=60372;StatusErrorCircle7=61624"~
			";Dial6=61771;MobWifi1=60476;NarratorForwardMirrored=60842;BumperLeft=61708;Unpin=59258;CalendarReply=59637;Annotation=59684;Setl"~
			"ockScreen=59317;CollateLandscapeSeparated=62892;AlignLeft=59620;Attach=59171;ReturnKey=59217;ChromeAnnotateContrast=61689;Pinned"~
			"=59456;EndPoint=59419;DataSense=59281;Read=59587;AlignCenter=59619;PrintDefault=62829;VerticalBatteryCharging1=62974;ReminderFil"~
			"l=60239;ReturnToWindow=59716;CollapseContent=61797;eSIMNoProfile=63004;SyncError=60010;LanguageJpn=60485;PowerButton=59368;Keybo"~
			"ardRightAligned=61965;FlickRight=59704;CalligraphyPen=60923;KeyboardLeftDock=62061;Headset=59739;AppIconDefault=60586;SpatialVol"~
			"ume3=61678;People=59158;RepeatOne=59629;CallForwarding=59378;WifiWarning2=60257;TaskViewSettings=60992;FavoriteStar=59188;Grippe"~
			"rResizeMirrored=59984;WifiCall4=60377;Location=59421;MapPin=59143;CityNext2=60423;RoamingInternational=59512;Edit=59151;CityNext"~
			"=60422;GoToStart=59644;EMI=59185;BatterySaver2=59493;StatusDualSIM2=59522;Bluetooth=59138;ResizeMouseTallMirrored=60001;DeviceDi"~
			"scovery=60382;PieSingle=60165;ChevronLeftSmall=59759;LightningBolt=59717;ToggleFilled=60433;TreeFolderFolderOpenFill=60740;Chrom"~
			"eBackContrastMirrored=61654;PPSTwoLandscape=62859;AdjustHologram=60370;QuietHoursBadge12=61646;StaplingLandscapeTwoRight=62886;A"~
			"rrowLeft8=61616;CollapseContentSingle=61798;NUIFPStartSlideAction=60291;FileExplorer=60496;NUIFPContinueSlideHand=60292;SignalBa"~
			"rs1=59500;StatusCircleCheckmark=61758;Volume1=59795;PreviewLink=59553;Korean=59773;MobBattery6=60326;AddRemoteDevice=59446;Check"~
			"List=59861;ResizeMouseSmallMirrored=60000;BrushSize=60840;DeviceLaptopPic=59383;TiltDown=59402;DuplexLandscapeTwoSidedShortEdge="~
			"62850;Battery5=59477;ResizeTouchNarrowerMirrored=60002;PenWorkspaceMirrored=61205;MobileTablet=59596;FuzzyReading=62959;ResizeMo"~
			"useWide=59205;ProgressRingDots=61802;TaskView=59332;MobBatteryCharging6=60337;Forward=59178;DrivingMode=59372;ThisPC=60494;Direc"~
			"tAccess=59451;Connected=61625;SmallErase=61737;MicOff=60500;BandBattery2=60603;ExploreContentSingle=61796;ResizeTouchNarrower=59"~
			"370;InkingColorFill=60775;PaymentCard=59591;Photo=59675;NUIFPPressRepeatAction=60301;ActionCenter=59676;ChevronRightMed=59764;Vo"~
			"lume=59239;RightArrowKeyTime0=60391;CalculatorSquareroot=59723;Groceries=60425;InternetSharing=59140;ChecklistMirrored=61621;Att"~
			"achCamera=59554;DoublePinyin=61573;Underline=59612;Keyboard12Key=62049;Dialpad=59231;StrokeEraseMirrored=61207;DefenderBadge12=6"~
			"1691;BusSolid=60231;History=59420;MobSignal3=60473;AllAppsMirrored=59968;Package=59320;StopPoint=59418;ChromeMinimizeContrast=61"~
			"229;Share=59181;WifiError2=60252;AirplaneSolid=60236;RingerSilent=59373;Connect=59139;Repair=59663;StatusError=60035;Down=59211;"~
			"WifiCall3=60376;MusicSharingOff=63012;MusicNote=60495;MobBattery5=60325;MobBatterySaver7=60349;View=59536;EyeGaze=61853;SpeedHig"~
			"h=60490;GripperBarVertical=59268;PuncKey0=59468;Reply=59770;ExploreContent=60621;ChinesePunctuation=61713;ChromeMinimize=59681;B"~
			"andBattery5=60606;StatusCircleRing=61752;JpnRomanji=59516;ImportMirrored=59986;TrainSolid=60237;Trim=59274;Zoom=59166;RightQuote"~
			"=59465;ActionCenterNotification=59367;FileExplorerApp=60497;Lock=59182;Unit=60614;VerticalBattery7=62969;ErrorBadge=59961;DateTi"~
			"me=60562;Reshare=59627;HolePunchPortraitRight=62865;AddFriend=59642;Broom=60057;Input=59745;MobSIMError=62891;InkingColorOutline"~
			"=60774;UnsyncFolder=59638;Manage=59666;Stop=59162;CaretBottomRightSolidCenter8=61801;StatusCircleErrorX=61757;StatusTriangleOute"~
			"r=61753;JpnRomanjiShift=59518;VerticalBattery8=62970;DockLeft=59660;PenPaletteMirrored=61206;TollSolid=61793;PuncKeyLeftBottom=5"~
			"9469;FontSize=59625;Permissions=59607;MapCompassBottom=59411;Print=59209;OutlineHalfStarRight=61672;Streaming=59710;ToggleBorder"~
			"=60434;DisableUpdates=59608;Caption=59578;KeyboardNarrow=62048;Lightbulb=60032;Type=59772;Code=59715;BatterySaver5=59496;Landsca"~
			"peOrientationMirrored=62831;BrowsePhotos=59333;Dial5=61770;TreeFolderFolder=60737;PuncKey1=59828;CalculatorMultiply=59719;HWPScr"~
			"atchOut=62563;Ethernet=59449;SIPMove=59225;WifiCall1=60374;Globe=59252;Sensor=59735;Tiles=60581;MobBatterySaver5=60347;PoliceCar"~
			"=60545;DeviceMonitorLeftPic=59386;PageMarginPortraitNarrow=62835;Search=59169;Shop=59161;eSIMBusy=63006;TapAndSend=59809;HolePun"~
			"chPortraitBottom=62867;MobBatteryCharging10=60341;EmojiTabFavorites=60762;Dial7=61772;BandBattery3=60604;QWERTYOn=59778;MusicAlb"~
			"um=59708;CheckboxIndeterminateCombo14=61805;Wifi=59137;WifiError0=60250;StatusSGLTECell=59527;Set=62957;VerticalBatteryCharging0"~
			"=62973;ResizeTouchSmaller=59202;MobSignal1=60471;Like=59617;Battery10=59455;DuplexLandscapeTwoSidedShortEdgeMirrored=62851;Flick"~
			"Down=59701;MapDirections=59414;DuplexPortraitTwoSidedLongEdge=62854;Tag=59628;CopyTo=62483;TabletSelected=60532;ResizeMouseMediu"~
			"m=59204;MobWifi2=60477;Devices2=59765;DuplexLandscapeTwoSidedLongEdge=62848;PageLeft=59232;NUIFPStartSlideHand=60290;FullScreen="~
			"59200;Lexicon=61824;NewWindow=59275;BumperRight=61709;SendMirrored=60003;Speakers=59381;Tablet=59146;MobeSIMBusy=60717;Accident="~
			"59423;ClippingTool=62470;StatusPause7=61813;StatusDualSIM1VPN=59525;CheckboxComposite=59194;Frigid=59850;DictionaryCloud=60355;L"~
			"ockScreenGlance=61029;Website=60225;TouchPointer=59337;ChinesePinyin=59786;StrokeErase2=61736;MailReplyAll=59586;TwoPage=59546;M"~
			"obBatteryCharging9=60340;Characters=59585;CalendarWeek=59584;Click=59568;MyNetwork=60455;ExpandTileMirrored=59982;StatusCheckmar"~
			"kLeft=61913;VerticalBattery6=62968;MobBatterySaver4=60346;DefenderApp=59453;Dpad=61710;Dictionary=59437;ExportMirrored=60898;Ren"~
			"ame=59564;TriggerRight=61707;DMC=59729;EraseTool=59228;ChromeRestoreContrast=61231;StatusVPN=59529;CalendarMirrored=60712;Constr"~
			"uctionCone=59791;eSIMLocked=63005;CallForwardRoamingMirrored=59972;Cafe=60466;Record=59336;ReturnKeySm=59750;Construction=59426;"~
			"MailForwardMirrored=59990;ParkingLocationSolid=60043;BatteryCharging1=59483;HWPNewLine=62565;QuarentinedItems=61618;AddTo=60616;"~
			"WifiWarning0=60255;MobSignal2=60472;PenTips=62558;MusicSharing=63011;SpatialVolume2=61677;BatterySaver4=59495;NUIFace=60264;Bull"~
			"etedList=59645;Favicon=59191;MusicInfo=59659;MobBattery7=60327;SearchAndApps=59251;StatusCheckmark=61912;LangJPN=59358;StatusCir"~
			"cleBlock2=61761;DrawSolid=60552;QuarterStarLeft=61642;Key12On=59776;PageMarginLandscapeNarrow=62839;Remove=59192;Add=59152;Comma"~
			"ndPrompt=59222;PenTipsMirrored=62559;Safe=62784;Walk=59397;OutlineStarLeftHalf=61687;Warning=59322;Earbud=62656;PageMirrored=628"~
			"30;ClearSelectionMirrored=59976;DuplexPortraitOneSided=62852;PenWorkspace=60870;JpnRomanjiLock=59517;ChromeSwitchContast=61900;M"~
			"obWifi3=60478;InkingTool=59245;MediaStorageTower=59749;Ferry=59363;Switch=59563;SpeedOff=60488;LeaveChat=59547;ContactInfoMirror"~
			"ed=59978;PPSOneLandscape=62858;Delete=59213;SignatureCapture=61247;DynamicLock=62521;RotateCamera=59550;InkingToolFill=59535;Cer"~
			"tificate=60309;ArrowDown8=61614;HalfDullSound=59824;Airplane=59145;MobBattery8=60328;StatusCircleOuter=61750;MobBatteryCharging4"~
			"=60335;CheckboxCompositeReversed=59197;SpatialVolume1=61676;ResizeMouseLarge=59207;StreamingEnterprise=60719;VerticalBattery4=62"~
			"966;Export=60897;WifiError1=60251;Video=59156;Devices3=60012;CellPhone=59626;MailFill=59560;eSIM=63003;Battery0=59472;BatteryCha"~
			"rging0=59482;Movies=59570;OpenFolderHorizontal=60709;ZoomIn=59555;HolePunchOff=62863;CalculatorBackspace=59727;LineDisplay=61245"~
			";HeadlessDevice=61841;StatusErrorFull=60304;CalculatorPercentage=59724;CaretRightSolid8=60890;VerticalBatteryCharging3=62976;Tra"~
			"fficCongestionSolid=61795;Touchpad=61349;MobSIMLock=59509;SurfaceHub=59566;Microphone=59168;BatterySaver0=59491;ScrollUpDown=605"~
			"59;MicError=60502;SIPRedock=59227;NetworkTower=60421;SetTile=59771;HWPStrikeThrough=62562;Info2=59935;OutlineQuarterStarLeft=616"~
			"69;BandBattery4=60605;IBeamOutline=59700;Equalizer=59881;RightArrowKeyTime2=59463;Component=59728;Page=59331;GroupList=61800;Bat"~
			"teryCharging4=59486;LanguageKor=59531;NewFolder=59636;MicOn=60529;MailReplyMirrored=59991;ZoomOut=59167;NarratorForward=60841;Ri"~
			"ghtArrowKeyTime1=59462;BarcodeScanner=60506;FlickUp=59702;SurfaceHubSelected=62654;RotationLock=59221;DeviceLaptopNoPic=59384;Ch"~
			"evronUp=59150;TreeFolderFolderOpen=60739;Relationship=61443;CalculatorDivide=59722;StatusCheckmark7=61623;WindowsInsider=61869;G"~
			"oMirrored=59983;MobBatteryCharging1=60332;SwitchApps=59641;Battery4=59476;QuietHours=59144;BatterySaver8=59499;Robot=59802;PageM"~
			"arginLandscapeNormal=62840;StaplingPortraitTwoLeft=62876;NetworkConnected=62341;StatusInfoLeft=62413;GlobalNavigationButton=5913"~
			"6;ForwardMirrored=61651;SetSolid=62958;PanMode=60649;UpdateRestore=59255;MobActionCenter=60482;Draw=60551;MiracastLogoLarge=6043"~
			"8;PrintAllPages=62833;WifiCall2=60375;NoiseCancelationOff=63008;TabletMode=60412;FullHiragana=59782;Devices=59250;SIMMissing=630"~
			"01;VerticalBattery5=62967;SaveAs=59282;AddSurfaceHub=60612;CashDrawer=60505;ShowResults=59580;Heart=60241;Swipe=59687;NetworkPri"~
			"nter=60837;SendFill=59173;Previous=59538;Design=60220;ResizeMouseMediumMirrored=59999;BatteryCharging3=59485;BackSpaceQWERTYMd=5"~
			"9686;Street=59667;Bank=59429;Light=59283;RedEye=59315;VerticalBatteryCharging4=62977;Apps=60725;CaretDownSolid8=60892;XboxOneCon"~
			"sole=59792;NUIFPRollLeftHand=60296;ImportAllMirrored=59987;StatusUnsecure=60249;HardDrive=60834;ThoughtBubble=60049;StatusTriang"~
			"leLeft=60414;Wifi1=59506;ButtonMenu=60899;DuplexLandscapeTwoSidedLongEdgeMirrored=62849;ChevronUpSmall=59757;BuildingEnergy=6042"~
			"7;CompletedSolid=60513;ShoppingCart=59327;DevUpdate=60613;Back=59179;PPSTwoPortrait=62860;DetachablePC=61699;Bold=59613;Multimed"~
			"iaDVR=59732;KeyboardOneHanded=60748;MoveToFolder=59614;GotoToday=59601;Preview=59647;USBSafeConnect=60659;Dock=59730;MobBatteryS"~
			"aver2=60344;StaplingLandscapeBookBinding=62889;MobWifi4=60479;Copy=59592;ButtonB=61588;SmartcardVirtual=59748;MobBatterySaver9=6"~
			"0351;Asterisk=59960;VerticalBatteryCharging2=62975;OpenPane=59552;StaplingPortraitBookBinding=62880;ChromeBack=59440;InfoSolid=6"~
			"1799;Devices4=60262;WifiHotspot=59530;Sustainable=60426;KeyboardBrightness=60729;HolePunchPortraitLeft=62864;HomeGroup=60454;Und"~
			"o=59303;ContactSolid=60044;OtherUser=59374;StaplingLandscapeTopRight=62882;LockFeedback=60379;ReplyMirrored=60981;Dislike=59616;"~
			"HomeSolid=60042;BatteryCharging10=60051;LandscapeOrientation=61291;TrafficLight=61233;DullSoundKey=59823;ReadingList=59324;Spati"~
			"alVolume0=61675;WifiEthernet=61047;ChevronDownMed=59762;Webcam=59576;ResetDrive=60356;DuplexLandscapeOneSided=62846;HolePunchLan"~
			"dscapeLeft=62868;MapCompassTop=59410;MobBatteryUnknown=60418;NetworkSharing=61843;SwitchUser=59208;ResizeTouchShorter=59371;TVMo"~
			"nitor=59380;GameConsole=59751;CallForwardRoaming=59515;ShowBcc=59588;StatusTriangleExclamation=61755;PresenceChicklet=59768;Remo"~
			"te=59567;Dial16=61781;Media=60009;ProtectedDocument=59558;ReceiptPrinter=60507;StatusCircleLeft=60413;Unfavorite=59609;ShowResul"~
			"tsMirrored=60005;Label=59698;CalendarSolid=60041;BackSpaceQWERTY=59216;Mouse=59746;TaskbarPhone=61028;ChromeFullScreenContrast=6"~
			"1656;ChromeFullScreen=59693;DialUp=59452;ResizeMouseTall=59206;Pause=59241;Rotate=59309;RepeatAll=59630;Narrator=60749;ParkingLo"~
			"cationMirrored=59998;StaplingPortraitBottomRight=62875;Health=59742;BatteryCharging2=59484;BatterySaver9=60052;ChromeBackToWindo"~
			"wContrast=61655;TreeFolderFolderFill=60738;IOT=61996;SyncFolder=59639;HalfKatakana=59784;LaptopSelected=60534;SyncBadge12=60843;"~
			"FontDecrease=59623;CaretUpSolid8=60891;ChatBubbles=59634;Cancel=59153;Megaphone=59273;PersonalFolder=60453;StreetsideSplitMinimi"~
			"ze=59394;BatteryCharging5=59487;EmojiTabCelebrationObjects=60757;Badge=60443;KeyboardDock=62059;ClearAllInk=60770;StatusCircle7="~
			"61622;Photo2=60319;ButtonA=61587;BidiRtl=59819;MobBatteryCharging5=60336;FreeFormClipping=62472;Video360=61745;StockUp=60177;Bid"~
			"iLtr=59818;DateTimeMirrored=61075;NUIFPPressRepeatHand=60300;Process=59891;MobBatterySaver8=60350;Reminder=60240;DuplexPortraitT"~
			"woSidedShortEdgeMirrored=62857;QuarentinedItemsMirrored=61619;LeftStick=61704;Dial15=61780;StorageTape=59754;VerticalBattery3=62"~
			"965;CalculatorEqualTo=59726;BatterySaver3=59494;ViewAll=59561;OneBar=59653;Courthouse=60424;PostUpdate=59635;LEDLight=59265;Coll"~
			"ateLandscape=62843;GripperBarHorizontal=59247;HalfStarLeft=59334;PointEraseMirrored=61208;StatusDualSIM1=59524;StatusCircleInner"~
			"=61751;LeftQuote=59464;ArrowRight8=61615;Family=60378;WifiError4=60254;OpenPaneMirrored=59995;ChromeClose=59579;LeftArrowKeyTime"~
			"0=60498;Drop=60226;Dial11=61776;Car=59396;MicClipping=60530;NUIIris=60263;Webcam2=59744;ChevronLeft=59243;VPN=59141;StartPointSo"~
			"lid=60233;StatusWarning=60036;SIMError=63000;LaptopSecure=62802;MobBatterySaver10=60352;RadioBtnOff=60618;KnowledgeArticle=61440"~
			";MobBatterySaver3=60345;Upload=59544;MobBattery10=60330;WifiCall0=60373;EmojiTabFoodPlants=60758;NetworkOffline=62340;Message=59"~
			"581;StaplingPortraitBottomLeft=62894;ContactInfo=59257;ImportAll=59574;SaveLocal=59276;StaplingPortraitTwoTop=62878;DullSound=59"~
			"665;PC1=59767;StatusConnecting1=60247;Play36=61002;ArrowUp8=61613;StatusCircleInfo=61759;EditMirrored=60286;OutlineHalfStarLeft="~
			"61671;HolePunchLandscapeBottom=62871;SliderThumb=60435;MicrophoneListening=61742;VerticalBatteryCharging5=62978;Shuffle=59569;Ba"~
			"ndBattery6=60607;NearbySharing=62434;Stopwatch=59670;RevToggleKey=59461;Accounts=59664;WifiError3=60253;MobeSIMLocked=60716;Chro"~
			"meAnnotate=59697;OpenLocal=59610;OpenInNewWindow=59559;LanguageChs=59533;Subtitles=60702;DataSenseBar=59301;PlaybackRateOther=60"~
			"504;KeyboardRightHanded=59236;InteractiveDashboard=62468;VolumeBars=60357;ActionCenterQuiet=61049;LargeErase=61738;Cloud=59219;B"~
			"attery9=59481;Comment=59658;Italic=59611;BatteryCharging9=59454;PuncKey4=59831;DockRightMirrored=59979;TwoBars=59654;CalendarDay"~
			"=59583;PPSFourLandscape=62861;Memo=59260;FontColor=59603;MobBatteryCharging2=60333;TimeLanguage=59253;KeyboardShortcut=60839;TVM"~
			"onitorSelected=60535;CircleRingBadge12=60847;PaginationDotSolid10=61735;PlayBadge12=60853;HorizontalTabKey=59389;MultimediaPMP=5"~
			"9733;DuplexPortraitTwoSidedLongEdgeMirrored=62855;DashKey=59822;HWPOverwrite=62566;LikeDislike=59615;BookmarksMirrored=59969;Rot"~
			"ateMapLeft=59405;PointErase=60769;KeyboardDismiss=59695;Projector=59741;CaretRight8=60886;NetworkConnectedCheckmark=62342;ListMi"~
			"rrored=59989;PLAP=60441;StockDown=60175;MultimediaDMS=59731;Error=59267;Home=59407;ToggleThumb=60436;Sync=59541;CC=59376;Insider"~
			"HubApp=60452;Dial2=61767;KeyboardLeftAligned=61964;PresenceChickletVideo=59769;Marker=60772;Network=59752;BatterySaver6=59497;Mo"~
			"bBattery2=60322;ClipboardListMirrored=61668;StatusSGLTEDataVPN=59528;PuncKey3=59830;ChineseChangjie=59777;HalfAlpha=59774;Batter"~
			"yCharging8=59490;PencilFill=61638;MobileSelected=60533;ChevronRightSmall=59760;DockLeftMirrored=59980;LockscreenDesktop=60991;Si"~
			"gnalBars5=59504;MobWifiWarning1=62579;SendFillMirrored=60004;Touchscreen=60836;DictionaryAdd=59438;Priority=59600;PuncKey=59460;"~
			"Japanese=59781;Cut=59590;WalkSolid=59174;HoloLensSelected=62655;SkipBack10=60732;DownloadMap=59430;HighlightFill2=59434;MobBatte"~
			"ryCharging3=60334;More=59154;MobileLocked=60448;Protractor=61620;EmojiTabTransitPlaces=60759;GripperResize=59272;Send=59172;Info"~
			"=59718;ErrorBadge12=60846;CallForwardInternational=59514;PinFill=59457;SettingsDisplaySound=59379;Save=59214;SelectAll=59571;Key"~
			"boardSplit=59238;MixVolumes=62659;Clear=59540;RightStick=61705;Emoji=59545;OEM=59212;MobCallForwarding=60542;ChromeSwitch=61899;"~
			"MobWifiWarning4=62582;Volume2=59796;Pin=59160;Calendar=59271;ThreeQuarterStarLeft=61644;Work=59425;SIPUndock=59226;HWPJoin=62560"~
			";Bullseye=62066;ClipboardList=61667;RoamingDomestic=59513;OutlineThreeQuarterStarLeft=61673;UnknownMirrored=61998;SignalNotConne"~
			"cted=59505;FeedbackApp=59705;Dial9=61774;OpenWith=59308;BatterySaver1=59492;WifiWarning3=60258;EthernetWarning=60246;Smartcard=5"~
			"9747;MailForward=59548;StatusDataTransferVPN=59521;USB=59534;SaveCopy=59957;MiracastLogoSmall=60437;ThreeBars=59655;BatterySaver"~
			"7=59498;Next=59539;KeyboardLowerBrightness=60730;ButtonX=61590;ChineseBoPoMoFo=59785;EraseToolFill=59435;PenPalette=61014;Headph"~
			"one=59382;BandBattery1=60602;VerticalBattery10=62972;OutlineThreeQuarterStarRight=61674;CtrlSpatialRight=61723;BatteryUnknown=59"~
			"798;Radar=60228;Group=59650;ResizeTouchLarger=59201;HeartFill=60242;CalculatorNegate=59725;SDCard=59377;HMD=61721;QuickNote=5914"~
			"7;FerrySolid=60232;Battery3=59475;MobBatterySaver0=60342;AllApps=59165;MobLocation=60483;Battery1=59473;Feedback=60693;Companion"~
			"App=60516;MobBatteryCharging0=60331;MobBattery1=60321;Wheel=61076;Redo=59302;Checkbox=59193;CircleFill=59963;BackgroundToggle=61"~
			"215;StatusInfo=62412;StatusErrorLeft=60415;ParkingLocation=59409;StatusCircleQuestionMark=61762;Admin=59375;EmojiSwatch=60763;Do"~
			"wnload=59542;HolePunchLandscapeRight=62869;DownShiftKey=59466;HolePunchPortraitTop=62866;RightArrowKeyTime3=59470;BulletedListMi"~
			"rrored=59970;Import=59573;StopPointSolid=60234;NUIFPRollLeftAction=60297;VideoSolid=59916;MobBattery9=60329;CalculatorAddition=5"~
			"9720;MagStripeReader=60508;PuncKey5=59832;VerticalBatteryUnknown=62984;Processing=59893;MailBadge12=60851;EaseOfAccess=59254;Dev"~
			"iceMonitorRightPic=59385;NUIFPRollRightHandAction=60295;Camera=59170;DeveloperTools=60538;NUIFPPressHand=60298;Brightness=59142;"~
			"ChevronRight=59244;PinnedFill=59458;Filter=59164;System=59248;ImageExport=61041;Contact=59259;StatusTriangle=60034;MobBatteryCha"~
			"rging8=60339;RightArrowKeyTime4=59471;FingerInking=60767;MobeSIM=60714;OpenFile=59621;KeyboardLeftHanded=59235;StaplingLandscape"~
			"TwoBottom=62888;StreetsideSplitExpand=59395;DuplexLandscapeOneSidedMirrored=62847;PeriodKey=59459;ConnectApp=60764;Beta=59940;Fo"~
			"lder=59575;LeaveChatMirrored=59988;ChromeBackMirrored=59975;LanguageCht=59532;Replay=61243;DuplexPortraitTwoSidedShortEdge=62856"~
			";OutlineStarRightHalf=61688;Communications=59738;VerticalBatteryCharging6=62979;CheckboxIndeterminateCombo=61806;ButtonY=61589;A"~
			"lignRight=59618;ChromeRestore=59683;StorageNetworkWireless=59753;Color=59280;MobBatterySaver1=60343;Help=59543;PPSFourPortrait=6"~
			"2862;FontIncrease=59624;CallForwardingMirrored=60055;StaplingPortraitTopLeft=62873;EmojiTabTextSmiles=60761;Battery2=59474;Trigg"~
			"erLeft=61706;StaplingOff=62872;Calculator=59631;Trackers=60127;ChevronUpMed=59761;Rewind=60318;SignalRoaming=60446;PINPad=61246;"~
			"BandBattery0=60601;Dial12=61777;PointerHand=62065;Highlight=59366;PasswordKeyShow=59816;StaplingLandscapeTopLeft=62881;Diagnosti"~
			"c=59865;Wifi3=59508;ClearAllInkMirrored=61209;Checkbox14=61803;PinyinIMELogo=60901;MobWifiWarning3=62581;StatusCircleExclamation"~
			"=61756;Eyedropper=61244;PageMarginLandscapeWide=62842;RectangularClipping=62471;SettingsBattery=61027;Dial13=61778;Leaf=59582;Fi"~
			"tPage=59814;ColorOff=62832;RememberedDevice=59148;CaretLeftSolid8=60889;SubtitlesAudio=60703;PlaybackRate1x=60503;Printer3D=5966"~
			"8;FullCircleMask=59679;TaskViewExpanded=60305;CheckboxFill=59195;MobBattery0=60320;Dial4=61769;AreaChart=59858;BatterySaver10=60"~
			"053;Unlock=59269;ZoomMode=60648;PuncKeyRightBottom=59827;Headphone2=60722;VerticalBattery9=62971;Touch=59413;Volume3=59797;Audio"~
			"=59606;StatusTriangleInner=61754;Dial8=61773;PageMarginLandscapeModerate=62841;OutlineQuarterStarRight=61670;GuestUser=61015;Cal"~
			"culatorSubtract=59721;BatteryCharging7=59489;ClearSelection=59622;Personalize=59249;World=59657;PassiveAuthentication=62250;Sign"~
			"alBars4=59503;EthernetError=60245;PaginationDotOutline10=61734;HighlightFill=59537;ChromeBackContrast=61653;ActionCenterAsterisk"~
			"=59937;Puzzle=60038;MobBattery4=60324;PuncKey2=59829;Play=59240;Settings=59155;StatusExclamationCircle7=61743;HolePunchLandscape"~
			"Top=62870;Completed=59696;MobeSIMNoProfile=60715;Dial3=61768;ActionCenterMirrored=60685;KeyboardFull=60465;WifiWarning4=60259;So"~
			"rt=59595;StatusCircle=60033;ScrollMode=60647;WorkSolid=60238;SIMLock=63002;AccidentSolid=60046;Library=59633;PageMarginPortraitM"~
			"oderate=62837;Emoji2=59246;PartyLeader=60583;CompanionDeviceFramework=60765;CommaKey=59821;PhoneBook=59264;HeartBroken=60050;Sta"~
			"plingLandscapeTwoTop=62887;MobBatterySaver6=60348;MobSignal4=60474;HalfStarRight=59335;KeyboardSettings=61968;BlueLight=61580;Si"~
			"gnalBars3=59502;ProvisioningPackage=59445;PuncKey9=59834;Bug=60392;NoiseCancelation=63007;StaplingPortraitTopRight=62874;UserAPN"~
			"=61569;RingerBadge12=60844;HideBcc=59589;FastForward=60317;CircleRing=59962;BackSpaceQWERTYSm=59685;IncidentTriangle=59412;Direc"~
			"tions=59632;Mute=59215;Accept=59643;UpArrowShiftKey=59218;NUIFPPressAction=60299;UpShiftKey=59467;StaplingLandscapeBottomRight=6"~
			"2884;PageMarginPortraitWide=62838;SlowMotionOn=60025;FlickLeft=59703;InkingCaret=60773;CollatePortraitSeparated=62845;PageMargin"~
			"PortraitNormal=62836;ReportDocument=59897;SkipForward30=60733;Slideshow=59270;CloudSeach=60900;BodyCam=60544;Orientation=59572;R"~
			"esizeMouseSmall=59203;ChevronDown=59149;WindDirection=60390;StatusDataTransfer=59520;ThreeQuarterStarRight=61645;Battery8=59480;"~
			"DisconnectDisplay=59924;LowerBrightness=60554;MobSIMMissing=59510;Project=60358;PlayerSettings=61272;Flag=59329;MapPin2=59319;Pa"~
			"geRight=59233;EmojiTabSymbols=60760;FolderFill=59605;DialShape3=61784;StaplingPortraitTwoRight=62877;MapDrive=59598;RightDoubleQ"~
			"uote=59825;BackToWindow=59199;Sticker2=62634;RotateMapRight=59404;FullKatakana=59783;VerticalBatteryCharging7=62980;ZeroBars=596"~
			"52;PrintfaxPrinterFile=59734;NUIFPContinueSlideAction=60293;ImportantBadge12=60849;Education=59326;ActionCenterNotificationMirro"~
			"red=60684;ButtonView2=61130;NUIFPRollRightHand=60294;CheckboxComposite14=61804;Scan=59646;VerticalBattery0=62962;CheckMark=59198"~
			";Calories=60589;Volume0=59794;SpeedMedium=60489;ExploitProtectionSettings=62041;MobWifiHotspot=60484;Bookmarks=59556;HelpMirrore"~
			"d=59985;GIF=62633;ChipCardCreditCardReader=61248;MapLayers=59422;FourBars=59656;Handwriting=59689;ClosePane=59551;Go=59565;PageS"~
			"olid=59177;PuncKey6=59833;BackMirrored=61650;Dial14=61779;PrintCustomRange=62834;CollatePortrait=62844;FolderOpen=59448;Ruler=60"~
			"766;Picture=59577;Ear=62064;ResetDevice=60688;VerticalBatteryCharging10=62983;GiftboxOpen=61747;MicSleep=60501;Refresh=59180;Wir"~
			"edUSB=60656;StatusConnecting2=60248;CloudPrinter=60838;ChromeMaximize=59682;MultiSelect=59234;ChevronDownSmall=59758;LeftDoubleQ"~
			"uote=59826;CtrlSpatialLeft=62439;MobSignal5=60475;Headphone0=60720;BatteryCharging6=59488;RadioBullet=59669;WirelessUSB=60657;Pa"~
			"ste=59263;Game=59388;KeyboardUndock=62060;Headphone3=60723;KeyboardRightDock=62062;AsteriskBadge12=60845;GridView=61666;Speech=6"~
			"1353;InkingToolFill2=59433;StatusSGLTE=59526;PasswordKeyHide=59817;MailReplyAllMirrored=59992;OpenWithMirrored=59996;StaplingLan"~
			"dscapeTwoLeft=62885;Font=59602;KeyboardStandard=59694;StatusCircleBlock=61760;ExpandTile=59766;CheckboxIndeterminate=59196;MobBa"~
			"ttery3=60323;NetworkAdapter=60835;ChromeCloseContrast=61228;TiltUp=59401;DefaultAPN=61568;DialShape4=61785;Vibrate=59511;ChromeB"~
			"ackToWindow=59692;ChineseQuick=59780;StatusWarningLeft=60416;TrackersMirrored=61074;MobDrivingMode=60487;VerticalBatteryCharging"~
			"8=62981;ReturnKeyLg=60311;ReportHacked=59184;RemoveFrom=60617;Train=59328;DialShape2=61783;GripperTool=59230;Recent=59427;PlaySo"~
			"lid=62896;List=59959;VerticalBattery1=62963;Bus=59398;FavoriteStarFill=59189;MobBatteryCharging7=60338;Link=59163;HWPInsert=6256"~
			"1;Marquee=61216;StaplingLandscapeBottomLeft=62883;Mail=59157;StorageOptical=59736;QuarterStarRight=61643;PuncKey8=59836;MobQuiet"~
			"Hours=60486;Important=59593;HangUp=59256;Battery6=59478;Battery7=59479;Document=59557;StatusCircleSync=61763;SwipeRevealArt=6052"~
			"5;ConstructionSolid=60045;CalligraphyFill=61639;PauseBadge12=60852;VerticalBattery2=62964;PPSOnePortrait=62893;CharacterAppearan"~
			"ce=61823;SignalBars2=59501;PuncKey7=59835;StaplingPortraitTwoBottom=62879;ToolTip=59439;QWERTYOff=59779;DisconnectDrive=59597;Fl"~
			"ashlight=59220;Crop=59304;WifiAttentionOverlay=59800;MobAirplane=60480;StatusDualSIM2VPN=59523;DockRight=59661;ChromeMaximizeCon"~
			"trast=61230;Dial10=61775;EnglishPunctuation=61712;ActionCenterQuietNotification=61050;RadioBullet2=60620;JpnRomanjiShiftLock=595"~
			"19;MobWifiWarning2=62580;Fingerprint=59688;EmojiTabSmilesAnimals=60756;Up=59210;ScreenTime=61826;ShareBroadband=59450;BlockConta"~
			"ct=59640;CircleFillBadge12=60848;EmojiTabPeople=60755;ViewDashboard=62022;MultiSelectMirrored=60056;ChevronLeftMed=59763;StrokeE"~
			"rase=60768;MultimediaDMP=60743;KeyboardClassic=59237;EraseToolFill2=59436;ClosePaneMirrored=59977;VideoChat=59562;DockBottom=596"~
			"62;Unknown=59854;DuplexPortraitOneSidedMirrored=62853;AspectRatio=59289;CallForwardInternationalMirrored=59971;Shield=59928;MobC"~
			"allForwardingMirrored=60543;MobBluetooth=60481;EndPointSolid=60235;DeviceMonitorNoPic=59387;Dial1=61766;SignalError=60718;Forwar"~
			"dSm=59820;ContactPresence=59599;BackSpaceQWERTYLg=60310;FavoriteList=59176;Ringer=60047;VerticalBatteryCharging9=62982;RadioBtnO"~
			"n=60619;Pencil=60771;HWPSplit=62564;Contact2=59604;FullAlpha=59775;DialShape1=61782;InPrivate=59175;StartPoint=59417;Headphone1="~
			"60721;Phone=59159;WifiWarning1=60256"; 
		
		shared static dchar[string] table; 
		if(table is null) {
			foreach(s; tableData.split(';')) {
				auto p = s.split('='); 
				table[p[0]] = (p[1].to!int).to!dchar; 
			}
			table.rehash; 
		}
		
		//get by dec or hex code
		if(name.length && name[0].inRange('0', '9')) return name.toInt.to!dchar; 
		
		auto a = name in table; 
		return a ? *a : '\uFFFD'; 
	} 
	
	/*
		void importSegoeSymbols(){
			wchar[string] segoeSymbols;
		
			foreach(s; File(`c:\dl\segoe_assets.txt`).readLines){
				auto p = s.split('\t');
				if(p.length>=2){
					segoeSymbols[p[0].strip] = p[1].to!int(16).to!wchar;
				}
			}
		
			segoeSymbols.rehash;
		
			segoeSymbols.byKeyValue.map!(kv => "%s=%s".format(kv.key, kv.value.to!int)).join(';').chunks(128).map!(s=>`"`~s.text~`"~`).join("\r\n").saveTo(File(`c:\dl\a.txt`));
		
			readln;
			application.exit;
		}
	*/
	
	shared static this()
	{
		bitmapLoaders.registerMarkedFunctions!(mixin(__MODULE__)); 
		bitmapEffects.registerMarkedFunctions!(mixin(__MODULE__)); 
	} 
}version(all)
extern (C)
{
	
	
	enum WEBP_DECODER_ABI_VERSION = 0x0209; 
	enum WEBP_ENCODER_ABI_VERSION = 0x020f; 
	
	/+
		Note: Extracted with:
			/+
			Code: copy types.h + decode.h + encode.h webp_d_header.c
			ldc2 webp_d_header.c -Hc -o-
		+/
		
		Manual modifications:
			- remove ImportC header
			- remove /+Code:  = void+/
			- fix an union
			- fix an identifier called /+Code: ref+/
			- bring all the static functions
			- bring two initialization functions passing ABI versions
		
		250626: it works now. /+Todo: after a longer test period, remove the old headers.+/
	+/
	/+
		alias __uint16_t = ushort; 
		alias __uint32_t = uint; 
		alias __uint64_t = ulong; 
		align alias uintptr_t = ulong; 
		align alias va_list = char*; 
		align void __va_start(char**, ...); 
		alias size_t = ulong; 
		alias ptrdiff_t = long; 
		alias intptr_t = long; 
		alias __vcrt_bool = bool; 
		alias wchar_t = ushort; 
		void __security_init_cookie(); 
		void __security_check_cookie(ulong _StackCookie); 
		void __report_gsfailure(ulong _StackCookie); 
		extern __gshared ulong __security_cookie; 
		alias __crt_bool = bool; 
		void _invalid_parameter_noinfo(); 
		void _invalid_parameter_noinfo_noreturn(); 
		void _invoke_watson(
			const(ushort)* _Expression, const(ushort)* _FunctionName, 
			const(ushort)* _FileName, uint _LineNo, ulong _Reserved
		); 
		alias errno_t = int; 
		alias wint_t = ushort; 
		alias wctype_t = ushort; 
		alias __time32_t = int; 
		alias __time64_t = long; 
		struct __crt_locale_data_public
		{
			const(ushort)* _locale_pctype; 
			int _locale_mb_cur_max; 
			uint _locale_lc_codepage; 
		} 
		struct __crt_locale_pointers
		{
			__crt_locale_data* locinfo; 
			__crt_multibyte_data* mbcinfo; 
		} 
		alias _locale_t = __crt_locale_pointers*; 
		struct _Mbstatet
		{
			uint _Wchar; 
			ushort _Byte; 
			ushort _State; 
		} 
		struct _Mbstatet; 
		alias mbstate_t = _Mbstatet; 
		alias time_t = long; 
		alias rsize_t = ulong; 
		int* _errno(); 
		int _set_errno(int _Value); 
		int _get_errno(int* _Value); 
		extern uint __threadid(); 
		extern ulong __threadhandle(); 
		alias int8_t = byte; 
		alias uint8_t = ubyte; 
		alias int16_t = short; 
		alias uint16_t = ushort; 
		alias int32_t = int; 
		alias uint32_t = uint; 
		alias uint64_t = ulong; 
		alias int64_t = long; 
	+/
	extern void* WebPMalloc(ulong size); 
	extern void WebPFree(void* ptr); 
	extern int WebPGetDecoderVersion(); 
	extern int WebPGetInfo(const(ubyte)* data, ulong data_size, int* width, int* height); 
	extern ubyte* WebPDecodeRGBA(const(ubyte)* data, ulong data_size, int* width, int* height); 
	extern ubyte* WebPDecodeARGB(const(ubyte)* data, ulong data_size, int* width, int* height); 
	extern ubyte* WebPDecodeBGRA(const(ubyte)* data, ulong data_size, int* width, int* height); 
	extern ubyte* WebPDecodeRGB(const(ubyte)* data, ulong data_size, int* width, int* height); 
	extern ubyte* WebPDecodeBGR(const(ubyte)* data, ulong data_size, int* width, int* height); 
	extern ubyte* WebPDecodeYUV(
		const(ubyte)* data, ulong data_size, int* width, int* height, 
		ubyte** u, ubyte** v, int* stride, int* uv_stride
	); 
	extern ubyte* WebPDecodeRGBAInto(
		const(ubyte)* data, ulong data_size, ubyte* output_buffer, 
		ulong output_buffer_size, int output_stride
	); 
	extern ubyte* WebPDecodeARGBInto(
		const(ubyte)* data, ulong data_size, ubyte* output_buffer, 
		ulong output_buffer_size, int output_stride
	); 
	extern ubyte* WebPDecodeBGRAInto(
		const(ubyte)* data, ulong data_size, ubyte* output_buffer, 
		ulong output_buffer_size, int output_stride
	); 
	extern ubyte* WebPDecodeRGBInto(
		const(ubyte)* data, ulong data_size, ubyte* output_buffer, 
		ulong output_buffer_size, int output_stride
	); 
	extern ubyte* WebPDecodeBGRInto(
		const(ubyte)* data, ulong data_size, ubyte* output_buffer, 
		ulong output_buffer_size, int output_stride
	); 
	extern ubyte* WebPDecodeYUVInto(
		const(ubyte)* data, ulong data_size, ubyte* luma, 
		ulong luma_size, int luma_stride, ubyte* u, ulong u_size, 
		int u_stride, ubyte* v, ulong v_size, int v_stride
	); 
	enum WEBP_CSP_MODE
	{
		MODE_RGB = 0,
		MODE_RGBA = 1,
		MODE_BGR = 2,
		MODE_BGRA = 3,
		MODE_ARGB = 4,
		MODE_RGBA_4444 = 5,
		MODE_RGB_565 = 6,
		MODE_rgbA = 7,
		MODE_bgrA = 8,
		MODE_Argb = 9,
		MODE_rgbA_4444 = 10,
		MODE_YUV = 11,
		MODE_YUVA = 12,
		MODE_LAST = 13,
	} 
	alias MODE_RGB = WEBP_CSP_MODE.MODE_RGB; 
	alias MODE_RGBA = WEBP_CSP_MODE.MODE_RGBA; 
	alias MODE_BGR = WEBP_CSP_MODE.MODE_BGR; 
	alias MODE_BGRA = WEBP_CSP_MODE.MODE_BGRA; 
	alias MODE_ARGB = WEBP_CSP_MODE.MODE_ARGB; 
	alias MODE_RGBA_4444 = WEBP_CSP_MODE.MODE_RGBA_4444; 
	alias MODE_RGB_565 = WEBP_CSP_MODE.MODE_RGB_565; 
	alias MODE_rgbA = WEBP_CSP_MODE.MODE_rgbA; 
	alias MODE_bgrA = WEBP_CSP_MODE.MODE_bgrA; 
	alias MODE_Argb = WEBP_CSP_MODE.MODE_Argb; 
	alias MODE_rgbA_4444 = WEBP_CSP_MODE.MODE_rgbA_4444; 
	alias MODE_YUV = WEBP_CSP_MODE.MODE_YUV; 
	alias MODE_YUVA = WEBP_CSP_MODE.MODE_YUVA; 
	alias MODE_LAST = WEBP_CSP_MODE.MODE_LAST; 
	//Some useful macros:
	static int WebPIsPremultipliedMode(WEBP_CSP_MODE mode)
	{
		return (
			mode == WEBP_CSP_MODE.MODE_rgbA || 
			mode == WEBP_CSP_MODE.MODE_bgrA || 
			mode == WEBP_CSP_MODE.MODE_Argb ||
			mode == WEBP_CSP_MODE.MODE_rgbA_4444
		); 
	} 
	
	static int WebPIsAlphaMode(WEBP_CSP_MODE mode)
	{
		return (
			mode == WEBP_CSP_MODE.MODE_RGBA || 
			mode == WEBP_CSP_MODE.MODE_BGRA || 
			mode == WEBP_CSP_MODE.MODE_ARGB ||
			mode == WEBP_CSP_MODE.MODE_RGBA_4444 || 
			mode == WEBP_CSP_MODE.MODE_YUVA ||
			WebPIsPremultipliedMode(mode)
		); 
	} 
	
	static int WebPIsRGBMode(WEBP_CSP_MODE mode)
	{ return (mode < WEBP_CSP_MODE.MODE_YUV); } 
	struct WebPRGBABuffer
	{
		ubyte* rgba; 
		int stride; 
		ulong size; 
	} 
	struct WebPYUVABuffer
	{
		ubyte* y; 
		ubyte* u; 
		ubyte* v; 
		ubyte* a; 
		int y_stride; 
		int u_stride; 
		int v_stride; 
		int a_stride; 
		ulong y_size; 
		ulong u_size; 
		ulong v_size; 
		ulong a_size; 
	} 
	struct WebPDecBuffer
	{
		WEBP_CSP_MODE colorspace; 
		int width; 
		int height; 
		int is_external_memory; 
		union 
		{
			WebPRGBABuffer RGBA; 
			WebPYUVABuffer YUVA; 
		} 
		uint[4] pad; 
		ubyte* private_memory; 
	} 
	extern int WebPInitDecBufferInternal(const WebPDecBuffer*, int); 
	static int WebPInitDecBuffer(WebPDecBuffer* buffer)
	{ return WebPInitDecBufferInternal(buffer, WEBP_DECODER_ABI_VERSION); } 
	extern void WebPFreeDecBuffer(const WebPDecBuffer* buffer); 
	enum VP8StatusCode
	{
		VP8_STATUS_OK = 0,
		VP8_STATUS_OUT_OF_MEMORY,
		VP8_STATUS_INVALID_PARAM,
		VP8_STATUS_BITSTREAM_ERROR,
		VP8_STATUS_UNSUPPORTED_FEATURE,
		VP8_STATUS_SUSPENDED,
		VP8_STATUS_USER_ABORT,
		VP8_STATUS_NOT_ENOUGH_DATA,
	} 
	alias VP8_STATUS_OK = VP8StatusCode.VP8_STATUS_OK; 
	alias VP8_STATUS_OUT_OF_MEMORY = VP8StatusCode.VP8_STATUS_OUT_OF_MEMORY; 
	alias VP8_STATUS_INVALID_PARAM = VP8StatusCode.VP8_STATUS_INVALID_PARAM; 
	alias VP8_STATUS_BITSTREAM_ERROR = VP8StatusCode.VP8_STATUS_BITSTREAM_ERROR; 
	alias VP8_STATUS_UNSUPPORTED_FEATURE = VP8StatusCode.VP8_STATUS_UNSUPPORTED_FEATURE; 
	alias VP8_STATUS_SUSPENDED = VP8StatusCode.VP8_STATUS_SUSPENDED; 
	alias VP8_STATUS_USER_ABORT = VP8StatusCode.VP8_STATUS_USER_ABORT; 
	alias VP8_STATUS_NOT_ENOUGH_DATA = VP8StatusCode.VP8_STATUS_NOT_ENOUGH_DATA; 
	alias WebPIDecoder = Typedef!(void*); 
	
	extern WebPIDecoder* WebPINewDecoder(const WebPDecBuffer* output_buffer); 
	extern WebPIDecoder* WebPINewRGB(
		WEBP_CSP_MODE csp, ubyte* output_buffer, 
		ulong output_buffer_size, int output_stride
	); 
	extern WebPIDecoder* WebPINewYUVA(
		ubyte* luma, ulong luma_size, int luma_stride, 
		ubyte* u, ulong u_size, int u_stride, ubyte* v, 
		ulong v_size, int v_stride, 
		ubyte* a, ulong a_size, int a_stride
	); 
	extern WebPIDecoder* WebPINewYUV(
		ubyte* luma, ulong luma_size, int luma_stride, 
		ubyte* u, ulong u_size, int u_stride, ubyte* v, 
		ulong v_size, int v_stride
	); 
	extern void WebPIDelete(const WebPIDecoder* idec); 
	extern VP8StatusCode WebPIAppend(const WebPIDecoder* idec, const(ubyte)* data, ulong data_size); 
	extern VP8StatusCode WebPIUpdate(const WebPIDecoder* idec, const(ubyte)* data, ulong data_size); 
	extern ubyte* WebPIDecGetRGB(const WebPIDecoder* idec, int* last_y, int* width, int* height, int* stride); 
	extern ubyte* WebPIDecGetYUVA(
		const WebPIDecoder* idec, int* last_y, ubyte** u, ubyte** v, 
		ubyte** a, int* width, int* height, int* stride, int* uv_stride, int* a_stride
	); 
	static ubyte* WebPIDecGetYUV(
		const WebPIDecoder* idec, int* last_y, ubyte** u, ubyte** v, 
		int* width, int* height, int* stride, int* uv_stride
	); 
	extern WebPDecBuffer* WebPIDecodedArea(
		const WebPIDecoder* idec, int* left, int* top, 
		int* width, int* height
	); 
	struct WebPBitstreamFeatures
	{
		int width; 
		int height; 
		int has_alpha; 
		int has_animation; 
		int format; 
		uint[5] pad; 
	} 
	extern VP8StatusCode WebPGetFeaturesInternal(const(ubyte)*, ulong, WebPBitstreamFeatures*, int); 
	static VP8StatusCode WebPGetFeatures(
		const ubyte* data, size_t data_size,
		WebPBitstreamFeatures* features
	)
	=> WebPGetFeaturesInternal(
		data, data_size, features,
		WEBP_DECODER_ABI_VERSION
	); 
	
	struct WebPDecoderOptions
	{
		int bypass_filtering; 
		int no_fancy_upsampling; 
		int use_cropping; 
		int crop_left; 
		int crop_top; 
		int crop_width; 
		int crop_height; 
		int use_scaling; 
		int scaled_width; 
		int scaled_height; 
		int use_threads; 
		int dithering_strength; 
		int flip; 
		int alpha_dithering_strength; 
		uint[5] pad; 
	} 
	struct WebPDecoderConfig
	{
		WebPBitstreamFeatures input; 
		const WebPDecBuffer output; 
		WebPDecoderOptions options; 
	} 
	extern int WebPInitDecoderConfigInternal(WebPDecoderConfig*, int); 
	
	static int WebPInitDecoderConfig(WebPDecoderConfig* config)
	=> WebPInitDecoderConfigInternal(config, WEBP_DECODER_ABI_VERSION); 
	
	extern WebPIDecoder* WebPIDecode(const(ubyte)* data, ulong data_size, WebPDecoderConfig* config); 
	extern VP8StatusCode WebPDecode(const(ubyte)* data, ulong data_size, WebPDecoderConfig* config); 
	extern int WebPGetEncoderVersion(); 
	extern ulong WebPEncodeRGB(
		const(ubyte)* rgb, int width, int height, int stride, 
		float quality_factor, ubyte** output
	); 
	extern ulong WebPEncodeBGR(
		const(ubyte)* bgr, int width, int height, int stride, 
		float quality_factor, ubyte** output
	); 
	extern ulong WebPEncodeRGBA(
		const(ubyte)* rgba, int width, int height, int stride, 
		float quality_factor, ubyte** output
	); 
	extern ulong WebPEncodeBGRA(
		const(ubyte)* bgra, int width, int height, int stride, 
		float quality_factor, ubyte** output
	); 
	extern ulong WebPEncodeLosslessRGB(const(ubyte)* rgb, int width, int height, int stride, ubyte** output); 
	extern ulong WebPEncodeLosslessBGR(const(ubyte)* bgr, int width, int height, int stride, ubyte** output); 
	extern ulong WebPEncodeLosslessRGBA(const(ubyte)* rgba, int width, int height, int stride, ubyte** output); 
	extern ulong WebPEncodeLosslessBGRA(const(ubyte)* bgra, int width, int height, int stride, ubyte** output); 
	enum WebPImageHint
	{
		WEBP_HINT_DEFAULT = 0,
		WEBP_HINT_PICTURE,
		WEBP_HINT_PHOTO,
		WEBP_HINT_GRAPH,
		WEBP_HINT_LAST,
	} 
	alias WEBP_HINT_DEFAULT = WebPImageHint.WEBP_HINT_DEFAULT; 
	alias WEBP_HINT_PICTURE = WebPImageHint.WEBP_HINT_PICTURE; 
	alias WEBP_HINT_PHOTO = WebPImageHint.WEBP_HINT_PHOTO; 
	alias WEBP_HINT_GRAPH = WebPImageHint.WEBP_HINT_GRAPH; 
	alias WEBP_HINT_LAST = WebPImageHint.WEBP_HINT_LAST; 
	struct WebPConfig
	{
		int lossless; 
		float quality; 
		int method; 
		WebPImageHint image_hint; 
		int target_size; 
		float target_PSNR; 
		int segments; 
		int sns_strength; 
		int filter_strength; 
		int filter_sharpness; 
		int filter_type; 
		int autofilter; 
		int alpha_compression; 
		int alpha_filtering; 
		int alpha_quality; 
		int pass; 
		int show_compressed; 
		int preprocessing; 
		int partitions; 
		int partition_limit; 
		int emulate_jpeg_size; 
		int thread_level; 
		int low_memory; 
		int near_lossless; 
		int exact; 
		int use_delta_palette; 
		int use_sharp_yuv; 
		int qmin; 
		int qmax; 
	} 
	enum WebPPreset
	{
		WEBP_PRESET_DEFAULT = 0,
		WEBP_PRESET_PICTURE,
		WEBP_PRESET_PHOTO,
		WEBP_PRESET_DRAWING,
		WEBP_PRESET_ICON,
		WEBP_PRESET_TEXT,
	} 
	alias WEBP_PRESET_DEFAULT = WebPPreset.WEBP_PRESET_DEFAULT; 
	alias WEBP_PRESET_PICTURE = WebPPreset.WEBP_PRESET_PICTURE; 
	alias WEBP_PRESET_PHOTO = WebPPreset.WEBP_PRESET_PHOTO; 
	alias WEBP_PRESET_DRAWING = WebPPreset.WEBP_PRESET_DRAWING; 
	alias WEBP_PRESET_ICON = WebPPreset.WEBP_PRESET_ICON; 
	alias WEBP_PRESET_TEXT = WebPPreset.WEBP_PRESET_TEXT; 
	
	extern int WebPConfigInitInternal(const WebPConfig*, WebPPreset, float, int); 
	static int WebPConfigInit(WebPConfig* config)
	{
		return WebPConfigInitInternal(
			config, WebPPreset.WEBP_PRESET_DEFAULT, 75.0f,
			WEBP_ENCODER_ABI_VERSION
		); 
	} 
	static int WebPConfigPreset(
		WebPConfig* config,
		WebPPreset preset, float quality
	)
	{
		return WebPConfigInitInternal(
			config, preset, quality,
			WEBP_ENCODER_ABI_VERSION
		); 
	} 
	extern int WebPConfigLosslessPreset(const WebPConfig* config, int level); 
	extern int WebPValidateConfig(const WebPConfig* config); 
	struct WebPAuxStats
	{
		int coded_size; 
		float[5] PSNR; 
		int[3] block_count; 
		int[2] header_bytes; 
		int[4][3] residual_bytes; 
		int[4] segment_size; 
		int[4] segment_quant; 
		int[4] segment_level; 
		int alpha_data_size; 
		int layer_data_size; 
		uint lossless_features; 
		int histogram_bits; 
		int transform_bits; 
		int cache_bits; 
		int palette_size; 
		int lossless_size; 
		int lossless_hdr_size; 
		int lossless_data_size; 
		uint[2] pad; 
	} 
	alias WebPWriterFunction = int function(const(ubyte)* data, ulong data_size, const WebPPicture* picture); 
	struct WebPMemoryWriter
	{
		ubyte* mem; 
		ulong size; 
		ulong max_size; 
		uint[1] pad; 
	} 
	extern void WebPMemoryWriterInit(WebPMemoryWriter* writer); 
	extern void WebPMemoryWriterClear(WebPMemoryWriter* writer); 
	extern int WebPMemoryWrite(const(ubyte)* data, ulong data_size, const WebPPicture* picture); 
	alias WebPProgressHook = int function(int percent, const WebPPicture* picture); 
	enum WebPEncCSP
	{
		WEBP_YUV420 = 0,
		WEBP_YUV420A = 4,
		WEBP_CSP_UV_MASK = 3,
		WEBP_CSP_ALPHA_BIT = 4,
	} 
	alias WEBP_YUV420 = WebPEncCSP.WEBP_YUV420; 
	alias WEBP_YUV420A = WebPEncCSP.WEBP_YUV420A; 
	alias WEBP_CSP_UV_MASK = WebPEncCSP.WEBP_CSP_UV_MASK; 
	alias WEBP_CSP_ALPHA_BIT = WebPEncCSP.WEBP_CSP_ALPHA_BIT; 
	enum WebPEncodingError
	{
		VP8_ENC_OK = 0,
		VP8_ENC_ERROR_OUT_OF_MEMORY,
		VP8_ENC_ERROR_BITSTREAM_OUT_OF_MEMORY,
		VP8_ENC_ERROR_NULL_PARAMETER,
		VP8_ENC_ERROR_INVALID_CONFIGURATION,
		VP8_ENC_ERROR_BAD_DIMENSION,
		VP8_ENC_ERROR_PARTITION0_OVERFLOW,
		VP8_ENC_ERROR_PARTITION_OVERFLOW,
		VP8_ENC_ERROR_BAD_WRITE,
		VP8_ENC_ERROR_FILE_TOO_BIG,
		VP8_ENC_ERROR_USER_ABORT,
		VP8_ENC_ERROR_LAST,
	} 
	alias VP8_ENC_OK = WebPEncodingError.VP8_ENC_OK; 
	alias VP8_ENC_ERROR_OUT_OF_MEMORY = WebPEncodingError.VP8_ENC_ERROR_OUT_OF_MEMORY; 
	alias VP8_ENC_ERROR_BITSTREAM_OUT_OF_MEMORY = WebPEncodingError.VP8_ENC_ERROR_BITSTREAM_OUT_OF_MEMORY; 
	alias VP8_ENC_ERROR_NULL_PARAMETER = WebPEncodingError.VP8_ENC_ERROR_NULL_PARAMETER; 
	alias VP8_ENC_ERROR_INVALID_CONFIGURATION = WebPEncodingError.VP8_ENC_ERROR_INVALID_CONFIGURATION; 
	alias VP8_ENC_ERROR_BAD_DIMENSION = WebPEncodingError.VP8_ENC_ERROR_BAD_DIMENSION; 
	alias VP8_ENC_ERROR_PARTITION0_OVERFLOW = WebPEncodingError.VP8_ENC_ERROR_PARTITION0_OVERFLOW; 
	alias VP8_ENC_ERROR_PARTITION_OVERFLOW = WebPEncodingError.VP8_ENC_ERROR_PARTITION_OVERFLOW; 
	alias VP8_ENC_ERROR_BAD_WRITE = WebPEncodingError.VP8_ENC_ERROR_BAD_WRITE; 
	alias VP8_ENC_ERROR_FILE_TOO_BIG = WebPEncodingError.VP8_ENC_ERROR_FILE_TOO_BIG; 
	alias VP8_ENC_ERROR_USER_ABORT = WebPEncodingError.VP8_ENC_ERROR_USER_ABORT; 
	alias VP8_ENC_ERROR_LAST = WebPEncodingError.VP8_ENC_ERROR_LAST; 
	struct WebPPicture
	{
		int use_argb; 
		WebPEncCSP colorspace; 
		int width; 
		int height; 
		ubyte* y; 
		ubyte* u; 
		ubyte* v; 
		int y_stride; 
		int uv_stride; 
		ubyte* a; 
		int a_stride; 
		uint[2] pad1; 
		uint* argb; 
		int argb_stride; 
		uint[3] pad2; 
		int function(const(ubyte)* data, ulong data_size, const WebPPicture* picture) writer; 
		void* custom_ptr; 
		int extra_info_type; 
		ubyte* extra_info; 
		WebPAuxStats* stats; 
		WebPEncodingError error_code; 
		int function(int percent, const WebPPicture* picture) progress_hook; 
		void* user_data; 
		uint[3] pad3; 
		ubyte* pad4; 
		ubyte* pad5; 
		uint[8] pad6; 
		void* memory_; 
		void* memory_argb_; 
		void*[2] pad7; 
	} 
	extern int WebPPictureInitInternal(const WebPPicture*, int); 
	static int WebPPictureInit(WebPPicture* picture)
	{ return WebPPictureInitInternal(picture, WEBP_ENCODER_ABI_VERSION); } 
	extern int WebPPictureAlloc(const WebPPicture* picture); 
	extern void WebPPictureFree(const WebPPicture* picture); 
	extern int WebPPictureCopy(const WebPPicture* src, const WebPPicture* dst); 
	extern int WebPPlaneDistortion(
		const(ubyte)* src, ulong src_stride, const(ubyte)* ref_, ulong ref_stride, 
		int width, int height, ulong x_step, int type, float* distortion, float* result
	); 
	extern int WebPPictureDistortion(const WebPPicture* src, const WebPPicture* ref_, int metric_type, float[5] result); 
	extern int WebPPictureCrop(const WebPPicture* picture, int left, int top, int width, int height); 
	extern int WebPPictureView(const WebPPicture* src, int left, int top, int width, int height, const WebPPicture* dst); 
	extern int WebPPictureIsView(const WebPPicture* picture); 
	extern int WebPPictureRescale(const WebPPicture* picture, int width, int height); 
	extern int WebPPictureImportRGB(const WebPPicture* picture, const(ubyte)* rgb, int rgb_stride); 
	extern int WebPPictureImportRGBA(const WebPPicture* picture, const(ubyte)* rgba, int rgba_stride); 
	extern int WebPPictureImportRGBX(const WebPPicture* picture, const(ubyte)* rgbx, int rgbx_stride); 
	extern int WebPPictureImportBGR(const WebPPicture* picture, const(ubyte)* bgr, int bgr_stride); 
	extern int WebPPictureImportBGRA(const WebPPicture* picture, const(ubyte)* bgra, int bgra_stride); 
	extern int WebPPictureImportBGRX(const WebPPicture* picture, const(ubyte)* bgrx, int bgrx_stride); 
	extern int WebPPictureARGBToYUVA(const WebPPicture* picture, WebPEncCSP); 
	extern int WebPPictureARGBToYUVADithered(const WebPPicture* picture, WebPEncCSP colorspace, float dithering); 
	extern int WebPPictureSharpARGBToYUVA(const WebPPicture* picture); 
	extern int WebPPictureSmartARGBToYUVA(const WebPPicture* picture); 
	extern int WebPPictureYUVAToARGB(const WebPPicture* picture); 
	extern void WebPCleanupTransparentArea(const WebPPicture* picture); 
	extern int WebPPictureHasTransparency(const WebPPicture* picture); 
	extern void WebPBlendAlpha(const WebPPicture* picture, uint background_rgb); 
	extern int WebPEncode(const WebPConfig* config, const WebPPicture* picture); 
} 