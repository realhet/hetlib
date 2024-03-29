module het.draw3d; 

//20210513: broken: Must reapply math.d changes!!!!!!!!!!!!!!!!!

//http://faydoc.tripod.com/formats/3ds.htm
//http://read.pudn.com/downloads70/sourcecode/windows/opengl/253342/INC/3DSFTK.H__.htm

import het, het.opengl, het.stream; 

enum DUMP_3DS_IMPORT = false; 

//enforce my modifications for gl3n... update: FUCK gl3n! :D
//static assert(vec3.init==vec3(0), "gl3n.Vector.init is nan");
//static assert(mat4.init==mat4.identity, "gl3n.Matrix.init is nan");


struct VertexRec
{ vec3 aPosition; } 

//utils /////////////////////////////////////////////////

auto project(in mat4 m, in vec3 v)
{
	auto p = m*vec4(v, 1),
			 w = 1/p.w; 
	return p.xyz*w; 
} 

/+
	mat4 lookAt(const vec3 eye, const vec3 target, const vec3 up)
	{
		auto forward = target - eye; 
		if(!sqrLength(forward))
		return mat4.identity; 
		forward = normalize(forward); 
		
		auto side = cross(forward, up).normalize; 
		auto upVector = cross(side, forward); 
		
		return mat4(vec4(side, 0), vec4(upVector, 0), vec4(-forward, 0), vec4(eye, 1)).transpose.inverse; 
	} 
+/

void repairRotation(ref mat4 m, bool doNormalize)
{
	vec3 col(int n)
	{ return vec3(m[0][n]      , m[1][n]      , m[2][n]     ); } 
	void setCol(int n, in vec3 v)
	{ m[0][n] = v.x; m[1][n] = v.y; m[2][n] = v.z; } 
	
	float[3] len; 
	foreach(int i, ref a; len)
	{
		a = col(i).length; if(!a)
		a=1; 
	}
	
	vec3[3] r; 
	r[0] = col(0)/len[0]; 
	r[1] = col(1)/len[1]; 
	r[2] = cross(r[0], r[1]); 
	r[0] = cross(r[1], r[2]); 
	
	if(doNormalize)
	foreach(i; 0..3)
	setCol(i, r[i]); 
	else
	foreach(i; 0..3)
	setCol(i, r[i]*len[i]); 
	
} 

//struct Ray(CT, int N){ Vec!(CT, N) origin, direction; }
//struct Plane(CT, int N){ Vec!(CT, N) origin, normal; }

struct Ray
{ vec3 origin, direction; } 
struct Plane
{ vec3 origin, normal; } 
//auto ray(in vec3 origin, in vec3 direction){ return Ray!(float, 3)(origin, direction); }
//auto plane(in vec3 origin, in vec3 normal){ return Plane!(float, 3)(origin, normal); }

auto intersect(in Plane plane, in Ray ray)
{
	import std.typecons; 
	Nullable!vec3 res; 
	
	auto e = 1e-6f; 
	auto d = dot(plane.normal, ray.direction); 
	
	if(!d.inRange(-e, e))
	{
		float distance = dot(plane.normal, (plane.origin-ray.origin)) / d; 
		res = (ray.origin + (ray.direction * distance)).nullable; 
	}
	return res; 
} 

auto intersect(in Ray ray, in Plane plane)
{ return intersect(plane, ray); } 



//Cursor3D //////////////////////////////////

/// A 3D cursor from a sceeen position. Reads the depth buffer.

struct Cursor3D
{
	ivec2 screen; //local coords inside viewport
	int invy; //for opengl
	bool inScreen; 
	
	float depth = .5f; 
	vec3 device; //-1..1 range
	vec3 world; 
	
	void setup(in ivec2 pos, in ibounds2 bounds)
	{
		inScreen = bounds.contains!"[)"(pos); 
		with(pos-bounds.topLeft)
		screen = ivec2(x, y); 
		invy = bounds.height-1-screen.y; 
		
		with(device)
		{
			x =	 2.0f*(screen.x)/bounds.width -1; 
			y =	 2.0f*(invy)/bounds.height-1; 
			z = 0; 
		}
		depth = 1; 
	} 
	
	void readDepth()
	{
		if(inScreen)
		{
			auto d = [.5f]; 
			gl.readPixels(screen.x, invy, 1, 1, GL_DEPTH_COMPONENT, GL_FLOAT, d); 
			depth = d[0]; 
		}else
		{ depth = 1; }
	} 
	
	/// read depth, and unproject
	void glProcess(in mat4 mInverse)
	{
		readDepth; 
		device.z = 2*depth-1; 
		world = mInverse.project(device); 
	} 
} 


//CubicOrientation /////////////////////////////////

struct CubeOrientation
{
	private: 
	
		static auto axisVector(int n)
	{
		auto e = vec3(0,0,0); 
		e[mod(n, 3)] = 1; 
		return e; 
	} 
	
		static int idxEncode(int delegate(int) axisIndex, int delegate(int) axisNegative)
	{
		return 1*axisNegative(0)  //negativeness mask 3 bits
			 | 2*axisNegative(1)
			 | 4*axisNegative(2)
			 | 8*(axisIndex(1) > axisIndex(2) ? 1:0)  //relation of the 2nd and the 3rd axis: 1 bit
			 |16*axisIndex(0); //first axis, 0..2
			 //total range = 48
	} 
	
		static auto mat2idx(in mat4 m)
	{
		auto axis	  (int n)
		{ return [m[0][n], m[1][n], m[2][n]]; } 
		auto axisIndex	  (int n)
		{ return cast(int) axis(n).map!(a => a<0 ? -a : a).maxIndex; }  //Note: abs suxx, it is declared in gl3n and makes utils. abs obsolete
		auto axisNegative(int n)
		{ return axis(n)[axisIndex(n)]<0 ? 1 : 0; } 
		return idxEncode(&axisIndex, &axisNegative); 
	} 
	
		static auto str2idx(string s)
	{
		auto axisIndex   (int n)
		{ return (cast(int)(s.get(n).lc-'x')).mod(3); } 
		auto axisNegative(int n)
		{ auto ch = s.get(n); return ch == ch.lc ? 0 : 1; } 
		return idxEncode(&axisIndex, &axisNegative); 
	} 
	
		static void idxDecode(int val, void delegate(int n, int idx, int neg) setAxis)
	{
		int ax0 = (val>>4).mod(3); 
		setAxis(0, ax0, val.getBit(0)); 
		
		int[] ax = iota(3).filter!(i => i!=ax0).array; 
		if(val.getBit(3))
		swap(ax[0], ax[1]); 
		
		setAxis(1, ax[0], val.getBit(1)); 
		setAxis(2, ax[1], val.getBit(2)); 
	} 
	
		static auto idx2mat(int val)
	{
		auto m = mat4(0,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,1); 
		void setAxis(int n, int idx, int neg)
		{ m[idx][n] = neg ? -1 : 1; } //rowcol
		idxDecode(val, &setAxis); 
		return m; 
	} 
	
		static auto idx2str(int val)
	{
		string[3] res; 
		void setAxis(int n, int idx, int neg)
		{ res[n] = (cast(char)('x' + idx + (neg ? -32 : 0))).to!string; } 
		idxDecode(val, &setAxis); 
		return res[].join; 
	} 
	
	public: 
		@RANGE(0, 24) ubyte idx; 
	
		this(string s)                       
	{ asString = s; } 
		this(int i)                          
	{ idx = cast(ubyte) i.mod(48); } 
	
		auto opCmp(in CubeOrientation other) 
	{ return idx - other.idx; } 
	
		string toString() const              
	{ return idx2str(idx); } 
		bool validateString(string s) const	 
	{ return s.length==3 && s.map!(a => "xyz".canFind(a.lc)).all; } 
		void fromString(string s)	 
	{
		if(validateString(s))
		idx = cast(ubyte)str2idx(s); 
	} 
	
		@property
	{
		auto matrix() const                
		{ return idx2mat(idx); } 
		void matrix(in mat4 m)             
		{ idx = cast(ubyte) mat2idx(m); } 
		
		auto asString() const              
		{ return toString; } 
		void asString(string s)            
		{ fromString(s); } 
	} 
	
		void spin(int axis, int cnt)
	{ matrix = matrix * mat4.rotation(vec4(axisVector(axis), 1), PIf/2*cnt.mod(4)); } 
	
		void mirror(int axis)
	{
		int i = axis.mod(3); 
		auto s = asString.to!(char[]); 
		s[i] = cast(char) (s[i].lc == s[i] ? s[i].uc : s[i].lc); 
		asString = s.to!string; 
	} 
	
		void spinRandom(uint seed)
	{
		enum N = 5; 
		foreach(i; 0..N)
		spin(seed.getBits(i*4, 2), seed.getBits(i*4+2, 2)); 
	} 
	
		void spinRandom(RNG* rng = null)
	{
		if(!rng)
		rng = &defaultRng; 
		spinRandom(rng.randomUint); 
	} 
	
		static void selfTest()
	{
		foreach(i; 0..3)
		foreach(dir; [-1, 1])
		{
			writef("Rotating around axis %s dir %2d:", i, dir); 
			CubeOrientation o; write(" ", o); 
			foreach(j; 0..4)
			{ o.spin(i, dir); write(" ", o); }
			writeln; 
		}
		
		foreach(i; 0..3)
		{
			CubeOrientation o; 
			writef("Mirroring around axis %s:", i); 
			write(" ", o); 
			foreach(k; 0..2)
			{ o.mirror(i); write(" ", o); }
			writeln; 
		}
		
		enforce(CubeOrientation(0)<CubeOrientation(1), "opCmp failed"); 
		
		auto getAllSpins(bool mirror)
		{
			RNG rng; 
			auto a = iota(200).map!(
				(i){
					CubeOrientation o; if(mirror)
					o.mirror(rng.random(3)); o.spinRandom(&rng); return o; 
				}
			).array.sort.uniq.array; 
			writefln("All spins, mirror=%d length=%d: %s", mirror.to!int, a.length, a); 
			enforce(a.length==24, "CubeOrientation big fail"); 
			return a; 
		} 
		
		auto spins = (getAllSpins(false) ~ getAllSpins(true)).sort.uniq.array; 
		writeln("Total spins with both mirrors: ", spins.length); 
		enforce(spins.length==48, "CubeOrientation big fail"); 
		
		//conversion tests
		foreach(o; iota(48).map!CubeOrientation)
		{
			{ CubeOrientation o2; o2.asString = o.asString;   enforce(o==o2, "sttring conversion fail"); }
			{ CubeOrientation o2; o2.matrix   = o.matrix;   enforce(o==o2, "sttring conversion fail"); }
		}
		writeln("Conversion tests passed."); 
	} 
	
} 


/// Do a swizzle and negate the coords marked with a capital letter
/// Example: code="Zyx"
/// Similar to swizzle
vec3 axisTransform(string code)(in vec3 v)
{
		vec3 u; 
		u.x = v.vector[(((cast(ubyte) code[0])-88) & 31) % 3]; if(code[0]<'a')
	u.x.negate; 
		u.y = v.vector[(((cast(ubyte) code[1])-88) & 31) % 3]; if(code[1]<'a')
	u.y.negate; 
		u.z = v.vector[(((cast(ubyte) code[2])-88) & 31) % 3]; if(code[2]<'a')
	u.z.negate; 
		return u; 
	
		//these 2 are compatible
	/*
		static matrix = CubeOrientation(code).matrix.get_rotation;
		return v * matrix;
	*/
} 


class Camera
{
	 //! Camera //////////////////////////////////////
		@STORED
	{
		@HIDDEN mat4 eye; 	    //contains viewing position, rotation and zoom
		@HIDDEN vec3 pivot; 	    //rotation center
		
		bool isPerspective = true; 
		@RANGE(30, 140) float verticalFov; 
		float verticalVisibleUnits = 1000; 
		
		float near = 10, //in ortho near is -far
			  far = 10000; 
	} 
	
		string unit; 
	
		this()
	{ reset; } 
	
		void dump()
	{ this.toJson.writeln; } 
	
		private vec3 axis(int n) const
	{
		vec3 v; foreach(i; 0..3)
		v[i] = eye[n][i]; return v; 
	} //Todo: the matric row/column majority is not good here   update: I swapped it!!!!
		private void setAxis(int n, vec3 v)
	{
		foreach(i; 0..3)
		eye[n][i] = v[i]; 
	} 
	
		vec3 right() const
	{ return axis(0); } 
		vec3 up() const
	{ return axis(1); } 
		vec3 forward() const
	{ return axis(2); } 
		@property vec3 origin()    const
	{ return axis(3); } 
		@property void origin(in vec3 v)
	{ setAxis(3, v); } 
	
		float pivotDistance() const
	{ return (origin-pivot).length; } 
		auto pivotPlane() const
	{ return Plane(pivot, forward); } 
		vec3 pivotPlaneCenter() const
	{ return intersect(pivotPlane, Ray(origin, forward)).get(vec3(0,0,0)); } 
		float pivotPlaneDistance() const
	{ return (origin-pivotPlaneCenter).length; } 
	
		float tanFovY()const
	{ return tan(verticalFov/360*PIf); } //Todo: use PI instead of PIf and check the assembli for single precision arithmetic.
	
		float calcVerticalVisibleUnits()	const
	{ return pivotPlaneDistance   * (tanFovY*2); } //*2 because tanFovY is just a half angle
		float calcPivotPlaneDistance()	const
	{ return verticalVisibleUnits / (tanFovY*2); } //inverse of calcVerticalVisibleUnits
	
		/// Synchronizes verticalVisibleUnits and origin distance from pivotPlane
		/// Must be called after change of: verticalVisibleUnits, origin, pivot
		void synch()
	{
		if(isPerspective)
		{ verticalVisibleUnits = pivotPlaneDistance * (tanFovY*2); }else
		{ origin = pivotPlaneCenter - forward * (verticalVisibleUnits / (tanFovY*2)); }
	} 
	
		/// increments verticalFov and moves camera back/forth
		void adjustFovY(float degIncrement)
	{
		if(!degIncrement)
		return; 
		float oldTop = pivotPlaneDistance*tanFovY; 
		verticalFov += degIncrement; 
		verticalFov = clamp(verticalFov, 30, 140); 
		float newTop = pivotPlaneDistance*tanFovY; 
		
		eye = eye * mat4.translation(vec3(0, 0, newTop-oldTop)); 
		synch; 
	} 
	
		//camera controls
		void reset()
	{
		eye = mat4.identity.rotatey(PI).translate(0,30*4,270*4).rotatex(-PIf/6); 
		pivot = vec3(0, 0, 0); 
		//verticalFov = 60;
		synch; 
	} 
	
		@HIDDEN private const float
			rotSpeed = 1/250.0f,
			zoomSpeed = 0.0025f*40,
			zoomMax = 1600.0f; 
	
		/// pans view and pivot. Speed is taken from pivotDistance by default.
		void pan(in vec2 v, float viewHeight, float speed = 1)
	{
		if(!v.length)
		return; 
		
		speed *= (isPerspective ? calcVerticalVisibleUnits : verticalVisibleUnits)/viewHeight; 
		
		vec3 delta = (right*v.x + up*v.y) * speed; 
		eye.translate(delta); 
		
		//pivot += delta;   //it's better to leave the pivot where it is. So the scene will rotate around the released mouse after panning.
		synch; 
	} 
	
		void look(vec2 v)
	{
		if(!v)
		return; 
		v *= rotSpeed; 
		auto d = origin; 
		
		auto ec_pivot = eye.inverse * vec4(pivot, 1); //save pivot
		
		with(eye)
		{ translate(-d);  rotate(-v.x, up); rotate(v.y, right);  /*rotatey(v.x);*/  translate(d);  }
		repairRotation(eye, true); 
		
		pivot = (eye * ec_pivot).xyz; //restore pivot in world space
		synch; 
	} 
	
	
		void rotateAround(mat3 rotation, vec3 center)
	{
		eye.translate(-center); 
		mat4 m; m.set_rotation(rotation); 
		eye = m * eye; 
		eye.translate(center); 
		eye.repairRotation(true); 
		synch; 
	} 
	
		void rotateAroundPivot(mat3 rotation)
	{ rotateAround(rotation, pivot); } 
	
		void rotateAround(vec3 angles, vec3 center)
	{
		if(!angles)
		return; 
		angles *= rotSpeed; 
		mat3 m; 
		
		if(angles.z)
		m.rotate(angles.z, forward); 
		if(angles.y)
		m.rotate(-angles.y, right); 
		
		if(angles.x)
		m.rotatey(-angles.x); 
		//if(angles.x) m.rotate(-angles.x, up);  //ez jobb, ha roll != 0, de rosszabb, ha korbejaras van
		
		rotateAround(m, center); 
	} 
	
		void rotateAround(vec2 angles, vec3 center)
	{ rotateAround(vec3(angles, 0), center); } 
	
		void rotateAroundPivot(vec3 angles)
	{ rotateAround(angles, pivot); } 
	
		void rotateAroundPivot(vec2 angles)
	{ rotateAroundPivot(vec3(angles, 0)); } 
	
		void updatePivot(bool mouseInScreen, in vec3 mousePos, float mouseDepth)
	{
		const mouseOnObject = mouseDepth < 1; 
		if(mouseOnObject)
		{
			pivot = mousePos; //update pivot
		}else
		{
			auto ray = isPerspective ? Ray(origin  , mousePos-origin)
															 : Ray(mousePos, -forward       ); 
			if(auto its = intersect(pivotPlane, ray))
			pivot = its.get; 
		}
		synch; 
	} 
	
		void updatePivot(in Cursor3D mousePos)
	{
		with(mousePos)
		updatePivot(inScreen, world, depth); 
	} 
	
		void zoom(float v, bool mouseInScreen, in vec3 mousePos, float mouseDepth)
	{
		if(!v)
		return; 
		if(mouseInScreen)
		{
			updatePivot(mouseInScreen, mousePos, mouseDepth); 
			
			auto d = pivot - origin; 
			float L = d.length*v*zoomSpeed; 
			L = clamp(L, -zoomMax, zoomMax); 
			d = d.normalized*L; 
			eye.translate(d); 
			
			if(!isPerspective)
			{
					//synch verticalVisibleUnits from origin
				isPerspective = true; 
				synch; 
				isPerspective = false; 
			}
		}
	} 
	
		void zoom(float v, in Cursor3D mousePos)
	{
		with(mousePos)
		zoom(v, inScreen, world, depth); 
	} 
	
	
		void lookFrom(const vec3 target, const vec3 dir, float dist)
	{
		auto d = -normalize(dir),
			 u = vec3(0, 1, 0),
			 l = cross(u, d); 
			 u = cross(d, l); 
		auto e = target - d*dist; 
		eye = mat4(vec4(l, 0), vec4(u, 0), vec4(d, 0), vec4(e, 1)).transposed; 
		
		pivot = target; 
		synch; 
	} 
	
	//void lookFrom(const vec3 target_, const vec3 dir, const AABB3   aabb , int width, int height, float step=1, float scale=1.15f);
	//void lookFrom(const vec3 target_, const vec3 dir, const AABB3[] aabbs, int width, int height, float step=1, float scale=1.15f);
	
	//bool updateAnimation(float dt);
	
		void setupCameraMatrices   (int width, int height, bool subRect, int x0, int y0, int x1, int y1, out mat4 mView, out mat4 mProjection)
	{
		synch; //just to make sure
		
		auto top	= near*tanFovY,
			 bottom	= -top,
			 aspect	= (cast(float)width)/(height>1 ? height : 1),  //Todo: itt meg a max()-ot bassza el a gl3n...
			 right	= top*aspect,
			 left	= -right; 
		
		void mp(float l, float r, float b, float t, float n, float f)
		{
				//Todo: refactor this big mess
			auto persp()
			{ return mat4.perspective(l, r, b, t, n, f); } 
			auto ortho()
			{
				//print(top-bottom, top, bottom);
				//auto s = /*1/(scale)*/ (173.042616451f/1000)*2000;
				//ha s = 173.042616451f, akkor az ablak fuggoleges iranyaban 1000 egyseg latszik.
				
				auto s = verticalVisibleUnits/(t-b); 
				
				return mat4.orthographic(l*s, r*s, b*s, t*s, -f, f); 
			} 
			
			/*
				if(perspective.inRange(0.01, 0.99)){
								auto p = persp, o = ortho, a = pow(perspective.remap(0, 1, 0.49, 0.81), 20);
								foreach(i; 0..4) foreach(j; 0..4) mProjection.matrix[i][j] = lerp(o.matrix[i][j], p.matrix[i][j], a);
							}else{
								mProjection = perspective>=.5 ? persp : ortho;
							}
			*/
			
			mProjection = isPerspective ? persp : ortho; 
		} 
		
		if(subRect)
		{
			auto xRemap(int x)
			{ return remap(x, 0, width , left, right ); } 
			auto yRemap(int y)
			{ return remap(y, 0, height, top , bottom); } 
			mp(xRemap(x0), xRemap(x1), yRemap(y1), yRemap(y0), near, far); 
		}else
		{ mp(left, right, bottom, top, near, far); }
		
		mView = lookAt(origin, origin+axis(2), axis(1)); 
	} 
	
	
		void navigate(bool keysEnabled, bool mouseEnabled, float clientHeight, in Cursor3D cursor)
	{
		if(keysEnabled)
		if(inputs.Home.pressed)
		reset; 
		
		if(mouseEnabled)
		{
				//Todo: implement system-wide mouse capture
			vec2 md = vec2(inputs.MX.delta, inputs.MY.delta); 
			
			if(inputs.MMB.pressed)
			updatePivot(cursor); //right before panning
			
			if(inputs.MMB.active)
			pan(md, clientHeight); 
			if(inputs.RMB.active)
			{
						 if(inputs.Ctrl .active)
				look(md*-.5); 
				else if(inputs.Shift.active) rotateAroundPivot(vec3(0, 0, md.x)); 
				else rotateAroundPivot(md); 
			}
			zoom(inputs.MW.delta*2, cursor); 
		}
	} 
	
	
	/*
		void glSetupCamera         (int width, int height, float _far, bool subRect=false, int x0=0, int y0=0, int x1=0, int y1=0);
		void glSetupCamera_animated(int width, int height, float _far, bool subRect=false, int x0=0, int y0=0, int x1=0, int y1=0);
	*/
	
} ; 



/+
	void Camera::lookFrom(const vec3& _target, const vec3& dir, const QVector<bounds3>& aabbs, int width, int height, float step, float scale)
	{
		float dist=step;
		const float maxDist=5000;
	
		lookFrom(_target, dir, dist);
	/*  M44f v, p;
		setupCameraMatrices(width, height, 10000, false, 0,0,0,0, v, p);
		Frustum fr(v*p);*/
	
		glSetupCamera(width, height, maxDist*2, false, 0,0,0,0);
		M44f mVP(glst.mView*glst.mProjection);
		Frustum fr(mVP);
	
		vec3 d = -dir.normalized();
	
		FOR(i, aabbs){
			while(fr.isAABB_outside(aabbs.at(i).translated(d*dist))){
				dist += step;
				if(dist>=maxDist) goto done;
			}
		}
	
	done:
	//  if(dist>=maxDist) dist=step;
	
		dist = min(dist*scale, maxDist);
		lookFrom(_target, dir, dist);
	}
	
	
	void Camera::lookFrom(const vec3& _target, const vec3& dir, const bounds3& aabb, int width, int height, float step, float scale)
	{
		lookFrom(_target, dir, QVector<bounds3>()<<aabb, width, height, step, scale);
	} 
+/



/+
	void Camera::glSetupCamera(int width,int height, float _far, bool subRect, int x0, int y0, int x1, int y1)
	{
		setupCameraMatrices(width, height, _far, subRect, x0, y0, x1, y1, glst.mView, glst.mProjection);
		glst.mModel = identityM44f();
		glst.light_pos = lightPos_slow;
	}
	
	
	void Camera::glSetupCamera_animated(int width, int height, float _far, bool subRect, int x0, int y0, int x1, int y1)
	{
		M44f backup = eye; eye = eye_animated;
		glSetupCamera(width, height, _far, subRect, x0, y0, x1, y1);
		eye = backup;
	} 
+/


/*
	bool Camera::updateAnimation(float dt)
	{
		int u = 0;
		u += follow(eye_animated, eye,	animationT(dt, .6f, .21f), 0.001f, false);	//move	camera slowly
		u += follow(lightPos_slow, eye_animated.row(3),	animationT(dt, .8f, .21f),	1);	//make light follow camera
		return u;
	} 
*/

//STL file load ////////////////////////////////////////////
enum STLFormat
{ binary, ascii} ; 

struct STLTri
{
	align(1): 
		vec3 n; 
		vec3[3] v; 
		ushort attr; //must ignore!!!!
} ; 

vec3[] loadBinStl(string s)
{
	static assert(STLTri.sizeof==50); 
	
	const len = s.length; 
	enforce(len>=84, "STL file format error: too small header"); 
	
	const cnt = *(cast(const int*)(s.ptr+80)); 
	enforce(cnt <= (len-84)/STLTri.sizeof, "STL file format error: Corrupt tiangle count"); 
	
	auto res = (cast(const STLTri*)(s.ptr+84))[0..cnt].map!(t => t.v.dup).join; 
	
	/+
		const doFlip = s.startsWith("solid "); //note: 200907 a solid4-hez nem kell, mert valami total kaosz jon abbol
			if(doFlip) foreach(ref v; res) { v.z = -v.z; }
	+/
	
	foreach(ref v; res)
	{ swap(v.z, v.y); v.z = -v.z; }
	
	return res; 
} 

vec3[] loadTextStl(string s)
{
		enforce(0, "not impl"); 
		return []; 
	/*
		int vid=0;
		STLBinaryTriangle tri;
		
		bool doFlip = ba.startsWith("solid "); //igy megy a cura is
		
		foreach(QString line, ba.split('\n')) {
			QStringList parts = line.trimmed().split(' ',QString::SkipEmptyParts);
			#define item(n) ((n)<parts.count()?parts.at(n):QString(""))
		
			QString cmd = item(0);
			if(cmd=="vertex") {
				if(vid<3) for(int i=0; i<3; i++) tri.v[vid].coord(i) = item(i+1).toFloat();
				vid++;
			}else if(cmd=="endloop") {
				if(vid==3) appendSTLTriangle(faces, tri, doFlip);
				vid = 0;
			}
		
			#undef item
		}
	*/
} 


vec3[] loadStl(string s)
{
	enforce(s.length, "STL file format error: empty file."); 
	
	const isBinary = s.length>83 && !s[83].inRange(9, 127); //assume no valid ascii character under 9 or over 127
	return isBinary ? s.loadBinStl
									: s.loadTextStl; 
} 

vec3[] loadStl(File f)
{ return f.readStr.loadStl; } 


//3d line drawing ///////////////////////////////////////////////////////

class LineDrawing
{
	struct LineVertex
	{
		vec3 aPosition;  //*** the fieldnames must match the name of the shader attributes!
		uint aColor; 
	} 
	
	private LineVertex[] vertices; 
	private VBO vbo_; 
	private bool vboValid; 
	
	VBO vbo()
	{
		if(chkSet(vboValid))
		vbo_ = null; 
		if(vbo_ is null && vertices.length)
		vbo_ = new VBO(vertices); 
		return vbo_; 
	} 
	
	void addLine(in vec3 p0, in vec3 p1, in RGB cl0, in RGB cl1)
	{ vertices ~= [LineVertex(p0, cl0), LineVertex(p1, cl1)]; vboValid = false; } 
	void addLine(in vec3 p0, in vec3 p1, in RGB cl)
	{ addLine(p0, p1, cl, cl); } 
	
	void addAxes(mat4 m, float scale = 1)
	{
		vec3 v(int n)()
		{ return vec3(m.matrix[0][n], m.matrix[1][n], m.matrix[2][n]); } //!!!!!!!!!!! fel van cserelve a column meg a row!!!!!!!!
		addLine(v!3, v!3+v!0*scale, clAxisX); 
		addLine(v!3, v!3+v!1*scale, clAxisY); 
		addLine(v!3, v!3+v!2*scale, clAxisZ); 
	} 
	
	void addCross(vec3 center, float size, RGB col)
	{
		addLine(center-vec3(size, 0, 0), center+vec3(size, 0, 0), col); 
		addLine(center-vec3(0, size, 0), center+vec3(0, size, 0), col); 
		addLine(center-vec3(0, 0, size), center+vec3(0, 0, size), col); 
	} 
	
	void addBB(in bounds3 bb, mat4 m, RGB cl = clWhite)
	{
		void a(string s)()
		{
			auto q0 = m * vec4(s[0]=='0' ? bb.bMin.x : bb.bMax.x, s[1]=='0' ? bb.bMin.y : bb.bMax.y, s[2]=='0' ? bb.bMin.z : bb.bMax.z, 1); //Todo: vec3 vec3 interop suxxx
			auto q1 = m * vec4(s[3]=='0' ? bb.bMin.x : bb.bMax.x, s[4]=='0' ? bb.bMin.y : bb.bMax.y, s[5]=='0' ? bb.bMin.z : bb.bMax.z, 1); 
			addLine(vec3(q0.x, q0.y, q0.z), vec3(q1.x, q1.y, q1.z), cl); 
		} 
		a!"000100"; a!"000010"; a!"000001"; 
		a!"010110"; a!"100110"; a!"100101"; 
		a!"001101"; a!"001011"; a!"010011"; 
		a!"011111"; a!"101111"; a!"110111"; 
	} 
	
} 



//3ds loader ///////////////////////////////////////////////////////

//Todo: IDE: warningok ne szamitsanak error-nak.

mixin template FIELD_protected(T, string name)
{ mixin("protected T $_; auto $() const{ return $_; }".replace("$", name)); } 

class Draw3D
{
	 //!Draw3D ////////////////////////////////////////
		Camera cam; 
	
		ibounds2 viewport; 
		Cursor3D cursor; 
	
		//Model matrices, transformations
		mat4 mModel = mat4.identity; 
		mat4[] mStack; 
	
		//debug drawings
		struct Options
	{
		bool
			showWorldAxes,
			showCameraPivot,
			showObjectAxes,
			showObjectBounds; 
			float axisLength = 250; 
		bool showAny()
		{ return this != typeof(this).init; } 
	} 
	
		Options options; 
	
		struct DrawnNode
	{ MeshNode node; mat4 matrix; } 
		DrawnNode[] drawnNodes; //collects all nodes drawn on screen for debug
	
		//calculated from cal
	//protected mat4 mView_, mProjection_, mInverse_; //calculated
	
		mixin FIELD_protected!(mat4, "mView"); 
		mixin FIELD_protected!(mat4, "mProjection"); 
		mixin FIELD_protected!(mat4, "mInverse"); 
	
		this()
	{ cam = new Camera; } 
	
		~this()
	{} 
	
		private bool inFrame; 
	
		float pickedZ; 
		MeshNode pickedNode; 
	
		ivec2 screenMousePos; 
	
		void beginFrame(ivec2 screenMousePos)
	{
		enforce(!inFrame, "already in beginFrame()"); 
		
		this.screenMousePos = screenMousePos; 
		viewport = gl.getViewport; //Todo: proper viewport handling, not just the full window
		cursor.setup(screenMousePos, viewport); 
		
		pickedZ = 1; 
		pickedNode = null; 
		
		cam.setupCameraMatrices(viewport.width, viewport.height, false, 0,0,0,0, mView_, mProjection_); 
		mInverse_ = (mProjection*mView).inverse; 
		mModel = mat4.identity; 
		
		gl.enable(GL_CULL_FACE); 
		gl.frontFace(GL_CCW); 
		gl.enable(GL_DEPTH_TEST); 
		gl.disable(GL_BLEND); 
		gl.disable(GL_ALPHA_TEST); 
		
		drawnNodes = []; 
		
		inFrame = true; 
	} 
	
		void endFrame()
	{
		enforce(inFrame, "endFrame() without beginFrame()"); 
		
		if(options.showAny)
		drawDebugStuff; 
		drawnNodes = []; 
		
		cursor.glProcess(mInverse); //get the world cursor from depth
		
		inFrame = false; 
	} 
	
		void navigate(bool keysEnabled, bool mouseEnabled)
	{ cam.navigate(keysEnabled, mouseEnabled, viewport.height, cursor); } 
	
		/// gets a cursor at a specific moment. Slow because of depth read.
		auto getCursor(ivec2 screenMousePos)
	{
		Cursor3D res; 
		viewport = gl.getViewport; //Todo: proper viewport handling, not just the full window
		res.setup(screenMousePos, viewport); 
		res.glProcess(mInverse); 
		return res; 
	} 
		auto getCursor()
	{ return getCursor(screenMousePos); } 
	
		void pushMatrix()
	{ mStack ~= mModel; } 
		void popMatrix()
	{
		enforce(mModel.length, "Unable to pop matrix. Matrix stack is empty"); 
		mModel = mStack[$-1]; 
		mStack = mStack[0..$-1]; 
	} 
	
		void translate(in vec3 v)
	{/*pushMatrix;*/ mModel.translate(v); } 
		void translate(float x, float y, float z)
	{/*pushMatrix;*/ mModel.translate(x, y, z); } 
		void scale(float f)
	{/*pushMatrix;*/ mModel.scale(f, f, f); } 
		void rotatex(float f)
	{/*pushMatrix;*/ mModel.rotatex(f); } 
		void rotatey(float f)
	{/*pushMatrix;*/ mModel.rotatey(f); } 
		void rotatez(float f)
	{/*pushMatrix;*/ mModel.rotatez(f); } 
		void rotate(float f, in vec3 a)
	{/*pushMatrix;*/ mModel.rotate(f, a); } 
	
		struct VRecord
	{ vec3 aPosition; } ; 
	
		void draw(VBO vbo, RGBA color = clWhite)
	{
		enum src_color = q{
			#version 150
			
			@vertex:
			in	vec3 aPosition;
			out	vec3 gPosition;
			
			void main()
			{ gPosition = aPosition;}
			
			@geometry:
			layout(triangles) in;
			layout(triangle_strip, max_vertices = 3) out;
			
			in vec3 gPosition[];
			flat out vec3 wc_normal;
			out vec3 wc_position;
			
			uniform mat4 mvp_matrix;
			uniform mat4 m_matrix;
			
			void emit(vec3 pos)
			{
				gl_Position = mvp_matrix*vec4(pos, 1);
				wc_position = vec3(m_matrix * vec4(pos, 1));
				EmitVertex();
			}
			
			void main()
			{
				wc_normal = normalize(mat3(m_matrix)*(cross(gPosition[0]-gPosition[1], gPosition[0]-gPosition[2])));
				for(int i=0; i<3; i++) emit(gPosition[i]); //EndPrimitive();
			}
			
			@fragment:
			
			uniform vec4 color;
			uniform vec3 wc_light;  //central lighting
			
			flat in vec3 wc_normal;
			in vec3 wc_position;
			
			//uniform sampler2D smpSilicon; //temporal sampler test
			
			void main(void) 
			{
				float diffuse = dot(normalize(wc_light-wc_position), normalize(wc_normal));
				
				vec3 ambientColor = color.rgb*0.15;
				vec3 diffuseColor = color.rgb*(diffuse*0.85);
				
				//experimental silicon wafer shader
				/*
					float side = fract(wc_position.x*0.1) > 0.5 ? 1 : -1;
					vec2 tc = vec2(0.8, 0.5 + diffuse*0.5*side);
					vec3 silicon = texture(smpSilicon, tc).rgb + vec3(0.4, 0.4, 0.4);
					diffuseColor *= silicon;
				*/
				
				gl_FragColor = vec4(ambientColor+diffuseColor ,0);
			}
		}; 
		
		static Shader sh; 
		if(sh is null)
		{ sh = new Shader("shader1", src_color); }
		
		sh.attrib(vbo); 
		
		auto p = mProjection; 
		auto v = mView; 
		auto m = mModel; 
		
		sh.uniform("mvp_matrix"     , (p*v*m).matrix); 
		sh.uniform("m_matrix"       , (m).matrix, false); 
		sh.uniform("color"          , color.rgbaf.comp); 
		
		/*
			static GLTexture tSilicon;
			if(tSilicon is null){
				auto b = newBitmap(`c:\dl\siliconWaferColorTexture.png`);
				tSilicon = new GLTexture("siliconWafer", b.width, b.height, GLTextureType.RGBA8, false);
				tSilicon.bind(0, GLTextureFilter.Linear, true);
				tSilicon.upload(b); //todo: ha nincs bind, akkor itt nincs exception, csak crash van. Kideriteni, hogy mi a gecikurvaisten kibaszott faszaert van ez?
			}
			tSilicon.bind(0, GLTextureFilter.Linear, true);
			sh.uniform("smpSilicon", 0);
		*/
		
		const isPerspective = p.matrix[3][3] == 0; 
		
		auto wc_light = vec3(v.inverse * vec4(0, 0, isPerspective ? 0 : 2*cam.far, 1)); //light from camera or behind camera in axonometric view.  *2 because (near plane = -far)
		sh.uniform("wc_light"       , wc_light.vector); 
		
		vbo.draw(GL_TRIANGLES); 
		
		//Todo: Mukodik-e a vertical tab a shaderben...
	} 
	
		void draw(MeshObject mesh, RGBA color)
	{ draw(mesh.vbo, color); } 
	
		void draw(MeshNode node, RGBA color, bool onlyThisObject = false)
	{
		if(node is null)
		return; 
		
		pushMatrix; scope(exit) popMatrix; 
		mModel = mModel * node.fullTransform; 
		
		if(options.showAny)
		drawnNodes ~= DrawnNode(node, mModel); 
		
		if(node.object !is null)
		{
			draw(node.object.vbo, opBinary!"*"(node.object.color, color)); //Todo: nem jo a color szorzas, mert implicit uint konverzio van
		}
		
		//experimental picking
		if(0)
		{
			cursor.readDepth; 
			if(chkSet(pickedZ, cursor.depth))
			pickedNode = node; //Todo: ez a modszer kurvalassu, mert allando ketiranyu kommunikaciot igenyel a kartyatol.
		}
		
		if(onlyThisObject)
		return; 
		
		mModel = mModel*mat4.identity.translate(node.pivot); //Todo: this should be a pre-translation, not a post-translation which is the same for every children.
		
		foreach(sn; node.subNodes)
		draw(sn, color); 
	} 
	
		void draw(Model model, RGBA color = clWhite)
	{ draw(model.root, opBinary!"*"(model.color, color)); } 
	
	
		void draw(LineDrawing ld)
	{
		auto vbo = ld.vbo; 
		if(vbo is null)
		return; 
		
		static Shader shader;   //! Line Debug Shader ///////////////////////////////////////////
		if(!shader)
		shader = new Shader(
			"LineShader", q{
				#version 150
				
				@vertex: 
				in vec3 aPosition; 
				in vec3 aColor; 
				
				out vec3 fColor; 
				
				uniform mat4 mvp_matrix; 
				
				void main()
				{
					gl_Position = mvp_matrix * vec4(aPosition, 1); 
					fColor = aColor; 
				} 
				
				@fragment: 
				in vec3 fColor; 
				
				void main()
				{ gl_FragColor = vec4(fColor, 0); } 
			}
		); 
		
		shader.uniform("mvp_matrix", (mProjection*mView*mModel).matrix); 
		shader.attrib(vbo); 
		
		gl.depthMask(false); 
		gl.enable(GL_DEPTH_TEST); 
		gl.depthFunc(GL_GEQUAL); 
		
		gl.enable(GL_BLEND); 
		gl.blendFunc(GL_CONSTANT_ALPHA, GL_ONE_MINUS_CONSTANT_ALPHA); 
		gl.blendColor(0, 0, 0, .33); 
		
		vbo.draw(GL_LINES); //draw hidden
		
		gl.disable(GL_BLEND); 
		gl.depthFunc(GL_LESS);  //this is the normal
		
		vbo.draw(GL_LINES); //draw foreground ones
		
		gl.enable(GL_DEPTH_TEST); 
		gl.depthMask(true); 
		
	} 
	
		void drawDebugStuff()
	{
		if(!options.showAny)
		return; 
		gl.lineWidth(1); 
		
		//everything here is in world coords
		pushMatrix; scope(exit) popMatrix; 
		mModel = mat4.identity; 
		
		if(options.showObjectBounds)
		{
				auto ld = new LineDrawing; 
			foreach(dn; drawnNodes)
			ld.addBB(dn.node.object.bounds, dn.matrix, pickedNode==dn.node ? clFuchsia : clWhite); 
			draw(ld); 
		}
		
		if(options.showWorldAxes)
		{
				auto ld = new LineDrawing; 
			ld.addAxes(mat4.identity, cam.far); 
			draw(ld); 
		}
		
		if(options.showCameraPivot)
		{
				auto ld = new LineDrawing; 
			auto c = vec3(cam.pivot.x, cam.pivot.y, cam.pivot.z),
								d = vec3(cam.pivotPlaneCenter.x, cam.pivotPlaneCenter.y, cam.pivotPlaneCenter.z),
								a = options.axisLength/3; 
			
			auto c1 = clFuchsia, c2 = clWhite; 
			ld.addCross(c, a, c1); 
			ld.addLine(c, d, c1, c2); ld.addCross(d, a, c2);  //pivotPlaneCenter
			
			draw(ld); 
		}
		
		if(options.showObjectAxes)
		{
				auto ld = new LineDrawing; 
			foreach(dn; drawnNodes)
			ld.addAxes(dn.matrix, options.axisLength); 
			gl.lineWidth(3); 
			draw(ld); 
		}
		
		gl.lineWidth(1); 
	} 
	
} 


//! 3DS ChunkIDs ///////////////////////////////

enum ChunkID : ushort
{
	//3DS File Chunk IDs ////////////////////////
	
	M3DMAGIC		= 0x4D4D,
	SMAGIC						    =	0x2D2D,
	LMAGIC						    =	0x2D3D,
	MLIBMAGIC	         = 0x3DAA,
	MATMAGIC	         = 0x3DFF,
	M3D_VERSION	         =	0x0002,
	M3D_KFVERSION		= 0x0005,
	
	//Mesh Chunk Ids ////////////////////////////
	
	MDATA	      = 0x3D3D,
	MESH_VERSION	      = 0x3D3E,
	COLOR_F	      = 0x0010,
	COLOR_24	      = 0x0011,
	LIN_COLOR_24	      = 0x0012,
	LIN_COLOR_F	      = 0x0013,
	INT_PERCENTAGE	      =	0x0030,
	FLOAT_PERCENTAGE		= 0x0031,
	
	MASTER_SCALE           = 0x0100,
	
	BIT_MAP	        = 0x1100,
	USE_BIT_MAP	        = 0x1101,
	SOLID_BGND	        = 0x1200,
	USE_SOLID_BGND	        = 0x1201,
	V_GRADIENT	        = 0x1300,
	USE_V_GRADIENT	        = 0x1301,
	
	LO_SHADOW_BIAS						  = 0x1400,
	HI_SHADOW_BIAS						  = 0x1410,
	SHADOW_MAP_SIZE	       = 0x1420,
	SHADOW_SAMPLES		= 0x1430,
	SHADOW_RANGE	       =	0x1440,
	SHADOW_FILTER	       = 0x1450,
	RAY_BIAS	       = 0x1460,
	
	O_CONSTS               = 0x1500,
	
	AMBIENT_LIGHT          = 0x2100,
	
	FOG	      = 0x2200,
	USE_FOG	      = 0x2201,
	FOG_BGND	      = 0x2210,
	DISTANCE_CUE	      = 0x2300,
	USE_DISTANCE_CUE	      = 0x2301,
	LAYER_FOG	      = 0x2302,
	USE_LAYER_FOG	      = 0x2303,
	DCUE_BGND	      = 0x2310,
	
	DEFAULT_VIEW	          = 0x3000,
	VIEW_TOP	          = 0x3010,
	VIEW_BOTTOM		= 0x3020,
	VIEW_LEFT	          =	0x3030,
	VIEW_RIGHT						     = 0x3040,
	VIEW_FRONT						     = 0x3050,
	VIEW_BACK						     =	0x3060,
	VIEW_USER						     =	0x3070,
	VIEW_CAMERA		= 0x3080,
	VIEW_WINDOW		= 0x3090,
	
	NAMED_OBJECT		= 0x4000,
	OBJ_HIDDEN	    =	0x4010,
	OBJ_VIS_LOFTER	    = 0x4011,
	OBJ_DOESNT_CAST	    = 0x4012,
	OBJ_MATTE	    = 0x4013,
	OBJ_FAST	    = 0x4014,
	OBJ_PROCEDURAL	    = 0x4015,
	OBJ_FROZEN	    = 0x4016,
	OBJ_DONT_RCVSHADOW	    = 0x4017,
	
	N_TRI_OBJECT           = 0x4100,
	
	POINT_ARRAY	     = 0x4110,
	POINT_FLAG_ARRAY	     = 0x4111,
	FACE_ARRAY	     = 0x4120,
	MSH_MAT_GROUP					 = 0x4130,
	OLD_MAT_GROUP					 = 0x4131,
	TEX_VERTS	     = 0x4140,
	SMOOTH_GROUP	     = 0x4150,
	MESH_MATRIX	     = 0x4160,
	MESH_COLOR	     = 0x4165,
	MESH_TEXTURE_INFO	     = 0x4170,
	PROC_NAME					 = 0x4181,
	PROC_DATA					 = 0x4182,
	MSH_BOXMAP	     = 0x4190,
	
	N_D_L_OLD              = 0x4400,
	
	N_CAM_OLD              = 0x4500,
	
	N_DIRECT_LIGHT		= 0x4600,
	DL_SPOTLIGHT	   =	0x4610,
	DL_OFF	   = 0x4620,
	DL_ATTENUATE		= 0x4625,
	DL_RAYSHAD	   =	0x4627,
	DL_SHADOWED	   = 0x4630,
	DL_LOCAL_SHADOW	   = 0x4640,
	DL_LOCAL_SHADOW2	   = 0x4641,
	DL_SEE_CONE	   = 0x4650,
	DL_SPOT_RECTANGULAR		= 0x4651,
	DL_SPOT_OVERSHOOT			 =	0x4652,
	DL_SPOT_PROJECTOR			 =	0x4653,
	DL_EXCLUDE		= 0x4654,
	DL_RANGE	   =	0x4655, /*Not used in R3*/
	DL_SPOT_ROLL	   =	0x4656,
	DL_SPOT_ASPECT		= 0x4657,
	DL_RAY_BIAS		= 0x4658,
	DL_INNER_RANGE	= 0x4659,
	DL_OUTER_RANGE	= 0x465A,
	DL_MULTIPLIER = 0x465B,
	
	N_AMBIENT_LIGHT        = 0x4680,
	
	N_CAMERA	          = 0x4700,
	CAM_SEE_CONE		= 0x4710,
	CAM_RANGES	          =	0x4720,
	
	HIERARCHY	         = 0x4F00,
	PARENT_OBJECT	         = 0x4F10,
	PIVOT_OBJECT						    = 0x4F20,
	PIVOT_LIMITS						    = 0x4F30,
	PIVOT_ORDER						    = 0x4F40,
	XLATE_RANGE						    = 0x4F50,
	
	POLY_2D                = 0x5000,
	
	//Flags in shaper file ////////////////////////////
	
	SHAPE_OK	          = 0x5010,
	SHAPE_NOT_OK	          = 0x5011,
	
	SHAPE_HOOK             = 0x5020,
	
	PATH_3D	          = 0x6000,
	PATH_MATRIX	          = 0x6005,
	SHAPE_2D	          = 0x6010,
	M_SCALE						     = 0x6020,
	M_TWIST						     = 0x6030,
	M_TEETER	          = 0x6040,
	M_FIT	          =	0x6050,
	M_BEVEL		= 0x6060,
	XZ_CURVE						     = 0x6070,
	YZ_CURVE						     = 0x6080,
	INTERPCT						     = 0x6090,
	DEFORM_LIMIT	          = 0x60A0,
	
	//Flags for Modeler options /////////////////////
	
	USE_CONTOUR		= 0x6100,
	USE_TWEEN						      =	0x6110,
	USE_SCALE						      =	0x6120,
	USE_TWIST						      =	0x6130,
	USE_TEETER	           = 0x6140,
	USE_FIT	           =	0x6150,
	USE_BEVEL		= 0x6160,
	
	//Viewport description chunks /////////////////////
	
	VIEWPORT_LAYOUT_OLD		= 0x7000,
	VIEWPORT_DATA_OLD		=	0x7010,
	VIEWPORT_LAYOUT		=	0x7001,
	VIEWPORT_DATA	   =	0x7011,
	VIEWPORT_DATA_3		= 0x7012,
	VIEWPORT_SIZE	   =	0x7020,
	NETWORK_VIEW	   = 0x7030,
	
	//External Application Data //////////////////////
	
	XDATA_SECTION		= 0x8000,
	XDATA_ENTRY	         =	0x8001,
	XDATA_APPNAME		= 0x8002,
	XDATA_STRING	         = 0x8003,
	XDATA_FLOAT	         = 0x8004,
	XDATA_DOUBLE	         = 0x8005,
	XDATA_SHORT	         = 0x8006,
	XDATA_LONG = 0x8007,
	XDATA_VOID = 0x8008,
	XDATA_GROUP = 0x8009,
	XDATA_RFU6 = 0x800A,
	XDATA_RFU5 = 0x800B,
	XDATA_RFU4 = 0x800C,
	XDATA_RFU3 = 0x800D,
	XDATA_RFU2 = 0x800E,
	XDATA_RFU1 = 0x800F,
	
	PARENT_NAME = 0x80F0,
	
	//Material Chunk IDs ////////////////////////////
	
	MAT_ENTRY	         = 0xAFFF,
	MAT_NAME	         = 0xA000,
	MAT_AMBIENT						    = 0xA010,
	MAT_DIFFUSE						    = 0xA020,
	MAT_SPECULAR	         = 0xA030,
	MAT_SHININESS	         = 0xA040,
	MAT_SHIN2PCT        = 0xA041,
	MAT_SHIN3PCT         = 0xA042,
	MAT_TRANSPARENCY	     = 0xA050,
	MAT_XPFALL		     = 0xA052,
	MAT_REFBLUR	           = 0xA053,
	
	MAT_SELF_ILLUM		= 0xA080,
	MAT_TWO_SIDE	        =	0xA081,
	MAT_DECAL	        = 0xA082,
	MAT_ADDITIVE	        = 0xA083,
	MAT_SELF_ILPCT      = 0xA084,
	MAT_WIRE      = 0xA085,
	MAT_SUPERSMP					 = 0xA086,
	MAT_WIRESIZE					 = 0xA087,
	MAT_FACEMAP      = 0xA088,
	MAT_XPFALLIN      = 0xA08A,
	MAT_PHONGSOFT	= 0xA08C,
	MAT_WIREABS    =	0xA08E,
	
	MAT_SHADING            = 0xA100,
	
	MAT_TEXMAP	      = 0xA200,
	MAT_OPACMAP						 = 0xA210,
	MAT_REFLMAP						 = 0xA220,
	MAT_BUMPMAP						 = 0xA230,
	MAT_SPECMAP						 = 0xA204,
	MAT_USE_XPFALL	      = 0xA240,
	MAT_USE_REFBLUR	      = 0xA250,
	MAT_BUMP_PERCENT	      = 0xA252,
	
	MAT_MAPNAME	           = 0xA300,
	MAT_ACUBIC	           = 0xA310,
	
	MAT_SXP_TEXT_DATA		= 0xA320,
	MAT_SXP_TEXT2_DATA		=	0xA321,
	MAT_SXP_OPAC_DATA				=	0xA322,
	MAT_SXP_BUMP_DATA				=	0xA324,
	MAT_SXP_SPEC_DATA				=	0xA325,
	MAT_SXP_SHIN_DATA			=	0xA326,
	MAT_SXP_SELFI_DATA	=	0xA328,
	MAT_SXP_TEXT_MASKDATA	= 0xA32A,
	MAT_SXP_TEXT2_MASKDATA	= 0xA32C,
	MAT_SXP_OPAC_MASKDATA	= 0xA32E,
	MAT_SXP_BUMP_MASKDATA	= 0xA330,
	MAT_SXP_SPEC_MASKDATA	= 0xA332,
	MAT_SXP_SHIN_MASKDATA	= 0xA334,
	MAT_SXP_SELFI_MASKDATA	= 0xA336,
	MAT_SXP_REFL_MASKDATA	= 0xA338,
	MAT_TEX2MAP						 = 0xA33A,
	MAT_SHINMAP						 = 0xA33C,
	MAT_SELFIMAP     = 0xA33D,
	MAT_TEXMASK       = 0xA33E,
	MAT_TEX2MASK				 = 0xA340,
	MAT_OPACMASK				 = 0xA342,
	MAT_BUMPMASK				 = 0xA344,
	MAT_SHINMASK				 = 0xA346,
	MAT_SPECMASK				 = 0xA348,
	MAT_SELFIMASK     = 0xA34A,
	MAT_REFLMASK     = 0xA34C,
	MAT_MAP_TILINGOLD     = 0xA350,
	MAT_MAP_TILING     = 0xA351,
	MAT_MAP_TEXBLUR_OLD     = 0xA352,
	MAT_MAP_TEXBLUR     = 0xA353,
	MAT_MAP_USCALE				 = 0xA354,
	MAT_MAP_VSCALE				 = 0xA356,
	MAT_MAP_UOFFSET	=	0xA358,
	MAT_MAP_VOFFSET	=	0xA35A,
	MAT_MAP_ANG	=	0xA35C,
	MAT_MAP_COL1				 = 0xA360,
	MAT_MAP_COL2				 = 0xA362,
	MAT_MAP_RCOL				 = 0xA364,
	MAT_MAP_GCOL				 = 0xA366,
	MAT_MAP_BCOL				 = 0xA368,
	
	//Keyframe Chunk IDs ///////////////////////
	
	KFDATA	    = 0xB000,
	KFHDR	    = 0xB00A,
	AMBIENT_NODE_TAG	    = 0xB001,
	OBJECT_NODE_TAG				 = 0xB002,
	CAMERA_NODE_TAG				 = 0xB003,
	TARGET_NODE_TAG				 = 0xB004,
	LIGHT_NODE_TAG	    = 0xB005,
	L_TARGET_NODE_TAG	    = 0xB006,
	SPOTLIGHT_NODE_TAG	    = 0xB007,
	
	KFSEG	       = 0xB008,
	KFCURTIME	       = 0xB009,
	NODE_HDR	       = 0xB010,
	INSTANCE_NAME	       = 0xB011,
	PRESCALE	       = 0xB012,
	PIVOT	       = 0xB013,
	BOUNDBOX	       = 0xB014,
	MORPH_SMOOTH	       = 0xB015,
	POS_TRACK_TAG						  = 0xB020,
	ROT_TRACK_TAG						  = 0xB021,
	SCL_TRACK_TAG						  = 0xB022,
	FOV_TRACK_TAG						  = 0xB023,
	ROLL_TRACK_TAG	       = 0xB024,
	COL_TRACK_TAG	       =	0xB025,
	MORPH_TRACK_TAG		= 0xB026,
	HOT_TRACK_TAG	       =	0xB027,
	FALL_TRACK_TAG						  = 0xB028,
	HIDE_TRACK_TAG						  = 0xB029,
	NODE_ID	       = 0xB030,
} 


string toString(in ChunkID id)
{
	auto s = id.to!string; 
	if(s.startsWith("cast("))
	s = format!"\33\14UNKOWN(0x%04x)\33\7"(cast(int)id); 
	return s; 
} 

struct Chunk
{
	 align(1): 
		ChunkID id; 
		uint nextChunk; 
		ubyte[] data; 
	
		auto toString() const
	{ return "%s (siz:%d) ".format(id.toString, data.length); } 
} 

class MeshObject
{
		 //! MeshObject ///////////////////////////////
		alias Index = uint; //ushort;
	
		string name; 
		mat4 mTransform_import = mat4.identity; //Todo: redundant. only needed for loading.
		RGBA color = clWhite; 
		vec3[] vertices; 
		vec2[] texCoords; 
		Index[4][] faces;  //last is 3x edge flag for wireframe
	
		//Todo: optimize mesh,
		//Todo: automatic ushort/uint vertex indices
	
		import core.atomic; 
		shared static int instanceCount; 
	
		this(string name)
	{
		instanceCount.atomicOp!"+="(1); 
		this.name = name; 
	} 
	
		~this()
	{
			//Todo: resource handling-ot at kell irni synchronized-re!
		//vbo_.free;
		//"success".writeln;
			instanceCount.atomicOp!"-="(1); 
	} 
	
		void geometryChanged()
	{
		boundsValid = false; 
		vboValid = false; 
	} 
	
		private bool vboValid; 
		private VBO cachedVbo; 
	
		VBO vbo()
	{
		if(chkSet(vboValid))
		cachedVbo = new VBO(cast(VertexRec[])(trimesh)); 
		
		return cachedVbo; 
	} 
	
		override string toString()
	{ return "MeshObject(%s, v:%s, t:%s, f:%s,\n mTrans:%s, \n%s)".format(name, vertices.length, texCoords.length, faces.length, mTransform_import, bounds); } 
	
		vec3[] trimesh()
	{ return faces.map!(f => [vertices[f[0]], vertices[f[1]], vertices[f[2]]]).join; } 
	
		private static
	{
		auto u4(size_t a, size_t b, size_t c)
		{ Index[4] f = [cast(Index)(a), cast(Index)(b  ), cast(Index)(c  ), 7]; return f; } 
		auto u4(size_t i)
		{ return u4(i, i+1, i+2); } 
	} 
	
		void appendTrimesh(vec3[] v)
	{
		 //simple stl import
		//Todo: textcoords
		auto vBase = vertices.length; 
		vertices ~= v; 
		
		faces ~= iota(v.length/3).map!(i => u4(i*3+vBase)).array; 
		
		geometryChanged; 
	} 
	
		void appendTrimesh(float[] v, int[] idx)
	{
		auto vBase = vertices.length; 
		
		vertices ~= cast(vec3[])v; 
		faces ~= iota(idx.length/3).map!(i => u4(idx[i*3], idx[i*3+1], idx[i*3+2])).array; 
		
		geometryChanged; 
	} 
	
		private bool boundsValid; 
		private bounds3 cachedBounds; 
	
		bounds3 bounds()
	{
		if(chkSet(boundsValid))
		cachedBounds = bounds3(vertices.map!(v=>vec3(v.x, v.y, v.z)).array); 
		return cachedBounds; 
	} 
	
		void transformVertices(in mat4 m)
	{
		foreach(ref v; vertices)
		v = (m * vec4(v, 1)).xyz; 
		geometryChanged; 
	} 
	
	protected: 
		//mesh building functions
		static int base; 
		void setBase()                       
	{ int base = vertices.length.to!int; } 
		void v(in vec3 a)                    
	{
		vertices ~= a; if(!texCoords.empty)
		texCoords ~= vec2(0); 
	} 
		void v(float x, float y, float z)    
	{ v(vec3(x, y, z)); } 
		void f(int a, int b, int c)          
	{ Index[4] r = [(base+a).to!Index, (base+b).to!Index, (base+c).to!Index, 0]; faces ~= r; } 
		void q(int a, int b, int c, int d)   
	{ f(a, b, c);  f(c, b, d); } 
	
		void addBox(bounds3 bnd)
	{
			setBase; 
		bnd.sortBounds; 
		with(bnd)
		foreach(x; [bMin.x, bMax.x])
		foreach(y; [bMin.y, bMax.y])
		foreach(z; [bMin.z, bMax.z])
		v(x, y, z); 
		q(0,1,2,3); 	 q(5,4,7,6); 
		q(0,2,4,6); 	 q(3,1,7,5); 
		q(0,4,1,5); 	 q(6,2,7,3); 
	} 
	
	
		void addPoly(in TessResult tess, float y0=0, float y1=1)
	{
			setBase; 
		sort(y0, y1); 
		if(y0==y1)
		{
				//zero thickness
			foreach(const p; tess.vertices)
			v(vec3(p.x, y0, p.y)); 
			
			foreach(const t; tess.triangles)
			f(t[0], t[1], t[2]); //bottom
			foreach(const t; tess.triangles)
			f(t[2], t[1], t[0]); //top
		}else
		{
				//nonzero thickness
			foreach(const p; tess.vertices)
			{
					v(vec3(p.x, y0, p.y)); 
				v(vec3(p.x, y1, p.y)); 
			}
			
			foreach(const t; tess.triangles)
			f(t[0]*2  , t[1]*2  , t[2]*2  ); //bottom
			foreach(const t; tess.triangles)
			f(t[2]*2|1, t[1]*2|1, t[0]*2|1); //top
			foreach(const l; tess.lines)
			q(l[0]*2, l[0]*2|1, l[1]*2, l[1]*2|1); //sides
		}
	} 
	
		void addPoly(in vec2[][] outlines, float y0=0, float y1=1)
	{ addPoly(tesselate(outlines), y0, y1); } 
	
		void addNGon(int sides, float radius, float y0=0, float y1=1)
	{
			//Todo: radius, y0, y1 kivalthato egy matrix-szal is
		TessResult tess; 
		with(tess)
		{
			auto a = 2*PI/sides; 
			vertices = iota(sides).map!(i => vec2(0, 1).vRot(i*a)*radius).array ~ vec2.Null; 
			
			foreach(i; 0..sides)
			{
				int j=i+1; if(j==sides)
				j=0; 
				vertices ~= vec2(0, 1).vRot(i*a)*radius; 
				lines ~= [i, j]; 
				triangles ~= [i, j, sides]; 
			}
		}
		addPoly(tess, y0, y1); 
	} 
	
} 

void filterTrimesh(alias pred)(MeshObject obj)
{
	with(obj)
	{
		auto newTrimesh = trimesh.filter!pred.array; 
		assert(newTrimesh.length % 3 == 0); 
		faces.clear;  vertices.clear;  texCoords.clear; 
		appendTrimesh(newTrimesh); 
	}
} 


class Material
{
	 //! Material ///////////////////////////////
	string name, matFileName; 
	RGBA ambient, diffuse, specular; 
	float shininess = 0.1, bumpAmount = 1; 
	
	string texMap, opacMap, bumpMap, specMap, reflMap; 
	
	this(string name)
	{ this.name = name; } 
	
	override string toString() const
	{
		return this.toString2; 
		//return "Material(%s, amb:%s, diff:%s, spec:%s, shin:%s, bumpa:%s, maps:%s)".format(name, ambient, diffuse, specular, shininess, bumpAmount, [texMap, opacMap, bumpMap, specMap, reflMap]);
	} 
} 


struct Joint
{
	 //Joint ////////////////////////////////////////
	Type type;  enum Type
	{ fixed, linear, rotational} 
	
	bool isFixed	   () const
	{ return type == Type.fixed; } 
	bool isLinear	   () const
	{ return type == Type.linear; } 
	bool isRotational() const
	{ return type == Type.rotational; } 
	
	vec3 axis; 
	float minValue = 0,
				maxValue = 0,
				offset = 0,
				value = 0; 
	
	vec3 rotCenter; 
	
	bool isAtMinimum()
	{ return isLinear && value <= minValue; } 
	bool isAtMaximum()
	{ return isLinear && value >= maxValue; } 
	
	private float restrict(float v)
	{
		if(isLinear)
		return v.clamp(minValue, maxValue); 
		else if(isRotational) return v.cyclicMod(360); 
		else return 0; 
	} 
	
	void set(float v)
	{ value = restrict(v); } 
	float get()
	{ return restrict(value); } 
	
	void adjust(float delta)
	{ set(value+delta); } 
	
	float middle() const
	{ return avg(minValue, maxValue); } 
	
	mat4 matrix()
	{
		with(Type)
		final switch(type)
		{
			case fixed	: return mat4.identity; 
			case linear	: return mat4.translation(axis * (value + offset)); 
			case rotational: return mat4.rotation((value + offset).toRad, axis); 
		}
	} 
	
	void apply(ref mat4 m)
	{
		if(type == Joint.Type.fixed)
		return; 
		m = m * matrix; 
	} 
	
	void testAnimate(float speed)
	{
		if(minValue==0 && maxValue==0 && type==Joint.Type.rotational)
		{ value = QPS*speed; }else
		{ value = sin(QPS*speed).remap(-1, 1, minValue, maxValue); }
	} 
} 

class MeshNode
{
	 //! MeshNode ///////////////////////////////
	//must update copyPropsFrom() if these are changed
	MeshObject object; 
	mat4 mTransform, mTransform2; 
	vec3 pivot = vec3(0); 
	ushort kfId; //redundant. only needed for 3ds loader
	
	private void copyPropsFrom(MeshNode src)
	{
		this.object	    = src.object; 
		this.mTransform	    = src.mTransform; 
		this.pivot	    = src.pivot; 
		this.kfId	    = src.kfId; 
	} 
	
	MeshNode parent; 
	MeshNode[] subNodes; 
	
	Joint joint; 
	
	string objectName() const
	{ return object ? object.name : ""; } 
	
	static int instanceCount; 
	
	this(MeshObject object, MeshNode parent)
	{ this(0, object, parent); } 
	this(ushort id, MeshObject object, MeshNode parent)
	{
		 //for import_3ds
		instanceCount++; 
		
		//"creating node: %s".writefln(object.text);
		
		this.kfId = id; 
		this.object = object; 
		if(object !is null)
		mTransform = object.mTransform_import; 
		this.parent = parent; 
	} 
	
	private this(MeshNode src, MeshNode parent)
	{
		 //clone
		instanceCount++; 
		//"cloning node: %s".writefln(src.object.text);
		
		copyPropsFrom(src); 
		
		this.parent = parent; 
		foreach(sn; src.subNodes)
		this.subNodes ~= new MeshNode(sn, this); 
	} 
	
	~this()
	{
		instanceCount--; 
		//std.stdio.writeln("destroying node ", object ? object.name : "null");
	} 
	
	private MeshNode findById(ushort id)
	{
		if(kfId==id)
		return this; 
		foreach(s; subNodes)
		{
			auto r = s.findById(id); 
			if(r)
			return r; 
		}
		return null; 
	} 
	
	private MeshNode findByName(string name)
	{
		if(object.name==name)
		return this; 
		foreach(s; subNodes)
		{
			auto r = s.findByName(name); 
			if(r)
			return r; 
		}
		return null; 
	} 
	
	auto opIndex(size_t idx)
	{ return(subNodes.length<idx) ? subNodes[idx] : null; } 
	
	auto opIndex(string name)
	{ return findByName(name); } 
	//auto opDispatch(string name)(){ return opIndex(name); }
	
	override string toString() const
	{ return "MeshNode(%d, \"%s\", pivot:%s, %s)".format(kfId, pivot, object ? object.name : "$$$DUMMY", subNodes); } 
	
	mat4 fullTransform()
	{
		//Todo: this is a big fucking mess
		return mTransform * mat4.translation(joint.rotCenter) * joint.matrix * mat4.translation(-joint.rotCenter) *mTransform2; 
	} 
	
	void dump(int level=0)
	{
		//"%s%d \"%s\" piv:%s tran:%s".writefln("  ".replicate(level), kfId, object ? object.name : "$$$DUMMY", pivot, mTransform);
		subNodes.each!((n){ n.dump(level+1); }); 
	} 
	
	void transformOrigin(in mat4 m)
	{
		 //relocates the origin and transforms all vertices, in a way that the geometry don't change at al. Only the origin (mTransfiorm).
		auto mi = m.inverse; 
		if(object)
		object.transformVertices(mi); 
		
		mTransform = mTransform * m; 
		foreach(sn; subNodes)
		sn.mTransform = sn.mTransform * mi; 
	} 
	
	void walk(void delegate(MeshNode) fv)
	{
			//recursive walk on this and all subNodes
		fv(this); 
		foreach(n; subNodes)
		n.walk(fv); 
	} 
	
	void transformedWalk(void delegate(MeshNode, in mat4) fv, in mat4 mModel = mat4.identity)
	{
		 //recursive transformed walk
		auto m = mModel * fullTransform; 
		fv(this, m); 
		
		if(subNodes.length)
		{
			m = m * mat4.identity.translate(pivot); 
			foreach(n; subNodes)
			n.transformedWalk(fv, m); 
		}
	} 
	
	float[] savePose()
	{
		float[] res; 
		walk((n){ res ~= n.joint.value; }); 
		return res; 
	} 
	
	void loadPose(in float[] data)
	{
		int idx; 
		walk((n){ n.joint.value = data[idx++]; }); 
	} 
	
} 

__gshared ModelPrototype[File] modelPrototypes; 

class ModelPrototype
{
	 //! ModelPrototype ////////////////////////////////////////
		const File fileName; 
		int instanceCnt; 
	
		MeshObject[string] objects; 
		Material[string] materials; 
		MeshNode root; 
	
		this(File fn)
	{
		fileName = fn; 
		
		if(fn.extIs("3ds"))
		{
			auto buf = fn.read; 
			import_3ds(buf); 
		}else if(fn.extIs("stl"))
		{
			auto trimesh = fn.loadStl; 
			auto name = fn.nameWithoutExt; 
			auto obj = new MeshObject(fn.nameWithoutExt); 
			obj.appendTrimesh(trimesh); 
			root = new MeshNode(obj, null); 
		}else if(fn.extIs("x3d"))
		{ import_x3d(fn); }else
		{ enforce(0, "Unknown 3D model extension: ", fn.ext); }
	} 
	
		private auto clone()
	{
		return root ? new MeshNode(root, null) //call recursive constructor
					: null; 
	} 
	
		//import 3DS/////////////////////////////////////
	private: 
		bool dump = DUMP_3DS_IMPORT; 
	
		MeshObject actObject; 
		Material actMaterial; 
	
		string lastKfName; 
		ushort lastKfId, lastKfParent; 
		vec3 lastKfPivot = vec3(0); 
		RGB lastColor; 
		float lastPercent = 0; 
		string lastMapName; 
	
		void newObject  (string name)
	{ actObject   = new MeshObject(name); objects  [name] = actObject; } 
		void newMaterial(string name)
	{ actMaterial = new Material  (name); materials[name] = actMaterial; } 
	
		void addKfNode()
	{
		auto o = lastKfName in objects; 
		enforce(o !is null || lastKfName=="$$$DUMMY", "Invalid kfObjectName: \""~lastKfName~"\""); 
		
		auto pNode = root.findById(lastKfParent); 
		enforce(pNode !is null, "Unable to find parent node "~lastKfParent.text); 
		
		auto node = new MeshNode(lastKfId, o !is null ? *o : null , pNode); 
		pNode.subNodes ~= node; 
		
		node.pivot = lastKfPivot; 
		lastKfPivot = vec3(0); 
	} 
	
		void processChunk(ref ubyte[] src, int level=0)
	{
		enforce(src.length>=6, "Out of data"); 
		Chunk chunk; 
		src.stRead(chunk.id); 
		src.stRead(chunk.nextChunk); 
		int len = chunk.nextChunk-6; 
		enforce(len>=0 && len<=src.length, "Invalid chunkSize"); 
		chunk.data = src[0..len]; 
		src = src[len..$]; 
		
		int cnt; 
		
		void processChunkArray()
		{
			while(chunk.data.length)
			processChunk(chunk.data, level+1); 
		} 
		T fetch(T)()
		{
			static if(is(T==string))
			{
				auto len = chunk.data.countUntil(0); 
				enforce(len>=0); 
				string res = cast(string)(chunk.data[0..len].dup); 
				chunk.data = chunk.data[len+1..$]; 
				return res; 
			}else static if(is(T==RGB))
			{
				processChunk(chunk.data, level+1); 
				return lastColor; 
			}else
			{ return chunk.data.stRead!T; }
		} 
		void fetchCnt()
		{ cnt = fetch!ushort; } 
		
		mat4 fetchMat43()
		{
				  auto f()
			{ return fetch!float; } 
			
					 float[3][4] m; 
					 foreach(i; 0..4)
			foreach(j; 0..3)
			m[i][j] = f; 
			
			
			/*
				 return mat4(	m[0][0],	 m[1][0],	 m[2][0],	 m[3][0],
				 	m[0][2],	 m[1][2],	 m[2][2],	 m[3][2],
						  -m[0][1], -m[1][1], -m[2][1], -m[3][1],
								 0,        0,        0,        1);
			*/
			
				  return mat4(
				 m[0][0],  m[1][0],  m[2][0],	 m[3][0],
					 m[0][1],	 m[1][1],	 m[2][1],	 m[3][1],
					 m[0][2],	 m[1][2],	 m[2][2],	 m[3][2],
						 0,        0,        0,        1
			); 
			
			
		} 
		static vec3 import3dsVector(in vec3 v)
		{
			//return vec3(v.x, v.z, -v.y);
			return v; 
		} 
		
		static auto import3dsFace(in ushort[4] i)
		{
			MeshObject.Index[4] r; 
			r[0] = i[0]; 
			r[1] = i[1]; 
			r[2] = i[2]; 
			r[3] = i[3]; 
			return r; 
		} 
		
		void processMap(ref string mapName)
		{ processChunkArray; mapName = lastMapName; } 
		
		
		if(dump)
		write("\n", "  ".replicate(level), chunk.toString, " "); 
		
		void todo()
		{
			if(dump)
			write("\33\14Not implemented\33\7 "); 
		} 
		
		with(ChunkID)
		switch(chunk.id)
		{
			case M3DMAGIC	: processChunkArray; if(dump)
			{
				materials.values.each!writeln; objects.each!writeln; if(root)
				root.dump; 
			}break; 
			case		 M3D_VERSION	: { ushort version_    = fetch!ushort; enforce(version_   <=3, "Invalid 3DS version"); break; }
			case		 MESH_VERSION	: { ushort meshVersion = fetch!ushort; enforce(meshVersion<=3, "Invalid 3DS meshVersion"); break; }
			case		 MDATA	: processChunkArray; break; 
			case     NAMED_OBJECT	: newObject(fetch!string); if(dump)
			actObject.name.write; processChunkArray; break; 
			case       N_TRI_OBJECT	: processChunkArray; break; 
			case						   POINT_ARRAY	: fetchCnt; actObject.vertices = (cast(vec3[])(chunk.data[0..cnt*12])).map!import3dsVector.array; break; 
			case						   FACE_ARRAY	: fetchCnt; actObject.faces = (cast(ushort[4][])(chunk.data[0..cnt*8])).map!import3dsFace.array; chunk.data = chunk.data[cnt*8..$]; processChunkArray; break; 
			case						     MSH_MAT_GROUP	: todo; break; 
			case						     SMOOTH_GROUP	: todo; break; 
			case						   TEX_VERTS	: fetchCnt; actObject.texCoords = cast(vec2[])(chunk.data[0..cnt*8]); break; 
			case						   MESH_MATRIX	: actObject.mTransform_import = fetchMat43; break; 
			case						   MESH_COLOR	: todo; break; 
			case     MAT_ENTRY	: processChunkArray; break; 
			case						 MAT_NAME	: newMaterial(fetch!string); break; 
			case						 MAT_AMBIENT	: actMaterial.ambient	= fetch!RGB; break; 
			case						 MAT_DIFFUSE	: actMaterial.diffuse	= fetch!RGB; break; 
			case						 MAT_SPECULAR	: actMaterial.specular	= fetch!RGB; break; 
			case						 MAT_SHININESS	: lastPercent = 0; processChunk(chunk.data, level+1); actMaterial.shininess = lastPercent; break; 
			case						 MAT_TEXMAP	: processMap(actMaterial.texMap ); break; 
			case						 MAT_OPACMAP	: processMap(actMaterial.opacMap); break; 
			case						 MAT_REFLMAP	: processMap(actMaterial.reflMap); break; 
			case						 MAT_BUMPMAP	: processMap(actMaterial.bumpMap); break; 
			case         MAT_BUMP_PERCENT	: actMaterial.bumpAmount = fetch!ushort*.012f; break; 
			case       MAT_SPECMAP	: processMap(actMaterial.specMap); break; 
			case         MAT_MAPNAME	: lastMapName = fetch!string; break; 
			case   KFDATA	: processChunkArray; break; 
			case				 KFSEG	: todo; break; //int start, int end
			case				 OBJECT_NODE_TAG	: processChunkArray; addKfNode; break; 
			case						 NODE_ID	: lastKfId = fetch!ushort; break; 
			case						 NODE_HDR	: lastKfName = fetch!string; fetch!int; /*ignore*/ lastKfParent = fetch!ushort;  break; 
			case						 PIVOT	: lastKfPivot = import3dsVector(fetch!vec3); break; 
			case						 BOUNDBOX	: todo; break; 
			case						 POS_TRACK_TAG	: todo; break; 
			case						 ROT_TRACK_TAG	: todo; break; 
			case						 SCL_TRACK_TAG	: todo; break; 
			
			case COLOR_F	  : lastColor = RGB(cast(float[])(chunk.data[0..12])); break; 
			case COLOR_24	  : lastColor = (cast(RGB[])(chunk.data[0..3]))[0]; break; 
			case INT_PERCENTAGE		: 	lastPercent = fetch!ushort*.01f; break; 
			case FLOAT_PERCENTAGE		: 	lastPercent = fetch!float*.01f; break; 
			default: 
				todo; 
		}
	} 
	
		void import_3ds(ref ubyte[] buf)
	{
			root = new MeshNode(0xFFFF, null, null); 
			processChunk(buf); 
		
			//vertices are transformed by default, so let's transform them back
			if(1)
		foreach(obj; objects)
		with(obj)
		{
			auto im = mTransform_import.inverse; 
			foreach(ref v; vertices)
			v = (im*vec4(v, 1)).xyz; 
		}
		
			//convert abs matrices to relative ones
			static void abs2rel(MeshNode node, in mat4 actIm = mat4.identity)
		{
				 mat4 nextIm = node.mTransform.inverse; 
				 foreach(child; node.subNodes)
			abs2rel(child, nextIm); //recursion in the beginning
			  node.mTransform = actIm*node.mTransform; 
			
			//node.pivot = (actIm*vec4(node.pivot, 1)).xyz; ???????????
		} 
			if(1)
		abs2rel(root); 
		
			//test cubes
		  /*
			foreach(obj; objects) with(obj){
				auto b = calcBounds;
				b.bMin.x = 0;
				b.bMin.y = 0;
				addBox(b);
				b = calcBounds;
				b.bMax.x = 0;
				b.bMax.y = 0;
				addBox(b);
			  }
		*/
	} 
	
	//import X3D //////////////////////////////////
	
		void import_x3d(bool dump=false)(File fn)
	{
		import std.xml; 
		auto str = fn.readStr; 
		check(str); 
		
		auto xml = new DocumentParser(str); 
		
		static auto toV(V)(ElementParser xml, string attr)
		{ return V(xml.tag.attr[attr].split(' ').map!"a.to!float".array); } 
		
		int level; 
		void wr(T...)(T t)
		{
			if(dump)
			writeln("  ".replicate(level), t); 
		} 
		
		int[] actIndex; 
		root = new MeshNode(new MeshObject(fn.otherExt("").name), null); 
		MeshNode actNode = root; 
		bool[] validTransformStack; 
		RGB[string] materials; 
		string actMaterialName; 
		
		xml.onStartTag["Transform"] = (ElementParser xml){
								 string def = xml.tag.attr["DEF"]; 
								 wr("Transform ", def); level++; 
								 auto rot = toV!vec4(xml, "rotation"); 
								 auto m = mat4.identity
									 *mat4.translation(toV!vec3(xml, "translation"))
									 *mat4.rotation(-rot.w, rot.xyz)
									 *mat4.scaling(toV!vec3(xml, "scale"))
			; 
			
								 const validTransform = !def.endsWith("_ifs_TRANSFORM") && def!="Light_TRANSFORM" && def!="Camera_TRANSFORM"; 
								 validTransformStack ~= validTransform; 
			
			      if(validTransform)
			{
				def = def.withoutEnding("_TRANSFORM"); 
				
				//create and insert the node into hierarchy
				auto node = new MeshNode(new MeshObject(def), actNode); 
				actNode.subNodes ~= node; 
				actNode = node; 
				
				//set node props
				node.mTransform = m; 
				
				wr("\33\16push\33\7 ", actNode.object.name); 
			}
			      wr(m); 
		}; 
		
		xml.onStartTag["Group"] = (ElementParser xml){ wr("Group ", xml.tag.attr["DEF"]); level++; }; 
		
		xml.onStartTag["Shape"] = (ElementParser xml){ wr("Shape"); level++; actMaterialName=""; }; 
		
		xml.onStartTag["Material"] = (ElementParser xml){
				//Appearance/Material
			if(auto def = "DEF" in xml.tag.attr)
			{
				auto c = RGB(xml.tag.attr["diffuseColor"].split(' ').map!"a.to!float".array); 
				materials[*def] = c; 
				actMaterialName = *def; 
			}else if(auto use = "USE" in xml.tag.attr)
			{ actMaterialName = *use; }
		}; 
		
		xml.onStartTag["IndexedTriangleSet"] = (ElementParser xml){
			actIndex = xml.tag.attr["index"].strip.split(' ').map!(to!int).array; 
			//wr("index=", actIndex);
		}; 
		
		xml.onStartTag["Coordinate"] = (ElementParser xml){
			auto v = xml.tag.attr["point"].strip.split(' ').map!(to!float).array; 
			//wr("vertex=", v);
			actNode.object.appendTrimesh(v, actIndex); 
			
			//set material... Should not be exactly here
			if(auto m = actMaterialName in materials)
			{ actNode.object.color = *m; }
			
			//wr(actNode.object.vertices);
			//wr(actNode.object.faces);
		}; 
		
		xml.onEndTag["Shape"] = (in Element e){ level--; }; 
		
		xml.onEndTag["Group"] = (in Element e){ level--; }; 
		
		xml.onEndTag["Transform"] = (in Element e){
			if(validTransformStack[$-1])
			{
					//steb back one level
				wr("\33\16pop\33\7 ", actNode.object.name); 
				actNode = actNode.parent; 
			}
			validTransformStack = validTransformStack[0..$-1]; 
			
			level--; 
		}; 
		
		xml.parse; 
		
		//convert abs matrices to relative ones
		static void abs2rel(MeshNode node, in mat4 actIm = mat4.identity)
		{
				 mat4 nextIm = node.mTransform.inverse; 
				 foreach(child; node.subNodes)
			abs2rel(child, nextIm); //recursion in the beginning
			  node.mTransform = actIm*node.mTransform; 
			
			//node.pivot = (actIm*vec4(node.pivot, 1)).xyz; ???????????
		} 
		if(0)
		abs2rel(root); 
	} 
	
} 

class Model
{
	 //! Model /////////////////////////
		ModelPrototype prototype; //can be null
		MeshNode root; //cloned structure
	
		RGBA color=clWhite; 
	
		this(string fn)
	{ this(File(fn)); } 
	
		this(File fn)
	{
		auto p = fn in modelPrototypes; 
		if(p is null)
		{
			prototype = new ModelPrototype(fn); //Todo: error handling
			modelPrototypes[fn] = prototype; 
		}else
		{ prototype = *p; }
		
		if(prototype !is null)
		{
			prototype.instanceCnt++; 
			root = prototype.clone; 
		}
	} 
	
		this(File fn, RGBA color_)
	{
		this(fn); 
		color = color_; 
	} 
	
		this(MeshObject obj)
	{
			//simple object, not prototype
		root = new MeshNode(obj, null); 
	} 
	
		~this()
	{
		if(prototype !is null)
		prototype.instanceCnt--; 
	} 
	
		void translate(in vec3 v)
	{
		if(!root)
		return; root.mTransform.translate(v); 
	} 
		void translate(float x, float y=0, float z=0)
	{ translate(vec3(x, y, z)); } 
	
		MeshNode nodeByName(string name, bool mustExists=true)
	{
		auto res = root ? root[name] : null; 
		enforce(root || !mustExists, `Unable to find MeshNode "%s" in model "%s".`.format(name, prototype.fileName)); 
		return res; 
	} 
	
		MeshNode opIndex(string name)
	{ return nodeByName(name, true); } 
		//MeshNode opDispatch(string name)(){ return opIndex(name); }
	
	
	
	//new basic objects //////////////////////////////////////////////////////
	static: 
		int boxIdx; 
	
		auto newBox(in bounds3 bnd)
	{
		auto o = new MeshObject(`custom:\\box_`~(boxIdx++).text); 
		o.addBox(bnd); 
		return new Model(o); 
	} 
		auto newBox(in vec3 size)
	{
		with(size*.5)
		return newBox(bounds3(-x, -y, -z, x, y, z)); 
	} 
		auto newBox(float sx, float sy, float sz)
	{ return newBox(vec3(sx, sy, sz)); } 
		auto newBox(float size)
	{ return newBox(vec3(size)); } 
	
		int polyIdx; 
	
		auto newPoly(in vec2[][] outlines, float y0, float y1)
	{
		auto o = new MeshObject(`custom:\\poly_`~(polyIdx++).text); 
		o.addPoly(outlines, y0, y1); 
		return new Model(o); 
	} 
		auto newPoly(in vec2[]   outline , float y0, float y1)
	{ return newPoly([outline], y0, y1); } 
		auto newPoly(in vec2[][] outlines, float height=1)	   
	{ return newPoly(outlines, 0, height); } 
		auto newPoly(in vec2[]   outline , float height=1)	   
	{ return newPoly(outline, 0, height); } 
	
		int NGonIdx; 
	
		auto newNGon(int sides, float radius, float y0, float y1)
	{
		auto o = new MeshObject(`custom:\\ngon_`~(NGonIdx++).text); 
		o.addNGon(sides, radius, y0, y1); 
		return new Model(o); 
	} 
		auto newNGon(int sides, float radius=1, float height=1)    
	{ return newNGon(sides, radius, 0, height); } 
	
	
} 

void test3ds()
{
	auto fn = File(
		//`c:\dl\model\Bulldozer B10\Bulldozer B10.3ds` blender:bugos
		//`c:\dl\model\little_forklift\frkl.3DS`        blender:bugos
		//`c:\dl\model\truck\3ds file.3DS`
		//`c:\dl\model\Bridge tank\3ds file.3DS`
		//`c:\dl\model\Tank T-34\3ds file.3DS`
		//`c:\dl\model\Tiger_I\Tiger_I.3ds`
		//`c:\dl\model\USAPC\apc.3ds`
		//`c:\dl\model\blender_tiger.3ds`
		`c:\dl\model\t34_max\t34_2.3DS`
	); 
	
	auto model1 = new Model(fn); 
	auto model2 = new Model(fn); 
	
	model1.root.dump; 
	model2.root.dump; 
	
	
} 