require "PremiumPrediction"
require "GamsteronPrediction"
require "DamageLib"
require "2DGeometry"
require "MapPositionGOS"

local EnemyHeroes = {}
local AllyHeroes = {}
-- [ AutoUpdate ] --
do
    
    local Version = 600.00
    
    local Files = {
        Lua = {
            Path = SCRIPT_PATH,
            Name = "SeriesV2.lua",
            Url = "https://raw.githubusercontent.com/Impulsx/Series/master/SeriesV2.lua"
        },
        Version = {
            Path = SCRIPT_PATH,
            Name = "SeriesV2.version",
            Url = "https://raw.githubusercontent.com/Impulsx/Series/master/SeriesV2.version"    -- check if Raw Adress correct pls.. after you have create the version file on Github
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

function GetNearestTurret(pos)
    --local turrets = _G.SDK.ObjectManager:GetTurrets(5000)
    local BestDistance = 0
    local BestTurret = nil
    for i = 1, Game.TurretCount() do
        local turret = Game.Turret(i)
        if turret.isAlly then
            local Distance = GetDistance(turret.pos, pos)
            if turret and (Distance < BestDistance or BestTurret == nil) then
                --PrintChat("Set Best Turret")
                BestTurret = turret
                BestDistance = Distance
            end
        end     
    end   
    return BestTurret
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

function GetBuffExpire(unit, buffname)
    for i = 0, unit.buffCount do
        local buff = unit:GetBuff(i)
        if buff.name == buffname and buff.count > 0 then 
            return buff.expireTime
        end
    end
    return nil
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
    if myHero.charName == "Jayce" then
        DelayAction(function() self:LoadJayce() end, 1.05)
    elseif myHero.charName == "Viktor" then
        DelayAction(function() self:LoadViktor() end, 1.05)
    elseif myHero.charName == "Tryndamere" then
        DelayAction(function() self:LoadTryndamere() end, 1.05)
    elseif myHero.charName == "Jax" then
        DelayAction(function() self:LoadJax() end, 1.05)
    elseif myHero.charName == "Neeko" then
        DelayAction(function() self:LoadNeeko() end, 1.05)
    elseif myHero.charName == "Vayne" then
        DelayAction(function() self:LoadVayne() end, 1.05)
    elseif myHero.charName == "Rumble" then
        DelayAction(function() self:LoadRumble() end, 1.05)
    elseif myHero.charName == "Cassiopeia" then
        DelayAction(function() self:LoadCassiopeia() end, 1.05)
    elseif myHero.charName == "Ezreal" then
        DelayAction(function() self:LoadEzreal() end, 1.05)
    elseif myHero.charName == "Corki" then
        DelayAction(function() self:LoadCorki() end, 1.05)
    elseif myHero.charName == "Orianna" then
        DelayAction(function() self:LoadOrianna() end, 1.05)
    end
end

function Manager:LoadCorki()
    Corki:Spells()
    Corki:Menu()
    --
    --GetEnemyHeroes()
    Callback.Add("Tick", function() Corki:Tick() end)
    Callback.Add("Draw", function() Corki:Draw() end)
    if _G.SDK then
        _G.SDK.Orbwalker:OnPreAttack(function(...) Corki:OnPreAttack(...) end)
        _G.SDK.Orbwalker:OnPostAttackTick(function(...) Corki:OnPostAttackTick(...) end)
        _G.SDK.Orbwalker:OnPostAttack(function(...) Corki:OnPostAttack(...) end)
    end
end

function Manager:LoadVayne()
    Vayne:Spells()
    Vayne:Menu()
    --
    --GetEnemyHeroes()
    Callback.Add("Tick", function() Vayne:Tick() end)
    Callback.Add("Draw", function() Vayne:Draw() end)
    if _G.SDK then
        _G.SDK.Orbwalker:OnPreAttack(function(...) Vayne:OnPreAttack(...) end)
        _G.SDK.Orbwalker:OnPostAttackTick(function(...) Vayne:OnPostAttackTick(...) end)
        _G.SDK.Orbwalker:OnPostAttack(function(...) Vayne:OnPostAttack(...) end)
    end
end

function Manager:LoadTryndamere()
    Tryndamere:Spells()
    Tryndamere:Menu()
    --
    --GetEnemyHeroes()
    Callback.Add("Tick", function() Tryndamere:Tick() end)
    Callback.Add("Draw", function() Tryndamere:Draw() end)
    if _G.SDK then
        _G.SDK.Orbwalker:OnPreAttack(function(...) Tryndamere:OnPreAttack(...) end)
        _G.SDK.Orbwalker:OnPostAttackTick(function(...) Tryndamere:OnPostAttackTick(...) end)
        _G.SDK.Orbwalker:OnPostAttack(function(...) Tryndamere:OnPostAttack(...) end)
    end
end

function Manager:LoadJayce()
    Jayce:Spells()
    Jayce:Menu()
    --
    --GetEnemyHeroes()
    Callback.Add("Tick", function() Jayce:Tick() end)
    Callback.Add("Draw", function() Jayce:Draw() end)
    if _G.SDK then
        _G.SDK.Orbwalker:OnPreAttack(function(...) Jayce:OnPreAttack(...) end)
        _G.SDK.Orbwalker:OnPostAttackTick(function(...) Jayce:OnPostAttackTick(...) end)
    end
end

function Manager:LoadNeeko()
    Neeko:Spells()
    Neeko:Menu()
    --
    --GetEnemyHeroes()
    Callback.Add("Tick", function() Neeko:Tick() end)
    Callback.Add("Draw", function() Neeko:Draw() end)
    if _G.SDK then
        _G.SDK.Orbwalker:OnPreAttack(function(...) Neeko:OnPreAttack(...) end)
        _G.SDK.Orbwalker:OnPostAttackTick(function(...) Neeko:OnPostAttackTick(...) end)
    end
end


function Manager:LoadOrianna()
    Orianna:Spells()
    Orianna:Menu()
    --
    --GetEnemyHeroes()
    Callback.Add("Tick", function() Orianna:Tick() end)
    Callback.Add("Draw", function() Orianna:Draw() end)
    if _G.SDK then
        _G.SDK.Orbwalker:OnPreAttack(function(...) Orianna:OnPreAttack(...) end)
        _G.SDK.Orbwalker:OnPostAttackTick(function(...) Orianna:OnPostAttackTick(...) end)
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
    end
end

function Manager:LoadViktor()
    Viktor:Spells()
    Viktor:Menu()
    --
    --GetEnemyHeroes()
    Callback.Add("Tick", function() Viktor:Tick() end)
    Callback.Add("Draw", function() Viktor:Draw() end)
    if _G.SDK then
        _G.SDK.Orbwalker:OnPreAttack(function(...) Viktor:OnPreAttack(...) end)
        _G.SDK.Orbwalker:OnPostAttackTick(function(...) Viktor:OnPostAttackTick(...) end)
    end
end

function Manager:LoadRumble()
    Rumble:Spells()
    Rumble:Menu()
    --
    --GetEnemyHeroes()
    Callback.Add("Tick", function() Rumble:Tick() end)
    Callback.Add("Draw", function() Rumble:Draw() end)
    if _G.SDK then
        _G.SDK.Orbwalker:OnPreAttack(function(...) Rumble:OnPreAttack(...) end)
        _G.SDK.Orbwalker:OnPostAttackTick(function(...) Rumble:OnPostAttackTick(...) end)
    end
end

function Manager:LoadCassiopeia()
    Cassiopeia:Spells()
    Cassiopeia:Menu()
    --
    --GetEnemyHeroes()
    Callback.Add("Tick", function() Cassiopeia:Tick() end)
    Callback.Add("Draw", function() Cassiopeia:Draw() end)
    if _G.SDK then
        _G.SDK.Orbwalker:OnPreAttack(function(...) Cassiopeia:OnPreAttack(...) end)
        _G.SDK.Orbwalker:OnPostAttackTick(function(...) Cassiopeia:OnPostAttackTick(...) end)
    end
end

function Manager:LoadEzreal()
    Ezreal:Spells()
    Ezreal:Menu()
    --
    --GetEnemyHeroes()
    Callback.Add("Tick", function() Ezreal:Tick() end)
    Callback.Add("Draw", function() Ezreal:Draw() end)
    if _G.SDK then
        _G.SDK.Orbwalker:OnPreAttack(function(...) Ezreal:OnPreAttack(...) end)
        _G.SDK.Orbwalker:OnPostAttackTick(function(...) Ezreal:OnPostAttackTick(...) end)
    end
end

class "Cassiopeia"

local EnemyLoaded = false
local casted = 0
local Qtick = true

local CastedE = false
local TickE = false
local TimeE = 0

local CastingQ = false
local CastingW = false
local CastingE = false
local Direction = nil
local CastingR = false
local QRange = 850
local WRange = 700
local ERange = 700
local RRange = 825
local WasInRange = false
local attacked = 0

function Cassiopeia:Menu()
    self.Menu = MenuElement({type = MENU, id = "Cassiopeia", name = "Cassiopeia"})
    self.Menu:MenuElement({id = "UltKey", name = "Manual R Key", key = string.byte("T"), value = false})
    self.Menu:MenuElement({id = "ComboMode", name = "Combo", type = MENU})
    self.Menu.ComboMode:MenuElement({id = "UseQ", name = "Use Q in Combo", value = true})
    self.Menu.ComboMode:MenuElement({id = "UseW", name = "Use W in Combo", value = true})
    self.Menu.ComboMode:MenuElement({id = "UseE", name = "Use E in Combo", value = true})
    self.Menu.ComboMode:MenuElement({id = "UseEDisableAA", name = "Disable AA's For E", value = true})
    self.Menu.ComboMode:MenuElement({id = "UseR", name = "Use R in Combo", value = true})
    self.Menu:MenuElement({id = "HarassMode", name = "Harass", type = MENU})
    self.Menu.HarassMode:MenuElement({id = "UseQ", name = "Use Q in Harass", value = true})
    self.Menu.HarassMode:MenuElement({id = "UseW", name = "Use W in Harass", value = false})
    self.Menu.HarassMode:MenuElement({id = "UseE", name = "Use E in Harass", value = true})
    self.Menu:MenuElement({id = "AutoMode", name = "Auto", type = MENU})
    self.Menu:MenuElement({id = "KSMode", name = "KS", type = MENU})
    self.Menu.KSMode:MenuElement({id = "UseQ", name = "Use W in Combo", value = true})
    self.Menu.KSMode:MenuElement({id = "UseE", name = "Use E in Combo", value = true})
    self.Menu:MenuElement({id = "Draw", name = "Draw", type = MENU})
    self.Menu.Draw:MenuElement({id = "UseDraws", name = "Enable Draws", value = false})
end

function Cassiopeia:Spells()
    QSpellData = {speed = math.huge, range = 850, delay = 0.65, radius = 50, collision = {}, type = "circular"}
    WSpellData = {speed = 1600, range = 700, delay = 0.25, angle = 80, radius = 0, collision = {}, type = "conic"}
    RSpellData = {speed = math.huge, range = 825, delay = 0.5, angle = 80, radius = 0, collision = {}, type = "conic"}
end

function Cassiopeia:Tick()
    if _G.JustEvade and _G.JustEvade:Evading() or (_G.ExtLibEvade and _G.ExtLibEvade.Evading) or Game.IsChatOpen() or myHero.dead then return end
    target = GetTarget(2000)
    CastingQ = myHero.activeSpell.name == "CassiopeiaQ"
    CastingW = myHero.activeSpell.name == "CassiopeiaW"
    CastingE = myHero.activeSpell.name == "CassiopeiaE"
    CastingR = myHero.activeSpell.name == "CassiopeiaR" 
    --PrintChat(myHero.activeSpell.name)
    self:ProcessSpells()
    self:Logic()
    self:Auto()
    if Mode() == "Combo" and myHero.mana > 50 and myHero:GetSpellData(_E).level > 0 and self.Menu.ComboMode.UseEDisableAA:Value() then
        _G.SDK.Orbwalker:SetAttack(false)
    else
        _G.SDK.Orbwalker:SetAttack(true)
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

function Cassiopeia:Draw()
    if self.Menu.Draw.UseDraws:Value() then
    end
end

function Cassiopeia:ProcessSpells()
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

function Cassiopeia:CanUse(spell, mode)
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
        if mode == "KS" and IsReady(spell) and self.Menu.KSMode.UseQ:Value() then
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
        if mode == "Harass" and IsReady(spell) and self.Menu.HarassMode.UseE:Value() then
            return true
        end
        if mode == "KS" and IsReady(spell) and self.Menu.KSMode.UseE:Value() then
            return true
        end
    elseif spell == _R then
        if mode == "Combo" and IsReady(spell) and self.Menu.ComboMode.UseR:Value() then
            return true
        end
    end
    return false
end

function Cassiopeia:Auto()
    for i, enemy in pairs(EnemyHeroes) do
        if enemy and not enemy.dead and ValidTarget(enemy) then
            if self:CanUse(_Q, "KS") and ValidTarget(enemy, QRange) then
                local Qdmg = getdmg("Q", enemy, myHero)
                local Edmg = getdmg("E", enemy, myHero)
                if enemy.health < Qdmg + Edmg then
                    self:UseQ(enemy)
                end
            end
            if self:CanUse(_E, "KS") and ValidTarget(enemy, ERange) then
                local Edmg = getdmg("E", enemy, myHero)
                if enemy.health < Edmg then
                    Control.CastSpell(HK_E, enemy)
                end
            end
        end
    end
end


function Cassiopeia:Logic()
    if target == nil then return end
    if Mode() == "Combo" or Mode() == "Harass" and target and ValidTarget(target) then
        local Poisoned = self:GetBuffPosion(target)
        local AARange = _G.SDK.Data:GetAutoAttackRange(myHero)
        if GetDistance(target.pos) < AARange then
            WasInRange = true
        end
        local NotCastingSpell = not CastingQ and not CastingW and not CastingE and not CastingR
        if self:CanUse(_Q, Mode()) and ValidTarget(target, QRange) and NotCastingSpell and not (myHero.pathing and myHero.pathing.isDashing) and not _G.SDK.Attack:IsActive() and not Poisoned then
            self:UseQ(target)
        end
        if self:CanUse(_E, Mode()) and ValidTarget(target, ERange) and NotCastingSpell and not (myHero.pathing and myHero.pathing.isDashing) then
            Control.CastSpell(HK_E, target)
        end
        if self:CanUse(_W, Mode()) and ValidTarget(target, WRange) and NotCastingSpell and not (myHero.pathing and myHero.pathing.isDashing) and not _G.SDK.Attack:IsActive() and not Poisoned then
            if not self:CanUse(_Q, Mode()) then
                self:UseW(target)
            end
        end
        local targetHealthPercent = target.health / target.maxHealth
        if self:CanUse(_R, Mode()) and ValidTarget(target, RRange) and NotCastingSpell and not (myHero.pathing and myHero.pathing.isDashing) and IsFacing(target) and (targetHealthPercent < 0.7 or GetDistance(target.pos) < 650) then
            self:UseR(target)
        end
    else
        WasInRange = false
    end     
end



function Cassiopeia:OnPostAttack(args)
end

function Cassiopeia:OnPostAttackTick(args)
end

function Cassiopeia:OnPreAttack(args)
end

function Cassiopeia:GetBuffPosion(unit)
    for i = 0, unit.buffCount do
        local buff = unit:GetBuff(i)
        if buff.type == 24 and Game.Timer() < buff.expireTime - 0.1 then 
            return true
        end
    end
    return false
end

function Cassiopeia:UseQ(unit)
    local pred = _G.PremiumPrediction:GetAOEPrediction(myHero, unit, QSpellData)
    if pred.CastPos and pred.HitChance > 0 then
        Control.CastSpell(HK_Q, pred.CastPos)
    end
end

function Cassiopeia:UseW(unit)
    local pred = _G.PremiumPrediction:GetAOEPrediction(myHero, unit, WSpellData)
    if pred.CastPos and pred.HitChance > 0 then
        Control.CastSpell(HK_W, pred.CastPos)
    end
end

function Cassiopeia:UseR(unit)
    local pred = _G.PremiumPrediction:GetAOEPrediction(myHero, unit, RSpellData)
    if pred.CastPos and pred.HitChance > 0 then
        Control.CastSpell(HK_R, pred.CastPos)
    end
end


class "Rumble"

local EnemyLoaded = false
local casted = 0
local Qtick = true
local HeatTime = 0
local CastingQ = false
local CastingW = false
local CastingE = false
local CastingR = false
local QRange = 600
local ERange = 850
local RRange = 1700
local Item_HK = {}
local WasInRange = false
local attacked = 0
local QBuff = false
local CanQ = true 
local QtickTime = 0

function Rumble:Menu()
    self.Menu = MenuElement({type = MENU, id = "Rumble", name = "Rumble"})
    self.Menu:MenuElement({id = "RKey", name = "Manual R Key", key = string.byte("T"), value = false})
    self.Menu:MenuElement({id = "ComboMode", name = "Combo", type = MENU})
    self.Menu.ComboMode:MenuElement({id = "OverHeatInfo", name = "Overheat Options Ignored If Killable", type = SPACE})
    self.Menu.ComboMode:MenuElement({id = "UseQ", name = "Use Q in Combo", value = true})
    self.Menu.ComboMode:MenuElement({id = "OverHeatQ", name = "Allow Q to Overheat", value = true})
    self.Menu.ComboMode:MenuElement({id = "UseW", name = "Use W in Combo", value = true})
    self.Menu.ComboMode:MenuElement({id = "UseWurf", name = "Use Urf W", value = true})
    self.Menu.ComboMode:MenuElement({id = "OverHeatW", name = "Allow W to Overheat", value = false})
    self.Menu.ComboMode:MenuElement({id = "UseE", name = "Use E in Combo", value = true})
    self.Menu.ComboMode:MenuElement({id = "UseEHitChance", name = "E Hit Chance (0.15)", value = 0.10, min = 0, max = 1.0, step = 0.05})
    self.Menu.ComboMode:MenuElement({id = "OverHeatE", name = "Allow E to Overheat", value = false})
    self.Menu.ComboMode:MenuElement({id = "UseR", name = "Use R in Combo", value = true})
    self.Menu.ComboMode:MenuElement({id = "OverHeatR", name = "Allow R to Overheat", value = true})
    self.Menu:MenuElement({id = "HarassMode", name = "Harass", type = MENU})
    self.Menu.HarassMode:MenuElement({id = "OverHeatInfo", name = "Overheat Options Ignored If Killable", type = SPACE})
    self.Menu.HarassMode:MenuElement({id = "UseQ", name = "Use Q in Harass", value = true})
    self.Menu.HarassMode:MenuElement({id = "OverHeatQ", name = "Allow Q to Overheat", value = true})
    self.Menu.HarassMode:MenuElement({id = "UseE", name = "Use E in Harass", value = true})
    self.Menu.HarassMode:MenuElement({id = "OverHeatQ", name = "Allow E to Overheat", value = false})
    self.Menu:MenuElement({id = "AutoMode", name = "Danger Zone", type = MENU})
    self.Menu.AutoMode:MenuElement({id = "Above50", name = "Keep Heat Above 50", value = true})
    self.Menu.AutoMode:MenuElement({id = "Above50Info", name = "(1st-4th)(0 off) Only When An Enemy Around", type = SPACE})
    self.Menu.AutoMode:MenuElement({id = "UseQ", name = "Q Priority", value = 4, min = 0, max = 4, step = 1})
    self.Menu.AutoMode:MenuElement({id = "UseW", name = "W Priority", value = 2, min = 0, max = 4, step = 1})
    self.Menu.AutoMode:MenuElement({id = "UseE", name = "(1 left) E Priority", value = 3, min = 0, max = 4, step = 1})
    self.Menu.AutoMode:MenuElement({id = "UseE2", name = "(2 left) E Priority", value = 1, min = 0, max = 4, step = 1})
    self.Menu:MenuElement({id = "KSMode", name = "Kill Steal", type = MENU})
    self.Menu.KSMode:MenuElement({id = "UseE", name = "Use E to KS", value = true})
    self.Menu.KSMode:MenuElement({id = "UseR", name = "Use R to KS", value = false})
    self.Menu.KSMode:MenuElement({id = "UseRtick", name = "Number of R Ticks", value = 4, min = 1, max = 12, step = 1})
    self.Menu:MenuElement({id = "Draw", name = "Draw", type = MENU})
    self.Menu.Draw:MenuElement({id = "UseDraws", name = "Enable Draws", value = false})
end

function Rumble:Spells()
    ESpellData = {speed = 1200, range = 885, delay = 0.1515, radius = 70, collision = {}, type = "linear"}
    ESpellDataC = {speed = 1200, range = 885, delay = 0.1515, radius = 70, collision = {"minion"}, type = "linear"}
    RSpellData = {speed = 1200, range = 1700, delay = 1.0, radius = 150, collision = {}, type = "linear"}
end


function Rumble:Draw()
    if self.Menu.Draw.UseDraws:Value() then
        local AARange = _G.SDK.Data:GetAutoAttackRange(myHero)
        Draw.Circle(myHero.pos, AARange, 1, Draw.Color(255, 0, 191, 255))
    end
end


function Rumble:Tick()
    if _G.JustEvade and _G.JustEvade:Evading() or (_G.ExtLibEvade and _G.ExtLibEvade.Evading) or Game.IsChatOpen() or myHero.dead then return end
    target = GetTarget(2000)
    CastingE = myHero.activeSpell.name == "RumbleGrenade"
    CastingR = myHero.activeSpell.name == "RumbleCarpetBombDummy"
    if not IsReady(_R) then
        Rdown = false
    end
    if Rdown == true then
        _G.SDK.Orbwalker:SetMovement(false)
    else
        _G.SDK.Orbwalker:SetMovement(true)
    end
    --PrintChat(myHero.activeSpell.name)
    --PrintChat(myHero.activeSpell.speed)
    QBuff = BuffActive(myHero, "UndyingRage")
    if self.Menu.RKey:Value() then
        self:ManualRCast()
    end
    --PrintChat(myHero.activeSpellSlot)
    self:UpdateItems()
    self:Logic()
    self:Auto()
    self:Items2()
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


function Rumble:UpdateItems()
    Item_HK[ITEM_1] = HK_ITEM_1
    Item_HK[ITEM_2] = HK_ITEM_2
    Item_HK[ITEM_3] = HK_ITEM_3
    Item_HK[ITEM_4] = HK_ITEM_4
    Item_HK[ITEM_5] = HK_ITEM_5
    Item_HK[ITEM_6] = HK_ITEM_6
    Item_HK[ITEM_7] = HK_ITEM_7
end

function Rumble:Items1()
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

function Rumble:Items2()
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


function Rumble:ManualRCast()
    local AARange = _G.SDK.Data:GetAutoAttackRange(myHero)
    local ERange = 660 + AARange
    if target then
        if ValidTarget(target, ERange) then
            self:UseE(target)
        end
    else
        for i, enemy in pairs(EnemyHeroes) do
            if enemy and not enemy.dead and ValidTarget(enemy, ERange) then
                if not (myHero.pathing and myHero.pathing.isDashing) and IsReady(_E) then
                    self:UseE(enemy)
                end
            end
        end
    end
end

function Rumble:Auto()
    for i, enemy in pairs(EnemyHeroes) do
        if enemy and not enemy.dead and ValidTarget(enemy) then
            if Mode() == "Combo" then
                if self:CanUse(_W, Mode()) and ValidTarget(enemy, 1500) and not CastingE and not CastingR and Rdown == false then
                    if self.Menu.ComboMode.UseW:Value() then
                        if myHero.mana < 80 or self.Menu.ComboMode.OverHeatW:Value() or myHero.health < 100 then
                            if self:IncomingAttack(enemy) then
                                Control.CastSpell(HK_W)
                            end
                        end
                    end
                end
            end
            if self.Menu.AutoMode.Above50:Value() then
                local delay = 2.0
                if Game.Timer() - HeatTime > delay and myHero.mana > 30 then 
                    for i = 1, 4 do
                        if Game.Timer() - HeatTime > delay and self:CanUse(_Q, "Force") and self.Menu.AutoMode.UseQ:Value() == i and GetDistance(enemy.pos) < 1500 and not CastingE and not CastingR and Rdown == false then
                            if myHero.mana < 60 then
                                Control.CastSpell(HK_Q)
                                HeatTime = Game.Timer()
                                break
                            end
                        end
                        if Game.Timer() - HeatTime > delay and self:CanUse(_W, "Force") and self.Menu.AutoMode.UseW:Value() == i and GetDistance(enemy.pos) < 1500 and not CastingE and not CastingR and Rdown == false then
                            if myHero.mana < 60 then
                                Control.CastSpell(HK_W)
                                --PrintChat("Heat manager W")
                                HeatTime = Game.Timer()
                                break
                            end
                        end
                        if Game.Timer() - HeatTime > delay and self:CanUse(_E, "Force") and self.Menu.AutoMode.UseE:Value() == i and GetDistance(enemy.pos) < ERange and not CastingE and not CastingR and Rdown == false then
                            if myHero.mana < 60 and myHero:GetSpellData(_E).ammo == 1 then
                                self:UseE(enemy)
                                HeatTime = Game.Timer()
                                break
                            end
                        end
                        if Game.Timer() - HeatTime > delay and self:CanUse(_E, "Force") and self.Menu.AutoMode.UseE2:Value() == i and GetDistance(enemy.pos) < ERange and not CastingE and not CastingR and Rdown == false then
                            if myHero.mana < 60 and myHero:GetSpellData(_E).ammo == 2 then
                                self:UseE(enemy)
                                HeatTime = Game.Timer()
                                break
                            end
                        end
                    end
                end
            end
            if self.Menu.KSMode.UseE:Value() and self:CanUse(_E, "KS") and GetDistance(enemy.pos) < ERange and not CastingE and not CastingR and Rdown == false then
                local Edmg = getdmg("E", enemy, myHero)
                if myHero.mana > 40 then
                    Edmg = Edmg * 1.5
                end
                if enemy.health < Edmg then
                    self:UseE(enemy, true)
                end
            end
            if self.Menu.KSMode.UseR:Value() and self:CanUse(_R, "KS") and GetDistance(enemy.pos) < 1700 and not CastingE and not CastingR then
                local ticks = self.Menu.KSMode.UseRtick:Value()
                local Rdmg = getdmg("R", enemy, myHero)
                if enemy.health < Rdmg * ticks then
                    self:UseR(enemy)
                end
            end
        end
    end
end 


function Rumble:CanUse(spell, mode)
    if mode == nil then
        mode = Mode()
    end
    --PrintChat(Mode())
    if spell == _Q then
        if mode == "Combo" and IsReady(spell) and self.Menu.ComboMode.UseQ:Value() then
            return true
        end
        if mode == "KS" and IsReady(spell) and self.Menu.KSMode.UseQ:Value() then
            return true
        end
        if mode == "Auto" and IsReady(spell) then
            return true
        end
        if mode == "Force" and IsReady(spell) then
            return true
        end
    elseif spell == _W then
        if mode == "Combo" and IsReady(spell) and self.Menu.ComboMode.UseW:Value() then
            return true
        end
        if mode == "Auto" and IsReady(spell) then
            return true
        end
        if mode == "Force" and IsReady(spell) then
            return true
        end
    elseif spell == _E then
        if mode == "Combo" and IsReady(spell) and self.Menu.ComboMode.UseE:Value() then
            return true
        end
        if mode == "KS" and IsReady(spell) and self.Menu.KSMode.UseE:Value() then
            return true
        end
        if mode == "Auto" and IsReady(spell) then
            return true
        end
        if mode == "Force" and IsReady(spell) then
            return true
        end
    elseif spell == _R then
        if mode == "Combo" and IsReady(spell) and self.Menu.ComboMode.UseR:Value() then
            return true
        end
        if mode == "KS" and IsReady(spell) and self.Menu.KSMode.UseR:Value() then
            return true
        end
        if mode == "Force" and IsReady(spell) then
            return true
        end
    end
    return false
end



function Rumble:Logic()
    if target == nil then return end
    --PrintChat(target.activeSpell.target)
    if myHero.handle == target.activeSpell.target then
        --PrintChat(target.activeSpellSlot)
        --PrintChat("At me!")
    end
    if Mode() == "Combo" or Mode() == "Harass" and target then
        self:Items1()
        local AARange = _G.SDK.Data:GetAutoAttackRange(myHero)
        if GetDistance(target.pos) < AARange then
            WasInRange = true
        end
        local EAARange = _G.SDK.Data:GetAutoAttackRange(target)
        if self:CanUse(_R, Mode()) and ValidTarget(target, 1700) and not CastingE and not CastingR then
            if self.Menu.ComboMode.UseR:Value() then
                local Rdmg = getdmg("R", target, myHero)
                local ticks = 4
                if GetDistance(target.pos, myHero.pos) < 1050 and IsReady(_E) then
                    ticks = ticks + 2
                end
                if GetDistance(target.pos, myHero.pos) < 700 and IsReady(_Q) then
                    ticks = ticks + 2
                end
                if GetDistance(target.pos, myHero.pos) < 600 and IsReady(_E) and IsReady(_Q) then
                    ticks = ticks + 1
                end
                if target.health < Rdmg * ticks and target.health > Rdmg * ticks/2 then
                    self:UseR(target)
                end
            end
        end
        if self:CanUse(_Q, Mode()) and ValidTarget(target, QRange) and not CastingE and not CastingR and Rdown == false then
            if self.Menu.ComboMode.UseQ:Value() then
                local Qdmg = getdmg("Q", target, myHero)
                if myHero.mana < 80 or self.Menu.ComboMode.OverHeatQ:Value() or target.health < Qdmg*1.5 then
                    if myHero.mana == 80 then
                        if self.Menu.ComboMode.UseE:Value() and self:CanUse(_E, Mode()) and ValidTarget(target, ERange) then
                            self:UseE(target, true)
                        end
                    end
                    --PrintChat(myHero.mana)
                    Control.CastSpell(HK_Q)
                end
            end
        end
        if self:CanUse(_E, Mode()) and ValidTarget(target, ERange) and not CastingE and not CastingR and Rdown == false then
            if self.Menu.ComboMode.UseE:Value() then
                local Edmg = getdmg("E", target, myHero)
                if myHero.mana < 90 or self.Menu.ComboMode.OverHeatE:Value() or target.health < Edmg*1.5 then
                    self:UseE(target, true)
                end
            end
        end
        if self:CanUse(_W, Mode()) and not CastingE and not CastingR and Rdown == false then
            if self.Menu.ComboMode.UseWurf:Value() then
                Control.CastSpell(HK_W)
            end
        end
    else
        WasInRange = false
    end     
end

function Rumble:UseR(unit)
    if GetDistance(unit.pos, myHero.pos) < 1700 then
        --PrintChat("Using E")
        local Direction = Vector((myHero.pos-unit.pos):Normalized())
        local Rspot = myHero.pos - Direction*700
        if GetDistance(myHero.pos, unit.pos) < 700 then
            Rspot = myHero.pos
        end
        --Control.SetCursorPos(Espot)
        --Control.CastSpell(HK_E, unit)
        local pred = _G.PremiumPrediction:GetPrediction(Rspot, unit, RSpellData)
        if pred.CastPos and _G.PremiumPrediction.HitChance.Low(pred.HitChance) and Rspot:DistanceTo(pred.CastPos) < 1000 then
            if Control.IsKeyDown(HK_R) and Rdown == true then
                --_G.SDK.Orbwalker:SetMovement(false)
                --PrintChat("E down")
                _G.SDK.Orbwalker:SetMovement(false)
                self:UseR2(Rspot, unit, pred)
            elseif Rdown == false and Mode() == "Combo" then
                ReturnMouse = mousePos
                Control.SetCursorPos(Rspot)
                Control.KeyDown(HK_R)
                Rdown = true
                _G.SDK.Orbwalker:SetMovement(false)
                --self:UseR2(Rspot, unit, pred)
            end
        end
    end
end

function Rumble:UseR2(RCastPos, unit, pred)
    if Control.IsKeyDown(HK_R) then
        local Direction = Vector((RCastPos-pred.CastPos):Normalized())
        local EndSpot = RCastPos - Direction*300
        Control.SetCursorPos(EndSpot)
        --PrintChat("Returned Mouse")
        Control.KeyUp(HK_R)
        --DelayAction(function() Control.KeyUp(HK_R) end, 0.05)
        DelayAction(function() Control.SetCursorPos(ReturnMouse) end, 0.01)
        DelayAction(function() Rdown = false end, 0.50)   
    end
end

--[[function Rumble:UseR2(RCastPos, unit, pred)
    if Control.IsKeyDown(HK_R) then
        local Direction = Vector((unit.pos-RCastPos):Normalized())
        local EndSpot = unit.pos - Direction*300
        Control.SetCursorPos(EndSpot)
        PrintChat("Returned Mouse")
        Control.KeyUp(HK_R)
        --DelayAction(function() Control.KeyUp(HK_R) end, 0.05)
        DelayAction(function() Control.SetCursorPos(ReturnMouse) end, 0.01)
        DelayAction(function() Rdown = false end, 0.50)   
    end
end--]]

function Rumble:IncomingAttack(unit)
    if unit.activeSpell.target == myHero.handle then
        return true
    else
        if unit.activeSpell.name == unit:GetSpellData(_Q).name then
            if unit.activeSpell.target == myHero.handle or GetDistance(unit.activeSpell.placementPos) < 200 then
                return true
            end
        elseif unit.activeSpell.name == unit:GetSpellData(_W).name then
            if unit.activeSpell.target == myHero.handle or GetDistance(unit.activeSpell.placementPos) < 200 then
                return true
            end
            if unit.activeSpell.target == myHero.handle or GetDistance(unit.activeSpell.placementPos) < 200 then
                return true
            end
        elseif unit.activeSpell.name == unit:GetSpellData(_R).name then
            if unit.activeSpell.target == myHero.handle or GetDistance(unit.activeSpell.placementPos) < 200 then
                return true
            end
        end
    end
    return false
end

function Rumble:OnPostAttack(args)
end

function Rumble:OnPostAttackTick(args)
end

function Rumble:OnPreAttack(args)
end

function Rumble:UseE(unit, Collision)
    if IsReady(_E) then
        local pred = _G.PremiumPrediction:GetPrediction(myHero, unit, ESpellData)
        if Collision then
            pred = _G.PremiumPrediction:GetPrediction(myHero, unit, ESpellDataC)
        end
        if pred.CastPos and pred.HitChance > self.Menu.ComboMode.UseEHitChance:Value() and myHero.pos:DistanceTo(pred.CastPos) < 900 then
            if IsReady(_E) then
                Control.CastSpell(HK_E, pred.CastPos)
            end
        end 
    end
end

class "Tryndamere"

local EnemyLoaded = false
local TargetTime = 0
local Dashed = true
local casted = 0
local Qtick = true
local CastingQ = false
local CastingW = false
local CastingE = false
local CastingR = false
local Item_HK = {}
local WasInRange = false
local attacked = 0
local RBuff = false
local CanQ = true 
local QtickTime = 0
local ClosestTurret = nil
local attacks = 0
local PossibleSpots = {}
local WAround = 0
local InsertedTime = Game.Timer()

function Tryndamere:Menu()
    self.Menu = MenuElement({type = MENU, id = "Tryndamere", name = "Tryndamere"})
    self.Menu:MenuElement({id = "EKey", name = "Manual E Key", key = string.byte("T"), value = false})
    self.Menu:MenuElement({id = "ComboMode", name = "Combo", type = MENU})
    self.Menu.ComboMode:MenuElement({id = "UseQ", name = "(Q) Use Q on Low HP", value = false})
    self.Menu.ComboMode:MenuElement({id = "UseQHealth", name = "(Q) Min Health %:", value = 10, min = 0, max = 100, step = 1})
    self.Menu.ComboMode:MenuElement({id = "UseQFury", name = "(Q) Min Fury:", value = 50, min = 0, max = 100, step = 5})
    self.Menu.ComboMode:MenuElement({id = "UseQUlt", name = "(Q) Use At the End of Ult", value = true})
    self.Menu.ComboMode:MenuElement({id = "UseQUltHealth", name = "(Q) At end of Ult Min Health %:", value = 10, min = 0, max = 100, step = 1})
    self.Menu.ComboMode:MenuElement({id = "UseW", name = "(W) Enabled", value = true})
    self.Menu.ComboMode:MenuElement({id = "UseE", name = "(E) Enabled", value = true})
    self.Menu.ComboMode:MenuElement({id = "UseEGapClose", name = "(E) GapClose: Use E to Get in Range", value = true})
    self.Menu.ComboMode:MenuElement({id = "UseESticky", name = "(E) Sticky: Save E to Stick to Attacked Targets", key = string.byte("A"), toggle = true, value = true})
    self.Menu.ComboMode:MenuElement({id = "UseEFast", name = "(E) Fast: No Prediction E", value = true})
    self.Menu.ComboMode:MenuElement({id = "UseR", name = "(R) Enabled", value = true})
    self.Menu.ComboMode:MenuElement({id = "UseRHealth", name = "(R) Min Health %:", value = 10, min = 0, max = 100, step = 1})
    self.Menu.ComboMode:MenuElement({id = "RInfo", name = "(R) Ignores Min % if there is Incoming Damage", type = MENU})
    self.Menu:MenuElement({id = "HarassMode", name = "Harass", type = MENU})
    self.Menu.HarassMode:MenuElement({id = "UseQ", name = "Use Q in Combo", value = true})
    self.Menu.HarassMode:MenuElement({id = "UseW", name = "Use W in Combo", value = true})
    self.Menu.HarassMode:MenuElement({id = "UseE", name = "Use E in Combo", value = true})
    self.Menu.HarassMode:MenuElement({id = "UseDashBack", name = "DashBack: Dash Back after attacking", key = string.byte("J"), toggle = true, value = true})
    self.Menu.HarassMode:MenuElement({id = "DashBackAttacks", name = "No Of Attacks Before DashBack", value = 1, min = 0, max = 5, step = 1})
    self.Menu.HarassMode:MenuElement({id = "UseR", name = "Use R in Combo", value = true})
    self.Menu:MenuElement({id = "AutoMode", name = "Auto", type = MENU})
    self.Menu.AutoMode:MenuElement({id = "UseQ", name = "Use Auto Q", value = false})
    self.Menu.AutoMode:MenuElement({id = "UseQHealth", name = "Q Min Health %", value = 10, min = 0, max = 100, step = 1})
    self.Menu.AutoMode:MenuElement({id = "UseQFury", name = "Q Min Fury", value = 50, min = 0, max = 100, step = 5})
    self.Menu.AutoMode:MenuElement({id = "UseQUlt", name = "(Q) Use At the End of Ult", value = true})
    self.Menu.AutoMode:MenuElement({id = "UseQUltHealth", name = "(Q) At end of Ult Min Health %:", value = 10, min = 0, max = 100, step = 1})
    self.Menu.AutoMode:MenuElement({id = "UseR", name = "Use Auto R", value = true})
    self.Menu.AutoMode:MenuElement({id = "UseRHealth", name = "R Min Health %", value = 10, min = 0, max = 100, step = 1})
    self.Menu.AutoMode:MenuElement({id = "RInfo2", name = "(R) Ignores Min % if there is Incoming Damage", type = MENU})
    self.Menu:MenuElement({id = "Draw", name = "Draw", type = MENU})
    self.Menu.Draw:MenuElement({id = "UseDraws", name = "Enable Draws", value = false})
    self.Menu.Draw:MenuElement({id = "WScan", name = "Draw Potentential Hidden Enemies", value = false})
    self.Menu.Draw:MenuElement({id = "DashBack", name = "Draw If DashBack Is On", value = false})
    self.Menu.Draw:MenuElement({id = "ESticky", name = "Draw If StickyE Is On", value = false})
    self.Menu.Draw:MenuElement({id = "AArange", name = "Draw AA Range", value = false})
end

function Tryndamere:Spells()
    ESpellData = {speed = 1200, range = 885, delay = 0.1515, radius = 70, collision = {}, type = "linear"}
end


function Tryndamere:Draw()
    if self.Menu.Draw.UseDraws:Value() then
        local AARange = _G.SDK.Data:GetAutoAttackRange(myHero)
        if self.Menu.Draw.AArange:Value() then 
            Draw.Circle(myHero.pos, AARange, 1, Draw.Color(255, 0, 191, 255))
        end
        if self.Menu.Draw.WScan:Value() then
            self:WScan()
        end
        --InfoBarSprite = Sprite("SeriesSprites\\InfoBar.png", 1)
        if self.Menu.Draw.DashBack:Value() then
            if self.Menu.HarassMode.UseDashBack:Value() then
                Draw.Text("Dash Back On", 10, myHero.pos:To2D().x, myHero.pos:To2D().y-120, Draw.Color(255, 0, 255, 0))
            else
                Draw.Text("Dash Back Off", 10, myHero.pos:To2D().x, myHero.pos:To2D().y-120, Draw.Color(255, 255, 0, 0))
            end
        end

        if self.Menu.Draw.ESticky:Value() then
            if self.Menu.ComboMode.UseESticky:Value() then
                Draw.Text("Sticky E On", 10, myHero.pos:To2D().x+5, myHero.pos:To2D().y-130, Draw.Color(255, 0, 255, 0))
                --InfoBarSprite:Draw(myHero.pos:To2D().x,myHero.pos:To2D().y)
            else
                Draw.Text("Sticky E Off", 10, myHero.pos:To2D().x+5, myHero.pos:To2D().y-130, Draw.Color(255, 255, 0, 0))
                --InfoBarSprite:Draw(myHero.pos:To2D().x,myHero.pos:To2D().y)
            end
        end
    end
end


function Tryndamere:WScan()
    local spell = _W
    --PrintChat(Game.CanUseSpell(spell))
    --PrintChat(WAround)
    if myHero:GetSpellData(spell).level > 0 then
        if Game.CanUseSpell(spell) == 0 or Game.CanUseSpell(spell) == 32 and WAround == 0 then
            if FoundETarget == false then
                --PrintChat("Found New E Target")
                local TargetDirection = Vector((myHero.pos-mousePos):Normalized())
                for i = 0, 360, 1 do
                    local NewTargetDirection = TargetDirection:Rotated(0,math.rad(i),0)
                    local TargetSpot = myHero.pos - NewTargetDirection * 800
                    if MapPosition:inBush(TargetSpot) then
                        --Draw.Circle(TargetSpot, 150, 1, Draw.Color(255, 255, 100, 255))
                        table.insert(PossibleSpots, {Spot = TargetSpot, Insterted = Game.Timer()})
                    end
                end
                InsertedTime = Game.Timer()
            end
            FoundETarget = true
        end
        if Game.CanUseSpell(spell) == 8 or Game.CanUseSpell(spell) == 40 then
            FoundETarget = false
        end
    end
    self:ClearSpots()
    if #PossibleSpots > 0 and WAround == 0 then
        for i = 1, #PossibleSpots do
            Draw.Circle(PossibleSpots[i].Spot, 50, 1, Draw.Color(255, 255, 100, 255))
        end
    end
end

function Tryndamere:ClearSpots()
    if #PossibleSpots > 0 then
        for i = #PossibleSpots, 1, -1 do
            if Game.Timer() - PossibleSpots[i].Insterted > 1.5 then
                table.remove(PossibleSpots,i)
            end
        end
    end
end

--[[function Q2(pr)
    for i= -math.pi*.5 ,math.pi*.5 ,math.pi*.09 do
        local one = 25.79618 * math.pi/180
        local an = myHero.pos + Vector(Vector(pr)-myHero.pos):Rotated(0, i*one, 0);
        local block, list = Q1:__GetCollision(myHero, an, 5);
        if not block then
            --Draw.Circle(an); Debug for pos
            if myHero:GetSpellData(slot).name == "VelkozQ" then
                Control.CastSpell(HK_Q, an);
                else
                if qb ~= 0 then
                    local TA = VectorExtendA(Vector(qb.pos.x, qb.pos.y,qb.pos.z), sPos, 1100);
                    local TB = VectorExtendB(Vector(qb.pos.x, qb.pos.y,qb.pos.z), sPos, 1100);
                    local TC = Line(Point(TA), Point(TB));
                    if TC:__distance(Point(pr)) < 200 then
                        Control.CastSpell(HK_Q);
                    end
                end
            end
        end
    end
end


function Vayne:GetStunSpot(unit)
    local Adds = {Vector(100,0,0), Vector(66,0,66), Vector(0,0,100), Vector(-66,0,66), Vector(-100,0,0), Vector(66,0,-66), Vector(0,0,-100), Vector(-66,0,-66)}
    local Xadd = Vector(100,0,0)
    for i = 1, #Adds do
        local TargetAdded = Vector(unit.pos + Adds[i])
        local Direction = Vector((unit.pos-TargetAdded):Normalized())
        --Draw.Circle(TargetAdded, 30, 1, Draw.Color(255, 0, 191, 255))
        for i=1, 5 do
            local ESSpot = unit.pos + Direction * (87*i) 
            --Draw.Circle(ESpot, 30, 1, Draw.Color(255, 0, 191, 255))
            if MapPosition:inWall(ESSpot) then
                local FlashDirection = Vector((unit.pos-ESSpot):Normalized())
                local FlashSpot = unit.pos - Direction * 400
                local MinusDist = GetDistance(FlashSpot, myHero.pos)
                if MinusDist > 400 then
                    FlashSpot = unit.pos - Direction * (800-MinusDist)
                    MinusDist = GetDistance(FlashSpot, myHero.pos)
                end
                if MinusDist < 700 then
                    if self.Menu.EFlashKey:Value() then
                        if IsReady(_E) and Flash and IsReady(Flash) then
                            Control.CastSpell(HK_E, unit)
                            DelayAction(function() Control.CastSpell(FlashSpell, FlashSpot) end, 0.05)
                        end                          
                    end
                end
                local QSpot = unit.pos - Direction * 300
                local MinusDistQ = GetDistance(QSpot, myHero.pos)
                if MinusDistQ > 300 then
                    QSpot = unit.pos - Direction * (600-MinusDistQ)
                    MinusDistQ = GetDistance(QSpot, myHero.pos)
                end
                if MinusDistQ < 470 then
                    if (self.Menu.ComboMode.UseQStun:Value() and Mode() == "Combo") or self.Menu.EFlashKey:Value() then
                        if IsReady(_Q) and IsReady(_E) then
                            Control.CastSpell(HK_Q, QSpot)
                        end                          
                    end
                end
            end
        end
    end
end--]]

function Tryndamere:Tick()
    if _G.JustEvade and _G.JustEvade:Evading() or (_G.ExtLibEvade and _G.ExtLibEvade.Evading) or Game.IsChatOpen() or myHero.dead then return end
    target = GetTarget(2000)
    CastingW = myHero.activeSpell.name == "TryndamereW"
    --PrintChat(myHero.activeSpell.name)
    --PrintChat(myHero.activeSpell.speed)
    RBuff = GetBuffExpire(myHero, "UndyingRage")
    if self.Menu.EKey:Value() then
        self:ManualECast()
    end
    --PrintChat(myHero.activeSpellSlot)
    if Mode() ~= "Harass" then
        Dashed = true
    end
    self:UpdateItems()
    self:Logic()
    self:Auto()
    self:Items2()
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


function Tryndamere:UpdateItems()
    Item_HK[ITEM_1] = HK_ITEM_1
    Item_HK[ITEM_2] = HK_ITEM_2
    Item_HK[ITEM_3] = HK_ITEM_3
    Item_HK[ITEM_4] = HK_ITEM_4
    Item_HK[ITEM_5] = HK_ITEM_5
    Item_HK[ITEM_6] = HK_ITEM_6
    Item_HK[ITEM_7] = HK_ITEM_7
end

function Tryndamere:Items1()
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

function Tryndamere:Items2()
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


function Tryndamere:ManualECast()
    local AARange = _G.SDK.Data:GetAutoAttackRange(myHero)
    local ERange = 660 + AARange
    if target then
        if ValidTarget(target, ERange) then
            self:UseE(target)
        end
    else
        for i, enemy in pairs(EnemyHeroes) do
            if enemy and not enemy.dead and ValidTarget(enemy, ERange) then
                if not (myHero.pathing and myHero.pathing.isDashing) and IsReady(_E) then
                    self:UseE(enemy)
                end
            end
        end
    end
end

function Tryndamere:Auto()
    local HealthPercent = (myHero.health / myHero.maxHealth) * 100
    if self:CanUse(_Q, "AutoUlt") then
        if self.Menu.AutoMode.UseQUltHealth:Value() >= HealthPercent and RBuff ~= nil and RBuff - Game.Timer() < 0.3 then 
            Control.CastSpell(HK_Q)
        end
    end
    --if Mode() ~= "Combo" and Mode() ~= "Harass" then
        local AARange = _G.SDK.Data:GetAutoAttackRange(myHero)
        local Wenemies = 0
        for i, enemy in pairs(EnemyHeroes) do
            if enemy and not enemy.dead and ValidTarget(enemy) then
                local EAARange = _G.SDK.Data:GetAutoAttackRange(enemy)
                if GetDistance(enemy.pos) < 870 then
                    Wenemies = Wenemies + 1
                end   
                if self:CanUse(_Q, "Auto") and ValidTarget(enemy, 1500) then
                    if self.Menu.AutoMode.UseQFury:Value() >= myHero.mana and self.Menu.AutoMode.UseQHealth:Value() >= HealthPercent and RBuff == nil then
                        Control.CastSpell(HK_Q)
                    end
                end
                if self:CanUse(_R, "Auto") and ValidTarget(enemy, 1500) then
                    local IncDamage = self:UltCalcs(target)
                    --PrintChat(IncDamage)
                    if self.Menu.AutoMode.UseRHealth:Value() >= HealthPercent or myHero.health <= IncDamage then 
                        Control.CastSpell(HK_R)
                    end
                end
            end
        end
        WAround = Wenemies
    --end
end 


function Tryndamere:CanUse(spell, mode)
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
        if mode == "Harass" and IsReady(spell) and self.Menu.HarassMode.UseR:Value() then
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



function Tryndamere:DashBack()
    if self.Menu.HarassMode.UseDashBack:Value() then
        --PrintChat("Dash Backing")
        if Dashed == true then
            attacks = self.Menu.HarassMode.DashBackAttacks:Value()
            ClosestTurret = GetNearestTurret(myHero.pos)
            Dashed = false
            --PrintChat("Attacks Set/Turret Set/Dashed = False")
        end
        if attacks <= 0 then
            --PrintChat("Attacks Less than 0")
            if ClosestTurret then
                --PrintChat("CLosest Turret")
            end
            if self:CanUse(_E, "Force") and target and ValidTarget(target, ERange) and ClosestTurret and not CastingW and not (myHero.pathing and myHero.pathing.isDashing) and not _G.SDK.Attack:IsActive() then
                Direction = Vector((myHero.pos-ClosestTurret.pos):Normalized())
                Spot = myHero.pos - Direction * 660
                Control.CastSpell(HK_E, Spot)
                Dashed = true
            end
        end
    end
end

function Tryndamere:Logic()
    if target == nil then 
        if Game.Timer() - TargetTime > 2 then
            WasInRange = false
        end
        return 
    end
    --PrintChat(target.activeSpell.target)
    if myHero.handle == target.activeSpell.target then
        --PrintChat(target.activeSpellSlot)
        --PrintChat("At me!")
    end
    if Mode() == "Combo" or Mode() == "Harass" and target then
        --PrintChat("Logic")
        TargetTime = Game.Timer()
        self:Items1()
        local AARange = _G.SDK.Data:GetAutoAttackRange(myHero) + target.boundingRadius
        if GetDistance(target.pos) < AARange then
            WasInRange = true
        end
        local WRange = 850
        local ERange = 660
        local EAARange = _G.SDK.Data:GetAutoAttackRange(target)
        local HealthPercent = (myHero.health / myHero.maxHealth) * 100
        if Mode() =="Harass" and self.Menu.HarassMode.UseDashBack:Value() then
            self:DashBack()
        elseif self:CanUse(_E, Mode()) and ValidTarget(target, ERange) and not CastingW and not (myHero.pathing and myHero.pathing.isDashing) and not _G.SDK.Attack:IsActive() then
            if self.Menu.ComboMode.UseESticky:Value() then
                if GetDistance(target.pos) > AARange and (WasInRange or self.Menu.ComboMode.UseEGapClose:Value()) then 
                    self:UseE(target)
                end
            elseif WasInRange or self.Menu.ComboMode.UseEGapClose:Value() then
                self:UseE(target)
            end
        end
        if self:CanUse(_Q, Mode()) and ValidTarget(target, EAARange*2) then
            if self.Menu.ComboMode.UseQFury:Value() >= myHero.mana and self.Menu.ComboMode.UseQHealth:Value() >= HealthPercent and RBuff == nil then 
                Control.CastSpell(HK_Q)
            end
        end
        if self:CanUse(_Q, "Ult") and ValidTarget(target) then
            if self.Menu.ComboMode.UseQUltHealth:Value() >= HealthPercent and RBuff and RBuff - Game.Timer() < 0.3 then 
                Control.CastSpell(HK_Q)
            end
        end
        local IncDamage = self:UltCalcs(target)
        if self:CanUse(_R, Mode()) and ValidTarget(target, EAARange*2) then
            if self.Menu.ComboMode.UseRHealth:Value() >= HealthPercent or myHero.health <= IncDamage then 
                Control.CastSpell(HK_R)
            end
        end
        if self:CanUse(_W, Mode()) and ValidTarget(target, WRange) and not CastingW and not (myHero.pathing and myHero.pathing.isDashing) and not _G.SDK.Attack:IsActive() then
            --PrintChat("Checking facing")
            if self.Menu.ComboMode.UseW:Value() and not IsFacing(target) then 
                Control.CastSpell(HK_W)
            end
        end
    else
        if Game.Timer() - TargetTime > 2 then
            WasInRange = false
        end
    end     
end

function Tryndamere:UltCalcs(unit)
    local Rdmg = getdmg("R", myHero, unit)
    local Qdmg = getdmg("Q", myHero, unit)
    --local Qdmg = getdmg("Q", unit, myHero)
    local Wdmg = getdmg("W", myHero, unit)
    local AAdmg = getdmg("AA", unit) 
    --PrintChat(Qdmg)
    --PrintChat(unit.activeSpell.name)
    --PrintChat(unit.activeSpellSlot)
    --PrintChat("Break------")
    --PrintChat(unit:GetSpellData(_Q).name)
    local CheckDmg = 0
    if unit.activeSpell.target == myHero.handle and unit.activeSpell.isChanneling == false and unit.totalDamage and unit.critChance then
        --PrintChat(unit.activeSpell.name)
        --PrintChat(unit.totalDamage)
        --PrintChat(myHero.critChance)
        CheckDmg = unit.totalDamage + (unit.totalDamage*unit.critChance)
    else
        --PrintChat("Spell")
        if unit.activeSpell.name == unit:GetSpellData(_Q).name and Qdmg then
            --PrintChat(Qdmg)
            CheckDmg = Qdmg
        elseif unit.activeSpell.name == unit:GetSpellData(_W).name and Wdmg then
            --PrintChat("W")
            CheckDmg = Wdmg
        elseif unit.activeSpell.name == unit:GetSpellData(_E).name and Edmg then
            --PrintChat("E")
            CheckDmg = Edmg
        elseif unit.activeSpell.name == unit:GetSpellData(_R).name and Rdmg then
            --PrintChat("R")
            CheckDmg = Rdmg
        end
    end
    --PrintChat(CheckDmg)
    return CheckDmg * 1.2
    --[[

    check if spell is auto attack, if it is, get the target, if its us, check speed and sutff, add it to the list with an end time, the damage and so on.
    
    .isChanneling = spell
    not .isChanneling = AA    

    if it's a spell however
    Find spell name, check if that slot has damage .activeSpellSlot might work, would be super easy then.
    if it has damage, check if it has a target, if it does, and the target is myhero, get the speed yadayada, damage, add it to the table.
        if it doesn't have a target, get it's end spot, speed and target spot is close to myhero, and so on, add it to the table. also try .endtime
        .spellWasCast might help if it works, check when to add the spell to the list just the once.

        another function to clear the list of any spell that has expired.

        Add up all the damage of all the spells in the list, this is the total incoming damage to my hero

    ]]
end

function Tryndamere:OnPostAttack(args)
    attacks = attacks - 1
end

function Tryndamere:OnPostAttackTick(args)
end

function Tryndamere:OnPreAttack(args)
end

function Tryndamere:UseE(unit)
    if self.Menu.ComboMode.UseEFast:Value() then
        Control.CastSpell(HK_E, unit)
    else
        local pred = _G.PremiumPrediction:GetPrediction(myHero, unit, ESpellData)
        if pred.CastPos and pred.HitChance > 0 and myHero.pos:DistanceTo(pred.CastPos) < 1150 then
            if not (myHero.pathing and myHero.pathing.isDashing) and IsReady(_E) then
                Control.CastSpell(HK_E, pred.CastPos)
            end
        end
    end 
end

class "Jax"

local EnemyLoaded = false
local casted = 0
local Qtick = true
local CastingQ = false
local CastingW = false
local CastingE = false
local CastingR = false
local Item_HK = {}
local EBuff = false
local WasInRange = false
local attacked = 0
local CanQ = true 
local QtickTime = 0

function Jax:Menu()
    self.Menu = MenuElement({type = MENU, id = "Jax", name = "Jax"})
    self.Menu:MenuElement({id = "QKey", name = "Manual Q Key", key = string.byte("T"), value = false})
    self.Menu:MenuElement({id = "ComboMode", name = "Combo", type = MENU})
    self.Menu.ComboMode:MenuElement({id = "UseQ", name = "(Q) Enabled", value = true})
    self.Menu.ComboMode:MenuElement({id = "UseQAA", name = "(Q) Use in AA Range", value = false})
    self.Menu.ComboMode:MenuElement({id = "UseQE", name = "(QE) Use E During Q Jump", value = true})
    self.Menu.ComboMode:MenuElement({id = "UseW", name = "(W) Enabled", value = true})
    self.Menu.ComboMode:MenuElement({id = "UseWAA", name = "(W) Reset AA", value = true})
    self.Menu.ComboMode:MenuElement({id = "UseWQ", name = "(WQ) Empower Q with W", value = true})
    self.Menu.ComboMode:MenuElement({id = "UseE", name = "(E) Enabled", value = true})
    self.Menu.ComboMode:MenuElement({id = "UseEBlock", name = "(E1) Start E To Block Targets Attacks", value = true})
    self.Menu.ComboMode:MenuElement({id = "UseEStun", name = "(E1) Start E if In Stun Range", value = true})
    self.Menu.ComboMode:MenuElement({id = "UseE2Stun", name = "(E2) End E To Stun Target", value = true})
    self.Menu:MenuElement({id = "HarassMode", name = "Harass", type = MENU})
    self.Menu.HarassMode:MenuElement({id = "UseQ", name = "(Q) Enabled", value = false})
    self.Menu.HarassMode:MenuElement({id = "UseQAA", name = "(Q) Use in AA Range", value = false})
    self.Menu.HarassMode:MenuElement({id = "UseQE", name = "(QE) Use E During Q Jump", value = true})
    self.Menu.HarassMode:MenuElement({id = "UseW", name = "(W) Enabled", value = false})
    self.Menu.HarassMode:MenuElement({id = "UseWAA", name = "(W) Reset AA", value = true})
    self.Menu.HarassMode:MenuElement({id = "UseWQ", name = "(WQ) Empower Q with W", value = true})
    self.Menu.HarassMode:MenuElement({id = "UseE", name = "(E) Enabled", value = false})
    self.Menu.HarassMode:MenuElement({id = "UseEBlock", name = "(E1) Start E To Block Targets Attacks", value = true})
    self.Menu.HarassMode:MenuElement({id = "UseEStun", name = "(E1) Start E if In Stun Range", value = true})
    self.Menu.HarassMode:MenuElement({id = "UseE2Stun", name = "(E2) End E To Stun Target", value = true})
    self.Menu:MenuElement({id = "AutoMode", name = "Auto", type = MENU})
    self.Menu.AutoMode:MenuElement({id = "UseE", name = "(E) Start E To Block All Attacks", value = true})
    self.Menu.AutoMode:MenuElement({id = "UseE2", name = "(E) Auto End E to Stun", value = false})
    self.Menu:MenuElement({id = "ManualMode", name = "ManualQ", type = MENU})
    self.Menu.ManualMode:MenuElement({id = "UseE", name = "Use E in Manual Q", value = true})
    self.Menu:MenuElement({id = "Draw", name = "Draw", type = MENU})
    self.Menu.Draw:MenuElement({id = "UseDraws", name = "Enable Draws", value = false})
end

function Jax:Spells()
end


function Jax:Draw()
    if self.Menu.Draw.UseDraws:Value() then
        local AARange = _G.SDK.Data:GetAutoAttackRange(myHero)
        Draw.Circle(myHero.pos, AARange, 1, Draw.Color(255, 0, 191, 255))
    end
end


function Jax:Tick()
    if _G.JustEvade and _G.JustEvade:Evading() or (_G.ExtLibEvade and _G.ExtLibEvade.Evading) or Game.IsChatOpen() or myHero.dead then return end
    target = GetTarget(2000)
    CastingE = myHero.activeSpell.name == "JaxE"
    --PrintChat(myHero:GetSpellData(_E).name)
    EBuff = BuffActive(myHero, "JaxCounterStrike")
    --PrintChat(myHero.activeSpell.speed)
    if self.Menu.QKey:Value() then
        self:ManualQCast()
    end
    self:Logic()
    self:Auto()
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


function Jax:ManualQCast()
    local AARange = _G.SDK.Data:GetAutoAttackRange(myHero)
    local QRange = 700
    if target then
        if ValidTarget(target, QRange) and not (myHero.pathing and myHero.pathing.isDashing) and IsReady(_Q) then
            if self:CanUse(_E, "Manual") then
                Control.CastSpell(HK_E)
            end
            Control.CastSpell(HK_Q, target)
        end
    else
        for i, enemy in pairs(EnemyHeroes) do
            if enemy and not enemy.dead and ValidTarget(enemy, QRange) then
                if not (myHero.pathing and myHero.pathing.isDashing) and IsReady(_Q) then
                    if self:CanUse(_E, "Manual") and not EBuff then
                        Control.CastSpell(HK_E)
                    end
                    Control.CastSpell(HK_Q, enemy)
                end
            end
        end
    end
end

function Jax:Auto()
    if Mode() ~= "Combo" and Mode() ~= "Harass" then
        for i, enemy in pairs(EnemyHeroes) do
            if enemy and not enemy.dead and ValidTarget(enemy) then
                local EAARange = _G.SDK.Data:GetAutoAttackRange(enemy)
                if ValidTarget(enemy, 300) and (self:CanUse(_E, "Auto2")) and EBuff then
                    Control.CastSpell(HK_E)
                elseif ValidTarget(enemy, EAARange) and self:CanUse(_E, "Auto") then
                    --PrintChat("Looking For Auto Attacks")
                    if myHero.handle == enemy.activeSpell.target and not EBuff then
                        if not enemy.activeSpell.isChanneling then
                            Control.CastSpell(HK_E)
                        end
                    end
                end
            end
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
    elseif spell == _R then
        if mode == "Combo" and IsReady(spell) and self.Menu.ComboMode.UseR:Value() then
            return true
        end
        if mode == "Harass" and IsReady(spell) and self.Menu.HarassMode.UseR:Value() then
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
        if mode == "Combo2" and IsReady(spell) and self.Menu.ComboMode.UseE2:Value() then
            return true
        end
        if mode == "ComboGap" and IsReady(spell) and self.Menu.ComboMode.UseEGap:Value() then
            return true
        end
        if mode == "Manual" and IsReady(spell) and self.Menu.ManualMode.UseE:Value() then
            return true
        end
        if mode == "Manual2" and IsReady(spell) and self.Menu.ManualMode.UseE2:Value() then
            return true
        end
        if mode == "Auto" and IsReady(spell) and self.Menu.AutoMode.UseE:Value() then
            return true
        end
        if mode == "Auto2" and IsReady(spell) and self.Menu.AutoMode.UseE2:Value() then
            return true
        end
        if mode == "AutoGap" and IsReady(spell) and self.Menu.AutoMode.UseEGap:Value() then
            return true
        end
    end
    return false
end



function Jax:Logic()
    if target == nil then return end
    --PrintChat(target.activeSpell.target)
    if myHero.handle == target.activeSpell.target then
        --PrintChat(target.activeSpellSlot)
        --PrintChat("At me!")
    end
    if Mode() == "Combo" or Mode() == "Harass" and target then
        --PrintChat("Logic")
        --self:Items1()
        local AARange = _G.SDK.Data:GetAutoAttackRange(myHero)
        if GetDistance(target.pos) < AARange then
            WasInRange = true
        end
        local QRange = 700
        local ERange = 300
        local EAARange = _G.SDK.Data:GetAutoAttackRange(target)
        if self:CanUse(_Q, Mode()) and ValidTarget(target, QRange) and not (myHero.pathing and myHero.pathing.isDashing) and not _G.SDK.Attack:IsActive() then
            if self.Menu.ComboMode.UseQAA:Value() then
                Control.CastSpell(HK_Q, target)
            elseif GetDistance(target.pos) > AARange then
                Control.CastSpell(HK_Q, target)
                if self.Menu.ComboMode.UseQE:Value() and not EBuff and IsReady(_E) then
                    Control.CastSpell(HK_E)
                end
            end 
        end
        if not (myHero.pathing and myHero.pathing.isDashing) and not _G.SDK.Attack:IsActive() then
            if ValidTarget(target, ERange) then
                Control.CastSpell(HK_E)
            elseif ValidTarget(target, EAARange) and self:CanUse(_E, "Combo") and self.Menu.ComboMode.UseEBlock:Value() then
                PrintChat("Looking For Auto Attacks")
                if myHero.handle == target.activeSpell.target and not EBuff then
                    if not target.activeSpell.isChanneling then
                        Control.CastSpell(HK_E)
                    end
                end
            end
        end
    else
        WasInRange = false
    end     
end

function Jax:OnPostAttack(args)
end

function Jax:OnPostAttackTick(args)
    local AARange = _G.SDK.Data:GetAutoAttackRange(myHero)
    if target then
        if self:CanUse(_W, Mode()) and ValidTarget(target, AARange+50) and not (myHero.pathing and myHero.pathing.isDashing) then
            Control.CastSpell(HK_W)
        end
    end
end

function Jax:OnPreAttack(args)
end




class "Ezreal"

local EnemyLoaded = false
local casted = 0
local Qtick = true
local CastingQ = false
local CastingW = false
local CastingE = false
local CastingR = false

local WasInRange = false
local attacked = 0
local CanQ = true 
local QtickTime = 0

function Ezreal:Menu()
    self.Menu = MenuElement({type = MENU, id = "Ezreal", name = "Ezreal"})
    self.Menu:MenuElement({id = "UltKey", name = "Manual R Key", key = string.byte("T"), value = false})
    self.Menu:MenuElement({id = "ComboMode", name = "Combo", type = MENU})
    self.Menu.ComboMode:MenuElement({id = "UseQ", name = "Use Q in Combo", value = true})
    self.Menu.ComboMode:MenuElement({id = "UseQHitChance", name = "Q Hit Chance (0.15)", value = 0.15, min = 0, max = 1.0, step = 0.05})
    self.Menu.ComboMode:MenuElement({id = "UseW", name = "Use W in Combo", value = true})
    self.Menu.ComboMode:MenuElement({id = "UseWHitChance", name = "W Hit Chance (0.15)", value = 0.15, min = 0, max = 1.0, step = 0.05})
    self.Menu:MenuElement({id = "HarassMode", name = "Harass", type = MENU})
    self.Menu.HarassMode:MenuElement({id = "UseQ", name = "Use Q in Harass", value = false})
    self.Menu.HarassMode:MenuElement({id = "UseW", name = "Use W in Harass", value = false})
    self.Menu:MenuElement({id = "AutoMode", name = "Auto", type = MENU})
    self.Menu.AutoMode:MenuElement({id = "UseQ", name = "Auto Use Q", value = true})
    self.Menu.AutoMode:MenuElement({id = "UseQHitChance", name = "Q Hit Chance (0.50)", value = 0.50, min = 0, max = 1.0, step = 0.05})
    self.Menu.AutoMode:MenuElement({id = "UseQMana", name = "Q: Min Mana %", value = 20, min = 1, max = 100, step = 1})
    self.Menu:MenuElement({id = "KSMode", name = "KS", type = MENU})
    self.Menu.KSMode:MenuElement({id = "UseQ", name = "Use Q in KS", value = true})
    self.Menu:MenuElement({id = "Draw", name = "Draw", type = MENU})
    self.Menu.Draw:MenuElement({id = "UseDraws", name = "Enable Draws", value = false})
end

function Ezreal:Spells()
    QSpellData = {speed = 2000, range = 1150, delay = 0.1515, radius = 30, collision = {}, type = "linear"}
    RSpellData = {speed = 2000, range = 3000, delay = 1.00, radius = 320, collision = {}, type = "linear"}
    WSpellData = {speed = 1200, range = 1150, delay = 0.1515, radius = 70, collision = {}, type = "linear"}
end

function Ezreal:Tick()
    if _G.JustEvade and _G.JustEvade:Evading() or (_G.ExtLibEvade and _G.ExtLibEvade.Evading) or Game.IsChatOpen() or myHero.dead then return end
    target = GetTarget(2000)
    CastingQ = myHero.activeSpell.name == "EzrealQ"
    CastingW = myHero.activeSpell.name == "EzrealW"
    CastingE = myHero.activeSpell.name == "EzrealE"
    CastingR = myHero.activeSpell.name == "EzrealR"
    --PrintChat(myHero.activeSpell.name)
    --PrintChat(myHero.activeSpell.speed)
    if Qtick == true then
        QtickTime = Game.Timer()
        Qtick = false
    else
        if Game.Timer() - QtickTime > 0.25 then
            CanQ = true
        end
    end
    if self.Menu.UltKey:Value() then
        self:ManualRCast()
    end
    self:Logic()
    self:Auto()
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

function Ezreal:Draw()
    if self.Menu.Draw.UseDraws:Value() then
        Draw.Circle(myHero.pos, 1150, 1, Draw.Color(255, 0, 191, 255))
    end
end

function Ezreal:ManualRCast()
    if target then
        if ValidTarget(target, 3000) then
            self:UseR(target)
        end
    else
        for i, enemy in pairs(EnemyHeroes) do
            if enemy and not enemy.dead and ValidTarget(enemy, 550) then
                if ValidTarget(target, 3000) then
                    self:UseR(target)
                end
            end
        end
    end
end

function Ezreal:Auto()
    if Mode() ~= "Combo" and Mode() ~= "Harass" then
        local AARange = _G.SDK.Data:GetAutoAttackRange(myHero)
        for i, enemy in pairs(EnemyHeroes) do
            if enemy and not enemy.dead and ValidTarget(enemy) then
                if self:CanUse(_Q, "Auto") and ValidTarget(enemy, QRange) and not CastingQ and not CastingW and not CastingE and not CastingR and not (myHero.pathing and myHero.pathing.isDashing) and not _G.SDK.Attack:IsActive() then
                    self:UseQAuto(enemy)
                end
            end
        end
    end
end 

function Ezreal:CanUse(spell, mode)
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
        local ManaPercent = myHero.mana / myHero.maxMana * 100
        if mode == "Auto" and IsReady(spell) and self.Menu.AutoMode.UseQ:Value() and ManaPercent > self.Menu.AutoMode.UseQMana:Value() then
            return true
        end
        if mode == "KS" and IsReady(spell) and self.Menu.KSMode.UseQ:Value() then
            return true
        end
    elseif spell == _R then
        if mode == "Combo" and IsReady(spell) and self.Menu.ComboMode.UseR:Value() then
            return true
        end
        if mode == "Harass" and IsReady(spell) and self.Menu.HarassMode.UseR:Value() then
            return true
        end
        if mode == "KS" and IsReady(spell) and self.Menu.KSMode.UseR:Value() then
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
        if mode == "ComboGap" and IsReady(spell) and self.Menu.ComboMode.UseEGap:Value() then
            return true
        end
        if mode == "Harass" and IsReady(spell) and self.Menu.HarassMode.UseE:Value() then
            return true
        end
        if mode == "Auto" and IsReady(spell) and self.Menu.AutoMode.UseE:Value() then
            return true
        end
        if mode == "AutoGap" and IsReady(spell) and self.Menu.AutoMode.UseEGap:Value() then
            return true
        end
        if mode == "KS" and IsReady(spell) and self.Menu.KSMode.UseE:Value() then
            return true
        end
    end
    return false
end



function Ezreal:Logic()
    if target == nil then return end
    if Mode() == "Combo" or Mode() == "Harass" and target then
        local AARange = _G.SDK.Data:GetAutoAttackRange(myHero)
        if GetDistance(target.pos) < AARange then
            WasInRange = true
        end
        local QRange = 1250
        local WRange = 1250
        local QdmgCheck = target.health >= getdmg("Q", target, myHero) or not self:CanUse(_Q, Mode())
        local AAdmgCheck = target.health >= getdmg("AA", target, myHero)
        if self:CanUse(_Q, Mode()) and ValidTarget(target, QRange) and not CastingQ and not CastingW and not CastingE and not CastingR and not (myHero.pathing and myHero.pathing.isDashing) and not _G.SDK.Attack:IsActive() then
            self:UseQ(target)
        end
        if QdmgCheck and AAdmgCheck and self:CanUse(_W, Mode()) and ValidTarget(target, AARange) and not CastingQ and not CastingW and not CastingE and not CastingR and not (myHero.pathing and myHero.pathing.isDashing) and not _G.SDK.Attack:IsActive() then
            self:UseW(target)
        end
    else
        WasInRange = false
    end     
end



function Ezreal:OnPostAttack(args)
end

function Ezreal:OnPostAttackTick(args)
end

function Ezreal:OnPreAttack(args)
end

function Ezreal:UseQAuto(unit)
    local pred = _G.PremiumPrediction:GetPrediction(myHero, unit, QSpellData)
    if pred.CastPos and pred.HitChance > self.Menu.AutoMode.UseQHitChance:Value() and myHero.pos:DistanceTo(pred.CastPos) < 1150 then
        local Collision = _G.PremiumPrediction:IsColliding(myHero, pred.CastPos, QSpellData, {"minion"})
        if CanQ == true and not Collision then
            Control.CastSpell(HK_Q, pred.CastPos)
            Qtick = true
            CanQ = false
        end
    end 
end


function Ezreal:UseQ(unit)
    local pred = _G.PremiumPrediction:GetPrediction(myHero, unit, QSpellData)
    if pred.CastPos and pred.HitChance > self.Menu.ComboMode.UseQHitChance:Value() and myHero.pos:DistanceTo(pred.CastPos) < 1150 then
        --PrintChat(pred.HitChance)
        local AARange = _G.SDK.Data:GetAutoAttackRange(myHero)
        local QdmgCheck = unit.health >= getdmg("Q", unit, myHero)
        local AAdmgCheck = unit.health >= getdmg("AA", unit, myHero) or GetDistance(unit.pos) > AARange
        local Collision = _G.PremiumPrediction:IsColliding(myHero, pred.CastPos, QSpellData, {"minion"})
        if self:CanUse(_W, Mode()) and ValidTarget(unit, 1250) and QdmgCheck and AAdmgCheck and not Collision then
            self:UseW(unit)
        end
        if not self:CanUse(_W, Mode()) or not QdmgCheck or not AAdmgCheck then
            if CanQ == true and not Collision then
                Control.CastSpell(HK_Q, pred.CastPos)
                Qtick = true
                CanQ = false
            end
        end
    end 
end

function Ezreal:UseW(unit)
    local pred = _G.PremiumPrediction:GetPrediction(myHero, unit, WSpellData)
    if pred.CastPos and pred.HitChance > self.Menu.ComboMode.UseWHitChance:Value() and myHero.pos:DistanceTo(pred.CastPos) < 1150 then
            Control.CastSpell(HK_W, pred.CastPos)
    end 
end

function Ezreal:UseR(unit)
    local pred = _G.PremiumPrediction:GetPrediction(myHero, unit, RSpellData)
    if pred.CastPos and _G.PremiumPrediction.HitChance.Medium(pred.HitChance) and myHero.pos:DistanceTo(pred.CastPos) < 3000 then
            Control.CastSpell(HK_R, pred.CastPos)
    end 
end

class "Vayne"

local EnemyLoaded = false
local casted = 0
local LastCalledTime = 0
local LastESpot = myHero.pos
local LastE2Spot = myHero.pos
local PickingCard = false
local TargetAttacking = false
local attackedfirst = 0
local CastingQ = false
local LastDirect = 0
local Flash = nil
local FlashSpell = nil
local CastingW = false
local LastHit = nil
local WStacks = 0
local HadStun = false
local StunTime = Game.Timer()
local CastingR = false
local UseBuffs = false
local ReturnMouse = mousePos
local Q = 1
local Edown = false
local R = 1
local WasInRange = false
local OneTick
local attacked = 0

function Vayne:Menu()
    self.Menu = MenuElement({type = MENU, id = "Vayne", name = "Vayne"})
    self.Menu:MenuElement({id = "EFlashKey", name = "E-Flash To Mouse", key = string.byte("T"), value = false})
    self.Menu:MenuElement({id = "UseBuffFunc", name = "Use Buff Functions(May Cause Crashes)", value = false})
    self.Menu:MenuElement({id = "ComboMode", name = "Combo", type = MENU})
    self.Menu.ComboMode:MenuElement({id = "UseQ", name = "Use Q in Combo", value = true})
    self.Menu.ComboMode:MenuElement({id = "UseQStun", name = "Use Q To Roll For Stun", value = true})
    self.Menu.ComboMode:MenuElement({id = "UseE", name = "Use E to stun in Combo", value = true})
    self.Menu.ComboMode:MenuElement({id = "UseEGap", name = "Anti Gap Close E", value = true})
    self.Menu.ComboMode:MenuElement({id = "UseEDelay", name = "E Delay", value = 50, min = 0, max = 200, step = 10})

    self.Menu:MenuElement({id = "HarassMode", name = "Harass", type = MENU})
    self.Menu.HarassMode:MenuElement({id = "UseQ", name = "Use Q in Harass", value = false})
    self.Menu.HarassMode:MenuElement({id = "UseE", name = "Use E to stun in Harass", value = false})

    self.Menu:MenuElement({id = "AutoMode", name = "Auto", type = MENU})
    self.Menu.AutoMode:MenuElement({id = "UseE", name = "Auto Use E to stun", value = true})
    self.Menu.AutoMode:MenuElement({id = "UseEGap", name = "Anti Gap Close E", value = true})

    self.Menu:MenuElement({id = "OrbMode", name = "Orbwalker", type = MENU})
    self.Menu.OrbMode:MenuElement({id = "UseRangedHelper", name = "Enable Range Helper ", value = true})
    self.Menu.OrbMode:MenuElement({id = "UseRangedHelperWalk", name = "Enable Range Helper Moving", value = true})
    self.Menu.OrbMode:MenuElement({id = "RangedHelperMouseDistance", name = "Mouse Distance From Target To Enable", value = 550, min = 0, max = 1500, step = 50})
    self.Menu.OrbMode:MenuElement({id = "RangedHelperRange", name = "Extra Distance To Kite (%)", value = 50, min = 0, max = 100, step = 10})
    self.Menu.OrbMode:MenuElement({id = "RangedHelperRangeFacing", name = "Extra Distance When Chasing (%)", value = 10, min = 0, max = 100, step = 10})
    self.Menu.OrbMode:MenuElement({id = "UseRangedHelperQ", name = "Enable Q in Range Helper", value = true})
    self.Menu.OrbMode:MenuElement({id = "UseRangedHelperQAlways", name = "Enable Q in Range Helper For damage", value = false})

    self.Menu:MenuElement({id = "KSMode", name = "KS", type = MENU})
    self.Menu.KSMode:MenuElement({id = "UseQ", name = "Use Q in KS", value = true})
    self.Menu.KSMode:MenuElement({id = "UseE", name = "Use E in KS", value = true})

    self.Menu:MenuElement({id = "Draw", name = "Draw", type = MENU})
    self.Menu.Draw:MenuElement({id = "UseDraws", name = "Enable Draws", value = false})
    self.Menu.Draw:MenuElement({id = "RangedHelperSpot", name = "Draw Ranged Helper Spot", value = false})
    self.Menu.Draw:MenuElement({id = "RangedHelperDistance", name = "Draw Ranged Helper Mouse Distance", value = false})
    self.Menu.Draw:MenuElement({id = "Path", name = "Draw Path", value = false})
    self.Menu.Draw:MenuElement({id = "StunCalc", name = "Draw Stun calcs", value = false})

end

function Vayne:Spells()
end

function Vayne:Tick()
    if _G.JustEvade and _G.JustEvade:Evading() or (_G.ExtLibEvade and _G.ExtLibEvade.Evading) or Game.IsChatOpen() or myHero.dead then return end
    target = GetTarget(1400)
    UseBuffs = self.Menu.UseBuffFunc:Value()
    if myHero:GetSpellData(SUMMONER_1).name:find("Flash") then
        Flash = SUMMONER_1
        FlashSpell = HK_SUMMONER_1
    elseif myHero:GetSpellData(SUMMONER_2).name:find("Flash") then
        Flash = SUMMONER_2
        FlashSpell = HK_SUMMONER_2
    else 
        Flash = nil
    end
    CastingE = myHero.activeSpell.name == "VayneCondemn"
    if target then
        if UseBuffs then
            TwoStacks = _G.SDK.BuffManager:GetBuffCount(target, "VayneSilveredDebuff")
        else
            TwoStacks = 2
        end
    else
        TwoStacks = 0
    end
    --PrintChat(myHero.activeSpell.name)
    if self.Menu.EFlashKey:Value() then
        --self:Eflash()
    end
    if target then
        self:GetStunSpot(target)
        self:RangedHelper(target)
    else
        _G.SDK.Orbwalker.ForceMovement = nil
    end
    self:Logic()
    self:Auto()
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

function Vayne:DrawRangedHelper(unit)
    local AARange = _G.SDK.Data:GetAutoAttackRange(myHero)
    local EAARange = _G.SDK.Data:GetAutoAttackRange(unit)
    local QRange = 300
    local MoveSpot = nil
    local RangeDif = AARange - EAARange
    local RangeDist = RangeDif*(self.Menu.OrbMode.RangedHelperRange:Value()/100)
    local RangeDistChase = RangeDif*(self.Menu.OrbMode.RangedHelperRangeFacing:Value()/100)
    if self.Menu.OrbMode.UseRangedHelper:Value() and unit and Mode() == "Combo" and GetDistance(mousePos, unit.pos) < self.Menu.OrbMode.RangedHelperMouseDistance:Value() and GetDistance(unit.pos) <= AARange+300 then
        
        local ScanDirection = Vector((myHero.pos-mousePos):Normalized())
        local ScanDistance = GetDistance(myHero.pos, unit.pos) * 0.8
        local ScanSpot = myHero.pos - ScanDirection * ScanDistance

        local MouseDirection = Vector((unit.pos-ScanSpot):Normalized())
        local MouseSpotDistance = EAARange + RangeDist
        if not IsFacing(unit) then
            MouseSpotDistance = EAARange + RangeDistChase
        end
        if AARange < EAARange + 150 then
            MouseSpotDistance = GetDistance(unit.pos)
            local UnitDistance = GetDistance(unit.pos)
            if UnitDistance < AARange*0.5 then
                MouseSpotDistance = GetDistance(unit.pos) + AARange*0.2
            end
            if UnitDistance > AARange*0.8 then
                MouseSpotDistance = GetDistance(unit.pos) - AARange*0.2
            end
        end
        local MouseSpot = unit.pos - MouseDirection * (MouseSpotDistance)
        MoveSpot = MouseSpot
        return MoveSpot
        --PrintChat("Forcing")
    else
        return nil
    end
end

function Vayne:RangedHelper(unit)
    local AARange = _G.SDK.Data:GetAutoAttackRange(myHero)
    local EAARange = _G.SDK.Data:GetAutoAttackRange(unit)
    local QRange = 300
    local MoveSpot = nil
    local RangeDif = AARange - EAARange
    local RangeDist = RangeDif*(self.Menu.OrbMode.RangedHelperRange:Value()/100)
    local RangeDistChase = RangeDif*(self.Menu.OrbMode.RangedHelperRangeFacing:Value()/100)
    if self.Menu.OrbMode.UseRangedHelper:Value() and unit and Mode() == "Combo" and GetDistance(mousePos, unit.pos) < self.Menu.OrbMode.RangedHelperMouseDistance:Value() and GetDistance(unit.pos) <= AARange+300 then
        
        local ScanDirection = Vector((myHero.pos-mousePos):Normalized())
        local ScanDistance = GetDistance(myHero.pos, unit.pos) * 0.8
        local ScanSpot = myHero.pos - ScanDirection * ScanDistance

        local MouseDirection = Vector((unit.pos-ScanSpot):Normalized())
        local MouseSpotDistance = EAARange + RangeDist
        if not IsFacing(unit) then
            MouseSpotDistance = EAARange + RangeDistChase
        end
        if AARange < EAARange + 150 then
            MouseSpotDistance = GetDistance(unit.pos)
        end
        local MouseSpot = unit.pos - MouseDirection * (MouseSpotDistance)
        MoveSpot = MouseSpot
        
        --if IsFacing(unit) then
            if self.Menu.OrbMode.UseRangedHelperQ:Value() then
                if ((GetDistance(unit.pos, myHero.pos) > AARange and GetDistance(MouseSpot, myHero.pos) < 300) or GetDistance(unit.pos, myHero.pos) > MouseSpotDistance+300 or GetDistance(unit.pos, myHero.pos) < EAARange+45 or self.Menu.OrbMode.UseRangedHelperQAlways:Value()) then
                    if IsReady(_Q) and not (myHero.pathing and myHero.pathing.isDashing) and not _G.SDK.Attack:IsActive() and not CastingE then
                        Control.CastSpell(HK_Q, MoveSpot)
                    end
                end
            end
        --end
        

        if self.Menu.OrbMode.UseRangedHelperWalk:Value() and GetDistance(unit.pos) <= AARange and AARange > EAARange + 150 then
            _G.SDK.Orbwalker.ForceMovement = MoveSpot
        else
            _G.SDK.Orbwalker.ForceMovement = nil
        end
    else
        _G.SDK.Orbwalker.ForceMovement = nil
    end
    if MoveSpot and GetDistance(MoveSpot) < 50 and self.Menu.OrbMode.UseRangedHelperWalk:Value() then
        _G.SDK.Orbwalker:SetMovement(false)
    else
        _G.SDK.Orbwalker:SetMovement(true)
    end
end

function Vayne:Eflash()
    if target then
        local PreMouse = mousePos
        if IsReady(_E) and ValidTarget(target, 550) and Flash and IsReady(Flash) then
            Control.CastSpell(HK_E, target)
            DelayAction(function() Control.CastSpell(FlashSpell, PreMouse) end, 0.05)
        end  
    end
end 


function Vayne:Draw()
    if self.Menu.Draw.UseDraws:Value() then
        --local Xadd = Vector(100,0,0)
        --local HeroAdded = Vector(myHero.pos + Xadd)
        --Draw.Circle(HeroAdded, 225, 1, Draw.Color(255, 0, 191, 255))
        Draw.Circle(myHero.pos, 300, 1, Draw.Color(255, 0, 191, 255))
        if self.Menu.Draw.Path:Value() then
            local path = myHero.pathing;
            local PathStart = myHero.pathing.pathIndex
            local PathEnd = myHero.pathing.pathCount
            if PathStart and PathEnd and PathStart >= 0 and PathEnd <= 20 and path.hasMovePath then
                for i = path.pathIndex, path.pathCount do
                    local path_vec = myHero:GetPath(i)
                    if path.isDashing then
                        Draw.Circle(path_vec,100,1,Draw.Color(255,0,0,255))
                    else
                        Draw.Circle(path_vec,100,1,Draw.Color(255,225,255,255))
                    end
                end
            end
        end
        if self.Menu.OrbMode.UseRangedHelper:Value() and target and self.Menu.Draw.RangedHelperDistance:Value() then
            Draw.Circle(target.pos, self.Menu.OrbMode.RangedHelperMouseDistance:Value(), 1, Draw.Color(255, 0, 0, 0))
        end
        if self.Menu.OrbMode.UseRangedHelper:Value() and target and self.Menu.Draw.RangedHelperSpot:Value() then
            local RangedSpot = self:DrawRangedHelper(target)
            if RangedSpot then
                Draw.Circle(RangedSpot, 25, 1, Draw.Color(255, 0, 100, 255))
                Draw.Circle(RangedSpot, 35, 1, Draw.Color(255, 0, 100, 255))
                Draw.Circle(RangedSpot, 45, 1, Draw.Color(255, 0, 100, 255))
            end
        end

        if target and self.Menu.Draw.StunCalc:Value() then
            self:DrawStunSpot()


            local unit = target
            local NextSpot = GetUnitPositionNext(unit)
            local PredictedPos = unit.pos
            local Direction = Vector((PredictedPos-myHero.pos):Normalized())
            if NextSpot then
                local Time = (GetDistance(unit.pos, myHero.pos) / 2000) + 0.25
                local UnitDirection = Vector((unit.pos-NextSpot):Normalized())
                PredictedPos = unit.pos - UnitDirection * (unit.ms*Time)
                Direction = Vector((PredictedPos-myHero.pos):Normalized())
            end

            for i=1, 5 do
                ESpot = PredictedPos + Direction * (87*i)
                Draw.Circle(ESpot, 50, 1, Draw.Color(255, 0, 191, 255)) 
            end
        end
    end
end

function Vayne:AntiDash(unit)
    local path = unit.pathing;
    local PathStart = unit.pathing.pathIndex
    local PathEnd = unit.pathing.pathCount
    if PathStart and PathEnd and PathStart >= 0 and PathEnd <= 20 and path.hasMovePath then
        for i = path.pathIndex, path.pathCount do
            local path_vec = unit:GetPath(i)
            if path.isDashing then
                return path_vec
            end
        end
    end
    return false
end

function Vayne:GetStunSpot(unit)
    local Adds = {Vector(100,0,0), Vector(66,0,66), Vector(0,0,100), Vector(-66,0,66), Vector(-100,0,0), Vector(66,0,-66), Vector(0,0,-100), Vector(-66,0,-66)}
    local Xadd = Vector(100,0,0)
    for i = 1, #Adds do
        local TargetAdded = Vector(unit.pos + Adds[i])
        local Direction = Vector((unit.pos-TargetAdded):Normalized())
        --Draw.Circle(TargetAdded, 30, 1, Draw.Color(255, 0, 191, 255))
        for i=1, 5 do
            local ESSpot = unit.pos + Direction * (87*i) 
            --Draw.Circle(ESpot, 30, 1, Draw.Color(255, 0, 191, 255))
            if MapPosition:inWall(ESSpot) then
                local FlashDirection = Vector((unit.pos-ESSpot):Normalized())
                local FlashSpot = unit.pos - Direction * 400
                local MinusDist = GetDistance(FlashSpot, myHero.pos)
                if MinusDist > 400 then
                    FlashSpot = unit.pos - Direction * (800-MinusDist)
                    MinusDist = GetDistance(FlashSpot, myHero.pos)
                end
                if MinusDist < 700 then
                    if self.Menu.EFlashKey:Value() then
                        if IsReady(_E) and Flash and IsReady(Flash) then
                            Control.CastSpell(HK_E, unit)
                            DelayAction(function() Control.CastSpell(FlashSpell, FlashSpot) end, 0.05)
                        end                          
                    end
                end
                local QSpot = unit.pos - Direction * 300
                local MinusDistQ = GetDistance(QSpot, myHero.pos)
                if MinusDistQ > 300 then
                    QSpot = unit.pos - Direction * (600-MinusDistQ)
                    MinusDistQ = GetDistance(QSpot, myHero.pos)
                end
                if MinusDistQ < 470 then
                    if (self.Menu.ComboMode.UseQStun:Value() and Mode() == "Combo") or self.Menu.EFlashKey:Value() then
                        if IsReady(_Q) and IsReady(_E) then
                            Control.CastSpell(HK_Q, QSpot)
                        end                          
                    end
                end
            end
        end
    end
end



function Vayne:DrawStunSpot()
    local Adds = {Vector(100,0,0), Vector(66,0,66), Vector(0,0,100), Vector(-66,0,66), Vector(-100,0,0), Vector(66,0,-66), Vector(0,0,-100), Vector(-66,0,-66)}
    local Xadd = Vector(100,0,0)
    for i = 1, #Adds do
        local TargetAdded = Vector(target.pos + Adds[i])
        local Direction = Vector((target.pos-TargetAdded):Normalized())
        --Draw.Circle(TargetAdded, 30, 1, Draw.Color(255, 0, 191, 255))
        for i=1, 5 do
            local ESSpot = target.pos + Direction * (87*i) 
            --Draw.Circle(ESpot, 30, 1, Draw.Color(255, 0, 191, 255))
            if MapPosition:inWall(ESSpot) then
                Draw.Circle(TargetAdded, 30, 1, Draw.Color(255, 0, 191, 255))
                Draw.Circle(ESSpot, 30, 1, Draw.Color(255, 0, 191, 255))
                local FlashDirection = Vector((target.pos-ESSpot):Normalized())
                local FlashSpot = target.pos - Direction * 400
                local MinusDist = GetDistance(FlashSpot, myHero.pos)
                if MinusDist > 400 then
                    FlashSpot = target.pos - Direction * (800-MinusDist)
                end
                if MinusDist < 700 then
                    Draw.Circle(FlashSpot, 30, 1, Draw.Color(255, 0, 255, 255))
                end

                local QSpot = target.pos - Direction * 300
                local MinusDistQ = GetDistance(QSpot, myHero.pos)
                if MinusDistQ > 300 then
                    QSpot = target.pos - Direction * (600-MinusDistQ)
                end
                if MinusDistQ < 470 then
                    Draw.Circle(QSpot, 30, 1, Draw.Color(255, 255, 100, 100))
                end
            end
        end
    end
end

function Vayne:CheckWallStun(unit)
    local NextSpot = GetUnitPositionNext(unit)
    local PredictedPos = unit.pos
    local Direction = Vector((PredictedPos-myHero.pos):Normalized())
    if NextSpot then
        local Time = (GetDistance(unit.pos, myHero.pos) / 2000) + 0.25
        local UnitDirection = Vector((unit.pos-NextSpot):Normalized())
        PredictedPos = unit.pos - UnitDirection * (unit.ms*Time)
        Direction = Vector((PredictedPos-myHero.pos):Normalized())
    end
    local FoundStun = false
    for i=1, 5 do
        ESpot = PredictedPos + Direction * (87*i) 
        if MapPosition:inWall(ESpot) then
            FoundStun = true
            if HadStun == false then
                StunTime = Game.Timer()
                HadStun = true
            elseif Game.Timer() - StunTime > (self.Menu.ComboMode.UseEDelay:Value()/1000) then
                HadStun = false
                return ESpot
            end
        end
    end
    if FoundStun == false then
        HadStun = false
    end
    return nil
end


function Vayne:Auto()
    --PrintChat("ksing")
    local AARange = _G.SDK.Data:GetAutoAttackRange(myHero)
    for i, enemy in pairs(EnemyHeroes) do
        if enemy and not enemy.dead and ValidTarget(enemy) then
            --[[if self:CanUse(_E, "KS") and ValidTarget(enemy, 550) and TwoStacks == 2 then
                local Edamage = getdmg("E", enemy, myHero)
                local Wdamage = getdmg("W", enemy, myHero)
                if enemy.health < Edamage + Wdamage then
                    Control.CastSpell(HK_E, enemy)
                end
            end]]--
            if self:CanUse(_E, "Auto") and ValidTarget(enemy, 550) and not CastingE and not enemy.pathing.isDashing then
                local Wall = self:CheckWallStun(enemy)
                if Wall and (TwoStacks ~= 1 or GetDistance(myHero.pos, Wall) < AARange) then
                    Control.CastSpell(HK_E, enemy)
                end
            end
            if self:CanUse(_E, "AutoGap") and ValidTarget(enemy, 550) and not CastingE then
                local DashSpot = self:AntiDash(enemy)
                if DashSpot then
                    if GetDistance(DashSpot) < 225 then
                        Control.CastSpell(HK_E, enemy)
                    end
                end
            end
            if self:CanUse(_E, "ComboGap") and Mode() == "Combo" and ValidTarget(enemy, 550) and not CastingE then
                local DashSpot = self:AntiDash(enemy)
                if DashSpot then
                    if GetDistance(DashSpot) < 225 then
                        Control.CastSpell(HK_E, enemy)
                    end
                end
            end
        end
    end
end 

function Vayne:CanUse(spell, mode)
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
        if mode == "Flee" and IsReady(spell) and self.Menu.FleeMode.UseQ:Value() then
            return true
        end
        if mode == "KS" and IsReady(spell) and self.Menu.KSMode.UseQ:Value() then
            return true
        end
    elseif spell == _R then
        if mode == "Combo" and IsReady(spell) and self.Menu.ComboMode.UseR:Value() then
            return true
        end
        if mode == "Harass" and IsReady(spell) and self.Menu.HarassMode.UseR:Value() then
            return true
        end
        if mode == "KS" and IsReady(spell) and self.Menu.KSMode.UseR:Value() then
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
        if mode == "ComboGap" and IsReady(spell) and self.Menu.ComboMode.UseEGap:Value() then
            return true
        end
        if mode == "Harass" and IsReady(spell) and self.Menu.HarassMode.UseE:Value() then
            return true
        end
        if mode == "Auto" and IsReady(spell) and self.Menu.AutoMode.UseE:Value() then
            return true
        end
        if mode == "AutoGap" and IsReady(spell) and self.Menu.AutoMode.UseEGap:Value() then
            return true
        end
        if mode == "KS" and IsReady(spell) and self.Menu.KSMode.UseE:Value() then
            return true
        end
    end
    return false
end



function Vayne:Logic()
    if target == nil then return end
    if Mode() == "Combo" or Mode() == "Harass" and target then
        local AARange = _G.SDK.Data:GetAutoAttackRange(myHero)
        if GetDistance(target.pos) < AARange then
            WasInRange = true
        end
        local ERange = 550

        if self:CanUse(_E, Mode()) and ValidTarget(target, ERange) and UseBuffs and TwoStacks == 2 then
            local Edamage = getdmg("E", target, myHero)
            local Wdamage = getdmg("W", target, myHero)
            if target.health < Edamage + Wdamage then
                Control.CastSpell(HK_E, target)
            end
        end

        local Wall = self:CheckWallStun(target)
        if self:CanUse(_E, Mode()) and ValidTarget(target, ERange) and not CastingE and Wall ~= nil and not target.pathing.isDashing then
            if TwoStacks ~= 1 or GetDistance(myHero.pos, Wall) < AARange then
                Control.CastSpell(HK_E, target)
            end
        end
    else
        WasInRange = false
    end     
end



function Vayne:OnPostAttack(args)
end

function Vayne:OnPostAttackTick(args)
    attackedfirst = 1
    attacked = 1
end

function Vayne:OnPreAttack(args)
    if target then
        --PrintChat(myHero.activeSpell.name)
        --PrintChat(target.charName)
    end
end

function Vayne:UseE(unit, hits)
    local pred = _G.PremiumPrediction:GetAOEPrediction(myHero, unit, ESpellData)
    if pred.CastPos and _G.PremiumPrediction.HitChance.Low(pred.HitChance) and myHero.pos:DistanceTo(pred.CastPos) < 1001 and pred.HitCount >= hits then
        Control.CastSpell(HK_E, pred.CastPos)
    end 
end

class "Corki"

local EnemyLoaded = false
local casted = 0
local Qtick = true
local CastingQ = false
local CastingW = false
local CastingE = false
local CastingR = false
local QRange = 850
local ERange = 600
local RRange = 1300
local WasInRange = false
local attacked = 0
local CanQ = true 
local QtickTime = 0

function Corki:Menu()
    self.Menu = MenuElement({type = MENU, id = "Corki", name = "Corki"})
    self.Menu:MenuElement({id = "UltKey", name = "Manual R Key", key = string.byte("T"), value = false})
    self.Menu:MenuElement({id = "ComboMode", name = "Combo", type = MENU})
    self.Menu.ComboMode:MenuElement({id = "UseQ", name = "Use Q in Combo", value = true})
    self.Menu.ComboMode:MenuElement({id = "UseQHitChance", name = "Q Hit Chance (0.15)", value = 0.15, min = 0, max = 1.0, step = 0.05})
    self.Menu.ComboMode:MenuElement({id = "UseE", name = "Use E in Combo", value = true})
    self.Menu.ComboMode:MenuElement({id = "UseR", name = "Use R in Combo", value = true})
    self.Menu.ComboMode:MenuElement({id = "UseRHitChance", name = "R Hit Chance (0.15)", value = 0.15, min = 0, max = 1.0, step = 0.05})
    self.Menu:MenuElement({id = "HarassMode", name = "Harass", type = MENU})
    self.Menu.HarassMode:MenuElement({id = "UseQ", name = "Use Q in Harass", value = false})
    self.Menu.HarassMode:MenuElement({id = "UseW", name = "Use W in Harass", value = false})
    self.Menu.HarassMode:MenuElement({id = "UseE", name = "Use E in Harass", value = false})
    self.Menu.HarassMode:MenuElement({id = "UseR", name = "Use R in Harass", value = false})
    self.Menu:MenuElement({id = "AutoMode", name = "Auto", type = MENU})
    self.Menu.AutoMode:MenuElement({id = "UseQ", name = "Auto Use Q", value = true})
    self.Menu.AutoMode:MenuElement({id = "UseQHitChance", name = "Q Hit Chance (0.50)", value = 0.50, min = 0, max = 1.0, step = 0.05})
    self.Menu.AutoMode:MenuElement({id = "UseQMana", name = "Q: Min Mana %", value = 20, min = 1, max = 100, step = 1})
    self.Menu:MenuElement({id = "KSMode", name = "KS", type = MENU})
    self.Menu.KSMode:MenuElement({id = "UseQ", name = "Use Q in KS", value = true})
    self.Menu:MenuElement({id = "Draw", name = "Draw", type = MENU})
    self.Menu.Draw:MenuElement({id = "UseDraws", name = "Enable Draws", value = false})
end

function Corki:Spells()
    QSpellData = {speed = 1000, range = 825, delay = 0.50, radius = 125, collision = {}, type = "circular"}
    RSpellData = {speed = 2000, range = 1300, delay = 1.00, radius = 40, collision = {"minion"}, type = "linear"}
    BRSpellData = {speed = 2000, range = 1500, delay = 1.00, radius = 40, collision = {"minion"}, type = "linear"}
end

function Corki:Tick()
    if _G.JustEvade and _G.JustEvade:Evading() or (_G.ExtLibEvade and _G.ExtLibEvade.Evading) or Game.IsChatOpen() or myHero.dead then return end
    target = GetTarget(2000)
    CastingQ = myHero.activeSpell.name == "PhosphorusBomb"
    CastingW = myHero.activeSpell.name == "CorkiW"
    CastingE = myHero.activeSpell.name == "CorkiE"
    CastingR = myHero.activeSpell.name == "MissileBarrageMissile" or myHero.activeSpell.name == "MissileBarrageMissile2"
    if CastingQ or CastingR then 
        --PrintChat(myHero.activeSpell.name)
    end
    --PrintChat(myHero.hudAmmo)
    --PrintChat(myHero.activeSpell.speed)
    if self.Menu.UltKey:Value() then
        self:ManualRCast()
    end
    self:Logic()
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

function Corki:Draw()
    if self.Menu.Draw.UseDraws:Value() then
        Draw.Circle(myHero.pos, 1150, 1, Draw.Color(255, 0, 191, 255))
    end
end

function Corki:ManualRCast()
    if target then
        if ValidTarget(target, 3000) then
            self:UseR(target)
        end
    else
        for i, enemy in pairs(EnemyHeroes) do
            if enemy and not enemy.dead and ValidTarget(enemy, 550) then
                if ValidTarget(target, 3000) then
                    self:UseR(target)
                end
            end
        end
    end
end

function Corki:Auto()
    if Mode() ~= "Combo" and Mode() ~= "Harass" then
        local AARange = _G.SDK.Data:GetAutoAttackRange(myHero)
        for i, enemy in pairs(EnemyHeroes) do
            if enemy and not enemy.dead and ValidTarget(enemy) then
            end
        end
    end
end 

function Corki:CanUse(spell, mode)
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
        local ManaPercent = myHero.mana / myHero.maxMana * 100
        if mode == "Auto" and IsReady(spell) and self.Menu.AutoMode.UseQ:Value() and ManaPercent > self.Menu.AutoMode.UseQMana:Value() then
            return true
        end
        if mode == "KS" and IsReady(spell) and self.Menu.KSMode.UseQ:Value() then
            return true
        end
    elseif spell == _R then
        if mode == "Combo" and IsReady(spell) and self.Menu.ComboMode.UseR:Value() then
            return true
        end
        if mode == "Harass" and IsReady(spell) and self.Menu.HarassMode.UseR:Value() then
            return true
        end
        if mode == "KS" and IsReady(spell) and self.Menu.KSMode.UseR:Value() then
            return true
        end
    elseif spell == _W then

    elseif spell == _E then
        if mode == "Combo" and IsReady(spell) and self.Menu.ComboMode.UseE:Value() then
            return true
        end
        if mode == "ComboGap" and IsReady(spell) and self.Menu.ComboMode.UseEGap:Value() then
            return true
        end
        if mode == "Harass" and IsReady(spell) and self.Menu.HarassMode.UseE:Value() then
            return true
        end
        if mode == "Auto" and IsReady(spell) and self.Menu.AutoMode.UseE:Value() then
            return true
        end
        if mode == "AutoGap" and IsReady(spell) and self.Menu.AutoMode.UseEGap:Value() then
            return true
        end
        if mode == "KS" and IsReady(spell) and self.Menu.KSMode.UseE:Value() then
            return true
        end
    end
    return false
end



function Corki:Logic()
    if target == nil then return end
    if Mode() == "Combo" or Mode() == "Harass" and target then
        local AARange = _G.SDK.Data:GetAutoAttackRange(myHero)
        if GetDistance(target.pos) < AARange then
            WasInRange = true
        end
        if self:CanUse(_Q, Mode()) and ValidTarget(target, QRange) and not CastingQ and not CastingW and not CastingE and not CastingR and not (myHero.pathing and myHero.pathing.isDashing) and not _G.SDK.Attack:IsActive() then
            self:UseQ(target, 1)
        end
        if self:CanUse(_E, Mode()) and ValidTarget(target, ERange) and not CastingQ and not CastingW and not CastingE and not CastingR and not (myHero.pathing and myHero.pathing.isDashing) and not _G.SDK.Attack:IsActive() then
            Control.CastSpell(HK_E)
        end
        if self:CanUse(_R, Mode()) and ValidTarget(target, RRange) and not CastingQ and not CastingW and not CastingE and not CastingR and not (myHero.pathing and myHero.pathing.isDashing) and not _G.SDK.Attack:IsActive() then
            self:UseR(target)
        end
    else
        WasInRange = false
    end     
end



function Corki:OnPostAttack(args)
end

function Corki:OnPostAttackTick(args)
end

function Corki:OnPreAttack(args)
end


function Corki:UseQ(unit, hits)
    local pred = _G.PremiumPrediction:GetAOEPrediction(myHero, unit, QSpellData)
    if pred.CastPos and pred.HitChance > self.Menu.ComboMode.UseQHitChance:Value() and myHero.pos:DistanceTo(pred.CastPos) < QRange and pred.HitCount >= hits then
        Control.CastSpell(HK_Q, pred.CastPos)
    end 
end


function Corki:UseR(unit)
    local SmallRocket = _G.SDK.BuffManager:HasBuff(myHero, "corkimissilebarragenc")
    if SmallRocket == false then
        local pred = _G.PremiumPrediction:GetPrediction(myHero, unit, BRSpellData)
        if pred.CastPos and pred.HitChance > self.Menu.ComboMode.UseQHitChance:Value()and myHero.pos:DistanceTo(pred.CastPos) < 1500 then
            Control.CastSpell(HK_R, pred.CastPos)
        end
    else
        local pred = _G.PremiumPrediction:GetPrediction(myHero, unit, RSpellData)
        if pred.CastPos and pred.HitChance > self.Menu.ComboMode.UseQHitChance:Value()and myHero.pos:DistanceTo(pred.CastPos) < 1300 then
            Control.CastSpell(HK_R, pred.CastPos)
        end  
    end
end

class "Orianna"

local EnemyLoaded = false
local Whits = 0
local Rhits = 0
local AllyLoaded = false

local GotBall = "None"
local BallUnit = myHero
local Ball = nil
local arrived = true
local CurrentSpot = myHero.pos
local LastSpot = myHero.pos
local StartSpot = myHero.pos

local CastedQ = false
local TickQ = false
local CastedE = false
local TickE = false
local CastTime = 0

local attackedfirst = 0
local WasInRange = false

function Orianna:Menu()
    self.Menu = MenuElement({type = MENU, id = "Orianna", name = "Orianna"})
    self.Menu:MenuElement({id = "ComboMode", name = "Combo", type = MENU})
    self.Menu.ComboMode:MenuElement({id = "UseQ", name = "Use Q in Combo", value = true})
    self.Menu.ComboMode:MenuElement({id = "UseW", name = "Use W in Combo", value = true})
    self.Menu.ComboMode:MenuElement({id = "UseWmin", name = "Number of Targets(W)", value = 1, min = 1, max = 5, step = 1})
    self.Menu.ComboMode:MenuElement({id = "UseE", name = "Use E in Combo", value = true})
    self.Menu.ComboMode:MenuElement({id = "UseR", name = "Use R in Combo", value = true})
    self.Menu.ComboMode:MenuElement({id = "UseRmin", name = "Number of Targets(R)", value = 2, min = 1, max = 5, step = 1})
    self.Menu:MenuElement({id = "KSMode", name = "KS", type = MENU})
    self.Menu.KSMode:MenuElement({id = "UseQ", name = "Use Q in KS", value = true})
    self.Menu.KSMode:MenuElement({id = "UseW", name = "Use W in KS", value = true})
    self.Menu.KSMode:MenuElement({id = "UseR", name = "Use R in KS", value = true})
    self.Menu:MenuElement({id = "HarassMode", name = "Harass", type = MENU})
    self.Menu.HarassMode:MenuElement({id = "UseQ", name = "Use Q in Harass", value = false})
    self.Menu.HarassMode:MenuElement({id = "UseW", name = "Use W in Harass", value = false})
    self.Menu.HarassMode:MenuElement({id = "UseWmin", name = "Number of Targets(W)", value = 1, min = 1, max = 5, step = 1})
    self.Menu.HarassMode:MenuElement({id = "UseE", name = "Use E in Harass", value = false})
    self.Menu.HarassMode:MenuElement({id = "UseR", name = "Use R in Harass", value = false})
    self.Menu.HarassMode:MenuElement({id = "UseRmin", name = "Number of Targets(R)", value = 3, min = 1, max = 5, step = 1})
    self.Menu:MenuElement({id = "AutoMode", name = "Auto", type = MENU})
    self.Menu.AutoMode:MenuElement({id = "UseQ", name = "Auto Use Q", value = false})
    self.Menu.AutoMode:MenuElement({id = "UseW", name = "Auto Use W", value = false})
    self.Menu.AutoMode:MenuElement({id = "UseWmin", name = "Number of Targets(W)", value = 1, min = 1, max = 5, step = 1})
    self.Menu.AutoMode:MenuElement({id = "UseE", name = "Auto Use E", value = false})
    self.Menu.AutoMode:MenuElement({id = "UseR", name = "Auto Use R", value = false})
    self.Menu.AutoMode:MenuElement({id = "UseRmin", name = "Number of Targets(R)", value = 3, min = 1, max = 5, step = 1})
    self.Menu:MenuElement({id = "FarmMode", name = "Farm", type = MENU})
    self.Menu.FarmMode:MenuElement({id = "UseQ", name = "Use Q to farm", value = false})
    self.Menu.FarmMode:MenuElement({id = "UseW", name = "Use W to farm", value = false})
    self.Menu.FarmMode:MenuElement({id = "UseWmin", name = "Number of Targets(W)", value = 2, min = 1, max = 10, step = 1})
    self.Menu.FarmMode:MenuElement({id = "UseE", name = "Use E to farm", value = false})
    self.Menu:MenuElement({id = "Draw", name = "Draw", type = MENU})
    self.Menu.Draw:MenuElement({id = "UseDraws", name = "Enable Draws", value = false})
end

function Orianna:Spells()
    QSpellData = {speed = 1400, range = 2000, delay = 0.10, radius = 100, collision = {}, type = "linear"}
end


function Orianna:Tick()
    if _G.JustEvade and _G.JustEvade:Evading() or (_G.ExtLibEvade and _G.ExtLibEvade.Evading) or Game.IsChatOpen() or myHero.dead then return end
    --PrintChat(myHero:GetSpellData(_W).name)
    --PrintChat(myHero:GetSpellData(_R).toggleState)
    target = GetTarget(1400)
    --PrintChat(myHero.activeSpell.name)
    --PrintChat(GotBall)
    self:ProcessSpells()
    if TickQ or TickE then
        Ball = self:ScanForBall()
        TickQ = false
        TickE = false
    end
    --self:KS()
    self:TrackBall()
    if Mode() == "LaneClear" then
        self:LaneClear()
    else
        self:Logic()
        self:Auto()
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
        end
    end
end

function Orianna:LaneClear()
    local FarmWhits = 0
    --PrintChat("Farming")
    if self:CanUse(_Q, "Farm") or self:CanUse(_W, "Farm") or self:CanUse(_E, "Farm") then
        local Minions = _G.SDK.ObjectManager:GetEnemyMinions(850)
        for i = 1, #Minions do
            local minion = Minions[i]
            local Qrange = 825
            if CurrentSpot and arrived then
                --PrintChat("Current farm spot")
                local Qdamage = getdmg("Q", minion, myHero)
                if self:CanUse(_Q, "Farm") and ValidTarget(minion, Qrange) then
                    --PrintChat("Casting Q farm")
                    self:UseQ(minion, 1)
                end
                if GetDistance(minion.pos, CurrentSpot) < 250 then
                    FarmWhits = FarmWhits + 1
                    local Wdamage = getdmg("W", minion, myHero)
                    if self:CanUse(_W, "Farm") then
                        if FarmWhits >= self.Menu.FarmMode.UseWmin:Value() then
                            Control.CastSpell(HK_W)
                        end
                    end
                end
                if self:CanUse(_E, "Farm") then
                    if GotBall == "Q" then
                        local Direction = Vector((CurrentSpot-myHero.pos):Normalized())
                        local EDist = GetDistance(minion.pos, CurrentSpot)
                        ESpot = CurrentSpot - Direction * EDist
                        if GetDistance(ESpot, minion.pos) < 100 then
                            Control.CastSpell(HK_E, myHero)
                        end                    
                    end 
                end
            end
        end
    end
end

function Orianna:ProcessSpells()
    if myHero:GetSpellData(_Q).currentCd == 0 then
        CastedQ = false
    else
        if CastedQ == false then
            --GotBall = "QCast"
            TickQ = true
        end
        CastedQ = true
    end
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

function Orianna:ScanForBall()
    local count = Game.MissileCount()
    for i = count, 1, -1 do
        local missile = Game.Missile(i)
        local data = missile.missileData
        if data and data.owner == myHero.handle then
            if data.name == "OrianaIzuna" then
                CastTime = Game.Timer()
                GotBall = "Q"
                return missile
            end
            if data.name == "OrianaRedact" then
                --PrintChat("Found E")
                if data.target then
                    --PrintChat(data.target)
                    --PrintChat(myHero.handle)
                    for i, ally in pairs(AllyHeroes) do
                        if ally and not ally.dead then
                            if ally.handle == data.target then
                                --PrintChat(ally.charName)
                                BallUnit = ally
                                GotBall = "Etarget"
                                CastTime = Game.Timer()
                                return missile
                            end
                        end
                    end
                end
                CastTime = Game.Timer()
                --GotBall = "E"
                return missile
            end
        end
    end
end

function Orianna:Draw()
    if self.Menu.Draw.UseDraws:Value() then

        Draw.Circle(myHero.pos, 100, 1, Draw.Color(255, 0, 0, 255))
        if Ball and (Ball.missileData.name == "OrianaIzuna" or Ball.missileData.name == "OrianaRedact") then
            Draw.Circle(Vector(Ball.missileData.placementPos), 100, 1, Draw.Color(255, 0, 191, 255))
        end
        if LastSpot and StartSpot then
            if GotBall == "Q" then
                Draw.Circle(LastSpot, 200, 1, Draw.Color(255, 0, 191, 255))
                Draw.Circle(StartSpot, 200, 1, Draw.Color(255, 0, 191, 255))
            elseif GotBall == "Etarget" then
                Draw.Circle(StartSpot, 200, 1, Draw.Color(255, 0, 191, 255))
                Draw.Circle(BallUnit.pos, 200, 1, Draw.Color(255, 0, 191, 255))
            end     
        end
        if CurrentSpot then
            Draw.Circle(CurrentSpot, 100, 1, Draw.Color(255, 255, 0, 100))
        end
        if target then
            AARange = _G.SDK.Data:GetAutoAttackRange(myHero)
            Draw.Circle(myHero.pos, AARange, 1, Draw.Color(255, 0, 191, 255))
        end
    end
end

function Orianna:TrackBall()
    if Ball and (Ball.missileData.name == "OrianaIzuna" or Ball.missileData.name == "OrianaRedact") then
        --PrintChat(Ball.missileData.speed)
        LastSpot = Vector(Ball.missileData.endPos)
        StartSpot = Vector(Ball.missileData.startPos)
    end
    if LastSpot and StartSpot then
        --PrintChat("Last spot and start spot")
        if GotBall == "Q" then
            local TimeGone = Game.Timer() - CastTime
            local Traveldist = 1400*TimeGone
            local Direction = Vector((StartSpot-LastSpot):Normalized())
            CurrentSpot = StartSpot - Direction * Traveldist
            if GetDistance(StartSpot, LastSpot) < Traveldist then
                arrived = true
                CurrentSpot = LastSpot
                Traveldist = GetDistance(StartSpot, LastSpot) + 100
            else
                arrived = false
            end
        elseif GotBall == "Etarget" then
            --PrintChat("Got Etarget")
            local TimeGone = Game.Timer() - CastTime
            local Traveldist = 1850*TimeGone
            local Direction = Vector((StartSpot-BallUnit.pos):Normalized())
            CurrentSpot = StartSpot - Direction * Traveldist
            if GetDistance(StartSpot, BallUnit.pos) < Traveldist then
                arrived = true
                CurrentSpot = BallUnit.pos
                Traveldist = GetDistance(StartSpot, BallUnit.pos) + 100
            else
                arrived = false
            end
        elseif GotBall == "None" then
            --PrintChat("none")
            CurrentSpot = myHero.pos
        end
        if (GetDistance(CurrentSpot, myHero.pos) > 1250 or GetDistance(CurrentSpot, myHero.pos) < 100) and GotBall == "Q" and arrived == true then
            --PrintChat("Returning Q")
            CurrentSpot = myHero.pos
            GotBall = "Return"
        elseif GetDistance(CurrentSpot, myHero.pos) > 1350 and (GotBall == "Etarget" or GotBall == "E") and arrived == true then
            --PrintChat("Returning E")
            --PrintChat(GetDistance(CurrentSpot, myHero.pos))
            CurrentSpot = myHero.pos
            BallUnit = nil
            GotBall = "Return"
        end
        if GotBall == "Return" then
            CurrentSpot = myHero.pos
        end   
    end
end 

function Orianna:KS()
    --PrintChat("ksing")
    for i, enemy in pairs(EnemyHeroes) do
        if enemy and not enemy.dead and ValidTarget(enemy) then
            local Qrange = 600
            local Qdamage = getdmg("Q", enemy, myHero, myHero:GetSpellData(_Q).level)
            if CurrentSpot and arrived then
                if self:CanUse(_Q, "KS") and GetDistance(enemy.pos, CurrentSpot) < Qrange and enemy.health < Qdamage then
                    self:UseQ(enemy)
                end
            end
        end
    end
end 

function Orianna:Auto()
    Whits = 0
    Rhits = 0
    for i, enemy in pairs(EnemyHeroes) do
        if enemy and not enemy.dead and ValidTarget(enemy) then
            local Qrange = 825
            if CurrentSpot and arrived then
                local what = nil
                local Qdamage = getdmg("Q", enemy, myHero)
                if self:CanUse(_Q, "KS") and ValidTarget(enemy, Qrange) and Qdamage > enemy.health then
                    self:UseQ(enemy, 1)
                end
                if self:CanUse(_Q, "Auto") and ValidTarget(enemy, Qrange) then
                    self:UseQ(enemy, 1)
                end
                if GetDistance(enemy.pos, CurrentSpot) < 250 then
                    Whits = Whits + 1
                    local Wdamage = getdmg("W", enemy, myHero)
                    if self:CanUse(_W, "Auto") then
                        if Whits >= self.Menu.AutoMode.UseWmin:Value() then
                            Control.CastSpell(HK_W)
                        end
                    end
                    if self:CanUse(_W, "KS") then
                        if enemy.health < Wdamage then
                            Control.CastSpell(HK_W)
                        end
                    end
                end
                if GetDistance(enemy.pos, CurrentSpot) < 270 then
                    Rhits = Rhits + 1
                    local Rdamage = getdmg("R", enemy, myHero)
                    if self:CanUse(_R, "Auto") then
                        if Rhits >= self.Menu.AutoMode.UseRmin:Value() then
                            Control.CastSpell(HK_R)
                        end
                    end
                    if self:CanUse(_R, "KS") then
                        if enemy.health < Rdamage then
                            Control.CastSpell(HK_R)
                        end
                    end
                end
                if self:CanUse(_E, "Auto") then
                    if GotBall == "Q" then
                        if (GetDistance(enemy.pos, CurrentSpot) > 250 or not self:CanUse(_W, "Auto") or Whits < self.Menu.AutoMode.UseWmin:Value()) and (GetDistance(enemy.pos, CurrentSpot) > 325 or not self:CanUse(_R, "Auto") or Whits < self.Menu.AutoMode.UseRmin:Value()) then
                            local Direction = Vector((CurrentSpot-myHero.pos):Normalized())
                            local EDist = GetDistance(enemy.pos, CurrentSpot)
                            ESpot = CurrentSpot - Direction * EDist
                            if GetDistance(ESpot, enemy.pos) < 100 then
                                Control.CastSpell(HK_E, myHero)
                            end 
                        end                   
                    end 
                end
            end
        end
    end
end

function Orianna:CanUse(spell, mode)
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
        if mode == "KS" and IsReady(spell) and self.Menu.KSMode.UseQ:Value() then
            return true
        end
        if mode == "Auto" and IsReady(spell) and self.Menu.AutoMode.UseQ:Value() then
            return true
        end
        if mode == "Farm" and IsReady(spell) and self.Menu.FarmMode.UseQ:Value() then
            return true
        end
    elseif spell == _W then
        if mode == "Combo" and IsReady(spell) and self.Menu.ComboMode.UseW:Value() then
            return true
        end
        if mode == "Harass" and IsReady(spell) and self.Menu.HarassMode.UseW:Value() then
            return true
        end
        if mode == "KS" and IsReady(spell) and self.Menu.KSMode.UseW:Value() then
            return true
        end
        if mode == "Auto" and IsReady(spell) and self.Menu.AutoMode.UseW:Value() then
            return true
        end
        if mode == "Farm" and IsReady(spell) and self.Menu.FarmMode.UseW:Value() then
            return true
        end
    elseif spell == _E then
        if mode == "Combo" and IsReady(spell) and self.Menu.ComboMode.UseE:Value() then
            return true
        end
        if mode == "Harass" and IsReady(spell) and self.Menu.HarassMode.UseE:Value() then
            return true
        end
        if mode == "Auto" and IsReady(spell) and self.Menu.AutoMode.UseE:Value() then
            return true
        end
        if mode == "Farm" and IsReady(spell) and self.Menu.FarmMode.UseE:Value() then
            return true
        end
    elseif spell == _R then
        if mode == "Combo" and IsReady(spell) and self.Menu.ComboMode.UseR:Value() then
            return true
        end
        if mode == "Harass" and IsReady(spell) and self.Menu.HarassMode.UseR:Value() then
            return true
        end
        if mode == "KS" and IsReady(spell) and self.Menu.KSMode.UseR:Value() then
            return true
        end
        if mode == "Auto" and IsReady(spell) and self.Menu.AutoMode.UseR:Value() then
            return true
        end
    end
    return false
end

function Orianna:Logic()
    if target == nil then return end
    if Mode() == "Combo" or Mode() == "Harass" and target then
        local AARange = _G.SDK.Data:GetAutoAttackRange(myHero)
        if GetDistance(target.pos) < AARange then
            WasInRange = true
        end
        local Qrange = 825
        if CurrentSpot and arrived then
            if self:CanUse(_Q, Mode()) and ValidTarget(target, Qrange) then
                self:UseQ(target, 1)
            end
            if self:CanUse(_W, Mode()) and GetDistance(target.pos, CurrentSpot) < 250 then
                --PrintChat("Can use W")
                if Mode() == "Combo" and Whits >= self.Menu.ComboMode.UseWmin:Value() then
                    Control.CastSpell(HK_W)
                elseif Mode() == "Harass" and Whits >= self.Menu.HarassMode.UseWmin:Value() then
                    Control.CastSpell(HK_W)
                end
            end
            if self:CanUse(_R, Mode()) and GetDistance(target.pos, CurrentSpot) < 270 then
                if Mode() == "Combo" and Rhits >= self.Menu.ComboMode.UseRmin:Value() then
                    Control.CastSpell(HK_R)
                elseif Mode() == "Harass" and Rhits >= self.Menu.HarassMode.UseRmin:Value() then
                    Control.CastSpell(HK_R)
                end
            end
            if self:CanUse(_E, Mode()) then
                if GotBall == "Q" then
                    if (GetDistance(target.pos, CurrentSpot) > 250 or not self:CanUse(_W, Mode()) or Whits < self.Menu.ComboMode.UseWmin:Value()) and (GetDistance(target.pos, CurrentSpot) > 325 or not self:CanUse(_R, Mode()) or Rhits < self.Menu.ComboMode.UseRmin:Value()) then
                        local Direction = Vector((CurrentSpot-myHero.pos):Normalized())
                        local EDist = GetDistance(target.pos, CurrentSpot)
                        ESpot = CurrentSpot - Direction * EDist
                        if GetDistance(ESpot, target.pos) < 100 then
                            Control.CastSpell(HK_E, myHero)
                        end
                    end                    
                end 
            end
        end
    else
        WasInRange = false
    end     
end

function Orianna:OnPostAttackTick(args)
    attackedfirst = 1
    if target then
    end
end


function Orianna:GetRDmg(unit)
    return getdmg("R", unit, myHero, stage, myHero:GetSpellData(_R).level)
end

function Orianna:OnPreAttack(args)
    if self:CanUse(_E, Mode()) and target then
    end
end

function Orianna:UseQ(unit, hits)
    if arrived and CurrentSpot then
        if self:CanUse(_E, Mode()) then
            local ErouteDist = GetDistance(myHero.pos, unit.pos) + GetDistance(myHero.pos, CurrentSpot) * 0.75
            if GetDistance(CurrentSpot, unit.pos) > ErouteDist then
                Control.CastSpell(HK_E, myHero)
            else
                pred = _G.PremiumPrediction:GetAOEPrediction(CurrentSpot, unit, QSpellData)
                if pred.CastPos and _G.PremiumPrediction.HitChance.Low(pred.HitChance) and myHero.pos:DistanceTo(pred.CastPos) < 825 and pred.HitCount >= hits then
                    Control.CastSpell(HK_Q, pred.CastPos)
                end            
            end
        else
            pred = _G.PremiumPrediction:GetAOEPrediction(CurrentSpot, unit, QSpellData)
            if pred.CastPos and _G.PremiumPrediction.HitChance.Low(pred.HitChance) and myHero.pos:DistanceTo(pred.CastPos) < 825 and pred.HitCount >= hits then
                    Control.CastSpell(HK_Q, pred.CastPos)
            end
        end
    end
end

function Orianna:UseW(card)
    if card == "Gold" then
        card = "GoldCardLock"
    else
        card = "BlueCardLock"
    end
    if myHero:GetSpellData(_W).name == card then
        Control.CastSpell(HK_W)
        PickingCard = false
        LockGold = false
        LockBlue = false
        ComboCard = "Gold"
    elseif myHero:GetSpellData(_W).name == "PickACard" then
        if PickingCard == false then
            Control.CastSpell(HK_W)
            PickingCard = true
        end
    else
        PickingCard = false
    end
end





class "Neeko"

local EnemyLoaded = false
local casted = 0
local LastCalledTime = 0
local LastESpot = myHero.pos
local LastE2Spot = myHero.pos
local PickingCard = false
local TargetAttacking = false
local attackedfirst = 0
local CastingQ = false
local LastDirect = 0
local CastingW = false
local CastingR = false
local ReturnMouse = mousePos
local Q = 1
local Edown = false
local R = 1
local WasInRange = false
local OneTick
local attacked = 0

function Neeko:Menu()
    self.Menu = MenuElement({type = MENU, id = "Neeko", name = "Neeko"})
    self.Menu:MenuElement({id = "FleeKey", name = "Disengage Key", key = string.byte("T"), value = false})
    self.Menu:MenuElement({id = "ComboMode", name = "Combo", type = MENU})
    self.Menu.ComboMode:MenuElement({id = "UseQ", name = "Use Q in Combo", value = true})
    self.Menu.ComboMode:MenuElement({id = "UseE", name = "Use E in Combo", value = true})
    self.Menu:MenuElement({id = "HarassMode", name = "Harass", type = MENU})
    self.Menu.HarassMode:MenuElement({id = "UseQ", name = "Use Q in Harass", value = false})
    self.Menu.HarassMode:MenuElement({id = "UseE", name = "Use E in Harass", value = false})

    self.Menu:MenuElement({id = "FleeMode", name = "Flee", type = MENU})
    self.Menu.FleeMode:MenuElement({id = "UseQ", name = "Use Q to Flee", value = true})
    self.Menu.FleeMode:MenuElement({id = "UseE", name = "Use E to Flee", value = true})

    self.Menu:MenuElement({id = "KSMode", name = "KS", type = MENU})
    self.Menu.KSMode:MenuElement({id = "UseQ", name = "Use Q in KS", value = true})
    self.Menu.KSMode:MenuElement({id = "UseE", name = "Use E in KS", value = true})

    self.Menu:MenuElement({id = "Draw", name = "Draw", type = MENU})
    self.Menu.Draw:MenuElement({id = "UseDraws", name = "Enable Draws", value = false})
end

function Neeko:Spells()
    ESpellData = {speed = 1300, range = 1000, delay = 0.25, radius = 70, collision = {}, type = "linear"}
    QSpellData = {speed = 1300, range = 800, delay = 0.10, radius = 225, collision = {}, type = "circular"}
end


function Neeko:Tick()
    if _G.JustEvade and _G.JustEvade:Evading() or (_G.ExtLibEvade and _G.ExtLibEvade.Evading) or Game.IsChatOpen() or myHero.dead then return end
    target = GetTarget(1400)
    CastingQ = myHero.activeSpell.name == "NeekoQ"
    CastingE = myHero.activeSpell.name == "NeekoE"
    --PrintChat(myHero.activeSpell.name)
    --PrintChat(myHero:GetSpellData(_R).name)
    self:Logic()
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

function Neeko:Draw()
    if self.Menu.Draw.UseDraws:Value() then
        Draw.Circle(myHero.pos, 225, 1, Draw.Color(255, 0, 191, 255))
        if target then
        end
    end
end

function Neeko:KS()
    --PrintChat("ksing")
    for i, enemy in pairs(EnemyHeroes) do
        if enemy and not enemy.dead and ValidTarget(enemy) then
        end
    end
end 

function Neeko:CanUse(spell, mode)
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
        if mode == "Flee" and IsReady(spell) and self.Menu.FleeMode.UseQ:Value() then
            return true
        end
        if mode == "KS" and IsReady(spell) and self.Menu.KSMode.UseQ:Value() then
            return true
        end
    elseif spell == _R then
        if mode == "Combo" and IsReady(spell) and self.Menu.ComboMode.UseR:Value() then
            return true
        end
        if mode == "Harass" and IsReady(spell) and self.Menu.HarassMode.UseR:Value() then
            return true
        end
        if mode == "KS" and IsReady(spell) and self.Menu.KSMode.UseR:Value() then
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
        if mode == "Harass" and IsReady(spell) and self.Menu.HarassMode.UseE:Value() then
            return true
        end
        if mode == "Flee" and IsReady(spell) and self.Menu.FleeMode.UseE:Value() then
            return true
        end
        if mode == "KS" and IsReady(spell) and self.Menu.KSMode.UseE:Value() then
            return true
        end
    end
    return false
end



function Neeko:Logic()
    if target == nil then return end
    if Mode() == "Combo" or Mode() == "Harass" and target then
        local AARange = _G.SDK.Data:GetAutoAttackRange(myHero)
        if GetDistance(target.pos) < AARange then
            WasInRange = true
        end
        local ERange = 1000
        local QRange = 800
        if self:CanUse(_E, Mode()) and ValidTarget(target, ERange) and not CastingQ and not CastingE then
            self:UseE(target, 1)
        end
        if self:CanUse(_Q, Mode()) and ValidTarget(target, QRange) and not CastingQ and not CastingE then
            self:UseQ(target, 1)
        end
    else
        WasInRange = false
    end     
end

function Neeko:OnPostAttackTick(args)
    if target then
    end
    attackedfirst = 1
    attacked = 1
end

function Neeko:OnPreAttack(args)
    if self:CanUse(_E, Mode()) and target then
    end
end

function Neeko:UseE(unit, hits)
    local pred = _G.PremiumPrediction:GetAOEPrediction(myHero, unit, ESpellData)
    if pred.CastPos and _G.PremiumPrediction.HitChance.Low(pred.HitChance) and myHero.pos:DistanceTo(pred.CastPos) < 1001 and pred.HitCount >= hits then
        Control.CastSpell(HK_E, pred.CastPos)
    end 
end

function Neeko:UseQ(unit, hits)
    local pred = _G.PremiumPrediction:GetAOEPrediction(myHero, unit, QSpellData)
    if pred.CastPos and _G.PremiumPrediction.HitChance.Low(pred.HitChance) and pred.HitCount >= hits then
        if myHero.pos:DistanceTo(pred.CastPos) < 801 then
            Control.CastSpell(HK_Q, pred.CastPos)
        else
            local Direction = Vector((myHero.pos-pred.CastPos):Normalized())
            local Espot = myhero.pos - Direction*800
            Control.CastSpell(HK_Q, pred.Espot)
        end
    end 
end

class "Viktor"

local EnemyLoaded = false
local casted = 0
local LastCalledTime = 0
local LastESpot = myHero.pos
local LastE2Spot = myHero.pos
local PickingCard = false
local TargetAttacking = false
local attackedfirst = 0
local CastingQ = false
local LastDirect = 0
local CastingW = false
local CastingR = false
local ReturnMouse = mousePos
local Q = 1
local Edown = false
local R = 1
local WasInRange = false
local OneTick
local attacked = 0

function Viktor:Menu()
    self.Menu = MenuElement({type = MENU, id = "Viktor", name = "Viktor"})
    self.Menu:MenuElement({id = "FleeKey", name = "Disengage Key", key = string.byte("T"), value = false})
    self.Menu:MenuElement({id = "ComboMode", name = "Combo", type = MENU})
    self.Menu.ComboMode:MenuElement({id = "UseQ", name = "Use Q in Combo", value = true})
    self.Menu.ComboMode:MenuElement({id = "UseW", name = "Use W in Combo", value = true})
    self.Menu.ComboMode:MenuElement({id = "UseE", name = "Use E in Combo", value = true})
    self.Menu.ComboMode:MenuElement({id = "UseEDef", name = "Use Defensive E in Combo", value = true})
    self.Menu.ComboMode:MenuElement({id = "UseEAtt", name = "Use Offensive E in Combo", value = true})
    self.Menu.ComboMode:MenuElement({id = "UseEAttHits", name = "Min enemies for Offensive E", value = 1, min = 1, max = 5, step = 1})
    self.Menu.ComboMode:MenuElement({id = "UseR", name = "Use R in Combo", value = true})
    self.Menu:MenuElement({id = "HarassMode", name = "Harass", type = MENU})
    self.Menu.HarassMode:MenuElement({id = "UseQ", name = "Use Q in Harass", value = false})
    self.Menu.HarassMode:MenuElement({id = "UseE", name = "Use E in Harass", value = false})
    self.Menu.HarassMode:MenuElement({id = "UseW", name = "Use W in Harass", value = false})
    self.Menu.HarassMode:MenuElement({id = "UseR", name = "Use R in Harass", value = false})

    self.Menu:MenuElement({id = "FleeMode", name = "Flee", type = MENU})
    self.Menu.FleeMode:MenuElement({id = "UseQ", name = "Use Q to Flee", value = true})
    self.Menu.FleeMode:MenuElement({id = "UseE", name = "Use E to Flee", value = true})

    self.Menu:MenuElement({id = "KSMode", name = "KS", type = MENU})
    self.Menu.KSMode:MenuElement({id = "UseQ", name = "Use Q in KS", value = true})

    self.Menu:MenuElement({id = "Draw", name = "Draw", type = MENU})
    self.Menu.Draw:MenuElement({id = "UseDraws", name = "Enable Draws", value = false})
end

function Viktor:Spells()
    ESpellData = {speed = 1350, range = 500, delay = 0.25, radius = 70, collision = {}, type = "linear"}
    WSpellData = {speed = 3000, range = 800, delay = 0.5, radius = 300, collision = {}, type = "circular"}
    RSpellData = {speed = 3000, range = 700, delay = 0.25, radius = 300, collision = {}, type = "circular"}
end

function Viktor:Tick()
    if _G.JustEvade and _G.JustEvade:Evading() or (_G.ExtLibEvade and _G.ExtLibEvade.Evading) or Game.IsChatOpen() or myHero.dead then return end
    target = GetTarget(1400)
    CastingQ = myHero.activeSpell.name == "ViktorPowerTransfer"
    CastingW = myHero.activeSpell.name == "ViktorGravitonField"
    CastingR = myHero.activeSpell.name == "ViktorChaosStorm"
    --PrintChat(myHero.activeSpell.name)
    --PrintChat(myHero:GetSpellData(_R).name)
    self:Logic()
    if not IsReady(_E) then
        Edown = false
    end
    if Edown == true then
        _G.SDK.Orbwalker:SetMovement(false)
    else
        _G.SDK.Orbwalker:SetMovement(true)
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

function Viktor:Draw()
    if self.Menu.Draw.UseDraws:Value() then
        Draw.Circle(myHero.pos, 300, 1, Draw.Color(255, 0, 191, 255))
        if target then
        end
    end
end

function Viktor:KS()
    --PrintChat("ksing")
    for i, enemy in pairs(EnemyHeroes) do
        if enemy and not enemy.dead and ValidTarget(enemy) then
        end
    end
end 

function Viktor:CanUse(spell, mode)
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
        if mode == "Flee" and IsReady(spell) and self.Menu.FleeMode.UseQ:Value() then
            return true
        end
        if mode == "KS" and IsReady(spell) and self.Menu.KSMode.UseQ:Value() then
            return true
        end
    elseif spell == _R then
        if mode == "Combo" and IsReady(spell) and self.Menu.ComboMode.UseR:Value() then
            return true
        end
        if mode == "Harass" and IsReady(spell) and self.Menu.HarassMode.UseR:Value() then
            return true
        end
        if mode == "KS" and IsReady(spell) and self.Menu.KSMode.UseR:Value() then
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
        if mode == "Harass" and IsReady(spell) and self.Menu.HarassMode.UseE:Value() then
            return true
        end
        if mode == "Flee" and IsReady(spell) and self.Menu.FleeMode.UseE:Value() then
            return true
        end
    end
    return false
end


function Viktor:DelayEscapeClick(delay)
    if Game.Timer() - LastCalledTime > delay then
        LastCalledTime = Game.Timer()
        Control.RightClick(mousePos:To2D())
    end
end


function Viktor:Logic()
    if target == nil then return end
    if Mode() == "Combo" or Mode() == "Harass" and target then
        local AARange = _G.SDK.Data:GetAutoAttackRange(myHero)
        if GetDistance(target.pos) < AARange then
            WasInRange = true
        end
        local ERange = 1025
        local QRange = 600
        local WRange = 800
        local RRange = 700
        local TargetNextSpot = GetUnitPositionNext(target)
        if TargetNextSpot then
            TargetAttacking = GetDistance(myHero.pos, target.pos) > GetDistance(myHero.pos, TargetNextSpot)
        else
            TargetAttacking = false
        end

        if self:CanUse(_W, Mode()) and ValidTarget(target, WRange) and Edown == false and not CastingQ and not CastingW then
            if target.pathing.isDashing and TargetAttacking and self.Menu.ComboMode.UseEDef:Value() then
                Control.CastSpell(HK_W, myHero)
            elseif GetDistance(myHero.pos, target.pos) < 300 and self.Menu.ComboMode.UseEDef:Value() then
                Control.CastSpell(HK_W, myHero)
            elseif self.Menu.ComboMode.UseEAtt:Value() then
                self:UseW(target, self.Menu.ComboMode.UseEAttHits:Value(), TargetAttacking)
            end
        end
        if self:CanUse(_E, Mode()) and ValidTarget(target, ERange) and not CastingQ and not CastingW and not CastingR then
            self:UseE(target)
        end
        if self:CanUse(_Q, Mode()) and ValidTarget(target, QRange) and Edown == false and not CastingQ and not CastingW and not CastingR then
            Control.CastSpell(HK_Q, target)
        end
        local RDmg = getdmg("R", target, myHero, 1, myHero:GetSpellData(_R).level)
        local RDmgTick = getdmg("R", target, myHero, 2, myHero:GetSpellData(_R).level)
        local RDmgTotal = RDmg + RDmgTick*2
        if self:CanUse(_R, Mode()) and ValidTarget(target, RRange) and Edown == false and not CastingQ and not CastingW and not CastingR and target.health < RDmgTotal and myHero:GetSpellData(_R).name == "ViktorChaosStorm"then
            Control.CastSpell(HK_R, target)
            --LastDirect = Game.Timer() + 1
        end
        if self:CanUse(_R, Mode()) and ValidTarget(target) and Edown == false and not CastingQ and not CastingW and not CastingR and myHero:GetSpellData(_R).name == "ViktorChaosStormGuide" and (myHero.attackData.state == 3 or GetDistance(myHero.pos, target.pos) > AARange) then
            self:DirectR(target.pos)
        end
    else
        WasInRange = false
    end     
end

function Viktor:DirectR(spot)
    if LastDirect - Game.Timer() < 0 then
        Control.CastSpell(HK_R, target)
        LastDirect = Game.Timer() + 1
    end
end

function Viktor:UseE2(ECastPos, unit, pred)
    if Control.IsKeyDown(HK_E) then
        Control.SetCursorPos(pred.CastPos)
        Control.KeyUp(HK_E)
        DelayAction(function() Control.SetCursorPos(ReturnMouse) end, 0.01)
        DelayAction(function() Edown = false end, 0.50)   
    end
end

function Viktor:OnPostAttackTick(args)
    if target then
    end
    attackedfirst = 1
    attacked = 1
end

function Viktor:OnPreAttack(args)
    if self:CanUse(_E, Mode()) and target then
    end
end


function Viktor:UseR1(unit, hits)
    local pred = _G.PremiumPrediction:GetAOEPrediction(myHero, unit, RSpellData)
    --PrintChat("trying E")
    if pred.CastPos and _G.PremiumPrediction.HitChance.Low(pred.HitChance) and myHero.pos:DistanceTo(pred.CastPos) < 701 and pred.HitCount >= hits then
            Control.CastSpell(HK_R, pred.CastPos)
            --Casted = 1
    end 
end

function Viktor:UseW(unit, hits, attacking)
    local pred = _G.PremiumPrediction:GetAOEPrediction(myHero, unit, WSpellData)
    --PrintChat("trying E")
    if pred.CastPos and _G.PremiumPrediction.HitChance.Medium(pred.HitChance) and myHero.pos:DistanceTo(pred.CastPos) < 801 and pred.HitCount >= hits then
        if attacking == true then
            local Direction = Vector((pred.CastPos-myHero.pos):Normalized())
            local Wspot = pred.CastPos - Direction*100
            Control.CastSpell(HK_W, Wspot)
        else
            local Direction = Vector((pred.CastPos-myHero.pos):Normalized())
            local Wspot = pred.CastPos + Direction*100
            if GetDistance(myHero.pos, Wspot) > 800 then
                Control.CastSpell(HK_W, pred.CastPos)
            else
                Control.CastSpell(HK_W, Wspot)
            end
        end
            --Casted = 1
    end 
end

function Viktor:UseE(unit)
    if GetDistance(unit.pos, myHero.pos) < 1025 then
        --PrintChat("Using E")
        local Direction = Vector((myHero.pos-unit.pos):Normalized())
        local Espot = myHero.pos - Direction*480
        if GetDistance(myHero.pos, unit.pos) < 480 then
            Espot = unit.pos
        end
        --Control.SetCursorPos(Espot)
        --Control.CastSpell(HK_E, unit)
        local pred = _G.PremiumPrediction:GetPrediction(Espot, unit, ESpellData)
        if pred.CastPos and _G.PremiumPrediction.HitChance.Low(pred.HitChance) and Espot:DistanceTo(pred.CastPos) < 501 then
            if Control.IsKeyDown(HK_E) and Edown == true then
                --_G.SDK.Orbwalker:SetMovement(false)
                --PrintChat("E down")
                self:UseE2(Espot, unit, pred)
            elseif Edown == false then
                --_G.SDK.Orbwalker:SetMovement(true)
                ReturnMouse = mousePos
                --PrintChat("Pressing E")
                Control.SetCursorPos(Espot)
                Control.KeyDown(HK_E)
                Edown = true
            end
        end
    end
end

class "Jayce"

local EnemyLoaded = false
local casted = 0
local LastESpot = myHero.pos
local LastE2Spot = myHero.pos
local attackedfirst = 0
local Weapon = "Hammer"
local Wbuff = false
local LastCalledTime = 0
local StartSpot = nil
local Q2CD = Game.Timer()
local W2CD = Game.Timer()
local E2CD = Game.Timer()
local Q1CD = Game.Timer()
local W1CD = Game.Timer()
local E1CD = Game.Timer()
local WasInRange = false

function Jayce:Menu()
    self.Menu = MenuElement({type = MENU, id = "Jayce", name = "Jayce"})
    self.Menu:MenuElement({id = "Insec", name = "Insec Key", key = string.byte("A"), value = false})
    self.Menu:MenuElement({id = "QE", name = "Manual QE", key = string.byte("T"), value = false})
    self.Menu:MenuElement({id = "AimQE", name = "Aim Assist on Manual QE", value = true})
    self.Menu:MenuElement({id = "ComboMode", name = "Combo", type = MENU})
    self.Menu.ComboMode:MenuElement({id = "UseQ", name = "Use Q in Combo", value = true})
    self.Menu.ComboMode:MenuElement({id = "UseW", name = "Use W in Combo", value = true})
    self.Menu.ComboMode:MenuElement({id = "UseE", name = "Use E in Combo", value = true})
    self.Menu.ComboMode:MenuElement({id = "UseR", name = "Use R in Combo", value = true})
    self.Menu.ComboMode:MenuElement({id = "UseQ2", name = "Use Q2 in Combo", value = true})
    self.Menu.ComboMode:MenuElement({id = "UseW2", name = "Use W2 in Combo", value = true})
    self.Menu.ComboMode:MenuElement({id = "UseE2", name = "Use E2 in Combo", value = true})
    self.Menu.ComboMode:MenuElement({id = "UseR2", name = "Use R2 in Combo", value = true})
    self.Menu:MenuElement({id = "KSMode", name = "KS", type = MENU})
    self.Menu.KSMode:MenuElement({id = "UseQ", name = "Use Q in KS", value = true})
    self.Menu.KSMode:MenuElement({id = "UseW", name = "Use W in KS", value = true})
    self.Menu.KSMode:MenuElement({id = "UseE", name = "Use E in KS", value = true})
    self.Menu.KSMode:MenuElement({id = "UseR", name = "Use R in KS", value = true})
    self.Menu.KSMode:MenuElement({id = "UseQ2", name = "Use Q2 in KS", value = true})
    self.Menu.KSMode:MenuElement({id = "UseW2", name = "Use W2 in KS", value = true})
    self.Menu.KSMode:MenuElement({id = "UseE2", name = "Use E2 in KS", value = true})
    self.Menu.KSMode:MenuElement({id = "UseR2", name = "Use R2 in KS", value = true})
    self.Menu:MenuElement({id = "HarassMode", name = "Harass", type = MENU})
    self.Menu.HarassMode:MenuElement({id = "UseQ", name = "Use Q in Harass", value = false})
    self.Menu.HarassMode:MenuElement({id = "UseW", name = "Use W in Harass", value = false})
    self.Menu.HarassMode:MenuElement({id = "UseE", name = "Use E in Harass", value = false})
    self.Menu.HarassMode:MenuElement({id = "UseR", name = "Use R in Harass", value = false})
    self.Menu.HarassMode:MenuElement({id = "UseQ2", name = "Use Q2 in Harass", value = false})
    self.Menu.HarassMode:MenuElement({id = "UseW2", name = "Use W2 in Harass", value = false})
    self.Menu.HarassMode:MenuElement({id = "UseE2", name = "Use E2 in Harass", value = false})
    self.Menu.HarassMode:MenuElement({id = "UseR2", name = "Use R2 in Harass", value = false})
    self.Menu:MenuElement({id = "Draw", name = "Draw", type = MENU})
    self.Menu.Draw:MenuElement({id = "UseDraws", name = "Enable Draws", value = false})
end

function Jayce:Spells()
    QSpellData = {speed = 1450, range = 1050, delay = 0.1515, radius = 70, collision = {"minion"}, type = "linear"}
    Q2SpellData = {speed = 1890, range = 1470, delay = 0.1515, radius = 70, collision = {"minion"}, type = "linear"}
end


function Jayce:Tick()
    if _G.JustEvade and _G.JustEvade:Evading() or (_G.ExtLibEvade and _G.ExtLibEvade.Evading) or Game.IsChatOpen() or myHero.dead then return end
    --PrintChat(myHero:GetSpellData(_R).name)
    --PrintChat(myHero:GetSpellData(_R).toggleState)
    target = GetTarget(1600)
    --PrintChat(myHero.activeSpell.name)
    Wbuff = _G.SDK.BuffManager:HasBuff(myHero, "jaycehypercharge")
    if myHero:GetSpellData(_R).name == "JayceStanceHtG" then
        Weapon = "Hammer"
    else
        Weapon = "Gun"
    end
    self:GetCDs()
    --PrintChat(Q2CD)
    self:KS()
    if self.Menu.QE:Value() and Weapon == "Gun" then 
        self:QECombo()
    end
    if self.Menu.Insec:Value() then
        SetMovement(false)
        self:Insec()
    else
        StartSpot = nil
        SetMovement(true)
        self:Logic()
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

function Jayce:Draw()
    if self.Menu.Draw.UseDraws:Value() then

        --Draw.Circle(LastESpot, 85, 1, Draw.Color(255, 0, 0, 255))
        --Draw.Circle(LastE2Spot, 85, 1, Draw.Color(255, 255, 0, 255))
        if target then
            AARange = _G.SDK.Data:GetAutoAttackRange(myHero)
            Draw.Circle(myHero.pos, AARange, 1, Draw.Color(255, 0, 191, 255))
        end
    end
end

function Jayce:GetCDs()
    if Weapon == "Hammer" then
        if not IsReady(_Q) then
            Q1CD = Game:Timer() + myHero:GetSpellData(0).currentCd
        end
        if not IsReady(_W) then
            W1CD = Game:Timer() + myHero:GetSpellData(1).currentCd
        end
        if not IsReady(_E) then
            E1CD = Game:Timer() + myHero:GetSpellData(2).currentCd
        end
    else
        if not IsReady(_Q) then
            Q2CD = Game:Timer() + myHero:GetSpellData(0).currentCd
        end
        if not IsReady(_W) then
            W2CD = Game:Timer() + myHero:GetSpellData(1).currentCd
        end
        if not IsReady(_E) then
            E2CD = Game:Timer() + myHero:GetSpellData(2).currentCd
        end
    end
end

function Jayce:KS()
    --PrintChat("ksing")
    for i, enemy in pairs(EnemyHeroes) do
        if enemy and not enemy.dead and ValidTarget(enemy) then
        end
    end
end 

function Jayce:CanUse(spell, mode, rmode)
    if mode == nil then
        mode = Mode()
    end
    if not rmode then
        rmode = Weapon
    end
    --PrintChat(Mode())
    if rmode == "Hammer" then
        if spell == _Q then
            if mode == "Combo" and IsReady(spell) and self.Menu.ComboMode.UseQ:Value() then
                return true
            end
            if mode == "Harass" and IsReady(spell) and self.Menu.HarassMode.UseQ:Value() then
                return true
            end
            if mode == "KS" and IsReady(spell) and self.Menu.KSMode.UseQ:Value() then
                return true
            end
        elseif spell == _W then
            if mode == "Combo" and IsReady(spell) and self.Menu.ComboMode.UseW:Value() then
                return true
            end
            if mode == "Harass" and IsReady(spell) and self.Menu.HarassMode.UseW:Value() then
                return true
            end
            if mode == "KS" and IsReady(spell) and self.Menu.KSMode.UseW:Value() then
                return true
            end
        elseif spell == _E then
            if mode == "Combo" and IsReady(spell) and self.Menu.ComboMode.UseE:Value() then
                return true
            end
            if mode == "Harass" and IsReady(spell) and self.Menu.HarassMode.UseE:Value() then
                return true
            end
            if mode == "KS" and IsReady(spell) and self.Menu.KSMode.UseE:Value() then
                return true
            end
        elseif spell == _R then
            if mode == "Combo" and IsReady(spell) and self.Menu.ComboMode.UseR:Value() then
                return true
            end
            if mode == "Harass" and IsReady(spell) and self.Menu.HarassMode.UseR:Value() then
                return true
            end
            if mode == "KS" and IsReady(spell) and self.Menu.KSMode.UseR:Value() then
                return true
            end
        end
    else
        if spell == _Q then
            if mode == "Combo" and IsReady(spell) and self.Menu.ComboMode.UseQ2:Value() then
                return true
            end
            if mode == "Harass" and IsReady(spell) and self.Menu.HarassMode.UseQ2:Value() then
                return true
            end
            if mode == "KS" and IsReady(spell) and self.Menu.KSMode.UseQ2:Value() then
                return true
            end
        elseif spell == _W then
            if mode == "Combo" and IsReady(spell) and self.Menu.ComboMode.UseW2:Value() then
                return true
            end
            if mode == "Harass" and IsReady(spell) and self.Menu.HarassMode.UseW2:Value() then
                return true
            end
            if mode == "KS" and IsReady(spell) and self.Menu.KSMode.UseW2:Value() then
                return true
            end
        elseif spell == _E then
            if mode == "Combo" and IsReady(spell) and self.Menu.ComboMode.UseE2:Value() then
                return true
            end
            if mode == "Harass" and IsReady(spell) and self.Menu.HarassMode.UseE2:Value() then
                return true
            end
            if mode == "KS" and IsReady(spell) and self.Menu.KSMode.UseE2:Value() then
                return true
            end
        elseif spell == _R then
            if mode == "Combo" and IsReady(spell) and self.Menu.ComboMode.UseR2:Value() then
                return true
            end
            if mode == "Harass" and IsReady(spell) and self.Menu.HarassMode.UseR2:Value() then
                return true
            end
            if mode == "KS" and IsReady(spell) and self.Menu.KSMode.UseR2:Value() then
                return true
            end
        end
    end
    return false
end

function Jayce:Logic()
    if target == nil then return end
    if Mode() == "Combo" or Mode() == "Harass" and target then
        local AARange = _G.SDK.Data:GetAutoAttackRange(myHero)
        if GetDistance(target.pos) < AARange then
            WasInRange = true
        end
        if Weapon == "Hammer" then
            local MeUnderTurret = IsUnderEnemyTurret(myHero.pos)
            local TargetUnderTurret = IsUnderEnemyTurret(target.pos)
            if self:CanUse(_Q, Mode(), Weapon) and ValidTarget(target, 600) and not (myHero.pathing and myHero.pathing.isDashing) then
                if not TargetUnderTurret or MeUnderTurret then
                    Control.CastSpell(HK_Q, target)
                end
            end
            if self:CanUse(_W, Mode(), Weapon) and ValidTarget(target, 285) then
                Control.CastSpell(HK_W)
            end

            if self:CanUse(_E, Mode(), Weapon) and ValidTarget(target, 240) then
                local Edmg= getdmg("E", target, myHero, 1, myHero:GetSpellData(_E).level)
                if target.health < Edmg then
                    Control.CastSpell(HK_E, target)
                elseif (self:CanUse(_Q, Mode(), Weapon) or Q2CD < Game.Timer() or W2CD < Game.Timer()) and GetDistance(target.pos, myHero.pos) < 100 and self:CanUse(_R, Mode(), Weapon) then
                    Control.CastSpell(HK_E, target)
                elseif not self:CanUse(_Q, Mode(), Weapon) and not self:CanUse(_W, Mode(), Weapon) and self:CanUse(_R, Mode(), Weapon) then
                    Control.CastSpell(HK_E, target)
                end
            end
            if self:CanUse(_R, Mode(), Weapon) then
                if GetDistance(target.pos, myHero.pos) > 700 then
                    Control.CastSpell(HK_R)
                elseif GetDistance(target.pos, myHero.pos) > 285 and not self:CanUse(_Q, Mode(), Weapon) then
                    Control.CastSpell(HK_R)
                elseif GetDistance(target.pos, myHero.pos) > 240 and not self:CanUse(_W, Mode(), Weapon) and not self:CanUse(_Q, Mode(), Weapon) then
                    Control.CastSpell(HK_R)
                elseif GetDistance(target.pos, myHero.pos) > AARange and not self:CanUse(_E, Mode(), Weapon) and not self:CanUse(_W, Mode(), Weapon) and not self:CanUse(_Q, Mode(), Weapon) then
                    Control.CastSpell(HK_R)
                elseif W2CD < Game.Timer() and not self:CanUse(_E, Mode(), Weapon) and not self:CanUse(_W, Mode(), Weapon) and not self:CanUse(_Q, Mode(), Weapon) then
                    Control.CastSpell(HK_R)
                end
            end
        else
            --PrintChat("Gun")
            if self:CanUse(_Q, Mode(), Weapon) and ValidTarget(target, 1050) and not self:CanUse(_E, Mode(), Weapon) then
                self:UseQ(target)
            end

            if self:CanUse(_W, Mode(), Weapon) and ValidTarget(target, AARange+100) then
                if myHero.attackData.state == 3 then
                   --Control.CastSpell(HK_W)
                end
            end

            if self:CanUse(_E, Mode(), Weapon) and ValidTarget(target, 1470) and self:CanUse(_Q, Mode(), Weapon) then
                self:UseQ2(target)
            end
            local MeUnderTurret = IsUnderEnemyTurret(myHero.pos)
            local TargetUnderTurret = IsUnderEnemyTurret(target.pos)
            if self:CanUse(_R, Mode(), Weapon) and (not TargetUnderTurret or MeUnderTurret) then
                if GetDistance(target.pos, myHero.pos) < 125 then
                    if self:CanUse(_W, Mode(), Weapon) then
                        Control.CastSpell(HK_W)
                    end
                    Control.CastSpell(HK_R)
                elseif GetDistance(target.pos, myHero.pos) < 240 and (Q1CD < Game.Timer() or W1CD < Game.Timer() or E1CD < Game.Timer() or Wbuff) and myHero.mana > 80 then
                    if self:CanUse(_W, Mode(), Weapon) then
                        Control.CastSpell(HK_W)
                    end
                    Control.CastSpell(HK_R)
                elseif GetDistance(target.pos, myHero.pos) < 600 and Q1CD < Game.Timer() and (W1CD < Game.Timer() or E1CD < Game.Timer() or Wbuff) and not self:CanUse(_Q, Mode(), Weapon) and myHero.mana > 80 then
                    if self:CanUse(_W, Mode(), Weapon) then
                        Control.CastSpell(HK_W)
                    end
                    Control.CastSpell(HK_R)
                end
            end
        end
    else
        WasInRange = false
    end     
end

function Jayce:DelayEscapeClick(delay, pos)
    if Game.Timer() - LastCalledTime > delay then
        LastCalledTime = Game.Timer()
        Control.RightClick(pos:To2D())
    end
end

function Jayce:QECombo()
    local SmallDist = 1000
    local QETarget = nil
    for i, enemy in pairs(EnemyHeroes) do
        if enemy and not enemy.dead and ValidTarget(enemy) then
            local MouseDist = GetDistance(enemy.pos, mousePos)
            if MouseDist < SmallDist then
                QETarget = enemy
                PrintChat("Got QETarget")
            end
        end
    end
    if QETarget and  Weapon == "Gun" and IsReady(_Q) and ValidTarget(QETarget, 1470) and self.Menu.AimQE:Value() and false then
        self:UseQ2Man(QETarget)
    elseif IsReady(_Q) then
        local Espot = Vector(myHero.pos):Extended(mousePos, 100)
        DelayAction(function() Control.CastSpell(HK_Q, mousePos) end, 0.05)
        if IsReady(_E) then
            Control.CastSpell(HK_E, Espot)
        end
    end 
end

function Jayce:Insec(target)
    local SmallDist = 1000
    local InsecTarget = nil
    for i, enemy in pairs(EnemyHeroes) do
        if enemy and not enemy.dead and ValidTarget(enemy) then
            local MouseDist = GetDistance(enemy.pos, mousePos)
            if MouseDist < SmallDist then
                InsecTarget = enemy
            end
        end
    end
    if InsecTarget and ValidTarget(InsecTarget, 600) then
        if Weapon == "Hammer" then
            if IsReady(_Q) and IsReady(_E) and not (myHero.pathing and myHero.pathing.isDashing) then
                if StartSpot == nil then
                    StartSpot = myHero.pos
                end
                Control.CastSpell(HK_Q, InsecTarget)
            end
            if StartSpot ~= nil and not IsReady(_Q) and IsReady(_E) then
                local TargetFromStartDist = GetDistance(InsecTarget.pos, StartSpot)
                local Espot = Vector(StartSpot):Extended(InsecTarget.pos, TargetFromStartDist+200)
                self:DelayEscapeClick(0.10, Espot)
                if GetDistance(myHero.pos, Espot) < 100 then
                    Control.CastSpell(HK_E, InsecTarget)
                    StartSpot = nil
                end
            else
                self:DelayEscapeClick(0.10, mousePos)
            end
        else
            if Q1CD < Game.Timer() and E1CD < Game.Timer() then
                local TargetDist = GetDistance(InsecTarget.pos, myHero.pos)
                local Espot = Vector(myHero.pos):Extended(InsecTarget.pos, TargetDist-150)
                if IsReady(_E) then
                    Control.CastSpell(HK_E, Espot)
                end
                if IsReady(_R) then
                    Control.CastSpell(HK_R)
                end
            else
                self:DelayEscapeClick(0.10, mousePos)
            end
        end
    else
        self:DelayEscapeClick(0.10, mousePos)
    end
end


function Jayce:OnPostAttackTick(args)
    attackedfirst = 1
    if target then
        if Weapon == "Gun" then
            local AARange = _G.SDK.Data:GetAutoAttackRange(myHero)
            if self:CanUse(_W, Mode(), Weapon) and ValidTarget(target, AARange+100) then
                Control.CastSpell(HK_W)
            end
        end
    end
end


function Jayce:GetRDmg(unit)
    return getdmg("R", unit, myHero, stage, myHero:GetSpellData(_R).level)
end

function Jayce:OnPreAttack(args)
end

function Jayce:UseQ(unit)
        local pred = _G.PremiumPrediction:GetPrediction(myHero, unit, QSpellData)
        if pred.CastPos and _G.PremiumPrediction.HitChance.Medium(pred.HitChance) and myHero.pos:DistanceTo(pred.CastPos) < 1050 then
                Control.CastSpell(HK_Q, pred.CastPos)
        end 
end

function Jayce:UseQ2(unit)
        local pred = _G.PremiumPrediction:GetPrediction(myHero, unit, Q2SpellData)
        if pred.CastPos and _G.PremiumPrediction.HitChance.Medium(pred.HitChance) and myHero.pos:DistanceTo(pred.CastPos) < 1470 then
                local Espot = Vector(myHero.pos):Extended(pred.CastPos, 100)
                DelayAction(function() Control.CastSpell(HK_Q, pred.CastPos) end, 0.05)
                Control.CastSpell(HK_E, Espot)
        end 
end


function Jayce:UseQ2Man(unit)
        local pred = _G.PremiumPrediction:GetPrediction(myHero, unit, Q2SpellData)
        if pred.CastPos and _G.PremiumPrediction.HitChance.Medium(pred.HitChance) and myHero.pos:DistanceTo(pred.CastPos) < 1470 then
                local Espot = Vector(myHero.pos):Extended(pred.CastPos, 100)
                DelayAction(function() Control.CastSpell(HK_Q, pred.CastPos) end, 0.05)
                Control.CastSpell(HK_E, Espot)
        else
            local Espot = Vector(myHero.pos):Extended(mousePos, 100)
            DelayAction(function() Control.CastSpell(HK_Q, mousePos) end, 0.05)
            Control.CastSpell(HK_E, Espot)
        end 
end


function Jayce:UseE(unit)
        local pred = _G.PremiumPrediction:GetPrediction(myHero, unit, ESpellData)
        if pred.CastPos and _G.PremiumPrediction.HitChance.Low(pred.HitChance) and myHero.pos:DistanceTo(pred.CastPos) < 700 then
                Control.CastSpell(HK_E, pred.CastPos)
                LastESpot = pred.CastPos
        end 
end

function Jayce:UseR(unit)
        local pred = _G.PremiumPrediction:GetPrediction(myHero, unit, RSpellData)
        if pred.CastPos and _G.PremiumPrediction.HitChance.Medium(pred.HitChance) and myHero.pos:DistanceTo(pred.CastPos) < 1300  then
                Control.CastSpell(HK_R, pred.CastPos)
        end 
end

function OnLoad()
    Manager()
end