//@exe
//@debug
//@release

import het.vulkanwin; 

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
				auto verts = polyLineToTriangleStrip(pathPoints, (互!((float/+w=6+/),(0.128),(0x36525F5C4644)))*300); 
				
				int i; 
				foreach(v; verts.take((0x36B65F5C4644).檢((iround(verts.length*(互!((float/+w=6+/),(1.000),(0x36E15F5C4644))))).max(1))))
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
	class FrmHelloVulkan : VulkanWindow
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
				egaPalette = new Texture(TexFormat.rgba_u8, 16, ColorEnum!EGAColor.rgbaArray); 
				c64Palette = new Texture(TexFormat.rgba_u8, 16, ColorEnum!C64Color.rgbaArray); 
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
				{/+dr.rect_old((bounds2(0, 0, 1-0.125, 1-0.125)+vec2(x, y))*64, hiresSprite.handle), RGBA(0xFFFF8000); +/}
				
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
			
			int getPixel_c64_8x8Std(in Image2D!RG img, in ubyte[] fontMap, in ivec2 pScr) const
			{
				if(pScr in ibounds2(ivec2(0), img.size*8))
				{
					const chPos = pScr>>3; 
					const ch = img[chPos.x, chPos.y].x; 
					if(ch < fontMap.length/8)
					{
						const remPos = pScr & 7; 
						return fontMap[ch*8 + remPos.y].getBit(remPos.x); 
					}
				}
				return 0; 
			} 
			
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
			
			class Sprites
			{
				BitmapArrayTexture tex; 
				RG[][] collisionPoints; 
				
				this(string bin)
				{
					tex = new BitmapArrayTexture(bin, cellSize: ivec2(24, 21)); 
					
					version(/+$DIDE_REGION Calculate collisionPoints+/all)
					{
						with(tex)
						foreach(i; 0..length)
						{
							RG[] res; bool p(int x, int y)
							{
								if(getPixel_1bit_unsafe(i, x, y))
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
						if(getPixel_c64_8x8Std(screen, fontMap, pScr)) return true; 
					}
					return false; 
				} 
			} 
			Sprites sprites; 
			
			
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
			
			FontSpec!FontFace customFont; 
			
			void loadAssets()
			{
				loadScreens(binScreens); 
				with(screens[0]) { bkCols = [15, 2, 6]; borderCol = 15; }
				with(screens[1]) { bkCols = [6, 0, 0]; borderCol = 8; }
				foreach(ref sc; screens[2..$])
				with(sc) { bkCols = [0, 4, 8]; borderCol = 0; }customFont = Font(
					new MonoFont
					(
						FontId._reserved_, "unnamed", new BitmapArrayTexture
						((cast(ubyte[])(binCharMap)), cellSize:ivec2(8, 8))
					)
				); 
				
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
				ibounds2(ivec2( 8, 19), ((ivec2(6, 1)).名!q{size})),
				ibounds2(ivec2(19,  6), ((ivec2(6, 1)).名!q{size})),
				ibounds2(ivec2(27, 20), ((ivec2(5, 1)).名!q{size}))
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
								((0x888D5F5C4644).檢 (zoomedPlatform)), ((0x88B65F5C4644).檢 (shipPos)); 
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
									shipDoubleSize, screen.img, 
									(cast(BitmapArrayTexture)((cast(MonoFont)(customFont.fontSpec)).monoTexture)).raw
									//Todo: ^^^ that's nasty!  Should be an option to use a texture only
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
				
				void drawJupiterLanderOnBuilder(GfxBuilder builder, ivec2 base)
				{
					with(builder)
					{
						PALH = c64Palette; 
						Style(customFont); 
						with(screen) { drawC64Screen(base+4, img, bkCols, borderCol); }
						if(shipVisible)
						{
							const p = base*8+4*8 + applyTransformation(shipPos)/+no rounding+/; 
							FMH 	= sprites.tex,
							FH 	= sprites.tex.height * (shipDoubleSize ? 2 : 1); 
							SC = vec4(0); 
							if(!shipExplosionTick)
							{
								PC(2, 4); //Todo: named colors!!!
								if(thrustLeft) drawC64Sprite(p, 10); 
								if(thrustRight) drawC64Sprite(p, 11); 
								if(thrustBottom) drawC64Sprite(p, 8+thrustFlicker); 
							}
							if(shipSpriteIdx>=0)
							{
								PC(shipColor, 4); //Todo: color enum!!!
								drawC64Sprite(p, shipSpriteIdx); 
							}
						}
						//((0xA5005F5C4644).檢(gbBitPos/8)); 
					}
				} 
				
				version(none)
				void drawJupiterLander(ivec2 baseOfs)
				{
					enum N = 1; 
					__gshared GfxBuilder[N] builders; 
					import std.parallelism; 
					foreach(sy; N.iota.parallel)
					{
						if(!builders[sy]) builders[sy] = new GfxBuilder; 
						auto builder = builders[sy]; builder.resetStream; 
						
						foreach(sx; N.iota)
						{
							const base = baseOfs + ivec2(40+8, 25+8)*ivec2(sx, sy); 
							drawJupiterLanderOnBuilder(builder, base); 
						}
					}
					
					foreach(builder; builders[].filter!"a")
					appendGfxContent(builder.extractGfxContent); 
				} 
				((0xA5995F5C4644).檢((update間(_間)))); 
				
				
				
				{
					auto tvBuilder = new TurboVisionBuilder; 
					tvBuilder.gfxContentDestination = getGfxContentDestination/+enables commit()/consume()+/; 
					tvBuilder.PALH = egaPalette; 
					
					static FontSpec!FontFace customFont222; 
					{
						static bool initialized; 
						if(initialized.chkSet)
						{
							//registerFont_mono_1bit("CGA_8x8", File(`fontmap:\C64_lower`), cellSize: ivec2(8, 8)); 
							
							registerFont_mono_1bit(File(`fontmap:\C64_upper`), cellSize: ivec2(8, 8)); 
							customFont222 = Font(accessFontFace("C64_upper")); 
						}
					}
					
					((0xA8335F5C4644).檢((update間(_間)))); 
					//Opt: ✅ tvBuilder.Style(Font.VGA_9x16) is the slowest of all.  Something's fucked up with that generator...
					if((互!((bool),(0),(0xA8DD5F5C4644))))
					{
						foreach(i; 0..10_000) tvBuilder.Style(Font.VGA_9x16); 	((0xA9485F5C4644).檢((update間(_間)))); 
						foreach(i; 0..10_000) tvBuilder.Style(Font(FontId.VGA_9x16)); 	((0xA9BA5F5C4644).檢((update間(_間)))); 
						foreach(i; 0..10_000) tvBuilder.Style(Font("VGA_9x16")); 	((0xAA275F5C4644).檢((update間(_間)))); 
						foreach(i; 0..10_000) tvBuilder.Style(Font(accessFontFace("C64_upper"))); 	((0xAAA55F5C4644).檢((update間(_間)))); 
						foreach(i; 0..10_000) tvBuilder.Style(Font.VGA_9x16.bold.italic.errorline); 	((0xAB255F5C4644).檢((update間(_間)))); 
						foreach(i; 0..10_000) tvBuilder.Style(customFont222); 	((0xAB8F5F5C4644).檢((update間(_間)))); 
						foreach(i; 0..10_000) tvBuilder.Style(Font("C64_upper")); 	((0xABFD5F5C4644).檢((update間(_間)))); 
						foreach(i; 0..10_000) tvBuilder.Style(Font(accessFontFace("C64_upper"))); 	((0xAC7B5F5C4644).檢((update間(_間)))); 
					}
					
					tvBuilder.Style(Font.VGA_9x16); 
					
					if((互!((bool),(0),(0xACED5F5C4644)))) { tvBuilder.Style(Font.bold.italic); }
					if((互!((bool),(0),(0xAD425F5C4644)))) { tvBuilder.Style(Font.VGA_9x16); }
					if((互!((bool),(0),(0xAD945F5C4644)))) { tvBuilder.Style(Font.CGA_8x8); }
					if((互!((bool),(0),(0xADE55F5C4644)))) {
						static FontSpec!FontFace customFont; 
						static bool initialized; 
						if(initialized.chkSet)
						{
							registerFont_mono_1bit("Tiny_5x8", File(`fontmap:\EverexME_5x8`), cellSize: ivec2(5, 8)); 
							customFont = Font(accessFontFace("Tiny_5x8")).bold; 
						}
						tvBuilder.Style(customFont.italic); 
					}
					if((互!((bool),(0),(0xAF675F5C4644)))) { tvBuilder.Style(Font("C64_upper")); }
					
					
					if(tvBuilder.fontFace) ((0xAFDF5F5C4644).檢(tvBuilder.fontFace.id)); 
					if(tvBuilder.fontFace) ((0xB02C5F5C4644).檢(tvBuilder.fontFace.identityStr)); 
					
					if((互!((bool),(1),(0xB0755F5C4644))))
					{
						with(tvBuilder.TR)
						{
							if((互!((bool),(0),(0xB0D05F5C4644)))) {
								scaleXY = ((
									vec2(
										(互!((float/+w=6+/),(0.496),(0xB1285F5C4644))), 
										(互!((float/+w=6+/),(0.496),(0xB1655F5C4644)))
									)*2
								)^^(2)); 
								if((互!((bool),(0),(0xB1C25F5C4644)))/+Note: uniform+/) with(scaleXY) y = x; 
							}
							if((互!((bool),(0),(0xB2235F5C4644)))) { skewX_deg = (互!((float/+min=-90 max=90 w=3 h=3+/),(-1.000),(0xB2565F5C4644))); }
							if((互!((bool),(0),(0xB2A85F5C4644)))) rotZ_deg = (互!((float/+w=3 h=3 endless=1+/),(0.111),(0xB2D85F5C4644)))*360; 
							if((互!((bool),(0),(0xB3275F5C4644)))) {
								transXY = (
									vec2(
										(互!((float/+w=6+/),(0.000),(0xB37E5F5C4644))),
										(互!((float/+w=6+/),(0.000),(0xB3BA5F5C4644)))
									)-.5f
								)*300; 
							}
							if((互!((bool),(0),(0xB4205F5C4644)))) {
								clipBounds =
								bounds2(
									vec2(
										(互!((float/+min=-200 max=2200 w=6+/),(-200.000),(0xB48A5F5C4644))),
										(互!((float/+min=-200 max=1200 w=6+/),(-200.000),(0xB4DB5F5C4644)))
									),
									((
										vec2(
											(互!((float/+min=-100 max=2000 w=6+/),(2000.000),(0xB5575F5C4644))),
											(互!((float/+min=0 max=2000 w=6+/),(614.932),(0xB5A95F5C4644)))
										)
									).名!q{size})
								); 
							}
							((0xB62F5F5C4644).檢(
								i"$(transXY)
$(skewX_deg)
$(rotZ_deg)
$(scaleXY)
$(clipBounds)".text
							)); 
						}
					}
					
					if((互!((bool),(0),(0xB6C65F5C4644))))
					{
						with(tvBuilder) {
							void benchmarkStateSaving(int N=10000, void delegate() fun)
							{
								/+
									Todo: 250927 conclusion: the state is fragmented: 
									should be placed into to a contiguous struct.
								+/
								void doit(int i)
								{
									auto savedState = allState; 
									fun(); 
									if(i<10) doit(i+1)/+recursion+/; 
									setState(savedState); 
								} 
								foreach(i; 0..N) doit((i&7)+3); 
							} 
							
							((0xB8E45F5C4644).檢((update間(_間)))); /+asm { int 3; } +/benchmarkStateSaving(0xBEEF, { TR.reset; }); ((0xB94F5F5C4644).檢((update間(_間)))); 
						}
					}
					
					if((互!((bool),(0),(0xB99C5F5C4644))))
					{
						with(tvBuilder) {
							Style(((white).名!q{fg}), ((black).名!q{bk}), ((5).名!q{TR.scaleXY})); 
							Text(mixin(舉!((FontId),q{CGA_8x8})), ((ltRed).名!q{fg}), "aa", M(0, 1), "bb"); 
							
							Text("aa"); 
							commit; return; 
						}
					}
					
					static struct SpringSimulation
					{
						// Spring endpoints
						float P0; 
						float P1; 
						
						// Spring state
						float springLength; 	// normal/rest length
						float velocity0, velocity1; 	// current velocity of the moving end
						
						// Constructor
						this(float p0, float p1, float length, float initialVelocity = 0.0f) 
						{
							P0 = p0; 
							P1 = p1; 
							springLength = length; 
							velocity0 = initialVelocity; 
							velocity1 = initialVelocity; 
						} 
						
						void update(
							float deltaTime_sec, float mass, float damping, float gravity, 
							float minRange, float maxRange
						) 
						{
							
							// Calculate spring force (Hooke's Law: F = -k * x)
							float displacement = (P1 - P0) - springLength; 
							float springForce0 = +displacement; 	 // k = 1 for simplicity
							float springForce1 = -displacement; 	 // k = 1 for simplicity
							
							// Calculate damping force (F = -c * v)
							float dampingForce0 = +damping * velocity0; 
							float dampingForce1 = -damping * velocity1; 
							
							// Calculate gravitational force
							float gravityForce = mass * gravity; 
							
							// Total force acting on the mass
							float totalForce0 = springForce0 + dampingForce0 + gravityForce; 
							float totalForce1 = springForce1 + dampingForce1 + gravityForce; 
							
							// Update velocity using Newton's second law (F = ma)
							float acceleration0 = totalForce0 / mass; 
							float acceleration1 = totalForce1 / mass; 
							
							velocity0 += acceleration0 * deltaTime_sec; 
							velocity1 += acceleration1 * deltaTime_sec; 
							
							// Update position
							P0 += velocity0 * deltaTime_sec; 
							P1 += velocity1 * deltaTime_sec; 
							
							// Apply boundary constraints with elastic bounce
							applyBoundaryConstraints(minRange, maxRange); 
						} 
						
						void applyBoundaryConstraints(float minRange, float maxRange) 
						{
							// Check if P1 exceeds the maximum range
							if(P1 > maxRange) {
								float overshoot = P1 - maxRange; 
								P1 = maxRange - overshoot;  // Reflect position
								velocity1 = -abs(velocity1) * 1;  // Reverse velocity with energy loss (bounce damping)
							}
							
							// Check if P1 goes below the minimum range
							if(P1 < minRange) {
								float overshoot = minRange - P1; 
								P1 = minRange + overshoot;  // Reflect position
								velocity1 = +abs(velocity1) * 1;  // Reverse velocity with energy loss (bounce damping)
							}
							
							// Check if P0 exceeds the maximum range
							if(P0 > maxRange) {
								float overshoot = P0 - maxRange; 
								P0 = maxRange - overshoot;  // Reflect position
								velocity0 = -abs(velocity0) * 1;  // Reverse velocity with energy loss (bounce damping)
							}
							
							// Check if P0 goes below the minimum range
							if(P0 < minRange) {
								float overshoot = minRange - P0; 
								P0 = minRange + overshoot;  // Reflect position
								velocity0 = +abs(velocity0) * 1;  // Reverse velocity with energy loss (bounce damping)
							}
							
						} 
						
						// Helper function to visualize the spring
						void draw() const 
						{
							writefln(
								"Spring: P0=%.2f, P1=%.2f, Length=%.2f, Velocity=%.2f", 
								P0, P1, (P1 - P0), velocity0
							); 
						} 
					} 
					
					
					static struct BouncingBounds
					{
						SpringSimulation horz, vert; 
						
						this(uint seed)
						{
							RNG rng; rng.seed = seed; 
							auto 	vel 	= vec2(rng.randomGaussPair[])*10, 
								pos0 	= vec2(rng.randomGaussPair[])*15, 
								pos1 	= vec2(rng.randomGaussPair[])*15; 
							
							horz = SpringSimulation(50.0f+pos0.x, 50+8*(40+8) + 5+pos1.x, 8*(40+8), 10 + vel.x); 
							vert = SpringSimulation(50.0f+pos0.y, 50+8*(25+8) + 10+pos1.y, 8*(25+8), 0 + vel.y); 
						} 
						
						void update(float deltaTime)
						{
							{
								float mass = .18f; 
								float damping = 0.02f; 
								float gravity = .1 * 9.8f; 
								float minRange = 16*1; 
								float maxRange = 16*24; 
								vert.update(
									deltaTime, mass, damping, 
									gravity, minRange, maxRange
								); 
							}
							{
								float mass = .24f; 
								float damping = 0.00f; 
								float gravity = 0; 
								float minRange = 9*1; 
								float maxRange = 9*79; 
								horz.update(
									deltaTime, mass, damping, 
									gravity, minRange, maxRange
								); 
							}
						} 
						
						@property bounds() const => bounds2(horz.P0, vert.P0, horz.P1, vert.P1); 
					} 
					
					static bouncingBounds = mixin(求map(q{seed},q{iota(80/4)},q{BouncingBounds(seed)})).array; 
					((0xCDDE5F5C4644).檢((update間(_間)))); mixin(求each(q{ref bb},q{bouncingBounds},q{bb.update(deltaTime.value(second))})); ((0xCE5C5F5C4644).檢((update間(_間)))); 
					
					with(tvBuilder)
					{
						//Link: google image search: borland turbo pascal
						//Link: https://psychocod3r.wordpress.com/2021/05/23/exploring-borland-turbo-pascal-for-dos/
						
						drawTextWindow
						(
							"noname00.pas", ibounds2(ivec2(0, 1), ((ivec2(80, 23)).名!q{size})), 
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
						
						Style(((.66).名!q{opacity})); 
						static TurboVisionBuilder jlBuilder; if(!jlBuilder) jlBuilder = new TurboVisionBuilder; 
						foreach(const bb; bouncingBounds)
						{
							jlBuilder.setState(colorState, fontState); 
							with(jlBuilder)
							{
								const windowSize = ivec2(45, 19); 
								TR.transXY = bb.bounds.topLeft; 
								TR.scaleXY = ((bb.bounds.size)/(windowSize*fontSize)); 
								drawTextWindow
									(
									"JupiterLander.pas", ibounds2(ivec2(0), ((windowSize).名!q{size})), 
									"".splitLines
								); 
								TR.transXY = TR.transXY + fontSize * TR.scaleXY; 
								TR.scaleXY.y *= ((windowSize.y-2)*fontSize.y) / (float((25+8)*8)); 
								drawJupiterLanderOnBuilder(jlBuilder, ivec2(0)); 
							}
							consume(jlBuilder); 
						}
						
						Style(((1).名!q{opacity})); 
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
								clMenuItem, "Help │ Run the current program"
						); fillSpace; 
					}
					
					tvBuilder.commit; 
				}
				
				((0xD7CE5F5C4644).檢((update間(_間)))); 
				{
					auto builder = new GfxBuilder; 
					with(builder)
					{
						//builder.drawSprite(vec2(0), 0, 3, false); 
						{
							const f = QPS_local.value(second).sin.remap(-1, 1, 0, 1); 
							PC = vec3(f, .66, 1).from_hsv; LW = 1 + ((40)*(f)); 
							TR.transXY = vec2(0, 200), TR.rotZ_deg = f*200; 
						}
						
						drawPath(
							q{
								M 10,10 h.01 m 10 h 10 m 10 h 10 h 10 m 10 h 10 h 10 h 10
								M 10,20 h 10 v 10 h-10 v-10 m 10 m 10
								M 10,40 l10,10 q 30,0 0,30 h 10
								M 10,80 l10,10 c 20,0 10,10 0, 20 h 10
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
								TR.transXY = vec2(wild[1].to!float, wild[2].to!float); 
								const id = wild[0]; 
								if(svgFontDemo.isWild(`*<path stroke-width="1" id="`~id~`" d="*"></path>*`))
								{ drawPath(wild[1]); }
								//dr.pop; 
							}
						}
					}
					consumeGfxContent(builder); 
				}
				((0xDE2E5F5C4644).檢((update間(_間)))); 
				
				
				
			} 
			
			
		} 
	} 
	
}


version(/+$DIDE_REGION+/all)
{
	/+
		Assistant: /+H1: Drawing Graphics API Cheat Sheet+/
		
		/+H2: Core Concepts+/
			/+Bullet: /+Bold: Drawing+/: Main class for 2D graphics operations+/
			/+Bullet: /+Bold: State-based+/: Maintains drawing state (color, line style, transformations)+/
			/+Bullet: /+Bold: Immediate mode+/: Commands are buffered and drawn later+/
			/+Bullet: /+Bold: GPU accelerated+/: Uses OpenGL/VBOs for rendering+/
		
		/+H2: Initialization & Management+/
		/+
			Structured: auto d = new Drawing(); 	// Create new drawing
			auto d = new Drawing("name"); 	// Named drawing
			auto clone = d.clone(); 	// Create clone
			d.clear(); 	// Clear all content
			d.clear(RGB.clWhite); 	// Clear with background color
		+/
		
		/+H2: State Management+/
		/+H3: Colors & Alpha+/
		/+
			Structured: d.color = RGB.clRed; 	// Set draw color
			d.alpha = 0.5; 	// Set alpha (0-1)
		+/
		
		/+H3: Line & Point Properties+/
		/+
			Structured: d.lineWidth = 2.0; 	// Absolute line width
			d.lineWidth = -2.0; 	// Relative line width
			d.pointSize = 3.0; 	// Point size
			d.lineStyle = LineStyle.normal; 	// Line style
			d.arrowStyle = ArrowStyle.none; 	// Arrow style
		+/
		
		/+H3: Font Properties+/
		/+
			Structured: d.fontHeight = 18; 	// Font size
			d.fontWeight = 1.4; 	// Font weight
			d.fontBold = true; 	// Bold text
			d.fontItalic = true; 	// Italic text
			d.fontMonoSpace = true; 	// Monospace font
			d.fontUnderline = true; 	// Underline
			d.fontStrikeOut = true; 	// Strikeout
		+/
		
		/+H3: Transformations+/
		/+
			Structured: d.translate(x, y); 	// Move origin
			d.scale(factor); 	// Scale drawing
			d.push(); 	// Save transformation state
			d.pop(); 	// Restore transformation state
		+/
		
		/+H3: State Stack+/
		/+
			Structured: d.saveState(); 	// Push current state
			d.restoreState(); 	// Pop state
			d.pushState(); d.popState(); 	// Aliases
		+/
		/+H2: Drawing Primitives+/
		
		/+H3: Points+/
		/+
			Structured: d.point(x, y); 	// Single point
			d.point(vec2(x, y)); 	// Vector point
			d.point(RGB.clRed, x, y); 	// Colored point
			d.point([vec2(0,0), vec2(1,1)]); 	// Multiple points
		+/
		
		/+H3: Lines+/
		/+
			Structured: d.moveTo(x, y); 	// Set starting point
			d.lineTo(x, y); 	// Draw line to point
			d.lineRel(dx, dy); 	// Relative line
			d.line(p0, p1); 	// Line between points
			d.line([p0, p1, p2]); 	// Polyline
			d.lineLoop([p0, p1, p2]); 	// Closed polyline
		+/
		
		/+H3: Advanced Line Drawing+/
		/+
			Structured: d.line2(
				// Flexible line command
				RGB.clRed,	// Color
				2.0,	// Line width  
				vec2(0,0), vec2(100,100),	// Points
				LineStyle.dashed	// Line style
			); 	
		+/
		
		/+H3: Shapes+/
		/+
			Structured: d.drawRect(x0, y0, x1, y1); 	// Rectangle outline
			d.fillRect(x0, y0, x1, y1); 	// Filled rectangle
			d.drawX(x0, y0, x1, y1); 	// X mark
			d.fillTriangle(p0, p1, p2); 	// Filled triangle
			d.fillConvexPoly([p0, p1, p2, p3]); 	// Convex polygon
		+/
		
		/+H3: Curves & Circles+/
		/+
			Structured: d.ellipse(x, y, rx, ry); 	// Ellipse
			d.circle(x, y, radius); 	// Circle
			d.bezier2(p0, p1, p2); 	// Quadratic Bezier
		+/
		
		/+H2: Text Rendering+/
		/+
			Structured: d.textOut(x, y, "Hello"); 	// Basic text
			d.textOut(vec2(x,y), "Hello"); 	// Vector position
			d.textOut(p, "Text", width, HAlign.center); 	// Aligned text
			d.textOutMulti(x, y, "Line1\nLine2"); 	// Multiline text
		+/
		
		/+H2: Images & Textures+/
		/+
			Structured: d.drawGlyph("image.png", x, y); 	// Draw image
			d.drawGlyph("image.png", bounds); 	// Draw to bounds
			d.drawGlyph(
				img,x, y,	// With options
				Flag.nearest,	// Filtering
				RectAlign.center,	// Alignment
				DrawGlyphScale(0.5)	// Scale
			); 
		+/
		
		/+H2: Advanced Features+/
		
		/+H3: Clipping+/
		/+
			Structured: d.pushClipBounds(bounds); 	// Set clip region
			// drawing commands...
			d.popClipBounds(); 	// Restore clip
		+/
		
		/+H3: Graphs & Charts+/
		/+
			Structured: d.vGraph(x0, y0, data); 	// Vertical graph
			d.hGraph(x0, y0, data); 	// Horizontal graph  
			d.hBars(x0, y0, data); 	// Bar chart
		+/
		
		/+H3: Custom Shaders+/
		/+
			Structured: d.customShader = `vec4 customShader() {
		// GLSL code
		return vec4(1.0);
	}`; 
		+/
		
		/+H3: SVG Paths+/
		/+
			Structured: d.drawPath("M 0 0 L 100 100"); // SVG path data
		+/
		
		/+H2: Rendering+/
		/+
			Structured: d.glDraw(view); 	// Draw to view
			d.glDraw(center, scale); 	// Draw with custom transform
		+/
		
		/+H2: Utility Functions+/
		/+
			Structured: bool empty = d.empty(); 	// Check if empty
			bounds2 b = d.bounds; 	// Get bounding box
			string s = d.stats(); 	// Get statistics
			auto objs = d.exportDrawingObjs(); 	// Export drawing objects
		+/
		
		/+H2: Coordinate Systems+/
			/+Bullet: /+Bold: Local coordinates+/: Affected by transformations+/
			/+Bullet: /+Bold: Screen coordinates+/: Final output coordinates  +/
			/+Bullet: Use /+Highlighted: inputTransform()+/ and /+Highlighted: inverseInputTransform()+/ for conversions+/
		
		/+H2: Performance Notes+/
			/+Bullet: Uses VBOs for GPU acceleration+/
			/+Bullet: Batches drawing commands automatically+/
			/+Bullet: Clones share data with original+/
			/+Bullet: Sub-drawings allow hierarchical composition+/
		
		/+H2: Common Patterns+/
		/+
			Structured: // Fluid interface pattern
			d.push()	.translate(10, 10)
				.scale(2)
				.drawRect(0, 0, 50, 50)
				.pop(); 
			
			// State backup pattern  
			d.saveState(); 
			d.color = RGB.clBlue; 
			d.lineWidth = 3; 
			// drawing...
			d.restoreState(); 
		+/
		
		/+Note: Usage(prompt_hit: 64, prompt_miss: 18898, completion: 1464, HUF: 2.55, price: 100%)+/
	+/
	
	/+
		Assistant: /+
			Para: I'll analyze the Drawing class usage patterns from the provided examples and categorize them
			with statistics.
		+/
		
		/+H2: Drawing Usage Pattern Analysis+/
		
		/+H3: Categories of Usage Patterns:+/
		
		1. /+Bold: COLOR & STYLING+/ (Most Frequent - 115 occurrences)
				/+Bullet: /+Highlighted: dr.color = colorValue+/ (85 occurrences)+/
				/+Bullet: /+Highlighted: dr.alpha = value+/ (4 occurrences)+/
				/+Bullet: /+Highlighted: dr.lineWidth = value+/ (6 occurrences)+/
				/+Bullet: /+Highlighted: dr.lineStyle = LineStyle.normal/dash+/ (8 occurrences)+/
				/+Bullet: /+Highlighted: dr.fontHeight = value+/ (8 occurrences)+/
				/+Bullet: /+Highlighted: dr.fontMonoSpace = bool+/ (4 occurrences)+/
		
		2. /+Bold: TRANSFORMATIONS+/ (45 occurrences)
				/+Bullet: /+Highlighted: dr.translate(x, y) / dr.translate(vec2)+/ (25 occurrences)+/
				/+Bullet: /+Highlighted: dr.pop+/ (15 occurrences)+/
				/+Bullet: /+Highlighted: dr.scale(factor)+/ (3 occurrences)+/
				/+Bullet: /+Highlighted: dr.pushClipBounds(bounds)+/ (2 occurrences)+/
		
		3. /+Bold: RECTANGLE OPERATIONS+/ (40 occurrences)
				/+Bullet: /+Highlighted: dr.drawRect(bounds) / dr.drawRect(x, y, w, h)+/ (15 occurrences)+/
				/+Bullet: /+Highlighted: dr.fillRect(bounds) / dr.fillRect(x, y, w, h)+/ (15 occurrences)+/
				/+Bullet: /+Highlighted: bounds2() creation and manipulation+/ (10 occurrences)+/
		
		4. /+Bold: LINE DRAWING+/ (35 occurrences)
				/+Bullet: /+Highlighted: dr.line/line2(points...)+/ (20 occurrences)+/
				/+Bullet: /+Highlighted: dr.vLine/hLine+/ (10 occurrences)+/
				/+Bullet: /+Highlighted: lineWidth changes+/ (5 occurrences)+/
		
		5. /+Bold: TEXT OPERATIONS+/ (25 occurrences)
				/+Bullet: /+Highlighted: dr.drawFontGlyph(stIdx, bounds, bkColor, fontFlags)+/ (15 occurrences)+/
				/+Bullet: /+Highlighted: dr.textOut(position, text)+/ (10 occurrences)+/
		
		6. /+Bold: POINT DRAWING+/ (20 occurrences)
				/+Bullet: /+Highlighted: dr.point(position)+/ (15 occurrences)+/
				/+Bullet: /+Highlighted: dr.pointSize changes+/ (5 occurrences)+/
		
		7. /+Bold: BEZIER OPERATIONS+/ (15 occurrences)
				/+Bullet: /+Highlighted: dr.drawCubicBezierDebug(P0, P1, P2, P3, r0, r1)+/ (5 occurrences)+/
				/+Bullet: /+Highlighted: dr.lineTo with evalBezier+/ (10 occurrences)+/
		
		8. /+Bold: CLIPPING+/ (8 occurrences)
				/+Bullet: /+Highlighted: dr.pushClipBounds+/ (4 occurrences)+/
				/+Bullet: /+Highlighted: dr.popClipBounds+/ (4 occurrences)+/
		
		9. /+Bold: STATE MANAGEMENT+/ (7 occurrences)
				/+Bullet: /+Highlighted: dr.push/dr.pop+/ (transform stack)+/
				/+Bullet: /+Highlighted: dr.clone/dr.subDraw+/ (drawing reuse)+/
				/+Bullet: /+Highlighted: dr.reset/dr.finalize+/+/
		
		10. /+Bold: ADVANCED OPERATIONS+/ (6 occurrences)
			/+Bullet: /+Highlighted: dr.lineLoop(points)+/ (closed polyline)+/
			/+Bullet: /+Highlighted: dr.copyFrom(otherDrawing)+/+/
			/+Bullet: /+Highlighted: dr.glDraw(view)+/ (OpenGL rendering)+/
			/+Bullet: /+Highlighted: dr.isClone property+/+/
		
		/+H3: Usage Statistics:+/
		
		/+
			Structured: (表([
				[q{/+Note: Category+/},q{/+Note: Count+/},q{/+Note: Percentage+/}],
				[q{Color & Styling},q{115},q{37.1%}],
				[q{Transformations},q{45},q{14.5%}],
				[q{Rectangle Operations},q{40},q{12.9%}],
				[q{Line Drawing},q{35},q{11.3%}],
				[q{Text Operations},q{25},q{8.1%}],
				[q{Point Drawing},q{20},q{6.5%}],
				[q{Bezier Operations},q{15},q{4.8%}],
				[q{Clipping},q{8},q{2.6%}],
				[q{State Management},q{7},q{2.3%}],
				[q{Advanced Operations},q{6},q{1.9%}],
				[q{/+Bold: Total+/},q{/+Bold: 310+/},q{/+Bold: 100%+/}],
			]))
		+/
		
		/+H3: Most Popular Specific Usages:+/
		
		1. /+Highlighted: dr.color = colorValue+/ - 85 occurrences (27.4% of total)
		2. /+Highlighted: dr.translate+/ - 25 occurrences (8.1% of total)
		3. /+Highlighted: dr.drawRect/fillRect+/ - 30 occurrences (9.7% of total)
		4. /+Highlighted: dr.line/line2+/ - 20 occurrences (6.5% of total)
		5. /+Highlighted: dr.pop+/ - 15 occurrences (4.8% of total)
		
		/+H3: Most Common Color Constants:+/
		
		1. /+Highlighted: clWhite+/ - 15+ occurrences
		2. /+Highlighted: clGray/Silver+/ - 10+ occurrences
		3. /+Highlighted: clFuchsia+/ - 8+ occurrences
		4. /+Highlighted: clRed/Blue/Lime+/ - 6+ occurrences each
		5. /+Highlighted: clYellow/Orange/Aqua+/ - 5+ occurrences each
		
		/+H3: Key Observations:+/
		
			/+
			Bullet: /+Bold: Color setting is overwhelmingly dominant+/ (37.1%), indicating Drawing is heavily used for
			stylized rendering with frequent color changes
		+/
			/+Bullet: /+Bold: Transform stack operations+/ are very common, showing hierarchical coordinate system usage+/
			/+Bullet: /+Bold: Rectangle and line primitives+/ form the core drawing functionality+/
			/+Bullet: /+Bold: Text and font operations+/ are significant, indicating UI/text rendering is a primary use case+/
			/+Bullet: /+Bold: Bezier curve support+/ shows advanced path drawing capabilities+/
			/+Bullet: /+Bold: Heavy use of color-state-change-draw sequences+/ suggests immediate mode drawing patterns+/
			/+Bullet: /+Bold: Frequent transform push/pop+/ indicates complex hierarchical drawing structures+/
		
		/+
			Para: The Drawing class provides a comprehensive 2D drawing API with strong emphasis on immediate mode drawing,
			hierarchical coordinate systems, rich styling options, and both simple primitives and complex path operations,
			particularly focused on UI element rendering with text and bezier curve support.
		+/
		
	+/
	/+
		Assistant: /+H1: View2D Graphics API Cheat Sheet+/
		
		/+H2: Core Properties+/
			/+Bullet: /+Highlighted: origin+/: World space center point (Vector2D)+/
			/+Bullet: /+Highlighted: scale+/: Zoom factor (1.0 = 1 unit = 1 pixel)+/
			/+Bullet: /+Highlighted: invScale+/: Pixel size in world units+/
			/+Bullet: /+Highlighted: animSpeed+/: Animation smoothness (0.0-0.9)+/
		
		/+H2: Coordinate Transformation+/
		/+
			Structured: // World → Screen
			vec2 screenPos = view.trans(worldPos); 
			vec2 screenPos = view.trans(worldPos, false); // skip animation
			
			// Screen → World  
			vec2 worldPos = view.invTrans(screenPos); 
			vec2 worldPos = view.invTrans(screenPos, false); // skip animation
		+/
		
		/+H2: Navigation Controls+/
		/+
			Structured: // Scroll
			view.scroll(vec2(dx, dy)); 	// Relative world units
			view.scrollH(pixels); 	// Horizontal pixels
			view.scrollV(pixels); 	// Vertical pixels
			
			// Zoom
			view.zoom(factor); 	// Relative zoom (logarithmic)
			view.zoomAround(screenPoint, factor); 	// Zoom around specific point
			view.zoomAroundMouse(factor); 	// Zoom around mouse position
			
			// View fitting
			view.zoom(bounds); 	// Fit bounds to view
			view.zoomAll(); 	// Fit workArea to view
			view.zoomAll_immediate(); 	// Instant fit
			view.autoZoom(); 	// Auto-fit when workArea changes
		+/
		
		/+H2: Viewport Management+/
		/+
			Structured: // Sub-screen area (for UI overlays)
			view.subScreenArea = bounds2(0.1, 0.1, 0.9, 0.9); 
			
			// Center correction (anti-aliasing)
			view.centerCorrection = true; 
			
			// Get visible area
			bounds2 visible = view.visibleArea(); 
			bounds2 visibleNow = view.visibleArea(false); // no animation
		+/
		
		/+H2: Mouse Interaction+/
		/+
			Structured: // Mouse position tracking
			vec2 worldMousePos = view.mousePos; 
			bool mouseInside = view.isMouseInside(); 
			
			// Screen bounds
			bounds2 screenBounds = view.subScreenBounds_anim(); 
		+/
		
		/+H2: Animation Control+/
		/+
			Structured: view.skipAnimation(); 	// Jump to target immediately
			view.updateAnimation(deltaTime, true); 	// Manual animation update
		+/
		
		/+H2: Smart Navigation+/
		/+
			Structured: view.smartScrollTo(targetBounds); 	// Queue smooth scroll-to
			view.updateSmartScroll(); 	// Process scroll queue
		+/
		
		/+H2: Configuration+/
		/+
			Structured: // Save/load view state
			string config = view.config; 
			view.config = savedConfig; 
		+/
		
		/+H2: Input Handling+/
		/+
			Structured: // Built-in navigation (keyboard + mouse)
			view.navigate(true, true); // Enable both input methods
			
			// Default controls:
			// - MMB/RMB: Pan
			// - Mouse Wheel: Zoom at mouse
			// - WASD: Keyboard panning  
			// - PgUp/PgDn: Keyboard zoom
			// - Shift: Slower movement
			// - Home: Zoom to fit
		+/
		
		/+H2: Work Area Management+/
		/+
			Structured: // Set drawing bounds
			view.workArea = calculatedBounds; 
			
			// Automatic fitting
			if(view.autoZoom()) {
				    // View was automatically adjusted
			}
		+/
		
		/+H2: Performance Notes+/
			/+Bullet: Transformation functions are computationally expensive+/
			/+Bullet: Use /+Highlighted: animated = false+/ for performance-critical operations+/
			/+Bullet: Center correction adds per-frame overhead+/
	+/
	
	/+
		Assistant: /+
			Para: I'll analyze the View2D class usage patterns from the provided examples and categorize them
			with statistics.
		+/
		
		/+H2: View2D Usage Pattern Analysis+/
		
		/+H3: Categories of Usage Patterns:+/
		
		1. /+Bold: Property Access+/ (Most Frequent - 16 occurrences)
					/+Bullet: /+Highlighted: view.scale+/ (4 occurrences)+/
					/+Bullet: /+Highlighted: view.mousePos.vec2+/ (2 occurrences)+/
					/+Bullet: /+Highlighted: view.screenBounds_anim.bounds2+/ (3 occurrences)+/
					/+Bullet: /+Highlighted: view.invScale+/ (1 occurrence)+/
					/+Bullet: /+Highlighted: view.screenBounds_anim.bounds2.size*0+/ (1 occurrence)+/
					/+Bullet: Other general /+Highlighted: view+/ property access (5 occurrences)+/
		
		2. /+Bold: Assignment Operations+/ (4 occurrences)
					/+Bullet: /+Highlighted: view = viewWorld+/+/
					/+Bullet: /+Highlighted: view = viewGUI+/+/
					/+Bullet: /+Highlighted: view.scale = min(view.scale, maxScale)+/+/
					/+Bullet: /+Highlighted: view = items.drop(topIndex).take(pageSize).array+/+/
		
		3. /+Bold: Method Calls+/ (3 occurrences)
					/+Bullet: /+Highlighted: view.zoom(searchResults.map!(r => r.bounds).fold!"a|b", 12)+/+/
					/+Bullet: /+Highlighted: view()+/ (function call operator)+/
					/+Bullet: /+Highlighted: view to zoom home+/+/
		
		4. /+Bold: Context/Description References+/ (8 occurrences)
					/+Bullet: /+Highlighted: view, 1: GUI screen+/+/
					/+Bullet: /+Highlighted: view, T[] items+/+/
					/+Bullet: /+Highlighted: view, vec2[2] searchBezierStart+/+/
					/+Bullet: /+Highlighted: view, subCells.map!(a => cast(Node)a).array+/+/
					/+Bullet: /+Highlighted: view and a drawing+/+/
					/+Bullet: /+Highlighted: view, surface1: GUI view+/+/
					/+Bullet: /+Highlighted: view, cellFun+/+/
					/+Bullet: /+Highlighted: view space.+/+/
		
		5. /+Bold: Standalone References+/ (6 occurrences)
					/+Bullet: Simple /+Highlighted: view+/ mentions without specific operations+/
		
		/+H3: Usage Statistics:+/
		
		/+
			Structured: (表([
				[q{/+Note: Category+/},q{/+Note: Count+/},q{/+Note: Percentage+/}],
				[q{Property Access},q{16},q{43.2%}],
				[q{Context References},q{8},q{21.6%}],
				[q{Standalone References},q{6},q{16.2%}],
				[q{Assignment Operations},q{4},q{10.8%}],
				[q{Method Calls},q{3},q{8.1%}],
				[q{/+Bold: Total+/},q{/+Bold: 37+/},q{/+Bold: 100%+/}],
			]))
		+/
		
		/+H3: Most Popular Specific Usages:+/
		
		1. /+Highlighted: view.scale+/ - 4 occurrences (10.8% of total)
		2. /+Bold: General property access+/ - 5 occurrences (13.5% of total)
		3. /+Highlighted: view.screenBounds_anim.bounds2+/ - 3 occurrences (8.1% of total)
		4. /+Highlighted: view.mousePos.vec2+/ - 2 occurrences (5.4% of total)
		
		/+H3: Key Observations:+/
		
			/+
			Bullet: /+Bold: Property access is dominant+/ (43.2%), indicating View2D is primarily used for reading/viewing
			state
		+/
			/+Bullet: /+Bold: Scale manipulation+/ is the most common specific operation+/
			/+Bullet: /+Bold: Screen bounds and mouse position+/ are frequently accessed properties+/
			/+
			Bullet: /+Bold: Assignment operations+/ suggest View2D objects are used in different contexts (world vs GUI
			views)
		+/
			/+
			Bullet: /+Bold: Method usage is relatively rare+/, suggesting View2D is more of a data container than an
			active controller
		+/
		
		/+
			Para: The View2D class appears to be a viewport/camera abstraction primarily used for coordinate transformations,
			mouse interaction, and display state management in a graphical interface context.
		+/
		
		/+Note: Usage(prompt_hit: 64, prompt_miss: 569, completion: 696, HUF: 0.34, price: 100%)+/
	+/
	
	/+
		Assistant: /+H1: Draw3D API Cheat Sheet+/
		
		/+H2: Initialization+/
			/+Bullet: /+Highlighted: Draw3D d3d = new Draw3D();+/ - Create instance+/
			/+Bullet: /+Highlighted: d3d.beginFrame(screenMousePos);+/ - Start frame rendering+/
			/+Bullet: /+Highlighted: d3d.endFrame();+/ - End frame rendering+/
		
		/+H2: Camera & Navigation+/
			/+Bullet: /+Highlighted: d3d.navigate(keysEnabled, mouseEnabled)+/ - Camera control+/
			/+Bullet: /+Highlighted: d3d.cam+/ - Access camera properties+/
			/+Bullet: /+Highlighted: d3d.getCursor()+/ - Get 3D cursor position+/
		
		/+H2: Transformations+/
			/+Bullet: /+Highlighted: pushMatrix()/popMatrix()+/ - Matrix stack operations+/
			/+Bullet: /+Highlighted: translate(x, y, z)+/ - Move object+/
			/+Bullet: /+Highlighted: scale(factor)+/ - Uniform scaling+/
			/+Bullet: /+Highlighted: rotatex/rotatey/rotatez(angle)+/ - Rotation around axes+/
			/+Bullet: /+Highlighted: rotate(angle, axis)+/ - Arbitrary axis rotation+/
		
		/+H2: Rendering Primitives+/
			/+Bullet: /+Highlighted: draw(VBO vbo, color)+/ - Draw vertex buffer object+/
			/+Bullet: /+Highlighted: draw(MeshObject mesh, color)+/ - Draw mesh object+/
			/+Bullet: /+Highlighted: draw(MeshNode node, color)+/ - Draw node hierarchy+/
			/+Bullet: /+Highlighted: draw(Model model, color)+/ - Draw complete model+/
			/+Bullet: /+Highlighted: draw(LineDrawing ld)+/ - Draw lines/wireframes+/
		
		
		/+H2: Debug Features+/
		/+
			Structured: d3d.options.showWorldAxes = true; 	  // Show world coordinate axes
			d3d.options.showCameraPivot = true; 	  // Show camera pivot point
			d3d.options.showObjectAxes = true; 	  // Show object local axes
			d3d.options.showObjectBounds = true; 		// Show object bounding boxes
			d3d.options.axisLength = 250; 	  // Set	axis display length
		+/
		
		/+H2: Properties+/
			/+Bullet: /+Highlighted: d3d.viewport+/ - Current viewport dimensions+/
			/+Bullet: /+Highlighted: d3d.cursor+/ - 3D cursor information+/
			/+Bullet: /+Highlighted: d3d.pickedNode+/ - Last picked/selected node+/
			/+Bullet: /+Highlighted: d3d.screenMousePos+/ - Current mouse position+/
		
		/+H2: Shader Features+/
			/+Bullet: Built-in Phong lighting with ambient/diffuse+/
			/+Bullet: Central lighting from camera direction+/
			/+Bullet: Automatic MVP matrix calculation+/
			/+Bullet: Color blending support+/
			/+Bullet: Normal calculation for lighting+/
		
		/+H2: OpenGL State+/
			/+Bullet: Depth testing enabled+/
			/+Bullet: Face culling (CCW front faces)+/
			/+Bullet: Proper depth buffer management+/
			/+Bullet: Line width control for debug drawing+/
		
		/+H2: Usage Pattern+/
		/+
			Structured: d3d.beginFrame(mousePos); 
			d3d.navigate(true, true); 
			
			// Draw your scene
			d3d.translate(1, 2, 3); 
			d3d.draw(myModel, clWhite); 
			
			d3d.endFrame(); 
		+/
		
		/+
			Italic: Note: All coordinates are in world space. Automatic matrix management handles 
			view/projection transformations.
		+/
		
		/+Note: Usage(prompt_hit: 64, prompt_miss: 4191, completion: 585, HUF: 0.67, price: 100%)+/
	+/
}