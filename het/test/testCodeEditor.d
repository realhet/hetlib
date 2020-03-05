//@exe
//@import c:\d\libs
//@ldc
//@compile -m64 -mcpu=athlon64-sse3 -mattr=+ssse3
//@release
///@debug

import het, het.ui, het.keywords, het.tokenizer, het.parser;

import io3 = std.stdio, u3 = het.utils : iow = indexOfWord, il = isLetter, isHexDigit;

//todo: commentek hozzacsapasa a tokenekhez. Ha a comment soraban van token, akkor ahhoz, ha nincs akkor meg a kovetkezo tokenhez, kiveve ha a legvegen van. De mi van, ha tobb comment van egymas mellett??

//todo: a sebesseghez a tokenizernek meg az utana kovetkezo lepeseknek is range-knak kell lenniuk.

enum testCase = q{
import std.stdio, het.utils;
import io = std.stdio, u = het.utils;
import io2 = std.stdio, u2 = het.utils : indexOfWord, isLetter;
import io3 = std.stdio, u3 = het.utils : iow = indexOfWord, il = isLetter;

public align(8){

extern(C++, NameSpace)   //LinkageAttribute   C C++ D Windows System Objective-C
align(4)          //AlignAttribute
deprecated(["Hello", "World"].join(" "))
export              //VisibilityAttribute

static if(1){
//private
//package(IdentifierList)
//protected
//public
//export          //VisibilityAttribute end
pragma(inline, true)
static
//abstract
final
//override
synchronized
//auto
//scope
//const
//immutable
//inout
//shared
__gshared
nothrow
pure
ref
//return
//@disable
@nogc
@ property
@safe
//@system
//@trusted

@  uda
@uda ()
@(5, uda()):
}
int a();

}
pragma(msg, typeof(a));

int test(int x)
{
    int r = -1;
    Lswitch: switch(x)
    {
        static foreach(i; 0 .. 100)
        {
            case i:
                r = i;
                break Lswitch;
        }
        default: break;
    }
    return r;
}

void main() {
    foreach (value; [ 1, 2, 3, 10, 20 ]) {
        writefln("--- value: %s ---", value);

        switch (value) {

        case 1:
            writeln("case 1");
            goto case;

        case 2:
            writeln("case 2");
            goto case 10;

        case 3:
            writeln("case 3");
            goto default;

        case 10:
            writeln("case 10");
            break;

        case 11: .. case 15:
            writeln("case 11..15");
            continue; // continue the outer loop

        case 20: case 21: case 25:
            writeln("case 20, 21, 25");
            break;

        default:
            writeln("default");
            break;
        }
    }
}
};



auto withoutComments(Token[] t){ return t.filter!(t => !t.isComment).array; }

Token[][] splitToSentences(Token[] tokens){
  if(tokens.empty) return [];

  auto level = tokens[0].level;
  auto separators = [-1];
  auto lastTokenIdx = tokens.length.to!int-1;
  foreach(int i, ref t; tokens){
    if(t.level==level && t.kind==TokenKind.Operator && t.id.among(opcolon, opsemiColon, opcurlyBracketClose)){

      //include the last comments in the same line
      int j = i;
      while(j<lastTokenIdx && tokens[j+1].isComment && t.line == tokens[j+1].line) j++;

      separators ~= j;
    }
  }

  if(separators[$-1] != lastTokenIdx)
    separators ~= lastTokenIdx;

  Token[][] res;
  foreach(int i; 0..separators.length.to!int-1)
    res ~= tokens[separators[i]+1 .. separators[i+1]+1];

  return res;
}


class BaseNode{ //BaseNode /////////////////////////////
  abstract void ui();

  protected void uiHeader(RGB color, string title){ with(im){
    theme = "tool";
    padding = "2 2 2 2";
    margin = "2";
    border = "1 normal";
    //border.extendBottomRight = true;
    bkColor = lerp(color, clWhite, .5);
    border.color = lerp(bkColor, clBlack, .25);
    style.bkColor = bkColor;
    if(title.length) Text(bold(title~" "));
  }}
}

class UnknownNode : BaseNode{ //UnknownNode //////////////////////////
  Token[] seq;

  this(Token[] seq){
    this.seq = seq;
  }

  override void ui(){ with(im){
    Column({
      border = "normal";
      foreach(ref t; seq)
        Row({ Text("%t".format(t), "\n"); });
    });
  }}
}

class ImportNode : BaseNode{ // import ////////////////////////////////
  Token[] seq;

  this(Token[] seq){
    this.seq = seq;
  }

  override void ui(){ with(im){
    Row({
      uiHeader(clRainbowYellow, "import");
      Row({
        string name;

        foreach(ref t; seq[1..$]){
          if(t.kind==TokenKind.Identifier || t.source.among(".", "=", ":")) name ~= t.source;
          if(t.source.among(",", ":")) { Edit(name, { bkColor = style.bkColor; }); name = ""; }
        }

        if(!name.empty){
          Edit(name, { bkColor = style.bkColor; }); name = "";
        }
      });
    });
  }}
}

class AttributeNode : BaseNode{
  Token[] seq;

  this(Token[] seq){
    this.seq = seq;
  }


}


Attributes parseAttribute(ref Token[] tokens){
  BaseNode[] res;

  if(tokens.empty) return [];



}


BaseNode[] parseDeclDefs(ref Token[] tokens){
  BaseNode[] res = [];

  if(tokens.empty) res;

  while(


  if(tokens[0].


}


BaseNode newNode(Token[] seq){
  enforce(seq.length);

  if(seq[0].isKeyword(kwimport)) return new ImportNode(seq);

  return new UnknownNode(seq);
}


class FrmMain: GLWindow { mixin autoCreate; // !FrmMain ////////////////////////////

  Parser parser;

  Token[][] tokenSentences;

  override void onCreate(){ // create /////////////////////////////////
    //VSynch = 1;
    //SetPriorityClass(GetCurrentProcess, REALTIME_PRIORITY_CLASS);

    //db.loadFromJSON(ini.read("settings", ""));

    parser = new Parser;

    auto f = File(`..\Dialogs.d`);
    parser.tokenize(f.fullName, testCase);

    parser.tokens = parser.tokens.withoutComments; //todo: deal with tokens later

    tokenSentences = parser.tokens.splitToSentences; //todo: input ranges
  }

  override void onDestroy(){ // destroy //////////////////////////////
    //ini.write("settings", db.saveToJSON);
  }


  override void onUpdate(){ // update ////////////////////////////////
    invalidate; //todo: opt

    view.navigate(!im.wantKeys, !im.wantMouse);

    caption = FPS.text;

    with(im) Panel({
      outerWidth = clientWidth;

      auto ta = parser.tokens;



/*      while(ta.length){
        alias act = ta[0];

        if(act.isComment){
        }


      }*/

      void header(RGB color, string title){ with(im){
        theme = "tool";
        padding = "2 2 2 2";
        margin = "2";
        border = "1 normal";
        //border.extendBottomRight = true;
        bkColor = lerp(color, clWhite, .5);
        border.color = lerp(bkColor, clBlack, .25);
        style.bkColor = bkColor;
        if(title.length) Text(bold(title~" "));
      }}


      void uiTokenSentences(Token[][] sentences){

        foreach(ts; sentences){
          auto node = newNode(ts);
          node.ui;


/*          if(ts[0].source=="import"){
            auto node = newNode(ts);
            node.ui;
          }else if(ts[$-1].source=="}"){ //block thing

            //search the start of the block
            auto level = ts[0].level; //the same as ts[$-1].level
            auto blockStart = ts.retro.countUntil!(t => t.source=="{" && t.level==level);
            assert(blockStart>=0);
            blockStart = ts.length-1-blockStart;

            Column({
              header(clSkyBlue, "");
              Row({
                foreach(t; ts[0..blockStart]){ Text(t.source, " "); }
              });


              if(ts[0].source=="switch"){
                Column({
                  header(clWhite, "");
                  auto sentences = ts[blockStart+1 .. $-1].splitToSentences;

                  //here gotta split the cases and the sentences

                  while(sentences.length){
                    string[] cases;
                    bool isRange;

                    while(sentences.length && sentences[0][$-1].source==":"){
                      auto cs = sentences[0][0..$-1]; //strip off :
                      sentences = sentences[1..$];

                      enforce(!cs.empty);

                      if(cs[0].source=="default"){
                        cases = ["default"];
                      }else{
                        if(cs[0].source==".."){
                          enforce(!isRange && cases.length==1);
                          cs = cs[1..$];
                          isRange = true;
                        }

                        enforce(cs.length && cs[0].source=="case");
                        cs = cs[1..$];

                        enforce(cs.length);

                        cases ~= cs.map!"a.source".join(" ");
                      }
                    }

                    auto s = cases.join(isRange ? " .. " : ", ");
                    Row({
                      Text(s, "  \t");
                      Bullet;

                      border = "normal";
                      border.extendBottomRight = true;
                      border.color = clSilver;
                      flags.yAlign = YAlign.top;


                      Token[][] temp;
                      while(sentences.length && sentences[0][$-1].source != ":"){
                        temp ~= sentences[0];
                        sentences = sentences[1..$];
                      }

                      Column({ //border = "normal";
                        uiTokenSentences(temp); //recursive
                      });
                    });
                  }
                });
              }else{
                Column({
                  header(clWhite, "");
                  auto sent = ts[blockStart+1 .. $-1].splitToSentences;
                  uiTokenSentences(sent); //recursive
                });
              }

            });
          }else if(ts[$-1].source.among(":", ";")){ //statement
            Row({
              //header(clWhite, "");
              Text(ts.map!(a => a.source).join(" "));
            });
          }else{
            Column({
              border = "normal";
              foreach(ref t; ts){
                Row({ Text("%t".format(t), "\n"); });
              }
            });
          }*/
        }

      }

      uiTokenSentences(tokenSentences);

    }); //panel


  }

  override void onPaint(){ // paint //////////////////////////////////////
    dr.clear(clSilver);
    drGUI.clear;

    im.draw(drGUI);

//    drawFpsTimeLine;
  }



}


