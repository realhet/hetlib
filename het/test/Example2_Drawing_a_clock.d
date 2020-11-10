//@exe
//@import c:\d\libs
//@ldc
//@compile -m64 -mcpu=athlon64-sse3 -mattr=+ssse3
///@release
//@debug

//todo: ez nem megy 64 biten

// This example will show how to do static and dynamic [Drawing]s in realtime.
// It will also demonstrate how to use a 2D [View] and realtime graphics.

import het; //publicly imports all the other necessary modules (win, geometry, utils, view, etc...)

class FrmClock: GLWindow{
  mixin autoCreate; //automatically creates an instance of this window at startup

//  Drawing drClockFace;
  double seconds = 0; //this value will smoothly follow the actual SecondOfDay value.
                      //It counts the seconds since around 1900.01.01

  const rClock = 100, rBig = 90, rSmall = 60; //some constants

  auto clockPoint(float a, float r){ //returns a point on the clock. a==1 -> 360deg
    return rotate(-vec2.basis(1), a*PI*2)*r;
  }

  override void onCreate(){
    seconds = itrunc(QPS); //initialize the secondOfDay
  }

  override void onUpdate(){
    //update the clock
    if(follow(seconds, itrunc(QPS), 0.1, 0.01)){
      //follow() is LERP-ing the value of 'seconds' towards rounded QPS.
      //         The lerp parameter is 0.1, and if the value reaches within 0.01
      //         range it will snap to it, and returning with false.
      //         The false return value means 'no change'.
      //QPS: returns the current second of the day using QueryPerformanceCounter()
      //     value converted to seconds and shifted by local time which is
      //     accessed on the first QPS call.
      invalidate; //redraw the scene
    }

    //update the 2D view
    view.navigate(true, true);  //View has a smooth pan/zoom featue, it must be updated
    //Also then the parameter is true, you can navigate in the view with the middle mouse, and with ASDW keys

    //Demonstrating how to add a keyboard action.
    with(actions){
      group("Common controls");
      onPressed("Close window", "Alt+X Ctrl+Q", true, { destroy; } );  // alt+X bugos! Az alt-nal mar bejelez, nem varja meg az X-et.
    }
  }

  override void onPaint(){ //the paint event
    gl.disable(GL_DEPTH_TEST);

    dr.clear(clBlack); drGUI.clear;

    //draw the static clock face
    with(dr){
      circle(0, 0, rClock*1.08);
      foreach(i; 0..60){
        auto p = clockPoint(i/60.0, rClock); //calculate the point
        if(i%5){ //Draw the small lines
          color = clWhite;  lineWidth = 1;  line(p*1.04f, p*0.96f);
        }else{ //Draw the points at every 5 seconds
          color = clWhite;  pointSize = 8;  point(p);
          color = clLime;   pointSize = 4;  point(p);
        }
      }

      //draw the dynamic things
                       // :  9   8   7   6   5   4   3   2   1   0
      immutable font = [0b0_111_111_111_111_111_101_111_111_001_111,
                        0b1_101_101_001_100_100_101_001_001_001_101,
                        0b0_111_111_001_111_111_111_111_111_001_101,
                        0b1_001_101_001_101_001_001_001_100_001_101,
                        0b0_111_111_001_111_111_001_111_111_001_111];
      //draw a column of the digital clock
      void drawDigitColumn(float x, int fontCol){ //Draws one column from the font[]
        foreach(y, mask; font){
          color = (mask>>fontCol)&1 ? clYellow : RGB(0x404040);
          auto p = vec2(x-8, y+4.5)*6; //digit positioning and spacing
          foreach(xx; 0..2) foreach(yy; 0..2) point(p+vec2(xx, yy)*3); //Each pixel is a 2x2 led matrix
        }
      }

      void drawDigit(float x, char ch){
        int ofs = (cast(int)ch-48)*3; //decode the input digit
        pointSize = 2.8;
        drawDigitColumn(x-1, 31); //empty column at the start
        foreach(a; 0..3) drawDigitColumn(x+a, ofs+2-a);
        drawDigitColumn(x+3, 31); //empty column at the end
      }

      auto secs = seconds.ifloor;

      foreach(idx, ch; format("%.2d%.2d", secs/60/60%24, secs/60%60))
        drawDigit([0, 4, 9, 13][idx], ch); //display the four digits at specific positions

      if(secs&1) drawDigitColumn(7.5, 30); //draw the flashing ":"

      //function to draw a specific clock hand
      void drawHand(int div, int mod){
        vec2 dir = clockPoint((cast(float)seconds/div%mod)/mod, 1);

        //decide the color and the width
        if(div==1){ color = clRed;   lineWidth = 4; }
              else{ color = clWhite; lineWidth = 8; }

        //decide the length
        float r = div==60*60 ? rSmall : rBig;

        //draw the clockHand
        moveTo(0, 0); lineTo(dir*r);
        pointSize = lineWidth*2;  point(0, 0);

        //draw the fluorescent thing
        if(div>1){
          color = clLime;
          lineWidth /= 2; moveTo(dir*lineWidth*2); lineTo(dir*r);
        }
      }

      //draw the 3 clockHands
      drawHand(   60, 60);
      drawHand(60*60, 12);
      drawHand(    1, 60);
    }

  }

}

