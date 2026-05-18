//@exe
//@debug
//@/release

//@compile --d-version=VulkanUI

import het.ui, het.ui_ruler; 

class FrmHelloGUI: UIWindow
{
	mixin autoCreate; mixin SetupMegaShader!q{}; 
	
	float param1 = 0, param2 = 0; 
	
	enum TestCase { off, test0, test1 } TestCase testCase; 
	
	
	override void onCreate()
	{
		//dumpDateTimeIteratorStats; 
		backgroundColor = (RGB(0)); showFPS = true; 
	} 
	
	override void onUpdate()
	{
		if(canProcessUserInput) navigateView(!im.wantKeys, !im.wantMouse); 
		invalidate; 
		
		with(im) {
			Panel(
				PanelPosition.topLeft, 
				{
					Row({ Text("param1"); Slider(param1, range(0, 1), { width = clientWidth-100; } ); }); 
					Row({ Text("TestCases"); BtnRow(testCase); }); 
					Row({ Text("param2"); Slider(param2, range(-1, 1), { width = clientWidth-100; } ); }); 
				}
			); 
		}
	} 
	
	override void beforeImDraw(IDrawing drWorld, IDrawing drGui)
	{
		with(drWorld)
		{
			color = clWhite; alpha = 1; 
			//fontHeight = 100; 
			//textOut(vec2(0,-100), "Hello"); 
			
			const ramp = 0.875 + sin(2*π*time.value(120*second))*0.0000125     *0.01  -.155; 
			if(1)
			{
				const i = (((0)?(param1*2):(cos(2*π*time.value(180*second))+1)))*32; 
				auto 	h = ulong.max/2,  n = (cast(ulong)(h * pow(ramp, i*2))).min(h),
					st = RawDateTime(h-n), en = RawDateTime(h+n+1); 
				
				st += param2 * day; 
				
				const bnd = bounds2(vec2(50, 0), ((vec2(clientWidth, 48*2)).名!q{size})); 
				
				drawHRuler(drWorld, bnd, st, en); 
			}
		}
	} 
} 