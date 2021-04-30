//@exe
//@release

//@compile --d-version intId

import het, het.ui;


class CustomTexture{ // CustomTexture ///////////////////////////////
  string name(){ return this.identityStr; }
  protected{
    Bitmap bmp;
    bool mustUpload;
  }

  void update(){ mustUpload = true; }
  void update(Bitmap bmp){ this.bmp = bmp; mustUpload = true; }

  int texIdx(){
    if(bmp is null) return -1; //nothing to draw
    if(!textures.isCustomExists(name)) mustUpload = true; //prepare for megaTexture GC
    Bitmap b = chkClear(mustUpload) ? bmp : null;
    return textures.custom(name, b);
  }
}


class KarcFileBrowser{ // KarcFileBrowser ////////////////////////////////////////
  Path path;

  bool mustRefresh;
  Path updatedPath;
  FileEntry[] files;

  int selectedIdx = -1;

  void update(){
    if(mustRefresh || path != updatedPath){
      updatedPath = path;
      mustRefresh = false;

      files = listFiles(updatedPath, "*.jpg", "name");
    }
  }

  void UI_path(){
    update;
    if(im.EditPath(path, this.genericId)) mustRefresh = true;
  }

  void UI_browser(){
    update;
    with(im) Container(this.genericId, {
      margin = "2";
      border = "1 normal gray";
      innerWidth = 300;
      flex = 1;
      bkColor = clSilver;

      void UI(in FileEntry e){
        //border.width = 1;
        //border.color = clAccent;
        //style.bkColor = bkColor = mix(clAccent, clWhite, 1);

        if(e.isDirectory){
          flags.vAlign = VAlign.center; height = 36; style.bold = true; Text("["~e.name~"]");
        }else{
          Row({ width = 72; height = 36; flags.hAlign = HAlign.center; Text(tag(`img "%s?thumb64" height=36`.format(e.fullName)));});
          Row({ width = 72; height = 36; flags.hAlign = HAlign.center; Text(tag(`img "%s?thumb64" height=36`.format(e.fullName)));});
          Text(File(e.name).nameWithoutExt);
        }
      }

      //Container({

      static float maxWidth = 0; print(maxWidth);
      const rowHeight = 40;
      const totalHeight = rowHeight*files.length;

      //size placeholder
      Container({ outerSize = vec2(0); actContainer.outerPos = vec2(maxWidth, totalHeight); });

      flags.saveVisibleBounds = true;

      auto visibleBounds = imstVisibleBounds(actId);
//        print("ftch", actId, visibleBounds);

      if(visibleBounds.height>0 && files.length){
        int st = clamp((visibleBounds.top   /rowHeight).ifloor,  0, files.length.to!int-1);
        int en = clamp((visibleBounds.bottom/rowHeight).iceil , st, files.length.to!int-1);

//          print(st, en, visibleBounds);

        foreach(idx;  st..en+1){
          auto selected(){ return idx==selectedIdx; }

          Row(genericId(idx), {
            padding = "2";
            flags.wordWrap = false;

            auto hit = hitTest(true/*enabled*/);

            if(!selected && hit.hover && (inputs.LMB.pressed || inputs.RMB.pressed)) selectedIdx = idx; //mosue down left or right

            style.bkColor = bkColor = mix(bkColor, clAccent, max(selected ? .5f:0, hit.hover_smooth*.25f));

            UI(files[idx]);
          });

          lastContainer.measure;
          lastContainer.outerPos.y = idx*rowHeight;

          maxWidth.maximize(lastContainer.outerWidth);
          lastContainer.flags.autoWidth = false;
          lastContainer.outerWidth = maxWidth; //todo: it's a useless crap shit fuck ass #$!@%^#$!
        }
      }


      flags.clipChildren = true;
      flags.vScrollState = ScrollState.auto_;
      flags.wordWrap = false;
      flags.hScrollState = ScrollState.auto_;
    });
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
    browser.path = Path(`c:\d\projects\karc\samples\Dir1`);

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
        browser.UI_browser;
        browser.UI_detail;




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

      if(customTexture.texIdx>=0) dr.drawGlyph(customTexture.texIdx, vec2(0), Yes.nearest);

      view.workArea = dr.bounds;
      //view.zoomAll;
    }

    im.draw;
  }
}