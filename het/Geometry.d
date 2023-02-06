module het.geometry;/+DIDE+/

import het.utils;


struct seg2
{
	 //todo: make a Segment template struct
	vec2[2] p;
	alias p this;
	
	this(in vec2 a, in vec2 b) { p = [a, b]; }
	this(float x0, float y0, float x1, float y1) { this(vec2(x0, y0), vec2(x1, y1)); }
	
	vec2 diff() const { return p[1]-p[0]; }
	float length() const { return .length(diff); }
	vec2 dir() const { return diff*(1/length); }
}

auto toSegs(in vec2[] p, bool circular)
{
	 //todo: rewrite with functional.slide
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
		return clockwise ? res
										 : res.retro.array;
	}
}

auto toSegs(in bounds2 bnd, bool clockwise=true)
{ return bnd.toPoints(clockwise).toSegs(true); }


//todo: these should be done with CTCG
//todo: put these into het.math
bounds2 inflated(in bounds2 b, in vec2 v)
{ return b.valid ? bounds2(b.low-v, b.high+v) : bounds2.init; } //todo: support this for all bounds
bounds2 inflated(in bounds2 b, in float x, in float y)
{ return b.inflated(vec2(x, y)); }
bounds2 inflated(in bounds2 b, float f)
{ return b.inflated(f, f); } //todo: support this for all bounds

bounds2 inflated(in ibounds2 b, in vec2 v)
{ return b.valid ? bounds2(b.low-v, b.high+v) : bounds2.init; } //todo: support this for all bounds
bounds2 inflated(in ibounds2 b, in float x, in float y)
{ return b.inflated(vec2(x, y)); }
bounds2 inflated(in ibounds2 b, float f)
{ return b.inflated(f, f); } //todo: support this for all bounds

ibounds2 inflated(in ibounds2 b, in ivec2 v)
{ return b.valid ? ibounds2(b.low-v, b.high+v) : ibounds2.init; } //todo: support this for all bounds
ibounds2 inflated(in ibounds2 b, int x, int y)
{ return b.inflated(ivec2(x, y)); } //todo: support this for all bounds
ibounds2 inflated(in ibounds2 b, int a)
{ return b.inflated(a, a); } //todo: support this for all bounds

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

vec2 intersectLines_noParallel_prec(in seg2 S0, in seg2 S1)
//todo: all of these variation should be refactored with static ifs.
{
	auto S	= S1.p[0]-S0.p[0],
			 T	= S0.p[1]-S0.p[0],
			 U	= S1.p[0]-S1.p[1],
			 det	= crossZ(T, U),
			 detA	= crossZ(S, U),
			 alpha	= detA/det;//opt: alpha = detA*rcpf_fast(det);
	
	return S0.p[0]+T*alpha;
}

bool intersectSegs_noParallel_prec(in seg2 S0, in seg2 S1, ref vec2 P)
{
	vec2 S = S1.p[0]-S0.p[0],
			T = S0.p[1]-S0.p[0],
			U = S1.p[0]-S1.p[1];
	float det	= crossZ(T, U),
				detA	= crossZ(S, U);
	
	if(inRange_sorted(detA, 0.0f, det))
	{
		  //have one intersection
		float detB = crossZ(T, S);
		if(inRange_sorted(detB, 0.0f, det)) {
			
			float alpha = detA/det;
			//alpha = detA*rcpf_fast(det); //rather not
			P = S0.p[0]+T*alpha;
			
			return true;
		}
	}
	return false;
}

bool intersectSegs_noParallel_prec(in seg2 S0, in seg2 S1)
{
	vec2 	S = S1.p[0]-S0.p[0],
		T = S0.p[1]-S0.p[0],
		U = S1.p[0]-S1.p[1];
	float 	det	= crossZ(T, U),
		detA	= crossZ(S, U);
	
	if(inRange_sorted(detA, 0.0f, det))
	{
		  //have one intersection
		float detB = crossZ(T, S);
		if(inRange_sorted(detB, 0.0f, det)) {
			float alpha = detA/det;
			return true;
		}
	}
	return false;
}

bool intersectSegs_falseParallel_prec(in seg2 S0, in seg2 S1)
{
	vec2 S = S1.p[0]-S0.p[0],
			T = S0.p[1]-S0.p[0],
			U = S1.p[0]-S1.p[1];
	float det  = crossZ(T, U);
	
	if(abs(det)<0.001f) return false;  //todo: this is lame
	
	float detA = crossZ(S, U);
	
	if(inRange_sorted(detA, 0.0f, det))
	{
		  //have one intersection
		float detB = crossZ(T, S);
		if(inRange_sorted(detB, 0.0f, det)) {
			float alpha = detA/det;
			return true;
		}
	}
	return false;
}

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
	const projection = v + (w - v)*t;	//Projection falls on the segment
	return distance(p, projection);
}

//todo: segmentPointDistance 3d
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
			if(p.x<0) { p.x += d1.y;		 }
			else { p.x += d1.y-d1.x;	v.y += i;	 }
			dot2(v);
		}
	}
	else {
		if(d.y>=0) { v=a; e=b.y; }
		else { v=b; e=a.y; }
		dot2(v);
		while(v.y<e) {
			++v.y;
			if(p.y<0) { p.y += d1.x;		 }
			else { p.y += d1.x-d1.y;	v.x += i;	 }
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
				NOTE: 	if you follow this algorithm exactly(at least for c#),
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
	else { if(data.length==1) { res.intercept = data[0].y; }else { return res; } }
	
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
	//todo: combine Quadratic and linear fitter
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
{ return a*d-c*b; } //todo: combine this with math.det
private float det(float a, float b, float c, float d, float e, float f, float g, float h, float i)
{
	return 	+a*det(e, f, h, i)
		-d*det(b, c, h, i)
		+g*det(b, c, e, f);
}

auto quadraticFit(in vec2[] data)
{
	NOTIMPL;//todo: this is possibly buggy. must refactor.
	
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
	//todo: optimize this with .tee or	something to access x and y only once
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