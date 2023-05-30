----------------------------------------------------------------------

local Heroes = {"MasterYi", "LeeSin", "Elise", "Jinx", "Leona", "Braum", "Blitzcrank", "Nami", "Sona", "DrMundo", "Nocturne", "Zed", "Olaf", "Hecarim", "Annie", "Garen", "Malphite", "Chogath", "Jax", "Amumu", "Warwick", "Gragas"}								

if not table.contains(Heroes, myHero.charName) then                 -- < ----- On first lines you must check your supported Champs,,,
	print('Shadow AIO does not support ' .. myHero.charName)				-- otherwise all functions will be loaded until the first champ check although no champ is supported
return end
----------------------------------------------------------------------
local GameHeroCount = Game.HeroCount
local GameHero = Game.Hero

local myHero = myHero
local LocalGameTimer = Game.Timer
local GameMissile = Game.Missile
local GameMissileCount = Game.MissileCount

local lastQ = 0
castedWard = false
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
local ItemHotKey = {[ITEM_1] = HK_ITEM_1, [ITEM_2] = HK_ITEM_2,[ITEM_3] = HK_ITEM_3, [ITEM_4] = HK_ITEM_4, [ITEM_5] = HK_ITEM_5, [ITEM_6] = HK_ITEM_6, [ITEM_7] = HK_ITEM_7,}
-- [ AutoUpdate ] --
do
    
    local Version = 0.8
    
    local Files = {
        Lua = {
            Path = SCRIPT_PATH,
            Name = "ShadowAIO.lua",
            Url = "https://raw.githubusercontent.com/4risto/GoS/master/ShadowAIO.lua"
        },
        Version = {
            Path = SCRIPT_PATH,
            Name = "ShadowAIO.version",
            Url = "https://raw.githubusercontent.com/4risto/GoS/master/ShadowAIO.version"    -- check if Raw Adress correct pls.. after you have create the version file on Github
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

Callback.Add("Load", function()
    orbwalker = _G.SDK.Orbwalker
    TargetSelector = _G.SDK.TargetSelector
   
    if FileExist(COMMON_PATH .. "PremiumPrediction.lua") then
        require('PremiumPrediction');
    else
        print("Requires PremiumPrediction please download the file thanks!");
        return
    end

    require('damagelib')
    --require('PremiumPrediction')
    --require('2DGeometry')

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

local function CheckBuffs(unit, buffname)
	for i = 0, unit.buffCount do
		local buff = unit:GetBuff(i)
		if buff and buff.name == buffname and buff.count > 0 then return buff.count end
	end
	return 0
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

function GetCastLevel(unit, slot)
    return unit:GetSpellData(slot).level == 0 and 1 or unit:GetSpellData(slot).level
end

local function GetStatsByRank(slot1, slot2, slot3, spell)
    local slot1 = 0
    local slot2 = 0
    local slot3 = 0
    return (({slot1, slot2, slot3})[myHero:GetSpellData(spell).level or 1])
end
--[[----------------------------------------------------------------------------------------------------------------------------------------------
   _   _   _   _   _      
  / \ / \ / \ / \ / \     
 ( S | T | A | R | T )    
  \_/ \_/ \_/ \_/ \_/     
   _   _                  
  / \ / \                 
 ( O | F )                
  \_/ \_/                 
   _   _   _   _   _   _  
  / \ / \ / \ / \ / \ / \ 
 ( J | U | N | G | L | E )
  \_/ \_/ \_/ \_/ \_/ \_/ 
]]---------------------------------------------------------------------------------------------------------------------------------------------------


--[[
   _   _   _   _   _   _   _   _  
  / \ / \ / \ / \ / \ / \ / \ / \ 
 ( M | a | s | t | e | r | Y | i )
  \_/ \_/ \_/ \_/ \_/ \_/ \_/ \_/  
                                                                    
]]


--local Heroes = {"MasterYi"}											<--- remove this 2 lines,,, you end this script with this, if myHero not MasterYi
--if not table.contains(Heroes, myHero.charName) then return end       		  I have added check on line 1 with explain why i do this....
        
class "MasterYi"
function MasterYi:__init()
    
    self.Q = {_G.SPELLTYPE_CIRCLE, Delay = 0.225, Radius = 0, Range = 600, Speed = 4000, Collision = false}
    

    OnAllyHeroLoad(function(hero)
        Allys[hero.networkID] = hero
    end)
    
    OnEnemyHeroLoad(function(hero)
        Enemys[hero.networkID] = hero
    end)    
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
    ["MasterYiIcon"] = "https://vignette.wikia.nocookie.net/leagueoflegends/images/7/73/Master_Yi_OriginalSquare.png",
    ["Q"] = "https://vignette.wikia.nocookie.net/leagueoflegends/images/e/e6/Alpha_Strike.png",
    ["W"] = "https://vignette.wikia.nocookie.net/leagueoflegends/images/6/61/Meditate.png",
    ["E"] = "https://vignette.wikia.nocookie.net/leagueoflegends/images/7/74/Wuju_Style.png",
    ["R"] = "https://vignette.wikia.nocookie.net/leagueoflegends/images/3/34/Highlander.png",
    ["EXH"] = "https://vignette.wikia.nocookie.net/leagueoflegends/images/4/4a/Exhaust.png",
    ["IGN"] = "https://vignette.wikia.nocookie.net/leagueoflegends/images/f/f4/Ignite.png"
    }

function MasterYi:LoadMenu()
    self.shadowMenu = MenuElement({type = MENU, id = "shadowMasterYi", name = "Shadow MasterYi"})


    -- COMBO --
    self.shadowMenu:MenuElement({type = MENU, id = "combo", name = "Combo"})
    self.shadowMenu.combo:MenuElement({id = "useq", name = "Use [Q] in combo", value = true})
    self.shadowMenu.combo:MenuElement({id = "usee", name = "Use [E] in combo", value = true})
    self.shadowMenu.combo:MenuElement({id = "user", name = "Use [R] in combo", value = true})
    self.shadowMenu.combo:MenuElement({id = "userrange", name = "Use [R] only if out of [Q] range?", value = true})

    -- AUTO W --
    self.shadowMenu:MenuElement({type = MENU, id = "autow", name = "Auto W"})
    self.shadowMenu.autow:MenuElement({id = "usew", name = "Use [W] automatically", value = true})
    self.shadowMenu.autow:MenuElement({id = "usewhealth", name = "Min health to auto [W]", value = 30, min = 0, max = 100, identifier = "%"})

    -- JUNGLE CLEAR --
    self.shadowMenu:MenuElement({type = MENU, id = "jungleclear", name = "Jungle Clear"})
    self.shadowMenu.jungleclear:MenuElement({id = "useq", name = "Use [Q] in clear", value = true})
    self.shadowMenu.jungleclear:MenuElement({id = "usee", name = "Use [E] in clear", value = true})


    -- DRAWING SETTINGS --
    self.shadowMenu:MenuElement({type = MENU, id = "drawings", name = "Drawing Settings"})
    self.shadowMenu.drawings:MenuElement({id = "drawAutoW", name = "Draw if auto [W] is on", value = true})
    self.shadowMenu.drawings:MenuElement({id = "drawRSettings", name = "Draw if only [R] on combo if out of [Q] range is on", value = true})

end


function MasterYi:Draw()

    if self.shadowMenu.drawings.drawAutoW:Value() then
        Draw.Text("Auto Use W: ", 18, 200, 30, Draw.Color(255, 225, 255, 255))
            if self.shadowMenu.autow.usew:Value() then
                Draw.Text("ON", 18, 290, 30, Draw.Color(255, 0, 255, 0))
                else
                    Draw.Text("OFF", 18, 290, 30, Draw.Color(255, 255, 0, 0))
            end 
    end

    if self.shadowMenu.drawings.drawAutoW:Value() then
        Draw.Text("Use [R] if out of range: ", 18, 200, 60, Draw.Color(255, 225, 255, 255))
            if self.shadowMenu.combo.userrange:Value() then
                Draw.Text("ON", 18, 370, 60, Draw.Color(255, 0, 255, 0))
                else
                    Draw.Text("OFF", 18, 370, 60, Draw.Color(255, 255, 0, 0))
            end 
    end
end

function MasterYi:Tick()
    if myHero.dead or Game.IsChatOpen() or (ExtLibEvade and ExtLibEvade.Evading == true) then
        return
    end
    self:autoW()
    if orbwalker.Modes[0] then
        self:Combo()
    elseif orbwalker.Modes[3] then
        self:jungleclear()
    elseif orbwalker.Modes[1] then
        
    end
end

function MasterYi:autoW()
  	
        if self.shadowMenu.autow.usew:Value() and Ready(_W) then
            if myHero.health/myHero.maxHealth <= self.shadowMenu.autow.usewhealth:Value()/100 then
                Control.CastSpell(HK_W)
            end
        end

end

function MasterYi:jungleclear()

        for i = 1, Game.MinionCount() do
            local obj = Game.Minion(i)
            if obj.team ~= myHero.team then
                if obj ~= nil and obj.valid and obj.visible and not obj.dead then
                    if Ready(_Q) and self.shadowMenu.jungleclear.useq:Value() and obj and obj.team == 300 and obj.valid and obj.visible and not obj.dead and (obj.pos:DistanceTo(myHero.pos) < self.Q.Range) then
                        Control.CastSpell(HK_Q, obj)
                    end
                    if Ready(_E) and self.shadowMenu.jungleclear.usee:Value() and obj and obj.team == 300 and obj.valid and obj.visible and not obj.dead and (obj.pos:DistanceTo(myHero.pos) < self.Q.Range) then
                        Control.CastSpell(HK_E);
                    end
                end
            end
            
        end

end


function MasterYi:Combo()
    local target = TargetSelector:GetTarget(self.Q.Range, 1)
    if target == nil then return end
    if Ready(_Q) and target and IsValid(target) then
        if self.shadowMenu.combo.useq:Value() then
           self:CastQ(target)
        end														
    end

    local target = TargetSelector:GetTarget(self.Q.Range, 1)
    if target == nil then return end
    if Ready(_E) and target and IsValid(target) then
        if self.shadowMenu.combo.usee:Value() then
           Control.CastSpell(HK_E)
        end														
    end

    local target = TargetSelector:GetTarget(self.Q.Range, 1)
    if target == nil then return end
        if Ready(_R) and target and IsValid(target) then
            if self.shadowMenu.combo.user:Value() then
                Control.CastSpell(HK_R)
            end
        end   

end


function MasterYi:GotBuff(unit, buffname)
    for i = 0, unit.buffCount do
        local buff = unit:GetBuff(i)
        if buff and buff.name == buffname and buff.count > 0 then return buff.count end
    end
    return 0
end

function MasterYi:CastQ(target)
    if Ready(_Q) and lastQ + 350 < GetTickCount() and orbwalker:CanMove() then
        local Pred = GamsteronPrediction:GetPrediction(target, self.Q, myHero)
        if Pred.Hitchance >= _G.HITCHANCE_NORMAL then
            Control.CastSpell(HK_Q, Pred.CastPosition)
            lastQ = GetTickCount()
        end
    end
end
--[[
   _   _   _   _   _   _  
  / \ / \ / \ / \ / \ / \ 
 ( L | e | e | S | i | n )
  \_/ \_/ \_/ \_/ \_/ \_/ 

--]]
   
class "LeeSin"
function LeeSin:__init()
    
    self.Q = {_G.SPELLTYPE_LINE, Delay = 0.225, Radius = 60, Range = 1200, Speed = 1800, Collision = true, MaxCollision = 0, CollisionTypes = {_G.COLLISION_MINION}}
    self.Q2 = {_G.SPELLTYPE_CIRCLE, Delay = 0.225, Range = 1300}

    self.W = {_G.SPELLTYPE_CIRCLE, Delay = 0.225, Range = 700, Speed = 1500}
    self.W2 = {_G.SPELLTYPE_CIRCLE, Delay = 0.225, Range = 350, Speed = 1500}

    self.E = {_G.SPELLTYPE_CIRCLE, Delay = 0.225, Range = 425, Speed = 0}
    self.E2 = {_G.SPELLTYPE_CIRCLE, Delay = 0.225, Range = 575, Speed = 0}

    self.R = {_G.SPELLTYPE_CIRCLE, Delay = 0.225, Range = 375, Speed = 1500}

    OnAllyHeroLoad(function(hero)
        Allys[hero.networkID] = hero
    end)
    
    OnEnemyHeroLoad(function(hero)
        Enemys[hero.networkID] = hero
    end)    
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
    ["LeeSinIcon"] = "https://vignette.wikia.nocookie.net/leagueoflegends/images/1/16/Lee_Sin_OriginalSquare.png",
    ["Q"] = "https://vignette.wikia.nocookie.net/leagueoflegends/images/7/74/Sonic_Wave.png",
    ["W"] = "https://vignette.wikia.nocookie.net/leagueoflegends/images/f/f1/Safeguard.png",
    ["E"] = "https://vignette.wikia.nocookie.net/leagueoflegends/images/b/bb/Tempest.png",
    ["R"] = "https://vignette.wikia.nocookie.net/leagueoflegends/images/a/aa/Dragon%27s_Rage.png",
    ["EXH"] = "https://vignette.wikia.nocookie.net/leagueoflegends/images/4/4a/Exhaust.png",
    ["IGN"] = "https://vignette.wikia.nocookie.net/leagueoflegends/images/f/f4/Ignite.png"
    }

function LeeSin:LoadMenu()
    self.shadowMenu = MenuElement({type = MENU, id = "shadowLeeSin", name = "Shadow LeeSin"})


    -- COMBO --
    self.shadowMenu:MenuElement({type = MENU, id = "combo", name = "Combo"})
    self.shadowMenu.combo:MenuElement({id = "useq", name = "Use [Q] in combo", value = true})
    self.shadowMenu.combo:MenuElement({id = "usee", name = "Use [E] in combo", value = true})
    self.shadowMenu.combo:MenuElement({id = "userinsec", name = "Use [R] in combo", value = true})

    -- AUTO W --
    self.shadowMenu:MenuElement({type = MENU, id = "autow", name = "Auto W"})
    self.shadowMenu.autow:MenuElement({id = "usew", name = "Use [W] automatically", value = true})
    self.shadowMenu.autow:MenuElement({id = "usewhealth", name = "Min health to auto [W]", value = 30, min = 0, max = 100, identifier = "%"})

    -- AUTO R --
    self.shadowMenu:MenuElement({type = MENU, id = "autor", name = "Auto R"})
    self.shadowMenu.autor:MenuElement({id = "user", name = "Use [R] automatically", value = true})
    self.shadowMenu.autor:MenuElement({id = "useronks", name = "Use [R] on killable", value = true})
    self.shadowMenu.autor:MenuElement({id = "userpanic", name = "Use [R] on panic", value = true})
    self.shadowMenu.autor:MenuElement({id = "userpanichealth", name = "Min health to auto [R] on panic", value = 30, min = 0, max = 100, identifier = "%"})

    -- JUNGLE CLEAR --
    self.shadowMenu:MenuElement({type = MENU, id = "jungleclear", name = "Jungle Clear"})
    self.shadowMenu.jungleclear:MenuElement({id = "useq", name = "Use [Q] in clear", value = true})
    self.shadowMenu.jungleclear:MenuElement({id = "usee", name = "Use [E] in clear", value = true})


    -- DRAWING SETTINGS --
    self.shadowMenu:MenuElement({type = MENU, id = "drawings", name = "Drawing Settings"})
    self.shadowMenu.drawings:MenuElement({id = "drawAutoW", name = "Draw if auto [W] is on", value = true})
    self.shadowMenu.drawings:MenuElement({id = "drawAutoRkillable", name = "Draw if auto [R] on killable is on", value = true})
    self.shadowMenu.drawings:MenuElement({id = "drawAutoRpanic", name = "Draw if auto [R] on low hp", value = true})

end


function LeeSin:Draw()

    if self.shadowMenu.drawings.drawAutoW:Value() then
        Draw.Text("Auto Use W: ", 18, 200, 30, Draw.Color(255, 225, 255, 255))
            if self.shadowMenu.autow.usew:Value() then
                Draw.Text("ON", 18, 370, 30, Draw.Color(255, 0, 255, 0))
                else
                    Draw.Text("OFF", 18, 370, 30, Draw.Color(255, 255, 0, 0))
            end 
    end

    if self.shadowMenu.drawings.drawAutoRkillable:Value() then
        Draw.Text("Use [R] if killable: ", 18, 200, 60, Draw.Color(255, 225, 255, 255))
            if self.shadowMenu.autor.useronks:Value() then
                Draw.Text("ON", 18, 370, 60, Draw.Color(255, 0, 255, 0))
                else
                    Draw.Text("OFF", 18, 370, 60, Draw.Color(255, 255, 0, 0))
            end 
    end

    if self.shadowMenu.drawings.drawAutoRpanic:Value() then
        Draw.Text("Use [R] to save self: ", 18, 200, 90, Draw.Color(255, 225, 255, 255))
            if self.shadowMenu.autor.userpanic:Value() then
                Draw.Text("ON", 18, 370, 90, Draw.Color(255, 0, 255, 0))
                else
                    Draw.Text("OFF", 18, 370, 90, Draw.Color(255, 255, 0, 0))
            end 
    end
end

function LeeSin:Tick()
    if myHero.dead or Game.IsChatOpen() or (ExtLibEvade and ExtLibEvade.Evading == true) then
        return
    end
    self:autoW()
    self:autoR()
    if orbwalker.Modes[0] then
        self:Combo()
    elseif orbwalker.Modes[3] then
        self:jungleclear()
    elseif orbwalker.Modes[1] then
        
    end
end

local keybindings = { [ITEM_1] = HK_ITEM_1, [ITEM_2] = HK_ITEM_2, [ITEM_3] = HK_ITEM_3, [ITEM_4] = HK_ITEM_4, [ITEM_5] = HK_ITEM_5, [ITEM_6] = HK_ITEM_6, [ITEM_7] = HK_ITEM_7}
function GetInventorySlotItem(itemID)
    assert(type(itemID) == "number", "GetInventorySlotItem: wrong argument types (<number> expected)")
    for _, j in pairs({ITEM_1, ITEM_2, ITEM_3, ITEM_4, ITEM_5, ITEM_6, ITEM_7}) do
        if myHero:GetItemData(j).itemID == itemID and myHero:GetSpellData(j).currentCd == 0 then return j end
    end
    return nil
end


function LeeSin:autoW()
    local target = TargetSelector:GetTarget(self.R.Range, 1)
        if self.shadowMenu.autow.usew:Value() and Ready(_W) then
            if myHero.health/myHero.maxHealth <= self.shadowMenu.autow.usewhealth:Value()/100 then
                Control.CastSpell(HK_W, myHero.pos)
            end
        end

end

function LeeSin:autoR()
local target = TargetSelector:GetTarget(self.R.Range, 1)
    if target and IsValid(target)then
        local rdmg = getdmg("R", target, myHero)
        if self.shadowMenu.autor.user:Value() and Ready(_R) then
            if self.shadowMenu.autor.useronks:Value() and rdmg > target.health then
                self:CastR(target)
            end
        end
    end
end

function LeeSin:jungleclear()

        for i = 1, Game.MinionCount() do
            local obj = Game.Minion(i)
            if obj.team ~= myHero.team then
                if obj ~= nil and obj.valid and obj.visible and not obj.dead then
                    if Ready(_Q) and self.shadowMenu.jungleclear.useq:Value() and obj and obj.team == 300 and obj.valid and obj.visible and not obj.dead and (obj.pos:DistanceTo(myHero.pos) < self.Q.Range) then
                        Control.CastSpell(HK_Q, obj)
                    end
                    if Ready(_E) and self.shadowMenu.jungleclear.usee:Value() and obj and obj.team == 300 and obj.valid and obj.visible and not obj.dead and (obj.pos:DistanceTo(myHero.pos) < self.E.Range) then
                        Control.CastSpell(HK_E);
                    end
                end
            end
            
        end

end


function LeeSin:Combo()
    local target = TargetSelector:GetTarget(self.Q.Range, 1)
    if target == nil then return end
    if Ready(_Q) and target and IsValid(target) then
        if self.shadowMenu.combo.useq:Value() then
           self:CastQ(target)
        end														
    end

    local target = TargetSelector:GetTarget(self.W.Range, 1)
    if target == nil then return end 
    if Ready(_W) and target and IsValid(target) then
        print(castedWard)
        if castedWard == false then
        local posBehind = myHero.pos:Extended(target.pos, target.distance + 300)
        end
        local castwPos = posBehind
        local ward = GetInventorySlotItem(3340) or GetInventorySlotItem(2055) or GetInventorySlotItem(2049) or GetInventorySlotItem(2301) or GetInventorySlotItem(2302) or GetInventorySlotItem(2303) or GetInventorySlotItem(3711)
        if ward and myHero.pos:DistanceTo(target.pos) <= 100 then
            Control.CastSpell(keybindings[ward], posBehind)
            castedWard = true
        end
        if castedWard == true then
            Control.CastSpell(HK_W, castwPos)
        end
    end 


    local target = TargetSelector:GetTarget(self.R.Range, 1)
    if target == nil then return end
    if Ready(_R) and target and IsValid(target) then
        if self.shadowMenu.combo.userinsec:Value() then
        DelayAction(function() self:CastR(target) end, 0.05)
        end														
    end

    local target = TargetSelector:GetTarget(self.E.Range, 1)
    if target == nil then return end
    if Ready(_E) and target and IsValid(target) then
        if self.shadowMenu.combo.usee:Value() then
           self:CastE(target)
        end														
    end
end


function LeeSin:GotBuff(unit, buffname)
    for i = 0, unit.buffCount do
        local buff = unit:GetBuff(i)
        if buff and buff.name == buffname and buff.count > 0 then return buff.count end
    end
    return 0
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
        local Pred = GamsteronPrediction:GetPrediction(target, self.R, myHero)
        if Pred.Hitchance >= _G.HITCHANCE_HIGH then
            Control.CastSpell(HK_R, Pred.CastPosition)
            lastR = GetTickCount()
        end
    end
end

function LeeSin:CastE(target)
    if Ready(_E) and lastE + 350 < GetTickCount() and orbwalker:CanMove() then
        local Pred = GamsteronPrediction:GetPrediction(target, self.E, myHero)
        if Pred.Hitchance >= _G.HITCHANCE_NORMAL then
            Control.CastSpell(HK_E, Pred.CastPosition)
            lastE = GetTickCount()
        end
    end
end

--[[
   _   _   _   _   _  
  / \ / \ / \ / \ / \ 
 ( E | L | I | S | E )
  \_/ \_/ \_/ \_/ \_/ 
]]

class "Elise"
function Elise:__init()
    
    self.QH = {Type = _G.SPELLTYPE_CIRCLE, Range = 625, Radius = 0, Speed = 2200, Collision = false}
    self.WH = {Type = _G.SPELLTYPE_LINE, Range = 950, Radius = 100, Speed = 5000, Collision = true, MaxCollision = 0, CollisionTypes = {_G.COLLISION_MINION}}
    self.EH = {Type = _G.SPELLTYPE_LINE, Range = 1075, Radius = 55, Speed = 1600, Collision = true, MaxCollision = 0, CollisionTypes = {_G.COLLISION_MINION}}

    self.QS = {Type = _G.SPELLTYPE_CIRCLE, Range = 475, Radius = 0, Speed = 20, Collision = false}
    self.ES = {Type = _G.SPELLTYPE_LINE, Range = 750, Radius = 0, Speed = 20}
    

    OnAllyHeroLoad(function(hero)
        Allys[hero.networkID] = hero
    end)
    
    OnEnemyHeroLoad(function(hero)
        Enemys[hero.networkID] = hero
    end)    
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
    ["EliseIcon"] = "https://vignette.wikia.nocookie.net/leagueoflegends/images/1/1b/Elise_OriginalSquare.png",
    ["Q"] = "https://vignette.wikia.nocookie.net/leagueoflegends/images/2/2b/Neurotoxin.png",
    ["W"] = "https://vignette.wikia.nocookie.net/leagueoflegends/images/6/60/Volatile_Spiderling.png",
    ["E"] = "https://vignette.wikia.nocookie.net/leagueoflegends/images/0/02/Cocoon.png",
    ["R"] = "https://vignette.wikia.nocookie.net/leagueoflegends/images/2/2b/Spider_Form.png",
    ["EXH"] = "https://vignette2.wikia.nocookie.net/leagueoflegends/images/4/4a/Exhaust.png"
    }

function Elise:LoadMenu()
    self.shadowMenu = MenuElement({type = MENU, id = "shadowElise", name = "Shadow Elise"})


    -- COMBO --
    self.shadowMenu:MenuElement({type = MENU, id = "combo", name = "Combo"})
    self.shadowMenu.combo:MenuElement({id = "combo1", name = "Use Human E > W > Q > Spider E > Q > W", value = true})
    self.shadowMenu.combo:MenuElement({id = "combor", name = "Switch to R manually after human combo done?", value = true})

    -- Auto Stun --
    self.shadowMenu:MenuElement({type = MENU, id = "autostun", name = "Auto Stun Setting"})
    self.shadowMenu.autostun:MenuElement({id = "useautostun", name = "Use auto stun?", value = true})
    self.shadowMenu.autostun:MenuElement({id = "changeform", name = "Automatically change from spdier form?", value = true})

    -- Manual Stun --
    self.shadowMenu:MenuElement({type = MENU, id = "manualstun", name = "Manual Stun Setting"})
    self.shadowMenu.manualstun:MenuElement({id = "usemanualstun", name = "Use manual stun?", value = true})


    -- JUNGLE CLEAR --
    self.shadowMenu:MenuElement({type = MENU, id = "jungleclear", name = "Jungle Clear"})
    self.shadowMenu.jungleclear:MenuElement({id = "combo1", name = "Use Human E > W > Q > Spider E > Q > W", value = true})

     -- JUNGLE KILLSTEAL --
    self.shadowMenu:MenuElement({type = MENU, id = "junglekillsteal", name = "Jungle Steal"})
    self.shadowMenu.junglekillsteal:MenuElement({id = "W", name = "Use W in Jungle Steal", value = true})

    -- DRAWING SETTINGS --
    self.shadowMenu:MenuElement({type = MENU, id = "drawings", name = "Drawing Settings"})
    self.shadowMenu.drawings:MenuElement({id = "drawAutoE", name = "Draw if auto [E] is on", value = true})
    self.shadowMenu.drawings:MenuElement({id = "drawAutoForm", name = "Draw if auto [R] is on with Auto stun", value = true})
    self.shadowMenu.drawings:MenuElement({id = "drawManualE", name = "Draw if manual [E] is on", value = true})

end


function Elise:Draw()

    if self.shadowMenu.drawings.drawAutoE:Value() then
        Draw.Text("Auto Use E: ", 18, 200, 30, Draw.Color(255, 225, 255, 255))
            if self.shadowMenu.autostun.useautostun:Value() then
                Draw.Text("ON", 18, 285, 30, Draw.Color(255, 0, 255, 0))
                else
                    Draw.Text("OFF", 18, 285, 30, Draw.Color(255, 255, 0, 0))
            end 
    end

    if self.shadowMenu.drawings.drawAutoForm:Value() then
        Draw.Text("Auto Use R if can stun: ", 18, 200, 55, Draw.Color(255, 225, 255, 255))
            if self.shadowMenu.autostun.changeform:Value() then
                Draw.Text("ON", 18, 365, 55, Draw.Color(255, 0, 255, 0))
                else
                    Draw.Text("OFF", 18, 365, 55, Draw.Color(255, 255, 0, 0))
            end 
    end

    if self.shadowMenu.drawings.drawManualE:Value() then
        Draw.Text("Manual E with Harass Key: ", 18, 200, 80, Draw.Color(255, 225, 255, 255))
            if self.shadowMenu.manualstun.usemanualstun:Value() then
                Draw.Text("ON", 18, 390, 80, Draw.Color(255, 0, 255, 0))
                else
                    Draw.Text("OFF", 18, 390, 80, Draw.Color(255, 255, 0, 0))
            end 
    end

end

function Elise:Tick()
    if myHero.dead or Game.IsChatOpen() or (ExtLibEvade and ExtLibEvade.Evading == true) then
        return
    end
    --self:junglekillsteal()
        self:autostun()
    if orbwalker.Modes[0] then
        self:Combo()
    elseif orbwalker.Modes[3] then
        self:jungleclear()
    elseif orbwalker.Modes[1] then
        self:manualstun()
    end
end

function Elise:autostun()
    local target = TargetSelector:GetTarget(self.EH.Range, 1)
    if target and IsValid(target) then
    local d = myHero.pos:DistanceTo(target.pos)
    if Ready(_R) and self.shadowMenu.autostun.changeform:Value() and self.shadowMenu.autostun.useautostun:Value() and (myHero:GetSpellData(_Q).name == "EliseSpiderQCast")then
        Control.CastSpell(HK_R)
    end
    if Ready(_E) and self.shadowMenu.autostun.useautostun:Value() and self.shadowMenu.autostun.changeform:Value() and d < 1075 then
        self:CastEH(target)
    end
    end

end

function Elise:manualstun()
    local target = TargetSelector:GetTarget(self.EH.Range, 1)
    if target and IsValid(target) then
    local d = myHero.pos:DistanceTo(target.pos)
    if Ready(_E) and self.shadowMenu.manualstun.usemanualstun:Value() and d < 1075 then
        self:CastEH(target)
    end
    end
end

function Elise:jungleclear()

   -- if (myHero:GetSpellData(_R).name == "EliseRSpider") 

    if self.shadowMenu.jungleclear.combo1:Value() then 
        for i = 1, Game.MinionCount() do
            local obj = Game.Minion(i)
            if obj.team ~= myHero.team then
                if obj ~= nil and obj.valid and obj.visible and not obj.dead then
                    if Ready(_E) and self.shadowMenu.jungleclear.combo1:Value() and obj and obj.team == 300 and obj.valid and obj.visible and not obj.dead and (obj.pos:DistanceTo(myHero.pos) < self.EH.Range) then
                        Control.CastSpell(HK_E, obj);
                    end
                    if Ready(_W) and self.shadowMenu.jungleclear.combo1:Value() and obj and obj.team == 300 and obj.valid and obj.visible and not obj.dead and (obj.pos:DistanceTo(myHero.pos) < self.WH.Range) then
                        Control.CastSpell(HK_W, obj);
                    end
                    if Ready(_Q) and self.shadowMenu.jungleclear.combo1:Value() and obj and obj.team == 300 and obj.valid and obj.visible and not obj.dead and (obj.pos:DistanceTo(myHero.pos) < self.QH.Range) then
                        Control.CastSpell(HK_Q, obj);
                    end
                    if Ready(_R) and self.shadowMenu.jungleclear.combo1:Value() and obj and obj.team == 300 and obj.valid and obj.visible and not obj.dead and (obj.pos:DistanceTo(myHero.pos) < self.QH.Range) then
                        Control.CastSpell(HK_R);
                    end
                    if Ready(_E) and self.shadowMenu.jungleclear.combo1:Value() and obj and obj.team == 300 and obj.valid and obj.visible and not obj.dead and (obj.pos:DistanceTo(myHero.pos) < self.ES.Range) then
                        Control.CastSpell(HK_E);
                        Control.CastSpell(HK_E, target);
                    end
                end
            end
            
        end
    end

end


function Elise:Combo()
    local target = TargetSelector:GetTarget(self.EH.Range, 1)
    if target == nil then return end
    if Ready(_E) and target and IsValid(target) then
        if self.shadowMenu.combo.combo1:Value() and (myHero:GetSpellData(_E).name == "EliseHumanE") then
           self:CastEH(target)
        end														
    end

    local target = TargetSelector:GetTarget(self.WH.Range, 1)
    if target == nil then return end
    local d = myHero.pos:DistanceTo(target.pos)
    if Ready(_W) and target and IsValid(target) then
        if self.shadowMenu.combo.combo1:Value() and (myHero:GetSpellData(_W).name == "EliseHumanW") then
           self:CastWH(target)
        end														
    end

    local target = TargetSelector:GetTarget(self.QH.Range, 1)
    if target == nil then return end
    if Ready(_Q) and target and IsValid(target) then
        if self.shadowMenu.combo.combo1:Value() and (myHero:GetSpellData(_Q).name == "EliseHumanQ") then
           Control.CastSpell(HK_Q, target)
        end														
    end

    if Ready(_R) then
        if self.shadowMenu.combo.combor:Value() and (myHero:GetSpellData(_R).name == "EliseR") then
            Control.CastSpell(HK_R)
        end
    end 

 -- SPIDER --

    local target = TargetSelector:GetTarget(self.ES.Range, 1)
    if target == nil then return end
    if Ready(_E) and target and IsValid(target) then
        if self.shadowMenu.combo.combo1:Value() and (myHero:GetSpellData(_E).name == "EliseSpiderEInitial") then
            Control.CastSpell(HK_E)
            Control.CastSpell(HK_E, target)
        end														
    end

    
    local target = TargetSelector:GetTarget(self.QS.Range, 1)
    if target == nil then return end
    if Ready(_Q) and target and IsValid(target) then
        if self.shadowMenu.combo.combo1:Value() and (myHero:GetSpellData(_Q).name == "EliseSpiderQCast") then
            Control.CastSpell(HK_Q, target)
        end														
    end

    local target = TargetSelector:GetTarget(self.QS.Range, 1)
    if target == nil then return end
    if Ready(_W) and target and IsValid(target) then
        if self.shadowMenu.combo.combo1:Value() and (myHero:GetSpellData(_W).name == "EliseSpiderW") then
            Control.CastSpell(HK_W)
        end														
    end



end

function Elise:junglekillsteal()
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

function Elise:GotBuff(unit, buffname)
    for i = 0, unit.buffCount do
        local buff = unit:GetBuff(i)
        if buff and buff.name == buffname and buff.count > 0 then return buff.count end
    end
    return 0
end

function Elise:CastWH(target)
    if Ready(_W) and lastW + 350 < GetTickCount() and orbwalker:CanMove() then
        local Pred = GamsteronPrediction:GetPrediction(target, self.WH, myHero)
        if Pred.Hitchance >= _G.HITCHANCE_NORMAL then
            Control.CastSpell(HK_W, Pred.CastPosition)
            lastW = GetTickCount()
        end
    end
end

-- HUMAN CASTS --
function Elise:CastEH(target)
    if Ready(_E) and lastE + 350 < GetTickCount() and orbwalker:CanMove() then
        local Pred = GamsteronPrediction:GetPrediction(target, self.EH, myHero)
        if Pred.Hitchance >= _G.HITCHANCE_HIGH then
            Control.CastSpell(HK_E, Pred.CastPosition)
            lastE = GetTickCount()
        end
    end
end

function Elise:CastWS(target)
    if Ready(_W) and lastW + 350 < GetTickCount() and orbwalker:CanMove() then
        local Pred = GamsteronPrediction:GetPrediction(target, self.WS, myHero)
        if Pred.Hitchance >= _G.HITCHANCE_NORMAL then
            Control.CastSpell(HK_W, Pred.CastPosition)
            lastW = GetTickCount()
        end
    end
end


-- SPIDER CASTS --
function Elise:CastES(target)
    if Ready(_E) and lastE + 350 < GetTickCount() and orbwalker:CanMove() then
        local Pred = GamsteronPrediction:GetPrediction(target, self.ES, myHero)
        if Pred.Hitchance >= _G.HITCHANCE_HIGH then
            Control.CastSpell(HK_E, Pred.CastPosition)
            lastE = GetTickCount()
        end
    end
end

function Elise:CastR(target)
    if Ready(_R) and lastR + 350 < GetTickCount() and orbwalker:CanMove() then
        local Pred = GamsteronPrediction:GetPrediction(target, self.R, myHero)
        if Pred.Hitchance >= _G.HITCHANCE_NORMAL then
            Control.CastSpell(HK_R, Pred.CastPosition)
            lastR = GetTickCount()
        end
    end
end

--[[
   _   _   _   _   _   _   _   _  
  / \ / \ / \ / \ / \ / \ / \ / \ 
 ( D | r | . | M | u | n | d | o )
  \_/ \_/ \_/ \_/ \_/ \_/ \_/ \_/ 
]]
class "DrMundo"
function DrMundo:__init()
    
    self.Q = {Type = _G.SPELLTYPE_LINE, Delay = 0.25, Radius = 60, Range = 975, Speed = 1850, Collision = true, MaxCollision = 0, CollisionTypes = {_G.COLLISION_MINION}}
    self.W = {Type = _G.SPELLTYPE_CIRCLE, Delay = 0, Radius = 162.5, Range = 800, Speed = 0}
    

    OnAllyHeroLoad(function(hero)
        Allys[hero.networkID] = hero
    end)
    
    OnEnemyHeroLoad(function(hero)
        Enemys[hero.networkID] = hero
    end)    
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
    ["DrMundoIcon"] = "https://vignette.wikia.nocookie.net/leagueoflegends/images/c/c3/Dr._Mundo_OriginalSquare.png",
    ["Q"] = "https://vignette.wikia.nocookie.net/leagueoflegends/images/f/f2/Infected_Cleaver.png",
    ["W"] = "https://vignette.wikia.nocookie.net/leagueoflegends/images/5/5d/Burning_Agony.png",
    ["E"] = "https://vignette.wikia.nocookie.net/leagueoflegends/images/9/95/Masochism.png",
    ["R"] = "https://vignette.wikia.nocookie.net/leagueoflegends/images/8/81/Sadism.png",
    ["EXH"] = "https://vignette.wikia.nocookie.net/leagueoflegends/images/4/4a/Exhaust.png",
    ["IGN"] = "https://vignette.wikia.nocookie.net/leagueoflegends/images/f/f4/Ignite.png"
    }

function DrMundo:LoadMenu()
    self.shadowMenu = MenuElement({type = MENU, id = "shadowDrMundo", name = "Shadow DrMundo"})


    -- COMBO --
    self.shadowMenu:MenuElement({type = MENU, id = "combo", name = "Combo"})
    self.shadowMenu.combo:MenuElement({id = "useq", name = "Use [Q] in combo", value = true})
    self.shadowMenu.combo:MenuElement({id = "usew", name = "Use [W] in combo", value = true})
    self.shadowMenu.combo:MenuElement({id = "usee", name = "Use [E] in combo", value = true})
    self.shadowMenu.combo:MenuElement({id = "user", name = "Use [R] in combo", value = true})
    self.shadowMenu.combo:MenuElement({id = "userhp", name = "Minimum HP to use [R]", value = 30, min = 0, max = 100, identifier = "%"})

    -- AUTO Q --
    self.shadowMenu:MenuElement({type = MENU, id = "autoq", name = "Auto Q"})
    self.shadowMenu.autoq:MenuElement({id = "useq", name = "Use [Q] automatically", value = true})
    self.shadowMenu.autoq:MenuElement({id = "useqmanual", name = "Use [Q] on keydown", key = string.byte("T"), value = true})


    -- JUNGLE CLEAR --
    self.shadowMenu:MenuElement({type = MENU, id = "jungleclear", name = "Jungle Clear"})
    self.shadowMenu.jungleclear:MenuElement({id = "useq", name = "Use [Q] in clear", value = true})
    self.shadowMenu.jungleclear:MenuElement({id = "usee", name = "Use [E] in clear", value = true})
    self.shadowMenu.jungleclear:MenuElement({id = "usew", name = "Use [W] in clear", value = true})

    -- AUTO R --
    self.shadowMenu:MenuElement({type = MENU, id = "autor", name = "Auto R Settings"})
    self.shadowMenu.autor:MenuElement({id = "useautor", name = "Use auto [R] ?", value = true})
    self.shadowMenu.autor:MenuElement({id = "autorhp", name = "Activate R when at what % HP", value = 30, min = 0, max = 100, identifier = "%"})

    -- DRAWING SETTINGS --
    self.shadowMenu:MenuElement({type = MENU, id = "drawings", name = "Drawing Settings"})
    self.shadowMenu.drawings:MenuElement({id = "drawAutoQ", name = "Draw if auto [Q] is on", value = true})
    self.shadowMenu.drawings:MenuElement({id = "drawManualQ", name = "Draw if manual [Q] is on", value = true})

    -- SUMMONER SETTINGS --
    self.shadowMenu:MenuElement({type = MENU, id = "SummonerSettings", name = "Summoner Settings"})
    if myHero:GetSpellData(SUMMONER_1).name == "SummonerDot" then
        self.shadowMenu.SummonerSettings:MenuElement({id = "UseIgnite", name = "Use [Ignite] if killable?", value = true})
    elseif myHero:GetSpellData(SUMMONER_2).name == "SummonerDot" then
        self.shadowMenu.SummonerSettings:MenuElement({id = "UseIgnite", name = "Use [Ignite] if killable?", value = true}) 
    end

    if myHero:GetSpellData(SUMMONER_1).name == "SummonerExhaust" then
        self.shadowMenu.SummonerSettings:MenuElement({id = "UseExhaust", name = "Use [Exhaust] on engage?", value = true})
    elseif myHero:GetSpellData(SUMMONER_2).name == "SummonerExhaust" then
        self.shadowMenu.SummonerSettings:MenuElement({id = "UseExhaust", name = "Use [Exhaust] on engage?", value = true}) 
    end

end


function DrMundo:Draw()

    if self.shadowMenu.drawings.drawAutoQ:Value() then
        Draw.Text("Auto Use Q: ", 18, 200, 30, Draw.Color(255, 225, 255, 255))
            if self.shadowMenu.autoq.useq:Value() then
                Draw.Text("ON", 18, 370, 30, Draw.Color(255, 0, 255, 0))
                else
                    Draw.Text("OFF", 18, 370, 30, Draw.Color(255, 255, 0, 0))
            end 
    end

end

function DrMundo:Tick()
    if myHero.dead or Game.IsChatOpen() or (ExtLibEvade and ExtLibEvade.Evading == true) then
        return
    end
    self:AutoR()
    self:autoQ()
    self:AutoSummoners()
    if orbwalker.Modes[0] then
        self:Combo()
    elseif orbwalker.Modes[3] then
        self:jungleclear()
    elseif orbwalker.Modes[1] then
        
    end
end

function DrMundo:AutoR()
    local decimalhealthstring = "." .. self.shadowMenu.autor.autorhp:Value()
    local decimalhealth = myHero.maxHealth * decimalhealthstring

    if self.shadowMenu.autor.useautor:Value() and myHero.health <= decimalhealth and Ready(_R) then
        Control.CastSpell(HK_R)
    end
end

function DrMundo:AutoSummoners()
    -- IGNITE --
    local target = TargetSelector:GetTarget(self.Q.Range, 1)
    if target and IsValid(target) then
        local ignDmg = getdmg("IGNITE", target, myHero)
        if myHero:GetSpellData(SUMMONER_1).name == "SummonerDot" and Ready(SUMMONER_1) and (target.health < ignDmg ) then
            Control.CastSpell(HK_SUMMONER_1, target)
        elseif myHero:GetSpellData(SUMMONER_2).name == "SummonerDot" and Ready(SUMMONER_2) and (target.health < ignDmg ) then
            Control.CastSpell(HK_SUMMONER_2, target)
        end
    end
end


function DrMundo:autoQ()
    local target = TargetSelector:GetTarget(self.Q.Range, 1)
    if target and IsValid(target) then
        if self.shadowMenu.autoq.useq:Value() and Ready(_Q) then
            self:CastQ(target)
        end

        if self.shadowMenu.autoq.useqmanual:Value() and Ready(_Q) then
            self:CastQ(target)
        end
    end

end

function DrMundo:jungleclear()

        for i = 1, Game.MinionCount() do
            local obj = Game.Minion(i)
            if obj.team ~= myHero.team then
                if obj ~= nil and obj.valid and obj.visible and not obj.dead then
                    if Ready(_Q) and self.shadowMenu.jungleclear.useq:Value() and obj and obj.team == 300 and obj.valid and obj.visible and not obj.dead and (obj.pos:DistanceTo(myHero.pos) < self.Q.Range) then
                        Control.CastSpell(HK_Q, obj)
                    end
                    if Ready(_E) and self.shadowMenu.jungleclear.usee:Value() and obj and obj.team == 300 and obj.valid and obj.visible and not obj.dead and (obj.pos:DistanceTo(myHero.pos) < self.Q.Range) then
                        Control.CastSpell(HK_E);
                    end
                    if Ready(_W) and myHero:GetSpellData(_W).toogleState ~= 2 and self.shadowMenu.jungleclear.usew:Value() and obj and obj.team == 300 and obj.valid and obj.visible and not obj.dead and (obj.pos:DistanceTo(myHero.pos) < self.W.Range) then
                        Control.CastSpell(HK_W);
                    end
                end
            end
            
        end

end


function DrMundo:Combo()
    local target = TargetSelector:GetTarget(self.Q.Range, 1)
    if target == nil then return end
    if Ready(_Q) and target and IsValid(target) then
        if self.shadowMenu.combo.useq:Value() then
           self:CastQ(target)
        end														
    end

    local target = TargetSelector:GetTarget(self.W.Range, 1)
    if target == nil then return end
    if Ready(_W) and target and IsValid(target) and myHero:GetSpellData(_W).toogleState ~= 2 then
        if self.shadowMenu.combo.usew:Value() then
           Control.CastSpell(HK_W)
        end														
    end

    local target = TargetSelector:GetTarget(self.Q.Range, 1)
    if target == nil then return end
    if Ready(_E) and target and IsValid(target) then
        if self.shadowMenu.combo.usee:Value() then
           Control.CastSpell(HK_E)
        end														
    end


end


function DrMundo:GotBuff(unit, buffname)
    for i = 0, unit.buffCount do
        local buff = unit:GetBuff(i)
        if buff and buff.name == buffname and buff.count > 0 then return buff.count end
    end
    return 0
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
        if Pred.Hitchance >= _G.HITCHANCE_HIGH then
            Control.CastSpell(HK_R, Pred.CastPosition)
            lastR = GetTickCount()
        end
    end
end

function DrMundo:CastE(target)
    if Ready(_E) and lastE + 350 < GetTickCount() and orbwalker:CanMove() then
        local Pred = GamsteronPrediction:GetPrediction(target, self.E, myHero)
        if Pred.Hitchance >= _G.HITCHANCE_NORMAL then
            Control.CastSpell(HK_E, Pred.CastPosition)
            lastE = GetTickCount()
        end
    end
end
--[[



]]

class "Nocturne"
function Nocturne:__init()
    
    self.Q = {Type = _G.SPELLTYPE_LINE, Delay = 0.25, Radius = 100, Range = 1200, Speed = 1600, Collision = false}
    self.W = {Type = _G.SPELLTYPE_CIRCLE, Delay = 0.25, Radius = 800, Range = 800, Speed = 1400, Collision = false}
    self.E = {Type = _G.SPELLTYPE_CIRCLE, Delay = 0.25, Radius = 0, Range = 475, Speed = 0, Collision = true, MaxCollision = 0, CollisionTypes = {_G.COLLISION_MINION}}
    self.R = {Type = _G.SPELLTYPE_CIRCLE, Delay = 0.50, Radius = 10000, Range = ({2500, 3250, 4000})[GetCastLevel(myHero, _R)], Speed = 2000}
    

    OnAllyHeroLoad(function(hero)
        Allys[hero.networkID] = hero
    end)
    
    OnEnemyHeroLoad(function(hero)
        Enemys[hero.networkID] = hero
    end)    
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
    ["NocturneIcon"] = "https://vignette.wikia.nocookie.net/leagueoflegends/images/a/a9/Nocturne_OriginalSquare.png",
    ["Q"] = "https://vignette.wikia.nocookie.net/leagueoflegends/images/0/09/Duskbringer.png",
    ["W"] = "https://vignette.wikia.nocookie.net/leagueoflegends/images/c/c2/Shroud_of_Darkness.png",
    ["E"] = "https://vignette.wikia.nocookie.net/leagueoflegends/images/f/f8/Unspeakable_Horror.png",
    ["R"] = "https://vignette.wikia.nocookie.net/leagueoflegends/images/8/8d/Paranoia.png",
    ["EXH"] = "https://vignette.wikia.nocookie.net/leagueoflegends/images/4/4a/Exhaust.png",
    ["IGN"] = "https://vignette.wikia.nocookie.net/leagueoflegends/images/f/f4/Ignite.png"
    }

function Nocturne:LoadMenu()
    self.shadowMenu = MenuElement({type = MENU, id = "shadowNocturne", name = "Shadow Nocturne"})


    -- COMBO --
    self.shadowMenu:MenuElement({type = MENU, id = "combo", name = "Combo"})
    self.shadowMenu.combo:MenuElement({id = "useq", name = "Use [Q] in combo", value = true})
    self.shadowMenu.combo:MenuElement({id = "usee", name = "Use [E] in combo", value = true})
    self.shadowMenu.combo:MenuElement({id = "user", name = "Use [R] in combo", value = true})

    -- JUNGLE CLEAR --
    self.shadowMenu:MenuElement({type = MENU, id = "jungleclear", name = "Jungle Clear"})
    self.shadowMenu.jungleclear:MenuElement({id = "useq", name = "Use [Q] in clear", value = true})
    self.shadowMenu.jungleclear:MenuElement({id = "usee", name = "Use [E] in clear", value = true})


    -- DRAWING SETTINGS --

end


function Nocturne:Draw()

end

function Nocturne:Tick()
    if myHero.dead or Game.IsChatOpen() or (ExtLibEvade and ExtLibEvade.Evading == true) then
        return
    end
    if orbwalker.Modes[0] then
        self:Combo()
    elseif orbwalker.Modes[3] then
        self:jungleclear()
    elseif orbwalker.Modes[1] then
        
    end
end

function Nocturne:jungleclear()

        for i = 1, Game.MinionCount() do
            local obj = Game.Minion(i)
            if obj.team ~= myHero.team then
                if obj ~= nil and obj.valid and obj.visible and not obj.dead then
                    if Ready(_Q) and self.shadowMenu.jungleclear.useq:Value() and obj and obj.team == 300 and obj.valid and obj.visible and not obj.dead and (obj.pos:DistanceTo(myHero.pos) < self.Q.Range) then
                        Control.CastSpell(HK_Q, obj)
                    end
                    if Ready(_E) and self.shadowMenu.jungleclear.usee:Value() and obj and obj.team == 300 and obj.valid and obj.visible and not obj.dead and (obj.pos:DistanceTo(myHero.pos) < self.Q.Range) then
                        Control.CastSpell(HK_E);
                    end
                end
            end
            
        end

end


function Nocturne:Combo()
    local target = TargetSelector:GetTarget(self.Q.Range, 1)
    if target == nil then return end
    if Ready(_Q) and target and IsValid(target) then
        if self.shadowMenu.combo.useq:Value() then
           self:CastQ(target)
        end														
    end

    local target = TargetSelector:GetTarget(self.E.Range, 1)
    if target == nil then return end
    if Ready(_E) and target and IsValid(target) then
        if self.shadowMenu.combo.usee:Value() then
           Control.CastSpell(HK_E, target)
        end														
    end

    local target = TargetSelector:GetTarget(2000, 1)
    if target == nil then return end
    local d = myHero.pos:DistanceTo(target.pos)
        if Ready(_R) and target and IsValid(target) then
            if self.shadowMenu.combo.user:Value() and (d >= 1200) then
                Control.CastSpell(HK_R, target)
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

function Nocturne:CastE(target)
    if Ready(_E) and lastE + 350 < GetTickCount() and orbwalker:CanMove() then
        local Pred = GamsteronPrediction:GetPrediction(target, self.E, myHero)
        if Pred.Hitchance >= _G.HITCHANCE_NORMAL then
            Control.CastSpell(HK_Q, Pred.CastPosition)
            lastE = GetTickCount()
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












--[[-------------------------------------------------------------------------------------------------------------------------
_   _   _              
/ \ / \ / \             
( E | N | D )            
\_/ \_/ \_/             
 _   _                  
/ \ / \                 
( O | F )                
\_/ \_/                 
 _   _   _   _   _   _  
/ \ / \ / \ / \ / \ / \ 
( J | U | N | G | L | E )
\_/ \_/ \_/ \_/ \_/ \_/ 

--]]-------------------------------------------------------------------------------------------------------------------------
--[[
   _   _   _   _  
  / \ / \ / \ / \ 
 ( J | I | N | X )
  \_/ \_/ \_/ \_/ 
]]

class "Jinx"
function Jinx:__init()
    
    self.Q = {speed = 2000, range = 600, delay = 0.25, radius = 0, type = "circular"}
    self.W = {speed = 1200, range = 10000, delay = 0.25, radius = 60, type = "linear", collision = {"minion"}}
    self.E = {speed = 1750, range = 900, delay = 0.25, radius = 50, type = "circular"}
    self.R = {speed = 1700, range = 25000, delay = 0.55, radius = 140, type = "linear"}

    

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
    self.shadowMenu = MenuElement({type = MENU, id = "shadowJinx", name = "Shadow Jinx"})


    -- COMBO --
    self.shadowMenu:MenuElement({type = MENU, id = "combo", name = "Combo"})
    self.shadowMenu.combo:MenuElement({id = "Q", name = "Use [Q] in Combo", value = true})
    self.shadowMenu.combo:MenuElement({id = "W", name = "Use [W] in Combo", value = true})
    self.shadowMenu.combo:MenuElement({id = "E", name = "Use [E] in  Combo", value = true})
    self.shadowMenu.combo:MenuElement({id = "EONCC", name = "Auto Use [E] on CC Targets", value = true})

        -- COMBO --
    self.shadowMenu:MenuElement({type = MENU, id = "clear", name = "Lane Clear"})
    self.shadowMenu.clear:MenuElement({id = "Q", name = "Use [Q] in LaneClear", value = true})


    -- R SETTINGS --
    self.shadowMenu:MenuElement({type = MENU, id = "rsettings", name = "R Settings"})
    self.shadowMenu.rsettings:MenuElement({id = "usermanual", name = "Use [R] on keydown", key = string.byte("T"), value = true, toggle = true})
    self.shadowMenu.rsettings:MenuElement({id = "usermanualdistance", name = "Max Distance willing to use [R] at", value = 0, min = 0, max = 20000})


    -- KILL STEAL --
    self.shadowMenu:MenuElement({type = MENU, id = "killsteal", name = "Kill Steal"})
    self.shadowMenu.killsteal:MenuElement({id = "killstealw", name = "Kill steal with [W]", value = true})
    self.shadowMenu.killsteal:MenuElement({id = "killstealr", name = "Kill steal with [R]", value = true})
    self.shadowMenu.killsteal:MenuElement({id = "killstealrangemax", name = "Max Distance willing to use R at", value = 0, min = 0, max = 20000})

    -- DRAWINGS --
    self.shadowMenu:MenuElement({type = MENU, id = "Drawing", name = "Draw Settings"})
    self.shadowMenu.Drawing:MenuElement({id = "draww", name = "Draw [W] Range", value = true})
    self.shadowMenu.Drawing:MenuElement({id = "drawe", name = "Draw [E] Range", value = true})
    self.shadowMenu.Drawing:MenuElement({id = "drawr", name = "Draw [R] Range", value = true})
    self.shadowMenu.Drawing:MenuElement({id = "drawrkill", name = "Draw [R] Killable Text", value = true})
    self.shadowMenu.Drawing:MenuElement({id = "drawrtoogle", name = "Draw [R] use toogle", value = true})
    self.shadowMenu.Drawing:MenuElement({id = "rdebug", name = "Draw [R] for debug", value = true})


end


function Jinx:Draw()

    if self.shadowMenu.Drawing.drawr:Value() and Ready(_R) then
		Draw.Circle(myHero, 1500, 1, Draw.Color(255, 0, 0))
		end                                                 
		if self.shadowMenu.Drawing.drawe:Value() and Ready(_E) then
		Draw.Circle(myHero, 900, 1, Draw.Color(235, 147, 52))
		end
		if self.shadowMenu.Drawing.draww:Value() and Ready(_W) then
		Draw.Circle(myHero, 1450, 1, Draw.Color(0, 212, 250))
        end
        if self.shadowMenu.Drawing.rdebug:Value() and Ready(_R) then
            Draw.Circle(myHero, 3000, 1, Draw.Color(255, 255, 0, 0))
            end   
        if self.shadowMenu.Drawing.drawrtoogle:Value() then
            Draw.Text("R Useage Toogle: ", 18, myHero.pos2D.x - 50, myHero.pos2D.y + 60, Draw.Color(255, 225, 255, 255))
                if self.shadowMenu.rsettings.usermanual:Value() then
                    Draw.Text("ON", 18, myHero.pos2D.x + 80, myHero.pos2D.y + 60, Draw.Color(255, 0, 255, 0))
                    else
                        Draw.Text("OFF", 18, myHero.pos2D.x + 80, myHero.pos2D.y + 60, Draw.Color(255, 255, 0, 0))
                end 
            end

    for i = 1,Game.HeroCount() do
        local hero = Game.Hero(i)
        if hero and IsValid(hero) and hero.team ~= myHero.team and rdmg > hero.health then
            local rdmg = getdmg("R", target, myHero)
            if self.shadowMenu.Drawing.drawrkill:Value() and Ready(_R) then
                Draw.Text("Killable with [R]", 18, hero.pos2D.x - 100, hero.pos2D.y + 60, Draw.Color(255, 225, 0, 0))
            end
        end
    end
end



function Jinx:Tick()
    if myHero.dead or Game.IsChatOpen() or (ExtLibEvade and ExtLibEvade.Evading == true) then
        return
    end
    self:autor()
    self:autoe()
    self:killsteal()
    if orbwalker.Modes[0] then
        self:Combo()
    elseif orbwalker.Modes[3] then
        self:Clear()
    end

    if myHero.activeSpell.name == "JinxR" then
        _G.SDK.Orbwalker:SetMovement(false)
        _G.SDK.Orbwalker:SetAttack(false)
else
    _G.SDK.Orbwalker:SetMovement(true)
    _G.SDK.Orbwalker:SetAttack(true)
end


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

function Jinx:autor()
    local target = TargetSelector:GetTarget(20000, 1)
    if target == nil then return end
    local d = myHero.pos:DistanceTo(target.pos)
    local rdmg = getdmg("R", target, myHero)
    local pred = _G.PremiumPrediction:GetPrediction(myHero, target, self.R)
    if Ready(_R) and target and IsValid(target)then
        if self.shadowMenu.rsettings.usermanual:Value() then
            if (d <= self.shadowMenu.rsettings.usermanualdistance:Value()) and (d >= 500) and (target.health < rdmg) then
                self:CastR(target)
            end
        end    
    end 

end

function Jinx:Clear()
    for i = 1, Game.MinionCount() do
        local minion = Game.Minion(i)
        if minion.team ~= myHero.team then
            if minion ~= nil and minion.valid and minion.visible and not minion.dead then
                if minion == nil and self:HasSecondQ() then
                     Control.CastSpell(HK_Q) 
                end
                local d = myHero.pos:DistanceTo(minion.pos)
                if self.shadowMenu.clear.Q:Value() and d < 600 then
                    if d > 525 and not self:HasSecondQ() or (d < 525 and self:HasSecondQ()) then
                        Control.CastSpell(HK_Q)
                    end
                end
            end
        end
    end
end

function Jinx:autoe()
    local target = TargetSelector:GetTarget(self.E.Range, 1)
    if target and IsValid(target) then
    if Ready(_E) and self.shadowMenu.combo.EONCC:Value() and IsImmobileTarget(target) then
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
        if Ready(_R) and target and IsValid(target) and (target.health <= rdmg) and self.shadowMenu.killsteal.killstealr:Value() and d > 500 and d < self.shadowMenu.killsteal.killstealrangemax:Value() then
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
    local pred = _G.PremiumPrediction:GetPrediction(myHero, target, self.W)
    if Ready(_W) and target and IsValid(target) then
        if self.shadowMenu.combo.W:Value() and pred.HitChance then
            self:CastW(target) 
        end														---- you have "end" forget
    end

    local target = TargetSelector:GetTarget(self.E.Range, 1)
    if target == nil then return end
    if Ready(_E) and target and IsValid(target) then
        if self.shadowMenu.combo.E:Value() then
            self:CastE(target)
        end
    end
    
    local target = TargetSelector:GetTarget(self.W.Range, 1)
    if target == nil then return end
    local distance = target.pos:DistanceTo(myHero.pos) 
    if Ready(_Q) and target and IsValid(target)then
        if self.shadowMenu.combo.Q:Value() then
            if distance > 525 and not self:HasSecondQ() or (distance < 525 and self:HasSecondQ()) then
                Control.CastSpell(HK_Q)
            end
        end    
    end 

end

function Jinx:HasSecondQ()
    return CheckBuffs(myHero, "JinxQ") > 0
end


function Jinx:CastW(target)
    if Ready(_W) and lastW + 350 < GetTickCount() and orbwalker:CanMove() then
        local pred = _G.PremiumPrediction:GetPrediction(myHero, target, self.W)
        if pred.CastPos and _G.PremiumPrediction.HitChance.Medium(pred.HitChance) and Game.CanUseSpell(_Q) == 0 then
            Control.CastSpell(HK_W, pred.CastPos)
            lastW = GetTickCount()
        end
    end
end


function Jinx:CastE(target)
    if Ready(_E) and lastE + 350 < GetTickCount() and orbwalker:CanMove() then
        local pred = _G.PremiumPrediction:GetPrediction(myHero, target, self.E)
        if pred.CastPos and _G.PremiumPrediction.HitChance.Medium(pred.HitChance) and Game.CanUseSpell(_E) == 0 then
            Control.CastSpell(HK_E, pred.CastPos)
            lastE = GetTickCount()
        end
    end
end

function Jinx:CastR(target)
    if Ready(_R) and lastR + 350 < GetTickCount() and orbwalker:CanMove() then
        local pred = _G.PremiumPrediction:GetPrediction(myHero, target, self.R)
        if pred.CastPos and _G.PremiumPrediction.HitChance.High(pred.HitChance) and Game.CanUseSpell(_R) == 0 then
            Direction = Vector((myHero.pos-pred.CastPos):Normalized())
	        Spot = myHero.pos - Direction * 700
            Control.CastSpell(HK_R, Spot)
            lastR = GetTickCount()
        end
    end
end

    --[[
    _   _   _   _   _   _   _   _   _   _  
    / \ / \ / \ / \ / \ / \ / \ / \ / \ / \ 
    ( B | L | I | T | Z | C | R | A | N | K )
    \_/ \_/ \_/ \_/ \_/ \_/ \_/ \_/ \_/ \_/ 
                                                                        
    ]]

        class "Blitzcrank"
        function Blitzcrank:__init()
            
            self.Q = {Type = _G.SPELLTYPE_LINE, Delay = 0.25, Radius = 140, Range = 1150, Speed = 1800, Collision = true, MaxCollision = 0, CollisionTypes = {_G.COLLISION_MINION}}
            self.R = {Type = _G.SPELLTYPE_CIRCLE, Delay = 0, Radius = 600, Range = 600, Speed = 0, Collision = false}
            

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
            ["BlitzIcon"] = "https://vignette.wikia.nocookie.net/leagueoflegends/images/a/ac/Blitzcrank_OriginalSquare.png",
            ["Q"] = "https://vignette.wikia.nocookie.net/leagueoflegends/images/e/e2/Rocket_Grab.png",
            ["W"] = "https://vignette.wikia.nocookie.net/leagueoflegends/images/a/ab/Overdrive.png",
            ["E"] = "https://vignette.wikia.nocookie.net/leagueoflegends/images/9/98/Power_Fist.png",
            ["R"] = "https://vignette.wikia.nocookie.net/leagueoflegends/images/a/a6/Static_Field.png",
            ["EXH"] = "https://vignette.wikia.nocookie.net/leagueoflegends/images/4/4a/Exhaust.png",
            ["IGN"] = "https://vignette.wikia.nocookie.net/leagueoflegends/images/f/f4/Ignite.png"
            }


        function Blitzcrank:LoadMenu()
            self.shadowMenu = MenuElement({type = MENU, id = "shadowBlitzcrank", name = "Shadow Blitzcrank"})

            -- COMBO --
            self.shadowMenu:MenuElement({type = MENU, id = "combo", name = "Combo"})
            self.shadowMenu.combo:MenuElement({id = "Q", name = "Use Q in Combo", value = true})
            self.shadowMenu.combo:MenuElement({id = "W", name = "Use W in Combo", value = true})
            self.shadowMenu.combo:MenuElement({id = "E", name = "Use E in  Combo", value = true})
            self.shadowMenu.combo:MenuElement({id = "R", name = "Use R in  Combo", value = true})

            -- AUTO R --
            self.shadowMenu:MenuElement({type = MENU, id = "autor", name = "Auto R Settings"})
            self.shadowMenu.autor:MenuElement({id = "useautor", name = "Use auto [R]", value = true})
            self.shadowMenu.autor:MenuElement({id = "autorammount", name = "Activate [R] when x enemies around", value = 1, min = 1, max = 5, identifier = "#"})

            -- SUMMONER SETTINGS --
            self.shadowMenu:MenuElement({type = MENU, id = "SummonerSettings", name = "Summoner Settings"})

            if myHero:GetSpellData(SUMMONER_1).name == "SummonerDot" then
                self.shadowMenu.SummonerSettings:MenuElement({id = "UseIgnite", name = "Use [Ignite] if killable?", value = true})
            elseif myHero:GetSpellData(SUMMONER_2).name == "SummonerDot" then
                self.shadowMenu.SummonerSettings:MenuElement({id = "UseIgnite", name = "Use [Ignite] if killable?", value = true}) 
            end

            
            if myHero:GetSpellData(SUMMONER_1).name == "SummonerExhaust" then
                self.shadowMenu.SummonerSettings:MenuElement({id = "UseExhaust", name = "Use [Exhaust] on engage?", value = true})
            elseif myHero:GetSpellData(SUMMONER_2).name == "SummonerExhaust" then
                self.shadowMenu.SummonerSettings:MenuElement({id = "UseExhaust", name = "Use [Exhaust] on engage?", value = true}) 
            end

        end

        
        function Blitzcrank:Draw()
            
        end
        
        function Blitzcrank:Tick()
            if myHero.dead or Game.IsChatOpen() or (ExtLibEvade and ExtLibEvade.Evading == true) then
                return
            end
            self:AutoR()
            self:AutoSummoners()
            if orbwalker.Modes[0] then
                self:Combo()
            elseif orbwalker.Modes[3] then
            end
        end
        
        
        function Blitzcrank:AutoSummoners()

            -- IGNITE --
            local target = TargetSelector:GetTarget(self.Q.Range, 1)
            if target and IsValid(target) then
            local ignDmg = getdmg("IGNITE", target, myHero)
            if myHero:GetSpellData(SUMMONER_1).name == "SummonerDot" and Ready(SUMMONER_1) and (target.health < ignDmg ) then
                Control.CastSpell(HK_SUMMONER_1, target)
            elseif myHero:GetSpellData(SUMMONER_2).name == "SummonerDot" and Ready(SUMMONER_2) and (target.health < ignDmg ) then
                Control.CastSpell(HK_SUMMONER_2, target)
            end


        end


        end
        function Blitzcrank:Combo()
            local QPred = GamsteronPrediction:GetPrediction(target, self.Q, myHero)
            local target = TargetSelector:GetTarget(self.Q.Range, 1)
            if Ready(_Q) and target and IsValid(target) then
                if self.shadowMenu.combo.Q:Value() then
                    self:CastQ(target)
                end
            end
            local target = TargetSelector:GetTarget(2000, 1)
            if Ready(_W) and target and IsValid(target) then
                local d = myHero.pos:DistanceTo(target.pos)
                if self.shadowMenu.combo.W:Value() and d >= 1150 then
                    Control.CastSpell(HK_W)
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
        
        function Blitzcrank:jungleclear()
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
                            Control.CastSpell(HK_W);
                        end
                    end
                    end
                end
        end
        end

        function Blitzcrank:AutoR()

        local target = TargetSelector:GetTarget(self.R.Range, 1)
            if target and IsValid(target) then
                if self.shadowMenu.autor.useautor:Value() and CountEnemiesNear(target, 600) >= self.shadowMenu.autor.autorammount:Value() and Ready(_R) then
                    Control.CastSpell(HK_R)
                end
            end
        end

        function Blitzcrank:laneclear()
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
        
        function Blitzcrank:CastQ(target)
            if Ready(_Q) and lastQ + 350 < GetTickCount() and orbwalker:CanMove() then
                local Pred = GamsteronPrediction:GetPrediction(target, self.Q, myHero)
                if Pred.Hitchance >= _G.HITCHANCE_HIGH then
                    Control.CastSpell(HK_Q, Pred.CastPosition)
                    lastQ = GetTickCount()
                end
            end
        end


        
        function Blitzcrank:CastR(target)
            if Ready(_R) and lastR + 350 < GetTickCount() and orbwalker:CanMove() then
                local Pred = GamsteronPrediction:GetPrediction(target, self.R, myHero)
                if Pred.Hitchance >= _G.HITCHANCE_NORMAL then
                    Control.CastSpell(HK_R, Pred.CastPosition)
                    lastR = GetTickCount()
                end
            end
        end
--[[
        _   _   _   _  
        / \ / \ / \ / \ 
    ( N | A | M | I )
        \_/ \_/ \_/ \_/ 
]]

class "Nami"
function Nami:__init()
    
    self.Q = {Type = _G.SPELLTYPE_CIRCLE, Delay = 0, Radius = 0, Range = 875, Speed = 1750, Collision = true, MaxCollision = 0, CollisionTypes = {_G.COLLISION_MINION}}
    self.W = {Type = _G.SPELLTYPE_CIRCLE, Delay = 0, Radius = 0, Range = 725, Speed = 1800, Collision = false}
    self.E = {Type = _G.SPELLTYPE_CIRCLE, Delay = 0, Radius = 800, Range = 800, Speed = 1800, Collision = false}
    self.R = {Type = _G.SPELLTYPE_CIRCLE, Delay = 0, Radius = 325, Range = 2750, Speed = 1200, Collision = false}
    

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
    ["NamiIcon"] = "https://vignette.wikia.nocookie.net/leagueoflegends/images/d/dd/Nami_OriginalSquare.png",
    ["Q"] = "https://vignette.wikia.nocookie.net/leagueoflegends/images/c/cb/Aqua_Prison.png",
    ["W"] = "https://vignette.wikia.nocookie.net/leagueoflegends/images/4/48/Ebb_and_Flow.png",
    ["E"] = "https://vignette.wikia.nocookie.net/leagueoflegends/images/a/a4/Tidecaller%27s_Blessing.png",
    ["R"] = "https://vignette.wikia.nocookie.net/leagueoflegends/images/2/2e/Tidal_Wave.png",
    ["EXH"] = "https://vignette.wikia.nocookie.net/leagueoflegends/images/4/4a/Exhaust.png",
    ["IGN"] = "https://vignette.wikia.nocookie.net/leagueoflegends/images/f/f4/Ignite.png"
    }


function Nami:LoadMenu()
    self.shadowMenu = MenuElement({type = MENU, id = "shadowNami", name = "Shadow Nami"})

    -- COMBO --
    self.shadowMenu:MenuElement({type = MENU, id = "combo", name = "Combo"})
    self.shadowMenu.combo:MenuElement({id = "Q", name = "Use [Q] in Combo", value = true})
    self.shadowMenu.combo:MenuElement({id = "W", name = "Use [W] on Ally", value = true})
    self.shadowMenu.combo:MenuElement({id = "wonAlly", name = "Use [W] in Combo", value = true})
    self.shadowMenu.combo:MenuElement({id = "E", name = "Use [E] in  Combo", value = true})
    self.shadowMenu.combo:MenuElement({id = "eonAlly", name = "Use [E] on Ally", value = true})
    self.shadowMenu.combo:MenuElement({id = "R", name = "Use [R] in  Combo", value = true})

    -- AUTO R --
    self.shadowMenu:MenuElement({type = MENU, id = "autor", name = "Auto R Settings"})
    self.shadowMenu.autor:MenuElement({id = "useautor", name = "Use auto [R]", value = true})
    self.shadowMenu.autor:MenuElement({id = "autorammount", name = "Activate [R] when x enemies around", value = 1, min = 1, max = 5, identifier = "#"})

    -- SUMMONER SETTINGS --
    self.shadowMenu:MenuElement({type = MENU, id = "SummonerSettings", name = "Summoner Settings"})

    if myHero:GetSpellData(SUMMONER_1).name == "SummonerDot" then
        self.shadowMenu.SummonerSettings:MenuElement({id = "UseIgnite", name = "Use [Ignite] if killable?", value = true})
    elseif myHero:GetSpellData(SUMMONER_2).name == "SummonerDot" then
        self.shadowMenu.SummonerSettings:MenuElement({id = "UseIgnite", name = "Use [Ignite] if killable?", value = true}) 
    end

    
    if myHero:GetSpellData(SUMMONER_1).name == "SummonerExhaust" then
        self.shadowMenu.SummonerSettings:MenuElement({id = "UseExhaust", name = "Use [Exhaust] on engage?", value = true})
    elseif myHero:GetSpellData(SUMMONER_2).name == "SummonerExhaust" then
        self.shadowMenu.SummonerSettings:MenuElement({id = "UseExhaust", name = "Use [Exhaust] on engage?", value = true}) 
    end

end

function Nami:Draw()
    
end

function Nami:Tick()
    if myHero.dead or Game.IsChatOpen() or (ExtLibEvade and ExtLibEvade.Evading == true) then
        return
    end
    self:AutoSummoners()
    --self:AutoW()
    if orbwalker.Modes[0] then
        self:Combo()
    elseif orbwalker.Modes[3] then
    end
end

function Nami:AutoSummoners()

    -- IGNITE --
    local target = TargetSelector:GetTarget(self.Q.Range, 1)
    if target and IsValid(target) then
    local ignDmg = getdmg("IGNITE", target, myHero)
		if myHero:GetSpellData(SUMMONER_1).name == "SummonerDot" and Ready(SUMMONER_1) and (target.health < ignDmg ) then
			Control.CastSpell(HK_SUMMONER_1, target)
		elseif myHero:GetSpellData(SUMMONER_2).name == "SummonerDot" and Ready(SUMMONER_2) and (target.health < ignDmg ) then
			Control.CastSpell(HK_SUMMONER_2, target)
		end
	end
end
--[[
function Nami:AutoW()

end
]]
function Nami:Combo()

    local QPred = GamsteronPrediction:GetPrediction(target, self.Q, myHero)
    local target = TargetSelector:GetTarget(self.Q.Range, 1)
    if Ready(_Q) and target and IsValid(target) then
        if self.shadowMenu.combo.Q:Value() then
            self:CastQ(target)
        end
    end

    local target = TargetSelector:GetTarget(self.W.Range, 1)
    if Ready(_W) and target and IsValid(target) then               
        if self.shadowMenu.combo.W:Value() then
            Control.CastSpell(HK_W, target)
        end
    end
   
    local target = TargetSelector:GetTarget(self.Q.Range, 1)
    if Ready(_E) and target and IsValid(target) then
        if self.shadowMenu.combo.E:Value() then
            Control.CastSpell(HK_E, myHero.pos)
            --self:CastSpell(HK_Etarget)
        end
    end

    local target = TargetSelector:GetTarget(self.R.Range, 1)
    if Ready(_R) and target and IsValid(target) then
        if self.shadowMenu.combo.R:Value() then
            self:CastR(target)
            --self:CastSpell(HK_Etarget)
        end
    end

end

function Nami:jungleclear()
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
                    Control.CastSpell(HK_W);
                end
            end
            end
        end
	end
end

function Nami:laneclear()
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

function Nami:CastQ(target)
    if Ready(_Q) and lastQ + 350 < GetTickCount() and orbwalker:CanMove() then
        local Pred = GamsteronPrediction:GetPrediction(target, self.Q, myHero)
        if Pred.Hitchance >= _G.HITCHANCE_HIGH then
            Control.CastSpell(HK_Q, Pred.CastPosition)
            lastQ = GetTickCount()
        end
    end
end

function Nami:CastR(target)
    if Ready(_R) and lastR + 350 < GetTickCount() and orbwalker:CanMove() then
        local Pred = GamsteronPrediction:GetPrediction(target, self.R, myHero)
        if Pred.Hitchance >= _G.HITCHANCE_NORMAL then
            Control.CastSpell(HK_R, Pred.CastPosition)
            lastR = GetTickCount()
        end
    end
end

--[[
_   _   _   _  
/ \ / \ / \ / \ 
( S | O | N | A )
\_/ \_/ \_/ \_/ 
]]
class "Sona"
function Sona:__init()
    
    self.Q = {Type = _G.SPELLTYPE_CIRCLE, Delay = 0.25, Radius = 0, Range = 825, Speed = 1500, Collision = false}
    self.W = {Type = _G.SPELLTYPE_CIRCLE, Delay = 0, Radius = 0, Range = 1000, Speed = 1500, Collision = false}
    self.E = {Type = _G.SPELLTYPE_CIRCLE, Delay = 0, Radius = 0, Range = 430, Speed = 1500, Collision = false}
    self.R = {Type = _G.SPELLTYPE_LINE, Delay = 0, Radius = 140, Range = 900, Speed = 2400, Collision = false}
    

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
    ["SonaIcon"] = "https://vignette.wikia.nocookie.net/leagueoflegends/images/f/fb/Sona_OriginalSquare.png",
    ["Q"] = "https://vignette.wikia.nocookie.net/leagueoflegends/images/e/e1/Hymn_of_Valor.png",
    ["W"] = "https://vignette.wikia.nocookie.net/leagueoflegends/images/9/99/Aria_of_Perseverance.png",
    ["E"] = "https://vignette.wikia.nocookie.net/leagueoflegends/images/7/76/Song_of_Celerity.png",
    ["R"] = "https://vignette.wikia.nocookie.net/leagueoflegends/images/b/b1/Crescendo.png",
    ["EXH"] = "https://vignette.wikia.nocookie.net/leagueoflegends/images/4/4a/Exhaust.png",
    ["IGN"] = "https://vignette.wikia.nocookie.net/leagueoflegends/images/f/f4/Ignite.png"
    }

function Sona:LoadMenu()
    self.shadowMenu = MenuElement({type = MENU, id = "shadowSona", name = "Shadow Sona"})

    -- COMBO --
    self.shadowMenu:MenuElement({type = MENU, id = "combo", name = "Combo"})
    self.shadowMenu.combo:MenuElement({id = "Q", name = "Use Q in Combo", value = true})
    self.shadowMenu.combo:MenuElement({id = "W", name = "Use W in Combo", value = false})
    self.shadowMenu.combo:MenuElement({id = "E", name = "Use E in  Combo", value = true})
    self.shadowMenu.combo:MenuElement({id = "R", name = "Use R in  Combo", value = true})

    -- AUTO R --
    self.shadowMenu:MenuElement({type = MENU, id = "autor", name = "Auto R Settings"})
    self.shadowMenu.autor:MenuElement({id = "useautor", name = "Use auto [R]", value = true})
    self.shadowMenu.autor:MenuElement({id = "autorammount", name = "Activate [R] when x enemies around", value = 1, min = 1, max = 5, identifier = "#"})

    -- AUTO W -- 
    self.shadowMenu:MenuElement({type = MENU, id = "autow", name = "Auto W Settings"})
    self.shadowMenu.autow:MenuElement({id = "useautow", name = "Use auto [W] on ally?", value = true})

    -- SUMMONER SETTINGS --
    self.shadowMenu:MenuElement({type = MENU, id = "SummonerSettings", name = "Summoner Settings"})

    if myHero:GetSpellData(SUMMONER_1).name == "SummonerDot" then
        self.shadowMenu.SummonerSettings:MenuElement({id = "UseIgnite", name = "Use [Ignite] if killable?", value = true})
    elseif myHero:GetSpellData(SUMMONER_2).name == "SummonerDot" then
        self.shadowMenu.SummonerSettings:MenuElement({id = "UseIgnite", name = "Use [Ignite] if killable?", value = true}) 
    end

    
    if myHero:GetSpellData(SUMMONER_1).name == "SummonerExhaust" then
        self.shadowMenu.SummonerSettings:MenuElement({id = "UseExhaust", name = "Use [Exhaust] on engage?", value = true})
    elseif myHero:GetSpellData(SUMMONER_2).name == "SummonerExhaust" then
        self.shadowMenu.SummonerSettings:MenuElement({id = "UseExhaust", name = "Use [Exhaust] on engage?", value = true}) 
    end
end

function Sona:Draw()
    
end

function Sona:Tick()
    if myHero.dead or Game.IsChatOpen() or (ExtLibEvade and ExtLibEvade.Evading == true) then
        return
    end
    self:AutoR()
    self:AutoSummoners()
    self:AutoW()
    if orbwalker.Modes[0] then
        self:Combo()
    elseif orbwalker.Modes[3] then
    end
end

function Sona:AutoSummoners()

    -- IGNITE --
    local target = TargetSelector:GetTarget(self.Q.Range, 1)
    if target and IsValid(target) then
    local ignDmg = getdmg("IGNITE", target, myHero)
    if myHero:GetSpellData(SUMMONER_1).name == "SummonerDot" and Ready(SUMMONER_1) and (target.health < ignDmg ) then
        Control.CastSpell(HK_SUMMONER_1, target)
    elseif myHero:GetSpellData(SUMMONER_2).name == "SummonerDot" and Ready(SUMMONER_2) and (target.health < ignDmg ) then
        Control.CastSpell(HK_SUMMONER_2, target)
    end
	end
end

function Sona:AutoW()
local target = TargetSelector:GetTarget(800)     	
if target == nil then return end	

if self.shadowMenu.autow.useautow:Value() and Ready(_W) then
    for i, ally in pairs(GetAllyHeroes()) do
        if self.shadowMenu.autow.useautow:Value() and IsValid(ally,1000) and myHero.pos:DistanceTo(ally.pos) <= 1000 and ally.health < ally.maxHealth then
            Control.CastSpell(HK_W, ally)
        end
    end
end
end

function Sona:Combo()
    local QPred = GamsteronPrediction:GetPrediction(target, self.Q, myHero)
    local target = TargetSelector:GetTarget(self.Q.Range, 1)
    if Ready(_Q) and target and IsValid(target) then
        if self.shadowMenu.combo.Q:Value() then
            self:CastQ(target)
        end
    end
    local target = TargetSelector:GetTarget(2000, 1)
    if Ready(_W) and target and IsValid(target) then
        local d = myHero.pos:DistanceTo(target.pos)
        if self.shadowMenu.combo.W:Value() and d >= 1150 then
            Control.CastSpell(HK_W)
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

function Sona:jungleclear()
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
                    Control.CastSpell(HK_W);
                end
            end
            end
        end
	end
end

function Sona:AutoR()
local target = TargetSelector:GetTarget(self.R.Range, 1)
    if target and IsValid(target) then
        if self.shadowMenu.autor.useautor:Value() and CountEnemiesNear(target, 500) >= self.shadowMenu.autor.autorammount:Value() and Ready(_R) then
            self:CastR(target)
        end
    end
end

function Sona:laneclear()
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

function Sona:CastQ(target)
    if Ready(_Q) and lastQ + 350 < GetTickCount() and orbwalker:CanMove() then
        local Pred = GamsteronPrediction:GetPrediction(target, self.Q, myHero)
        if Pred.Hitchance >= _G.HITCHANCE_NORMAL then
            Control.CastSpell(HK_Q, Pred.CastPosition)
            lastQ = GetTickCount()
        end
    end
end

function Sona:CastR(target)
    if Ready(_R) and lastR + 350 < GetTickCount() and orbwalker:CanMove() then
        local Pred = GamsteronPrediction:GetPrediction(target, self.R, myHero)
        if Pred.Hitchance >= _G.HITCHANCE_NORMAL then
            Control.CastSpell(HK_R, Pred.CastPosition)
            lastR = GetTickCount()
        end
    end
end
--[[
_   _   _   _   _  
/ \ / \ / \ / \ / \ 
( B | R | A | U | M )
\_/ \_/ \_/ \_/ \_/ 
]]
class "Braum"
function Braum:__init()

self.Q = {Type = _G.SPELLTYPE_LINE, Delay = 0.25, Radius = 70, Range = 1000, Speed = 1100, Collision = true, MaxCollision = 0, CollisionTypes = {_G.COLLISION_MINION}}
self.R = {Type = _G.SPELLTYPE_LINE, Delay = 0, Radius = 80, Range = 1250, Speed = 1200, Collision = false}


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
["BraumIcon"] = "https://vignette.wikia.nocookie.net/leagueoflegends/images/2/28/Braum_OriginalSquare.png",
["Q"] = "https://vignette.wikia.nocookie.net/leagueoflegends/images/c/c2/Winter%27s_Bite.png",
["W"] = "https://vignette.wikia.nocookie.net/leagueoflegends/images/9/91/Stand_Behind_Me.png",
["E"] = "https://vignette.wikia.nocookie.net/leagueoflegends/images/e/ef/Unbreakable.png",
["R"] = "https://vignette.wikia.nocookie.net/leagueoflegends/images/4/44/Glacial_Fissure.png",
["EXH"] = "https://vignette.wikia.nocookie.net/leagueoflegends/images/4/4a/Exhaust.png",
["IGN"] = "https://vignette.wikia.nocookie.net/leagueoflegends/images/f/f4/Ignite.png"
}


function Braum:LoadMenu()
self.shadowMenu = MenuElement({type = MENU, id = "shadowBraum", name = "Shadow Braum"})

-- COMBO --
self.shadowMenu:MenuElement({type = MENU, id = "combo", name = "Combo"})
self.shadowMenu.combo:MenuElement({id = "Q", name = "Use Q in Combo", value = true})
self.shadowMenu.combo:MenuElement({id = "W", name = "Use W in Combo", value = false})
self.shadowMenu.combo:MenuElement({id = "E", name = "Use E in  Combo", value = true})
self.shadowMenu.combo:MenuElement({id = "R", name = "Use R in  Combo", value = true})
self.shadowMenu.combo:MenuElement({id = "userammount", name = "Activate [R] when x enemies around", value = 1, min = 1, max = 5, identifier = "#"})

-- AUTO R --
self.shadowMenu:MenuElement({type = MENU, id = "autor", name = "Auto R Settings"})
self.shadowMenu.autor:MenuElement({id = "useautor", name = "Use auto [R]", value = true})
self.shadowMenu.autor:MenuElement({id = "autorammount", name = "Activate [R] when x enemies around", value = 1, min = 1, max = 5, identifier = "#"})

-- AUTO W -- 
self.shadowMenu:MenuElement({type = MENU, id = "autow", name = "Auto Jump on Ally Settings"})
self.shadowMenu.autow:MenuElement({id = "useautow", name = "Use auto [W] and [E] on ally?", value = true})
self.shadowMenu.autow:MenuElement({id = "useautowhp", name = "Use auto [W] and [E] on ally hp %", value = 30, min = 0, max = 100, identifier = "%"})

-- DRAWING SETTINGS --
self.shadowMenu:MenuElement({type = MENU, id = "drawings", name = "Drawing Settings"})
self.shadowMenu.drawings:MenuElement({id = "drawAutoR", name = "Draw if auto [R] is on", value = true})
self.shadowMenu.drawings:MenuElement({id = "drawAutoWE", name = "Draw if auto [W] and [E] on Ally is on", value = true})


-- SUMMONER SETTINGS --
self.shadowMenu:MenuElement({type = MENU, id = "SummonerSettings", name = "Summoner Settings"})
if myHero:GetSpellData(SUMMONER_1).name == "SummonerDot" then
    self.shadowMenu.SummonerSettings:MenuElement({id = "UseIgnite", name = "Use [Ignite] if killable?", value = true})
elseif myHero:GetSpellData(SUMMONER_2).name == "SummonerDot" then
    self.shadowMenu.SummonerSettings:MenuElement({id = "UseIgnite", name = "Use [Ignite] if killable?", value = true}) 
end

if myHero:GetSpellData(SUMMONER_1).name == "SummonerExhaust" then
    self.shadowMenu.SummonerSettings:MenuElement({id = "UseExhaust", name = "Use [Exhaust] on engage?", value = true})
elseif myHero:GetSpellData(SUMMONER_2).name == "SummonerExhaust" then
    self.shadowMenu.SummonerSettings:MenuElement({id = "UseExhaust", name = "Use [Exhaust] on engage?", value = true}) 
end

end


function Braum:Draw()

if self.shadowMenu.drawings.drawAutoR:Value() then
    Draw.Text("Auto Cast R: ", 15, 5, 30, Draw.Color(255, 225, 255, 0))
        if self.shadowMenu.autor.useautor:Value() then
            Draw.Text("ON", 15, 85, 30, Draw.Color(255, 0, 255, 0))
            else
                Draw.Text("OFF", 15, 85, 30, Draw.Color(255, 255, 0, 0))
        end 
end

if self.shadowMenu.drawings.drawAutoWE:Value() then
    Draw.Text("Auto Jump on Ally: ", 15, 5, 60, Draw.Color(255, 225, 255, 0))
        if self.shadowMenu.autow.useautow:Value() then
            Draw.Text("ON", 15, 115, 60, Draw.Color(255, 0, 255, 0))
            else
            Draw.Text("OFF", 15, 115, 60, Draw.Color(255, 255, 0, 0))
        end 
end

end

function Braum:Tick()
if myHero.dead or Game.IsChatOpen() or (ExtLibEvade and ExtLibEvade.Evading == true) then
    return
end
self:AutoR()
self:AutoSummoners()
self:AutoW()
if orbwalker.Modes[0] then
    self:Combo()
elseif orbwalker.Modes[3] then
end
end


function Braum:AutoSummoners()

-- IGNITE --
local target = TargetSelector:GetTarget(self.Q.Range, 1)
if target and IsValid(target) then
local ignDmg = getdmg("IGNITE", target, myHero)
if myHero:GetSpellData(SUMMONER_1).name == "SummonerDot" and Ready(SUMMONER_1) and (target.health < ignDmg ) then
    Control.CastSpell(HK_SUMMONER_1, target)
elseif myHero:GetSpellData(SUMMONER_2).name == "SummonerDot" and Ready(SUMMONER_2) and (target.health < ignDmg ) then
    Control.CastSpell(HK_SUMMONER_2, target)
end
end

end

function Braum:AutoW()
local target = TargetSelector:GetTarget(800)     	
if target == nil then return end	

if self.shadowMenu.autow.useautow:Value() and Ready(_W) then
for i, ally in pairs(GetAllyHeroes()) do
    if self.shadowMenu.autow.useautow:Value() and IsValid(ally,1000) and myHero.pos:DistanceTo(ally.pos) <= 1000 and ally.health / ally.maxHealth < self.shadowMenu.autow.useautowhp:Value() / 100 then
        Control.CastSpell(HK_W, ally)
        Control.CastSpell(HK_E)
    end
end
end
end

function Braum:Combo()
local QPred = GamsteronPrediction:GetPrediction(target, self.Q, myHero)
local target = TargetSelector:GetTarget(self.Q.Range, 1)
if Ready(_Q) and target and IsValid(target) then
    if self.shadowMenu.combo.Q:Value() then
        self:CastQ(target)
    end
end
local target = TargetSelector:GetTarget(2000, 1)
if Ready(_W) and target and IsValid(target) then
    local d = myHero.pos:DistanceTo(target.pos)
    if self.shadowMenu.combo.W:Value() and d >= 1150 then
        Control.CastSpell(HK_W)
    end
end

local target = TargetSelector:GetTarget(self.Q.Range, 1)
if Ready(_E) and target and IsValid(target) then
    if self.shadowMenu.combo.E:Value() then
        Control.CastSpell(HK_E)
        --self:CastSpell(HK_Etarget)
    end
end

local target = TargetSelector:GetTarget(self.R.Range, 1)
if target and IsValid(target) then
    if self.shadowMenu.combo.R:Value() and CountEnemiesNear(target, 1250) >= self.shadowMenu.combo.userammount:Value() and Ready(_R) then
        self:CastR(target)
    end
end

end

function Braum:jungleclear()
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
                Control.CastSpell(HK_W);
            end
        end
        end
    end
end
end

function Braum:AutoR()
local target = TargetSelector:GetTarget(self.R.Range, 1)
if target and IsValid(target) then
    if self.shadowMenu.autor.useautor:Value() and CountEnemiesNear(target, 1250) >= self.shadowMenu.autor.autorammount:Value() and Ready(_R) then
        self:CastR(target)
    end
end
end

function Braum:CastQ(target)
if Ready(_Q) and lastQ + 350 < GetTickCount() and orbwalker:CanMove() then
    local Pred = GamsteronPrediction:GetPrediction(target, self.Q, myHero)
    if Pred.Hitchance >= _G.HITCHANCE_NORMAL then
        Control.CastSpell(HK_Q, Pred.CastPosition)
        lastQ = GetTickCount()
    end
end
end

function Braum:CastR(target)
if Ready(_R) and lastR + 350 < GetTickCount() and orbwalker:CanMove() then
    local Pred = GamsteronPrediction:GetPrediction(target, self.R, myHero)
    if Pred.Hitchance >= _G.HITCHANCE_NORMAL then
        Control.CastSpell(HK_R, Pred.CastPosition)
        lastR = GetTickCount()
    end
end
end
--[[
_   _   _   _   _  
/ \ / \ / \ / \ / \ 
( T | A | R | I | C )
\_/ \_/ \_/ \_/ \_/ 
]]
class "Leona"
function Leona:__init()

self.Q = {Type = _G.SPELLTYPE_CIRCLE, Range = 100}
self.W = {Type = _G.SPELLTYPE_CIRCLE, Delay = 3, Range = 450, Speed = 828.5}
self.E = {Type = _G.SPELLTYPE_CIRCLE, Range = 1200, Speed = 20}
self.R = {Type = _G.SPELLTYPE_LINE, Delay = 0, Radius = 80, Range = 1250, Speed = 1200, Collision = false}


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
["LeonaIcon"] = "https://vignette.wikia.nocookie.net/leagueoflegends/images/b/ba/Leona_OriginalSquare.png",
["Q"] = "https://vignette.wikia.nocookie.net/leagueoflegends/images/c/c6/Shield_of_Daybreak.png",
["W"] = "https://vignette.wikia.nocookie.net/leagueoflegends/images/c/c5/Eclipse.png",
["E"] = "https://vignette.wikia.nocookie.net/leagueoflegends/images/9/91/Zenith_Blade.png",
["R"] = "https://vignette.wikia.nocookie.net/leagueoflegends/images/5/5c/Solar_Flare.png",
["EXH"] = "https://vignette.wikia.nocookie.net/leagueoflegends/images/4/4a/Exhaust.png",
["IGN"] = "https://vignette.wikia.nocookie.net/leagueoflegends/images/f/f4/Ignite.png"
}


function Leona:LoadMenu()
self.shadowMenu = MenuElement({type = MENU, id = "shadowLeona", name = "Shadow Leona"})

-- COMBO --
self.shadowMenu:MenuElement({type = MENU, id = "combo", name = "Combo"})
self.shadowMenu.combo:MenuElement({id = "Q", name = "Use Q in Combo", value = true})
self.shadowMenu.combo:MenuElement({id = "W", name = "Use W in Combo", value = false})
self.shadowMenu.combo:MenuElement({id = "E", name = "Use E in  Combo", value = true})
self.shadowMenu.combo:MenuElement({id = "R", name = "Use R in  Combo", value = true})
self.shadowMenu.combo:MenuElement({id = "userammount", name = "Activate [R] when x enemies hit", value = 1, min = 1, max = 5, identifier = "#"})

-- AUTO R --
self.shadowMenu:MenuElement({type = MENU, id = "autor", name = "Auto R Settings"})
self.shadowMenu.autor:MenuElement({id = "useautor", name = "Use auto [R]", value = true})
self.shadowMenu.autor:MenuElement({id = "autorammount", name = "Activate [R] when x enemies hit", value = 1, min = 1, max = 5, identifier = "#"})


-- DRAWING SETTINGS --
self.shadowMenu:MenuElement({type = MENU, id = "drawings", name = "Drawing Settings"})
self.shadowMenu.drawings:MenuElement({id = "drawAutoR", name = "Draw if auto [R] is on", value = true})


-- SUMMONER SETTINGS --
self.shadowMenu:MenuElement({type = MENU, id = "SummonerSettings", name = "Summoner Settings"})
if myHero:GetSpellData(SUMMONER_1).name == "SummonerDot" then
    self.shadowMenu.SummonerSettings:MenuElement({id = "UseIgnite", name = "Use [Ignite] if killable?", value = true})
elseif myHero:GetSpellData(SUMMONER_2).name == "SummonerDot" then
    self.shadowMenu.SummonerSettings:MenuElement({id = "UseIgnite", name = "Use [Ignite] if killable?", value = true}) 
end

if myHero:GetSpellData(SUMMONER_1).name == "SummonerExhaust" then
    self.shadowMenu.SummonerSettings:MenuElement({id = "UseExhaust", name = "Use [Exhaust] on engage?", value = true})
elseif myHero:GetSpellData(SUMMONER_2).name == "SummonerExhaust" then
    self.shadowMenu.SummonerSettings:MenuElement({id = "UseExhaust", name = "Use [Exhaust] on engage?", value = true}) 
end

end


function Leona:Draw()

if self.shadowMenu.drawings.drawAutoR:Value() then
    Draw.Text("Auto Cast R: ", 15, 5, 30, Draw.Color(255, 225, 255, 0))
        if self.shadowMenu.autor.useautor:Value() then
            Draw.Text("ON", 15, 85, 30, Draw.Color(255, 0, 255, 0))
            else
                Draw.Text("OFF", 15, 85, 30, Draw.Color(255, 255, 0, 0))
        end 
end

end

function Leona:Tick()
if myHero.dead or Game.IsChatOpen() or (ExtLibEvade and ExtLibEvade.Evading == true) then
    return
end
self:AutoR()
self:AutoSummoners()
if orbwalker.Modes[0] then
    self:Combo()
elseif orbwalker.Modes[3] then
end
end

function Leona:AutoSummoners()

-- IGNITE --
local target = TargetSelector:GetTarget(self.Q.Range, 1)
if target and IsValid(target) then
local ignDmg = getdmg("IGNITE", target, myHero)
if myHero:GetSpellData(SUMMONER_1).name == "SummonerDot" and Ready(SUMMONER_1) and (target.health < ignDmg ) then
    Control.CastSpell(HK_SUMMONER_1, target)
elseif myHero:GetSpellData(SUMMONER_2).name == "SummonerDot" and Ready(SUMMONER_2) and (target.health < ignDmg ) then
    Control.CastSpell(HK_SUMMONER_2, target)
end
end


end

function Leona:Combo()
local EPred = GamsteronPrediction:GetPrediction(target, self.E, myHero)
local target = TargetSelector:GetTarget(self.E.Range, 1)
if Ready(_E) and target and IsValid(target) then
    if self.shadowMenu.combo.E:Value() then
        self:CastE(target)
    end
end
local target = TargetSelector:GetTarget(self.Q.Range, 1)
if Ready(_Q) and target and IsValid(target) then
    if self.shadowMenu.combo.Q:Value() then
        Control.CastSpell(HK_Q)
    end
end

local target = TargetSelector:GetTarget(self.W.Range, 1)
if Ready(_W) and target and IsValid(target) then
    if self.shadowMenu.combo.W:Value() then
        Control.CastSpell(HK_W)
        --self:CastSpell(HK_Etarget)
    end
end

local target = TargetSelector:GetTarget(self.R.Range, 1)
if target and IsValid(target) then
    if self.shadowMenu.combo.R:Value() and CountEnemiesNear(target, 1250) >= self.shadowMenu.combo.userammount:Value() and Ready(_R) then
        self:CastR(target)
    end
end

end

function Leona:jungleclear()
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
                Control.CastSpell(HK_W);
            end
        end
        end
    end
end
end

function Leona:AutoR()
local target = TargetSelector:GetTarget(self.R.Range, 1)
if target and IsValid(target) then
    if self.shadowMenu.autor.useautor:Value() and CountEnemiesNear(target, 1250) >= self.shadowMenu.autor.autorammount:Value() and Ready(_R) then
        self:CastR(target)
    end
end
end

function Leona:CastE(target)
if Ready(_E) and lastE + 350 < GetTickCount() and orbwalker:CanMove() then
    local Pred = GamsteronPrediction:GetPrediction(target, self.E, myHero)
    if Pred.Hitchance >= _G.HITCHANCE_NORMAL then
        Control.CastSpell(HK_E, Pred.CastPosition)
        lastE = GetTickCount()
    end
end
end

function Leona:CastR(target)
if Ready(_R) and lastR + 350 < GetTickCount() and orbwalker:CanMove() then
    local Pred = GamsteronPrediction:GetPrediction(target, self.R, myHero)
    if Pred.Hitchance >= _G.HITCHANCE_NORMAL then
        Control.CastSpell(HK_R, Pred.CastPosition)
        lastR = GetTickCount()
    end
end
end
--[[
   _   _   _  
  / \ / \ / \ 
 ( Z | E | D )
  \_/ \_/ \_/ 
]]
class "Zed"
function Zed:__init()

self.Q = {speed = 900, range = 900, delay = 0.25, radius = 50, type = "linear"}
self.W = {speed = 1750, range = 650, delay = 0.25, radius = 1950, type = "linear"}
self.E = {speed = 1337000, range = 290, delay = 0.25, radius = 290, type = "Circular"}
self.R = {speed = 1337000, range = 625, delay = 0.25, radius = 0, type = "Circular"}


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
["ZedIcon"] = "https://vignette.wikia.nocookie.net/leagueoflegends/images/4/46/Zed_OriginalSquare.png",
["Q"] = "https://vignette.wikia.nocookie.net/leagueoflegends/images/9/96/Razor_Shuriken.png",
["W"] = "https://vignette.wikia.nocookie.net/leagueoflegends/images/3/3f/Living_Shadow.png",
["E"] = "https://vignette.wikia.nocookie.net/leagueoflegends/images/4/45/Shadow_Slash.png",
["R"] = "https://vignette.wikia.nocookie.net/leagueoflegends/images/3/34/Death_Mark.png",
["EXH"] = "https://vignette.wikia.nocookie.net/leagueoflegends/images/4/4a/Exhaust.png",
["IGN"] = "https://vignette.wikia.nocookie.net/leagueoflegends/images/f/f4/Ignite.png"
}


function Zed:LoadMenu()
self.shadowMenu = MenuElement({type = MENU, id = "shadowZed", name = "Shadow Zed"})

-- COMBO --
self.shadowMenu:MenuElement({type = MENU, id = "combo", name = "Combo"})
self.shadowMenu.combo:MenuElement({id = "Q", name = "Use Q in Combo", value = true})
self.shadowMenu.combo:MenuElement({id = "W", name = "Use W in Combo", value = true})
self.shadowMenu.combo:MenuElement({id = "E", name = "Use E in  Combo", value = true})
self.shadowMenu.combo:MenuElement({id = "R", name = "Use R in  Combo", value = true})
self.shadowMenu.combo:MenuElement({id = "userkillable", name = "Activate [R] when full combo can kill", value = true})

-- COMBO --
self.shadowMenu:MenuElement({type = MENU, id = "harass", name = "Harass"})
self.shadowMenu.harass:MenuElement({id = "Q", name = "Use Q in Combo", value = true})
self.shadowMenu.harass:MenuElement({id = "W", name = "Use W in Combo", value = true})
self.shadowMenu.harass:MenuElement({id = "E", name = "Use E in  Combo", value = true})

-- AUTO R --
self.shadowMenu:MenuElement({type = MENU, id = "autor", name = "Auto R Settings"})
self.shadowMenu.autor:MenuElement({id = "useautor", name = "Use auto [R]", value = true})
self.shadowMenu.autor:MenuElement({id = "autorammount", name = "Activate [R] when x enemies hit", value = 1, min = 1, max = 5, identifier = "#"})


-- DRAWING SETTINGS --
self.shadowMenu:MenuElement({type = MENU, id = "drawings", name = "Drawing Settings"})
self.shadowMenu.drawings:MenuElement({id = "drawW", name = "Draw [W] Range", value = true})
self.shadowMenu.drawings:MenuElement({id = "drawQ", name = "Draw [Q] Range", value = true})
self.shadowMenu.drawings:MenuElement({id = "drawE", name = "Draw [E] Range", value = true})
self.shadowMenu.drawings:MenuElement({id = "drawR", name = "Draw [R] Range", value = true})
self.shadowMenu.drawings:MenuElement({id = "drawRkillabletext", name = "Draw Killable with full combo", value = true})


-- SUMMONER SETTINGS --
self.shadowMenu:MenuElement({type = MENU, id = "SummonerSettings", name = "Summoner Settings"})
if myHero:GetSpellData(SUMMONER_1).name == "SummonerDot" then
    self.shadowMenu.SummonerSettings:MenuElement({id = "UseIgnite", name = "Use [Ignite] if killable?", value = true})
elseif myHero:GetSpellData(SUMMONER_2).name == "SummonerDot" then
    self.shadowMenu.SummonerSettings:MenuElement({id = "UseIgnite", name = "Use [Ignite] if killable?", value = true}) 
end

if myHero:GetSpellData(SUMMONER_1).name == "SummonerExhaust" then
    self.shadowMenu.SummonerSettings:MenuElement({id = "UseExhaust", name = "Use [Exhaust] on engage?", value = true})
elseif myHero:GetSpellData(SUMMONER_2).name == "SummonerExhaust" then
    self.shadowMenu.SummonerSettings:MenuElement({id = "UseExhaust", name = "Use [Exhaust] on engage?", value = true}) 
end

end


function Zed:Draw()

if self.shadowMenu.drawings.drawW:Value() then
    if Ready(_W) then
        Draw.Circle(myHero, 650, 1, Draw.Color(255, 255, 0, 255))
    end
end

if self.shadowMenu.drawings.drawQ:Value() then
    if Ready(_Q) then
        Draw.Circle(myHero, 900, 1, Draw.Color(255, 255, 0, 255))
    end
end

if self.shadowMenu.drawings.drawE:Value() then
    if Ready(_E) then
        Draw.Circle(myHero, 290, 1, Draw.Color(255, 255, 0, 255))
    end
end

if self.shadowMenu.drawings.drawR:Value() then
    if Ready(_R) then
        Draw.Circle(myHero, 625, 1, Draw.Color(255, 255, 0, 255))
    end
end

for i = 1,Game.HeroCount() do
    local hero = Game.Hero(i)
    if hero and IsValid(hero) and hero.team ~= myHero.team and (getdmg("R", hero, myHero) + (getdmg("Q", hero, myHero) * 2) + getdmg("E", hero, myHero) + (myHero.totalDamage * 2)) > hero.health then
        if Ready(_Q) and Ready(_W) and Ready(_E) and Ready(_R) then
            Draw.Text("Killable with [Full Combo]", 18, hero.pos2D.x - 100, hero.pos2D.y + 60, Draw.Color(255, 225, 0, 0))
        end
    end
end

end

function Zed:Tick()
if myHero.dead or Game.IsChatOpen() or (ExtLibEvade and ExtLibEvade.Evading == true) then
    return
end
self:AutoSummoners()
if orbwalker.Modes[0] then
    self:Combo()
elseif orbwalker.Modes[1] then
    self:Harass()
elseif orbwalker.Modes[3] then
end
end


function Zed:AutoSummoners()

-- IGNITE --
local target = TargetSelector:GetTarget(self.Q.Range, 1)
if target and IsValid(target) then
local ignDmg = getdmg("IGNITE", target, myHero)
if myHero:GetSpellData(SUMMONER_1).name == "SummonerDot" and Ready(SUMMONER_1) and (target.health < ignDmg ) then
    Control.CastSpell(HK_SUMMONER_1, target)
elseif myHero:GetSpellData(SUMMONER_2).name == "SummonerDot" and Ready(SUMMONER_2) and (target.health < ignDmg ) then
    Control.CastSpell(HK_SUMMONER_2, target)
end
end
end

function Zed:Harass()

    local target = TargetSelector:GetTarget(self.W.Range, 1)
    if target == nil then end
    local d = myHero.pos:DistanceTo(target.pos)
    if target and IsValid(target) then
            if self.shadowMenu.harass.W:Value() and Ready(_W) and myHero:GetSpellData(_W).name ~= "ZedW2" and (d <= 650) then
            Control.CastSpell(HK_W, target)
        end
    end

    if CheckBuffs(myHero, "ZedWHandler") > 0 then
        print(CheckBuffs(myHero, "ZedWHandler") > 0)
        local target = TargetSelector:GetTarget(self.E.Range, 1)
        if target == nil then end
        local pred = _G.PremiumPrediction:GetPrediction(myHero, target, self.E)
        if target and IsValid(target) then
            local d = pred.CastPos:DistanceTo(target.pos)
            if self.shadowMenu.harass.E:Value() and Ready(_E) and (d <= 270) then
            Control.CastSpell(HK_E)
            end
        end
    end

    if not Ready(_W) then
        local target = TargetSelector:GetTarget(self.E.Range, 1)
        if target == nil then end
        local pred = _G.PremiumPrediction:GetPrediction(myHero, target, self.E)
        if target and IsValid(target) then
            local d = myHero.pos:DistanceTo(target.pos)
            if self.shadowMenu.harass.E:Value() and Ready(_E) and (d <= 270) then
            Control.CastSpell(HK_E)
            end
        end
    end

    local target = TargetSelector:GetTarget(self.W.Range, 1)
    if target == nil then end
    if target and IsValid(target) then
        if self.shadowMenu.harass.Q:Value() and Ready(_Q) then
            self:CastQ(target)
        end
    end

end

function Zed:Combo()
    local target = TargetSelector:GetTarget(self.R.Range, 1)
    if target == nil then end
    if target and IsValid(target) then
        local d = myHero.pos:DistanceTo(target.pos)
        if self.shadowMenu.combo.R:Value() and Ready(_R) and (d <= 630) then
            Control.CastSpell(HK_R, target)
        end
    end

    DelayAction(function()
		local target = TargetSelector:GetTarget(self.W.Range, 1)
		if target == nil then end
		if target and IsValid(target) then
			local d = myHero.pos:DistanceTo(target.pos)
			if self.shadowMenu.combo.W:Value() and Ready(_W) and myHero:GetSpellData(_W).name ~= "ZedW2" and (d <= 650) then
				Control.CastSpell(HK_W, target)
			end
		end
	end, 0.75)

    if CheckBuffs(myHero, "ZedWHandler") > 0 then
        local target = TargetSelector:GetTarget(self.E.Range, 1)
        if target == nil then end
        local pred = _G.PremiumPrediction:GetPrediction(myHero, target, self.E)
        if target and IsValid(target) then
            local d = pred.CastPos:DistanceTo(target.pos)
            if self.shadowMenu.combo.E:Value() and Ready(_E) and (d <= 270) then
            Control.CastSpell(HK_E)
            end
        end
    end

    if not Ready(_W) then
        local target = TargetSelector:GetTarget(self.E.Range, 1)
        if target == nil then end
        local pred = _G.PremiumPrediction:GetPrediction(myHero, target, self.E)
        if target and IsValid(target) then
            local d = myHero.pos:DistanceTo(target.pos)
            if self.shadowMenu.combo.E:Value() and Ready(_E) and (d <= 270) then
            Control.CastSpell(HK_E)
            end
        end
    end

    local target = TargetSelector:GetTarget(self.Q.Range, 1)
    if target == nil then end
    local pred = _G.PremiumPrediction:GetPrediction(myHero, target, self.Q)
    print(pred.HitChance)
    if target and IsValid(target) then
        if self.shadowMenu.combo.Q:Value() and Ready(_Q) then
            self:CastQ(target)
        end
    end
end


--[[

Cast Spells Below


]]

function Zed:CastQ(target)
    if Ready(_Q) and lastQ + 350 < GetTickCount() and orbwalker:CanMove() then
        local pred = _G.PremiumPrediction:GetPrediction(myHero, target, self.Q)
        if pred.CastPos and _G.PremiumPrediction.HitChance.Medium(pred.HitChance) and Game.CanUseSpell(_Q) == 0 then
            Control.CastSpell(HK_Q, pred.CastPos)
            lastQ = GetTickCount()
        end
    end
end

function Zed:CastW(target)
    if Ready(_W) and lastW + 350 < GetTickCount() and orbwalker:CanMove() then
        local pred = _G.PremiumPrediction:GetPrediction(myHero, target, self.W)
        if pred.CastPos and _G.PremiumPrediction.HitChance.Medium(pred.HitChance) and Game.CanUseSpell(_W) == 0 then
            Control.CastSpell(HK_W, pred.CastPos)
            lastW = GetTickCount()
        end
    end
end

function Zed:CastR(target)
    if Ready(_R) and lastR + 350 < GetTickCount() and orbwalker:CanMove() then
        local pred = _G.PremiumPrediction:GetPrediction(myHero, target, self.R)
        if pred.CastPos and _G.PremiumPrediction.HitChance.Medium(pred.HitChance) and Game.CanUseSpell(_R) == 0 then
            Control.CastSpell(HK_R, pred.CastPos)
            lastR = GetTickCount()
        end
    end
end

--[[
   _   _   _  
  / \ / \ / \ 
 ( Z | E | D )
  \_/ \_/ \_/ 
]]
class "Olaf"
function Olaf:__init()

self.Q = {_G.SPELLTYPE_LINE, Delay = 0.225, Radius = 50, Range = 1000, Speed = 1500, Collision = false}



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
["OlafIcon"] = "https://vignette.wikia.nocookie.net/leagueoflegends/images/7/7e/Olaf_OriginalSquare.png",
["Q"] = "https://vignette.wikia.nocookie.net/leagueoflegends/images/6/61/Undertow.png",
["W"] = "https://vignette.wikia.nocookie.net/leagueoflegends/images/a/ad/Vicious_Strikes.png",
["E"] = "https://vignette.wikia.nocookie.net/leagueoflegends/images/2/25/Reckless_Swing.png",
["R"] = "https://vignette.wikia.nocookie.net/leagueoflegends/images/6/68/Ragnarok.png",
["EXH"] = "https://vignette.wikia.nocookie.net/leagueoflegends/images/4/4a/Exhaust.png",
["IGN"] = "https://vignette.wikia.nocookie.net/leagueoflegends/images/f/f4/Ignite.png"
}


function Olaf:LoadMenu()
self.shadowMenu = MenuElement({type = MENU, id = "shadowOlaf", name = "Shadow Olaf"})

-- COMBO --
self.shadowMenu:MenuElement({type = MENU, id = "combo", name = "Combo"})
self.shadowMenu.combo:MenuElement({id = "Q", name = "Use Q in Combo", value = true})
self.shadowMenu.combo:MenuElement({id = "W", name = "Use W in Combo", value = true})
self.shadowMenu.combo:MenuElement({id = "E", name = "Use E in  Combo", value = true})
self.shadowMenu.combo:MenuElement({id = "R", name = "Use R in  Combo", value = true})
self.shadowMenu.combo:MenuElement({id = "userkillable", name = "Activate [R] when full combo can kill", value = true})

-- JUNGLE CLEAR --
self.shadowMenu:MenuElement({type = MENU, id = "jungleclear", name = "Jungle Clear"})
self.shadowMenu.jungleclear:MenuElement({id = "useq", name = "Use [Q] in clear", value = true})
self.shadowMenu.jungleclear:MenuElement({id = "usee", name = "Use [E] in clear", value = true})

-- AUTO R --
self.shadowMenu:MenuElement({type = MENU, id = "autor", name = "Auto R Settings"})
self.shadowMenu.autor:MenuElement({id = "useautor", name = "Use auto [R]", value = true})
self.shadowMenu.autor:MenuElement({id = "autorammount", name = "Activate [R] when x enemies hit", value = 1, min = 1, max = 5, identifier = "#"})


-- DRAWING SETTINGS --
self.shadowMenu:MenuElement({type = MENU, id = "drawings", name = "Drawing Settings"})
self.shadowMenu.drawings:MenuElement({id = "drawW", name = "Draw [W] Range", value = true})
self.shadowMenu.drawings:MenuElement({id = "drawQ", name = "Draw [Q] Range", value = true})
self.shadowMenu.drawings:MenuElement({id = "drawE", name = "Draw [E] Range", value = true})
self.shadowMenu.drawings:MenuElement({id = "drawR", name = "Draw [R] Range", value = true})
self.shadowMenu.drawings:MenuElement({id = "drawRkillabletext", name = "Draw Killable with full combo", value = true})


-- SUMMONER SETTINGS --
self.shadowMenu:MenuElement({type = MENU, id = "SummonerSettings", name = "Summoner Settings"})
if myHero:GetSpellData(SUMMONER_1).name == "SummonerDot" then
    self.shadowMenu.SummonerSettings:MenuElement({id = "UseIgnite", name = "Use [Ignite] if killable?", value = true})
elseif myHero:GetSpellData(SUMMONER_2).name == "SummonerDot" then
    self.shadowMenu.SummonerSettings:MenuElement({id = "UseIgnite", name = "Use [Ignite] if killable?", value = true}) 
end

if myHero:GetSpellData(SUMMONER_1).name == "SummonerExhaust" then
    self.shadowMenu.SummonerSettings:MenuElement({id = "UseExhaust", name = "Use [Exhaust] on engage?", value = true})
elseif myHero:GetSpellData(SUMMONER_2).name == "SummonerExhaust" then
    self.shadowMenu.SummonerSettings:MenuElement({id = "UseExhaust", name = "Use [Exhaust] on engage?", value = true}) 
end

end


function Olaf:Draw()

if self.shadowMenu.drawings.drawW:Value() then
    if Ready(_W) then
        Draw.Circle(myHero, 650, 1, Draw.Color(255, 255, 0, 255))
    end
end

if self.shadowMenu.drawings.drawQ:Value() then
    if Ready(_Q) then
        Draw.Circle(myHero, 1000, 1, Draw.Color(255, 255, 0, 255))
    end
end

if self.shadowMenu.drawings.drawE:Value() then
    if Ready(_E) then
        Draw.Circle(myHero, 290, 1, Draw.Color(255, 255, 0, 255))
    end
end

if self.shadowMenu.drawings.drawR:Value() then
    if Ready(_R) then
        Draw.Circle(myHero, 625, 1, Draw.Color(255, 255, 0, 255))
    end
end

for i = 1,Game.HeroCount() do
    local hero = Game.Hero(i)
    if hero and IsValid(hero) and hero.team ~= myHero.team and (getdmg("R", hero, myHero) + (getdmg("Q", hero, myHero) * 2) + getdmg("E", hero, myHero) + (myHero.totalDamage * 2)) > hero.health then
        if Ready(_Q) and Ready(_W) and Ready(_E) and Ready(_R) then
            Draw.Text("Killable with [Full Combo]", 18, hero.pos2D.x - 100, hero.pos2D.y + 60, Draw.Color(255, 225, 0, 0))
        end
    end
end

end

function Olaf:Tick()
if myHero.dead or Game.IsChatOpen() or (ExtLibEvade and ExtLibEvade.Evading == true) then
    return
end
if orbwalker.Modes[0] then
    self:Combo()
elseif orbwalker.Modes[1] then
    self:Harass()
elseif orbwalker.Modes[3] then
    self:jungleclear()
end
end

function Olaf:jungleclear()

    for i = 1, Game.MinionCount() do
        local obj = Game.Minion(i)
        if obj.team ~= myHero.team then
            if obj ~= nil and obj.valid and obj.visible and not obj.dead then
                if Ready(_Q) and self.shadowMenu.jungleclear.useq:Value() and obj and obj.team == 300 and obj.valid and obj.visible and not obj.dead and (obj.pos:DistanceTo(myHero.pos) < self.Q.Range) then
                    Control.CastSpell(HK_Q, obj)
                end
                if Ready(_E) and self.shadowMenu.jungleclear.usee:Value() and obj and obj.team == 300 and obj.valid and obj.visible and not obj.dead and (obj.pos:DistanceTo(myHero.pos) < self.Q.Range) then
                    Control.CastSpell(HK_E);
                end
            end
        end        
    end
end

function Olaf:Combo()
    local target = TargetSelector:GetTarget(self.Q.Range, 1)
    if target == nil then end
    local pred = _G.PremiumPrediction:GetPrediction(myHero, target, self.Q)
    local d = myHero.pos:DistanceTo(target.pos)
    print(pred.HitChance)
    if target and IsValid(target) then
        if self.shadowMenu.combo.Q:Value() and Ready(_Q) then
            self:CastQ(target)
        end
        if self.shadowMenu.combo.E:Value() and Ready(_E) and d <= 325 then
            Control.CastSpell(HK_E, target)
        end
        if self.shadowMenu.combo.W:Value() and Ready(_W) and d <= 100 then
            Control.CastSpell(HK_W)
        end
    end
end


--[[

Cast Spells Below

]]

function Olaf:CastQ(target)
    if Ready(_Q) and lastQ + 350 < GetTickCount() and orbwalker:CanMove() then
        local Pred = GamsteronPrediction:GetPrediction(target, self.Q, myHero)
        if Pred.Hitchance >= _G.HITCHANCE_HIGH then
            Control.CastSpell(HK_Q, Pred.CastPosition)
            lastQ = GetTickCount()
        end
    end
end

--[[
   _   _   _   _   _   _   _  
  / \ / \ / \ / \ / \ / \ / \ 
 ( h | e | c | a | r | i | m )
  \_/ \_/ \_/ \_/ \_/ \_/ \_/ 
]]

class "Hecarim"
function Hecarim:__init()

    self.Q = {_G.SPELLTYPE_CIRCLE, Delay = 0.225, Radius = 350, Range = 350, Speed = 1750, Collision = true, MaxCollision = 0, CollisionTypes = {_G.COLLISION_MINION}}
    self.W = {_G.SPELLTYPE_CIRCLE, Delay = 0.1, Radius = 575, Range = 575, Speed = 1800, Collision = false}
    self.R = {_G.SPELLTYPE_CIRCLE, Delay = 0.1, Radius = 1000, Range = 1000, Speed = 1800, Collision = false}
    


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
["HecarimIcon"] = "https://vignette.wikia.nocookie.net/leagueoflegends/images/c/ca/Hecarim_OriginalSquare.png",
["Q"] = "https://vignette.wikia.nocookie.net/leagueoflegends/images/e/e4/Rampage.png",
["W"] = "https://vignette.wikia.nocookie.net/leagueoflegends/images/4/4d/Spirit_of_Dread.png",
["E"] = "https://vignette.wikia.nocookie.net/leagueoflegends/images/a/ac/Devastating_Charge.png",
["R"] = "https://vignette.wikia.nocookie.net/leagueoflegends/images/a/ac/Devastating_Charge.png",
["EXH"] = "https://vignette.wikia.nocookie.net/leagueoflegends/images/4/4a/Exhaust.png",
["IGN"] = "https://vignette.wikia.nocookie.net/leagueoflegends/images/f/f4/Ignite.png"
}


function Hecarim:LoadMenu()
self.shadowMenu = MenuElement({type = MENU, id = "shadowHecarim", name = "Shadow Hecarim"})

-- COMBO --
self.shadowMenu:MenuElement({type = MENU, id = "combo", name = "Combo"})
self.shadowMenu.combo:MenuElement({id = "Q", name = "Use Q in Combo", value = true})
self.shadowMenu.combo:MenuElement({id = "W", name = "Use W in Combo", value = true})
self.shadowMenu.combo:MenuElement({id = "E", name = "Use E in  Combo", value = true})
self.shadowMenu.combo:MenuElement({id = "R", name = "Use R in  Combo", value = true})
self.shadowMenu.combo:MenuElement({id = "userkillable", name = "Activate [R] when can hit x targers", value = 1, min = 1, max = 5, identifier = "#"})

-- JUNGLE CLEAR --
self.shadowMenu:MenuElement({type = MENU, id = "jungleclear", name = "Jungle Clear"})
self.shadowMenu.jungleclear:MenuElement({id = "useq", name = "Use [Q] in clear", value = true})
self.shadowMenu.jungleclear:MenuElement({id = "usew", name = "Use [W] in clear", value = true})


-- DRAWING SETTINGS --
self.shadowMenu:MenuElement({type = MENU, id = "drawings", name = "Drawing Settings"})
self.shadowMenu.drawings:MenuElement({id = "drawW", name = "Draw [W] Range", value = true})
self.shadowMenu.drawings:MenuElement({id = "drawQ", name = "Draw [Q] Range", value = true})
self.shadowMenu.drawings:MenuElement({id = "drawE", name = "Draw [E] Range", value = true})
self.shadowMenu.drawings:MenuElement({id = "drawR", name = "Draw [R] Range", value = true})
self.shadowMenu.drawings:MenuElement({id = "drawRkillabletext", name = "Draw Killable with full combo", value = true})


-- SUMMONER SETTINGS --
self.shadowMenu:MenuElement({type = MENU, id = "SummonerSettings", name = "Summoner Settings"})
if myHero:GetSpellData(SUMMONER_1).name == "SummonerDot" then
    self.shadowMenu.SummonerSettings:MenuElement({id = "UseIgnite", name = "Use [Ignite] if killable?", value = true})
elseif myHero:GetSpellData(SUMMONER_2).name == "SummonerDot" then
    self.shadowMenu.SummonerSettings:MenuElement({id = "UseIgnite", name = "Use [Ignite] if killable?", value = true}) 
end

if myHero:GetSpellData(SUMMONER_1).name == "SummonerExhaust" then
    self.shadowMenu.SummonerSettings:MenuElement({id = "UseExhaust", name = "Use [Exhaust] on engage?", value = true})
elseif myHero:GetSpellData(SUMMONER_2).name == "SummonerExhaust" then
    self.shadowMenu.SummonerSettings:MenuElement({id = "UseExhaust", name = "Use [Exhaust] on engage?", value = true}) 
end

end


function Hecarim:Draw()

if self.shadowMenu.drawings.drawW:Value() then
    if Ready(_W) then
        Draw.Circle(myHero, 650, 1, Draw.Color(255, 255, 0, 255))
    end
end

if self.shadowMenu.drawings.drawQ:Value() then
    if Ready(_Q) then
        Draw.Circle(myHero, 1000, 1, Draw.Color(255, 255, 0, 255))
    end
end

if self.shadowMenu.drawings.drawE:Value() then
    if Ready(_E) then
        Draw.Circle(myHero, 290, 1, Draw.Color(255, 255, 0, 255))
    end
end

if self.shadowMenu.drawings.drawR:Value() then
    if Ready(_R) then
        Draw.Circle(myHero, 625, 1, Draw.Color(255, 255, 0, 255))
    end
end

for i = 1,Game.HeroCount() do
    local hero = Game.Hero(i)
    if hero and IsValid(hero) and hero.team ~= myHero.team and (getdmg("R", hero, myHero) + (getdmg("Q", hero, myHero) * 2) + getdmg("E", hero, myHero) + (myHero.totalDamage * 2)) > hero.health then
        if Ready(_Q) and Ready(_W) and Ready(_E) and Ready(_R) then
            Draw.Text("Killable with [Full Combo]", 18, hero.pos2D.x - 100, hero.pos2D.y + 60, Draw.Color(255, 225, 0, 0))
        end
    end
end

end

function Hecarim:Tick()
if myHero.dead or Game.IsChatOpen() or (ExtLibEvade and ExtLibEvade.Evading == true) then
    return
end
if orbwalker.Modes[0] then
    self:Combo()
elseif orbwalker.Modes[1] then
elseif orbwalker.Modes[3] then
    self:jungleclear()
end
end

function Hecarim:jungleclear()

    for i = 1, Game.MinionCount() do
        local obj = Game.Minion(i)
        if obj.team ~= myHero.team then
            if obj ~= nil and obj.valid and obj.visible and not obj.dead then
                if Ready(_Q) and self.shadowMenu.jungleclear.useq:Value() and obj and obj.team == 300 and obj.valid and obj.visible and not obj.dead and obj.pos:DistanceTo(myHero.pos) < 800 then
                    Control.CastSpell(HK_Q, obj);
                end
            end
        end
        if Ready(_W) and self.shadowMenu.jungleclear.usew:Value() and obj and obj.team == 300 and obj.valid and obj.visible and not obj.dead and obj.pos:DistanceTo(myHero.pos) < 125 + myHero.boundingRadius then
            Control.CastSpell(HK_W);
        end
    end
end

function Hecarim:Combo()
    local target = TargetSelector:GetTarget(self.Q.Range, 1)
    if target == nil then end
    if Ready(_Q) and target and IsValid(target) then
        if self.shadowMenu.combo.Q:Value() then
            Control.CastSpell(HK_Q, target)
        end
    end
    if Ready(_E) and target and IsValid(target) then
        if self.shadowMenu.combo.E:Value() then
            Control.CastSpell(HK_E)
            --self:CastSpell(HK_Etarget)
        end
    end
    if Ready(_W) and target and IsValid(target) then
        if self.shadowMenu.combo.W:Value() then
            Control.KeyDown(HK_W)
            Control.KeyUp(HK_W)
            --self:CastSpell(HK_Etarget)
        end
    end
    local target = TargetSelector:GetTarget(self.R.Range, 1)
    if Ready(_R) and target and IsValid(target)then
        if self.shadowMenu.combo.R:Value() then
            --print("Value is true")
            self:CastR(target)
        end
    end
end


--[[
Cast Spells Below
]]

function Hecarim:CastR(target)
    if Ready(_R) and lastR + 350 < GetTickCount() and orbwalker:CanMove() then
        local Pred = GamsteronPrediction:GetPrediction(target, self.R, myHero)
        if Pred.Hitchance >= _G.HITCHANCE_HIGH then
            Control.CastSpell(HK_R, Pred.CastPosition)
            lastR = GetTickCount()
        end
    end
end

--[[
   _   _   _   _   _  
  / \ / \ / \ / \ / \ 
 ( A | N | N | I | E )
  \_/ \_/ \_/ \_/ \_/ 
]]

class "Annie"
function Annie:__init()

    self.Q = {_G.SPELLTYPE_CIRCLE, Delay = 0.225, Range = 625, Speed = 1400, Collision = true, MaxCollision = 1, CollisionTypes = {_G.COLLISION_MINION}}
    self.W = {_G.SPELLTYPE_CONE, Delay = 0.1, Range = 600, Collision = false}
    self.R = {_G.SPELLTYPE_CIRCLE, Delay = 0.1, Radius = 290, Range = 600, Collision = false}
    


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
["AnnieIcon"] = "https://vignette.wikia.nocookie.net/leagueoflegends/images/1/18/Annie_OriginalSquare.png",
["Q"] = "https://vignette.wikia.nocookie.net/leagueoflegends/images/2/25/Disintegrate.png",
["W"] = "https://vignette.wikia.nocookie.net/leagueoflegends/images/2/21/Incinerate.png",
["E"] = "https://vignette.wikia.nocookie.net/leagueoflegends/images/9/90/Molten_Shield.png",
["R"] = "https://vignette.wikia.nocookie.net/leagueoflegends/images/e/e7/Summon-_Tibbers.png",
["EXH"] = "https://vignette.wikia.nocookie.net/leagueoflegends/images/4/4a/Exhaust.png",
["IGN"] = "https://vignette.wikia.nocookie.net/leagueoflegends/images/f/f4/Ignite.png"
}


function Annie:LoadMenu()
self.shadowMenu = MenuElement({type = MENU, id = "shadowAnnie", name = "Shadow Annie"})

-- Q --
self.shadowMenu:MenuElement({type = MENU, id = "Q", name = "Q"})
self.shadowMenu.Q:MenuElement({id = "Qcombo", name = "Use [Q] in Combo", value = true})
self.shadowMenu.Q:MenuElement({id = "Qlast", name = "Use auto [Q] last hit", key = string.byte("T"), toggle = true, value = true})
self.shadowMenu.Q:MenuElement({id = "Qharass", name = "Use [Q] in Harass", value = true})

-- W --
self.shadowMenu:MenuElement({type = MENU, id = "W", name = "W"})
self.shadowMenu.W:MenuElement({id = "Wcombo", name = "Use [W] in Combo", value = true})
self.shadowMenu.W:MenuElement({id = "Wharass", name = "Use [W] in Harass", value = true})

-- E --
self.shadowMenu:MenuElement({type = MENU, id = "E", name = "E"})
self.shadowMenu.E:MenuElement({id = "Ecombo", name = "Use [E] in Combo", value = true})
self.shadowMenu.E:MenuElement({id = "Eharass", name = "Use [E] in Harass", value = true})

-- R --
self.shadowMenu:MenuElement({type = MENU, id = "R", name = "R"})
self.shadowMenu.R:MenuElement({id = "Rcombo", name = "Use [R] in Combo", value = true})
self.shadowMenu.R:MenuElement({id = "Rcombostun", name = "Use [R] in Combo only if stun", value = true})
self.shadowMenu.R:MenuElement({id = "Rhitable", name = "Activate [R] when can hit x targets", value = 1, min = 1, max = 5, identifier = "#"})



-- DRAWING SETTINGS --
self.shadowMenu:MenuElement({type = MENU, id = "drawings", name = "Drawing Settings"})
self.shadowMenu.drawings:MenuElement({id = "drawW", name = "Draw [W] Range", value = true})
self.shadowMenu.drawings:MenuElement({id = "drawQ", name = "Draw [Q] Range", value = true})
self.shadowMenu.drawings:MenuElement({id = "drawQauto", name = "Draw [Q] auto", value = true})
self.shadowMenu.drawings:MenuElement({id = "drawR", name = "Draw [R] Range", value = true})
self.shadowMenu.drawings:MenuElement({id = "drawRkillabletext", name = "Draw Killable with full combo", value = true})


-- SUMMONER SETTINGS --
self.shadowMenu:MenuElement({type = MENU, id = "SummonerSettings", name = "Summoner Settings"})
if myHero:GetSpellData(SUMMONER_1).name == "SummonerDot" then
    self.shadowMenu.SummonerSettings:MenuElement({id = "UseIgnite", name = "Use [Ignite] if killable?", value = true})
elseif myHero:GetSpellData(SUMMONER_2).name == "SummonerDot" then
    self.shadowMenu.SummonerSettings:MenuElement({id = "UseIgnite", name = "Use [Ignite] if killable?", value = true}) 
end

if myHero:GetSpellData(SUMMONER_1).name == "SummonerExhaust" then
    self.shadowMenu.SummonerSettings:MenuElement({id = "UseExhaust", name = "Use [Exhaust] on engage?", value = true})
elseif myHero:GetSpellData(SUMMONER_2).name == "SummonerExhaust" then
    self.shadowMenu.SummonerSettings:MenuElement({id = "UseExhaust", name = "Use [Exhaust] on engage?", value = true}) 
end

end


function Annie:Draw()

if self.shadowMenu.drawings.drawW:Value() then
    if Ready(_W) then
        Draw.Circle(myHero, 650, 1, Draw.Color(255, 255, 0, 255))
    end
end

if self.shadowMenu.drawings.drawQ:Value() then
    if Ready(_Q) then
        Draw.Circle(myHero, 1000, 1, Draw.Color(255, 255, 0, 255))
    end
end

if self.shadowMenu.drawings.drawQauto:Value() then
    if self.shadowMenu.Q.Qlast:Value() then
        local red = Draw.Color(255,255,0,0)
        local green = Draw.Color(255,0,255,0)
        Draw.Text("Auto Q Minions", 18, myHero.pos2D.x - 50, myHero.pos2D.y + 60, green)
    end

    if not self.shadowMenu.Q.Qlast:Value() then
        local red = Draw.Color(255,255,0,0)
        local green = Draw.Color(255,0,255,0)
        Draw.Text("Auto Q Minions", 18, myHero.pos2D.x - 50, myHero.pos2D.y + 60, red)
    end
end


if self.shadowMenu.drawings.drawR:Value() then
    if Ready(_R) then
        Draw.Circle(myHero, 625, 1, Draw.Color(255, 255, 0, 255))
    end
end

for i = 1,Game.HeroCount() do
    local hero = Game.Hero(i)
    if hero and IsValid(hero) and hero.team ~= myHero.team and (getdmg("R", hero, myHero) + (getdmg("Q", hero, myHero) * 2) + (myHero.totalDamage * 2)) > hero.health then
        if Ready(_Q) and Ready(_W) and Ready(_R) then
            Draw.Text("Killable with [Full Combo]", 18, hero.pos2D.x - 100, hero.pos2D.y + 60, Draw.Color(255, 225, 0, 0))
        end
    end
end

end

function Annie:Tick()
if myHero.dead or Game.IsChatOpen() or (ExtLibEvade and ExtLibEvade.Evading == true) then
    return
end
    self:autoQ()
if orbwalker.Modes[0] then
    self:Combo()
elseif orbwalker.Modes[1] then
    self:Harass()
elseif orbwalker.Modes[3] then
end
end

function Annie:autoQ()
    local AARange = 175 + myHero.boundingRadius
	local mtarget = nil
	local Minions = _G.SDK.ObjectManager:GetEnemyMinions(self.Q.range)
    for i = 1, #Minions do
        local minion = Minions[i]
        local qdmg = getdmg("Q", minion, myHero)
        local d = myHero.pos:DistanceTo(minion.pos)
        if Ready(_Q) and (minion.health <= qdmg) and self.shadowMenu.Q.Qlast:Value() and d < 625 then
            if mtarget == nil or minion.health < mtarget.health then
                mtarget = minion
                Control.CastSpell(HK_Q, mtarget)
            end			
        end
    end

end

function Annie:Harass()
    local target = TargetSelector:GetTarget(self.Q.Range, 1)
    if target == nil then end
    if Ready(_Q) and target and IsValid(target) then
        if self.shadowMenu.Q.Qharass:Value() then
            Control.CastSpell(HK_Q, target)
        end
    end

    local target = TargetSelector:GetTarget(self.W.Range, 1)
    if target == nil then end
    if Ready(_W) and target and IsValid(target) then
        if self.shadowMenu.W.Wharass:Value() then
            Control.CastSpell(HK_W, target)
        end
    end

    local target = TargetSelector:GetTarget(self.W.Range, 1)
    if target == nil then end
    if Ready(_E) and target and IsValid(target) then
        if self.shadowMenu.E.Eharass:Value() then
            Control.CastSpell(HK_E)
        end
    end
end

function Annie:Combo()

    local target = TargetSelector:GetTarget(self.R.Range, 1)
    if Ready(_R) and target and IsValid(target) then
        if self.shadowMenu.R.Rcombo:Value() and self.shadowMenu.R.Rcombostun:Value() then
            if CheckBuffs(myHero, "anniepassiveprimed") > 0 then
            self:CastR(target)
            end
        end
    end

    if Ready(_R) and target and IsValid(target) then
        if self.shadowMenu.R.Rcombo:Value() and not self.shadowMenu.R.Rcombostun:Value() then
            self:CastR(target)
        end
    end

    local target = TargetSelector:GetTarget(self.Q.Range, 1)
    if target == nil then end
    if Ready(_Q) and target and IsValid(target) then
        if self.shadowMenu.Q.Qcombo:Value() then
            Control.CastSpell(HK_Q, target)
        end
    end
    if Ready(_E) and target and IsValid(target) then
        if self.shadowMenu.E.Ecombo:Value() then
            Control.CastSpell(HK_E)
            --self:CastSpell(HK_Etarget)
        end
    end
    if Ready(_W) and target and IsValid(target) then
        if self.shadowMenu.W.Wcombo:Value() then
            Control.KeyDown(HK_W)
            Control.KeyUp(HK_W)
            --self:CastSpell(HK_Etarget)
        end
    end   
end


--[[
Cast Spells Below
]]

function Annie:CastR(target)
    if Ready(_R) and lastR + 350 < GetTickCount() and orbwalker:CanMove() then
        local Pred = GamsteronPrediction:GetPrediction(target, self.R, myHero)
        if Pred.Hitchance >= _G.HITCHANCE_HIGH then
            Control.CastSpell(HK_R, Pred.CastPosition)
            lastR = GetTickCount()
        end
    end
end

--[[
   _   _   _   _   _  
  / \ / \ / \ / \ / \ 
 ( A | N | N | I | E )
  \_/ \_/ \_/ \_/ \_/ 
]]

class "Garen"
function Garen:__init()

    self.Q = {_G.SPELLTYPE_CIRCLE, Delay = 0.225, Range = 600, Collision = false}
    self.E = {_G.SPELLTYPE_CIRCLE, Delay = 0.1, Radius = 160, Range = 660, Speed = 700, Collision = false}
    self.R = {_G.SPELLTYPE_CIRCLE, Delay = 0.1, Range = 400, Speed = 900, Collision = false}
    


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
["GarenIcon"] = "https://vignette.wikia.nocookie.net/leagueoflegends/images/9/97/Garen_OriginalSquare.png",
["Q"] = "https://vignette.wikia.nocookie.net/leagueoflegends/images/1/17/Decisive_Strike.png",
["W"] = "https://vignette.wikia.nocookie.net/leagueoflegends/images/2/25/Courage.png",
["E"] = "https://vignette.wikia.nocookie.net/leagueoflegends/images/1/15/Judgment.png",
["R"] = "https://vignette.wikia.nocookie.net/leagueoflegends/images/c/ce/Demacian_Justice.png",
["EXH"] = "https://vignette.wikia.nocookie.net/leagueoflegends/images/4/4a/Exhaust.png",
["IGN"] = "https://vignette.wikia.nocookie.net/leagueoflegends/images/f/f4/Ignite.png"
}


function Garen:LoadMenu()
self.shadowMenu = MenuElement({type = MENU, id = "shadowGaren", name = "Shadow Garen"})

-- Q --
self.shadowMenu:MenuElement({type = MENU, id = "Q", name = "Q"})
self.shadowMenu.Q:MenuElement({id = "Qcombo", name = "Use [Q] in Combo", value = true})

-- W --
self.shadowMenu:MenuElement({type = MENU, id = "W", name = "W"})
self.shadowMenu.W:MenuElement({id = "Wcombo", name = "Use [W] in Combo", value = true})
self.shadowMenu.W:MenuElement({id = "Wharass", name = "Use [W] in Harass", value = true})
-- E --
self.shadowMenu:MenuElement({type = MENU, id = "E", name = "E"})
self.shadowMenu.E:MenuElement({id = "Ecombo", name = "Use [E] in Combo", value = true})
self.shadowMenu.E:MenuElement({id = "Eharass", name = "Use [E] in Harass", value = true})

-- R --
self.shadowMenu:MenuElement({type = MENU, id = "R", name = "R"})
self.shadowMenu.R:MenuElement({id = "Rcombo", name = "Use [R] in Combo", value = true})
self.shadowMenu.R:MenuElement({id = "Rexecute", name = "Use [R] as execute", value = true})




-- DRAWING SETTINGS --
self.shadowMenu:MenuElement({type = MENU, id = "drawings", name = "Drawing Settings"})
self.shadowMenu.drawings:MenuElement({id = "drawrKillable", name = "Draw Killable with [R]", value = true})
self.shadowMenu.drawings:MenuElement({id = "drawfullKillable", name = "Draw Killable with full combo", value = true})

-- SUMMONER SETTINGS --
self.shadowMenu:MenuElement({type = MENU, id = "SummonerSettings", name = "Summoner Settings"})
if myHero:GetSpellData(SUMMONER_1).name == "SummonerDot" then
    self.shadowMenu.SummonerSettings:MenuElement({id = "UseIgnite", name = "Use [Ignite] if killable?", value = true})
elseif myHero:GetSpellData(SUMMONER_2).name == "SummonerDot" then
    self.shadowMenu.SummonerSettings:MenuElement({id = "UseIgnite", name = "Use [Ignite] if killable?", value = true}) 
end

if myHero:GetSpellData(SUMMONER_1).name == "SummonerExhaust" then
    self.shadowMenu.SummonerSettings:MenuElement({id = "UseExhaust", name = "Use [Exhaust] on engage?", value = true})
elseif myHero:GetSpellData(SUMMONER_2).name == "SummonerExhaust" then
    self.shadowMenu.SummonerSettings:MenuElement({id = "UseExhaust", name = "Use [Exhaust] on engage?", value = true}) 
end

end


function Garen:Draw()
if self.shadowMenu.drawings.drawfullKillable:Value() then
for i = 1,Game.HeroCount() do
    local hero = Game.Hero(i)
    if hero and IsValid(hero) and hero.team ~= myHero.team and (getdmg("R", hero, myHero) + (getdmg("Q", hero, myHero) * 2) + (myHero.totalDamage * 2)) > hero.health then
        if Ready(_Q) and Ready(_W) and Ready(_R) then
            Draw.Text("Killable with Full Combo", 18, hero.pos2D.x - 100, hero.pos2D.y - 200, Draw.Color(255, 225, 0, 0))
        end
    end
end
end

if self.shadowMenu.drawings.drawrKillable:Value() then
for i = 1,Game.HeroCount() do
    local hero = Game.Hero(i)
    local rdmg = getdmg("R", hero, myHero)
    if hero and IsValid(hero) and hero.team ~= myHero.team and rdmg > hero.health then
        if Ready(_R) then
            Draw.Text("Killable with [R]", 18, hero.pos2D.x - 100, hero.pos2D.y + 35, Draw.Color(255, 225, 0, 0))
        end
    end
end
end
end

function Garen:Tick()
if myHero.dead or Game.IsChatOpen() or (ExtLibEvade and ExtLibEvade.Evading == true) then
    return
end
    self:autoR()
    self:AutoSummoners()
if orbwalker.Modes[0] then
    self:Combo()
elseif orbwalker.Modes[1] then
    self:Harass()
elseif orbwalker.Modes[3] then
end
end

function Garen:Harass()
    local target = TargetSelector:GetTarget(self.Q.Range, 1)
    if target == nil then end
    if Ready(_Q) and target and IsValid(target) then
        if self.shadowMenu.Q.Qharass:Value() then
            Control.CastSpell(HK_Q, target)
        end
    end

    local target = TargetSelector:GetTarget(self.W.Range, 1)
    if target == nil then end
    if Ready(_W) and target and IsValid(target) then
        if self.shadowMenu.W.Wharass:Value() then
            Control.CastSpell(HK_W, target)
        end
    end

    local target = TargetSelector:GetTarget(self.W.Range, 1)
    if target == nil then end
    if Ready(_E) and target and IsValid(target) then
        if self.shadowMenu.E.Eharass:Value() then
            Control.CastSpell(HK_E)
        end
    end
end

function Garen:autoR()
    if self.shadowMenu.R.Rexecute:Value() then
        local target = TargetSelector:GetTarget(self.R.Range, 1)
        if target == nil then end
        if Ready(_R) and target and IsValid(target) then
            local rdmg = getdmg("R", target, myHero)
            if (rdmg >= target.health) then
				Control.CastSpell(HK_R, target)
            end
        end
    end
end

function Garen:AutoSummoners()
    -- IGNITE --
    local target = TargetSelector:GetTarget(self.Q.Range, 1)
    if target and IsValid(target) then
        local ignDmg = getdmg("IGNITE", target, myHero)
        if myHero:GetSpellData(SUMMONER_1).name == "SummonerDot" and Ready(SUMMONER_1) and (target.health < ignDmg ) then
            Control.CastSpell(HK_SUMMONER_1, target)
        elseif myHero:GetSpellData(SUMMONER_2).name == "SummonerDot" and Ready(SUMMONER_2) and (target.health < ignDmg ) then
            Control.CastSpell(HK_SUMMONER_2, target)
        end
    end
end

function Garen:Combo()
    local target = TargetSelector:GetTarget(self.Q.Range, 1)
    if target == nil then end
    if Ready(_Q) and target and IsValid(target) then
        if self.shadowMenu.Q.Qcombo:Value() then
            Control.CastSpell(HK_Q, target)
        end
    end

    if Ready(_W) and target and IsValid(target) then
        if self.shadowMenu.W.Wcombo:Value() then
            Control.CastSpell(HK_W)
            --self:CastSpell(HK_Etarget)
        end
    end

    if Ready(_E) and target and IsValid(target) then
        if self.shadowMenu.E.Ecombo:Value() and CheckBuffs(myHero, "GarenQ") == 0 then
            Control.CastSpell(HK_E)
            --self:CastSpell(HK_Etarget)
        end
    end
end


--[[
Cast Spells Below
]]

function Garen:CastR(target)
    if Ready(_R) and lastR + 350 < GetTickCount() and orbwalker:CanMove() then
        local Pred = GamsteronPrediction:GetPrediction(target, self.R, myHero)
        if Pred.Hitchance >= _G.HITCHANCE_HIGH then
            Control.CastSpell(HK_R, Pred.CastPosition)
            lastR = GetTickCount()
        end
    end
end

--[[
   _   _   _   _   _  
  / \ / \ / \ / \ / \ 
 ( A | N | N | I | E )
  \_/ \_/ \_/ \_/ \_/ 
]]

class "Malphite"
function Malphite:__init()

    self.Q = {_G.SPELLTYPE_CIRCLE, Delay = 0.225, Range = 625, Speed = 1200, Collision = false}
    self.E = {_G.SPELLTYPE_CIRCLE, Delay = 0.1, Range = 400, Collision = false}
    self.R = {_G.SPELLTYPE_CIRCLE, Delay = 0.1, Range = 1000, Radius = 160, Speed = 700, Collision = false}
    

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
["MalphiteIcon"] = "https://vignette.wikia.nocookie.net/leagueoflegends/images/1/10/Malphite_OriginalSquare.png",
["Q"] = "https://vignette.wikia.nocookie.net/leagueoflegends/images/3/3c/Seismic_Shard.png",
["W"] = "https://vignette.wikia.nocookie.net/leagueoflegends/images/8/8a/Thunderclap.png",
["E"] = "https://vignette.wikia.nocookie.net/leagueoflegends/images/c/c1/Ground_Slam.png",
["R"] = "https://vignette.wikia.nocookie.net/leagueoflegends/images/5/58/Unstoppable_Force.png",
["EXH"] = "https://vignette.wikia.nocookie.net/leagueoflegends/images/4/4a/Exhaust.png",
["IGN"] = "https://vignette.wikia.nocookie.net/leagueoflegends/images/f/f4/Ignite.png"
}


function Malphite:LoadMenu()
self.shadowMenu = MenuElement({type = MENU, id = "shadowMalphite", name = "Shadow Malphite"})

-- Q --
self.shadowMenu:MenuElement({type = MENU, id = "Q", name = "Q"})
self.shadowMenu.Q:MenuElement({id = "Qcombo", name = "Use [Q] in Combo", value = true})
self.shadowMenu.Q:MenuElement({id = "Qharass", name = "Use [Q] in Harass", value = true})

-- W --
self.shadowMenu:MenuElement({type = MENU, id = "W", name = "W"})
self.shadowMenu.W:MenuElement({id = "Wcombo", name = "Use [W] in Combo", value = true})
self.shadowMenu.W:MenuElement({id = "Wharass", name = "Use [W] in Harass", value = true})
-- E --
self.shadowMenu:MenuElement({type = MENU, id = "E", name = "E"})
self.shadowMenu.E:MenuElement({id = "Ecombo", name = "Use [E] in Combo", value = true})
self.shadowMenu.E:MenuElement({id = "Eharass", name = "Use [E] in Harass", value = true})

-- R --
self.shadowMenu:MenuElement({type = MENU, id = "R", name = "R"})
self.shadowMenu.R:MenuElement({id = "Rcombo", name = "Use [R] in Combo", value = true})
self.shadowMenu.R:MenuElement({id = "Rhitable", name = "Activate [R] when can hit x targets", value = 1, min = 1, max = 5, identifier = "#"})
self.shadowMenu.R:MenuElement({id = "Rexecute", name = "Use [R] to execute", value = true})



-- DRAWING SETTINGS --
self.shadowMenu:MenuElement({type = MENU, id = "drawings", name = "Drawing Settings"})
self.shadowMenu.drawings:MenuElement({id = "drawrKillable", name = "Draw Killable with [R]", value = true})
self.shadowMenu.drawings:MenuElement({id = "drawfullKillable", name = "Draw Killable with full combo", value = true})

-- SUMMONER SETTINGS --
self.shadowMenu:MenuElement({type = MENU, id = "SummonerSettings", name = "Summoner Settings"})
if myHero:GetSpellData(SUMMONER_1).name == "SummonerDot" then
    self.shadowMenu.SummonerSettings:MenuElement({id = "UseIgnite", name = "Use [Ignite] if killable?", value = true})
elseif myHero:GetSpellData(SUMMONER_2).name == "SummonerDot" then
    self.shadowMenu.SummonerSettings:MenuElement({id = "UseIgnite", name = "Use [Ignite] if killable?", value = true}) 
end

if myHero:GetSpellData(SUMMONER_1).name == "SummonerExhaust" then
    self.shadowMenu.SummonerSettings:MenuElement({id = "UseExhaust", name = "Use [Exhaust] on engage?", value = true})
elseif myHero:GetSpellData(SUMMONER_2).name == "SummonerExhaust" then
    self.shadowMenu.SummonerSettings:MenuElement({id = "UseExhaust", name = "Use [Exhaust] on engage?", value = true}) 
end

end

function Malphite:Draw()
if self.shadowMenu.drawings.drawfullKillable:Value() then
for i = 1,Game.HeroCount() do
    local hero = Game.Hero(i)
    if hero and IsValid(hero) and hero.team ~= myHero.team and (getdmg("R", hero, myHero) + (getdmg("Q", hero, myHero) * 2) + (myHero.totalDamage * 2)) > hero.health then
        if Ready(_Q) and Ready(_W) and Ready(_R) then
            Draw.Text("Killable with Full Combo", 18, hero.pos2D.x - 100, hero.pos2D.y - 200, Draw.Color(255, 225, 0, 0))
        end
    end
end
end

if self.shadowMenu.drawings.drawrKillable:Value() then
for i = 1,Game.HeroCount() do
    local hero = Game.Hero(i)
    local rdmg = getdmg("R", hero, myHero)
    if hero and IsValid(hero) and hero.team ~= myHero.team and rdmg > hero.health then
        if Ready(_R) then
            Draw.Text("Killable with [R]", 18, hero.pos2D.x - 100, hero.pos2D.y + 35, Draw.Color(255, 225, 0, 0))
        end
    end
end
end
end

function Malphite:Tick()
if myHero.dead or Game.IsChatOpen() or (ExtLibEvade and ExtLibEvade.Evading == true) then
    return
end
    self:autoR()
    self:AutoSummoners()
if orbwalker.Modes[0] then
    self:Combo()
elseif orbwalker.Modes[1] then
    self:Harass()
elseif orbwalker.Modes[3] then
end
end

function Malphite:Harass()
    local target = TargetSelector:GetTarget(self.Q.Range, 1)
    if target == nil then end
    if Ready(_Q) and target and IsValid(target) then
        if self.shadowMenu.Q.Qharass:Value() then
            Control.CastSpell(HK_Q, target)
        end
    end

    local target = TargetSelector:GetTarget(self.W.Range, 1)
    if target == nil then end
    if Ready(_W) and target and IsValid(target) then
        if self.shadowMenu.W.Wharass:Value() then
            Control.CastSpell(HK_W, target)
        end
    end

    local target = TargetSelector:GetTarget(self.W.Range, 1)
    if target == nil then end
    if Ready(_E) and target and IsValid(target) then
        if self.shadowMenu.E.Eharass:Value() then
            Control.CastSpell(HK_E)
        end
    end
end

function Malphite:autoR()
    if self.shadowMenu.R.Rexecute:Value() then
        local target = TargetSelector:GetTarget(self.R.Range, 1)
        if target == nil then end
        if Ready(_R) and target and IsValid(target) then
            local rdmg = getdmg("R", target, myHero)
            if (rdmg >= target.health) then
            Control.CastSpell(HK_R, target)
            end
        end
    end
end

function Malphite:AutoSummoners()
    -- IGNITE --
    local target = TargetSelector:GetTarget(self.Q.Range, 1)
    if target and IsValid(target) then
        local ignDmg = getdmg("IGNITE", target, myHero)
        if myHero:GetSpellData(SUMMONER_1).name == "SummonerDot" and Ready(SUMMONER_1) and (target.health < ignDmg ) then
            Control.CastSpell(HK_SUMMONER_1, target)
        elseif myHero:GetSpellData(SUMMONER_2).name == "SummonerDot" and Ready(SUMMONER_2) and (target.health < ignDmg ) then
            Control.CastSpell(HK_SUMMONER_2, target)
        end
    end
end

function Malphite:Combo()
    local target = TargetSelector:GetTarget(self.R.Range, 1)
    if target == nil then end
    if Ready(_R) and target and IsValid(target) then
        if self.shadowMenu.R.Rcombo:Value() and CountEnemiesNear(target, 1000) then
            self:CastR(target)
        end
    end

    local target = TargetSelector:GetTarget(self.Q.Range, 1)
    if target == nil then end
    if Ready(_Q) and target and IsValid(target) then
        if self.shadowMenu.Q.Qcombo:Value() then
            Control.CastSpell(HK_Q, target)
        end
    end

    if Ready(_W) and target and IsValid(target) then
        if self.shadowMenu.W.Wcombo:Value() then
            Control.CastSpell(HK_W)
        end
    end

    local target = TargetSelector:GetTarget(self.E.Range, 1)
    if target == nil then end
    if Ready(_E) and target and IsValid(target) then
        if self.shadowMenu.E.Ecombo:Value() then
            Control.CastSpell(HK_E)
        end
    end
end


--[[
Cast Spells Below
]]

function Malphite:CastR(target)
    if Ready(_R) and lastR + 350 < GetTickCount() and orbwalker:CanMove() then
        local Pred = GamsteronPrediction:GetPrediction(target, self.R, myHero)
        if Pred.Hitchance >= _G.HITCHANCE_HIGH then
            Control.CastSpell(HK_R, Pred.CastPosition)
            lastR = GetTickCount()
        end
    end
end

--[[
   _   _   _   _   _  
  / \ / \ / \ / \ / \ 
 ( A | N | N | I | E )
  \_/ \_/ \_/ \_/ \_/ 
]]

class "Chogath"
function Chogath:__init()

    self.Q = {_G.SPELLTYPE_CIRCLE, Delay =1.2, Range = 950, Radius = 250, Speed = math.huge, Collision = false}
    self.W = {_G.SPELLTYPE_CONE, Delay = 0.25, Range = 650, Radius = 60, Speed = math.huge, Collision = false}
    self.R = {_G.SPELLTYPE_CIRCLE, Delay = 0.1, Range = 175, Speed = 500, Collision = false}
    

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
["ChogathIcon"] = "https://vignette.wikia.nocookie.net/leagueoflegends/images/2/28/Cho%27Gath_OriginalSquare.png",
["Q"] = "https://vignette.wikia.nocookie.net/leagueoflegends/images/3/38/Rupture.png",
["W"] = "https://vignette.wikia.nocookie.net/leagueoflegends/images/3/3b/Feral_Scream.png",
["E"] = "https://vignette.wikia.nocookie.net/leagueoflegends/images/7/79/Vorpal_Spikes.png",
["R"] = "https://vignette.wikia.nocookie.net/leagueoflegends/images/2/2f/Feast.png",
["EXH"] = "https://vignette.wikia.nocookie.net/leagueoflegends/images/4/4a/Exhaust.png",
["IGN"] = "https://vignette.wikia.nocookie.net/leagueoflegends/images/f/f4/Ignite.png"
}


function Chogath:LoadMenu()
self.shadowMenu = MenuElement({type = MENU, id = "shadowChogath", name = "Shadow Chogath"})

-- Q --
self.shadowMenu:MenuElement({type = MENU, id = "Q", name = "Q"})
self.shadowMenu.Q:MenuElement({id = "Qcombo", name = "Use [Q] in Combo", value = true})
self.shadowMenu.Q:MenuElement({id = "Qharass", name = "Use [Q] in Harass", value = true})

-- W --
self.shadowMenu:MenuElement({type = MENU, id = "W", name = "W"})
self.shadowMenu.W:MenuElement({id = "Wcombo", name = "Use [W] in Combo", value = true})
self.shadowMenu.W:MenuElement({id = "Wharass", name = "Use [W] in Harass", value = true})
-- E --
self.shadowMenu:MenuElement({type = MENU, id = "E", name = "E"})
self.shadowMenu.E:MenuElement({id = "Ecombo", name = "Use [E] in Combo", value = true})
self.shadowMenu.E:MenuElement({id = "Eharass", name = "Use [E] in Harass", value = true})

-- R --
self.shadowMenu:MenuElement({type = MENU, id = "R", name = "R"})
self.shadowMenu.R:MenuElement({id = "Rcombo", name = "Use [R] in Combo", value = true})
self.shadowMenu.R:MenuElement({id = "Rexectue", name = "Use [R] to execute", value = true})



-- DRAWING SETTINGS --
self.shadowMenu:MenuElement({type = MENU, id = "drawings", name = "Drawing Settings"})
self.shadowMenu.drawings:MenuElement({id = "drawrKillable", name = "Draw Killable with [R]", value = true})
self.shadowMenu.drawings:MenuElement({id = "drawfullKillable", name = "Draw Killable with full combo", value = true})

-- SUMMONER SETTINGS --
self.shadowMenu:MenuElement({type = MENU, id = "SummonerSettings", name = "Summoner Settings"})
if myHero:GetSpellData(SUMMONER_1).name == "SummonerDot" then
    self.shadowMenu.SummonerSettings:MenuElement({id = "UseIgnite", name = "Use [Ignite] if killable?", value = true})
elseif myHero:GetSpellData(SUMMONER_2).name == "SummonerDot" then
    self.shadowMenu.SummonerSettings:MenuElement({id = "UseIgnite", name = "Use [Ignite] if killable?", value = true}) 
end

if myHero:GetSpellData(SUMMONER_1).name == "SummonerExhaust" then
    self.shadowMenu.SummonerSettings:MenuElement({id = "UseExhaust", name = "Use [Exhaust] on engage?", value = true})
elseif myHero:GetSpellData(SUMMONER_2).name == "SummonerExhaust" then
    self.shadowMenu.SummonerSettings:MenuElement({id = "UseExhaust", name = "Use [Exhaust] on engage?", value = true}) 
end

end


function Chogath:Draw()
if self.shadowMenu.drawings.drawfullKillable:Value() then
for i = 1,Game.HeroCount() do
    local hero = Game.Hero(i)
    if hero and IsValid(hero) and hero.team ~= myHero.team and (getdmg("R", hero, myHero) + (getdmg("Q", hero, myHero) * 2) + (myHero.totalDamage * 2)) > hero.health then
        if Ready(_Q) and Ready(_W) and Ready(_R) then
            Draw.Text("Killable with Full Combo", 18, hero.pos2D.x - 100, hero.pos2D.y - 200, Draw.Color(255, 225, 0, 0))
        end
    end
end
end

if self.shadowMenu.drawings.drawrKillable:Value() then
for i = 1,Game.HeroCount() do
    local hero = Game.Hero(i)
    local rdmg = getdmg("R", hero, myHero)
    if hero and IsValid(hero) and hero.team ~= myHero.team and rdmg > hero.health then
        if Ready(_R) then
            Draw.Text("Killable with [R]", 18, hero.pos2D.x - 100, hero.pos2D.y + 35, Draw.Color(255, 225, 0, 0))
        end
    end
end
end




end

function Chogath:Tick()
if myHero.dead or Game.IsChatOpen() or (ExtLibEvade and ExtLibEvade.Evading == true) then
    return
end
    self:autoR()
    self:AutoSummoners()
if orbwalker.Modes[0] then
    self:Combo()
elseif orbwalker.Modes[1] then
    self:Harass()
elseif orbwalker.Modes[3] then
end
end

function Chogath:Harass()
    local target = TargetSelector:GetTarget(self.Q.Range, 1)
    if target == nil then end
    if Ready(_Q) and target and IsValid(target) then
        if self.shadowMenu.Q.Qharass:Value() then
            Control.CastSpell(HK_Q, target)
        end
    end

    local target = TargetSelector:GetTarget(self.W.Range, 1)
    if target == nil then end
    if Ready(_W) and target and IsValid(target) then
        if self.shadowMenu.W.Wharass:Value() then
            Control.CastSpell(HK_W, target)
        end
    end

    local target = TargetSelector:GetTarget(self.W.Range, 1)
    if target == nil then end
    if Ready(_E) and target and IsValid(target) then
        if self.shadowMenu.E.Eharass:Value() then
            Control.CastSpell(HK_E)
        end
    end


end

function Chogath:autoR()
    if self.shadowMenu.R.Rexectue:Value() then
        local target = TargetSelector:GetTarget(self.R.Range, 1)
        if target == nil then end
        if Ready(_R) and target and IsValid(target) then
            local rdmg = getdmg("R", target, myHero)
            if (rdmg >= target.health) then
            Control.CastSpell(HK_R, target)
            end
        end
    end
end

function Chogath:AutoSummoners()
    -- IGNITE --
    local target = TargetSelector:GetTarget(self.Q.Range, 1)
    if target and IsValid(target) then
        local ignDmg = getdmg("IGNITE", target, myHero)
        if myHero:GetSpellData(SUMMONER_1).name == "SummonerDot" and Ready(SUMMONER_1) and (target.health < ignDmg ) then
            Control.CastSpell(HK_SUMMONER_1, target)
        elseif myHero:GetSpellData(SUMMONER_2).name == "SummonerDot" and Ready(SUMMONER_2) and (target.health < ignDmg ) then
            Control.CastSpell(HK_SUMMONER_2, target)
        end
    end
end



function Chogath:Combo()
    local target = TargetSelector:GetTarget(self.Q.Range, 1)
    if target == nil then end
    if Ready(_Q) and target and IsValid(target) then
        if self.shadowMenu.Q.Qcombo:Value() then
            self:CastQ(target)
        end
    end

    if Ready(_W) and target and IsValid(target) then
        if self.shadowMenu.W.Wcombo:Value() then
            self:CastW(target)
        end
    end

    if Ready(_E) and target and IsValid(target) then
        if self.shadowMenu.E.Ecombo:Value() then
            Control.CastSpell(HK_E)
        end
    end

    local target = TargetSelector:GetTarget(self.R.Range, 1)
    if target == nil then end
    if Ready(_R) and target and IsValid(target) then
        if self.shadowMenu.R.Rcombo:Value()then
            self:CastR(target)
        end
    end
end


--[[
Cast Spells Below
]]

function Chogath:CastR(target)
    if Ready(_R) and lastR + 350 < GetTickCount() and orbwalker:CanMove() then
        local Pred = GamsteronPrediction:GetPrediction(target, self.R, myHero)
        if Pred.Hitchance >= _G.HITCHANCE_HIGH then
            Control.CastSpell(HK_R, Pred.CastPosition)
            lastR = GetTickCount()
        end
    end
end

function Chogath:CastQ(target)
    if Ready(_Q) and lastQ + 350 < GetTickCount() and orbwalker:CanMove() then
        local Pred = GamsteronPrediction:GetPrediction(target, self.Q, myHero)
        if Pred.Hitchance >= _G.HITCHANCE_HIGH then
            Control.CastSpell(HK_Q, Pred.CastPosition)
            lastQ = GetTickCount()
        end
    end
end

function Chogath:CastW(target)
    if Ready(_W) and lastW + 350 < GetTickCount() and orbwalker:CanMove() then
        local Pred = GamsteronPrediction:GetPrediction(target, self.W, myHero)
        if Pred.Hitchance >= _G.HITCHANCE_HIGH then
            Control.CastSpell(HK_W, Pred.CastPosition)
            lastW = GetTickCount()
        end
    end
end

--[[
   _   _   _   _   _  
  / \ / \ / \ / \ / \ 
 ( A | N | N | I | E )
  \_/ \_/ \_/ \_/ \_/ 
]]

class "Jax"
function Jax:__init()

    self.Q = {_G.SPELLTYPE_CIRCLE, Delay = 0.225, Radius = 700, Range = 700, Speed = 1750, Collision = false}
    self.W = {_G.SPELLTYPE_CIRCLE, Delay = 0.1, Radius = myHero.range, Range = myHero.range, Speed = 1800, Collision = false}
    self.E = {_G.SPELLTYPE_CIRCLE, Delay = 0.1, Radius = 300, Range = 300, Speed = 1800, Collision = false}

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
["JaxIcon"] = "https://vignette.wikia.nocookie.net/leagueoflegends/images/f/f5/Jax_OriginalSquare.png",
["Q"] = "https://vignette.wikia.nocookie.net/leagueoflegends/images/f/f6/Leap_Strike.png",
["W"] = "https://vignette.wikia.nocookie.net/leagueoflegends/images/5/57/Empower.png",
["E"] = "https://vignette.wikia.nocookie.net/leagueoflegends/images/6/66/Counter_Strike.png",
["R"] = "https://vignette.wikia.nocookie.net/leagueoflegends/images/2/24/Grandmaster%27s_Might.png",
["EXH"] = "https://vignette.wikia.nocookie.net/leagueoflegends/images/4/4a/Exhaust.png",
["IGN"] = "https://vignette.wikia.nocookie.net/leagueoflegends/images/f/f4/Ignite.png"
}


function Jax:LoadMenu()
self.shadowMenu = {}
self.shadowMenu.root = MenuElement({type = MENU, id = "shadowJax", name = "Shadow Jax"})

-- Q --
self.shadowMenu.Q = self.shadowMenu.root:MenuElement({type = MENU, id = "Q1", name = "Q2"})
self.shadowMenu.QCombo = self.shadowMenu.Q:MenuElement({id = "Qcombo", name = "Use [Q] in Combo", value = true})
self.shadowMenu.QJungle = self.shadowMenu.Q:MenuElement({id = "Qjungle", name = "Use [Q] in Jungle Clear", value = true})

-- W --
self.shadowMenu.W = self.shadowMenu.root:MenuElement({type = MENU, id = "W", name = "W"})
self.shadowMenu.W:MenuElement({id = "Wcombo", name = "Use [W] in Combo", value = true})
self.shadowMenu.W:MenuElement({id = "Wjungle", name = "Use [W] in Jungle Clear", value = true})
-- E --
self.shadowMenu.E = self.shadowMenu.root:MenuElement({type = MENU, id = "E", name = "E"})
self.shadowMenu.E:MenuElement({id = "Ecombo", name = "Use [E] in Combo", value = true})
self.shadowMenu.E:MenuElement({id = "Ejungle", name = "Use [E] in Jungle Clear", value = true})

-- R --
self.shadowMenu.R = self.shadowMenu.root:MenuElement({type = MENU, id = "R", name = "R"})
self.shadowMenu.R:MenuElement({id = "Rcombo", name = "Use [R] in Combo", value = true})


-- DRAWING SETTINGS --
self.shadowMenu.drawings = self.shadowMenu.root:MenuElement({type = MENU, id = "drawings", name = "Drawing Settings"})
self.shadowMenu.drawings:MenuElement({id = "drawrKillable", name = "Draw Killable with [R]", value = true})
self.shadowMenu.drawings:MenuElement({id = "drawfullKillable", name = "Draw Killable with full combo", value = true})

-- SUMMONER SETTINGS --
self.shadowMenu.root:MenuElement({type = MENU, id = "SummonerSettings", name = "Summoner Settings"})
if myHero:GetSpellData(SUMMONER_1).name == "SummonerDot" then
    self.shadowMenu.SummonerSettings:MenuElement({id = "UseIgnite", name = "Use [Ignite] if killable?", value = true})
elseif myHero:GetSpellData(SUMMONER_2).name == "SummonerDot" then
    self.shadowMenu.SummonerSettings:MenuElement({id = "UseIgnite", name = "Use [Ignite] if killable?", value = true}) 
end

if myHero:GetSpellData(SUMMONER_1).name == "SummonerExhaust" then
    self.shadowMenu.SummonerSettings:MenuElement({id = "UseExhaust", name = "Use [Exhaust] on engage?", value = true})
elseif myHero:GetSpellData(SUMMONER_2).name == "SummonerExhaust" then
    self.shadowMenu.SummonerSettings:MenuElement({id = "UseExhaust", name = "Use [Exhaust] on engage?", value = true}) 
end

end


function Jax:Draw()
if self.shadowMenu.drawings.drawfullKillable:Value() then
for i = 1,Game.HeroCount() do
    local hero = Game.Hero(i)
    if hero and IsValid(hero) and hero.team ~= myHero.team and (getdmg("W", hero, myHero) + getdmg("E", hero, myHero) + (getdmg("Q", hero, myHero) * 2) + (myHero.totalDamage * 2)) > hero.health then
        if Ready(_Q) and Ready(_W) and Ready(_E) then
            Draw.Text("Killable with Full Combo", 18, hero.pos2D.x - 100, hero.pos2D.y - 200, Draw.Color(255, 225, 0, 0))
        end
    end
end
end

end




function Jax:Tick()
if myHero.dead or Game.IsChatOpen() or (ExtLibEvade and ExtLibEvade.Evading == true) then
    return
end
    self:AutoSummoners()
if orbwalker.Modes[0] then
    self:Combo()
elseif orbwalker.Modes[1] then
elseif orbwalker.Modes[3] then
    self:jungleclear()
end
end


function Jax:AutoSummoners()
    -- IGNITE --
    local target = TargetSelector:GetTarget(self.Q.Range, 1)
    if target and IsValid(target) then
        local ignDmg = getdmg("IGNITE", target, myHero)
        if myHero:GetSpellData(SUMMONER_1).name == "SummonerDot" and Ready(SUMMONER_1) and (target.health < ignDmg ) then
            Control.CastSpell(HK_SUMMONER_1, target)
        elseif myHero:GetSpellData(SUMMONER_2).name == "SummonerDot" and Ready(SUMMONER_2) and (target.health < ignDmg ) then
            Control.CastSpell(HK_SUMMONER_2, target)
        end
    end
end

function Jax:jungleclear()

    for i = 1, Game.MinionCount() do
        local obj = Game.Minion(i)
        if obj.team ~= myHero.team then
            if obj ~= nil and obj.valid and obj.visible and not obj.dead then
                if Ready(_Q) and self.shadowMenu.Q.Qjungle:Value() and obj and obj.team == 300 and obj.valid and obj.visible and not obj.dead and (obj.pos:DistanceTo(myHero.pos) < self.Q.Range) then
                    Control.CastSpell(HK_Q, obj)
                end
                if Ready(_E) and self.shadowMenu.E.Ejungle:Value() and obj and obj.team == 300 and obj.valid and obj.visible and not obj.dead and (obj.pos:DistanceTo(myHero.pos) < self.E.Range) then
                    Control.CastSpell(HK_E);
                end
                if Ready(_W) and self.shadowMenu.W.Wjungle:Value() and obj and obj.team == 300 and obj.valid and obj.visible and not obj.dead and (obj.pos:DistanceTo(myHero.pos) < self.Q.Range) then
                    Control.CastSpell(HK_W);
                end
            end
        end
        
    end

end



function Jax:Combo()
    local target = TargetSelector:GetTarget(self.Q.Range, 1)
    if target == nil then end
    if Ready(_Q) and target and IsValid(target) then
        if self.shadowMenu.Q.Qcombo:Value() then
            Control.CastSpell(HK_Q, target)
        end
    end

    if Ready(_W) and target and IsValid(target) then
        if self.shadowMenu.W.Wcombo:Value() then
            Control.CastSpell(HK_W)
        end
    end

    local target = TargetSelector:GetTarget(self.E.Range, 1)
    if target == nil then end
    if Ready(_E) and target and IsValid(target) then
        if self.shadowMenu.E.Ecombo:Value() then
            Control.CastSpell(HK_E)
        end
    end

    if target == nil then end
    if Ready(_R) and target and IsValid(target) then
        if self.shadowMenu.R.Rcombo:Value() then
            Control.CastSpell(HK_R)
        end
    end
end


--[[
Cast Spells Below
]]

function Jax:CastR(target)
    if Ready(_R) and lastR + 350 < GetTickCount() and orbwalker:CanMove() then
        local Pred = GamsteronPrediction:GetPrediction(target, self.R, myHero)
        if Pred.Hitchance >= _G.HITCHANCE_HIGH then
            Control.CastSpell(HK_R, Pred.CastPosition)
            lastR = GetTickCount()
        end
    end
end

--[[
   _   _   _   _   _  
  / \ / \ / \ / \ / \ 
 ( A | N | N | I | E )
  \_/ \_/ \_/ \_/ \_/ 
]]

class "Amumu"
function Amumu:__init()

    self.Q = {_G.SPELLTYPE_LINE, Delay = 0.225, Range = 1100, Radius = 80, Speed = 2000, Collision = true, MaxCollision = 1, CollisionTypes = {_G.COLLISION_MINION}}
    self.W = {_G.SPELLTYPE_CIRCLE, Delay = 0.225, Range = 300, Speed = math.huge, Collision = false}
    self.E = {_G.SPELLTYPE_CIRCLE, Delay = 0.225, Range = 350, Speed = math.huge, Collision = false}
    self.R = {_G.SPELLTYPE_CIRCLE, Delay = 0.225, Range = 550, Speed = 20, Collision = false}

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
["AmumuIcon"] = "https://vignette.wikia.nocookie.net/leagueoflegends/images/4/40/Amumu_OriginalSquare.png",
["Q"] = "https://vignette.wikia.nocookie.net/leagueoflegends/images/b/b5/Bandage_Toss.png",
["W"] = "https://vignette.wikia.nocookie.net/leagueoflegends/images/2/25/Despair.png",
["E"] = "https://vignette.wikia.nocookie.net/leagueoflegends/images/b/b3/Tantrum.png",
["R"] = "https://vignette.wikia.nocookie.net/leagueoflegends/images/7/72/Curse_of_the_Sad_Mummy.png",
["EXH"] = "https://vignette.wikia.nocookie.net/leagueoflegends/images/4/4a/Exhaust.png",
["IGN"] = "https://vignette.wikia.nocookie.net/leagueoflegends/images/f/f4/Ignite.png"
}


function Amumu:LoadMenu()
self.shadowMenu = MenuElement({type = MENU, id = "shadowAmumu", name = "Shadow Amumu"})

-- Q --
self.shadowMenu:MenuElement({type = MENU, id = "Q", name = "Q"})
self.shadowMenu.Q:MenuElement({id = "Qcombo", name = "Use [Q] in Combo", value = true})
self.shadowMenu.Q:MenuElement({id = "Qharass", name = "Use [Q] in Harass", value = true})
self.shadowMenu.Q:MenuElement({id = "Qjungle", name = "Use [Q] in Jungle Clear", value = true})
-- W --
self.shadowMenu:MenuElement({type = MENU, id = "W", name = "W"})
self.shadowMenu.W:MenuElement({id = "Wcombo", name = "Use [W] in Combo", value = true})
self.shadowMenu.W:MenuElement({id = "Wharass", name = "Use [W] in Harass", value = true})
self.shadowMenu.W:MenuElement({id = "Wjungle", name = "Use [W] in Jungle Clear", value = true})

-- E --
self.shadowMenu:MenuElement({type = MENU, id = "E", name = "E"})
self.shadowMenu.E:MenuElement({id = "Ecombo", name = "Use [E] in Combo", value = true})
self.shadowMenu.E:MenuElement({id = "Eharass", name = "Use [E] in Harass", value = true})
self.shadowMenu.E:MenuElement({id = "Ejungle", name = "Use [E] in Jungle Clear", value = true})

-- R --
self.shadowMenu:MenuElement({type = MENU, id = "R", name = "R"})
self.shadowMenu.R:MenuElement({id = "Rcombo", name = "Use [R] in Combo", value = true})
self.shadowMenu.R:MenuElement({id = "Rhitable", name = "Activate [R] when can hit x targets", value = 1, min = 1, max = 5, identifier = "#"})



-- DRAWING SETTINGS --
self.shadowMenu:MenuElement({type = MENU, id = "drawings", name = "Drawing Settings"})
self.shadowMenu.drawings:MenuElement({id = "drawrKillable", name = "Draw Killable with [R]", value = true})
self.shadowMenu.drawings:MenuElement({id = "drawfullKillable", name = "Draw Killable with full combo", value = true})

-- SUMMONER SETTINGS --
self.shadowMenu:MenuElement({type = MENU, id = "SummonerSettings", name = "Summoner Settings"})
if myHero:GetSpellData(SUMMONER_1).name == "SummonerDot" then
    self.shadowMenu.SummonerSettings:MenuElement({id = "UseIgnite", name = "Use [Ignite] if killable?", value = true})
elseif myHero:GetSpellData(SUMMONER_2).name == "SummonerDot" then
    self.shadowMenu.SummonerSettings:MenuElement({id = "UseIgnite", name = "Use [Ignite] if killable?", value = true}) 
end

if myHero:GetSpellData(SUMMONER_1).name == "SummonerExhaust" then
    self.shadowMenu.SummonerSettings:MenuElement({id = "UseExhaust", name = "Use [Exhaust] on engage?", value = true})
elseif myHero:GetSpellData(SUMMONER_2).name == "SummonerExhaust" then
    self.shadowMenu.SummonerSettings:MenuElement({id = "UseExhaust", name = "Use [Exhaust] on engage?", value = true}) 
end

end


function Amumu:Draw()
if self.shadowMenu.drawings.drawfullKillable:Value() then
for i = 1,Game.HeroCount() do
    local hero = Game.Hero(i)
    if hero and IsValid(hero) and hero.team ~= myHero.team and (getdmg("R", hero, myHero) + (getdmg("Q", hero, myHero) * 2) + (myHero.totalDamage * 2)) > hero.health then
        if Ready(_Q) and Ready(_W) and Ready(_R) then
            Draw.Text("Killable with Full Combo", 18, hero.pos2D.x - 100, hero.pos2D.y - 200, Draw.Color(255, 225, 0, 0))
        end
    end
end
end

if self.shadowMenu.drawings.drawrKillable:Value() then
for i = 1,Game.HeroCount() do
    local hero = Game.Hero(i)
    local rdmg = getdmg("R", hero, myHero)
    if hero and IsValid(hero) and hero.team ~= myHero.team and rdmg > hero.health then
        if Ready(_R) then
            Draw.Text("Killable with [R]", 18, hero.pos2D.x - 100, hero.pos2D.y + 35, Draw.Color(255, 225, 0, 0))
        end
    end
end
end




end

function Amumu:Tick()
if myHero.dead or Game.IsChatOpen() or (ExtLibEvade and ExtLibEvade.Evading == true) then
    return
end
    self:AutoSummoners()
if orbwalker.Modes[0] then
    self:Combo()
elseif orbwalker.Modes[1] then
    self:Harass()
elseif orbwalker.Modes[3] then
    self:JungleClear()
end
end

function Amumu:JungleClear()

    for i = 1, Game.MinionCount() do
        local obj = Game.Minion(i)
        if obj.team ~= myHero.team then
            if obj ~= nil and obj.valid and obj.visible and not obj.dead then
                if Ready(_Q) and self.shadowMenu.Q.Qjungle:Value() and obj and obj.team == 300 and obj.valid and obj.visible and not obj.dead and (obj.pos:DistanceTo(myHero.pos) < self.Q.Range) then
                    Control.CastSpell(HK_Q, obj)
                end
                if Ready(_E) and self.shadowMenu.E.Ejungle:Value() and obj and obj.team == 300 and obj.valid and obj.visible and not obj.dead and (obj.pos:DistanceTo(myHero.pos) < self.E.Range) then
                    Control.CastSpell(HK_E);
                end
                if Ready(_W) and self.shadowMenu.W.Wjungle:Value() and obj and obj.team == 300 and obj.valid and obj.visible and not obj.dead and (obj.pos:DistanceTo(myHero.pos) < self.W.Range) then
                    Control.KeyDown(HK_W);
                end
            end
        end
        
    end

end

function Amumu:Harass()
    local target = TargetSelector:GetTarget(self.Q.Range, 1)
    if target == nil then end
    if Ready(_Q) and target and IsValid(target) then
        if self.shadowMenu.Q.Qharass:Value() then
            Control.CastSpell(HK_Q, target)
        end
    end

    local target = TargetSelector:GetTarget(self.W.Range, 1)
    if target == nil then end
    if Ready(_W) and target and IsValid(target) then
        if self.shadowMenu.W.Wharass:Value() then
            Control.CastSpell(HK_W, target)
        end
    end

    local target = TargetSelector:GetTarget(self.W.Range, 1)
    if target == nil then end
    if Ready(_E) and target and IsValid(target) then
        if self.shadowMenu.E.Eharass:Value() then
            Control.CastSpell(HK_E)
        end
    end


end

function Amumu:AutoSummoners()
    -- IGNITE --
    local target = TargetSelector:GetTarget(self.Q.Range, 1)
    if target and IsValid(target) then
        local ignDmg = getdmg("IGNITE", target, myHero)
        if myHero:GetSpellData(SUMMONER_1).name == "SummonerDot" and Ready(SUMMONER_1) and (target.health < ignDmg ) then
            Control.CastSpell(HK_SUMMONER_1, target)
        elseif myHero:GetSpellData(SUMMONER_2).name == "SummonerDot" and Ready(SUMMONER_2) and (target.health < ignDmg ) then
            Control.CastSpell(HK_SUMMONER_2, target)
        end
    end
end



function Amumu:Combo()
    local target = TargetSelector:GetTarget(self.Q.Range, 1)
    if target == nil then end
    if Ready(_Q) and target and IsValid(target) then
        if self.shadowMenu.Q.Qcombo:Value() then
            self:CastQ(target)
        end
    end

    if Ready(_W) and target and IsValid(target) then
        if self.shadowMenu.W.Wcombo:Value() then
            Control.KeyDown(HK_W)
        end
    end

    local target = TargetSelector:GetTarget(self.E.Range, 1)
    if target == nil then end
    if Ready(_E) and target and IsValid(target) then
        if self.shadowMenu.E.Ecombo:Value() then
            Control.CastSpell(HK_E)
        end
    end

    local target = TargetSelector:GetTarget(self.R.Range, 1)
    if target == nil then end
    if Ready(_R) and target and IsValid(target) then
        if self.shadowMenu.R.Rcombo:Value() and CountEnemiesNear(target, 1000) >= self.shadowMenu.R.Rhitable:Value() then
            self:CastR(target)
        end
    end
end


--[[
Cast Spells Below
]]

function Amumu:CastR(target)
    if Ready(_R) and lastR + 350 < GetTickCount() and orbwalker:CanMove() then
        local Pred = GamsteronPrediction:GetPrediction(target, self.R, myHero)
        if Pred.Hitchance >= _G.HITCHANCE_HIGH then
            Control.CastSpell(HK_R, Pred.CastPosition)
            lastR = GetTickCount()
        end
    end
end

function Amumu:CastQ(target)
    if Ready(_Q) and lastQ + 350 < GetTickCount() and orbwalker:CanMove() then
        local Pred = GamsteronPrediction:GetPrediction(target, self.Q, myHero)
        if Pred.Hitchance >= _G.HITCHANCE_HIGH then
            Control.CastSpell(HK_Q, Pred.CastPosition)
            lastQ = GetTickCount()
        end
    end
end

--[[
   _   _   _   _   _  
  / \ / \ / \ / \ / \ 
 ( A | N | N | I | E )
  \_/ \_/ \_/ \_/ \_/ 
]]

class "Warwick"
function Warwick:__init()

    self.Q = {_G.SPELLTYPE_CIRCLE, Delay = 0.225, Radius = 600, Range = 600, Speed = 1750, Collision = false}
    self.R = {_G.SPELLTYPE_CIRCLE, Delay = 0.1, Radius = 55, Range = 2.5 * myHero.ms, Speed = 1800, Collision = false}
    

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
["WarwickIcon"] = "https://vignette.wikia.nocookie.net/leagueoflegends/images/2/23/Warwick_OriginalSquare.png",
["Q"] = "https://vignette.wikia.nocookie.net/leagueoflegends/images/7/76/Jaws_of_the_Beast.png",
["W"] = "https://vignette.wikia.nocookie.net/leagueoflegends/images/c/cd/Blood_Hunt.png",
["E"] = "https://vignette.wikia.nocookie.net/leagueoflegends/images/9/91/Primal_Howl.png",
["R"] = "https://vignette.wikia.nocookie.net/leagueoflegends/images/f/f7/Infinite_Duress.png",
["EXH"] = "https://vignette.wikia.nocookie.net/leagueoflegends/images/4/4a/Exhaust.png",
["IGN"] = "https://vignette.wikia.nocookie.net/leagueoflegends/images/f/f4/Ignite.png"
}


function Warwick:LoadMenu()
self.shadowMenu = MenuElement({type = MENU, id = "shadowWarwick", name = "Shadow Warwick"})

-- Q --
self.shadowMenu:MenuElement({type = MENU, id = "Q", name = "Q"})
self.shadowMenu.Q:MenuElement({id = "Qcombo", name = "Use [Q] in Combo", value = true})
self.shadowMenu.Q:MenuElement({id = "Qharass", name = "Use [Q] in Harass", value = true})
self.shadowMenu.Q:MenuElement({id = "Qjungle", name = "Use [Q] in Jungle Clear", value = true})
-- W --
self.shadowMenu:MenuElement({type = MENU, id = "W", name = "W"})
self.shadowMenu.W:MenuElement({id = "Wcombo", name = "Use [W] in Combo", value = true})


-- E --
self.shadowMenu:MenuElement({type = MENU, id = "E", name = "E"})
self.shadowMenu.E:MenuElement({id = "Ecombo", name = "Use [E] in Combo", value = true})
self.shadowMenu.E:MenuElement({id = "Eharass", name = "Use [E] in Harass", value = true})
self.shadowMenu.E:MenuElement({id = "Ejungle", name = "Use [E] in Jungle Clear", value = true})

-- R --
self.shadowMenu:MenuElement({type = MENU, id = "R", name = "R"})
self.shadowMenu.R:MenuElement({id = "Rcombo", name = "Use [R] in Combo", value = true})
self.shadowMenu.R:MenuElement({id = "Rhitable", name = "Activate [R] when can hit x targets", value = 1, min = 1, max = 5, identifier = "#"})



-- DRAWING SETTINGS --
self.shadowMenu:MenuElement({type = MENU, id = "drawings", name = "Drawing Settings"})
self.shadowMenu.drawings:MenuElement({id = "drawrKillable", name = "Draw Killable with [R]", value = true})
self.shadowMenu.drawings:MenuElement({id = "drawfullKillable", name = "Draw Killable with full combo", value = true})

-- SUMMONER SETTINGS --
self.shadowMenu:MenuElement({type = MENU, id = "SummonerSettings", name = "Summoner Settings"})
if myHero:GetSpellData(SUMMONER_1).name == "SummonerDot" then
    self.shadowMenu.SummonerSettings:MenuElement({id = "UseIgnite", name = "Use [Ignite] if killable?", value = true})
elseif myHero:GetSpellData(SUMMONER_2).name == "SummonerDot" then
    self.shadowMenu.SummonerSettings:MenuElement({id = "UseIgnite", name = "Use [Ignite] if killable?", value = true}) 
end

if myHero:GetSpellData(SUMMONER_1).name == "SummonerExhaust" then
    self.shadowMenu.SummonerSettings:MenuElement({id = "UseExhaust", name = "Use [Exhaust] on engage?", value = true})
elseif myHero:GetSpellData(SUMMONER_2).name == "SummonerExhaust" then
    self.shadowMenu.SummonerSettings:MenuElement({id = "UseExhaust", name = "Use [Exhaust] on engage?", value = true}) 
end

end


function Warwick:Draw()



if self.shadowMenu.drawings.drawfullKillable:Value() then
for i = 1,Game.HeroCount() do
    local hero = Game.Hero(i)
    if hero and IsValid(hero) and hero.team ~= myHero.team and (getdmg("R", hero, myHero) + (getdmg("Q", hero, myHero) * 2) + (myHero.totalDamage * 2)) > hero.health then
        if Ready(_Q) and Ready(_W) and Ready(_R) then
            Draw.Text("Killable with Full Combo", 18, hero.pos2D.x - 100, hero.pos2D.y - 200, Draw.Color(255, 225, 0, 0))
        end
    end
end
end

if self.shadowMenu.drawings.drawrKillable:Value() then
for i = 1,Game.HeroCount() do
    local hero = Game.Hero(i)
    local rdmg = getdmg("R", hero, myHero)
    if hero and IsValid(hero) and hero.team ~= myHero.team and rdmg > hero.health then
        if Ready(_R) then
            Draw.Text("Killable with [R]", 18, hero.pos2D.x - 100, hero.pos2D.y + 35, Draw.Color(255, 225, 0, 0))
        end
    end
end
end




end

function Warwick:Tick()
if myHero.dead or Game.IsChatOpen() or (ExtLibEvade and ExtLibEvade.Evading == true) then
    return
end
    self:AutoSummoners()
if orbwalker.Modes[0] then
    self:Combo()
elseif orbwalker.Modes[1] then
    self:Harass()
elseif orbwalker.Modes[3] then
    self:JungleClear()
end
end

function Warwick:JungleClear()

    for i = 1, Game.MinionCount() do
        local obj = Game.Minion(i)
        if obj.team ~= myHero.team then
            if obj ~= nil and obj.valid and obj.visible and not obj.dead then
                if Ready(_Q) and self.shadowMenu.Q.Qjungle:Value() and obj and obj.team == 300 and obj.valid and obj.visible and not obj.dead and (obj.pos:DistanceTo(myHero.pos) < self.Q.Range) then
                    Control.CastSpell(HK_Q, obj)
                end
                if Ready(_E) and self.shadowMenu.E.Ejungle:Value() and obj and obj.team == 300 and obj.valid and obj.visible and not obj.dead and (obj.pos:DistanceTo(myHero.pos) < self.Q.Range) then
                    Control.CastSpell(HK_E);
                end
            end
        end
        
    end

end

function Warwick:Harass()
    local target = TargetSelector:GetTarget(self.Q.Range, 1)
    if target == nil then end
    if Ready(_Q) and target and IsValid(target) then
        if self.shadowMenu.Q.Qharass:Value() then
            Control.CastSpell(HK_Q, target)
        end
    end

    local target = TargetSelector:GetTarget(self.Q.Range, 1)
    if target == nil then end
    if Ready(_E) and target and IsValid(target) then
        if self.shadowMenu.E.Eharass:Value() then
            Control.CastSpell(HK_E)
        end
    end


end


function Warwick:AutoSummoners()
    -- IGNITE --
    local target = TargetSelector:GetTarget(self.Q.Range, 1)
    if target and IsValid(target) then
        local ignDmg = getdmg("IGNITE", target, myHero)
        if myHero:GetSpellData(SUMMONER_1).name == "SummonerDot" and Ready(SUMMONER_1) and (target.health < ignDmg ) then
            Control.CastSpell(HK_SUMMONER_1, target)
        elseif myHero:GetSpellData(SUMMONER_2).name == "SummonerDot" and Ready(SUMMONER_2) and (target.health < ignDmg ) then
            Control.CastSpell(HK_SUMMONER_2, target)
        end
    end
end



function Warwick:Combo()

    local target = TargetSelector:GetTarget(self.R.Range, 1)
    if target == nil then end
    if Ready(_R) and target and IsValid(target) then
        if self.shadowMenu.R.Rcombo:Value() then
            self:CastR(target)
        end
    end

    local target = TargetSelector:GetTarget(self.Q.Range, 1)
    if target == nil then end
    if Ready(_Q) and target and IsValid(target) then
        if self.shadowMenu.Q.Qcombo:Value() then
            Control.CastSpell(HK_Q, target)
        end
    end

    if Ready(_W) and target and IsValid(target) then
        if self.shadowMenu.W.Wcombo:Value() then
            Control.CastSpell(HK_W)
        end
    end

    local target = TargetSelector:GetTarget(self.Q.Range, 1)
    if target == nil then end
    if Ready(_E) and target and IsValid(target) then
        if self.shadowMenu.E.Ecombo:Value() then
            Control.CastSpell(HK_E)
        end
    end
end


--[[
Cast Spells Below
]]

function Warwick:CastR(target)
    if Ready(_R) and lastR + 350 < GetTickCount() and orbwalker:CanMove() then
        local Pred = GamsteronPrediction:GetPrediction(target, self.R, myHero)
        if Pred.Hitchance >= _G.HITCHANCE_HIGH then
            Control.CastSpell(HK_R, Pred.CastPosition)
            lastR = GetTickCount()
        end
    end
end

--[[
   _   _   _   _   _  
  / \ / \ / \ / \ / \ 
 ( A | N | N | I | E )
  \_/ \_/ \_/ \_/ \_/ 
]]

class "Gragas"
function Gragas:__init()

    self.Q = {Type = _G.SPELLTYPE_LINE, Delay = 0, Radius = 100, Range = myHero:GetSpellData(_Q).range, Speed = 1000, Collision = false}
    self.W = {Type = _G.SPELLTYPE_CIRCLE, Delay = 0.75, Radius = 175, Range = myHero:GetSpellData(_W).range, Speed = 0, Collision = false}
    self.E = {Type = _G.SPELLTYPE_CIRCLE, Delay = 0, Radius = 180, Range = myHero:GetSpellData(_E).range, Speed = 1400, Collision = false}
    self.R = {Type = _G.SPELLTYPE_CIRCLE, Delay = 0.55, Radius = 400, Range = myHero:GetSpellData(_R).range, Speed = 1000, Collision = false}
    
    

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
["GragasIcon"] = "https://vignette.wikia.nocookie.net/leagueoflegends/images/0/02/Gragas_OriginalSquare.png",
["Q"] = "https://vignette.wikia.nocookie.net/leagueoflegends/images/4/4b/Barrel_Roll.png",
["W"] = "https://vignette.wikia.nocookie.net/leagueoflegends/images/5/59/Drunken_Rage.png",
["E"] = "https://vignette.wikia.nocookie.net/leagueoflegends/images/2/2c/Body_Slam.png",
["R"] = "https://vignette.wikia.nocookie.net/leagueoflegends/images/7/7c/Explosive_Cask.png",
["EXH"] = "https://vignette.wikia.nocookie.net/leagueoflegends/images/4/4a/Exhaust.png",
["IGN"] = "https://vignette.wikia.nocookie.net/leagueoflegends/images/f/f4/Ignite.png"
}


function Gragas:LoadMenu()
self.shadowMenu = MenuElement({type = MENU, id = "shadowGragas", name = "Shadow Gragas"})

-- Q --
self.shadowMenu:MenuElement({type = MENU, id = "Q", name = "Q"})
self.shadowMenu.Q:MenuElement({id = "Qcombo", name = "Use [Q] in Combo", value = true})
self.shadowMenu.Q:MenuElement({id = "Qharass", name = "Use [Q] in Harass", value = true})
self.shadowMenu.Q:MenuElement({id = "Qjungle", name = "Use [Q] in Jungle Clear", value = true})
-- W --
self.shadowMenu:MenuElement({type = MENU, id = "W", name = "W"})
self.shadowMenu.W:MenuElement({id = "Wcombo", name = "Use [W] in Combo", value = true})
self.shadowMenu.W:MenuElement({id = "Wharass", name = "Use [W] in Harass", value = true})
self.shadowMenu.W:MenuElement({id = "Wjungle", name = "Use [W] in Jungle Clear", value = true})

-- E --
self.shadowMenu:MenuElement({type = MENU, id = "E", name = "E"})
self.shadowMenu.E:MenuElement({id = "Ecombo", name = "Use [E] in Combo", value = true})
self.shadowMenu.E:MenuElement({id = "Eharass", name = "Use [E] in Harass", value = true})
self.shadowMenu.E:MenuElement({id = "Ejungle", name = "Use [E] in Jungle Clear", value = true})

-- R --
self.shadowMenu:MenuElement({type = MENU, id = "R", name = "R"})
self.shadowMenu.R:MenuElement({id = "Rcombo", name = "Use [R] in Combo", value = true})
self.shadowMenu.R:MenuElement({id = "Rexectue", name = "Use [R] to execute", value = true})



-- DRAWING SETTINGS --
self.shadowMenu:MenuElement({type = MENU, id = "drawings", name = "Drawing Settings"})
self.shadowMenu.drawings:MenuElement({id = "drawrKillable", name = "Draw Killable with [R]", value = true})
self.shadowMenu.drawings:MenuElement({id = "drawfullKillable", name = "Draw Killable with full combo", value = true})

-- SUMMONER SETTINGS --
self.shadowMenu:MenuElement({type = MENU, id = "SummonerSettings", name = "Summoner Settings"})
if myHero:GetSpellData(SUMMONER_1).name == "SummonerDot" then
    self.shadowMenu.SummonerSettings:MenuElement({id = "UseIgnite", name = "Use [Ignite] if killable?", value = true})
elseif myHero:GetSpellData(SUMMONER_2).name == "SummonerDot" then
    self.shadowMenu.SummonerSettings:MenuElement({id = "UseIgnite", name = "Use [Ignite] if killable?", value = true}) 
end

if myHero:GetSpellData(SUMMONER_1).name == "SummonerExhaust" then
    self.shadowMenu.SummonerSettings:MenuElement({id = "UseExhaust", name = "Use [Exhaust] on engage?", value = true})
elseif myHero:GetSpellData(SUMMONER_2).name == "SummonerExhaust" then
    self.shadowMenu.SummonerSettings:MenuElement({id = "UseExhaust", name = "Use [Exhaust] on engage?", value = true}) 
end

end


function Gragas:Draw()
if self.shadowMenu.drawings.drawfullKillable:Value() then
for i = 1,Game.HeroCount() do
    local hero = Game.Hero(i)
    if hero and IsValid(hero) and hero.team ~= myHero.team and (getdmg("R", hero, myHero) + (getdmg("Q", hero, myHero) * 2) + (myHero.totalDamage * 2)) > hero.health then
        if Ready(_Q) and Ready(_W) and Ready(_R) then
            Draw.Text("Killable with Full Combo", 18, hero.pos2D.x - 100, hero.pos2D.y - 200, Draw.Color(255, 225, 0, 0))
        end
    end
end
end

if self.shadowMenu.drawings.drawrKillable:Value() then
for i = 1,Game.HeroCount() do
    local hero = Game.Hero(i)
    local rdmg = getdmg("R", hero, myHero)
    if hero and IsValid(hero) and hero.team ~= myHero.team and rdmg > hero.health then
        if Ready(_R) then
            Draw.Text("Killable with [R]", 18, hero.pos2D.x - 100, hero.pos2D.y + 35, Draw.Color(255, 225, 0, 0))
        end
    end
end
end




end

function Gragas:Tick()
if myHero.dead or Game.IsChatOpen() or (ExtLibEvade and ExtLibEvade.Evading == true) then
    return
end
    self:autoR()
    self:AutoSummoners()
if orbwalker.Modes[0] then
    self:Combo()
elseif orbwalker.Modes[1] then
    self:Harass()
elseif orbwalker.Modes[3] then
    self:JungleClear()
end
end

function Gragas:JungleClear()

    for i = 1, Game.MinionCount() do
        local obj = Game.Minion(i)
        if obj.team ~= myHero.team then
            if obj ~= nil and obj.valid and obj.visible and not obj.dead then
                if Ready(_E) and self.shadowMenu.E.Ejungle:Value() and obj and obj.team == 300 and obj.valid and obj.visible and not obj.dead and (obj.pos:DistanceTo(myHero.pos) < self.E.Range) then
                    self:CastE(obj)
                end
                if Ready(_W) and self.shadowMenu.W.Wjungle:Value() and obj and obj.team == 300 and obj.valid and obj.visible and not obj.dead and (obj.pos:DistanceTo(myHero.pos) < self.Q.Range) then
                    Control.CastSpell(HK_W)
                end
                if Ready(_Q) and self.shadowMenu.Q.Qjungle:Value() and obj and obj.team == 300 and obj.valid and obj.visible and not obj.dead and (obj.pos:DistanceTo(myHero.pos) < self.Q.Range) then
                    self:CastQ(obj)
                end
            end
        end
        
    end

end

function Gragas:Harass()
    local target = TargetSelector:GetTarget(self.Q.Range, 1)
    if target == nil then end
    if Ready(_Q) and target and IsValid(target) then
        if self.shadowMenu.Q.Qharass:Value() then
            self:CastQ(target)
        end
    end

    local target = TargetSelector:GetTarget(self.W.Range, 1)
    if target == nil then end
    if Ready(_W) and target and IsValid(target) then
        if self.shadowMenu.W.Wharass:Value() then
            Control.CastSpell(HK_W, target)
        end
    end

    local target = TargetSelector:GetTarget(self.W.Range, 1)
    if target == nil then end
    if Ready(_E) and target and IsValid(target) then
        if self.shadowMenu.E.Eharass:Value() then
            self:CastE(target)
        end
    end


end

function Gragas:autoR()
    if self.shadowMenu.R.Rexectue:Value() then
        local target = TargetSelector:GetTarget(self.R.Range, 1)
        if target == nil then end
        if Ready(_R) and target and IsValid(target) then
            local rdmg = getdmg("R", target, myHero)
            if (rdmg >= target.health) then
                self:CastR(target)
            end
        end
    end
end

function Gragas:AutoSummoners()
    -- IGNITE --
    local target = TargetSelector:GetTarget(self.Q.Range, 1)
    if target and IsValid(target) then
        local ignDmg = getdmg("IGNITE", target, myHero)
        if myHero:GetSpellData(SUMMONER_1).name == "SummonerDot" and Ready(SUMMONER_1) and (target.health < ignDmg ) then
            Control.CastSpell(HK_SUMMONER_1, target)
        elseif myHero:GetSpellData(SUMMONER_2).name == "SummonerDot" and Ready(SUMMONER_2) and (target.health < ignDmg ) then
            Control.CastSpell(HK_SUMMONER_2, target)
        end
    end
end



function Gragas:Combo()
    local target = TargetSelector:GetTarget(self.Q.Range, 1)
    if target == nil then end
    if Ready(_Q) and target and IsValid(target) then
        if self.shadowMenu.Q.Qcombo:Value() then
            self:CastQ(target)
        end
    end

    if Ready(_W) and target and IsValid(target) then
        if self.shadowMenu.W.Wcombo:Value() then
            Control.CastSpell(HK_W)
        end
    end

    local target = TargetSelector:GetTarget(self.E.Range, 1)
    if target == nil then end
    if Ready(_E) and target and IsValid(target) then
        if self.shadowMenu.E.Ecombo:Value() then
            self:CastE(target)
        end
    end
end


--[[
Cast Spells Below
]]

function Gragas:CastR(target)
    if Ready(_R) and lastR + 350 < GetTickCount() and orbwalker:CanMove() then
        local Pred = GamsteronPrediction:GetPrediction(target, self.R, myHero)
        if Pred.Hitchance >= _G.HITCHANCE_HIGH then
            Control.CastSpell(HK_R, Pred.CastPosition)
            lastR = GetTickCount()
        end
    end
end

function Gragas:CastE(target)
    if Ready(_E) and lastE + 350 < GetTickCount() and orbwalker:CanMove() then
        local Pred = GamsteronPrediction:GetPrediction(target, self.E, myHero)
        if Pred.Hitchance >= _G.HITCHANCE_NORMAL then
            Control.CastSpell(HK_E, Pred.CastPosition)
            lastE = GetTickCount()
        end
    end
end


function Gragas:CastQ(target)
    if Ready(_Q) and lastQ + 350 < GetTickCount() and orbwalker:CanMove() then
        local Pred = GamsteronPrediction:GetPrediction(target, self.Q, myHero)
        if Pred.Hitchance >= _G.HITCHANCE_HIGH then
            Control.CastSpell(HK_Q, Pred.CastPosition)
            lastQ = GetTickCount()
        end
    end
end
