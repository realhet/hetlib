module het.mcu;/+DIDE+/

import het, het.ui;

//WireColor //////////////////////////////////////////////////////////////////

RGB toWireColor(string s)
{
	static RGB[string]map;  if(!map)
	map = [
		"white"	 : clWhite,
		"black"	 : clBlack,
		"grey"   : RGB(183, 183, 183),
		"brown"  : RGB(120, 63, 4),
		"blue"   : RGB(17, 85, 204),
		"red"    : RGB(255, 16, 0),
		"orange" : clOrange,
		"yellow" : clYellow,
		"green"  : RGB(51, 204, 51),
		"pink"	: RGB(234, 153, 153),
		"violet" :	RGB(103, 78, 167),
	];
	
	
	return *enforce(s.lc in map, "unknown wire color: "~s.quoted);
}

/// Displays a wire color with it's name
void ColorRow(string colorName, float hScale = 1)
{
	with(im)
	{
		if(colorName.isWild("*-*"))
		{
			Column(
				{
					const c0 = wild[0], c1 = wild[1];
					ColorRow(c0, .5);
					ColorRow(c1, .5);
				}
			);
		}else
		{
			Row(
				{
					if(hScale==1)
					{
						border = "1 normal gray";
						border.inset = true;
					}
					outerWidth = 52;
					style.bkColor = bkColor = colorName.toWireColor;
					style.fontColor = blackOrWhiteFor(bkColor); flags.hAlign = HAlign.center;
					fh = fh*hScale;
					Text(colorName);
				}
			);
		}
	}
}

auto connectorInfo(string s)
{
	ConnectorInfo ci;
	with(ci)
	{
		s = s.strip;
		
		bool chk(string[] choices...)
		{
			const idx = choices.map!(a => s.startsWith_ci(a)).countUntil(true);
			if(idx>=0)
			{
				s = s[choices[idx].length..$].stripLeft;
				return true;
			}
			return false;
		}
		
		void fetchPins()
		{
			ignoreExceptions(
				{
					numPins = s.parse!ubyte;
					s = s.strip;
					chk("pins", "pin");
				}
			);
		}
		
		void fetchGender()
		{
			isMale = chk("Male", "M");
			isFemale = chk("Female", "F");
		}
		
		//standard connectors: https://docs.rs-online.com/06b0/0900766b81424442.pdf
		if(chk("DSubHD", "D-SubHD", "DSub HD", "D-Sub HD"))
		{
				type = Type.DSubHD;
			fetchPins; fetchGender;
			valid = hasGender & [15, 26, 44, 50, 62, 78].canFind(numPins);
		}else if(chk("DSub", "D-Sub"))
		{
			type = Type.DSub; //do not move this IF before DSubHD!!!
								fetchPins; fetchGender;
								valid = hasGender & [9, 15, 19, 25, 37].canFind(numPins);
		}else if(chk("M12_", "M12"))
		{
				type = Type.M12;
			fetchPins; fetchGender;
			valid = hasGender & [3, 4, 5, 8, 12].canFind(numPins);
		}else if(chk("Wire"))
		{
				type = Type.Wire;
			fetchPins;
			valid = true;
		}
		
		valid &= s==""; //no remaining text allowed
	}
	
	return ci;
}

auto allDSubConnectors()
{ return chain([9, 15, 19, 25, 37].map!`a.format!"DSub%dM"`, [15, 26, 44, 50, 62, 78].map!`a.format!"DSubHD%dM"`); }
auto allM12Connectors()
{ return chain([3, 4, 5, 8, 12].map!`a.format!"M12_%dM"`); }
auto allConnectors()
{ return chain(allDSubConnectors, allM12Connectors); }

struct ConnectorInfo
{
	//ConnectorInfo ///////////////////////////////////////
	enum Type
	{ Unknown, Wire, DSub, DSubHD, M12 }
	Type type;
	ubyte numPins;
	bool isMale, isFemale;
	
	//view parameters
	bool backSide, rot90, rot180;
	
	bool valid;
	
	@property hasGender() const
	{ return isMale || isFemale; }
	
	string toString() const
	{
		if(!valid || type==Type.Unknown)
		return "";
		
		auto res = type.text;
		if(numPins)
		res ~= " " ~ numPins.text ~ "pin";
		if(isMale)
		res~= " M";
		if(isFemale)
		res~= " F";
		
		return res;
	}
	
	vec2 baseSize() const
	{
		if(!valid)
		return vec2(0);
		
		with(Type)
		return type.predSwitch(
			DSub	, vec2(numPins/2*2+4, 5),
			DSubHD	, numPins==78 ? vec2(43, 9) : vec2(numPins/3*2+5 + (numPins%3==0 ? -1 : 0) , 7),
			M12	, vec2(numPins<=5 ? 7.5 : numPins<=8 ? 9.5 : 10),
			vec2(0)
		);
		
	}
	
	enum unitFromFh = 0.5f;
	enum fontScale = 0.88f;
	
	vec2 transformedSize(float fh) const
	{
		auto s = baseSize;
		if(rot90)
		s = vec2(s.y, s.x);
		return s*(fh*unitFromFh);
	}
	
	void draw(Drawing dr, float fh, in string[string] pinColorMap = null) const
	{
		//Draws the schematic aligned to the top left. Use calcSize() to get the size and align.
		//Drawing size depends on fontHeight
		const
			 unit = fh*unitFromFh,
			 size = transformedSize(fh),
			 uSize = baseSize*unit,
			 center = size*.5f;
		
		vec2 tr(vec2 p)
		{
			p -= uSize*.5f;
			
			if(backSide==isMale)
			p.x = -p.x;
			if(rot90)
			p = vec2(-p.y, p.x);
			if(rot180)
			p = vec2(-p.x, -p.y);
			
			p += center;
			
			return p;
		}
		
		enum 
			 clOutline = clGray,
			 clBody = RGB(196, 196, 212);
		
		dr.fontHeight = fh*fontScale;
		
		
		void drawPin(vec2 p, string label)
		{
			  string colorName = pinColorMap.get(label, "");
			
				 RGB cRing;
				 bool hasRingColor;
				 if(colorName.isWild("*:*"))
			{
				hasRingColor = true;
				cRing = wild[0].toWireColor;
				colorName = wild[1];
			}
			
				 RGB c0, c1;
				 if(colorName=="")
			{ c0 = c1 = clBody; }else if(colorName.isWild("*-*"))
			{
				c0 = wild[0].toWireColor;
				c1 = wild[1].toWireColor;
			}else
			{ c0 = c1 = colorName.toWireColor; }
			
			  auto a = unit*1.8f;
			
				 dr.color = hasRingColor ? cRing : clOutline;
				 dr.pointSize = a*(hasRingColor ? 1.25f : 1.1f); //Todo: intelligent point() function
				 dr.point(tr(p));
			
				if(hasRingColor)
			a	*= .9f;
			
				 dr.color = c0;
				 dr.pointSize = a;
				 dr.point(tr(p));
			
			  if(c1!=c0)
			{
				dr.color = c1;
				dr.lineWidth = a*.5f;
				dr.line(tr(vec2(p.x-unit*.5f, p.y)), tr(vec2(p.x+unit*.5f, p.y)));
			}
			
			  if(label!="")
			{
				dr.color = (colorName=="" ? clOutline : blackOrWhiteFor(c1));
				dr.autoSizeText(tr(p), label, 1.25f);
			}
			
		}
		
		
		void drawDSubBody(float rScale, float slope)
		{
			dr.color = clBody;
			const r = unit*rScale;
			dr.lineWidth = r*2; //factor less than 2.0 -> It will have a margin.
			
			const sl = (uSize.y-r*2)*slope,
						a = vec2(r, r),
						b = vec2(uSize.x-r, r),
						c = vec2(a.x + sl, uSize.y-r),
						d = vec2(b.x - sl, uSize.y-r);
			
			dr.line(tr(a), tr(c));  dr.line(tr(b), tr(d));
			
			const N = iceil(uSize.y/dr.lineWidth), invN = 1.0f/N;
			foreach(i; 0..N+1)
			{
				const t = float(i)*invN;
				dr.line(tr(mix(a, c, t)), tr(mix(b, d, t)));
			}
		}
		
		
		if(type==Type.DSub)
		{
			const h = (numPins+1)/2;
			
			drawDSubBody(1, .25f);
			foreach(i; 0..h)
			drawPin(vec2(i*2+2    , 1.5)*unit, (i+1).text);
			foreach(i; h..numPins)
			drawPin(vec2((i-h)*2+3, 3.5)*unit, (i+1).text);
		}else if(type==Type.DSubHD)
		{
			
			const t = (numPins+1)/3;
			
			drawDSubBody(1, .25f);
			if(numPins==50)
			{
				foreach(i; 0..t    )
				drawPin(vec2(i*2+2.5          , 1.5)*unit, (i+1).text);
				foreach(i; t..t*2-1)
				drawPin(vec2((i-t)*2+3.5      , 3.5)*unit, (i+1).text);
				foreach(i; t*2-1..numPins)
				drawPin(vec2((i-(t*2-1))*2+2.5, 5.5)*unit, (i+1).text);
			}else if(numPins==78)
			{
				foreach(i; 0 ..20)
				drawPin(vec2((i   )*2+2.5, 1.5)*unit, (i+1).text);
				foreach(i; 20..39)
				drawPin(vec2((i-20)*2+3.5, 3.5)*unit, (i+1).text);
				foreach(i; 39..59)
				drawPin(vec2((i-39)*2+2.5, 5.5)*unit, (i+1).text);
				foreach(i; 59..78)
				drawPin(vec2((i-59)*2+3.5, 7.5)*unit, (i+1).text);
			}else
			{
				foreach(i; 0..t  )
				drawPin(vec2(i*2+3      , 1.5)*unit, (i+1).text);
				foreach(i; t..t*2)
				drawPin(vec2((i-t)*2+2  , 3.5)*unit, (i+1).text);
				foreach(i; t*2..numPins)
				drawPin(vec2((i-t*2)*2+3, 5.5)*unit, (i+1).text);
			}
		}else if(type==Type.M12)
		{
			
				 //body
				 dr.pointSize = size.x;	 dr.color = clBody;	 dr.point(tr(center));
				 dr.pointSize = size.x*.15f;	 dr.color = clOutline;	 dr.point(tr(center-vec2(0, (size.y-dr.pointSize)/2)));
			
			  void P(float r, float a, string label)
			{
					//polar coords
				drawPin(unit*(vec2(0, -r).rotate(-PIf*a))+center, label);
			}
			
			  if(numPins.inRange(3, 5))
			{
				enum R = 2.25f;
				P(R,  .25, "1");
				P(R, 1.25, "3");
				P(R,  .75, "4");
				if(numPins>=4)
				P(R, 1.75, "2");
				if(numPins>=5)
				P(0, 0   , "5");
			}else if(numPins==8)
			{
				{
					enum R = 3.25f, e = .2f, N = 7;
					iota(N).each!(i => P(R, i.remap(0, N-1, e, 2-e), [2, 3, 4, 5, 6, 7, 1][i].text));
				}
				P(0, 0   , "8");
			}else if(numPins==12)
			{
				{
					enum R = 3.5f, e = .18f, N = 9;
					iota(N).each!(i => P(R, i.remap(0, N-1, e, 2-e), [1, 9, 8, 7, 6, 5, 4, 3, 2][i].text));
				}
				{
					enum R = 1.33f;
					P(R, 0   , "10");
					P(R,  .66, "12");
					P(R, 1.33, "11");
				}
			}
			
			
		}
		
	}
}



//A clickable button with the connector type. Clicking shows a ConnectorPanel.

//ConnectorBtn //////////////////////////////////////////////////
void ConnectorBtn(string srcModule=__MODULE__, size_t srcLine=__LINE__, bool isWhite=false, T...)(string conn, T args)
{
	with(im)
	{
		
		//optional parameter
		string[string] pinColorMap;
		static if(args.length && is(T[0] == string[string]))
		pinColorMap = args[0];
		
		auto	ci = connectorInfo(conn);
		const	hasDetail = ci.valid && ci.type!=ConnectorInfo.Type.Wire,
		bk = actContainer.bkColor;
		
		struct IMData
		{
			bool opened=true, genderOverride, backSide;
			int rotation;
		}
		
		IMData* imData;
		
		if(
			Btn!(srcModule, srcLine)(
				{
					
					if(!ci.valid)
					{
							//unable to identify the connector
						
						Text("\U0001F50C", conn);
						
					}else
					{
							//valid connector
						
						imData = &ImStorage!IMData.access(actContainer.id);
						if(!hasDetail)
						imData.opened = false;
						
						if(imData.opened)
						{
							 //show the details
							
							//name, pinCount
							Text("\U0001F50C" ~ ci.type.text);
							if(ci.numPins)
							Text(" "~ci.numPins.text~"pin");
							
							//gender. Optional override.
							if(ci.hasGender)
							{
								bool isMale = ci.isMale;
								if(imData.genderOverride)
								isMale.toggle;
								if(
									Btn(
										{
											innerWidth = fh*.7f; if(imData.genderOverride)
											{ style.fontColor = clRed; style.bold = true; } Text(isMale ? "M" : "F");
										}
									)
								)
								imData.genderOverride.toggle;
							}
							
							//front of back. Default is front. Optional override.
							if(
								Btn(
									{
										innerWidth = fh*1.8f; if(imData.backSide)
										{ style.fontColor = clRed; style.bold = true; } Text(imData.backSide ? "back" : "front");
									}
								)
							)
							imData.backSide.toggle;
							
							//90deg rotation
							if(Btn({ innerWidth = fh*1.6f; Text(((imData.rotation&3)*90).text~"\u00b0"); }))
							imData.rotation = (imData.rotation+1)&3;
							
							//the actual schematic visualization
							Text("\n");
							Row(
								{
									flags.clickable = false;
									margin = "2";
									
									//update orientation params
									if(imData.genderOverride)
									swap(ci.isMale, ci.isFemale);
									ci.backSide = imData.backSide;
									ci.rot90 = (imData.rotation&1)!=0;
									ci.rot180 = (imData.rotation&2)!=0;
									
									innerSize = ci.transformedSize(fh).ceil;
									auto dr = new Drawing;
									ci.draw(dr, fh, pinColorMap);
									addOverlayDrawing(dr);
								}
							);
						}else
						{ Text("\U0001F50C"~ci.text); }
						
					}
				}, args
			)
		)
		{
			if(imData)
			{
				imData.opened.toggle;
				if(!hasDetail)
				imData.opened = false;
			}else
			{
				WARN("Invalid connector: "~conn.quoted);
				beep;
			}
		}
		
	}
}


/// This class contains common things around an Arduino Nano controller project.
class ArduinoNanoProject
{
	
	
	static struct Wire
	{
		 //Wire ////////////////////////////////////////////////////////
		string identifier;
		
		int pin_A; //this comes out from the box
		string color, description;
		int pin_B; //this is on the end of the cable
		
		char state = '?'; //elements: ? 1 0
		
		protected auto decodeIdentifier() const
		{
			if(identifier=="")
			return tuple("", "");
			const p = identifier.split(':');
			enforce(p.length==2, `Wire.identifier must be in format: pin:label.`);
			enforce(p[1].startsWith("IN_") || p[1].startsWith("OUT_"), `Wire.label must start with "IN_" or "OUT_".`);
			return tuple(p[0], p[1]);
		}
		
		@property string pin	() const
		{ return decodeIdentifier[0]; } //this is the MCU pin
		@property string label	() const
		{ return decodeIdentifier[1]; }
		@property bool isInput	() const
		{ return identifier!="" && label.startsWith("IN_" ); }
		@property bool isOutput() const
		{ return identifier!="" && label.startsWith("OUT_"); }
		
		
		void UI(float panelWidth) const
		{
			with(im)
			Row(
				YAlign.top, {
					style.bkColor = bkColor = clWhite;
					margin = "0";
					border = "1 normal gray";
					border.extendBottomRight = true;
					padding = "1 0 0 1";
					Row(HAlign.right, { width=fh; Text(pin_A ? pin_A.text:" "); });
					Text(" ");
					ColorRow(color);
					Text(" ");
					Row({ width=fh; Text(pin_B ? pin_B.text:" "); });
					Text("  ");
					Row(
						YAlign.top, {
							width = panelWidth;
							Row(
								{
									flex = 1;
									if(identifier!="")
									{ Text(bold(label), "  "); }
									if(description.isWild("*WARNING:*"))
									{
										Text(wild[0]);
										const blink = QPS.value(second).fract<.5;
										style.bkColor = blink ? clRed : clWhite;
										style.fontColor = !blink ? clRed : clWhite;
										Text("\u26A0 ", bold(wild[1]));
									}else
									{
										if(description!="")
										Text(description);
										else Text(clGray, "not connected");
									}
								}
							);
							if(identifier!="")
							Row({ Btn({ Text(pin~" ");  Led(state != '0', state.among('0', '1') ? isInput ? clLime : clYellow : clGray); }, genericId(pin)); });
						}
					);
				}
			);
			
		}
	}
	
	static struct Cable
	{
		 //Cable /////////////////////////////////////////////////
		string name, color, connector_A, connector_B;
		Wire[] wires;
		
		string[string] pinColorMap_A, pinColorMap_B;
		bool pinColorMaps_valid; //must clear when changed: pin_A, pin_B, color
		
		void update_pinColorMaps()
		{
			if(chkSet(pinColorMaps_valid))
			{
				pinColorMap_A = wires.filter!(w => w.pin_A && w.description!="").map!(w => tuple(w.pin_A.text, (color==""?"":color~':')~w.color)).assocArray;
				pinColorMap_B = wires.filter!(w => w.pin_B && w.description!="").map!(w => tuple(w.pin_B.text, (color==""?"":color~':')~w.color)).assocArray;
			}
		}
		
		void UI(float panelWidth=340)
		{
			with(im)
			{
				CableFrame(
					{
						flags.yAlign = YAlign.baseline;
						ColorRow(color);
						fh = 22;	  Text("  ", bold(name));
						fh = 3;	  Text("\n ");
						fh = 18;
						foreach(const wire; wires)
						{
							Text("\n    ");
							wire.UI(panelWidth);
						}
						Text("\n");
						Row(
							{
								margin = "4 0 0 0";
								fh = 18;   Text("    ");
								
								update_pinColorMaps;
								
								ConnectorBtn(connector_A, pinColorMap_A);
								Text("-");
								ConnectorBtn(connector_B, pinColorMap_B);
							}
						);
					}, genericId(name)
				);
			}
		}
	}
	
	
	static Wire[] AllWires	(bool IN=true, bool OUT=true)(Cable[] cables)
	{ return cables.map!"a.wires".join.filter!(a => IN && a.isInput || OUT && a.isOutput).array.withoutDuplicates!"a.identifier"; }
	static Wire[] InputWires	(Cable[] cables)
	{ return AllWires!(true, false)(cables); }
	static Wire[] OutputWires(Cable[] cables)
	{ return AllWires!(false, true)(cables); }
	
	static string[] AllWireLabels(Cable[] cables)
	{ return AllWires(cables).map!"a.label".array; }
	
	//helper functs /////////////////////////////////////////////////////
	
	static bool arduinoPinLessThan(string a, string b)
	{
		 //sort index for arduino pin names
		
		string process(string s)
		{
			s = s.uc.replace("A", "Z");
			if(s.length==2)
			s = s[0]~"0"~s[1];
			return s;
		}
		
		return lessThan(process(a), process(b));
	}
	
	
	static struct PinReg
	{ char regName; ubyte regBit; }
	
	static auto getNanoPinReg(string pin)
	{
		 //access port register/bit of an Arduino NANO pin
		try
		{
			
				 enforce(pin.length>=2, "too short");
				 const idx = pin[1..$].to!ubyte;
			
				 if(pin[0]=='D')
			{
				if(idx.inRange(2,  7))
				return PinReg('D', idx  ); //0, 1 is for serial!!!
				if(idx.inRange(8, 13))
				return PinReg('B', cast(ubyte)(idx-8));
			}
				 if(pin[0]=='A')
			{
				if(idx.inRange(0,  5))
				return PinReg('C', idx  ); //6 is reset
			}
			
			  raise("unhandled");
			
		}catch(Exception e)
		{ raise(format!"Invalid arduino pin: %s (%s)"(pin.quoted, e.simpleMsg)); }
		
		assert(0);
	}
	
	static void CableFrame(T...)(in T args )
	{
		with(im)
		Row(
			{
				theme = "tool";
				margin = "2 4";
				border = "2 normal gray";
				padding = "4";
				style.bkColor = bkColor = RGB(230, 230, 230);
				flags.yAlign = YAlign.baseline;
			}, args
		);
		
	}
	
	
	Cable[] cables; //all the cables connected to the MCU
	@STORED int cablesTabsIdx;
	
	void updateWireStates(bool[string] map)
	{
		foreach(ref c; cables)
		foreach(ref w; c.wires)
		if(auto a = w.label in map)
		w.state = *a ? '1' : '0';
		else w.state = '?';
	}
	
	abstract string generateProgram();
	
	void BtnGenerateProgram()
	{
		with(im)
		if(Btn("GenPrg"))
		{
			auto s = generateProgram;
			clipboard.asText = s;
			beep;
		}
		
	}
	
	void TabsCables()
	{
		with(im)
		{
			Tabs!(
				"a.name",     //title, generated from the item
				(a){ a.UI; }  //content generated form the item
			)
			(
				cables, //items
							cablesTabsIdx, //index to remember selected item
							genericArg!"includeAll"(true) //extra options: includeAll -> Shows an "All" option at the end of the items.
			);
		}
	}
	
}



immutable arduinoUtils = q{
	
	/// Arduino utils ///////////////////////////////////////////////////////////////////
	
	uint32_t CRC32tab[256] = {
		 0x00000000, 0x77073096, 0xee0e612c, 0x990951ba,	0x076dc419, 0x706af48f,
		 0xe963a535, 0x9e6495a3, 0x0edb8832, 0x79dcb8a4,	0xe0d5e91e, 0x97d2d988,
		 0x09b64c2b, 0x7eb17cbd, 0xe7b82d07, 0x90bf1d91,	0x1db71064, 0x6ab020f2,
		 0xf3b97148, 0x84be41de, 0x1adad47d, 0x6ddde4eb,	0xf4d4b551, 0x83d385c7,
		 0x136c9856, 0x646ba8c0, 0xfd62f97a, 0x8a65c9ec,	0x14015c4f, 0x63066cd9,
		 0xfa0f3d63, 0x8d080df5, 0x3b6e20c8, 0x4c69105e,	0xd56041e4, 0xa2677172,
		 0x3c03e4d1, 0x4b04d447, 0xd20d85fd, 0xa50ab56b,	0x35b5a8fa, 0x42b2986c,
		 0xdbbbc9d6, 0xacbcf940, 0x32d86ce3, 0x45df5c75,	0xdcd60dcf, 0xabd13d59,
		 0x26d930ac, 0x51de003a, 0xc8d75180, 0xbfd06116,	0x21b4f4b5, 0x56b3c423,
		 0xcfba9599, 0xb8bda50f, 0x2802b89e, 0x5f058808,	0xc60cd9b2, 0xb10be924,
		 0x2f6f7c87, 0x58684c11, 0xc1611dab, 0xb6662d3d,	0x76dc4190, 0x01db7106,
		 0x98d220bc, 0xefd5102a, 0x71b18589, 0x06b6b51f,	0x9fbfe4a5, 0xe8b8d433,
		 0x7807c9a2, 0x0f00f934, 0x9609a88e, 0xe10e9818,	0x7f6a0dbb, 0x086d3d2d,
		 0x91646c97, 0xe6635c01, 0x6b6b51f4, 0x1c6c6162,	0x856530d8, 0xf262004e,
		 0x6c0695ed, 0x1b01a57b, 0x8208f4c1, 0xf50fc457,	0x65b0d9c6, 0x12b7e950,
		 0x8bbeb8ea, 0xfcb9887c, 0x62dd1ddf, 0x15da2d49,	0x8cd37cf3, 0xfbd44c65,
		 0x4db26158, 0x3ab551ce, 0xa3bc0074, 0xd4bb30e2,	0x4adfa541, 0x3dd895d7,
		 0xa4d1c46d, 0xd3d6f4fb, 0x4369e96a, 0x346ed9fc,	0xad678846, 0xda60b8d0,
		 0x44042d73, 0x33031de5, 0xaa0a4c5f, 0xdd0d7cc9,	0x5005713c, 0x270241aa,
		 0xbe0b1010, 0xc90c2086, 0x5768b525, 0x206f85b3,	0xb966d409, 0xce61e49f,
		 0x5edef90e, 0x29d9c998, 0xb0d09822, 0xc7d7a8b4,	0x59b33d17, 0x2eb40d81,
		 0xb7bd5c3b, 0xc0ba6cad, 0xedb88320, 0x9abfb3b6,	0x03b6e20c, 0x74b1d29a,
		 0xead54739, 0x9dd277af, 0x04db2615, 0x73dc1683,	0xe3630b12, 0x94643b84,
		 0x0d6d6a3e, 0x7a6a5aa8, 0xe40ecf0b, 0x9309ff9d,	0x0a00ae27, 0x7d079eb1,
		 0xf00f9344, 0x8708a3d2, 0x1e01f268, 0x6906c2fe,	0xf762575d, 0x806567cb,
		 0x196c3671, 0x6e6b06e7, 0xfed41b76, 0x89d32be0,	0x10da7a5a, 0x67dd4acc,
		 0xf9b9df6f, 0x8ebeeff9, 0x17b7be43, 0x60b08ed5,	0xd6d6a3e8, 0xa1d1937e,
		 0x38d8c2c4, 0x4fdff252, 0xd1bb67f1, 0xa6bc5767,	0x3fb506dd, 0x48b2364b,
		 0xd80d2bda, 0xaf0a1b4c, 0x36034af6, 0x41047a60,	0xdf60efc3, 0xa867df55,
		 0x316e8eef, 0x4669be79, 0xcb61b38c, 0xbc66831a,	0x256fd2a0, 0x5268e236,
		 0xcc0c7795, 0xbb0b4703, 0x220216b9, 0x5505262f,	0xc5ba3bbe, 0xb2bd0b28,
		 0x2bb45a92, 0x5cb36a04, 0xc2d7ffa7, 0xb5d0cf31,	0x2cd99e8b, 0x5bdeae1d,
		 0x9b64c2b0, 0xec63f226, 0x756aa39c, 0x026d930a,	0x9c0906a9, 0xeb0e363f,
		 0x72076785, 0x05005713, 0x95bf4a82, 0xe2b87a14,	0x7bb12bae, 0x0cb61b38,
		 0x92d28e9b, 0xe5d5be0d, 0x7cdcefb7, 0x0bdbdf21,	0x86d3d2d4, 0xf1d4e242,
		 0x68ddb3f8, 0x1fda836e, 0x81be16cd, 0xf6b9265b,	0x6fb077e1, 0x18b74777,
		 0x88085ae6, 0xff0f6a70, 0x66063bca, 0x11010b5c,	0x8f659eff, 0xf862ae69,
		 0x616bffd3, 0x166ccf45, 0xa00ae278, 0xd70dd2ee,	0x4e048354, 0x3903b3c2,
		 0xa7672661, 0xd06016f7, 0x4969474d, 0x3e6e77db,	0xaed16a4a, 0xd9d65adc,
		 0x40df0b66, 0x37d83bf0, 0xa9bcae53, 0xdebb9ec5,	0x47b2cf7f, 0x30b5ffe9,
		 0xbdbdf21c, 0xcabac28a, 0x53b39330, 0x24b4a3a6,	0xbad03605, 0xcdd70693,
		 0x54de5729, 0x23d967bf, 0xb3667a2e, 0xc4614ab8,	0x5d681b02, 0x2a6f2b94,
		 0xb40bbe37, 0xc30c8ea1, 0x5a05df1b, 0x2d02ef8d	
	};
	
	uint32_t calcCrc32(String& s)
	{
		uint32_t r = 0xFFFFFFFF;
		uint8_t* ptr = s.c_str();
		int len = s.length();
		for(int i=0; i<len; i++)
		r = CRC32tab[uint8_t(r)^ptr[i]]^(r>>8);
		
		return ~r;
	}
	
	void Serial_printCrc32(String& s)
	{
		uint32_t r = calcCrc32(s);
		for(byte i=0; i<4; i++, r>>=8)
		Serial.print(char(r));
	}
	
	
	void Serial_sendMessage(String id, String& msg)
	{
		Serial.print(msg);
		Serial_printCrc32(msg);
		Serial.print(id);
		Serial.print('\n');
	}
	
	/////////////////////////////////////////////////////////////////////////////////////
	
};