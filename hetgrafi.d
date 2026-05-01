module het.hetgrafi;

import std.algorithm : clamp;
import std.format : format;
import std.math : floor, pow, log10;
import std.string : indexOf;

import core.sys.windows.windows : SYSTEMTIME;
import het : DateTime, Time, Local, clBlack, day, hour, minute, second, milli, micro, nano;
import het.math : vec2, bounds2, RGB, mix;
import het.win : IDrawing;

// Port of the old Delphi7 THetGrafi widget logic to D.
// UI/control hosting is external; this module exposes rendering into `IDrawing`
// and mouse interaction helpers.

enum HetGrafiEventType { changed } 
alias HetGrafiEvent = void delegate(HetGrafi sender, HetGrafiEventType typ, int extra); 
alias OnDrawGraph = void delegate(HetGrafi sender, IDrawing g, bounds2 graphBounds); 

enum MouseButton { left, right, middle } 

struct MouseButtons
{ bool left, right, middle; } 

struct ZoomBounds { DateTime x0, x1; double y0, y1; }

final class HetGrafi
{
	public: 
		// Public configuration/state (kept similar to original).
		RGB lineColor = clBlack; 
		int vertHdrWidth = 60; 
		int lineHeight = 16; 
	
		bool yearMonthTogether = true; 
		bool hourMinTogether = false; 
		bool noVerticalScale = false; 
	
		bool disableZoom = false; 
		bool disablePanX = false; 
		bool disablePanY = false; 
	
		// Range limits (pan/zoom constraints)
		DateTime xMin;
		DateTime xMax;
		double yMin = 0; 
		double yMax = 0; 
		Time xDeltaMax = Time(double.infinity);
		double yDeltaMax = double.infinity; 
	
		// Current visible range
		DateTime x0;
		DateTime x1;
		double y0 = 0; 
		double y1 = 1; 
	
		bounds2 graphRect; 
	
		OnDrawGraph onDrawGraph; 
		HetGrafiEvent onEvent; 
	
		// Selection / interaction
		int selecting; // 0 none, 1 zoom-rect, 2 pan, 3 dynamic zoom
		vec2 buttonDownPoint; 
		ZoomBounds originalBounds;
		DateTime selX0, selX1;
		double sely0, sely1;
		bool selDrawn; 
	
		this() {} 
	
		void setUpRange2(
			DateTime _x0, DateTime _x1, DateTime _xMin, DateTime _xMax, Time _xDeltaMax,
			double _y0Top, double _y1Bottom, double _yMax, double _yMin, double _yDeltaMax
		)
	{
		x0 = _x0; 
		x1 = _x1; 
		xMin = _xMin; 
		xMax = _xMax; 
		xDeltaMax = _xDeltaMax; 
		
		y0 = _y0Top; 
		y1 = _y1Bottom; 
		yMax = _yMax; 
		yMin = _yMin; 
		yDeltaMax = _yDeltaMax; 
		
		checkAndClamp(); 
		notifyChanged(); 
	} 
	
		// Screen <-> world transforms (graphRect must be set)
		DateTime scrToX(float x) const
		{
			const w = graphRect.right - graphRect.left;
			if(w <= 0) return x0;
			const t = (x - graphRect.left) / w;
			const span = x1 - x0;
			return x0 + (t * span.value(second)) * second;
		}
	
		double scrToY(float y) const
	{
		const h = graphRect.bottom - graphRect.top; 
		if(h <= 0) return y0; 
		const t = (y - graphRect.top) / h; 
		return y0 + t * (y1 - y0); 
	} 
	
		float xToScr(DateTime x) const
		{
			const w = graphRect.right - graphRect.left;
			if(w <= 0) return graphRect.left;
			const denom = (x1 - x0).value(second);
			const t = denom == 0 ? 0.0 : (x - x0).value(second) / denom;
			return graphRect.left + cast(float)(t * w);
		}
	
		float yToScr(double y) const
	{
		const h = graphRect.bottom - graphRect.top; 
		if(h <= 0) return graphRect.top; 
		const t = (y - y0) / (y1 - y0); 
		return graphRect.top + cast(float)(t * h); 
	} 
	
		// Interactive API
		void mouseDown(MouseButton button, MouseButtons buttons, float x, float y)
	{
		selecting = 0; 
		clearSel(); 
		
		buttonDownPoint = vec2(x, y); 
			originalBounds = ZoomBounds(x0, x1, y0, y1);
		
			selX0 = scrToX(x);
			selX1 = selX0;
		sely0 = scrToY(y); 
		sely1 = sely0; 
		
		if(buttons.left && !buttons.right) selecting = 1; // zoom rect
		if(!buttons.left && buttons.right) selecting = 2; // pan
		if((buttons.left && buttons.right) || button == MouseButton.middle)
		{
			clearSel(); 
			selecting = 3; // dynamic zoom
		}
		
		if(selecting == 1) selDrawn = true; 
	} 
	
		void mouseMove(MouseButtons buttons, float x, float y)
	{
		if(selecting == 1)
		{
				selX1 = scrToX(x);
				sely1 = scrToY(y);
				selDrawn = true;
				return;
			}
		
		if(selecting == 2)
		{
				const nx = scrToX(x);
				const ny = scrToY(y);
				const dx = selX0 - nx;
				const dy = sely0 - ny;
				bool changed;
				if(!disablePanX) { x0 += dx; x1 += dx; changed = true; }
				if(!disablePanY) { y0 += dy; y1 += dy; changed = true; }
				if(changed)
			{
				checkAndClamp(); 
				notifyChanged(); 
			}
				selX0 = scrToX(x);
				sely0 = scrToY(y);
				return;
			}
		
		if(selecting == 3 && !disableZoom)
		{
			const dx = pow(2.0, -cast(double)(x - buttonDownPoint.x) / 100.0); 
			const dy = pow(2.0,  cast(double)(y - buttonDownPoint.y) / 100.0); 
			
				x0 = selX0 - (selX0 - originalBounds.x0) * dx;
				x1 = selX0 + (originalBounds.x1 - selX0) * dx;
				y0 = sely0 - (sely0 - originalBounds.y0) * dy;
				y1 = sely0 + (originalBounds.y1 - sely0) * dy;
			checkAndClamp(); 
			notifyChanged(); 
			return; 
		}
	} 
	
		void mouseUp(MouseButton button, MouseButtons buttons, float x, float y)
	{
		const upPoint = vec2(x, y); 
		const isClick = (abs(upPoint.x - buttonDownPoint.x) < 2) && (abs(upPoint.y - buttonDownPoint.y) < 2); 
		
		if(selecting == 1)
		{
			// Apply zoom rect if big enough
			clearSel(); 
			selecting = 0; 
			if(disableZoom) return; 
			
			const dx = abs(xToScr(selX1) - xToScr(selX0)); 
			const dy = abs(yToScr(sely1) - yToScr(sely0)); 
			if(dx > 5 || dy > 5)
			{
				pushZoomMemory(); 
				x0 = (selX0 < selX1) ? selX0 : selX1; 
				x1 = (selX0 < selX1) ? selX1 : selX0; 
				y0 = min(sely0, sely1); 
				y1 = max(sely0, sely1); 
				checkAndClamp(); 
				notifyChanged(); 
			}
			return; 
		}
		
		if(selecting == 2)
		{
			selecting = 0; 
			return; 
		}
		
		if(button == MouseButton.right && isClick && !disableZoom)
		{
			// Zoom out around center (Delphi did 2x zoom-out)
			pushZoomMemory(); 
			const cx = x0 + ((x1 - x0) * 0.5);
			const cy = (y0 + y1) * 0.5; 
			x0 = cx + ((x0 - cx) * 2); 
			x1 = cx + ((x1 - cx) * 2); 
			y0 = cy + (y0 - cy) * 2; 
			y1 = cy + (y1 - cy) * 2; 
			checkAndClamp(); 
			notifyChanged(); 
			return; 
		}
		
		if(selecting == 3)
		{
			if(isClick && !disableZoom && _zoomCount > 0)
			{
				// Restore previous zoom state
				const b = _zoomBuf[--_zoomCount]; 
				x0 = b.x0; x1 = b.x1; y0 = b.y0; y1 = b.y1; 
				checkAndClamp(); 
				notifyChanged(); 
			}
			selecting = 0; 
		}
	} 
	
		// Rendering entrypoint: draws grid + selection + calls onDrawGraph for actual data.
		void paint(IDrawing g, bounds2 clientRect)
	{
		graphRect = clientRect; 
		paintGrid(g); 
		if(onDrawGraph) onDrawGraph(this, g, graphRect); 
		drawSel(g); 
	} 
	
	void paintGrid(IDrawing g)
	{
		// Background
		g.color = mix(clBlack, lineColor, 0.0f); 
		g.fillRect(graphRect); 
		
		// Y axis tick selection based on original table
		enum double[] ySteps =
		[
			1_000_000, 500_000, 200_000, 100_000, 50_000, 20_000, 10_000,
			5_000, 2_000, 1_000, 500, 200, 100, 50, 20, 10,
			5, 2, 1,
			0.5, 0.2, 0.1, 0.05, 0.02, 0.01,
			0.005, 0.002, 0.001,
			0.0005, 0.0002, 0.0001,
			0.00005, 0.00002, 0.00001,
			0.000005, 0.000002, 0.000001,
		]; 
		
		if(!noVerticalScale)
		{
			const yInterval = y1 - y0; 
			if(abs(yInterval) > 1e-12)
			{
				const graphH = (graphRect.bottom - graphRect.top); 
				double best = ySteps[0]; 
				double bestErr = double.infinity; 
				foreach(s; ySteps)
				{
					const pix = abs(graphH / yInterval * s); 
					const err = abs(40.0 - pix); 
					if(err < bestErr) { bestErr = err; best = s; }
				}
				
				double y = floor(y0 / best) * best; 
				g.color = lineColor; 
				g.lineWidth = 1; 
				
				for(int guard = 0; guard < 2000; ++guard)
				{
					const yScr = yToScr(y); 
					if(yScr > graphRect.bottom + 1) break; 
					if(yScr >= graphRect.top - 1)
					{
						// grid line
						g.hLine(graphRect.left + vertHdrWidth - 5, yScr, graphRect.right); 
						
						// label
						const s = format("%.5g", y); 
						g.textOut(vec2(graphRect.left + 2, yScr - g.fontHeight * 0.5f), s); 
					}
					y += best; 
				}
			}
		}
		
		// X grid (DateTime): choose a tick unit based on pixels/second and emit aligned labels.
		{
			const w = (graphRect.right - graphRect.left) - vertHdrWidth;
			if(w > 10 && x1 > x0)
			{
				const spanSec = (x1 - x0).value(second);
				if(spanSec > 0)
				{
					const secPerPx = spanSec / w;
					const pxPerSec = 1.0 / secPerPx;

					Gran gran;
					int step = 1;
					pickGranularity(pxPerSec, gran, step);

					auto t = alignDown(x0, gran, step);
					g.color = lineColor;
					g.lineWidth = 1;

					for(int guard = 0; guard < 5000; ++guard)
					{
						if(t > x1) break;
						const xScr = xToScr(t);
						if(xScr >= graphRect.left + vertHdrWidth - 1 && xScr <= graphRect.right + 1)
						{
							g.vLine(xScr, graphRect.top, graphRect.bottom);
							g.textOut(vec2(xScr + 2, graphRect.bottom - g.fontHeight), formatLabel(t, gran));
						}
						t = addStep(t, gran, step);
					}
				}
			}
		}
	} 

	private enum Gran
	{
		year,
		month,
		day,
		hour,
		minute,
		second,
		millisecond,
		microsecond,
		nanosecond,
	}

	private static void pickGranularity(double pxPerSec, out Gran gran, out int step)
	{
		// Target around ~80px between labeled ticks.
		// This is tuned for readability, not for matching Delphi's full rule table.
		step = 1;

		if(pxPerSec * (365.0 * 24 * 3600) >= 80) { gran = Gran.year; step = 1; return; }
		if(pxPerSec * (30.0  * 24 * 3600) >= 80) { gran = Gran.month; step = 1; return; }
		if(pxPerSec * (24.0  * 3600) >= 80) { gran = Gran.day; step = 1; return; }
		if(pxPerSec * (3600.0) >= 80)
		{
			gran = Gran.hour;
			step = pxPerSec * (12.0 * 3600) >= 80 ? 12 :
			       pxPerSec * (6.0  * 3600) >= 80 ? 6  :
			       pxPerSec * (3.0  * 3600) >= 80 ? 3  :
			       pxPerSec * (2.0  * 3600) >= 80 ? 2  : 1;
			return;
		}
		if(pxPerSec * (60.0) >= 80)
		{
			gran = Gran.minute;
			step = pxPerSec * (30.0 * 60) >= 80 ? 30 :
			       pxPerSec * (20.0 * 60) >= 80 ? 20 :
			       pxPerSec * (15.0 * 60) >= 80 ? 15 :
			       pxPerSec * (10.0 * 60) >= 80 ? 10 :
			       pxPerSec * (5.0  * 60) >= 80 ? 5  :
			       pxPerSec * (2.0  * 60) >= 80 ? 2  : 1;
			return;
		}
		if(pxPerSec * 1.0 >= 80)
		{
			gran = Gran.second;
			step = pxPerSec * 30.0 >= 80 ? 30 :
			       pxPerSec * 20.0 >= 80 ? 20 :
			       pxPerSec * 15.0 >= 80 ? 15 :
			       pxPerSec * 10.0 >= 80 ? 10 :
			       pxPerSec * 5.0  >= 80 ? 5  :
			       pxPerSec * 2.0  >= 80 ? 2  : 1;
			return;
		}

		// Sub-second
		if(pxPerSec * 0.001 >= 80) { gran = Gran.millisecond; step = 1; return; }
		if(pxPerSec * 0.000001 >= 80) { gran = Gran.microsecond; step = 1; return; }
		gran = Gran.nanosecond;
		step = 1;
	}

	private static DateTime alignDown(DateTime t, Gran gran, int step)
	{
		static DateTime fromLocalSystemTime(in SYSTEMTIME st) { return DateTime(Local, st); }

		auto st = t.localSystemTime;
		final switch(gran)
		{
			case Gran.year:
				st.wMonth = 1; st.wDay = 1;
				st.wHour = 0; st.wMinute = 0; st.wSecond = 0; st.wMilliseconds = 0;
				// step years: snap year down
				{
					const y = cast(int)st.wYear;
					const y0 = y - (y % step);
					st.wYear = cast(ushort)y0;
				}
				return fromLocalSystemTime(st);

			case Gran.month:
				st.wDay = 1;
				st.wHour = 0; st.wMinute = 0; st.wSecond = 0; st.wMilliseconds = 0;
				{
					const m = cast(int)st.wMonth;
					const m0 = m - ((m - 1) % step);
					st.wMonth = cast(ushort)m0;
				}
				return fromLocalSystemTime(st);

			case Gran.day:
				st.wHour = 0; st.wMinute = 0; st.wSecond = 0; st.wMilliseconds = 0;
				// step days: we keep it simple (no calendar-day snapping by step > 1)
				return fromLocalSystemTime(st);

			case Gran.hour:
				st.wMinute = 0; st.wSecond = 0; st.wMilliseconds = 0;
				st.wHour = cast(ushort)(cast(int)st.wHour - (cast(int)st.wHour % step));
				return fromLocalSystemTime(st);

			case Gran.minute:
				st.wSecond = 0; st.wMilliseconds = 0;
				st.wMinute = cast(ushort)(cast(int)st.wMinute - (cast(int)st.wMinute % step));
				return fromLocalSystemTime(st);

			case Gran.second:
				st.wMilliseconds = 0;
				st.wSecond = cast(ushort)(cast(int)st.wSecond - (cast(int)st.wSecond % step));
				return fromLocalSystemTime(st);

			case Gran.millisecond:
			case Gran.microsecond:
			case Gran.nanosecond:
				// Raw alignment (UTC) for sub-second ticks
				ulong unit;
				final switch(gran)
				{
					case Gran.millisecond: unit = DateTime.RawUnit.ms; break;
					case Gran.microsecond: unit = DateTime.RawUnit.us; break;
					case Gran.nanosecond: unit = DateTime.RawUnit._100ns; break; // best available
					default: unit = DateTime.RawUnit._100ns; break;
				}
				auto res = t;
				const u = unit * cast(ulong)step;
				res.raw -= res.raw % u;
				return res;
		}
	}

	private static DateTime addStep(DateTime t, Gran gran, int step)
	{
		auto st = t.localSystemTime;
		final switch(gran)
		{
			case Gran.year:
				st.wYear = cast(ushort)(cast(int)st.wYear + step);
				return DateTime(Local, st);
			case Gran.month:
				{
					int y = st.wYear;
					int m = st.wMonth + step;
					while(m > 12) { m -= 12; ++y; }
					st.wYear = cast(ushort)y;
					st.wMonth = cast(ushort)m;
				}
				return DateTime(Local, st);
			case Gran.day: return t + (step * day);
			case Gran.hour: return t + (step * hour);
			case Gran.minute: return t + (step * minute);
			case Gran.second: return t + (step * second);
			case Gran.millisecond: return t.add_raw(DateTime.RawUnit.ms * cast(ulong)step);
			case Gran.microsecond: return t.add_raw(DateTime.RawUnit.us * cast(ulong)step);
			case Gran.nanosecond: return t.add_raw(DateTime.RawUnit._100ns * cast(ulong)step);
		}
	}

	private static string formatLabel(DateTime t, Gran gran)
	{
		auto st = t.localSystemTime;
		const rawInSec = t.raw % DateTime.RawUnit.sec;
		const usPart = cast(uint)((rawInSec / DateTime.RawUnit.us) % 1_000_000);
		const ns100Part = cast(uint)((rawInSec / DateTime.RawUnit._100ns) % 10_000_000);
		final switch(gran)
		{
			case Gran.year: return format("%04d", st.wYear);
			case Gran.month: return format("%04d-%02d", st.wYear, st.wMonth);
			case Gran.day: return format("%04d-%02d-%02d", st.wYear, st.wMonth, st.wDay);
			case Gran.hour: return format("%02d:%02d", st.wHour, st.wMinute);
			case Gran.minute: return format("%02d:%02d", st.wHour, st.wMinute);
			case Gran.second: return format("%02d:%02d:%02d", st.wHour, st.wMinute, st.wSecond);
			case Gran.millisecond: return format("%02d:%02d:%02d.%03d", st.wHour, st.wMinute, st.wSecond, st.wMilliseconds);
			case Gran.microsecond: return format("%02d:%02d:%02d.%03d%03d", st.wHour, st.wMinute, st.wSecond, st.wMilliseconds, usPart % 1000);
			case Gran.nanosecond: return format("%02d:%02d:%02d.%07d", st.wHour, st.wMinute, st.wSecond, ns100Part);
		}
	}
	
		void drawSel(IDrawing g)
	{
		if(!selDrawn || selecting != 1) return; 
		const b = selectionBounds(); 
		g.color = invRGB(lineColor); 
		g.lineWidth = 1; 
		g.drawRect(b); 
	} 
	
		void clearSel()
	{ selDrawn = false; } 
	
		bounds2 selectionBounds() const
		{
			const xA = xToScr(selX0);
			const xB = xToScr(selX1);
			const yA = yToScr(sely0);
			const yB = yToScr(sely1);
			return bounds2(min(xA, xB), min(yA, yB), max(xA, xB), max(yA, yB));
		}
	
		void pushZoomMemory()
		{
			if(_zoomCount == _zoomBuf.length)
		{
			for(size_t i = 1; i < _zoomBuf.length; ++i) _zoomBuf[i - 1] = _zoomBuf[i]; 
			_zoomCount = _zoomBuf.length - 1; 
		}
			_zoomBuf[_zoomCount++] = ZoomBounds(x0, x1, y0, y1);
		}
	
		void zoomOut()
		{
		if(disableZoom) return; 
		if(_zoomCount == 0) return; 
		const b = _zoomBuf[--_zoomCount]; 
			x0 = b.x0; x1 = b.x1; y0 = b.y0; y1 = b.y1;
			checkAndClamp();
			notifyChanged();
		}
	
	void checkAndClamp()
	{
		if(x1 < x0) { const t = x0; x0 = x1; x1 = t; }
		if(y1 < y0) { const t = y0; y0 = y1; y1 = t; }
		
		const dx = x1 - x0; 
		const dy = y1 - y0; 
		
		if(dx > xDeltaMax)
		{
			const mid = x0 + (dx * 0.5); 
			x0 = mid - (xDeltaMax * 0.5); 
			x1 = mid + (xDeltaMax * 0.5); 
		}
		if(dy > yDeltaMax)
		{
			const mid = (y0 + y1) * 0.5; 
			y0 = mid - yDeltaMax * 0.5; 
			y1 = mid + yDeltaMax * 0.5; 
		}
		
		if(xMax && xMin && (x1 - x0) <= (xMax - xMin))
		{
			const span = x1 - x0; 
			auto n0 = x0.unixTime;
			const min0 = xMin.unixTime;
			const max0 = (xMax - span).unixTime;
			n0 = clamp(n0, min0, max0);
			x0.unixTime = n0;
			x1 = x0 + span; 
		}
		if(yMax > yMin && (y1 - y0) <= (yMax - yMin))
		{
			const span = y1 - y0; 
			y0 = clamp(y0, yMin, yMax - span); 
			y1 = y0 + span; 
		}
	} 
	
		RGB invRGB(RGB c) const
	{ return RGB(1.0f - c.r, 1.0f - c.g, 1.0f - c.b); } 
	
	private: 
		ZoomBounds[10] _zoomBuf;
		size_t _zoomCount; 
	
		void notifyChanged()
	{ if(onEvent) onEvent(this, HetGrafiEventType.changed, 0); } 
} 

unittest
{
	auto g = new HetGrafi; 
	DateTime a = void; a.unixTime = 0;
	DateTime b = void; b.unixTime = 10;
	DateTime mn = void; mn.unixTime = -100;
	DateTime mx = void; mx.unixTime = 100;
	g.setUpRange2(a, b, mn, mx, 1000*second, 0, 1, 10, -10, 1000); 
	g.graphRect = bounds2(0, 0, 100, 100); 
	assert(g.scrToX(0) == g.x0); 
	assert(g.scrToX(100) == g.x1); 
	
	g.mouseDown(MouseButton.left, MouseButtons(true, false, false), 10, 10); 
	g.mouseMove(MouseButtons(true, false, false), 90, 90); 
	assert(g.selecting == 1); 
	assert(g.selectionBounds.right >= g.selectionBounds.left); 
	g.mouseUp(MouseButton.left, MouseButtons(true, false, false), 90, 90); 

	// DateTime label formatting smoke
	DateTime t0 = void; t0.unixTime = 0;
	assert(HetGrafi.formatLabel(t0, HetGrafi.Gran.year).length == 4);
	auto t1 = t0.add_raw(DateTime.RawUnit._100ns * 123);
	assert(HetGrafi.formatLabel(t1, HetGrafi.Gran.nanosecond).indexOf('.') >= 0);
} 
