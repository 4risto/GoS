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
            Name = "dnsActivator.lua",
            Url = "https://raw.githubusercontent.com/fkndns/dnsActivator/main/dnsActivator.lua"
       },
        Version = {
            Path = SCRIPT_PATH,
            Name = "dnsActivator.version",
            Url = "https://raw.githubusercontent.com/fkndns/dnsActivator/main/dnsActivator.version"    -- check if Raw Adress correct pls.. after you have create the version file on Github
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

local Camps = {
    "SRU_Baron",
    "SRU_RiftHerald",
    "SRU_Dragon_Water",
    "SRU_Dragon_Fire",
    "SRU_Dragon_Earth",
    "SRU_Dragon_Air",
    "SRU_Dragon_Elder",
    "SRU_Blue",
    "SRU_Red",
    "SRU_Gromp",
    "SRU_Murkwolf",
    "SRU_Razorbeak",
    "SRU_Krug",
    "Sru_Crab",
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

function GetDistance(Pos1, Pos2)
    return math.sqrt(GetDistanceSqr(Pos1, Pos2))
end

function IsImmobile(unit)
    local MaxDuration = 0
    for i = 0, unit.buffCount do
        local buff = unit:GetBuff(i)
        if buff and buff.count > 0 then
            local BuffType = buff.type
            if BuffType == 5 or BuffType == 11 or BuffType == 21 or BuffType == 22 or BuffType == 24 or BuffType == 29 or buff.name == "recall" then
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
            if BuffType == 5 or BuffType == 8 or BuffType == 9 or BuffType == 11 or BuffType == 21 or BuffType == 22 or BuffType == 24 or BuffType == 31 then
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

function InBase(pos)
    for i = 1, Game.ObjectCount() do
        local object = Game.Object(i)

        if object.isAlly and object.type == Obj_AI_SpawnPoint and GetDistance(object.pos, pos) <= 1000 then
            --PrintChat("Base")
            return object
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

local function MMCast(pos, spell)
        local MMSpot = Vector(pos):ToMM()
        local MouseSpotBefore = mousePos
        Control.SetCursorPos(MMSpot.x, MMSpot.y)
        Control.KeyDown(spell); Control.KeyUp(spell)
        DelayAction(function() Control.SetCursorPos(MouseSpotBefore) end, 0.20)
end

class "Activator"
local EnemyLoaded = false
local AllyLoaded = false
local EnemiesIronSpike = spikecount
local EnemiesGoreDrinker = drinkercount
local EnemiesOmen = omencount
local AlliesAround = allycount
local Timer = Game.Timer()
local ComboTimer = 0

function Activator:__init()
	self:LoadMenu()
	self:ItemSpells()
	Callback.Add("Tick", function() self:Tick() end)
	Callback.Add("Draw", function() self:Draw() end)
end

local SmiteDamage = 0

function Activator:LoadMenu()
-- main menu
	self.Menu = MenuElement({type = MENU, id = "Activator", name = "dnsActivator"})
	self.Menu:MenuElement({id = "summs", name = "Summoner Spells", type = MENU})
	self.Menu:MenuElement({id = "defitems", name = "Defensive Items", type = MENU})
	self.Menu:MenuElement({id = "targitems", name = "Targeted Items", type = MENU})
	self.Menu:MenuElement({id = "pots", name = "Potions", type = MENU})
    self.Menu:MenuElement({id = "autolvl", name = "Auto Level Spells", type = MENU})
-- summs
	self.Menu.summs:MenuElement({id = "summheal", name = "Summoner Heal", type = MENU})
	self.Menu.summs:MenuElement({id = "summbarrier", name = "Summoner Barrier", type = MENU})
	self.Menu.summs:MenuElement({id = "summexhaust", name = "Summoner Exhaust", type = MENU})
--self.Menu.summs.MenuElement({id = "summsnowball", name = "Summoner Snowball", type = MENU})
--self.Menu.summs:MenuElement({id = "summclarity", name = "Summoner Clarity", type = MENU})
	self.Menu.summs:MenuElement({id = "summcleanse", name = "Summoner Cleanse", type = MENU})
	self.Menu.summs:MenuElement({id = "summignite", name = "Summoner Ignite", type = MENU})
	self.Menu.summs:MenuElement({id = "summsmite", name = "Summoner Smite", type = MENU})
-- defitems
	self.Menu.defitems:MenuElement({id = "itemqss", name = "QSS Items", type = MENU})
	self.Menu.defitems:MenuElement({id = "itemredemption", name = "Redemption", type = MENU})
	self.Menu.defitems:MenuElement({id = "itemmikaels", name = "Mikaels", type = MENU})
	self.Menu.defitems:MenuElement({id = "itemzhonyas", name = "Zhonyas / Stopwatch", type = MENU})
	self.Menu.defitems:MenuElement({id = "itemsolari", name = "Locket of the iron Solari", type = MENU})
-- targetitems
	self.Menu.targitems:MenuElement({id = "itemironspk", name = "Ironspike Whisp", type = MENU})
	self.Menu.targitems:MenuElement({id = "itemgoredrnk", name = "Goredrinker", type = MENU})
	self.Menu.targitems:MenuElement({id = "itemstidebreaker", name = "Stridebreaker", type = MENU})
	self.Menu.targitems:MenuElement({id = "itemshure", name = "Shurelya's Battlesong", type = MENU})
	self.Menu.targitems:MenuElement({id = "itemranduin", name = "Randuin's Omen", type = MENU})
	self.Menu.targitems:MenuElement({id = "itemchempunk", name = "Turbo Chempunk", type = MENU})
	self.Menu.targitems:MenuElement({id = "itemyoumuu", name = "Youmuu's Ghostblade", type = MENU})
	self.Menu.targitems:MenuElement({id = "itemrocket", name = "Hextech Rocketbelt", type = MENU})
	self.Menu.targitems:MenuElement({id = "itemprowler", name = "Prowler's Claw", type = MENU})
	self.Menu.targitems:MenuElement({id = "itemevfrost", name = "Everfrost", type = MENU})
	self.Menu.targitems:MenuElement({id = "itemgale", name = "Galeforce", type = MENU})
-- pots
	self.Menu.pots:MenuElement({id = "itemhppot", name = "Use Health Potion", value = true})
	self.Menu.pots:MenuElement({id = "itemhppothp", name = "If HP lower then", value = 70, min = 5, max = 95, step = 5, identifier = "%"})
	self.Menu.pots:MenuElement({id = "itemrefpot", name = "Use Refillable Potion", value = true})
	self.Menu.pots:MenuElement({id = "itemrefpothp", name = "If HP lower then", value = 70, min = 5, max = 95, step = 5, identifier = "%" })
	self.Menu.pots:MenuElement({id = "itemcookie", name = "Use Cookies", value = true})
	self.Menu.pots:MenuElement({id = "itemcookiemana", name = "If Mana lower then", value = 25, min = 5, max = 95, step = 5, identifier = "%"})
	self.Menu.pots:MenuElement({id = "itemcorpot", name = "Use Corrupting Potion", value = true})
	self.Menu.pots:MenuElement({id = "itemcorpothp", name = "If HP lower then", value = 70, min = 5, max = 95, step = 5, identifier = "%"})
-- heal
	self.Menu.summs.summheal:MenuElement({id = "summhealuse", name = "Use Heal", value = true})
	self.Menu.summs.summheal:MenuElement({id = "summhealusehp", name = "If my HP lower then", value = 30, min = 5, max = 95, step = 5, identifier = "%" })
	self.Menu.summs.summheal:MenuElement({id = "summhealmate", name = "Use Heal on allies", value = true})
	self.Menu.summs.summheal:MenuElement({id = "summhealmatehp", name = "If their HP lower then", value = 25, min = 5, max = 95, step = 5, identifier = "%"})
	self.Menu.summs.summheal:MenuElement({id = "alliestoheal", name = "Allies to heal", type = MENU})
-- barrier
	self.Menu.summs.summbarrier:MenuElement({id = "summbarrieruse", name = "Use Barrier", value = true})
	self.Menu.summs.summbarrier:MenuElement({id = "summbarrierusehp", name = "If HP lower then", value = 30, min = 5, max = 95, step = 5, identifier = "%"})
-- exhaust
	self.Menu.summs.summexhaust:MenuElement({id = "summexhaustuse", name = "Use Exhaust", value = true})
	self.Menu.summs.summexhaust:MenuElement({id = "summexhaustusehp", name = "If my HP lower then", value = 30, min = 5, max = 95, step = 5, identifier = "%"})
    self.Menu.summs.summexhaust:MenuElement({id = "summexhaustmate", name = "Use Exhaust for ally", true})
    self.Menu.summs.summexhaust:MenuElement({id = "summexhaustmatehp", name = "If ally HP lower then", value = 30, min = 5, max = 95, step = 5, identifier = "%"})
	self.Menu.summs.summexhaust:MenuElement({id = "enemiestohit", name = "Enemies to use on", type = MENU})
-- cleanse
	self.Menu.summs.summcleanse:MenuElement({id = "summcleanseuse", name = "Use Cleanse", value = true})
	self.Menu.summs.summcleanse:MenuElement({id = "summcleanserange", name = "If enemy is closer then", value = 800, min = 200, max = 1500, step = 100})
-- smite
	self.Menu.summs.summsmite:MenuElement({id = "summsmitered", name = "Use RedSmite", value = true})
	self.Menu.summs.summsmite:MenuElement({id = "summsmiteredhp", name = "Use RedSmite if enemy lower then", value = 30, min = 5, max = 95, step = 5, identifier = "%"})
	self.Menu.summs.summsmite:MenuElement({id = "summredenemies", name = "Enemies to use on", type = MENU})
	self.Menu.summs.summsmite:MenuElement({id = "summsmiteblue", name = "Use BlueSmite", value = true})
	self.Menu.summs.summsmite:MenuElement({id = "summsmitebluehp", name = "Use BlueSmite if enemy lower then", value = 30, min = 5, max = 95, step = 5, identifier = "%"})
	self.Menu.summs.summsmite:MenuElement({id = "summblueenemies", name = "Enemies to use on", type = MENU})
	self.Menu.summs.summsmite:MenuElement({id = "smitespace", name = "Only Smites enemy if 2 SmiteStacks", type = SPACE})
    self.Menu.summs.summsmite:MenuElement({id = "smitecamps", name = "Smite Monsters", type = MENU})
--campsmite
    self.Menu.summs.summsmite.smitecamps:MenuElement({id = "smitedrake", name = "Use [Smite] on Drakes", value = true})
    self.Menu.summs.summsmite.smitecamps:MenuElement({id = "smiteherald", name = "Use [Smite] on Herald", value = true})
    self.Menu.summs.summsmite.smitecamps:MenuElement({id = "smitebaron", name = "Use [Smite] on Baron", value = true})
    self.Menu.summs.summsmite.smitecamps:MenuElement({id = "smiteredblue", name = "[Smite] Red/Blue if Contested", value = true})
    self.Menu.summs.summsmite.smitecamps:MenuElement({id = "smitecrab", name = "[Smite] Crab if Contested", value = true})
    self.Menu.summs.summsmite.smitecamps:MenuElement({id = "smitelow", name = "[Smite] Camp for Health in Fight", value = true})
    self.Menu.summs.summsmite.smitecamps:MenuElement({id = "smitelowhp", name = "[Smite] Camp HP", value = 30, min = 5, max = 95, step = 5, identifier = "%"})
-- ignite 
	self.Menu.summs.summignite:MenuElement({id = "summigniteuse", name = "Use Ignite", value = true})
	self.Menu.summs.summignite:MenuElement({id = "enemiestohit", name = "Enemies to use on", type = MENU})
-- qss
	self.Menu.defitems.itemqss:MenuElement({id = "itemqssuse", name = "Use QSS Items", value = true})
	self.Menu.defitems.itemqss:MenuElement({id = "itemqssuserange", name = "If enemy is closer then", value = 800, min = 200, max = 1500, step = 100})
--redemption
	self.Menu.defitems.itemredemption:MenuElement({id = "itemredemptionuse", name = "Use Redemption", value = true})
	self.Menu.defitems.itemredemption:MenuElement({id = "itemredemptionusehp", name = "If my HP lower then", value = 30, min = 5, max = 95, step = 5, identifier = "%"})
	self.Menu.defitems.itemredemption:MenuElement({id = "itemredemptionmate", name = "Use Redemption on aliies", value = true})
	self.Menu.defitems.itemredemption:MenuElement({id = "itemredemptionmatehp", name = "If their HP lower then", value = 25, min = 5, max = 95, step = 5, identifier = "%"})
	self.Menu.defitems.itemredemption:MenuElement({id = "alliestoheal", name = "Allies to use on", type = MENU})
-- mikaels
	self.Menu.defitems.itemmikaels:MenuElement({id = "itemmikaelsuse", name = "Use Mikaels", value = false})
	self.Menu.defitems.itemmikaels:MenuElement({id = "itemmikaelsusehp", name = "If my HP lower then", value = 15, min = 5, max = 95, step = 5, identifier = "%"})
	self.Menu.defitems.itemmikaels:MenuElement({id = "itemmikaelsmate", name = "Use Mikaels on allies", value = true})
	self.Menu.defitems.itemmikaels:MenuElement({id = "itemmikaelsmaterange", name = "If enemys is closer then", value = 800, min = 200, max = 1500, step = 100})
	self.Menu.defitems.itemmikaels:MenuElement({id = "alliestoheal", name = "Allies to use on", type = MENU})
-- locket of the irons solari
	self.Menu.defitems.itemsolari:MenuElement({id = "itemsolariuse", name = "Use Locket of the iron Solari", value = true})
	self.Menu.defitems.itemsolari:MenuElement({id = "itemsolariusehp", name = "If my HP lower then", value = 30, min = 5, max = 95, step = 5, identifier = "%"})
	self.Menu.defitems.itemsolari:MenuElement({id = "itemsolarimate", name = "Use Locket on allies", value = true})
	self.Menu.defitems.itemsolari:MenuElement({id = "itemsolarimatehp", name = "If their HP lower then", value = 25, min = 5, max = 95, step = 5, identifier = "%"})
	self.Menu.defitems.itemsolari:MenuElement({id = "alliestoheal", name = "Allies to use on", type = MENU})
-- zhonyas and stopwatch
	self.Menu.defitems.itemzhonyas:MenuElement({id = "itemzhonyasuse", name = "Use Zhonyas", value = true})
	self.Menu.defitems.itemzhonyas:MenuElement({id = "itemzhonyasusehp", name = "If my HP lower then", value = 30, min = 5, max = 95, step = 5, identifier = "%"})
	self.Menu.defitems.itemzhonyas:MenuElement({id = "itemstopwatchuse", name = "Use Stopwatch", value = true})
	self.Menu.defitems.itemzhonyas:MenuElement({id = "itemstopwatchusehp", name = "If my HP lower then", value = 30, min = 5, max = 95, step = 5, identifier = "%"})
-- ironspike whisp
	self.Menu.targitems.itemironspk:MenuElement({id = "itemironspkuse", name = "Use Ironspike Whisp", value = true})
	self.Menu.targitems.itemironspk:MenuElement({id = "itemironspkusetar", name = "If more enemies then", value = 2, min = 0, max = 5, step = 1})
    self.Menu.targitems.itemironspk:MenuElement({id = "itemironspkcombo", name = "Use only in Combo Mode", value = true})
	self.Menu.targitems.itemironspk:MenuElement({id = "enemiestohit", name = "Enemies to use on", type = MENU})
-- goredrinker
	self.Menu.targitems.itemgoredrnk:MenuElement({id = "itemgoredrnkuse", name = "Use Goredrinker", value = true})
	self.Menu.targitems.itemgoredrnk:MenuElement({id = "itemgoredrnkusetar", name = "If more enemies then", value = 2, min = 1, max = 5, step = 1})
	self.Menu.targitems.itemgoredrnk:MenuElement({id = "itemgoredrnkusehp", name = "If HP lower then", value = 40, min = 5, max = 95, step = 5, identifier = "%"})
    self.Menu.targitems.itemgoredrnk:MenuElement({id = "itemgoredrnkcombo", name = "Use only in Combo Mode", value = true})
	self.Menu.targitems.itemgoredrnk:MenuElement({id = "enemiestohit", name = "Enemies to use on", type = MENU})
	self.Menu.targitems.itemgoredrnk:MenuElement({id = "gorespace", name = "Enemies to hit and HP are seperate things", type = SPACE})
-- stridebreaker
	self.Menu.targitems.itemstidebreaker:MenuElement({id = "itemstidebreakeruse", name = "Use Stridebreaker", value = true})
    self.Menu.targitems.itemstidebreaker:MenuElement({id = "itemstidebreakercombo", name = "Use only in Combo Mode", value = true})
	self.Menu.targitems.itemstidebreaker:MenuElement({id = "enemiestohit", name = "Enemies to use on", type = MENU})
-- shurelyas
	self.Menu.targitems.itemshure:MenuElement({id = "itemshureuse", name = "Use Shurelya's Battlesong", value = true})
	self.Menu.targitems.itemshure:MenuElement({id = "itemshurerange", name = "If enemy closer then", value = 900, min = 100, max = 1500, step = 100})
	self.Menu.targitems.itemshure:MenuElement({id = "itemshureally", name = "If more allies then", value = 1, min = 0, max = 5, step = 1})
    self.Menu.targitems.itemshure:MenuElement({id = "itemshurecombo", name = "Use only in Combo Mode", value = true})
	self.Menu.targitems.itemshure:MenuElement({id = "enemiestohit", name = "Enemies to use on", type = MENU})
-- randuins
	self.Menu.targitems.itemranduin:MenuElement({id = "itemranduinuse", name = "Use Randuin's Omen", value = true})
	self.Menu.targitems.itemranduin:MenuElement({id = "itemranduintar", name = "If more enemies then", value = 2, min = 0, max = 5, step = 1})
    self.Menu.targitems.itemranduin:MenuElement({id = "itemranduincombo", name = "Use only in Combo Mode", value = true})
	self.Menu.targitems.itemranduin:MenuElement({id = "enemiestohit", name = "Enemies to use on", type = MENU})
-- chempunk
	self.Menu.targitems.itemchempunk:MenuElement({id = "itemchempunkuse", name = "Use Turbo Chempunk", value = true})
	self.Menu.targitems.itemchempunk:MenuElement({id = "itemchempunkrange", name = "If enemy closer then", value = 700, min = 200, max = 1500, step = 100})
    self.Menu.targitems.itemchempunk:MenuElement({id = "itemchempunkcombo", name = "Use only in Combo Mode", value = true})
	self.Menu.targitems.itemchempunk:MenuElement({id = "enemiestohit", name = "Enemies to use on", type = true})
-- youmuu
	self.Menu.targitems.itemyoumuu:MenuElement({id = "itemyoumuuuse", name = "Use Youmuu's Ghostblade", value = true})
	self.Menu.targitems.itemyoumuu:MenuElement({id = "itemyoumuuuserange", name = "If enemy closer then", value = 700, min = 200, max = 1500, step = 100})
    self.Menu.targitems.itemyoumuu:MenuElement({id = "itemyoumuusecombo", name = "Use only in Combo Mode", value = true})
    self.Menu.targitems.itemyoumuu:MenuElement({id = "enemiestohit", name = "Enemies to use on", type = MENU})
-- rocketbelt
	self.Menu.targitems.itemrocket:MenuElement({id = "itemrocketuse", name = "Use Hextech Rocketbelt", value = true})
	self.Menu.targitems.itemrocket:MenuElement({id = "itemrocketuserange", name = "If enemy closer then", value = 700, min = 200, max = 1500, step = 100})
    self.Menu.targitems.itemrocket:MenuElement({id = "itemrocketcombo", name = "Use only in Combo Mode", value = true})
	self.Menu.targitems.itemrocket:MenuElement({id = "enemiestohit", name = "Enemies to use on", type = MENU})
-- prowlers claw
	self.Menu.targitems.itemprowler:MenuElement({id = "itemprowleruse", name = "Use Prowler's Claw", value = true})
    self.Menu.targitems.itemprowler:MenuElement({id = "itemprowlercombo", name = "Use only in Combo Mode", value = true})
	self.Menu.targitems.itemprowler:MenuElement({id = "enemiestohit", name = "Enemies to use on", type = MENU})
-- everfrost
	self.Menu.targitems.itemevfrost:MenuElement({id = "itemevfrostuse", name = "Use Everfrost", value = true})
    self.Menu.targitems.itemevfrost:MenuElement({id = "itemevfrostcombo", name = "Use only in Combo Mode", value = true})
	self.Menu.targitems.itemevfrost:MenuElement({id = "enemiestohit", name = "Enemies to use on", type = MENU})
-- galeforce
	self.Menu.targitems.itemgale:MenuElement({id = "itemgaleuse", name = "Use Galeforce", value = true})
	self.Menu.targitems.itemgale:MenuElement({id = "itemgaleusehp", name = "If enemy lower then", value = 30, min = 5, max = 95, step = 5, identifier = "%"})
    self.Menu.targitems.itemgale:MenuElement({id = "itemgalecombo", name = "Use only in Combo Mode", value = true})
	self.Menu.targitems.itemgale:MenuElement({id = "enemiestohit", name = "Enemies to use on", type = MENU})
-- auto level
    self.Menu.autolvl:MenuElement({id = "autolvluse", name = "Enable Auto Level Spells", value = true})
    self.Menu.autolvl:MenuElement({id = "autolvlorder", name = "Levelorder", value = 2, drop = {"[Q]->[W]->[E]", "[Q]->[E]->[W]", "[W]->[Q]->[E]", "[W]->[E]->[Q]", "[E]->[Q]->[W]", "[E]->[W]->[Q]"}})
    self.Menu.autolvl:MenuElement({id = "autolvllvl", name = "Start AutoLevel at [lvl]", value = 2, min = 2, max = 18})
end

function Activator:AllyMenu()
	for i, ally in pairs(AllyHeroes) do
		self.Menu.summs.summheal.alliestoheal:MenuElement({id = ally.charName, name = ally.charName, value = true})
		self.Menu.defitems.itemredemption.alliestoheal:MenuElement({id = ally.charName, name = ally.charName, value = true})
		self.Menu.defitems.itemmikaels.alliestoheal:MenuElement({id = ally.charName, name = ally.charName, value = true})
		self.Menu.defitems.itemsolari.alliestoheal:MenuElement({id = ally.charName, name = ally.charName, value = true})
	end
end

function Activator:EnemyMenu()
	for i, enemy in pairs(EnemyHeroes) do
		self.Menu.summs.summexhaust.enemiestohit:MenuElement({id = enemy.charName, name = enemy.charName, value = true})
		self.Menu.summs.summignite.enemiestohit:MenuElement({id = enemy.charName, name = enemy.charName, value = true})
		self.Menu.targitems.itemironspk.enemiestohit:MenuElement({id = enemy.charName, name = enemy.charName, value = true})
		self.Menu.targitems.itemgoredrnk.enemiestohit:MenuElement({id = enemy.charName, name = enemy.charName, value = true})
		self.Menu.targitems.itemstidebreaker.enemiestohit:MenuElement({id = enemy.charName, name = enemy.charName, value = true})
		self.Menu.targitems.itemshure.enemiestohit:MenuElement({id = enemy.charName, name = enemy.charName, value = true})
		self.Menu.targitems.itemranduin.enemiestohit:MenuElement({id = enemy.charName, name = enemy.charName, value = true})
		self.Menu.targitems.itemchempunk.enemiestohit:MenuElement({id = enemy.charName, name = enemy.charName, value = true})
		self.Menu.targitems.itemyoumuu.enemiestohit:MenuElement({id = enemy.charName, name = enemy.charName, value = true})
		self.Menu.targitems.itemrocket.enemiestohit:MenuElement({id = enemy.charName, name = enemy.charName, value = true})
		self.Menu.targitems.itemprowler.enemiestohit:MenuElement({id = enemy.charName, name = enemy.charName, value = true})
		self.Menu.targitems.itemevfrost.enemiestohit:MenuElement({id = enemy.charName, name = enemy.charName, value = true})
		self.Menu.targitems.itemgale.enemiestohit:MenuElement({id = enemy.charName, name = enemy.charName, value = true})
		self.Menu.summs.summsmite.summredenemies:MenuElement({id = enemy.charName, name = enemy.charName, value = true})
		self.Menu.summs.summsmite.summblueenemies:MenuElement({id = enemy.charName, name = enemy.charName, value = true})
	end
end
function Activator:Tick()
	if _G.JustEvade and _G.JustEvade:Evading() or (_G.ExtLibEvade and _G.ExtLibEvade.Evading) or Game.IsChatOpen() or myHero.dead then return end
	self:Loop()
	self:Pots()
    self:Autolvl()
	CastingQ = myHero.activeSpell.name == myHero:GetSpellData(_Q).name
	CastingW = myHero.activeSpell.name == myHero:GetSpellData(_W).name
	CastingE = myHero.activeSpell.name == myHero:GetSpellData(_E).name
	CastingR = myHero.activeSpell.name == myHero:GetSpellData(_R).name
    if Mode() == "Combo" then
        ComboTimer = Game.Timer() - Timer
    else
        ComboTimer = 0
        Timer = Game.Timer()
    end
	if EnemyLoaded == false then
        local CountEnemy = 0
        for i, enemy in pairs(EnemyHeroes) do
            CountEnemy = CountEnemy + 1
        end
        if CountEnemy < 1 then
            GetEnemyHeroes()
        else
			self:EnemyMenu()
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
			self:AllyMenu()
			AllyLoaded = true
			PrintChat("Ally Loaded") 
		end
	end
end

function Activator:CastingChecks()
	if not CastingQ or CastingW or CastingE or CastingR then
		return true
	else
		return false
	end
end

function Activator:SmoothChecks()
    if self:CastingChecks() and myHero.attackData.state ~= 2 and _G.SDK.Cursor.Step == 0 and (ComboTimer == 0 or ComboTimer > 0.1) then
        return true
    else
        return false
    end
end
	
function Activator:Loop()
	local spikecount = 0 
	local drinkercount = 0
	local omencount = 0
	local allycount = 0

		-- enemy loop
		for i, enemy in pairs(EnemyHeroes) do
        --campsmite
        self:Monsters(enemy)
		-- spike count
			if ValidTarget(enemy, 350 + myHero.boundingRadius + enemy.boundingRadius) and self.Menu.targitems.itemironspk.enemiestohit[enemy.charName] and self.Menu.targitems.itemironspk.enemiestohit[enemy.charName]:Value() then
				spikecount = spikecount + 1
			end
		-- goredrinker count
			if ValidTarget(enemy, 350 + myHero.boundingRadius + enemy.boundingRadius) and self.Menu.targitems.itemgoredrnk.enemiestohit[enemy.charName] and self.Menu.targitems.itemgoredrnk.enemiestohit[enemy.charName]:Value() then
				drinkercount = drinkercount + 1
			end
		-- randuins count
			if ValidTarget(enemy, 350 + myHero.boundingRadius + enemy.boundingRadius) and self.Menu.targitems.itemranduin.enemiestohit[enemy.charName] and self.Menu.targitems.itemranduin.enemiestohit[enemy.charName]:Value() then
				omencount = omencount + 1
			end
		-- heal self
			if self.Menu.summs.summheal.summhealuse:Value() and myHero.health / myHero.maxHealth <= self.Menu.summs.summheal.summhealusehp:Value() / 100 and enemy.activeSpell.valid and not enemy.activeSpell.isStopped then
                if enemy.activeSpell.target == myHero.handle then
				    self:UseHeal()
                else
                    local placementPos = enemy.activeSpell.placementPos
                    local width = myHero.boundingRadius + 50
                    if enemy.activeSpell.width > 0 then width = width + enemy.activeSpell.width end
                    local spellLine = ClosestPointOnLineSegment(myHero.pos, enemy.pos, placementPos)
                    if GetDistance(myHero.pos, spellLine) <= width then
                        self:UseHeal()
                    end
                end
			end
        -- exhaust self
            if self.Menu.summs.summexhaust.summexhaustuse:Value() and ValidTarget(enemy, 535 + myHero.boundingRadius) and myHero.health / myHero.maxHealth <= self.Menu.summs.summexhaust.summexhaustusehp:Value() / 100 and enemy.activeSpell.valid and not enemy.activeSpell.isStopped and self.Menu.summs.summexhaust.enemiestohit[enemy.charName]:Value() and self:SmoothChecks() then
                if enemy.activeSpell.target == myHero.handle then
                    self:UseExhaust(enemy)
                else
                    local placementPos = enemy.activeSpell.placementPos
                    local width = myHero.boundingRadius + 50
                    if enemy.activeSpell.width > 0 then width = width + enemy.activeSpell.width end
                    local spellLine = ClosestPointOnLineSegment(myHero.pos, enemy.pos, placementPos)
                    if GetDistance(myHero.pos, spellLine) <= width then
                        self:UseExhaust(enemy)
                    end
                end
            end
		-- barrier
			if self.Menu.summs.summbarrier.summbarrieruse:Value() and myHero.health / myHero.maxHealth <= self.Menu.summs.summbarrier.summbarrierusehp:Value() / 100 and enemy.activeSpell.valid and not enemy.activeSpell.isStopped then
				if enemy.activeSpell.target == myHero.handle then
                    self:UseBarrier()
                else
                    local placementPos = enemy.activeSpell.placementPos
                    local width = myHero.boundingRadius + 50
                    if enemy.activeSpell.width > 0 then width = width + enemy.activeSpell.width end
                    local spellLine = ClosestPointOnLineSegment(myHero.pos, enemy.pos, placementPos)
                    if GetDistance(myHero.pos, spellLine) <= width then
                        self:UseBarrier()
                    end
                end
			end
		-- cleanse
			if self.Menu.summs.summcleanse.summcleanseuse:Value() and IsCleanse(myHero) >= 0.5 and ValidTarget(enemy, self.Menu.summs.summcleanse.summcleanserange:Value() + myHero.boundingRadius + enemy.boundingRadius) then
				self:UseCleanse()
			end
		-- ignite
			local IgnDmg = 50 + 20 * myHero.levelData.lvl
			if ValidTarget(enemy, 535 + myHero.boundingRadius) and self.Menu.summs.summignite.summigniteuse:Value() and enemy.health <= IgnDmg and self.Menu.summs.summignite.enemiestohit[enemy.charName] and self.Menu.summs.summignite.enemiestohit[enemy.charName]:Value() and self:SmoothChecks() then
				self:UseIgnite(enemy)
			end
		-- redsmite
			if enemy and ValidTarget(enemy, 500 + myHero.boundingRadius + enemy.boundingRadius) and self.Menu.summs.summsmite.summsmitered:Value() and enemy.health / enemy.maxHealth <= self.Menu.summs.summsmite.summsmiteredhp:Value() / 100 and self.Menu.summs.summsmite.summredenemies[enemy.charName] and self.Menu.summs.summsmite.summredenemies[enemy.charName]:Value() and self:SmoothChecks() then
				self:UseRedSmite(enemy)
			end
		-- bluesmite
			if enemy and ValidTarget(enemy, 500 + myHero.boundingRadius + enemy.boundingRadius) and self.Menu.summs.summsmite.summsmiteblue:Value() and enemy.health / enemy.maxHealth <= self.Menu.summs.summsmite.summsmitebluehp:Value() / 100 and self.Menu.summs.summsmite.summblueenemies[enemy.charName] and self.Menu.summs.summsmite.summblueenemies[enemy.charName]:Value() and self:SmoothChecks() then
				self:UseBlueSmite(enemy)
			end
		-- QSS
			if self.Menu.defitems.itemqss.itemqssuse:Value() and ValidTarget(enemy, self.Menu.defitems.itemqss.itemqssuserange:Value() + myHero.boundingRadius + enemy.boundingRadius) and IsCleanse(myHero) >= 0.5 then
				if GetItemSlot(myHero, 3140) > 0 then
					self:UseQSS()
				elseif GetItemSlot(myHero, 3139) > 0 then
					self:UseMerc()
				elseif GetItemSlot(myHero, 6035) > 0 then
					self:UseDawn()
				end
			end
		-- redemption self
			if self.Menu.defitems.itemredemption.itemredemptionuse:Value() and myHero.health / myHero.maxHealth <= self.Menu.defitems.itemredemption.itemredemptionusehp:Value() / 100 and enemy.activeSpell.valid and not enemy.activeSpell.isStopped and self:SmoothChecks() then
                if enemy.activeSpell.target == myHero.handle then
                    self:UseRedemption(myHero)
                else
                    local placementPos = enemy.activeSpell.placementPos
                    local width = myHero.boundingRadius + 50
                    if enemy.activeSpell.width > 0 then width = width + enemy.activeSpell.width end
                    local spellLine = ClosestPointOnLineSegment(myHero.pos, enemy.pos, placementPos)
                    if GetDistance(myHero.pos, spellLine) <= width then
                        self:UseRedemption(myHero)
                    end
                end
			end
		-- mikaels self
			if self.Menu.defitems.itemmikaels.itemmikaelsuse:Value() and (myHero.health / myHero.maxHealth <= self.Menu.defitems.itemmikaels.itemmikaelsusehp:Value() / 100 or IsCleanse(myHero) > 0.5)  and enemy.activeSpell.valid and not enemy.activeSpell.isStopped and self:SmoothChecks() then
                if enemy.activeSpell.target == myHero.handle then
                    self:UseMikaels(myHero)
                else
                    local placementPos = enemy.activeSpell.placementPos
                    local width = myHero.boundingRadius + 50
                    if enemy.activeSpell.width > 0 then width = width + enemy.activeSpell.width end
                    local spellLine = ClosestPointOnLineSegment(myHero.pos, enemy.pos, placementPos)
                    if GetDistance(myHero.pos, spellLine) <= width then
                        self:UseMikaels(myHero)
                    end
                end
			end
		-- stopwatch
			if self.Menu.defitems.itemzhonyas.itemstopwatchuse:Value() and myHero.health / myHero.maxHealth <= self.Menu.defitems.itemzhonyas.itemstopwatchusehp:Value() / 100 and enemy.activeSpell.valid and not enemy.activeSpell.isStopped then
				if enemy.activeSpell.target == myHero.handle then
                    self:UseStpWth()
                else
                    local placementPos = enemy.activeSpell.placementPos
                    local width = myHero.boundingRadius + 50
                    if enemy.activeSpell.width > 0 then width = width + enemy.activeSpell.width end
                    local spellLine = ClosestPointOnLineSegment(myHero.pos, enemy.pos, placementPos)
                    if GetDistance(myHero.pos, spellLine) <= width then
                        self:UseStpWth()
                    end
                end
			end
		-- zhonyas 
			if self.Menu.defitems.itemzhonyas.itemzhonyasuse:Value() and myHero.health / myHero.maxHealth <= self.Menu.defitems.itemzhonyas.itemzhonyasusehp:Value() / 100 and enemy.activeSpell.valid and not enemy.activeSpell.isStopped then
				if enemy.activeSpell.target == myHero.handle then
                    self:UseZhonyas()
                else
                    local placementPos = enemy.activeSpell.placementPos
                    local width = myHero.boundingRadius + 50
                    if enemy.activeSpell.width > 0 then width = width + enemy.activeSpell.width end
                    local spellLine = ClosestPointOnLineSegment(myHero.pos, enemy.pos, placementPos)
                    if GetDistance(myHero.pos, spellLine) <= width then
                        self:UseZhonyas()
                    end
                end
			end
		-- locket self
			if self.Menu.defitems.itemsolari.itemsolariuse:Value() and myHero.health / myHero.maxHealth <= self.Menu.defitems.itemsolari.itemsolariusehp:Value() / 100 and enemy.activeSpell.valid and not enemy.activeSpell.isStopped and not _G.SDK.Attack:IsActive() then
				if enemy.activeSpell.target == myHero.handle then
                    self:UseLocket()
                else
                    local placementPos = enemy.activeSpell.placementPos
                    local width = myHero.boundingRadius + 50
                    if enemy.activeSpell.width > 0 then width = width + enemy.activeSpell.width end
                    local spellLine = ClosestPointOnLineSegment(myHero.pos, enemy.pos, placementPos)
                    if GetDistance(myHero.pos, spellLine) <= width then
                        self:UseLocket()
                    end
                end
			end
		-- ironspike
			if self.Menu.targitems.itemironspk.itemironspkuse:Value() and EnemiesIronSpike == self.Menu.targitems.itemironspk.itemironspkusetar:Value() and myHero.attackData.state ~= 2 and self:CastingChecks() then
				self:UseIronSpk()
			end
		-- goredrinker
			if self.Menu.targitems.itemgoredrnk.itemgoredrnkuse:Value() and EnemiesGoreDrinker == self.Menu.targitems.itemgoredrnk.itemgoredrnkusetar:Value() and not _G.SDK.Attack:IsActive() then
				self:UseGoreDrinker()
			elseif self.Menu.targitems.itemgoredrnk.itemgoredrnkuse:Value() and myHero.health / myHero.maxHealth <= self.Menu.targitems.itemgoredrnk.itemgoredrnkusehp:Value() / 100 and ValidTarget(enemy, 350 + myHero.boundingRadius + enemy.boundingRadius) and not _G.SDK.Attack:IsActive() then
				self:UseGoreDrinker()
			end
		-- stridebreaker 
			if self.Menu.targitems.itemstidebreaker.itemstidebreakeruse:Value() and ValidTarget(enemy, 525 + myHero.boundingRadius + enemy.boundingRadius) and self.Menu.targitems.itemstidebreaker.enemiestohit[enemy.charName] and self.Menu.targitems.itemstidebreaker.enemiestohit[enemy.charName]:Value() and self:SmoothChecks() then
				self:UseStrideBreaker(enemy)
			end
		-- omen
			if self.Menu.targitems.itemranduin.itemranduinuse:Value() and EnemiesOmen == self.Menu.targitems.itemranduin.itemranduintar:Value() and not _G.SDK.Attack:IsActive() then
				self:UseOmen()
			end
		-- chempunk
			if self.Menu.targitems.itemchempunk.itemchempunkuse:Value() and IsMyHeroFacing(enemy) and ValidTarget(enemy, self.Menu.targitems.itemchempunk.itemchempunkrange:Value() + myHero.boundingRadius + enemy.boundingRadius) and self.Menu.targitems.itemchempunk.enemiestohit[enemy.charName] and self.Menu.targitems.itemchempunk.enemiestohit[enemy.charName]:Value() and not _G.SDK.Attack:IsActive() then
				self:UseChempunk()
			end
		-- youmuu 
			if self.Menu.targitems.itemyoumuu.itemyoumuuuse:Value() and ValidTarget(enemy, self.Menu.targitems.itemyoumuu.itemyoumuuuserange:Value() + myHero.boundingRadius + enemy.boundingRadius) and self.Menu.targitems.itemyoumuu.enemiestohit[enemy.charName] and self.Menu.targitems.itemyoumuu.enemiestohit[enemy.charName]:Value() and not _G.SDK.Attack:IsActive() then
				self:UseYoumuus()
			end
		-- prowlers
			if self.Menu.targitems.itemprowler.itemprowleruse:Value() and ValidTarget(enemy, 450 + myHero.boundingRadius + enemy.boundingRadius) and self.Menu.targitems.itemprowler.enemiestohit[enemy.charName] and self.Menu.targitems.itemprowler.enemiestohit[enemy.charName]:Value() and self:SmoothChecks() then
				self:UseClaw(enemy)
			end
		-- rocketbelt
			if self.Menu.targitems.itemrocket.itemrocketuse:Value() and ValidTarget(enemy, self.Menu.targitems.itemrocket.itemrocketuserange:Value() + myHero.boundingRadius + enemy.boundingRadius) and self.Menu.targitems.itemrocket.enemiestohit[enemy.charName] and self.Menu.targitems.itemrocket.enemiestohit[enemy.charName]:Value() and self:SmoothChecks() then
				self:UseRocketBelt(enemy)
			end
		-- frost
			if self.Menu.targitems.itemevfrost.itemevfrostuse:Value() and ValidTarget(enemy, 800 + myHero.boundingRadius + enemy.boundingRadius) and self.Menu.targitems.itemevfrost.enemiestohit[enemy.charName] and self.Menu.targitems.itemevfrost.enemiestohit[enemy.charName]:Value() and self:SmoothChecks() then
				self:UseFrost(enemy)
			end
		-- galeforce
			if self.Menu.targitems.itemgale.itemgaleuse:Value() and ValidTarget(enemy, 700 + myHero.boundingRadius + enemy.boundingRadius) and enemy.health / enemy.maxHealth <= self.Menu.targitems.itemgale.itemgaleusehp:Value() / 100 and self.Menu.targitems.itemgale.enemiestohit[enemy.charName] and self.Menu.targitems.itemgale.enemiestohit[enemy.charName]:Value() and self:SmoothChecks() then
				GalePos = self:GaleLeftRight(enemy)
				if GalePos ~= nil then
					self:UseGale(GalePos)
				end
			end
		-- allycount reset
			allycount = 0
			-- ally loop
			for j, ally in pairs(AllyHeroes) do 
			-- ally count
				if ValidTarget(ally, 850 + myHero.boundingRadius + ally.boundingRadius) then
					allycount = allycount + 1
				end
			-- ally heal
				if self.Menu.summs.summheal.summhealmate:Value() and ally.health / ally.maxHealth <= self.Menu.summs.summheal.summhealmatehp:Value() / 100 and self.Menu.summs.summheal.alliestoheal[ally.charName] and self.Menu.summs.summheal.alliestoheal[ally.charName]:Value() and enemy.activeSpell.valid and not enemy.activeSpell.isStopped and ValidTarget(ally, 850 + myHero.boundingRadius + ally.boundingRadius) then
					if enemy.activeSpell.target == ally.handle then
                        self:UseHeal(ally)
                    else
                        local placementPos = enemy.activeSpell.placementPos
                        local width = ally.boundingRadius + 50
                        if enemy.activeSpell.width > 0 then width = width + enemy.activeSpell.width end
                        local spellLine = ClosestPointOnLineSegment(ally.pos, enemy.pos, placementPos)
                        if GetDistance(ally.pos, spellLine) <= width then
                            self:UseHeal(ally)
                        end
                    end
				end
            -- exhaust ally
                if self.Menu.summs.summexhaust.summexhaustmate:Value() and IsValid(ally) and ValidTarget(enemy, 535 + myHero.boundingRadius) and ally.health / ally.maxHealth <= self.Menu.summs.summexhaust.summexhaustmatehp:Value() / 100 and enemy.activeSpell.valid and not enemy.activeSpell.isStopped and self.Menu.summs.summexhaust.enemiestohit[enemy.charName]:Value() then
                    if enemy.activeSpell.target == ally.handle then
                        self:UseExhaust(enemy)
                    else
                        local placementPos = enemy.activeSpell.placementPos
                        local width = ally.boundingRadius + 50
                        if enemy.activeSpell.width > 0 then width = width + enemy.activeSpell.width end
                        local spellLine = ClosestPointOnLineSegment(ally.pos, enemy.pos, placementPos)
                        if GetDistance(ally.pos, spellLine) <= width then
                            self:UseExhaust(enemy)
                        end
                    end
                end
			-- ally redemption
				if self.Menu.defitems.itemredemption.itemredemptionmate:Value() and ally.health / ally.maxHealth <= self.Menu.defitems.itemredemption.itemredemptionmatehp:Value() / 100 and enemy.activeSpell.valid and not enemy.activeSpell.isStopped and ValidTarget(ally, 5500 + myHero.boundingRadius + ally.boundingRadius) and self.Menu.defitems.itemredemption.alliestoheal[ally.charName] and self.Menu.defitems.itemredemption.alliestoheal[ally.charName]:Value() and not _G.SDK.Attack:IsActive() then
					if enemy.activeSpell.target == ally.handle then
                        if ally.pos:ToScreen().onScreen then
                            self:UseRedemption(ally)
                        else
                            self:UseRedemptionMM(ally)
                        end
                    else
                        local placementPos = enemy.activeSpell.placementPos
                        local width = ally.boundingRadius + 50
                        if enemy.activeSpell.width > 0 then width = width + enemy.activeSpell.width end
                        local spellLine = ClosestPointOnLineSegment(ally.pos, enemy.pos, placementPos)
                        if GetDistance(ally.pos, spellLine) <= width then
                            if ally.pos:ToScreen().onScreen then
                                self:UseRedemption(ally)
                            else
                                self:UseRedemptionMM(ally)
                            end
                        end
                    end
				end
			-- ally mikaels 
				if self.Menu.defitems.itemredemption.itemredemptionmate:Value() and enemy and IsValid(enemy) and GetDistance(ally.pos, enemy.pos) < self.Menu.defitems.itemmikaels.itemmikaelsmaterange:Value() + ally.boundingRadius + enemy.boundingRadius and IsCleanse(ally) > 0.5 and ValidTarget(ally, 600 + myHero.boundingRadius + ally.boundingRadius) and self.Menu.defitems.itemmikaels.alliestoheal[ally.charName] and self.Menu.defitems.itemmikaels.alliestoheal[ally.charName]:Value() and not _G.SDK.Attack:IsActive() then
					self:UseMikaels(ally)
				end
			-- ally locket
				if self.Menu.defitems.itemsolari.itemsolarimate:Value() and ally.health / ally.maxHealth <= self.Menu.defitems.itemsolari.itemsolarimatehp:Value() / 100 and enemy.activeSpell.valid and not enemy.activeSpell.isStopped and self.Menu.defitems.itemsolari.alliestoheal[ally.charName] and self.Menu.defitems.itemsolari.alliestoheal[ally.charName]:Value() and ValidTarget(ally, 800 + myHero.boundingRadius + ally.boundingRadius) and not _G.SDK.Attack:IsActive() then
					if enemy.activeSpell.target == ally.handle then
                        self:UseLocket(ally)
                    else
                        local placementPos = enemy.activeSpell.placementPos
                        local width = ally.boundingRadius + 50
                        if enemy.activeSpell.width > 0 then width = width + enemy.activeSpell.width end
                        local spellLine = ClosestPointOnLineSegment(ally.pos, enemy.pos, placementPos)
                        if GetDistance(ally.pos, spellLine) <= width then
                            self:UseLocket(ally)
                        end
                    end
				end
			-- ally shurelyas
				if self.Menu.targitems.itemshure.itemshureuse:Value() and ValidTarget(enemy, self.Menu.targitems.itemshure.itemshurerange:Value() + myHero.boundingRadius + enemy.boundingRadius) and AlliesAround == self.Menu.targitems.itemshure.itemshureally:Value() and self.Menu.targitems.itemshure.enemiestohit[enemy.charName] and self.Menu.targitems.itemshure.enemiestohit[enemy.charName]:Value()and not _G.SDK.Attack:IsActive() then
					self:UseShurelyas()
				elseif self.Menu.targitems.itemshure.itemshureuse:Value() and GetDistance(ally.pos, enemy.pos) < self.Menu.targitems.itemshure.itemshurerange:Value() + myHero.boundingRadius + enemy.boundingRadius and IsValid(enemy) and AlliesAround == self.Menu.targitems.itemshure.itemshureally:Value() and self.Menu.targitems.itemshure.enemiestohit[enemy.charName] and self.Menu.targitems.itemshure.enemiestohit[enemy.charName]:Value() and not _G.SDK.Attack:IsActive() then
					self:UseShurelyas()
				end
			end	
			AlliesAround = allycount
		end
		EnemiesIronSpike = spikecount
		EnemiesGoreDrinker = drinkercount
		EnemiesOmen = omencount
end

function Activator:Monsters(enemy)
    local monsters = _G.SDK.ObjectManager:GetMonsters(1000)
    for i = 1, #monsters do
        local monster = monsters[i]
        if ValidTarget(monster, 550) and self.Menu.summs.summsmite.smitecamps.smitedrake:Value() and (monster.charName == "SRU_Dragon_Water" or monster.charName == "SRU_Dragon_Fire" or monster.charName == "SRU_Dragon_Earth" or monster.charName == "SRU_Dragon_Air" or monster.charName == "SRU_Dragon_Elder") then
            local SmiteDamage = self:GetSmiteDamage()
            if monster.health <= SmiteDamage then
                self:SmiteCamp(monster)
            end
        end
        if ValidTarget(monster, 550) and self.Menu.summs.summsmite.smitecamps.smiteherald:Value() and monster.charName == "SRU_RiftHerald" then
            local SmiteDamage = self:GetSmiteDamage()
            if monster.health <= SmiteDamage then
                self:SmiteCamp(monster)
            end
        end
        if ValidTarget(monster, 550) and self.Menu.summs.summsmite.smitecamps.smitebaron:Value() and monster.charName == "SRU_Baron" then
            local SmiteDamage = self:GetSmiteDamage()
            if monster.health <= SmiteDamage then
                self:SmiteCamp(monster)
            end
        end
        if ValidTarget(monster, 550) and self.Menu.summs.summsmite.smitecamps.smiteredblue:Value() and (monster.charName == "SRU_Blue" or monster.charName == "SRU_Red") and ValidTarget(enemy, 1000) then
            local SmiteDamage = self:GetSmiteDamage()
            if monster.health <= SmiteDamage then
                self:SmiteCamp(monster)
            end
        end
        if ValidTarget(monster, 550) and self.Menu.summs.summsmite.smitecamps.smitecrab:Value() and monster.charName == "Sru_Crab" and ValidTarget(enemy, 1000) then
            local SmiteDamage = self:GetSmiteDamage()
            if monster.health <= SmiteDamage then
                self:SmiteCamp(monster)
            end
        end
        if ValidTarget(monster, 550) and self.Menu.summs.summsmite.smitecamps.smitelow:Value() and myHero.health / myHero.maxHealth <= self.Menu.summs.summsmite.smitecamps.smitelowhp:Value() / 100 and ValidTarget(enemy, 1000) then
            for i = 1, #Camps do
                if monster.charName == Camps[i] then
                    self:SmiteCamp(monster)
                end
            end
        end
    end
end

function Activator:Autolvl()
    local spellPoints = myHero.levelData.lvlPts 
    local Level = myHero.levelData.lvl

    if spellPoints > 0 and self.Menu.autolvl.autolvluse:Value() and Game.IsOnTop() and Level >= self.Menu.autolvl.autolvllvl:Value() then
        if Level == 6 or Level == 11 or Level == 16 then
            Control.KeyDown(HK_LUS)
            Control.KeyDown(HK_R)
            Control.KeyUp(HK_R)
            Control.KeyUp(HK_LUS)
        elseif Level == 8 or Level == 10 or Level == 12 or Level == 13 then
            if self.Menu.autolvl.autolvlorder:Value() == 1 or self.Menu.autolvl.autolvlorder:Value() == 6 then
                Control.KeyDown(HK_LUS)
                Control.KeyDown(HK_W)
                Control.KeyUp(HK_W)
                Control.KeyUp(HK_LUS)
            elseif self.Menu.autolvl.autolvlorder:Value() == 3 or self.Menu.autolvl.autolvlorder:Value() == 5 then
                Control.KeyDown(HK_LUS)
                Control.KeyDown(HK_Q)
                Control.KeyUp(HK_Q)
                Control.KeyUp(HK_LUS)
            elseif self.Menu.autolvl.autolvlorder:Value() == 2 or self.Menu.autolvl.autolvlorder:Value() == 4 then
                Control.KeyDown(HK_LUS)
                Control.KeyDown(HK_E)
                Control.KeyUp(HK_E)
                Control.KeyUp(HK_LUS)
            end
        elseif Level == 4 or Level == 5 or Level == 7 or Level == 9 then
            if self.Menu.autolvl.autolvlorder:Value() == 1 or self.Menu.autolvl.autolvlorder:Value() == 2 then
                Control.KeyDown(HK_LUS)
                Control.KeyDown(HK_Q)
                Control.KeyUp(HK_Q)
                Control.KeyUp(HK_LUS)
            elseif self.Menu.autolvl.autolvlorder:Value() == 3 or self.Menu.autolvl.autolvlorder:Value() == 4 then
                Control.KeyDown(HK_LUS)
                Control.KeyDown(HK_W)
                Control.KeyUp(HK_W)
                Control.KeyUp(HK_LUS)
            elseif self.Menu.autolvl.autolvlorder:Value() == 5 or self.Menu.autolvl.autolvlorder:Value() == 6 then
                Control.KeyDown(HK_LUS)
                Control.KeyDown(HK_E)
                Control.KeyUp(HK_E)
                Control.KeyUp(HK_LUS)
            end
        elseif Level == 14 or Level == 15 or Level == 17 or Level == 18 then
            if self.Menu.autolvl.autolvlorder:Value() == 4 or self.Menu.autolvl.autolvlorder:Value() == 6 then
                Control.KeyDown(HK_LUS)
                Control.KeyDown(HK_Q)
                Control.KeyUp(HK_Q)
                Control.KeyUp(HK_LUS)
            elseif self.Menu.autolvl.autolvlorder:Value() == 2 or self.Menu.autolvl.autolvlorder:Value() == 5 then
                Control.KeyDown(HK_LUS)
                Control.KeyDown(HK_W)
                Control.KeyUp(HK_W)
                Control.KeyUp(HK_LUS)
            elseif self.Menu.autolvl.autolvlorder:Value() == 1 or self.Menu.autolvl.autolvlorder:Value() == 3 then
                Control.KeyDown(HK_LUS)
                Control.KeyDown(HK_E)
                Control.KeyUp(HK_E)
                Control.KeyUp(HK_LUS)
            end
            -- lvl 2 Protection
        elseif Level == 2 then
            if self.Menu.autolvl.autolvlorder:Value() == 3 and myHero:GetSpellData(_Q).level == 0 then
                Control.KeyDown(HK_LUS)
                Control.KeyDown(HK_Q)
                Control.KeyUp(HK_Q)
                Control.KeyUp(HK_LUS)
            elseif self.Menu.autolvl.autolvlorder:Value() == 3 and myHero:GetSpellData(_Q).level == 1 then
                Control.KeyDown(HK_LUS)
                Control.KeyDown(HK_W)
                Control.KeyUp(HK_W)
                Control.KeyUp(HK_LUS)
            end
            if self.Menu.autolvl.autolvlorder:Value() == 1 and myHero:GetSpellData(_W).level == 0 then
                Control.KeyDown(HK_LUS)
                Control.KeyDown(HK_W)
                Control.KeyUp(HK_W)
                Control.KeyUp(HK_LUS)
            elseif self.Menu.autolvl.autolvlorder:Value() == 1 and myHero:GetSpellData(_W).level == 1 then
                Control.KeyDown(HK_LUS)
                Control.KeyDown(HK_Q)
                Control.KeyUp(HK_Q)
                Control.KeyUp(HK_LUS)
            end
            if self.Menu.autolvl.autolvlorder:Value() == 2 and myHero:GetSpellData(_E).level == 0 then
                Control.KeyDown(HK_LUS)
                Control.KeyDown(HK_E)
                Control.KeyUp(HK_E)
                Control.KeyUp(HK_LUS)
            elseif self.Menu.autolvl.autolvlorder:Value() == 2 and myHero:GetSpellData(_E).level == 1 then
                Control.KeyDown(HK_LUS)
                Control.KeyDown(HK_Q)
                Control.KeyUp(HK_Q)
                Control.KeyUp(HK_LUS)
            end
            if self.Menu.autolvl.autolvlorder:Value() == 4 and myHero:GetSpellData(_E).level == 0 then
                Control.KeyDown(HK_LUS)
                Control.KeyDown(HK_E)
                Control.KeyUp(HK_E)
                Control.KeyUp(HK_LUS)
            elseif self.Menu.autolvl.autolvlorder:Value() == 4 and myHero:GetSpellData(_E).level == 1 then
                Control.KeyDown(HK_LUS)
                Control.KeyDown(HK_W)
                Control.KeyUp(HK_W)
                Control.KeyUp(HK_LUS)
            end
            if self.Menu.autolvl.autolvlorder:Value() == 5 and myHero:GetSpellData(_Q).level == 0 then
                Control.KeyDown(HK_LUS)
                Control.KeyDown(HK_Q)
                Control.KeyUp(HK_Q)
                Control.KeyUp(HK_LUS)
            elseif self.Menu.autolvl.autolvlorder:Value() == 5 and myHero:GetSpellData(_Q).level == 1 then
                Control.KeyDown(HK_LUS)
                Control.KeyDown(HK_E)
                Control.KeyUp(HK_E)
                Control.KeyUp(HK_LUS)
            end
            if self.Menu.autolvl.autolvlorder:Value() == 6 and myHero:GetSpellData(_W).level == 0 then
                Control.KeyDown(HK_LUS)
                Control.KeyDown(HK_W)
                Control.KeyUp(HK_W)
                Control.KeyUp(HK_LUS)
            elseif self.Menu.autolvl.autolvlorder:Value() == 6 and myHero:GetSpellData(_W).level == 1 then
                Control.KeyDown(HK_LUS)
                Control.KeyDown(HK_E)
                Control.KeyUp(HK_E)
                Control.KeyUp(HK_LUS)
            end
            -- lvl 3 Protection
        elseif Level == 3 then
            if self.Menu.autolvl.autolvlorder:Value() == 1 and myHero:GetSpellData(_E).level == 0 then
                Control.KeyDown(HK_LUS)
                Control.KeyDown(HK_E)
                Control.KeyUp(HK_E)
                Control.KeyUp(HK_LUS)
            elseif self.Menu.autolvl.autolvlorder:Value() == 1 and myHero:GetSpellData(_E).level == 1 then
                Control.KeyDown(HK_LUS)
                Control.KeyDown(HK_Q)
                Control.KeyUp(HK_Q)
                Control.KeyUp(HK_LUS)
            end
            if self.Menu.autolvl.autolvlorder:Value() == 2 and myHero:GetSpellData(_W).level == 0 then
                Control.KeyDown(HK_LUS)
                Control.KeyDown(HK_W)
                Control.KeyUp(HK_W)
                Control.KeyUp(HK_LUS)
            elseif self.Menu.autolvl.autolvlorder:Value() == 2 and myHero:GetSpellData(_W).level == 1 then
                Control.KeyDown(HK_LUS)
                Control.KeyDown(HK_Q)
                Control.KeyUp(HK_Q)
                Control.KeyUp(HK_LUS)
            end
            if self.Menu.autolvl.autolvlorder:Value() == 3 and myHero:GetSpellData(_E).level == 0 then
                Control.KeyDown(HK_LUS)
                Control.KeyDown(HK_E)
                Control.KeyUp(HK_E)
                Control.KeyUp(HK_LUS)
            elseif self.Menu.autolvl.autolvlorder:Value() == 3 and myHero:GetSpellData(_E).level == 1 then
                Control.KeyDown(HK_LUS)
                Control.KeyDown(HK_W)
                Control.KeyUp(HK_W)
                Control.KeyUp(HK_LUS)
            end
            if self.Menu.autolvl.autolvlorder:Value() == 4 and myHero:GetSpellData(_Q).level == 0 then
                Control.KeyDown(HK_LUS)
                Control.KeyDown(HK_Q)
                Control.KeyUp(HK_Q)
                Control.KeyUp(HK_LUS)
            elseif self.Menu.autolvl.autolvlorder:Value() == 4 and myHero:GetSpellData(_Q).level == 1 then
                Control.KeyDown(HK_LUS)
                Control.KeyDown(HK_W)
                Control.KeyUp(HK_W)
                Control.KeyUp(HK_LUS)
            end
            if self.Menu.autolvl.autolvlorder:Value() == 5 and myHero:GetSpellData(_W).level == 0 then
                Control.KeyDown(HK_LUS)
                Control.KeyDown(HK_W)
                Control.KeyUp(HK_W)
                Control.KeyUp(HK_LUS)
            elseif self.Menu.autolvl.autolvlorder:Value() == 5 and myHero:GetSpellData(_W).level == 1 then
                Control.KeyDown(HK_LUS)
                Control.KeyDown(HK_E)
                Control.KeyUp(HK_E)
                Control.KeyUp(HK_LUS)
            end
            if self.Menu.autolvl.autolvlorder:Value() == 6 and myHero:GetSpellData(_Q).level == 0 then
                Control.KeyDown(HK_LUS)
                Control.KeyDown(HK_Q)
                Control.KeyUp(HK_Q)
                Control.KeyUp(HK_LUS)
            elseif self.Menu.autolvl.autolvlorder:Value() == 6 and myHero:GetSpellData(_Q).level == 1 then
                Control.KeyDown(HK_LUS)
                Control.KeyDown(HK_E)
                Control.KeyUp(HK_E)
                Control.KeyUp(HK_LUS)
            end
        end
    end
end


function Activator:Draw()
	--Draw.Circle(myHero.pos, 1175, 1, Draw.Color(237, 255, 255, 255))
end

function Activator:ItemSpells()
	FrostSpellData = {speed = 1200, range = 835, delay = 0.20, radius = 50, collision = {}, type = "linear"}
	BeltSpellData = {speed = 1600, range = 1000, delay = 0.31, angle = 45, radius = 50, collision = {"minion"}, type = "conic"}
	BreakerSpellData = {speed = 1500, range = 500, delay = 0.21, radius = 50, collision = {}, type = "circular"}
end
-- summs 
function Activator:UseHeal(unit)
	if myHero:GetSpellData(SUMMONER_1).name == "SummonerHeal" and IsReady(SUMMONER_1) then
		Control.CastSpell(HK_SUMMONER_1, unit)
	elseif myHero:GetSpellData(SUMMONER_2).name == "SummonerHeal" and IsReady(SUMMONER_2) then
		Control.CastSpell(HK_SUMMONER_2, unit)
	end
end

function Activator:UseBarrier()
	if myHero:GetSpellData(SUMMONER_1).name == "SummonerBarrier" and IsReady(SUMMONER_1) then
		Control.CastSpell(HK_SUMMONER_1)
	elseif myHero:GetSpellData(SUMMONER_2).name == "SummonerBarrier" and IsReady(SUMMONER_2) then
		Control.CastSpell(HK_SUMMONER_2)
	end
end

function Activator:UseExhaust(unit)
	if myHero:GetSpellData(SUMMONER_1).name == "SummonerExhaust" and IsReady(SUMMONER_1) then
		Control.CastSpell(HK_SUMMONER_1, unit)
	elseif myHero:GetSpellData(SUMMONER_2).name == "SummonerExhaust" and IsReady(SUMMONER_2) then
		Control.CastSpell(HK_SUMMONER_2, unit)
	end
end

function Activator:UseCleanse()
	if myHero:GetSpellData(SUMMONER_1).name == "SummonerBoost" and IsReady(SUMMONER_1) then
		Control.CastSpell(HK_SUMMONER_1)
	elseif myHero:GetSpellData(SUMMONER_2).name == "SummonerBoost" and IsReady(SUMMONER_2) then
		Control.CastSpell(HK_SUMMONER_2)
	end
end

function Activator:UseIgnite(unit)
	if myHero:GetSpellData(SUMMONER_1).name == "SummonerDot" and IsReady(SUMMONER_1) then
		Control.CastSpell(HK_SUMMONER_1, unit)
	elseif myHero:GetSpellData(SUMMONER_2).name == "SummonerDot" and IsReady(SUMMONER_2) then
		Control.CastSpell(HK_SUMMONER_2, unit)
	end
end

function Activator:UseBlueSmite(unit)
	if myHero:GetSpellData(SUMMONER_1).name == "S5_SummonerSmitePlayerGanker" and IsReady(SUMMONER_1) and myHero:GetSpellData(SUMMONER_1).ammo > 1then
		Control.CastSpell(HK_SUMMONER_1, unit)
	elseif myHero:GetSpellData(SUMMONER_2).name == "S5_SummonerSmitePlayerGanker" and IsReady(SUMMONER_2) and myHero:GetSpellData(SUMMONER_2).ammo > 1 then
		Control.CastSpell(HK_SUMMONER_2, unit)
	end
end

function Activator:UseRedSmite(unit)
	if myHero:GetSpellData(SUMMONER_1).name == "S5_SummonerSmiteDuel" and IsReady(SUMMONER_1) and myHero:GetSpellData(SUMMONER_1).ammo > 1 then
		Control.CastSpell(HK_SUMMONER_1, unit)
	elseif myHero:GetSpellData(SUMMONER_2).name == "S5_SummonerSmiteDuel" and IsReady(SUMMONER_2) and myHero:GetSpellData(SUMMONER_2).ammo > 1 then
		Control.CastSpell(HK_SUMMONER_2, unit)
	end
end

function Activator:SmiteCamp(unit)
    if (myHero:GetSpellData(SUMMONER_1).name == "S5_SummonerSmitePlayerGanker" or myHero:GetSpellData(SUMMONER_1).name == "S5_SummonerSmiteDuel" or myHero:GetSpellData(SUMMONER_1).name == "SummonerSmite") and IsReady(SUMMONER_1) then
        Control.CastSpell(HK_SUMMONER_1, unit)
    elseif (myHero:GetSpellData(SUMMONER_2).name == "S5_SummonerSmitePlayerGanker" or myHero:GetSpellData(SUMMONER_2).name == "S5_SummonerSmiteDuel" or myHero:GetSpellData(SUMMONER_2).name == "SummonerSmite") and IsReady(SUMMONER_2) then
        Control.CastSpell(HK_SUMMONER_2, unit)
    end
end

function Activator:GetSmiteDamage()
    if myHero:GetSpellData(SUMMONER_1).name == "SummonerSmite" or myHero:GetSpellData(SUMMONER_2).name == "SummonerSmite" then
        return 450
    elseif myHero:GetSpellData(SUMMONER_1).name == "S5_SummonerSmiteDuel" or myHero:GetSpellData(SUMMONER_2).name == "S5_SummonerSmiteDuel" then
        return 900
    elseif myHero:GetSpellData(SUMMONER_1).name == "S5_SummonerSmitePlayerGanker" or myHero:GetSpellData(SUMMONER_2).name == "S5_SummonerSmitePlayerGanker" then
        return 900
    else 
        return 0
    end
end

-- items
function Activator:UseQSS()
	local ItemQSS = GetItemSlot(myHero, 3140)
	if ItemQSS > 0 and myHero:GetSpellData(ItemQSS).currentCd == 0 then
		Control.CastSpell(ItemHotKey[ItemQSS])
	end
end

function Activator:UseMerc()
	local ItemMerc = GetItemSlot(myHero,  3139)
	if ItemMerc > 0 and myHero:GetSpellData(ItemMerc).currentCd == 0 then
		Control.CastSpell(ItemHotKey[ItemMerc])
	end
end

function Activator:UseDawn()
	local ItemDawn = GetItemSlot(myHero, 6035)
	if ItemDawn > 0 and myHero:GetSpellData(ItemDawn).currentCd == 0 then
		Control.CastSpell(ItemHotKey[ItemDawn])
	end
end

function Activator:UseRedemption(unit)
	local ItemRedem = GetItemSlot(myHero, 3107)
	if ItemRedem > 0 and myHero:GetSpellData(ItemRedem).currentCd == 0 then
		Control.CastSpell(ItemHotKey[ItemRedem], unit)
	end
end

function Activator:UseRedemptionMM(unit)
	local ItemRedem = GetItemSlot(myHero, 3107)
	if ItemRedem > 0 and myHero:GetSpellData(ItemRedem).currentCd == 0 then
        MMCast(unit.pos, ItemHotKey[ItemRedem])
	end
end

function Activator:UseMikaels(unit)
	local ItemMika = GetItemSlot(myHero, 3222)
	if ItemMika > 0 and myHero:GetSpellData(ItemMika).currentCd == 0 then
		Control.CastSpell(ItemHotKey[ItemMika], unit)
	end
end

function Activator:UseStpWth()
	local ItemStpWth = GetItemSlot(myHero, 2420)
	if ItemStpWth > 0 and myHero:GetSpellData(ItemStpWth).currentCd == 0 then
		Control.CastSpell(ItemHotKey[ItemStpWth])
	end
end

function Activator:UseZhonyas()
	local ItemZhonyas = GetItemSlot(myHero, 3157)
	if ItemZhonyas > 0 and myHero:GetSpellData(ItemZhonyas).currentCd == 0 then
		Control.CastSpell(ItemHotKey[ItemZhonyas])
	end
end

function Activator:UseLocket()
	local ItemLocket = GetItemSlot(myHero, 3190)
	if ItemLocket > 0 and myHero:GetSpellData(ItemLocket).currentCd == 0 then
		Control.CastSpell(ItemHotKey[ItemLocket])
	end
end

function Activator:UseIronSpk()
    if (self.Menu.targitems.itemironspk.itemironspkcombo:Value() and Mode() == "Combo") or not self.Menu.targitems.itemironspk.itemironspkcombo:Value() then
    	local ItemIronSpk = GetItemSlot(myHero, 6029)
    	if ItemIronSpk > 0 and myHero:GetSpellData(ItemIronSpk).currentCd == 0 then
    		Control.CastSpell(ItemHotKey[ItemIronSpk])
    	end
    end
end

function Activator:UseGoreDrinker()
    if (self.Menu.targitems.itemgoredrnk.itemgoredrnkcombo:Value() and Mode() == "Combo") or not self.Menu.targitems.itemgoredrnk.itemgoredrnkcombo:Value() then
    	local ItemGoreDrinker = GetItemSlot(myHero, 6630)
    	if ItemGoreDrinker > 0 and myHero:GetSpellData(ItemGoreDrinker).currentCd == 0 then
    		Control.CastSpell(ItemHotKey[ItemGoreDrinker])
    	end
    end
end

function Activator:UseStrideBreaker(unit)
    if (self.Menu.targitems.itemstidebreaker.itemstidebreakercombo:Value() and Mode() == "Combo") or not self.Menu.targitems.itemstidebreaker.itemstidebreakercombo:Value() then
    	local ItemStrideBreaker = GetItemSlot(myHero, 6631)
    	local pred = _G.PremiumPrediction:GetPrediction(myHero, unit, BreakerSpellData)
    	if pred.CastPos and _G.PremiumPrediction.HitChance.Medium(pred.HitChance) and ItemStrideBreaker > 0 and myHero:GetSpellData(ItemStrideBreaker).currentCd == 0 then
    		Control.CastSpell(ItemHotKey[ItemStrideBreaker], pred.CastPos)
    	end
    end
end

function Activator:UseShurelyas()
    if (self.Menu.targitems.itemshure.itemshurecombo:Value() and Mode() == "Combo") or not self.Menu.targitems.itemshure.itemshurecombo:Value() then
    	local ItemShurelyas = GetItemSlot(myHero, 2065)
    	if ItemShurelyas > 0 and myHero:GetSpellData(ItemShurelyas).currentCd == 0 then
    		Control.CastSpell(ItemHotKey[ItemShurelyas])
    	end
    end
end

function Activator:UseOmen()
    if (self.Menu.targitems.itemranduin.itemranduincombo:Value() and Mode() == "Combo") or not self.Menu.targitems.itemranduin.itemranduincombo:Value() then
    	local ItemOmen = GetItemSlot(myHero, 3143)
    	if ItemOmen > 0 and myHero:GetSpellData(ItemOmen).currentCd == 0 then
    		Control.CastSpell(ItemHotKey[ItemOmen])
    	end
    end
end

function Activator:UseChempunk()
    if (self.Menu.targitems.itemchempunk.itemchempunkcombo:Value() and Mode() == "Combo") or not self.Menu.targitems.itemchempunk.itemchempunkcombo:Value() then
    	local ItemChempunk = GetItemSlot(myHero, 6664)
    	if ItemChempunk > 0 and myHero:GetSpellData(ItemChempunk).currentCd == 0 then
    		Control.CastSpell(ItemHotKey[ItemChempunk])
    	end
    end
end

function Activator:UseYoumuus()
    if (self.Menu.targitems.itemyoumuu.itemyoumuusecombo:Value() and Mode() == "Combo") or not self.Menu.targitems.itemyoumuu.itemyoumuusecombo:Value() then
    	local ItemYoumuus = GetItemSlot(myHero, 3142)
    	if ItemYoumuus > 0 and myHero:GetSpellData(ItemYoumuus).currentCd == 0 then
    		Control.CastSpell(ItemHotKey[ItemYoumuus])
    	end
    end
end

function Activator:UseRocketBelt(unit)
    if (self.Menu.targitems.itemrocket.itemrocketcombo:Value() and Mode() == "Combo") or not self.Menu.targitems.itemrocket.itemrocketcombo:Value() then
    	local ItemRocketBelt = GetItemSlot(myHero, 3152)
    	local pred = _G.PremiumPrediction:GetPrediction(myHero, unit, BeltSpellData)
    	if pred.CastPos and _G.PremiumPrediction.HitChance.Medium(pred.HitChance) and ItemRocketBelt > 0 and myHero:GetSpellData(ItemRocketBelt).currentCd == 0 then
    		Control.CastSpell(ItemHotKey[ItemRocketBelt], pred.CastPos)
    	end
    end
end

function Activator:UseClaw(unit)
    if (self.Menu.targitems.itemprowler.itemprowlercombo:Value() and Mode() == "Combo") or not self.Menu.targitems.itemprowler.itemprowlercombo:Value() then
    	local ItemClaw = GetItemSlot(myHero, 6693)
    	if ItemClaw > 0 and myHero:GetSpellData(ItemClaw).currentCd == 0 then
    		Control.CastSpell(ItemHotKey[ItemClaw], unit)
    	end
    end
end

function Activator:UseFrost(unit)
    if (self.Menu.targitems.itemevfrost.itemevfrostcombo:Value() and Mode() == "Combo") or not self.Menu.targitems.itemevfrost.itemevfrostcombo:Value() then
    	local ItemFrost = GetItemSlot(myHero, 6656)
    	local pred = _G.PremiumPrediction:GetPrediction(myHero, unit, FrostSpellData)
    	if pred.CastPos and ItemFrost > 0 and myHero:GetSpellData(ItemFrost).currentCd == 0 then
    		Control.CastSpell(ItemHotKey[ItemFrost], pred.CastPos)
    	end
    end
end

function Activator:UseGale(posy)
    if (self.Menu.targitems.itemgale.itemgalecombo:Value() and Mode() == "Combo") or not self.Menu.targitems.itemgale.itemgalecombo:Value() then
    	local ItemGale = GetItemSlot(myHero, 6671)
    	if ItemGale > 0 and myHero:GetSpellData(ItemGale).currentCd == 0 then
    		Control.CastSpell(ItemHotKey[ItemGale], posy)
    	end
    end
end


	
--pots
function Activator:UseHPPot()
	local ItemHPPot = GetItemSlot(myHero, 2003) 
	if ItemHPPot > 0 and not BuffActive(myHero, "Item2003") and not InBase(myHero.pos) then
		Control.CastSpell(ItemHotKey[ItemHPPot])
	end
end

function Activator:UseCookie()
	local ItemCookie = GetItemSlot(myHero, 2010)
	if ItemCookie > 0 and not BuffActive(myHero, "Item2010") and not InBase(myHero.pos) then
		Control.CastSpell(ItemHotKey[ItemCookie])
	end
end

function Activator:UseRefillPot()
	local ItemRefillPot = GetItemSlot(myHero, 2031)
	local RefillAmmo = myHero:GetItemData(ItemRefillPot).ammo 
	if ItemRefillPot > 0 and not BuffActive(myHero, "ItemCrystalFlask") and RefillAmmo > 0 and not InBase(myHero.pos) then
		Control.CastSpell(ItemHotKey[ItemRefillPot])
	end
end

function Activator:UseCorruptPot()
	local ItemCorruptPot = GetItemSlot(myHero, 2033)
	local CorruptAmmo = myHero:GetItemData(ItemCorruptPot).ammo
	if ItemCorruptPot > 0 and not BuffActive(myHero, "ItemDarkCrystalFlask") and CorruptAmmo > 0 and not InBase(myHero.pos) then
		Control.CastSpell(ItemHotKey[ItemCorruptPot])
	end
end

function Activator:Pots()
	if myHero.alive == false then return end
	
	if self.Menu.pots.itemhppot:Value() and myHero.health / myHero.maxHealth <= self.Menu.pots.itemhppothp:Value() / 100 then
		self:UseHPPot()
	end
	if self.Menu.pots.itemrefpot:Value() and myHero.health / myHero.maxHealth <= self.Menu.pots.itemrefpothp:Value() / 100 then
		self:UseRefillPot()
	end
	if self.Menu.pots.itemcookie:Value() and myHero.mana / myHero.maxMana <= self.Menu.pots.itemcookiemana:Value() / 100 then
		self:UseCookie()
	end
	if self.Menu.pots.itemcorpot:Value() and myHero.health / myHero.maxHealth <= self.Menu.pots.itemcorpothp:Value() / 100 then
		self:UseCorruptPot()
	end
	
end

function Activator:GaleLeftRight(unit)
	local RadAngle1 = 90 * math.pi / 180
	local RadAngle2 = 270 * math.pi / 180
	local EnemyDirection = Vector((myHero.pos-unit.pos):Normalized())
	local LeftDirection = Vector(EnemyDirection:Rotated(0, RadAngle1, 0))
	local RightDirection = Vector(EnemyDirection:Rotated(0, RadAngle2, 0))
	local GaleLeft = myHero.pos - LeftDirection * 400
	local GaleRight = myHero.pos - RightDirection * 400
	local LeftLeftDirection = Vector((GaleLeft-unit.pos):Normalized())
	local RightRightDirection = Vector((GaleRight-unit.pos):Normalized())
	local BestSpotLeft = GaleLeft - LeftLeftDirection * 200
	local BestSpotRight = GaleRight - RightRightDirection * 200
	if GetDistance(mousePos, BestSpotLeft) > GetDistance(mousePos, BestSpotRight) then
		GalePos = BestSpotRight
	else
		GalePos = BestSpotLeft
	end
	return GalePos
	
end

function OnLoad()
    Activator()
end

