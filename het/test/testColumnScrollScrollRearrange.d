//@exe

//@release
///@debug
///@compile --d-debug

//@compile --d-version longId

import het, het.ui;

struct KarcFileEntry{ // KarcFileEntry //////////////////////////////////////////////
  enum thumbWidth = 72,
       thumbHeight = 36,
       totalPadding = 4;

  Path path;
  DateTime dateTime;
  string single, karc0, karc1; //valid combinations: single, s0, s1, s0+s1

  bool isDirectory() const{ return single.endsWith('\\'); }
  bool isSingle   () const{ return single.length>0; }
  bool isKarc0    () const{ return karc0.length>0; }
  bool isKarc1    () const{ return karc1.length>0; }
  int  karcCnt    () const{ return isKarc0.to!int + isKarc1.to!int; }
  bool isKarc     () const{ return karcCnt>0; }

  void UI(int sensorIdx){ with(im){

    void Thumb(string fn, bool selected, int widthScale){
      Row({
        padding = (totalPadding/2).text;
        innerSize = vec2(thumbWidth*widthScale, thumbHeight);
        if(!selected) bkColor = clWinBackground;
        if(fn=="") return;
        flags.hAlign = HAlign.center;
        if(File(fn).extIs(["jpg"])){
          Text(tag(format!`img "%s?thumb64" height=%s`(path.fullPath~fn, thumbHeight)));
        }else{
          flags.vAlign = VAlign.center;
          Text(isDirectory ? "DIR" : File(fn).ext.uc ~ "\nfile");
        }
      });
    }

    //padding = "2";
    flags.wordWrap = false;
    flags.vAlign = VAlign.center;
    flags.yAlign = YAlign.center;
    innerHeight = thumbHeight + totalPadding;

    if(isKarc){
      if(karcCnt==2){
        Thumb(karc0, sensorIdx==0, 1);
        Thumb(karc1, sensorIdx==1, 1);
        Spacer;
        Text(File(karc0).nameWithoutExt[0..$-1], "0,1");
      }else{
        Thumb(karc0, isKarc0, 1);
        Thumb(karc1, isKarc1, 1);
        Spacer;
        Text(File(isKarc0 ? karc0 : karc1).nameWithoutExt);
      }
    }else if(isSingle){
      Thumb(single, true, 2);
      Spacer;
      if(isDirectory){
        style.bold = true; Text(single);
      }else{
        Text(File(single).nameWithoutExt);
      }

    }
  }}


}

class KarcFileBrowser{ // KarcFileBrowser ////////////////////////////////////////
  Path path;

  bool mustRefresh;
  Path updatedPath;
  KarcFileEntry[] items;

  int selectedIdx = -1;
  int sensorIdx = 0;

  float maxWidth = 0; //this must cleared when items changed

  void update(){
    if(mustRefresh || path != updatedPath){
      updatedPath = path;
      mustRefresh = false;
      maxWidth = 0;

      auto files = listFiles(updatedPath, "*.jpg", "name", Yes.onlyFiles);
      items.clear;

      while(!files.empty) with(files.front){
        if(name.isWild("*_S0.*")){
          items ~= KarcFileEntry(path, DateTime(ftLastWriteTime), "", name);
          files.popFront;
          if(files.length) with(files.front) if(name.isWild(items[$-1].karc0.replace("_S0.", "_S1."))){
            items[$-1].karc1 = name;
            files.popFront;
          }
        }else if(name.isWild("*_S1.*")){
          items ~= KarcFileEntry(path, DateTime(ftLastWriteTime), "", "", name);
          files.popFront;
        }else{
          if(!isDirectory) items ~= KarcFileEntry(path, DateTime(ftLastWriteTime), name ~ (isDirectory ? `\` : ``));
          files.popFront;
        }
      }

      items = items.sort!((in a,in b) => a.dateTime > b.dateTime).array;
    }
  }

  auto UI_path(){
    bool clicked;

    update;
    if(im.EditPath(path, this.genericId)) mustRefresh = clicked = true;

    return clicked;
  }

  auto UI_browser(){
    bool clicked;

    update;
    with(im) Container(this.genericId, {
      margin = "2";
      border = "1 normal gray";
      innerWidth = 400;
      flex = 1; //It is vertical flex
      //innerHeight = 500;
      bkColor = clWinBackground;

      const rowHeight = KarcFileEntry.thumbHeight + KarcFileEntry.totalPadding;

      const totalHeight = rowHeight*items.length;

      //size placeholder
      Container({ outerSize = vec2(0); outerPos = vec2(maxWidth, totalHeight); });

      with(flags){
        clipChildren = true;
        vScrollState = ScrollState.auto_;
        wordWrap = false;
        hScrollState = ScrollState.auto_;
      }

      flags.saveVisibleBounds = true;
      auto visibleBounds = imstVisibleBounds(actId);

      if(visibleBounds.height>0 && items.length){
        int st = clamp((visibleBounds.top   /rowHeight).ifloor,  0, items.length.to!int-1);
        int en = clamp((visibleBounds.bottom/rowHeight).iceil , st, items.length.to!int-1);

        foreach(idx;  st..en+1){
          auto selected(){ return idx==selectedIdx; }

          Row(genericId(idx), {
            auto hit = hitTest(true/*enabled*/);
            if(/*!selected && */hit.hover && (inputs.LMB.pressed || inputs.RMB.pressed)){
              selectedIdx = idx; //mosue down left or right
              clicked = true;
              with(items[selectedIdx]) if(isKarc){
                if(karcCnt==2){
                  //todo: this mouse getting thing is fucking lame. actMousePos should be accessible at all times, and flags.targetSurface should be inherited.
                  const clientMouseX = im.actView.mousePos.x - hit.hitBounds.left - actContainer.topLeftGapSize.x,
                        thumbOuterWidth = KarcFileEntry.thumbWidth + KarcFileEntry.totalPadding,
                        thumbIdx = (clientMouseX / thumbOuterWidth).ifloor;
                  if(thumbIdx.inRange(0, 1)){
                    sensorIdx = thumbIdx;
                  }
                }else{
                  sensorIdx = isKarc0 ? 0 : 1;
                }
              }
            }
            style.bkColor = bkColor = mix(bkColor, clAccent, max(selected ? .5f:0, hit.hover_smooth*.25f));

            items[idx].UI(sensorIdx);
          });

          with(lastContainer){
            measure;
            outerPos.y = idx*rowHeight;

            maxWidth.maximize(outerWidth);

            //todo: autoWidth wont reset automatically when setting outterWidth
            flags.autoWidth = false;
            outerWidth = maxWidth;
          }
        }
      }
    });

    return clicked;
  }

  void UI_detail(){
    update;
    with(im) Column(this.genericId, {
      margin = "2";
      Row("Details:");
      Row("Blabla:");
      Row("Blabla:");
    });
  }
}


class FrmTestInputs: GLWindow { mixin autoCreate;  // Frm ///////////////////////////////////

  CustomTexture customTexture;
  int threshold = 2;

  KarcFileBrowser browser;

  override void onCreate(){
    customTexture = new CustomTexture;

    browser = new KarcFileBrowser;
    browser.path = Path(`c:\d\projects\karc\samples`);

    refresh;

    //print("fuck! ha nincs console es valamelyik thread-en a jpeg decoder WARNingot dob, akkor vegtelen looppal kifagy.");
  }

  void refresh(){
    static Bitmap bOrig;
    if(!bOrig) bOrig = newBitmap(`\dl\login_ebay.png`);
    //`c:\D\projects\Karc\Samples\old\200221-213031-481.jpg`);

    //`c:\dl\books-notebook-notepad-pencil.jpg`);//c:\dl\s-l1600 (19).jpg`);

    auto iSrc = bOrig.get!ubyte;
    auto iDst = image2D(bOrig.size, bOrig.get!RGB.asArray);

    auto img = image2D(bOrig.size*ivec2(1, 2), ubyte(0));
    img[0, 0] = iSrc;

    foreach(y; 0..iSrc.height-2) foreach(x; 0..iSrc.width-2){
      auto subImg = iSrc[x..x+2, y..y+2],
           hDiff = min(absDiff(subImg[0,0],subImg[1,0]), absDiff(subImg[0,1],subImg[1,1])),
           vDiff = min(absDiff(subImg[0,0],subImg[0,1]), absDiff(subImg[1,0],subImg[1,1])),
           xDiff = min(absDiff(subImg[0,0],subImg[1,0]), absDiff(subImg[0,0],subImg[0,1]), absDiff(subImg[0,0],subImg[1,1]), absDiff(subImg[1,0],subImg[0,1])),
           xDiffAvg = max(absDiff(subImg[0,0],subImg[1,0]), absDiff(subImg[0,0],subImg[0,1]), absDiff(subImg[0,0],subImg[1,1]), absDiff(subImg[1,0],subImg[0,1]));

      void set(RGB col){ iDst[x, y] = col; }
      switch(xDiff/*+xDiffAvg/4*/){
        case 1: set(clLime);                  break;
        case 2: set(clYellow);                break;
        case 3: set(clOrange);                break;
        case 4: set(clRed);                   break;
        case 5:..case 255: set(clFuchsia);    break;
        default: set(clBlack);
      }
    }

    customTexture.update(new Bitmap(iDst));
  }

  override void onUpdate(){
    view.navigate(!im.wantKeys, !im.wantMouse);
    invalidate;

    auto LedBtn(string srcModule=__MODULE__, size_t srcLine=__LINE__)(in bool ledState, RGB ledColor, string caption){ with(im){
      return Btn!(srcModule, srcLine)({ if(ledColor!=clBlack){ flags.hAlign = HAlign.left; Led(ledState, ledColor); Text(" "); } Text(caption); width = 3.5*fh; });
    }}

    with(im){

      Panel(PanelPosition.topClient, {
        foreach(sensorIdx; 0..2) Row(sensorIdx.genericArg!"id", {
          style.bkColor = bkColor = sensorIdx==1 ? clAccent : clWhite;
          fh = fh*3.4;
          Text(sensorIdx==0 ? clBlack : clWhite, "S"~(+sensorIdx+1).text);
          Column({
            style.bkColor = bkColor = sensorIdx==1 ? clAccent : clWhite;
            Row({
              //theme = "tool";
              static trig = false; if(LedBtn(trig, clYellow, "Trigger").pressed) trig.toggle;
              static insp = false; if(LedBtn(insp, clYellow, "Inspect").pressed) insp.toggle;
              static save = false; if(LedBtn(save, clYellow, "Collect").pressed) save.toggle;
            });
            Row({
              bool b;
              LedBtn(b, clRed, "Source");
              LedBtn(b, clRed, "Image" );
              LedBtn(b, clRed, "Detect");
            });
          });
          Row({
            style.bkColor = bkColor = sensorIdx==1 ? clAccent : clWhite;
            Btn({ padding = "8"; fh = 36; Text("\u25fb"); });
            static continuous = false; if(Btn({ Led(continuous, clLime); padding = "8"; fh = 36; Text("\u25b6"); }).pressed) continuous.toggle;
          });

          Row({
            margin = "0 2";
            innerWidth = 96;
            innerHeight = 56;
            bkColor = clGray;
          });
          Row({
            margin = "0 2";
            innerWidth = 96*4;
            innerHeight = 56;
            bkColor = clGray;
          });
        });
      });
      Panel(PanelPosition.rightClient, {
        padding = "2";
        browser.UI_path;
        if(browser.UI_browser){ if(0) beep; }
        //browser.UI_detail;




/*        Row({
          border = "1 normal black";
          width = 50;
          flags.hAlign = HAlign.center;
          Text("abc");
        });

        Row({ border = "1 normal black"; width = 50; flags.hAlign = HAlign.center;
          Text("abc");
        });

        flags.wordWrap = false;
        width  = 150; flags.autoHeight=false; flags.hScrollState = ScrollState.on;
        height = 150; flags.autoWidth =false; flags.vScrollState = ScrollState.on;
        style.bkColor = clAqua;
        fh = 255; Text("\U0001F0CF");*/

        /* Row({
          Text("threshold");
          if(Slider(threshold, logRange(1, 255), { width = 512; })) refresh;
          Text(threshold.text);
        });*/

      });
    }
  }

  override void onPaint(){
    {
      auto dr = new Drawing; scope(exit) dr.glDraw(view);
      dr.clear(clBlack);

      //draw something
      dr.textOut(0, 0, "Hello");

      dr.drawGlyph(customTexture, vec2(0), Yes.nearest);

      view.workArea = dr.bounds;
      //view.zoomAll;
    }

    im.draw;
  }
}