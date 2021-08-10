local RCMenu = MenuElement({type = MENU, id = "RCMenu", name = "Recall Tracker", leftIcon = "http://puu.sh/pPVxo/6e75182a01.png"})
RCMenu:MenuElement({id = "Enabled", name = "Enabled", value = true})
RCMenu:MenuElement({id = "OnlyEnemies", name = "Show Only Enemies", value = true, leftIcon = "http://puu.sh/rGoYt/5c99e94d8a.png"})
RCMenu:MenuElement({id = "OnlyFOW", name = "Show Only in FOW", value = true})
RCMenu:MenuElement({id = "BarWidth", name = "Recall Bar WidthSize", value = 250, min = 100, max = 550})


local RecallColor = Draw.Color(128,16,235,209);
local TeleportColor = Draw.Color(128,206,89,214);

local recalling = {}
local x = 5
local y = Game.Resolution().y/2
local scale = WINDOW_H / 1080 * 1.5
local rowHeight = 16*scale
local fontSize = 14*scale
local _169, _115 = 169*scale, 100*scale
local myTeam = 0


local function percentToRGB(percent) 
	local r, g
    if percent == 100 then
        percent = 99 end
		
    if percent < 50 then
        g = math.floor(255 * (percent / 50))
        r = 255
    else
        g = 255
        r = math.floor(255 * ((50 - percent % 50) / 50))
    end
	
    return Draw.Color(255,r,g,0);
end

function OnDraw()
	if not RCMenu.Enabled:Value() then return end	
	myTeam = myHero.team
	local i = 0
	for hero, recallObj in pairs(recalling) do
		local percent=math.floor((recallObj.hero.health/recallObj.hero.maxHealth)*100)
		local color=percentToRGB(percent)
		local leftTime = recallObj.starttime - GetTickCount() + recallObj.info.totalTime
		
		if leftTime<0 then leftTime = 0 end
		Draw.Rect(x,y+rowHeight*i-2,_169,rowHeight,Draw.Color(0x50000000))
		if i>0 then Draw.Rect(x,y+rowHeight*i-2,_169,1,Draw.Color(0xC0000000)) end
		
		Draw.Text(string.format("%s (%d%%)", recallObj.hero.charName, percent), fontSize, x+2, y+rowHeight*i, color)
		
		if recallObj.info.isStart then
			Draw.Text(string.format("%.1fs", leftTime/1000), fontSize, x+_115, y+rowHeight*i, color)
			if recallObj.info.name == "Teleport" then
				Draw.Rect(x+_169,y+rowHeight*i, RCMenu.BarWidth:Value()*leftTime/recallObj.info.totalTime,fontSize,TeleportColor) --the bart itself
				else
				Draw.Rect(x+_169,y+rowHeight*i, RCMenu.BarWidth:Value()*leftTime/recallObj.info.totalTime,fontSize,RecallColor) --the bart itself
				end
			Draw.Rect(x+_169,y+rowHeight*i, RCMenu.BarWidth:Value(),1,Draw.Color(0xFF000000))
			Draw.Rect(x+_169,y+rowHeight*i+fontSize, RCMenu.BarWidth:Value(),1,Draw.Color(0xFF000000))
			Draw.Rect(x+_169,y+rowHeight*i, 1,fontSize,Draw.Color(0xFF000000))
			Draw.Rect(x+_169+RCMenu.BarWidth:Value()-1,y+rowHeight*i, 1,fontSize,Draw.Color(0xFF000000))
		else
			if recallObj.killtime == nil then
				if recallObj.info.isFinish and not recallObj.info.isStart then
					recallObj.result = "FINISHED"
					recallObj.killtime =  GetTickCount()+2000
				elseif not recallObj.info.isFinish then
					recallObj.result = "CANCELED"
					recallObj.killtime =  GetTickCount()+2000
				end
				
			end
			Draw.Text(recallObj.result, fontSize, x+_115, y+rowHeight*i, color)
		end
		if recallObj.killtime~=nil and GetTickCount() > recallObj.killtime then
			recalling[hero] = nil
		end
		i=i+1
	end
end




function OnProcessRecall(Object,recallProc)
	if not RCMenu.Enabled:Value() and recalling[Object.networkID] == nil then return end
	if RCMenu.OnlyEnemies:Value() and recalling[Object.networkID] == nil and myTeam == Object.team then return end
	if RCMenu.OnlyFOW:Value() and recalling[Object.networkID] == nil and Object.visible then return end
	
	local rec = {}
	rec.hero = Object
	rec.info = recallProc
	rec.starttime = GetTickCount()
	rec.killtime = nil
	rec.result = nil
	recalling[Object.networkID] = rec

end

--PrintChat("Recall tracker by Krystian loaded.")