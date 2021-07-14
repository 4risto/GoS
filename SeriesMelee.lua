require "PremiumPrediction"
require "GamsteronPrediction"
require "DamageLib"
require "2DGeometry"
require "MapPositionGOS"

_G.QHelperActive = false
_G.AatroxQType = 0

local EnemyHeroes = {}
local AllyHeroes = {}
-- [ AutoUpdate ] --
do
    
    local Version = 200.00
    
    local Files = {
        Lua = {
            Path = SCRIPT_PATH,
            Name = "SeriesMelee.lua",
            Url = "https://raw.githubusercontent.com/Impulsx/Series/master/SeriesMelee.lua"
        },
        Version = {
            Path = SCRIPT_PATH,
            Name = "SeriesMelee.version",
            Url = "https://raw.githubusercontent.com/Impulsx/Series/master/SeriesMelee.version"    -- check if Raw Adress correct pls.. after you have create the version file on Github
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
            print("New Series Version. Press 2x F6")     -- <-- you can change the massage for users here !!!!
        else
            print(Files.Version.Name .. ": No Updates Found")   --  <-- here too
        end
    
    end
    
    AutoUpdate()

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

function GetDistanceSqr(Pos1, Pos2)
    local Pos2 = Pos2 or myHero.pos
    local dx = Pos1.x - Pos2.x
    local dz = (Pos1.z or Pos1.y) - (Pos2.z or Pos2.y)
    return dx^2 + dz^2
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

function GetAllyHeroes()
    for i = 1, Game.HeroCount() do
        local Hero = Game.Hero(i)
        if Hero.isAlly then
            table.insert(AllyHeroes, Hero)
            PrintChat(Hero.name)
        end
    end
    --PrintChat("Got Enemy Heroes")
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

function SetMovement(bool)
    if _G.PremiumOrbwalker then
        _G.PremiumOrbwalker:SetAttack(bool)
        _G.PremiumOrbwalker:SetMovement(bool)       
    elseif _G.SDK then
        _G.SDK.Orbwalker:SetMovement(bool)
        _G.SDK.Orbwalker:SetAttack(bool)
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
class "Manager"

function Manager:__init()
    if myHero.charName == "Kled" then
        DelayAction(function() self:LoadKled() end, 1.05)
    elseif myHero.charName == "Aatrox" then
        DelayAction(function() self:LoadAatrox() end, 1.05)
    elseif myHero.charName == "Lillia" then
        DelayAction(function() self:LoadLillia() end, 1.05)
    elseif myHero.charName == "Yone" then
        DelayAction(function() self:LoadYone() end, 1.05)
    elseif myHero.charName == "Rengar" then
        DelayAction(function() self:LoadRengar() end, 1.05)
    elseif myHero.charName == "Jax" then
        DelayAction(function() self:LoadJax() end, 1.05)
    elseif myHero.charName == "Darius" then
        DelayAction(function() self:LoadDarius() end, 1.05)
    end
end


function Manager:LoadKled()
    Kled:Spells()
    Kled:Menu()
    --
    --GetEnemyHeroes()
    Callback.Add("Tick", function() Kled:Tick() end)
    Callback.Add("Draw", function() Kled:Draw() end)
    if _G.SDK then
        _G.SDK.Orbwalker:OnPreAttack(function(...) Kled:OnPreAttack(...) end)
        _G.SDK.Orbwalker:OnPostAttackTick(function(...) Kled:OnPostAttackTick(...) end)
        _G.SDK.Orbwalker:OnPostAttack(function(...) Kled:OnPostAttack(...) end)
    end
end

function Manager:LoadJax()
    Jax:Spells()
    Jax:Menu()
    --
    --GetEnemyHeroes()
    Callback.Add("Tick", function() Jax:Tick() end)
    Callback.Add("Draw", function() Jax:Draw() end)
    if _G.SDK then
        _G.SDK.Orbwalker:OnPreAttack(function(...) Jax:OnPreAttack(...) end)
        _G.SDK.Orbwalker:OnPostAttackTick(function(...) Jax:OnPostAttackTick(...) end)
        _G.SDK.Orbwalker:OnPostAttack(function(...) Jax:OnPostAttack(...) end)
    end
end

function Manager:LoadAatrox()
    Aatrox:Spells()
    Aatrox:Menu()
    --
    --GetEnemyHeroes()
    Callback.Add("Tick", function() Aatrox:Tick() end)
    Callback.Add("Draw", function() Aatrox:Draw() end)
    if _G.SDK then
        _G.SDK.Orbwalker:OnPreAttack(function(...) Aatrox:OnPreAttack(...) end)
        _G.SDK.Orbwalker:OnPostAttackTick(function(...) Aatrox:OnPostAttackTick(...) end)
        _G.SDK.Orbwalker:OnPostAttack(function(...) Aatrox:OnPostAttack(...) end)
    end
end


function Manager:LoadLillia()
    Lillia:Spells()
    Lillia:Menu()
    --
    --GetEnemyHeroes()
    Callback.Add("Tick", function() Lillia:Tick() end)
    Callback.Add("Draw", function() Lillia:Draw() end)
    if _G.SDK then
        _G.SDK.Orbwalker:OnPreAttack(function(...) Lillia:OnPreAttack(...) end)
        _G.SDK.Orbwalker:OnPostAttackTick(function(...) Lillia:OnPostAttackTick(...) end)
        _G.SDK.Orbwalker:OnPostAttack(function(...) Lillia:OnPostAttack(...) end)
    end
end

function Manager:LoadYone()
    Yone:Spells()
    Yone:Menu()
    --
    --GetEnemyHeroes()
    Callback.Add("Tick", function() Yone:Tick() end)
    Callback.Add("Draw", function() Yone:Draw() end)
    if _G.SDK then
        _G.SDK.Orbwalker:OnPreAttack(function(...) Yone:OnPreAttack(...) end)
        _G.SDK.Orbwalker:OnPostAttackTick(function(...) Yone:OnPostAttackTick(...) end)
        _G.SDK.Orbwalker:OnPostAttack(function(...) Yone:OnPostAttack(...) end)
    end
end

function Manager:LoadRengar()
    Rengar:Spells()
    Rengar:Menu()
    --
    --GetEnemyHeroes()
    Callback.Add("Tick", function() Rengar:Tick() end)
    Callback.Add("Draw", function() Rengar:Draw() end)
    if _G.SDK then
        _G.SDK.Orbwalker:OnPreAttack(function(...) Rengar:OnPreAttack(...) end)
        _G.SDK.Orbwalker:OnPostAttackTick(function(...) Rengar:OnPostAttackTick(...) end)
        _G.SDK.Orbwalker:OnPostAttack(function(...) Rengar:OnPostAttack(...) end)
    end
end

function Manager:LoadDarius()
    Darius:Spells()
    Darius:Menu()
    --
    --GetEnemyHeroes()
    Callback.Add("Tick", function() Darius:Tick() end)
    Callback.Add("Draw", function() Darius:Draw() end)
    if _G.SDK then
        _G.SDK.Orbwalker:OnPreAttack(function(...) Darius:OnPreAttack(...) end)
        _G.SDK.Orbwalker:OnPostAttackTick(function(...) Darius:OnPostAttackTick(...) end)
        _G.SDK.Orbwalker:OnPostAttack(function(...) Darius:OnPostAttack(...) end)
    end
end


class "Yone"

local EnemyLoaded = false
local TargetTime = 0

local CastingQ = false
local CastingW = false
local CastingE = false
local CastingR = false
local Item_HK = {}

local WasInRange = false

local ForceTarget = nil

local EBuff = false
local Q2Buff = false

local PostAttack = false
local LastSpellName = ""

local Etarget = nil
local LastCastDamage = 0
local EdmgRecv = 0
local Edmg = 0
local LastTargetHealth = 0
local Added = false
local EdmgFinal = 0


local QRange = 475
local Q2Range = 950
local WRange = 600
local RRange = 1000
local AARange = 0



local CastedW = false
local TickW = false
local CastedQ = false
local TickQ = false
local CastedR = false
local TickR = false

local ENeeded = false


local RStackTime = Game.Timer()
local LastRstacks = 0

local ARStackTime = Game.Timer()
local ALastRstacks = 0
local ALastTickTarget = myHero

function Yone:Menu()
    self.Menu = MenuElement({type = MENU, id = "Yone", name = "Yone"})
    self.Menu:MenuElement({id = "ComboMode", name = "Combo", type = MENU})
    self.Menu.ComboMode:MenuElement({id = "UseQ", name = "(Q) Use Q", value = true})
    self.Menu.ComboMode:MenuElement({id = "UseQ2HitChance", name = "(Q2) HitChance (0=Fire Often, 1=Immobile)", value = 0, min = 0, max = 1.0, step = 0.05})
    self.Menu.ComboMode:MenuElement({id = "UseW", name = "(W) Enabled", value = true})
    self.Menu.ComboMode:MenuElement({id = "UseE1", name = "(E1) Use E-R When Killable", value = true})
    self.Menu.ComboMode:MenuElement({id = "UseESmallCombo", name = "(E1) Use E When Killable", value = true})
    self.Menu.ComboMode:MenuElement({id = "UseESmallPercent", name = "(E1) % of Combo Damage To Use (E1)", value = 60, min = 1, max = 100, step = 1})
    self.Menu.ComboMode:MenuElement({id = "UseE", name = "(E2) Recall E To Finish Kills", value = true})
    self.Menu.ComboMode:MenuElement({id = "UseEPercent", name = "(E2) % of Combo Damage To Use (E2)", value = 70, min = 1, max = 100, step = 1})
    self.Menu.ComboMode:MenuElement({id = "UseR", name = "(R) Enabled", value = true})
    self.Menu.ComboMode:MenuElement({id = "UseRNum", name = "(R) Number Of Targets", value = 2, min = 1, max = 5, step = 1})
    self.Menu.ComboMode:MenuElement({id = "UseRComboFinish", name = "(R) In Combo When Killable", value = true})
    self.Menu.ComboMode:MenuElement({id = "UseRComboFinishDamage", name = "(R) % of Combo Damage To Use (R)", value = 70, min = 1, max = 100, step = 1})
    self.Menu.ComboMode:MenuElement({id = "UseRFinish", name = "(R) To Finish A Single Target", value = true})
    self.Menu.ComboMode:MenuElement({id = "UseRHitChance", name = "(R) HitChance (0=Fire Often, 1=Immobile)", value = 0, min = 0, max = 1.0, step = 0.05})
    self.Menu:MenuElement({id = "HarassMode", name = "Harass", type = MENU})
    self.Menu.HarassMode:MenuElement({id = "UseQ", name = "(Q) use Q", value = false})
    self.Menu.HarassMode:MenuElement({id = "UseW", name = "(W) use W", value = false})
    self.Menu:MenuElement({id = "AutoMode", name = "Auto", type = MENU})
    self.Menu:MenuElement({id = "Draw", name = "Draw", type = MENU})
    self.Menu.Draw:MenuElement({id = "UseDraws", name = "Enable Draws", value = false})
    self.Menu.Draw:MenuElement({id = "DrawAA", name = "Draw AA range", value = false})
    self.Menu.Draw:MenuElement({id = "DrawQ", name = "Draw Q range", value = false})
    self.Menu.Draw:MenuElement({id = "DrawW", name = "Draw W range", value = false})
    self.Menu.Draw:MenuElement({id = "DrawR", name = "Draw R range", value = false})
    self.Menu.Draw:MenuElement({id = "DrawBurstDamage", name = "Burst Damage", value = false})
    self.Menu.Draw:MenuElement({id = "DrawEDamage", name = "Draw E damage", value = false})
end

function Yone:Spells()
    --local Erange = self.Menu.ComboMode.UseEDistance:Value()
    QSpellData = {speed = 1550, range = 475, delay = 0.4, radius = 80, collision = {""}, type = "linear"}
    Q2SpellData = {speed = 1550, range = 950, delay = 0.4, radius = 120, collision = {""}, type = "linear"}
    RSpellData = {speed = 1550, range = 1000, delay = 0.75, radius = 120, collision = {""}, type = "linear"}

    WSpellData = {speed = math.huge, range = 600, delay = 0.5, angle = 80, radius = 0, collision = {}, type = "conic"}
end


function Yone:Draw()
    if self.Menu.Draw.UseDraws:Value() then
        local AARange = _G.SDK.Data:GetAutoAttackRange(myHero)
        if self.Menu.Draw.DrawAA:Value() then
            Draw.Circle(myHero.pos, AARange, 1, Draw.Color(255, 0, 191, 0))
        end
        if self.Menu.Draw.DrawQ:Value() then
            Draw.Circle(myHero.pos, QRange, 1, Draw.Color(255, 255, 0, 255))
        end
        if self.Menu.Draw.DrawW:Value() then
            Draw.Circle(myHero.pos, WRange, 1, Draw.Color(255, 255, 0, 255))
        end
        if self.Menu.Draw.DrawR:Value() then
            Draw.Circle(myHero.pos, RRange, 1, Draw.Color(255, 255, 0, 255))
        end
        if self.Menu.Draw.DrawBurstDamage:Value() then
            for i, enemy in pairs(EnemyHeroes) do
                if enemy and not enemy.dead and ValidTarget(enemy, 2000) then
                    local BurstDamage = math.floor(self:GetAllDamage(enemy))
                    if not self:CanUse(_R, "Force") then 
                        BurstDamage = math.floor(self:GetAllDamage(enemy, "E"))
                    end

                    local EnemyHealth = math.floor(enemy.health)
                    if BurstDamage > EnemyHealth then
                        Draw.Text("Total Dmg:" .. BurstDamage .. "/" .. EnemyHealth, 15, enemy.pos:To2D().x-15, enemy.pos:To2D().y-125, Draw.Color(255, 0, 255, 0))
                    elseif BurstDamage*1.3 > EnemyHealth then
                        Draw.Text("Total Dmg:" .. BurstDamage .. "/" .. EnemyHealth, 15, enemy.pos:To2D().x-15, enemy.pos:To2D().y-125, Draw.Color(255, 255, 150, 150))
                    else
                        Draw.Text("Total Dmg:" .. BurstDamage .. "/" .. EnemyHealth, 15, enemy.pos:To2D().x-15, enemy.pos:To2D().y-125, Draw.Color(255, 255, 0, 0))
                    end
                end
            end
        end
        if self.Menu.Draw.DrawEDamage:Value() and target and not target.dead and ValidTarget(target, 2000) and EBuff then
            local EDamage = math.floor(EdmgFinal)
            local EnemyHealth = math.floor(target.health)
            if EDamage then
                if EDamage > EnemyHealth then
                    Draw.Text("E Dmg:" .. EDamage .. "/" .. EnemyHealth, 15, target.pos:To2D().x-15, target.pos:To2D().y-110, Draw.Color(255, 255, 255, 255))
                elseif EDamage*1.3 > EnemyHealth then
                    Draw.Text("E Dmg:" .. EDamage .. "/" .. EnemyHealth, 15, target.pos:To2D().x-15, target.pos:To2D().y-110, Draw.Color(255, 150, 70, 70))
                else
                    Draw.Text("E Dmg:" .. EDamage .. "/" .. EnemyHealth, 15, target.pos:To2D().x-15, target.pos:To2D().y-110, Draw.Color(255, 170, 0, 0))
                end
            end
        end
    end
end

function Yone:GetAllDamage(unit, extra)
    local Qdmg = getdmg("Q", unit, myHero)
    local Wdmg = getdmg("W", unit, myHero) + getdmg("W", unit, myHero, 2)
    local Rdmg = getdmg("R", unit, myHero) + getdmg("R", unit, myHero, 2)
    local CritChance = myHero.critChance
    local AAdmg = getdmg("AA", unit, myHero) + (getdmg("AA", unit, myHero) * CritChance)
    local TotalDmg = 0
    if self:CanUse(_Q, "Force") then
        TotalDmg = TotalDmg + Qdmg + AAdmg
    end
    if self:CanUse(_W, "Force") then
        TotalDmg = TotalDmg + Wdmg + AAdmg
    end
    if self:CanUse(_R, "Force") then
        TotalDmg = TotalDmg + Rdmg + AAdmg
    end
    if self:CanUse(_E, "Force") or EBuff then
        local EPercent = 0.25 + (0.025*myHero:GetSpellData(_E).level)
        TotalDmg = TotalDmg + (TotalDmg*EPercent)
        ENeeded = true
    else
        ENeeded = false
    end
    if extra and extra == "E" then
        TotalDmg = TotalDmg + AAdmg
    end
    return TotalDmg
end

function Yone:Tick()
    if _G.JustEvade and _G.JustEvade:Evading() or (_G.ExtLibEvade and _G.ExtLibEvade.Evading) or Game.IsChatOpen() or myHero.dead then return end

    target = GetTarget(2000)

    AARange = _G.SDK.Data:GetAutoAttackRange(myHero)
    CastingQ = myHero.activeSpell.name == "YoneQ" or myHero.activeSpell.name == "YoneQ3"
    CastingW = myHero.activeSpell.name == "YoneW"
    CastingE = myHero.activeSpell.name == "YoneE"
    CastingR = myHero.activeSpell.name == "YoneR"

    EBuff = myHero.mana > 1 and myHero.mana < 499

    Q2Buff = GetBuffExpire(myHero, "yoneq3ready")
    --PrintChat(myHero.activeSpell.name)
    self:GetEDamage(target)
    self:UpdateItems()
    self:Logic()
    self:Auto()
    self:Items2()
    self:ProcessSpells()
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


function Yone:UpdateItems()
    Item_HK[ITEM_1] = HK_ITEM_1
    Item_HK[ITEM_2] = HK_ITEM_2
    Item_HK[ITEM_3] = HK_ITEM_3
    Item_HK[ITEM_4] = HK_ITEM_4
    Item_HK[ITEM_5] = HK_ITEM_5
    Item_HK[ITEM_6] = HK_ITEM_6
    Item_HK[ITEM_7] = HK_ITEM_7
end

function Yone:Items1()
    if GetItemSlot(myHero, 3074) > 0 and ValidTarget(target, 300) then --rave 
        if myHero:GetSpellData(GetItemSlot(myHero, 3074)).currentCd == 0 then
            Control.CastSpell(Item_HK[GetItemSlot(myHero, 3074)])
        end
    end
    if GetItemSlot(myHero, 3077) > 0 and ValidTarget(target, 300) then --tiamat
        if myHero:GetSpellData(GetItemSlot(myHero, 3077)).currentCd == 0 then
            Control.CastSpell(Item_HK[GetItemSlot(myHero, 3077)])
        end
    end
    if GetItemSlot(myHero, 3144) > 0 and ValidTarget(target, 550) then --bilge
        if myHero:GetSpellData(GetItemSlot(myHero, 3144)).currentCd == 0 then
            Control.CastSpell(Item_HK[GetItemSlot(myHero, 3144)], target)
        end
    end
    if GetItemSlot(myHero, 3153) > 0 and ValidTarget(target, 550) then -- botrk
        if myHero:GetSpellData(GetItemSlot(myHero, 3153)).currentCd == 0 then
            Control.CastSpell(Item_HK[GetItemSlot(myHero, 3153)], target)
        end
    end
    if GetItemSlot(myHero, 3146) > 0 and ValidTarget(target, 700) then --gunblade hex
        if myHero:GetSpellData(GetItemSlot(myHero, 3146)).currentCd == 0 then
            Control.CastSpell(Item_HK[GetItemSlot(myHero, 3146)], target)
        end
    end
    if GetItemSlot(myHero, 3748) > 0 and ValidTarget(target, 300) then -- Titanic Hydra
        if myHero:GetSpellData(GetItemSlot(myHero, 3748)).currentCd == 0 then
            Control.CastSpell(Item_HK[GetItemSlot(myHero, 3748)])
        end
    end
end

function Yone:Items2()
    if GetItemSlot(myHero, 3139) > 0 then
        if myHero:GetSpellData(GetItemSlot(myHero, 3139)).currentCd == 0 then
            if IsImmobile(myHero) then
                Control.CastSpell(Item_HK[GetItemSlot(myHero, 3139)], myHero)
            end
        end
    end
    if GetItemSlot(myHero, 3140) > 0 then
        if myHero:GetSpellData(GetItemSlot(myHero, 3140)).currentCd == 0 then
            if IsImmobile(myHero) then
                Control.CastSpell(Item_HK[GetItemSlot(myHero, 3140)], myHero)
            end
        end
    end
end

function Yone:GetSleepBuffs(unit, buffname)
    for i = 0, unit.buffCount do
        local buff = unit:GetBuff(i)
        if buff.name == buffname and buff.count > 0 then 
            return buff
        end
    end
    return nil
end

function Yone:Auto()
    for i, enemy in pairs(EnemyHeroes) do
        if enemy and not enemy.dead and ValidTarget(enemy) then
        end
    end
end 


function Yone:CanUse(spell, mode)
    if mode == nil then
        mode = Mode()
    end
    --PrintChat(Mode())
    if spell == _Q then
        if mode == "Combo" and IsReady(spell) and self.Menu.ComboMode.UseQ:Value() then
            return true
        end
        if mode == "Harass" and IsReady(spell) and self.Menu.HarassMode.UseQ:Value() then
            return true
        end

        if mode == "Force" and IsReady(spell) then
            return true
        end
    elseif spell == _R then
        if mode == "Combo" and IsReady(spell) and self.Menu.ComboMode.UseR:Value() then
            return true
        end

        if mode == "Force" and IsReady(spell) then
            return true
        end
    elseif spell == _W then
        if mode == "Combo" and IsReady(spell) and self.Menu.ComboMode.UseW:Value() then
            return true
        end
        if mode == "Harass" and IsReady(spell) and self.Menu.HarassMode.UseW:Value() then
            return true
        end

        if mode == "Force" and IsReady(spell) then
            return true
        end
    elseif spell == _E then
        if mode == "Combo" and IsReady(spell) and self.Menu.ComboMode.UseE:Value() then
            return true
        end
        if mode == "ERCombo" and IsReady(spell) and self.Menu.ComboMode.UseE1:Value() then
            return true
        end
        if mode == "ESmallCombo" and IsReady(spell) and self.Menu.ComboMode.UseESmallCombo:Value() then
            return true
        end
        if mode == "Force" and IsReady(spell) then
            return true
        end
    end
    return false
end


function Yone:Logic()
    if target == nil then 
        if Game.Timer() - TargetTime > 2 then
            WasInRange = false
        end
        return 
    end
    if Mode() == "Combo" or Mode() == "Harass" and target and ValidTarget(target) then
        --PrintChat("Logic")
        TargetTime = Game.Timer()
        self:Items1()

        local QRangeExtra = 0
        if IsFacing(target) then
            QRangeExtra = myHero.ms * 0.2
        end
        if IsImmobile(target) then
            QRangeExtra = myHero.ms * 0.5
        end
        
        if GetDistance(target.pos) < AARange then
            WasInRange = true
        end

        local TargetSleep = self:GetSleepBuffs(target, "YonePDoT")

        if self:CanUse(_E, Mode()) and ValidTarget(target) and EBuff and target.health < EdmgFinal and self:CastingChecks() and not (myHero.pathing and myHero.pathing.isDashing) then
            Control.CastSpell(HK_E)
        end
        if not EBuff and self:CanUse(_E, "ESmallCombo") and ValidTarget(target) and self:CastingChecks() and not (myHero.pathing and myHero.pathing.isDashing) then
            local BurstDamage = self:GetAllDamage(target, "E") * (self.Menu.ComboMode.UseESmallPercent:Value() / 100)
            local EnemyHealth = target.health
            if ENeeded then
                local EngageRange = 0
                if self:CanUse(_Q, Mode()) then
                    if Q2Buff ~= nil then 
                        EngageRange =  Q2Range
                    else
                        EngageRange = QRange
                    end
                elseif self:CanUse(_W, Mode()) then
                    EngageRange =  WRange
                else
                    EngageRange = AARange
                end
                EngageRange = EngageRange + 300
                if GetDistance(target.pos) < EngageRange and BurstDamage > EnemyHealth then
                    Control.CastSpell(HK_E, target)
                    --PrintChat(BurstDamage)
                end
            end

        end
        if self:CanUse(_Q, Mode()) and ValidTarget(target) and self:CastingChecks() and not (myHero.pathing and myHero.pathing.isDashing) and not _G.SDK.Attack:IsActive() then
            if Q2Buff ~= nil then
                if GetDistance(target.pos) < Q2Range + 200 then
                    self:UseQ2(target)
                end
            else
                if GetDistance(target.pos) < QRange + 200 then
                    self:UseQ(target)
                end               
            end
        end
        if self:CanUse(_W, Mode()) and ValidTarget(target, WRange+200) and self:CastingChecks() and not (myHero.pathing and myHero.pathing.isDashing) and not _G.SDK.Attack:IsActive() then
            if GetDistance(target.pos) < WRange + 200 then
                self:UseW(target)
            end   
        end
        if self:CanUse(_R, Mode()) and ValidTarget(target, RRange+200) and self:CastingChecks() and not (myHero.pathing and myHero.pathing.isDashing) and not _G.SDK.Attack:IsActive() then
            local BurstDamage = self:GetAllDamage(target) * (self.Menu.ComboMode.UseRComboFinishDamage:Value() / 100)
            local EnemyHealth = target.health
            if self.Menu.ComboMode.UseRComboFinish:Value() and BurstDamage > EnemyHealth then
                if ENeeded == false then
                    if not EBuff and self:CanUse(_E, "ERCombo") then
                        Control.CastSpell(HK_E, target)
                    else
                        self:UseR(target, "combokill")
                    end
                else
                    if EBuff then
                        self:UseR(target, "combokill")
                    elseif self:CanUse(_E, "ERCombo") then
                        Control.CastSpell(HK_E, target)
                    end
                end
            end
            self:UseR(target)
        end



        if Game.Timer() - TargetTime > 2 then
            WasInRange = false
        end
    end     
end

function Yone:GetEDamage()
    local unit = nil
    if target then
        unit = target
    end
    --PrintChat(TickQ)
    if EBuff and unit ~= nil then
        --PrintChat(myHero.activeSpell.name)
        if Etarget == nil then
            Etarget = unit
            LastCastDamage = 0
            EdmgRecv = 0
            Edmg = 0
            LastTargetHealth = 0
            Added = false
            EdmgFinal = 0
        end
        local Qdmg = getdmg("Q", unit, myHero)
        local Wdmg = getdmg("W", unit, myHero) + getdmg("W", unit, myHero, 2)
        local Rdmg = getdmg("R", unit, myHero) + getdmg("R", unit, myHero, 2)
        local AAdmg = getdmg("AA", unit, myHero)
        if Added == false then
            if (myHero.activeSpell.name == "YoneBasicAttack" or myHero.activeSpell.name == "YoneBasicAttack2" or myHero.activeSpell.name == "YoneBasicAttack3" or myHero.activeSpell.name == "YoneBasicAttack4") then
                --Edmg = Edmg + AAdmg
                LastCastDamage = AAdmg
                LastSpellName = myHero.activeSpell.name
                --PrintChat(LastCastDamage)
                Added = true
            elseif (myHero.activeSpell.name == "YoneCritAttack" or myHero.activeSpell.name == "YoneCritAttack2" or myHero.activeSpell.name == "YoneCritAttack3" or myHero.activeSpell.name == "YoneCritAttack4") then
                --Edmg = Edmg + AAdmg
                LastCastDamage = AAdmg * 2
                LastSpellName = myHero.activeSpell.name
                --PrintChat(LastCastDamage)
                Added = true   
            end
        elseif myHero.activeSpell.name ~= LastSpellName then
            if myHero.activeSpell.name == "" then
                LastSpellName = myHero.activeSpell.name
            end
            --Added = false
        end
        if Added == false then
            if TickQ and Qdmg then
                --Edmg = Edmg + Qdmg
                LastSpellName = myHero.activeSpell.name
                LastCastDamage =  Qdmg
                --PrintChat(LastCastDamage)
            end
            if TickW and Wdmg then
                Edmg = Edmg + Wdmg
                LastSpellName = myHero.activeSpell.name
                LastCastDamage =  Wdmg
                --PrintChat(LastCastDamage)
                TickW = false
            end
            if TickR and Rdmg then
                Edmg = Edmg + Rdmg
                LastSpellName = myHero.activeSpell.name
                LastCastDamage =  Rdmg
                --PrintChat(LastCastDamage)
                TickR = false
            end
        end

        if unit.health ~= LastTargetHealth then
            if Added == true then
                --PrintChat(LastTargetHealth - unit.health)
                if (LastTargetHealth - unit.health) > 30 then
                    Edmg = Edmg + (LastTargetHealth - unit.health)
                    Added = false
                end
            end

            if TickQ == true then
                --PrintChat(LastTargetHealth - unit.health)
                if (LastTargetHealth - unit.health) > 30 then
                    Edmg = Edmg + (LastTargetHealth - unit.health)
                    TickQ = false
                end
            end
        end
        LastTargetHealth = unit.health
        local EPercent = 0.25 + (0.025*myHero:GetSpellData(_E).level)
        EdmgFinal = (Edmg * EPercent) * (self.Menu.ComboMode.UseEPercent:Value() / 100)
        --PrintChat(EdmgFinal)
    else
        Etarget = nil
        LastCastDamage = 0
        EdmgRecv = 0
        Edmg = 0
        LastTargetHealth = 0
        Added = false
        EdmgFinal = 0
        TickQ = false
        TickW = false
        TickR = false
    end
end


function Yone:ProcessSpells()
    if myHero:GetSpellData(_Q).currentCd == 0 then
        CastedQ = false
    else
        if CastedQ == false then
            TickQ = true
            --PrintChat(TickQ)
        end
        CastedQ = true
    end
    if myHero:GetSpellData(_W).currentCd == 0 then
        CastedW = false
    else
        if CastedW == false then
            TickW = true
        end
        CastedW = true
    end
    if myHero:GetSpellData(_R).currentCd == 0 then
        CastedR = false
    else
        if CastedR == false then
            TickR = true
        end
        CastedR = true
    end
end

function Yone:CastingChecks()
    if not CastingQ and not CastingE and not CastingR and not CastingW then
        return true
    else
        return false
    end
end


function Yone:OnPostAttack(args)
    --PrintChat("Post")
    PostAttack = true
end

function Yone:OnPostAttackTick(args)
end

function Yone:OnPreAttack(args)
end

function Yone:UseW(unit)
    local pred = _G.PremiumPrediction:GetAOEPrediction(myHero, unit, WSpellData)
    if pred.CastPos and pred.HitChance > 0 then
        Control.CastSpell(HK_W, pred.CastPos)
    end
end

function Yone:UseR(unit, rtype)
    local pred = _G.PremiumPrediction:GetAOEPrediction(myHero, unit, RSpellData)
    local Qdmg = getdmg("Q", unit, myHero)
    local Wdmg = getdmg("W", unit, myHero) + getdmg("W", unit, myHero, 2)
    local Rdmg = getdmg("R", unit, myHero) + getdmg("R", unit, myHero, 2)
    local AAdmg = getdmg("AA", unit, myHero)
    local RTotalDmg = 0
    if EBuff then
        local EPercent = 0.25 + (0.025*myHero:GetSpellData(_E).level)
        local RComboDmg = Rdmg
        if self:CanUse(_Q, Mode()) then
            RComboDmg = RComboDmg + Qdmg
        end
        if self:CanUse(_W, Mode()) then
            RComboDmg = RComboDmg + Wdmg
        end
        RTotalDmg = Rdmg + (RComboDmg*EPercent)
    else
        RTotalDmg = Rdmg
    end
    if pred.CastPos and pred.HitChance > self.Menu.ComboMode.UseRHitChance:Value() then
        if pred.HitCount >= self.Menu.ComboMode.UseRNum:Value() then
            if not EBuff and self.Menu.ComboMode.UseE1:Value() and self:CanUse(_E, "Force") then
                Control.CastSpell(HK_E, unit)
            else
                Control.CastSpell(HK_R, pred.CastPos)
            end
        elseif self.Menu.ComboMode.UseRFinish:Value() and unit.health < RTotalDmg then
            EnemiesAroundUnit = 0
            for i, enemy in pairs(EnemyHeroes) do
                if enemy and not enemy.dead and ValidTarget(enemy, 2000) then
                    if GetDistance(enemy.pos, unit.pos) < 600 then
                        EnemiesAroundUnit = EnemiesAroundUnit + 1
                    end
                end
            end
            if not EBuff and self.Menu.ComboMode.UseE1:Value() and self:CanUse(_E, "Force") and EnemiesAroundUnit > 2 then
                Control.CastSpell(HK_E, unit)
            else
                Control.CastSpell(HK_R, pred.CastPos)
            end
        elseif rtype and rtype == "combokill" then
            Control.CastSpell(HK_R, pred.CastPos)
        end
    end
end

function Yone:UseQ(unit)
    local pred = _G.PremiumPrediction:GetPrediction(myHero, unit, QSpellData)
    if pred.CastPos and pred.HitChance > 0 then
        Control.CastSpell(HK_Q, pred.CastPos)
    end
end

function Yone:UseQ2(unit)
    local pred = _G.PremiumPrediction:GetAOEPrediction(myHero, unit, Q2SpellData)
    if pred.CastPos and pred.HitChance > self.Menu.ComboMode.UseQ2HitChance:Value() then
        Control.CastSpell(HK_Q, pred.CastPos)
    end
end


class "Lillia"

local EnemyLoaded = false
local TargetTime = 0

local CastingQ = false
local CastingW = false
local CastingE = false
local CastingR = false
local Item_HK = {}

local WasInRange = false

local ForceTarget = nil

local RBuff = false
local QBuff = nil



local QRange = 485
local WRange = 565
local AARange = 0

local BallSpot = nil
local BallDirection = nil
local BallVelocity = 0
local Fired = false
local BallAlive = false
local BallFiredTime = 0

local CastedW = false
local TickW = false

local RStackTime = Game.Timer()
local LastRstacks = 0

local ARStackTime = Game.Timer()
local ALastRstacks = 0
local ALastTickTarget = myHero

function Lillia:Menu()
    self.Menu = MenuElement({type = MENU, id = "Lillia", name = "Lillia"})
    self.Menu:MenuElement({id = "BallKey", name = "Shoot A Bouncy ball", key = string.byte("H"), value = false})
    self.Menu:MenuElement({id = "ComboMode", name = "Combo", type = MENU})
    self.Menu.ComboMode:MenuElement({id = "UseQ", name = "(Q) Use Q", value = true})
    self.Menu.ComboMode:MenuElement({id = "UseQFar", name = "(Q) Don't Use Q When Too Close", value = true})
    self.Menu.ComboMode:MenuElement({id = "UseQLock", name = "(Q) Movement Helper", value = true})
    self.Menu.ComboMode:MenuElement({id = "UseW", name = "(W) Enabled", value = true})
    self.Menu.ComboMode:MenuElement({id = "UseWFast", name = "(W) Use Fast Mode", value = false})
    self.Menu.ComboMode:MenuElement({id = "UseE", name = "(E) Enabled", value = true})
    self.Menu.ComboMode:MenuElement({id = "UseEQ", name = "(E) Don't Q until E is Used", value = true})
    self.Menu.ComboMode:MenuElement({id = "UseEW", name = "(E) Don't W until E is Used", value = true})
    self.Menu.ComboMode:MenuElement({id = "UseEHitChance", name = "(E) HitChance (0=Fire Often, 1=Immobile)", value = 0, min = 0, max = 1.0, step = 0.05})
    self.Menu.ComboMode:MenuElement({id = "UseEDistance", name = "(E) Max Distance", value = 2000, min = 0, max = 20000, step = 10})
    self.Menu.ComboMode:MenuElement({id = "UseR", name = "(R) Enabled", value = true})
    self.Menu.ComboMode:MenuElement({id = "UseRNum", name = "(R) Number Of Targets", value = 3, min = 1, max = 5, step = 1})
    self.Menu:MenuElement({id = "HarassMode", name = "Harass", type = MENU})
    self.Menu.HarassMode:MenuElement({id = "UseQ", name = "(Q) use Q", value = false})
    self.Menu.HarassMode:MenuElement({id = "UseW", name = "(W) use W", value = false})
    self.Menu.HarassMode:MenuElement({id = "UseE", name = "(E) Use E", value = false})
    self.Menu:MenuElement({id = "AutoMode", name = "Auto", type = MENU})
    self.Menu.AutoMode:MenuElement({id = "UseR", name = "(R) Auto", value = true})
    self.Menu.AutoMode:MenuElement({id = "UseRNum", name = "(R) Number Of Targets", value = 3, min = 1, max = 5, step = 1})
    self.Menu:MenuElement({id = "Draw", name = "Draw", type = MENU})
    self.Menu.Draw:MenuElement({id = "UseDraws", name = "Enable Draws", value = false})
    self.Menu.Draw:MenuElement({id = "DrawAA", name = "Draw AA range", value = false})
    self.Menu.Draw:MenuElement({id = "DrawQ", name = "Draw Q range", value = false})
    self.Menu.Draw:MenuElement({id = "DrawW", name = "Draw W range", value = false})
    self.Menu.Draw:MenuElement({id = "DrawE", name = "Draw E range", value = false})
    self.Menu.Draw:MenuElement({id = "DrawHelper", name = "Draw Q helper", value = false})
end

function Lillia:Spells()
    --local Erange = self.Menu.ComboMode.UseEDistance:Value()
    WSpellData = {speed = math.huge, range = 500, delay = 0.6, radius = 65, collision = {}, type = "circular"}
    ESpellData = {speed = 1400, range = math.huge, delay = 0.4, angle = 50, radius = 120, collision = {""}, type = "linear"}
    ESpellDataCol = {speed = 1400, range = math.huge, delay = 0, angle = 50, radius = 120, collision = {"minion"}, type = "linear"}
    ELobSpellData = {speed = 1400, range = 750, delay = 0.4, angle = 50, radius = 120, collision = {}, type = "linear"}
end


function Lillia:Draw()
    if self.Menu.Draw.UseDraws:Value() then
        local AARange = _G.SDK.Data:GetAutoAttackRange(myHero)
        if self.Menu.Draw.DrawAA:Value() then
            Draw.Circle(myHero.pos, AARange, 1, Draw.Color(255, 0, 191, 0))
        end
        if self.Menu.Draw.DrawQ:Value() then
            Draw.Circle(myHero.pos, QRange, 1, Draw.Color(255, 255, 0, 255))
        end
        if self.Menu.Draw.DrawW:Value() then
            Draw.Circle(myHero.pos, WRange, 1, Draw.Color(255, 255, 0, 255))
        end
        if self.Menu.Draw.DrawE:Value() then
            Draw.Circle(myHero.pos, self.Menu.ComboMode.UseEDistance:Value(), 1, Draw.Color(255, 0, 0, 255))
        end
        if self.Menu.Draw.DrawHelper:Value() then
            local QSpot = self:DrawQHelper()
            if QSpot then
                Draw.Circle(QSpot, 100, 1, Draw.Color(255, 0, 191, 255))
                Draw.Circle(QSpot, 80, 1, Draw.Color(255, 0, 191, 255))
                Draw.Circle(QSpot, 60, 1, Draw.Color(255, 0, 191, 255))
                Draw.Circle(target.pos, QRange, 1, Draw.Color(255, 255, 191, 255))
                Draw.Circle(target.pos, QRange-205, 1, Draw.Color(255, 255, 191, 255))
            end
        end
        --InfoBarSprite = Sprite("SeriesSprites\\InfoBar.png", 1)
        --if self.Menu.ComboMode.UseEAA:Value() then
            --Draw.Text("Sticky E On", 10, myHero.pos:To2D().x+5, myHero.pos:To2D().y-130, Draw.Color(255, 0, 255, 0))
            --InfoBarSprite:Draw(myHero.pos:To2D().x,myHero.pos:To2D().y)
        --else
            --Draw.Text("Sticky E Off", 10, myHero.pos:To2D().x+5, myHero.pos:To2D().y-130, Draw.Color(255, 255, 0, 0))
            --InfoBarSprite:Draw(myHero.pos:To2D().x,myHero.pos:To2D().y)
        --end
    end
end

function Lillia:Tick()
    if _G.JustEvade and _G.JustEvade:Evading() or (_G.ExtLibEvade and _G.ExtLibEvade.Evading) or Game.IsChatOpen() or myHero.dead then return end
    target = GetTarget(2000)
    AARange = _G.SDK.Data:GetAutoAttackRange(myHero)
    CastingQ = myHero.activeSpell.name == "LilliaQ"
    CastingW = myHero.activeSpell.name == "LilliaW"
    CastingE = myHero.activeSpell.name == "LilliaE"
    CastingR = myHero.activeSpell.name == "LilliaR"
    QBuff = GetBuffExpire(myHero, "LilliaQ")
    self:QHelper()
    --RBuff = GetBuffExpire(myHero, "Undying")
    --PrintChat(myHero.activeSpell.name)
    self:UpdateItems()
    self:Logic()
    self:Auto()
    self:Items2()
    self:ProcessSpells()
    if TickW then
        --DelayAction(function() _G.SDK.Orbwalker:__OnAutoAttackReset() end, 0.05)
        TickW = false
    end
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


function Lillia:UpdateItems()
    Item_HK[ITEM_1] = HK_ITEM_1
    Item_HK[ITEM_2] = HK_ITEM_2
    Item_HK[ITEM_3] = HK_ITEM_3
    Item_HK[ITEM_4] = HK_ITEM_4
    Item_HK[ITEM_5] = HK_ITEM_5
    Item_HK[ITEM_6] = HK_ITEM_6
    Item_HK[ITEM_7] = HK_ITEM_7
end

function Lillia:Items1()
    if GetItemSlot(myHero, 3074) > 0 and ValidTarget(target, 300) then --rave 
        if myHero:GetSpellData(GetItemSlot(myHero, 3074)).currentCd == 0 then
            Control.CastSpell(Item_HK[GetItemSlot(myHero, 3074)])
        end
    end
    if GetItemSlot(myHero, 3077) > 0 and ValidTarget(target, 300) then --tiamat
        if myHero:GetSpellData(GetItemSlot(myHero, 3077)).currentCd == 0 then
            Control.CastSpell(Item_HK[GetItemSlot(myHero, 3077)])
        end
    end
    if GetItemSlot(myHero, 3144) > 0 and ValidTarget(target, 550) then --bilge
        if myHero:GetSpellData(GetItemSlot(myHero, 3144)).currentCd == 0 then
            Control.CastSpell(Item_HK[GetItemSlot(myHero, 3144)], target)
        end
    end
    if GetItemSlot(myHero, 3153) > 0 and ValidTarget(target, 550) then -- botrk
        if myHero:GetSpellData(GetItemSlot(myHero, 3153)).currentCd == 0 then
            Control.CastSpell(Item_HK[GetItemSlot(myHero, 3153)], target)
        end
    end
    if GetItemSlot(myHero, 3146) > 0 and ValidTarget(target, 700) then --gunblade hex
        if myHero:GetSpellData(GetItemSlot(myHero, 3146)).currentCd == 0 then
            Control.CastSpell(Item_HK[GetItemSlot(myHero, 3146)], target)
        end
    end
    if GetItemSlot(myHero, 3748) > 0 and ValidTarget(target, 300) then -- Titanic Hydra
        if myHero:GetSpellData(GetItemSlot(myHero, 3748)).currentCd == 0 then
            Control.CastSpell(Item_HK[GetItemSlot(myHero, 3748)])
        end
    end
end

function Lillia:Items2()
    if GetItemSlot(myHero, 3139) > 0 then
        if myHero:GetSpellData(GetItemSlot(myHero, 3139)).currentCd == 0 then
            if IsImmobile(myHero) then
                Control.CastSpell(Item_HK[GetItemSlot(myHero, 3139)], myHero)
            end
        end
    end
    if GetItemSlot(myHero, 3140) > 0 then
        if myHero:GetSpellData(GetItemSlot(myHero, 3140)).currentCd == 0 then
            if IsImmobile(myHero) then
                Control.CastSpell(Item_HK[GetItemSlot(myHero, 3140)], myHero)
            end
        end
    end
end

function Lillia:GetSleepBuffs(unit, buffname)
    for i = 0, unit.buffCount do
        local buff = unit:GetBuff(i)
        if buff.name == buffname and buff.count > 0 then 
            return buff
        end
    end
    return nil
end

function Lillia:Auto()
    NumRTargets = 0
    local Etarget = nil
    for i, enemy in pairs(EnemyHeroes) do
        if enemy and not enemy.dead and ValidTarget(enemy) then
            local Buff = self:GetSleepBuffs(enemy, "LilliaPDoT")
            if Buff ~= nil then
                NumRTargets = NumRTargets + 1
            end
            if not target and Mode() == "Combo" and self:CanUse(_E, Mode()) then
                if Etarget == nil or (GetDistance(enemy.pos, mousePos) < GetDistance(Etarget.pos, mousePos)) then
                    Etarget = enemy
                end
            end
        end
    end
    if Etarget and self:CastingChecks() and ValidTarget(Etarget) then
        self:UseE(Etarget)
    end
    if self:CanUse(_R, "Auto") and NumRTargets >= self.Menu.AutoMode.UseRNum:Value() then
        Control.CastSpell(HK_R)
    end
end 


function Lillia:CanUse(spell, mode)
    if mode == nil then
        mode = Mode()
    end
    --PrintChat(Mode())
    if spell == _Q then
        if mode == "Combo" and IsReady(spell) and self.Menu.ComboMode.UseQ:Value() then
            return true
        end
        if mode == "Harass" and IsReady(spell) and self.Menu.HarassMode.UseQ:Value() then
            return true
        end
        if mode == "AutoUlt" and IsReady(spell) and self.Menu.AutoMode.UseQUlt:Value() then
            return true
        end
        if mode == "Ult" and IsReady(spell) and self.Menu.ComboMode.UseQUlt:Value() then
            return true
        end
        if mode == "Auto" and IsReady(spell) and self.Menu.AutoMode.UseQ:Value() then
            return true
        end
    elseif spell == _R then
        if mode == "Combo" and IsReady(spell) and self.Menu.ComboMode.UseR:Value() then
            return true
        end
        if mode == "Auto" and IsReady(spell) and self.Menu.AutoMode.UseR:Value() then
            return true
        end
    elseif spell == _W then
        if mode == "Combo" and IsReady(spell) and self.Menu.ComboMode.UseW:Value() then
            return true
        end
        if mode == "Harass" and IsReady(spell) and self.Menu.HarassMode.UseW:Value() then
            return true
        end
    elseif spell == _E then
        if mode == "Combo" and IsReady(spell) and self.Menu.ComboMode.UseE:Value() then
            return true
        end
        if mode == "Force" and IsReady(spell) then
            return true
        end
        if mode == "Harass" and IsReady(spell) and self.Menu.HarassMode.UseE:Value() then
            return true
        end
        if mode == "ComboGap" and IsReady(spell) and self.Menu.ComboMode.UseEGap:Value() then
            return true
        end
        if mode == "Auto" and IsReady(spell) and self.Menu.AutoMode.UseE:Value() then
            return true
        end
        if mode == "AutoGap" and IsReady(spell) and self.Menu.AutoMode.UseEGap:Value() then
            return true
        end
    end
    return false
end


function Lillia:DrawQHelper()
    if self.Menu.ComboMode.UseQLock:Value() and QBuff ~= nil and target and Mode() == "Combo" then
        local Distance = GetDistance(target.pos)
        local QExpire = QBuff - Game.Timer()
        local myHeroMs = myHero.ms * 0.75
        if not IsFacing(target) then
            myHeroMs = myHeroMs - (target.ms/2)
        end
        local MaxMove = myHeroMs * QExpire

        local MouseDirection = Vector((myHero.pos-mousePos):Normalized())
        local MouseSpotDistance = MaxMove * 0.8
        if MaxMove > Distance then
            MouseSpotDistance = Distance * 0.8
        end
        local MouseSpot = myHero.pos - MouseDirection * (MouseSpotDistance)

        local TargetMouseDirection = Vector((target.pos-MouseSpot):Normalized())
        local TargetMouseSpot = target.pos - TargetMouseDirection * 315
        local TargetMouseSpotDistance = GetDistance(myHero.pos, TargetMouseSpot)

        if MaxMove < TargetMouseSpotDistance then
            MouseDirection = Vector((myHero.pos-mousePos):Normalized())
            MouseSpotDistance = Distance * 0.4
            MouseSpot = myHero.pos - MouseDirection * (MouseSpotDistance)
            TargetMouseDirection = Vector((target.pos-MouseSpot):Normalized())
            TargetMouseSpot = target.pos - TargetMouseDirection * 315
        end
        if Distance < QRange + MaxMove then
            return TargetMouseSpot
        end
        --local HeroDirection = Vector((myHero.pos-target.pos):Normalized())
        --local HeroSpot = myHero.pos + HeroDirection * 315
    end
end


function Lillia:QHelper()
    --PrintChat(myHero.activeSpell.name)
    if not target then return end
    if not ValidTarget(target) then return end
    local Qon = myHero.activeSpell.name == "LilliaQ" or (GetDistance(target.pos) < 315 and self:CanUse(_Q, Mode()))
    if self.Menu.ComboMode.UseQLock:Value() and Qon and target and Mode() == "Combo" then
        --PrintChat("Moving")
        --_G.SDK.Orbwalker:SetMovement(false)
        local Distance = GetDistance(target.pos)
        --local QExpire = QBuff - Game.Timer()
        local myHeroMs = myHero.ms * 0.75
        if not IsFacing(target) then
            myHeroMs = myHeroMs - (target.ms/2)
        end
        local MaxMove = myHeroMs * 0.5

        local MouseDirection = Vector((myHero.pos-mousePos):Normalized())
        local MouseSpotDistance = Distance  * 0.8
        if MaxMove > Distance then
            MouseSpotDistance = Distance * 0.8
        end
        local MouseSpot = myHero.pos - MouseDirection * (MouseSpotDistance)

        local TargetMouseDirection = Vector((target.pos-MouseSpot):Normalized())
        local TargetMouseSpot = target.pos - TargetMouseDirection * 315
        local TargetMouseSpotDistance = GetDistance(myHero.pos, TargetMouseSpot)

        if Distance < QRange + MaxMove then
            --Control.Move(TargetMouseSpot)
            --PrintChat("Walking for Q")
            _G.SDK.Orbwalker.ForceMovement = TargetMouseSpot
            _G.QHelperActive = true
        else
            --PrintChat("Not Q")
            _G.SDK.Orbwalker.ForceMovement = nil
            _G.QHelperActive = false
            --Control.Move(mousePos)
        end
        --local HeroDirection = Vector((myHero.pos-target.pos):Normalized())
        --local HeroSpot = myHero.pos + HeroDirection * 315
    else
        _G.QHelperActive = false
        --_G.SDK.Orbwalker:SetMovement(true)
    end
end

function Lillia:Logic()
    if target == nil then 
        if Game.Timer() - TargetTime > 2 then
            WasInRange = false
        end
        return 
    end
    if Mode() == "Combo" or Mode() == "Harass" and target and ValidTarget(target) then
        --PrintChat("Logic")
        TargetTime = Game.Timer()
        self:Items1()

        local QRangeExtra = 0
        if IsFacing(target) then
            QRangeExtra = myHero.ms * 0.2
        end
        if IsImmobile(target) then
            QRangeExtra = myHero.ms * 0.5
        end
        
        if GetDistance(target.pos) < AARange then
            WasInRange = true
        end

        if self:CanUse(_W, Mode()) and ValidTarget(target, WRange) and self:CastingChecks() and not (myHero.pathing and myHero.pathing.isDashing) and not _G.SDK.Attack:IsActive() then
            if not self.Menu.ComboMode.UseEW:Value() or not self:CanUse(_E, Mode()) then
                self:UseW(target)
            end
        end
        local TargetSleep = self:GetSleepBuffs(target, "LilliaPDoT")
        if self:CanUse(_R, Mode()) and not CastingR then
            if NumRTargets >= self.Menu.ComboMode.UseRNum:Value() and TargetSleep ~= nil then
                Control.CastSpell(HK_R)
            end
        end

        if self:CanUse(_E, Mode()) and ValidTarget(target, self.Menu.ComboMode.UseEDistance:Value()) and self:CastingChecks() and not (myHero.pathing and myHero.pathing.isDashing) and not _G.SDK.Attack:IsActive() then
            --PrintChat("Casitng E")
            if GetDistance(target.pos) < 750 then
                self:UseELob(target)
            else
                self:UseE(target)
            end
        end
        if self:CanUse(_Q, Mode()) and ValidTarget(target, QRange) and self:CastingChecks() and not (myHero.pathing and myHero.pathing.isDashing) and not _G.SDK.Attack:IsActive() then
            if not self.Menu.ComboMode.UseEQ:Value() or not self:CanUse(_E, Mode()) then
                if GetDistance(target.pos) > 250 or not self.Menu.ComboMode.UseQFar:Value() then
                    Control.CastSpell(HK_Q)
                end
            end
        end
        if Game.Timer() - TargetTime > 2 then
            WasInRange = false
        end
    end     
end

function Lillia:ProcessSpells()
    if myHero:GetSpellData(_W).currentCd == 0 then
        CastedW = false
    else
        if CastedW == false then
            --GotBall = "ECast"
            TickW = true
        end
        CastedW = true
    end
end

function Lillia:CastingChecks()
    if not CastingQ and not CastingE and not CastingR and not CastingW then
        return true
    else
        return false
    end
end


function Lillia:OnPostAttack(args)

end

function Lillia:OnPostAttackTick(args)
end

function Lillia:OnPreAttack(args)
end

function Lillia:UseW(unit)
    local pred = _G.PremiumPrediction:GetAOEPrediction(myHero, unit, WSpellData)
    if pred.CastPos and pred.HitChance > 0 then
        if (not self:CanUse(_E, Mode()) and not self:CanUse(_Q, Mode())) or pred.HitChance > 0.8 then 
            Control.CastSpell(HK_W, pred.CastPos)
        end
    end
end

function Lillia:UseELob(unit)
    local pred = _G.PremiumPrediction:GetPrediction(myHero, unit, ELobSpellData)
    if pred.CastPos and pred.HitChance > self.Menu.ComboMode.UseEHitChance:Value()and myHero.pos:DistanceTo(pred.CastPos) < self.Menu.ComboMode.UseEDistance:Value() then
        Control.CastSpell(HK_E, pred.CastPos)
    end
end

function Lillia:WallCollision(pos1, pos2)
    local Direction = Vector((pos1-pos2):Normalized())
    --Draw.Circle(TargetAdded, 30, 1, Draw.Color(255, 0, 191, 255))
    local checks = GetDistance(pos1,pos2)/50
    --PrintChat("Walls")
    for i=15, checks do
        local CheckSpot = pos1 - Direction * (50*i)
        local Adds = {Vector(100,0,0), Vector(66,0,66), Vector(0,0,100), Vector(-66,0,66), Vector(-100,0,0), Vector(66,0,-66), Vector(0,0,-100), Vector(-66,0,-66)} 
        for i = 1, #Adds do
            local TargetAdded = Vector(CheckSpot + Adds[i])
            if MapPosition:inWall(TargetAdded) then
                Draw.Circle(CheckSpot, 30, 1, Draw.Color(255, 255, 0, 0))
                return true
            else
                Draw.Circle(CheckSpot, 30, 1, Draw.Color(255, 0, 191, 255))
            end
        end
    end
    return false
end

function Lillia:UseE(unit)
    local pred = _G.PremiumPrediction:GetPrediction(myHero, unit, ESpellData)
    if pred.CastPos and pred.HitChance > self.Menu.ComboMode.UseEHitChance:Value()and myHero.pos:DistanceTo(pred.CastPos) < self.Menu.ComboMode.UseEDistance:Value() then
        local Direction2 = Vector((myHero.pos-pred.CastPos):Normalized())
        local Pos2 = myHero.pos - Direction2 * 750
        local pred2 = _G.PremiumPrediction:GetPrediction(Pos2, unit, ESpellDataCol)
        if pred2.CastPos and pred2.HitChance >= 0 then
            Direction = Vector((myHero.pos-pred.CastPos):Normalized())
            Distance = 750
            Spot = myHero.pos - Direction * Distance
            local MouseSpotBefore = mousePos
            if not self:WallCollision(myHero.pos, pred.CastPos) then
                --PrintChat("Casting E")
                --PrintChat(pred.CastPos:ToScreen().onScreen)
                if pred.CastPos:ToScreen().onScreen then
                    Control.CastSpell(HK_E, pred.CastPos)
                else
                    local MMSpot = Vector(pred.CastPos):ToMM()
                    Control.SetCursorPos(MMSpot.x, MMSpot.y)
                    Control.KeyDown(HK_E); Control.KeyUp(HK_E)
                    DelayAction(function() Control.SetCursorPos(MouseSpotBefore) end, 0.20)
                    --Control.SetCursorPos(MouseSpotBefore)
                    --Control.CastSpell(HK_E, Spot)
                end
            end
        end
    end
end

class "Aatrox"

local EnemyLoaded = false
local TargetTime = 0

local CastingQ = false
local CastingW = false
local CastingE = false
local CastingR = false
local Item_HK = {}

local WasInRange = false

local ForceTarget = nil

local WBuff = nil



local Q1Range = 625
local Q2Range = 475
local Q3Range = 360
local WRange = 825
local AARange = 0
local ERange = 300
local RRange = 0
local QActiveRadius = 100
local QDashRadius = 55

local CastedE = false
local TickE = false

local QVersion = 0
local QActiveRange = Q1Range
local QActiveSweetRange = Q1Range - 120
local QMovementHelper = false

function Aatrox:Menu()
    self.Menu = MenuElement({type = MENU, id = "Aatrox", name = "Aatrox"})
    self.Menu:MenuElement({id = "ComboMode", name = "Combo", type = MENU})
    self.Menu.ComboMode:MenuElement({id = "UseQ", name = "(Q) Use Q", value = true})
    self.Menu.ComboMode:MenuElement({id = "UseQ1Knockup", name = "(Q1) Use Q1 Only When it Knocks Up", value = false})
    self.Menu.ComboMode:MenuElement({id = "UseQ2Knockup", name = "(Q2) Use Q2 Only When it Knocks Up", value = true})
    self.Menu.ComboMode:MenuElement({id = "UseQ3Knockup", name = "(Q3) Use Q3 Only When it Knocks Up", value = true})
    self.Menu.ComboMode:MenuElement({id = "UseQ1", name = "(Q1) Use Movement Helper", value = false})
    self.Menu.ComboMode:MenuElement({id = "UseQ2", name = "(Q2) Use Movement Helper", value = true})
    self.Menu.ComboMode:MenuElement({id = "UseQ3", name = "(Q3) Use Movement Helper", value = true})
    self.Menu.ComboMode:MenuElement({id = "QMovementExtra", name = "Distance from Spot activate Movement", value = 100, min = 0, max = 1000, step = 10})
    self.Menu.ComboMode:MenuElement({id = "UseW", name = "(W) Enabled", value = true})
    self.Menu.ComboMode:MenuElement({id = "UseWHitChance", name = "(W) Hit Chance", value = 0, min = 0, max = 1.0, step = 0.05})
    self.Menu.ComboMode:MenuElement({id = "UseE", name = "(E) Enabled", value = true})
    self.Menu.ComboMode:MenuElement({id = "UseR", name = "(R) Enabled", value = true})
    self.Menu:MenuElement({id = "HarassMode", name = "Harass", type = MENU})
    self.Menu.HarassMode:MenuElement({id = "UseQ", name = "(Q) Use Q", value = true})
    self.Menu.HarassMode:MenuElement({id = "UseW", name = "(W) Enabled", value = true})
    self.Menu.HarassMode:MenuElement({id = "UseE", name = "(E) Enabled", value = true})
    self.Menu.HarassMode:MenuElement({id = "UseEHitChance", name = "(E) Hit Chance", value = 0, min = 0, max = 1.0, step = 0.05})
    self.Menu.HarassMode:MenuElement({id = "UseR", name = "(R) Enabled", value = false})
    self.Menu:MenuElement({id = "AutoMode", name = "Auto", type = MENU})
    self.Menu:MenuElement({id = "Draw", name = "Draw", type = MENU})
    self.Menu.Draw:MenuElement({id = "UseDraws", name = "Enable Draws", value = false})
    self.Menu.Draw:MenuElement({id = "DrawAA", name = "Draw AA range", value = false})
    self.Menu.Draw:MenuElement({id = "DrawQ", name = "Draw Q range", value = false})
    self.Menu.Draw:MenuElement({id = "DrawE", name = "Draw E range", value = false})
    self.Menu.Draw:MenuElement({id = "DrawR", name = "Draw R range", value = false})
    self.Menu.Draw:MenuElement({id = "DrawCustom", name = "Draw A Custom Range Circle", value = false})
    self.Menu.Draw:MenuElement({id = "DrawCustomRange", name = "Custom Range Circle", value = 500, min = 0, max = 2000, step = 10})
end

function Aatrox:Spells()
    --ESpellData = {speed = math.huge, range = ERange, delay = 0, angle = 50, radius = 0, collision = {}, type = "conic"}
    WSpellData = {speed = 1800, range = 825, delay = 0.25, radius = 160, collision = {"minion"}, type = "linear"}
    QSpellData = {speed = math.huge, range = 625, delay = 0.5, radius = 120, collision = {""}, type = "circular"}
end


function Aatrox:Draw()
    if self.Menu.Draw.UseDraws:Value() then
        local AARange = _G.SDK.Data:GetAutoAttackRange(myHero)
        if self.Menu.Draw.DrawAA:Value() then
            Draw.Circle(myHero.pos, AARange, 1, Draw.Color(255, 0, 191, 0))
        end
        if self.Menu.Draw.DrawQ:Value() then
            Draw.Circle(myHero.pos, QRange, 1, Draw.Color(255, 255, 0, 255))
        end
        if self.Menu.Draw.DrawE:Value() then
            Draw.Circle(myHero.pos, ERange, 1, Draw.Color(255, 0, 0, 255))
        end
        if self.Menu.Draw.DrawR:Value() then
            Draw.Circle(myHero.pos, RRange, 1, Draw.Color(255, 255, 255, 255))
        end
        if self.Menu.Draw.DrawCustom:Value() then
            Draw.Circle(myHero.pos, self.Menu.Draw.DrawCustomRange:Value(), 1, Draw.Color(255, 0, 191, 0))
        end
        --InfoBarSprite = Sprite("SeriesSprites\\InfoBar.png", 1)
        --if self.Menu.ComboMode.UseEAA:Value() then
            --Draw.Text("Sticky E On", 10, myHero.pos:To2D().x+5, myHero.pos:To2D().y-130, Draw.Color(255, 0, 255, 0))
            --InfoBarSprite:Draw(myHero.pos:To2D().x,myHero.pos:To2D().y)
        --else
            --Draw.Text("Sticky E Off", 10, myHero.pos:To2D().x+5, myHero.pos:To2D().y-130, Draw.Color(255, 255, 0, 0))
            --InfoBarSprite:Draw(myHero.pos:To2D().x,myHero.pos:To2D().y)
        --end
        if myHero.activeSpell.name == "AatroxQWrapperCast" then
            local CastDirection = myHero.dir
            local CastDistance = QActiveSweetRange
            local CastVector = myHero.pos + CastDirection * CastDistance

            Draw.Circle(CastVector, QActiveRadius, 1, Draw.Color(255, 255, 0, 0))
            --PrintChat(myHero.activeSpell.castEndTime)
        end
    end
end



function Aatrox:Tick()
    if _G.JustEvade and _G.JustEvade:Evading() or (_G.ExtLibEvade and _G.ExtLibEvade.Evading) or Game.IsChatOpen() or myHero.dead then return end
    target = GetTarget(2000)
    AARange = _G.SDK.Data:GetAutoAttackRange(myHero)
    CastingQ = myHero.activeSpell.name == "AatroxQWrapperCast"
    CastingW = myHero.activeSpell.name == "AatroxW"
    CastingE = myHero.activeSpell.name == "AatroxE"
    CastingR = myHero.activeSpell.name == "AatroxR"
    --PrintChat(myHero:GetSpellData(_Q).name)
    if myHero:GetSpellData(_Q).name == "AatroxQ" and not CastingQ then
        QVersion = 1
        QActiveRange = Q1Range
        QActiveSweetRange = Q1Range - 95
        QMovementHelper = self.Menu.ComboMode.UseQ1:Value()
        QActiveRadius = 110
        QDashRadius = 55
        QSpellData = {speed = math.huge, range = 625, delay = 0.5, radius = 120, collision = {""}, type = "circular"}
    elseif myHero:GetSpellData(_Q).name == "AatroxQ2" and not CastingQ  then
        QVersion = 2
        QActiveRange = Q2Range
        QActiveSweetRange = Q2Range - 70
        QMovementHelper = self.Menu.ComboMode.UseQ2:Value()
        QActiveRadius = 100
        QDashRadius = 200
        QSpellData = {speed = math.huge, range = Q2Range, delay = 0.5, radius = 120, collision = {""}, type = "circular"}
    elseif myHero:GetSpellData(_Q).name == "AatroxQ3" and not CastingQ then
        QVersion = 3
        QActiveRange = Q3Range
        QActiveSweetRange = 200
        QActiveRadius = 160
        QDashRadius = 80
        QMovementHelper = self.Menu.ComboMode.UseQ3:Value()
        QSpellData = {speed = math.huge, range = Q3Range, delay = 0.5, radius = 120, collision = {""}, type = "circular"}
    end
    if Mode() == "Combo" and target and self:CanUse(_Q, Mode()) and ValidTarget(target, QActiveRange+self.Menu.ComboMode.QMovementExtra:Value()) and (GetDistance(target.pos) + self.Menu.ComboMode.QMovementExtra:Value() > QActiveSweetRange) and QMovementHelper then
        --PrintChat(QVersion)
        _G.AatroxQType = QVersion
    else
        _G.AatroxQType = 0
    end
    if TickE then
        ECastTime = Game.Timer()
        TickE = false
    end
    if ECastTime then
        if not (myHero.pathing and myHero.pathing.isDashing) then
            --PrintChat(Game.Timer() - ECastTime)
            ECastTime = nil
        end
    end


    self:UpdateItems()
    self:Logic()
    self:Auto()
    self:Items2()
    self:ProcessSpells()
    if CastingQ then
        _G.AatroxQType = 0
    end
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


function Aatrox:UpdateItems()
    Item_HK[ITEM_1] = HK_ITEM_1
    Item_HK[ITEM_2] = HK_ITEM_2
    Item_HK[ITEM_3] = HK_ITEM_3
    Item_HK[ITEM_4] = HK_ITEM_4
    Item_HK[ITEM_5] = HK_ITEM_5
    Item_HK[ITEM_6] = HK_ITEM_6
    Item_HK[ITEM_7] = HK_ITEM_7
end

function Aatrox:Items1()
    if GetItemSlot(myHero, 3074) > 0 and ValidTarget(target, 300) then --rave 
        if myHero:GetSpellData(GetItemSlot(myHero, 3074)).currentCd == 0 then
            Control.CastSpell(Item_HK[GetItemSlot(myHero, 3074)])
        end
    end
    if GetItemSlot(myHero, 3077) > 0 and ValidTarget(target, 300) then --tiamat
        if myHero:GetSpellData(GetItemSlot(myHero, 3077)).currentCd == 0 then
            Control.CastSpell(Item_HK[GetItemSlot(myHero, 3077)])
        end
    end
    if GetItemSlot(myHero, 3144) > 0 and ValidTarget(target, 550) then --bilge
        if myHero:GetSpellData(GetItemSlot(myHero, 3144)).currentCd == 0 then
            Control.CastSpell(Item_HK[GetItemSlot(myHero, 3144)], target)
        end
    end
    if GetItemSlot(myHero, 3153) > 0 and ValidTarget(target, 550) then -- botrk
        if myHero:GetSpellData(GetItemSlot(myHero, 3153)).currentCd == 0 then
            Control.CastSpell(Item_HK[GetItemSlot(myHero, 3153)], target)
        end
    end
    if GetItemSlot(myHero, 3146) > 0 and ValidTarget(target, 700) then --gunblade hex
        if myHero:GetSpellData(GetItemSlot(myHero, 3146)).currentCd == 0 then
            Control.CastSpell(Item_HK[GetItemSlot(myHero, 3146)], target)
        end
    end
    if GetItemSlot(myHero, 3748) > 0 and ValidTarget(target, 300) then -- Titanic Hydra
        if myHero:GetSpellData(GetItemSlot(myHero, 3748)).currentCd == 0 then
            Control.CastSpell(Item_HK[GetItemSlot(myHero, 3748)])
        end
    end
end

function Aatrox:Items2()
    if GetItemSlot(myHero, 3139) > 0 then
        if myHero:GetSpellData(GetItemSlot(myHero, 3139)).currentCd == 0 then
            if IsImmobile(myHero) then
                Control.CastSpell(Item_HK[GetItemSlot(myHero, 3139)], myHero)
            end
        end
    end
    if GetItemSlot(myHero, 3140) > 0 then
        if myHero:GetSpellData(GetItemSlot(myHero, 3140)).currentCd == 0 then
            if IsImmobile(myHero) then
                Control.CastSpell(Item_HK[GetItemSlot(myHero, 3140)], myHero)
            end
        end
    end
end

function Aatrox:GetPassiveBuffs(unit, buffname)
    for i = 0, unit.buffCount do
        local buff = unit:GetBuff(i)
        if buff.name == buffname and buff.count > 0 then 
            return buff
        end
    end
    return nil
end


function Aatrox:Auto()
    for i, enemy in pairs(EnemyHeroes) do
        if enemy and not enemy.dead and ValidTarget(enemy) then
        end
    end
end 

function Aatrox:CanUse(spell, mode)
    if mode == nil then
        mode = Mode()
    end
    --PrintChat(Mode())
    if spell == _Q then
        if mode == "Combo" and IsReady(spell) and self.Menu.ComboMode.UseQ:Value() then
            return true
        end
        if mode == "Combo2" and IsReady(spell) and self.Menu.ComboMode.UseQ2:Value() then
            return true
        end
        if mode == "Harass" and IsReady(spell) and self.Menu.HarassMode.UseQ:Value() then
            return true
        end
        if mode == "Auto" and IsReady(spell) and self.Menu.AutoMode.UseQ:Value() then
            return true
        end
    elseif spell == _R then
        if mode == "Combo" and IsReady(spell) and self.Menu.ComboMode.UseR:Value() then
            return true
        end
        if mode == "Auto" and IsReady(spell) and self.Menu.AutoMode.UseR:Value() then
            return true
        end
    elseif spell == _W then
        if mode == "Combo" and IsReady(spell) and self.Menu.ComboMode.UseW:Value() then
            return true
        end
        if mode == "Harass" and IsReady(spell) and self.Menu.HarassMode.UseW:Value() then
            return true
        end
    elseif spell == _E then
        if mode == "Combo" and IsReady(spell) and self.Menu.ComboMode.UseE:Value() then
            return true
        end
        if mode == "Force" and IsReady(spell) then
            return true
        end
        if mode == "Harass" and IsReady(spell) and self.Menu.HarassMode.UseE:Value() then
            return true
        end
    end
    return false
end

function Aatrox:Logic()
            --PrintChat(myHero.activeSpell.name)
    if target == nil then 
        if Game.Timer() - TargetTime > 2 then
            WasInRange = false
        end
        return 
    end
    if Mode() == "Combo" or Mode() == "Harass" and target then
        --PrintChat("Logic")
        TargetTime = Game.Timer()
        self:Items1()
        
        if GetDistance(target.pos) < AARange then
            WasInRange = true
        end
        if self:CanUse(_Q, Mode()) and self:CastingChecks() and not (myHero.pathing and myHero.pathing.isDashing) and not _G.SDK.Attack:IsActive() and ValidTarget(target, QActiveRange) then
            if (QVersion == 1 and self.Menu.ComboMode.UseQ1Knockup:Value()) or (QVersion == 2 and self.Menu.ComboMode.UseQ2Knockup:Value()) or (QVersion == 3 and self.Menu.ComboMode.UseQ3Knockup:Value()) then
                if QVersion == 3 and GetDistance(target.pos) < QActiveSweetRange then
                    local pred = _G.PremiumPrediction:GetPrediction(myHero, target, QSpellData)
                    if pred.CastPos and pred.HitChance > 0 and myHero.pos:DistanceTo(pred.CastPos) < QActiveSweetRange then
                        Control.CastSpell(HK_Q, pred.CastPos)
                    end
                elseif GetDistance(target.pos) > QActiveSweetRange then
                    local pred = _G.PremiumPrediction:GetPrediction(myHero, target, QSpellData)
                    if pred.CastPos and pred.HitChance > 0 and myHero.pos:DistanceTo(pred.CastPos) > QActiveSweetRange and myHero.pos:DistanceTo(pred.CastPos) < QActiveRange then
                        Control.CastSpell(HK_Q, pred.CastPos)
                    end            
                end
            else
                self:UseQ(target)
            end
        end
        if self:CanUse(_W, Mode()) and self:CastingChecks() and not _G.SDK.Attack:IsActive() and ValidTarget(target, WRange) then
            self:UseW(target)
        end
        if self:CanUse(_E, Mode()) and _G.AatroxQType == 0 and self:CastingChecks() and not _G.SDK.Attack:IsActive() and ValidTarget(target, ERange+AARange) and GetDistance(target.pos) > AARange then
            --self:UseE(target)
        end

        if self:CanUse(_E, Mode()) and CastingQ then
               --PrintChat("Less Cast Time")
                local CastDirection = myHero.dir
                local CastDistance = QActiveSweetRange
                local CastVector = myHero.pos + CastDirection * CastDistance
                local TravelTime = GetDistance(CastVector)/1000
                if QVersion == 1 then
                    TravelTime = GetDistance(CastVector)/1200
                elseif QVersion == 2 then
                    TravelTime = GetDistance(CastVector)/1200
                elseif QVersion == 3 then
                    TravelTime = GetDistance(CastVector)/600
                end
                if GetDistance(target.pos, CastVector) > QActiveRadius and myHero.activeSpell.castEndTime - Game.Timer() < TravelTime then
                    --PrintChat("Q missed")
                    local EVector = target.pos - CastDirection * CastDistance
                    if GetDistance(EVector) < ERange + QDashRadius then
                        Control.CastSpell(HK_E, EVector)
                    end
                end
        end
        if Game.Timer() - TargetTime > 2 then
            WasInRange = false
        end
    end     
end

function Aatrox:ProcessSpells()
    if myHero:GetSpellData(_E).currentCd == 0 then
        CastedE = false
    else
        if CastedE == false then
            --GotBall = "ECast"
            TickE = true
        end
        CastedE = true
    end
end

function Aatrox:CastingChecks()
    if not CastingQ and not CastingW and not CastingE and not CastingR then
        return true
    else
        return false
    end
end


function Aatrox:OnPostAttack(args)

end

function Aatrox:OnPostAttackTick(args)
end

function Aatrox:OnPreAttack(args)
end

function Aatrox:UseQ(unit)
    local pred = _G.PremiumPrediction:GetPrediction(myHero, unit, QSpellData)
    if pred.CastPos and pred.HitChance > 0 and myHero.pos:DistanceTo(pred.CastPos) < QActiveRange then
        Control.CastSpell(HK_Q, pred.CastPos)
    end 
end

function Aatrox:UseW(unit)
    local pred = _G.PremiumPrediction:GetPrediction(myHero, unit, WSpellData)
    if pred.CastPos and pred.HitChance > self.Menu.ComboMode.UseWHitChance:Value() and myHero.pos:DistanceTo(pred.CastPos) < WRange then
        Control.CastSpell(HK_W, pred.CastPos)
    end 
end

function Aatrox:UseE(unit)
    Control.CastSpell(HK_E, unit)
end

class "Jax"

local EnemyLoaded = false
local TargetTime = 0

local CastingQ = false
local CastingW = false
local CastingE = false
local CastingR = false
local Item_HK = {}

local WasInRange = false

local ForceTarget = nil

local EBuff = false



local QRange = 700
local WRange = 0
local AARange = 0
local ERange = 350
local RRange = 0

local QAAW = 0



function Jax:Menu()
    self.Menu = MenuElement({type = MENU, id = "Jax", name = "Jax"})
    self.Menu:MenuElement({id = "ComboMode", name = "Combo", type = MENU})
    self.Menu.ComboMode:MenuElement({id = "UseQ", name = "(Q) Use Q", value = true})
    self.Menu.ComboMode:MenuElement({id = "UseQAA", name = "(Q) Use Q In AA Range", value = false})
    self.Menu.ComboMode:MenuElement({id = "UseW", name = "(W) Enabled", value = true})
    self.Menu.ComboMode:MenuElement({id = "UseWReset", name = "(W) To Reset Auto Attack", value = true})
    self.Menu.ComboMode:MenuElement({id = "UseE", name = "(E) Enabled", value = true})
    self.Menu.ComboMode:MenuElement({id = "UseE2", name = "(E2) Enabled", key = string.byte("T"), toggle = true, value = true})
    self.Menu.ComboMode:MenuElement({id = "UseR", name = "(R) Enabled", value = true})
    self.Menu.ComboMode:MenuElement({id = "UseRHealth", name = "(R) Min % Health", value = 40, min = 0, max = 100, step = 5})
    self.Menu:MenuElement({id = "HarassMode", name = "Harass", type = MENU})
    self.Menu.HarassMode:MenuElement({id = "UseQ", name = "(Q) Use Q", value = true})
    self.Menu.HarassMode:MenuElement({id = "UseQAA", name = "(Q) Use Q In AA Range", value = true})
    self.Menu.HarassMode:MenuElement({id = "UseW", name = "(W) Enabled", value = true})
    self.Menu.HarassMode:MenuElement({id = "UseE", name = "(E) Enabled", value = true})
    self.Menu.HarassMode:MenuElement({id = "UseE2", name = "(E2) Enabled", value = true})
    self.Menu.HarassMode:MenuElement({id = "UseR", name = "(R) Enabled", value = false})
    self.Menu.HarassMode:MenuElement({id = "UseRHealth", name = "(R) Min % Health", value = 20, min = 0, max = 100, step = 5})
    self.Menu:MenuElement({id = "Draw", name = "Draw", type = MENU})
    self.Menu.Draw:MenuElement({id = "UseDraws", name = "Enable Draws", value = false})
    self.Menu.Draw:MenuElement({id = "DrawAA", name = "Draw AA range", value = false})
    self.Menu.Draw:MenuElement({id = "DrawQ", name = "Draw Q range", value = false})
    self.Menu.Draw:MenuElement({id = "DrawE", name = "Draw E range", value = false})
    self.Menu.Draw:MenuElement({id = "DrawR", name = "Draw R range", value = false})
    self.Menu.Draw:MenuElement({id = "DrawCustom", name = "Draw A Custom Range Circle", value = false})
    self.Menu.Draw:MenuElement({id = "DrawCustomRange", name = "Custom Range Circle", value = 500, min = 0, max = 2000, step = 10})
    self.Menu.Draw:MenuElement({id = "DrawES", name = "Draw E Settings text", value = false})
end

function Jax:Spells()

end


function Jax:Draw()
    if self.Menu.Draw.UseDraws:Value() then
        local AARange = _G.SDK.Data:GetAutoAttackRange(myHero)
        if self.Menu.Draw.DrawAA:Value() then
            Draw.Circle(myHero.pos, AARange, 1, Draw.Color(255, 0, 191, 0))
        end
        if self.Menu.Draw.DrawQ:Value() then
            Draw.Circle(myHero.pos, QRange, 1, Draw.Color(255, 255, 0, 255))
        end
        if self.Menu.Draw.DrawE:Value() then
            Draw.Circle(myHero.pos, ERange, 1, Draw.Color(255, 0, 0, 255))
        end
        if self.Menu.Draw.DrawR:Value() then
            Draw.Circle(myHero.pos, RRange, 1, Draw.Color(255, 255, 255, 255))
        end
        if self.Menu.Draw.DrawCustom:Value() then
            Draw.Circle(myHero.pos, self.Menu.Draw.DrawCustomRange:Value(), 1, Draw.Color(255, 0, 191, 0))
        end
        if self.Menu.Draw.DrawES:Value() then
            if self.Menu.ComboMode.UseE2:Value() then
                Draw.Text("(Jax) E2 On", 10, myHero.pos:To2D().x+5, myHero.pos:To2D().y-120, Draw.Color(255, 0, 255, 100))
            else
                Draw.Text("(Jax) E2 Off", 10, myHero.pos:To2D().x+5, myHero.pos:To2D().y-120, Draw.Color(255, 255, 0, 100))
            end
        end
    end
end



function Jax:Tick()
    if _G.JustEvade and _G.JustEvade:Evading() or (_G.ExtLibEvade and _G.ExtLibEvade.Evading) or Game.IsChatOpen() or myHero.dead then return end
    target = GetTarget(2000)
    AARange = _G.SDK.Data:GetAutoAttackRange(myHero)
    WRange = AARange + 50
    CastingQ = myHero.activeSpell.name == "JaxQ"
    CastingW = myHero.activeSpell.name == "JaxW"
    CastingE = myHero.activeSpell.name == "JaxE"
    CastingR = myHero.activeSpell.name == "JaxR"
    EBuff = BuffActive(myHero, "JaxCounterStrike")
    --PrintChat(myHero.activeSpell.name)
    self:UpdateItems()
    self:Logic()
    self:Auto()
    self:Items2()
    self:ProcessSpells()
    if TickW then
        --_G.SDK.Orbwalker:__OnAutoAttackReset()
        TickW = false
    end
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


function Jax:UpdateItems()
    Item_HK[ITEM_1] = HK_ITEM_1
    Item_HK[ITEM_2] = HK_ITEM_2
    Item_HK[ITEM_3] = HK_ITEM_3
    Item_HK[ITEM_4] = HK_ITEM_4
    Item_HK[ITEM_5] = HK_ITEM_5
    Item_HK[ITEM_6] = HK_ITEM_6
    Item_HK[ITEM_7] = HK_ITEM_7
end

function Jax:Items1()
    if GetItemSlot(myHero, 3074) > 0 and ValidTarget(target, 300) then --rave 
        if myHero:GetSpellData(GetItemSlot(myHero, 3074)).currentCd == 0 then
            Control.CastSpell(Item_HK[GetItemSlot(myHero, 3074)])
        end
    end
    if GetItemSlot(myHero, 3077) > 0 and ValidTarget(target, 300) then --tiamat
        if myHero:GetSpellData(GetItemSlot(myHero, 3077)).currentCd == 0 then
            Control.CastSpell(Item_HK[GetItemSlot(myHero, 3077)])
        end
    end
    if GetItemSlot(myHero, 3144) > 0 and ValidTarget(target, 550) then --bilge
        if myHero:GetSpellData(GetItemSlot(myHero, 3144)).currentCd == 0 then
            Control.CastSpell(Item_HK[GetItemSlot(myHero, 3144)], target)
        end
    end
    if GetItemSlot(myHero, 3153) > 0 and ValidTarget(target, 550) then -- botrk
        if myHero:GetSpellData(GetItemSlot(myHero, 3153)).currentCd == 0 then
            Control.CastSpell(Item_HK[GetItemSlot(myHero, 3153)], target)
        end
    end
    if GetItemSlot(myHero, 3146) > 0 and ValidTarget(target, 700) then --gunblade hex
        if myHero:GetSpellData(GetItemSlot(myHero, 3146)).currentCd == 0 then
            Control.CastSpell(Item_HK[GetItemSlot(myHero, 3146)], target)
        end
    end
    if GetItemSlot(myHero, 3748) > 0 and ValidTarget(target, 300) then -- Titanic Hydra
        if myHero:GetSpellData(GetItemSlot(myHero, 3748)).currentCd == 0 then
            Control.CastSpell(Item_HK[GetItemSlot(myHero, 3748)])
        end
    end
end

function Jax:Items2()
    if GetItemSlot(myHero, 3139) > 0 then
        if myHero:GetSpellData(GetItemSlot(myHero, 3139)).currentCd == 0 then
            if IsImmobile(myHero) then
                Control.CastSpell(Item_HK[GetItemSlot(myHero, 3139)], myHero)
            end
        end
    end
    if GetItemSlot(myHero, 3140) > 0 then
        if myHero:GetSpellData(GetItemSlot(myHero, 3140)).currentCd == 0 then
            if IsImmobile(myHero) then
                Control.CastSpell(Item_HK[GetItemSlot(myHero, 3140)], myHero)
            end
        end
    end
end

function Jax:GetPassiveBuffs(unit, buffname)
    for i = 0, unit.buffCount do
        local buff = unit:GetBuff(i)
        if buff.name == buffname and buff.count > 0 then 
            return buff
        end
    end
    return nil
end


function Jax:Auto()
    for i, enemy in pairs(EnemyHeroes) do
        if enemy and not enemy.dead and ValidTarget(enemy) then
        end
    end
end 

function Jax:CanUse(spell, mode)
    if mode == nil then
        mode = Mode()
    end
    --PrintChat(Mode())
    if spell == _Q then
        if mode == "Combo" and IsReady(spell) and self.Menu.ComboMode.UseQ:Value() then
            return true
        end
        if mode == "Harass" and IsReady(spell) and self.Menu.HarassMode.UseQ:Value() then
            return true
        end
        if mode == "Force" and IsReady(spell) then
            return true
        end
    elseif spell == _R then
        if mode == "Combo" and IsReady(spell) and self.Menu.ComboMode.UseR:Value() then
            return true
        end
        if mode == "Harass" and IsReady(spell) and self.Menu.HarassMode.UseQ:Value() then
            return true
        end
        if mode == "Force" and IsReady(spell) then
            return true
        end
    elseif spell == _W then
        if mode == "Combo" and IsReady(spell) and self.Menu.ComboMode.UseW:Value() then
            return true
        end
        if mode == "Harass" and IsReady(spell) and self.Menu.HarassMode.UseW:Value() then
            return true
        end
        if mode == "Force" and IsReady(spell) then
            return true
        end
    elseif spell == _E then
        if not EBuff then
            if mode == "Combo" and IsReady(spell) and self.Menu.ComboMode.UseE:Value() then
                return true
            end
            if mode == "Harass" and IsReady(spell) and self.Menu.HarassMode.UseE:Value() then
                return true
            end
        else
            if mode == "Combo" and IsReady(spell) and self.Menu.ComboMode.UseE2:Value() then
                return true
            end
            if mode == "Harass" and IsReady(spell) and self.Menu.HarassMode.UseE2:Value() then
                return true
            end
        end
        if mode == "Force" and IsReady(spell) then
            return true
        end
    end
    return false
end

function Jax:Logic()
    if target == nil then 
        if Game.Timer() - TargetTime > 2 then
            WasInRange = false
        end
        return 
    end
    if Mode() == "Combo" or Mode() == "Harass" and target then
        --PrintChat("Logic")
        TargetTime = Game.Timer()
        self:Items1()
        
        if GetDistance(target.pos) < AARange then
            WasInRange = true
        end
        if self:CanUse(_W, Mode()) and ValidTarget(target, ERange) then
            if myHero.attackData.state == STATE_WINDDOWN or Mode() == "Harass" or not self.Menu.ComboMode.UseWReset:Value() or QAAW == 2 then
                self:UseW(target)
                if QAAW == 2 then
                    QAAW = 0
                end
            end
        end
        if self:CanUse(_Q, Mode()) and ValidTarget(target, QRange) and not (myHero.pathing and myHero.pathing.isDashing) and not _G.SDK.Attack:IsActive() then
            if Mode() == "Combo" then
                if self.Menu.ComboMode.UseQAA:Value() or GetDistance(target.pos) > AARange then
                    if self:CanUse(_W, Mode()) and not self.Menu.ComboMode.UseWReset:Value() then
                        self:UseW(target)
                    end
                    self:UseQ(target)
                end
            elseif Mode() == "Harass" then
                if not self.Menu.HarassMode.UseQAA:Value() or GetDistance(target.pos) > AARange then
                    if self:CanUse(_W, Mode()) then
                        self:UseW(target)
                    end
                    self:UseQ(target)
                end
            end
        end
        if self:CanUse(_E, Mode()) and not _G.SDK.Attack:IsActive() and ValidTarget(target, ERange) then
            self:UseE(target)
        end
        if self:CanUse(_R, Mode()) and not _G.SDK.Attack:IsActive() and ValidTarget(target, QRange) then
            self:UseR(target)
        end
        --
        if Game.Timer() - TargetTime > 2 then
            WasInRange = false
        end
    end     
end

function Jax:ProcessSpells()
    if myHero:GetSpellData(_W).currentCd == 0 then
        CastedW = false
    else
        if CastedW == false then
            --GotBall = "ECast"
            TickW = true
        end
        CastedW = true
    end
end

function Jax:CastingChecks()
    if not CastingQ and not CastingE and not CastingW and not CastingR then
        return true
    else
        return false
    end
end


function Jax:OnPostAttack(args)
    if QAAW == 1 then
        QAAW = 2
    end
end

function Jax:OnPostAttackTick(args)

end

function Jax:OnPreAttack(args)
end

function Jax:UseQ(unit)
    Control.CastSpell(HK_Q, unit)
    QAAW = 1
end

function Jax:UseW(unit)
    Control.CastSpell(HK_W)
    _G.SDK.Orbwalker:__OnAutoAttackReset()
end

function Jax:UseE(unit)
    Control.CastSpell(HK_E)
end

function Jax:UseR(unit)
    local HealthValue = 1
    if Mode() == "Combo" then
        HealthValue = self.Menu.ComboMode.UseRHealth:Value() / 100
    elseif Mode() == "Harass" then
        HealthValue = self.Menu.HarassMode.UseRHealth:Value() / 100
    end
    if myHero.health < myHero.maxHealth*HealthValue then
        Control.CastSpell(HK_R)
    end
end

class "Rengar"

local EnemyLoaded = false
local TargetTime = 0

local CastingQ = false
local CastingW = false
local CastingE = false
local CastingR = false
local Item_HK = {}

local WasInRange = false

local ForceTarget = nil

local PBuff = false

local MaxFerocity = "Q"


local QRange = 0
local WRange = 450
local AARange = 0
local ERange = 1000

local Mounted = true


function Rengar:Menu()
    self.Menu = MenuElement({type = MENU, id = "Rengar", name = "Rengar"})
    self.Menu:MenuElement({id = "MeleeKey", name = "Melee Helper Toggle", key = string.byte("H"), toggle = true, value = false})
    self.Menu:MenuElement({id = "ComboMode", name = "Combo", type = MENU})
    self.Menu.ComboMode:MenuElement({id = "UseQ", name = "(Q) Enabled", value = true})
    self.Menu.ComboMode:MenuElement({id = "UseW", name = "(W) Enabled", value = true})
    self.Menu.ComboMode:MenuElement({id = "UseE", name = "(E) Enabled", value = true})
    self.Menu.ComboMode:MenuElement({id = "UseItems", name = "Items Enabled", value = true})
    self.Menu.ComboMode:MenuElement({id = "UseEHitChance", name = "(E) Hit Chance", value = 0, min = 0, max = 1.0, step = 0.05})
    self.Menu:MenuElement({id = "HarassMode", name = "Harass", type = MENU})
    self.Menu.HarassMode:MenuElement({id = "UseQ", name = "(Q) use Q", value = false})
    self.Menu.HarassMode:MenuElement({id = "UseW", name = "(W) use W", value = false})
    self.Menu.HarassMode:MenuElement({id = "UseE", name = "(E) Use E", value = false})
    self.Menu.HarassMode:MenuElement({id = "UseE", name = "(E) Hit Chance", value = 0, min = 0, max = 1.0, step = 0.05})
    self.Menu.HarassMode:MenuElement({id = "UseItems", name = "Items Enabled", value = true})
    self.Menu:MenuElement({id = "AutoMode", name = "Auto", type = MENU})
    self.Menu:MenuElement({id = "Draw", name = "Draw", type = MENU})
    self.Menu.Draw:MenuElement({id = "UseDraws", name = "Enable Draws", value = false})
    self.Menu.Draw:MenuElement({id = "DrawAA", name = "Draw AA range", value = false})
    self.Menu.Draw:MenuElement({id = "DrawQ", name = "Draw Q range", value = false})
    self.Menu.Draw:MenuElement({id = "DrawE", name = "Draw E range", value = false})
    self.Menu.Draw:MenuElement({id = "DrawR", name = "Draw R range", value = false})
    self.Menu.Draw:MenuElement({id = "DrawCustom", name = "Draw A Custom Range Circle", value = false})
    self.Menu.Draw:MenuElement({id = "DrawCustomRange", name = "Custom Range Circle", value = 500, min = 0, max = 2000, step = 10})
end

function Rengar:Spells()
    --ESpellData = {speed = math.huge, range = ERange, delay = 0, angle = 50, radius = 0, collision = {}, type = "conic"}
    ESpellData = {speed = 2000, range = 1000, delay = 0, radius = 30, collision = {"minion"}, type = "linear"}
end


function Rengar:Draw()
    if self.Menu.Draw.UseDraws:Value() then
        local AARange = _G.SDK.Data:GetAutoAttackRange(myHero)
        if self.Menu.Draw.DrawAA:Value() then
            Draw.Circle(myHero.pos, AARange, 1, Draw.Color(255, 0, 191, 0))
        end
        if self.Menu.Draw.DrawQ:Value() then
            Draw.Circle(myHero.pos, QRange, 1, Draw.Color(255, 255, 0, 255))
        end
        if self.Menu.Draw.DrawE:Value() then
            Draw.Circle(myHero.pos, ERange, 1, Draw.Color(255, 0, 0, 255))
        end
        if self.Menu.Draw.DrawR:Value() then
            Draw.Circle(myHero.pos, RRange, 1, Draw.Color(255, 255, 255, 255))
        end
        if self.Menu.Draw.DrawCustom:Value() then
            Draw.Circle(myHero.pos, self.Menu.Draw.DrawCustomRange:Value(), 1, Draw.Color(255, 0, 191, 0))
        end
        --InfoBarSprite = Sprite("SeriesSprites\\InfoBar.png", 1)
        --if self.Menu.ComboMode.UseEAA:Value() then
            --Draw.Text("Sticky E On", 10, myHero.pos:To2D().x+5, myHero.pos:To2D().y-130, Draw.Color(255, 0, 255, 0))
            --InfoBarSprite:Draw(myHero.pos:To2D().x,myHero.pos:To2D().y)
        --else
            --Draw.Text("Sticky E Off", 10, myHero.pos:To2D().x+5, myHero.pos:To2D().y-130, Draw.Color(255, 255, 0, 0))
            --InfoBarSprite:Draw(myHero.pos:To2D().x,myHero.pos:To2D().y)
        --end
    end
end



function Rengar:Tick()
    if _G.JustEvade and _G.JustEvade:Evading() or (_G.ExtLibEvade and _G.ExtLibEvade.Evading) or Game.IsChatOpen() or myHero.dead then return end
    target = GetTarget(2000)
    AARange = _G.SDK.Data:GetAutoAttackRange(myHero)
    QRange = AARange + 20
    WRange = 450
    CastingQ = myHero.activeSpell.name == "RengarQ"
    CastingW = myHero.activeSpell.name == "RengarW"
    CastingE = myHero.activeSpell.name == "RengarE"
    CastingR = myHero.activeSpell.name == "RengarR"
    PBuff = AARange > 800
    --PrintChat(myHero:GetSpellData(_W).ammo)
    if myHero:GetSpellData(_Q).name == "RengarRiderQ" then
        Mounted = false 
    else
        Mounted = true
    end
    self:UpdateItems()
    self:Logic()
    self:Auto()
    self:Items2()
    self:ProcessSpells()
    if self:CanUse(_W, Mode()) then
        --DelayAction(function() _G.SDK.Orbwalker:__OnAutoAttackReset() end, 0.05)
        TickW = false
    end
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


function Rengar:UpdateItems()
    Item_HK[ITEM_1] = HK_ITEM_1
    Item_HK[ITEM_2] = HK_ITEM_2
    Item_HK[ITEM_3] = HK_ITEM_3
    Item_HK[ITEM_4] = HK_ITEM_4
    Item_HK[ITEM_5] = HK_ITEM_5
    Item_HK[ITEM_6] = HK_ITEM_6
    Item_HK[ITEM_7] = HK_ITEM_7
end

function Rengar:Items1()
    if (Mode() == "Combo" and self.Menu.ComboMode.UseItems:Value()) or (Mode() == "Harass" and self.Menu.HarassMode.UseItems:Value()) then
        if GetItemSlot(myHero, 3144) > 0 and ValidTarget(target, 550) then --bilge
            if myHero:GetSpellData(GetItemSlot(myHero, 3144)).currentCd == 0 then
                Control.CastSpell(Item_HK[GetItemSlot(myHero, 3144)], target)
            end
        end
        if GetItemSlot(myHero, 3153) > 0 and ValidTarget(target, 550) then -- botrk
            if myHero:GetSpellData(GetItemSlot(myHero, 3153)).currentCd == 0 then
                Control.CastSpell(Item_HK[GetItemSlot(myHero, 3153)], target)
            end
        end
        if GetItemSlot(myHero, 3146) > 0 and ValidTarget(target, 700) then --gunblade hex
            if myHero:GetSpellData(GetItemSlot(myHero, 3146)).currentCd == 0 then
                Control.CastSpell(Item_HK[GetItemSlot(myHero, 3146)], target)
            end
        end
    end
end

function Rengar:Items2()
    if (Mode() == "Combo" and self.Menu.ComboMode.UseItems:Value()) or (Mode() == "Harass" and self.Menu.HarassMode.UseItems:Value()) then
        if GetItemSlot(myHero, 3139) > 0 then
            if myHero:GetSpellData(GetItemSlot(myHero, 3139)).currentCd == 0 then
                if IsImmobile(myHero) then
                    Control.CastSpell(Item_HK[GetItemSlot(myHero, 3139)], myHero)
                end
            end
        end
        if GetItemSlot(myHero, 3140) > 0 then
            if myHero:GetSpellData(GetItemSlot(myHero, 3140)).currentCd == 0 then
                if IsImmobile(myHero) then
                    Control.CastSpell(Item_HK[GetItemSlot(myHero, 3140)], myHero)
                end
            end
        end
    end
end

function Rengar:GetPassiveBuffs()
    for i = 0, myHero.buffCount do
        local buff = myHero:GetBuff(i)
        if buff.name == "RengarPassive" and buff.count > 0 then 
            return true
        end
    end
    return false
end


function Rengar:Auto()
    for i, enemy in pairs(EnemyHeroes) do
        if enemy and not enemy.dead and ValidTarget(enemy) then
        end
    end
end 

function Rengar:CanUse(spell, mode)
    if mode == nil then
        mode = Mode()
    end
    --PrintChat(Mode())
    if spell == _Q then
        if mode == "Combo" and IsReady(spell) and self.Menu.ComboMode.UseQ:Value() then
            return true
        end
        if mode == "Harass" and IsReady(spell) and self.Menu.HarassMode.UseQ:Value() then
            return true
        end
        if mode == "Auto" and IsReady(spell) and self.Menu.AutoMode.UseQ:Value() then
            return true
        end
    elseif spell == _R then
        if mode == "Combo" and IsReady(spell) and self.Menu.ComboMode.UseR:Value() then
            return true
        end
        if mode == "Auto" and IsReady(spell) and self.Menu.AutoMode.UseR:Value() then
            return true
        end
    elseif spell == _W then
        if mode == "Combo" and IsReady(spell) and self.Menu.ComboMode.UseW:Value() then
            return true
        end
        if mode == "Harass" and IsReady(spell) and self.Menu.HarassMode.UseW:Value() then
            return true
        end
    elseif spell == _E then
        if mode == "Combo" and IsReady(spell) and self.Menu.ComboMode.UseE:Value() then
            return true
        end
        if mode == "Force" and IsReady(spell) then
            return true
        end
        if mode == "Harass" and IsReady(spell) and self.Menu.HarassMode.UseE:Value() then
            return true
        end
    end
    return false
end

function Rengar:Logic()
    if target == nil then 
        if Game.Timer() - TargetTime > 2 then
            WasInRange = false
        end
        return 
    end
    if Mode() == "Combo" or Mode() == "Harass" and target then
        --PrintChat("Logic")
        TargetTime = Game.Timer()
        self:Items1()
        
        if GetDistance(target.pos) < AARange then
            WasInRange = true
        end
        if self:CanUse(_Q, Mode()) and ValidTarget(target) and self:CastingChecks() and not _G.SDK.Attack:IsActive() and ((myHero.pathing and myHero.pathing.isDashing) or GetDistance(target.pos) < AARange+200) then
            if myHero.mana < 4 or MaxFerocity == "Q" then
                self:UseQ()
            end
        end
        if self:CanUse(_E, Mode()) and ValidTarget(target, ERange) and self:CastingChecks() and not _G.SDK.Attack:IsActive() then
            if myHero.mana < 4 or MaxFerocity == "E" then
                --PrintChat("Yep")
                if (PBuff == false or (myHero.pathing and myHero.pathing.isDashing)) and (not self:CanUse(_Q, Mode()) or GetDistance(target.pos) > AARange)  then
                    --PrintChat("Yep2")
                    self:UseE(target)
                end
            end
        end
        if self:CanUse(_W, Mode()) and ValidTarget(target, WRange) and self:CastingChecks() and not _G.SDK.Attack:IsActive() then
            if myHero.mana < 4 then
                self:UseW()
            end
            if (Mode() == "Combo" and self.Menu.ComboMode.UseItems:Value()) or (Mode() == "Harass" and self.Menu.HarassMode.UseItems:Value()) then
                if GetItemSlot(myHero, 3074) > 0 and ValidTarget(target, 300) then --rave 
                    if myHero:GetSpellData(GetItemSlot(myHero, 3074)).currentCd == 0 then
                        Control.CastSpell(Item_HK[GetItemSlot(myHero, 3074)])
                    end
                end
                if GetItemSlot(myHero, 3077) > 0 and ValidTarget(target, 300) then --tiamat
                    if myHero:GetSpellData(GetItemSlot(myHero, 3077)).currentCd == 0 then
                        Control.CastSpell(Item_HK[GetItemSlot(myHero, 3077)])
                    end
                end
                if GetItemSlot(myHero, 3748) > 0 and ValidTarget(target, 300) then -- Titanic Hydra
                    if myHero:GetSpellData(GetItemSlot(myHero, 3748)).currentCd == 0 then
                        Control.CastSpell(Item_HK[GetItemSlot(myHero, 3748)])
                    end
                end
            end
        end
        if TickW or (not self:CanUse(_Q, Mode()) and not self:CanUse(_W, Mode())) then
            if (Mode() == "Combo" and self.Menu.ComboMode.UseItems:Value()) or (Mode() == "Harass" and self.Menu.HarassMode.UseItems:Value()) then
                if GetItemSlot(myHero, 3074) > 0 and ValidTarget(target, 300) then --rave 
                    if myHero:GetSpellData(GetItemSlot(myHero, 3074)).currentCd == 0 then
                        Control.CastSpell(Item_HK[GetItemSlot(myHero, 3074)])
                    end
                end
                if GetItemSlot(myHero, 3077) > 0 and ValidTarget(target, 300) then --tiamat
                    if myHero:GetSpellData(GetItemSlot(myHero, 3077)).currentCd == 0 then
                        Control.CastSpell(Item_HK[GetItemSlot(myHero, 3077)])
                    end
                end
                if GetItemSlot(myHero, 3748) > 0 and ValidTarget(target, 300) then -- Titanic Hydra
                    if myHero:GetSpellData(GetItemSlot(myHero, 3748)).currentCd == 0 then
                        Control.CastSpell(Item_HK[GetItemSlot(myHero, 3748)])
                    end
                end
                TickW = false
            end
        end
        if Game.Timer() - TargetTime > 2 then
            WasInRange = false
        end
    end     
end

function Rengar:ProcessSpells()
    if myHero:GetSpellData(_W).currentCd == 0 then
        CastedW = false
    else
        if CastedW == false then
            --GotBall = "ECast"
            TickW = true
        end
        CastedW = true
    end
end

function Rengar:CastingChecks()
    if not CastingQ and not CastingE and not CastingW and not CastingR then
        return true
    else
        return true
    end
end


function Rengar:OnPostAttack(args)

end

function Rengar:OnPostAttackTick(args)
end

function Rengar:OnPreAttack(args)
end

function Rengar:UseQ()
    Control.CastSpell(HK_Q)
end

function Rengar:UseW()
    Control.CastSpell(HK_W)
end

function Rengar:UseE(unit)
    local pred = _G.PremiumPrediction:GetPrediction(myHero, unit, ESpellData)
    if pred.CastPos and pred.HitChance > self.Menu.ComboMode.UseEHitChance:Value() and myHero.pos:DistanceTo(pred.CastPos) < ERange then
            Control.CastSpell(HK_E, pred.CastPos)
    end 
end


class "Darius"

local EnemyLoaded = false
local TargetTime = 0

local CastingQ = false
local CastingW = false
local CastingE = false
local CastingR = false
local Item_HK = {}

local WasInRange = false

local ForceTarget = nil

local RBuff = false
local QBuff = nil



local QRange = 425
local WRange = 0
local AARange = 0
local ERange = 535
local RRange = 460

local BallSpot = nil
local BallDirection = nil
local BallVelocity = 0
local Fired = false
local BallAlive = false
local BallFiredTime = 0

local CastedW = false
local TickW = false

local RStackTime = Game.Timer()
local LastRstacks = 0

local ARStackTime = Game.Timer()
local ALastRstacks = 0
local ALastTickTarget = myHero

function Darius:Menu()
    self.Menu = MenuElement({type = MENU, id = "Darius", name = "Darius"})
    self.Menu:MenuElement({id = "BallKey", name = "Shoot A Bouncy ball", key = string.byte("H"), value = false})
    self.Menu:MenuElement({id = "ComboMode", name = "Combo", type = MENU})
    self.Menu.ComboMode:MenuElement({id = "UseQ", name = "(Q) Use Q", value = true})
    self.Menu.ComboMode:MenuElement({id = "UseQLock", name = "(Q) Movement Helper", value = true})
    self.Menu.ComboMode:MenuElement({id = "UseW", name = "(W) Enabled", value = true})
    self.Menu.ComboMode:MenuElement({id = "UseE", name = "(E) Enabled", value = true})
    self.Menu.ComboMode:MenuElement({id = "UseEFast", name = "(E) Use Fast Mode", value = true})
    self.Menu.ComboMode:MenuElement({id = "UseEAA", name = "(E) Block E in AA range", value = false})
    self.Menu.ComboMode:MenuElement({id = "UseEQ", name = "(E) Use E to Set up Q (even with Block on)", value = true})
    self.Menu.ComboMode:MenuElement({id = "UseR", name = "(R) Enabled", value = true})
    self.Menu.ComboMode:MenuElement({id = "UseRDamage", name = "(R) R Damage (%)", value = 95, min = 0, max = 200, step = 1})
    self.Menu.ComboMode:MenuElement({id = "UseRPassive", name = "(R) Early R if Passive Damage Can kill", value = false})
    self.Menu.ComboMode:MenuElement({id = "UseRPassiveDamage", name = "(R) Passive Damage (%)", value = 25, min = 0, max = 100, step = 1})
    self.Menu:MenuElement({id = "HarassMode", name = "Harass", type = MENU})
    self.Menu.HarassMode:MenuElement({id = "UseQ", name = "(Q) use Q", value = false})
    self.Menu.HarassMode:MenuElement({id = "UseW", name = "(W) use W", value = false})
    self.Menu.HarassMode:MenuElement({id = "UseE", name = "(E) Use E", value = false})
    self.Menu:MenuElement({id = "AutoMode", name = "Auto", type = MENU})
    self.Menu.AutoMode:MenuElement({id = "UseR", name = "(R) Auto KS", value = true})
    self.Menu.AutoMode:MenuElement({id = "UseRDamage", name = "(R) R Damage (%)", value = 95, min = 0, max = 200, step = 1})
    self.Menu:MenuElement({id = "Draw", name = "Draw", type = MENU})
    self.Menu.Draw:MenuElement({id = "UseDraws", name = "Enable Draws", value = false})
    self.Menu.Draw:MenuElement({id = "DrawAA", name = "Draw AA range", value = false})
    self.Menu.Draw:MenuElement({id = "DrawQ", name = "Draw Q range", value = false})
    self.Menu.Draw:MenuElement({id = "DrawE", name = "Draw E range", value = false})
    self.Menu.Draw:MenuElement({id = "DrawR", name = "Draw R range", value = false})
    self.Menu.Draw:MenuElement({id = "DrawHelper", name = "Draw Q helper", value = false})
    self.Menu.Draw:MenuElement({id = "DrawDamage", name = "Draw Combo Damage on Target", value = false})
end

function Darius:Spells()
    ESpellData = {speed = math.huge, range = ERange, delay = 0.25, angle = 50, radius = 0, collision = {}, type = "conic"}
end


function Darius:Draw()
    if self.Menu.Draw.UseDraws:Value() then
        local AARange = _G.SDK.Data:GetAutoAttackRange(myHero)
        if self.Menu.Draw.DrawAA:Value() then
            Draw.Circle(myHero.pos, AARange, 1, Draw.Color(255, 0, 191, 0))
        end
        if self.Menu.Draw.DrawQ:Value() then
            Draw.Circle(myHero.pos, QRange, 1, Draw.Color(255, 255, 0, 255))
        end
        if self.Menu.Draw.DrawE:Value() then
            Draw.Circle(myHero.pos, ERange, 1, Draw.Color(255, 0, 0, 255))
        end
        if self.Menu.Draw.DrawR:Value() then
            Draw.Circle(myHero.pos, RRange, 1, Draw.Color(255, 255, 255, 255))
        end
        if self.Menu.Draw.DrawHelper:Value() then
            local QSpot = self:DrawQHelper()
            if QSpot then
                Draw.Circle(QSpot, 100, 1, Draw.Color(255, 0, 191, 255))
                Draw.Circle(QSpot, 80, 1, Draw.Color(255, 0, 191, 255))
                Draw.Circle(QSpot, 60, 1, Draw.Color(255, 0, 191, 255))
                Draw.Circle(target.pos, QRange, 1, Draw.Color(255, 255, 191, 255))
                Draw.Circle(target.pos, QRange-205, 1, Draw.Color(255, 255, 191, 255))
            end
        end
        if target and self.Menu.Draw.DrawDamage:Value() then
            local DamageArray = self:GetDamage(target)
            if DamageArray.TotalDamage > target.health then
                Draw.Text(math.floor(DamageArray.TotalDamage), 20, target.pos:To2D().x-20, target.pos:To2D().y-120, Draw.Color(255, 0, 255, 0))
                Draw.Text("____", 20, target.pos:To2D().x-15, target.pos:To2D().y-117, Draw.Color(255, 0, 150, 0))
                Draw.Text(math.floor(target.health), 20, target.pos:To2D().x-10, target.pos:To2D().y-100, Draw.Color(255, 0, 150, 0))
            else
                Draw.Text(math.floor(DamageArray.TotalDamage), 20, target.pos:To2D().x-20, target.pos:To2D().y-120, Draw.Color(255, 255, 0, 0))
                Draw.Text("____", 20, target.pos:To2D().x-15, target.pos:To2D().y-117, Draw.Color(255, 0, 150, 0))
                Draw.Text(math.floor(target.health), 20, target.pos:To2D().x-10, target.pos:To2D().y-100, Draw.Color(255, 0, 150, 0))
            end
        end
        --InfoBarSprite = Sprite("SeriesSprites\\InfoBar.png", 1)
        --if self.Menu.ComboMode.UseEAA:Value() then
            --Draw.Text("Sticky E On", 10, myHero.pos:To2D().x+5, myHero.pos:To2D().y-130, Draw.Color(255, 0, 255, 0))
            --InfoBarSprite:Draw(myHero.pos:To2D().x,myHero.pos:To2D().y)
        --else
            --Draw.Text("Sticky E Off", 10, myHero.pos:To2D().x+5, myHero.pos:To2D().y-130, Draw.Color(255, 255, 0, 0))
            --InfoBarSprite:Draw(myHero.pos:To2D().x,myHero.pos:To2D().y)
        --end
    end
end

function Darius:Tick()
    if _G.JustEvade and _G.JustEvade:Evading() or (_G.ExtLibEvade and _G.ExtLibEvade.Evading) or Game.IsChatOpen() or myHero.dead then return end
    target = GetTarget(2000)
    AARange = _G.SDK.Data:GetAutoAttackRange(myHero)
    WRange = AARange + 20
    CastingQ = myHero.activeSpell.name == "DariusQ"
    CastingW = myHero.activeSpell.name == "DariusW"
    CastingE = myHero.activeSpell.name == "DariusE"
    CastingR = myHero.activeSpell.name == "DariusR"
    QBuff = GetBuffExpire(myHero, "dariusqcast")
    self:QHelper()
    --RBuff = GetBuffExpire(myHero, "Undying")
    --PrintChat(myHero.activeSpellSlot)
    self:UpdateItems()
    self:Logic()
    self:Auto()
    self:Items2()
    self:ProcessSpells()
    if TickW then
        --DelayAction(function() _G.SDK.Orbwalker:__OnAutoAttackReset() end, 0.05)
        TickW = false
    end
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


function Darius:UpdateItems()
    Item_HK[ITEM_1] = HK_ITEM_1
    Item_HK[ITEM_2] = HK_ITEM_2
    Item_HK[ITEM_3] = HK_ITEM_3
    Item_HK[ITEM_4] = HK_ITEM_4
    Item_HK[ITEM_5] = HK_ITEM_5
    Item_HK[ITEM_6] = HK_ITEM_6
    Item_HK[ITEM_7] = HK_ITEM_7
end

function Darius:Items1()
    if GetItemSlot(myHero, 3074) > 0 and ValidTarget(target, 300) then --rave 
        if myHero:GetSpellData(GetItemSlot(myHero, 3074)).currentCd == 0 then
            Control.CastSpell(Item_HK[GetItemSlot(myHero, 3074)])
        end
    end
    if GetItemSlot(myHero, 3077) > 0 and ValidTarget(target, 300) then --tiamat
        if myHero:GetSpellData(GetItemSlot(myHero, 3077)).currentCd == 0 then
            Control.CastSpell(Item_HK[GetItemSlot(myHero, 3077)])
        end
    end
    if GetItemSlot(myHero, 3144) > 0 and ValidTarget(target, 550) then --bilge
        if myHero:GetSpellData(GetItemSlot(myHero, 3144)).currentCd == 0 then
            Control.CastSpell(Item_HK[GetItemSlot(myHero, 3144)], target)
        end
    end
    if GetItemSlot(myHero, 3153) > 0 and ValidTarget(target, 550) then -- botrk
        if myHero:GetSpellData(GetItemSlot(myHero, 3153)).currentCd == 0 then
            Control.CastSpell(Item_HK[GetItemSlot(myHero, 3153)], target)
        end
    end
    if GetItemSlot(myHero, 3146) > 0 and ValidTarget(target, 700) then --gunblade hex
        if myHero:GetSpellData(GetItemSlot(myHero, 3146)).currentCd == 0 then
            Control.CastSpell(Item_HK[GetItemSlot(myHero, 3146)], target)
        end
    end
    if GetItemSlot(myHero, 3748) > 0 and ValidTarget(target, 300) then -- Titanic Hydra
        if myHero:GetSpellData(GetItemSlot(myHero, 3748)).currentCd == 0 then
            Control.CastSpell(Item_HK[GetItemSlot(myHero, 3748)])
        end
    end
end

function Darius:Items2()
    if GetItemSlot(myHero, 3139) > 0 then
        if myHero:GetSpellData(GetItemSlot(myHero, 3139)).currentCd == 0 then
            if IsImmobile(myHero) then
                Control.CastSpell(Item_HK[GetItemSlot(myHero, 3139)], myHero)
            end
        end
    end
    if GetItemSlot(myHero, 3140) > 0 then
        if myHero:GetSpellData(GetItemSlot(myHero, 3140)).currentCd == 0 then
            if IsImmobile(myHero) then
                Control.CastSpell(Item_HK[GetItemSlot(myHero, 3140)], myHero)
            end
        end
    end
end

function Darius:GetPassiveBuffs(unit, buffname)
    for i = 0, unit.buffCount do
        local buff = unit:GetBuff(i)
        if buff.name == buffname and buff.count > 0 then 
            return buff
        end
    end
    return nil
end

function Darius:GetDamage(unit)
    local Qdmg = 0
    local Wdmg = 0
    local Rdmg = 0
    local Pdmg = 0
    local Pstacks = 1
    local ManaCost = 0
    if IsReady(_R) then
        ManaCost = myHero:GetSpellData(_R).mana 
    end
    if IsReady(_Q) and myHero.mana >= ManaCost + myHero:GetSpellData(_Q).mana then
        ManaCost = ManaCost + myHero:GetSpellData(_Q).mana 
        Qdmg = getdmg("Q", unit, myHero)
        Pstacks = Pstacks + 1
    end
    if IsReady(_W) and myHero.mana >= ManaCost + myHero:GetSpellData(_W).mana then
        ManaCost = ManaCost + myHero:GetSpellData(_W).mana 
        Wdmg = getdmg("W", unit, myHero)
        Pstacks = Pstacks + 1
    end
    if IsReady(_E) and myHero.mana >= ManaCost + myHero:GetSpellData(_E).mana then
        ManaCost = ManaCost + myHero:GetSpellData(_E).mana 
        Pstacks = Pstacks + 1
    end
    if IsReady(_R) then
        Pstacks = Pstacks + 1
        Rdmg = self:GetRDamage(unit, "Combo", Pstacks)
    end
    local AAdmg = getdmg("AA", unit, myHero)
    Pdmg = self:GetPassiveTickDamage(unit) * Pstacks

    local UnitHealth = unit.health + unit.shieldAD
    local TotalDamage = Qdmg + Wdmg + Rdmg + Pdmg + AAdmg
    local DamageArray = {QDamage = Qdmg, WDamage = Wdmg, RDamage = Rdmg, PDamage = Pdmg, AADamage = AAdmg, TotalDamage = TotalDamage}
    return DamageArray
end

function Darius:GetPassiveDamage(unit, buff, stacks)
    local StackDamage = (12+ myHero.levelData.lvl) + (0.3 * myHero.bonusDamage)
    local buffDuration = buff.expireTime - Game.Timer()
    local PassiveDamage = (StackDamage * ((buffDuration - (buffDuration%1.25))/1.25)) * buff.count
    local PassiveDmg = CalcPhysicalDamage(myHero, unit, PassiveDamage)
    return PassiveDmg
end

function Darius:GetPassiveTickDamage(unit)
    local StackDamage = (12+ myHero.levelData.lvl) + (0.3 * myHero.bonusDamage)
    local PassiveDmg = CalcPhysicalDamage(myHero, unit, StackDamage)
    return PassiveDmg
end

function Darius:GetRDamage(unit, mode, stacks)
    if unit == nil then
        return 0
    end
    if mode == "Combo" then
        local Rdmg = getdmg("R", unit, myHero)
        local PassiveBuff = self:GetPassiveBuffs(unit, "DariusHemo")
        if PassiveBuff then
            local RStacks = PassiveBuff.count
            if LastRstacks ~= RStacks then
                if LastTickTarget and LastTickTarget.charName == unit.charName then
                    RStackTime = Game.Timer()
                    LastRstacks = RStacks
                    LastTickTarget = unit
                else
                    LastRstacks = RStacks
                    LastTickTarget = unit
                end
            end
            local RStackDamage = Rdmg * (0.2*RStacks)
            local RDamage = (Rdmg + RStackDamage) * (self.Menu.ComboMode.UseRDamage:Value() / 100)
            if self.Menu.ComboMode.UseRPassive:Value() then
                local PassiveDamage = self:GetPassiveDamage(unit, PassiveBuff) * (self.Menu.ComboMode.UseRPassiveDamage:Value() / 100)
                RDamage = RDamage + PassiveDamage
            elseif RStackTime - Game.Timer() < 0.40 then
                RDamage = RDamage + self:GetPassiveTickDamage(unit)
            end
            return RDamage
        else
            if stacks then
                local RStackDamage = Rdmg * (0.2*stacks)
                return (Rdmg + RStackDamage) * (self.Menu.ComboMode.UseRDamage:Value() / 100)
            else
                return Rdmg * (self.Menu.ComboMode.UseRDamage:Value() / 100)
            end
        end
    elseif mode == "Auto" then
        local Rdmg = getdmg("R", unit, myHero)
        local PassiveBuff = self:GetPassiveBuffs(unit, "DariusHemo")
        if PassiveBuff then
            local RStacks = PassiveBuff.count
            if ALastRstacks ~= RStacks then
                if ALastTickTarget.charName == unit.charName then
                    ARStackTime = Game.Timer()
                    ALastRstacks = RStacks
                    ALastTickTarget = unit
                else
                    ALastRstacks = RStacks
                    ALastTickTarget = unit 
                end
            end
            local RStackDamage = Rdmg * (0.2*RStacks)
            local RDamage = (Rdmg + RStackDamage) * (self.Menu.AutoMode.UseRDamage:Value() / 100)
            if RStackTime - Game.Timer() < 0.40 then
                RDamage = RDamage + self:GetPassiveTickDamage(unit, PassiveBuff)
            end
            return RDamage
        else
            return Rdmg * (self.Menu.AutoMode.UseRDamage:Value() / 100)
        end
    end
    return 0
end


function Darius:Auto()
    for i, enemy in pairs(EnemyHeroes) do
        if enemy and not enemy.dead and ValidTarget(enemy) then
            if self:CanUse(_R, "Auto") and ValidTarget(enemy, RRange) then
                local RDamage = self:GetRDamage(enemy, "Auto")
                if RDamage > enemy.health + enemy.shieldAD then
                    Control.CastSpell(HK_R, enemy)
                end
            end
        end
    end
end 


function Darius:CanUse(spell, mode)
    if mode == nil then
        mode = Mode()
    end
    --PrintChat(Mode())
    if spell == _Q then
        if mode == "Combo" and IsReady(spell) and self.Menu.ComboMode.UseQ:Value() then
            return true
        end
        if mode == "Harass" and IsReady(spell) and self.Menu.HarassMode.UseQ:Value() then
            return true
        end
        if mode == "AutoUlt" and IsReady(spell) and self.Menu.AutoMode.UseQUlt:Value() then
            return true
        end
        if mode == "Ult" and IsReady(spell) and self.Menu.ComboMode.UseQUlt:Value() then
            return true
        end
        if mode == "Auto" and IsReady(spell) and self.Menu.AutoMode.UseQ:Value() then
            return true
        end
    elseif spell == _R then
        if mode == "Combo" and IsReady(spell) and self.Menu.ComboMode.UseR:Value() then
            return true
        end
        if mode == "Auto" and IsReady(spell) and self.Menu.AutoMode.UseR:Value() then
            return true
        end
    elseif spell == _W then
        if mode == "Combo" and IsReady(spell) and self.Menu.ComboMode.UseW:Value() then
            return true
        end
        if mode == "Harass" and IsReady(spell) and self.Menu.HarassMode.UseW:Value() then
            return true
        end
    elseif spell == _E then
        if mode == "Combo" and IsReady(spell) and self.Menu.ComboMode.UseE:Value() then
            return true
        end
        if mode == "Force" and IsReady(spell) then
            return true
        end
        if mode == "Harass" and IsReady(spell) and self.Menu.HarassMode.UseE:Value() then
            return true
        end
        if mode == "ComboGap" and IsReady(spell) and self.Menu.ComboMode.UseEGap:Value() then
            return true
        end
        if mode == "Auto" and IsReady(spell) and self.Menu.AutoMode.UseE:Value() then
            return true
        end
        if mode == "AutoGap" and IsReady(spell) and self.Menu.AutoMode.UseEGap:Value() then
            return true
        end
    end
    return false
end


function Darius:DrawQHelper()
    if self.Menu.ComboMode.UseQLock:Value() and QBuff ~= nil and target and Mode() == "Combo" then
        local Distance = GetDistance(target.pos)
        local QExpire = QBuff - Game.Timer()
        local myHeroMs = myHero.ms * 0.75
        if not IsFacing(target) then
            myHeroMs = myHeroMs - (target.ms/2)
        end
        local MaxMove = myHeroMs * QExpire

        local MouseDirection = Vector((myHero.pos-mousePos):Normalized())
        local MouseSpotDistance = MaxMove * 0.8
        if MaxMove > Distance then
            MouseSpotDistance = Distance * 0.8
        end
        local MouseSpot = myHero.pos - MouseDirection * (MouseSpotDistance)

        local TargetMouseDirection = Vector((target.pos-MouseSpot):Normalized())
        local TargetMouseSpot = target.pos - TargetMouseDirection * 315
        local TargetMouseSpotDistance = GetDistance(myHero.pos, TargetMouseSpot)

        if MaxMove < TargetMouseSpotDistance then
            MouseDirection = Vector((myHero.pos-mousePos):Normalized())
            MouseSpotDistance = Distance * 0.4
            MouseSpot = myHero.pos - MouseDirection * (MouseSpotDistance)
            TargetMouseDirection = Vector((target.pos-MouseSpot):Normalized())
            TargetMouseSpot = target.pos - TargetMouseDirection * 315
        end
        if Distance < QRange + MaxMove then
            return TargetMouseSpot
        end
        --local HeroDirection = Vector((myHero.pos-target.pos):Normalized())
        --local HeroSpot = myHero.pos + HeroDirection * 315
    end
end


function Darius:QHelper()
    if self.Menu.ComboMode.UseQLock:Value() and QBuff ~= nil and target and Mode() == "Combo" then
        --_G.SDK.Orbwalker:SetMovement(false)
        local Distance = GetDistance(target.pos)
        local QExpire = QBuff - Game.Timer()
        local myHeroMs = myHero.ms * 0.75
        if not IsFacing(target) then
            myHeroMs = myHeroMs - (target.ms/2)
        end
        local MaxMove = myHeroMs * QExpire

        local MouseDirection = Vector((myHero.pos-mousePos):Normalized())
        local MouseSpotDistance = MaxMove * 0.8
        if MaxMove > Distance then
            MouseSpotDistance = Distance * 0.8
        end
        local MouseSpot = myHero.pos - MouseDirection * (MouseSpotDistance)

        local TargetMouseDirection = Vector((target.pos-MouseSpot):Normalized())
        local TargetMouseSpot = target.pos - TargetMouseDirection * 315
        local TargetMouseSpotDistance = GetDistance(myHero.pos, TargetMouseSpot)

        if Distance < QRange + MaxMove then
            --Control.Move(TargetMouseSpot)
            _G.SDK.Orbwalker.ForceMovement = TargetMouseSpot
            _G.QHelperActive = true
        else
            _G.SDK.Orbwalker.ForceMovement = nil
            _G.QHelperActive = false
            --Control.Move(mousePos)
        end
        --local HeroDirection = Vector((myHero.pos-target.pos):Normalized())
        --local HeroSpot = myHero.pos + HeroDirection * 315
    else
        _G.QHelperActive = false
        --_G.SDK.Orbwalker:SetMovement(true)
    end
end

function Darius:Logic()
    if target == nil then 
        if Game.Timer() - TargetTime > 2 then
            WasInRange = false
        end
        return 
    end
    if Mode() == "Combo" or Mode() == "Harass" and target then
        --PrintChat("Logic")
        TargetTime = Game.Timer()
        self:Items1()

        local QRangeExtra = 0
        if IsFacing(target) then
            QRangeExtra = myHero.ms * 0.2
        end
        if IsImmobile(target) then
            QRangeExtra = myHero.ms * 0.5
        end
        
        if GetDistance(target.pos) < AARange then
            WasInRange = true
        end

        if self:CanUse(_W, Mode()) and ValidTarget(target, WRange) and self:CastingChecks() and not _G.SDK.Attack:IsActive() then
            --PrintChat("Checking facing")
            if self.Menu.ComboMode.UseW:Value() then 
                Control.CastSpell(HK_W)
            end
        end
        if self:CanUse(_R, Mode()) and ValidTarget(target, RRange) and not CastingR then
            local RDamage = self:GetRDamage(target, Mode())
            if RDamage > target.health + target.shieldAD and target.health > 0 then
                Control.CastSpell(HK_R, target)
            end
        end

        if self:CanUse(_E, Mode()) and ValidTarget(target, ERange) and self:CastingChecks() and not (myHero.pathing and myHero.pathing.isDashing) and not _G.SDK.Attack:IsActive() then
            if self.Menu.ComboMode.UseEAA:Value() then
                if GetDistance(target.pos) > AARange then 
                    self:UseE(target)
                end
            else
                self:UseE(target)
            end
            if self.Menu.ComboMode.UseEQ:Value() and self:CanUse(_Q, Mode()) then
                self:UseE(target)
            end
        end
        if self:CanUse(_Q, Mode()) and ValidTarget(target, QRange+QRangeExtra) and self:CastingChecks() and not (myHero.pathing and myHero.pathing.isDashing) and not _G.SDK.Attack:IsActive() then
            if not self.Menu.ComboMode.UseEQ:Value() or not self:CanUse(_E, Mode()) then
                if self:CanUse(_W, Mode()) and ValidTarget(target, WRange) then
                    Control.CastSpell(HK_W)
                end
                Control.CastSpell(HK_Q)
            end
        end
        if Game.Timer() - TargetTime > 2 then
            WasInRange = false
        end
    end     
end

function Darius:ProcessSpells()
    if myHero:GetSpellData(_W).currentCd == 0 then
        CastedW = false
    else
        if CastedW == false then
            --GotBall = "ECast"
            TickW = true
        end
        CastedW = true
    end
end

function Darius:CastingChecks()
    if not CastingQ and not CastingE and not CastingR then
        return true
    else
        return false
    end
end


function Darius:OnPostAttack(args)

end

function Darius:OnPostAttackTick(args)
end

function Darius:OnPreAttack(args)
end

function Darius:UseE(unit)
    if self.Menu.ComboMode.UseEFast:Value() then
        Control.CastSpell(HK_E, unit)
    else
        local pred = _G.PremiumPrediction:GetAOEPrediction(myHero, unit, ESpellData)
        if pred.CastPos and pred.HitChance > 0 then
            Control.CastSpell(HK_E, pred.CastPos)
        end
    end 
end


class "Kled"

local EnemyLoaded = false
local TargetTime = 0

local CastingQ = false
local CastingW = false
local CastingE = false
local CastingR = false
local Item_HK = {}

local WasInRange = false

local ForceTarget = nil

local WBuff = nil



local QRange = 750
local WRange = 0
local AARange = 0
local ERange = 600
local RRange = math.huge
local Q2Range = 700

local Mounted = true


function Kled:Menu()
    self.Menu = MenuElement({type = MENU, id = "Kled", name = "Kled"})
    self.Menu:MenuElement({id = "ComboMode", name = "Combo", type = MENU})
    self.Menu.ComboMode:MenuElement({id = "UseQ", name = "(Q) Use Q", value = true})
    self.Menu.ComboMode:MenuElement({id = "UseQHitChance", name = "(Q) Hit Chance", value = 0, min = 0, max = 1.0, step = 0.05})
    self.Menu.ComboMode:MenuElement({id = "UseQ2", name = "(Q2) Use Unmounted Q", value = true})
    self.Menu.ComboMode:MenuElement({id = "UseQ2HitChance", name = "(Q2)Hit Chance", value = 0, min = 0, max = 1.0, step = 0.05})
    self.Menu.ComboMode:MenuElement({id = "UseE", name = "(E) Enabled", value = true})
    self.Menu.ComboMode:MenuElement({id = "UseEFast", name = "(E) Use Fast Mode", value = true})
    self.Menu.ComboMode:MenuElement({id = "UseEAA", name = "(E) Block E in AA range", value = false})
    self.Menu:MenuElement({id = "HarassMode", name = "Harass", type = MENU})
    self.Menu.HarassMode:MenuElement({id = "UseQ", name = "(Q) use Q", value = false})
    self.Menu.HarassMode:MenuElement({id = "UseE", name = "(E) Use E", value = false})
    self.Menu:MenuElement({id = "AutoMode", name = "Auto", type = MENU})
    self.Menu:MenuElement({id = "Draw", name = "Draw", type = MENU})
    self.Menu.Draw:MenuElement({id = "UseDraws", name = "Enable Draws", value = false})
    self.Menu.Draw:MenuElement({id = "DrawAA", name = "Draw AA range", value = false})
    self.Menu.Draw:MenuElement({id = "DrawQ", name = "Draw Q range", value = false})
    self.Menu.Draw:MenuElement({id = "DrawE", name = "Draw E range", value = false})
    self.Menu.Draw:MenuElement({id = "DrawR", name = "Draw R range", value = false})
    self.Menu.Draw:MenuElement({id = "DrawCustom", name = "Draw A Custom Range Circle", value = false})
    self.Menu.Draw:MenuElement({id = "DrawCustomRange", name = "Custom Range Circle", value = 500, min = 0, max = 2000, step = 10})
end

function Kled:Spells()
    --ESpellData = {speed = math.huge, range = ERange, delay = 0, angle = 50, radius = 0, collision = {}, type = "conic"}
    ESpellData = {speed = 2000, range = 600, delay = 0, radius = 30, collision = {}, type = "linear"}
    QSpellData = {speed = 2000, range = 750, delay = 0.30, radius = 30, collision = {}, type = "linear"}
    Q2SpellData = {speed = 2000, range = 700, delay = 0.25, radius = 30, collision = {}, type = "linear"}
end


function Kled:Draw()
    if self.Menu.Draw.UseDraws:Value() then
        local AARange = _G.SDK.Data:GetAutoAttackRange(myHero)
        if self.Menu.Draw.DrawAA:Value() then
            Draw.Circle(myHero.pos, AARange, 1, Draw.Color(255, 0, 191, 0))
        end
        if self.Menu.Draw.DrawQ:Value() then
            Draw.Circle(myHero.pos, QRange, 1, Draw.Color(255, 255, 0, 255))
        end
        if self.Menu.Draw.DrawE:Value() then
            Draw.Circle(myHero.pos, ERange, 1, Draw.Color(255, 0, 0, 255))
        end
        if self.Menu.Draw.DrawR:Value() then
            Draw.Circle(myHero.pos, RRange, 1, Draw.Color(255, 255, 255, 255))
        end
        if self.Menu.Draw.DrawCustom:Value() then
            Draw.Circle(myHero.pos, self.Menu.Draw.DrawCustomRange:Value(), 1, Draw.Color(255, 0, 191, 0))
        end
        --InfoBarSprite = Sprite("SeriesSprites\\InfoBar.png", 1)
        --if self.Menu.ComboMode.UseEAA:Value() then
            --Draw.Text("Sticky E On", 10, myHero.pos:To2D().x+5, myHero.pos:To2D().y-130, Draw.Color(255, 0, 255, 0))
            --InfoBarSprite:Draw(myHero.pos:To2D().x,myHero.pos:To2D().y)
        --else
            --Draw.Text("Sticky E Off", 10, myHero.pos:To2D().x+5, myHero.pos:To2D().y-130, Draw.Color(255, 255, 0, 0))
            --InfoBarSprite:Draw(myHero.pos:To2D().x,myHero.pos:To2D().y)
        --end
    end
end



function Kled:Tick()
    if _G.JustEvade and _G.JustEvade:Evading() or (_G.ExtLibEvade and _G.ExtLibEvade.Evading) or Game.IsChatOpen() or myHero.dead then return end
    target = GetTarget(2000)
    AARange = _G.SDK.Data:GetAutoAttackRange(myHero)
    WRange = AARange + 20
    CastingQ = myHero.activeSpell.name == "KledQ"
    CastingW = myHero.activeSpell.name == "KledW"
    CastingE = myHero.activeSpell.name == "KledE"
    CastingR = myHero.activeSpell.name == "KledR"
    if target then
        QBuff = GetBuffExpire(target, "kledqmark")
    end
    if myHero:GetSpellData(_W).ammo > 3 then
        WBuff = false
    else
        WBuff = true
    end
    --PrintChat(myHero:GetSpellData(_W).ammo)
    if myHero:GetSpellData(_Q).name == "KledRiderQ" then
        Mounted = false 
    else
        Mounted = true
    end
    self:UpdateItems()
    self:Logic()
    self:Auto()
    self:Items2()
    self:ProcessSpells()
    if TickW then
        --DelayAction(function() _G.SDK.Orbwalker:__OnAutoAttackReset() end, 0.05)
        TickW = false
    end
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


function Kled:UpdateItems()
    Item_HK[ITEM_1] = HK_ITEM_1
    Item_HK[ITEM_2] = HK_ITEM_2
    Item_HK[ITEM_3] = HK_ITEM_3
    Item_HK[ITEM_4] = HK_ITEM_4
    Item_HK[ITEM_5] = HK_ITEM_5
    Item_HK[ITEM_6] = HK_ITEM_6
    Item_HK[ITEM_7] = HK_ITEM_7
end

function Kled:Items1()
    if GetItemSlot(myHero, 3074) > 0 and ValidTarget(target, 300) then --rave 
        if myHero:GetSpellData(GetItemSlot(myHero, 3074)).currentCd == 0 then
            Control.CastSpell(Item_HK[GetItemSlot(myHero, 3074)])
        end
    end
    if GetItemSlot(myHero, 3077) > 0 and ValidTarget(target, 300) then --tiamat
        if myHero:GetSpellData(GetItemSlot(myHero, 3077)).currentCd == 0 then
            Control.CastSpell(Item_HK[GetItemSlot(myHero, 3077)])
        end
    end
    if GetItemSlot(myHero, 3144) > 0 and ValidTarget(target, 550) then --bilge
        if myHero:GetSpellData(GetItemSlot(myHero, 3144)).currentCd == 0 then
            Control.CastSpell(Item_HK[GetItemSlot(myHero, 3144)], target)
        end
    end
    if GetItemSlot(myHero, 3153) > 0 and ValidTarget(target, 550) then -- botrk
        if myHero:GetSpellData(GetItemSlot(myHero, 3153)).currentCd == 0 then
            Control.CastSpell(Item_HK[GetItemSlot(myHero, 3153)], target)
        end
    end
    if GetItemSlot(myHero, 3146) > 0 and ValidTarget(target, 700) then --gunblade hex
        if myHero:GetSpellData(GetItemSlot(myHero, 3146)).currentCd == 0 then
            Control.CastSpell(Item_HK[GetItemSlot(myHero, 3146)], target)
        end
    end
    if GetItemSlot(myHero, 3748) > 0 and ValidTarget(target, 300) then -- Titanic Hydra
        if myHero:GetSpellData(GetItemSlot(myHero, 3748)).currentCd == 0 then
            Control.CastSpell(Item_HK[GetItemSlot(myHero, 3748)])
        end
    end
end

function Kled:Items2()
    if GetItemSlot(myHero, 3139) > 0 then
        if myHero:GetSpellData(GetItemSlot(myHero, 3139)).currentCd == 0 then
            if IsImmobile(myHero) then
                Control.CastSpell(Item_HK[GetItemSlot(myHero, 3139)], myHero)
            end
        end
    end
    if GetItemSlot(myHero, 3140) > 0 then
        if myHero:GetSpellData(GetItemSlot(myHero, 3140)).currentCd == 0 then
            if IsImmobile(myHero) then
                Control.CastSpell(Item_HK[GetItemSlot(myHero, 3140)], myHero)
            end
        end
    end
end

function Kled:GetPassiveBuffs(unit, buffname)
    for i = 0, unit.buffCount do
        local buff = unit:GetBuff(i)
        if buff.name == buffname and buff.count > 0 then 
            return buff
        end
    end
    return nil
end


function Kled:Auto()
    for i, enemy in pairs(EnemyHeroes) do
        if enemy and not enemy.dead and ValidTarget(enemy) then
        end
    end
end 

function Kled:CanUse(spell, mode)
    if mode == nil then
        mode = Mode()
    end
    --PrintChat(Mode())
    if spell == _Q then
        if mode == "Combo" and IsReady(spell) and self.Menu.ComboMode.UseQ:Value() then
            return true
        end
        if mode == "Combo2" and IsReady(spell) and self.Menu.ComboMode.UseQ2:Value() then
            return true
        end
        if mode == "Harass" and IsReady(spell) and self.Menu.HarassMode.UseQ:Value() then
            return true
        end
        if mode == "Auto" and IsReady(spell) and self.Menu.AutoMode.UseQ:Value() then
            return true
        end
    elseif spell == _R then
        if mode == "Combo" and IsReady(spell) and self.Menu.ComboMode.UseR:Value() then
            return true
        end
        if mode == "Auto" and IsReady(spell) and self.Menu.AutoMode.UseR:Value() then
            return true
        end
    elseif spell == _W then
        if mode == "Combo" and IsReady(spell) and self.Menu.ComboMode.UseW:Value() then
            return true
        end
        if mode == "Harass" and IsReady(spell) and self.Menu.HarassMode.UseW:Value() then
            return true
        end
    elseif spell == _E then
        if mode == "Combo" and IsReady(spell) and self.Menu.ComboMode.UseE:Value() then
            return true
        end
        if mode == "Force" and IsReady(spell) then
            return true
        end
        if mode == "Harass" and IsReady(spell) and self.Menu.HarassMode.UseE:Value() then
            return true
        end
    end
    return false
end

function Kled:Logic()
    if target == nil then 
        if Game.Timer() - TargetTime > 2 then
            WasInRange = false
        end
        return 
    end
    if Mode() == "Combo" or Mode() == "Harass" and target then
        --PrintChat("Logic")
        TargetTime = Game.Timer()
        self:Items1()
        
        if GetDistance(target.pos) < AARange then
            WasInRange = true
        end
        if self:CanUse(_E, Mode()) and ValidTarget(target, ERange) and self:CastingChecks() and not (myHero.pathing and myHero.pathing.isDashing) and not _G.SDK.Attack:IsActive() then
            if not self.Menu.ComboMode.UseEAA:Value() or GetDistance(target.pos) > AARange or self:CanUse(_Q, Mode()) then
                if not WBuff or GetDistance(target.pos) > AARange then
                    self:UseE(target)
                end
            end
        end
        if Mounted and self:CanUse(_Q, Mode()) and not CastingQ and not CastingR and ValidTarget(target, QRange) then
            self:UseQ(target)
        end
        if not Mounted and self:CanUse(_Q, "Combo2") and self:CastingChecks() and not (myHero.pathing and myHero.pathing.isDashing) and not _G.SDK.Attack:IsActive() and ValidTarget(target, Q2Range) then
            if (GetDistance(target.pos) > AARange and myHero:GetSpellData(_Q).ammo == 2) or (myHero.mana > 75 and (myHero:GetSpellData(_W).ammo > 1 or GetDistance(target.pos) > AARange)) or (GetDistance(target.pos) < 50 and not WBuff) then
                self:UseQ2(target)
            end
        end
        if Game.Timer() - TargetTime > 2 then
            WasInRange = false
        end
    end     
end

function Kled:ProcessSpells()
    if myHero:GetSpellData(_W).currentCd == 0 then
        CastedW = false
    else
        if CastedW == false then
            --GotBall = "ECast"
            TickW = true
        end
        CastedW = true
    end
end

function Kled:CastingChecks()
    if not CastingQ and not CastingE and not CastingR then
        return true
    else
        return false
    end
end


function Kled:OnPostAttack(args)

end

function Kled:OnPostAttackTick(args)
end

function Kled:OnPreAttack(args)
end

function Kled:UseQ(unit)
    local pred = _G.PremiumPrediction:GetPrediction(myHero, unit, QSpellData)
    if pred.CastPos and pred.HitChance > self.Menu.ComboMode.UseQHitChance:Value() and myHero.pos:DistanceTo(pred.CastPos) < QRange then
        Control.CastSpell(HK_Q, pred.CastPos)
    end 
end

function Kled:UseQ2(unit)
    local pred = _G.PremiumPrediction:GetPrediction(myHero, unit, Q2SpellData)
    if pred.CastPos and pred.HitChance > self.Menu.ComboMode.UseQ2HitChance:Value() and myHero.pos:DistanceTo(pred.CastPos) < Q2Range then
        Control.CastSpell(HK_Q, pred.CastPos)
    end 
end

function Kled:UseE(unit)
    if self.Menu.ComboMode.UseEFast:Value() then
        Control.CastSpell(HK_E, unit)
    else
        local pred = _G.PremiumPrediction:GetPrediction(myHero, unit, QSpellData)
        if pred.CastPos and pred.HitChance > 0 then
            Control.CastSpell(HK_E, pred.CastPos)
        end
    end 
end

function OnLoad()
    Manager()
end