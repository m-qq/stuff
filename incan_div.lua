local API = require("api")

API.Write_fake_mouse_do(false)
API.SetDrawLogs(true)
API.SetDrawTrackedSkills(true)
API.SetMaxIdleTime(9)

local WISP_TYPE = "INCANDESCENT"  

local WISP_DATA = {
    INCANDESCENT = {
        enriched_spring = 18195,
        spring = 18194,
        wisp = 18171,
        energy = 29324
    }
    -- Add other wisp types here, e.g.:
    -- LUMINOUS = { enriched_spring = XXXXX, spring = XXXXX, wisp = XXXXX, energy = XXXXX },
}

local ID = {
    BUTTERFLY = 19884,
    KNOWLEDGE = 23855,
    SEREN_SPIRIT = 26022,
    SIPHON_ANIM = 21228,
    MEMORY_VARBIT = 34807,
    HATCHET = 59629,

    -- For depositing memories manually:
    -- EMPOWERED_RIFT = 93489 (type 0)
    -- ENERGY_RIFT = 87306 (type 12)
}

local BUTTERFLY_TIMEOUT = 15
local CHECK_INTERVAL = 100

local energy = {start = 0, current = 0, gained = 0}
local strands = {start = 0, current = 0, gained = 0}

local function waitForCondition(conditionFunc, timeout, checkInterval)
    local startTime = API.ScriptRuntime()
    local interval = checkInterval or CHECK_INTERVAL

    while (API.ScriptRuntime() - startTime) < timeout and API.Read_LoopyLoop() do
        if conditionFunc() then
            return true
        end
        API.RandomSleep2(interval, interval / 2, interval / 2)
    end

    return false
end

local function handlePriorityTarget(npcId, name, waitForDisappear)
    local npcs = API.GetAllObjArray1({npcId}, 50, {1})
    if #npcs > 0 then
        print("Found " .. name .. ", interacting...")
        API.RandomSleep2(300, 700, math.random(600, 1000))
        API.DoAction_NPC(0xc8, API.OFF_ACT_InteractNPC_route, {npcId}, 50)

        if waitForDisappear then
            local startTime = API.ScriptRuntime()
            while (API.ScriptRuntime() - startTime) < BUTTERFLY_TIMEOUT and API.Read_LoopyLoop() do
                API.RandomSleep2(CHECK_INTERVAL, 50, 50)
                local newNpcs = API.GetAllObjArray1({npcId}, 50, {1})
                if #newNpcs == 0 then
                    print(name .. " interaction complete")
                    return true
                end
            end
            print(name .. " interaction timed out")
        else
            API.RandomSleep2(300, 100, 100)
        end

        return true
    end
    return false
end

local function updateTracking()
    local wispConfig = WISP_DATA[WISP_TYPE]
    local newEnergy = Inventory:GetItemAmount(wispConfig.energy)
    if newEnergy ~= energy.current then
        energy.current = newEnergy
        energy.gained = energy.current - energy.start
        print(string.format("Energy gained this session: %d (Total: %d)", energy.gained, energy.current))
    end
    local newStrands = API.GetVarbitValue(ID.MEMORY_VARBIT)
    if newStrands ~= strands.current then
        strands.current = newStrands
        strands.gained = strands.current - strands.start
        print(string.format("Memory strands gained this session: %d (Total: %d)", strands.gained, strands.current))
    end
end

local function handleWisp()
    local wispConfig = WISP_DATA[WISP_TYPE]
    local targetId = nil
    local targetName = nil

    local enrichedSprings = API.GetAllObjArray1({wispConfig.enriched_spring}, 50, {1})
    if #enrichedSprings > 0 then
        print("Found enriched spring, interacting...")
        API.RandomSleep2(300, 700, math.random(600, 1000))
        targetId = wispConfig.enriched_spring
        targetName = "enriched spring"
        API.DoAction_NPC(0xc8, API.OFF_ACT_InteractNPC_route, {wispConfig.enriched_spring}, 50)
    else
        local springs = API.GetAllObjArray1({wispConfig.spring}, 50, {1})
        if #springs > 0 then
            print("Found spring, interacting...")
            API.RandomSleep2(300, 700, math.random(600, 1000))
            targetId = wispConfig.spring
            targetName = "spring"
            API.DoAction_NPC(0xc8, API.OFF_ACT_InteractNPC_route, {wispConfig.spring}, 50)
        else
            local wisps = API.GetAllObjArray1({wispConfig.wisp}, 50, {1})
            if #wisps > 0 then
                print("Found wisp, interacting...")
                API.RandomSleep2(300, 700, math.random(600, 1000))
                targetId = wispConfig.wisp
                targetName = "wisp"
                API.DoAction_NPC(0xc8, API.OFF_ACT_InteractNPC_route, {wispConfig.wisp}, 50)
            end
        end
    end

    if targetId then
        waitForCondition(function() return API.ReadPlayerMovin2() end, 3, CHECK_INTERVAL)
        waitForCondition(function() return not API.ReadPlayerMovin2() end, 10, CHECK_INTERVAL)
        local animStarted = waitForCondition(function() return API.ReadPlayerAnim() == ID.SIPHON_ANIM end, 5, CHECK_INTERVAL)
        if animStarted then
            print("Siphoning...")
            while API.ReadPlayerAnim() == ID.SIPHON_ANIM and API.Read_LoopyLoop() do
                updateTracking()

                local butterflies = API.GetAllObjArray1({ID.BUTTERFLY}, 50, {1})
                local knowledge = API.GetAllObjArray1({ID.KNOWLEDGE}, 50, {1})

                if #butterflies > 0 or #knowledge > 0 then
                    print("Priority target detected, interrupting siphon")
                    break
                end
                if targetId ~= wispConfig.enriched_spring then
                    local newEnrichedSprings = API.GetAllObjArray1({wispConfig.enriched_spring}, 50, {1})
                    if #newEnrichedSprings > 0 then
                        print("Enriched spring appeared, switching...")
                        break
                    end
                end

                API.RandomSleep2(CHECK_INTERVAL, 50, 50)
            end
            print("Siphoning complete")
        end
        return true
    end
    return false
end

local function mainLoop()
    local wispConfig = WISP_DATA[WISP_TYPE]
    if not wispConfig then
        print("ERROR: Invalid WISP_TYPE '" .. WISP_TYPE .. "' configured!")
        print("Script terminated.")
        return
    end

    print("Starting " .. WISP_TYPE .. " Divination script...")
    if not API.Container_Check_Items(94, {ID.HATCHET}) then
        print("ERROR: Hatchet of divinity (id = " .. ID.HATCHET .. ") not equipped!")
        print("Script terminated.")
        return
    end
    print("Hatchet of divinity equipped.")
    energy.start = Inventory:GetItemAmount(wispConfig.energy)
    energy.current = energy.start
    print(string.format("Starting with %d energy in inventory", energy.start))
    strands.start = API.GetVarbitValue(ID.MEMORY_VARBIT)
    strands.current = strands.start
    print(string.format("Starting with %d memory strands", strands.start))
    while API.Read_LoopyLoop() do
        updateTracking()
        if handlePriorityTarget(ID.BUTTERFLY, "Guthixian butterfly", true) then
            API.RandomSleep2(300, 500, 200)
        end
        if handlePriorityTarget(ID.KNOWLEDGE, "Manifested knowledge", false) then
            API.RandomSleep2(300, 500, 200)
        end
        if handlePriorityTarget(ID.SEREN_SPIRIT, "Seren spirit", false) then
            API.RandomSleep2(300, 500, 200)
        end
        if API.ReadPlayerAnim() ~= ID.SIPHON_ANIM then
            handleWisp()
        end
        API.RandomSleep2(CHECK_INTERVAL, 150, 100)
    end
end

mainLoop()
