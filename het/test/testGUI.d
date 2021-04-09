//@exe
///@release

import het, het.ui;

enum Category{ Draw2D, Text, Align, Sliders }

void UI_Category(Category category){
  with(Category) final switch(category){
    case Draw2D:                        break;
    case Text:          UI_Text;        break;
    case Align:         UI_Align;       break;
    case Sliders:       UI_Sliders;     break;
  }
}


void UI_Text(){ with(im){ //Text (Cell Docs) //////////////////////////////
  Document(`CELL Documentation`, {
  //  Toc;

    void LI(string capt, string text){ OldListItem(bold(capt) ~ "\t\t\t\t" ~ text); }

    Chapter(`Markup text format`, {
      Text(`The preferred text format is UTF8.
Every line can contain a definition, so the new-line character marks the end of the definition.
Empty lines are either ignored or used to break the continuity of lists/tables.
There are exceptions for this, but it will be specified there.`);

      Chapter(`Embedding meta information into the text`, {
        Text(`The fundamental building block is the "cell". The simplest cell is this single line of text, like this one for example.
For more complex cells, meta information (tags) can be inserted along with the text:`);

        Code(`text` ~ tag(`char 0xB6`) ~ `meta commands` ~ tag(`char 0xA7`) ~ `more text`);
        Text(`The opening symbol is the "`~tag("char 0xB6")~`" "Pilcrow" character, Alt+20.`);
        Text(`The closing symbol is the "`~tag("char 0xA7")~`" "Section sign" character, Alt+21.`);
        Text(`Lines starting with special tags can define the meaning of the whole line. These starter tags can build special types of cells or they can create more than one cells too.`);
        Text(`The above text representation can be issued from code by using the tag() function:`);
        Code(`"text" ~ tag("meta connamds") ~ "more text"`);
      });
      Chapter(`Formatting the text`, {
        Chapter(`Setting text format manually`, {
          Text(`The format to modify the current TextStyle is:`);
          Code(tag(`char 0xB6`) ~ `style param1=value1 param2=value2 ...` ~ tag(`char 0xA7`));
        });
        Text(`The available parameters are:`);
        [`font="Segoe Script"|Selects a different @fontFace`,
         `fontHeight=24|Sets the font's height to @24 pixels`,
         `bold=1|Turn on @bold`,
         `italic=1|Turn on @italic`,
         `underline=1|Turn on @underline`,
         `strikeout=1|Turn on @strikeout`,
         `fontColor=0xFF0080|Sets the @color of the font`,
         `bkColor=lime|Sets the @color of the font background`].each!((s){
           s.isWild("*=*|*");
           OldListItem( format("%s=%s\t\t\t\t%s", bold(wild[0]), wild[1], wild[2].replace("@", tag("style "~wild[0]~"="~wild[1]))) );
        }); //todo: minTabSize a \t\t\t\t halmozas helyett. Ehhez kell egy theme is valoszinuleg.
        Text("Note: Valid color formats are the following: 0xFF00FF, rgb(255, 0, 255), fuchsia");
        Chapter(`Predefined text formats`, {
          Text(`There are some predefined textstyles. They can be selected simply by their name (or their short name):`);
          Code(tag(`char 0xB6`) ~ `name` ~ tag(`char 0xA7`));

          auto styles = ["normal, n", "larger", "smaller", "half", "comment", "error", "bold, b", "bold2, b2", "quote, q", "code, c", "link", "title", "chapter", "chapter2", "chapter3"];
          foreach(s; styles)
            OldListItem(s ~ "\t\t\t\t" ~ tag(s.split(",")[0])~"Demo");
        });
      });
      Chapter(`Properties`, {
        Chapter(`Cell properties`, {
          Text(`To modify the properties of the current cell (normally a Row), use the 'prop' tag:`);
          Code(tag(`char 0xB6`) ~ `prop name1=value1 name2=value2 ...` ~ tag(`char 0xA7`));
        });
        Chapter(`Container properties`, {
          Text(`These are the properties for every kind of cells.`);
          Spacer(0.5*fh);
          LI("innerWidth, innerHeight", "Sets the size of the cell inside its pading.");
          LI("outerWidth, outerHeight", "Sets the total size of the cell including its margin.");
          LI("width, height", "Shorthand for "~bold("outerWidth")~" and "~bold("outerHeight")~".");
          Spacer(0.5*fh);
          Text("Note: By default sizes are defined in pixels. If you want to use fontHeight units, put an \"x\" after the number. Eg.: \"1.5x\".");
          Spacer(0.5*fh);
          LI("margin.all", "Defines the margin size in all 4 directions around the cell.");
          LI("margin.horz", "Sets margin on left and right.");
          LI("margin.vert", "Sets margin on top and bottom.");
          LI("margin.left/right/top/bottom", "Sets margin on specific directions.");
          LI("margin", "This is a shorthand for the above, the number of elements (separated by spaces) defines which sides to set.");
          //todo: this should be a table
          Spacer(0.5*fh);
          Text("The following examples are demonstrating the usage of the the shortHand format:
1\tall=1
1 2\tvert=1, horz=2
1 2 3\ttop=1, horz=2, bottom=3
1 2 3 4\ttop=1, right=2, bottom=3, left=4");
          Spacer(0.5*fh);
          Text("Padding:");
          LI("padding", "Defines the inner area of the cell. Can be used in the exact same way as "~bold("margin")~".");
          Spacer(0.5*fh);
          Text("The border in is between the margin and the padding:");
          LI("border.width", "Sets the width(thickness) of the border");
          LI("border.color", "Sets color.");
          auto borders = ["none","normal","dot","dash","dashDot","dash2","dashDot2","double"].map!(s => tag("row \""~s~"\" border="~s)).join("  ");
          LI("border.style", "Can be the following: "~borders); //todo: bug: double border is single
          LI("border", "ShortHand, that sets all the border parameters. Example: \"0.5x dot red\". Width and color is optional.");
          Spacer(0.5*fh);
          Text("Other container properties:");
          Spacer(0.5*fh);
          LI("flex", "This cell is flexible. The remaining size of the parent cell will be shared across flexible cells. Each flex cell will get a size proportional to its flex value.");
          LI("bkColor", "Background color. Later this will be a background object with more properties.");
        });
      });
      Chapter(`Special tags in Rows`, {
        LI("row", "Inserts a row which is acts like a cell. First parameter is the nontent of that row, remaining are properties.");
        auto rowExample = `row "Test row" border="2 dash SkyBlue" width=160 height=2x`;
        Code(rowExample);
        Text(tag(rowExample));

        LI("img", "Loads and displays an image. The first parameter can be a fileName.");
        auto imgExample = `img "c:\dl\hehe.png"`;
        Code(imgExample);
        Text(tag(imgExample));
        Text(`Note: Use the `~bold(`font:\`)~` drive prefix to load one ore more characters of a specific font:`);

        auto imgFontExample = "img \"font:\\Segoe UI Emoji\\32?\U0001F355\U0001F35F\U0001f964\"";
        Code(imgFontExample);
        Text(tag(imgFontExample));
        Text("Note: You can attach some parameters to the font render like adding a directory to the filePath.");
        LI("<integer>", "Sets the fontHeight. 32 is used in the above example."); //todo: this should be a table
        LI("ct", "ClearType");
        LI("x3", "Stretch the image 3x wider. Can be usebul in a cleartype shader.");
        LI("x2", "...2x wider.");

        Spacer(1*fh);
        LI("char", "Access a character by (dec or hex) code.");
        auto charExample = "char 0x61";
        Code(charExample);
        Text(tag(charExample));

        Spacer(1*fh);
        LI("symbol", "Inserts a symbol from \"Segoe MDL2 Assets\" font. Parameter can be an index or a name.");
        auto symbolExample1 = "symbol 0xE80F";
        auto symbolExample2 = "symbol Wifi";
        Code(symbolExample1~"         "~symbolExample2);
        Text(tag(symbolExample1)~tag(symbolExample2));

        Spacer(1*fh);
        LI("space", "Inserts whitespace. First param specifies the width.");
        auto spaceExample = "space 5x border=normal bkColor=yellow";
        Code(spaceExample);
        Text("some text"~tag(spaceExample)~"more text");

      });
    });
  });

}}

void UI_Align(){ with(im){ // Align //////////////////////////////////////////
  Column({
    enum lorem = "In\r\npublishing and graphic design, lorem ipsum is a placeholder text commonly used to demonstrate(...)";

    void TestFlag(T)(T[] items, void delegate(T) fun, string lorem){
      Row({ foreach(i; items){ Row({
        flex = 1;  //no autoWidth, so it will enable wrap
        margin = "1";
        border = "1 single black";
        padding = "1";
        fun(i);
        Text(bold(T.stringof~"."~i.text), " ", "\U0001F4A1", lorem);
        //flags.canSelectCells = true;
      }); }
      Spacer(.5*fh); //todo: ez is bugos
    }); }

    Text("HAlign Test  width=explicit(flex=1)  height=auto  wrap=on");
    TestFlag([EnumMembers!(het.uibase.HAlign)], (het.uibase.HAlign i){ flags.hAlign=i; }, lorem); //todo: ambigious names: draiwng.HAlign

    Text("VAlign Test  width=explicit(flex=1)  height=5 lines  wrap=on");
    TestFlag([EnumMembers!(het.uibase.VAlign)], (het.uibase.VAlign i){ height = fh*5; flags.vAlign=i; }, lorem[0..$/4]); //todo: ambigious names: draiwng.HAlign

    //todo: ez el van baszva
    Text("YAlign Test  width=explicit(flex=1)  height=5 lines  wrap=on");
    TestFlag([EnumMembers!YAlign], (YAlign i){ flags.yAlign=i; }, "     M_"~tag("style fontHeight=40")~"_M");
  });

}}


void UI_Sliders(){ with(im){ // Sliders ///////////////////////////////////////////////
  immutable sizes = [8, 16, 32, 64, 128];

  static float value = 50;

  static int sliderFontHeight, defaultSliderFontHeight;
  if(!sliderFontHeight) sliderFontHeight = defaultSliderFontHeight = style.fontHeight;
  Row({
    Text("FontHeight"); Spacer; Slider(sliderFontHeight, range(1, 72));
    Spacer; if(Btn(format!"Default(%s)"(defaultSliderFontHeight))) sliderFontHeight = defaultSliderFontHeight;
  });

  void TestSlider(int size, SliderOrientation orientation, SliderStyle sliderStyle){
    flags.yAlign = YAlign.top;
    Row({
      border = "1 normal silver"; margin = "1";
      style.fontHeight = sliderFontHeight.to!ubyte;
      Slider(value, range(0, 100), orientation, sliderStyle, {
        final switch(orientation){
          case SliderOrientation.horz : outerWidth = size;             outerHeight = sliderFontHeight; break;
          case SliderOrientation.vert : outerWidth = sliderFontHeight; outerHeight = size;             break;
          case SliderOrientation.round: outerWidth = size;             outerHeight = size;             break;
          case SliderOrientation.auto_: auto i = sizes.countUntil(size);  outerWidth = fh*(i+1); outerHeight = fh*(sizes.length-i);  break;
        }
      });
    });
    if(orientation==SliderOrientation.horz) Text('\n');
  }

  void TestSliders(SliderStyle sliderStyle, SliderOrientation[] orientations){
    Row({ padding = "5";
      flags.yAlign = YAlign.top;
      Text(bold(sliderStyle.text), "\n");
      foreach(orientation; orientations) Column({
        Row("orientation : ", orientation.text);
        Row({ foreach(size; sizes) TestSlider(size, orientation, sliderStyle); });
      });
    });
  }

  TestSliders(SliderStyle.slider, [EnumMembers!SliderOrientation]);
  TestSliders(SliderStyle.scrollBar, [SliderOrientation.horz, SliderOrientation.vert]);

}}


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
      UI_Category(category);
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


enum oldSliderSource = q{ //! OldSliderSource ////////////////////////////////////////////////////

  enum SliderOrientation{ horz, vert, round, auto_ }
  enum HoverState { normal, hover, pressed, disabled }

  void calcSliderOrientation(ref SliderOrientation orientation, in bounds2 r){
    if(orientation == SliderOrientation.auto_){
      float aspect = safeDiv(r.width/r.height, 1);
      enum THRESHOLD = 1.5f;

      orientation = aspect>=THRESHOLD     ? SliderOrientation.horz:
                    aspect<=(1/THRESHOLD) ? SliderOrientation.vert:
                                            SliderOrientation.round;
    }
  }


  class Slider : Container { // Slider //////////////////////////////////
    //todo: shift precise mode: must use float knob position to improve the precision

    __gshared static{ //information about the current slider being modified
      uint mod_id, mod_actid;
      SliderOrientation mod_ori;
      vec2 mod_p0, mod_p1;
      bounds2 mod_knob;
      vec2 mod_ofs, mod_mouseBase;
      float mod_nPosBase;
      int mod_dir; //0:unknown, 1:h, 2:v

      void modSet(uint id, in SliderOrientation ori, vec2 p0, vec2 p1, in bounds2 bKnob){
        mod_id = id;
        mod_ori = ori;
        mod_p0 = p0;
        mod_p1 = p1;
        mod_knob = bKnob;
      }
    }

    uint id;
    SliderOrientation orientation = SliderOrientation.auto_;
    RGB bkColor;
    RGB   clLine, clThumb, clRuler;
    float lwLine, lwThumb, lwRuler, rulerOfs;

    int rulerDiv0 = 9, rulerDiv1 = 4;
    ubyte rulerSides=3;

    float nPos, nCenter=0;  //center is the start of the marking on the line
    int wrapCnt; //for endless, to see if there was a wrapping or not. Used to reconstruct actual value

    bounds2 hitBounds;

    bool focused;

    this(uint id, bool enabled, ref float nPos_, in im.range range_, ref bool userModified, vec2 mousePos, TextStyle ts, out HitInfo hit){
      this.id = id;

      hit = im.hitTest(this, id, enabled);

      hitBounds = hit.hitBounds;

      focused = im.focusUpdate(this, id,
        enabled,
        hit.pressed/* || manualFocus*/, //when to enter
        inputs["Esc"].pressed,  //when to exit
        /* onEnter */ { },
        /* onFocus */ { },
        /* onExit  */ { }
      );
      //res.focused = focused;

      if(focused){
        void set(float n){
          nPos_ = n.clamp(0, 1);
          userModified = true;
        }

        void delta(float scale){
          auto nStep(){ return range_.step / (range_.max-range_.min); }
          set(nPos_ + nStep *scale);
        }

        const pageSize = 8;
        if(inputs.Left.repeated  || inputs.Down.repeated) delta(-1);
        if(inputs.Right.repeated || inputs.Up.repeated  ) delta( 1);
        if(inputs.PgDn.repeated)                          delta(-pageSize);
        if(inputs.PgUp.repeated)                          delta( pageSize);
        if(inputs.Home.down)                              set(0);
        if(inputs.End .down)                              set(1);
      }

      nPos = nPos_;

      bkColor = ts.bkColor;

      const hoverOrFocus = max(hit.hover_smooth*.5f, focused ? 1.0f : 0);

      clThumb = mix(mix(clSliderThumb, clSliderThumbHover, hoverOrFocus), clSliderThumbPressed, hit.captured_smooth);
      clLine =  mix(mix(clSliderLine , clSliderLineHover , hoverOrFocus), clSliderLinePressed , hit.captured_smooth);
      clRuler = mix(bkColor, ts.fontColor, 0); //disable ruler for now

      if(!enabled) clLine = clThumb = clGray; //todo: nem clGray ez, hanem clDisabledText vagy ilyesmi

      innerSize = vec2(ts.fontHeight*6, ts.fontHeight); //default size

      float thumbSize = ts.fontHeight*0.8f;
      rulerOfs = thumbSize*0.5f;
      lwThumb = thumbSize*(1.0f/3);
      lwLine  = thumbSize*(2.0f/NormalFontHeight);
      lwRuler = lwLine*0.5f;

      //hit.pressed
      const isLinear = mod_ori.among(SliderOrientation.horz, SliderOrientation.vert);
      const isRound = mod_ori==SliderOrientation.round;
      const precise = inputs.Shift.active ? 0.125f : 1;
      if(hit.pressed && enabled){  //todo: enabled handling
        userModified = true;
        mod_actid = id;

        //decide wether the knob has to jump to the mouse position or not
        const doJump = mod_id==id && isLinear && !mod_knob.contains!"[)"(mousePos);
        if(doJump) mod_ofs = vec2(0);
              else mod_ofs = mod_knob.center-mousePos;

        if(doJump){
          if(mod_ori==SliderOrientation.horz){
            nPos = remap_clamp(mousePos.x, mod_p0.x, mod_p1.x, 0, 1);
            if(mousePos.x<mod_p0.x) mod_ofs.x = mod_p0.x-mousePos.x;
            if(mousePos.x>mod_p1.x) mod_ofs.x = mod_p1.x-mousePos.x - (range_.isEndless ? 1 : 0); //otherwise endles range_ gets into an endless incrementing loop
          }else if(mod_ori==SliderOrientation.vert){
            nPos = remap_clamp(mousePos.y, mod_p0.y, mod_p1.y, 0, 1);
            //note: p1 and p0 are intentionally swapped!!!
            if(mousePos.y<mod_p1.y) mod_ofs.y = mod_p1.y-mousePos.y; //todo: test vertical circular slider jump to the very ends, and see if not jumps to opposite si
            if(mousePos.y>mod_p0.y) mod_ofs.y = mod_p0.y-mousePos.y - (range_.isEndless ? 1 : 0);
          }
        }

        if(isRound){
          mouseLock;
          mod_mouseBase = rawMousePos;
          mod_nPosBase = nPos;
          mod_dir = 0;
        }
      }

      //continuous update if active
      if(id==mod_actid){
        userModified = true;

        if(isLinear) slowMouse(precise!=1, precise);

        if(mod_ori==SliderOrientation.horz){
          auto p = mousePos.x+mod_ofs.x;
          if(range_.isCircular || range_.isEndless) mouseMoveRelX(wrapInRange(p, mod_p0.x, mod_p1.x, wrapCnt)); //circular wrap around
          nPos = remap(p, mod_p0.x, mod_p1.x, 0, 1);
          if(range_.isClamped) nPos = nPos.clamp(0, 1);
        }else if(mod_ori==SliderOrientation.vert){
          auto p = mousePos.y+mod_ofs.y;
          if(range_.isCircular || range_.isEndless) mouseMoveRelY(wrapInRange(p, mod_p0.y, mod_p1.y, wrapCnt)); //circular wrap around
          nPos = remap(p, mod_p0.y, mod_p1.y, 0, 1);
          if(range_.isClamped) nPos = nPos.clamp(0, 1);
        }else{
          auto diff = rawMousePos-mod_mouseBase;
          auto act_dir = abs(diff.x)>abs(diff.y) ? 1 : 2;
          if(mod_dir==0 && length(diff)>=3) mod_dir = act_dir;
          auto delta = (mod_dir ? mod_dir : act_dir)==1 ? inputs.MXraw.delta : -inputs.MYraw.delta;
          mod_nPosBase += delta*(precise*(1.0f/180));
          mod_nPosBase = mod_nPosBase.clamp(0, 1);
          nPos = mod_nPosBase;
            //todo: endless????
            //todo: ha tulmegy, akkor vinnie kell magaval a base-t is!!!
            //todo: Ctrl precizitas megoldasa globalisan az inputs.d-ben.
        }
      }

      //hit.released
      if(hit.released){
        mod_actid = 0;

        //todo: this isn't safe! what if the control disappears!!!
        if(isLinear){
          slowMouse(false);
        }else{
          mouseUnlock;
        }
      }

      if(userModified)
        nPos_ = nPos;
    }

    override bounds2 getHitBounds(){
      return innerBounds;
    }

    override void draw(Drawing dr){
      const mod_update = !hitBounds.empty && !inputs.LMB.value;

      dr.color = bkColor; dr.fillRect(borderBounds_inner);
      drawBorder(dr);

      dr.alpha = 1; dr.lineStyle = LineStyle.normal; dr.arrowStyle = ArrowStyle.none;
      void drawThumb(vec2 a, vec2 t){ dr.lineWidth = lwThumb; dr.color = clThumb; dr.line(a-t.rotate90, a+t.rotate90); }
      void drawLine(vec2 a, vec2 b, RGB cl){ dr.lineWidth = lwLine; dr.color = cl; dr.line(a, b); }

      auto b = innerBounds;
      orientation.calcSliderOrientation(b);

      if(orientation==SliderOrientation.horz){
        auto t = vec2(lwThumb, 0),
             ro = vec2(0, rulerOfs),
             p0 = b.leftCenter  + t,
             p1 = b.rightCenter - t;

        drawLine(p0, p1, clLine);

        if(rulerSides&1) drawStraightRuler(dr, bounds2(p0-ro, p1-ro*0.4f), rulerDiv0, rulerDiv1, true );
        if(rulerSides&2) drawStraightRuler(dr, bounds2(p0+ro*0.4f, p1+ro), rulerDiv0, rulerDiv1, false);

        if(!isnan(nPos)){
          auto p = mix(p0, p1, nPos);
          if(!isnan(nCenter)) drawLine(mix(p0, p1, nCenter), p, clThumb);
          drawThumb(p, t);

          if(mod_update) modSet(id, orientation, dr.inputTransform(p0), dr.inputTransform(p1), dr.inputTransform(bounds2(p, p).inflated(lwThumb*0.5f, lwThumb*1.5f)));
        }

      }else if(orientation==SliderOrientation.vert){
        auto t = vec2(0, -lwThumb),
             ro = vec2(rulerOfs, 0),
             p0 = b.bottomCenter + t,
             p1 = b.topCenter    - t;

        drawLine(p0, p1, clLine);

        if(rulerSides&1) drawStraightRuler(dr, bounds2(p1-ro, p0-ro*0.4f), rulerDiv0, rulerDiv1, true );
        if(rulerSides&2) drawStraightRuler(dr, bounds2(p1+ro*0.4f, p0+ro), rulerDiv0, rulerDiv1, false);

        if(!isnan(nPos)){
          auto p = mix(p0, p1, nPos);
          if(!isnan(nCenter)) drawLine(mix(p0, p1, nCenter), p, clThumb);
          drawThumb(p, t);
          if(mod_update) modSet(id, orientation, dr.inputTransform(p0), dr.inputTransform(p1), dr.inputTransform(bounds2(p, p).inflated(lwThumb*1.5f, lwThumb*0.5f)));
        }
      }else if(orientation==SliderOrientation.round){
        //center square
        bool endless = false;

        b = b.fittingSquare;
        if(mod_update) modSet(id, orientation, dr.inputTransform(b.center), dr.inputTransform(b.center), dr.inputTransform(b));

        auto c = b.center, r = b.width*0.4f;

        if(rulerSides) drawRoundRuler(dr, c, r, rulerDiv0, rulerDiv1, endless);
        r *= 0.8f;

        float a0 = (endless ? 0 : 0.25f)*PIf;
        float a1 = (endless ? 2 : 1.75f)*PIf;

        dr.lineWidth = lwLine;
        dr.color = clLine;
        dr.circle(c, r, a0, a1);

        if(!isnan(nPos)){
          float n = 1-nPos;
          n = endless ? n.fract : n.clamp(0, 1);  //todo: ezt megcsinalni a range-val
          float a = mix(a0, a1, n);
          if(!endless && !isnan(nCenter)){
            float ac = mix(a0, a1, (1-nCenter).clamp(0, 1));
            dr.color = clThumb;
            if(ac>=a) dr.circle(c, r, a, ac);
                 else dr.circle(c, r, ac, a);
          }

          dr.lineWidth = lwThumb;
          dr.color = clThumb;
          auto v = vec2(sin(a), cos(a));
          dr.line(c, c+v*r);
        }
      }

    }

    // Draw Rulers
    protected void drawStraightRuler(Drawing dr, in bounds2 r, int cnt, int cnt2=-1, bool topleft=true){
      cnt--;
      if(cnt<=0) return;
      if(cnt2<0) cnt2 = cnt;
      dr.color = clRuler; dr.lineWidth = lwRuler;
      if(r.height < r.width){
        float c = r.center.y,
              b = r.top,
              t = r.bottom,
              j = r.left,
              ja = r.width/cnt;
        if(!topleft) swap(b, t);
        foreach(i; 0..cnt+1){
          dr.vLine(j, b, cnt2 && i%cnt2==0 ? t : c);
          j += ja;
        }
      }else{
        float c = r.center.x,
              b = r.left,
              t = r.right,
              j = r.top,
              ja = r.height/cnt;
        if(!topleft) swap(b, t);
        foreach(i; 0..cnt+1){
          dr.hLine(b, j, cnt2 && i%cnt2==0 ? t : c);
          j += ja;
        }
      }
    }

    protected void drawRoundRuler(Drawing dr, in vec2 center, float radius, int cnt, int cnt2=-1, bool endless=false){
      cnt--;
      if(cnt<=0) return;
      if(cnt2<0) cnt2 = cnt;
    //  radius *= (1/1.25f);
      dr.color = clRuler; dr.lineWidth = lwRuler;
      foreach(i; 0..cnt+1){
        float a = endless ? 2*PIf*i/cnt
                          : -0.25f*PIf + 1.5f*PIf*i/cnt;
        float co = -cos(a), si = -sin(a);
        dr.moveTo(center.x+co*radius, center.y+si*radius);
        float radius2 = radius*( !endless && (cnt2 && i%cnt2==0) ? 1.25f : 1.125f);
        dr.lineTo(center.x+co*radius2, center.y+si*radius2);
      }
    }
  }

  // Slider ///////////////////////////
  auto Slider(string file=__FILE__, uint line=__LINE__, V, T...)(ref V value, T args)
  if(isFloatingPoint!V || isIntegral!V)
  {
    mixin(id.M ~ enable.M ~ selected.M ~ range.M);

    //flipped range interval. Needed for vertical scrollbar
    const flipped = !_range.isOrdered;
    if(flipped) swap(_range.min, _range.max);

    //string props;
    static foreach(a; args){{ alias t = Unqual!(typeof(a));
      static if(isSomeString!t){
        //props = a; //todo: ennek is
        static assert(0, "string parameter in Slider is deprecated. Use {} delegate instead!");
      }
    }}

    float normValue = _range.normalize(flipped ? _range.max-value : value); // FLIP

    int wrapCnt;
    if(_range.isEndless){
      wrapCnt = normValue.floor.iround;  //todo: refactor endless wrapCnt stuff
      normValue = normValue-normValue.floor;
    }

    auto oldFh = style.fontHeight;
    if(theme != "tool") style.fontHeight = (fh*1.4f).to!ubyte; //note: scrollbar gets the thumbsize from fontHeight

    bool userModified;
    HitInfo hit;
    auto sl = new .Slider(id_, enabled, normValue, _range, userModified, actView.mousePos, style, hit, getStaticParamDef(SliderOrientation.auto_, args));

    style.fontHeight = oldFh;

    append(sl); push(sl, id_); scope(exit) pop;

    mixin(hintHandler);
    static foreach(a; args) static if(__traits(compiles, a())) a();

    if(userModified && enabled){

      if(_range.isEndless) normValue += wrapCnt-sl.wrapCnt;

      float f = _range.denormalize(normValue);
      static if(isIntegral!V) f = round(f);
      value = f.to!V;
      if(flipped) value = _range.max.to!V-value; // UNFLIP
    }

    //todo: what to return on from slider
    return userModified;
  }


};