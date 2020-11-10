//@exe
//@import c:\d\libs
//@ldc
//@compile -m64 -mcpu=athlon64-sse3 -mattr=+ssse3
///@release
//@debug

import het; //publicly imports all the other necessary modules (win, geometry, utils, view, etc...)

class FrmMain: GLWindow{
  mixin autoCreate; //automatically creates an instance of this window at startup

//Helper functs, consts ////////////////////////////////////////////////////////////////////////////////////
  static bool isBlack(int n){
    immutable blackSet = [2,4,6,8,10,11,13,15,17,20,22,24,26,28,29,31,33,35];
    return blackSet.canFind(n);
  }
  static bool isRed(int n){
    return n>0 && !isBlack(n);
  }

  //colors
  immutable RGB
    clFrame       = 0x30e0e0   ,
    clBackground  = 0x109010   ,
    clTableText   = 0xd0d0d0   ,
    clTableBlack  = 0x101010   ,
    clTableRed    = 0x2010c0   ;

  void drawFrame(Drawing dr, in bounds2 r){ with(dr){
    color = clFrame;
    lineWidth = 0.04f;
    drawRect(r);
  }}

  void drawFramedText(Drawing dr, in bounds2 rect, string text, float fonth){ with(dr){
    drawFrame(dr, rect);
    color = clTableText;
    fontHeight = fonth;
    textOut(rect.center-vec2(0, fonth*0.38f), text, 0, HAlign.center);
  }}

  vec2 numberPos(int n){
    return n>=1 ? vec2((n-1)/3, 2-(n-1)%3)
                : vec2(-1, n==0 ? 1.5 : 0);
  }

  vec2 numberSize(int n){
    return vec2(1, n>0 ? 1 : 1.5);
  }

  bounds2 numberRect(int n){
    auto p = numberPos(n);
    return bounds2(p, p+numberSize(n));
  }

  vec2 numberCenter(int n){
    return numberRect(n).center;
  }

//AREA classes ///////////////////////////////////////////////////////////////////////////////////////

  class Area{ //an area on a table. Can be drawn, checked for mouse, returns the winning rate
    Coin[] coins; //the coin stack placed on this area

    abstract{
      string caption();
      bool check(int n); //checks if number N is a win or not
      float winRate();
      vec2 coinPos();
      float coinWidth();
      void draw(Drawing dr);
    }
  }

  class NumberArea : Area{
    private int number;

    this(int n){
      assert(inRange(n, -1, 36));
      number = n;
    }

    private string text(){
      return number==-1 ? "00"
                        : number.to!string;
    }

    override string caption()   { return "One number: " ~ text; }
    override bool check(int n)  { return number==n; }
    override float winRate()    { return 35; }
    override vec2 coinPos()      { return numberCenter(number); }
    override float coinWidth()  { return 1; }

    override void draw(Drawing dr){with(dr){
      auto pos = numberPos(number);
      auto rect = numberRect(number);

      if(number>0){ //draw red/black circles
        color = isBlack(number) ? clTableBlack : clTableRed;
        pointSize = 0.8;
        point(pos+vec2(0.5, 0.5));
      }

      drawFramedText(dr, rect, text, 0.6);
    }}

  }

  class NumbersArea : Area{ //more than 1 adjacent numbers
    private int[] numbers;
    this(int[] nums){
      nums.each!(x => assert(inRange(x, -1, 36)));
      numbers = nums;
      assert(winRate!=0);
    }

    override string caption()   { return format("%s numbers: %(%s %)", numbers.length, numbers); }
    override bool check(int n)  { return numbers.canFind(n); }
    override float winRate(){
      switch(numbers.length){
        case 2: return 17;
        case 3: return 11;
        case 4: return 8;
        case 5: return 6;
        case 6: return 5;
        default: return 0;
      }
    }
    override vec2 coinPos(){
      vec2 avg = vec2(0);
      foreach(n; numbers) avg += numberCenter(n);
      avg /= numbers.count;

      switch(numbers.length){
        case 2: return avg;
        case 3: return numbers.canFind(0) ? vec2(0, 1.5)
                                          : vec2(numberCenter(numbers[0]).x, 3);
        case 4: return avg;
        case 5: return vec2(0, 3);
        case 6: return vec2(avg.x, 3);
        default: assert(false);
      }
    }
    override float coinWidth()    { return 1; }

    override void draw(Drawing dr) { }
  }

  class DozenArea : Area{
    private int third;

    this(int t){
      assert(inRange(t, 0, 2));
      third = t;
    }

    private string text()       { return ["1ST", "2ND", "3RD"][third]~" 12"; }
    override string caption()   { return "Dozen: " ~ ["1st", "2nd", "3rd"][third]; }
    override bool check(int n)  { return inRange(n, third*12+1, (third+1)*12); }
    override float winRate()    { return 2; }
    override vec2 coinPos()      { return vec2(third*4+2, 3.5); }
    override float coinWidth()  { return 4; }

    override void draw(Drawing dr){with(dr){
      auto pos = vec2(third*4, 3);
      auto rect = bounds2(pos, pos+vec2(4, 1));

      drawFramedText(dr, rect, text, 0.8);
    }}

  }

  class DoubleDozenArea : Area{
    private int idx;

    this(int i){
      assert(inRange(i, 0, 3));
      idx = i;
    }

    override string caption()   { return ["Dozens: 1st, 2nd", "Dozens: 2nd, 3rd", "Columns: 1st, 2nd", "Columns: 2nd, 3rd"][idx]; }
    override bool check(int n)  {
      final switch(idx){
        case 0: return inRange(n,  1, 24);
        case 1: return inRange(n, 13, 36);
        case 2: return n>0 && (n-1)%3!=2;
        case 3: return n>0 && (n-1)%3!=0;
      }
    }
    override float winRate()    { return 0.5; }
    override vec2 coinPos()      { return [vec2(4,3.5), vec2(8,3.5), vec2(12.5,1), vec2(12.5, 2)][idx]; }
    override float coinWidth()  { return 1; }

    override void draw(Drawing dr){ }
  }

  class ColumnArea : Area{
    private int idx;

    this(int i){
      assert(inRange(i, 0, 2));
      idx = i;
    }

    private string text()       { return "2:1"; }
    override string caption()   { return "Column: " ~ ["1", "2", "3"][idx]; }
    override bool check(int n)  { return n>0 && (n-1)%3==idx; }
    override float winRate()    { return 2; }
    override vec2 coinPos()      { return vec2(12, idx)+vec2(0.5, 0.5); }
    override float coinWidth()  { return 1; }

    override void draw(Drawing dr){with(dr){
      auto pos = vec2(12, idx);
      auto rect = bounds2(pos, pos+vec2(1, 1));

      drawFramedText(dr, rect, text, 0.6);
    }}

  }

  class BinaryArea : Area{
  private:
    int idx, xpos;
    string[] texts, captions;

    this(int i){
      assert(inRange(i, 0, 1));
      idx = i;
    }
  public:
    override string caption()   { return captions[idx]; }
    override float winRate()    { return 1; }
  }

  class HalfArea : BinaryArea{
    this(int h){
      super(h);
      texts    = ["1 to 18"  , "19 TO 36"  ];
      captions = ["Half: low", "Half: high"];
    }

    override bool check(int n)  { return inRange(n, idx*18+1, (idx+1)*18); }
    override vec2 coinPos()      { return vec2(idx*10+1, 4.5); }
    override float coinWidth()  { return 2; }

    override void draw(Drawing dr){
      auto pos = vec2(idx*10, 4),
           rect = bounds2(pos, pos+vec2(2, 1));
      drawFramedText(dr, rect, texts[idx], 0.45);
    }
  }

  class ParityArea : BinaryArea{
    this(int i){
      super(i);
      texts    = ["EVEN"        , "ODD"        ];
      captions = ["Parity: even", "Parity: odd"];
    }

    override bool check(int n)  { return n>0 && (n&1)==idx; }
    override vec2 coinPos()      { return vec2(idx*6+3, 4.5); }
    override float coinWidth()  { return 2; }

    override void draw(Drawing dr){with(dr){
      auto pos = vec2(2+idx*6, 4);
      auto rect = bounds2(pos, pos+vec2(2, 1));

      drawFramedText(dr, rect, texts[idx], 0.45);
    }}

  }

  class ColorArea : BinaryArea{
    this(int i){
      super(i);
      texts    = ["RED"       , "BLACK"       ];
      captions = ["Color: red", "Color: black"];
    }

    override bool check(int n)  { return idx ? isBlack(n) : isRed(n); }
    override vec2 coinPos()      { return vec2(idx*2+5, 4.5); }
    override float coinWidth()  { return 2; }

    override void draw(Drawing dr){with(dr){
      auto pos = vec2(4+idx*2, 4),
           rect = bounds2(pos, pos+vec2(2, 1)),
           r2 = rect;

      r2 = r2.inflated(-0.3);
      color = idx ? clTableBlack : clTableRed;
      fillRombus(r2);
      drawFrame (dr, rect);
      drawRombus(r2);
    }}

  }


  class Table{ // Table class /////////////////////////////////
  private:
    Area[] areas;
    Drawing drawing;

    void drawCoinLines(Drawing dr){ //debug visualize the areas receiving coins on the table
      foreach(a; areas){with(dr){
        color = clAqua;
        lineWidth = 0.1;
        auto cp = a.coinPos,
             cw = vec2(a.coinWidth/2-0.5, 0);
        line(cp-cw, cp+cw+0.001f);
      }}
    }

  public:
    this(){
      //create the table areas
      foreach(i; -1..37) areas ~= new NumberArea(i);
      foreach(i;  0.. 3) areas ~= [new DozenArea(i), new ColumnArea(i)];
      foreach(i;  0.. 2) areas ~= [new HalfArea(i), new ParityArea(i), new ColorArea(i)];
      foreach(x; 0..2) foreach(y; 0..12) areas ~= new NumbersArea([y*3+x+1, y*3+x+2]);
      foreach(x; 0..3) foreach(y; 0..11) areas ~= new NumbersArea([y*3+x+1, y*3+x+4]);
      areas ~= [new NumbersArea([-1, 0]), new NumbersArea([0, 1]), new NumbersArea([-1, 3]), new NumbersArea([-1, 0, 2])]; //some additional 2s, 3s with zeroes
      foreach(y; 0..12) areas ~= new NumbersArea(iota(3).map!(x=>x+y*3+1).array);
      foreach(x; 0..2) foreach(y; 0..11) areas ~= new NumbersArea([y*3+x+1, y*3+x+4, y*3+x+2, y*3+x+5]);
      areas ~= new NumbersArea([-1, 0, 1, 2, 3]);
      foreach(y; 0..11) areas ~= new NumbersArea(iota(6).map!(x=>x+y*3+1).array);
      foreach(i; 0..4) areas ~= new DoubleDozenArea(i); //UK only
    }

    void glDraw(ref View2D view){
      if(drawing is null){
        drawing = new Drawing;
        with(drawing){
          clear;
          color = clBackground;
          fillRect(-1.5, -0.5, 13.5, 5.5);
          foreach(a; areas) a.draw(drawing);
          //drawCoinLines(drawing); //debug
        }
      }
      drawing.glDraw(view);
    }
  }

//COINS ////////////////////////////////////////////////////////////////////////////////////////////////////

  class Coin{
  private:
    static immutable coinValues = [1, 5, 10, 25, 50, 100];
    static Drawing[coinValues.length] drawings;
    static auto indexOf(int value){ return coinValues.countUntil(value); }
    RGB color(){ return [clSilver, clWowGreen, clWowBlue, clWowPurple, RGB(0x3030ff), clWowRed][indexOf(value)]; }
  public:
    static int findSuitableCoinValue(int total){ foreach_reverse(v; coinValues)if(v<=total) return v; return 0; }

    int value;
    vec2 pos, target;

    this(int v, vec2 p = vec2(0)){
      value = v;
      pos = p;
      target = pos;
      assert(indexOf(value)>=0);
    }

    void glDraw(View2D view){ //not ref because it will be transformed
      auto id = indexOf(value);
      if(drawings[id] is null){
        drawings[id] = new Drawing;
        with(drawings[id]){
          const pos = vec2(0);

          lineWidth = 0.08f;
          pointSize = 0.3*2;

          color = RGB(0x505050);
          circle(pos, 0.32);

          color = this.color;
          point(pos);

          color = clWhite;
          circle(pos, 0.3);

          lineWidth = 0.05f;
          foreach(i; 0..24){
            auto a = rotate(vec2(0.315f, 0), i*(1.0f/12)*PI);
            color = this.color;
            line(pos+a, pos+a*0.8f);
          }

          color = clBlack;
          auto text = value.to!string;
          fontHeight = text.length==1 ? 0.5f :
                       text.length==2 ? 0.4f : 0.3f;
          textOut(pos-vec2(0, fontHeight*0.38f), text, 0, HAlign.center);
        }
      }
      drawings[id].glDraw(view, pos);
    }

    bool update(){
      float at = calcAnimationT(deltaTime, 0.5f);
      return follow(pos, target, at, 0.01f);
    }
  }

  class Coins{
  private:
    Coin[] coins;
    immutable startPos = vec2(6, -3);

    void rearrange(){
      //calculates positions for each type of coins
      immutable vals = Coin.coinValues;

      int[] counts; counts.length = vals.length;

      foreach(c; coins){
        auto idx = vals.countUntil(c.value);
        assert(idx>=0);
        int cnt = counts[idx]++;

        const stackWidth = 5;
        c.target = vec2(idx*2+(cnt%stackWidth)*0.3, 6+(cnt/stackWidth)*0.6);
      }
    }

  public:
    void earn(int value, int count){
      if(count<=0) return;
      foreach(i; 0..count) coins ~= new Coin(value, startPos);
      rearrange;
    }

    void earn(int total){
      int[int] lst;
      while(total>0){
        int v = Coin.findSuitableCoinValue(total);
        lst[v]++;
        total -= v;
      }
      foreach(kv; lst.byKeyValue)
        earn(kv.key, kv.value);
    }

    void glDraw(ref View2D view){
      foreach(c; coins) c.glDraw(view);
    }

    bool update(){
      bool any;
      foreach(c; coins) any |= c.update;
      return any;
    }

  }


//WHEEL ////////////////////////////////////////////////////////////////////////////////////////////////////

  class Wheel{

    void draw(Drawing dr){with(dr){


    }}
  }

//GAME STATE ///////////////////////////////////////////////////////////////////////////////////////////////
  Table table;
  Coins coins;

  override void onCreate(){//CREATE ////////////////////////////////////////////////////////////////////////
    table = new Table;
    coins = new Coins;
//    wheel = new Wheel;
    view.workArea = bounds2(-2,-1, 14, 7);
    view.zoomAll;

    coins.earn(  1, 10);
    coins.earn(  5, 10);
    coins.earn( 10, 10);
    coins.earn( 25, 10);
    coins.earn( 50, 10);
    coins.earn(100, 10);
  }

  override void onUpdate(){//UPDATE ////////////////////////////////////////////////////////////////////////
    if(view.navigate(true, true)) invalidate;;

    //mouseCoin = coin.at(mousePos);
    //mouseNumber = table.at(mousePos);

    if(coins.update) invalidate;
  }

  override void onPaint(){with(gl){//PAINT //////////////////////////////////////////////////////////////////////////
    dr.clear; drGUI.clear;

    clearColor(0);  gl.clear(GL_COLOR_BUFFER_BIT);
    disable(GL_DEPTH_TEST);

    table.glDraw(view);
    coins.glDraw(view);

    //drawFPS(drGUI);
  }}
}