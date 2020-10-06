module het.dialogs;

import het.utils, het.color, core.sys.windows.windows, core.sys.windows.shlobj;

pragma(lib, "comdlg32.lib");
pragma(lib, "ole32.lib");  //CoTaskMemFree needs it

//copy paste from winuser.d to compile faster
enum {
    MB_OK                        = 0,
    MB_OKCANCEL,
    MB_ABORTRETRYIGNORE,
    MB_YESNOCANCEL,
    MB_YESNO,
    MB_RETRYCANCEL,
    MB_CANCELTRYCONTINUE,     // = 6
    MB_TYPEMASK                  = 0x0000000F,
    MB_ICONHAND                  = 0x00000010,
    MB_ICONSTOP                  = MB_ICONHAND,
    MB_ICONERROR                 = MB_ICONHAND,
    MB_ICONQUESTION              = 0x00000020,
    MB_ICONEXCLAMATION           = 0x00000030,
    MB_ICONWARNING               = MB_ICONEXCLAMATION,
    MB_ICONASTERISK              = 0x00000040,
    MB_ICONINFORMATION           = MB_ICONASTERISK,
    MB_USERICON                  = 0x00000080,
    MB_ICONMASK                  = 0x000000F0,

    MB_DEFBUTTON1                = 0,
    MB_DEFBUTTON2                = 0x00000100,
    MB_DEFBUTTON3                = 0x00000200,
    MB_DEFBUTTON4                = 0x00000300,
    MB_DEFMASK                   = 0x00000F00,

    MB_APPLMODAL                 = 0,
    MB_SYSTEMMODAL               = 0x00001000,
    MB_TASKMODAL                 = 0x00002000,
    MB_MODEMASK                  = 0x00003000,

    MB_HELP                      = 0x00004000,
    MB_NOFOCUS                   = 0x00008000,
    MB_MISCMASK                  = 0x0000C000,

    MB_SETFOREGROUND             = 0x00010000,
    MB_DEFAULT_DESKTOP_ONLY      = 0x00020000,
    MB_TOPMOST                   = 0x00040000,
    MB_SERVICE_NOTIFICATION_NT3X = 0x00040000,
    MB_RIGHT                     = 0x00080000,
    MB_RTLREADING                = 0x00100000,
    MB_SERVICE_NOTIFICATION      = 0x00200000
}

enum {
    IDOK          = 1,
    IDCANCEL,
    IDABORT,
    IDRETRY,
    IDIGNORE,
    IDYES,
    IDNO,
    IDCLOSE,
    IDHELP,
    IDTRYAGAIN,
    IDCONTINUE // = 11
}

uint messageBox(HWND hwnd, string text, string caption, uint flags){ //todo:!!!!!!!!!!!!!! zero terminate strings!!!
  return MessageBoxW(hwnd, text.toUTF16z, caption.toUTF16z, flags);
}

void showMessage(string text){
  messageBox(null, text, "", MB_OK);
}

// browseForFolder /////////////////////////////////////////////////////////////////////////


extern (Windows) int _browseCallback(HWND hwnd, uint uMsg, LPARAM lParam, LPARAM lpData){
  switch(uMsg){
    case BFFM_INITIALIZED:{
      if(lpData)
        SendMessage(hwnd, BFFM_SETSELECTION, 1, lpData);
    break;}
    default:
  }
  return 0;
}

Path browseForFolder(HWND hwnd, string title, Path foldr){
  Path res;
  BROWSEINFO bi;
  with(bi){
    hwndOwner = hwnd;
    pszDisplayName = cast(wchar*)toPWChar(title);
    lpszTitle = toPWChar(title);
    ulFlags = BIF_RETURNONLYFSDIRS;
    lpfn = &_browseCallback;
    lParam = cast(LPARAM)toPWChar(foldr.dir);
  }
  auto itemIDList = SHBrowseForFolder(&bi);
  if(itemIDList){
    wchar[MAX_PATH] str;
    if(SHGetPathFromIDList(itemIDList, str.ptr)){
      res.dir = toStr(str.ptr);
    }
    CoTaskMemFree(itemIDList);
  }
  return res;
}

class FileDialog{ // FileDialog /////////////////////////////////////////////////////////////////////////
  HWND owner;
  string what;       //the name of the thing. Title is auto-generated.
  string defaultExt; //up to 3 letters without leading '.'
  string filter;     //in custom format. See -> processExtFilter()
  Path initialPath;

  this(HWND owner_, string what_, string defaultExt_, string filter_, Path initialPath_ = Path.init){
    //bah... this sucks in D
    owner = owner_;
    what = what_;
    defaultExt = defaultExt_;
    filter = filter_;
    initialPath = initialPath_;
  }


  auto open     (File fileName=File.init) { return File  (getFileName(GetFileNameMode.Open     , owner, what, fileName.fullName, defaultExt, filter, initialPath.dir)); }
  auto openMulti(File fileName=File.init) { return toList(getFileName(GetFileNameMode.OpenMulti, owner, what, fileName.fullName, defaultExt, filter, initialPath.dir)); }
  auto saveAs   (File fileName=File.init) { return File  (getFileName(GetFileNameMode.SaveAs   , owner, what, fileName.fullName, defaultExt, filter, initialPath.dir)); }
  auto renameTo (File fileName=File.init) { return File  (getFileName(GetFileNameMode.RenameTo , owner, what, fileName.fullName, defaultExt, filter, initialPath.dir)); }

private:
  enum GetFileNameMode {Open, OpenMulti, Save, SaveAs, RenameTo}

  static private string getFileName(GetFileNameMode mode, HWND owner, string what, string fileName, string defaultExt, string filter, string initialDir){
    import core.sys.windows.commdlg;

    bool isOpen = mode==GetFileNameMode.Open || mode==GetFileNameMode.OpenMulti;
    bool isMulti = mode==GetFileNameMode.OpenMulti;

    OPENFILENAMEW ofn;
    ofn.hwndOwner = owner;
    ofn.Flags = OFN_FILEMUSTEXIST | OFN_OVERWRITEPROMPT | OFN_EXPLORER ;
    if(isMulti) ofn.Flags |= OFN_ALLOWMULTISELECT ;

    //filename
    wchar[0x4000] fileStr;
    fileStr[] = 0;
    fileStr[0..fileName.length] = fileName.to!wstring[];
    ofn.lpstrFile = fileStr.ptr;
    ofn.nMaxFile = fileStr.length;

    //initialDir
    ofn.lpstrInitialDir = initialDir.to!wstring.ptr; //todo:!!!!!!!!!!!!!! zero terminate strings!!!

    //filter
    filter = processExtFilter(filter, true);
    ofn.lpstrFilter = filter.to!wstring.ptr;    //todo:!!!!!!!!!!!!!! zero terminate strings!!!
    uint filterHash = xxh(filter);
    string filterIniEntry = format("FileFilterIndex%8x", filterHash);
    ofn.nFilterIndex = ini.read(filterIniEntry, "1").to!int;

    //default ext
    ofn.lpstrDefExt = defaultExt.to!wstring.ptr;

    //title
    string title;
    if(what!=""){
      string fn = File(fileName).name;
      if(fn!="") fn = `"`~fn~`"`;

      with(GetFileNameMode) final switch(mode){
        case Open       : title = "Open "~what; break;
        case OpenMulti  : title = "Open "~what~" (multiple files can be selected)"; break;
        case Save       : title = "Save "~what; break; //this is the first save
        case SaveAs     : title = "Save "~what~` `~fn~` As`; break;
        case RenameTo   : title = "Rename "~what~` `~fn~` To`; break;
      }
      ofn.lpstrTitle = title.toPWChar;
    }

    //execute
    auto res = isOpen ? GetOpenFileNameW(&ofn)
                      : GetSaveFileNameW(&ofn);

    string err = checkCommDlgError(res);
    bool ok = err=="";

    //save filterIndex
    ini.write(filterIniEntry, ofn.nFilterIndex.to!string);

    if(err=="CDERR_CANCEL") fileName = err = ""; //cancel is no error, but empty fileName

    //check errors
    enforce(err=="", "FileDialog.getFileName(): "~err);

    //read back filename
    if(ok){
      if(isMulti){ //extract the whole double zero terminated string
        int zcnt=0;
        foreach(ch; fileStr){
          if(ch) zcnt=0; else zcnt++;
          if(zcnt==2)break;
          fileName ~= ch;
        }
        if(!fileName.empty) fileName = fileName[0..$-1]; //remove last '\0', make it az a zero separated list.
      }else{
        fileName = ofn.lpstrFile.to!string;
      }
    }else{
      fileName="";
    }

    return fileName;
  }

  auto toList(string s){
    //converts zero separated list from the form [basePath,name1,name2...] to [file1,file2...]
    auto list = s.split('\0');
    File[] res;
    res.reserve(list.length-1);

    if(list.length<2) return res;
    foreach(i; 1..list.length)
      res ~= File(list[0], list[i]);
    return res;
  }

}


//utility stuff ///////////////////////////////////////////////////////////////////////////////

/************************************
 * Input special chars: "(" ")" brackets creating groups.
 *                      "," comma separates multiple subgroups inside a group
 * Example input: "All files(Pictures(*.bmp;*.jpg),Sound files(*.wav;*.mp3))"
 * Returns: double zero terminated list of (filterName, filterExtList) pairs later used by getOpenFileName and others.
 */
private string processExtFilter(string filter, bool includeExts){
  void enforce(bool b, lazy string s){ if(!b) .enforce(b, "processExtFilter(): "~s); }

  //test filter=`All Files(Program files(Sources(*.d),Executables(*.exe;*.com;*.bat)),Graphic Files(Bitmaps(*.bmp),Jpeg files(*.jpg;*.jpeg))))`;
  string[] names;
  string[] filterNames, filterExts;
  string act;

  void emit(){
    string a = act.strip;
    if(!a.empty){
      foreach(n; names){
        int idx = cast(int)filterNames.countUntil(n);
        if(idx<0) { filterNames ~= n; filterExts ~= ""; idx = cast(int)filterNames.length-1; }
        if(!filterExts[idx].empty) filterExts[idx] ~= ";";
        filterExts[idx] ~= a;
      }
    }
    //reset act
    act = "";
  }

  foreach(ch; filter){
    switch(ch){
      case '(':
        names ~= act.strip;
        act = "";
      break;
      case ')':
        emit;
        enforce(!names.empty, "too many closing brackets ')'");
        names = names[0..$-1];
      break;
      case ',': case ';':
        emit;
      break;
      default:
        act ~= ch;
    }
  }
  enforce(names.empty, "unclosed brackets");
  enforce(act.strip=="", "garbage at end");

  //combine
  string filterStr;
  foreach(i, n; filterNames){
    if(includeExts) n ~= " ("~filterExts[i].replace(";", " ")~")";
    filterStr ~= n ~ "\0" ~ filterExts[i] ~ "\0";
  }
  filterStr ~= '\0'; //double zero terminate

  //test writeln(filterStr.replace("\0", "\n"));

  return filterStr;
}

private string checkCommDlgError(int res){

  if(res) return ""; //no error

  import core.sys.windows.commdlg, core.sys.windows.cderr;
  auto err = CommDlgExtendedError;

  if(err==0) return "CDERR_CANCEL";

  immutable errorStrs = [
    "CDERR_DIALOGFAILURE",
    "CDERR_FINDRESFAILURE",
    "CDERR_INITIALIZATION",
    "CDERR_LOADRESFAILURE",
    "CDERR_LOADSTRFAILURE",
    "CDERR_LOCKRESFAILURE",
    "CDERR_MEMALLOCFAILURE",
    "CDERR_MEMLOCKFAILURE",
    "CDERR_NOHINSTANCE",
    "CDERR_NOHOOK",
    "CDERR_NOTEMPLATE",
    "CDERR_STRUCTSIZE",
    "FNERR_BUFFERTOOSMALL",
    "FNERR_INVALIDFILENAME",
    "FNERR_SUBCLASSFAILURE"];

  static foreach(e; errorStrs)
    mixin(format(q{if(err==%s) return "%s";}, e, e));

  return "CDERR_UNKNOWN";
}


// chooseColor /////////////////////////////////

RGB8 chooseColor(HWND hwnd, RGB8 color, bool fullOpen){
  import core.sys.windows.commdlg;
  static uint[16] customColors; //todo: save/load ini
  CHOOSECOLOR cc = {
    hwndOwner: hwnd,
    rgbResult: cast(uint)(color.to!RGBA8) & 0xFFFFFF,
    lpCustColors: customColors.ptr,
    Flags: CC_RGBINIT | CC_ANYCOLOR | (fullOpen ? CC_FULLOPEN : 0)
  };
  RGB8 res = color;
  if(ChooseColor(&cc)) res = RGB8(cc.rgbResult);
  return res;
}


// testing /////////////////////////////////

void testDialogs()    {
  print(browseForFolder(null, "title", appPath));

  print(new FileDialog(null, "Dlang source file", ".d", "Sources(*.d)", appPath).open);

  print(chooseColor(null, clBlue, false));
  print(chooseColor(null, clAqua, true ));
}
