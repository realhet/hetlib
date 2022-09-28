module het.assembly;

import het.utils;

public import core.simd;

//Imported builtins ////////////////////////////////////////////
import ldc.llvmasm;

//public import ldc.gccbuiltins_x86 : pshufb	= __builtin_ia32_pshufb128; //note: this maps to signed bytes. I wand unsigneds for chars and for color channels.
//byte16 pshufb(byte16 a, byte16 b){return __asm!ubyte16("pshufb $2, $1", "=x,0,x", a, b); }
T pshufb(T, U)(T a, in U b) { return __asm!ubyte16("pshufb $2, $1", "=x,0,x", a, b); }
 
T palignr(ubyte im, T)(T a, in T b) { return __asm!ubyte16("palignr $3, $2, $1", "=x,0,x,i", a, b, im); }


