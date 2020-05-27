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

import het.utils, het.geometry,
       core.sys.windows.windows, core.sys.windows.winuser, std.json;

__gshared int[] virtualKeysDown;

// Utils /////////////////////////////////////////////////////////////////////

void getKeyboardDelays(ref double d1, ref double d2){
  //Gets windows keyboard delays in seconds
  //note: The query takes 6microsecs only, so it can go into the update loop
  int val;

  SystemParametersInfoW(SPI_GETKEYBOARDDELAY, 0, &val, 0);
  d1 = remap(val, 0, 3, 0.250, 1); //0: 250ms .. 3: 1sec

  SystemParametersInfoW(SPI_GETKEYBOARDSPEED, 0, &val, 0);
  d2 = 1.0/remap(val, 0, 31, 2.5, 30); //0: 2.5hz .. 31: 30Hz
}

void _notifyMouseWheel(float delta) //Must be called from outside, from a Window loop in Window.d
{
  MouseInputHandler.wheelDeltaAccum += delta;
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

InputManager inputs(){ //global access point
  __gshared static InputManager _inputs;
  if(!_inputs){ //Create the first inputManager and initialize
    _inputs = new InputManager();
    _inputs.registerInputHandler(new KeyboardInputHandler);
    _inputs.registerInputHandler(new MouseInputHandler);
    _inputs.registerInputHandler(new PotiInputHandler);
    _inputs.registerInputHandler(new XInputInputHandler);
  }
  return _inputs;
};

enum InputEntryType{ //Operation      Examples
  digitalState,   //=0 Off, !=0 On.        a switch
  analogState,    //[0..1]                 Volume potmeter, Light level, Piano key state
  digitalButton,  //=0 Off, !=0 On.        normally released. Keyboard, MouseButton
  analogButton,   //[0..1]                 normally released. Left/Right trigger, piano note
  absolute,       //any value              Mouse ScreenPos, position of a playback time slider
  delta,          //any value              Mouse Wheel, Jog wheel
}

class InputEntry{
  const InputHandlerBase owner;
  const string name;
  const InputEntryType type;
  float value=0, lastValue=0;

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

  float pressedTime = 0;

  // repeat support, for typing emulation
  static double repeatDelay1 = 0.5;
  static double repeatDelay2 = 0.125; //updated from outside

  private{
    bool repeated_;
    double repeatNextTime = 0;
  }

  bool repeated()const { return repeated_; }

  void _updateRepeated(double now){
    repeated_ = false;
    if(value){
      if(pressed){
        repeated_ = true;
        repeatNextTime = now+repeatDelay1;
      }else{
        if(now>=repeatNextTime){
          repeated_ = true;
          repeatNextTime = now+repeatDelay2;
        }
      }
    }
  }

}

class InputHandlerBase{
  string category;
  InputEntry[] entries;
  void update() { }
  this() { }
}

class InputManager{
private:
  bool initialized = false;

  InputEntry nullEntry;

  void rehashAll() { entries.rehash; handlers.rehash; }
  void error(string s) { throw new Exception("InputManager: "~s); }

  double now; //local fast time in seconds
public:
  InputHandlerBase[string] handlers;
  InputEntry[string] entries;

  this(){
    //add the nullEntry
    nullEntry = new InputEntry(null, InputEntryType.digitalState, "null");
    entries [nullEntry.name] = nullEntry;
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
    clearDeltas;
    foreach(h; handlers) h.update;

    getKeyboardDelays(InputEntry.repeatDelay1, InputEntry.repeatDelay2); //todo: this is only needed once a sec, dunno how slow it is.
    foreach(e; entries){
      if(e.pressed) e.pressedTime = now;
      e._updateRepeated(now);
    }
  }

  void clearDeltas() {
    foreach(e; entries) e.lastValue = e.value;
  }

  InputEntry opIndex(string name){
    auto e = name in entries;
    return e ? *e : nullEntry;
  }

  InputEntry opDispatch(string name)(){
    return opIndex(name);
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
      auto k = keys.split('+').map!strip.array;
      if(k.empty) allDown = false; //empty combo

      foreach(key; k) if(!this[key].value){ allDown = false; break; }

      if(!allDown) return false; //not this key combo

      final switch(mode){
        case QueryMode.Active : return true;
        case QueryMode.Pressed: return this[k[$-1]].pressed; //todo: wrong
        case QueryMode.Typed  : return this[k[$-1]].repeated; //todo: wrong
//        case QueryMode.Released:return this[k[$-1]].released; //todo: wrong
      }
    }

  }

  bool active (string keys) { return _query(keys, QueryMode.Active ); }
  bool pressed(string keys) { return _query(keys, QueryMode.Pressed); }
  bool typed  (string keys) { return _query(keys, QueryMode.Typed  ); }
//  bool released(string keys) { return _query(keys, QueryMode.Released ); }

public: //standard stuff
  V2f mouseAct()    const { return V2f(entries["MX"].value, entries["MY"].value); }
  V2f mouseDelta()  const { return V2f(entries["MX"].delta, entries["MY"].delta); }
  bool mouseMoved() const { return entries["MX"].changed || entries["MY"].changed; }
  float mouseWheelDelta() const { return entries["MW"].delta; }

  int keyModifierMask() {
    int res;
    foreach(i, s; keyModifiers) if(entries[s].active) res += 1<<i;
    return res;
  };
  alias modifiers = keyModifierMask;

}


/////////////////////////////////////////////////////////////////////////////
///  Keyboard input handler                                               ///
/////////////////////////////////////////////////////////////////////////////

class KeyboardInputHandler: InputHandlerBase {
private:
  ubyte[256] keys;
  InputEntry[256] emap;

  InputEntry eWin; //there is no Win = LWin | RWin key on the map, so emulate it.
  InputEntry eCapsLockState, eNumLockState, eScrLockState; //toggled states

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

    //Top row
    add(VK_ESCAPE, "Esc");
    foreach(i; 0..24) add(VK_F1+i, "F"~text(i+1));
    add(VK_SNAPSHOT, "PrnScr");
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
    add(VK_XBUTTON1, "XB1"); add(VK_XBUTTON2, "XB2"); //back, fwd on mouse

    //Multimedia
    add(7                       , "XBox");
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
  }

  override void update(){
    GetKeyboardState(&keys[0]);

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

//    foreach(int i; 0..256) if(keys[i]&0x80) write(" ", i); writeln;
  }

}


/////////////////////////////////////////////////////////////////////////////
///  Mouse movement input handler                                         ///
/////////////////////////////////////////////////////////////////////////////

class MouseInputHandler: InputHandlerBase {
private:
  InputEntry mx, my, mw, mxr, myr;
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


  //global access for all DInput functionality
  public auto DInput(){ //global access
    static __gshared DInputWrapper f;
    if(!f) f = new DInputWrapper;
    return f;
  }

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

auto rawMousePos  (){ return V2f(inputs.MXraw.value, inputs.MYraw.value); };
auto rawMouseDelta(){ return V2f(inputs.MXraw.delta, inputs.MYraw.delta); };

void mouseLock(V2i pos){ with(pos){
  //clamp to the screen, otherwise winapi will unlock the mouse
  RECT r;
  GetWindowRect(GetDesktopWindow, &r);
  pos.x = pos.x.clamp(r.left, r.right-1);
  pos.y = pos.y.clamp(r.top, r.bottom-1);

  r = RECT(x, y, x+1, y+1);
  ClipCursor(&r);
}}

void mouseLock(in V2f pos){ mouseLock(pos.vFloor); }

void mouseLock(){ mouseLock(winMousePos); }

void mouseUnlock(){ ClipCursor(null); }

void slowMouse(bool enabled, float speed=0.25f){
  slowMouseSpeed = speed;

  if(slowMouseEnabled==enabled) return;
  slowMouseEnabled = enabled;
  slowMousePos = winMousePos.toF+V2f(0.5f, 0.5f);
  if(enabled) mouseLock(winMousePos);
         else mouseUnlock;
}

void mouseMoveRel(float dx, float dy){
  if(!dx && !dy) return;

  if(slowMouseEnabled){
    slowMousePos += V2f(dx, dy);
  }else{
    POINT p; GetCursorPos(&p);
    SetCursorPos(p.x+dx.iRound, p.y+dy.iRound);
  }
}

void mouseMoveRel(V2f d){ mouseMoveRel(d.x, d.y); }
void mouseMoveRelX(float dx){ mouseMoveRel(dx, 0); }
void mouseMoveRelY(float dy){ mouseMoveRel(0, dy); }

private __gshared{
  bool slowMouseEnabled;
  float slowMouseSpeed;
  V2f slowMousePos;

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
      slowMousePos = winMousePos.toF+V2f(0.5f, 0.5f);
    }
  }

  //winapi mouse get/set
  V2i winMousePos(){
    POINT p; GetCursorPos(&p);
    return V2i(p.x, p.y);
  }
}

// MouseState wrapper class ///////////////////////////////////////////////////

class MouseState{
public:
  struct MSRelative{
    V2i screen = V2i.Null;
    V2f world = V2f.Null;
    int wheel;

    float screenDist=0, worldDist=0;
  }
  struct MSAbsolute{
    bool LMB, RMB, MMB, shift, alt, ctrl;
    V2i screen = V2i.Null;
    V2f world = V2f.Null;
    int wheel;
  }

public:
  MSAbsolute act, last, pressed;
  MSRelative delta, hover, hoverMax;
  bool justPressed, justReleased, LMB, MMB, RMB;
  Bounds2i screenRect, screenSelectionRect;
  Bounds2f worldRect, worldSelectionRect;
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

    maximize(hoverMax.screen, vAbs(hover.screen));
    maximize(hoverMax.world , vAbs(hover.world ));

    //calc distances
    void dist(ref MSRelative res){
      res.screenDist = res.screen.toF.len_prec;
      res.worldDist  = res.world.len_prec;
    }

    dist(delta);
    dist(hover);
    dist(hoverMax);

    LMB = pressed.LMB && act.LMB;
    MMB = pressed.MMB && act.MMB;
    RMB = pressed.RMB && act.RMB;

    screenSelectionRect = Bounds2i(pressed.screen, act.screen, true);
    worldSelectionRect = Bounds2f(pressed.world, act.world, true);

    moving = !delta.world.isNull;
  }

  bool inWorld () const { return worldRect .checkInsideRect(act.world ); }
  bool inScreen() const { return screenRect.checkInsideRect(act.screen); }
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

//global access for all XInput functionality
auto XInput() //global access
{
  static __gshared XInputFuncts f;
  if(!f) f = new XInputFuncts;
  return f;
}

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

    addAnalog(4, "xiLT", true);                addAnalog(6, "xiT");              addAnalog( 5, "xiRT", true);
    addButton(8, "xiLB");                                                        addButton( 9, "xiRB");
    addButton(0, "xiUp");     addButton( 5, "xiBack"); addButton( 4, "xiStart"); addButton(12, "xiA");
    addButton(1, "xiDown");                                                      addButton(13, "xiB");
    addButton(2, "xiLeft");                                                      addButton(14, "xiX");
    addButton(3, "xiRight");  addButton( 6, "xiLS");   addButton( 7, "xiRS");    addButton(15, "xiY");

    addAnalog(0, "xiLX"); addAnalog(1, "xiLY");            addAnalog(2, "xiRX"); addAnalog(3, "xiRY");
  }

  override void update(){
    auto st = XInput.getState;

    foreach(int idx, e; buttons) if(e) e.value = (st.wButtons>>idx)&1;
    axes[0].value = st.sThumbLX*(1.0f/32768);
    axes[1].value = st.sThumbLY*(1.0f/32768);
    axes[2].value = st.sThumbRX*(1.0f/32768);
    axes[3].value = st.sThumbRY*(1.0f/32768);
    axes[4].value = st.bLeftTrigger*(1.0f/256);
    axes[5].value = st.bRightTrigger*(1.0f/256);
    axes[6].value = axes[5].value-axes[4].value;
  }

}

/////////////////////////////////////////////////////////////////////////////
///  Actions                                                              ///
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

