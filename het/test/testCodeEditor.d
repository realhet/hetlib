//@exe
//@import c:\d\libs
//@ldc
//@compile -m64 -mcpu=athlon64-sse3 -mattr=+ssse3
//@release
///@debug

import het, het.ui, het.keywords, het.tokenizer, het.parser;

class FrmMain: GLWindow { mixin autoCreate; // !FrmMain ////////////////////////////

  Parser parser;

  Token[][] tokenSentences;

  override void onCreate(){ // create /////////////////////////////////
    //VSynch = 1;
    //SetPriorityClass(GetCurrentProcess, REALTIME_PRIORITY_CLASS);

    //db.loadFromJSON(ini.read("settings", ""));

    parser = new Parser;

    auto f = File(`..\Dialogs.d`);
    parser.tokenize(f.fullName);

    //isolate tokenSentences
    auto separators = [-1];
    auto lastTokenIdx = parser.tokens.length.to!int-1;
    foreach(int i, ref t; parser.tokens){
      if(t.level==0 && t.kind==TokenKind.Operator && t.id.among(opcolon, opsemiColon, opcurlyBracketClose)){

        //attach comment in the same line
        int j = i;
        while(j<lastTokenIdx && parser.tokens[j+1].isComment && t.line == parser.tokens[j+1].line) j++;

        separators ~= j;
      }
    }

    if(separators[$-1] != lastTokenIdx)
      separators ~= lastTokenIdx;

    foreach(int i; 0..separators.length.to!int-1)
      tokenSentences ~= parser.tokens[separators[i]+1 .. separators[i+1]+1];
  }

  override void onDestroy(){ // destroy //////////////////////////////
    //ini.write("settings", db.saveToJSON);
  }


  override void onUpdate(){ // update ////////////////////////////////
    invalidate; //todo: opt

    //scroll the ui... fucking lame, must rethink
    bool processMouse = true;
    if(im.mouseOverUI){ //it's bad.
      processMouse = false;
    }

    updateView(processMouse, true);

    caption = FPS.text;

    with(im) Panel({
      outerWidth = clientWidth;

      auto ta = parser.tokens;



/*      while(ta.length){
        alias act = ta[0];

        if(act.isComment){
        }


      }*/


      foreach(ts; tokenSentences){
        if(ts[0].source=="import"){
          Row({
            //theme = "tool";

            padding = "2";
            margin = "2";
            border = "normal";
            bkColor = clOrange;
            style.bkColor = bkColor;
            Comment("static");
            Text(bold(" import "));

            string s0;
            //Row(s0, {
              string name;


              foreach(ref t; ts[1..$]){
                if(t.kind==TokenKind.Identifier || t.source.among(".", "=", ":")) name ~= t.source;
                if(t.source.among(",", ":")) { Edit(name, { bkColor = style.bkColor; }); Text(", "); name = ""; }
              }
            //});
          });

        }else{
          Column({
            border = "normal";
            foreach(ref t; ts){
              Row({ Text("%t".format(t), "\n"); });
            }
          });
        }
      }

    });

  }

  override void onPaint(){ // paint //////////////////////////////////////
    dr.clear(clSilver);
    drGUI.clear;

    im.draw(drGUI);

//    drawFpsTimeLine;
  }



}


