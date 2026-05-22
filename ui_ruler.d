module het.ui_ruler; 

//A dev staging area for the UI Ruler component.

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
	
	string formatYMD(int y, int m, int d)
	=> format!"%d %s %d"(y, MonthNames[m-1], d); 
	/+format!"%d.%02d.%02d"(y, m, d)+/
	
	string formatH(int h)
	=> format!"%02d:"(h); 
	string formatHM(int h, int m)
	=> format!"%02d:%02d"(h, m); 
	string formatHMS(int h, int m, int s)
	=> format!"%02d:%02d:%02d"(h, m, s); 
	
	enum FULL_YMD = 
	q{((isFull)?(formatYMD(wYear, wMonth, wDay)~" "):(""))},
	FULL_YMDHMS = 
	q{
		((isFull)?(
			mixin(FULL_YMD) ~ 
			formatHMS(wHour, wMinute, wSecond)~" "
		):(""))
	}; 
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
		string str(uint y, uint yearStep, bool isFull)
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
		string str(uint ym, uint monthStep, bool isFull)
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
	
	__gshared DayQuantizeBug=false; 
	
	template YearMonthDayIterator()
	{
		uint init(DateTime dt, uint dayStep)
		{
			const 	st = dt.localSystemTime_fullRange,
				y = st.wYear,  m = st.wMonth, d = st.wDay; 
			
			version(/+$DIDE_REGION Apply human quantization "logic"+/all)
			{
				int dq = ((dayStep<5)?(quantize(d-1, dayStep)+1) :(quantize(d, dayStep).max(1))); 
				if(dq>=((m==2)?(28):(30))) dq -= dayStep; 
			}
			
			return (y*16 + m-1/+0based!+/)*32 + dq; 
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
		string str(uint ymd, uint dayStep, bool isFull)
		{ mixin(decodeYMD); return formatYMD(y, m, d); } 
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
		string str(long raw, uint minuteStep, bool isFull)
		{
			with(dt(raw).localSystemTime)
			return mixin(FULL_YMD)~formatH(wHour); 
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
		string str(long raw, uint minuteStep, bool isFull)
		{
			with(dt(raw).localSystemTime)
			return mixin(FULL_YMD)~formatHM(wHour, wMinute); 
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
		string str(long raw, uint secondStep, bool isFull)
		{
			with(dt(raw).localSystemTime)
			return mixin(FULL_YMD)~
			formatHMS(wHour, wMinute, wSecond); 
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
			else { doit; /+It has enough precision, just do it once.+/}
		} 
		
		DateTime dt(in State st)
		{
			with(st) {
				const ulong cur = base + (iround(counter * unit)); 
				return RawDateTime(cur>=base ? cur : ulong.max); 
			}
		} 
		
		bool isRed(in State st) => false; 
		string str(in State st, uint thousandStep, bool isFull)
		{
			string s; 
			if(isFull)
			with(st.base.RawDateTime.localSystemTime)
			{
				s = mixin(FULL_YMDHMS); 
				if(unit1000<=DateTime.RawUnit.ms)
				{
					s ~= (st.base/DateTime.RawUnit.ms%1000).text~"ms "; 
					if(unit1000<=DateTime.RawUnit.us)
					{ s ~= (st.base/DateTime.RawUnit.us%1000).text~"µs "; }
				}
			}
			return s ~ st.counter.text ~ unitStr; 
		} 
	} 
	alias MilliSecIterator 	= ThousandIterator!("ms", DateTime.RawUnit.sec),
	MicroSecIterator 	= ThousandIterator!("µs", DateTime.RawUnit.ms),
	NanoSecIterator 	= ThousandIterator!("ns", DateTime.RawUnit.us); 
} 



mixin((
	(表([
		[q{/+Note: DateTimeGranularity : ubyte+/},q{/+Note: Iterator#+/},q{/+Note: Steps+/},q{/+Note: AvgTime+/},q{/+Note: NumChars+/},q{/+Note: FullChars+/}],
		[q{none},q{},q{[]},q{0*second},q{1},q{0}],
		[q{year},q{YearIterator},q{[1, 2, 5, 10, 20, 50, 100, 200, 500, 1000]},q{gregorianDaysInYear*day},q{5},q{0}],
		[q{month},q{YearMonthIterator},q{[1, 2, 3, 6]},q{gregorianDaysInMonth*day},q{9},q{0}],
		[q{day},q{YearMonthDayIterator},q{[1, 2, 3, 5, 10, 15]},q{day},q{15},q{3}],
		[q{hour},q{HourIterator},q{[1, 2, 3, 6, 12]},q{hour},q{4},q{0}],
		[q{minute},q{HourMinuteIterator},q{[1, 2, 5, 10, 15, 30]},q{minute},q{6},q{0}],
		[q{second},q{HourMinuteSecondIterator},q{[1, 2, 5, 10, 15, 30]},q{second},q{9},q{22}],
		[q{milliSecond},q{MilliSecIterator},q{[1, 2, 5, 10, 20, 50, 100, 200, 500]},q{milli(second)},q{6},q{33}],
		[q{microSecond},q{MicroSecIterator},q{[1, 2, 5, 10, 20, 50, 100, 200, 500]},q{micro(second)},q{6},q{42}],
		[q{nanoSecond},q{NanoSecIterator},q{[1, 2, 5, 10, 20, 50, 100, 200, 500]},q{nano(second)},q{6},q{0}],
		[q{yearWeek},q{},q{[1, 2, 4, 8, 12, 21]},q{7*day},q{4},q{0}],
		[q{yearWeek_iso},q{},q{[1, 2, 4, 8, 12, 21]},q{7*day},q{4},q{0}],
		[q{yearDay},q{},q{[1, 2, 3, 7, 14, 28, 56, 91, 182]},q{day},q{4},q{0}],
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

void iterateLocalDateTimeRanges(
	DateTime start, DateTime end, 
	float left, float right, float avgCharWidth,
	in DateTimeGranularity[] granularities,
	void delegate(ref DateTimeIteratedRange) onLabel, 
	void delegate(ref DateTimeIteratedRange) onTick=null,
	bool fullLabel = false
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
		const numChars = 	dateTimeGranularityNumChars[gr] +
			((fullLabel)?(dateTimeGranularityFullChars[gr]):(0)); 
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
						label = str(iState, step, fullLabel); 
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
		doit; DayQuantizeBug=false; 
		
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
				i.format!"%6d", state, ITER.str(state, step, isFull:false), 
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

struct HRulerLayout
{
	DateTimeGranularityStep gr; 
	
	float p0, p1, avgCharWidth; 
	DateTime t0, t1; 
	
	bool opEquals(const ref HRulerLayout b) const 
	=> gr.granularity==b.gr.granularity && gr.step==b.gr.step
	
	/+Screen coords match loosely.+/
	&& isClose(p0, b.p0) && isClose(p1, b.p1) 
	&& avgCharWidth.isClose(b.avgCharWidth)
	
	/+Time points match exactly+/
	&& t0==b.t0 && t1==b.t1; 
	
	size_t toHash() const
	{
		auto h = hashOf((cast(int)(gr.granularity)) | gr.step<<8); 
		h = p0.hashOf(p1.hashOf(avgCharWidth.hashOf(h))); 
		return t0.hashOf(t1.hashOf(h)); 
	} 
	
	bool valid()const => gr.valid && t1>t0 && p1>p0 && avgCharWidth!=0; 
	bool opCast(B: bool)()const => valid; 
	
	string[] labels; bool[] isRed; 
	float[] p; DateTime[] t; 
	
	struct Tick { align(1): float p; ubyte level; } 
	Tick[] ticks; 
} 


HRulerLayout generateHRulerLayout
	(
	bounds2 bnd, DateTime start, DateTime end, 
	in DateTimeGranularity[] granularities = DateTimeGranularities.full,
	bool fullLabel
)
{
	HRulerLayout res; 
	if(start>=end || bnd.empty) return res; 
	const float 	h = bnd.height, fh = h*(16.0f/24), 	//fontHeight
		avgCharWidth = fh * 9.0f/16; 
	
	res.p0 = bnd.left, res.p1 = bnd.right, res.avgCharWidth = avgCharWidth, 
	res.t0 = start, res.t1 = end; 
	
	iterateLocalDateTimeRanges
	(
		start, end, bnd.left, bnd.right, avgCharWidth, granularities, 
		((a){
			if(a.idx==0) {
				res.gr = a.granularityStep; 
				res.p ~= a.p0, res.t ~= a.t0; 
			}
			
			res.labels ~= a.label, res.isRed ~= a.isRed; 
			res.p ~= a.p1, res.t ~= a.t1; 
		}),
		((a){ res.ticks ~= HRulerLayout.Tick(a.p1, a.tickLevel); }),
		fullLabel : fullLabel
	); 
	
	return res; 
} 

void drawHRuler(IDrawing dr, bounds2 bnd, const ref HRulerLayout ruler, bool isFine)
{
	enum lineWidthScale	= 1.05f,
	clMajorTick 	= (RGB(0x101010)),
	clMinorTick 	= (RGB(0x202020)),
	clText 	= (RGB(0x000000)),
	clRedText 	= (RGB(0x0000FF)),
	clBackground	= (RGB(0xFFFFFF)); 
	
	if(bnd.empty) return; 
	const float 	h = bnd.height,
		defH = ((isFine)?(24):(16)),
		lw = h/defH, 	//lineWidth;
		fh = h*(16.0f/defH), 	//fontHeight
		th = h/6	/+tickHeigh+/; 
	
	dr.lineWidth = lw * lineWidthScale, dr.fontHeight = fh; 
	dr.color = clBackground; dr.fillRect(bnd); 
	
	if(!ruler.valid) return; 
	
	void drawTick(float x, int size/+1..6+/)
	{ dr.vLine(x, bnd.bottom-size.predSwitch(2, 2.5f, size)*th, bnd.bottom); } 
	
	if(isFine)
	{ dr.color = clMinorTick; foreach(t; ruler.ticks) drawTick(t.p, t.level); }
	dr.color = clMajorTick; foreach(x; ruler.p) drawTick(x, 6); 
	
	dr.color = clText; bool lastIsRed = false; 
	void drawLabel(bool isRed, float x, string str)
	{
		if(lastIsRed.chkSet(isRed))
		dr.color = ((isRed)?(clRedText):(clText)); 
		dr.textOut(vec2(x, bnd.top), str); 
	} 
	
	const pad = lw*3, N = ruler.labels.length; 
	if(N>=3)
	{
		foreach(i, s; ruler.labels)
		{ drawLabel(ruler.isRed[i], ruler.p[i] + pad, s); }
	}
	else if(N==2)
	{
		const 	s = ruler.labels[0], tw = dr.textWidth(s),
			x = min(bnd.left+pad, ruler.p[1] - pad - tw); 
		drawLabel(ruler.isRed[0], x, s); 
		drawLabel(ruler.isRed[1], ruler.p[1] + pad, ruler.labels[1]); 
	}
	else if(N==1)
	{
		const 	s = ruler.labels[0],
			x = bnd.left + pad; 
		drawLabel(ruler.isRed[0], x, s); 
	}
} 

//returns true it the top rows is filled
bool drawHRuler(
	IDrawing dr, bounds2 bnd, DateTime start, DateTime end,
	
	bool shiftUpwards = false
	/+If there is no coarse text, if goes up 1 fh+/
)
{
	const fh = bnd.height * (2.0f/5); 
	bounds2 coarseBnd = bnd, fineBnd = bnd; 
	coarseBnd.bottom = fineBnd.top = bnd.top + fh; 
	
	alias G = DateTimeGranularity, GS = DateTimeGranularities; 
	static immutable granularitySets = 
		[
		GS.yearMonthDay, GS.hourMinSec, 
		[G.milliSecond], [G.microSecond], [G.nanoSecond]
	]; 
	
	HRulerLayout fineLayout, coarseLayout; 
	foreach_reverse(gsIdx; 0..granularitySets.length)
	{
		DayQuantizeBug = true; 
		fineLayout = generateHRulerLayout
			(
			fineBnd, start, end, 
			granularitySets[gsIdx], fullLabel: false
		); 
		if(fineLayout)
		{
			if(gsIdx>0)
			{
				coarseLayout = generateHRulerLayout
					(
					coarseBnd, start, end, 
					granularitySets[gsIdx-1], fullLabel: true
				); 
			}
			break; 
		}
	}
	
	const hasCoarse = !!coarseLayout; 
	if(shiftUpwards && !hasCoarse) {
		coarseBnd 	-= vec2(0, fh),
		fineBnd 	-= vec2(0, fh); 
	}
	
	drawHRuler(dr, coarseBnd, coarseLayout, isFine: false); 
	drawHRuler(dr, fineBnd, fineLayout, isFine: true); 
	
	return hasCoarse; 
} 