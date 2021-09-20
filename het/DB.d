module het.db;

import het.utils, het.stream;

/////////////////////////////////////////////////////////////////////
/// Archiver                                                      ///
/////////////////////////////////////////////////////////////////////

/// This encapsulates custom data objects in a stream. Any type of bytestream will do, no packaging is needed.
/// The data can be identified and easily skipped from both directions. Contains crc.

class Archiver{

  enum DefaultMasterRecordMaxSize = 0x200; //DON'T CHANGE!
  enum InitialFilePoolSize = 0x100;

  enum LeadInSize = 5*4;
  enum LeadOutSize = 5*4;
  enum MaxLeadSize = max(LeadInSize, LeadOutSize);
  enum PlainFrameSize = LeadInSize + LeadOutSize;

  static struct JumpRecord{
    enum Marking = "$JMP";
    ulong from, to, over;
  }
  static assert(JumpRecord.sizeof==24);

  size_t calcJumpRecordSizeBytes()const{
    return PlainFrameSize +JumpRecord.Marking.length.alignUp(4) +JumpRecord.sizeof.alignUp(4)
           +(compr=="" ? 0 : 4);
  }

  static struct MasterRecord{ // MasterRecord ///////////////////////////////////
    enum Marking = "$MR";

    //all offsets and sizes in bytes
    @STORED{
      string volume, originalFileName;
      ulong masterRecordBegin,
            masterRecordEnd,
            filePoolBegin,
            filePoolEnd,
            blobPoolBegin,
            totalFileCount,
            totalFileSize,
            totalBlobCount,
            totalBlobSize;
      DateTime created, modified;

      //todo: archiveEnd: after this ofs, growth is not possible  0=endless
    }

    void checkConsistency(){
      auto a = [masterRecordBegin, masterRecordEnd, filePoolBegin, filePoolEnd, blobPoolBegin];
      enforce(a.map!q{(a&3)==0}.all, "FATAL MRCC Fail: unaligned");
      enforce(a.equal(a.sort)      , "FATAL MRCC Fail: unordered");
    }

    private bool valid; //this is set by outside conditions
    T opCast(T:bool)() const{ return valid; }

    ulong actualMasterRecordMaxSize() const{
      enforce(masterRecordEnd>=masterRecordBegin, "Invalid MR size");
      return masterRecordEnd-masterRecordBegin;
    }

    void initializeNew(File file, string volume, ulong baseOffset, ulong filePoolInitialSize){
      this = MasterRecord.init;
      this.volume = volume;
      originalFileName  = file.fullName;
      masterRecordBegin = baseOffset;
      masterRecordEnd   = masterRecordBegin +  DefaultMasterRecordMaxSize;
      filePoolBegin     = masterRecordEnd;
      filePoolEnd       = filePoolBegin     +  filePoolInitialSize;
      blobPoolBegin     = filePoolEnd;
      created = modified = now;
    }

  }

  // finds a datablock that possibly contains data. It helps in reconstucting archived blocks.
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


  // Archiver main /////////////////////////////////////////////////////////////////////

  private SeedStream seedStream;

  this(){
    seedStream = SeedStream_pascal(56432);

    __gshared static bool selfTestDone;
    if(chkSet(selfTestDone)) selfTest;
  }

  void initSeedStream(uint a, uint c){ seedStream = SeedStream(a, c); }
  void testSeedStream(){ seedStream.test; }

  private MasterRecord masterRecord;
  /*private*/ File file;
  private string compr;

  void close(){
    file = File.init;
    masterRecord = masterRecord.init;
    compr = "";
  }

  bool valid() const{ return masterRecord.valid && file.exists; }
  T opCast(T:bool)() const{ return valid; }

  private void write_internal(in void[] rec, ulong ofs){
    masterRecord.checkConsistency;
    file.write(rec, ofs, masterRecord.masterRecordBegin>0 ? Yes.preserveTimes : No.preserveTimes); //note: don't change datetime when this archive is attached to the end of another file.
  }

  private void padRight(ref uint[] data, ulong maxSizeBytes){
    enforce((maxSizeBytes&3)==0, "align4 error");
    while(data.sizeBytes < maxSizeBytes) data ~= seedStream.fetchFront;
  }

  private ulong actualFrameSize(ulong headerSizeBytes, ulong dataSizeBytes) const{
    return PlainFrameSize + (compr!="" ? 4 : 0) + headerSizeBytes.alignUp(4) + dataSizeBytes.alignUp(4);
  }

  private void writeMasterRecord(){
    auto rec = createRecord(MasterRecord.Marking, masterRecord.toJson.compress, now.timestamp, compr);
    padRight(rec, masterRecord.actualMasterRecordMaxSize);

    enforce(rec.sizeBytes <= masterRecord.actualMasterRecordMaxSize, "Archive MR overflow. %d <= %d".format(rec.sizeBytes, masterRecord.actualMasterRecordMaxSize));
    write_internal(rec, masterRecord.masterRecordBegin);
  }

  private void readMasterRecord(in ulong ofs){
    masterRecord = MasterRecord.init;
    const data = cast(uint[])file.read(true, ofs, DefaultMasterRecordMaxSize),
          res = decodeRecord(data, compr);
    enforce(res.error=="", "Error decoding MR: "~res.error);
    masterRecord.fromJson(res.data.uncompress.to!string);
    enforce(masterRecord.masterRecordBegin==ofs, "MR offset mismatch. %d != %d".format(masterRecord.masterRecordBegin, ofs));

    masterRecord.checkConsistency;

    masterRecord.valid = true;
  }

  private auto writeRecord(string fn, in void[] data){ with(masterRecord){
    const rec = createRecord(fn, data.compress, now.timestamp, compr),
          recSize = rec.sizeBytes,
          requiredSize = recSize + calcJumpRecordSizeBytes;

    enforce((recSize & 3 | requiredSize & 3) == 0, "FATAL: Alignment error"); //must be dword aligned

    bool fitsInFilePool() const{ return masterRecord.filePoolBegin + requiredSize <= masterRecord.filePoolEnd; }

    if(!fitsInFilePool){
      //must extend filePool (1.5x exponential growth)
      void extendFilePoolEnd(){ filePoolEnd += max((totalFileSize/2)&~3UL, requiredSize); }

      if(filePoolEnd==blobPoolBegin){
        //there are no blobs at the end, it can extend as far as it's needed
        extendFilePoolEnd;
        blobPoolBegin = filePoolEnd;
      }else{
        //there are blobs in the way, must make a jump.
        auto jumpRec = createRecord(JumpRecord.Marking, [JumpRecord(filePoolBegin, blobPoolBegin, filePoolEnd)], now.timestamp, compr);

        //todo: calculate jumpRecSize properly
        enforce(calcJumpRecordSizeBytes == jumpRec.sizeBytes, "FATAL: jumpRecordSize mismatch  expected:%d  actual:%d".format(calcJumpRecordSizeBytes, jumpRec.sizeBytes));

        padRight(jumpRec, filePoolEnd-filePoolBegin);
        enforce(jumpRec.sizeBytes == filePoolEnd-filePoolBegin, "FATAL: jumpRecord padding fail");

        write_internal(jumpRec, filePoolBegin);
        filePoolBegin += jumpRec.sizeBytes;

        //allocate new filePool after the blobs
        filePoolBegin = blobPoolBegin;
        filePoolEnd = filePoolBegin;
        extendFilePoolEnd;
        blobPoolBegin = filePoolEnd;
      }
    }
    enforce(fitsInFilePool, "Fatal error: doesn't fitsInFilePool");

    //write the file and adjust the pool
    auto res = Bounds!ulong(filePoolBegin, filePoolBegin+recSize);
    write_internal(rec, filePoolBegin);

    filePoolBegin += recSize;
    totalFileSize += recSize;
    totalFileCount ++;

    writeMasterRecord; //always write it for safety

    return res;
  }}

  private auto writeBlobRecord(string fn, in void[] data){ with(masterRecord){
    const rec = createRecord(fn, data, now.timestamp, compr),
          recSize = rec.sizeBytes;

    auto res = Bounds!ulong(blobPoolBegin, blobPoolBegin+recSize);
    write_internal(rec, blobPoolBegin);

    //write the file and adjust the pool
    blobPoolBegin += recSize;
    totalBlobSize += recSize;
    totalBlobCount ++;

    writeMasterRecord; //always write it for safety

    return res;
  }}

  private auto findMasterRecordOfs(){
    auto ofs = findNonRedundantBlock(file, DefaultMasterRecordMaxSize, 0, 0.125, Yes.exponentialSearch); //don't change this!!!
    if(ofs<0) raise("Unable to locate suitable MR offset.");
    return ofs;
  }

  void create(T)(T file_, string volume, string compr="", ulong baseOfs=0){
    enforce(!valid, "Archive already opened.");

    close;
    try{
      file = File(file_);
      this.compr = compr;

      if(file.exists){
        beep;
        const code = [now].xxh3.to!string(36).take(3).to!string;
        writef("Archive.create: %s starting from offset:%s will be overwritten. Are you sure? (type %s if yes) ", file, baseOfs, code);
        if(readln.strip.uc==code){
          writeln(" Overwrite enabled. ");
        }else{
          raise("Archive.create: user approval error.");
        }
      }else{
        file.write([0]);
      }

      masterRecord.initializeNew(file, volume, baseOfs, InitialFilePoolSize+calcJumpRecordSizeBytes);
      writeMasterRecord;

      masterRecord.valid = true; //from now it's valid and opened
    }catch(Exception e){
      close;
      throw e;
    }
  }

  void open(T)(T file_, string compr="", ulong baseOfs=0){
    enforce(!valid, "Archive already opened.");

    close;
    try{
      file = File(file_);
      this.compr = compr;
      enforce(file.exists, "Archive file not found: "~file.text);

      readMasterRecord(baseOfs); //if it succeeds, it will set valid to true
    }catch(Exception e){
      close;
      throw e;
    }
  }

  auto addRecord(string name, in void[] data){
    enforce(valid, "No archive is opened.");
    return writeRecord(name, data);
  }

  auto addBlob(string name, in void[] data){
    enforce(valid, "No archive is opened.");
    return writeBlobRecord(name, data);
  }

  auto addBlob(File f){
    return addBlob(f.fullName, f.read(true));
  }

  // record reading //////////////////////////////////////////////////////////////////////////////

  struct ReadRecordResult{
    string name;
    ubyte[] data;
  }

  auto readRecords(string pattern){
    enforce(valid, "No archive is opened.");
    ReadRecordResult[] res;

    ulong ofs = masterRecord.masterRecordEnd;
    foreach(idx; 0..masterRecord.totalFileCount){
      auto r = decodeRecordFromFile(ofs); //opt: this reads even those records that don't needed...
      LOG("Record found:", r.header);

      if(r.error.length){
        //todo: more consistency checking needed
        LOG("End of records: ", r.error);
        break;
      }

      if(r.header==JumpRecord.Marking){
        enforce(r.data.length == JumpRecord.sizeof);
        auto jr = (cast(JumpRecord[])r.data)[0];
        LOG("Got jump record", jr);
        ofs = jr.to;
        continue;
      }

      if(r.header.isWildMulti(pattern)) res ~= ReadRecordResult(r.header, cast(ubyte[])(r.data.uncompress));
      ofs += r.recordSizeBytes; //todo: endless loop protection
    }

    return res;
  }

  // record handling //////////////////////////////////////////////////////////////////////////////
  private {

    uint[] createRecord(string header, in void[] data, string headerCompression, string dataCompression){

      void applyHeaderCompression(string op)(string headerCompression/+empty for debug only+/, bool compressAllData, uint[] uLeadIn, uint[] uHeader, uint[] uData, uint[] uLeadOut){
        if(headerCompression=="") return;

        seedStream.seed = headerCompression.xxh3_32;
        auto ss = refRange(&seedStream);
        void apply(uint[] a){ mixin(q{ a[] #= ss.take(a.length).array[]; }.replace("#", op)); }

        apply(uLeadIn);
        apply(uHeader);
        if(compressAllData){
          apply(uData);
        }else{
          if(uData.length) apply(uData[$-1..$]); // there is normal compression, just do possible padded zeros in last byte
        }
        apply(uLeadOut);
      }

      void[] cdata;
      if(dataCompression!=""){
        auto compr = norx!(64, 4, 1).encrypt(dataCompression, [headerCompression.xxh3_32], data);
        cdata = compr.data ~ compr.tag[0..4];
      }else{
        cdata = data.dup; //because it will work inplace
      }

      uint[] uLeadIn  = [0u, 1, 2, header.length.to!uint, cdata.length.to!uint];
      uint[] uHeader  = header.dup.toUints;
      uint[] uData    = cdata.toUints;
      uint[] uLeadOut = [0u, 1, -1, (uLeadIn.length + uHeader.length + uData.length /+size of the leadin and data except the end marker+/).to!uint];

      //print(uLeadIn); print(uHeader); print(uData); print(uLeadOut);

      applyHeaderCompression!"+"(headerCompression, dataCompression.empty, uLeadIn, uHeader, uData, uLeadOut);

      auto res = uLeadIn ~ uHeader ~ uData ~ uLeadOut;
      res ~= res.xxh3_32; //add final error checking

      return res;
    }

    auto decodeRecord(in uint[] data_, string dataCompression){
      auto data = data_.dup; //because it will work on it

      struct Record{
        string error;
        string warning;

        string header;
        ubyte[] data;
        ulong recordSizeBytes;
      }
      Record res;

      try{
        uint[] tryFetch(uint n){
          uint len = min(n, data.length);
          auto res = data[0..len];
          data = data[len..$];
          return res;
        }

        uint[] fetchExactly(uint n){
          auto arr = tryFetch(n);
          enforce(arr.length == n, "Not enough input data");
          res.recordSizeBytes += n*4;
          return arr;
        }

        uint[] uLeadIn = fetchExactly(5);
        const seed = uLeadIn[0];

        seedStream.seed = uLeadIn[0];
        auto ss = refRange(&seedStream);
        void apply(uint[] a){ a[] -= ss.take(a.length).array[]; }

        apply(uLeadIn);
        enforce(uLeadIn[0..3].equal([0u, 1, 2]), "Invalid LeadIn sequence");

        const uint headerBytes = uLeadIn[3];
        uint[] uHeader = fetchExactly((headerBytes+3)/4);
        apply(uHeader);
        res.header = ((cast(char[])uHeader)[0..headerBytes]).to!string;

        const uint dataBytes = uLeadIn[4];
        uint[] uData = fetchExactly((dataBytes+3)/4);
        if(dataCompression=="") apply(uData);
                           else if(uData.length) apply(uData[$-1..$]);

        ubyte[] cData = (cast(ubyte[])uData)[0..dataBytes];
        if(dataCompression!=""){
          enforce(cData.length>=4, "Not enough cData "~cData.length.text);
          const expectedTag = cData[$-4..$];
          cData = cData[0..$-4];

          auto decompr = norx!(64, 4, 1).decrypt(dataCompression, [seed], cData);
          enforce(expectedTag.equal(decompr.tag[0..4]), "Tag check fail");
          res.data = decompr.data;
        }else{
          res.data = cData;
        }

        //verify leadOut
        try{
          uint[] uLeadOut = fetchExactly(4);
          apply(uLeadOut);
          //print("LEADOUT", uLeadOut);

          enforce(uLeadOut[0..3].equal([0u, 1, -1]), "bad leadOut sequence: "~uLeadOut[0..3].text);

          uint len = (uLeadIn.length + uHeader.length + uData.length).to!uint;
          enforce(uLeadOut[3]==len, format!"uSize mismatch: %d != %s"(uLeadOut[3], len));

          uint storedSheckSum = fetchExactly(1)[0];
          uint calcedSheckSum = data_[0..len+4/*leadOut*/].xxh3_32;
          enforce(storedSheckSum == calcedSheckSum, "crc error");
        }catch(Exception e){
          res.error = "LeadOut error: "~e.simpleMsg; return res;
        }
      }catch(Exception e){
        res.error = e.msg; return res;
      }

      return res;
    }

    auto peekRecord(in uint[] data){
      struct Res{
        bool isLeadIn, isLeadOut, needMoreData;
        ulong headerLength, dataLength, seekBack, fullSize;
        bool valid(){ return !needMoreData && (isLeadIn || isLeadOut); }
      }

      Res res;
      if(data.length>=3){
        seedStream.seed = data[0];
        seedStream.popFront;
        if(data[1] == seedStream.front+1){
          seedStream.popFront;
          auto a = data[2]-seedStream.front;
          if(a==2){
            seedStream.popFront;
            res.isLeadIn = true;
            if(data.length>=5){
              res.headerLength = data[3]-seedStream.front; seedStream.popFront;
              res.dataLength   = data[4]-seedStream.front;
              res.fullSize     = actualFrameSize(res.headerLength, res.dataLength);
            }else{
              res.needMoreData = true;
            }
          }else if(a==-1){
            seedStream.popFront;
            res.isLeadOut = true;
            if(data.length>=4){
              res.seekBack = data[3]-seedStream.front;
            }else{
              res.needMoreData = true;
            }
          }
        }
      }else{
        res.needMoreData = true;
      }

      return res;
    }

    auto decodeRecordFromFile(ulong ofs){
      re:
      auto data = cast(uint[])file.read(false, ofs, ofs+MaxLeadSize);
      auto peek = peekRecord(data);

      bool once;
      if(!once && peek.valid && peek.isLeadOut){
        once = true;
        ofs = ofs-peek.seekBack; //todo: test it properly
        goto re;
      }

      if(peek.valid && peek.isLeadIn)
        data = cast(uint[])file.read(true, ofs, ofs+peek.fullSize);

      return decodeRecord(data, compr);
    }

  } // end of record handling

  // tests /////////////////////////////////////////////////////////////////

  void selfTest(){
    RNG rng;
    //const t0=QPS;
    foreach(headerLen; [0, 1, 3, 4, 5, 7, 8, 9]){
      foreach(dataLen; [0, 1, 3, 4, 5, 7, 8, 9]){
        string header = iota(headerLen).map!(i => cast(char)(rng.random(96)+32)).to!string;
        ubyte[] data = iota(dataLen).map!(i => cast(ubyte)(rng.random(256))).array;
        foreach(dataCompr; ["", "deflate"]){
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

  static void longTest(){
    import het.db;

    LOG("Doing tests");

    RNG rng; rng.seed = 123456;
    with(rng){
      ubyte[] randomFile(){
        bool large = random(2)==1;
        ubyte randomByte(){ return cast(ubyte)(large ? random(256) : random(64)+32); }
        return iota((large ? 65536 : 512)+random(1024)).map!(i => randomByte).array;
      }
      static bool isSmall(in void[] a){ return a.sizeBytes<8192; }

      const allFiles = iota(100).map!(i => randomFile).array,
            smallFiles = allFiles.filter!isSmall.array,
            largeFiles = allFiles.filter!(not!isSmall).array;

      foreach(c; ["", "test"]){
        auto f = File(`c:\arctest.bin`);
        f.remove;

        auto arc = new Archiver;
        arc.create(f, "testvolume");

        auto db = new AMDB(new ArchiverDBFile(arc, "main.db"));

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
        foreach(data; allFiles){
          if(isSmall(data)){
            locations ~= arc.addRecord(data.xxh3.text, data);
          }else{
            locations ~= arc.addBlob(data.xxh3.text, data);
            auto loc = locations[$-1];

            string id = data.xxh3.to!string(36).padLeft('0', 13).to!string;
            auto bname = format!"BLOB_%s"(id);
            db.data(format!"%s  is a  Blob"(bname));
            db.data(format!"%s  file type  JPG"(bname));
            db.data(format!"%s  archive location  %d"(bname, loc.low));
            db.data(format!"%s  size in bytes  %d"(bname, data.sizeBytes));
            if(0) db.data(format!"%s  original file name  %s"(bname, ""));
            //db.data(format!"%s  has thumbnail  %s");
          }
        }

        foreach(i, loc; locations){
          //auto res = arc.decodeRecord(cast(uint[])f.read(true, loc.low, loc.high-loc.low), c);
          auto res = arc.decodeRecordFromFile(loc.low);
          enforce(res.error == "", "Error: "~res.error);

          //must not forget to uncompress small files
          if(isSmall(res.data)) res.data = cast(ubyte[])res.data.uncompress; //it's outdated!!!!!!

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


// ArchiverDBFile /////////////////////////////////////////////////////
class ArchiverDBFile : DBFileInterface{ //this is an AMDB inside an Archive
  string name;
  Archiver arc;

  this(Archiver arc, string name){
    this.arc = arc;
    this.name = name;
  }

  File file(){ return File(arc.file.fullName~`\`~name); } //just an information, not a usable file (yet)

  string[] readLines(){
    return arc.readRecords(name).map!(r => (cast(string)r.data).splitLines).join;
  }

  void appendLines(string[] lines){
    arc.addRecord(name, '\n'~lines.join('\n')~'\n');
  }
}


class AMDBException : Exception {
  this(string s){ super(s); }
}

interface DBFileInterface{
  File file();
  string[] readLines(); //reads the whole file
  void appendLines(string[] lines); //appends some lines
}

class TextDBFile : DBFileInterface{
  private File file_;

  this(File file){
    this.file_ = file;
  }

  File file(){ return file_; }

  string[] readLines(){ return file_.readLines; }

  void appendLines(string[] lines){ file_.append("\n"~lines.join("\n")~"\n"); }
}

class AMDB{
  enum versionStr = "1.00";

  private uint lastIdIndex;
  Items items;
  Links links;

  private DBFileInterface dbFileInterface;

  bool autoCreateETypes   = true ,
       autoCreateVerbs    = true ,
       autoCreateEntities = false;

  //----------------------------------------------------------------------------------

  this(){
    items.db = links.db = transaction.db = this;

    //do critical unittests
    __gshared static bool tested;
    if(tested.chkSet) unittest_splitSentences;
  }

  this(DBFileInterface dbFileInterface){
    this();

    this.dbFileInterface = dbFileInterface;

    load;
  }

  this(File file){ this(new TextDBFile(file)); }
  this(string fileName){ this(File(fileName)); }

  //clear all the internal data. Does not change the dbFile.
  private void clear(){
    lastIdIndex = 0;
    links.clear;
    items.clear;
  }

  File file(){ return dbFileInterface ? dbFileInterface.file : File(""); }

  void error(string s) const{ throw new AMDBException(s); }

  static string autoQuoted(string s){
    //todo: slow
    if(s.canFind!(ch => ch<32 || ch.among('"', '\'', '`', '\\')) || s.canFind("  ") || s.canFind("..."))return s.quoted;
    else return s;
  }

  static string autoUnquoted(string s){
    if(s.startsWith('"')){
      import het.tokenizer; //todo: agyuval verebre...
      Token[] t;
      string err = tokenize("", s, t);
      enforce(err=="" && t.length, "Error decoding quoted string: "~err);
      return t[0].data.to!string;
    }else return s;
  }

  // Id ////////////////////////////////////

  struct Id{
    uint id;

    bool valid() const { return id!=0; }
    bool opCast(B: bool)() const { return valid; }

    size_t toHash() const @safe pure nothrow{ return id; }
    bool opEquals(ref const Id b) const @safe pure nothrow{ return id==b.id; }

    string toString() const { return id.text; }

    long opCmp(in Id b) const{ return long(id)-long(b.id); }

    string serializeText() const{ return id.to!string(10); }
    void deserializeText(string s){ id = s.to!uint(10); }
  }

  private Id _internal_generateNextId(){ return Id(++lastIdIndex); }

  /// When an item is loaded
  private void _internal_maximizeNextId(in Id id){ lastIdIndex.maximize(id.id); }

  // Items /////////////////////////////

  struct Items{
    private AMDB db;
    private string[Id] byId;
    private Id[string] byItem;

    // data access -------------------------------------------

    auto ids(){ return byId.keys; }
    auto strings(){ return byItem.keys; }

    auto count() const{ return byId.length; }

    string get(in Id id                 ) const{ if(auto a = id in byId) return *a; else return "" ; }
    string get(in Id id, lazy string def) const{ if(auto a = id in byId) return *a; else return def; }

    string require(in Id id                 ) const{ if(auto a = id in byId) return *a; else{ db.error(format!"Required id %s not found."   (id     )); assert(0); } }
    string require(in Id id, lazy string msg) const{ if(auto a = id in byId) return *a; else{ db.error(format!"Required id %s not found. %s"(id, msg)); assert(0); } }

    Id get(string str             ) const{ if(auto a = str in byItem) return *a; else return Id.init; }
    Id get(string str, lazy Id def) const{ if(auto a = str in byItem) return *a; else return def    ; }

    Id require(string str                 ) const{ if(auto a = str in byItem) return *a; else{ db.error(format!"Required item %s not found."   (str.quoted     )); assert(0); } }
    Id require(string str, lazy string msg) const{ if(auto a = str in byItem) return *a; else{ db.error(format!"Required item %s not found. %s"(str.quoted, msg)); assert(0); } }

    auto opBinaryRight(string op)(in Id id) if(op=="in"){

      struct ItemResult{
        string str;
        bool valid;
        alias str this;
        bool opCast(B : bool)() const{ return valid; }
      }

      if(auto a = id in byId) return ItemResult(*a, true); else return ItemResult.init;
    }

    Id opBinaryRight(string op)(string str) if(op=="in"){ return get(str); }

    string opIndex(in Id id) const{ return require(id); }
    Id opIndex(string str) const{ return require(str); }

    // data manipulation -------------------------------------------------------

    //inserts into the lists, called by itemId_create and importItem
    private void _internal_createItem(in Id id, string name){
      byItem[name] = id;
      byId[id] = name;
    }

    private bool _internal_tryRemoveItem(in Id id){
      if(auto item = id in this){
        byId.remove(id);
        byItem.remove(item);
        return true;
      }
      return false;
    }

    private void clear(){ byId = null; byItem = null; }

    private Id create(string name, void delegate(Id) afterCreate = null){
      auto id = get(name);
      if(id) return id;

      id = db._internal_generateNextId;
      _internal_createItem(id, name);
      db.transaction._internal_onItemCreated(id);
      if(afterCreate) afterCreate(id);
      return id;
    }

    private void load(in Id id, string data){
      if(!id) db.error("Invalid null id");
      if(id in db.links) db.error(format!"Load error: Item id already exists as a link. id=%s old=%s new=%s"(id, db.toStr(id), data));
      if(auto existing = id in this){
        if(existing==data) return; //already loaded, id is the same
        db.error(format!"Load error: Id already exists with different item data. id=%s old=%s new=%s"(id, db.toStr(id), data));
      }
      //id is free, check duplicated data
      if(get(data)) format!"Load error: Item already exists with different id. new=%s"(data);

      //good to go, create it
      db._internal_maximizeNextId(id);
      _internal_createItem(id, data);
    }
  }

  // Links //////////////////////////////////////

  struct Link{
    Id sourceId, verbId, targetId;

    size_t toHash() const @safe pure nothrow{
      return sourceId.hashOf(verbId.hashOf(targetId.hashOf));
    }

    bool opEquals(ref const Link b) const @safe pure nothrow{
      return sourceId==b.sourceId
          && verbId  ==b.verbId
          && targetId==b.targetId;
    }

    bool valid() const { return sourceId.valid && verbId.valid; }
    bool opCast(B : bool)() const{ return valid; }
  }

  struct Links{
    private AMDB db;
    private Link[Id] byId;
    private Id[Link] byLink;

    // data access -------------------------------------------

    auto ids(){ return byId.keys; }
    auto links(){ return byLink.keys; }

    auto count() const{ return byId.length; }

    Link get(in Id id               ) const{ if(auto a = id in byId) return *a; else return Link.init; }
    Link get(in Id id, lazy Link def) const{ if(auto a = id in byId) return *a; else return def      ; }

    Link require(in Id id                 ) const{ if(auto a = id in byId) return *a; else{ db.error(format!"Required link %s not found."   (id     )); assert(0); } }
    Link require(in Id id, lazy string msg) const{ if(auto a = id in byId) return *a; else{ db.error(format!"Required link %s not found. %s"(id, msg)); assert(0); } }

    Id get(in Link link               ) const{ if(auto a = link in byLink) return *a; else return Id.init; }
    Id get(in Link link, lazy Id defId) const{ if(auto a = link in byLink) return *a; else return defId  ; }

    Id get(in Id sourceId, in Id verbId                ) const{ return get(Link(sourceId, verbId          )); }
    Id get(in Id sourceId, in Id verbId, in Id targetId) const{ return get(Link(sourceId, verbId, targetId)); }

    Id require(in Link link                 ) const{ if(auto a = link in byLink) return *a; else{ db.error(format!"Required link %s not found."   (link     )); assert(0); } }
    Id require(in Link link, lazy string msg) const{ if(auto a = link in byLink) return *a; else{ db.error(format!"Required link %s not found. %s"(link, msg)); assert(0); } }

    Id require(in Id sourceId, in Id verbId                ) const{ return require(Link(sourceId, verbId          )); }
    Id require(in Id sourceId, in Id verbId, in Id targetId) const{ return require(Link(sourceId, verbId, targetId)); }

    auto opBinaryRight(string op)(in Id id) if(op=="in"){ return get(id); }
    Id opBinaryRight(string op)(in Link link) if(op=="in"){ return get(link); }

    Link opIndex(in Id id) const{ return require(id); }
    Id opIndex(in Link link) const{ return require(link); }

    // data manipulation -------------------------------------------------------

    private void _internal_createLink(in Id id, in Link link){
      byId[id] = link;
      byLink[link] = id;
    }

    bool _internal_tryRemoveLink(in Id id){
      if(auto link = id in this){
        byId.remove(id);
        byLink.remove(link);
        return true;
      }
      return false;
    }

    private void clear(){ byId = null; byLink = null; }

    private Id create(in Id sourceId, in Id verbId, in Id targetId=Id.init){
      auto link = Link(sourceId, verbId, targetId);
      auto id = get(link);
      if(id) return id; //access if can

      id = db._internal_generateNextId;
      _internal_createLink(id, link);
      db.transaction._internal_onLinkCreated(id);

      return id;
    }

    private void load(in Id id, in Link data){
      if(!id) db.error("Invalid null id");
      if(id in db.items) db.error(format!"Load error: Link id already exists as an item. id=%s old=%s new=%s"(id, db.toStr(id), data));
      if(auto link = id in this){
        if(link==data) return; //already loaded, id is the same
        db.error(format!"Load error: Id already exists with different link data. id=%s old=%s new=%s"(id, db.toStr(id), data));
      }
      //id is free, check duplicated data
      if(get(data)) format!"Load error: Link already exists with different id. new=%s"(data);

      //good to go, create it
      db._internal_maximizeNextId(id);
      _internal_createLink(id, data);
    }


  }

  // Transaction ////////////////////

  struct Transaction{
    private AMDB db;
    private string[] commitBuffer, cancelBuffer;

    @property bool active() const { return commitBuffer.length>0; }

    void commit(){
      if(!active) return;

      if(db.dbFileInterface)
        db.dbFileInterface.appendLines(commitBuffer); //todo: transaction header/footer

      commitBuffer = null;
      cancelBuffer = null;
    }

    void cancel(){
      if(!active) return;
      enforce(cancelBuffer.length == commitBuffer.length, "Cancel/commit buffer inconsistency: " ~ cancelBuffer.length.text ~ "!=" ~ commitBuffer.length.text);

      while(cancelBuffer.length){
        auto s = cancelBuffer[$-1];
        try{
          if(s.startsWith('~')){
            Id id;  id.deserializeText(s[1..$]);
            db.deleteThing(id);
          }else NOTIMPL;
        }finally{
          cancelBuffer = cancelBuffer[0..$-1];
          commitBuffer = commitBuffer[0..$-1];
        }
      }
    }

    //called after create but not when loading
    private void _internal_onItemCreated(in Id id){
      commitBuffer ~= db.serializeText(id);
      cancelBuffer ~= '~'~id.serializeText;
    }

    //called after create but not when loading
    private void _internal_onLinkCreated(in Id id){
      commitBuffer ~= db.serializeText(id);
      cancelBuffer ~= '~'~id.serializeText;
    }

  }
  Transaction transaction;

  void commit(){ transaction.commit; }
  void cancel(){ transaction.cancel; }

  // toStr, prettyStr //////////////////////////////////////////////////////////////////

  string toStr(in Id id, int recursion=0){
    if(!id) return "Null";
    if(auto item = id in items) return format!"Item(%s, %s)"(id, (item).quoted);
    if(auto link = id in links) with(link){
      if(recursion-->0){
        return format!"Link(%s, %s, %s, %s)"(id, toStr(sourceId, recursion), toStr(verbId, recursion), toStr(targetId, recursion));
      }else{
        return format!"Link(%s, %s, %s, %s)"(id, sourceId, verbId, targetId);
      }
    }
    return format!"Unknown(%s)"(id);
  }

  string prettyStr(Flag!"color" color = Yes.color)(in Id id){
    if(!id){
      auto s = "null";
      static if(color) s = EgaColor.ltWhite(s);
      return s;
    }else if(auto item = id in items){
      auto s = autoQuoted(item);
      static if(color){
        if     (isSystemVerb(s)) s = EgaColor.ltWhite(s);
        else if(isSystemType(s)) s = EgaColor.ltGreen(s);
        else if(isVerb  (id)   ) s = EgaColor.yellow(s);
        else if(isEType (id)   ) s = EgaColor.ltMagenta(s);
        else if(isEntity(id)   ) s = EgaColor.ltBlue(s);
      }
      return s;
    }else if(auto link = id in links){

      string a(in Id id){ return id in links ? "..." : prettyStr!(color)(id); }

      auto sSource = a(link.sourceId),
           sVerb   = a(link.verbId),
           sTarget = link.targetId ? a(link.targetId) : "";

      return sSource ~ (sSource=="..." ? "" : "  ") ~ sVerb ~ (sTarget=="" ? "" : "  ") ~ sTarget;
    }else{
      auto s = format!"Unknown(%s)"(id);
      static if(color) s = EgaColor.ltRed(s);
      return s;
    }
  }

  string prettyStr(Flag!"color" color = Yes.color)(in Id id, const ColumnInfo ci){
    if(!id){
      auto s = "null";
      static if(color) s = EgaColor.ltWhite(s);
      return console.leftJustify(s, ci.size);
    }else if(auto item = id in items){
      auto s = autoQuoted(item);
      static if(color){
        if     (isSystemVerb(s)) s = EgaColor.ltWhite(s);
        else if(isSystemType(s)) s = EgaColor.ltGreen(s);
        else if(isVerb  (id)   ) s = EgaColor.yellow(s);
        else if(isEType (id)   ) s = EgaColor.ltMagenta(s);
        else if(isEntity(id)   ) s = EgaColor.ltBlue(s);
      }
      return console.leftJustify(s, ci.size);
    }else if(auto link = id in links){

      string a(in Id id){ return id in links ? "..." : prettyStr!(color)(id); }

      auto sSource = a(link.sourceId),
           sVerb   = a(link.verbId),
           sTarget = link.targetId ? a(link.targetId) : "";

      sSource = console.leftJustify(sSource, ci.maxSourceWidth);
      sVerb   = console.leftJustify(sVerb  , ci.maxVerbWidth  );
      sTarget = console.leftJustify(sTarget, ci.maxTargetWidth);

      return sSource ~ (ci.isBackLink?"":"  ") ~ sVerb ~ (ci.maxTargetWidth?"  ":"") ~ sTarget;
    }else{
      auto s = format!"Unknown(%s)"(id);
      static if(color) s = EgaColor.ltRed(s);
      return console.leftJustify(s, ci.size);
    }
  }

  struct ColumnInfo{
    bool anySourceIsNoLink;
    int maxSourceWidth, maxVerbWidth, maxTargetWidth;

    // extra info, calculated later
    bool isBackLink;
    int offset, size;

    private void accumulate(AMDB db, in Id id){
      if(auto link = id in db.links){

        string a(in Id id){ return id in db.links ? "..." : db.prettyStr!(No.color)(id); }

        auto sSource = a(link.sourceId),
             sVerb   = a(link.verbId),
             sTarget = link.targetId ? a(link.targetId) : "";

        anySourceIsNoLink |= sSource!="...";
        maxSourceWidth.maximize(cast(int)(sSource.walkLength));
        maxVerbWidth  .maximize(cast(int)(sVerb  .walkLength));
        maxTargetWidth.maximize(cast(int)(sTarget.walkLength));
      }else{
        auto s = db.prettyStr!(No.color)(id);
        anySourceIsNoLink |= s!="...";
        maxSourceWidth.maximize(cast(int)(s.walkLength));
      }
    }
  }

  private void calcColumnInfoExtra(ColumnInfo[] columns){
    foreach(idx, ref c; columns) with(c){
      isBackLink = !anySourceIsNoLink && c.maxSourceWidth==3;
      size = maxSourceWidth + (maxVerbWidth ? (isBackLink ? 0 : 2) + maxVerbWidth : 0) + (maxTargetWidth ? 2+maxTargetWidth: 0);
      offset = idx>0 ? columns[idx-1].offset+columns[idx-1].size+2 : 0;
    }
  }

  string prettyStr(Flag!"color" color = Yes.color)(in IdSequence seq){
    //todo: Use sentenceColumnIndices!
    return iota(seq.ids.length.to!int).map!((i){
      auto id = seq.ids[i];
      auto s = prettyStr!(color)(id);
      static if(color) if(i==seq.centerIdx) s = "\34\10" ~ s ~ "\34\0";
      return s;
    }).join("  ");
  }

  void printTable(in IdSequence[] seqs){
    const sentenceColumnIndices = seqs.map!(seq => seq.coulmnIndices(this)).array;

    // collect width of columns
    ColumnInfo[] columns;
    columns.length = sentenceColumnIndices.map!(a => a.maxElement(-1)).maxElement(-1)+1;
    foreach(sequenceIdx, const columnIndices; sentenceColumnIndices){
      const ids = seqs[sequenceIdx].ids;
      foreach(sentenceIdx, columnIdx; columnIndices){
        const id = ids[sentenceIdx];
        columns[columnIdx].accumulate(this, id);
      }
    }

    calcColumnInfoExtra(columns);

    // draw the cells from left to right, top to bottom.
    foreach(sequenceIdx, const columnIndices; sentenceColumnIndices){
      const ids = seqs[sequenceIdx].ids;

      int lastColumnIdx = -1;
      foreach(sentenceIdx, columnIdx; columnIndices){
        const id = ids[sentenceIdx];
        const ci(){ return columns[columnIdx]; }
        const newLine = columnIdx != lastColumnIdx+1;
        lastColumnIdx = columnIdx;
        if(newLine){
          write("\n", " ".replicate(ci.offset));
        }else{
          if(sentenceIdx>0) write("  ");
        }
        //todo: justify for integers
        //todo: justify for datetimes
        auto s = id ? prettyStr(id, ci) : " ".replicate(ci.size);
        /*auto highlighted = seqs[sequenceIdx].centerIdx==sentenceIdx;
        if(highlighted) write("\34\10", s, "\34\0"); else */
        write(s);
      }
      writeln;
    }

  }

  // serialization ////////////////////////////////////////////

  string serializeText(in Id id){
    if(auto link = id in links){
      with(link) return id.serializeText ~" "~ sourceId.serializeText ~" "~ verbId.serializeText ~(targetId ? " "~targetId.serializeText : "");
    }else if(auto item = id in items){
      auto s = autoQuoted(item);
      //string is closed with newLine.  Only need to escape when it contains newLine or starts with the escape quote. But to make sure, escape it if it contains any special chars
      return id.serializeText~"="~s;
    }else error("Invalid Id to serialize:"~id.text);
    assert(0);
  }

  string serializeText(R)(in R r){ return r.map!(i => serializeText(i)~"\n").join; }

  void deserializeLine(string line){
    line = line.strip;
    if(line=="") return;
    const idx = line.map!(ch => ch==' ' || ch=='=').countUntil(true);
    enforce(idx>0, "Invalid text db line format: "~line.quoted);

    //get Id
    const id = Id(line[0..idx].to!uint);
    const lineType = line[idx];
    line = line[idx+1..$];

    switch(lineType){
      case '=':{ //Item
        items.load(id, autoUnquoted(line));
      }break;
      case ' ':{
        auto p = line.split(' ').map!(a => Id(a.to!uint)).array;
        enforce(p.length.among(2, 3), "Invalid link id count. "~line.quoted);
        if(p.length==2) p ~= Id.init;
        foreach(a; p) enforce(!a || a in items || a in links, "Invalid link id: "~a.text~" "~line.quoted);
        links.load(id, Link(p[0], p[1], p[2]));
      }break;
      default: raise("Unknown lineType. "~line.quoted);
    }
  }

  private void load(){
    try{
      clear;
      if(dbFileInterface) foreach(line; dbFileInterface.readLines) deserializeLine(line);
    }catch(Exception e){
      raise("AMDB load error: "~e.simpleMsg);
    }
  }


  // find referrers ///////////////////////////////////////////////////

  auto referrers(Flag!"source" chkSource = Yes.source, Flag!"verb" chkVerb = Yes.verb, Flag!"target" chkTarget = Yes.target, alias retExpr="a.key")(in Id id){
    return links.byId.byKeyValue.filter!(a => chkSource && a.value.sourceId==id
                                           || chkVerb   && a.value.verbId  ==id
                                           || chkTarget && a.value.targetId==id).map!retExpr;
  }

  auto sourceReferrers(in Id id){ return referrers!(Yes.source, No .verb, No .target)(id); }
  auto verbReferrers  (in Id id){ return referrers!(No .source, Yes.verb, No .target)(id); }
  auto targetReferrers(in Id id){ return referrers!(No .source, No .verb, Yes.target)(id); }

  bool hasReferrers(in Id id){
    if(!id) return false;
    return !referrers(id).empty;
  }

  auto allReferrers(Flag!"source" chkSource = Yes.source, Flag!"verb" chkVerb = Yes.verb, Flag!"target" chkTarget = Yes.target, alias retExpr="a.key")(in Id id){
    bool[Id] found;

    void doit(in Id id){
      foreach(r; referrers!(chkSource, chkVerb, chkTarget, retExpr)(id)) if(r !in found){
        found[r]=true;
        doit(r);
      }
    }
    doit(id);

    return found.keys.sort.array;
  }

  auto allSourceReferrers(in Id id){ return referrers!(Yes.source, No .verb, No .target)(id); }
  auto allTargetReferrers(in Id id){ return referrers!(No .source, No .verb, Yes.target)(id); }

  // delete ///////////////////////////////////////////////////////////////

  void deleteThing(in Id id){ //used by transaction.cancel
    if(!id) return; //no need to delete null
    enforce(!hasReferrers(id), "Can't delete, because it has references:  "~prettyStr(id));
    if(items._internal_tryRemoveItem(id) || links._internal_tryRemoveLink(id)) return;
    raise("Can't delete thing. Id not found: "~id.text);
  }

/*  void _internal_replaceLink(in Id linkId, in Link oldLink, in Link newLink){
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
  }*/

  // Central notification handling ////////////////////////////

  // translations /////////////////////////////////////////

  string inputTranslateVerb(string s){
    if(s=="is an") s="is a";
    return s;
  }


  // systemTypes //////////////////////////////////////////

  immutable allSystemTypes = ["Verb", "EType", "AType", "String", "Int", "Long", "UInt", "ULong", "Float", "Double", "DateTime", "Date", "Time"];

  auto systemTypeMap(){
    static int[string] m;
    if(!m){ foreach(idx, name; allSystemTypes) m[name] = cast(int)idx + 1; m.rehash; }
    return m;
  }

  int systemTypeIdx(string name){ return systemTypeMap.get(name, 0); }
  bool isSystemType(string name){ return (name in systemTypeMap)!is null; }

  // systemVerbs //////////////////////////////////////////

  immutable allSystemVerbs = ["is a"];

  auto systemVerbMap(){
    static int[string] m;
    if(!m){ foreach(idx, name; allSystemVerbs) m[name] = cast(int)idx + 1; m.rehash; }
    return m;
  }

  int systemVerbIdx(string name){ return systemVerbMap.get(name, 0); }
  bool isSystemVerb(string name){ return (name in systemVerbMap)!is null; }

  Id sysId(string name){
    if(auto id = name in items) return id;
    if(isSystemVerb(name) || isSystemType(name)) return items.create(name);

    error("Invalid sysId name. Must be a systemVerb or a systemType. "~name.quoted);
    assert(0);
  }

  // input verifications ///////////////////////////////////////////////////

  private void verifyETypeName(string s){
    enforce(s.length, "Invalid entity name. Empty string. "~s.quoted);
    auto ch = s.decodeFront;
    enforce(ch.isLetter && ch==ch.toUpper, "Invalid entity name. Must start with a capital letter. "~s.quoted);
    enforce(!isSystemType(s), "Invalid entity name. Can't be a system type. "~s.quoted);
    enforce(!isSystemVerb(s), "Invalid entity name. Can't be a system verb. "~s.quoted);
  }

  private void verifyVerbName(string s){
    enforce(s.length, "Invalid verb name. Empty string. "~s.quoted);
    auto olds = s; //todo: it's ugly
    auto ch = s.decodeFront;
    enforce(ch.isLetter && ch==ch.toLower, "Invalid verb name. Must start with a lower letter. "~olds.quoted);
    enforce(!isSystemType(s), "Invalid verb name. Can't be a system type. "~olds.quoted);
    enforce(!isSystemVerb(s), "Invalid verb name. Can't be a system verb. "~olds.quoted);
  }

  // filter, exists ///////////////////////////////////////////////////////

  bool exists(S, V, T)(in S s, in V v, in T t){
    static if(is(S==Id)) auto si = s; else auto si = s in items;
    static if(is(V==Id)) auto vi = v; else auto vi = v in items;
    static if(is(T==Id)) auto ti = t; else auto ti = t in items;
    return (Link(si, vi, ti) in links).valid; //this is fast
  }

  bool exists(S, V)(in S s, in V v){ return exists(s, v, Id.init); }

  auto filter(S, V, T)(in S source, in V verb, in T target){
    bool test(in Link link){

      bool testOne(T)(in Id id, in T criteria){
        static if(isSomeString!T){
          if(!items.get(id).isWild(criteria)) return false; //todo: ez hasonlit a chkId-re, ossze kene vonni!
        }else static if(is(Unqual!T == Id)){
          if(source && id != criteria) return false;
        }else static assert(0, "Invalid params");
        return true;
      }

      if(!testOne(link.sourceId, source)) return false;
      if(!testOne(link.verbId  , verb  )) return false;
      if(!testOne(link.targetId, target)) return false;
      return true;
    }

    return links.byId.byKeyValue.filter!(a => test(a.value)).map!"a.key";
  }

  bool isAType(T)(in T a){ return exists(a, "is a", "AType"); }
  bool isEType(T)(in T a){ return exists(a, "is a", "EType"); }
  bool isVerb (T)(in T a){ return exists(a, "is a", "Verb" ); }

  bool isEntity(in Id id){ return filter(id, "is a", "*").any!(a => isEType(links[a].targetId)); }

  bool isInstanceOf(T, U)(in T entity, in U eType){ return exists(entity, "is a", eType); } //todo: subtype handling

  auto things()  { return chain(items.ids, links.ids); }
  auto verbs()   { return filter("*", "is a", "Verb" ).map!(a => links[a].sourceId); }
  auto eTypes()  { return filter("*", "is a", "EType").map!(a => links[a].sourceId); }
  auto aTypes()  { return filter("*", "is a", "AType").map!(a => links[a].sourceId); }

  auto entities()           { return eTypes                             .map!(e => filter("*", "is a", e).map!(e => links.get(e).sourceId)).join; }
  auto entities(string mask){ return eTypes.filter!(e => chkId(e, mask)).map!(e => filter("*", "is a", e).map!(e => links.get(e).sourceId)).join; }

  char thingCategory(in Id id){
    if(!id) return 0;
    if(auto link = id in links){
      if(isAType(id)) return 's';
      if(items.get(link.verbId)=="is a"){
        if(isEType(link.targetId)) return 'e';
        return 's';
      }else return 'd';
    }else return 'i';
  }

  bool isSchema                 (in Id id){ return thingCategory(id)=='s'; }
  bool isEntityAssociation      (in Id id){ return thingCategory(id)=='e'; }
  bool isData                   (in Id id){ return thingCategory(id)=='d'; }
  bool isItem                   (in Id id){ return thingCategory(id)=='i'; }

  // create system things /////////////////////////////

  private Id createEType(string s){
    verifyETypeName(s);
    return items.create(s, (id){ links.create(id, sysId("is a"), sysId("EType")); }); //implicit "* is a EType"
  }

  private Id resolveType(string s){
    if(isSystemType(s)) return sysId(s);

    if(auto id = s in items) if(exists(id, "is a", "EType")) return id;

    if(autoCreateETypes){
      return createEType(s);
    }else{
      enforce(0, "Unknown type: "~s.quoted);
      return Id.init;
    }
  }

  private Id createVerb(string s){
    verifyVerbName(s);
    return items.create(s, (id){ links.create(id, sysId("is a"), sysId("Verb"));} ); //implicit "* is a Verb"
  }

  private Id resolveVerb(string s){
    if(isSystemVerb(s)) return sysId(s); //system verbs are not asserted

    if(auto id = s in items) if(exists(id, "is a", "Verb")) return id;

    if(autoCreateVerbs){
      return createVerb(s);
    }else{
      enforce(0, "Unknown verb: "~s.quoted);
      return Id.init;
    }
  }

  private Id createVerbAssertion(string name){
    enforce(name!="...", "Verb Assertion source can't be a \"...\" association.");
    enforce(!isSystemType(name), "Verb Assertion source can't be a SystemType: "~name.quoted);
    enforce(!isSystemVerb(name), "Verb Assertion source can't be a SystemVerb: "~name.quoted);
    return createVerb(name);
  }

  private Id createETypeAssertion(string name){
    enforce(name!="...", "EType Assertion source can't be a \"...\" association.");
    enforce(!isSystemType(name), "EType Assertion source can't be a SystemType: "~name.quoted);
    enforce(!isSystemVerb(name), "EType Assertion source can't be a SystemVerb: "~name.quoted);
    return createEType(name);
  }

  private Id createEntityAssertion(string name, string type){
    enforce(name!="...", "Entity assertion source can't be a \"...\" association.");

    enforce(!isSystemType(name), "Entity assertion source can't be a SystemType: "~name.quoted);
    enforce(!isSystemVerb(name), "Entity assertion source can't be a SystemVerb: "~name.quoted);
    enforce(!exists(name, "is a", "EType"), "Entity assertion source can't be an EType: "~name.quoted);
    enforce(exists(type, "is a", "EType"), "Entity assertion target must be an EType: "~type.quoted);

    return links.create(items.create(name), sysId("is a"), items[type]);
  }

  // input text, sentence processing //////////////////////////////

  static string[][] textToSentences(string input){
    import het.tokenizer : collectAndReplaceQuotedStrings;
    auto quotedStrings = collectAndReplaceQuotedStrings(input, `  "  `);
    string fetchQStr(){
      enforce(quotedStrings.length, "Quoted string literals: Array is empty.");
      return quotedStrings.fetchFront;
    }

    string[][] lineToSentences(string line){
      //strip at "..."
      auto p = line.strip.split("...").map!strip.array;

      //handle the first special case.
      foreach(i; 1..p.length) p[i] = "...  "~p[i]; //put back the "...", it will be processed later
      if(p.length && p[0]=="") p = p[1..$]; //is it allowed to start a new line with "...".

      //split the sentences to words. Separator is double space.
      string[] splitSentence(string s){
        return s.strip.split("  ").map!strip.filter!"a.length".map!(a => a==`"` ? fetchQStr : a).array; //todo: empty string encoded as ""
      }
      return p.map!(a => splitSentence(a)).array;
    }

    return input.splitLines.map!(line => lineToSentences(line)).join;
  }

  static string[][] toSentences(T)(T s){
    static if(isSomeString!T) return textToSentences(s);
                         else return s;
  }

  // schema, data entry ///////////////////////////////////////////////////////

  bool typeCheck(in Id typeId, string data){
    if(const typeName = typeId in items){
      if(isEType(typeId)){
        return isInstanceOf(data, typeId); //todo: supertypes
      }else if(isSystemType(typeName)){ //todo: slow
        switch(typeName){
          case "String": return true;
          case "Int": return data.to!int.collectException is null;
          case "Long": return data.to!long.collectException is null;
          case "UInt": return data.to!uint.collectException is null;
          case "ULong": return data.to!ulong.collectException is null;
          case "DateTime": return data.DateTime.collectException is null;
          case "Date": return data.Date.collectException is null;
          case "Time": return data.Time.collectException is null;
          default:
        }
      }
    }

    error("Unhandled type: "~prettyStr(typeId)); //todo: prettyStr nem jo ide, mert az exceptionnal nincs szinezes
    return false;
  }

  private Id[] findATypesForSentence(string[] p, in Id lastTypeId){

    enforce(p.length.among(2, 3), "Invalid sentence length: "~p.text);
    enforce(isVerb(p[1]), "Unknown verb: "~p.text);
    Id verbId = items[p[1]];
    Id[] res;
    foreach(aid, link; links.byId) if(link.verbId==verbId) if(isAType(aid)){

      const sourceIsOk = p[0]=="..." && link.sourceId==lastTypeId || !isAType(link.sourceId) && typeCheck(link.sourceId, p[0]);
      if(!sourceIsOk) continue;

      const targetIsOk = p.length==2 && !link.targetId || p.length==3 && !isAType(link.targetId) && typeCheck(link.targetId, p[2]);
      if(!targetIsOk) continue;

      res ~= aid;
    }
    return res;
  }

  private bool walkToSourceAType(ref Id id){
    if(auto link = id in links) if(isAType(link.sourceId)){
        id = link.sourceId;
        return true;
      }
    return false;
  }

  private bool walkToSourceLink(ref Id id){
    if(auto link = id in links) if(link.sourceId in links){
        id = link.sourceId;
        return true;
      }
    return false;
  }


  void processSchemaSentence(string[] p, ref Id id){
    enforce(p.length.among(2, 3), "Invalid sentence length: "~p.text);
    enforce(id || p[0]!="...", "Last Id is null at sentence:"~p.text);

    p[1] = inputTranslateVerb(p[1]);

    if(isSystemVerb(p[1])){
      if(p[1]=="is a"){ //Verb and EType assertion
        enforce(p.length==3, "Assertion must have a target: "~p.text);

        switch(p.get(2)){
          case "Verb" : id = createVerbAssertion(p[0]); break;
          case "EType": id = createETypeAssertion(p[0]); break;
          default: enforce(0, "Invalid schema assertion: "~p.text);
        }
      }else{
        enforce(0, "Unhandled system verb in schema: "~p.text);
      }
    }else{
      //association type
      id = links.create(p[0]=="..." ? id : resolveType(p[0]),
                        resolveVerb(p[1]),
                        p.length>2 ? resolveType(p[2]) : Id.init);

      links.create(id, sysId("is a"), sysId("AType"));
    }
  }

  void processDataSentence(string[] p, ref Id tid, ref Id id){
    enforce(p.length.among(2, 3), "Invalid sentence length: "~p.text);
    enforce(id || p[0]!="...", "Last Id is null at sentence:"~p.text);  //same until this point!!!!

    p[1] = inputTranslateVerb(p[1]);

    if(isSystemVerb(p[1])){
      if(p[1]=="is a"){ // Entity assertion
        enforce(p.length==3, "Entity assertion must have a target: "~p.text);
        id = createEntityAssertion(p[0], p[2]);
      }else{
        enforce(0, "Unhandled system verb in data: "~p.text);
      }
    }else{ //association
      //find a valid atype for this sentence. Try to step back to sourceId if that is an atype.
      Id[] aTypes;
      auto tempTid = tid, tempId = id;
      do{
        aTypes = findATypesForSentence(p, tempTid);
      }while(aTypes.empty && p[0]=="..." && walkToSourceAType(tempTid) && walkToSourceLink(tempId));

      //check if exactly one type found
      if(aTypes.empty) error("Unable to find AType for: "~p.text);
      if(aTypes.length>1) error("Ambiguous ATypes found for for: "~p.text~" ["~aTypes.map!(a => prettyStr(a)).join(", ")~"]");

      //ok to go. Actualize current id and tid after a possible step-back
      id = tempId;
      tid = tempTid;

      //create the link
      id = links.create(p[0]=="..." ? id : items.create(p[0]),
                        items[p[1]],
                        p.length>2 ? items.create(p[2]) : Id.init);
      tid = aTypes[0];
    }
  }


  // multiline bulk processing
  private Id lastSchemaId;

  void schema(string input){
    lastDataTypeId = lastDataId = Id.init; //reset the state of other input categories

    foreach(s; textToSentences(input)) processSchemaSentence(s, lastSchemaId);
  }

  private Id lastDataId, lastDataTypeId;

  void data(string input){
    lastSchemaId = Id.init; //reset the state of other input categories

    foreach(s; textToSentences(input)) processDataSentence(s, lastDataTypeId, lastDataId);
  }

  // query ////////////////////////////////////////////////////////

  struct QueryInputSources{
    bool items, schema, entities, data;

    @property bool any () const{ return items || schema || entities || data; }
    @property bool all () const{ return items && schema && entities && data; }
    @property bool none() const{ return !any; }

    @property bool anyLinks() const{ return schema || entities || data; }
    @property bool anyItems() const{ return items; }

    void setFlags(string flags){
      this = typeof(this).init;
      if(flags.canFind('i')) items    = true;
      if(flags.canFind('s')) schema   = true;
      if(flags.canFind('e')) entities = true;
      if(flags.canFind('d')) data     = true;
      if(flags.canFind('a')) items = schema = entities = data = true;

      //none means only the 'data'
      if(none) data = true;
    }

    bool check(char thingCategory) const{
      if(all) return true;
      if(none) return false;
      switch(thingCategory){
        case 'i': return items;
        case 's': return schema;
        case 'e': return entities;
        case 'd': return data;
        default: return false;
      }
    }
  }

  struct QueryOptions{
    QueryInputSources sources;  alias sources this;
    bool extendLeft, extendRight;
  }

  private auto fetchQueryOptions(ref string input){
    auto flags = input.fetchRegexFlags;
    QueryOptions res;

    res.sources.setFlags(flags);

    // extend left and right
    res.extendRight = input.endsWith  ("...");  if(res.extendRight) input = input.withoutEnding  ("...");
    res.extendLeft  = input.startsWith("...");  if(res.extendLeft ) input = input.withoutStarting("...");

    return res;
  }


  /// own version of wildcard check specialized to AMDB
  private bool chkStr(string s, string mask){
    return s.isWild(mask);
  }

  private bool chkId(in Id id, string mask){ //todo: ez mehetne a filter-be is, mert hasonlo
    string s;
    if(!id) s = "null";
    else if(auto a = id in items) s = a;
    else if(id in links) s = "...";
    else NOTIMPL;

    // mask : eType
    if(mask.canFind(':')){
      auto p = mask.split(':').map!strip;
      enforce(p.length==2, "Invalid typed mask format");

      const itemMask  = p[0]=="" ? "*" : p[0];
      const eTypeMask = p[1]=="" ? "*" : p[1];

      return chkStr(s, itemMask) && !filter(id, "is a", eTypeMask).empty;
    }

    return chkStr(s, mask);
  }

  enum QuerySource{ all, data, schema, items }

  Id[] query(string[] p, in QueryInputSources qs){ //works on a single sentence

    bool checkQuerySourceLinks(in Id id){ return qs.check(thingCategory(id)); }

    Id[] res;
    if(p.length==1){
      if(qs.anyLinks) foreach(id, const link; links.byId){
        if(!checkQuerySourceLinks(id)) continue;
        if(chkId(link.sourceId, p[0]) || chkId(link.verbId, p[0]) || chkId(link.targetId, p[0])) res ~= id; // x  ->  x can be at any place
      }
      if(qs.anyItems) foreach(id; items.ids){
        if(chkId(id, p[0])) res ~= id; // also can be an item too
      }
    }else if(p.length==2){
      if(qs.anyLinks) foreach(id, const link; links.byId){
        if(!checkQuerySourceLinks(id)) continue;
        if(!link.targetId && chkId(link.sourceId, p[0]) && chkId(link.verbId, p[1])) res ~= id; // target must be null
      }
    }else if(p.length==3){
      if(qs.anyLinks) foreach(id, const link; links.byId){
        if(!checkQuerySourceLinks(id)) continue;
        if(chkId(link.sourceId, p[0]) && chkId(link.verbId, p[1]) && chkId(link.targetId, p[2])) res ~= id;
      }
    }else NOTIMPL;
    return res;
  }

  /// Extends srcIds with referencing child links. Sentence must start with "..."
  Id[] query(Id[] sourceIds, string[] p){
    Id[] res;
    enforce(p.length.among(2, 3), `Invalid sentence for srcId based query. Invalid sentence length. `~p.text);
    enforce(p.get(0)=="...", `Invalid sentence for srcId based query. Source must be "...". `~p.text);
    if(p.length==2){
      foreach(sourceId; sourceIds){
        foreach(id, const link; links.byId){
          /* if(link.sourceId==sourceId && !link.targetId && chkId(link.verbId, p[1])) res ~= id; */
          if(link.sourceId==sourceId && (chkId(link.verbId, p[1]) || chkId(link.targetId, p[1]))) res ~= id;  // ...x  ->  x can be at any place
        }
      }
    }else if(p.length==3){
      foreach(sourceId; sourceIds){
        foreach(id, const link; links.byId){
          if(link.sourceId==sourceId && chkId(link.verbId, p[1]) && chkId(link.targetId, p[2])) res ~= id;
        }
      }
    }
    return res;
  }

  /// Extends srcIds with referencing child links. generalized recursive version, works with more than one sentence
  Id[] query(Id[] sourceIds, string[][] sentences){
    while(sentences.length) sourceIds = query(sourceIds, sentences.fetchFront);
    return sourceIds;
  }

  Id[] query(T)(T sentences, in QueryInputSources qs){ //works on sentences
    Id[] res;
    auto s = toSentences(sentences);
    if(s.length==0) return null; //empty query
    if(s.length==1) return query(s[0], qs); //one sentence
    return query(query(s[0], qs), s[1..$]); //many sentences in a chain
  }

  IdSequence extend(in Id id, in QueryOptions queryOptions){
    auto seq = IdSequence([id]);
    if(queryOptions.extendRight) seq = extendRight(seq);
    if(queryOptions.extendLeft ) seq = extendLeft (seq);
    return seq;
  }

  IdSequence[] query(T)(T sentences, in QueryOptions queryOptions){ //this version does left/right extensions too
    return query(sentences, queryOptions.sources).sort.map!(i => extend(i, queryOptions)).array;
  }

  static struct IdSequence{ // IdSequence ///////////////////////////////////////
    Id[] ids;
    int leftExtension, rightExtension;

    @property int centerIdx() const{ return ids.length.to!int-1-rightExtension; }

    void appendLeft (Id   ext){ ids = ext ~ ids      ; leftExtension  ++; }
    void appendRight(Id   ext){ ids =       ids ~ ext; rightExtension ++; }
    void appendLeft (Id[] ext){ ids = ext ~ ids      ; leftExtension  += ext.length.to!int; }
    void appendRight(Id[] ext){ ids =       ids ~ ext; rightExtension += ext.length.to!int; }

    int[] coulmnIndices(AMDB db) const{
      int[] indices;
      Id[] stack;
      foreach(id; ids){
        if(!id){
          stack ~= id; //nothing to do with null
        }else{
          //measure how much to step back for the parent
          sizediff_t backSteps = -1;
          auto link = id in db.links;
          if(!stack.empty && link)
            backSteps = stack.retro.countUntil!(s => !s || s == link.sourceId);

          if     (backSteps==0) stack ~= id;
          else if(backSteps> 0) stack = stack[0..$-backSteps]~id;
          else                  stack = [id]; //no connection -> restart the stack
        }
        indices ~= (cast(int)stack.length)-1;
      }
      return indices;
    }
  }

  // extend Left/Right //////////////////////////////////////////////////////////

  private enum defaultExtendLeftRecursion = 100;

  IdSequence extendLeft(IdSequence seq, int recursion=defaultExtendLeftRecursion){
    foreach(i; 0..recursion){
      if(seq.ids.length)
        if(auto link = seq.ids[0] in links.byId)
          if(link.sourceId in links){
            seq.appendLeft(link.sourceId);
            continue;
          }
      break;
    }
    return seq;
  }

  IdSequence extendRight(IdSequence seq){
    Id[] sourceExtension(in Id sourceId){ return sourceReferrers(sourceId).map!(i => i ~ sourceExtension(i)).join.sort.array; }
    if(seq.ids.length && seq.ids[$-1]in links) seq.appendRight(sourceExtension(seq.ids[$-1]));
    return seq;
  }

  // pads with empty sentences from the left to equalize the lengths of the left-extensions
  IdSequence[] padLeft(IdSequence[] seqs){
    if(seqs.empty) return seqs;
    int maxLeftExtension = seqs.map!(s => s.leftExtension).maxElement;
    foreach(ref s; seqs){
      int a = max(maxLeftExtension-s.leftExtension, 0);
      if(a>0){
        s.ids = [Id.init].replicate(a) ~ s.ids;
        s.leftExtension += a;
      }
    }
    return seqs;
  }

  // text mode interface ////////////////////////////////////////////

  void printFilteredSortedItems(R)(R r, string mask=""){
    r.filter!(i => mask=="" || chkId(i, mask)).array.sort!((a,b)=>icmp(items.get(a, ""), items.get(b, ""))<0).each!(i => print(prettyStr(i)));
  }

  void tryDelete(Id[] ids){
    print("-------------------------------------------------------");
    Id[] remaining;
    bool anyDeleted;

    do{
      anyDeleted = false;
      foreach(id; ids) if(hasReferrers(id)){
        remaining ~= id;
      }else{
        print("DELETING", prettyStr(id));
        deleteThing(id);
        anyDeleted = true;
      }
      ids = remaining;
    }while(ids.length && anyDeleted);

    if(ids.length) WARN("Unable to delete all"); //todo: wipe
  }

  auto query(string input){
    const options = fetchQueryOptions(input);
    return query(input, options);
  }

  int execTextCommand(string input){
    input = input.strip;

    try{
      string cmd = input.wordAt(0);
      input = input[cmd.length..$].strip;

      switch(cmd.lc){
        case "id": print(prettyStr(extendLeft(IdSequence([Id(input.to!uint)])))); break;

        case "s", "schema": schema(input); break;
        case "d", "data": data(input); break;
        case "q", "query":{
          //const options = fetchQueryOptions(input);
          auto res = padLeft(query(input/*, options*/));
          printTable(res);
        }break;

        case "items"   : printFilteredSortedItems(items.ids, input); break;
        case "etypes"  : printFilteredSortedItems(eTypes   , input); break;
        case "verbs"   : printFilteredSortedItems(verbs    , input); break;
        case "entities": printFilteredSortedItems(entities(input=="" ? "*" : input)); break;

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
    }catch(Exception e){
      print(EgaColor.ltRed("ERROR:"), e.simpleMsg);
    }

    writeln;
    return true;
  }

  string inputTextCommand(){
    //prompt
    write(EgaColor.white(">"), format!" I:%d + L:%d = %d %s"(items.count, links.count, items.count+links.count, transaction.commitBuffer.length ? EgaColor.red("*"~transaction.commitBuffer.length.text~" ") : ""));

/*    switch(textCommandMode){
      case 's': write(EgaColor.ltMagenta("schema ")); break;
      case 'd': write(EgaColor.ltBlue   ("data ")); break;
      case 'q': write(EgaColor.ltGreen  ("query ")); break;
      default: raise("invalid mode");
    }*/
    write(EgaColor.white("> "));

    return readln;
  }

  void textCommandLoop(){
    while(execTextCommand(inputTextCommand)){}
  }

}

//! Unittest //////////////////////////////////////

void unittest_splitSentences(){
  uint h;
  void a(string s){
    auto r = AMDB.textToSentences(s).text; h = r.xxh32(h);
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

void unittest_main(){
  unittest_splitSentences;
}