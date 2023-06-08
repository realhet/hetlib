module het.megatexturing;/+DIDE+/

import het.opengl, het.algorithm;

//imports for debug
import het.draw2d;

//Global access ///////////////////////////////

alias textures = Singleton!TextureManager;

__gshared int[dchar] DefaultFont_subTexIdxMap;
//Used by UI, must be cleared after every megatexture GC

__gshared
	DEBUG_clearRemovedSubtexArea	= false, //marks the free'd parts with fuchsia
	global_disableSubtextureAging	= false, /+
	Suspend updating texture access statistics.
	Good for debugging the megaTextures, 
	it can be disabled temporarily.
+/
	EnableMultiThreadedTextureLoading 	= true,

	synchLog = false,  //LOG the start and end of synch blocks

	MegaTexMinSize = 1<< 9, //can set by the application before any textures being used
	MegaTexMaxSize = 1<<13;
//Todo: ensure the safety of this with a setter.

bool canUnloadTexture(File f, int age)
{
	if(age<=3) return false;
	if(f.drive.among("custom", "font")) return false;
	return true;
}


//MegaTexturing constants ///////////////////////////////

enum //the alignment of a subTexture. Also the number of mipmaps.
SubTexCellBits	= 3,
SubTexCellSize	= 1<<SubTexCellBits,
SubTexCellMask 	= SubTexCellSize-1,

//Maximum size of textures. Hardware dependent. Max 16K
SubTexSizeBits	= 14,   //MAX 14bits / 16K
SubTexMaxSize	= 1<<SubTexSizeBits,
SubTexSizeMask 	= SubTexMaxSize-1;


enum //starting size for textures
//MegaTexMinSizeBits = 13,               //todo: !!!!!!!! must be set when app starts
//MegaTexMinSize = 1<<MegaTexMinSizeBits,

//MegaTexMaxSizeBits = 13,              //todo: !!!!!!!! must be set when app starts
//MegaTexMaxSize = 1<<MegaTexMaxSizeBits,

SubTexIdxBits 	= 16,
SubTexIdxCnt	= 1<<SubTexIdxBits;

//not used SubTexPosBits = MegaTexMaxSizeBits-SubTexCellBits,

//MegaTexIdxBits = 4,                 //in the shader, it is max 8. -> samplerArray[8]
enum MegaTexMaxCnt = 3; //max = 1<<MegaTexIdxBits
//Todo: !!!!!!!! must be set when app starts



//SubTexInfo struct ////////////////////////

enum SubTexChannelConfig
{
	R	, G	, B	, A	,
	RG	, GB	, BA	, unknown0	,
	RGB	, GBA	, unknown1	, unknown2	,
	RGBA	, unknown3	, unknown4	, RGBA_ClearType	
}

//packed data struct that
private struct SubTexInfo
{
	 align(1): import std.bitmanip;
	mixin(
		bitfields!(
			uint, "cellX",	 14, uint, "texIdx_lo",	 2,
			uint, "cellY",	 14, uint, "texIdx_hi",	 2, //texIdxHi = 3-x, to be likely visible
			uint, "width1",	 14, uint, "texChn_lo",	 2,
			uint, "height1",	 14, uint, "texChn_hi",	 2
		)
	);
	
	this(in ivec2 pos, in ivec2 size, int texIdx, in SubTexChannelConfig texChn)
	//pos and size is in pixels
	{
		enforce(
			(pos.x & SubTexCellMask)==0
			&& (pos.y & SubTexCellMask)==0, "unaligned pos"
		);
		
		enforce(
			pos.x>=0 && size.x>0 && pos.x+size.x<=SubTexMaxSize
			&& pos.y>=0 && size.y>0 && pos.y+size.y<=SubTexMaxSize, 
			"pos, size: Out of range. pos:%s size:%s pos+size:%s SubTexMaxSize:%s"
			.format(pos, size, pos+size, SubTexMaxSize)
		);
		enforce(texIdx.inRange(0, MegaTexMaxCnt-1), "texIdx: Out of range");
		
		cellX =	pos.x>>SubTexCellBits;	texIdx_lo = texIdx.getBits(0, 2);
		cellY =	pos.y>>SubTexCellBits;	texIdx_hi = texIdx.getBits(2, 2);
		auto tc	= cast(int)texChn;	
		width1	= size.x-1;	texChn_lo = tc.getBits(0, 2);
		height1	= size.y-1;	texChn_hi = tc.getBits(2, 2);
	}
	
	bool isNull() const
	{ return this==typeof(this).init; }
	ivec2 pos() const
	{ return ivec2(cellX, cellY)<<SubTexCellBits; }
	
	int width()	const
	{ return width1+1; }
	int height()	const
	{ return height1+1; }
	auto size()	const
	{ return ivec2(width, height); }
	auto bounds()	const
	{ return ibounds2(pos, pos+size); }
	
	size_t sizeBytes() const
	{ return width*height*4/+...instead of channelCnt, to show actual memory usage+/; }
	
	int texIdx() const
	{ return texIdx_lo | texIdx_hi<<2; }
	
	auto	channelConfig() const
	{ return cast(SubTexChannelConfig)(texChn_lo | texChn_hi<<2); }
	int	channelBase	 () const
	{ return texChn_lo; }
	int	channelCnt	 () const
	{ return texChn_hi+1; }
	
	auto toString() const
	{
		return isNull 	? "SubTexInfo(null)" 
			: "SubTexInfo(pos:(%-4d, %-4d), size:(%-4d, %-4d), mega:%d, chn:%4s)"
			.format(pos.x, pos.y, size.x, size.y, texIdx, channelConfig);
	}
}

auto longToSubTexInfo(long val)
{
	SubTexInfo si;
	si = *(cast(SubTexInfo*)&val);
	return si;
}

class MegaTexture
{
	 //MegaTexture class /////////////////////////////
	private:
		int texIdx, channels;
		GLTexture glTexture;
	
		void resizeGLTexture()
	{
		if(glTexture.size!=texSize) {
			glTexture.fastBind;
			glTexture.resize(texSize);
		}
	}
	
	public:
		MaxRectsBin bin;
		auto texSize() const
	{ return ivec2(bin.width, bin.height) << SubTexCellBits; }
	
	public:
		this(int texIdx, int channels)
	{
		enforce(texIdx.inRange(0, MegaTexMaxCnt-1), "texIdx out of range");
		enforce(channels==4, "Only 4chn Megatextures supported");
		
		this.texIdx = texIdx;
		this.channels = channels;
		
		const 	minSize = min(MegaTexMinSize, gl.maxTextureSize)>>SubTexCellBits,
			maxSize = min(MegaTexMaxSize, gl.maxTextureSize)>>SubTexCellBits;
		bin = new MaxRectsBin(minSize, minSize, maxSize, maxSize);
		
		glTexture = new GLTexture(
			"MegaTexture[%d]".format(texIdx), 
			texSize.x, texSize.y, GLTextureType.RGBA8, 
			false/*no mipmap*/
		);
		//Todo: MegaTexture.mipmap
		
		glTexture.bind;
	}
	
		~this() {
		glTexture.free;
		bin.free;
	}
	
		void reinitialize() { bin.reinitialize; }
	
		override string toString() { return "MegaTexture(%s)".format(glTexture); }
	
		bool add(in ivec2 size, int channels, int data/*subTexIdx*/, out SubTexInfo info)
	{
		auto cellSize = (size+SubTexCellMask)>>SubTexCellBits,
				 rect = bin.add(cellSize.x, cellSize.y, data);
		
		if(rect is null) {
			//Todo: MegaTexture.repack()
			return false; //unable to allocate because out of space.
		}
		
		resizeGLTexture;//apply the possible binSize change
		
		auto pos = ivec2(rect.x, rect.y)<<SubTexCellBits;
		info = SubTexInfo(pos, size, texIdx, cast(SubTexChannelConfig)((channels-1)*4));
		//Todo: MegaTexture.channels = 1, 2, 3, not just 4
		
		return true;
	}
	
		void remove(in int data)
	{
		bin.remove(data).enforce("nothing to remove");
		//if(!bin.remove(data)) WARN("bin: nothing to remove ", data);
	}
	
		void dump() const
	{ bin.dump; }
	
		void debugDraw(Drawing dr)
	{
		dr.scale(SubTexCellSize); scope(exit) dr.pop;
		
		dr.lineWidth = -1;
		
		dr.lineStyle = LineStyle.normal;
		foreach(r; bin.freeRects) {
			dr.color = clWhite;
			dr.drawRect(r.bounds.inflated(-0.25f));
		}
		
		dr.lineStyle = LineStyle.dash;
		foreach(j, r; bin.rects) {
			dr.color = clBlack; //clVga[(cast(int)j % ($-1))+1];
			dr.alpha = 0.25;
			dr.fillRect(r.bounds);
			dr.alpha = 1;
			
			dr.color = clWhite;
			dr.drawRect(r.bounds.inflated(-0.25f));
		}
		
		dr.lineStyle = LineStyle.normal;
		
		dr.color = clWhite;  dr.drawRect(0, 0, bin.width, bin.height);
	}
	
		size_t sizeBytes() const { return glTexture ? glTexture.sizeBytes : 0; }
}


class InfoTexture
{
	 //InfoTexture class ////////////////////////////////
	private:
		enum TexelsPerInfo = 2; //for rgba & 8byte subTexInfo
		enum TexWidth = 512, InfoPerLine = TexWidth/TexelsPerInfo;
	
	public  GLTexture glTexture;
	
		int[int] lastAccessed; //last globalUpdateTick when accessed/updated
	
	
	public	SubTexInfo[] infoArray;
		int[]	freeIndices;
	
		int capacity() const
	{ return InfoPerLine * glTexture.height; }
		int length() const
	{ return cast(int)infoArray.length; }
	
		void upload(int idx)
	{
		 //Opt: ezt megcsinalni kotegelt feldolgozasura
		glTexture.fastBind;
		glTexture.upload(infoArray[idx..idx+1], idx % InfoPerLine * TexelsPerInfo, idx / InfoPerLine, 2, 1);
	}
	
		void grow()
	{
		glTexture.fastBind;
		glTexture.resize(TexWidth, glTexture.height*2); //exponential grow
	}
	
		bool isValidIdx(int idx) const
	{ return idx.inRange(infoArray); }
	
		void checkValidIdx(int idx) const
	{
		 //Todo: refactor to isValidIdx
		enforce(isValidIdx(idx), "subTexIdx out of range (%s)".format(idx));
		//ez nem kell, mert a delayed loader null-t allokal eloszor. 
		//enforce(!infoArray[idx].isNull, "invalid subTexIdx (%s)".format(idx));
	}
	
		void accessedNow(int idx)
	{
		if(!global_disableSubtextureAging)
		lastAccessed[idx] = application.tick;
	}
	
	public:
	
		this()
	{
		enforce(SubTexInfo.sizeof==8, "Only implemented for 8 byte SubTextInfo");
		
		glTexture = new GLTexture(
			"InfoTexture", TexWidth, 1/*height*/, 
			GLTextureType.RGBA8, 
			false/*no mipmap*/
		);
		glTexture.bind;
	}
	
		~this()
	{ glTexture.free; }
	
		//peeks the next subTex idx. Doesn't allocate it. Must be analogous with add()
		//Note: this technique is too dangerous. Must add the info, but not upload.
		/*
		int peekNextIdx() const{
				if(!freeIndices.empty){//reuse a free slot
					return freeIndices[$-1];
				}else{ //add an extra slot
					return cast(int)infoArray.length;
				}
			}
	*/
	
		//allocates a new subTexture slot
	
		int add(in SubTexInfo info, Flag!"uploadNow" uploadNow= Yes.uploadNow)
	{
		//ez nem kell, mert a delayed loader pont null-t allokal eloszor: 
		//enforce(!info.isNull, "cannot allocate SubTexInfo.null");
		
		int actIdx;
		
		//this must be analogous with peekNextIdx
		if(!freeIndices.empty) {
			//reuse a free slot
			actIdx = freeIndices.popLast;
			infoArray[actIdx] = info;
		}
		else {
			 //add an extra slot
			infoArray ~= info;
			actIdx = cast(int)infoArray.length-1;
			
			enforce(actIdx<SubTexIdxCnt, "FATAL: SubTexIdxCnt limit reached");
			
			if(capacity<infoArray.length) grow;
		}
		
		accessedNow(actIdx);
		
		if(uploadNow) upload(actIdx);
		
		return actIdx;
	}
	
		//removes a subTex by idx
		void remove(int idx)
	{
		checkValidIdx(idx);
		
		infoArray[idx] = SubTexInfo.init;
		freeIndices ~= idx;
		
		upload(idx); //upload the null for safety
		//Todo: feltetelesen fordithatova tenni ezeket a felszabaditas utani zero filleket
	}
	
		//gets a subTexInfo by idx
		SubTexInfo access(int idx)
	{
		checkValidIdx(idx);
		accessedNow(idx);
		return infoArray[idx];
	}
	
		void modify(int idx, in SubTexInfo info)
	{
		checkValidIdx(idx);
		accessedNow(idx);
		infoArray[idx] = info;
		upload(idx);
	}
	
	
		void dump() const
	{
		//infoArray.enumerate.each!writeln;
		//!!! LDC 1.20.0 win64 linker bug when using enumerate here!!!!!
		
		//foreach(i, a; infoArray) writeln(tuple(i, a));
		//!!! linker error as well
		
		//foreach(i, a; infoArray) writeln(tuple(i, i+1));
		//!!! this is bad as well, the problem is not related to own structs, just to tuples
		
		foreach(i, a; infoArray) writefln("(%s, %s)", i, a);  //this works
	}
	
		size_t sizeBytes() const
	{ return glTexture ? glTexture.sizeBytes : 0; }
}

//Todo: make the texture class
class Texture
{
	 //Texture class /////////////////////////////////
	//this holds all the info to access a subTexture
	private:
		TextureManager owner;
		int idx;
		File file;
	
		private this(TextureManager owner, int idx)
	{
		 //this is unnamed and empty
		this.owner = owner;
		this.idx = idx;
	}
	
	public:
		this(TextureManager owner, int idx, File file, bool delayed = false)
	{
		this(owner, idx);
		this.file = file;
	}
	
		override string toString() const
	{ return "Texture(#%d, %s)".format(idx, file); }
}    deprecated(`Use bitmaps("name", bitmap)")`) class CustomTexture
{
	 //CustomTexture ///////////////////////////////
	const string name;
	protected {
		Bitmap bmp;
		bool mustUpload;
	}
	
	this(string name="")
	{ this.name = name.strip.length ? name : this.identityStr; }
	
	void clear()
	{ bmp.free; mustUpload = false; }
	void update()
	{ mustUpload = true; }
	void update(Bitmap bmp)
	{ this.bmp = bmp; mustUpload = true; }
	
	int texIdx()
	{
		if(bmp is null) return -1; //nothing to draw
		if(!textures.isCustomExists(name)) mustUpload = true; //prepare for megaTexture GC
		Bitmap b = chkClear(mustUpload) ? bmp : null;
		return textures.custom(name, b);
	}
	
	ivec2 size()const
	{ return bmp ? bmp.size : ivec2(0); }
	
	auto getFile()
	{ return File(`custom:\`~name); }
	auto getBmp()
	{ return bmp; }
}


class TextureManager
{
	 //TextureManager class /////////////////////////////////
	private:
		InfoTexture infoTexture;
		MegaTexture[] megaTextures;
	
		int[File] byFileName; //texIdx of File
	
		bool[int] pendingIndices; //files being loaded by a worker thread
		bool[int] invalidateAgain; //files that cannot be invalidated yet, because they are loading right now
	
		void enforceSize(const ivec2 size)
	{
		enforce(
			size.x<=SubTexMaxSize && size.y<=SubTexMaxSize,
			"Texture too big (%s)".format(size)
		);
		enforce(
			size.x<=gl.maxTextureSize && size.y<=gl.maxTextureSize,
			"Texture too big on current opengl implementation (%s)".format(size)
		);
	}
	
		void chkMtIdx(int mtIdx)
	{
		enforce(
			mtIdx.inRange(megaTextures), 
			"mtIdx out of range (%s !in [0..%s])".format(mtIdx, megaTextures.length)
		);
	}
	
		bool isCompatible(const Bitmap bmp, const MegaTexture mt)
	{
		return true;
		//mt.channels==bmp.channels;
	}
	
		void addNewMegaTexture(int channels)
	{
		if(megaTextures.length>=MegaTexMaxCnt) { raise("Out of megatextures"); }
		megaTextures ~= new MegaTexture(megaTextures.length.to!int, channels);
	}
	
		int allocSubTexInfo(in SubTexInfo info = SubTexInfo.init)
	{
		 //info should point to a 'loading progress image'
		return infoTexture.add(info);
	}
	
		private int garbageCycle; //just an ever increasing index
	
		bool isPending(int idx)
	{ return idx in pendingIndices && pendingIndices[idx]; }
	
		bool isInvalidatingAgain(int idx)
	{ return idx in invalidateAgain && invalidateAgain[idx]; }
	
		bool isUntouchable(int idx)
	{ return isPending(idx) || isInvalidatingAgain(idx); }
	
		void garbageCollect()
	{
		auto _ = PROBE("Textures.GC");
		
		 //garbageCollect() /////////////////////////////////////////
		int mtIdx = garbageCycle % cast(int)megaTextures.length;
		chkMtIdx(mtIdx);
		
		garbageCycle++; //set the index for the next garbageCollect
		
		//LOG("GCycle", garbageCycle);
		
		auto allInfos = collectSubTexInfo2.filter!(i => i.info.texIdx==mtIdx).array; //on the current megatexture
		//auto infosToUnload	= allInfos.filter!(i =>  i.canUnload).array;
		//auto infosToSave	= allInfos.filter!(i => !i.canUnload).array;
		
		//no need to wait pending because they are not allocated yet in the bins and update() only called from main thread, also it can start a GC
		/+
			while(allInfos.map!(i => isPending(i.idx)).any){
				LOG("Waiting for pending textures...");
				sleep(10);
			}
		+/
		
		//LOG("MegaTexture.GC   mtIdx:", mtIdx, "  removing:", infosToUnload.length, "  keeping:", infosToSave.length, "   total:", collectSubTexInfo2.count);
		
		//Note: Tere is no fucking glReadSubtexImage. So everything must be dropped. Custom textures must be uploaded on every frame if needed.
		//raise("notImpl " ~ info.text);
		
		foreach(info; allInfos) { invalidate(info.file); }
		
		megaTextures[mtIdx].reinitialize;
		
		//Todo: Ugly lag and one frame of garbage when the DefaultFont_subTexIdxMap is cleared.
		//Not nice. But seems safe. It takes a lot of time, to draw the fonts again and it is impossible to read them back from the reinitialized texture.
		//solution -> dedicated megatexture to the defaultfont
		DefaultFont_subTexIdxMap.clear; //UI uses this cache, and now it is invalid because of the GC
	}
	
		SubTexInfo allocSpace(int subTexIdx, in Bitmap bmp)
	{
		enforce(bmp);
		enforceSize(bmp.size);
		
		SubTexInfo info;
		bool tryAdd(MegaTexture mt) { return isCompatible(bmp, mt) && mt.add(bmp.size, bmp.channels, subTexIdx, info); }
		
		//the order could be improved
		foreach(mt; megaTextures) if(tryAdd(mt)) return info;
		
		//at this point failed to add to the current set of megatextures.
		
		if(megaTextures.length>=MegaTexMaxCnt)
		{
			if(0) {
				raise("Out of megatextures"); //Todo: make a texture garbage collect cycle here
			}
			else {
				foreach(i; 0..MegaTexMaxCnt)
				{
					garbageCollect;
					foreach(mt; megaTextures) if(tryAdd(mt)) return info; //try again
				}
			}
		}
		else {
			
			if(megaTextures.length) MegaTexMinSize = MegaTexMaxSize;
			//All textures use the max size expect the first. (small apps ned only 512*512)
			
			addNewMegaTexture(4);
			foreach(mt; megaTextures) if(tryAdd(mt)) return info; //try again
		}
		
		enforce("Unable to allocate subTexture. "~bmp.size.text);
		assert(0);
	}
	
		void uploadData(SubTexInfo info, Bitmap bmp, bool dontUploadData=false)
	{
		auto mtIdx = info.texIdx;
		
		chkMtIdx(mtIdx);
		auto mt = megaTextures[mtIdx];
		
		if(!dontUploadData) {
			mt.glTexture.fastBind;
			
			//Todo: this is wasting ram and not work with custom non 4ch bitmaps
			//Note: temporary solution: there is a nondestructive converter inside
			//bmp.channels = 4;
			mt.glTexture.upload(bmp, info.pos.x, info.pos.y, info.size.x, info.size.y);
		}
	}
	
		/*
		ubyte[] downloadData(SubTexInfo info){
			auto mtIdx = info.texIdx;
		
			chkMtIdx(mtIdx);
			auto mt = megaTextures[mtIdx];
		
			mt.glTexture.fastBind;
			mt.glTexture.download(bmp, info.pos.x, info.pos.y, info.size.x, info.size.y);
		}
	*/
	
		void uploadSubTex(int idx, Bitmap bmp, bool dontUploadData=false)
	{
		//it has an existing id
		auto info = allocSpace(idx, bmp);
		infoTexture.modify(idx, info);
		uploadData(info, bmp, dontUploadData);
	}
	
		int createSubTex(Bitmap bmp)
	{
		//creates a new one, returns the idx
		//NO! Null texture is not allowed here!!! if(bmp.empty) return 0; //special NULL texture
		//this is checked by allocSpace. enforce(bmp && !bmp.empty);
		
		/+
			 old and bogus version
			auto idx = infoTexture.peekNextIdx; 	//returns 8
			auto info = allocSpace(idx, bmp);	//GC deletes info[0..4], and allocspace if susseeded, stores the subtexIdx in info.
			infoTexture.add(info);	//and this allocates on 3 (last freed) not 8.  BUG!!!!!!!!!!!
		+/
		
		//new version allowing GC to manipulate subTexInfos.
		auto idx = infoTexture.add(longToSubTexInfo(-1)/+just a marking, that it's not null+/, No.uploadNow);
		auto info = allocSpace(idx, bmp);
		infoTexture.modify(idx, info);
		
		uploadData(info, bmp);
		return idx;
	}
	
		void removeSubTex(int idx)
	{
		//get SubTexInfo
		auto info = infoTexture.access(idx);
		
		//get megaTex idx
		auto mtIdx = info.texIdx;
		chkMtIdx(mtIdx);
		
		//clear the area with clFuchsia for debug
		if(DEBUG_clearRemovedSubtexArea)
		with(megaTextures[mtIdx].glTexture) {
			fastBind;
			fill(RGBA(0xFFFF00FF), info.pos.x, info.pos.y, info.size.x, info.size.y);
		}
		
		
		megaTextures[mtIdx].remove(idx);
		infoTexture.remove(idx);
	}
	
		Bitmap[] bmpQueue;
	
	public:
		this() { infoTexture = new InfoTexture; }
	
		bool update()
	{
		auto _ = PROBE("Textures.Update");
		bool inv;
		
		auto t0 = QPS;
		
		enum UploadTextureMaxTime = 1.0*second/60;
		size_t uploadedSize;
		enum TextureFlushLimit = 8 << 20;
		do
		{
			
			Bitmap bmp;
			synchronized(textures) {
				if(synchLog) LOG("bmpQueue.popFirst(null) before");
				bmp = bmpQueue.popFirst(null);
				if(synchLog) LOG("bmpQueue.popFirst(null) after");
			}
			
			if(!bmp) break;
			
			auto idx = bmp.tag;
			
			pendingIndices.remove(idx); //not pending anymore so it can be reinvalidated
			
			if(idx in invalidateAgain)
			{
				//WARN("Delayed loaded bmp is in invalidateAgain.", idx);
				
				uploadSubTex(idx, bmp, true);
				//this is here to finalize the allocation of the texture before the invalidation
				//Opt: disable the upload of this texture data
				
				invalidateAgain.remove(idx);
				foreach(f, i; byFileName)
				if(i == idx) {
					 //Opt: slow linear search
					//WARN("Reinvalidating", f, idx);
					invalidate(f);
					break;
				}
				
			}
			else
			{
				uploadSubTex(idx, bmp);
				
				//flush at every N megabytes so the transfer time of this particular upload can be measured and limited.
				uploadedSize += bmp.sizeBytes;
				if(uploadedSize >= TextureFlushLimit) {
					uploadedSize -= TextureFlushLimit;
					gl.flush;
				}
			}
			
			inv = true;
			
		}
		while(QPS-t0<UploadTextureMaxTime/*sec*/);
		
		return inv;
	}
	
		void invalidate(in File fileName)
	{
		if(auto idx = (fileName in byFileName))
		{
			if(*idx in pendingIndices) {
				//WARN("Texture loader is pending", fileName, *idx);
				invalidateAgain[*idx] = true;
				return;
			}
			enforce(byFileName.remove(fileName), "Unable to remove "~fileName.fullName);
			removeSubTex(*idx);
			//LOG("invalidated ", fileName, "  idx:", *idx);
		}
		else
		{
			//LOG("no need to invalidate, doesn't exists", fileName);
		}
	}
	
	
	
		bool isCustomExists(string name)
	{ return (File(`custom:\`~name) in byFileName) !is null; }
	
		bool exists(File f)
	{ return (f in byFileName) !is null; }
		bool exists(string f)
	{ return (File(f) in byFileName) !is null; }
	
		int custom(string name, Bitmap bmp=null)
	{
		 //if bitmap != null then refresh
		enum log = false;
		if(log) "testures.custom(%s, %s)".writefln(name, bmp);
		
				auto fileName = File(`custom:\`~name);
		
		if(auto a = (fileName in byFileName))
		{
			 //already exists?
			if(bmp) {
				 //reupdate existing
								removeSubTex(*a);
								auto idx = createSubTex(bmp);
								byFileName[fileName] = idx;
				if(log) "Updated subtex %s:".writefln(fileName);
								return idx;
			}
			else {
				 //no change, just return the existing handle
				if(log) "Found subtex %s:".writefln(fileName);
								return *a;
			}
		}
		else
		{
			 //this is a new entry
						if(bmp is null)
			{
				bmp = new Bitmap(image2D(8, 8, RGBA(clFuchsia)));
				//if no bmp, just create a purple placeholder
			}
						auto idx = createSubTex(bmp);
						byFileName[fileName] = idx;
			if(log) "Created subtex %s:".writefln(fileName);
						return idx;
		}
	}
	
		SubTexInfo accessInfo(int idx)
	{
		 //todo ez egy texture class-ba kell, hogy benne legyen
		return infoTexture.access(idx);
	}
		
		int opIndex(F)(F file)
	{ return access(file, Yes.delayed); }
	
		int accessNow(F)(F file)
	{ return access(file, No.delayed); }
	
		
		SubTexInfo opIndex(int idx)
	{ return infoTexture.access(idx); }
	
		void dump() const
	{ infoTexture.dump; }
	
		GLTexture[] getGLTextures()
	{ return infoTexture.glTexture ~ megaTextures.map!(a => a.glTexture).array; }
	
		ivec2 textureSize(int idx)
	{
		return infoTexture.isValidIdx(idx) 	? accessInfo(idx).size
			: ivec2(0);
	}
	
		ivec2 textureSize(File file)
	{ return textureSize(access(file, Yes.delayed)); }
	
		void uploadInplace(int idx, Bitmap bmp)
	{ uploadData(accessInfo(idx), bmp); }
	
		/// A SubTexInfo +
		struct SubTexInfo2
	{
		int idx, lastAccessed;
		File file;
		SubTexInfo info;
		
		bool canUnload() const
		{ return canUnloadTexture(file, application.tick - lastAccessed); }
		
		auto toString() const
		{ return format!"%-4s: %s age:%-5d %s"(idx, info, lastAccessed, file.fullName); }
	}
	
		void infoDump()
	{
		print("--------------- MegaTexture dump ----------------");
		foreach(i, info; infoTexture.infoArray)
		print(format!"%-3d : %-20s "(i, info));
		foreach(f; byFileName.keys.sort) { print(format!"%-3d : %-20s "(byFileName[f], f.nameWithoutExt)); }
	}
	
		int length() const
	{ return byFileName.length.to!int; }
		size_t usedSizeBytes() const
	{ return infoTexture.infoArray.map!(a => size_t(a.sizeBytes)).sum; }
		size_t poolSizeBytes() const
	{ return megaTextures.map!(mt => mt.sizeBytes).sum + infoTexture.sizeBytes; }
	
		auto megaTextureSizes() const
	{ return megaTextures.map!(m => m.texSize).array; }
	
		string megaTextureConfig() const
	{
		return megaTextureSizes.map!(
			s => s.x.shortSizeText!1024
				~ (s.x == s.y ? "" : "x"~s.y.shortSizeText!1024)
		).join(", ");
	}
	
		auto collectSubTexInfo2()
	{
		//Todo: this should be the main list.
		//although it's fast: For 2GB textures, it's only 0.2ms to collect. (Standard test images)
		
		//LOG("attempting to get subtexInfo2");
		//infoDump;
		
		SubTexInfo2[] res;
		
		foreach(file, idx; byFileName) {
			//LOG("retrieving ", file, "  idx:", idx);
			const info = infoTexture.infoArray[idx],
						lastAccessed = infoTexture.lastAccessed[idx];
			res ~= SubTexInfo2(idx, lastAccessed, file, info);
		}
		
		return res;
	}
	
		void debugDraw(Drawing dr)
	{
		 //debugDraw /////////////////////////////
		//print("Megatexture debug draw----------------------------");
		
		//megatexture debugging will not affect texture last-accessed statistics
		global_disableSubtextureAging = true;
		scope(exit) global_disableSubtextureAging = false;
		
		//collect all subtextures
		auto subTexInfos = collectSubTexInfo2;
		
		int ofs;
		foreach(megaIdx, mt; megaTextures)
		{
			dr.translate(0, ofs); scope(exit) { dr.pop; ofs += mt.texSize.y + 16; }
			
			//draw background
			dr.color = clFuchsia;
			dr.alpha = 1;
			dr.fillRect(bounds2(vec2(0), mt.texSize));
			
			//draw subtextures
			foreach(const si; subTexInfos)
			if(si.info.texIdx==megaIdx)
			{
				dr.color = clWhite;
				dr.drawGlyph(si.idx, bounds2(si.info.bounds), clGray);
				//Todo: drawRect support for ibounds2
				
				if(!si.canUnload) {
					dr.lineWidth=-3; dr.color = clYellow;
					dr.drawX(bounds2(si.info.bounds));
				}
			}
			
			
			//draw free and used rects and frame
			mt.debugDraw(dr);
		}
		
	}
	
	
		ulong[File] bitmapModified; 
		//Todo: this change detection is lame
		//Bug: this is also a memory leak.
	
		/// NOT threadsafe by design!!! Gfx is mainthread only anyways.
		int access(File file, Flag!"delayed" fDelayed)
	{
		enum log = false;
		
		const delayed = fDelayed && EnableMultiThreadedTextureLoading;
		
		auto bmp = bitmaps(file, delayed ? Yes.delayed : No.delayed, ErrorHandling.ignore);  
		//Opt: this synchronized call is slow. Should make a very fast cache storing images accessed in the current frame.
		auto modified = bmp.modified.toId_deprecated; //Todo: deprecate toId and use the DateTime itself
		
		if(log) LOG(bmp);
		if(auto existing = file in byFileName)
		{
			
			//Todo: ennel az egyenlosegjelnel 2 bug van:
			//1: ha ==, akkor a thumbnailnak 0 a datetime-je
			/+
				2: ha != (allandoan ujrafoglalja, nem a kivant mukodes), akkor a 
					nearest sampling bugja tapasztalhato a folyamatosan athelyezett 
					thumbnail image-k miatt. Mint egy hernyo, ciklikusan 1 pixelt csuszik.
			+/
			if(modified == bitmapModified.get(file, 0))
			{
				if(log) LOG("\33\12existing\33\7");
				return *existing; //existing texture and matching modified datetime
			}
			if(log) LOG("\33\14removing\33\7");
			removeSubTex(*existing); //It's changed, must remove
		}
		//upload new texture
		if(log) LOG("\33\16creating\33\7", modified);
		
		auto idx = createSubTex(bmp);
		byFileName[file] = idx;
		bitmapModified[file] = modified;
		return idx;
	}
	
	void refresh_timeView(File file)
	{
		auto bmp = bitmaps(file, Yes.delayed, ErrorHandling.ignore);  
		if(bmp.loading) return;
		byFileName.update(
			file,
			() => createSubTex(bmp),
			(ref int idx){
				removeSubTex(idx);
				idx = createSubTex(bmp);
			}
		);
	}
	
	void refresh_timeView_multi(File[] files)
	{
		void update(Bitmap bmp)
		{
			if(bmp && !bmp.loading)
			byFileName.update(
				bmp.file,
				() => createSubTex(bmp),
				(ref int idx){
					removeSubTex(idx);
					idx = createSubTex(bmp);
				}
			);
		}
		
		foreach(bmp; bitmapQuery_accessDelayedMulti(files)) update(bmp);
		
		//foreach(bmp; files.map!(file => bitmaps(file, Yes.delayed, ErrorHandling.ignore))) update(bmp);
	}
	
	
	
		auto _getInternalFileToSubTexIdxAA()
	{
		//Note: TimeView/KarcLogger needs this, to do fast bulk processing.
		return byFileName;
	}
}