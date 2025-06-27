local WorldHop = {}
local API = require("api")

-- Configuration

--[[
	NOTE: the delays are long to account for low pc specs. you can speed it up if you want
]]

local swapForDuration   = true			-- should we swap worlds?
local worldChanges      = 0			-- running count of # of world changes
local recentWorlds      = {}			-- initialize to store recent world history
local maxRecent         = 3   			-- Avoid the last 3 worlds
local swapWorldDuration = math.random(40, 90) * 60 * 1000  	-- 40 - 90 minutes in ms
local startTime         = API.ScriptRuntime()
local worlds            = {6, 9, 22, 27, 31, 35, 39, 42, 44, 45, 46, 58, 59, 60, 62, 64, 74, 76, 77, 89, 91, 97, 98, 99, 100, 103, 104, 116, 117}
						-- feel free to modify for lower ping
API.Write_fake_mouse_do(false)

-- parse the current world value
function WorldHop.getCurrentWorld()
    local text = API.ScanForInterfaceTest2Get(false, {
        {1587, 0, -1, 0}, {1587, 2, -1, 0}, {1587, 10, -1, 0}, {1587, 68, -1, 0}
    })
    if text and text[1] and text[1].textids then
        return tonumber(string.match(text[1].textids, "World (%d+)"))
    end
    return nil
end

-- select a new, valid world for swapping to
function WorldHop.chooseNewWorld(currentWorld)
    local filtered = {}
    for _, w in ipairs(worlds) do
        if w ~= currentWorld and not recentWorlds[w] then
            table.insert(filtered, w)
        end
    end
    if #filtered == 0 then
        print("[DEBUG] - No non-recent worlds available. Reusing full world list.")
        filtered = worlds
    end
    return filtered[math.random(1, #filtered)]
end

-- Attempt to open the mini logout menu up to 3 times before giving up
function WorldHop.openLogoutMenu()
    local success = false
    for attempt = 1, 3 do
        if API.DoAction_Interface(0xffffffff,0xffffffff,1,1477,97,1,API.OFF_ACT_GeneralInterface_route) then
            print(string.format("[WORLD HOP] - Attempt to open the mini logout menu: %d", attempt))
            API.RandomSleep2(math.random(1800, 3000), 1200, 600)
            if API.VB_FindPSettinOrder(2874).state == 1 then
            	success = true
		print(string.format("[WORLD HOP] - Mini world logout menu opened on attempt: %d", attempt))
            	break
	    end
        else
            print(string.format("[DEBUG] - Failed to open mini logout menu on attempt %d", attempt))
            API.RandomSleep2(math.random(600, 1200), 300, 300)
        end
    end

    if not success then
        print("[DEBUG] - Could not open mini logout menu after 3 attempts")
        return false
    end

    return true
end

function WorldHop.openWorldMenu()
    local success = false
    for attempt = 1, 3 do
        if API.DoAction_Interface(0x24, 0xffffffff, 1, 1433, 65, -1, API.OFF_ACT_GeneralInterface_route) then
            print(string.format("[WORLD HOP] - Attempting to open the world menu: %d", attempt))
	    API.RandomSleep2(math.random(1800, 3000), 1200, 600)
            if API.VB_FindPSettinOrder(2874).state == 61 then
		print(string.format("[WORLD HOP] - Main world menu opened on attempt: %d", attempt))
            	success = true
            	break
	    end
        else
            print(string.format("[DEBUG] - Failed to open main world menu on attempt %d", attempt))
            API.RandomSleep2(math.random(600, 1200), 300, 300)
        end
    end

    if not success then
        print("[DEBUG] - Could not open main world menu after 3 attempts")
        return false
    end

    return true
end

function WorldHop.pickWorld(whichWorld)
    local loggedIn = false

    for attempt = 1, 3 do
        if API.DoAction_Interface(
             0xffffffff, 0xffffffff, 1,
             1587, 8, whichWorld,
             API.OFF_ACT_GeneralInterface_route
           ) then

            API.RandomSleep2(math.random(1800,2400),1200,1200)
            
            for waitTick = 1, 35 do
                if API.PlayerLoggedIn() then
                    loggedIn = true
                    print(string.format(
                      "[WORLD HOP] - Logged in on attempt %d", attempt
                    ))
                    break
                end
                API.RandomSleep2(400, 200, 200) 
            end

            if loggedIn then
                break
            else
                print(string.format(
                  "[DEBUG] - Not logged in on attempt %d, retrying…", attempt
                ))
            end
        else
            print(string.format(
              "[DEBUG] - Failed to click world %d on attempt %d",
              whichWorld, attempt
            ))
        end

        API.RandomSleep2(math.random(1200,2400),900,300)
    end

    if not loggedIn then
        print("[DEBUG] - Player failed to log in after 3 tries")
        return false
    end

    return true
end

function WorldHop.hopWorld()
    print("[DEBUG] Preparing to hop worlds...")
    -- clear most recent tick action
    API.RandomSleep2(math.random(600, 1800), 600, 300)

    if not WorldHop.openLogoutMenu() then
        return false
    end

    if not WorldHop.openWorldMenu() then
        return false
    end
    
    -- allow population of world data
    API.RandomSleep2(math.random(2*600, 5*600), 600, 1200)

    local currentWorld = WorldHop.getCurrentWorld()
    if not currentWorld then
        print("[DEBUG] - Could not detect current world")
        return false
    end

    local newWorld = WorldHop.chooseNewWorld(currentWorld)
    print(string.format("[WORLD HOP] Switching from World %d -> World %d", currentWorld, newWorld))

    if not WorldHop.pickWorld(newWorld) then
	return false
    end

    print("[WORLD HOP] World hop successful.. New world: "..newWorld)

    -- Track recent worlds (record the world we just arrived in)
    recentWorlds[newWorld] = true
    local count = 0
    for _ in pairs(recentWorlds) do count = count + 1 end
    if count > maxRecent then
        for k in pairs(recentWorlds) do
            recentWorlds[k] = nil
            break
        end
    end

    -- debug the current world list
    do
        local list = {}
        for w in pairs(recentWorlds) do
            table.insert(list, w)
        end
        table.sort(list)
        print("[DEBUG] - Recent worlds: " .. table.concat(list, ", "))
    end

    -- Reset timers/flags
    startTime   = API.ScriptRuntime()
    worldChanges = worldChanges + 1

    return true
end

function WorldHop.checkHopWorlds()
    local timeOnWorld = API.ScriptRuntime() - startTime
    print(string.format("[DEBUG] Time on current world: %d seconds", math.floor(timeOnWorld)))
    print(string.format("[DEBUG] Swapping worlds after: %d seconds", math.floor(swapWorldDuration/1000)))

    if swapForDuration and (timeOnWorld > swapWorldDuration / 1000) then
        if not WorldHop.hopWorld() then
		API.Write_LoopyLoop(false)	
	end
    end
end

return WorldHop
