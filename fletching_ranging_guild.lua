local API = require("api")

local mode = "headless"  -- "headless", "rune", "adamant", "broad"

local MODES = {
    headless = {
        name = "Headless Arrows",
        interfaceText = "Headless arrow x15",
        inventoryAction = {itemId = 52, action = API.OFF_ACT_GeneralInterface_route},
        requiredItems = {
            {id = 52, name = "Arrow shaft"},  -- Arrow shafts
            {id = 314, name = "Feather"}      -- Feathers
        }
    },
    rune = {
        name = "Rune Arrows",
        interfaceText = "Rune arrow x15",
        inventoryAction = {itemId = 44, action = API.OFF_ACT_GeneralInterface_route},
        requiredItems = {
            {id = 53, name = "Headless arrow"}, -- Headless arrows
            {id = 44, name = "Rune arrowtips"}  -- Rune arrowtips
        }
    },
    adamant = {
        name = "Adamant Arrows",
        interfaceText = "Adamant arrow x15",
        inventoryAction = {itemId = 43, action = API.OFF_ACT_GeneralInterface_route},
        requiredItems = {
            {id = 53, name = "Headless arrow"},   -- Headless arrows
            {id = 43, name = "Adamant arrowtips"} -- Adamant arrowtips
        }
    },
    broad = {
        name = "Broad Arrows",
        interfaceText = "Broad arrow x15",
        inventoryAction = {itemId = 13278, action = API.OFF_ACT_GeneralInterface_route},
        requiredItems = {
            {id = 53, name = "Headless arrow"},     -- Headless arrows
            {id = 13278, name = "Broad arrowheads"}, -- Broad arrowheads
            {id = 4160, name = "Broad arrow"}       -- Product (for reference)
        }
    }
}

local currentMode = MODES[mode]
if not currentMode then
    error("Invalid mode: " .. tostring(mode) .. ". Valid modes: headless, rune, adamant, broad")
end

print(string.format("[CONFIG] Mode: %s", currentMode.name))
print(string.format("[CONFIG] Interface text: %s", currentMode.interfaceText))
print(string.format("[CONFIG] Required items: %s + %s", currentMode.requiredItems[1].name, currentMode.requiredItems[2].name))

API.Write_fake_mouse_do(false)
API.SetDrawTrackedSkills(true)
API.SetDrawLogs(true)
API.SetMaxIdleTime(9)

local actionPerformed = false
local cycleStartTime = 0
local actionType = "none" 
local TIMEOUT_MS = 5000  

local function resetCycle()
    actionPerformed = false
    cycleStartTime = API.ScriptRuntime()
    actionType = "none"
    print("[DEBUG] Cycle reset")
end

local function isTimedOut()
    return (API.ScriptRuntime() - cycleStartTime) >= TIMEOUT_MS
end

local function checkRequiredItems()
    for _, item in ipairs(currentMode.requiredItems) do
        local amount = Inventory:GetItemAmount(item.id)
        if amount <= 0 then
            print(string.format("[ERROR] Missing required item: %s (ID: %d)", item.name, item.id))
            return false
        end
        print(string.format("[CHECK] %s: %d", item.name, amount))
    end
    return true
end

local function getCurrentInterfaceText()
    local interfaceResult = API.ScanForInterfaceTest2Get(false, { { 1370,0,-1,0 }, { 1370,2,-1,0 }, { 1370,4,-1,0 }, { 1370,5,-1,0 }, { 1370,13,-1,0 } })
    if interfaceResult and #interfaceResult > 0 then
        return interfaceResult[1].textids
    end
    return nil
end

resetCycle()

while API.Read_LoopyLoop() do
    if isTimedOut() then
        print(string.format("[WARNING] Cycle timed out after %d seconds, forcing reset", TIMEOUT_MS / 1000))
        resetCycle()
        API.RandomSleep2(500, 200, 300)
        goto continue
    end

    if not actionPerformed then
        if not checkRequiredItems() then
            print("[ERROR] Missing required items, stopping script")
            API.Write_LoopyLoop(false)
            return
        end

        local currentInterfaceText = getCurrentInterfaceText()

        if currentInterfaceText == currentMode.interfaceText then
            print(string.format("[ACTION] Interface action - Clicking %s", currentMode.interfaceText))
            API.DoAction_Interface(0xffffffff,0xffffffff,0,1370,30,-1,API.OFF_ACT_GeneralInterface_Choose_option)
            actionPerformed = true
            actionType = "interface"
        else
            print(string.format("[ACTION] Inventory action - Opening %s interface", currentMode.name))
            API.DoAction_Inventory1(currentMode.inventoryAction.itemId, 0, 1, currentMode.inventoryAction.action)
            actionPerformed = true
            actionType = "inventory"
        end
    end

    if actionPerformed then
        local timeSinceAction = API.ScriptRuntime() - cycleStartTime
        local shouldReset = false

        if actionType == "inventory" then
            local currentInterfaceText = getCurrentInterfaceText()

            if currentInterfaceText == currentMode.interfaceText then
                shouldReset = true
                print(string.format("[SUCCESS] Interface opened: %s", currentMode.interfaceText))
            elseif timeSinceAction >= 2000 then -- 2 second timeout for interface to open
                shouldReset = true
                print(string.format("[TIMEOUT] Interface didn't open, forcing cycle reset (expected: %s)", currentMode.interfaceText))
            end
        elseif actionType == "interface" then
 
            local currentInterfaceText = getCurrentInterfaceText()
            if currentInterfaceText ~= currentMode.interfaceText then
                shouldReset = true
                print("[SUCCESS] Interface action completed, interface changed")
            elseif timeSinceAction >= 2000 then -- 2 second timeout for interface action
                shouldReset = true
                print("[TIMEOUT] Interface action timeout, forcing cycle reset")
            end
        end

        if shouldReset then
            resetCycle()
        end
    end

    ::continue::
    API.RandomSleep2(100, 50, 100)
end
