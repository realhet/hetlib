//@exe
///@release

import het, het.ui;

class FrmMain: GLWindow { mixin autoCreate; // !FrmMain ////////////////////////////

  bounds2 lastWorkArea;
  bool showFPS;

  override void onCreate(){ // create /////////////////////////////////
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

    with(im) Panel(PanelPosition.top, {
      Text("Top panel");
    });

    with(im) Panel(PanelPosition.left, {
      vScroll;

      Text("Left panel");
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


