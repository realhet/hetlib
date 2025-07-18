
//@exe
//@debug
///@release

import het.ui; 

class FrmHelloGUI: GLWindow
{
	mixin autoCreate; 
	
	override void onCreate()
	{} 
	
	override void onUpdate()
	{
		view.navigate(!im.wantKeys, !im.wantMouse); 
		invalidate; 
		
		with(im)
		{ Panel(PanelPosition.topLeft, { Text("Hello"); }); }
		
	} 
	
	override void onPaint()
	{
		gl.clearColor(RGB(0x2d2d2d)); gl.clear(GL_COLOR_BUFFER_BIT); 
		
		{
			auto dr = new Drawing; scope(exit) dr.glDraw(view); 
			
			//draw something
			dr.textOut(0, 0, "Hello"); 
		}
	} 
} 
