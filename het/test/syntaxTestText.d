Éô
/*
🖐⏲

🙈🙉🙊

💑🏾
*/
struct Token{
  Variant data;
  int id; //emuns: operator, keyword
  int pos, length;
  int line, posInLine;
  int level; //hiehrarchy level in [] () {} q{}
  string source;

  TokenKind kind;
  bool isTokenString; //it is inside the outermost tokenstring. Calculated in Parser.tokenize.BracketHierarchy, not in tokenizer.
  bool isBuildMacro; // //@ comments right after a newline or at the beginning of the file. Calculated in parser.collectBuildMacros

  /*string toString() const{
    return "%-20s: %s %s".format(kind, level, source);//~" "~(!data ? "" : data.text);
  }*/

  void toString(scope void delegate(const(char)[]) sink, FormatSpec!char fmt){
    if(fmt.spec == 't')	put(sink, format!"%s\t%s\t%s"(kind, level, source));
    else	put(sink, format!"%-20s: %s %s"(kind, level, source));
  }

  bool isOperator(int op)	const { return id==op && kind==TokenKind.Operator;	}
  bool isKeyword (int kw)	const { return id==kw && kind==TokenKind.Keyword ;	}
  bool isIdentifier()	const { return kind==TokenKind.Identifier;	}
  bool isIdentifier(string s)	const { return isIdentifier && source==s;	}
  bool isComment()	const { return kind==TokenKind.Comment;	}

  void raiseError(string msg, string fileName=""){ throw new Exception(format(`%s(%d:%d): Error at "%s": %s`, fileName, line+1, posInLine+1, source, msg)); }

  //---------------------------------------------------
  override void measure(){
    const	autoWidth	= innerSize.x==0	,
    	autoHeight	= innerSize.y==0	,
    	doWrap	= flags.canWrap && !autoWidth	;

    //print("  rm begin", subCells.length, innerSize, "flex:", flex, "canWrap:", flags.canWrap, "autoWidth:", autoWidth, "doWrap,", doWrap);
    //scope(exit) print("  rm end", subCells.length, innerSize, "flex:", flex, flags.canWrap, doWrap);

    //adjust length of leading and internal tabs
    foreach(idx, tIdx; tabIdx){
      const isLeading = idx==tIdx; //it's not good for multiline!!!
      subCells[tIdx].innerSize.x *= (isLeading ? LeadingTabScale : InternalTabScale);
    }

    solveFlexAndMeasureAll(autoWidth);

    auto wrappedLines = makeWrappedLines(doWrap);

    //hide spaces on the sides by wetting width to 0. This needs for size calculation.
    //todo: don't do this for the line being edited!!!
    if(doWrap && !flags.dontHideSpaces) wrappedLines.hideSpaces(flags.hAlign);

    //horizontal alignment, sizing
    if(autoWidth ) innerSize.x = wrappedLines.calcWidth; //set actual size if automatic

    //horizontal text align on every line
    //todo: clip or stretch
    if(!autoWidth || wrappedLines.length>1) foreach(ref wl; wrappedLines){
      final switch(flags.hAlign){
        case HAlign.left	:	break;
        case HAlign.center	: wl.alignX(innerSize.x, 0.5);	break;
        case HAlign.right	: wl.alignX(innerSize.x, 1  );	break;
        case HAlign.justify	: wl.justifyX(innerSize.x);	break;
      }
    }

    //vertical alignment, sizing
    if(autoHeight){
      innerSize.y = wrappedLines.calcHeight;
      //height is calculated, no remaining space, so no align is needed
    }else{
      //height is fixed
      auto remaining = innerSize.y - wrappedLines.calcHeight;
      if(remaining > AlignEpsilon){
        final switch(flags.vAlign){
          case VAlign.top	:	break;
          case VAlign.center	: wrappedLines.alignY(innerSize.y, 0.5);	break;
          case VAlign.bottom	: wrappedLines.alignY(innerSize.y, 1.0);	break;
          case VAlign.justify	: wrappedLines.justifyY(innerSize.y);	break;
        }
      }else if(remaining < AlignEpsilon){
        //todo: clipping/scrolling
      }
    }

    //vertical cell align in each line
    if(flags.yAlign != YAlign.top) foreach(ref wl; wrappedLines){
      final switch(flags.yAlign){
        case YAlign.top	:	break;
        case YAlign.center	: wl.alignY(0.5);	break;
        case YAlign.bottom	: wl.alignY(1.0);	break;
        case YAlign.baseline	: wl.alignY(0.8);	break;
      }
    }

    //remember the contents of the edited row
    import het.ui: im;  if(im.textEditorState.row is this) im.textEditorState.wrappedLines = wrappedLines;
  }

  override void draw(Drawing dr){
    super.draw(dr);

    //draw the carets and selection of the editor
    import het.ui: im;  
    if(im.textEditorState.row is this){
      dr.translate(innerPos);
      im.textEditorState.drawOverlay(dr, bkColor.inverse);
      dr.pop; 
    }
  }

}a

blabla

import std.functional : binaryFun;
import std.range.primitives :	empty, front,
	popFront,
	isInputRange,
	isForwardRange,
	isRandomAccessRange,
	hasSlicing,
	hasLength;
import std.stdio : writeln;
import std.traits : isNarrowString;

/**
Returns the common prefix of two ranges
without the auto-decoding special case.

Params:
  pred = Predicate for commonality comparison
  r1 = A forward range of elements.
  r2 = An input range of elements.

Returns:
A slice of r1 which contains the characters
that both ranges start with.
 */
auto commonPrefix(alias pred = "a == b", R1, R2)(R1 r1, R2 r2)
if(	isForwardRange!R1 && isInputRange!R2 &&
	!isNarrowString!R1 &&
	is(typeof(binaryFun!pred(r1.front, r2.front))))
{
  import std.algorithm.comparison : min;
  static if(	isRandomAccessRange!R1 &&
  	isRandomAccessRange!R2 &&
  	hasLength!R1 && hasLength!R2 &&
  	hasSlicing!R1)
  {
    immutable limit = min(	r1.length,
    	r2.length);
    foreach (i; 0 .. limit)
    {
      if (!binaryFun!pred(r1[i], r2[i]))
      {
        return r1[0 .. i];
      }
    }
    return r1[0 .. limit];
  }
  else
  {
        import std.range : takeExactly;
        auto result = r1.save;
        size_t i = 0;
        for (;
             !r1.empty && !r2.empty &&
             binaryFun!pred(r1.front, r2.front);
             ++i, r1.popFront(), r2.popFront())
        {}
        return takeExactly(result, i);
    }
}

void main()
{
    // prints: "hello, "
    writeln(commonPrefix("hello, world"d,
                         "hello, there"d));
}