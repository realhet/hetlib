module het.db; 

import het; 

/////////////////////////////////////////////////////////////////////
/// Archiver                                                      ///
/////////////////////////////////////////////////////////////////////

/// This encapsulates custom data objects in a stream. Any type of bytestream will do, no packaging is needed.
/// The data can be identified and easily skipped from both directions. Contains crc.

class Archiver {
	
		enum DefaultMasterRecordMaxSize = 0x200; //DON'T CHANGE!
		enum InitialrecordPoolSize = 0x100; 
	
		enum LeadInSize = 5*4; 
		enum LeadOutSize = 5*4; 
		enum MaxLeadSize = max(LeadInSize, LeadOutSize); 
		enum PlainFrameSize = LeadInSize + LeadOutSize; 
	
		static struct JumpRecord
	{
		enum Marking = "$JMP"; 
		ulong from, to, over; 
	} 
		static assert(JumpRecord.sizeof==24); 
	
		size_t calcJumpRecordSizeBytes()const
	{
		return PlainFrameSize +JumpRecord.Marking.length.alignUp(4) +JumpRecord.sizeof.alignUp(4)
			   +(compr=="" ? 0 : 4); 
	} 
	
		static struct MasterRecord
	{
		 //MasterRecord ///////////////////////////////////
		enum Marking = "$MR"; 
		
		//all offsets and sizes in bytes
		@STORED
		{
			string volume, originalFileName; 
			ulong masterRecordBegin,
						masterRecordEnd,
						recordPoolBegin,
						recordPoolEnd,
						blobPoolBegin,
						totalRecordCount,
						totalRecordSize,
						totalJumpCount,
						totalJumpSize,
						totalBlobCount,
						totalBlobSize; 
			DateTime created, modified; 
			
			//Todo: archiveEnd: after this ofs, growth is not possible  0=endless
		} 
		
		void checkConsistency()
		{
			auto a = [masterRecordBegin, masterRecordEnd, recordPoolBegin, recordPoolEnd, blobPoolBegin]; 
			enforce(a.map!q{(a&3)==0}.all, "FATAL MRCC Fail: unaligned"); 
			enforce(a.equal(a.sort)      , "FATAL MRCC Fail: unordered"); 
		} 
		
		private bool valid; //this is set by outside conditions
		T opCast(T:bool)() const
		{ return valid; } 
		
		ulong actualMasterRecordMaxSize() const
		{
			enforce(masterRecordEnd>=masterRecordBegin, "Invalid MR size"); 
			return masterRecordEnd-masterRecordBegin; 
		} 
		
		void initializeNew(File file, string volume, ulong baseOffset, ulong recordPoolInitialSize)
		{
			this = MasterRecord.init; 
			this.volume = volume; 
			originalFileName	=	file.fullName; 
			masterRecordBegin	=	baseOffset; 
			masterRecordEnd	=	masterRecordBegin	+  DefaultMasterRecordMaxSize; 
			recordPoolBegin		= masterRecordEnd; 	
			recordPoolEnd	= recordPoolBegin	+	recordPoolInitialSize; 
			blobPoolBegin     =	recordPoolEnd; 	
			created = modified = now; 
		} 
		
		string stats(in File file, string serial)
		{
			string s = "Archive stats: "; 
			if(!valid)
			return s~"INVALID\n"; 
			s ~= file.fullName ~ "\n"; 
			if(icmp(originalFileName, file.fullName))
			s ~= "  Original file: "~originalFileName~"\n"; 
			
			s ~= "  Volume  : "~volume.quoted~"   Serial: "~serial.quoted~"\n"; 
			s ~= "  Created : "~created.text ~"\n"; 
			s ~= "  Modified: "~modified.text~"\n"; 
			
			void BE(string name, ulong begin, ulong end)
			{ s ~= format!"  %s begin: %10d  end: %10d  size: %10dB\n"(name, begin, end, end-begin); } 
			
								 BE("Master record", masterRecordBegin, masterRecordEnd); 
								 BE("Record pool  ", recordPoolBegin,     recordPoolEnd); 
			const siz = file.size; 
			s ~= format!"  Blob pool     begin: %10d  capacity: %4sB\n"(blobPoolBegin, siz>blobPoolBegin ? (file.size-blobPoolBegin).shortSizeText!1024 : "- "); 
			
			void CTA(string name, ulong count, ulong size)
			{ s ~= format!"  %s count: %7d  total size: %4sB  avg size: %4sB\n"(name, count, size.shortSizeText!1024, count ? (size/count).shortSizeText!1024 : "- "); } 
			
			CTA("Record", totalRecordCount, totalRecordSize); 
			CTA("Jump  ", totalJumpCount  , totalJumpSize); 
			CTA("Blob  ", totalBlobCount  , totalBlobSize); 
			return s; 
		} 
	} 
	
		//finds a datablock that possibly contains data. It helps in reconstucting archived blocks.
	/*
		static sizediff_t findNonRedundantBlock(File f, size_t blockSize, size_t startOffset, float threshold, Flag!"exponentialSearch" exponentialSearch){
			auto fsize = f.size, fofs = startOffset; //skip first block
		
			bool eof(){ return fofs+blockSize>fsize; }
			bool check(){ return !eof && f.read(true, fofs, blockSize).calcRedundance<threshold; }
		
			while(!eof){
				if(check) return fofs;
				fofs = exponentialSearch ? fofs*2 : fofs+blockSize;
			}
			return -1;
		}
	*/
	
	
		//Archiver main /////////////////////////////////////////////////////////////////////
	
		private SeedStream seedStream; 
	
		this()
	{
		seedStream = SeedStream_pascal(56432); 
		
		__gshared static bool selfTestDone; 
		if(chkSet(selfTestDone))
		selfTest; 
	} 
	
		void initSeedStream(uint a, uint c)
	{ seedStream = SeedStream(a, c); } 
		void testSeedStream()
	{ seedStream.test; } 
	
		private MasterRecord masterRecord; 	   auto getMasterRecord()	const
	{ return masterRecord; } 
		File file; 	   auto getFile()	const
	{ return file; } 
		private string compr; 
	
		void close()
	{
		file = File.init; 
		masterRecord = masterRecord.init; 
		compr = ""; 
	} 
	
		bool valid() const
	{ return masterRecord.valid && file.exists; } 
	
		string stats()
	{ return masterRecord.stats(file, seedStream.a.to!string(16)~'-'~seedStream.c.to!string(16)); } 
	
		private void write_internal(in void[] rec, ulong ofs)
	{
		masterRecord.checkConsistency; 
		file.write(rec, ofs, masterRecord.masterRecordBegin>0 ? Yes.preserveTimes : No.preserveTimes); //Note: don't change datetime when this archive is attached to the end of another file.
	} 
	
		private void padRight(ref uint[] data, ulong maxSizeBytes)
	{
		enforce((maxSizeBytes&3)==0, "align4 error"); 
		while(data.sizeBytes < maxSizeBytes)
		data ~= seedStream.fetchFront; 
	} 
	
		private ulong actualFrameSize(ulong headerSizeBytes, ulong dataSizeBytes) const
	{ return PlainFrameSize + (compr!="" ? 4 : 0) + headerSizeBytes.alignUp(4) + dataSizeBytes.alignUp(4); } 
	
		private void writeMasterRecord()
	{
		masterRecord.modified = now; 
		
		auto rec = createRecord(MasterRecord.Marking, masterRecord.toJson.compress, now.timestamp, compr); 
		padRight(rec, masterRecord.actualMasterRecordMaxSize); 
		
		enforce(rec.sizeBytes <= masterRecord.actualMasterRecordMaxSize, "Archive MR overflow. %d <= %d".format(rec.sizeBytes, masterRecord.actualMasterRecordMaxSize)); 
		write_internal(rec, masterRecord.masterRecordBegin); 
	} 
	
		private uint[] read_internal(bool mustSucceed, ulong ofs, ulong sizeBytes)
	{ return cast(uint[])file.read(mustSucceed, ofs, sizeBytes); } 
	
		private void readMasterRecord(in ulong ofs)
	{
		masterRecord = MasterRecord.init; 
		const data = read_internal(true, ofs, DefaultMasterRecordMaxSize),
			  res = decodeRecord(data, compr); 
		enforce(res.error=="", "Error decoding MR: "~res.error); 
		masterRecord.fromJson(res.data.uncompress.to!string); 
		enforce(masterRecord.masterRecordBegin==ofs, "MR offset mismatch. %d != %d".format(masterRecord.masterRecordBegin, ofs)); 
		
		masterRecord.checkConsistency; 
		
		masterRecord.valid = true; 
	} 
	
		private auto writeRecord(string fn, in void[] data)
	{
		with(masterRecord)
		{
			const rec = createRecord(fn, data.compress, now.timestamp, compr),
					 recSize = rec.sizeBytes,
					 requiredSize = recSize + calcJumpRecordSizeBytes; 
			
			enforce((recSize & 3 | requiredSize & 3) == 0, "FATAL: Alignment error"); //must be dword aligned
			
			bool fitsInrecordPool() const
			{ return masterRecord.recordPoolBegin + requiredSize <= masterRecord.recordPoolEnd; } 
			
			if(!fitsInrecordPool)
			{
				//must extend recordPool (1.5x exponential growth)
				void extendrecordPoolEnd()
				{ recordPoolEnd += max((totalRecordSize/2)&~3UL, requiredSize); } 
				
				if(recordPoolEnd==blobPoolBegin)
				{
					//there are no blobs at the end, it can extend as far as it's needed
					extendrecordPoolEnd; 
					blobPoolBegin = recordPoolEnd; 
				}else
				{
					//there are blobs in the way, must make a jump.
					auto jumpRec = createRecord(JumpRecord.Marking, [JumpRecord(recordPoolBegin, blobPoolBegin, recordPoolEnd)], now.timestamp, compr); 
					
					//Todo: calculate jumpRecSize properly
					enforce(calcJumpRecordSizeBytes == jumpRec.sizeBytes, "FATAL: jumpRecordSize mismatch  expected:%d  actual:%d".format(calcJumpRecordSizeBytes, jumpRec.sizeBytes)); 
					
					padRight(jumpRec, recordPoolEnd-recordPoolBegin); 
					enforce(jumpRec.sizeBytes == recordPoolEnd-recordPoolBegin, "FATAL: jumpRecord padding fail"); 
					
					write_internal(jumpRec, recordPoolBegin); 
					recordPoolBegin += jumpRec.sizeBytes; 
					
					totalJumpCount ++; 
					totalJumpSize += jumpRec.sizeBytes; 
					
					//allocate new recordPool after the blobs
					recordPoolBegin = blobPoolBegin; 
					recordPoolEnd = recordPoolBegin; 
					extendrecordPoolEnd; 
					blobPoolBegin = recordPoolEnd; 
				}
			}
			enforce(fitsInrecordPool, "Fatal error: doesn't fitsInrecordPool"); 
			
			//write the file and adjust the pool
			auto res = Bounds!ulong(recordPoolBegin, recordPoolBegin+recSize); 
			write_internal(rec, recordPoolBegin); 
			
			recordPoolBegin += recSize; 
			totalRecordSize += recSize; 
			totalRecordCount ++; 
			
			writeMasterRecord; //always write it for safety
			
			return res; 
		}
	} 
	
		private auto writeBlobRecord(string fn, in void[] data)
	{
		with(masterRecord)
		{
			const rec = createRecord(fn, data, now.timestamp, compr),
				  recSize = rec.sizeBytes; 
			
			auto res = Bounds!ulong(blobPoolBegin, blobPoolBegin+recSize); 
			write_internal(rec, blobPoolBegin); 
			
			//write the file and adjust the pool
			blobPoolBegin += recSize; 
			totalBlobSize += recSize; 
			totalBlobCount ++; 
			
			//Note: Dont write master record here! Only write master record after a normal record.
			//That is the end of that transaction! Blob writing is just the middle of a transaction.
			//NO!!!! writeMasterRecord; //NO -> always write it for safety
			
			return res; 
		}
	} 
	
		/+
		private auto findMasterRecordOfs(){
				auto ofs = findNonRedundantBlock(file, DefaultMasterRecordMaxSize, 0, 0.125, Yes.exponentialSearch); //don't change this!!!
				if(ofs<0) raise("Unable to locate suitable MR offset.");
				return ofs;
			}
	+/
	
		void create(T)(T file_, string volume, string compr="", ulong baseOfs=0)
	{
		enforce(!valid, "Archive already opened."); 
		
		close; 
		try
		{
			file = File(file_); 
			this.compr = compr; 
			
			if(file.exists)
			{
				beep; 
				const code = [now].xxh3.to!string(36).take(3).to!string; 
				writef("Archive.create: %s starting from offset:%s will be overwritten. Are you sure? (type %s if yes) ", file, baseOfs, code); 
				if(readln.strip.uc==code)
				{ writeln(" Overwrite enabled. "); }else
				{ raise("Archive.create: user approval error."); }
			}else
			{
				file.write(""); //this initializes an 'empty' file
			}
			
			masterRecord.initializeNew(file, volume, baseOfs, InitialrecordPoolSize+calcJumpRecordSizeBytes); 
			writeMasterRecord; 
			
			masterRecord.valid = true; //from now it's valid and opened
		}catch(Exception e)
		{
			close; 
			throw e; 
		}
	} 
	
		void open(T)(T file_, string compr="", ulong baseOfs=0)
	{
		enforce(!valid, "Archive already opened."); 
		
		close; 
		try
		{
			file = File(file_); 
			this.compr = compr; 
			enforce(file.exists, "Archive file not found: "~file.text); 
			
			readMasterRecord(baseOfs); //if it succeeds, it will set valid to true
		}catch(Exception e)
		{
			close; 
			throw e; 
		}
	} 
	
		auto addRecord(string name, in void[] data)
	{
		enforce(valid, "No archive is opened."); 
		return writeRecord(name, data); 
	} 
	
		///note: addBlob must be followed by an addRecord which will write out the master record automatically.
		auto addBlob(string name, in void[] data)
	{
		enforce(valid, "No archive is opened."); 
		return writeBlobRecord(name, data); 
	} 
	
		auto addBlob(File f)
	{ return addBlob(f.fullName, f.read(true)); } 
	
		//record reading //////////////////////////////////////////////////////////////////////////////
	
		static struct ReadRecordResult
	{
		string name; 
		ubyte[] data; 
	} 
	
		auto readRecords(string pattern)
	{
		enforce(valid, "No archive is opened."); 
		ReadRecordResult[] res; 
		
		ulong ofs = masterRecord.masterRecordEnd; 
		foreach(idx; 0..masterRecord.totalRecordCount)
		{
			re: 
			
			//const T0 = QPS;
			auto r = decodeRecordFromFile(ofs); //Opt: this reads even those records that don't needed...
			//LOG("Record found:", r.header, "elapsed sec:", QPS-T0);
			
			if(r.error.length)
			{
				//Todo: more consistency checking needed
				//LOG("unexpected end of records: ", r.error);
				break; 
			}
			
			if(r.header==JumpRecord.Marking)
			{
				enforce(r.data.length == JumpRecord.sizeof); 
				auto jr = (cast(JumpRecord[])r.data)[0]; 
				ofs = jr.to; 
				goto re; //don't count in totalRecord
			}
			
			if(r.header.isWildMulti(pattern))
			res ~= ReadRecordResult(r.header, cast(ubyte[])(r.data.uncompress)); 
			
			ofs += r.recordSizeBytes; //Todo: endless loop protection
		}
		
		return res; 
	} 
	
		//record handling //////////////////////////////////////////////////////////////////////////////
		private
	{
		
		uint[] createRecord(string header, in void[] data, string headerCompression, string dataCompression)
		{
			
			void applyHeaderCompression(string op)(string headerCompression/+empty for debug only+/, bool compressAllData, uint[] uLeadIn, uint[] uHeader, uint[] uData, uint[] uLeadOut)
			{
				if(headerCompression=="")
				return; 
				
				seedStream.seed = headerCompression.xxh3_32; 
				auto ss = refRange(&seedStream); 
				void apply(uint[] a)
				{ mixin(q{a[] #= ss.take(a.length).array[]; }.replace("#", op)); } 
				
				apply(uLeadIn); 
				apply(uHeader); 
				if(compressAllData)
				{ apply(uData); }else
				{
					if(uData.length)
					apply(uData[$-1..$]); //there is normal compression, just do possible padded zeros in last byte
				}
				apply(uLeadOut); 
			} 
			
			void[] cdata; 
			if(dataCompression!="")
			{
				auto compr = norx!(64, 4, 1).encrypt(dataCompression, [headerCompression.xxh3_32], data); 
				cdata = compr.data ~ compr.tag[0..4]; 
			}else
			{
				cdata = data.dup; //because it will work inplace
			}
			
			uint[] uLeadIn	= [0u, 1, 2, header.length.to!uint, cdata.length.to!uint]; 
			uint[] uHeader	= header.dup.toUints; 
			uint[] uData	= cdata.toUints; 
			uint[] uLeadOut	= [0u, 1, -1, (uLeadIn.length + uHeader.length + uData.length /+size of the leadin and data except the end marker+/).to!uint]; 
			
			//print(uLeadIn); print(uHeader); print(uData); print(uLeadOut);
			
			applyHeaderCompression!"+"(headerCompression, dataCompression.empty, uLeadIn, uHeader, uData, uLeadOut); 
			
			auto res = uLeadIn ~ uHeader ~ uData ~ uLeadOut; 
			res ~= res.xxh3_32; //add final error checking
			
			return res; 
		} 
		
		auto decodeRecord(in uint[] data_, string dataCompression)
		{
			auto data = data_.dup; //because it will work on it
			
			static struct Record
			{
				string error; 
				string warning; 
				
				string header; 
				ubyte[] data; 
				ulong recordSizeBytes; 
			} 
			Record res; 
			
			try
			{
				uint[] tryFetch(uint n)
				{
					uint len = min(n, data.length); 
					auto res = data[0..len]; 
					data = data[len..$]; 
					return res; 
				} 
				
				uint[] fetchExactly(uint n)
				{
					auto arr = tryFetch(n); 
					enforce(arr.length == n, "Not enough input data"); 
					res.recordSizeBytes += n*4; 
					return arr; 
				} 
				
				uint[] uLeadIn = fetchExactly(5); 
				const seed = uLeadIn[0]; 
				
				seedStream.seed = uLeadIn[0]; 
				auto ss = refRange(&seedStream); 
				void apply(uint[] a)
				{ a[] -= ss.take(a.length).array[]; } 
				
				apply(uLeadIn); 
				enforce(uLeadIn[0..3].equal([0u, 1, 2]), "Invalid LeadIn sequence"); 
				
				const uint headerBytes = uLeadIn[3]; 
				uint[] uHeader = fetchExactly((headerBytes+3)/4); 
				apply(uHeader); 
				res.header = ((cast(char[])uHeader)[0..headerBytes]).to!string; 
				
				const uint dataBytes = uLeadIn[4]; 
				uint[] uData = fetchExactly((dataBytes+3)/4); 
				if(dataCompression=="")
				apply(uData); 
				else if(uData.length)	apply(uData[$-1..$]); 
				
				ubyte[] cData = (cast(ubyte[])uData)[0..dataBytes]; 
				if(dataCompression!="")
				{
					enforce(cData.length>=4, "Not enough cData "~cData.length.text); 
					const expectedTag = cData[$-4..$]; 
					cData = cData[0..$-4]; 
					
					auto decompr = norx!(64, 4, 1).decrypt(dataCompression, [seed], cData); 
					enforce(expectedTag.equal(decompr.tag[0..4]), "Tag check fail"); 
					res.data = decompr.data; 
				}else
				{ res.data = cData; }
				
				//verify leadOut
				try
				{
					uint[] uLeadOut = fetchExactly(4); 
					apply(uLeadOut); 
					//print("LEADOUT", uLeadOut);
					
					enforce(uLeadOut[0..3].equal([0u, 1, -1]), "bad leadOut sequence: "~uLeadOut[0..3].text); 
					
					uint len = (uLeadIn.length + uHeader.length + uData.length).to!uint; 
					enforce(uLeadOut[3]==len, format!"uSize mismatch: %d != %s"(uLeadOut[3], len)); 
					
					uint storedSheckSum = fetchExactly(1)[0]; 
					uint calcedSheckSum = data_[0..len+4/*leadOut*/].xxh3_32; 
					enforce(storedSheckSum == calcedSheckSum, "crc error"); 
				}catch(Exception e)
				{ res.error = "LeadOut error: "~e.simpleMsg; return res; }
			}catch(Exception e)
			{ res.error = e.msg; return res; }
			
			return res; 
		} 
		
		auto peekRecord(in uint[] data)
		{
			struct Res
			{
				bool isLeadIn, isLeadOut, needMoreData; 
				ulong headerLength, dataLength, seekBack, fullSize; 
				bool valid()
				{ return !needMoreData && (isLeadIn || isLeadOut); } 
			} 
			
			Res res; 
			if(data.length>=3)
			{
				seedStream.seed = data[0]; 
				seedStream.popFront; 
				if(data[1] == seedStream.front+1)
				{
					seedStream.popFront; 
					auto a = data[2]-seedStream.front; 
					if(a==2)
					{
						seedStream.popFront; 
						res.isLeadIn = true; 
						if(data.length>=5)
						{
							res.headerLength	= data[3]-seedStream.front; seedStream.popFront; 
							res.dataLength	= data[4]-seedStream.front; 
							res.fullSize	= actualFrameSize(res.headerLength, res.dataLength); 
						}else
						{ res.needMoreData = true; }
					}else if(a==-1)
					{
						seedStream.popFront; 
						res.isLeadOut = true; 
						if(data.length>=4)
						{ res.seekBack = data[3]-seedStream.front; }else
						{ res.needMoreData = true; }
					}
				}
			}else
			{ res.needMoreData = true; }
			
			return res; 
		} 
		
		public auto decodeRecordFromFile(ulong ofs)
		{
			re: 
			auto data = read_internal(false, ofs, MaxLeadSize); 
			auto peek = peekRecord(data); 
			
			bool once; 
			if(!once && peek.valid && peek.isLeadOut)
			{
				once = true; 
				ofs = ofs-peek.seekBack; //Todo: test it properly
				goto re; 
			}
			
			if(peek.valid && peek.isLeadIn)
			{ data = read_internal(true, ofs, peek.fullSize); }
			
			return decodeRecord(data, compr); 
		} 
		
	} //end of record handling
	
	
		//tests /////////////////////////////////////////////////////////////////
	
		void selfTest()
	{
		RNG rng; 
		//const t0=QPS;
		foreach(headerLen; [0, 1, 3, 4, 5, 7, 8, 9])
		{
			foreach(dataLen; [0, 1, 3, 4, 5, 7, 8, 9])
			{
				string header = iota(headerLen).map!(i => cast(char)(rng.random(96)+32)).to!string; 
				ubyte[] data = iota(dataLen).map!(i => cast(ubyte)(rng.random(256))).array; 
				foreach(dataCompr; ["", "deflate"])
				{
					auto record = cast(uint[])createRecord(header, data, "hdrc", dataCompr); 
					auto res = decodeRecord(record, dataCompr); 
					//print(res);
					immutable hde = "Header compression error: "; 
					enforce(res.error=="", hde~res.error); 
					enforce(res.header==header, hde~"header mismatch"); 
					enforce(res.data==data, hde~"data mismatch"); 
				}
			}
		}
		//writeln(QPS-t0);
	} 
	
		static void longTest()
	{
		import het.db; 
		
		LOG("Doing tests"); 
		
		RNG rng; rng.seed = 123456; 
		with(rng)
		{
			ubyte[] randomFile()
			{
				bool large = random(2)==1; 
				ubyte randomByte()
				{ return cast(ubyte)(large ? random(256) : random(64)+32); } 
				return iota((large ? 65536 : 512)+random(1024)).map!(i => randomByte).array; 
			} 
			static bool isSmall(in void[] a)
			{ return a.sizeBytes<8192; } 
			
			const allFiles = iota(100).map!(i => randomFile).array,
						smallFiles = allFiles.filter!isSmall.array,
						largeFiles = allFiles.filter!(not!isSmall).array; 
			
			foreach(c; ["", "test"])
			{
				auto f = File(`c:\arctest.bin`); 
				f.remove; 
				
				auto arc = new Archiver; 
				arc.create(f, "testvolume"); 
				
				auto db = new AMDBCore(new ArchiverDBFile(arc, "main.db")); 
				
				db.schema("Blob  is a  EType"); 
				
				//db.schema("Bitmap  is a  Blob"); //todo: subtypes
				
				db.schema("File type  is a  EType"); 
					 db.data("JPG        is a  File type"); 
					 db.data("BMP        is a  File type"); 
					 db.data("PNG        is a  File type"); 
					 db.data("WEBP       is a  File type"); 
				
				db.schema("Blob  archive location       Long"); 
				db.schema("Blob  file type              File type"); 
				db.schema("Blob  original file name     String"); 
				db.schema("Blob  size in bytes          Long"); 
				db.schema("Blob  has thumbnail          Blob"); 
				db.commit; 
				
				Bounds!ulong[] locations; 
				foreach(data; allFiles)
				{
					if(isSmall(data))
					{ locations ~= arc.addRecord(data.xxh3.text, data); }else
					{
						locations ~= arc.addBlob(data.xxh3.text, data); 
						auto loc = locations[$-1]; 
						
						string id = data.xxh3.to!string(36).padLeft('0', 13).to!string; 
						auto bname = format!"BLOB_%s"(id); 
						db.data(format!"%s  is a  Blob"(bname)); 
						db.data(format!"%s  file type  JPG"(bname)); 
						db.data(format!"%s  archive location  %d"(bname, loc.low)); 
						db.data(format!"%s  size in bytes  %d"(bname, data.sizeBytes)); 
						if(0)
						db.data(format!"%s  original file name  %s"(bname, "")); 
						//db.data(format!"%s  has thumbnail  %s");
					}
				}
				
				foreach(i, loc; locations)
				{
					auto res = arc.decodeRecordFromFile(loc.low); 
					enforce(res.error == "", "Error: "~res.error); 
					
					//must not forget to uncompress small files
					if(isSmall(res.data))
					res.data = cast(ubyte[])res.data.uncompress; //it's outdated!!!!!!
					
					//hash checks
					const h = allFiles[i].xxh3; 
					enforce(h.text == res.header, "ERR1"); 
					enforce(h == res.data.xxh3, "ERR2"); 
				}
				
				arc.masterRecord.toJson.print; 
				
				db.printTable(db.padLeft(db.query(":Blob"))); 
				
			}
			LOG("Great success. Nice!"); 
		}
	} 
	
} 


/////////////////////////////////////////////////////////////////////
/// AMDB                                                          ///
/////////////////////////////////////////////////////////////////////


//ArchiverDBFile /////////////////////////////////////////////////////
class ArchiverDBFile : DBFileInterface {
	 //this is an AMDB inside an Archive
	string name; 
	Archiver arc; 
	
	this(Archiver arc, string name) {
		this.arc = arc; 
		this.name = name; 
	} 
	
	File file() { return File(arc.file.fullName~`\`~name); } //just an information, not a usable file (yet)
	
	string[] readLines() {
		return arc.readRecords(name).map!(r => (cast(string)r.data).splitLines).join; 
		//log this
	} 
	
	void appendLines(string[] lines) {
		arc.addRecord(name, '\n'~lines.join('\n')~'\n'); 
		//log this too
	} 
} 


class AMDBException : Exception { this(string s) { super(s); } } 

interface DBFileInterface {
	File file(); 
	string[] readLines(); //reads the whole file
	void appendLines(string[] lines); //appends some lines
} 

class TextDBFile : DBFileInterface {
	private File file_; 
	
	this(File file) { this.file_ = file; } 
	
	File file() { return file_; } 
	
	string[] readLines() { return file_.readLines; } 
	
	void appendLines(string[] lines) { file_.append("\n"~lines.join("\n")~"\n"); } 
} 

class AMDBCore {
	enum versionStr = "1.00"; 
	
	private uint lastIdIndex; 
	Items items; 
	Links links; 
	
	private DBFileInterface dbFileInterface; 
	
	bool autoCreateETypes	= true ,
				 autoCreateVerbs	= true ,
				 autoCreateEntities	= false; 
	
	//----------------------------------------------------------------------------------
	
	this()
	{
		items.db = links.db = transaction.db = this; 
		
		//do critical unittests
		__gshared static bool tested; 
		if(tested.chkSet)
		unittest_splitSentences; 
	} 
	
	this(DBFileInterface dbFileInterface)
	{
		this(); 
		this.dbFileInterface = dbFileInterface; 
		load; 
	} 
	
	this(File file)
	{ this(new TextDBFile(file)); } 
	this(string fileName)
	{ this(File(fileName)); } 
	
	//clear all the internal data. Does not change the dbFile.
	private void clear()
	{
		lastIdIndex = 0; 
		links.clear; 
		items.clear; 
	} 
	
	File file()
	{ return dbFileInterface ? dbFileInterface.file : File(""); } 
	
	void error(string s) const
	{ throw new AMDBException(s); } 
	
	static string autoQuoted(string s)
	{
		//Todo: slow
		if(s.canFind!(ch => ch<32 || ch.among('"', '\'', '`', '\\')) || s.canFind("  ") || s.canFind("..."))
		return s.quoted; 
		else return s; 
	} 
	
	static string autoUnquoted(string s)
	{
		if(s.startsWith('"'))
		{
			import het.parser; //Todo: agyuval verebre...
			Token[] t; 
			string err = tokenize("", s, t); 
			enforce(err=="" && t.length, "Error decoding quoted string: "~err); 
			return t[0].data.to!string; 
		}else
		return s; 
	} 
	
	//Id ////////////////////////////////////
	
	struct Id
	{
		uint id; 
		
		bool valid() const
		{ return id!=0; } 
		bool opCast(B: bool)() const
		{ return valid; } 
		
		size_t toHash() const @safe pure nothrow
		{ return id; } 
		bool opEquals(ref const Id b) const @safe pure nothrow
		{ return id==b.id; } 
		
		string toString() const
		{ return id.text; } 
		
		long opCmp(in Id b) const
		{ return long(id)-long(b.id); } 
		
		string serializeText() const
		{ return id.to!string(10); } 
		void deserializeText(string s)
		{ id = s.to!uint(10); } 
	} 
	
	private Id _internal_generateNextId()
	{ return Id(++lastIdIndex); } 
	
	/// When an item is loaded
	private void _internal_maximizeNextId(in Id id)
	{ lastIdIndex.maximize(id.id); } 
	
	
	struct Items
	{
		private AMDBCore db; 
		private string[Id] byId; 
		private Id[string] byItem; 
		
		//data access -------------------------------------------
		
		auto ids()
		{ return byId.keys; } 
		auto strings()
		{ return byItem.keys; } 
		
		auto count() const
		{ return byId.length; } 
		
		string get(in Id id                 ) const
		{
			if(auto a = id in byId)
			return *a; else
			return ""; 
		} 
		string get(in Id id, lazy string def) const
		{
			if(auto a = id in byId)
			return *a; else
			return def; 
		} 
		
		//Todo: require() has an incompatible meaning compared to assocArray.require
		string require(in Id id                 ) const
		{
			if(auto a = id in byId)
			return *a; else
			{ db.error(format!"Required id %s not found."   (id     )); assert(0); }
		} 
		string require(in Id id, lazy string msg) const
		{
			if(auto a = id in byId)
			return *a; else
			{ db.error(format!"Required id %s not found. %s"(id, msg)); assert(0); }
		} 
		
		Id get(string str             ) const
		{
			if(auto a = str in byItem)
			return *a; else
			return Id.init; 
		} 
		Id get(string str, lazy Id def) const
		{
			if(auto a = str in byItem)
			return *a; else
			return def; 
		} 
		
		Id require(string str                 ) const
		{
			if(auto a = str in byItem)
			return *a; else
			{ db.error(format!"Required item %s not found."   (str.quoted     )); assert(0); }
		} 
		Id require(string str, lazy string msg) const
		{
			if(auto a = str in byItem)
			return *a; else
			{ db.error(format!"Required item %s not found. %s"(str.quoted, msg)); assert(0); }
		} 
		
		auto opBinaryRight(string op)(in Id id) if(op=="in")
		{
			
			struct ItemResult
			{
				string str; 
				bool valid; 
				alias str this; 
				bool opCast(B : bool)() const
				{ return valid; } 
			} 
			
			if(auto a = id in byId)
			return ItemResult(*a, true); else
			return ItemResult.init; 
		} 
		
		Id opBinaryRight(string op)(string str) if(op=="in")
		{ return get(str); } 
		
		string opIndex(in Id id) const
		{ return require(id); } 
		Id opIndex(string str) const
		{ return require(str); } 
		
		//data manipulation -------------------------------------------------------
		
		//inserts into the lists, called by itemId_create and importItem
		private void _internal_createItem(in Id id, string name)
		{
			byItem[name] = id; 
			byId[id] = name; 
		} 
		
		private bool _internal_tryRemoveItem(in Id id)
		{
			if(auto item = id in this)
			{
				byId.remove(id); 
				byItem.remove(item); 
				return true; 
			}
			return false; 
		} 
		
		private void clear()
		{ byId = null; byItem = null; } 
		
		private Id create(string name, void delegate(Id) afterCreate = null)
		{
			auto id = get(name); 
			if(id)
			return id; 
			
			id = db._internal_generateNextId; 
			_internal_createItem(id, name); 
			db.transaction._internal_onItemCreated(id); 
			if(afterCreate)
			afterCreate(id); 
			return id; 
		} 
		
		private void load(in Id id, string data)
		{
			if(!id)
			db.error("Invalid null id"); 
			if(id in db.links)
			db.error(format!"Load error: Item id already exists as a link. id=%s old=%s new=%s"(id, db.toStr(id), data)); 
			if(auto existing = id in this)
			{
				if(existing==data)
				return; //already loaded, id is the same
				db.error(format!"Load error: Id already exists with different item data. id=%s old=%s new=%s"(id, db.toStr(id), data)); 
			}
			//id is free, check duplicated data
			if(get(data))
			format!"Load error: Item already exists with different id. new=%s"(data); 
			
			//good to go, create it
			db._internal_maximizeNextId(id); 
			_internal_createItem(id, data); 
		} 
	} 
	
	//Links //////////////////////////////////////
	
	struct Link
	{
		Id sourceId, verbId, targetId; 
		
		size_t toHash() const @safe pure nothrow
		{ return sourceId.hashOf(verbId.hashOf(targetId.hashOf)); } 
		
		bool opEquals(ref const Link b) const @safe pure nothrow
		{
			  return sourceId==b.sourceId
					 && verbId  ==b.verbId
					 && targetId==b.targetId; 
		} 
		
		bool valid() const
		{ return sourceId.valid && verbId.valid; } 
		bool opCast(B : bool)() const
		{ return valid; } 
	} 
	
	struct VerbTarget
	{ Id verbId, targetId; } 
	struct SourceVerb
	{ Id sourceId, verbId; } 
	
	struct Links
	{
		private AMDBCore db; 
		private Link[Id] byId; 
		private Id[Link] byLink; 
		
		bool[Id][VerbTarget] sourcesByVerbTarget; 
		bool[Id][SourceVerb] targetsBySourceVerb; 
		
		//data access -------------------------------------------
		
		auto ids()
		{ return byId.keys; } 
		auto links()
		{ return byLink.keys; } 
		
		auto byLink_()
		{ return byLink.byKey; } 
		
		auto count() const
		{ return byId.length; } 
		
		Link get(in Id id               ) const
		{
			if(auto a = id in byId)
			return *a; else
			return Link.init; 
		} 
		Link get(in Id id, lazy Link def) const
		{
			if(auto a = id in byId)
			return *a; else
			return def; 
		} 
		
		Link require(in Id id                 ) const
		{
			if(auto a = id in byId)
			return *a; else
			{ db.error(format!"Required link %s not found."   (id     )); assert(0); }
		} 
		Link require(in Id id, lazy string msg) const
		{
			if(auto a = id in byId)
			return *a; else
			{ db.error(format!"Required link %s not found. %s"(id, msg)); assert(0); }
		} 
		
		Id get(in Link link               ) const
		{
			if(auto a = link in byLink)
			return *a; else
			return Id.init; 
		} 
		Id get(in Link link, lazy Id defId) const
		{
			if(auto a = link in byLink)
			return *a; else
			return defId; 
		} 
		
		Id get(in Id sourceId, in Id verbId                ) const
		{ return get(Link(sourceId, verbId          )); } 
		Id get(in Id sourceId, in Id verbId, in Id targetId) const
		{ return get(Link(sourceId, verbId, targetId)); } 
		
		Id require(in Link link                 ) const
		{
			if(auto a = link in byLink)
			return *a; else
			{ db.error(format!"Required link %s not found."   (link     )); assert(0); }
		} 
		Id require(in Link link, lazy string msg) const
		{
			if(auto a = link in byLink)
			return *a; else
			{ db.error(format!"Required link %s not found. %s"(link, msg)); assert(0); }
		} 
		
		Id require(in Id sourceId, in Id verbId                ) const
		{ return require(Link(sourceId, verbId          )); } 
		Id require(in Id sourceId, in Id verbId, in Id targetId) const
		{ return require(Link(sourceId, verbId, targetId)); } 
		
		auto opBinaryRight(string op)(in Id id) if(op=="in")
		{ return get(id); } 
		Id opBinaryRight(string op)(in Link link) if(op=="in")
		{ return get(link); } 
		
		Link opIndex(in Id id) const
		{ return require(id); } 
		Id opIndex(in Link link) const
		{ return require(link); } 
		
		//data manipulation -------------------------------------------------------
		
		private void _internal_createLink(in Id id, in Link link)
		{
			byId[id] = link; 
			byLink[link] = id; 
			
			sourcesByVerbTarget[VerbTarget(link.verbId, link.targetId)][link.sourceId] = true; 
			targetsBySourceVerb[SourceVerb(link.sourceId, link.verbId)][link.targetId] = true; 
		} 
		
		bool _internal_tryRemoveLink(in Id id)
		{
			if(auto link = id in this)
			{
				byId.remove(id); 
				byLink.remove(link); 
				
				sourcesByVerbTarget[VerbTarget(link.verbId, link.targetId)].remove(link.sourceId); 
				targetsBySourceVerb[SourceVerb(link.sourceId, link.verbId)].remove(link.targetId); 
				
				return true; 
			}
			return false; 
		} 
		
		private void clear()
		{ byId = null; byLink = null; } 
		
		private Id create(in Id sourceId, in Id verbId, in Id targetId=Id.init)
		{
			auto link = Link(sourceId, verbId, targetId); 
			auto id = get(link); 
			if(id)
			return id; //access if can
			
			id = db._internal_generateNextId; 
			_internal_createLink(id, link); 
			db.transaction._internal_onLinkCreated(id); 
			
			return id; 
		} 
		
		private void load(in Id id, in Link data)
		{
			if(!id)
			db.error("Invalid null id"); 
			if(id in db.items)
			db.error(format!"Load error: Link id already exists as an item. id=%s old=%s new=%s"(id, db.toStr(id), data)); 
			if(auto link = id in this)
			{
				if(link==data)
				return; //already loaded, id is the same
				db.error(format!"Load error: Id already exists with different link data. id=%s old=%s new=%s"(id, db.toStr(id), data)); 
			}
			//id is free, check duplicated data
			if(get(data))
			format!"Load error: Link already exists with different id. new=%s"(data); 
			
			//good to go, create it
			db._internal_maximizeNextId(id); 
			_internal_createLink(id, data); 
		} 
		
		
	} 
	
	//Transaction ////////////////////
	
	struct Transaction
	{
		private AMDBCore db; 
		private string[] commitBuffer, cancelBuffer; 
		
		@property bool active() const
		{ return commitBuffer.length>0; } 
		
		void commit()
		{
			if(!active)
			return; 
			
			if(db.dbFileInterface)
			db.dbFileInterface.appendLines(commitBuffer); //Todo: transaction header/footer
			
			commitBuffer = null; 
			cancelBuffer = null; 
		} 
		
		void cancel()
		{
			if(!active)
			return; 
			enforce(cancelBuffer.length == commitBuffer.length, "Cancel/commit buffer inconsistency: " ~ cancelBuffer.length.text ~ "!=" ~ commitBuffer.length.text); 
			
			while(cancelBuffer.length)
			{
				auto s = cancelBuffer[$-1]; 
				try
				{
					if(s.startsWith('~'))
					{
						Id id;  id.deserializeText(s[1..$]); 
						db.deleteThing(id); 
					}else
					NOTIMPL; 
				}finally
				{
					cancelBuffer = cancelBuffer[0..$-1]; 
					commitBuffer = commitBuffer[0..$-1]; 
				}
			}
		} 
		
		//called after create but not when loading
		private void _internal_onItemCreated(in Id id)
		{
			commitBuffer ~= db.serializeText(id); 
			cancelBuffer ~= '~'~id.serializeText; 
		} 
		
		//called after create but not when loading
		private void _internal_onLinkCreated(in Id id)
		{
			commitBuffer ~= db.serializeText(id); 
			cancelBuffer ~= '~'~id.serializeText; 
		} 
		
	} 
	Transaction transaction; 
	
	@property bool canCommit() const
	{ return transaction.active; } 
	void commit()
	{ transaction.commit; } 
	void cancel()
	{ transaction.cancel; } 
	
	//toStr, prettyStr //////////////////////////////////////////////////////////////////
	
	string toStr(in Id id, int recursion=0)
	{
		if(!id)
		return "Null"; 
		if(auto item = id in items)
		return format!"Item(%s, %s)"(id, (item).quoted); 
		if(auto link = id in links)
		with(link)
		{
			if(recursion-->0)
			{ return format!"Link(%s, %s, %s, %s)"(id, toStr(sourceId, recursion), toStr(verbId, recursion), toStr(targetId, recursion)); }else
			{ return format!"Link(%s, %s, %s, %s)"(id, sourceId, verbId, targetId); }
		}
		return format!"Unknown(%s)"(id); 
	} 
	
	string prettyStr(Flag!"color" color = Yes.color)(in Id id)
	{
		if(!id)
		{
			auto s = "null"; 
			static if(color)
			s = EgaColor.ltWhite(s); 
			return s; 
		}else if(auto item = id in items)
		{
			auto s = autoQuoted(item); 
			static if(color)
			{
				if(isSystemVerb(s))
				s = EgaColor.ltWhite(s); 
				else if(isSystemType(s)) s = EgaColor.ltGreen(s); 
				else if(isVerb  (id)) s = EgaColor.yellow(s); 
				else if(isEType (id)) s = EgaColor.ltMagenta(s); 
				else if(isEntity(id)) s = EgaColor.ltBlue(s); 
			}
			return s; 
		}else if(auto link = id in links)
		{
			
			string a(in Id id)
			{ return id in links ? "..." : prettyStr!(color)(id); } 
			
			auto sSource	= a(link.sourceId),
					 sVerb	= a(link.verbId),
					 sTarget	= link.targetId ? a(link.targetId) : ""; 
			
			return sSource ~ (sSource=="..." ? "" : "  ") ~ sVerb ~ (sTarget=="" ? "" : "  ") ~ sTarget; 
		}else
		{
			auto s = format!"Unknown(%s)"(id); 
			static if(color)
			s = EgaColor.ltRed(s); 
			return s; 
		}
	} 
	
	string prettyStr(Flag!"color" color = Yes.color)(in Id id, const ColumnInfo ci)
	{
		if(!id)
		{
			auto s = "null"; 
			static if(color)
			s = EgaColor.ltWhite(s); 
			return console.leftJustify(s, ci.size); 
		}else if(auto item = id in items)
		{
			auto s = autoQuoted(item); 
			static if(color)
			{
				if(isSystemVerb(s))
				s = EgaColor.ltWhite(s); 
				else if(isSystemType(s)) s = EgaColor.ltGreen(s); 
				else if(isVerb  (id)) s = EgaColor.yellow(s); 
				else if(isEType (id)) s = EgaColor.ltMagenta(s); 
				else if(isEntity(id)) s = EgaColor.ltBlue(s); 
			}
			return console.leftJustify(s, ci.size); 
		}else if(auto link = id in links)
		{
			
			string a(in Id id)
			{ return id in links ? "..." : prettyStr!(color)(id); } 
			
			auto sSource	= a(link.sourceId),
					 sVerb	= a(link.verbId),
					 sTarget	= link.targetId ? a(link.targetId) : ""; 
			
			sSource	= console.leftJustify(sSource, ci.maxSourceWidth); 
			sVerb	= console.leftJustify(sVerb  , ci.maxVerbWidth  ); 
			sTarget	= console.leftJustify(sTarget, ci.maxTargetWidth); 
			
			return sSource ~ (ci.isBackLink?"":"  ") ~ sVerb ~ (ci.maxTargetWidth?"  ":"") ~ sTarget; 
		}else
		{
			auto s = format!"Unknown(%s)"(id); 
			static if(color)
			s = EgaColor.ltRed(s); 
			return console.leftJustify(s, ci.size); 
		}
	} 
	
	struct ColumnInfo
	{
		bool anySourceIsNoLink; 
		int maxSourceWidth, maxVerbWidth, maxTargetWidth; 
		
		//extra info, calculated later
		bool isBackLink; 
		int offset, size; 
		
		private void accumulate(AMDBCore db, in Id id)
		{
			if(auto link = id in db.links)
			{
				
				string a(in Id id)
				{ return id in db.links ? "..." : db.prettyStr!(No.color)(id); } 
				
				auto	sSource	= a(link.sourceId),
					sVerb	= a(link.verbId),
					sTarget	= link.targetId ? a(link.targetId) : ""; 
				
				anySourceIsNoLink |= sSource!="..."; 
				maxSourceWidth.maximize(cast(int)(sSource.walkLength)); 
				maxVerbWidth  .maximize(cast(int)(sVerb  .walkLength)); 
				maxTargetWidth.maximize(cast(int)(sTarget.walkLength)); 
			}else
			{
				auto s = db.prettyStr!(No.color)(id); 
				anySourceIsNoLink |= s!="..."; 
				maxSourceWidth.maximize(cast(int)(s.walkLength)); 
			}
		} 
	} 
	
	private void calcColumnInfoExtra(ColumnInfo[] columns)
	{
		foreach(idx, ref c; columns)
		with(c)
		{
			isBackLink = !anySourceIsNoLink && c.maxSourceWidth==3; 
			size = maxSourceWidth + (maxVerbWidth ? (isBackLink ? 0 : 2) + maxVerbWidth : 0) + (maxTargetWidth ? 2+maxTargetWidth: 0); 
			offset = idx>0 ? columns[idx-1].offset+columns[idx-1].size+2 : 0; 
		}
		
	} 
	
	string prettyStr(Flag!"color" color = Yes.color)(in IdSequence seq)
	{
		//Todo: Use sentenceColumnIndices!
		return iota(seq.ids.length.to!int).map!(
			(i){
				auto id = seq.ids[i]; 
				auto s = prettyStr!(color)(id); 
				static if(color)
				if(i==seq.centerIdx)
				s = "\34\10" ~ s ~ "\34\0"; 
				return s; 
			}
		).join("  "); 
	} 
	
	void printTable(in IdSequence[] seqs)
	{
		const sentenceColumnIndices = seqs.map!(seq => seq.coulmnIndices(this)).array; 
		
		//collect width of columns
		ColumnInfo[] columns; 
		columns.length = sentenceColumnIndices.map!(a => a.maxElement(-1)).maxElement(-1)+1; 
		foreach(sequenceIdx, const columnIndices; sentenceColumnIndices)
		{
			const ids = seqs[sequenceIdx].ids; 
			foreach(sentenceIdx, columnIdx; columnIndices)
			{
				const id = ids[sentenceIdx]; 
				columns[columnIdx].accumulate(this, id); 
			}
		}
		
		calcColumnInfoExtra(columns); 
		
		//draw the cells from left to right, top to bottom.
		foreach(sequenceIdx, const columnIndices; sentenceColumnIndices)
		{
			const ids = seqs[sequenceIdx].ids; 
			
			int lastColumnIdx = -1; 
			foreach(sentenceIdx, columnIdx; columnIndices)
			{
				const id = ids[sentenceIdx]; 
				const ci()
				{ return columns[columnIdx]; } 
				const newLine = columnIdx != lastColumnIdx+1; 
				lastColumnIdx = columnIdx; 
				if(newLine)
				{ write("\n", " ".replicate(ci.offset)); }else
				{
					if(sentenceIdx>0)
					write("  "); 
				}
				//Todo: justify for integers
				//Todo: justify for datetimes
				auto s = id ? prettyStr(id, ci) : " ".replicate(ci.size); 
				/*
					auto highlighted = seqs[sequenceIdx].centerIdx==sentenceIdx;
					if(highlighted) write("\34\10", s, "\34\0"); else 
				*/
				write(s); 
			}
			writeln; 
		}
		
	} 
	
	//serialization ////////////////////////////////////////////
	
	string serializeText(in Id id)
	{
		if(auto link = id in links)
		{
			with(link)
			return id.serializeText ~" "~ sourceId.serializeText ~" "~ verbId.serializeText ~(targetId ? " "~targetId.serializeText : ""); 
		}else if(auto item = id in items)
		{
			auto s = autoQuoted(item); 
			//string is closed with newLine.  Only need to escape when it contains newLine or starts with the escape quote. But to make sure, escape it if it contains any special chars
			return id.serializeText~"="~s; 
		}else
		error("Invalid Id to serialize:"~id.text); 
		assert(0); 
	} 
	
	string serializeText(R)(in R r)
	{ return r.map!(i => serializeText(i)~"\n").join; } 
	
	void deserializeLine(string line)
	{
		line = line.strip; 
		if(line=="")
		return; 
		const idx = line.map!(ch => ch==' ' || ch=='=').countUntil(true); 
		enforce(idx>0, "Invalid text db line format: "~line.quoted); 
		
		//get Id
		const id = Id(line[0..idx].to!uint); 
		const lineType = line[idx]; 
		line = line[idx+1..$]; 
		
		switch(lineType)
		{
			case '=': {
					//Item
				items.load(id, autoUnquoted(line)); 
			}break; 
			case ' ': {
				auto p = line.split(' ').map!(a => Id(a.to!uint)).array; 
				enforce(p.length.among(2, 3), "Invalid link id count. "~line.quoted); 
				if(p.length==2)
				p ~= Id.init; 
				foreach(a; p)
				enforce(!a || a in items || a in links, "Invalid link id: "~a.text~" "~line.quoted); 
				links.load(id, Link(p[0], p[1], p[2])); 
			}break; 
			default: raise("Unknown lineType. "~line.quoted); 
		}
	} 
	
	private void load()
	{
		try
		{
			clear; 
			if(dbFileInterface)
			foreach(line; dbFileInterface.readLines)
			deserializeLine(line); 
		}catch(Exception e)
		{ raise("AMDB load error: "~e.simpleMsg); }
	} 
	
	
	//find referrers ///////////////////////////////////////////////////
	
	auto referrers(Flag!"source" chkSource = Yes.source, Flag!"verb" chkVerb = Yes.verb, Flag!"target" chkTarget = Yes.target, alias retExpr="a.key")(in Id id)
	{
		//Opt: linear
		return links.byId.byKeyValue.filter!(
			a => chkSource && a.value.sourceId==id
															 || chkVerb	&& a.value.verbId  ==id
															 || chkTarget	&& a.value.targetId==id
		).map!retExpr; 
	} 
	
	auto sourceReferrers(in Id id)
	{ return referrers!(Yes.source, No .verb, No .target)(id); } 
	auto verbReferrers  (in Id id)
	{ return referrers!(No .source, Yes.verb, No .target)(id); } 
	auto targetReferrers(in Id id)
	{ return referrers!(No .source, No .verb, Yes.target)(id); } 
	
	bool hasReferrers(in Id id)
	{
		if(!id)
		return false; 
		return !referrers(id).empty; 
	} 
	
	auto allReferrers(Flag!"source" chkSource = Yes.source, Flag!"verb" chkVerb = Yes.verb, Flag!"target" chkTarget = Yes.target, alias retExpr="a.key")(in Id id)
	{
		bool[Id] found; 
		
		void doit(in Id id)
		{
			foreach(r; referrers!(chkSource, chkVerb, chkTarget, retExpr)(id))
			if(r !in found)
			{
				found[r]=true; 
				doit(r); 
			}
			
		} 
		doit(id); 
		
		return found.keys.sort.array; 
	} 
	
	auto allSourceReferrers(in Id id)
	{ return referrers!(Yes.source, No .verb, No .target)(id); } 
	auto allTargetReferrers(in Id id)
	{ return referrers!(No .source, No .verb, Yes.target)(id); } 
	
	//delete ///////////////////////////////////////////////////////////////
	
	void deleteThing(in Id id)
	{
			//used by transaction.cancel
		if(!id)
		return; //no need to delete null
		enforce(!hasReferrers(id), "Can't delete, because it has references:  "~prettyStr(id)); 
		if(items._internal_tryRemoveItem(id) || links._internal_tryRemoveLink(id))
		return; 
		raise("Can't delete thing. Id not found: "~id.text); 
	} 
	
	/*
		void _internal_replaceLink(in Id linkId, in Link oldLink, in Link newLink){
			links.byLink.remove(oldLink);
			links.byId[linkId] = newLink;
			links.byLink[newLink] = linkId;
		}
		
		void changeTargetTo(in Id linkId, in Id newTargetId){
			const oldLink = enforce(linkId in links, "CTT: Link not found: "~linkId.text);
		
			if(oldLink.targetId==newTargetId) return; //nothing changed
			const newLink = Link(oldLink.sourceId, oldLink.verbId, newTargetId);
		
			//check is the modified link already exists.
			const existingLinkId = newLink in links;
			if(existingLinkId) raise("CTT: modified link already exists: "~prettyStr(existingLinkId));
		
			//update the internal state
			_internal_replaceLink(linkId, oldLink, newLink);
		}
	*/
	
	//Central notification handling ////////////////////////////
	
	//translations /////////////////////////////////////////
	
	string inputTranslateVerb(string s)
	{
		if(s=="is an")
		s="is a"; 
		return s; 
	} 
	
	
	//systemTypes //////////////////////////////////////////
	
	immutable allSystemTypes = ["Verb", "EType", "AType", "String", "Int", "Long", "UInt", "ULong", "Float", "Double", "DateTime", "Date", "Time"]; 
	
	auto systemTypeMap()
	{
		static int[string] m; 
		if(!m)
		{
			foreach(idx, name; allSystemTypes)
			m[name] = cast(int)idx + 1; m.rehash; 
		}
		return m; 
	} 
	
	int systemTypeIdx(string name)
	{ return systemTypeMap.get(name, 0); } 
	bool isSystemType(string name)
	{ return (name in systemTypeMap)!is null; } 
	
	//systemVerbs //////////////////////////////////////////
	
	immutable allSystemVerbs = ["is a"]; 
	
	auto systemVerbMap()
	{
		static int[string] m; 
		if(!m)
		{
			foreach(idx, name; allSystemVerbs)
			m[name] = cast(int)idx + 1; m.rehash; 
		}
		return m; 
	} 
	
	int systemVerbIdx(string name)
	{ return systemVerbMap.get(name, 0); } 
	bool isSystemVerb(string name)
	{ return (name in systemVerbMap)!is null; } 
	
	Id sysId(string name)
	{
		if(auto id = name in items)
		return id; 
		if(isSystemVerb(name) || isSystemType(name))
		return items.create(name); 
		
		error("Invalid sysId name. Must be a systemVerb or a systemType. "~name.quoted); 
		assert(0); 
	} 
	
	//input verifications ///////////////////////////////////////////////////
	
	private void verifyETypeName(string s)
	{
		enforce(s.length, "Invalid entity name. Empty string. "~s.quoted); 
		auto ch = s.decodeFront; 
		enforce(ch.isLetter && ch==ch.toUpper, "Invalid entity name. Must start with a capital letter. "~s.quoted); 
		enforce(!isSystemType(s), "Invalid entity name. Can't be a system type. "~s.quoted); 
		enforce(!isSystemVerb(s), "Invalid entity name. Can't be a system verb. "~s.quoted); 
	} 
	
	private void verifyVerbName(string s)
	{
		enforce(s.length, "Invalid verb name. Empty string. "~s.quoted); 
		auto olds = s; //Todo: it's ugly
		auto ch = s.decodeFront; 
		enforce(ch.isLetter && ch==ch.toLower, "Invalid verb name. Must start with a lower letter. "~olds.quoted); 
		enforce(!isSystemType(s), "Invalid verb name. Can't be a system type. "~olds.quoted); 
		enforce(!isSystemVerb(s), "Invalid verb name. Can't be a system verb. "~olds.quoted); 
	} 
	
	//filter, exists ///////////////////////////////////////////////////////
	
	/// this is kinda fast
	bool exists(S, V, T)(in S s, in V v, in T t)
	{
		static if(is(S==Id))
		auto si = s; else
		auto si = s in items; 
		static if(is(V==Id))
		auto vi = v; else
		auto vi = v in items; 
		static if(is(T==Id))
		auto ti = t; else
		auto ti = t in items; 
		return (Link(si, vi, ti) in links).valid; //this is fast
	} 
	
	bool exists(S, V)(in S s, in V v)
	{ return exists(s, v, Id.init); } 
	
	/// this is fucking slow but only needed for queryes
	auto filter2(S, V, T)(in S source, in V verb, in T target)
	{
		 //Opt: linear
		//print("Filter is fucking slow!");
		
		bool test(in Link link)
		{
			
			bool testOne(T)(in Id id, in T criteria)
			{
				static if(isSomeString!T)
				{
					if(!items.get(id).isWild(criteria))
					return false; //Todo: ez hasonlit a chkId-re, ossze kene vonni!
				}else static if(is(Unqual!T == Id))
				{
					if(source && id != criteria)
					return false; 
				}else
				static assert(0, "Invalid params"); 
				return true; 
			} 
			
			if(!testOne(link.sourceId, source))
			return false; 
			if(!testOne(link.verbId  , verb  ))
			return false; 
			if(!testOne(link.targetId, target))
			return false; 
			return true; 
		} 
		
		return links.byId.byKeyValue.filter!(a => test(a.value)).map!"a.key"; 
	} 
	
	bool isAType(T)(in T a)
	{ return exists(a, "is a", "AType"); } 
	bool isEType(T)(in T a)
	{ return exists(a, "is a", "EType"); } 
	bool isVerb (T)(in T a)
	{ return exists(a, "is a", "Verb" ); } 
	
	bool isEntity(in Id id)
	{ return filter2(id, "is a", "*").any!(a => isEType(links[a].targetId)); } 
	
	bool isInstanceOf(T, U)(in T entity, in U eType)
	{ return exists(entity, "is a", eType); } //Todo: subtype handling
	
	auto things() 
	{ return chain(items.ids, links.ids); } 
	
	Id[] idArrayOfIsASomething(T)(in T t)
	{
		VerbTarget vt; 
		static if(is(T==Id))
		vt.targetId = t; else
		vt.targetId = t in items; 
		vt.verbId = "is a" in items; //otp: keyword cache
		
		if(auto a = vt in links.sourcesByVerbTarget)
		return a.keys; 
		else	return []; 
	} 
	
	Id[] verbs()	
	{ return idArrayOfIsASomething("Verb");  } 
	Id[] eTypes()	
	{ return idArrayOfIsASomething("EType"); } 
	Id[] aTypes()	
	{ return idArrayOfIsASomething("AType"); } //previously it was: return filter("*", "is a", "AType").map!(a => links[a].sourceId);
	
	auto entities()          
	{ return eTypes                             .map!(e => filter2("*", "is a", e).map!(e => links.get(e).sourceId)).join; } 
	auto entities(string mask)
	{ return eTypes.filter!(e => chkId(e, mask)).map!(e => filter2("*", "is a", e).map!(e => links.get(e).sourceId)).join; } 
	
	char thingCategory(in Id id)
	{
		if(!id)
		return 0; 
		if(auto link = id in links)
		{
			if(isAType(id))
			return 's'; 
			if(items.get(link.verbId)=="is a")
			{
				if(isEType(link.targetId))
				return 'e'; 
				return 's'; 
			}else
			return 'd'; 
		}else
		return 'i'; 
	} 
	
	bool isSchema	     (in Id id)
	{ return thingCategory(id)=='s'; } 
	bool isEntityAssociation	     (in Id id)
	{ return thingCategory(id)=='e'; } 
	bool isData			   (in Id id)
	{ return thingCategory(id)=='d'; } 
	bool isItem			   (in Id id)
	{ return thingCategory(id)=='i'; } 
	
	//create system things /////////////////////////////
	
	private Id createEType(string s)
	{
		verifyETypeName(s); 
		return items.create(s, (id){ links.create(id, sysId("is a"), sysId("EType")); }); //implicit "* is a EType"
	} 
	
	private Id resolveType(string s)
	{
		if(isSystemType(s))
		return sysId(s); 
		
		if(auto id = s in items)
		if(exists(id, "is a", "EType"))
		return id; 
		
		if(autoCreateETypes)
		{ return createEType(s); }else
		{
			enforce(0, "Unknown type: "~s.quoted); 
			return Id.init; 
		}
	} 
	
	private Id createVerb(string s)
	{
		verifyVerbName(s); 
		return items.create(s, (id){ links.create(id, sysId("is a"), sysId("Verb")); } ); //implicit "* is a Verb"
	} 
	
	private Id resolveVerb(string s)
	{
		if(isSystemVerb(s))
		return sysId(s); //system verbs are not asserted
		
		if(auto id = s in items)
		if(exists(id, "is a", "Verb"))
		return id; 
		
		if(autoCreateVerbs)
		{ return createVerb(s); }else
		{
			enforce(0, "Unknown verb: "~s.quoted); 
			return Id.init; 
		}
	} 
	
	private Id createVerbAssertion(string name)
	{
		enforce(name!="...", "Verb Assertion source can't be a \"...\" association."); 
		enforce(!isSystemType(name), "Verb Assertion source can't be a SystemType: "~name.quoted); 
		enforce(!isSystemVerb(name), "Verb Assertion source can't be a SystemVerb: "~name.quoted); 
		return createVerb(name); 
	} 
	
	private Id createETypeAssertion(string name)
	{
		enforce(name!="...", "EType Assertion source can't be a \"...\" association."); 
		enforce(!isSystemType(name), "EType Assertion source can't be a SystemType: "~name.quoted); 
		enforce(!isSystemVerb(name), "EType Assertion source can't be a SystemVerb: "~name.quoted); 
		return createEType(name); 
	} 
	
	private Id createEntityAssertion(string name, string type)
	{
		enforce(name!="...", "Entity assertion source can't be a \"...\" association."); 
		
		enforce(!isSystemType(name), "Entity assertion source can't be a SystemType: "~name.quoted); 
		enforce(!isSystemVerb(name), "Entity assertion source can't be a SystemVerb: "~name.quoted); 
		enforce(!exists(name, "is a", "EType"), "Entity assertion source can't be an EType: "~name.quoted); 
		enforce(exists(type, "is a", "EType"), "Entity assertion target must be an EType: "~type.quoted); 
		
		return links.create(items.create(name), sysId("is a"), items[type]); 
	} 
	
	//input text, sentence processing //////////////////////////////
	
	static string[][] textToSentences(string input)
	{
		import het.parser : collectAndReplaceQuotedStrings; 
		auto quotedStrings = collectAndReplaceQuotedStrings(input, `  "  `); 
		string fetchQStr()
		{
			enforce(quotedStrings.length, "Quoted string literals: Array is empty."); 
			return quotedStrings.fetchFront; 
		} 
		
		string[][] lineToSentences(string line)
		{
			//strip at "..."
			auto p = line.strip.split("...").map!strip.array; 
			
			//handle the first special case.
			foreach(i; 1..p.length)
			p[i] = "...  "~p[i]; //put back the "...", it will be processed later
			if(p.length && p[0]=="")
			p = p[1..$]; //is it allowed to start a new line with "...".
			
			//split the sentences to words. Separator is double space.
			string[] splitSentence(string s)
			{
				return s.strip.split("  ").map!strip.filter!"a.length".map!(a => a==`"` ? fetchQStr : a).array; //Todo: empty string encoded as ""
			} 
			return p.map!(a => splitSentence(a)).array; 
		} 
		
		return input.splitLines.map!(line => lineToSentences(line)).join; 
	} 
	
	static string[][] toSentences(T)(T s)
	{
		static if(isSomeString!T)
		return textToSentences(s); 
		else	return s; 
	} 
	
	//schema, data entry ///////////////////////////////////////////////////////
	
	bool typeCheck(in Id typeId, string data)
	{
		if(const typeName = typeId in items)
		{
			if(isEType(typeId))
			{
				return isInstanceOf(data, typeId); //Todo: supertypes
			}else if(isSystemType(typeName))
			{
					//Todo: slow
				switch(typeName)
				{
					case "String": return true; 
					case "Int": return data.to!int.collectException is null; 
					case "Long": return data.to!long.collectException is null; 
					case "UInt": return data.to!uint.collectException is null; 
					case "ULong": return data.to!ulong.collectException is null; 
					case "DateTime": return data.DateTime.collectException is null; 
					//case "Date": return data.Date.collectException is null;
					//case "Time": return data.Time.collectException is null;
					default: 
				}
			}
		}
		
		error("Unhandled type: "~prettyStr(typeId)); //Todo: prettyStr nem jo ide, mert az exceptionnal nincs szinezes
		return false; 
	} 
	
	private Id[] findATypesForSentence(string[] p, in Id lastTypeId)
	{
		//const T0 = QPS; scope(exit) print("FAFS", p, QPS-T0);
		
		enforce(p.length.among(2, 3), "Invalid sentence length: "~p.text); 
		enforce(isVerb(p[1]), "Unknown verb: "~p.text); 
		Id verbId = items[p[1]]; 
		Id[] res; 
		
		//old slow linear version: foreach(aid, link; links.byId) if(link.verbId==verbId) if(isAType(aid)){
		
		foreach(aid; aTypes)
		{
			const link = links[aid]; 
			if(link.verbId==verbId)
			{
				 //Opt: there should be a map for aTypes by verb
				const sourceIsOk = p[0]=="..." && link.sourceId==lastTypeId || !isAType(link.sourceId) && typeCheck(link.sourceId, p[0]); 
				if(!sourceIsOk)
				continue; 
				
				const targetIsOk = p.length==2 && !link.targetId || p.length==3 && !isAType(link.targetId) && typeCheck(link.targetId, p[2]); 
				if(!targetIsOk)
				continue; 
				
				res ~= aid; 
			}
		}
		return res; 
	} 
	
	private bool walkToSourceAType(ref Id id)
	{
		if(auto link = id in links)
		if(isAType(link.sourceId))
		{
			id = link.sourceId; 
			return true; 
		}
		
		return false; 
	} 
	
	private bool walkToSourceLink(ref Id id)
	{
		if(auto link = id in links)
		if(link.sourceId in links)
		{
			id = link.sourceId; 
			return true; 
		}
		
		return false; 
	} 
	
	
	void processSchemaSentence(string[] p, ref Id id)
	{
		enforce(p.length.among(2, 3), "Invalid sentence length: "~p.text); 
		enforce(id || p[0]!="...", "Last Id is null at sentence:"~p.text); 
		
		p[1] = inputTranslateVerb(p[1]); 
		
		if(isSystemVerb(p[1]))
		{
			if(p[1]=="is a")
			{
				 //Verb and EType assertion
				enforce(p.length==3, "Assertion must have a target: "~p.text); 
				
				switch(p.get(2))
				{
					case "Verb": id = createVerbAssertion(p[0]); break; 
					case "EType": id = createETypeAssertion(p[0]); break; 
					default: enforce(0, "Invalid schema assertion: "~p.text); 
				}
			}else
			{ enforce(0, "Unhandled system verb in schema: "~p.text); }
		}else
		{
			//association type
			id = links.create(
				p[0]=="..." ? id : resolveType(p[0]),
										resolveVerb(p[1]),
										p.length>2 ? resolveType(p[2]) : Id.init
			); 
			
			links.create(id, sysId("is a"), sysId("AType")); 
		}
	} 
	
	void processDataSentence(string[] p, ref Id tid, ref Id id)
	{
		enforce(p.length.among(2, 3), "Invalid sentence length: "~p.text); 
		enforce(id || p[0]!="...", "Last Id is null at sentence:"~p.text);  //same until this point!!!!
		
		p[1] = inputTranslateVerb(p[1]); 
		
		if(isSystemVerb(p[1]))
		{
			if(p[1]=="is a")
			{
					//Entity assertion
				enforce(p.length==3, "Entity assertion must have a target: "~p.text); 
				id = createEntityAssertion(p[0], p[2]); 
			}else
			{ enforce(0, "Unhandled system verb in data: "~p.text); }
		}else
		{
				//association
			
			//find a valid atype for this sentence. Try to step back to sourceId if that is an atype.
			Id[] aTypes; 
			auto tempTid = tid, tempId = id; 
			do
			{ aTypes = findATypesForSentence(p, tempTid); }while(aTypes.empty && p[0]=="..." && walkToSourceAType(tempTid) && walkToSourceLink(tempId)); 
			
			//check if exactly one type found
			if(aTypes.empty)
			error("Unable to find AType for: "~p.text); 
			if(aTypes.length>1)
			error("Ambiguous ATypes found for for: "~p.text~" ["~aTypes.map!(a => prettyStr(a)).join(", ")~"]"); 
			
			//ok to go. Actualize current id and tid after a possible step-back
			id = tempId; 
			tid = tempTid; 
			
			//create the link
			id = links.create(
				p[0]=="..." ? id : items.create(p[0]),
										items[p[1]],
										p.length>2 ? items.create(p[2]) : Id.init
			); 
			tid = aTypes[0]; 
		}
	} 
	
	
	//multiline bulk processing
	
	private Id lastSchemaId; 
	
	void schema(string input)
	{
		lastDataTypeId = lastDataId = Id.init; //reset the state of other input categories
		
		foreach(s; textToSentences(input))
		processSchemaSentence(s, lastSchemaId); 
	} 
	
	private Id lastDataId, lastDataTypeId; 
	
	void data(string input)
	{
		lastSchemaId = Id.init; //reset the state of other input categories
		
		foreach(s; textToSentences(input))
		processDataSentence(s, lastDataTypeId, lastDataId); 
	} 
	
	//query ////////////////////////////////////////////////////////
	
	struct QueryInputSources
	{
		bool items, schema, entities, data; 
		
		@property bool any () const
		{ return items || schema || entities || data; } 
		@property bool all () const
		{ return items && schema && entities && data; } 
		@property bool none() const
		{ return !any; } 
		
		@property bool anyLinks() const
		{ return schema || entities || data; } 
		@property bool anyItems() const
		{ return items; } 
		
		void setFlags(string flags)
		{
			this = typeof(this).init; 
			if(flags.canFind('i'))
			items	= true; 
			if(flags.canFind('s'))
			schema	= true; 
			if(flags.canFind('e'))
			entities	= true; 
			if(flags.canFind('d'))
			data	= true; 
			if(flags.canFind('a'))
			items = schema = entities = data = true; 
			
			//none means only the 'data'
			if(none)
			data = true; 
		} 
		
		bool check(char thingCategory) const
		{
			if(all)
			return true; 
			if(none)
			return false; 
			switch(thingCategory)
			{
				case 'i': return items; 
				case 's': return schema; 
				case 'e': return entities; 
				case 'd': return data; 
				default: return false; 
			}
		} 
	} 
	
	struct QueryOptions
	{
		QueryInputSources sources;  alias sources this; 
		bool extendLeft, extendRight; 
	} 
	
	private auto fetchQueryOptions(ref string input)
	{
		auto flags = input.fetchRegexFlags; 
		QueryOptions res; 
		
		res.sources.setFlags(flags); 
		
		//extend left and right
		res.extendRight	= input.endsWith  ("..."); 	 if(res.extendRight)
		input = input.withoutEnding  ("..."); 
		res.extendLeft	= input.startsWith("..."); 	 if(res.extendLeft)
		input = input.withoutStarting("..."); 
		
		return res; 
	} 
	
	
	/// own version of wildcard check specialized to AMDB
	private bool chkStr(string s, string mask)
	{ return s.isWild(mask); } 
	
	private bool chkId(in Id id, string mask)
	{
		 //Todo: ez mehetne a filter-be is, mert hasonlo
		string s; 
		if(!id)
		s = "null"; 
		else if(auto a = id in items) s = a; 
		else if(id in links) s = "..."; 
		else NOTIMPL; 
		
		//mask : eType
		if(mask.canFind(':'))
		{
			auto p = mask.split(':').map!strip; 
			enforce(p.length==2, "Invalid typed mask format"); 
			
			const itemMask	= p[0]=="" ? "*" : p[0]; 
			const eTypeMask	= p[1]=="" ? "*" : p[1]; 
			
			return chkStr(s, itemMask) && !filter2(id, "is a", eTypeMask).empty; 
		}
		
		return chkStr(s, mask); 
	} 
	
	enum QuerySource
	{ all, data, schema, items} 
	
	Id[] query(string[] p, in QueryInputSources qs)
	{
		 //works on a single sentence
		
		bool checkQuerySourceLinks(in Id id)
		{ return qs.check(thingCategory(id)); } 
		
		Id[] res; 
		if(p.length==1)
		{
			if(qs.anyLinks)
			foreach(id, const link; links.byId)
			{
					//Opt: linear
				if(!checkQuerySourceLinks(id))
				continue; 
				if(chkId(link.sourceId, p[0]) || chkId(link.verbId, p[0]) || chkId(link.targetId, p[0]))
				res ~= id; //x  ->  x can be at any place
			}
			
			if(qs.anyItems)
			foreach(id; items.ids)
			{
							//Opt: linear
				if(chkId(id, p[0]))
				res ~= id; //also can be an item too
			}
			
		}else if(p.length==2)
		{
			if(qs.anyLinks)
			foreach(id, const link; links.byId)
			{
					//Opt: linear
				if(!checkQuerySourceLinks(id))
				continue; 
				if(!link.targetId && chkId(link.sourceId, p[0]) && chkId(link.verbId, p[1]))
				res ~= id; //target must be null
			}
			
		}else if(p.length==3)
		{
			if(qs.anyLinks)
			foreach(id, const link; links.byId)
			{
					//Opt: linear
				if(!checkQuerySourceLinks(id))
				continue; 
				if(chkId(link.sourceId, p[0]) && chkId(link.verbId, p[1]) && chkId(link.targetId, p[2]))
				res ~= id; 
			}
			
		}else
		NOTIMPL; 
		return res; 
	} 
	
	/// Extends srcIds with referencing child links. Sentence must start with "..."
	Id[] query(Id[] sourceIds, string[] p)
	{
		Id[] res; 
		enforce(p.length.among(2, 3), `Invalid sentence for srcId based query. Invalid sentence length. `~p.text); 
		enforce(p.get(0)=="...", `Invalid sentence for srcId based query. Source must be "...". `~p.text); 
		if(p.length==2)
		{
			foreach(sourceId; sourceIds)
			{
				foreach(id, const link; links.byId)
				{
						//Opt: linear
					/*if(link.sourceId==sourceId && !link.targetId && chkId(link.verbId, p[1])) res ~= id;*/
					if(link.sourceId==sourceId && (chkId(link.verbId, p[1]) || chkId(link.targetId, p[1])))
					res ~= id;  //...x  ->  x can be at any place
				}
			}
		}else if(p.length==3)
		{
			foreach(sourceId; sourceIds)
			{
				foreach(id, const link; links.byId)
				{
						//Opt: linear
					if(link.sourceId==sourceId && chkId(link.verbId, p[1]) && chkId(link.targetId, p[2]))
					res ~= id; 
				}
			}
		}
		return res; 
	} 
	
	/// Extends srcIds with referencing child links. generalized recursive version, works with more than one sentence
	Id[] query(Id[] sourceIds, string[][] sentences)
	{
		while(sentences.length)
		sourceIds = query(sourceIds, sentences.fetchFront); 
		return sourceIds; 
	} 
	
	Id[] query(T)(T sentences, in QueryInputSources qs)
	{
			//works on sentences
		Id[] res; 
		auto s = toSentences(sentences); 
		if(s.length==0)
		return null; //empty query
		if(s.length==1)
		return query(s[0], qs); //one sentence
		return query(query(s[0], qs), s[1..$]); //many sentences in a chain
	} 
	
	IdSequence extend(in Id id, in QueryOptions queryOptions)
	{
		auto seq = IdSequence([id]); 
		if(queryOptions.extendRight)
		seq = extendRight(seq); 
		if(queryOptions.extendLeft)
		seq = extendLeft (seq); 
		return seq; 
	} 
	
	IdSequence[] query(T)(T sentences, in QueryOptions queryOptions)
	{
			//this version does left/right extensions too
		return query(sentences, queryOptions.sources).sort.map!(i => extend(i, queryOptions)).array; 
	} 
	
	static struct IdSequence
	{
		 //IdSequence ///////////////////////////////////////
		Id[] ids; 
		int leftExtension, rightExtension; 
		
		@property int centerIdx() const
		{ return ids.length.to!int-1-rightExtension; } 
		
		void appendLeft (Id   ext)
		{ ids = ext ~ ids; leftExtension  ++; } 
		void appendRight(Id   ext)
		{ ids =       ids ~ ext; rightExtension ++; } 
		void appendLeft (Id[] ext)
		{ ids = ext ~ ids; leftExtension  += ext.length.to!int; } 
		void appendRight(Id[] ext)
		{ ids =       ids ~ ext; rightExtension += ext.length.to!int; } 
		
		int[] coulmnIndices(AMDBCore db) const
		{
			int[] indices; 
			Id[] stack; 
			foreach(id; ids)
			{
				if(!id)
				{
					stack ~= id; //nothing to do with null
				}else
				{
					//measure how much to step back for the parent
					sizediff_t backSteps = -1; 
					auto link = id in db.links; 
					if(!stack.empty && link)
					backSteps = stack.retro.countUntil!(s => !s || s == link.sourceId); 
					
					if(backSteps==0)
					stack ~= id; 
					else if(backSteps> 0) stack = stack[0..$-backSteps]~id; 
					else stack = [id]; //no connection -> restart the stack
				}
				indices ~= (cast(int)stack.length)-1; 
			}
			return indices; 
		} 
	} 
	
	//extend Left/Right //////////////////////////////////////////////////////////
	
	private enum defaultExtendLeftRecursion = 100; 
	
	IdSequence extendLeft(IdSequence seq, int recursion=defaultExtendLeftRecursion)
	{
		foreach(i; 0..recursion)
		{
			if(seq.ids.length)
			if(
				auto link = seq.ids[0] in links.byId//Opt: linear
			)
			if(link.sourceId in links)
			{
				seq.appendLeft(link.sourceId); 
				continue; 
			}
			break; 
		}
		return seq; 
	} 
	
	IdSequence extendRight(IdSequence seq)
	{
		Id[] sourceExtension(in Id sourceId)
		{ return sourceReferrers(sourceId).map!(i => i ~ sourceExtension(i)).join.sort.array; } 
		if(seq.ids.length && seq.ids[$-1]in links)
		seq.appendRight(sourceExtension(seq.ids[$-1])); 
		return seq; 
	} 
	
	//pads with empty sentences from the left to equalize the lengths of the left-extensions
	IdSequence[] padLeft(IdSequence[] seqs)
	{
		if(seqs.empty)
		return seqs; 
		int maxLeftExtension = seqs.map!(s => s.leftExtension).maxElement; 
		foreach(ref s; seqs)
		{
			int a = max(maxLeftExtension-s.leftExtension, 0); 
			if(a>0)
			{
				s.ids = [Id.init].replicate(a) ~ s.ids; 
				s.leftExtension += a; 
			}
		}
		return seqs; 
	} 
	
	//text mode interface ////////////////////////////////////////////
	
	void printFilteredSortedItems(R)(R r, string mask="")
	{ r.filter!(i => mask=="" || chkId(i, mask)).array.sort!((a,b)=>icmp(items.get(a, ""), items.get(b, ""))<0).each!(i => print(prettyStr(i))); } 
	
	void tryDelete(Id[] ids)
	{
		print("-------------------------------------------------------"); 
		Id[] remaining; 
		bool anyDeleted; 
		
		do
		{
			anyDeleted = false; 
			foreach(id; ids)
			if(hasReferrers(id))
			{ remaining ~= id; }else
			{
				print("DELETING", prettyStr(id)); 
				deleteThing(id); 
				anyDeleted = true; 
			}
			
			ids = remaining; 
		}while(ids.length && anyDeleted); 
		
		if(ids.length)
		WARN("Unable to delete all"); //Todo: wipe
	} 
	
	auto query(string input)
	{
		const options = fetchQueryOptions(input); 
		return query(input, options); 
	} 
	
	int execTextCommand(string input)
	{
		input = input.strip; 
		
		try
		{
			string cmd = input.wordAt(0); 
			input = input[cmd.length..$].strip; 
			
			switch(cmd.lc)
			{
				case "id": print(prettyStr(extendLeft(IdSequence([Id(input.to!uint)])))); break; 
				
				case "s", "schema": schema(input); break; 
				case "d", "data": data(input); break; 
				case "q", "query": {
					//const options = fetchQueryOptions(input);
					auto res = padLeft(query(input/*, options*/)); 
					printTable(res); 
				}break; 
				
				case "items": printFilteredSortedItems(items.ids, input); break; 
				case "etypes": printFilteredSortedItems(eTypes   , input); break; 
				case "verbs"	: printFilteredSortedItems(verbs    , input); break; 
				case "entities": 	printFilteredSortedItems(entities(input=="" ? "*" : input)); break; 
				
				case "commit": transaction.commit; break; 
				case "cancel": transaction.cancel; break; 
				
				case "info": 
					 print("Engine     : AMDB", versionStr); 
					 print("  Built    :", DateTime(__TIMESTAMP__).timestamp); 
					 writeln; 
					 print("File       :", file.fullName); 
					 print("  Size     :", format!"%.1f"(file.size/1024.0), "KB"); 
					 print("  Created  :", file.created.timestamp); 
					 print("  Modified :", file.modified.timestamp); 
					 print("  Accessed :", file.accessed.timestamp); 
					 print("  Now      :", now.timestamp); 
					 writeln; 
					 const itemBytes = items.ids.map!(i => serializeText(i).length+1).sum; writefln!"Items: %8d %8.1f KB"(items.count, itemBytes/1024.0); 
					 const linkBytes = links.ids.map!(i => serializeText(i).length+1).sum; writefln!"Links: %8d %8.1f KB"(links.count, linkBytes/1024.0); 
					 writefln!"Total: %8d %8.1f KB"(items.count+links.count, (itemBytes+linkBytes)/1024.0); 
					 writeln; 
					 writeln("Commit buffer entries: ", transaction.commitBuffer.length ? EgaColor.red(transaction.commitBuffer.length.text) : "0"); 
				break; 
				
				case "commitbuffer", "commitbuf": transaction.commitBuffer.each!print; break; 
				case "cancelbuffer", "cancelbuf": transaction.cancelBuffer.each!print; break; 
				
				case "exit": case "x": enforce(!transaction.active, "Pending transaction. Use \"commit\" or \"cancel\" before exiting."); return false; 
				
				default: error("Unknown command: "~cmd.quoted); 
			}
		}catch(Exception e)
		{ print(EgaColor.ltRed("ERROR:"), e.simpleMsg); }
		
		writeln; 
		return true; 
	} 
	
	string inputTextCommand()
	{
			//prompt
			write(EgaColor.white(">"), format!" I:%d + L:%d = %d %s"(items.count, links.count, items.count+links.count, transaction.commitBuffer.length ? EgaColor.red("*"~transaction.commitBuffer.length.text~" ") : "")); 
		
		/*
			switch(textCommandMode){
				case 's': write(EgaColor.ltMagenta("schema ")); break;
				case 'd': write(EgaColor.ltBlue	 ("data ")); break;
				case 'q': write(EgaColor.ltGreen	 ("query ")); break;
				default: raise("invalid mode");
			}
		*/
			write(EgaColor.white("> ")); 
		
			return readln; 
	} 
	
	void textCommandLoop()
	{
		while(execTextCommand(inputTextCommand))
		{}
	} 
	
} 


auto myHashOf(in ubyte[] data)
{ return data.xxh3_64; } 

auto myHashStrOf(in ubyte[] data)
{ return data.xxh3_64.to!string(36); } 

auto myHashStrOf(in File f)
{ return f.read(false).xxh3_64.to!string(36); } 

int utcYearMonth(DateTime d)
{
	if(!d)
	return 0; 
	with(d.utcSystemTime)
	return wYear*100 + wMonth; 
} 

int utcYearQuarter(DateTime d)
{
	if(!d)
	return 0; 
	with(d.utcSystemTime)
	return wYear*10 + ((wMonth-1)/3)+1; 
} 

int utcYear(DateTime d)
{
	if(!d)
	return 0; 
	with(d.utcSystemTime)
	return wYear; 
} 

class FileHashCache
{
	File file; 
	@STORED string[string] data; 
	int changedCnt; 
	
	void save() const
	{ this.toJson.saveTo(file); LOG; } 
	
	void load()
	{ auto a = this; a.fromJson(file.readStr(false)); } 
	
	this(File file)
	{
		this.file = file; 
		load; 
	} 
	
	string getHash(File f)
	{
		string fn = f.fullName; 
		if(auto a = fn in data)
		{ return *a; }else
		{
			if(changedCnt++ > 256)
			{
				changedCnt = 0; 
				save; 
			}
			return data[fn] = myHashStrOf(f); 
		}
	} 
	
	string opIndex(File f)
	{ return getHash(f); } 
} 

struct PictureRecord
{
	string name; //fully qualified name, unique in this library
	ulong offset, size, hash;     //offset==0: it's a redundant file. Must be searched by hash.
	DateTime modified, imported; 
} 

class PictureLibrary
{
	File dirFile; 
	PictureRecord[] records; //in import order
	
	const(PictureRecord)*[][ulong] recordsByHash; //allow multiple records
	const(PictureRecord)*[ulong] recordByHashNameTime; 
	
	static ulong hashNameTimeOf(in ulong hash, in string name, in DateTime dt)
	{ return name.xxh3_64(hash+dt.toId_deprecated); } 
	
	static ulong hashNameTimeOf(in PictureRecord r)
	{ return hashNameTimeOf(r.hash, r.name, r.modified); } 
	
	bool exists(in PictureRecord rec)
	{
		const hnt = hashNameTimeOf(rec); 
		return (hnt in recordByHashNameTime) !is null; 
	} 
	
	private File originalArchiveFileOf(in PictureRecord rec)
	{
		//Note: DON'T CHANGE THIS!!!!
		return File(dirFile.otherExt("").fullName~"_"~rec.modified.utcYearMonth.text~".arch"); 
	} 
	
	auto exportRecord(size_t idx)
	{
		static struct Result
		{
			string name; 
			DateTime modified; 
			ulong hash; 
			ubyte[] data; 
		} 
		
		enforce(idx.inRange(records)); 
		auto rec = records[idx]; 
		Result result; 
		
		result.name	= rec.name,
		result.modified 	= rec.modified,
		result.hash	= rec.hash; 
		
		rec = *recordsByHash[result.hash][0]; //lookup agai to find the first one
		result.data	= originalArchiveFileOf(rec).read(true, rec.offset, rec.size); 
		if(result.hash != myHashOf(result.data)) ERR("CRC error: "~rec.text); 
		
		return result; 
	} 
	
	
	void internalAddToRecordToCaches(const(PictureRecord)* rec)
	{
		const hnt = hashNameTimeOf(*rec); 
		enforce((hnt in recordByHashNameTime) is null, "Fatal Error: PictureRecord Already exists "~rec.text); 
		recordByHashNameTime[hnt] = rec; 
		
		if(auto a = rec.hash in recordsByHash)
		{ *a ~= rec; }else
		recordsByHash[rec.hash] = [rec]; 
	} 
	
	this(File dirFile_, Flag!"create" create = No.create)
	{
		dirFile = dirFile_.normalized; 
		if(create)
		{
			print("Creating PictureLibrary:", dirFile); 
			enforce(!dirFile.exists, "Already exists, delete first: "~dirFile.text); 
			dirFile.write(""); 
		}else
		{
			print("Opening PictureLibrary:", dirFile); 
			enforce(dirFile.exists, "File not exists: "~dirFile.text); 
			auto txt = "["~dirFile.readText(true)~"]"; 
			records.fromJson(txt, "PictureLibrary("~dirFile.text~")", ErrorHandling.raise); //Opt: 5sec for 35 megs... json is slow
			foreach(ref r; records)
			internalAddToRecordToCaches(&r); 
			
			print("total count:", records.length); 
			print("total size:", records.map!"a.size".sum.shortSizeText!1024); 
			print("unique count:", recordsByHash.byValue.walkLength); 
			print("unique size:", recordsByHash.byValue.map!"a[0].size".sum.shortSizeText!1024); 
			print; 
		}
	} 
	
	void add(FileEntry[] srcEntries, Path srcPath, FileHashCache hashCache)
	{
		PictureRecord[] goodRecords, badRecords; 
		
		srcPath = srcPath.normalized; 
		
		//process
		foreach(entry; srcEntries)
		{
			PictureRecord rec; 
			bool good=false; 
			try
			{
				auto f = entry.file; 
				enforce(f.fullPath.startsWith(srcPath.fullPath), "File is not in srcPath: "~f.text~" "~srcPath.text); 
				//too slow enforce(f.exists, "File not exists: "~f.fullName.quoted);
				enforce(f.extIs("jpg", "jpeg", "webp", "gif"), "Unsupported file extension: "~entry.ext.quoted); 
				
				//rec.name is just the filename right after srcPath without the starting '\'
				rec.name = entry.fullName[srcPath.fullPath.length..$]; 
				rec.modified = entry.modified; 
				rec.size = entry.size; 
				
				enforce(rec.size, "File is empty: "~f.text); 
				
				good = true; 
			}catch(Exception ex)
			{ rec.name = ex.simpleMsg; }
			
			(good ? goodRecords : badRecords) ~= rec; 
		}
		
		//report collected errors
		if(badRecords.length)
		throw new Exception("There were errors importing into PictureLibrary\n"~badRecords.map!(r => r.name).join("\n")); 
		
		foreach(idx, r; goodRecords)
		{
			auto f = File(srcPath, r.name); 
			r.hash = hashCache[f].to!ulong(36); 
			r.imported = now; 
			
			write(idx.text, " / ", goodRecords.length.text, " ", r.text); 
			try
			{
				if(exists(r))
				{ print(EgaColor.ltWhite("Exact file occurence already exists.")); }else
				{
					if(auto hr = r.hash in recordsByHash)
					{ print(EgaColor.ltGreen("File contents exists previously "~hr.length.text~" times.")); }else
					{
						print(EgaColor.yellow("Importing new file.")); 
						
						//append file data
						auto fArch = originalArchiveFileOf(r); 
						{
							auto sf = StdFile(originalArchiveFileOf(r).fullName, "a+b"); 
							sf.rawWrite("\nFile:"~r.name~"\nHash:"~r.hash.to!string(36)~"\nModified:"~r.modified.utcTimestamp~"\nImported:"~r.imported.utcTimestamp~"\nSize:"~r.size.text~"\n"); 
							r.offset = sf.size; 
							sf.rawWrite(f.read(true)); 
							sf.close; 
						}
					}
					
					//append record
					{ auto df = StdFile(dirFile.fullName, "a+b");  df.rawWrite(r.toJson~",\n");  df.close; }
					records ~= r; 
					internalAddToRecordToCaches(&r); 
				}
			}catch(Exception e)
			{ ERR(e.simpleMsg); }
		}
	} 
	
} version(/+$DIDE_REGION DataSet+/all)
{
		mixin  template DatasetTemplate(K, R)
	{
		private
		{
			alias This = typeof(this); 
			enum isSimpleField(T) 	= __traits(isPOD, T) 
				&& !isDynamicArray!T 
				&& !isAssociativeArray!T; 
			//Todo: it can't look inside structs: It says it's circular, but I think it's NOT!!!
			
			enum isMainAACustom = __traits(hasMember, This, "MainAA"); 
			static if(isMainAACustom)	public MainAA!(K, R) _aa; 
			else	R[K] _aa; 
			
			auto _set(T)(K key, T value_)
			{
				static if(__traits(compiles, cast(R) value_))
				auto value = cast(R) value_; 
				else
				auto value = R(value_); 
				
				const creating = key !in _aa, modifying = !creating; 
				
				static if(__traits(compiles, _rb))
				if(_rb && creating)	_rb.insert(key); 
				_aa[key] = value; 
				
				static if(__traits(hasMember, This, "afterCreate"))
				if(creating) afterCreate(key, value); 
				static if(__traits(hasMember, This, "afterModify"))
				if(modifying) afterModify(key, value); 
				static if(__traits(hasMember, This, "afterAssign"))
				afterAssign(key, value); 
				
				return _recordAccessor(key, key in _aa); 
			} 
			
			auto _get(Flag!"raise" raise)(K key)
			{
				auto a = key in _aa; 
				if(raise) enforce(a, "Key not found."); 
				return _recordAccessor(key, a); 
			} 
			
			auto _unorderedKeys()
			{ return _aa.byKey; } 
			
			enum isBlobAACustom = __traits(hasMember, This, "BlobAA"); 
			
			static if(is(R.Blobs))
			{
				static immutable _blobNames = [FieldNameTuple!(R.Blobs)]; 
				alias _blobTypes = FieldTypeTuple!(R.Blobs); 
			}
			else
			{
				static immutable _blobNames = (string[]).init; 
				alias _blobTypes = AliasSeq!(); 
			}
			
			static foreach(i, T; _blobTypes)
			mixin(
				format!
				(((isBlobAACustom)?(q{BlobAA!(K, %s) _blobAA_%s; }) :(q{%s[K] _blobAA_%s; })))
				(T.stringof, _blobNames[i])
			); 
			
			
			final void _blobSet(string field, T)(K key, T value)
			{
				const creating = key !in mixin("_blobAA_"~field), modifying = !creating; 
				
				mixin("_blobAA_"~field)[key] = value; 
				
				static if(__traits(hasMember, This, "afterCreateBlob"))
				if(creating) afterCreateBlob!field(key, value); 
				static if(__traits(hasMember, This, "afterModifyBlob"))
				if(modifying) afterModifyBlob!field(key, value); 
				static if(__traits(hasMember, This, "afterAssignBlob"))
				afterAssignBlob!field(key, value); 
			} 
			
			final auto _blobGet(string field)(K key)
			{
				auto a = key in mixin("_blobAA_"~field); 
				return a; 
				//Note: No unpacking done here! It must be consequent.
			} 
			
			auto _recordAccessor(K key, R* record)
			{
				static struct RecordAccessor
				{
					This _logger; 
					K key; 
					const(R)* _record; 
					
					bool opCast(B : bool)() const
					{ return _record !is null; } 
					
					static foreach(i, T; FieldTypeTuple!R)
					static if(isSimpleField!T)
					mixin(
						q{
							@property auto $()
							{ return _record.$; } 
						}.replace("$", FieldNameTuple!R[i])
					); 
					else static assert(0, format!"Invalid DataLogger field: %s %s;"(T.stringof, FieldNameTuple!R[i])); 
					
					static foreach(name; _blobNames)
					{
						mixin(
							q{
								@property auto $()
								{ return _logger._blobGet!`$`(key); } 
								@property void $(T)(T data)
								{ _logger._blobSet!`$`(key, data); } 
							}.replace("$", name)
						); 
					}
				} 
				
				return RecordAccessor(this, key, record); 
			} 
			
			enum OrderedKeysEnabled = __traits(hasMember, This, "OrderedKeys") && OrderedKeys; 
			static if(OrderedKeysEnabled)
			{
				import std.container.rbtree; 
				RedBlackTree!(K, "a<b", false/+no duplicates+/) _rb; 
				
				auto _rb_access()
				{
					if(!_rb) _rb = new typeof(_rb)(_unorderedKeys); 
					return _rb; 
				} 
				
				auto _orderedKeys()
				{ return _rb_access[]; } 
				
				auto _orderedKeyInterval(K key0, K key1)
				{
					//dec key0 just a little bit, because RBTree.upperBound() is exclusive
					static if(is(K==DateTime)) key0 = key0 ? RawDateTime(key0.raw-1) : key0; 
					else static if(isFloatingPoint!K) key0 = key0.nextDown; 
					else key0--; 
					
					return _rb_access	.upperBound(key0)
						.until!(k=>k >= key1); 
				} 
			}
		} 
		auto length()
		{ return _aa.length; } auto empty()
		{ return !length; } 
		
		auto keys()
		{
			static if(OrderedKeysEnabled) return _orderedKeys; 
			else return _unorderedKeys; 
		} 
		
		auto opIndex(K key)
		{ return _get!(Yes.raise)(key); } auto opIndexAssign(T)(T value, K key)
		{ return _set(key, value); } 
		
		auto opIndex()
		{ return keys.map!(k => _get!(No.raise)(k)); } 
		
		auto opBinaryRight(string op : "in")(K key)
		{ return _get!(No.raise)(key); } 
		
		K[2] opSlice(size_t dim)(K key0, K key1)
		{ return [key0, key1]; } 
		
		static if(OrderedKeysEnabled)
		{
			auto keys(K k0, K k1)
			{ return _orderedKeyInterval(k0, k1); } 
			
			auto minKey()
			{ return empty ? K.init : _orderedKeys.front; } 
			
			auto maxKey()
			{ return empty ? K.init : _orderedKeys.back; } 
			
			auto opIndex(K[2] k /+[incl..excl) range+/)
			{ return _orderedKeyInterval(k[0], k[1]).map!(k => _get!(No.raise)(k)); } 
		}
		
	} 
		version(/+$DIDE_REGION DataSet tests+/all)
	{
		void testDataset()
		{
			struct TestRecord
			{
				align(1)
				{
					char[4] type; 
					int width, height; 
					vec3 v; 
				} 
				struct Blobs
				{
					string descr; 
					const(void)[] data; 
				} 
			} struct DummyAA(K, V)
			{
				V[K] aa; 
				auto opBinaryRight(string op : "in")(K key) { return key in aa; } 
				auto opIndexAssign(in V value, in K key) { return aa[key] = value; } 
				auto length() { return aa.length; } 
				auto byKey() { return aa.byKey; } 
			} 
			
			class TestDataset(K, R)
			{
				enum OrderedKeys = true; 
				alias MainAA = DummyAA,
				BlobAA = DummyAA; 
				
				mixin DatasetTemplate!(K, R); 
				
				void afterCreate(K, R)(K key, R value) { print("\33\14Record created:\33\7", key, value); } 
				void afterModify(K, R)(K key, R value) { print("\33\14Record modified:\33\7", key, value); } 
				void afterAssign(K, R)(K key, R value) { print("\33\14Record assigned:\33\7", key, value); } 
				void afterCreateBlob(string field, K, R)(K key, R value) { print("\33\14Blob created:\33\7", field, key, value); } 
				void afterModifyBlob(string field, K, R)(K key, R value) { print("\33\14Blob modified:\33\7", field, key, value); } 
				void afterAssignBlob(string field, K, R)(K key, R value) { print("\33\14Blob assigned:\33\7", field, key, value); } 
			} 
			
			auto logger = new TestDataset!(DateTime, TestRecord); 
			
			//feed some data
			TestRecord record = { "HELL", 320, 200, vec3(5)}; 
			logger[DateTime(UTC, 2000, 1, 9)] = record; 
			logger[DateTime(UTC, 2000, 1, 9)] = record; //this one is a modification
			logger[DateTime(UTC, 2000, 1, 3)] = record; 
			logger[DateTime(UTC, 2000, 1, 7)] = record; 
			logger[DateTime(UTC, 2000, 1, 8)] = record; 
			
			
			//access specific data
			with(logger[DateTime(UTC, 2000, 1, 9)])
			print(key, type, width, height, v); 
			
			if(auto a = DateTime(UTC, 2000, 1, 8) in logger)
			with(a)
			print(key, type, width, height, v); 
			
			//check if data is not in
			if(DateTime(UTC, 2000, 1, 4) !in logger)
			print("not found"); 
			
			//access range of keys  (uses optionally built rbTree)
			logger.keys.each!print; 
			logger.keys(DateTime(UTC, 2000, 1, 7), DateTime(UTC, 2000, 1, 9)).each!print; 
			
			//access data of key ranges
			logger[DateTime(UTC, 2000, 1, 7) .. DateTime(UTC, 2000, 1, 9)].each!print; 
			logger[].each!print; 
			
			//set blobs
			logger[DateTime(UTC, 2000, 1, 9)].descr = "Description"; 
			logger[DateTime(UTC, 2000, 1, 8)].data = [1, 2, 3]; 
			
			//get blobs
			logger[DateTime(UTC, 2000, 1, 9)].descr.print; 
			logger[DateTime(UTC, 2000, 1, 8)].data().print; 
			
			//get properties of blobs
			logger[DateTime(UTC, 2000, 1, 9)].descr().length.print; 
			logger[DateTime(UTC, 2000, 1, 8)].data.length.print; 
			
			//access to the whole record
			(*(logger[DateTime(UTC, 2000, 1, 8)]._record)).toJson.print; 
			
		} mixin template _DatasetTemplateDebug(K, R)
		{
			/+
				Note: This thing was used to solve the lod0().property problem.
				Probably the fix was that all properties started using generic (T) type.
				Same type, same unknown alias name.
				/+Link: https://forum.dlang.org/post/cyvewilqnctwohcexfpc@forum.dlang.org+/
			+/
			alias This = typeof(this); 
			R[K] _aa; 
			
			static immutable _blobNames = [FieldNameTuple!(R.Blobs)]; 
			alias _blobTypes = FieldTypeTuple!(R.Blobs); 
			
			static foreach(i, T; _blobTypes)
			mixin(format!q{%s[K] _blobAA_%s; }(T.stringof, _blobNames[i])); 
			
			
			auto _recordAccessor(K key, R* record)
			{
				static struct RecordAccessor
				{
					This _logger; 
					K key; 
					const(R)* _record; 
					
					bool opCast(B : bool)() const
					{ return _record !is null; } 
					
					static foreach(name; FieldNameTuple!(R.Blobs))
					{
						mixin(
							format!q{
								@property auto %1$s()
								{ return key in _logger._blobAA_%1$s; } 
								@property void %1$s(T)(T data)
								{ _logger._blobAA_%1$s[key] = data; } 
							}(name)
						); 
					}
				} 
				
				return RecordAccessor(this, key, record); 
			} 
			
			auto opIndex(K key)
			{
				auto a = key in _aa; 
				return _recordAccessor(key, a); 
				
			} 
			
			auto opIndexAssign(T)(T value, K key)
			{
				_aa[key] = value; 
				return _recordAccessor(key, key in _aa); 
			} 
			
		}  void testDatasetPropertyAccess()
		{
			struct TestRecord2
			{
				align(1)
				{ int width, height; } 
				struct Blobs
				{ string descr; } 
			} 
			
			class TestDataset2(K, R)
			{ mixin _DatasetTemplateDebug!(K, R); } 
			
			auto logger = new TestDataset2!(ulong, TestRecord2); 
			
			//feed some data
			TestRecord2 record = { 320, 200}; 
			logger[42] = record; 
			
			//set blobs
			logger[42].descr = "Description"; 
			
			//get blobs
			logger[42].descr.print; 
			logger[42].descr().print; 
			
			//get properties of blobs
			//static assert(!__traits(compiles, logger[42].descr.length));
			logger[42].descr().length.print; 
			logger[42].descr.length.print; 
			//Todo: "zero arg functions passed through properties" are broken.
		} 
	}
}version(/+$DIDE_REGION DataLogger+/all)
{
	
	class DataLogger(K, R, R_default=void)
	{
		public
		{
			/+
				Note: 
							𝐅𝐢𝐥𝐞𝐧𝐚𝐦𝐞 𝐬𝐩𝐞𝐜𝐢𝐟𝐢𝐜𝐚𝐭𝐢𝐨𝐧
				
					path\namePrefix[.index].timestamp[.field].ext
				
				 • namePrefix	example: Log
				 • index	autoincrement, 5 digits
				 • timestamp 	23-01-01T18-26-32U      easily readable UTC
				 • field	optional blob field
				 • ext	 • .main	Main stream of records
					 • .blob 	Blob data (string or const(ubyte)[])
					 • .bidx 	Index for blobs
				
			+/struct DataLoggerUtils
			{
				static immutable timestampWildMask = "????-??-??T??-??-??Z"; 
				
				static string encodeTimestamp(DateTime t)
				{
					if(!t) return "NULL"; 
					with(t.utcSystemTime)
					return 	format!"%04d-%02d-%02dT%02d-%02d-%02dZ"
						(wYear, wMonth, wDay, wHour, wMinute, wSecond); 
				} 
				
				static string extractWildMask(File file)
				{
					return file.name	.splitter('.')
						.enumerate
						.map!(a=>((a.index==1)?(timestampWildMask) :(a.value)))
						.join('.'); 
				} 
			} struct DataLoggerAA(K, V)
			{
				static assert(isFixedSizeOpaqueType!K); 
				static assert(isFixedSizeOpaqueType!V); 
				
				V[K] aa; 
				File logFile; 
				auto opBinaryRight(string op : "in")(K key) { return key in aa; } 
				auto length() { return aa.length; } 
				auto byKey() { return aa.byKey; } 
				auto opIndexAssign(in V value, in K key)
				{
					if(logFile)
					{
						if(!logFile.exists)
						logFile.append(keyValueDefOf!(K, V).jsonPacket); 
						
						//!!!! Fixed size record handling.  Dynamic data is in blobs!
						logFile.append([key]); 
						logFile.append([value]); 
					}
					else raise("Can't write data: No log file specified."); 
					
					//Todo: Use winapi files
					return aa[key] = value; 
				} 
				
				void load()
				{
					const t0 = now; scope(exit) print(now-t0); 
					
					aa.clear; 
					const mask = DataLoggerUtils.extractWildMask(logFile); 
					
					K[] keys; V[] values; 
					
					foreach(f; logFile.path.files(mask).sort)
					{
						try
						{ importKeyValues!(K, V, R_default)(f.read(true), keys, values); }
						catch(Exception e)
						{ WARN(e.simpleMsg); }
					}
					
					//create the full AA in a single pass.
					aa = assocArray(keys, values); 
				} 
			} 
			struct DataLoggerBlobAA(K, V)
			{
				struct FileBlockRef
				{
					File file; size_t offset, size; 
					//Todo: FileBlockRef should have a text form: fn.ext?ofs=123&size=456
				} 
				FileBlockRef[K] aaIdx; 
				File idxFile, dataFile; 
				auto length() { return aaIdx.length; } 
				auto byKey() { return aaIdx.byKey; } 
				auto opIndexAssign(in V value, in K key)
				{
					auto raw = cast(void[]) value; 
					const 	offset 	= dataFile.size, 
						size	= raw.length; 
					
					//Content must be written first, if HDD is full, this will fail first.
					if(dataFile && idxFile)
					{
						dataFile.append(raw); 
						
						idxFile.append([key]); 
						idxFile.append([offset, size]); 
					}
					else raise("Can't write data: No data and/or idx file specified."); 
					
					//Todo: Use winapi files
					
					aaIdx[key] = FileBlockRef(dataFile, offset, size); 
					//Bug: try to do atomic operation with proper exception handling
					//Todo: implement locked file operations.
					//Opt: also it's fcking slow to open and close all the time.
					
					return value; 
				} 
				
				auto opBinaryRight(string op : "in")(K key)
				{
					static struct BlobLoader
					{
						/+
							Note: This voldemort struct is required to emulate the AA's pointer access.
							This result must not be dereferenced.
						+/
						const FileBlockRef _fileBlockRef; 
						@property
						{
							auto _file() const
							{ return _fileBlockRef.file; } auto _offset() const
							{ return _fileBlockRef.offset; } auto _size() const
							{ return _fileBlockRef.size; } 
							
							auto _data()
							{
								return _file.read(true, _offset, _size); 
								//it will throw if can't read.
							} 
							
							bool _valid() const
							{ return !!_file; } bool _exists() const
							{ return _offset + _size <= _file.size; } 
						} 
						
						alias _data this; 
						
						auto opCast(B : bool)() const { return _valid; } 
					} 
					
					if(const a = key in aaIdx)	{ return BlobLoader(*a); }
					else	{ return BlobLoader(); }
				} 
				
				void load()
				{
					//Todo: maintenance: delete orphan bidx and blob files.
					const t0 = now; scope(exit) print(now-t0); 
					
					aaIdx.clear; 
					const mask = DataLoggerUtils.extractWildMask(idxFile); 
					
					static struct KF { align(1): K key; size_t offset, size; } 
					
					K[] keys; FileBlockRef[] values; 
					
					foreach(fIdx; idxFile.path.files(mask).sort)
					{
						const 	fData = fIdx.otherExt(".blob"),
							fDataSize = fData.size; 
						
						size_t loadSize = fIdx.size; 
						if(loadSize%KF.sizeof)
						{
							loadSize = loadSize/KF.sizeof*KF.sizeof; 
							WARN("DataLogger.idxFile truncated:", fIdx); 
						}
						
						//load the index file
						auto buf = cast(KF[]) fIdx.read(true, 0, loadSize); 
						
						//split into key/values and accumulate
						keys ~= buf.map!(a => a.key).array; 
						values ~= buf.map!(a => FileBlockRef(fData, a.offset, a.size)).array; 
					}
					
					//create the full AA in a single pass.
					aaIdx = assocArray(	keys, values); 
				} 
			} 
		} 
		
		enum OrderedKeys = true; 
		alias MainAA = DataLoggerAA,
		BlobAA = DataLoggerBlobAA; 
		
		mixin DatasetTemplate!(K, R); 
		
		const
		{
			Path _path; 
			string _namePrefix; 
			DateTime _logTime; 
			string _timestamp; 
		} 
		
		void _initialize()
		{
			string encodeFn(string timestamp, string field, string ext)
			{
				return only(
					_namePrefix,
					timestamp,
					field,
					ext.withoutStarting('.')
				).filter!(a=>a!="").join("."); 
			} 
			
			File encodeFile(string field, string ext)
			{ return _path ? File(_path, encodeFn(_timestamp, field, ext)) : File.init; } 
			
			//assign filenames
			_aa.logFile = encodeFile("", ".main"); ; 
			static foreach(name; _blobNames)
			{
				mixin("_blobAA_"~name).idxFile = encodeFile(name, ".bidx"); 
				mixin("_blobAA_"~name).dataFile = encodeFile(name, ".blob"); 
			}
		} 
		
		void _load()
		{
			_aa.load; 
			static foreach(name; _blobNames) mixin("_blobAA_"~name).load; 
		} 
		
		this(Path path, string namePrefix)
		{
			_path = path; 
			_namePrefix = namePrefix; 
			_logTime = now; 
			_timestamp = DataLoggerUtils.encodeTimestamp(_logTime); 
			
			enforce(!_namePrefix.canFind('.'), "Invalid namePrefix. Must not contain '.'!"); 
			enforce(!_path || _path.exists, "Path must be either NULL or an existing path. "~_path.text); 
			
			_initialize; 
			_load; 
			/+
				Note: It's no problem when _timestamp is the same as the latest file piexes,
				because it is OK to appent to them as well.
				It could be solved using an incremental index.
			+/
			//Todo: There should be an incremental index next to the timestamp as well!
		} 
	} 
	version(/+$DIDE_REGION DataLogger tests+/all)
	{
		void dataLoggerTest()
		{
			struct Data
			{
				align(1)	 {
					char[4] type; 
					RGBA avgColor; 
					ivec2 size; 
				} 
				struct Blobs	 { const(void)[] lod0, lod3, lod6; } 
			} 
			
			auto logger = new DataLogger!(DateTime, Data)(Path(`c:\!!!!!test`), `DataLog`); 
			
			with(logger[now] = Data("C1", clRed.rgb1, ivec2(1280, 720)))
			{
				print(*_record); 
				lod0 = "-= LOD0 TEST DATA =-"; 
				lod3 = "-= LOD33333333333333333333 TEST DATA =-"; 
				print(lod0); 
				print(lod3); 
			}
		} 
		
		void oldDelphiTest_recreated()
		{
			struct SelfTest
			{ int value; } 
			
			class SelfTests { mixin DatasetTemplate!(string, SelfTest); } 
			
			auto selfTests = new SelfTests; 
			
			selfTests["Denes"] = 5; 
			selfTests["Bea"] = 3; 
			selfTests["Aladar"] = 2; 
			selfTests["Zoltan"] = 1; 
			selfTests["Emese"] = 3; 
			
			const res = selfTests[]	.filter!"a.value>1"
				.array.sort!((a, b) => cmp(b.value, a.value).cmpChain(cmp(a.key, b.key))<0)
				.array.multiSort!("a.value>b.value", "a.key<b.key")
				.array.mySort!("-value key")
				.map!"a.key ~ a.value.text"
				.join; 
			
			print(res); 
			print(res==`Denes5Bea3Emese3Aladar2`); 
		} 
		
		void personSortTest()
		{
			//ChatGPT: How to sort a range by multiple fields in DLang?
			
			struct Person
			{
				string name; 
				int age; 
			} 
			
			//Create an array of Person objects
			Person[] people = [
				{ "Alice", 25},
				{ "Bob", 30},
				{ "Charlie", 20},
				{ "Alice", 30},
				{ "Bob", 25}
			]; 
			
			//Sort the array by name and age
			people.mySort!"name age"; 
			
			//Print the sorted array
			people	.map!`a.name ~ ", " ~ a.age.text`
				.each!writeln; 
		} 
		
			struct SimulatedSample { DateTime when; File file; } 
			auto simulatedSampleStream(DateTime base, Time interval, Time delay1, Time delay2, Time howLong)
		{
			struct ScheduledFile { File file; } 
			class ScheduledFiles { enum OrderedKeys = true; mixin DatasetTemplate!(DateTime, ScheduledFile); } 
			auto scheduledFiles = new ScheduledFiles; 
			
			const srcFiles = [
				Path(`c:\D\projects\Karc\Log\230406T11`).files(`*C1.webp`),
				Path(`c:\D\projects\Karc\Log\221201T11`).files(`*C2.webp`),
				Path(`c:\D\projects\Karc\Log\221201T11`).files(`*C3.webp`)
			]; 
			
			foreach(i; 0..((howLong)/(interval)).get.iround)
			{
				void add(DateTime t, File f)
				{ scheduledFiles[t] = f; } 
				
				add(base + i*interval, srcFiles[0][i * 101 % $]); 
				add(base + i*interval + delay1, srcFiles[1][i * 107 % $]); 
				add(base + i*interval + delay2, srcFiles[2][i * 127 % $]); 
			}
			
			return scheduledFiles[].map!(a => SimulatedSample(a.key, a.file)).array; 
		} 
			auto simulatedSampleStream(DateTime base, Time howLong)
		{
			return simulatedSampleStream(
				base, 
				4.18243 * second,	//interval between workpieces
				7.03154 * second,	//Delay from C1 to C2
				7.53234 * second, 	//Delay from C1 to C3
				howLong	//Total duration of this test
			); 
		} 
			void karcDataLoggerTest()
		{
			
			struct KarcSample
			{
				align(1)	 {
					char[4] type; 
					ivec2 size; 
					RGBA avgColor; 
				} 
				struct Blobs { const(void)[] lod0, lod3, lod6; } 
			} 
			
			auto karcSamples = new DataLogger!(DateTime, KarcSample)(Path(`c:\!!!!!test`), `KarcSamples`); 
			
			foreach(i, a; simulatedSampleStream(now, 1*hour).enumerate)
			{
				print(i.format!"%6d", a.when, a.file); 
				
				import het.bitmap; 
				Bitmap bmp; 
				void loadBmp() { if(!bmp) bmp = newBitmap(a.file, ErrorHandling.raise); } 
				
				if(a.when !in karcSamples)
				{
					print("  Creating main record..."); 
					loadBmp; 
					auto type = "C"~a.file.nameWithoutExt[$-1]; 
					karcSamples[a.when] = KarcSample(type.fourC, bmp.size, RGBA(255, 0, 255, 255)); 
				}
				
				with(karcSamples[a.when])
				{
					if(!lod0)
					{
						print("Importing lod0..."); 
						lod0 = a.file.read(true); 
					}
				}
			}
			
			karcSamples[].map!"a.lod0._size>0".sum.print; 
		} 
			void allDataLoggerTests()
		{
			testDataset; 
			testDatasetPropertyAccess; 
			dataLoggerTest; 
			oldDelphiTest_recreated; 
			karcDataLoggerTest; 
		} 
	}
}version(/+$DIDE_REGION TimeView+/all)
{
	version(/+$DIDE_REGION+/all)
	{
		enum TimeUnit : ubyte
		{ year, month, day, hour, minute} 
		
		struct TimeUnitInfo
		{
			TimeUnit unit; 
			string name, symbol; 
			Time avgDuration; 
		} 
		
		auto info(TimeUnit unit)
		{
			static immutable TimeUnitInfo[] arr = 
			[
				{ TimeUnit.year	, "year"	, "Y"	, gregorianDaysInYear*day	},
				{ TimeUnit.month	, "month"	, "M"	, gregorianDaysInMonth*day	},
				{ TimeUnit.day	, "day"	, "D"	, day	},
				{ TimeUnit.hour	, "hour"	, "h"	, hour	},
				{ TimeUnit.minute	, "minute"	, "m"	, minute	},
			]; 
			return arr[unit]; 
		} 
		
		TimeUnit timeUnitFromStr(string s)
		{
			foreach(u; EnumMembers!TimeUnit)
			if(s.among(u.info.name, u.info.symbol))
			return u; 
			throw new Exception("Unknown TimeUnit: "~s.quoted); 
		} 
		
		struct TimeStep
		{
			ushort count; 
			TimeUnit unit; 
			bool isVert; 
			
			int maxSubSteps; //calculated from this and next level. This is also the scaing of 'size' between levels.
			int levelIdx; 
			ivec2 size; //calculated pixel area
			
			
			bool isHorz() const
			{ return !isVert; } 
			bool isSummary() const
			{ return !!maxSubSteps; } 
			vec2 dir() const
			{ return isVert ? vec2(0, 1) : vec2(1, 0); } 
			Time avgDuration() const
			{ return count * unit.info.avgDuration; } 
			
			string calcTimeRangeText(DateTime[2] tr) const
			{
				//Note: This only calculates the lowest unit, and the beginning of the time frame.
				const s0 = tr[0].LocalDateTime.systemTime; 
				
				final switch(unit)
				{
					case TimeUnit.year: 	switch(count)	{
						case 1: 	return format!"%04d"(s0.wYear); 
						case 10: 	return format!"%04d'"(s0.wYear); 
						case 100: 	return format!"%04d''"(s0.wYear); 
						default: 	return format!"%04d.."(s0.wYear); 
					}
					case TimeUnit.month: 	switch(count)	{
						case 1: 	return format!"%04d.%02d"(s0.wYear, s0.wMonth); 
						case 3: 	return format!"%04dQ%d"(s0.wYear, (s0.wMonth-1)/3+1); 
						case 6: 	return format!"%04dH%d"(s0.wYear, (s0.wMonth-1)/6+1); 
						default: 	return format!"%04d.%02d.."(s0.wYear, s0.wMonth); 
					}
					case TimeUnit.day: 	switch(count)	{
						case 1: 	return format!"%2d"(s0.wDay); 
						default: 	return format!"%02d.."(s0.wDay); 
					}
					case TimeUnit.hour: 	switch(count)	{
						case 1: 	return format!"%2d:"(s0.wHour); 
						default: 	return format!"%02d:.."(s0.wDay); 
					}
					case TimeUnit.minute: 	switch(count)	{
						case 1: 	return format!"%2d:%2d'"(s0.wHour, s0.wMinute); 
						default: 	return format!"%2d:%2d'.."(s0.wHour, s0.wMinute); 
					}
				}
			} 
			
		} 
		
		private auto decodeTimeStepConfig(string config)
		{
			TimeStep[] res; 
			
			bool isVert, hasCnt; 
			int cnt; 
			foreach(ch; config)
			{
				switch(ch)
				{
					case ' ': 	continue; 
					case '|': 	isVert = true; continue; 
					case '-': 	isVert = false; continue; 
					case '0': .. case '9': 	hasCnt = true; cnt = cnt*10 + (ch-'0'); continue; 
					
					default: 
					
					res ~= TimeStep((hasCnt ? cnt : 1).to!ushort, timeUnitFromStr(ch.text), isVert); 
					
					//reset temporary state
					hasCnt = false; cnt = 0; 
				}
			}
			return res; 
		} 
		
		int timeStepDivide(in TimeStep a, in TimeStep b)
		{
			int ac = a.count, bc = b.count, sc = 1; 
			if(a.unit != b.unit)
			with(TimeUnit)
			{
				//must return the maximums. Example: for months it's 31.
				if(a.unit == year && b.unit == month) sc = 12; 
				else if(a.unit == month && b.unit == day) sc = 31 /+31 for unaligned and 37 for aligned weekdays+/; 
				else if(a.unit == day && b.unit == hour) sc = 24; 
				else if(a.unit == hour && b.unit == minute) sc = 60; 
				else if(a.unit == year && b.unit == day) sc = 366; 
				else throw new Exception("Unhandled TimeStep division: "~a.text~" "~b.text); 
			}
			
			ac *= sc; //scale a to the unit of b
			
			const res = ac / bc; 
			enforce(res * bc == ac, "Invalid TimeStep ratio (must be evenly divisible): "~a.text~" "~b.text); 
			
			return res; 
		} 
		
		private void calcTimeLevelSizes(TimeStep[] levels, ivec2 baseSize)
		{
			if(levels.empty) return; 
			levels.back.size = baseSize; 
			levels.back.maxSubSteps = 0; //this is the last level, no more subdivisions from here.
			foreach_reverse(lo; 1..levels.length)
			{
				const hi = lo-1; 
				const scale = timeStepDivide(levels[hi], levels[lo]); 
				
				levels[hi].maxSubSteps = scale; 
				
				auto s = levels[lo].size; 
				(levels[lo].isVert ? s.y : s.x) *= scale; 
				levels[hi].size = s; 
			}
		} 
		
		
	}
	class TimeView(Payload)
	{
		class TimeBlock
		{
			Payload payload; 
			
			const TimeStep* level; 
			DateTime[2] timeRange; //Todo: These data could be produced by a visitor, but I don't care ATM.
			ibounds2 rect; //this is a difficult recursive calculation, it must be stored.
			
			TimeBlock[] subBlocks; 
			
			auto timeRangeText()
			{ return level.calcTimeRangeText(timeRange); } 
			
			DateTime[2] timeRange_add_raw(ulong delta) const
			{
				if(!delta) return timeRange; 
				return [
					timeRange[0].add_raw(delta),
					timeRange[1].add_raw(delta)
				]; 
			} 
			
			int levelIdx() const
			{ return level.levelIdx; } 
			
			bool isSummary() const
			{ return level.isSummary; } bool isDetail() const
			{ return !isSummary; } 
			
			int opCmp(in TimeBlock b) const
			{ return timeRange[0].opCmp(b.timeRange[0]); } 
			bool opEquals(in TimeBlock b) const
			{ return timeRange[0]==b.timeRange[0]; } 
			
			auto duration() const
			{ return timeRange[1] - timeRange[0]; } 
			
			auto rawDuration() const
			{ return timeRange[1].raw - timeRange[0].raw; } 
			
			this(in ref TimeStep level, in DateTime[2] timeRange, in ibounds2 rect)
			{
				this.level = &level; 
				this.timeRange = timeRange; 
				this.rect =rect; 
				
				{
					const len = level.maxSubSteps; 
					enforce(len.inRange(0, 10000), "subBlocks.length: Out of range"); 
					subBlocks.length = len; 
				}
				
				//print("TimeBlock created:", levelIdx, idx, blk.timeRange, blk.rect);
			} 
		} 
		
		TimeStep[] levels; 	/+Note: From largest to lowest time step level.+/
		DateTime timeOrigin; 	/+
			Note: The current largest level is aligned to the geometric origin.  Everything else is relative to that.
			⚠Do not share geometric coordinates between different timeViews.  Only share DateTimes.
		+/
		TimeBlock[DateTime] root; 	/+Note: Largest level is a map, all remaining sublevels are arrays.+/
		
		this(string config, ivec2 cellSize)
		{
			//example config string: "|100Y|10Y|Y-3M-M|D-h|2m"
			
			levels = decodeTimeStepConfig(config); enforce(levels.length); 
			foreach(i, ref level; levels) level.levelIdx = i.to!int; 
			calcTimeLevelSizes(levels, cellSize); 
			timeOrigin = calcTimeBounds(now, 0)[0]; 
			
			dump; 
		} 
		
		DateTime[2] calcTimeBounds(in DateTime t, size_t levelIdx = size_t.max)
		{
			if(!t) return (DateTime[2]).init; 
			
			enforce(levels.length); 
			levelIdx.minimize(levels.length-1); 
			
			const 	level = &levels[levelIdx],
				isSimple = 	(level.unit > TimeUnit.day /+Note: '>' because timeUnits are in descending order.+/) ||
					(level.unit == TimeUnit.day && level.count==1); 
			if(isSimple)
			{
				const 	rawUnits = level.unit.predSwitch(
					TimeUnit.minute	, DateTime.RawUnit.min,
					TimeUnit.hour	, DateTime.RawUnit.hour,
					TimeUnit.day	, DateTime.RawUnit.day
				),
					m = rawUnits * level.count,
					t0 = t.raw - t.raw % m,
					t1 = t0 + m; 
				return [RawDateTime(t0), RawDateTime(t1)]; 
			}
			else
			{
				const st = t.utcSystemTime; 
				if(level.unit==TimeUnit.year) {
					const y = st.wYear,
						y0 = y - y%level.count,
						y1 = y0 + level.count; 
					return [
						DateTime(UTC, y0, 1, 1), 
						DateTime(UTC, y1, 1, 1)
					]; 
				}
				if(level.unit==TimeUnit.month) {
					const 	ym = (st.wYear)*12 + (st.wMonth-1),
						ym0 = ym - ym%level.count,
						ym1 = ym0 + level.count; 
					return [
						DateTime(UTC, ym0/12, ym0%12+1, 1), 
						DateTime(UTC, ym1/12, ym1%12+1, 1)
					]; 
				}
			}
			
			//Todo: Must handle situations when the lower bound is equal to or below 1600.01.01. That's a NULL datetime.
			
			throw new Exception("calcTimeBounds fail"); 
		} 
		
		alias peek = access!false; 
		bool access(bool autoCreate=true)(DateTime t, bool delegate(TimeBlock) fun)
		{
			TimeBlock prevBlock; 
			auto prevT0 = timeOrigin; 
			auto prevTopLeft = ivec2(0); 
			
			foreach(levelIdx, const ref level; levels)
			{
				auto actTimeRange = calcTimeBounds(t, levelIdx); 
				const idx = ((actTimeRange[0] - prevT0) / level.avgDuration).get.round.to!int; //Opt: Div -> invMul
				
				TimeBlock blk; 
				void createNewBlk()
				{
					const ofs = prevTopLeft + (
						level.isVert 	? ivec2(0, idx*level.size.y)
							: ivec2(idx*level.size.x, 0)
					); 
					blk = new TimeBlock(
						level, actTimeRange, 
						ibounds2(ivec2(0), level.size) + ofs
					); 
				} 
				
				if(levelIdx==0)
				{
					//Note: Get the block from the root level hashTable
					
					const key = actTimeRange[0]; 
					
					auto a = key in root; 
					if(!a)
					{
						if(autoCreate)
						{
							createNewBlk; 
							root[key] = blk; 
							a = key in root; 
						}
						else
						return false; 
					}
					else
					blk = *a; 
				}else {
					//Note: Get a subBlock from the previous TimeBlock
					//always do rangeChecking. I don't trust in this.
					enforce(
						idx.inRange(prevBlock.subBlocks), 
						"Unable to fit subBlock into TimeBlock."
					); 
					
					auto a = &prevBlock.subBlocks[idx]; 
					if(*a is null)
					{
						if(autoCreate)
						{
							createNewBlk; 
							*a = blk; 
						}
						else
						return false; 
					}
					else
					blk = *a; 
				}
				
				//got the TimeBlock, call the delegate
				assert(blk); 
				if(!fun(blk)) return true; 
				//returns true, because it exists, just breaking as it was request of the fun()
				
				//advance
				prevBlock = blk; 
				prevT0 = prevBlock.timeRange[0]; 
				prevTopLeft = prevBlock.rect.topLeft; 
			}
			
			return true; //success
		} 
		
		ibounds2 calcBounds()
		{
			auto a = root.values.sort; 
			if(a.empty) return ibounds2.init; 
			
			return ibounds2(a.front.rect.topLeft, a.back.rect.bottomRight); 
		} 
		
		void visit(ibounds2 clipBounds, bool delegate(TimeBlock) fun1, void delegate(TimeBlock) fun2)
		{
			void visitBlocks(R)(R blocks)
			{
				foreach(blk; blocks)
				{
					if(blk && clipBounds.overlaps(blk.rect))
					{
						if(fun1(blk))
						{
							visitBlocks(blk.subBlocks); 
							fun2(blk); 
						}
					}
				}
			} 
			visitBlocks(root.values.sort); 
			
			/+Opt: Detect horz/vert direction and do binary filtering on clipBounds+/
		} 
		
		void dump()
		{
			const t = now; 
			print(
				format!"\nListing %s TimeStep levels.  Now = %s\n"(levels.length, t) ~
				levels	.enumerate
					.map!(
					a => format!"  \33\10#\33\7%d  \33\16%s%3s%s\33\7 %5s * %-5s  ->%-3s  %s .. %s"
					(
						a.index,
						a.value.isVert ? "\u2193" : "\u2192",
						a.value.count,
						a.value.unit.info.symbol,
						a.value.size.x.shortSizeText!1000,
						a.value.size.y.shortSizeText!1000,
						a.value.maxSubSteps,
						calcTimeBounds(t, a.index)[0],
						calcTimeBounds(t, a.index)[1] - milli(second)
					)
				)
					.join('\n')
			); 
		} 
		
		
	} 
}version(all)
{
	void unittest_splitSentences() {
		uint h; 
		void a(string s) {
			auto r = AMDBCore.textToSentences(s).text; h = r.xxh32(h); 
			//print(s, "|", r);
		} 
		
		a("One part"); 
		a("Part one  Part two"); 
		a("Part 1  Part 2     Part 3"); 
		a("Part 1  Part 2  Part 3  Part 4"); 
		
		a("One part...2nd sentence."); 
		a("Part one  Part two...2nd"); 
		a("Part 1  Part 2     Part 3  ...  2nd"); 
		
		a("Part one  Part two\n...2nd"); 
		
		a("Part one  Part two\nNew     sentence  ...next"); 
		
		a(`a"c"d"e  e"..."f  f\""""g`);   //c style "" string literals are decoded as a word.
		
		//print(h);
		enforce(h==1522071754, "AMDB.textToSentences test FAIL"); 
	} 
	void unittest_main() { unittest_splitSentences; } 
}