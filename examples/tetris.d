//@exe
//@debug
///@release

//@compile --d-version=VulkanUI

//Todo: game over text needs a dark background.

import het.ui; 

class FrmTetris: UIWindow
{
	mixin autoCreate; mixin SetupMegaShader!""; 
	//settings /////////////////////////////////////
	enum KeyRepeatSpeed	  = 60/15, //Hz
	FieldWidth	  = 12,
	FieldHeight	  = 18,
	CollapsingMaxTick	  = 12; 
	
	//assets //////////////////////////////////////
	const tetronimos = [
		0b_0100_0110_0010_1100_0110_0010_0100,
		0b_0100_0110_0110_0100_0100_0110_0110,
		0b_0100_0000_0010_0100_0100_0100_0010,
		0b_0100_0000_0000_0000_0000_0000_0000,
		
		0b_0000_0110_0100_0010_1110_1100_0110,
		0b_1111_0110_1110_1110_0010_0110_1100,
		0b_0000_0000_0000_0000_0000_0000_0000,
		0b_0000_0000_0000_0000_0000_0000_0000,
		
		0b_0100_0110_0100_1000_0010_0010_0100,
		0b_0100_0110_0110_1000_0010_0110_0110,
		0b_0100_0000_0100_1100_0110_0100_0010,
		0b_0100_0000_0000_0000_0000_0000_0000,
		
		0b_0000_0110_1110_1110_1000_1100_0110,
		0b_1111_0110_0100_1000_1110_0110_1100,
		0b_0000_0000_0000_0000_0000_0000_0000,
		0b_0000_0000_0000_0000_0000_0000_0000,
	]; 
	
	bool sample(int x, int y, int t, int r)
	{ return tetronimos[r%4*4+y]>>(t*4+3-x) & 1; } 
	
	int[FieldWidth][FieldHeight] field; 
	const palette = [
		clBlack, clGray, clRainbowAqua, clRainbowYellow, clRainbowPurple, 
		clRainbowBlue, clRainbowOrange, clRainbowGreen, clRainbowRed
	]; 
	
	void initField()
	{
		foreach(y; 0..FieldHeight)
		foreach(x; 0..FieldWidth)
		{ field[y][x] = x==0 || x==FieldWidth-1 || y==FieldHeight-1 ? 1 : 0; }
	} 
	
	auto dr() => staticDr; 
	
	void drawCell(int x, int y, int c)
	{
		if(!c)
		return; 
		dr.color = palette[c]; 
		dr.fillRect(x, y, x+0.95, y+0.95); 
		
		if(c>1)
		{
			//highlights
			dr.lineWidth = 0.1; 
			
			dr.color = palette[c].darken(0.5); 
			dr.vLine(x+0.93, y+0.93, y+0.07); 
			dr.hLine(x+0.93, y+0.93, x+0.07); 
			
			dr.color = palette[c].lighten(0.5); 
			dr.vLine(x+0.07, y+0.07, y+0.90); 
			dr.hLine(x+0.07, y+0.07, x+0.90); 
		}
	} 
	
	void drawField()
	{
		foreach(y; 0..FieldHeight)
		foreach(x; 0..FieldWidth)
		drawCell(x, y, field[y][x]); 
	} 
	
	//keyboard input //////////////////////////////
	enum Key
	{left, right, down, rotate}; 
	const keyNames = ["Left", "Right", "Down", "Up"]; 
	
	int[4] keyTicks; //0: off 1..n: hold time
	
	//updates keyboard states
	void updateKeys()
	{
		foreach(k; 0..keyNames.length)
		keyTicks[k] = inputs.active(keyNames[k]) ? keyTicks[k]+1 : 0; 
	} 
	
	//queryes the keys. Most of them are repeated.
	bool pressed(Key k)
	{
		return keyTicks[k]==1
		|| k!=Key.rotate && (keyTicks[k] % KeyRepeatSpeed == 1)
		/+rotate isn't repeated+/; 
	} 
	
	//state /////////////////////////////////////
	
	int actT, nextT, actX, actY, actR; 
	int fallTick, collapsingTick; 
	int[] collapsingRows; 
	int level, score, collapsingCnt; 
	bool gameOver; 
	
	int speed()
	=> (iround(60/(1.25^^(level-1)))); 
	
	void newTetronimo()
	{
		gameOver = false; 
		actT = nextT; 
		nextT = random(7); 
		actX = FieldWidth/2-2; 
		actY = 0; 
		actR = 0; 
		fallTick = 0; 
		collapsingTick = 0; 
		collapsingRows = []; 
		
		if(checkCollision(actX, actY, actT, actR))
		{
			//game over
			gameOver = true; 
		}
	} 
	
	void newGame()
	{
		initField; 
		nextT = random(7); 
		newTetronimo; 
		score = 0; 
		level = 1; 
		collapsingCnt = 0; 
	} 
	
	void drawTetronimo(int x, int y, int t, int r)
	{
		foreach(j; 0..4)
		foreach(i; 0..4)
		if(sample(i, j, t, r))
		drawCell(x+i, y+j, t+2); 
	} 
	
	bool checkCollision(int x, int y, int t, int r)
	{
		foreach(j; 0..4)
		foreach(i; 0..4)
		if(sample(i, j, t, r) && field[y+j][x+i])
		return true; 
		return false; 
	} 
	
	void sinkTetronimo(int x, int y, int t, int r)
	{
		foreach(j; 0..4)
		foreach(i; 0..4)
		if(sample(i, j, t, r))
		field[y+j][x+i] = t+2; 
	} 
	
	void moveDown()
	{
		//check collision
		if(!checkCollision(actX, actY+1, actT, actR))
		{
			//fall down
			actY++; 
		}else
		{
				//there is a collision
			sinkTetronimo(actX, actY, actT, actR); 
			score += 25; 
			
			foreach(y; 0..FieldHeight-1)
			if(field[y][].all)
			collapsingRows ~= y; 
			
			if(!collapsingRows.empty)
			{
				score += 100<<collapsingRows.length-1; 
				
				collapsingCnt += collapsingRows.length; 
				if(collapsingCnt>10)
				{ collapsingCnt -= 10; level++; }
				
			}else
			{ newTetronimo; }
		}
	} 
	
	void updateGame()
	{
		if(gameOver)
		{
			if(inputs["Space"].pressed)
			newGame; 
			return; 
		}
		
		if(!collapsingRows.empty)
		{
			collapsingTick += 1; 
			if(collapsingTick>=CollapsingMaxTick)
			{
				foreach(r; collapsingRows)
				{
					for(int y=r; y>2; y--)
					{ field[y][] = field[y-1][]; }
				}
				newTetronimo; 
			}
			return; 
		}
		
		if(pressed(Key.left  ) && !checkCollision(actX-1, actY, actT, actR  ))
		actX--; 
		if(pressed(Key.right ) && !checkCollision(actX+1, actY, actT, actR  ))
		actX++; 
		if(pressed(Key.rotate) && !checkCollision(actX  , actY, actT, actR+1))
		actR++; 
		
		//gravity
		fallTick++; 
		if(pressed(Key.down) || fallTick>speed)
		{
			fallTick = 0; 
			moveDown; 
		}
	} 
	
	
	override void onCreate()
	{ newGame; } 
	
	override void onUpdate()
	{
		//set the view to fixed
		view.zoom(bounds2(-1, 0, FieldWidth+8, FieldHeight)); 
		
		
		updateKeys; 
		updateGame; 
		invalidate; 
	} 
	
	override void beforeImDraw()
	{
		drawField; 
		
		if(collapsingRows.empty && (!gameOver || QPS.value(second).fract<0.5))
		drawTetronimo(actX, actY, actT, actR); 
		
		if(!collapsingRows.empty)
		{
			dr.alpha = (collapsingTick&3)/3.0f; 
			dr.color = clWhite; 
			foreach(r; collapsingRows)
			dr.fillRect(1, r, FieldWidth-1, r+1); 
			dr.alpha = 1; 
		}
		
		dr.fontHeight = 1; 
		dr.color = clWhite; 
		
		dr.textOut(vec2(FieldWidth+1, 2), "LEVEL"); 
		auto s = level.text; dr.textOut(vec2(FieldWidth+7-dr.textWidth(s), 2), s); 
		dr.textOut(vec2(FieldWidth+1, 4), "SCORE"); 
		s = score.text; dr.textOut(vec2(FieldWidth+7-dr.textWidth(s), 4), s); 
		dr.textOut(vec2(FieldWidth+1, 6), "NEXT"); 
		drawTetronimo(FieldWidth+3, 6, nextT, 0); 
		
		if(gameOver)
		{
			dr.fontHeight = 2; 
			dr.color = clWhite; 
			s = "GAME OVER"; 
			dr.textOut(vec2(FieldWidth/2-dr.textWidth(s)/2, FieldHeight/2-1), s); 
			
			dr.fontHeight = 1; 
			s = "Press SPACE to continue"; 
			dr.textOut(vec2(FieldWidth/2-dr.textWidth(s)/2, FieldHeight/2+1), s); 
		}
	} 
} 