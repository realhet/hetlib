//@EXE

import het.utils;

void printCard(A...)(string title, string content){
  writeln;

  enum Single:string {
    h = "\u2500",
    tl = "\u250e",
  }

  auto lines = content.split('\n'),map!;

  write("\34\11\33\15"~Single.tl~" "~title~" ", Single.h, Single.tr);

}

void main(){ application.runConsole({
  printCard("Card", "abc");



}); }