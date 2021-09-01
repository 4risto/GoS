if myHero.charName ~= "Lucian" then return end 	

local myHero = _G.myHero

local LocalGetTickCount         = GetTickCount
local LocalVector		= Vector
local LocalCallbackAdd		= Callback.Add
local LocalCallbackDel		= Callback.Del
local LocalDrawLine		= Draw.Line
local LocalDrawColor		= Draw.Color
local LocalDrawCircle		= Draw.Circle
local LocalCastSpell            = Control.CastSpell
local LocalControlMove          = Control.Move
local LocalControlIsKeyDown	= Control.IsKeyDown
local LocalControlKeyUp  	= Control.KeyUp
local LocalControlKeyDown	= Control.KeyDown
local LocalGameCanUseSpell	= Game.CanUseSpell
local LocalGameHeroCount 	= Game.HeroCount
local LocalGameHero 		= Game.Hero
local LocalGameMinionCount 	= Game.MinionCount
local LocalGameMinion 		= Game.Minion
local ITEM_1			= ITEM_1
local ITEM_2			= ITEM_2
local ITEM_3			= ITEM_3
local ITEM_4			= ITEM_4
local ITEM_5			= ITEM_5
local ITEM_6			= ITEM_6
local ITEM_7			= ITEM_7
local _Q			= _Q
local _W			= _W
local _E			= _E
local _R		        = _R
local READY 		        = READY
local LocalTableInsert          = table.insert
local LocalTableSort            = table.sort
local LocalTableRemove          = table.remove;
local tonumber		        = tonumber
local ipairs		        = ipairs
local pairs		        = pairs

local Menu, Q, Q2, W, E, R

local Mode = function()
        if _G.SDK.Orbwalker.Modes[_G.SDK.ORBWALKER_MODE_COMBO] then
                return "Combo"
        elseif _G.SDK.Orbwalker.Modes[_G.SDK.ORBWALKER_MODE_HARASS] then
                return "Harass"
        elseif _G.SDK.Orbwalker.Modes[_G.SDK.ORBWALKER_MODE_LANECLEARS] then
                return "LaneClear"
        elseif _G.SDK.Orbwalker.Modes[_G.SDK.ORBWALKER_MODE_JUNGLECLEAR] then
                return "LaneClear"
        elseif _G.SDK.Orbwalker.Modes[_G.SDK.ORBWALKER_MODE_LASTHIT] then
                return "LastHit"
        elseif _G.SDK.Orbwalker.Modes[_G.SDK.ORBWALKER_MODE_FLEE] then
                return "Flee"
        end
end

local GetTarget = function(range)
        return _G.SDK.TargetSelector:GetTarget(range, _G.SDK.DAMAGE_TYPE_PHYSICAL, myHero.pos)
end

local ValidTarget =  function(unit, range)
	local range = type(range) == "number" and range or math.huge
	return unit and unit.team ~= myHero.team and unit.valid and unit.distance <= range and not unit.dead and unit.isTargetable and unit.visible
end

local GetEnemyHeroes = function()
        local result = {}
	for i = 1, LocalGameHeroCount() do
		local Hero = LocalGameHero(i)
		if Hero.isEnemy then
			LocalTableInsert(result, Hero)
		end
	end
	return result
end

local GetMinions = function(range)
        local result = {}
	for i = 1, LocalGameMinionCount() do
		local minion = LocalGameMinion(i)
		if minion and ValidTarget(minion, range) and minion.isEnemy and minion.team ~= 300 then
			LocalTableInsert(result, minion)
		end
	end
	return result
end

local GetJungleMinions = function(range)
        local result = {}
	for i = 1, LocalGameMinionCount() do
		local minion = LocalGameMinion(i)
		if minion and ValidTarget(minion, range) and minion.team == 300 then
			LocalTableInsert (result, minion)
		end
	end
	return result
end

local GetDistanceSqr = function(Pos1, Pos2)
	local Pos2 = Pos2 or myHero.pos
	local dx = Pos1.x - Pos2.x
	local dz = (Pos1.z or Pos1.y) - (Pos2.z or Pos2.y)
	return dx^2 + dz^2
end

local GetDistance = function(Pos1, Pos2)
	return math.sqrt(GetDistanceSqr(Pos1, Pos2))
end

local GetPercentHP = function(unit)
        return 100 * unit.health / unit.maxHealth
end

local GetPercentMP = function(unit)
        return 100 * unit.mana / unit.maxMana
end

local HealthPrediction = function(unit, time)
        local orb
        if _G.SDK then
        	orb = _G.SDK.HealthPrediction:GetPrediction(unit, time)
        elseif _G.Orbwalker then
        	orb = GOS:HP_Pred(unit, time)
        end
        return orb
end

local VectorPointProjectionOnLineSegment = function(v1, v2, v)
	local cx, cy, ax, ay, bx, by = v.x, (v.z or v.y), v1.x, (v1.z or v1.y), v2.x, (v2.z or v2.y)
        local rL = ((cx - ax) * (bx - ax) + (cy - ay) * (by - ay)) / ((bx - ax) ^ 2 + (by - ay) ^ 2)
        local pointLine = { x = ax + rL * (bx - ax), y = ay + rL * (by - ay) }
        local rS = rL < 0 and 0 or (rL > 1 and 1 or rL)
        local isOnSegment = rS == rL
        local pointSegment = isOnSegment and pointLine or {x = ax + rS * (bx - ax), y = ay + rS * (by - ay)}
	return pointSegment, pointLine, isOnSegment
end

local EnemyMinionsOnLine = function(sp, ep, width)
        local c = 0
        for i, minion in pairs(GetMinions()) do
        	if minion and not minion.dead and minion.isEnemy then
        		local pointSegment, pointLine, isOnSegment = VectorPointProjectionOnLineSegment(sp, ep, minion.pos)
        		if isOnSegment and GetDistanceSqr(pointSegment, minion.pos) < (width + minion.boundingRadius)^2 and GetDistanceSqr(sp, ep) > GetDistanceSqr(sp, minion.pos) then
				c = c + 1
			end
        	end
        end
        return c
end

local GetBestLinearFarmPos = function(range, width)
	local pos, hit = nil, 0
	for i, minion in pairs(GetMinions()) do
		if minion and not minion.dead and minion.isEnemy then
			local EP = myHero.pos:Extended(minion.pos, range)
			local C = EnemyMinionsOnLine(myHero.pos, EP, width)
			if C > hit then
				hit = C
				pos = minion.pos
			end
		end
	end
	return pos, hit
end

local CircleCircleIntersection = function(c1, c2, r1, r2) 
        local D = GetDistance(c1, c2)
        if D > r1 + r2 or D <= math.abs(r1 - r2) then return nil end 
        local A = (r1 * r2 - r2 * r1 + D * D) / (2 * D) 
        local H = math.sqrt(r1 * r1 - A * A)
        local Direction = (c2 - c1):Normalized() 
        local PA = c1 + A * Direction 
        local S1 = PA + H * Direction:Perpendicular() 
        local S2 = PA - H * Direction:Perpendicular() 
        return S1, S2 
end

local ClosestToMouse = function(p1, p2) 
        if GetDistance(mousePos, p1) > GetDistance(mousePos, p2) then return p2 else return p1 end
end

local DrawLine3D = function(x1, y1, z1, x2, y2, z2, width, color)
	local xyz_1 = LocalVector(x1, y1, z1):To2D()
	local xyz_2 = LocalVector(x2, y2, z2):To2D()
	LocalDrawLine(xyz_2.x, xyz_2.y, xyz_1.x, xyz_1.y, width or 1, color or LocalDrawColor(255, 255, 255, 255))
end

local DrawRectangleOutline = function(startPos, endPos, width, color, ex)     
        local c1 = startPos+Vector(Vector(endPos)-startPos):Perpendicular():Normalized()*width     
        local c2 = startPos+Vector(Vector(endPos)-startPos):Perpendicular2():Normalized()*width     
        local c3 = endPos+Vector(Vector(startPos)-endPos):Perpendicular():Normalized()*width     
        local c4 = endPos+Vector(Vector(startPos)-endPos):Perpendicular2():Normalized()*width     
        DrawLine3D(c1.x,c1.y,c1.z,c2.x,c2.y,c2.z,math.ceil(width/ex),color)     
        DrawLine3D(c2.x,c2.y,c2.z,c3.x,c3.y,c3.z,math.ceil(width/ex),color)     
        DrawLine3D(c3.x,c3.y,c3.z,c4.x,c4.y,c4.z,math.ceil(width/ex),color)     
        DrawLine3D(c1.x,c1.y,c1.z,c4.x,c4.y,c4.z,math.ceil(width/ex),color) 
end 

local DrawTriangle = function(vector3, color, thickness, size, rot, speed, yShift, yLevel) 	
        if not vector3 then vector3 = LocalVector(myHero.pos) end 	
        if not color then color = LocalDrawColor(255, 255, 255, 255) end 	
        if not thickness then thickness = 3 end 	
        if not size then size = 75 end 	
        if not speed then speed = 1 else speed = 1-speed end
        vector3.y = vector3.y + yShift + (rot * yLevel) 
        local a2v = function(a, m) m = m or 1 return math.cos(a) * m, math.sin(a) * m end
        local RX1, RZ1 = a2v((rot*speed), size) 	
        local RX2, RZ2 = a2v((rot*speed) + math.pi*0.33333, size) 	
        local RX3, RZ3 = a2v((rot*speed) + math.pi*0.66666, size) 	
        local PX1 = vector3.x + RX1 	
        local PZ1 = vector3.z + RZ1 	
        local PX2 = vector3.x + RX2 	
        local PZ2 = vector3.z + RZ2 	
        local PX3 = vector3.x + RX3 	
        local PZ3 = vector3.z + RZ3 	
        local PXT1 = vector3.x - (PX1 - vector3.x) 	
        local PZT1 = vector3.z - (PZ1 - vector3.z) 	
        local PXT3 = vector3.x - (PX3 - vector3.x) 	
        local PZT3 = vector3.z - (PZ3 - vector3.z)  	
        DrawLine3D(PXT1, vector3.y, PZT1, PXT3, vector3.y, PZT3, thickness, color) 	
        DrawLine3D(PXT3, vector3.y, PZT3, PX2, vector3.y, PZ2, thickness, color) 	
        DrawLine3D(PX2, vector3.y, PZ2, PXT1, vector3.y, PZT1, thickness, color) 
end

local GetItemSlot = function(unit, id)
        for i = ITEM_1, ITEM_7 do
		if unit:GetItemData(i).itemID == id and unit:GetSpellData(i).currentCd == 0 then 
			return i
		end
	end
	return nil
end

local CastQ = function(target) 
        LocalCastSpell(HK_Q, target) 
end 

local CastQ2 = function(target) 
        local pred = target:GetPrediction(Q.speed, Q.delay)
        if pred == nil then return end 
        local targetPos = LocalVector(myHero.pos):Extended(pred, Q2.range) 
        if Q.IsReady() and ValidTarget(target, Q2.range) and GetDistance(myHero.pos, pred) <= Q2.range then 
        	for i, minion in pairs(GetMinions()) do 
        		if minion and not minion.dead and ValidTarget(minion, Q.range) then 
        			local minionPos = LocalVector(myHero.pos):Extended(LocalVector(minion.pos), Q2.range)
        			if GetDistance(targetPos, minionPos) <= Q2.width/2 then 
        				LocalCastSpell(HK_Q, minion) 
        			end 
        		end 
        	end 
        end 
end

local CastW = function(target, fast) 
        if not fast then 
        	local pred = target:GetPrediction(W.speed, W.delay)
        	local col = target:GetCollision(W.width, W.speed, W.delay)
        	if col < 1 then
        		LocalCastSpell(HK_W, pred) 
        	end
        else 
        	LocalCastSpell(HK_W, target.pos)
        end 
end

local CastE = function(target, mode, range) 
        if mode == 1 then 
        	local c1, c2, r1, r2 = LocalVector(myHero.pos), LocalVector(target.pos), myHero.range, 525 
        	local O1, O2 = CircleCircleIntersection(c1, c2, r1, r2) 
        	if O1 or O2 then 
        		local pos = c1:Extended(LocalVector(ClosestToMouse(O1, O2)), range)
        		LocalCastSpell(HK_E, pos) 
        	end 
        elseif mode == 2 then 
        	local pos = Vector(myHero.pos):Extended(mousePos, range)
        	LocalCastSpell(HK_E, pos) 
        elseif mode == 3 then 
        	local pos = LocalVector(myHero.pos):Extended(LocalVector(target.pos), range)
        	LocalCastSpell(HK_E, pos)
        end 
end 

local KB = { [ITEM_1] = HK_ITEM_1, [ITEM_2] = HK_ITEM_2, [ITEM_3] = HK_ITEM_3, [ITEM_4] = HK_ITEM_4, [ITEM_5] = HK_ITEM_5, [ITEM_6] = HK_ITEM_6 }
local BWC = GetItemSlot(myHero, 3144)
local BOTRK = GetItemSlot(myHero, 3153)
local YOUMUU = GetItemSlot(myHero, 3142)
local UseItems = function(target)
        BWC   = GetItemSlot(myHero, 3144)
        BOTRK = GetItemSlot(myHero, 3153)
        YOUMUU = GetItemSlot(myHero, 3142)
        if Menu.Items.BOTRK.Use:Value() and BOTRK and ValidTarget(target, 550) and GetPercentHP(myHero) <= Menu.Items.BOTRK.MyHP:Value() and GetPercentHP(target) <= Menu.Items.BOTRK.EnemyHP:Value() then
        	LocalCastSpell(KB[BOTRK], target)
        elseif Menu.Items.BWC.Use:Value() and BWC and ValidTarget(target, 550) then
        	LocalCastSpell(KB[BWC], target)
        elseif Menu.Items.YOUMUU.Use:Value() and YOUMUU and ValidTarget(target, myHero.range + target.boundingRadius) then 
        	LocalCastSpell(KB[YOUMUU], target)
        end
end

local LvLOrder = {
        [1] = { HK_Q, HK_E, HK_W, HK_Q, HK_Q, HK_R, HK_Q, HK_W, HK_Q, HK_W, HK_R, HK_W, HK_W, HK_E, HK_E, HK_R, HK_E, HK_E },
        [2] = { HK_Q, HK_W, HK_E, HK_Q, HK_Q, HK_R, HK_Q, HK_W, HK_Q, HK_W, HK_R, HK_W, HK_W, HK_E, HK_E, HK_R, HK_E, HK_E },
        [3] = { HK_Q, HK_W, HK_E, HK_Q, HK_Q, HK_R, HK_Q, HK_E, HK_Q, HK_E, HK_R, HK_E, HK_E, HK_W, HK_W, HK_R, HK_W, HK_W },
        [4] = { HK_W, HK_E, HK_Q, HK_W, HK_W, HK_R, HK_W, HK_Q, HK_W, HK_Q, HK_R, HK_Q, HK_Q, HK_E, HK_E, HK_R, HK_E, HK_E },
        [5] = { HK_W, HK_E, HK_Q, HK_W, HK_W, HK_R, HK_W, HK_E, HK_W, HK_E, HK_R, HK_E, HK_E, HK_Q, HK_Q, HK_R, HK_Q, HK_Q },
        [6] = { HK_E, HK_Q, HK_W, HK_E, HK_E, HK_R, HK_E, HK_W, HK_E, HK_W, HK_R, HK_W, HK_W, HK_Q, HK_Q, HK_R, HK_Q, HK_Q },
        [7] = { HK_E, HK_Q, HK_W, HK_E, HK_E, HK_R, HK_E, HK_Q, HK_E, HK_Q, HK_R, HK_Q, HK_Q, HK_W, HK_W, HK_R, HK_W, HK_W },
        [8] = { HK_E, HK_Q, HK_W, HK_E, HK_E, HK_R, HK_E, HK_W, HK_E, HK_W, HK_R, HK_W, HK_W, HK_Q, HK_Q, HK_R, HK_Q, HK_Q },
}
local LvLSlot = nil
local LvLTick = 0
local AutoLvLUp = function()
        local MyLvLPts = myHero.levelData.lvl - (myHero:GetSpellData(_Q).level + myHero:GetSpellData(_W).level + myHero:GetSpellData(_E).level + myHero:GetSpellData(_R).level)
        local MyLvL = myHero.levelData.lvl
        local Sec = LvLOrder[Menu.lvlup.Order:Value()][MyLvL - MyLvLPts + 1]

        if MyLvLPts > 0 then
        	if Menu.lvlup.flvl:Value() and MyLvL == 1 then return end
        	if LocalGetTickCount() - LvLTick > 800 and Sec ~= nil then
        		LocalControlKeyDown(HK_LUS)
        		LocalControlKeyDown(Sec)
        		LvLSlot = Sec
        		LvLTick = LocalGetTickCount()
        	end
        end
        if LocalControlIsKeyDown(HK_LUS) then
                LocalControlKeyUp(HK_LUS)
        end
        if LvLSlot and LocalControlIsKeyDown(LvLSlot) then
                LocalControlKeyUp(LvLSlot)
        end
end

local Tick = function()
        if Menu.lvlup.Use:Value() then
        	AutoLvLUp()
        end
        if Menu.WJ.Use:Value() and Menu.WJ.Key:Value() then
        	local p1 = myHero.pos:Extended(mousePos, 200)                 
        	local p2 = myHero.pos:Extended(mousePos, E.range)              
        	local p3 = myHero.pos:Extended(mousePos, myHero.boundingRadius)            
        	if MapPosition:inWall(p1) then                         
        		if not MapPosition:inWall(p2) and mousePos.y-myHero.pos.y < 225 then                                 
        			if E.IsReady() then
        			        LocalCastSpell(HK_E, p2) 
        			end                               
        			--Move(p2)      
                                _G.SDK.Orbwalker.ForceMovement = p2                   
        		else                                 
        			--Move(p3)  
                                _G.SDK.Orbwalker.ForceMovement = p3                     
        		end                 
        	else                         
        		_G.SDK.Orbwalker.ForceMovement = p1               
        	end     
        else
                _G.SDK.Orbwalker.ForceMovement = nil 
        end	
        if Mode() == "LastHit" and GetPercentMP(myHero) >= Menu.LastHit.Mana:Value() and Menu.LastHit.Q.Use:Value() and Q.IsReady() then
        	for i, minion in pairs(GetMinions()) do
        	        if minion and not minion.dead and GetDistance(myHero.pos, minion.pos) <= Q.range then
        		        local hppred = HealthPrediction(minion, Q2.delay)
        		        if Q.GetDamage(unit) >= hppred then
        			        LocalCastSpell(HK_Q, minion)
        		        end
        	        end
                end
        elseif Mode() == "LaneClear" and GetPercentMP(myHero) >= Menu.LaneClear.Mana:Value() and Menu.LaneClear.Q.Use:Value() and Q.IsReady() then
        	local pos, hit = GetBestLinearFarmPos(Q.range, Q2.width)
        	if pos and hit >= Menu.LaneClear.Q.MinionHit:Value() then
        		LocalCastSpell(HK_Q, pos)
        	end
        end
        local target = GetTarget(1500)
        if target == nil then return end
        if Mode() == "Combo" then  
                UseItems(target)    	
        	if Menu.Combo.Q.Use2:Value() then 
        		CastQ2(target) 
        	end 
        elseif Mode() == "Harass" and GetPercentMP(myHero) >= Menu.Harass.Mana:Value() and Menu.Harass.WhiteList[target.charName]:Value() then
        	if Menu.Harass.Q.Use:Value() and Q.IsReady() and ValidTarget(target, Q.range) then
        		CastQ(target)
        	end
        	if Menu.Harass.Q.Use2:Value() then 
        		CastQ2(target) 
        	end 
        	if Menu.Harass.W.Use:Value() and W.IsReady() and ValidTarget(target, W.range) then 
        		CastW(target, false) 
        	end 
        end
        if Menu.AutoHarass.UseExtQ:Value() and GetPercentMP(myHero) >= Menu.AutoHarass.Mana:Value() and Menu.AutoHarass.WhiteList[target.charName]:Value() then
        	CastQ2(target)
        end
end

local Drawings = function()
        if myHero.dead or Menu.Draw.Disable:Value() then return end
        if not inc then inc = 0 end 	
        inc = inc + 0.002 	
        if inc > 6.28318 then inc = 0 end 
        if Menu.WJ.Use:Value() and Menu.WJ.Key:Value() and Menu.Draw.WJPos:Value() then
        	local p1 = myHero.pos:Extended(mousePos, E.range)  
        	local p2 = myHero.pos:Extended(mousePos, myHero.boundingRadius)  
        	if MapPosition:inWall(p1) then 		       
        	        LocalDrawCircle(p1, LocalDrawColor(255, 255, 0, 0)) 	 
        	        DrawTriangle(p1, LocalDrawColor(255, 255, 0, 0), 2, 75, inc, 10, 0, 0)  
        	        DrawTriangle(p1, LocalDrawColor(255, 255, 0, 0), 2, 100, inc, 10, 0, 0)        	        
        	else 		        
        	        LocalDrawCircle(p1) 
        	        DrawTriangle(p1, LocalDrawColor(255, 255, 255, 255), 2, 75, inc, 10, 0, 0)
        	        DrawTriangle(p1, LocalDrawColor(255, 255, 255, 255), 2, 100, inc, 10, 0, 0)			        	        
        	end 
        end
        if Menu.Draw.Q.Range:Value() and Q.IsReady() then
                LocalDrawCircle(myHero.pos, Q.range, Menu.Draw.Q.Width:Value(), Menu.Draw.Q.Color:Value())
        end
        if Menu.Draw.W.Range:Value() and W.IsReady() then
                LocalDrawCircle(myHero.pos, W.range, Menu.Draw.W.Width:Value(), Menu.Draw.W.Color:Value())
        end
        if Menu.Draw.E.Range:Value() and E.IsReady() then
                LocalDrawCircle(myHero.pos, E.range, Menu.Draw.E.Width:Value(), Menu.Draw.E.Color:Value())
        end
        if Menu.Draw.R.Range:Value() and R.IsReady() then
                LocalDrawCircle(myHero.pos, R.range, Menu.Draw.R.Width:Value(), Menu.Draw.R.Color:Value())
        end
	local target = GetTarget(1500)
	if target == nil then return end
	if Menu.Draw.CurTarget:Value() then
	LocalDrawCircle(target.pos, LocalDrawColor(100, 255, 255, 0)) 	
        DrawTriangle(target.pos, LocalDrawColor(100, 255, 255, 0), 2, 75, inc, 10, 0, 0)  
        DrawTriangle(target.pos, LocalDrawColor(100, 255, 255, 0), 2, 100, inc, 10, 0, 0) 
        end
        if Menu.Draw.Q.Range2:Value() and Q.IsReady() and GetDistance(myHero.pos, target.pos) <= 1500 then  		
        	DrawRectangleOutline(myHero.pos, myHero.pos:Extended(target.pos, Q.range), Q2.width, Menu.Draw.Q.Color2:Value(), 50) 		
        	DrawRectangleOutline(myHero.pos, myHero.pos:Extended(target.pos, Q2.range), Q2.width, Menu.Draw.Q.Color2:Value(), 50) 	
        end 
end

local RangeLogicForE = function(target)
        local pred = target:GetPrediction(math.huge, 0.25)
        local range = GetDistance(pred) < myHero.range and 125 or 425
        return range
end

local AfterAttack = function()
        local target = GetTarget(1500)
        local ComboRotation = Menu.Combo.ComboRotation:Value() - 1
        local JungleRotation = Menu.JungleClear.JungleClearRotation:Value() - 1

	if Mode() == "Combo" then
		if ComboRotation == 3 then
	        	if Menu.Combo.W.Use:Value() and W.IsReady() and ValidTarget(target, W.range) then
		                CastW(target, Menu.Combo.W.UseFast:Value())
	                elseif Menu.Combo.E.Use:Value() and E.IsReady() and ValidTarget(target, E.range*2) then
		                CastE(target, Menu.Combo.E.Mode:Value(), RangeLogicForE(target)) --Menu.Combo.E.Range:Value()
	                elseif Menu.Combo.Q.Use:Value() and Q.IsReady() and ValidTarget(target, Q.range) then
		                CastQ(target)
	                end
	        end
		if Menu.Combo.Q.Use:Value() and (ComboRotation == 0 or LocalGameCanUseSpell(ComboRotation) ~= READY) and Q.IsReady() and ValidTarget(target, Q.range) then
		        CastQ(target)
	        elseif Menu.Combo.E.Use:Value() and (ComboRotation == 2 or LocalGameCanUseSpell(ComboRotation) ~= READY) and E.IsReady() and ValidTarget(target, E.range*2) then
		        CastE(target, Menu.Combo.E.Mode:Value(), RangeLogicForE(target)) --Menu.Combo.E.Range:Value()
	        elseif Menu.Combo.W.Use:Value() and (ComboRotation == 1 or LocalGameCanUseSpell(ComboRotation) ~= READY) and W.IsReady() and ValidTarget(target, W.range) then
		        CastW(target, Menu.Combo.W.UseFast:Value())
	        end
        elseif Mode() == "LaneClear" and GetPercentMP(myHero) >= Menu.JungleClear.Mana:Value() then
        	for i, jminion in pairs(GetJungleMinions()) do
        		if Menu.JungleClear.Q.Use:Value() and (JungleRotation == 0 or LocalGameCanUseSpell(JungleRotation) ~= READY) and Q.IsReady() and ValidTarget(jminion, Q.range) then
		                CastQ(jminion)
	                elseif Menu.JungleClear.E.Use:Value() and (JungleRotation == 2 or LocalGameCanUseSpell(JungleRotation) ~= READY) and E.IsReady() and ValidTarget(jminion, E.range*2) then
		                CastE(jminion, Menu.JungleClear.E.Mode:Value(), Menu.JungleClear.E.Range:Value())
	                elseif Menu.JungleClear.W.Use:Value() and (JungleRotation == 1 or LocalGameCanUseSpell(JungleRotation) ~= READY) and W.IsReady() and ValidTarget(jminion, W.range) then
		                CastW(jminion, true)
	                end
        	end
        end
end

local CurrentOrbName = function()
        local orb
        if _G.SDK then
        	orb = "IC's Orbwalker"
        else
        	orb = "Orbwalker Not Found, Enable IC's Orbwalker"
        end
        return orb
end

local Load = function()   
        require("MapPositionGOS")

        Menu = MenuElement({type = MENU, name = "PROJECT | Lucian",  id = "Lucian", leftIcon = "http://vignette2.wikia.nocookie.net/leagueoflegends/images/b/b9/Lucian_PROJECT_Trace_3.png"})
        Menu:MenuElement({name = " ", drop = {"General Features"}})
        Menu:MenuElement({type = MENU, name = "Combo",  id = "Combo"})
        Menu.Combo:MenuElement({type = MENU, name = "[Q] Piercing Light",  id = "Q"})
        Menu.Combo.Q:MenuElement({name = "Use Q In Combo", id = "Use", value = true})
        Menu.Combo.Q:MenuElement({name = "Use Extended Q In Combo", id = "Use2", value = true})
        Menu.Combo:MenuElement({type = MENU, name = "[W] Ardent Blaze",  id = "W"})
        Menu.Combo.W:MenuElement({name = "Use W In Combo", id = "Use", value = true})
        Menu.Combo.W:MenuElement({name = "Use Fast W In Combo", id = "UseFast", value = true})
        Menu.Combo:MenuElement({type = MENU, name = "[E] Relentless Pursuit",  id = "E"})
        Menu.Combo.E:MenuElement({name = "Use E In Combo", id = "Use", value = true})
        Menu.Combo.E:MenuElement({name = "E Mode", id = "Mode", value = 1, drop = {"Side", "Mouse", "Target"}})
        ----Menu.Combo.E:MenuElement({name = "E Dash Range", id = "Range", value = 125, min = 100, max = 425, step = 5})
        Menu.Combo:MenuElement({name = "Combo Rotation Priority",  id = "ComboRotation", value = 3, drop = {"Q", "W", "E", "EW"}})

        Menu:MenuElement({type = MENU, name = "Harass",  id = "Harass"})
        Menu.Harass:MenuElement({type = MENU, name = "[Q] Piercing Light",  id = "Q"})
        Menu.Harass.Q:MenuElement({name = "Harass With Q", id = "Use", value = true})
        Menu.Harass.Q:MenuElement({name = "Harass With Extended Q", id = "Use2", value = true})
        Menu.Harass:MenuElement({type = MENU, name = "[W] Ardent Blaze",  id = "W"})
        Menu.Harass.W:MenuElement({name = "Harass With W", id = "Use", value = true})
        Menu.Harass:MenuElement({type = MENU, name = "White List",  id = "WhiteList"})
        for i, Enemy in pairs(GetEnemyHeroes()) do
        	Menu.Harass.WhiteList:MenuElement({name = Enemy.charName,  id = Enemy.charName, value = true})
        end
        Menu.Harass:MenuElement({name = "Mana Manager(%)", id = "Mana", value = 50, min = 1, max = 100, step = 1})

        Menu:MenuElement({type = MENU, name = "Last Hit",  id = "LastHit"})
        Menu.LastHit:MenuElement({type = MENU, name = "[Q] Piercing Light",  id = "Q"})
        Menu.LastHit.Q:MenuElement({name = "Last Hit With Q", id = "Use", value = true})
        Menu.LastHit:MenuElement({name = "Mana Manager(%)", id = "Mana", value = 50, min = 1, max = 100, step = 1})

        Menu:MenuElement({type = MENU, name = "Lane Clear",  id = "LaneClear"})
        Menu.LaneClear:MenuElement({type = MENU, name = "[Q] Piercing Light",  id = "Q"})
        Menu.LaneClear.Q:MenuElement({name = "Lane Clear With Q", id = "Use", value = true})
        Menu.LaneClear.Q:MenuElement({name = "Minion Hit", id = "MinionHit", value = 3, min = 1, max = 6, step = 1})
        Menu.LaneClear:MenuElement({name = "Mana Manager(%)", id = "Mana", value = 50, min = 1, max = 100, step = 1})

        Menu:MenuElement({type = MENU, name = "Jungle Clear",  id = "JungleClear"})
        Menu.JungleClear:MenuElement({type = MENU, name = "[Q] Piercing Light",  id = "Q"})
        Menu.JungleClear.Q:MenuElement({name = "Use Q In JungleClear", id = "Use", value = true})
        Menu.JungleClear:MenuElement({type = MENU, name = "[W] Ardent Blaze",  id = "W"})
        Menu.JungleClear.W:MenuElement({name = "Use W In JungleClear", id = "Use", value = true})
        Menu.JungleClear:MenuElement({type = MENU, name = "[E] Relentless Pursuit",  id = "E"})
        Menu.JungleClear.E:MenuElement({name = "Use E In JungleClear", id = "Use", value = true})
        Menu.JungleClear.E:MenuElement({name = "E Mode", id = "Mode", value = 1, drop = {"Side", "Mouse", "Target"}})
        Menu.JungleClear.E:MenuElement({name = "E Dash Range", id = "Range", value = 125, min = 100, max = 425, step = 5})
        Menu.JungleClear:MenuElement({name = "JungleClear Rotation Priority",  id = "JungleClearRotation", value = 3, drop = {"Q", "W", "E"}})
        Menu.JungleClear:MenuElement({name = "Mana Manager(%)", id = "Mana", value = 50, min = 1, max = 100, step = 1})

        Menu:MenuElement({name = " ", drop = {"Advanced Features"}})

        Menu:MenuElement({type = MENU, name = "Auto Harass",  id = "AutoHarass"})
        Menu.AutoHarass:MenuElement({name = "Auto Harass With Extended Q", id = "UseExtQ", value = true})
        Menu.AutoHarass:MenuElement({type = MENU, name = "White List",  id = "WhiteList"})
        for i, Enemy in pairs(GetEnemyHeroes()) do
        	Menu.AutoHarass.WhiteList:MenuElement({name = Enemy.charName,  id = Enemy.charName, value = true})
        end
        Menu.AutoHarass:MenuElement({name = "Mana Manager(%)", id = "Mana", value = 50, min = 1, max = 100, step = 1})

        Menu:MenuElement({type = MENU, name = "Auto Level Up",  id = "lvlup"})
        Menu.lvlup:MenuElement({name = "Use Auto Level Up", id = "Use", value = true})
        Menu.lvlup:MenuElement({name = "Don't Use At 1 Lvl", id = "flvl", value = true})
        Menu.lvlup:MenuElement({name = "Sequence Order", id = "Order", drop = {"Recomended for Lucian", "Q > W > E", "Q > E > W","W > Q > E","W > E > Q","E > W > Q", "E > Q > W"}})

        Menu:MenuElement({type = MENU, name = "Activator",  id = "Items"})
        Menu.Items:MenuElement({type = MENU, name = "Bilgewater Cutlass",  id = "BWC"})
        Menu.Items.BWC:MenuElement({name = "Use In Combo",  id = "Use", value = true})
        Menu.Items:MenuElement({type = MENU, name = "Blade of the Ruined King",  id = "BOTRK"})
        Menu.Items.BOTRK:MenuElement({name = "Use In Combo",  id = "Use", value = true})
        Menu.Items.BOTRK:MenuElement({name = "My HP(%)",  id = "MyHP", value = 100, min = 1, max = 100, step = 1})
        Menu.Items.BOTRK:MenuElement({name = "Enemy HP(%)",  id = "EnemyHP", value = 50, min = 1, max = 100, step = 1})
        Menu.Items:MenuElement({type = MENU, name = "Youmuu's Ghostblade",  id = "YOUMUU"})
        Menu.Items.YOUMUU:MenuElement({name = "Use In Combo",  id = "Use", value = true})

        Menu:MenuElement({type = MENU, name = "Walljump",  id = "WJ"})
        Menu.WJ:MenuElement({name = "Use Walljump ",  id = "Use", value = true})
        Menu.WJ:MenuElement({name = "Walljump Key ",  id = "Key", key = string.byte("G"), toggle = false})
  
        Menu:MenuElement({type = MENU, name = "Drawings",  id = "Draw"})
        Menu.Draw:MenuElement({name = "Disable All Drawings", id = "Disable", value = false})
        Menu.Draw:MenuElement({type = MENU, name = "[Q] Piercing Light",  id = "Q"})
        Menu.Draw.Q:MenuElement({name = "Draw Q Range",  id = "Range", value = true})
        Menu.Draw.Q:MenuElement({name = "Q Color",  id = "Color", color = LocalDrawColor(255,255,255,255)})
        Menu.Draw.Q:MenuElement({name = "Q Width",  id = "Width", value = 2, min = 1, max = 10, step = 1})
        Menu.Draw.Q:MenuElement({name = "Draw Q Rectangle",  id = "Range2", value = true})
        Menu.Draw.Q:MenuElement({name = "Q Rectangle Color",  id = "Color2", color = LocalDrawColor(255,255,255,255)})
        Menu.Draw:MenuElement({type = MENU, name = "[W] Ardent Blaze",  id = "W"})
        Menu.Draw.W:MenuElement({name = "Draw W Range",  id = "Range", value = true})
        Menu.Draw.W:MenuElement({name = "W Color",  id = "Color", color = LocalDrawColor(255,255,255,255)})
        Menu.Draw.W:MenuElement({name = "W Width",  id = "Width", value = 2, min = 1, max = 10, step = 1})
        Menu.Draw:MenuElement({type = MENU, name = "[E] Relentless Pursuit",  id = "E"})
        Menu.Draw.E:MenuElement({name = "Draw E Range",  id = "Range", value = true})
        Menu.Draw.E:MenuElement({name = "E Color",  id = "Color", color = LocalDrawColor(255,255,255,255)})
        Menu.Draw.E:MenuElement({name = "E Width",  id = "Width", value = 2, min = 1, max = 10, step = 1})
        Menu.Draw:MenuElement({type = MENU, name = "[R] The Culling",  id = "R"})
        Menu.Draw.R:MenuElement({name = "Draw R Range",  id = "Range", value = true})
        Menu.Draw.R:MenuElement({name = "R Color",  id = "Color", color = LocalDrawColor(255,255,255,255)})
        Menu.Draw.R:MenuElement({name = "R Width",  id = "Width", value = 2, min = 1, max = 10, step = 1})
        Menu.Draw:MenuElement({name = "Draw Current Target", id = "CurTarget", value = true})
        Menu.Draw:MenuElement({name = "Draw Walljump Position", id = "WJPos", value = true})

        Menu:MenuElement({name = " ", drop = {"Script Info"}})
        Menu:MenuElement({name = "Script Version", drop = {"1.1"}})
        Menu:MenuElement({name = "League Version", drop = {"7.16"}})
        Menu:MenuElement({name = "Author", drop = {"Shulepin"}})

        Q    = { range = 650                                                                                                }         
        Q2   = { range = 900 , delay = 0.35, speed = math.huge, width = 25, collision = false, aoe = false, type = "linear" }         
        W    = { range = 1000, delay = 0.30, speed = 1600     , width = 80, collision = true , aoe = true , type = "linear" }         
        E    = { range = 425                                                                                                }         
        R    = { range = 1200, delay = 0.10, speed = 2500     , width = 110                                                 }       

        Q.IsReady = function() return LocalGameCanUseSpell(_Q) == READY end         
        W.IsReady = function() return LocalGameCanUseSpell(_W) == READY end         
        E.IsReady = function() return LocalGameCanUseSpell(_E) == READY end         
        R.IsReady = function() return LocalGameCanUseSpell(_R) == READY end  

        Q.GetDamage = function(unit) return 45 + 35 * myHero:GetSpellData(_Q).level + myHero.bonusDamage * ((50 + 10 * myHero:GetSpellData(_Q).level)/100) end        

        LocalCallbackAdd("Tick", function() Tick() end)         
        LocalCallbackAdd("Draw", function() Drawings() end)
        _G.SDK.Orbwalker:OnPostAttack(function() AfterAttack() end) 

        print("Shulepin's Lucian Loaded | Current orbwalker: "..CurrentOrbName())         
end 

function OnLoad() Load() end
