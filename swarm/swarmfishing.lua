local API = require("api")
--local AURAS = require("swarm.AURAS")
local version = "1.1"

-- ═════════════════════════════════════════════════════
--                    SCRIPT CONFIGURATION                    
-- ═════════════════════════════════════════════════════

local fishingAction = "frenzyS"   		-- Available options: "sailfish", "minnows", "frenzyS", "frenzyN", "swarm", "bluejellyfish", "greenjellyfish"               

local whichAura = ""  				-- Aura to maintain (leave "" to disable or enter the exact aura and uncomment AURAS above)

local bankPin = 0000

local usePorters = true                         -- Use inventory porters for banking
local useGOTE = false                           -- Use Grace of the Elves (requires usePorters = true)

local watchRandoms = true                       -- Auto-handle fishing notes, bottles, etc.
local MIN_IDLE_TIME_MINUTES = 5                 -- Minimum minutes before anti-idle action
local MAX_IDLE_TIME_MINUTES = 15                -- Maximum minutes before anti-idle action

local alertItemLevel = 10                       -- Alert when augmented item reaches this level

-- ═════════════════════════════════════════════════════
--                      CORE DATA STRUCTURES                     
-- ═════════════════════════════════════════════════════

local FISH_TYPES = {
    {"rocktail","Rocktails","rocktail",15270}, {"cavefish","Cavefish","cavefish",15264},
    {"bluejelly","Blue Blubbers","blue blubber jellyfish",42265}, {"sailfish","Sailfish","sailfish",42249},
    {"mantaray","Manta rays","manta ray",389}, {"seaturtle","Sea turtles","sea turtle",395},
    {"greatwhiteshark","Great white sharks","great white shark",34727}, {"baronshark","Baron sharks","baron shark"},
    {"greenblubber","Green Blubbers","green blubber jellyfish",42256}, {"minnow","Minnows","magnetic minnow"},
    {"monkfish","Monkfish","monkfish",7944}, {"swordfish","Swordfish","swordfish",371},
    {"bass","Bass","bass",363}, {"tuna","Tuna","tuna",359}, {"cod","Cod","cod",341},
    {"mackerel","Mackerel","mackerel",353}, {"trout","Trout","trout",335},
    {"herring","Herring","herring",345}, {"shrimp","Shrimp","shrimp",317}
}

local porterCharges = {
    [29276]=5,[29275]=5, [29278]=10,[29277]=10, [29280]=15,[29279]=15,
    [29282]=20,[29281]=20, [29284]=25,[29283]=25, [29286]=30,[29285]=30,
    [51491]=50,[51490]=50
}

local RANDOM_EVENTS = {
    {42286,"Fishing notes detected"," + Gained extra xp from consuming fishing notes"},
    {42285,"Tangled fishbowl detected"," + 5% xp boost activated for 3 minutes"},
    {42284,"Broken fishing rod detected"," + 10% catch rate boost activated for 3 minutes"},
    {42283,"Barrel of bait detected"," + 10% additional catch boost for 3 minutes"},
    {42282,"Message in a bottle detected"," + Message in a bottle consumed"}
}

local AREAS = {
    sailfish={2135,7124,2149,7136}, minnows={2127,7085,2141,7101},
    frenzyS={2062,7108,2073,7112}, frenzyN={2064,7121,2074,7131},
    swarm={2090,7075,2103,7079}, jellyfish={2083,7109,2114,7145},
    bluejellyfish={2083,7109,2114,7145}, greenjellyfish={2083,7109,2114,7145},
    minJunc={2116,7113,2122,7118}, midJunc={2097,7108,2103,7113}, southJunc={2102,7100,2106,7105},
    bankPorterEnter={2132,7103,2135,7110}, bankPorterJelly={2096,7111,2103,7116},
    netJelly={2096,7089,2102,7094}, netEnter={2114,7121,2122,7125}
}

local npcIds = {
    sailfish={25222,25221}, minnows={25219}, swarm={25220},
    jellyfish={25224,25223}, bluejellyfish={25224}, greenjellyfish={25223},
    frenzyS={25204,25202,25195,25194,25201,25203,25196,25197,25197,25198,25205,25199,25208,25207,25200,25209,25206},
    frenzyN={25204,25202,25195,25194,25201,25203,25196,25197,25197,25198,25205,25199,25208,25207,25200,25209,25206}
}

local edges = {
    sailfish={"netEnter","minJunc","bankPorterEnter"}, minnows={"bankPorterEnter"},
    frenzyS={"midJunc"}, frenzyN={"midJunc"}, jellyfish={"midJunc"}, swarm={"netJelly"},
    minJunc={"sailfish","minnows","midJunc","bankPorterEnter","netEnter"},
    midJunc={"jellyfish","southJunc","frenzyN","frenzyS","minJunc","bankPorterJelly","netJelly"},
    southJunc={"midJunc","swarm"},
    bankPorterEnter={"minJunc","minnows","sailfish"}, bankPorterJelly={"midJunc"},
    netJelly={"swarm","midJunc"}, netEnter={"minJunc","sailfish"}
}

local BANKING_REGIONS = {
    sailfish={porter="bankPorterEnter",net="netEnter"}, minnows={porter="bankPorterEnter",net="netEnter"},
    swarm={porter="bankPorterJelly",net="netJelly"}, jellyfish={porter="bankPorterJelly",net="netJelly"},
    frenzyS={porter="bankPorterJelly",net="netJelly"}, frenzyN={porter="bankPorterJelly",net="netJelly"}
}

local DEPOSIT_CONFIGS = {
    bankPorterEnter={id=110591,action={porter=0x33,net=0x3c},route={porter=API.OFF_ACT_GeneralObject_route2,net=API.OFF_ACT_GeneralObject_route3}},
    bankPorterJelly={id=110860,action={porter=0x33,net=0x3c},route={porter=API.OFF_ACT_GeneralObject_route3,net=API.GeneralObject_route_useon}},
    netJelly={id=110857,action={net=0x29},route={net=API.OFF_ACT_GeneralObject_route2}},
    netEnter={id=110857,action={net=0x29},route={net=API.OFF_ACT_GeneralObject_route2}}
}

local xpTable = {0,1160,2607,5176,8286,11760,15835,21152,28761,40120, 57095,81960,117397,166496,232755,320080,432785,575592,753631,972440}
local ALL_PORTERS = {29276,29278,29280,29282,29284,29286,51491,29275,29277,29279,29281,29283,29285,51490}
local ACTIVITY_TYPES = {frenzyS="frenzy", frenzyN="frenzy", minnows="minnows", default="regular"}
local validActions = {sailfish=true, minnows=true, frenzyS=true, frenzyN=true, swarm=true, bluejellyfish=true, greenjellyfish=true}
local levelRequirements = {sailfish=97, minnows=68, frenzyS=94, frenzyN=94, swarm=68, bluejellyfish=91, greenjellyfish=68}

-- ═════════════════════════════════════════════════════
--                   VARIABLES                     
-- ═════════════════════════════════════════════════════

local prices = {}
for _, f in ipairs(FISH_TYPES) do
    local id = f[4]
    if id then prices[id] = API.GetExchangePrice(id) or 0 end
end

local regions, nodes = {}, {}
for name, coords in pairs(AREAS) do
    local x1, y1, x2, y2 = coords[1], coords[2], coords[3], coords[4]
    regions[name] = {p1=WPOINT.new(x1,y1,0), p2=WPOINT.new(x2,y2,3)}
    nodes[name] = {xMin=x1, xMax=x2, yMin=y1, yMax=y2}
end

startingInventory = {}
afk = API.ScriptRuntime()
randomTime = 0
lastIdleXp = API.GetSkillXP("FISHING")
lastFishTime = API.ScriptRuntime()
local fishCounts, prevFishCounts = {}, {}
local totalFish, lastChatCount = 0, 0
local lastFishCaught = API.ScriptRuntime()
local lastKnownFishCount = 0
local frenzyInteractions = 0
local waitingForFrenzyCompletion = false
local lastKnownMinnowCount = 0
local minnowInteractions = 0
local unpack = unpack or table.unpack

for _, f in ipairs(FISH_TYPES) do
    fishCounts[f[1]] = 0
    prevFishCounts[f[1]] = 0
end

local currentGOTEThreshold = 0
local lastPorterInventoryState = ""
local portersUsed = 0
local lastPorterBuffAmount = 0
local buffTrackingInitialized = false

local startXp = API.GetSkillXP("FISHING")
local lastDisplayedValues = {
    totalFish = 0, xpGained = 0, gpEarned = 0, porterCharges = 0,
    porterCount = 0, totalCharges = 0, portersUsed = 0, inventorySpaces = 0,
    playerAnim = 0, playerMoving = false, currentRegion = "", playerX = 0, playerY = 0,
    inventoryHash = "", timeSinceActionSeconds = 0, timeSinceFishSeconds = 0,
    auraTimeMinutes = 0, runtimeMinutes = 0
}
local configurationDisplayed = false
local lastConfigState = ""

local pathQueue, visitedNodes, validEdges = {}, {}, {}

local normalizedAction = nil  
local isFrenzyAction = false  
local actionClean = nil       

API.SetDrawLogs(true)
API.SetDrawTrackedSkills(true)

-- ═════════════════════════════════════════════════════
--                     UTILITY FUNCTIONS                      
-- ═════════════════════════════════════════════════════

local function normalizeFishName(name)
    return (name == "bluejellyfish" or name == "greenjellyfish") and "jellyfish" or name
end

local function activityUsesPorters()
    local actionClean = normalizeFishName(fishingAction)
    return actionClean ~= "frenzyS" and actionClean ~= "frenzyN" and actionClean ~= "minnows"
end

local function randomPointInRegion(r)
    local x1, x2 = math.min(r.p1.x, r.p2.x), math.max(r.p1.x, r.p2.x)
    local y1, y2 = math.min(r.p1.y, r.p2.y), math.max(r.p1.y, r.p2.y)
    return {
        x = math.floor(x1 + math.random() * (x2 - x1) + 0.5),
        y = math.floor(y1 + math.random() * (y2 - y1) + 0.5),
        z = 0
    }
end

local function dist2(a, b)
    return math.sqrt((a.x - b.x)^2 + (a.y - b.y)^2)
end

local function inside(x, y, box, z)
    z = z or 0
    local x1, x2 = math.min(box.p1.x, box.p2.x), math.max(box.p1.x, box.p2.x)
    local y1, y2 = math.min(box.p1.y, box.p2.y), math.max(box.p1.y, box.p2.y)
    local z1, z2 = math.min(box.p1.z or 0, box.p2.z or 3), math.max(box.p1.z or 0, box.p2.z or 3)
    return x >= x1 and x <= x2 and y >= y1 and y <= y2 and z >= z1 and z <= z2
end

local function insideRegion(x, y, regs, regionName, z)
    local r = regs[regionName]
    return r and inside(x, y, r, z) or false
end

local function format_number(n)
    n = tonumber(n)
    if not n then return "0" end
    local s = tostring(math.floor(n))
    local pos = #s % 3
    if pos == 0 then pos = 3 end
    return s:sub(1, pos) .. s:sub(pos + 1):gsub("(%d%d%d)", ",%1")
end

local function GetItemLevel(xp)
    if not xp or type(xp) ~= "number" then return 0 end
    for i = #xpTable, 1, -1 do
        if xp >= xpTable[i] then return i end
    end
    return 0
end

local function recordFishTime()
    lastFishTime = API.ScriptRuntime()
end

local function timeSinceLastFish()
    return API.ScriptRuntime() - lastFishTime
end

local function findPlayerRegion(px, py, pz)
    for rn, rb in pairs(regions) do
        if inside(px, py, rb, pz) then return normalizeFishName(rn) end
    end
end

local function nearestNode(px, py, nodes)
    local best, bd
    for n, N in pairs(nodes) do
        local nx, ny = N.x or (N.xMin + N.xMax) / 2, N.y or (N.yMin + N.yMax) / 2
        local d = (px - nx)^2 + (py - ny)^2
        if not bd or d < bd then best, bd = n, d end
    end
    if not best then
        handleCriticalError("Unable to find nearest node", string.format("No valid nodes found for position (%.1f, %.1f)", px, py))
    end
    return best
end

-- ═════════════════════════════════════════════════════
--                     INTERFACE FUNCTIONS                     
-- ═════════════════════════════════════════════════════

local function getNecklaceID()
    local container = API.Container_Get_all(94)
    return (container and container[3] and container[3].item_id and container[3].item_id > 0) and container[3].item_id or 0
end

local function getNecklaceCharges()
    local container = API.Container_Get_all(94)
    return container and container[3] and container[3].Extra_ints and container[3].Extra_ints[2] or 0
end

local function getPorterAmount()
    local buff = API.Buffbar_GetIDstatus(51490, false)
    return buff and buff.found and tonumber(buff.text) or 0
end

local function getRequiredAmount()
    return API.GetVarbitValue(52157) == 1 and 2000 or 500
end

local function checkDialogue()
    return API.VB_FindPSettinOrder(2874).state == 12
end

local function checkAnim()
    return API.ReadPlayerAnim() == 0
end

local function findNPC(objID, objType, distance)
    return API.GetAllObjArray1({objID}, distance or 30, {objType})[1] or false
end

local function isEquipmentOpen()
    return API.VB_FindPSettinOrder(3074).state == 1
end

local function openEquipment()
    for i = 1, 3 do
	if isEquipmentOpen() then
		print(string.format("[DEBUG] Equipment tab opened on try %d", i))
		return true
	end
	print(string.format("[DEBUG] Opening Equipment tab (try %d)", i))
        API.DoAction_Interface(0xc2, 0xffffffff, 1, 1431, 0, 10, API.OFF_ACT_GeneralInterface_route)
        API.RandomSleep2(math.random(600,1800), 400, 200)
    end
    error("[ERROR] Unable to open Equipment tab")
    return false
end

local function isBackpackOpen()
    return API.VB_FindPSettinOrder(3039).state == 1
end

local function openBackpack()
    for i = 1, 3 do
	if isBackpackOpen() then
		print(string.format("[DEBUG] Backpack tab opened on try %d", i))
		return true
	end
	print(string.format("[DEBUG] Opening Backpack tab (try %d)", i))
	API.DoAction_Interface(0xc2,0xffffffff,1,1431,0,9,API.OFF_ACT_GeneralInterface_route)
        API.RandomSleep2(math.random(600,1800), 400, 200)
    end
    error("[ERROR] Unable to open Backpack tab")
    return false
end

function maybeEnterPin()
    if API.VB_FindPSettinOrder(2874).state == 18 then
        print("[PIN] PIN window detected -> entering PIN")
        API.DoBankPin(bankPin)
        API.RandomSleep2(math.random(1200,2400),200,200)
        local s = API.VB_FindPSettinOrder(2874).state
        if s == 12 or s == 18 then
            error("[PIN] - PIN window still present after one try / wrong pin")
            return false
        end
        print("[PIN] PIN entered successfully")
        return true
    else
        print("[PIN] - No bank pin window detected")
        return true
    end
end

-- ═════════════════════════════════════════════════════
--               ERROR HANDLING / VALIDATION FUNCTIONS                   
-- ═════════════════════════════════════════════════════

local function handleCriticalError(errorMessage, context)
    print("===========================================")
    print("           CRITICAL ERROR OCCURRED        ")
    print("===========================================")
    print(string.format("[FATAL] %s", errorMessage))
    if context then print(string.format("[CONTEXT] %s", context)) end
    print(string.format("[TIME] %s", os.date("%Y-%m-%d %H:%M:%S")))
    print(string.format("[RUNTIME] %s", API.ScriptRuntimeString()))
    print(string.format("[ACTIVITY] %s", fishingAction))
    local player = API.PlayerCoord()
    local regionName = findPlayerRegion(player.x, player.y, player.z)
    print(string.format("[LOCATION] Player at: (%.1f, %.1f, %d) [%s]", player.x, player.y, player.z, regionName or "Unknown"))
    print("[ACTION] Script will now terminate")
    print("===========================================")
    API.Write_LoopyLoop(false)
    error(string.format("[FATAL] %s", errorMessage))
end

local function isInDeepSeaHub()
    local region = API.PlayerRegion()
    local x, y, z = region.x, region.y, region.z
    local validRegions = {{32, 111, 8303}, {32, 110, 8302}, {33, 111, 8559}, {33, 110, 8558}}
    for _, validRegion in ipairs(validRegions) do
        if x == validRegion[1] and y == validRegion[2] and z == validRegion[3] then
            print(string.format("[INFO] Player in Deep Sea Fishing hub at (%d, %d, %d)", x, y, z))
            return true
        end
    end
    print(string.format("[INFO] Player NOT in Deep Sea Fishing hub. Current: (%d, %d, %d)", x, y, z))
    return false
end

local function checkRequiredLevel() 
    if API.XPLevelTable(API.GetSkillXP("FISHING")) < levelRequirements[fishingAction] then
        error(string.format("Need Fishing level %d for %s (current: %d)", levelRequirements[fishingAction], fishingAction, API.XPLevelTable(API.GetSkillXP("FISHING"))))
    end
    return true
end

-- ═════════════════════════════════════════════════════
--                     PORTER FUNCTIONS                     
-- ═════════════════════════════════════════════════════

local function hasPorter()
    for _, id in ipairs(ALL_PORTERS) do  
        if Inventory:Contains(id) then
            return id, porterCharges[id] or 0
        end
    end
    return 0, 0
end

local function howManyPorters()
    local count, charges = 0, 0
    for _, id in ipairs(ALL_PORTERS) do  
        if Inventory:Contains(id) then
            local amount = Inventory:GetItemAmount(id) or 0
            count = count + amount
            charges = charges + (amount * (porterCharges[id] or 0))
        end
    end
    return count, charges
end

local function checkPorter(threshold)
    local buff = API.Buffbar_GetIDstatus(51490, false)
    if not (buff and buff.found) then return true end 
    local necklaceCharges = getNecklaceCharges() or 0
    local buffCharges = tonumber(buff.text) or 0
    local currentCharges = math.max(necklaceCharges, buffCharges)
    return currentCharges <= threshold
end

local function getGOTEChargingThreshold()
    local porterId, porterChargeValue = hasPorter()
    local state = porterId .. "_" .. porterChargeValue
    if state ~= lastPorterInventoryState then
        lastPorterInventoryState = state
        currentGOTEThreshold = porterId > 0 and math.random(1, math.max(1, 500 - porterChargeValue)) or math.random(1, 450)
        print("[DEBUG] New GOTE threshold: " .. currentGOTEThreshold)
    end
    return currentGOTEThreshold
end

local function hasEnoughPortersForGOTE()
    if not useGOTE then return true end
    local required, current
    required = getRequiredAmount()
    current = getPorterAmount()
    local needed = required - current
    if needed <= 0 then return true end
    local _, available = howManyPorters()
    print(string.format("[DEBUG] GOTE needs %d more charges, have %d available", needed, available))
    return available >= needed
end

local function trackPorterBuffUsage()
    if not usePorters or not activityUsesPorters() then
        return
    end
    local currentBuffAmount = getPorterAmount()
    if not buffTrackingInitialized or currentBuffAmount > lastPorterBuffAmount then
        lastPorterBuffAmount = currentBuffAmount
        buffTrackingInitialized = true
        if currentBuffAmount > 0 then
            print(string.format("[DEBUG] Porter buff tracking initialized: %d", currentBuffAmount))
        end
        return
    end
    if currentBuffAmount < lastPorterBuffAmount then
        local chargesConsumed = lastPorterBuffAmount - currentBuffAmount
        portersUsed = portersUsed + chargesConsumed
        lastPorterBuffAmount = currentBuffAmount
    end
end

-- ═════════════════════════════════════════════════════
--                     AURA MANAGEMENT                     
-- ═════════════════════════════════════════════════════

local function handleAuraManagement()
    if not whichAura or whichAura == "" or not AURAS then return true end
    AURAS.pin(bankPin)
    local auraTimeRemaining = AURAS.auraTimeRemaining()
    local refreshThreshold = AURAS.auraRefreshTime or 0
    if auraTimeRemaining > refreshThreshold then return true end
    print(string.format("[INFO] Refreshing aura '%s' (%.1f min remaining)", whichAura, auraTimeRemaining / 60))
    if not AURAS.activateAura(whichAura) then
        handleCriticalError("Failed to activate selected aura", string.format("AURAS.activateAura('%s') returned false - aura activation failed", whichAura))
    end
    print(string.format("[DEBUG] Activated aura: '%s'", whichAura))
    API.RandomSleep2(math.random(700, 1200), 1200, math.random(300, 600))
    return API.DoAction_Interface(0xc2, 0xffffffff, 1, 1431, 0, 9, API.OFF_ACT_GeneralInterface_route)
end

-- ═════════════════════════════════════════════════════
--                 FISH TRACKING FUNCTIONS                 
-- ═════════════════════════════════════════════════════

local function getActivityType(action)
    return ACTIVITY_TYPES[normalizeFishName(action)] or ACTIVITY_TYPES.default
end

local function calcTotalFish()
    local sum = 0
    for _, f in ipairs(FISH_TYPES) do
        sum = sum + (fishCounts[f[1]] or 0)
    end
    return sum
end

local function countCurrentSessionFish()
    local sessionCounts = {}
    for _, f in ipairs(FISH_TYPES) do
        local name, _, _, id = unpack(f)
        if id then
            local currentAmount = Inventory:GetItemAmount(id) or 0
            local startingAmount = startingInventory[name] or 0
            local sessionFish = math.max(0, currentAmount - startingAmount)
            if sessionFish > 0 then
                sessionCounts[name] = sessionFish
            end
        end
    end
    return sessionCounts
end

local function updateFrenzyTracking()
    if waitingForFrenzyCompletion and API.ReadPlayerAnim() == 0 then
        waitingForFrenzyCompletion = false
        frenzyInteractions = frenzyInteractions + 1
        lastFishCaught = API.ScriptRuntime()
        print(string.format("[DEBUG] Frenzy interaction #%d completed", frenzyInteractions))
        return true
    end
    return false
end

local function updateMinnowTracking()
    local currentMinnowCount = Inventory:GetItemAmount(42241) or 0
    if currentMinnowCount > lastKnownMinnowCount then
        local increase = currentMinnowCount - lastKnownMinnowCount
        minnowInteractions = minnowInteractions + increase
        lastKnownMinnowCount = currentMinnowCount
        lastFishCaught = API.ScriptRuntime()
        print(string.format("[DEBUG] Minnows increased by %d, total: %d", increase, minnowInteractions))
        return true
    end
    lastKnownMinnowCount = currentMinnowCount
    return false
end

local function updateRegularFishTracking()
    local currentInventory = countCurrentSessionFish()
    local currentTotal = 0
    for _, count in pairs(currentInventory) do
        currentTotal = currentTotal + count
    end
    if currentTotal > lastKnownFishCount then
        lastFishCaught = API.ScriptRuntime()
        lastKnownFishCount = currentTotal
        return true
    end
    lastKnownFishCount = currentTotal
    return false
end

local function detectNewFish()
    local activityType = getActivityType(fishingAction)
    if activityType == "frenzy" then
        return updateFrenzyTracking()
    elseif activityType == "minnows" then
        return updateMinnowTracking()
    else
        return updateRegularFishTracking()
    end
end

local function findChatText()
    local chats = API.GatherEvents_chat_check()
    for i = lastChatCount + 1, #chats do
        local txt = chats[i].text
        if txt then
            local lower = string.lower(txt)
            local cnt, fishName = string.match(lower, "^you transport to your bank:%s*(%d+)%s*x%s*raw%s*([^.]+)")
            cnt = tonumber(cnt)
            if cnt and fishName then
                for _, f in ipairs(FISH_TYPES) do
                    if fishName == f[3] then
                        fishCounts[f[1]] = (fishCounts[f[1]] or 0) + cnt
                        break
                    end
                end
            end
        end
    end
    lastChatCount = #chats
    totalFish = calcTotalFish()
end

local function timeSinceLastFishCaught()
    return API.ScriptRuntime() - lastFishCaught
end

local function updateInventoryBaseline()
    for _, f in ipairs(FISH_TYPES) do
        local name, _, _, id = unpack(f)
        startingInventory[name] = id and Inventory:GetItemAmount(id) or 0
    end
    lastKnownFishCount = 0
    if getActivityType(fishingAction) == "minnows" then
        lastKnownMinnowCount = Inventory:GetItemAmount(42241) or 0
        print("[DEBUG] Minnow baseline updated to: " .. lastKnownMinnowCount)
    end
    print("[DEBUG] New baseline set, lastKnownFishCount reset to 0")
end

-- ═════════════════════════════════════════════════════
--                   STATISTICS FUNCTIONS                   
-- ═════════════════════════════════════════════════════

local function getStatsData()
    local profit_total = 0
    local fishData = {}
    for _, f in ipairs(FISH_TYPES) do
        local cnt = fishCounts[f[1]] or 0
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
    local currentXp = API.GetSkillXP("FISHING")
    local xpGained = currentXp - startXp
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

local function collectCurrentMetrics()
    local stats = getStatsData()
    local currentCharges, porterCount, totalCharges = 0, 0, 0
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
    local totalSessionFish, fishLabel, showGP
    local activityType = getActivityType(fishingAction)
    if activityType == "frenzy" then
        totalSessionFish = frenzyInteractions + totalFish
        fishLabel = "Interactions:"
        showGP = false
    elseif activityType == "minnows" then
        totalSessionFish = minnowInteractions + totalFish
        fishLabel = "Minnows:"
        showGP = false
    else
        totalSessionFish = sessionFishTotal + totalFish
        fishLabel = "Fish:"
        showGP = true
    end
    local player = API.PlayerCoord()
    local px, py, pz = player.x, player.y, player.z
    local currentRegion = findPlayerRegion(px, py, pz) or "Unknown"
    local inventorySpaces = activityUsesPorters() and Inventory:FreeSpaces() or 0
    local timeSinceActionSeconds = math.floor(timeSinceLastFish())
    local runtimeMinutes = math.floor(API.ScriptRuntime() / 60)
    local auraTimeMinutes = 0
    if whichAura and whichAura ~= "" and AURAS then
        local auraTime = AURAS.auraTimeRemaining()
        auraTimeMinutes = auraTime > 0 and math.floor(auraTime / 60) or 0
    end
    local inventoryItems = {}
    for name, count in pairs(sessionInventory) do
        table.insert(inventoryItems, name .. ":" .. count)
    end
    table.sort(inventoryItems)
    local inventoryHash = table.concat(inventoryItems, "|")
    return {
        stats = stats,
        totalSessionFish = totalSessionFish,
        fishLabel = fishLabel,
        showGP = showGP,
        totalGpEarned = totalGpEarned,
        currentCharges = currentCharges,
        porterCount = porterCount,
        totalCharges = totalCharges,
        sessionInventory = sessionInventory,
        inventorySpaces = inventorySpaces,
        currentRegion = currentRegion,
        playerPos = {x = px, y = py, z = pz},
        timeSinceActionSeconds = timeSinceActionSeconds,
        auraTimeMinutes = auraTimeMinutes,
        runtimeMinutes = runtimeMinutes,
        inventoryHash = inventoryHash
    }
end

local function buildMetricsTable(metrics)
    local runtimeSeconds = API.ScriptRuntime()
    local fishPerHour = runtimeSeconds > 0 and math.floor(metrics.totalSessionFish * 3600 / runtimeSeconds) or 0
    local profitPerHr = runtimeSeconds > 0 and math.floor(metrics.totalGpEarned * 3600 / runtimeSeconds) or 0
    local metricsTable = {
        { "Deep Sea Fishing", fishingAction .. " (Required Level: " .. levelRequirements[fishingAction] .. ")" },
        { "", "" },
        { "Runtime:", API.ScriptRuntimeString() },
        { metrics.fishLabel, string.format("%d (%d/h)", metrics.totalSessionFish, fishPerHour) },
        { "XP:", string.format("%s (%s/h)", format_number(metrics.stats.xpGained), format_number(metrics.stats.xpPerHr)) },
    }
    if metrics.showGP then
        table.insert(metricsTable, { "GP:", string.format("%s (%s/h)", format_number(metrics.totalGpEarned), format_number(profitPerHr)) })
    end
    table.insert(metricsTable, { "", "" })
    table.insert(metricsTable, { "Player State:", string.format("Animation: %s", API.ReadPlayerAnim()) })
    table.insert(metricsTable, { "", string.format("Is Moving: %s", tostring(API.ReadPlayerMovin2())) })
    table.insert(metricsTable, { "", "" })
    if activityUsesPorters() then
        table.insert(metricsTable, { "Inventory:", string.format("%d/28 free spaces", Inventory:FreeSpaces()) })
    end
    table.insert(metricsTable, { "Region:", metrics.currentRegion })
    local interacting = API.ReadLpInteracting()
    if interacting and interacting.Name and interacting.Name ~= "" then
        table.insert(metricsTable, { "Interacting With:", interacting.Name })
    end
    if metrics.timeSinceActionSeconds > 0 then
        table.insert(metricsTable, { "Last Action:", string.format("%.0fs ago", metrics.timeSinceActionSeconds) })
    end
    if usePorters and activityUsesPorters() then
        table.insert(metricsTable, { "", "" })
        if useGOTE then
            local requiredAmount = getRequiredAmount()
            local chargePercent = math.floor((metrics.currentCharges / requiredAmount) * 100)
            table.insert(metricsTable, { "GOTE:", string.format("%d%% (%d/%d)", chargePercent, metrics.currentCharges, requiredAmount) })
        else
            if metrics.currentCharges > 0 then
                table.insert(metricsTable, { "Porter:", string.format("%d active", metrics.currentCharges) })
            end
        end
        table.insert(metricsTable, { "Inventory:", string.format("%d porters (%d charges)", metrics.porterCount, metrics.totalCharges) })
        table.insert(metricsTable, { "Used:", string.format("%d charges", portersUsed) })
    end
    local hasSessionFish = false
    if activityUsesPorters() then  
        for name, count in pairs(metrics.sessionInventory) do
            if not hasSessionFish then
                table.insert(metricsTable, { "", "" })
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
            table.insert(metricsTable, { 
                displayName .. ":", 
                string.format("%d (%s gp)", count, format_number(fishValue))
            })
        end
    end
    if whichAura and whichAura ~= "" and metrics.auraTimeMinutes > 0 then
        table.insert(metricsTable, { "", "" })
        table.insert(metricsTable, { "Aura Remaining:", string.format("%.0f min left", metrics.auraTimeMinutes) })
    end
    return metricsTable
end

local function tracking()
    detectNewFish()
    trackPorterBuffUsage() 
    local metricsTable = buildMetricsTable(collectCurrentMetrics())
    API.DrawTable(metricsTable)
end

-- ═════════════════════════════════════════════════════
--                   NAVIGATION FUNCTIONS                   
-- ═════════════════════════════════════════════════════

local function getBankingRegion(fishingAction, usePorters)
    return usePorters and BANKING_REGIONS[normalizeFishName(fishingAction)].porter or BANKING_REGIONS[normalizeFishName(fishingAction)].net
end

local function canBankForPorters()
    if not usePorters then return false end
    return getBankingRegion(fishingAction, usePorters):match("bankPorter")
end

local function findDepositLocation()
    local bankingRegion = getBankingRegion(fishingAction, usePorters)
    local bankRegion = regions[bankingRegion]
    local config = DEPOSIT_CONFIGS[bankingRegion]
    local mode = usePorters and "porter" or "net"
    local randomPt = randomPointInRegion(bankRegion)
    return {
        x = randomPt.x, y = randomPt.y, z = 0,
        id = config.id, action = config.action[mode] or config.action.net, route = config.route[mode]
    }
end

local function getNodePoint(n)
    if not n then
        handleCriticalError("Invalid node passed to getNodePoint", "Node parameter is nil")
    end
    return n.xMin and {
        x = math.floor(n.xMin + math.random() * (n.xMax - n.xMin)), 
        y = math.floor(n.yMin + math.random() * (n.yMax - n.yMin)), 
        z = 0 
    } or n
end

local function buildValidEdges(start, dest)
    validEdges = {}
    for node, connections in pairs(edges) do
        validEdges[node] = {}
        for _, connected in ipairs(connections) do
            if nodes[connected] then table.insert(validEdges[node], connected) end
        end
    end
    if (start == "frenzyN" and dest == "frenzyS") or (start == "frenzyS" and dest == "frenzyN") then
        table.insert(validEdges["frenzyN"], "frenzyS")
        table.insert(validEdges["frenzyS"], "frenzyN")
    end
end

local function find_path(startLocation, destinationLocation)
    local player = API.PlayerCoord()
    if not edges[startLocation] then
        startLocation = nearestNode(player.x, player.y, nodes)
        print(string.format("[WARN] find_path: startLocation invalid, using '%s'", startLocation))
    end
    buildValidEdges(startLocation, destinationLocation)
    pathQueue = {{startLocation}}
    visitedNodes = {[startLocation] = true}
    while #pathQueue > 0 do
        local currentPath = table.remove(pathQueue, 1)
        local currentNode = currentPath[#currentPath]
        if currentNode == destinationLocation then return currentPath end
        for _, nextNode in ipairs(validEdges[currentNode] or {}) do
            if not visitedNodes[nextNode] then
                visitedNodes[nextNode] = true
                local newPath = {table.unpack(currentPath)}
                table.insert(newPath, nextNode)
                table.insert(pathQueue, newPath)
            end
        end
    end
    return nil
end

local function optimizeWaypoints(path, i, player)
    local furthestIndex = i
    for j = i + 1, #path do
        local distance = regions[path[j]] and 
            dist2(player, randomPointInRegion(regions[path[j]])) or
            dist2(player, getNodePoint(nodes[path[j]]))
        if distance >= 8 and distance <= 25 then
            furthestIndex = j
        elseif distance > 25 then
            break
        end
    end
    return furthestIndex
end

local function doDirectFrenzyWalk(pr, dest)
    print(string.format("Direct walk %s -> %s", pr, dest))
    local pt = randomPointInRegion(regions[dest])
    API.DoAction_Tile(WPOINT.new(pt.x, pt.y, 0))
    API.RandomSleep2(700, 600, 1800)
    repeat
        if not API.Read_LoopyLoop() then return end
        API.RandomSleep2(200, 100, 100)
        tracking()
        local pos = API.PlayerCoord()
        local dx, dy = pos.x - pt.x, pos.y - pt.y
    until not API.ReadPlayerMovin2() or (dx*dx + dy*dy <= 36)
end

local function validateAndCleanPath(fullPath, pr, dest, player)
    if not fullPath or #fullPath < 2 then
        print(string.format("[ERROR] No path from %s -> %s", pr, dest))
        return nil
    end
    if #fullPath > 1 and fullPath[1] == pr then
        table.remove(fullPath, 1)
    end
    if #fullPath < 1 then
        print(string.format("[INFO] No movement needed, already at %s", dest))
        return nil
    end
    if pr == "jellyfish" and #fullPath > 0 and fullPath[1] == "midJunc" then
        local midPt = getNodePoint(nodes["midJunc"])
        local dx, dy = player.x - midPt.x, player.y - midPt.y
        if dx*dx + dy*dy < 81 then
            table.remove(fullPath, 1)
            print("[INFO] Skipping midJunc since we're close")
        end
    end
    return #fullPath > 0 and fullPath or nil
end

local function walkPath(path, startPlayerPos, dest)
    if not path or #path == 0 then
        print("[INFO] walkPath: Empty path, no movement needed")
        return
    end
    local i = 1
    while i <= #path do
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
                    print(string.format("[INFO] walkPath: Skipping %d waypoints, jumping from %s to %s", furthestIndex - i, path[i], path[furthestIndex]))
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
                print(string.format("Walking to %s (%d/%d) @ (%.2f,%.2f) [randomPointInRegion] (distance: %.1f)", label, i, #path, pt.x, pt.y, dist2(player, pt)))
            else
                local nodePt = getNodePoint(nodes[path[i]])
                pt = { x = nodePt.x, y = nodePt.y, z = nodePt.z or 0 }
                print(string.format("Walking to %s (%d/%d) @ (%.2f,%.2f) [getNodePoint] (distance: %.1f)", label, i, #path, pt.x, pt.y, dist2(player, pt)))
            end
            API.DoAction_Tile(WPOINT.new(pt.x, pt.y, pt.z or 0))
            API.RandomSleep2(1200,600,600)
            repeat
                if not API.Read_LoopyLoop() then 
                    print("[INFO] Script stopping during movement")
                    return 
                end   
                API.RandomSleep2(100,200,100)
                tracking()
                local player = API.PlayerCoord()
                local px, py, pz = player.x, player.y, player.z
                local isMoving = API.ReadPlayerMovin2()
                if math.random() < 0.2 then
                    print(string.format("[DEBUG] Movement progress: (%.1f,%.1f) -> target (%.1f,%.1f), moving=%s, distance=%.1f", px, py, pt.x, pt.y, tostring(isMoving), dist2(player, pt)))
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
                            print(string.format("[ERROR] Failed to reach %s. Player pos: (%.1f,%.1f,%d)", dest, px, py, pz))
                            if destRegion then
                                print(string.format("[ERROR] Target region: X(%.1f-%.1f) Y(%.1f-%.1f) Z(%d-%d)", destRegion.p1.x, destRegion.p2.x, destRegion.p1.y, destRegion.p2.y, destRegion.p1.z or 0, destRegion.p2.z or 3))
                            end
                            print("[ERROR] Stopping movement attempt")
                            return 
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

local function doMovementTo(destinationFunc)
    local player = API.PlayerCoord()
    local x, y, z = player.x, player.y, player.z
    local dest = destinationFunc()
    local pr = findPlayerRegion(x, y, z) or (inside(x, y, regions[dest], z) and dest) or nearestNode(x, y, nodes)
    if pr == dest then
        print(string.format("[INFO] Already at destination: %s", dest))
        return
    end
    if (pr == "frenzyN" and dest == "frenzyS") or (pr == "frenzyS" and dest == "frenzyN") then
        doDirectFrenzyWalk(pr, dest)
        return
    end
    local fullPath = find_path(pr, dest)
    local cleanPath = validateAndCleanPath(fullPath, pr, dest, player)
    if cleanPath then
        print(string.format("[INFO] Walking path: %s", table.concat(cleanPath, " -> ")))
        walkPath(cleanPath, player, dest)
    end
end

local function doMovement()
    doMovementTo(function() return normalizeFishName(fishingAction) end)
end

local function doMovementToBanking()
    doMovementTo(function() return getBankingRegion(fishingAction, usePorters) end)
end

local function ensureBackToFishing()
    local dest = normalizeFishName(fishingAction)
    local pos = API.PlayerCoord()
    local px, py, pz = pos.x, pos.y, pos.z
    
    if not inside(px, py, regions[dest], pz) then
        print("[WARN] Not in fishing area, returning")
        doMovement()
        pos = API.PlayerCoord()
        if not inside(pos.x, pos.y, regions[dest], pos.z) then
            print("[ERROR] Failed to return to fishing area")
            return false
        end
    end
    return true
end

-- ═════════════════════════════════════════════════════
--                   BANKING FUNCTIONS                   
-- ═════════════════════════════════════════════════════

local function interactObject(loc, timeout)
    timeout = timeout or 15
    print(string.format("[DEBUG] Interacting with object ID %d at (%.1f, %.1f)", loc.id, loc.x, loc.y))
    API.DoAction_Object1(loc.action, loc.route, { loc.id }, 50)
    API.RandomSleep2(math.random(1200, 2400), 600, math.random(600, 1200))
    local startTime = os.time()
    while API.ReadPlayerMovin2() do
        if os.time() - startTime >= timeout then
            print(string.format("[ERROR] Interaction timed out after %ds", timeout))
            return false 
        end
        API.RandomSleep2(math.random(100, 200), 100, 100)
        tracking()
    end
    print(string.format("[SUCCESS] Interacted with object ID %d", loc.id))
    return true
end

local function handleGOTEChargingInterface(currentPorters)
    print(string.format("[DEBUG] Charging GOTE with %d porters", currentPorters))
    API.DoAction_Interface(0xffffffff, API.GetEquipSlot(2).itemid1, 6, 1464, 15, 2, API.OFF_ACT_GeneralInterface_route2)
    API.RandomSleep2(math.random(800, 1600), 300, 600)
    return true
end

local function handleGOTEChargingConfirmation()
    if API.VB_FindPSettinOrder(2874).state == 1572882 then
        API.DoAction_Interface(0xffffffff, 0xffffffff, 0, 847, 22, -1, API.OFF_ACT_GeneralInterface_Choose_option)
        API.RandomSleep2(math.random(900, 2400), 600, 600)
    else
        print("[WARN] No confirmation dialog detected")
    end
    return true
end

local function validateChargingProgress(beforeAmount, beforePorters, afterAmount, afterPorters, requiredAmount)
    if afterAmount == beforeAmount and afterPorters == beforePorters then
        print("[ERROR] No progress made in charging attempt")
        return false
    end
    if afterAmount < requiredAmount and afterPorters == 0 then
        print(string.format("[ERROR] Insufficient porters - still need %d charges", requiredAmount - afterAmount))
        return false
    end
    return true
end

local function chargeGOTE()
    if not useGOTE then
        return false
    end
    local requiredAmount = getRequiredAmount()
    local currentAmount = getPorterAmount()
    print(string.format("[DEBUG] GOTE charging: %d/%d charges", currentAmount, requiredAmount))
    if currentAmount >= requiredAmount then
        print("[DEBUG] GOTE already charged")
        return true
    end
    if not isEquipmentOpen() and not openEquipment() then
        print("[ERROR] Unable to open equipment tab")
        return false
    end
    if getNecklaceID() == 0 then
        print("[ERROR] Unable to determine necklace slot")
        return false
    end
    for attempt = 1, 5 do
        local porterCount, porterCharges = howManyPorters()
        if porterCount < 1 then
            print("[ERROR] No porters available for GOTE charging")
            return false
        end
        local chargesNeeded = requiredAmount - currentAmount
        if porterCharges < chargesNeeded then
            print(string.format("[WARN] Partial charging: need %d, have %d charges", chargesNeeded, porterCharges))
        end
        local beforeAmount = getPorterAmount()
        local beforePorters, beforeCharges = howManyPorters()
        if not handleGOTEChargingInterface(porterCount) then
            return false
        end
        if not handleGOTEChargingConfirmation() then
            return false
        end
        local afterAmount = getPorterAmount()
        local afterPorters, afterCharges = howManyPorters()
        print(string.format("[DEBUG] Attempt %d: %d->%d charges, %d->%d porters", attempt, beforeAmount, afterAmount, beforePorters, afterPorters))
        if not validateChargingProgress(beforeAmount, beforePorters, afterAmount, afterPorters, requiredAmount) then
            return false
        end
        currentAmount = afterAmount
        if currentAmount >= requiredAmount then
            break
        end
        API.RandomSleep2(200, 100, 100)
        tracking()
    end
    if currentAmount < requiredAmount then
        handleCriticalError("Failed to charge GOTE after 5 attempts", string.format("Still need %d charges", requiredAmount - currentAmount))
    end
    if not isBackpackOpen() and not openBackpack() then
        print("[ERROR] Failed to re-open backpack tab")
        return false
    end
    print(string.format("[SUCCESS] GOTE charged to %d/%d", currentAmount, requiredAmount))
    return true
end

local function depositAtBank()
    local loc = findDepositLocation()
    if not loc then
        error("[ERROR] Could not determine deposit location")
        return false
    end
    print(("Banking at: %s (x=%.1f, y=%.1f)"):format(getBankingRegion(fishingAction, usePorters), loc.x, loc.y))
    print(string.format("[DEBUG] Banking details: ID=%d, action=0x%x", loc.id, loc.action))
    doMovementToBanking()
    tracking()
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
    if not maybeEnterPin() then
        error("[ERROR] failed to input bank pin")
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
                print(("[DEPOSIT] %dx %s -> %s gp"):format(deposited, displayName, format_number(gp)))
            end
        end
    end
    totalFish = totalFish + depositedFishCount
    print(("[DEPOSIT] Total deposit value: %s gp | Total fish count: %d"):format(format_number(depositGP), totalFish))
    tracking()
    updateInventoryBaseline() 
    return true
end

-- ═════════════════════════════════════════════════════
--                    EVENT FUNCTIONS                    
-- ═════════════════════════════════════════════════════

local function checkXpIncrease()
    local newXp = API.GetSkillXP("FISHING")
    if newXp == lastIdleXp then
        handleCriticalError("No XP increase detected during idle check", "Player may be stuck or not actively fishing")
    end
    lastIdleXp = newXp 
end

local function idleCheck()
    local now = API.ScriptRuntime()
    if randomTime == 0 then
        randomTime = math.random(MIN_IDLE_TIME_MINUTES * 60, MAX_IDLE_TIME_MINUTES * 60)
    end
    if now - afk > randomTime then
        afk = now
        randomTime = 0
        tracking()
        API.PIdle1()
        checkXpIncrease()
    end
end

local function gameStateChecks()
    local state = API.GetGameState2()
    if state ~= 3 or not API.PlayerLoggedIn() then
        handleCriticalError("Player not in game", string.format("Game state: %d, Logged in: %s", state, tostring(API.PlayerLoggedIn())))
    end
end

local function claimNPC(npcId, npcName)
    local npc = findNPC(npcId, 1, 30)
    if not npc then
        return false
    end
    print(string.format("[DEBUG] %s detected - attempting to interact", npcName))
    API.RandomSleep2(math.random(600, 1800), 600, 1200)
    return API.DoAction_NPC(0x29, API.OFF_ACT_InteractNPC_route, { npcId }, 50)
end

local function claimSerenSpirit()
    return claimNPC(26022, "Seren Spirit")
end

local function claimDivineBlessing()
    return claimNPC(27228, "Divine Blessing")
end

local function handleMessageInBottle(itemId, successMsg)
    local bottleOpened = false
    for attempt = 1, 10 do
        tracking()
        local vb_state = API.VB_FindPSettinOrder(2874).state
        if (vb_state == 0 and bottleOpened) or not Inventory:Contains(itemId) then
            print("[DEBUG] - " .. successMsg)
            return true
        end
        if vb_state == 12 then
            API.DoAction_Interface(0xffffffff, 0xffffffff, 0, 1186, 8, -1, API.OFF_ACT_GeneralInterface_Choose_option)
            API.RandomSleep2(600, 600, 600)
            bottleOpened = true
        elseif vb_state == 18 then
            API.DoAction_Interface(0xffffffff, 0xffffffff, 0, 751, 66, -1, API.OFF_ACT_GeneralInterface_Choose_option)
            API.RandomSleep2(600, 600, 600)
            bottleOpened = true
        elseif vb_state == 0 and not bottleOpened then
            API.DoAction_Inventory1(itemId, 0, 1, API.OFF_ACT_GeneralInterface_route)
            API.RandomSleep2(600, 600, 600)
        else
            API.RandomSleep2(600, 600, 600)
        end
    end
    error("[ERROR] - Unable to process message in a bottle after 10 attempts")
    return false
end

local function handleStandardRandomEvent(itemId, successMsg)
    for attempt = 1, 20 do
        if API.VB_FindPSettinOrder(2874).state == 1572882 then
            break
        end
        API.DoAction_Inventory1(itemId, 0, 1, API.OFF_ACT_GeneralInterface_route)
        API.RandomSleep2(800, 600, 600)
    end
    API.DoAction_Interface(0xffffffff, 0xffffffff, 0, 847, 22, -1, API.OFF_ACT_GeneralInterface_Choose_option)
    API.RandomSleep2(800, 600, 600)
    local finalState = API.VB_FindPSettinOrder(2874).state
    if finalState ~= 1572882 then
        print("[DEBUG] - " .. successMsg)
        return true
    else
        print("[ERROR] - Unable to process random event: state still " .. tostring(finalState))
        return false
    end
end

local function handleRandomEvent(itemId, startMsg, successMsg)
    if not watchRandoms or not Inventory:Contains(itemId) then
        return true
    end
    print("[DEBUG] - " .. startMsg)
    if itemId == 42282 then
        return handleMessageInBottle(itemId, successMsg)
    else
        return handleStandardRandomEvent(itemId, successMsg)
    end
end

local function processRandomEvents()
    for _, ev in ipairs(RANDOM_EVENTS) do
        local itemId, startMsg, successMsg = unpack(ev)
        if not handleRandomEvent(itemId, startMsg, successMsg) then
            handleCriticalError("Failed to handle fishing random event", string.format("Interaction failed for item ID %d: %s", itemId, startMsg))
        end
    end
    return true
end

local function handleEventProcessingAndCleanup()
    if not processRandomEvents() then
        handleCriticalError("Failed to process random events", "Random event processing returned false - check inventory")
    end
    if claimSerenSpirit() then
        print("[SUCCESS] Claimed Seren Spirit")
    end
    if claimDivineBlessing() then
        print("[SUCCESS] Claimed Divine Blessing")
    end
    tracking()
    return true
end

-- ═════════════════════════════════════════════════════
--                   FISHING FUNCTIONS                   
-- ═════════════════════════════════════════════════════

local function augmentedReached()
    local container = API.Container_Get_all(94)
    local itemXp = container and container[4] and container[4].Extra_ints and container[4].Extra_ints[2]
    return itemXp and GetItemLevel(itemXp) >= alertItemLevel or false
end

local function shouldReinteractWithSpot()
    local interacting = API.ReadLpInteracting()
    if not interacting or not interacting.Name then
        return false
    end
    local name = interacting.Name
    if name == "Electrifying blue blubber jellyfish" or name == "Electrifying green blubber jellyfish" then
        print("[DEBUG] - Interacting with an electrified fishing spot")
        return true
    end
    if name == "Sailfish" and normalizeFishName(fishingAction) == "sailfish" then
        if #API.GetAllObjArray1({25222}, 50, {1}) > 0 then
            print("[DEBUG] - Interacting with a regular sailfish spot but a swift sailfish is available")
            return true
        end
    end
    return false
end

local function tryFishingAction()
    local key = fishingAction == "bluejellyfish" and "bluejellyfish" or
                fishingAction == "greenjellyfish" and "greenjellyfish" or normalizedAction
    local ids = npcIds[key]
    if not ids then
        print("[tryFishingAction] no NPC IDs for:", key)
        return false
    end
    for _, id in ipairs(ids) do
        local npcs = API.GetAllObjArray1({id}, 50, {1})
        if npcs and #npcs > 0 then
            for _, npc in ipairs(npcs) do
                if not isFrenzyAction or tostring(npc.Action) == "Fling" then
                    return API.DoAction_NPC(0x3c, API.OFF_ACT_InteractNPC_route, { npc.Id }, 50)
                end
            end
        end
    end
    return false
end

local function doAndAwaitAnim(interactFn, description, timeoutSec)
    print(string.format("[DEBUG] - %s", description))
    if not interactFn() then
        print(string.format("[ERROR] - %s interaction failed", description))
        return false
    end
    if isFrenzyAction and description == "Trying fishing action" then
        waitingForFrenzyCompletion = true
        print("[DEBUG] - Waiting for frenzy completion")
    end
    local nonMovingTime, lastTime = 0, API.ScriptRuntime()
    repeat
        API.RandomSleep2(200, 100, 100)
        tracking()
        local now = API.ScriptRuntime()
        if not API.ReadPlayerMovin2() then
            nonMovingTime = nonMovingTime + (now - lastTime)
            if nonMovingTime > timeoutSec then
                print(string.format("[ERROR] - %s: timeout after %ds", description, timeoutSec))
                return false
            end
        end
        lastTime = now
    until API.ReadPlayerAnim() ~= 0
    print(string.format("[DEBUG] - Animation started after %.2fs", nonMovingTime))
    return true
end

local function handleFishingInteractions()
    local player = API.PlayerCoord()
    local targetRegion = normalizedAction
    if not regions[targetRegion] then
        handleCriticalError("Invalid fishing destination", string.format("No region defined for fishing action '%s'", fishingAction))
    end
    if not inside(player.x, player.y, regions[targetRegion], player.z) then
        local currentRegion = findPlayerRegion(player.x, player.y, player.z) or "Unknown"
        print(string.format("[INFO] Moving from '%s' to '%s'", currentRegion, targetRegion))
        doMovement()
        local newPlayer = API.PlayerCoord()
        if not inside(newPlayer.x, newPlayer.y, regions[targetRegion], newPlayer.z) then
            handleCriticalError("Failed to reach fishing area", string.format("Movement failed: %s -> %s", currentRegion, targetRegion))
        end
        print(string.format("[SUCCESS] Moved to fishing area: '%s'", targetRegion))
    end
    if checkDialogue() and normalizedAction == "swarm" then
        print("[DEBUG] Swarm dialogue detected - attempting net snagging")
        local result = doAndAwaitAnim(
            function()
                return API.DoAction_NPC(0x3c, API.OFF_ACT_InteractNPC_route, {25220}, 50)
            end,
            "Snagging net @ swarm spot", 20
        )
        if not result then
            handleCriticalError("Swarm fishing failed", "doAndAwaitAnim returned false for swarm snag")
        end
        recordFishTime()
        return true
    end
    if (checkAnim() and not checkDialogue()) or shouldReinteractWithSpot() then
        local interacting = API.ReadLpInteracting()
        local interactionType = "regular fishing"
        if interacting and interacting.Name then
            if interacting.Name:find("Electrifying") then
                interactionType = "electrified spot"
            elseif interacting.Name == "Sailfish" then
                interactionType = "swift sailfish optimization"
            end
        end
        print(string.format("[DEBUG] Starting %s for '%s'", interactionType, fishingAction))
        local result = doAndAwaitAnim(tryFishingAction, "Trying fishing action", 20)
        if not result then
            handleCriticalError("Fishing action failed", string.format("%s '%s' returned false", interactionType, fishingAction))
        end
        recordFishTime()
        return true
    end
    return false
end

-- ═════════════════════════════════════════════════════
--                 INVENTORY MANAGEMENT                 
-- ═════════════════════════════════════════════════════

local function handleInventoryManagement()
    if actionClean == "frenzyS" or actionClean == "frenzyN" or actionClean == "minnows" then
        return
    end
    if usePorters then
        if useGOTE then
            local chargingThreshold = getGOTEChargingThreshold()
            local needsCharging = checkPorter(chargingThreshold)
            if needsCharging then
                if hasEnoughPortersForGOTE() then
                    if not chargeGOTE() then
                        print("[INFO] GOTE charging failed - banking for more porters")
                        if not depositAtBank() then
                            handleCriticalError("Banking failed during GOTE restocking", "depositAtBank() returned false")
                        end
                        if not ensureBackToFishing() then
                            handleCriticalError("Failed to return to fishing area after banking", "ensureBackToFishing() returned false")
                        end
                    end
                else
                    if canBankForPorters() then
                        print("[INFO] GOTE needs charging - banking for porters")
                        if not depositAtBank() then
                            handleCriticalError("Banking failed during porter restocking", "depositAtBank() returned false")
                        end
                        if not ensureBackToFishing() then
                            handleCriticalError("Failed to return to fishing area after banking", "ensureBackToFishing() returned false")
                        end
                    else
                        handleCriticalError("GOTE requires porters but cannot restock at current location", string.format("Activity '%s' uses net banking which doesn't support porter restocking", fishingAction))
                    end
                end
            end
        else
            local needsPorter = checkPorter(0)
            if needsPorter then  
                local porterId, porterChargeValue = hasPorter()
                if porterId > 0 then
                    print(string.format("[DEBUG] Activating porter ID %d (%d charges)", porterId, porterChargeValue))
                    API.DoAction_Inventory1(porterId, 0, 2, API.OFF_ACT_GeneralInterface_route)
                    API.RandomSleep2(math.random(600, 1800), 600, 330)
                else
                    if canBankForPorters() then
                        print("[INFO] No porters available - banking for restock")
                        if not depositAtBank() then
                            handleCriticalError("Banking failed during porter restock", "depositAtBank() returned false")
                        end
                        if not ensureBackToFishing() then
                            handleCriticalError("Failed to return to fishing area after banking", "ensureBackToFishing() returned false")
                        end
                    else
                        handleCriticalError("No porters available and cannot restock at current location", string.format("Activity '%s' requires porters but current location only supports net banking", fishingAction))
                    end
                end
            end
        end
    else
        if Inventory:FreeSpaces() == 0 then
            print("[INFO] Inventory full - depositing at fishing net")
            if not depositAtNet() then
                handleCriticalError("Net deposit failed", "depositAtNet() returned false")
            end
            if not ensureBackToFishing() then
                handleCriticalError("Failed to return to fishing area after net deposit", "ensureBackToFishing() returned false")
            end
        end
    end
end

-- ═════════════════════════════════════════════════════
--                   RESET FUNCTIONS                   
-- ═════════════════════════════════════════════════════

local function resetFishTrackingVariables()
    fishCounts, prevFishCounts = {}, {}
    for _, f in ipairs(FISH_TYPES) do
        fishCounts[f[1]] = 0
        prevFishCounts[f[1]] = 0
    end
    totalFish, lastChatCount = 0, 0
    frenzyInteractions = 0
    waitingForFrenzyCompletion = false
    minnowInteractions = 0
    lastKnownMinnowCount = Inventory:GetItemAmount(42241) or 0
    lastFishCaught = API.ScriptRuntime()
    lastKnownFishCount = 0
end

local function resetPorterTrackingVariables()
    portersUsed = 0
    lastPorterBuffAmount = 0
    buffTrackingInitialized = false
    currentGOTEThreshold = 0
    lastPorterInventoryState = ""
end

local function resetStatisticsVariables()
    startXp = API.GetSkillXP("FISHING")
    lastDisplayedValues = {
        totalFish = 0, xpGained = 0, gpEarned = 0, porterCharges = 0,
        porterCount = 0, totalCharges = 0, portersUsed = 0, inventorySpaces = 0,
        playerAnim = 0, playerMoving = false, currentRegion = "", playerX = 0, playerY = 0,
        inventoryHash = "", timeSinceActionSeconds = 0, timeSinceFishSeconds = 0,
        auraTimeMinutes = 0, runtimeMinutes = 0
    }
    configurationDisplayed = false
    lastConfigState = ""
end

local function resetScriptVariables()
    print("[INFO] Resetting script variables")
    startingInventory = {}
    for _, f in ipairs(FISH_TYPES) do
        local name, _, _, id = unpack(f)
        startingInventory[name] = id and Inventory:GetItemAmount(id) or 0
    end
    resetFishTrackingVariables()    
    resetPorterTrackingVariables()  
    resetStatisticsVariables()      
    lastIdleXp = API.GetSkillXP("FISHING")
    lastFishTime = API.ScriptRuntime()
    afk = API.ScriptRuntime()
    randomTime = 0
end

-- ═════════════════════════════════════════════════════
--                 INITIALIZATION FUNCTIONS                 
-- ═════════════════════════════════════════════════════

local function initializeScript()
    print("[INFO] Starting input validation")
    if not validActions[fishingAction] then
        handleCriticalError("Invalid fishing action specified", string.format("'%s' is not valid. Must be one of: sailfish, minnows, frenzyS, frenzyN, swarm, bluejellyfish, greenjellyfish", fishingAction))
    end
    if not isInDeepSeaHub() then
        handleCriticalError("Player not in Deep Sea Fishing area", "Please move to the Deep Sea Fishing hub and restart the script")
    end
    if not checkRequiredLevel() then
        handleCriticalError("Insufficient fishing level", string.format("Need level %d for %s", levelRequirements[fishingAction], fishingAction))
    end
    if useGOTE and not usePorters then
        handleCriticalError("Invalid GOTE configuration", "useGOTE requires usePorters=true. GOTE needs porters to charge itself")
    end
    resetScriptVariables()
    actionClean = normalizeFishName(fishingAction)
    normalizedAction = normalizeFishName(fishingAction)
    isFrenzyAction = normalizedAction == "frenzyS" or normalizedAction == "frenzyN"
    print("[DEBUG] Script setup completed")
end

-- ═════════════════════════════════════════════════════
--                      MAIN LOOP                      
-- ═════════════════════════════════════════════════════

API.Write_fake_mouse_do(false)
initializeScript()

while API.Read_LoopyLoop() do
    gameStateChecks()
    handleInventoryManagement()
    handleAuraManagement()
    idleCheck()
    findChatText()
    handleFishingInteractions()
    handleEventProcessingAndCleanup()
    API.RandomSleep2(math.random(300, 500), 100, 600)
end
