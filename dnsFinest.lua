require "DamageLib"
require "2DGeometry"
require "MapPositionGOS"
require "PremiumPrediction"


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

local ItemHotKey = {[ITEM_1] = HK_ITEM_1, [ITEM_2] = HK_ITEM_2,[ITEM_3] = HK_ITEM_3, [ITEM_4] = HK_ITEM_4, [ITEM_5] = HK_ITEM_5, [ITEM_6] = HK_ITEM_6,}

local InterruptSpells = {
    ["Caitlyn"] = {"CaitlynAceintheHole"},
    ["FiddleSticks"] = {"Crowstorm"},
    ["FiddleSticks"] = {"DrainChannel"},
    ["Galio"] = {"GalioIdolOfDurand"},
    ["Janna"] = {"ReapTheWhirlwind"},
    ["Karthus"] = {"KarthusFallenOne"},
    ["Katarina"] = {"KatarinaR"},
    ["Lucian"] = {"LucianR"},
    ["Malzahar"] = {"AlZaharNetherGrasp"},
    ["MasterYi"] = {"Meditate"},
    ["MissFortune"] = {"MissFortuneBulletTime"},
    ["Nunu"] = {"NunuR"},
    ["Pantheon"] = {"PantheonRJump"},
    ["Pantheon"] = {"PantheonRFall"},
    ["Shen"] = {"ShenStandUnited"},
    ["TwistedFate"] = {"Destiny"},
    ["Urgot"] = {"UrgotSwap2"},
    ["Velkoz"] = {"VelkozR"},
    ["Warwick"] = {"WarwickR"},
    ["Xerath"] = {"XerathLocusOfPower2"}
}

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
    local count = 0
    for i, hero in pairs(EnemyHeroes) do
    local Range = range * range
        if GetDistanceSqr(pos, hero.pos) < Range and IsValid(hero) then
        count = count + 1
        end
    end
    return count
end

local function GetEnemyCountLinear(range, pos)
    local count = 0
    for i, enemy in pairs(EnemyHeroes) do
        local enemyLine = ClosestPointOnLineSegment(enemy.pos, pos, myHero.pos)
        if GetDistance(enemy.pos, enemyLine) <= range and ValidTarget(enemy) then
            count = count + 1
        end
    end
    return count
end
 
local function GetAllyCount(range, pos)
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
    if myHero.charName == "Xerath" then
        DelayAction(function() self:LoadXerath() end, 1.05)
    end
    if myHero.charName == "Brand" then
        DelayAction(function() self:LoadBrand() end, 1.05)
    end
    if myHero.charName == "MissFortune" then
        DelayAction(function() self:LoadMissFortune() end, 1.05)
    end
end

function Manager:LoadXerath()
    Xerath:Spells()
    Xerath:Menu()
    Callback.Add("Tick", function() Xerath:Tick() end)
    Callback.Add("Draw", function() Xerath:Draws() end)
end

function Manager:LoadBrand()
    Brand:Spells()
    Brand:Menu()
    Callback.Add("Tick", function() Brand:Tick() end)
    Callback.Add("Draw", function() Brand:Draws() end)
end

function Manager:LoadMissFortune()
    MissFortune:Spells()
    MissFortune:Menu()
    Callback.Add("Tick", function() MissFortune:Tick() end)
    Callback.Add("Draw", function() MissFortune:Draws() end)
end



class "Xerath"

local EnemyLoaded = false
local Timer = Game.Timer()
local TickCount = GetTickCount()
local AARange = 575
local QRange = 735
local ActiveQRange = 0
local lastSpell = GetTickCount()
local lastQ = Game.Timer()
local lastR = Game.Timer()

local MenuIcon = "https://static.wikia.nocookie.net/leagueoflegends/images/c/cf/Xerath_OriginalSquare.png"
local QIcon = "https://static.wikia.nocookie.net/leagueoflegends/images/b/bf/Xerath_Arcanopulse.png"
local WIcon = "https://static.wikia.nocookie.net/leagueoflegends/images/c/c3/Xerath_Eye_of_Destruction.png"
local EIcon = "https://static.wikia.nocookie.net/leagueoflegends/images/c/c5/Xerath_Shocking_Orb.png"
local RIcon = "https://static.wikia.nocookie.net/leagueoflegends/images/2/29/Xerath_Rite_of_the_Arcane.png"


function Xerath:Menu()
    self.Menu = MenuElement({type = MENU, id = "xerath", name = "dnsXerath 2.0", leftIcon = MenuIcon})

    --combo
    self.Menu:MenuElement({id = "combo", name = "Combo", type = MENU})
    self.Menu.combo:MenuElement({id = "qcombo", name = "Use [Q] in Combo", value = true, leftIcon = QIcon})
    self.Menu.combo:MenuElement({id = "wcombo", name = "Use [W] in Combo", value = true, leftIcon = WIcon})
    self.Menu.combo:MenuElement({id = "ecombo", name = "Use [E] in Combo", value = true, leftIcon = EIcon})
    self.Menu.combo:MenuElement({id = "esemi", name = "Semi [E] near Mouse", key = string.byte("Y"), toggle = false, leftIcon = EIcon})
    self.Menu.combo:MenuElement({id = "rcombo", name = "Use [R] in Combo", value = true, leftIcon = RIcon})
    self.Menu.combo:MenuElement({id = "rmanual", name = "Start [R] manually", value = true, leftIcon = RIcon})
    self.Menu.combo:MenuElement({id = "rsemi", name = "Semi [R] near Mouse", key = string.byte("T"), toggle = false, leftIcon = RIcon})

    --auto
    self.Menu:MenuElement({id = "auto", name = "Auto", type = MENU})
    self.Menu.auto:MenuElement({id = "qauto", name = "Allow [Q] autouse", value = true, leftIcon = QIcon})
    self.Menu.auto:MenuElement({id = "wauto", name = "Allow [W] autouse", value = true, leftIcon = WIcon})
    self.Menu.auto:MenuElement({id = "eauto", name = "Allow [E] autouse", value = true, leftIcon = EIcon})

    --Draw
    self.Menu:MenuElement({id = "draw", name = "Draw", type = MENU})
    self.Menu.draw:MenuElement({id = "rdraw", name = "Draw [R] on Minimap", value = true, leftIcon = RIcon})

end

function Xerath:Draws()
    if self.Menu.draw.rdraw:Value() and IsReady(_R) then
        Draw.CircleMinimap(myHero, RPred.range, 2, Draw.Color(255, 255, 0, 255))
    end
end

function Xerath:Spells()
    QPred = {delay = 0.528, radius = 25, range = 735, speed = math.huge, collision = {}, type = "linear"}
    WPred = {delay = 0.528, radius = 25, range = 1000, speed = math.huge, collision = {}, type = "circular"}
    EPred = {delay = 0.250, radius = 25, range = 1050, speed = 1400, collision = {"minion"}, type = "linear"}
    RPred = {delay = 0.627, radius = 25, range = 5200, speed = math.huge, collision = {}, type = "circular"}
end

function Xerath:Tick()
    if _G.JustEvade and _G.JustEvade:Evading() or (_G.ExtLibEvade and _G.ExtLibEvade.Evading) or Game.IsChatOpen() or myHero.dead then return end

    if Control.IsKeyDown(HK_Q) and myHero:GetSpellData(_Q).currentCd > 1 then
        Control.KeyUp(HK_Q)
    end
    CastingQ = myHero.activeSpell.name == "XerathArcanopulseChargeUp"
    CastingW = myHero.activeSpell.name == "XerathArcaneBarrage2"
    CastingE = myHero.activeSpell.name == "XerathMageSpear"
    CastingR = myHero.activeSpell.name == "XerathLocusOfPower2"
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
    self:QLogic()
end

function Xerath:Checks()
    if not CastingQ and not CastingW and not CastingE and not CastingR and _G.SDK.Cursor.Step == 0 and not _G.SDK.Orbwalker:IsAutoAttacking() and _G.SDK.Spell:CanTakeAction({q = 0.65, w = 0.35, e = 0.35, r = 0.75}) then
        return true
    else 
        return false
    end
end

function Xerath:CanUse(spell, mode)
    if mode == nil then
        mode = Mode() 
    end

    if spell == _Q then
        if mode == "Combo" and IsReady(_Q) and self:Checks() and self.Menu.combo.qcombo:Value() then
            return true
        else return false end
        if mode == "Auto" and IsReady(_Q) and self:Checks() and self.Menu.auto.qauto:Value() then
            return true
        else return false end
    end
    if spell == _W then
        if mode == "Combo" and IsReady(_W) and self:Checks() and self.Menu.combo.wcombo:Value() then
            return true
        else return false end
        if mode == "Auto" and IsReady(_W) and self:Checks() and self.Menu.auto.wauto:Value() then
            return true
        else return false end
    end
    if spell == _E then
        if mode == "Combo" and IsReady(_E) and self:Checks() and self.Menu.combo.ecombo:Value() then
            return true
        else return false end
        if mode == "Semi" and IsReady(_E) and self:Checks() and self.Menu.combo.esemi:Value() then
            return true
        else return false end
        if mode == "Auto" and IsReady(_E) and self:Checks() and self.Menu.auto.eauto:Value() then
            return true
        else return false end
    end
    if spell == _R then
        if mode == "Combo" and IsReady(_R) and self:Checks() and self.Menu.combo.rcombo:Value() then
            return true
        else return false end
        if mode == "Semi" and IsReady(_R) and self.Menu.combo.rsemi:Value() then
            return true
        else return false end
    end
end

function Xerath:Logic() 
    if Mode() == "Combo" then
        self:QCombo()
        self:WCombo()
        self:ECombo()
    end
end

function Xerath:Auto()
    for i, enemy in pairs(EnemyHeroes) do
        self:RLogic(enemy)
        self:QKS(enemy)
        self:WKS(enemy)
        self:EKS(enemy)
        self:ESemi(enemy)
        self:EInterrupt(enemy)
        self:EImmobile(enemy)
        if Mode() == "Combo" then
            self:RCombo(enemy)
        end
    end
end

function Xerath:QBuffCheck()
    if BuffActive(myHero, "XerathArcanopulseChargeUp") and Control.IsKeyDown(HK_Q) then
        return false
    else
        return true
    end
end

function Xerath:RBuffCheck()
    if BuffActive(myHero, "XerathLocusOfPower2") then
        return false
    else
        return true
    end
end

function Xerath:QCombo()
    local target = GetTarget(1400)
    if ValidTarget(target) and self:CanUse(_Q, "Combo") and self:Checks() and self:QBuffCheck() and self:RBuffCheck() then
        Control.KeyDown(HK_Q)
        lastQ = Game.Timer()
    end
end

function Xerath:QLogic()
    if not self:QBuffCheck() then

        _G.SDK.Orbwalker:SetAttack(false)
        QPred.range = 735 + (450 * (GetTickCount() - TickCount) / 1000)
        if QPred.range >= 1450 then
            QPred.range = 1450 
        end

        if Mode() == "Combo" then
            local target = GetTarget(1450)
            if ValidTarget(target, QPred.range) and self:RBuffCheck() and lastQ + 0.15 < Game.Timer() then
                local pred = _G.PremiumPrediction:GetPrediction(myHero, target, QPred)
                if pred.CastPos and pred.HitChance >= 0.04 and GetDistance(myHero.pos, pred.CastPos) <= QPred.range then
                    if pred.CastPos:To2D().onScreen then
                        _G.Control.CastSpell(HK_Q, pred.CastPos)
                    else
                        local CastSpot = myHero.pos:Extended(pred.CastPos, 800)
                        _G.Control.CastSpell(HK_Q, CastSpot)
                    end
                end
            end
        end

    else

        _G.SDK.Orbwalker:SetAttack(true)
        TickCount = GetTickCount()
        QPred.range = 735

    end
end

function Xerath:WCombo()
    local target = GetTarget(WPred.range)
    if ValidTarget(target) and self:CanUse(_W, "Combo") and self:Checks() and self:QBuffCheck() and self:RBuffCheck() then
        local pred = _G.PremiumPrediction:GetPrediction(myHero, target, WPred)
        if pred.CastPos and pred.HitChance >= 0.04 and GetDistance(myHero.pos, pred.CastPos) <= WPred.range then
            if pred.CastPos:To2D().onScreen then
                _G.Control.CastSpell(HK_W, pred.CastPos)
            else return end
        end
    end
end

function Xerath:ECombo()
    local target = GetTarget(EPred.range)
    if ValidTarget(target) and self:CanUse(_E, "Combo") and self:Checks() and self:QBuffCheck() and self:RBuffCheck() then
        local pred = _G.PremiumPrediction:GetPrediction(myHero, target, EPred)
        if pred.CastPos and pred.HitChance >= 0.06 and GetDistance(myHero.pos, pred.CastPos) <= EPred.range then
            if pred.CastPos:To2D().onScreen then
                _G.Control.CastSpell(HK_E, pred.CastPos)
            else
                local CastSpot = myHero.pos:Extended(pred.CastPos, 800)
                _G.Control.CastSpell(HK_E, CastSpot)
            end
        end
    end
end


function Xerath:EnemiesAround(enemy)
    local count = 0
    if GetDistance(myHero.pos, enemy.pos) <= 900 then
        count = count + 1
    end
    return count
end

function Xerath:RCombo(enemy)
    if self:EnemiesAround(enemy) >= 1 then return end
    if self.Menu.combo.rmanual:Value() then return end

    local rstacks = 1
    if myHero:GetSpellData(_R).level == 1 then rstacks = 3 end
    if myHero:GetSpellData(_R).level == 2 then rstacks = 4 end
    if myHero:GetSpellData(_R).level == 3 then rstacks = 5 end
    local target = GetTarget(RPred.range)
    if ValidTarget(target) and self:CanUse(_R, "Combo") and self:Checks() and self:RBuffCheck() and self:QBuffCheck() then
        local rdam = getdmg("R", target, myHero, myHero:GetSpellData(_R).level)
        if target.health <= (rdam * (rstacks - 1)) then
            Control.KeyDown(HK_R)
        end
    end
end

function Xerath:RLogic(enemy)
    if not self:RBuffCheck() then
        SetMovement(false)
        if Mode() == "Combo" then
            local target = GetTarget(RPred.range)
            if ValidTarget(target) and self:QBuffCheck() then
                local pred = _G.PremiumPrediction:GetPrediction(myHero, target, RPred)
                if pred.CastPos and pred.HitChance >= 0.04 and GetDistance(myHero.pos, pred.CastPos) <= RPred.range and lastR + 0.9 < Game.Timer() then
                    if pred.CastPos:To2D().onScreen then
                        _G.Control.CastSpell(HK_R, pred.CastPos)
                        lastR = Game.Timer()
                    else
                        CastSpellMM(HK_R, pred.CastPos)
                        lastR = Game.Timer()
                    end
                end
            end
        end
        if ValidTarget(enemy, RPred.range) and self.Menu.combo.rsemi:Value() and GetDistance(mousePos, enemy.pos) <= 250 and lastR + 0.9 < Game.Timer() then
            PrintChat("1")
            local pred = _G.PremiumPrediction:GetPrediction(myHero, enemy, RPred)
            if pred.CastPos and pred.HitChance >= 0.04 and GetDistance(myHero.pos, pred.CastPos) <= RPred.range then
                PrintChat("2")
                if pred.CastPos:To2D().onScreen then
                    _G.Control.CastSpell(HK_R, pred.CastPos)
                    lastR = Game.Timer()
                else
                    CastSpellMM(HK_R, pred.CastPos)
                    lastR = Game.Timer()
                end
            end
        end

    else
        SetMovement(true)
    end
end

function Xerath:QKS(enemy)
    if ValidTarget(enemy, QPred.range) and self:CanUse(_Q, "Auto") and self:Checks() and self:QBuffCheck() and self:RBuffCheck() then
        local qdam = getdmg("Q", enemy, myHero, myHero:GetSpellData(_Q).level)
        if qdam > enemy.health then
            local pred = _G.PremiumPrediction:GetPrediction(myHero, enemy, QPred)
            if pred.CastPos and pred.HitChance >= 0.04 and GetDistance(myHero.pos, pred.CastPos) <= QPred.range then
                if pred.CastPos:To2D().onScreen then
                    _G.Control.CastSpell(HK_Q, pred.CastPos)
                else
                    local CastSpot = myHero.pos:Extended(pred.CastPos, 800)
                    _G.Control.CastSpell(HK_Q, CastSpot)
                end
            end
        end
    end
end

function Xerath:WKS(enemy)
    if ValidTarget(enemy, WPred.range) and self:CanUse(_W, "Auto") and self:Checks() and self:QBuffCheck() and self:RBuffCheck() then
        local wdam = getdmg("W", enemy, myHero, myHero:GetSpellData(_W).level)
        if wdam > enemy.health then
            if enemy.pos:To2D().onScreen then
                _G.Control.CastSpell(HK_W, enemy.pos)
            else return end
        end
    end
end

function Xerath:EKS(enemy)
    if ValidTarget(enemy, EPred.range) and self:CanUse(_E, "Auto") and self:Checks() and self:QBuffCheck() and self:RBuffCheck() then
        local edam = getdmg("E", enemy, myHero, myHero:GetSpellData(_E).level)
        if edam > enemy.health then
            local pred = _G.PremiumPrediction:GetPrediction(myHero, enemy, EPred)
            if pred.CastPos and pred.HitChance >= 0.04 and GetDistance(myHero.pos, pred.CastPos) <= EPred.range then
                if pred.CastPos:To2D().onScreen then
                    _G.Control.CastSpell(HK_E, pred.CastPos)
                else
                    local CastSpot = myHero.pos:Extended(pred.CastPos, 800)
                    _G.Control.CastSpell(HK_E, CastSpot)
                end
            end
        end
    end
end

function Xerath:ESemi(enemy)
    if ValidTarget(enemy, EPred.range) and self.Menu.combo.esemi:Value() and self:Checks() and self:QBuffCheck() and self:RBuffCheck() and GetDistance(enemy.pos, mousePos) <= 250 then
        local pred = _G.PremiumPrediction:GetPrediction(myHero, enemy, EPred)
        if pred.CastPos and pred.HitChance >= 0.04 and GetDistance(pred.CastPos, myHero.pos) <= EPred.range then
            if pred.CastPos:To2D().onScreen then
                _G.Control.CastSpell(HK_E, pred.CastPos)
            else
                local CastSpot = myHero.pos:Extended(pred.CastPos, 800)
                _G.Control.CastSpell(HK_E, CastSpot)
            end
        end
    end
end


function Xerath:EInterrupt(enemy)
    local Timer = Game.Timer()
    if ValidTarget(enemy, EPred.range) and self:CanUse(_E, "Auto") and self:Checks() and enemy.activeSpell.valid and not enemy.activeSpell.isStopped and self:QBuffCheck() and self:RBuffCheck() then
        local t = InterruptSpells[enemy.charName]
        if t then
            for i = 1, #t do
                if enemy.activeSpell.name == t[i] and enemy.activeSpell.startTime - Timer > 0.33 then
                    local pred = _G.PremiumPrediction:GetPrediction(myHero, enemy, EPred)
                    if pred.CastPos and pred.HitChance >= 0.75 and GetDistance(myHero.pos, pred.CastPos) <= EPred.range then
                        if pred.CastPos:To2D().onScreen then
                            _G.Control.CastSpell(HK_E, pred.CastPos)
                        else
                            local CastSpot = myHero.pos:Extended(pred.CastPos, 800)
                            _G.Control.CastSpell(HK_E, CastSpot)
                        end
                    end
                end
            end
        end
    end
end

function Xerath:EImmobile(enemy)
    if ValidTarget(enemy, EPred.range) and self:CanUse(_E, "Auto") and self:Checks() and self:QBuffCheck() and self:RBuffCheck() then
        if IsImmobile(enemy) >= 0.5 then
            local pred = _G.PremiumPrediction:GetPrediction(myHero, enemy, EPred)
            if pred.CastPos and pred.HitChance >= 1 and GetDistance(myHero.pos, pred.CastPos) <= EPred.range then
                if pred.CastPos:To2D().onScreen then
                    _G.Control.CastSpell(HK_E, pred.CastPos)
                else
                    local CastSpot = myHero.pos:Extended(pred.CastPos, 800)
                    _G.Control.CastSpell(HK_E, CastSpot)
                end
            end
        elseif enemy.pathing and enemy.pathing.isDashing then
            if GetDistance(enemy.pathing.endPos, myHero.pos) < GetDistance(enemy.pos, myHero.pos) then
                local pred = _G.PremiumPrediction:GetPrediction(myHero, enemy, EPred)
                if pred.CastPos and pred.HitChance >= 1 and myHero.pos:DistanceTo(pred.CastPos) <= EPred.range then
                    if pred.CastPos:To2D().onScreen then
                        _G.Control.CastSpell(HK_E, pred.CastPos)
                    else
                        local CastSpot = myHero.pos:Extended(pred.CastPos, 800)
                        _G.Control.CastSpell(HK_E, CastSpot)
                    end
                end
            end
        end
    end
end

class "Brand"

local EnemyLoaded = false
local PassiveBuff = "BrandAblaze"
local Icon = "https://www.proguides.com/public/media/rlocal/champion/thumbnail/63.png"
local QIcon = "https://www.proguides.com/public/media/rlocal/champion/ability/thumbnail/BrandQ.png"
local WIcon = "https://www.proguides.com/public/media/rlocal/champion/ability/thumbnail/BrandW.png"
local EIcon = "https://www.proguides.com/public/media/rlocal/champion/ability/thumbnail/BrandE.png"
local RIcon = "https://www.proguides.com/public/media/rlocal/champion/ability/thumbnail/BrandR.png"

function Brand:Menu()
    self.Menu = MenuElement({type = MENU, id = "brand", name = "dnsBrand 2.0", leftIcon = Icon})

    self.Menu:MenuElement({id = "combo", name = "Combo", type = MENU})
    self.Menu.combo:MenuElement({id = "qcombo", name = "Use [Q] in Combo", value = true, leftIcon = QIcon})
    self.Menu.combo:MenuElement({id = "wcombo", name = "Use [W] in Combo", value = true, leftIcon = WIcon})
    self.Menu.combo:MenuElement({id = "ecombo", name = "Use [E] in Combo", value = true, leftIcon = EIcon})
    self.Menu.combo:MenuElement({id = "rcombo", name = "Use [R] in Combo", value = true, leftIcon = RIcon})

    self.Menu:MenuElement({id = "auto", name = "Auto", type = MENU})
    self.Menu.auto:MenuElement({id = "qauto", name = "Allow [Q] autouse", value = true, leftIcon = QIcon})
    self.Menu.auto:MenuElement({id = "wauto", name = "Allow [W] autouse", value = true, leftIcon = WIcon})
    self.Menu.auto:MenuElement({id = "eauto", name = "Allow [E] autouse", value = true, leftIcon = EIcon})
    self.Menu.auto:MenuElement({id = "rauto", name = "Allow [R] autouse", value = true, leftIcon = RIcon})

end

function Brand:Spells()
    QPred = {delay = 0.25, radius = 25, range = 1040, speed = 1200, collision = {"minion"}, type = "linear"}
    WPred = {delay = 0.627, radius = 25, range = 900, speed = math.huge, collision = {}, type = "circular"}
    EPred = {range = 675}
    RPred = {range = 750}
end

function Brand:Draws()
end

function Brand:Tick()
    if _G.JustEvade and _G.JustEvade:Evading() or (_G.ExtLibEvade and _G.ExtLibEvade.Evading) or Game.IsChatOpen() or myHero.dead then return end
    CastingQ = myHero.activeSpell.name == "BrandQ"
    CastingW = myHero.activeSpell.name == "BrandW"
    CastingE = myHero.activeSpell.name == "BrandE"
    CastingR = myHero.activeSpell.name == "BrandR"
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
end

function Brand:Checks()
    if not CastingQ and not CastingW and not CastingE and not CastingR and _G.SDK.Cursor.Step == 0 and _G.SDK.Spell:CanTakeAction({q = 0.35, w = 0.35, e = 0.35, r = 0.35}) and not _G.SDK.Orbwalker:IsAutoAttacking() then
        return true
    else return false end
end

function Brand:CanUse(spell, mode)
    if mode == nil then
        mode = Mode()
    end

    if spell == _Q then
        if mode == "Combo" and IsReady(_Q) and self:Checks() and self.Menu.combo.qcombo:Value() then
            return true
        else return false end
        if mode == "Auto" and IsReady(_Q) and self:Checks() and self.Menu.auto.qauto:Value() then
            return true
        else return false end
    end
    if spell == _W then
        if mode == "Combo" and IsReady(_W) and self:Checks() and self.Menu.combo.wcombo:Value() then
            return true
        else return false end
        if mode == "Auto" and IsReady(_W) and self:Checks() and self.Menu.auto.wauto:Value() then
            return true 
        else return false end
    end
    if spell == _E then
        if mode == "Combo" and IsReady(_E) and self:Checks() and self.Menu.combo.ecombo:Value() then
            return true
        else return false end
        if mode == "Auto" and IsReady(_E) and self:Checks() and self.Menu.auto.eauto:Value() then
            return true
        else return false end
    end
    if spell == _R then
        if mode == "Combo" and IsReady(_R) and self:Checks() and self.Menu.combo.rcombo:Value() then
            return true
        else return false end
        if mode == "Auto" and IsReady(_R) and self:Checks() and self.Menu.auto.rauto:Value() then
            return true
        else return false end
    end
end

function Brand:Logic()
    if Mode() == "Combo" then
        self:QCombo()
        self:WCombo()
        self:ECombo()
        self:RCombo()
    end
end

function Brand:Auto()
    for i, enemy in pairs(EnemyHeroes) do
        self:QAuto(enemy)
        self:QKS(enemy)
        self:WKS(enemy)
        self:RKS(enemy)
        self:EKS(enemy)
        self:RDeath()
    end
end

function Brand:QCombo()
    local target = GetTarget(QPred.range)
    if ValidTarget(target) and self:CanUse(_Q, "Combo") and self:Checks() and BuffActive(target, PassiveBuff) then
        local pred = _G.PremiumPrediction:GetPrediction(myHero, target, QPred)
        if pred.CastPos and pred.HitChance >= 0.04 and GetDistance(myHero.pos, pred.CastPos) <= QPred.range then
            if pred.CastPos:To2D().onScreen then
                _G.Control.CastSpell(HK_Q, pred.CastPos)
            else
                local CastSpot = myHero.pos:Extended(pred.CastPos, 800)
                _G.Control.CastSpell(HK_Q, CastSpot)
            end
        end
    end
end

function Brand:WCombo()
    local target = GetTarget(WPred.range)
    if ValidTarget(target) and self:CanUse(_W, "Combo") and self:Checks() then
        local pred = _G.PremiumPrediction:GetPrediction(myHero, target, WPred)
        if pred.CastPos and pred.HitChance >= 0.04 and GetDistance(myHero.pos, pred.CastPos) <= WPred.range then
            if pred.CastPos:To2D().onScreen then
                _G.Control.CastSpell(HK_W, pred.CastPos)
            else return end
        end
    end
end

function Brand:ECombo()
    local target = GetTarget(EPred.range)
    if ValidTarget(target) and self:CanUse(_E, "Combo") and self:Checks() then
        if target.pos:To2D().onScreen then
            _G.Control.CastSpell(HK_E, target)
        else return end
    end
end

function Brand:RCombo()
    local target = GetTarget(RPred.range)
    if ValidTarget(target) and self:CanUse(_R, "Combo") and self:Checks() and GetEnemyCount(750, target.pos) >= 2 then
        if target.pos:To2D().onScreen then
            _G.Control.CastSpell(HK_R, target)
        else return end
    end
end

function Brand:QAuto(enemy)
    if ValidTarget(enemy, QPred.range) and self:CanUse(_Q, "Auto") and self:Checks() and BuffActive(enemy, PassiveBuff) then
        local pred = _G.PremiumPrediction:GetPrediction(myHero, enemy, QPred)
        if pred.CastPos and pred.HitChance >= 0.06 and GetDistance(myHero.pos, pred.CastPos) <= QPred.range then
            if pred.CastPos:To2D().onScreen then
                _G.Control.CastSpell(HK_Q, pred.CastPos)
            else
                local CastSpot = myHero.pos:Extended(pred.CastPos, 800)
                _G.Control.CastSpell(HK_Q, CastSpot)
            end
        end
    end
end

function Brand:QKS(enemy)
    if ValidTarget(enemy, QPred.range) and self:CanUse(_Q, "Auto") and self:Checks() then
        local qdam = getdmg("Q", enemy, myHero, myHero:GetSpellData(_Q).level)
        if qdam > enemy.health then
            local pred = _G.PremiumPrediction:GetPrediction(myHero, enemy, QPred)
            if pred.CastPos and pred.HitChance >= 0.04 and GetDistance(myHero.pos, pred.CastPos) <= QPred.range then
                if pred.CastPos:To2D().onScreen then
                    _G.Control.CastSpell(HK_Q, pred.CastPos)
                else
                    local CastSpot = myHero.pos:Extended(pred.CastPos, 800)
                    _G.Control.CastSpell(HK_Q, CastSpot)
                end
            end
        end
    end
end

function Brand:WKS(enemy) 
    if ValidTarget(enemy, WPred.range) and self:CanUse(_W, "Auto") and self:Checks() then
        local wdam = getdmg("W", enemy, myHero, myHero:GetSpellData(_W).level)
        if wdam > enemy.health then
            local pred = _G.PremiumPrediction:GetPrediction(myHero, enemy, WPred)
            if pred.CastPos and pred.HitChance >= 0.04 and GetDistance(myHero.pos, pred.CastPos) <= WPred.range then
                if pred.CastPos:To2D().onScreen then
                    _G.Control.CastSpell(HK_W, pred.CastPos)
                else return end
            end
        end
    end
end

function Brand:EKS(enemy)
    if ValidTarget(enemy, EPred.range) and self:CanUse(_E, "Auto") and self:Checks() then
        local edam = getdmg("E", enemy, myHero, myHero:GetSpellData(_E).level)
        if edam > enemy.health then
            _G.Control.CastSpell(HK_E, enemy)
        end
    end 
end

function Brand:RKS(enemy)
    if ValidTarget(enemy, RPred.range) and self:CanUse(_R, "Auto") and self:Checks() then
        local rdam = getdmg("R", enemy, myHero, myHero:GetSpellData(_R).level)
        if rdam > enemy.health then
            _G.Control.CastSpell(HK_R, enemy)
        end
    end
end

function Brand:RDeath()
    if not (IsReady(_R) and self:Checks() and self.Menu.auto.rauto:Value()) then
        return
    end
    local heroes = _G.SDK.ObjectManager:GetEnemyHeroes(RPred.range)
    for i, hero in ipairs(heroes) do 
        if not (myHero.health/myHero.maxHealth <= 0.25) and ValidTarget(hero) then 
            return 
        end
        Control.CastSpell(HK_R, hero)
    end
end

class "MissFortune"

local AARange = myHero.range + myHero.boundingRadius
local EnemyLoaded = false
local RBuff = "BrandAblaze"
local Icon = "https://static.wikia.nocookie.net/leagueoflegends/images/7/72/Miss_Fortune_OriginalSquare.png"
local QIcon = "https://static.wikia.nocookie.net/leagueoflegends/images/c/cc/Miss_Fortune_Double_Up.png"
local WIcon = "https://static.wikia.nocookie.net/leagueoflegends/images/5/53/Miss_Fortune_Strut.png"
local EIcon = "https://static.wikia.nocookie.net/leagueoflegends/images/8/82/Miss_Fortune_Make_It_Rain.png"
local RIcon = "https://static.wikia.nocookie.net/leagueoflegends/images/e/ec/Miss_Fortune_Bullet_Time.png"

function MissFortune:Menu()
    self.Menu = MenuElement({type = MENU, id = "fortune", name = "dnsMissFortune", leftIcon = Icon})

    self.Menu:MenuElement({id = "combo", name = "Combo", type = MENU})
    self.Menu.combo:MenuElement({id = "qcombo", name = "Use [Q] in Combo", value = true, leftIcon = QIcon})
    self.Menu.combo:MenuElement({id = "wcombo", name = "Use [W] in Combo", value = true, leftIcon = WIcon})
    self.Menu.combo:MenuElement({id = "ecombo", name = "Use [E] in Combo", value = true, leftIcon = EIcon})
    self.Menu.combo:MenuElement({id = "rsemi", name = "Use [R] Semi near Mouse", key = string.byte("T"), toggle = false, leftIcon = RIcon})

    self.Menu:MenuElement({id = "auto", name = "Auto", type = MENU})
    self.Menu.auto:MenuElement({id = "qauto", name = "Use [Q] auto", value = true, leftIcon = QIcon})
    self.Menu.auto:MenuElement({id = "eauto", name = "Use [E] auto", value = true, leftIcon = EIcon})
end

function MissFortune:Spells()
    QPred = {delay = 0.25, speed = 1400, range = AARange}
    EPred = {delay = 0.25, speed = math.huge, range = 1000, radius = 25, type = circular, collision = {}}
    RPred = {delay = 0.25, speed = 2000, range = 1450, radius = 25, angle = 30, type = conic, collision = {}}
end

function MissFortune:Draws()
end

function MissFortune:Tick()
    if _G.JustEvade and _G.JustEvade:Evading() or (_G.ExtLibEvade and _G.ExtLibEvade.Evading) or Game.IsChatOpen() or myHero.dead then return end
    CastingQ = myHero.activeSpell.name == "MissFortuneRicochetShot"
    CastingW = myHero.activeSpell.name == "MissFortuneViciousStrikes"
    CastingE = myHero.activeSpell.name == "MissFortuneScattershot"
    CastingR = myHero.activeSpell.name == "MissFortuneBulletTime"
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
end

function MissFortune:Checks()
    if not CastingQ and not CastingW and not CastingE and not CastingR and _G.SDK.Cursor.Step == 0 and _G.SDK.Spell:CanTakeAction({q = 0.35, w = 0.1, e = 0.35, r = 0.1}) and not _G.SDK.Orbwalker:IsAutoAttacking() then
        return true
    else return false end
end

function MissFortune:Logic()
    if Mode() == "Combo" then
        self:QCombo()
        self:WCombo()
        self:ECombo()
    end
end

function MissFortune:Auto()
    self:RSemi()
    self:EAuto()
    self:QAuto()
end

function MissFortune:QCombo()
    if not (IsReady(_Q) and self:Checks() and self.Menu.combo.qcombo:Value()) then
        return 
    end
    local target = GetTarget(QPred.range)
    if target == nil then
        return
    end
    Control.CastSpell(HK_Q, target)
end

function MissFortune:WCombo()
    if not (IsReady(_W) and self:Checks() and self.Menu.combo.wcombo:Value()) then
        return
    end
    local target = GetTarget(AARange)
    if target == nil then
        return 
    end
    Control.CastSpell(HK_W)
end

function MissFortune:ECombo()
    if not (IsReady(_E) and self:Checks() and self.Menu.combo.ecombo:Value()) then
        return 
    end
    local target = GetTarget(EPred.range)
    if target == nil then
        return 
    end
    local pred = _G.PremiumPrediction:GetPrediction(myHero, target, EPred)
    if not (pred.CastPos and pred.HitChance >= 0.04 and GetDistance(myHero.pos, pred.CastPos) <= EPred.range) then
        return 
    end
    Control.CastSpell(HK_E, pred.CastPos)
end

function MissFortune:RSemi()
    if not (IsReady(_R) and self:Checks() and self.Menu.combo.rsemi:Value()) then
        return
    end
    local heroes = _G.SDK.ObjectManager:GetEnemyHeroes(RPred.range)
    for i, hero in ipairs(heroes) do
        if not (ValidTarget(hero) and GetDistance(hero.pos, mousePos) < 300) then
            return
        end 
        local pred = _G.PremiumPrediction:GetPrediction(myHero, hero, RPred)
        if not (pred.CastPos and pred.HitChance >= 0.04 and GetDistance(myHero.pos, pred.CastPos) <= RPred.range) then
            return 
        end
        Control.CastSpell(HK_R, pred.CastPos)
    end
end

function MissFortune:EAuto()
    if not (IsReady(_E) and self:Checks() and self.Menu.auto.eauto:Value()) then
        return
    end
    local heroes = _G.SDK.ObjectManager:GetEnemyHeroes(EPred.range)
    for i, hero in ipairs(heroes) do
        if not ValidTarget(hero) then 
            return
        end
        local edam = getdmg("E", hero, myHero, 2, myHero:GetSpellData(_E).level) * 3
        if not (hero.health < edam) then 
            return 
        end
        Control.CastSpell(HK_E, hero)
    end
end

function MissFortune:QAuto()
    if not (IsReady(_Q) and self:Checks() and self.Menu.auto.qauto:Value()) then
        return
    end
    local minions = _G.SDK.ObjectManager:GetEnemyMinions(QPred.range)
    for i, minion in ipairs(minions) do
        if not (ValidTarget(minion)) then
            return
        end
        local minRange = GetDistance(myHero.pos, minion.pos)
        local checkRange = myHero.pos:Extended(minion.pos, minRange + 250)
        local target = GetTarget(QPred.range + 500)
        if not (ValidTarget(target) and GetDistance(checkRange, target.pos) <= 150) then
            return 
        end
        Control.CastSpell(HK_Q, minion)
    end
end

function OnLoad()
    Manager()
end

