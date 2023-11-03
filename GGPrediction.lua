local Version = 1.56
local Name = "GGPrediction"

Callback.Add("Load", function()
	GGUpdate:New({
		version = Version,
		scriptName = Name,
		scriptPath = COMMON_PATH .. Name .. ".lua",
		scriptUrl = "https://raw.githubusercontent.com/4risto/GoS/master/" .. Name .. ".lua",
		versionPath = COMMON_PATH .. Name .. ".version",
		versionUrl = "https://raw.githubusercontent.com/4risto/GoS/master/" .. Name .. ".version",
	})
end)

if _G.GGPrediction then
	return
end

local math_huge = math.huge
local math_pi = math.pi
local math_sqrt = assert(math.sqrt)
local math_abs = assert(math.abs)
local math_min = assert(math.min)
local math_max = assert(math.max)
local math_pow = assert(math.pow)
local math_atan = assert(math.atan)
local math_acos = assert(math.acos)
local table_remove = assert(table.remove)
local table_insert = assert(table.insert)
local Game, Vector, Draw, Callback = _G.Game, _G.Vector, _G.Draw, _G.Callback
local Menu, Immobile, Math, Path, UnitData, ObjectManager, Collision, Prediction
local COLLISION_MINION = 0
local COLLISION_ALLYHERO = 1
local COLLISION_ENEMYHERO = 2
local COLLISION_YASUOWALL = 3
local HITCHANCE_IMPOSSIBLE = 0
local HITCHANCE_COLLISION = 1
local HITCHANCE_NORMAL = 2
local HITCHANCE_HIGH = 3
local HITCHANCE_IMMOBILE = 4
local SPELLTYPE_LINE = 0
local SPELLTYPE_CIRCLE = 1
local SPELLTYPE_CONE = 2

-- stylua: ignore start
local __menu = MenuElement({name = "GG Prediction", id = "GGPrediction", type = _G.MENU})

Menu =
{
    MaxRange = __menu:MenuElement({id = "PredMaxRange" .. myHero.charName, name = "Pred Max Range %", value = 100, min = 70, max = 100, step = 1}),
    Latency = __menu:MenuElement({id = "Latency", name = "Ping/Latency", value = 50, min = 0, max = 200, step = 5}),
    ExtraDelay = __menu:MenuElement({id = "ExtraDelay", name = "Extra Delay", value = 60, min = 0, max = 100, step = 5}),
    VersionA = __menu:MenuElement({name = '', type = _G.SPACE, id = 'VersionSpaceA'}),
    VersionB = __menu:MenuElement({name = 'Version  ' .. Version, type = _G.SPACE, id = 'VersionSpaceB'}),
}
-- stylua: ignore end

function Menu:GetMaxRange()
	local result = self.MaxRange:Value() * 0.01
	return result
end

function Menu:GetLatency()
	local result = self.Latency:Value() * 0.001
	return result
end

function Menu:GetExtraDelay()
	local result = self.ExtraDelay:Value() * 0.001
	return result
end
--[[
enum class BuffType {
    Internal = 0,
    Aura = 1,
    CombatEnchancer = 2,
    CombatDehancer = 3,
    SpellShield = 4,
    Stun = 5,
    Invisibility = 6,
    Silence = 7,
    Taunt = 8,
    Berserk = 9,
    Polymorph = 10,
    Slow = 11,
    Snare = 12,
    Damage = 13,
    Heal = 14,
    Haste = 15,
    SpellImmunity = 16,
    PhysicalImmunity = 17,
    Invulnerability = 18,
    AttackSpeedSlow = 19,
    NearSight = 20,
    Fear = 22,
    Charm = 23,
    Poison = 24,
    Suppression = 25,
    Blind = 26,
    Counter = 27,
    Currency = 21,
    Shred = 28,
    Flee = 29,
    Knockup = 30,
    Knockback = 31,
    Disarm = 32,
    Grounded = 33,
    Drowsy = 34,
    Asleep = 35,
    Obscured = 36,
    ClickProofToEnemies = 37,
    Unkillable = 38
};
--]]

Immobile = {
	IMMOBILE_TYPES = {
		[5] = true,
		[8] = true,
		[12] = true,
		[22] = true,
		[23] = true,
		[25] = true,
		[30] = true,
		--[35] = true -> asleep zoe e, new move clicks??
	},
}

function Immobile:GetDuration(unit)
	local SpellCastTime = 0
	local AttackCastTime = 0
	local ImmobileDuration = 0
	local KnockDuration = 0
	if unit.pathing.hasMovePath then
		return ImmobileDuration, SpellCastTime, AttackCastTime, KnockDuration
	end
	local buffs = SDK.BuffManager:GetBuffs(unit)
	for i = 1, #buffs do
		local buff = buffs[i]
		local duration = buff.duration
		if duration > 0 then
			if duration > ImmobileDuration and self.IMMOBILE_TYPES[buff.type] then
				ImmobileDuration = duration
			elseif buff.type == 31 then
				KnockDuration = duration
			end
		end
	end
	local spell = unit.activeSpell
	if spell and spell.valid then
		if spell.isAutoAttack then
			AttackCastTime = spell.castEndTime
		elseif spell.windup > 0.1 then
			SpellCastTime = spell.castEndTime
		end
	end
	return ImmobileDuration, SpellCastTime, AttackCastTime, KnockDuration
end
Math = {}

function Math:Get2D(p)
	p = p.pos == nil and p or p.pos
	return { x = p.x, z = p.z == nil and p.y or p.z }
end

function Math:Get3D(p)
	local result = Vector(p.x, p.y, p.z)
	return result
end

function Math:GetDistance(p1, p2)
	local dx = p2.x - p1.x
	local dz = p2.z - p1.z
	return math_sqrt(dx * dx + dz * dz)
end

function Math:IsInRange(p1, p2, range)
	local dx = p1.x - p2.x
	local dz = p1.z - p2.z
	if dx * dx + dz * dz <= range * range then
		return true
	end
	return false
end

function Math:VectorsEqual(p1, p2, num)
	num = num or 5
	if self:GetDistance(p1, p2) < num then
		return true
	end
	return false
end

function Math:Normalized(p1, p2)
	local dx = p1.x - p2.x
	local dz = p1.z - p2.z
	local length = math_sqrt(dx * dx + dz * dz)
	local sol = nil
	if length > 0 then
		local inv = 1.0 / length
		sol = { x = (dx * inv), z = (dz * inv) }
	end
	return sol
end

function Math:Extended(vec, dir, range)
	if dir == nil then
		return vec
	end
	return { x = vec.x + dir.x * range, z = vec.z + dir.z * range }
end

function Math:Perpendicular(dir)
	if dir == nil then
		return nil
	end
	return { x = -dir.z, z = dir.x }
end

function Math:Intersection(s1, e1, s2, e2)
	local IntersectionResult = { Intersects = false, Point = { x = 0, z = 0 } }
	local deltaACz = s1.z - s2.z
	local deltaDCx = e2.x - s2.x
	local deltaACx = s1.x - s2.x
	local deltaDCz = e2.z - s2.z
	local deltaBAx = e1.x - s1.x
	local deltaBAz = e1.z - s1.z
	local denominator = deltaBAx * deltaDCz - deltaBAz * deltaDCx
	local numerator = deltaACz * deltaDCx - deltaACx * deltaDCz
	if denominator == 0 then
		if numerator == 0 then
			if s1.x >= s2.x and s1.x <= e2.x then
				return { Intersects = true, Point = s1 }
			end
			if s2.x >= s1.x and s2.x <= e1.x then
				return { Intersects = true, Point = s2 }
			end
			return IntersectionResult
		end
		return IntersectionResult
	end
	local r = numerator / denominator
	if r < 0 or r > 1 then
		return IntersectionResult
	end
	local s = (deltaACz * deltaBAx - deltaACx * deltaBAz) / denominator
	if s < 0 or s > 1 then
		return IntersectionResult
	end
	local point = { x = s1.x + r * deltaBAx, z = s1.z + r * deltaBAz }
	return { Intersects = true, Point = point }
end

function Math:ClosestPointOnLineSegment(p, p1, p2)
	local px = p.x
	local pz = p.z
	local ax = p1.x
	local az = p1.z
	local bx = p2.x
	local bz = p2.z
	local bxax = bx - ax
	local bzaz = bz - az
	local t = ((px - ax) * bxax + (pz - az) * bzaz) / (bxax * bxax + bzaz * bzaz)
	if t < 0 then
		return p1, false
	end
	if t > 1 then
		return p2, false
	end
	return { x = ax + t * bxax, z = az + t * bzaz }, true
end

function Math:Intercept(src, spos, epos, sspeed, tspeed)
	local dx = epos.x - spos.x
	local dz = epos.z - spos.z
	local magnitude = math_sqrt(dx * dx + dz * dz)
	local tx = spos.x - src.x
	local tz = spos.z - src.z
	local tvx = (dx / magnitude) * tspeed
	local tvz = (dz / magnitude) * tspeed
	local a = tvx * tvx + tvz * tvz - sspeed * sspeed
	local b = 2 * (tvx * tx + tvz * tz)
	local c = tx * tx + tz * tz
	local ts
	if math_abs(a) < 1e-6 then
		if math_abs(b) < 1e-6 then
			if math_abs(c) < 1e-6 then
				ts = { 0, 0 }
			end
		else
			ts = { -c / b, -c / b }
		end
	else
		local disc = b * b - 4 * a * c
		if disc >= 0 then
			disc = math_sqrt(disc)
			local a = 2 * a
			ts = { (-b - disc) / a, (-b + disc) / a }
		end
	end
	local sol
	if ts then
		local t0 = ts[1]
		local t1 = ts[2]
		local t = math_min(t0, t1)
		if t < 0 then
			t = math_max(t0, t1)
		end
		if t > 0 then
			sol = t
		end
	end
	return sol
end

function Math:Polar(p1)
	local x = p1.x
	local z = p1.z
	if x == 0 then
		if z > 0 then
			return 90
		end
		if z < 0 then
			return 270
		end
		return 0
	end
	local theta = math_atan(z / x) * (180.0 / math_pi) --RadianToDegree
	if x < 0 then
		theta = theta + 180
	end
	if theta < 0 then
		theta = theta + 360
	end
	return theta
end

function Math:AngleBetween(p1, p2)
	if p1 == nil or p2 == nil then
		return nil
	end
	local theta = self:Polar(p1) - self:Polar(p2)
	if theta < 0 then
		theta = theta + 360
	end
	if theta > 180 then
		theta = 360 - theta
	end
	return theta
end

function Math:FindAngle(p1, center, p2)
	local b = math_pow(center.x - p1.x, 2) + math_pow(center.z - p1.z, 2)
	local a = math_pow(center.x - p2.x, 2) + math_pow(center.z - p2.z, 2)
	local c = math_pow(p2.x - p1.x, 2) + math_pow(p2.z - p1.z, 2)
	local angle = math_acos((a + b - c) / math_sqrt(4 * a * b)) * (180 / math_pi)
	if angle > 90 then
		angle = 180 - angle
	end
	return angle
end

function Math:CircleCircleIntersection(center1, center2, radius1, radius2)
	local result = {}
	local D = self:GetDistance(center1, center2)
	if D > radius1 + radius2 or D <= math_abs(radius1 - radius2) then
		return result
	end
	local A = (radius1 * radius1 - radius2 * radius2 + D * D) / (2 * D)
	local H = math_sqrt(radius1 * radius1 - A * A)
	local Direction = self:Normalized(center2, center1)
	local PA = self:Extended(center1, Direction, A)
	local DirectionPerpendicular = self:Perpendicular(Direction)
	table_insert(result, self:Extended(PA, DirectionPerpendicular, H))
	table_insert(result, self:Extended(PA, DirectionPerpendicular, -H))
	return result
end
Path = {}

function Path:GetLenght(path)
	local result = 0
	for i = 1, #path - 1 do
		result = result + Math:GetDistance(path[i], path[i + 1])
	end
	return result
end

function Path:CutPath(path, distance)
	local result = {}
	if distance <= 0 then
		return path
	end
	for i = 1, #path - 1 do
		local a, b = path[i], path[i + 1]
		local dist = Math:GetDistance(a, b)
		if dist > distance then
			table_insert(result, Math:Extended(a, Math:Normalized(b, a), distance))
			for j = i + 1, #path do
				table_insert(result, path[j])
			end
			break
		end
		distance = distance - dist
	end
	return #result > 0 and result or { path[#path] }
end

function Path:ReversePath(path)
	local result = {}
	for i = #path, 1, -1 do
		table_insert(result, path[i])
	end
	return result
end

function Path:GetPath(unit)
	local result = { Math:Get2D(unit.pos) }
	local path = unit.pathing
	if path then
		if path.isDashing then
			local endPos = path.endPos
			if endPos and endPos.x then
				table_insert(result, Math:Get2D(endPos))
			else
				--print("GetPath -> endPos=" .. tostring(endPos))
			end
		else
			local istart = path.pathIndex
			local iend = path.pathCount
			if istart and iend and istart >= 0 and iend <= 20 then
				for i = istart, iend do
					local pos = unit:GetPath(i)
					if pos and pos.x then
						table_insert(result, Math:Get2D(pos))
					else
						--print("GetPath -> pos=" .. tostring(pos))
					end
				end
			else
				--print("GetPath -> istart=" .. tostring(istart) .. " iend=" .. tostring(iend))
			end
		end
	end
	return result
end

function Path:GetPredictedPath(source, speed, movespeed, path)
	local result = {}
	local tT = 0
	for i = 1, #path - 1 do
		local a = path[i]
		table_insert(result, a)
		local b = path[i + 1]
		local tB = Math:GetDistance(a, b) / movespeed
		local direction = Math:Normalized(b, a)
		a = Math:Extended(a, direction, -(movespeed * tT))
		local t = Math:Intercept(source, a, b, speed, movespeed)
		if t and t >= tT and t <= tT + tB then
			table_insert(result, Math:Extended(a, direction, t * movespeed))
			return result, t
		end
		tT = tT + tB
	end
	return nil, -1
end
UnitData = {
	Visible = {},
	Waypoints = {},
}

function UnitData:OnVisible(id, visible)
	if self.Visible[id] == nil then
		self.Visible[id] = { visible = visible, visibleTick = GetTickCount(), invisibleTick = GetTickCount() }
	end
	if visible then
		if not self.Visible[id].visible then
			self.Visible[id].visible = true
			self.Visible[id].visibleTick = GetTickCount()
		end
	else
		if self.Visible[id].visible then
			self.Visible[id].visible = false
			self.Visible[id].invisibleTick = GetTickCount()
		end
	end
end

function UnitData:OnWaypoint(id, path, hasMovePath, isDashing, endPos)
	local timer = GetTickCount()
	if self.Waypoints[id] == nil then
		self.Waypoints[id] = {
			moving = hasMovePath,
			dashing = isDashing,
			path = path,
			tick = timer,
			stoptick = timer,
			pos = endPos,
		}
	end
	if hasMovePath then
		if not Math:VectorsEqual(self.Waypoints[id].pos, endPos, 50) then
			self.Waypoints[id].tick = timer
		end
		self.Waypoints[id].pos = endPos
		self.Waypoints[id].dashing = isDashing
	elseif self.Waypoints[id].moving then
		self.Waypoints[id].stoptick = GetTickCount()
	end
	self.Waypoints[id].path = path
	self.Waypoints[id].moving = hasMovePath
end

function UnitData:OnTick()
	local id, visible, path, pathing, hasMovePath, isDashing, endPos
	for i, unit in ipairs(ObjectManager:GetHeroes()) do
		id = unit.networkID
		visible = unit.visible
		self:OnVisible(id, visible)
		if visible then
			pathing = unit.pathing
			if pathing then
				hasMovePath = pathing.hasMovePath
				isDashing = pathing.isDashing
				endPos = Math:Get2D(pathing.endPos)
				path = Path:GetPath(unit)
				self:OnWaypoint(id, path, hasMovePath, isDashing, endPos)
			end
		end
	end
end

function UnitData:OnPrediction(unit)
	local id = unit.networkID
	local visible = unit.visible
	self:OnVisible(id, visible)
	if visible then
		local hasMovePath = unit.pathing.hasMovePath
		local isDashing = unit.pathing.isDashing
		local endPos = Math:Get2D(unit.pathing.endPos)
		self:OnWaypoint(id, Path:GetPath(unit), hasMovePath, isDashing, endPos)
	end
end

Callback.Add("Load", function()
	Callback.Add("Draw", function()
		UnitData:OnTick()
	end)
end)
ObjectManager = {}

function ObjectManager:IsValid(unit)
	if unit and unit.valid and unit.visible and not unit.dead and unit.isTargetable then
		return true
	end
	return false
end

function ObjectManager:GetHeroes()
	local _Heroes = {}
	local hero, count
	count = Game.HeroCount()
	for i = 1, count do
		hero = Game.Hero(i)
		if hero and hero.valid and not hero.dead then
			table_insert(_Heroes, hero)
		end
	end
	return _Heroes
end

function ObjectManager:GetEnemyHeroes()
	local _EnemyHeroes = {}
	local count = Game.HeroCount()
	for i = 1, count do
		local hero = Game.Hero(i)
		if self:IsValid(hero) and hero.isEnemy then
			table_insert(_EnemyHeroes, hero)
		end
	end
	return _EnemyHeroes
end

function ObjectManager:GetAllyHeroes()
	local _AllyHeroes = {}
	local count = Game.HeroCount()
	for i = 1, count do
		local hero = Game.Hero(i)
		if self:IsValid(hero) and hero.isAlly then
			table_insert(_AllyHeroes, hero)
		end
	end
	return _AllyHeroes
end
Collision = {}

 function Collision:GetCollision(source, castPos, speed, delay, radius, collisionTypes, skipID)
	source = Math:Extended(source, Math:Normalized(source, castPos), 75)
	castPos = Math:Extended(castPos, Math:Normalized(castPos, source), 75)
	local isWall, collisionObjects, collisionCount = false, {}, 0
	local objects = {}
	for i, colType in pairs(collisionTypes) do
		if colType == COLLISION_MINION then
			for k = 1, Game.MinionCount() do
				local unit = Game.Minion(k)
				if
					unit.networkID ~= skipID
					and ObjectManager:IsValid(unit)
					and unit.isEnemy
					and Math:GetDistance(source, Math:Get2D(unit.pos)) < 2000
				then
					table_insert(objects, unit)
				end
			end
		elseif colType == COLLISION_ALLYHERO then
			for k, unit in pairs(ObjectManager:GetAllyHeroes()) do
				if unit.networkID ~= skipID and Math:GetDistance(source, Math:Get2D(unit.pos)) < 2000 then
					table_insert(objects, unit)
				end
			end
		elseif colType == COLLISION_ENEMYHERO then
			for k, unit in pairs(ObjectManager:GetEnemyHeroes()) do
				if unit.networkID ~= skipID and Math:GetDistance(source, Math:Get2D(unit.pos)) < 2000 then
					table_insert(objects, unit)
				end
			end
		end
	end
	for i, object in pairs(objects) do
		local isCol = false
		local objectPos = Math:Get2D(object.pos)
		local pointLine, isOnSegment = Math:ClosestPointOnLineSegment(objectPos, source, castPos)
		if isOnSegment and Math:IsInRange(objectPos, pointLine, radius + 15 + object.boundingRadius) then
			isCol = true
		elseif object.pathing.hasMovePath then
			objectPos = Math:Get2D(object:GetPrediction(speed, delay))
			pointLine, isOnSegment = Math:ClosestPointOnLineSegment(objectPos, source, castPos)
			if isOnSegment and Math:IsInRange(objectPos, pointLine, radius + 15 + object.boundingRadius) then
				isCol = true
			end
		end
		if isCol then
			table_insert(collisionObjects, object)
			collisionCount = collisionCount + 1
		end
	end
	return isWall, collisionObjects, collisionCount
end 
function Collision:GetCollision2(source, castPos, speed, delay, radius, collisionTypes, skipID)
	source = Math:Extended(source, Math:Normalized(source, castPos), myHero.boundingRadius)
	castPos = Math:Extended(castPos, Math:Normalized(castPos, source), 75)
	local isWall, collisionObjects, collisionCount = false, {}, 0
	local objects = {}
	local objects2 = {}
	for i, colType in pairs(collisionTypes) do
		if colType == COLLISION_MINION then
			for k = 1, Game.MinionCount() do
				local unit = Game.Minion(k)
				if
					unit.networkID ~= skipID
					and ObjectManager:IsValid(unit)
					and unit.isEnemy
					and Math:GetDistance(source, Math:Get2D(unit.pos)) < 2000
				then
					table_insert(objects, unit)
				end
			end
		elseif colType == COLLISION_ALLYHERO then
			for k, unit in pairs(ObjectManager:GetAllyHeroes()) do
				if unit.networkID ~= skipID and Math:GetDistance(source, Math:Get2D(unit.pos)) < 2000 then
					table_insert(objects, unit)
				end
			end
		elseif colType == COLLISION_ENEMYHERO then
			for k, unit in pairs(ObjectManager:GetEnemyHeroes()) do
				if unit.networkID ~= skipID and Math:GetDistance(source, Math:Get2D(unit.pos)) < 2000 then
					table_insert(objects2, unit)
				end
			end
		end
	end
	for i, object in pairs(objects) do
		local isCol = false
		local objectPos = Math:Get2D(object.pos)
		local pointLine, isOnSegment = Math:ClosestPointOnLineSegment(objectPos, source, castPos)
		if isOnSegment and Math:IsInRange(objectPos, pointLine, radius+ object.boundingRadius) then
			isCol = true
		elseif object.pathing.hasMovePath then
			objectPos = Math:Get2D(object:GetPrediction(speed, delay))
			pointLine, isOnSegment = Math:ClosestPointOnLineSegment(objectPos, source, castPos)
			if isOnSegment and Math:IsInRange(objectPos, pointLine, radius + object.boundingRadius) then
				isCol = true
			end
		end
		if isCol then
			table_insert(collisionObjects, object)
			collisionCount = collisionCount + 1
		end
	end
	for i, object in pairs(objects2) do
		local isCol = false
		local prjctdpos, uselesscastpos, prjectdtimetohit = Prediction:GetPrediction(
			object,
			source,
			speed,
			delay,
			1,
			true
		)
		local objectPos = Math:Get2D(object:GetPrediction(math.huge, prjectdtimetohit)) 
		local pointLine, isOnSegment = Math:ClosestPointOnLineSegment(objectPos, source, castPos)
		if isOnSegment and prjctdpos and Math:IsInRange(prjctdpos, pointLine, radius+ object.boundingRadius) then
			isCol = true			
		end
		if isCol then
			table_insert(collisionObjects, object)
			collisionCount = collisionCount + 1
		end
	end
	return isWall, collisionObjects, collisionCount
end
Prediction = {}

function Prediction:GetPrediction(target, source, speed, delay, radius, isHero)
	local id, ms = target.networkID, target.ms
	if not isHero then
		local hasMovePath = target.pathing.hasMovePath
		if not hasMovePath then
			return Math:Get2D(target.pos)
		end
		local path = Path:GetPath(target)
		if #path <= 1 then
			return Math:Get2D(target.pos)
		end
		local delay2 = delay + Menu:GetLatency() + Menu:GetExtraDelay()
		local path2 = Path:CutPath(path, ms * delay2)
		if speed == math_huge then
			return path2[1]
		end
		local path3, time = Path:GetPredictedPath(source, speed, ms, path)
		if path3 then
			return path3[#path3]
		end
		return path[#path]
	end
	UnitData:OnPrediction(target)
	local vis = UnitData.Visible[id]
	if vis.visible then
		if GetTickCount() < vis.visibleTick + 0.5 then
			return nil, nil, -1
		end
	elseif GetTickCount() > vis.invisibleTick + 1 then
		return nil, nil, -1
	end
	local wp = UnitData.Waypoints[id]
	if wp.moving and #wp.path <= 1 then
		return nil, nil, -1
	end
	if not wp.moving then
		local pos = Math:Get2D(target.pos)
		return pos, pos, delay + Math:GetDistance(pos, source) / speed
	end
	if wp.dashing then
		local pos = wp.pos
		return pos, pos, delay + Math:GetDistance(pos, source) / speed
	end
	local delay2 = delay + Menu:GetLatency() + Menu:GetExtraDelay()
	if speed == math_huge then
		local path = Path:CutPath(wp.path, ms * delay2)
		local path2 = Path:CutPath(wp.path, (ms * delay2) - radius)
		return path[1], path2[1], delay
	end
	local path, time = Path:GetPredictedPath(source, speed, ms, Path:CutPath(wp.path, ms * delay2))
	if path then
		local path2 = Path:CutPath(Path:ReversePath(path), radius)
		return path[#path], path2[1], delay + Math:GetDistance(path[#path], source) / speed
	end
	local p = wp.path[#wp.path]
	return p, p, delay + Math:GetDistance(p, source) / speed
end
function Prediction:GetPrediction2(target, source, speed, delay, radius, isHero)
	local id, ms = target.networkID, target.ms
	if not isHero then
	
		local hasMovePath = target.pathing.hasMovePath
		if not hasMovePath then
			return Math:Get2D(target.pos), Math:Get2D(target.pos), Math:GetDistance(target.pos, source) / speed
			
		end
		local path = Path:GetPath(target)
		if #path <= 1 then
			return Math:Get2D(target.pos), Math:Get2D(target.pos), Math:GetDistance(target.pos, source) / speed
		end
		local delay2 = delay + Menu:GetLatency() + Menu:GetExtraDelay()
		local path2 = Path:CutPath(path, ms * delay2)
		if speed == math_huge then
			return path2[1], path2[1], Math:GetDistance(target.pos, source) / speed
		end
		local path3, time = Path:GetPredictedPath(source, speed, ms, path)
		if path3 then
			return path3[#path3],path3[#path3], Math:GetDistance(target.pos, source) / speed
		end
		return path[#path],	path[#path], Math:GetDistance(target.pos, source) / speed
	end
	UnitData:OnPrediction(target)
	local vis = UnitData.Visible[id]
	if vis.visible then
		if GetTickCount() < vis.visibleTick + 0.5 then
			return nil, nil, -1
		end
	elseif GetTickCount() > vis.invisibleTick + 1 then
		return nil, nil, -1
	end
	local wp = UnitData.Waypoints[id]
	if wp.moving and #wp.path <= 1 then
		return nil, nil, -1
	end
	if not wp.moving then
		local pos = Math:Get2D(target.pos)
		return pos, pos, delay + Math:GetDistance(pos, source) / speed
	end
	if wp.dashing then
		local pos = wp.pos
		return pos, pos, delay + Math:GetDistance(pos, source) / speed
	end
	local delay2 = delay + Menu:GetLatency() + Menu:GetExtraDelay()
	if speed == math_huge then
		local path = Path:CutPath(wp.path, ms * delay2)
		local path2 = Path:CutPath(wp.path, (ms * delay2) - radius)
		return path[1], path2[1], delay
	end
	local path, time = Path:GetPredictedPath(source, speed, ms, Path:CutPath(wp.path, ms * delay2))
	if path then
		local path2 = Path:CutPath(Path:ReversePath(path), radius)
		return path[#path], path2[1], delay + Math:GetDistance(path[#path], source) / speed
	end
	local p = wp.path[#wp.path]
	return p, p, delay + Math:GetDistance(p, source) / speed
end

function Prediction:SpellPrediction(args)
	local c = {}
	do -- __init()
		c.Collision, c.MaxCollision, c.CollisionTypes = false, 0, { 0, 3 }
		if args.Collision ~= nil then
			c.Collision = args.Collision
		end
		if args.MaxCollision ~= nil then
			c.MaxCollision = args.MaxCollision
		end
		if args.CollisionTypes ~= nil then
			c.CollisionTypes = args.CollisionTypes
		end
		c.Type, c.Speed, c.Range, c.Delay, c.Radius, c.UseBoundingRadius =
			SPELLTYPE_LINE, math_huge, math_huge, 0, 1, false
		if args.Type ~= nil then
			c.Type = args.Type
		end
		if args.Speed ~= nil then
			c.Speed = args.Speed
		end
		if args.Range ~= nil then
			c.Range = args.Range
		end
		if args.Delay ~= nil then
			c.Delay = args.Delay
		end
		if args.Radius ~= nil then
			c.Radius = args.Radius
		end
		if args.UseBoundingRadius or (args.UseBoundingRadius == nil and c.Type == SPELLTYPE_LINE) then
			c.UseBoundingRadius = true
		end
	end
	function c:ResetOutput()
		self.HitChance = 0
		self.CastPosition = nil
		self.UnitPosition = nil
		self.TimeToHit = 0
		self.CollionableObjects = {}
	end
	function c:GetOutput()
		self.TargetIsHero = self.Target.type == Obj_AI_Hero
		self.RealRadius = self.UseBoundingRadius and self.Radius + self.Target.boundingRadius or self.Radius
		if self.TargetIsHero then
			self.UnitPosition, self.CastPosition, self.TimeToHit = Prediction:GetPrediction(
				self.Target,
				self.Source,
				self.Speed,
				self.Delay,
				self.RealRadius,
				self.TargetIsHero
			)
		else
			self.UnitPosition, self.CastPosition, self.TimeToHit = Prediction:GetPrediction2(
				self.Target,
				self.Source,
				self.Speed,
				self.Delay,
				self.RealRadius,
				self.TargetIsHero
			)
		end
	end
	function c:HighHitChance(spelltime, attacktime)
		local wp, path, tick, timer =
			UnitData.Waypoints[self.Target.networkID], self.Target.pathing, GetTickCount(), Game.Timer()
		if not self.Target.visible then
			return false
		end
		if wp.moving then
			if tick < wp.tick + 150 then
				return true
			end
			if tick > wp.tick + 1000 and Path:GetLenght(wp.path) > 1000 then
				return true
			end
			return false
		end
		if tick - wp.stoptick < 50 then
			return true
		end
		if tick - wp.stoptick > 1000 then
			return true
		end
		if attacktime - 0.05 > timer then
			return true
		end
		if spelltime - 0.05 > timer then
			return true
		end
		return false
	end
	function c:IsCollision()
		local isWall, collisionObjects, collisionCount = Collision:GetCollision(
			self.Source,
			self.CastPosition,
			self.Speed,
			self.Delay,
			self.Radius,
			self.CollisionTypes,
			self.Target.networkID
		)

		if isWall or collisionCount > self.MaxCollision then
			self.CollionableObjects = collisionObjects
			return true
		end
		return false	
	end
	function c:IsInRange()
		self.MyHeroPos = Math:Get2D(myHero.pos)
		if
			Math:IsInRange(
				self.Type == SPELLTYPE_CIRCLE and self.CastPosition or self.UnitPosition,
				self.MyHeroPos,
				self.Range
			)
		then
			local y = self.Target.pos.y
			y = y > 100 and 100 or y
			self.CastPosition.y = y
			self.UnitPosition.y = y
			local castPos3D = Math:Get3D(self.CastPosition)
			self.IsOnScreen = castPos3D:To2D().onScreen
			if not self.IsOnScreen then
				if self.Type == SPELLTYPE_CIRCLE then
					return false
				end
				self.CastPosition = myHero.pos:Extended(castPos3D, 800)
			end
			return true
		end
		return false
	end
	function c:CanHit(hitChance)
		hitChance = hitChance or HITCHANCE_NORMAL
		if self.UnitPosition == nil or self.CastPosition == nil then
			self.HitChance = 0
			return false
		end
		--[[if self.Type ~= SPELLTYPE_CIRCLE and self.TimeToHit > 0.7 and Math:FindAngle(self.CastPosition, self.Target.pos, myHero.pos) > 90 - self.TimeToHit * 30 then
			return false
		end]]
		self.HitChance = HITCHANCE_NORMAL
		if self.TargetIsHero then
			local duration, spelltime, attacktime, knockduration = Immobile:GetDuration(self.Target)
			if knockduration ~= 0 then
				self.HitChance = 0
				return false
			end
			if duration > 0 then
				if self.TimeToHit + 0.02 < duration + self.RealRadius / self.Target.ms then
					self.HitChance = HITCHANCE_IMMOBILE
				end
			end
			if self.HitChance == HITCHANCE_NORMAL and self:HighHitChance(spelltime, attacktime) then
				self.HitChance = HITCHANCE_HIGH
			end			
		end
		if self.HitChance < hitChance then
			return false
		end
		if self.Range ~= math_huge and not self:IsInRange() then
			return false
		end

		if self.Collision and self:IsCollision() then
			return false
		end
		if not Math:VectorsEqual(self.PosTo, Math:Get2D(self.Target.posTo), 50) then
			return false
		end

		if os.clock() - self.StartTime > 0.03 then
			return false
		end
		return true
	end
	function c:GetPrediction(target, source)
		self.Target = target
		self.Source = Math:Get2D(source)
		self.PosTo = Math:Get2D(target.posTo)
		self.StartTime = os.clock()
		self:ResetOutput()
		self:GetOutput()
	end
	function c:GetAOEPrediction(source)
		local aoetargets = {}
		local enemies = ObjectManager:GetEnemyHeroes()
		for i = 1, #enemies do
			local enemy = enemies[i]
			if not SDK.ObjectManager:IsHeroImmortal(enemy) then
				self:GetPrediction(enemy, source)
				if self:CanHit(HITCHANCE_NORMAL) then
					table_insert(
						aoetargets,
						{ enemy, self.HitChance, self.TimeToHit, self.CastPosition, self.UnitPosition }
					)
				end
			end
		end
		local result = {}
		local isCircle = self.Type == SPELLTYPE_CIRCLE
		for i = 1, #aoetargets do
			local aoetarget = aoetargets[i]
			local count = 1
			local distance = 0
			local castpos = aoetarget[4]
			for j = 1, #aoetargets do
				if i ~= j then
					local d
					local unitpos = aoetargets[j][5]
					if isCircle then
						d = Math:GetDistance(castpos, unitpos)
					else
						local pointLine, isOnSegment = Math:ClosestPointOnLineSegment(unitpos, self.Source, castpos)
						d = Math:GetDistance(pointLine, unitpos)
					end
					if d < self.RealRadius then
						count = count + 1
						distance = distance + d
					end
				end
			end
			table_insert(result, {
				Count = count,
				Distance = distance,
				Unit = aoetarget[1],
				HitChance = aoetarget[2],
				TimeToHit = aoetarget[3],
				CastPosition = castpos,
			})
		end
		return result
	end
	return c
end
--[[
	GGPrediction - Global Class, API
]]
_G.GGPrediction = {
	COLLISION_MINION = COLLISION_MINION,
	COLLISION_ALLYHERO = COLLISION_ALLYHERO,
	COLLISION_ENEMYHERO = COLLISION_ENEMYHERO,
	COLLISION_YASUOWALL = COLLISION_YASUOWALL,
	HITCHANCE_IMPOSSIBLE = HITCHANCE_IMPOSSIBLE,
	HITCHANCE_COLLISION = HITCHANCE_COLLISION,
	HITCHANCE_NORMAL = HITCHANCE_NORMAL,
	HITCHANCE_HIGH = HITCHANCE_HIGH,
	HITCHANCE_IMMOBILE = HITCHANCE_IMMOBILE,
	SPELLTYPE_LINE = SPELLTYPE_LINE,
	SPELLTYPE_CIRCLE = SPELLTYPE_CIRCLE,
	SPELLTYPE_CONE = SPELLTYPE_CONE,
}
function GGPrediction:GetPrediction(target, source, speed, delay, radius)
	return Prediction:GetPrediction(target, Math:Get2D(source), speed, delay, radius, target.type == Obj_AI_Hero)
end
function GGPrediction:GetCollision(source, castPos, speed, delay, radius, collisionTypes, skipID)
	return Collision:GetCollision(source, castPos, speed, delay, radius, collisionTypes, skipID)
end
function GGPrediction:GetCollision2(source, castPos, speed, delay, radius, collisionTypes, skipID)
	return Collision:GetCollision2(source, castPos, speed, delay, radius, collisionTypes, skipID)
end
function GGPrediction:SpellPrediction(args)
	return Prediction:SpellPrediction(args)
end
function GGPrediction:ClosestPointOnLineSegment(p, p1, p2)
	return Math:ClosestPointOnLineSegment(p, p1, p2)
end
function GGPrediction:IsInRange(p1, p2, range)
	return Math:IsInRange(p1, p2, range)
end
function GGPrediction:GetImmobileDuration(unit)
	return Immobile:GetDuration(unit)
end
function GGPrediction:FindAngle(p1, center, p2)
	return Math:FindAngle(p1, center, p2)
end
function GGPrediction:GetDistance(p1, p2)
	return Math:GetDistance(p1, p2)
end
function GGPrediction:IsInRange(p1, p2, range)
	return Math:IsInRange(p1, p2, range)
end
function GGPrediction:CircleCircleIntersection(center1, center2, radius1, radius2)
	return Math:CircleCircleIntersection(center1, center2, radius1, radius2)
end
