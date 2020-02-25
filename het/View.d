module het.view;

import het.win, het.inputs;

struct View2D {
private:
  Window owner;
  float m_logScale = 0, //base value. all others are derived from it
        m_scale = 1, m_invScale = 1; //1 -> 1unit = pixel on screen

  float m_logScale_anim = 0;
  V2f m_origin_anim = V2f.Null;

  bool animStarted;
public:
  V2f origin = V2f.Null;

  @property{ float logScale() const { return m_logScale; }  void  logScale(float s){ m_logScale = s; m_scale = pow(2, logScale); m_invScale = 1/scale; }  }
  @property{ float scale   () const { return m_scale;    }  void  scale   (float s){ logScale = log2(s); }                                                }
  @property{ float invScale() const { return m_invScale; }  void  invScale(float s){ logScale = log2(1/s); }                                              }
  //animated stuff
  float animSpeed = 0.3; //0=off, 0.3=normal, 0.9=slow
  auto origin_anim()  const { return m_origin_anim; }
  auto scale_anim()   const { return pow(2, m_logScale_anim); }

  private Bounds2f workArea_;
  @property{
    auto workArea() const { return workArea_; }
    void workArea(const Bounds2f b) { workArea_ = b; }
    void workArea(const Bounds2i b) { workArea_ = b.toF; } //that's retarded, Bounds2f should accept Bounds2i
  }

  @disable this();
  this(Window owner) {
    this.owner = owner;
  }

  V2f clientSize()                { return owner.clientSize.toF; }
  V2f clientSizeHalf()            { return clientSize*0.5; } //floor because otherwise it would make aliasing in the center of the view

  Bounds2f visibleArea(bool animated = true)
  {
    V2f mi = invTrans(V2f(0,0), animated),
        ma = invTrans(clientSize, animated);
    return Bounds2f(mi, ma, true);
  }

  bool centerCorrection; //it is needed for center aligned images. Prevents aliasing effect on odd client widths/heights.

  auto getOrigin(bool animated){
    V2f res = animated ? origin_anim : origin;
    if(centerCorrection){
      with(clientSize){
        if(x.iRound&1) res.x += 0.5/getScale(animated);  //opt:fucking slow, need to be cached
        if(y.iRound&1) res.y += 0.5/getScale(animated);
      }
    }
    return res;
  }
  auto getScale(bool animated){
    float res = animated ? scale_anim : scale;
    return res;
  }

  //todo: make this transformation cached and fast!
  V2f trans(const V2f world, bool animated=true)     { return ((world-getOrigin(animated))*getScale(animated)+clientSizeHalf); }  //opt: fucking slow, need to be cached
  V2f invTrans(const V2f client, bool animated=true) { return (client-clientSizeHalf)/getScale(animated) + getOrigin(animated); }

  V2f mouseAct()                { return owner.screenToClient(inputs.mouseAct); }

  //Scroll/Zoom User controls
  bool scrollSlower;       //also affects zoom
  float scrollRate() const      { return scrollSlower ? 0.125f : 1; }

  void scroll(const V2f delta)  { origin -= delta*(scrollRate*invScale); }
  void scrollH(float delta)     { scroll(V2f(delta, 0)); }
  void scrollV(float delta)     { scroll(V2f(0, delta)); }

  void zoom(float amount)       { scale = pow(2, log2(scale)+amount*scrollRate); }

  void zoomBounds(const Bounds2f bb){
    if(bb.isNull) return;
    origin = bb.center;
    auto s = bb.size;
    if(s.len_prec==0) return;
    maximize(s.x, .001f);
    maximize(s.y, .001f);
    auto sc = clientSize/bb.size;
    scale = min(sc.x, sc.y)*.97f; //overzoom a bit
  }

  void zoomAll() {
    zoomBounds(workArea);
  }

  void zoomAround(const V2f point, float amount) {
    if(!amount) return;
    auto sh = point-clientSizeHalf;
    origin += sh*invScale;
    zoom(amount);
    origin -= sh*invScale;


  }
  void zoomAroundMouse(float amount) { zoomAround(mouseAct, amount); }


  // navigate 2D view with the keyboard and the mouse
  // it optionally calls invalidate
  bool navigate(bool keyboardEnabled, bool mouseEnabled){
    auto oldOrigin = origin;
    auto oldScale = scale;

    with(owner.actions){
      const scrollSpeed = owner.deltaTime*800,
            zoomSpeed   = owner.deltaTime*6,
            wheelSpeed  = 0.375f;

      group("View controls");          ////todo: ctrl+s es s (mint move osszeakad!)

      bool en = mouseEnabled;   //todo: actions are deprecated. This view.navigate function should be replaced with az IMGUI enable flag and a hidden window.
      onActive  ("Scroll"              , "MMB RMB"     , { if(en) scroll(inputs.mouseDelta); }         );
      onDelta   ("Zoom"                , "MW"          , (x){ if(en) zoomAroundMouse(x*wheelSpeed); }  );

      en = keyboardEnabled;
      onActive  ("Scroll left"         , "A"           , { if(en) scrollH( scrollSpeed); }             );
      onActive  ("Scroll right"        , "D"           , { if(en) scrollH(-scrollSpeed); }             );
      onActive  ("Scroll up"           , "W"           , { if(en) scrollV( scrollSpeed); }             );
      onActive  ("Scroll down"         , "S"           , { if(en) scrollV(-scrollSpeed); }             );
      onActive  ("Zoom in"             , "PgUp"        , { if(en) zoom( zoomSpeed); }                  );
      onActive  ("Zoom out"            , "PgDn"        , { if(en) zoom(-zoomSpeed); }                  );
      onModifier("Scroll/Zoom slower"  , "Shift"       , scrollSlower                                  );
      onPressed ("Zoom all"            , "Home"        , { if(en) zoomBounds(workArea); }              );
    }

    bool res = origin!=oldOrigin || scale!=oldScale;
    if(res) owner.invalidate;
    return res;
  }

  bool updateAnimation(float deltaTime, bool callInvalidate){
    float at = animationT(deltaTime, animSpeed);
    if(chkSet(animStarted)) at = 1;

    bool res;
    res |= follow(m_origin_anim, origin, at, invScale*1e-2f);
    res |= follow(m_logScale_anim, logScale, at, 1e-2f);

    if(res && callInvalidate) owner.invalidate;
    return res;
  }

  //skips the animated moves to their destination immediately
  void skipAnimation(){
    updateAnimation(9999, false);
  }

  //update smooth navigation. invalidates automatically
  /*bool _updateInternal(bool processActions){
    bool res;
    //if(processActions) res |= updateActions; -> call it manually with navigate()
    res |= updateAnimation(owner.deltaTime, true);
    return res;
  }*/

  @property string config() {
    return format("%f %f %f", logScale, origin.x, origin.y);
  }
  @property void config(string s) {
    try{
      auto a = s.split(' ').map!(x => to!float(x));
      if(a.length==3){
        logScale        = a[0];
        origin.x        = a[1];
        origin.y        = a[2];
      }
    }catch(Throwable){}
  }

}

