//@exe
//@debug
//@release

//@compile --d-version=VulkanUI

import het.ui; 

auto extremeDateTime(int year)
=> RawDateTime(((year<2000)?(0):(ulong.max))); 

struct PackedDateTime
{
	ushort year; 
	ubyte month, day, hour, minute, second, hsec; 
	this(int year, int month, int day)
	{
		this.year 	= (cast(ushort)(year)),
		this.month 	= (cast(ubyte)(month)),
		this.day 	= (cast(ubyte)(day)); 
	} 
	this(
		int year, int month, int day, 
		int hour, int minute=0, int second=0, int hsec=0
	)
	{
		this(year, month, day); 
		this.hour 	= (cast(ubyte)(hour)),
		this.minute 	= (cast(ubyte)(minute)),
		this.second 	= (cast(ubyte)(second)),
		this.hsec 	= (cast(ubyte)(hsec)); 
	} 
} 


DateTime localDateTime(PackedDateTime dt)
=> DateTime(Local, dt.year, dt.month, dt.day)
.ifThrown(extremeDateTime(dt.year)); 

alias cachedLocalDateTime = memoize!localDateTime; 

DateTime cachedLocalDateTime(int year, int month=1, int day=1)
=> cachedLocalDateTime(PackedDateTime(year, month, day)); 

private T quantize(T)(T m, uint q=1)
=> 
((q>1)?((cast(T)((double(m)).stdQuantize!floor(q)))):(m)); 

template YearIterator()
{
	uint init(DateTime dt, uint yearStep)
	{
		const y = dt.localSystemTime_fullRange.wYear; 
		return quantize(y, yearStep); 
	} 
	
	void inc(ref uint y, uint yearStep)
	{ y += yearStep; } 
	
	DateTime dt(uint y)
	=> cachedLocalDateTime(y); 
	
	string str(uint y, uint yearStep)
	=> y.text; 
} 

template YearMonthIterator()
{
	uint init(DateTime dt, uint monthStep)
	{
		const 	st = dt.localSystemTime_fullRange,
			y = st.wYear,  m = st.wMonth-1; 
		return y*12 + quantize(m, monthStep); 
	} 
	
	enum decodeYM = q{const y = ym/12, m = (ym%12)+1; }; 
	
	void inc(ref uint ym, uint monthStep)
	{ ym += monthStep; } 
	
	DateTime dt(uint ym)
	{ mixin(decodeYM); return cachedLocalDateTime(y, m); } 
	
	string str(uint ym, uint monthStep)
	{
		mixin(decodeYM); 
		return y.text~monthStep.predSwitch
		(
			3, format!" Q%d"((m-1)/3+1),
			6, format!" H%d"((m-1)/6+1),
			/+format!".%02d"(m)+/
			' '~MonthNames[m-1]
		); 
	} 
} 

template YearMonthDayIterator()
{
	uint init(DateTime dt, uint dayStep)
	{
		const 	st = dt.localSystemTime_fullRange,
			y = st.wYear,  m = st.wMonth-1, d = st.wDay-1; 
		return (y*16 + m)*32 + quantize(d, dayStep)+1; 
	} 
	
	enum decodeYMD = q{
		uint 	ym 	= ymd / 32, 	d 	= ymd % 32,
			y 	= ym / 16, 	m 	= ym % 16 + 1; 
	}; 
	
	void inc(ref uint ymd, uint dayStep)
	{
		mixin(decodeYMD); 
		int daysInMonth_fast() 
		=> monthDays[m-1];  int daysInMonth_precise() 
		=> daysInMonth_fast + (cast(uint)((m==2 && isLeapYear(y)))); 
		
		void nextMonth() { if(m>=12)	{ y++; m=1; }	else	m++; d=1; } 
		
		switch(dayStep)
		{
			case 1: 	{ d+=dayStep; if(d>daysInMonth_precise) nextMonth; }	break; 
			case 2: 	{ d+=dayStep; if((m==2 && d>27) || d>29) nextMonth; }	break; 
			case 3: 	{ d+=dayStep; if((m==2 && d>25) || d>28) nextMonth; }	break; 
			default: 	{ d = ((d==1)?(0):(d))+dayStep; if(d>25) nextMonth; }	break; 
		}
		
		ymd = (y*16 + m-1)*32 + d; 
	} 
	
	DateTime dt(uint ymd)
	{ mixin(decodeYMD); return cachedLocalDateTime(y, m, d); } 
	
	string str(uint ymd, uint dayStep)
	{
		mixin(decodeYMD); return /+format!"%d.%02d.%02d"(y, m, d)+/
		format!"%d %s %d"(y, MonthNames[m-1], d); 
	} 
} 

template HourIterator()
{
	/+
		Todo: Itt tartok!!!!!!!!!!!!!!!!!!!
		
		
		
		
		
		
		
		
		
		
		
		
		
		
		
		
		
		
		
		
		
	+/
	
	
	DateTime init(DateTime dt, uint hourStep)
	{
		
		
		const h = dt.localSystemTime_fullRange.wHour; 
		return quantize(h, hourStep); 
	} 
	
	void inc(ref uint h, uint hourStep)
	{ h += hourStep; } 
	
	DateTime dt(uint y)
	=> cachedLocalDateTime(y); 
	
	string str(uint y, uint yearStep)
	=> y.text; 
} 

void testYMD()
{
	alias ITER = YearMonthDayIterator!(); 
	foreach(step; [1, 2, 3, 5, 10, 15])
	{
		print!step; 
		auto state = ITER.init(RawDateTime(0), step); 
		DateTime prev; 
		size_t[ulong] diffHist; 
		foreach(i; 0..int.max)
		{
			const act = ITER.dt(state); 
			const ulong diff = act.raw-prev.raw; 
			
			if(i>0) diffHist[diff]++; 
			if(0)
			print(
				i.format!"%6d", state, ITER.str(state, step), 
				format!"%12.2f"((double(act.raw))/DateTime.RawUnit.day), 
				format!"%12.2f"((double(diff))/DateTime.RawUnit.day), 
				act.raw.format!"%016X", 
				(diff).format!"%16X", 
				ITER.dt(state).utcText
			); 
			
			ITER.inc(state, step); 
			if(act.raw==ulong.max) break; 
			prev = act; 
		}
		foreach(k; diffHist.keys.sort)
		print(
			diffHist[k].format!"%6d x", k.format!"%16X", 
			((double(k))/DateTime.RawUnit.day).format!"%18.12f"
		); 
	}
} 


mixin((
	(表([
		[q{/+Note: DateTimeGranularity : ubyte+/},q{/+Note: Steps+/},q{/+Note: AvgTime+/},q{/+Note: NumChars+/}],
		[q{year},q{[1, 2, 5, 10, 20, 50, 100, 500, 1000]},q{gregorianDaysInYear*day},q{5}],
		[q{month},q{[1, 2, 3, 6]},q{gregorianDaysInMonth*day},q{8}],
		[q{day},q{[1, 2, 3, 5, 10, 15]},q{day},q{11}],
		[q{hour},q{[1, 2, 3, 6, 12]},q{hour},q{11+3}],
		[q{minute},q{[1, 2, 5, 10, 15, 20, 30]},q{minute},q{11+6}],
		[q{second},q{[1, 2, 5, 10, 15, 20, 30]},q{second},q{3}],
		[q{millisecond},q{[1, 2, 5, 10, 20, 50, 100, 500]},q{milli(second)},q{4}],
		[q{microsecond},q{[1, 2, 5, 10, 20, 50, 100, 500]},q{micro(second)},q{4}],
		[q{nanosecond},q{[1, 2, 5, 10, 20, 50, 100, 500]},q{nano(second)},q{4}],
		[q{yearWeek},q{[1, 2, 4, 8, 12, 21]},q{7*day},q{4}],
		[q{yearWeek_iso},q{[1, 2, 4, 8, 12, 21]},q{7*day},q{4}],
		[q{yearDay},q{[1, 2, 3, 7, 14, 28, 56, 91, 182]},q{day},q{4}],
	]))
).調!(GEN_enumTable)); 

struct DateTimeGranularities
{
	private alias _ = DateTimeGranularity; 
	static immutable
		yearMonthDay 	= [_.year, _.month, _.day],
		yearWeek 	= [_.year, _.yearWeek],
		yearWeek_iso 	= [_.year, _.yearWeek_iso],
		yearDay 	= [_.year, _.yearDay],
			
		hourMin	= [_.hour, _.minute],
		hourMinSec	= hourMin ~ _.second,
			
		subSecond	= [_.millisecond, _.microsecond, _.nanosecond],
			
		full	= yearMonthDay 	~ hourMinSec ~ subSecond,
		full_weeks	= yearWeek 	~ hourMinSec ~ subSecond,
		full_isoWeeks	= yearWeek_iso 	~ hourMinSec ~ subSecond,
		
		
		test = [_.year, _.month, _.day, _.hour]; 
} 


struct DateTimeIteratedRange
{
	DateTime t0, t1; 
	float p0=0, p1=0; 
	string label; 
	uint internalIndex; 
	DateTimeGranularity granularity; 
	ushort step; bool isFirst; 
} 

auto iterateLocalDateTimeRanges(
	DateTime start, DateTime end, 
	float left, float right, float avgCharWidth,
	in DateTimeGranularity[] granularities,
	void delegate(ref DateTimeIteratedRange) callback, 
	bool noLabel=false
)
{
	if(start>=end) return; 
	if(left>=right) return; 
	
	DateTimeIteratedRange state; 
	
	
	const Time 	fullSpan 	= end - start,
		charTime 	= ((fullSpan * avgCharWidth)/(right - left)); 
	
	const trScale = ((right - left)/((float(end.raw - start.raw)))); 
	float tr(DateTime dt)
	=> ((dt.raw>=start.raw)?( (float(dt.raw - start.raw)) * trScale) :(-(float(start.raw - dt.raw)) * trScale)) + left; 
	
	float avgSize=0; 
	findGranularity: 
	foreach(gr; granularities.retro)
	{
		const avgTime = dateTimeGranularityAvgTime[gr]; 
		const numChars = dateTimeGranularityNumChars[gr]; 
		const float target = numChars * ((charTime)/(avgTime)); 
		foreach(step; dateTimeGranularitySteps[gr])
		{
			if(target < step) {
				state.granularity 	= gr, 
				state.step 	= step.to!ushort; 
				avgSize = step * avgTime.value(second) * 
					DateTime.RawUnit.sec * trScale; 
				break findGranularity; 
			}
		}
	}
	
	if(state.step)
	{
		void iterate(alias ITER)()
		{
			with(ITER)
			with(state)
			{
				version(/+$DIDE_REGION Fetch first boundary+/all)
				{
					auto idx = init(start, step); 
					t0 = dt(idx); p0 = tr(t0); 
				}
				
				if(t0<end)
				{
					
					
					label = str(idx, step); 
					
					version(/+$DIDE_REGION Fetch second boundary+/all)
					{
						inc(idx, step); 
						t1 = dt(idx); p1 = tr(t1); 
					}
					
					if(t0.raw==0)
					{ p0.minimize(p1-avgSize); }
					
					isFirst = true; callback(state); 
					isFirst = false; 
					
					version(/+$DIDE_REGION Shift+/all)
					{ t0 = t1, p0 = p1; }
					while(t0<end)
					{
						label = str(idx, step); 
						
						version(/+$DIDE_REGION Fetch next+/all)
						{
							inc(idx, step); 
							t1 = dt(idx); p1 = tr(t1); 
						}
						
						if(t1.raw==ulong.max)
						p1.maximize(p0+avgSize); 
						
						callback(state); 
						
						
						
						version(/+$DIDE_REGION Shift+/all)
						{ t0 = t1, p0 = p1; }
					}
				}
			}
		} 
		switch(state.granularity)
		{
			case DateTimeGranularity.year: 	iterate!(YearIterator!()); 	break; 
			case DateTimeGranularity.month: 	iterate!(YearMonthIterator!()); 	break; 
			case DateTimeGranularity.day: 	iterate!(YearMonthDayIterator!()); 	break; 
			
			default: 
		}
	}
	
} 

static void drawHRuler(IDrawing dr, bounds2 bnd, DateTime start, DateTime end)
{
	enum lineWidthScale	= 1.5f,
	clMajorTick 	= clBlue/+(RGB(0x202020))+/,
	clText 	= (RGB(0x000000)); 
	
	if(start>=end || bnd.empty) return; 
	const float 	h = bnd.height,
		lw = h/24, 	//lineWidth;
		fh = h*(16.0f/24), 	//fontHeight
		th = h/6,	/+tickHeigh+/
		avgCharWidth = fh * 9.0f/16,
		totalChars = bnd.width / avgCharWidth; 
	
	const sc = (float(((bnd.width)/(end.raw-start.raw)))); 
	float tr(DateTime dt)
	=> ((dt.raw>=start.raw)?( (float(dt.raw-start.raw))*sc) :(-(float(start.raw-dt.raw))*sc))+bnd.left; 
	
	dr.lineWidth = lw * lineWidthScale, dr.fontHeight = fh; 
	dr.color = clWhite; dr.fillRect(bnd); 
	
	void drawTick(float x, int size/+1..6+/)
	{ dr.vLine(x, bnd.bottom-size*th, bnd.bottom); } 
	
	
	const fullSpan 	= end-start; 
	
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
	
	auto evalMonthBoundaries(int monthStep, out int startYM)
	{
		int toLocalYearMonth(DateTime dt)
		{
			const 	st = dt.localSystemTime_fullRange,
				y = st.wYear,  m = st.wMonth-1 /+0 based!+/; 
			return y*12 + quantize(m, monthStep); 
		} 
		
		startYM = toLocalYearMonth(start); 
		const endYM = toLocalYearMonth(end); 
		
		return iota(startYM, endYM+monthStep+1, monthStep)
			.map!((ym){
			const y = ym/12, m = (ym%12)+1; 
			return cachedLocalDateTime(y, m); 
		})	.array; 
	}  auto evalYearBoundaries(int yearStep, out int startYear)
	{
		int toLocalYear(DateTime dt)
		{
			const y = dt.localSystemTime_fullRange.wYear; 
			return quantize(y, yearStep); 
		} 
		
		startYear = toLocalYear(start); 
		const endYear 	= toLocalYear(end); 
		
		return iota(startYear, endYear+yearStep+1, yearStep)
			.map!((y)=>(cachedLocalDateTime(y)))	.array; 
	} 
	
	void extrapolateEnds(in DateTime[] t, ref float[] p)
	{
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
	} 
	
	if(!inputs.Shift.down)
	iterateLocalDateTimeRanges(
		start, end, bnd.left, bnd.right, avgCharWidth, DateTimeGranularities.yearMonthDay, 
		((a){
			dr.color = clMajorTick; if(a.isFirst) drawTick(a.p0, 6); drawTick(a.p1, 6); 
			dr.color = clText; dr.textOut(vec2(a.p0+lw*3, bnd.top), a.label); 
		})
	); 
	
	if(inputs.Shift.down)
	{
		uint dayStep; 
		{
			const float target = ((targetLabelSpan(3))/(day)); 
			foreach(step; [1, 2, 5, 10, 15])
			{ if(target < step) { dayStep = step; break; }}
		}
		
		if(dayStep)
		{
			int startYM; 
			const tMonths = evalMonthBoundaries(1, startYM); 
			
			
			
			goto done; 
		}
		
		uint monthStep; 
		{
			const float target = ((targetLabelSpan(4+4))/(gregorianDaysInMonth * day)); 
			foreach(step; [1, 2, 3, 6])
			{ if(target < step) { monthStep = step; break; }}
		}
		
		if(monthStep)
		{
			int startYM; 
			const t = evalMonthBoundaries(monthStep, startYM); 
			if(t.length>=2)
			{
				auto p = t.map!((dt)=>(tr(dt))).array; 
				extrapolateEnds(t, p); 
				
				dr.color = clMajorTick; foreach(x; p) drawTick(x, 6); 
				
				dr.color = clText; 
				foreach(i; 0..t.length-1)
				{
					const 	ym = startYM+i*monthStep, 
						y = ym/12, m = ym%12; 
					const s = y.text~'.'~monthStep.predSwitch
						(
						3, format!"Q%d"(m/3+1),
						6, format!"H%d"(m/6+1),
						/+format!"%02d"(m+1)+/
						MonthNames[m]
					); 
					dr.textOut(vec2(p[i]+lw*3, bnd.top), s); 
				}
			}
			
			goto done; 
		}
		
		uint yearStep; 
		
		Time charTime = fullSpan * avgCharWidth / bnd.width; 
		{
			const float target = 5/+chars+/ * ((charTime)/(gregorianDaysInYear * day)); 
			foreach(step; [1, 2, 5, 10, 20, 50, 100, 200, 500, 1000])
			{ if(target < step) { yearStep = step; break; }}
		}
		
		if(yearStep)
		{
			int startY; const t = evalYearBoundaries(yearStep, startY); 
			
			if(t.length>=2)
			{
				auto p = t.map!((dt)=>(tr(dt))).array; 
				extrapolateEnds(t, p); 
				
				dr.color = clMajorTick; foreach(x; p) drawTick(x, 6); 
				
				dr.color = clText; 
				foreach(i; 0..t.length-1)
				{
					dr.textOut(
						vec2(p[i]+lw*3, bnd.top), 
						text(startY+i*yearStep)
					); 
				}
			}
			
			goto done; 
		}
	}
	done: 
} 

class FrmHelloGUI: UIWindow
{
	mixin autoCreate; mixin SetupMegaShader!q{}; 
	
	override void onCreate()
	{
		testYMD; 
		backgroundColor = (RGB(0)); showFPS = true; 
	} 
	
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
			
			
			const ramp = 0.875 + sin(2*π*time.value(20*second))*0.125     *1; 
			foreach(i; 0..100)
			{
				static if(0)
				const 	h = ulong.max/2,  n = (cast(ulong)(h * pow(ramp, i))).min(h),
					st = RawDateTime(h-n), en = RawDateTime(h+n+1); 
				
				static if(1)
				const st = RawDateTime(0), en = RawDateTime((cast(ulong)((ulong.max * pow(ramp, i)).min(ulong.max)))); 
				
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