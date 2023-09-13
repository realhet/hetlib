module het.geometry; /+DIDE+/

import het.utils; 

alias seg2 = Segment!vec2; 
alias dseg2 = Segment!dvec2; 

struct Segment(Vect)
{
	alias 	V = Vect, 
		E = V.ComponentType; 
	
	V[2] p; 
	
	alias p this; 
	
	this(A, B)(in A a, in B b) { p[0] = V(a); p[1] = V(b); } 
	this(E x0, E y0, E x1, E y1) { this(V(x0, y0), V(x1, y1)); } 
	
	auto diff() const { return p[1] - p[0]; } 
	auto length() const { return .length(diff); } //Todo: implement in math.length
	auto dir() const { return diff*(1/length); } //Todo: implement in math.normalize
} 

auto toSegs(in vec2[] p, bool circular)
{
	 //Todo: rewrite with functional.slide
	seg2[] res; 
	res.reserve(p.length); 
	if(p.length<=1) return res; 
	foreach(i; 0..p.length-1+(circular ? 1 : 0)) {
		auto j = i+1; 
		if(j == p.length) j = 0; 
		res ~= seg2(p[i], p[j]); 
	}
	return res; 
} 

auto toPoints(in bounds2 bnd, bool clockwise=true)
{
	with(bnd) {
		auto res = [low, vec2(high.x, low.y), high, vec2(low.x, high.y)]; 
		return clockwise 	? res
			: res.retro.array; 
	}
} 

auto toSegs(in bounds2 bnd, bool clockwise=true)
{ return bnd.toPoints(clockwise).toSegs(true); } 


//Todo: these should be done with CTCG
//Todo: put these into het.math
bounds2 inflated(in bounds2 b, in vec2 v)
{ return b.valid ? bounds2(b.low-v, b.high+v) : bounds2.init; } //Todo: support this for all bounds
bounds2 inflated(in bounds2 b, in float x, in float y)
{ return b.inflated(vec2(x, y)); } 
bounds2 inflated(in bounds2 b, float f)
{ return b.inflated(f, f); } //Todo: support this for all bounds

bounds2 inflated(in ibounds2 b, in vec2 v)
{ return b.valid ? bounds2(b.low-v, b.high+v) : bounds2.init; } //Todo: support this for all bounds
bounds2 inflated(in ibounds2 b, in float x, in float y)
{ return b.inflated(vec2(x, y)); } 
bounds2 inflated(in ibounds2 b, float f)
{ return b.inflated(f, f); } //Todo: support this for all bounds

ibounds2 inflated(in ibounds2 b, in ivec2 v)
{ return b.valid ? ibounds2(b.low-v, b.high+v) : ibounds2.init; } //Todo: support this for all bounds
ibounds2 inflated(in ibounds2 b, int x, int y)
{ return b.inflated(ivec2(x, y)); } //Todo: support this for all bounds
ibounds2 inflated(in ibounds2 b, int a)
{ return b.inflated(a, a); } //Todo: support this for all bounds

auto fittingSquare(in bounds2 b)
{
	auto diff = (b.size.x-b.size.y)*0.5f; 
	if(diff<0) return b.inflated(0    , diff); 
	else return b.inflated(-diff,    0); 
} 

//float - int combinations ///////////////////////////////////////

////////////////////////////////////////////////////////////////////////////////////////////
///  Graphics algorithms                                                                 ///
////////////////////////////////////////////////////////////////////////////////////////////

///  Intersections, primitive distances  ///////////////////////////////////////////////////

vec2 intersectLines_noParallel_prec(S: Segment!E, E)(in S S0, in S S1)
//Todo: all of these variation should be refactored with static ifs.
{
	auto 	S	= S1.p[0]-S0.p[0],
		T	= S0.p[1]-S0.p[0],
		U	= S1.p[0]-S1.p[1],
		det	= crossZ(T, U),
		detA	= crossZ(S, U),
		alpha 	= detA/det; //Opt: alpha = detA*rcpf_fast(det);
	
	return S0.p[0] + T*alpha; 
} 

bool intersectSegs_noParallel_prec(S: Segment!E, E)(in S S0, in S S1, ref E P)
{
	auto 	S = S1.p[0]-S0.p[0],
		T = S0.p[1]-S0.p[0],
		U = S1.p[0]-S1.p[1]; 
	auto 	det	= crossZ(T, U),
		detA 	= crossZ(S, U); 
	
	if(inRange_sorted(detA, 0, det))
	{
		//have one intersection
		auto detB = crossZ(T, S); 
		if(inRange_sorted(detB, 0, det))
		{
			auto alpha = detA/det; 
			//alpha = detA*rcpf_fast(det); //rather not
			P = S0.p[0]+T*alpha; 
			
			return true; 
		}
	}
	return false; 
} 

bool intersectSegs_noParallel_prec(S: Segment!E, E)(in S S0, in S S1)
{
	auto 	S = S1.p[0]-S0.p[0],
		T = S0.p[1]-S0.p[0],
		U = S1.p[0]-S1.p[1]; 
	auto 	det	= crossZ(T, U),
		detA	= crossZ(S, U); 
	
	if(inRange_sorted(detA, 0, det))
	{
		//have one intersection
		auto detB = crossZ(T, S); 
		if(inRange_sorted(detB, 0, det)) {
			auto alpha = detA/det; 
			return true; 
		}
	}
	return false; 
} 

bool intersectSegs_falseParallel_prec(S: Segment!E, E)(in S S0, in S S1)
{
	auto 	S	= S1.p[0] - S0.p[0],
		T	= S0.p[1] - S0.p[0],
		U 	= S1.p[0] - S1.p[1]; 
	auto det = crossZ(T, U); 
	
	if(abs(det)<1e-30) return false;  //Todo: this is lame
	
	auto detA = crossZ(S, U); 
	
	if(inRange_sorted(detA, 0, det))
	{
		//have one intersection
		auto detB = crossZ(T, S); 
		if(inRange_sorted(detB, 0, det)) {
			auto alpha = detA/det; 
			return true; 
		}
	}
	return false; 
} 

auto polyLineLength(R)(R arr)
{ return arr.slide!(No.withPartial)(2).map!(a => (magnitude(a[1]-a[0]))).sum; } 

float segmentPointDistance_prec(const vec2 v, const vec2 w, const vec2 p)
{
	//Return minimum distance between line segment vw and point p
	const l2 = sqrLength(v-w);    //i.e. |w-v|^2 -  avoid a sqrt
	if(!l2) return distance(p, v); //v == w case
	//Consider the line extending the segment, parameterized as v + t (w - v).
	//We find projection of point p onto the line.
	//It falls where t = [(p-v) . (w-v)] / |w-v|^2
	//We clamp t from [0,1] to handle	points outside the segment vw.
	const t = max(0, min(1, dot(p - v,	w - v) / l2)); 
	const projection = v + (w - v)*t; 	//Projection falls on the segment
	return distance(p, projection); 
} 

//Todo: segmentPointDistance 3d
/*
	vec3 segmentNearestPoint(vec3 S0, vec3 S1, vec3 P){
		vec3 v = S1 - S0;
		vec3 w = P - S0;
	
		float c1 = dot(w,v);
		if(c1<=0.0) return S0;
	
		float c2 = dot(v,v);
		if(c2<=c1) return S1;
	
		float b = c1 / c2;
		vec3 Pb = S0 + b * v;
		return Pb;
	}
	
	
	float segmentPointDistance(vec3 S0, vec3 S1, vec3 P){
		return distance(P, segmentNearestPoint(S0, S1, P));
	}
*/


/// 2D point position restriction inside bounds
vec2 restrictPos_normal(T1, T2)(in Vector!(T1, 2) p, in Bounds!(Vector!(T2, 2)) bnd)
{ return p.clamp(bnd.low, bnd.high); } 

vec2 restrictPos_editor(T1, T2)(in Vector!(T1, 2) p, in Bounds!(Vector!(T2, 2)) bnd)
{
	return 	p.y<bnd.top ? bnd.topLeft :
		p.y>bnd.bottom ? bnd.bottomRight :
		vec2(p.x.clamp(bnd.left, bnd.right), p.y); 
} 

///  Bresenham line drawing /////////////////////////////////////////////////////////////////////

void line_bresenham(in ivec2 a, in ivec2 b, bool skipFirst, void delegate(in ivec2) dot)
{
	auto d = b-a,
			 d1 = abs(d),
			 p = ivec2(
		2*d1.y-d1.x,
										 2*d1.x-d1.y
	),
			 i = (d.x<0)==(d.y<0) ? 1 : -1; 
	d1 *= 2; 
	
	void dot2(in ivec2 p) { if(!skipFirst || p!=a) dot(p); } 
	
	int e; ivec2 v; 
	if(d1.y<=d1.x) {
		if(d.x>=0) { v=a; e=b.x; }
		else { v=b; e=a.x; }
		dot2(v); 
		while(v.x<e) {
			++v.x; 
			if(p.x<0) { p.x += d1.y; 		}
			else { p.x += d1.y-d1.x; 	v.y += i; 	}
			dot2(v); 
		}
	}
	else {
		if(d.y>=0) { v=a; e=b.y; }
		else { v=b; e=a.y; }
		dot2(v); 
		while(v.y<e) {
			++v.y; 
			if(p.y<0) { p.y += d1.x; 		}
			else { p.y += d1.x-d1.y; 	v.x += i; 	}
			dot2(v); 
		}
	}
} 

///	 Cohen Sutherland line-rect Clipping ///////////////////////////////////////////////////////////////
///	 Ported to Delphi from wikipedia C code by Omar Reis - 2012	                         ///
///	 Ported back to C by realhet 2013, lol	                         ///
///	 Ported finally to D by realhet 2016, lol**2	                         ///

bool _lineClip(V, E, F)(in V bMin, in V bMax, ref V a, ref V b)
{
	const 	INSIDE	= 0, //0000
		LEFT	= 1, //0001
		RIGHT	= 2, //0010
		BOTTOM	= 4, //0100
		TOP	= 8 //1000
	; 
	
	int computeOutCode(const V v) const
	{
		int res = INSIDE; //initialised as being inside of clip window
		
		if(v.x < bMin.x) res |= LEFT; 
		else if(
			v.x > bMax.x//to the left of clip window
		)
		res |= RIGHT; 
		//to the right of clip window
		
		if(v.y < bMin.y) res |= BOTTOM; 
		else if(
			v.y > bMax.y//below the clip window
		)
		res |= TOP; 
		//above the clip window
		
		return res; 
	} 
	
	//compute outcodes for P0, P1, and whatever point lies outside the clip rectangle
	int outcode0 = computeOutCode(a); 
	int outcode1 = computeOutCode(b); 
	while(1)
	{
		if((outcode0 | outcode1)==0) {
			 //Bitwise OR is 0. Trivially result and get out of loop
			return true; 
		}
		else if(outcode0 & outcode1) {
			 //Bitwise AND is not 0. Trivially reject and get out of loop
			return false; 
		}
		else {
			//failed both tests, so calculate the line segment to clip
			//from an outside point to an intersection with clip edge
			//At least one endpoint is outside the clip rectangle; pick it.
			int outcodeOut = outcode0 ? outcode0 : outcode1; 
			//Now find the intersection point;
			//use formulas y = a.y + slope * (x - a.x), x = a.x + (1 / slope) * (y - a.y)
			F x,y; 
			if(outcodeOut & TOP)	{
				//point is above the clip rectangle
				x = a.x + (b.x - a.x) * (bMax.y - a.y) / (b.y - a.y); 
				y = bMax.y; 
			}
			else if(outcodeOut & BOTTOM)	{
				//point is below the clip rectangle
				x	= a.x + (b.x - a.x) * (bMin.y - a.y) / (b.y - a.y); 
				y	= bMin.y; 
			}
			else if(outcodeOut & RIGHT)	{
				//point is to the right of clip rectangle
				y	= a.y + (b.y - a.y) * (bMax.x - a.x) / (b.x - a.x); 
				x	= bMax.x; 
			}
			else	{
				//point is to the left of clip rectangle
				y = a.y + (b.y - a.y) * (bMin.x - a.x) / (b.x - a.x); 
				x = bMin.x; 
			}
			
			/*
				Note: if you follow this algorithm exactly(at least for c#),
				then you will fall into an infinite loop
				in case a line crosses more than two segments. 
				To avoid that problem, leave out the last else
				if(outcodeOut & LEFT) and just make it else 
			*/
			
			//Now we move outside point to intersection point to clip
			//and get ready for next pass.
			if(outcodeOut==outcode0) {
				a.x = cast(E)x; 
				a.y = cast(E)y; 
				outcode0 = computeOutCode(a); 
			}
			else {
				b.x = cast(E)x; 
				b.y = cast(E)y; 
				outcode1 = computeOutCode(b); 
			}
		}
	}
} 
//lineClip()



/// Nearest finders ///////////////////////////////////////////////////////////////

int distManh(in ibounds2 b, in ivec2 p)
{ with(b) return max(max(left-p.x, p.x-right, 0), max(top-p.y, p.y-bottom, 0)); } 

auto findNearestManh(in ibounds2[] b, in ivec2 p)
{
	auto idx = b.map!(r => r.distManh(p)).array.minIndex; 
	if(idx<0) return ibounds2(); 
	else return b[idx]; 
} 

auto findNearestManh(ibounds2[] b, in ivec2 p, int maxDist, int* actDist=null)
{
	auto idx = b.map!(r => r.distManh(p)).array.minIndex; 
	if(idx<0) {
		if(actDist) *actDist = int.max; 
		return ibounds2(); 
	}else {
		int d = b[idx].distManh(p); 
		if(actDist) *actDist = d; 
		if(d>maxDist) return ibounds2(); 
		else return b[idx]; 
	}
} 

//Linear fit ///////////////////////////////////////////////////////////////////////

struct LinearFitResult
{
	vec2[] points; 
	float slope=0; 
	float intercept=0; 
	
	float deviation = 0; 
	int worstIdx = -1; 
	bool isGood; //optimizer fills it
	
	bool isNull() const
	{ return !slope && !intercept; } 
	
	float y(float x)
	{ return intercept+x*slope; } 
} 

auto linearFit(in vec2[] data)
{
	auto xSum	= data.map!"a.x".sum,
			 ySum	= data.map!"a.y".sum,
			 xxSum	= data.map!"a.x*a.x".sum,
			 xySum	= data.map!"a.x*a.y".sum,
			 len =	data.length.to!float; 
	
	LinearFitResult res; 
	
	if(data.length>=2) {
		res.points = data.dup; 
		res.slope = (len*xySum - xSum*ySum) / (len * xxSum - xSum * xSum); 
		res.intercept = (ySum - res.slope * xSum) / len; 
	}
	else { if(data.length==1) { res.intercept = data[0].y; }else { return res; }}
	
	auto error(in vec2 p) { return res.y(p.x)-p.y; } 
	res.deviation = sqrt(data.map!(p => error(p)^^2).sum/(data.length.to!int-1)); 
	res.worstIdx = data.map!(p => abs(error(p))).maxIndex.to!int; 
	
	return res; 
} 

auto linearFit(in vec2[] data, int requiredPoints, float maxDeviation)
{
	auto fit = linearFit(data); 
	
	while(1) {
		fit.isGood = fit.points.length>=requiredPoints && fit.deviation<maxDeviation; 
		if(fit.isGood) break; 
		if(fit.points.length<=requiredPoints) break; 
		fit = linearFit(fit.points.remove(fit.worstIdx)); 
	}
	
	return fit; 
} 

//Quadratic fit ///////////////////////////////////////////////////////////////////////

struct QuadraticFitResult
{
	//Todo: combine Quadratic and linear fitter
	vec2[] points; 
	float a=0, b=0, c=0; 
	
	float deviation = 0; 
	int worstIdx = -1; 
	bool isGood; //optimizer fills it
	
	bool isNull() const { return !a && !b && !c; } 
	
	float y(float x) const { return a*x^^2 + b*x + c; } 
	
	vec2 location() const
	{
		float ly = 0; 
		const lx = peakLocation(a, b, c, &ly); 
		return vec2(lx, ly); 
	} 
	
	float location_x() const
	{ return peakLocation(a, b, c); } 
} 

private float det(float a, float b, float c, float d)
{ return a*d-c*b; } //Todo: combine this with math.det
private float det(float a, float b, float c, float d, float e, float f, float g, float h, float i)
{
	return 	+a*det(e, f, h, i)
		-d*det(b, c, h, i)
		+g*det(b, c, e, f); 
} 

auto quadraticFit(in vec2[] data)
{
	NOTIMPL; //Todo: this is possibly buggy. must refactor.
	
	QuadraticFitResult res; 
	if(data.length<3) {
		if(data.length==2) {
			auto lin = linearFit(data); //get it from linear
			res.b = lin.slope; 
			res.c = lin.intercept; 
			res.deviation = lin.deviation; 
			res.worstIdx = lin.worstIdx; 
		}
		return res; 
	}
	
	//https://www.codeproject.com/Articles/63170/Least-Squares-Regression-for-Quadratic-Curve-Fitti
	//notation sjk to mean the sum of x_i^j*y_i^k.
	//Todo: optimize this with .tee or	something to access x and y only once
	float 	s40 = data.map!"a.x^^4".sum,	//sum of x^4
		s30 = data.map!"a.x^^3".sum,	//sum of x^3
		s20 = data.map!"a.x^^2".sum,	//sum of x^2
		s10 = data.map!"a.x".sum,	//sum of x
		s00 = data.length,	//sum of x^0 * y^0	ie 1 * number of entries
		s21 = data.map!"a.x^^2*a.y".sum,	//sum of x^2*y
		s11 = data.map!"a.x*a.y".sum,	//sum of x*y
		s01 = data.map!"a.y".sum	//sum of y
	; 
	
	auto D = det(
		s40, s30, s20,
		s30, s20, s10,
		s20, s10, s00
	); 
	res.a = det(
		s21, s30, s20,
		s11, s20, s10,
		s01, s10, s00
	)/D; 
	res.b = det(
		s40, s21, s20,
		s30, s11, s10,
		s20, s01, s00
	)/D; 
	res.c = det(
		s40, s30, s21,
		s30, s20, s11,
		s20, s10, s01
	)/D; 
	
	res.points = data.dup; 
	
	//copied from lin
	auto error(in vec2 p) { return res.y(p.x)-p.y; } 
	res.deviation = sqrt(data.map!(p => error(p)^^2).sum/(data.length.to!int-1)); 
	res.worstIdx = data.map!(p => abs(error(p))).maxIndex.to!int; 
	
	return res; 
} 
auto mirrorPointOverLine(V, T2, T3)(V P, T2 A, T3 B)
{
	const 	d = B - A,
		mx = ((V(d.x*d.x - d.y*d.y, d.x*d.y*2))/(d.x*d.x + d.y*d.y)),
		my = mx.rotate270,
		a = P - A; 
	return mx*a.x + my*a.y + A; 
} 

auto extrapolateCurve(V)(V A, V B, V C)
{
	//Continuity: C1
	static if(1)
	{
		//this is simpler, only uses 1 div and no trigonometryc functions
		//Opt: Measure how fast and precise it is.
		const M1 = (B+C)/2, M2 = M1 + (B-C).rotate90; 
		return mirrorPointOverLine(A, M1, M2); 
	}
	else
	{
		const 	v1 = (B-A).normalize,
			v2 = (C-B).normalize,
			a = asin(cross(v1, v2).z); 
		return C + (C-B).rotate(a); 
	}
} 

auto extrapolateCurve(V)(V A, V B, V C, V D)
{
	//Continuity: C2
	const 	v1 = (B-A).normalize,
		v2 = (C-B).normalize,
		v3 = (D-C).normalize,
		a1 = asin(cross(v1, v2).z),
		a2 = asin(cross(v2, v3).z),
		a3 = a2 + (a2-a1); 
	return D + (D-C).rotate(a3); 
} 

T[2] linearBezierWeights(T)(T t)
{
	const u = 1-t; 
	return [u, t]; 
} 

T[3] quadraticBezierWeights(T)(T t)
{
	const u = 1-t; 
	return [((u)^^(2)), 2*u*t, ((t)^^(2))]; 
} 

T[4] cubicBezierWeights(T)(T t)
{
	const u = 1-t; 
	return [((u)^^(3)), 3*t*((u)^^(2)), 3*u*((t)^^(2)), ((t)^^(3))]; 
} 

auto evalBezier(F, int N)(in Vector!(F, 2)[N] p, F t)
{
	const w = cubicBezierWeights(t); 
	auto res = p[0]*w[0]; 
	static foreach(i; 1..p.length) res += p[i]*w[i]; 
	return res; 
} 

auto generateBezierPolyline(F, int N)(in Vector!(F, 2)[N] p, F stepSize=1)
{
	
	auto eval(F t)
	{ return evalBezier(p, t); } 
	
	const 	roughCount	= iround(5*p[].polyLineLength/stepSize).max(1),
		invRoughCount 	= F(1)/roughCount,
		points	= iota(roughCount+F(1)).map!(i => eval(i*invRoughCount)).array,
		lengths	= points.slide!(No.withPartial)(2).map!(a => distance(a[0], a[1])).array,
		totalLen	= lengths.sum,
		segmentCount	= iround(totalLen/stepSize).max(1),
		segmentLen	= totalLen/segmentCount; 
		
	F writtenLen = 0, prevLen = 0; F[] t; 
	loop:  //resample the t values using linear interpolation
	foreach(i, actLen; lengths)
	{
		while(writtenLen.inRange(prevLen, prevLen+actLen))
		{
			t ~= (i + writtenLen.remap(prevLen, prevLen+actLen, 0, 1))*invRoughCount; 
			writtenLen += segmentLen; 
			if(t.length==segmentCount) break loop; 
		}
		prevLen += actLen; 
	}
	t ~= 1;  //the last point must be exactly 1.0
	
	return t.map!(a => eval(a)).array; 
} 



alias FTurtle = Turtle_!float, 
DTurtle = Turtle_!double, 
Turtle = DTurtle; 

struct Turtle_(T)
{
	alias V=Vector!(T, 2); 
	
	T stepSize=1; 
	void delegate(V) sink; 
	
	//state variables
	V pos, dir=V(1, 0); 
	
	void reset()
	{ pos = 0; dir = V(1, 0); } 
	
	@property state() { return tuple(pos, dir); } 
	@property state(Tuple!(V, V) a) { pos = a[0]; dir = a[1]; } 
	
	Tuple!(V, V)[] stack; 
	void push()
	{ stack ~= state; } 
	void pop()
	{
		enforce(stack.length); 
		state = stack.back; stack.popBack; 
	} 
	
	V[] capture(void delegate() fun)
	{
		V[] res; 
		
		auto realSink = sink; 
		sink = (V p){ if(res.empty || res.back!=p) res ~= p; }; 
		push; 
		scope(exit) { sink = realSink; pop; } 
		
		fun(); 
		
		return res; 
	} 
	
	void emit(V[] arr)
	{ arr.each!((a){ sink(a); }); } 
	
	void line(
		in T length //negative goes backwards
	)
	{
		if(!length) return; 
		const 	segmentCount 	= ((abs(length))/(stepSize)).iround.max(1),
			endPos 	= pos + dir*length,
			step 	= (endPos-pos) * (T(1)/segmentCount); 
		sink(pos); 
		foreach(i; 0..segmentCount-1)
		{ pos += step; sink(pos); }
		pos = endPos; sink(pos); 
	} 
	
	void arc_angle(
		T θ, //negative: goes backwards on the same side
		T r //-left, +right
	)
	{
		if(!θ) return; 
		if(θ<0) {
			//negative angle: backwards, same side (mirror)
			θ *= -1; dir *= -1; r *= -1; 
		}
		θ = θ.radians * r.sign; //turning direction is defined by radius
		
		const 	length	= abs(θ*r),
			segmentCount	= ((length)/(stepSize)).iround.max(1),
			segmentLength 	= ((length)/(segmentCount)),
			center	= pos + dir.rotate90 * r,
			endPos	= (pos-center).rotate(θ) + center,
			endDir	= (normalize(dir.rotate(θ))),
			Δθ 	= ((θ)/(segmentCount)); 
		
		dir = (normalize(dir.rotate(Δθ / 2))) * segmentLength; 
		sink(pos); 
		foreach(i; 0..segmentCount-1)
		{
			pos += dir; sink(pos); 
			dir = dir.rotate(Δθ); 
		}
		pos = endPos; dir = endDir; 
		sink(pos); 
	} 
	
	void arc_length(
		T length, //negative: goes backwards on the same side
		T r //-left, +right
	)
	{
		if(!length) return; 
		const θ = ((length)/((magnitude(r)))).degrees; 
		arc_angle(θ, r); 
	} 
	
	void clothoid_accel(
		T ΔΔθ, //angle step increase between steps.
		T r_start, T r_end //negative = turn left
	)
	{
		if(!ΔΔθ) return; 
		if(ΔΔθ<0)
		{
			//negative angle: backwards, same side (mirror)
			ΔΔθ *= -1; dir *= -1; 
		}
		
		const 	segmentLength 	= stepSize,
			Δθ_start 	= segmentLength / r_start,
			Δθ_end 	= segmentLength / r_end; 
		
		//calculate actual angle acceleration
		ΔΔθ = (magnitude(ΔΔθ.radians)) * sign(Δθ_end - Δθ_start); 
		if(!ΔΔθ) return; 
		
		
		sink(pos); 
		T Δθ = Δθ_start + ΔΔθ; //the first point has acceleration too
		dir = (normalize(dir.rotate(Δθ/2))) * segmentLength; //sets dir.length
		while(
			(ΔΔθ>0 && Δθ<Δθ_end) || 
			(ΔΔθ<0 && Δθ>Δθ_end)
		)
		{
			pos += dir; sink(pos); 
			dir = dir.rotate(Δθ); 
			Δθ += ΔΔθ; 
		}
		
		/+
			Note: The final pos/dir is distorted by the iterative calculations, 
			but it's much simpler than FresnelC
		+/
		pos += dir; sink(pos); 
		dir = (normalize(dir.rotate(Δθ/2))); //restore dir.length
	} 
} 