//@exe
///@release

import het, het.ui;

enum Category{ Draw2D, Sliders }

class FrmMain: GLWindow { mixin autoCreate; // !FrmMain ////////////////////////////

  bounds2 lastWorkArea;
  bool showFPS;

  Category category = Category.Sliders;

  override void onCreate(){ // create /////////////////////////////////
    caption = "GUI Test";
  }

  override void onDestroy(){ // destroy //////////////////////////////
    //ini.write("settings", db.toJson);
  }

  override void onUpdate(){ // update ////////////////////////////////
    invalidate; //todo: opt

    //view.subScreenArea = bounds2(float(PanelWidth) / clientWidth, 0, 1, 1);
    view.navigate(!im.wantKeys, !im.wantMouse);

    //automatically ZoomAll when the resolution
    if(view.workArea.width>8 && view.workArea.height>8 && chkSet(lastWorkArea, view.workArea))
      view.zoomAll;

    with(im) Panel(PanelPosition.topClient, {
      Row({
        Text(tsChapter, "GUI Test");
        Spacer;
        BtnRow(category);
      });
    });

    with(im) Panel(PanelPosition.client, {

      if(category==Category.Sliders){
        immutable sizes = [8, 16, 32, 64, 128];

        static float value = 50;

        static int sliderFontHeight, defaultSliderFontHeight;
        if(!sliderFontHeight) sliderFontHeight = defaultSliderFontHeight = style.fontHeight;
        Row({
          Text("FontHeight"); Spacer; Slider(sliderFontHeight, range(1, 72));
          Spacer; if(Btn(format!"Default(%s)"(defaultSliderFontHeight))) sliderFontHeight = defaultSliderFontHeight;
        });

        void TestSlider(int size, SliderOrientation orientation){
          flags.yAlign = YAlign.top;
          Row({
            border = "1 normal silver"; margin = "1";
            style.fontHeight = sliderFontHeight.to!ubyte;
            Slider(value, range(0, 100), orientation, {
              final switch(orientation){
                case SliderOrientation.horz : width = size;             height = sliderFontHeight; break;
                case SliderOrientation.vert : width = sliderFontHeight; height = size;             break;
                case SliderOrientation.round: width = size;             height = size;             break;
                case SliderOrientation.auto_: auto i = sizes.countUntil(size);  width = fh*(i+1); height = fh*(sizes.length-i);  break;
              }
            });
          });
          if(orientation==SliderOrientation.horz) Text('\n');
        }

        //fh = 30;

        Row({ padding = "5";
          flags.yAlign = YAlign.top;
          Text(bold("Normal sliders\n"));
          foreach(orientation; EnumMembers!SliderOrientation) Column({
            Row("orientation : ", orientation.text);
            Row({ foreach(size; sizes) TestSlider(size, orientation); });
          });
        });
        Row({ padding = "5";
          flags.yAlign = YAlign.top;
          Text(bold("Scrollbars\n"));
          foreach(orientation; EnumMembers!SliderOrientation) Column({
            Row("orientation : ", orientation.text);
            Row({ foreach(size; sizes) TestSlider(size, orientation); });
          });
        });

      }

    });


/*    with(im) Panel(PanelPosition.topLeft, {
      width = PanelWidth;
      vScroll;

      list.each!UI_Thumbnail;
    });*/
  }

  override void onPaint(){ // paint //////////////////////////////////////
    gl.clearColor(clSilver); gl.clear(GL_COLOR_BUFFER_BIT);

    auto dr = scoped!Drawing;
    //db.samples.glDraw(dr);
    textures.debugDraw(dr);

    view.workArea = dr.bounds;
    dr.glDraw(view);

    im.draw;

    if(showFPS){
      auto drGUI = scoped!Drawing;
      drawFPS(drGUI);
      drGUI.glDraw(viewGUI);
    }
  }


}


