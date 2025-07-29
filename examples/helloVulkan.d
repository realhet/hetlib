//@exe
//@debug
///@release

import het.vulkanwin; 

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
			auto verts = polyLineToTriangleStrip(pathPoints, (互!((float/+w=6+/),(0.128),(0x9675F5C4644)))*300); 
			
			int i; 
			foreach(v; verts.take((0x9C75F5C4644).檢((iround(verts.length*(互!((float/+w=6+/),(1.000),(0x9F15F5C4644))))).max(1))))
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
	
	
}
class FrmHelloVulkan : VulkanWindow
{
	mixin autoCreate;  
	
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
	]; 
	
	
	Texture[] textures; 
	
	Texture egaPalette, c64Palette, vgaPalette, hiresSprite, multiSprite; 
	
	override void onCreate()
	{
		windowBounds = ibounds2(1280, 0, 1920, 600); 
		(clAll.length).print; 
		if(1)
		{
			console.hide; 
			
			egaPalette = new Texture(TexFormat.rgba_u8, 16, EGAPalette); 
			c64Palette = new Texture(TexFormat.rgba_u8, 16, C64Palette); 
			vgaPalette = new Texture(TexFormat.rgb_u8, 256, VGAPalette); 
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
			
			if(1)
			{
				
				
				//bitmaps[`c:\dl\catacomb 3D wall.png`.File].get!RGB.; 
			}
			
		}
		
	} 
	
	override void onDestroy() {} 
	
	
	override void onUpdate()
	{
		if(KeyCombo("Ctrl+F2").pressed) application.exit; 
		if(PERIODIC(1*second)) caption = FPS.text ~ " " ~ UPS.text; 
		
		foreach(y; 0..8)
		foreach(x; 0..8)
		{ dr.rect((bounds2(0, 0, 1-0.125, 1-0.125)+vec2(x, y))*64, TexHandle((y*8+x)%16+1)), RGBA(0xFFFF8000); }
		
		
		if(KeyCombo("F1").pressed) { textures.each!free; textures.clear; }
	} 
} 