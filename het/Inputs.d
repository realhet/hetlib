module het.inputs;

/+termonology:

input signal     ___________11111111111111111111111111_______________

InputEntry's functions:

active           ___________11111111111111111111111111_______________
pressed          ___________1________________________________________
released         ____________________________________1_______________
changed          ___________1________________________1_______________   *on digital input
hold             ___________11111111111111111111111111_______________

With KeyCombo's and ShiftStates:

pressed: only when the ShiftState is equals
hold: keeps it until the main keys is off, whatever the shift state is.
released: end of 'hold'

repeated: repeats while 'hold'   can specify intervals (first and the rest), defaults to system's settings
typed: same as repeated


K
U
Shift+K
Shift+K+U    //All must pressed
Shift+Ctrl+U

Ctrl+K&U     //sequential shortcuts: lastKeyCombo, lastKeyCombo2
Ctrl+U&K     //2nd modifier: if not present then can be nothing, or the same as the first modifier.

+/

//TODO: atnevezni het.inputs-ra;
//TODO: tesztelni, hogy 'F5' es 'Shift F5' jol mukodik-e egyutt.
//TODO: improve mousewheel precision: it is only giving 1's and 2's on 60FPS.

import het.utils,
       core.sys.windows.windows, core.sys.windows.winuser, std.json;

__gshared int[] virtualKeysDown;

// Utils /////////////////////////////////////////////////////////////////////

void spiGetKeyboardDelays(ref float d1, ref float d2){
  //Gets windows keyboard delays in seconds
  //note: The query takes 6microsecs only, so it can go into the update loop
  int val;

  SystemParametersInfoW(SPI_GETKEYBOARDDELAY, 0, &val, 0);
  d1 = remap(val, 0, 3, 0.250f, 1); //0: 250ms .. 3: 1sec

  SystemParametersInfoW(SPI_GETKEYBOARDSPEED, 0, &val, 0);
  d2 = 1.0f/remap(val, 0, 31, 2.5f, 37.5f); //0: 2.5hz .. 31: 40Hz
}

int[3] spiGetMouse(){
  int[3] val;
  SystemParametersInfoW(SPI_GETMOUSE, 0, &val, 0);
  return val;
}

int spiGetMouseSpeed(){
  int val;
  SystemParametersInfoW(SPI_GETMOUSESPEED, 0, &val, 0);
  return val;
}

void _notifyMouseWheel(float delta) //Must be called from outside, from a Window loop in Window.d
{
  MouseInputHandler.wheelDeltaAccum += delta;
}

char shiftedKey(char key){
  switch(key){
    case 'a':..case'z': return cast(char)(key - 'a' + 'A');
    case '0':..case'9': return ")!@#$%^&*("[key-'0'];
    case '`' : return '~';
    case '-' : return '_';
    case '=' : return '+';
    case '[' : return '{';
    case ']' : return '}';
    case ';' : return ':';
    case '\'': return '"';
    case '\\': return '|';
    case ',' : return '<';
    case '.' : return '>';
    case '/' : return '?';
    default:   return key;
  }
}

char unshiftedKey(char key){
  switch(key){
    case 'A':..case'Z': return cast(char)(key - 'A' + 'a');

    case ')': return '0';
    case '!': return '1';
    case '@': return '2';
    case '#': return '3';
    case '$': return '4';
    case '%': return '5';
    case '^': return '6';
    case '&': return '7';
    case '*': return '8';
    case '(': return '9';

    case '~': return '`' ;
    case '_': return '-' ;
    case '+': return '=' ;
    case '{': return '[' ;
    case '}': return ']' ;
    case ':': return ';' ;
    case '"': return '\'';
    case '|': return '\\';
    case '<': return ',' ;
    case '>': return '.' ;
    case '?': return '/' ;
    default:   return key;
  }
}

string shiftedKey(string s){
  if(s.length==1) return shiftedKey(s[0]).to!string;
  return s;
}

string unshiftedKey(string s){
  if(s.length==1) return unshiftedKey(s[0]).to!string;
  return s;
}

struct ClickDetector{

  enum doubleTicks    = 15,   //todo: use winuser.GetDoubleClickTime()
       longPressTicks = 30;

  bool pressing, pressed, released;
  bool clicked, doubleClicked, tripleClicked, nClicked;
  bool longPressed, longPressing, longClicked;
  int clickCount;

  uint tPressed, tPressedPrev;

  void update(bool state){
    //clear all the transitional bits
    pressed = released = clicked = doubleClicked = tripleClicked = nClicked = longPressed = longClicked = false;

    pressed  =  state && !pressing;
    released = !state &&  pressing;
    pressing = state;

    if(pressed){
      tPressedPrev = tPressed;
      tPressed = application.tick;
      if(tPressed-tPressedPrev <= doubleTicks){
        switch(++clickCount){
          case 1:doubleClicked = true; break;
          case 2:tripleClicked = true; break;
          default: nClicked = true;
        }
      }else{
        clickCount = 0;
      }
    }else if(released){
      if(longPressing.chkClear){
        longClicked = clicked = true;
      }else{
        if(clickCount==0) clicked = true;
      }
    }

    const pressDuration = pressing ? application.tick-tPressed : 0;
    enum enableDoubleLongPress = true;
    if(pressDuration>longPressTicks && (enableDoubleLongPress || clickCount==0)){
      if(longPressing.chkSet){
        longPressed = true;
        clickCount = 0;
      }
    }

    if(application.tick-tPressed > doubleTicks) clickCount = 0;
  }


  string toString() const{
    return format!"%s%s %s%s %s"(
      pressing ? "P":"_",
      pressed ? "+" : clicked?"-": " ",
      longPressing ? "P":"_",
      longPressed ? "+" : longClicked?"-": " ",
      doubleClicked ? "2" : tripleClicked ? "3" : nClicked ? "N" : " "
    );

/*    bool pressing, pressed, released;
    bool clicked, fistClicked, doubleClicked, tripleClicked, quadClicked, manyClicked;
    bool longPressed, longPressing, longClicked;
    int clickCount;

    uint tPressed, tPressedPrev;*/

  }
}

/////////////////////////////////////////////////////////////////////////////
///  KeyCombo                                                             ///
/////////////////////////////////////////////////////////////////////////////

immutable keyModifiers = ["Ctrl", "Shift", "Alt", "Win"];

int keyModifierCode(string key){
  if(key.empty) return 0;
  foreach(i, a; keyModifiers){
    if(key==a || key[0].among('L', 'R') && key[1..$]==a){
      return 1<<cast(int)i;
    }
  }
  return 0;
}

int keyModifierMask(in string[] keys){
  int res; foreach(k; keys) res |= k.keyModifierCode; return res;
}

auto keyModifierMaskToStrings(int mask){
  string[] res;
  foreach(i, s; keyModifiers)
    if(mask & (1<<cast(int)i)) res ~= s;
  return res;
}

string commonKeyModifier(string key){ //eg: LShift -> Shift
  if(!key.empty && keyModifiers.canFind(key[1..$]) && key[0].among('L', 'R')) return key[1..$];
  return key;
}

struct KeyComboEntry{ //a single keycombo like F1, LShift+RShift, Ctrl+Alt, Ctrl+Num+, Ctrl+K+U
                      //todo: Ctrl+KU is sequential!
  string[] keys;

  this(string s){
    enum plusMark = "@PLUS@";

    s = s.replace("++", plusMark~"+"); //the first plus from ++ is preserved
    if(s.startsWith("+")) s = plusMark~s[1..$];
    if(s.endsWith("+")) s = s[0..$-1]~plusMark;

    keys = s.split('+')
            .map!(s => s.strip.replace(plusMark, "+"))
            .filter!(s => !s.empty)
            .array;
  }

  string toString() const { return keys.join('+'); }

  private bool validIdx(size_t n) const { return n<keys.length; }
  InputEntry entries(size_t n) { return validIdx(n) ? inputs.entries.get(keys[n], null) : null; }
  bool valid(size_t n) { return entries(n) !is null; }
  bool valid() { return !keys.empty && iota(keys.length).map!(i => valid(i)).all; }

  int keyModifierMask() const { return keys.keyModifierMask; }

  bool pressed ()  {
    return valid && inputs.keyModifierMask==keyModifierMask && entries(keys.length-1).pressed;
  }

  bool active  ()  { return valid && inputs.keyModifierMask==keyModifierMask && entries(keys.length-1).active; }
  bool released()  { return valid && inputs.keyModifierMask==keyModifierMask && entries(keys.length-1).released; }
  bool typed   ()  { return valid && inputs.keyModifierMask==keyModifierMask && entries(keys.length-1).repeated; }
}

struct KeyCombo{
  KeyComboEntry[] combos;

  this(string s){
    combos = s.split(' ')
              .map!strip
              .filter!(x => !x.empty)
              .map!(x => KeyComboEntry(x))
              .array;
  }

  string toString() const { return combos.map!text.join('+'); }

  bool active  () { return combos.any!"a.active"; }  alias hold = active; alias down = active;
  bool pressed () { return combos.any!"a.pressed"; }
  bool typed   () { return combos.any!"a.typed"; }
  bool released() { return combos.any!"a.released"; }

//  bool changed () { return combos.map!changed .any; }
}

//TODO: az egerklikkeles (pressed) csak akkor megy at, ha az update interval rovidebb volt a klikkeles hosszanal. Ezt valahogy javitani.

/////////////////////////////////////////////////////////////////////////////
///  InputHandler base classes                                            ///
/////////////////////////////////////////////////////////////////////////////

alias inputs = Singleton!InputManager;

enum InputEntryType{ //Operation      Examples
  digitalState,   //=0 Off, !=0 On.        a switch
  analogState,    //[0..1]                 Volume potmeter, Light level, Piano key state
  digitalButton,  //=0 Off, !=0 On.        normally released. Keyboard, MouseButton
  analogButton,   //[0..1]                 normally released. Left/Right trigger, piano note
  absolute,       //any value              Mouse ScreenPos, position of a playback time slider
  delta,          //any value              Mouse Wheel, Jog wheel
}

class InputEntry{
  bool opCast(T:bool)() const { return active; }

  const InputHandlerBase owner;
  const string name;
  const InputEntryType type;
  float value=0, lastValue=0, pressedTime=0;

  string category() const { return owner.category; }

  this(InputHandlerBase owner, InputEntryType type, string name, float value = 0){
    //validate name
    enforce(!name.empty && name[0]!='+', `InputEntry() invalid name "%s"`.format(name));

    this.owner = owner;
    this.name = name;
    this.type = type;
    this.value = value;
    lastValue = value;
  }

  bool isButton() const { return type==InputEntryType.digitalButton || type==InputEntryType.analogButton; }

  float delta () const { return value -lastValue; }
  bool changed() const { return value!=lastValue; }
  bool active() const { return value!=0; }
  bool lastActive () const { return lastValue!=0; }
  bool pressed() const { return active && !lastActive; }
  bool released()const { return !active && lastActive; }

  float activeDuration() const{
    if(active) return inputs.now-pressedTime;
          else return 0;
  }

  bool longPress() const{ return activeDuration >= inputs.longPressDuration; }

  bool down() const { return  active; }
  bool up() const { return !active; }


  private{
    bool repeated_;
    double repeatNextTime = 0;
  }

  bool repeated()const { return repeated_; }

  void _updateRepeated(double now){
    repeated_ = inputs.repeatLogic(active, pressed, repeatNextTime);
  }

}

class InputHandlerBase{
  string category;
  InputEntry[] entries;
  void update() { }
  this() { }
}

class InputManager{ //! InputManager /////////////////////////////////
  static{
    float longPressDuration = 0.5;

    float repeatDelay1 = 0.5;   //updated in every frame
    float repeatDelay2 = 0.125; //updated in every frame

    int mouseSpeed = 10; //updated in every frame
    int[3] mouseThresholds = [6, 10, 1]; //updated in every frame
  }
private:
  bool initialized = false;

  InputEntry nullEntry;

  void rehashAll() { entries.rehash; handlers.rehash; }
  void error(string s) { throw new Exception("InputManager: "~s); }

  double now; //local fast time in seconds
  //todo: replace this with DateTime and prioper seconds handling.
public:
  InputHandlerBase[string] handlers;
  InputEntry[string] entries;

  KeyboardInputHandler keyboardInputHandler;

  this(){
    //add the nullEntry
    nullEntry = new InputEntry(null, InputEntryType.digitalState, "null");
    entries [nullEntry.name] = nullEntry;

    //register common handlers
    registerInputHandler(keyboardInputHandler = new KeyboardInputHandler);
    registerInputHandler(new MouseInputHandler);
    registerInputHandler(new PotiInputHandler);
    registerInputHandler(new XInputInputHandler);
  }

  void registerInputHandler(InputHandlerBase h){
    if(h.category in handlers) error(`Input handler category "`~h.category~`" already registered.`);
    foreach(e; h.entries) if(e.name in entries) error(`Input entry "`~e.name~`" already registered.`);

    //add the category and the entries to the pool
    handlers[h.category] = h;
    foreach(e; h.entries) entries[e.name] = e;
    rehashAll;
  }

  void unregisterInputHandler(InputHandlerBase h){
    handlers.remove(h.category);
    foreach(e; h.entries) entries.remove(e.name);
    rehashAll;
  }

  void update() {
    now = QPS_local;

    //ensure that inputentry is untouched
    with(nullEntry){
      if(value || lastValue || pressedTime){
        WARN("nullEntry was disturbed.");
        value=0; lastValue=0; pressedTime=0;
      }
    }

    clearDeltas;
    foreach(h; handlers) h.update;

    spiGetKeyboardDelays(repeatDelay1, repeatDelay2); //todo: this is only needed once a sec, dunno how slow it is.
    mouseSpeed = spiGetMouseSpeed;
    mouseThresholds = spiGetMouse;


    foreach(e; entries){
      if(e.pressed) e.pressedTime = now;
      e._updateRepeated(now);
    }
  }

  void clearDeltas() {
    foreach(e; entries) e.lastValue = e.value;
  }

  auto opIndex(string name){ //todo: this should be const. And there should be access(name) which has read/write access.

    struct InpitEntryWrapper{ //note: this wrapper is needed for opCast!(bool) to work properly. For classes, D doesn't call opCast, it checks the pointer.
      alias entry this;
      InputEntry entry;
      bool opCast(T:bool)() { return entry ? entry.active : false; }
    }

    auto doit(){
      if(name=="") return nullEntry;
      auto e = name in entries;
      if(e is null) e = translateKey(name) in entries; //try to translate
      return e ? *e : nullEntry;
    }

    return InpitEntryWrapper(doit);
  }

  auto opDispatch(string name)(){
    return opIndex(name);
  }

  /// Tries to interpret a key's name. Searching the closest in inputs.entries.
  string translateKey(string key){
    //empty string is empty
    if(key=="") return "";
    //can find in inputs
    if(key in entries) return key;

    //try to find it in a dynamic dictionary
    static string[string] dict;
    if(auto p = key in dict) return *p;

    //compress words to letters
    auto words = key.split(' ');
    foreach(ref word; words){
      if(word.among!sameText("Left", "Right", "Middle", "Mid", "Mouse", "Click", "Button", "Btn", "Wheel")) word = word[0..1].uc;
      else if(word.sameText("Control")) word = "Ctrl";
    }

    //join words and try to translate
    string trans = words.join;
    static string[string] wdict;
    if(wdict is null) wdict = ["LMC": "LMB",  "MMC": "MMB",  "RMC": "RMB",  "M3": "MMB",  "M4": "MB4",  "M5": "MB5",  "MWDown": "MWDn"];
    if(auto p = trans in wdict) trans = *p;

    //fint the translated result in inputs.entries
    string found;
    if(trans in entries){ //case sens
      found = trans;
    }else{ //case insens
      auto keys = entries.keys;
      auto i = keys.map!lc.countUntil(trans.lc);
      if(i>=0) found = keys[i];
    }
    if(found=="") ERR(format!"Can't find transformed key in inputs.entries: %s -> %s"(key.quoted, trans.quoted));

    //save the transformed name
    dict[key] = found;
    return found;
  }

  //query functions for key combo access
  private{

    //todo: use KeyCombo struct!
    enum QueryMode { Active, Pressed, Typed }
    bool _query(string keys, QueryMode mode){  //format: Alt+F1 K Ctrl+K
      //more than one keys in OR relation
      if(keys.canFind(' ')){//call it recursively
        foreach(k; strip(keys).split(' ')) if(_query(k, mode)) return true;
        return false;
      }

      //all key must be down
      bool allDown = true;
      auto keyList = keys.split('+').map!strip.array;
      if(keyList.empty) allDown = false; //empty combo

      foreach(key; keyList) if(!this[key].value){ allDown = false; break; }

      if(!allDown) return false; //not this key combo

      final switch(mode){
        case QueryMode.Active : return true;
        case QueryMode.Pressed: return this[keyList[$-1]].pressed; //todo: wrong
        case QueryMode.Typed  : return this[keyList[$-1]].repeated; //todo: wrong
//        case QueryMode.Released:return this[k[$-1]].released; //todo: wrong
      }
    }

  }

  bool active (string keys) { return _query(keys, QueryMode.Active ); }
  bool pressed(string keys) { return _query(keys, QueryMode.Pressed); }
  bool typed  (string keys) { return _query(keys, QueryMode.Typed  ); }
//  bool released(string keys) { return _query(keys, QueryMode.Released ); }

public: //standard stuff
  auto mouseAct()   const { return vec2(entries["MX"].value, entries["MY"].value); }
  auto mouseDelta() const { return vec2(entries["MX"].delta, entries["MY"].delta); }
  bool mouseMoved() const { return entries["MX"].changed || entries["MY"].changed; }
  float mouseWheelDelta() const { return entries["MW"].delta; }

  int keyModifierMask() {
    int res;
    foreach(i, s; keyModifiers) if(entries[s].active) res += 1<<i;
    return res;
  };
  alias modifiers = keyModifierMask;

  // keyboard emulation ///////////////////////////////////

  bool validKey(string key){ return strToVk(key)!=0; }

  static bool isMouseBtn   (int vk){ return vk.among(VK_LBUTTON, VK_RBUTTON, VK_MBUTTON, VK_XBUTTON1, VK_XBUTTON2)>0; } //todo: these are slow...
  static bool isExtendedKey(int vk){ return vk.among(VK_UP, VK_DOWN, VK_LEFT, VK_RIGHT, VK_HOME, VK_END, VK_PRIOR, VK_NEXT, VK_INSERT, VK_DELETE)>0;
   }

  bool isMouseBtn(string key){ return isMouseBtn(strToVk(key)); } //todo: these are slow...

  void pressKey(ubyte vk, bool press=true){
    if(!vk) return;
    if(isMouseBtn(vk)){
      void a(int d, int u, int x=0){ mouse_event(press ? d : u , 0, 0, x, 0); }
      switch(vk){
        case VK_LBUTTON  : a(MOUSEEVENTF_LEFTDOWN  , MOUSEEVENTF_LEFTUP  ); break;
        case VK_RBUTTON  : a(MOUSEEVENTF_RIGHTDOWN , MOUSEEVENTF_RIGHTUP ); break;
        case VK_MBUTTON  : a(MOUSEEVENTF_MIDDLEDOWN, MOUSEEVENTF_MIDDLEUP); break;
        case VK_XBUTTON1 : a(MOUSEEVENTF_XDOWN     , MOUSEEVENTF_XUP     , XBUTTON1); break;
        case VK_XBUTTON2 : a(MOUSEEVENTF_XDOWN     , MOUSEEVENTF_XUP     , XBUTTON2); break;
        default: enforce(0, `Unknown mouse button %s`.format(vk));
      }
    }else{
      //Note: keybd_event, SendInput: multimedia keys that launch apps aren't working. Sound volume, and play controls are working.

      const flags = (press ? 0 : KEYEVENTF_KEYUP) | (isExtendedKey(vk) ? KEYEVENTF_EXTENDEDKEY : 0);

      enum method = 0;

      static if(method==0){
        //const sc = MapVirtualKeyA(vk, MAPVK_VK_TO_VSC).to!ubyte; <--- not needed
        keybd_event(vk, 0, flags, 0);
      }else static if(method==1){
        INPUT input;
        input.type = INPUT_KEYBOARD;
        with(input.ki){
          wVk = vk;
          //wScan = MapVirtualKey(vk, 0).to!ushort; //<--- not needed
          dwFlags = flags;
        }
        SendInput(1, &input, INPUT.sizeof);
      }else static assert(0, "invalid keyboard emulation method index");
    }
  }

  void releaseKey(ubyte vk){ pressKey(vk, false); }

  void pressKey(string key, bool press=true){
    //if(key=="") return; //empty is  valid
    //auto vk = enforce(strToVk(key), "Inputs.keyPress: Invalid key "~key.quoted);
    const vk = strToVk(key);
    if(!vk) return;
    pressKey(vk, press);
  }

  void releaseKey(string key){ pressKey(key, false); }

  void typeKey(string key){
    //todo: accent handling
    //todo: shift symbol handling
    const needShift = key.length==1 && (key[0].isLetter && ((key[0].toUpper==key[0]) != inputs["CapsLockState"].active)) && !inputs["Shift"].down;

    if(needShift) pressKey("LShift");
    pressKey(key);
    releaseKey(key);
    if(needShift) releaseKey("LShift");
  }

  void typeText(string s){ foreach(ch; s) typeKey(ch.to!string); }

  // keycode conversion //////////////////////////////////////

  ubyte strToVk(string key){ return keyboardInputHandler.strToVk(key); }
  string vkToStr(ubyte vk){ return keyboardInputHandler.vkToStr(vk); }

  string vkToUni(ubyte vk, Flag!"shift" shift, Flag!"altGr" altGr){
    if(!vk) return "";
    static ubyte[256] keymap = ubyte(0).repeat(256).array;

    keymap[VK_SHIFT  ] = shift ? 0xFF : 0;
    keymap[VK_CONTROL] = altGr ? 0xff : 0;
    keymap[VK_MENU   ] = altGr ? 0xff : 0;

    wchar[32] buf;
    const res = ToUnicode(vk, 0, keymap.ptr, buf.ptr, buf.length, 0);
    if(res!=1) return "";//"\uFFFD";
    return buf.toStr;
  }

  string vkToUni(ubyte vk, int flags){ return vkToUni(vk, flags&1 ? Yes.shift : No.shift, flags&2 ? Yes.altGr : No.altGr); }
  string strToUni(string key, int flags){ return vkToUni(strToVk(key), flags); }
  string strToUni(string key, Flag!"shift" shift, Flag!"altGr" altGr){ return vkToUni(strToVk(key), shift, altGr); }

  //this version uses the current keystate
  string vkToUni(ubyte vk){
    wchar[32] buf;
    const res = ToUnicode(vk, 0, keyboardInputHandler.keys.ptr, buf.ptr, buf.length, 0);
    if(res!=1) return "";//"\uFFFD";
    return buf.toStr;
  }
  string strToUni(string key){ return vkToUni(strToVk(key)); }

  // repeat logic /////////////////////////////////////

  bool repeatLogic(in bool active, in bool pressed, ref double repeatNextTime, in float delay1, in float delay2){
    if(active){ //todo: at kene terni tick-re...
      //note: 'now' is saved in every update cycle. That's why this fucnt is not static.
      if(pressed){
        repeatNextTime = now+repeatDelay1;
        return true;
      }
      if(now>=repeatNextTime){
        repeatNextTime = now+repeatDelay2;
        return true;
      }
    }
    return false;
  }

  bool repeatLogic(in bool active, in bool pressed, ref double repeatNextTime){
    return repeatLogic(active, pressed, repeatNextTime, repeatDelay1, repeatDelay2);
  }

}


/////////////////////////////////////////////////////////////////////////////
///  Input Emulator                                                       ///
/////////////////////////////////////////////////////////////////////////////

class InputEmulator{
  // redirects keyboard and mouse inputs to windows
  string[] activeKeys, lastActiveKeys, pressedKeys, releasedKeys;
  string repeatedKey, lastRepeatedKey;
  double repeatState;
  bool repeatedKeyPressed;

  void updateKeyState(string[] activeKeys_){
    lastActiveKeys = activeKeys;
    activeKeys = activeKeys_.sort.uniq.array;

    //detect pressed and released keys. Using only the state of activeKeys and lastActiveKeys.
    pressedKeys  = activeKeys.filter!(k => !lastActiveKeys.canFind(k)).array;
    releasedKeys = lastActiveKeys.filter!(k => !activeKeys.canFind(k)).array;

    foreach(k; releasedKeys) inputs.releaseKey(k);
    foreach(k; pressedKeys) inputs.pressKey(k);

    if(!releasedKeys.empty) repeatedKey = "";
    pressedKeys.filter!(k => !inputs.isMouseBtn(k)).each!(k => repeatedKey = k); //all keys can be repeated except mouse buttons
    repeatedKeyPressed = inputs.repeatLogic(repeatedKey!="", lastRepeatedKey != repeatedKey, repeatState);
    if(repeatedKeyPressed && !pressedKeys.canFind(repeatedKey))
      inputs.pressKey(repeatedKey);

    //update history
    lastRepeatedKey = repeatedKey;
    lastActiveKeys = activeKeys;
  }

  protected vec2 lastMMoveFraction;

  void mouseMove1(float nx, float ny){
    lastMMoveFraction += vec2(nx, ny);
    ivec2 r = iround(lastMMoveFraction);
    if(r) mouse_event(MOUSEEVENTF_MOVE, r.x, r.y, 0, 0);
    lastMMoveFraction -= r;
  }


  void mouseMove(float nx, float ny, float fastOrSlow){
    float f(float x){
      return x<0 ? -f(-x)
                 : max(0, x*1.125-0.1); //deadzone
    }

    auto len = vec2(nx, ny).length;
    auto speed = len>0.95 ? 5 : 2;  //turbo speed at the very ends

    if(fastOrSlow!=0){
      float a = fastOrSlow.sqr.remap(0, 1, 1, 4);
      if(fastOrSlow<0) a = 1/a;
      speed *= a;
    }

    mouseMove1(f(nx)*speed, f(ny)*-speed);
  }

  void mouseWheel(float speed/+ -1..1 range +/, float fastOrSlow){
    if(speed.abs>0.05f/+deadZone+/){
      speed = signedsqr(speed) * 15; //base wheel speed
      if(fastOrSlow!=0){
        float f = fastOrSlow.sqr.remap(0, 1, 1, 5);
        if(fastOrSlow<0) f = 1/f;
        speed *= f;
      }
      if(const i = speed.iround) mouse_event(MOUSEEVENTF_WHEEL, 0, 0, i, 0);
    }
  }


}


/////////////////////////////////////////////////////////////////////////////
///  Keyboard input handler                                               ///
/////////////////////////////////////////////////////////////////////////////

class KeyboardInputHandler: InputHandlerBase {
  ubyte[256] keys;
private:
  InputEntry[256] emap;

  //maps to and from virtual keycodes
  ubyte[string] _nameToVk;
  string[ubyte] _vkToName;

  void initMaps(){
    foreach(idx, e; emap)if(e){
      _nameToVk[e.name] = idx.to!ubyte;
      _vkToName[idx.to!ubyte] = e.name;
    }
  }

  InputEntry
    eWin,  //there is no Win = LWin | RWin key on the map, so emulate it.
    eCapsLockState, eNumLockState, eScrLockState, //toggled states
    eMWUp, eMWDn; //Mouse Wheel up/down as buttons reacting to movement

  void add(int vk, string name){
    if(emap[vk]) throw new Exception("KeyboardInputHandler.add("~name~") Duplicated vk: "~text(vk));
    auto e = new InputEntry(this, InputEntryType.digitalButton, name);
    emap[vk] = e;
    entries ~= e;
  }

public:
  this(){
    category = "kbd";

    void special(ref InputEntry e, string name, bool isState=false){ e = new InputEntry(this, isState ? InputEntryType.digitalState : InputEntryType.digitalButton, name); entries ~= e; }
    special(eWin          , "Win"          );
    special(eCapsLockState, "CapsLockState", true);
    special(eNumLockState , "NumLockState" , true);
    special(eScrLockState , "ScrLockState" , true);
    special(eMWUp         , "MWUp");
    special(eMWDn         , "MWDn");

    //Top row
    add(VK_ESCAPE, "Esc");
    foreach(i; 0..24) add(VK_F1+i, "F"~text(i+1));
    add(VK_SNAPSHOT, "PrtScn");
    add(VK_SCROLL, "ScrLock");
    add(VK_PAUSE, "Pause");

    //Numpad
    add(VK_NUMLOCK, "NumLock");  add(VK_DIVIDE  , "Num/");  add(VK_MULTIPLY, "Num*");
    add(VK_ADD    , "Num+");     add(VK_SUBTRACT, "Num-");  add(VK_DECIMAL , "Num.");
    foreach(i; 0..10) add(VK_NUMPAD0+i, "Num"~text(i));  //VK_RETURN is the same on NumPad.

    //Ins, Home...
    add(VK_INSERT, "Ins");  add(VK_HOME, "Home");  add(VK_PRIOR, "PgUp"  );
    add(VK_DELETE, "Del");  add(VK_END , "End" );  add(VK_NEXT , "PgDn");

    //Arrows
                           add(VK_UP  , "Up"  );
    add(VK_LEFT, "Left");  add(VK_DOWN, "Down");  add(VK_RIGHT, "Right");

    //Special keys
    add(VK_OEM_1, ";"); add(VK_OEM_2, "/"); add(VK_OEM_3, "`"); //TODO: ` nem lehet, mert valamiert beszarik tole
    add(VK_OEM_4, "["); add(VK_OEM_5, `\`); add(VK_OEM_6, "]");
    add(VK_OEM_7, "'"); add(VK_OEM_8, "OEM_8");
    add(VK_OEM_PLUS , "=");  add(VK_OEM_COMMA , ",");
    add(VK_OEM_MINUS, "-");  add(VK_OEM_PERIOD, ".");
    add(VK_OEM_102, "OEM_102"); //hosszu 'i' a magyaron
    add(VK_APPS, "Menu"); //windows menu button

    //enter, bs, tab, caps, space
    add(VK_RETURN, "Enter");  add(VK_BACK , "Backspace");  add(VK_CAPITAL, "CapsLock");
    add(VK_TAB   , "Tab"  );  add(VK_SPACE, "Space"    );

    //modifiers, win/menus
    add(VK_SHIFT  , "Shift");  add(VK_LSHIFT  , "LShift");  add(VK_RSHIFT  , "RShift");
    add(VK_CONTROL, "Ctrl" );  add(VK_LCONTROL, "LCtrl" );  add(VK_RCONTROL, "RCtrl" );
    add(VK_MENU   , "Alt"  );  add(VK_LMENU   , "LAlt"  );  add(VK_RMENU   , "RAlt"  );
                               add(VK_LWIN    , "LWin"  );  add(VK_RWIN    , "RWin"  ); //Win is added manually

    //AlphaNumerics
    foreach(i; 0..10) add('0'+i, text(i)); //numbers
    foreach(char i; 'A'..'Z'+1) { add(i, to!string(i)); }

    //Mouse
    add(VK_LBUTTON , "LMB"); add(VK_RBUTTON , "RMB");  add(VK_MBUTTON, "MMB");
    add(VK_XBUTTON1, "MB4"); add(VK_XBUTTON2, "MB5"); //back, fwd buttons on mouse

    //Multimedia
    add(7                       , "XBox"); //Ubdocumented xbox guide bitton
    add(VK_LAUNCH_MAIL          , "Mail");
    add(VK_LAUNCH_MEDIA_SELECT  , "Media");
    add(VK_LAUNCH_APP1          , "App1");
    add(VK_LAUNCH_APP2          , "App2");

    add(VK_VOLUME_DOWN          , "Vol-");
    add(VK_VOLUME_UP            , "Vol+");
    add(VK_VOLUME_MUTE          , "Mute");
    add(VK_MEDIA_NEXT_TRACK     , "Next");
    add(VK_MEDIA_PREV_TRACK     , "Prev");
    add(VK_MEDIA_STOP           , "Stop");
    add(VK_MEDIA_PLAY_PAUSE     , "Play");

    add(VK_BROWSER_BACK         , "Back");
    add(VK_BROWSER_FORWARD      , "Forward");
    add(VK_BROWSER_REFRESH      , "Refresh");
    add(VK_BROWSER_STOP         , "BrStop");
    add(VK_BROWSER_SEARCH       , "Search");
    add(VK_BROWSER_FAVORITES    , "Favorites");
    add(VK_BROWSER_HOME         , "HomePage");


//Todo: add multimedia keys
/*  unused extras
    add(VK_CANCEL, "VK_CANCEL");
    add(VK_XBUTTON1, "VK_XBUTTON1");
    add(VK_XBUTTON2, "VK_XBUTTON2");
    add(VK_CLEAR, "VK_CLEAR");
    add(VK_KANA, "VK_KANA");
    add(VK_HANGEUL, "VK_HANGEUL");
    add(VK_HANGUL, "VK_HANGUL");
    add(VK_JUNJA, "VK_JUNJA");
    add(VK_FINAL, "VK_FINAL");
    add(VK_HANJA, "VK_HANJA");
    add(VK_KANJI, "VK_KANJI");
    add(VK_CONVERT, "VK_CONVERT");
    add(VK_NONCONVERT, "VK_NONCONVERT");
    add(VK_ACCEPT, "VK_ACCEPT");
    add(VK_MODECHANGE, "VK_MODECHANGE");
    add(VK_SELECT, "VK_SELECT");
    add(VK_PRINT, "VK_PRINT");
    add(VK_EXECUTE, "VK_EXECUTE");
    add(VK_HELP, "VK_HELP");
    add(VK_SLEEP, "VK_SLEEP");
    add(VK_SEPARATOR, "VK_SEPARATOR");
    add(VK_PROCESSKEY, "VK_PROCESSKEY");
    add(VK_PACKET, "VK_PACKET");
    add(VK_ATTN, "VK_ATTN");
    add(VK_CRSEL, "VK_CRSEL");
    add(VK_EXSEL, "VK_EXSEL");
    add(VK_EREOF, "VK_EREOF");
    add(VK_PLAY, "VK_PLAY");
    add(VK_ZOOM, "VK_ZOOM");
    add(VK_NONAME, "VK_NONAME");
    add(VK_PA1, "VK_PA1");
    add(VK_OEM_CLEAR, "VK_OEM_CLEAR");*/

    initMaps;
  }

  override void update(){
    //this sucks when not in focus, or the mouse is not moving over it -> GetKeyboardState(&keys[0]);

    const t0 = QPS;
    foreach(vk; 0..256) if(emap[vk]){
      const s = GetAsyncKeyState(vk);
      keys[vk] = cast(ubyte)(s>>8);
    }

    static ubyte shrink(int a){ return a&1 | (a>>8) & 0x80; }

    foreach(vk; [VK_CAPITAL, VK_SCROLL, VK_NUMLOCK]) keys[vk] = shrink(GetKeyState(vk));

    int[] ks;
    foreach(vk; 0..256){
      int down = keys[vk]&0x80 ? 1 : 0;
      if(emap[vk]){
        emap[vk].value = down;
      }
      if(down) ks ~= vk;
    }

    virtualKeysDown = ks;

    //manual things
    eWin.value = max(emap[VK_LWIN].value, emap[VK_RWIN].value); //Win = LWin || RWin

    eCapsLockState.value = keys[VK_CAPITAL]&1;
    eNumLockState .value = keys[VK_NUMLOCK]&1;
    eScrLockState .value = keys[VK_SCROLL ]&1;

    //eMWUp and eMWDn is updated from the mouse handler

//    foreach(int i; 0..256) if(keys[i]&0x80) write(" ", i); writeln;

    //print(QPS-t0);
  }

  ubyte strToVk(string key){ return _nameToVk.get(key, ubyte(0)); }
  string vkToStr(ubyte vk){ return _vkToName.get(vk, ""); }
}


/////////////////////////////////////////////////////////////////////////////
///  Mouse movement input handler                                         ///
/////////////////////////////////////////////////////////////////////////////

class MouseInputHandler: InputHandlerBase {
private:
  InputEntry mx, my, mw, mxr, myr, mwUp, mwDn;
  static float wheelDeltaAccum = 0;
public:
  this(){
    category = "mouse";

    mx = new InputEntry(this, InputEntryType.absolute, "MX");
    my = new InputEntry(this, InputEntryType.absolute, "MY");
    mw = new InputEntry(this, InputEntryType.delta   , "MW");

    mxr = new InputEntry(this, InputEntryType.delta, "MXraw");
    myr = new InputEntry(this, InputEntryType.delta, "MYraw");

    entries ~= [mx, my, mw, mxr, myr];
  }

  override void update(){
    if(application.handle){
      auto st = DInput.getMouseState;
      mxr.value += st.lX;
      myr.value += st.lY;
    }
    if(slowMouseEnabled){
      slowMouseUpdate;
      mx.value = slowMousePos.x;
      my.value = slowMousePos.y;
    }else{
      POINT p;
      if(GetCursorPos(&p)){
        mx.value = p.x;
        my.value = p.y;
      }
    }
    mw.value += wheelDeltaAccum;  wheelDeltaAccum = 0;

    //mouseWheel up/down as buttons
    if(mwUp is null){ mwUp = inputs["MWUp"]; mwDn = inputs["MWDn"]; }
    mwUp.value = mw.delta>0 ? 1 : 0;
    mwDn.value = mw.delta<0 ? 1 : 0;
  }
}

// DirectInput mouse & gamepad ///////////////////////////////////////////////////

private{
  enum
    DIRECTINPUT_VERSION = 0x0800,

    DISCL_EXCLUSIVE     = 0x01,
    DISCL_NONEXCLUSIVE  = 0x02,
    DISCL_FOREGROUND    = 0x04,
    DISCL_BACKGROUND    = 0x08,
    DISCL_NOWINKEY      = 0x10,

    DIDOI_ASPECTPOSITION = 0x00000100,

    DIDFT_ALL           = 0,
    DIDFT_ABSAXIS       = 1,
    DIDFT_RELAXIS       = 2,
    DIDFT_AXIS          = DIDFT_ABSAXIS | DIDFT_RELAXIS,
    DIDFT_PSHBUTTON     = 4,
    DIDFT_TGLBUTTON     = 8,
    DIDFT_BUTTON        = DIDFT_PSHBUTTON | DIDFT_TGLBUTTON,
    DIDFT_POV           = 0x10,
    DIDFT_COLLECTION    = 0x40,
    DIDFT_NODATA        = 0x80,
    DIDFT_ANYINSTANCE   = 0x00FF_FF00,
    DIDFT_INSTANCEMASK  = DIDFT_ANYINSTANCE,
    DIDFT_OPTIONAL      = 0x8000_0000;

  struct SysMouse {} mixin(uuid!(SysMouse, "6F1D2B60-D5A0-11CF-BFC7-444553540000"));

  struct XAxis  {} mixin(uuid!(XAxis , "A36D02E0-C9F3-11CF-BFC7-444553540000"));
  struct YAxis  {} mixin(uuid!(YAxis , "A36D02E1-C9F3-11CF-BFC7-444553540000"));
  struct ZAxis  {} mixin(uuid!(ZAxis , "A36D02E2-C9F3-11CF-BFC7-444553540000"));
  struct RxAxis {} mixin(uuid!(RxAxis, "A36D02F4-C9F3-11CF-BFC7-444553540000"));
  struct RyAxis {} mixin(uuid!(RyAxis, "A36D02F5-C9F3-11CF-BFC7-444553540000"));
  struct RzAxis {} mixin(uuid!(RzAxis, "A36D02E3-C9F3-11CF-BFC7-444553540000"));
  struct Slider {} mixin(uuid!(Slider, "A36D02E4-C9F3-11CF-BFC7-444553540000"));
  struct Button {} mixin(uuid!(Button, "A36D02F0-C9F3-11CF-BFC7-444553540000"));
  struct Key    {} mixin(uuid!(Key   , "55728220-D33C-11CF-BFC7-444553540000"));
  struct Pov    {} mixin(uuid!(Pov   , "A36D02F2-C9F3-11CF-BFC7-444553540000"));
  struct Unknown{} mixin(uuid!(Unknown,"A36D02F3-C9F3-11CF-BFC7-444553540000"));

  enum DI8DEVCLASS:uint {ALL = 0, DEVICE = 1, POINTER = 2, KEYBOARD = 3, GAMECTRL = 4}
  enum DIEDFL_ALLDEVICES      = 0x00000000,
       DIEDFL_ATTACHEDONLY    = 0x00000001,
       DIEDFL_FORCEFEEDBACK   = 0x00000100,
       DIEDFL_INCLUDEALIASES  = 0x00010000,
       DIEDFL_INCLUDEPHANTOMS = 0x00020000,
       DIEDFL_INCLUDEHIDDEN   = 0x00040000;

  struct DIDeviceInstanceA { align(1):
    uint dwSize;
    GUID guidInstance;
    GUID guidProduct;
    uint dwDevType;
    char[MAX_PATH] tszInstanceName;
    char[MAX_PATH] tszProductName;
    GUID guidFFDriver;
    ushort wUsagePage;
    ushort wUsage;
  }

  alias DIEnumDevicesCallbackA = extern(Windows) bool function(in DIDeviceInstanceA ddi, void* pvRef);

  struct DIDeviceObjectInstanceA { align(1):
    uint dwSize;
    GUID guidType;
    uint dwOfs, dwType, dwFlags;
    char[MAX_PATH] tszName;
    uint dwFFMaxForce, dwFFForceResolution;
    ushort wCollectionNumber, wDesignatorIndex, wUsagePage, wUsage;
    uint dwDimension;
    ushort wExponent, wReportId;
  }

  alias DIEnumDeviceObjectsCallbackA = extern(Windows) bool function(in DIDeviceObjectInstanceA ddoi, void* pvRef);

  mixin( uuid!(IDirectInput8A, "BF798030-483A-4DA2-AA99-5D64ED369700"));
  interface    IDirectInput8A : IUnknown{ extern(Windows):
    HRESULT CreateDevice(REFIID rguid, out IDirectInputDeviceA device, IUnknown pUnkOuter);
    HRESULT EnumDevices(DI8DEVCLASS dwDevType, DIEnumDevicesCallbackA lpCallback, void* pvRef, uint dwFlags);
  /*  function GetDeviceStatus(const rguidInstance: TGUID): HResult; stdcall;
    function RunControlPanel(hwndOwner: HWND; dwFlags: DWORD): HResult; stdcall;
    function Initialize(hinst: THandle; dwVersion: DWORD): HResult; stdcall;
    function FindDevice(const rguidClass: TGUID; ptszName: PAnsiChar; out pguidInstance: TGUID): HResult; stdcall;
    function EnumDevicesBySemantics(ptszUserName: PAnsiChar; const lpdiActionFormat: TDIActionFormatA; lpCallback: TDIEnumDevicesBySemanticsCallbackA; pvRef: Pointer; dwFlags: DWORD): HResult; stdcall;
    function ConfigureDevices(lpdiCallback: TDIConfigureDevicesCallback; const lpdiCDParams: TDIConfigureDevicesParamsA; dwFlags: DWORD; pvRefData: Pointer): HResult; stdcall;*/
  }

  struct DIObjectDataFormat{
    PGUID pguid;
    uint dwOfs, dwType, dwFlags;
  }

  struct DIDataFormat{
    uint dwSize, dwObjSize, dwFlags, dwDataSize, dwNumObjs;
    const DIObjectDataFormat* rgodf;
  }

  const DIObjectDataFormat[11] rgodfDIMouse2 = [
    {&IID_XAxis   ,  0 , DIDFT_AXIS   | DIDFT_ANYINSTANCE                  , 0},
    {&IID_YAxis   ,  4 , DIDFT_AXIS   | DIDFT_ANYINSTANCE                  , 0},
    {&IID_ZAxis   ,  8 , DIDFT_AXIS   | DIDFT_ANYINSTANCE | DIDFT_OPTIONAL , 0},
    {null         , 12 , DIDFT_BUTTON | DIDFT_ANYINSTANCE                  , 0},
    {null         , 13 , DIDFT_BUTTON | DIDFT_ANYINSTANCE                  , 0},
    {null         , 14 , DIDFT_BUTTON | DIDFT_ANYINSTANCE | DIDFT_OPTIONAL , 0},
    {null         , 15 , DIDFT_BUTTON | DIDFT_ANYINSTANCE | DIDFT_OPTIONAL , 0},
    {null         , 16 , DIDFT_BUTTON | DIDFT_ANYINSTANCE | DIDFT_OPTIONAL , 0},
    {null         , 17 , DIDFT_BUTTON | DIDFT_ANYINSTANCE | DIDFT_OPTIONAL , 0},
    {null         , 18 , DIDFT_BUTTON | DIDFT_ANYINSTANCE | DIDFT_OPTIONAL , 0},
    {null         , 19 , DIDFT_BUTTON | DIDFT_ANYINSTANCE | DIDFT_OPTIONAL , 0},
  ];

  struct DIMouseState{
    int lX, lY, lZ;
    ubyte[8] rgbButtons;
  }

  const c_dfDIMouse2 = DIDataFormat(
    DIDataFormat.sizeof,
    DIObjectDataFormat.sizeof,
    DIDFT_RELAXIS,
    DIMouseState.sizeof,
    rgodfDIMouse2.length,
    rgodfDIMouse2.ptr
  );

  const DIObjectDataFormat[44] rgodfDIJoystick = [
    {&IID_XAxis ,  0, DIDFT_AXIS | DIDFT_ANYINSTANCE | DIDFT_OPTIONAL, DIDOI_ASPECTPOSITION},
    {&IID_YAxis ,  4, DIDFT_AXIS | DIDFT_ANYINSTANCE | DIDFT_OPTIONAL, DIDOI_ASPECTPOSITION},
    {&IID_ZAxis ,  8, DIDFT_AXIS | DIDFT_ANYINSTANCE | DIDFT_OPTIONAL, DIDOI_ASPECTPOSITION},
    {&IID_RxAxis, 12, DIDFT_AXIS | DIDFT_ANYINSTANCE | DIDFT_OPTIONAL, DIDOI_ASPECTPOSITION},
    {&IID_RyAxis, 16, DIDFT_AXIS | DIDFT_ANYINSTANCE | DIDFT_OPTIONAL, DIDOI_ASPECTPOSITION},
    {&IID_RzAxis, 20, DIDFT_AXIS | DIDFT_ANYINSTANCE | DIDFT_OPTIONAL, DIDOI_ASPECTPOSITION},
    // 2 Sliders
    {&IID_Slider, 24, DIDFT_AXIS | DIDFT_ANYINSTANCE | DIDFT_OPTIONAL, DIDOI_ASPECTPOSITION},
    {&IID_Slider, 28, DIDFT_AXIS | DIDFT_ANYINSTANCE | DIDFT_OPTIONAL, DIDOI_ASPECTPOSITION},
    // 4 POVs (yes, really)
    {&IID_Pov   , 32, DIDFT_POV | DIDFT_ANYINSTANCE | DIDFT_OPTIONAL, 0},
    {&IID_Pov   , 36, DIDFT_POV | DIDFT_ANYINSTANCE | DIDFT_OPTIONAL, 0},
    {&IID_Pov   , 40, DIDFT_POV | DIDFT_ANYINSTANCE | DIDFT_OPTIONAL, 0},
    {&IID_Pov   , 44, DIDFT_POV | DIDFT_ANYINSTANCE | DIDFT_OPTIONAL, 0},
    // Buttons
    {null       , 48+ 0, DIDFT_BUTTON | DIDFT_ANYINSTANCE | DIDFT_OPTIONAL, 0},
    {null       , 48+ 1, DIDFT_BUTTON | DIDFT_ANYINSTANCE | DIDFT_OPTIONAL, 0},
    {null       , 48+ 2, DIDFT_BUTTON | DIDFT_ANYINSTANCE | DIDFT_OPTIONAL, 0},
    {null       , 48+ 3, DIDFT_BUTTON | DIDFT_ANYINSTANCE | DIDFT_OPTIONAL, 0},
    {null       , 48+ 4, DIDFT_BUTTON | DIDFT_ANYINSTANCE | DIDFT_OPTIONAL, 0},
    {null       , 48+ 5, DIDFT_BUTTON | DIDFT_ANYINSTANCE | DIDFT_OPTIONAL, 0},
    {null       , 48+ 6, DIDFT_BUTTON | DIDFT_ANYINSTANCE | DIDFT_OPTIONAL, 0},
    {null       , 48+ 7, DIDFT_BUTTON | DIDFT_ANYINSTANCE | DIDFT_OPTIONAL, 0},
    {null       , 48+ 8, DIDFT_BUTTON | DIDFT_ANYINSTANCE | DIDFT_OPTIONAL, 0},
    {null       , 48+ 9, DIDFT_BUTTON | DIDFT_ANYINSTANCE | DIDFT_OPTIONAL, 0},
    {null       , 48+10, DIDFT_BUTTON | DIDFT_ANYINSTANCE | DIDFT_OPTIONAL, 0},
    {null       , 48+11, DIDFT_BUTTON | DIDFT_ANYINSTANCE | DIDFT_OPTIONAL, 0},
    {null       , 48+12, DIDFT_BUTTON | DIDFT_ANYINSTANCE | DIDFT_OPTIONAL, 0},
    {null       , 48+13, DIDFT_BUTTON | DIDFT_ANYINSTANCE | DIDFT_OPTIONAL, 0},
    {null       , 48+14, DIDFT_BUTTON | DIDFT_ANYINSTANCE | DIDFT_OPTIONAL, 0},
    {null       , 48+15, DIDFT_BUTTON | DIDFT_ANYINSTANCE | DIDFT_OPTIONAL, 0},
    {null       , 48+16, DIDFT_BUTTON | DIDFT_ANYINSTANCE | DIDFT_OPTIONAL, 0},
    {null       , 48+17, DIDFT_BUTTON | DIDFT_ANYINSTANCE | DIDFT_OPTIONAL, 0},
    {null       , 48+18, DIDFT_BUTTON | DIDFT_ANYINSTANCE | DIDFT_OPTIONAL, 0},
    {null       , 48+19, DIDFT_BUTTON | DIDFT_ANYINSTANCE | DIDFT_OPTIONAL, 0},
    {null       , 48+20, DIDFT_BUTTON | DIDFT_ANYINSTANCE | DIDFT_OPTIONAL, 0},
    {null       , 48+21, DIDFT_BUTTON | DIDFT_ANYINSTANCE | DIDFT_OPTIONAL, 0},
    {null       , 48+22, DIDFT_BUTTON | DIDFT_ANYINSTANCE | DIDFT_OPTIONAL, 0},
    {null       , 48+23, DIDFT_BUTTON | DIDFT_ANYINSTANCE | DIDFT_OPTIONAL, 0},
    {null       , 48+24, DIDFT_BUTTON | DIDFT_ANYINSTANCE | DIDFT_OPTIONAL, 0},
    {null       , 48+25, DIDFT_BUTTON | DIDFT_ANYINSTANCE | DIDFT_OPTIONAL, 0},
    {null       , 48+26, DIDFT_BUTTON | DIDFT_ANYINSTANCE | DIDFT_OPTIONAL, 0},
    {null       , 48+27, DIDFT_BUTTON | DIDFT_ANYINSTANCE | DIDFT_OPTIONAL, 0},
    {null       , 48+28, DIDFT_BUTTON | DIDFT_ANYINSTANCE | DIDFT_OPTIONAL, 0},
    {null       , 48+29, DIDFT_BUTTON | DIDFT_ANYINSTANCE | DIDFT_OPTIONAL, 0},
    {null       , 48+30, DIDFT_BUTTON | DIDFT_ANYINSTANCE | DIDFT_OPTIONAL, 0},
    {null       , 48+31, DIDFT_BUTTON | DIDFT_ANYINSTANCE | DIDFT_OPTIONAL, 0},
  ];

  struct DIJoystickState{ align(1):
    int X=0x7fff, Y=0x7fff, Z=0x7fff, Rx=0x7fff, Ry=0x7fff, Rz=0x7fff;
    int[2] Slider;
    int[4] Pov = [-1, -1, -1, -1];
    ubyte[32] Button;
  }

  const c_dfDIJoystick = DIDataFormat(
    DIDataFormat.sizeof,
    DIObjectDataFormat.sizeof,
    DIDFT_ABSAXIS,
    DIJoystickState.sizeof,
    rgodfDIJoystick.length,
    rgodfDIJoystick.ptr
  );

  mixin( uuid!(IDirectInputDeviceA, "5944E680-C92E-11CF-BFC7-444553540000"));
  interface    IDirectInputDeviceA : IUnknown { extern(Windows):
    void _dummy0();//function GetCapabilities(var lpDIDevCaps: TDIDevCaps): HResult; stdcall;
    HRESULT EnumObjects(DIEnumDeviceObjectsCallbackA cb, void* pvRef, uint dwFlags);
    void _dummy2();//function GetProperty(rguidProp: PGUID; var pdiph: TDIPropHeader): HResult; stdcall;
    void _dummy3();//function SetProperty(rguidProp: PGUID; const pdiph: TDIPropHeader): HResult; stdcall;
    HRESULT Acquire();
    HRESULT Unacquire();
    HRESULT GetDeviceState(uint cbData, void* lpvData);
    void _dummy4();//function GetDeviceData(cbObjectData: DWORD; rgdod: PDIDeviceObjectData; out pdwInOut: DWORD; dwFlags: DWORD): HResult; stdcall;
    HRESULT SetDataFormat(in DIDataFormat didf);
    void _dummy5();//function SetEventNotification(hEvent: THandle): HResult; stdcall;
    HRESULT SetCooperativeLevel(HWND hwnd, uint dwFlags);
    void _dummy6();//function GetObjectInfo(var pdidoi: TDIDeviceObjectInstanceA; dwObj, dwHow: DWORD): HResult; stdcall;
    void _dummy7();//function GetDeviceInfo(var pdidi: TDIDeviceInstanceA): HResult; stdcall;
    void _dummy8();//function RunControlPanel(hwndOwner: HWND; dwFlags: DWORD): HResult; stdcall;
    void _dummy9();//function Initialize(hinst: THandle; dwVersion: DWORD; const rguid: TGUID): HResult; stdcall;
  }


  alias DInput = Singleton!DInputWrapper;
}


class DInputWrapper{
private:
  const bool loaded;
  extern(Windows){
    HRESULT function(HINSTANCE hinst, uint dwVersion, REFIID riidltf, out IDirectInput8A ppvOut, IUnknown punkOuter) DirectInput8Create;
  }

  IDirectInput8A directInput8;
  IDirectInputDeviceA directMouse, directJoystick;

  static string nameOf(in GUID g){
    static foreach(s; "XAxis,YAxis,ZAxis,RxAxis,RyAxis,RzAxis,Slider,Button,Key,Pov".split(',')){
       mixin("if(g==IID_%s) return `%s`;".format(s, s));
    }
    import std.uuid;
    return (cast(UUID)g).toString;
  }

  void enumObjects(IDirectInputDeviceA dev){
    static extern(Windows) bool enumCB(in DIDeviceObjectInstanceA doi, void* pvRef){
      "%-20s t:%2X #:%2X f:%04X %s".writefln(nameOf(doi.guidType), doi.dwType&0xFF, doi.dwType>>8, doi.dwFlags, doi.tszName.toStr);
      return true;//continue or not
    }

    enforce(S_OK == dev.EnumObjects(&enumCB, null, 0/*DIDFT_ALL*/)      , "directInputDevice.EnumObjects() fail");
    readln;
  }

  void initMouse(){
    enforce(S_OK == directInput8.CreateDevice(&IID_SysMouse, directMouse, null)                                                     , "directInput8.CreateDevice(SysMouse) fail");
    enforce(application.handle !is null, "DXMouse initialization error: no mainForm present.");
    enforce(S_OK == directMouse.SetCooperativeLevel(application.handle, DISCL_BACKGROUND | DISCL_NONEXCLUSIVE)                      , "directMouse.SetCooperativeLevel() fail");
    enforce(S_OK == directMouse.SetDataFormat(c_dfDIMouse2)                                                                         , "directMouse.SetDataFormat() fail");
    enforce(S_OK == directMouse.Acquire                                                                                             , "directMouse.acquire() fail");
  }

  bool initJoystick(){
    GUID guidJoystick;
    static extern(Windows) bool enumCB(in DIDeviceInstanceA ddi, void* pvRef){
      //writeln(ddi.guidInstance, " : ", ddi.tszInstanceName.toStr, " / ", ddi.tszProductName.toStr, " ", ddi.wUsagePage, " ", ddi.wUsage);
      *(cast(GUID*)pvRef) = ddi.guidInstance;
      return false;//continue or not
    }
    enforce(S_OK == directInput8.EnumDevices(DI8DEVCLASS.GAMECTRL, &enumCB, &guidJoystick, DIEDFL_ALLDEVICES)      , "directInput8.EnumDevices(Joystick) fail");
    if(guidJoystick==GUID.init) return false;

    //writeln("Joystick GUID: ", guidJoystick);
    enforce(S_OK == directInput8.CreateDevice(&guidJoystick, directJoystick, null)                                  , "directInput8.CreateDevice(Joystick) fail");
    enforce(application.handle !is null, "DXJoystick initialization error: no mainForm present.");
    enforce(S_OK == directJoystick.SetCooperativeLevel(application.handle, DISCL_BACKGROUND | DISCL_NONEXCLUSIVE)   , "directJoystick.SetCooperativeLevel() fail");

    //enumObjects(directJoystick);

    enforce(S_OK == directJoystick.SetDataFormat(c_dfDIJoystick)                                                   , "directJoystick.SetDataFormat() fail");
    enforce(S_OK == directJoystick.Acquire                                                                         , "directJoystick.acquire() fail");

    //writeln("Joystick Init");
    return true;
  }

public:
  this(){
    enum dllName = "dinput8.dll";
    auto m = loadLibrary(dllName, false);
    if(m){
      m.getProcAddress("DirectInput8Create", DirectInput8Create);
      enforce(S_OK == DirectInput8Create(GetModuleHandle(null), DIRECTINPUT_VERSION, &IID_IDirectInput8A, directInput8, null)         , "DirectInput8Create() fail");

      initMouse;
      initJoystick;
      loaded = true;
    }
  }

  auto getMouseState(){
    DIMouseState ms;
    if(directMouse !is null){
      directMouse.Acquire;
      directMouse.GetDeviceState(ms.sizeof, &ms);
    }
    return ms;
  }

  auto getJoystickState(){
    DIJoystickState js;
    if(directJoystick !is null){
      directJoystick.Acquire;
      directJoystick.GetDeviceState(js.sizeof, &js);
    }
    return js;
  }

  ~this(){
    if(loaded){
      directMouse.Unacquire;
      directMouse.SafeRelease;
      directInput8.SafeRelease;
    }
  }
}

// Slow/Locked Mouse, pos get/set //////////////////////////////////////////////////////////

auto rawMousePos  (){ return vec2(inputs.MXraw.value, inputs.MYraw.value); };
auto rawMouseDelta(){ return vec2(inputs.MXraw.delta, inputs.MYraw.delta); };

void mouseLock(ivec2 pos){ with(pos){
  //clamp to the screen, otherwise winapi will unlock the mouse
  RECT r;
  GetWindowRect(GetDesktopWindow, &r);
  pos.x = pos.x.clamp(r.left, r.right-1);
  pos.y = pos.y.clamp(r.top, r.bottom-1);

  r = RECT(x, y, x+1, y+1);
  ClipCursor(&r);
}}

void mouseLock(in vec2 pos){ mouseLock(pos.ifloor); }

void mouseLock(){ mouseLock(winMousePos); }

void mouseUnlock(){ ClipCursor(null); }

void slowMouse(bool enabled, float speed=0.25f){
  slowMouseSpeed = speed;

  if(slowMouseEnabled==enabled) return;
  slowMouseEnabled = enabled;
  slowMousePos = winMousePos + vec2(0.5, 0.5);
  if(enabled) mouseLock(winMousePos);
         else mouseUnlock;
}

void mouseMoveRel(float dx, float dy){
  if(!dx && !dy) return;

  if(slowMouseEnabled){
    slowMousePos += vec2(dx, dy);
  }else{
    POINT p; GetCursorPos(&p);
    SetCursorPos(p.x+dx.iround, p.y+dy.iround);
  }
}

void mouseMoveRel(in vec2 d){ mouseMoveRel(d.x, d.y); }
void mouseMoveRelX(float dx){ mouseMoveRel(dx, 0); }
void mouseMoveRelY(float dy){ mouseMoveRel(0, dy); }

private __gshared{
  bool slowMouseEnabled;
  float slowMouseSpeed;
  vec2 slowMousePos;

  void slowMouseUpdate(){
    if(slowMouseEnabled){
      slowMousePos += rawMouseDelta*slowMouseSpeed;

      //clamp to screen
      RECT r;
      GetWindowRect(GetDesktopWindow, &r);
      slowMousePos.x = slowMousePos.x.clamp(r.left, r.right-0.01f);
      slowMousePos.y = slowMousePos.y.clamp(r.top, r.bottom-0.01f);

      mouseLock(slowMousePos);
    }else{
      slowMousePos = winMousePos + vec2(.5, .5);
    }
  }

  //winapi mouse get/set
  auto winMousePos(){
    POINT p; GetCursorPos(&p);
    return ivec2(p.x, p.y);
  }
}

// MouseState wrapper class ///////////////////////////////////////////////////

class MouseState{
public:
  struct MSRelative{
    ivec2 screen;
    vec2 world;
    int wheel;

    float screenDist=0, worldDist=0;
  }
  struct MSAbsolute{
    bool LMB, RMB, MMB, shift, alt, ctrl;
    ivec2 screen;
    vec2 world;
    int wheel;
  }

public:
  MSAbsolute act, last, pressed;
  MSRelative delta, hover, hoverMax;
  bool justPressed, justReleased, LMB, MMB, RMB;
  ibounds2 screenRect, screenSelectionRect;
  bounds2 worldRect, worldSelectionRect;
  bool moving;

  void _updateInternal(MSAbsolute next){
    //convert wheel to absolute from relative
    next.wheel += act.wheel;

    //process press/release
    bool anyButton(const MSAbsolute a) const { return a.LMB || a.RMB || a.MMB; }
    auto pressing     = anyButton(next),
         lastPressing = anyButton(act);

    justPressed  =  pressing && !lastPressing;
    justReleased = !pressing &&  lastPressing;

    last = act; act = next;

    if(justPressed){
      hoverMax = MSRelative.init;
      pressed = act;
    }

    //calc deltas
    void diff(ref MSRelative res, const MSAbsolute act, const MSAbsolute last){
      res.screen = act.screen-last.screen;
      res.world  = act.world -last.world ;
      res.wheel  = act.wheel -last.wheel ;
    }

    diff(delta, act, last   );
    diff(hover, act, pressed);

    maximize(hoverMax.screen, abs(hover.screen));
    maximize(hoverMax.world , abs(hover.world ));

    //calc distances
    void dist(ref MSRelative res){
      res.screenDist = length(res.screen);
      res.worldDist  = length(res.world);
    }

    dist(delta);
    dist(hover);
    dist(hoverMax);

    LMB = pressed.LMB && act.LMB;
    MMB = pressed.MMB && act.MMB;
    RMB = pressed.RMB && act.RMB;

    screenSelectionRect = ibounds2(pressed.screen, act.screen).sorted;
    worldSelectionRect = bounds2(pressed.world, act.world).sorted;

    moving = !delta.world.isnull;
  }

  bool inWorld () const { return worldRect .contains!"[)"(act.world ); }
  bool inScreen() const { return screenRect.contains!"[)"(act.screen); }
}

/////////////////////////////////////////////////////////////////////////////
///  Debug Poti input handler                                             ///
/////////////////////////////////////////////////////////////////////////////

class PotiInputHandler: InputHandlerBase { //A set of poties from the debugging interface
private:
  alias potiCount = DebugLogClient.potiCount;
  InputEntry[potiCount] ie;
public:
  this(){
    category = "DebugPoti";

    foreach(i; 0..ie.length){
      ie[i] = new InputEntry(this, InputEntryType.analogState, "DebugPoti"~to!string(i));
      entries ~= ie[i];
    }
  }

  override void update(){
    foreach(i; 0..ie.length) ie[i].value = dbg.getPotiValue(i);
  }
}


/////////////////////////////////////////////////////////////////////////////
///  XInput haldler                                                       ///
/////////////////////////////////////////////////////////////////////////////

alias XInput = Singleton!XInputFuncts;

class XInputFuncts{
private:

  struct XINPUT_GAMEPAD { align(1):
    ushort wButtons;
    ubyte bLeftTrigger, bRightTrigger;
    short sThumbLX, sThumbLY, sThumbRX, sThumbRY;
  }

  struct XINPUT_STATE{ align(1):
    uint dwPacketNumber;
    XINPUT_GAMEPAD Gamepad;
  }

  const bool functsLoaded;
  extern(Windows){
    int function (uint dwUserIndex, XINPUT_STATE *pState) _XInputGetState;
    void function (bool enable) _XInputEnable;
  }

public:
  this(){
    const dllName = "Xinput1_4.dll"; //"Xinputuap.dll";
    auto hXInputModule = loadLibrary(dllName, false);
    if(hXInputModule){
      hXInputModule.getProcAddress("XInputGetState", _XInputGetState);
      hXInputModule.getProcAddress("XInputEnable"  , _XInputEnable  );
      functsLoaded = true;
    }
  }

  auto getState(int userIdx=0){
    XINPUT_STATE res;
    if(functsLoaded){
      //_XInputEnable(true); //not needed
      _XInputGetState(userIdx, &res);
    }
    return res.Gamepad;
  }
}


class XInputInputHandler: InputHandlerBase {
private:
  InputEntry[16] buttons;
  InputEntry[7] axes;
  InputEntry guideButton;

  InputEntry[15] abxyCombos;
  int actAbxyState, lastAbxyState, //current and last state of ABXY buttons
      processedAbxyState, abxyPhase, //latched state after the delay
      summedAbxyState; //for small clicks
  enum abxyDelay = 10; //todo: It is 60 FPS based, not time based

  void addButton(int idx, string name){
    enforce(!buttons[idx], "XInputHandler.addButton("~name~") Duplicated idx: "~text(idx));
    auto e = new InputEntry(this, InputEntryType.digitalButton, name);
    buttons[idx] = e;  entries ~= e;
  }

  void addAnalog(int idx, string name, bool isAnalogButton=false){
    enforce(!axes[idx], "XInputHandler.addAnalog("~name~") Duplicated idx: "~text(idx));
    auto e = new InputEntry(this, isAnalogButton ? InputEntryType.analogButton : InputEntryType.analogState, name);
    axes[idx] = e;  entries ~= e;
  }

public:
  this(){
    category = "xinput";

    guideButton = new InputEntry(this, InputEntryType.digitalButton, "xiGuide"); entries ~= guideButton;

    addAnalog(4, "xiLT", true);                addAnalog(6, "xiT");              addAnalog( 5, "xiRT", true);
    addButton(8, "xiLB");                                                        addButton( 9, "xiRB");
    addButton(0, "xiUp");     addButton( 5, "xiBack"); addButton( 4, "xiStart"); addButton(12, "xiA");
    addButton(1, "xiDown");                                                      addButton(13, "xiB");
    addButton(2, "xiLeft");                                                      addButton(14, "xiX");
    addButton(3, "xiRight");  addButton( 6, "xiLS");   addButton( 7, "xiRS");    addButton(15, "xiY");

    addAnalog(0, "xiLX"); addAnalog(1, "xiLY");            addAnalog(2, "xiRX"); addAnalog(3, "xiRY");

    //simultaneously pressed combos of ABXY buttons
    foreach(i; 1..16){
      const name = "xic" ~ iota(4).map!(a => (1<<a) & i ? "ABXY"[a..a+1] : "").join;
      auto e = new InputEntry(this, InputEntryType.digitalButton, name);
      abxyCombos[i-1] = e;
      entries ~= e;
    }
  }

  override void update(){
    auto st = XInput.getState;

    //this hack gets the guide button state.
    bool guideButtonState;
    static if(1){
      //todo: guide button poller: https://forums.tigsource.com/index.php?topic=26792.0
        //LoadLibrary("C:/Windows/System32/xinput1_3.dll");
        //Get the address of ordinal 100.
      struct SecretStruct{
        uint eventCount;
        ushort buttons;
  //        unsigned short up:1, down:1, left:1, right:1, start:1, back:1, l3:1, r3:1,
  //                           lButton:1, rButton:1, guideButton:1, unknown:1, aButton:1,
  //                           bButton:1, xButton:1, yButton:1; // button state bitfield
        ubyte lTrigger;  //Left Trigger
        ubyte rTrigger;  //Right Trigger
        short lJoyY;  //Left Joystick Y
        short lJoyx;  //Left Joystick X
        short rJoyY;  //Right Joystick Y
        short rJoyX;  //Right Joystick X
      }

      static bool guideHackTried;
      static extern(C) int function(int, ref SecretStruct) guideHackFunct;
      if(guideHackTried.chkSet){
        auto lib = loadLibrary("xinput1_3.dll", false);
        if(lib) getProcAddress(lib, 100, guideHackFunct, false);
      }

      if(guideHackFunct !is null){
        SecretStruct sc;
        if(guideHackFunct(0, sc)==0) //only 10us
          guideButtonState = (sc.buttons & 0x400)!=0;
      }
    }

    //todo: get all the states from xinput1_3, not just the guide button

    guideButton.value = guideButtonState ? 1 : 0;

    foreach(int idx, e; buttons) if(e) e.value = (st.wButtons>>idx)&1;
    axes[0].value = st.sThumbLX*(1.0f/32768);
    axes[1].value = st.sThumbLY*(1.0f/32768);
    axes[2].value = st.sThumbRX*(1.0f/32768);
    axes[3].value = st.sThumbRY*(1.0f/32768);
    axes[4].value = st.bLeftTrigger*(1.0f/256);
    axes[5].value = st.bRightTrigger*(1.0f/256);
    axes[6].value = axes[5].value-axes[4].value;

    abxyUpdate;
  }

  private void abxyUpdate(){
    //update abxy combos
    lastAbxyState = actAbxyState;
    actAbxyState = iota(4).map!(a => buttons[12+a].down ? (1<<a) : 0).sum;
    summedAbxyState |= actAbxyState;

    if(!actAbxyState){
      processedAbxyState = processedAbxyState==0 ? summedAbxyState : 0;
                         // ^^ this ensures that the smallest clicks are recognised too.
      summedAbxyState = 0;
      abxyPhase = 0;
    }else{
      const changed = lastAbxyState!=actAbxyState;

      if(changed || abxyPhase)
        abxyPhase++;

      if(abxyPhase >= abxyDelay){
        processedAbxyState = actAbxyState;
        abxyPhase = 0;
      }
    }

    foreach(i; 1..16) abxyCombos[i-1].value =  i==processedAbxyState ? 1 : 0;

    //print(format("%2x %3d %2x", actAbxyState, abxyPhase, processedAbxyState));
    //writef!"%X"(processedAbxyState);
  }

}

/////////////////////////////////////////////////////////////////////////////
///  Actions (deprecated)                                                 ///
/////////////////////////////////////////////////////////////////////////////

struct Action{  //todo: this is kinda deprecated: the new thing is MenuItem/KeyCombo.
private:
//these fields are specified from the constructors
  ActionGroup* group;
  char type; //a = active, p = pressed, g = group, m = modifier
  string name;
  string key;
  bool enabled;
  void delegate() task;
  void delegate(float) task2;
  bool* modifier;

//these fields are internally used
  int consistencyCnt; //at the end; all these counters must be equal
  string defaultKey; //reduntant copy from defaultKeyMap

//-----------------------------------------
  string fullName() const { return group.name~`\`~name; }
  private bool execute() {
    bool res;
    if(enabled) switch(type){
      case 'a': if(inputs.active (key)) if(task) {
                  task();
                  res = true;
                }
                break;
      case 'p': if(inputs.pressed(key)) if(task) {
                  task();
                  res = true;
                }
                break;
      case 't': if(inputs.typed(key)) if(task) {
                  task();
                  res = true;
                }
                break;
      case 'm': if(modifier) {
                  res = chkSet(*modifier, inputs.active(key));
                }
                break;
      case 'd': if(task2 && inputs[key].changed) {
                  task2(inputs[key].delta);
                  res = true;
                }
                break;
      case 'v': if(task2 && inputs[key].changed) {
                  task2(inputs[key].value);
                  res = true;
                }
                break;
      default:
    }
    return res;
  }
}


struct ActionGroup{
private:
  string name;
  Action[] actions;

  Action* find(string name){
    foreach(ref a; actions){ if(a.name==name) return &a; }
    return null;
  }
  Action* add(Action ac){
    enforce(find(ac.name)==null, format(`Action "%s" already exists.`, ac.name));
    actions ~= ac;
    return &actions[$-1];
  }
  Action* findAdd(Action action){
    auto ac = find(action.name);
    if(!ac) ac = add(action);
    return ac;
  }

  bool enabled() const { return true; }
}


struct ActionManager{
private:
  ActionGroup[] groups;
  ActionGroup* actGroup; //the following controls will use this group
  bool m_updating, m_changed;
  string[string] defaultKeyMap, //it is saved on the first update
                 pendingKeyMap; //it will loaded on the next update

  void add(ActionGroup grp){
    enforce(findGroup(grp.name)==null, format(`ActionGroup "%s" already exists.`, grp.name));
    groups ~= grp;
  }

  ActionGroup* findGroup(string name){
    foreach(ref g; groups) if(g.name==name) return &g;
    return null;
  }

  ActionGroup* findAddGroup(string name){
    auto g = findGroup(name);
    if(!g){
      groups ~= ActionGroup(name);
      g = &groups[$-1];
    }
    return g;
  }

  Action* findAction(string fullName){
    auto name = File(fullName).name;
    auto groupName = File(fullName).dir;
    Action* ac;
    if(groupName!=""){
      auto grp = findGroup(groupName);
      enforce(grp, format(`Can't find ActionGroup "%s"`, groupName));
      ac = grp.find(name);
      enforce(ac, format(`Can't find Action "%s" in ActionGroup "%s"`, name, groupName));
    }else{
      foreach(ref grp; groups){
        auto ac2 = grp.find(name);
        if(ac2){
          enforce(!ac, `Ambiguous Action name"`~name~`"`);
          ac = ac2;
        }
      }
    }
    enforce(ac, format(`Can't find Action "%s"`, fullName));
    return ac;
  }

  bool checkConsistency(){ //all actions must be processed equal times
    int c;
    foreach(ref g; groups) foreach(ref a; g.actions) {
      auto act = a.consistencyCnt;
      if(!c) c = act; //first value
      if(c!=act) return false;
    }
    return true;
  }

  auto exportKeyMap()
  {
    string[string] map;
    foreach(ref g; groups) foreach(ref a; g.actions)
      map[a.fullName] = a.key;
    return map;
  }

  void importKeyMap(string[string] map)
  {
    pendingKeyMap = map.dup;
    //update actual keys
    foreach(ref g; groups) foreach(ref a; g.actions){
      auto name = a.fullName;
      if(auto k = name in pendingKeyMap){
        a.key = *k;
        pendingKeyMap.remove(a.name);
      }
    }
  }

  private void processAction(Action action) {
    enforce(updating, "Can't add action to ActionManager: not in updating state.");
    enforce(actGroup, "Can't add action to ActionManager: no group is specified.");

    auto ac = actGroup.find(action.name);
    if(!ac){ //create the new action
      ac = actGroup.add(action);

      //save defaults
      ac.defaultKey = ac.key; //redundant copy
      defaultKeyMap[ac.fullName] = ac.key;
    }

    //copy enabledness
    ac.enabled = action.enabled;

    //load pending config
    auto name = ac.fullName;
    if(auto k=name in pendingKeyMap){
      ac.key = *k;
      pendingKeyMap.remove(name);
    }

    ac.consistencyCnt++;

    if(enabled && actGroup.enabled && ac.enabled){
      if(ac.execute){
        m_changed |= true;
      }
    }
  }

public:
  @property bool changed () { return m_changed ; }
  @property bool updating() { return m_updating; }

  string toString() { //dump
    string s;
    s ~= "Actions\n";
    foreach(ref grp; groups){
      s ~= "  "~grp.name~"\n";
      foreach(ref ac; grp.actions){
        s ~= format("    %-28s: %s\n", ac.name, ac.key);
      }
    }
    return s;
  }

  //functs used in Window.doUpdate()
  void beginUpdate() {
    enforce(!updating, "ActionManager is already in updating state.");
    actGroup = null;
    m_updating = true;
    m_changed = false;
  }
  void endUpdate() {
    enforce(updating, "ActionManager is not in updating state.");
    actGroup = null;
    m_updating = false;
    pendingKeyMap = null; //already processed, remove possible leftovers

    enforce(checkConsistency, "ActionManager consistency check failed.");      //can be 2 actions on the same name for example
  }

  //shortcuts creating new actions (in doUpdate also)
  void group(string name)                                               { actGroup = findAddGroup(name); }
  void onActive  (string name, string key, bool en, void delegate() task)        { processAction(Action(actGroup, 'a', name, key, en, task)); }
  void onPressed (string name, string key, bool en, void delegate() task)        { processAction(Action(actGroup, 'p', name, key, en, task)); }
  void onTyped   (string name, string key, bool en, void delegate() task)        { processAction(Action(actGroup, 't', name, key, en, task)); }
  void onModifier(string name, string key, bool en, ref bool modifier)           { processAction(Action(actGroup, 'm', name, key, en, null, null, &modifier)); }
  void onDelta   (string name, string key, bool en, void delegate(float) task2)  { processAction(Action(actGroup, 'd', name, key, en, null, task2)); }
  void onValue   (string name, string key, bool en, void delegate(float) task2)  { processAction(Action(actGroup, 'v', name, key, en, null, task2)); }

  bool enabled() const { return true; }

  //manage config
  @property string config()             { return mapToStr(exportKeyMap); }
  @property void config(string data)    { importKeyMap(strToMap(data)); }
  auto defaultConfig()                  { return mapToStr(defaultKeyMap); }
  void loadDefaults()                   { config = defaultConfig; }
  bool isDefault()                      { return config==defaultConfig; }

  string key(string name)                       { return findAction(name).key; }
  void setKey(string name, string k)            { with(findAction(name)) if(sameText(k, "default")) key = defaultKey; else key = k; }
  @property string defaultKey(string name)      { return findAction(name).defaultKey; }

}


//! Keyboard/Mouse hooks //////////////////////////////////////////////////////

@("kbd/mouse access") public {
  //todo: which is faster?   import core.sys.windows.windows;  or
  import core.sys.windows.windef, core.sys.windows.winuser, core.sys.windows.winbase;

  extern(Windows) LRESULT LowLevelKeyboardProc(int nCode, WPARAM wParam, LPARAM lParam) nothrow
  {
    bool log = 1;
    try{
      if(wParam==WM_KEYDOWN){
        auto pKeyBoard = cast(KBDLLHOOKSTRUCT*)lParam;
        if(log) writeln("down", pKeyBoard.vkCode);
      }else if(wParam==WM_KEYUP){
        auto pKeyBoard = cast(KBDLLHOOKSTRUCT*)lParam;
        if(log) writeln("up", pKeyBoard.vkCode);
      }else{
        if(log) writeln("wparam", wParam);
      }


    }catch(Exception){}

    return CallNextHookEx(null, nCode, wParam, lParam);
  }

  auto installGlobalKeyboardHook(){
    auto a = SetWindowsHookEx(WH_KEYBOARD_LL, &LowLevelKeyboardProc, GetModuleHandle(null), 0);
    if(!a) writeln("fail:k0");
    return a;
  }

  extern(Windows) LRESULT LowLevelMouseProc(int nCode, WPARAM wParam, LPARAM lParam) nothrow
  {
    try{
      bool log = false;
      const hs = cast(MSLLHOOKSTRUCT*)lParam;
      if(hs){
        switch(wParam){
          case WM_LBUTTONDOWN: break;
          case WM_LBUTTONUP: break;
          case WM_MOUSEMOVE: break;
          case WM_MOUSEWHEEL: break;
          case WM_RBUTTONDOWN: break;
          case WM_RBUTTONUP: break;
          default: break;
        }
        if(log) print("mouse:", nCode, wParam, *hs);
      }
    }catch(Exception){}

    return CallNextHookEx(null, nCode, wParam, lParam);
  }

  auto installGlobalMouseHook(){
    auto a = SetWindowsHookEx(WH_MOUSE_LL, &LowLevelMouseProc, GetModuleHandle(null), 0);
    if(!a) writeln("fail:k0");
    return a;
  }

}
