//@exe
//@import c:\d\libs
//@ldc
//@compile -m64 -mcpu=athlon64-sse3 -mattr=+ssse3
///@release
//@debug

///@compile --unittest  //this is broken because of my shitty linker usage

import het.utils;


// ShaderToy inputs
vec2 iResolution;
float iTime = 0.86;


static if(0){

  /**
   * @author jonobr1 / http://jonobr1.com/
   */

  /**
   * Convert r, g, b to normalized vec3
   */
  vec3 rgb(float r, float g, float b) {
    return vec3(r / 255.0, g / 255.0, b / 255.0);
  }

  /**
   * Draw a circle at vec2 `pos` with radius `rad` and
   * color `color`.
   */
  vec4 circle(vec2 uv, vec2 pos, float rad, vec3 color) {
    float d = length(pos - uv) - rad;
    float t = clamp(d, 0.0, 1.0);
    return vec4(color, 1.0 - t);
  }

  void mainImage(out vec4 fragColor, in vec2 fragCoord ) {
    vec2 uv = fragCoord.xy;

    vec2 center = iResolution.xy * 0.5;
    float radius = 0.25 * iResolution.y;

      // Background layer
    vec4 layer1 = vec4(rgb(210.0, 222.0, 228.0), 1.0);

    // Circle
    vec3 red = rgb(225.0, 95.0, 60.0);
    vec4 layer2 = circle(uv, center, radius, red);

    // Blend the two
    fragColor = mix(layer1, layer2, layer2.a);
  }

}

static if(0){
    // https://www.shadertoy.com/view/lsX3W4
    // Created by inigo quilez - iq/2013
    // License Creative Commons Attribution-NonCommercial-ShareAlike 3.0 Unported License.


    // This shader computes the distance to the Mandelbrot Set for everypixel, and colorizes
    // it accoringly.
    //
    // Z -> Z^^2+c, Z0 = 0.
    // therefore Z' -> 2 dot Z dot Z' + 1
    //
    // The Hubbard-Douady potential G(c) is G(c) = log Z/2^n
    // G'(c) = Z'/Z/2^n
    //
    // So the distance is |G(c)|/|G'(c)| = |Z| dot log|Z|/|Z'|
    //
    // More info here: http://www.iquilezles.org/www/articles/distancefractals/distancefractals.htm


    float distanceToMandelbrot( in vec2 c )
    {
        //#if 1
        {
            float c2 = dot(c, c);
            // skip computation inside M1 - http://iquilezles.org/www/articles/mset_1bulb/mset1bulb.htm
            if( 256.0*c2*c2 - 96.0*c2 + 32.0*c.x - 3.0 < 0.0 ) return 0.0;
            // skip computation inside M2 - http://iquilezles.org/www/articles/mset_2bulb/mset2bulb.htm
            if( 16.0*(c2+2.0*c.x+1.0) - 1.0 < 0.0 ) return 0.0;
        }
        //#endif

        // iterate
        float di =  1.0;
        vec2 z  = vec2(0.0);
        float m2 = 0.0;
        vec2 dz = vec2(0.0);
        for( int i=0; i<300; i++ )
        {
            if( m2>1024.0 ) { di=0.0; break; }

        // Z' -> 2*Z*Z' + 1
            dz = 2.0f*vec2(z.x*dz.x-z.y*dz.y, z.x*dz.y + z.y*dz.x) + vec2(1.0,0.0);

            // Z -> Z^^2 + c
            z = vec2( z.x*z.x - z.y*z.y, 2.0*z.x*z.y ) + c;

            m2 = dot(z,z);
        }

        // distance
      // d(c) = |Z|*log|Z|/|Z'|
      float d = 0.5*sqrt(dot(z,z)/dot(dz,dz))*log(dot(z,z));
        if( di>0.5 ) d=0.0;

        return d;
    }

    void mainImage( out vec4 fragColor, in vec2 fragCoord )
    {
        vec2 p = (2.0*fragCoord-iResolution.xy)/iResolution.y;

        // animation
      float tz = 0.5 - 0.5*cos(0.225*iTime);
        float zoo = pow( 0.5, 13.0*tz );
      vec2 c = vec2(-0.05,.6805) + p*zoo;

        // distance to Mandelbrot
        float d = distanceToMandelbrot(c);

        // do some soft coloring based on distance
      d = clamp( pow(4.0*d/zoo,0.2), 0.0, 1.0 );

        vec3 col = vec3(d);

        fragColor = vec4( col, 1.0 );
    }

}

static if(1){
  //https://www.shadertoy.com/view/MtfGWM

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

void main(){ //static import het.utils; het.utils.application.runConsole({
  het.math.unittest_main;
  import het.image;

  if(0){
    foreach(i; 0..100){
      auto p1 = iround(vec2(sin(i*0.2), cos(i*0.3))*10+12),  bnd1 = ibounds2(p1-3, p1+3);
      auto p2 = iround(vec2(sin(i*0.3), cos(i*0.5))*10+12),  bnd2 = ibounds2(p2-3, p2+3);

      auto bnd12 = bnd1 & bnd2;
      writeln("assert((%s & %s) == %s);".format(bnd1, bnd2, bnd12));

      foreach(y; 0..24){
        foreach(x; 0..24){
          auto p = ivec2(x, y);
          write(p in bnd12 ? '$' : ".abC"[(p in bnd1 ? 1 : 0) + (p in bnd2 ? 2 : 0)]);
        }
        writeln;
      }
      readln;
    }
  }



  iResolution = vec2(76, 50);
  foreach_reverse(y; 0..iResolution.y){
    foreach(x; iota(0, iResolution.x, 0.5)){
      vec2 fragCoord = vec2(x, y);
      vec4 fragColor;
      mainImage(fragColor, fragCoord);

      auto ch = " .+%@"[((fragColor.rgb*grayscaleWeights).sum*5).ifloor.clamp(0, 4)]; //todo: quantize
      write(ch);
    }
    writeln;
  }


}
