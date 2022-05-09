module het.view;

import het.win, het.inputs;

class View2D {
public:
  private Window owner_;
  @property auto owner(){
    enforce(owner_ !is null, "Forgot to set View2D.owner");
    return owner_;
  }
  @property void owner(Window w){ owner_ = w; }

private:
  float m_logScale = 0, //base value. all others are derived from it
        m_scale = 1, m_invScale = 1; //1 -> 1unit = pixel on screen

  float m_logScale_anim = 0;
  vec2 m_origin_anim;

  bool animStarted;
public:
  vec2 origin;

  // extra information from external source in screen space
  vec2 mousePos;
  bounds2 clipBounds;

  this(){}

  this(in vec2 origin, float scale){
    this.origin = origin;
    this.scale = scale;
  }

  override string toString() const {
    return format!"View2D(%s, %s)"(origin, scale);
  }

  @property{ float logScale() const { return m_logScale; }  void  logScale(float s){ m_logScale = s; m_scale = pow(2, logScale); m_invScale = 1/scale; }  }
  @property{ float scale   () const { return m_scale;    }  void  scale   (float s){ logScale = log2(s); }                                                }
  @property{ float invScale() const { return m_invScale; }  void  invScale(float s){ logScale = log2(1/s); }                                              }
  //animated stuff
  float animSpeed = 0.3; //0=off, 0.3=normal, 0.9=slow
  auto origin_anim()   const { return m_origin_anim; }
  auto scale_anim()    const { return pow(2, m_logScale_anim); }
  auto invScale_anim() const { return 1.0f/scale_anim; }

  bounds2 workArea, workArea_accum; //next workarea is the currently built one being drawn

  auto subScreenArea = bounds2(0, 0, 1, 1); // if there is some things on the screen that is in front of the view, it can be used to set the screen to a smaller portion of the viewPort

  auto subScreenOrigin(){
    vec2 res = origin;
    if(subScreenArea.valid){
      auto subScreenShift = clientSize * (subScreenArea.center - vec2(.5, .5)); //in pixels
      res += subScreenShift * invScale;
    }
    return res;
  }

  auto subScreenOrigin_anim(){
    vec2 res = origin_anim;
    if(subScreenArea.valid){
      auto subScreenShift = clientSize * (subScreenArea.center - vec2(.5, .5)); //in pixels
      res += subScreenShift * invScale_anim;
    }
    return res;
  }


  vec2 clientSize()                { return vec2(owner.clientSize); }
  vec2 clientSizeHalf()            { return clientSize*0.5f; } //floor because otherwise it would make aliasing in the center of the view

  bounds2 visibleArea(bool animated = true)
  {
    vec2 mi = invTrans(vec2(0)   , animated),
         ma = invTrans(clientSize, animated);
    return bounds2(mi, ma).sorted;
  }

  bool centerCorrection; //it is needed for center aligned images. Prevents aliasing effect on odd client widths/heights.

  auto getOrigin(bool animated){
    vec2 res = animated ? origin_anim : origin;
    if(centerCorrection){
      with(clientSize){
        if(x.iround&1) res.x += 0.5f/getScale(animated);  //opt:fucking slow, need to be cached
        if(y.iround&1) res.y += 0.5f/getScale(animated);
      }
    }
    return res;
  }
  auto getScale(bool animated){
    float res = animated ? scale_anim : scale;
    return res;
  }

  //todo: make this transformation cached and fast!
  T trans(T)(in T world, bool animated=true)     { return ((world-getOrigin(animated))*getScale(animated)+clientSizeHalf); }  //opt: fucking slow, need to be cached
  T invTrans(T)(in T client, bool animated=true) { return (client-clientSizeHalf)/getScale(animated) + getOrigin(animated); }

  //Scroll/Zoom User controls
  bool scrollSlower;       //also affects zoom
  float scrollRate() const      { return scrollSlower ? 0.125f : 1; }

  void scroll(in vec2 delta)    { origin -= delta*(scrollRate*invScale); }
  void scrollH(float delta)     { scroll(vec2(delta, 0)); }
  void scrollV(float delta)     { scroll(vec2(0, delta)); }

  void zoom(float amount)       { scale = pow(2, log2(scale)+amount*scrollRate); }

  void zoomBounds(in bounds2 bb, float overZoomPercent = 3){
    if(!bb.valid || !subScreenArea.valid) return;
    //corrigate according to subScreenArea
    auto realClientSize = clientSize * subScreenArea.size; //in pixels
    auto subScreenShift = clientSize * (subScreenArea.center - vec2(.5, .5)); //in pixels

    origin = bb.center;
    auto s = bb.size;
    //maximize(s.x, .001f); maximize(s.y, .001f);
    auto sc = realClientSize/bb.size;
    scale = min(sc.x, sc.y)*(1 - overZoomPercent*.01f); //overzoom a bit

    //corrigate according to subScreenArea: shift
    origin -= subScreenShift * invScale;
  }

  bool _mustZoomAll; //schedule zoom all on the next draw

  void zoomAll_later(){ _mustZoomAll = true; }

  void zoomAll(){ zoomBounds(workArea); }

  void zoomAll_immediate(){
    zoomAll;
    skipAnimation;
  }

  void zoomAround(in vec2 screenPoint, float amount) {  //todo: the zoom and the translation amount is not proportional. Fast zooming to the side looks bad. Zoom in center is ok.
    if(!amount) return;
    auto sh = screenPoint-clientSizeHalf;
    origin += sh*invScale;
    zoom(amount);
    origin -= sh*invScale;
  }
  void zoomAroundMouse(float amount) { zoomAround(trans(mousePos), amount); }

  ///Automatically call zoomAll() when workArea changes
  private bounds2 lastWorkArea; //detection change for autoZoom()
  bool autoZoom(){
    if(workArea.area>0 && chkSet(lastWorkArea, workArea)){
      zoomAll;
      return true;
    }
    return false;
  }

  // navigate 2D view with the keyboard and the mouse
  // it optionally calls invalidate
  bool navigate(bool keyboardEnabled, bool mouseEnabled){
    auto oldOrigin = origin;
    auto oldScale = scale;

    with(owner.actions){
      const scrollSpeed = owner.deltaTime.value(second)*800,
            zoomSpeed   = owner.deltaTime.value(second)*6,
            wheelSpeed  = 0.375f;

      group("View controls");          ////todo: ctrl+s es s (mint move osszeakad!)

      const enm = mouseEnabled;   //todo: actions are deprecated. This view.navigate function should be replaced with az IMGUI enable flag and a hidden window.
      onActive  ("Scroll"              , "MMB RMB"     , enm, { scroll(inputs.mouseDelta); }         );
      onDelta   ("Zoom"                , "MW"          , enm, (x){ zoomAroundMouse(x*wheelSpeed); }  );

      const enk = keyboardEnabled;
      onActive  ("Scroll left"         , "A"           , enk, { scrollH( scrollSpeed); }             );
      onActive  ("Scroll right"        , "D"           , enk, { scrollH(-scrollSpeed); }             );
      onActive  ("Scroll up"           , "W"           , enk, { scrollV( scrollSpeed); }             );
      onActive  ("Scroll down"         , "S"           , enk, { scrollV(-scrollSpeed); }             );
      onActive  ("Zoom in"             , "PgUp"        , enk, { zoom( zoomSpeed); }                  );
      onActive  ("Zoom out"            , "PgDn"        , enk, { zoom(-zoomSpeed); }                  );
      onModifier("Scroll/Zoom slower"  , "Shift"       , enk, scrollSlower                           );
      onPressed ("Zoom all"            , "Home"        , enk, { zoomAll; }                           );
    }

    bool res = origin!=oldOrigin || scale!=oldScale;
    if(res) owner.invalidate;
    return res;
  }

  bool updateAnimation(float deltaTime, bool callInvalidate){  //todo: use quantities.time
    float at = calcAnimationT(deltaTime, animSpeed);
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

