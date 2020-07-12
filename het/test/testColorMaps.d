//@exe
//@import c:\d\libs
//@ldc
//@compile -m64 -mcpu=athlon64-sse3 -mattr=+ssse3
//@release
///@debug

import het, het.ui;

/////////////////////////////////////////////////////////////////////////////////////////////////

void ui(ColorMap cmap){ with(im){
  Row({
    Row({ width = 120; }, cmap.name);
    Row({ border = "1 normal gray";
      width = 256; height = 12;
      auto fn = `colormap:\`~cmap.name;
      Text(tag(`img "%s" width=%s height=%s`.format(fn, width, height)));
    });
  });
}}

void ui(ColorMaps cmaps, string header){ with(im){
  static bool b=true;
  Node(b, { Row(bold(header));              },
          { foreach(cmap; cmaps) ui(cmap);  });
}}

void ui(ColorMapCategory cat){
  ui(cat.colorMaps, cat.name ~ " ColorMaps");
}

void violate(){
  throw new Exception("TEXTEXCEPTION");
  asm{ mov RAX,0x123A; mov [RAX], RAX; /*int 3;*/ }
}

class FrmMain: GLWindow { mixin autoCreate; // !FrmMain ////////////////////////////

  override void onCreate(){ // create /////////////////////////////////
  }

  override void onDestroy(){ // destroy //////////////////////////////
    //ini.write("settings", db.saveToJSON);
  }


  override void onUpdate(){ // update ////////////////////////////////
    invalidate; //todo: opt

    const PanelWidth = 416;

    view.navigate(!im.wantKeys, !im.wantMouse);

    with(im) Panel(PanelPosition.topLeft, {
      width = PanelWidth;
      vScroll;

      //try{
        installExceptionFilter;
        Row({
          if(Btn("int 3")) asm{ int 3; }
          if(Btn("accessv write")) asm{ mov RAX,0x1234; mov [RAX], RAX; }
          if(Btn("accessv read" )) asm{ mov RAX,0x1234; mov RAX, [RAX]; }
          if(Btn("raise" )) raise("custom exception");
          if(Btn("throw" )) throw new Exception("custom exception");
        });
      //}catch(Throwable){ }

      void toolHeader(){
        theme = "tool";
        bkColor = lerp(clWinBtn, tsNormal.bkColor, .5); style.bkColor = bkColor;
        padding = "4";
      }

      Row({
        Text(tsChapter, "ColorMap DEMO");
        Flex;
        Text(tsComment, "Build: "~__DATE__~"  "~__TIME__);
      });
      Spacer(.5*fh);

      foreach(cat; colorMaps.categories) ui(cat);
      //ui(colorMaps, "All ColorMaps");
    });
  }

  override void onPaint(){ // paint //////////////////////////////////////
    dr.clear(clSilver);
    drGUI.clear;

    im.draw(drGUI);

    if(0) foreach(i; 0..255){
      double[][] polys = [[ 4.05630748e+08, -3.66095716e+09,  1.51615212e+10, -3.81828926e+10,
        6.53317418e+10, -8.03730609e+10,  7.33860595e+10, -5.06166218e+10,
        2.65914471e+10, -1.06520321e+10,  3.23641170e+09, -7.36971932e+08,
        1.23274026e+08, -1.46738185e+07,  1.18204597e+06, -5.94177597e+04,
        1.61707665e+03, -1.72898199e+01,  1.00033755e+00], [-1.51179197e+08,  1.37938243e+09, -5.76440368e+09,  1.46071494e+10,
       -2.50433806e+10,  3.06871998e+10, -2.76738851e+10,  1.86286652e+10,
       -9.39074432e+09,  3.52217569e+09, -9.66080635e+08,  1.87624857e+08,
       -2.43287811e+07,  1.86144473e+06, -5.42686597e+04, -2.42351728e+03,
        2.10192687e+02,  1.91883026e+00,  1.10139693e-04], [ 6.65510667e+07, -5.76177131e+08,  2.30327215e+09, -5.64007560e+09,
        9.45792554e+09, -1.14928583e+10,  1.04345228e+10, -7.18700315e+09,
        3.77215622e+09, -1.50236911e+09,  4.48660921e+08, -9.85111390e+07,
        1.54619595e+07, -1.66870040e+06,  1.17245909e+05, -4.94371133e+03,
        1.09130190e+02, -9.30975417e-01, -5.83318400e-05]];

      foreach(j; 0..3){
        dr.pointSize = -3;
        dr.color = [clRed, clLime, clBlue][j];

        static poly2(float x, float[] p){
          float x0 = 1, sum=0;
          foreach(pp; p){
            sum += x0*pp;
            x0 *= x;
          }
          return sum;
        }


        dr.point(i, 255-colorMaps["viridis"].eval(i/255.0).comp[j]);
      }
    }

    dr.drawGlyph(File(`colorMap:\viridis`), V2f(0, 0));

    drawFpsTimeLine(drGUI);
  }


}