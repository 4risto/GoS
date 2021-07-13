-- Lazy Xerath

if myHero.charName ~= "Xerath" then return end

require "DamageLib"
require "PremiumPrediction"

local Version = 2.11


local huge = math.huge
local pi = math.pi
local floor = math.floor
local ceil = math.ceil
local sqrt = math.sqrt
local max = math.max
local min = math.min
--
local lenghtOf = math.lenghtOf
local abs = math.abs
local deg = math.deg
local cos = math.cos
local sin = math.sin
local acos = math.acos
local atan = math.atan
local Vector = Vector
local KeyDown = Control.KeyDown
local KeyUp = Control.KeyUp
local IsKeyDown = Control.IsKeyDown
local SetCursorPos = Control.SetCursorPos

local function GetDistanceSqr(p1, p2)
	local success, message = pcall(function() if p1 == nil then print(p1.x) end end)
	if not success then print(message) end
    p2 = p2 or myHero
    p1 = p1.pos or p1
    p2 = p2.pos or p2
    
    local dx, dz = p1.x - p2.x, p1.z - p2.z
    return dx * dx + dz * dz
end
 
local function GetDistance(p1, p2)
    return sqrt(GetDistanceSqr(p1, p2))
end

class "Spell"
 
function Spell:__init(SpellData)
    self.Slot = SpellData.Slot
    self.Range = SpellData.Range or huge
    self.Delay = SpellData.Delay or 0.25
    self.Speed = SpellData.Speed or huge
    self.Radius = SpellData.Radius or SpellData.Width or 0
    self.Width = SpellData.Width or SpellData.Radius or 0
    self.From = SpellData.From or myHero
    self.Collision = SpellData.Collision or false
    self.Type = SpellData.Type or "Press"
    self.DmgType = SpellData.DmgType or "Physical"
    --
    return self
end
 
function Spell:IsReady()
    return GameCanUseSpell(self.Slot) == READY
end
 
function Spell:CanCast(unit, Range, from)
    local from = from or self.From.pos
    local Range = Range or self.Range
    return unit and unit.valid and unit.visible and not unit.dead and (not Range or GetDistance(from, unit) <= Range)
end
 
function Spell:GetPrediction(target)
    return Prediction:GetBestCastPosition(target, self)
end
 
function Spell:GetBestLinearCastPos(sTar, lst)
    return GetBestLinearCastPos(self, sTar, lst)
end
 
function Spell:GetBestCircularCastPos(sTar, lst)
    return GetBestCircularCastPos(self, sTar, lst)
end
 
function Spell:GetBestLinearFarmPos()
    return GetBestLinearFarmPos(self)
end
 
function Spell:GetBestCircularFarmPos()
    return GetBestCircularFarmPos(self)
end
 
function Spell:CalcDamage(target)
    local rawDmg = self:GetDamage(target, stage)
    if rawDmg <= 0 then return 0 end
    --
    local damage = 0
    if self.DmgType == 'Magical' then
        damage = CalcMagicalDamage(self.From, target, rawDmg)
    elseif self.DmgType == 'Physical' then
        damage = CalcPhysicalDamage(self.From, target, rawDmg);
    elseif self.DmgType == 'Mixed' then
        damage = CalcMixedDamage(self.From, target, rawDmg * .5, rawDmg * .5)
    end
    
    if self.DmgType ~= 'True' then
        if HasBuff(myHero, "summonerexhaustdebuff") then
            damage = damage * .6
        elseif HasBuff(myHero, "itemsmitechallenge") then
            damage = damage * .6
        elseif HasBuff(myHero, "itemphantomdancerdebuff") then
            damage = damage * .88
        end
    else
        damage = rawDmg
    end
    
    return damage
end
 
function Spell:GetDamage(target, stage)
    local slot = self:SlotToString()
    return self:IsReady() and getdmg(slot, target, self.From, stage or 1) or 0
end
 
function Spell:SlotToHK()
    return ({[_Q] = HK_Q, [_W] = HK_W, [_E] = HK_E, [_R] = HK_R, [SUMMONER_1] = HK_SUMMONER_1, [SUMMONER_2] = HK_SUMMONER_2})[self.Slot]
end
 
function Spell:SlotToString()
    return ({[_Q] = "Q", [_W] = "W", [_E] = "E", [_R] = "R"})[self.Slot]
end
 
function Spell:Cast(castOn)
    if not self:IsReady() or ShouldWait() then return end
    --
    local slot = self:SlotToHK()
    if self.Type == "Press" then
        KeyDown(slot)
        return KeyUp(slot)
    end
    --
    local pos = castOn.x and castOn
    local targ = castOn.health and castOn
    --
    if self.Type == "AOE" and pos then
        local bestPos, hit = self:GetBestCircularCastPos(targ, GetEnemyHeroes(self.Range + self.Radius))
        pos = hit >= 2 and bestPos or pos
    end
    --
    if (targ and not targ.pos:To2D().onScreen) then
        return
    elseif (pos and not pos:To2D().onScreen) then
        if self.Type == "AOE" then
            local mapPos = pos:ToMM()
            Control.CastSpell(slot, mapPos.x, mapPos.y)
        else
            pos = myHero.pos:Extended(pos, 200)
            if not pos:To2D().onScreen then return end
        end
    end
    --
    return Control.CastSpell(slot, targ or pos)
end
 
function Spell:CastToPred(target, minHitchance)
    if not target then return end
    --
    local predPos, castPos, hC = self:GetPrediction(target)
    if predPos and hC >= minHitchance then
        return self:Cast(predPos)
    end
end
 
function Spell:OnImmobile(target)
    local TargetImmobile, ImmobilePos, ImmobileCastPosition = Prediction:IsImmobile(target, self)
    if self.Collision then
        local colStatus = #(mCollision(self.From.pos, Pos, self)) > 0
        if colStatus then return end
        return TargetImmobile, ImmobilePos, ImmobileCastPosition
    end
    return TargetImmobile, ImmobilePos, ImmobileCastPosition
end
 
local function DrawDmg(hero, damage)
    local screenPos = hero.pos:To2D()
    local barPos = {x = screenPos.x - 50, y = screenPos.y - 150, onScreen = screenPos.onScreen}
    if barPos.onScreen then
        local percentHealthAfterDamage = max(0, hero.health - damage) / hero.maxHealth
        local xPosEnd = barPos.x + barXOffset + barWidth * hero.health / hero.maxHealth
        local xPosStart = barPos.x + barXOffset + percentHealthAfterDamage * 100
        DrawLine(xPosStart, barPos.y + barYOffset, xPosEnd, barPos.y + barYOffset, 10, DmgColor)
    end
end
 
local function DrawSpells(instance, extrafn)
    local drawSettings = Menu.Draw
    if drawSettings.ON:Value() then
        local qLambda = drawSettings.Q:Value() and instance.Q and instance.Q:Draw(66, 244, 113)
        local wLambda = drawSettings.W:Value() and instance.W and instance.W:Draw(66, 229, 244)
        local eLambda = drawSettings.E:Value() and instance.E and instance.E:Draw(244, 238, 66)
        local rLambda = drawSettings.R:Value() and instance.R and instance.R:Draw(244, 66, 104)
        local tLambda = drawSettings.TS:Value() and instance.target and DrawMark(instance.target.pos, 3, instance.target.boundingRadius, Color.Red)
        if instance.enemies and drawSettings.Dmg:Value() then
            for i = 1, #instance.enemies do
                local enemy = instance.enemies[i]
                local qDmg, wDmg, eDmg, rDmg = instance.Q and instance.Q:CalcDamage(enemy) or 0, instance.W and instance.W:CalcDamage(enemy) or 0, instance.E and instance.E:CalcDamage(enemy) or 0, instance.R and instance.R:CalcDamage(enemy) or 0
                
                DrawDmg(enemy, qDmg + wDmg + eDmg + rDmg)
                if extrafn then
                    extrafn(enemy)
                end
            end
        end
    end
end

ObjectManager = _G.SDK.ObjectManager

GetEnemyMinions = function(range)
	return ObjectManager:GetEnemyMinions(range)
end

local function VectorPointProjectionOnLineSegment(v1, v2, v)
    local cx, cy, ax, ay, bx, by = v.x, v.z, v1.x, v1.z, v2.x, v2.z
    local rL = ((cx - ax) * (bx - ax) + (cy - ay) * (by - ay)) / ((bx - ax) * (bx - ax) + (by - ay) * (by - ay))
    local pointLine = {x = ax + rL * (bx - ax), z = ay + rL * (by - ay)}
    local rS = rL < 0 and 0 or (rL > 1 and 1 or rL)
    local isOnSegment = rS == rL
    local pointSegment = isOnSegment and pointLine or {x = ax + rS * (bx - ax), z = ay + rS * (by - ay)}
    return pointSegment, pointLine, isOnSegment
end

local function mCollision(pos1, pos2, spell, list) --returns a table with minions (use #table to get count)
    local result, speed, width, delay, list = {}, spell.Speed, spell.Width + 65, spell.Delay, list
    --
    if not list then
        list = GetEnemyMinions(max(GetDistance(pos1), GetDistance(pos2)) + spell.Range + 100)
    end
    --
    for i = 1, #list do
        local m = list[i]
        local pos3 = delay and m:GetPrediction(speed, delay) or m.pos
        if m and m.team ~= TEAM_ALLY and m.dead == false and m.isTargetable and GetDistanceSqr(pos1, pos2) > GetDistanceSqr(pos1, pos3) then
            local pointSegment, pointLine, isOnSegment = VectorPointProjectionOnLineSegment(pos1, pos2, pos3)
            if isOnSegment and GetDistanceSqr(pointSegment, pos3) < width * width then
                result[#result + 1] = m
            end
        end
    end
    return result
end


class "Prediction"
 
function Prediction:VectorMovementCollision(startPoint1, endPoint1, v1, startPoint2, v2, delay)
    local sP1x, sP1y, eP1x, eP1y, sP2x, sP2y = startPoint1.x, startPoint1.z, endPoint1.x, endPoint1.z, startPoint2.x, startPoint2.z
    local d, e = eP1x - sP1x, eP1y - sP1y
    local dist, t1, t2 = sqrt(d * d + e * e), nil, nil
    local S, K = dist ~= 0 and v1 * d / dist or 0, dist ~= 0 and v1 * e / dist or 0
    local function GetCollisionPoint(t) return t and {x = sP1x + S * t, y = sP1y + K * t} or nil end
    if delay and delay ~= 0 then sP1x, sP1y = sP1x + S * delay, sP1y + K * delay end
    local r, j = sP2x - sP1x, sP2y - sP1y
    local c = r * r + j * j
    if dist > 0 then
        if v1 == huge then
            local t = dist / v1
            t1 = v2 * t >= 0 and t or nil
        elseif v2 == huge then
            t1 = 0
        else
            local a, b = S * S + K * K - v2 * v2, -r * S - j * K
            if a == 0 then
                if b == 0 then --c=0->t variable
                    t1 = c == 0 and 0 or nil
                else --2*b*t+c=0
                    local t = -c / (2 * b)
                    t1 = v2 * t >= 0 and t or nil
                end
            else --a*t*t+2*b*t+c=0
                local sqr = b * b - a * c
                if sqr >= 0 then
                    local nom = sqrt(sqr)
                    local t = (-nom - b) / a
                    t1 = v2 * t >= 0 and t or nil
                    t = (nom - b) / a
                    t2 = v2 * t >= 0 and t or nil
                end
            end
        end
    elseif dist == 0 then
        t1 = 0
    end
    return t1, GetCollisionPoint(t1), t2, GetCollisionPoint(t2), dist
end
 
function Prediction:IsDashing(unit, spell)
    local delay, radius, speed, from = spell.Delay, spell.Radius, spell.Speed, spell.From.pos
    local OnDash, CanHit, Pos = false, false, nil
    local pathData = unit.pathing
    --
    if pathData.isDashing then
        local startPos = Vector(pathData.startPos)
        local endPos = Vector(pathData.endPos)
        local dashSpeed = pathData.dashSpeed
        local timer = Game.Timer()
        local startT = timer - Game.Latency() / 2000
        local dashDist = GetDistance(startPos, endPos)
        local endT = startT + (dashDist / dashSpeed)
        --
        if endT >= timer and startPos and endPos then
            OnDash = true
            --
            local t1, p1, t2, p2, dist = self:VectorMovementCollision(startPos, endPos, dashSpeed, from, speed, (timer - startT) + delay)
            t1, t2 = (t1 and 0 <= t1 and t1 <= (endT - timer - delay)) and t1 or nil, (t2 and 0 <= t2 and t2 <= (endT - timer - delay)) and t2 or nil
            local t = t1 and t2 and min(t1, t2) or t1 or t2
            --
            if t then
                Pos = t == t1 and Vector(p1.x, 0, p1.y) or Vector(p2.x, 0, p2.y)
                CanHit = true
            else
                Pos = Vector(endPos.x, 0, endPos.z)
                CanHit = (unit.ms * (delay + GetDistance(from, Pos) / speed - (endT - timer))) < radius
            end
        end
    end
    
    return OnDash, CanHit, Pos
end
 


function Prediction:IsImmobile(unit, spell)
    if unit.ms == 0 then return true, unit.pos, unit.pos end
    local delay, radius, speed, from = spell.Delay, spell.Radius, spell.Speed, spell.From.pos
    local debuff = {}
    for i = 1, unit.buffCount do
        local buff = unit:GetBuff(i)
        if buff.duration > 0 then
            local ExtraDelay = speed == math.huge and 0 or (GetDistance(from, unit.pos) / speed)
            if buff.expireTime + (radius / unit.ms) > Game.Timer() + delay + ExtraDelay then
                debuff[buff.type] = true
            end
        end
    end
    if debuff[_STUN] or debuff[_TAUNT] or debuff[_SNARE] or debuff[_SLEEP] or
        debuff[_CHARM] or debuff[_SUPRESS] or debuff[_AIRBORNE] then
        return true, unit.pos, unit.pos
    end
    return false, unit.pos, unit.pos
end
 
function Prediction:IsSlowed(unit, spell)
    local delay, speed, from = spell.Delay, spell.Speed, spell.From.pos
    for i = 1, unit.buffCount do
        local buff = unit:GetBuff(i)
        if buff.type == _SLOW and buff.expireTime >= Game.Timer() and buff.duration > 0 then
            if buff.expireTime > Game.Timer() + delay + GetDistance(unit.pos, from) / speed then
                return true
            end
        end
    end
    return false
end
 
function Prediction:CalculateTargetPosition(unit, spell, tempPos)
    local delay, radius, speed, from = spell.Delay, spell.Radius, spell.Speed, spell.From
    local calcPos = nil
    local pathData = unit.pathing
    local pathCount = pathData.pathCount
    local pathIndex = pathData.pathIndex
    local pathEndPos = Vector(pathData.endPos)
    local pathPos = tempPos and tempPos or unit.pos
    local pathPot = (unit.ms * ((GetDistance(pathPos) / speed) + delay))
    local unitBR = unit.boundingRadius
    --
    if pathCount < 2 then
        local extPos = unit.pos:Extended(pathEndPos, pathPot - unitBR)
        --
        if GetDistance(unit.pos, extPos) > 0 then
            if GetDistance(unit.pos, pathEndPos) >= GetDistance(unit.pos, extPos) then
                calcPos = extPos
            else
                calcPos = pathEndPos
            end
        else
            calcPos = pathEndPos
        end
    else
        for i = pathIndex, pathCount do
            if unit:GetPath(i) and unit:GetPath(i - 1) then
                local startPos = i == pathIndex and unit.pos or unit:GetPath(i - 1)
                local endPos = unit:GetPath(i)
                local pathDist = GetDistance(startPos, endPos)
                --
                if unit:GetPath(pathIndex - 1) then
                    if pathPot > pathDist then
                        pathPot = pathPot - pathDist
                    else
                        local extPos = startPos:Extended(endPos, pathPot - unitBR)
                        
                        calcPos = extPos
                        
                        if tempPos then
                            return calcPos, calcPos
                        else
                            return self:CalculateTargetPosition(unit, spell, calcPos)
                        end
                    end
                end
            end
        end
        --
        if GetDistance(unit.pos, pathEndPos) > unitBR then
            calcPos = pathEndPos
        else
            calcPos = unit.pos
        end
    end
    
    calcPos = calcPos and calcPos or unit.pos
    
    if tempPos then
        return calcPos, calcPos
    else
        return self:CalculateTargetPosition(unit, spell, calcPos)
    end
end
 
function Prediction:GetBestCastPosition(unit, spell)
    local Range = spell.Range and spell.Range - 30 or huge
    local radius = spell.Radius == 0 and 1 or (spell.Radius + unit.boundingRadius) - 4
    local speed = spell.Speed or huge
    local from = spell.From or myHero
    local delay = spell.Delay + (0.07 + Game.Latency() / 1000)
    local collision = spell.Collision or false
    --
    local Position, CastPosition, HitChance = Vector(unit), Vector(unit), 0
    local TargetDashing, CanHitDashing, DashPosition = self:IsDashing(unit, spell)
    local TargetImmobile, ImmobilePos, ImmobileCastPosition = self:IsImmobile(unit, spell)
    
    if TargetDashing then
        if CanHitDashing then
            HitChance = 5
        else
            HitChance = 0
        end
        Position, CastPosition = DashPosition, DashPosition
    elseif TargetImmobile then
        Position, CastPosition = ImmobilePos, ImmobileCastPosition
        HitChance = 4
    else
        Position, CastPosition = self:CalculateTargetPosition(unit, spell)
        
        if unit.activeSpell and unit.activeSpell.valid then
            HitChance = 2
        end
        
        if GetDistanceSqr(from.pos, CastPosition) < 250 then
            HitChance = 2
            local newSpell = {Range = Range, Delay = delay * 0.5, Radius = radius, Width = radius, Speed = speed * 2, From = from}
            Position, CastPosition = self:CalculateTargetPosition(unit, newSpell)
        end
        
        local temp_angle = from.pos:AngleBetween(unit.pos, CastPosition)
        if temp_angle >= 60 then
            HitChance = 1
        elseif temp_angle <= 30 then
            HitChance = 2
        end
    end
    if GetDistanceSqr(from.pos, CastPosition) >= Range * Range then
        HitChance = 0
    end
    if collision and HitChance > 0 then
        local newSpell = {Range = Range, Delay = delay, Radius = radius * 2, Width = radius * 2, Speed = speed * 2, From = from}
        if #(mCollision(from.pos, CastPosition, newSpell)) > 0 then
            HitChance = 0
        end
    end
    
    return Position, CastPosition, HitChance
end

--MENU

local 	LazyMenu = MenuElement({id = "LazyXerath", name = "Jiingz "..myHero.charName, type = MENU})
		LazyMenu:MenuElement({id = "Combo", name = "Combo", type = MENU})
		LazyMenu:MenuElement({id = "Harass", name = "Harass", type = MENU})
		LazyMenu:MenuElement({id = "Clear", name = "Lane+JungleClear", type = MENU})
		LazyMenu:MenuElement({id = "Killsteal", name = "Killsteal", type = MENU})
		--LazyMenu:MenuElement({id = "Debug", name = "Debug", type = MENU})
		LazyMenu:MenuElement({id = "Misc", name = "Misc", type = MENU})
		LazyMenu:MenuElement({id = "Drawings", name = "Drawings", type = MENU})
		LazyMenu:MenuElement({id = "Key", name = "Key Settings", type = MENU})
		LazyMenu.Key:MenuElement({id = "Combo", name = "Combo", key = string.byte(" ")})
		LazyMenu.Key:MenuElement({id = "Harass", name = "Harass | Mixed", key = string.byte("C")})
		LazyMenu.Key:MenuElement({id = "Clear", name = "LaneClear | JungleClear", key = string.byte("V")})
		LazyMenu.Key:MenuElement({id = "LastHit", name = "LastHit", key = string.byte("X")})
		LazyMenu:MenuElement({id = "fastOrb", name = "Make Orbwalker fast again", value = true})
		
		
---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

--
local contains = table.contains
local insert = table.insert
local remove = table.remove
local sort = table.sort

local TEAM_ALLY = myHero.team
local TEAM_ENEMY = 300 - myHero.team
local TEAM_JUNGLE = 300

function GetMode()   
    if _G.SDK then
        return 
		_G.SDK.Orbwalker.Modes[_G.SDK.ORBWALKER_MODE_COMBO] and "Combo"
        or 
		_G.SDK.Orbwalker.Modes[_G.SDK.ORBWALKER_MODE_HARASS] and "Harass"
        or 
		_G.SDK.Orbwalker.Modes[_G.SDK.ORBWALKER_MODE_LANECLEAR] and "LaneClear"
        or 
		_G.SDK.Orbwalker.Modes[_G.SDK.ORBWALKER_MODE_JUNGLECLEAR] and "LaneClear"
        or 
		_G.SDK.Orbwalker.Modes[_G.SDK.ORBWALKER_MODE_LASTHIT] and "LastHit"
        or 
		_G.SDK.Orbwalker.Modes[_G.SDK.ORBWALKER_MODE_FLEE] and "Flee"
		or nil
    
	elseif _G.PremiumOrbwalker then
		return _G.PremiumOrbwalker:GetMode()
	end
	return nil
end

local function SetAttack(bool)
	if _G.EOWLoaded then
		EOW:SetAttacks(bool)
	elseif _G.SDK then                                                        
		_G.SDK.Orbwalker:SetAttack(bool)
	elseif _G.PremiumOrbwalker then
		_G.PremiumOrbwalker:SetAttack(bool)	
	else
		GOS.BlockAttack = not bool
	end

end

local function SetMovement(bool)
	if _G.EOWLoaded then
		EOW:SetMovements(bool)
	elseif _G.SDK then
		_G.SDK.Orbwalker:SetMovement(bool)
	elseif _G.PremiumOrbwalker then
		_G.PremiumOrbwalker:SetMovement(bool)	
	else
		GOS.BlockMovement = not bool
	end
end

local function GetDistance(p1,p2)
return  math.sqrt(math.pow((p2.x - p1.x),2) + math.pow((p2.y - p1.y),2) + math.pow((p2.z - p1.z),2))
end

local function GetDistance2D(p1,p2)
return  math.sqrt(math.pow((p2.x - p1.x),2) + math.pow((p2.y - p1.y),2))
end

local function GetMinionCount(Range, pos)
    local pos = pos.pos
	local count = 0
	for i = 1,Game.MinionCount() do
	local hero = Game.Minion(i)
	local Range = Range * Range
		if hero.team ~= TEAM_ALLY and hero.dead == false and GetDistance(pos, hero.pos) < Range then
		count = count + 1
		end
	end
	return count
end

local _AllyHeroes
function GetAllyHeroes()
  if _AllyHeroes then return _AllyHeroes end
  _AllyHeroes = {}
  for i = 1, Game.HeroCount() do
    local unit = Game.Hero(i)
    if unit.isAlly then
      table.insert(_AllyHeroes, unit)
    end
  end
  return _AllyHeroes
end

local _EnemyHeroes
function GetEnemyHeroes()
  if _EnemyHeroes then return _EnemyHeroes end
  for i = 1, Game.HeroCount() do
    local unit = Game.Hero(i)
    if unit.isEnemy then
	  if _EnemyHeroes == nil then _EnemyHeroes = {} end
      table.insert(_EnemyHeroes, unit)
    end
  end
  return {}
end

function IsImmobileTarget(unit)
	for i = 0, unit.buffCount do
		local buff = unit:GetBuff(i)
		if buff and (buff.type == 5 or buff.type == 12 or buff.type == 30 or buff.type == 25 or buff.name == "recall") and buff.count > 0 then
			return true
		end
	end
	return false	
end

local _OnVision = {}
function OnVision(unit)
	if _OnVision[unit.networkID] == nil then _OnVision[unit.networkID] = {state = unit.visible , tick = GetTickCount(), pos = unit.pos} end
	if _OnVision[unit.networkID].state == true and not unit.visible then _OnVision[unit.networkID].state = false _OnVision[unit.networkID].tick = GetTickCount() end
	if _OnVision[unit.networkID].state == false and unit.visible then _OnVision[unit.networkID].state = true _OnVision[unit.networkID].tick = GetTickCount() end
	return _OnVision[unit.networkID]
end
Callback.Add("Tick", function() OnVisionF() end)
local visionTick = GetTickCount()
function OnVisionF()
	if GetTickCount() - visionTick > 100 then
		for i,v in pairs(GetEnemyHeroes()) do
			OnVision(v)
		end
	end
end

local _OnWaypoint = {}
function OnWaypoint(unit)
	if _OnWaypoint[unit.networkID] == nil then _OnWaypoint[unit.networkID] = {pos = unit.posTo , speed = unit.ms, time = Game.Timer()} end
	if _OnWaypoint[unit.networkID].pos ~= unit.posTo then 
		-- print("OnWayPoint:"..unit.charName.." | "..math.floor(Game.Timer()))
		_OnWaypoint[unit.networkID] = {startPos = unit.pos, pos = unit.posTo , speed = unit.ms, time = Game.Timer()}
			DelayAction(function()
				local time = (Game.Timer() - _OnWaypoint[unit.networkID].time)
				local speed = GetDistance2D(_OnWaypoint[unit.networkID].startPos,unit.pos)/(Game.Timer() - _OnWaypoint[unit.networkID].time)
				if speed > 1250 and time > 0 and unit.posTo == _OnWaypoint[unit.networkID].pos and GetDistance(unit.pos,_OnWaypoint[unit.networkID].pos) > 200 then
					_OnWaypoint[unit.networkID].speed = GetDistance2D(_OnWaypoint[unit.networkID].startPos,unit.pos)/(Game.Timer() - _OnWaypoint[unit.networkID].time)
					-- print("OnDash: "..unit.charName)
				end
			end,0.05)
	end
	return _OnWaypoint[unit.networkID]
end

local function GetPred(unit,speed,delay)
	local speed = speed or math.huge
	local delay = delay or 0.25
	local unitSpeed = unit.ms
	if OnWaypoint(unit).speed > unitSpeed then unitSpeed = OnWaypoint(unit).speed end
	if OnVision(unit).state == false then
		local unitPos = unit.pos + Vector(unit.pos,unit.posTo):Normalized() * ((GetTickCount() - OnVision(unit).tick)/1000 * unitSpeed)
		local predPos = unitPos + Vector(unit.pos,unit.posTo):Normalized() * (unitSpeed * (delay + (GetDistance(myHero.pos,unitPos)/speed)))
		if GetDistance(unit.pos,predPos) > GetDistance(unit.pos,unit.posTo) then predPos = unit.posTo end
		return predPos
	else
		if unitSpeed > unit.ms then
			local predPos = unit.pos + Vector(OnWaypoint(unit).startPos,unit.posTo):Normalized() * (unitSpeed * (delay + (GetDistance(myHero.pos,unit.pos)/speed)))
			if GetDistance(unit.pos,predPos) > GetDistance(unit.pos,unit.posTo) then predPos = unit.posTo end
			return predPos
		elseif IsImmobileTarget(unit) then
			return unit.pos
		else
			return unit:GetPrediction(speed,delay)
		end
	end
end

local function CanUseSpell(spell)
	return myHero:GetSpellData(spell).currentCd == 0 and myHero:GetSpellData(spell).level > 0 and myHero:GetSpellData(spell).mana <= myHero.mana
end

function GetPercentHP(unit)
  if type(unit) ~= "userdata" then error("{GetPercentHP}: bad argument #1 (userdata expected, got "..type(unit)..")") end
  return 100*unit.health/unit.maxHealth
end

function GetPercentMP(unit)
  if type(unit) ~= "userdata" then error("{GetPercentMP}: bad argument #1 (userdata expected, got "..type(unit)..")") end
  return 100*unit.mana/unit.maxMana
end

local function GetBuffs(unit)
  local t = {}
  for i = 0, unit.buffCount do
    local buff = unit:GetBuff(i)
    if buff.count > 0 then
      table.insert(t, buff)
    end
  end
  return t
end

function HasBuff(unit, buffname)
  if type(unit) ~= "userdata" then error("{HasBuff}: bad argument #1 (userdata expected, got "..type(unit)..")") end
  if type(buffname) ~= "string" then error("{HasBuff}: bad argument #2 (string expected, got "..type(buffname)..")") end
  for i, buff in pairs(GetBuffs(unit)) do
    if buff.name == buffname then 
      return true
    end
  end
  return false
end

function GetItemSlot(unit, id)
  for i = ITEM_1, ITEM_7 do
    if unit:GetItemData(i).itemID == id then
      return i
    end
  end
  return 0 -- 
end

function GetBuffData(unit, buffname)
  for i = 0, unit.buffCount do
    local buff = unit:GetBuff(i)
    if buff.name == buffname and buff.count > 0 then 
      return buff
    end
  end
  return {type = 0, name = "", startTime = 0, expireTime = 0, duration = 0, stacks = 0, count = 0}--
end

function IsImmune(unit)
  if type(unit) ~= "userdata" then error("{IsImmune}: bad argument #1 (userdata expected, got "..type(unit)..")") end
  for i, buff in pairs(GetBuffs(unit)) do
    if (buff.name == "KindredRNoDeathBuff" or buff.name == "UndyingRage") and GetPercentHP(unit) <= 10 then
      return true
    end
    if buff.name == "VladimirSanguinePool" or buff.name == "JudicatorIntervention" then 
      return true
    end
  end
  return false
end 

function IsValidTarget(unit, Range, checkTeam, from)
  local Range = Range == nil and math.huge or Range
  if type(Range) ~= "number" then error("{IsValidTarget}: bad argument #2 (number expected, got "..type(Range)..")") end
  if type(checkTeam) ~= "nil" and type(checkTeam) ~= "boolean" then error("{IsValidTarget}: bad argument #3 (boolean or nil expected, got "..type(checkTeam)..")") end
  if type(from) ~= "nil" and type(from) ~= "userdata" then error("{IsValidTarget}: bad argument #4 (vector or nil expected, got "..type(from)..")") end
  if unit == nil or not unit.valid or not unit.visible or unit.dead or not unit.isTargetable or IsImmune(unit) or (checkTeam and unit.isAlly) then 
    return false 
  end 
  return unit.pos:DistanceTo(from.pos and from.pos or myHero.pos) < Range 
end

function CountAlliesInRange(point, Range)
  if type(point) ~= "userdata" then error("{CountAlliesInRange}: bad argument #1 (vector expected, got "..type(point)..")") end
  local Range = Range == nil and math.huge or Range 
  if type(Range) ~= "number" then error("{CountAlliesInRange}: bad argument #2 (number expected, got "..type(Range)..")") end
  local n = 0
  for i = 1, Game.HeroCount() do
    local unit = Game.Hero(i)
    if unit.isAlly and not unit.isMe and IsValidTarget(unit, Range, false, point) then
      n = n + 1
    end
  end
  return n
end

local function CountEnemiesInRange(point, Range)
  if type(point) ~= "userdata" then error("{CountEnemiesInRange}: bad argument #1 (vector expected, got "..type(point)..")") end
  local Range = Range == nil and math.huge or Range 
  if type(Range) ~= "number" then error("{CountEnemiesInRange}: bad argument #2 (number expected, got "..type(Range)..")") end
  local n = 0
  for i = 1, Game.HeroCount() do
    local unit = Game.Hero(i)
    if IsValidTarget(unit, Range, true, point) then
      n = n + 1
    end
  end
  return n
end

local DamageReductionTable = {
  ["Braum"] = {buff = "BraumShieldRaise", amount = function(target) return 1 - ({0.3, 0.325, 0.35, 0.375, 0.4})[target:GetSpellData(_E).level] end},
  ["Urgot"] = {buff = "urgotswapdef", amount = function(target) return 1 - ({0.3, 0.4, 0.5})[target:GetSpellData(_R).level] end},
  ["Alistar"] = {buff = "Ferocious Howl", amount = function(target) return ({0.5, 0.4, 0.3})[target:GetSpellData(_R).level] end},
  -- ["Amumu"] = {buff = "Tantrum", amount = function(target) return ({2, 4, 6, 8, 10})[target:GetSpellData(_E).level] end, damageType = 1},
  ["Galio"] = {buff = "GalioIdolOfDurand", amount = function(target) return 0.5 end},
  ["Garen"] = {buff = "GarenW", amount = function(target) return 0.7 end},
  ["Gragas"] = {buff = "GragasWSelf", amount = function(target) return ({0.1, 0.12, 0.14, 0.16, 0.18})[target:GetSpellData(_W).level] end},
  ["Annie"] = {buff = "MoltenShield", amount = function(target) return 1 - ({0.16,0.22,0.28,0.34,0.4})[target:GetSpellData(_E).level] end},
  ["Malzahar"] = {buff = "malzaharpassiveshield", amount = function(target) return 0.1 end}
}

function GotBuff(unit, buffname)
  for i = 0, unit.buffCount do
    local buff = unit:GetBuff(i)
    if buff.name == buffname and buff.count > 0 then 
      return buff.count
    end
  end
  return 0
end

function GetBuffData(unit, buffname)
  for i = 0, unit.buffCount do
    local buff = unit:GetBuff(i)
    if buff.name == buffname and buff.count > 0 then 
      return buff
    end
  end
  return {type = 0, name = "", startTime = 0, expireTime = 0, duration = 0, stacks = 0, count = 0}
end

function CalcPhysicalDamage(source, target, amount)
  local ArmorPenPercent = source.armorPenPercent
  local ArmorPenFlat = (0.4 + target.levelData.lvl / 30) * source.armorPen
  local BonusArmorPen = source.bonusArmorPenPercent

  if source.type == Obj_AI_Minion then
    ArmorPenPercent = 1
    ArmorPenFlat = 0
    BonusArmorPen = 1
  elseif source.type == Obj_AI_Turret then
    ArmorPenFlat = 0
    BonusArmorPen = 1
    if source.charName:find("3") or source.charName:find("4") then
      ArmorPenPercent = 0.25
    else
      ArmorPenPercent = 0.7
    end
  end

  if source.type == Obj_AI_Turret then
    if target.type == Obj_AI_Minion then
      amount = amount * 1.25
      if string.ends(target.charName, "MinionSiege") then
        amount = amount * 0.7
      end
      return amount
    end
  end

  local armor = target.armor
  local bonusArmor = target.bonusArmor
  local value = 100 / (100 + (armor * ArmorPenPercent) - (bonusArmor * (1 - BonusArmorPen)) - ArmorPenFlat)

  if armor < 0 then
    value = 2 - 100 / (100 - armor)
  elseif (armor * ArmorPenPercent) - (bonusArmor * (1 - BonusArmorPen)) - ArmorPenFlat < 0 then
    value = 1
  end
  return math.max(0, math.floor(DamageReductionMod(source, target, PassivePercentMod(source, target, value) * amount, 1)))
end

function CalcMagicalDamage(source, target, amount)
  local mr = target.magicResist
  local value = 100 / (100 + (mr * source.magicPenPercent) - source.magicPen)

  if mr < 0 then
    value = 2 - 100 / (100 - mr)
  elseif (mr * source.magicPenPercent) - source.magicPen < 0 then
    value = 1
  end
  return math.max(0, math.floor(DamageReductionMod(source, target, PassivePercentMod(source, target, value) * amount, 2)))
end

function DamageReductionMod(source,target,amount,DamageType)
  if source.type == Obj_AI_Hero then
    if GotBuff(source, "Exhaust") > 0 then
      amount = amount * 0.6
    end
  end

  if target.type == Obj_AI_Hero then

    for i = 0, target.buffCount do
      if target:GetBuff(i).count > 0 then
        local buff = target:GetBuff(i)
        if buff.name == "MasteryWardenOfTheDawn" then
          amount = amount * (1 - (0.06 * buff.count))
        end
    
        if DamageReductionTable[target.charName] then
          if buff.name == DamageReductionTable[target.charName].buff and (not DamageReductionTable[target.charName].damagetype or DamageReductionTable[target.charName].damagetype == DamageType) then
            amount = amount * DamageReductionTable[target.charName].amount(target)
          end
        end

        if target.charName == "Maokai" and source.type ~= Obj_AI_Turret then
          if buff.name == "MaokaiDrainDefense" then
            amount = amount * 0.8
          end
        end

        if target.charName == "MasterYi" then
          if buff.name == "Meditate" then
            amount = amount - amount * ({0.5, 0.55, 0.6, 0.65, 0.7})[target:GetSpellData(_W).level] / (source.type == Obj_AI_Turret and 2 or 1)
          end
        end
      end
    end

    if GetItemSlot(target, 1054) > 0 then
      amount = amount - 8
    end

    if target.charName == "Kassadin" and DamageType == 2 then
      amount = amount * 0.85
    end
  end

  return amount
end

function PassivePercentMod(source, target, amount, damageType)
  local SiegeMinionList = {"Red_Minion_MechCannon", "Blue_Minion_MechCannon"}
  local NormalMinionList = {"Red_Minion_Wizard", "Blue_Minion_Wizard", "Red_Minion_Basic", "Blue_Minion_Basic"}

  if source.type == Obj_AI_Turret then
    if table.contains(SiegeMinionList, target.charName) then
      amount = amount * 0.7
    elseif table.contains(NormalMinionList, target.charName) then
      amount = amount * 1.14285714285714
    end
  end
  if source.type == Obj_AI_Hero then 
    if target.type == Obj_AI_Hero then
      if (GetItemSlot(source, 3036) > 0 or GetItemSlot(source, 3034) > 0) and source.maxHealth < target.maxHealth and damageType == 1 then
        amount = amount * (1 + math.min(target.maxHealth - source.maxHealth, 500) / 50 * (GetItemSlot(source, 3036) > 0 and 0.015 or 0.01))
      end
    end
  end
  return amount
end

---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

local function Priority(charName)
  local p1 = {"Alistar", "Amumu", "Blitzcrank", "Braum", "Cho'Gath", "Dr. Mundo", "Garen", "Gnar", "Maokai", "Hecarim", "Jarvan IV", "Leona", "Lulu", "Malphite", "Nasus", "Nautilus", "Nunu", "Olaf", "Rammus", "Renekton", "Sejuani", "Shen", "Shyvana", "Singed", "Sion", "Skarner", "Taric", "TahmKench", "Thresh", "Volibear", "Warwick", "MonkeyKing", "Yorick", "Zac", "Poppy"}
  local p2 = {"Aatrox", "Darius", "Elise", "Evelynn", "Galio", "Gragas", "Irelia", "Jax", "Lee Sin", "Morgana", "Janna", "Nocturne", "Pantheon", "Rengar", "Rumble", "Swain", "Trundle", "Tryndamere", "Udyr", "Urgot", "Vi", "XinZhao", "RekSai", "Bard", "Nami", "Sona", "Camille"}
  local p3 = {"Akali", "Diana", "Ekko", "FiddleSticks", "Fiora", "Gangplank", "Fizz", "Heimerdinger", "Jayce", "Kassadin", "Kayle", "Kha'Zix", "Lissandra", "Mordekaiser", "Nidalee", "Riven", "Shaco", "Vladimir", "Yasuo", "Zilean", "Zyra", "Ryze"}
  local p4 = {"Ahri", "Anivia", "Annie", "Ashe", "Azir", "Brand", "Caitlyn", "Cassiopeia", "Corki", "Draven", "Ezreal", "Graves", "Jinx", "Kalista", "Karma", "Karthus", "Katarina", "Kennen", "KogMaw", "Kindred", "Leblanc", "Lucian", "Lux", "Malzahar", "MasterYi", "MissFortune", "Orianna", "Quinn", "Sivir", "Syndra", "Talon", "Teemo", "Tristana", "TwistedFate", "Twitch", "Varus", "Vayne", "Veigar", "Velkoz", "Viktor", "Xerath", "Zed", "Ziggs", "Jhin", "Soraka"}
  if table.contains(p1, charName) then return 1 end
  if table.contains(p2, charName) then return 1.25 end
  if table.contains(p3, charName) then return 1.75 end
  return table.contains(p4, charName) and 2.25 or 1
end

local function GetTarget(Range,t,pos)
	if _G.SDK then
		if myHero.ap > myHero.totalDamage then
			return _G.SDK.TargetSelector:GetTarget(Range, _G.SDK.DAMAGE_TYPE_MAGICAL);
		else
			return _G.SDK.TargetSelector:GetTarget(Range, _G.SDK.DAMAGE_TYPE_PHYSICAL);
		end
	elseif _G.PremiumOrbwalker then
		return _G.PremiumOrbwalker:GetTarget(Range)
	end
end
 
local castSpell = {state = 0, tick = GetTickCount(), casting = GetTickCount() - 1000, mouse = mousePos}
local function CastSpell(spell,pos,Range,delay)
local Range = Range or math.huge
local delay = delay or 250
local ticker = GetTickCount()

	if castSpell.state == 0 and GetDistance(myHero.pos,pos) < Range and ticker - castSpell.casting > delay + Game.Latency() and pos:ToScreen().onScreen then
		castSpell.state = 1
		castSpell.mouse = mousePos
		castSpell.tick = ticker
	end
	if castSpell.state == 1 then
		if ticker - castSpell.tick < Game.Latency() then
			Control.SetCursorPos(pos)
			Control.KeyDown(spell)
			Control.KeyUp(spell)
			castSpell.casting = ticker + delay
			DelayAction(function()
				if castSpell.state == 1 then
					Control.SetCursorPos(castSpell.mouse)
					castSpell.state = 0
				end
			end,Game.Latency()/1000)
		end
		if ticker - castSpell.casting > Game.Latency() then
			Control.SetCursorPos(castSpell.mouse)
			castSpell.state = 0
		end
	end
end

local function CastSpellMM(spell,pos,Range,delay)
local Range = Range or math.huge
local delay = delay or 250
local ticker = GetTickCount()
	if castSpell.state == 0 and GetDistance(myHero.pos,pos) < Range and ticker - castSpell.casting > delay + Game.Latency() then
		castSpell.state = 1
		castSpell.mouse = mousePos
		castSpell.tick = ticker
	end
	if castSpell.state == 1 then
		if ticker - castSpell.tick < Game.Latency() then
			local castPosMM = pos:ToMM()
			Control.SetCursorPos(castPosMM.x,castPosMM.y)
			Control.KeyDown(spell)
			Control.KeyUp(spell)
			castSpell.casting = ticker + delay
			DelayAction(function()
				if castSpell.state == 1 then
					Control.SetCursorPos(castSpell.mouse)
					castSpell.state = 0
				end
			end,Game.Latency()/1000)
		end
		if ticker - castSpell.casting > Game.Latency() then
			Control.SetCursorPos(castSpell.mouse)
			castSpell.state = 0
		end
	end
end

-- local castSpell = {state = 0, tick = GetTickCount(), casting = GetTickCount() - 1000, mouse = mousePos}
local function ReleaseSpell(spell,pos,Range,delay)
local delay = delay or 250
local ticker = GetTickCount()
	if castSpell.state == 0 and GetDistance(myHero.pos,pos) < Range and ticker - castSpell.casting > delay + Game.Latency() then
		castSpell.state = 1
		castSpell.mouse = mousePos
		castSpell.tick = ticker
	end
	if castSpell.state == 1 then
		if ticker - castSpell.tick < Game.Latency() then
			if not pos:ToScreen().onScreen then
				pos = myHero.pos + Vector(myHero.pos,pos):Normalized() * math.random(530,760)
				Control.SetCursorPos(pos)
				Control.KeyUp(spell)
			else
				Control.SetCursorPos(pos)
				Control.KeyUp(spell)
			end
			castSpell.casting = ticker + delay
			DelayAction(function()
				if castSpell.state == 1 then
					Control.SetCursorPos(castSpell.mouse)
					castSpell.state = 0
				end
			end,Game.Latency()/1000)
		end
		if ticker - castSpell.casting > Game.Latency() then
			Control.SetCursorPos(castSpell.mouse)
			castSpell.state = 0
		end
	end
end

local aa = {state = 1, tick = GetTickCount(), tick2 = GetTickCount(), downTime = GetTickCount(), target = myHero}
local lastTick = 0
local lastMove = 0
local aaTicker = Callback.Add("Tick", function() aaTick() end)
function aaTick()
	if aa.state == 1 and myHero.attackData.state == 2 then
		lastTick = GetTickCount()
		aa.state = 2
		aa.target = myHero.attackData.target
	end
	if aa.state == 2 then
		if myHero.attackData.state == 1 then
			aa.state = 1
		end
		if Game.Timer() + Game.Latency()/2000 - myHero.attackData.castFrame/200 > myHero.attackData.endTime - myHero.attackData.windDownTime and aa.state == 2 then
			-- print("OnAttackComp WindUP:"..myHero.attackData.endTime)
			aa.state = 3
			aa.tick2 = GetTickCount()
			aa.downTime = myHero.attackData.windDownTime*1000 - (myHero.attackData.windUpTime*1000)
			if LazyMenu.fastOrb ~= nil and LazyMenu.fastOrb:Value() then
				if GetMode() ~= "" and myHero.attackData.state == 2 then
					Control.Move()
				end
			end
		end
	end
	if aa.state == 3 then
		if GetTickCount() - aa.tick2 - Game.Latency() - myHero.attackData.castFrame > myHero.attackData.windDownTime*1000 - (myHero.attackData.windUpTime*1000)/2 then
			aa.state = 1
		end
		if myHero.attackData.state == 1 then
			aa.state = 1
		end
		if GetTickCount() - aa.tick2 > aa.downTime then
			aa.state = 1
		end
	end
end

local castAttack = {state = 0, tick = GetTickCount(), casting = GetTickCount() - 1000, mouse = mousePos}
local function CastAttack(pos,Range,delay)
local delay = delay or myHero.attackData.windUpTime*1000/2

local ticker = GetTickCount()
	if castAttack.state == 0 and GetDistance(myHero.pos,pos.pos) < Range and ticker - castAttack.casting > delay + Game.Latency() and aa.state == 1 and not pos.dead and pos.isTargetable then
		castAttack.state = 1
		castAttack.mouse = mousePos
		castAttack.tick = ticker
		lastTick = GetTickCount()
	end
	if castAttack.state == 1 then
		if ticker - castAttack.tick < Game.Latency() and aa.state == 1 then
				Control.SetCursorPos(pos.pos)
				Control.mouse_event(MOUSEEVENTF_RIGHTDOWN)
				Control.mouse_event(MOUSEEVENTF_RIGHTUP)
				castAttack.casting = ticker + delay
			DelayAction(function()
				if castAttack.state == 1 then
					Control.SetCursorPos(castAttack.mouse)
					castAttack.state = 0
				end
			end,Game.Latency()/1000)
		end
		if ticker - castAttack.casting > Game.Latency() and castAttack.state == 1 then
			Control.SetCursorPos(castAttack.mouse)
			castAttack.state = 0
		end
	end
end

local castMove = {state = 0, tick = GetTickCount(), mouse = mousePos}
local function CastMove(pos)
local movePos = pos or mousePos
Control.KeyDown(HK_TCO)
Control.mouse_event(MOUSEEVENTF_RIGHTDOWN)
Control.mouse_event(MOUSEEVENTF_RIGHTUP)
Control.KeyUp(HK_TCO)
end

--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

class "LazyXerath"

function LazyXerath:Spells()
	self.Q = Spell({
		Slot = 0,
		Range = 750,
		Delay = 0.5,
		Speed = huge,
		Width = 250,
		Collision = false,
		From = myHero,
		Type = "SkillShot"
	})
	self.W = Spell({
		Slot = 1,
		Range = 1000,
		Delay = 0.5,
		Speed = huge,
		Radius = 200,
		Width = 200,
		Collision = false,
		From = myHero,
		Type = "AOE"
	})
	self.E = Spell({
		Slot = 2,
		Range = 1125,
		Delay = 0.25,
		Speed = 1400,
		Width = 80,
		Collision = true,
		From = myHero,
		Type = "Skillshot"
	})
	self.R = Spell({
		Slot = 3,
		Range = 5000,
		Delay = 0.627,
		Speed = huge,
		Width = 200,
		Collision = false,
		From = myHero,
		Type = "AOE"
	})
	self.Q.MaxRange = 1400
end

function LazyXerath:__init()
	print("Jiingz Xerath Loaded")
	self:Spells()
	self.spellIcons = { Q = "http://vignette3.wikia.nocookie.net/leagueoflegends/images/5/57/Arcanopulse.png",
						W = "http://vignette1.wikia.nocookie.net/leagueoflegends/images/2/20/Eye_of_Destruction.png",
						E = "http://vignette2.wikia.nocookie.net/leagueoflegends/images/6/6f/Shocking_Orb.png",
						R = "http://vignette1.wikia.nocookie.net/leagueoflegends/images/3/37/Rite_of_the_Arcane.png"}
	self.AA = { delay = 0.25, speed = 2000, width = 0, Range = 550 }
	
	
	
	local QspellData = {speed = self.Q.Speed,	Range = self.Q.Range, 	delay = self.Q.Delay + Game.Latency() / 1000, 	radius = self.Q.Width, 	collision = {nil}, 		type = "linear"}
	local WspellData = {speed = self.W.Speed,	Range = self.W.Range, 	delay = self.W.Delay + Game.Latency() / 1000, 	radius = self.W.Width, 	collision = {nil}, 		type = "circular"}
	local EspellData = {speed = self.E.Speed, 	Range = self.E.Range, 	delay = self.E.Delay + Game.Latency() / 1000, 	radius = self.E.Width, 	collision = {"minion"}, type = "linear"}
	local RspellData = {speed = self.R.Speed, 	Range = self.R.Range, 	delay = self.R.Delay + Game.Latency() / 1000, 	radius = self.R.Width, 	collision = {nil}, 		type = "circular"}
	
	self.Range = 550
	self.chargeQ = false
	self.qTick = GetTickCount()
	self.chargeR = false
	self.chargeRTick = GetTickCount()
	self.R_target = nil
	self.R_target_tick = GetTickCount()
	self.firstRCast = true
	self.R_Stacks = 0
	self.lastRtick = GetTickCount()
	self.CanUseR = true
	self.lastTarget = nil
	self.lastTarget_tick = GetTickCount()
	self:Menu()
	function OnTick() self:Tick() end
 	function OnDraw() self:Draw() end
end

function LazyXerath:Menu()
	LazyMenu.Combo:MenuElement({id = "useQ", name = "Use Q", value = true})
	LazyMenu.Combo:MenuElement({id = "legitQ", name = "Legit Q slider", value = 0.075, min = 0, max = 0.15, step = 0.01})
	LazyMenu.Combo:MenuElement({id = "useW", name = "Use W", value = true})
	LazyMenu.Combo:MenuElement({id = "useE", name = "Use E", value = true})
	LazyMenu.Combo:MenuElement({id = "useR", name = "Use R", value = true})
	LazyMenu.Combo:MenuElement({id = "R", name = "Ultimate Settings", type = MENU})
	LazyMenu.Combo.R:MenuElement({id = "useRself", name = "Start R manually", value = false})
	LazyMenu.Combo.R:MenuElement({id = "BlackList", name = "Auto R blacklist", type = MENU})
	LazyMenu.Combo.R:MenuElement({id = "safeR", name = "Safety R stack", value = 1, min = 0, max = 2, step = 1})
	LazyMenu.Combo.R:MenuElement({id = "targetChangeDelay", name = "Delay between target switch", value = 100, min = 0, max = 2000, step = 10})
	LazyMenu.Combo.R:MenuElement({id = "castDelay", name = "Delay between casts", value = 150, min = 0, max = 500, step = 1})
	LazyMenu.Combo.R:MenuElement({id = "useBlue", name = "Use Farsight Alteration", value = true})
	LazyMenu.Combo.R:MenuElement({id = "useRkey", name = "On key press (close to mouse)", key = string.byte("T")})
	
	--LazyMenu.Debug:MenuElement({id = "DrawQ", name = "Draw Q Prediction", value = true})
	--LazyMenu.Debug:MenuElement({id = "DrawW", name = "Draw W Prediction", value = true})
	--LazyMenu.Debug:MenuElement({id = "DrawE", name = "Draw E Prediction", value = true})
	--LazyMenu.Debug:MenuElement({id = "DrawR", name = "Draw R Prediction", value = true})

	LazyMenu.Drawings:MenuElement({id = "DrawQRange", name = "Draw Q", value = true})
	LazyMenu.Drawings:MenuElement({id = "DrawWRange", name = "Draw W", value = true})
	LazyMenu.Drawings:MenuElement({id = "DrawERange", name = "Draw E", value = true})
	LazyMenu.Drawings:MenuElement({id = "DrawKillable", name = "Draw Killable with R", value = true})

	LazyMenu.Harass:MenuElement({id = "useQ", name = "Use Q", value = true})
	LazyMenu.Harass:MenuElement({id = "manaQ", name = " Q | Mana-Manager", value = 40, min = 0, max = 100, step = 1})
	LazyMenu.Harass:MenuElement({id = "useW", name = "Use W", value = true})
	LazyMenu.Harass:MenuElement({id = "manaW", name = " W | Mana-Manager", value = 60, min = 0, max = 100, step = 1})
	LazyMenu.Harass:MenuElement({id = "useE", name = "Use E", value = false})
	LazyMenu.Harass:MenuElement({id = "manaE", name = " E | Mana-Manager", value = 80, min = 0, max = 100, step = 1})
	
	LazyMenu.Clear:MenuElement({id = "useQ", name = "Use Q", value = true})
	LazyMenu.Clear:MenuElement({id = "manaQ", name = " [Q]Mana-Manager", value = 40, min = 0, max = 100, step = 1})
	LazyMenu.Clear:MenuElement({id = "hitQ", name = "min Minions Use Q", value = 2, min = 1, max = 6, step = 1})

	LazyMenu.Killsteal:MenuElement({id = "useQ", name = "Use Q to killsteal", value = true})
	LazyMenu.Killsteal:MenuElement({id = "useW", name = "Use W to killsteal", value = true})
	
	LazyMenu.Misc:MenuElement({id = "gapE", name = "Use E on gapcloser (beta)", value = true})
	LazyMenu.Misc:MenuElement({id = "drawRRange", name = "Draw R Range on minimap", value = true})
	
	LazyMenu:MenuElement({id = "TargetSwitchDelay", name = "Delay between target switch", value = 350, min = 0, max = 750, step = 1})
	self:TargetMenu()
	LazyMenu:MenuElement({id = "space", name = "Don't forget to turn off default [COMBO] orbwalker!", type = SPACE, onclick = function() LazyMenu.space:Hide() end})
end

local create_menu_tick
function LazyXerath:TargetMenu()
	create_menu_tick = Callback.Add("Tick",function() 
		for i,v in pairs(GetEnemyHeroes()) do
			self:MenuRTarget(v,create_menu_tick)
		end
	end)
end

function LazyXerath:MenuRTarget(v,t)
	if LazyMenu.Combo.R.BlackList[v.charName] ~= nil then
		-- Callback.Del("Tick",create_menu_tick)
	else
		LazyMenu.Combo.R.BlackList:MenuElement({id = v.charName, name = "Blacklist: "..v.charName, value = false})
	end
end

function LazyXerath:Tick()
	if _G.JustEvade and _G.JustEvade:Evading() or Game.IsChatOpen() then return end
	self:castingQ()
	self:castingR()
	if myHero.dead then return end
	self:useRonKey()
	local rBuff = GetBuffData(myHero,"xerathrshots")
	if rBuff.count > 0 or GetMode() == "Combo" then
		SetMovement(false)
		SetAttack(false)
	else
		SetMovement(true)
		SetAttack(true)
	end
	if GetMode() == "Combo" then
		if aa.state ~= 2 then
			self:Combo()
		end
		self:ComboOrb()
	elseif GetMode() == "LaneClear" then
		if aa.state ~= 2 then
			self:LaneClear()
		end
	elseif GetMode() == "Harass" then
		if aa.state ~= 2 then
			self:Harass()
		end
	end
	self:EnemyLoop()
end

function LazyXerath:Draw()
if myHero.dead then return end
	if LazyMenu.Combo.R.useRkey:Value() then
		Draw.Circle(mousePos,500)
	end
	if LazyMenu.Misc.drawRRange:Value() and self.chargeR == false then
		if Game.CanUseSpell(_R) == 0 then
			Draw.CircleMinimap(myHero.pos, 5000,1.5,Draw.Color(200,50,180,230))
		end
	end
	
	if LazyMenu.Drawings.DrawQRange:Value() then
		Draw.Circle(myHero.pos, 1400, 5, Draw.Color(255,0,0,230))
	end

	if LazyMenu.Drawings.DrawWRange:Value() then
		Draw.Circle(myHero.pos, self.W.Range, 5, Draw.Color(255, 0, 255, 0))
	end

	if LazyMenu.Drawings.DrawERange:Value() then
		Draw.Circle(myHero.pos, self.E.Range, 5, Draw.Color(255, 255, 0, 0))
	end


	if LazyMenu.Drawings.DrawKillable:Value() then 
		for i,hero in pairs(GetEnemyHeroes()) do
			if hero.isEnemy and hero.valid and not hero.dead and hero.isTargetable and (OnVision(hero).state == true or (OnVision(hero).state == false and GetTickCount() - OnVision(hero).tick < 50)) and hero.isTargetable and GetDistance(myHero.pos,hero.pos) < 5000 then
				local rDMG = getdmg("R", hero, myHero) * (2 + myHero:GetSpellData(_R).level) - LazyMenu.Combo.R.safeR:Value()
				if hero.health + hero.shieldAP + hero.shieldAD < rDMG then
					local res = Game.Resolution()
      				Draw.Text(hero.charName.. " Is killable with ".. (2 + myHero:GetSpellData(_R).level) - LazyMenu.Combo.R.safeR:Value().. " Ult Shots!!", 64, res.x / 2 - 250 - (#hero.charName * 30), res.y / 2 -380, Draw.Color(255, 255, 0, 0))
				end
			end
		end
	end
	
	
end

function LazyXerath:ComboOrb()
	if self.chargeR == false and castSpell.state == 0 then
		local target = GetTarget(610)
		local tick = GetTickCount()
		if target then
			if aa.state == 1 and self.chargeQ == false and GetDistance(myHero.pos,target.pos) < 575 and ((Game.CanUseSpell(_Q) ~= 0 and Game.CanUseSpell(_W) ~= 0 and Game.CanUseSpell(_E) ~= 0) or GotBuff(myHero,"xerathascended2onhit") > 0 ) then
				CastAttack(target,575)
			elseif aa.state ~= 2 and tick - lastMove > 30 then
				Control.Move()
				lastMove = tick
			end
		else
			if aa.state ~= 2 and tick - lastMove > 30 then
				Control.Move()
				lastMove = tick
			end
		end
	end
end

function LazyXerath:castingQ()
	if self.chargeQ == true then
		self.Q.Range = 750 + 500*(GetTickCount()-self.qTick)/1000
		if self.Q.Range > 1400 then self.Q.Range = 1400 end
	end
	local qBuff = GetBuffData(myHero,"XerathArcanopulseChargeUp")
	if self.chargeQ == false and qBuff.count > 0 then
		self.qTick = GetTickCount()
		self.chargeQ = true
	end
	if self.chargeQ == true and qBuff.count == 0 then
		self.chargeQ = false
		self.Q.Range = 750
		if Control.IsKeyDown(HK_Q) == true then
			Control.KeyUp(HK_Q)
		end
	end
	if Control.IsKeyDown(HK_Q) == true and self.chargeQ == false then
		DelayAction(function()
			if Control.IsKeyDown(HK_Q) == true and self.chargeQ == false then
				Control.KeyUp(HK_Q)
			end
		end,0.3)
	end
	if Control.IsKeyDown(HK_Q) == true and Game.CanUseSpell(_Q) ~= 0 then
		DelayAction(function()
			if Control.IsKeyDown(HK_Q) == true then
				self.Q.Range = 750
				Control.KeyUp(HK_Q)
			end
		end,0.01)
	end
end

function LazyXerath:castingR()
	local rBuff = GetBuffData(myHero,"XerathLocusOfPower2")
	if self.chargeR == false and rBuff.count > 0 then
		self.chargeR = true
		self.chargeRTick = GetTickCount()
		self.firstRCast = true
	end
	if self.chargeR == true and rBuff.count == 0 then
		self.chargeR = false
		self.R_target = nil
	end
	if self.chargeR == true then
		if self.CanUseR == true and Game.CanUseSpell(_R) ~= 0 and GetTickCount() - self.chargeRTick > 600 then
			self.CanUseR = false
			self.R_Stacks = self.R_Stacks - 1
			self.firstRCast = false
			self.lastRtick = GetTickCount()
		end
		if self.CanUseR == false and Game.CanUseSpell(_R) == 0 then
			self.CanUseR = true
		end
	end
	if self.chargeR == false then
		if Game.CanUseSpell(_R) == 0 then
			self.R_Stacks = 2+myHero:GetSpellData(_R).level
		end
	end
end

function LazyXerath:Combo()
	if self.chargeR == false then
		if LazyMenu.Combo.useW:Value() then
			self:useW()
		end
		if LazyMenu.Combo.useE:Value() then
			self:useE()
		end
		if LazyMenu.Combo.useQ:Value() then
			self:useQ()
		end
	end
	self:useR()
end

function LazyXerath:Harass()
	if self.chargeR == false then
		local mp = GetPercentMP(myHero)
		if LazyMenu.Harass.useW:Value() and mp > LazyMenu.Harass.manaW:Value() then
			self:useW()
		end
		if LazyMenu.Harass.useE:Value() and mp > LazyMenu.Harass.manaE:Value() then
			self:useE()
		end
		if LazyMenu.Harass.useQ:Value() and (mp > LazyMenu.Harass.manaQ:Value() or self.chargeQ == true) then	
			self:useQ()
		end
	end
end

function LazyXerath:LaneClear()
	if self.chargeR == false then
		local mp = 100*myHero.mana/myHero.maxMana
		if LazyMenu.Clear.useQ:Value() and (mp > LazyMenu.Clear.manaQ:Value() or self.chargeQ == true) then
			self:clearQ()
		end
	end
end

function LazyXerath:useQonMinion(minion,qPred)
	if Game.Timer() - OnWaypoint(minion).time > 0.05 and (((Game.Timer() - OnWaypoint(minion).time < 0.15 or Game.Timer() - OnWaypoint(minion).time > 1.0) and OnVision(minion).state == true) or (OnVision(minion).state == false)) and GetDistance(myHero.pos,qPred) < self.Q.Range - minion.boundingRadius then
		ReleaseSpell(HK_Q,qPred,self.Q.Range,100)
		self.lastMinion = minion
		self.lastMinion_tick = GetTickCount() + 200
	end
end

function LazyXerath:clearQ()
	if Game.CanUseSpell(_Q) == 0 and castSpell.state == 0 then
		for i = 1, Game.MinionCount() do
		local minion = Game.Minion(i)
		local qPred = self.Q:GetPrediction(minion)
		local count = GetMinionCount(150, minion)		
			if minion.team == (300 - myHero.team) and qPred then
				if GetDistance(myHero.pos,qPred) < 1400 and count >= LazyMenu.Clear.hitQ:Value() then
					self:startQ(minion)
				end
				if self.chargeQ == true then
					self:useQonMinion(minion,qPred)
				end
			end
			if minion.team == 300 and qPred then
				if GetDistance(myHero.pos,qPred) < 1400 then
					self:startQ(minion)
				end
				if self.chargeQ == true then
					self:useQonMinion(minion,qPred)
				end
			end			
		end
	end
end

function LazyXerath:useQ()
	if Game.CanUseSpell(_Q) == 0 and castSpell.state == 0 then
		local target = GetTarget(1500,"AP")
		if target then
			local QspellData = {speed = self.Q.Speed,	range = self.Q.Range, 	delay = self.Q.Delay + Game.Latency() / 1000, 	radius = self.Q.Width, 	collision = {nil}, 		type = "linear"}
			local qPred = _G.PremiumPrediction:GetPrediction(myHero, target, QspellData)
			QspellData = {speed = huge,	range = self.Q.Range, 	delay = 1 + Game.Latency() / 1000, 	radius = 250, 	collision = {nil}, 		type = "linear"}
			local qPred2 = _G.PremiumPrediction:GetPrediction(myHero, target, QspellData)
			if qPred.CastPos and qPred2.CastPos then
				if GetDistance(myHero.pos,qPred.CastPos) < 1500 then
					self:startQ(target)
				end
				if self.chargeQ == true then
					self:useQclose(target,qPred2.CastPos)
					self:useQCC(target)
					self:useQonTarget(target,qPred2.CastPos)
				end
			end
		end
	end
end

function LazyXerath:useW()
	if Game.CanUseSpell(_W) == 0 and self.chargeQ == false and castSpell.state == 0 then
		local target = GetTarget(self.W.Range,"AP")
		if self.lastTarget == nil then self.lastTarget = target end
		if target and (target == self.lastTarget or (GetDistance(target.pos,self.lastTarget.pos) > 400 and GetTickCount() - self.lastTarget_tick > LazyMenu.TargetSwitchDelay:Value())) then
			local WSpellData = {speed = huge,	range = 1000, 	delay = 0.5, 	radius = 200, 	collision = {nil}, 		type = "circular"}
			local wPred = _G.PremiumPrediction:GetPrediction(myHero, target, WSpellData)
			if wPred.CastPos then
				self:useWdash(target)
				self:useWCC(target)
				self:useWkill(target,wPred.CastPos)
				self:useWhighHit(target,wPred.CastPos)
			end
		end
	end
end

function LazyXerath:useE()
	if Game.CanUseSpell(_E) == 0 and self.chargeQ == false and castSpell.state == 0 then
		self:useECC()
		local target = GetTarget(self.E.Range,"AP")
		if self.lastTarget == nil then self.lastTarget = target end
		if target and (target == self.lastTarget or (GetDistance(target.pos,self.lastTarget.pos) > 400 and GetTickCount() - self.lastTarget_tick > LazyMenu.TargetSwitchDelay:Value())) then
			local ESpellData = {speed = 1400,	range = 1125, 	delay = 0.25, 	radius = 80, 	collision = {"minion"}, 		type = "linear"}
			local ePred = _G.PremiumPrediction:GetPrediction(myHero, target, ESpellData)
			if ePred.CastPos then
				self:useEdash(target)
				self:useEbrainAFK(target,ePred.CastPos)
			end
		end
	end
end

function LazyXerath:useR()
	if Game.CanUseSpell(_R) == 0 and self.chargeQ == false and castSpell.state == 0 then
		local target = self:GetRTarget(1100,5000)
		if target then
			self:useRkill(target)
			if ((self.firstRCast == true or self.chargeR ~= true) or (GetTickCount() - self.lastRtick > 500 + LazyMenu.Combo.R.targetChangeDelay:Value() and GetDistance(target.pos,self.R_target.pos) > 750) or (GetDistance(target.pos,self.R_target.pos) <= 850)) and target ~= self.R_target then
				self.R_target = target
			end
			-- if target == self.R_target or (target ~= self.R_target and GetDistance(target.pos,self.R_target.pos) > 600 and GetTickCount() - self.lastRtick > 800 + LazyMenu.Combo.R.targetChangeDelay:Value()) then
			if target == self.R_target then
				if self.chargeR == true and GetTickCount() - self.lastRtick >= 800 + LazyMenu.Combo.R.castDelay:Value() then
					if target and not IsImmune(target) and (Game.Timer() - OnWaypoint(target).time > 0.05 and (Game.Timer() - OnWaypoint(target).time < 0.20 or Game.Timer() - OnWaypoint(target).time > 1.25) or IsImmobileTarget(target) == true or (self.firstRCast == true and OnVision(target).state == false) ) then
					    local RSpellData = {speed = huge,	range = 5000, 	delay = 0.627, 	radius = 80, 	collision = {}, 		type = "circular"}
						local rPred = _G.PremiumPrediction:GetPrediction(myHero, target, RSpellData)
						if target.pos2D.onScreen then
							CastSpell(HK_R,rPred.CastPos,5000,100)
							self.R_target = target
						else
							CastSpellMM(HK_R,rPred.CastPos,5000,100)
							self.R_target = target
						end
					end
				end
			end
		end
	end
end

function LazyXerath:EnemyLoop()
	if aa.state ~= 2 and castSpell.state == 0 then
		for i,target in pairs(GetEnemyHeroes()) do
			if not target.dead and target.isTargetable and target.valid and (OnVision(target).state == true or (OnVision(target).state == false and GetTickCount() - OnVision(target).tick < 500)) then
				if LazyMenu.Killsteal.useQ:Value() then
					if Game.CanUseSpell(_Q) == 0 and GetDistance(myHero.pos,target.pos) < 1500 then
						local hp = target.health + target.shieldAP + target.shieldAD
						local dmg = getdmg("Q", target, myHero)
						if hp < dmg then
							if self.chargeQ == false then
								local qPred2 = self.Q:GetPrediction(target)
								if GetDistance(qPred2,myHero.pos) < 1500 then
									Control.KeyDown(HK_Q)
								end
							else
								local qPred = self.Q:GetPrediction(target)
								self:useQonTarget(target,qPred)
							end
						end
					end
				end
				if LazyMenu.Killsteal.useW:Value() then
					if Game.CanUseSpell(_W) == 0 and GetDistance(myHero.pos,target.pos) < self.W.Range then
						local wPred = self.W:GetPrediction(target)
						self:useWkill(target,wPred)
					end
				end
				if LazyMenu.Misc.gapE:Value() and Game.CanUseSpell(_E) == 0 then
					if GetDistance(target.posTo,myHero.pos) < 500 then
						self:useEdash(target)
					end
				end
			end
		end
	end
end

function LazyXerath:startQ(target)
	local start = true
	if LazyMenu.Combo.useE:Value() and Game.CanUseSpell(_E) == 0 and GetDistance(target.pos,myHero.pos) < 650 and target:GetCollision(self.E.width,self.E.speed,self.E.delay) == 0 then start = false end
	if Game.CanUseSpell(_Q) == 0 and self.chargeQ == false and start == true then
		Control.KeyDown(HK_Q)
	end
end

function LazyXerath:useQCC(target)
	if GetDistance(myHero.pos,target.pos) < self.Q.Range - 20 then
		if IsImmobileTarget(target) == true then
			ReleaseSpell(HK_Q,target.pos,self.Q.Range,100)
			self.lastTarget = target
			self.lastTarget_tick = GetTickCount() + 200
		end
	end
end

function LazyXerath:useQonTarget(target,qPred)
	if Game.Timer() - OnWaypoint(target).time > 0.05 + LazyMenu.Combo.legitQ:Value() and (((Game.Timer() - OnWaypoint(target).time < 0.15 + LazyMenu.Combo.legitQ:Value() or Game.Timer() - OnWaypoint(target).time > 1.0) and OnVision(target).state == true) or (OnVision(target).state == false)) and GetDistance(myHero.pos,qPred) < self.Q.Range - target.boundingRadius then
		ReleaseSpell(HK_Q,qPred,self.Q.Range,100)
		self.lastTarget = target
		self.lastTarget_tick = GetTickCount() + 200
	end
end

function LazyXerath:useQclose(target,qPred)
	if GetDistance(myHero.pos,qPred) < 750 and Game.Timer() - OnWaypoint(target).time > 0.05 then
		ReleaseSpell(HK_Q,qPred,self.Q.Range,75)
		self.lastTarget = target
		self.lastTarget_tick = GetTickCount() + 200
	end
end

function LazyXerath:useWCC(target)
	if GetDistance(myHero.pos,target.pos) < self.W.Range - 50 then
		if IsImmobileTarget(target) == true then
			CastSpell(HK_W,target.pos,self.W.Range)
			self.lastTarget = target
			self.lastTarget_tick = GetTickCount() + 200
		end
	end
end

function LazyXerath:useWhighHit(target,wPred)
	local afterE = false
	if LazyMenu.Combo.useE:Value() and Game.CanUseSpell(_E) == 0 and myHero:GetSpellData(_W).mana + myHero:GetSpellData(_E).mana <= myHero.mana and GetDistance(myHero.pos,target.pos) <= 750 then
		if target:GetCollision(self.E.width,self.E.speed,self.E.delay) == 0 then
			afterE = true
		end
	end
	if Game.Timer() - OnWaypoint(target).time > 0.05 and (Game.Timer() - OnWaypoint(target).time < 0.20 or Game.Timer() - OnWaypoint(target).time > 1.25) and GetDistance(myHero.pos,wPred) < self.W.Range - 50 and afterE == false then
		CastSpell(HK_W,wPred,self.W.Range)
		self.lastTarget = target
		self.lastTarget_tick = GetTickCount() + 200
	end
end

function LazyXerath:useWdash(target)
	if OnWaypoint(target).speed > target.ms then
	
		local wPred = self.W.GetPrediction(target)
		if GetDistance(myHero.pos,wPred) < self.W.Range then
			CastSpell(HK_W,wPred,self.W.Range)
			self.lastTarget = target
			self.lastTarget_tick = GetTickCount() + 200
		end
	end
end

function LazyXerath:useWkill(target,wPred)
	if Game.Timer() - OnWaypoint(target).time > 0.05 and GetDistance(myHero.pos,wPred) < self.W.Range then
		if target.health + target.shieldAP + target.shieldAD < CalcMagicalDamage(myHero,target,30 + 30*myHero:GetSpellData(_W).level + (0.6*myHero.ap)) then
			CastSpell(HK_W,wPred,self.W.Range)
		end
	end
end

function LazyXerath:useECC()
	local target = GetTarget(self.E.Range,"AP")
	if target then
		if GetDistance(myHero.pos,target.pos) < self.E.Range - 20 then
			if IsImmobileTarget(target) == true and target:GetCollision(self.E.width,self.E.speed,0.25) == 0 then
				CastSpell(HK_E,target.pos,5000)
				self.lastTarget = target
				self.lastTarget_tick = GetTickCount() + 200
			end
		end
	end
end

function LazyXerath:useEbrainAFK(target,ePred)
	if Game.Timer() - OnWaypoint(target).time > 0.05 and (Game.Timer() - OnWaypoint(target).time < 0.125 or Game.Timer() - OnWaypoint(target).time > 1.25) and GetDistance(myHero.pos,ePred) < self.E.Range then
		if GetDistance(myHero.pos,ePred) <= 800 then
			CastSpell(HK_E,ePred,5000)
			self.lastTarget = target
			self.lastTarget_tick = GetTickCount() + 200
		else
			if target.ms < 340 then
				CastSpell(HK_E,ePred,5000)
				self.lastTarget = target
				self.lastTarget_tick = GetTickCount() + 200
			end
		end
	end
end

function LazyXerath:useEdash(target)
	if OnWaypoint(target).speed > target.ms then
		local ePred = self.E:GetPrediction(target)
		if GetDistance(myHero.pos,ePred) < self.E.Range and target:GetCollision(self.E.Width,self.E.Speed,1) == 0 then
			CastSpell(HK_E,ePred,5000)
			self.lastTarget = target
			self.lastTarget_tick = GetTickCount() + 200
		end
	end
end

function LazyXerath:startR(target)
	local eAallowed = 0
	if GetDistance(myHero.pos,target.pos) < 1200 + 250 * myHero:GetSpellData(_R).level and target.visible then
		eAallowed = 1
	end
	if self.chargeR == false and CountEnemiesInRange(myHero.pos,2500) <= eAallowed and GetDistance(myHero.pos,target.pos) > 1300 and not (GetDistance(myHero.pos,target.pos) < 1500 and Game.CanUseSpell(_Q) == 0) and (OnVision(target).state == true or (OnVision(target).state == false and GetTickCount() - OnVision(target).tick < 50)) then
		if LazyMenu.Combo.R.useBlue:Value() then
			local blue = GetItemSlot(myHero,3363)
			if blue > 0 and CanUseSpell(blue) and OnVision(target).state == false and GetDistance(myHero.pos,target.pos) < 3800 then
				-- this doesn't actually work, but i'm going to leave it alone because i really don't want to mess with it...
				local bluePred = GetPred(target,math.huge,0.25)
				CastSpellMM(HK_ITEM_7,bluePred,4000,50)
			else
				CastSpell(HK_R,myHero.pos + Vector(myHero.pos,target.pos):Normalized() * math.random(500,800),5000,50)
			end
		else
			CastSpell(HK_R,myHero.pos + Vector(myHero.pos,target.pos):Normalized() * math.random(500,800),5000,50)
		end
		self.R_target = target
		self.firstRCast = true
	end
end

function LazyXerath:useRkill(target)
	if self.chargeR == false and LazyMenu.Combo.R.BlackList[target.charName] ~= nil and not LazyMenu.Combo.R.useRself:Value() and LazyMenu.Combo.R.BlackList[target.charName]:Value() == false then
		local rDMG = getdmg("R", target, myHero) * (2 + myHero:GetSpellData(_R).level) - LazyMenu.Combo.R.safeR:Value()
		if target.health + target.shieldAP + target.shieldAD < rDMG and CountAlliesInRange(target.pos,700) == 0 then
			local delay =  math.floor((target.health + target.shieldAP + target.shieldAD)/(rDMG/(2+myHero:GetSpellData(_R).level))) * 0.8
			if GetDistance(myHero.pos,target.pos) + target.ms*delay <= 5000 and not IsImmune(target) then
				self:startR(target)
			end
		end
	end
end

function LazyXerath:useRonKey()
	if LazyMenu.Combo.R.useRkey:Value() then
		if self.chargeR == true and Game.CanUseSpell(_R) == 0 then
			local target = GetTarget(500,"AP",mousePos)
			if not target then target = GetTarget(5000,"AP") end
			if target and not IsImmune(target) then
			    local RSpellData = {speed = huge,	range = 5000, 	delay = 0.627, 	radius = 80, 	collision = {}, 		type = "circular"}
				local rPred = _G.PremiumPrediction:GetPrediction(myHero, target, RSpellData)
				if target.pos2D.onScreen then
					CastSpell(HK_R,rPred.CastPos,5000,100)
					self.R_target = target
					self.R_target_tick = GetTickCount()
				else
					CastSpellMM(HK_R,rPred.CastPos,5000,100)
					self.R_target = target
					self.R_target_tick = GetTickCount()
				end
			end
		end
	end
end

local _targetSelect
local _targetSelectTick = GetTickCount()
function LazyXerath:GetRTarget(closeRange,maxRange)
local tick = GetTickCount()
if tick - _targetSelectTick > 200 then
	_targetSelectTick = tick
	local killable = {}
		for i,hero in pairs(GetEnemyHeroes()) do
			if hero.isEnemy and hero.valid and not hero.dead and hero.isTargetable and (OnVision(hero).state == true or (OnVision(hero).state == false and GetTickCount() - OnVision(hero).tick < 50)) and hero.isTargetable and GetDistance(myHero.pos,hero.pos) < maxRange then
				local rDMG = getdmg("R", hero, myHero) * (2 + myHero:GetSpellData(_R).level) - LazyMenu.Combo.R.safeR:Value()
				if hero.health + hero.shieldAP + hero.shieldAD < rDMG then
					killable[hero.networkID] = hero
				end
			end
		end
		local target
		local p = 0
		local oneshot = false
		for i,kill in pairs(killable) do
			if (CalcMagicalDamage(myHero,kill,170+30*myHero:GetSpellData(_R).level + (myHero.ap*0.43)) > kill.health + kill.shieldAP + kill.shieldAD) then
				if p < Priority(kill.charName) then
					p = Priority(kill.charName)
					target = kill
					oneshot = true
				end
			else
				if p < Priority(kill.charName) and oneshot == false then
					p = Priority(kill.charName)
					target = kill
				end
			end
		end
		if target then
			_targetSelect = target
			return _targetSelect
		end
	if CountEnemiesInRange(myHero.pos,closeRange) >= 2 then
		local t = GetTarget(closeRange,"AP")
		_targetSelect = t
		return _targetSelect
	else
		local t = GetTarget(maxRange,"AP")
		_targetSelect = t
		return _targetSelect
	end
end

if _targetSelect and not _targetSelect.dead then
	return _targetSelect
else
	_targetSelect = GetTarget(maxRange,"AP")
	return _targetSelect
end

end

function OnLoad() LazyXerath() end




{"mode":"full","isActive":false}