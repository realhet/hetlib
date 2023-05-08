module het.assembly;

import het.utils;

public import ldc.llvmasm;
public import core.simd : byte16, double2, float4, int4, long2, short8, ubyte16, uint4, ulong2, ushort8, void16,
loadUnaligned,  prefetch, storeUnaligned, SimdVector = Vector /+Because there is het.math.Vector already defined.+/; 

/+
	Note: Important note on SSE constants:
		/+Code: enum          ubyte16 a = [1, 2, 3];+/	⛔ It calculates BAD results!!!
		/+Code: static immutable ubyte16 a = [1, 2, 3];+/ 	⚠ It works, but the compiler crashes when used in pragma(msg).
	Possible workarounds:
		/+Code: mixin([1, 2, 3])+/ 	put the array literal inside mixin().
		/+Code: [1, 2, 3].dup+/	pass it through the std library. array(), dup() template functions will work.
+/

//Imported builtins ////////////////////////////////////////////

//example: 	__asm("movl $1, $0", "=*m,r", &i, j);


//public import ldc.gccbuiltins_x86 : pshufb	= __builtin_ia32_pshufb128; //note: this maps to signed bytes. I wand unsigneds for chars and for color channels.
//byte16 pshufb(byte16 a, byte16 b){return __asm!ubyte16("pshufb $2, $1", "=x,0,x", a, b); }
T pshufb(T, U)(T a, in U b) { return __asm!ubyte16("pshufb $2, $1", "=x,0,x", a, b); }

T palignr(ubyte im, T)(T a, in T b) { return __asm!ubyte16("palignr $3, $2, $1", "=x,0,x,i", a, b, im); }

//__builtin_ia32_pcmpestri128
T pcmpestri(ubyte im, T)(T a, in T b) { return __asm!ubyte16("pcmpestri $3, $2, $1", "=x,0,x,i", a, b, im); }