//@exe
//@debug
//@release

//@compile --d-version=VulkanUI

import het.ui; 

private
{
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
} 

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

template HourIterator()
{
	enum unit = DateTime.RawUnit.hour; 
	
	void adjust(ref long raw, uint hourStep)
	{
		if(raw<=hourStep || hourStep<=1) return; 
		
		foreach(i; 0..hourStep-1)
		{
			const h = dt(raw).localSystemTime.wHour; 
			if(h%hourStep==0) break; 
			raw++; 
		}
	} 
	
	long init(DateTime dt, uint hourStep)
	{
		long raw = dt.raw / unit % hourStep; 
		
		raw -= hourStep-1; 
		adjust(raw, hourStep); 
		return raw; 
	} 
	
	void inc(ref long raw, uint hourStep)
	{
		raw += hourStep; 
		adjust(raw, hourStep); 
	} 
	
	DateTime dt(long raw)
	{
		if(raw<=0) return RawDateTime(0); 
		if(raw>=ulong.max/unit) return RawDateTime(ulong.max); 
		return RawDateTime((cast(ulong)(raw)) * unit); 
	} 
	
	string str(long raw, uint hourStep)
	{
		const h = dt(raw).localSystemTime.wHour; 
		return h.format!"%02d:"; 
	} 
} 

template HourMinuteIterator()
{
	enum unit = DateTime.RawUnit.min; 
	
	long init(DateTime dt, uint minuteStep)
	=> dt.raw / unit % minuteStep; 
	
	void inc(ref long raw, uint minuteStep)
	{ raw += minuteStep; } 
	
	DateTime dt(long raw)
	{
		if(raw>=ulong.max/unit) return RawDateTime(ulong.max); 
		return RawDateTime((cast(ulong)(raw))*unit); 
	} 
	
	string str(long raw, uint minuteStep)
	{
		with(dt(raw).localSystemTime)
		return format!"%02d:%02d"(wHour, wMinute); 
	} 
} 

template HourMinuteSecondIterator()
{
	enum unit = DateTime.RawUnit.sec; 
	
	long init(DateTime dt, uint secondStep)
	=> dt.raw / unit % secondStep; 
	
	void inc(ref long raw, uint secondStep)
	{ raw += secondStep; } 
	
	DateTime dt(long raw)
	{
		if(raw>=ulong.max/unit) return RawDateTime(ulong.max); 
		return RawDateTime((cast(ulong)(raw))*unit); 
	} 
	
	string str(long raw, uint secondStep)
	{
		with(dt(raw).localSystemTime)
		return format!"%02d:%02d:%02d"(wHour, wMinute, wSecond); 
	} 
} 

template ThousandIterator(string unitStr, ulong unit1000)
{
	enum unit = unit1000/1000.0f; 
	
	struct State { ulong base; uint counter; } 
	
	State init(DateTime dt, uint thousandStep)
	{
		ulong m = dt.raw % unit1000; 
		return State(
			dt.raw - m, 
			(ifloor(m / unit)).clamp(0, 999) % thousandStep
		); 
	} 
	
	void inc(ref State st, uint thousandStep)
	{
		void doit()
		{
			with(st) {
				counter += thousandStep; 
				if(counter>=1000)
				{
					counter = 0; 
					const next = base+unit1000; 
					base = next>=base ? next : ulong.max; 
				}
			}
		} 
		enum mustFixRoundingErrors = unit<10; 
		static if(mustFixRoundingErrors)
		{
			/+
				repeat the increment operation if the raw DateTime 
				was not changed.
			+/
			const prev = dt(st); 
			doit; if(prev==dt(st)) doit; 
		}
		else { doit;  /+It has enough precision, just do it once.+/}
	} 
	
	DateTime dt(in State st)
	{
		with(st) {
			const ulong cur = base + (iround(counter * unit)); 
			return RawDateTime(cur>=base ? cur : ulong.max); 
		}
	} 
	
	string str(in State st, uint thousandStep)
	=> st.counter.text ~ unitStr; 
} 

alias MilliSecIterator 	= ThousandIterator!("ms", DateTime.RawUnit.sec),
MicroSecIterator 	= ThousandIterator!("µs", DateTime.RawUnit.ms),
NanoSecIterator 	= ThousandIterator!("ns", DateTime.RawUnit.us); 




mixin((
	(表([
		[q{/+Note: DateTimeGranularity : ubyte+/},q{/+Note: Steps+/},q{/+Note: AvgTime+/},q{/+Note: NumChars+/}],
		[q{year},q{[1, 2, 5, 10, 20, 50, 100, 500, 1000]},q{gregorianDaysInYear*day},q{5}],
		[q{month},q{[1, 2, 3, 6]},q{gregorianDaysInMonth*day},q{8}],
		[q{day},q{[1, 2, 3, 5, 10, 15]},q{day},q{11}],
		[q{hour},q{[1, 2, 3, 4, 6, 8]},q{hour},q{4}],
		[q{minute},q{[1, 2, 5, 10, 15, 20, 30]},q{minute},q{6}],
		[q{second},q{[1, 2, 5, 10, 15, 20, 30]},q{second},q{9}],
		[q{milliSecond},q{[1, 2, 5, 10, 20, 50, 100, 200, 500]},q{milli(second)},q{6}],
		[q{microSecond},q{[1, 2, 5, 10, 20, 50, 100, 200, 500]},q{micro(second)},q{6}],
		[q{nanoSecond},q{[1, 2, 5, 10, 20, 50, 100, 200, 500]},q{nano(second)},q{6}],
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
			
		subSecond	= [_.milliSecond, _.microSecond, _.nanoSecond],
			
		full	= yearMonthDay 	~ hourMinSec ~ subSecond,
		full_weeks	= yearWeek 	~ hourMinSec ~ subSecond,
		full_isoWeeks	= yearWeek_iso 	~ hourMinSec ~ subSecond; 
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
		//print(start, end, state.granularity, state.step); ulong COUNT; 
		
		void iterate(alias ITER)()
		{
			with(ITER)
			with(state)
			{
				version(/+$DIDE_REGION Fetch first boundary+/all)
				{ auto idx = init(start, step); t0 = dt(idx); p0 = tr(t0); }
				
				bool first = true; 
				while(t0<end)
				{
					label = str(idx, step); 
					
					version(/+$DIDE_REGION Fetch second boundary+/all)
					{ inc(idx, step); t1 = dt(idx); p1 = tr(t1); }
					
					if(first)	{
						if(t0.raw==0)
						p0.minimize(p1-avgSize); 
					}
					else	{
						if(t1.raw==ulong.max)
						p1.maximize(p0+avgSize); 
					}
					
					callback(state); /+COUNT++; +/
					
					version(/+$DIDE_REGION Shift+/all)
					{ t0 = t1, p0 = p1; }first = false; 
				}
			}
		} 
		switch(state.granularity)
		{
			case DateTimeGranularity.year: 	iterate!(YearIterator!()); 	break; 
			case DateTimeGranularity.month: 	iterate!(YearMonthIterator!()); 	break; 
			case DateTimeGranularity.day: 	iterate!(YearMonthDayIterator!()); 	break; 
			case DateTimeGranularity.hour: 	iterate!(HourIterator!()); 	break; 
			case DateTimeGranularity.minute: 	iterate!(HourMinuteIterator!()); 	break; 
			case DateTimeGranularity.second: 	iterate!(HourMinuteSecondIterator!()); 	break; 
			case DateTimeGranularity.milliSecond: 	iterate!(MilliSecIterator); 	break; 
			case DateTimeGranularity.microSecond: 	iterate!(MicroSecIterator); 	break; 
			case DateTimeGranularity.nanoSecond: 	iterate!(NanoSecIterator); 	break; 
			
			default: 
		}
		
		//print(COUNT); 
	}
	
} 

static void drawHRuler(IDrawing dr, bounds2 bnd, DateTime start, DateTime end)
{
	enum lineWidthScale	= 1.5f,
	clMajorTick 	= clBlue/+(RGB(0x202020))+/,
	clText 	= (RGB(0x000000)),
	clBackground	= (RGB(0x00E0FF)); 
	
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
	dr.color = clBackground; dr.fillRect(bnd); 
	
	void drawTick(float x, int size/+1..6+/)
	{ dr.vLine(x, bnd.bottom-size*th, bnd.bottom); } 
	
	
	iterateLocalDateTimeRanges
	(
		start, end, bnd.left, bnd.right, avgCharWidth, DateTimeGranularities.full, 
		((a){
			dr.color = clMajorTick; 
			if(a.isFirst) drawTick(a.p0, 6); drawTick(a.p1, 6); 
			
			dr.color = clText; dr.textOut(vec2(a.p0+lw*3, bnd.top), a.label); 
		})
	); 
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
			
			
			const ramp = 0.875 + sin(2*π*time.value(20*second))*0.125     *0.01  -.155; 
			foreach(i; 0..128)
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