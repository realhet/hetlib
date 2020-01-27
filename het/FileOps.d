module het.fileops;

public import het.utils, het.dialogs;

enum FileOpEnum {FileLoad, FileSave, UndoLoad, UndoSave }

class FileOps{
private:
  alias Data = ubyte[];

  //filename, protected from outside
  File fileName_;
  @property fileName(File fn){ fileName_ = fn; }
  public @property File fileName() const { return fileName_; }

  public  File defaultSaveFileName; //app sets it. For the new file being saved

  Data fileData;
  FileDialog fileDialog;

  int savedCnt=0; //if == 0 -> cansave is false.
  // new, open, save, saveas: set to 0
  // undo: dec;  redo: inc;  chg: inc if >=0

  immutable historyMaxSize = 20;
  File[] history;

  struct UndoRec {
    Data data;
    string caption;
  };

  bool lastOpWasNew, blockChg;
  Data lastData; //saved before chg()
  UndoRec[] undoBuf, redoBuf;

  File delegate(File) onSave;
  File delegate() onLoad;
  void delegate(FileOpEnum) onFileOp;

public:
  this(FileDialog fileDialog_, void delegate(FileOpEnum) onFileOp_){
    assert(fileDialog_);
    assert(onFileOp_);

    fileDialog = fileDialog_;
    onFileOp = onFileOp_;

    clickNew;
  }

  bool isChanged()      const { return savedCnt!=0; }
  bool isNew()          const { return lastOpWasNew && !isChanged; }

  size_t undoCount()      const { return undoBuf.length; }
  size_t redoCount()      const { return redoBuf.length; }
  string undoCaption()  const { return canUndo ? undoBuf[$-1].caption : ""; }
  string redoCaption()  const { return canRedo ? redoBuf[$-1].caption : ""; }

  string fileCaption()  const { return (isChanged?"*":"")~(fileName.toString=="" ? "unnamed" : fileName.toString); }

  size_t memUsage() const {
    return fileData.sizeof +
           undoBuf.map!"a.data.sizeof".sum +
           redoBuf.map!"a.data.sizeof".sum;
  }

  string stats() const{ //todo: erre a stats()-ra valami mixint csinalni, tul sok az ismetles
    return format("undoCnt:%d redoCnt:%d isChanged:%d isNew:%d memUsage:%d savedCnt:%d fileName:%s",
                   undoCount, redoCount, isChanged,   isNew,   memUsage,   savedCnt,   fileName);
  }

  bool canCloseApp(){ //should be called before exit
    return trySaveBeforeNewOrOpen;
  }

  struct action{}

  //user commands
  @action{
    void clickNew(){ new_(true); }

    void clickDiscard(){ new_(false); }

    void clickOpen(){ open(File("")); }

    bool canSave()        const { return isChanged || isNew; }
    void clickSave(){
      if(!fileName) { clickSaveAs; return; }
      save(fileName); //Save always, even when unchanged!!!!
    }

    void clickSaveAs(){
      auto fn = fileDialog.saveAs(fileName ? fileName : defaultSaveFileName);
      if(!fn) return;
      save(fn);
    }

    bool canUndo() const { return undoCount>0; }
    void clickUndo(){
      if(!canUndo) return;
      redoBuf ~= UndoRec(lastData, "");
      lastData = takeLast(undoBuf).data;
      contentLoad(lastData, false);
      savedCnt--;
    }

    bool canRedo() const { return redoCount>0; }
    void clickRedo(){
      if(!canRedo) return;
      undoBuf ~= UndoRec(lastData, "");
      lastData = takeLast(redoBuf).data;
      contentLoad(lastData, false);
      savedCnt++;
    }
  }

  //editor notifies this when there is a modification
  void notifyChg(string undoCaption = ""){
    redoBuf.clear;
    undoBuf ~= UndoRec(lastData, undoCaption);
    lastData = contentSave(false);
    if(savedCnt>=0) ++savedCnt;
  }

private:
  void clearUndo() {
    undoBuf.clear;
    redoBuf.clear;
    savedCnt = 0;
  }

  void contentLoad(Data data_, bool isFile){
    blockChg = true;
    fileData = data_;
    onFileOp(isFile ? FileOpEnum.FileLoad : FileOpEnum.UndoLoad);
    blockChg = false;
  }
  Data contentSave(bool isFile){
    fileData = null;
    onFileOp(isFile ? FileOpEnum.FileSave : FileOpEnum.UndoSave);
    return fileData;
  }

  //internal commands  (fn=="" means file dialog query)
  bool new_(bool trySave = true){
    if(trySave && !trySaveBeforeNewOrOpen) return false;

    fileName.fullName = "";
    lastOpWasNew = true;
    contentLoad(null, true);
    clearUndo;

    return true;
  }

  bool open(File fn, bool trySave = true){  //!!!!!!!trysave-nek mindig igaznak kene lennie, viszont akkor kellene discard parancs
    if(trySave && !trySaveBeforeNewOrOpen) return false;

    if(!fn){
      fn = onLoad(); //!!!!!!!!!!!!!!!Ezeket a dialogokat inkabb egy FileDialog class-al kene csinalni.
      if(!fn)return false;
    }

    fileName = fn;
    lastOpWasNew = false;
    contentLoad(fn.read, true);
    lastData = contentSave(false); //Why???????
    clearUndo;

    return true;
  }

  bool save(File fn){
    if(!fn){
      fn = fileDialog.saveAs(File(""));
      if(!fn) return false;
    }

    fileName = fn;
    lastOpWasNew = false;
    fileName.write(contentSave(true));

    //undoBuf.clear(); redoBuf.clear(); NO undo clear on save!!!!
    savedCnt = 0; //only savecnt.reset

    return true;
  }

  void updateHistory(){
    if(!fileName) return;
    if(!history.empty && history[0]==fileName) return;

    //remove older items of the same name
    history = history.filter!(h => h!=fileName).array;

    //insert latest fileName
    history = fileName ~ history;

    //restrict history size
    if(history.length>historyMaxSize) history.length = historyMaxSize;
  }

  //saves before New or Open. returns true if saved or nothing to save or user don't wanna save.
  bool trySaveBeforeNewOrOpen(){
    if(!isChanged()) return true;

    switch(messageBox(fileDialog.owner, "The edited "~fileDialog.what~" has been modified.\nDo you want to save your changes?", "Unsaved changes", MB_ICONWARNING|MB_YESNOCANCEL)){
      case IDYES: return save(fileName);
      case IDNO: return true;
      default: return false;
    }
  }
}





