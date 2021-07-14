require "PremiumPrediction"
require "DamageLib"
require "2DGeometry"
require "MapPositionGOS"


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
            Name = "dnsFighter.lua",
            Url = "https://raw.githubusercontent.com/fkndns/dnsFighter/main/dnsFighter.lua"
       },
        Version = {
            Path = SCRIPT_PATH,
            Name = "dnsActivator.version",
            Url = "https://raw.githubusercontent.com/fkndns/dnsFighter/main/dnsFighter.version"    -- check if Raw Adress correct pls.. after you have create the version file on Github
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
            if BuffType == 5 or BuffType == 12 or BuffType == 22 or BuffType == 23 or BuffType == 25 or BuffType == 30 or buff.name == "recall" then
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
            if BuffType == 5 or BuffType == 8 or BuffType == 9 or BuffType == 12 or BuffType == 22 or BuffType == 23 or BuffType == 25 or BuffType == 32 then
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
            if BuffType == 5 or BuffType == 8 or BuffType == 9 or BuffType == 12 or BuffType == 22 or BuffType == 23 or BuffType == 25 or BuffType == 32 or BuffType == 10 then
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

function EnableMovement()
    SetMovement(true)
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

local function dnsTargetSelector(unit, range, output, menVal)
    local unitMRValue = unit.magicResist - (unit.magicResist * myHero.magicPenPercent) - myHero.magicPen
    local unitMRMultiplier = unitMRValue / 100
    local unitMREHP = unit.health * (1 / unitMRMultiplier) or 0
    local unitARValue = unit.armor - (unit.armor * myHero.armorPenPercent) - myHero.armorPen
    local unitARMultiplier = unitARValue / 100
    local unitAREHP = unit.health * (1 / unitARMultiplier) or 0 
    if ValidTarget(unit, range) then
        if output == nil then
            --PrintChat("Scuffed"..unit.charName)
            return unit
        else
            if menVal == 1 then
                if unit.health < output.health then
                    --PrintChat("lowest Health "..unit.charName)
                    return unit
                end
            elseif menVal == 2 then
                if unit.totalDamage > output.totalDamage then
                    --PrintChat("highest AD "..unit.charName)
                    return unit
                end
            elseif menVal == 3 then
                if unit.ap > output.ap then
                    --PrintChat("highest AP  "..unit.charName)
                    return unit
                end
            end
        end
    else
        return nil
    end
    return output
end

class "Manager"

function Manager:__init()
    if myHero.charName == "Irelia" then
        DelayAction(function() self:LoadIrelia() end, 1.05)
    end
end

function Manager:LoadIrelia()
    Irelia:Spells()
    Irelia:Menu()
    Callback.Add("Tick", function() Irelia:Tick() end)
    Callback.Add("Draw", function() Irelia:Draws() end)
end

class "Irelia"

local EnemyLoaded = false
local AARange = 197 + myHero.boundingRadius
local QRange = 532 + myHero.boundingRadius
local WRange = 750 + myHero.boundingRadius
local ERange = 780 + myHero.boundingRadius
local RRange = 870 + myHero.boundingRadius
local E1Pos = nil
local PassiveMark = "ireliamark"
local StackBuff = "ireliapassivestacks"
local StackBuffMax = "ireliapassivestacksmax"
local WBuff = "ireliawdefense"
local IreliaIcon = "https://www.proguides.com/public/media/rlocal/champion/thumbnail/39.png"
local QIcon = "https://www.proguides.com/public/media/rlocal/champion/ability/thumbnail/IreliaQ.png"
local WIcon = "https://www.proguides.com/public/media/rlocal/champion/ability/thumbnail/IreliaW.png"
local EIcon = "https://www.proguides.com/public/media/rlocal/champion/ability/thumbnail/IreliaE.png"
local RIcon = "https://www.proguides.com/public/media/rlocal/champion/ability/thumbnail/IreliaR.png"



function Irelia:Menu()
    self.Menu = MenuElement({type = MENU, id = "irelia", name = "dnsIrelia", leftIcon = IreliaIcon})

    -- Combo
    self.Menu:MenuElement({id = "combo", name = "Combo", type = MENU})
    self.Menu.combo:MenuElement({id = "qcombo", name = "Use [Q] in Combo", value = true, leftIcon = QIcon})
    self.Menu.combo:MenuElement({id = "qcombogap", name = "Use[Q] Minion GapCloser", value = true, leftIcon = QIcon})
    self.Menu.combo:MenuElement({id = "wcombo", name = "Use [W] in Combo", value = true, leftIcon = WIcon})
    self.Menu.combo:MenuElement({id = "ecombo", name = "Use [E] in Combo", value = true, leftIcon = EIcon})
    self.Menu.combo:MenuElement({id = "ecombohc", name = "[E] HitChance >=", value = 0.5, min = 0.1, max = 1.0, step = 0.1, leftIcon = EIcon})
    self.Menu.combo:MenuElement({id = "rcombo", name = "Use [R] in Combo", value = true, leftIcon = RIcon})
    self.Menu.combo:MenuElement({id = "rcombohc", name = "[R] HitChance >=", value = 0.5, min = 0.1, max = 1.0, step = 0.1})
    self.Menu.combo:MenuElement({id = "rcombocount", name = "[R] HitCount >=", value = 2, min = 1, max = 5, step = 1, leftIcon = RIcon})

    -- lasthit / LaneClear
    self.Menu:MenuElement({id = "farm", name = "Farming Modes", type = MENU})
    self.Menu.farm:MenuElement({id = "qlaneclear", name = "Use [Q] in LaneClear", value = true, leftIcon = QIcon})
    self.Menu.farm:MenuElement({id = "qlaneclearmana", name = "[Q] LaneClear Mana >=", value = 15, min = 0, max = 100, step = 5, identifier = "%", leftIcon = QIcon})
    self.Menu.farm:MenuElement({id = "qlasthit", name = "Use [Q] in LastHit", value = true, leftIcon = QIcon})
    self.Menu.farm:MenuElement({id = "qlasthitmana", name = "[Q] LastHit Mana >=", value = 15, min = 0, max = 100, step = 5, identifier = "%", leftIcon = QIcon})

    -- draws
    self.Menu:MenuElement({id = "draws", name = "Draws", type = MENU})
    self.Menu.draws:MenuElement({id = "qdraw", name = "Draw [Q] Range", value = false, leftIcon = QIcon})
    self.Menu.draws:MenuElement({id = "wdraw", name = "Draw [W] Range", value = false, leftIcon = WIcon})
    self.Menu.draws:MenuElement({id = "edraw", name = "Draw [E] Range", value = false, leftIcon = EIcon})
    self.Menu.draws:MenuElement({id = "rdraw", name = "Draw [R] Range", value = false, leftIcon = RIcon})

    -- Misc 
    self.Menu:MenuElement({id = "misc", name = "Misc", type = MENU})
    self.Menu.misc:MenuElement({id = "meleehelper", name = "MeleeHelper", value = false})
end

function Irelia:Spells()
    WSpellData = {speed = math.huge, range = WRange, delay = 0.25, radius = 60, collision = {}, type = "linear"}
    ESpellData = {speed = math.huge, range = ERange - 50, delay = 0.4, radius = 60, collision = {}, type = "circular"}
    RSpellData = {speed = 2000, range = RRange - 50, delay = 0.4, radius = 60, collision = {}, type = "linear"}
end

function Irelia:Draws()
    if self.Menu.draws.edraw:Value() then
        Draw.Circle(myHero, ERange, 2, Draw.Color(255, 255, 255, 255))
    end
    if self.Menu.draws.qdraw:Value() then
        Draw.Circle(myHero, AARange, 2, Draw.Color(255, 255, 255, 0))
    end
    if self.Menu.draws.wdraw:Value() then
        Draw.Circle(myHero, WRange, 2, Draw.Color(255, 255, 0, 255))
    end
    if self.Menu.draws.rdraw:Value() then
        Draw.Circle(myHero, RRange, 2, Draw.Color(255, 0, 255, 255))
    end
end

function Irelia:Tick()
    if _G.JustEvade and _G.JustEvade:Evading() or (_G.ExtLibEvade and _G.ExtLibEvade.Evading) or Game.IsChatOpen() or myHero.dead then return end
    target = GetTarget(1500)
    if target and ValidTarget(target) then
        --PrintChat(target.pos:To2D())
        --PrintChat(mousePos:To2D())
        GaleMouseSpot = self:MoveHelper(target)
    else
        _G.SDK.Orbwalker.ForceMovement = nil
    end
    CastingQ = myHero.activeSpell.name == "IreliaQ"
    CastingW = myHero.activeSpell.name == "IreliaW"
    CastingE = myHero.activeSpell.name == "IreliaE"
    CastingE2 = myHero.activeSpell.name == "IreliaE2"
    CastingR = myHero.activeSpell.name == "IreliaR"
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

function Irelia:CastingChecks()
    if not CastingQ or not CastingW or not CastingE or not CastingR or not CastingE2 then
        return true
    else
        return false
    end
end

function Irelia:CanUse(spell, mode)
    if mode == nil then 
        mode = Mode()
    end
    if spell == _Q then
        if mode == "Combo" and self.Menu.combo.qcombo:Value() and IsReady(_Q) then
            return true
        end
        if mode == "Combo2" and self.Menu.combo.qcombogap:Value() and IsReady(_Q) then
            return true
        end
        if mode == "LastHit" and self.Menu.farm.qlasthit:Value() and IsReady(_Q) and myHero.mana / myHero.maxMana >= self.Menu.farm.qlasthitmana:Value() / 100 then
            return true
        end
        if mode == "LaneClear" and self.Menu.farm.qlaneclear:Value() and IsReady(_Q) and myHero.mana / myHero.maxMana >= self.Menu.farm.qlaneclearmana:Value() / 100 then
            return true
        end
    end
    if spell == _W then
        if mode == "Combo" and self.Menu.combo.wcombo:Value() and IsReady(_W) then
            return true
        end
    end
    if spell == _E then
        if mode == "Combo" and self.Menu.combo.ecombo:Value() and IsReady(_E) then
            return true
        end
    end
    if spell == _R then
        if mode == "Combo" and self.Menu.combo.rcombo:Value() and IsReady(_R) then
            return true
        end
    end
end

function Irelia:Minions()
    local minions = _G.SDK.ObjectManager:GetEnemyMinions(QRange)
    for i = 1, #minions do
            local minion = minions[i]
            if Mode() == "Combo" then
                self:QBuffStack(minion)
            end
            if Mode() == "LaneClear" then
                self:QLaneClear(minion)
            end
            if Mode() == "LastHit" then
                self:QLastHit(minion)
            end
    end
end

function Irelia:Auto()
    for i, enemy in pairs(EnemyHeroes) do
        if aatarget ~= nil then
            _G.SDK.Orbwalker.ForceTarget = aatarget
        else
            _G.SDK.Orbwalker.ForceTarget = nil
        end
        if Mode() == "Combo" then
            self:QCombo1(enemy)
            self:QCombo3(enemy)
        end
        self:QDodge(enemy)
    end   
end

function Irelia:Logic()
    if target == nil then return end
    if Mode() == "Combo" then
            self:ComboE1()
            self:ComboE2()
            self:WKill()
            self:RCombo()

    end
end

function Irelia:QCombo1(enemy)
    if ValidTarget(enemy, QRange) and self:CanUse(_Q, "Combo") and BuffActive(enemy, "ireliamark") and self:CastingChecks() and myHero.attackData.state ~= 2 then
        Control.CastSpell(HK_Q, enemy)
    end
end

function Irelia:QCombo3(enemy) 
    if ValidTarget(enemy, QRange) and self:CanUse(_Q, "Combo") and enemy.health / enemy.maxHealth <= 0.5 then
        local QDam = getdmg("Q", enemy, myHero, 1, myHero:GetSpellData(_Q).level)
        if enemy.health <= QDam and self:CastingChecks() then
            Control.CastSpell(HK_Q, enemy)
        end
    end
end

function Irelia:QBuffStack(minion)
    local MinionQTarget = GetTarget(QRange + 400)
    if MinionQTarget ~= nil and self:CanUse(_Q, "Combo") and self:CastingChecks() and myHero.attackData.state ~= 2 then
        if ValidTarget(minion, QRange) and GetDistance(minion.pos, MinionQTarget.pos) <= 300 then
            local QDam = getdmg("Q", minion, myHero, 2, myHero:GetSpellData(_Q).level)
            if minion.health <= QDam or BuffActive(minion, PassiveMark) then
                Control.CastSpell(HK_Q, minion)
            end
        end
    end
end

function Irelia:QDodge(enemy)
    local minions = _G.SDK.ObjectManager:GetEnemyMinions(QRange)
    for i = 1, #minions do
        local minion = minions[i]
        if self:CanUse(_Q, "Combo") and enemy.activeSpell.valid and enemy.isChanneling and enemy.activeSpell.spellWasCast then
           -- PrintChat("1")
            local placementPos = enemy.activeSpell.placementPos
            local width = enemy.activeSpell.width
            local spellLine = ClosestPointOnLineSegment(myHero.pos, enemy.pos, placementPos)
            if GetDistance(myHero.pos, spellLine) <= width then
                local spellLine2 = ClosestPointOnLineSegment(minion.pos, enemy.pos, placementPos)
                if ValidTarget(minion, QRange) and GetDistance(minion.pos, spellLine2) >= 200 then
                    local QDam = getdmg("Q", minion, myHero, 2, myHero:GetSpellData(_Q).level)
                    if (minion.health <= QDam or BuffActive(minion, PassiveMark) or myHero.health / myHero.maxHealth <= 0.25) and self:CastingChecks() and myHero.attackData.state ~=2 then
                        Control.CastSpell(HK_Q, minion)
                       -- PrintChat("Dodged")
                    end
                end
            end
        end
    end
end


function Irelia:ComboE1()
    local e1target = GetTarget(ERange)
    if e1target ~= nil and self:CanUse(_E, "Combo") and myHero:GetSpellData(_E).name == "IreliaE" and self:CastingChecks() and myHero.attackData.state ~= 2 and not BuffActive(e1target, PassiveMark) then
        local NextPos = GetUnitPositionNext(e1target)
        local Direction = Vector((NextPos-e1target.pos):Normalized())
        local CastSpot = e1target.pos - Direction * e1target.ms / 2
        if CastSpot ~= nil and GetDistance(myHero.pos, CastSpot) <= ERange - 100 then
            Control.CastSpell(HK_E, CastSpot)
        end
    end 
end

function Irelia:ComboE2()
    local e2target = GetTarget(ERange)
    if e2target ~= nil and self:CanUse(_E, "Combo") and myHero:GetSpellData(_E).name == "IreliaE2" and self:CastingChecks() and myHero.attackData.state ~= 2 then
        local pred = _G.PremiumPrediction:GetPrediction(myHero, e2target, ESpellData)
        if pred.CastPos and pred.HitChance >= self.Menu.combo.ecombohc:Value() then
            Control.CastSpell(HK_E, pred.CastPos)
        end
    end
end

function Irelia:RCombo()
    local RTarget = GetTarget(RRange)
    if RTarget ~= nil and self:CanUse(_R, "Combo") and GetEnemyCount(300, RTarget) >= self.Menu.combo.rcombocount:Value() and not BuffActive(RTarget, PassiveMark) and not IsReady(_E) then
        local pred = _G.PremiumPrediction:GetPrediction(myHero, RTarget, RSpellData)
        if pred.CastPos and pred.HitChance >= self.Menu.combo.rcombohc:Value() and self:CastingChecks() and myHero.attackData.state ~= 2 then
                Control.CastSpell(HK_R, pred.CastPos)
        end
    end
end

function Irelia:QLaneClear(minion)
    if ValidTarget(minion, QRange) and self:CanUse(_Q, "LaneClear") then
        local QDam = getdmg("Q", minion, myHero, 2, myHero:GetSpellData(_Q).level)
        if minion.health <= QDam and self:CastingChecks() and myHero.attackData.state ~= 2 then
            if IsUnderEnemyTurret(minion.pos) then
                local allyminions = _G.SDK.ObjectManager:GetAllyMinions(QRange + 300)
                for i = 1, #allyminions do
                    local allyminion = allyminions[i]
                    if IsValid(allyminion) and IsUnderEnemyTurret(allyminion.pos) then
                        Control.CastSpell(HK_Q, minion)
                    end
                end
            else
                Control.CastSpell(HK_Q, minion)
            end
        end
    end
end

function Irelia:QLastHit(minion)
    if ValidTarget(minion, QRange) and self:CanUse(_Q, "LastHit") then
        local QDam = getdmg("Q", minion, myHero, 2, myHero:GetSpellData(_Q).level)
        if minion.health <= QDam and self:CastingChecks() and myHero.attackData.state ~= 2 then
            if IsUnderEnemyTurret(minion.pos) then
                local allyminions = _G.SDK.ObjectManager:GetAllyMinions(QRange + 300)
                for i = 1, #allyminions do
                    local allyminion = allyminions[i]
                    if IsValid(allyminion) and IsUnderEnemyTurret(allyminion.pos) then
                        Control.CastSpell(HK_Q, minion)
                    end
                end
            else
                Control.CastSpell(HK_Q, minion)
            end
        end
    end
end


function Irelia:WKill()
    local wtarget = GetTarget(WRange)
    if wtarget ~= nil and self:CanUse(_W, "Combo") and wtarget.health / wtarget.maxHealth <= 0.5 then
        local QDam = getdmg("Q", wtarget, myHero, 1, myHero:GetSpellData(_Q).level)
        local WDam = getdmg("W", wtarget, myHero, myHero:GetSpellData(_W).level)
        local fulldam = QDam * 2 + WDam
        if wtarget.health <= fulldam and self:CastingChecks() and myHero.attackData.state ~= 2 then
            local pred = _G.PremiumPrediction:GetPrediction(myHero, wtarget, WSpellData)
            if pred.CastPos and pred.HitChance >= 0.5 then
                Control.CastSpell(HK_W, pred.CastPos)
            end
        end
    end
end

function Irelia:MoveHelper(unit)
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
        elseif self.Menu.misc.meleehelper:Value() and GetDistance(myHero.pos, unit.pos) <= AARange-50 and (Mode() == "Combo" or Mode() == "Harass") and self:CastingChecks() and MouseDistance < 750 then
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
