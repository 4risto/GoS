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
    
    local Version = 0.16
    
    local Files = {
        Lua = {
            Path = SCRIPT_PATH,
            Name = "ShadowAIO.lua",
            Url = "https://raw.githubusercontent.com/ShadowFusion/MJGA/master/ShadowAIO.lua"
        },
        Version = {
            Path = SCRIPT_PATH,
            Name = "ShadowAIO.version",
            Url = "https://raw.githubusercontent.com/ShadowFusion/MJGA/master/ShadowAIO.version"    -- check if Raw Adress correct pls.. after you have create the version file on Github
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
    ["Urgot"] = true, 
    ["LeeSin"] = true, 
    ["MasterYi"] = true, 
    ["Warwick"] = true, 
    ["Hecarim"] = true, 
    ["Jax"] = true,
    ["Amumu"] = true,
    ["Cassiopeia"] = true,
    ["Nocturne"] = true,
    ["DrMundo"] = true,
    ["MonkeyKing"] = true,
    ["Gragas"] = true,
    ["Twitch"] = true,
    ["JarvanIV"] = true,
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
      
    require('DamageLib')
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


if myHero.charName == "Urgot" then
class "Urgot"
function Urgot:__init()
    
    self.Q = {Type = _G.SPELLTYPE_CIRCLE, Delay = 0.25, Radius = 60, Range = 800, Speed = 1400, Collision = true, MaxCollision = 0, CollisionTypes = {_G.COLLISION_MINION, _G.COLLISION_ENEMYHERO}}
    self.W = {Type = _G.SPELLTYPE_CIRCLE, Delay = 0.25, Radius = 800, Range = 800, Speed = 1400, Collision = true, MaxCollision = 0, CollisionTypes = {_G.COLLISION_MINION, _G.COLLISION_ENEMYHERO}}
    self.E = {Type = _G.SPELLTYPE_LINE, Delay = 0.25, Radius = 0, Range = 475, Speed = 0, Collision = true, MaxCollision = 1, CollisionTypes = {_G.COLLISION_MINION, _G.COLLISION_ENEMYHERO}}
    self.R = {Type = _G.SPELLTYPE_LINE, Delay = 0.50, Radius = 0, Range = 2500, Speed = 3200, Collision = true, MaxCollision = 1, CollisionTypes = {_G.COLLISION_MINION, _G.COLLISION_ENEMYHERO}}
    
    
    OnAllyHeroLoad(function(hero)
        Allys[hero.networkID] = hero
    end)
    
    OnEnemyHeroLoad(function(hero)
        Enemys[hero.networkID] = hero
    end)
    
    Callback.Add("Tick", function() self:Tick() end)
    Callback.Add("Draw", function() self:Draw() end)
    
    orbwalker:OnPreMovement(
        function(args)
            if lastMove + 180 > GetTickCount() then
                args.Process = false
            else
                args.Process = true
                lastMove = GetTickCount()
            end
        end
    )
end

function Urgot:LoadMenu()
    self.shadowMenu = MenuElement({type = MENU, id = "shadowUrgot", name = "Shadow Urgot"})
    self.shadowMenu:MenuElement({type = MENU, id = "combo", name = "Combo"})
    self.shadowMenu.combo:MenuElement({id = "Q", name = "Use Q in Combo", value = true})
    self.shadowMenu.combo:MenuElement({id = "W", name = "Use W in Combo(Recomended Disabled)", value = false})
    self.shadowMenu.combo:MenuElement({id = "E", name = "Use E in  Combo", value = true})
    self.shadowMenu:MenuElement({type = MENU, id = "jungleclear", name = "Jungle Clear"})
    self.shadowMenu.jungleclear:MenuElement({id = "UseQ", name = "Use Q in Jungle Clear", value = true})
    self.shadowMenu.jungleclear:MenuElement({id = "UseE", name = "Use E in Jungle Clear", value = true})
    self.shadowMenu:MenuElement({type = MENU, id = "autor", name = "Auto R"})
    self.shadowMenu.autor:MenuElement({id = "AutoR", name = "Auto R", value = true})
    --self.shadowMenu:MenuElement({type = MENU, id = "jungleclear", name = "Jungle Clear"})
end

function Urgot:Draw()
    
end

function Urgot:Tick()
    if myHero.dead or Game.IsChatOpen() or (ExtLibEvade and ExtLibEvade.Evading == true) then
        return
    end
    self:AutoR()
    if orbwalker.Modes[0] then
        self:Combo()
    elseif orbwalker.Modes[3] then
        self:jungleclear()
    end
end

function Urgot:AutoR()
    local target = TargetSelector:GetTarget(self.R.Range, 1)
    if Ready(_R) and target and IsValid(target) and (target.health <= target.maxHealth / 4) and self.shadowMenu.autor.AutoR:Value() then
        local Pred = GamsteronPrediction:GetPrediction(target, self.R, myHero)
        --print(Pred.Hitchance)
            --Control.CastSpell(HK_Q, target)
            self:CastR(target)
    end
end


function Urgot:Combo()
    local QPred = GamsteronPrediction:GetPrediction(target, self.Q, myHero)
    local target = TargetSelector:GetTarget(self.Q.Range, 1)
    if Ready(_Q) and target and IsValid(target) then
        if self.shadowMenu.combo.Q:Value() then
            --Control.CastSpell(HK_Q, target)
            self:CastQ(target)
        end
    end

    local Wactive = false;
    if myHero:GetSpellData(_W).name == 'UrgotW2' then
    Wactive = true
    else
    Wactive = false
    end
    local target = TargetSelector:GetTarget(self.W.Range, 1)
    if Ready(_W) and target and IsValid(target) and Wactive == false then
        if self.shadowMenu.combo.W:Value() then
            Control.KeyDown(HK_W)
            Control.KeyUp(HK_W)
        end
    end
    
    local target = TargetSelector:GetTarget(self.E.Range - 100, 1)
    if Ready(_E) and target and IsValid(target) then
        if self.shadowMenu.combo.E:Value() then
            Control.CastSpell(HK_E, target)
            --self:CastSpell(HK_Etarget)
        end
    end

end

function Urgot:jungleclear()
if self.shadowMenu.jungleclear.UseQ:Value() then 
    for i = 1, Game.MinionCount() do
        local obj = Game.Minion(i)
        if obj.team ~= myHero.team then
            if obj ~= nil and obj.valid and obj.visible and not obj.dead then
                if Ready(_Q) and self.shadowMenu.jungleclear.UseQ:Value() and obj and obj.team == 300 and obj.valid and obj.visible and not obj.dead and (obj.pos:DistanceTo(myHero.pos) < 800) then
                    Control.CastSpell(HK_Q, obj);
                end
            end
        end
        if Ready(_E) and self.shadowMenu.jungleclear.UseE:Value() and obj and obj.team == 300 and obj.valid and obj.visible and not obj.dead and obj.pos:DistanceTo(myHero.pos) < 125 + myHero.boundingRadius then
            Control.CastSpell(HK_E, obj);
        end
    end
end
end

function Urgot:CastQ(target)
    if Ready(_Q) and lastQ + 350 < GetTickCount() and orbwalker:CanMove() then
        local Pred = GamsteronPrediction:GetPrediction(target, self.Q, myHero)
        if Pred.Hitchance >= _G.HITCHANCE_NORMAL then
            Control.CastSpell(HK_Q, Pred.CastPosition)
            lastQ = GetTickCount()
        end
    end
end

function Urgot:CastR(target)
    if Ready(_R) and lastR + 350 < GetTickCount() and orbwalker:CanMove() then
        local Pred = GamsteronPrediction:GetPrediction(target, self.R, myHero)
        if Pred.Hitchance >= _G.HITCHANCE_NORMAL then
            Control.CastSpell(HK_R, Pred.CastPosition)
            lastR = GetTickCount()
        end
    end
end
end
if myHero.charName == "LeeSin" then
    class "LeeSin"
function LeeSin:__init()
    
    self.Q = {_G.SPELLTYPE_LINE, Delay = 0.25, Radius = 65, Range = 1200, Speed = 1750, Collision = true, MaxCollision = 0, CollisionTypes = {_G.COLLISION_MINION, _G.COLLISION_YASUOWALL}}
    self.W = {Type = _G.SPELLTYPE_CIRCLE, Delay = 0.25, Radius = 800, Range = 700, Speed = 1400, Collision = true, MaxCollision = 0, CollisionTypes = {_G.COLLISION_MINION, _G.COLLISION_ENEMYHERO}}
    self.E = {Type = _G.SPELLTYPE_LINE, Delay = 0.25, Radius = 350, Range = 350, Speed = 0, Collision = true, MaxCollision = 1, CollisionTypes = {_G.COLLISION_MINION, _G.COLLISION_ENEMYHERO}}
    self.R = {Type = _G.SPELLTYPE_LINE, Delay = 0.50, Radius = 0, Range = 375, Speed = 3200, Collision = true, MaxCollision = 1, CollisionTypes = {_G.COLLISION_MINION, _G.COLLISION_ENEMYHERO}}
    
    
    OnAllyHeroLoad(function(hero)
        Allys[hero.networkID] = hero
    end)
    
    OnEnemyHeroLoad(function(hero)
        Enemys[hero.networkID] = hero
    end)
    
    Callback.Add("Tick", function() self:Tick() end)
    Callback.Add("Draw", function() self:Draw() end)
    
    orbwalker:OnPreMovement(
        function(args)
            if lastMove + 180 > GetTickCount() then
                args.Process = false
            else
                args.Process = true
                lastMove = GetTickCount()
            end
        end
    )
end

function LeeSin:LoadMenu()
    self.shadowMenuLee = MenuElement({type = MENU, id = "shadowLeeSin", name = "Shadow Lee"})
    self.shadowMenuLee:MenuElement({type = MENU, id = "combo", name = "Combo"})
    self.shadowMenuLee.combo:MenuElement({id = "Q", name = "Use Q in Combo", value = true})
    self.shadowMenuLee.combo:MenuElement({id = "E", name = "Use E in  Combo", value = true})
    self.shadowMenuLee:MenuElement({type = MENU, id = "jungleclear", name = "Jungle Clear"})
    self.shadowMenuLee.jungleclear:MenuElement({id = "UseQ", name = "Use Q in Jungle Clear", value = true})
    self.shadowMenuLee.jungleclear:MenuElement({id = "UseW", name = "Use W in Jungle Clear", value = true})
    self.shadowMenuLee.jungleclear:MenuElement({id = "UseE", name = "Use E in Jungle Clear", value = true})
    self.shadowMenuLee:MenuElement({type = MENU, id = "killsteal", name = "Kill Steal"})
    self.shadowMenuLee.killsteal:MenuElement({id = "AutoQ", name = "Auto Q", value = true})
    self.shadowMenuLee.killsteal:MenuElement({id = "AutoR", name = "Auto R", value = true})
    self.shadowMenuLee:MenuElement({type = MENU, id = "autow", name = "Auto W settings"})
    self.shadowMenuLee.autow:MenuElement({id = "autows", name = "Auto W yourself", value = true})
    self.shadowMenuLee.autow:MenuElement({id = "selfhealth", name = "Min health to auto w self", value = 30, min = 0, max = 100, identifier = "%"})
    self.shadowMenuLee.autow:MenuElement({id = "autowa", name = "Auto W ally", value = true})
    self.shadowMenuLee.autow:MenuElement({id = "allyhealth", name = "Min health to auto w ally", value = 30, min = 0, max = 100, identifier = "%"})
	self.shadowMenuLee:MenuElement({type = MENU, id = "Drawing", name = "Drawing Settings"})
	self.shadowMenuLee.Drawing:MenuElement({id = "DrawQ", name = "Draw [Q] Range", value = true})
	self.shadowMenuLee.Drawing:MenuElement({id = "DrawR", name = "Draw [R] Range", value = true})
	self.shadowMenuLee.Drawing:MenuElement({id = "DrawE", name = "Draw [E] Range", value = true})
    self.shadowMenuLee.Drawing:MenuElement({id = "DrawW", name = "Draw [W] Range", value = true})
end

function LeeSin:Draw()
    if myHero.dead then return end
	if self.shadowMenuLee.Drawing.DrawR:Value() and Ready(_R) then
    Draw.Circle(myHero, 375, 1, Draw.Color(255, 225, 255, 10))
	end                                                 
	if self.shadowMenuLee.Drawing.DrawQ:Value() and Ready(_Q) and myHero:GetSpellData(_Q).name == "BlindMonkQOne" then
    Draw.Circle(myHero, 1200, 1, Draw.Color(225, 225, 0, 10))
	end
	if self.shadowMenuLee.Drawing.DrawE:Value() and Ready(_E) and myHero:GetSpellData(_E).name == "BlindMonkEOne"  then
    Draw.Circle(myHero, 350, 1, Draw.Color(225, 225, 125, 10))
	end
	if self.shadowMenuLee.Drawing.DrawW:Value() and Ready(_W) then
    Draw.Circle(myHero, 700, 1, Draw.Color(225, 225, 125, 10))
	end
end

function LeeSin:Tick()
    if myHero.dead or Game.IsChatOpen() or (ExtLibEvade and ExtLibEvade.Evading == true) then
        return
    end
    self:killsteal()
    self:autow()
    if orbwalker.Modes[0] then
        self:Combo()
    elseif orbwalker.Modes[3] then
        self:jungleclear()
    end
end

function LeeSin:killsteal() 
    local target = TargetSelector:GetTarget(self.R.Range, 1)
    if target == nil then return end
        local rdmg = (({150, 375, 600})[myHero:GetSpellData(_R).level or 1] + (myHero.bonusDamage * 2))
        if Ready(_R) and target and IsValid(target) and (target.health <= rdmg) and self.shadowMenuLee.killsteal.AutoR:Value() then
            --Control.CastSpell(HK_Q, target)
            self:CastR(target)
        end
    target = TargetSelector:GetTarget(self.Q.Range, 1)
    if target ~= nil then
        local qdmg = (({55, 80, 105, 130, 155})[myHero:GetSpellData(_Q).level] + myHero.bonusDamage) * (2 - target.health / target.maxHealth)
        if Ready(_Q) and target and IsValid(target) and (target.health <= qdmg) and self.shadowMenuLee.killsteal.AutoQ:Value() then
            --Control.CastSpell(HK_Q, target)
            self:CastQ(target)
        end
    end
end

function LeeSin:Combo()
    local TargetSelector = _G.SDK.TargetSelector
    local pred = GamsteronPrediction:GetPrediction(target, self.Q, myHero)
    local qishit = myHero:GetSpellData(_Q).toggleState
    local target = TargetSelector:GetTarget(self.Q.Range, 1)
    if myHero:GetSpellData(_Q).name == BlindMonkQTwo and Ready(_Q) then
        Control.KeyDown(_Q)
    end
    if Ready(_Q) and target and IsValid(target) then
        if self.shadowMenuLee.combo.Q:Value() then
            --Control.CastSpell(HK_Q, target)
            self:CastQ(target)
        end
    end
    local target = TargetSelector:GetTarget(self.E.Range, 1)
    if Ready(_E) and target and IsValid(target) then
        if self.shadowMenuLee.combo.E:Value() then
            Control.KeyDown(HK_E)
            --self:CastSpell(HK_Etarget)
        end
    end
end

function LeeSin:jungleclear()
if self.shadowMenuLee.jungleclear.UseQ:Value() then 
    for i = 1, Game.MinionCount() do
        local obj = Game.Minion(i)
        if obj.team ~= myHero.team then
            if obj ~= nil and obj.valid and obj.visible and not obj.dead then
                if Ready(_Q) and self.shadowMenuLee.jungleclear.UseQ:Value() and obj and obj.team == 300 and obj.valid and obj.visible and not obj.dead and obj.pos:DistanceTo(myHero.pos) < 800 then
                    Control.CastSpell(HK_Q, obj);
                end
            end
        end
        if Ready(_W) and self.shadowMenuLee.jungleclear.UseW:Value() and obj and obj.team == 300 and obj.valid and obj.visible and not obj.dead and obj.pos:DistanceTo(myHero.pos) < 125 + myHero.boundingRadius then
            Control.CastSpell(HK_W);
        end
        if Ready(_E) and self.shadowMenuLee.jungleclear.UseE:Value() and obj and obj.team == 300 and obj.valid and obj.visible and not obj.dead and obj.pos:DistanceTo(myHero.pos) < 125 + myHero.boundingRadius then
            Control.CastSpell(HK_E);
        end
    end
end
end

function LeeSin:autow()
    local target = TargetSelector:GetTarget(800)     	
    if target == nil then return end	
        
        if self.shadowMenuLee.autow.autows:Value() and Ready(_W) then
            if myHero.health/myHero.maxHealth <= self.shadowMenuLee.autow.selfhealth:Value()/100 then
                Control.CastSpell(HK_W, myHero)
                if myHero:GetSpellData(_W).name == "BlindMonkWTwo" then
                    Control.CastSpell(HK_W)
                end
            end
            for i, ally in pairs(GetAllyHeroes()) do
                if self.shadowMenuLee.autow.autowa:Value() and IsValid(ally,1000) and myHero.pos:DistanceTo(ally.pos) <= 700 and ally.health/ally.maxHealth <= self.shadowMenuLee.autow.allyhealth:Value()/100 then
                    Control.CastSpell(HK_W, ally)
                    if HasBuff(ally, "blindmonkwoneshield") then
                        Control.CastSpell(HK_W)
                    end
                end
            end
        end
    end

function LeeSin:CastQ(target)
    if Ready(_Q) and lastQ + 350 < GetTickCount() and orbwalker:CanMove() then
        local Pred = GamsteronPrediction:GetPrediction(target, self.Q, myHero)
        if Pred.Hitchance >= _G.HITCHANCE_HIGH then
            Control.CastSpell(HK_Q, Pred.CastPosition)
            lastQ = GetTickCount()
        end
    end
end

function LeeSin:CastR(target)
    if Ready(_R) and lastR + 350 < GetTickCount() and orbwalker:CanMove() then
        local Pred = GamsteronPrediction:GetPrediction(target, self.Q, myHero)
        if Pred.Hitchance >= _G.HITCHANCE_HIGH then
            Control.CastSpell(HK_R, Pred.CastPosition)
            lastR = GetTickCount()
        end
    end
end
end

class "MasterYi"
function MasterYi:__init()
    
    self.Q = {_G.SPELLTYPE_CIRCLE, Delay = 0.225, Radius = 600, Range = 600, Speed = 1750, Collision = true, MaxCollision = 0, CollisionTypes = {_G.COLLISION_MINION, _G.COLLISION_YASUOWALL}}
    
    
    OnAllyHeroLoad(function(hero)
        Allys[hero.networkID] = hero
    end)
    
    OnEnemyHeroLoad(function(hero)
        Enemys[hero.networkID] = hero
    end)
    
    Callback.Add("Tick", function() self:Tick() end)
    Callback.Add("Draw", function() self:Draw() end)
    
    orbwalker:OnPreMovement(
        function(args)
            if lastMove + 180 > GetTickCount() then
                args.Process = false
            else
                args.Process = true
                lastMove = GetTickCount()
            end
        end
    )
end

function MasterYi:LoadMenu()
    self.shadowMenuYi = MenuElement({type = MENU, id = "shadowMasterYi", name = "Shadow Yi"})
    self.shadowMenuYi:MenuElement({type = MENU, id = "combo", name = "Combo"})
    self.shadowMenuYi.combo:MenuElement({id = "Q", name = "Use Q in Combo", value = true})
    self.shadowMenuYi.combo:MenuElement({id = "E", name = "Use E in  Combo", value = true})
    self.shadowMenuYi:MenuElement({type = MENU, id = "jungleclear", name = "Jungle Clear"})
    self.shadowMenuYi.jungleclear:MenuElement({id = "UseQ", name = "Use Q in Jungle Clear", value = true})
    self.shadowMenuYi.jungleclear:MenuElement({id = "UseW", name = "Use W in Jungle Clear", value = true})
    self.shadowMenuYi.jungleclear:MenuElement({id = "UseE", name = "Use E in Jungle Clear", value = true})
    self.shadowMenuYi:MenuElement({type = MENU, id = "autow", name = "Auto W settings"})
    self.shadowMenuYi.autow:MenuElement({id = "autow", name = "Auto W yourself", value = true})
    self.shadowMenuYi.autow:MenuElement({id = "selfhealth", name = "Min health to auto w", value = 30, min = 0, max = 100, identifier = "%"})
    self.shadowMenuYi:MenuElement({type = MENU, id = "DodgeSetting", name = "Ddoge Settings"})
    self.shadowMenuYi.DodgeSetting:MenuElement({id = "DodgeSpells", name = "Dodge Incoming spells with [Q]", value = true})
    self.shadowMenuYi.DodgeSetting:MenuElement({id = "Follow", name = "Use Q to follow dashes / blinks", value = true})
	self.shadowMenuYi:MenuElement({type = MENU, id = "Drawing", name = "Drawing Settings"})
	self.shadowMenuYi.Drawing:MenuElement({id = "DrawQ", name = "Draw [Q] Range", value = true})
end

function MasterYi:Draw()
    if myHero.dead then return end
end

function MasterYi:Tick()
    if myHero.dead or Game.IsChatOpen() or (ExtLibEvade and ExtLibEvade.Evading == true) then
        return
    end
    if orbwalker.Modes[0] then
        self:Combo()
    elseif orbwalker.Modes[3] then
        self:jungleclear()
    end
    self:autow()
    self:OnRecvSpell(target);
    if target then
        self:FollowDash(target);
    end
end

function MasterYi:Combo()
    local target = TargetSelector:GetTarget(self.Q.Range, 1)
    if Ready(_Q) and target and IsValid(target) then
        if self.shadowMenuYi.combo.Q:Value() then
            Control.CastSpell(HK_Q, target)
        end
    end
    if Ready(_E) and target and IsValid(target) then
        if self.shadowMenuYi.combo.E:Value() then
            Control.KeyDown(HK_E)
            --self:CastSpell(HK_Etarget)
        end
    end
end

function MasterYi:jungleclear()
if self.shadowMenuYi.jungleclear.UseQ:Value() then 
    for i = 1, Game.MinionCount() do
        local obj = Game.Minion(i)
        if obj.team ~= myHero.team then
            if obj ~= nil and obj.valid and obj.visible and not obj.dead then
                if Ready(_Q) and self.shadowMenuYi.jungleclear.UseQ:Value() and obj and obj.team == 300 and obj.valid and obj.visible and not obj.dead and obj.pos:DistanceTo(myHero.pos) < 800 then
                    Control.CastSpell(HK_Q, obj);
                end
            end
        end
        if Ready(_E) and self.shadowMenuYi.jungleclear.UseE:Value() and obj and obj.team == 300 and obj.valid and obj.visible and not obj.dead and obj.pos:DistanceTo(myHero.pos) < 125 + myHero.boundingRadius then
            Control.CastSpell(HK_E);
        end
    end
end
end

function MasterYi:autow()   	
        if self.shadowMenuYi.autow.autow:Value() and Ready(_W) then
            if myHero.health/myHero.maxHealth <= self.shadowMenuYi.autow.selfhealth:Value()/100 then
                Control.CastSpell(HK_W, myHero)
        end
    end
end

function MasterYi:CastDodge()
    local target = nil
	local bestchamp = { hero = nil, health = math.huge, maxHealth = math.huge }
	if Game.HeroCount() > 0 then
		for i = 1, Game.HeroCount() do
            local hero = Game.Hero(i)
			if hero.IsEnemy and hero.visible and myHero.pos:DistanceTo(hero.pos) <= 600 then
				if hero.maxHealth < bestchamp.maxHealth then
					bestchamp.hero = hero
					bestchamp.health = hero.health
					bestchamp.maxHealth = hero.maxHealth
				end
			end
		end
		target = bestchamp.hero
	end
	if target then
		local enemiesInRange = 0
		for i = 1, Game.HeroCount() do
            local hero = Game.Hero(i)
			if hero.IsEnemy and hero.team ~= target.team and target.pos:DistanceTo(hero.pos) < 1000 then
				enemiesInRange = enemiesInRange + 1
			end
		end
		if enemiesInRange > 1 then
            for i = 1, Game.MinionCount() do
                local obj = Game.Minion(i)
                if obj.team ~= myHero.team then
					if obj and myHero.pos:DistanceTo(obj.pos) < 600 then
						target = obj
						break
					end
				end
			end
		end
	else
		for i = 1, Game.MinionCount() do
            local obj = Game.Minion(i)
            if obj.team ~= myHero.team then
				if obj and myHero.pos:DistanceTo(obj.pos) < 600 then
					target = obj
					break
				end
			end
		end
	end
	if target then
		if self.shadowMenuYi.DodgeSetting.DodgeSpells:Value() then
            Control.CastSpell(HK_Q, target);
		end
	end
end

function MasterYi:Dodge()
    local spell = myHero.activeSpell
	if Ready(_Q) and spell and spell.owner and spell.owner.team == myHero.team and not myHero.attackData.state == STATE_ATTACK then
		if spell.target and spell.target == myHero then
			self:CastDodge()
		else
			if myHero.pos:DistanceTo(spell.endPos) <= (150 + myHero.boundingRadius) / 2 then
				self:CastDodge()
			end
		end
	end
end

function MasterYi:FollowDash(target)
    if self.shadowMenuYi.DodgeSetting.Follow:Value() and target and target.visible and not target.dead and target.pathing and target.pathing.hasMovePath and target.pathing.isDashing then
        Control.CastSpell(HK_Q, target);
	end
end



function MasterYi:OnRecvSpell(target)
    self:Dodge();
end

function MasterYi:CastQ(target)
    if Ready(_Q) and lastQ + 350 < GetTickCount() and orbwalker:CanMove() then
        local Pred = GamsteronPrediction:GetPrediction(target, self.Q, myHero)
        if Pred.Hitchance >= _G.HITCHANCE_HIGH then
            Control.CastSpell(HK_Q, Pred.CastPosition)
            lastQ = GetTickCount()
        end
    end
end

class "Warwick"
function Warwick:__init()
    
    self.Q = {_G.SPELLTYPE_CIRCLE, Delay = 0.225, Radius = 600, Range = 600, Speed = 1750, Collision = true, MaxCollision = 0, CollisionTypes = {_G.COLLISION_MINION, _G.COLLISION_YASUOWALL}}
    self.R = {_G.SPELLTYPE_CIRCLE, Delay = 0.1, Radius = 55, Range = 2.5 * myHero.ms, Speed = 1800, Collision = false, MaxCollision = 0, CollisionTypes = {_G.COLLISION_MINION, _G.COLLISION_YASUOWALL}}
    
    
    OnAllyHeroLoad(function(hero)
        Allys[hero.networkID] = hero
    end)
    
    OnEnemyHeroLoad(function(hero)
        Enemys[hero.networkID] = hero
    end)
    
    Callback.Add("Tick", function() self:Tick() end)
    Callback.Add("Draw", function() self:Draw() end)
    
    orbwalker:OnPreMovement(
        function(args)
            if lastMove + 180 > GetTickCount() then
                args.Process = false
            else
                args.Process = true
                lastMove = GetTickCount()
            end
        end
    )
end

function Warwick:LoadMenu()
    self.shadowMenuWick = MenuElement({type = MENU, id = "shadowWarwick", name = "Shadow Warwick"})
    self.shadowMenuWick:MenuElement({type = MENU, id = "combo", name = "Combo"})
    self.shadowMenuWick.combo:MenuElement({id = "Q", name = "Use Q in Combo", value = true})
    self.shadowMenuWick.combo:MenuElement({id = "E", name = "Use E in  Combo", value = true})
    self.shadowMenuWick.combo:MenuElement({id = "R", name = "Use R in  Combo", value = true})
    self.shadowMenuWick:MenuElement({type = MENU, id = "jungleclear", name = "Jungle Clear"})
    self.shadowMenuWick.jungleclear:MenuElement({id = "UseQ", name = "Use Q in Jungle Clear", value = true})
    self.shadowMenuWick.jungleclear:MenuElement({id = "UseW", name = "Use W in Jungle Clear", value = true})
    self.shadowMenuWick.jungleclear:MenuElement({id = "UseE", name = "Use E in Jungle Clear", value = true})
    self.shadowMenuWick:MenuElement({type = MENU, id = "autoe", name = "Auto E settings"})
    self.shadowMenuWick.autoe:MenuElement({id = "autoe", name = "Auto E yourself", value = true})
    self.shadowMenuWick.autoe:MenuElement({id = "selfhealth", name = "Min health to auto E", value = 30, min = 0, max = 100, identifier = "%"})
    self.shadowMenuWick:MenuElement({type = MENU, id = "DodgeSetting", name = "Ddoge Settings"})
    self.shadowMenuWick.DodgeSetting:MenuElement({id = "DodgeSpells", name = "Dodge Incoming spells with [Q]", value = true})
    self.shadowMenuWick.DodgeSetting:MenuElement({id = "Follow", name = "Use Q to follow dashes / blinks", value = true})
	self.shadowMenuWick:MenuElement({type = MENU, id = "Drawing", name = "Drawing Settings"})
	self.shadowMenuWick.Drawing:MenuElement({id = "DrawQ", name = "Draw [Q] Range", value = true})
end

function Warwick:Draw()
    if myHero.dead then return end
end

function Warwick:Tick()
    if myHero.dead or Game.IsChatOpen() or (ExtLibEvade and ExtLibEvade.Evading == true) then
        return
    end
    if orbwalker.Modes[0] then
        self:Combo()
    elseif orbwalker.Modes[3] then
        self:jungleclear()
    end
    self:autoe()
    self:OnRecvSpell(target);
    if target then
        self:FollowDash(target);
    end
end

function Warwick:Combo()
    local target = TargetSelector:GetTarget(self.Q.Range, 1)
    if Ready(_Q) and target and IsValid(target) then
        if self.shadowMenuWick.combo.Q:Value() then
            Control.CastSpell(HK_Q, target)
        end
    end
    if Ready(_E) and target and IsValid(target) then
        if self.shadowMenuWick.combo.E:Value() then
            Control.KeyDown(HK_E)
            --self:CastSpell(HK_Etarget)
        end
    end
    local target = TargetSelector:GetTarget(self.R.Range, 1)
    local range = 2.5 * myHero.ms
    if Ready(_R) and target and IsValid(target)then
        if self.shadowMenuWick.combo.R:Value() and myHero.pos:DistanceTo(target.pos) <= self.R.Range then
            --print("Value is true")
            self:CastR(target)
        end
    end
end

function Warwick:jungleclear()
if self.shadowMenuWick.jungleclear.UseQ:Value() then 
    for i = 1, Game.MinionCount() do
        local obj = Game.Minion(i)
        if obj.team ~= myHero.team then
            if obj ~= nil and obj.valid and obj.visible and not obj.dead then
                if Ready(_Q) and self.shadowMenuWick.jungleclear.UseQ:Value() and obj and obj.team == 300 and obj.valid and obj.visible and not obj.dead and obj.pos:DistanceTo(myHero.pos) < 800 then
                    Control.CastSpell(HK_Q, obj);
                end
            end
        end
        if Ready(_E) and self.shadowMenuWick.jungleclear.UseE:Value() and obj and obj.team == 300 and obj.valid and obj.visible and not obj.dead and obj.pos:DistanceTo(myHero.pos) < 125 + myHero.boundingRadius then
            Control.CastSpell(HK_E);
        end
    end
end
end

function Warwick:autoe()   	
        if self.shadowMenuWick.autoe.autoe:Value() and Ready(_E) then
            if myHero.health/myHero.maxHealth <= self.shadowMenuWick.autoe.selfhealth:Value()/100 then
                Control.CastSpell(HK_E)
        end
    end
end

function Warwick:CastDodge()
    local target = nil
	local bestchamp = { hero = nil, health = math.huge, maxHealth = math.huge }
	if Game.HeroCount() > 0 then
		for i = 1, Game.HeroCount() do
            local hero = Game.Hero(i)
			if hero.IsEnemy and hero.visible and myHero.pos:DistanceTo(hero.pos) <= 600 then
				if hero.maxHealth < bestchamp.maxHealth then
					bestchamp.hero = hero
					bestchamp.health = hero.health
					bestchamp.maxHealth = hero.maxHealth
				end
			end
		end
		target = bestchamp.hero
	end
	if target then
		local enemiesInRange = 0
		for i = 1, Game.HeroCount() do
            local hero = Game.Hero(i)
			if hero.IsEnemy and hero.team ~= target.team and target.pos:DistanceTo(hero.pos) < 1000 then
				enemiesInRange = enemiesInRange + 1
			end
		end
		if enemiesInRange > 1 then
            for i = 1, Game.MinionCount() do
                local obj = Game.Minion(i)
                if obj.team ~= myHero.team then
					if obj and myHero.pos:DistanceTo(obj.pos) < 600 then
						target = obj
						break
					end
				end
			end
		end
	else
		for i = 1, Game.MinionCount() do
            local obj = Game.Minion(i)
            if obj.team ~= myHero.team then
				if obj and myHero.pos:DistanceTo(obj.pos) < 600 then
					target = obj
					break
				end
			end
		end
	end
	if target then
		if self.shadowMenuWick.DodgeSetting.DodgeSpells:Value() then
            Control.KeyDown(HK_Q, target);
		end
	end
end

function Warwick:Dodge()
    local spell = myHero.activeSpell
	if Ready(_Q) and spell and spell.owner and spell.owner.team == myHero.team and not myHero.attackData.state == STATE_ATTACK then
		if spell.target and spell.target == myHero then
			self:CastDodge()
		else
			if myHero.pos:DistanceTo(spell.endPos) <= (150 + myHero.boundingRadius) / 2 then
				self:CastDodge()
			end
		end
	end
end

function Warwick:FollowDash(target)
    if self.shadowMenuWick.DodgeSetting.Follow:Value() and target and target.visible and not target.dead and target.pathing and target.pathing.hasMovePath and target.pathing.isDashing then
        Control.CastSpell(HK_Q, target);
	end
end



function Warwick:OnRecvSpell(target)
    self:Dodge();
end

function Warwick:CastR(target)
    if Ready(_R) and lastR + 350 < GetTickCount() and orbwalker:CanMove() then
        local Pred = GamsteronPrediction:GetPrediction(target, self.R, myHero)
        if Pred.Hitchance >= _G.HITCHANCE_HIGH then
            Control.CastSpell(HK_R, Pred.CastPosition)
            lastR = GetTickCount()
        end
    end
end

class "Hecarim"
function Hecarim:__init()
    
    self.Q = {_G.SPELLTYPE_CIRCLE, Delay = 0.225, Radius = 350, Range = 350, Speed = 1750, Collision = true, MaxCollision = 0, CollisionTypes = {_G.COLLISION_MINION, _G.COLLISION_YASUOWALL}}
    self.W = {_G.SPELLTYPE_CIRCLE, Delay = 0.1, Radius = 575, Range = 575, Speed = 1800, Collision = false, MaxCollision = 0, CollisionTypes = {_G.COLLISION_MINION, _G.COLLISION_YASUOWALL}}
    self.R = {_G.SPELLTYPE_CIRCLE, Delay = 0.1, Radius = 1000, Range = 1000, Speed = 1800, Collision = false, MaxCollision = 0, CollisionTypes = {_G.COLLISION_MINION, _G.COLLISION_YASUOWALL}}
    
    
    OnAllyHeroLoad(function(hero)
        Allys[hero.networkID] = hero
    end)
    
    OnEnemyHeroLoad(function(hero)
        Enemys[hero.networkID] = hero
    end)
    
    Callback.Add("Tick", function() self:Tick() end)
    Callback.Add("Draw", function() self:Draw() end)
    
    orbwalker:OnPreMovement(
        function(args)
            if lastMove + 180 > GetTickCount() then
                args.Process = false
            else
                args.Process = true
                lastMove = GetTickCount()
            end
        end
    )
end

function Hecarim:LoadMenu()
    self.shadowMenuHecarim = MenuElement({type = MENU, id = "shadowHecarim", name = "Shadow Hecarim"})
    self.shadowMenuHecarim:MenuElement({type = MENU, id = "combo", name = "Combo"})
    self.shadowMenuHecarim.combo:MenuElement({id = "Q", name = "Use Q in Combo", value = true})
    self.shadowMenuHecarim.combo:MenuElement({id = "E", name = "Use E in  Combo", value = true})
    self.shadowMenuHecarim.combo:MenuElement({id = "W", name = "Use W in  Combo", value = true})
    self.shadowMenuHecarim.combo:MenuElement({id = "R", name = "Use R in  Combo", value = true})
    self.shadowMenuHecarim:MenuElement({type = MENU, id = "jungleclear", name = "Jungle Clear"})
    self.shadowMenuHecarim.jungleclear:MenuElement({id = "UseQ", name = "Use Q in Jungle Clear", value = true})
    self.shadowMenuHecarim.jungleclear:MenuElement({id = "UseW", name = "Use W in Jungle Clear", value = true})
end

function Hecarim:Draw()
    if myHero.dead then return end
end

function Hecarim:Tick()
    if myHero.dead or Game.IsChatOpen() or (ExtLibEvade and ExtLibEvade.Evading == true) then
        return
    end
    if orbwalker.Modes[0] then
        self:Combo()
    elseif orbwalker.Modes[3] then
        self:jungleclear()
    end
end

function Hecarim:Combo()
    local target = TargetSelector:GetTarget(self.Q.Range, 1)
    if Ready(_Q) and target and IsValid(target) then
        if self.shadowMenuHecarim.combo.Q:Value() then
            Control.CastSpell(HK_Q, target)
        end
    end
    if Ready(_E) and target and IsValid(target) then
        if self.shadowMenuHecarim.combo.E:Value() then
            Control.KeyDown(HK_E)
            --self:CastSpell(HK_Etarget)
        end
    end
    if Ready(_W) and target and IsValid(target) then
        if self.shadowMenuHecarim.combo.W:Value() then
            Control.KeyDown(HK_W)
            Control.KeyUp(HK_W)
            --self:CastSpell(HK_Etarget)
        end
    end
    local target = TargetSelector:GetTarget(self.R.Range, 1)
    if Ready(_R) and target and IsValid(target)then
        if self.shadowMenuHecarim.combo.R:Value() then
            --print("Value is true")
            self:CastR(target)
        end
    end
end

function Hecarim:jungleclear()
if self.shadowMenuHecarim.jungleclear.UseQ:Value() then 
    for i = 1, Game.MinionCount() do
        local obj = Game.Minion(i)
        if obj.team ~= myHero.team then
            if obj ~= nil and obj.valid and obj.visible and not obj.dead then
                if Ready(_Q) and self.shadowMenuHecarim.jungleclear.UseQ:Value() and obj and obj.team == 300 and obj.valid and obj.visible and not obj.dead and obj.pos:DistanceTo(myHero.pos) < 800 then
                    Control.CastSpell(HK_Q, obj);
                end
            end
        end
        if Ready(_W) and self.shadowMenuHecarim.jungleclear.UseW:Value() and obj and obj.team == 300 and obj.valid and obj.visible and not obj.dead and obj.pos:DistanceTo(myHero.pos) < 125 + myHero.boundingRadius then
            Control.KeyDown(HK_W);
        end
    end
end
end

function Hecarim:CastR(target)
    if Ready(_R) and lastR + 350 < GetTickCount() and orbwalker:CanMove() then
        local Pred = GamsteronPrediction:GetPrediction(target, self.R, myHero)
        if Pred.Hitchance >= _G.HITCHANCE_HIGH then
            Control.CastSpell(HK_R, Pred.CastPosition)
            lastR = GetTickCount()
        end
    end
end

class "Jax"
function Jax:__init()
    
    self.Q = {_G.SPELLTYPE_CIRCLE, Delay = 0.225, Radius = 700, Range = 700, Speed = 1750, Collision = true, MaxCollision = 0, CollisionTypes = {_G.COLLISION_MINION, _G.COLLISION_YASUOWALL}}
    self.W = {_G.SPELLTYPE_CIRCLE, Delay = 0.1, Radius = myHero.range, Range = myHero.range, Speed = 1800, Collision = false, MaxCollision = 0, CollisionTypes = {_G.COLLISION_MINION, _G.COLLISION_YASUOWALL}}
    self.E = {_G.SPELLTYPE_CIRCLE, Delay = 0.1, Radius = 300, Range = 300, Speed = 1800, Collision = false, MaxCollision = 0, CollisionTypes = {_G.COLLISION_MINION, _G.COLLISION_YASUOWALL}}
    
    
    OnAllyHeroLoad(function(hero)
        Allys[hero.networkID] = hero
    end)
    
    OnEnemyHeroLoad(function(hero)
        Enemys[hero.networkID] = hero
    end)
    
    Callback.Add("Tick", function() self:Tick() end)
    Callback.Add("Draw", function() self:Draw() end)
    
    orbwalker:OnPreMovement(
        function(args)
            if lastMove + 180 > GetTickCount() then
                args.Process = false
            else
                args.Process = true
                lastMove = GetTickCount()
            end
        end
    )
end

function Jax:LoadMenu()
    self.shadowMenuJax = MenuElement({type = MENU, id = "shadowJax", name = "Shadow Jax"})
    self.shadowMenuJax:MenuElement({type = MENU, id = "combo", name = "Combo"})
    self.shadowMenuJax.combo:MenuElement({id = "Q", name = "Use Q in Combo", value = true})
    self.shadowMenuJax.combo:MenuElement({id = "E", name = "Use E in  Combo", value = true})
    self.shadowMenuJax.combo:MenuElement({id = "W", name = "Use W in  Combo", value = true})
    self.shadowMenuJax:MenuElement({type = MENU, id = "jungleclear", name = "Jungle Clear"})
    self.shadowMenuJax.jungleclear:MenuElement({id = "UseQ", name = "Use Q in Jungle Clear", value = true})
    self.shadowMenuJax.jungleclear:MenuElement({id = "UseW", name = "Use W in Jungle Clear", value = true})
    self.shadowMenuJax.jungleclear:MenuElement({id = "UseE", name = "Use E in Jungle Clear", value = true})
    self.shadowMenuJax:MenuElement({type = MENU, id = "autor", name = "Auto R settings"})
    self.shadowMenuJax.autor:MenuElement({id = "autor", name = "Auto R yourself", value = true})
    self.shadowMenuJax.autor:MenuElement({id = "selfhealth", name = "Min health to auto E", value = 30, min = 0, max = 100, identifier = "%"})
end

function Jax:Draw()
    if myHero.dead then return end
end

function Jax:Tick()
    if myHero.dead or Game.IsChatOpen() or (ExtLibEvade and ExtLibEvade.Evading == true) then
        return
    end
    if orbwalker.Modes[0] then
        self:Combo()
    elseif orbwalker.Modes[3] then
        self:jungleclear()
    end
end

function Jax:Combo()
    local target = TargetSelector:GetTarget(self.Q.Range, 1)
    if Ready(_Q) and target and IsValid(target) then
        if self.shadowMenuJax.combo.Q:Value() then
            Control.CastSpell(HK_Q, target)
        end
    end
    local target = TargetSelector:GetTarget(self.E.Range, 1)
    if Ready(_E) and target and IsValid(target) then
        if self.shadowMenuJax.combo.E:Value() then
            Control.KeyDown(HK_E)
            --self:CastSpell(HK_Etarget)
        end
    end
    local target = TargetSelector:GetTarget(self.W.Range, 1)
    if Ready(_W) and target and IsValid(target)then
        if self.shadowMenuJax.combo.W:Value() then
            --print("Value is true")
            Control.KeyDown(HK_W)
        end
    end
end

function Jax:jungleclear()
if self.shadowMenuJax.jungleclear.UseQ:Value() then 
    for i = 1, Game.MinionCount() do
        local obj = Game.Minion(i)
        if obj.team ~= myHero.team then
            if obj ~= nil and obj.valid and obj.visible and not obj.dead then
                if Ready(_Q) and self.shadowMenuJax.jungleclear.UseQ:Value() and obj and obj.team == 300 and obj.valid and obj.visible and not obj.dead and obj.pos:DistanceTo(myHero.pos) < 800 then
                    Control.CastSpell(HK_Q, obj);
                end
            end
        end
        if Ready(_E) and self.shadowMenuJax.jungleclear.UseE:Value() and obj and obj.team == 300 and obj.valid and obj.visible and not obj.dead and obj.pos:DistanceTo(myHero.pos) < 125 + myHero.boundingRadius then
            Control.CastSpell(HK_E);
        end
        if Ready(_W) and self.shadowMenuJax.jungleclear.UseE:Value() and obj and obj.team == 300 and obj.valid and obj.visible and not obj.dead and obj.pos:DistanceTo(myHero.pos) < 125 + myHero.boundingRadius then
            Control.CastSpell(HK_W);
        end
    end
end
end

function Jax:autor()   	
    if self.shadowMenuJax.autor.autor:Value() and Ready(_R) then
        if myHero.health/myHero.maxHealth <= self.shadowMenuJax.autor.selfhealth:Value()/100 then
            Control.KeyDown(HK_R)
    end
end
end

class "Amumu"
function Amumu:__init()
    
    self.Q = {_G.SPELLTYPE_LINE, Delay = 0.225, Radius = 1100, Range = 1100, Speed = 2000, Collision = true, MaxCollision = 0, CollisionTypes = {_G.COLLISION_MINION, _G.COLLISION_YASUOWALL}}
    self.R = {_G.SPELLTYPE_CIRCLE, Delay = 0.1, Radius = 550, Range = 550, Speed = 2000, Collision = false, MaxCollision = 1, CollisionTypes = {_G.COLLISION_ENEMY, _G.COLLISION_YASUOWALL}}
    self.E = {_G.SPELLTYPE_CIRCLE, Delay = 0.1, Radius = 350, Range = 350, Speed = 2000, Collision = false, MaxCollision = 1, CollisionTypes = {_G.COLLISION_ENEMY, _G.COLLISION_YASUOWALL}}
    self.W = {_G.SPELLTYPE_CIRCLE, Delay = 0.1, Radius = 300, Range = 300, Speed = 2000, Collision = false, MaxCollision = 1, CollisionTypes = {_G.COLLISION_ENEMY, _G.COLLISION_YASUOWALL}}

    
    OnAllyHeroLoad(function(hero)
        Allys[hero.networkID] = hero
    end)
    
    OnEnemyHeroLoad(function(hero)
        Enemys[hero.networkID] = hero
    end)
    
    Callback.Add("Tick", function() self:Tick() end)
    Callback.Add("Draw", function() self:Draw() end)
    
    orbwalker:OnPreMovement(
        function(args)
            if lastMove + 180 > GetTickCount() then
                args.Process = false
            else
                args.Process = true
                lastMove = GetTickCount()
            end
        end
    )
end

function Amumu:LoadMenu()
    self.shadowMenuAmumu = MenuElement({type = MENU, id = "shadowAmumu", name = "Shadow Amumu"})
    self.shadowMenuAmumu:MenuElement({type = MENU, id = "combo", name = "Combo"})
    self.shadowMenuAmumu.combo:MenuElement({id = "Q", name = "Use Q in Combo", value = true})
    self.shadowMenuAmumu.combo:MenuElement({id = "E", name = "Use E in  Combo", value = true})
    self.shadowMenuAmumu.combo:MenuElement({id = "W", name = "Use W in  Combo", value = true})
    self.shadowMenuAmumu:MenuElement({type = MENU, id = "jungleclear", name = "Jungle Clear"})
    self.shadowMenuAmumu.jungleclear:MenuElement({id = "UseQ", name = "Use Q in Jungle Clear", value = true})
    self.shadowMenuAmumu.jungleclear:MenuElement({id = "UseW", name = "Use W in Jungle Clear", value = true})
    self.shadowMenuAmumu.jungleclear:MenuElement({id = "wmanajungle", name = "Stop using W in clear at what %", value = 30, min = 0, max = 100, identifier = "%"})
    self.shadowMenuAmumu.jungleclear:MenuElement({id = "UseE", name = "Use E in Jungle Clear", value = true})
    self.shadowMenuAmumu:MenuElement({type = MENU, id = "autor", name = "Auto R settings"})
    self.shadowMenuAmumu.autor:MenuElement({id = "autor", name = "If can auto sun with [R] use automatically", value = true})
    self.shadowMenuAmumu.autor:MenuElement({id = "autormin", name = "How many eneimies inside [R] range to ult.", value = 2, min = 1, max = 4, step = 1}) 
    self.shadowMenuAmumu:MenuElement({type = MENU, id = "killsteal", name = "Killsteal settings"})
    self.shadowMenuAmumu.killsteal:MenuElement({id = "useq", name = "If can kill target with [Q] use automatically", value = true})
    self.shadowMenuAmumu.killsteal:MenuElement({id = "usee", name = "If can kill target with [E] use automatically", value = true})

end

function Amumu:Draw()
    if myHero.dead then return end
end

function Amumu:Tick()
    if myHero.dead or Game.IsChatOpen() or (ExtLibEvade and ExtLibEvade.Evading == true) then
        return
    end
    self:autor()
    if orbwalker.Modes[0] then
        self:Combo()
    elseif orbwalker.Modes[3] then
        self:jungleclear()
    end
end

function Amumu:Combo()
    local target = TargetSelector:GetTarget(self.Q.Range, 1)
    if Ready(_Q) and target and IsValid(target) then
        if self.shadowMenuAmumu.combo.Q:Value() then
            self:CastQ(target)
        end
    end
    local target = TargetSelector:GetTarget(self.E.Range, 1)
    if Ready(_E) and target and IsValid(target) then
        if self.shadowMenuAmumu.combo.E:Value() then
            Control.CastSpell(HK_E, target)
            --self:CastSpell(HK_Etarget)
        end
    end
    local target = TargetSelector:GetTarget(self.W.Range, 1)
    if Ready(_W) and target and IsValid(target)then
        if self.shadowMenuAmumu.combo.W:Value() then
            --print("Value is true")
            Control.KeyDown(HK_W)
        end
    end
end

function Amumu:jungleclear()
    if self.shadowMenuAmumu.jungleclear.UseQ:Value() then 
        for i = 1, Game.MinionCount() do
            local obj = Game.Minion(i)
            if obj.team ~= myHero.team then
                if obj ~= nil and obj.valid and obj.visible and not obj.dead then
                    if Ready(_Q) and self.shadowMenuAmumu.jungleclear.UseQ:Value() and obj and obj.team == 300 and obj.valid and obj.visible and not obj.dead and obj.pos:DistanceTo(myHero.pos) < 800 then
                        Control.CastSpell(HK_Q, obj);
                    end
                end
            end
            if Ready(_E) and self.shadowMenuAmumu.jungleclear.UseE:Value() and obj and obj.team == 300 and obj.valid and obj.visible and not obj.dead and obj.pos:DistanceTo(myHero.pos) < 125 + myHero.boundingRadius then
                Control.CastSpell(HK_E);
            end
            if Ready(_W) and self.shadowMenuAmumu.jungleclear.UseW:Value() and obj and obj.team == 300 and obj.valid and obj.visible and not obj.dead and obj.pos:DistanceTo(myHero.pos) < 125 + myHero.boundingRadius then
                Control.CastSpell(HK_W);
            end
        end
    end
    end

    function GetDistanceSqr(p1, p2)
        if not p1 then return math.huge end
        p2 = p2 or myHero
        local dx = p1.x - p2.x
        local dz = (p1.z or p1.y) - (p2.z or p2.y)
        return dx*dx + dz*dz
    end

    function CountEnemiesNear(pos, range)
        local pos = pos.pos
        local N = 0
        for i = 1, Game.HeroCount() do
            local hero = Game.Hero(i)
            if (IsValid(hero, range) and hero.isEnemy and GetDistanceSqr(pos, hero.pos) < range * range) then
                N = N + 1
            end
        end
        return N
    end

function Amumu:autor()
    local target = TargetSelector:GetTarget(self.R.Range, 1)
    if self.shadowMenuAmumu.autor.autor:Value() then
        if Ready(_R) and target and IsValid(target) and CountEnemiesNear(target, 350) >= self.shadowMenuAmumu.autor.autormin:Value() then
            Control.CastSpell(HK_R)
        end
    end
end

function Amumu:killsteal()
    local QDMG = getdmg("q", target, myHero, 1)
    local EDMG = getdmg("e", target, myHero, 1)
    if self.shadowMenuAmumu.killsteal.useq:Value() and QDMG >= target.health then
        self:CastQ()
    end
    if self.shadowMenuAmumu.killsteal.usee:Value() and EDMG >= target.health then
        Control.CastSpell(HK_E, target)
    end
end

function Amumu:CastQ(target)
    if Ready(_Q) and lastR + 350 < GetTickCount() and orbwalker:CanMove() then
        local Pred = GamsteronPrediction:GetPrediction(target, self.Q, myHero)
        if Pred.Hitchance >= _G.HITCHANCE_HIGH then
            Control.CastSpell(HK_Q, Pred.CastPosition)
            lastQ = GetTickCount()
        end
    end
end

class "Cassiopeia"
function Cassiopeia:__init()
    
    self.Q = {_G.SPELLTYPE_CIRCLE, Delay = 0.8, Radius = 75, Range = 850, Speed = math.huge, Collision = false, MaxCollision = 1, CollisionTypes = {_G.COLLISION_MINION, _G.COLLISION_ENEMY, _G.COLLISION_YASUOWALL}}
    self.W = {_G.SPELLTYPE_CIRCLE, Delay = 0.1, Radius = 160, Range = 700, Speed = math.huge, Collision = false, MaxCollision = 1, CollisionTypes = {_G.COLLISION_MINION, _G.COLLISION_ENEMY, _G.COLLISION_YASUOWALL}}
    self.E = {_G.SPELLTYPE_CIRCLE, Delay = 0.1, Radius = 55, Range = 700, Speed = math.huge, Collision = false, MaxCollision = 0, CollisionTypes = {_G.COLLISION_MINION, _G.COLLISION_ENEMY, _G.COLLISION_YASUOWALL}}
    self.R = {_G.SPELLTYPE_CONE, Delay = 0.1, Radius = 80, Range = 825, Speed = 3200, Collision = false, MaxCollision = 1, CollisionTypes = {_G.COLLISION_ENEMY, _G.COLLISION_YASUOWALL}}
    
    OnAllyHeroLoad(function(hero)
        Allys[hero.networkID] = hero
    end)
    
    OnEnemyHeroLoad(function(hero)
        Enemys[hero.networkID] = hero
    end)
    
    Callback.Add("Tick", function() self:Tick() end)
    Callback.Add("Draw", function() self:Draw() end)
    
    orbwalker:OnPreMovement(
        function(args)
            if lastMove + 180 > GetTickCount() then
                args.Process = false
            else
                args.Process = true
                lastMove = GetTickCount()
            end
        end
    )
end

if myHero.charName == "Graves" then
    class "Graves"
    function Graves:__init()
        
        self.Q = {Type = _G.SPELLTYPE_LINE, Delay = 0.25, Radius = 100, Range = 925, Speed = 2000, Collision = false, MaxCollision = 0, CollisionTypes = {_G.COLLISION_MINION, _G.COLLISION_ENEMYHERO}}
        self.W = {Type = _G.SPELLTYPE_CIRCLE, Delay = 0.25, Radius = 250, Range = 950, Speed = 1000, Collision = false, MaxCollision = 0, CollisionTypes = {_G.COLLISION_MINION, _G.COLLISION_ENEMYHERO}}
        self.E = {Type = _G.SPELLTYPE_LINE, Delay = 0.25, Radius = 0, Range = 425, Speed = 2000, Collision = false, MaxCollision = 0, CollisionTypes = {_G.COLLISION_MINION, _G.COLLISION_ENEMYHERO}}
        self.R = {Type = _G.SPELLTYPE_CONE, Delay = 0.50, Radius = 800, Range = 1000, Speed = 3200, Collision = false, MaxCollision = 0, CollisionTypes = {_G.COLLISION_MINION, _G.COLLISION_ENEMYHERO}}
        
        
        OnAllyHeroLoad(function(hero)
            Allys[hero.networkID] = hero
        end)
        
        OnEnemyHeroLoad(function(hero)
            Enemys[hero.networkID] = hero
        end)
        
        Callback.Add("Tick", function() self:Tick() end)
        Callback.Add("Draw", function() self:Draw() end)
        
        orbwalker:OnPreMovement(
            function(args)
                if lastMove + 180 > GetTickCount() then
                    args.Process = false
                else
                    args.Process = true
                    lastMove = GetTickCount()
                end
            end
        )
    end
    
    function Graves:LoadMenu()
        self.shadowMenu = MenuElement({type = MENU, id = "shadowGraves", name = "Shadow Graves"})
        self.shadowMenu:MenuElement({type = MENU, id = "combo", name = "Combo"})
        self.shadowMenu.combo:MenuElement({id = "Q", name = "Use Q in Combo", value = true})
        self.shadowMenu.combo:MenuElement({id = "W", name = "Use W in Combo(Recomended Disabled)", value = false})
        self.shadowMenu.combo:MenuElement({id = "E", name = "Use E in  Combo", value = true})
        self.shadowMenu:MenuElement({type = MENU, id = "jungleclear", name = "Jungle Clear"})
        self.shadowMenu.jungleclear:MenuElement({id = "UseQ", name = "Use Q in Jungle Clear", value = true})
        self.shadowMenu.jungleclear:MenuElement({id = "UseE", name = "Use E in Jungle Clear", value = true})
        self.shadowMenu:MenuElement({type = MENU, id = "autor", name = "Auto R"})
        self.shadowMenu.autor:MenuElement({id = "AutoR", name = "Auto R", value = true})
        --self.shadowMenu:MenuElement({type = MENU, id = "jungleclear", name = "Jungle Clear"})
    end
    
    function Graves:Draw()
        
    end
    
    function Graves:Tick()
        if myHero.dead or Game.IsChatOpen() or (ExtLibEvade and ExtLibEvade.Evading == true) then
            return
        end
        if orbwalker.Modes[0] then
            self:Combo()
        elseif orbwalker.Modes[3] then
            self:jungleclear()
        end
    end
    
    function Graves:AutoR()
        local target = TargetSelector:GetTarget(self.R.Range, 1)
        if Ready(_R) and target and IsValid(target) and (target.health <= target.maxHealth / 4) and self.shadowMenu.autor.AutoR:Value() then
            local Pred = GamsteronPrediction:GetPrediction(target, self.R, myHero)
            --print(Pred.Hitchance)
                --Control.CastSpell(HK_Q, target)
                self:CastR(target)
        end
    end
    
    
    function Graves:Combo()
        local QPred = GamsteronPrediction:GetPrediction(target, self.Q, myHero)
        local target = TargetSelector:GetTarget(self.Q.Range, 1)
        if Ready(_Q) and target and IsValid(target) then
            if self.shadowMenu.combo.Q:Value() then
                self:CastQ(target)
            end
        end
        if Ready(_E) and target and IsValid() then
                self:CastE(target)
        end
    
    
    end
    
    function Graves:jungleclear()
    if self.shadowMenu.jungleclear.UseQ:Value() then 
        for i = 1, Game.MinionCount() do
            local obj = Game.Minion(i)
            if obj.team ~= myHero.team then
                if obj ~= nil and obj.valid and obj.visible and not obj.dead then
                    if Ready(_Q) and self.shadowMenu.jungleclear.UseQ:Value() and obj and obj.team == 300 and obj.valid and obj.visible and not obj.dead and (obj.pos:DistanceTo(myHero.pos) < 800) then
                        Control.CastSpell(HK_Q, obj);
                    end
                end
            end
            if Ready(_E) and self.shadowMenu.jungleclear.UseE:Value() and obj and obj.team == 300 and obj.valid and obj.visible and not obj.dead and obj.pos:DistanceTo(myHero.pos) < 125 + myHero.boundingRadius then
                Control.CastSpell(HK_E, obj);
            end
        end
    end
    end
    
    function Graves:CastQ(target)
        if Ready(_Q) and lastQ + 350 < GetTickCount() and orbwalker:CanMove() then
            local Pred = GamsteronPrediction:GetPrediction(target, self.Q, myHero)
            if Pred.Hitchance >= _G.HITCHANCE_NORMAL then
                Control.CastSpell(HK_Q, Pred.CastPosition)
                lastQ = GetTickCount()
            end
        end
    end
    
    function Graves:CastR(target)
        if Ready(_R) and lastR + 350 < GetTickCount() and orbwalker:CanMove() then
            local Pred = GamsteronPrediction:GetPrediction(target, self.R, myHero)
            if Pred.Hitchance >= _G.HITCHANCE_NORMAL then
                Control.CastSpell(HK_R, Pred.CastPosition)
                lastR = GetTickCount()
            end
        end
    end
    end

    if myHero.charName == "Nocturne" then
        class "Nocturne"
        function Nocturne:__init()
            
            self.Q = {Type = _G.SPELLTYPE_LINE, Delay = 0.25, Radius = 100, Range = 1200, Speed = 1600, Collision = false, MaxCollision = 1, CollisionTypes = {_G.COLLISION_MINION, _G.COLLISION_ENEMYHERO}}
            self.W = {Type = _G.SPELLTYPE_CIRCLE, Delay = 0.25, Radius = 800, Range = 800, Speed = 1400, Collision = false, MaxCollision = 0, CollisionTypes = {_G.COLLISION_MINION, _G.COLLISION_ENEMYHERO}}
            self.E = {Type = _G.SPELLTYPE_CIRCLE, Delay = 0.25, Radius = 0, Range = 475, Speed = 0, Collision = true, MaxCollision = 0, CollisionTypes = {_G.COLLISION_MINION, _G.COLLISION_ENEMYHERO}}
            self.R = {Type = _G.SPELLTYPE_CIRCLE, Delay = 0.50, Radius = 10000, Range = ({2500, 3250, 4000})[GetCastLevel(myHero, _R)], Speed = 2000, Collision = false, MaxCollision = 1, CollisionTypes = {_G.COLLISION_MINION, _G.COLLISION_ENEMYHERO}}
            
            --print(GetCastLevel(myHero, _R))

            OnAllyHeroLoad(function(hero)
                Allys[hero.networkID] = hero
            end)
            
            OnEnemyHeroLoad(function(hero)
                Enemys[hero.networkID] = hero
            end)
            
            Callback.Add("Tick", function() self:Tick() end)
            Callback.Add("Draw", function() self:Draw() end)
            
            orbwalker:OnPreMovement(
                function(args)
                    if lastMove + 180 > GetTickCount() then
                        args.Process = false
                    else
                        args.Process = true
                        lastMove = GetTickCount()
                    end
                end
            )
        end
        
        function Nocturne:LoadMenu()
            self.shadowMenu = MenuElement({type = MENU, id = "shadowNocturne", name = "Shadow Nocturne"})
            self.shadowMenu:MenuElement({type = MENU, id = "combo", name = "Combo"})
            self.shadowMenu.combo:MenuElement({id = "Q", name = "Use Q in Combo", value = true})
            self.shadowMenu.combo:MenuElement({id = "W", name = "Use W in Combo", value = false})
            self.shadowMenu.combo:MenuElement({id = "E", name = "Use E in  Combo", value = true})
            self.shadowMenu:MenuElement({type = MENU, id = "jungleclear", name = "Jungle Clear"})
            self.shadowMenu.jungleclear:MenuElement({id = "UseQ", name = "Use Q in Jungle Clear", value = true})
            self.shadowMenu.jungleclear:MenuElement({id = "UseE", name = "Use E in Jungle Clear", value = true})
            self.shadowMenu:MenuElement({type = MENU, id = "laneclear", name = "Lane Clear"})
            self.shadowMenu.laneclear:MenuElement({id= "UseQLane", name = "Use Q in Lane Clear", value = true})
            self.shadowMenu:MenuElement({type = MENU, id = "autor", name = "Kill Steal"})
            self.shadowMenu.autor:MenuElement({id = "AutoR", name = "Kill steal with R", value = true})
            --self.shadowMenu:MenuElement({type = MENU, id = "jungleclear", name = "Jungle Clear"})
        end
        
        function Nocturne:Draw()
            
        end
        
        function Nocturne:Tick()
            if myHero.dead or Game.IsChatOpen() or (ExtLibEvade and ExtLibEvade.Evading == true) then
                return
            end
            self:AutoR()
            if orbwalker.Modes[0] then
                self:Combo()
            elseif orbwalker.Modes[3] then
                self:jungleclear()
                self:laneclear()
            end
        end
        
        function Nocturne:AutoR()
            local target = TargetSelector:GetTarget(self.R.Range, 1)
            if target and IsValid(target) then
            local rdmg = (({150, 275, 400})[myHero:GetSpellData(_R).level or 1] + (myHero.bonusDamage * 2))
            if Ready(_R) and target and IsValid(target) and (target.health <= rdmg) and self.shadowMenu.autor.AutoR:Value() then
                local Pred = GamsteronPrediction:GetPrediction(target, self.R, myHero)
                --print(Pred.Hitchance)
                    --Control.CastSpell(HK_Q, target)
                    Control.CastSpell(HK_R)
                    self:CastR(target)
            end
        end
        end
        
        
        function Nocturne:Combo()
            local QPred = GamsteronPrediction:GetPrediction(target, self.Q, myHero)
            local target = TargetSelector:GetTarget(self.Q.Range, 1)
            if Ready(_Q) and target and IsValid(target) then
                if self.shadowMenu.combo.Q:Value() then
                    --Control.CastSpell(HK_Q, target)
                    self:CastQ(target)
                end
            end
            --print(GetCastLevel(myHero, _R))
           -- print(self.R.Range)
            if Ready(_W) then
                if self.shadowMenu.combo.W:Value() then
                    Control.KeyDown(HK_W)
                end
            end
            
            local target = TargetSelector:GetTarget(self.E.Range - 100, 1)
            if Ready(_E) and target and IsValid(target) then
                if self.shadowMenu.combo.E:Value() then
                    Control.CastSpell(HK_E, target)
                    --self:CastSpell(HK_Etarget)
                end
            end
        
        end
        
        function Nocturne:jungleclear()
        if self.shadowMenu.jungleclear.UseQ:Value() then 
            for i = 1, Game.MinionCount() do
                local obj = Game.Minion(i)
                if obj.team ~= myHero.team then
                    if obj ~= nil and obj.valid and obj.visible and not obj.dead then
                        if Ready(_Q) and self.shadowMenu.jungleclear.UseQ:Value() and obj and obj.team == 300 and obj.valid and obj.visible and not obj.dead and (obj.pos:DistanceTo(myHero.pos) < 800) then
                            Control.CastSpell(HK_Q, obj);
                        end
                    end
                end
                if Ready(_E) and self.shadowMenu.jungleclear.UseE:Value() and obj and obj.team == 300 and obj.valid and obj.visible and not obj.dead and obj.pos:DistanceTo(myHero.pos) < 125 + myHero.boundingRadius then
                    Control.CastSpell(HK_E, obj);
                end
            end
        end
        end

        function Nocturne:laneclear()
            for i = 1, Game.MinionCount() do
                local minion = Game.Minion(i)
                if minion.team ~= myHero.team then 
                    local dist = myHero.pos:DistanceTo(minion.pos)
                    if self.shadowMenu.laneclear.UseQLane:Value() and Ready(_Q) and dist <= self.Q.Range then 
                        Control.CastSpell(HK_Q, minion.pos)
                    end

                end
            end
        end
        
        function Nocturne:CastQ(target)
            if Ready(_Q) and lastQ + 350 < GetTickCount() and orbwalker:CanMove() then
                local Pred = GamsteronPrediction:GetPrediction(target, self.Q, myHero)
                if Pred.Hitchance >= _G.HITCHANCE_NORMAL then
                    Control.CastSpell(HK_Q, Pred.CastPosition)
                    lastQ = GetTickCount()
                end
            end
        end
        
        function Nocturne:CastR(target)
            if Ready(_R) and lastR + 350 < GetTickCount() and orbwalker:CanMove() then
                local Pred = GamsteronPrediction:GetPrediction(target, self.R, myHero)
                if Pred.Hitchance >= _G.HITCHANCE_NORMAL then
                    Control.CastSpell(HK_R, Pred.CastPosition)
                    lastR = GetTickCount()
                end
            end
        end
        end

        if myHero.charName == "DrMundo" then
            class "DrMundo"
            function DrMundo:__init()
                
                self.Q = {Type = _G.SPELLTYPE_LINE, Delay = 0.25, Radius = 60, Range = 975, Speed = 1850, Collision = true, MaxCollision = 0, CollisionTypes = {_G.COLLISION_MINION, _G.COLLISION_ENEMYHERO}}
                self.W = {Type = _G.SPELLTYPE_CIRCLE, Delay = 0, Radius = 162.5, Range = 800, Speed = 0, Collision = false, MaxCollision = 0, CollisionTypes = {_G.COLLISION_MINION, _G.COLLISION_ENEMYHERO}}
                self.E = {Type = _G.SPELLTYPE_CIRCLE, Delay = 0, Radius = 0, Range = 0, Speed = 0, Collision = false, MaxCollision = 0, CollisionTypes = {_G.COLLISION_MINION, _G.COLLISION_ENEMYHERO}}
                self.R = {Type = _G.SPELLTYPE_CIRCLE, Delay = 0, Radius = 0, Range = 0, Speed = 0, Collision = false, MaxCollision = 0, CollisionTypes = {_G.COLLISION_MINION, _G.COLLISION_ENEMYHERO}}
                

                OnAllyHeroLoad(function(hero)
                    Allys[hero.networkID] = hero
                end)
                
                OnEnemyHeroLoad(function(hero)
                    Enemys[hero.networkID] = hero
                end)
                
                Callback.Add("Tick", function() self:Tick() end)
                Callback.Add("Draw", function() self:Draw() end)
                
                orbwalker:OnPreMovement(
                    function(args)
                        if lastMove + 180 > GetTickCount() then
                            args.Process = false
                        else
                            args.Process = true
                            lastMove = GetTickCount()
                        end
                    end
                )
            end
            
            function DrMundo:LoadMenu()
                self.shadowMenu = MenuElement({type = MENU, id = "shadowDrMundo", name = "Shadow DrMundo"})
                self.shadowMenu:MenuElement({type = MENU, id = "combo", name = "Combo"})
                self.shadowMenu.combo:MenuElement({id = "Q", name = "Use Q in Combo", value = true})
                self.shadowMenu.combo:MenuElement({id = "W", name = "Use W in Combo", value = false})
                self.shadowMenu.combo:MenuElement({id = "E", name = "Use E in  Combo", value = true})
                self.shadowMenu.combo:MenuElement({id = "R", name = "Use R in  Combo", value = true})
                self.shadowMenu:MenuElement({type = MENU, id = "jungleclear", name = "Jungle Clear"})
                self.shadowMenu.jungleclear:MenuElement({id = "UseQ", name = "Use Q in Jungle Clear", value = true})
                self.shadowMenu.jungleclear:MenuElement({id = "UseW", name = "Use W in Jungle Clear", value = true})
                self.shadowMenu.jungleclear:MenuElement({id = "UseE", name = "Use E in Jungle Clear", value = true})
                self.shadowMenu:MenuElement({type = MENU, id = "laneclear", name = "Lane Clear"})
                self.shadowMenu.laneclear:MenuElement({id= "UseQLane", name = "Use Q in Lane Clear", value = true})
                self.shadowMenu:MenuElement({type = MENU, id = "killsteal", name = "Kill Steal"})
                self.shadowMenu.killsteal:MenuElement({id = "killstealq", name = "Kill steal with Q", value = true})
                self.shadowMenu:MenuElement({type = MENU, id = "autor", name = "Auto R Settings"})
                self.shadowMenu.autor:MenuElement({id = "useautor", name = "Use auto [R] ?", value = true})
                self.shadowMenu.autor:MenuElement({id = "autorhp", name = "Activate R when at what % HP", value = 30, min = 0, max = 100, identifier = "%"})
            end
            
            function DrMundo:Draw()
                
            end
            
            function DrMundo:Tick()
                if myHero.dead or Game.IsChatOpen() or (ExtLibEvade and ExtLibEvade.Evading == true) then
                    return
                end
                self:killsteal()
                self:AutoR()
                if orbwalker.Modes[0] then
                    self:Combo()
                elseif orbwalker.Modes[3] then
                    self:jungleclear()
                    self:laneclear()
                end
            end
            
            function DrMundo:killsteal()
                local target = TargetSelector:GetTarget(self.Q.Range, 1)
                if target and IsValid(target) then
                  --  print(myHero:GetSpellData(_W).toggleState)
                local EnemyHealthThirty = target.health * .30
                local qdmg = (({20, 275, 400})[myHero:GetSpellData(_R).level or 1])
                if Ready(_R) and target and IsValid(target) and (target.health <= qdmg) and self.shadowMenu.killsteal.killstealq:Value() then
                    local Pred = GamsteronPrediction:GetPrediction(target, self.Q, myHero)
                    --print(Pred.Hitchance)
                        --Control.CastSpell(HK_Q, target)
                        self:CastQ(target)
                end
            end
            end
            
            
            function DrMundo:Combo()
                local QPred = GamsteronPrediction:GetPrediction(target, self.Q, myHero)
                local target = TargetSelector:GetTarget(self.Q.Range, 1)
                if Ready(_Q) and target and IsValid(target) then
                    if self.shadowMenu.combo.Q:Value() then
                        self:CastQ(target)
                    end
                end
                if Ready(_W) then
                    if self.shadowMenu.combo.W:Value() and myHero:GetSpellData(_W).toogleState ~= 2 then
                        Control.KeyDown(HK_W)
                    end
                end
                
                local target = TargetSelector:GetTarget(self.Q.Range, 1)
                if Ready(_E) and target and IsValid(target) then
                    if self.shadowMenu.combo.E:Value() then
                        Control.CastSpell(HK_E)
                        --self:CastSpell(HK_Etarget)
                    end
                end
            
            end
            
            function DrMundo:jungleclear()
            if self.shadowMenu.jungleclear.UseQ:Value() then 
                for i = 1, Game.MinionCount() do
                    local obj = Game.Minion(i)
                    if obj.team ~= myHero.team then
                        if obj ~= nil and obj.valid and obj.visible and not obj.dead then
                            if Ready(_Q) and self.shadowMenu.jungleclear.UseQ:Value() and obj and obj.team == 300 and obj.valid and obj.visible and not obj.dead and (obj.pos:DistanceTo(myHero.pos) < 800) then
                                Control.CastSpell(HK_Q, obj);
                            end
                            if Ready(_E) and self.shadowMenu.jungleclear.UseE:Value() and obj and obj.team == 300 and obj.valid and obj.visible and not obj.dead and obj.pos:DistanceTo(myHero.pos) < 800 then
                                Control.CastSpell(HK_E);
                            end
                            if Ready(_W) and self.shadowMenu.jungleclear.UseW:Value() and myHero:GetSpellData(_W).toogleState ~= 2 and obj and obj.team == 300 and obj.valid and obj.visible and not obj.dead and obj.pos:DistanceTo(myHero.pos) < 800 then
                                Control.KeyDown(HK_W);
                            end
                        end
                        end
                    end
            end
            end

            function DrMundo:AutoR()
                local decimalhealthstring = "." .. self.shadowMenu.autor.autorhp:Value()
                local decimalhealth = myHero.maxHealth * decimalhealthstring
            
                if self.shadowMenu.autor.useautor:Value() and myHero.health <= decimalhealth and Ready(_R) then
                    Control.CastSpell(HK_R)
                end
            end
    
            function DrMundo:laneclear()
                for i = 1, Game.MinionCount() do
                    local minion = Game.Minion(i)
                    if minion.team ~= myHero.team then 
                        local dist = myHero.pos:DistanceTo(minion.pos)
                        if self.shadowMenu.laneclear.UseQLane:Value() and Ready(_Q) and dist <= self.Q.Range then 
                            Control.CastSpell(HK_Q, minion.pos)
                        end
    
                    end
                end
            end
            
            function DrMundo:CastQ(target)
                if Ready(_Q) and lastQ + 350 < GetTickCount() and orbwalker:CanMove() then
                    local Pred = GamsteronPrediction:GetPrediction(target, self.Q, myHero)
                    if Pred.Hitchance >= _G.HITCHANCE_NORMAL then
                        Control.CastSpell(HK_Q, Pred.CastPosition)
                        lastQ = GetTickCount()
                    end
                end
            end

    
            
            function DrMundo:CastR(target)
                if Ready(_R) and lastR + 350 < GetTickCount() and orbwalker:CanMove() then
                    local Pred = GamsteronPrediction:GetPrediction(target, self.R, myHero)
                    if Pred.Hitchance >= _G.HITCHANCE_NORMAL then
                        Control.CastSpell(HK_R, Pred.CastPosition)
                        lastR = GetTickCount()
                    end
                end
            end
            end

            if myHero.charName == "MonkeyKing" then
                class "MonkeyKing"
                function MonkeyKing:__init()
                    
                    self.Q = {Type = _G.SPELLTYPE_LINE, Delay = 0, Radius = 100, Range = myHero:GetSpellData(_Q).range, Speed = 0, Collision = false, MaxCollision = 0, CollisionTypes = {_G.COLLISION_MINION, _G.COLLISION_ENEMYHERO}}
                    self.W = {Type = _G.SPELLTYPE_CIRCLE, Delay = 0, Radius = 175, Range = myHero:GetSpellData(_W).range, Speed = 0, Collision = false, MaxCollision = 0, CollisionTypes = {_G.COLLISION_MINION, _G.COLLISION_ENEMYHERO}}
                    self.E = {Type = _G.SPELLTYPE_CIRCLE, Delay = 0, Radius = 187.5, Range = myHero:GetSpellData(_E).range, Speed = 0, Collision = false, MaxCollision = 0, CollisionTypes = {_G.COLLISION_MINION, _G.COLLISION_ENEMYHERO}}
                    self.R = {Type = _G.SPELLTYPE_CIRCLE, Delay = 0, Radius = 162.5, Range = myHero:GetSpellData(_R).range, Speed = 0, Collision = false, MaxCollision = 0, CollisionTypes = {_G.COLLISION_MINION, _G.COLLISION_ENEMYHERO}}
                    
    
                    OnAllyHeroLoad(function(hero)
                        Allys[hero.networkID] = hero
                    end)
                    
                    OnEnemyHeroLoad(function(hero)
                        Enemys[hero.networkID] = hero
                    end)
                    
                    Callback.Add("Tick", function() self:Tick() end)
                    Callback.Add("Draw", function() self:Draw() end)
                    
                    orbwalker:OnPreMovement(
                        function(args)
                            if lastMove + 180 > GetTickCount() then
                                args.Process = false
                            else
                                args.Process = true
                                lastMove = GetTickCount()
                            end
                        end
                    )
                end

                local Icons = {
                    ["WukongIcon"] = "https://vignette1.wikia.nocookie.net/leagueoflegends/images/7/78/Wukong_OriginalLoading.jpg",
                    ["Q"] = "https://vignette3.wikia.nocookie.net/leagueoflegends/images/1/10/Crushing_Blow.png",
                    ["W"] = "https://vignette1.wikia.nocookie.net/leagueoflegends/images/b/bb/Decoy.png",
                    ["E"] = "https://vignette3.wikia.nocookie.net/leagueoflegends/images/e/e0/Nimbus_Strike.png",
                    ["R"] = "https://vignette3.wikia.nocookie.net/leagueoflegends/images/7/79/Cyclone.png",
                    ["EXH"] = "https://vignette2.wikia.nocookie.net/leagueoflegends/images/4/4a/Exhaust.png"
                    }
                
                function MonkeyKing:LoadMenu()
                    self.shadowMenu = MenuElement({type = MENU, id = "shadowMonkeyKing", name = "Shadow Wukong", leftIcon = Icons["WukongIcon"]})


                    -- COMBO --
                    self.shadowMenu:MenuElement({type = MENU, id = "combo", name = "Combo"})
                    self.shadowMenu.combo:MenuElement({id = "Q", name = "Use Q in Combo", value = true, leftIcon = Icons.Q})
                    self.shadowMenu.combo:MenuElement({id = "E", name = "Use E in  Combo", value = true, leftIcon = Icons.E})
                    self.shadowMenu.combo:MenuElement({id = "R", name = "Use R in  Combo", value = true, leftIcon = Icons.R})
                    self.shadowMenu.combo:MenuElement({id = "ER", name = "Min enemies to use R", value = 1, min = 1, max = 5})


                    -- JUNGLE CLEAR --
                    self.shadowMenu:MenuElement({type = MENU, id = "jungleclear", name = "Jungle Clear"})
                    self.shadowMenu.jungleclear:MenuElement({id = "Q", name = "Use Q in Jungle clear", value = true, leftIcon = Icons.Q})
                    self.shadowMenu.jungleclear:MenuElement({id = "E", name = "Use E in Jungle clear", value = true, leftIcon = Icons.E})


                    -- LANE CLEAR --
                    self.shadowMenu:MenuElement({type = MENU, id = "laneclear", name = "Lane Clear"})
                    self.shadowMenu.laneclear:MenuElement({id= "UseQLane", name = "Use Q in Lane Clear", value = true, leftIcon = Icons.Q})
                    self.shadowMenu.laneclear:MenuElement({id= "UseELane", name = "Use E in Lane Clear", value = true, leftIcon = Icons.Q})


                    -- KILL STEAL --
                    self.shadowMenu:MenuElement({type = MENU, id = "killsteal", name = "Kill Steal"})
                    self.shadowMenu.killsteal:MenuElement({id = "killstealq", name = "Kill steal with Q", value = true, leftIcon = Icons.Q})

                end
                
                function MonkeyKing:Draw()
                    
                end
                
                function MonkeyKing:Tick()
                    if myHero.dead or Game.IsChatOpen() or (ExtLibEvade and ExtLibEvade.Evading == true) then
                        return
                    end
                    self:killsteal()
                    if orbwalker.Modes[0] then
                        self:Combo()
                    elseif orbwalker.Modes[3] then
                        self:jungleclear()
                        self:laneclear()
                    end
                end
                
                function MonkeyKing:killsteal()
                    local target = TargetSelector:GetTarget(self.Q.Range, 1)
                    if target and IsValid(target) then
                      --  print(myHero:GetSpellData(_W).toggleState)
                    local EnemyHealthThirty = target.health * .30
                    local qdmg = (({20, 275, 400})[myHero:GetSpellData(_R).level or 1])
                    if Ready(_R) and target and IsValid(target) and (target.health <= qdmg) and self.shadowMenu.killsteal.killstealq:Value() then
                        local Pred = GamsteronPrediction:GetPrediction(target, self.Q, myHero)
                        --print(Pred.Hitchance)
                            --Control.CastSpell(HK_Q, target)
                            self:CastQ(target)
                    end
                end
                end
                
                
                function MonkeyKing:Combo()
                    local QPred = GamsteronPrediction:GetPrediction(target, self.Q, myHero)
                    local target = TargetSelector:GetTarget(self.Q.Range, 1)
                    if Ready(_Q) and target and IsValid(target) then
                        if self.shadowMenu.combo.Q:Value() then
                            self:CastQ(target)
                        end
                    end
                    local target = TargetSelector:GetTarget(self.E.Range, 1)
                    if Ready(_E) and target and IsValid(target) then
                        if self.shadowMenu.combo.E:Value() then
                            Control.CastSpell(HK_E, target)
                            --self:CastSpell(HK_Etarget)
                        end
                    end

                    local target = TargetSelector:GetTarget(self.R.Range, 1)
                    if Ready(_R) and CountEnemiesNear(target, self.R.Range) >= self.shadowMenu.combo.ER:Value() and target and IsValid(target) then
                        if self.shadowMenu.combo.R:Value() then
                            self:CastR(target)
                            --self:CastSpell(HK_Etarget)
                        end
                    end
                end
                
                function MonkeyKing:jungleclear()
                if self.shadowMenu.jungleclear.Q:Value() then 
                    for i = 1, Game.MinionCount() do
                        local obj = Game.Minion(i)
                        if obj.team ~= myHero.team then
                            if obj ~= nil and obj.valid and obj.visible and not obj.dead then
                                if Ready(_Q) and self.shadowMenu.jungleclear.Q:Value() and obj and obj.team == 300 and obj.valid and obj.visible and not obj.dead and (obj.pos:DistanceTo(myHero.pos) < 800) then
                                    Control.CastSpell(HK_Q, obj);
                                end
                                if Ready(_E) and self.shadowMenu.jungleclear.E:Value() and obj and obj.team == 300 and obj.valid and obj.visible and not obj.dead and obj.pos:DistanceTo(myHero.pos) < 800 then
                                    Control.CastSpell(HK_E, obj);
                                end
                            end
                            end
                        end
                end
                end
        
                function MonkeyKing:laneclear()
                    for i = 1, Game.MinionCount() do
                        local minion = Game.Minion(i)
                        if minion.team ~= myHero.team then 
                            local dist = myHero.pos:DistanceTo(minion.pos)
                            if self.shadowMenu.laneclear.UseQLane:Value() and Ready(_Q) and dist <= self.Q.Range then 
                                Control.CastSpell(HK_Q, minion.pos)
                            end
                            if self.shadowMenu.laneclear.UseELane:Value() and Ready(_E) and dist <= self.E.Range then 
                                Control.CastSpell(HK_E, minion.pos)
                            end
                        end
                    end
                end
                
                function MonkeyKing:CastQ(target)
                    if Ready(_Q) and lastQ + 350 < GetTickCount() and orbwalker:CanMove() then
                        local Pred = GamsteronPrediction:GetPrediction(target, self.Q, myHero)
                        if Pred.Hitchance >= _G.HITCHANCE_NORMAL then
                            Control.CastSpell(HK_Q, Pred.CastPosition)
                            lastQ = GetTickCount()
                        end
                    end
                end
    
        
                
                function MonkeyKing:CastR(target)
                    if Ready(_R) and lastR + 350 < GetTickCount() and orbwalker:CanMove() then
                        local Pred = GamsteronPrediction:GetPrediction(target, self.R, myHero)
                        if CountEnemiesNear(target, myHero:GetSpellData(_R).range) >= self.shadowMenu.combo.ER:Value() then
                            Control.CastSpell(HK_R)
                            lastR = GetTickCount()
                        end
                    end
                end
                end
            
                if myHero.charName == "Gragas" then
                    class "Gragas"
                    function Gragas:__init()
                        
                        self.Q = {Type = _G.SPELLTYPE_LINE, Delay = 0, Radius = 100, Range = myHero:GetSpellData(_Q).range, Speed = 1000, Collision = false, MaxCollision = 0, CollisionTypes = {_G.COLLISION_MINION, _G.COLLISION_ENEMYHERO}}
                        self.W = {Type = _G.SPELLTYPE_CIRCLE, Delay = 0.75, Radius = 175, Range = myHero:GetSpellData(_W).range, Speed = 0, Collision = false, MaxCollision = 0, CollisionTypes = {_G.COLLISION_MINION, _G.COLLISION_ENEMYHERO}}
                        self.E = {Type = _G.SPELLTYPE_CIRCLE, Delay = 0, Radius = 180, Range = myHero:GetSpellData(_E).range, Speed = 1400, Collision = false, MaxCollision = 0, CollisionTypes = {_G.COLLISION_MINION, _G.COLLISION_ENEMYHERO}}
                        self.R = {Type = _G.SPELLTYPE_CIRCLE, Delay = 0.55, Radius = 400, Range = myHero:GetSpellData(_R).range, Speed = 1000, Collision = false, MaxCollision = 0, CollisionTypes = {_G.COLLISION_MINION, _G.COLLISION_ENEMYHERO}}
                        
        
                        OnAllyHeroLoad(function(hero)
                            Allys[hero.networkID] = hero
                        end)
                        
                        OnEnemyHeroLoad(function(hero)
                            Enemys[hero.networkID] = hero
                        end)
                        
                        Callback.Add("Tick", function() self:Tick() end)
                        Callback.Add("Draw", function() self:Draw() end)
                        
                        orbwalker:OnPreMovement(
                            function(args)
                                if lastMove + 180 > GetTickCount() then
                                    args.Process = false
                                else
                                    args.Process = true
                                    lastMove = GetTickCount()
                                end
                            end
                        )
                    end
    
                    local Icons = {
                        ["WukongIcon"] = "https://cdn.discordapp.com/attachments/653578761228386317/676567302015287301/GragMain.png",
                        ["Q"] = "https://cdn.discordapp.com/attachments/653578761228386317/676562902194585620/GragE.png",
                        ["W"] = "https://cdn.discordapp.com/attachments/653578761228386317/676563180121489408/GragW.png",
                        ["E"] = "https://cdn.discordapp.com/attachments/653578761228386317/676563389652402176/GragE2.png",
                        ["R"] = "https://cdn.discordapp.com/attachments/653578761228386317/676563633244733482/GragR.png",
                        ["EXH"] = "https://vignette2.wikia.nocookie.net/leagueoflegends/images/4/4a/Exhaust.png"
                        }
                    
                    function Gragas:LoadMenu()
                        self.shadowMenu = MenuElement({type = MENU, id = "shadowGragas", name = "Shadow Gragas", leftIcon = Icons["WukongIcon"]})
    
    
                        -- COMBO --
                        self.shadowMenu:MenuElement({type = MENU, id = "combo", name = "Combo"})
                        self.shadowMenu.combo:MenuElement({id = "Q", name = "Use Q in Combo", value = true, leftIcon = Icons.Q})
                        self.shadowMenu.combo:MenuElement({id = "W", name = "Use W in Combo", value = true, leftIcon = Icons.W})
                        self.shadowMenu.combo:MenuElement({id = "E", name = "Use E in  Combo", value = true, leftIcon = Icons.E})
                        self.shadowMenu.combo:MenuElement({id = "R", name = "Use R in  Combo", value = true, leftIcon = Icons.R})
                        self.shadowMenu.combo:MenuElement({id = "RSETTINGS", name = "[R]Ultimate Settings", type = MENU})
                        self.shadowMenu.combo.RSETTINGS:MenuElement({id = "ER", name = "Min enemies to use R", value = 1, min = 1, max = 5,})
                        self.shadowMenu.combo.RSETTINGS:MenuElement({id = "RKILL", name = "Only use ult if killable", value = true, leftIcon = Icons.R})
    
    
                        -- JUNGLE CLEAR --
                        self.shadowMenu:MenuElement({type = MENU, id = "jungleclear", name = "Jungle Clear"})
                        self.shadowMenu.jungleclear:MenuElement({id = "Q", name = "Use Q in Jungle clear", value = true, leftIcon = Icons.Q})
                        self.shadowMenu.jungleclear:MenuElement({id = "W", name = "Use W in Jungle clear", value = true, leftIcon = Icons.W})
                        self.shadowMenu.jungleclear:MenuElement({id = "E", name = "Use E in Jungle clear", value = true, leftIcon = Icons.E})
    
    
                        -- LANE CLEAR --
                        self.shadowMenu:MenuElement({type = MENU, id = "laneclear", name = "Lane Clear"})
                        self.shadowMenu.laneclear:MenuElement({id= "UseQLane", name = "Use Q in Lane Clear", value = true, leftIcon = Icons.Q})
    
    
                        -- KILL STEAL --
                        self.shadowMenu:MenuElement({type = MENU, id = "killsteal", name = "Kill Steal"})
                        self.shadowMenu.killsteal:MenuElement({id = "killstealq", name = "Kill steal with Q", value = true, leftIcon = Icons.Q})
                        self.shadowMenu.killsteal:MenuElement({id = "killstealr", name = "Kill steal with R", value = true, leftIcon = Icons.R})
    
                    end
                    
                    function Gragas:Draw()
                        
                    end
                    
                    function Gragas:Tick()
                        if myHero.dead or Game.IsChatOpen() or (ExtLibEvade and ExtLibEvade.Evading == true) then
                            return
                        end
                        self:killsteal()
                        if orbwalker.Modes[0] then
                            self:Combo()
                        elseif orbwalker.Modes[3] then
                            self:jungleclear()
                            self:laneclear()
                        end
                    end
                    
                    function Gragas:killsteal()
                        local target = TargetSelector:GetTarget(self.Q.Range, 1)
                        if target and IsValid(target) then
                          --  print(myHero:GetSpellData(_W).toggleState)
                        local EnemyHealthThirty = target.health * .30
                        local qdmg = getdmg("Q", target, myHero)
                        local rdmg = getdmg("R", target, myHero)
                        if Ready(_R) and target and IsValid(target) and (target.health <= rdmg) and self.shadowMenu.killsteal.killstealr:Value() then
                            local Pred = GamsteronPrediction:GetPrediction(target, self.R, myHero)
                            --print(Pred.Hitchance)
                                --Control.CastSpell(HK_Q, target)
                                self:CastR(target)
                        end
                    end
                    end
                    
                    
                    function Gragas:Combo()
                        local target = TargetSelector:GetTarget(self.E.Range, 1)
                        if target == nil then return end
                        if Ready(_E) and target and IsValid(target) then
                            if self.shadowMenu.combo.E:Value() then
                                Control.CastSpell(HK_E, target)
                                --self:CastSpell(HK_Etarget)
                            end
                        end

                        local QPred = GamsteronPrediction:GetPrediction(target, self.Q, myHero)
                        local target = TargetSelector:GetTarget(self.Q.Range, 1)
                        if target == nil then return end
                        if Ready(_Q) and target and IsValid(target) then
                            if self.shadowMenu.combo.Q:Value() then
                                self:CastQ(target)
                            end
                        end

                        local target = TargetSelector:GetTarget(self.Q.Range, 1)
                        if Ready(_W) and target and IsValid(target) then
                            if self.shadowMenu.combo.W:Value() then
                                Control.CastSpell(HK_W)
                                --self:CastSpell(HK_Etarget)
                            end
                        end
                        if self.shadowMenu.combo.RSETTINGS.RKILL:Value() then
                        local target = TargetSelector:GetTarget(self.R.Range, 1)
                        if Ready(_R) and target and IsValid(target) then
                            local RDMG = getdmg("R", target, myHero)
                            --print(target.health)
                            if self.shadowMenu.combo.R:Value() and target.health < RDMG then
                                self:CastR(target)
                                --self:CastSpell(HK_Etarget)
                            end
                        end
                    end
                    
                function Gragas:jungleclear()
                    if self.shadowMenu.jungleclear.Q:Value() then 
                        for i = 1, Game.MinionCount() do
                            local obj = Game.Minion(i)
                            if obj.team ~= myHero.team then
                                if obj ~= nil and obj.valid and obj.visible and not obj.dead then
                                    if Ready(_Q) and self.shadowMenu.jungleclear.Q:Value() and obj and obj.team == 300 and obj.valid and obj.visible and not obj.dead and (obj.pos:DistanceTo(myHero.pos) < 800) then
                                        Control.CastSpell(HK_Q, obj);
                                    end
                                    if Ready(_E) and self.shadowMenu.jungleclear.E:Value() and obj and obj.team == 300 and obj.valid and obj.visible and not obj.dead and obj.pos:DistanceTo(myHero.pos) < 800 then
                                        Control.CastSpell(HK_E, obj);
                                    end
                                    if Ready(_W) and self.shadowMenu.jungleclear.W:Value() and obj and obj.team == 300 and obj.valid and obj.visible and not obj.dead and obj.pos:DistanceTo(myHero.pos) < 800 then
                                        Control.CastSpell(HK_W);
                                    end
                                end
                                end
                            end
                    end
                end
            
                    function Gragas:laneclear()
                        for i = 1, Game.MinionCount() do
                            local minion = Game.Minion(i)
                            if minion.team ~= myHero.team then 
                                local dist = myHero.pos:DistanceTo(minion.pos)
                                if self.shadowMenu.laneclear.UseQLane:Value() and Ready(_Q) and dist <= self.Q.Range then 
                                    Control.CastSpell(HK_Q, minion.pos)
                                end
                            end
                        end
                    end
                    
                    function Gragas:CastQ(target)
                        if Ready(_Q) and lastQ + 350 < GetTickCount() and orbwalker:CanMove() then
                            local Pred = GamsteronPrediction:GetPrediction(target, self.Q, myHero)
                            if Pred.Hitchance >= _G.HITCHANCE_NORMAL then
                                Control.CastSpell(HK_Q, Pred.CastPosition)
                                lastQ = GetTickCount()
                            end
                        end
                    end

                    function Gragas:CastE(target)
                        if Ready(_E) and lastE + 350 < GetTickCount() and orbwalker:CanMove() then
                            local Pred = GamsteronPrediction:GetPrediction(target, self.E, myHero)
                            if Pred.Hitchance >= _G.HITCHANCE_NORMAL then
                                Control.CastSpell(HK_E, Pred.CastPosition)
                                lastQ = GetTickCount()
                            end
                        end
                    end
        
                    function Gragas:CastR(target)
                        if Ready(_R) and lastR + 350 < GetTickCount() and orbwalker:CanMove() then
                            local Pred = GamsteronPrediction:GetPrediction(target, self.R, myHero)
                            if Pred.Hitchance >= _G.HITCHANCE_HIGH then
                                Control.CastSpell(HK_R, Pred.CastPosition)
                                lastR = GetTickCount()
                            end
                        end
                    end
                end
            end

        local Heroes = {"JarvanIV"}
        if not table.contains(Heroes, myHero.charName) then return end
                
        
        
        class "JarvanIV"
        function JarvanIV:__init()
            
            self.Q = {Type = _G.SPELLTYPE_LINE, Range = 770, Radius = 90}
            self.W = {Type = _G.SPELLTYPE_CIRCLE, Radius = 625, Range = 10}
            self.E = {Type = _G.SPELLTYPE_CIRCLE, Range = 860, Radius = 175}
            self.R = {Type = _G.SPELLTYPE_CIRCLE, Range = 650, Radius = 325}

            

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
        
        local function CheckFlag(unit, range)
            for i = 0, Game.ObjectCount() do
                local object = Game.Object(i) 
                --print(object.name)
                if object and GetDistanceSqr(object.pos, unit.pos) < range and object.charName == "JarvanIVDamacianStandard" and GetDistanceSqr(object.pos, myHero.pos) < 770 then
                    return true, object.pos
                    end    
                end    
            return false 
        end

        local Icons = {
            ["JarvanIVIcon"] = "https://vignette.wikia.nocookie.net/leagueoflegends/images/4/4c/Jarvan_IV_OriginalSquare.png",
            ["Q"] = "https://vignette.wikia.nocookie.net/leagueoflegends/images/4/4c/Dragon_Strike.png",
            ["W"] = "https://vignette.wikia.nocookie.net/leagueoflegends/images/f/f8/Golden_Aegis.png",
            ["E"] = "https://vignette.wikia.nocookie.net/leagueoflegends/images/6/65/Demacian_Standard.png",
            ["R"] = "https://vignette.wikia.nocookie.net/leagueoflegends/images/c/cf/Cataclysm.png",
            ["EXH"] = "https://vignette2.wikia.nocookie.net/leagueoflegends/images/4/4a/Exhaust.png"
            }
        
        function JarvanIV:LoadMenu()
            self.shadowMenu = MenuElement({type = MENU, id = "shadowJarvanIV", name = "Shadow JarvanIV", leftIcon = Icons["JarvanIVIcon"]})


            -- COMBO --
            self.shadowMenu:MenuElement({type = MENU, id = "combo", name = "Combo"})
            self.shadowMenu.combo:MenuElement({id = "Q", name = "Use Q in Combo", value = true, leftIcon = Icons.Q})
            self.shadowMenu.combo:MenuElement({id = "W", name = "Use W in Combo", value = true, leftIcon = Icons.W})
            self.shadowMenu.combo:MenuElement({id = "E", name = "Use E in  Combo", value = true, leftIcon = Icons.E})
            self.shadowMenu.combo:MenuElement({id = "R", name = "Use R in  Combo", value = true, leftIcon = Icons.R})
            self.shadowMenu.combo:MenuElement({id = "RSETTINGS", name = "[R]Ultimate Settings", type = MENU})
            self.shadowMenu.combo.RSETTINGS:MenuElement({id = "ER", name = "Min enemies to use R", value = 1, min = 1, max = 5,})
            self.shadowMenu.combo.RSETTINGS:MenuElement({id = "RKILL", name = "Only use ult if killable", value = true, leftIcon = Icons.R})


            -- JUNGLE CLEAR --
            self.shadowMenu:MenuElement({type = MENU, id = "jungleclear", name = "Jungle Clear"})
            self.shadowMenu.jungleclear:MenuElement({id = "Q", name = "Use Q in Jungle clear", value = true, leftIcon = Icons.Q})
            self.shadowMenu.jungleclear:MenuElement({id = "W", name = "Use W in Jungle clear", value = true, leftIcon = Icons.W})
            self.shadowMenu.jungleclear:MenuElement({id = "E", name = "Use E in Jungle clear", value = true, leftIcon = Icons.E})

             -- JUNGLE KILLSTEAL --
            self.shadowMenu:MenuElement({type = MENU, id = "junglekillsteal", name = "Jungle Steal"})
            self.shadowMenu.junglekillsteal:MenuElement({id = "Q", name = "Use Q in Jungle Steal", value = true, leftIcon = Icons.Q})
            self.shadowMenu.junglekillsteal:MenuElement({id = "E", name = "Use E in Jungle Steal", value = true, leftIcon = Icons.E})


            -- LANE CLEAR --
            self.shadowMenu:MenuElement({type = MENU, id = "laneclear", name = "Lane Clear"})
            self.shadowMenu.laneclear:MenuElement({id= "UseQLane", name = "Use Q in Lane Clear", value = true, leftIcon = Icons.Q})


            -- KILL STEAL --
            self.shadowMenu:MenuElement({type = MENU, id = "killsteal", name = "Kill Steal"})
            self.shadowMenu.killsteal:MenuElement({id = "killstealq", name = "Kill steal with Q", value = true, leftIcon = Icons.Q})
            self.shadowMenu.killsteal:MenuElement({id = "killsteale", name = "Kill steal with E", value = true, leftIcon = Icons.E})
            self.shadowMenu.killsteal:MenuElement({id = "killstealr", name = "Kill steal with R", value = true, leftIcon = Icons.R})

        end
        
        function JarvanIV:Draw()
            
        end
        
        function JarvanIV:Tick()
            if myHero.dead or Game.IsChatOpen() or (ExtLibEvade and ExtLibEvade.Evading == true) then
                return
            end
            self:killsteal()
            self:junglekillsteal()
            if orbwalker.Modes[0] then
                self:Combo()
            elseif orbwalker.Modes[3] then
                self:jungleclear()
                self:laneclear()
            end
        end
        
        function JarvanIV:killsteal()
            local target = TargetSelector:GetTarget(self.R.Range, 1)
            if target and IsValid(target) then       
            local qdmg = getdmg("Q", target, myHero)
            local rdmg = getdmg("R", target, myHero)
                if Ready(_R) and target and IsValid(target) and (target.health <= rdmg) and self.shadowMenu.killsteal.killstealr:Value() then
                    self:CastR(target)
                end
                if Ready(_Q) and target and IsValid(target) and (target.health <= qdmg) and self.shadowMenu.killsteal.killstealq:Value() then
                    self:CastQ(target)
                end
            end
        end
        
        
        function JarvanIV:Combo()
            local target = TargetSelector:GetTarget(self.E.Range, 1)
            if target == nil then return end
            local posBehind = myHero.pos:Extended(target.pos, target.distance + 200)
            if Ready(_E) and Ready(_Q) and target and IsValid(target) then
                if self.shadowMenu.combo.E:Value() then
                    self:CastE(target)
                    --self:CastSpell(HK_Etarget)
                end
            end

            local target = TargetSelector:GetTarget(self.Q.Range, 1)
            if target == nil then return end
            if Ready(_Q) and target and IsValid(target) then
                if self.shadowMenu.combo.Q:Value() then
                        Control.CastSpell(HK_Q, target)
                end    
            end

            local target = TargetSelector:GetTarget(self.W.Range, 1)
            if target == nil then return end
            if Ready(_W) and target and IsValid(target) then
                if self.shadowMenu.combo.W:Value() then
                    Control.CastSpell(HK_W)
                    --self:CastSpell(HK_Etarget)
                end														---- you have "end" forget
            end
            if self.shadowMenu.combo.RSETTINGS.RKILL:Value() then
                local target = TargetSelector:GetTarget(self.R.Range, 1)
                if target == nil then return end
                if Ready(_R) and target and IsValid(target) then
                local RDMG = getdmg("R", target, myHero)
                    if self.shadowMenu.combo.R:Value() and target.health < RDMG then
                        self:CastR(target)
                        --self:CastSpell(HK_Etarget)
                    end
                end														---- you have "end" forget
            end
        end
        
        function JarvanIV:jungleclear()
            if self.shadowMenu.jungleclear.Q:Value() then 
                for i = 1, Game.MinionCount() do
                    local obj = Game.Minion(i)
                    if obj.team ~= myHero.team then
                        if obj ~= nil and obj.valid and obj.visible and not obj.dead then
                            if Ready(_E) and self.shadowMenu.jungleclear.E:Value() and obj and obj.team == 300 and obj.valid and obj.visible and not obj.dead and obj.pos:DistanceTo(myHero.pos) < self.E.Range + myHero.boundingRadius then
                                Control.CastSpell(HK_E, obj);
                            end

                            if Ready(_Q) and self.shadowMenu.jungleclear.Q:Value() and obj and obj.team == 300 and obj.valid and obj.visible and not obj.dead and (obj.pos:DistanceTo(myHero.pos) < self.Q.Range) then
                                Control.CastSpell(HK_Q, obj);
                            end
                            if Ready(_W) and self.shadowMenu.jungleclear.W:Value() and obj and obj.team == 300 and obj.valid and obj.visible and not obj.dead and obj.pos:DistanceTo(myHero.pos) < self.W.Range + myHero.boundingRadius then
                                Control.CastSpell(HK_W);
                            end
                        end
                    end
                end
            end
        end

        function JarvanIV:junglekillsteal()
            if self.shadowMenu.junglekillsteal.Q:Value() then 
                for i = 1, Game.MinionCount() do
                    local obj = Game.Minion(i)
                    if obj.team ~= myHero.team then
                        if obj ~= nil and obj.valid and obj.visible and not obj.dead then
                            local qdmg = getdmg("Q", obj, myHero, 1)
                            local edmg = getdmg("Q", obj, myHero, 1)
                            if Ready(_E) and self.shadowMenu.junglekillsteal.E:Value() and obj and obj.team == 300 and obj.valid and obj.visible and not obj.dead and obj.pos:DistanceTo(myHero.pos) < self.E.Range + myHero.boundingRadius and obj.health < qdmg then
                                Control.CastSpell(HK_E, obj);
                            end
                            if Ready(_Q) and self.shadowMenu.junglekillsteal.Q:Value() and obj and obj.team == 300 and obj.valid and obj.visible and not obj.dead and (obj.pos:DistanceTo(myHero.pos) < self.Q.Range and obj.health < edmg) then
                                Control.CastSpell(HK_Q, obj);
                            end
                        end
                    end
                end
            end
        end

        function JarvanIV:laneclear()
            for i = 1, Game.MinionCount() do
                local minion = Game.Minion(i)
                if minion.team ~= myHero.team then 
                    local dist = myHero.pos:DistanceTo(minion.pos)
                    if self.shadowMenu.laneclear.UseQLane:Value() and Ready(_Q) and dist <= self.Q.Range then 
                        Control.CastSpell(HK_Q, minion.pos)
                    end
                end
            end
        end
       
        function JarvanIV:CastQ(target)
            if Ready(_Q) and lastQ + 350 < GetTickCount() and orbwalker:CanMove() then
                local Pred = GamsteronPrediction:GetPrediction(target, self.Q, myHero)
                if Pred.Hitchance >= _G.HITCHANCE_NORMAL then
                    Control.CastSpell(HK_Q, Pred.CastPosition)
                    lastQ = GetTickCount()
                end
            end
        end

        function JarvanIV:CastE(target)
            if Ready(_E) and lastE + 350 < GetTickCount() and orbwalker:CanMove() then
                local Pred = GamsteronPrediction:GetPrediction(target, self.E, myHero)
                if Pred.Hitchance >= _G.HITCHANCE_NORMAL then
                    Control.CastSpell(HK_E, Pred.CastPosition)
                    lastQ = GetTickCount()
                end
            end
        end

        function JarvanIV:CastR(target)
            if Ready(_R) and lastR + 350 < GetTickCount() and orbwalker:CanMove() then
                local Pred = GamsteronPrediction:GetPrediction(target, self.R, myHero)
                if Pred.Hitchance >= _G.HITCHANCE_HIGH then
                    Control.CastSpell(HK_R, Pred.CastPosition)
                    lastR = GetTickCount()
                end
            end
        end