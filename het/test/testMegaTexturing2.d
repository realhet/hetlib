//@exe
//@release

import het, het.ui, het.stream;

//todo: put these into math.d
size_t clamp(R)(sizediff_t idx, R arr) if(__traits(compiles, idx<arr.length-1)){
  if(!arr.length || idx<0) return 0;
  if(idx>=arr.length) return arr.length-1;
  return idx;
}

int clamp(R)(int idx, R arr) if(IsRandomRange!R){
  return clamp(sizediff_t(idx), arr).to!int;
}

class FrmMain: GLWindow { mixin autoCreate; // !FrmMain ////////////////////////////

  this(){
    LOG;
  }

  @STORED bool showFPS = true;
  bounds2 lastWorkArea;
  auto photoPath = Path(
    `c:\!temp`
//    `c:\d\projects\karc\samples`
  );
  File[] photos;
  @STORED File _actPhoto;

  @property auto actPhotoIdx(){
    return photos.countUntil(_actPhoto).to!int;
  }

  @property void actPhotoIdx(sizediff_t idx){
    auto i = idx.clamp(photos);
    _actPhoto = i.inRange(photos) ? photos[i] : File("");
  }

  @property File actPhoto(){
    return actPhotoIdx<0 ? File("") : _actPhoto;
  }

  @property void actPhoto(File f){
    _actPhoto = f;
  }

  override void onCreate(){ // create /////////////////////////////////
    import het.megatexturing;
    MegaTexMinSize = MegaTexMaxSize = 8<<10;

    auto a = this; a.fromJson(ini.read("settings", ""));
    photos = photoPath.files("*.jpg").sort!((a,b)=>a < b).take(1600).array;
  }

  override void onDestroy(){ // destroy //////////////////////////////
    ini.write("settings", this.toJson);
  }

  override void onUpdate(){ // update ////////////////////////////////
    caption = TPS.text;
    invalidate; //todo: opt

    auto
      kcShowFPS   = KeyCombo("Ctrl+F"),
      kcUp        = KeyCombo("Up"),
      kcDown      = KeyCombo("Down"),
      kcAccess    = KeyCombo("A");

    if(kcShowFPS.pressed) showFPS.toggle;
    if(kcUp  .typed) actPhotoIdx = actPhotoIdx-1;
    if(kcDown.typed) actPhotoIdx = actPhotoIdx+1;
    if(kcAccess.pressed && actPhoto.exists) textures[actPhoto];

    if(KeyCombo("Space").pressed) photos[0..9-1].each!(f => textures[f]);

    view.navigate(false/*keys*/, true/*mouse*/);

    //automatically ZoomAll when the resolution
    if(!view.workArea.empty && chkSet(lastWorkArea, view.workArea)) view.zoomAll;
  }

  void drawPhotoList(Drawing dr){ with(dr){
    fontHeight = 20;
    auto actIdx = actPhotoIdx;
    foreach(i, f; photos){
      float y = i*fontHeight;
      const focused = actIdx == i;
      dr.color = focused ? clAqua : clWhite;

      if(focused) dr.textOut(0, y, "*");

      dr.textOut(20, y, f.nameWithoutExt);
    }
  }}

  override void onPaint(){ // paint //////////////////////////////////////
    gl.clearColor(clBlack); gl.clear(GL_COLOR_BUFFER_BIT);

    // draw main ///////////////////////////
    auto dr = scoped!Drawing;

    if(1) foreach(i; 0..1) if(inputs.CapsLockState.down) dr.drawGlyph(photos[random(photos.length.to!int)], vec2(i*2000, -2000));

    if(0){ dr.translate(-1000, 0); dr.scale(5); drawPhotoList(dr); dr.pop; dr.pop; }

    textures.debugDraw(dr);

    view.workArea |= dr.bounds;
    dr.glDraw(view);

    // draw overlay ////////////////////////
    auto drGUI = scoped!Drawing;
    if(showFPS){
      drawFPS(drGUI);
    }
    drGUI.glDraw(viewGUI);
  }


}

