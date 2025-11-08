//@exe
//@debug
//@release

//@compile -d-version=VulkanUI

import het.ui; 

class FrmTestVulkanUI : UIWindow
{
	mixin autoCreate; mixin SetupMegaShader!q{}; 
	
	override void onCreate()
	{ windowBounds = ibounds2(1280, 0, 1920, 600); } 
	
	override void onDestroy() {} 
	
	override void onUpdate()
	{
		if(KeyCombo("Ctrl+F2").pressed) application.exit; 
		if(PERIODIC(1*second)) caption = FPS.text ~ " " ~ UPS.text; 
		
		mixin(同!(q{float/+w=2.5 h=2.5 min=0.125 max=16 newLine=1 sameBk=1 rulerSides=1 rulerDiv0=11+/},q{guiScale},q{0x1C349493B0B})); 
		with(im)
		{
			Panel(
				PanelPosition.topClient, 
				{
					static bool flag; static str = "Edit me!"; static val = .5; 
					foreach(i; 0..2)
					{
						Column(
							((i).名!q{id}),
							{
								if(Btn("Press me!")) flag.toggle; 
								ChkBox(flag, "Check me!"); 
								Edit(str); 
								Slider(val, range(0, 1)); 
								Row(
									{
										Text(`🤓`); Img(File(`icon:\.exe`)); 
										
										void customDraw(int i)
										{
											addDrawCallback(
												((IDrawing dr, .Container cntr) {
													dr.color = clBlue; dr.fontHeight = 16; 
													dr.textOut(vec2(40, 0), "Hello"~i.text); 
												})
											); 
										} 
										customDraw(i); 
									}
								); 
							}
						); 
					}
					resourceMonitor.UI(innerWidth-16); 
				}
			); 
		}
	} 
} 