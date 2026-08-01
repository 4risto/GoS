local Draw = Draw
local DrawText = Draw.Text
local DrawRect = Draw.Rect
local DrawCircle = Draw.Circle


local ColorWhite = Draw.Color(255, 255, 255, 255)
local ColorDarkGreen = Draw.Color(255, 0, 100, 0)
local ColorDarkRed = Draw.Color(255, 139, 0, 0)
local ColorDarkBlue = Draw.Color(255, 0, 0, 139)
local ColorTransparentBlack = Draw.Color(150, 0, 0, 0)

local CircleSize2
local AddSize2
local SubSize2

local DrawMenu2 = MenuElement({type = MENU, id = "Draw Range Circle2", name = "Draw Range Circle"})
DrawMenu2:MenuElement({id = "Draw", name = "Enable Range Circle", value = false})
DrawMenu2:MenuElement({id = "CircleSize", name = "Size of Range Circle", value = 100, min = 1, max = 2000, step = 25})
DrawMenu2:MenuElement({id = "Reset", name = "Click to Reset Size of Range Circle", type = SPACE, onclick = function() DrawMenu2.CircleSize:Value(100) end})
DrawMenu2:MenuElement({id = "Add", name = "Click to + Size of Range Circle", type = SPACE, onclick = function() Add() end})
DrawMenu2:MenuElement({id = "AddSize", name = "Size of + to Circle", value = 50, min = 1, max = 100, step = 1})
DrawMenu2:MenuElement({id = "Sub", name = "Click to - Size of Range Circle", type = SPACE, onclick = function() Sub() end})
DrawMenu2:MenuElement({id = "SubSize", name = "Size of - to Circle", value = 50, min = 1, max = 100, step = 1})
    Callback.Add("Tick", function() Tick() end)
    Callback.Add("Draw", function() Draw2() end)

function Add()
    CircleSize2 = CircleSize2 + AddSize2
    DrawMenu2.CircleSize:Value(CircleSize2)
end

function Sub()
    CircleSize2 = CircleSize2 - SubSize2
    DrawMenu2.CircleSize:Value(CircleSize2)
end

function Tick()
    if Game.IsChatOpen() or myHero.dead then return end
    CircleSize2 = DrawMenu2.CircleSize:Value()
    AddSize2 = DrawMenu2.AddSize:Value()
    SubSize2 = DrawMenu2.SubSize:Value()
end

function Draw2()
    local CircleSize2 = DrawMenu2.CircleSize:Value()
    if not DrawMenu2.Draw:Value() then return end
    DrawCircle(myHero.pos, CircleSize2, 1, ColorDarkBlue)

end