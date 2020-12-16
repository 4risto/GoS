if myHero.charName == "Ashe" or myHero.charName == "Ezreal" or myHero.charName == "Lucian" or myHero.charName == "Caitlyn" or myHero.charName == "Twitch" or myHero.charName == "KogMaw" or myHero.charName == "Kalista" or myHero.charName == "Corki" or myHero.charName == "Xayah" or myHero.charName == "Senna" then
	local TRUStinMyMarksmanloaded = false
	require "2DGeometry"
	require "PremiumPrediction"
	castSpell = {state = 0, tick = GetTickCount(), casting = GetTickCount() - 1000, mouse = mousePos}
	function SetMovement(bool)
		if _G.EOWLoaded then
			EOW:SetMovements(bool)
			EOW:SetAttacks(bool)
		elseif _G.SDK then
			_G.SDK.Orbwalker:SetMovement(bool)
			_G.SDK.Orbwalker:SetAttack(bool)
		else
			GOS.BlockMovement = not bool
			GOS.BlockAttack = not bool
		end
		if bool then
			castSpell.state = 0
		end
	end
	
	function CurrentModes()
		local combomodeactive, harassactive, canmove, canattack, currenttarget
		if _G.SDK then -- ic orbwalker
			combomodeactive = _G.SDK.Orbwalker.Modes[_G.SDK.ORBWALKER_MODE_COMBO]
			harassactive = _G.SDK.Orbwalker.Modes[_G.SDK.ORBWALKER_MODE_HARASS]
			canmove = _G.SDK.Orbwalker:CanMove()
			canattack = _G.SDK.Orbwalker:CanAttack()
			currenttarget = _G.SDK.TargetSelector.SelectedTarget or _G.SDK.Orbwalker:GetTarget()
		elseif _G.EOW then -- eternal orbwalker
			combomodeactive = _G.EOW:Mode() == 1
			harassactive = _G.EOW:Mode() == 2
			canmove = _G.EOW:CanMove() 
			canattack = _G.EOW:CanAttack()
			currenttarget = _G.EOW:GetTarget()
		else -- default orbwalker
			combomodeactive = _G.GOS:GetMode() == "Combo"
			harassactive = _G.GOS:GetMode() == "Harass"
			canmove = _G.GOS:CanMove()
			canattack = _G.GOS:CanAttack()
			currenttarget = _G.GOS:GetTarget()
		end
		return combomodeactive, harassactive, canmove, canattack, currenttarget
	end
	
	function GetInventorySlotItem(itemID)
		assert(type(itemID) == "number", "GetInventorySlotItem: wrong argument types (<number> expected)")
		for _, j in pairs({ ITEM_1, ITEM_2, ITEM_3, ITEM_4, ITEM_5, ITEM_6}) do
			if myHero:GetItemData(j).itemID == itemID and myHero:GetSpellData(j).currentCd == 0 then return j end
		end
		return nil
	end
	
	function UseBotrk()
		local target = (_G.SDK and _G.SDK.TargetSelector:GetTarget(300, _G.SDK.DAMAGE_TYPE_PHYSICAL)) or (_G.GOS and _G.GOS:GetTarget(300,"AD"))
		if target then 
			local botrkitem = GetInventorySlotItem(3153) or GetInventorySlotItem(3144)
			if botrkitem then
				local keybindings = { [ITEM_1] = HK_ITEM_1, [ITEM_2] = HK_ITEM_2, [ITEM_3] = HK_ITEM_3, [ITEM_4] = HK_ITEM_4, [ITEM_5] = HK_ITEM_5, [ITEM_6] = HK_ITEM_6}
				Control.CastSpell(keybindings[botrkitem],target.pos)
			end
		end
	end
end

if myHero.charName == "Ashe" then
	local Ashe = {}
	Ashe.__index = Ashe
	local Scriptname,Version,Author,LVersion = "TRUSt in my Ashe","v1.7","TRUS","10.3"
	function Ashe:GetBuffs(unit)
		self.T = {}
		for i = 0, unit.buffCount do
			local Buff = unit:GetBuff(i)
			if Buff.count > 0 then
				table.insert(self.T, Buff)
			end
		end
		return self.T
	end
	
	function Ashe:QBuff(buffname)
		for K, Buff in pairs(self:GetBuffs(myHero)) do
			if Buff.name:lower() == "asheqcastready" then
				return true
			end
		end
		return false
	end
	
	function Ashe:__init()
		if not TRUStinMyMarksmanloaded then TRUStinMyMarksmanloaded = true else return end
		self:LoadSpells()
		self:LoadMenu()
		Callback.Add("Tick", function() self:Tick() end)
		
		local orbwalkername = ""
		if _G.SDK then
			orbwalkername = "IC'S orbwalker"	
			_G.SDK.Orbwalker:OnPostAttack(function() 
				local combomodeactive = (_G.SDK.Orbwalker.Modes[_G.SDK.ORBWALKER_MODE_COMBO])
				local currenttarget = _G.SDK.Orbwalker:GetTarget()
				if (combomodeactive) and self.Menu.UseQCombo:Value() and self:QBuff() then
					self:CastQ()
				end
			end)
		elseif _G.EOW then
			orbwalkername = "EOW"	
			_G.EOW:AddCallback(_G.EOW.AfterAttack, function() 
				local combomodeactive = _G.EOW:Mode() == 1
				local currenttarget = _G.EOW:GetTarget()
				if (combomodeactive) and self.Menu.UseQCombo:Value() and self:QBuff() then
					self:CastQ()
				end
			end)
		elseif _G.GOS then
			orbwalkername = "Noddy orbwalker"
			
			_G.GOS:OnAttackComplete(function() 
				local combomodeactive = _G.GOS:GetMode() == "Combo"
				local currenttarget = _G.GOS:GetTarget()
				if (combomodeactive) and currenttarget and self.Menu.UseQCombo:Value() and self:QBuff() and currenttarget then
					self:CastQ()
				end
			end)
			
		else
			orbwalkername = "Orbwalker not found"
			
		end
		PrintChat(Scriptname.." "..Version.." - Loaded...."..orbwalkername)
	end
	
	--[[Spells]]
	function Ashe:LoadSpells()
		W = {Range = 1200, width = nil, Delay = 0.25, Radius = 30, Speed = 900}
	end
	
	
	function GetConeAOECastPosition(unit, delay, angle, range, speed, from)
		range = range and range - 4 or 20000
		radius = 1
		from = from and Vector(from) or Vector(myHero.pos)
		angle = angle * math.pi / 180
		
		local CastPosition = unit:GetPrediction(speed,delay)
		local points = {}
		local mainCastPosition = CastPosition
		
		table.insert(points, Vector(CastPosition) - Vector(from))
		
		local function CountVectorsBetween(V1, V2, points)
			local result = 0	
			local hitpoints = {} 
			for i, test in ipairs(points) do
				local NVector = Vector(V1):CrossP(test)
				local NVector2 = Vector(test):CrossP(V2)
				if NVector.y >= 0 and NVector2.y >= 0 then
					result = result + 1
					table.insert(hitpoints, test)
				elseif i == 1 then
					return -1 --doesnt hit the main target
				end
			end
			return result, hitpoints
		end
		
		local function CheckHit(position, angle, points)
			local direction = Vector(position):Normalized()
			local v1 = position:Rotated(0, -angle / 2, 0)
			local v2 = position:Rotated(0, angle / 2, 0)
			return CountVectorsBetween(v1, v2, points)
		end
		local enemyheroestable = (_G.SDK and _G.SDK.ObjectManager:GetEnemyHeroes(range)) or (_G.GOS and _G.GOS:GetEnemyHeroes())
		for i, target in ipairs(enemyheroestable) do
			if target.networkID ~= unit.networkID and myHero.pos:DistanceTo(target.pos) < range then
				CastPosition = target:GetPrediction(speed,delay)
				if from:DistanceTo(CastPosition) < range then
					table.insert(points, Vector(CastPosition) - Vector(from))
				end
			end
		end
		
		local MaxHitPos
		local MaxHit = 1
		local MaxHitPoints = {}
		
		if #points > 1 then
			
			for i, point in ipairs(points) do
				local pos1 = Vector(point):Rotated(0, angle / 2, 0)
				local pos2 = Vector(point):Rotated(0, - angle / 2, 0)
				
				local hits, points1 = CountVectorsBetween(pos1, pos2, points)
				--
				if hits >= MaxHit then
					
					MaxHitPos = C1
					MaxHit = hits
					MaxHitPoints = points1
				end
				
			end
		end
		
		if MaxHit > 1 then
			--Center the cone
			local maxangle = -1
			local p1
			local p2
			for i, hitp in ipairs(MaxHitPoints) do
				for o, hitp2 in ipairs(MaxHitPoints) do
					local cangle = Vector():AngleBetween(hitp2, hitp) 
					if cangle > maxangle then
						maxangle = cangle
						p1 = hitp
						p2 = hitp2
					end
				end
			end
			
			
			return Vector(from) + range * (((p1 + p2) / 2)):Normalized(), MaxHit
		else
			return unit.pos, 1
		end
	end
	
	
	
	function Ashe:LoadMenu()
		self.Menu = MenuElement({type = MENU, id = "TRUStinymyAshe", name = Scriptname})
		self.Menu:MenuElement({id = "UseWCombo", name = "UseW in combo", value = true})
		self.Menu:MenuElement({id = "UseQCombo", name = "UseQ in combo", value = true})
		self.Menu:MenuElement({id = "UseQAfterAA", name = "UseQ only afterattack", value = true})
		self.Menu:MenuElement({id = "UseWHarass", name = "UseW in Harass", value = true})
		self.Menu:MenuElement({id = "UseBOTRK", name = "Use botrk", value = true})
		self.Menu:MenuElement({id = "CustomSpellCast", name = "Use custom spellcast", tooltip = "Can fix some casting problems with wrong directions and so (thx Noddy for this one)", value = true})
		self.Menu:MenuElement({id = "delay", name = "Custom spellcast delay", value = 50, min = 0, max = 200, step = 5, identifier = ""})
		
		self.Menu:MenuElement({id = "blank", type = SPACE , name = ""})
		self.Menu:MenuElement({id = "blank", type = SPACE , name = "Script Ver: "..Version.. " - LoL Ver: "..LVersion.. "" .. (_G.PremiumPrediction:Loaded() and " PremiumPr" or "")})
		self.Menu:MenuElement({id = "blank", type = SPACE , name = "by "..Author.. ""})
	end
	
	function Ashe:Tick()
		if myHero.dead or (not _G.SDK and not _G.GOS) then return end
		
		if myHero.activeSpell and myHero.activeSpell.valid and myHero.activeSpell.name == "Volley" then 
			if castSpell.state == 1 then
				ReturnCursor(castSpell.mouse)
			end
		end
		local combomodeactive, harassactive, canmove, canattack, currenttarget = CurrentModes()
		if combomodeactive and self.Menu.UseBOTRK:Value() then
			UseBotrk()
		end
		
		if combomodeactive and self.Menu.UseWCombo:Value() and canmove and not canattack then
			self:CastW(currenttarget)
		end
		if combomodeactive and self:QBuff() and self.Menu.UseQCombo:Value() and (not self.Menu.UseQAfterAA:Value()) and currenttarget and canmove and not canattack then
			self:CastQ()
		end
		if harassactive and self.Menu.UseWHarass:Value() and ((canmove and not canattack) or not currenttarget) then
			self:CastW(currenttarget)
		end
	end
	
	function ReturnCursor(pos)
		Control.SetCursorPos(pos)
		SetMovement(true)
	end
	
	function LeftClick(pos)
		Control.mouse_event(MOUSEEVENTF_LEFTDOWN)
		Control.mouse_event(MOUSEEVENTF_LEFTUP)
		DelayAction(ReturnCursor,0.05,{pos})
	end
	
	function Ashe:CastSpell(spell,pos)
		local customcast = self.Menu.CustomSpellCast:Value()
		if not customcast then
			Control.CastSpell(spell, pos)
			return
		else
			local delay = self.Menu.delay:Value()
			local ticker = GetTickCount()
			if castSpell.state == 0 and ticker > castSpell.casting then
				castSpell.state = 1
				castSpell.mouse = mousePos
				castSpell.tick = ticker
				if ticker - castSpell.tick < Game.Latency() then
					--block movement
					SetMovement(false)
					Control.SetCursorPos(pos)
					Control.KeyDown(spell)
					Control.KeyUp(spell)
					DelayAction(LeftClick,delay/1000,{castSpell.mouse})
					castSpell.casting = ticker + 500
				end
			end
		end
	end
	
	
	function Ashe:CastQ()
		if self:CanCast(_Q) then
			Control.CastSpell(HK_Q)
		end
	end
	
	
	function Ashe:CastW(target)
		local target = target or (_G.SDK and _G.SDK.TargetSelector:GetTarget(W.Range, _G.SDK.DAMAGE_TYPE_PHYSICAL)) or (_G.GOS and _G.GOS:GetTarget(W.Range,"AD"))
		if target and self:CanCast(_W) and target:GetCollision(W.Radius,W.Speed,W.Delay) == 0 then
			local getposition = self:GetWPos(target)
			if getposition then
				self:CastSpell(HK_W,getposition)
			end
		end
	end
	
	
	function Ashe:GetWPos(unit)
		if unit then
			local temppos = GetConeAOECastPosition(unit, W.Delay, 45, W.Range, W.Speed)
			if temppos then 
				return temppos
			end
		end
		
		return false
	end
	
	function Ashe:IsReady(spellSlot)
		return myHero:GetSpellData(spellSlot).currentCd == 0 and myHero:GetSpellData(spellSlot).level > 0
	end
	
	function Ashe:CheckMana(spellSlot)
		return myHero:GetSpellData(spellSlot).mana < myHero.mana
	end
	
	function Ashe:CanCast(spellSlot)
		return self:IsReady(spellSlot) and self:CheckMana(spellSlot)
	end
	
	function OnLoad()
		Ashe:__init()
	end
end

if myHero.charName == "Lucian" then
	local Lucian = {}
	Lucian.__index = Lucian
	local Scriptname,Version,Author,LVersion = "TRUSt in my Lucian","v1.6","TRUS","10.3"
	local passive = true
	local lastbuff = 0
	function Lucian:__init()
		if not TRUStinMyMarksmanloaded then TRUStinMyMarksmanloaded = true else return end
		self:LoadSpells()
		self:LoadMenu()
		Callback.Add("Tick", function() self:Tick() end)
		
		local orbwalkername = ""
		if _G.SDK then
			orbwalkername = "IC'S orbwalker"		
			_G.SDK.Orbwalker:OnPostAttack(function() 
				passive = false 
				--PrintChat("passive removed")
				local combomodeactive = _G.SDK.Orbwalker.Modes[_G.SDK.ORBWALKER_MODE_COMBO]
				if combomodeactive and _G.SDK.Orbwalker:CanMove() and Game.Timer() > lastbuff - 3.5 then 
					if self:CanCast(_E) and self.Menu.UseE:Value() and _G.SDK.Orbwalker:GetTarget() then
						self:CastSpell(HK_E,mousePos)
						return
					end
				end
			end)
		elseif _G.EOW then
			orbwalkername = "EOW"	
			_G.EOW:AddCallback(_G.EOW.AfterAttack, function() 
				passive = false 
				local combomodeactive = _G.EOW:Mode() == 1
				local canmove = _G.EOW:CanMove()
				if combomodeactive and canmove and Game.Timer() > lastbuff - 3.5 then 
					if self:CanCast(_E) and self.Menu.UseE:Value() and _G.EOW:GetTarget() then
						self:CastSpell(HK_E,mousePos)
						return
					end
				end
			end)
		elseif _G.GOS then
			orbwalkername = "Noddy orbwalker"
			_G.GOS:OnAttackComplete(function() 
				passive = false 
				local combomodeactive = _G.GOS:GetMode() == "Combo"
				local canmove = _G.GOS:CanMove()
				if combomodeactive and canmove and Game.Timer() > lastbuff - 3.5 then 
					if self:CanCast(_E) and self.Menu.UseE:Value() and _G.GOS:GetTarget() then
						self:CastSpell(HK_E,mousePos)
						return
					end
				end
			end)
			
			
		else
			orbwalkername = "Orbwalker not found"
			
		end
		PrintChat(Scriptname.." "..Version.." - Loaded...."..orbwalkername)
	end
	
	--[[Spells]]
	function Lucian:LoadSpells()
		Q = {Range = 1190, width = nil, Delay = 0.25, Radius = 60, Speed = 2000, Collision = false, aoe = false, type = "linear"}
	end
	
	
	
	function Lucian:LoadMenu()
		self.Menu = MenuElement({type = MENU, id = "TRUStinymyLucian", name = Scriptname})
		self.Menu:MenuElement({id = "UseQ", name = "UseQ", value = true})
		self.Menu:MenuElement({id = "UseW", name = "UseW", value = true})
		self.Menu:MenuElement({id = "UseE", name = "UseE", value = true})
		self.Menu:MenuElement({id = "UseBOTRK", name = "Use botrk", value = true})
		self.Menu:MenuElement({id = "UseQHarass", name = "Harass with Q", value = true})
		self.Menu:MenuElement({id = "CustomSpellCast", name = "Use custom spellcast", tooltip = "Can fix some casting problems with wrong directions and so (thx Noddy for this one)", value = true})
		self.Menu:MenuElement({id = "delay", name = "Custom spellcast delay", value = 50, min = 0, max = 200, step = 5, identifier = ""})
		
		self.Menu:MenuElement({id = "blank", type = SPACE , name = ""})
		self.Menu:MenuElement({id = "blank", type = SPACE , name = "Script Ver: "..Version.. " - LoL Ver: "..LVersion.. "" .. (_G.PremiumPrediction:Loaded() and " PremiumPr" or "")})
		self.Menu:MenuElement({id = "blank", type = SPACE , name = "by "..Author.. ""})
	end
	
	function Lucian:GetBuffs(unit)
		self.T = {}
		for i = 0, unit.buffCount do
			local Buff = unit:GetBuff(i)
			if Buff.count > 0 then
				table.insert(self.T, Buff)
			end
		end
		return self.T
	end
	
	function Lucian:HasBuff(unit, buffname)
		for K, Buff in pairs(self:GetBuffs(unit)) do
			if Buff.name:lower() == buffname:lower() then
				return Buff.expireTime
			end
		end
		return false
	end
	
	function Lucian:Tick()
		if myHero.dead or (not _G.SDK and not _G.GOS) then return end
		local buffcheck = self:HasBuff(myHero,"lucianpassivebuff")
		if buffcheck and buffcheck ~= lastbuff then
			lastbuff = buffcheck
			--PrintChat("Passive added : "..Game.Timer().." : "..lastbuff)
			passive = true
		end
		local combomodeactive, harassactive, canmove, canattack, currenttarget = CurrentModes()
		if combomodeactive and self.Menu.UseBOTRK:Value() then
			UseBotrk()
		end
		if harassactive and self.Menu.UseQHarass:Value() and self:CanCast(_Q) then self:Harass() end 
		if not (myHero.activeSpell and myHero.activeSpell.valid and 
		(myHero.activeSpell.name == "LucianQ" or myHero.activeSpell.name == "LucianW")) then
			if combomodeactive and canmove and not canattack and Game.Timer() > lastbuff - 3 then 
				if self:CanCast(_E) and self.Menu.UseE:Value() and currenttarget then
					self:CastSpell(HK_E,mousePos)
					return
				end
				if self:CanCast(_Q) and self.Menu.UseQ:Value() and currenttarget then
					self:CastQ(currenttarget)
					return
				end
				if self:CanCast(_W) and self.Menu.UseW:Value() and currenttarget then
					self:CastW(currenttarget)
					return
				end
			end
			
		end
		
		if myHero.activeSpell and myHero.activeSpell.valid and 
		(myHero.activeSpell.name == "LucianQ" or myHero.activeSpell.name == "LucianW") and passive ~= myHero.activeSpell.endTime then
			passive = myHero.activeSpell.endTime
			--PrintChat("found passive1")
		end
		
		
	end
	
	function EnableMovement()
		--unblock movement
		SetMovement(true)
	end
	
	function ReturnCursor(pos)
		Control.SetCursorPos(pos)
		DelayAction(EnableMovement,0.1)
	end
	
	function LeftClick(pos)
		Control.mouse_event(MOUSEEVENTF_LEFTDOWN)
		Control.mouse_event(MOUSEEVENTF_LEFTUP)
		DelayAction(ReturnCursor,0.05,{pos})
	end
	
	function Lucian:CastSpell(spell,pos)
		local customcast = self.Menu.CustomSpellCast:Value()
		if not customcast then
			Control.CastSpell(spell, pos)
			return
		else
			local delay = self.Menu.delay:Value()
			local ticker = GetTickCount()
			if castSpell.state == 0 and ticker > castSpell.casting then
				castSpell.state = 1
				castSpell.mouse = mousePos
				castSpell.tick = ticker
				if ticker - castSpell.tick < Game.Latency() then
					--block movement
					SetMovement(false)
					Control.SetCursorPos(pos)
					Control.KeyDown(spell)
					Control.KeyUp(spell)
					DelayAction(LeftClick,delay/1000,{castSpell.mouse})
					castSpell.casting = ticker + 500
				end
			end
		end
	end
	
	
	--[[CastQ]]
	function Lucian:CastQ(target)
		if target and self:CanCast(_Q) and passive == false then
			self:CastSpell(HK_Q, target.pos)
		end
	end
	
	--[[CastQ]]
	function Lucian:CastW(target)
		if target and self:CanCast(_W) and passive == false then
			self:CastSpell(HK_W, target.pos)
		end
	end
	
	
	function Lucian:IsReady(spellSlot)
		return myHero:GetSpellData(spellSlot).currentCd == 0 and myHero:GetSpellData(spellSlot).level > 0
	end
	
	function Lucian:CheckMana(spellSlot)
		return myHero:GetSpellData(spellSlot).mana < myHero.mana
	end
	
	function Lucian:CanCast(spellSlot)
		return self:IsReady(spellSlot) and self:CheckMana(spellSlot)
	end
	
	
	
	function Lucian:Harass()
		local temptarget = self:FarQTarget()
		if temptarget then
			self:CastSpell(HK_Q,temptarget.pos)
		end
	end
	
	
	
	
	function Lucian:FarQTarget()
		local qtarget = (_G.SDK and _G.SDK.TargetSelector:GetTarget(900, _G.SDK.DAMAGE_TYPE_PHYSICAL)) or (_G.GOS and _G.GOS:GetTarget(900,"AD"))
		if qtarget then
			
			if myHero.pos:DistanceTo(qtarget.pos)<500 then
				return qtarget
			end
			
			
			local qdelay = 0.4 - myHero.levelData.lvl*0.01
			local pos
			
			if (_G.PremiumPrediction:Loaded()) then
				pos = _G.PremiumPrediction:GetPositionAfterTime(qtarget, qdelay)
			else 
				pos = qtarget:GetPrediction(math.huge,qdelay)
			end
			
			if not pos then return false end 
			local minionlist = {}
			if _G.SDK then
				minionlist = _G.SDK.ObjectManager:GetEnemyMinions(500)
			elseif _G.GOS then
				for i = 1, Game.MinionCount() do
					local minion = Game.Minion(i)
					if minion.valid and minion.isEnemy and minion.pos:DistanceTo(myHero.pos) < 500 then
						table.insert(minionlist, minion)
					end
				end
			end
			V = Vector(pos) - Vector(myHero.pos)
			
			Vn = V:Normalized()
			Distance = myHero.pos:DistanceTo(pos)
			tx, ty, tz = Vn:Unpack()
			TopX = pos.x - (tx * Distance)
			TopY = pos.y - (ty * Distance)
			TopZ = pos.z - (tz * Distance)
			
			Vr = V:Perpendicular():Normalized()
			Radius = qtarget.boundingRadius or 65
			tx, ty, tz = Vr:Unpack()
			
			LeftX = pos.x + (tx * Radius)
			LeftY = pos.y + (ty * Radius)
			LeftZ = pos.z + (tz * Radius)
			RightX = pos.x - (tx * Radius)
			RightY = pos.y - (ty * Radius)
			RightZ = pos.z - (tz * Radius)
			
			Left = Point(LeftX, LeftY, LeftZ)
			Right = Point(RightX, RightY, RightZ)
			Top = Point(TopX, TopY, TopZ)
			Poly = Polygon(Left, Right, Top)
			
			for i, minion in pairs(minionlist) do
				toPoint = Point(minion.pos.x, minion.pos.y,minion.pos.z)
				if Poly:__contains(toPoint) then
					return minion
				end
			end
		end
		return false 
	end
	
	
	function OnLoad()
		Lucian:__init()
	end
end


if myHero.charName == "Caitlyn" then
	local Caitlyn = {}
	Caitlyn.__index = Caitlyn
	local Scriptname,Version,Author,LVersion = "TRUSt in my Caitlyn","v1.8","TRUS","10.3"
	require "DamageLib"
	local qtarget
	if FileExist(COMMON_PATH .. "PremiumPrediction.lua") then
		require 'PremiumPrediction'
		PrintChat("PremiumPrediction library loaded")
	end
	local lastcastspell = {}
	local lasttrappedtime = {}
	local Alreadycheckedbuff = {}
	local LastW
	function Caitlyn:__init()
		if not TRUStinMyMarksmanloaded then TRUStinMyMarksmanloaded = true else return end
		self:LoadSpells()
		self:LoadMenu()
		Callback.Add("Tick", function() self:Tick() end)
		Callback.Add("Draw", function() self:Draw() end)
		local orbwalkername = ""
		if _G.SDK then
			orbwalkername = "IC'S orbwalker"		
			_G.SDK.Orbwalker:OnPostAttack(function(arg) 		
				self:GetTrapped()
			end)
		elseif _G.EOW then
			orbwalkername = "EOW"	
			_G.EOW:AddCallback(_G.EOW.AfterAttack, function() 
				self:GetTrapped()
			end)
		elseif _G.GOS then
			orbwalkername = "Noddy orbwalker"
			_G.GOS:OnAttackComplete(function() 
				self:GetTrapped()
			end)
		else
			PrintChat(Scriptname.." "..Version.." - Loaded...."..orbwalkername)
		end
	end
	
	--[[Spells]]
	function Caitlyn:LoadSpells()
		Q = {Range = 1190, Width = 90, Delay = 0.625, Speed = 2000}
		E = {Range = 800, Width = 70, Delay = 0.125, Speed = 1600}
	end
	
	function Caitlyn:LoadMenu()
		self.Menu = MenuElement({type = MENU, id = "TRUStinymyCaitlyn", name = Scriptname})
		self.Menu:MenuElement({id = "UseUlti", name = "Use R", tooltip = "On killable target which is on screen", key = string.byte("R")})
		self.Menu:MenuElement({id = "UseEQ", name = "UseEQ", key = string.byte("X")})
		self.Menu:MenuElement({id = "autoW", name = "Use W on cc", value = true})
		self.Menu:MenuElement({id = "AttackMoveHeadshots", name = "Attack move headshots", value = true})
		self.Menu:MenuElement({id = "UseBOTRK", name = "Use botrk", value = true})
		self.Menu:MenuElement({id = "CustomSpellCast", name = "Use custom spellcast", value = true})
		self.Menu:MenuElement({id = "DrawR", name = "Draw Killable with R", value = true})
		self.Menu:MenuElement({id = "DrawColor", name = "Color for Killable circle", color = Draw.Color(0xBF3F3FFF)})
		if (_G.PremiumPrediction:Loaded()) then
			
			self.Menu:MenuElement({id = "PremPredminchance", name = "PremPr Minimal hitchance", value = 1, min = 1, max = 100, step = 1, identifier = ""})
		end
		
		self.Menu:MenuElement({id = "delay", name = "Custom spellcast delay", value = 50, min = 0, max = 200, step = 5, identifier = ""})
		
		self.Menu:MenuElement({id = "blank", type = SPACE , name = ""})
		self.Menu:MenuElement({id = "blank", type = SPACE , name = "Script Ver: "..Version.. " - LoL Ver: "..LVersion.. "" .. (_G.PremiumPrediction:Loaded() and " PremiumPr" or "")})
		self.Menu:MenuElement({id = "blank", type = SPACE , name = "by "..Author.. ""})
	end
	
	function Caitlyn:Tick()
		if myHero.dead or (not _G.SDK and not _G.GOS) then return end
		local combomodeactive, harassactive, canmove, canattack, currenttarget = CurrentModes()
		if combomodeactive and self.Menu.UseBOTRK:Value() then
			UseBotrk()
		end
		if (myHero.activeSpell and myHero.activeSpell.valid and myHero.activeSpell.name == "CaitlynHeadshotMissile" and lasttrappedtime[myHero.activeSpell.target]) then
			lasttrappedtime[myHero.activeSpell.target] = nil
			PrintChat("attack done: "..myHero.activeSpell.target)
			self:GetTrapped()
		end
		
		for j, enemy in pairs(lasttrappedtime) do
			if enemy then 
				if Game.Timer() < enemy then
					enemy = nil
					return
				end
				
				if Game.Timer() > enemy and Game.Timer() - 0.1 < enemy then
					self:GetTrapped()
				end
			end
		end
		
		if (myHero.attackData and myHero.attackData.target and myHero.attackData.state ~= 1 and lasttrappedtime[myHero.attackData.target]) then
			--PrintChat("attack dropped")
		end
		local useEQ = self.Menu.UseEQ:Value()
		if self.Menu.UseUlti:Value() and self:CanCast(_R) then
			self:UseR()
		end
		if not currenttarget then 
			self:GetTrapped()
		end
		if self:CanCast(_Q) and self:CanCast(_E) and useEQ then
			self:CastE(currenttarget)
		end
		
		if myHero.activeSpell and myHero.activeSpell.valid and myHero.activeSpell.name == "CaitlynEntrapment" and self:CanCast(_Q) and useEQ then
			Control.CastSpell(HK_Q,qtarget)
		end
		if self:CanCast(_W) then
			self:AutoW()
		end
	end
	
	function ReturnCursor(pos)
		Control.SetCursorPos(pos)
		SetMovement(true)
	end
	
	function LeftClick(pos)
		DelayAction(ReturnCursor,0.01,{pos})
	end
	
	function Caitlyn:GetRTarget()
		self.KillableHeroes = {}
		local RRange = ({2000, 2500, 3000})[myHero:GetSpellData(_R).level]
		local heroeslist = (_G.SDK and _G.SDK.ObjectManager:GetEnemyHeroes(RRange)) or (_G.GOS and _G.GOS:GetEnemyHeroes())
		for i, hero in pairs(heroeslist) do
			local RDamage = getdmg("R",hero,myHero,1)
			if hero.health and RDamage and RDamage > hero.health and hero.pos2D.onScreen and myHero.pos:DistanceTo(hero.pos) < RRange then
				table.insert(self.KillableHeroes, hero)
			end
		end
		return self.KillableHeroes
	end
	
	function Caitlyn:IsValidTarget(unit, range, checkTeam, from)
		local range = range == nil and math.huge or range
		if unit == nil or not unit.valid or not unit.visible or unit.dead or not unit.isTargetable or (checkTeam and unit.isAlly) then
			return false
		end
		if myHero.pos:DistanceTo(unit.pos)>range then return false end 
		return true 
	end
	
	
	
	function Caitlyn:GetTrapped()
		if not self.Menu.AttackMoveHeadshots:Value() then return end
		local heroeslist = (_G.SDK and _G.SDK.ObjectManager:GetEnemyHeroes(RRange)) or (_G.GOS and _G.GOS:GetEnemyHeroes())
		for j, enemy in pairs(heroeslist) do
			for i = 0, enemy.buffCount do
				local buff = enemy:GetBuff(i);
				if (not myHero.isChanneling) and (buff.count > 0 and buff.duration > 0 and buff.name == "caitlynyordletrapinternal" and (lasttrappedtime[enemy.handle] == nil or lasttrappedtime[enemy.handle] < Game.Timer())) then
					lasttrappedtime[enemy] = buff.expireTime
					if self:IsValidTarget(enemy,1300) then
						self:AttackMoveShit(enemy)
					end
				end
			end
		end
	end
	
	function Caitlyn:UseR()
		local RTarget = self:GetRTarget()
		if #RTarget > 0 then
			Control.SetCursorPos(RTarget[1].pos)
			Control.KeyDown(HK_R)
			Control.KeyUp(HK_R)
		end
	end
	
	function Caitlyn:Draw()
		if self.Menu.DrawR:Value() then
			local RTarget = self:GetRTarget()
			for i, hero in pairs(RTarget) do
				Draw.Circle(hero.pos, 60, 3, self.Menu.DrawColor:Value())
			end
		end
	end
	
	function Caitlyn:Stunned(enemy)
		for i = 0, enemy.buffCount do
			local buff = enemy:GetBuff(i);
			if (buff.type == 5 or buff.type == 11 or buff.type == 24) and buff.duration > 0.9 and buff.name ~= "caitlynyordletrapdebuff" then
				return true
			end
		end
		return false
	end
	
	function Caitlyn:AutoW()
		if not self.Menu.autoW:Value() then return end
		local ImmobileEnemy = self:GetImmobileTarget()
		if ImmobileEnemy and myHero.pos:DistanceTo(ImmobileEnemy.pos)<800 and (not LastW or LastW:DistanceTo(ImmobileEnemy.pos)>60) then
			if ImmobileEnemy.pathing.isDashing and myHero.pos:DistanceTo(ImmobileEnemy.pathing.endPos)<800 then
				self:CastSpell(HK_W,ImmobileEnemy.pathing.endPos)
			else
				self:CastSpell(HK_W,ImmobileEnemy.pos)
			end
			LastW = ImmobileEnemy.pos
		end
	end
	
	
	function Caitlyn:AttackMoveShit(enemy)
		local delay = self.Menu.delay:Value()
		local ticker = GetTickCount()
		if castSpell.state == 0 and ticker > castSpell.casting then
			castSpell.state = 1
			castSpell.mouse = mousePos
			castSpell.tick = ticker
			if ticker - castSpell.tick < Game.Latency() then
				--block movement
				local newpos = Vector(enemy.pos.x, enemy.pos.y,enemy.pos.z + 200)
				Control.SetCursorPos(newpos)
				Control.KeyDown(0x39)
				Control.KeyUp(0x39)
				DelayAction(LeftClick,delay/1000,{castSpell.mouse})
				castSpell.casting = ticker
			end
		end
	end
	
	function Caitlyn:CastSpell(spell,pos)
		local customcast = self.Menu.CustomSpellCast:Value()
		if not customcast then
			Control.CastSpell(spell, pos)
			return
		else
			local delay = self.Menu.delay:Value()
			local ticker = GetTickCount()
			if castSpell.state == 0 and ticker > castSpell.casting then
				castSpell.state = 1
				castSpell.mouse = mousePos
				castSpell.tick = ticker
				if ticker - castSpell.tick < Game.Latency() then
					--block movement
					SetMovement(false)
					Control.SetCursorPos(pos)
					Control.KeyDown(spell)
					Control.KeyUp(spell)
					DelayAction(LeftClick,delay/1000,{castSpell.mouse})
					castSpell.casting = ticker
				end
			end
		end
	end
	
	
	function Caitlyn:GetImmobileTarget()
		local GetEnemyHeroes = (_G.SDK and _G.SDK.ObjectManager:GetEnemyHeroes(800)) or (_G.GOS and _G.GOS:GetEnemyHeroes())
		for i = 1, #GetEnemyHeroes do
			local Enemy = GetEnemyHeroes[i]
			if Enemy and self:Stunned(Enemy) and myHero.pos:DistanceTo(Enemy.pos) < 800 then
				return Enemy
			end
		end
		return false
	end
	
	
	
	function Caitlyn:CastCombo(pos)
		local delay = self.Menu.delay:Value()
		local ticker = GetTickCount()
		if castSpell.state == 0 and ticker > castSpell.casting then
			castSpell.state = 1
			castSpell.mouse = mousePos
			castSpell.tick = ticker
			if ticker - castSpell.tick < Game.Latency() then
				--block movement
				SetMovement(false)
				Control.SetCursorPos(pos)
				Control.KeyDown(HK_E)
				Control.KeyUp(HK_E)
				Control.KeyDown(HK_Q)
				Control.KeyUp(HK_Q)
				DelayAction(LeftClick,delay/1000,{castSpell.mouse})
				castSpell.casting = ticker
			end
		end
	end
	
	
	
	--[[CastEQ]]
	function Caitlyn:CastE(target)
		if not _G.SDK and not _G.GOS then return end
		local target = target or (_G.SDK and _G.SDK.TargetSelector:GetTarget(E.Range, _G.SDK.DAMAGE_TYPE_PHYSICAL)) or (_G.GOS and _G.GOS:GetTarget(E.Range,"AD"))
		local castpos
		if (_G.PremiumPrediction:Loaded() and target) then
			local spellData = {speed = E.Speed, range = E.Range, delay = E.Delay, radius = E.Width, collision = {"minion"}, type = "linear"}
			local pred = _G.PremiumPrediction:GetPrediction(myHero, target, spellData)
			if pred.CastPos and pred.HitChance >= self.Menu.PremPredminchance:Value()/100 then
				self:CastCombo(pred.CastPos)
				qtarget = pred.CastPos
			end
		elseif target and target:GetCollision(E.Radius,E.Speed,E.Delay) == 0 then
			castPos = target:GetPrediction(E.Speed,E.Delay)
			self:CastCombo(castPos)
			qtarget = castPos
		end
	end
	
	
	function Caitlyn:IsReady(spellSlot)
		return myHero:GetSpellData(spellSlot).currentCd == 0 and myHero:GetSpellData(spellSlot).level > 0
	end
	
	function Caitlyn:CheckMana(spellSlot)
		return myHero:GetSpellData(spellSlot).mana < myHero.mana
	end
	
	function Caitlyn:CanCast(spellSlot)
		return self:IsReady(spellSlot) and self:CheckMana(spellSlot)
	end
	
	function OnLoad()
		Caitlyn:__init()
	end
end

if myHero.charName == "Ezreal" then
	local Ezreal = {}
	Ezreal.__index = Ezreal
	local Scriptname,Version,Author,LVersion = "TRUSt in my Ezreal","v1.11","TRUS","10.3"
	require "DamageLib"
	
	if FileExist(COMMON_PATH .. "PremiumPrediction.lua") then
		require 'PremiumPrediction'
		PrintChat("PremiumPrediction library loaded")
	end
	local EPrediction = {}
	
	function Ezreal:__init()
		if not TRUStinMyMarksmanloaded then TRUStinMyMarksmanloaded = true else return end
		self:LoadSpells()
		self:LoadMenu()
		Callback.Add("Tick", function() self:Tick() end)
		
		local orbwalkername = ""
		if _G.SDK then
			orbwalkername = "IC'S orbwalker"	
		elseif _G.EOW then
			orbwalkername = "EOW"	
		elseif _G.GOS then
			orbwalkername = "Noddy orbwalker"
		else
			orbwalkername = "Orbwalker not found"
		end
		PrintChat(Scriptname.." "..Version.." - Loaded...."..orbwalkername)
	end
	
	local lastpick = 0
	--[[Spells]]
	function Ezreal:LoadSpells()
		Q = {Range = 1150, Width = 60, Delay = 0.25, Speed = 2000, Collision = false, aoe = false, type = "line"}
		if TYPE_GENERIC then
			local QSpell = Prediction:SetSpell({range = Q.Range, speed = Q.Speed, delay = Q.Delay, width = Q.Width}, TYPE_LINE, true)
			EPrediction[_Q] = QSpell
		end
	end
	
	function Ezreal:LoadMenu()
		self.Menu = MenuElement({type = MENU, id = "TRUStinymyEzreal", name = Scriptname})
		self.Menu:MenuElement({id = "UseQ", name = "UseQ on champions", value = true})
		self.Menu:MenuElement({id = "UseQLH", name = "[WIP] UseQ to lasthit", value = true})
		self.Menu:MenuElement({id = "UseBOTRK", name = "Use botrk", value = true})
		if TYPE_GENERIC then
			self.Menu:MenuElement({id = "EternalUse", name = "Use eternal prediction", value = true})
			self.Menu:MenuElement({id = "minchance", name = "Minimal hitchance EPred", value = 0.25, min = 0, max = 1, step = 0.05, identifier = ""})
		end
		if (_G.PremiumPrediction:Loaded()) then
			
			self.Menu:MenuElement({id = "PremPredminchance", name = "PremPr Minimal hitchance", value = 1, min = 1, max = 100, step = 1, identifier = ""})
		end
		
		self.Menu:MenuElement({id = "CustomSpellCast", name = "Use custom spellcast", tooltip = "Can fix some casting problems with wrong directions and so (thx Noddy for this one)", value = true})
		self.Menu:MenuElement({id = "delay", name = "Custom spellcast delay", value = 50, min = 0, max = 200, step = 5, identifier = ""})
		
		self.Menu:MenuElement({id = "blank", type = SPACE , name = ""})
		self.Menu:MenuElement({id = "blank", type = SPACE , name = "Script Ver: "..Version.. " - LoL Ver: "..LVersion.. "" .. (_G.PremiumPrediction:Loaded() and " PremiumPr" or "")})
		self.Menu:MenuElement({id = "blank", type = SPACE , name = "by "..Author.. ""})
	end
	
	function Ezreal:Tick()
		if myHero.dead or (not _G.SDK and not _G.GOS) then return end
		local combomodeactive, harassactive, canmove, canattack, currenttarget = CurrentModes()
		local farmactive = (_G.SDK and _G.SDK.Orbwalker.Modes[_G.SDK.ORBWALKER_MODE_LASTHIT]) or (_G.EOW and _G.EOW:Mode() == 3) or (not _G.SDK and _G.GOS and _G.GOS:GetMode() == "Lasthit") 
		local laneclear = (_G.SDK and _G.SDK.Orbwalker.Modes[_G.SDK.ORBWALKER_MODE_LANECLEAR]) or (_G.EOW and _G.EOW:Mode() == 4) or (not _G.SDK and _G.GOS and _G.GOS:GetMode() == "Clear") 
		
		if combomodeactive and self.Menu.UseBOTRK:Value() then
			UseBotrk()
		end
		if (combomodeactive or harassactive) and self:CanCast(_Q) and self.Menu.UseQ:Value() and canmove and (not canattack or not currenttarget) then
			self:CastQ()
		end
		
		if (farmactive or laneclear) and self.Menu.UseQLH:Value() then 
			self:QLastHit()
		end
		
		
	end
	
	function EnableMovement()
		--unblock movement
		SetMovement(true)
	end
	
	function ReturnCursor(pos)
		Control.SetCursorPos(pos)
		DelayAction(EnableMovement,0.1)
	end
	
	function LeftClick(pos)
		Control.mouse_event(MOUSEEVENTF_LEFTDOWN)
		Control.mouse_event(MOUSEEVENTF_LEFTUP)
		DelayAction(ReturnCursor,0.05,{pos})
	end
	
	function Ezreal:CastSpell(spell,pos)
		local customcast = self.Menu.CustomSpellCast:Value()
		if not customcast then
			Control.CastSpell(spell, pos)
			return
		else
			local delay = self.Menu.delay:Value()
			local ticker = GetTickCount()
			if castSpell.state == 0 and ticker > castSpell.casting then
				castSpell.state = 1
				castSpell.mouse = mousePos
				castSpell.tick = ticker
				if ticker - castSpell.tick < Game.Latency() then
					--block movement
					SetMovement(false)
					Control.SetCursorPos(pos)
					Control.KeyDown(spell)
					Control.KeyUp(spell)
					DelayAction(LeftClick,delay/1000,{castSpell.mouse})
					castSpell.casting = ticker + 500
				end
			end
		end
	end
	
	
	--[[CastQ]]
	function Ezreal:CastQ(target)
		if (not _G.SDK and not _G.GOS) then return end
		if (myHero.activeSpell and myHero.activeSpell.valid and myHero.activeSpell.name == "EzrealArcaneShift") then return end 
		local target = target or (_G.SDK and _G.SDK.TargetSelector:GetTarget(Q.Range, _G.SDK.DAMAGE_TYPE_PHYSICAL)) or (_G.GOS and _G.GOS:GetTarget(Q.Range,"AD"))
		if target and target.type == "AIHeroClient" and self:CanCast(_Q) and self.Menu.UseQ:Value() then
			if (_G.PremiumPrediction:Loaded()) then
				local spellData = {speed = Q.Speed, range = Q.Range, delay = Q.Delay, radius = Q.Width, collision = {"minion"}, type = "linear"}
				local pred = _G.PremiumPrediction:GetPrediction(myHero, target, spellData)
				if pred.CastPos and pred.HitChance >= self.Menu.PremPredminchance:Value()/100 then
					self:CastSpell(HK_Q, pred.CastPos)
				end
			elseif target:GetCollision(Q.Width,Q.Speed,Q.Delay) == 0 then
				castPos = target:GetPrediction(Q.Speed,Q.Delay)
				self:CastSpell(HK_Q, castPos)
			end
			
		end
	end
	function Ezreal:QLastHit()
		local minionlist = {}
		local canattack = (_G.SDK and _G.SDK.Orbwalker:CanAttack()) or (not _G.SDK and _G.GOS and _G.GOS:CanAttack())
		local canmove = (_G.SDK and _G.SDK.Orbwalker:CanMove()) or (not _G.SDK and _G.GOS and _G.GOS:CanMove())
		if _G.SDK then
			minionlist = _G.SDK.ObjectManager:GetEnemyMinions(Q.Range)
		elseif _G.GOS then
			for i = 1, Game.MinionCount() do
				local minion = Game.Minion(i)
				if minion.valid and minion.isEnemy and minion.pos:DistanceTo(myHero.pos) < Q.Range then
					table.insert(minionlist, minion)
				end
			end
		end
		
		for i, minion in pairs(minionlist) do
			local distancetominion = myHero.pos:DistanceTo(minion.pos)
			if (distancetominion > myHero.range or (not canattack and canmove)) and not _G.SDK.Orbwalker:ShouldWait() then
				local QDamage = getdmg("Q",minion,myHero)
				local timetohit = distancetominion/Q.Speed
				if _G.SDK.HealthPrediction:GetPrediction(minion, timetohit + 0.3)<0 and _G.SDK.HealthPrediction:GetPrediction(minion, timetohit)< QDamage and _G.SDK.HealthPrediction:GetPrediction(minion, timetohit)>0 then
					if minion and self:CanCast(_Q) and minion:GetCollision(Q.Radius,Q.Speed,Q.Delay) == 1 then
						local castPos = minion:GetPrediction(Q.Speed,Q.Delay)
						self:CastSpell(HK_Q, castPos)
					end
				end
			end
		end
	end
	
	function Ezreal:IsReady(spellSlot)
		return myHero:GetSpellData(spellSlot).currentCd == 0 and myHero:GetSpellData(spellSlot).level > 0
	end
	
	function Ezreal:CheckMana(spellSlot)
		return myHero:GetSpellData(spellSlot).mana < myHero.mana
	end
	
	function Ezreal:CanCast(spellSlot)
		return self:IsReady(spellSlot) and self:CheckMana(spellSlot)
	end
	
	
	function OnLoad()
		Ezreal:__init()
	end
end

if myHero.charName == "Twitch" then
	local Scriptname,Version,Author,LVersion = "TRUSt in my Twitch","v1.8","TRUS","8.8"
	local Twitch = {}
	Twitch.__index = Twitch
	require "DamageLib"
	local qtarget
	local barHeight = 8
	local barWidth = 103
	local barXOffset = 24
	local barYOffset = -8
	function Twitch:__init()
		if not TRUStinMyMarksmanloaded then TRUStinMyMarksmanloaded = true else return end
		self:LoadMenu()
		Callback.Add("Tick", function() self:Tick() end)
		Callback.Add("Draw", function() self:Draw() end)
		local orbwalkername = ""
		if _G.SDK then
			orbwalkername = "IC'S orbwalker"		
			_G.SDK.Orbwalker:OnPostAttack(function(arg) 		
				DelayAction(recheckparticle,0.2)
			end)
		elseif _G.EOW then
			orbwalkername = "EOW"	
			_G.EOW:AddCallback(_G.EOW.AfterAttack, function() 
				DelayAction(recheckparticle,0.2)
			end)
		elseif _G.GOS then
			orbwalkername = "Noddy orbwalker"
			_G.GOS:OnAttackComplete(function() 
				DelayAction(recheckparticle,0.2)
			end)
		else
			orbwalkername = "Orbwalker not found"
			
		end
		PrintChat(Scriptname.." "..Version.." - Loaded...."..orbwalkername)
	end
	
	function Twitch:LoadMenu()
		self.Menu = MenuElement({type = MENU, id = "TRUStinymyTwitch", name = Scriptname})
		self.Menu:MenuElement({id = "UseEKS", name = "Use E on killable", value = true})
		self.Menu:MenuElement({id = "UseERange", name = "Use E on running enemy", value = true})
		self.Menu:MenuElement({id = "MinStacks", name = "Minimal E stacks", value = 2, min = 0, max = 6, step = 1, identifier = ""})
		self.Menu:MenuElement({id = "UseBOTRK", name = "Use botrk", value = true})
		self.Menu:MenuElement({id = "CustomSpellCast", name = "Use custom spellcast", value = true})
		self.Menu:MenuElement({id = "DrawE", name = "Draw Killable with E", value = true})
		self.Menu:MenuElement({id = "DrawEDamage", name = "Draw E damage on HPBar", value = true})
		self.Menu:MenuElement({id = "DrawColor", name = "Color for drawing", color = Draw.Color(0xBF3F3FFF)})
		self.Menu:MenuElement({id = "delay", name = "Custom spellcast delay", value = 50, min = 0, max = 200, step = 5, identifier = ""})
		
		self.Menu:MenuElement({id = "blank", type = SPACE , name = ""})
		self.Menu:MenuElement({id = "blank", type = SPACE , name = "Script Ver: "..Version.. " - LoL Ver: "..LVersion.. "" .. (_G.PremiumPrediction:Loaded() and " PremiumPr" or "")})
		self.Menu:MenuElement({id = "blank", type = SPACE , name = "by "..Author.. ""})
	end
	local lastcasttime = 0
	function Twitch:Tick()
		if myHero.dead or (not _G.SDK and not _G.GOS) then return end
		
		if myHero.activeSpell and myHero.activeSpell.valid and myHero.activeSpell.name:lower() == "twitchvenomcask" and myHero.activeSpell.startTime ~= lastcasttime then
			lastcasttime = myHero.activeSpell.startTime
			DelayAction(recheckparticle,0.3)
		end
		
		
		local combomodeactive, harassactive, canmove, canattack, currenttarget = CurrentModes()
		
		if combomodeactive then 
			if self.Menu.UseBOTRK:Value() then
				UseBotrk()
			end	
		end
		
		if self:CanCast(_E) and self.Menu.UseEKS:Value() then
			self:UseEKS()
		end
		
		if (harassactive or combomodeactive) and self.Menu.UseERange:Value() and self:CanCast(_E) then
			self:UseERange()
		end
	end
	
	function Twitch:UseERange()
		local heroeslist = (_G.SDK and _G.SDK.ObjectManager:GetEnemyHeroes(1100)) or (_G.GOS and _G.GOS:GetEnemyHeroes())
		local target = (_G.SDK and _G.SDK.TargetSelector.SelectedTarget) or (_G.GOS and _G.GOS:GetTarget())
		if target then return end 
		for i, hero in pairs(heroeslist) do
			if stacks[hero.charName] and self:GetStacks(stacks[hero.charName].name) >= self.Menu.MinStacks:Value() then
				if myHero.pos:DistanceTo(hero.pos)<1000 and myHero.pos:DistanceTo(hero:GetPrediction(math.huge,0.25)) > 1000 then
					Control.CastSpell(HK_E)
				end
			end
		end
	end
	
	function Twitch:GetStacks(str)
		if str:lower():find("twitch_base_p_stack_01") then return 1
		elseif str:lower():find("twitch_base_p_stack_02") then return 2
		elseif str:lower():find("twitch_base_p_stack_03") then return 3
		elseif str:lower():find("twitch_base_p_stack_04") then return 4
		elseif str:lower():find("twitch_base_p_stack_05") then return 5
		elseif str:lower():find("twitch_base_p_stack_06") then return 6
		end
		return 0
	end
	stacks = {}
	function recheckparticle()
		local heroeslist = (_G.SDK and _G.SDK.ObjectManager:GetEnemyHeroes(1100)) or (_G.GOS and _G.GOS:GetEnemyHeroes())
		for i = 1, Game.ParticleCount() do
			local object = Game.Particle(i)			
			if object then
				local stacksamount = Twitch:GetStacks(object.name)
				if stacksamount > 0 then
					for i, hero in pairs(heroeslist) do
						if object.pos:DistanceTo(hero.pos)<200 and object ~= hero then 	
							stacks[hero.charName] = object
						end
					end
				end
			end
		end
		return false
	end
	
	function Twitch:GetBuffs(unit)
		self.T = {}
		for i = 0, unit.buffCount do
			local Buff = unit:GetBuff(i)
			if Buff.count > 0 then
				table.insert(self.T, Buff)
			end
		end
		return self.T
	end
	
	local DamageModifiersTable = {
		summonerexhaustdebuff = 0.6,
		itemphantomdancerdebuff = 0.88
	}
	function Twitch:DamageModifiers(target)
		local currentpercent = 1
		for K, Buff in pairs(self:GetBuffs(myHero)) do
			if DamageModifiersTable[Buff.name:lower()] then
				currentpercent = currentpercent*DamageModifiersTable[Buff.name:lower()]
			end
		end
		for K, Buff in pairs(self:GetBuffs(target)) do
			if Buff.count > 0 and Buff.name and string.find(Buff.name, "PressThreeAttack") and (Buff.expireTime - Buff.startTime == 6) then
				currentpercent = currentpercent * 1.12
			end
		end
		return currentpercent
	end
	
	
	function Twitch:GetETarget()
		self.KillableHeroes = {}
		self.DamageHeroes = {}
		local heroeslist = (_G.SDK and _G.SDK.ObjectManager:GetEnemyHeroes(1200)) or (_G.GOS and _G.GOS:GetEnemyHeroes())
		local level = myHero:GetSpellData(_E).level
		if level == 0 then return end
		for i, hero in pairs(heroeslist) do
			if stacks[hero.charName] and self:GetStacks(stacks[hero.charName].name) > 0 then 
				local EDamage = (self:GetStacks(stacks[hero.charName].name) * (({15, 20, 25, 30, 35})[level] + 0.2 * myHero.ap + 0.25 * myHero.bonusDamage)) + ({20, 30, 40, 50, 60})[level]
				local tmpdmg = CalcPhysicalDamage(myHero, hero, EDamage)
				local damagemods = self:DamageModifiers(hero)
				tmpdmg = tmpdmg * damagemods
				if hero.health and tmpdmg then 
					if tmpdmg > hero.health and myHero.pos:DistanceTo(hero.pos)<1200 then
						table.insert(self.KillableHeroes, hero)
					else
						table.insert(self.DamageHeroes, {hero = hero, damage = tmpdmg})
					end
				end
			end
		end
		return self.KillableHeroes, self.DamageHeroes
	end
	
	function Twitch:UseEKS()
		local ETarget, damaged = self:GetETarget()
		if #ETarget > 0 then
			Control.KeyDown(HK_E)
			Control.KeyUp(HK_E)
		end
	end
	
	function Twitch:Draw()
		if self.Menu.DrawE:Value() or self.Menu.DrawEDamage:Value() then
			local ETarget, damaged = self:GetETarget()
			if self.Menu.DrawE:Value() then
				if not ETarget then return end
				for i, hero in pairs(ETarget) do
					Draw.Circle(hero.pos, 60, 3, self.Menu.DrawColor:Value())
				end
			end
			if self.Menu.DrawEDamage:Value() then 
				if not damaged then return end
				for i, hero in pairs(damaged) do
					local barPos = hero.hero.hpBar
					if barPos.onScreen then
						local damage = hero.damage
						local percentHealthAfterDamage = math.max(0, hero.hero.health - damage) / hero.hero.maxHealth
						local xPosEnd = barPos.x + barXOffset + barWidth * hero.hero.health/hero.hero.maxHealth
						local xPosStart = barPos.x + barXOffset + percentHealthAfterDamage * 100
						Draw.Line(xPosStart, barPos.y + barYOffset, xPosEnd, barPos.y + barYOffset, 10, self.Menu.DrawColor:Value())
					end
				end
			end
		end
	end
	
	
	function Twitch:IsReady(spellSlot)
		return myHero:GetSpellData(spellSlot).currentCd == 0 and myHero:GetSpellData(spellSlot).level > 0
	end
	
	function Twitch:CheckMana(spellSlot)
		return myHero:GetSpellData(spellSlot).mana < myHero.mana
	end
	
	function Twitch:CanCast(spellSlot)
		return self:IsReady(spellSlot) and self:CheckMana(spellSlot)
	end
	
	function OnLoad()
		Twitch:__init()
	end
end

if myHero.charName == "KogMaw" then
	local KogMaw = {}
	KogMaw.__index = KogMaw
	local Scriptname,Version,Author,LVersion = "TRUSt in my KogMaw","v1.5","TRUS","10.3"
	
	if FileExist(COMMON_PATH .. "PremiumPrediction.lua") then
		require 'PremiumPrediction'
		PrintChat("PremiumPrediction library loaded")
	end
	
	function KogMaw:__init()
		if not TRUStinMyMarksmanloaded then TRUStinMyMarksmanloaded = true else return end
		self:LoadSpells()
		self:LoadMenu()
		Callback.Add("Tick", function() self:Tick() end)
		
		local orbwalkername = ""
		if _G.SDK then
			orbwalkername = "IC'S orbwalker"
			_G.SDK.Orbwalker:OnPostAttack(function() 
				local combomodeactive = _G.SDK.Orbwalker.Modes[_G.SDK.ORBWALKER_MODE_COMBO]
				local harassactive = _G.SDK.Orbwalker.Modes[_G.SDK.ORBWALKER_MODE_HARASS]
				if (combomodeactive or harassactive) then
					self:CastQ(_G.SDK.Orbwalker:GetTarget(),combomodeactive)
				end
			end)
		elseif _G.EOW then
			orbwalkername = "EOW"	
			_G.EOW:AddCallback(_G.EOW.AfterAttack, function() 
				local combomodeactive = _G.EOW:Mode() == 1
				local harassactive = _G.EOW:Mode() == 2
				if (combomodeactive or harassactive) then
					self:CastQ(_G.EOW:GetTarget(),combomodeactive)
				end
			end)
		elseif _G.GOS then
			orbwalkername = "Noddy orbwalker"
			_G.GOS:OnAttackComplete(function() 
				local combomodeactive = _G.GOS:GetMode() == "Combo"
				local harassactive = _G.GOS:GetMode() == "Harass"
				if (combomodeactive or harassactive) then
					self:CastQ(_G.GOS:GetTarget(),combomodeactive)
				end
			end)
		else
			orbwalkername = "Orbwalker not found"
			
		end
		PrintChat(Scriptname.." "..Version.." - Loaded...."..orbwalkername)
	end
	
	--[[Spells]]
	function KogMaw:LoadSpells()
		Q = {Range = 1175, Width = 70, Delay = 0.25, Speed = 1650}
		E = {Range = 1280, Width = 120, Delay = 0.5, Speed = 1350}
		R = {Range = 1200, Delay = 1.2, Width = 120, Speed = 99999999}
	end
	
	function KogMaw:LoadMenu()
		self.Menu = MenuElement({type = MENU, id = "TRUStinymyKogMaw", name = Scriptname})
		--[[Combo]]
		self.Menu:MenuElement({id = "UseBOTRK", name = "Use botrk", value = true})
		self.Menu:MenuElement({type = MENU, id = "Combo", name = "Combo Settings"})
		self.Menu.Combo:MenuElement({id = "comboUseQ", name = "Use Q", value = true})
		self.Menu.Combo:MenuElement({id = "comboUseE", name = "Use E", value = true})
		self.Menu.Combo:MenuElement({id = "comboUseR", name = "Use R", value = true})
		self.Menu.Combo:MenuElement({id = "MaxStacks", name = "Max R stacks: ", value = 3, min = 0, max = 10})
		self.Menu.Combo:MenuElement({id = "ManaW", name = "Save mana for W", value = true})
		
		--[[Harass]]
		self.Menu:MenuElement({type = MENU, id = "Harass", name = "Harass Settings"})
		self.Menu.Harass:MenuElement({id = "harassUseQ", name = "Use Q", value = true})
		self.Menu.Harass:MenuElement({id = "harassUseE", name = "Use E", value = true})
		self.Menu.Harass:MenuElement({id = "harassMana", name = "Minimal mana percent:", value = 30, min = 0, max = 101, identifier = "%"})
		self.Menu.Harass:MenuElement({id = "harassUseR", name = "Use R", value = true})
		self.Menu.Harass:MenuElement({id = "HarassMaxStacks", name = "Max R stacks: ", value = 3, min = 0, max = 10})
		
		if (_G.PremiumPrediction:Loaded()) then
			
			self.Menu:MenuElement({id = "PremPredminchance", name = "PremPr Minimal hitchance", value = 1, min = 1, max = 100, step = 1, identifier = ""})
		end
		
		self.Menu:MenuElement({id = "CustomSpellCast", name = "Use custom spellcast", tooltip = "Can fix some casting problems with wrong directions and so (thx Noddy for this one)", value = true})
		self.Menu:MenuElement({id = "delay", name = "Custom spellcast delay", value = 50, min = 0, max = 200, step = 5, identifier = ""})
		
		self.Menu:MenuElement({id = "blank", type = SPACE , name = ""})
		self.Menu:MenuElement({id = "blank", type = SPACE , name = "Script Ver: "..Version.. " - LoL Ver: "..LVersion.. "" .. (_G.PremiumPrediction:Loaded() and " PremiumPr" or "")})
		self.Menu:MenuElement({id = "blank", type = SPACE , name = "by "..Author.. ""})
	end
	
	function KogMaw:Tick()
		if myHero.dead or (not _G.SDK and not _G.GOS) then return end
		local combomodeactive, harassactive, canmove, canattack, currenttarget = CurrentModes()
		local HarassMinMana = self.Menu.Harass.harassMana:Value()
		
		
		if combomodeactive and self.Menu.UseBOTRK:Value() then
			UseBotrk()
		end
		
		if ((combomodeactive) or (harassactive and myHero.maxMana * HarassMinMana * 0.01 < myHero.mana)) and canmove and (not canattack or not currenttarget) then
			self:CastQ(currenttarget,combomodeactive or false)
			self:CastE(currenttarget,combomodeactive or false)
			self:CastR(currenttarget,combomodeactive or false)
		end
		
		
		if myHero.activeSpell and myHero.activeSpell.valid and (myHero.activeSpell.name == "KogMawQ" or myHero.activeSpell.name == "KogMawVoidOozeMissile" or myHero.activeSpell.name == "KogMawLivingArtillery") then
			if castSpell.state == 1 then
				ReturnCursor(castSpell.mouse)
			end
		end
	end
	
	function EnableMovement()
		SetMovement(true)
	end
	
	function ReturnCursor(pos)
		Control.SetCursorPos(pos)
		DelayAction(EnableMovement,0.1)
	end
	
	function LeftClick(pos)
		Control.mouse_event(MOUSEEVENTF_LEFTDOWN)
		Control.mouse_event(MOUSEEVENTF_LEFTUP)
		DelayAction(ReturnCursor,0.05,{pos})
	end
	
	function KogMaw:CastSpell(spell,pos)
		local customcast = self.Menu.CustomSpellCast:Value()
		if not customcast then
			Control.CastSpell(spell, pos)
			return
		else
			local delay = self.Menu.delay:Value()
			local ticker = GetTickCount()
			if castSpell.state == 0 and ticker > castSpell.casting then
				castSpell.state = 1
				castSpell.mouse = mousePos
				castSpell.tick = ticker
				if ticker - castSpell.tick < Game.Latency() then
					--block movement
					SetMovement(false)
					Control.SetCursorPos(pos)
					Control.KeyDown(spell)
					Control.KeyUp(spell)
					DelayAction(LeftClick,delay/1000,{castSpell.mouse})
					castSpell.casting = ticker + 500
				end
			end
		end
	end
	
	function KogMaw:GetRRange()
		return (myHero:GetSpellData(_R).level > 0 and ({1200,1500,1800})[myHero:GetSpellData(_R).level]) or 0
	end
	
	function KogMaw:GetBuffs()
		self.T = {}
		for i = 0, myHero.buffCount do
			local Buff = myHero:GetBuff(i)
			if Buff.count > 0 then
				table.insert(self.T, Buff)
			end
		end
		return self.T
	end
	
	function KogMaw:UltStacks()
		for K, Buff in pairs(self:GetBuffs()) do
			if Buff.name:lower() == "kogmawlivingartillerycost" then
				return Buff.count
			end
		end
		return 0
	end
	
	
	--[[CastQ]]
	function KogMaw:CastQ(target, combo)
		if (not _G.SDK and not _G.GOS and not _G.EOW) then return end
		local target = target or (_G.SDK and _G.SDK.TargetSelector:GetTarget(Q.Range, _G.SDK.DAMAGE_TYPE_PHYSICAL)) or (_G.GOS and _G.GOS:GetTarget(Q.Range,"AP"))
		if target and target.type == "AIHeroClient" and self:CanCast(_Q) and ((combo and self.Menu.Combo.comboUseQ:Value()) or (combo == false and self.Menu.Harass.harassUseQ:Value())) then
			
			if (_G.PremiumPrediction:Loaded()) then
				local spellData = {speed = Q.Speed, range = Q.Range, delay = Q.Delay, radius = Q.Width, collision = {"minion"}, type = "linear"}
				local pred = _G.PremiumPrediction:GetPrediction(myHero, target, spellData)
				if pred.CastPos and pred.HitChance >= self.Menu.PremPredminchance:Value()/100 then
					self:CastSpell(HK_Q, pred.CastPos)
				end
			elseif (target:GetCollision(Q.Width,Q.Speed,Q.Delay) == 0) then
				local castPos = target:GetPrediction(Q.Speed,Q.Delay)
				self:CastSpell(HK_Q, castPos)
			end
		end
	end
	
	
	--[[CastE]]
	function KogMaw:CastE(target,combo)
		if (not _G.SDK and not _G.GOS and not _G.EOW) then return end
		local target = target or (_G.SDK and _G.SDK.TargetSelector:GetTarget(E.Range, _G.SDK.DAMAGE_TYPE_PHYSICAL)) or (_G.GOS and _G.GOS:GetTarget(E.Range,"AP"))
		if target and target.type == "AIHeroClient" and self:CanCast(_E) and ((combo and self.Menu.Combo.comboUseE:Value()) or (combo == false and self.Menu.Harass.harassUseE:Value())) then
			
			if (_G.PremiumPrediction:Loaded()) then
				local spellData = {speed = E.Speed, range = E.Range, delay = E.Delay, radius = E.Width, collision = {}, type = "linear"}
				local pred = _G.PremiumPrediction:GetPrediction(myHero, target, spellData)
				if pred.CastPos and pred.HitChance >= self.Menu.PremPredminchance:Value()/100 then
					self:CastSpell(HK_E, pred.CastPos)
				end
			else
				local castPos = target:GetPrediction(E.Speed,E.Delay)
				self:CastSpell(HK_E, castPos)
			end
		end
	end
	
	--[[CastR]]
	function KogMaw:CastR(target,combo)
		if (not _G.SDK and not _G.GOS and not _G.EOW) then return end
		local RRange = self:GetRRange()
		local target = target or (_G.SDK and _G.SDK.TargetSelector:GetTarget(RRange, _G.SDK.DAMAGE_TYPE_PHYSICAL)) or (_G.GOS and _G.GOS:GetTarget(RRange,"AP"))
		local currentultstacks = self:UltStacks()
		if target and target.type == "AIHeroClient" and self:CanCast(_R) 
		and ((combo and self.Menu.Combo.comboUseR:Value()) or (combo == false and self.Menu.Harass.harassUseR:Value())) 
		and ((combo == false and currentultstacks < self.Menu.Harass.HarassMaxStacks:Value()) or (currentultstacks < self.Menu.Combo.MaxStacks:Value()))
		then
			if (_G.PremiumPrediction:Loaded()) then
				local spellData = {speed = R.Speed, range = R.Range, delay = R.Delay, radius = R.Width, collision = {}, type = "circular"}
				local pred = _G.PremiumPrediction:GetPrediction(myHero, target, spellData)
				if pred.CastPos and pred.CastPos:To2D().onScreen and pred.HitChance >= self.Menu.PremPredminchance:Value()/100 then
					self:CastSpell(HK_R, pred.CastPos)
				end
			else
				local castPos = target:GetPrediction(R.Speed,R.Delay)
				if (castPos:To2D().onScreen) then
					self:CastSpell(HK_R, castPos)
				end
			end
		end
	end
	
	function KogMaw:IsReady(spellSlot)
		return myHero:GetSpellData(spellSlot).currentCd == 0 and myHero:GetSpellData(spellSlot).level > 0
	end
	
	function KogMaw:CheckMana(spellSlot)
		local savemana = self.Menu.Combo.ManaW:Value()
		return myHero:GetSpellData(spellSlot).mana < (myHero.mana - ((savemana and 40) or 0))
	end
	
	function KogMaw:CanCast(spellSlot)
		return self:IsReady(spellSlot) and self:CheckMana(spellSlot)
	end
	
	
	function OnLoad()
		KogMaw:__init()
	end
end

if myHero.charName == "Kalista" then 
	local Scriptname,Version,Author,LVersion = "TRUSt in my Kalista","v1.3","TRUS","10.3"
	local Kalista = {}
	Kalista.__index = Kalista
	require "DamageLib"
	local chainedally = nil
	local barHeight = 8
	local barWidth = 103
	local barXOffset = 24
	local barYOffset = -8
	
	if FileExist(COMMON_PATH .. "PremiumPrediction.lua") then
		require 'PremiumPrediction'
		PrintChat("PremiumPrediction library loaded")
	end
	JungleHpBarOffset = {
		["SRU_Dragon_Water"] = {Width = 140, Height = 4, XOffset = -9, YOffset = -60},
		["SRU_Dragon_Fire"] = {Width = 140, Height = 4, XOffset = -9, YOffset = -60},
		["SRU_Dragon_Earth"] = {Width = 140, Height = 4, XOffset = -9, YOffset = -60},
		["SRU_Dragon_Air"] = {Width = 140, Height = 4, XOffset = -9, YOffset = -60},
		["SRU_Dragon_Elder"] = {Width = 140, Height = 4, XOffset = 11, YOffset = -142},
		["SRU_Baron"] = {Width = 190, Height = 10, XOffset = 16, YOffset = 24},
		["SRU_RiftHerald"] = {Width = 139, Height = 6, XOffset = 12, YOffset = 22},
		["SRU_Red"] = {Width = 139, Height = 4, XOffset = -7, YOffset = -19},
		["SRU_Blue"] = {Width = 139, Height = 4, XOffset = -14, YOffset = -38},
		["SRU_Gromp"] = {Width = 86, Height = 2, XOffset = 16, YOffset = -28},
		["Sru_Crab"] = {Width = 61, Height = 2, XOffset = 37, YOffset = -8},
		["SRU_Krug"] = {Width = 79, Height = 2, XOffset = 22, YOffset = -30},
		["SRU_Razorbeak"] = {Width = 74, Height = 2, XOffset = 15, YOffset = -23},
		["SRU_Murkwolf"] = {Width = 74, Height = 2, XOffset = 24, YOffset = -30}
	}
	
	
	function Kalista:__init()
		if not TRUStinMyMarksmanloaded then TRUStinMyMarksmanloaded = true else return end
		self:LoadSpells()
		self:LoadMenu()
		Callback.Add("Tick", function() self:Tick() end)
		Callback.Add("Draw", function() self:Draw() end)
		local orbwalkername = ""
		if _G.SDK then
			orbwalkername = "IC'S orbwalker"	
			_G.SDK.Orbwalker:OnPostAttack(function() 
				local combomodeactive = _G.SDK.Orbwalker.Modes[_G.SDK.ORBWALKER_MODE_COMBO]
				local harassactive = _G.SDK.Orbwalker.Modes[_G.SDK.ORBWALKER_MODE_HARASS]
				local QMinMana = self.Menu.Combo.qMinMana:Value()
				if (combomodeactive or harassactive) then	
					if (harassactive or (myHero.maxMana * QMinMana * 0.01 < myHero.mana)) then
						self:CastQ(_G.SDK.Orbwalker:GetTarget(),combomodeactive or false)
					end
				end
			end)
		elseif _G.EOW then
			orbwalkername = "EOW"	
			_G.EOW:AddCallback(_G.EOW.AfterAttack, function() self:DelayedQ() end)
		elseif _G.GOS then
			orbwalkername = "Noddy orbwalker"
			_G.GOS:OnAttackComplete(function() 
				local combomodeactive = _G.GOS:GetMode() == "Combo"
				local harassactive = _G.GOS:GetMode() == "Harass"
				local QMinMana = self.Menu.Combo.qMinMana:Value()
				if (combomodeactive or harassactive) then
					if (harassactive or (myHero.maxMana * QMinMana * 0.01 < myHero.mana)) then
						self:CastQ(_G.GOS:GetTarget(),combomodeactive or false)
					end
				end
			end)
		else
			orbwalkername = "Orbwalker not found"
			
		end
		PrintChat(Scriptname.." "..Version.." - Loaded...."..orbwalkername)
	end
	function Kalista:DelayedQ()
		DelayAction(function() 
			local combomodeactive = _G.EOW:Mode() == 1
			local harassactive = _G.EOW:Mode() == 2
			local QMinMana = self.Menu.Combo.qMinMana:Value()
			if (combomodeactive or harassactive) then
				if (harassactive or (myHero.maxMana * QMinMana * 0.01 < myHero.mana)) then
					self:CastQ(_G.EOW:GetTarget(),combomodeactive or false)
				end
			end
		end, 0.05)
	end
	--[[Spells]]
	function Kalista:LoadSpells()
		Q = {Range = 1150, Width = 40, Delay = 0.25, Speed = 2100}
		E = {Range = 1000}
	end
	
	function Kalista:LoadMenu()
		self.Menu = MenuElement({type = MENU, id = "TRUStinymyKalista", name = Scriptname})
		
		--[[Combo]]
		self.Menu:MenuElement({id = "UseBOTRK", name = "Use botrk", value = true})
		self.Menu:MenuElement({id = "AlwaysKS", name = "Always KS with E", value = true})
		
		self.Menu:MenuElement({type = MENU, id = "Runes", name = "Runes Settings"})
		self.Menu.Runes:MenuElement({id = "PrecisionCombatR", name = "Precision Combat Rune", drop = {"None", "Coup de Grace", "Cut Down", "Last Stand"}})
		
		self.Menu:MenuElement({type = MENU, id = "Combo", name = "Combo Settings"})
		self.Menu.Combo:MenuElement({id = "comboUseQ", name = "Use Q", value = true})
		self.Menu.Combo:MenuElement({id = "qMinMana", name = "Minimal mana for Q:", value = 30, min = 0, max = 101, identifier = "%"})
		self.Menu.Combo:MenuElement({id = "comboUseE", name = "Use E", value = true})
		
		--[[UseR]]
		self.Menu:MenuElement({type = MENU, id = "RLogic", name = "AutoR Settings"})
		self.Menu.RLogic:MenuElement({id = "Active", name = "Active", value = true})
		self.Menu.RLogic:MenuElement({id = "RMaxHealth", name = "Health for AutoR:", value = 30, min = 0, max = 100, identifier = "%"})
		
		--[[LastHit]]
		self.Menu:MenuElement({type = MENU, id = "AutLastHit", name = "LastHit E settings"})
		self.Menu.AutLastHit:MenuElement({id = "Active", name = "Always active", value = true})
		self.Menu.AutLastHit:MenuElement({id = "keyActive", name = "Activation key", key = string.byte(" ")})
		self.Menu.AutLastHit:MenuElement({id = "MinTargets", name = "Min creeps:", value = 1, min = 0, max = 5})
		
		--[[Draw]]
		self.Menu:MenuElement({type = MENU, id = "Draw", name = "Draw Settings"})
		self.Menu.Draw:MenuElement({id = "DrawEDamage", name = "Draw number health after E", value = true})
		self.Menu.Draw:MenuElement({id = "DrawEBarDamage", name = "On hpbar after E", value = true})
		--self.Menu.Draw:MenuElement({id = "HPBarOffset", name = "Z offset for HPBar ", value = 0, min = -100, max = 100, tooltip = "change this if damage showed in wrong position"})
		--self.Menu.Draw:MenuElement({id = "HPBarOffsetX", name = "X offset for HPBar ", value = 0, min = -100, max = 100, tooltip = "change this if damage showed in wrong position"})
		self.Menu.Draw:MenuElement({id = "DrawInPrecent", name = "Draw numbers in percent", value = true})
		self.Menu.Draw:MenuElement({id = "DrawE", name = "Draw heroes Killable with E", value = true})
		self.Menu.Draw:MenuElement({id = "DrawLastHit", name = "Draw minion Killable with E", value = true})
		self.Menu.Draw:MenuElement({id = "TextOffset", name = "Z offset for text ", value = 0, min = -100, max = 100})
		self.Menu.Draw:MenuElement({id = "TextSize", name = "Font size ", value = 30, min = 2, max = 64})
		self.Menu.Draw:MenuElement({id = "DrawColor", name = "Color for drawing", color = Draw.Color(0xBF3F3FFF)})
		
		--[[Harass]]
		self.Menu:MenuElement({type = MENU, id = "Harass", name = "Harass Settings"})
		self.Menu.Harass:MenuElement({id = "harassUseQ", name = "Use Q", value = true})
		self.Menu.Harass:MenuElement({id = "harassUseELasthit", name = "Use E Harass when lasthit", value = true})
		self.Menu.Harass:MenuElement({id = "HarassMinEStacksLH", name = "Min E stacks (LastHit): ", value = 3, min = 0, max = 10})
		self.Menu.Harass:MenuElement({id = "harassUseERange", name = "Use E when out of range", value = true})
		self.Menu.Harass:MenuElement({id = "HarassMinEStacks", name = "Min E stacks (Range): ", value = 3, min = 0, max = 10})
		self.Menu.Harass:MenuElement({id = "harassMana", name = "Minimal mana percent:", value = 30, min = 0, max = 101, identifier = "%"})
		
		self.Menu:MenuElement({type = MENU, id = "SmiteMarker", name = "AutoE Jungle"})
		self.Menu.SmiteMarker:MenuElement({id = "Enabled", name = "Enabled", key = string.byte("K"), toggle = true})
		self.Menu.SmiteMarker:MenuElement({id = "MarkBaron", name = "Baron", value = true, leftIcon = "http://puu.sh/rPuVv/933a78e350.png"})
		self.Menu.SmiteMarker:MenuElement({id = "MarkHerald", name = "Herald", value = true, leftIcon = "http://puu.sh/rQs4A/47c27fa9ea.png"})
		self.Menu.SmiteMarker:MenuElement({id = "MarkDragon", name = "Dragon", value = true, leftIcon = "http://puu.sh/rPvdF/a00d754b30.png"})
		self.Menu.SmiteMarker:MenuElement({id = "MarkBlue", name = "Blue Buff", value = true, leftIcon = "http://puu.sh/rPvNd/f5c6cfb97c.png"})
		self.Menu.SmiteMarker:MenuElement({id = "MarkRed", name = "Red Buff", value = true, leftIcon = "http://puu.sh/rPvQs/fbfc120d17.png"})
		self.Menu.SmiteMarker:MenuElement({id = "MarkGromp", name = "Gromp", value = true, leftIcon = "http://puu.sh/rPvSY/2cf9ff7a8e.png"})
		self.Menu.SmiteMarker:MenuElement({id = "MarkWolves", name = "Wolves", value = true, leftIcon = "http://puu.sh/rPvWu/d9ae64a105.png"})
		self.Menu.SmiteMarker:MenuElement({id = "MarkRazorbeaks", name = "Razorbeaks", value = true, leftIcon = "http://puu.sh/rPvZ5/acf0e03cc7.png"})
		self.Menu.SmiteMarker:MenuElement({id = "MarkKrugs", name = "Krugs", value = true, leftIcon = "http://puu.sh/rPw6a/3096646ec4.png"})
		self.Menu.SmiteMarker:MenuElement({id = "MarkCrab", name = "Crab", value = true, leftIcon = "http://puu.sh/rPwaw/10f0766f4d.png"})
		
		
		self.Menu:MenuElement({type = MENU, id = "SmiteDamage", name = "Draw damage in Jungle"})
		self.Menu.SmiteDamage:MenuElement({id = "Enabled", name = "Display text", value = true})
		self.Menu.SmiteDamage:MenuElement({id = "EnabledHPBar", name = "Display on HPBar", value = true})
		self.Menu.SmiteDamage:MenuElement({id = "MarkBaron", name = "Baron", value = true, leftIcon = "http://puu.sh/rPuVv/933a78e350.png"})
		self.Menu.SmiteDamage:MenuElement({id = "MarkHerald", name = "Herald", value = true, leftIcon = "http://puu.sh/rQs4A/47c27fa9ea.png"})
		self.Menu.SmiteDamage:MenuElement({id = "MarkDragon", name = "Dragon", value = true, leftIcon = "http://puu.sh/rPvdF/a00d754b30.png"})
		self.Menu.SmiteDamage:MenuElement({id = "MarkBlue", name = "Blue Buff", value = true, leftIcon = "http://puu.sh/rPvNd/f5c6cfb97c.png"})
		self.Menu.SmiteDamage:MenuElement({id = "MarkRed", name = "Red Buff", value = true, leftIcon = "http://puu.sh/rPvQs/fbfc120d17.png"})
		self.Menu.SmiteDamage:MenuElement({id = "MarkGromp", name = "Gromp", value = true, leftIcon = "http://puu.sh/rPvSY/2cf9ff7a8e.png"})
		self.Menu.SmiteDamage:MenuElement({id = "MarkWolves", name = "Wolves", value = true, leftIcon = "http://puu.sh/rPvWu/d9ae64a105.png"})
		self.Menu.SmiteDamage:MenuElement({id = "MarkRazorbeaks", name = "Razorbeaks", value = true, leftIcon = "http://puu.sh/rPvZ5/acf0e03cc7.png"})
		self.Menu.SmiteDamage:MenuElement({id = "MarkKrugs", name = "Krugs", value = true, leftIcon = "http://puu.sh/rPw6a/3096646ec4.png"})
		self.Menu.SmiteDamage:MenuElement({id = "MarkCrab", name = "Crab", value = true, leftIcon = "http://puu.sh/rPwaw/10f0766f4d.png"})
		
		
		if (_G.PremiumPrediction:Loaded()) then
			
			self.Menu:MenuElement({id = "PremPredminchance", name = "PremPr Minimal hitchance", value = 1, min = 1, max = 100, step = 1, identifier = ""})
		end
		self.Menu:MenuElement({id = "CustomSpellCast", name = "Use custom spellcast", tooltip = "Can fix some casting problems with wrong directions and so (thx Noddy for this one)", value = true})
		self.Menu:MenuElement({id = "delay", name = "Custom spellcast delay", value = 50, min = 0, max = 200, step = 5, identifier = ""})
		
		self.Menu:MenuElement({id = "blank", type = SPACE , name = ""})
		self.Menu:MenuElement({id = "blank", type = SPACE , name = "Script Ver: "..Version.. " - LoL Ver: "..LVersion.. "" .. (_G.PremiumPrediction:Loaded() and " PremiumPr" or "")})
		self.Menu:MenuElement({id = "blank", type = SPACE , name = "by "..Author.. ""})
	end
	
	
	function Kalista:ChainedAlly()
		for i = 1, Game.HeroCount() do
			local hero = Game.Hero(i)
			if self:HasBuff(hero,"kalistacoopstrikeally") then
				chainedally = hero
			end
		end	
	end
	
	
	
	function Kalista:Tick()
		if myHero.dead or (not _G.SDK and not _G.GOS) then return end
		if not chainedally then self:ChainedAlly() end 
		
		local combomodeactive, harassactive, canmove, canattack, currenttarget = CurrentModes()
		local HarassMinMana = self.Menu.Harass.harassMana:Value()
		local QMinMana = self.Menu.Combo.qMinMana:Value()
		
		if combomodeactive and self.Menu.UseBOTRK:Value() then
			UseBotrk()
		end
		if ((combomodeactive) or (harassactive and myHero.maxMana * HarassMinMana * 0.01 < myHero.mana)) then
			if (harassactive or (myHero.maxMana * QMinMana * 0.01 < myHero.mana)) and not currenttarget then
				self:CastQ(currenttarget,combomodeactive or false)
			end
			if (not canattack or not currenttarget) and self.Menu.Combo.comboUseE:Value() then
				self:CastE(currenttarget,combomodeactive or false)
			end
		end
		
		if self.Menu.AlwaysKS:Value() then
			self:CastE(false,combomodeactive or false)
		end
		if self:CanCast(_E) then 
			if harassactive and self.Menu.Harass.harassUseELasthit:Value() then
				self:UseEOnLasthit()
			end
			if self.Menu.AutLastHit.Active:Value() or self.Menu.AutLastHit.keyActive:Value() or self.Menu.Draw.DrawLastHit:Value() then
				self:LastHitCreeps()
			end
		end
		if (harassactive) and self:CanCast(_E) and not canattack then
			if self.Menu.Harass.harassUseERange:Value() then 
				self:UseERange()
			end
		end
		
		
		if self.Menu.RLogic.Active:Value() and chainedally and self:CanCast(_R) then
			if chainedally.health/chainedally.maxHealth <= self.Menu.RLogic.RMaxHealth:Value()/100 and self:EnemyInRange(chainedally.pos,500) > 0 then
				Control.CastSpell(HK_R)
			end
		end
		
	end
	
	function EnableMovement()
		--unblock movement
		SetMovement(true)
	end
	
	function ReturnCursor(pos)
		Control.SetCursorPos(pos)
		Control.mouse_event(MOUSEEVENTF_RIGHTDOWN)
		Control.mouse_event(MOUSEEVENTF_RIGHTUP)
		DelayAction(EnableMovement,0.1)
	end
	
	function LeftClick(pos)
		Control.mouse_event(MOUSEEVENTF_LEFTDOWN)
		Control.mouse_event(MOUSEEVENTF_LEFTUP)
		DelayAction(ReturnCursor,0.05,{pos})
	end
	
	function Kalista:CastSpell(spell,pos)
		local customcast = self.Menu.CustomSpellCast:Value()
		if not customcast then
			Control.CastSpell(spell, pos)
			return
		else
			local delay = self.Menu.delay:Value()
			local ticker = GetTickCount()
			if castSpell.state == 0 and ticker > castSpell.casting then
				castSpell.state = 1
				castSpell.mouse = mousePos
				castSpell.tick = ticker
				if ticker - castSpell.tick < Game.Latency() then
					--block movement
					SetMovement(false)
					Control.SetCursorPos(pos)
					Control.KeyDown(spell)
					Control.KeyUp(spell)
					DelayAction(LeftClick,delay/1000,{castSpell.mouse})
					castSpell.casting = ticker + 500
				end
			end
		end
	end
	
	local SmiteTable = {
		SRU_Baron = "MarkBaron",
		SRU_RiftHerald = "MarkHerald",
		SRU_Dragon_Water = "MarkDragon",
		SRU_Dragon_Fire = "MarkDragon",
		SRU_Dragon_Earth = "MarkDragon",
		SRU_Dragon_Air = "MarkDragon",
		SRU_Dragon_Elder = "MarkDragon",
		SRU_Blue = "MarkBlue",
		SRU_Red = "MarkRed",
		SRU_Gromp = "MarkGromp",
		SRU_Murkwolf = "MarkWolves",
		SRU_Razorbeak = "MarkRazorbeaks",
		SRU_Krug = "MarkKrugs",
		Sru_Crab = "MarkCrab",
	}
	local killableminions = {}
	function Kalista:LastHitCreeps()
		local minionlist = {}
		local lhcount = 0
		killableminions = {}
		if _G.SDK then
			minionlist = _G.SDK.ObjectManager:GetEnemyMinions(E.Range)
			for i, minion in pairs(minionlist) do
				if minion.valid and minion.isEnemy and self:GetSpears(minion) > 0 then 
					local EDamage = getdmg("E",minion,myHero) 
					if EDamage > minion.health then
						lhcount = lhcount + 1
						if self.Menu.Draw.DrawLastHit:Value() then
							table.insert(killableminions, minion)
						end
					end
				end
			end
		elseif _G.GOS then
			for i = 1, Game.MinionCount() do
				local minion = Game.Minion(i)
				if minion.valid and minion.isEnemy and self:GetSpears(minion) > 0 then 
					local EDamage = getdmg("E",minion,myHero) 
					if EDamage > minion.health then
						lhcount = lhcount + 1
						if self.Menu.Draw.DrawLastHit:Value() then
							table.insert(killableminions, minion)
						end
					end
				end
			end
		end
		if (self.Menu.AutLastHit.Active:Value() or self.Menu.keyActive.Active:Value()) and lhcount >= self.Menu.AutLastHit.MinTargets:Value() then
			Control.CastSpell(HK_E)
		end
	end
	function Kalista:DrawDamageMinion(type, minion, damage)
		if not type or not self.Menu.SmiteDamage[type] then
			return
		end
		
		
		if self.Menu.SmiteDamage[type]:Value() then
			
			if self.Menu.SmiteDamage.Enabled:Value() then
				local offset = self.Menu.Draw.TextOffset:Value()
				local fontsize = self.Menu.Draw.TextSize:Value()
				local InPercents = self.Menu.Draw.DrawInPrecent:Value()
				local healthremaining = InPercents and math.floor((minion.health - damage)/minion.maxHealth*100).."%" or math.floor(minion.health - damage,1)
				Draw.Text(healthremaining, fontsize, minion.pos2D.x, minion.pos2D.y+offset,self.Menu.Draw.DrawColor:Value())
			end
			
			if self.Menu.SmiteDamage.EnabledHPBar:Value() then 
				local barPos = minion.hpBar
				if barPos.onScreen then
					local damage = damage
					local percentHealthAfterDamage = math.max(0, minion.health - damage) / minion.maxHealth
					local BarWidth = JungleHpBarOffset[minion.charName]["Width"]
					local BarHeight = JungleHpBarOffset[minion.charName]["Height"]
					local YOffset = JungleHpBarOffset[minion.charName]["YOffset"]
					local XOffset = JungleHpBarOffset[minion.charName]["XOffset"]
					local XPosStart = barPos.x + XOffset + BarWidth * 0
					local xPosEnd = barPos.x + XOffset + BarWidth * percentHealthAfterDamage
					
					Draw.Line(XPosStart, barPos.y + YOffset,xPosEnd, barPos.y + YOffset, BarHeight, self.Menu.Draw.DrawColor:Value())
				end
			end
			
		end
		
	end
	
	function Kalista:DrawSmiteableMinion(type,minion)
		if not type or not self.Menu.SmiteMarker[type] then
			return
		end
		if self.Menu.SmiteMarker[type]:Value() then
			if minion.pos2D.onScreen then
				Draw.Circle(minion.pos,minion.boundingRadius,6,Draw.Color(0xFF00FF00));
			end
			if self:CanCast(_E) then
				Control.CastSpell(HK_E)
			end
		end
	end
	function Kalista:HasBuff(unit, buffname)
		for K, Buff in pairs(self:GetBuffs(unit)) do
			if Buff.name:lower() == buffname:lower() then
				return Buff.expireTime
			end
		end
		return false
	end
	
	
	function Kalista:CheckKillableMinion()
		local minionlist = {}
		if _G.SDK then
			minionlist = _G.SDK.ObjectManager:GetMonsters(E.Range)
		elseif _G.GOS then
			for i = 1, Game.MinionCount() do
				local minion = Game.Minion(i)
				if minion.valid and minion.isEnemy and minion.pos:DistanceTo(myHero.pos) < E.Range then
					table.insert(minionlist, minion)
				end
			end
		end
		for i, minion in pairs(minionlist) do
			if self:GetSpears(minion) > 0 then 
				local EDamage = getdmg("E",minion,myHero)
				local minionName = minion.charName
				EDamage = EDamage*(((minion.charName == "SRU_RiftHerald" or minion.charName == "SRU_Baron" or string.find(minion.charName, "ragon")) and 0.45) or (self:HasBuff(myHero,"barontarget") and 0.5) or 1)
				if EDamage > minion.health then
					local minionName = minion.charName
					self:DrawSmiteableMinion(SmiteTable[minionName], minion)
				else
					self:DrawDamageMinion(SmiteTable[minionName], minion, EDamage)
				end
			end
		end
	end
	function Kalista:GetBuffs(unit)
		self.T = {}
		for i = 0, unit.buffCount do
			local Buff = unit:GetBuff(i)
			if Buff.count > 0 then
				table.insert(self.T, Buff)
			end
		end
		return self.T
	end
	
	function Kalista:GetSpears(unit, buffname)
		for K, Buff in pairs(self:GetBuffs(unit)) do
			if Buff.name:lower() == "kalistaexpungemarker" then
				return Buff.count
			end
		end
		return 0
	end
	
	function Kalista:UseERange()
		local heroeslist = (_G.SDK and _G.SDK.ObjectManager:GetEnemyHeroes(1100)) or self:GetEnemyHeroes()
		local target = (_G.SDK and _G.SDK.TargetSelector.SelectedTarget) or (_G.EOW and _G.EOW:GetTarget()) or (_G.GOS and _G.GOS:GetTarget())
		if target then return end 
		for i, hero in pairs(heroeslist) do
			if self:GetSpears(hero) >= self.Menu.Harass.HarassMinEStacks:Value() then
				if myHero.pos:DistanceTo(hero.pos)<1000 and myHero.pos:DistanceTo(hero:GetPrediction(math.huge,0.25)) > 900 then
					Control.CastSpell(HK_E)
				end
			end
		end
	end
	
	function Kalista:UseEOnLasthit()
		local heroeslist = (_G.SDK and _G.SDK.ObjectManager:GetEnemyHeroes(1100)) or self:GetEnemyHeroes()
		local useE = false
		local minionlist = {}
		
		for i, hero in pairs(heroeslist) do
			if self:GetSpears(hero) >= self.Menu.Harass.HarassMinEStacksLH:Value() then
				if _G.SDK then
					minionlist = _G.SDK.ObjectManager:GetEnemyMinions(E.Range)
				elseif _G.GOS then
					for i = 1, Game.MinionCount() do
						local minion = Game.Minion(i)
						if minion.valid and minion.isEnemy and minion.pos:DistanceTo(myHero.pos) < E.Range then
							table.insert(minionlist, minion)
						end
					end
				end
				
				for i, minion in pairs(minionlist) do
					local spearsamount = self:GetSpears(minion)
					if spearsamount > 0 then 
						local EDamage = getdmg("E",minion,myHero)
						-- local basedmg = ({20, 30, 40, 50, 60})[level] + 0.6* (myHero.totalDamage)
						-- local perspear = ({10, 14, 19, 25, 32})[level] + ({0.2, 0.225, 0.25, 0.275, 0.3})[level]* (myHero.totalDamage)
						-- local tempdamage = basedmg + perspear*spearsamount
						if EDamage > minion.health then
							Control.CastSpell(HK_E)
						end
					end
				end
			end
		end
	end
	
	function Kalista:EnemyInRange(source,radius)
		local count = 0
		if not source then return end
		local heroeslist = (_G.SDK and _G.SDK.ObjectManager:GetEnemyHeroes(1700)) or self:GetEnemyHeroes()
		for i, target in ipairs(heroeslist) do
			if target.pos:DistanceTo(source) < radius then 
				count = count + 1
			end
		end
		return count
	end
	
	function Kalista:GetEnemyHeroes()
		self.EnemyHeroes = {}
		for i = 1, Game.HeroCount() do
			local Hero = Game.Hero(i)
			if Hero.isEnemy and Hero.isTargetable then
				table.insert(self.EnemyHeroes, Hero)
			end
		end
		return self.EnemyHeroes
	end
	local DamageModifiersTable = {
		summonerexhaustdebuff = 0.6,
		itemphantomdancerdebuff = 0.88,
		itemsmiteburn = 0.8
	}
	
	local DamageModifiersTableEnemies = {
		fioraw = 0,
		undyingrage = 0,
		kindredrnodeathbuff = 0,
		taricr = 0,
		judicatorintervention = 0
	}
	
	function Kalista:DamageModifiers(target)
		local currentpercent = 1
		for K, Buff in pairs(self:GetBuffs(myHero)) do
			if DamageModifiersTable[Buff.name:lower()] then
				currentpercent = currentpercent*DamageModifiersTable[Buff.name:lower()]
			end
		end
		for K, Buff in pairs(self:GetBuffs(target)) do
			if Buff.name and DamageModifiersTableEnemies[Buff.name:lower()] then
				return 0 
			end
			if Buff.count > 0 and Buff.name and string.find(Buff.name, "PressTheAttack") and (Buff.expireTime - Buff.startTime == 6) then
				currentpercent = currentpercent * 1.12
			end
		end
		local PrecisionCombatRune = self.Menu.Runes.PrecisionCombatR:Value()
		if PrecisionCombatRune == 2 then
			if target.health/target.maxHealth < 0.4 then
				currentpercent = currentpercent * 1.07
			end
		elseif PrecisionCombatRune == 3 then
			local healthdifference = target.maxHealth - myHero.maxHealth
			if healthdifference > 2000 then
				currentpercent = currentpercent * 1.10
			elseif healthdifference > 1691 then
				currentpercent = currentpercent * 1.09
			elseif healthdifference > 1383 then
				currentpercent = currentpercent * 1.08
			elseif healthdifference > 1075 then
				currentpercent = currentpercent * 1.07
			elseif healthdifference > 766 then
				currentpercent = currentpercent * 1.06
			elseif healthdifference > 458 then
				currentpercent = currentpercent * 1.05
			elseif healthdifference > 150 then
				currentpercent = currentpercent * 1.04
			end
		elseif PrecisionCombatRune == 4 then
			local missinghealth = 1 - myHero.health/myHero.maxHealth
			local calculatebonus = missinghealth < 0.4 and 1 or (1.05 + (math.floor(missinghealth*10 - 4)*0.02))
			currentpercent = currentpercent * (calculatebonus < 1.12 and calculatebonus or 1.11)
		end
		return currentpercent
	end
	function Kalista:GetETarget()
		self.KillableHeroes = {}
		self.DamageHeroes = {}
		local heroeslist = (_G.SDK and _G.SDK.ObjectManager:GetEnemyHeroes(1200)) or self:GetEnemyHeroes()
		local level = myHero:GetSpellData(_E).level
		for i, hero in pairs(heroeslist) do
			if self:GetSpears(hero) > 0 and myHero.pos:DistanceTo(hero.pos)<E.Range then 
				local EDamage = getdmg("E",hero,myHero)
				local damagemods = self:DamageModifiers(hero)
				EDamage = EDamage * damagemods
				if hero.health and EDamage and EDamage > hero.health then
					table.insert(self.KillableHeroes, hero)
				else
					table.insert(self.DamageHeroes, {hero = hero, damage = EDamage})
				end
			end
		end
		return self.KillableHeroes, self.DamageHeroes
	end
	
	--[[CastQ]]
	function Kalista:CastQ(target, combo)
		if (not _G.SDK and not _G.GOS) then return end
		local target = target or (_G.SDK and _G.SDK.TargetSelector:GetTarget(Q.Range, _G.SDK.DAMAGE_TYPE_PHYSICAL)) or (_G.GOS and _G.GOS:GetTarget(Q.Range,"AD"))
		if target and target.type == "AIHeroClient" and self:CanCast(_Q) and ((combo and self.Menu.Combo.comboUseQ:Value()) or (combo == false and self.Menu.Harass.harassUseQ:Value())) then
			local castPos
			if (_G.PremiumPrediction:Loaded()) then
				local spellData = {speed = Q.Speed, range = Q.Range, delay = Q.Delay, radius = Q.Width, collision = {"minion"}, type = "linear"}
				local pred = _G.PremiumPrediction:GetPrediction(myHero, target, spellData)
				if pred.CastPos and pred.HitChance >= self.Menu.PremPredminchance:Value()/100 then
					self:CastSpell(HK_Q, pred.CastPos)
				end
			elseif target:GetCollision(Q.Width,Q.Speed,Q.Delay) == 0 then
				castPos = target:GetPrediction(Q.Speed,Q.Delay)
				self:CastSpell(HK_Q, castPos)
			end
		end
	end
	
	
	--[[CastE]]
	function Kalista:CastE(target,combo)
		local killable, damaged = self:GetETarget()
		if self:CanCast(_E) and #killable > 0 then
			Control.CastSpell(HK_E)
		end
	end
	
	
	
	function Kalista:IsReady(spellSlot)
		return myHero:GetSpellData(spellSlot).currentCd == 0 and myHero:GetSpellData(spellSlot).level > 0
	end
	
	function Kalista:CheckMana(spellSlot)
		return myHero:GetSpellData(spellSlot).mana < myHero.mana
	end
	
	function Kalista:CanCast(spellSlot)
		return self:IsReady(spellSlot) and self:CheckMana(spellSlot)
	end
	
	function Kalista:Draw()
		if self.Menu.SmiteMarker.Enabled:Value() then
			self:CheckKillableMinion()
		end
		if self.Menu.Draw.DrawLastHit:Value() then
			for i, minion in pairs(killableminions) do
				Draw.Circle(minion.pos, minion.boundingRadius, 6, self.Menu.Draw.DrawColor:Value())
			end
		end
		local killable, damaged = self:GetETarget()
		local offset = self.Menu.Draw.TextOffset:Value()
		local fontsize = self.Menu.Draw.TextSize:Value()
		local InPercents = self.Menu.Draw.DrawInPrecent:Value()
		if self.Menu.Draw.DrawE:Value() then
			for i, hero in pairs(killable) do
				Draw.Circle(hero.pos, 80, 6, self.Menu.Draw.DrawColor:Value())
				Draw.Text("killable", fontsize, hero.pos2D.x, hero.pos2D.y+offset,self.Menu.Draw.DrawColor:Value())
			end	
		end
		if self.Menu.Draw.DrawEDamage:Value() or self.Menu.Draw.DrawEBarDamage:Value()then
			for i, hero in pairs(damaged) do
				if self.Menu.Draw.DrawEBarDamage:Value() then 
					local barPos = hero.hero.hpBar
					if barPos.onScreen then
						--local barYOffset = self.Menu.Draw.HPBarOffset:Value()
						--local barXOffset = self.Menu.Draw.HPBarOffsetX:Value()
						local damage = hero.damage
						local percentHealthAfterDamage = math.max(0, hero.hero.health - damage) / hero.hero.maxHealth
						local xPosEnd = barPos.x + barXOffset + barWidth * hero.hero.health/hero.hero.maxHealth
						local xPosStart = barPos.x + barXOffset + percentHealthAfterDamage * 100
						Draw.Line(xPosStart, barPos.y + barYOffset, xPosEnd, barPos.y + barYOffset, 12, self.Menu.Draw.DrawColor:Value())
					end
				end
				if self.Menu.Draw.DrawEDamage:Value() then 
					local healthremaining = InPercents and math.floor((hero.hero.health - hero.damage)/hero.hero.maxHealth*100).."%" or math.floor(hero.hero.health - hero.damage,1)
					Draw.Text(healthremaining, fontsize, hero.hero.pos2D.x, hero.hero.pos2D.y+offset,self.Menu.Draw.DrawColor:Value())
				end
			end
		end
	end
	
	function OnLoad()
		Kalista:__init()
	end
end


if myHero.charName == "Sivir" then 
	local Scriptname,Version,Author,LVersion = "TRUSt in my Sivir","v1.1","TRUS","10.3"
	local Sivir = {}
	Sivir.__index = Sivir
	
	function Sivir:__init()
		if not TRUStinMyMarksmanloaded then TRUStinMyMarksmanloaded = true else return end
		self:LoadMenu()
		local orbwalkername = ""
		if _G.SDK then
			orbwalkername = "IC'S orbwalker"	
			
			_G.SDK.Orbwalker:OnPostAttack(function() 
				local combomodeactive = _G.SDK.Orbwalker.Modes[_G.SDK.ORBWALKER_MODE_COMBO]
				local harassactive = _G.SDK.Orbwalker.Modes[_G.SDK.ORBWALKER_MODE_HARASS]
				if (combomodeactive or harassactive) and self:CanCast(_W) and self.Menu.UseW:Value() then
					Control.CastSpell(HK_W)
				end
			end)
		elseif _G.EOW then
			orbwalkername = "EOW"	
		elseif _G.GOS then
			orbwalkername = "Noddy orbwalker"
			_G.GOS:OnAttackComplete(function() 
				local combomodeactive = _G.GOS:GetMode() == "Combo"
				local harassactive = _G.GOS:GetMode() == "Harass"
				local QMinMana = self.Menu.Combo.qMinMana:Value()	
				if (combomodeactive or harassactive) and self:CanCast(_W) and self.Menu.UseW:Value() then
					Control.CastSpell(HK_W)
				end
			end)
		else
			orbwalkername = "Orbwalker not found"
			
		end
		PrintChat(Scriptname.." "..Version.." - Loaded...."..orbwalkername)
	end
	
	
	function Sivir:LoadMenu()
		self.Menu = MenuElement({type = MENU, id = "TRUStinymySivir", name = Scriptname})
		
		--[[Combo]]
		self.Menu:MenuElement({id = "UseW", name = "Use W", value = true})
		
		
		self.Menu:MenuElement({id = "blank", type = SPACE , name = ""})
		self.Menu:MenuElement({id = "blank", type = SPACE , name = "Script Ver: "..Version.. " - LoL Ver: "..LVersion.. "" .. (_G.PremiumPrediction:Loaded() and " PremiumPr" or "")})
		self.Menu:MenuElement({id = "blank", type = SPACE , name = "by "..Author.. ""})
	end
	
	function Sivir:IsReady(spellSlot)
		return myHero:GetSpellData(spellSlot).currentCd == 0 and myHero:GetSpellData(spellSlot).level > 0
	end
	
	function Sivir:CheckMana(spellSlot)
		return myHero:GetSpellData(spellSlot).mana < myHero.mana
	end
	
	function Sivir:CanCast(spellSlot)
		return self:IsReady(spellSlot) and self:CheckMana(spellSlot)
	end
	
	function OnLoad()
		Sivir:__init()
	end
end

if myHero.charName == "Corki" then
	local Corki = {}
	Corki.__index = Corki
	local Scriptname,Version,Author,LVersion = "TRUSt in my Corki","v1.2","TRUS","10.3"
	
	if FileExist(COMMON_PATH .. "PremiumPrediction.lua") then
		require 'PremiumPrediction'
		PrintChat("PremiumPrediction library loaded")
	end
	
	local EPrediction = {}
	
	function Corki:__init()
		if not TRUStinMyMarksmanloaded then TRUStinMyMarksmanloaded = true else return end
		self:LoadSpells()
		self:LoadMenu()
		Callback.Add("Tick", function() self:Tick() end)
		
		local orbwalkername = ""
		if _G.SDK then
			orbwalkername = "IC'S orbwalker"
			_G.SDK.Orbwalker:OnPostAttack(function() 
				local combomodeactive = _G.SDK.Orbwalker.Modes[_G.SDK.ORBWALKER_MODE_COMBO]
				local harassactive = _G.SDK.Orbwalker.Modes[_G.SDK.ORBWALKER_MODE_HARASS]
				if (combomodeactive or harassactive) then
					self:CastQ(_G.SDK.TargetSelector.SelectedTarget or _G.SDK.Orbwalker:GetTarget(825,_G.SDK.DAMAGE_TYPE_MAGICAL),combomodeactive)
				end
			end)
		elseif _G.EOW then
			orbwalkername = "EOW"	
			_G.EOW:AddCallback(_G.EOW.AfterAttack, function() 
				local combomodeactive = _G.EOW:Mode() == 1
				local harassactive = _G.EOW:Mode() == 2
				if (combomodeactive or harassactive) then
					self:CastQ(_G.EOW:GetTarget(),combomodeactive)
				end
			end)
		elseif _G.GOS then
			orbwalkername = "Noddy orbwalker"
			_G.GOS:OnAttackComplete(function() 
				local combomodeactive = _G.GOS:GetMode() == "Combo"
				local harassactive = _G.GOS:GetMode() == "Harass"
				if (combomodeactive or harassactive) then
					self:CastQ(_G.GOS:GetTarget(),combomodeactive)
				end
			end)
		else
			orbwalkername = "Orbwalker not found"
			
		end
		PrintChat(Scriptname.." "..Version.." - Loaded...."..orbwalkername)
	end
	
	--[[Spells]]
	function Corki:LoadSpells()
		Q = {Range = 825, Width = 250, Delay = 0.3, Speed = 1000}
		R = {Range = 1300, Delay = 0.2, Width = 120, Speed = 2000}
		R2 = {Range = 1500, Delay = 0.2, Width = 120, Speed = 2000}
		E = {Range = 400}
		
		if TYPE_GENERIC then
			local QSpell = Prediction:SetSpell({range = Q.Range, speed = Q.Speed, delay = Q.Delay, width = Q.Width}, TYPE_CIRCULAR, true)
			EPrediction["Q"] = QSpell
			local RSpell = Prediction:SetSpell({range = R.Range, speed = R.Speed, delay = R.Delay, width = R.Width}, TYPE_LINE, true)
			EPrediction["R"] = RSpell
			local R2Spell = Prediction:SetSpell({range = R.Range, speed = R2.Speed, delay = R2.Delay, width = R2.Width}, TYPE_LINE, true)
			EPrediction["R2"] = R2Spell
			
		end
	end
	
	function Corki:LoadMenu()
		self.Menu = MenuElement({type = MENU, id = "TRUStinymyCorki", name = Scriptname})
		--[[Combo]]
		self.Menu:MenuElement({id = "UseBOTRK", name = "Use botrk", value = true})
		self.Menu:MenuElement({type = MENU, id = "Combo", name = "Combo Settings"})
		self.Menu.Combo:MenuElement({id = "comboUseQ", name = "Use Q", value = true})
		self.Menu.Combo:MenuElement({id = "comboUseE", name = "Use E", value = true})
		self.Menu.Combo:MenuElement({id = "comboUseR", name = "Use R", value = true})
		self.Menu.Combo:MenuElement({id = "MaxStacks", name = "Min R stacks: ", value = 0, min = 0, max = 7})
		self.Menu.Combo:MenuElement({id = "ManaW", name = "Save mana for W", value = true})
		
		--[[Harass]]
		self.Menu:MenuElement({type = MENU, id = "Harass", name = "Harass Settings"})
		self.Menu.Harass:MenuElement({id = "harassUseQ", name = "Use Q", value = true})
		self.Menu.Harass:MenuElement({id = "harassUseR", name = "Use R", value = true})
		self.Menu.Harass:MenuElement({id = "HarassMaxStacks", name = "Min R stacks: ", value = 3, min = 0, max = 7})
		self.Menu.Harass:MenuElement({id = "harassMana", name = "Minimal mana percent:", value = 30, min = 0, max = 101, identifier = "%"})
		
		if TYPE_GENERIC then
			self.Menu:MenuElement({id = "EternalUse", name = "Use eternal prediction", value = true})
			self.Menu:MenuElement({id = "minchance", name = "Minimal hitchance", value = 0.25, min = 0, max = 1, step = 0.05, identifier = ""})
		end
		if (_G.PremiumPrediction:Loaded()) then
			
			self.Menu:MenuElement({id = "PremPredminchance", name = "PremPr Minimal hitchance", value = 1, min = 1, max = 100, step = 1, identifier = ""})
		end
		self.Menu:MenuElement({id = "CustomSpellCast", name = "Use custom spellcast", tooltip = "Can fix some casting problems with wrong directions and so (thx Noddy for this one)", value = true})
		self.Menu:MenuElement({id = "delay", name = "Custom spellcast delay", value = 50, min = 0, max = 200, step = 5, identifier = ""})
		
		self.Menu:MenuElement({id = "blank", type = SPACE , name = ""})
		self.Menu:MenuElement({id = "blank", type = SPACE , name = "Script Ver: "..Version.. " - LoL Ver: "..LVersion.. "" .. (_G.PremiumPrediction:Loaded() and " PremiumPr" or "")})
		self.Menu:MenuElement({id = "blank", type = SPACE , name = "by "..Author.. ""})
	end
	
	function Corki:Tick()
		if myHero.dead or (not _G.SDK and not _G.GOS) then return end
		local combomodeactive, harassactive, canmove, canattack, currenttarget = CurrentModes()
		local HarassMinMana = self.Menu.Harass.harassMana:Value()
		
		
		if combomodeactive and self.Menu.UseBOTRK:Value() then
			UseBotrk()
		end
		
		if ((combomodeactive) or (harassactive and myHero.maxMana * HarassMinMana * 0.01 < myHero.mana)) and (canmove or not currenttarget) then
			self:CastQ(currenttarget,combomodeactive or false)
			if combomodeactive then
				self:CastE(currenttarget,true)
			end
			self:CastR(currenttarget,combomodeactive or false)
		end
	end
	
	function EnableMovement()
		SetMovement(true)
	end
	
	function ReturnCursor(pos)
		Control.SetCursorPos(pos)
		DelayAction(EnableMovement,0.1)
	end
	
	function LeftClick(pos)
		Control.mouse_event(MOUSEEVENTF_LEFTDOWN)
		Control.mouse_event(MOUSEEVENTF_LEFTUP)
		DelayAction(ReturnCursor,0.05,{pos})
	end
	
	function Corki:CastSpell(spell,pos)
		local customcast = self.Menu.CustomSpellCast:Value()
		if not customcast then
			Control.CastSpell(spell, pos)
			return
		else
			local delay = self.Menu.delay:Value()
			local ticker = GetTickCount()
			if castSpell.state == 0 and ticker > castSpell.casting then
				castSpell.state = 1
				castSpell.mouse = mousePos
				castSpell.tick = ticker
				if ticker - castSpell.tick < Game.Latency() then
					--block movement
					SetMovement(false)
					Control.SetCursorPos(pos)
					Control.KeyDown(spell)
					Control.KeyUp(spell)
					DelayAction(LeftClick,delay/1000,{castSpell.mouse})
					castSpell.casting = ticker + 500
				end
			end
		end
	end
	
	function Corki:GetRRange()
		return (self:HasBig() and R2.Range or R.Range)
	end
	
	function Corki:GetBuffs()
		self.T = {}
		for i = 0, myHero.buffCount do
			local Buff = myHero:GetBuff(i)
			if Buff.count > 0 then
				table.insert(self.T, Buff)
			end
		end
		return self.T
	end
	
	function Corki:HasBig()
		for K, Buff in pairs(self:GetBuffs()) do
			if Buff.name:lower() == "corkimissilebarragecounterbig" then
				return true
			end
		end
		return false
	end
	
	function Corki:StacksR()
		return myHero:GetSpellData(_R).ammo
	end
	--[[CastQ]]
	function Corki:CastQ(target, combo)
		if (not _G.SDK and not _G.GOS and not _G.EOW) then return end
		local target = target or (_G.SDK and _G.SDK.TargetSelector:GetTarget(Q.Range, _G.SDK.DAMAGE_TYPE_MAGICAL)) or (_G.GOS and _G.GOS:GetTarget(Q.Range,"AP"))
		if target and target.type == "AIHeroClient" and self:CanCast(_Q) and ((combo and self.Menu.Combo.comboUseQ:Value()) or (combo == false and self.Menu.Harass.harassUseQ:Value())) then
			local castpos
			if (_G.PremiumPrediction:Loaded()) then
				local spellData = {speed = Q.Speed, range = Q.Range, delay = Q.Delay, radius = Q.Width, collision = {}, type = "circular"}
				local pred = _G.PremiumPrediction:GetPrediction(myHero, target, spellData)
				if pred.CastPos and pred.HitChance >= self.Menu.PremPredminchance:Value()/100 then
					self:CastSpell(HK_Q, castpos)
				end
			elseif TYPE_GENERIC and self.Menu.EternalUse:Value() then
				castPos = EPrediction["Q"]:GetPrediction(target, myHero.pos)
				if castPos.hitChance >= self.Menu.minchance:Value() then
					self:CastSpell(HK_Q, castPos.castPos)
				end
			else
				castPos = target:GetPrediction(Q.Speed,Q.Delay)
				self:CastSpell(HK_Q, castPos)
			end
		end
	end
	
	
	--[[CastE]]
	function Corki:CastE(target,combo)
		if (not _G.SDK and not _G.GOS and not _G.EOW) then return end
		local target = target or (_G.SDK and _G.SDK.TargetSelector:GetTarget(E.Range, _G.SDK.DAMAGE_TYPE_PHYSICAL)) or (_G.GOS and _G.GOS:GetTarget(E.Range,"AP"))
		if target and target.type == "AIHeroClient" and self:CanCast(_E) and self.Menu.Combo.comboUseE:Value() then
			self:CastSpell(HK_E, target.pos)
		end
	end
	
	--[[CastR]]
	function Corki:CastR(target,combo)
		if (not _G.SDK and not _G.GOS and not _G.EOW) then return end
		local RRange = self:GetRRange()
		local target = target or (_G.SDK and _G.SDK.TargetSelector:GetTarget(RRange, _G.SDK.DAMAGE_TYPE_PHYSICAL)) or (_G.GOS and _G.GOS:GetTarget(RRange,"AP"))
		local currentultstacks = self:StacksR()
		if target and target.type == "AIHeroClient" and self:CanCast(_R) 
		and ((combo and self.Menu.Combo.comboUseR:Value()) or (combo == false and self.Menu.Harass.harassUseR:Value())) 
		and ((combo == false and currentultstacks > self.Menu.Harass.HarassMaxStacks:Value()) or (combo and currentultstacks > self.Menu.Combo.MaxStacks:Value()))
		then
			local ulttype = self:HasBig() and "R2" or "R"
			if (_G.PremiumPrediction:Loaded()) then
				if (ulttype == "R2") then
					local spellData = {speed = R2.Speed, range = R2.Range, delay = R2.Delay, radius = R2.Width, collision = {}, type = "linear"}
					local pred = _G.PremiumPrediction:GetPrediction(myHero, target, spellData)
					if pred.CastPos and pred.HitChance >= self.Menu.PremPredminchance:Value()/100 then
						self:CastSpell(HK_R, pred.CastPos)
					end
				else
					local spellData = {speed = R.Speed, range = R.Range, delay = R.Delay, radius = R.Width, collision = {}, type = "linear"}
					local pred = _G.PremiumPrediction:GetPrediction(myHero, target, spellData)
					if pred.CastPos and pred.HitChance >= self.Menu.PremPredminchance:Value()/100 then
						self:CastSpell(HK_R, pred.CastPos)
					end
				end
			elseif ulttype == "R2" and target:GetCollision(R2.Radius,R2.Speed,R2.Delay) == 0 then
				castPos = target:GetPrediction(R2.Speed,R2.Delay)
				self:CastSpell(HK_R, castPos)
			elseif ulttype == "R" and target:GetCollision(R.Radius,R.Speed,R.Delay) == 0 then
				castPos = target:GetPrediction(R.Speed,R.Delay)
				self:CastSpell(HK_R, castPos)
			end
		end
	end
	
	function Corki:IsReady(spellSlot)
		return myHero:GetSpellData(spellSlot).currentCd == 0 and myHero:GetSpellData(spellSlot).level > 0
	end
	
	function Corki:CheckMana(spellSlot)
		local savemana = self.Menu.Combo.ManaW:Value()
		return myHero:GetSpellData(spellSlot).mana < (myHero.mana - ((savemana and 40) or 0))
	end
	
	function Corki:CanCast(spellSlot)
		return self:IsReady(spellSlot) and self:CheckMana(spellSlot)
	end
	
	
	function OnLoad()
		Corki:__init()
	end
end

if myHero.charName == "Xayah" then
	local Scriptname,Version,Author,LVersion = "TRUSt in my Xayah","v1.2","TRUS","10.3"
	
	local Xayah = {}
	Xayah.__index = Xayah
	
	require "DamageLib"
	if FileExist(COMMON_PATH .. "PremiumPrediction.lua") then
		require 'PremiumPrediction'
		PrintChat("PremiumPrediction library loaded")
	end
	XayahPassiveTable = {}
	
	function Xayah:__init()
		if not TRUStinMyMarksmanloaded then TRUStinMyMarksmanloaded = true else return end
		self:LoadSpells()
		self:LoadMenu()
		Callback.Add("Tick", function() self:Tick() end)
		Callback.Add("Draw", function() self:Draw() end)
		local orbwalkername = ""
		if _G.SDK then
			orbwalkername = "IC'S orbwalker"	
			_G.SDK.Orbwalker:OnPostAttack(function() 
			end)
		elseif _G.EOW then
			orbwalkername = "EOW"	
		elseif _G.GOS then
			orbwalkername = "Noddy orbwalker"
		else
			orbwalkername = "Orbwalker not found"
		end
		PrintChat(Scriptname.." "..Version.." - Loaded...."..orbwalkername)
	end
	
	
	function Xayah:LoadSpells()
		Q = {Range = 1100, Width = 50, Delay = 0.5, Speed = 1200}
		E = {Range = 1000}
		R = {Delay = 1, Range = 1100}
		
	end
	
	function Xayah:LoadMenu()
		self.Menu = MenuElement({type = MENU, id = "TRUStinymyXayah", name = Scriptname})
		
		--[[Combo]]
		self.Menu:MenuElement({id = "UseBOTRK", name = "Use botrk", value = true})
		
		self.Menu:MenuElement({type = MENU, id = "Combo", name = "Combo Settings"})
		self.Menu.Combo:MenuElement({id = "comboUseQ", name = "Use Q", value = true})
		self.Menu.Combo:MenuElement({id = "comboUseW", name = "Use W", value = true})
		self.Menu.Combo:MenuElement({id = "comboUseE", name = "Use E", value = true})
		self.Menu.Combo:MenuElement({id = "comboEFeathers", name = "Minimal feather for E:", value = 4, min = 1, max = 8})
		self.Menu.Combo:MenuElement({id = "savemana", name = "Save mana for E:", value = true})
		
		self.Menu:MenuElement({type = MENU, id = "EUsage", name = "EUsage"})
		self.Menu.EUsage:MenuElement({id = "autoroot", name = "Auto Root", value = true})
		self.Menu.EUsage:MenuElement({id = "rootedamount", name = "Minimal enemys for autoroot:", value = 2, min = 1, max = 5})
		self.Menu.EUsage:MenuElement({id = "autoks", name = "Autokill with E", value = true})
		
		--[[Draw]]
		self.Menu:MenuElement({type = MENU, id = "Draw", name = "Draw Settings"})
		self.Menu.Draw:MenuElement({id = "DrawE", name = "Draw Featherhit amounts", value = true})
		self.Menu.Draw:MenuElement({id = "DrawOnGround", name = "Draw Feathers on ground", value = true})
		self.Menu.Draw:MenuElement({id = "DrawFLines", name = "Draw Feathers lines", value = true})
		
		
		--[[Harass]]
		self.Menu:MenuElement({type = MENU, id = "Harass", name = "Harass Settings"})
		self.Menu.Harass:MenuElement({id = "harassUseQ", name = "Use Q", value = true})
		self.Menu.Harass:MenuElement({id = "harassUseE", name = "Use E", value = true})
		self.Menu.Harass:MenuElement({id = "minEFeathers", name = "Minimal feather for E:", value = 2, min = 1, max = 8})
		self.Menu.Harass:MenuElement({id = "harassMana", name = "Minimal mana percent:", value = 30, min = 0, max = 101, identifier = "%"})
		
		
		if (_G.PremiumPrediction:Loaded()) then
			
			self.Menu:MenuElement({id = "PremPredminchance", name = "PremPr Minimal hitchance", value = 1, min = 1, max = 100, step = 1, identifier = ""})
		end
		self.Menu:MenuElement({id = "CustomSpellCast", name = "Use custom spellcast", tooltip = "Can fix some casting problems with wrong directions and so (thx Noddy for this one)", value = true})
		self.Menu:MenuElement({id = "delay", name = "Custom spellcast delay", value = 50, min = 0, max = 200, step = 5, identifier = ""})
		
		self.Menu:MenuElement({id = "blank", type = SPACE , name = ""})
		self.Menu:MenuElement({id = "blank", type = SPACE , name = "Script Ver: "..Version.. " - LoL Ver: "..LVersion.. "" .. (_G.PremiumPrediction:Loaded() and " PremiumPr" or "")})
		self.Menu:MenuElement({id = "blank", type = SPACE , name = "by "..Author.. ""})
	end
	
	
	function alreadycontains(element)
		for _, value in pairs(XayahPassiveTable) do
			if value.ID == element.networkID then
				return true
			end
		end
		return false
	end
	
	function Xayah:GetFeatherHits(target)
		local HitCount = 0
		if target then	
			for i, object in ipairs(XayahPassiveTable) do
				local collidingLine = LineSegment(myHero.pos, object.Position)
				if Point(target):__distance(collidingLine) < 80 + target.boundingRadius then
					HitCount = HitCount + 1
					object.hit = true
				end
			end
		end
		return HitCount
	end
	
	function Xayah:UpdateFeathers()
		for i = 1, Game.MissileCount() do
			local missile = Game.Missile(i)
			if missile.missileData and missile.missileData.owner == myHero.handle and not alreadycontains(missile) then
				if missile.missileData.name == "XayahQMissile1" or missile.missileData.name == "XayahQMissile2" or missile.missileData.name == "XayahRMissile" then
					table.insert(XayahPassiveTable, {placetime = Game.Timer() + 6, ID = missile.networkID, Position = Vector(missile.missileData.endPos), hit = false})
				elseif missile.missileData.name == "XayahPassiveAttack" then
					local newpos = myHero.pos:Extended(missile.missileData.endPos,1000)
					table.insert(XayahPassiveTable, {placetime = Game.Timer() + 6, ID = missile.networkID, Position = Vector(newpos), hit = false})
				elseif missile.missileData.name == "XayahEMissile" then
					XayahPassiveTable = {}
				end
			end
		end
	end
	
	function Xayah:Tick()
		if myHero.dead or (not _G.SDK and not _G.GOS) then return end
		
		local combomodeactive, harassactive, canmove, canattack, currenttarget = CurrentModes()
		local HarassMinMana = self.Menu.Harass.harassMana:Value()
		local savemana = self.Menu.Combo.savemana:Value()
		local Eautoroot = self.Menu.EUsage.autoroot:Value()
		local eKS = self.Menu.EUsage.autoks:Value()
		self:UpdateFeathers()
		
		
		if combomodeactive and self.Menu.UseBOTRK:Value() then
			UseBotrk()
		end
		if self:CanCast(_Q) and ((combomodeactive and self.Menu.Combo.comboUseQ:Value() and (not savemana or myHero.mana > myHero:GetSpellData(_Q).mana + myHero:GetSpellData(_E).mana)) or (harassactive and self.Menu.Harass.harassUseQ:Value() and myHero.maxMana * HarassMinMana * 0.01 < myHero.mana)) then
			if canmove and (not canattack or not currenttarget) then
				self:CastQ(currenttarget,combomodeactive or false)
			end
		end
		if self:CanCast(_E) then 
			if (Eautoroot or eKS) then
				self:EUsage()
			end
			if (harassactive and self.Menu.Harass.harassUseE:Value()) then
				if canmove and (not canattack or not currenttarget) then
					local heroeslist = (_G.SDK and _G.SDK.ObjectManager:GetEnemyHeroes()) or self:GetEnemyHeroes()
					for i, target in ipairs(heroeslist) do
						if self:IsValidTarget(target) then
							local hits = self:GetFeatherHits(target)
							if hits >= self.Menu.Harass.minEFeathers:Value() then
								Control.CastSpell(HK_E)
							end
						end
					end
				end
			end
			if (combomodeactive and self.Menu.Combo.comboUseE:Value()) then
				if canmove and (not canattack or not currenttarget) then
					local heroeslist = (_G.SDK and _G.SDK.ObjectManager:GetEnemyHeroes()) or self:GetEnemyHeroes()
					for i, target in ipairs(heroeslist) do
						if self:IsValidTarget(target) then
							local hits = self:GetFeatherHits(target)
							if hits >= self.Menu.Combo.comboEFeathers:Value() then
								Control.CastSpell(HK_E)
							end
						end
					end
				end
			end
		end
		if currenttarget and self:CanCast(_W) and self.Menu.Combo.comboUseW:Value() and combomodeactive then
			Control.CastSpell(HK_W)
		end	
		
	end
	
	function EnableMovement()
		--unblock movement
		SetMovement(true)
	end
	
	function ReturnCursor(pos)
		Control.SetCursorPos(pos)
		Control.mouse_event(MOUSEEVENTF_RIGHTDOWN)
		Control.mouse_event(MOUSEEVENTF_RIGHTUP)
		DelayAction(EnableMovement,0.1)
	end
	
	function LeftClick(pos)
		Control.mouse_event(MOUSEEVENTF_LEFTDOWN)
		Control.mouse_event(MOUSEEVENTF_LEFTUP)
		DelayAction(ReturnCursor,0.05,{pos})
	end
	
	function Xayah:CastSpell(spell,pos)
		local customcast = self.Menu.CustomSpellCast:Value()
		if not customcast then
			Control.CastSpell(spell, pos)
			return
		else
			local delay = self.Menu.delay:Value()
			local ticker = GetTickCount()
			if castSpell.state == 0 and ticker > castSpell.casting then
				castSpell.state = 1
				castSpell.mouse = mousePos
				castSpell.tick = ticker
				if ticker - castSpell.tick < Game.Latency() then
					--block movement
					SetMovement(false)
					Control.SetCursorPos(pos)
					Control.KeyDown(spell)
					Control.KeyUp(spell)
					DelayAction(LeftClick,delay/1000,{castSpell.mouse})
					castSpell.casting = ticker + 500
				end
			end
		end
	end
	
	
	
	function Xayah:CastQ(target, combo)
		if (not _G.SDK and not _G.GOS and not _G.EOW) then return end
		local target = target or (_G.SDK and _G.SDK.TargetSelector:GetTarget(Q.Range, _G.SDK.DAMAGE_TYPE_PHYSICAL)) or (_G.GOS and _G.GOS:GetTarget(Q.Range,"AD"))
		if target and target.type == "AIHeroClient" then
			if (_G.PremiumPrediction:Loaded()) then
				local spellData = {speed = Q.Speed, range = Q.Range, delay = Q.Delay, radius = Q.Width, collision = {}, type = "linear"}
				local pred = _G.PremiumPrediction:GetPrediction(myHero, target, spellData)
				if pred.CastPos and pred.HitChance >= self.Menu.PremPredminchance:Value()/100 then
					self:CastSpell(HK_Q, pred.CastPos)
				end
			elseif (target:GetCollision(Q.Width,Q.Speed,Q.Delay) == 0) then
				local castPos = target:GetPrediction(Q.Speed,Q.Delay)
				self:CastSpell(HK_Q, castPos)
			end
		end
	end
	function Xayah:IsValidTarget(unit, range, checkTeam, from)
		local range = range == nil and math.huge or range
		if unit == nil or not unit.valid or not unit.visible or unit.dead or not unit.isTargetable or (checkTeam and unit.isAlly) then
			return false
		end
		if myHero.pos:DistanceTo(unit.pos)>range then return false end 
		return true 
	end
	
	function Xayah:EUsage()
		local heroeslist = (_G.SDK and _G.SDK.ObjectManager:GetEnemyHeroes()) or self:GetEnemyHeroes()
		local rootedenemy = 0
		for i, target in ipairs(heroeslist) do
			if self:IsValidTarget(target) then
				local hits = self:GetFeatherHits(target)
				if hits == 0 then return end 
				if hits >= 3 then
					rootedenemy = rootedenemy +1
				end
				local edamage = (45 + myHero:GetSpellData(_E).level*10 + 0.6*myHero.bonusDamage)*hits*(1+myHero.critChance/2)
				local tempdmg = CalcPhysicalDamage(myHero,target,edamage)
				if tempdmg > target.health then
					Control.CastSpell(HK_E)
				end
				if rootedenemy >= self.Menu.EUsage.rootedamount:Value() then 
					Control.CastSpell(HK_E)
				end
				
			end
		end
	end
	
	function Xayah:IsReady(spellSlot)
		return myHero:GetSpellData(spellSlot).currentCd == 0 and myHero:GetSpellData(spellSlot).level > 0
	end
	
	function Xayah:CheckMana(spellSlot)
		return myHero:GetSpellData(spellSlot).mana < myHero.mana
	end
	
	function Xayah:CanCast(spellSlot)
		return self:IsReady(spellSlot) and self:CheckMana(spellSlot)
	end
	
	function Xayah:Draw()
		if self.Menu.Draw.DrawE:Value() then
			local heroeslist = (_G.SDK and _G.SDK.ObjectManager:GetEnemyHeroes()) or self:GetEnemyHeroes()
			for i, target in ipairs(heroeslist) do
				local hits = self:GetFeatherHits(target)
				Draw.Text(tostring(hits), 25, target.pos:To2D().x, target.pos:To2D().y, Draw.Color(255, 255, 255, 0))
			end
		end
		if self.Menu.Draw.DrawOnGround:Value() or self.Menu.Draw.DrawFLines:Value() then
			for i, object in ipairs(XayahPassiveTable) do
				if object.placetime > Game.Timer() then
					if self.Menu.Draw.DrawOnGround:Value() then
						Draw.Circle(object.Position, 90, 3, Draw.Color(255, 255, 255, 0))
					end
					if self.Menu.Draw.DrawFLines:Value() then
						Draw.Line(myHero.pos:To2D().x, myHero.pos:To2D().y, object.Position:To2D().x, object.Position:To2D().y, 4, object.hit and Draw.Color(255, 255, 0, 0) or Draw.Color(255, 255, 255, 0))
					end
				else
					table.remove(XayahPassiveTable,i)
				end
				object.hit = false
			end
		end
	end
	
	function OnLoad()
		Xayah:__init()
	end
end


if myHero.charName == "Senna" then
	local Senna = {}
	Senna.__index = Senna
	local Scriptname,Version,Author,LVersion = "TRUSt in my Senna","v1.2","TRUS","10.3"
	local passive = true
	local lastbuff = 0
	function Senna:__init()
		if not TRUStinMyMarksmanloaded then TRUStinMyMarksmanloaded = true else return end
		self:LoadSpells()
		self:LoadMenu()
		Callback.Add("Tick", function() self:Tick() end)
		
		local orbwalkername = ""
		if _G.SDK then
			orbwalkername = "IC'S orbwalker"		
		elseif _G.EOW then
			orbwalkername = "EOW"	
		elseif _G.GOS then
			orbwalkername = "Noddy orbwalker"		
		else
			orbwalkername = "Orbwalker not found"
			
		end
		PrintChat(Scriptname.." "..Version.." - Loaded...."..orbwalkername)
	end
	
	--[[Spells]]
	function Senna:LoadSpells()
		Q = {Range = 1190, width = nil, Delay = 0.25, Radius = 60, Speed = 2000, Collision = false, aoe = false, type = "linear"}
	end
	
	function Senna:LoadMenu()
		self.Menu = MenuElement({type = MENU, id = "TRUStinymySenna", name = Scriptname})
		self.Menu:MenuElement({id = "UseQ", name = "UseQ", value = true})
		self.Menu:MenuElement({id = "UseBOTRK", name = "Use botrk", value = true})
		self.Menu:MenuElement({id = "UseQHarass", name = "Harass with Q", value = true})
		self.Menu:MenuElement({id = "CustomSpellCast", name = "Use custom spellcast", tooltip = "Can fix some casting problems with wrong directions and so (thx Noddy for this one)", value = true})
		self.Menu:MenuElement({id = "delay", name = "Custom spellcast delay", value = 50, min = 0, max = 200, step = 5, identifier = ""})
		
		self.Menu:MenuElement({id = "blank", type = SPACE , name = ""})
		self.Menu:MenuElement({id = "blank", type = SPACE , name = "Script Ver: "..Version.. " - LoL Ver: "..LVersion.. "" .. (_G.PremiumPrediction:Loaded() and " PremiumPr" or "")})
		self.Menu:MenuElement({id = "blank", type = SPACE , name = "by "..Author.. ""})
	end
	
	
	function Senna:Tick()
		if myHero.dead or (not _G.SDK and not _G.GOS) then return end
		local combomodeactive, harassactive, canmove, canattack, currenttarget = CurrentModes()
		if combomodeactive and self.Menu.UseBOTRK:Value() then
			UseBotrk()
		end
		if harassactive and self.Menu.UseQHarass:Value() and self:CanCast(_Q) then 
			self:Harass() 
		end 
		if combomodeactive and canmove and not canattack then 
			if self:CanCast(_Q) and self.Menu.UseQ:Value() and currenttarget then
				self:CastQ(currenttarget)
				return
			end		
			
		end
		
	end
	
	function EnableMovement()
		--unblock movement
		SetMovement(true)
	end
	
	function ReturnCursor(pos)
		Control.SetCursorPos(pos)
		DelayAction(EnableMovement,0.1)
	end
	
	function LeftClick(pos)
		Control.mouse_event(MOUSEEVENTF_LEFTDOWN)
		Control.mouse_event(MOUSEEVENTF_LEFTUP)
		DelayAction(ReturnCursor,0.05,{pos})
	end
	
	function Senna:CastSpell(spell,pos)
		local customcast = self.Menu.CustomSpellCast:Value()
		if not customcast then
			Control.CastSpell(spell, pos)
			return
		else
			local delay = self.Menu.delay:Value()
			local ticker = GetTickCount()
			if castSpell.state == 0 and ticker > castSpell.casting then
				castSpell.state = 1
				castSpell.mouse = mousePos
				castSpell.tick = ticker
				if ticker - castSpell.tick < Game.Latency() then
					--block movement
					SetMovement(false)
					Control.SetCursorPos(pos)
					Control.KeyDown(spell)
					Control.KeyUp(spell)
					DelayAction(LeftClick,delay/1000,{castSpell.mouse})
					castSpell.casting = ticker + 500
				end
			end
		end
	end
	
	
	--[[CastQ]]
	function Senna:CastQ(target)
		if target and self:CanCast(_Q) then
			self:CastSpell(HK_Q, target.pos)
		end
	end
	
	function Senna:IsReady(spellSlot)
		return myHero:GetSpellData(spellSlot).currentCd == 0 and myHero:GetSpellData(spellSlot).level > 0
	end
	
	function Senna:CheckMana(spellSlot)
		return myHero:GetSpellData(spellSlot).mana < myHero.mana
	end
	
	function Senna:CanCast(spellSlot)
		return self:IsReady(spellSlot) and self:CheckMana(spellSlot)
	end
	
	
	
	function Senna:Harass()
		local temptarget = self:FarQTarget()
		if temptarget then
			self:CastSpell(HK_Q,temptarget.pos)
		end
	end
	
	
	
	
	function Senna:FarQTarget()
		local qtarget = (_G.SDK and _G.SDK.TargetSelector:GetTarget(1300, _G.SDK.DAMAGE_TYPE_PHYSICAL)) or (_G.GOS and _G.GOS:GetTarget(1300,"AD"))
		if qtarget then
			
			if myHero.pos:DistanceTo(qtarget.pos)<myHero.range then
				return qtarget
			end
			
			
			local qdelay = 0.4 - myHero.levelData.lvl*0.01
			local pos
			
			if (_G.PremiumPrediction:Loaded()) then
				pos = _G.PremiumPrediction:GetPositionAfterTime(qtarget, qdelay)
			else 
				pos = qtarget:GetPrediction(math.huge,qdelay)
			end
			
			if not pos then return false end 
			local minionlist = {}
			for i = 1, Game.MinionCount() do
				local minion = Game.Minion(i)
				if minion.valid and minion.pos:DistanceTo(myHero.pos) < myHero.range then
					table.insert(minionlist, minion)
				end
			end
			
			for i = 1, Game.HeroCount() do
				local minion = Game.Hero(i)
				if minion.valid and minion.pos:DistanceTo(myHero.pos) < myHero.range then
					table.insert(minionlist, minion)
				end
			end
			V = Vector(pos) - Vector(myHero.pos)
			
			Vn = V:Normalized()
			Distance = myHero.pos:DistanceTo(pos)
			tx, ty, tz = Vn:Unpack()
			TopX = pos.x - (tx * Distance)
			TopY = pos.y - (ty * Distance)
			TopZ = pos.z - (tz * Distance)
			
			Vr = V:Perpendicular():Normalized()
			Radius = qtarget.boundingRadius or 65
			tx, ty, tz = Vr:Unpack()
			
			LeftX = pos.x + (tx * Radius)
			LeftY = pos.y + (ty * Radius)
			LeftZ = pos.z + (tz * Radius)
			RightX = pos.x - (tx * Radius)
			RightY = pos.y - (ty * Radius)
			RightZ = pos.z - (tz * Radius)
			
			Left = Point(LeftX, LeftY, LeftZ)
			Right = Point(RightX, RightY, RightZ)
			Top = Point(TopX, TopY, TopZ)
			Poly = Polygon(Left, Right, Top)
			
			for i, minion in pairs(minionlist) do
				toPoint = Point(minion.pos.x, minion.pos.y,minion.pos.z)
				if Poly:__contains(toPoint) then
					return minion
				end
			end
		end
		return false 
	end
	
	
	function OnLoad()
		Senna:__init()
	end
end
