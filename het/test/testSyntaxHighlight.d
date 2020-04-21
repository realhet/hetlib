//@exe
//@import c:\d\libs
//@ldc
//@compile -m64 -mcpu=athlon64-sse3 -mattr=+ssse3
//@release
///@debug
///@run $ c:\d\libs\het\utils.d
//@run $ c:\d\libs\het\draw3d.d

import het, het.ui, het.tokenizer;

struct SyntaxStyle{
  RGB fontColor, bkColor;
  string style; //b,i,u
}

struct SyntaxStyleRow{
  string kindName;
  SyntaxStyle[] formats;
}

immutable syntaxPresetNames =
                   ["Default"                 , "Classic"                              , "C64"                          , "Dark"                    ];
immutable SyntaxStyleRow[] syntaxTable = [
  {"Whitespace"  , [{clBlack  ,clWhite   ,"" }, {clVgaYellow      ,clVgaLowBlue   ,"" }, {clC64LBlue  ,clC64Blue   ,"" }, {0xc7c5c5 ,0x2d2d2d ,"" }]},
  {"Selected"    , [{clWhite  ,10841427  ,"" }, {clVgaLowBlue     ,clVgaLightGray ,"" }, {clC64Blue   ,clC64LBlue  ,"" }, {clBlack  ,0xc7c5c5 ,"" }]},
  {"FoundAct"    , [{0xFCFDCD ,clBlack   ,"" }, {clVgaLightGray   ,clVgaBlack     ,"" }, {clC64LGrey  ,clC64Black  ,"" }, {clBlack  ,0xffffff ,"" }]},
  {"FoundAlso"   , [{clBlack  ,0x78AAFF  ,"" }, {clVgaLightGray   ,clVgaBrown     ,"" }, {clC64LGrey  ,clC64DGrey  ,"" }, {clBlack  ,0xa7a5a5 ,"" }]},
  {"NavLink"     , [{clBlue   ,clWhite   ,"u"}, {clVgaHighRed     ,clVgaLowBlue   ,"u"}, {clC64Red    ,clC64Blue   ,"" }, {0xFF8888 ,0x2d2d2d ,"u"}]},
  {"Number"      , [{clBlue   ,clWhite   ,"" }, {clVgaYellow      ,clVgaLowBlue   ,"" }, {clC64Yellow ,clC64Blue   ,"" }, {0x008CFA ,0x2d2d2d ,"" }]},
  {"String"      , [{clBlue   ,clSkyBlue ,"" }, {clVgaHighCyan    ,clVgaLowBlue   ,"" }, {clC64Cyan   ,clC64Blue   ,"" }, {0x64E000 ,0x283f28 ,"" }]},
  {"Keyword"     , [{clNavy   ,clWhite   ,"b"}, {clVgaWhite       ,clVgaLowBlue   ,"b"}, {clC64White  ,clC64Blue   ,"" }, {0x5C00F6 ,0x2d2d2d ,"b"}]},
  {"Symbol"      , [{clBlack  ,clWhite   ,"" }, {clVgaYellow      ,clVgaLowBlue   ,"" }, {clC64Yellow ,clC64Blue   ,"" }, {0x00E2E1 ,0x2d2d2d ,"" }]},
  {"Comment"     , [{clNavy   ,clYellow  ,"i"}, {clVgaLightGray   ,clVgaLowBlue   ,"i"}, {clC64LGrey  ,clC64Blue   ,"" }, {0xe64Db5 ,0x442d44 ,"i"}]},
  {"Directive"   , [{clTeal   ,clWhite   ,"" }, {clVgaHighGreen   ,clVgaLowBlue   ,"" }, {clC64Green  ,clC64Blue   ,"" }, {0x4Db5e6 ,0x2d4444 ,"" }]},
  {"Identifier1" , [{clBlack  ,clWhite   ,"" }, {clVgaYellow      ,clVgaLowBlue   ,"" }, {clC64Yellow ,clC64Blue   ,"" }, {0xc7c5c5 ,0x2d2d2d ,"" }]},
  {"Identifier2" , [{clGreen  ,clWhite   ,"" }, {clVgaHighGreen   ,clVgaLowBlue   ,"" }, {clC64LGreen ,clC64Blue   ,"" }, {clGreen  ,0x2d2d2d ,"" }]},
  {"Identifier3" , [{clTeal   ,clWhite   ,"" }, {clVgaHighCyan    ,clVgaLowBlue   ,"" }, {clC64Cyan   ,clC64Blue   ,"" }, {clTeal   ,0x2d2d2d ,"" }]},
  {"Identifier4" , [{clPurple ,clWhite   ,"" }, {clVgaHighMagenta ,clVgaLowBlue   ,"" }, {clC64Purple ,clC64Blue   ,"" }, {0xf040e0 ,0x2d2d2d ,"" }]},
  {"Identifier5" , [{0x0040b0 ,clWhite   ,"" }, {clVgaBrown       ,clVgaLowBlue   ,"" }, {clC64Orange ,clC64Blue   ,"" }, {0x0060f0 ,0x2d2d2d ,"" }]},
  {"Identifier6" , [{0xb04000 ,clWhite   ,"" }, {clVgaHighBlue    ,clVgaLowBlue   ,"" }, {clC64LBlue  ,clC64Blue   ,"" }, {0xf06000 ,0x2d2d2d ,"" }]},
  {"Label"       , [{clBlack  ,0xDDFFEE  ,"u"}, {clBlack          ,clVgaHighCyan  ,"" }, {clBlack     ,clC64Cyan   ,"" }, {clBlack  ,0x2d2d2d ,"u"}]},
  {"Attribute"   , [{clPurple ,clWhite   ,"b"}, {clVgaHighMagenta ,clVgaLowBlue   ,"b"}, {clC64Purple ,clC64Blue   ,"b"}, {0xAAB42B ,0x2d2d2d ,"b"}]},
  {"BasicType"   , [{clTeal   ,clWhite   ,"b"}, {clVgaHighCyan    ,clVgaLowBlue   ,"b"}, {clC64Cyan   ,clC64Blue   ,"b"}, {clWhite  ,0x2d2d2d ,"b"}]},
  {"Error"       , [{clRed    ,clWhite   ,"u"}, {clVgaHighRed     ,clVgaLowBlue   ,"u"}, {clC64Red    ,clC64Blue   ,"" }, {0x00FFEF ,0x2d2dFF ,"" }]},
  {"Binary1"     , [{clWhite  ,clBlue    ,"" }, {clVgaLowBlue     ,clVgaYellow    ,"" }, {clC64Blue   ,clC64Yellow ,"" }, {0x2d2d2d ,0x20bCFA ,"" }]},
];

mixin(format!"enum SyntaxKind   {%s}"(syntaxTable.map!"a.kindName".join(',')));
mixin(format!"enum SyntaxPreset {%s}"(syntaxPresetNames.join(',')));


class FrmMain: GLWindow { mixin autoCreate; // !FrmMain ////////////////////////////
  SyntaxResult source;

  override void onCreate(){ // create /////////////////////////////////
    auto file = File(application.args(1));
    enforce(file.exists);

    PERF("load, tokenize, syntaxHighLight", {
      source = syntaxHighLight(file.fullName, file.readText);
    });
    PERF.report.writeln;
  }

  override void onDestroy(){ // destroy //////////////////////////////
  }

  override void onUpdate(){ // update ////////////////////////////////
    invalidate; //todo: opt
    //view.navigate(!im.wantKeys, !im.wantMouse);

    caption = FPS.text;

    with(im) Panel({
      width = clientWidth;
      vScroll;

      auto preset = SyntaxPreset.Dark;

      style.fontHeight = 28;
      style.bkColor = syntaxTable[SyntaxKind.Whitespace].formats[preset].bkColor;

      Text(source.text);

      //apply syntax
      with(actContainer.subCells[$-1]){
        enforce(subCells.length==source.syntax.length);
        foreach(i, glyph; cast(Glyph[])subCells){
          auto fmt = &syntaxTable[source.syntax[i]].formats[preset];
          glyph.fontColor = fmt.fontColor;
          glyph.bkColor   = fmt.bkColor;
          glyph.fontFlags = boolMask(fmt.style.canFind('b'), fmt.style.canFind('i'), fmt.style.canFind('u')); //todo: slow
        }
      }

      //uiContainerAlignTest;

      static s = "Hello\r\nWorld!",
             editWidth = 100;

      /*Row({  Text("Test control  ");  Slider(editWidth, range(1, 300));  });
      Row({  foreach(i; 0..2) Edit(s, id(i), { width = editWidth; style.fontHeight = 40; });  });
      Text(im.textEditorState.dbg);*/

    });

   }

  override void onPaint(){ // paint //////////////////////////////////////
    dr.clear(clSilver);
    drGUI.clear;

    im.draw(drGUI);

    drawFpsTimeLine;
  }

}


