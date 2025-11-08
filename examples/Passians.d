//@exe

//@debug
///@release

//@compile -d-version=VulkanUI

import het.ui; 

shared static this()
{ bitmapEffects.registerMarkedFunctions!(mixin(__MODULE__)); } 

auto frmMain()
{ return cast(FrmMain) mainWindow; }  

@BITMAPEFFECT Bitmap rotateEffect(Bitmap bmp, in QueryString params)
{
	auto img = bmp.accessOrGet!RGB; 
	const rotCnt = params.option("rotate", 0)&3; 
	
	//Opt: it's not so optimal. A shader would be better.
	if(rotCnt)
	foreach(i; 0..4-rotCnt)
	img = image2D(img.columns.retro); 
	
	return new Bitmap(img); 
} 

immutable 	clGreen1 =	mix(clGreen, clBlack, 0.2f),
	clGreen2 = clGreen; 

enum CS_CARD	= 0,
CS_CARD_SEL 	= 1; 

void initCardGfx()
{
	const zipFile = File(appPath, `playingCards_webp.zip`); 
	zipFile.read(true).unzipFiles(`virtual:\cards\`); 
} 

enum cardSize = vec2(234, 333); 

enum SuitChars = "HSDC";  
enum SuitNames = ["hearts", "spades", "diamonds", "clubs"]; 

enum RankChars = "A23456789XJQK"; 
enum RankNames = [
	"ace", "2", "3", "4", "5", "6", "7", "8", "9", "10", 
	"jack", "queen", "king" 
]; 
enum Backs = [
	"blue", "blue2", "red", "red2", "abstract", "abstract_clouds", 
	"abstract_scene", "astronaut", "cars", "castle", "fish", "frog"
]; 

File cardFaceFile(int suitIdx, int rankIdx)
{
	auto 	suitName = SuitNames.get(suitIdx),
		rankName = RankNames.get(rankIdx); 
	
	string s; 
	if(suitName!="" && rankName!="")
	{
		s	= suitName~"_"~rankName; 
			
		if(s.endsWith("_ace")) s ~= "_large_pip"; 
		else if(s.endsWith("_8")) s ~= "_alt"; 
	}
	else
	{ s = "blank_card"; }
	
	return File(`virtual:\cards\` ~ s ~ `.webp`); 
} 

File cardBackFile(int deck=0)
{
	auto idx = (cast(uint)frmMain.backCardIdx); 
	
	//validate idx
	if(idx>=Backs.length) idx %= Backs.length; 
	
	auto s = Backs[idx]; 
	
	//alternate blue/red
	if(deck&1) {
		if(s.startsWith("blue")) s = "red"~s.withoutStarting("blue"); 
		else if(s.startsWith("red")) s = "blue"~s.withoutStarting("red"); 
	}
	
	return File(`virtual:\cards\` ~ s ~ ".webp"); 
} 

class Card : Container
{
	@STORED  bool isSelected; 
	
	@STORED
	{
		char suit, rank; 
		ubyte deck; 
		
		bool faceUp, horizontal; 
		vec2 storedPos; 
	} 
	
	//SelectionManager temp variables
	bool oldSelected; 
	int zIndex; //It is used for some algorithms. Assume not being up to date all the time.
	
	int placed; //placeCard() sets it to true. Used for deleting unised cards.
	bool duplicated; //on load, duplicated items are marked, then later removed.
	
	@STORED vec2 targetPos; 
	@STORED bool animating, removing; 
	 
	@property
	{
		string shortName() const
		{ return suit.text ~ rank.text ~ (deck ? deck.text : ""); } 
		void shortName(string s)
		{
			suit = s.get(0); 
			enforce(SuitChars.countUntil(suit)>=0, "Can't decode suit: "~suit.text.quoted~" "~s.quoted); 
			
			rank = s.get(1); 
			enforce(RankChars.countUntil(rank)>=0, "Can't decode rank: "~rank.text.quoted~" "~s.quoted); 
			
			deck = s.get(2, '0').to!ubyte.ifThrown(ubyte(0)); 
			enforce(deck.among('0', '1'), "Can't decode deck: "~s.quoted); 
		} 
	} 
	
	vec2 initialAnimatedPos()
	{ return vec2(10000, 0).rotate(shortName.hashOf); } 
	
	int suitIdx()
	{ return SuitChars.countUntil(suit).to!int; } 
	int rankIdx()
	{ return RankChars.countUntil(rank).to!int; } 
	
	File file()
	{ return ((faceUp)?(cardFaceFile(suitIdx, rankIdx)) :(cardBackFile(deck))) ~ (horizontal ? "?rotate=1" : ""); }  
	
	void beforeSave()
	{ storedPos = outerPos; } 
	void afterLoad()
	{ outerPos = storedPos; } 
	
	override void rearrange()
	{
		vec2 s = cardSize; 
		if(horizontal) swap(s.x, s.y); 
		outerSize = s; 
	} 
	
	@property
	{
		vec2 center()
		{
			rearrange; 
			return outerBounds.center; 
		} 
		void center(vec2 c)
		{
			rearrange; 
			outerPos = c - outerSize/2; 
		} 
	} @property
	{
		vec2 targetCenter()
		{
			rearrange; 
			return targetPos + outerSize/2; 
		} 
		void targetCenter(vec2 c)
		{
			rearrange; 
			targetPos = c - outerSize/2; 
		} 
	} 
	
	bounds2 targetBounds()
	{
		rearrange; 
		return bounds2(targetPos, targetPos + outerSize); 
	} 
	
	override void draw(Drawing dr)
	{
		/+dr.drawGlyph(file, innerBounds, isSelected ? CS_CARD_SEL : CS_CARD, No.nearest); +/
		
		//dr.drawFontGlyph((cast(int)(textures_getNow(file))), innerBounds, clGray, 16); 
		dr.drawTexture_custom(
			(cast(int)(textures_getNow(file))), innerBounds, 
			((isSelected)?(CS_CARD_SEL):(CS_CARD)),
			RGBA(0), RGBA(0)
		); 
		
		version(/+$DIDE_REGION+/none) {
			if(isSelected)
			{ dr.alpha = .33; dr.color = clAccent; dr.fillRect(innerBounds); dr.alpha = 1; }
		}
		
		if(frmMain.hoveredCard is this)
		{
			dr.lineWidth = -1.01; dr.color = clYellow; dr.alpha = 0.5; 
			dr.drawRect(outerBounds.inflated(5)); 
			dr.alpha = 1; 
		}
	} 
} 


class FrmMain: UIWindow
{
	mixin autoCreate; 
	
	version(/+$DIDE_REGION CustomShader+/all)
	{
		struct CustomShaderParams
		{
			RGBA clAccent; 
			float cornerRadius = 10.41; 
			float borderWidth = 1.2; 
			float dummy; 
		} 
		
		CustomShaderParams customShaderParams; 
		mixin SetupMegaShader!
		(
			iq{
				/*The very first custom shader code*/
				#define clAccent (unpackUnorm4x8(UB.customShaderParams0))
				#define cornerRadius (uintBitsToFloat(UB.customShaderParams1))
				#define borderWidth (uintBitsToFloat(UB.customShaderParams2))
				#define CS getFragCustomShaderIdx
				
				float rectDist(vec2 p, vec2 mi, vec2 ma)
				{ return length(p - max(vec2(0), min(ma-mi, p-mi)) - mi); } 
				
				vec4 customShader()
				{
					vec4 c = readFilteredSample(true); 
					
					float range = cornerRadius; 
					vec2 size = vec2(getTexSize(fragTexHandle)); 
					vec2 p = fragTexCoordXY * size; 
					vec2 mi = vec2(0) + vec2(range); 
					vec2 ma = size - vec2(range); 
					float dist = rectDist(p, mi, ma); 
					
					float pixelRange = length(dFdx(p)); 
					float blackRange = range-borderWidth; 
					float blackness = smoothstep(blackRange-min(pixelRange, blackRange), blackRange, dist); 
					float alpha = 1-smoothstep(range-min(pixelRange, range), range, dist); 
					c.rgb = mix(c.rgb, vec3(0), blackness); 
					c.a *= alpha; 
					
					if(CS==$(CS_CARD_SEL))
					c.rgb = mix(c.rgb, clAccent.rgb, clAccent.a); 
					return c; 
				} 
			}.text
		); 
		
		void updateCustomShaderParams()
		{
			with(customShaderParams)
			{
				clAccent = vec4(.clAccent.from_unorm, .4).to_unorm; 
				mixin(同!(q{float/+w=6 h=1 min=0 max=32 sameBk=1 rulerSides=3 rulerDiv0=11+/},q{cornerRadius},q{0x19A96D7903C7})); 
				mixin(同!(q{float/+w=6 h=1 min=0 max=4 sameBk=1 rulerSides=3 rulerDiv0=11+/},q{borderWidth},q{0x1A236D7903C7})); 
			}
			UB.setCustomShaderParams(customShaderParams); 
		} 
	}
	
	@STORED int backCardIdx; 
	
	@STORED Card[] cards; 
	Card[string] cardMap; 
	
	version(/+$DIDE_REGION Workspace+/all)
	{
		class MyContainer : Container
		{
			override void draw(Drawing dr)
			{
				//Note: Must not cull!!! Every picture should refresh their extra data.
				subCells.each!(c => c.draw(dr)); 
				
				//Note: This is where the extra data is combined.
				frmMain.drawOverlay(dr); 
			} 
		} 
		
		MyContainer workspace; 
		SelectionManager!Card selection; 
		
		auto calcBounds()
		{ return cards.fold!((a, b)=> a|b.outerBounds)(bounds2.init); }  
		
		void clear()
		{
			cards.clear; 
			cardMap.clear; 
			selection.notifyRemoveAll; 
		} 
		
		auto findCards(string mask)
		{ return cards.filter!(c => c.shortName.isWild(mask)); } 
		
		auto findCard(string s)
		{ return findCards(s).frontOrNull; } 
		
		private int placeIdx; 
		
		auto placeCard(vec2 centerPos, string shortName, bool faceUp, bool horizontal=false)
		{
			auto card = new Card; 
			card.shortName = shortName; 
			
			if(auto a = card.shortName in cardMap) { card = *a; }
			else {
				//initial position 
				card.outerPos = card.initialAnimatedPos; 
				
				cards ~= card; 
				cardMap[card.shortName] = card; 
			}
			
			card.faceUp = faceUp; 
			card.horizontal = horizontal; 
			card.targetCenter = centerPos; 
			
			card.placed = ++placeIdx; 
			card.animating = true; 
			
			return card; 
		} 
		
		void startRemoveCard(Card card)
		{
			card.targetPos = card.initialAnimatedPos; 
			card.removing = true; 
			card.animating = true; 
		} 
		
		void removeCard(Card card)
		{
			if(card.shortName !in cardMap) return; 
			const idx = cards.countUntil(card); 
			enforce(idx>=0, "Fatal error: Ccard storage inconsistenct"); 
			selection.notifyRemove(cards[idx]); 
			cards = cards.remove(idx); 
			cardMap.remove(card.shortName); 
			workspace.subCells = cast(Cell[]) cards; 
		} 
		
		void removeCards(R)(R cards)
		{
			auto arr = cards.array; 
			foreach(c; arr) removeCard(c); 
		} 
		
		auto selectedCards()
		{ return cards.filter!(c => c.isSelected); } auto unselectedCards()
		{ return cards.filter!(c => !c.isSelected); } 
		
		void selectAll(bool sel=true)
		{ foreach(c; cards) c.isSelected = sel; } void selectNone()
		{ selectAll(false); } 
		
		auto hoveredCard()
		{ return selection.hoveredItem; } 
	}
	
	override void onCreate()
	{
		initCardGfx; 
		backgroundColor = clGreen1; 
		
		workspace = new MyContainer; 
		with(workspace)
		{
			flags.noBackground = true; 
			flags.targetSurface = TargetSurface.world; 
		}
		selection = new typeof(selection); 
		
		loadFromJson(ini.read("settings", "")); 
	} 
	
	override void onDestroy()
	{ ini.write("settings", saveToJson); } 
	
	string saveToJson()
	{ return this.toJson; } 
	
	void loadFromJson(string str)
	{
		clear; 
		auto lvalueThis = this; 
		lvalueThis.fromJson(str); 
		
		//rebuild the map
		size_t[] rem; //remove duplicates
		foreach(i, c; cards) {
			if(c.shortName in cardMap)
			c.duplicated = true; 
			else
			cardMap[c.shortName] = c; 
		}
		
		cards = cards.remove!"a.duplicated"; 
	} 
	
	vec2 calcMassCenter()
	{
		if(cards.length) return cards.map!"a.center".mean; 
		else return vec2(0); 
	} 
	
	vec2 calcSelectedMassCenter()
	{
		if(cards.length) return selectedCards.map!"a.center".mean; 
		else return vec2(0); 
	} 
	
	void updateCards()
	{
		const animationT = calcAnimationT(deltaTime.value(second), 0.7, 0.1); 
		foreach(c; cards)
		{
			if(c.animating)
			if(follow(c.outerPos, c.targetPos, animationT, 1))
			c.animating = false; 
		}
		
		foreach(c; cards.filter!"!a.animating") c.targetPos = c.outerPos; 
		
		foreach(c; cards.filter!"!a.animating && a.removing".array) removeCard(c); 
	} 
	
	void setupPlayField(void delegate() fun)
	{
		//mark all existing cards to be unused, reset stuff
		foreach(c; cards)
		{
			c.placed = 0; 
			c.removing = false; c.animating = false; 
			c.isSelected = false; c.oldSelected = false; 
		}
		placeIdx = 0; 
		
		//do the placement of all cards
		fun(); 
		
		//remove unused cards
		foreach(c; cards.filter!"!a.placed") startRemoveCard(c); 
		
		//centralize visible cards
		auto validCards() { return cards.filter!"!a.removing"; } 
		if(!validCards.empty)
		{
			const ofs = validCards.map!"a.targetCenter".mean; 
			foreach(c; validCards) c.targetPos -= ofs; 
		}
		
		//set placement order
		cards = cards.sort!((a, b) => a.placed<b.placed).array; 
		
		//zoom bounds
		if(const bnd = validCards.map!"a.targetBounds".fold!"a|b"(bounds2.init))
		view.zoom(bnd); 
	} 
	
	string[] fullDeck(int numDecks=1)
	{
		string[] res; 
		enforce(numDecks.among(1, 2), "Invalid number of decks"); 
		foreach(z, d; ["", "1"].take(numDecks))
		foreach(y, s; SuitChars)
		foreach(x, r; RankChars)
		res ~= [s, r].text~d; 
		return res; 
	} 
	
	void placeGrid(string[] cards, int width)
	{
		const g = (cardSize + vec2(20)); 
		
		foreach(i, s; cards)
		{
			const x = i%width, y = i/width; 
			placeCard(vec2(x, y)*g, s, true, false); 
		}
	} 
	
	void placeKlondike(int numDecks = 1)
	{
		const g = (cardSize + vec2(20)); 
		auto deck = fullDeck(numDecks).randomShuffle; 
		
		foreach(x; 0..numDecks.predSwitch(1, 7, 2, 9))
		foreach(y; 0..x+1)
		placeCard(vec2(x, 1 + 0.25*y)*g, deck.fetchBack, x==y); 
		
		foreach(i, c; deck)
		placeCard(vec2(-0.005, -0.005)*i*g, c, false); 
	} 
	
	void placeCrazyQuilt()
	{
		const g = (vec2((cardSize.x+cardSize.y)/2) + vec2(20)); 
		auto deck = fullDeck(2).randomShuffle; 
		
		{
			float y = 1.1; 
			foreach(r; "AK")
			{
				foreach(s; SuitChars)
				{
					const card = [s, r].text ~ (random(2) ? "1" : ""); 
					deck = deck.remove(deck.countUntil(card)); 
					placeCard(vec2(0.4, y)*g, card, true, true); 
					y += 0.85; 
				}
				y += 0.15; 
			}
		}
		
		foreach(x; 0..8)
		foreach(y; 0..8)
		{ placeCard(vec2(x+2.5, y)*g, deck.fetchBack, true, (x^y)&1); }
		
		foreach(i, c; deck)
		placeCard(vec2(-0.005, -0.005)*i*g, c, false); 
	} 
	
	
	override void onUpdate()
	{
		if(canProcessUserInput) navigateView(!im.wantKeys, !im.wantMouse); 
		const canEdit = !im.wantMouse && view.isMouseInside && canProcessUserInput; 
		caption = i"FPS: $(FPS)  scale: $(view.invScale_anim
.format!"%20.10f")".text; 
		
		with(im)
		{
			Panel(
				PanelPosition.topLeft, 
				{
					Row(
						{
							if(Btn("Clear"))
							{ setupPlayField({}); }
							if(Btn("Random card"))
							{
								placeCard(
									vec2(0, 0), SuitChars.randomElement.text ~ 
									RankChars.randomElement.text ~ 
									"01".randomElement.text, random(2)==1, random(2)==1
								); 
							}
							if(Btn("Full deck")) { setupPlayField({ placeGrid(fullDeck, 13); }); }
							if(Btn("Full 2x decks")) { setupPlayField({ placeGrid(fullDeck(2), 13); }); }
							if(Btn("Klondike")) { setupPlayField({ placeKlondike; }); }
							if(Btn("Double Klondike")) { setupPlayField({ placeKlondike(2); }); }
							if(Btn("Crazy Quilt")) { setupPlayField({ placeCrazyQuilt; }); }
						}
					); 
				}
			); 
		}
		
		{
			selection.onBringToFront = (){
				cards = bringSelectedItemsToFront(cards, true); 
				return cards; 
			}; 
			selection.deselectBelow = true; 
			selection.update(canEdit, view, cards); 
			workspace.subCells = cast(Cell[]) cards; 
			workspace.rearrange; 
			im.root ~= workspace; 
		}
		
		view.subScreenArea = im.clientArea / clientSize; 
		
		static if(is(typeof(updateCustomShader))) updateCustomShader; 
		updateCards; 
		
		updateCustomShaderParams; invalidate; 
	} 
	
	override void onPaint()
	{
		//gl.clearColor(clGreen1); gl.clear(GL_COLOR_BUFFER_BIT); 
		
		static if(0)
		{
			auto dr = new Drawing; 
			dr.drawGlyph(File(`monitor:\`), vec2(0)); 
			dr.glDraw(view); 
			
			static bool running; 
			if(running.chkSet)
			spawn(
				{
					while(1)
					{
						bitmaps.refresh(`monitor:\`); 
						sleep(50); 
					}
				}
			); 
		}
	} 
	
	void drawOverlay(Drawing dr)
	{
		if(const bnd = selection.selectionBounds)
		{
			dr.color = clWhite; dr.lineWidth = -2.01; dr.lineStyle = LineStyle.dash; 
			dr.drawRect(bnd); 
			dr.lineStyle = LineStyle.normal; 
		}
		
		if(cards.length) {
			dr.pointSize = -10; 
			dr.color = clFuchsia; 
			dr.point(calcMassCenter); 
		}
		
		{
			dr.pointSize = -20; 
			dr.lineWidth = -10; 
			dr.fontHeight = -16; 
			
			foreach(i; 0..33)
			{
				dr.color = clWhite; 
				const p = vec2(1L<<i); 
				dr.line(vec2(0), p); 
				dr.point(p); 
				dr.textOut(p, i"  1<<$(i) = $(1L<<i)".text); 
			}
		}
	} 
} 