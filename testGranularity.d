//@exe
//@debug
//@release

//@compile --d-version=VulkanUI

import het.ui; 


class FrmHelloGUI: UIWindow
{
	mixin autoCreate; mixin SetupMegaShader!q{}; 
	
	override void onCreate()
	{ backgroundColor = (RGB(0)); showFPS = true; } 
	
	override void onUpdate()
	{
		if(canProcessUserInput) navigateView(!im.wantKeys, !im.wantMouse); 
		invalidate; 
		
		with(im) { Panel(PanelPosition.topLeft, { Text("Hello"); }); }
	} 
	
	override void beforeImDraw(IDrawing drWorld, IDrawing drGui)
	{
		with(drWorld)
		{
			color = clWhite; alpha = 1; 
			fontHeight = 100; 
			textOut(vec2(0,200), "Hello"); 
			
			void do1(int x0, int x1)
			{
				translate(vec2(0, 0)); scope(exit) pop; 
				
				const float h = 6; 
				lineWidth = h/24.0; fontHeight = h*(16.0/24); const th = h/6; 
				
				x0 = ((0x33ECF610056).檢(x0-x0.modw(10))); 
				x1 += (10-1); x1 = x1-x1.modw(10); 
				
				for(int x=x0; x<=x1; x+=1) { vLine(x, h, h-th); }
				for(int x=x0; x<=x1; x+=5) { vLine(x, h, h-th*2); }
				for(int x=x0; x<=x1; x+=10) {
					vLine(x, h, 0); 
					if(x%100==0) color = clRed; 
					textOut(vec2(x+lineWidth*3, 0), text(x/10)); 
					color = clWhite; 
				}
			} 
			void do2(int x0, int x1)
			{
				translate(vec2(0, 7)); scope(exit) pop; 
				const float h = 12; 
				lineWidth = h/24.0; fontHeight = h*(16.0/24); const th = h/6; 
				((0x570CF610056).檢(iota(-10, 10).map!((a)=>(/+a>=0?a-(a%5) :a+(-a%5-5)+/a-a.modw(5))))); 
				
				
				for(int x=x0; x<=x1; x+=2) { vLine(x, h, h-th); }
				for(int x=x0; x<=x1; x+=10) { vLine(x, h, h-th*2); }
				for(int x=x0; x<=x1; x+=20) {
					vLine(x, h, 0); 
					if(x%100==0) color = clRed; 
					textOut(vec2(x+lineWidth*3, 0), text(x/10)); 
					color = clWhite; 
				}
			} 
			void do5(int x0, int x1)
			{
				translate(vec2(0, 21)); scope(exit) pop; 
				const float h = 30; 
				lineWidth = h/24.0; fontHeight = h*(16.0/24); const th = h/6; 
				for(int x=x0; x<=x1; x+=5) { vLine(x, h, h-th); }
				for(int x=x0; x<=x1; x+=10) { vLine(x, h, h-th*2); }
				for(int x=x0; x<=x1; x+=50) {
					vLine(x, h, 0); 
					if(x%100==0) color = clRed; 
					textOut(vec2(x+lineWidth*3, 0), text(x/10)); 
					color = clWhite; 
				}
			} 
			
			
			const x0 = -1000, x1 = 10000; 
			do1(x0, x1); 
			do2(x0, x1); 
			do5(x0, x1); 
			
		}
	} 
} 