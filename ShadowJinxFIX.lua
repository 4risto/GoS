
local GameHeroCount = Game.HeroCount
local GameHero = Game.Hero

local myHero = myHero
local LocalGameTimer = Game.Timer
local GameMissile = Game.Missile
local GameMissileCount = Game.MissileCount

local lastQ = 0

local lastW = 0
local lastE = 0
local lastR = 0
local lastIG = 0
local lastMove = 0
local HITCHANCE_NORMAL = 2
local HITCHANCE_HIGH = 3
local HITCHANCE_IMMOBILE = 4

local Enemys = {}
local Allys = {}

local orbwalker
local TargetSelector

-- [ AutoUpdate ] --
do
    
    local Version = 0.05
    
    local Files = {
        Lua = {
            Path = SCRIPT_PATH,
            Name = "Jinx.lua",
            Url = "https://raw.githubusercontent.com/4risto/Gamingonsteroids-LUAs/master/ShadowJinxFIX.lua"
        },
        Version = {
            Path = SCRIPT_PATH,
            Name = "Jinx.version",
            Url = "https://raw.githubusercontent.com/4risto/Gamingonsteroids-LUAs/master/ShadowJinxFIX.version"    -- check if Raw Adress correct pls.. after you have create the version file on Github
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
            print("New ShadowAIO Vers. Press 2x F6")     -- <-- you can change the massage for users here !!!!
        else
            print(Files.Version.Name .. ": No Updates Found")   --  <-- here too
        end
    
    end
    
    AutoUpdate()

end

local Champions = {
    ["Jinx"] = true,
}

--Checking Champion 
if Champions[myHero.charName] == nil then
    print('Shadow AIO does not support ' .. myHero.charName) return
end


Callback.Add("Load", function()
    orbwalker = _G.SDK.Orbwalker
    TargetSelector = _G.SDK.TargetSelector
    if FileExist(COMMON_PATH .. "GamsteronPrediction.lua") then
        require('GamsteronPrediction');
    else
        print("Requires GamsteronPrediction please download the file thanks!");
        return
    end
    if FileExist(COMMON_PATH .. "DamageLib.lua") then
        print("Damagelib Loaded")

    end
        
    require('damagelib')
    local _IsHero = _G[myHero.charName]();
    _IsHero:LoadMenu();
end)

local function IsValid(unit)
    if (unit
        and unit.valid
        and unit.isTargetable
        and unit.alive
        and unit.visible
        and unit.networkID
        and unit.health > 0
        and not unit.dead
    ) then
    return true;
end
return false;
end

local function MinionsNear(pos,range)
	local pos = pos.pos
	local N = 0
		for i = 1, Game.MinionCount() do 
		local Minion = Game.Minion(i)
		local Range = range * range
		if IsValid(Minion, 800) and Minion.team == TEAM_ENEMY and GetDistanceSqr(pos, Minion.pos) < Range then
			N = N + 1
		end
	end
	return N	
end	

local function GetAllyHeroes() 
	AllyHeroes = {}
	for i = 1, Game.HeroCount() do
		local Hero = Game.Hero(i)
		if Hero.isAlly and not Hero.isMe then
			table.insert(AllyHeroes, Hero)
		end
	end
	return AllyHeroes
end

local function Ready(spell)
    return myHero:GetSpellData(spell).currentCd == 0 and myHero:GetSpellData(spell).level > 0 and myHero:GetSpellData(spell).mana <= myHero.mana and Game.CanUseSpell(spell) == 0
end

local function OnAllyHeroLoad(cb)
    for i = 1, GameHeroCount() do
        local obj = GameHero(i)
        if obj.isAlly then
            cb(obj)
        end
    end
end

local function OnEnemyHeroLoad(cb)
    for i = 1, GameHeroCount() do
        local obj = GameHero(i)
        if obj.isEnemy then
            cb(obj)
        end
    end
end

function GetCastLevel(unit, slot)
	return unit:GetSpellData(slot).level == 0 and 1 or unit:GetSpellData(slot).level
end

local function GetStatsByRank(slot1, slot2, slot3, spell)
	local slot1 = 0
    local slot2 = 0
    local slot3 = 0
	return (({slot1, slot2, slot3})[myHero:GetSpellData(spell).level or 1])
end

function IsImmobileTarget(unit)
	for i = 0, unit.buffCount do
		local buff = unit:GetBuff(i)
		if buff and (buff.type == 5 or buff.type == 11 or buff.type == 29 or buff.type == 24 or buff.name == "recall") and buff.count > 0 then
			return true
		end
	end
	return false	
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


local Heroes = {"Jinx"}
if not table.contains(Heroes, myHero.charName) then return end
        
class "Jinx"
function Jinx:__init()
    
    self.Q = {Type = _G.SPELLTYPE_CIRCLE, Radius = 150}
    self.W = {Type = _G.SPELLTYPE_LINE, Range = 1450, Radius = 40.25, Speed = 3200, Collision = true, MaxCollision = 1, CollisionTypes = {0, 2, 3}}
    self.E = {Type = _G.SPELLTYPE_CIRCLE, Range = 900, Radius = 50}
    self.R = {Type = _G.SPELLTYPE_CIRCLE, Range = 20000, Radius = 225, Speed = 1500}

    

    OnAllyHeroLoad(function(hero)
        Allys[hero.networkID] = hero
    end)
    
    OnEnemyHeroLoad(function(hero)
        Enemys[hero.networkID] = hero
    end)
                                      --- you need Load here your Menu        
    Callback.Add("Tick", function() self:Tick() end)
    Callback.Add("Draw", function() self:Draw() end)
    
    orbwalker:OnPreMovement(function(args)
        if lastMove + 180 > GetTickCount() then
            args.Process = false
        else
            args.Process = true
            lastMove = GetTickCount()
        end
    end)
end

local Icons = {
    ["JinxIcon"] = "https://vignette.wikia.nocookie.net/leagueoflegends/images/6/65/Jinx_OriginalSquare.png",
    ["Q"] = "https://vignette.wikia.nocookie.net/leagueoflegends/images/4/4d/Pow-Pow.png",
    ["W"] = "https://vignette.wikia.nocookie.net/leagueoflegends/images/7/76/Zap%21.png",
    ["E"] = "https://vignette.wikia.nocookie.net/leagueoflegends/images/b/bb/Flame_Chompers%21.png",
    ["R"] = "https://vignette.wikia.nocookie.net/leagueoflegends/images/a/a8/Super_Mega_Death_Rocket%21.png",
    ["EXH"] = "https://vignette2.wikia.nocookie.net/leagueoflegends/images/4/4a/Exhaust.png"
    }

function Jinx:LoadMenu()
    self.shadowMenu = MenuElement({type = MENU, id = "shadowJinx", name = "Shadow Jinx", leftIcon = Icons["JinxIcon"]})


    -- COMBO --
    self.shadowMenu:MenuElement({type = MENU, id = "combo", name = "Combo"})
    self.shadowMenu.combo:MenuElement({id = "Q", name = "Use Q in Combo", value = true, leftIcon = Icons.Q})
    self.shadowMenu.combo:MenuElement({id = "W", name = "Use W in Combo", value = true, leftIcon = Icons.W})
    self.shadowMenu.combo:MenuElement({id = "E", name = "Use E in  Combo", value = true, leftIcon = Icons.E})
    self.shadowMenu.combo:MenuElement({id = "EONCC", name = "Auto Use E on CC Targets", value = true, leftIcon = Icons.E})


     -- JUNGLE KILLSTEAL --
    self.shadowMenu:MenuElement({type = MENU, id = "junglekillsteal", name = "Jungle Steal"})
    self.shadowMenu.junglekillsteal:MenuElement({id = "W", name = "Use W in Jungle Steal", value = true, leftIcon = Icons.W})


    -- KILL STEAL --
    self.shadowMenu:MenuElement({type = MENU, id = "killsteal", name = "Kill Steal"})
    self.shadowMenu.killsteal:MenuElement({id = "killstealw", name = "Kill steal with W", value = true, leftIcon = Icons.W})
    self.shadowMenu.killsteal:MenuElement({id = "killstealr", name = "Kill steal with R", value = true, leftIcon = Icons.R})
    self.shadowMenu.killsteal:MenuElement({id = "killstealrangemax", name = "Max Distance willing to use R at", value = 0, min = 0, max = 20000})

end


function Jinx:Draw()
end

function Jinx:Tick()
    if myHero.dead or Game.IsChatOpen() or (ExtLibEvade and ExtLibEvade.Evading == true) then
        return
    end
    self:autoe()
    self:killsteal()
    self:junglekillsteal()
    if orbwalker.Modes[0] then
        self:Combo()
    elseif orbwalker.Modes[3] then
    end
end

function Jinx:autoe()
    local target = TargetSelector:GetTarget(self.E.Range, 1)
    if target and IsValid(target) then
    if Ready(_E) and self.shadowMenu.combo.E:Value() and self.shadowMenu.combo.EONCC:Value() and IsImmobileTarget(target) then
        self:CastE(target)

    end
    end
end
function Jinx:killsteal()
    local target = TargetSelector:GetTarget(self.R.Range, 1)
    if target and IsValid(target) then      
    local d = myHero.pos:DistanceTo(target.pos)
    local wdmg = getdmg("W", target, myHero)
    local rdmg = getdmg("R", target, myHero)
        if Ready(_R) and target and IsValid(target) and (target.health <= rdmg) and self.shadowMenu.killsteal.killstealr:Value() and d <= self.shadowMenu.killsteal.killstealrangemax:Value() then
            self:CastR(target)
        end
        if Ready(_W) and target and IsValid(target) and (target.health <= wdmg) and self.shadowMenu.killsteal.killstealw:Value() then
            self:CastW(target)
        end
    end
end

function Jinx:Combo()
    local target = TargetSelector:GetTarget(self.W.Range, 1)
    if target == nil then return end
    if Ready(_W) and target and IsValid(target) then
        if self.shadowMenu.combo.W:Value() then
           self:CastW(target)
            --self:CastSpell(HK_Etarget)
        end														---- you have "end" forget
    end

    local target = TargetSelector:GetTarget(self.E.Range, 1)
    if target == nil then return end
    local posBehind = myHero.pos:Extended(target.pos, target.distance + 100)
    if Ready(_E) and target and IsValid(target) then
        if self.shadowMenu.combo.E:Value() then
            self:CastE(target)
            --self:CastSpell(HK_Etarget)
        end
    end



    
    local distance = target.pos:DistanceTo(myHero.pos) 
    local target = TargetSelector:GetTarget(self.Q.Range, 1)
    if target == nil then return end
    if Ready(_Q) and target and IsValid(target)then
        if self.shadowMenu.combo.Q:Value() then
            if distance > 615 and not self:HasSecondQ() or (distance < 615 and self:HasSecondQ()) then
                Control.CastSpell(HK_Q)
            end
        end    
    end 
end

function Jinx:junglekillsteal()
    if self.shadowMenu.junglekillsteal.W:Value() then 
        for i = 1, Game.MinionCount() do
            local obj = Game.Minion(i)
            if obj.team ~= myHero.team then
                if obj ~= nil and obj.valid and obj.visible and not obj.dead then
                    local wdmg = getdmg("W", obj, myHero, 1)
                    if Ready(_W) and self.shadowMenu.junglekillsteal.W:Value() and obj and obj.team == 300 and obj.valid and obj.visible and not obj.dead and (obj.pos:DistanceTo(myHero.pos) < self.W.Range and obj.health < wdmg) then
                        Control.CastSpell(HK_W, obj);
                    end
                end
            end
        end
    end
end

function Jinx:HasSecondQ()
    return Jinx:GotBuff(myHero, "JinxQ") > 0
end

function Jinx:GotBuff(unit, buffname)
    for i = 0, unit.buffCount do
        local buff = unit:GetBuff(i)
        if buff and buff.name == buffname and buff.count > 0 then return buff.count end
    end
    return 0
end

function Jinx:CastW(target)
    if Ready(_W) and lastW + 350 < GetTickCount() and orbwalker:CanMove() then
        local Pred = GamsteronPrediction:GetPrediction(target, self.W, myHero)
        if Pred.Hitchance >= _G.HITCHANCE_NORMAL then
            Control.CastSpell(HK_W, Pred.CastPosition)
            lastW = GetTickCount()
        end
    end
end

function Jinx:CastE(target)
    if Ready(_E) and lastE + 350 < GetTickCount() and orbwalker:CanMove() then
        local Pred = GamsteronPrediction:GetPrediction(target, self.E, myHero)
        if Pred.Hitchance >= _G.HITCHANCE_NORMAL then
            Control.CastSpell(HK_E, Pred.CastPosition)
            lastE = GetTickCount()
        end
    end
end

function Jinx:CastR(target)
    if Ready(_R) and lastR + 350 < GetTickCount() and orbwalker:CanMove() then
        local Pred = GamsteronPrediction:GetPrediction(target, self.R, myHero)
        if Pred.Hitchance >= _G.HITCHANCE_NORMAL then
            Control.CastSpell(HK_R, Pred.CastPosition)
            lastR = GetTickCount()
        end
    end
end
