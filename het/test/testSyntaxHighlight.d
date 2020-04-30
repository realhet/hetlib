//@exe
//@import c:\d\libs
//@ldc
//@compile -m64 -mcpu=athlon64-sse3 -mattr=+ssse3
//@release
///@debug
//@run $ c:\d\libs\het\utils.d
///@run $ c:\d\libs\het\draw3d.d
///@run $ c:\D\ldc2\import\std\format.d
///@run $ c:\D\ldc2\import\std\uni.d
///@run $ c:\d\libs\het\test\syntaxTestText.d
///@run $ c:\D\ldc2\import\std\datetime\systime.d


import het, het.ui, het.tokenizer;


string transformLeadingSpacesToTabs(string original, int spacesPerTab=2){

  string process(string s){
    s = stripRight(s);
    int cnt;
    string spaces = " ".replicate(spacesPerTab);
    while(s.startsWith(spaces)){
      s = s[spaces.length..$];
      cnt++;
    }
    s = "\t".replicate(cnt) ~ s;
    return s;
  }

  return original.split('\n').map!(s => process(s)).join('\n'); //todo: this is bad for strings
}

struct SyntaxStyle{
  RGB fontColor, bkColor;
  int fontFlags; //1:b, 2:i, 4:u
}

struct SyntaxStyleRow{
  string kindName;
  SyntaxStyle[] formats;
}


//todo: these should be uploaded to the gpu
//todo: from the program this is NOT extendable
immutable syntaxPresetNames =
                   ["Default"                 , "Classic"                              , "C64"                          , "Dark"                    ];
immutable SyntaxStyleRow[] syntaxTable = [
  {"Whitespace"  , [{clBlack  ,clWhite   ,0}, {clVgaYellow      ,clVgaLowBlue   ,0}, {clC64LBlue  ,clC64Blue   ,0}, {0xc7c5c5 ,0x2d2d2d ,0}]},
  {"Selected"    , [{clWhite  ,10841427  ,0}, {clVgaLowBlue     ,clVgaLightGray ,0}, {clC64Blue   ,clC64LBlue  ,0}, {clBlack  ,0xc7c5c5 ,0}]},
  {"FoundAct"    , [{0xFCFDCD ,clBlack   ,0}, {clVgaLightGray   ,clVgaBlack     ,0}, {clC64LGrey  ,clC64Black  ,0}, {clBlack  ,0xffffff ,0}]},
  {"FoundAlso"   , [{clBlack  ,0x78AAFF  ,0}, {clVgaLightGray   ,clVgaBrown     ,0}, {clC64LGrey  ,clC64DGrey  ,0}, {clBlack  ,0xa7a5a5 ,0}]},
  {"NavLink"     , [{clBlue   ,clWhite   ,4}, {clVgaHighRed     ,clVgaLowBlue   ,4}, {clC64Red    ,clC64Blue   ,0}, {0xFF8888 ,0x2d2d2d ,4}]},
  {"Number"      , [{clBlue   ,clWhite   ,0}, {clVgaYellow      ,clVgaLowBlue   ,0}, {clC64Yellow ,clC64Blue   ,0}, {0x008CFA ,0x2d2d2d ,0}]},
  {"String"      , [{clBlue   ,clSkyBlue ,0}, {clVgaHighCyan    ,clVgaLowBlue   ,0}, {clC64Cyan   ,clC64Blue   ,0}, {0x64E000 ,0x283f28 ,0}]},
  {"Keyword"     , [{clNavy   ,clWhite   ,1}, {clVgaWhite       ,clVgaLowBlue   ,1}, {clC64White  ,clC64Blue   ,0}, {0x5C00F6 ,0x2d2d2d ,1}]},
  {"Symbol"      , [{clBlack  ,clWhite   ,0}, {clVgaYellow      ,clVgaLowBlue   ,0}, {clC64Yellow ,clC64Blue   ,0}, {0x00E2E1 ,0x2d2d2d ,0}]},
  {"Comment"     , [{clNavy   ,clYellow  ,2}, {clVgaLightGray   ,clVgaLowBlue   ,2}, {clC64LGrey  ,clC64Blue   ,0}, {0xe64Db5 ,0x442d44 ,2}]},
  {"Directive"   , [{clTeal   ,clWhite   ,0}, {clVgaHighGreen   ,clVgaLowBlue   ,0}, {clC64Green  ,clC64Blue   ,0}, {0x4Db5e6 ,0x2d4444 ,0}]},
  {"Identifier1" , [{clBlack  ,clWhite   ,0}, {clVgaYellow      ,clVgaLowBlue   ,0}, {clC64Yellow ,clC64Blue   ,0}, {0xc7c5c5 ,0x2d2d2d ,0}]},
  {"Identifier2" , [{clGreen  ,clWhite   ,0}, {clVgaHighGreen   ,clVgaLowBlue   ,0}, {clC64LGreen ,clC64Blue   ,0}, {clGreen  ,0x2d2d2d ,0}]},
  {"Identifier3" , [{clTeal   ,clWhite   ,0}, {clVgaHighCyan    ,clVgaLowBlue   ,0}, {clC64Cyan   ,clC64Blue   ,0}, {clTeal   ,0x2d2d2d ,0}]},
  {"Identifier4" , [{clPurple ,clWhite   ,0}, {clVgaHighMagenta ,clVgaLowBlue   ,0}, {clC64Purple ,clC64Blue   ,0}, {0xf040e0 ,0x2d2d2d ,0}]},
  {"Identifier5" , [{0x0040b0 ,clWhite   ,0}, {clVgaBrown       ,clVgaLowBlue   ,0}, {clC64Orange ,clC64Blue   ,0}, {0x0060f0 ,0x2d2d2d ,0}]},
  {"Identifier6" , [{0xb04000 ,clWhite   ,0}, {clVgaHighBlue    ,clVgaLowBlue   ,0}, {clC64LBlue  ,clC64Blue   ,0}, {0xf06000 ,0x2d2d2d ,0}]},
  {"Label"       , [{clBlack  ,0xDDFFEE  ,4}, {clBlack          ,clVgaHighCyan  ,0}, {clBlack     ,clC64Cyan   ,0}, {clBlack  ,0x2d2d2d ,4}]},
  {"Attribute"   , [{clPurple ,clWhite   ,1}, {clVgaHighMagenta ,clVgaLowBlue   ,1}, {clC64Purple ,clC64Blue   ,1}, {0xAAB42B ,0x2d2d2d ,1}]},
  {"BasicType"   , [{clTeal   ,clWhite   ,1}, {clVgaHighCyan    ,clVgaLowBlue   ,1}, {clC64Cyan   ,clC64Blue   ,1}, {clWhite  ,0x2d2d2d ,1}]},
  {"Error"       , [{clRed    ,clWhite   ,4}, {clVgaHighRed     ,clVgaLowBlue   ,4}, {clC64Red    ,clC64Blue   ,0}, {0x00FFEF ,0x2d2dFF ,0}]},
  {"Binary1"     , [{clWhite  ,clBlue    ,0}, {clVgaLowBlue     ,clVgaYellow    ,0}, {clC64Blue   ,clC64Yellow ,0}, {0x2d2d2d ,0x20bCFA ,0}]},
];

mixin(format!"enum SyntaxKind   {%s}"(syntaxTable.map!"a.kindName".join(',')));
mixin(format!"enum SyntaxPreset {%s}"(syntaxPresetNames.join(',')));

__gshared defaultSyntaxPreset = SyntaxPreset.Dark;
__gshared defaultSyntaxFontHeight = 22;

/// Lookup a syntax style and apply it to a TextStyle reference
void applySyntax(ref TextStyle ts, ubyte syntax, SyntaxPreset preset)
in(syntax<syntaxTable.length)
{
  auto fmt = &syntaxTable[syntax].formats[preset];
  ts.fontColor = fmt.fontColor;
  ts.bkColor   = fmt.bkColor;
  ts.bold      = fmt.fontFlags.getBit(0);
  ts.italic    = fmt.fontFlags.getBit(1);
  ts.underline = fmt.fontFlags.getBit(2);
}

/// Shorthand with global default preset
void applySyntax(ref TextStyle ts, ubyte syntax){
  applySyntax(ts, syntax, defaultSyntaxPreset);
}


class CodeRow: Row{ //CodeRow //////////////////////////////////////
  SourceCode code;
  int lineIdx;
  bool measured;

  this(SourceCode code, int lineIdx, ref TextStyle ts){
    super(ts); //this overwrites bkColor

    this.code = code;
    this.lineIdx = lineIdx;
    bkColor = syntaxTable[0].formats[defaultSyntaxPreset].bkColor; //this also

    flags.canWrap = false;

    auto line = code.getLine(lineIdx);
    this.appendCode(line.text, line.syntax, (s){ ts.applySyntax(s); }, ts);

    //empty row height is half
    if(subCells.empty) {
      innerHeight = ts.fontHeight*0.5;
      bkColor = lerp(bkColor, bkColor.l>0x80 ? clWhite : clBlack, 0.0625);
    }
  }

  override void measure(){
    if(measured.chkSet)
      super.measure;
  }

//  void refresh(SyntaxPreset preset = SyntaxPreset.Dark){
    /*bkColor = syntaxTable[0].bkColor;

    cubCells.clear;

    const lineCount  = code.lineCount,
          lineDigits = iCeil(log10(lineCount+1)),
          valid      = lineIdx>=0 && lineIdx<code.lineCount;

    if(valid){
      auto text      = code.getLine     (lineIdx),
           syntax    = code.getSyntax   (lineIdx),
           hierarchy = code.getHierarchy(lineIdx);
    }*/

//      indent = hierarchy.
//  }
}

class CodeColumn : Column { //CodeColumn
  SourceCode code;
  bool measured;
  Drawing cachedDrawing;

  this(SourceCode code){
    auto ts = tsNormal;
    ts.applySyntax(0);
    ts.fontHeight = 22;

    super(ts); //this overwrites bkColor

    auto codeRows = iota(code.lineCount).map!(i => new CodeRow(code, i, ts)).array;

    append(cast(Cell[]) codeRows);
  }

  override void measure(){
    if(measured.chkSet)
      super.measure;
  }

  override void draw(Drawing dr){
    if(0){
      super.draw(dr);
    }else{
      if(cachedDrawing is null){
        cachedDrawing = dr.clone;
        super.draw(cachedDrawing);
      }
      dr.draw(cachedDrawing);
    }
  }
}

class FrmMain: GLWindow { mixin autoCreate; // !FrmMain ////////////////////////////
  SourceCode code;
  CodeColumn codeColumn;

  void reload(){
    auto file = File(application.args(1));
    string text;

    PERF("load, syntaxHighLight", {
      text = file.readText;
    });
    PERF("processLeadingSpaces", {
      text = text.transformLeadingSpacesToTabs;
    });
    PERF("tokenize/syntaxHighlight", {
      code = new SourceCode(text, file);
    });
    PERF("create codeColumn", {
      codeColumn = new CodeColumn(code);
    });
    PERF("codeColumn.measure", {
      codeColumn.measure;
    });

    PERF.report.writeln;

  }

  override void onCreate(){ // create /////////////////////////////////
    reload;
  }

  override void onDestroy(){ // destroy //////////////////////////////
  }

  override void onUpdate(){ // update ////////////////////////////////
    invalidate; //todo: opt
    view.navigate(!im.wantKeys, !im.wantMouse);

    caption = FPS.text;

    with(im) Panel({
      //width = clientWidth;
      //vScroll;

      style.applySyntax(0);
      Row({ style.fontHeight=50; Text("FUCK"); });

      actContainer.append(codeColumn);
    });

    if(inputs.Space.pressed){
      reload;
      foreach(const t; code.tokens[0..10]){
        print(t.line, t.kind);
      }
    }
  }

  override void onPaint(){ // paint //////////////////////////////////////
    dr.clear(clBlack);
    drGUI.clear;

    im.draw(dr);

    //drGUI.glDraw(viewGUI);
    //drGUI.clear;

    drawFpsTimeLine(drGUI);
    /*drGUI.glDraw(viewGUI);*/
  }

}


