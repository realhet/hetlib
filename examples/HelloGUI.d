//@exe
//@compile --d-version=VulkanUI
//@debug
///@release

import het.ui; 

class FrmHelloGUI: UIWindow
{
	mixin autoCreate; mixin SetupMegaShader!q{}; 
	
	override void onCreate()
	{ backgroundColor = (RGB(0x2d2d2d)); } 
	
	override void onUpdate()
	{
		if(canProcessUserInput) navigateView(!im.wantKeys, !im.wantMouse); 
		invalidate; 
		
		with(im) { Panel(PanelPosition.topLeft, { Text("Hello"); }); }
	} 
	
	override void beforeImDraw()
	{
		with(staticDr)
		{
			color = clWhite; 
			fontHeight = 100; 
			textOut(vec2(0), "Hello"); 
		}
	} 
} 