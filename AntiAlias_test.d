//@exe
//@debug
//@release

//@compile --d-version=VulkanUI

/+
	260423: Implement antialias on Vulkan.
	
	
+/

import het.ui; 

vec2[4][] makeBezierSegments(vec2[] points)
{
	auto result = appender!(vec2[4][]); 
	
	// Handle first segment (no previous point)
	{
		auto p0 = points[0].vec2; 
		auto p1 = points[1].vec2; 
		auto p2 = points[2].vec2; 
		auto cp1 = p0 + (p1 - p0) / 6.0f;  // extrapolate previous
		auto cp2 = p1 - (p2 - p0) / 6.0f; 
		vec2[4] tmp = [p0, cp1, cp2, p1]; 
		result.put(tmp); 
	}
	
	// Middle segments
	foreach(i; 1 .. points.length - 2)
	{
		auto p_prev = points[i-1].vec2; 
		auto p_curr = points[i].vec2; 
		auto p_next = points[i+1].vec2; 
		auto p_next2 = points[i+2].vec2; 
		
		auto cp1 = p_curr + (p_next - p_prev) / 6.0f; 
		auto cp2 = p_next - (p_next2 - p_curr) / 6.0f; 
		vec2[4] tmp = [p_curr, cp1, cp2, p_next]; 
		result.put(tmp); 
	}
	
	// Handle last segment (no next point)
	{
		auto p_last3 = points[$-3].vec2; 
		auto p_last2 = points[$-2].vec2; 
		auto p_last = points[$-1].vec2; 
		auto cp1 = p_last2 + (p_last - p_last3) / 6.0f; 
		auto cp2 = p_last - (p_last - p_last2) / 6.0f;  // extrapolate next
		vec2[4] tmp = [p_last2, cp1, cp2, p_last]; 
		result.put(tmp); 
	}
	
	return result.data; 
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
			color = clWhite; 
			fontHeight = 100; 
			textOut(vec2(0), "Hello"); 
			
			static vec2[] p; 
			void drawBarnsleyFern(size_t maximum_iterations)
			{
				//Link: https://en.wikipedia.org/wiki/Barnsley_fern
				float x = 0, y = 0, xn = 0, yn = 0; 
				foreach(t; 0 .. maximum_iterations)
				{
					float r = randomFloat(); 
					
					if(r < 0.01f)
					{
						xn = 0.0f; 
						yn = 0.16f * y; 
					}
					else if(r < 0.86f)
					{
						xn = 0.85f * x + 0.04f * y; 
						yn = -0.04f * x + 0.85f * y + 1.6f; 
					}
					else if(r < 0.93f)
					{
						xn = 0.2f * x - 0.26f * y; 
						yn = 0.23f * x + 0.22f * y + 1.6f; 
					}
					else
					{
						xn = -0.15f * x + 0.28f * y; 
						yn = 0.26f * x + 0.24f * y + 0.44f; 
					}
					
					p ~= vec2(xn, -yn)*100; 
					
					x = xn; y = yn; 
				}
			} 
			
			void curlicueFractal(size_t N, double s)
			{
				//Link: https://mathworld.wolfram.com/CurlicueFractal.html
				auto θ = 0.0, ϕ = 0.0, v = dvec2(0); 
				s *= 2*π; 
				
				
				p ~= vec2(0); 
				foreach(i; 0..N)
				{
					ϕ += θ; ϕ = ϕ.mod(2*π); 
					θ += s; θ = θ.mod(2*π); 
					v += 10*dvec2(sin(ϕ), cos(ϕ)); 
					p ~= v.vec2; 
					
					s *= 1.0003; 
				}
			} 
			
			static vec2[4][] bez; 
			
			if(p.empty) {
				//drawBarnsleyFern(50000); 
				const constants = [
					1.618033988749894/+goldenRatio+/,
					log(2),
					ℯ,
					sqrt(2),
					π/16012
				]; 
				curlicueFractal(
					/+240_000 line+/
					75_000/+bez+/, constants[4]
				); 
				
				bez = makeBezierSegments(p); 
				
			}
			
			
			
			lineWidth = 1; pointSize = 1; 
			alpha = 1; 
			color = clRed; 
			foreach(i; 1..p.length.min(3)) { line(p[i-1], p[i]); }
			
			color = clWhite; 
			auto gfx = (cast(GfxBuilder)(drWorld.getGfxBuilder)); 
			//auto realSize = inputTransformSize(lineWidth); 
			with(gfx)
			{
				PC = clWhite; 
				svgBegin; 
				if(0)
				{
					svg!'M'(p[0]); foreach(i; 1..p.length) {
						if(!i.getBits(1, 6)) PC = RGB((i>>6)&0xff, 255, 255).from_hsv; 
						svg!'L'(p[i]); 
						
					}
				}
				else
				{
					svg!'M'(bez[0][0]); 
					foreach(i, s; bez[1..$]) {
						if(!i.getBits(1, 4)) PC = RGB((i>>4)&0xff, 255, 255).from_hsv; 
						svg!'C'(s[1], s[2], s[3]); 
					}
				}
				svgEnd; 
			}
			alpha = 1; 
			
			
		}
	} 
} 