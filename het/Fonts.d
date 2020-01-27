module het.fonts;

import het.utils, het.geometry, het.image, het.draw2d;

// plotFont: Simpe vector font //////////////////////////////

enum DrawTextOption{ monoSpace, italic, vertFlip}

struct plotFont{
static:
  enum fontHeight       = 25.0f,
       fontMonoWidth    = 20.0f, //height = 40
       fontYAdjust      = 4.0f;

  float textWidth (float scale, bool monoSpace, string text) {
    if(monoSpace) return text.length*fontMonoWidth                              *scale;
             else return text.map!(ch => charMap[cast(int)ch].gfx.width).sum    *scale;
  }

  float textHeight(float scale, string text) { return fontHeight*scale; }
  V2f textExtent  (float scale, bool monoSpace, string text) { return V2f(textWidth(scale, monoSpace, text), textHeight(scale, text)); }

  void drawText(ref Drawing dr, V2f pos, float scale, bool monoSpace, bool italic, string text, bool vertFlip){
    pos.y += scale*fontYAdjust;
    foreach(ch; text){
      auto cg = charMap[cast(int)ch].gfx;

      foreach(const poly; cg.points)
        foreach(i, const p; poly){
          V2f v = p;
          if(!vertFlip) v.y = fontHeight-v.y;
          if(monoSpace) v.x += (fontMonoWidth-cg.width)*0.5;
          if(italic) v.x += 4 - v.y*0.25;
          dr.lineTo(pos+v*scale, i==0);
        }

      pos.x += (monoSpace ? fontMonoWidth : cg.width)*scale;
    }
  }

  auto drawTextStrokes(V2f pos, string text, float scale=1, DrawTextOption[] options=[]){
    V2f[][] res;    //todo: refactor this funct
    pos.y += scale*fontYAdjust;

    const monoSpace = options.canFind(DrawTextOption.monoSpace);
    const italic    = options.canFind(DrawTextOption.italic   );
    const vertFlip  = options.canFind(DrawTextOption.vertFlip );

    foreach(ch; text){
      auto cg = charMap[cast(int)ch].gfx;

      foreach(const poly; cg.points)
        foreach(i, const p; poly){
          V2f v = p;
          if(!vertFlip) v.y = fontHeight-v.y;
          if(monoSpace) v.x += (fontMonoWidth-cg.width)*0.5;
          if(italic) v.x += 4 - v.y*0.25;

          //exporting it
          if(i==0) res ~= [[]];
          res[$-1] ~= pos+v*scale;
        }

      pos.x += (monoSpace ? fontMonoWidth : cg.width)*scale;
    }
    return res;
  }

  private const(CharRec)*[256] charMap;
  static this(){ //static init
    foreach(ref cr; chars)
      charMap[cast(int)cr.ch] = &cr;

    //set default char for undefinied ones
    foreach(ref m; charMap) if(!m) m = charMap[cast(int)'?'];
  }

  struct CharGfx{ float width; V2f[][] points; }
  struct CharRec{ char ch; CharGfx gfx; }
  //data source: https://hackage.haskell.org/package/plotfont
  //todo: Editor: linkek highlightolasa es raugras.
  const CharRec[] chars =[
        {' ',{16,[]}}
       ,{'!',{10,[[{5,2},{4,1},{5,0},{6,1},{5,2}],[{5,7},{5,21}]]}}
       ,{'"',{16,[[{4,15},{5,16},{6,18},{6,20},{5,21},{4,20},{5,19}],
                    [{10,15},{11,16},{12,18},{12,20},{11,21},{10,20},{11,19}]]}}
       ,{'\'',{10,[[{4,15},{5,16},{6,18},{6,20},{5,21},{4,20},{5,19}]]}}
       ,{'#',{21,[[{10,-7},{17,25}],[{11,25},{4,-7}],[{3,6},{17,6}],
                                                 [{18,12},{4,12}]]}}
       ,{'$',{20,[[{3,3},{5,1},{8,0},{12,0},{15,1},{17,3},{17,6}
                    ,{16,8},{15,9},{13,10},{7,12},{5,13},{4,14},{3,16}
                    ,{3,18},{5,20},{8,21},{12,21},{15,20},{17,18}]
                   ,[{12,25},{12,-4}],[{8,-4},{8,25}]]}}
       ,{'%',{24,[[{8,21},{10,19},{10,17},{9,15},{7,14},{5,14}
                    ,{3,16},{3,18},{4,20},{6,21},{8,21},{10,20}
                    ,{13,19},{16,19},{19,20},{21,21},{3,0}]
                   ,[{17,7},{15,6},{14,4},{14,2},{16,0},{18,0}
                    ,{20,1},{21,3},{21,5},{19,7},{17,7}]]}}
       ,{'&',{26,[[{23,2},{23,1},{22,0},{20,0},{18,1},{16,3}
                    ,{11,10},{9,13},{8,16},{8,18},{9,20},{11,21}
                    ,{13,20},{14,18},{14,16},{13,14},{12,13},{5,9}
                    ,{4,8},{3,6},{3,4},{4,2},{5,1},{7,0},{11,0}
                    ,{13,1},{15,3},{17,6},{19,11},{20,13},{21,14}
                    ,{22,14},{23,13},{23,12}]]}}
       ,{'(',{14,[[{11,-7},{9,-5},{7,-2},{5,2},{4,7},{4,11}
                    ,{5,16},{7,20},{9,23},{11,25}]]}}
       ,{')',{14,[[{3,-7},{5,-5},{7,-2},{9,2},{10,7},{10,11}
                    ,{9,16},{7,20},{5,23},{3,25}]]}}
       ,{'*',{16,[[{3,12},{13,18}],[{8,21},{8,9}],[{13,12},{3,18}]]}}
       ,{'+',{26,[[{4,9},{22,9}],[{13,0},{13,18}]]}}
       ,{',',{10,[[{4,-4},{5,-3},{6,-1},{6,1},{5,2},{4,1},{5,0}
                    ,{6,1}]]}}
       ,{'-',{26,[[{4,9},{22,9}]]}}
       ,{'.',{10,[[{5,2},{4,1},{5,0},{6,1},{5,2}]]}}
       ,{'/',{22,[[{2,-7},{20,25}]]}}
       ,{'0',{20,[[{9,21},{6,20},{4,17},{3,12},{3,9},{4,4},{6,1}
                    ,{9,0},{11,0},{14,1},{16,4},{17,9},{17,12}
                    ,{16,17},{14,20},{11,21},{9,21}]]}}
       ,{'1',{20,[[{6,17},{8,18},{11,21},{11,0}]]}}
       ,{'2',{20,[[{4,16},{4,17},{5,19},{6,20},{8,21},{12,21}
                    ,{14,20},{15,19},{16,17},{16,15},{15,13}
                    ,{13,10},{3,0},{17,0}]]}}
       ,{'3',{20,[[{3,4},{4,2},{5,1},{8,0},{11,0},{14,1}
                    ,{16,3},{17,6},{17,8},{16,11},{15,12},{13,13}
                    ,{10,13},{16,21},{5,21}]]}}
       ,{'4',{20,[[{13,0},{13,21},{3,7},{18,7}]]}}
       ,{'5',{20,[[{3,4},{4,2},{5,1},{8,0},{11,0},{14,1}
                    ,{16,3},{17,6},{17,8},{16,11},{14,13},{11,14}
                    ,{8,14},{5,13},{4,12},{5,21},{15,21}]]}}
       ,{'6',{20,[[{4,7},{5,10},{7,12},{10,13},{11,13},{14,12}
                    ,{16,10},{17,7},{17,6},{16,3},{14,1},{11,0}
                    ,{10,0},{7,1},{5,3},{4,7},{4,12},{5,17}
                    ,{7,20},{10,21},{12,21},{15,20},{16,18}]]}}
       ,{'7',{20,[[{3,21},{17,21},{7,0}]]}}
       ,{'8',{20,[[{8,21},{5,20},{4,18},{4,16},{5,14},{7,13}
                    ,{11,12},{14,11},{16,9},{17,7},{17,4},{16,2}
                    ,{15,1},{12,0},{8,0},{5,1},{4,2},{3,4}
                    ,{3,7},{4,9},{6,11},{9,12},{13,13},{15,14}
                    ,{16,16},{16,18},{15,20},{12,21},{8,21}]]}}
       ,{'9',{20,[[{4,3},{5,1},{8,0},{10,0},{13,1},{15,4}
                    ,{16,9},{16,14},{15,18},{13,20},{10,21}
                    ,{9,21},{6,20},{4,18},{3,15},{3,14},{4,11}
                    ,{6,9},{9,8},{10,8},{13,9},{15,11},{16,14}]]}}
       ,{':',{10,[[{5,2},{4,1},{5,0},{6,1},{5,2}],
                    [{5,14},{4,13},{5,12},{6,13},{5,14}]]}}
       ,{';',{10,[[{4,-4},{5,-3},{6,-1},{6,1},{5,2},{4,1}
                    ,{5,0},{6,1}],[{5,14},{4,13},{5,12},{6,13}
                                          ,{5,14}]]}}
       ,{'<',{24,[[{20,0},{4,9},{20,18}]]}}
       ,{'=',{26,[[{4,6},{22,6}],[{22,12},{4,12}]]}}
       ,{'>',{24,[[{4,0},{20,9},{4,18}]]}}
       ,{'?',{18,[[{3,16},{3,17},{4,19},{5,20},{7,21},{11,21}
                    ,{13,20},{14,19},{15,17},{15,15},{14,13}
                    ,{13,12},{9,10},{9,7}]
                   ,[{9,2},{8,1},{9,0},{10,1},{9,2}]]}}
       ,{'@',{27,[[{11,5},{10,6},{9,8},{9,11},{10,14},{12,16}]
                  ,[{18,13},{17,15},{15,16},{12,16},{10,15},{9,14}
                   ,{8,11},{8,8},{9,6},{11,5},{14,5},{16,6}
                   ,{17,8}],[{19,5},{18,6},{18,8},{19,16}]
                  ,[{18,16},{17,8},{17,6},{19,5},{21,5},{23,7}
                   ,{24,10},{24,12},{23,15},{22,17},{20,19}
                   ,{18,20},{15,21},{12,21},{9,20},{7,19}
                   ,{5,17},{4,15},{3,12},{3,9},{4,6},{5,4}
                   ,{7,2},{9,1},{12,0},{15,0},{18,1},{20,2},{21,3}]]}}
       ,{'A',{18,[[{1,0},{9,21},{17,0}],[{14,7},{4,7}]]}}
       ,{'B',{21,[[{4,11},{13,11},{16,10},{17,9},{18,7},{18,4}
                    ,{17,2},{16,1},{13,0},{4,0},{4,21},{13,21}
                    ,{16,20},{17,19},{18,17},{18,15},{17,13}
                    ,{16,12},{13,11}]]}}
       ,{'C',{21,[[{18,5},{17,3},{15,1},{13,0},{9,0},{7,1}
                    ,{5,3},{4,5},{3,8},{3,13},{4,16},{5,18}
                    ,{7,20},{9,21},{13,21},{15,20},{17,18},{18,16}]]}}
       ,{'D',{21,[[{4,0},{4,21},{11,21},{14,20},{16,18},{17,16}
                    ,{18,13},{18,8},{17,5},{16,3},{14,1},{11,0},{4,0}]]}}
       ,{'E',{19,[[{4,11},{12,11}],[{17,21},{4,21},{4,0},{17,0}]]}}
       ,{'F',{18,[[{12,11},{4,11}],[{4,0},{4,21},{17,21}]]}}
       ,{'G',{21,[[{13,8},{18,8},{18,5},{17,3},{15,1},{13,0}
                    ,{9,0},{7,1},{5,3},{4,5},{3,8},{3,13}
                    ,{4,16},{5,18},{7,20},{9,21},{13,21},{15,20}
                    ,{17,18},{18,16}]]}}
       ,{'H',{22,[[{4,0},{4,21}],[{4,11},{18,11}],[{18,21},{18,0}]]}}
       ,{'I',{8,[[{4,0},{4,21}]]}}
       ,{'J',{16,[[{2,7},{2,5},{3,2},{4,1},{6,0},{8,0},{10,1}
                    ,{11,2},{12,5},{12,21}]]}}
       ,{'K',{21,[[{18,0},{9,12}],[{4,21},{4,0}],[{4,7},{18,21}]]}}
       ,{'L',{17,[[{4,21},{4,0},{16,0}]]}}
       ,{'M',{24,[[{4,0},{4,21},{12,0},{20,21},{20,0}]]}}
       ,{'N',{22,[[{4,0},{4,21},{18,0},{18,21}]]}}
       ,{'O',{22,[[{9,21},{7,20},{5,18},{4,16},{3,13},{3,8}
                    ,{4,5},{5,3},{7,1},{9,0},{13,0},{15,1}
                    ,{17,3},{18,5},{19,8},{19,13},{18,16},{17,18}
                    ,{15,20},{13,21},{9,21}]]}}
       ,{'P',{21,[[{4,0},{4,21},{13,21},{16,20},{17,19},{18,17}
                    ,{18,14},{17,12},{16,11},{13,10},{4,10}]]}}
       ,{'Q',{22,[[{9,21},{7,20},{5,18},{4,16},{3,13},{3,8}
                    ,{4,5},{5,3},{7,1},{9,0},{13,0},{15,1}
                    ,{17,3},{18,5},{19,8},{19,13},{18,16},{17,18}
                    ,{15,20},{13,21},{9,21}],[{12,4},{18,-2}]]}}
       ,{'R',{21,[[{4,0},{4,21},{13,21},{16,20},{17,19},{18,17}
                    ,{18,15},{17,13},{16,12},{13,11},{4,11}]
                   ,[{11,11},{18,0}]]}}
       ,{'S',{20,[[{3,3},{5,1},{8,0},{12,0},{15,1},{17,3}
                    ,{17,6},{16,8},{15,9},{13,10},{7,12},{5,13}
                    ,{4,14},{3,16},{3,18},{5,20},{8,21},{12,21}
                    ,{15,20},{17,18}]]}}
       ,{'T',{16,[[{1,21},{15,21}],[{8,21},{8,0}]]}}
       ,{'U',{22,[[{4,21},{4,6},{5,3},{7,1},{10,0},{12,0}
                    ,{15,1},{17,3},{18,6},{18,21}]]}}
       ,{'V',{18,[[{1,21},{9,0},{17,21}]]}}
       ,{'W',{24,[[{2,21},{7,0},{12,21},{17,0},{22,21}]]}}
       ,{'X',{20,[[{3,0},{17,21}],[{3,21},{17,0}]]}}
       ,{'Y',{18,[[{1,21},{9,11},{9,0}],[{9,11},{17,21}]]}}
       ,{'Z',{20,[[{3,21},{17,21},{3,0},{17,0}]]}}
       ,{'[',{14,[[{5,-7},{5,25}],[{11,25},{4,25},{4,-7},{11,-7}]]}}
       ,{'\\',{22,[[{20,-7},{2,25}]]}}
       ,{']',{14,[[{3,-7},{10,-7},{10,25},{3,25}],[{9,25},{9,-7}]]}}
       ,{'^',{16,[[{2,12},{8,18},{14,12}],[{11,15},{8,19},{5,15}]]}}
       ,{'_',{16,[[{0,-2},{16,-2}]]}}
       ,{'`',{10,[[{5,17},{6,16},{5,15},{4,16},{4,18},{5,20},{6,21}]]}}
       ,{'a',{19,[[{15,0},{15,14}],[{15,11},{13,13},{11,14},{8,14}
                                             ,{6,13},{4,11},{3,8},{3,6},{4,3}
                                             ,{6,1},{8,0},{11,0},{13,1},{15,3}]]}}
       ,{'b',{19,[[{4,11},{6,13},{8,14},{11,14},{13,13},{15,11}
                    ,{16,8},{16,6},{15,3},{13,1},{11,0},{8,0}
                    ,{6,1},{4,3}],[{4,0},{4,21}]]}}
       ,{'c',{18,[[{15,3},{13,1},{11,0},{8,0},{6,1},{4,3},{3,6}
                    ,{3,8},{4,11},{6,13},{8,14},{11,14},{13,13},{15,11}]]}}
       ,{'d',{19,[[{15,11},{13,13},{11,14},{8,14},{6,13},{4,11}
                    ,{3,8},{3,6},{4,3},{6,1},{8,0},{11,0},{13,1}
                    ,{15,3}],[{15,0},{15,21}]]}}
       ,{'e',{18,[[{3,8},{15,8},{15,10},{14,12},{13,13},{11,14}
                    ,{8,14},{6,13},{4,11},{3,8},{3,6},{4,3},{6,1}
                    ,{8,0},{11,0},{13,1},{15,3}]]}}
       ,{'f',{12,[[{2,14},{9,14}],[{10,21},{8,21},{6,20},{5,17}
                                            ,{5,0}]]}}
       ,{'g',{19,[[{6,-6},{8,-7},{11,-7},{13,-6},{14,-5},{15,-2}
                    ,{15,14}],[{15,11},{13,13},{11,14},{8,14},{6,13}
                                  ,{4,11},{3,8},{3,6},{4,3},{6,1},{8,0}
                                  ,{11,0},{13,1},{15,3}]]}}
       ,{'h',{19,[[{4,21},{4,0}],[{4,10},{7,13},{9,14},{12,14}
                                           ,{14,13},{15,10},{15,0}]]}}
       ,{'i',{8,[[{3,21},{4,20},{5,21},{4,22},{3,21}]
                  ,[{4,14},{4,0}]]}}
       ,{'j',{10,[[{1,-7},{3,-7},{5,-6},{6,-3},{6,14}]
                   ,[{5,21},{6,20},{7,21},{6,22},{5,21}]]}}
       ,{'k',{17,[[{4,21},{4,0}],[{4,4},{14,14}],[{8,8},{15,0}]]}}
       ,{'l',{8,[[{4,0},{4,21}]]}}
       ,{'m',{30,[[{4,0},{4,14}],[{4,10},{7,13},{9,14},{12,14}
                                           ,{14,13},{15,10},{15,0}]
                   ,[{15,10},{18,13},{20,14},{23,14},{25,13}
                    ,{26,10},{26,0}]]}}
       ,{'n',{19,[[{4,0},{4,14}],[{4,10},{7,13},{9,14}
                                           ,{12,14},{14,13},{15,10},{15,0}]]}}
       ,{'o',{19,[[{8,14},{6,13},{4,11},{3,8},{3,6}
                    ,{4,3},{6,1},{8,0},{11,0},{13,1},{15,3}
                    ,{16,6},{16,8},{15,11},{13,13},{11,14},{8,14}]]}}
       ,{'p',{19,[[{4,-7},{4,14}],[{4,11},{6,13},{8,14}
                                            ,{11,14},{13,13},{15,11}
                                            ,{16,8},{16,6},{15,3},{13,1}
                                            ,{11,0},{8,0},{6,1},{4,3}]]}}
       ,{'q',{19,[[{15,-7},{15,14}],[{15,11},{13,13},{11,14}
                                              ,{8,14},{6,13},{4,11},{3,8}
                                              ,{3,6},{4,3},{6,1},{8,0}
                                              ,{11,0},{13,1},{15,3}]]}}
       ,{'r',{13,[[{4,0},{4,14}]
                   ,[{4,8},{5,11},{7,13},{9,14},{12,14}]]}}
       ,{'s',{17,[[{3,3},{4,1},{7,0},{10,0},{13,1}
                    ,{14,3},{14,4},{13,6},{11,7},{6,8},{4,9}
                    ,{3,11},{4,13},{7,14},{10,14},{13,13}
                    ,{14,11}]]}}
       ,{'t',{12,[[{9,14},{2,14}],[{5,21},{5,4},{6,1}
                                            ,{8,0},{10,0}]]}}
       ,{'u',{19,[[{4,14},{4,4},{5,1}
                    ,{7,0},{10,0},{12,1},{15,4}],[{15,0},{15,14}]]}}
       ,{'v',{16,[[{2,14},{8,0},{14,14}]]}}
       ,{'w',{22,[[{3,14},{7,0},{11,14},{15,0},{19,14}]]}}
       ,{'x',{17,[[{3,0},{14,14}],[{3,14},{14,0}]]}}
       ,{'y',{16,[[{2,14},{8,0}],[{1,-7},{2,-7},{4,-6}
                                           ,{6,-4},{8,0},{14,14}]]}}
       ,{'z',{17,[[{3,14},{14,14},{3,0},{14,0}]]}}
       ,{'{',{14,[[{7,-6},{6,-4},{6,-2},{7,0},{8,1}
                    ,{9,3},{9,5},{8,7},{4,9},{8,11}
                    ,{9,13},{9,15},{8,17},{7,18},{6,20}
                    ,{6,22},{7,24}]
                   ,[{9,25},{7,24},{6,23},{5,21},{5,19},{6,17}
                    ,{7,16},{8,14},{8,12},{6,10}]
                   ,[{6,8},{8,6},{8,4},{7,2},{6,1},{5,-1}
                    ,{5,-3},{6,-5},{7,-6},{9,-7}]]}}
       ,{'|',{8,[[{4,-7},{4,25}]]}}
       ,{'}',{14,[[{5,-7},{7,-6},{8,-5},{9,-3},{9,-1}
                    ,{8,1},{7,2},{6,4},{6,6},{8,8}]
                   ,[{8,10},{6,12},{6,14},{7,16},{8,17}
                    ,{9,19},{9,21},{8,23},{7,24},{5,25}]
                   ,[{7,24},{8,22},{8,20},{7,18},{6,17}
                    ,{5,15},{5,13},{6,11},{10,9},{6,7}
                    ,{5,5},{5,3},{6,1},{7,0},{8,-2}
                    ,{8,-4},{7,-6}]]}}
       ,{'~',{24,[[{3,6},{3,8},{4,11},{6,12},{8,12}
                    ,{10,11},{14,8},{16,7},{18,7},{20,8}
                    ,{21,10}]
                   ,[{21,12},{21,10},{20,7},{18,6},{16,6}
                    ,{14,7},{10,10},{8,11},{6,11},{4,10},{3,8}]]}}
       ];
}

// GDI Font /////////////////////////////////

enum FontQuality {standard, smooth, clearType}

class GDIFont{
import core.runtime,
       core.sys.windows.windows,
       core.sys.windows.windef,
       core.sys.windows.winuser,
       core.sys.windows.wingdi,
       core.sys.windows.wincon,
       core.sys.windows.mmsystem;
private:
  string fontName;
  int height;
  bool clearType;

  HFONT hFont;
  HBITMAP hBitmap;
  HDC hdcMem;
  SIZE siz;
  BITMAPINFO bmi;


  void D2D_CreateRederTarget(){ // Create a DC render target.
  }

public:
  bool isCompatible(string fontName, int height, bool clearType){
    return this.fontName ==fontName
        && this.height   ==height
        && this.clearType==clearType;
  }

  this(string fontName, int height, bool clearType){
    this.fontName =fontName;
    this.height   =height;
    this.clearType=clearType;

    enum CLEARTYPE_QUALITY = 5;
    const quality = clearType ? CLEARTYPE_QUALITY : ANTIALIASED_QUALITY;

    hFont = CreateFontA(height, 0/*width*/, 0/*escapement*/, 0/*orientation*/, FW_NORMAL/*weight*/,
                        0/*italic*/, 0/*underline*/, 0/*strikeOut*/,
                        DEFAULT_CHARSET, OUT_OUTLINE_PRECIS, CLIP_DEFAULT_PRECIS, quality, DEFAULT_PITCH, cast(LPCSTR)fontName.ptr);

    HDC hdc = GetDC(null);
    hdcMem = CreateCompatibleDC(hdc);
    SelectObject(hdcMem, hFont);

    // get the size of "W"
    GetTextExtentPoint32(hdcMem, "W", 1, &siz);

    siz.cx = nearest2NSize(siz.cx*2); //must be enought for anything
    siz.cy = nearest2NSize(siz.cy);
    hBitmap = CreateCompatibleBitmap(hdc, siz.cx, siz.cy);

    COLORREF bkcolor = 0x00000000;
    COLORREF color   = 0x00ffffff;

    SetBkColor(hdcMem, bkcolor);
    SetTextColor(hdcMem, color);

    SelectObject(hdcMem, hBitmap);

    //"font.created".writeln;

    getUnicodeRanges;
  }

  void getUnicodeRanges(){  //this is useless. it gets the complete range
fontName.writeln;

    ubyte[] buf;
    buf.length = GetFontUnicodeRanges(hdcMem, null);
    if(buf.length<GLYPHSET.sizeof) return;
    auto gs = cast(GLYPHSET*)buf.ptr;
    GetFontUnicodeRanges(hdcMem, gs);

    if(gs.flAccel|GS_8BIT_INDICES){
      auto ranges = gs.ranges.ptr[0..gs.cRanges];
      foreach(int idx, r; ranges){
        "%4d %.4X:%.4X".writefln(idx, r.wcLow, r.wcLow+r.cGlyphs-1);
      }
    }else{
      enforce(false, "not impl");
    }

    File(`c:\dl\`~fontName~` glyphset.dat`).write(buf);
  }

  void d2dDrawChar() {
/*    std::auto_ptr<TDirect2DCanvas> pCanvas(new TDirect2DCanvas(hDC, TRect(0, 0, ClientWidth, ClientHeight)));

    // configure Direct2D font
    pCanvas->Font->Size        = 40;
    pCanvas->Font->Name        = L"Segoe UI Emoji";
    pCanvas->Font->Orientation = 0;
    pCanvas->Font->Pitch       = System::Uitypes::TFontPitch::fpVariable;
    pCanvas->Font->Style       = TFontStyles();

    // get DirectWrite text format object
    _di_IDWriteTextFormat pFormat = pCanvas->Font->Handle;

    if (!pFormat)
        return;

    pCanvas->RenderTarget->SetTextAntialiasMode(D2D1_TEXT_ANTIALIAS_MODE_CLEARTYPE);

    ::D2D1_COLOR_F color;
    color.r = 0.0f;
    color.g = 0.0f;
    color.b = 0.0f;
    color.a = 1.0f;

    ::ID2D1SolidColorBrush* pBrush = NULL;

    // create solid color brush, use pen color if rect is completely filled with outline
    pCanvas->RenderTarget->CreateSolidColorBrush(color, &pBrush);

    if (!pBrush)
        return;

    // set horiz alignment
    pFormat->SetTextAlignment(DWRITE_TEXT_ALIGNMENT_LEADING);

    // set vert alignment
    pFormat->SetParagraphAlignment(DWRITE_PARAGRAPH_ALIGNMENT_NEAR);

    // set reading direction
    pFormat->SetReadingDirection(DWRITE_READING_DIRECTION_LEFT_TO_RIGHT);

    // set word wrapping mode
    pFormat->SetWordWrapping(DWRITE_WORD_WRAPPING_NO_WRAP);

    IDWriteInlineObject* pInlineObject = NULL;

    ::DWRITE_TRIMMING trimming;
    trimming.delimiter      = 0;
    trimming.delimiterCount = 0;
    trimming.granularity    = DWRITE_TRIMMING_GRANULARITY_NONE;

    // set text trimming
    pFormat->SetTrimming(&trimming, pInlineObject);

    pCanvas->BeginDraw();

    pCanvas->RenderTarget->DrawText(text.c_str(), text.length(), pFormat, textRect, pBrush,
                D2D1_DRAW_TEXT_OPTIONS_ENABLE_COLOR_FONT);

    pCanvas->EndDraw(); */
  }

  auto drawChar(dchar ch){
    auto s = cast(wchar[])([ch].toUTF16);

    SIZE siz; GetTextExtentPoint32W(hdcMem, s.ptr, cast(int)s.length, &siz);


    TextOutW(hdcMem, 0, 0, s.ptr, cast(int)s.length);

    auto img = new Image!RGBA8(siz.cx, siz.cy);

    with(bmi.bmiHeader){
      biSize        = BITMAPINFOHEADER.sizeof;
      biWidth       = siz.cx;
      biHeight      = -siz.cy;
      biPlanes      = 1;
      biBitCount    = 32;
      biCompression = BI_RGB;
      biSizeImage   = siz.cx*siz.cy*4;
    }
    if(!GetDIBits(hdcMem, hBitmap, 0, siz.cy, img.data.ptr, &bmi, DIB_RGB_COLORS)){
      //error handling not needed...
    }

    //todo: color font renderer (possibly Direct2D)
    foreach(ref p; img.data) p.a = ((p.r+p.g+p.b)*85)>>8; //alpha = rgb average. can be used as grayscale
    return new Bitmap(img);
  }

  ~this(){
    DeleteObject(hFont);
    DeleteObject(hBitmap);
    DeleteDC(hdcMem);

    //"font.freed".writeln;
  }
}

private __gshared GDIFont actGDIFont;

auto renderFont(dchar[] str, string fontName, int height, bool clearType){
  //remove if incompatible
  if(actGDIFont && !actGDIFont.isCompatible(fontName, height, clearType)) actGDIFont.free;

  if(!actGDIFont) actGDIFont = new GDIFont(fontName, height, clearType);

  Bitmap[] res;
  foreach(ch; str) res ~= actGDIFont.drawChar(ch);

  return res;
}

auto renderFont(dchar ch, string fontName, int height, bool clearType){
  return renderFont([ch], fontName, height, clearType)[0];
}



// Programming-font : DEPRECATED //////////////////////////////

/+
//todo: unicode support
/*struct CharRange{
  int low, high;
  string comment;
}

const CharRange[] supportedCharRanges = [
  {0x0020, 0x0080, "Basic Latin"},
  {0x00A0, 0x0100, "Latin-1 Supplement"},
  {0x0100, 0x0180, "Latin Extended-A"},
  {0x0180, 0x0240, "Latin Extended-B"},
  {0x0370, 0x0400, "Greek and Coptic"},
  {0x0400, 0x0500, "Cyrillic"},
  {0x0500, 0x0530, "Cyrillic Supplement"},
  {0x16A0, 0x1700, "Runic"},
  {0x1C80, 0x1C90, "Cyrillic Extended C"},
  {0xA640, 0xA6A0, "Cyrillic Extended B"},
];
//static this(){ supportedCharRanges.map!(a => a.high-a.low).sum.writeln; }\
*/

struct array2D(T){
  private int w, h;
  T[] data;

  @property width () const { return w; }
  @property height() const { return h; }
  @property size  () const { return w*h; }

  void resize(int width_, int height_){
    w = width_;
    h = height_;
    data = uninitializedArray!(T[])(size);
  }

  this(int width_,  int height_){
    resize(width_, height_);
  }

  T* scanLine(int y){ return &data[y*w]; }
}

void createFontMap(string[] fontNames, int cellW, int cellH, int rowSize, int numChars) {
  import core.sys.windows.windows, core.sys.windows.wingdi;

  auto t0=QPS;

  int w = cellW*rowSize*cast(int)fontNames.length,
      numRows = nearest2NSize((numChars+rowSize-1)/rowSize),
      h = cellH*numRows;

  HDC hdcScreen = GetDC(null); // Get a device context to the screen.
  scope(exit) ReleaseDC(null, hdcScreen);

  HDC hdcBmp = CreateCompatibleDC(hdcScreen); // Create a device context
  scope (exit) DeleteDC(hdcBmp);

  // Create a bitmap and attach it to the device context we created above...
  HBITMAP bmp = CreateCompatibleBitmap(hdcScreen, w, h);
  scope(exit) DeleteObject(bmp);

  SelectObject(hdcBmp, bmp); //throw away previous object

  // Now, you can draw into bmp using the device context hdcBmp...
//  RECT r = {0, 0, w, h};
//  FillRect(hdcBmp, &r, cast(HBRUSH)GetStockObject(BLACK_BRUSH));

//  r = RECT(10, 10, 50, 100);
//  FillRect(hdcBmp, &r, cast(HBRUSH)GetStockObject(BLACK_BRUSH));

   //NONANTIALIASED_QUALITY = 0x03,
   //ANTIALIASED_QUALITY = 0x04,

  foreach(int fontIdx, fontName; fontNames){

    enum CLEARTYPE_QUALITY = 0x05;

    const quality = ANTIALIASED_QUALITY;
    auto hFont = CreateFontA(cellH, 0, 0, 0, FW_NORMAL, FALSE, FALSE, FALSE, ANSI_CHARSET, OUT_DEFAULT_PRECIS, CLIP_DEFAULT_PRECIS, quality, 0, toStringz(fontName));
    scope(exit) DeleteObject(hFont);

    SelectObject(hdcBmp, hFont);

    SetBkColor(hdcBmp, 0);
    SetTextColor(hdcBmp, 0xFFFFFF);

    foreach(x; 0..rowSize) foreach(y; 0..numRows){
      auto ch = cast(wchar)(x+y*rowSize);

      float yDelta = 0;

      if(ch == 3) yDelta = 0.18;
      if(ch == 4) yDelta = 0.38;

      const specials = [
        0xFFFD, // <?>
        0x2026, // ...
        0x2015, // strikeout -
        0x2026, // ... down
        0x2015, // single _
        0x2017, // double _
        0x2714, // handwritten pipe
        0x2718, // handwritten X
        0x2591, // 25% gradient
        0x2592, // 50% gradient
        0x2593, // 75% gradient


        //deck symbols
        0x23f4, // play left
        0x23f5, // play
        0x23f6, // play up
        0x23f7, // play dn
        0x23f8, // pause
        0x23f9, // stop
        0x23fA, // rec

        //french cards
        0x2665,
        0x2666,
        0x2660,
        0x2663,

        //music symbols
        0x266a,
        0x266b,
        0x266d,
        0x266f,

        /+these are too wide

        //weather
        0x2600,
        0x2601,
        0x2602,
        0x2603,

        0x2610, // [ ]
        0x2611, // [p] pipe
        0x2612, // [x]
        +/

      ];

      if(ch>=0 && ch<specials.length) ch = cast(wchar)specials[ch];

      SIZE size;
      GetTextExtentPoint32(hdcBmp, &ch, 1, &size);

      if(ch=='W') size.writeln;

      TextOutW(hdcBmp, fontIdx*cellW*rowSize + x*cellW + max(0, (cellW-size.cx)/2), y*cellH + iRound(cellH*yDelta), &ch, 1);
    }
  }

  // etc...

// Get the BITMAP from the HBITMAP
  BITMAPFILEHEADER   bmfHeader;
  BITMAPINFOHEADER   bi;

  bi.biSize = bi.sizeof;
  bi.biWidth = w;
  bi.biHeight = h;
  bi.biPlanes = 1;
  bi.biBitCount = 32;
  bi.biCompression = BI_RGB;
  bi.biSizeImage = 0;
  bi.biXPelsPerMeter = 0;
  bi.biYPelsPerMeter = 0;
  bi.biClrUsed = 0;
  bi.biClrImportant = 0;

  int dwBmpSize = ((w * bi.biBitCount + 31) / 32) * 4 * h;

  // Starting with 32-bit Windows, GlobalAlloc and LocalAlloc are implemented as wrapper functions that
  // call HeapAlloc using a handle to the process's default heap. Therefore, GlobalAlloc and LocalAlloc
  // have greater overhead than HeapAlloc.
  HANDLE hDIB = GlobalAlloc(GHND, dwBmpSize);
  scope(exit) GlobalFree(hDIB);

  ubyte* lpbitmap = cast(ubyte*)GlobalLock(hDIB);
  scope(exit) GlobalUnlock(hDIB);

  // Gets the "bits" from the bitmap and copies them into a buffer
  // which is pointed to by lpbitmap.
  GetDIBits(hdcBmp, bmp, 0,
      h,
      lpbitmap,
      cast(BITMAPINFO*)&bi, DIB_RGB_COLORS);

writeln("genFont", QPS-t0);

  // A file is created, this is where we will save the screen capture.
  HANDLE hFile = CreateFile("captureqwsx.bmp",
      GENERIC_WRITE,
      0,
      NULL,
      CREATE_ALWAYS,
      FILE_ATTRIBUTE_NORMAL, NULL);
  scope(exit) CloseHandle(hFile);

  // Add the size of the headers to the size of the bitmap to get the total file size
  DWORD dwSizeofDIB = dwBmpSize + cast(int)(BITMAPFILEHEADER.sizeof + BITMAPINFOHEADER.sizeof);

  //Offset to where the actual bitmap bits start.
  bmfHeader.bfOffBits = BITMAPFILEHEADER.sizeof + BITMAPINFOHEADER.sizeof;

  //Size of the file
  bmfHeader.bfSize = dwSizeofDIB;

  //bfType must always be BM for Bitmaps
  bmfHeader.bfType = 0x4D42; //BM

  DWORD dwBytesWritten = 0;
  WriteFile(hFile, cast(void*)&bmfHeader, BITMAPFILEHEADER.sizeof, &dwBytesWritten, null);
  WriteFile(hFile, cast(void*)&bi, BITMAPINFOHEADER.sizeof, &dwBytesWritten, null);
  WriteFile(hFile, cast(void*)lpbitmap, dwBmpSize, &dwBytesWritten, null);
}

void generateFontMap(){
  createFontMap(["consolas"], 32, 64, 16, 256);
}

+/


