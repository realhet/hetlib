//@exe
//@debug
///@release

//@compile --d-version=VulkanUI

import het.ui; 

static void drawHRuler(IDrawing dr, bounds2 bnd, DateTime start, DateTime end)
{
	enum lineWidthScale	= 1.5f,
	clMajorTick 	= clBlue/+(RGB(0x202020))+/,
	clText 	= (RGB(0x000000)); 
	
	if(start>=end) return; 
	const h = bnd.height; if(h<=0) return; 
	const 	lw = h/24, 	//lineWidth;
		fh = h*(16.0f/24), 	//fontHeight
		th = h/6 	/+tickHeigh+/; 
	
	const sc = (float(((bnd.width)/(end.raw-start.raw)))); 
	float tr(DateTime dt)
	=> ((dt.raw>=start.raw)?( (float(dt.raw-start.raw))*sc) :(-(float(start.raw-dt.raw))*sc))+bnd.left; 
	
	dr.lineWidth = lw * lineWidthScale, dr.fontHeight = fh; 
	dr.color = clWhite; dr.fillRect(bnd); 
	
	void drawTick(float x, int size/+1..6+/)
	{ dr.vLine(x, bnd.bottom-size*th, bnd.bottom); } 
	
	
	const 	fullSpan 	= end-start; 
	
	auto targetLabelSpan(float chars)
	{
		const targetLabelWidth 	= fh*(9/16.0)*chars+6*lw, 
		targetLabelCount 	= (bnd.width/targetLabelWidth).max(1),
		targetLabelSpan 	= fullSpan/targetLabelCount; 
		return targetLabelSpan; 
	} 
	
	T quantize(T)(T m, int q=1)
	=> 
	((q>1)?((cast(T)((double(m)).stdQuantize!floor(q)))):(m)); 
	auto extremeDateTime(int year)
	=> RawDateTime(((year<2000)?(0):(ulong.max))); 
	
	uint monthStep; 
	{
		const float target = ((targetLabelSpan(4+3))/(gregorianDaysInMonth * day)); 
		foreach(step; [1, 2, 3, 6])
		{ if(target < step) { monthStep = step; break; }}
	}
	
	uint yearStep; 
	if(!monthStep)
	{
		const float target = ((targetLabelSpan(4))/(gregorianDaysInYear * day)); 
		foreach(step; [1, 2, 5, 10, 20, 50, 100, 200, 500, 1000])
		{ if(target < step) { yearStep = step; break; }}
	}
	
	if(monthStep)
	{
		int toLocalYearMonth(DateTime dt)
		{
			const 	st = dt.localSystemTime_fullRange,
				y = st.wYear,  m = st.wMonth-1 /+0 based!+/; 
			return y*12 + quantize(m, monthStep); 
		} 
		
		const 	startYM 	= toLocalYearMonth(start),
			endYM 	= toLocalYearMonth(end); 
		
		const t = iota(startYM, endYM+monthStep+1, monthStep)
			.map!((ym){
			const y = ym/12, m = (ym%12)+1; 
			return DateTime(Local, y, m, 1)
			.ifThrown(extremeDateTime(y)); 
		})	.array; 
		
		if(t.length>=2)
		{
			auto p = t.map!((dt)=>(tr(dt))).array; 
			
			if(t.length>=3 /+extrapolate both ends+/)
			{
				void extend(size_t a, size_t b, size_t c)
				{
					const newc = p[a] + (p[b]-p[a])*2; 
					if((p[c] < newc)==(p[c] > p[b])) p[c] = newc; 
				} 
				if(t[0].raw==0) { extend(2, 1, 0); }
				if(t[$-1].raw==ulong.max) {
					const len = t.length; 
					extend(len-3, len-2, len-1); 
				}
			}
			
			dr.color = clMajorTick; foreach(x; p) drawTick(x, 6); 
			
			dr.color = clText; foreach(i; 0..t.length-1)
			{
				const 	ym = startYM+i*monthStep, 
					y = ym/12, m = ym%12; 
				
				dr.textOut(
					vec2(p[i]+lw*3, bnd.top), 
					text(y)~'.'~monthStep.predSwitch
					(
						3, format!"Q%d"(m/3+1),
						6, format!"H%d"(m/6+1),
						format!"%02d"(m+1),
					)
				); 
			}
		}
	}
	
	if(yearStep)
	{
		int toLocalYear(DateTime dt)
		{
			const y = dt.localSystemTime_fullRange.wYear; 
			return quantize(y, yearStep); 
		} 
		
		const 	startYear 	= toLocalYear(start),
			endYear 	= toLocalYear(end); 
		
		const t = iota(startYear, endYear+yearStep+1, yearStep)
			.map!((y)=>(
			DateTime(Local, y, 1, 1)
			.ifThrown(extremeDateTime(y))
		))	.array; 
		
		if(t.length>=2)
		{
			auto p = t.map!((dt)=>(tr(dt))).array; 
			
			if(t.length>=3 /+extrapolate both ends+/)
			{
				void extend(size_t a, size_t b, size_t c)
				{
					const newc = p[a] + (p[b]-p[a])*2; 
					if((p[c] < newc)==(p[c] > p[b])) p[c] = newc; 
				} 
				if(t[0].raw==0) { extend(2, 1, 0); }
				if(t[$-1].raw==ulong.max) {
					const len = t.length; 
					extend(len-3, len-2, len-1); 
				}
			}
			
			dr.color = clMajorTick; foreach(x; p) drawTick(x, 6); 
			
			dr.color = clText; foreach(i; 0..t.length-1)
			{
				dr.textOut(
					vec2(p[i]+lw*3, bnd.top), 
					text(startYear+i*yearStep)
				); 
			}
		}
	}
} 


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
			textOut(vec2(0,-100), "Hello"); 
			
			
			foreach(i; 0..100)
			{
				static if(0)
				const 	h = ulong.max/2,  n = (cast(ulong)(h * pow(0.75, i))).min(h),
					st = RawDateTime(h-n), en = RawDateTime(h+n+1); 
				
				static if(1)
				const st = RawDateTime(0), en = RawDateTime((cast(ulong)((ulong.max * pow(0.75, i)).min(ulong.max)))); 
				
				drawHRuler(drWorld, bounds2(vec2(50, 10+26*i), ((vec2(clientWidth, 24)).名!q{size})), st, en); 
			}
			
			void do1(int x0, int x1)
			{
				translate(vec2(0, 0)); scope(exit) pop; 
				
				const float h = 6; 
				lineWidth = h/24.0; fontHeight = h*(16.0/24); const th = h/6; 
				
				x0 = x0-x0.modw(10); 
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
			//do1(x0, x1); 
			//do2(x0, x1); 
			//do5(x0, x1); 
			
		}
	} 
} 