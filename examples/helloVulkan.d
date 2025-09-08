//@exe
//@debug
///@release

import het.vulkanwin;  mixin asmFunctions; 

static immutable EGAPalette = 
[
	(RGBA(0, 0, 0, 255)),	//Black
	(RGBA(0, 0, 170, 255)),	//Blue
	(RGBA(0, 170, 0, 255)),	//Green
	(RGBA(0, 170, 170, 255)),	//Cyan
	(RGBA(170, 0, 0, 255)),	//Red
	(RGBA(170, 0, 170, 255)),	//Magenta
	(RGBA(170, 85, 0, 255)),	//Brown
	(RGBA(170, 170, 170, 255)),	//Light Gray
	(RGBA(85, 85, 85, 255)),	//Dark Gray
	(RGBA(85, 85, 255, 255)),	//Bright Blue
	(RGBA(85, 255, 85, 255)),	//Bright Green
	(RGBA(85, 255, 255, 255)),	//Bright Cyan
	(RGBA(255, 85, 85, 255)),	//Bright Red
	(RGBA(255, 85, 255, 255)),	//Bright Magenta
	(RGBA(255, 255, 85, 255)),	//Yellow
	(RGBA(255, 255, 255, 255))	//White
]; static immutable C64Palette = 
[
	(RGBA(0, 0, 0, 255)),	//Black
	(RGBA(255, 255, 255, 255)),	//White
	(RGBA(136, 0, 0, 255)),	//Red
	(RGBA(170, 255, 238, 255)),	//Cyan
	(RGBA(204, 68, 204, 255)),	//Purple
	(RGBA(0, 204, 85, 255)),	//Green
	(RGBA(0, 0, 170, 255)),	//Blue
	(RGBA(238, 238, 119, 255)),	//Yellow
	(RGBA(221, 136, 85, 255)),	//Orange
	(RGBA(102, 68, 0, 255)),	//Brown
	(RGBA(255, 119, 119, 255)),	//Light Red
	(RGBA(51, 51, 51, 255)),	//Dark Gray
	(RGBA(119, 119, 119, 255)),	//Medium Gray
	(RGBA(170, 255, 102, 255)),	//Light Green
	(RGBA(0, 136, 255, 255)),	//Light Blue
	(RGBA(187, 187, 187, 255)) 	//Light Gray
]; static immutable VGAPalette = 
[
	(RGB(0x000000 )),(RGB(0xAA0000 )),(RGB(0x00AA00 )),(RGB(0xAAAA00 )),(RGB(0x0000AA )),(RGB(0xAA00AA )),(RGB(0x0055AA )),(RGB(0xAAAAAA )),(RGB(0x555555 )),(RGB(0xFF5555 )),(RGB(0x55FF55 )),(RGB(0xFFFF55 )),(RGB(0x5555FF )),(RGB(0xFF55FF )),(RGB(0x55FFFF )),(RGB(0xFFFFFF )),
	(RGB(0x000000 )),(RGB(0x101010 )),(RGB(0x202020 )),(RGB(0x353535 )),(RGB(0x454545 )),(RGB(0x555555 )),(RGB(0x656565 )),(RGB(0x757575 )),(RGB(0x8A8A8A )),(RGB(0x9A9A9A )),(RGB(0xAAAAAA )),(RGB(0xBABABA )),(RGB(0xCACACA )),(RGB(0xDFDFDF )),(RGB(0xEFEFEF )),(RGB(0xFFFFFF )),
	(RGB(0xFF0000 )),(RGB(0xFF0041 )),(RGB(0xFF0082 )),(RGB(0xFF00BE )),(RGB(0xFF00FF )),(RGB(0xBE00FF )),(RGB(0x8200FF )),(RGB(0x4100FF )),(RGB(0x0000FF )),(RGB(0x0041FF )),(RGB(0x0082FF )),(RGB(0x00BEFF )),(RGB(0x00FFFF )),(RGB(0x00FFBE )),(RGB(0x00FF82 )),(RGB(0x00FF41 )),(RGB(0x00FF00 )),(RGB(0x41FF00 )),(RGB(0x82FF00 )),(RGB(0xBEFF00 )),(RGB(0xFFFF00 )),(RGB(0xFFBE00 )),(RGB(0xFF8200 )),(RGB(0xFF4100 )),
	(RGB(0xFF8282 )),(RGB(0xFF829E )),(RGB(0xFF82BE )),(RGB(0xFF82DF )),(RGB(0xFF82FF )),(RGB(0xDF82FF )),(RGB(0xBE82FF )),(RGB(0x9E82FF )),(RGB(0x8282FF )),(RGB(0x829EFF )),(RGB(0x82BEFF )),(RGB(0x82DFFF )),(RGB(0x82FFFF )),(RGB(0x82FFDF )),(RGB(0x82FFBE )),(RGB(0x82FF9E )),(RGB(0x82FF82 )),(RGB(0x9EFF82 )),(RGB(0xBEFF82 )),(RGB(0xDFFF82 )),(RGB(0xFFFF82 )),(RGB(0xFFDF82 )),(RGB(0xFFBE82 )),(RGB(0xFF9E82 )),
	(RGB(0xFFBABA )),(RGB(0xFFBACA )),(RGB(0xFFBADF )),(RGB(0xFFBAEF )),(RGB(0xFFBAFF )),(RGB(0xEFBAFF )),(RGB(0xDFBAFF )),(RGB(0xCABAFF )),(RGB(0xBABAFF )),(RGB(0xBACAFF )),(RGB(0xBADFFF )),(RGB(0xBAEFFF )),(RGB(0xBAFFFF )),(RGB(0xBAFFEF )),(RGB(0xBAFFDF )),(RGB(0xBAFFCA )),(RGB(0xBAFFBA )),(RGB(0xCAFFBA )),(RGB(0xDFFFBA )),(RGB(0xEFFFBA )),(RGB(0xFFFFBA )),(RGB(0xFFEFBA )),(RGB(0xFFDFBA )),(RGB(0xFFCABA )),
	(RGB(0x710000 )),(RGB(0x71001C )),(RGB(0x710039 )),(RGB(0x710055 )),(RGB(0x710071 )),(RGB(0x550071 )),(RGB(0x390071 )),(RGB(0x1C0071 )),(RGB(0x000071 )),(RGB(0x001C71 )),(RGB(0x003971 )),(RGB(0x005571 )),(RGB(0x007171 )),(RGB(0x007155 )),(RGB(0x007139 )),(RGB(0x00711C )),(RGB(0x007100 )),(RGB(0x1C7100 )),(RGB(0x397100 )),(RGB(0x557100 )),(RGB(0x717100 )),(RGB(0x715500 )),(RGB(0x713900 )),(RGB(0x711C00 )),
	(RGB(0x713939 )),(RGB(0x713945 )),(RGB(0x713955 )),(RGB(0x713961 )),(RGB(0x713971 )),(RGB(0x613971 )),(RGB(0x553971 )),(RGB(0x453971 )),(RGB(0x393971 )),(RGB(0x394571 )),(RGB(0x395571 )),(RGB(0x396171 )),(RGB(0x397171 )),(RGB(0x397161 )),(RGB(0x397155 )),(RGB(0x397145 )),(RGB(0x397139 )),(RGB(0x457139 )),(RGB(0x557139 )),(RGB(0x617139 )),(RGB(0x717139 )),(RGB(0x716139 )),(RGB(0x715539 )),(RGB(0x714539 )),
	(RGB(0x715151 )),(RGB(0x715159 )),(RGB(0x715161 )),(RGB(0x715169 )),(RGB(0x715171 )),(RGB(0x695171 )),(RGB(0x615171 )),(RGB(0x595171 )),(RGB(0x515171 )),(RGB(0x515971 )),(RGB(0x516171 )),(RGB(0x516971 )),(RGB(0x517171 )),(RGB(0x517169 )),(RGB(0x517161 )),(RGB(0x517159 )),(RGB(0x517151 )),(RGB(0x597151 )),(RGB(0x617151 )),(RGB(0x697151 )),(RGB(0x717151 )),(RGB(0x716951 )),(RGB(0x716151 )),(RGB(0x715951 )),
	(RGB(0x410000 )),(RGB(0x410010 )),(RGB(0x410020 )),(RGB(0x410031 )),(RGB(0x410041 )),(RGB(0x310041 )),(RGB(0x200041 )),(RGB(0x100041 )),(RGB(0x000041 )),(RGB(0x001041 )),(RGB(0x002041 )),(RGB(0x003141 )),(RGB(0x004141 )),(RGB(0x004131 )),(RGB(0x004120 )),(RGB(0x004110 )),(RGB(0x004100 )),(RGB(0x104100 )),(RGB(0x204100 )),(RGB(0x314100 )),(RGB(0x414100 )),(RGB(0x413100 )),(RGB(0x412000 )),(RGB(0x411000 )),
	(RGB(0x412020 )),(RGB(0x412028 )),(RGB(0x412031 )),(RGB(0x412039 )),(RGB(0x412041 )),(RGB(0x392041 )),(RGB(0x312041 )),(RGB(0x282041 )),(RGB(0x202041 )),(RGB(0x202841 )),(RGB(0x203141 )),(RGB(0x203941 )),(RGB(0x204141 )),(RGB(0x204139 )),(RGB(0x204131 )),(RGB(0x204128 )),(RGB(0x204120 )),(RGB(0x284120 )),(RGB(0x314120 )),(RGB(0x394120 )),(RGB(0x414120 )),(RGB(0x413920 )),(RGB(0x413120 )),(RGB(0x412820 )),
	(RGB(0x412D2D )),(RGB(0x412D31 )),(RGB(0x412D35 )),(RGB(0x412D3D )),(RGB(0x412D41 )),(RGB(0x3D2D41 )),(RGB(0x352D41 )),(RGB(0x312D41 )),(RGB(0x2D2D41 )),(RGB(0x2D3141 )),(RGB(0x2D3541 )),(RGB(0x2D3D41 )),(RGB(0x2D4141 )),(RGB(0x2D413D )),(RGB(0x2D4135 )),(RGB(0x2D4131 )),(RGB(0x2D412D )),(RGB(0x31412D )),(RGB(0x35412D )),(RGB(0x3D412D )),(RGB(0x41412D )),(RGB(0x413D2D )),(RGB(0x41352D )),(RGB(0x41312D )),
	(RGB(0x000000 )),(RGB(0x000000 )),(RGB(0x000000 )),(RGB(0x000000 )),(RGB(0x000000 )),(RGB(0x000000 )),(RGB(0x000000 )),(RGB(0x000000 )),
]; RGB[] importVicePalette(File f)
=> f.readLines	.filter!q{a.length && !a.startsWith(`#`)}
	.map!((a)=>(a.replace(" ", "").to!uint(16).BGR)).takeExactly(16).array; enum svgFontDemo = `<svg xmlns:xlink="http://www.w3.org/1999/xlink" width="17.044ex" height="2.843ex" style="vertical-align: -0.838ex;" viewBox="0 -863.1 7338.5 1223.9" role="img" focusable="false" xmlns="http://www.w3.org/2000/svg" aria-labelledby="MathJax-SVG-1-Title">
<title id="MathJax-SVG-1-Title">{\displaystyle g(\nabla f,X)=\partial _{X}f,}</title>
<defs aria-hidden="true">
<path stroke-width="1" id="E1-MJMATHI-67" d="M311 43Q296 30 267 15T206 0Q143 0 105 45T66 160Q66 265 143 353T314 442Q361 442 401 394L404 398Q406 401 409 404T418 412T431 419T447 422Q461 422 470 413T480 394Q480 379 423 152T363 -80Q345 -134 286 -169T151 -205Q10 -205 10 -137Q10 -111 28 -91T74 -71Q89 -71 102 -80T116 -111Q116 -121 114 -130T107 -144T99 -154T92 -162L90 -164H91Q101 -167 151 -167Q189 -167 211 -155Q234 -144 254 -122T282 -75Q288 -56 298 -13Q311 35 311 43ZM384 328L380 339Q377 350 375 354T369 368T359 382T346 393T328 402T306 405Q262 405 221 352Q191 313 171 233T151 117Q151 38 213 38Q269 38 323 108L331 118L384 328Z"></path>
<path stroke-width="1" id="E1-MJMAIN-28" d="M94 250Q94 319 104 381T127 488T164 576T202 643T244 695T277 729T302 750H315H319Q333 750 333 741Q333 738 316 720T275 667T226 581T184 443T167 250T184 58T225 -81T274 -167T316 -220T333 -241Q333 -250 318 -250H315H302L274 -226Q180 -141 137 -14T94 250Z"></path>
<path stroke-width="1" id="E1-MJMAIN-2207" d="M46 676Q46 679 51 683H781Q786 679 786 676Q786 674 617 326T444 -26Q439 -33 416 -33T388 -26Q385 -22 216 326T46 676ZM697 596Q697 597 445 597T193 596Q195 591 319 336T445 80L697 596Z"></path>
<path stroke-width="1" id="E1-MJMATHI-66" d="M118 -162Q120 -162 124 -164T135 -167T147 -168Q160 -168 171 -155T187 -126Q197 -99 221 27T267 267T289 382V385H242Q195 385 192 387Q188 390 188 397L195 425Q197 430 203 430T250 431Q298 431 298 432Q298 434 307 482T319 540Q356 705 465 705Q502 703 526 683T550 630Q550 594 529 578T487 561Q443 561 443 603Q443 622 454 636T478 657L487 662Q471 668 457 668Q445 668 434 658T419 630Q412 601 403 552T387 469T380 433Q380 431 435 431Q480 431 487 430T498 424Q499 420 496 407T491 391Q489 386 482 386T428 385H372L349 263Q301 15 282 -47Q255 -132 212 -173Q175 -205 139 -205Q107 -205 81 -186T55 -132Q55 -95 76 -78T118 -61Q162 -61 162 -103Q162 -122 151 -136T127 -157L118 -162Z"></path>
<path stroke-width="1" id="E1-MJMAIN-2C" d="M78 35T78 60T94 103T137 121Q165 121 187 96T210 8Q210 -27 201 -60T180 -117T154 -158T130 -185T117 -194Q113 -194 104 -185T95 -172Q95 -168 106 -156T131 -126T157 -76T173 -3V9L172 8Q170 7 167 6T161 3T152 1T140 0Q113 0 96 17Z"></path>
<path stroke-width="1" id="E1-MJMATHI-58" d="M42 0H40Q26 0 26 11Q26 15 29 27Q33 41 36 43T55 46Q141 49 190 98Q200 108 306 224T411 342Q302 620 297 625Q288 636 234 637H206Q200 643 200 645T202 664Q206 677 212 683H226Q260 681 347 681Q380 681 408 681T453 682T473 682Q490 682 490 671Q490 670 488 658Q484 643 481 640T465 637Q434 634 411 620L488 426L541 485Q646 598 646 610Q646 628 622 635Q617 635 609 637Q594 637 594 648Q594 650 596 664Q600 677 606 683H618Q619 683 643 683T697 681T738 680Q828 680 837 683H845Q852 676 852 672Q850 647 840 637H824Q790 636 763 628T722 611T698 593L687 584Q687 585 592 480L505 384Q505 383 536 304T601 142T638 56Q648 47 699 46Q734 46 734 37Q734 35 732 23Q728 7 725 4T711 1Q708 1 678 1T589 2Q528 2 496 2T461 1Q444 1 444 10Q444 11 446 25Q448 35 450 39T455 44T464 46T480 47T506 54Q523 62 523 64Q522 64 476 181L429 299Q241 95 236 84Q232 76 232 72Q232 53 261 47Q262 47 267 47T273 46Q276 46 277 46T280 45T283 42T284 35Q284 26 282 19Q279 6 276 4T261 1Q258 1 243 1T201 2T142 2Q64 2 42 0Z"></path>
<path stroke-width="1" id="E1-MJMAIN-29" d="M60 749L64 750Q69 750 74 750H86L114 726Q208 641 251 514T294 250Q294 182 284 119T261 12T224 -76T186 -143T145 -194T113 -227T90 -246Q87 -249 86 -250H74Q66 -250 63 -250T58 -247T55 -238Q56 -237 66 -225Q221 -64 221 250T66 725Q56 737 55 738Q55 746 60 749Z"></path>
<path stroke-width="1" id="E1-MJMAIN-3D" d="M56 347Q56 360 70 367H707Q722 359 722 347Q722 336 708 328L390 327H72Q56 332 56 347ZM56 153Q56 168 72 173H708Q722 163 722 153Q722 140 707 133H70Q56 140 56 153Z"></path>
<path stroke-width="1" id="E1-MJMAIN-2202" d="M202 508Q179 508 169 520T158 547Q158 557 164 577T185 624T230 675T301 710L333 715H345Q378 715 384 714Q447 703 489 661T549 568T566 457Q566 362 519 240T402 53Q321 -22 223 -22Q123 -22 73 56Q42 102 42 148V159Q42 276 129 370T322 465Q383 465 414 434T455 367L458 378Q478 461 478 515Q478 603 437 639T344 676Q266 676 223 612Q264 606 264 572Q264 547 246 528T202 508ZM430 306Q430 372 401 400T333 428Q270 428 222 382Q197 354 183 323T150 221Q132 149 132 116Q132 21 232 21Q244 21 250 22Q327 35 374 112Q389 137 409 196T430 306Z"></path>
</defs>
<g stroke="currentColor" fill="currentColor" stroke-width="0" transform="matrix(1 0 0 -1 0 0)" aria-hidden="true">
 <use xlink:href="#E1-MJMATHI-67" x="0" y="0"></use>
 <use xlink:href="#E1-MJMAIN-28" x="480" y="0"></use>
 <use xlink:href="#E1-MJMAIN-2207" x="870" y="0"></use>
 <use xlink:href="#E1-MJMATHI-66" x="1703" y="0"></use>
 <use xlink:href="#E1-MJMAIN-2C" x="2254" y="0"></use>
 <use xlink:href="#E1-MJMATHI-58" x="2699" y="0"></use>
 <use xlink:href="#E1-MJMAIN-29" x="3551" y="0"></use>
 <use xlink:href="#E1-MJMAIN-3D" x="4218" y="0"></use>
<g transform="translate(5275,0)">
 <use xlink:href="#E1-MJMAIN-2202" x="0" y="0"></use>
 <use transform="scale(0.707)" xlink:href="#E1-MJMATHI-58" x="751" y="-213"></use>
</g>
 <use xlink:href="#E1-MJMATHI-66" x="6509" y="0"></use>
 <use xlink:href="#E1-MJMAIN-2C" x="7060" y="0"></use>
</g>
</svg>
`; 

version(/+$DIDE_REGION+/all) {
	/+
		/+
			Code: static vec2[] polyLineToTriangleStrip(in vec2[] pts, float radius)
			{
				const numPts = pts.length.to!int; 
				vec2[] vertices; 
				
				for(int i = 0; i < numPts; ++i)
				{
					int a = ((i - 1) < 0) ? 0 : (i - 1); 
					int b = i; 
					int c = ((i + 1) >= numPts) ? numPts - 1 : (i + 1); 
					int d = ((i + 2) >= numPts) ? numPts - 1 : (i + 2); 
					const p0 = pts[a]; 
					const p1 = pts[b]; 
					const p2 = pts[c]; 
					const p3 = pts[d]; 
					
					if(p1 == p2) continue; 
					
					// 1) define the line between the two points
					const line = (p2 - p1).normalize; 
					
					// 2) find the normal vector of this line
					const normal = vec2(-line.y, line.x).normalize; 
					
					// 3) find the tangent vector at both the end points:
					//					 -if there are no segments before or after this one, use the line itself
					//					 -otherwise, add the two normalized lines and average them by normalizing again
					const tangent1 = (p0 == p1) ? line : ((p1 - p0).normalize + line).normalize; 
					const tangent2 = (p2 == p3) ? line : ((p3 - p2).normalize + line).normalize; 
					
					// 4) find the miter line, which is the normal of the tangent
					const miter1 = vec2(-tangent1.y, tangent1.x); 
					const miter2 = vec2(-tangent2.y, tangent2.x); 
					
					// find	length of miter by projecting the miter onto the normal,
					// take	the length of the projection, invert it and multiply it by the thickness:
					//	length = thickness * ( 1 / |normal|.|miter| )
					float length1 = radius / dot(normal, miter1); 
					float length2 = radius / dot(normal, miter2); 
					
					if(i == 0) {
						vertices ~= p1 - length1 * miter1; 
						vertices ~= p1 + length1 * miter1; 
					}
					
					vertices ~= p2 - length2 * miter2; 
					vertices ~= p2 + length2 * miter2; 
				}
				return vertices; 
			} 
			
			const pathPoints = [
				vec2(58,80),vec2(108,379),vec2(191,228),vec2(159,144),vec2(265,124),
				vec2(221,388),vec2(337,476),vec2(313,127),vec2(427,63),vec2(365,175),
				vec2(448,246),vec2(478,130),vec2(483,303),vec2(380,302),vec2(415,470),
			]; 
			
			if(0)
			VB.tri(
				clRed, vec2(0,0), 	clBlue, vec2(0, 1), 
				clLime, vec2(1, 0), 	clYellow, vec2(1, 1), 
				clAqua, vec2(2, 1), 	clFuchsia, vec2(1, 0)
			); 
			
			
			{
				auto verts = polyLineToTriangleStrip(pathPoints, (互!((float/+w=6+/),(0.128),(0x36685F5C4644)))*300); 
				
				int i; 
				foreach(v; verts.take((0x36CC5F5C4644).檢((iround(verts.length*(互!((float/+w=6+/),(1.000),(0x36F75F5C4644))))).max(1))))
				VB.tri(i++ & 2 ? clWhite : clRed, v); 
			}
			
		+/
	+/
	
	version(/+$DIDE_REGION Color maps, palettes+/all)
	{
		
		/+
			enum cmap
			{
				//Perceptually Uniform Sequential
					viridis, plasma, inferno, magma, cividis,
				//Sequential
					Greys, Purples, Blues, Greens, Oranges, Reds,
					YlOrBr, YlOrRd, OrRd, PuRd, RdPu, BuPu,
					GnBu, PuBu, YlGnBu, PuBuGn, BuGn, YlGn,
				//Sequential (2)
					binary, gist_yarg, gist_gray, gray, bone, pink,
					spring, summer, autumn, winter, cool, Wistia,
					hot, afmhot, gist_heat, copper,
				//Diverging
					PiYG, PRGn, BrBG, PuOr, RdGy, RdBu,
					RdYlBu, RdYlGn, Spectral, coolwarm, bwr, seismic,
					berlin, managua, vanimo,
				//Cyclic
				   twilight, twilight_shifted, hsv,
				//Qualitative
					Pastel1, Pastel2, Paired, Accent,
					Dark2, Set1, Set2, Set3,
					tab10, tab20, tab20b, tab20c,
				//Miscellaneous
					flag, prism, ocean, gist_earth, terrain, gist_stern,
					gnuplot, gnuplot2, CMRmap, cubehelix, brg,
					gist_rainbow, rainbow, jet, turbo, nipy_spectral,
					gist_ncar
			} static immutable cmapNumGradients
				= [EnumMembers!cmap].map!
			((c){
				with(cmap)
				switch(c)
				{
					case 	Pastel2,
						Accent,
						Dark2,
						Set2: 	return  8; 
					case 	Pastel1,
						Set1: 	return  9; 
					case tab10: 	return 10; 
					case 	Paired,
						Set3: 	return 12; 
					case 	tab20, 
						tab20b, 
						tab20c: 	return 20; 
					default: 	return 0; 
				}
			})
			.array; 
		+/
		
		/+
			chars
				00 one 7 bit char
				01 1..32 7 bit chars chars
				10 1..32 7 bit repeated chars
				11 zero terminated unicode chars
			
			
		+/
		
	}
	class FrmHelloVuonUpdatelkan : VulkanWindow
	{
		mixin autoCreate;  
		
		version(/+$DIDE_REGION App management+/all)
		{
			class App
			{
				void onCreate() {} 
				void onDestroy() {} 
				void onUpdate() {} 
				void onDraw() {} 
			} 
			
			string[] appNames; //class names (not titles)
			App delegate()[] appConstructors; 
			App[] apps; //all running apps (null if not running)
			@STORED string actAppName; 
			App _app; //active app
			
			void initApps()
			{
				appNames = []; 
				static foreach(n; __traits(allMembers, typeof(this)))
				{
					{
						alias M = __traits(getMember, typeof(this), n); 
						static if(is(M : App) && !is(M==App))
						{
							appNames ~= M.classinfo.name.split('.').back; 
							appConstructors ~= ((){ return (cast(App)(new M())); }); 
						}
					}
				}
				apps = [App.init].replicate(appNames.length); 
			} 
			
			@property app()
			{
				if(_app && typeid(_app).name.endsWith(chain(only('.'), actAppName)))
				{
					return _app; //fast path
				}
				_app = null; const idx = appNames.countUntil(actAppName); 
				if(idx>=0)
				{
					//create new app if needed
					if(apps[idx] is null) {
						apps[idx] = appConstructors[idx](); 
						apps[idx].onCreate; 
					}
					_app = apps[idx]; 
				}
				return _app; 
			} 
		}
		
		version(/+$DIDE_REGION Common stuff+/all)
		{
			Texture egaPalette, c64Palette, vgaPalette; 
			
			void createCommoStuff()
			{
				egaPalette = new Texture(TexFormat.rgba_u8, 16, EGAPalette); 
				c64Palette = new Texture(
					TexFormat.rgba_u8, 16, /+C64Palette+/
					File(`c:\C64\VICE\C64\colodore.vpl`).importVicePalette.map!RGBA.array
				); 
				vgaPalette = new Texture(TexFormat.rgba_u8, 256, VGAPalette.map!RGBA.array); 
			} 
		}
		
		override void onCreate()
		{
			windowBounds = ibounds2(1280, 0, 1920, 600); 
			initApps; 
			createCommoStuff; 
			actAppName = ["SamplingDemo", "JupiterLander"][1]; 
		} 
		
		override void onDestroy() {} 
		
		override void onUpdate()
		{
			if(KeyCombo("Ctrl+F2").pressed) application.exit; 
			if(PERIODIC(1*second)) caption = FPS.text ~ " " ~ UPS.text; 
			
			if(app) app.onUpdate; 
		} 
		
		class SamplingDemo : App
		{
			Texture[] textures; 
			
			Texture hiresSprite, multiSprite; 
			
			override void onCreate()
			{
				hiresSprite = ((){
					const ubyte[] data = 
					[
						0,127,0, 1,255,192, 3,255,224, 3,231,224, 7,217,240, 7,223,240, 7,217,240, 3,231,224, 
						3,255,224, 3,255,224, 2,255,160, 1,127,64, 1,62,64, 0,156,128, 0,156,128, 0,73,0, 
						0,73,0, 0,62,0, 0,62,0, 0,62,0, 0,28,0 
					]; 
					return new Texture(TexFormat.wa_u1, ivec2(24, 21), data.swapBits); 
				})(); 
				multiSprite = ((){
					const ubyte[] data = 
					[
						0,170,0, 2,170,128, 10,170,160, 10,170,160, 42,170,168, 43,170,232, 47,235,250, 
						175,235,250, 173,235,122, 173,235,122, 171,170,234, 170,170,170, 170,170,170,
						170,170,170, 170,170,170, 170,170,170, 170,170,170, 162,138,138, 162,138,138,
						128,130,2, 128,130,2
					]; 
					return new Texture(TexFormat.wa_u2, ivec2(12, 21), data.swapBits); 
				})(); 
				
				new Texture(TexFormat.rgba_u8, 16, EGAPalette); 
			} 
			
			override void onUpdate()
			{
				foreach(y; 0..8)
				foreach(x; 0..8)
				{ dr.rect((bounds2(0, 0, 1-0.125, 1-0.125)+vec2(x, y))*64, hiresSprite.handle), RGBA(0xFFFF8000); }
				
				if(KeyCombo("F1").pressed) { textures.each!free; textures.clear; }
			} 
		} 
		class C64App : App
		{
			struct Screen
			{
				Image2D!RG img; 
				int[3] bkCols; 
				int borderCol; 
				
				void fillFgCol(int col, int x, int y, int w=1, int  h=1)
				{
					foreach(ref a; img[x..x+w, y..y+h])
					a.y = (cast(ubyte)(a.y.setBits(0, 4, col))); 
				} 
				
				void textOut(R)(int x, int y, R s, int fgCol=-1)
				{
					int xx = x; 
					int len; 
					foreach(ch; s) { img[xx, y].x = ch.bitCast!ubyte; xx++; len++; }
					if(fgCol>=0) fillFgCol(fgCol, x, y, len); 
				} 
			} 
			Screen[] screens; 
			
			void loadScreens(string bin)
			{
				auto img = bin.deserializeImage!ubyte; 
				const numScreens = img.height/25; 
				enforce(numScreens>0); 
				enforce(numScreens*25==img.height); 
				enforce(img.width==40*2); 
				
				auto allScreens = image2D(
					ivec2(40, 25*numScreens), 
					(cast(RG[])(img.asArray))
				); 
				screens = numScreens.iota
					.map!((i)=>(Screen(allScreens[0..$, i*25..(i+1)*25]))).array; 
			} 
			
			class BitmapArray
			{
				Texture tex; 
				ubyte[] raw; 
				uint length; 
				ivec2 size; 
				
				float aspect; 
				
				int getPixel_unsafe(int idx, int x, int y) const
				=> raw[(idx*size.y+y)*(size.x/8)+(x/8)].getBit(x%8); 
				
				this(ivec2 size, string bin)
				{
					enforce(size.x>0 && size.y>0); 
					this.size = size; aspect = (float(size.x))/size.y; 
					auto img = bin.deserializeImage!ubyte; 
					length = img.height/size.y; 
					enforce(img.width==size.x); 
					enforce(img.height==length*size.y); 
					raw = img.asArray.pack8bitTo1bit; 
					tex = new Texture(TexFormat.wa_u1, ivec3(size.xy, length), raw); 
				} 
			} 
			
			class Font : BitmapArray
			{
				this(string bin)
				{ super(ivec2(8, 8), bin); } 
			} 
			Font font; 
			
			int getPixel_8x8Std(in Image2D!RG screen, in ubyte[] fontMap, in ivec2 pScr)
			{
				if(pScr in ibounds2(ivec2(0), screen.size*8))
				{
					const chPos = pScr>>3; 
					const ch = screen[chPos.x, chPos.y].x; 
					if(ch < fontMap.length/8)
					{
						const remPos = pScr & 7; 
						return fontMap[ch*8 + remPos.y].getBit(remPos.x); 
					}
				}
				return 0; 
			} 
			
			auto vgaFont()
			{
				__gshared BitmapArray vgaFont; 
				if(!vgaFont)
				{
					const origFile = File(i`c:\dl\vga-rom-fonts-ag869x16.webp`.text); 
					auto img = origFile.read(true).deserializeImage!ubyte; 
					const charSize = img.size/16; 
					const generate9thPixel = !!origFile.name.isWild("*ag869x*"); 
					const realCharSize = charSize + ivec2(generate9thPixel, 0); 
					
					ubyte[] res; 
					foreach(cy; 0..16)
					foreach(cx; 0..16)
					foreach(y; 0..charSize.y)
					{
						res ~= img[cx*8..(cx+1)*8, cy*charSize.y+y].asArray; 
						if(generate9thPixel)
						res ~= ((cy==0xC || cy==0xD)?(res.back):(0)); 
					}
					
					img = image2D(realCharSize.x, realCharSize.y*256, res); 
					
					const modifiedFile = origFile.otherExt(".fontMap.webp"); 
					img.serializeImage("webp quality=999").saveTo(modifiedFile); 
					
					vgaFont = new BitmapArray
					(realCharSize, (cast(string)(modifiedFile.read(true)))); 
				}
				return vgaFont; 
			} 
			
			class Sprites : BitmapArray
			{
				RG[][] collisionPoints; 
				
				this(string bin)
				{
					super(ivec2(24, 21), bin); 
					
					version(/+$DIDE_REGION Calculate collisionPoints+/all)
					{
						foreach(i; 0..length)
						{
							RG[] res; bool p(int x, int y)
							{
								if(getPixel_unsafe(i, x, y))
								{
									res.addIfCan(RG(x, y));  
									return true; 
								}
								return false; 
							} 
							foreach(x; 0..size.x)
							{
								foreach(y; 0..size.y) if(p(x, y)) break; 
								foreach_reverse(y; 0..size.y) if(p(x, y)) break; 
							}
							foreach(y; 0..size.y)
							{
								foreach(x; 0..size.x) if(p(x, y)) break; 
								foreach_reverse(x; 0..size.x) if(p(x, y)) break; 
							}
							collisionPoints ~= res.sort.uniq.array; 
						}
					}
				} 
				
				bool detectCollision(
					in int idx, in ivec2 fromSpriteToScreen, 
					in bool doubleSize,
					in Image2D!RG screen, in ubyte[] fontMap
				)
				{
					foreach(cp; collisionPoints[idx])
					{
						const pScr = 	fromSpriteToScreen +
							(ivec2(cp)<<int(doubleSize)); 
						if(getPixel_8x8Std(screen, fontMap, pScr)) return true; 
					}
					return false; 
				} 
			} 
			Sprites sprites; 
			
			class Builder : GfxBuilder
			{
				void drawC64Rect(ibounds2 bnd, int fg)
				{
					begin(4, {}); 
					synch_PALH; 
					emit(
						assemble(mixin(舉!((Opcode),q{setPC})), mixin(舉!((ColorFormat),q{u4})), bits(fg, 4)),
						assemble(mixin(舉!((Opcode),q{drawMove})), mixin(舉!((CoordFormat),q{f32}))), vec2(bnd.topLeft),
						assemble(mixin(舉!((Opcode),q{drawTexRect})), mixin(舉!((CoordFormat),q{f32}))), vec2(bnd.bottomRight),
						assembleHandle(0)
					); 
				} 
				
				void drawC64Mark(ivec2 p, int fg = 7)
				{ drawC64Rect(ibounds2(p, ((1).genericArg!q{size})), fg); } 
				
				void emitC64Border(ivec2 pos, int fg)
				{
					void r(int x0, int y0, int x1, int y1)
					{
						auto p(int x, int y) => (ivec2(x, y)+pos)*8; 
						drawC64Rect(ibounds2(p(x0, y0), p(x1, y1)), fg); 
					} 
					r(0, 0, 4+40+4, 4); r(0, 4+25, 4+40+4, 4+25+4); 
					r(0, 4, 4, 4+25); r(4+40, 4, 4+40+4, 4+25); 
				} 
				
				void drawC64Sprite(vec2 pos, int idx, int fg, bool doubleSize)
				{
					begin(4, {}); 
					synch_PALH; 
					emit_setFMH(sprites.tex); 
					emit(
						assemble(mixin(舉!((Opcode),q{setPC})), mixin(舉!((ColorFormat),q{u4})), bits(fg, 4)),
						assemble(mixin(舉!((Opcode),q{setFH})), mixin(舉!((SizeFormat),q{u8})), ubyte(21*((doubleSize)?(2):(1)))),
						assemble(mixin(舉!((Opcode),q{drawMove})), mixin(舉!((CoordFormat),q{f32}))), vec2(pos),
						assemble(mixin(舉!((Opcode),q{drawFontASCII})), bits(0, 6), (cast(ubyte)(idx)))
					); 
				} 
				
				void emitC64Screen(ivec2 pos, Image2D!RG img, int[3] bkCols, int borderCol)
				{
					emitC64Border(pos-4, borderCol); 
					foreach(y; 0..img.height)
					{ drawChrRow((pos+ivec2(0, y))*8, img.row(y), bkCols[0]); }
				} 
				
				void drawChrRow(ivec2 pos, RG[] data, int bk)
				{
					if(data.empty) return; 
					
					int index = 0; 
					
					void setup()
					{
						emit_setPALH(c64Palette); 
						emit_setFMH(font.tex); 
						emit(
							assemble(mixin(舉!((Opcode),q{setFH})), mixin(舉!((SizeFormat),q{u4})), bits(8, 4)),
							assemble(mixin(舉!((Opcode),q{setSC})), mixin(舉!((ColorFormat),q{u4})), bits(bk, 4)),
							assemble(mixin(舉!((Opcode),q{drawMove})), mixin(舉!((CoordFormat),q{i16}))), bits(pos.x+index*8, 16), bits(pos.y, 16)
						); 
					} 
					
					//begin; setup;
					
					static RG[] fetchSameColor(ref RG[] data, size_t maxCount)
					{
						if(data.empty) return []; 
						const fg = data.front.y; 
						auto n = data.countUntil!((a)=>(a.y!=fg)); if(n<0) n = data.length; 
						n.minimize(maxCount); 
						auto res = data[0..n]; data = data[n..$]; return res; 
					} 
					
					enum MinRunLength = 2,
					MaxRunLength = 64; 
					
					static sizediff_t countDifferentChars(RG[] data)
					{
						if(data.length>=1+MinRunLength)
						{
							enum SkipAtStart = 1; 
							const i = 	data[SkipAtStart..$]
								.slide!(No.withPartial)(MinRunLength)
								.countUntil!((a)=>(a.all!((b)=>(b.x==a[0].x)))); 
							if(i>=0) return i+SkipAtStart; 
						}
						return data.length; 
					} 
					
					void emitSameChars(ref RG[] data)
					{
						if(data.empty) return; 
						const ubyte ch = data[0].x; 
						auto n = data.countUntil!((a)=>(a.x!=ch)); if(n<0) n = data.length; 
						if(n>=MinRunLength)
						{
							emit(assemble(bits(mixin(舉!((Opcode),q{drawFontASCII_rep}))), bits(n-1, 6), ch)); 
							data = data[n..$]; 
						}
					} 
					
					void emitDifferentChars(ref RG[] data)
					{
						if(data.empty) return; 
						
						auto n = countDifferentChars(data); 
						emit(assemble(bits(mixin(舉!((Opcode),q{drawFontASCII}))), bits(n-1, 6))); 
						emitEvenBytes(data.fetchFrontN(n)); 
					} 
					
					void emitRun(ref RG[] data)
					{
						while(!data.empty)
						{ emitSameChars(data); emitDifferentChars(data); }
					} 
					
					index = 0; 
					while(data.length)
					{
						size_t remainingChars = min(maxVertexCount/4, MaxRunLength/+should go next to the opcodes, not here!+/); 
						
						//todo_this_not_works_at_alll; 
						
						begin; setup;  //Todo: chain it to the end of previous
						
						auto act = fetchSameColor(data, remainingChars); 
						const nextIndex = index + act.length.to!int; 
						emit(assemble(bits(mixin(舉!((Opcode),q{setPC}))), mixin(舉!((ColorFormat),q{u4})), bits(act[0].y, 4))); 
						emitRun(act); 
						
						//Todo: make a whole line of text a triangle strip!
						
						index = nextIndex; 
					}
					end; 
				} 
				
				void drawPath(Args...)(in Args args)
				{
					void setup() {/+synch_PS, synch_SC...+/} 
					
					/+
						Bug: The splitter is WRONG, for a temporal fix, it gets a full begin() at each path
						The problem could be at start/end of line segments. The tangents are bad there!
					+/
					static if(0)	begin(6/+to be safe+/, {}); 
					else	begin/+full begin. for a fix+/; 
					
					setup; 
					const NOP = assemble(mixin(舉!((Opcode),q{drawPathM})), mixin(舉!((XYFormat),q{relX})), mixin(舉!((CoordFormat),q{i8})), byte(0)); 
					
					vec2 P_start, P_last, P_mirror; //internal state
					
					void emitPathCmd(A...)(in char cmd, in Opcode op, in A args)
					{
						//cmd is for estimationb only.  It should use the SvgPathCommand...
						
						const est = bezierTesselationSettings.estimateVertexCount(cmd); 
						if(est + 4/*to be sure*/ > remainingVertexCount)
						{
							emit(
								assemble(mixin(舉!((Opcode),q{drawPathTG})), mixin(舉!((XYFormat),q{absXY})), mixin(舉!((CoordFormat),q{f32}))), args[0], 
								NOP, NOP
							); 
							end; 
							begin; 
							setup; 
							emit(
								assemble(mixin(舉!((Opcode),q{drawPathTG})), mixin(舉!((XYFormat),q{absXY})), mixin(舉!((CoordFormat),q{f32}))), P_mirror,
								assemble(mixin(舉!((Opcode),q{drawPathTG})), mixin(舉!((XYFormat),q{absXY})), mixin(舉!((CoordFormat),q{f32}))), P_last
							); 
							incVertexCount(2); //add extra to be sure
						}
						
						emit(op); incVertexCount(est); 
						static foreach(a; args) { emit(assemble(mixin(舉!((XYFormat),q{absXY})), mixin(舉!((CoordFormat),q{f32}))), a); }
					} 
					
					void onItem(const ref SvgPathItem item)
					{
						const ref P0()
						=> item.data[0]; const ref P1()
						=> item.data[1]; const ref P2()
						=> item.data[2]; const Pm()
						=> P_last*2 - P_mirror; 
						final switch(item.cmd)
						{
								/+drawing+/	/+state update+/	
							case SvgPathCommand.M: 	emitPathCmd('M', mixin(舉!((Opcode),q{drawPathM})), P0); 	P_mirror = P_last = P_start = P0; 	break; 
							case SvgPathCommand.L: 	emitPathCmd('L', mixin(舉!((Opcode),q{drawPathL})), P0); 	P_mirror = P_last; P_last = P0; 	break; 
							case SvgPathCommand.Q: 	emitPathCmd('Q', mixin(舉!((Opcode),q{drawPathQ})), P0, P1); 	P_mirror = P0; P_last = P1; 	break; 
							case SvgPathCommand.T: 	emitPathCmd('T', mixin(舉!((Opcode),q{drawPathT})), P0); 	P_mirror = Pm; P_last = P0; 	break; 
							case SvgPathCommand.C: 	emitPathCmd('C', mixin(舉!((Opcode),q{drawPathC})), P0, P1, P2); 	P_mirror = P1; P_last = P2; 	break; 
							case SvgPathCommand.S: 	emitPathCmd('S', mixin(舉!((Opcode),q{drawPathS})), P0, P1); 	P_mirror = P0; P_last = P1; 	break; 
							/+redirected commands:+/			
							case SvgPathCommand.A: 	approximateArcToCubicBeziers(P_last, item, &onItem)
							/+Todo: move it to GPU+/
							/+
								Opt: Should do with a simplified version of cubic bezier!
								because <90deg and no S curve
							+/; 		break; 
							case SvgPathCommand.Z: 	if(P_last!=P_start)
							{
								emitPathCmd('L', mixin(舉!((Opcode),q{drawPathL})), P_start); 
								/+Todo: move it to GPU+/
								/+Todo: only works for line+/
							}	P_mirror = P_last = P_start; 	break; 
						}
					} 
					
					
					SvgPathParser parser = void; bool parserInitialized = false; 
					void parse(in string s)
					{
						if(parserInitialized.chkSet) parser = SvgPathParser(&onItem); 
						parser.parse(s); 
					} 
					
					static foreach(i, a; args)
					{
						{
							alias T = Unqual!(Args[i]); 
							static if(isSomeString!T) { parse(a); }
						}
					}
					
					emit(NOP, NOP, NOP); incVertexCount(2); /+to be sure+/
				} 
			} 
			class EGABuilder
			{
				Builder _builder; 
				
				this()
				{ _builder = new Builder; } 
				
				auto extractGfxContent()
				=> _builder.extractGfxContent; 
				
				void reset()
				{ _builder.reset; } 
				
				
				enum HAlign:ubyte { left, center, right } 
				enum VAlign:ubyte { top, center, baseline, bottom } 
				
				static struct EGAColor {
					ubyte data; 
					this(T)(T a)
					{ data = cast(ubyte)a; } 
				} 
				
				enum FontId: ubyte
				{
					default_, 
					
					CGA8x8, 
					VGA9x16, 
					
					Arial,
					Bahnschrift,
					Calibri,
					Cambria,
					Cambria_Math,
					Candara,
					Cascadia_Code,
					Cascadia_Mono,
					Comic_Sans_MS,
					Consolas,
					Constantia,
					Corbel,
					Courier_New,
					Franklin_Gothic,
					Gabriola,
					Georgia,
					HoloLens_MDL2_Assets,
					Impact,
					Ink_Free,
					Lucida_Console,
					Lucida_Sans_Unicode,
					Marlett,
					Microsoft_Sans_Serif,
					MingLiU_ExtB,
					Segoe_MDL2_Assets,
					Segoe_Print,
					Segoe_Script,
					Segoe_UI,
					Segoe_UI_Emoji,
					Segoe_UI_Historic,
					Segoe_UI_Symbol,
					Sitka,
					Sylfaen,
					Symbol,
					Tahoma,
					Times_New_Roman,
					Trebuchet_MS,
					Verdana,
					Webdings,
					Wingdings,
					
					reserved_
				} 
				static foreach(e; EnumMembers!FontId)
				static if(e>FontId.default_ && e<FontId.reserved_)
				mixin(iq{enum $(e.text) = FontId.$(e.text); }.text); 
				
				enum 
				{
					/+Note: 0+/	black	= EGAColor(0),
					/+Note: 1+/	blue	= EGAColor(1),
					/+Note: 2+/	green	= EGAColor(2),
					/+Note: 3+/	cyan	= EGAColor(3),
					/+Note: 4+/	red	= EGAColor(4),
					/+Note: 5+/	magenta	= EGAColor(5),
					/+Note: 6+/	brown	= EGAColor(6),
					/+Note: 7+/	ltGray	= EGAColor(7),
					/+Note:  8+/	dkGray	= EGAColor(8+0),
					/+Note:  9+/	ltBlue	= EGAColor(8+1),
					/+Note: 10+/ /+Note: 0xA+/	ltGreen	= EGAColor(8+2),
					/+Note: 11+/ /+Note: 0xB+/	ltCyan	= EGAColor(8+3),
					/+Note: 12+/ /+Note: 0xC+/	ltRed	= EGAColor(8+4),
					/+Note: 13+/ /+Note: 0xD+/	ltMagenta	= EGAColor(8+5),
					/+Note: 14+/ /+Note: 0xE+/	yellow	= EGAColor(8+6),
					/+Note: 15+/ /+Note: 0xF+/	white	= EGAColor(8+7),
				} 
				
				static struct fg
				{
					EGAColor value; alias this = value; 
					this(A)(in A a) { value = a; } 
				} 
				
				static struct bk
				{
					EGAColor value; alias this = value; 
					this(A)(in A a) { value = a; } 
				} 
				
				static EGAColor color(A)(in A a)
				=> fg(a); 
				
				static struct fgbk
				{
					EGAColor[2] value; 
					this(A, B)(in A a, in B b) { value[0] = a, value[1] = b; } 
					this(int a) { value[0] = a.getBits(0, 4), a.getBits(4, 4); } 
				} 
				
				static struct opacity {
					ubyte value = 255; 
					this(A)(in A a) {
						static if(isFloatingPoint!A)	value = a.to_unorm; 
						else	value = (cast(ubyte)(a)); 
					} 
				} 
				
				// A struct to hold the current graphic state
				static struct GraphicState
				{
					mixin((
						(表([
							[q{/+Note: Type+/},q{/+Note: Bits+/},q{/+Note: Name+/},q{/+Note: Def+/},q{/+Note: Comment+/}],
							[q{ubyte},q{8},q{"fgbkColors"},q{7},q{/++/}],
							[q{ubyte},q{8},q{"opacity"},q{255},q{/++/}],
							[q{FontId},q{6},q{"fontId"},q{VGA9x16},q{/++/}],
							[q{ubyte},q{8},q{"fontHeight"},q{16},q{/++/}],
							[q{HAlign},q{2},q{"hAlign"},q{},q{/++/}],
							[q{VAlign},q{2},q{"vAlign"},q{},q{/++/}],
						]))
					).調!(GEN_bitfields)); 
					
					@property fgColor() const
					=> (cast(EGAColor)(fgbkColors.getBits(0, 4))); 
					@property fgColor(int a) 
					{ fgbkColors = (cast(ubyte)(fgbkColors.setBits(0, 4, a))); } 
					@property fgColor(EGAColor a) 
					{ fgColor = a.data; } 
					@property bkColor() const
					=> (cast(EGAColor)(fgbkColors.getBits(4, 4))); 
					@property bkColor(int a) 
					{ fgbkColors = (cast(ubyte)(fgbkColors.setBits(4, 4, a))); } 
					@property bkColor(EGAColor a) 
					{ bkColor = a.data; } 
					
					alias font = fontId, fh = fontHeight; 
					
					void applyArg(T)(in T a)
					{
						static EGAColor asColor(T)(T arg)
						{
							static if(is(C : EGAColor)) return arg.value; 
							else static if(is(C : int)) return EGAColor(arg.value); 
							else static assert(false, "Unsupported color type: " ~ C.stringof); 
						} 
						
						static if(is(T : HAlign))	{ hAlign = a; }
						else static if(is(T : VAlign))	{ vAlign = a; }
						else static if(is(T : GenericArg!(name, C), string name, C))
						{
							static if(name == "fg")	{ fgColor = asColor(a.value); }
							else static if(name == "bk")	{ bkColor = asColor(a.value); }
							else static assert(false, "Unsupported generic arg: " ~ T.stringof); 
						}
						else static if(is(T : fg))	{ fgColor = a.value; }
						else static if(is(T : bk))	{ bkColor = a.value; }
						else static if(is(T : fgbk))	{
							fgColor = a.value[0]; 
							bkColor = a.value[1]; 
						}
						else static if(
							is(
								T : EGABuilder.opacity
								/+Todo: name conflict!+/
							)
						)	{ opacity = a.value; }
						else static assert(false, "Unsupported type: " ~ T.stringof); 
					} 
				} 
				
				GraphicState graphicState; 
				vec2 cursorPos; 
				
				struct M { vec2 value; this(A...)(in A a) { value = vec2(a); } } 
				struct m { vec2 value; this(A...)(in A a) { value = vec2(a); } } 
				
				struct Mx { float value=0; this(A)(in A a) { value = float(a); } } 
				struct mx { float value=0; this(A)(in A a) { value = float(a); } } 
				struct My { float value=0; this(A)(in A a) { value = float(a); } } 
				struct my { float value=0; this(A)(in A a) { value = float(a); } } 
				
				void Style(Args...)(in Args args)
				{
					//this alters graphicState
					static foreach(i, a; args)
					{
						{
							alias T = Args[i]; 
							static if(__traits(compiles, { graphicState.applyArg(a); })) graphicState.applyArg(a); 
							else static assert(false, "Unhandled Style() argument: "~T.stringof); 
						}
					}
				} 
				
				enum isStyleArg(T) = __traits(compiles, { GraphicState st; st.applyArg(T.init); }); 
				
				void Text(Args...)(Args args)
				{
					//this work on temporal graphics state
					/+Must not use const args!!!! because /+Code: chain(" ", str)+/ fails.+/
					
					GraphicState st = graphicState/+only modity temporal state+/; 
					static foreach(i, a; args)
					{
						{
							alias T = Args[i]; 
							static if(is(T : M))	cursorPos = a.value; 
							else static if(is(T : Mx))	cursorPos.x = a.value; 
							else static if(is(T : My))	cursorPos.y = a.value; 
							else static if(is(T : m))	cursorPos += a.value; 
							else static if(is(T : mx))	cursorPos.x += a.value; 
							else static if(is(T : my))	cursorPos.y += a.value; 
							else static if(isStyleArg!T)	st.applyArg(a); 
							else static if(isSomeString!T)	textBackend(st, a); 
							else static if(isSomeChar!T)	textBackend(st, only(a)); 
							else static if(
								isInputRange!T &&
								isSomeChar
								!(ElementType!T)
							)	{ textBackend(st, a); }
							else static if(isDelegate!T) a(); 
							else static if(isFunction!T) a(); 
							else
							{
								st.applyArg(opacity(.5)); 
								static assert(false, "Unhandled Text() argument: "~T.stringof); 
							}
						}
					}
				} 
				
				void textBackend_old(A)(in GraphicState st, A r)
				{
					const scaleX = 9, scaleY = 16; 
					alias font = vgaFont; 
					foreach(ch; r.dtext)
					{
						_builder.begin; 
						_builder.emit_setPALH(egaPalette); 
						_builder.emit_setFMH(font.tex); 
						_builder.emit(
							assemble(mixin(舉!((Opcode),q{setFH})), mixin(舉!((SizeFormat),q{u8})), (cast(ubyte)(st.fontHeight))),
							assemble(mixin(舉!((Opcode),q{setPCSC})), mixin(舉!((ColorFormat),q{u4})), st.fgbkColors),
							assemble(mixin(舉!((Opcode),q{setC})), mixin(舉!((ColorFormat),q{a_u8})), st.opacity), 
							assemble(
								mixin(舉!((Opcode),q{drawMove})), mixin(舉!((CoordFormat),q{i16})), 	bits((iround(cursorPos.x*scaleX)), 16), 
									bits((iround(cursorPos.y*scaleY)), 16)
							),
							assemble(mixin(舉!((Opcode),q{drawFontASCII})), bits(1-1, 6), (cast(ubyte)(((ch<=255)?(ch):(254)))))
						); 
						_builder.end; 
						cursorPos.x += /+st.fontHeight * font.aspect+/1; 
					}
				} 
				
				
				void textBackend(A)(in GraphicState st, A r)
				{
					//Todo: this should go to buffer
					static if(isInputRange!A) if(r.empty) return; 
					
					const scaleX = 9, scaleY = 16; 
					alias font = vgaFont; 
					
					void setup()
					{
						with(_builder)
						{
							synch_PALH; 
							synch_FMH; 
							emit(
								assemble(mixin(舉!((Opcode),q{setFH})), mixin(舉!((SizeFormat),q{u8})), (cast(ubyte)(st.fontHeight))),
								assemble(mixin(舉!((Opcode),q{setPCSC})), mixin(舉!((ColorFormat),q{u4})), st.fgbkColors),
								assemble(mixin(舉!((Opcode),q{setC})), mixin(舉!((ColorFormat),q{a_u8})), st.opacity),
								assemble(
									mixin(舉!((Opcode),q{drawMove})), mixin(舉!((CoordFormat),q{i16})), 	bits((iround(cursorPos.x*scaleX)), 16), 
										bits((iround(cursorPos.y*scaleY)), 16)
								)
							); 
						}
					} 
					_builder.begin(0, {}); 
					setup; 
					
					//convert UTF-8 to 8bit ASCII, reuse allocated memory.
					static Appender!(ubyte[]) app; 
					app.clear, app.put(r.byDchar.map!((ch)=>((cast(ubyte)(((ch<=255)?(ch):(254))))))); 
					
					uint decideCharCount(int len)
					{
						enum maxChars = 1<<6/+bits, base1 (0 means 1, 63 means 64)+/; 
						const uint 	space 	= max(_builder.remainingVertexCount-2, 0)/2,
							n	= len.min(min(space, maxChars)); 
						if(n) _builder.incVertexCount(n*2+2); return n; 
					} 
					encodeRLE
					(
						app[], 3,
						((ubyte[] part) {
							while(1)
							{
								if(const n = decideCharCount((cast(int)(part.length))))
								{
									_builder.emit(assemble(mixin(舉!((Opcode),q{drawFontASCII})), bits(n-1, 6)), part[0..n]); 
									cursorPos.x += n; part = part[n..$]; if(part.empty) break; 
								}
								/+start next geometry item+/_builder.begin; setup; 
							}
						}),
						((ubyte ch, uint len) {
							while(1)
							{
								if(const n = decideCharCount(len))
								{
									_builder.emit(assemble(mixin(舉!((Opcode),q{drawFontASCII_rep})), bits(n-1, 6)), ch); 
									cursorPos.x += n; len -= n; if(!len) break; 
								}
								/+start next geometry item+/_builder.begin; setup; 
							}
						})
					); 
					
					enum tooLargeBuf = 0x1000; /+Don't waste memory for exceptionally large texts+/
					if(app.length>tooLargeBuf) { app.shrinkTo(tooLargeBuf); }
				} 
				
			} 
			class TurboVisionBuilder : EGABuilder
			{
				enum clMenuBk 	= bk(ltGray), 
				clMenuText 	= fg(black), 
				clMenuKey	= fg(red),
				clMenuItem 	= fgbk(clMenuText, clMenuBk),
				clMenuSelected 	= fgbk(clMenuText, green),
				clMenuDisabled 	= fgbk(dkGray, clMenuBk); 
				
				enum clWindowBk	= bk(blue),
				clWindowText 	= fg(white),
				clWindow 	= fgbk(clWindowText, clWindowBk),
				clWindowClickable 	= fgbk(ltGreen, clWindowBk); 
				
				enum clScrollBar = fgbk(blue, cyan); 
				
				static struct MenuItem
				{
					string title, shortcut, hint; 
					bool selected, disabled, opened; 
					MenuItem[] subMenu; 
				} 
				
				void drawMenuTitle(Args...)(in MenuItem item, Args extra)
				{
					const clNormal = 	item.disabled 	? clMenuDisabled : 
						item.selected 	? clMenuSelected 
							: clMenuItem; 
					const s = item.title, aidx = s.byDchar.countUntil('&'); 
					if(aidx < 0) { Text(clNormal, chain(" ", s , " ")); }
					else {
						Text(
							clNormal, 	chain(" ", mixin(指(q{s},q{0..aidx}))), 
							clMenuKey, 	mixin(指(q{s},q{aidx+1})), 
							clNormal, 	chain(mixin(指(q{s},q{aidx+2..$})), " "),
							extra
						); 
					}
				} 
				
				void drawSubMenu(R)(R items)
					if(isForwardRange!(R, MenuItem))
				{
					sizediff_t measureItemWidth(in MenuItem item)
					=> item.title.filter!"a!='&'".walkLength + 2
					+ ((item.shortcut.empty)?(0):(item.shortcut.walkLength + 2)); 
					
					const maxWidth = items.save.map!measureItemWidth.maxElement; 
					vec2 pos = cursorPos; void NL() { pos += vec2(0, 1); Text(M(pos)); } 
					Style(clMenuItem); 
					
					void shadow(size_t n) { Text(bk(black), opacity(.6), " ".replicate(n)); } 
					
					Text(chain(" \u00DA", "\u00C4".replicate(maxWidth), "\u00BF ")); NL; 
					foreach(item; items)
					{
						Text(" \u00B3"); 
						const space = maxWidth - measureItemWidth(item); 
						if(item.shortcut!="")
						{ drawMenuTitle(item, chain(" ".replicate(space+1), item.shortcut, " ")); }
						else
						{ drawMenuTitle(item, " ".replicate(space)); }
						Text("\u00B3 "); shadow(2); NL; 
					}
					Text(chain(" \u00C0", "\u00C4".replicate(maxWidth), "\u00D9 ")); shadow(2); NL; 
					Text(mx(2)); shadow(maxWidth+4); 
					
					
					//Text(fg(yellow), bk(red), " Submenu goes here "~maxWidth.text); 
				} 
				
				void drawMainMenu(R)(R items)
					if(isForwardRange!(R, MenuItem))
				{
					foreach(item; items)
					{
						const pos = cursorPos; 
						drawMenuTitle(item); 
						if(item.opened && !item.subMenu.empty)
						{
							mixin(scope_remember(q{cursorPos})); 
							Text(M(pos), my(1)); //move the cursor
							drawSubMenu(item.subMenu); 
						}
					}
				} 
				
				void drawTextWindow(R)(string title, ibounds2 bnd, R lines)
				{
					void Btn(string s)
					{ Text(clWindow, "[", clWindowClickable, s, clWindow, "]"); } 
					
					Style(clWindow); 
					Text(
						M(bnd.topLeft), "\u00C9\u00CD", { Btn("\u00FE"); }, 
						chain(" ", title, " ").text.center(bnd.width-12, '\u00CD'), "1\u00CD",
						{ Btn("\u0012"); }, "\u00CD\u00BB"
					); 
					const w = bnd.width-2, h = bnd.height-2; 
					foreach(line; lines.padRight("", h).take(h))
					{
						Text(Mx(bnd.left), my(1), '\u00BA'); 
						string s = line.replace('\t', "    ").padRight(' ', w).takeExactly(w).text; 
						foreach(word; s.splitWhen!((a,b)=>(a.isAlphaNum!=b.isAlphaNum)))
						{
							enum keywords = ["program", "var", "begin", "end", "integer"]; 
							const isKeyword = keywords.canFind(word.text.lc); 
							Text(fg(((isKeyword)?(white):(yellow))), word); 
						}
						Text(
							clScrollBar, predSwitch(
								cursorPos.y-bnd.top-1, 
								0, '\u001E', 1, '\u00FE', h-1, '\u001F', '\u00B1'
							)
						); 
					}
					Text(
						M(bnd.bottomLeft), my(-1), "\u00C8\u00CD",
						chain(" ", "1:1", " ").text.center(17, '\u00CD'),
						clScrollBar, chain("\u0011", "\u00FE", "\u00B1".replicate(bnd.width-24), "\u0010"),
						clWindowClickable, "\u00C4\u00D9"
					); 
				} 
				
				void fillSpace(int width=80) { while(cursorPos.x<width) Text(' '); } 
				
			} 
		} 
		
		class JupiterLander : C64App
		{
			static immutable
			binCharMap = 
			x"5249464698020000574542505650384C8B0200002F07C0FF000F30FFF33FFFF31F78064AF3FFA9D1
A27F68487097504F0AF753701B3A381CDD6DAA1A7777E8C1768F5CD7F7E47B749B62B6E605ACDEDC
5DC22A324FBA8A24ACBD81DF2FA2FF46DBB6311B5AB633A4C495D53FF886A8BB66FDFA5BBFB55F74
68FFEC93EB1F7DE17EF9E60700975DB3FEE813AFD69BEED9D58423291756F1FDB9C37A77EED861E6
C27044748F2B582A0894F7694ABA16A02E375D4A7EEAA9C0352FABF6163227255E892A094A7A950C
2D494A6C89B892FF2DC05301875A3A28325041E1C2C4D2D116B85AE353DCCCE06A0DF25322256FA2
95C1F52ABDC5590E0DA8BC5E810A14E939CB64287B21FDB4802EC3CD4FD1A8A59F3640B2E632B46E
22A5CB0A28DA1CDDBBD36809A3104045B4411C0556B4A9CE80D11273CA241B43A898E41D33BAFB89
81960B260E018836C807D106ACC6912084849082116B572C5B3B4C4A2E8000B0F469606961FF7377
F7DF4334CDC00292ECA02613A9EC50E48E0A868ED94162A8589F9AB4A5FDBDF2AEB36647454C2117
52090180722A0626738898C96DBD38D9482F3F67C59CE45E0388D979F0EC5103D1270D705217EEF4
D94BA2310BB072CC26490C92BC571BA5ABF97F3714EF31055A0C308D11C4007BAD1E2106D3221A88
017504883571E41B2BD538EC8EB82A0042D017E5770FE92B298608800B04506B7C9ADE6C65CE5341
AFA18975B418DA2B509ECB5A37D34F1BB5CC29920EE9ADC121782BBDFFF10700F0FE99AEF9666E48
522DF83AEBE9E74EB9FB2FE7EE7692C48D5EC5CE5E8E170190374A3DD78A3DD7E6D8051E00B4321F
205A2AF0030A15801A000850E85A3DA093749DF0AC00C83F75EA5C25875382C4910DA1231301F267
49917FB40DBE00CFBF84699305F865FF2FFB7E14E06CD3B4DD11C0FF6D327C00",
			binSprites = 
			x"524946460A020000574542505650384CFD0100002F17C03E000F30FFF33FFFF31F7890B46DDB31B7
33BABE519C8C62DB49CDAFC7A0B66DAE6CCF7C731C59D5EDCAB66DDB5EDA8D6DBDAB3AA2FF7BE04E
37BDA3CD0ED17C9CFBD4E21A3F7D7777FD733F7D5F777DA6BEDA19A4513235C47F953A7C55C7570B
CB09D967C3EDE09534F5A649040B2DD48739E503AEA1FDC85F5BF5DA5D579C7D2E30BB893E5B09CC
BE90A95B9A58BBAC5FEDE51121F7EC21F5233458BBDD9E32494E1870BBC77A7A469365A1FEB33267
90E3C001F17AAAFB91F29A35E6EED96675A67969526061BF4555C3B51F8E6A1BF77C5B7AE59B7A6F
ADB87E46DEB8E9F6F0A3F2D969B7CFBC67891555B8F3CA21D7D041E41B1B5F2C17658F4460EEF9E7
6533C616DFDD7EC97EB5D66429BD3BA674E8D8DC86BE7745D7E562E2E4C63D03A41EEBE59ED1B7B3
AED3A016B6BB627F99F0ABB91E596FB3383CE646288B2D148FA5DA8F8F16B223A5E2B1945FA7DAB1
6E5163BCB3BEC85223B65788E3CFC41C049A77AE3BC2ADE4489F9986903029BD17337DE917C8C700
14351FBD880A60871FD6745EF8326E9434626EF7962FCCDB3EBFF152844A7BB51F40A4E738977712
D151CA42887287380EE85074ECD0A0D7808A7E66A2609C06F434692285019C56F311802628B8031A
002B28FC142B200158550051FC4C83BB9E38D4FC07328A901020F3BF283F24043840E6B7BC410DDE
FC474DE00634E15F0100",
			binScreens = 
			x"52494646D8040000574542505650384CCB0400002F4F40250005B5DBD6D6C6CD73DFB15E87949419
ED8EC3CC1C831CBBF18C6649726731A5CCCCED8F975F789E5772E05B44FF1D39922435792815B619
6A1686C64F20FD7CA2D0A4E1CE60E99E99C1CE22CCB0E7879BC195C29787934586A5FB0260666064
DC130A0594C7D6B98F1D7D7A6CF78F91131A7E4CF5F7BFA60A27BB9EF5B4C75967615A6465C00C73
2E7C63C9CFE9873B1F33E383DF220F66FF1FFB84DF22672C0479E1EEBF24E7135C7FD77FB2F945FF
5A097F68D2BF1D25FDA9FE4C7FAEBFD05FEAAFF4D7FA1BFDADFE4E7FAF7FD03FEA9FF4CF41F95BFF
C5C8F28FFE57FFA7FFD7F4ACA40743A800D449657C8C29563046810459C9045D2C63304B21607E64
A354C218CBC84BC930451F05C6488D24842D6CCD8DE0A9C3902ED20E0D694C1925C4A54A7D9A3041
82210AECA06B30C00E328CF110231473256FE9297224250546484A1E21C11A7A48D1458641498ACC
D84752AC2137EECF3E1E950CAD447DE37E2DB063488614134C8CBBFAA175950C5323F1B673FF21A3
47CBD67989718121C891344162B0529263ECDA178CF49F2041668E41C9C44A32418ABE9171AD64C9
ECAD65972C568D5C2343C879A5B5596E23F92A085D64255D73349CE908B9D5D304DB0646222B4F6A
A4DD3472F7AD1C03E70CA4F6B9AC71DA04198C915B633631C675C598C3C498A91ED69CC99731C512
7AD64EDEB358C536A824C5D4C01C4132CE1B623A4B37738E59EF1A633635C629418EDC4837B15788
63DCB66BBAEEA9A48F142B58F3DC771771133770C9FC95BD724A4D313067B7DAE78263E58FD075B4
D333AED245615C60CD621EF4859295781AE7F128A678231EC617E3AD98E2224E632AD3147137CECA
F3F87CA868A12EBAA866B46A44C7A0ADEAE3610055978F3A0EEAF1D1470A062881FA40D5C039318D
3467D3A91F28469B1E6C23EFB5520BCC8CA7BDB80CDBB1F40325C16D984E6CCE7AF199500ECABDBE
CF3B91A45B5410D2622249775A4C9B8924DD5931A714AF215E3A5BCF0839A938A7BDA9B9E91C2328
E084E236C4F98CCB11157B9C73070A00EFE4A3EA98339D279B185E8F25E94E0B8167C741103A321C
3B4E4341A6ECBE92A692AA54A94869051675D239AA238C8A7704C20686B8882D47D599A3306ADA02
0216EAA4F5E3000EA25E105154370ED50DA06ED0B320412A2F6F15168A80F588C8DC06A2104EA985
60E60EDE6C06FB45284388582E98E1C270410D0FAF0B6E38785C25C68FC355A61F2A1F127744C541
6839B90F44DEFAD7572985B774B8A4234B1BC8FA9E83E72BA7ED23CAA37E944659944414DD8A08B6
5EB01334468D7163A79137FA8DB491359206356EC193CFADCD6173DA4C9A9326356F354943ACAF69
122A77F4FC6FCFA1DE5D64B4987484CCEA08A8B0F6BC10228A24B42AE19088368B735280E09C158B
8C53CC1F9FA99093254C23248467355F09272B43D2C29380DB90137AEFB80334ABA0A350C981C8D7
8C4E4540502722C07D1958C5BCE125C05B785D24589D711F81085867101D2EA9546BFFBFC09CD411
81F5F5007544D8E7F6F98A3F6E7160D51121698710A2A86E1C0ACA292F8BC1EA88704FC64EC5FBC6
29CE674CC2BD499C0C46A8378913A5AB02885C38AA738B0A4C42B890CFC3DB90D366BB45411D2146
E2D90755719ECD7BB50372F82DD68C4E85805BEB08A993DE47385449A4B49FA7461D7119D770A1B6
75C4AB9AC2AA0600"; 
			
			void loadAssets()
			{
				loadScreens(binScreens); 
				with(screens[0]) { bkCols = [15, 2, 6]; borderCol = 15; }
				with(screens[1]) { bkCols = [6, 0, 0]; borderCol = 8; }
				foreach(ref sc; screens[2..$])
				with(sc) { bkCols = [0, 4, 8]; borderCol = 0; }
				
				font = new Font(binCharMap); 
				sprites = new Sprites(binSprites); 
			} 
			
			Screen screen; 
			
			bool shipVisible, shipSimulated, thrustLeft, thrustRight, thrustBottom, thrustFlicker; 
			vec2 shipPos, shipSpeed; 
			int shipColor, shipSpriteIdx; bool shipDoubleSize; 
			float shipExplosionTick=0, delayedExplosion=0; ; 
			
			int zoomedPlatform = -1, landedOnPlatform = -1; 
			ivec2 shipTranslation; 
			
			static immutable 	explosionColors = [5, 7, 8, 12, 13, 15, 1, 3],
				explosionMaxSpriteIdx = 7,
				explosionMaxTick = 100,
				platformBounds = [
				ibounds2(ivec2( 8, 19), ((ivec2(6, 1)).genericArg!q{size})),
				ibounds2(ivec2(19,  6), ((ivec2(6, 1)).genericArg!q{size})),
				ibounds2(ivec2(27, 20), ((ivec2(5, 1)).genericArg!q{size}))
			],
				platformZoomedPos = [ivec2(12, 16), ivec2(12, 10), ivec2(16, 18)],
				platformMultipliers = [5, 2, 10],
				speedScale = 3.0f; ; 
			
			
			static str(R)(R s)
			=> s.byChar.map!((a)=>(a.predSwitch(' ', '@', '-', '\x5F', a))).text; 
			
			enum Scene {title, instructions, demo, game} 
			Scene _scene; 
			Time sceneTime = 0*second; 
			@property scene() const
			=> _scene; @property void scene(Scene a)
			{ _scene = a; onSceneStarts(); } 
			
			void onSceneStarts()
			{
				sceneTime = 0*second; 
				
				void loadScreen(int idx)
				{ screen = screens[idx]; screen.img = screen.img.dup; } 
				
				void initShip()
				{
					shipVisible = true; shipSimulated = true; 
					shipPos = vec2(14, 2); shipDoubleSize = false; 
					shipSpeed = vec2(10, -1) + vec2(randomGaussPair[])*3; 
					shipColor = 3; shipSpriteIdx = 0; 
					shipExplosionTick = 0; delayedExplosion = 0; delayedRestart = 0; 
					thrustLeft = thrustRight = thrustBottom = false; 
					zoomedPlatform = -1; landedOnPlatform = -1; 
					shipTranslation = ivec2(0); 
				} 
				
				
				final switch(scene)
				{
					case Scene.title: 	{ loadScreen(0); shipVisible = false; }	break; 
					case Scene.instructions: 	{
						loadScreen(1); initShip; 
						shipSimulated = false; 
						shipPos = vec2(119, 39); 
						shipDoubleSize = true; 
					}	break; 
					case Scene.demo: 	{ loadScreen(2); initShip; }	break; 
					case Scene.game: 	{
						loadScreen(2); initShip; 
						fuel = initialFuel; score = 0; 
					}	break; 
				}
			} 
			
			int score, highScore, pendingScore; 
			enum initialFuel = 32 * 8, fuelPenalty = 32; 
			float fuel = 0; 
			float scoreTimer=0; 
			float delayedRestart = 0; 
			float gameOverTimer = 0; 
			
			void uiLabelInt(ivec2 p, int col, string label, int value)
			{
				with(screen)
				{
					textOut(p.x, p.y, label, col); 
					textOut(
						p.x + label.length.to!int, p.y, 
						str(value.format!"%6d"), 1
					); 
				}
			} 
			
			void uiFuelGauge(
				ivec2 p, int barWidth, int col, int barCol, 
				string label, int value
			)
			{
				with(screen)
				{
					textOut(p.x, p.y, label, 7); 
					if(value>0)
					{
						auto barChars = 	only(16+value%8).padLeft(1, value/8+1)
							.padRight(0, barWidth).take(barWidth); 
						textOut(p.x + label.length.to!int, p.y, barChars, 6); 
					}
					else
					{
						textOut(
							p.x + label.length.to!int, p.y, 
							str("      OUT OF FUEL".padRight(' ', barWidth)), 2
						); 
					}
				}
			} 
			
			void uiAccelGauge(ivec2 p, int barHeight, int col1, int col2, int value)
			{
				with(screen)
				{
					const cy = p.y + barHeight/2; 
					version(/+$DIDE_REGION Bar+/all)
					{
						img[p.x, p.y-1] = RG(10, col1); 
						foreach(y; p.y..p.y+barHeight)
						img[p.x, y] = RG(1, col1); 
						img[p.x, cy].y = (cast(ubyte)(col2)); 
						img[p.x, p.y+barHeight] = RG(11, col1); 
					}
					version(/+$DIDE_REGION Needle+/all)
					{
						value += barHeight/2*8; 
						if(mixin(界1(q{0},q{value},q{barHeight*8})))
						img[p.x, p.y + value/8].x = 24 + value%8; 
					}
					version(/+$DIDE_REGION Labels+/all)
					{
						textOut(p.x-1, p.y-3, [8, 9], 1); 
						img[p.x-1, p.y] = RG(0x3E, 1); 
						img[p.x-1, cy-1] = RG(0x3B, 1); 
						img[p.x-1, cy+0] = RG(0x3C, 1); 
						img[p.x-1, p.y+barHeight-1] = RG(0x3F, 1); 
					}
				}
			} 
			
			void drawUI()
			{
				with(screen)
				{
					uiLabelInt(ivec2(1, 23), 5, str("SCORE :"), score); 
					uiLabelInt(ivec2(18, 23), 4, str("HI-SCORE :"), highScore); 
					uiFuelGauge(ivec2(1, 24), 32, 7, 6, str("FUEL : "), (ifloor(fuel))); 
					uiAccelGauge(ivec2(39, 4), 16, 5, 7, (ifloor(shipSpeed.y * speedScale))); 
				}
			} 
			
			void drawMsg(R)(R msg, int y=1)
			{
				with(screen)
				{
					const w = msg.length.to!int+4, x = (40-w)/2; 
					
					textOut(x, y+0, str('@'.repeat.take(w)), 1); 
					textOut(x, y+1, chain("@@", msg, "@@"), 1); 
					textOut(x, y+2, '@'.repeat.take(w), 1); 
				}
			} 
			
			
			override void onCreate()
			{ loadAssets; scene = Scene.title; } 
			
			override void onUpdate()
			{
				auto _間=init間; 
				const appDeltaTime = application.deltaTime * 1; 
				enum tickFreq = 50 /+Hz+/; 
				const float 	Δt	= appDeltaTime.value(second),
					t 	= sceneTime.value(second),
				Δtick 	= Δt * tickFreq,
				tick 	= t * tickFreq; 
				sceneTime += appDeltaTime/+advance time+/; 
				
				thrustFlicker = (ifloor(tick/3.5f)) & 1; /+update the flickering of the bottom thruster+/
				
				version(/+$DIDE_REGION+/all) {
					void animateInstructions()
					{
						const phase = (ifloor(tick/32))%6; 
						
						thrustLeft = phase==1; 
						thrustRight = phase==3; 
						thrustBottom = phase==5; 
						
						screen.fillFgCol(thrustLeft   ?0:1, 11, 11, 6); 
						screen.fillFgCol(thrustRight  ?0:1, 19, 11, 7); 
						screen.fillFgCol(thrustBottom?0:1, 23,  7, 7); 
					} 
					
					void flashingBottomText()
					{ screen.fillFgCol((ifloor(tick/16)), 10, 24, 18); } 
					
					void processInput(bool en)
					{
						thrustBottom 	= en && KeyCombo(`F1`).down,
						thrustLeft 	= en && KeyCombo(`A`).down,
						thrustRight 	= en && KeyCombo(`D`).down; 
					} 
				}
				
				vec2 applyTransformation(vec2 p)
				{
					if(zoomedPlatform<0) return p; 
					p -= platformBounds[zoomedPlatform].topLeft*8; 
					p *= 2; 
					p += platformZoomedPos[zoomedPlatform]*8; 
					return p; 
				} 
				
				int decideZoomedPlatform()
				{
					with(shipPos)
					{
						if(y>88) return x>160 ? 2 : 0; 
						if(mixin(界0(q{110},q{x},q{220})) && y>12) return 1; 
						return -1; 
					}
				} 
				
				void updateShip()
				{
					if(shipVisible && shipSimulated)
					{
						version(/+$DIDE_REGION Ship control+/all)
						{
							if(thrustLeft) shipSpeed.x += 7.0f * Δt; 
							if(thrustRight) shipSpeed.x -= 7.0f * Δt; 
							if(thrustBottom) shipSpeed.y -= 11.0f * Δt; 
							
							static if((常!(bool)(0))/+debug+/)
							{
								shipSpeed = 0; 
								if(inputs["Up"].repeated) shipPos += ivec2(0, -1); 
								if(inputs["Down"].repeated) shipPos += ivec2(0, 1); 
								if(inputs["Left"].repeated) shipPos += ivec2(-1, 0); 
								if(inputs["Right"].repeated) shipPos += ivec2(1, 0); 
								((0xEB3F5F5C4644).檢 (zoomedPlatform)), ((0xEB685F5C4644).檢 (shipPos)); 
							}
						}
						
						version(/+$DIDE_REGION Physics update+/all)
						{
							static if((常!(bool)(1))/+gravity+/)
							{
								if(
									landedOnPlatform<0/+Only when not landed+/
									/+So it will remember the speed at the moment of touch down+/
								)
								shipSpeed.y += 3.5f * Δt; 
							}
							
							shipPos += shipSpeed * Δt; 
						}
						
						version(/+$DIDE_REGION Fuel consumption+/all)
						{ fuel -= (thrustLeft + thrustRight + 4*thrustBottom) * 5 * Δt; fuel.maximize(0); }
						
						version(/+$DIDE_REGION Select camera position+/all)
						{
							if(zoomedPlatform.chkSet(decideZoomedPlatform))
							{
								const sceneId = [2, 4, 3, 5][zoomedPlatform+1]; 
								screen.img[0..38, 0..23] = screens[sceneId].img[0..38, 0..23]; 
								shipDoubleSize = zoomedPlatform>=0; 
							}
						}
						
						version(/+$DIDE_REGION Collisions, exceptions+/all)
						{
							if(shipPos.y<-21) {
								shipSimulated = false; 
								fuel = max(fuel - fuelPenalty, 0); 
								drawMsg(str("OUT OF SKY")); 
								delayedRestart = 2; 
							}
							
							landedOnPlatform = -1; 
							if(zoomedPlatform>=0)
							{
								auto bnd = bounds2(platformBounds[zoomedPlatform]*8); 
								enum extraPixels = 3; 
								bnd.left -= extraPixels; 
								bnd.right += -24 + extraPixels; 
								bnd.top -= 21; 
								
								if(shipPos in bnd)
								{
									shipPos.y = bnd.top; 
									landedOnPlatform = zoomedPlatform; 
									shipSpeed.x *= .9f; //slow down horizontally
									if((magnitude(shipSpeed.x))<.1f/+ship stopped on a platform+/)
									{
										shipSimulated = false; 
										
										version(/+$DIDE_REGION Score calculation+/all)
										{
											const 	baseScore 	= 	1000 - (ifloor(((shipSpeed.y * speedScale)/(8)) * 100))*10,
												multiplier 	= platformMultipliers[zoomedPlatform],
												totalScore 	= baseScore * multiplier; 
											if(baseScore>0)
											{
												drawMsg(str(i"$(baseScore) X $(multiplier) = $(totalScore)".text)); 
												pendingScore = totalScore; 
											}
											else if(baseScore>-1000)
											{ delayedExplosion = 2; drawMsg(str("SORRY NO BONUS")); }
											else
											{ delayedExplosion = .001f; drawMsg(str("KABOOM")); }
										}
									}
								}
							}
							
							if(
								sprites.detectCollision(
									shipSpriteIdx, (iround(applyTransformation(shipPos))), 
									shipDoubleSize, screen.img, font.raw
								)
							)
							{
								shipSimulated = false; 
								delayedExplosion = .001f; 
							}
						}
					}
					
					version(/+$DIDE_REGION Explosion+/all)
					{
						if(delayedExplosion>0)
						{
							delayedExplosion -= Δt; 
							if(delayedExplosion<=0)
							{
								delayedExplosion = 0; 
								shipExplosionTick = .001f; 
							}
						}
						if(shipExplosionTick > 0)
						{
							shipExplosionTick += Δtick * 0.65f; 
							
							const i = (ifloor(shipExplosionTick)); 
							shipColor = explosionColors[i%explosionColors.length]; 
							shipSpriteIdx = i/4+1; 
							if(shipSpriteIdx>explosionMaxSpriteIdx)
							{
								shipExplosionTick = 0; 
								shipSpriteIdx = -1; 
								fuel = max(fuel - fuelPenalty, 0); 
								shipVisible = false; 
								delayedRestart = 2; 
							}
						}
					}version(/+$DIDE_REGION Score counting, restarting+/all)
					{
						if(pendingScore > 0)
						{
							scoreTimer += Δt; enum scoringDelay = .02f; 
							while(scoreTimer >= scoringDelay)
							{
								scoreTimer -= scoringDelay; 
								const amount = pendingScore.min(10); 
								score 	+= amount,
								fuel 	+= amount*.025f,
								pendingScore 	-= amount; 
								if(!pendingScore) delayedRestart = 1; 
							}
						}
						if(delayedRestart>0)
						{
							delayedRestart -= Δt; 
							delayedRestart.maximize(0); 
						}
						
						if(gameOverTimer>0)
						{
							gameOverTimer -= Δt; 
							if(gameOverTimer<=0)
							{
								gameOverTimer=0; 
								score = 0; 
								scene = Scene.title; 
							}
						}
					}
				} 
				
				void tryStartGame()
				{ if(KeyCombo("F1").down) scene = Scene.game; } 
				
				final switch(scene)
				{
					case Scene.title: 	{
						if(t>=4) scene = Scene.instructions; 
						tryStartGame; 
					}	break; 
					case Scene.instructions: 	{
						flashingBottomText; animateInstructions; 
						if(tick>=32*(6*3+1)) scene = Scene.demo; 
						tryStartGame; 
					}	break; 
					case Scene.demo: 	{
						updateShip; flashingBottomText; 
						if(
							(!shipVisible && !delayedRestart) 
							|| t>20
						) scene = Scene.title; 
						tryStartGame; 
					}	break; 
					case Scene.game: 	{
						processInput(shipSimulated && fuel>0); updateShip; 
						if(scene==Scene.game/+because game over timer can switch out+/)
						{
							drawUI; 
							const 	ongoingStuff 	= (
								delayedExplosion || shipExplosionTick>0
								|| delayedRestart || pendingScore
								|| gameOverTimer>0
							),
								roundEnded 	= (!shipSimulated || !shipVisible); 
							if(!ongoingStuff && roundEnded)
							{
								if(fuel>0)
								{
									mixin(scope_remember(q{fuel, score})); 
									scene = Scene.game; 
								}
								else
								{
									highScore.maximize(score); 
									gameOverTimer = 3; 
									drawMsg(str("GAME OVER"), 4); 
								}
							}
						}
					}	break; 
				}
				((0x101A95F5C4644).檢((update間(_間)))); 
				void drawJupiterLander(ivec2 baseOfs)
				{
					enum N = 1; 
					__gshared Builder[N] builders; 
					import std.parallelism; 
					foreach(sy; N.iota.parallel)
					{
						if(!builders[sy]) builders[sy] = new Builder; 
						auto builder = builders[sy]; 
						builder.reset; 
						builder.PALH = c64Palette; 
						
						if(1)
						foreach(sx; N.iota)
						{
							const base = baseOfs + ivec2(40+8, 25+8)*ivec2(sx, sy); 
							with(screen) { builder.emitC64Screen(base+4, img, bkCols, borderCol); }
							if(shipVisible)
							{
								const p = base*8+4*8+applyTransformation(shipPos)/+no rounding+/; 
								if(!shipExplosionTick)
								{
									if(thrustLeft) builder.drawC64Sprite(p, 10, 2, shipDoubleSize); 
									if(thrustRight) builder.drawC64Sprite(p, 11, 2, shipDoubleSize); 
									if(thrustBottom) builder.drawC64Sprite(p, 8+thrustFlicker, 2, shipDoubleSize); 
								}
								if(shipSpriteIdx>=0)
								{ builder.drawC64Sprite(p, shipSpriteIdx, shipColor, shipDoubleSize); }
							}
						}
						
						((0x106105F5C4644).檢(builder.gbBitPos/8)); 
					}
					
					foreach(builder; builders[].filter!"a")
					appendGfxContent(builder.extractGfxContent); 
				} 
				
				
				
				{
					auto tvBuilder = new TurboVisionBuilder; 
					tvBuilder._builder.PALH = egaPalette; 
					tvBuilder._builder.FMH = vgaFont.tex; 
					
					
					with(tvBuilder)
					{
						//Link: google image search: borland turbo pascal
						//Link: https://psychocod3r.wordpress.com/2021/05/23/exploring-borland-turbo-pascal-for-dos/
						
						
						
						
						drawTextWindow
						(
							"noname00.pas", ibounds2(ivec2(0, 1), ((ivec2(80, 23)).genericArg!q{size})), 
							"Program Add;

Var
	Num1, Num2, Sum : integer;
Begin
	Write('Input number 1: ');
	Readln(Num1);
	Write('Input number 2: ');
	Readln(Num2);
	Sum := Num1 + Num2;
	Writeln(Sum);
	Readln;
End.".splitLines
						); 
						
						drawTextWindow
						(
							"JupiterLander.pas", ibounds2(ivec2(29, 5), ((ivec2(45, 19)).genericArg!q{size})), 
							"".splitLines
						); 
					}
					appendGfxContent(tvBuilder.extractGfxContent); tvBuilder.reset; 
					
					drawJupiterLander(ivec2(34, 12)); 
					
					tvBuilder.reset; 
					with(tvBuilder)
					{
						static MenuItem[] mainMenuItems = 
						[
							{"&File"}, 
							{"&Edit"}, 
							{"&Search"}, 
							{
								"&Run", selected : true, opened : true, subMenu : 
								[
									{"&Run", shortcut : "Ctrl+F9", selected : true}, 
									{"&Step over", shortcut : "F8"}, 
									{"&Trace into", shortcut : "F7"}, 
									{"&Go to cursor", shortcut : "F4"}, 
									{"&Program reset", shortcut : "Ctrl+F2", disabled : true}, 
									{"P&arameters..."}
								]
							},
							{"&Compile"}, 
							{"&Debug"}, 
							{"&Tools"}, 
							{"&Options"}, 
							{"&Window"}, 
							{"&Help"},
						]; 
						
						Text(M(0, 0)); drawMainMenu(mainMenuItems); fillSpace; 
						
						Text(
							M(0, 24), 	clMenuKey, chain(" ", "F1", " "), 
								clMenuItem, "Help \u00B3 Run the current program"
						); fillSpace; 
					}
					appendGfxContent(tvBuilder.extractGfxContent); tvBuilder.reset; 
				}
				
				((0x10ED15F5C4644).檢((update間(_間)))); 
				{
					auto builder = new Builder; 
					with(builder)
					{
						//builder.drawSprite(vec2(0), 0, 3, false); 
						drawPath(
							q{
								M 10,210 h.01 m 10 h 10 m 10 h 10 h 10 m 10 h 10 h 10 h 10
								M 10,220 h 10 v 10 h-10 v-10 m 10 m 10
								M 10,240 l10,10 q 30,0 0,30 h 10
								M 10,280 l10,10 c 20,0 10,10 0, 20 h 10
							}
						); 
						
						static if((常!(bool)(0)))
						{
							foreach(j; 0..20)
							drawPath(
								iota((iround(2+QPS.value(5*second).fract*(150-j*3))))
								.map!((i)=>(i"$(i?'L':'M')$(-i*3) $((iround(j*20 + 50 + sin(i*.2f)*30)))".text)).join
							); 
						}
						
						static if((常!(bool)(0)))
						{
							static string svgPath; if(svgPath=="") svgPath = `c:\dl\testSvgPath.txt`.File.readText(true); 
							//dr.color = clGold; dr.lineWidth = 1; 
							drawPath(svgPath); 
						}
						
						static if((常!(bool)(0)))
						{
							foreach(line; svgFontDemo.splitLines)
							if(line.strip.isWild(`<use xlink:href="#*" x="*" y="*"></use>`))
							{
								//dr.translate(wild[1].to!float, wild[2].to!float); 
								const id = wild[0]; 
								if(svgFontDemo.isWild(`*<path stroke-width="1" id="`~id~`" d="*"></path>*`))
								{ drawPath(wild[1]); }
								//dr.pop; 
							}
						}
					}
					auto content = builder.extractGfxContent; 
					//content.gb.hexDump; 
					appendGfxContent(content); 
				}
				((0x114AA5F5C4644).檢((update間(_間)))); 
				unittest_assembleSize; 
				
				
			} 
			
			
		} 
	} 
	
}