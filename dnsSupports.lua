require "GGPrediction"
require "DamageLib"
require "2DGeometry"
require "MapPositionGOS"


local EnemyHeroes = {}
local AllyHeroes = {}
local EnemySpawnPos = nil
local AllySpawnPos = nil

--do--
    
    --local Version = 1.4
    
    --local Files = {
        --Lua = {
            --Path = SCRIPT_PATH,
            --Name = "dnsSupports.lua",
            --Url = "https://raw.githubusercontent.com/fkndns/dnsSupports/main/dnsSupports.lua"
       --},
        --Version = {
            --Path = SCRIPT_PATH,
            --Name = "dnsSupports.version",
            --Url = "https://raw.githubusercontent.com/fkndns/dnsSupports/main/dnsSupports.version"    -- check if Raw Adress correct pls.. after you have create the version file on Github
        --}
    --}
    
    --local function AutoUpdate()
        
        --local function DownloadFile(url, path, fileName)
            --DownloadFileAsync(url, path .. fileName, function() end)
            --while not FileExist(path .. fileName) do end
        --end
        
        --local function ReadFile(path, fileName)
            --local file = io.open(path .. fileName, "r")
            --local result = file:read()
            --file:close()
            --return result
        --end
        
        --DownloadFile(Files.Version.Url, Files.Version.Path, Files.Version.Name)
        --local textPos = myHero.pos:To2D()
        --local NewVersion = tonumber(ReadFile(Files.Version.Path, Files.Version.Name))
        --if NewVersion > Version then
            --DownloadFile(Files.Lua.Url, Files.Lua.Path, Files.Lua.Name)
            --print("New dnsMarksmen Version. Press 2x F6")     -- <-- you can change the massage for users here !!!!
        --else
            --print(Files.Version.Name .. ": No Updates Found")   --  <-- here too
        --end
    
    --end
    
    --AutoUpdate()

--end --

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

local function MMCast(pos, spell)
        local MMSpot = Vector(pos):ToMM()
        local MouseSpotBefore = mousePos
        Control.SetCursorPos(MMSpot.x, MMSpot.y)
        Control.KeyDown(spell); Control.KeyUp(spell)
        DelayAction(function() Control.SetCursorPos(MouseSpotBefore) end, 0.20)
end

class "Manager"

function Manager:__init()
    if myHero.charName == "Lulu" then
        DelayAction(function () self:LoadLulu() end, 1.05)
    end
end

function Manager:LoadLulu()
    Lulu:Spells()
    Lulu:Menu()
    Callback.Add("Tick", function() Lulu:Tick() end)
    Callback.Add("Draw", function() Lulu:Draws() end)
end

class "Lulu"

local WBuffs = {
    ["Ashe"] = {"AsheQ"},
    ["Hecarim"] = {"HecarimRamp"},
    ["Kaisa"] = {"KaisaE"},
    ["Kayle"] = {"KayleE"},
    ["Kennen"] = {"KennenShurikenStorm"},
    ["KogMaw"] = {"KogMawBioArcaneBarrage"},
    ["MasterYi"] = {"Highlander"},
    ["Quinn"] = {"QuinnE"},
    ["Rammus"] = {"PowerBall"},
    ["Rengar"] = {"RengarR"},
    ["Samira"] = {"SamiraE"},
    ["Singed"] = {"InsanityPotion"},
    ["Skarner"] = {"SkarnerImpale"},
    ["Tristana"] = {"TristanaE"},
    ["Twitch"] = {"TwitchFullAutomatic"},
    ["Varus"] = {"VarusR"},
    ["Vayne"] = {"VayneInquisition"},
    ["Xayah"] = {"XayahW"},
}

local EnemyLoaded = false
local AllyLoaded = false

-- Icons
local ChampIcon = "https://www.proguides.com/public/media/rlocal/champion/thumbnail/117.png"
local QIcon = "https://www.proguides.com/public/media/rlocal/champion/ability/thumbnail/LuluQ.png"
local WIcon = "https://www.proguides.com/public/media/rlocal/champion/ability/thumbnail/LuluW.png"
local EIcon = "https://www.proguides.com/public/media/rlocal/champion/ability/thumbnail/LuluE.png"
local RIcon = "https://www.proguides.com/public/media/rlocal/champion/ability/thumbnail/LuluR.png"
--Ranges
local AARange = 550
local QRange = 925
local WRange = 650
local ERange = 650
local RRange = 900

-- Buffs


function Lulu:Menu()
    self.Menu = MenuElement({type = MENU, id = "lulu", name = "dnsLulu", leftIcon = ChampIcon})

    -- combo
    self.Menu:MenuElement({id = "combo", name = "Combo", type = MENU})
    self.Menu.combo:MenuElement({id = "qcombo", name = "Use [Q] in Combo", value = true, leftIcon = QIcon})
    self.Menu.combo:MenuElement({id = "qcombohc", name = "[Q] HitChance", value = 2, drop = {"Normal", "High", "Immobile"}, leftIcon = QIcon})
    self.Menu.combo:MenuElement({id = "wcombo", name = "Use [W] in Combo", value = true, leftIcon = WIcon})
    self.Menu.combo:MenuElement({id = "rcombo", name = "Use [R] in Combo", value = true, leftIcon = RIcon})
    self.Menu.combo:MenuElement({id = "rcombocount", name = "[R] HitCount", value = 3, min = 1, max = 5, step = 1, leftIcon = RIcon})
    self.Menu.combo:MenuElement({id = "rcomboallies", name = "Use [R] on:", type = MENU, leftIcon = RIcon})

    -- Auto
    self.Menu:MenuElement({id = "auto", name = "Auto", type = MENU})
    self.Menu.auto:MenuElement({id = "qks", name = "Use [Q] KS", value = false, leftIcon = QIcon})
    self.Menu.auto:MenuElement({id = "wbuff", name = "Use [W] Buff", value = true, leftIcon = WIcon})
    self.Menu.auto:MenuElement({id = "winterrupt", name = "Use [W] Interrupt", value = true, leftIcon = WIcon})
    self.Menu.auto:MenuElement({id = "eauto", name = "Use [E] Shield", value = true, leftIcon = EIcon})
    self.Menu.auto:MenuElement({id = "eautohp", name = "[E] HP <=", value = 80, min = 5, max = 100, step = 5, identifier = "%", leftIcon = EIcon})
    self.Menu.auto:MenuElement({id = "eautoallies", name = "Use [E] on:", type = MENU, leftIcon = EIcon})
    self.Menu.auto:MenuElement({id = "rauto", name = "Use [R] Shield", value = true, leftIcon = RIcon})
    self.Menu.auto:MenuElement({id = "rautohp", name = "[R] HP <=", value = 30, min = 5, max = 100, step = 5, identifier = "%", leftIcon = RIcon})
    self.Menu.auto:MenuElement({id = "rautoallies", name = "Use [R] on:", type = MENU, leftIcon = RIcon})

    -- Draw
    self.Menu:MenuElement({id = "draws", name = "Draws", type = MENU})
    self.Menu.draws:MenuElement({id = "qdraw", name = "Draw [Q] Range", value = false, leftIcon = QIcon})
    self.Menu.draws:MenuElement({id = "wedraw", name = "Draw [W] / [E] Range", value = false, leftIcon = WIcon, rightIcon = EIcon})
    self.Menu.draws:MenuElement({id = "rdraw", name = "Draw [R] Range", value = false, leftIcon = RIcon})
end

function Lulu:ActiveMenu()
    for i, ally in pairs(AllyHeroes) do
        self.Menu.combo.rcomboallies:MenuElement({id = ally.charName, name = ally.charName, value = true})
        self.Menu.auto.eautoallies:MenuElement({id = ally.charName, name = ally.charName, value = true})
        self.Menu.auto.rautoallies:MenuElement({id = ally.charName, name = ally.charName, value = true})
    end
end

function Lulu:Draws()
    if self.Menu.draws.qdraw:Value() then
        Draw.Circle(myHero, QRange, 1, Draw.Color(255, 255, 255, 0))
    end
    if self.Menu.draws.wedraw:Value() then
        Draw.Circle(myHero, WRange, 1, Draw.Color(255, 0, 255, 0))
    end
    if self.Menu.draws.rdraw:Value() then
        Draw.Circle(myHero, RRange, 1, Draw.Color(255, 255, 0, 0))
    end
end

function Lulu:Spells()
    QSpell = GGPrediction:SpellPrediction({Delay = 0.25, Radius = 80, Range = QRange, Speed = 1400, Collision = false, Type = GGPrediction.SPELLTYPE_LINE})
end

function Lulu:Tick()
    if _G.JustEvade and _G.JustEvade:Evading() or (_G.ExtLibEvade and _G.ExtLibEvade.Evading) or Game.IsChatOpen() or myHero.dead then return end

    target = GetTarget(AARange)
    CastingQ = myHero.activeSpell.name == "LuluQ"
    CastingW = myHero.activeSpell.name == "LuluW"
    CastingE = myHero.activeSpell.name == "LuluE"
    CastingR = myHero.activeSpell.name == "LuluR"
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
end

function Lulu:CastingChecks()
    if not CastingQ and not CastingW and not CastingE and not CastingR then
        return true
    else
        return false
    end
end

function Lulu:CanUse(spell, mode)
    if mode == nil then
        mode = Mode()
    end

    if spell == _Q then
        if mode == "Combo" and IsReady(_Q) and self.Menu.combo.qcombo:Value() then
            return true
        end
        if mode == "KS" and IsReady(_Q) and self.Menu.auto.qks:Value() then
            return true
        end
    end
    if spell == _W then
        if mode == "Combo" and IsReady(_W) and self.Menu.combo.wcombo:Value() then
            return true
        end
        if mode == "Buff" and IsReady(_W) and self.Menu.auto.wbuff:Value() then
            return true
        end
        if mode == "Interrupt" and IsReady(_W) and self.Menu.auto.winterrupt:Value() then
            return true
        end
    end
    if spell == _E then
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


function Lulu:Logic()
    self:TurretShield()
    if Mode() == "Combo" then
        self:ComboQ()
    end
end

function Lulu:Auto()
    for i, enemy in pairs(EnemyHeroes) do
        self:QKS(enemy)
        self:WInterrupt(enemy)
        self:WDash(enemy)
        self:EShieldSelf(enemy)
        self:RShieldSelf(enemy)
        if Mode() == "Combo" then
            self:WComboSelf(enemy)
        end
        for j, ally in pairs(AllyHeroes) do
            self:WBuff(ally)
            self:EShieldAlly(enemy, ally)
            self:RShieldAlly(enemy, ally)
            self:TurretShieldAlly(ally)
            if Mode() == "Combo" then
                self:ComboR(enemy, ally)
                self:WComboAlly(enemy, ally)
            end
        end
    end
end


-- [functions] --

function Lulu:ComboQ()
    local qtarget = GetTarget(QRange)
    if ValidTarget(qtarget, QRange) and self:CanUse(_Q, "Combo") and self:CastingChecks() and myHero.attackData.state ~= 2 then
        QSpell:GetPrediction(qtarget, myHero)
        if QSpell:CanHit(self.Menu.combo.qcombohc:Value() + 1) then
            Control.CastSpell(HK_Q, QSpell.CastPosition)
        end
    end
end

function Lulu:ComboR(enemy, ally) 
    if ValidTarget(ally, RRange) and self:CanUse(_R, "Combo") and self:CastingChecks() and myHero.attackData.state ~= 2 and self.Menu.combo.rcomboallies[ally.charName]:Value() and GetEnemyCount(250, ally) >= self.Menu.combo.rcombocount:Value() then
        Control.CastSpell(HK_R, ally)
    end
end

function Lulu:QKS(enemy)
    if ValidTarget(enemy, QRange) and self:CanUse(_Q, "KS") and self:CastingChecks() and myHero.attackData.state ~= 2 then
        local QDam = getdmg("Q", enemy, myHero, myHero:GetSpellData(_Q).level)
        if enemy.health <= QDam then
            QSpell:GetPrediction(enemy, myHero)
            if QSpell:CanHit(HITCHANCE_HIGH) then
                Control.CastSpell(HK_Q, QSpell.CastPosition)
            end
        end
    end
end

function Lulu:WComboSelf(enemy)
    if ValidTarget(enemy, WRange) and self:CanUse(_W, "Combo") and self:CastingChecks() and myHero.attackData.state ~= 2 and enemy.activeSpell.valid and not enemy.activeSpell.isStopped then
        if enemy.activeSpell.target == myHero.handle then
            Control.CastSpell(HK_W, enemy)
        else
            local placementPos = enemy.activeSpell.placementPos
            local width = myHero.boundingRadius + 50
            if enemy.activeSpell.width > 0 then width = width + enemy.activeSpell.width end
            local spellLine = ClosestPointOnLineSegment(myHero.pos, enemy.pos, placementPos)
            if GetDistance(myHero.pos, spellLine) <= width then
                Control.CastSpell(HK_W, enemy)
            end
        end
    end
end

function Lulu:WComboAlly(enemy, ally)
    if ValidTarget(ally) and ValidTarget(enemy, WRange) and self:CanUse(_W, "Combo") and self:CastingChecks() and myHero.attackData.state ~= 2 and enemy.activeSpell.valid and not enemy.activeSpell.isStopped then
        if enemy.activeSpell.target == ally.handle then
            Control.CastSpell(HK_W, enemy)
        else
            local placementPos = enemy.activeSpell.placementPos
            local width = ally.boundingRadius + 50
            if enemy.activeSpell.width > 0 then width = width + enemy.activeSpell.width end
            local spellLine = ClosestPointOnLineSegment(ally.pos, enemy.pos, placementPos)
            if GetDistance(ally.pos, spellLine) <= width then
                Control.CastSpell(HK_W, enemy)
            end
        end
    end
end

function Lulu:WBuff(ally)
    if ValidTarget(ally, WRange) and self:CanUse(_W, "Buff") and self:CastingChecks() and myHero.attackData.state ~= 2 and ally.activeSpell.valid then
        local t = WBuffs[ally.charName] 
        if t then
            for i = 1, #t do
                if ally.activeSpell.name == t[i] then
                    Control.CastSpell(HK_W, ally)
                end
            end
        end
    end
end

function Lulu:WInterrupt(enemy)
    local Timer = Game.Timer()
    if ValidTarget(enemy, WRange) and self:CanUse(_W, "Interrupt") and self:CastingChecks() and myHero.attackData.state ~= 2 and enemy.activeSpell.valid and not enemy.activeSpell.isStopped and enemy.activeSpell.castEndTime - Timer > 0.4 then
        Control.CastSpell(HK_W, enemy)
    end
end

function Lulu:WDash(enemy)
    if ValidTarget(enemy, WRange) and self:CanUse(_W, "Interrupt") and self:CastingChecks() and myHero.attackData.state ~= 2 then
        if enemy.pathing.isDashing then
            if GetDistance(myHero.pos, enemy.pathing.endPos) < GetDistance(myHero.pos, enemy.pos) then
                Control.CastSpell(HK_W, enemy)
            end
        end
    end
end

function Lulu:EShieldAlly(enemy, ally)
    if ValidTarget(ally, ERange) and self:CanUse(_E, "Auto") and self:CastingChecks() and myHero.attackData.state ~= 2 and self.Menu.auto.eautoallies[ally.charName]:Value() and enemy.activeSpell.valid and not enemy.activeSpell.isStopped and ally.health / ally.maxHealth <= self.Menu.auto.eautohp:Value() / 100 then
        if enemy.activeSpell.target == ally.handle then
            Control.CastSpell(HK_E, ally)
        else
            local placementPos = enemy.activeSpell.placementPos
            local width = ally.boundingRadius + 50
            if enemy.activeSpell.width > 0 then width = width + enemy.activeSpell.width end
            local spellLine = ClosestPointOnLineSegment(ally.pos, enemy.pos, placementPos)
            if GetDistance(ally.pos, spellLine) <= width then
                Control.CastSpell(HK_E, ally)
            end
        end
    end
end

function Lulu:EShieldSelf(enemy)
    if ValidTarget(enemy) and self:CanUse(_E, "Auto") and self:CastingChecks() and myHero.attackData.state ~= 2 and enemy.activeSpell.valid and not enemy.activeSpell.isStopped and myHero.health / myHero.maxHealth <= self.Menu.auto.eautohp:Value() / 100 then
        if enemy.activeSpell.target == myHero.handle then
            Control.CastSpell(HK_E, myHero)
        else
            local placementPos = enemy.activeSpell.placementPos
            local width = myHero.boundingRadius + 50
            if enemy.activeSpell.width > 0 then width = width + enemy.activeSpell.width end
            local spellLine = ClosestPointOnLineSegment(myHero.pos, enemy.pos, placementPos)
            if GetDistance(myHero.pos, spellLine) <= width then
                Control.CastSpell(HK_E, myHero)
            end
        end
    end
end

function Lulu:TurretShield()
    if self:CanUse(_E, "Auto") and GetTurretShot(myHero) and self:CastingChecks() and myHero.attackData.state ~= 2 and myHero.health / myHero.maxHealth <= self.Menu.auto.eautohp:Value() / 100 then
        Control.CastSpell(HK_E, myHero)
    end
end

function Lulu:TurretShieldAlly(ally)
    if ValidTarget(ally, ERange) and self:CanUse(_E, "Auto") and GetTurretShot(ally) and self:CastingChecks() and myHero.attackData.state ~= 2 and ally.health / ally.maxHealth <= self.Menu.auto.eautohp:Value() / 100 then
        Control.CastSpell(HK_E, ally)
    end
end

function Lulu:RShieldSelf(enemy)
    if ValidTarget(enemy) and self:CanUse(_R, "Auto") and self:CastingChecks() and myHero.attackData.state ~= 2 and enemy.activeSpell.valid and not enemy.activeSpell.isStopped and myHero.health / myHero.maxHealth <= self.Menu.auto.rautohp:Value() / 100 then
        if enemy.activeSpell.target == myHero.handle then
            Control.CastSpell(HK_R, myHero)
        else
            local placementPos = enemy.activeSpell.placementPos
            local width = myHero.boundingRadius + 50
            if enemy.activeSpell.width > 0 then width = width + enemy.activeSpell.width end
            local spellLine = ClosestPointOnLineSegment(myHero.pos, enemy.pos, placementPos)
            if GetDistance(myHero.pos, spellLine) <= width then
                Control.CastSpell(HK_R, myHero)
            end
        end
    end
end

function Lulu:RShieldAlly(enemy, ally)
    if ValidTarget(ally, RRange) and self:CanUse(_R, "Auto") and self:CastingChecks() and myHero.attackData.state ~= 2 and self.Menu.auto.rautoallies[ally.charName]:Value() and enemy.activeSpell.valid and not enemy.activeSpell.isStopped and ally.health / ally.maxHealth <= self.Menu.auto.rautohp:Value() / 100 then
        if enemy.activeSpell.target == ally.handle then
            Control.CastSpell(HK_R, ally)
        else
            local placementPos = enemy.activeSpell.placementPos
            local width = ally.boundingRadius + 50
            if enemy.activeSpell.width > 0 then width = width + enemy.activeSpell.width end
            local spellLine = ClosestPointOnLineSegment(ally.pos, enemy.pos, placementPos)
            if GetDistance(ally.pos, spellLine) <= width then
                Control.CastSpell(HK_R, ally)
            end
        end
    end
end

function OnLoad()
    Manager()
end
