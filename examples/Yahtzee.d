//@exe
//@debug
///@release

//@compile -d-version=VulkanUI

import het.ui; 

immutable 	clGreen1 = mix(clGreen, clBlack, 0.2f),
	clGreen2 = clGreen; 

void UI_Die(int num, vec2 ofs = vec2(0))
{
	with(im)
	{
		immutable 	diceBorder = 8,
			diceSize = 64,
			dotOffset = 20,
			dotSize = 16.7f; 
		const valid = num.inRange(1, 6); 
		Container(
			{
				flags.noBackground = true; 
				flags.clipSubCells = ofs.y!=0; 
				margin = "4"; 
				bkColor = clGreen1; //should be inherited
				innerSize = vec2(diceSize + diceBorder*2); 
				ofs *= innerSize; 
				Row(
					{
						outerPos = ofs; 
						border.width = diceBorder; 
						border.color = bkColor = valid ? clWhite : clGreen1; 
						innerSize = vec2(diceSize); 
						if(valid)
						{
							void customDraw(IDrawing dr, .Container cntr)
							{
								with(dr)
								{
									color = clRed; 
									pointSize = dotSize; 
									void dot(int x, int y)
									{ point((vec2(x, y)) * dotOffset + cntr.innerSize/2); } 
									
									if(num & 1)
									dot(0, 0); 
									if(num > 1)
									{ dot(-1, -1); dot(1,  1); }
									if(num > 3)
									{ dot(-1,  1); dot(1, -1); }
									if(num > 5)
									{ dot(-1,  0); dot(1,  0); }
								}
							} 
							addDrawCallback(&customDraw); 
						}
					}
				); 
			}
		); 
	}
} 



	
	@WindowStyle(WS_OVERLAPPEDWINDOW - WS_SIZEBOX - WS_MAXIMIZEBOX, WS_EX_TOPMOST*0) class FrmYahtzee: UIWindow
{
	mixin autoCreate; 
	mixin SetupMegaShader!""; 
	
	immutable
		animationLimit = 0.01f,
		animationScale = 1.4f; 
	
	static int random6()
	{
		static int cnt; 
		return random(6)+1; 
		//return cnt++/6%6+1;
	} 
	
	struct DieStruct
	{
		int num; 
		vec2 ofs; 	//ofs.y: -1 out of screen on top, will gravitate to 0. ofs>1 is out of screen on bottom.
			//ofs.x is for sorting
		bool hold; 
	} 
	
	DieStruct[5] dice; 
	int turnIdx, rollIdx, maxTurn; 
	bool pendingRoll; //roll was pressed. after the animation ends, it must update turn and roll indices.
	int[string] scoreMap; 
	int grandTotal; 
	
	void initialize()
	{
		scoreMap.clear; 
		grandTotal = 0; 
		turnIdx = rollIdx = 0; 
		maxTurn = 13; //bonus yahtzee will increase this
	} 
	
	void unhold()
	{
		foreach(ref d; dice)
		d.hold = false; 
	} 
	
	void roll()
	{
		foreach(ref d; dice)
		if(!d.hold)
		d.ofs.y = animationLimit; //just start it to fall
	} 
	
	bool animating_y()
	{ return dice[].any!(d => d.ofs.y!=0); } //only fall animations
	bool animating()
	{ return dice[].any!(d => !isnull(d.ofs)); } //fall and sort
	bool gameOver()
	{ return turnIdx>=maxTurn; } 
	
	void update()
	{
		
		//fall out on bottom
		foreach(ref d; dice)
		{
			if(d.ofs.y>0)
			{
				d.ofs.y *= animationScale; 
				if(d.ofs.y>1)
				{
						//start to scroll in a nem random die
					d.ofs.y = -1.1; 
					d.num = random6; 
				}
			}
		}
		
		//fall in from top
		foreach(ref d; dice)
		{
			if(d.ofs.y<0)
			{
				d.ofs.y /= animationScale; 
				if(d.ofs.y > -animationLimit)
				{
					d.ofs.y = 0; //just arrived
				}
				break; //only process one incoming at a time
			}
		}
		
		//animate sorting
		foreach(ref d; dice)
		if(d.ofs.x)
		{
			d.ofs.x /= animationScale; 
			if(abs(d.ofs.x)<animationLimit)
			d.ofs.x = 0; 
		}
		
		//initiate sorting
		if(!animating_y)
		{
			foreach(i; 0..dice.length-1)
			{
				if(dice[i].ofs.x==0 && dice[i+1].ofs.x==0 && dice[i].num > dice[i+1].num)
				{
					swap(dice[i].num , dice[i+1].num ); 
					swap(dice[i].hold, dice[i+1].hold); 
					dice[i  ].ofs.x =  1; 
					dice[i+1].ofs.x = -1; 
				}
			}
		}
	} 
	
	override void onCreate()
	{
		caption = "Yahtzee!"; 
		initialize; 
	} 
	
	override void onUpdate()
	{
		//navigateView(!im.wantKeys, !im.wantMouse); 
		//invalidate; 
		
		update; //the game
		const en = !animating; 
		
		if(en && chkClear(pendingRoll))
		{ rollIdx++; }
		
		with(im)
		{
			Panel(
				PanelPosition.topLeft, 
				{
					bkColor = clGreen1; 
					border.width = 0; 
					Column(
						{
							padding = "16"; 
							style.bkColor = bkColor = clGreen2; 
							//style.fontColor = clYellow; fh = 72; Text("Yahtzee");
							Column(
								{
									style.bkColor = bkColor = clGreen1; 
									padding = "4"; 
									Row(
										{
											foreach(idx, ref d; dice)
											Column(
												{
													flags.noBackground = true; 
													UI_Die(d.num, d.ofs); 
													if(
														Btn(
															{ margin = "4"; Text("HOLD"); }, 
															genericId(idx), 
															selected(d.hold), 
															enable(en && d.num && rollIdx<3 && !gameOver )
														)
													)
													{ d.hold.toggle; }
												}
											); 
										}
									); 
									if(Btn({ margin = "4"; Text("ROLL"); }, enable(en && rollIdx<3)))
									{
										if(gameOver)
										{ initialize; unhold; roll; pendingRoll = true; }else
										{
											if(dice[].all!(d => d.hold))
											{ rollIdx = 3; }else
											{ roll; pendingRoll = true; }
										}
									}
									
									//status text
									Row(
										{
												margin = "4"; fh = 18; style.fontColor = clWhite; 
											
											if(gameOver)
											{
												Text("Game Over.  Final score: "~bold(grandTotal.text)~"\n"); 
												Text("You can press ROLL, to start a new game."); 
											}else
											{
												Text("Turn: "~bold((turnIdx+1).text)~" of "~maxTurn.text, "   "); 
												Text("Roll: "~bold(rollIdx.predSwitch(0, "First", 1, "Second", "Last"))~"\n"); 
												
												if(animating_y)
												Text("Rolling..."); 
												else if(animating) Text("Sorting..."); 
												else {
													auto s = rollIdx.predSwitch(
														0, "Press ROLL!",
														1, "You can HOLD some dice and press ROLL or write down a SCORE.",
														2, "You can HOLD more dice and ROLL again or write down a SCORE.",
														"No more rolls, You have to write down a SCORE now."
													); 
													foreach(w; ["ROLL", "HOLD", "SCORE"])
													s = s.replace(w, bold(w)); 
													Text(s); 
												}
											}
											
										}
									); 
									
								}
							); 
							
							Spacer(8); 
							
							//Score table: https://www.memory-improvement-tips.com/support-files/yahtzee-score-sheets.pdf
							Column(
								{
									style = tsNormal; bkColor = style.bkColor; 
									fh = 18; 
									padding = "4"; 
									
									auto d = dice[].map!(d => d.num).array.sort.array; 
									const canScore = !d.canFind(0) && !animating; 
									
									int scoreAccum = 0; 
									
									void ScoreRow(string title, string hintText, void delegate() fun)
									{
										Row(
											{
												void Cell(void delegate() fun)
												{
													Row(
														{
															padding = "0 4"; 
															innerHeight = fh+12; 
															flags.vAlign = VAlign.center; 
															border = "1 normal black"; border.extendBottomRight = true; 
															fun(); 
														}
													); 
												} 
												
												Cell(
													{
															width = fh*8; 
														if(hintText.length)
														{
															//Todo: make this available in "im" scope.
															actContainer.id = actContainer.id.combine(genericId(title)); //Todo: give a name to this too
															auto hit = hitTest(true); //Todo: hint can go out of the client area.
															if(hit.hover)
															{
																auto hr = hint(hintText); 
																hr.owner = actContainer; 
																hr.bounds = hit.hitBounds; 
																addHint(hr); 
															}
														}
														Text(title); 
													}
												); 
												Cell(
													{
															width = fh*2.5; flags.hAlign = HAlign.center; 
														fun(); 
													}
												); 
											}
										); 
									} 
									
									void writeScore(string title, int score)
									{
										scoreMap[title] = score; 
										rollIdx = 0;  turnIdx++; 
										if(turnIdx<maxTurn)
										{ unhold; roll; pendingRoll = true; }else
										{
											beep; //end of game
										}
									} 
									
									void Score(string title, string hintText, bool pred, int score)
									{
										score *= pred; 
										
										ScoreRow(
											title, hintText, {
												if(auto sc = title in scoreMap)
												{
													Text(bold((*sc).text)); 
													scoreAccum += *sc; 
												}else
												{
													if(canScore)
													{
														if(Btn({ Text(score.text); innerWidth = fh*2; }, genericId(title)))
														{
															scoreAccum += score; 
															writeScore(title, score); 
														}
													}else
													{ Text(" "); }
												}
											}
										); 
									} 
									
									void Summary(string title, string hintText, int sum)
									{ ScoreRow(title, hintText, { Text(sum ? bold(sum.text) : " "); }); } 
									
									//Upper section --------------------------------------------
									scoreAccum = 0; 
									foreach(i, name; "Aces Twos Threes Fours Fives Sixes".split)
									Score(
										format!"%s %s = %s"(name, cast(wchar)(0x2680+i), i+1), //Todo: proper elastic tabstops in table columns
										format!"Count and add only %s"(name),
										true, d.filter!(a => a==i+1).sum
									); 
									
									int totalUpper = scoreAccum; 	 Summary("TOTAL SCORE", "", totalUpper); 
									int upperBonus = totalUpper>=63 ? 35 : 0; 	 Summary("BONUS", "If total score is 63 or over. Score 35", upperBonus); 
									totalUpper += upperBonus; 	 Summary("TOTAL of upper section", "", totalUpper); 
									
									//Lower section --------------------------------------------
									scoreAccum = 0; 
									bool isNOfAKind(int n)
									{ return d.group.any!(a => a[1]>=n); } 
									bool isStraight(int n)
									{ return d.slide(2).map!"a[1]-a[0]".array.canFind([1].replicate(n-1)); } 
									bool isFullHouse()
									{ return d.group.map!"a[1]".array.sort.equal([2, 3]); } 
									
									Score("3 of a kind"   , "Add total of all dice"    , isNOfAKind(3), d.sum); 
									Score("4 of a kind"   , "Add total of all dice"    , isNOfAKind(4), d.sum); 
									Score("Full House"    , "Score 25"                 , isFullHouse  , 25   ); 
									Score("Small straight", "Sequence of 4. Score 30"  , isStraight(4), 30   ); 
									Score("Large straight", "Sequence of 5. Score 40"  , isStraight(5), 40   ); 
									Score("YAHTZEE"       , "5 of a kind. Score 50"    , isNOfAKind(5), 50   ); 
									Score("Chance"        , "Score total of all 5 dice", true         , d.sum); 
									
									enum sYahtzeeBonus = "YAHTZEE BONUS"; 
									int yahtzeeBonus()
									{ return scoreMap.get(sYahtzeeBonus); } 
									ScoreRow(
										sYahtzeeBonus, "Score 100 for every additional YAHTZEEs.\nUnless you've scored a 0 to YAHTZEE previously.",
										{
											if(canScore && isNOfAKind(5) && scoreMap.get("YAHTZEE")>0)
											{
												if(Btn("+100"))
												{
													maxTurn++; //this is an extra bonus turn, not a real one out of the 13.
													writeScore(sYahtzeeBonus, yahtzeeBonus+100); 
												}
											}else
											{
												int b = yahtzeeBonus; 
												if(b)
												Text(bold(b.text)); else
												Text(" "); 
											}
										}
									); 
									scoreAccum += yahtzeeBonus; 
									
									int totalLower = scoreAccum; 	Summary("TOTAL of lower section", "", totalLower); 
									grandTotal = totalUpper + totalLower; 	Summary("GRAND TOTAL", "", grandTotal); 
									
								}
							); 
						}
					); 
				}
			); 
		}
		
		clientSize = im.surfaceBounds[1].size.ifloor; 
	} 
	
} 