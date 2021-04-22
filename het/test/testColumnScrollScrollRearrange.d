//@exe
//@release

import het, het.ui;

class CustomTexture{
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


class FrmTestInputs: GLWindow { mixin autoCreate;

  CustomTexture customTexture;
  int threshold = 32;

  override void onCreate(){
    customTexture = new CustomTexture;

    refresh;
  }

  void refresh(){
    static Bitmap bOrig;
    if(!bOrig) bOrig = newBitmap(`c:\dl\login_hestore.png`);

    auto iSrc = bOrig.get!ubyte;
    auto iDst = image2D(bOrig.size, bOrig.get!RGB.asArray);

    auto img = image2D(bOrig.size*ivec2(1, 2), ubyte(0));
    img[0, 0] = iSrc;

    foreach(y; 0..iSrc.height-2) foreach(x; 0..iSrc.width-2){
      auto subImg = iSrc[x..x+2, y..y+2],
           hDiff = min(absDiff(subImg[0,0],subImg[1,0]), absDiff(subImg[0,1],subImg[1,1])),
           vDiff = min(absDiff(subImg[0,0],subImg[0,1]), absDiff(subImg[1,0],subImg[1,1]));
      img[x, y+iSrc.height] = cast(ubyte)(
         min(hDiff, vDiff)>=threshold ? 255 : 0
      );

      if(img[x, y+iSrc.height]) iDst[x, y] = clFuchsia;
    }

    customTexture.update(new Bitmap(iDst));
  }

  override void onUpdate(){
    view.navigate(!im.wantKeys, !im.wantMouse);
    invalidate;

    with(im){
      Panel(PanelPosition.topLeft, {

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

        Row({
          Text("threshold");
          if(Slider(threshold, logRange(1, 255), { width = 512; })) refresh;
          Text(threshold.text);
        });

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