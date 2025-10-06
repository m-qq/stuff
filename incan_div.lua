local API = require("api")

API.Write_fake_mouse_do(false)
API.SetDrawLogs(true)
API.SetDrawTrackedSkills(true)
API.SetMaxIdleTime(9)

local WISP_TYPE = "INCANDESCENT"

local LEAGUES = true

local HATCHET_OF_DIVINITY = true
local MEMORY_DOWSER = false

local WISP_DATA = {
    PALE = {
        spring = 18173,
        wisp = 18150,
        energy = 29313,
        memory = 29384,
        rift_x = 3121.0,
        rift_y = 3216.0,
        level = 1
    },
    FLICKERING = {
        enriched_spring = 18175,
        enriched_wisp = 18154,
        spring = 18174,
        wisp = 18151,
        energy = 29314,
        memory = 29385,
        enriched_memory = 39396,
        rift_x = 3007.0,
        rift_y = 3402.0,
        level = 10
    },
    BRIGHT = {
        enriched_spring = 18177,
        enriched_wisp = 18154,
        spring = 18176,
        wisp = 18153,
        energy = 29315,
        memory = 29386,
        enriched_memory = 29397,
        rift_x = 3303.0,
        rift_y = 3396.0,
        level = 20
    },
    GLOWING = {
        enriched_spring = 18179,
        enriched_wisp = 18156,
        spring = 18178,
        wisp = 18155,
        energy = 29316,
        memory = 29387,
        enriched_memory = 29398,
        rift_x = 2735.0,
        rift_y = 3413.0,
        level = 30
    },
    SPARKLING = {
        enriched_spring = 18181,
        enriched_wisp = 18158,
        spring = 18180,
        wisp = 18157,
        energy = 29317,
        memory = 29388,
        enriched_memory = 29399,
        rift_x = 2769.0,
        rift_y = 3599.0,
        level = 40
    },
    GLEAMING = {
        enriched_spring = 18183,
        enriched_wisp = 18160,
        spring = 18182,
        wisp = 18159,
        energy = 29318,
        memory = 29389,
        enriched_memory = 29400,
        rift_x = 2890.0,
        rift_y = 3047.0,
        level = 50
    },
    VIBRANT = {
        enriched_spring = 18185,
        enriched_wisp = 18162,
        spring = 18184,
        wisp = 18161,
        energy = 29319,
        memory = 29390,
        enriched_memory = 29401,
        rift_x = 2422.0,
        rift_y = 2864.0,
        level = 60
    },
    LUSTROUS = {
        enriched_spring = 18187,
        enriched_wisp = 18164,
        spring = 18186,
        wisp = 18163,
        energy = 29320,
        memory = 29391,
        enriched_memory = 29402,
        rift_x = 3468.0,
        rift_y = 3539.0,
        level = 70
    },
    BRILLIANT = {
        enriched_spring = 18189,
        enriched_wisp = 18166,
        spring = 18188,
        wisp = 18165,
        energy = 29321,
        memory = 29392,
        enriched_memory = 29403,
        rift_x = 3405.0,
        rift_y = 3294.0,
        level = 80
    },
    RADIANT = {
        enriched_spring = 18191,
        enriched_wisp = 18168,
        spring = 18190,
        wisp = 18167,
        energy = 29322,
        memory = 29393,
        enriched_memory = 29404,
        rift_x = 3805.0,
        rift_y = 3552.0,
        level = 85
    },
    LUMINOUS = {
        enriched_spring = 18193,
        enriched_wisp = 18170,
        spring = 18192,
        wisp = 18169,
        energy = 29323,
        memory = 29394,
        enriched_memory = 29405,
        rift_x = 3315.0,
        rift_y = 2658.0,
        level = 90
    },
    INCANDESCENT = {
        enriched_spring = 18195,
        enriched_wisp = 18172,
        spring = 18194,
        wisp = 18171,
        energy = 29324,
        memory = 29395,
        enriched_memory = 29406,
        rift_x = 2282.0,
        rift_y = 3048.0,
        level = 95
    }
}

local ID = {
    BUTTERFLY = 19884,
    KNOWLEDGE = 23855,
    SEREN_SPIRIT = 26022,
    SIPHON_ANIM = 21228,
    MEMORY_VARBIT = 34807,
    HATCHET = 59629,
    MEMORY_DOWSER = 57521,

    -- For depositing memories manually:
    -- EMPOWERED_RIFT = 93489 (type 0)
    -- ENERGY_RIFT = 87306 (type 12)
}

local BUTTERFLY_TIMEOUT = 15
local CHECK_INTERVAL = 100

local energy = {start = 0, current = 0, gained = 0}
local strands = {start = 0, current = 0, gained = 0}
local manualDeposit = false

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

    if wispConfig.enriched_spring then
        local enrichedSprings = API.GetAllObjArray1({wispConfig.enriched_spring}, 50, {1})
        if #enrichedSprings > 0 then
            print("Found enriched spring, interacting...")
            API.RandomSleep2(300, 700, math.random(600, 1000))
            targetId = wispConfig.enriched_spring
            targetName = "enriched spring"
            API.DoAction_NPC(0xc8, API.OFF_ACT_InteractNPC_route, {wispConfig.enriched_spring}, 50)
        end
    end

    if not targetId and wispConfig.enriched_wisp then
        local enrichedWisps = API.GetAllObjArray1({wispConfig.enriched_wisp}, 50, {1})
        if #enrichedWisps > 0 then
            print("Found enriched wisp, interacting...")
            API.RandomSleep2(300, 700, math.random(600, 1000))
            targetId = wispConfig.enriched_wisp
            targetName = "enriched wisp"
            API.DoAction_NPC(0xc8, API.OFF_ACT_InteractNPC_route, {wispConfig.enriched_wisp}, 50)
        end
    end

    if not targetId then
        local springs = API.GetAllObjArray1({wispConfig.spring}, 50, {1})
        if #springs > 0 then
            print("Found spring, interacting...")
            API.RandomSleep2(300, 700, math.random(600, 1000))
            targetId = wispConfig.spring
            targetName = "spring"
            API.DoAction_NPC(0xc8, API.OFF_ACT_InteractNPC_route, {wispConfig.spring}, 50)
        end
    end

    if not targetId then
        local wisps = API.GetAllObjArray1({wispConfig.wisp}, 50, {1})
        if #wisps > 0 then
            print("Found wisp, interacting...")
            API.RandomSleep2(300, 700, math.random(600, 1000))
            targetId = wispConfig.wisp
            targetName = "wisp"
            API.DoAction_NPC(0xc8, API.OFF_ACT_InteractNPC_route, {wispConfig.wisp}, 50)
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

                local isHarvestingEnriched = (targetId == wispConfig.enriched_spring or targetId == wispConfig.enriched_wisp)

                if not isHarvestingEnriched then
                    if wispConfig.enriched_spring then
                        local newEnrichedSprings = API.GetAllObjArray1({wispConfig.enriched_spring}, 50, {1})
                        if #newEnrichedSprings > 0 then
                            print("Enriched spring appeared, switching...")
                            break
                        end
                    end

                    if wispConfig.enriched_wisp then
                        local newEnrichedWisps = API.GetAllObjArray1({wispConfig.enriched_wisp}, 50, {1})
                        if #newEnrichedWisps > 0 then
                            print("Enriched wisp appeared, switching...")
                            break
                        end
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

local function checkLocation(wispConfig)
    local playerX = API.PlayerCoord().x
    local playerY = API.PlayerCoord().y
    local distance = math.sqrt((playerX - wispConfig.rift_x)^2 + (playerY - wispConfig.rift_y)^2)

    if distance > 40 then
        print(string.format("WARNING: Too far from rift! Distance: %.1f (Player: %.1f, %.1f | Rift: %.1f, %.1f)",
            distance, playerX, playerY, wispConfig.rift_x, wispConfig.rift_y))
        return false
    end
    return true
end

local function getRiftLocation()
    local energyRift = API.GetAllObjArray1({87306}, 40, {12})
    if #energyRift > 0 then
        return energyRift[1].Tile_XYZ.x, energyRift[1].Tile_XYZ.y
    end

    local empoweredRift = API.GetAllObjArray1({93489}, 40, {0})
    if #empoweredRift > 0 then
        return empoweredRift[1].Tile_XYZ.x, empoweredRift[1].Tile_XYZ.y
    end

    return nil, nil
end

local function mainLoop()
    if (HATCHET_OF_DIVINITY == true) and (MEMORY_DOWSER == true) then
	print("ERROR: Invalid Config - Hatchet and Dowser both selected.")
        print("Script terminated.")
        return
    end

    local wispConfig = WISP_DATA[WISP_TYPE]
    if not wispConfig then
        print("ERROR: Invalid WISP_TYPE '" .. WISP_TYPE .. "' configured!")
        print("Script terminated.")
        return
    end

    print("Starting " .. WISP_TYPE .. " Divination script...")
    print(string.format("Configuration: Wisp Type = %s, Required Level = %d", WISP_TYPE, wispConfig.level))

    local currentLevel = API.XPLevelTable(API.GetSkillXP("DIVINATION"))
    print(string.format("Current Divination Level: %d (Required: %d)", currentLevel, wispConfig.level))
    if currentLevel < wispConfig.level then
        print(string.format("ERROR: Insufficient Divination level! You need level %d.", wispConfig.level))
        print("Script terminated.")
        return
    end

    local conversionMode = API.GetVarbitValue(40524)
    local modeText = ""
    if conversionMode == 1 then
        modeText = "Convert memories and energy into XP"
    elseif conversionMode == 0 then
        modeText = "Convert memories into XP, keep energy"
    elseif conversionMode == 2 then
        modeText = "Convert memories into energy"
    else
        modeText = "Unknown mode"
    end
    print(string.format("Conversion Mode (varbit 40524): %d - %s", conversionMode, modeText))

    local riftX, riftY = getRiftLocation()
    if riftX and riftY then
        print(string.format("Rift found at: %.1f, %.1f (Expected: %.1f, %.1f)",
            riftX, riftY, wispConfig.rift_x, wispConfig.rift_y))
    else
        print("WARNING: Could not detect rift location!")
    end

    if not checkLocation(wispConfig) then
        print("ERROR: Not at correct location for " .. WISP_TYPE .. " wisps!")
        print("Script terminated.")
        return
    end
    print("Location check passed.")
    
    if (LEAGUES == true) then
	if (HATCHET_OF_DIVINITY == true) then
    	    if not API.Container_Check_Items(94, {ID.HATCHET}) then
            	print("ERROR: Leagues - Hatchet of divinity (id = " .. ID.HATCHET .. ") not equipped!")
            	print("Script terminated.")
            	return
            end
	    print("Leagues - Hatchet of divinity equipped.")
	elseif (MEMORY_DOWSER == true) then
    	    if not API.Container_Check_Items(94, {ID.MEMORY_DOWSER}) then
            	print("ERROR: Leagues - Memory Dowser (id = " .. ID.MEMORY_DOWSER .. ") not equipped!")
            	print("Script terminated.")
            	return
            end
            print("Leagues - Memory dowser equipped.")
	else
	    manualDeposit = true
	    print("Leagues - Standard mode: Deposit memories manually.")
	    print("ERROR: Manual deposit not yet implemented!")
	    print("Script terminated.")
	    return
	end
    elseif (MEMORY_DOWSER == true) then
    	if not API.Container_Check_Items(94, {ID.MEMORY_DOWSER}) then
            print("ERROR: Memory Dowser (id = " .. ID.MEMORY_DOWSER .. ") not equipped!")
            print("Script terminated.")
            return
        end
	print("Memory dowser equipped.")
    else
	manualDeposit = true
	print("Standard mode: Deposit memories manually.")
	print("ERROR: Manual deposit not yet implemented!")
	print("Script terminated.")
	return
    end
        
    energy.start = Inventory:GetItemAmount(wispConfig.energy)
    energy.current = energy.start
    print(string.format("Starting with %d energy in inventory", energy.start))
    strands.start = API.GetVarbitValue(ID.MEMORY_VARBIT)
    strands.current = strands.start
    print(string.format("Starting with %d memory strands", strands.start))
    while API.Read_LoopyLoop() do
        if not checkLocation(wispConfig) then
            print("ERROR: Moved too far from rift location!")
            print("Script terminated.")
            break
        end

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
