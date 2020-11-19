//@exe
//@import c:\d\libs
//@ldc
//@compile -m64 -mcpu=athlon64-sse3 -mattr=+ssse3
//@release
///@debug

///@compile --cov

import het.utils;

//! ShaderToy tests ///////////////////////////////////////////////////////////////////

vec2 iResolution;
float iTime = 0;

static if(1){ // 3D Julia ////////////////////////////////////////////////
  // https://www.shadertoy.com/view/MtfGWM
  //another holy grail candidate from msltoe found here:
  //http://www.fractalforums.com/theory/choosing-the-squaring-formula-by-location

  //I have altered the formula to make it continuous but it still creates the same nice julias - eiffie

  alias time = iTime;
  alias size = iResolution;

  vec3 C,mcol;
  bool bColoring=false;
  enum pi = 3.14159f;
  float DE(vec3 p){
    float dr=1.0,r=length(p);
    //C=p;
    for(int i=0;i<10;i++){
      if(r>20.0)break;
      dr=dr*2.0*r;
      float psi = abs(mod(atan(p.z,p.y)+pi/8.0,pi/4.0)-pi/8.0);
      p.yz=vec2(cos(psi),sin(psi))*length(p.yz);
      vec3 p2=p*p;
      p=vec3(vec2(p2.x-p2.y,2.0*p.x*p.y)*(1.0-p2.z/(p2.x+p2.y+p2.z)),
        2.0*p.z*sqrt(p2.x+p2.y))+C;
      r=length(p);
      if(bColoring && i==3)mcol=p;
    }
    return min(log(r)*r/max(dr,1.0),1.0);
  }

  float rnd(vec2 c){return fract(sin(dot(vec2(1.317,19.753),c))*413.7972);}
  float rndStart(vec2 fragCoord){
    return 0.5+0.5*rnd(fragCoord.xy+vec2(time*217.0));
  }
  float shadao(vec3 ro, vec3 rd, float px, vec2 fragCoord){//pretty much IQ's SoftShadow
    float res=1.0,d,t=2.0*px*rndStart(fragCoord);
    for(int i=0;i<4;i++){
      d=max(px,DE(ro+rd*t)*1.5);
      t+=d;
      res=min(res,d/t+t*0.1);
    }
    return res;
  }
  vec3 Sky(vec3 rd){//what sky??
    return vec3(0.5+0.5*rd.y);
  }
  vec3 L;
  vec3 Color(vec3 ro, vec3 rd, float t, float px, vec3 col, bool bFill, vec2 fragCoord){
    ro+=rd*t;
    bColoring=true;float d=DE(ro);bColoring=false;
    vec2 e=vec2(px*t,0.0);
    vec3 dn=vec3(DE(ro-e.xyy),DE(ro-e.yxy),DE(ro-e.yyx));
    vec3 dp=vec3(DE(ro+e.xyy),DE(ro+e.yxy),DE(ro+e.yyx));
    vec3 N=(dp-dn)/(length(dp-vec3(d))+length(vec3(d)-dn));
    vec3 R=reflect(rd,N);
    vec3 lc=vec3(1.0,0.9,0.8),sc=sqrt(abs(sin(mcol))),rc=Sky(R);
    float sh=clamp(shadao(ro,L,px*t,fragCoord)+0.2,0.0,1.0);
    sh=sh*(0.5+0.5*dot(N,L))*exp(-t*0.125);
    vec3 scol=sh*lc*(sc+rc*pow(max(0.0,dot(R,L)),4.0));
    if(bFill)d*=0.05;
    col=mix(scol,col,clamp(d/(px*t),0.0,1.0));
    return col;
  }
  mat3 lookat(vec3 fw){
    fw=normalize(fw);vec3 rt=normalize(cross(fw,vec3(0.0,1.0,0.0)));return mat3(rt,cross(rt,fw),fw);
  }

  vec3 Julia(float t){
    t=mod(t,5.0);
    if(t<1.0)return vec3(-0.8,0.0,0.0);
    if(t<2.0)return vec3(-0.8,0.62,0.41);
    if(t<3.0)return vec3(-0.8,1.0,-0.69);
    if(t<4.0)return vec3(0.5,-0.84,-0.13);
    return vec3(0.0,1.0,-1.0);
  }

  void mainImage( out vec4 fragColor, in vec2 fragCoord ) {
    float px=0.5/size.y;
    L=normalize(vec3(0.4,0.8,-0.6));
    float tim=time*0.5;

    vec3 ro=vec3(cos(tim*1.3),sin(tim*0.4),sin(tim))*3.0;
    vec3 rd=lookat(vec3(-0.1)-ro)*normalize(vec3((2.0*fragCoord.xy-size.xy)/size.y,3.0));

    tim*=0.6;
    if(mod(tim,15.0)<5.0)C=mix(Julia(tim-1.0),Julia(tim),smoothstep(0.0,1.0,fract(tim)*5.0));
    else C=vec3(-cos(tim),cos(tim)*abs(sin(tim*0.3)),-0.5*abs(-sin(tim)));

    float t=DE(ro)*rndStart(fragCoord),d=0.0,od=10.0;
    vec3 edge=vec3(-1.0);
    bool bGrab=false;
    vec3 col=Sky(rd);
    for(int i=0;i<78;i++){
      t+=d*0.5;
      d=DE(ro+rd*t);
      if(d>od){
        if(bGrab && od<px*t && edge.x<0.0){
          edge=vec3(edge.yz,t-od);
          bGrab=false;
        }
      }else bGrab=true;
      od=d;
      if(t>10.0 || d<0.00001)break;
    }
    bool bFill=false;
    d*=0.05;
    if(d<px*t && t<10.0){
      if(edge.x>0.0)edge=edge.zxy;
      edge=vec3(edge.yz,t);
      bFill=true;
    }
    for(int i=0;i<3;i++){
      if(edge.z>0.0)col=Color(ro,rd,edge.z,px,col,bFill,fragCoord);
      edge=edge.zxy;
      bFill=false;
    }
    fragColor = vec4(2.0*col,1.0);
  }

}


void gdiDrawFractal(Window win){
  import core.sys.windows.windows;

  auto rect = win.clientRect;
  FillRect(win.hdc, &rect, cast(HBRUSH) (COLOR_WINDOW+2));

  iResolution = vec2(320, 240);
  foreach(p; iResolution.itrunc.iota2){
    vec2 fragCoord = p;
    vec4 fragColor;
    mainImage(fragColor, fragCoord);
    SetPixel(win.hdc, p.x, p.y, fragColor.floatToRgb.lll.raw);
  }
}


class ScannerSimulation{ // ScannerSimulation
  bounds2 targetBounds = bounds2(-16, -16, 16, 16);
  vec2 targetCenter(){ return targetBounds.center; }

  vec2 projectorPos = vec2(-61, 0 );    vec2 projectorDir(){ return normalize(targetCenter-projectorPos); }
  vec2 cameraPos    = vec2(-40, 20);    vec2 cameraDir   (){ return normalize(targetCenter-cameraPos   ); }

  enum resolution = 100;
  enum rayLength = 60.0f;

  int actRay;

  // simulate the highly distorted camera and the projector optics.
  auto cameraRay(int n){ return seg2(cameraPos, cameraPos + cameraDir.rotate(mix(-30.0f, 32.0f, float(n)/resolution).radians - cos(n*0.05f)*0.08f)*70); }
  auto projectorRay(int n){ return seg2(projectorPos, projectorPos + projectorDir.rotate(n.remap(0, resolution, -21.0f, 20.0f).radians + sin(n*0.08f)*0.05f)*100); }


  void draw(Drawing dr, View2D view){ with(dr){
    actRay = (actRay+1)%resolution;
    actRay = QPS.iround % resolution;

    { static bool a; if(!chkSet(a)) mmGrid(view); }

    auto rayColor(int i){ return RGB(RGB(30,30,30) * (i==actRay ? 2 : 1)); }

    foreach(i; 0..resolution) dr.line2(rayColor(i), cameraRay(i)   );
    foreach(i; 0..resolution) dr.line2(rayColor(i), projectorRay(i));


    color = clGray;
    drawRect(targetBounds);
    drawX(targetBounds);
    circle(targetCenter, 32/2);

    dr.line2(ArrowStyle.vector, clLime  , cameraPos    , cameraPos    + 10*cameraDir   );
    dr.line2(ArrowStyle.vector, clYellow, projectorPos , projectorPos + 10*projectorDir);

  }}

}


void maintest(){ //import het.utils; het.utils.application.runConsole({ //! Main ////////////////////////////////////////////
  het.math.unittest_main;

  import het.stream;
  het.stream.unittest_main;

  import het.uibase; //rememberEditedWrappedLines()  drawTextEditorOverlay()
  import het.ui;

//  import common.gcode;
//  import common.gcodeshader;

  //https://solarianprogrammer.com/2013/05/22/opengl-101-matrices-projection-view-model/#:~:text=The%20matrix%20M%2C%20that%20contains,a%20single%20matrix%20for%20efficiency.

  print(123);
//  readln;


/*  import het.math, het.utils, het.debugclient, het.geometry, het.color, het.bitmap, het.win, het.view, het.opengl, het.binpacker, het.megatexturing,
    het.fonts, het.draw2d, het.dialogs, het.keywords, het.tokenizer;

  import het.libvlc, het.fileops, het.http, het.parser, het.stream;*/

//readln; application.exit;

}//); }


/*void main(){
  application.runConsole({
    maintest;
  });
}*/

/*
import het.win;

class MyWin: Window{
  mixin autoCreate;  //automatically creates an instance of this form ath startup

  override void onCreate(){
    maintest;
  }

  override void onPaint(){
    gdiDrawFractal;
  }

}
*/





import het, het.ui;

class MyWin: GLWindow{
  mixin autoCreate;  //automatically creates an instance of this form at startup
public:

  ScannerSimulation sim;

  override void onCreate(){

    // so dome unittests
    //het.math.unittest_main;
    //import het.stream; het.stream.unittest_main;

  }
  override void onUpdate(){
    view.navigate(1,1);

    with(im) Panel({
      padding = "4";
      Text(clRed, "Hello World!");

      uiCellDocumentation;
    });

    invalidate;
  }

  override void onPaint(){
    dr.clear(clBlack);
    if(!sim) sim = new ScannerSimulation;
    sim.draw(dr, view);

    im.draw(dr);
  }
}


