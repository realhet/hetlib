//@exe
//@debug
//@release

//@compile --d-version=VulkanUI

import het.ui; 

private
{
	auto extremeDateTime(int year)
	=> RawDateTime(((year<2000)?(0):(ulong.max))); 
	
	struct YearMonthDay
	{ ushort year; ubyte month, day; } 
	
	DateTime localDateTime_impl(in YearMonthDay dt)
	=> DateTime(Local, dt.year, dt.month, dt.day).ifThrown(extremeDateTime(dt.year)); 
	alias cachedLocalDateTime_impl = memoize!localDateTime_impl; 
	/+Opt: This uses AssocArray so it is bad for the GC.+/
	
	DateTime cachedLocalDateTime(int year, int month=1, int day=1)
	=> cachedLocalDateTime_impl(YearMonthDay((cast(ushort)(year)), (cast(ubyte)(month)), (cast(ubyte)(day)))); 
	
	ubyte dayOfWeek_impl(in YearMonthDay dt)
	{
		int y = dt.year, m = dt.month, d = dt.day; 
		/+
			Tomohiko Sakamoto's algorithm
			Returns: 0=Sunday, 1=Monday, ..., 6=Saturday
			Works for Gregorian calendar (after 1582)
		+/
		static immutable t = [0, 3, 2, 5, 0, 3, 5, 1, 4, 6, 2, 4]; 
		if(m < 3) y -= 1; 
		return (cast(ubyte)((y + y / 4 - y / 100 + y / 400 + t[m - 1] + d) % 7)); 
	} 
	alias cachedDayOfWeek_impl = memoize!dayOfWeek_impl; 
	
	ubyte cachedDayOfWeek(int year, int month, int day)
	=> cachedDayOfWeek_impl(YearMonthDay((cast(ushort)(year)), (cast(ubyte)(month)), (cast(ubyte)(day)))); 
	
	
	T quantize(T)(T m, uint q=1)
	=> ((q>1)?((cast(T)((double(m)).stdQuantize!floor(q)))):(m)); 
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
	
	bool isRed(uint y) => false; 
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
	
	bool isRed(uint ym) => false; 
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
	
	bool isRed(uint ymd)
	{ mixin(decodeYMD); return !!cachedDayOfWeek(y, m, d).among(0, 6); } 
	string str(uint ymd, uint dayStep)
	{
		mixin(decodeYMD); return /+format!"%d.%02d.%02d"(y, m, d)+/
		format!"%d %s %d"(y, MonthNames[m-1], d); 
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
		long raw = dt.raw / unit; 
		raw -= hourStep-1; 
		adjust(raw, hourStep); return raw; 
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
	
	bool isRed(long raw) => false; 
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
	{
		long raw = dt.raw / unit; 
		if(minuteStep>1) raw -= raw.modw(minuteStep); return raw; 
	} 
	
	void inc(ref long raw, uint minuteStep)
	{ raw += minuteStep; } 
	
	DateTime dt(long raw)
	{
		if(raw>=ulong.max/unit) return RawDateTime(ulong.max); 
		return RawDateTime((cast(ulong)(raw))*unit); 
	} 
	
	bool isRed(long raw) => false; 
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
	{
		long raw = dt.raw / unit; 
		if(secondStep>1) raw -= raw.modw(secondStep); return raw; 
	} 
	
	void inc(ref long raw, uint secondStep)
	{ raw += secondStep; } 
	
	DateTime dt(long raw)
	{
		if(raw>=ulong.max/unit) return RawDateTime(ulong.max); 
		return RawDateTime((cast(ulong)(raw))*unit); 
	} 
	
	bool isRed(long raw) => false; 
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
		int fr = (ifloor(m / unit)).clamp(0, 999); 
		fr -= fr % thousandStep; 
		return State(dt.raw - m, fr); 
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
	
	bool isRed(in State st) => false; 
	string str(in State st, uint thousandStep)
	=> st.counter.text ~ unitStr; 
} 

alias MilliSecIterator 	= ThousandIterator!("ms", DateTime.RawUnit.sec),
MicroSecIterator 	= ThousandIterator!("µs", DateTime.RawUnit.ms),
NanoSecIterator 	= ThousandIterator!("ns", DateTime.RawUnit.us); 




mixin((
	(表([
		[q{/+Note: DateTimeGranularity : ubyte+/},q{/+Note: Iterator#+/},q{/+Note: Steps+/},q{/+Note: AvgTime+/},q{/+Note: NumChars+/}],
		[q{none},q{},q{[]},q{0*second},q{1}],
		[q{year},q{YearIterator},q{[1, 2, 5, 10, 20, 50, 100, 200, 500, 1000]},q{gregorianDaysInYear*day},q{5}],
		[q{month},q{YearMonthIterator},q{[1, 2, 3, 6]},q{gregorianDaysInMonth*day},q{8}],
		[q{day},q{YearMonthDayIterator},q{[1, 2, 3, 5, 10, 15]},q{day},q{11}],
		[q{hour},q{HourIterator},q{[1, 2, 3, 6, 12]},q{hour},q{4}],
		[q{minute},q{HourMinuteIterator},q{[1, 2, 5, 10, 15, 30]},q{minute},q{6}],
		[q{second},q{HourMinuteSecondIterator},q{[1, 2, 5, 10, 15, 30]},q{second},q{9}],
		[q{milliSecond},q{MilliSecIterator},q{[1, 2, 5, 10, 20, 50, 100, 200, 500]},q{milli(second)},q{6}],
		[q{microSecond},q{MicroSecIterator},q{[1, 2, 5, 10, 20, 50, 100, 200, 500]},q{micro(second)},q{6}],
		[q{nanoSecond},q{NanoSecIterator},q{[1, 2, 5, 10, 20, 50, 100, 200, 500]},q{nano(second)},q{6}],
		[q{yearWeek},q{},q{[1, 2, 4, 8, 12, 21]},q{7*day},q{4}],
		[q{yearWeek_iso},q{},q{[1, 2, 4, 8, 12, 21]},q{7*day},q{4}],
		[q{yearDay},q{},q{[1, 2, 3, 7, 14, 28, 56, 91, 182]},q{day},q{4}],
	]))
).調!(GEN_enumTable)); 

DateTimeGranularity successorOf(DateTimeGranularity g)
{
	with(DateTimeGranularity)
	{
		static immutable sequence = [year, month, day, hour, minute, second, milliSecond, microSecond, nanoSecond]; 
		const idx = sequence.countUntil(g); 
		if(mixin(界1(q{0},q{idx+1},q{sequence.length}))) return sequence[idx+1]; 
		return DateTimeGranularity.none; 
	}
} 

struct DateTimeGranularityStep
{
	DateTimeGranularity granularity; 
	ubyte tickLevel; 
	ushort step; 
	
	bool valid()const => granularity&&step; 
	bool opCast(B: bool)()const => valid; 
	
	bool isTick()const => !!tickLevel; 
} 

DateTimeGranularityStep[] selectTickGranularities(in DateTimeGranularityStep a)
{
	alias G = DateTimeGranularity, GS = DateTimeGranularityStep; 
	auto level1(int l)
	=> [GS(a.granularity, 1, (cast(ushort)(l)))]; 
	
	auto level2(int l1, int l2)
	=> [
		GS(a.granularity, 2, (cast(ushort)(l1))),
		GS(a.granularity, 1, (cast(ushort)(l2)))
	]; 
	
	auto level2succ(int l1, int l2)
	=> [
		GS(a.granularity          , 2, (cast(ushort)(l1))),
		GS(a.granularity.successorOf, 1, (cast(ushort)(l2)))
	]; 
	
	auto level2succ2(int l1, int l2)
	=> [
		GS(a.granularity.successorOf, 2, (cast(ushort)(l1))),
		GS(a.granularity.successorOf, 1, (cast(ushort)(l2)))
	]; 
	
	if(a.step<=0) return []; 
	
	if(a.step==1000) return level2(500, 100); 
	if(a.step==500) return level2(100, 50); 
	if(a.step==200) return level2(100, 20); 
	if(a.step==100) return level2(50, 10); 
	if(a.step==50) return level2(10, 5); 
	if(a.step==20) return level2(10, 2); 
	if(a.step==30) return level1(10); 
	if(a.step==15) return level2(5, 1); 
	if(a.step==12) return level2(6, 1); 
	if(a.step==10) return level2(5, 1); 
	if(a.step==8) return level2(4, 1); 
	if(a.step==5)
	{
		if(a.granularity==G.year) return level2succ(1, 6/+month+/); 
		if(a.granularity==G.day) return level2succ(1, 12/+hour+/); 
		if(a.granularity==G.minute) return level2succ(1, 30/+second+/); 
		if(mixin(界3(q{G.second},q{a.granularity},q{G.nanoSecond})))
		return level2succ(1, 500/+thousandth+/); 
	}
	if(a.step==2)
	{
		if(a.granularity==G.year) return level2succ(1, 3/+month+/); 
		if(a.granularity==G.day) return level2succ(1, 6/+hour+/); 
		if(a.granularity==G.minute) return level2succ(1, 15/+second+/); 
		if(mixin(界3(q{G.second},q{a.granularity},q{G.nanoSecond})))
		return level2succ(1, 200/+thousandth+/); 
	}
	if(a.step==1)
	{
		if(a.granularity==G.year) return level2succ2(3, 1/+month+/); 
		if(a.granularity==G.day) return level2succ2(6, 2/+hour+/); 
		if(a.granularity==G.hour) return level2succ2(30, 10/+minute+/); 
		if(a.granularity==G.minute) return level2succ2(30, 10/+second+/); 
		if(mixin(界3(q{G.second},q{a.granularity},q{G.nanoSecond})))
		return level2succ2(500, 100/+thousandth+/); 
	}
	if(mixin(界0(q{1},q{a.step},q{10}))) return level1(1); 
	return []; 
} 

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
	uint idx; 
	DateTimeGranularityStep granularityStep; 
	ref granularity() => granularityStep.granularity; 
	ref step() => granularityStep.step; 
	ref tickLevel() => granularityStep.tickLevel; 
	
	//only if tickLevel!=0
	bool isRed; string label; 
} 

auto iterateLocalDateTimeRanges(
	DateTime start, DateTime end, 
	float left, float right, float avgCharWidth,
	in DateTimeGranularity[] granularities,
	void delegate(ref DateTimeIteratedRange) onLabel, 
	void delegate(ref DateTimeIteratedRange) onTick=null
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
	
	void doit()
	{
		if(!state.step) return; 
		//print(start, end, state.granularity, state.step); ulong COUNT; 
		
		void iterate(alias Iterator)()
		{
			static if(__traits(compiles, &Iterator.inc))
			alias ITER = Iterator; else alias ITER = Iterator!(); 
			with(ITER)
			with(state)
			{
				version(/+$DIDE_REGION Fetch first boundary+/all)
				{ auto iState = init(start, step); t0 = dt(iState); p0 = tr(t0); }
				
				idx = 0; 
				while(t0<end)
				{
					if(tickLevel==0) {
						label = str(iState, step); 
						state.isRed = ITER.isRed(iState); 
					}
					
					version(/+$DIDE_REGION Fetch second boundary+/all)
					{ inc(iState, step); t1 = dt(iState); p1 = tr(t1); }
					
					if(idx==0)	{
						if(t0.raw==0)
						p0.minimize(p1-avgSize); 
					}
					else	{
						if(t1.raw==ulong.max)
						p1.maximize(p0+avgSize); 
					}
					
					if(tickLevel==0) onLabel(state); else onTick(state); 
					
					version(/+$DIDE_REGION Shift+/all)
					{ t0 = t1, p0 = p1; }idx++; 
				}
			}
		} 
		
		sw: final switch(state.granularity)
		{
			static foreach(g; EnumMembers!DateTimeGranularity)
			{
				case g: 
				static if(dateTimeGranularityIterator[g]!="")
				mixin(iq{iterate!$(dateTimeGranularityIterator[g]); }.text); 
				break sw; 
			}
		}
	} 
	
	if(state.step)
	{
		doit; 
		
		if(onTick !is null)
		{
			foreach(gs; state.granularityStep.selectTickGranularities)
			if(gs) { state.granularityStep = gs; doit; }
		}
	}
} 

void dumpIteratorStats(alias Iterator)(int[] steps)
{
	static if(__traits(compiles, &Iterator.inc))
	alias ITER = Iterator; else alias ITER = Iterator!(); 
	print("DateTime Iterator statistics for:", ITER.stringof); 
	foreach(step; steps)
	{
		print("Step:", step); 
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
			diffHist[k].format!"%9d *", k.format!"%16X", 
			((double(k))/DateTime.RawUnit.day).format!"%18.12f"
		); 
		print; 
	}
	print; 
} 

void dumpDateTimeIteratorStats()
{
	dumpIteratorStats!YearMonthDayIterator([1, 2, 3, 5, 10, 15]); 
	dumpIteratorStats!HourIterator([1, 2, 3, 4, 6, 8]); 
} 

static void drawHRuler(IDrawing dr, bounds2 bnd, DateTime start, DateTime end)
{
	enum lineWidthScale	= 1.1f,
	clMajorTick 	= (RGB(0x000000)),
	clMinorTick 	= (RGB(0x000000)),
	clText 	= (RGB(0x000000)),
	clBackground	= (RGB(0xFFFFFF)); 
	
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
	{ dr.vLine(x, bnd.bottom-size.predSwitch(2, 2.5f, size)*th, bnd.bottom); } 
	
	
	iterateLocalDateTimeRanges
	(
		start, end, bnd.left, bnd.right, avgCharWidth, DateTimeGranularities.full, 
		((a){
			dr.color = clMajorTick; 
			if(a.idx==0) drawTick(a.p0, 6); drawTick(a.p1, 6); 
			
			dr.color = a.isRed ? clRed : clText; 
			dr.textOut(vec2(a.p0+lw*3, bnd.top), a.label); 
		}),
		((a){ dr.color = clMinorTick; drawTick(a.p1, a.tickLevel); })
	); 
} 

class FrmHelloGUI: UIWindow
{
	mixin autoCreate; mixin SetupMegaShader!q{}; 
	
	override void onCreate()
	{
		//dumpDateTimeIteratorStats; 
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
			
			const ramp = 0.875 + sin(2*π*time.value(20*second))*0.0000125     *0.01  -.155; 
			if(1)
			foreach(i; 0..128/1)
			{
				static if(1)
				const 	h = ulong.max/2,  n = (cast(ulong)(h * pow(ramp, i*1))).min(h),
					st = RawDateTime(h-n), en = RawDateTime(h+n+1); 
				
				static if(0)
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
				/+
				do1(x0, x1); 
				do2(x0, x1); 
				do5(x0, x1); 
			+/
		}
	} 
} 