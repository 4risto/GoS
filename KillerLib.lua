require "MapPositionGOS"
require "2DGeometry"
require "GGPrediction"
require "PremiumPrediction"

local kLibVersion = 2.68

-- [ AutoUpdate ]
do

	local KILLER_PATH = COMMON_PATH.."KillerAIO/"
	local KILLER_LIB = "KillerLib.lua"
	local KILLER_VERSION = "KillerLib.version"
	local gitHub = "https://raw.githubusercontent.com/Henslock/GoS-EXT/main/KillerAIO/"
    
    local function AutoUpdate()
	
		local function FileExists(path)
			local file = io.open(path, "r")
			if file ~= nil then 
				io.close(file) 
				return true 
			else 
				return false 
			end
		end
		
		local function DownloadFile(path, fileName)
			local startTime = os.clock()
			DownloadFileAsync(gitHub .. fileName, path .. fileName, function() end)
			repeat until os.clock() - startTime > 3 or FileExists(path .. fileName)
		end
        
        local function ReadFile(path, fileName)
            local file = assert(io.open(path .. fileName, "r"))
            local result = file:read()
            file:close()
            return result
        end
        
        DownloadFile(KILLER_PATH, KILLER_VERSION)
        local NewVersion = tonumber(ReadFile(KILLER_PATH, KILLER_VERSION))
        if NewVersion > kLibVersion then
            DownloadFile(KILLER_PATH, KILLER_LIB)
            print("New Killer Library Update - Please reload with F6")
        end
    end
	
	-- AutoUpdate() -- disabled by request (remove network auto-updates)
end
----------------------------------------------------
--|                   		UTILITY					             |--
----------------------------------------------------
-- VARS --
print("Killer Libs Loaded [ver. "..kLibVersion.."]")
heroes = false
wClock = 0
clock = os.clock
Latency = Game.Latency
ping = Latency() * 0.001
foundAUnit = false
_movementHistory = {}
TEAM_ALLY = myHero.team
TEAM_ENEMY = 300 - myHero.team
TEAM_JUNGLE = 300
wClock = 0
_OnVision = {}
sqrt = math.sqrt
MathHuge = math.huge
TableInsert = table.insert
TableRemove = table.remove
GameTimer = Game.Timer
Allies, Enemies, Turrets, FriendlyTurrets, Units = {}, {}, {}, {}, {}
DrawRect = Draw.Rect
DrawLine = Draw.Line
DrawCircle = Draw.Circle
DrawColor = Draw.Color
DrawText = Draw.Text
ControlSetCursorPos = Control.SetCursorPos
ControlKeyUp = Control.KeyUp
ControlKeyDown = Control.KeyDown
GameCanUseSpell = Game.CanUseSpell
GameHeroCount = Game.HeroCount
GameHero = Game.Hero
GameMinionCount = Game.MinionCount
GameMinion = Game.Minion
GameTurretCount = Game.TurretCount
GameTurret = Game.Turret
GameIsChatOpen = Game.IsChatOpen
GameResolution = Game.Resolution()
castSpell = {state = 0, tick = GetTickCount(), casting = GetTickCount() - 1000, mouse = mousePos}

HITCHANCE_IMPOSSIBLE = 0
HITCHANCE_COLLISION = 1
HITCHANCE_NORMAL = 2
HITCHANCE_HIGH = 3
HITCHANCE_IMMOBILE = 4

MINION_CANON = 0
MINION_MELEE = 1
MINION_CASTER = 2

RUNNING_AWAY = -1
RUNNING_TOWARDS = 1

LEAGUE_ARENA = 30 --map ID

_G.LATENCY = 0.05

-- Ensure a safe global IsValid exists early so callbacks registered
-- earlier in the file (Tick callbacks) can safely call it while the
-- rest of the file is still being parsed.
if IsValid == nil then
	function IsValid(unit)
		return (unit and unit.valid and unit.isTargetable and not unit.dead and unit.visible and unit.networkID and unit.pathing and unit.health > 0)
	end
end

--== Strafe Prediction==--

class("StrafePred")

StrafePred.WaypointData = {}
StrafePred.NewPosData = {}
StrafePred.StandingData = {}

function StrafePred:__init()
    _G._STRAFEPRED_START = true
    self.OnStrafePredCallback = {}
    Callback.Add("Tick", function() self:OnTick() end)
    
	local function register_objmgr_callbacks()
		if _G.SDK and _G.SDK.ObjectManager and not self._ObjMgrRegistered then
			_G.SDK.ObjectManager:OnEnemyHeroLoad(function(args)
		local enemyUnit = args.unit
		self.WaypointData[enemyUnit.handle] = {}
		self.NewPosData[enemyUnit.handle] = {x = 0, z = 0}
		self.StandingData[enemyUnit.handle] = GameTimer()
                
			end)
			self._ObjMgrRegistered = true
			return true
		end
		return false
	end

	if not register_objmgr_callbacks() then
		Callback.Add("Tick", function()
			register_objmgr_callbacks()
		end)
	end
	
end
 
local waypointLimit = 4
local strafeMargin = 0.5 --The closer this value is to 1, the more strict the strafe check will be
local stutterDistMargin = 125

function StrafePred:OnTick()	
	for _, unit in pairs(Enemies) do
		if(unit.valid and IsValid(unit)) then
			if(unit.pathing.hasMovePath) and (self.NewPosData[unit.handle])  then
				local newPos = self.NewPosData[unit.handle]
				self.StandingData[unit.handle] = GameTimer()
				if(unit.pathing.endPos.x ~= newPos.x and unit.pathing.endPos.z ~= newPos.z ) then
					self.NewPosData[unit.handle] = unit.pathing.endPos
					local endPosVec = Vector(unit.pathing.endPos.x, unit.pos.y, unit.pathing.endPos.z)
					local startPosVec = Vector(unit.pathing.startPos.x, unit.pos.y, unit.pathing.startPos.z)
					local nVec = Vector(endPosVec - startPosVec):Normalized()

					if(self.WaypointData[unit.handle] ~= nil or self.WaypointData[unit.handle]) then
						self:AddWaypointData(unit, {nVec, GameTimer(), unit.pos})
					end
					
				end
			end
		end
	end

	for _, unit in pairs(Allies) do
		if(unit.valid and IsValid(unit)) then
			if(unit.pathing.hasMovePath)  then
				self.StandingData[unit.handle] = GameTimer()
			end
		end
	end

	if(myHero.valid and IsValid(myHero)) then
		if(myHero.pathing.hasMovePath)  then
			self.StandingData[myHero.handle] = GameTimer()
		end
	end
	
end

function StrafePred:AddWaypointData(unit, tbl)
	local uName = unit.handle
	for i = #self.WaypointData[uName], 1, -1 do
		self.WaypointData[uName][i + 1] = self.WaypointData[uName][i]
	end
	if(#self.WaypointData[uName] > waypointLimit) then
		table.remove(self.WaypointData[uName], waypointLimit + 1)
	end
	self.WaypointData[uName][1] = tbl
end

function StrafePred:IsStrafing(tar)
	local tName = tar.handle
	if(tar.pathing.hasMovePath == false) then return false end
	if(self.WaypointData[tName] ~= nil or self.WaypointData[tName]) then
		if(#self.WaypointData[tName] == waypointLimit) then
			--Dot product check
			local res1 = dotProduct(self.WaypointData[tName][1][1], self.WaypointData[tName][2][1])
			local res2 = dotProduct(self.WaypointData[tName][1][1], self.WaypointData[tName][3][1])
			local res3 = dotProduct(self.WaypointData[tName][1][1], self.WaypointData[tName][4][1])
			local timebetweenWaypoints = self.WaypointData[tName][1][2] - self.WaypointData[tName][2][2] -- Time between waypoint update
			local lastWaypointTime = GameTimer() - self.WaypointData[tName][1][2] --Time between last waypoint and game time
			
			local pos1 = self.WaypointData[tName][1][3]
			local pos2 = self.WaypointData[tName][2][3]
			local pos3 = self.WaypointData[tName][3][3]
			local pos4 = self.WaypointData[tName][4][3]
			local avgPos = (pos1+pos2+pos3+pos4)/4

			if(res1 <= -strafeMargin and res2 >= strafeMargin and res3 <= -strafeMargin and timebetweenWaypoints <= 0.70 and lastWaypointTime <= 0.7) then
				return true, avgPos
			else
				return false
			end
		end
	else
		return false
	end
	
	return false
end

function StrafePred:IsStutterDancing(tar)
	local tName = tar.handle
	if(tar.pathing.hasMovePath == false) then return false end
	if(self.WaypointData[tName] ~= nil or self.WaypointData[tName]) then
		if(#self.WaypointData[tName] == waypointLimit) then

			local pos1 = self.WaypointData[tName][1][3]
			local pos2 = self.WaypointData[tName][2][3]
			local pos3 = self.WaypointData[tName][3][3]
			local pos4 = self.WaypointData[tName][4][3]
			local avgPos = (pos1+pos2+pos3+pos4)/4
			

			local timebetweenWaypoints = self.WaypointData[tName][1][2] - self.WaypointData[tName][2][2] -- Time between waypoint update
			local lastWaypointTime = GameTimer() - self.WaypointData[tName][1][2] --Time between last waypoint and game time
			
			if(tar.pos:DistanceTo(avgPos) <= stutterDistMargin and tar.pos:DistanceTo(pos4) <= stutterDistMargin and timebetweenWaypoints <= 0.90 and lastWaypointTime <= 1 ) then
				return true, avgPos
			end
		end
	else
		return false
	end
	
	return false
end

function StrafePred:GetIdleStandingTime(tar)
	if(self.StandingData[tar.handle] == nil or self.StandingData[tar.handle] == {}) then
		self.StandingData[tar.handle] = GameTimer()
	end

	if(IsValid(tar)) then
		if(self.StandingData[tar.handle] ~= nil) then
			local result = GameTimer() - self.StandingData[tar.handle]
			if(result <= 0.1) then result = 0 end
			return result
		end
	end
	return 0
end

local function OnChampStrafe(fn)
    if not _STRAFEPRED_START then
        _G.StrafePred = StrafePred()
    end
    table.insert(StrafePred.OnStrafePredCallback, fn)
end

StrafePred()

--[[ DELAY ACTION ]]--

if not unpack then unpack = table.unpack end
local delayedActions, delayedActionsExecuter = {}, nil
function DelayEvent(func, delay, args) --delay in seconds
	if not delayedActionsExecuter then
		function delayedActionsExecuter()
			for t, funcs in pairs(delayedActions) do
				if t <= os.clock() then
					for _, f in ipairs(funcs) do f.func(unpack(f.args or {})) end
					delayedActions[t] = nil
				end
			end
		end
		Callback.Add("Tick", delayedActionsExecuter)
	end
	local t = os.clock() + (delay or 0)
	if delayedActions[t] then table.insert(delayedActions[t], { func = func, args = args })
	else delayedActions[t] = { { func = func, args = args } }
	end
end


-- [[AUTO LEVELER]] --

function GenerateSkillPriority(input1, input2)

	local input3 = 0
	local enumTable = {1, 2, 3}
	enumTable[input1] = nil
	enumTable[input2] = nil
	for k, v in pairs(enumTable) do
		input3 = v
	end

	local skillPriority = {
		["firstSkill"] = FetchQWESkillOrder(input1),
		["secondSkill"] = FetchQWESkillOrder(input2),
		["thirdSkill"] = FetchQWESkillOrder(input3)
	}

	return skillPriority
end

function FetchQWEByValue(input)
	if(input == 1) then
		return "Q"
	end
	if(input == 2) then
		return "W"
	end
	return "E"
end

function FetchQWESkillOrder(input)
	if(input == 1) then
		return {_Q, HK_Q}
	end
	if(input == 2) then
		return {_W, HK_W}
	end
	return {_E, HK_E}
end

local AutoLevelCheck = false
function AutoLeveler(skillPriority)
	if AutoLevelCheck then return end
	
	local level = myHero.levelData.lvl
	local levelPoints = myHero.levelData.lvlPts

	if (levelPoints == 0) or (level == 1) then return end
	if (Game.mapID == HOWLING_ABYSS and level <= 3) then return end
	if (Game.mapID == LEAGUE_ARENA) then return end
	--[[
	Rules:
	- Prioritize Ult when it's attainable [6, 11, 16]
	- Make sure we have at least one rank of every ability by level 3
	- Funnel skill points into the primary skill, and if we cannot, overflow to the secondary
	- A skill cannot be leveled up if it's level will be greater than HALF of our champion level ROUNDED UP
	--]]
	if(levelPoints > 0) then
		local rLevel = myHero:GetSpellData(_R).level

		if (rLevel == 0 and level >= 6) or (rLevel == 1 and level >= 11) or (rLevel == 2 and level >= 16) then
			AutoLevelCheck = true
			DelayEvent(function()		
				Control.KeyDown(HK_LUS)
				Control.KeyDown(HK_R)
				Control.KeyUp(HK_R)
				Control.KeyUp(HK_LUS)
				AutoLevelCheck = false
			end, math.random(0.1, 0.15))
			return
		end

		local firstSkill = myHero:GetSpellData(skillPriority["firstSkill"][1])
		local secondSkill = myHero:GetSpellData(skillPriority["secondSkill"][1])
		local thirdSkill = myHero:GetSpellData(skillPriority["thirdSkill"][1])

		--First 3 skill levels
		if(firstSkill.level == 0) then
			AutoLevelCheck = true
			local cachedLevel = firstSkill.level
			DelayEvent(function()
				if(cachedLevel == firstSkill.level) then
					Control.KeyDown(HK_LUS)
					Control.KeyDown(skillPriority["firstSkill"][2])
					Control.KeyUp(skillPriority["firstSkill"][2])
					Control.KeyUp(HK_LUS)
				end
				DelayEvent(function()
					AutoLevelCheck = false
				end, 0.05)
			end, math.random(0.1, 0.15))
			return
		end
		if(secondSkill.level == 0) then
			AutoLevelCheck = true
			local cachedLevel = secondSkill.level
			DelayEvent(function()
				if(cachedLevel == secondSkill.level) then
					Control.KeyDown(HK_LUS)
					Control.KeyDown(skillPriority["secondSkill"][2])
					Control.KeyUp(skillPriority["secondSkill"][2])
					Control.KeyUp(HK_LUS)
				end
				DelayEvent(function()
					AutoLevelCheck = false
				end, 0.05)
			end, math.random(0.1, 0.15))
			return
		end
		if(thirdSkill.level == 0) then
			AutoLevelCheck = true
			local cachedLevel = thirdSkill.level
			DelayEvent(function()
				if(cachedLevel == thirdSkill.level) then
					Control.KeyDown(HK_LUS)
					Control.KeyDown(skillPriority["thirdSkill"][2])
					Control.KeyUp(skillPriority["thirdSkill"][2])
					Control.KeyUp(HK_LUS)
				end
				DelayEvent(function()
					AutoLevelCheck = false
				end, 0.05)
			end, math.random(0.1, 0.15))
			return
		end


		-- Standard leveling
		if(firstSkill.level ~= 5) then
			if(firstSkill.level + 1 <= math.ceil(level/2)) then
				
				AutoLevelCheck = true
				local cachedLevel = firstSkill.level
				DelayEvent(function()
					if(cachedLevel == firstSkill.level) then
						Control.KeyDown(HK_LUS)
						Control.KeyDown(skillPriority["firstSkill"][2])
						Control.KeyUp(skillPriority["firstSkill"][2])
						Control.KeyUp(HK_LUS)
					end
					AutoLevelCheck = false
				end, math.random(0.1, 0.15))
				return
			end
		end

		if(secondSkill.level ~= 5) then
			if(secondSkill.level + 1 <= math.ceil(level/2)) then
				AutoLevelCheck = true
				local cachedLevel = secondSkill.level
				DelayEvent(function()
					if(cachedLevel == secondSkill.level) then
						Control.KeyDown(HK_LUS)
						Control.KeyDown(skillPriority["secondSkill"][2])
						Control.KeyUp(skillPriority["secondSkill"][2])
						Control.KeyUp(HK_LUS)
					end
					AutoLevelCheck = false
				end, math.random(0.1, 0.15))
				return
			end
		end

		if(thirdSkill.level ~= 5) then
			if(thirdSkill.level + 1 <= math.ceil(level/2)) then
				AutoLevelCheck = true
				local cachedLevel = thirdSkill.level
				DelayEvent(function()	
					if(cachedLevel == thirdSkill.level) then
						Control.KeyDown(HK_LUS)
						Control.KeyDown(skillPriority["thirdSkill"][2])
						Control.KeyUp(skillPriority["thirdSkill"][2])
						Control.KeyUp(HK_LUS)
					end
					AutoLevelCheck = false
				end, math.random(0.1, 0.15))
				return
			end
		end
	else
		AutoLevelCheck = false
	end
end

-- ITEM & RUNE DATA --

ItemHotKey = {[ITEM_1] = HK_ITEM_1, [ITEM_2] = HK_ITEM_2,[ITEM_3] = HK_ITEM_3, [ITEM_4] = HK_ITEM_4, [ITEM_5] = HK_ITEM_5, [ITEM_6] = HK_ITEM_6}

Item = {
	Boots = 1001,
	FaerieCharm = 1004,
	RejuvenationBead = 1006,
	GiantsBelt = 1011,
	CloakofAgility = 1018,
	BlastingWand = 1026,
	SapphireCrystal = 1027,
	RubyCrystal = 1028,
	ClothArmor = 1029,
	ChainVest = 1031,
	NullMagicMantle = 1033,
	Emberknife = 1035,
	LongSword = 1036,
	Pickaxe = 1037,
	BFSword = 1038,
	Hailblade = 1039,
	ObsidianEdge = 1040,
	Dagger = 1042,
	RecurveBow = 1043,
	AmplifyingTome = 1052,
	VampiricScepter = 1053,
	DoransShield = 1054,
	DoransBlade = 1055,
	DoransRing = 1056,
	NegatronCloak = 1057,
	NeedlesslyLargeRod = 1058,
	DarkSeal = 1082,
	Cull = 1083,
	ScorchclawPup = 1101,
	GustwalkerHatchling = 1102,
	MosstomperSeedling = 1103,
	EyeoftheHerald = 1104 or 3513,
	PenetratingBullets = 1500,
	Fortification = 1501 or 1521,
	ReinforcedArmor = 1502 or 1506,
	WardensEye = 1503,
	Vanguard = 1504,
	Overcharged = 1507,
	AntitowerSocks = 1508,
	Gusto = 1509,
	PhreakishGusto = 1510,
	SuperMechArmor = 1511,
	SuperMechPowerField = 1512,
	TurretPlating = 1515,
	StructureBounty = 1516 or 1517 or 1518 or 1519,
	OvererchargedHA = 1520,
	TowerPowerUp = 1522,
	HealthPotion = 2003,
	TotalBiscuitofEverlastingWill = 2010,
	KircheisShard = 2015,
	SteelSigil = 2019,
	RefillablePotion = 2031,
	CorruptingPotion = 2033,
	GuardiansAmulet = 2049,
	GuardiansShroud = 2050,
	GuardiansHorn = 2051 or 222051,
	PoroSnax = 2052,
	ControlWard = 2055,
	ShurelyasBattlesong = 2065 or 222065,
	ElixirofIron = 2138,
	ElixirofSorcery = 2139,
	ElixirofWrath = 2140,
	CappaJuice = 2141,
	JuiceofPower = 2142,
	JuiceofVitality = 2143,
	JuiceofHaste = 2144,
	MinionDematerializer = 2403,
	CommencingStopwatch = 2419,
	Stopwatch = 2420,
	BrokenStopwatch = 2421 or 2424,
	SlightlyMagicalFootwear = 2422,
	PerfectlyTimedStopwatch = 2423,
	Evenshroud = 3001 or 223001,
	ArchangelsStaff = 3003 or 223003,
	Manamune = 3004 or 223004,
	BerserkersGreaves = 3006 or 223006,
	BootsofSwiftness = 3009 or 223009,
	ChemtechPutrifier = 3011 or 223011,
	ChaliceofBlessing = 3012,
	SorcerersShoes = 3020 or 223020,
	LifewellPendant = 3023,
	GlacialBuckler = 3024,
	GuardianAngel = 3026,
	InfinityEdge = 3031 or 223026,
	MortalReminder = 3033 or 223031,
	LastWhisper = 3035 or 223033,
	LordDominiksRegards = 3036 or 223036,
	SeraphsEmbrace = 3040 or 223040,
	MejaisSoulstealer = 3041,
	Muramana = 3042 or 223042,
	Phage = 3044,
	PhantomDancer = 3046 or 223046,
	PlatedSteelcaps = 3047 or 223047,
	ZekesConvergence = 3050 or 223050,
	HearthboundAxe = 3051,
	SteraksGage = 3053 or 223053,
	Sheen = 3057,
	SpiritVisage = 3065 or 223065,
	WingedMoonplate = 3066,
	Kindlegem = 3067,
	SunfireAegis = 3068 or 223068,
	TearoftheGoddess = 3070,
	BlackCleaver = 3071 or 223071,
	Bloodthirster = 3072 or 223072,
	RavenousHydra = 3074 or 223074,
	Thornmail = 3075 or 223075,
	BrambleVest = 3076,
	Tiamat = 3077,
	TrinityForce = 3078 or 223078,
	WardensMail = 3082,
	WarmogsArmor = 3083,
	Heartsteel = 3084 or 223084,
	RunaansHurricane = 3085 or 223085,
	Zeal = 3086,
	StatikkShiv = 3087 or 223087,
	RabadonsDeathcap = 3089 or 223089,
	WitsEnd = 3091 or 223091,
	RapidFirecannon = 3094 or 223094,
	Stormrazor = 3095 or 223095,
	LichBane = 3100 or 223100,
	BansheesVeil = 3102 or 223102,
	AegisoftheLegion = 3105,
	Redemption = 3107 or 223107,
	FiendishCodex = 3108,
	KnightsVow = 3109 or 223109,
	FrozenHeart = 3110 or 223110,
	MercurysTreads = 3111 or 223111,
	GuardiansOrb = 3112 or 223112,
	AetherWisp = 3113,
	ForbiddenIdol = 3114,
	NashorsTooth = 3115 or 223115,
	RylaisCrystalScepter = 3116 or 223116,
	MobilityBoots = 3117,
	WintersApproach = 3119 or 223119,
	Fimbulwinter = 3121 or 223121,
	ExecutionersCalling = 3123,
	GuinsoosRageblade = 3124 or 223124,
	DeathfireGrasp = 3128,
	CaulfieldsWarhammer = 3133,
	SerratedDirk = 3134,
	VoidStaff = 3135 or 223135,
	MercurialScimitar = 3139 or 223139,
	QuicksilverSash = 3140,
	YoumuusGhostblade = 3142 or 223142,
	RanduinsOmen = 3143 or 223143,
	HextechAlternator = 3145,
	HextechRocketbelt = 3152 or 223152,
	BladeofTheRuinedKing = 3153 or 223153,
	Hexdrinker = 3155,
	MawofMalmortius = 3156 or 223156,
	ZhonyasHourglass = 3157 or 223157,
	IonianBootsofLucidity = 3158 or 223158,
	SpearOfShojin = 3161 or 223161,
	Morellonomicon = 3165 or 223165,
	GuardiansBlade = 3177 or 223177,
	UmbralGlaive = 3179,
	Hullbreaker = 3181 or 223181,
	GuardiansHammer = 3184 or 223184,
	LocketoftheIronSolari = 3190 or 223190,
	SeekersArmguard = 3191,
	GargoyleStoneplate = 3193 or 223193,
	SpectresCowl = 3211,
	MikaelsBlessing = 3222 or 223222,
	ScarecrowEffigy = 3330,
	StealthWard = 3340,
	ArcaneSweeper = 3348,
	LucentSingularity = 3349,
	FarsightAlteration = 3363,
	OracleLens = 3364,
	YourCut = 3400,
	RiteOfRuin = 3430,
	ArdentCenser = 3504 or 223504,
	EssenceReaver = 3508 or 223508,
	KalistasBlackSpear = 3599 or 3600,
	DeadMansPlate = 3742 or 223742,
	TitanicHydra = 3748 or 223748,
	CrystallineBracer = 3801,
	LostChapter = 3802,
	CatalystofAeons = 3803,
	EdgeofNight = 3814 or 223814,
	SpellthiefsEdge = 3850,
	Frostfang = 3851,
	ShardofTrueIce = 3853,
	SteelShoulderguards = 3854,
	RunesteelSpaulders = 3855,
	PauldronsofWhiterock = 3857,
	RelicShield = 3858,
	TargonsBuckler = 3859,
	BulwarkoftheMountain = 3860,
	SpectralSickle = 3862,
	HarrowingCrescent = 3863,
	BlackMistScythe = 3864,
	FireatWill = 3901,
	DeathsDaughter = 3902,
	RaiseMorale = 3903,
	OblivionOrb = 3916,
	ImperialMandate = 4005 or 224005,
	BloodlettersCurse = 4010,
	ForceofNature = 4401 or 224401,
	TheGoldenSpatula = 4403 or 224403,
	HorizonFocus = 4628 or 224628,
	CosmicDrive = 4629 or 224629,
	BlightingJewel = 4630,
	VerdantBarrier = 4632,
	Riftmaker = 4633 or 224633,
	LeechingLeer = 4635,
	NightHarvester = 4636 or 224636,
	DemonicEmbrace = 4637 or 224637,
	WatchfulWardstone = 4638,
	StirringWardstone = 4641,
	BandleglassMirror = 4642,
	VigilantWardstone = 4643,
	CrownoftheShatteredQueen = 4644 or 224644,
	Shadowflame = 4645 or 224645,
	IronspikeWhip = 6029,
	SilvermereDawn = 6035 or 226035,
	DeathsDance = 6333 or 226333,
	ChempunkChainsword = 6609 or 226609,
	StaffofFlowingWater = 6616 or 226616,
	MoonstoneRenewer = 6617 or 226617,
	EchoesofHelia = 6620 or 226620,
	Goredrinker = 6630 or 226630,
	Stridebreaker = 6631 or 226631,
	DivineSunderer = 6632 or 226632,
	LiandrysAnguish = 6653 or 226653,
	LudensTempest = 6655 or 226655,
	Everfrost = 6656 or 226656,
	RodofAges = 6657 or 226657,
	BamisCinder = 6660,
	IcebornGauntlet = 6662 or 226662,
	TurboChemtank = 6664 or 226664,
	JakShoTheProtean = 6665 or 226665,
	RadiantVirtue = 6667 or 226667,
	Noonquiver = 6670,
	Galeforce = 6671 or 6671,
	KrakenSlayer = 6672 or 6672,
	ImmortalShieldbow = 6673 or 6673,
	NavoriQuickblades = 6675 or 6675,
	TheCollector = 6676 or 6676,
	Rageknife = 6677,
	DuskbladeofDraktharr = 6691 or 226691,
	Eclipse = 6692 or 226692,
	ProwlersClaw = 6693 or 226693,
	SeryldasGrudge = 6694 or 226694,
	SerpentsFang = 6695 or 226695,
	AxiomArc = 6696 or 226696,
	SandshrikesClaw = 7000,
	Syzygy = 7001 or 227001,
	DraktharrsShadowcarver = 7002 or 227002,
	FrozenFist = 7005 or 227005,
	Typhoon = 7006 or 227006,
	IcathiasCurse = 7009 or 227009,
	Vespertide = 7010 or 227010,
	UpgradedAeropack = 7011 or 227011,
	LiandrysLament = 7012 or 227012,
	EyeofLuden = 7013 or 227013,
	EternalWinter = 7014 or 227014,
	CeaselessHunger = 7015 or 227015,
	Dreamshatter = 7016 or 227016,
	Deicide = 7017 or 227017,
	InfinityForce = 7018 or 227018,
	ReliquaryoftheGoldenDawn = 7019 or 227019,
	ShurelyasRequiem = 7020 or 227020,
	Starcaster = 7021 or 227021,
	Equinox = 7023 or 227023,
	Caesura = 7024 or 227024,
	Leviathan = 7025 or 227025,
	TheUnspokenParasite = 7026 or 227026,
	PrimordialDawn = 7027 or 227027,
	InfiniteConvergence = 7028 or 227028,
	YoumuusWake = 7029 or 227029,
	SeethingSorrow = 7030 or 227030,
	EdgeofFinality = 7031 or 227031,
	Flicker = 7032 or 227032,
	CryoftheShriekingCity = 7033 or 227033,
	GangplankPlaceholder = 7050,
	AnathemasChains = 8001 or 228001,
	AbyssalMask = 8020 or 228020,
	Ghostcrawlers = 223005,
	AtmasReckoning = 223039,
	HextechGunblade = 223146,
	Zephyr = 223172,
	GuardiansDirk = 223185,
	SpectralCutlass = 224004,
}

ItemDamage = {
	[Item.Muramana] = function()
		if(myHero.range < 400) then
			return myHero.maxMana*0.035 + myHero.bonusDamage*0.06
		else
			return myHero.maxMana*0.027 + myHero.bonusDamage*0.06
		end
	end,
	[Item.DivineSunderer] = function(args)
		if(myHero.range < 400) then
			return myHero.baseDamage * 1.6 + args.maxHealth * 0.04
		else
			return myHero.baseDamage * 1.6 + args.maxHealth * 0.02
		end
	end,
	[Item.Everfrost] = function() return 100 + (myHero.ap * 0.3) end,
	[Item.EternalWinter] = function() return 100 + (myHero.ap * 0.3) end,
	[Item.LudensTempest] = function() return 100 + (myHero.ap * 0.1) end,
	[Item.Sheen] = function() return myHero.baseDamage end,
	[Item.TrinityForce] = function() return myHero.baseDamage * 2 end,
	[Item.IcebornGauntlet] = function() return myHero.baseDamage end,
	[Item.InfinityForce] = function() return myHero.baseDamage * 2 end,
	[Item.EssenceReaver] = function() return (myHero.baseDamage * 1.3) + (myHero.bonusDamage * 0.2) end,
	[Item.HextechRocketbelt] = function() return 125 + (0.15 * myHero.ap) end,
	[Item.UpgradedAeropack] = function() return 125 + (0.15 * myHero.ap) end,
	[Item.ProwlersClaw] = function() return 85 + (0.55 * myHero.bonusDamage) end,
	[Item.Stridebreaker] = function() return 1.75 * myHero.baseDamage end,
	[Item.IronspikeWhip] = function() return myHero.baseDamage end,
	[Item.DuskbladeofDraktharr] = function(args) return (1 + math.min(((1 - (args.health / args.maxHealth)) / 7) * 1.6, 0.16)) end,
	[Item.NavoriQuickblades] = function() return (1 + (myHero.critChance / 5)) end,
	[Item.LordDominiksRegards] = function(args) return (1 + ((math.max(args.maxHealth - myHero.maxHealth, 0))/100 * 0.88)/100) end,
}

function HasItem(itemID)
    for i = ITEM_1, ITEM_7 do
		if(type(itemID) == "table") then
			for _, item in pairs(itemID) do
				local id = myHero:GetItemData(i).itemID
				if id == item then
					if(myHero:GetSpellData(i).currentCd == 0) then
						return true, i
					end
				end
			end
		else
			local id = myHero:GetItemData(i).itemID
			if id == itemID then
				if(myHero:GetSpellData(i).currentCd == 0) then
					return true, i
				else
					return false
				end
			end
		end
    end
	return false
end

function GetItemDamage(itemID, tar)
	if(ItemDamage[itemID]) then
		local hasArgs = (debug.getinfo(ItemDamage[itemID]).nparams) == 1
		if(hasArgs) then
			if(tar) then
				return ItemDamage[itemID](tar)
			else
				print("Warning: GetItemDamage called without providing target for ID " .. itemID)
			end
		else
			return ItemDamage[itemID]()
		end
	end
	return 0
end

-- Rune Stuff

function HasElectrocute()
    for i = 0, myHero.buffCount do
        local buff = myHero:GetBuff(i)
        if buff and buff.count>0 and buff.name:lower():find("electrocute.lua") then
			return true
        end
    end

	return false
end

function GetElectrocuteDamage()
	return 30 + ((190/17)*(myHero.levelData.lvl-1)) + (myHero.ap * 0.05) + (myHero.bonusDamage * 0.1)
end

function HasIgnite()
	if myHero:GetSpellData(SUMMONER_1).name == "SummonerDot" and Ready(SUMMONER_1) then
		return true
	elseif myHero:GetSpellData(SUMMONER_2).name == "SummonerDot" and Ready(SUMMONER_2) then
		return true
	end
	
	return false
end

function UseIgnite(unit)
	if myHero:GetSpellData(SUMMONER_1).name == "SummonerDot" and Ready(SUMMONER_1) then
		Control.CastSpell(HK_SUMMONER_1, unit)
	elseif myHero:GetSpellData(SUMMONER_2).name == "SummonerDot" and Ready(SUMMONER_2) then
		Control.CastSpell(HK_SUMMONER_2, unit)
	end
end

function GetIgniteDamage()
	return 50 + (20 * myHero.levelData.lvl)
end

function HasArcaneComet()
    for i = 0, myHero.buffCount do
        local buff = myHero:GetBuff(i)
        if buff and buff.count>0 and buff.name:lower():find("arcanecometsnipe.lua") then
			return true
        end
    end

	return false
end

function GetArcaneCometDamage()
	return 30 + ((100/17)*(myHero.levelData.lvl-1)) + (myHero.ap * 0.05) + (myHero.bonusDamage * 0.1)
end

function HasFirstStrike()
    for i = 0, myHero.buffCount do
        local buff = myHero:GetBuff(i)
        if buff and buff.count>0 and buff.name:lower():find("firststrikeavailable") then
			return true
        end
    end

	return false
end
function GetFirstStrikeBonus()
	return 1.07
end


-- UTILITY FUNCTIONS --

function LoadUnits()
	--[[
	for i = 1, GameHeroCount() do
		local unit = GameHero(i); Units[i] = {unit = unit, spell = nil}
		if unit.team ~= myHero.team then TableInsert(Enemies, unit)
		elseif unit.team == myHero.team and unit ~= myHero then TableInsert(Allies, unit) end
	end
	--]]

	_G.SDK.ObjectManager:OnEnemyHeroLoad(function(args)
		local hero = args.unit
		TableInsert(Enemies, hero)
	end)

	_G.SDK.ObjectManager:OnAllyHeroLoad(function(args)
		local hero = args.unit
		TableInsert(Allies, hero)
	end)

	for i = 1, Game.TurretCount() do
		local turret = Game.Turret(i)
		if turret and turret.isEnemy then TableInsert(Turrets, turret) end
		if turret and not turret.isEnemy then TableInsert(FriendlyTurrets, turret) end
	end

end


function CheckWall(from, to, distance)
    local pos1 = to + (to - from):Normalized() * 50
    local pos2 = pos1 + (to - from):Normalized() * (distance - 50)
    local point1 = Point(pos1.x, pos1.z)
    local point2 = Point(pos2.x, pos2.z)
    if MapPosition:intersectsWall(LineSegment(point1, point2)) then
        return true
    end
    return false
end


function EnemyHeroes()
    local _EnemyHeroes = {}
    for i = 1, GameHeroCount() do
        local unit = GameHero(i)
        if unit.isEnemy then
            TableInsert(_EnemyHeroes, unit)
        end
    end
    return _EnemyHeroes
end


function IsValid(unit)
    if (unit and unit.valid and unit.isTargetable and not unit.dead and unit.visible and unit.networkID and unit.pathing and unit.health > 0) then
        return true;
    end
    return false;
end

function Ready(spell)
    return myHero:GetSpellData(spell).currentCd == 0 and myHero:GetSpellData(spell).level > 0 and myHero:GetSpellData(spell).mana <= myHero.mana and GameCanUseSpell(spell) == 0
end

function GetDistanceSqr(pos1, pos2)
	local pos2 = pos2 or myHero.pos
	local dx = pos1.x - pos2.x
	local dz = (pos1.z or pos1.y) - (pos2.z or pos2.y)
	return dx * dx + dz * dz
end

function GetDistance(pos1, pos2)
	if(pos1 == nil or pos2 == nil) then return "Error" end

	local a = pos1.pos or pos1
	local b = pos2.pos or pos2
	return sqrt(GetDistanceSqr(a, b))
end

function GetDistance2D(pos1, pos2)
	local pos2 = pos2 or myHero.pos
	local dx = pos1.x - pos2.x
	local dy = pos1.y - pos2.y
	return sqrt(dx * dx + dy * dy)
end

function Lerp(a, b, t)
	return (a + ((b - a)*t))
end

function GetClosestPointToCursor(tbl)
	local closestPoint = nil
	local closestDist = math.huge
	for i = 1, #tbl do
		point = tbl[i]
		local dist = GetDistance2D(point:To2D(), cursorPos)
		if(dist <= closestDist) then	
			closestPoint = point
			closestDist = dist
		end
	end
	return closestPoint
end

function GetClosestUnitToCursor(units)
	local closestUnit = nil
	local closestDist = math.huge

	if #units == 1 then return units[1] end

	for i = 1, #units do
		if(IsValid(units[i])) then
			local point = units[i].pos
			local dist = GetDistance2D(point:To2D(), cursorPos)
			if(dist <= closestDist) then	
				closestUnit = units[i]
				closestDist = dist
			end
		end
	end
	return closestUnit
end

function GetTarget(range) 
	if _G.SDK then
		if myHero.ap > myHero.totalDamage then
			return _G.SDK.TargetSelector:GetTarget(range, _G.SDK.DAMAGE_TYPE_MAGICAL);
		else
			return _G.SDK.TargetSelector:GetTarget(range, _G.SDK.DAMAGE_TYPE_PHYSICAL);
		end
	end
end

--Returns a sorted list of GGOrbwalker Targets

-- UwU
function GetTargets(range) 

	if _G.SDK then

		if myHero.ap > myHero.totalDamage then
			return _G.SDK.TargetSelector:GetTargets(range, _G.SDK.DAMAGE_TYPE_MAGICAL);
		else
			return _G.SDK.TargetSelector:GetTargets(range, _G.SDK.DAMAGE_TYPE_PHYSICAL);
		end

	end

end

function GetMode()   
    if _G.SDK then
        return 
		_G.SDK.Orbwalker.Modes[_G.SDK.ORBWALKER_MODE_COMBO] and "Combo"
        or 
		_G.SDK.Orbwalker.Modes[_G.SDK.ORBWALKER_MODE_HARASS] and "Harass"
        or 
		_G.SDK.Orbwalker.Modes[_G.SDK.ORBWALKER_MODE_LANECLEAR] and "LaneClear"
        or 
		_G.SDK.Orbwalker.Modes[_G.SDK.ORBWALKER_MODE_JUNGLECLEAR] and "LaneClear"
        or 
		_G.SDK.Orbwalker.Modes[_G.SDK.ORBWALKER_MODE_LASTHIT] and "LastHit"
        or 
		_G.SDK.Orbwalker.Modes[_G.SDK.ORBWALKER_MODE_FLEE] and "Flee"
		or nil
    
	elseif _G.PremiumOrbwalker then
		return _G.PremiumOrbwalker:GetMode()
	end
	return nil
end

function SetAttack(bool)
	if _G.EOWLoaded then
		EOW:SetAttacks(bool)
	elseif _G.SDK then                                                        
		_G.SDK.Orbwalker:SetAttack(bool)
	elseif _G.PremiumOrbwalker then
		_G.PremiumOrbwalker:SetAttack(bool)	
	else
		GOS.BlockAttack = not bool
	end

end

function SetMovement(bool)
	if _G.EOWLoaded then
		EOW:SetMovements(bool)
	elseif _G.SDK then
		_G.SDK.Orbwalker:SetMovement(bool)
	elseif _G.PremiumOrbwalker then
		_G.PremiumOrbwalker:SetMovement(bool)	
	else
		GOS.BlockMovement = not bool
	end
end

function CheckLoadedEnemies()
	local count = 0
	for i, unit in ipairs(Enemies) do
        if unit and unit.isEnemy then
		count = count + 1
		end
	end
	return count
end

function GetEnemyHeroes()
	return Enemies
end

function GetEnemyTurrets()
	return Turrets
end

function GetFriendlyTurrets()
	return FriendlyTurrets
end

function GetClosestFriendlyTurret()
	local closestTurret = nil
	local closestDist = math.huge
	for _, turret in pairs(FriendlyTurrets) do
		if(turret and IsValid(turret) and not turret.dead) then
			local checkDist = myHero.pos:DistanceTo(turret.pos)
			if(checkDist <= closestDist) then
				closestDist = checkDist
				closestTurret = turret
			end
		end
	end
	return closestTurret
end
function GetClosestEnemyTurret()
	local closestTurret = nil
	local closestDist = math.huge
	for _, turret in pairs(Turrets) do
		if(turret and IsValid(turret) and not turret.dead) then
			local checkDist = myHero.pos:DistanceTo(turret.pos)
			if(checkDist <= closestDist) then
				closestDist = checkDist
				closestTurret = turret
			end
		end
	end
	return closestTurret
end

function GetEnemyMinionsUnderTurret(turret)
	local turretMinions = {}
	if(turret and IsValid(turret) and not turret.dead) then
		local minions = _G.SDK.ObjectManager:GetEnemyMinions(750 + myHero.range)
		for _, minion in pairs(minions) do
			if(minion and IsValid(minion)) then
				if(minion.pos:DistanceTo(turret.pos) < (turret.boundingRadius + 750 + minion.boundingRadius / 2 + 100)) then
					table.insert(turretMinions, minion)
				end
			end
		end
	end
	return turretMinions
end

local targetCachedNetID = 0
local cachedTarget = nil

function GetTurretMinionTarget(turret, minions)
	if(turret.targetID == targetCachedNetID) then
		return cachedTarget
	end
	for _, minion in pairs(minions) do
		if(turret.targetID == minion.networkID) then
			targetCachedNetID = minion.networkID
			cachedTarget = minion
			return cachedTarget
		end
	end
	return nil
end

function GetEnemyHeroes(range, bbox)
	local result = {}
	for _, unit in ipairs(Enemies) do
		if(IsValid(unit)) then
			local extrarange = bbox and unit.boundingRadius or 0
			if unit.distance < range + extrarange then
				table.insert(result, unit)
			end
		end
	end
	return result
end

function GetAllyHeroes(range, bbox)
	local result = {}
	for _, unit in ipairs(Allies) do
		if(IsValid(unit) and unit.networkID ~= myHero.networkID) then
			local extrarange = bbox and unit.boundingRadius or 0
			if unit.distance < range + extrarange then
				table.insert(result, unit)
			end
		end
	end
	return result
end

function IsUnderTurret(unit)
    local boundingRadius = unit.boundingRadius or 0
    local unitpos = unit.pos or unit
    for i, turret in ipairs(GetEnemyTurrets()) do
        local range = (turret.boundingRadius + 750 + boundingRadius / 2)
        if not turret.dead then 
            if turret.pos:DistanceTo(unitpos) < range then
                return true
            end
        end
    end
    return false
end

function IsPositionUnderTurret(pos)
	for i, turret in ipairs(GetEnemyTurrets()) do
        local range = (turret.boundingRadius + 750)
        if not turret.dead then 
            if turret.pos:DistanceTo(pos) < range then
                return true
            end
        end
    end
    return false
end

function IsTurretDiving(pos)
	if(IsPositionUnderTurret(myHero.pos) == false and IsPositionUnderTurret(pos) == true) then
		return true
	end

	return false
end

function IsUnderFriendlyTurret(unit)
	for i, turret in ipairs(GetFriendlyTurrets()) do
        local range = (turret.boundingRadius + 750 + unit.boundingRadius / 2)
        if not turret.dead then 
            if turret.pos:DistanceTo(unit.pos) < range then
                return true, turret
            end
        end
    end
    return false
end

function GetTurretDamage()
	local minutes = math.min(Game.Timer()/60, 14)
	return 162 + (13 * math.floor(minutes))
end

function IsInFountain()
	local map = Game.mapID
	local posSR_Blue, posSR_Red, posHA_Blue, posHA_Red = {x = 410, y = 180, z = 416}, {x = 14296, y = 171, z = 14386}, {x = 1081, y = -130, z = 1195}, {x = 11721, y = -130, z = 11515}
	local team = myHero.team
	-- 100 = BLUE || 200 = RED
	if(map == HOWLING_ABYSS) then
		if(team == 100) then 	-- Blue
			return (myHero.pos:DistanceTo(Vector(posHA_Blue)) <= 575)
		elseif(team == 200) then								-- Red
			return (myHero.pos:DistanceTo(Vector(posHA_Red)) <= 575)
		end
	end
	
	if(map == SUMMONERS_RIFT) then
		if(team == 100) then 	-- Blue
			return (myHero.pos:DistanceTo(Vector(posSR_Blue)) <= 800)
		elseif(team == 200) then								-- Red
			return (myHero.pos:DistanceTo(Vector(posSR_Red)) <= 800)
		end
	end
	
	return false
end

function HasBuff(unit, buffname)
	for i = 0, unit.buffCount do
		local buff = unit:GetBuff(i)	

		if buff.name == buffname and buff.count > 0 then 
			return true
		end
	end
	return false
end

function HasBuffType(unit, type)
    for i = 0, unit.buffCount do
        local buff = unit:GetBuff(i)
        if buff and buff.count > 0 and buff.type == type then
            return true
        end
    end
    return false
end

function GetBuffData(unit, buffname)
	for i = 0, unit.buffCount do
    local buff = unit:GetBuff(i)
		if buff.name == buffname and buff.count > 0 then 
			return buff
		end
	end
	return {type = 0, name = "", startTime = 0, expireTime = 0, duration = 0, stacks = 0, count = 0}
end

function IsRecalling(unit)
	if(unit.isChanneling) then
		if(unit.activeSpell.valid) then
			if(unit.activeSpell.name == "recall") then
				return true 
			end
		end
	end
	
	--[[

	--This wasn't optimal to check.
	
	local buff = GetBuffData(unit, "recall")
	if buff and buff.duration > 0 then
		return true, GameTimer() - buff.startTime
	end
	--]]

    return false
end

function IsImmobile(unit, recallOption)
    local MaxDuration = 0
    for i = 0, unit.buffCount do
        local buff = unit:GetBuff(i)
        if buff and buff.count > 0 then
            local BuffType = buff.type
            if BuffType == 5 or BuffType == 12 or BuffType == 11 or BuffType == 22 or BuffType == 35 or BuffType == 25 or BuffType == 29 then
                local BuffDuration = buff.duration
                if BuffDuration > MaxDuration then
                    MaxDuration = BuffDuration
                end
            end
			
			if(recallOption) then
				if(buff.name == "recall") then
					local BuffDuration = buff.duration
					if BuffDuration > MaxDuration then
						MaxDuration = BuffDuration
					end
				end
			end
        end
    end
    return MaxDuration
end

function IsHardCCd(unit)
    local MaxDuration = 0
    for i = 0, unit.buffCount do
        local buff = unit:GetBuff(i)
        if buff and buff.count > 0 then
            local BuffType = buff.type
            if BuffType == 5 or BuffType == 8 or BuffType == 10 or BuffType == 12 or BuffType == 22 or BuffType == 23  or BuffType == 35 or BuffType == 34 or BuffType == 25 or BuffType == 29 then
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

function IsChainable(unit)
    local MaxDuration = 0
    for i = 0, unit.buffCount do
        local buff = unit:GetBuff(i)
        if buff and buff.count > 0 then
            local BuffType = buff.type
            if BuffType == 5 or BuffType == 8 or BuffType == 9 or BuffType == 11 or BuffType == 21 or BuffType == 22 or BuffType == 24 or BuffType == 31 or BuffType == 10 then
                local BuffDuration = buff.duration
                if BuffDuration > MaxDuration then
                    MaxDuration = BuffDuration
                end
            end
        end
    end
    return MaxDuration
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

function ClosestPointOnLineSegment(p, p1, p2)
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
	local result = {x = ax + t * bxax, z = az + t * bzaz}
    return result, true
end

function IsInRange(v1, v2, range)
	v1 = v1.pos or v1
	v2 = v2.pos or v2
	local dx = v1.x - v2.x
	local dz = (v1.z or v1.y) - (v2.z or v2.y)
	if dx * dx + dz * dz <= range * range then
		return true
	end
	return false
end

function GetEnemyCount(range, pos)
    local pos = pos.pos
	local count = 0
	for i = 1, GameHeroCount() do 
	local hero = GameHero(i)
	local Range = range * range
		if hero.team ~= TEAM_ALLY and GetDistanceSqr(pos, hero.pos) < Range and IsValid(hero) then
		count = count + 1
		end
	end
	return count
end

function GetEnemyCountAtPos(checkrange, range, pos)
    local enemies = _G.SDK.ObjectManager:GetEnemyHeroes(checkrange)
    local count = 0
    for i = 1, #enemies do 
        local enemy = enemies[i]
        local Range = range * range
        if GetDistanceSqr(pos, enemy.pos) < Range and IsValid(enemy) then
            count = count + 1
        end
    end
    return count
end

function GetEnemiesAtPos(checkrange, range, pos, target)
    local enemies = _G.SDK.ObjectManager:GetEnemyHeroes(checkrange)
	local results = {}
    for i = 1, #enemies do 
        local enemy = enemies[i]
        local Range = range * range
        if GetDistanceSqr(pos, enemy.pos) < Range and IsValid(enemy) and enemy ~= target then
			table.insert(results, enemy)
        end
    end
	
	table.insert(results, target)
    return results
end

function GetMinionCount(checkrange, range, pos)
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

function GetMinionsAroundMinion(checkrange, range, minion)
    local minions = _G.SDK.ObjectManager:GetEnemyMinions(checkrange)
	local results = {}
    for i = 1, #minions do 
        local m = minions[i]
        local Range = range * range
        if GetDistanceSqr(minion.pos, m.pos) < Range and IsValid(minion) and (m ~= minion) then
			table.insert(results, m)
        end
    end
	return results
end

function GetTableMinionsAroundMinion(tableMinions, range, minion)
	local results = {}
    for i = 1, #tableMinions do 
        local m = tableMinions[i]
        local Range = range * range
        if GetDistanceSqr(minion.pos, m.pos) < Range and IsValid(minion) and (m ~= minion) then
			table.insert(results, m)
        end
    end
	return results
end

function GetMinionsAroundPosition(checkrange, range, pos)
    local minions = _G.SDK.ObjectManager:GetEnemyMinions(checkrange)
	local results = {}
    for i = 1, #minions do 
        local m = minions[i]
        local Range = range * range
        if GetDistanceSqr(pos, m.pos) < Range then
			table.insert(results, m)
        end
    end
	return results
end

function GetCanonMinion(minions)
	for i = 1, #minions do
		local minion = minions[i]
		if(IsValid(minion)) then
			if (minion.charName == "SRU_ChaosMinionSiege" or minion.charName == "SRU_OrderMinionSiege") then
				return minion
			end
		end
	end
	
	return nil
end

function GetMinionByHandle(handle)
	local cachedminions = _G.SDK.ObjectManager:GetMinions()
	for i = 1, #cachedminions do
		local obj = cachedminions[i]
		if(obj.handle == handle) then
			return obj
		end
	end
	
	return nil
end

function GetMinionType(minion)
	if (minion.charName:find("ChaosMinionSiege")  or minion.charName:find("OrderMinionSiege")) then
		return MINION_CANON
	end
	
	if (minion.charName:find("ChaosMinionRanged")  or minion.charName:find("OrderMinionRanged")) then
		return MINION_CASTER
	end
	
	if (minion.charName:find("ChaosMinionMelee")  or minion.charName:find("OrderMinionMelee")) then
		return MINION_MELEE
	end
	
	return -1
end

function GetMinionTurretDamage(minion)
	if(GetMinionType(minion) == MINION_CASTER) then
		return minion.maxHealth * 0.7
	end

	if(GetMinionType(minion) == MINION_MELEE) then
		return minion.maxHealth * 0.45
	end
	
	return GetTurretDamage()
end

function AverageClusterPosition(targets)
	local finalPos = {x = 0, z = 0}
	for _, target in pairs(targets) do
		finalPos.x = finalPos.x + target.pos.x
		finalPos.z = finalPos.z + target.pos.z
	end
	
	finalPos.x = finalPos.x / #targets
	finalPos.z = finalPos.z / #targets
	
	local point = Vector(finalPos.x, myHero.pos.y, finalPos.z)
	return point
end

-- 2D dot product of two normalized vectors
function dotProduct( a, b )
        -- multiply the x's, multiply the y's, then add
		local mag1 = a
		local mag2 = b
		mag1.y = a.y or a.z or 0
		mag2.y = b.y or b.z or 0
        local dot = (mag1.x * mag2.x + mag1.y * mag2.y)
        return dot
end

-- 3D dot product of two normalized vectors
function dotProduct3D( a, b )
        -- multiply the x's, multiply the y's, then add
        local dot = (a.x * b.x + a.y * b.y + a.z * b.z)
        return dot
end

function CalculateBoundingBoxAvg(targets, predSpeed, predDelay)
	local highestX, lowestX, highestZ, lowestZ = 0, math.huge, 0, math.huge
	local avg = {x = 0, y = 0, z = 0}
	for k, v in pairs(targets) do
		local vPos = v.pos
		if(predDelay) then
			if(predDelay > 0) then
				vPos = v:GetPrediction(predSpeed, predDelay)
			end
		end
		
		if(vPos.x >= highestX) then
			highestX = vPos.x
		end
		
		if(vPos.z >= highestZ) then
			highestZ = vPos.z
		end
		
		if(vPos.x < lowestX) then
			lowestX = vPos.x
		end
		
		if(vPos.z < lowestZ) then
			lowestZ = vPos.z
		end
	end
	
	local vec1 = Vector(highestX, myHero.pos.y, highestZ)
	local vec2 = Vector(highestX, myHero.pos.y, lowestZ)
	local vec3 = Vector(lowestX, myHero.pos.y, highestZ)
	local vec4 = Vector(lowestX, myHero.pos.y, lowestZ)
	
	avg = (vec1 + vec2 + vec3 + vec4) /4
	
	return avg
end

function FindFurthestTargetFromMe(targets)	
	local furthestTarget = targets[1]
	local furthestDist = 0
	for _, target in pairs(targets) do
		local dist = myHero.pos:DistanceTo(target.pos)
		if(dist >= furthestDist) then
			furthestTarget = target
			furthestDist = dist
		end
	end
	
	return furthestTarget
end

function MyHeroNotReady()
    return myHero.dead or Game.IsChatOpen() or (_G.JustEvade and _G.JustEvade:Evading()) or (_G.ExtLibEvade and _G.ExtLibEvade.Evading) or IsRecalling(myHero)
end

function CheckDmgItems(itemID)
    assert(type(itemID) == "number", "GetInventorySlotItem: wrong argument types (<number> expected)")
    for _, j in pairs({ITEM_1, ITEM_2, ITEM_3, ITEM_4, ITEM_5, ITEM_6, ITEM_7}) do
        if myHero:GetItemData(j).itemID == itemID then 
			return j, (myHero:GetSpellData(j).currentCd == 0)
		end
    end
    return nil
end

function CalcMagicalDamage(source, target, amount)
    local passiveMod = 0

    local totalMR = target.magicResist
    if totalMR < 0 then
        passiveMod = 2 - 100 / (100 - totalMR)
    elseif totalMR * source.magicPenPercent - source.magicPen < 0 then
        passiveMod = 1
    else
        passiveMod = 100 / (100 + totalMR * source.magicPenPercent - source.magicPen)
    end

    local dmg = math.max(math.floor(passiveMod * amount), 0)
    
    if target.charName == "Kassadin" then
        dmg = dmg * 0.85
    elseif target.charName == "Malzahar" and _G.SDK.BuffManager:HasBuff(target, "malzaharpassiveshield") then
		dmg = dmg * 0.1
    end
    
    return dmg
end

function CalcPhysicalDamage(source, target, amount)
    local armorPenetrationPercent = source.armorPenPercent
    local armorPenetrationFlat = source.armorPen * (0.6 + 0.4 * source.levelData.lvl / 18)
    local bonusArmorPenetrationMod = source.bonusArmorPenPercent

    local armor = target.armor
    local bonusArmor = target.bonusArmor
    local value

    if armor < 0 then
        value = 2 - 100 / (100 - armor)
    elseif armor * armorPenetrationPercent - bonusArmor *
        (1 - bonusArmorPenetrationMod) - armorPenetrationFlat < 0 then
        value = 1
    else
        value = 100 / (100 + armor * armorPenetrationPercent - bonusArmor *
                    (1 - bonusArmorPenetrationMod) - armorPenetrationFlat)
    end
	
	local final = math.max(math.floor(value * amount), 0)
	return final
end

function CanFlash()
	local slot = nil
	local castSlot = nil
	local hasFlash = false
	if myHero:GetSpellData(SUMMONER_1).name == "SummonerFlash" or myHero:GetSpellData(SUMMONER_1).name == "SummonerCherryFlash" then
		slot = SUMMONER_1
		castSlot = HK_SUMMONER_1
		hasFlash = true
	end
	if myHero:GetSpellData(SUMMONER_2).name == "SummonerFlash" or myHero:GetSpellData(SUMMONER_2).name == "SummonerCherryFlash" then
		slot = SUMMONER_2
		castSlot = HK_SUMMONER_2
		hasFlash = true
	end

	if not hasFlash then
		return false
	end
	if myHero:GetSpellData(slot).currentCd > 0 or myHero:GetSpellData(slot).name == "SummonerCherryFlash_CD" then
		return false
	end
	if GameCanUseSpell(slot) ~= 0 then
		return false
	end

	if(Ready(slot) == false) then
		return false
	end

	return true, castSlot
end

function UseFlash(pos)
	local castAtPos = false
	if(pos) then castAtPos = true end

	if myHero:GetSpellData(SUMMONER_1).name == "SummonerFlash" or myHero:GetSpellData(SUMMONER_1).name == "SummonerCherryFlash" then
		if(castAtPos) then
			if(GetDistance(myHero, pos) > 400) then
				pos = myHero.pos:Extended(pos, 400)
			end
 			Control.CastSpell(HK_SUMMONER_1, pos)
		else
			Control.CastSpell(HK_SUMMONER_1)
		end
	end
	if myHero:GetSpellData(SUMMONER_2).name == "SummonerFlash" or myHero:GetSpellData(SUMMONER_2).name == "SummonerCherryFlash" then
		if(castAtPos) then
			if(GetDistance(myHero, pos) > 400) then
				pos = myHero.pos:Extended(pos, 400)
			end
			Control.CastSpell(HK_SUMMONER_2, pos)
		else
			Control.CastSpell(HK_SUMMONER_2)
		end
	end
end

function CanUseSummoner(unit, name)
	if myHero:GetSpellData(SUMMONER_1).name == name and Ready(SUMMONER_1) then
		return true
	elseif myHero:GetSpellData(SUMMONER_2).name == name and Ready(SUMMONER_2) then
		return true
	end
	
	return false
end

function IsPointLeftOfLine(a, b, c)
	local d = (c.x - a.x)*(b.z - a.z) - (c.z - a.z)*(b.x - a.x)
	return d < 0
end

function GetAngle(v1, v2)
	local vec1 = v1:Len()
	local vec2 = v2:Len()
	local Angle = math.abs(math.deg(math.acos((v1*v2)/(vec1*vec2))))
	return Angle
end

function IsInCone(enemy, castPos, distance, angle, optionalStartOffset)
	optionalStartOffset = optionalStartOffset or 0
	local refPos = myHero.pos
	if(optionalStartOffset > 0) then
		refPos = castPos:Extended(myHero.pos, GetDistance(myHero.pos, castPos) + optionalStartOffset)
	end
	local vec1 = Vector(castPos - refPos):Normalized()
	local vec2 = Vector(enemy.pos - refPos):Normalized()
	if(GetDistance(myHero, enemy) < distance and GetAngle(vec1, vec2) <= angle) then
		return true
	end

	return false
end

function GetCircleIntersectionPoints(p1, p2, center, radius)
	local sect = {[0] = {0, 0, 0}, [1] = {0, 0, 0}}
	local dp = {x = 0, y = 0, z = 0}
    local a, b, c
    local bb4ac
    local mu1
    local mu2
	
     dp.x   = p2.x - p1.x
     dp.z   = p2.z - p1.z

     a = dp.x * dp.x + dp.z * dp.z
     b = 2 * (dp.x * (p1.x - center.x) + dp.z * (p1.z - center.z))
     c = center.x* center.x + center.z * center.z
     c = c + p1.x * p1.x + p1.z * p1.z
     c = c - 2 * (center.x * p1.x + center.z * p1.z)
     c = c - radius * radius
     bb4ac  = b * b - 4 * a * c
     if(math.abs(a) < 0 or bb4ac < 0) then
         return sect
     end
	
     mu1 = (-b + math.sqrt(bb4ac)) / (2 * a)
     mu2 = (-b - math.sqrt(bb4ac)) / (2 * a)
	 
     sect[0] = {p1.x + mu1 * (p2.x - p1.x), 0, p1.z + mu1 * (p2.z - p1.z)}
     sect[1] = {p1.x + mu2 * (p2.x - p1.x), 0, p1.z + mu2 * (p2.z - p1.z)}
     
     return sect;
end

--This is a helper function that will use GGPrediction to find a suitable area to cast area spells outside of their default range - AKA edge casting
function GetExtendedSpellPrediction(target, spellData)
	local isExtended = false
	local extendedSpellData = {Type = spellData.Type, Delay = spellData.Delay, Range = spellData.Range + spellData.Radius, Radius = spellData.Radius, Speed = spellData.Speed, Collision = spellData.Collision}
	local spellPred = GGPrediction:SpellPrediction(extendedSpellData)
	local predVec = Vector(0, 0, 0)
	spellPred:GetPrediction(target, myHero)
	--Get the extended predicted position, and the cast range of the spell
	if(spellPred.CastPosition) then
		predVec = Vector(spellPred.CastPosition.x, myHero.pos.y, spellPred.CastPosition.z)
		if(myHero.pos:DistanceTo(predVec) < spellData.Range) then
			return spellPred, isExtended
		end
	end
	local defaultRangeVec = (predVec - myHero.pos):Normalized() * spellData.Range + myHero.pos
	--DrawCircle(testVec, 150, 3)
	--Find the difference between these two points as a vector to create a line, and then find a perpendicular bisecting line at the extended cast position using this line
	--local vec = (predVec - defaultRangeVec):Normalized() * 100 + myHero.pos
	local vecNormal = (predVec - defaultRangeVec):Normalized()
	local perp = Vector(vecNormal.z, 0, -vecNormal.x) * spellData.Radius + predVec
	local negPerp = Vector(-vecNormal.z, 0, vecNormal.x) * spellData.Radius + predVec

	--Find the points of intersection from our bisecting line to the radius of our spell at its cast range. 
	-- We can use this data to find a more precise circle, and make sure that our prediction will hit that.
	-- If our prediction hits the precise circle, that means our spell will hit if its extended
	-- This is really difficult to explain but much easier to visualize with diagrams
	local intersections = GetCircleIntersectionPoints(perp, negPerp, defaultRangeVec, spellData.Radius)
	
	--We only need one of the intersection points to form our precise circle
	local intVec = Vector(intersections[0][1], myHero.pos.y, intersections[0][3])
	--local halfVec = Vector((intersections[0][1] + intersections[1][1]) /2, myHero.pos.y, (intersections[0][3] + intersections[1][3])/2)
	
	local preciseCircRadius = intVec:DistanceTo(predVec)
	local preciseSpellData = {Type = spellData.Type, Delay = spellData.Delay, Range = spellData.Range + spellData.Radius, Radius = preciseCircRadius, Speed = spellData.Speed, Collision = spellData.Collision}
	local preciseSpellPred = GGPrediction:SpellPrediction(preciseSpellData)
	isExtended = true
	preciseSpellPred:GetPrediction(target, myHero)

	return preciseSpellPred, isExtended
end

function CalculateBestCirclePosition(targets, radius, edgeDetect, spellRange, spellSpeed, spellDelay)
	local avgCastPos = CalculateBoundingBoxAvg(targets, spellSpeed, spellDelay)
	local newCluster = {}
	local distantEnemies = {}

	for _, enemy in pairs(targets) do
		if(enemy.pos:DistanceTo(avgCastPos) > radius) then
			table.insert(distantEnemies, enemy)
		else
			table.insert(newCluster, enemy)
		end
	end
	
	if(#distantEnemies > 0) then
		local closestDistantEnemy = nil
		local closestDist = 10000
		for _, distantEnemy in pairs(distantEnemies) do
			local dist = distantEnemy.pos:DistanceTo(avgCastPos)
			if( dist < closestDist ) then
				closestDistantEnemy = distantEnemy
				closestDist = dist
			end
		end
		if(closestDistantEnemy ~= nil) then
			table.insert(newCluster, closestDistantEnemy)
		end
		
		--Recursion, we are discarding the furthest target and recalculating the best position
		if(#newCluster ~= #targets) then
			return CalculateBestCirclePosition(newCluster, radius)
		end
	end
	
	if(edgeDetect) and myHero.pos:DistanceTo(avgCastPos) > spellRange then

		local checkPos = myHero.pos:Extended(avgCastPos, spellRange)
		local furthestTarget = FindFurthestTargetFromMe(newCluster)
		local fakeMyHeroPos = avgCastPos:Extended(myHero.pos, spellRange + radius - 50)
		if(furthestTarget ~= nil) then
			fakeMyHeroPos = avgCastPos:Extended(myHero.pos, spellRange + radius - furthestTarget.pos:DistanceTo(avgCastPos))
		end

		if(myHero.pos:DistanceTo(avgCastPos) >= fakeMyHeroPos:DistanceTo(avgCastPos)) then
			checkPos = fakeMyHeroPos:Extended(avgCastPos, spellRange)
		end
		
		local hitAllCheck = true
		for _, v in pairs(newCluster) do
			if(v:GetPrediction(math.huge, spellDelay):DistanceTo(checkPos) >= radius + 5) then -- the +5 is to fix a precision issue
				hitAllCheck = false
			end
		end
		
		if hitAllCheck then 
			return checkPos, #newCluster, newCluster
		end

	end
	
	return avgCastPos, #targets, targets
end

function CalculateBestLinePosition(targets, radius, spellRange, spellSpeed, spellDelay)
	local avgCastPos = CalculateBoundingBoxAvg(targets, spellSpeed, spellDelay)
	local newCluster = {}
	local distantEnemies = {}

	local lineEndPos = myHero.pos:Extended(avgCastPos, spellRange)
	
	for _, enemy in pairs(targets) do
		local ePredPos = GGPrediction:SpellPrediction({Type = GGPrediction.SPELLTYPE_LINE, Delay = spellDelay, Range = spellRange, Radius = radius, Speed = spellSpeed})
		ePredPos:GetPrediction(enemy, myHero)
		if(ePredPos.CastPosition) then
			ePredPos = Vector(ePredPos.CastPosition.x, enemy.pos.y, ePredPos.CastPosition.z)
		else
			ePredPos = enemy.pos
		end

		local point, isOnSegment = ClosestPointOnLineSegment(ePredPos, myHero.pos, lineEndPos)
		if(ePredPos:DistanceTo(point) > radius) then
			table.insert(distantEnemies, enemy)
		else
			table.insert(newCluster, enemy)
		end
	end
	
	if(#distantEnemies > 0) then
		local closestDistantEnemy = nil
		local closestDist = 10000
		for _, distantEnemy in pairs(distantEnemies) do

			local dPredPos = GGPrediction:SpellPrediction({Type = GGPrediction.SPELLTYPE_LINE, Delay = spellDelay, Range = spellRange, Radius = radius, Speed = spellSpeed})
			dPredPos:GetPrediction(distantEnemy, myHero)
			if(dPredPos.CastPosition) then
				dPredPos = Vector(dPredPos.CastPosition.x, distantEnemy.pos.y, dPredPos.CastPosition.z)
			else
				dPredPos = distantEnemy.pos
			end

			local point, isOnSegment = ClosestPointOnLineSegment(dPredPos, myHero.pos, lineEndPos)
			local dist = dPredPos:DistanceTo(point)
			if( dist < closestDist ) then
				closestDistantEnemy = distantEnemy
				closestDist = dist
			end
		end
		if(closestDistantEnemy ~= nil) then
			table.insert(newCluster, closestDistantEnemy)
		end
		
		--Recursion, we are discarding the furthest target and recalculating the best position
		if(#newCluster ~= #targets) then
			return CalculateBestLinePosition(newCluster, radius)
		end
	end
	
	return avgCastPos, #targets, targets
end

--Checks to see if a unit is running towards or away from the target
function GetUnitRunDirection(unit, target)
	if(target.pathing.hasMovePath) then
		local meVec = (unit.pos - target.pos):Normalized()
		local pathVec = (target.pathing.endPos - target.pos):Normalized()
		if(dotProduct3D(meVec, pathVec) <= -0.5) then
			return RUNNING_AWAY
		else
			return RUNNING_TOWARDS
		end
	end
	return nil
end

function HasBuffType(unit, type)
    local buffs = _G.SDK.BuffManager:GetBuffs(unit)
    for i, buff in ipairs(buffs) do
        if buff and buff.count > 0 and buff.type == type then
            return true
        end
    end
    return false
end

function CantKill(unit, kill, ss, aa, sionCheck)
    -- Define conditions for each buff
	sionCheck = sionCheck ~= false

    if sionCheck and unit.charName == "Sion" and unit:GetSpellData(_Q).name == "SionPassiveSpeed" then
        return true
    end

    local buffConditions = {
        kayler = function() return true end,
        undyingrage = function() return unit.health < 100 or kill end,
        kindredrnodeathbuff = function() return kill or (unit.health / unit.maxHealth) < 0.11 end,
        chronoshift = function() return kill end,
        willrevive = function() return (unit.health / unit.maxHealth) >= 0.5 and kill end,
        morganae = function() return ss end,
        fioraw = true,
        pantheone = true,
        jaxe = function() return aa end,
        nilahw = function() return aa end,
        shenwbuff = function() return aa end
    }

    -- Get buffs using SDK
    local buffs = _G.SDK.BuffManager:GetBuffs(unit)

    -- Iterate through buffs
    for _, buff in ipairs(buffs) do
        if buff.count > 0 then
            local buffName = buff.name:lower()

			if(sionCheck) then
				if buffName == "sionpassivezombie" then
					return true
				end
			end

            -- Check conditions for each buff in table
            for buffKey, buffCondition in pairs(buffConditions) do
                if buffName:find(buffKey) and (type(buffCondition) == 'boolean' or buffCondition()) then
                    return true
                end
            end
        end
    end

    -- Additional condition check
    if HasBuffType(unit, 4) and ss then
        return true
    end

    return false
end

function GetPrediction(target, spell_speed, casting_delay)
	if(not IsValid(target)) then return end
	local caster_position = myHero.pos
	local target_position = target.pos
	local direction_vector = target.pathing.hasMovePath and (target:GetPath(target.pathing.pathIndex) - target_position):Normalized() or target.dir
	local movement_speed = target.ms
	
	-- Normalize direction_vector
	local magnitude = math.sqrt(direction_vector.x^2 + direction_vector.z^2)
	local normalized_direction_vector = {x = direction_vector.x / magnitude, z = direction_vector.z / magnitude}

	if(target.pathing.hasMovePath and target.pathing.isDashing) then
		return Vector(target.pathing.endPos), Vector(target.pathing.endPos)
	end
	
	-- Target velocity vector
	local target_velocity = {x = normalized_direction_vector.x * movement_speed, z = normalized_direction_vector.z * movement_speed}

	-- If the spell_speed is math.huge (i.e., the spell travels instantaneously), return the predicted target_position after casting_delay
	if spell_speed == math.huge then
		return {x = target_position.x + target_velocity.x * casting_delay, z = target_position.z + target_velocity.z * casting_delay}
	end

	-- Calculate difference in positions
	local delta_position = {x = target_position.x - caster_position.x, z = target_position.z - caster_position.z}

	-- Quadratic equation coefficients
	local a = (target_velocity.x^2 + target_velocity.z^2) - spell_speed^2
	local b = 2 * (delta_position.x * target_velocity.x + delta_position.z * target_velocity.z)
	local c = delta_position.x^2 + delta_position.z^2

	-- Discriminant
	local discriminant = b^2 - 4*a*c

	-- If the discriminant is negative, no real solution exists
	if discriminant < 0 then
		return nil
	end

	-- Find the two possible solutions
	local t1 = (-b + math.sqrt(discriminant)) / (2 * a)
	local t2 = (-b - math.sqrt(discriminant)) / (2 * a)

	-- We want the smallest positive t (if it exists)
	local t = nil
	if t1 > 0 and t2 > 0 then
		t = math.min(t1, t2)
	elseif t1 > 0 then
		t = t1
	elseif t2 > 0 then
		t = t2
	end

	if t == nil then
		return nil
	end

	-- Compute the interception point
	local interception_point = {
		x = target_position.x + target_velocity.x * t,
		y = target_position.y,
		z = target_position.z + target_velocity.z * t
	}

	return Vector(interception_point)
end

function GetPredictionPrecise(target, spell_speed, casting_delay, spell_radius, Circular)
	local latency = _G.LATENCY > 1 and _G.LATENCY * 0.001 or _G.LATENCY
	casting_delay = casting_delay + latency
	local caster_position = myHero.pos
	local target_position = target.pos
	local direction_vector = target.pathing.hasMovePath and (target:GetPath(target.pathing.pathIndex) - target_position):Normalized() or target.dir
	local movement_speed = target.pathing.hasMovePath and target.ms or 0
 	local target_radius = Circular and 0 or target.boundingRadius
	-- Normalize direction_vector
	local magnitude = math.sqrt(direction_vector.x^2 + direction_vector.z^2)
	local normalized_direction_vector = {x = direction_vector.x / magnitude, z = direction_vector.z / magnitude}
	-- Target velocity vector
	local target_velocity = {x = normalized_direction_vector.x * movement_speed, z = normalized_direction_vector.z * movement_speed}
  
	-- Calculate difference in positions
	local delta_position = {x = target_position.x - caster_position.x, z = target_position.z - caster_position.z}
  
	if(target.pathing.hasMovePath and target.pathing.isDashing) then
		--If the time it takes for the target to dash to its end position is LESS than the time it takes for our spell to reach that position, we can cast at the dash end position.
		if (GetDistance(target.pos,target.pathing.endPos)/target.pathing.dashSpeed) < (GetDistance(caster_position, target.pathing.endPos)/spell_speed + casting_delay) then
			return Vector(target.pathing.endPos), Vector(target.pathing.endPos)
		end
	end

	local function adjustPosition(position, t)
		local delay = t or casting_delay
		local potential_adjusted_position = {
			x = position.x - normalized_direction_vector.x * (spell_radius),
			y = position.y,
			z = position.z  - normalized_direction_vector.z * (spell_radius)
		}
		local potential_adjusted_position2 = {
		  x = target_position.x + target_velocity.x * (latency+0.1),
		  y = target_position.y,
		  z = target_position.z  + target_velocity.z *(latency+0.1) 
	  	}
		local distance_target_would_travel = movement_speed * delay
		return distance_target_would_travel < (spell_radius + target_radius + 20) and potential_adjusted_position2 or potential_adjusted_position
	end
	-- If the spell_speed is math.huge (i.e., the spell travels instantaneously), return the predicted target_position after casting_delay
	if spell_speed == math.huge then
		local target_position = {
			x = target_position.x + target_velocity.x * casting_delay,
			y = target_position.y,
			z = target_position.z + target_velocity.z * casting_delay
		}
		return Vector(adjustPosition(target_position)), target_position
	end
  
	-- Quadratic equation coefficients
	local a = (target_velocity.x^2 + target_velocity.z^2) - spell_speed^2
	local b = 2 * (delta_position.x * target_velocity.x + delta_position.z * target_velocity.z)
	local c = delta_position.x^2 + delta_position.z^2
  
	-- Discriminant
	local discriminant = b^2 - 4*a*c
  
	-- If the discriminant is negative, no real solution exists
	if discriminant < 0 then
		return nil
	end
  
	-- Find the smallest positive solution
	local t = (function()
		local t1 = (-b + math.sqrt(discriminant)) / (2 * a)
		local t2 = (-b - math.sqrt(discriminant)) / (2 * a)
		if t1 > 0 and t2 > 0 then
			return math.min(t1, t2)
		elseif t1 > 0 then
			return t1
		elseif t2 > 0 then
			return t2
		end
	end)()
  
	if not t then
		return nil
	end
  
	-- Compute the interception point
	t=t+casting_delay
	local interception_point = {
		x = target_position.x + target_velocity.x * t,
		y = target_position.y,
		z = target_position.z + target_velocity.z * t
	}

	return Vector(adjustPosition(interception_point, t)), interception_point
end

function GetPredictedPathPosition(target, delay)
	local target_position = target.pos
	local direction_vector = target.dir
	local movement_speed = target.ms

	if target.pathing.hasMovePath ==false then
	movement_speed=0.1
	end

	if(target.pathing.hasMovePath) then
		direction_vector = (target.pathing.endPos - target.pos):Normalized()
	end

	local magnitude = math.sqrt(direction_vector.x^2 + direction_vector.z^2)
	local normalized_direction_vector = {x = direction_vector.x / magnitude, z = direction_vector.z / magnitude}
	local target_velocity = {x = normalized_direction_vector.x * movement_speed, z = normalized_direction_vector.z * movement_speed}

	return Vector({x = target_position.x + target_velocity.x * delay, y=target_position.y, z = target_position.z + target_velocity.z * delay})
end

-- A variant of CastSpell that checks if spells are on screen
function CastSpell(key, a, b, c)

	local function GetControlPos(a, b, c)
		local pos
		if a and b and c then
			pos = { x = a, y = b, z = c }
		elseif a and b then
			pos = { x = a, y = b }
		elseif a then
			pos = a.pos or a
		end
		return pos
	end

	local function CastKey(key)
		if key == MOUSEEVENTF_RIGHTDOWN then
			Control.KeyDown(HK_TCO)
			Control.mouse_event(MOUSEEVENTF_RIGHTDOWN)
			Control.mouse_event(MOUSEEVENTF_RIGHTUP)
		else
		Control.KeyDown(HK_TCO)
			Control.KeyDown(key)
			Control.KeyUp(key)
	
		end
	end

	local pos = GetControlPos(a, b, c)
	if pos then
		if _G.SDK.Cursor.Step > 0 then
			return false
		end

		--Off-screen casting fix
		if not (Vector(pos):To2D().onScreen) then return false end
		
		if not b and a.pos then
			_G.SDK.Cursor:Add(key, a)
		else
			_G.SDK.Cursor:Add(key, pos)
		end
		return true
	end

	if not a then
		CastKey(key)
		return true
	end

	return false
end

function OffsetInWallPosition(pos, spell_radius, weight)
	if(MapPosition:inWall(pos) == nil) then
		local radius = spell_radius
		local accuracy = 8

		local tbl = {}
		for i = 1, accuracy do
			local vec = Vector(0, 0, 1):Rotated(0, math.rad((360/accuracy) * i), 0) * radius
			local intersectionPoint = MapPosition:getIntersectionPoint3D(pos, pos + vec)
			if(intersectionPoint) then
				local closestPt = ClosestPointOnLineSegment(intersectionPoint, pos, pos + vec)
				closestPt = Vector(closestPt.x, intersectionPoint.y, closestPt.z)
				if((closestPt - (pos+vec)) ~= Vector(0,0,0)) then
					table.insert(tbl, (closestPt - (pos+vec)):Normalized() * GetDistance(pos + vec, closestPt)*weight)
				end
			end
		end

		if #tbl > 0 then
			local finalVec = Vector(0, 0, 0)
			for _, data in ipairs(tbl) do
				finalVec = finalVec + data
			end
			finalVec = finalVec/#tbl

			if(finalVec) then
				return pos + finalVec
			end
		end
	end

	return pos
end

function CastPredictedSpell(args)

	local hotkey = args.Hotkey
	local target = args.Target 
	local SpellData = args.SpellData
	local extendedCheck = args.ExtendedCheck or false
	local maxCollision = args.maxCollision or 0
	local splashCollision = args.CheckSplashCollision or false
	local splashCollisionRadius = args.SplashCollisionRadius or 0
	local useHeroCollision = args.UseHeroCollision or false
	local checkTerrain = args.CheckTerrain or false
	local terrainOffsetWeight = args.TerrainCorrectionWeight or 0.8
	local collisionRadiusOverride = args.collisionRadiusOverride or SpellData.Radius or 0
	local ignoreUnkillable = args.IgnoreUnkillable ~= false
	local ignoreSS = args.IgnoreSpellshields or false
	local ignoreAA = args.IgnoreAAImmune or false
	local validcheck = args.ValidCheck or false
	local ggpred = args.GGPred or false
	local strafecheck = args.StrafePred ~= false
	local killerpred = args.KillerPred ~= false
	local interpolatedPred = args.InterpolatedPred or false --A subset of KillerPred that will cast the spell at the exact path point the unit and spell will meet.
	local offscreenLinearSkillshots = args.offscreenLinearSkillshots ~= false
	local returnpos = args.ReturnPos or false

	local function CastSpell(hotkey, position)

		if(checkTerrain) then
			local inWallCheck = (MapPosition:inWall(position) == 1)
			if(inWallCheck) then
				return false
			end
			
			local correctedPosition = OffsetInWallPosition(position, collisionRadiusOverride, terrainOffsetWeight)
			if(correctedPosition and GetDistance(correctedPosition, myHero.pos) <= SpellData.Range) then
				position = correctedPosition
			end
		end

		if returnpos then
			return position
		end

		if Vector(position):To2D().onScreen then
			if (ignoreUnkillable or ignoreSS or ignoreAA) == false or (CantKill(target, ignoreUnkillable, ignoreSS, ignoreAA) == false) then
				if _G.SDK.Cursor.Step == 0 then
					_G.Control.CastSpell(hotkey, position)
					return true
				end
			end
		else
			local distances = {700, 500, 300}
			if(offscreenLinearSkillshots and SpellData.Type ~= GGPrediction.SPELLTYPE_CIRCLE) then
				if (ignoreUnkillable or ignoreSS or ignoreAA) == false or (CantKill(target, ignoreUnkillable, ignoreSS, ignoreAA) == false) then
					for _, distance in ipairs(distances) do
						local extendedPosition = myHero.pos:Extended(position, distance)
						if extendedPosition:ToScreen().onScreen then
							if _G.SDK.Cursor.Step == 0 then
								_G.Control.CastSpell(hotkey, extendedPosition)      
								return true
							end
						end
					end
				end
			end
		end
	end

	if(IsValid(target) == false) then return end
	if(SpellData.Range == false) then return end

	SpellData.Speed = SpellData.Speed or math.huge
	SpellData.Delay = SpellData.Delay or 0

	local collisionTypes = {GGPrediction.COLLISION_MINION, GGPrediction.COLLISION_YASUOWALL}
	if(useHeroCollision) then
		collisionTypes = {GGPrediction.COLLISION_MINION, GGPrediction.COLLISION_ENEMYHERO, GGPrediction.COLLISION_YASUOWALL}
	end

	local function CheckCollisionAndCastSpell(pos, maxCollision, collisionTypes)
		if(maxCollision > 0) then
			local isWall, collisionObjects, collisionCount = GGPrediction:GetCollision(myHero.pos, pos, SpellData.Speed, SpellData.Delay, collisionRadiusOverride, collisionTypes, target.networkID)
			if(collisionCount < maxCollision) then
				return CastSpell(hotkey, pos)
			else
				if(splashCollision) then
					local shouldSplash = true
					for _, obj in ipairs(collisionObjects) do
						local boundingRadiusCheck = obj.pos:Extended(myHero.pos, obj.boundingRadius)
						if(GetDistance(pos, boundingRadiusCheck) > splashCollisionRadius) then
							shouldSplash = false
							break
						end
					end

					if shouldSplash then
						return CastSpell(hotkey, pos)
					end
				end
			end
		else    
			return CastSpell(hotkey, pos)
		end
	end

	if(strafecheck) then
		local isStrafing, avgPos = StrafePred:IsStrafing(target)
		local isStutterDancing, avgPos2 = StrafePred:IsStutterDancing(target)
		
		if(isStrafing) then
			if(avgPos:DistanceTo(myHero.pos) < SpellData.Range) then
				return CheckCollisionAndCastSpell(avgPos, maxCollision, collisionTypes)
			end
		end
		if(isStutterDancing) then
			if(avgPos2:DistanceTo(myHero.pos) < SpellData.Range) then
				return CheckCollisionAndCastSpell(avgPos2, maxCollision, collisionTypes)
			end
		end
	end
	
	if(extendedCheck) then
		local SpellPrediction, isExtended = GetExtendedSpellPrediction(target, SpellData)
		if(isExtended) then
			if SpellPrediction:CanHit(HITCHANCE_HIGH) then
				local result = myHero.pos:Extended(Vector(SpellPrediction.CastPosition), SpellData.Range)
				return CheckCollisionAndCastSpell(result, maxCollision, collisionTypes)
			end
		else
			local SpellPrediction = GGPrediction:SpellPrediction(SpellData)
			SpellPrediction:GetPrediction(target, myHero)
			if SpellPrediction.CastPosition and SpellPrediction:CanHit(HITCHANCE_HIGH) and GetDistance(SpellPrediction.CastPosition, myHero.pos) <= SpellData.Range then
				return CheckCollisionAndCastSpell(SpellPrediction.CastPosition, maxCollision, collisionTypes)
			end				
		end
	elseif ggpred then
		local SpellPrediction = GGPrediction:SpellPrediction(SpellData)
		SpellPrediction:GetPrediction(target, myHero)
		if SpellPrediction.CastPosition and SpellPrediction:CanHit(HITCHANCE_HIGH) and (GetDistance(SpellPrediction.CastPosition, myHero.pos) <= SpellData.Range) then
			return CheckCollisionAndCastSpell(SpellPrediction.CastPosition, maxCollision, collisionTypes)
		end
	end

	if killerpred then
		local enemyPredPos, interpolatedPos = GetPredictionPrecise(target, SpellData.Speed, SpellData.Delay, collisionRadiusOverride, SpellData.Type == GGPrediction.SPELLTYPE_CIRCLE)
		if(enemyPredPos) then
			if(interpolatedPred) then
				if(GetDistance(interpolatedPos, myHero.pos) <= SpellData.Range) then
					return CheckCollisionAndCastSpell(interpolatedPos, maxCollision, collisionTypes)
				end
			else
				if(GetDistance(enemyPredPos, myHero.pos) <= SpellData.Range) then
					return CheckCollisionAndCastSpell(enemyPredPos, maxCollision, collisionTypes)
				end
			end
		end
	end

	return false
end
