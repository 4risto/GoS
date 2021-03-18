require "PremiumPrediction"
require "DamageLib"
require "2DGeometry"
require "MapPositionGOS"

local EnemyHeroes = {}
local AllyHeroes = {}
-- [ AutoUpdate ] --
do
    
    local Version = 111.00
    
    local Files = {
        Lua = {
            Path = SCRIPT_PATH,
            Name = "Series.lua",
            Url = "https://raw.githubusercontent.com/LegoNioh/Series/master/Series.lua"
        },
        Version = {
            Path = SCRIPT_PATH,
            Name = "Series.version",
            Url = "https://raw.githubusercontent.com/LegoNioh/Series/master/Series.version"    -- check if Raw Adress correct pls.. after you have create the version file on Github
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
            print("Version Changes: Added Lucian Auto Q On Minions") 
            print("Version Changes: Added Fizz")
			print("Version Changes: Added Fizz Last Hit") 
			print("Version Changes: Fixed FPS drops on Lucian Auto Q")
			print("Version Changes: Added Quinn")
			print("Version Changes: Lots of Quinn changes...")  
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

function IsFacing(unit)
    local V = Vector((unit.pos - myHero.pos))
    local D = Vector(unit.dir)
    local Angle = 180 - math.deg(math.acos(V*D/(V:Len()*D:Len())))
    if math.abs(Angle) < 80 then 
        return true  
    end
    return false
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
		return _G.SDK.TargetSelector:GetTarget(range, _G.SDK.DAMAGE_TYPE_PHYSICAL);
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
	if myHero.charName == "Aphelios" then
		DelayAction(function() self:LoadAphelios() end, 1.05)
	elseif myHero.charName == "Lucian" then
		DelayAction(function() self:LoadLucian() end, 1.05)
	elseif myHero.charName == "Pyke" then
		DelayAction(function() self:LoadPyke() end, 1.05)
	elseif myHero.charName == "Quinn" then
		DelayAction(function() self:LoadQuinn() end, 1.05)
	elseif myHero.charName == "Fizz" then
		DelayAction(function() self:LoadFizz() end, 1.05)
	elseif myHero.charName == "Riven" then
		DelayAction(function() self:LoadRiven() end, 1.05)
	elseif myHero.charName == "Zoe" then
		DelayAction(function() self:LoadZoe() end, 1.05)
	elseif myHero.charName == "Teemo" then
		DelayAction(function() self:LoadTeemo() end, 1.05)
	elseif myHero.charName == "MasterYi" then
		DelayAction(function() self:LoadMasterYi() end, 1.05)
	elseif myHero.charName == "MissFortune" then
		DelayAction(function() self:LoadMissFortune() end, 1.05)
	elseif myHero.charName == "TwistedFate" then
		DelayAction(function() self:LoadTwistedFate() end, 1.05)
	elseif myHero.charName == "Draven" then
		DelayAction(function() self:LoadDraven() end, 1.05)
	end
end

function Manager:LoadTwistedFate()
	TwistedFate:Spells()
	TwistedFate:Menu()
	--
	--GetEnemyHeroes()
	Callback.Add("Tick", function() TwistedFate:Tick() end)
	Callback.Add("Draw", function() TwistedFate:Draw() end)
	if _G.SDK then
		_G.SDK.Orbwalker:OnPreAttack(function(...) TwistedFate:OnPreAttack(...) end)
		_G.SDK.Orbwalker:OnPostAttackTick(function(...) TwistedFate:OnPostAttackTick(...) end)
	end
end


function Manager:LoadMissFortune()
	MissFortune:Spells()
	MissFortune:Menu()
	--
	--GetEnemyHeroes()
	Callback.Add("Tick", function() MissFortune:Tick() end)
	Callback.Add("Draw", function() MissFortune:Draw() end)
	if _G.SDK then
		_G.SDK.Orbwalker:OnPreAttack(function(...) MissFortune:OnPreAttack(...) end)
		_G.SDK.Orbwalker:OnPostAttackTick(function(...) MissFortune:OnPostAttackTick(...) end)
	end
end


function Manager:LoadTeemo()
	Teemo:Spells()
	Teemo:Menu()
	--
	--GetEnemyHeroes()
	Callback.Add("Tick", function() Teemo:Tick() end)
	Callback.Add("Draw", function() Teemo:Draw() end)
	if _G.SDK then
		_G.SDK.Orbwalker:OnPreAttack(function(...) Teemo:OnPreAttack(...) end)
		_G.SDK.Orbwalker:OnPostAttackTick(function(...) Teemo:OnPostAttackTick(...) end)
	end
end

function Manager:LoadZoe()
	Zoe:Spells()
	Zoe:Menu()
	--
	--GetEnemyHeroes()
	Callback.Add("Tick", function() Zoe:Tick() end)
	Callback.Add("Draw", function() Zoe:Draw() end)
	if _G.SDK then
		_G.SDK.Orbwalker:OnPreAttack(function(...) Zoe:OnPreAttack(...) end)
		_G.SDK.Orbwalker:OnPostAttackTick(function(...) Zoe:OnPostAttackTick(...) end)
	end
end


function Manager:LoadLucian()
	Lucian:Spells()
	Lucian:Menu()
	--
	--GetEnemyHeroes()
	Callback.Add("Tick", function() Lucian:Tick() end)
	Callback.Add("Draw", function() Lucian:Draw() end)
	if _G.SDK then
		_G.SDK.Orbwalker:OnPreAttack(function(...) Lucian:OnPreAttack(...) end)
		_G.SDK.Orbwalker:OnPostAttackTick(function(...) Lucian:OnPostAttackTick(...) end)
	end
end


function Manager:LoadDraven()
	Draven:Spells()
	Draven:Menu()
	--
	--GetEnemyHeroes()
	Callback.Add("Tick", function() Draven:Tick() end)
	Callback.Add("Draw", function() Draven:Draw() end)
	if _G.SDK then
		_G.SDK.Orbwalker:OnPreAttack(function(...) Draven:OnPreAttack(...) end)
		_G.SDK.Orbwalker:OnPostAttackTick(function(...) Draven:OnPostAttackTick(...) end)
		--_G.SDK.Orbwalker:OnPostAttack(function(...) Aphelios:OnPostAttack(...) end)
	end
end


function Manager:LoadPyke()
	Pyke:Spells()
	Pyke:Menu()
	--
	--GetEnemyHeroes()
	Callback.Add("Tick", function() Pyke:Tick() end)
	Callback.Add("Draw", function() Pyke:Draw() end)
end

function Manager:LoadAphelios()
	Aphelios:Spells()
	Aphelios:Menu()
	--
	--GetEnemyHeroes()
	Callback.Add("Tick", function() Aphelios:Tick() end)
	Callback.Add("Draw", function() Aphelios:Draw() end)
	if _G.SDK then
		_G.SDK.Orbwalker:OnPreAttack(function(...) Aphelios:OnPreAttack(...) end)
		_G.SDK.Orbwalker:OnPostAttackTick(function(...) Aphelios:OnPostAttackTick(...) end)
	end
end

function Manager:LoadFizz()
	Fizz:Spells()
	Fizz:Menu()
	--
	--GetEnemyHeroes()
	Callback.Add("Tick", function() Fizz:Tick() end)
	Callback.Add("Draw", function() Fizz:Draw() end)
	if _G.SDK then
		_G.SDK.Orbwalker:OnPreAttack(function(...) Fizz:OnPreAttack(...) end)
		_G.SDK.Orbwalker:OnPostAttackTick(function(...) Fizz:OnPostAttackTick(...) end)
	end
end

function Manager:LoadRiven()
	Riven:Spells()
	Riven:Menu()
	--
	--GetEnemyHeroes()
	Callback.Add("Tick", function() Riven:Tick() end)
	Callback.Add("Draw", function() Riven:Draw() end)
	if _G.SDK then
		_G.SDK.Orbwalker:OnPreAttack(function(...) Riven:OnPreAttack(...) end)
		_G.SDK.Orbwalker:OnPostAttackTick(function(...) Riven:OnPostAttackTick(...) end)
	end
end

function Manager:LoadQuinn()
	Quinn:Spells()
	Quinn:Menu()
	--
	--GetEnemyHeroes()
	Callback.Add("Tick", function() Quinn:Tick() end)
	Callback.Add("Draw", function() Quinn:Draw() end)
	if _G.SDK then
		_G.SDK.Orbwalker:OnPreAttack(function(...) Quinn:OnPreAttack(...) end)
		_G.SDK.Orbwalker:OnPostAttackTick(function(...) Quinn:OnPostAttackTick(...) end)
	end
end

function Manager:LoadMasterYi()
	MasterYi:Spells()
	MasterYi:Menu()
	--
	--GetEnemyHeroes()
	Callback.Add("Tick", function() MasterYi:Tick() end)
	Callback.Add("Draw", function() MasterYi:Draw() end)
	if _G.SDK then
		_G.SDK.Orbwalker:OnPreAttack(function(...) MasterYi:OnPreAttack(...) end)
		_G.SDK.Orbwalker:OnPostAttackTick(function(...) MasterYi:OnPostAttackTick(...) end)
	end
end

class "Riven"

local EnemyLoaded = false
local casted = 0
local LastCalledTime = 0
local LastESpot = myHero.pos
local LastE2Spot = myHero.pos
local PickingCard = false
local attackedfirst = 0
local Q = 1
local R = 1
local WasInRange = false
local OneTick
local attacked = 0

function Riven:Menu()
    self.Menu = MenuElement({type = MENU, id = "Riven", name = "Riven"})
    self.Menu:MenuElement({id = "ToggleFightKey", name = "Toggle Fighting", key = string.byte("A"), value = false, toggle = true})
    self.Menu:MenuElement({id = "FleeKey", name = "Disengage Key", key = string.byte("T"), value = false})
    self.Menu:MenuElement({id = "ComboMode", name = "Combo", type = MENU})
    self.Menu.ComboMode:MenuElement({id = "UseQ", name = "Use Q in Combo", value = true})
    self.Menu.ComboMode:MenuElement({id = "UseQFast", name = "Use Fast Q Mode", value = true})
    self.Menu.ComboMode:MenuElement({id = "UseQHop", name = "Hop over targets with Q", value = true})
    self.Menu.ComboMode:MenuElement({id = "UseW", name = "Use W in Combo", value = true})
    self.Menu.ComboMode:MenuElement({id = "UseE", name = "Use E in Combo", value = true})
    self.Menu.ComboMode:MenuElement({id = "UseR", name = "Use R in Combo", value = true})
    self.Menu.ComboMode:MenuElement({id = "GapUseQ", name = "Use Q To Gap Close with damage calcs", value = true})
    self.Menu.ComboMode:MenuElement({id = "GapUseE", name = "Use E To Gap Close with damage calcs", value = true})

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

function Riven:Spells()
    QSpellData = {speed = 1000, range = 500, delay = 0.25, radius = 150, collision = {}, type = "circular"}
    RSpellData = {speed = 1600, range = 900, delay = 0.25, angle = 75, radius = 0, collision = {}, type = "conic"}
end


function Riven:Tick()
    if _G.JustEvade and _G.JustEvade:Evading() or (_G.ExtLibEvade and _G.ExtLibEvade.Evading) or Game.IsChatOpen() or myHero.dead then return end
    --PrintChat(myHero:GetSpellData(_Q).ammo)
    --PrintChat(myHero:GetSpellData(_R).name)
    target = GetTarget(1400)
    --self:KS()
    if myHero:GetSpellData(_R).name == "RivenFengShuiEngine" then
    	R = 1
    else
    	R = 2
    end
    Q = myHero:GetSpellData(_Q).ammo+1
    if Q == 1 or not target or GetDistance(target.pos, myHero.pos) > _G.SDK.Data:GetAutoAttackRange(myHero) or not self.Menu.ToggleFightKey:Value() or self.Menu.FleeKey:Value() then
    	_G.SDK.Orbwalker:SetMovement(true)
    elseif target and GetDistance(target.pos, myHero.pos) < _G.SDK.Data:GetAutoAttackRange(myHero) then
    	if self.Menu.ComboMode.UseQFast:Value() and self.Menu.ComboMode.UseQ:Value() and self.Menu.ToggleFightKey:Value() and not self.Menu.FleeKey:Value() then 
    		_G.SDK.Orbwalker:SetMovement(false)
    	end
    	if myHero.attackData.state == 3 then
    		if OneTick then
    			attackedfirst = 1
    			attacked = 1
    			OneTick = false
    		end
    	else
    		OneTick = true
    	end
    end
    if target then
    	local Damages = self:GetDamages(target, 3)
    	--PrintChat(Damages.Totaldmg)
    end
    if self.Menu.FleeKey:Value() then
    	self:Escape()
    elseif self.Menu.ToggleFightKey:Value() then
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

function Riven:Draw()
    if self.Menu.Draw.UseDraws:Value() then

        --Draw.Circle(LastESpot, 85, 1, Draw.Color(255, 0, 0, 255))
        --Draw.Circle(LastE2Spot, 85, 1, Draw.Color(255, 255, 0, 255))
        --Draw.Circle(cursorPos, 85, 1, Draw.Color(255, 255, 0, 255))
        --Draw.Circle(mousePos, 185, 1, Draw.Color(255, 0, 0, 255))
        if target then
            AARange = _G.SDK.Data:GetAutoAttackRange(myHero)
            Draw.Circle(myHero.pos, 270, 1, Draw.Color(255, 0, 191, 255))
            local NextSpot = GetUnitPositionNext(myHero)
			local spot = myHero.pos
			if NextSpot then
				local Direction = Vector((myHero.pos-NextSpot):Normalized())
				spot = myHero.pos - Direction*270
				Draw.Circle(spot, 150, 1, Draw.Color(255, 0, 191, 255))
			end
        end
        if not self.Menu.ToggleFightKey:Value() then
        	--DrawText(i, 48, object.pos:ToScreen(), DrawColor(255, 0, 255, 0))
        	--Draw.Text("Fighting Off", 18, myHero.pos:ToScreen(), Draw.Color(255, 255, 0, 0))
        	Draw.Text("Fighting Off", 18, 370, 40, Draw.Color(255, 255, 0, 0))
        	Draw.Text("Fighting Off", 18, myHero.pos:ToScreen().x-40, myHero.pos:ToScreen().y-110, Draw.Color(255, 255, 0, 0))
        end
    end
end

function Riven:KS()
    --PrintChat("ksing")
    for i, enemy in pairs(EnemyHeroes) do
        if enemy and not enemy.dead and ValidTarget(enemy) then
        end
    end
end 

function Riven:CanUse(spell, mode)
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


function Riven:DelayEscapeClick(delay)
	if Game.Timer() - LastCalledTime > delay then
		LastCalledTime = Game.Timer()
		Control.RightClick(mousePos:To2D())
	end
end

function Riven:Escape()
	self:DelayEscapeClick(0.10)
	if self:CanUse(_E, "Flee") then
		Control.CastSpell(HK_E, mousePos)
	end
	if self:CanUse(_Q, "Flee") and not (myHero.pathing and myHero.pathing.isDashing) then
		Control.CastSpell(HK_Q)
	end
end

function Riven:Logic()
    if target == nil then return end
    if Mode() == "Combo" or Mode() == "Harass" and target then
    	self:GetInRange(target)
        local AARange = _G.SDK.Data:GetAutoAttackRange(myHero)
        if GetDistance(target.pos) < AARange then
            WasInRange = true
        end
        local QRange = 270
        local Q3Range = 270
        local WRange = 250
        local ERange = 250 + AARange
        if self:CanUse(_Q, Mode()) then
        	ERange = 250 + 270
        end
       -- PrintChat(Q)
        local Damages = self:GetDamages(target, 3)
        if Damages.Rdmg > target.health and self:CanUse(_R, Mode()) and R == 2 and GetDistance(target.pos, myHero.pos) < 900 then
        	self:UseR(target)
        end
        if Q < 4 and self:CanUse(_Q, Mode()) and ValidTarget(target, QRange) and attacked == 1 then
        	if R == 1 and self:CanUse(_R, Mode()) and self:CanKill(target) and not self:CanUse(_E, Mode()) and not self:CanUse(_W, Mode()) then
				Control.CastSpell(HK_R)
        	end
            self:UseQ(target)
        end
        if Q == 4 and self:CanUse(_Q, Mode()) and ValidTarget(target, Q3Range) and attacked == 1 then
            self:UseQ3(target)
        end
        if self:CanUse(_W, Mode()) and ValidTarget(target, WRange) and Q == 1 and not self:CanUse(_Q, Mode()) and attacked == 1 then
        	if R == 1 and self:CanUse(_R, Mode()) and self:CanKill(target) and not self:CanUse(_E, Mode()) then
				Control.CastSpell(HK_R)
        	end
         end
        if self:CanUse(_E, Mode()) and ValidTarget(target, ERange) and (Q == 1 or GetDistance(target.pos, myHero.pos) > 270) and (not self:CanUse(_Q, Mode()) or GetDistance(target.pos, myHero.pos) > 270) then
        	if R == 1 and self:CanUse(_R, Mode()) and self:CanKill(target) then
				Control.CastSpell(HK_R)
        	end
            Control.CastSpell(HK_E, target)
            if self:CanUse(_W, Mode()) then
            	Control.CastSpell(HK_W)
            end
        end
        --PrintChat(Damages.Rdmg)
        if not self:CanUse(_E, Mode()) and not self:CanUse(_W, Mode()) and not self:CanUse(_Q, Mode()) and self:CanUse(_R, Mode()) then
        	if GetDistance(target.pos, myHero.pos) < 800 and Damages.Rdmg > target.health and (GetDistance(target.pos, myHero.pos) > AARange or myHero.attackData.state == 3) then
        		Control.CastSpell(HK_R)
        	end
        end
    else
        WasInRange = false
    end     
end

function Riven:GetInRange(unit)
	--PrintChat("Getting in range")
	local AARange = _G.SDK.Data:GetAutoAttackRange(myHero)
	if unit and GetDistance(unit.pos, myHero.pos) > AARange then
		--PrintChat("Got unit")
		if self:CanUse(_E, Mode()) and self:CanUse(_Q, Mode()) and self.Menu.ComboMode.GapUseE:Value() then
			--PrintChat("Can use E")
			if Q == 1 and GetDistance(unit.pos, myHero.pos) < 1060 then
				--PrintChat("Checking damage for E")
				local Damages = self:GetDamages(unit, 1)
				--PrintChat(Damages.Totaldmg)
				if Damages.Totaldmg > unit.health then
					if R == 1 and self:CanUse(_R, Mode()) then
						Control.CastSpell(HK_R)
        			end
					Control.CastSpell(HK_E, unit.pos)
				end 
			elseif Q < 4 and GetDistance(unit.pos, myHero.pos) < 790 then
				local Damages = self:GetDamages(unit, 2)
				--PrintChat("Casting Close E")
				if Damages.Totaldmg > unit.health then
					if R == 1 and self:CanUse(_R, Mode()) then
						Control.CastSpell(HK_R)
        			end
					Control.CastSpell(HK_E, unit.pos)
				end 
			end
		elseif self:CanUse(_Q, Mode()) and self.Menu.ComboMode.GapUseQ:Value() and not (myHero.pathing and myHero.pathing.isDashing) then
			if Q == 1 and GetDistance(unit.pos, myHero.pos) < 810 then
				local Damages = self:GetDamages(unit, 1)
				if Damages.Totaldmg > unit.health then
					Control.CastSpell(HK_Q, unit)
				end 
			elseif Q < 4 and GetDistance(unit.pos, myHero.pos) < 540 then
				local Damages = self:GetDamages(unit, 2)
				if Damages.Totaldmg > unit.health then
					Control.CastSpell(HK_Q, unit)
				end 
			end
		end
	end

end

function Riven:UseR(unit)
        local pred = _G.PremiumPrediction:GetAOEPrediction(myHero, unit, RSpellData)
        if pred.CastPos and _G.PremiumPrediction.HitChance.Low(pred.HitChance) and myHero.pos:DistanceTo(pred.CastPos) < 900 then
            Control.CastSpell(HK_R, pred.CastPos)
        end 
end

function Riven:PredQSpot(unit)
        local pred = _G.PremiumPrediction:GetAOEPrediction(myHero, unit, QSpellData)
        if pred.CastPos and _G.PremiumPrediction.HitChance.Low(pred.HitChance) then
            return pred.CastPos
        end 
end

function CheckQSpot(unit)
	local NextSpot = GetUnitPositionNext(myHero)
	local spot = myHero.pos
	if NextSpot then
		local Direction = Vector((myHero.pos-NextSpot):Normalized())
		spot = myHero.pos - Direction*270
	end
	if GetDistance(spot, unit.pos) < 150 then
		return true
	end
	return false
end

function Riven:OnPostAttackTick(args)
    if target then
    	local Damages = self:GetDamages(target, 3)
    	if (not self:CanUse(_Q, Mode()) or Damages.Rdmg > target.health) and self:CanUse(_R, Mode()) and R == 2 and GetDistance(target.pos, myHero.pos) < 900 then
        	--self:UseR(target)
        end
    end
	if target and attacked == 0 and self.Menu.ComboMode.UseQFast:Value() then
		--PrintChat("Clicking")
		Control.RightClick(mousePos:To2D())
	end
	--PrintChat("Attacked = 1")
    attackedfirst = 1
    attacked = 1
end


function Riven:GetDamages(unit, MaxQ)
	local Pdmg = myHero.totalDamage * 0.25
	local PassiveStage = myHero.levelData.lvl / 3
	if PassiveStage == 2 then
		Pdmg = myHero.totalDamage * 0.30
	elseif PassiveStage == 3 then
		Pdmg = myHero.totalDamage * 0.35
	elseif PassiveStage == 4 then
		Pdmg = myHero.totalDamage * 0.40
	elseif PassiveStage == 5 then
		Pdmg = myHero.totalDamage * 0.45
	elseif PassiveStage == 6 then
		Pdmg = myHero.totalDamage * 0.50
	end
    local Rdmg = getdmg("R", unit, myHero, 1, myHero:GetSpellData(_R).level)
    local Qdmg = getdmg("Q", unit, myHero, 1, myHero:GetSpellData(_Q).level)
    local Wdmg = getdmg("W", unit, myHero, 1, myHero:GetSpellData(_W).level)
    local AAdmg = getdmg("AA", unit, myHero) 
    local totalDamage = 0
    if self:CanUse(_Q, Mode()) then
    	if Q == 1 and MaxQ == 3 then
    		totalDamage = totalDamage + (Qdmg + AAdmg + Pdmg) * 3
    	elseif Q < 4 and MaxQ > 1 then
    		totalDamage = totalDamage + (Qdmg + AAdmg + Pdmg) * 2
    	elseif MaxQ == 1 then
    	    totalDamage = totalDamage + (Qdmg + AAdmg + Pdmg)
    	end
    end 
    if self:CanUse(_W, Mode()) then
    	totalDamage = totalDamage + Wdmg + AAdmg + Pdmg
    end 
    
    if self:CanUse(_R, Mode()) then
    	totalDamage = totalDamage * 1.2 + Rdmg
    end
    local Damages = {Qdmg = Qdmg, Wdmg = Wdmg, Rdmg =Rdmg, AAdmg = AAdmg, Totaldmg = totalDamage}
    --PrintChat(totalDamage)
    return Damages
end

function Riven:CanKill(unit)
	local Damages = self:GetDamages(unit, 3)
	--PrintChat(Damages.Totaldmg)
	return Damages.Totaldmg > unit.health
end

function Riven:OnPreAttack(args)
    if self:CanUse(_E, Mode()) and target then
    end
end

function Riven:UseQ3(unit)
	if self.Menu.ComboMode.UseQHop:Value() then
			--PrintChat("Check Q 3")
		    local Direction = Vector((unit.pos-myHero.pos):Normalized())
			local EndSpot = unit.pos + Direction*400
			local Direction2 = Vector((myHero.pos-unit.pos):Normalized())
			local MoveSpot = myHero.pos - Direction2*400
			Control.RightClick(MoveSpot:To2D())
			if CheckQSpot(unit) then
	        	Control.CastSpell(HK_Q, EndSpot)
	        	--PrintChat("Cast Q 3")
	        	attacked = 0
	       	else
		        Control.CastSpell(HK_Q, unit)
		        attacked = 0
	        end
    else
    	 local Direction = Vector((unit.pos-myHero.pos):Normalized())
			local EndSpot = unit.pos + Direction*400
			local Direction2 = Vector((myHero.pos-unit.pos):Normalized())
			local MoveSpot = myHero.pos - Direction2*400
			Control.RightClick(mousePos:To2D())
			if CheckQSpot(unit) and not self.Menu.ComboMode.UseQFast:Value()  then
				if self:CanUse(_W, Mode()) and Q == 1 then
	            	Control.CastSpell(HK_W)
	            	DelayAction(function() Control.CastSpell(HK_Q, EndSpot) end, 0.05)
	            else
	        		Control.CastSpell(HK_Q, EndSpot)
	        	end
	        	--PrintChat("Cast Q 1 or 2")
	        	attacked = 0
	    	elseif self:CanUse(_W, Mode()) and Q == 1 then
	            Control.CastSpell(HK_W)
	            DelayAction(function() Control.CastSpell(HK_Q, unit) end, 0.05)
	        else
	        	Control.CastSpell(HK_Q, unit)
	        end
	        attacked = 0
   	end
end

function Riven:UseQ(unit)
		--PrintChat("Check Q 1 or 2")
		if self.Menu.ComboMode.UseQHop:Value() then
			local Direction = Vector((unit.pos-myHero.pos):Normalized())
			local EndSpot = unit.pos + Direction*400
			local Direction2 = Vector((myHero.pos-unit.pos):Normalized())
			local MoveSpot = myHero.pos - Direction2*400
			Control.RightClick(MoveSpot:To2D())
			if CheckQSpot(unit) then
				if self:CanUse(_W, Mode()) and Q == 1 then
	            	Control.CastSpell(HK_W)
	            	DelayAction(function() Control.CastSpell(HK_Q, EndSpot) end, 0.05)
	            else
	        		Control.CastSpell(HK_Q, EndSpot)
	        	end
	        	--PrintChat("Cast Q 1 or 2")
	        	attacked = 0
	        else
		        if self:CanUse(_W, Mode()) and Q == 1 then
		            Control.CastSpell(HK_W)
		            DelayAction(function() Control.CastSpell(HK_Q, unit) end, 0.05)
		        else
		        	Control.CastSpell(HK_Q, unit)
		        end
		        attacked = 0
	        end
	    else
	        local Direction = Vector((unit.pos-myHero.pos):Normalized())
			local EndSpot = unit.pos + Direction*400
			local Direction2 = Vector((myHero.pos-unit.pos):Normalized())
			local MoveSpot = myHero.pos - Direction2*400
			Control.RightClick(mousePos:To2D())
			if CheckQSpot(unit) and not self.Menu.ComboMode.UseQFast:Value() then
				if self:CanUse(_W, Mode()) and Q == 1 then
	            	Control.CastSpell(HK_W)
	            	DelayAction(function() Control.CastSpell(HK_Q, EndSpot) end, 0.05)
	            else
	        		Control.CastSpell(HK_Q, EndSpot)
	        	end
	        	--PrintChat("Cast Q 1 or 2")
	        	attacked = 0
	    	elseif self:CanUse(_W, Mode()) and Q == 1 then
	            Control.CastSpell(HK_W)
	            DelayAction(function() Control.CastSpell(HK_Q, unit) end, 0.05)
	        else
	        	Control.CastSpell(HK_Q, unit)
	        end
	        attacked = 0
       	end
end

function Riven:UseW(card)
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

class "TwistedFate"

local EnemyLoaded = false
local casted = 0
local LastESpot = myHero.pos
local LastE2Spot = myHero.pos
local PickingCard = false
local attackedfirst = 0
local WasInRange = false
local ComboCard = "Gold"
local LockGold = false
local LockBlue = false

function TwistedFate:Menu()
    self.Menu = MenuElement({type = MENU, id = "TwistedFate", name = "TwistedFate"})
    self.Menu:MenuElement({id = "GoldKey", name = "Gold Card Key (buffers a Gold Card)", key = string.byte("Space"), value = false})
    self.Menu:MenuElement({id = "BlueKey", name = "Blue Card Key (buffers a Blue Card", key = string.byte("T"), value = false})
    self.Menu:MenuElement({id = "ComboMode", name = "Combo", type = MENU})
    self.Menu.ComboMode:MenuElement({id = "UseQ", name = "Use Q in Combo", value = true})
    self.Menu.ComboMode:MenuElement({id = "UseW", name = "Use W in Combo", value = true})
    self.Menu:MenuElement({id = "KSMode", name = "KS", type = MENU})
    self.Menu.KSMode:MenuElement({id = "UseQ", name = "Use Q in KS", value = true})
    self.Menu:MenuElement({id = "HarassMode", name = "Harass", type = MENU})
    self.Menu.HarassMode:MenuElement({id = "UseQ", name = "Use Q in Harass", value = false})
    self.Menu.HarassMode:MenuElement({id = "UseW", name = "Use W in Harass", value = false})
    self.Menu:MenuElement({id = "Draw", name = "Draw", type = MENU})
    self.Menu.Draw:MenuElement({id = "UseDraws", name = "Enable Draws", value = false})
end

function TwistedFate:Spells()
    QSpellData = {speed = 1000, range = 1450, delay = 0.25, radius = 200, collision = {}, type = "linear"}
end


function TwistedFate:Tick()
    if _G.JustEvade and _G.JustEvade:Evading() or (_G.ExtLibEvade and _G.ExtLibEvade.Evading) or Game.IsChatOpen() or myHero.dead then return end
    --PrintChat(myHero:GetSpellData(_W).name)
    --PrintChat(myHero:GetSpellData(_R).toggleState)
    target = GetTarget(1400)
    --PrintChat(myHero.activeSpell.name)
    if self.Menu.GoldKey:Value() and IsReady(_W) then
    	LockGold = true
    	LockBlue = false
    elseif self.Menu.GoldKey:Value() then
    	ComboCard = "Gold"
    end
    if LockGold == true and IsReady(_W) then
    	self:UseW("Gold")
    end
    if self.Menu.BlueKey:Value() and IsReady(_W) then
    	LockBlue = true
    	LockGold = false
    elseif self.Menu.BlueKey:Value() then
    	ComboCard = "Blue"
    end
    if LockBlue == true and IsReady(_W) then
    	self:UseW("Blue")
    end
    self:KS()
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

function TwistedFate:Draw()
    if self.Menu.Draw.UseDraws:Value() then

        --Draw.Circle(LastESpot, 85, 1, Draw.Color(255, 0, 0, 255))
        --Draw.Circle(LastE2Spot, 85, 1, Draw.Color(255, 255, 0, 255))
        if target then
            AARange = _G.SDK.Data:GetAutoAttackRange(myHero)
            Draw.Circle(myHero.pos, AARange, 1, Draw.Color(255, 0, 191, 255))
        end
    end
end

function TwistedFate:KS()
    --PrintChat("ksing")
    for i, enemy in pairs(EnemyHeroes) do
        if enemy and not enemy.dead and ValidTarget(enemy) then
            local Qrange = 600
            local Qdamage = getdmg("Q", enemy, myHero, myHero:GetSpellData(_Q).level)
            if self:CanUse(_Q, "KS") and GetDistance(enemy.pos, myHero.pos) < Qrange and enemy.health < Qdamage then
                self:UseQ(enemy)
            end
        end
    end
end 

function TwistedFate:CanUse(spell, mode)
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
    end
    return false
end

function TwistedFate:Logic()
    if target == nil then return end
    if Mode() == "Combo" or Mode() == "Harass" and target then
        local AARange = _G.SDK.Data:GetAutoAttackRange(myHero)
        if GetDistance(target.pos) < AARange then
            WasInRange = true
        end
        local Qrange = 1450
        if self:CanUse(_Q, Mode()) and ValidTarget(target, Qrange) then
            self:UseQ(target)
        end
        if self:CanUse(_W, Mode()) and ValidTarget(target, AARange) then
            self:UseW(ComboCard)
        end
    else
        WasInRange = false
    end     
end

function TwistedFate:OnPostAttackTick(args)
    attackedfirst = 1
    if target then
    end
end


function TwistedFate:GetRDmg(unit)
    return getdmg("R", unit, myHero, stage, myHero:GetSpellData(_R).level)
end

function TwistedFate:OnPreAttack(args)
    if self:CanUse(_E, Mode()) and target then
    end
end

function TwistedFate:UseQ(unit)
        local pred = _G.PremiumPrediction:GetPrediction(myHero, unit, QSpellData)
        if pred.CastPos and _G.PremiumPrediction.HitChance.Low(pred.HitChance) and myHero.pos:DistanceTo(pred.CastPos) < 700 then
                Control.CastSpell(HK_Q, pred.CastPos)
        end 
end

function TwistedFate:UseW(card)
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

class "MasterYi"

local EnemyLoaded = false
local casted = 0
local LastESpot = myHero.pos
local LastE2Spot = myHero.pos
local attackedfirst = 0
local WasInRange = false

function MasterYi:Menu()
	self.Menu = MenuElement({type = MENU, id = "MasterYi", name = "MasterYi"})
	self.Menu:MenuElement({id = "UrfMode", name = "UrfMode", value = true})
	self.Menu:MenuElement({id = "FarmKey", name = "Farm Key", key = string.byte("Z"), value = false})
	self.Menu:MenuElement({id = "ComboMode", name = "Combo", type = MENU})
	self.Menu.ComboMode:MenuElement({id = "UseQ", name = "Use Q in Combo", value = true})
	self.Menu.ComboMode:MenuElement({id = "UseQAvoid", name = "Use Q To Avoid Spells", value = true})
	self.Menu.ComboMode:MenuElement({id = "UseW", name = "Use W in Combo", value = true})
	self.Menu.ComboMode:MenuElement({id = "UseE", name = "Use smart E in Combo", value = true})
	self.Menu:MenuElement({id = "KSMode", name = "KS", type = MENU})
	self.Menu.KSMode:MenuElement({id = "UseQ", name = "Use Q in KS", value = true})
	self.Menu:MenuElement({id = "HarassMode", name = "Harass", type = MENU})
	self.Menu.HarassMode:MenuElement({id = "UseQ", name = "Use Q in Harass", value = false})
	self.Menu.HarassMode:MenuElement({id = "UseW", name = "Use W in Harass", value = false})
	self.Menu.HarassMode:MenuElement({id = "UseE", name = "Use smart E in Harass", value = false})
	self.Menu:MenuElement({id = "OrbMode", name = "Orbwalker", type = MENU})
    self.Menu.OrbMode:MenuElement({id = "UseMeleeHelper", name = "Enable MeleeHelper", value = true})
    self.Menu.OrbMode:MenuElement({id = "MeleeHelperMouseDistance", name = "Mouse Distance From Target To Enable", value = 550, min = 0, max = 1500, step = 50})
	self.Menu:MenuElement({id = "Draw", name = "Draw", type = MENU})
	self.Menu.Draw:MenuElement({id = "UseDraws", name = "Enable Draws", value = false})
	self.Menu.Draw:MenuElement({id = "MeleeHelperSpot", name = "Draw Melee Helper Spot", value = false})
    self.Menu.Draw:MenuElement({id = "MeleeHelperDistance", name = "Draw Melee Helper Mouse Distance", value = false})
end

function MasterYi:Spells()
	RSpellData = {speed = 1300, range = 1300, delay = 0.25, radius = 70, collision = {}, type = "linear"}
	ESpellData = {speed = 3000, range = 700, delay = 0.25, radius = 20, collision = {}, type = "linear"}
	E2SpellData = {speed = 3000, range = 470, delay = 0.45, radius = 200, collision = {}, type = "circular"}
end


function MasterYi:Tick()
	if _G.JustEvade and _G.JustEvade:Evading() or (_G.ExtLibEvade and _G.ExtLibEvade.Evading) or Game.IsChatOpen() or myHero.dead then return end
	--PrintChat(myHero:GetSpellData(_E).name)
	--PrintChat(myHero:GetSpellData(_R).toggleState)
	target = GetTarget(1400)
	--PrintChat(myHero.activeSpell.name)
	if myHero.activeSpell.name == "MasterYiQ" then
		_G.SDK.Orbwalker:SetMovement(false)
		_G.SDK.Orbwalker:SetAttack(false)
	else
		_G.SDK.Orbwalker:SetMovement(true)
		_G.SDK.Orbwalker:SetAttack(true)
	end
	self:MeleeHelper()
	self:KS()
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

function MasterYi:Draw()
	if self.Menu.Draw.UseDraws:Value() then

		--Draw.Circle(LastESpot, 85, 1, Draw.Color(255, 0, 0, 255))
		--Draw.Circle(LastE2Spot, 85, 1, Draw.Color(255, 255, 0, 255))
		if target then
			AARange = _G.SDK.Data:GetAutoAttackRange(myHero)
			Draw.Circle(myHero.pos, AARange, 1, Draw.Color(255, 0, 191, 255))

		end

		if self.Menu.OrbMode.UseMeleeHelper:Value() and target and self.Menu.Draw.MeleeHelperDistance:Value() then
            Draw.Circle(target.pos, self.Menu.OrbMode.MeleeHelperMouseDistance:Value(), 1, Draw.Color(255, 0, 0, 0))
        end
        if self.Menu.OrbMode.UseMeleeHelper:Value() and target and self.Menu.Draw.MeleeHelperSpot:Value() then
            local MeleeSpot = self:DrawMeleeHelper()
            if MeleeSpot then
                Draw.Circle(MeleeSpot, 25, 1, Draw.Color(255, 0, 100, 255))
                Draw.Circle(MeleeSpot, 35, 1, Draw.Color(255, 0, 100, 255))
                Draw.Circle(MeleeSpot, 45, 1, Draw.Color(255, 0, 100, 255))
            end
        end
	end
end


function MasterYi:DrawMeleeHelper()
    local AARange = _G.SDK.Data:GetAutoAttackRange(myHero)
    local MoveSpot = nil
    if self.Menu.OrbMode.UseMeleeHelper:Value() and target and Mode() == "Combo" and GetDistance(mousePos, target.pos) < self.Menu.OrbMode.MeleeHelperMouseDistance:Value() and GetDistance(target.pos) <= AARange then
        local MouseDirection = Vector((target.pos-mousePos):Normalized())
        local MouseDistance = GetDistance(mousePos, target.pos)
        local MouseSpotDistance = AARange - target.boundingRadius
        if IsFacing(target) then
            MouseSpotDistance = AARange - 10
            --PrintChat("Facing")
        end
        local MouseSpot = target.pos - MouseDirection * (MouseSpotDistance)
        MoveSpot = MouseSpot
        return MoveSpot
        --PrintChat("Forcing")
    else
        return nil
    end
end

function MasterYi:MeleeHelper()
    local AARange = _G.SDK.Data:GetAutoAttackRange(myHero)
    local MoveSpot = nil
    if self.Menu.OrbMode.UseMeleeHelper:Value() and target and Mode() == "Combo" and GetDistance(mousePos, target.pos) < self.Menu.OrbMode.MeleeHelperMouseDistance:Value() and GetDistance(target.pos) <= AARange then
        local MouseDirection = Vector((target.pos-mousePos):Normalized())
        local MouseDistance = GetDistance(mousePos, target.pos)
        local MouseSpotDistance = AARange - target.boundingRadius
        if IsFacing(target) then
            MouseSpotDistance = AARange - 10
            --PrintChat("Facing")
        end
        local MouseSpot = target.pos - MouseDirection * (MouseSpotDistance)
        MoveSpot = MouseSpot
        _G.SDK.Orbwalker.ForceMovement = MoveSpot
        --PrintChat("Forcing")
    else
        _G.SDK.Orbwalker.ForceMovement = nil
    end
    if MoveSpot and GetDistance(MoveSpot) < 50 then
        _G.SDK.Orbwalker:SetMovement(false)
        --PrintChat("False")
    else
        _G.SDK.Orbwalker:SetMovement(true)
    end
end

function MasterYi:KS()
	--PrintChat("ksing")
	for i, enemy in pairs(EnemyHeroes) do
		if enemy and not enemy.dead and ValidTarget(enemy) then
			local Qrange = 600
			local Qdamage = getdmg("Q", enemy, myHero, myHero:GetSpellData(_Q).level)
			if self:CanUse(_Q, "KS") and GetDistance(enemy.pos, myHero.pos) < Qrange and enemy.health < Qdamage then
				Control.CastSpell(HK_Q, enemy)
			end
		end
	end
end	

function MasterYi:CanUse(spell, mode)
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
	elseif spell == _R then
		if mode == "Combo" and IsReady(spell) and self.Menu.ComboMode.UseR:Value() then
			return true
		end
		if mode == "Manual" and IsReady(spell) and self.Menu.ComboMode.UseRMan:Value() and self.Menu.ComboMode.UseRManKey:Value() then
			return true
		end
	end
	return false
end

function MasterYi:IsTargetedBy(unit)

    local targeted = false
    if unit.activeSpell.target == myHero.handle and unit.activeSpell.isChanneling == false and unit.totalDamage and unit.critChance then
    	if unit.totalDamage + (unit.totalDamage*unit.critChance) > myHero.health then
    		targeted = true
    	end
    elseif unit.activeSpell.target == myHero.handle then
        --PrintChat("Spell")
        if unit.activeSpell.name == unit:GetSpellData(_Q).name then
            --PrintChat(Qdmg)
            targeted = true
        elseif unit.activeSpell.name == unit:GetSpellData(_W).name then
            --PrintChat("W")
            targeted = true
        elseif unit.activeSpell.name == unit:GetSpellData(_E).name then
            --PrintChat("E")
            targeted = true
        elseif unit.activeSpell.name == unit:GetSpellData(_R).name then
            --PrintChat("R")
            targeted = true
        end
    end
    if targeted == true then
    	--PrintChat("Targetted")
    end
    return targeted
end

function MasterYi:Logic()
	if target == nil then return end
	if Mode() == "Combo" or Mode() == "Harass" and target then
		local AARange = _G.SDK.Data:GetAutoAttackRange(myHero)
		if GetDistance(target.pos) < AARange then
			WasInRange = true
		end
		local Qrange = 600
		if self:CanUse(_Q, Mode()) and ValidTarget(target, Qrange) and (GetDistance(target.pos, myHero.pos) > AARange + target.boundingRadius or self.Menu.UrfMode:Value() or (self:IsTargetedBy(target) and self.Menu.ComboMode.UseQAvoid:Value())) and not _G.SDK.Attack:IsActive() then
			if self:CanUse(_E, Mode()) then
				Control.CastSpell(HK_E)
			end
			Control.CastSpell(HK_Q, target)
		end
	else
		WasInRange = false
    end		
end

function MasterYi:OnPostAttackTick(args)
	attackedfirst = 1
	if target then
		local AARange = _G.SDK.Data:GetAutoAttackRange(myHero)
		if self:CanUse(_W, Mode()) and ValidTarget(target, AARange) then
			Control.CastSpell(HK_W)
		end
	end
end


function MasterYi:GetRDmg(unit)
	return getdmg("R", unit, myHero, stage, myHero:GetSpellData(_R).level)
end

function MasterYi:OnPreAttack(args)
	if self:CanUse(_E, Mode()) and target then
		Control.CastSpell(HK_E)
	end
end

function MasterYi:UseE(unit)
		local pred = _G.PremiumPrediction:GetPrediction(myHero, unit, ESpellData)
		if pred.CastPos and _G.PremiumPrediction.HitChance.Low(pred.HitChance) and myHero.pos:DistanceTo(pred.CastPos) < 700 then
		    	Control.CastSpell(HK_E, pred.CastPos)
		    	LastESpot = pred.CastPos
		end 
end

function MasterYi:UseR(unit)
		local pred = _G.PremiumPrediction:GetPrediction(myHero, unit, RSpellData)
		if pred.CastPos and _G.PremiumPrediction.HitChance.Medium(pred.HitChance) and myHero.pos:DistanceTo(pred.CastPos) < 1300  then
		    	Control.CastSpell(HK_R, pred.CastPos)
		end 
end

class "MissFortune"

local IS = {}
local EnemyLoaded = false
local QCastTime = Game:Timer()
local RCastTime = Game:Timer()
local Casted = 0
local CanQclick = true
local attackedfirst = 0
local WasInRange = false
local DoubleShot = false
local IsUlting = false
local LastCalledTime = 0
local Direction = myHero.pos

function MissFortune:Menu()
    self.Menu = MenuElement({type = MENU, id = "MissFortune", name = "MissFortune"})
    self.Menu:MenuElement({id = "ComboMode", name = "Combo", type = MENU})
    self.Menu.ComboMode:MenuElement({id = "UseQ", name = "Use Q in Combo", value = true})
    self.Menu.ComboMode:MenuElement({id = "UseW", name = "Use W in Combo", value = true})
    self.Menu.ComboMode:MenuElement({id = "UseE", name = "Use smart E in Combo", value = true})
    self.Menu.ComboMode:MenuElement({id = "UseEMin", name = "Min Hits To Cast E without Ult", value = 1, min = 0, max = 5, step = 1})
    self.Menu.ComboMode:MenuElement({id = "UseR", name = "Use R in Combo When Target Low", value = true})
    self.Menu.ComboMode:MenuElement({id = "UseRMin", name = "Min Hits To Cast R", value = 3, min = 0, max = 5, step = 1})
    self.Menu.ComboMode:MenuElement({id = "UseRManKey", name = "Use Manual R key", key = string.byte("T"), value = false})
    self.Menu.ComboMode:MenuElement({id = "StopRManKey", name = "Cancel R key", key = string.byte("R"), value = false})
    self.Menu.ComboMode:MenuElement({id = "UseQMinionCombo", name = "Q Bounce in Combo", value = true})
    self.Menu.ComboMode:MenuElement({id = "UseQMinionHarass", name = "Auto Q Bounce in Harras (May FPS Drop)", value = false})
    self.Menu.ComboMode:MenuElement({id = "UseQDelay", name = "Bounce check (Higher = More FPS)", value = 0.2, min = 0.1, max = 1, step = 0.1})
    self.Menu.ComboMode:MenuElement({id = "UseQMana", name = "Min Mana % to use Auto Q", value = 10, min = 0, max = 100, step = 1})
    self.Menu:MenuElement({id = "HarassMode", name = "Harass", type = MENU})
    self.Menu.HarassMode:MenuElement({id = "UseQ", name = "Use Q in Harass", value = true})
    self.Menu.HarassMode:MenuElement({id = "UseW", name = "Use W in Harass", value = true})
    self.Menu.HarassMode:MenuElement({id = "UseE", name = "Use smart E in Harass", value = true})
    self.Menu:MenuElement({id = "Draw", name = "Draw", type = MENU})
    self.Menu.Draw:MenuElement({id = "UseDraws", name = "Enable Draws", value = false})
end

function MissFortune:Spells()
    WSpellData = {speed = 1600, range = 900, delay = 0.25, radius = 40, collision = {}, type = "linear"}
    ESpellData = {speed = 1600, range = 1000, delay = 0.25, radius = 200, collision = {}, type = "circular"}
    RSpellData = {speed = 2800, range = 1300, delay = 0.25, angle = 40, radius = 0, collision = {}, type = "conic"}
end



function MissFortune:Tick()
    if _G.JustEvade and _G.JustEvade:Evading() or (_G.ExtLibEvade and _G.ExtLibEvade.Evading) or Game.IsChatOpen() or myHero.dead then return end
    target = GetTarget(1400)
    --PrintChat(Casted)
    IsUlting = myHero.activeSpell.name == "MissFortuneBulletTime" 
    if self.Menu.ComboMode.UseRManKey:Value() then
        if target and self:CanUse(_R, "Manual") and ValidTarget(target, 1400) and GetDistance(target.pos) > 350 then
        	--PrintChat("Should cast R")
            self:UseR(target, 1)
        end
    end
    if self.Menu.ComboMode.StopRManKey:Value() then
        _G.SDK.Orbwalker:SetMovement(true)
        _G.SDK.Orbwalker:SetAttack(true)
    end
    --PrintChat(myHero.activeSpell.name)
    if Casted == 1 then
    	if IsUlting then
    		Casted = 0
    		--PrintChat("casted = 0")
    	end
        _G.SDK.Orbwalker:SetMovement(false)
        _G.SDK.Orbwalker:SetAttack(false)
    elseif Casted == 0 and not IsUlting then
    	self:KS()
    	self:Logic()
    	_G.SDK.Orbwalker:SetMovement(true)
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
    if not IsUlting and casted == 0 and self:CanUse(_Q, Mode()) and self.Menu.ComboMode.UseQMinionCombo:Value() then
    	local BounceTarget = nil
    	if Mode() == "Combo" then
    		BounceTarget = self:DelayQBounce(self.Menu.ComboMode.UseQDelay:Value())
    	end
    	if Mode() == "Harass" and self.Menu.ComboMode.UseQMinionHarass:Value() then
			BounceTarget = self:DelayQBounce(self.Menu.ComboMode.UseQDelay:Value())
		end
        if BounceTarget then
        	Control.CastSpell(HK_Q, BounceTarget.CastTarget)
        end
    end
end

function MissFortune:Draw()
    if self.Menu.Draw.UseDraws:Value() then
        Draw.Circle(myHero.pos, 550, 1, Draw.Color(255, 0, 191, 255))
        if target then
        	local Direction = Vector((target.pos-myHero.pos):Normalized())
			local EndSpot = target.pos + Direction*500
			--Draw.Circle(EndSpot, 250, 1, Draw.Color(255, 0, 191, 255))
			--Direction = Vector((myHero.pos-target.pos):Normalized())
			--lhs = Vector(mousePos-myHero.pos)
           -- dotp = lhs:DotProduct(Direction)
           -- Location = myHero.pos + Direction * dotp
			--Draw.Circle(Location, 250, 1, Draw.Color(255, 0, 191, 255))


        	local BounceTarget = self:GetQBounceTarget(target)
        	if BounceTarget then
        		--PrintChat("Bounce Target")
        		Draw.Circle(BounceTarget.CastTarget.pos, 50, 1, Draw.Color(255, 0, 191, 255))
        		Draw.Circle(BounceTarget.HitTarget.pos, 50, 1, Draw.Color(255, 255, 191, 255))
        	end
        end
    end
end

function MissFortune:KS()
    --PrintChat("ksing")
    for i, enemy in pairs(EnemyHeroes) do
        if enemy and not enemy.dead and ValidTarget(enemy, 900) then
        end
    end
end 

function MissFortune:CanUse(spell, mode)
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
        if mode == "KS" and IsReady(spell) and self.Menu.ComboMode.UseQMinion:Value() then
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
    elseif spell == _R then
        if mode == "Combo" and IsReady(spell) and self.Menu.ComboMode.UseR:Value() then
            return true
        end
        if mode == "Manual" and IsReady(spell) and self.Menu.ComboMode.UseR:Value() then
            return true
        end
    end
    return false
end

function MissFortune:Logic()
    if target == nil then return end
    if Mode() == "Combo" or Mode() == "Harass" and target then
        if GetDistance(target.pos) < 500 then
            WasInRange = true
        end
        if Casted == 1 then
            if _G.SDK.Orbwalker:CanAttack() then
                --Control.Attack(enemy)
            end
        end
        if self:CanUse(_E, Mode()) and GetDistance(target.pos, myHero.pos) < 1000 then
            self:UseE(target, self.Menu.ComboMode.UseEMin:Value())
        end
        if self:CanUse(_R, Mode()) and ValidTarget(target, 1400) and GetDistance(target.pos) > 350 then
        	--PrintChat("Should cast R")
            self:UseR(target, self.Menu.ComboMode.UseRMin:Value())
        end
    else
        WasInRange = false
    end     
end

function MissFortune:DelayQBounce(delay)
	if Game.Timer() - LastCalledTime > delay then
		LastCalledTime = Game.Timer()
		--PrintChat("Delayed Q")
		return self:GetQBounceTarget()
	end
end

function MissFortune:GetQBounceTarget(unit)
    --PrintChat("Getting Q minion")
    local minions = _G.SDK.ObjectManager:GetEnemyMinions(1100)
    local mtarget = nil
    local mhit = nil
    local mlocation = nil
    local ClosestEnemyHero = nil
    local ClosestDist = 500
    local manaper = myHero.mana / myHero.maxMana * 100
	--_G.PremiumPrediction:IsPointInArc(sourcePos, unitPos, endPos, range, angle)
    if manaper > self.Menu.ComboMode.UseQMana:Value() then -- if Have enough mana
    	for j, enemy in pairs(EnemyHeroes) do -- Check all the enemy champs first, to see if we can bounce Q off them
    		if enemy and not enemy.dead and ValidTarget(enemy, 650) then
				local Direction = Vector((enemy.pos-myHero.pos):Normalized()) -- get the direction from myhero to the enemy hero being checked
				local EndSpot = enemy.pos + Direction*500 -- Get the furthest spot the Q can bounce to dead behind
				for i = 1, #minions do -- Start by looping through all the minions to find the closest
	                local minion = minions[i]
	                if minion.team == 300 - myHero.team and IsValid(minion) then
	                    if GetDistance(myHero.pos, enemy.pos) < GetDistance(minion.pos, myHero.pos) and GetDistance(minion.pos, enemy.pos) < 500 then -- If the minion is further away than the enemy champ, but within 500 range of the enemy champ
							local Distance = self:GetDistanceToMiddle(enemy, EndSpot, minion) -- seee How far it is from the middle line of the cone
			            	if Distance < ClosestDist then -- if it's our closest, save the distance for later, enemy heros have to be closer than this to their line.
			            		ClosestDist = Distance
			            	end
	                    end
	                end
	            end
         		for j, enemy2 in pairs(EnemyHeroes) do -- Now we search the enemy champions
         			--PrintChat(enemy2.networkID)
         			-- If the enemy we want to bounce to is within 500 range, not the enemy we are trying to bounce off, and furhter away than the target we are bouncing off
					if enemy2 and not enemy2.dead and GetDistance(enemy2.pos, enemy.pos) < 500 and enemy.networkID ~= enemy2.networkID and GetDistance(myHero.pos, enemy.pos) < GetDistance(enemy2.pos, myHero.pos) then 
			            --PrintChat("Yeah this check worked")
			            local DistanceMid = self:GetDistanceToMiddle(enemy, EndSpot, enemy2) -- Get the distance to the middle of the cone
			            --print(DistanceMid)
			            --PrintChat("Distance")
			            if DistanceMid < ClosestDist then -- If the distance is the closest (this includes all the minions checked) It will get hit, so save it for now and the hero.
			            	ClosestEnemyHero = enemy2
			            	ClosestDist = DistanceMid
			            	--PrintChat("Found new closest")
			            end
					end
				end
             	if ClosestEnemyHero and _G.PremiumPrediction:IsPointInArc(enemy.pos, ClosestEnemyHero.pos, EndSpot, 500, 80) then -- Now we have our closest enemy hero, unless nil. If it's in the cone, save the mtarget and the enemy hero the bounce will hit
             		--PrintChat("Set Closest")
             		mtarget = enemy
             		mhit = ClosestEnemyHero
             		--PrintChat("made closest")
             	end
   		 	end
		end
		ClosestDist = 500 -- Reset the closest dist, we either didn't find one, or don't need it anyway.
		if not mtarget then -- If we didn't find one with a bounce from a hero, look for a bounce on minions
            for i = 1, #minions do -- Loop through all the minions to try and bounce off them
                local minion = minions[i]
                if minion.team == 300 - myHero.team and IsValid(minion) then
                	--PrintChat("In Q range")
                    if GetDistance(minion.pos, myHero.pos) < 650 then -- If in range to cast Q on
						local Direction = Vector((minion.pos-myHero.pos):Normalized())
						local EndSpot = minion.pos + Direction*500 -- Get the furthest spot in the cone the Q bounces from the minion
						for k = 1, #minions do -- start checking for the closest minion to the middle again
			                local minion2 = minions[k]
			                if minion2.team == 300 - myHero.team and IsValid(minion2) and minion.networkID ~= minion2.networkID then -- Make sure its not the same minion we are trying to bounce off
			                    if GetDistance(myHero.pos, minion.pos) < GetDistance(minion2.pos, myHero.pos) and GetDistance(minion2.pos, minion.pos) < 500 then -- Make sure its in the right spot again
									local Distance = self:GetDistanceToMiddle(minion, EndSpot, minion2) -- Find the distance to the middle
					            	if Distance < ClosestDist then -- if It's our closest, save the distance for later to check if the hero's are closer
					            		ClosestDist = Distance
					            	end
			                    end
			                end
			            end
	             		for j, enemy2 in pairs(EnemyHeroes) do -- Now check heors
							if enemy2 and not enemy2.dead and GetDistance(enemy2.pos, minion.pos) < 500 then
					            local Distance = self:GetDistanceToMiddle(minion, EndSpot, enemy2) -- Find out how close it is to the middle
					            if Distance < ClosestDist then -- Check the distance against the closest minion, and the other champs that were deemed closest
					            	ClosestEnemyHero = enemy2
					            	ClosestDist = Distance
					            end
							end
						end
	                 	if ClosestEnemyHero and _G.PremiumPrediction:IsPointInArc(minion.pos, ClosestEnemyHero.pos, EndSpot, 500, 80) then -- If we found a closest hero from a minion bounce, check if its in the arc
	                 		mtarget = minion -- Save it if it is
	                 		mhit = ClosestEnemyHero -- Also save who it will hit, useful for draws and checking if its target
	                 	end
                    end
                end
            end
        end
    end
    if ValidTarget(mtarget, 650) then -- If we found an mtarget and saved it, already checked if it was in the arc
        return {CastTarget = mtarget, HitTarget = mhit} -- Return both the Cast target, and the Hittarget via a table. BounceQ.CastTarget BounceQ.HitTarget for example.
    else
    	return nil -- Didn't find anything, try again later
    end
end

function MissFortune:GetDistanceToMiddle(startPos, endPos, checkPos)
	--PrintChat("Getting dist to middle")
    local Location = Vector(self:ClosestPointOnLineSegment(checkPos.pos, startPos.pos, endPos))
    --Draw.Circle(Location, 200, 1, Draw.Color(255, 0, 191, 255))
    --PrintChat(Location.x)
    local Distance = self:GetDistance2d(Location, checkPos.pos)
    --PrintChat(Distance)
    return Distance
end

function MissFortune:GetDistance2d(p1, p2)
    local dx = p2.x - p1.x
    local dz = p2.z - p1.z
    return math.sqrt(dx * dx + dz * dz)
end

function MissFortune:ClosestPointOnLineSegment(p, p1, p2)
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

function MissFortune:GetRDmg(unit, hits)
    local level = myHero:GetSpellData(_R).level
    local RDmg = getdmg("R", unit, myHero, myHero:GetSpellData(_R).level)
    if hits then
        return RDmg * hits
    else
        return  RDmg * (12 + 2*level)
    end
end


function MissFortune:OnPreAttack(args)
end

function MissFortune:OnPostAttackTick(args)
    attackedfirst = 1
    if target and Mode() == "Combo" or Mode() == "Harass" then
    	if self:CanUse(_Q, Mode()) and GetDistance(target.pos, myHero.pos) < 650 then
        	Control.CastSpell(HK_Q, target)
        end
        if self:CanUse(_W, Mode()) and GetDistance(target.pos, myHero.pos) < 650 then
        	Control.CastSpell(HK_W)
        end
    end
end

function MissFortune:UseE(unit, hits)
        local pred = _G.PremiumPrediction:GetAOEPrediction(myHero, unit, ESpellData)
        --PrintChat("trying E")
        if pred.CastPos and _G.PremiumPrediction.HitChance.Low(pred.HitChance) and myHero.pos:DistanceTo(pred.CastPos) < 1000 and pred.HitCount >= hits then
                Control.CastSpell(HK_E, pred.CastPos)
                --Casted = 1
        end 
end

function MissFortune:UseR(unit, hits)
        local pred = _G.PremiumPrediction:GetAOEPrediction(myHero, unit, RSpellData)
        if pred.CastPos and _G.PremiumPrediction.HitChance.Low(pred.HitChance) and myHero.pos:DistanceTo(pred.CastPos) < 1300 and target.health < self:GetRDmg(target)*0.8 then
        	--PrintChat("Casting R")
        	_G.SDK.Orbwalker:SetMovement(false)
        	_G.SDK.Orbwalker:SetAttack(false)
            Control.CastSpell(HK_R, pred.CastPos)
            Casted = 1
        end 
end

class "Lucian"

local IS = {}
local EnemyLoaded = false
local QCastTime = Game:Timer()
local RCastTime = Game:Timer()
local Casted = 0
local QCasted = false
local AAData = 1
local UsedE = false
local CanQclick = true
local attackedfirst = 0
local WasInRange = false
local DoubleShot = false
local Direction = myHero.pos

function Lucian:Menu()
	self.Menu = MenuElement({type = MENU, id = "Lucian", name = "Lucian"})
	self.Menu:MenuElement({id = "ComboMode", name = "Combo", type = MENU})
	self.Menu.ComboMode:MenuElement({id = "UseQ", name = "Use Q in Combo", value = true})
	self.Menu.ComboMode:MenuElement({id = "UseW", name = "Use W in Combo", value = true})
	self.Menu.ComboMode:MenuElement({id = "UseE", name = "Use smart E in Combo", value = true})
	self.Menu.ComboMode:MenuElement({id = "Use2", name = "Use E Before W", value = true})
	self.Menu.ComboMode:MenuElement({id = "Use3", name = "Use E Before Q", value = false})
	self.Menu.ComboMode:MenuElement({id = "UseR", name = "Use R in Combo", value = true})
	self.Menu.ComboMode:MenuElement({id = "UseRManKey", name = "Manual R key", key = string.byte("T"), value = false})
	self.Menu.ComboMode:MenuElement({id = "UseQMinionCombo", name = "Q on minions in Combo (No FPS Drops)", value = false})
	self.Menu.ComboMode:MenuElement({id = "UseQMinion", name = "Auto Q on minions (May Cause FPS Drops)", value = false})
	self.Menu.ComboMode:MenuElement({id = "UseQMana", name = "Min Mana % to use Auto Q", value = 10, min = 0, max = 100, step = 1})
	self.Menu.ComboMode:MenuElement({id = "UseRMagnet", name = "Magnet when R is active", value = false})
	self.Menu.ComboMode:MenuElement({id = "rMagnetMouseRange", name = "Magnet Mouse Range", value = 700, min = 100, max = 1200, step = 100})
	self.Menu.ComboMode:MenuElement({id = "rMagnetHeroRange", name = "Magnet Hero Range", value = 500, min = 100, max = 1200, step = 100})
	self.Menu.ComboMode:MenuElement({id = "rMagnetSmooth", name = "Smooth Magnet Mode", value = false})
	self.Menu:MenuElement({id = "HarassMode", name = "Harass", type = MENU})
	self.Menu.HarassMode:MenuElement({id = "UseQ", name = "Use Q in Harass", value = true})
	self.Menu.HarassMode:MenuElement({id = "UseW", name = "Use W in Harass", value = true})
	self.Menu.HarassMode:MenuElement({id = "UseE", name = "Use smart E in Harass", value = false})
	self.Menu:MenuElement({id = "Draw", name = "Draw", type = MENU})
	self.Menu.Draw:MenuElement({id = "UseDraws", name = "Enable Draws", value = false})
end

function Lucian:Spells()
	WSpellData = {speed = 1600, range = 900, delay = 0.25, radius = 40, collision = {}, type = "linear"}
	RSpellData = {speed = 2800, range = 1200, delay = 0, radius = 110, collision = {}, type = "linear"}
end

function Lucian:Tick()
	if _G.JustEvade and _G.JustEvade:Evading() or (_G.ExtLibEvade and _G.ExtLibEvade.Evading) or Game.IsChatOpen() or myHero.dead then return end
	target = GetTarget(1400)
	--PrintChat(myHero.activeSpell.name)
	if (myHero.pathing and myHero.pathing.isDashing) then
		UsedE = true
		--PrintChat("Casting E")
	elseif UsedE == true then
		--PrintChat("rest E")
		if hasPassive then
			DelayAction(function() _G.SDK.Orbwalker:__OnAutoAttackReset() end, 0.05)
		end
		UsedE = false
	end
	--PrintChat(myHero.attackData.state)
	if myHero.activeSpell.name == "LucianQ" then
		--PrintChat("Casting Q")
		QCasted = true
	else
		--PrintChat("Not Casting Q")
		if QCasted == true then
			if target then
				Control.Attack(target)
			end
		end
		QCasted = false
	end
	local hasPassive = _G.SDK.BuffManager:HasBuff(myHero, "LucianPassiveBuff")
	if hasPassive then
		DoubleShot = true
		Casted = 0
	else
		DoubleShot = false
	end	
	if self.Menu.ComboMode.UseRManKey:Value() then
		_G.SDK.Orbwalker:SetMovement(true)
		_G.SDK.Orbwalker:SetAttack(true)
	end
	self:KS()
	self:Logic()
	if myHero:GetSpellData(_R).toggleState == 1 or not target and myHero.activeSpell.name ~= "LucianQ" then
		--_G.SDK.Orbwalker:SetMovement(true)
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

function Lucian:Draw()
	if self.Menu.Draw.UseDraws:Value() then
		Draw.Circle(myHero.pos, 630, 1, Draw.Color(255, 0, 191, 255))
		if target then
			--PrintChat("drawing R spot")
			if myHero:GetSpellData(_R).toggleState == 1 then
				Direction = Vector((target.pos-myHero.pos):Normalized())
			end
			lhs = Vector(mousePos-myHero.pos)
			dotp = lhs:DotProduct(Direction)
			clicker = -GetDistance(target.pos)+100
			if dotp < 0 then
				clicker = -GetDistance(target.pos)-100
			end
			Location = target.pos + Direction * clicker
			--PrintChat(dotp)
			--Draw.Circle(Location, 55, 1, Draw.Color(255, 0, 191, 255))
		end
	end
end

function Lucian:KS()
	--PrintChat("ksing")
	for i, enemy in pairs(EnemyHeroes) do
		if enemy and not enemy.dead and ValidTarget(enemy, 1000) then
			if self:CanUse(_Q, "KS") and GetDistance(enemy.pos, myHero.pos) > 600 and GetDistance(enemy.pos, myHero.pos) < 1000 and self.Menu.ComboMode.UseQMinion:Value() then
				--PrintChat("ksing 2")
				self:GetQMinion(enemy)
			end
		end
	end
end	

function Lucian:CanUse(spell, mode)
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
		if mode == "KS" and IsReady(spell) and self.Menu.ComboMode.UseQMinion:Value() then
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
	elseif spell == _R then
		if mode == "Combo" and IsReady(spell) and self.Menu.ComboMode.UseR:Value() then
			return true
		end
	end
	return false
end

function Lucian:Logic()
	if target == nil then return end
	if Mode() == "Combo" or Mode() == "Harass" and target then
		if GetDistance(target.pos) < 500 then
			WasInRange = true
		end
		if Casted == 1 then
			if _G.SDK.Orbwalker:CanAttack() then
				--Control.Attack(enemy)
			end
		end
		if self:CanUse(_Q, Mode()) and GetDistance(target.pos, myHero.pos) > 630 and GetDistance(target.pos, myHero.pos) < 1000 and self.Menu.ComboMode.UseQMinionCombo:Value() then
			self:GetQMinion(target)
		end
		--PrintChat(myHero.attackData.state)
		if myHero.attackData.state == 1 then
			--PrintChat("CanAttack ")
		else
			--PrintChat("Can't Attack")
		end
		if self:CanUse(_E, Mode()) and myHero:GetSpellData(_R).toggleState == 1 then
			if GetDistance(target.pos) > 520 then
				if (WasInRange == true or self.Menu.ComboMode.Use3:Value()) and GetDistance(target.pos) < 1050 then
					if GetDistance(mousePos, target.pos) < 500 then
						Control.CastSpell(HK_E, mousePos)
						if _G.PremiumOrbwalker then
							DelayAction(function() _G.PremiumOrbwalker:ResetAutoAttack() end, 0.05)
						elseif _G.SDK then
							DelayAction(function() _G.SDK.Orbwalker:__OnAutoAttackReset() end, 0.05)
						end
					end
				end 
			else
				if myHero.attackData.state == STATE_WINDDOWN and not DoubleShot and (self.Menu.ComboMode.Use2:Value() or not self:CanUse(_W, Mode())) and (self.Menu.ComboMode.Use3:Value() or not self:CanUse(_Q, Mode())) and not _G.SDK.Attack:IsActive() then
					local CloseMouse = mousePos 
					CloseMouse = myHero.pos:Extended(mousePos, 100)
					Control.CastSpell(HK_E, CloseMouse)
					DoubleShot = true
					if _G.PremiumOrbwalker then
						DelayAction(function() _G.PremiumOrbwalker:ResetAutoAttack() end, 0.05)
					elseif _G.SDK then
						DelayAction(function() _G.SDK.Orbwalker:__OnAutoAttackReset() end, 0.05)
					end
					if self.Menu.ComboMode.Use2:Value() then
						Casted = 1
					end
				end
			end
		end
			--PrintChat(myHero.activeSpell.name)
		if _G.SDK.Attack:IsActive() then
			--PrintChat("Attack ACttive")
		end

		local Qrange = 1000 + myHero.boundingRadius + target.boundingRadius
		--PrintChat(range)
		if self:CanUse(_Q, Mode()) and ValidTarget(target, Qrange) and not (myHero.pathing and myHero.pathing.isDashing) and not DoubleShot and myHero.activeSpell.name ~= "LucianQ" and myHero.activeSpell.name ~= "LucianE" and not _G.SDK.Attack:IsActive() then
			if not self.Menu.ComboMode.Use3:Value() or not self:CanUse(_E, Mode()) then
				Control.CastSpell(HK_Q, target)
			end
			--DelayAction(function() self:QClick() end, 0.30)
			--self:QClick()
			--PrintChat(myHero.attackSpeed)
			--DelayAction(function() 	Control.RightClick(mousePos:To2D()) end, 0.05)
			--DelayAction(function() _G.SDK.Orbwalker:__OnAutoAttackReset() end, 0.05)
			if myHero.attackSpeed < 1.40 then
				--PrintChat("cat")
				--DelayAction(function() Control.Move(mousePos) end, 0.75)
			end
			Casted = 1
		end

		if self:CanUse(_W, Mode()) and ValidTarget(target, 900) and not DoubleShot and Casted == 0 and myHero.activeSpell.name ~= "LucianQ" and myHero.activeSpell.name ~= "LucianE" and not _G.SDK.Attack:IsActive() then
			if GetDistance(target.pos, myHero.pos) > 600 or not self:CanUse(_Q, Mode()) then
				if not self.Menu.ComboMode.Use2:Value() or not self:CanUse(_E, Mode()) then
					self:UseW(target)
				end
			end
		end
		--PrintChat(self:GetRDmg(target))
		--PrintChat(target.health)
		if myHero:GetSpellData(_R).toggleState == 2 and target and self.Menu.ComboMode.UseRMagnet:Value() and Mode() == "Combo" then
			--PrintChat("Walking")
			_G.SDK.Orbwalker:SetMovement(false)
			lhs = Vector(mousePos-myHero.pos)
			dotp = lhs:DotProduct(Direction)
			clicker = -GetDistance(target.pos)+100
			if dotp < 0 then
				clicker = -GetDistance(target.pos)-100
			end
			Location = target.pos + Direction * clicker
			if GetDistance(myHero.pos, Location) < self.Menu.ComboMode.rMagnetHeroRange:Value() and GetDistance(mousePos, myHero.pos) < self.Menu.ComboMode.rMagnetMouseRange:Value() then
				Control.Move(Location)
			else
				_G.SDK.Orbwalker:SetMovement(true)
			end
		elseif myHero.activeSpell.name ~= "LucianQ" then
			--_G.SDK.Orbwalker:SetMovement(true)
			Direction = Vector((target.pos-myHero.pos):Normalized())
		end
		if self:CanUse(_R, Mode()) and ValidTarget(target, 1200) and myHero:GetSpellData(_R).toggleState == 1 and target.health < self:GetRDmg(target)*0.8 and GetDistance(target.pos) > 650 then
			self:UseR(target)
		end
	else
		WasInRange = false
    end		
end

function Lucian:QClick()
	local NextSpot = GetUnitPositionNext(myHero)
	local spot = mousePos
	if NextSpot then
		local Direction = Vector((myHero.pos-NextSpot):Normalized())
		spot = myHero.pos - Direction*100
	else
		local Direction = Vector((myHero.pos-target.pos):Normalized())
		--spot = myHero.pos- Direction*100
		--spot = mousePos
		--PrintChat("using hero spot")
	end
	Draw.Circle(mousePos, 50, 1, Draw.Color(255, 0, 191, 255))
	--Control.RightClick(spot:To2D())
	if target then
		Control.Attack(target)
	end
	--DelayAction(function() 	Control.RightClick(target.pos:To2D()) end, 0.05)
end

function Lucian:GetQMinion(unit)
		--PrintChat("Getting Q minion")
		local minions = _G.SDK.ObjectManager:GetEnemyMinions(500)
		local mtarget = nil
		local mlocation = nil
		local manaper = myHero.mana / myHero.maxMana * 100
		if manaper > self.Menu.ComboMode.UseQMana:Value() then
	 		for i = 1, #minions do
	        	local minion = minions[i]
	    		--PrintChat(minion.team)
				if minion.team == 300 - myHero.team and IsValid(minion) then
					--PrintChat("minion")
					if GetDistance(minion.pos, myHero.pos) < 500 then
						if GetDistance(unit.pos, minion.pos) < GetDistance(unit.pos, myHero.pos) then
							CastDirection = Vector((minion.pos-myHero.pos):Normalized())
							enemydist = GetDistance(unit.pos, myHero.pos)
							EnemySpot = myHero.pos:Extended(minion.pos, enemydist)
							Location = EnemySpot
							--Draw.Circle(Location, 55, 1, Draw.Color(255, 0, 191, 255))
							if GetDistance(Location, unit.pos) < 50 then
								if mtarget == nil or GetDistance(Location, unit.pos) < GetDistance(mlocation, unit.pos) then 
									mtarget = minion
									mlocation = Location
								end
							end
						end
					end
				end
			end
		end
		if ValidTarget(mtarget, 500) then
			Control.CastSpell(HK_Q, mtarget)
		end
end

function Lucian:GetRDmg(unit, hits)
	local level = myHero:GetSpellData(_R).level
	local RDmg = getdmg("R", unit, myHero, myHero:GetSpellData(_R).level)
	if hits then
		return RDmg * hits
	else
		return  RDmg * (15 + 5*level)
	end
end


function Lucian:OnPreAttack(args)
end

function Lucian:OnPostAttackTick(args)
	attackedfirst = 1
	if target and Mode() == "Combo" then
		--PrintChat(target.boundingRadius)

	end
end



function Lucian:UseW(unit)
		local pred = _G.PremiumPrediction:GetPrediction(myHero, unit, WSpellData)
		if pred.CastPos and _G.PremiumPrediction.HitChance.Low(pred.HitChance) and myHero.pos:DistanceTo(pred.CastPos) < 900 then
		    	Control.CastSpell(HK_W, pred.CastPos)
		    	Casted = 1
		end 
end

function Lucian:UseR(unit)
		local pred = _G.PremiumPrediction:GetPrediction(myHero, unit, RSpellData)
		if pred.CastPos and _G.PremiumPrediction.HitChance.Medium(pred.HitChance) and myHero.pos:DistanceTo(pred.CastPos) < 1200  then
		    	Control.CastSpell(HK_R, pred.CastPos)
		end 
end

class "Zoe"

local EnemyLoaded = false
local ECastTime = Game:Timer()
local RCastTime = Game:Timer()
local casted = 0
local LastESpot = myHero.pos
local LastE2Spot = myHero.pos
local QCastTime = 0
local attackedfirst = 0
local WasInRange = false
local QRecast = false
local LastHitSpot = myHero.pos
local Direction = myHero.pos

function Zoe:Menu()
	self.Menu = MenuElement({type = MENU, id = "Zoe", name = "Zoe"})
	self.Menu:MenuElement({id = "FarmKey", name = "Farm Key", key = string.byte("Z"), value = false})
	self.Menu:MenuElement({id = "ComboMode", name = "Combo", type = MENU})
	self.Menu.ComboMode:MenuElement({id = "UseQ", name = "Use Q in Combo", value = true})
	self.Menu.ComboMode:MenuElement({id = "UseW", name = "Use W in Combo", value = true})
	self.Menu.ComboMode:MenuElement({id = "UseE", name = "Use smart E in Combo", value = true})
	self.Menu.ComboMode:MenuElement({id = "UseR", name = "Use R in Combo", value = true})
	self.Menu.ComboMode:MenuElement({id = "UseRManKey", name = "Manual R key", key = string.byte("T"), value = false})
	self.Menu.ComboMode:MenuElement({id = "UseRMan", name = "Use R When pressing Manual R key", value = true})
	self.Menu:MenuElement({id = "KSMode", name = "KS", type = MENU})
	self.Menu.KSMode:MenuElement({id = "UseQ", name = "Use Q in KS", value = true})
	self.Menu.KSMode:MenuElement({id = "UseW", name = "Use W in KS", value = true})
	self.Menu.KSMode:MenuElement({id = "UseE", name = "Use smart E in KS", value = true})
	self.Menu.KSMode:MenuElement({id = "UseR", name = "Use R in KS", value = true})
	self.Menu:MenuElement({id = "HarassMode", name = "Harass", type = MENU})
	self.Menu.HarassMode:MenuElement({id = "UseQ", name = "Use Q in Harass", value = true})
	self.Menu.HarassMode:MenuElement({id = "UseW", name = "Use W in Harass", value = true})
	self.Menu.HarassMode:MenuElement({id = "UseE", name = "Use smart E in Harass", value = false})
	self.Menu:MenuElement({id = "Draw", name = "Draw", type = MENU})
	self.Menu.Draw:MenuElement({id = "UseDraws", name = "Enable Draws", value = false})
end

function Zoe:Spells()
	RSpellData = {speed = 3000, range = 575, delay = 0.7, radius = 100, collision = {}, type = "linear"}
	WSpellData = {speed = 1200, range = 800, delay = 0.25, radius = 250, collision = {}, type = "linear"}
	QSpellData = {speed = 1200, range = 3000, delay = 0, radius = 100, collision = {"minion"}, type = "linear"}
	Q2SpellData = {speed = 1200, range = 3000, delay = 0, radius = 100, collision = {"minion"}, type = "circular"}
end


function Zoe:Tick()
	if _G.JustEvade and _G.JustEvade:Evading() or (_G.ExtLibEvade and _G.ExtLibEvade.Evading) or Game.IsChatOpen() or myHero.dead then return end
	--PrintChat(myHero:GetSpellData(_E).name)
	--PrintChat(myHero:GetSpellData(_R).toggleState)
	target = GetTarget(1400)
	if myHero:GetSpellData(_Q).name == "ZoeQRecast" then
		--PrintChat("Casted")
		QRecast = true
		if QCastTime == 0 then
			QCastTime = Game.Timer() + 2
		end
	else
		QCastTime = 0
		QRecast = false
	end
	if QCastTime > 0 then
		--PrintChat(QCastTime - Game.Timer())
	end
	--PrintChat(Game.Latency()/1000)
	self:ManualRCast()
	--self:KS()
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

function Zoe:Draw()
	if self.Menu.Draw.UseDraws:Value() then
		Draw.Circle(myHero.pos, 500, 1, Draw.Color(255, 0, 191, 255))
		--Draw.Circle(LastESpot, 85, 1, Draw.Color(255, 0, 0, 255))
		--Draw.Circle(LastE2Spot, 85, 1, Draw.Color(255, 255, 0, 255))
		if target then
		end
	end
end

function Zoe:ManualRCast()
	if target then
		if self:CanUse(_R, "Manual") and ValidTarget(target, 1300) then
			self:UseR(target)
		end
	else
		for i, enemy in pairs(EnemyHeroes) do
			if enemy and not enemy.dead and ValidTarget(enemy, 550) then
				if self:CanUse(_R, "Manual") and ValidTarget(target, 1300) then
					self:UseR(target)
				end
			end
		end
	end
end

function Zoe:KS()
	--PrintChat("ksing")
	for i, enemy in pairs(EnemyHeroes) do
		if enemy and not enemy.dead and ValidTarget(enemy, 550) then
			local Qrange = 550 + enemy.boundingRadius + myHero.boundingRadius
			local Qdamage = getdmg("Q", enemy, myHero, myHero:GetSpellData(_Q).level) + getdmg("AA", enemy, myHero)
			if self:CanUse(_Q, "KS") and GetDistance(enemy.pos, myHero.pos) > Qrange and self.Menu.KSMode.UseQ:Value() and enemy.health < Qdamage then
				Control.CastSpell(HK_Q, enemy)
			end
		end
	end
end	

function Zoe:CanUse(spell, mode)
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
	elseif spell == _R then
		if mode == "Combo" and IsReady(spell) and self.Menu.ComboMode.UseR:Value() then
			return true
		end
		if mode == "Manual" and IsReady(spell) and self.Menu.ComboMode.UseRMan:Value() and self.Menu.ComboMode.UseRManKey:Value() then
			return true
		end
	end
	return false
end

function Zoe:Logic()
	if target == nil then return end
	if target then
		local AARange = 550 + target.boundingRadius + myHero.boundingRadius
		if GetDistance(target.pos) < AARange then
			WasInRange = true
		end
		if self:CanUse(_Q, Mode()) and ValidTarget(target) then
			if QRecast and QCastTime > 0 then
				local Qleft = QCastTime - Game.Timer()
				if Qleft < 1.08 then
					self:UseQ(target)
				end
			end
		end
		if self:CanUse(_E, Mode()) and ValidTarget(target, 550) then
			self:UseE(target)
		end
		if self:CanUse(_W, Mode()) and ValidTarget(target, 550) then
			Control.CastSpell(HK_W)
		end
		if self:CanUse(_R, Mode()) and ValidTarget(target, 1300) and target.health < self:GetRDmg(target, true) then
			self:UseR(target)
		end
	else
		WasInRange = false
    end		
end

function Zoe:GetRDmg(unit)
	return getdmg("R", unit, myHero, stage, myHero:GetSpellData(_R).level)
end

function Zoe:OnPreAttack(args)
	if target then
	end
end

function Zoe:OnPostAttackTick(args)
	attackedfirst = 1
	if target then
	end
end

function Zoe:UseQ(unit)
		local pred = _G.PremiumPrediction:GetPrediction(myHero, unit, QSpellData)
		if pred.CastPos and _G.PremiumPrediction.HitChance.Low(pred.HitChance) then
		    	Control.CastSpell(HK_Q, pred.CastPos)
		    	LastQSpot = pred.CastPos
		end 
end

function Zoe:UseE(unit)
		local pred = _G.PremiumPrediction:GetPrediction(myHero, unit, ESpellData)
		if pred.CastPos and _G.PremiumPrediction.HitChance.Low(pred.HitChance) and myHero.pos:DistanceTo(pred.CastPos) < 700 then
		    	Control.CastSpell(HK_E, pred.CastPos)
		    	LastESpot = pred.CastPos
		end 
end

function Zoe:UseR(unit)
		local pred = _G.PremiumPrediction:GetPrediction(myHero, unit, RSpellData)
		if pred.CastPos and _G.PremiumPrediction.HitChance.Medium(pred.HitChance) and myHero.pos:DistanceTo(pred.CastPos) < 1300  then
		    	Control.CastSpell(HK_R, pred.CastPos)
		end 
end

class "Draven"

local EnemyLoaded = false
local ECastTime = Game:Timer()
local RCastTime = Game:Timer()
local casted = 0
local Axes = {}, {}, {}
local AxesV2 = {}, {}, {}
local PreStats = {}, {}
local PostStats = {}, {}
local MenuHero = 0
local MenuHeroTime = 0
local MenuTarget = 0
local MenuTargetTime = 0
local MenuStop = 0
local MenuStopTime = 0
local Throws = {}
local PreProc = false
local PostTime = Game.Timer()
local PreTime = Game.Timer()
local GoodEndTimeDif = 1.1
local LastESpot = myHero.pos
local LastE2Spot = myHero.pos
local attackedfirst = 0
local spot = myHero.pos
local WasInRange = false
local BuffOnStick = false
local LastWindup = 0.22
local GlobalTargetAxe = nil
local BackUpTime = Game.Timer()
local CreatedTick = false
local AxeOrbSetMove = true -- Moved from AxeOrb and made global
local HadStacks = 0
local AxeComboModeRange = 550
local HadPassive = false
local Hadpassive2 = false
local AxeHunt = 0
local PostAttacked = false
local HoldingAxe = false
local OneTickSpin = true
local LastCreateTime = -1
local ShowMenuDraws = Game.Timer()
local LastHitSpot = myHero.pos
local Direction = myHero.pos

function Draven:Menu()
	self.Menu = MenuElement({type = MENU, id = "Draven", name = "Draven"})
	self.Menu:MenuElement({id = "FarmKey", name = "Farm Key", key = string.byte("Z"), value = false})
	self.Menu:MenuElement({id = "ComboMode", name = "Combo", type = MENU})
	self.Menu.ComboMode:MenuElement({id = "UseQ", name = "Use Q in Combo", value = true})
	self.Menu.ComboMode:MenuElement({id = "UseW", name = "Use W in Combo", value = true})
	self.Menu.ComboMode:MenuElement({id = "UseE", name = "Use smart E in Combo", value = true})
	self.Menu.ComboMode:MenuElement({id = "UseR", name = "Use R in Combo", value = true})
	self.Menu.ComboMode:MenuElement({id = "AxeOrbHeroRange", name = "Axe Catch Range From Hero (700)", value = 650, min = 100, max = 1200, step = 50})
	self.Menu.ComboMode:MenuElement({id = "AxeOrbStopRange", name = "Stop Moving To Axe Range From Axe (80)", value = 80, min = 0, max = 500, step = 10})
	self.Menu.ComboMode:MenuElement({id = "AxeOrbModeCombo", name = "In fights catch based on target", value = true})
	self.Menu.ComboMode:MenuElement({id = "AxeOrbTargetRange", name = "Fight Axe Catch Range From Target (900)", value = 900, min = 100, max = 1200, step = 50})
	self.Menu.ComboMode:MenuElement({id = "UseRManKey", name = "Manual R key", key = string.byte("T"), value = false})
	self.Menu.ComboMode:MenuElement({id = "UseRMan", name = "Use R When pressing Manual R key", value = true})
	self.Menu:MenuElement({id = "KSMode", name = "KS", type = MENU})
	self.Menu.KSMode:MenuElement({id = "UseQ", name = "Use Q in KS", value = true})
	self.Menu.KSMode:MenuElement({id = "UseW", name = "Use W in KS", value = true})
	self.Menu.KSMode:MenuElement({id = "UseE", name = "Use smart E in KS", value = true})
	self.Menu.KSMode:MenuElement({id = "UseR", name = "Use R in KS", value = true})
	self.Menu:MenuElement({id = "HarassMode", name = "Harass", type = MENU})
	self.Menu.HarassMode:MenuElement({id = "UseQ", name = "Use Q in Harass", value = true})
	self.Menu.HarassMode:MenuElement({id = "UseW", name = "Use W in Harass", value = true})
	self.Menu.HarassMode:MenuElement({id = "UseE", name = "Use smart E in Harass", value = false})
	self.Menu:MenuElement({id = "Draw", name = "Draw", type = MENU})
	self.Menu.Draw:MenuElement({id = "UseDraws", name = "Enable Draws", value = false})
end

function Draven:MenuManager()
	--PrintChat("Errr")
	if self.Menu.ComboMode.AxeOrbHeroRange:Value() ~= MenuHero then
		--PrintChat("Changed Menu")
		MenuHeroTime = Game.Timer() + 2
	end
	if self.Menu.ComboMode.AxeOrbTargetRange:Value() ~= MenuStop then
		--PrintChat("Changed Menu")
		MenuStopTime  = Game.Timer() + 2
	end
	if self.Menu.ComboMode.AxeOrbStopRange:Value() ~= MenuTarget then
		--PrintChat("Changed Menu")
		MenuTargetTime = Game.Timer() + 2
	end

	MenuHero = self.Menu.ComboMode.AxeOrbHeroRange:Value()
	MenuStop = self.Menu.ComboMode.AxeOrbTargetRange:Value()
	MenuTarget = self.Menu.ComboMode.AxeOrbStopRange:Value()
	--PrintChat(MenuRanges[1].range)
	--PrintChat(MenuRanges[1].time)
end

function Draven:Spells()
	RSpellData = {speed = 2000, range = 3000, delay = 0.25, radius = 160, collision = {}, type = "linear"}
	ESpellData = {speed = 1400, range = 1050, delay = 0.25, radius = 100, collision = {}, type = "linear"}
end


function Draven:Tick()
	--PrintChat(" ")
	if _G.JustEvade and _G.JustEvade:Evading() or (_G.ExtLibEvade and _G.ExtLibEvade.Evading) or Game.IsChatOpen() or myHero.dead then return end
	target = GetTarget(3000)
	HoldingAxe = _G.SDK.BuffManager:GetBuff(myHero, "DravenSpinning") or _G.SDK.BuffManager:GetBuff(myHero, "DravenSpinningAttack")
	SecondRBuff = _G.SDK.BuffManager:GetBuff(myHero, "dravenrdoublecast")
	WBuffAS = _G.SDK.BuffManager:GetBuff(myHero, "dravenfurybuff")
	WBuffMS = _G.SDK.BuffManager:GetBuff(myHero, "DravenFury")
	--self:CreateAxeDelay(0.5)
	--self:DeleteAxes()
	--self:CreateAxes()
	--PrintChat(" ")
	self:MenuManager()
	if self.Menu.ComboMode.UseRManKey:Value() then
		self:DirectAxe()
	end
	self:DeleteAxes()
	self:AxeOrb()
	self:ManualRCast()
	self:Logic()
	self:KS()
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

function Draven:Logic()
	if target == nil then return end
	if Mode() == "Combo" or Mode() == "Harass" and target then
		local AARange = 550 + target.boundingRadius + myHero.boundingRadius
		if GetDistance(target.pos) < AARange then
			WasInRange = true
		end
		if self:CanUse(_Q, Mode()) and ValidTarget(target, 550) then
			--Control.CastSpell(HK_Q)
		end
		if self:CanUse(_E, Mode()) and ValidTarget(target, 550) and not AxeOrbSetMove then
			self:UseE(target)
		end
		if self:CanUse(_W, Mode()) then
			Control.CastSpell(HK_W)
		end
		if self:CanUse(_R, Mode()) and ValidTarget(target, 3000) and target.health < self:GetRDmg(target, true) * 1.8 and not SecondRBuff then
			self:UseR(target)
		end
	else
		WasInRange = false
    end		
end

function Draven:Draw()
	if self.Menu.Draw.UseDraws:Value() then
		--Draw.Circle(myHero.pos, 500, 1, Draw.Color(255, 0, 191, 255))
		--Draw.Circle(LastESpot, 85, 1, Draw.Color(255, 0, 0, 255))
		--Draw.Circle(LastE2Spot, 85, 1, Draw.Color(255, 255, 0, 255))
		--Draw.Circle(mousePos, 550, 1, Draw.Color(255, 0, 191, 255))
		if GlobalTargetAxe then
			if target then
				local NextSpot = GetUnitPositionNext(target)
				if NextSpot then
					local Direction = Vector((target.pos-NextSpot):Normalized())
					local Time = GlobalTargetAxe.endTime - Game.Timer()
					local Distance = target.ms * Time
					local Spot = target.pos - Direction*Distance
				else
					local spot = target.pos
				end
				Draw.Circle(spot, 150, 1, Draw.Color(255, 255, 255, 255)) 
			end
		end
		if MenuHeroTime - Game.Timer() > 0 then
			Draw.Circle(myHero.pos, MenuHero, 1, Draw.Color(255, 0, 191, 255))
		end
		if MenuStopTime - Game.Timer() > 0 then
			Draw.Circle(myHero.pos, MenuStop, 1, Draw.Color(255, 0, 191, 255))
		end
		if MenuTargetTime - Game.Timer() > 0 then
			Draw.Circle(myHero.pos, MenuTarget, 1, Draw.Color(255, 0, 191, 255))
		end
		--Direction = Vector((myHero.pos-mousePos):Normalized())
		--spot = myHero.pos - Direction*100
		--Draw.Circle(spot, 150, 1, Draw.Color(255, 255, 0, 255))
		for i = 1, #Axes do
			local Axe = Axes[i]
			if Axe then	
				--PrintChat(Axe.endTime)
				Draw.Circle(Axe.pos, 150, 1, Draw.Color(255, 255, 0, 255))
			end
		end
		--[[if #Axes > 0 then
			local timediff = Axes[1].endTime - Game.Timer()
			local MaxDistance = myHero.ms * timediff
			Draw.Circle(myHero.pos, MaxDistance*0.8, 1, Draw.Color(255, 255, 0, 255))
			if GetDistance(Axes[1].pos, myHero.pos) > MaxDistance * 0.5 then
			end
		end--]]
		--Draw.Circle(spot, myHero.boundingRadius, 1, Draw.Color(192, 65, 105, 225))


	end
end

function Draven:AxeOrb()
	if #Axes <= 0 then 
		_G.SDK.Orbwalker:SetMovement(true)
		_G.SDK.Orbwalker:SetAttack(true)
		return false
	end 
	local NearTurret = IsNearEnemyTurret(myHero.pos, 600)
	local UnderTurret = IsUnderEnemyTurret(myHero.pos)
	local AxeComboMode = self.Menu.ComboMode.AxeOrbModeCombo:Value()
 	local TargetAxe = nil
	local SmallRange = self.Menu.ComboMode.AxeOrbStopRange:Value()
 	for i = 1, #Axes do
        local Axe = Axes[i]
        if Axe then
        	local AxeTime = Axe.endTime - Game.Timer()
			local AxeMaxDistance = myHero.ms * AxeTime
        	if GetDistance(Axe.pos, myHero.pos) < AxeMaxDistance then
        		if not IsNearEnemyTurret(Axe.pos, 0) or IsUnderEnemyTurret(myHero.pos) then
	        		if AxeComboMode and target and Mode() == "Combo" then
        				PredSpot = GetUnitPositionNext(target)
        				if PredSpot then
        					PredDirection = Vector((target.pos-PredSpot):Normalized())
        					Distance = target.ms * AxeTime
        					spot = target.pos - PredDirection*Distance
        				else
        					spot = target.pos
        				end
        				if GetDistance(spot, Axe.pos) < self.Menu.ComboMode.AxeOrbTargetRange:Value() then -- changed to spot, was target.pos might break
        					TargetAxe = Axe
        					break
        				end
	        		else
	        			if GetDistance(Axe.pos, myHero.pos) < self.Menu.ComboMode.AxeOrbHeroRange:Value() then
	        				TargetAxe = Axe
	        				break
	        			else
	        				if self:CanUse(_W, "Orb") and ValidTarget(target, 850) then
								Control.CastSpell(HK_W)
							end
	        			end
	        		end
        		end
        	end
        end
    end
	if TargetAxe then
		GlobalTargetAxe = TargetAxe
		--PrintChat("We're on baby")
		--PrintChat(#Axes)
		local Time = TargetAxe.endTime - Game.Timer()
		local MaxDistance = myHero.ms * Time
		local ActualDistance = GetDistance(TargetAxe.pos, myHero.pos)
		if ActualDistance < MaxDistance then
			--PrintChat(ActualDistance)
			--PrintChat("Orb orb axe")
			if ActualDistance > SmallRange then
				--PrintChat("greater than 150")
				_G.SDK.Orbwalker:SetMovement(false)
				_G.SDK.Orbwalker:SetAttack(false)
				AxeOrbSetMove = true
			end
			if ActualDistance < SmallRange then
				--PrintChat("Closer than 150")
				_G.SDK.Orbwalker:SetAttack(true)
				Direction = Vector((TargetAxe.pos-mousePos):Normalized())
				spot = TargetAxe.pos - Direction*SmallRange 
				if not _G.SDK.Attack:IsActive() then
					Control.Move(spot)
				end
				--_G.SDK.Orbwalker:SetMovement(true)
				AxeOrbSetMove = false
			elseif ActualDistance > MaxDistance * 0.5 then
				--PrintChat("greater than 0.8")
				_G.SDK.Orbwalker:SetAttack(false)
				AxeOrbSetMove = true
			end
			if AxeOrbSetMove and not _G.SDK.Attack:IsActive() then
				--PrintChat("moving")
				Control.Move(TargetAxe.pos)
				DrawAxe = TargetAxe
			end
			return true
		else
			_G.SDK.Orbwalker:SetMovement(true)
			_G.SDK.Orbwalker:SetAttack(true)
			return false
		end
	else
		GlobalTargetAxe = nil
		--if #Axes < 1 then
			_G.SDK.Orbwalker:SetMovement(true)
		--end
		_G.SDK.Orbwalker:SetAttack(true)
		return false
	end
end

function Draven:DeleteAxes()
    table.sort(Axes, function(a, b) return GetDistance(a.pos) < GetDistance(b.pos) end)
    for i = 1, #Axes do
        local object = Axes[i]
        if object and (object.endTime - Game.Timer() >= 0 and GetDistance(object.obj.pos, object.pos) > 10) then
            --DrawText(i, 48, object.pos:ToScreen(), DrawColor(255, 0, 255, 0))
        else
            table.remove(Axes, i)
        end
    end
end

function Draven:CreateAxes()
	if CreatedTick then return end
	self:DeleteAxes()
	--PrintChat("Creating Axes")
	local count = Game.MissileCount()
	--PrintChat()
	if #PostStats > 0 then 
		local FirstPostSpin = PostStats[#PostStats].Spin
		local FirstPostTime = PostStats[#PostStats].Time
	end
	if #PreStats > 0 then
		local FirstPreSpin = PreStats[#PreStats].Spin
		local PreTime = PreStats[#PreStats].Time
	end
	for i = count, 1, -1 do
		local missile = Game.Missile(i)
		local data = missile.missileData
		if data and data.owner == myHero.handle and data.name == "DravenSpinningReturn" and not self:CheckAxe(missile) then
			--PrintChat("Creating a timed axe")
			local BestEndTime = Game.Timer() + 0.7
			if FirstPostSpin and not FirstPreSpin then
				BestEndTime = FirstPostTime
				--PrintChat("Create Post Timed Axe")
				FirstPostSpin = false
			elseif FirstPreSpin then
				BestEndTime = PreTime - LastWindup
				--PrintChat("Create Pre Timed Axe")
				--PrintChat(BestEndTime - Game.Timer())
				FirstPreSpin = false
			elseif GoodEndTimeDif then
				--PrintChat("With Good End Time")
				BestEndTime = Game.Timer() + GoodEndTimeDif
			end
			if BestEndTime - Game.Timer() > 0.3 then
				GoodEndTimeDif = BestEndTime - Game.Timer()
			end
			--PrintChat(GoodEndTimeDif)
			local MaxDistance = myHero.ms * GoodEndTimeDif
			if GetDistance(myHero.pos, Vector(missile.missileData.endPos)) < MaxDistance then
				--PrintChat(MaxDistance)
			end
			BestEndTime = Game.Timer() + GoodEndTimeDif
			if BestEndTime - Game.Timer() > 0 then
				--PrintChat("Created Axe")
				table.insert(Axes, 1, {endTime = BestEndTime, ID = missile.handle, pos = Vector(missile.missileData.endPos), obj = missile}) --its always 1.1 seconds (missile speed changes based on distance)
				table.remove(PostStats, #PostStats)
				--PrintChat("Removing PreStats")
				--PrintChat(#PreStats)
				table.remove(PreStats, #PreStats)
				--PrintChat(#PreStats)
				CreatedTick = true
			end
			return true
		end
	end
	self:DeleteAxes()
end


function Draven:CheckAxe(obj)
	for i = 1, #Axes do
		if Axes[i].ID == obj.handle then
			return true
		end
	end
end

function Draven:OnPreAttack(args)
	Pre = true
	if self:CanUse(_Q, Mode()) and target then
		Control.CastSpell(HK_Q)
	end
	hasPassive = _G.SDK.BuffManager:GetBuff(myHero, "DravenSpinning") or _G.SDK.BuffManager:GetBuff(myHero, "DravenSpinningAttack")
	if hasPassive then
		PreSpin = true
		PreTime = Game.Timer() + 2
		--PrintChat("inserted both tables")
		--PrintChat(#PreStats)
		table.insert(PreStats, 1, {Spin = PreSpin, Time = PreTime})
		--PrintChat(#PreStats)
		table.insert(PostStats, 1, {Spin = true, Time = 1337})
	end
	local Timer = 0.5
	--PrintChat(Timer)
	for i=1,5,1 do
		--PrintChat(i)
		DelayAction(function() self:CreateAxes() end, Timer+ i * 0.10)
	end
	CreatedTick = false
end

function Draven:OnPostAttackTick(args)
	if myHero.activeSpell.name == "DravenSpinningAttack" or myHero.activeSpell.name == "DravenSpinningAttack2" then
		LastWindup = myHero.activeSpell.windup
		PostSpin = true
		PostTime = Game.Timer() + 1.8 - LastWindup
		for i = 1, #PostStats do
        	local PostSession = PostStats[i]
        	if PostSession.Time == 1337 then
        		PostStats[i].Spin = PostSpin
        		PostStats[i].Time = PostTime
        	end
        end
	end
end

function Draven:CreateAxeDelay(delay)
	if LastCreateTime + delay - Game.Timer() < 0 and Mode() == "Combo" then
		--PrintChat("Create Axe at a delay")
		LastCreateTime = Game.Timer()
		self:CreateAxes()
	end
	-- body
end

function Draven:DirectAxe()
	--PrintChat("----------------------------------")
	Direction = Vector((myHero.pos-mousePos):Normalized())
	if target then
		Direction = Vector((myHero.pos-target.pos):Normalized())
	end
	spot = myHero.pos - Direction*100
	Control.Move(spot)
	--PrintChat("Directing")
end


function Draven:ManualRCast()
	if target then
		if self:CanUse(_R, "Manual") and ValidTarget(target, 1300) then
			self:UseR(target)
		end
	else
		for i, enemy in pairs(EnemyHeroes) do
			if enemy and not enemy.dead and ValidTarget(enemy, 550) then
				if self:CanUse(_R, "Manual") and ValidTarget(target, 1300) then
					self:UseR(target)
				end
			end
		end
	end
end

function Draven:KS()
	--PrintChat("ksing")
	for i, enemy in pairs(EnemyHeroes) do
		if enemy and not enemy.dead and ValidTarget(enemy, 550) then
			local Edamage = getdmg("E", enemy, myHero, myHero:GetSpellData(_E).level)
			if self:CanUse(_E, "KS") and GetDistance(enemy.pos, myHero.pos) < ESpellData.range and enemy.health < Edamage then
				self:UseE(enemy)
			end
			if self:CanUse(_R, "KS") and ValidTarget(enemy, 3000) and enemy.health < self:GetRDmg(enemy) * 1.8 and not SecondRBuff and GetDistance(enemy.pos, myHero.pos) > 650 then
				self:UseR(target)
			end
		end
	end
end	

function Draven:CanUse(spell, mode)
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
		if mode == "Manual" and IsReady(spell) and self.Menu.ComboMode.UseRMan:Value() and self.Menu.ComboMode.UseRManKey:Value() then
			return true
		end
		if mode == "KS" and IsReady(spell) and self.Menu.KSMode.UseR:Value() then
			return true
		end
	end
	return false
end

function Draven:GetRDmg(unit)
	return getdmg("R", unit, myHero, stage, myHero:GetSpellData(_R).level)
end


function Draven:UseE(unit)
	local pred = _G.PremiumPrediction:GetPrediction(myHero, unit, ESpellData)
	if pred.CastPos and _G.PremiumPrediction.HitChance.Low(pred.HitChance) and myHero.pos:DistanceTo(pred.CastPos) < 700 then
	    	Control.CastSpell(HK_E, pred.CastPos)
	end 
end

function Draven:UseR(unit)
	if not SecondRBuff then
		local pred = _G.PremiumPrediction:GetPrediction(myHero, unit, RSpellData)
		if pred.CastPos and _G.PremiumPrediction.HitChance.Medium(pred.HitChance) and myHero.pos:DistanceTo(pred.CastPos) < 3000 then
			Direction = Vector((myHero.pos-pred.CastPos):Normalized())
			Spot = myHero.pos - Direction * 700
	    	Control.CastSpell(HK_R, Spot)
	    	local SecondRTime = GetDistance(myHero.pos, unit.pos) / 2000
			DelayAction(function() self:UseR2() end, SecondRTime-0.2)
		end
	end 
end

function Draven:UseR2()
	if IsReady(_R) then
		Control.CastSpell(HK_R) 
		--PrintChat("casting second R")
	end
end

class "Teemo"

local EnemyLoaded = false
local ECastTime = Game:Timer()
local RCastTime = Game:Timer()
local casted = 0
local LastESpot = myHero.pos
local LastE2Spot = myHero.pos
local attackedfirst = 0
local WasInRange = false

function Teemo:Menu()
	self.Menu = MenuElement({type = MENU, id = "Teemo", name = "Teemo"})
	self.Menu:MenuElement({id = "FarmKey", name = "Farm Key", key = string.byte("Z"), value = false})
	self.Menu:MenuElement({id = "ComboMode", name = "Combo", type = MENU})
	self.Menu.ComboMode:MenuElement({id = "UseQ", name = "Use Q in Combo", value = true})
	self.Menu:MenuElement({id = "KSMode", name = "KS", type = MENU})
	self.Menu.KSMode:MenuElement({id = "UseQ", name = "Use Q in KS", value = true})
	self.Menu:MenuElement({id = "HarassMode", name = "Harass", type = MENU})
	self.Menu.HarassMode:MenuElement({id = "UseQ", name = "Use Q in Harass", value = true})
	self.Menu:MenuElement({id = "Draw", name = "Draw", type = MENU})
	self.Menu.Draw:MenuElement({id = "UseDraws", name = "Enable Draws", value = false})
end

function Teemo:Spells()
	RSpellData = {speed = 1300, range = 1300, delay = 0.25, radius = 70, collision = {}, type = "linear"}
	ESpellData = {speed = 1300, range = 700, delay = 0.25, radius = 20, collision = {}, type = "linear"}
	E2SpellData = {speed = 3000, range = 470, delay = 0.45, radius = 200, collision = {}, type = "circular"}
end

function Teemo:Tick()
	if _G.JustEvade and _G.JustEvade:Evading() or (_G.ExtLibEvade and _G.ExtLibEvade.Evading) or Game.IsChatOpen() or myHero.dead then return end
	--PrintChat(myHero:GetSpellData(_E).name)
	--PrintChat(myHero:GetSpellData(_R).toggleState)
	--PrintChat(myHero.activeSpell.name)
	ActiveSpell = myHero.activeSpell.name
	target = GetTarget(1400)
	self:KS()
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

function Teemo:Draw()
	if self.Menu.Draw.UseDraws:Value() then
		local AARange = 590
		Draw.Circle(myHero.pos, AARange, 1, Draw.Color(255, 0, 191, 255))
		Draw.Circle(myHero.pos, 680, 1, Draw.Color(255, 0, 191, 255))
		--Draw.Circle(LastESpot, 85, 1, Draw.Color(255, 0, 0, 255))
		--Draw.Circle(LastE2Spot, 85, 1, Draw.Color(255, 255, 0, 255))
		if target then
		end
	end
end

function Teemo:KS()
	--PrintChat("ksing")
	for i, enemy in pairs(EnemyHeroes) do
		if enemy and not enemy.dead and ValidTarget(enemy) then
			local Qrange = 680
			local Qdamage = getdmg("Q", enemy, myHero, myHero:GetSpellData(_Q).level)
			if self:CanUse(_Q, "KS") and GetDistance(enemy.pos, myHero.pos) < Qrange and self.Menu.KSMode.UseQ:Value() and enemy.health < Qdamage and ActiveSpell ~= "BlindingDart" then
				Control.CastSpell(HK_Q, enemy)
			end
		end
	end
end	

function Teemo:CanUse(spell, mode)
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
	elseif spell == _R then
		if mode == "Combo" and IsReady(spell) and self.Menu.ComboMode.UseR:Value() then
			return true
		end
		if mode == "Manual" and IsReady(spell) and self.Menu.ComboMode.UseRMan:Value() and self.Menu.ComboMode.UseRManKey:Value() then
			return true
		end
	end
	return false
end

function Teemo:Logic()
	--PrintChat(ActiveSpell)
	if target == nil then return end
	if Mode() == "Combo" or Mode() == "Harass" and target then
		local AARange = 590
		if GetDistance(target.pos) < AARange then
			WasInRange = true
		end
		local Qrange = 680 
		if self:CanUse(_Q, Mode()) and ValidTarget(target, Qrange) and GetDistance(target.pos, myHero.pos) > AARange and ActiveSpell ~= "BlindingDart" then
			Control.CastSpell(HK_Q, target)
		end
	else
		WasInRange = false
    end		
end

function Teemo:OnPostAttackTick(args)
	attackedfirst = 1
	if target then
		local Qrange = 680 + target.boundingRadius + myHero.boundingRadius
		if self:CanUse(_Q, Mode()) and ValidTarget(target, Qrange) and ActiveSpell ~= "BlindingDart" then
			Control.CastSpell(HK_Q, target)
		end
	end
end


function Teemo:GetRDmg(unit)
	return getdmg("R", unit, myHero, stage, myHero:GetSpellData(_R).level)
end

function Teemo:OnPreAttack(args)
	if target then
	end
end

function Teemo:UseE(unit)
		local pred = _G.PremiumPrediction:GetPrediction(myHero, unit, ESpellData)
		if pred.CastPos and _G.PremiumPrediction.HitChance.Low(pred.HitChance) and myHero.pos:DistanceTo(pred.CastPos) < 700 then
		    	Control.CastSpell(HK_E, pred.CastPos)
		    	LastESpot = pred.CastPos
		end 
end

function Teemo:UseR(unit)
		local pred = _G.PremiumPrediction:GetPrediction(myHero, unit, RSpellData)
		if pred.CastPos and _G.PremiumPrediction.HitChance.Medium(pred.HitChance) and myHero.pos:DistanceTo(pred.CastPos) < 1300  then
		    	Control.CastSpell(HK_R, pred.CastPos)
		end 
end

class "Fizz"

local EnemyLoaded = false
local ECastTime = Game:Timer()
local RCastTime = Game:Timer()
local casted = 0
local LastESpot = myHero.pos
local LastE2Spot = myHero.pos
local attackedfirst = 0
local WasInRange = false
local BuffOnStick = false
local LastHitSpot = myHero.pos
local Direction = myHero.pos

function Fizz:Menu()
	self.Menu = MenuElement({type = MENU, id = "Fizz", name = "Fizz"})
	self.Menu:MenuElement({id = "FarmKey", name = "Farm Key", key = string.byte("Z"), value = false})
	self.Menu:MenuElement({id = "ComboMode", name = "Combo", type = MENU})
	self.Menu.ComboMode:MenuElement({id = "UseQ", name = "Use Q in Combo", value = true})
	self.Menu.ComboMode:MenuElement({id = "UseW", name = "Use W in Combo", value = true})
	self.Menu.ComboMode:MenuElement({id = "UseE", name = "Use smart E in Combo", value = true})
	self.Menu.ComboMode:MenuElement({id = "UseR", name = "Use R in Combo", value = true})
	self.Menu.ComboMode:MenuElement({id = "UseRManKey", name = "Manual R key", key = string.byte("T"), value = false})
	self.Menu.ComboMode:MenuElement({id = "UseRMan", name = "Use R When pressing Manual R key", value = true})
	self.Menu:MenuElement({id = "KSMode", name = "KS", type = MENU})
	self.Menu.KSMode:MenuElement({id = "UseQ", name = "Use Q in KS", value = true})
	self.Menu.KSMode:MenuElement({id = "UseW", name = "Use W in KS", value = true})
	self.Menu.KSMode:MenuElement({id = "UseE", name = "Use smart E in KS", value = true})
	self.Menu.KSMode:MenuElement({id = "UseR", name = "Use R in KS", value = true})
	self.Menu:MenuElement({id = "HarassMode", name = "Harass", type = MENU})
	self.Menu.HarassMode:MenuElement({id = "UseQ", name = "Use Q in Harass", value = true})
	self.Menu.HarassMode:MenuElement({id = "UseW", name = "Use W in Harass", value = true})
	self.Menu.HarassMode:MenuElement({id = "UseE", name = "Use smart E in Harass", value = false})
	self.Menu:MenuElement({id = "Draw", name = "Draw", type = MENU})
	self.Menu.Draw:MenuElement({id = "UseDraws", name = "Enable Draws", value = false})
end

function Fizz:Spells()
	RSpellData = {speed = 1300, range = 1300, delay = 0.25, radius = 70, collision = {}, type = "linear"}
	ESpellData = {speed = 1300, range = 700, delay = 0.25, radius = 20, collision = {}, type = "linear"}
	E2SpellData = {speed = 3000, range = 470, delay = 0.45, radius = 200, collision = {}, type = "circular"}
end


function Fizz:LastHit()
	local AARange = 175 + myHero.boundingRadius
	local mtarget = nil
	local dmg = 0
	local Minions = _G.SDK.ObjectManager:GetEnemyMinions(AARange)
	if IsReady(_W) or not (Mode() == "Harass" or Mode() == "LaneClear" or Mode() == "LastHit") then
		for i = 1, #Minions do
			local minion = Minions[i]
			if IsReady(_W) then
				dmg = getdmg("W", minion, myHero, myHero:GetSpellData(_W).level) + getdmg("AA", minion, myHero)
				AARange = 225 + myHero.boundingRadius
			else
				dmg = getdmg("AA", minion, myHero)
			end
			if minion.health < dmg then
				if mtarget == nil or minion.health < mtarget.health then
					mtarget = minion
				end			
			end
		end
		if mtarget and ValidTarget(mtarget, AARange) then
				wtfattack(mtarget)
		elseif not Mode() == "Harass" and not Mode() == "LaneClear" and not Mode() == "Combo" then
			_G.SDK.Orbwalker:Move()
		end
	end
end

function wtfattack(unit)
	if IsReady(_W) then
		Control.CastSpell(HK_W)
	end
	DelayAction(function() Control.Attack(unit) end, 0.05)
end

function Fizz:Tick()
	if _G.JustEvade and _G.JustEvade:Evading() or (_G.ExtLibEvade and _G.ExtLibEvade.Evading) or Game.IsChatOpen() or myHero.dead then return end
	--PrintChat(myHero:GetSpellData(_E).name)
	--PrintChat(myHero:GetSpellData(_R).toggleState)
	target = GetTarget(1400)
	if myHero:GetSpellData(_E).name == "FizzETwo" or myHero:GetSpellData(_E).name == "FizzEBuffer"  then
		BuffOnStick = true
	elseif myHero:GetSpellData(_E).name == "FizzE" then
		BuffOnStick = false
	end
	self:ManualRCast()
	self:KS()
	if self.Menu.FarmKey:Value() then
		self:LastHit()

	end
	self:Logic()
	if BuffOnStick then
		_G.SDK.Orbwalker:SetMovement(false)
		_G.SDK.Orbwalker:SetAttack(false)
	else
		_G.SDK.Orbwalker:SetMovement(true)
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

function Fizz:Draw()
	if self.Menu.Draw.UseDraws:Value() then
		Draw.Circle(myHero.pos, 500, 1, Draw.Color(255, 0, 191, 255))
		--Draw.Circle(LastESpot, 85, 1, Draw.Color(255, 0, 0, 255))
		--Draw.Circle(LastE2Spot, 85, 1, Draw.Color(255, 255, 0, 255))
		if target then
		end
	end
end

function Fizz:ManualRCast()
	if target then
		if self:CanUse(_R, "Manual") and ValidTarget(target, 1300) then
			self:UseR(target)
		end
	else
		for i, enemy in pairs(EnemyHeroes) do
			if enemy and not enemy.dead and ValidTarget(enemy, 550) then
				if self:CanUse(_R, "Manual") and ValidTarget(target, 1300) then
					self:UseR(target)
				end
			end
		end
	end
end

function Fizz:KS()
	--PrintChat("ksing")
	for i, enemy in pairs(EnemyHeroes) do
		if enemy and not enemy.dead and ValidTarget(enemy, 550) then
			local Qrange = 550 + enemy.boundingRadius + myHero.boundingRadius
			local Qdamage = getdmg("Q", enemy, myHero, myHero:GetSpellData(_Q).level) + getdmg("AA", enemy, myHero)
			if self:CanUse(_Q, "KS") and GetDistance(enemy.pos, myHero.pos) > Qrange and self.Menu.KSMode.UseQ:Value() and enemy.health < Qdamage then
				Control.CastSpell(HK_Q, enemy)
			end
		end
	end
end	

function Fizz:CanUse(spell, mode)
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
	elseif spell == _R then
		if mode == "Combo" and IsReady(spell) and self.Menu.ComboMode.UseR:Value() then
			return true
		end
		if mode == "Manual" and IsReady(spell) and self.Menu.ComboMode.UseRMan:Value() and self.Menu.ComboMode.UseRManKey:Value() then
			return true
		end
	end
	return false
end

function Fizz:Logic()
	if target == nil then return end
	if Mode() == "Combo" or Mode() == "Harass" and target then
		local AARange = 175 + target.boundingRadius + myHero.boundingRadius
		local TotalDamage = self:GetTotalDamage(target)
		if GetDistance(target.pos) < 550 then
			WasInRange = true
		end
		if GetDistance(target.pos) < AARange then
			WasInRange = true
		elseif GetDistance(target.pos) < AARange+50 and self:CanUse(_W, Mode()) and not self:CanUse(_Q, Mode()) and not self:CanUse(_E, Mode()) then
			Control.CastSpell(HK_W)
		end
		if self:CanUse(_Q, Mode()) and ValidTarget(target, 550) then
			if GetDistance(target.pos, myHero.pos) < AARange then
				if casted == 0 and not self:CanUse(_W, Mode()) and not self:CanUse(_E, Mode()) then
					Control.CastSpell(HK_Q, target)
				end
			else
				Control.CastSpell(HK_Q, target)
				if self:CanUse(_W, Mode()) then
					Control.CastSpell(HK_W)
				end
			end
		end
		if self:CanUse(_E, Mode()) and ValidTarget(target, 700) then
			if BuffOnStick and myHero:GetSpellData(_E).name == "FizzETwo" then
				if ValidTarget(target, 470) then
					--PrintChat("EEE")
					self:UseE2(target)
				end
			elseif myHero:GetSpellData(_E).name == "FizzE" then
				--PrintChat("AAA")
				if IsUnderEnemyTurret(target.pos) then
					--PrintChat("under")
					if not self:CanUse(_Q, Mode()) then
						if GetDistance(target.pos, myHero.pos) < AARange then
							if casted == 0 and not self:CanUse(_W, Mode()) then
								self:UseE(target)
							end
						else
							self:UseE(target)
						end
					end
				else
					--PrintChat("Not under")
					if GetDistance(target.pos, myHero.pos) < AARange then
						if casted == 0 and not self:CanUse(_W, Mode()) then
							self:UseE(target)
						end
					elseif GetDistance(target.pos, myHero.pos) < 550 then
						if not self:CanUse(_Q, Mode()) then
							self:UseE(target)
						end
					else
						self:UseE(target)	
					end
				end
			end
		end
		if self:CanUse(_R, Mode()) and ValidTarget(target, 1300) and target.health < self:GetTotalDamage(target, true) and target.health > self:GetTotalDamage(target, false) then
			self:UseR(target)
		end
	else
		WasInRange = false
    end		
end

function Fizz:GetRDmg(unit)
	local stage = 3
	if GetDistance(unit.pos, myHero.pos) < 455 then
		stage = 1
	elseif GetDistance(unit.pos, myHero.pos) < 910 then
		stage = 2
	end
	return getdmg("R", unit, myHero, stage, myHero:GetSpellData(_R).level)
end

function Fizz:GetTotalDamage(unit, ult)
	local QD = 0
	local WD = 0
	local ED = 0
	local RD = 0
	local Crange = 550
	local CRrange = 750
	local TD = 0
	if IsReady(_R) and GetDistance(unit.pos, myHero.pos) < 1300 then
		RD = self:GetRDmg(unit)
		Crange = 1300
		CRrange = 1300
	end
	if IsReady(_E) or BuffOnStick and GetDistance(unit.pos, myHero.pos) < CRrange then
		ED = getdmg("E", unit, myHero, myHero:GetSpellData(_E).level)
		if not IsReady(_R) then
			Crange = 700
		end
	end
	if IsReady(_Q) and GetDistance(unit.pos, myHero.pos) < Crange then
		QD = getdmg("Q", unit, myHero, myHero:GetSpellData(_Q).level) + getdmg("AA", unit, myHero)
	end
	if IsReady(_W) and GetDistance(unit.pos, myHero.pos) < Crange then
		WD = getdmg("W", unit, myHero, myHero:GetSpellData(_W).level) * 2 + getdmg("AA", unit, myHero)
	end
	if ult then
		TD = QD + WD + ED + RD
	else
		TD = QD + WD + ED
	end
	return TD
end

function Fizz:OnPreAttack(args)
end

function Fizz:OnPostAttackTick(args)
	attackedfirst = 1
	if target then
		if self:CanUse(_W, Mode()) and ValidTarget(target, 225) then
			Control.CastSpell(HK_W)
			casted = 1
			_G.SDK.Orbwalker:__OnAutoAttackReset()
		else
			--PrintChat("casted")
			casted = 0
		end
	end
end

function Fizz:UseE(unit)
		local pred = _G.PremiumPrediction:GetPrediction(myHero, unit, ESpellData)
		if pred.CastPos and _G.PremiumPrediction.HitChance.Low(pred.HitChance) and myHero.pos:DistanceTo(pred.CastPos) < 700 then
		    	Control.CastSpell(HK_E, pred.CastPos)
		    	LastESpot = pred.CastPos
		end 
end

function Fizz:UseE2(unit)
		--PrintChat("try E2")
		local pred = _G.PremiumPrediction:GetAOEPrediction(myHero, unit, E2SpellData)
		if pred.CastPos and _G.PremiumPrediction.HitChance.Medium(pred.HitChance) then
		    	Control.CastSpell(HK_E, pred.CastPos)
		    	--PrintChat("Cast E2")
		    	LastE2Spot = pred.CastPos
		end 
end

function Fizz:UseR(unit)
		local pred = _G.PremiumPrediction:GetPrediction(myHero, unit, RSpellData)
		if pred.CastPos and _G.PremiumPrediction.HitChance.Medium(pred.HitChance) and myHero.pos:DistanceTo(pred.CastPos) < 1300  then
		    	Control.CastSpell(HK_R, pred.CastPos)
		end 
end

class "Quinn"

local EnemyLoaded = false
local LastDist = 0
local ECastTime = Game:Timer()
local RCastTime = Game:Timer()
local casted = 0
local LockedTarget = nil
local LastESpot = myHero.pos
local LastE2Spot = myHero.pos
local attackedfirst = 0
local WasInRange = false
local hasHarrier = false
local UltMode = false
local CastingQ = false
local UltChan = false
local PassiveAuto = false
local passiveenemy = nil
local mtarget = nil
local target = nil
local SpecialTarget = nil
local CloseChamp = nil
local CloseMinion = nil
local DontSwitch = nil
local LastHitSpot = myHero.pos
local Direction = myHero.pos

function Quinn:Menu()
	self.Menu = MenuElement({type = MENU, id = "Quinn", name = "Quinn"})
	self.Menu:MenuElement({id = "ComboMode", name = "Combo", type = MENU})
	self.Menu.ComboMode:MenuElement({id = "UseQ", name = "Use Q in Combo", value = true})
	self.Menu.ComboMode:MenuElement({id = "UseW", name = "Use W in Combo", value = true})
	self.Menu.ComboMode:MenuElement({id = "UseE", name = "Use E in Combo", value = true})
	self.Menu.ComboMode:MenuElement({id = "UseR", name = "Use R in Combo", value = true})
	self.Menu.ComboMode:MenuElement({id = "UseMinionPassive", name = "AA Nearby Minions to proc passive", value = false})
	self.Menu.ComboMode:MenuElement({id = "UseChampionPassive", name = "AA Nearby Champs to proc passive", value = false})
	self.Menu:MenuElement({id = "KSMode", name = "KS", type = MENU})
	self.Menu.KSMode:MenuElement({id = "UseQ", name = "Use Q in KS", value = true})
	self.Menu.KSMode:MenuElement({id = "UseE", name = "Use E in KS", value = true})
	self.Menu.KSMode:MenuElement({id = "UseR", name = "Use R in KS", value = true})
	self.Menu:MenuElement({id = "HarassMode", name = "Harass", type = MENU})
	self.Menu.HarassMode:MenuElement({id = "UseQ", name = "Use Q in Harass", value = true})
	self.Menu.HarassMode:MenuElement({id = "UseW", name = "Use W in Harass", value = true})
	self.Menu.HarassMode:MenuElement({id = "UseE", name = "Use E in Harass", value = false})
	self.Menu.HarassMode:MenuElement({id = "UseMinionPassive", name = "AA Nearby Minions to proc passive", value = false})
	self.Menu.HarassMode:MenuElement({id = "UseChampionPassive", name = "AA Nearby Champs to proc passive", value = false})
	self.Menu:MenuElement({id = "Draw", name = "Draw", type = MENU})
	self.Menu.Draw:MenuElement({id = "UseDraws", name = "Enable Draws", value = false})
end

function Quinn:Spells()
	QSpellData = {speed = 1300, range = 1025, delay = 0.25, radius = 70, collision = {"minion"}, type = "linear"}
end

function Quinn:GotBuff(unit)
	for i = 0, unit.buffCount do
		local buff = unit:GetBuff(i)
		if buff and buff.count > 0 then 
			PrintChat(buff.name)
		end
	end
end

function Quinn:CanEnableAttack() 
	if UltChan or SpecialTarget then
		return false
	end
	return true   
end

function Quinn:SetMovement(bool)	
	if _G.SDK then
		_G.SDK.Orbwalker:SetMovement(bool)
		if self:CanEnableAttack() then
			_G.SDK.Orbwalker:SetAttack(bool)
		end
	end
end


function Quinn:Tick()
	if _G.JustEvade and _G.JustEvade:Evading() or (_G.ExtLibEvade and _G.ExtLibEvade.Evading) or Game.IsChatOpen() or myHero.dead then return end
	--PrintChat(myHero.attackData.state)
	target = GetTarget(1400)
	self:GetTargetManager()
	if SpecialTarget then
		--PrintChat("setting false")
		if not myHero.attackData.state == 2 then
			_G.SDK.Orbwalker:SetAttack(false)
		end
		if _G.SDK.Data:HeroCanAttack() and myHero.attackData.state == 1 then
			--PrintChat("Errrrrrrrrrr")
			--_G.SDK.Orbwalker:Attack(SpecialTarget)
			Control.Attack(SpecialTarget)
		end
	end

	CastingQ = myHero.activeSpell.name == "QuinnQ"
	PassiveAuto = myHero.activeSpell.name == "QuinnWEnchanced"
	hasHarrier = _G.SDK.BuffManager:HasBuff(myHero, "quinnpassiveammo")
	UltChan = myHero:GetSpellData(_R).name == "QuinnRReturnToQuinn" 
	if myHero:GetSpellData(_R).name == "QuinnR" or myHero:GetSpellData(_R).name == "QuinnRReturnToQuinn" then
		UltMode = false
	else
		UltMode = true
	end
	if UltChan then
		self:SetMovement(false)
	else
		if self:CanEnableAttack() then
			self:SetMovement(true)
			--PrintChat("true")
		end
		self:Logic()
	end
	self:KS()


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

function Quinn:Draw()
	if self.Menu.Draw.UseDraws:Value() then
		Draw.Circle(myHero.pos, 500, 1, Draw.Color(255, 0, 191, 255))
		--Draw.Circle(LastESpot, 85, 1, Draw.Color(255, 0, 0, 255))
		--Draw.Circle(LastE2Spot, 85, 1, Draw.Color(255, 255, 0, 255))
		if target then
		end
	end
end

function Quinn:GetCloseChampions()
	local Count = 0
	for i, enemy in pairs(EnemyHeroes) do
		if enemy and not enemy.dead then
			local Range = 1025
			if ValidTarget(enemy, Range) then
				Count = Count + 1
			end
		end
	end
	return Count
end

function Quinn:GetCloseMarkedMinion()
	local Minions = _G.SDK.ObjectManager:GetEnemyMinions(AARange)
	for i = 1, #Minions do
		local Aminion = Minions[i]
		local AARange = 525 + Aminion.boundingRadius + myHero.boundingRadius
		if ValidTarget(Aminion, AARange) and _G.SDK.BuffManager:HasBuff(Aminion, "QuinnW") then
			--PrintChat("Found new enemy")
			CloseMinion = Aminion
			return
		end		
	end
	CloseMinion = nil
end

function Quinn:GetTargetManager()
	local Selected = nil
	local CloseChampions = self:GetCloseChampions()
	local MarkedChampion = self:MarkedChampionCheck()
	local MarkedMinion = self:MarkedMinionCheck()
	if MarkedChampion then
		self:GetCloseMarkedChamp()
	elseif CloseChampions > 0 then
		if MarkedMinion then
			self:GetCloseMinionChamp()
		end
	end
	if CloseChamp then
		SpecialTarget = CloseChamp
	elseif CloseMinion then
		SpecialTarget = CloseMinion
	else
		SpecialTarget = nil
	end
end

function Quinn:GetCloseMarkedChamp()
	for i, enemy in pairs(EnemyHeroes) do
		if enemy and not enemy.dead then
			local AARange = 525 + enemy.boundingRadius + myHero.boundingRadius
			if ValidTarget(enemy, AARange) and _G.SDK.BuffManager:HasBuff(enemy, "QuinnW") then
				if not target or not target.networkID == enemy.networkID then
					--PrintChat("Found new Champ")
					CloseChamp = enemy
					return
				end
			end
		end
	end
	CloseChamp = nil
end

function Quinn:MarkedChampionCheck()
	local ComboCheck = self.Menu.ComboMode.UseChampionPassive:Value() and Mode() == "Combo"
	local HarassCheck = self.Menu.HarassMode.UseChampionPassive:Value() and Mode() == "Harass"
	if not UltChan and not PassiveAuto and not HasHarrier and ComboCheck or HarassCheck then
		return true
	else
		return false
	end
end

function Quinn:MarkedMinionCheck()
	local ComboCheck = self.Menu.ComboMode.UseMinionPassive:Value() and Mode() == "Combo"
	local HarassCheck = self.Menu.HarassMode.UseMinionPassive:Value() and Mode() == "Harass"
	if not UltChan and not PassiveAuto and not HasHarrier and ComboCheck or HarassCheck then
		self:GetCloseMarkedMinion()
		return true
	else
		return false
	end
end

function Quinn:KS()
	--PrintChat("ksing")
	for i, enemy in pairs(EnemyHeroes) do
		if enemy and not enemy.dead and ValidTarget(enemy, 1025) then
			local AARange = 525 + enemy.boundingRadius + myHero.boundingRadius
			local Qrange = 1025 + enemy.boundingRadius
			local Qdamage = getdmg("Q", enemy, myHero, myHero:GetSpellData(_Q).level)
			if self:CanUse(_Q, "KS") and GetDistance(enemy.pos, myHero.pos) < Qrange and self.Menu.KSMode.UseQ:Value() and enemy.health < Qdamage then
				self:UseQ(enemy)
			end
			local Erange = 675 + enemy.boundingRadius
			local Edamage = getdmg("E", enemy, myHero, myHero:GetSpellData(_E).level)
			if self:CanUse(_E, "KS") and GetDistance(enemy.pos, myHero.pos) < Erange and self.Menu.KSMode.UseE:Value() and enemy.health < Edamage then
				Control.CastSpell(HK_E, enemy)
			end
			local Rrange = 700
			local Rdamage = getdmg("R", enemy, myHero, myHero:GetSpellData(_R).level)
			if self:CanUse(_R, "KS") and GetDistance(enemy.pos, myHero.pos) < Rrange and self.Menu.KSMode.UseR:Value() and enemy.health < Rdamage and UltMode then
				Control.CastSpell(HK_R)
			end
		end
	end
end	

function Quinn:CanUse(spell, mode)
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
		if mode == "KS" and IsReady(spell) and self.Menu.KSMode.UseR:Value() then
			return true
		end
	end
	return false
end

function Quinn:Logic()
	if LockedTarget  and LockedTarget.dead then
		WasInRange = false
		LockedTarget = nil 
		LastDist = 10000
	end
	if target and (LockedTarget == target or LockedTarget == nil) then
		LastDist = GetDistance(target.pos, myHero.pos)
		--PrintChat(LastDist)
	else
		if Mode() == "Combo" and LastDist < 1025 then
			--PrintChat("What")
			if self:CanUse(_W, "Combo") then
				--PrintChat("What?!")
				Control.CastSpell(HK_W)
			end
		end
		WasInRange = false
		LockedTarget = nil 
		LastDist = 10000
		return 
	end
	if Mode() == "Combo" or Mode() == "Harass" and target then
		local hasPassive = _G.SDK.BuffManager:HasBuff(target, "QuinnW")
		local AARange = 525 + target.boundingRadius + myHero.boundingRadius
		local QRange = 1025 + target.boundingRadius + myHero.boundingRadius
		local ERange = 675 + target.boundingRadius + myHero.boundingRadius
		local RRange = 700
		--PrintChat(ERange)
		if hasPassive then
			--PrintChat("Got the Mark")
		end
		if GetDistance(target.pos, myHero.pos) < AARange then
			LockedTarget = target
		end
		if self:CanUse(_Q, Mode()) and ValidTarget(target, QRange) and not hasPassive and not UltMode then
			self:UseQ(target)
		end
		local MeUnderTurret = IsUnderEnemyTurret(myHero.pos)
		local TargetUnderTurret = IsUnderEnemyTurret(target.pos)
		if self:CanUse(_E, Mode()) and ValidTarget(target, ERange) and not hasPassive then
			if not TargetUnderTurret or MeUnderTurret then
				if GetDistance(target.pos, myHero.pos) < 175 then
					Control.CastSpell(HK_E, target)
				elseif GetDistance(target.pos, myHero.pos) > AARange and WasInRange then
					Control.CastSpell(HK_E, target)
				elseif UltMode then
					Control.CastSpell(HK_E, target)
				end
			end
		end
		if self:CanUse(_R, Mode()) and ValidTarget(target, AARange) and UltMode then
			Control.CastSpell(HK_R)
		end
	else
		WasInRange = false
		LockedTarget = nil
		LastDist = 10000
    end		
end

function Quinn:OnPreAttack(args)
end

function Quinn:OnPostAttackTick(args)
	local ERange = 675 + myHero.boundingRadius
	if ValidTarget(target, ERange) and self:CanUse(_E, Mode()) and not hasPassive then
		Control.CastSpell(HK_E, target)
	end
end

function Quinn:UseQ(unit)
		local pred = _G.PremiumPrediction:GetPrediction(myHero, unit, QSpellData)
		if pred.CastPos and _G.PremiumPrediction.HitChance.Low(pred.HitChance) and myHero.pos:DistanceTo(pred.CastPos) < 700 and not CastingQ then
		    	Control.CastSpell(HK_Q, pred.CastPos)
		end 
end

class "Aphelios"

local EnemyLoaded = false
local MainHand = "None"
local OffHand = "None"
local FlameQR = Game:Timer()
local SniperQR = Game:Timer()
local SlowQR = Game:Timer()
local BounceQR = Game:Timer()
local HealQR = Game:Timer()
local MainAtTime = MainHand
local CanRoot = false
local CanRange = false

function Aphelios:Menu()
	self.Menu = MenuElement({type = MENU, id = "Aphelios", name = "Aphelios"})
	self.Menu:MenuElement({id = "ComboMode", name = "Combo", type = MENU})
	self.Menu.ComboMode:MenuElement({id = "UseQ", name = "Use Q's in Combo", value = true})
	self.Menu.ComboMode:MenuElement({id = "UseW", name = "Switch Weapons", value = true})
	self.Menu.ComboMode:MenuElement({id = "UseQPassive", name = "Range Attack Calibrum Marked Targets", value = true})
	self.Menu:MenuElement({id = "HarassMode", name = "Harass", type = MENU})
	self.Menu.HarassMode:MenuElement({id = "UseQ", name = "Use Q's in Harass", value = true})
	self.Menu.HarassMode:MenuElement({id = "UseW", name = "Switch Weapons", value = true})
	self.Menu.HarassMode:MenuElement({id = "UseQPassive", name = "Range Attack Calibrum Marked Targets", value = true})
	self.Menu:MenuElement({id = "KSMode", name = "Kill Steal", type = MENU})
	self.Menu.KSMode:MenuElement({id = "UseQFlame", name = "Use Infernum Q to KS", value = true})
	self.Menu.KSMode:MenuElement({id = "UseQSniper", name = "Use Calibrum Q to KS", value = true})
	self.Menu.KSMode:MenuElement({id = "UseQPassive", name = "Killsteal Calibrum Marked Targets", value = true})
	self.Menu.KSMode:MenuElement({id = "UseW", name = "Switch Weapons to KS", value = true})
	self.Menu.KSMode:MenuElement({id = "UseR", name = "Use R to KS", value = true})
	self.Menu:MenuElement({id = "Draw", name = "Draw", type = MENU})
	self.Menu.Draw:MenuElement({id = "UseDraws", name = "Enable Draws", value = true})
end


function Aphelios:Spells()
	QSniperSpell = {speed = 1850, range = 1450, delay = 0.25, radius = 60, collision = {"minion"}, type = "linear"}
	QFlameSpell = {speed = 1850, range = 850, delay = 0.25, radius = 100, collision = {}, type = "linear"}
	RAllSpell = {speed = 1000, range = 1300, delay = 0.25, radius = 110, collision = {}, type = "linear"}
end


function Aphelios:Tick()
	if _G.JustEvade and _G.JustEvade:Evading() or (_G.ExtLibEvade and _G.ExtLibEvade.Evading) or Game.IsChatOpen() or myHero.dead then return end
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
	target = GetTarget(3000)
	if _G.SDK.BuffManager:HasBuff(myHero, "ApheliosSeverumQ") then
		SetAttack(false)
	else
		SetAttack(true)
	end
	OffHand = self:GetOffHand()
	MainHand = self:GetGun()
	self:GetTargetBuffs()
	self:KS()
	self:Combo()
end

function Aphelios:Draw()
	if self.Menu.Draw.UseDraws:Value() then
		Draw.Circle(myHero.pos, 225, 1, Draw.Color(255, 0, 191, 255))
		local endtime = Game.Timer()
		if myHero.activeSpell.valid then
			local attacktargetpos = myHero.activeSpell.placementPos
			local vectargetpos = Vector(attacktargetpos.x,attacktargetpos.y,attacktargetpos.z)
			Draw.Circle(vectargetpos, 225, 1, Draw.Color(255, 0, 191, 255))
		end
		Draw.Text(MainHand, 25, 770, 900, Draw.Color(0xFF32CD32))
		Draw.Text(OffHand, 25, 870, 900, Draw.Color(0xFF0000FF))
	end
	return 0
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

function SetAttack(bool)
	if _G.PremiumOrbwalker then
		_G.PremiumOrbwalker:SetAttack(bool)	
	elseif _G.SDK then
		_G.SDK.Orbwalker:SetAttack(bool)
	end
end

function EnableMovement()
	SetMovement(true)
end


function Aphelios:OnPreAttack(args)
	--("Attackedpre")
	Attacked = 0
end

function Aphelios:OnPostAttack()
	if Attacked == 0 then
		Attacked = 1
		Casted = 0
		--PrintChat("Attacked")
	end
	if target then
	end
end


function Aphelios:OnPostAttackTick(args)
	if Attacked == 0 then
		Attacked = 1
		Casted = 0
		--PrintChat("Attacked")
	end
	if target then
	end
end

function Aphelios:KS()
	local Qstage = 1
	local Rstage = 1
	local QspellType = QSniperSpell
	if MainHand == "Flame" then
		QspellType= QFlameSpell
		Qstage = 4
		Rstage = 2
	end
	for i, enemy in pairs(EnemyHeroes) do
		if enemy and not enemy.dead and ValidTarget(enemy, 1100) then
			if _G.SDK.BuffManager:HasBuff(target, "aphelioscalibrumbonusrangedebuff") and GetDistance(enemy.pos) > 650 then
				local AADmg = getdmg("AA", enemy, myHero)
				if _G.SDK.Orbwalker:CanAttack() and self.Menu.KSMode.UseQPassive:Value() and enemy.health < AADmg then
					Control.Attack(enemy)
				elseif _G.SDK.Orbwalker:CanAttack() and Mode() == "Combo" and self.Menu.ComboMode.UseQPassive:Value() and not ValidTarget(target, 650) then
					Control.Attack(enemy)
				elseif _G.SDK.Orbwalker:CanAttack() and Mode() == "Harass" and self.Menu.HarassMode.UseQPassive:Value() and not ValidTarget(target, 650) then
					Control.Attack(enemy)
				end
			end
			if self:CanUse(_Q, "KS") then
				local QDmg = getdmg("Q", enemy, myHero, Qstage, myHero:GetSpellData(_Q).level)
				if enemy.health < QDmg then
					local pred = _G.PremiumPrediction:GetPrediction(myHero, enemy, QspellType)
					if pred.CastPos and _G.PremiumPrediction.HitChance.Medium(pred.HitChance) then
		    			Control.CastSpell(HK_Q, pred.CastPos)
					end 
				end
			end
			if self:CanUse(_R, "KS") and GetDistance(enemy.pos) > 650  then
				local RDmg = getdmg("R", enemy, myHero, Rstage, myHero:GetSpellData(_R).level)
				local AADmg = getdmg("AA", enemy, myHero)
				if enemy.health < RDmg + AADmg*0.8 then
					self:UseRAll(enemy)
				end
			end
		end
	end
end

function Aphelios:GetOffHand()
	if _G.SDK.BuffManager:HasBuff(myHero, "ApheliosOffHandBuffCalibrum") then
		return "Sniper" 
	elseif _G.SDK.BuffManager:HasBuff(myHero, "ApheliosOffHandBuffGravitum") then
		return "Slow" 
	elseif _G.SDK.BuffManager:HasBuff(myHero,  "ApheliosOffHandBuffSeverum") then
		return "Heal" 
	elseif _G.SDK.BuffManager:HasBuff(myHero, "ApheliosOffHandBuffCrescendum") then
		return "Bounce" 
	elseif _G.SDK.BuffManager:HasBuff(myHero,  "ApheliosOffHandBuffInfernum") then
		return "Flame" 
	end
end

function Aphelios:GetGun()
	if myHero:GetSpellData(_Q).name == "ApheliosCalibrumQ" then
		return "Sniper" 
	end
	if myHero:GetSpellData(_Q).name == "ApheliosGravitumQ" then
		return "Slow" 
	end
	if myHero:GetSpellData(_Q).name == "ApheliosSeverumQ" then
		return "Heal" 
	end
	if myHero:GetSpellData(_Q).name == "ApheliosCrescendumQ" then
		return "Bounce" 
	end
	if myHero:GetSpellData(_Q).name == "ApheliosInfernumQ" then
		return "Flame" 
	end
end

function Aphelios:UseQSniper(unit)
		local pred = _G.PremiumPrediction:GetPrediction(myHero, unit, QSniperSpell)
		if pred.CastPos and _G.PremiumPrediction.HitChance.Medium(pred.HitChance) then
		    	Control.CastSpell(HK_Q, pred.CastPos)
		    	--DelayAction(RightClick,1.5,{target, mousePos})
		end 
end


function Aphelios:UseRAll(unit)
		local pred = _G.PremiumPrediction:GetPrediction(myHero, unit, RAllSpell)
		if pred.CastPos and _G.PremiumPrediction.HitChance.Medium(pred.HitChance) then
		    	if GetDistance(pred.CastPos) <= 1300 then
		    		Control.CastSpell(HK_R, pred.CastPos)
		    	end
		end 
end

function Aphelios:UseQFlame(unit)
		local pred = _G.PremiumPrediction:GetPrediction(myHero, unit, QFlameSpell)
		if pred.CastPos and _G.PremiumPrediction.HitChance.Medium(pred.HitChance) then
		    	Control.CastSpell(HK_Q, pred.CastPos)
		end 
end

function AmmoCheck(ammo)
	if myHero.hudAmmo > ammo or myHero.hudAmmo == 1 then
		return true
	else
		return false 
	end
end

function Aphelios:GetTargetBuffs()
	if target then
		CanRoot = _G.SDK.BuffManager:HasBuff(target, "ApheliosGravitumDebuff")
		CanRange = _G.SDK.BuffManager:HasBuff(target, "aphelioscalibrumbonusrangedebuff")
	end
end

function Aphelios:CanUse(spell, mode)
	if spell == _Q then
		if mode == "Combo" and IsReady(spell) and self.Menu.ComboMode.UseQ:Value() then
			return true
		elseif mode == "Harass" and IsReady(spell) and self.Menu.HarassMode.UseQ:Value() then
			return true
		elseif mode == "KS" and IsReady(spell) and MainHand == "Flame" and self.Menu.KSMode.UseQFlame:Value() then
			return true
		elseif mode == "KS" and IsReady(spell) and MainHand == "Sniper" and self.Menu.KSMode.UseQSniper:Value() then
			return true
		end
	elseif spell == _W then
		if mode == "Combo" and IsReady(spell) and self.Menu.ComboMode.UseW:Value() then
			return true
		elseif mode == "Harass" and IsReady(spell) and self.Menu.HarassMode.UseW:Value() then
			return true
		elseif mode == "KS" and IsReady(spell) and self.Menu.KSMode.UseW:Value() then
			return true
		end
	elseif spell == _R then
		if mode == "KS" and IsReady(spell) and self.Menu.KSMode.UseR:Value() then
			return true
		end
	end
	return false
end

function Aphelios:Combo()
	if target == nil then return end
	if Mode() == "Combo" or Mode() == "Harass" and target then
--@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@ SNIPER SNIPER SNIPER SNIPER @@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
			if MainHand == "Sniper" then
				if not IsReady(_Q) then
					SniperQR = Game:Timer() + myHero:GetSpellData(0).currentCd
				end
				if OffHand == "Slow" then
					if self:CanUse(_Q, Mode()) and ValidTarget(target, 1450) then
						self:UseQSniper(target)
					end
					if IsReady(_E) then

					end
					if self:CanUse(_W, Mode()) then
						if not self:CanUse(_Q, Mode()) and GetDistance(target.pos) <= 500 then
							Control.CastSpell(HK_W)
						end
						if SlowQR < Game:Timer() and CanRoot and myHero.mana > 60 then
							Control.CastSpell(HK_W)
						end 
					end
					if IsReady(_R) then

					end
					-- if target has Q buff, switch to W
				end
				if OffHand == "Flame" then
					if self:CanUse(_Q, Mode()) and ValidTarget(target, 1450) then
						self:UseQSniper(target)
					end
					if IsReady(_E) then

					end
					if self:CanUse(_W, Mode()) then
						--PrintChat("W REady")
						if GetDistance(target.pos) <= 500 then
							Control.CastSpell(HK_W)
						end 
						if FlameQR < Game:Timer() and GetDistance(target.pos) <= 650  and myHero.mana > 60 then
							Control.CastSpell(HK_W)
						end 
					end
					if IsReady(_R) then

					end
				end
				if OffHand == "Bounce" then
					if self:CanUse(_Q, Mode()) and ValidTarget(target, 1450) then
						self:UseQSniper(target)
					end
					if IsReady(_E) then

					end
					if self:CanUse(_W, Mode()) then
						if GetDistance(target.pos) < 350 then
							Control.CastSpell(HK_W)
						end
						if BounceQR < Game:Timer() and GetDistance(target.pos) <= 475 and myHero.mana > 60 then
							Control.CastSpell(HK_W)
						end  
					end
					if IsReady(_R) then

					end
				end
				if OffHand == "Heal" then
					if self:CanUse(_Q, Mode()) and ValidTarget(target, 1450) then
						self:UseQSniper(target)
					end
					if IsReady(_E) then

					end
					if self:CanUse(_W, Mode()) then
						if GetDistance(target.pos) <= 300 or myHero.health < myHero.maxHealth*0.3 then
							Control.CastSpell(HK_W)
						end
						if HealQR < Game:Timer() and GetDistance(target.pos) <= 550 and myHero.mana > 60 and myHero.levelData.lvl > 1 then
							Control.CastSpell(HK_W)
						end  
					end
					if IsReady(_R) then
					end
				end
			end

--@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@ SLOW SLOW SLOW SLOW @@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@


			if MainHand == "Slow" then
				if not IsReady(_Q) then
					SlowQR = Game:Timer() + myHero:GetSpellData(0).currentCd
				end
				if OffHand == "Sniper" then
					if self:CanUse(_Q, Mode()) and CanRoot then -- and target has Q buff 
						Control.CastSpell(HK_Q)
					end
					if IsReady(_E) then

					end
					if self:CanUse(_W, Mode()) then
						if GetDistance(target.pos) > 550 then
							Control.CastSpell(HK_W)
						end 
					end
					if IsReady(_R) then
					end
				end
				if OffHand == "Flame" then
					if self:CanUse(_Q, Mode()) and CanRoot then
						Control.CastSpell(HK_Q)
					end
					if IsReady(_E) then

					end
					if self:CanUse(_W, Mode()) then
						if FlameQR < Game:Timer() and myHero.mana > 60 and GetDistance(target.pos) <= 650 then
							Control.CastSpell(HK_W)
						end  
					end
					if IsReady(_R) then

					end
				end
				if OffHand == "Bounce" then
					if self:CanUse(_Q, Mode()) and CanRoot then
						Control.CastSpell(HK_Q)
					end
					if IsReady(_E) then

					end
					if self:CanUse(_W, Mode()) then
						if not self:CanUse(_Q, Mode()) and GetDistance(target.pos) < 350 then
							Control.CastSpell(HK_W)
						end 
						if BounceQR < Game:Timer() and myHero.mana > 60 and GetDistance(target.pos) <= 400 and not self:CanUse(_Q, Mode()) then
							Control.CastSpell(HK_W)
						end 
					end
					if IsReady(_R) then

					end
				end
				if OffHand == "Heal" then
					if self:CanUse(_Q, Mode()) and CanRoot then
						Control.CastSpell(HK_Q)
					end
					if IsReady(_E) then

					end
					if self:CanUse(_W, Mode()) then
						if not self:CanUse(_Q, Mode()) and myHero.health < myHero.maxHealth/2 then
							Control.CastSpell(HK_W)
						end
						if HealQR < Game:Timer() and myHero.mana > 60 and GetDistance(target.pos) <= 650 and not self:CanUse(_Q, Mode()) then
							Control.CastSpell(HK_W)
						end 
					end
					if IsReady(_R) then
					end
				end
			end


--@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@ FLAME FLAME FLAME FLAME @@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@


			if MainHand == "Flame" then
				if not IsReady(_Q) then
					FlameQR = Game:Timer() + myHero:GetSpellData(0).currentCd
				end
				if OffHand == "Slow" then
					if self:CanUse(_Q, Mode()) and ValidTarget(target, 850) then
						self:UseQFlame(target)
					end
					if IsReady(_E) then

					end
					if self:CanUse(_W, Mode()) then
						if not self:CanUse(_Q, Mode()) and GetDistance(target.pos) > 350 then
							Control.CastSpell(HK_W)
						end
						if SlowQR < Game:Timer() and myHero.mana > 60 and GetDistance(target.pos) <= 650 then
							Control.CastSpell(HK_W)
						end 
					end
					if IsReady(_R) then
					end
				end
				if OffHand == "Sniper" then
					if self:CanUse(_Q, Mode()) and ValidTarget(target, 850) then
						self:UseQFlame(target)
					end
					if IsReady(_E) then

					end
					if self:CanUse(_W, Mode()) then
						if GetDistance(target.pos) > 550 then
							Control.CastSpell(HK_W)
						end 
					end
					if IsReady(_R) then
					end
				end
				if OffHand == "Bounce" then
					if self:CanUse(_Q, Mode()) and ValidTarget(target, 850) then
						self:UseQFlame(target)
					end
					if IsReady(_E) then

					end
					if self:CanUse(_W, Mode()) then
						if not self:CanUse(_Q, Mode()) and GetDistance(target.pos) < 550 then
							Control.CastSpell(HK_W)
						end
						if BounceQR < Game:Timer() and myHero.mana > 60 and GetDistance(target.pos) <= 400 then
							Control.CastSpell(HK_W)
						end  
					end
					if IsReady(_R) then
					end
				end
				if OffHand == "Heal" then
					if self:CanUse(_Q, Mode()) and ValidTarget(target, 850) then
						self:UseQFlame(target)
					end
					if IsReady(_E) then

					end
					if self:CanUse(_W, Mode()) then
						if HealQR < Game:Timer() and myHero.mana > 60 and GetDistance(target.pos) <= 650 then
							Control.CastSpell(HK_W)
						end  
					end
					if IsReady(_R) then
					end
				end
			end


--@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@ BOUNCE BOUNCE BOUNCE BOUNCE @@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
			--function Orbwalker:__OnAutoAttackReset()
    		--	Attack.Reset = true
			--end

			if MainHand == "Bounce" then
				if not IsReady(_Q) then
					BounceQR = Game:Timer() + myHero:GetSpellData(0).currentCd
				end
				if OffHand == "Slow" then
					if self:CanUse(_Q, Mode()) and ValidTarget(target, 475) then
						Control.CastSpell(HK_Q, target)
					end
					if IsReady(_E) then

					end
					if self:CanUse(_W, Mode()) then
						if self:CanUse(_Q, Mode()) then
							if GetDistance(target.pos) > 475 then
								Control.CastSpell(HK_W)
							end
						else
							if GetDistance(target.pos) > 400 then
								Control.CastSpell(HK_W)
							end
						end
						if SlowQR < Game:Timer() and myHero.mana > 60 and CanRoot then
							Control.CastSpell(HK_W)
						end 
					end
					if IsReady(_R) then
					end
				end
				if OffHand == "Flame" then
					if self:CanUse(_Q, Mode()) and ValidTarget(target, 475) then
						Control.CastSpell(HK_Q, target)
					end
					if IsReady(_E) then

					end
					if self:CanUse(_W, Mode()) then
						if FlameQR < Game:Timer() and myHero.mana > 60 and GetDistance(target.pos) <= 650 then
							Control.CastSpell(HK_W)
						end  
					end
					if IsReady(_R) then

					end
				end
				if OffHand == "Sniper" then
					if self:CanUse(_Q, Mode()) and ValidTarget(target, 475) then
						Control.CastSpell(HK_Q, target)
					end
					if IsReady(_E) then

					end
					if self:CanUse(_W, Mode()) then
						if self:CanUse(_Q, Mode()) then
							if GetDistance(target.pos) > 475 then
								Control.CastSpell(HK_W)
							end
						else
							if GetDistance(target.pos) > 350 then
								Control.CastSpell(HK_W)
							end
						end 
					end
					if IsReady(_R) then
					end
				end
				if OffHand == "Heal" then
					if self:CanUse(_Q, Mode()) and ValidTarget(target, 475) then
						Control.CastSpell(HK_Q, target)
					end
					if IsReady(_E) then

					end
					if self:CanUse(_W, Mode()) then
						if HealQR < Game:Timer() and myHero.mana > 60 and GetDistance(target.pos) <= 650 then
							Control.CastSpell(HK_W)
						end  
					end
					if IsReady(_R) then
					end
				end
			end


--@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@ HEAL HEAL HEAL HEAL @@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@


			if MainHand == "Heal" then
				if not IsReady(_Q) then
					HealQR = Game:Timer() + myHero:GetSpellData(0).currentCd
				end	
				--PrintChat("Heal")
				if OffHand == "Slow" then
					if self:CanUse(_Q, Mode()) and ValidTarget(target, 620) then
						Control.CastSpell(HK_Q)
					end
					if IsReady(_E) then

					end
					if self:CanUse(_W, Mode()) then
						if not self:CanUse(_Q, Mode()) and myHero.health > myHero.maxHealth*0.7 then
							Control.CastSpell(HK_W)
						end
						if SlowQR < Game:Timer() and myHero.mana > 60 and GetDistance(target.pos) <= 650 then
							Control.CastSpell(HK_W)
						end  
					end
					if IsReady(_R) then

					end
				end
				if OffHand == "Flame" then
					if self:CanUse(_Q, Mode()) and ValidTarget(target, 620) then
						Control.CastSpell(HK_Q)
					end
					if IsReady(_E) then

					end
					if self:CanUse(_W, Mode()) then
						if not self:CanUse(_Q, Mode()) and GetDistance(target.pos) < 550 and myHero.health > myHero.maxHealth*0.2 then
							Control.CastSpell(HK_W)
						end 
						if FlameQR < Game:Timer() and myHero.mana > 60 and GetDistance(target.pos) <= 650 then
							Control.CastSpell(HK_W)
						end  
					end
					if IsReady(_R) then

					end
				end
				if OffHand == "Bounce" then
					if self:CanUse(_Q, Mode()) and ValidTarget(target, 620) then
						Control.CastSpell(HK_Q)
					end
					if IsReady(_E) then

					end
					if self:CanUse(_W, Mode()) then
						if not self:CanUse(_Q, Mode()) and GetDistance(target.pos) < 550 and myHero.health > myHero.maxHealth*0.2 then
							Control.CastSpell(HK_W)
						end 
					end
					if IsReady(_R) then

					end
				end
				if OffHand == "Sniper" then
					if self:CanUse(_Q, Mode()) and ValidTarget(target, 620) then
						Control.CastSpell(HK_Q)
					end
					if IsReady(_E) then

					end
					if self:CanUse(_W, Mode()) then
						if GetDistance(target.pos) > 550 and myHero.health > myHero.maxHealth*0.3 then
							Control.CastSpell(HK_W)
						end 
					end
					if IsReady(_R) then

					end
				end
			end
	end
end

function Aphelios:Harass()
	if target == nil then return end
	if Mode() == "Harass" then
			
	end
end

class "Pyke"

local EnemyLoaded = false
local casted = 0

local RRange = 750
local QRange = 1100
local ERange = 550

local FinishQ = true
local ChargingQ = false
local CastingQ = false
local CastingW = false
local CastingE = false
local CastingR = false

local WasInRange = false
local attacked = 0

local QCastTime = 0

local Rtick = true
local CanR = true 
local RtickTime = 0

function Pyke:Menu()
    self.Menu = MenuElement({type = MENU, id = "Pyke", name = "Pyke"})
    self.Menu:MenuElement({id = "UltKey", name = "Manual R Key", key = string.byte("T"), value = false})
    self.Menu:MenuElement({id = "ComboMode", name = "Combo", type = MENU})
    self.Menu.ComboMode:MenuElement({id = "UseQ", name = "Use Q in Combo", value = true})
    self.Menu.ComboMode:MenuElement({id = "UseQHitChance", name = "Q Hit Chance (0.15)", value = 0.15, min = 0, max = 1.0, step = 0.05})
    self.Menu.ComboMode:MenuElement({id = "UseQShort", name = "Use Short Q in Combo", value = true})
    self.Menu.ComboMode:MenuElement({id = "UseQMan", name = "Auto Finish manual Casted Qs", value = true})
    self.Menu.ComboMode:MenuElement({id = "UseE", name = "Use E in Combo", value = true})
    self.Menu.ComboMode:MenuElement({id = "UseEHitChance", name = "E Hit Chance (0.15)", value = 0.15, min = 0, max = 1.0, step = 0.05})
    self.Menu.ComboMode:MenuElement({id = "UseR", name = "Use R in Combo", value = true})
    self.Menu.ComboMode:MenuElement({id = "UseRHitChance", name = "R Hit Chance (0.15)", value = 0.15, min = 0, max = 1.0, step = 0.05})
    self.Menu:MenuElement({id = "KSMode", name = "Auto KS", type = MENU})
    self.Menu.KSMode:MenuElement({id = "UseR", name = "Use R in KS", value = true})
    self.Menu:MenuElement({id = "Draw", name = "Draw", type = MENU})
    self.Menu.Draw:MenuElement({id = "UseDraws", name = "Enable Draws", value = false})
end

function Pyke:Spells()
    QSpellData = {speed = 1700, range = 1100, delay = 0.25, radius = 55, collision = {"minion"}, type = "linear"}
    QScanSpellData = {speed = 1700, range = 1100, delay = 0.25, radius = 55, collision = {}, type = "linear"}
    RSpellData = {speed = 3000, range = 750, delay = 0.75, radius = 250, collision = {""}, type = "circular"}
    ESpellData = {speed = 1000, range = 550, delay = 0.25, radius = 100, collision = {""}, type = "linear"}
    AOEeSpellData = {speed = 1000, range = 550, delay = 0.25, radius = 100, collision = {""}, type = "linear"}
end

function Pyke:Tick()
    if _G.JustEvade and _G.JustEvade:Evading() or (_G.ExtLibEvade and _G.ExtLibEvade.Evading) or Game.IsChatOpen() or myHero.dead then return end
    target = GetTarget(2000)
    CastingQ = myHero.activeSpell.name == "PykeQ" or myHero.activeSpell.name == "PykeQRange" or myHero.activeSpell.name == "PykeQMelee"
    FinishQ = myHero.activeSpell.name == "PykeQRange" or myHero.activeSpell.name == "PykeQMelee"
    ChargingQ = myHero.activeSpell.name == "PykeQ"
    CastingW = myHero.activeSpell.name == "PykeW"
    CastingE = myHero.activeSpell.name == "PykeE"
    CastingR = myHero.activeSpell.name == "PykeR"
    --PrintChat(myHero:GetSpellData(_Q).name)
    --PrintChat(myHero.activeSpell.name)
    if IsReady(_Q) and not ChargingQ then
    	local ChargeTime = Game.Timer() - QCastTime
    	if Control.IsKeyDown(HK_Q) and ChargeTime > 0.1 then
            Control.KeyUp(HK_Q)
        end
    	QCastTime = Game:Timer() + 0.10
    end
    if Rtick == true then
        RtickTime = Game.Timer()
        Rtick = false
    else
        if Game.Timer() - RtickTime > 0.25 then
            CanR = true
        end
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

function Pyke:Draw()
    if self.Menu.Draw.UseDraws:Value() then
        Draw.Circle(myHero.pos, 1150, 1, Draw.Color(255, 0, 191, 255))
    end
end


function Pyke:Auto()
    local AARange = _G.SDK.Data:GetAutoAttackRange(myHero)
    for i, enemy in pairs(EnemyHeroes) do
        if enemy and not enemy.dead and ValidTarget(enemy) then

		    if ChargingQ == true and (Mode() == "Combo" or self.Menu.ComboMode.UseQMan:Value()) then
		    	--PrintChat("ChargingQ")
				local ChargeTime = Game.Timer() - QCastTime
				local DynamicQRange = 400
				if ChargeTime > 0.5 then
					DynamicQRange = 400 + (150 * ((ChargeTime-0.5)/0.1))
				else
					if not self.Menu.ComboMode.UseQShort:Value() then
						DynamicQRange = 0
					end
				end
				if DynamicQRange > 1100 then
					DynamicQRange = 1100
				end
				local DynamicQSpellData = {speed = 1700, range = DynamicQRange, delay = 0.25, radius = 55, collision = {"minion"}, type = "linear"}
			    local pred = _G.PremiumPrediction:GetPrediction(myHero, enemy, DynamicQSpellData)
		        if pred.CastPos and  pred.HitChance > self.Menu.ComboMode.UseQHitChance:Value() and GetDistance(pred.CastPos) < 1200 and Control.IsKeyDown(HK_Q) then
		                Control.CastSpell(HK_Q, pred.CastPos)
		                --PrintChat(ChargeTime)
		                --PrintChat("Casting Q auto 2")
		        end 	
			end
            if (self:CanUse(_R, "KS") or (Mode() == "Combo" and self:CanUse(_R, "Combo"))) and ValidTarget(enemy, RRange) and not CastingQ and not CastingW and not CastingE and not CastingR and not (myHero.pathing and myHero.pathing.isDashing) and self:UltKillCheck(enemy) then
                self:UseR(enemy)
            end
        end
    end
end 

function Pyke:GetUltDamage()
    local LvL = myHero.levelData.lvl
    if not LvL then
        LvL = 1
    end
    local LevelDamage = ({250, 250, 250, 250, 250, 250, 290, 330, 370, 400, 430, 450, 470, 490, 510, 530, 540, 550})[LvL]
    local HeroDamage = myHero.bonusDamage * 0.8
    local HeroPen = myHero.armorPen * 1.5
    local TotalDamage = LevelDamage + HeroDamage + HeroPen
    return TotalDamage
end

function Pyke:UltKillCheck(unit)
    local Rdmg = self:GetUltDamage()
    if unit.health < Rdmg and unit.health > 0 then
        return true
    else
        return false
    end
end

function Pyke:CanUse(spell, mode)
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



function Pyke:Logic()
    if target == nil then return end
    if Mode() == "Combo" or Mode() == "Harass" and target then
        local AARange = _G.SDK.Data:GetAutoAttackRange(myHero)
        if GetDistance(target.pos) < AARange then
            WasInRange = true
        end
        if self:CanUse(_Q, Mode()) and ValidTarget(target, QRange) and not CastingQ and not CastingW and not CastingE and not CastingR and not (myHero.pathing and myHero.pathing.isDashing) and not _G.SDK.Attack:IsActive() then
            local pred = _G.PremiumPrediction:GetPrediction(myHero, target, QScanSpellData)
            if pred.CastPos and  pred.HitChance > 0 and GetDistance(pred.CastPos) < 1200 then
                QCastTime = Game:Timer() + 0.10
                --PrintChat("Q")
                Control.KeyDown(HK_Q)
            end
        end
        if self:CanUse(_E, Mode()) and not self:CanUse(_Q, Mode()) and ValidTarget(target, ERange) and not CastingQ and not CastingW and not CastingE and not CastingR and not _G.SDK.Attack:IsActive() then
            self:UseE(target)
        end
    else
        WasInRange = false
    end     
end



function Pyke:OnPostAttack(args)
end

function Pyke:OnPostAttackTick(args)
end

function Pyke:OnPreAttack(args)
end

function Pyke:UseQ(unit)
        local pred = _G.PremiumPrediction:GetPrediction(myHero, unit, QSpellData)
        if pred.CastPos and  pred.HitChance > 0 and GetDistance(pred.CastPos) < 1200 then
                Control.CastSpell(HK_Q, pred.CastPos)
        end 
end

function Pyke:UseR(unit)
        local pred = _G.PremiumPrediction:GetAOEPrediction(myHero, unit, RSpellData)
        if pred.CastPos and  pred.HitChance > self.Menu.ComboMode.UseRHitChance:Value() and GetDistance(pred.CastPos) < 850 and CanR == true then
                Control.CastSpell(HK_R, pred.CastPos)
                CanR = false
                Rtick = true
        end 
end

function Pyke:UseAOEe(unit)
        local pred = _G.PremiumPrediction:GetAOEPrediction(myHero, unit, AOEeSpellData)
        if pred.CastPos and  pred.HitChance > self.Menu.ComboMode.UseEHitChance:Value() and GetDistance(pred.CastPos) < 650 then
                Control.CastSpell(HK_E, CastSpot)
        end 
end

function Pyke:UseE(unit)
        local pred = _G.PremiumPrediction:GetPrediction(myHero, unit, ESpellData)
        if pred.CastPos and  pred.HitChance > self.Menu.ComboMode.UseEHitChance:Value() and GetDistance(pred.CastPos) < 650 then
                Control.CastSpell(HK_E, pred.CastPos)
        end 
end

function OnLoad()
	Manager()
end
