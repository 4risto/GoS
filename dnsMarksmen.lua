require "DamageLib"
require "2DGeometry"
require "MapPositionGOS"
require "PremiumPrediction"
require "GGPrediction"


local EnemyHeroes = {}
local AllyHeroes = {}
local EnemySpawnPos = nil
local AllySpawnPos = nil

--[[ AutoUpdate deactivated until proper rank.
do
    
    local Version = 1.0
    
    local Files = {
        Lua = {
            Path = SCRIPT_PATH,
            Name = "dnsMages.lua",
            Url = "https://raw.githubusercontent.com/fkndns/dnsMages/main/dnsMages.lua"
       },
        Version = {
            Path = SCRIPT_PATH,
            Name = "dnsActivator.version",
            Url = "https://raw.githubusercontent.com/fkndns/dnsMages/main/dnsMages.version"    -- check if Raw Adress correct pls.. after you have create the version file on Github
        }
    }
    
    local function AutoUpdate()
        
        local function DownloadFile(url, path, fileName)
            DownloadFileAsync(url, path .. fileName, function() end)
            while not FileExist(path .. fileName) do end
        end
        
        local function ReadFile(path, fileName)
            local file = io.open(path .. fileName, "r")
            local result = file:read()
            file:close()
            return result
        end
        
        DownloadFile(Files.Version.Url, Files.Version.Path, Files.Version.Name)
        local textPos = myHero.pos:To2D()
        local NewVersion = tonumber(ReadFile(Files.Version.Path, Files.Version.Name))
        if NewVersion > Version then
            DownloadFile(Files.Lua.Url, Files.Lua.Path, Files.Lua.Name)
            print("New dnsMarksmen Version. Press 2x F6")     -- <-- you can change the massage for users here !!!!
        else
            print(Files.Version.Name .. ": No Updates Found")   --  <-- here too
        end
    
    end
    
    AutoUpdate()

end 
--]]

local ItemHotKey = {[ITEM_1] = HK_ITEM_1, [ITEM_2] = HK_ITEM_2, [ITEM_3] = HK_ITEM_3, [ITEM_4] = HK_ITEM_5, [ITEM_5] = HK_ITEM_6, [ITEM_6] = HK_ITEM_7, [ITEM_7] = HK_ITEM_7,}

local function GetInventorySlotItem(itemID)
    assert(type(itemID) == "number", "GetInventorySlotItem: wrong argument types (<number> expected)")
    for _, j in pairs({ITEM_1, ITEM_2, ITEM_3, ITEM_4, ITEM_5, ITEM_6}) do
        if myHero:GetItemData(j).itemID == itemID and myHero:GetSpellData(j).currentCd == 0 then return j end
    end
    return nil
end

local function IsNearEnemyTurret(pos, distance)
    --PrintChat("Checking Turrets")
    local turrets = _G.SDK.ObjectManager:GetTurrets(GetDistance(pos) + 1000)
    for i = 1, #turrets do
        local turret = turrets[i]
        if turret and GetDistance(turret.pos, pos) <= distance+915 and turret.team == 300-myHero.team then
            --PrintChat("turret")
            return turret
        end
    end
end

local function IsUnderEnemyTurret(pos)
    --PrintChat("Checking Turrets")
    local turrets = _G.SDK.ObjectManager:GetTurrets(GetDistance(pos) + 1000)
    for i = 1, #turrets do
        local turret = turrets[i]
        if turret and GetDistance(turret.pos, pos) <= 915 and turret.team == 300-myHero.team then
            --PrintChat("turret")
            return turret
        end
    end
end

function GetDifference(a,b)
    local Sa = a^2
    local Sb = b^2
    local Sdif = (a-b)^2
    return math.sqrt(Sdif)
end

function GetDistanceSqr(Pos1, Pos2)
    local Pos2 = Pos2 or myHero.pos
    local dx = Pos1.x - Pos2.x
    local dz = (Pos1.z or Pos1.y) - (Pos2.z or Pos2.y)
    return dx^2 + dz^2
end

function DrawTextOnHero(hero, text, color)
    local pos2D = hero.pos:To2D()
    local posX = pos2D.x - 50
    local posY = pos2D.y
    Draw.Text(text, 28, posX + 50, posY - 15, color)
end

function GetDistance(Pos1, Pos2)
    return math.sqrt(GetDistanceSqr(Pos1, Pos2))
end

function IsImmobile(unit)
    local MaxDuration = 0
    for i = 0, unit.buffCount do
        local buff = unit:GetBuff(i)
        if buff and buff.count > 0 then
            local BuffType = buff.type
            if BuffType == 5 or BuffType == 12 or BuffType == 22 or BuffType == 23 or BuffType == 25 or BuffType == 30 or BuffType == 35 or buff.name == "recall" then
                local BuffDuration = buff.duration
                if BuffDuration > MaxDuration then
                    MaxDuration = BuffDuration
                end
            end
        end
    end
    return MaxDuration
end

function IsCleanse(unit)
    local MaxDuration = 0
    for i = 0, unit.buffCount do
        local buff = unit:GetBuff(i)
        if buff and buff.count > 0 then
            local BuffType = buff.type
            if BuffType == 5 or BuffType == 8 or BuffType == 10 or BuffType == 12 or BuffType == 22 or BuffType == 23 or BuffType == 25 or BuffType == 32 then
                local BuffDuration = buff.duration
                if BuffDuration > MaxDuration then
                    MaxDuration = BuffDuration
                end
            end
        end
    end
    return MaxDuration
end

function IsChainable(unit)
    local MaxDuration = 0
    for i = 0, unit.buffCount do
        local buff = unit:GetBuff(i)
        if buff and buff.count > 0 then
            local BuffType = buff.type
            if BuffType == 5 or BuffType == 8 or BuffType == 10 or BuffType == 12 or BuffType == 22 or BuffType == 23 or BuffType == 25 or BuffType == 32 or BuffType == 11 then
                local BuffDuration = buff.duration
                if BuffDuration > MaxDuration then
                    MaxDuration = BuffDuration
                end
            end
        end
    end
    return MaxDuration
end

function GetEnemyHeroes()
    for i = 1, Game.HeroCount() do
        local Hero = Game.Hero(i)
        if Hero.isEnemy then
            table.insert(EnemyHeroes, Hero)
            PrintChat(Hero.name)
        end
    end
    --PrintChat("Got Enemy Heroes")
end

function GetEnemyBase()
    for i = 1, Game.ObjectCount() do
        local object = Game.Object(i)
        
        if not object.isAlly and object.type == Obj_AI_SpawnPoint then 
            EnemySpawnPos = object
            break
        end
    end
end

function GetAllyBase()
    for i = 1, Game.ObjectCount() do
        local object = Game.Object(i)
        
        if object.isAlly and object.type == Obj_AI_SpawnPoint then 
            AllySpawnPos = object
            break
        end
    end
end

function GetAllyHeroes()
    for i = 1, Game.HeroCount() do
        local Hero = Game.Hero(i)
        if Hero.isAlly and Hero.charName ~= myHero.charName then
            table.insert(AllyHeroes, Hero)
            PrintChat(Hero.name)
        end
    end
    --PrintChat("Got Enemy Heroes")
end

function GetBuffStart(unit, buffname)
    for i = 0, unit.buffCount do
        local buff = unit:GetBuff(i)
        if buff.name == buffname and buff.count > 0 then 
            return buff.startTime
        end
    end
    return nil
end

function GetBuffExpire(unit, buffname)
    for i = 0, unit.buffCount do
        local buff = unit:GetBuff(i)
        if buff.name == buffname and buff.count > 0 then 
            return buff.expireTime
        end
    end
    return nil
end

function GetBuffDuration(unit, buffname)
    for i = 0, unit.buffCount do
        local buff = unit:GetBuff(i)
        if buff.name == buffname and buff.count > 0 then 
            return buff.duration
        end
    end
    return 0
end

function GetBuffStacks(unit, buffname)
    for i = 0, unit.buffCount do
        local buff = unit:GetBuff(i)
        if buff.name == buffname and buff.count > 0 then 
            return buff.count
        end
    end
    return 0
end

local function GetWaypoints(unit) -- get unit's waypoints
    local waypoints = {}
    local pathData = unit.pathing
    table.insert(waypoints, unit.pos)
    local PathStart = pathData.pathIndex
    local PathEnd = pathData.pathCount
    if PathStart and PathEnd and PathStart >= 0 and PathEnd <= 20 and pathData.hasMovePath then
        for i = pathData.pathIndex, pathData.pathCount do
            table.insert(waypoints, unit:GetPath(i))
        end
    end
    return waypoints
end

local function GetUnitPositionNext(unit)
    local waypoints = GetWaypoints(unit)
    if #waypoints == 1 then
        return nil -- we have only 1 waypoint which means that unit is not moving, return his position
    end
    return waypoints[2] -- all segments have been checked, so the final result is the last waypoint
end

local function GetUnitPositionAfterTime(unit, time)
    local waypoints = GetWaypoints(unit)
    if #waypoints == 1 then
        return unit.pos -- we have only 1 waypoint which means that unit is not moving, return his position
    end
    local max = unit.ms * time -- calculate arrival distance
    for i = 1, #waypoints - 1 do
        local a, b = waypoints[i], waypoints[i + 1]
        local dist = GetDistance(a, b)
        if dist >= max then
            return Vector(a):Extended(b, dist) -- distance of segment is bigger or equal to maximum distance, so the result is point A extended by point B over calculated distance
        end
        max = max - dist -- reduce maximum distance and check next segments
    end
    return waypoints[#waypoints] -- all segments have been checked, so the final result is the last waypoint
end

function GetTarget(range)
    if _G.SDK then
        return _G.SDK.TargetSelector:GetTarget(range, _G.SDK.DAMAGE_TYPE_MAGICAL);
    else
        return _G.GOS:GetTarget(range,"AD")
    end
end

function CalcRDmg(unit)
    local Damage = 0
    local Distance = GetDistance(myHero.pos, unit.pos)
    local MathDist = math.floor(math.floor(Distance)/100)   
    local level = myHero:GetSpellData(_R).level
    local BaseQ = ({25, 35, 45})[level] + 0.15 * myHero.bonusDamage
    local QMissHeal = ({25, 30, 35})[level] / 100 * (unit.maxHealth - unit.health)
    local dist = myHero.pos:DistanceTo(unit.pos)
    if Distance < 100 then
        Damage = BaseQ + QMissHeal
    elseif Distance >= 1500 then
        Damage = BaseQ * 10 + QMissHeal     
    else
        Damage = ((((MathDist * 6) + 10) / 100) * BaseQ) + BaseQ + QMissHeal
    end
    return CalcPhysicalDamage(myHero, unit, Damage)
end

function GotBuff(unit, buffname)
    for i = 0, unit.buffCount do
        local buff = unit:GetBuff(i)
        --PrintChat(buff.name)
        if buff.name == buffname and buff.count > 0 then 
            return buff.count
        end
    end
    return 0
end

function BuffActive(unit, buffname)
    for i = 0, unit.buffCount do
        local buff = unit:GetBuff(i)
        if buff.name == buffname and buff.count > 0 then 
            return true
        end
    end
    return false
end

function IsReady(spell)
    return myHero:GetSpellData(spell).currentCd == 0 and myHero:GetSpellData(spell).level > 0 and myHero:GetSpellData(spell).mana <= myHero.mana and Game.CanUseSpell(spell) == 0
end

function Mode()
    if _G.SDK then
        if _G.SDK.Orbwalker.Modes[_G.SDK.ORBWALKER_MODE_COMBO] then
            return "Combo"
        elseif _G.SDK.Orbwalker.Modes[_G.SDK.ORBWALKER_MODE_HARASS] or Orbwalker.Key.Harass:Value() then
            return "Harass"
        elseif _G.SDK.Orbwalker.Modes[_G.SDK.ORBWALKER_MODE_LANECLEAR] or Orbwalker.Key.Clear:Value() then
            return "LaneClear"
        elseif _G.SDK.Orbwalker.Modes[_G.SDK.ORBWALKER_MODE_LASTHIT] or Orbwalker.Key.LastHit:Value() then
            return "LastHit"
        elseif _G.SDK.Orbwalker.Modes[_G.SDK.ORBWALKER_MODE_FLEE] then
            return "Flee"
        end
    else
        return GOS.GetMode()
    end
end

function GetItemSlot(unit, id)
    for i = ITEM_1, ITEM_7 do
        if unit:GetItemData(i).itemID == id then
            return i
        end
    end
    return 0
end

function IsFacing(unit)
    local V = Vector((unit.pos - myHero.pos))
    local D = Vector(unit.dir)
    local Angle = 180 - math.deg(math.acos(V*D/(V:Len()*D:Len())))
    if math.abs(Angle) < 80 then 
        return true  
    end
    return false
end

function IsMyHeroFacing(unit)
    local V = Vector((myHero.pos - unit.pos))
    local D = Vector(myHero.dir)
    local Angle = 180 - math.deg(math.acos(V*D/(V:Len()*D:Len())))
    if math.abs(Angle) < 80 then 
        return true  
    end
    return false
end

function SetMovement(bool)
    if _G.PremiumOrbwalker then
        _G.PremiumOrbwalker:SetAttack(bool)
        _G.PremiumOrbwalker:SetMovement(bool)       
    elseif _G.SDK then
        _G.SDK.Orbwalker:SetMovement(bool)
        _G.SDK.Orbwalker:SetAttack(bool)
    end
end


local function CheckHPPred(unit, SpellSpeed)
     local speed = SpellSpeed
     local range = myHero.pos:DistanceTo(unit.pos)
     local time = range / speed
     if _G.SDK and _G.SDK.Orbwalker then
         return _G.SDK.HealthPrediction:GetPrediction(unit, time)
     elseif _G.PremiumOrbwalker then
         return _G.PremiumOrbwalker:GetHealthPrediction(unit, time)
    end
end

local function IsValid(unit)
    if (unit and unit.valid and unit.isTargetable and unit.alive and unit.visible and unit.networkID and unit.pathing and unit.health > 0) then
        return true;
    end
    return false;
end

local function ClosestPointOnLineSegment(p, p1, p2)
    local px = p.x
    local pz = p.z
    local ax = p1.x
    local az = p1.z
    local bx = p2.x
    local bz = p2.z
    local bxax = bx - ax
    local bzaz = bz - az
    local t = ((px - ax) * bxax + (pz - az) * bzaz) / (bxax * bxax + bzaz * bzaz)
    if (t < 0) then
        return p1, false
    end
    if (t > 1) then
        return p2, false
    end
    return {x = ax + t * bxax, z = az + t * bzaz}, true
end

local function ValidTarget(unit, range)
    if (unit and unit.valid and unit.isTargetable and unit.alive and unit.visible and unit.networkID and unit.pathing and unit.health > 0) then
        if range then
            if GetDistance(unit.pos) <= range then
                return true;
            end
        else
            return true
        end
    end
    return false;
end

local function GetEnemyCount(range, pos)
    local pos = pos.pos
    local count = 0
    for i, hero in pairs(EnemyHeroes) do
    local Range = range * range
        if GetDistanceSqr(pos, hero.pos) < Range and IsValid(hero) then
        count = count + 1
        end
    end
    return count
end

local function GetAllyCount(range, pos)
    local pos = pos.pos
    local count = 0
    for i, hero in pairs(AllyHeroes) do
    local Range = range * range
        if GetDistanceSqr(pos, hero.pos) < Range and IsValid(hero) then
        count = count + 1
        end
    end
    return count
end

local function GetMinionCount(checkrange, range, pos)
    local minions = _G.SDK.ObjectManager:GetEnemyMinions(checkrange)
    local pos = pos.pos
    local count = 0
    for i = 1, #minions do 
        local minion = minions[i]
        local Range = range * range
        if GetDistanceSqr(pos, minion.pos) < Range and IsValid(minion) then
            count = count + 1
        end
    end
    return count
end

local function GetMinionCountLinear(checkrange, range, pos)
    local minions = _G.SDK.ObjectManager:GetEnemyMinions(checkrange)
    local count = 0 
    for i = 1, #minions do
        local minion = minions[i]
        local spellLine = ClosestPointOnLineSegment(minion.pos, myHero.pos, pos)
        if GetDistance(minion.pos, spellLine) <= range and ValidTarget(minion) then
            count = count + 1
        end
    end
    return count
end


local function dnsTargetSelector(unit, range)
    local fullDamUnit = (unit.totalDamage + unit.ap * 0.7)
    local healthPercentUnit = (unit.health / unit.maxHealth)
    local unitStrength = fullDamUnit / healthPercentUnit
    local dtarget = nil
    if dtarget ~= nil then
        local fullDamdtarget = (dtarget.totalDamage + dtarget.ap * 0.7) 
        local healthPercentdtarget = (dtarget.health / dtarget.maxHealth) 
        local dtargetStrength = fullDamdtarget / healthPercentdtarget
    end
    if ValidTarget(unit, range) then
        --PrintChat("target")
        if dtarget == nil or unitStrength > dtargetStrength then
            dtarget = unit
            PrintChat(dtarget.charName)
        end
    end
    return dtarget
end

function GetTurretShot(unit)
    local turrets = _G.SDK.ObjectManager:GetTurrets(GetDistance(unit.pos) + 1000)
    for i = 1, #turrets do
        local turret = turrets[i]
        if turret and turret.activeSpell.valid and turret.activeSpell.target == unit.handle and not turret.activeSpell.isStopped and turret.team == 300-myHero.team then
            --PrintChat("turret shot")
            return true
        else
            return false
        end
    end
end

local function GetWDmg(unit)
    local Wdmg = getdmg("W", unit, myHero, 1)
    local W2dmg = getdmg("W", unit, myHero, 2)  
    local buff = GetBuffData(unit, "kaisapassivemarker")
    if buff and buff.count == 4 then
        return (Wdmg+W2dmg)     
    else        
        return Wdmg 
    end 
end

local function CastSpellMM(spell,pos,range,delay)
local castSpell = {state = 0, tick = GetTickCount(), casting = GetTickCount() - 1000, mouse = mousePos}
local range = range or math.huge
local delay = delay or 250
local ticker = GetTickCount()
    if castSpell.state == 0 and GetDistance(myHero.pos,pos) < range and ticker - castSpell.casting > delay + Game.Latency() then
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

local function HitChanceConvert(menVal)
    if menVal == 1 then
        return 0
    elseif menVal == 2 then 
        return 0.25
    elseif menVal == 3 then
        return 0.5
    elseif menVal == 4 then
        return 0.75
    elseif menVal == 5 then
        return 1
    end
end

function GGCast(spell, target, spellprediction, hitchance)
        if not (target or spellprediction) then
            return false
        end
        if spellprediction == nil then
            if target == nil then
                Control.KeyDown(spell)
                Control.KeyUp(spell)
                return true
            end
            _G.Control.CastSpell(spell, target)
            return true
        end
        if target == nil then
            return false
        end
        spellprediction:GetPrediction(target, myHero)
        if spellprediction:CanHit(hitchance or HITCHANCE_HIGH) and GetDistance(spellprediction.CastPosition, myHero.pos) < spellprediction.Range and GetDistance(spellprediction.CastPosition, target.pos) < 250 then
            _G.Control.CastSpell(spell, spellprediction.CastPosition)
            return true
        end
        return false
    end

function dnsCast(spell, pos, prediction, hitchance)
    local hitchance = hitchance or 0.1
    if pos == nil and prediction == nil then
        Control.KeyDown(spell)
        Control.KeyUp(spell)
    elseif prediction == nil then
        if pos:ToScreen().onScreen then
            _G.Control.CastSpell(spell, pos)
        else
            CastSpellMM(spell, pos)
        end
    else
        if prediction.type == "circular" then
            local pred = _G.PremiumPrediction:GetPrediction(myHero, pos, prediction)
            if pred.CastPos and pred.HitChance >= hitchance and GetDistance(pred.CastPos, myHero.pos) <= prediction.range then
                if pred.CastPos:ToScreen().onScreen then
                    _G.Control.CastSpell(spell, pred.CastPos)
                else
                    CastSpellMM(spell, pred.CastPos)
                end
            end
        elseif prediction.type == "linear" then
            local pred = _G.PremiumPrediction:GetPrediction(myHero, pos, prediction)
            if pred.CastPos and pred.HitChance >= hitchance and GetDistance(pred.CastPos, myHero.pos) <= prediction.range then
                if pred.CastPos:ToScreen().onScreen then
                    _G.Control.CastSpell(spell, pred.CastPos)
                else
                    local CastSpot = myHero.pos:Extended(pred.CastPos, 800)
                    _G.Control.CastSpell(spell, CastSpot)
                end
            end
        elseif prediction.type == "conic" then
            local pred = _G.PremiumPrediction:GetPrediction(myHero, pos, prediction)
            if pred.CastPos and pred.HitChance >= hitchance and GetDistance(pred.CastPos, myHero.pos) <= prediction.range then
                if pred.CastPos:ToScreen().onScreen then
                    _G.Control.CastSpell(spell, pred.CastPos)
                else
                    return
                end
            end
        end
    end
end

class "Manager"

function Manager:__init()
	if myHero.charName == "Kaisa" then
		DelayAction(function () self:LoadKaisa() end, 1.05)
	end
	if myHero.charName == "Caitlyn" then
		DelayAction(function() self:LoadCaitlyn() end, 1.05)
	end
	if myHero.charName == "Tristana" then
		DelayAction(function() self:LoadTristana() end, 1.05)
	end
    if myHero.charName == "Jinx" then
        DelayAction(function() self:LoadJinx() end, 1.05)
    end
    if myHero.charName == "Senna" then
        DelayAction(function() self:LoadSenna() end, 1.05)
    end
end

function Manager:LoadKaisa()
	Kaisa:Spells()
	Kaisa:Menu()
    
	Callback.Add("Tick", function() Kaisa:Tick() end)
	Callback.Add("Draw", function() Kaisa:Draws() end)
	if _G.SDK then
        _G.SDK.Orbwalker:OnPreAttack(function(...) Kaisa:OnPreAttack(...) end)
        _G.SDK.Orbwalker:OnPostAttackTick(function(...) Kaisa:OnPostAttackTick(...) end)
        _G.SDK.Orbwalker:OnPostAttack(function(...) Kaisa:OnPostAttack(...) end)
    end
end

function Manager:LoadCaitlyn()
    Caitlyn:Spells()
    Caitlyn:Menu()
    --
    --GetEnemyHeroes()
    Callback.Add("Tick", function() Caitlyn:Tick() end)
    Callback.Add("Draw", function() Caitlyn:Draw() end)
    if _G.SDK then
        _G.SDK.Orbwalker:OnPreAttack(function(...) Caitlyn:OnPreAttack(...) end)
        _G.SDK.Orbwalker:OnPostAttackTick(function(...) Caitlyn:OnPostAttackTick(...) end)
        _G.SDK.Orbwalker:OnPostAttack(function(...) Caitlyn:OnPostAttack(...) end)
    end
end

function Manager:LoadTristana()
    Tristana:Spells()
    Tristana:Menu()
    --
    --GetEnemyHeroes()
    Callback.Add("Tick", function() Tristana:Tick() end)
    Callback.Add("Draw", function() Tristana:Draw() end)
    if _G.SDK then
        _G.SDK.Orbwalker:OnPreAttack(function(...) Tristana:OnPreAttack(...) end)
        _G.SDK.Orbwalker:OnPostAttackTick(function(...) Tristana:OnPostAttackTick(...) end)
        _G.SDK.Orbwalker:OnPostAttack(function(...) Tristana:OnPostAttack(...) end)
    end
end

function Manager:LoadJinx()
    Jinx:Spells()
    Jinx:Menu()
    Callback.Add("Tick", function() Jinx:Tick() end)
    Callback.Add("Draw", function() Jinx:Draws() end)
end

function Manager:LoadSenna()
    Senna:Spells()
    Senna:Menu()
    Callback.Add("Tick", function() Senna:Tick() end)
    Callback.Add("Draw", function() Senna:Draws() end)
end

class "Kaisa"

local EnemyLoaded = false
local MinionsAround = count
local KaisaImg = "https://www.proguides.com/public/media/rlocal/champion/thumbnail/145.png"
local KaisaQImg = "https://www.proguides.com/public/media/rlocal/champion/ability/thumbnail/KaisaQ.png"
local KaisaWImg = "https://www.proguides.com/public/media/rlocal/champion/ability/thumbnail/KaisaW.png"
local KaisaEImg = "https://www.proguides.com/public/media/rlocal/champion/ability/thumbnail/KaisaE.png"
local KaisaRImg = "https://www.proguides.com/public/media/rlocal/champion/ability/thumbnail/KaisaR.png"

function Kaisa:Menu()
-- menu
	self.Menu = MenuElement({type = MENU, id = "Kaisa", name = "dnsKai'Sa", leftIcon = KaisaImg})
-- q spell
	self.Menu:MenuElement({id = "QSpell", name = "Q", type = MENU, leftIcon = KaisaQImg})
	self.Menu.QSpell:MenuElement({id = "QCombo", name = "Combo", value = true, leftIcon = KaisaQImg})
	self.Menu.QSpell:MenuElement({id = "QSpace1", name = "", type = SPACE})
	self.Menu.QSpell:MenuElement({id = "QHarass", name = "Harass", value = false, leftIcon = KaisaQImg})
	self.Menu.QSpell:MenuElement({id = "QHarassMana", name = "Harass Mana %", value = 40, min = 0, max = 100, identifier = "%", leftIcon = KaisaQImg})
	self.Menu.QSpell:MenuElement({id = "QSpace2", name = "", type = SPACE})
	self.Menu.QSpell:MenuElement({id = "QLaneClear", name = "LaneClear", value = true, leftIcon = KaisaQImg})
	self.Menu.QSpell:MenuElement({id = "QLaneClearCount", name = "LaneClear when Q can hit atleast", value = 4, min = 1, max = 9, step = 1, leftIcon = KaisaQImg})
	self.Menu.QSpell:MenuElement({id = "QLaneClearMana", name = "LaneClear Mana %", value = 60, min = 0, max = 100, identifier = "%", leftIcon = KaisaQImg})
	self.Menu.QSpell:MenuElement({id = "QSpace3", name = "", type = SPACE})
-- w spell
	self.Menu:MenuElement({id = "WSpell", name = "W", type = MENU, leftIcon = KaisaWImg})
	self.Menu.WSpell:MenuElement({id = "WCombo", name = "Combo", value = true, leftIcon = KaisaWImg})
	self.Menu.WSpell:MenuElement({id = "WSpace1", name = "", type = SPACE})
	self.Menu.WSpell:MenuElement({id = "WHarass", name = "Harass", value = false, leftIcon = KaisaWImg})
	self.Menu.WSpell:MenuElement({id = "WHarassMana", name = "Harass Mana %", value = 40, min = 0, max = 100, identifier = "%", leftIcon = KaisaWImg})
	self.Menu.WSpell:MenuElement({id = "WSpace2", name = "", type = SPACE})
	self.Menu.WSpell:MenuElement({id = "WLastHit", name = "LastHit Cannon when out of AA Range", value = true, leftIcon = KaisaWImg})
	self.Menu.WSpell:MenuElement({id = "WSpace3", name = "", type = SPACE})
	self.Menu.WSpell:MenuElement({id = "WKS", name = "KS", value = true, leftIcon = KaisaWImg})
	self.Menu.WSpell:MenuElement({id = "WSpace4", name = "", type = SPACE})
-- e spell 
	self.Menu:MenuElement({id = "ESpell", name = "E", type = MENU, leftIcon = KaisaEImg})
	self.Menu.ESpell:MenuElement({id = "ECombo", name = "Combo", value = true, leftIcon = KaisaEImg})
	self.Menu.ESpell:MenuElement({id = "ESpace1", name = "", type = SPACE})
	self.Menu.ESpell:MenuElement({id = "EFlee", name = "Flee", value = true, leftIcon = KaisaEImg})
	self.Menu.ESpell:MenuElement({id = "ESpace2", name = "", type = SPACE})
	self.Menu.ESpell:MenuElement({id = "EPeel", name = "Autopeel Meeledivers", value = true, leftIcon = KaisaEImg})
	self.Menu.ESpell:MenuElement({id = "ESpace3", name = "", type = SPACE})
-- r spell
	self.Menu:MenuElement({id = "RSpell", name = "R", type = MENU, leftIcon = KaisaRImg})
	self.Menu.RSpell:MenuElement({id = "Sorry", name = "R is an automatical thingy", type = SPACE, leftIcon = KaisaRImg})
	self.Menu.RSpell:MenuElement({id = "Sorry2", name = "I'm really sorry", type = SPACE, leftIcon = KaisaRImg})
-- draws
	self.Menu:MenuElement({id = "Draws", name = "Draws", type = MENU})
	self.Menu.Draws:MenuElement({id = "EnableDraws", name = "Enable", value = false})
	self.Menu.Draws:MenuElement({id = "DrawsSpace1", name = "", type = SPACE})
	self.Menu.Draws:MenuElement({id = "QDraw", name = "Q Range", value = false, leftIcon = KaisaQImg})
	self.Menu.Draws:MenuElement({id = "WDraw", name = "W Range", value = false, leftIcon = KaisaWImg})
	self.Menu.Draws:MenuElement({id = "RDraw", name = "R Range", value = false, leftIcon = KaisaRImg})
-- ranged helper
	self.Menu:MenuElement({id = "rangedhelper", name = "Use RangedHelper", value = false})
end

function Kaisa:Draws()
	if self.Menu.Draws.EnableDraws:Value() then
        if self.Menu.Draws.QDraw:Value() then
            Draw.Circle(myHero.pos, 600 + myHero.boundingRadius, 1, Draw.Color(255, 255, 0, 0))
        end
		if self.Menu.Draws.WDraw:Value() then
			Draw.Circle(myHero.pos, 3000, 1, Draw.Color(255, 0, 255, 0))
		end
		if self.Menu.Draws.RDraw:Value() and myHero:GetSpellData(_R).level <= 1 then
			Draw.Circle(myHero.pos, 1500, 1, Draw.Color(255, 255, 255, 255))
		end
		if self.Menu.Draws.RDraw:Value() and myHero:GetSpellData(_R).level == 2 then
			Draw.Circle(myHero.pos, 2250, 1, Draw.Color(255, 255, 255, 255))
		end
		if self.Menu.Draws.RDraw:Value() and myHero:GetSpellData(_R).level == 3 then
			Draw.Circle(myHero.pos, 3000, 1, Draw.Color(255, 255, 255, 255))
		end
    end
end

function Kaisa:CastingChecks()
	if CastingW or CastingE or CastingR then
		return false
	else 
		return true
	end
end

function Kaisa:Spells()
	WSpellData = {speed = 1750, range = 1400, delay = 0.4, radius = 65, collision = {"minion"}, type = "linear"}
end

function Kaisa:Tick()
    if _G.JustEvade and _G.JustEvade:Evading() or (_G.ExtLibEvade and _G.ExtLibEvade.Evading) or Game.IsChatOpen() or myHero.dead then return end
    target = GetTarget(1400)
	if target and ValidTarget(target) then
        --PrintChat(target.pos:To2D())
        --PrintChat(mousePos:To2D())
        GaleMouseSpot = self:RangedHelper(target)
    else
        _G.SDK.Orbwalker.ForceMovement = nil
    end
    AARange = _G.SDK.Data:GetAutoAttackRange(myHero)
	CastingQ = myHero.activeSpell.name == "KaisaQ"
	CastingW = myHero.activeSpell.name == "KaisaW"
	CastingE = myHero.activeSpell.name == "KaisaE"
	CastingR = myHero.activeSpell.name == "KaisaR"
    self:Logic()
	self:Auto()
	self:LastHit()
	self:LaneClear()
    if EnemyLoaded == false then
        local CountEnemy = 0
        for i, enemy in pairs(EnemyHeroes) do
            CountEnemy = CountEnemy + 1
        end
        if CountEnemy < 1 then
            GetEnemyHeroes()
        else
            EnemyLoaded = true
            PrintChat("Enemy Loaded")
        end
    end
end 

function Kaisa:CanUse(spell, mode)
	local ManaPercent = myHero.mana / myHero.maxMana * 100
	if mode == nil then
		mode = Mode()
	end
	if spell == _Q then
		if mode == "Combo" and IsReady(spell) and self.Menu.QSpell.QCombo:Value() then
			return true
		end
		if mode == "Harass" and IsReady(spell) and self.Menu.QSpell.QHarass:Value() and ManaPercent > self.Menu.QSpell.QHarassMana:Value() then
			return true
		end
		if mode == "LaneClear" and IsReady(spell) and self.Menu.QSpell.QLaneClear:Value() and ManaPercent > self.Menu.QSpell.QLaneClearMana:Value() then
			return true
		end
	elseif spell == _W then
		if mode == "Combo" and IsReady(spell) and self.Menu.WSpell.WCombo:Value() then
			return true
		end
		if mode == "Harass" and IsReady(spell) and self.Menu.WSpell.WHarass:Value() and ManaPercent > self.Menu.WSpell.WHarassMana:Value() then
			return true
		end
		if mode == "LastHit" and IsReady(spell) and self.Menu.WSpell.WLastHit:Value() then
			return true
		end
		if mode == "KS" and IsReady(spell) and self.Menu.WSpell.WKS:Value() then
			return true
		end
	elseif spell == _E then
		if mode == "Combo" and IsReady(spell) and self.Menu.ESpell.ECombo:Value() then
			return true
		end
		if mode == "Flee" and IsReady(spell) and self.Menu.ESpell.EFlee:Value() then
			return true
		end
		if mode == "ChargePeel" and IsReady(spell) and self.Menu.ESpell.EPeel:Value() then
			return true
		end
	end
	return false
end

function Kaisa:Auto()
	-- enemy loop
	for i, enemy in pairs(EnemyHeroes) do
		--w ks
		local WRange = 2000 + myHero.boundingRadius + enemy.boundingRadius 
		if ValidTarget(enemy, WRange) and self:CanUse(_W, "KS") and self:CastingChecks() and not _G.SDK.Attack:IsActive() then
			local WDamage = GetWDmg(enemy)
			local pred = _G.PremiumPrediction:GetPrediction(myHero, enemy, WSpellData)
			if pred.CastPos and pred.HitChance >= 0.7 and enemy.health <= WDamage then
				Control.CastSpell(HK_W, pred.CastPos)
			end
		end
		-- e peel
		local Bedrohungsreichweite = 250 + myHero.boundingRadius + enemy.boundingRadius
		if ValidTarget(enemy, Bedrohungsreichweite) and IsFacing(enemy) and not IsMyHeroFacing(enemy) and self:CanUse(_E, "ChargePeel") and self:CastingChecks() and not _G.SDK.Attack:IsActive() and enemy.activeSpell.target == myHero.handle then
			Control.CastSpell(HK_E)
		end
	end
end

function Kaisa:Logic()
	if target == nil then
		return
	end
	local QRange = 600 + myHero.boundingRadius + target.boundingRadius
	local WRange = 1400 + myHero.boundingRadius + target.boundingRadius
	local ERange = 525 + 300 + myHero.boundingRadius + target.boundingRadius
	
	
	if Mode() == "Combo" and target then
		if ValidTarget(target, QRange) and self:CanUse(_Q, "Combo") and self:CastingChecks() and not _G.SDK.Attack:IsActive() then
				Control.CastSpell(HK_Q)
		end
		if ValidTarget(target, WRange) and self:CanUse(_W, "Combo") and self:CastingChecks() and not _G.SDK.Attack:IsActive() then
			local pred = _G.PremiumPrediction:GetPrediction(myHero, target, WSpellData)
			if pred.CastPos and pred.HitChance >= 0.7 and GetBuffStacks(target, "kaisapassivemarker") >= 3 then 
				Control.CastSpell(HK_W, pred.CastPos)
			end
		end
		if ValidTarget(target, ERange) and self:CanUse(_E, "Combo") and self:CastingChecks() and not _G.SDK.Attack:IsActive() then
			if GetDistance(target.pos) > 550 + myHero.boundingRadius + target.boundingRadius and IsMyHeroFacing(target) then
				Control.CastSpell(HK_E)
			end
		end
	elseif Mode() == "Harass" and target then
		if ValidTarget(target, QRange) and self:CanUse(_Q, "Harass") and self:CastingChecks() and not _G.SDK.Attack:IsActive() and not IsUnderEnemyTurret(myHero.pos) then
				Control.CastSpell(HK_Q)
		end
		if ValidTarget(target, WRange) and self:CanUse(_W, "Harass") and self:CastingChecks() and not _G.SDK.Attack:IsActive() and not IsUnderEnemyTurret(myHero.pos) then
			local pred = _G.PremiumPrediction:GetPrediction(myHero, target, WSpellData)
			if pred.CastPos and pred.HitChance > 0.5 then 
				Control.CastSpell(HK_W, pred.CastPos)
			end
		end
	elseif Mode() == "Flee" and target then
		if ValidTarget(target, ERange) and self:CanUse(_E, "Flee") and self:CastingChecks() and not _G.SDK.Attack:IsActive() and not IsMyHeroFacing(enemy) then
				Control.CastSpell(HK_E)
		end
	end	
end

function Kaisa:LastHit()
	if self:CanUse(_W, "LastHit") and (Mode == "LastHit" or Mode() == "LaneClear" or Mode() == "Harass") then
		local minions = _G.SDK.ObjectManager:GetEnemyMinions(1400)
		for i = 1, #minions do 
			local minion = minions[i]
			if GetDistance(minion.pos) > 525 + myHero.boundingRadius and ValidTarget(minion, 1400 + myHero.boundingRadius) and (minion.charName == "SRU_ChaosMinionSiege" or minion.charName == "SRU_OrderMinionSiege") then
				local WDamage = GetWDmg(minion)
				if WDamage >= minion.health and self:CastingChecks() and not _G.SDK.Attack:IsActive() then 
					local pred = _G.PremiumPrediction:GetPrediction(myHero, minion, WSpellData)
					if pred.CastPos and pred.HitChance >= 0.20 then
						Control.CastSpell(HK_W, pred.CastPos)
					end
				end
			end
		end
	end
end

function Kaisa:LaneClear()
	local count = 0 
	if self:CanUse(_Q, "LaneClear") and Mode() == "LaneClear" then
		local minions = _G.SDK.ObjectManager:GetEnemyMinions(600)
		for i = 1, #minions do 
			local minion = minions[i]
			if ValidTarget(minion, 600 + myHero.boundingRadius + minion.boundingRadius) then
				count = count + 1
			end
			if MinionsAround >= self.Menu.QSpell.QLaneClearCount:Value() then
				Control.CastSpell(HK_Q)
			end
		end
	end
	MinionsAround = count
end

function Kaisa:RangedHelper(unit)
	local AARange = 525 + target.boundingRadius
    local EAARangel = _G.SDK.Data:GetAutoAttackRange(unit)
    local MoveSpot = nil
    local RangeDif = AARange - EAARangel
    local ExtraRangeDist = RangeDif
    local ExtraRangeChaseDist = RangeDif - 100

    local ScanDirection = Vector((myHero.pos-mousePos):Normalized())
    local ScanDistance = GetDistance(myHero.pos, unit.pos) * 0.8
    local ScanSpot = myHero.pos - ScanDirection * ScanDistance
	

    local MouseDirection = Vector((unit.pos-ScanSpot):Normalized())
    local MouseSpotDistance = EAARangel + ExtraRangeDist
    if not IsFacing(unit) then
        MouseSpotDistance = EAARangel + ExtraRangeChaseDist
    end
    if MouseSpotDistance > AARange then
        MouseSpotDistance = AARange
    end

    local MouseSpot = unit.pos - MouseDirection * (MouseSpotDistance)
	local MouseDistance = GetDistance(unit.pos, mousePos)
    local GaleMouseSpotDirection = Vector((myHero.pos-MouseSpot):Normalized())
    local GalemouseSpotDistance = GetDistance(myHero.pos, MouseSpot)
    if GalemouseSpotDistance > 300 then
        GalemouseSpotDistance = 300
    end
    local GaleMouseSpoty = myHero.pos - GaleMouseSpotDirection * GalemouseSpotDistance
    MoveSpot = MouseSpot

    if MoveSpot then
        if GetDistance(myHero.pos, MoveSpot) < 50 or IsUnderEnemyTurret(MoveSpot) then
            _G.SDK.Orbwalker.ForceMovement = nil
        elseif self.Menu.rangedhelper:Value() and GetDistance(myHero.pos, unit.pos) <= AARange-50 and (Mode() == "Combo" or Mode() == "Harass") and self:CastingChecks() and MouseDistance < 750 then
            _G.SDK.Orbwalker.ForceMovement = MoveSpot
        else
            _G.SDK.Orbwalker.ForceMovement = nil
        end
    end
    return GaleMouseSpoty
end

function Kaisa:OnPostAttack(args)
end

function Kaisa:OnPostAttackTick(args)
end

function Kaisa:OnPreAttack(args)
end


function OnLoad()
    Manager()
end

class "Caitlyn"

local EnemyLoaded = false
local EnemiesAround = count
local MinionsLaneClear = laneclearcount
local RAround = rcount
local CaitIcon = "https://www.proguides.com/public/media/rlocal/champion/thumbnail/51.png"
local CaitQIcon = "https://www.proguides.com/public/media/rlocal/champion/ability/thumbnail/CaitlynPiltoverPeacemaker.png"
local CaitWIcon = "https://www.proguides.com/public/media/rlocal/champion/ability/thumbnail/CaitlynYordleTrap.png"
local CaitEIcon = "https://www.proguides.com/public/media/rlocal/champion/ability/thumbnail/CaitlynEntrapment.png"
local CaitRIcon = "https://www.proguides.com/public/media/rlocal/champion/ability/thumbnail/CaitlynAceintheHole.png"

function Caitlyn:Menu()
    self.Menu = MenuElement({type = MENU, id = "Caitlyn", name = "dnsCaitlyn", leftIcon = CaitIcon})
    self.Menu:MenuElement({id = "QSpell", name = "Q", type = MENU, leftIcon = CaitQIcon})
	self.Menu.QSpell:MenuElement({id = "QCombo", name = "Combo", value = true, leftIcon = CaitQIcon})
	self.Menu.QSpell:MenuElement({id = "QComboHitChance", name = "HitChance", value = 0.5, min = 0.1, max = 1.0, step = 0.1, leftIcon = CaitQIcon})
	self.Menu.QSpell:MenuElement({id = "QHarass", name = "Harass", value = false, leftIcon = CaitQIcon})
	self.Menu.QSpell:MenuElement({id = "QHarassHitChance", name = "HitChance", value = 0.5, min = 0.1, max = 1.0, step = 0.1, leftIcon = CaitQIcon})
	self.Menu.QSpell:MenuElement({id = "QHarassMana", name = "Mana %", value = 40, min = 0, max = 100, identifier = "%", leftIcon = CaitQIcon})
	self.Menu.QSpell:MenuElement({id = "QLaneClear", name = "LaneClear", value = false, leftIcon = CaitQIcon})
	self.Menu.QSpell:MenuElement({id = "QLaneClearCount", name = "if HitCount is atleast", value = 5, min = 1, max = 9, step = 1, leftIcon = CaitQIcon})
	self.Menu.QSpell:MenuElement({id = "QLaneClearMana", name = "Mana %", value = 60, min = 0, max = 100, identifier = "%", leftIcon = CaitQIcon})
	self.Menu.QSpell:MenuElement({id = "QLastHit", name = "LastHit", value = true, leftIcon = CaitQIcon})
	self.Menu.QSpell:MenuElement({id = "QKS", name = "KS", value = true, leftIcon = CaitQIcon})
	self.Menu:MenuElement({id = "WSpell", name = "W", type = MENU, leftIcon = CaitWIcon})
	self.Menu.WSpell:MenuElement({id = "WImmo", name = "Auto W immobile Targets", value = true, leftIcon = CaitWIcon})
	self.Menu:MenuElement({id = "ESpell", name = "E", type = MENU, leftIcon = CaitEIcon})
	self.Menu.ESpell:MenuElement({id = "ECombo", name = "Combo", value = true, leftIcon = CaitEIcon})
	self.Menu.ESpell:MenuElement({id = "EComboHitChance", name = "HitChance", value = 1, min = 0.1, max = 1.0, step = 0.1, leftIcon = CaitEIcon})
	self.Menu.ESpell:MenuElement({id = "EHarass", name = "Harass", value = false, leftIcon = CaitEIcon})
	self.Menu.ESpell:MenuElement({id = "EHarassHitChance", name = "HitChance", value = 1, min = 0.1, max = 1.0, step = 0.1, leftIcon = CaitEIcon})
	self.Menu.ESpell:MenuElement({id = "EHarassMana", name = "Mana %", value = 60, min = 0, max = 100, identifier = "%", leftIcon = CaitEIcon})
	self.Menu.ESpell:MenuElement({id = "EGap", name = "Peel Meele Champs", value = true, leftIcon = CaitEIcon})
	self.Menu:MenuElement({id = "RSpell", name = "R", type = MENU, leftIcon = CaitRIcon})
	self.Menu.RSpell:MenuElement({id = "RKS", name = "KS", value = true, leftIcon = CaitRIcon})
	self.Menu:MenuElement({id = "MakeDraw", name = "Nubody nees dravvs", type = MENU, leftIcon = CaitRIcon})
	self.Menu.MakeDraw:MenuElement({id = "UseDraws", name = "U wanna hav dravvs?", value = false})
	self.Menu.MakeDraw:MenuElement({id = "QDraws", name = "U wanna Q-Range dravvs?", value = false, leftIcon = CaitQIcon})
	self.Menu.MakeDraw:MenuElement({id = "RDraws", name = "U wanna R-Range dravvs?", value = false, leftIcon = CaitRIcon})
	self.Menu:MenuElement({id = "rangedhelper", name = "Use RangedHelper", value = false})
end

function Caitlyn:Spells()
    QSpellData = {speed = 2200, range = 1300, delay = 0.625, radius = 50, collision = {}, type = "linear"}
	WSpellData = {speed = math.huge, range = 800, delay = 0.25, radius = 65, collision = {}, type = "circular"}
	ESpellData = {speed = 1600, range = 750, delay = 0.15, radius = 65, collision = {"minion"}, type = "linear"}
end

function Caitlyn:CastingChecks()
	if not CastingQ or CastingW or CastingR then
		return true
	else 
		return false
	end
end

function Caitlyn:Draw()
    if self.Menu.MakeDraw.UseDraws:Value() then
        if self.Menu.MakeDraw.QDraws:Value() then
            Draw.Circle(myHero.pos, 1300, 1, Draw.Color(237, 255, 255, 255))
        end
		if self.Menu.MakeDraw.RDraws:Value() then
			Draw.Circle(myHero.pos, 3500, 1, Draw.Color(237, 255, 255, 255))
		end
    end
end

function Caitlyn:Tick()
    if _G.JustEvade and _G.JustEvade:Evading() or (_G.ExtLibEvade and _G.ExtLibEvade.Evading) or Game.IsChatOpen() or myHero.dead then return end
    target = GetTarget(1400)
	if target and ValidTarget(target) then
        --PrintChat(target.pos:To2D())
        --PrintChat(mousePos:To2D())
        GaleMouseSpot = self:RangedHelper(target)
    else
        _G.SDK.Orbwalker.ForceMovement = nil
    end
	CastingQ = myHero.activeSpell.name == "CaitlynPiltoverPeacemaker"
	CastingW = myHero.activeSpell.name == "CaitlynYordleTrap"
	CastingE = myHero.activeSpell.name == "CaitlynEntrapment"
	CastingR = myHero.activeSpell.name == "CaitlynAceintheHole"
    self:Logic()
	self:KS()
	self:LastHit()
	self:LaneClear()
    if EnemyLoaded == false then
        local CountEnemy = 0
        for i, enemy in pairs(EnemyHeroes) do
            CountEnemy = CountEnemy + 1
        end
        if CountEnemy < 1 then
            GetEnemyHeroes()
        else
            EnemyLoaded = true
            PrintChat("Enemy Loaded")
        end
	end
end

function Caitlyn:KS()

	local rtarget = nil
	local count = 0
	for i, enemy in pairs(EnemyHeroes) do
	local QRange = 1300 + enemy.boundingRadius
	local RRange = 3500 + enemy.boundingRadius 
	local EPeelRange = 250 + enemy.boundingRadius 
	local WRange = 800 + enemy.boundingRadius 
		if GetDistance(enemy.pos) < 800 then
			count = count + 1
			--PrintChat(EnemiesAround)
		end
		if ValidTarget(enemy, RRange) and self:CanUse(_R,"KS") and GetDistance(myHero.pos, enemy.pos) > 900 + myHero.boundingRadius + enemy.boundingRadius and EnemiesAround == 0 and not IsUnderEnemyTurret(myHero.pos) and self:CastingChecks() and not _G.SDK.Attack:IsActive() then
			local RDamage = getdmg("R", enemy, myHero, myHero:GetSpellData(_R).level)
			if enemy.health <= RDamage then
				rtarget = enemy
			end
			local rcount = 0
            if rtarget ~= nil then
                for j, enemy2 in pairs(EnemyHeroes) do
				    local RLine = ClosestPointOnLineSegment(enemy2.pos, myHero.pos, rtarget.pos)
				    if GetDistance(RLine, enemy2.pos) <= 500 then
					   rcount = rcount + 1
				    end
                end
            end
			RAround = rcount
			if RAround == 1 then
				if enemy.pos:ToScreen().onScreen then
					Control.CastSpell(HK_R, enemy.pos)
				else
					local MMSpot = Vector(enemy.pos):ToMM()
					local MouseSpotBefore = mousePos
					Control.SetCursorPos(MMSpot.x, MMSpot.y)
					Control.KeyDown(HK_R); Control.KeyUp(HK_R)
					DelayAction(function() Control.SetCursorPos(MouseSpotBefore) end, 0.20)
				end
			end
		end
		if ValidTarget(enemy, QRange) and self:CanUse(_Q, "KS") then
			local QDamage = getdmg("Q", enemy, myHero, myHero:GetSpellData(_Q).level)
			local pred = _G.PremiumPrediction:GetPrediction(myHero, enemy, QSpellData)
			if pred.CastPos and _G.PremiumPrediction.HitChance.High(pred.HitChance) and enemy.health < QDamage and GetDistance(pred.CastPos) > 650 + myHero.boundingRadius + enemy.boundingRadius and Caitlyn:CastingChecks() and not _G.SDK.Attack:IsActive() then
				Control.CastSpell(HK_Q, pred.CastPos)
			end
		end
		if ValidTarget(enemy, WRange) and self:CanUse(_W, "TrapImmo") and self:CastingChecks() and not _G.SDK.Attack:IsActive() and (IsImmobile(enemy) > 0.5 or enemy.ms <= enemy.ms * 0.25) and not BuffActive(enemy, "caitlynyordletrapdebuff") then
			local pred = _G.PremiumPrediction:GetPrediction(myHero, enemy, WSpellData)
			if pred.CastPos and pred.HitChance >= 1 then
				Control.CastSpell(HK_W, pred.CastPos)
			end
		end
		if ValidTarget(enemy, EPeelRange) and self:CanUse(_E, "NetGap") and self:CastingChecks() and not _G.SDK.Attack:IsActive() and IsFacing(enemy) and not IsMyHeroFacing(enemy) and enemy.activeSpell.target == myHero.handle then
				Control.CastSpell(HK_E, enemy)
		end
		if enemy and ValidTarget(enemy, 1300 + myHero.boundingRadius + enemy.boundingRadius) and (GetBuffDuration(enemy, "CaitlynEntrapmentMissile") > 0 or GetBuffDuration(enemy, "caitlynyordletrapdebuff") > 0) then
			_G.SDK.Orbwalker.ForceTarget = enemy
		else
			_G.SDK.Orbwalker.ForceTarget = nil
		end
	end
	EnemiesAround = count
end

function Caitlyn:CanUse(spell, mode)
	local ManaPercent = myHero.mana / myHero.maxMana * 100
	if mode == nil then
		mode = Mode()
	end
	
	if spell == _Q then
		if mode == "Combo" and IsReady(spell) and self.Menu.QSpell.QCombo:Value() then
			return true
		end
		if mode == "Harass" and IsReady(spell) and self.Menu.QSpell.QHarass:Value() and ManaPercent > self.Menu.QSpell.QHarassMana:Value() then
			return true
		end
		if mode == "LaneClear" and IsReady(spell) and self.Menu.QSpell.QLaneClear:Value() and ManaPercent > self.Menu.QSpell.QLaneClearMana:Value() then
			return true
		end
		if mode == "KS" and IsReady(spell) and self.Menu.QSpell.QKS:Value() then
			return true
		end
		if mode == "LastHit" and IsReady(spell) and self.Menu.QSpell.QLastHit:Value() then
			return true
		end
	elseif spell == _W then
		if mode == "TrapImmo" and IsReady(spell) and self.Menu.WSpell.WImmo:Value() then
			return true
		end
	elseif spell == _E then
		if mode == "Combo" and IsReady(spell) and self.Menu.ESpell.ECombo:Value() then
			return true
		end
		if mode == "Harass" and IsReady(spell) and self.Menu.ESpell.EHarass:Value()and ManaPercent > self.Menu.ESpell.EHarassMana:Value() then
			return true
		end
		if mode == "NetGap" and IsReady(spell) and self.Menu.ESpell.EGap:Value() then
			return true
		end
	elseif spell == _R then
		if mode == "KS" and IsReady(spell) and self.Menu.RSpell.RKS:Value() then
			return true
		end
	end
	return false
end

function Caitlyn:Logic()
    if target == nil then 
        return 
    end
	local maxQRange = 1300 + target.boundingRadius
	local minQRange = 650 + target.boundingRadius
	local ERange = 750 + target.boundingRadius
	
    if Mode() == "Combo" and target then
        if self:CanUse(_Q, "Combo") and ValidTarget(target, maxQRange) and Caitlyn:CastingChecks() and not _G.SDK.Attack:IsActive() and GetDistance(myHero.pos, target.pos) > minQRange  then
            local pred = _G.PremiumPrediction:GetPrediction(myHero, target, QSpellData)
			if pred.CastPos and pred.HitChance > self.Menu.QSpell.QComboHitChance:Value() then
				Control.CastSpell(HK_Q, pred.CastPos)
			end
        elseif self:CanUse(_Q, "Combo") and ValidTarget(target, maxQRange) and Caitlyn:CastingChecks() and (GetBuffDuration(target, "CaitlynEntrapmentMissile") >= 0.5 or GetBuffDuration(target, "caitlynyordletrapdebuff") >= 0.5) then
			Control.CastSpell(HK_Q, target.pos)
		end
		if self:CanUse(_E, "Combo") and ValidTarget(target, ERange) and self:CastingChecks() and not _G.SDK.Attack:IsActive() then
			local pred = _G.PremiumPrediction:GetPrediction(myHero, target, ESpellData)
			if pred.CastPos and pred.HitChance > self.Menu.ESpell.EComboHitChance:Value() then 
				Control.CastSpell(HK_E, pred.CastPos)
			end
		elseif self:CanUse(_E, "Combo") and ValidTarget(target, ERange) and self:CastingChecks() and not _G.SDK.Attack:IsActive() and GetBuffDuration(target, "caitlynyordletrapdebuff") >= 0.5 then
			local pred = _G.PremiumPrediction:GetPrediction(myHero, target, ESpellData)
			if pred.CastPos and pred.HitChance > 0.5 then
				Control.CastSpell(HK_E, pred.CastPos)
			end
		end
	elseif Mode() == "Harass" and target then
		if self:CanUse(_Q, "Harass") and ValidTarget(target, maxQRange) and self:CastingChecks() and not _G.SDK.Attack:IsActive() and GetDistance(myHero.pos, target.pos) > minQRange and not IsUnderEnemyTurret(myHero.pos) then
            local pred = _G.PremiumPrediction:GetPrediction(myHero, target, QSpellData)
			if pred.CastPos and pred.HitChance > self.Menu.QSpell.QHarassHitChance:Value() then
				Control.CastSpell(HK_Q, pred.CastPos)
			end
        elseif self:CanUse(_Q, "Harass") and ValidTarget(target, maxQRange) and self:CastingChecks() and not _G.SDK.Attack:IsActive() and (GetBuffDuration(target, "CaitlynEntrapmentMissile") >= 0.5 or GetBuffDuration(target, "caitlynyordletrapdebuff") >= 0.5) and not IsUnderEnemyTurret(myHero.pos) then
			Control.CastSpell(HK_Q, target.pos)
		end
		if self:CanUse(_E, "Harass") and ValidTarget(target, ERange) and self:CastingChecks() and not _G.SDK.Attack:IsActive() and not IsUnderEnemyTurret(myHero.pos) then
			local pred = _G.PremiumPrediction:GetPrediction(myHero, target, ESpellData)
			if pred.CastPos and pred.HitChance > self.Menu.ESpell.EHarassHitChanceHitChance:Value() then 
				Control.CastSpell(HK_E, pred.CastPos)
			end
		elseif self:CanUse(_E, "Harass") and ValidTarget(target, ERange) and self:CastingChecks() and not _G.SDK.Attack:IsActive() and GetBuffDuration(target, "caitlynyordletrapdebuff") >= 0.5 and not IsUnderEnemyTurret(myHero.pos) then
			local pred = _G.PremiumPrediction:GetPrediction(myHero, target, ESpellData)
			if pred.CastPos and pred.HitChance > 0.5 then
				Control.CastSpell(HK_E, pred.CastPos)
			end
		end
	end
end

function Caitlyn:LastHit()
	if self:CanUse(_Q, "LastHit") and (Mode() == "LastHit" or Mode() == "Harass") then
		local minions = _G.SDK.ObjectManager:GetEnemyMinions(1300)
		for i = 1, #minions do
			local minion = minions[i]
			local QDam = getdmg("Q", minion, myHero, myHero:GetSpellData(_Q).level)
			local EDam = getdmg("E", minion, myHero, myHero:GetSpellData(_E).level)
			if GetDistance(minion.pos) > 650 and ValidTarget(minion, 1300) and (minion.charName == "SRU_ChaosMinionSiege" or minion.charName == "SRU_OrderMinionSiege") and self:CastingChecks() and not _G.SDK.Attack:IsActive() then
				local pred = _G.PremiumPrediction:GetPrediction(myHero, minion, QSpellData)
				if QDam >= minion.health and pred.CastPos and pred.HitChance > 0.20 then
					Control.CastSpell(HK_Q, pred.CastPos)
				end
			end
		end
	end
end

function Caitlyn:LaneClear()
    if self:CanUse(_Q, "LaneClear") and Mode() == "LaneClear" then
        local minions = _G.SDK.ObjectManager:GetEnemyMinions(1300)
        for i = 1, #minions do
            local minion = minions[i]
            if ValidTarget(minion, 1300 + myHero.boundingRadius) then
                mainminion = minion
            end
			local laneclearcount = 0
			for j = 1, #minions do
				local minion2 = minions[j]
				local MinionNear = ClosestPointOnLineSegment(minion2.pos, myHero.pos, mainminion.pos)
				if GetDistance(MinionNear, minion2.pos) < 120 then
					laneclearcount = laneclearcount + 1
				end
			end
			MinionsLaneClear = laneclearcount
			if MinionsLaneClear >= self.Menu.QSpell.QLaneClearCount:Value() then	
				Control.CastSpell(HK_Q, mainminion.pos)
			end
        end
		
    end
end

function Caitlyn:RangedHelper(unit)
	local AARange = 625 + target.boundingRadius
    local EAARangel = _G.SDK.Data:GetAutoAttackRange(unit)
    local MoveSpot = nil
    local RangeDif = AARange - EAARangel
    local ExtraRangeDist = RangeDif
    local ExtraRangeChaseDist = RangeDif - 100

    local ScanDirection = Vector((myHero.pos-mousePos):Normalized())
    local ScanDistance = GetDistance(myHero.pos, unit.pos) * 0.8
    local ScanSpot = myHero.pos - ScanDirection * ScanDistance
	

    local MouseDirection = Vector((unit.pos-ScanSpot):Normalized())
    local MouseSpotDistance = EAARangel + ExtraRangeDist
    if not IsFacing(unit) then
        MouseSpotDistance = EAARangel + ExtraRangeChaseDist
    end
    if MouseSpotDistance > AARange then
        MouseSpotDistance = AARange
    end

    local MouseSpot = unit.pos - MouseDirection * (MouseSpotDistance)
	local MouseDistance = GetDistance(unit.pos, mousePos)
    local GaleMouseSpotDirection = Vector((myHero.pos-MouseSpot):Normalized())
    local GalemouseSpotDistance = GetDistance(myHero.pos, MouseSpot)
    if GalemouseSpotDistance > 300 then
        GalemouseSpotDistance = 300
    end
    local GaleMouseSpoty = myHero.pos - GaleMouseSpotDirection * GalemouseSpotDistance
    MoveSpot = MouseSpot

    if MoveSpot then
        if GetDistance(myHero.pos, MoveSpot) < 50 or IsUnderEnemyTurret(MoveSpot) then
            _G.SDK.Orbwalker.ForceMovement = nil
        elseif self.Menu.rangedhelper:Value() and GetDistance(myHero.pos, unit.pos) <= AARange-50 and (Mode() == "Combo" or Mode() == "Harass") and self:CastingChecks() and MouseDistance < 750 then
            _G.SDK.Orbwalker.ForceMovement = MoveSpot
        else
            _G.SDK.Orbwalker.ForceMovement = nil
        end
    end
    return GaleMouseSpoty
end
			
function Caitlyn:OnPostAttack(args)
end

function Caitlyn:OnPostAttackTick(args)
end

function Caitlyn:OnPreAttack(args)
end



function OnLoad()
    Manager()
end

class "Tristana"

local EnemyLoaded = false
local TristIcon = "https://www.proguides.com/public/media/rlocal/champion/thumbnail/18.png"
local TristQIcon = "https://www.proguides.com/public/media/rlocal/champion/ability/thumbnail/TristanaQ.png"
local TristWIcon = "https://www.proguides.com/public/media/rlocal/champion/ability/thumbnail/TristanaW.png"
local TristEIcon = "https://www.proguides.com/public/media/rlocal/champion/ability/thumbnail/TristanaE.png"
local TristRIcon = "https://www.proguides.com/public/media/rlocal/champion/ability/thumbnail/TristanaR.png"

function Tristana:Menu()
	self.Menu = MenuElement({type = MENU, id = "dnsTristana", name = "dnsTristana", leftIcon = TristIcon})
-- main menu
	self.Menu:MenuElement({id = "combo", name = "Combo", type = MENU})
	self.Menu:MenuElement({id = "harass", name = "Harass", type = MENU})
	self.Menu:MenuElement({id = "laneclear", name = "LaneClear", type = MENU})
	self.Menu:MenuElement({id = "auto", name = "Auto", type = MENU})
	self.Menu:MenuElement({id = "draws", name = "Draws", type = MENU})
	self.Menu:MenuElement({id = "rangedhelper", name = "Use RangedHelper", value = false})
-- combo 
	self.Menu.combo:MenuElement({id = "qcombo", name = "Use Q in Combo", value = true, leftIcon = TristQIcon})
	self.Menu.combo:MenuElement({id = "qcomboe", name = "Only Q when E", value = true, leftIcon = TristQIcon})
	self.Menu.combo:MenuElement({id = "ecombo", name = "Use E in Combo", value = true, leftIcon = TristEIcon})
-- harass
	self.Menu.harass:MenuElement({id = "qharass", name = "Use Q in Harass", value = true, leftIcon = TristQIcon})
	self.Menu.harass:MenuElement({id = "qharasse", name = "Only Q when E", value = true, leftIcon = TristQIcon})
	self.Menu.harass:MenuElement({id = "qharassmana", name = "Q Harass Mana", value = 40, min = 5, max = 95, step = 5, identifier = "%", leftIcon = TristQIcon})
	self.Menu.harass:MenuElement({id = "eharass", name = "Use E in Harass", value = true, leftIcon = TristEIcon})
	self.Menu.harass:MenuElement({id = "eharassmana", name = "E Harass Mana", value = 40, min = 5, max = 95, step = 5, identifier = "%", leftIcon = TristEIcon})
-- laneclear
	self.Menu.laneclear:MenuElement({id = "qlaneclear", name = "Use Q in LaneClear", value = true, leftIcon = TristQIcon})
	self.Menu.laneclear:MenuElement({id = "qlaneclearcount", name = "Q LaneClear Minions", value = 6, min = 1, max = 9, step = 1, leftIcon = TristQIcon})
	self.Menu.laneclear:MenuElement({id = "qlaneclearmana", name = "Q LaneClear Mana", value = 60, min = 5, max = 95, step = 5, identifier = "%", leftIcon = TristQIcon})
-- auto 
	self.Menu.auto:MenuElement({id = "rks", name = "Use R to KS", value = true, leftIcon = TristRIcon})
	self.Menu.auto:MenuElement({id = "wrks", name = "Use W + R to KS", value = true, leftIcon = TristWIcon})
	self.Menu.auto:MenuElement({id = "wrksspace", name = "To Use WRKS, normal RKS needs to be ticked", type = SPACE, leftIcon = TristRIcon})
	self.Menu.auto:MenuElement({id = "rpeel", name = "Use R to Peel", value = true, leftIcon = TristRIcon})
	self.Menu.auto:MenuElement({id = "rpeelhp", name = "If HP is lower then", value = 40, min = 5, max = 95, step = 5, identifier = "%", leftIcon = TristRIcon})
-- draws 
	self.Menu.draws:MenuElement({id = "qtimer", name = "Draw Q Timer", value = false, leftIcon = TristQIcon})
	self.Menu.draws:MenuElement({id = "wdraw", name = "Draw W Range", value = false, leftIcon = TristWIcon})
	self.Menu.draws:MenuElement({id = "anydraw", name = "Draw AA/E/R Range", value = false, leftIcon = TristEIcon})
end

function Tristana:Draw()
	local anyrange = 517 + (8 * myHero.levelData.lvl) + myHero.boundingRadius
	-- w draws
	if self.Menu.draws.wdraw:Value() then
		Draw.Circle(myHero.pos, 850 + myHero.boundingRadius, 2, Draw.Color(255, 23, 230, 220))
	end
	-- q timer 
	local QBuffDuration = GetBuffDuration(myHero, "TristanaQ")
	if self.Menu.draws.qtimer:Value() and BuffActive(myHero, "TristanaQ") then
		DrawTextOnHero(myHero, QBuffDuration, Draw.Color(255, 23, 230, 220))
	end
	--AAER draw
	if self.Menu.draws.anydraw:Value() then
		Draw.Circle(myHero.pos, anyrange, 2, Draw.Color(255, 49, 203, 100))
	end
end

function Tristana:Spells() 
	WSpellData = {speed = 1100, range = 850 + myHero.boundingRadius, delay = 0.25, radius = 350, collision = {}, type = "circular" }
end

function Tristana:Tick()
	if _G.JustEvade and _G.JustEvade:Evading() or (_G.ExtLibEvade and _G.ExtLibEvade.Evading) or Game.IsChatOpen() or myHero.dead then return end
	target = GetTarget(1400)
	AARange = _G.SDK.Data:GetAutoAttackRange(myHero)
	if target and ValidTarget(target) then
        --PrintChat(target.pos:To2D())
        --PrintChat(mousePos:To2D())
        GaleMouseSpot = self:RangedHelper(target)
    else
        _G.SDK.Orbwalker.ForceMovement = nil
    end
	-- casting checks
	CastingQ = myHero.activeSpell.name == "TristanaQ"
	CastingW = myHero.activeSpell.name == "TristanaW"
	CastingE = myHero.activeSpell.name == "TristanaE"
	CastingR = myHero.activeSpell.name == "TristanaR"
	self:Auto()
	self:Logic()
	self:LaneClear()
	if EnemyLoaded == false then
        local CountEnemy = 0
        for i, enemy in pairs(EnemyHeroes) do
            CountEnemy = CountEnemy + 1
        end
        if CountEnemy < 1 then
            GetEnemyHeroes()
        else
            EnemyLoaded = true
            PrintChat("Enemy Loaded")
        end
	end
end

function Tristana:CastingChecks()
	if not CastingE and not CastingR then
		return true
	else 
		return false
	end
end

function Tristana:CanUse(spell, mode)
	local ManaPercent = myHero.mana / myHero.maxMana * 100
	local HPPercent = myHero.health / myHero.maxHealth

	if mode == nil then
		mode = Mode()
	end

	if spell == _Q then
		if mode == "Combo" and IsReady(_Q) and self.Menu.combo.qcombo:Value() then 
			return true
		end
		if mode == "Harass" and IsReady(_Q) and self.Menu.harass.qharass:Value() and ManaPercent >= self.Menu.harass.qharassmana:Value() then
			return true
		end
		if mode == "LaneClear" and IsReady(_Q) and self.Menu.laneclear.qlaneclear:Value() and ManaPercent >= self.Menu.laneclear.qlaneclearmana:Value() then
			return true
		end
	elseif spell == _W then
		if mode == "WRKS" and IsReady(_W) and self.Menu.auto.wrks:Value() then
			return true
		end
	elseif spell == _E then
		if mode == "Combo" and IsReady(_E) and self.Menu.combo.ecombo:Value() then
			return true
		end
		if mode == "Harass" and IsReady(_E) and self.Menu.harass.eharass:Value() and ManaPercent >= self.Menu.harass.eharassmana:Value() then
			return true
		end
		if mode == "Tower" and IsReady(_E) and self.Menu.laneclear.etower:Value() and ManaPercent >= self.Menu.laneclear.etowermana:Value() then
			return true
		end
	elseif spell == _R then
		if mode == "KS" and IsReady(_R) and self.Menu.auto.rks:Value() then 
			return true
		end
		if mode == "WRKS" and IsReady(_R) and self.Menu.auto.wrks:Value() then
			return true
		end
		if mode == "Peel" and IsReady(_R) and self.Menu.auto.rpeel:Value() and HPPercent <= self.Menu.auto.rpeelhp:Value() / 100 then
			return true
		end
	end
	return false
end

function Tristana:EDMG(unit)
	local eLvl = myHero:GetSpellData(_E).level
	if eLvl > 0 then
		local raw = ({ 154, 176, 198, 220, 242 })[eLvl]
		local m = ({ 1.1, 1.65, 2.2, 2.75, 3.3 })[eLvl]
		local bonusDmg = (m * myHero.bonusDamage) + (1.1 * myHero.ap)
		local FullDmg = raw + bonusDmg
		return CalcPhysicalDamage(myHero, unit, FullDmg)  
	end
end

function Tristana:Auto()
	for i, enemy in pairs(EnemyHeroes) do
		local WRange = 850 + myHero.boundingRadius + enemy.boundingRadius
		local AAERRange = 517 + (8 * myHero.levelData.lvl) + myHero.boundingRadius + enemy.boundingRadius


		-- rks 
		if enemy and ValidTarget(enemy, AAERRange) and self:CanUse(_R, "KS") and self:CastingChecks() and myHero.attackData.state ~= 2 then
			local EDamage = self:EDMG(enemy)
			local RDamage = getdmg("R", enemy, myHero, myHero:GetSpellData(_R).level)
			if GetBuffStacks(enemy, "tristanaecharge") >= 3 and enemy.health <= RDamage + EDamage or enemy.health <= RDamage then
				Control.CastSpell(HK_R, enemy)
			end
		end

		--wrks
		if enemy and ValidTarget(enemy, AAERRange + WRange - 100) and GetDistance(enemy.pos, myHero.pos) > AAERRange + 50 and self:CanUse(_R, "WRKS") and self:CanUse(_W, "WRKS") and self:CastingChecks() and myHero.attackData.state ~= 2 then
			local EDamage = self:EDMG(enemy)
			local RDamage = getdmg("R", enemy, myHero, myHero:GetSpellData(_R).level)
			if (GetBuffStacks(enemy, "tristanaecharge") >= 3 and enemy.health <= RDamage + EDamage or enemy.health <= RDamage) then
				local Direction = Vector((enemy.pos-myHero.pos):Normalized())
				local WSpot = enemy.pos - Direction * (AAERRange - 50)
				Control.CastSpell(HK_W, WSpot)
			end
		end
		-- r peel
		if enemy and ValidTarget(enemy, 250 + myHero.boundingRadius + enemy.boundingRadius) and self:CanUse(_R, "Peel") and IsFacing(enemy) and not IsMyHeroFacing(enemy) and self:CastingChecks() and enemy.activeSpell.target == myHero.handle and enemy.activeSpell.valid and enemy.activeSpell.spellWasCast then
			Control.CastSpell(HK_R, enemy)
		end
		-- force target
		if enemy and ValidTarget(enemy, AAERRange) and GetBuffDuration(enemy, "tristanaechargesound") > 0 then
			_G.SDK.Orbwalker.ForceTarget = enemy
		else
			_G.SDK.Orbwalker.ForceTarget = nil
		end
	end
end


function Tristana:Logic() 
	if target == nil then return end

	local WRange = 850 + myHero.boundingRadius + target.boundingRadius
	local AAERRange = 517 + (8 * myHero.levelData.lvl) + myHero.boundingRadius + target.boundingRadius
	if Mode() == "Combo" and target then
		if target and ValidTarget(target, AAERRange) and self:CanUse(_E, "Combo") and myHero.attackData.state ~= 2 and self:CastingChecks() then
			Control.CastSpell(HK_E, target)
		end
		if target and ValidTarget(target, AAERRange) and self:CanUse(_Q, "Combo") and self.Menu.combo.qcomboe:Value() and GetBuffDuration(target, "tristanaechargesound") >= 0.5 and self:CastingChecks() and myHero.attackData.state == 2 then
			Control.CastSpell(HK_Q)
		elseif target and ValidTarget(target, AAERRange) and self:CanUse(_Q, "Combo") and not self.Menu.combo.qcomboe:Value() and self:CastingChecks() and myHero.attackData.state == 2 then
			Control.CastSpell(HK_Q)
		end
	end
	if Mode() == "Harass" and target then
		if target and ValidTarget(target, AAERRange) and self:CanUse(_E, "Harass") and myHero.attackData.state ~= 2 and self.CastingChecks() then
			Control.CastSpell(HK_E, target)
		end
		if target and ValidTarget(target, AAERRange) and self:CanUse(_Q, "Harass") and self.Menu.harass.qharasse.Value() and GetBuffDuration(target, "tristanaechargesound") >= 0.5 and self:CastingChecks() and myHero.attackData.state == 2 then
			Control.CastSpell(HK_Q)
		elseif target and ValidTarget(target, AAERRange) and self:CanUse(_Q, "Harass") and not self.Menu.harass.qharasse.Value() and self:CastingChecks() and myHero.attackData.state == 2 then
			Control.CastSpell(HK_Q)
		end
	end
end

function Tristana:LaneClear()
	local qcount = 0
	if Mode() == "LaneClear" then 
		local minions = _G.SDK.ObjectManager:GetEnemyMinions(1300)
		for i = 1, #minions do
			local minion = minions[i]
			local WRange = 850 + myHero.boundingRadius + minion.boundingRadius
			local AAERRange = 517 + (8 * myHero.levelData.lvl) + myHero.boundingRadius + minion.boundingRadius
			--laneclear q
			if minion and ValidTarget(minion, AAERRange + 100) and self:CanUse(_Q, "LaneClear") then
				qcount = qcount + 1
				--PrintChat(qcount)
			end
			if qcount >= self.Menu.laneclear.qlaneclearcount:Value() and myHero.attackData.state == 2 then
				Control.CastSpell(HK_Q)
			end
		end
	end
end

function Tristana:RangedHelper(unit)
	local AARange = 517 + (8 * myHero.levelData.lvl) + myHero.boundingRadius + target.boundingRadius
    local EAARangel = _G.SDK.Data:GetAutoAttackRange(unit)
    local MoveSpot = nil
    local RangeDif = AARange - EAARangel
    local ExtraRangeDist = RangeDif
    local ExtraRangeChaseDist = RangeDif - 100

    local ScanDirection = Vector((myHero.pos-mousePos):Normalized())
    local ScanDistance = GetDistance(myHero.pos, unit.pos) * 0.8
    local ScanSpot = myHero.pos - ScanDirection * ScanDistance
	

    local MouseDirection = Vector((unit.pos-ScanSpot):Normalized())
    local MouseSpotDistance = EAARangel + ExtraRangeDist
    if not IsFacing(unit) then
        MouseSpotDistance = EAARangel + ExtraRangeChaseDist
    end
    if MouseSpotDistance > AARange then
        MouseSpotDistance = AARange
    end

    local MouseSpot = unit.pos - MouseDirection * (MouseSpotDistance)
	local MouseDistance = GetDistance(unit.pos, mousePos)
    local GaleMouseSpotDirection = Vector((myHero.pos-MouseSpot):Normalized())
    local GalemouseSpotDistance = GetDistance(myHero.pos, MouseSpot)
    if GalemouseSpotDistance > 300 then
        GalemouseSpotDistance = 300
    end
    local GaleMouseSpoty = myHero.pos - GaleMouseSpotDirection * GalemouseSpotDistance
    MoveSpot = MouseSpot

    if MoveSpot then
        if GetDistance(myHero.pos, MoveSpot) < 50 or IsUnderEnemyTurret(MoveSpot) then
            _G.SDK.Orbwalker.ForceMovement = nil
        elseif self.Menu.rangedhelper:Value() and GetDistance(myHero.pos, unit.pos) <= AARange-50 and (Mode() == "Combo" or Mode() == "Harass") and self:CastingChecks() and MouseDistance < 750 then
            _G.SDK.Orbwalker.ForceMovement = MoveSpot
        else
            _G.SDK.Orbwalker.ForceMovement = nil
        end
    end
    return GaleMouseSpoty
end

function Tristana:OnPostAttack(args)
end

function Tristana:OnPostAttackTick(args)
end

function Tristana:OnPreAttack(args)
end



function OnLoad()
    Manager()
end

class "Jinx"

local EnemyLoaded = false

-- ranges
local BaseAARange = 580
local AARange = 0
local QRange = 0
local QCheckRange = 0
local WRange = 1450
local ERange = 900
local RRange = 20000

-- buffs
local powpow = "jinxqicon"
local fishbones = "JinxQ"

-- icons
local ChampIcon = "https://www.proguides.com/public/media/rlocal/champion/thumbnail/222.png"
local QIcon = "https://www.proguides.com/public/media/rlocal/champion/ability/thumbnail/JinxQ.png"
local WIcon = "https://www.proguides.com/public/media/rlocal/champion/ability/thumbnail/JinxW.png"
local EIcon = "https://www.proguides.com/public/media/rlocal/champion/ability/thumbnail/JinxE.png"
local RIcon = "https://www.proguides.com/public/media/rlocal/champion/ability/thumbnail/JinxR.png"

-- counts
local ComboTimer = 0
local Timer = Game.Timer()
local QLaneClearCount = nil

function Jinx:Menu()
    self.Menu = MenuElement({type = MENU, id = "jinx", name = "dnsJinx", leftIcon = ChampIcon})

    -- Combo
    self.Menu:MenuElement({id = "combo", name = "Combo", type = MENU})
    self.Menu.combo:MenuElement({id = "qcombo", name = "Use [Q] in Combo", value = true, leftIcon = QIcon})
    self.Menu.combo:MenuElement({id = "wcombo", name = "Use [W] in Combo", value = true, leftIcon = WIcon})
    self.Menu.combo:MenuElement({id = "wcombohc", name = "[W] HitChance", value = 2, drop = {"Normal", "High", "Immobile"}, leftIcon = WIcon})
    self.Menu.combo:MenuElement({id = "wcomboaa", name = "Use [W] only if Target is out of [AA] Range", value = true, leftIcon = WIcon})
    self.Menu.combo:MenuElement({id = "ecombo", name = "Use [E] in Combo", value = true, leftIcon = EIcon})
    self.Menu.combo:MenuElement({id = "ecombohc", name = "[E] HitChance", value = 2, drop = {"Normal", "High", "Immobile"}, leftIcon = EIcon})
    self.Menu.combo:MenuElement({id = "rcombo", name = "Use [R] in Combo", value = true, leftIcon = RIcon})
    self.Menu.combo:MenuElement({id = "rcombohc", name = "[R] HitChance", value = 2, drop = {"Normal", "High", "Immobile"}, leftIcon = RIcon})
    self.Menu.combo:MenuElement({id = "rcombocount", name = "[R] HitCount", value = 3, min = 1, max = 5, step = 1, leftIcon = RIcon})
    self.Menu.combo:MenuElement({id = "rcomboaa", name = "Use [R] if Target is out of [AA] Range", value = true, leftIcon = RIcon})
    self.Menu.combo:MenuElement({id = "rcomborange", name = "[R] Range", value = 3000, min = 500, max = 20000, step = 500, leftIcon = RIcon})
    self.Menu.combo:MenuElement({id  ="rsemi", name = "Semi [R] Key", value = false, key = string.byte("T"), leftIcon = RIcon})

    -- lasthit
    self.Menu:MenuElement({id = "lasthit", name = "LastHit", type = MENU})
    self.Menu.lasthit:MenuElement({id = "wlasthit", name = "Use [W] to LastHit Cannon out of [AA] Range", value = true, leftIcon = WIcon})
    self.Menu.lasthit:MenuElement({id = "wlasthitmana", name = "[W] Mana", value = 20, min = 5, max = 100, step = 5, leftIcon = WIcon})

    -- laneclear
    self.Menu:MenuElement({id = "laneclear", name = "LaneClear", type = MENU})
    self.Menu.laneclear:MenuElement({id = "qlaneclear", name = "Use [Q2] in LaneClear (BETA)", value = true, leftIcon = QIcon})
    self.Menu.laneclear:MenuElement({id = "qlaneclearcount", name = "[Q2] HitCount", value = 3, min = 1, max = 7, step = 1, leftIcon = QIcon})
    self.Menu.laneclear:MenuElement({id = "qlaneclearmana", name = "[Q2] Mana", value = 40, min = 5, max = 100, step = 5, leftIcon = QIcon})

    -- auto
    self.Menu:MenuElement({id = "auto", name = "Auto", type = MENU})
    self.Menu.auto:MenuElement({id = "wauto", name = "[W] KS", value = true, leftIcon = WIcon})
    self.Menu.auto:MenuElement({id = "eauto", name = "[E] Dash/Runedown Interrupt (BETA)", value = true, leftIcon = EIcon})
    self.Menu.auto:MenuElement({id = "rauto", name = "[R] KS", value = true, leftIcon = RIcon})
    self.Menu.auto:MenuElement({id = "rautorange", name = "[R] KS Range", value = 3000, min = 500, max = 20000, step = 500, leftIcon = RIcon})

    -- draws
    self.Menu:MenuElement({id = "draws", name = "Draws", type = MENU})
    self.Menu.draws:MenuElement({id = "rangetoggle", name = "Print [Q] state on Hero", value = true, leftIcon = QIcon})
    self.Menu.draws:MenuElement({id = "qdraw", name = "Draw [AA] Range", value = false, leftIcon = QIcon})
    self.Menu.draws:MenuElement({id = "wdraw", name = "Draw [W] Range", value = false, leftIcon = WIcon})
    self.Menu.draws:MenuElement({id = "edraw", name = "Draw [E] Range", value = false, leftIcon = EIcon})

    -- range helper
    self.Menu:MenuElement({id = "movehelper", name = "RangeHelper", value = false})
end

function Jinx:Draws()
    if self.Menu.draws.rangetoggle:Value() and myHero:GetSpellData(_Q).level > 0 then
        if BuffActive(myHero, powpow) then
            DrawTextOnHero(myHero, "POW-POW", Draw.Color(255, 229, 73, 156))
        elseif BuffActive(myHero, fishbones) then
            DrawTextOnHero(myHero, "FISHBONES", Draw.Color(255, 114, 139, 240))
        end
    end
    if self.Menu.draws.qdraw:Value() then
        Draw.Circle(myHero, AARange, 2, Draw.Color(255, 255, 0, 0))
    end
    if self.Menu.draws.wdraw:Value() then
        Draw.Circle(myHero, WRange, 2, Draw.Color(255, 0, 255, 0))
    end
    if self.Menu.draws.edraw:Value() then
        Draw.Circle(myHero, ERange, 2, Draw.Color(255, 255, 255, 0))
    end
end

function Jinx:Spells()
    WSpell = {speed = 3300, delay = 0.6, range = WRange, radius = 50, collision = {"minion"}, type = "linear"}
    ESpell = {speed = math.huge, delay = 0.9, range = ERange, radius = 50, collision = {}, type = "circular"}
    RSpell = {speed = 1950, delay = 0.6, range = RRange, radius = 50, collision = {}, type = "linear"}

    W = GGPrediction:SpellPrediction({Type = GGPrediction.SPELLTYPE_LINE, Speed = 3300, Delay = 0.6, Radius = 60, Range = 1450, Collision = true, MaxCollision = 0, CollisionTypes = {GGPrediction.COLLISION_MINION}})
    E = GGPrediction:SpellPrediction({Type = GGPrediction.SPELLTYPE_CIRCLE, Speed = math.huge, Delay = 0.9, Radius = 60, Range = 900, Collision = false})
    R = GGPrediction:SpellPrediction({Type = GGPrediction.SPELLTYPE_LINE, Speed = 1950, Delay = 0.6, Radius = 60, Range = 20000, Collision = true, MaxCollision = 0, CollisionTypes = {GGPrediction.COLLISION_ENEMYHERO}})
end

function Jinx:Tick()
    if _G.JustEvade and _G.JustEvade:Evading() or (_G.ExtLibEvade and _G.ExtLibEvade.Evading) or Game.IsChatOpen() or myHero.dead then return end
    target = GetTarget(AARange)
    if ValidTarget(target) then
        GaleMouseSpot = self:MoveHelper(target)
    else
        _G.SDK.Orbwalker.ForceMovement = nil
    end
    self:GetQRange()
    self:GetAARange()
    CastingQ = myHero.activeSpell.name == "JinxQ"
    CastingW = myHero.activeSpell.name == "JinxW"
    CastingE = myHero.activeSpell.name == "JinxE"
    CastingR = myHero.activeSpell.name == "JinxR"
    if EnemyLoaded == false then
        local CountEnemy = 0
        for i, enemy in pairs(EnemyHeroes) do
            CountEnemy = CountEnemy + 1
        end
        if CountEnemy < 1 then
            GetEnemyHeroes()
        else
            EnemyLoaded = true
            PrintChat("Enemy Loaded")
        end
    end
    self:Logic()
    self:Auto()
    self:Minions()
end

function Jinx:CastingChecks()
    if not CastingQ and not CastingW and not CastingE and not CastingR then
        return true
    else 
        return false
    end
end

function Jinx:SmoothChecks()
    if self:CastingChecks() and not _G.SDK.Attack:IsActive() and _G.SDK.Cursor.Step == 0 and _G.SDK.Spell:CanTakeAction({q = 0, w = 0.73, e = 0.33, r = 0.73}) then
        return true
    else 
        return false
    end
end


function Jinx:CanUse(spell, mode)
    if mode == nil then
        mode = Mode()
    end

    if spell == _Q then
        if mode == "Combo" and IsReady(_Q) and self.Menu.combo.qcombo:Value() then
            return true
        end
        if mode == "LastHit" and IsReady(_Q) and self.Menu.lasthit.qlasthit:Value() and myHero.mana / myHero.maxMana >= self.Menu.lasthit.qlasthitmana:Value() / 100 then
            return true
        end
        if mode == "LaneClear" and IsReady(_Q) and self.Menu.laneclear.qlaneclear:Value() and myHero.mana / myHero.maxMana >= self.Menu.laneclear.qlaneclearmana:Value() / 100 then
            return true
        end
    end
    if spell == _W then
        if mode == "Combo" and IsReady(_W) and self.Menu.combo.wcombo:Value() then
            return true
        end
        if mode == "LastHit" and IsReady(_W) and self.Menu.lasthit.wlasthit:Value() and myHero.mana / myHero.maxMana >= self.Menu.lasthit.wlasthitmana:Value() / 100 then
            return true
        end
        if mode == "Auto" and IsReady(_W) and self.Menu.auto.wauto:Value() then
            return true
        end
    end
    if spell == _E then
        if mode == "Combo" and IsReady(_E) and self.Menu.combo.ecombo:Value() then
            return true
        end
        if mode == "Auto" and IsReady(_E) and self.Menu.auto.eauto:Value() then
            return true
        end
    end
    if spell == _R then
        if mode == "Combo" and IsReady(_R) and self.Menu.combo.rcombo:Value() then
            return true
        end
        if mode == "Auto" and IsReady(_R) and self.Menu.auto.rauto:Value() then
            return true
        end
    end
end

function Jinx:Logic()
    if Mode() == "Combo" then
        self:QCombo()
        self:WCombo()
        self:ECombo()
    end
end

function Jinx:Auto()
    for i, enemy in pairs(EnemyHeroes) do 
        if Mode() == "Combo" then
            self:RCombo(enemy)
        end
        self:WKS(enemy)
        self:EInterrupt(enemy)
        self:RKS(enemy)
        self:SemiR(enemy)
    end
end

function Jinx:Minions()
    local minions = _G.SDK.ObjectManager:GetEnemyMinions(WRange)
    for i = 1, #minions do
        local minion = minions[i]
        if Mode() == "LastHit" then
            self:WLastHit(minion)
        end
        if Mode() == "LaneClear" then
            self:QLaneClear(minion)
        end
    end
end

-- functions -- 

function Jinx:QCombo()
    local qtarget = GetTarget(QCheckRange)
    if qtarget == nil then return end
    if ValidTarget(qtarget, QCheckRange) and self:CanUse(_Q, "Combo") and self:SmoothChecks() and GetDistance(myHero.pos, qtarget.pos) > BaseAARange and BuffActive(myHero, powpow) then
        Control.CastSpell(HK_Q)
    end
    if ValidTarget(qtarget, BaseAARange) and self:CanUse(_Q, "Combo") and self:SmoothChecks() and BuffActive(myHero, fishbones) then
        Control.CastSpell(HK_Q)
    end
end

function Jinx:WCombo()
    local wtarget = GetTarget(WRange)
    if wtarget == nil then return end
    if ValidTarget(wtarget, WRange) and self:CanUse(_W, "Combo") and self:SmoothChecks() then
        if self.Menu.combo.wcomboaa:Value() then
            if GetDistance(myHero.pos, wtarget.pos) > AARange then
                GGCast(HK_W, wtarget, W, self.Menu.combo.wcombohc:Value()+1)
            end
        else
            GGCast(HK_W, wtarget, W, self.Menu.combo.wcombohc:Value()+1)
        end
    end
end

function Jinx:ECombo()
    local etarget = GetTarget(ERange)
    if etarget == nil then return end
    if ValidTarget(etarget, ERange) and self:CanUse(_E, "Combo") and self:SmoothChecks() then
        GGCast(HK_E, etarget, E, self.Menu.combo.ecombohc:Value()+1)
    end
end

function Jinx:RCombo(enemy)
    if ValidTarget(enemy, self.Menu.combo.rcomborange:Value()) and self:CanUse(_R, "Combo") and GetEnemyCount(400, enemy) >= self.Menu.combo.rcombocount:Value() and self:SmoothChecks() then
        if self.Menu.combo.rcomboaa:Value() then
            if enemy.pos:ToScreen().onScreen then
                GGCast(HK_R, enemy, R)
            else
                R:GetPrediction(enemy, myHero)
                if R:CanHit(HITCHANCE_HIGH) and GetDisntance(R.CastPosition, myHero.pos) <= R.Range then
                    local Direction = Vector((myHero.pos-R.CastPosition):Normalized())
                    local CastSpot = myHero.pos - Direction * 800
                    GGCast(HK_R, CastSpot)
                end
            end
        else
            if enemy.pos:ToScreen().onScreen then
                GGCast(HK_R, enemy, R)
            else
                R:GetPrediction(enemy, myHero)
                if R:CanHit(HITCHANCE_HIGH) and GetDistance(R.CastPosition, myHero.pos) <= R.Range then
                    local Direction = Vector((myHero.pos-R.CastPosition):Normalized())
                    local CastSpot = myHero.pos - Direction * 800
                    GGCast(HK_R, CastSpot)
                end
            end
        end
    end
end

function Jinx:WKS(enemy)
    if ValidTarget(enemy, WRange) and self:CanUse(_W, "Auto") and self:SmoothChecks() then
        local WDam = getdmg("W", enemy, myHero)
        if enemy.health < WDam then
            GGCast(HK_W, enemy, W)
        end
    end
end

function Jinx:EInterrupt(enemy)
    if ValidTarget(enemy, ERange) and self:CanUse(_E, "Auto") and self:SmoothChecks() then
        if GetDistance(myHero.pos, enemy.pos) <= 200 and enemy.activeSpell.valid and enemy.activeSpell.spellWasCast and enemy.activeSpell.target == myHero.handle then
            GGCast(HK_E, enemy, E)
        elseif enemy.pathing.isDashing then
            if GetDistance(myHero.pos, enemy.pathing.endPos) < GetDistance(myHero.pos, enemy.pos) then
                GGCast(HK_E, enemy, E)
            end
        end
    end
end

function Jinx:RKS(enemy)
    if ValidTarget(enemy, self.Menu.auto.rautorange:Value()) and self:CanUse(_R, "Auto") and self:SmoothChecks() and self:EnemiesAround(enemy) == 0 then
        local RDam = CalcRDmg(enemy)
        if enemy.health < RDam then
            if enemy.pos:ToScreen().onScreen then
                GGCast(HK_R, enemy, R)
            else
                R:GetPrediction(enemy, myHero)
                if R:CanHit(HITCHANCE_HIGH) and GetDistance(R.CastPosition, myHero.pos) <= R.Range then
                    local Direction = Vector((myHero.pos-R.CastPosition):Normalized())
                    local CastSpot = myHero.pos - Direction * 800
                    GGCast(HK_R, CastSpot)
                end
            end
        end
    end
end

function Jinx:SemiR(enemy)
    if ValidTarget(enemy, RRange) and self.Menu.combo.rsemi:Value() and GetDistance(enemy.pos, mousePos) <= 400 and self:SmoothChecks() then
        if enemy.pos:ToScreen().onScreen then
            GGCast(HK_R, enemy, R)
        else
            R:GetPrediction(enemy, myHero)
            if R:CanHit(HITCHANCE_HIGH) and GetDistance(R.CastPosition, myHero.pos) <= R.Range then
                local Direction = Vector((myHero.pos-R.CastPosition):Normalized())
                local CastSpot = myHero.pos - Direction * 800
                GGCast(HK_R, CastSpot)
            end
        end
    end
end


function Jinx:WLastHit(minion)
    if ValidTarget(minion, WRange) and self:CanUse(_W, "LastHit") and self:SmoothChecks() and (minion.charName == "SRU_ChaosMinionSiege" or minion.charName == "SRU_OrderMinionSiege") and GetDistance(myHero.pos, minion.pos) >= QCheckRange then
        local WDam = getdmg("W", minion, myHero, myHero:GetSpellData(_Q).level)
        if minion.health <= WDam then
            local minions2 = _G.SDK.ObjectManager:GetEnemyMinions(WRange)
            for i = 1, #minions2 do 
                local minion2 = minions2[i]
                local Line = ClosestPointOnLineSegment(minion2.pos, myHero.pos, minion.pos)
                if GetDistance(minion2.pos, Line) <= 120 then
                    return
                else
                    Control.CastSpell(HK_W, minion)
                end
            end
        end
    end
end

function Jinx:QLaneClear(minion)
    if ValidTarget(minion, QCheckRange) and self:CanUse(_Q, "LaneClear") and self:SmoothChecks() and BuffActive(myHero, powpow) then
        local minions2 = _G.SDK.ObjectManager:GetEnemyMinions(QCheckRange)
        local count = 0
        for i = 1, #minions2 do
            local minion2 = minions2[i]
            if GetDistance(minion.pos, minion2.pos) <= 250 then
                count = count + 1
            end
        end
        QLaneClearCount = count
        if QLaneClearCount >= self.Menu.laneclear.qlaneclearcount:Value() then
            Control.CastSpell(HK_Q)
        else
            if BuffActive(myHero, fishbones) and IsReady(_Q) then
                Control.CastSpell(HK_Q)
            end
        end
    end
    if myHero.mana / myHero.maxMana <= self.Menu.laneclear.qlaneclearmana:Value() and BuffActive(myHero, fishbones) and IsReady(_Q) then
        Control.CastSpell(HK_Q)
    end
end


function Jinx:EnemiesAround(enemy)
    local count = 0
    if GetDistance(myHero.pos, enemy.pos) <= 700 then
        count = count + 1
    end
    return count
end


function Jinx:GetQRange()
    if myHero:GetSpellData(_Q).level > 0 and IsReady(_Q) then
        QRange = 75 + 25 * myHero:GetSpellData(_Q).level
        QCheckRange = BaseAARange + QRange
    end
end

function Jinx:GetAARange()
    if BuffActive(myHero, fishbones) then
        AARange = BaseAARange + QRange
    else
        AARange = BaseAARange
    end
end

function Jinx:MoveHelper(unit)
    local EAARangel = _G.SDK.Data:GetAutoAttackRange(unit)
    local MoveSpot = nil
    local RangeDif = AARange - EAARangel
    local ExtraRangeDist = RangeDif
    local ExtraRangeChaseDist = RangeDif - 100

    local ScanDirection = Vector((myHero.pos-mousePos):Normalized())
    local ScanDistance = GetDistance(myHero.pos, unit.pos) * 0.8
    local ScanSpot = myHero.pos - ScanDirection * ScanDistance
    

    local MouseDirection = Vector((unit.pos-ScanSpot):Normalized())
    local MouseSpotDistance = EAARangel + ExtraRangeDist
    if not IsFacing(unit) then
        MouseSpotDistance = EAARangel + ExtraRangeChaseDist
    end
    if MouseSpotDistance > BaseAARange then
        MouseSpotDistance = BaseAARange
    end

    local MouseSpot = unit.pos - MouseDirection * (MouseSpotDistance)
    local MouseDistance = GetDistance(unit.pos, mousePos)
    local GaleMouseSpotDirection = Vector((myHero.pos-MouseSpot):Normalized())
    local GalemouseSpotDistance = GetDistance(myHero.pos, MouseSpot)
    if GalemouseSpotDistance > 300 then
        GalemouseSpotDistance = 300
    end
    local GaleMouseSpoty = myHero.pos - GaleMouseSpotDirection * GalemouseSpotDistance
    MoveSpot = MouseSpot

    if MoveSpot then
        if GetDistance(myHero.pos, MoveSpot) < 50 or IsUnderEnemyTurret(MoveSpot) then
            _G.SDK.Orbwalker.ForceMovement = nil
        elseif self.Menu.movehelper:Value() and GetDistance(myHero.pos, unit.pos) <= AARange-50 and (Mode() == "Combo" or Mode() == "Harass") and self:CastingChecks() and MouseDistance < 750 then
            _G.SDK.Orbwalker.ForceMovement = MoveSpot
        else
            _G.SDK.Orbwalker.ForceMovement = nil
        end
    end
    return GaleMouseSpoty
end

class "Senna"

local EnemyLoaded = false
local AllyLoaded = false
local lastSpell = GetTickCount()

local SIcon = "https://www.proguides.com/public/media/rlocal/champion/thumbnail/235.png"
local QIcon = "https://www.proguides.com/public/media/rlocal/champion/ability/thumbnail/SennaQ.png"
local WIcon = "https://www.proguides.com/public/media/rlocal/champion/ability/thumbnail/SennaW.png"
local EIcon = "https://www.proguides.com/public/media/rlocal/champion/ability/thumbnail/SennaE.png"
local RIcon = "https://www.proguides.com/public/media/rlocal/champion/ability/thumbnail/SennaR.png"

function Senna:Menu()
    self.Menu = MenuElement({type = MENU, id = "senna", name = "dnsSenna", leftIcon = SIcon})

    self.Menu:MenuElement({id = "combo", name = "Combo", type = MENU})
    self.Menu.combo:MenuElement({id = "qcombo", name = "Use [Q] in Combo", value = true, leftIcon = QIcon})
    self.Menu.combo:MenuElement({id = "qextended", name = "Use [Q] Extended", value = true, leftIcon = QIcon})
    self.Menu.combo:MenuElement({id = "qextendedmana", name = "[Q] Extended Mana", value = 40, min = 5, max = 95, step = 5, identifier = "%", leftIcon = QIcon})
    self.Menu.combo:MenuElement({id = "wcombo", name = "Use [W] in Combo", value = true, leftIcon = WIcon})
    self.Menu.combo:MenuElement({id = "ecombo", name = "Use [E] to cancle Attacks", value = true, leftIcon = EIcon})
    self.Menu.combo:MenuElement({id = "ecombohp", name = "[E] HP", value = 40, min = 5, max = 95, step = 5, identifier = "%", leftIcon = EIcon})
    self.Menu.combo:MenuElement({id = "rsemi", name = "[R] Semi", value = false, key = string.byte("T"), toggle = false, leftIcon = RIcon})

    self.Menu:MenuElement({id = "auto", name = "Auto", type = MENU})
    self.Menu.auto:MenuElement({id = "qheal", name = "Auto [Q] low allys", value = true, leftIcon = QIcon})
    self.Menu.auto:MenuElement({id = "qhealhp", name = "[Q] HP <", value = 60, min = 5, max = 95, step = 5, identifier = "%", leftIcon = QIcon})
    self.Menu.auto:MenuElement({id = "qhealallies", name = "[Q] Allies", type = MENU, leftIcon = QIcon})
    self.Menu.auto:MenuElement({id = "qks", name = "Use [Q] to KS", value = true, leftIcon = QIcon})
    self.Menu.auto:MenuElement({id = "qks2", name = "Use [Q] + [Ward] to KS", value = true, leftIcon = QIcon})
    self.Menu.auto:MenuElement({id = "wimmo", name = "Use [W] on immobile Targets", value = true, leftIcon = WIcon})
    self.Menu.auto:MenuElement({id = "rsave", name = "Use [R] to shield allys", value = true, leftIcon = RIcon})
    self.Menu.auto:MenuElement({id = "rsavehp", name = "[R] HP <", value = 40, min = 5, max = 95, step = 5, identifier = "%", leftIcon = RIcon})
    self.Menu.auto:MenuElement({id = "rsaveallies", name = "[R] Allies", type = MENU, leftIcon = RIcon})
    self.Menu.auto:MenuElement({id = "rks", name = "Use [R] to KS", value = true, leftIcon = RIcon})

    self.Menu:MenuElement({id = "laneclear", name = "LaneClear", type = MENU})
    self.Menu.laneclear:MenuElement({id = "qlaneclear", name = "Use [Q] in LaneClear", value = true, leftIcon = QIcon})
    self.Menu.laneclear:MenuElement({id = "qlaneclearcount", name = "[Q] HitCount >=", value = 3, min = 1, max = 9, step = 1, leftIcon = QIcon})
    self.Menu.laneclear:MenuElement({id = "qlaneclearmana", name = "[Q] Mana >=", value = 40, min = 5, max = 95, step = 5, identifier = "%", leftIcon = QIcon})

    self.Menu:MenuElement({id = "misc", name = "Misc", type = MENU})
    self.Menu.misc:MenuElement({id = "movementhelper", name = "RangeHelper", value = true})

    self.Menu:MenuElement({id = "draws", name = "Draws", type = MENU})
    self.Menu.draws:MenuElement({id = "qdraw", name = "Draw [Q] Range", value = false, leftIcon = QIcon})
    self.Menu.draws:MenuElement({id = "wdraw", name = "Draw [W] Range", value = false, leftIcon = WIcon})

end

function Senna:ActiveMenu()
    for i, ally in pairs(AllyHeroes) do
        self.Menu.auto.qhealallies:MenuElement({id = ally.charName, name = ally.charName, value = true})
        self.Menu.auto.rsaveallies:MenuElement({id = ally.charName, name = ally.charName, value = true})
    end
end

function Senna:Spells()
    Q = {range =  myHero.range + myHero.boundingRadius, radius = 100}
    Q2 = {range = 1300, radius = 75, delay = 0.33, speed = math.huge, collision = {}, type = "linear"}
    W = {range = 1200, radius = 50, delay = 0.25, speed = 1200, collision = {"minion"}, type = "linear"}
    R = {range = 20000, radius = 30, delay = 1, speed = 20000, collision = {}, type = "circular"}
end

function Senna:Draws()
    if self.Menu.draws.qdraw:Value() then
        Draw.Circle(myHero, Q.range, 2, Draw.Color(255, 255, 255, 0))
    end
    if self.Menu.draws.wdraw:Value() then
        Draw.Circle(myHero, W.range, 2, Draw.Color(255, 0, 255, 0))
    end
end

function Senna:Tick()
    if _G.JustEvade and _G.JustEvade:Evading() or (_G.ExtLibEvade and _G.ExtLibEvade.Evading) or Game.IsChatOpen() or myHero.dead then return end
    target = GetTarget(myHero.range + myHero.boundingRadius)

    if target and ValidTarget(target) then
        GaleMouseSpot = self:MoveHelper(target)
    else
        _G.SDK.Orbwalker.ForceMovement = nil
    end

    Q.range = myHero.range + myHero.boundingRadius + myHero.boundingRadius
    CastingQ = myHero.activeSpell.name == "SennaQ"
    CastingW = myHero.activeSpell.name == "SennaW"
    CastingE = myHero.activeSpell.name == "SennaE"
    CastingR = myHero.activeSpell.name == "SennaR"
    if EnemyLoaded == false then
        local CountEnemy = 0
        for i, enemy in pairs(EnemyHeroes) do
            CountEnemy = CountEnemy + 1
        end
        if CountEnemy < 1 then
            GetEnemyHeroes()
        else
            EnemyLoaded = true
            PrintChat("Enemy Loaded")
        end
    end
    if AllyLoaded == false then
        local CountAlly = 0
        for i, ally in pairs(AllyHeroes) do
            CountAlly = CountAlly + 1
        end
        if CountAlly < 1 then
            GetAllyHeroes()
        else
            AllyLoaded = true
            PrintChat("Ally Loaded")
            self:ActiveMenu()
        end
    end
    self:Auto()
    self:Logic()
    self:Minions()
end

function Senna:CastingChecks()
    if not CastingQ and not CastingW and not CastingE and not CastingR and _G.SDK.Spell:CanTakeAction({q = 0.55, w = 0.4, e = 1.15, r = 1.15}) and _G.SDK.Cursor.Step == 0 and not _G.SDK.Orbwalker:IsAutoAttacking() then
        return true
    else
        return false
    end
end

function Senna:CanUse(spell, mode)
    if mode == nil then
        mode = Mode()
    end

    if spell == _Q then
        if mode == "Combo" and IsReady(_Q) and self.Menu.combo.qcombo:Value() then
            return true
        end
        if mode == "Extended" and IsReady(_Q) and self.Menu.combo.qextended:Value() and myHero.mana / myHero.maxMana >= self.Menu.combo.qextendedmana:Value() / 100 then
            return true
        end
        if mode == "Heal" and IsReady(_Q) and self.Menu.auto.qheal:Value() then
            return true
        end
        if mode == "KS" and IsReady(_Q) and self.Menu.auto.qks:Value() then
            return true
        end
        if mode == "Ward" and IsReady(_Q) and self.Menu.auto.qks2:Value() then
            return true
        end
        if mode == "LaneClear" and IsReady(spell) and self.Menu.laneclear.qlaneclear:Value() and myHero.mana / myHero.maxMana >= self.Menu.laneclear.qlaneclearmana:Value() / 100 then
            return true
        end
    end
    if spell == _W then
        if mode == "Combo" and IsReady(_W) and self.Menu.combo.wcombo:Value() then
            return true
        end
        if mode == "Immo" and IsReady(_W) and self.Menu.auto.wimmo:Value() then
            return true
        end
    end
    if spell == _E then
        if mode == "Combo" and IsReady(_E) and self.Menu.combo.ecombo:Value() then
            return true
        end
    end
    if spell == _R then
        if mode == "Save" and IsReady(_R) and self.Menu.auto.rsave:Value() then
            return true
        end
        if mode == "KS" and IsReady(_R) and self.Menu.auto.rks:Value() then
            return true
        end
        if mode == "Semi" and IsReady(spell) and self.Menu.combo.rsemi:Value() then
            return true
        end
    end
    return false
end

function Senna:Auto()
    for i, enemy in pairs(EnemyHeroes) do
        self:QKS(enemy)
        self:QKS1(enemy)
        self:QKS2(enemy)
        self:WImmo(enemy)
        self:RKS(enemy)
        self:RSemi(enemy)
        if Mode() == "Combo" then
            self:ECombo(enemy)
        end
        for j, ally in pairs(AllyHeroes) do
            self:AutoHeal(enemy, ally)
            self:RSave(enemy, ally)
        end
    end
end

function Senna:Logic()
    if Mode() == "Combo" then
        self:QCombo()
        self:QExtended()
        self:WCombo()
    end
end

function Senna:Minions()
    local minions = _G.SDK.ObjectManager:GetEnemyMinions(1400)
    for i = 1, #minions do
        local minion = minions[i]
        if Mode() == "LaneClear" then
            self:QLaneClear(minion)
        end
    end
end

-- functions -- 

function Senna:QCombo()
    local qtarget = GetTarget(Q.range)
    if ValidTarget(qtarget) and self:CanUse(_Q, "Combo") and self:CastingChecks() then
        _G.Control.CastSpell(HK_Q, qtarget.pos)
    end
end

function Senna:WCombo()
    local wtarget = GetTarget(W.range)
    if ValidTarget(wtarget) and self:CanUse(_W, "Combo") and self:CastingChecks() then
        dnsCast(HK_W, wtarget, W, 0.07)
    end
end

function Senna:ECombo(enemy)
    if ValidTarget(enemy) and self:CanUse(_E, "Combo") and self:CastingChecks() and enemy.activeSpell.valid and not enemy.activeSpell.isStopped and myHero.health / myHero. maxHealth <= self.Menu.combo.ecombohp:Value() / 100 then
        if enemy.activeSpell.target == myHero.handle then
            dnsCast(HK_E)
        end
    end
end

function Senna:QExtended()
    local qtarget = GetTarget(Q2.range)
    if ValidTarget(qtarget) and self:CanUse(_Q, "Extended") and self:CastingChecks() then
        local pred = _G.PremiumPrediction:GetPrediction(myHero, qtarget, Q2)
        local minions = _G.SDK.ObjectManager:GetMinions(Q.range)
        for i = 1, #minions do
            local minion = minions[i]
            if ValidTarget(minion) then
                local targetPos = myHero.pos:Extended(pred.CastPos, Q2.range)
                local minionPos = myHero.pos:Extended(minion.pos, Q2.range)
                if GetDistance(targetPos, minionPos) <= Q2.radius then
                    dnsCast(HK_Q, minion.pos)
                end
            end
        end
    end
end

function Senna:AutoHeal(enemy, ally)
    if ValidTarget(ally, Q.range) and self:CanUse(_Q, "Heal") and self:CastingChecks() and ally.health / ally.maxHealth <= self.Menu.auto.qhealhp:Value() / 100 and ValidTarget(enemy) and GetDistance(enemy.pos, ally.pos) <= 1000 and self.Menu.auto.qhealallies[ally.charName]:Value() then
        dnsCast(HK_Q, ally.pos)
    end
end

function Senna:QKS(enemy)
    if ValidTarget(enemy, Q.range) and self:CanUse(_Q, "KS") and self:CastingChecks() then
        local qdam = getdmg("Q", enemy, myHero, myHero:GetSpellData(_Q).level)
        if qdam >= enemy.health then
            dnsCast(HK_Q, enemy.pos)
        end
    end
end

function Senna:QKS1(enemy)
    if ValidTarget(enemy, Q2.range) and GetDistance(myHero.pos, enemy.pos) > Q.range and self:CanUse(_Q, "KS") and self:CastingChecks() then
        local qdam = getdmg("Q", enemy, myHero, myHero:GetSpellData(_Q).level)
        if qdam > enemy.health then
            local pred = _G.PremiumPrediction:GetPrediction(myHero, enemy, Q2)
            if pred.CastPos and pred.HitChance > 0 then
                local minions = _G.SDK.ObjectManager:GetMinions(Q.range)
                for i = 1, #minions do
                    local minion = minions[i]
                    if ValidTarget(minion) then
                        local targetPos = myHero.pos:Extended(pred.CastPos, Q2.range)
                        local minionPos = myHero.pos:Extended(minion.pos, Q2.range)
                        if GetDistance(targetPos, minionPos) <= Q2.radius then
                            _G.Control.CastSpell(HK_Q, minion.pos)
                        end
                    end
                end
                local heroes = _G.SDK.ObjectManager:GetHeroes(Q.range)
                for j = 1, #heroes do
                    local hero = heroes[i]
                    if ValidTarget(hero) then
                        local targetPos = myHero.pos:Extended(pred.CastPos, Q2.range)
                        local heroPos = myHero.pos:Extended(hero.pos, Q2.range)
                        if GetDistance(targetPos, heroPos) <= Q2.radius then
                            _G.Control.CastSpell(HK_Q, hero.pos)
                        end
                    end
                end
            end
        end
    end
end

function Senna:GetWardStone()
    if GetItemSlot(myHero, 3863) > 0 then
        return GetItemSlot(myHero, 3863)
    elseif GetItemSlot(myHero, 3864) > 0 then
        return GetItemSlot(myHero, 3864)
    elseif GetItemSlot(myHero, 3855) > 0 then
        return GetItemSlot(myHero, 3855)
    elseif GetItemSlot(myHero, 3856) > 0 then
        return GetItemSlot(myHero, 3856)
    else
        return 0
    end
end

function Senna:QKS2(enemy)
    local YellowTrinket = GetItemSlot(myHero, 3340)
    local WardStone = self:GetWardStone()
    local PinkWard = GetItemSlot(myHero, 2055)
    local WardStoneAmmo = myHero:GetItemData(WardStone).ammo
    if ValidTarget(enemy, Q2.range) and GetDistance(myHero.pos, enemy.pos) > Q.range and self:CanUse(_Q, "Ward") and self:CastingChecks() then
        --PrintChat(myHero:GetItemData(YellowTrinket).stacks)
        local qdam = getdmg("Q", enemy, myHero, myHero:GetSpellData(_Q).level)
        if qdam >= enemy.health then
            local pred = _G.PremiumPrediction:GetPrediction(myHero, enemy, Q2)
            if pred.CastPos and pred.HitChance > 0 then
                local wardPos = myHero.pos:Extended(pred.CastPos, 500)
                if WardStone > 0 and WardStoneAmmo > 0 then
                    Control.CastSpell(ItemHotKey[WardStone], wardPos)
                    DelayAction(function() Control.CastSpell(HK_Q, wardPos) end, 0.15)
                elseif YellowTrinket > 0 and myHero:GetSpellData(YellowTrinket).currentCd == 0 then
                    Control.CastSpell(ItemHotKey[YellowTrinket], wardPos)
                    DelayAction(function() Control.CastSpell(HK_Q, wardPos) end, 0.15)
                elseif PinkWard > 0 then
                    Control.CastSpell(ItemHotKey[PinkWard], wardPos)
                    DelayAction(function() Control.CastSpell(HK_Q, wardPos) end, 0.15)
                end
            end
        end
    end
end

function Senna:WImmo(enemy)
    if ValidTarget(enemy, W.range) and self:CanUse(_W, "Immo") and self:CastingChecks() then 
        if IsImmobile(enemy) >= 0.5 then
            dnsCast(HK_W, enemy, W, 1)
        elseif enemy.pathing and enemy.pathing.isDashing then
            if GetDistance(enemy.pos, myHero.pos) > GetDistance(enemy.pathing.endPos, myHero.pos) then
                dnsCast(HK_W, enemy, W, 1)
            end
        end
    end
end

function Senna:RSave(enemy, ally)
    if ValidTarget(ally, R.range) and self:CanUse(_R, "Save") and self:CastingChecks() and enemy.activeSpell.valid and not enemy.activeSpell.isStopped and ally.health / ally.maxHealth <= self.Menu.auto.rsavehp:Value() / 100 and self.Menu.auto.rsaveallies[ally.charName]:Value() then 
        if enemy.activeSpell.target == ally.handle then
            dnsCast(HK_R, ally, R, 0.05)
        else
            local placementPos = enemy.activeSpell.placementPos
            local startPos = enemy.activeSpell.startPos
            local width = ally.boundingRadius + 50
            if enemy.activeSpell.width > 0 then width = width + enemy.activeSpell.width end
            local spellLine = ClosestPointOnLineSegment(ally.pos, startPos, placementPos)
            if GetDistance(ally.pos, spellLine) <= width then
                dnsCast(HK_R, ally, R, 0.05)
            end
        end
    end
end

function Senna:RKS(enemy)
    if ValidTarget(enemy, R.range) and self:CanUse(_R, "KS") and self:CastingChecks() then
        local rdam = getdmg("R", enemy, myHero, myHero:GetSpellData(_R).level)
        if rdam >= enemy.health then
            dnsCast(HK_R, enemy, R, 0.07)
        end
    end
end

function Senna:RSemi(enemy)
    if ValidTarget(enemy, R.range) and self:CanUse(_R, "Semi") and self:CastingChecks() then
        if enemy.pos:DistanceTo(mousePos) <= 400 then
            dnsCast(HK_R, enemy, R, 0.05)
        end
    end
end

function Senna:QLaneClear(minion)
    if ValidTarget(minion, Q.range) and self:CanUse(_Q, "LaneClear") and self:CastingChecks() then
        local minionPos = myHero.pos:Extended(minion.pos, 1300)
        if GetMinionCountLinear(1400, Q2.radius, minionPos) >= self.Menu.laneclear.qlaneclearcount:Value() then
            dnsCast(HK_Q, minion.pos)
        end
    end
end

function Senna:MoveHelper(unit)
    local EAARangel = unit.range + unit.boundingRadius
    local AARange = myHero.range + myHero.boundingRadius
    local MoveSpot = nil
    local RangeDif = AARange - EAARangel
    local ExtraRangeDist = RangeDif
    local ExtraRangeChaseDist = RangeDif - 100

    local ScanDirection = Vector((myHero.pos-mousePos):Normalized())
    local ScanDistance = GetDistance(myHero.pos, unit.pos) * 0.8
    local ScanSpot = myHero.pos - ScanDirection * ScanDistance
    

    local MouseDirection = Vector((unit.pos-ScanSpot):Normalized())
    local MouseSpotDistance = EAARangel + ExtraRangeDist
    if not IsFacing(unit) then
        MouseSpotDistance = EAARangel + ExtraRangeChaseDist
    end
    if MouseSpotDistance > AARange then
        MouseSpotDistance = AARange
    end

    local MouseSpot = unit.pos - MouseDirection * (MouseSpotDistance)
    local MouseDistance = GetDistance(unit.pos, mousePos)
    local GaleMouseSpotDirection = Vector((myHero.pos-MouseSpot):Normalized())
    local GalemouseSpotDistance = GetDistance(myHero.pos, MouseSpot)
    if GalemouseSpotDistance > 300 then
        GalemouseSpotDistance = 300
    end
    local GaleMouseSpoty = myHero.pos - GaleMouseSpotDirection * GalemouseSpotDistance
    MoveSpot = MouseSpot

    if MoveSpot then
        if GetDistance(myHero.pos, MoveSpot) < 50 or IsUnderEnemyTurret(MoveSpot) then
            _G.SDK.Orbwalker.ForceMovement = nil
        elseif self.Menu.misc.movementhelper:Value() and GetDistance(myHero.pos, unit.pos) <= AARange-50 and (Mode() == "Combo" or Mode() == "Harass") and self:CastingChecks() and MouseDistance < 750 then
            _G.SDK.Orbwalker.ForceMovement = MoveSpot
        else
            _G.SDK.Orbwalker.ForceMovement = nil
        end
    end
    return GaleMouseSpoty
end

function OnLoad()
    Manager()
end

























