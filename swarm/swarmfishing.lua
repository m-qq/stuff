local API			= require("api")
local AURAS 			= require("swarm.AURAS").pin(0000)	-- require AURAS library & enter your bank pin
local version			= "1.0"

---------------------------------------------------------------------
-- SETUP / CONFIG ---------------------------------------------------
---------------------------------------------------------------------
local whichAura			= "legendary call of the sea"	-- enter the desired aura
local fishingAction         	= "swarm"       		-- set your main fishing target here 
								-- "sailfish", "minnows", "frenzyS", "frenzyN" 
								-- "swarm", "bluejellyfish", "greenjellyfish"

-- levels for bluejellyfish 91, greenjellyfish 68, swarm 68, minnows 68, frenzyN 94, frenzyS 94, sailfish 97

usePorters	    	    	= true				-- can use inventory porters if no GOTE, must be true if useGOTE 
useGOTE                     	= false    			-- use grace of the elves porters

local watchRandoms          	= true          		-- handle fishing notes/tangled fishbowl/etc
local MIN_IDLE_TIME_MINUTES 	= 5				-- min minutes before anti idle action
local MAX_IDLE_TIME_MINUTES 	= 15				-- max minutes before anti idle action	
local alertItemLevel        	= 10            		-- alert on augmented item level reached (use auto siphons)
								-- alertItemLevel taken out in 1.0

API.Write_fake_mouse_do(false)

---------------------------------------------------------------------
-- DEFINITIONS ------------------------------------------------------
---------------------------------------------------------------------

-- not all fish types are tested! (lower level swarm fish i.e. shrimp, herring..text values may not be exactly matching)
local FISH_TYPES = {
    {"rocktail",         "Rocktails",          "rocktail",                15270},
    {"cavefish",         "Cavefish",           "cavefish",                15264},
    {"bluejelly",        "Blue Blubbers",      "blue blubber jellyfish",  42265},
    {"sailfish",         "Sailfish",           "sailfish",                42249},
    {"mantaray",         "Manta rays",         "manta ray",               389	},
    {"seaturtle",        "Sea turtles",        "sea turtle",              395	},
    {"greatwhiteshark",  "Great white sharks", "great white shark",       34727},
    {"baronshark",       "Baron sharks",       "baron shark"			},
    {"greenblubber",     "Green Blubbers",     "green blubber jellyfish", 42256},
    {"minnow",           "Minnows",            "magnetic minnow"		},
    {"monkfish",         "Monkfish",           "monkfish",                7944	},
    {"swordfish",        "Swordfish",          "swordfish",               371	},
    {"bass",             "Bass",               "bass",                    363	},
    {"tuna",             "Tuna",               "tuna",                    359	},
    {"cod",              "Cod",                "cod",                     341	},
    {"mackerel",         "Mackerel",           "mackerel",                353	},
    {"trout",            "Trout",              "trout",                   335	},
    {"herring",          "Herring",            "herring",                 345	},
    {"shrimp",           "Shrimp",             "shrimp",                  317	},
}

local validActions = {
    sailfish        = true,
    minnows         = true,
    frenzyS         = true,
    frenzyN         = true,
    swarm           = true,
    bluejellyfish   = true,
    greenjellyfish  = true,
}

if not validActions[fishingAction] then
    error(("Invalid fishingAction '%s'; must be one of: %s")
        :format(
            fishingAction,
            table.concat(
                {"sailfish","minnows","frenzyS","frenzyN","swarm","bluejellyfish","greenjellyfish"},
                ", "
            )
        )
    )
end

local levelRequirements = {
    bluejellyfish 	= 91,
    greenjellyfish 	= 68,
    swarm         	= 68,
    minnows       	= 68,
    frenzyN       	= 94,
    frenzyS       	= 94,
    sailfish      	= 97,
}

local prices = {}
for _, f in ipairs(FISH_TYPES) do
    local id = f[4]
    if id then
        prices[id] = API.GetExchangePrice(id) or 0
    end
end

local npcIds = {
    sailfish       = { 25222, 25221 },         
    minnows        = { 25219 },
    frenzyS        = { 25204, 25202, 25195, 25194, 25201, 25203, 25196, 25197, 25197, 25198, 25205, 25199, 25208, 25207, 25200, 25209, 25206 },
    frenzyN        = { 25204, 25202, 25195, 25194, 25201, 25203, 25196, 25197, 25197, 25198, 25205, 25199, 25208, 25207, 25200, 25209, 25206 },
    swarm          = { 25220 },            
    jellyfish      = { 25224, 25223 },            
    bluejellyfish  = { 25224 },           
    greenjellyfish = { 25223 },       
}

local xpTable = {   
    0,		1160,		2607,		5176, 		8286, 
    11760,	15835,		21152,		28761,		40120,
    57095,	81960,		117397,		166496,		232755,
    320080,	432785,		575592,		753631,		972440
}

local regions = {
    sailfish       = {p1 = WPOINT.new(2135,7124,0),  p2 = WPOINT.new(2149,7136,3)},
    minnows        = {p1 = WPOINT.new(2127,7085,0),  p2 = WPOINT.new(2141,7101,3)}, 
    frenzyS        = {p1 = WPOINT.new(2062,7108,0),  p2 = WPOINT.new(2073,7112,3)},
    frenzyN        = {p1 = WPOINT.new(2064,7121,0),  p2 = WPOINT.new(2074,7131,3)}, 
    swarm          = {p1 = WPOINT.new(2090,7075,0),  p2 = WPOINT.new(2103,7079,3)},  
    jellyfish      = {p1 = WPOINT.new(2083,7109,0),  p2 = WPOINT.new(2114,7145,3)}, 
    bluejellyfish  = {p1 = WPOINT.new(2083,7109,0),  p2 = WPOINT.new(2114,7145,3)},
    greenjellyfish = {p1 = WPOINT.new(2083,7109,0),  p2 = WPOINT.new(2114,7145,3)}, 
    
    -- Junction regions
    minJunc        = {p1 = WPOINT.new(2116,7113,0),  p2 = WPOINT.new(2122,7118,3)},
    midJunc        = {p1 = WPOINT.new(2097,7108,0),  p2 = WPOINT.new(2103,7113,3)},
    southJunc      = {p1 = WPOINT.new(2102,7100,0),  p2 = WPOINT.new(2106,7105,3)},
    
    -- Bank/Net regions
    bankPorterEnter    = {p1 = WPOINT.new(2132,7103,0),  p2 = WPOINT.new(2135,7110,3)},
    bankPorterJelly    = {p1 = WPOINT.new(2096,7111,0),  p2 = WPOINT.new(2103,7116,3)}, 
    netJelly           = {p1 = WPOINT.new(2096,7089,0),  p2 = WPOINT.new(2102,7094,3)}, 
    netEnter           = {p1 = WPOINT.new(2114,7121,0),  p2 = WPOINT.new(2122,7125,3)}, 
}

local RANDOM_EVENTS = {
    {42286, "Fishing notes detected",        " + Gained extra xp from consuming fishing notes"},
    {42285, "Tangled fishbowl detected",     " + 5% xp boost activated for 3 minutes"},
    {42284, "Broken fishing rod detected",   " + 10% catch rate boost activated for 3 minutes"},
    {42283, "Barrel of bait detected",       " + 10% additional catch boost for 3 minutes"},
    {42282, "Message in a bottle detected",  " + Message in a bottle consumed"} 		-- pick 1 of 3 options
}

local edges = {
    -- Fishing spots
    sailfish   = {"netEnter", "minJunc", "bankPorterEnter"},
    minnows    = {"bankPorterEnter"},
    frenzyS    = {"midJunc"},
    frenzyN    = {"midJunc"},
    jellyfish  = {"midJunc"},       
    swarm      = {"netJelly"},     
    
    -- Junction connections  
    minJunc    = {"sailfish", "minnows", "midJunc", "bankPorterEnter", "netEnter"},
    midJunc    = {"jellyfish", "southJunc", "frenzyN", "frenzyS", "minJunc", "bankPorterJelly", "netJelly"},
    southJunc  = {"midJunc", "swarm"},
    
    -- Bank/Net connections
    bankPorterEnter  = {"minJunc", "minnows", "sailfish"},
    bankPorterJelly  = {"midJunc"},
    netJelly         = {"swarm", "midJunc"},
    netEnter         = {"minJunc", "sailfish"},
}

local porterCharges = {
    -- Tier 1 
    [29276] = 5,  -- Active 
    [29275] = 5,  -- Inactive 
    
    -- Tier 2
    [29278] = 10,  -- Active 
    [29277] = 10,  -- Inactive 
    
    -- Tier 3 
    [29280] = 15,  -- Active 
    [29279] = 15,  -- Inactive
    
    -- Tier 4
    [29282] = 20,  -- Active 
    [29281] = 20,  -- Inactive 
    
    -- Tier 5
    [29284] = 25,  -- Active
    [29283] = 25,  -- Inactive 
    
    -- Tier 6
    [29286] = 30,  -- Active
    [29285] = 30,  -- Inactive
    
    -- Tier 7
    [51491] = 50,  -- Active
    [51490] = 50,  -- Inactive
}

startingInventory 		= {}
local afk 			= API.ScriptRuntime()
local randomTime 		= 0
local lastFishCaught 		= API.ScriptRuntime()
local lastKnownFishCount 	= 0
local frenzyInteractions 	= 0
local waitingForFrenzyCompletion = false
local lastKnownMinnowCount 	= 0
local minnowInteractions	= 0
local lastFishTime 		= API.ScriptRuntime()    	-- initialize to script start
local currentGOTEThreshold 	= 0				-- dont change
local lastPorterInventoryState 	= ""
local portersUsed = 0
local lastPorterBuffAmount = 0
local buffTrackingInitialized = false

---------------------------------------------------------------------
-- LEVEL 1: BASIC UTILITY FUNCTIONS (NO DEPENDENCIES) ---------------
---------------------------------------------------------------------

local function normalizeFishName(name)
  if name=="bluejellyfish" or name=="greenjellyfish" then
    return "jellyfish"
  end
  return name
end

local function activityUsesPorters()
    local actionClean = normalizeFishName(fishingAction)
    return actionClean ~= "frenzyS" and actionClean ~= "frenzyN" and actionClean ~= "minnows"
end

local function randomPointInRegion(r)
    local x1, x2 = math.min(r.p1.x, r.p2.x), math.max(r.p1.x, r.p2.x)
    local y1, y2 = math.min(r.p1.y, r.p2.y), math.max(r.p1.y, r.p2.y)
    
    local x = math.floor(x1 + math.random() * (x2 - x1) + 0.5)
    local y = math.floor(y1 + math.random() * (y2 - y1) + 0.5)
    
    return { x = x, y = y, z = 0 }  
end

local function dist2(a,b)
  return math.sqrt((a.x-b.x)^2 + (a.y-b.y)^2)
end

local function inside(x,y,box,z)
  local x1,x2 = math.min(box.p1.x,box.p2.x), math.max(box.p1.x,box.p2.x)
  local y1,y2 = math.min(box.p1.y,box.p2.y), math.max(box.p1.y,box.p2.y)
  local z1,z2 = math.min(box.p1.z or 0, box.p2.z or 3), math.max(box.p1.z or 0, box.p2.z or 3)
  
  z = z or 0  -- Default Z to 0 if not provided
  
  return x>=x1 and x<=x2 and y>=y1 and y<=y2 and z>=z1 and z<=z2
end

local function insideRegion(x, y, regs, regionName, z)
    local r = regs[regionName]
    if not r then return false end
    return inside(x, y, r, z)
end

local function format_number(n)
    if not n then
        return "0"
    end
    
    n = tonumber(n)
    if not n then
        return "0"
    end
    
    local s = tostring(math.floor(n)) 
    local pos = #s % 3
    if pos == 0 then pos = 3 end
    return s:sub(1, pos) .. s:sub(pos + 1):gsub("(%d%d%d)", ",%1")
end

local function GetItemLevel(xp)
    if not xp or type(xp) ~= "number" then
        return 0
    end
    
    for i = #xpTable, 1, -1 do
        if xp >= xpTable[i] then
            return i
        end
    end
    return 0
end

local function getNecklaceID()
    local container = API.Container_Get_all(94)
    if container and container[3] and container[3].item_id and container[3].item_id > 0 then
        return container[3].item_id
    else
        return 0
    end
end

local function getNecklaceCharges()
    local container = API.Container_Get_all(94)
    if not container or type(container) ~= "table" then
        return 0
    end
    if not container[3] or type(container[3]) ~= "table" then
        return 0
    end
    if not container[3].Extra_ints or type(container[3].Extra_ints) ~= "table" then
        return 0
    end
    if not container[3].Extra_ints[2] or container[3].Extra_ints[2] <= 0 then
        return 0
    end
    return container[3].Extra_ints[2]
end

local function getPorterAmount()
    local buff = API.Buffbar_GetIDstatus(51490, false)
    if (buff and buff.found) then
        local amount = tonumber(buff.text)
        return amount or 0  
    end
    return 0  
end

local function getRequiredAmount()
    local varbitValue = API.GetVarbitValue(52157)
    if varbitValue == 0 then
        return 500
    elseif varbitValue == 1 then
        return 2000
    else
        return 500 
    end
end

local function recordFishTime()
    lastFishTime = API.ScriptRuntime()
end

local function timeSinceLastFish()
    return API.ScriptRuntime() - lastFishTime
end

local function isInDeepSeaHub()
    local player = API.PlayerCoord()
    local px, py, pz = player.x, player.y, player.z
    
    local minX, maxX = math.huge, -math.huge
    local minY, maxY = math.huge, -math.huge
    local minZ, maxZ = 0, 3  -- Deep sea fishing is on levels 0-3
    
    for regionName, region in pairs(regions) do
        local x1, x2 = region.p1.x, region.p2.x
        local y1, y2 = region.p1.y, region.p2.y
        
        minX = math.min(minX, x1, x2)
        maxX = math.max(maxX, x1, x2)
        minY = math.min(minY, y1, y2)
        maxY = math.max(maxY, y1, y2)
        
        if region.p1.z then
            minZ = math.min(minZ, region.p1.z)
        end
        if region.p2.z then
            maxZ = math.max(maxZ, region.p2.z)
        end
    end
    
    local buffer = 5
    minX = minX - buffer
    maxX = maxX + buffer
    minY = minY - buffer
    maxY = maxY + buffer
    
    local inHub = px >= minX and px <= maxX and 
                  py >= minY and py <= maxY and 
                  pz >= minZ and pz <= maxZ
    
    if inHub then
        print(string.format("[INFO] Player is in Deep Sea Fishing hub at (%.1f, %.1f, %d)", px, py, pz))
        print(string.format("[INFO] Hub bounds: X(%.1f-%.1f) Y(%.1f-%.1f) Z(%d-%d)", 
            minX, maxX, minY, maxY, minZ, maxZ))
    else
        print(string.format("[INFO] Player is NOT in Deep Sea Fishing hub"))
        print(string.format("[INFO] Player location: (%.1f, %.1f, %d)", px, py, pz))
        print(string.format("[INFO] Hub bounds: X(%.1f-%.1f) Y(%.1f-%.1f) Z(%d-%d)", 
            minX, maxX, minY, maxY, minZ, maxZ))
    end
    
    return inHub
end

---------------------------------------------------------------------
-- LEVEL 2: PORTER FUNCTIONS (DEPEND ON LEVEL 1) --------------------
---------------------------------------------------------------------

local lastPorterCount = -1
local lastTotalCharges = -1

local function hasPorter()
    local preferred = {29276, 29278, 29280, 29282, 29284, 29286, 51491}
    for _, id in ipairs(preferred) do
        if Inventory:Contains(id) then
            return id, porterCharges[id] or 0
        end
    end
    local fallback = {29275, 29277, 29279, 29281, 29283, 29285, 51490}
    for _, id in ipairs(fallback) do
        if Inventory:Contains(id) then
            return id, porterCharges[id] or 0
        end
    end
    return 0, 0
end

local function howManyPorters()
    local allPorters = {
        29276, 29278, 29280, 29282, 29284, 29286, 51491,
        29275, 29277, 29279, 29281, 29283, 29285, 51490
    }
    local porterCount = 0
    local totalCharges = 0

    for _, id in ipairs(allPorters) do
        if Inventory:Contains(id) then
            local count = Inventory:GetItemAmount(id)
            porterCount = porterCount + count
            totalCharges = totalCharges + (count * (porterCharges[id] or 0))
        end
    end

    if porterCount ~= lastPorterCount or totalCharges ~= lastTotalCharges then
        if porterCount > 0 then
            print("[DEBUG] Porter inventory changed: " .. porterCount .. " porters worth " .. totalCharges .. " total charges")
        else
            print("[DEBUG] No porters in inventory")
        end
        lastPorterCount = porterCount
        lastTotalCharges = totalCharges
    end

    return porterCount, totalCharges
end

local function checkPorter(howMany)
    local buff = API.Buffbar_GetIDstatus(51490, false)
    local hasPorterBuff = buff and buff.found
    
    if not hasPorterBuff then
        return true
    end
    
    local necklaceCharges = getNecklaceCharges() or 0
    local buffCharges = tonumber(buff.text) or 0
    
    local currentCharges = math.max(necklaceCharges, buffCharges)
    
    local needsPorter = currentCharges <= howMany
    
    return needsPorter
end

local function getGOTEChargingThreshold()
    local porterId, porterChargeValue = hasPorter()
    
    local currentState = tostring(porterId) .. "_" .. tostring(porterChargeValue)
    
    if currentState ~= lastPorterInventoryState then
        lastPorterInventoryState = currentState
        
        if porterId > 0 then
            local maxThreshold = 500 - porterChargeValue
            currentGOTEThreshold = math.random(1, maxThreshold)
            print("[DEBUG] Porter inventory changed - new GOTE threshold: " .. currentGOTEThreshold)
        else
            currentGOTEThreshold = math.random(0, 450) 
            print("[DEBUG] No porters available - new GOTE threshold: " .. currentGOTEThreshold)
        end
    end
    
    return currentGOTEThreshold
end

local function hasEnoughPortersForGOTE()
    if not useGOTE then
        return true  -- Not using GOTE, so this check doesn't matter
    end
    
    local requiredAmount = getRequiredAmount()
    local currentAmount = getPorterAmount()
    local chargesNeeded = requiredAmount - currentAmount
    
    if chargesNeeded <= 0 then
        return true  -- Already fully charged
    end
    
    local _, totalPorterCharges = howManyPorters()
    
    print(string.format("[DEBUG] GOTE needs %d more charges, have %d porter charges available", 
        chargesNeeded, totalPorterCharges))
    
    return totalPorterCharges >= chargesNeeded
end

---------------------------------------------------------------------
-- LEVEL 3: NODE & NAVIGATION FUNCTIONS (DEPEND ON LEVEL 1-2) -------
---------------------------------------------------------------------

local nodes = {
    sailfish   = {xMin=2135,xMax=2149,yMin=7124,yMax=7136,name="sailfish"},
    minnows    = {xMin=2127,xMax=2141,yMin=7085,yMax=7101,name="minnows"},
    frenzyS    = {xMin=2062,xMax=2073,yMin=7108,yMax=7112,name="frenzyS"},
    frenzyN    = {xMin=2064,xMax=2074,yMin=7121,yMax=7131,name="frenzyN"},
    swarm      = {xMin=2090,xMax=2103,yMin=7075,yMax=7079,name="swarm"},
    jellyfish  = {xMin=2083,xMax=2114,yMin=7109,yMax=7145,name="jellyfish"},

    minJunc    = {xMin=2117,xMax=2123,yMin=7108,yMax=7112,name="minJunc"},
    midJunc    = {xMin=2097,xMax=2103,yMin=7108,yMax=7113,name="midJunc"},
    southJunc  = {xMin=2102,xMax=2106,yMin=7100,yMax=7105,name="southJunc"},
    
    -- Bank/Net nodes
    bankPorterEnter  = {xMin=2132,xMax=2135,yMin=7103,yMax=7110,name="bankPorterEnter"},
    bankPorterJelly  = {xMin=2096,xMax=2103,yMin=7111,yMax=7116,name="bankPorterJelly"},
    netJelly         = {xMin=2096,xMax=2102,yMin=7089,yMax=7094,name="netJelly"},
    netEnter         = {xMin=2114,xMax=2122,yMin=7121,yMax=7125,name="netEnter"},
}

local function getNodePoint(n)
  if n.xMin then
    return { x = math.floor(n.xMin + math.random()*(n.xMax-n.xMin)),
             y = math.floor(n.yMin + math.random()*(n.yMax-n.yMin)),
             z = 0 }
  end
  return n
end

local function getBankingRegion(fishingAction, usePorters)
    local actionClean = normalizeFishName(fishingAction)
    
    if actionClean == "sailfish" then
        return usePorters and "bankPorterEnter" or "netEnter"
    elseif actionClean == "minnows" then
        return usePorters and "bankPorterEnter" or "netEnter"
    elseif actionClean == "swarm" then
        return usePorters and "bankPorterJelly" or "netJelly"
    elseif actionClean == "jellyfish" or actionClean == "bluejellyfish" or actionClean == "greenjellyfish" then
        return usePorters and "bankPorterJelly" or "netJelly"
    elseif actionClean == "frenzyS" or actionClean == "frenzyN" then
        return usePorters and "bankPorterJelly" or "netJelly"
    else
        return usePorters and "bankPorterJelly" or "netJelly"
    end
end

local function canBankForPorters()
    if not usePorters then
        return false  -- Not using porters at all
    end
    
    local bankingRegion = getBankingRegion(fishingAction, usePorters)
    
    local supportsPorterPresets = (bankingRegion == "bankPorterEnter" or bankingRegion == "bankPorterJelly")
    
    if not supportsPorterPresets then
        print(string.format("[WARN] Current banking region '%s' doesn't support porter presets", bankingRegion))
        return false
    end
    
    print(string.format("[DEBUG] Banking region '%s' supports porter presets", bankingRegion))
    return true
end

local function findPlayerRegion(px,py,pz)  
  for rn,rb in pairs(regions) do
    if inside(px,py,rb,pz) then return normalizeFishName(rn) end
  end
end

local function nearestNode(px,py,nodes)
  local best,bd
  for n,N in pairs(nodes) do
    local nx,ny = N.x or (N.xMin+N.xMax)/2, N.y or (N.yMin+N.yMax)/2
    local d=(px-nx)^2+(py-ny)^2
    if not bd or d<bd then best,bd=n,d end
  end
  return best
end

local function findDepositLocation()
    local bankingRegion = getBankingRegion(fishingAction, usePorters)
    local bankRegion = regions[bankingRegion]
    
    if not bankRegion then
        error(("[ERROR] Invalid banking region: %s"):format(bankingRegion))
        return nil
    end
    
    local randomPt = randomPointInRegion(bankRegion)
    
    local loc = {
        x = randomPt.x,
        y = randomPt.y,
        z = 0
    }
    
    if bankingRegion == "bankPorterEnter" then
        loc.id = 110591
        loc.action = usePorters and 0x33 or 0x3c
        loc.route = usePorters and API.OFF_ACT_GeneralObject_route2 or API.OFF_ACT_GeneralObject_route3

    elseif bankingRegion == "bankPorterJelly" then
        loc.id = 110860
        loc.action = usePorters and 0x33 or 0x3c
        loc.route = usePorters and API.OFF_ACT_GeneralObject_route3 or API.GeneralObject_route_useon

    elseif bankingRegion == "netJelly" then
        loc.id = 110857
        loc.action = 0x29
        loc.route = API.OFF_ACT_GeneralObject_route2

    elseif bankingRegion == "netEnter" then
        loc.id = 110857
        loc.action = 0x29
        loc.route = API.OFF_ACT_GeneralObject_route2

    else
        error(("[ERROR] Unhandled banking region: %s"):format(bankingRegion))
        return nil
    end
    
    print(("[INFO] Selected banking region: %s at (%.1f, %.1f)"):format(bankingRegion, loc.x, loc.y))
    return loc
end

---------------------------------------------------------------------
-- LEVEL 4: CHAT & STATS (DEPEND ON LEVEL 1) ------------------------
---------------------------------------------------------------------

local fishCounts     = {}
local prevFishCounts = {}
local unpack = unpack or table.unpack

local function clearAllFishData()
    print("[INFO] Clearing all previous fish data...")
    
    for _, f in ipairs(FISH_TYPES) do
        local name, _, _, id = unpack(f)
        startingInventory[name] = id and Inventory:GetItemAmount(id) or 0
    end
    
    for _, f in ipairs(FISH_TYPES) do
        fishCounts[f[1]] = 0
        prevFishCounts[f[1]] = 0
    end
    
    totalFish = 0
end

local totalFish= 0
local lastChatCount = 0
local startXp = API.GetSkillXP("FISHING")
local portersUsed = 0

API.SetDrawLogs(true)
API.SetDrawTrackedSkills(true)

local function calcTotalFish()
    local sum = 0
    for _, f in ipairs(FISH_TYPES) do
        sum = sum + fishCounts[f[1]]
    end
    return sum
end

local function countCurrentSessionFish()
    local sessionCounts = {}
    for _, f in ipairs(FISH_TYPES) do
        local name, _, _, id = unpack(f)
        local currentAmount = id and Inventory:GetItemAmount(id) or 0
        local startingAmount = startingInventory[name] or 0
        
        local sessionFish = math.max(0, currentAmount - startingAmount)
        if sessionFish > 0 then
            sessionCounts[name] = sessionFish
        end
    end
    return sessionCounts
end

local function checkForFrenzyCompletion()
    if waitingForFrenzyCompletion and API.ReadPlayerAnim() == 0 then
        waitingForFrenzyCompletion = false
        frenzyInteractions = frenzyInteractions + 1
        lastFishCaught = API.ScriptRuntime()
        
        print(string.format("[DEBUG] Frenzy interaction #%d completed", frenzyInteractions))
        return true
    end
    return false
end 

local function checkForMinnowIncrease()
    if normalizeFishName(fishingAction) == "minnows" then
        local currentMinnowCount = Inventory:GetItemAmount(42241) or 0
        
        if currentMinnowCount > lastKnownMinnowCount then
            local increase = currentMinnowCount - lastKnownMinnowCount
            minnowInteractions = minnowInteractions + increase
            lastKnownMinnowCount = currentMinnowCount
            lastFishCaught = API.ScriptRuntime()
            
            print(string.format("[DEBUG] Minnows increased by %d, total interactions: %d", increase, minnowInteractions))
            return true
        end
        
        lastKnownMinnowCount = currentMinnowCount
    end
    return false
end

local function trackPorterBuffUsage()
    if not usePorters or not activityUsesPorters() then
        return  -- Skip all porter tracking for frenzy/minnows
    end
    
    local currentBuffAmount = getPorterAmount()
    
    if not buffTrackingInitialized or currentBuffAmount > lastPorterBuffAmount then
        lastPorterBuffAmount = currentBuffAmount
        buffTrackingInitialized = true
        if currentBuffAmount > 0 then
            print(string.format("[DEBUG] Porter buff tracking initialized/reset to: %d", currentBuffAmount))
        end
        return
    end
    
    if currentBuffAmount < lastPorterBuffAmount then
        local chargesConsumed = lastPorterBuffAmount - currentBuffAmount
        portersUsed = portersUsed + chargesConsumed
        lastPorterBuffAmount = currentBuffAmount
    end
end

local function detectNewFish()
    if checkForFrenzyCompletion() then
        return true
    end
    
    if checkForMinnowIncrease() then
        return true
    end
    
    if normalizeFishName(fishingAction) == "frenzyS" or normalizeFishName(fishingAction) == "frenzyN" then
        return false  -- Frenzy tracking is handled via checkForFrenzyCompletion()
    end
    
    if normalizeFishName(fishingAction) == "minnows" then
        return false  -- Minnow tracking is handled via checkForMinnowIncrease()
    end
    
    local currentInventory = countCurrentSessionFish()
    local currentTotal = 0
    for _, count in pairs(currentInventory) do
        currentTotal = currentTotal + count
    end
    
    if currentTotal ~= lastKnownFishCount then
        --print(string.format("[DEBUG] Fish count changed: %d -> %d", lastKnownFishCount, currentTotal))
    end
    
    if currentTotal > lastKnownFishCount then
        lastFishCaught = API.ScriptRuntime()
        lastKnownFishCount = currentTotal
        
        return true
    end
    
    lastKnownFishCount = currentTotal  -- Always update the known count
    return false
end

local function timeSinceLastFishCaught()
    return API.ScriptRuntime() - lastFishCaught
end

local function updateInventoryBaseline()
    print("[INFO] Updating inventory baseline after banking...")
    for _, f in ipairs(FISH_TYPES) do
        local name, _, _, id = unpack(f)
        startingInventory[name] = id and Inventory:GetItemAmount(id) or 0
    end
    
    lastKnownFishCount = 0
    
    if normalizeFishName(fishingAction) == "minnows" then
        lastKnownMinnowCount = Inventory:GetItemAmount(42241) or 0
        print("[DEBUG] Minnow baseline updated to: " .. lastKnownMinnowCount)
    end
    
    print("[DEBUG] New baseline set, lastKnownFishCount reset to 0")
end

local function findChatText()
    local chats = API.GatherEvents_chat_check()
    for i = lastChatCount + 1, #chats do
        local txt = chats[i].text
        if txt then
            local lower = string.lower(txt)
            local cnt, fishName = string.match(
                lower,
                "^you transport to your bank:%s*(%d+)%s*x%s*raw%s*([^.]+)"
            )
            cnt = tonumber(cnt)
            if cnt and fishName then
                for _, f in ipairs(FISH_TYPES) do
                    if fishName == f[3] then
                        fishCounts[f[1]] = fishCounts[f[1]] + cnt
                        break
                    end
                end
            end
        end
    end
    lastChatCount = #chats
    totalFish = calcTotalFish()
end

local function getStatsData()
    local profit_total = 0
    local fishData = {}
    
    for _, f in ipairs(FISH_TYPES) do
        local cnt = fishCounts[f[1]]
        if cnt > 0 then
            local price = f[4] and (prices[f[4]] or 0) or 0
            local tot = cnt * price
            profit_total = profit_total + tot
            
            table.insert(fishData, {
                name = f[2],
                count = cnt,
                price = price,
                total = tot
            })
        end
    end
    
    local xpGained = API.GetSkillXP("FISHING") - startXp
    local elapsed = API.ScriptRuntime()
    local xpPerHr = elapsed > 0 and math.floor(xpGained * 3600 / elapsed) or 0
    local profitPerHr = elapsed > 0 and math.floor(profit_total * 3600 / elapsed) or 0
    
    return {
        fishData = fishData,
        xpGained = xpGained,
        xpPerHr = xpPerHr,
        profit_total = profit_total,
        profitPerHr = profitPerHr
    }
end

local function resetScriptVariables()
    print("[INFO] Resetting script variables for new run...")
    
    startingInventory = {}
    for _, f in ipairs(FISH_TYPES) do
        local name, _, _, id = unpack(f)
        startingInventory[name] = id and Inventory:GetItemAmount(id) or 0
    end
    
    fishCounts = {}
    for _, f in ipairs(FISH_TYPES) do
        fishCounts[f[1]] = 0
    end
    
    totalFish = 0
    lastChatCount = 0
    portersUsed = 0  -- Back to tracking individual charges
    lastPorterBuffAmount = 0  -- Reset buff tracking
    buffTrackingInitialized = false  -- Reset initialization flag
    frenzyInteractions = 0
    waitingForFrenzyCompletion = false
    minnowInteractions = 0
    lastKnownMinnowCount = Inventory:GetItemAmount(42241) or 0
    
    lastDisplayedValues = {
        totalFish = 0, xpGained = 0, gpEarned = 0, porterCharges = 0,
        porterCount = 0, totalCharges = 0, portersUsed = 0, inventorySpaces = 0,
        playerAnim = 0, playerMoving = false, currentRegion = "", playerX = 0, playerY = 0,
        inventoryHash = "", timeSinceActionSeconds = 0, timeSinceFishSeconds = 0,
        nextIdleSeconds = 0, auraTimeMinutes = 0, runtimeMinutes = 0
    }
    
    lastFishCaught = API.ScriptRuntime()
    lastKnownFishCount = 0
    
    currentGOTEThreshold = 0
    lastPorterInventoryState = ""
    lastPorterCount = -1
    lastTotalCharges = -1
    
    startXp = API.GetSkillXP("FISHING")
    lastFishTime = API.ScriptRuntime()
    afk = API.ScriptRuntime()
    randomTime = 0
end

---------------------------------------------------------------------
-- LEVEL 5: METRICS FUNCTIONS (DEPEND ON LEVEL 1-4) -----------------
---------------------------------------------------------------------

local function calculateInventoryValue(sessionInventory)
    local totalValue = 0
    for name, count in pairs(sessionInventory) do
        for _, f in ipairs(FISH_TYPES) do
            if f[1] == name and f[4] then
                local price = prices[f[4]] or 0
                totalValue = totalValue + (count * price)
                break
            end
        end
    end
    return totalValue
end

local lastDisplayedValues = {
    totalFish = 0,
    xpGained = 0,
    gpEarned = 0,
    porterCharges = 0,
    porterCount = 0,
    totalCharges = 0,
    portersUsed = 0,
    inventorySpaces = 0,
    playerAnim = 0,
    playerMoving = false,
    currentRegion = "",
    playerX = 0,
    playerY = 0,
    inventoryHash = "",
    timeSinceActionSeconds = 0,
    timeSinceFishSeconds = 0,
    auraTimeMinutes = 0,
    runtimeMinutes = 0
}

local function hasSignificantChange()
    local stats = getStatsData()
    
    local currentCharges = 0
    local porterCount, totalCharges = 0, 0
    if usePorters and activityUsesPorters() then
        currentCharges = getPorterAmount()
        porterCount, totalCharges = howManyPorters()
    end
    
    local sessionInventory = countCurrentSessionFish()
    local sessionFishTotal = 0
    for _, count in pairs(sessionInventory) do
        sessionFishTotal = sessionFishTotal + count
    end
    local inventoryValue = calculateInventoryValue(sessionInventory)
    local totalGpEarned = stats.profit_total + inventoryValue
    local totalSessionFish = sessionFishTotal + totalFish
    local playerAnim = API.ReadPlayerAnim()
    local playerMoving = API.ReadPlayerMovin2()
    local player = API.PlayerCoord()
    local px, py, pz = player.x, player.y, player.z 
    local currentRegion = findPlayerRegion(px, py, pz) or "Unknown"
    
    local inventorySpaces = 0
    if activityUsesPorters() then
        inventorySpaces = Inventory:FreeSpaces()
    end
    
    local timeSinceActionSeconds = math.floor(timeSinceLastFish())
    local runtimeMinutes = math.floor(API.ScriptRuntime() / 60)
    
    local auraTimeMinutes = 0
    if whichAura and whichAura ~= "" then
        local auraTime = AURAS.auraTimeRemaining()
        auraTimeMinutes = auraTime > 0 and math.floor(auraTime / 60) or 0
    end
    
    local inventoryItems = {}
    for name, count in pairs(sessionInventory) do
        table.insert(inventoryItems, name .. ":" .. count)
    end
    table.sort(inventoryItems)
    local inventoryHash = table.concat(inventoryItems, "|")
    
    local hasChanges = false
    
    local porterChanges = false
    if activityUsesPorters() then
        porterChanges = (lastDisplayedValues.porterCharges ~= currentCharges or
                        lastDisplayedValues.porterCount ~= porterCount or
                        lastDisplayedValues.totalCharges ~= totalCharges or
                        lastDisplayedValues.portersUsed ~= portersUsed or
                        lastDisplayedValues.inventorySpaces ~= inventorySpaces)
    end
    
    if lastDisplayedValues.totalFish ~= totalSessionFish or
       lastDisplayedValues.xpGained ~= stats.xpGained or
       lastDisplayedValues.gpEarned ~= totalGpEarned or
       porterChanges or
       lastDisplayedValues.playerAnim ~= playerAnim or
       lastDisplayedValues.playerMoving ~= playerMoving or
       lastDisplayedValues.currentRegion ~= currentRegion or
       lastDisplayedValues.playerX ~= player.x or
       lastDisplayedValues.playerY ~= player.y or
       lastDisplayedValues.inventoryHash ~= inventoryHash or
       lastDisplayedValues.timeSinceActionSeconds ~= timeSinceActionSeconds or
       lastDisplayedValues.auraTimeMinutes ~= auraTimeMinutes or
       lastDisplayedValues.runtimeMinutes ~= runtimeMinutes then
        
        hasChanges = true
        
        lastDisplayedValues.totalFish = totalSessionFish
        lastDisplayedValues.xpGained = stats.xpGained
        lastDisplayedValues.gpEarned = totalGpEarned
        lastDisplayedValues.porterCharges = currentCharges
        lastDisplayedValues.porterCount = porterCount
        lastDisplayedValues.totalCharges = totalCharges
        lastDisplayedValues.portersUsed = portersUsed
        lastDisplayedValues.inventorySpaces = inventorySpaces
        lastDisplayedValues.playerAnim = playerAnim
        lastDisplayedValues.playerMoving = playerMoving
        lastDisplayedValues.currentRegion = currentRegion
        lastDisplayedValues.playerX = player.x
        lastDisplayedValues.playerY = player.y
        lastDisplayedValues.inventoryHash = inventoryHash
        lastDisplayedValues.timeSinceActionSeconds = timeSinceActionSeconds
        lastDisplayedValues.auraTimeMinutes = auraTimeMinutes
        lastDisplayedValues.runtimeMinutes = runtimeMinutes
    end
    
    return hasChanges
end

local function buildMetricsTable()
    local stats = getStatsData()
    
    local currentCharges = 0
    local porterCount, totalCharges = 0, 0
    if usePorters and activityUsesPorters() then
        currentCharges = getPorterAmount()
        porterCount, totalCharges = howManyPorters()
    end
    
    local sessionInventory = countCurrentSessionFish()
    local runtimeSeconds = API.ScriptRuntime()
    
    local sessionFishTotal = 0
    for name, count in pairs(sessionInventory) do
        sessionFishTotal = sessionFishTotal + count
    end
    
    local inventoryValue = calculateInventoryValue(sessionInventory)
    local totalGpEarned = stats.profit_total + inventoryValue
    
    local totalSessionFish
    local fishPerHour
    local fishLabel
    local showGP = true  -- Whether to show GP tracking
    
    if normalizeFishName(fishingAction) == "frenzyS" or normalizeFishName(fishingAction) == "frenzyN" then
        totalSessionFish = frenzyInteractions + totalFish
        fishLabel = "Interactions:"
        showGP = false  -- No GP for frenzy
    elseif normalizeFishName(fishingAction) == "minnows" then
        totalSessionFish = minnowInteractions + totalFish
        fishLabel = "Minnows:"
        showGP = false  -- No GP for minnows
    else
        totalSessionFish = sessionFishTotal + totalFish
        fishLabel = "Fish:"
        showGP = true   -- Regular fishing has GP
    end
    
    fishPerHour = runtimeSeconds > 0 and math.floor(totalSessionFish * 3600 / runtimeSeconds) or 0
    local profitPerHr = runtimeSeconds > 0 and math.floor(totalGpEarned * 3600 / runtimeSeconds) or 0
    
    local metrics = {
        { "Deep Sea Fishing", fishingAction .. " (Required Level: " .. levelRequirements[fishingAction] .. ")" },
        { "", "" },
        { "Runtime:", API.ScriptRuntimeString() },
        { fishLabel, string.format("%d (%d/h)", totalSessionFish, fishPerHour) },
        { "XP:", string.format("%s (%s/h)", format_number(stats.xpGained), format_number(stats.xpPerHr)) },
    }
    
    if showGP then
        table.insert(metrics, { "GP:", string.format("%s (%s/h)", format_number(totalGpEarned), format_number(profitPerHr)) })
    end
    
    table.insert(metrics, { "", "" })
    table.insert(metrics, { "Player State:", string.format("Animating: %s", API.ReadPlayerAnim()) })
    table.insert(metrics, { "", string.format("Moving: %s", tostring(API.ReadPlayerMovin2())) })
    table.insert(metrics, { "", "" })
    
    if activityUsesPorters() then
        table.insert(metrics, { "Inventory:", string.format("%d/28 free spaces", Inventory:FreeSpaces()) })
    end
    
    table.insert(metrics, { "Region:", findPlayerRegion(API.PlayerCoord().x, API.PlayerCoord().y, API.PlayerCoord().z) or "Unknown" })
    
    local interacting = API.ReadLpInteracting()
    if interacting and interacting.Name and interacting.Name ~= "" then
        table.insert(metrics, { "Interacting:", interacting.Name })
    end
    
    local timeSinceAction = timeSinceLastFish()
    if timeSinceAction > 0 then
        table.insert(metrics, { "Last Action:", string.format("%.0fs ago", timeSinceAction) })
    end
    
    if usePorters and activityUsesPorters() then
        table.insert(metrics, { "", "" })
        if useGOTE then
            local requiredAmount = getRequiredAmount()
            local chargePercent = math.floor((currentCharges / requiredAmount) * 100)
            table.insert(metrics, { "GOTE:", string.format("%d%% (%d/%d)", chargePercent, currentCharges, requiredAmount) })
        else
            local activeCharges = getPorterAmount()
            if activeCharges > 0 then
                table.insert(metrics, { "Porter:", string.format("%d active", activeCharges) })
            end
        end
        
        table.insert(metrics, { "Inventory:", string.format("%d porters (%d charges)", porterCount, totalCharges) })
        table.insert(metrics, { "Used:", string.format("%d charges", portersUsed) })
    end
    
    local hasSessionFish = false
    if activityUsesPorters() then  
        for name, count in pairs(sessionInventory) do
            if not hasSessionFish then
                table.insert(metrics, { "", "" })
                hasSessionFish = true
            end
            
            local displayName = name
            for _, f in ipairs(FISH_TYPES) do
                if f[1] == name then
                    displayName = f[2]
                    break
                end
            end
            
            local fishValue = 0
            for _, f in ipairs(FISH_TYPES) do
                if f[1] == name and f[4] then
                    fishValue = count * (prices[f[4]] or 0)
                    break
                end
            end
            
            table.insert(metrics, { 
                displayName .. ":", 
                string.format("%d (%s gp)", count, format_number(fishValue))
            })
        end
    end
    
    if whichAura and whichAura ~= "" then
        local auraTime = AURAS.auraTimeRemaining()
        if auraTime > 0 then
            table.insert(metrics, { "", "" })
            table.insert(metrics, { "Aura:", string.format("%.0f min left", auraTime / 60) })
        end
    end
    
    local currentConfigState = string.format("%s_%s_%s", fishingAction, tostring(usePorters), tostring(useGOTE))
    if not configurationDisplayed or lastConfigState ~= currentConfigState then
        table.insert(metrics, { "", "" })
        table.insert(metrics, { "-- Configuration --", "" })
        
        if activityUsesPorters() then
            table.insert(metrics, { "Porters:", tostring(usePorters) })
            table.insert(metrics, { "GOTE:", tostring(useGOTE) })
            table.insert(metrics, { "Banking:", usePorters and "Porter/Bank" or "Fishing Net" })
        else
            table.insert(metrics, { "Activity:", "No porters needed" })
        end
        
        table.insert(metrics, { "Randoms:", tostring(watchRandoms) })
        if whichAura and whichAura ~= "" then
            table.insert(metrics, { "Aura:", whichAura })
        end
        
        configurationDisplayed = true
        lastConfigState = currentConfigState
    end
    
    return metrics
end

local function tracking()
    if not API.Read_LoopyLoop() then 
        return 
    end
    
    detectNewFish()
    trackPorterBuffUsage() 
    
    if hasSignificantChange() then
        local metrics = buildMetricsTable()
        API.DrawTable(metrics)
    end
end

---------------------------------------------------------------------
-- LEVEL 6: PATHFINDING (DEPEND ON LEVEL 1-5) -----------------------
---------------------------------------------------------------------

local function find_path(startLocation, destinationLocation)
    local playerPosition = API.PlayerCoord()
    
    if not edges[startLocation] then
        startLocation = nearestNode(playerPosition.x, playerPosition.y, nodes)
        print(("[WARN] find_path: startLocation was invalid, reset to '%s'"):format(startLocation))
    end
    
    if not edges[destinationLocation] then
        destinationLocation = nearestNode(playerPosition.x, playerPosition.y, nodes)
        print(("[WARN] find_path: destinationLocation was invalid, reset to '%s'"):format(destinationLocation))
    end
    
    local validEdges = {}
    for currentNode, connectedNodes in pairs(edges) do
        validEdges[currentNode] = {}
        for _, connectedNode in ipairs(connectedNodes) do
            if nodes[connectedNode] then
                table.insert(validEdges[currentNode], connectedNode)
            end
        end
    end
    
    if (startLocation == "frenzyN" and destinationLocation == "frenzyS") or 
       (startLocation == "frenzyS" and destinationLocation == "frenzyN") then
        table.insert(validEdges["frenzyN"], "frenzyS")
        table.insert(validEdges["frenzyS"], "frenzyN")
    end
    
    local pathQueue = { { startLocation } }
    local visitedNodes = { [startLocation] = true }
    
    while #pathQueue > 0 do
        local currentPath = table.remove(pathQueue, 1)
        local currentNode = currentPath[#currentPath]
        
        if currentNode == destinationLocation then
            return currentPath
        end
        
        for _, nextNode in ipairs(validEdges[currentNode] or {}) do
            if not visitedNodes[nextNode] then
                visitedNodes[nextNode] = true
                local newPath = { table.unpack(currentPath) }
                table.insert(newPath, nextNode)
                table.insert(pathQueue, newPath)
            end
        end
    end
    
    return nil
end

local function walkPath(path, startPlayerPos, dest)
    if not path or #path == 0 then
        print("[INFO] walkPath: Empty path, no movement needed")
        return
    end

    local i = 1
    while i <= #path do
        -- CRITICAL: Check if script should stop
        if not API.Read_LoopyLoop() then 
            print("[INFO] Script stopping during walkPath")
            return 
        end
        
        local player = API.PlayerCoord()
        local px, py, pz = player.x, player.y, player.z
        local isFinal = (i == #path)
        local label = isFinal and dest or path[i]
        
        local shouldSkip = false
        if not isFinal and insideRegion(px, py, regions, path[i], pz) then
            print(string.format("[INFO] walkPath: Already inside %s, skipping to next waypoint", path[i]))
            shouldSkip = true
        end
        
        if not shouldSkip then
            if not isFinal then
                local minDistance = 8
                local maxDistance = 25
                local furthestIndex = i
                
                for j = i + 1, #path do
                    local waypointRegion = regions[path[j]]
                    local distance
                    
                    if waypointRegion then
                        local randomPt = randomPointInRegion(waypointRegion)
                        distance = dist2(player, randomPt)
                    else
                        local nodePt = getNodePoint(nodes[path[j]])
                        if nodePt then
                            distance = dist2(player, nodePt)
                        else
                            break
                        end
                    end
                    
                    if distance >= minDistance and distance <= maxDistance then
                        furthestIndex = j
                    elseif distance > maxDistance then
                        break
                    end
                end
                
                if furthestIndex > i then
                    print(string.format("[INFO] walkPath: Skipping %d waypoints, jumping from %s to %s", 
                        furthestIndex - i, path[i], path[furthestIndex]))
                    i = furthestIndex
                    label = path[i]
                    isFinal = (i == #path)
                    if isFinal then
                        label = dest
                    end
                end
            end
            
            local pt
            if regions[path[i]] then
                local randomPt = randomPointInRegion(regions[path[i]])
                pt = { x = randomPt.x, y = randomPt.y, z = randomPt.z or 0 }
                print(string.format("Walking to %s (%d/%d) @ (%.2f,%.2f) [randomPointInRegion] (distance: %.1f)", 
                    label, i, #path, pt.x, pt.y, dist2(player, pt)))
            else
                local nodePt = getNodePoint(nodes[path[i]])
                pt = { x = nodePt.x, y = nodePt.y, z = nodePt.z or 0 }
                print(string.format("Walking to %s (%d/%d) @ (%.2f,%.2f) [getNodePoint] (distance: %.1f)", 
                    label, i, #path, pt.x, pt.y, dist2(player, pt)))
            end
            
            API.DoAction_Tile(WPOINT.new(pt.x, pt.y, pt.z or 0))
            API.RandomSleep2(1200,600,600)
            
            repeat
                if not API.Read_LoopyLoop() then 
                    print("[INFO] Script stopping during movement")
                    return 
                end
                
                API.RandomSleep2(100,100,100)
                tracking()

                local player = API.PlayerCoord()
                local px, py, pz = player.x, player.y, player.z
                local isMoving = API.ReadPlayerMovin2()

                if math.random() < 0.2 then  -- 20% chance to log progress
                    print(string.format("[DEBUG] Movement progress: (%.1f,%.1f) -> target (%.1f,%.1f), moving=%s, distance=%.1f", 
                        px, py, pt.x, pt.y, tostring(isMoving), dist2(player, pt)))
                end

                local dx, dy, dz = px - pt.x, py - pt.y, pz - pt.z
                local closeEnough = (dx*dx + dy*dy) <= 36
                local inCurrentRegion = insideRegion(px, py, regions, path[i], pz)
                local inDestRegion = isFinal and insideRegion(px, py, regions, dest, pz)
                    
                local shouldStop = false
                if isFinal then
                    if inDestRegion then
                        shouldStop = true
                        print(string.format("[INFO] Successfully reached %s region at (%.1f,%.1f,%d)", dest, px, py, pz))
                    else
                        local destRegion = regions[dest]
                        local inDestRegionLenient = false
                        if destRegion then
                            local x1, x2 = math.min(destRegion.p1.x, destRegion.p2.x), math.max(destRegion.p1.x, destRegion.p2.x)
                            local y1, y2 = math.min(destRegion.p1.y, destRegion.p2.y), math.max(destRegion.p1.y, destRegion.p2.y)
                            inDestRegionLenient = px >= x1 and px <= x2 and py >= y1 and py <= y2
                        end
                        
                        if inDestRegionLenient then
                            print(string.format("[WARN] Reached %s with X,Y correct but Z mismatch. Player: (%.1f,%.1f,%d)", dest, px, py, pz))
                            shouldStop = true
                        elseif not API.ReadPlayerMovin2() then
                            -- Failed to reach endpoint region - don't error, just stop
                            print(string.format("[ERROR] Failed to reach %s. Player pos: (%.1f,%.1f,%d)", dest, px, py, pz))
                            if destRegion then
                                print(string.format("[ERROR] Target region: X(%.1f-%.1f) Y(%.1f-%.1f) Z(%d-%d)", 
                                    destRegion.p1.x, destRegion.p2.x, destRegion.p1.y, destRegion.p2.y,
                                    destRegion.p1.z or 0, destRegion.p2.z or 3))
                            end
                            print("[ERROR] Stopping movement attempt")
                            return  -- Return instead of error()
                        end
                    end
                else
                    shouldStop = inCurrentRegion or closeEnough
                end
            until shouldStop
        end
        i = i + 1
    end
end

function doMovement()
    if not API.Read_LoopyLoop() then return end

    local player = API.PlayerCoord()
    local x, y, z   = player.x, player.y, player.z
    local dest   = normalizeFishName(fishingAction)

    local pr = findPlayerRegion(x, y, z)
    if not pr and inside(x, y, regions[dest], z) then
        pr = dest
    end
    if not pr then
        pr = nearestNode(x, y, nodes)
        print(("[WARN] doMovement: pr was nil, using nearest node '%s'"):format(pr))
    end

    if pr == dest then
        print(("[INFO] Already at destination: %s"):format(dest))
        return
    end

    if (pr=="frenzyN" and dest=="frenzyS") or (pr=="frenzyS" and dest=="frenzyN") then
        print(("Direct walk %s -> %s"):format(pr, dest))
        local randomPt = randomPointInRegion(regions[dest])
        local pt = { x = randomPt.x, y = randomPt.y, z = randomPt.z or 0 }
        print(("Direct walk point @ (%.2f,%.2f) [randomPointInRegion]"):format(pt.x, pt.y))
        API.DoAction_Tile(WPOINT.new(pt.x, pt.y, pt.z))
        API.RandomSleep2(600,600,1800)
        repeat
            -- CRITICAL: Check if script should stop
            if not API.Read_LoopyLoop() then 
                print("[INFO] Script stopping during direct walk")
                return 
            end
            
            API.RandomSleep2(100,100,100)
            tracking()
        until not API.ReadPlayerMovin2()
           or (function(p)
                 local pos = API.PlayerCoord()
                 local dx, dy = pos.x - p.x, pos.y - p.y
                 return dx*dx + dy*dy <= 36
               end)(pt)
        return
    end

    local fullPath = find_path(pr, dest)
    if not fullPath or #fullPath < 2 then
        print(("[ERROR] No path from %s -> %s"):format(pr, dest))
        return
    end

    if #fullPath > 1 and fullPath[1] == pr then
        print(("[INFO] Removing starting location '%s' from path (already there)"):format(pr))
        table.remove(fullPath, 1)
    end

    if not fullPath or #fullPath < 1 then
        print(("[INFO] No movement needed, already at or very close to %s"):format(dest))
        return
    end

    if pr == "jellyfish" and #fullPath > 0 and fullPath[1] == "midJunc" then
        local midPt = getNodePoint(nodes["midJunc"])
        local dx, dy = player.x - midPt.x, player.y - midPt.y
        if dx*dx + dy*dy < 81 then
            table.remove(fullPath, 1)
            print("[INFO] Skipping midJunc since we're already within 9 tiles of it")
        end
    end

    if not fullPath or #fullPath < 1 then
        print(("[INFO] All waypoints removed, already at destination %s"):format(dest))
        return
    end

    print(("[INFO] Walking path: %s"):format(table.concat(fullPath, " -> ")))
    walkPath(fullPath, player, dest)
end

local function doMovementToBanking()
    if not API.Read_LoopyLoop() then return end

    local player = API.PlayerCoord()
    local x, y, z = player.x, player.y, player.z
    local dest   = getBankingRegion(fishingAction, usePorters)

    local pr = findPlayerRegion(x, y, z)
    if not pr and inside(x, y, regions[dest], z) then 
        pr = dest
    end
    if not pr then
        pr = nearestNode(x, y, nodes)
        print(("[WARN] doMovementToBanking: pr was nil, using nearest node '%s'"):format(pr))
    end

    if pr == dest then
        print(("[INFO] Already at banking destination: %s"):format(dest))
        return
    end

    local fullPath = find_path(pr, dest)
    if not fullPath or #fullPath < 2 then
        print(("[ERROR] No path from %s -> %s"):format(pr, dest))
        return
    end

    if #fullPath > 1 and fullPath[1] == pr then
        print(("[INFO] Banking: Removing starting location '%s' from path (already there)"):format(pr))
        table.remove(fullPath, 1)
    end

    if not fullPath or #fullPath < 1 then
        print(("[INFO] Banking: No movement needed, already at %s"):format(dest))
        return
    end

    print(("[INFO] Banking path: %s"):format(table.concat(fullPath, " -> ")))
    walkPath(fullPath, player, dest)  -- Uses the fixed walkPath with loop safety
end

---------------------------------------------------------------------
-- LEVEL 7: BANKING FUNCTIONS (DEPEND ON LEVEL 1-6) -----------------
---------------------------------------------------------------------

local function interactObject(loc, timeout)
    print(string.format("[DEBUG] Attempting to interact with object ID %d at (%.1f, %.1f)", loc.id, loc.x, loc.y))
    
    local routeName = "Unknown"
    if loc.route == API.OFF_ACT_GeneralObject_route2 then
        routeName = "API.OFF_ACT_GeneralObject_route2"
    elseif loc.route == API.OFF_ACT_GeneralObject_route3 then
        routeName = "API.OFF_ACT_GeneralObject_route3"
    elseif loc.route == API.GeneralObject_route_useon then
        routeName = "API.GeneralObject_route_useon"
    end
    
    print(string.format("[DEBUG] Using action: 0x%x, route: %s", loc.action, routeName))
    
    local interactionResult = API.DoAction_Object1(loc.action, loc.route, { loc.id }, 50)

    print(string.format("[DEBUG] Interaction result: %s", tostring(interactionResult)))
    
    if not interactionResult then
        print("[ERROR] Banking interaction failed - DoAction_Object1 returned false")
        return false
    end
    
    API.RandomSleep2(math.random(1200,2400), 600, math.random(600,1200))

    local start = os.time()
    repeat
        if not API.Read_LoopyLoop() then 
            print("[INFO] Script stopping during banking interaction")
            return false 
        end
        
        API.RandomSleep2(math.random(100, 200), 50, 50)
        tracking()
        
        if os.time() - start >= timeout then
            print(("[ERROR] interaction timed out after %ds"):format(timeout))
            return false  -- Return false instead of stopping script
        end
    until not API.ReadPlayerMovin2()

    print("[INFO] deposit interaction complete & movement stopped")
    return true
end

local function chargeGOTE()
    if not useGOTE then
        return false
    end

    local requiredAmount = getRequiredAmount()
    local currentAmount = getPorterAmount()
    
    print("[DEBUG] Charging GOTE - current: " .. currentAmount .. ", required: " .. requiredAmount)
    
    local maxAttempts = 5  -- Limit charging attempts
    local attempts = 0

    while currentAmount < requiredAmount and attempts < maxAttempts do
        if not API.Read_LoopyLoop() then 
            print("[INFO] Script stopping during GOTE charging")
            return false 
        end
        
        attempts = attempts + 1
        print(string.format("[DEBUG] GOTE charging attempt %d/%d", attempts, maxAttempts))
        
        tracking()
        API.RandomSleep2(200, 100, 100) 
        
        local porterCount, porterCharges = howManyPorters()
        print(string.format("[DEBUG] Available: %d porters (%d charges)", porterCount, porterCharges))
        
        if porterCount < 1 then
            print("[ERROR] No porters available for GOTE charging")
            return false  -- Return false instead of erroring
        end
        
        local chargesNeeded = requiredAmount - currentAmount
        if porterCharges < chargesNeeded then
            print(string.format("[WARN] Insufficient porter charges: need %d, have %d", chargesNeeded, porterCharges))
            print("[WARN] Will attempt partial charging")
        end
        
        if not AURAS.isEquipmentOpen() then
            if not AURAS.openEquipment() then 
                print("[ERROR] Unable to open equipment tab")
                return false
            end
        end
        
        if getNecklaceID() == 0 then
            print("[ERROR] Unable to determine necklace slot")
            return false
        end
        
        local beforeAmount = getPorterAmount()
        local beforePorters, beforeCharges = howManyPorters()
        
        print(string.format("[DEBUG] Before charging: GOTE=%d, porters=%d (%d charges)", 
            beforeAmount, beforePorters, beforeCharges))
        
        local currentPorters, _ = howManyPorters()
        local chargeResult = API.DoAction_Interface(0xffffffff,API.GetEquipSlot(2).itemid1,6,1464,15,2,API.OFF_ACT_GeneralInterface_route2)
        
        if chargeResult then
            print("[DEBUG] - Charging grace of the elves with " .. tostring(currentPorters) .. " porters")
            API.RandomSleep2(math.random(800, 1600), 300, 600)
        else
            print("[ERROR] Failed to initiate GOTE charging interface")
            return false
        end
        
        if API.VB_FindPSettinOrder(2874).state == 1572882 then
            print("[DEBUG] - Detected confirmation window for recharging grace of the elves")
            local confirmResult = API.DoAction_Interface(0xFFFFFFFF, 0xFFFFFFFF, 0, 847, 22, -1, API.OFF_ACT_GeneralInterface_Choose_option)
            if confirmResult then
                print("[DEBUG] - Selecting yes to confirm using porters")
                API.RandomSleep2(math.random(1200, 2400), 600, 600)
            else
                print("[ERROR] Failed to confirm GOTE charging")
                return false
            end
        else
            print("[WARN] No confirmation dialog detected")
        end
        
        local afterAmount = getPorterAmount()
        local afterPorters, afterCharges = howManyPorters()
        
        print(string.format("[DEBUG] After charging: GOTE=%d, porters=%d (%d charges)", 
            afterAmount, afterPorters, afterCharges))
        
        if afterAmount == beforeAmount and afterPorters == beforePorters then
            print("[ERROR] No progress made in charging attempt - interface may have failed")
            return false
        end
        
        currentAmount = afterAmount
        print("[DEBUG] - Updated porter amount: " .. currentAmount)
        
        if currentAmount < requiredAmount and afterPorters == 0 then
            print(string.format("[ERROR] Ran out of porters but still need %d more GOTE charges", 
                requiredAmount - currentAmount))
            return false
        end
    end
    
    if attempts >= maxAttempts then
        print(string.format("[ERROR] Failed to charge GOTE after %d attempts", maxAttempts))
        return false
    end
    
    if not AURAS.isBackpackOpen() then
        if not AURAS.openBackpack() then 
            print("[ERROR] Failed to re-open the backpack tab")
            return false
        end
    end
    
    local finalAmount = getPorterAmount()
    print("[DEBUG] - Successfully charged GOTE to: " .. finalAmount)
    return finalAmount >= requiredAmount
end

local function depositAtBank()
    print("[INFO] Going to bank...")
    
    doMovementToBanking()
    tracking()
    
    local loc = findDepositLocation()
    if not loc then
        error("[ERROR] Could not determine deposit location")
        return false
    end
    
    print(("Banking at: %s (x=%.1f, y=%.1f)"):format(getBankingRegion(fishingAction, usePorters), loc.x, loc.y))
    print(string.format("[DEBUG] Banking details: ID=%d, action=0x%x", loc.id, loc.action))
    print(loc.route)
    
    local player = API.PlayerCoord()
    local px, py, pz = player.x, player.y, player.z
    local bankingRegion = getBankingRegion(fishingAction, usePorters)

    if not insideRegion(px, py, regions, bankingRegion, pz) then
        error("[ERROR] failed to travel to bank")
        return false
    end
    
    if not interactObject(loc, 15) then 
        error("[ERROR] failed to interact with bank") 
        return false 
    end
    
    if not AURAS.maybeEnterPin() then
        error("[ERROR] failed to input bank pin")
        API.Write_LoopyLoop(false)
        return false
    end
    
    API.RandomSleep2(math.random(600,1800), 600, math.random(600,1200))
    
    if useGOTE then
        local currentCharges = getPorterAmount()
        local requiredAmount = getRequiredAmount()
        
        print("[DEBUG] At bank - GOTE charges: " .. currentCharges .. ", required: " .. requiredAmount)
        
        if currentCharges < requiredAmount then

            local porterCount, totalPorterCharges = howManyPorters()
            if not hasEnoughPortersForGOTE() then
                print("[ERROR] Insufficient porters in preset for GOTE charging!")
                print(string.format("[ERROR] Need %d more GOTE charges but only have %d porter charges", 
                    requiredAmount - currentCharges, totalPorterCharges))
                print("[ERROR] Please add more porters to your bank preset")
                error("[ERROR] Cannot continue without sufficient porters for GOTE")
                return false
            end
            
            print("[DEBUG] GOTE needs charging and sufficient porters available")
            if not chargeGOTE() then
                error("[ERROR] Failed to charge grace of the elves")
                API.Write_LoopyLoop(false)
                return false
            end
        else
            print("[DEBUG] GOTE charges sufficient, no charging needed")
        end
    end
    
    if checkPorter(0) and usePorters and not useGOTE then
        local porterId, _ = hasPorter()
        if porterId > 0 then
            API.DoAction_Inventory1(porterId, 0, 2, API.OFF_ACT_GeneralInterface_route)
            API.RandomSleep2(math.random(600, 1800), 600, 330)
        end
    end
    tracking()
    updateInventoryBaseline()
    return true
end

local function depositAtNet()
    local loc = findDepositLocation()
    if not loc then
        error("[ERROR] Could not determine deposit location")
        return false
    end
    
    print(("Depositing at net: %s (x=%.1f, y=%.1f)"):format(getBankingRegion(fishingAction, usePorters), loc.x, loc.y))

    local beforeCounts = {}
    for _, f in ipairs(FISH_TYPES) do
        local name, _, _, id = unpack(f)
        beforeCounts[name] = id and Inventory:GetItemAmount(id) or 0
    end

    doMovementToBanking()
    tracking()
    
    local player = API.PlayerCoord()
    local px, py, pz = player.x, player.y, player.z
    local bankingRegion = getBankingRegion(fishingAction, usePorters)
    if not insideRegion(px, py, regions, bankingRegion, pz) then
        error("[ERROR] Failed to travel to fishing net")
        return false
    end
    
    local beforeSpaces = Inventory:FreeSpaces()
    if not interactObject(loc, 15) then
        error("[ERROR] Failed to interact with fishing net")
        return false
    end

    API.RandomSleep2(math.random(600,1800), 600, math.random(600,1200))

    local afterSpaces = Inventory:FreeSpaces()
    if afterSpaces == beforeSpaces then
        error("[ERROR] No fish were deposited into the fishing net")
        API.Write_LoopyLoop(false)
        return false
    end

    local afterCounts = {}
    for _, f in ipairs(FISH_TYPES) do
        local name, _, _, id = unpack(f)
        afterCounts[name] = id and Inventory:GetItemAmount(id) or 0
    end

    local depositGP = 0
    local depositedFishCount = 0
    for _, f in ipairs(FISH_TYPES) do
        local name, displayName, _, id = unpack(f)
        if id then
            local deposited = beforeCounts[name] - afterCounts[name]
            if deposited > 0 then
                depositedFishCount = depositedFishCount + deposited
                fishCounts[name] = fishCounts[name] + deposited
                local gp = deposited * (prices[id] or 0)
                depositGP = depositGP + gp
                print(("[DEPOSIT] %dx %s -> %s gp")
                      :format(deposited, displayName, format_number(gp)))
            end
        end
    end

    totalFish = totalFish + depositedFishCount

    print(("[DEPOSIT] Total deposit value: %s gp; total fish count: %d")
          :format(format_number(depositGP), totalFish))
    tracking()
    updateInventoryBaseline() 
    return true
end

---------------------------------------------------------------------
-- LEVEL 8: GAME STATE & EVENTS (DEPEND ON LEVEL 1-7) ---------------
---------------------------------------------------------------------

local function checkXpIncrease()
    local newXp = API.GetSkillXP("FISHING")
    if newXp == startXp then
        error("[ERROR] - No XP increase detected")
        API.Write_LoopyLoop(false)
    end
    startXp = newXp
end

local function idleCheck()
    local now = API.ScriptRuntime()
    if randomTime == 0 then
        randomTime = math.random(MIN_IDLE_TIME_MINUTES * 60, MAX_IDLE_TIME_MINUTES * 60)
    end
    if now - afk > randomTime then
        afk = now
        tracking()
        
        if not API.Read_LoopyLoop() then 
            print("[INFO] Script stopping during idle check")
            return 
        end
        
        API.PIdle1()
        checkXpIncrease()
        randomTime = 0
    end
end

local function gameStateChecks()
    local state = API.GetGameState2()
    if state ~= 3 or not API.PlayerLoggedIn() then
        API.logDebug('[HELP] - Not in-game or logged out')
        API.Write_LoopyLoop(false)
    end
end

local function checkDialogue()
    return API.VB_FindPSettinOrder(2874).state == 12
end

local function checkRequiredLevel() 
	local reqLevel = levelRequirements[fishingAction]
	if API.XPLevelTable(API.GetSkillXP("FISHING")) < reqLevel then
    		error(("Need Fishing level %d for %s"):format(reqLevel, fishingAction))
	end
	return API.XPLevelTable(API.GetSkillXP("FISHING")) >= reqLevel
end

local function checkAnim()
    return API.ReadPlayerAnim() == 0
end

function findNPC(objID, objType, distance)
    local allObjects = API.GetAllObjArray1({ objID }, distance or 30, { objType })
    return allObjects[1] or false
end

local function claimSerenSpirit()
    if findNPC(26022, 1, 30) then  
	if API.DoAction_NPC(0x29,API.OFF_ACT_InteractNPC_route,{ 26022 },50) then
	    print("[DEBUG] - Claiming seren spirit")
	    API.RandomSleep2(math.random(600, 1800), 600, 1200)
	    return true
	end
    end
    return false
end

local function claimDivineBlessing()
    if findNPC(27228, 1, 30) then  
	if API.DoAction_NPC(0x29,API.OFF_ACT_InteractNPC_route,{ 27228 },50) then
	    print("[DEBUG] - Claiming divine blessing")
	    API.RandomSleep2(math.random(600, 1800), 600, 1200)
	    return true
	end
    end
    return false
end

local function handleRandomEvent(itemId, startMsg, successMsg)
    if not watchRandoms or not Inventory:Contains(itemId) then
        return true
    end
    API.logInfo("[HELP] - " .. startMsg)
   
    if itemId == 42282 then
        local maxAttempts = 10
        local attempts = 0
        local bottleOpened = false
        
        while attempts < maxAttempts do

            if not API.Read_LoopyLoop() then 
                print("[INFO] Script stopping during random event handling")
                return false 
            end
            
            tracking()
            local vb_state = API.VB_FindPSettinOrder(2874).state
            
            if vb_state == 0 and bottleOpened then
                API.logInfo("[HELP] - " .. successMsg)
                return true
                
            elseif vb_state == 12 then
                API.DoAction_Interface(0xffffffff, 0xffffffff, 0, 1186, 8, -1, API.OFF_ACT_GeneralInterface_Choose_option)
                API.RandomSleep2(600, 600, 600)
                bottleOpened = true
                
            elseif vb_state == 18 then
                API.DoAction_Interface(0xffffffff,0xffffffff,0,751,66,-1,API.OFF_ACT_GeneralInterface_Choose_option)
                API.RandomSleep2(600, 600, 600)
                bottleOpened = true
                
            elseif vb_state == 0 and not bottleOpened then
                API.DoAction_Inventory1(itemId, 0, 1, API.OFF_ACT_GeneralInterface_route)
                API.RandomSleep2(
                    math.random(600, 2 * 600),
                    math.random(100, 400),
                    math.random(100, 600)
                )
            else
                API.RandomSleep2(600, 600, 600)
            end
            
            if not Inventory:Contains(itemId) then
                API.logInfo("[HELP] - " .. successMsg)
                return true
            end
            
            attempts = attempts + 1
        end
        
        API.logInfo("[ERROR] - Unable to process message in a bottle after " .. maxAttempts .. " attempts")
        return false
    end
    
    local safetyCounter = 0
    local maxSafetyAttempts = 20  -- Prevent infinite loops
    
    while API.VB_FindPSettinOrder(2874).state ~= 1572882 and safetyCounter < maxSafetyAttempts do
        if not API.Read_LoopyLoop() then 
            print("[INFO] Script stopping during random event processing")
            return false 
        end
        
        API.DoAction_Inventory1(itemId, 0, 1, API.OFF_ACT_GeneralInterface_route)
        API.RandomSleep2(
            math.random(600, 3 * 600),
            math.random(100, 400),
            math.random(100, 600)
        )
        safetyCounter = safetyCounter + 1
    end
    
    if safetyCounter >= maxSafetyAttempts then
        API.logInfo("[ERROR] - Random event processing timed out after " .. maxSafetyAttempts .. " attempts")
        return false
    end
    
    API.DoAction_Interface(
        0xffffffff, 0xffffffff, 0,
        847, 22, -1,
        API.OFF_ACT_GeneralInterface_Choose_option
    )
    API.RandomSleep2(
        math.random(600, 3 * 600),
        math.random(100, 400),
        math.random(100, 600)
    )
    local finalState = API.VB_FindPSettinOrder(2874).state
    if finalState ~= 1572882 then
        API.logInfo("[HELP] - " .. successMsg)
        return true
    else
        API.logInfo("[ERROR] - Unable to process random event: state still " .. tostring(finalState))
        return false
    end
end

local function augmentedReached()
    local container = API.Container_Get_all(94)
    if not container or not container[4] or not container[4].Extra_ints or not container[4].Extra_ints[2] then
        return false
    end
    
    local itemXp = container[4].Extra_ints[2]
    local itemLevel = GetItemLevel(itemXp)
    
    return itemLevel >= alertItemLevel
end

local function interactingWithElectrified()
    if API.ReadLpInteracting().Name == "Electrifying blue blubber jellyfish" or API.ReadLpInteracting().Name == "Electrifying green blubber jellyfish" then
	print("[DEBUG] - Interacting with an electrified fishing spot")
	return true
    end
    return false
end

local function interactingNonSwiftWithSwiftAvail()
    if API.ReadLpInteracting().Name == "Sailfish" and normalizeFishName(fishingAction) == "sailfish" then
	if #API.GetAllObjArray1({25222}, 50, {1}) > 0 then
	    print("[DEBUG] - Interacting with a regular sailfish spot but a swift sailfish is available")
	    return true
	end
    end
    return false
end

local function processRandomEvents()
    for _, ev in ipairs(RANDOM_EVENTS) do
        if not API.Read_LoopyLoop() then 
            print("[INFO] Script stopping during random event processing")
            return false 
        end
        
        local itemId, startMsg, successMsg = unpack(ev)
        if not handleRandomEvent(itemId, startMsg, successMsg) then
            error("[WARN] Failed to handle random event")
            API.Write_LoopyLoop(false)  
            return false
        end
    end
    return true
end

---------------------------------------------------------------------
-- LEVEL 9: FISHING FUNCTIONS (DEPEND ON LEVEL 1-8) -----------------
---------------------------------------------------------------------

local function tryFishingAction()
    local key
    if fishingAction == "bluejellyfish" then
        key = "bluejellyfish"
    elseif fishingAction == "greenjellyfish" then
        key = "greenjellyfish"
    else
        key = normalizeFishName(fishingAction)
    end

    local ids = npcIds[key]
    if not ids then
        print("[tryFishingAction] no NPC IDs for:", key)
        return
    end

    for _, id in ipairs(ids) do
        local npcs = API.GetAllObjArray1({id}, 50, {1})
        if not npcs or #npcs == 0 then
            print(string.format("[tryFishingAction] no NPCs found for ID %d", id))
        else
            for idx, npc in ipairs(npcs) do
            	local actionName = tostring(npc.Action)

    		if (normalizeFishName(fishingAction) == "frenzyN" or normalizeFishName(fishingAction) == "frenzyS") and actionName ~= "Fling" then
			print(string.format("[SKIP] id = %d @ (x = %.1f, y = %.1f)", npc.Id, npc.Tile_XYZ.x, npc.Tile_XYZ.y))
          		goto continue
    		end
		local playerPos = API.PlayerCoordfloat()
    		local x, y = npc.Tile_XYZ.x, npc.Tile_XYZ.y
    		local dist = math.sqrt((x - playerPos.x)^2 + (y - playerPos.y)^2)
    		if dist <= 50 then
        		return API.DoAction_NPC(0x3c, API.OFF_ACT_InteractNPC_route, { npc.Id }, 50)
    		end
		::continue::
            end
        end
    end
end

local function ensureBackToFishing()
    local dest = normalizeFishName(fishingAction)
    local pos  = API.PlayerCoord()
    local px, py, pz = pos.x, pos.y, pos.z 	
    
    print(string.format("[DEBUG] ensureBackToFishing: Player at (%.1f, %.1f, %d), checking region '%s'", px, py, pz, dest))
    
    if not inside(px, py, regions[dest], pz) then
    	print("[WARN] Not in fishing area, attempting to return")
    	local targetRegion = regions[dest]
    	if targetRegion then
    	    print(string.format("[DEBUG] Target region: X(%.1f-%.1f) Y(%.1f-%.1f) Z(%d-%d)", 
    	        targetRegion.p1.x, targetRegion.p2.x, 
    	        targetRegion.p1.y, targetRegion.p2.y,
    	        targetRegion.p1.z or 0, targetRegion.p2.z or 3))
    	end
    	
    	doMovement()  -- Uses the fixed doMovement with loop safety

    	pos = API.PlayerCoord()
    	px, py, pz = pos.x, pos.y, pos.z  
    	print(string.format("[DEBUG] After movement: Player at (%.1f, %.1f, %d)", px, py, pz))
    	
    	if not inside(px, py, regions[dest], pz) then
            print("[ERROR] Still outside fishing area after movement")
            print(string.format("[ERROR] Player position: (%.1f, %.1f, %d)", px, py, pz))
            print(string.format("[ERROR] Expected region '%s'", dest))
            return false  -- Return false instead of stopping script
        end
    end

    return true
end

local function doAndAwaitAnim(interactFn, description, timeoutSec)
    print(("[DEBUG] - %s"):format(description))

    if not interactFn() then
        print(("[ERROR] - %s interaction failed"):format(description))
        return false
    end

    if (normalizeFishName(fishingAction) == "frenzyS" or normalizeFishName(fishingAction) == "frenzyN") and 
       description == "Trying fishing action" then
        waitingForFrenzyCompletion = true
        print("[DEBUG] - Set waiting for frenzy completion")
    end

    local accumulated = 0
    local lastTime    = API.ScriptRuntime()

    repeat
        -- CRITICAL: Check if script should stop
        if not API.Read_LoopyLoop() then 
            print("[INFO] Script stopping during animation wait")
            return false 
        end
        
        API.RandomSleep2(100,100,100)
        tracking()

        local now = API.ScriptRuntime()
        local dt  = now - lastTime

        if not API.ReadPlayerMovin2() then
            accumulated = accumulated + dt
        end

        lastTime = now

        if accumulated > timeoutSec then
            print(("[ERROR] - %s: no animation within %d seconds of non-moving time, giving up")
                  :format(description, timeoutSec))
            return false  -- Return false instead of error()
        end
    until API.ReadPlayerAnim() ~= 0

    print(("[DEBUG] - Animation for %s started after %.2f seconds of non-moving wait.")
          :format(description, accumulated))
    return true
end

---------------------------------------------------------------------
-- MAIN LOOP --------------------------------------------------------
---------------------------------------------------------------------
if not isInDeepSeaHub() then
    error("[ERROR] Please move to the Deep Sea Fishing area and restart the script.")
    API.Write_LoopyLoop(false)
end

if not checkRequiredLevel() then
    API.Write_LoopyLoop(false)
end

if useGOTE and not usePorters then
    error("ERROR: useGOTE requires usePorters to be true. GOTE needs porters to charge itself.\n" ..
          "Either set usePorters = true, or set useGOTE = false.")
end

clearAllFishData()
resetScriptVariables()

while API.Read_LoopyLoop() do
    gameStateChecks()

    local actionClean = normalizeFishName(fishingAction)
    local destination = normalizeFishName(fishingAction)
    local player = API.PlayerCoord()
    local px, py, pz = player.x, player.y, player.z
	
    if actionClean ~= "frenzyS"
    and actionClean ~= "frenzyN"
    and actionClean ~= "minnows" then
        
    if usePorters then
    if useGOTE then
        local chargingThreshold = getGOTEChargingThreshold()
        local needsCharging = checkPorter(chargingThreshold)
        
        if needsCharging then
            if hasEnoughPortersForGOTE() then
                if not chargeGOTE() then
    		    print("[ERROR] Failed to charge grace of the elves - going to bank for more porters")
    		    if not depositAtBank() then
    		        print("[ERROR] Failed to deposit at bank for porter restocking")
    		        goto continue
    		    end
    		    if not ensureBackToFishing() then
    		        print("[ERROR] Failed to return to fishing area")
    		        goto continue
    		    end
    		    goto continue
		end
            else
                if canBankForPorters() then
                    print("[INFO] GOTE needs charging but insufficient porters - going to bank")
                    if not depositAtBank() then
                        print("[ERROR] Failed to restock porters for GOTE")
                        goto continue
                    end
                    if not ensureBackToFishing() then
                        print("[ERROR] Failed to return to fishing area after restocking")
                        goto continue
                    end
                    goto continue
                else
                    local bankingRegion = getBankingRegion(fishingAction, usePorters)
                    print("[ERROR] GOTE needs charging but insufficient porters available")
                    print("[ERROR] Current fishing location uses net banking, cannot restock porters")
                    print("[ERROR] Please manually move to a location with porter banking or disable GOTE")
                    print("[ERROR] Insufficient porters for GOTE and cannot restock automatically")
                    goto continue  -- Continue instead of error
                end
            end
        end
    else
        local needsPorter = checkPorter(0)
        
        if needsPorter then  
            local porterId, porterChargeValue = hasPorter()
            
            if porterId > 0 then
                API.DoAction_Inventory1(porterId, 0, 2, API.OFF_ACT_GeneralInterface_route)
                API.RandomSleep2(math.random(600,1800), 600, 330)
            else
                if not depositAtBank() then
                    print("[ERROR] Failed to deposit at bank")
                    goto continue
                end
                if not ensureBackToFishing() then
                    print("[ERROR] Failed to return to fishing area")
                    goto continue
                end
                goto continue
            end
        end
    end
    elseif not usePorters and Inventory:FreeSpaces() == 0 then
	if not depositAtNet() then
	    print("[ERROR] Failed to deposit at fishing net")
	    goto continue
	end
	if not ensureBackToFishing() then
	    print("[ERROR] Failed to return to fishing area")
	    goto continue
	end
	goto continue
    end
    end 

    if whichAura and whichAura ~= "" and AURAS.auraTimeRemaining() <= AURAS.auraRefreshTime then
        AURAS.activateAura(whichAura)
        API.RandomSleep2(math.random(600, 1200), 1200, math.random(300, 600))
        API.DoAction_Interface(0xc2, 0xffffffff, 1, 1431, 0, 9, API.OFF_ACT_GeneralInterface_route)
    end

    idleCheck()
    findChatText()

    if not inside(px, py, regions[destination], pz) then
      	doMovement()
    end

    if checkDialogue() and normalizeFishName(fishingAction) == "swarm" then
        if doAndAwaitAnim(
             function()
                 return API.DoAction_NPC(0x3c, API.OFF_ACT_InteractNPC_route, {25220}, 50)
             end,
             "Snagging net @ swarm spot",
             20
           )
        then
            recordFishTime()
        end

    elseif (checkAnim() and not checkDialogue())
    or interactingWithElectrified()
    or interactingNonSwiftWithSwiftAvail()
    then
    	if doAndAwaitAnim(tryFishingAction, "Trying fishing action", 20) then
        	recordFishTime()
    	end
    end

    ::continue::
    processRandomEvents()
    claimSerenSpirit()
    claimDivineBlessing()

    tracking()
    
    API.RandomSleep2(math.random(300, 500), 100, math.random(600, 2400))
end