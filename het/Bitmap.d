module het.bitmap;/+DIDE+/

version(/+$DIDE_REGION+/all)
{
	//This is the new replacement of het.image.d
	
	pragma(lib, "gdi32.lib");
	
	//Todo: icons have a black background since windows update installed near 22.11.15
	
	import het.utils;
	
	enum smallSpace = "\u2008";
	
	__gshared size_t BitmapCacheMaxSizeBytes = 768<<20;
	
	import std.uni: isAlphaNum;
	import core.sys.windows.windows :	HBITMAP, HDC, BITMAPINFO, GetDC, CreateCompatibleDC, CreateCompatibleBitmap, 
		SelectObject, BITMAPINFOHEADER, BI_RGB, DeleteObject, GetDIBits, DIB_RGB_COLORS,
		HRESULT, WCHAR, BOOL, RECT, IID;
	
	//png, tga, jpg(read_jpeg_info only)
	import imageformats; //Todo: a jpeg ebbol mar nem kell.
	
	//webp
	import webp.encode, webp.decode;
	
	//jpeg
	import turbojpeg.turbojpeg;
	
	//turn Direct2D linkage on/off
	version = D2D_FONT_RENDERER;
	
	enum BitmapQueryCommand
	{ access, access_delayed, finishWork, finishTransformation, remove, stats, details, garbageCollect, set }
	
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
	
	struct BitmapTransformation
	{
		 //BitmapTransformation (thumb) ////////////////////////////////////
		enum thumbKeyword = "?thumb";
		//?thumb32w		 specifies maximum width
		//?thumb32h		 specifies maximum height
		//?thumb32wh	  specifies maximum width and maximum height
		//?thumb32	  ditto
		//Todo: ?thumb32x24  different maxwidth and maxheight
		//Todo: keep aspect or not
		/+
			Todo: ?thumb=32w is not possible because processMarkupCommandLine() 
				uses the = pro parameters and it can't passed into this filename.
		+/
		//Todo: cache decoded full size image
		//Todo: turboJpeg small size extract
		
		File originalFile, transformedFile;
		int thumbMaxSize;
		bool maxWidthSpecified, maxHeightSpecified;
		
		size_t sizeBytes; //used by bitmapQuery/detailed stats
		
		bool isThumb() const { return thumbMaxSize>0; }
		
		bool isHistogram, isGrayHistogram; //Todo: this is lame. This should be solved by registered plugins.
		
		this(File file)
		{
			
			transformedFile = file;
			auto s = file.fullName;
			
			//try to decode thumbnail params
			string thumbDef, orig;
			if(file.fullName.split2(thumbKeyword, orig, thumbDef, false/+must not strip!+/))
			{
				originalFile = File(orig);
				
				//get width/height posfixes
				while(1) {
					if(thumbDef.endsWith("w")) { maxWidthSpecified	= true; thumbDef.popBack; continue; }
					if(thumbDef.endsWith("h")) { maxHeightSpecified	= true; thumbDef.popBack; continue; }
					break;
				}
				const maxAllSpecified = maxWidthSpecified == maxHeightSpecified;
				if(maxAllSpecified)
				maxWidthSpecified = maxHeightSpecified = true;
				
				ignoreExceptions({ thumbMaxSize = thumbDef.to!int; });
			}
			else if(file.fullName.canFind("?histogram"))	{
				originalFile = File(orig[0..orig.countUntil('?')]);
				isHistogram = true;
			}
			else if(file.fullName.canFind("?grayHistogram"))	{
				originalFile = File(orig[0..orig.countUntil('?')]);
				isGrayHistogram = true;
			}
		}
		
		alias needTransform this;
		bool needTransform()
		{ return isThumb|| isHistogram || isGrayHistogram; }
		
		Bitmap transform(Bitmap orig)
		{
			if(!orig || !orig.valid) return newErrorBitmap("Invalid source for BitmapTransform.");
			
			sizeBytes = orig.sizeBytes; //used by bitmapQuery/detailed stats
			
			auto doIt()
			{
				if(isThumb)
				{
					float minScale = 1;
					if(maxWidthSpecified) minScale.minimize(float(thumbMaxSize) / orig.size.x);
					if(maxHeightSpecified) minScale.minimize(float(thumbMaxSize) / orig.size.y);
					
					if(minScale < 1) {
						ivec2 newSize = round(orig.size*minScale);
						//print("THUMB", fn, thumbDef, "oldSize", orig.size, "newSize", newSize);
						return orig.resize_nearest(newSize); //Todo: mipmapped bilinear/trilinear
					}
				}
				else if(isHistogram)
				{
					auto img = orig.get!RGB;
					int[3][256] histogram;
					foreach(p; img.asArray) foreach(i; 0..3) histogram[p[i]][i]++;
					int histogramMax = histogram[].map!(h => h[].max).array.max;
					float sc = 255.0f/histogramMax;
					return new Bitmap(image2D(256, 1, histogram[].map!(p => RGB(p[0]*sc, p[1]*sc, p[2]*sc))));
				}
				else if(isGrayHistogram)
				{
					auto img = orig.get!ubyte;
					int[256] histogram;
					foreach(p; img.asArray) histogram[p]++;
					int histogramMax = histogram[].max;
					float sc = 255.0f/histogramMax;
					return new Bitmap(image2D(256, 1, histogram[].map!(p => cast(ubyte)((p*sc).iround))));
				}
				
				return orig.dup;
			}
			
			//set filename and copy the modified time
			auto res = doIt;
			res.file = transformedFile;
			res.modified = orig.modified;
			return res;
		}
		
	}
	
	
	
	private BitmapCacheStats _bitmapCacheStats; //this is a result
	
	Bitmap bitmapQuery(BitmapQueryCommand cmd, File file, ErrorHandling errorHandling, Bitmap bmpIn=null)
	{
		auto _ = PROBE("bitmapQuery");
		synchronized
		{
			
			//disable delayed
			//if(cmd==BitmapQueryCommand.access_delayed) cmd = BitmapQueryCommand.access;
			
			import std.parallelism;
			enum log = false;
			
			Bitmap res;
			
			__gshared Bitmap[File] cache, loading;
			__gshared  BitmapTransformation[File] transformationQueue;
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
				
				static void worker_load(Bitmap bmp/+"loading" bitmap that is holding filename to load+/)
				{
					const errorHandling = ErrorHandling.ignore; //track;
					
					auto file = bmp.file; //it receives the original unloaded Bitmap and monitors the .removed field too.
					
					const maxWorkers = 9999;
					//Todo: no need to limit parallelism, taskPool is good. The slow bottleneck is convert and upload to gpu.
					
					while(cast()activeBackgroundLoaderCount >= maxWorkers)
					{
						sleep(3);
						//Todo: this sleep is not threadsafe
					}
					
					if(bmp.removed)
					{
						if(log)
						LOG("Bitmap has been removed before delayed loader. Cancelling operation.", bmp);
						return;
					}
					
					import core.atomic;
					
					atomicOp!"+="(activeBackgroundLoaderCount, 1);
					//LOG(cast()activeBackgroundLoaderCount, bmp.file.name);
					
					auto newBmp = newBitmap(file, errorHandling);
					
					atomicOp!"-="(activeBackgroundLoaderCount, 1);
					
					bitmapQuery(BitmapQueryCommand.finishWork, file, errorHandling, newBmp);
				}
				
				taskPool.put(task!worker_load(bmp));
				
				return bmp; //returns a "loading" placeholder bitmap
			}
			
			/// Allocate new transformed file in cache and launch the transformer thread
			static auto startDelayedTransformation(Bitmap originalBmp, Bitmap transformedBmp, BitmapTransformation tr)
			{
				
				static void worker_transform(Bitmap originalBmp, Bitmap transformedBmp, BitmapTransformation tr)
				{
					if(transformedBmp.removed)
					{
						if(log)
						LOG("Bitmap has been removed before delayed transformation. Canceling operation.", transformedBmp);
						return;
					}
					
					ignoreExceptions
					(
						{
							auto newBmp = tr.transform(originalBmp);
							//LOG(originalBmp, transformedBmp, newBmp, tr);
							bitmapQuery(BitmapQueryCommand.finishTransformation, tr.transformedFile, ErrorHandling.track, newBmp);
						}
					);
				}
				
				taskPool.put(task!worker_transform(originalBmp, transformedBmp, tr));
			}
			
			//Loads and transforms a file, and updates the caches. Works in delayed and immediate mode.
			//   requiredOriginalTime : optional check for the transformation's original file modified time
			Bitmap loadAndTransform(File file, DateTime requiredOriginalTime = DateTime.init)
			{
				Bitmap res;
				
				bool delayed = cmd==BitmapQueryCommand.access_delayed;
				if(file.driveIs(`font`) || file.driveIs(`temp`) || file.driveIs(`icon`)) delayed = false; 
				//Todo: delayed restriction. should refactor this nicely. Use hash map and centralize nondelayed file types.
				
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
							if(checkRequiredModifiedTime(*originalBmp))
							{
								 //original bmp is up to date
								startDelayedTransformation(*originalBmp, res, tr);
							}
							else
							{
								 //original is an old version
								auto lastBmp = *originalBmp; 
								//preserve it in the cache, so it can be displayed while loading the new
								
								transformationQueue[tr.originalFile] = tr;
								startDelayedLoad(tr.originalFile);
								
								cache[tr.originalFile] = lastBmp;
								lastBmp.loading = true;
							}
						}
						else {
							transformationQueue[tr.originalFile] = tr;
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
						
						if(auto p = file in cache)
						{
							 //already in cache
							res = *p;
							
							//check for a refreshed version
							if(!res.loading)
							{
								//current bitmap is NOT loading
								if(auto t = file.getLatestModifiedTime)
								{
									//the modified time is accessible
									if(t != res.modified)
									{
										//it has a new version, must load...
										if(cmd == BitmapQueryCommand.access_delayed)
										{
											loadAndTransform(file, t);
											//put back the original file into the cache and mark that it is loading
											cache[file] = res;
											res.loading = true;
										}
										else
										{ res = loadAndTransform(file, t); }
									}
								}
							}
							
						}
						else
						{
							//new thing, must be loaded
							res = loadAndTransform(file);
						}
					}
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
							startDelayedTransformation(bmpIn, cache[(*tr).transformedFile], *tr);
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
						transformationQueue.remove(file);
					}
				}
				break;
			}
			
			if(res) res.accessed_tick = application.tick;
			
			return res;
		}
	}
	
	__gshared struct bitmaps
	{
		static: //bitmaps() ///////////////////////////////////////////
			auto opCall(F)(F file, Flag!"delayed" delayed=No.delayed, ErrorHandling errorHandling=ErrorHandling.track, Bitmap bmp=null)
		{ return bitmapQuery(delayed ? BitmapQueryCommand.access_delayed : BitmapQueryCommand.access, File(file), errorHandling, bmp); }
			auto opCall(F)(F file, ErrorHandling errorHandling, Flag!"delayed" delayed=No.delayed, Bitmap bmp=null)
		{ return opCall(file, delayed, errorHandling, bmp); }
		
			auto opIndex(F)(F file)
		{ return opCall(file, No.delayed, ErrorHandling.raise); }
		
			auto opIndexAssign(F)(Bitmap bmp, F file)
		{ /*enforce(bmp && bmp.valid);*/ return opCall(file, No.delayed, ErrorHandling.raise, bmp); }
		
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
			
			void set(File f, Bitmap bmp)
		{
			enforce(f);
			enforce(bmp);
			
			bitmapQuery(BitmapQueryCommand.set, f, ErrorHandling.ignore, bmp);
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
		
		doIt("immediate"                    , ()=>bitmaps(file, No.delayed));	 bitmaps.remove(file);
		doIt("immediate again, after remove", ()=>bitmaps(file, No.delayed));	 bitmaps.remove(file);
		doIt("delayed first (cache miss)"	  , ()=>bitmaps(file, Yes.delayed));
		doIt("delayed again (cache hit)"		 , ()=>bitmaps(file, Yes.delayed));	 bitmaps.remove(file);
		doIt("delayed again (removed  )"		 , ()=>bitmaps(file, Yes.delayed));	 bitmaps.remove(file);
		
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
	
	
	//CustomBitmapLoader ///////////////////////////////////////////////////
	
	
	private __gshared Bitmap function(string)[string] customBitmapLoaders;
	
	void registerCustomBitmapLoader(string prefix, Bitmap function(string) loader) //Todo: make it threadsafe
	in(prefix.length>=2, "invalid prefix string")
	{
		prefix = prefix.lc;
		enforce(!(prefix in customBitmapLoaders), "Already registered customBitmapLoader. Prefix: "~prefix);
		customBitmapLoaders[prefix] = loader;
	}
	
	Bitmap colorMapBitmapLoader(string name)
	{
		enforce(name in colorMaps);
		auto 	width = 128,
			raw = colorMaps[name].toArray!RGBA(width),
			img = image2D(width, 1, raw),
			bmp = new Bitmap(img);
		return bmp;
	}
	
	//newBitmap ////////////////////////////
	
	//Load a bitmap immediately with optional error handling. No caching, no thumbnail/transformations.
	auto newBitmap(File file, ErrorHandling errorHandling)
	{
		 //newBitmap() ////////////////////////////
		Bitmap res;
		final switch(errorHandling)
		{
			case ErrorHandling.raise 	:{
				try { res = newBitmap_internal(file, true); }
				catch(Exception e) { throw e; }
			}	break;
			case ErrorHandling.track 	:{
				try { res = newBitmap_internal(file, true); }
				catch(Exception e) { WARN(e.simpleMsg); res = newErrorBitmap(e.simpleMsg); }
			}	break;
			case ErrorHandling.ignore	:{
				try { res = newBitmap_internal(file, true); }
				catch(Exception e) { res = newErrorBitmap(e.simpleMsg); }
			}	break;
		}
		res.file = file;
		res.modified = file.modified;
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
	
	private Bitmap newBitmap_internal(in ubyte[] data, bool mustSucceed=true)
	{ return data.deserialize!Bitmap(mustSucceed); }
	
	private Bitmap newBitmap_internal(in File file, bool mustSucceed=true)
	{ return newBitmap_internal(file.fullName, mustSucceed); }
	
	/// Gets the modified time of any given filename. Including real/virtual files, fonts, transformed images, thumbnails
	/// returns null if unknown
	auto getLatestModifiedTime(in File file, Flag!"virtualOnly" virtualOnly = Yes.virtualOnly/*Todo: preproc*/)
	{
		if(file) {
			auto drive = file.drive;
			if(!virtualOnly || drive!="virtual") { return file.withoutQueryString.modified; }
		}
		return DateTime.init;
	}
	
	Bitmap newBitmap_internal(string fn, bool mustSucceed=true)
	{
		//Todo: handle mustSuccess with an outer try catch{}, not with lots of ifs.
		//when tere is an error, always raise an exception, catch will handle it. If mustSuccess, it will reraise. Otherwise it can drop a WARN.
		
		//split prefix:\line
		auto prefix = fn.until!(not!isAlphaNum).text;
		auto line = fn;
		if(prefix.length>1 && fn[prefix.length..$].startsWith(`:\`))
		{
			line = fn[prefix.length+2..$];
			prefix = prefix.lc;
		}else { prefix = ""; }
		
		//Opt: this if chain is slow
		
		if(prefix=="")	{
			//threat it as a simple filename
			return File(fn).deserialize!Bitmap(mustSucceed);
		}
		else if(prefix=="font")	{
			//Todo: font and icon should be put in a list that ensures the following: bitmap.resident, no delayed load
			version(D2D_FONT_RENDERER)
			{
				auto res = bitmapFontRenderer.renderDecl(fn); //Todo: error handling, mustExists
				if(res.valid) res.resident = true; //dont garbagecollect fonts because they are slow to generate
				return res;
			}
			else { enforce(0, "No font renderer linked into the exe. Use version D2D_FONT_RENDERER!"); }
		}
		else if(prefix=="temp")	{ auto b = new Bitmap; b.resident = true; b.file = File(fn); return b; }
		else if(prefix=="virtual")	{ return File(fn).deserialize!Bitmap(mustSucceed); }
		else if(prefix=="desktop")	{ return getDesktopSnapshot; }
		else if(prefix=="monitor")	{
			return getPrimaryMonitorSnapshot; //Todo: monitor indexing
		}
		else if(prefix=="debug")	{
			 //debug images
			uint color = (line.to!int)>>1;
			color = color | (255-color)<<8;
			return new Bitmap(image2D(1600, 1200, RGBA(0xFF000000 | color)));
		}
		else if(prefix=="icon")	{
			//folder: icon:\folder\    //"folder" is a literal!!!
			//drive: icon:\d:\
			//file: icon:\.bat
			
			//Todo: LoadIcon from dll/exe
			
			//options: ?small ?16 ?large ?32
			
			auto res = getAssociatedIconBitmap(line);
			if(mustSucceed & !res) raise("Unable to get associated icon for `"~fn~"`");
			
			if(res.valid) res.resident = true;
			return res;
		}
		else	{
			auto loader = prefix in customBitmapLoaders;
			if(loader)
			return (*loader)(line);
		}
		
		raise("Unknown prefix: "~prefix~`:\`);
		return null; //raise is not enough
		
		//if(fn.startsWith(`screenShot:\`)){
		//Todo: screenshot implementalasa
		
		/*
			   auto gBmp = new GdiBitmap(ivec2(screenWidth, screenHeight), 4);
			BitBlt(gBmp.hdcMem, 0, 0, gBmp.size.x, gBmp.size.y, GetDC(NULL), 0, 0, SRCCOPY).writeln;
		*/
		
		//Todo: bitmap clipboard operations
		/*
			// save bitmap to clipboard
				OpenClipboard(NULL);
				EmptyClipboard();
				SetClipboardData(CF_BITMAP, hBitmap);
				CloseClipboard();
		*/
		
		
		/*
			HDC	hScreen = GetDC(NULL);
				HDC	hDC	=	CreateCompatibleDC(hScreen);
				HBITMAP	hBitmap	= CreateCompatibleBitmap(hScreen, abs(b.x-a.x), abs(b.y-a.y));
				HGDIOBJ	old_obj	= SelectObject(hDC, hBitmap);
				BOOL	bRet	= BitBlt(hDC, 0, 0, abs(b.x-a.x), abs(b.y-a.y), hScreen, a.x, a.y, SRCCOPY);
			
				// save bitmap to clipboard
				OpenClipboard(NULL);
				EmptyClipboard();
				SetClipboardData(CF_BITMAP, hBitmap);
				CloseClipboard();
			
			 // clean up
			 SelectObject(hDC, old_obj);
			 DeleteDC(hDC);
			 ReleaseDC(NULL, hScreen);
			 DeleteObject(hBitmap);
		*/
		//}
		
		//debug images
		
		//otherwise File
		//return new Bitmap(File(fn).read(mustExist));
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
	
	float linearInterpolate(float[2] p, float x)
	{
		//http://www.paulinternet.nl/?page=bicubic
		return p[1]*x + p[0]*(1-x);
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
	{ with(img) { data[] &= mask; } }
	
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
}
version(/+$DIDE_REGION+/all)
{
	
	
	//BitmapInfo ///////////////////////////////////
	
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
		{ return supportedBitmapExts.canFind(format) && chn.inRange(1, 4); }
		
			int numPixels() const
		{ return size[].product; }
		
			const ref auto width()
		{ return size.x; }
			const ref auto height()
		{ return size.y; }
		
		private static {
			
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
				 //use libWebp
				import webp.decode;
				
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
					enforce(stream.length>=8);
					const us = cast(ushort[])stream[0..8];
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
		
			this(in File fileName)
		{
			enum peekSize = 32;
			this(fileName, fileName.read(false, 0, peekSize));
		}
		
	}
	
	
	class Bitmap
	{
		private
		{
			void[] data_;
			string type_ = "ubyte";
			int width_, height_, channels_=4;
		}
		
		deprecated int tag;	//can be an external id
		deprecated int counter;	//can notify of cnahges
		
		File file;
		DateTime modified;
		string error;
		bool loading, removed;	//Todo: these are managed by bitmaps(). Should be protected and readonly.
		bool processed;	//user flag. Can do postprocessing after the image is loaded
		bool resident;	//if true, garbageCollector will nor free this
		
		uint accessed_tick; //garbageCollect using it
		
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
			data_ = data;
			width_ = width;
			height_ = height;
			channels_ = channels;
			type_ = type;
			
			counter++;
		}
		
		void set(E)(Image!(E, 2) im)
		{
			setRaw(im.asArray, im.width, im.height, VectorLength!E, (ScalarType!E).stringof);
			
			counter++;
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
					if(CT.stringof == type && len==channels)
					{
						auto im = (cast()this).getImage_unsafe!T;
						static if(is(T==E)) return im.dup;
						else static if(is(T==RGB) && is(E==RGBA))
						{ return image2D(size, im.asArray.rgb_to_rgba); }
						else return im.image2D!(a => a.convertPixel!E);
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
		
		Bitmap dup()
		{
			auto b = new Bitmap;
			b.file = file;
			b.modified = modified;
			b.error = error;
			b.setRaw(data_.dup, width, height, channels, type);
			return b;
		}
		
		void saveTo(F)(in F file)
		{
			auto f = File(file);
			this.serialize(f.ext.withoutStarting('.')).saveTo(f);
		}
		
		void loadFrom(F)(in F file)
		{
			auto f = File(file);
			auto b = f.read.deserialize!Bitmap;
			copyFrom(b);
		}
	}
	
	//Bitmap/Image serializer //////////////////////////////////////////
	
	immutable serializeImage_supportedFormats = ["webp", "png", "bmp", "tga", "jpg"];
	
	__gshared serializeImage_defaultFormat = "png";
	//png is the best because it knows 1..4 components and it's moderately compressed.
	
	private static ubyte[] write_webp_to_mem(int width, int height, ubyte[] data, int quality)
	{
		  //Reasonable quality = 95,  lossless = 100
		//Note: the header is in the same syntax like in the imageformats module.
		
		ubyte* output;
		size_t size;
		const lossy = quality<100; //100 means lossless
		const channels = data.length.to!int/(width*height);
		enforce(data.length = width*height*channels, "invalid image data");
		switch(channels)
		{
			case 4:	size = lossy 	? WebPEncodeRGBA	(data.ptr, width, height, width*channels, quality, &output)
				: WebPEncodeLosslessRGBA	(data.ptr, width, height, width*channels, &output);	break;
			case 3:	size = lossy 	? WebPEncodeRGB	(data.ptr, width, height, width*channels, quality, &output)
				: WebPEncodeLosslessRGB	(data.ptr, width, height, width*channels, &output);	break;
			default:	enforce(0, "8/16bit webp not supported"); //Todo: Y, YA plane-kkal megoldani ezeket is
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
		const channels = data.length.to!int/(width*height),
					pitch = width*channels;
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
	
	private ubyte[] serializeImage(T)(Image!(T, 2) img, string format="")
	{
		 //compile time version
		import imageformats;
		
		enum chn = VectorLength!T,
				 type = (ScalarType!T).stringof;
		if(format=="") format = serializeImage_defaultFormat;
		auto fmt = format.commandLineToMap;
		
		auto getQuality()
		{
			return ("quality" in fmt) 	? fmt["quality"].to!int.clamp(0, 100)
				: 95 /+Default quality for jpeg and webp+/;
		}
		
		switch(fmt["0"])
		{
			case "bmp":	return write_bmp_to_mem 
			(
				img.width, img.height, cast(ubyte[])
				img.convertImage_ubyte_chnRemap!([3,4,3,4]).asArray
			); //only 3 and 4 chn supported
			case "png":	return write_png_to_mem 
			(
				img.width, img.height, cast(ubyte[])
				img.convertImage_ubyte_chnRemap!([1,2,3,4]).asArray
			); //all chn supported
			case "tga":	return write_tga_to_mem  
			(
				img.width, img.height, cast(ubyte[])
				img.convertImage_ubyte_chnRemap!([1,4,3,4]).asArray
			); //all except 2 chn supported
			case "webp":	return write_webp_to_mem
			(
				img.width, img.height, cast(ubyte[])
				img.convertImage_ubyte_chnRemap!([3,4,3,4]).asArray, getQuality
			); //only 3 and 4 chn
			case "jpg":	return write_jpg_to_mem  
			(
				img.width, img.height, cast(ubyte[])
				img.convertImage_ubyte_chnRemap!([1,1,3,3]).asArray, getQuality
			); //losts alpha
			default:	raise("invalid image serialization format: "~format); return [];
		}
	}
	
	private ubyte[] serializeImage(Bitmap bmp, string format="")
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
	
	Bitmap deserialize(T : Bitmap)(in ubyte[] stream, bool mustSucceed=false)
	{
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
					} break;
					case 4: {
						auto data = uninitializedArray!(RGBA[])(info.numPixels);
						WebPDecodeRGBAInto(stream.ptr, stream.length, cast(ubyte*)data.ptr, data.length*4, info.size.x*4);
						bmp.set(image2D(info.size, data));
					} break;
					//Todo: WebPDecodeYUVInto-val megcsinalni az 1 es 2 channelt.
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
						
					} break;
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
		HDC hScreenDC = GetDC(null);//CreateDC("DISPLAY", NULL, NULL, NULL);
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
	
	auto getSnapshot(in ibounds2 bnd)
	{
		auto gBmp = new GdiBitmap(bnd.size); scope(exit) gBmp.free;
		auto dc = GetDC(null); scope(exit) ReleaseDC(null, dc);
		BitBlt(gBmp.hdcMem, 0, 0, bnd.width, bnd.height, dc, bnd.left, bnd.top, SRCCOPY);
		
		auto bmp = new Bitmap(gBmp.toImage);
		bmp.modified = now;
		return bmp;
	}
	
	auto getDesktopSnapshot()
	{ return getSnapshot(getDesktopBounds); }
	auto getPrimaryMonitorSnapshot()
	{ return getSnapshot(getPrimaryMonitorBounds); }
	
	//Icon /////////////////////////////////////
	
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
					
					DrawIconEx(gBmp.hdcMem, 0, 0, hIcon, bi.biWidth, bi.biHeight, 0, null, DI_MASK );	 auto imMask	= gBmp.toImage;
					DrawIconEx(gBmp.hdcMem, 0, 0, hIcon, bi.biWidth, bi.biHeight, 0, null, DI_IMAGE);	 auto imColor	= gBmp.toImage;
					
					//swap blue-red, gray if transparent.
					auto imAlpha = image2D!((i, m) => m.g ? RGBA(127, 127, 127, 0) : RGBA(i.b, i.g, i.r, 255))(imColor, imMask);
					
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
	
	
	
	//GdiBitmap class ////////////////////////////////////
	
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
			if(!GetDIBits(hdcMem, hBitmap, 0, size.y, img.asArray.ptr, &bmi, DIB_RGB_COLORS))
			raiseLastError;
			return img;
		}
		
		Bitmap toBitmap()
		{ return new Bitmap(toImage); }
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
			extern(Windows):
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
				in D2D1_RENDER_TARGET_PROPERTIES renderTargetProperties, 
				out ID2D1DCRenderTarget dcRenderTarget
			);
		}
		
			enum D2D1_FACTORY_TYPE:uint
		{ SINGLE_THREADED, MULTI_THREADED, FORCE_DWORD = 0xffffffff }
		
			extern(Windows) HRESULT D2D1CreateFactory(
			D2D1_FACTORY_TYPE factoryType, 
			REFIID riid, void* pFactoryOptions, out ID2D1Factory
		);
		
			enum D2D1_ANTIALIAS_MODE:uint
		{ PER_PRIMITIVE, ALIASED, FORCE_DWORD = 0xffffffff }
			enum D2D1_DRAW_TEXT_OPTIONS:uint
		{ NONE=0, NO_SNAP=1, CLIP=2, ENABLE_COLOR_FONT=4, FORCE_DWORD=0xffffffff }
			enum D2D1_TEXT_ANTIALIAS_MODE:uint
		{ DEFAULT, CLEARTYPE, GRAYSCALE, ALIASED, FORCE_DWORD = 0xffffffff }
		
			enum DWRITE_TEXT_ALIGNMENT :int
		{ LEADING, TRAILING, CENTER, JUSTIFIED }
			enum DWRITE_PARAGRAPH_ALIGNMENT :int
		{ NEAR, FAR, CENTER }
			enum DWRITE_WORD_WRAPPING :int
		{ WRAP, NO_WRAP, EMERGENCY_BREAK, WHOLE_WORD, CHARACTER }
			enum DWRITE_READING_DIRECTION :int
		{ LEFT_TO_RIGHT, RIGHT_TO_LEFT, TOP_TO_BOTTOM, BOTTOM_TO_TOP }
			enum DWRITE_FLOW_DIRECTION :int
		{ TOP_TO_BOTTOM, BOTTOM_TO_TOP, LEFT_TO_RIGHT, RIGHT_TO_LEFT }
			enum DWRITE_TRIMMING_GRANULARITY :int
		{ NONE, CHARACTER, WORD }
			enum DWRITE_LINE_SPACING_METHOD :int
		{ DEFAULT, UNIFORM }
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
		{ NORMAL, OBLIQUE, ITALIC }
		
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
			extern(Windows):
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
			extern(Windows):
			void SetOpacity(FLOAT opacity);
			void SetTransform(in D2D1_MATRIX_3X2_F transform);
			FLOAT GetOpacity() const;
			void GetTransform(out D2D1_MATRIX_3X2_F transform) const;
		}
		
			mixin(uuid!(ID2D1SolidColorBrush, "2cd906a9-12e2-11dc-9fed-001143a055f9"));
			interface ID2D1SolidColorBrush : ID2D1Brush
		{
			extern(Windows):
			void SetColor(in D2D1_COLOR_F color);
			ref D2D1_COLOR_F GetColor() const; //Bug: got crash? see ID2D1RenderTarget.GetSize()
		}
		
			mixin(uuid!(ID2D1Resource, "2cd90691-12e2-11dc-9fed-001143a055f9"));
			interface ID2D1Resource : IUnknown
		{
			extern(Windows):
			void GetFactory(out ID2D1Factory factory) const;
		}
		
			mixin(uuid!(ID2D1RenderTarget, "2cd90694-12e2-11dc-9fed-001143a055f9"));
			interface ID2D1RenderTarget : ID2D1Resource
		{
			extern(Windows):
			HRESULT CreateBitmap(/**/);
			HRESULT CreateBitmapFromWicBitmap(/**/);
			HRESULT CreateSharedBitmap(/**/);
			HRESULT CreateBitmapBrush(/**/);
			HRESULT CreateSolidColorBrush(
				in D2D1_COLOR_F color, 
				in D2D1_BRUSH_PROPERTIES brushProperties, 
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
			void FillRectangle(in D2D1_RECT_F rect, ID2D1Brush brush);
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
			
			void SetTransform(in D2D1_MATRIX_3X2_F transform);
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
			
			void Clear(in D2D1_COLOR_F clearColor);
			
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
		{
			 extern(Windows):
					HRESULT BindDC(const HDC  hDC, const(RECT)* pSubRect);
		}
		
			mixin(uuid!(IDWriteFactory, "b859ee5a-d838-4b5b-a2e8-1adc7d93db48"));
			interface IDWriteFactory : IUnknown
		{
			extern(Windows):
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
		
			enum DWRITE_FACTORY_TYPE : int { SHARED, ISOLATED }
		
			export extern(C) HRESULT DWriteCreateFactory(DWRITE_FACTORY_TYPE factoryType, REFIID iid, out IDWriteFactory factory);
		
			mixin(uuid!(IDWriteTextLayout, "53737037-6d14-410b-9bfe-0b182bb70961"));
			interface IDWriteTextLayout : IDWriteTextFormat
		{
			extern(Windows):
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
					scope(exit) gBmp.free;
					
					//draw
					auto rect = RECT(0, 0, gBmp.size.x, gBmp.size.y); //Todo: this can be null???
					dcrt.BindDC(gBmp.hdcMem, &rect).hrChk("BindDC");
					
					dcrt.BeginDraw;
						dcrt.Clear(inverse ? white : black);
						brush.SetColor(inverse ? black : white);
					
						float y = 0;
						if(isLucidaConsole) y = props.height*0.16f;else if(!isSegoeAssets)
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
				
				if(res.access!RGBA.asArray.map!isGrayscale.all)
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
	{ registerCustomBitmapLoader("colormap", &colorMapBitmapLoader); }
}