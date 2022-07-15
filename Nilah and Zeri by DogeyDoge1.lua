if not FileExist(COMMON_PATH .. "GGPrediction.lua") then
    DownloadFileAsync("https://raw.githubusercontent.com/gamsteron/GG/master/GGPrediction.lua", COMMON_PATH .. "GGPrediction.lua", function() end)
    print('GGPrediction - downloaded! Please 2xf6!')
    return
end
require('GGPrediction')
require("MapPositionGOS")

local Menu, Utils, Champion

local GG_Target, GG_Orbwalker, GG_Buff, GG_Damage, GG_Spell, GG_Object, GG_Attack, GG_Data, GG_Cursor

local HITCHANCE_NORMAL = 2
local HITCHANCE_HIGH = 3
local HITCHANCE_IMMOBILE = 4

local DAMAGE_TYPE_PHYSICAL = 0
local DAMAGE_TYPE_MAGICAL = 1
local DAMAGE_TYPE_TRUE = 2

local ORBWALKER_MODE_NONE = -1
local ORBWALKER_MODE_COMBO = 0
local ORBWALKER_MODE_HARASS = 1
local ORBWALKER_MODE_LANECLEAR = 2
local ORBWALKER_MODE_JUNGLECLEAR = 3
local ORBWALKER_MODE_LASTHIT = 4
local ORBWALKER_MODE_FLEE = 5

local TEAM_JUNGLE = 300
local TEAM_ALLY = myHero.team
local TEAM_ENEMY = 300 - myHero.team

local math_huge = math.huge
local math_pi = math.pi
local math_sqrt = assert(math.sqrt)
local math_abs = assert(math.abs)
local math_ceil = assert(math.ceil)
local math_min = assert(math.min)
local math_max = assert(math.max)
local math_pow = assert(math.pow)
local math_atan = assert(math.atan)
local math_acos = assert(math.acos)
local math_random = assert(math.random)
local table_sort = assert(table.sort)
local table_remove = assert(table.remove)
local table_insert = assert(table.insert)

local myHero = myHero
local os = os
local math = math
local Game = Game
local Timer = Game.Timer
local Vector = Vector
local Control = Control
local Draw = Draw
local table = table
local pairs = pairs
local GetTickCount = GetTickCount
local GameMinionCount     = Game.MinionCount
local GameMinion          = Game.Minion

local LastChatOpenTimer = 0

local function IsInRange(v1, v2, range)
	v1 = v1.pos or v1
	v2 = v2.pos or v2
	local dx = v1.x - v2.x
	local dz = (v1.z or v1.y) - (v2.z or v2.y)
	if dx * dx + dz * dz <= range * range then
		return true
	end
	return false
end

local function GetDistance(v1, v2)
	v1 = v1.pos or v1
	v2 = v2.pos or v2
	local dx = v1.x - v2.x
	local dz = (v1.z or v1.y) - (v2.z or v2.y)
	return math.sqrt(dx * dx + dz * dz)
end

Utils = {}

Utils.CanUseSpell = true

--Utils.CachedDistance = {}

Utils.InterruptableSpells = {
	["CaitlynAceintheHole"] = true,
	["Crowstorm"] = true,
	["DrainChannel"] = true,
	["GalioIdolOfDurand"] = true,
	["ReapTheWhirlwind"] = true,
	["KarthusFallenOne"] = true,
	["KatarinaR"] = true,
	["LucianR"] = true,
	["AlZaharNetherGrasp"] = true,
	["Meditate"] = true,
	["MissFortuneBulletTime"] = true,
	["AbsoluteZero"] = true,
	["PantheonRJump"] = true,
	["PantheonRFall"] = true,
	["ShenStandUnited"] = true,
	["Destiny"] = true,
	["UrgotSwap2"] = true,
	["VelkozR"] = true,
	["InfiniteDuress"] = true,
	["XerathLocusOfPower2"] = true,
}

function Utils:DrawTextOnHero(hero, text, color)
	local pos2D = hero.pos:To2D()
	local posX = pos2D.x - 50
	local posY = pos2D.y
	Draw.Text(text, 50, posX + 50, posY - 15, color)
end

function Utils:GetEnemyHeroes(range, bbox)
	local result = {}
	if not self.CanUseSpell then
		return result
	end
	for i, unit in ipairs(Champion.EnemyHeroes) do
		--[[if self.CachedDistance[i] == nil then
			self.CachedDistance[i] = unit.distance
		end]]
		local extrarange = bbox and unit.boundingRadius or 0
		if --[[self.CachedDistance[i]]
			unit.distance < range + extrarange
		then
			table_insert(result, unit)
		end
	end
	return result
end

function Utils:GetEnemyHeroes2(source, range, bbox)
	local result = {}
	if not self.CanUseSpell then
		return result
	end
	source = source.pos or source
	for i, unit in ipairs(Champion.EnemyHeroes) do
		local extrarange = bbox and unit.boundingRadius or 0
		if unit.pos:DistanceTo(source) < range + extrarange then
			table_insert(result, unit)
		end
	end
	return result
end

function Utils:GetEnemyHeroesInsidePolygon(range, polygon, bbox)
	local result = {}
	if not self.CanUseSpell then
		return result
	end
	for i, unit in ipairs(Champion.EnemyHeroes) do
		--[[if self.CachedDistance[i] == nil then
			self.CachedDistance[i] = unit.distance
		end]]
		local extrarange = bbox and unit.boundingRadius or 0
		if --[[self.CachedDistance[i]]
			unit.distance < range + extrarange and self:InsidePolygon(polygon, unit)
		then
			table_insert(result, unit)
		end
	end
	return result
end

function Utils:Cast(spell, target, spellprediction, hitchance)
	if not self.CanUseSpell and (target or spellprediction) then
		return false
	end
	if spellprediction == nil then
		if target == nil then
			Control.KeyDown(spell)
			Control.KeyUp(spell)
			return true
		end
		Control.CastSpell(spell, target)
		self.CanUseSpell = false
		return true
	end
	if target == nil then
		return false
	end
	spellprediction:GetPrediction(target, myHero)
	if spellprediction:CanHit(hitchance or HITCHANCE_HIGH) then
		Control.CastSpell(spell, spellprediction.CastPosition)
		self.CanUseSpell = false
		return true
	end
	return false
end

function Utils:CheckWall(from, to, distance)
	local pos1 = to + (to - from):Normalized() * 50
	local pos2 = pos1 + (to - from):Normalized() * (distance - 50)
	local point1 = { x = pos1.x, z = pos1.z }
	local point2 = { x = pos2.x, z = pos2.z }
	if MapPosition:intersectsWall(point1, point2) or (MapPosition:inWall(point1) and MapPosition:inWall(point2)) then
		return true
	end
	return false
end

function Utils:InsidePolygon(polygon, point)
	local result = false
	local j = #polygon
	point = point.pos or point
	local pointx = point.x
	local pointz = point.z or point.y
	for i = 1, #polygon do
		if polygon[i].z < pointz and polygon[j].z >= pointz or polygon[j].z < pointz and polygon[i].z >= pointz then
			if
				polygon[i].x
					+ (pointz - polygon[i].z) / (polygon[j].z - polygon[i].z) * (polygon[j].x - polygon[i].x)
				< pointx
			then
				result = not result
			end
		end
		j = i
	end
	return result
end

function Utils:IsValid(unit, range)
		if
			unit
			and unit.valid
			and unit.visible
			and unit.alive
			and unit.isTargetable
			and (range == nil or unit.distance < range)
		then
			return true
		end
		return false
	end

local SupportedChampions = {
	["Zeri"] = true,
	["Nilah"] = true
	
	
	
}

if not SupportedChampions[myHero.charName] then
	print("HHAIO - " .. myHero.charName .. " -> not supported!")
	return
end

local PermaShow

local DrawText = Draw.Text
local DrawRect = Draw.Rect
local GameResolution = Game.Resolution()
local AminoFont = Draw.Font("Arimo-Regular.ttf", "Arimo")
local ColorWhite = Draw.Color(255, 255, 255, 255)
local ColorDarkGreen = Draw.Color(255, 0, 100, 0)
local ColorDarkRed = Draw.Color(255, 139, 0, 0)
local ColorDarkBlue = Draw.Color(255, 0, 0, 139)
local ColorTransparentBlack = Draw.Color(150, 0, 0, 0)

PermaShow = {
	X = GameResolution.x * 0.074578848,
	Y = GameResolution.y * 0.914169340,
	MoveX = 0,
	MoveY = 0,
	Moving = false,
	Width = 0,
	Height = 0,
	Count = 0,
	Groups = {},
	ValidGroups = {},
	MaxTitleWidth = 0,
	MaxLabelWidth = 0,
	MaxValueWidth = 0,
	Margin = 10,
	ItemSpaceX = 75,
	ItemSpaceY = 2,
	GroupSpaceY = 12,
	PrintTitle = true,
	DefaultValueWidth = Draw.FontRect("Space", 13, AminoFont).x + 22,
	InfoPath = COMMON_PATH .. "PermaShow.save",

	UpdateGroupPosition = function(self)
		self.Height = self.Margin * 0.5
		self.Width = self.Width + self.ItemSpaceX + self.Margin * 2
		for i = 1, #self.ValidGroups do
			local group = self.ValidGroups[i]
			if PermaShow.PrintTitle then
				group.Title:UpdatePos()
			end
			for j = 1, #group.Items do
				local item = group.Items[j]
				item:UpdatePos(self.Margin)
				if j < #group.Items then
					self.Height = self.Height + self.ItemSpaceY
				end
			end
			if i < #self.ValidGroups then
				self.Height = self.Height + self.GroupSpaceY
			end
		end
		self.Height = self.Height + self.Margin * 0.5
		self:OnHeightChange()
	end,

	OnWidthChange = function(self)
		local diffX = (self.X + self.Width) - GameResolution.x
		if diffX > 0 then
			self.X = self.X - diffX
			self:Write()
		end
	end,

	OnHeightChange = function(self)
		local diffY = (self.Y + self.Height) - GameResolution.y
		if diffY > 0 then
			self.Y = self.Y - diffY
			self:Write()
		end
	end,

	OnUpdate = function(self)
		self.MaxValueWidth = self.DefaultValueWidth
		for i = 1, #self.ValidGroups do
			local group = self.ValidGroups[i]
			local items = group.Items
			for j = 1, #items do
				local item = items[j]
				if item.Value.Width > self.MaxValueWidth then
					self.MaxValueWidth = item.Value.Width
				end
			end
		end
		local width = self.MaxLabelWidth + self.MaxValueWidth
		if PermaShow.PrintTitle and self.MaxTitleWidth > width then
			width = self.MaxTitleWidth
		end
		if width ~= self.Width then
			self.Width = width
			self:OnWidthChange()
		end
		self:UpdateGroupPosition()
	end,

	OnItemChange = function(self)
		for i = #self.ValidGroups, 1, -1 do
			table.remove(self.ValidGroups, i)
		end
		self.MaxTitleWidth = 0
		self.MaxLabelWidth = 0
		self.MaxValueWidth = self.DefaultValueWidth
		for i = 1, #self.Groups do
			local group = self.Groups[i]
			local items = group.Items
			if #items > 0 then
				table.insert(self.ValidGroups, group)
				local title = group.Title
				self.Height = self.Height + title.Height
				if title.Width > self.MaxTitleWidth then
					self.MaxTitleWidth = title.Width
				end
				for j = 1, #items do
					local item = items[j]
					if item.Label.Width > self.MaxLabelWidth then
						self.MaxLabelWidth = item.Label.Width
					end
					if item.Value.Width > self.MaxValueWidth then
						self.MaxValueWidth = item.Value.Width
					end
				end
			end
		end
		local width = self.MaxLabelWidth + self.MaxValueWidth
		if PermaShow.PrintTitle and self.MaxTitleWidth > width then
			width = self.MaxTitleWidth
		end
		if width ~= self.Width then
			self.Width = width
			self:OnWidthChange()
		end
		self:UpdateGroupPosition()
	end,

	WndMsg = function(self, msg, wParam)
		if self.Count < 1 then
			return
		end
		if msg == 513 and wParam == 0 then
			local x1, y1, x2, y2 = cursorPos.x, cursorPos.y, self.X, self.Y
			if x1 >= x2 and x1 <= x2 + self.Width then
				if y1 >= y2 and y1 <= y2 + self.Height then
					self.MoveX = x2 - x1
					self.MoveY = y2 - y1
					self.Moving = true
					--print('started')
				end
			end
		end
		if msg == 514 and wParam == 1 and self.Moving then
			self.Moving = false
			self:Write()
			--print('stopped')
		end
	end,

	Draw = function(self)
		if self.Count < 1 then
			return
		end
		if self.Moving then
			local cpos = cursorPos
			self.X = cpos.x + self.MoveX
			self.Y = cpos.y + self.MoveY
		end
		DrawRect(self.X, self.Y, self.Width, self.Height, ColorTransparentBlack)
		for i = 1, #self.ValidGroups do
			self.ValidGroups[i]:Draw()
		end
	end,

	Read = function(self)
		local f = io.open(self.InfoPath, "r")
		if f then
			local pos = assert(load(f:read("*all")))()
			self.X, self.Y = pos[1], pos[2]
			--print(self.X/GameResolution.x)
			--print(self.Y/GameResolution.y)
			f:close()
		end
	end,

	Write = function(self)
		local f = io.open(self.InfoPath, "w")
		if f then
			f:write("return{" .. self.X .. "," .. self.Y .. "}")
			f:close()
		end
	end,

	Group = function(self, id, name)
		return {
			Id = id,
			Title = self:GroupTitle(name):Init(),
			Items = {},
			Draw = function(self)
				if PermaShow.PrintTitle then
					self.Title:Draw()
				end
				for i = 1, #self.Items do
					self.Items[i]:Draw()
				end
			end,
		}
	end,

	GroupTitle = function(self, name)
		return {
			X = 0,
			Y = 0,
			Name = name,

			UpdatePos = function(self)
				local height = PermaShow.Height
				self.X = (PermaShow.Width - PermaShow.MaxValueWidth - self.Width) / 2
				self.Y = height
				PermaShow.Height = self.Y + self.Height + 3
			end,

			Draw = function(self)
				DrawText(self.Name, 13, PermaShow.X + self.X, PermaShow.Y + self.Y, ColorWhite, AminoFont)
				local x = PermaShow.X + self.X
				local y = PermaShow.Y + self.Y + self.Height + 1
				Draw.Line(x, y, x + self.Width, y, 1, ColorWhite)
			end,

			Init = function(self)
				local size = Draw.FontRect(self.Name, 13, AminoFont)
				self.Width = size.x
				self.Height = size.y
				return self
			end,
		}
	end,

	GroupItem = function(self, name, menuItem)
		return {
			X = 0,
			Y = 0,
			Label = self:ItemLabel(name),
			Value = self:ItemValue(),
			MenuItem = menuItem,

			UpdatePos = function(self, margin, spaceY)
				local height = PermaShow.Height
				self.X = margin
				self.Y = height
				PermaShow.Height = self.Y + self.Height
				self.Label:UpdatePos(self)
				self.Value:UpdatePos(self, margin)
			end,

			Init = function(self)
				self.Label:Init()
				self.MenuItem.ParmaShowOnValueChange = function()
					self:Update()
				end
				self:Update()
				return self
			end,

			Draw = function(self)
				self.Label:Draw()
				self.Value:Draw()
			end,

			Update = function(self)
				self.Value:Update(self.MenuItem)
				self.Width = self.Label.Width + self.Value.Width
				self.Height = self.Label.Height > self.Value.Height and self.Label.Height or self.Value.Height
				PermaShow:OnUpdate()
			end,

			Dispose = function(self)
				self.MenuItem.ParmaShowOnValueChange = false
			end,
		}
	end,

	ItemLabel = function(self, name)
		return {
			X = 0,
			Y = 0,
			Name = name,

			UpdatePos = function(self, parent)
				self.X = parent.X --(PermaShow.Width - self.Width - PermaShow.MaxValueWidth - 10) / 2--parent.X
				self.Y = parent.Y + (parent.Height - self.Height) / 2
			end,

			Draw = function(self)
				DrawText(self.Name, 13, PermaShow.X + self.X, PermaShow.Y + self.Y, ColorWhite, AminoFont)
			end,

			Init = function(self)
				local size = Draw.FontRect(self.Name, 13, AminoFont)
				self.Width = size.x
				self.Height = size.y
			end,
		}
	end,

	ItemValue = function(self)
		return {
			X = 0,
			Y = 0,
			RectX = 0,
			RectY = 0,
			RectColor = ColorDarkBlue,

			UpdatePos = function(self, parent, margin)
				local rectMargin = 0 --12
				self.RectX = PermaShow.Width - PermaShow.MaxValueWidth - margin - rectMargin
				self.RectY = parent.Y + (parent.Height - self.Height) / 2
				self.RectWidth = PermaShow.Width - self.RectX - margin
				self.RectHeight = self.Height
				self.X = self.RectX + (self.RectWidth - self.Width) / 2
				self.Y = self.RectY + (self.RectHeight - self.Height) / 2
			end,

			Draw = function(self)
				DrawRect(
					PermaShow.X + self.RectX,
					PermaShow.Y + self.RectY,
					self.RectWidth,
					self.RectHeight,
					self.RectColor
				)
				DrawText(self.Name, 13, PermaShow.X + self.X, PermaShow.Y + self.Y, ColorWhite, AminoFont)
			end,

			Update = function(self, menuItem)
				self.Value = menuItem:GetValue()
				if menuItem.Type ~= 4 then
					self.RectColor = self.Value and ColorDarkGreen or ColorDarkRed
				end

				self.Name = menuItem:ToString()
				local size = Draw.FontRect(self.Name, 13, AminoFont)
				self.Width = size.x
				self.Height = size.y
			end,
		}
	end,

	AddGroup = function(self, group)
		table.insert(self.Groups, self:Group(group.Id, group.Name))
		return true
	end,

	AddItem = function(self, name, menuItem)
		for i = 1, #self.Groups do
			local group = self.Groups[i]
			if menuItem.PermaShowID == group.Id then
				table.insert(group.Items, self:GroupItem(name, menuItem):Init())
				self.Count = self.Count + 1
				self:OnItemChange()
				return true
			end
		end
		return false
	end,

	RemoveItem = function(self, menuItem)
		for i = 1, #self.Groups do
			local group = self.Groups[i]
			if group.Id == menuItem.PermaShowID then
				for j = 1, #group.Items do
					if group.Items[j].Value.Id == menuItem.Id then
						group.Items[j]:Dispose()
						table.remove(group.Items, j)
						self.Count = self.Count - 1
						self:OnItemChange()
						return true
					end
				end
			end
		end
		return false
	end,
}

PermaShow:Read()

local function PSDrawCallback()
	PermaShow:Draw()
end

local function PSWndMsgCallback(msg, wParam)
	PermaShow:WndMsg(msg, wParam)
end

Callback.Add("Draw", PSDrawCallback)
Callback.Add("WndMsg", PSWndMsgCallback)

class("ScriptMenu")

function ScriptMenu:__init(id, name, parent, type, a, b, c, d)
	self.Id = id
	self.Name = name
	if parent == nil then
		self.ElementCount = 0
		self.Settings = {}
		self.Gos = MenuElement({ type = _G.MENU, name = name, id = id })
		PermaShow:AddGroup(self)
		return
	end
	parent.ElementCount = parent.ElementCount + 1
	self.Type = type
	self.Parent = parent
	if self.Type == 0 then --space
		self.Gos = self.Parent.Gos:MenuElement({
			id = "INFO_" .. tostring(parent.ElementCount),
			name = id or "",
			type = _G.SPACE,
		})
		return
	end
	assert(self.Parent[self.Id] == nil, "menu: '" .. self.Parent.Id .. "' already contains '" .. self.Id .. "'")
	self.Parent[self.Id] = self
	if self.Type == 1 then --menu
		self.ElementCount = 0
		self.Gos = self.Parent.Gos:MenuElement({ id = id, name = name, type = _G.MENU })
	else
		local root = self:GetRoot()
		--print(self.Id .. ' ' .. root.Id)
		assert(root.Settings[self.Id] == nil, "settings: '" .. root.Id .. "' already contains '" .. self.Id .. "'")
		self.Settings = root.Settings
		self.ParmaShowOnValueChange = false
		local args = {
			id = id,
			name = name,
			type = _G.PARAM,
			callback = function(x)
				self.Settings[self.Id] = x
				if self.ParmaShowOnValueChange then
					self.ParmaShowOnValueChange()
				end
			end,
		}
		--OnOff
		if self.Type == 2 then
			args.value = a
			self.PermaShowID = root.Id
			--Slider
		elseif self.Type == 3 then
			args.value = a
			args.min = b
			args.max = c
			args.step = d
			--List
		elseif self.Type == 4 then
			args.value = a
			args.drop = b
			self.PermaShowID = root.Id
			self.DropList = b
			--Color
		elseif self.Type == 5 then
			args.color = a
		elseif self.Type == 6 then
			assert(_G.type(a) == "string", "ScriptMenu:KeyDown(id, name, key): [key] must be string")
			args.value = false
			args.key = string.byte(a)
			self.Key = a:upper()
			self.PermaShowID = root.Id
			args.onKeyChange = function(x)
				self.Key = string.char(x):upper()
				if self.ParmaShowOnValueChange then
					self.ParmaShowOnValueChange()
				end
			end
		elseif self.Type == 7 then
			assert(_G.type(b) == "string", "ScriptMenu:KeyToggle(id, name, value, key: [key] must be string")
			args.value = a
			args.key = string.byte(b)
			args.toggle = true
			self.Key = b:upper()
			self.PermaShowID = root.Id
			args.onKeyChange = function(x)
				self.Key = string.char(x):upper()
				if self.ParmaShowOnValueChange then
					self.ParmaShowOnValueChange()
				end
			end
		end
		self.Gos = self.Parent.Gos:MenuElement(args)
		if self.Type >= 6 then
			self.Key = string.char(self.Gos.__key):upper()
		end
		--print('prev ' .. tostring(self.Settings[self.Id]))
		self.Settings[self.Id] = self.Gos:Value()
		--print('post ' .. tostring(self.Settings[self.Id]))
	end
end

function ScriptMenu:Space(id, name)
	return ScriptMenu("", name, self, 0)
end

function ScriptMenu:Info(id, name)
	return ScriptMenu(id, name, self, 0)
end

function ScriptMenu:Menu(id, name)
	return ScriptMenu(id, name, self, 1)
end

function ScriptMenu:OnOff(id, name, value)
	return ScriptMenu(id, name, self, 2, value)
end

function ScriptMenu:Slider(id, name, value, min, max, step)
	return ScriptMenu(id, name, self, 3, value, min, max, step)
end

function ScriptMenu:List(id, name, value, drop)
	return ScriptMenu(id, name, self, 4, value, drop)
end

function ScriptMenu:Color(id, name, color)
	return ScriptMenu(id, name, self, 5, color)
end

function ScriptMenu:KeyDown(id, name, key)
	return ScriptMenu(id, name, self, 6, key)
end

function ScriptMenu:KeyToggle(id, name, value, key)
	return ScriptMenu(id, name, self, 7, value, key)
end

function ScriptMenu:Hide(value)
	self.Gos:Hide(value)
end

function ScriptMenu:Remove()
	self.Gos:Remove()
end

function ScriptMenu:GetRoot()
	local root = self.Parent
	while true do
		if root.Parent == nil then
			break
		end
		root = root.Parent
	end
	return root
end

function ScriptMenu:ToString()
	if self.Type == 4 then
		return self.DropList[self.Settings[self.Id]]
	end
	if self.Type >= 6 then
		return self.Key == " " and "Space" or self.Key
	end
	if self.Type == 2 then
		return self.Settings[self.Id] and "On" or "Off"
	end
	return tostring(self.Settings[self.Id])
end

function ScriptMenu:GetValue()
	return self.Settings[self.Id]
end

function ScriptMenu:PermaShow(text, value)
	--print(text)
	if self.Type == nil or self.Type < 2 or self.Type == 3 or self.Type == 5 then
		return
	end
	if value == nil then
		value = true
	end
	if value then
		PermaShow:AddItem(text, self)
	else
		PermaShow:RemoveItem(self)
	end
end

local Settings
Menu = {}
Menu.m = MenuElement({name = "HH " .. myHero.charName, id = 'HH' .. myHero.charName, type = _G.MENU})
Menu.q = Menu.m:MenuElement({name = 'Q', id = 'q', type = _G.MENU})
Menu.w = Menu.m:MenuElement({name = 'W', id = 'w', type = _G.MENU})
Menu.e = Menu.m:MenuElement({name = 'E', id = 'e', type = _G.MENU})
Menu.r = Menu.m:MenuElement({name = 'R', id = 'r', type = _G.MENU})
Menu.d = Menu.m:MenuElement({name = 'Drawings', id = 'd', type = _G.MENU})



--Zeri 

if Champion == nil and myHero.charName == "Zeri" then
    -- menu
	Menu.blockaa = Menu.q:MenuElement({ id = "blockaa", name = "Block auto without Q passive", value = true})
    Menu.q_combo = Menu.q:MenuElement({id = 'combo', name = 'Combo', value = true})
    Menu.q_hitchance = Menu.q:MenuElement({id = "hitchance", name = "Hitchance", value = 2, drop = {"normal", "high", "immobile"}})
    Menu.q:MenuElement({id = "lane", name = "LaneClear", type = _G.MENU})
    Menu.q_lh_enabled = Menu.q.lane:MenuElement({id = "lhenabled", name = "LastHit Enabled", value = true})
    Menu.q_lc_enabled = Menu.q.lane:MenuElement({id = "lcenabled", name = "LaneClear Enabled", value = true})
    
    Menu.w_combo = Menu.w:MenuElement({id = 'combo', name = 'Combo', value = true})
	Menu.w_wall = Menu.w:MenuElement({id = "wall", name = "Only use through wall", value = true})
    Menu.w_hitchance = Menu.w:MenuElement({id = "hitchance", name = "Hitchance", value = 2, drop = {"normal", "high", "immobile"}})
    Menu.w_mana = Menu.w:MenuElement({id = "mana", name = "Min. Mana %", value = 30, min = 0, max = 100, step = 1})

    Menu.r_combo = Menu.r:MenuElement({id = 'combo', name = 'Combo', value = true})
    Menu.r_xenemies = Menu.r:MenuElement({id = "xenemies", name = "When can hit x enemies", value = 3, min = 1, max = 5, step = 1})
    
    Menu.drawQ = Menu.d:MenuElement({id = "drawq", name = "Draw Q", value = true})

	-- locals
	qRange = 825
	aaRange = myHero.range
	
	local QPrediction = GGPrediction:SpellPrediction({
		Delay = 0.1,
		Radius = 80,
		Range = qRange,
		Speed = 2600,
		Collision = true,
		MaxCollision = 0,
		CollisionTypes = { GGPrediction.COLLISION_MINION, GGPrediction.COLLISION_YASUOWALL },
		Type = GGPrediction.SPELLTYPE_LINE,
	})
	local WPrediction = GGPrediction:SpellPrediction({
		Delay = 0.6,
		Radius = 80,
		Range = 900,
		Speed = 2200,
		Collision = true,
		MaxCollision = 0,
		CollisionTypes = { GGPrediction.COLLISION_MINION, GGPrediction.COLLISION_YASUOWALL },
		Type = GGPrediction.SPELLTYPE_LINE,
	})
	local W2Prediction = GGPrediction:SpellPrediction({
		Delay = 0.6,
		Radius = 80,
		Range = 2700,
		Speed = 2200,
		Collision = false,
		Type = GGPrediction.SPELLTYPE_LINE,
	})

	-- champion
	Champion = {
		CanAttackCb = function()
			return GG_Spell:CanTakeAction({ q = 0.4, w = .65, e = 0.4, r = .35 })
		end,
		CanMoveCb = function()
			return GG_Spell:CanTakeAction({ q = 0.3, w = .55, e = 0.3, r = .25 })
		end,
		OnPostAttackTick = function(PostAttackTimer)
			Champion:PreTick()
			Champion.QTargets = Utils:GetEnemyHeroes(QPrediction.Range)
			Champion.WTargets = Utils:GetEnemyHeroes(2700)
			Champion:WLogic()
			Champion:QLogic()
			Champion:RLogic()
		end,
	}
	-- load
	function Champion:OnLoad()
		local getDamage = function()
				local levelDmgTbl  = {7 , 10 , 13 , 16 , 19}
				local levelPctTbl  = {1.05 , 1.1 , 1.15 , 1.2 , 1.25}
				local levelDmg = levelDmgTbl[myHero:GetSpellData(_Q).level]
				local levelPct = levelPctTbl[myHero:GetSpellData(_Q).level]
				local dmg = levelDmg + myHero.totalDamage*levelPct
			return dmg
		end
		local canLastHit = function()
			return Menu.q_lh_enabled:Value()
		end
		local canLaneClear = function()
			return Menu.q_lc_enabled:Value()
		end
		local isQReady = function()
			return GG_Spell:IsReady(_Q)
		end
		GG_Spell:SpellClear(_Q, QPrediction, isQReady, canLastHit, canLaneClear, getDamage)
	end
	-- wnd msg
	function Champion:OnWndMsg(msg, wParam)
	
	end
	-- tick
	function Champion:OnTick()
		if Game.IsChatOpen() then
			LastChatOpenTimer = os.clock()
		end
		
		-- for j = 0, myHero.buffCount do
			-- local buff = myHero:GetBuff(j);
			-- if buff ~= nil and buff.count > 0 then
				-- PrintChat(myHero.name, "type: " .. buff.type .. 
				-- ", name: " .. buff.name .. 
				-- ", startTime: " .. buff.startTime .. 
				-- ", expireTime: " .. buff.expireTime .. 
				-- ", duration: " .. buff.duration .. 
				-- ", stacks: " .. buff.stacks .. 
				-- ", count: " .. buff.count .. 
				-- ", sourceName: " .. buff.sourceName
				-- );
			-- end
		-- end
		
		local hasPassive = GG_Buff:HasBuff(myHero,"zeriqpassiveready")
		if hasPassive and Menu.blockaa:Value() then
			GG_Orbwalker:SetAttack(true)
		elseif not hasPassive and Menu.blockaa:Value() and (self.IsCombo or self.IsLaneClear) then
			GG_Orbwalker:SetAttack(false)
		else 
			GG_Orbwalker:SetAttack(true)
		end
		
		local hasSpecialRounds = GG_Buff:HasBuff(myHero,"zeriespecialrounds")
		if not hasSpecialRounds then
			QPrediction = GGPrediction:SpellPrediction({
				Delay = 0.1,
				Radius = 80,
				Range = qRange,
				Speed = 2600,
				Collision = false,
				--MaxCollision = 0,
				--CollisionTypes = { GGPrediction.COLLISION_MINION, GGPrediction.COLLISION_YASUOWALL },
				Type = GGPrediction.SPELLTYPE_LINE,
			})
		else
			QPrediction = GGPrediction:SpellPrediction({
				Delay = 0.1,
				Radius = 80,
				Range = qRange,
				Speed = 3400,
				Collision = false,
				Type = GGPrediction.SPELLTYPE_LINE,
			})
		end
		
		if myHero.range == 575 then	--check for lethal tempo and change q range 
			self.qRange = 900
		else
			self.qRange = 825
		end
	
		self.QTargets = Utils:GetEnemyHeroes(QPrediction.Range)
		self:QLogic()
		self:RLogic()
		self.WTargets = Utils:GetEnemyHeroes(2300)
		self:WLogic()
	end
	-- q logic
	function Champion:QLogic()
		if not GG_Spell:IsReady(_Q) then
			return
		end
		self:QCombo()
	end
	-- w logic
	function Champion:WLogic()
		if not GG_Spell:IsReady(_W) then
			return
		end
		self:WCombo()
	end
	-- r logic
	function Champion:RLogic()
		if not GG_Spell:IsReady(_R) then
			return
		end
		self:RCombo()
	end
	
	function Champion:delayAndDisableOrbwalker(delay) 
		_nextSpellCast = Game.Timer() + delay
		GG_Orbwalker:SetMovement(false)
		GG_Orbwalker:SetAttack(false)
		DelayAction(function() 
			GG_Orbwalker:SetMovement(true)
			GG_Orbwalker:SetAttack(true)
		end, delay)
	end
	
	
	-- r combo
	function Champion:RCombo()
		local minenemies = Utils:GetEnemyHeroes(825)
		if #minenemies >= Menu.r_xenemies:Value() and self.IsCombo then
            Utils:Cast(HK_R, myHero)
        end
	end
	-- q combo
	function Champion:QCombo()
		if not self.IsCombo and Menu.q_combo:Value() then
			return
		end
		local target = self.AttackTarget ~= nil and self.AttackTarget
			or GG_Target:GetTarget(self.QTargets, DAMAGE_TYPE_PHYSICAL)
		Utils:Cast(HK_Q, target, QPrediction, Menu.q_hitchance:Value() + 1)
	end
	-- w combo
	function Champion:WCombo()
		if self.IsCombo and Menu.w_combo:Value() then
			if self.ManaPercent < Menu.w_mana:Value() then
				return
			end
			local target = self.AttackTarget ~= nil and self.AttackTarget
				or GG_Target:GetTarget(self.WTargets, DAMAGE_TYPE_MAGICAL)			
			if target == nil then
				return 
			else 
				local direction = (target.pos - myHero.pos):Normalized()
				for distance = 50, 1100, 50 do
					local testPosition = myHero.pos + direction * distance
					if testPosition:ToScreen().onScreen then
						if target.pos:DistanceTo(testPosition) < 50 then 	-- it will hit champion before it hits wall
							if not Menu.w_wall:Value() then 				-- The user selected to allow hitting even when not through terrain
								Utils:Cast(HK_W, target, WPrediction, Menu.w_hitchance:Value() + 1)
								self:delayAndDisableOrbwalker(.6)
								return
							else
								return
							end
						end
						if MapPosition:inWall(testPosition) then
							if target.pos:DistanceTo(testPosition) > 1500 then
								return
							end
							Utils:Cast(HK_W, target, W2Prediction, Menu.w_hitchance:Value() + 1)
							self:delayAndDisableOrbwalker(.6)
							return
						end
					end
				end
				return
			end
		end
	end	
	-- draw
	function Champion:OnDraw()
		if Menu.drawQ:Value() then 
			Draw.Circle(myHero.pos, self.qRange, Draw.Color(0, 128, 128))
		end
	end
end

--Nilah 

if Champion == nil and myHero.charName == "Nilah" then
    -- menu
    Menu.q_combo = Menu.q:MenuElement({id = 'combo', name = 'Combo', value = true})
    Menu.q_hitchance = Menu.q:MenuElement({id = "hitchance", name = "Hitchance", value = 2, drop = {"normal", "high", "immobile"}})
    Menu.q:MenuElement({id = "lane", name = "LaneClear", type = _G.MENU})
    Menu.q_lh_enabled = Menu.q.lane:MenuElement({id = "lhenabled", name = "LastHit Enabled", value = true})
    Menu.q_lc_enabled = Menu.q.lane:MenuElement({id = "lcenabled", name = "LaneClear Enabled", value = true})
    

    Menu.r_combo = Menu.r:MenuElement({id = 'combo', name = 'Combo', value = true})
    Menu.r_xenemies = Menu.r:MenuElement({id = "xenemies", name = "When can hit x enemies", value = 3, min = 1, max = 5, step = 1})
    
    Menu.drawQ = Menu.d:MenuElement({id = "drawq", name = "Draw Q", value = true})

	-- locals
	qRange = 550
	aaRange = myHero.range
	
	local QPrediction = GGPrediction:SpellPrediction({
		Delay = 0.25,
		Radius = 150,
		Range = qRange,
		Speed = 2600,
		Collision = false,
		Type = GGPrediction.SPELLTYPE_LINE,
	})
	
	-- champion
	Champion = {
		CanAttackCb = function()
			return GG_Spell:CanTakeAction({ q = 0.4, w = .65, e = 0.4, r = .35 })
		end,
		CanMoveCb = function()
			return GG_Spell:CanTakeAction({ q = 0.3, w = .55, e = 0.3, r = .25 })
		end,
		OnPostAttackTick = function(PostAttackTimer)
			Champion:PreTick()
			Champion.QTargets = Utils:GetEnemyHeroes(QPrediction.Range)
			Champion:QLogic()
			Champion:RLogic()
		end,
	}
	-- load
	function Champion:OnLoad()
		local getDamage = function()
				local levelDmgTbl  = {5 , 10 , 15 , 20 , 25}
				local levelPctTbl  = { 0.9 , 1.0 , 1.1 , 1.15 , 1.2 }
				local levelDmg = levelDmgTbl[myHero:GetSpellData(_Q).level]
				local levelPct = levelPctTbl[myHero:GetSpellData(_Q).level]
				local dmg = levelDmg + myHero.totalDamage*levelPct
			return dmg
		end
		local canLastHit = function()
			return Menu.q_lh_enabled:Value()
		end
		local canLaneClear = function()
			return Menu.q_lc_enabled:Value()
		end
		local isQReady = function()
			return GG_Spell:IsReady(_Q)
		end
		GG_Spell:SpellClear(_Q, QPrediction, isQReady, canLastHit, canLaneClear, getDamage)
	end
	-- wnd msg
	function Champion:OnWndMsg(msg, wParam)
	
	end
	-- tick
	function Champion:OnTick()
		if Game.IsChatOpen() then
			LastChatOpenTimer = os.clock()
		end
		
		self.QTargets = Utils:GetEnemyHeroes(QPrediction.Range)
		self:QLogic()
		self:RLogic()
	end
	-- q logic
	function Champion:QLogic()
		if not GG_Spell:IsReady(_Q) then
			return
		end
		self:QCombo()
	end
	-- r logic
	function Champion:RLogic()
		if not GG_Spell:IsReady(_R) then
			return
		end
		self:RCombo()
	end
	
	function Champion:delayAndDisableOrbwalker(delay) 
		_nextSpellCast = Game.Timer() + delay
		GG_Orbwalker:SetMovement(false)
		GG_Orbwalker:SetAttack(false)
		DelayAction(function() 
			GG_Orbwalker:SetMovement(true)
			GG_Orbwalker:SetAttack(true)
		end, delay)
	end
	
	
	-- r combo
	function Champion:RCombo()
		local minenemies = Utils:GetEnemyHeroes(450)
		if #minenemies >= Menu.r_xenemies:Value() and self.IsCombo then
            Utils:Cast(HK_R, myHero)
        end
	end
	-- q combo
	function Champion:QCombo()
		if not self.IsCombo and Menu.q_combo:Value() then
			return
		end
		local target = self.AttackTarget ~= nil and self.AttackTarget
			or GG_Target:GetTarget(self.QTargets, DAMAGE_TYPE_PHYSICAL)
		Utils:Cast(HK_Q, target, QPrediction, Menu.q_hitchance:Value() + 1)
	end	
	-- draw
	function Champion:OnDraw()
		if Menu.drawQ:Value() then 
			Draw.Circle(myHero.pos, 550, Draw.Color(0, 128, 128))
		end
	end
end

-- --Kai'sa

-- if Champion == nil and myHero.charName == "Kai'sa" then
    -- -- menu
    -- Menu.q_combo = Menu.q:MenuElement({id = 'combo', name = 'Combo', value = true})

    -- Menu.q:MenuElement({id = "lane", name = "LaneClear", type = _G.MENU})
    -- Menu.q_lc_enabled = Menu.q.lane:MenuElement({id = "lcenabled", name = "LaneClear Enabled", value = true})
    
    -- Menu.w_combo = Menu.w:MenuElement({id = 'combo', name = 'Combo', value = true})
    -- Menu.w_hitchance = Menu.w:MenuElement({id = "hitchance", name = "Hitchance", value = 2, drop = {"normal", "high", "immobile"}})
    -- Menu.w_mana = Menu.w:MenuElement({id = "mana", name = "Min. Mana %", value = 30, min = 0, max = 100, step = 1})

    
    -- Menu.drawQ = Menu.d:MenuElement({id = "drawq", name = "Draw Q", value = true})

	-- -- locals
	-- qRange = 525
	-- local WPrediction = GGPrediction:SpellPrediction({Type = GGPrediction.SPELLTYPE_LINE, Delay = 0.4, Radius = 100, Range = 3000, Speed = 1750, Collision = true, CollisionTypes = {GGPrediction.COLLISION_MINION}})
	-- -- champion
	-- Champion = {
		-- CanAttackCb = function()
			-- return GG_Spell:CanTakeAction({ q = 0, w = .5, e = 0.4, r = .35 })
		-- end,
		-- CanMoveCb = function()
			-- return GG_Spell:CanTakeAction({ q = 0, w = .4, e = 0, r = .25 })
		-- end,
		-- OnPostAttackTick = function(PostAttackTimer)
			-- Champion:PreTick()
			-- Champion.QTargets = Utils:GetEnemyHeroes(qRange)
			-- Champion.WTargets = Utils:GetEnemyHeroes(WPrediction.Range)
			-- Champion:WLogic()
			-- Champion:QLogic()
			-- Champion:RLogic()
		-- end,
	-- }
	-- -- load
	-- function Champion:OnLoad()
		
	-- end
	-- -- wnd msg
	-- function Champion:OnWndMsg(msg, wParam)
	
	-- end
	-- -- tick
	-- function Champion:OnTick()
		
	
		-- self:QLogic()
		-- self:WLogic()
	-- end
	-- -- q logic
	-- function Champion:QLogic()
		-- if not GG_Spell:IsReady(_Q) then
			-- return
		-- end
		-- self:QCombo()
	-- end
	-- -- w logic
	-- function Champion:WLogic()
		-- if not GG_Spell:IsReady(_W) then
			-- return
		-- end
		-- self:WCombo()
	-- end
	-- -- q combo
	-- function Champion:QCombo()
		-- if not self.IsCombo and Menu.q_combo:Value() then
			-- return
		-- end
		-- local target = self.AttackTarget ~= nil and self.AttackTarget
			-- or GG_Target:GetTarget(self.QTargets, DAMAGE_TYPE_PHYSICAL)
		-- if target == nil then
			-- return
		-- end
		-- if 
			-- Utils:Cast(HK_Q, myHero)
		-- end
	-- end
	-- -- w combo
	-- function Champion:WCombo()
		-- if not self.IsCombo and Menu.w_combo:Value() then
			-- return
		-- end
		-- if self.ManaPercent < Menu.w_mana:Value() then
			-- return
		-- end
		-- local target = self.AttackTarget ~= nil and self.AttackTarget
			-- or GG_Target:GetTarget(self.WTargets, DAMAGE_TYPE_MAGICAL)
		-- if target == nil then
			-- return
		-- end
		-- if myHero.pos:DistanceTo(target.pos) <= 800 and GetBuffData(target, "kaisapassivemarker").count >= 3 then
			-- Utils:Cast(HK_W, target, WPrediction, Menu.w_hitchance:Value() + 1)
		-- end
	-- end	
	-- -- draw
	-- function Champion:OnDraw()
		
	-- end
-- end

if Champion ~= nil then
	function Champion:PreTick()
		self.IsCombo = GG_Orbwalker.Modes[ORBWALKER_MODE_COMBO]
		self.IsHarass = GG_Orbwalker.Modes[ORBWALKER_MODE_HARASS]
		self.IsLaneClear = GG_Orbwalker.Modes[ORBWALKER_MODE_LANECLEAR]
		self.IsLastHit = GG_Orbwalker.Modes[ORBWALKER_MODE_LASTHIT]
		self.IsFlee = GG_Orbwalker.Modes[ORBWALKER_MODE_FLEE]
		self.AttackTarget = nil
		self.CanAttackTarget = false
		self.IsAttacking = GG_Orbwalker:IsAutoAttacking()
		if not self.IsAttacking and (self.IsCombo or self.IsHarass) then
			self.AttackTarget = GG_Target:GetComboTarget()
			self.CanAttack = GG_Orbwalker:CanAttack()
			if self.AttackTarget and self.CanAttack then
				self.CanAttackTarget = true
			else
				self.CanAttackTarget = false
			end
		end
		self.Timer = Game.Timer()
		self.Pos = myHero.pos
		self.BoundingRadius = myHero.boundingRadius
		self.Range = myHero.range + self.BoundingRadius
		self.ManaPercent = 100 * myHero.mana / myHero.maxMana
		self.AllyHeroes = GG_Object:GetAllyHeroes(2000)
		self.EnemyHeroes = GG_Object:GetEnemyHeroes(false, false, true)
		--Utils.CachedDistance = {}
	end
	Callback.Add("Load", function()
		GG_Target = _G.SDK.TargetSelector
		GG_Orbwalker = _G.SDK.Orbwalker
		GG_Buff = _G.SDK.BuffManager
		GG_Damage = _G.SDK.Damage
		GG_Spell = _G.SDK.Spell
		GG_Object = _G.SDK.ObjectManager
		GG_Attack = _G.SDK.Attack
		GG_Data = _G.SDK.Data
		GG_Cursor = _G.SDK.Cursor
		GG_Orbwalker:CanAttackEvent(Champion.CanAttackCb)
		GG_Orbwalker:CanMoveEvent(Champion.CanMoveCb)
		if Champion.OnLoad then
			Champion:OnLoad()
		end
		if Champion.OnPreAttack then
			GG_Orbwalker:OnPreAttack(Champion.OnPreAttack)
		end
		if Champion.OnAttack then
			GG_Orbwalker:OnAttack(Champion.OnAttack)
		end
		if Champion.OnPostAttack then
			GG_Orbwalker:OnPostAttack(Champion.OnPostAttack)
		end
		if Champion.OnPostAttackTick then
			GG_Orbwalker:OnPostAttackTick(Champion.OnPostAttackTick)
		end
		if Champion.OnTick then
			table.insert(_G.SDK.OnTick, function()
				Champion:PreTick()
				Champion:OnTick()
				Utils.CanUseSpell = true
			end)
		end
		if Champion.OnDraw then
			table.insert(_G.SDK.OnDraw, function()
				Champion:OnDraw()
			end)
		end
		if Champion.OnWndMsg then
			table.insert(_G.SDK.OnWndMsg, function(msg, wParam)
				Champion:OnWndMsg(msg, wParam)
			end)
		end
	end)
	return
end