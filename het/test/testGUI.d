//@exe
///@release

import het, het.ui;

enum Category{ Inputs, Draw2D, Text, Align, Sliders }

void UI_Category(Category category){
  with(Category) final switch(category){
    case Inputs:        UI_Inputs;      break;
    case Draw2D:        UI_TestDrawing; break;
    case Text:          UI_Text;        break;
    case Align:         UI_Align;       break;
    case Sliders:       UI_Sliders;     break;
  }
}

void UI_TestDrawing(){
  with(im) Row({ //todo: this should be coomable
    const bnd = bounds2(0, 0, 100, 100);

    margin = "2";
    innerSize = bnd.size;

    auto dr = new Drawing;

    dr.color= clWhite;
    dr.fillRect(bnd);

    dr.color = clBlack;
    dr.fontHeight = 1;

    //LineWidth/ pointSize
    dr.translate(0, 12);
    dr.fontHeight = 2; dr.textOut(0, -3, "pointSize, lineWidth"); dr.fontHeight = 1;
    foreach(i, lw; [0.05, 0.1, 0.2, 0.5, 1, 1.5, 2]){
      foreach(sgn; [false, true]){
        dr.pointSize = dr.lineWidth = lw * (sgn ? 1 : -1);
        auto x = sgn ? 0 : 11;
        dr.textOut(x, i*2, "%.2f".format(dr.lineWidth));
        dr.point(x+3, i*2+0.5);
        dr.hline(x+5, i*2+0.5, x+9);
      }
    }
    dr.pop;

    dr.translate(25, 12);
    dr.fontHeight = 2; dr.textOut(0, -3, "lineStipple"); dr.fontHeight = 1;
    dr.lineWidth =0.1;
    foreach (i, ls; EnumMembers!LineStyle){
      dr.lineStyle = ls;
      dr.textOut(0, i*2, ls.text);
      dr.hline(3, i*2+0.5, 12);
    }
    dr.lineStyle = LineStyle.normal;
    dr.pop;

    flags.clipChildren = true;
    addOverlayDrawing(dr);
  });


}

void UI_Inputs(){
  static InputsTester it;
  if(!it) it = new typeof(it);
  with(it){ update; UI; }
}

class InputsTester {  // Inputs //////////////////////////////////////////////////

  struct KeyComboRect {
    KeyComboEntry key;
    vec2 pos, size;

    float st = 0;

    auto bounds() { return bounds2(pos, pos+size); }

    void draw(Drawing dr){
      auto bc = key.valid ? mix(RGB(0x606060), clYellow, st) : clRed;

      dr.lineWidth = -1;

      auto b = bounds;
      dr.color = bc;
      dr.fillRect(b);

      dr.color = RGB(0x303030);
      dr.drawRect(b);

      dr.color = clWhite;
      dr.fontHeight = 0.8;
      dr.fontMonoSpace = false;
      while(dr.textWidth(key.text)>b.width) dr.fontHeight *= 0.9;
      dr.textOut(b.left, b.top+(b.height-dr.fontHeight)*.5 , key.text, b.width, HAlign.center);
    }

    void update(){
      if(key.active ) st = max(st, 1);
      st *= 0.66;
    }
  }

  KeyComboRect[] keys;
  string[] keyComboDump;

  this(){
    float x = 0, y = 0, x0 = 0;
    void nl(){ x = x0; y += 1; }
    void a(string s, float w = 1, float h = 1){ keys ~= KeyComboRect(KeyComboEntry(s), vec2(x, y), vec2(w, h)); x += w; }
    void b(string s, float w = 1){ foreach(e; s) a([e], w); }
    void c(string s, float w = 1){ foreach(e; s.split(',')) a(e, w); }

    //keyboard
//              x =2; c("F13,F14,F15,F16"); x+=.5; c("F17,F18,F19,F20"); x+=.5; c("F21,F22,F23,F24"); nl;
    a("Esc"); x+=1; c("F1,F2,F3,F4"); x+=.5; c("F5,F6,F7,F8"); x+=.5; c("F9,F10,F11,F12"); x+=.5; c("PrnScr,ScrLock,Pause"); x+=.5; c("NumLockState,CapsLockState,ScrLockState", 1.33); nl; y+=.5;
                                       b("`1234567890-="); a("Backspace", 2);  x+=.5; c("Ins,Home,PgUp");  x+=.5; c("NumLock,Num/,Num*,Num-"); nl;
    a("Tab"     , 1.5 );               b("QWERTYUIOP[]");  a("Enter", 1.5);    x+=.5; c("Del,End,PgDn");   x+=.5; c("Num7,Num8,Num9"); a("Num+", 1, 2); nl;
    a("CapsLock", 1.75);               b(`ASDFGHJKL;'\`);  a("Enter", 1.25);   x+=.5; x+=3;                x+=.5; c("Num4,Num5,Num6"); nl;
    a("LShift"  , 1.25); a("OEM_102"); b("ZXCVBNM,./");    a("RShift", 2.75);  x+=.5; x+=1; a("Up"); x+=1; x+=.5; c("Num1,Num2,Num3"); a("Enter",1,2); nl;
    a("LCtrl"   , 1.5 ); a("LWin", 1.25); a("LAlt", 1.25); a("Space", 5.75); a("RAlt", 1.25); a("RWin", 1.25); a("Menu", 1.25); a("RCtrl", 1.5); x+=.5; a("Left"); a("Down"); a("Right");  x+=.5; a("Num0", 2); a("Num."); nl;

    y+=.5; c("Shift,Ctrl,Alt,Win", 0.75);  x+=.25; c("Mail,Media,App1,App2,XBox"); x+=.25;  c("Vol+,Vol-,Mute");  x+=.25; c("Prev,Next,Stop,Play"); x+=.25; c("Back,Forward,Refresh,BrStop,Search,Favorites,HomePage"); nl; y+=.5;

    //key combos
    y+=1; a("Shift+A",2); a("Shift+Ctrl+Alt+F1",4); a("Ctrl+MMB",2);

    //mouse
    x = x0 = 24; y = 0;
    a("LMB", 1.5, 2); a("MMB", 0.75, 2); a("RMB", 1.5, 2); nl;
    y += 2;
    a("XB2"); nl; a("XB1"); nl;

    //XBox controller
    x = x0 = 0; y = 11;
    c("xiLB,xiRB,xiLS,xiRS,xiA,xiB,xiX,xiY,xiBack,xiStart,xiLeft,xiRight,xiUp,xiDown");
  }

  auto getBounds(){ return bounds2(0, 0, 28, 20).inflated(.5f); }

  void update(){
    keys.each!"a.update";

    keyComboDump = [];
    void dump(string s){ keyComboDump ~= s; }

    bool anyPressed = inputs.entries.values.map!(a => a.isButton && a.pressed).sum!=0;

    auto allKeys = inputs.entries.values.filter!(e => e.isButton && e.value).array.sort!((a,b)=>a.pressedTime<b.pressedTime, SwapStrategy.stable).map!"a.name".array,
         lastPressedKey = allKeys.empty?"" : allKeys[$-1],
         modifiers = allKeys.filter!(k => keyModifierCode(k)).array.dup.sort.array,
         keys = allKeys.filter!(k => !keyModifierCode(k)).array.dup.sort.array,
         modifierMask = keyModifierMask(modifiers),
         commonModifiers = keyModifierMaskToStrings(modifierMask),
         actualModifiers = modifiers.filter!(m => !commonModifiers.canFind(m)).array;

    static string[] accumulatedKeys;
    static int lastModifierMask;
    static int lastKeysLength;

    bool modifierMaskChanged = lastModifierMask!=modifierMask;

    if(modifierMaskChanged || !modifierMask || keys.length>1){
      accumulatedKeys.clear;
    }else{
      if(keys.length==1 && lastKeysLength==0){
        if(accumulatedKeys.length>=2) accumulatedKeys.clear;
        accumulatedKeys ~= keys[0];
      }
      if(keys.length>1) accumulatedKeys.clear;
    }
    lastKeysLength = keys.length.to!int;

    lastModifierMask = modifierMask;

    dump("Current combo: %s".format(allKeys));
    dump("mods : %s".format(modifiers)~" "~modifierMask.text);
    dump("cmods: %s".format(commonModifiers));
    dump("amods: %s".format(actualModifiers));
    dump("keys : %s".format(keys)~"    accumulated keys: %s".format(accumulatedKeys));

    string combo;
    if(!keys.empty){
      combo = (commonModifiers ~ keys).join('+');
    }else{
      combo = actualModifiers.join('+');
    }

    string accumulatedCombo;

    if(!keys.empty && accumulatedKeys.length==2){
      accumulatedCombo = (commonModifiers ~ accumulatedKeys.join('&')).join('+');
    }

    static string inputCombo; //this is the one that used in a KeyCombo Edit box.
    static int lastKeyCount;
    string recognizedInputCombo;
    static string[] recognizedInputComboHistory;
    int keyCount = allKeys.length.to!int;
    if(lastKeyCount<=keyCount){
      lastKeyCount = keyCount;
      inputCombo = accumulatedCombo.empty ? combo : accumulatedCombo;
    }else{
      if(keyCount==0){
        if(!inputCombo.empty){
          recognizedInputCombo = inputCombo;
          recognizedInputComboHistory = recognizedInputCombo ~ recognizedInputComboHistory.take(9);
        }
        inputCombo = "";
        lastKeyCount = 0;
      }
    }

    dump("current combo : %s".format(combo));
    dump("current input combo : %s".format(inputCombo));
    dump("recognized input combo : %s".format(recognizedInputComboHistory));

    string[] expectedAccumulatedCombos = ["Ctrl+K&U", "Ctrl+K&R", "Ctrl+K&W"]; //this is the input which must be specified to be able to process the 2 key sequences

    dump("expectedAccumulatedCombos : %s".format(expectedAccumulatedCombos));

    string actCombo = expectedAccumulatedCombos.canFind(accumulatedCombo) ? accumulatedCombo : combo;
    dump("act combo: %s".format(actCombo));

    string[] pressedCombos; //this one starts the timing for every KeyCombo's
    static string[] pressedComboHistory;
    if(anyPressed){
      pressedCombos ~= actCombo;

      if(keys.length>1) //more than 1 char is pressed at once: the last single on can also start an event
        pressedCombos ~= (commonModifiers ~ lastPressedKey).join('+');

      pressedComboHistory = pressedCombos ~ pressedComboHistory.take(9);
    }

    dump("pressed combo history: %s".format(pressedComboHistory));

    //press timers
    static int[string] ticks;

    //press down
    foreach(s; pressedCombos){
      if(s !in ticks){
        ticks[s] = 0; //start timer
      }
    }

    //increment
    foreach(ref t; ticks.byValue) t++;

    //release
    foreach(s0; ticks.byKey.array){  //kell a .array, mert menet kozben nem lehet torolni!!!
      auto s = s0.split('&')[$-1];
      auto kc = KeyComboEntry(s);
      foreach(k; kc.keys) if(!inputs[k].active){
        ticks.remove(s0);
        break;
      }
    }

    foreach(a; ticks.byKeyValue) dump(a.key~"   "~a.value.text);

    lastModifierMask = modifierMask;
  }

  void draw(Drawing dr){ with(dr){
    color = mix(BGR(0xcfb997), clBlack, 0.25f); fillRect(getBounds.inflated(0.5f));

    foreach(k; keys) k.draw(dr);

    //mouse
    {
      float x = 25.5, y = 3;
      fontHeight = 0.5;
      color = clWhite; textOut(x, y, "MX"); color = clYellow; textOut(x+1, y, "%.0f".format(inputs.MX.value), 1, HAlign.right); y += 0.5;
      color = clWhite; textOut(x, y, "MY"); color = clYellow; textOut(x+1, y, "%.0f".format(inputs["MY"].value), 1, HAlign.right); y += 0.5;
      color = clWhite; textOut(x, y, "MW"); color = clYellow; textOut(x+1, y, "%.1f".format(inputs["MW"].value), 1, HAlign.right); y += 1.5;
      color = clWhite; textOut(x-1.5, y, "MXraw"); color = clYellow; textOut(x+1, y, "%.0f".format(inputs["MXraw"].value), 1, HAlign.right); y += 0.5;
      color = clWhite; textOut(x-1.5, y, "MYraw"); color = clYellow; textOut(x+1, y, "%.0f".format(inputs["MYraw"].value), 1, HAlign.right); y += 0.5;

      foreach(idx, name; "xiLX,xiLY,xiRX,xiRY,xiLT,xiRT,xiT".split(',')){
        fontHeight = 0.5;
        color = clWhite;  textOut(15.25+idx*1.5+0.5, 11, name);
        color = clYellow; textOut(15.25+idx*1.5+0, 11.5, "%.2f".format(inputs[name].value), 1.5, HAlign.right);
      }
    }

    {
      string[] dump = keyComboDump;

      fontHeight = 0.5;
      color = clWhite;
      foreach(y, s; dump) dr.textOut(0, 12.5+y*0.5, s);
    }
  }}

  void UI(float scale = 32){
    with(im) Row({
      const bnd = getBounds*scale;

      margin = "2";
      innerSize = bnd.size;

      auto dr = new Drawing;
      dr.translate(-bnd.topLeft).scale(scale);
      this.draw(dr);
      dr.pop(2);

      flags.clipChildren = true;
      addOverlayDrawing(dr);
    });
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
      flags.wordWrap = false;
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

  Column({
    immutable scrollStates = ["off", "on", "auto"];
    immutable containerTypes = ["Row", "Column", "Container"];
    static hs=1, vs=1, ww=false, aw=false, ah=false;
    immutable defaultFonth = 72;
    static ubyte fonth = defaultFonth;
    static cellSize = ivec2(128);
    static containerType = "Column";
    Row(bold("AutoSize, WordWrap, ScrollBar tests"));
    Row({
      Text("Container ", BtnRow(containerType, containerTypes));
      Spacer;
      Text("fontHeight ");
      Slider(fonth, range(1, 255));
      if(Btn("Default("~defaultFonth.text~")")) fonth = defaultFonth; //todo: flex and \t not go well: the adjustment of \t is AFTER the flex, not before.
      Spacer;
      Text("width ");
      Slider(cellSize.x, range(0, 255));
      Text("height ");
      Slider(cellSize.y, range(0, 255));
    });
    Row(YAlign.top, {
      flags.yAlign = YAlign.top;
      Column({
        Row({ Text("hFlowConfig \t");
          auto f = getHFlowConfig(aw, ww, cast(ScrollState)hs);
          if(BtnRow(f)) final switch(f){
            case FlowConfig.autoSize   : aw = true;                               break;
            case FlowConfig.wrap       : aw = false; ww = true;                   break;
            case FlowConfig.noScroll   : aw = ww = false; hs = ScrollState.off;   break;
            case FlowConfig.scroll     : aw = ww = false; hs = ScrollState.on;    break;
            case FlowConfig.autoScroll : aw = ww = false; hs = ScrollState.auto_; break;
          }
        });
        Row({ Text("vFlowConfig \t");
          auto f = getVFlowConfig(ah, cast(ScrollState)vs).text;
          if(BtnRow(f, [FlowConfig.autoSize, FlowConfig.noScroll, FlowConfig.scroll, FlowConfig.autoScroll].map!text.array)) final switch(f.to!FlowConfig){
            case FlowConfig.autoSize   : ah = true;                          break;
            case FlowConfig.wrap       : //not supported for vertical
            case FlowConfig.noScroll   : ah = false; vs = ScrollState.off;   break;
            case FlowConfig.scroll     : ah = false; vs = ScrollState.on;    break;
            case FlowConfig.autoScroll : ah = false; vs = ScrollState.auto_; break;
          }
        });
        HR;
        ChkBox(aw, "autoWidth");
        ChkBox(ww, "wordWrap");
        Row({ Text("hScrollState \t"); BtnRow(hs, scrollStates); });
        HR;
        ChkBox(ah, "autoHeight");
        Row({ Text("vScrollState \t"); BtnRow(vs, scrollStates); });
      });

      void TestContainers(alias Cntr)(){
        foreach(idx, str; ["a", "abcdefg", "a\nb\nc", "abscefg\nABCDEF\n12345"]) Cntr({
          border = "1 normal silver";
          margin = "2";
          if(!aw) width  = cellSize.x;
          if(!ah) height = cellSize.y;
          with(flags){
            clipChildren = true;
            hScrollState = cast(ScrollState)hs;
            vScrollState = cast(ScrollState)vs;
            wordWrap = ww;
          }
          fh = fonth;
          Text(str);
          if(Btn("\U0001F327")) beep;

          static if(Cntr.stringof=="Container()") foreach(i, ref c; actContainer.subCells){
            const ph = i*0.2+float((QPS*0.3).fract)*2*PIf;
            c.outerPos = vec2((sin(ph)+1)*50, (cos(ph)+1)*50);
            auto g = cast(Glyph)c;
            if(g) g.bkColor = hsvToRgb((i*0.1f).fract, 1, 1).floatToRgb;
          }

        });

      }

      if(containerType=="Row") TestContainers!Row;
      if(containerType=="Column") TestContainers!Column;
      if(containerType=="Container") TestContainers!Container;

      //foreach(Cntr; AliasSeq!(Row, Column, Container)) static if(is()){

    });
  });

}}


class FrmMain: GLWindow { mixin autoCreate; // !FrmMain ////////////////////////////

  bounds2 lastWorkArea;
  bool showFPS=0;

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
      flags.clipChildren = true;

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

