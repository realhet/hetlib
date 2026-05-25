//@exe
//@debug
///@release

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
				PanelPosition.topClient, 
				{
					Row({ flags.wordWrap=false; Text("param1"); Slider(param1, range(0, 1), { width = clientWidth-100; } ); }); 
					Row({ flags.wordWrap=false; Text("TestCases"); BtnRow(testCase); }); 
					Row({ flags.wordWrap=false; Text("param2"); Slider(param2, range(-1, 1), { width = clientWidth-100; } ); }); 
				}
			); 
		}
		with(im) {
			Panel(
				PanelPosition.leftClient, 
				{
					outerSize.x = fh*30; 
					Text("Grafikon címke oszlop"); 
				}
			); 
		}
		with(im) {
			Panel(
				PanelPosition.rightClient, 
				{
					outerSize.x = fh*30; 
					Text("Projektek, Munkalapok"); 
				}
			); 
		}
		with(im) {
			Panel(
				PanelPosition.topClient, 
				{
					padding = "1 1 1 0"; /+bkColor = (RGB(0xFFCCDD)); +/
					
					static DateTime t0_outer, t1_outer, t0, t1; 
					if(!t1_outer) {
						t0_outer = DateTime(2026, 1, 1), 
						t1_outer = DateTime(2026, 12, 31, 23, 59, 59, 999); 
					}
					
					mixin(
						ONCE(
							q{
								t0 = now, 
								t1 = t0 + ((2+sin((now-today).value(((10)*(second))) * ((2)*(π))))*(2*day)) * 5; 
							}
						)
					); 
					
					
					HRuler(t0_outer, t1_outer, t0, t1, {}); 
				}
			); 
		}
		
		foreach(capt; ["gép1", "gép2", "gép3", "összes gép"])
		with(im) {
			Panel(
				PanelPosition.topClient, 
				{
					Container(
						{
							height = 4*fh; 
							Row({ Text(capt); }); 
						}
					); 
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