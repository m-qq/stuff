local API      	 	= require("api")

API.Write_fake_mouse_do(false)
API.SetDrawLogs(true)
API.SetDrawTrackedSkills(true)
API.SetMaxIdleTime(9)

local pendingManifestedKnowledge = false
local manifestedKnowledgeTime = 0
local pendingSerenSpirit = false
local serenSpiritTime = 0
local pendingCatalyst = false
local catalystTime = 0
local COMPACTED_ITEMS = {
    47933, -- Compacted vines
    47937, -- Compacted clay
    47932, -- Compacted wood
    47936, -- Compacted stone
    47935  -- Compacted hides
}
local COSMIC_RUNE_ID = 564    -- Cosmic runes
local TIME_RUNE_ID = 58450    -- Time runes
local waitingForTimeInterface = false
local waitingForContributionConfirm = false
local lastStatus = ""
local lastMixingAnimationTime = 0
local sessionStartTime = API.ScriptRuntime()
local compactedItemsSent = 0
local timeAdvancementCount = 0
local contributionsCount = 0
local mixingCycles = 0
local randomSpawnsCollected = {
    manifestedKnowledge = 0,
    serenSpirit = 0,
    catalyst = 0
}

local function checkRandomSpawns()
    local currentTime = API.ScriptRuntime()

    if pendingManifestedKnowledge and currentTime >= manifestedKnowledgeTime then
        print("Interacting with Manifested knowledge")
        Interact:NPC("Manifested knowledge", "Siphon", 30)
        pendingManifestedKnowledge = nil
        manifestedKnowledgeTime = 0
        randomSpawnsCollected.manifestedKnowledge = randomSpawnsCollected.manifestedKnowledge + 1
        return true
    end

    if pendingSerenSpirit and currentTime >= serenSpiritTime then
        print("Interacting with Seren spirit")
        Interact:NPC("Seren spirit", "Capture", 30)
        pendingSerenSpirit = nil
        serenSpiritTime = 0
        randomSpawnsCollected.serenSpirit = randomSpawnsCollected.serenSpirit + 1
        return true
    end

    if pendingCatalyst and currentTime >= catalystTime then
        print("Interacting with Catalyst of alteration")
        Interact:NPC("Catalyst of alteration", "Capture", 30)
        pendingCatalyst = nil
        catalystTime = 0
        randomSpawnsCollected.catalyst = randomSpawnsCollected.catalyst + 1
        return true
    end

    if not pendingManifestedKnowledge then
        local manifestedKnowledge = API.GetAllObjArray1({23855}, 30, {1})
        for _, obj in ipairs(manifestedKnowledge) do
            local delay = math.random(10, 50) / 10 
            manifestedKnowledgeTime = currentTime + delay
            pendingManifestedKnowledge = true
            print(string.format("Found Manifested knowledge - will interact in %.1fs", delay))
            break
        end
    end

    if not pendingSerenSpirit then
        local serenSpirit = API.GetAllObjArray1({26022}, 30, {1})
        for _, obj in ipairs(serenSpirit) do
            local delay = math.random(10, 50) / 10 
            serenSpiritTime = currentTime + delay
            pendingSerenSpirit = true
            print(string.format("Found Seren spirit - will interact in %.1fs", delay))
            break
        end
    end

    if not pendingCatalyst then
        local catalyst = API.GetAllObjArray1({28411}, 30, {1})
        for _, obj in ipairs(catalyst) do
            local delay = math.random(10, 50) / 10
            catalystTime = currentTime + delay
            pendingCatalyst = true
            print(string.format("Found Catalyst of alteration - will interact in %.1fs", delay))
            break
        end
    end

    return false
end

local function validateGameState()
    if API.GetLocalPlayerAddress() == 0 or API.GetGameState2() ~= 3 then
        print("Bad game state")
        API.Write_LoopyLoop(false)
        return false
    end
    return true
end

local function validatePlayerLocation()
    local playerPos = API.PlayerCoord()
    if playerPos.x < 11577 or playerPos.x > 11578 or playerPos.y < 6203 or playerPos.y > 6205 then
        print("Player not in valid herb area")
        API.Write_LoopyLoop(false)
        return false
    end
    return true
end

local function checkAndSendCompactedItems()
    local foundItems = false
    local itemCount = 0

    for _, itemId in ipairs(COMPACTED_ITEMS) do
        if Inventory:GetItemAmount(itemId) > 0 then
            print(string.format("Found compacted item (ID: %d), sending to camp", itemId))
            API.DoAction_Inventory1(itemId, 0, 1, API.OFF_ACT_GeneralInterface_route)
            API.RandomSleep2(1500, 500, 200) -- Wait for interaction
            foundItems = true
            itemCount = itemCount + 1
        end
    end

    if foundItems then
        print(string.format("Sent %d compacted item(s) to camp, resuming mixing tinctures", itemCount))
        compactedItemsSent = compactedItemsSent + itemCount
        mixingCycles = mixingCycles + 1
        Interact:Object("Apothecary", "Mix tinctures", 10)
        API.RandomSleep2(2000, 500, 200) -- Wait for mixing to start
        return true
    end

    return false
end

local function hasEnoughRunesForAdvanceTime()
    local cosmicRunes = Inventory:GetItemAmount(COSMIC_RUNE_ID) or 0
    local timeRunes = Inventory:GetItemAmount(TIME_RUNE_ID) or 0
    return cosmicRunes > 15 and timeRunes > 20
end

local function castAdvanceTime()
    if not hasEnoughRunesForAdvanceTime() then
        print("Not enough runes for Advance Time spell")
        return false
    end

    print("Casting Advance Time spell")
    API.DoAction_Ability("Advance Time", 1, API.OFF_ACT_GeneralInterface_route)
    waitingForTimeInterface = true
    timeAdvancementCount = timeAdvancementCount + 1
    return true
end

local function handleTimeInterface()
    if not waitingForTimeInterface then
        return false
    end

    local interface = API.ScanForInterfaceTest2Get(false, {{720,2,-1,0}, {720,16,-1,0}, {720,7,-1,0}, {720,27,-1,0}})
    if interface and interface[1] and interface[1].textids == "4. Anachronia base camp - Advance time by one day." then
        print("Found time advancement interface, selecting Anachronia base camp")
        API.KeyboardPress2(string.byte("4"), 60, 100)
        waitingForTimeInterface = false
        API.RandomSleep2(2000, 500, 200) 

        print("Contributing all resources to Apothecary")
        Interact:NPC("Apothecary", "Contribute all resources", 10)
        waitingForContributionConfirm = true
        API.RandomSleep2(2000, 500, 200)
        return true
    end

    return false
end

local function handleContributionConfirmation()
    if not waitingForContributionConfirm then
        return false
    end

    local interface = API.ScanForInterfaceTest2Get(false, {{1188,5,-1,0}, {1188,2,-1,0}, {1188,0,-1,0}, {1188,8,-1,0}, {1188,12,-1,0}, {1188,6,-1,0}})
    if interface and interface[1] then
        local text = interface[1].textids
        if text == "Yes." or text == "Yes. :" or text == "Yes.:" then
            print("Found contribution confirmation, confirming with key 1")
            API.KeyboardPress2(string.byte("1"), 60, 100) -- Send key "1"
            waitingForContributionConfirm = false
            contributionsCount = contributionsCount + 1
            API.RandomSleep2(2000, 500, 200) -- Wait for confirmation
            return true
        end
    end

    return false
end

local function calculateRemainingCasts()
    local cosmicRunes = Inventory:GetItemAmount(COSMIC_RUNE_ID) or 0
    local timeRunes = Inventory:GetItemAmount(TIME_RUNE_ID) or 0
    local maxCastsFromCosmic = math.floor(cosmicRunes / 15)
    local maxCastsFromTime = math.floor(timeRunes / 20)

    return math.min(maxCastsFromCosmic, maxCastsFromTime)
end

local function checkMixingAnimation()
    local currentTime = API.ScriptRuntime()
    local playerAnim = API.ReadPlayerAnim()

    if playerAnim == 17097 then
        lastMixingAnimationTime = currentTime
        return true
    end

    return (currentTime - lastMixingAnimationTime) <= 10
end

local function displayMetrics()
    local currentTime = API.ScriptRuntime()
    local xpLeftRaw = API.GetVarbitValue(51159) or 0
    local xpLeft = xpLeftRaw * 16  -- Apply 16x multiplier for actual XP
    local remainingCasts = calculateRemainingCasts()
    local cosmicRunes = Inventory:GetItemAmount(COSMIC_RUNE_ID) or 0
    local timeRunes = Inventory:GetItemAmount(TIME_RUNE_ID) or 0

    local metrics = {
        { "Iaia Mixer" },
        { "", "" },
        { "Runtime:", API.ScriptRuntimeString() },
        { "Status:", lastStatus ~= "" and lastStatus or "Starting..." },
        { "", "" },
        { "XP & Resources:", "" },
        { "- XP Left:", string.format("%d", xpLeft) },
        { "- Cosmic Runes:", string.format("%d", cosmicRunes) },
        { "- Time Runes:", string.format("%d", timeRunes) },
        { "- Casts Remaining:", string.format("%d", remainingCasts) }
    }

    local hasStats = mixingCycles > 0 or compactedItemsSent > 0 or timeAdvancementCount > 0 or contributionsCount > 0
    if hasStats then
        table.insert(metrics, { "", "" })
        table.insert(metrics, { "Session Statistics:", "" })

        if mixingCycles > 0 then
            table.insert(metrics, { "- Mixing Cycles:", string.format("%d", mixingCycles) })
        end
        if compactedItemsSent > 0 then
            table.insert(metrics, { "- Items Sent:", string.format("%d", compactedItemsSent) })
        end
        if timeAdvancementCount > 0 then
            table.insert(metrics, { "- Time Advances:", string.format("%d", timeAdvancementCount) })
        end
        if contributionsCount > 0 then
            table.insert(metrics, { "- Contributions:", string.format("%d", contributionsCount) })
        end
    end

    local hasSpawns = randomSpawnsCollected.manifestedKnowledge > 0 or randomSpawnsCollected.serenSpirit > 0 or randomSpawnsCollected.catalyst > 0
    if hasSpawns then
        table.insert(metrics, { "", "" })
        table.insert(metrics, { "Random Spawns:", "" })

        if randomSpawnsCollected.manifestedKnowledge > 0 then
            table.insert(metrics, { "- Manifested Knowledge:", string.format("%d", randomSpawnsCollected.manifestedKnowledge) })
        end
        if randomSpawnsCollected.serenSpirit > 0 then
            table.insert(metrics, { "- Seren Spirit:", string.format("%d", randomSpawnsCollected.serenSpirit) })
        end
        if randomSpawnsCollected.catalyst > 0 then
            table.insert(metrics, { "- Catalyst:", string.format("%d", randomSpawnsCollected.catalyst) })
        end
    end

    API.DrawTable(metrics)
end

while API.Read_LoopyLoop() do

	if not validateGameState() or not validatePlayerLocation() then
		return
	end

	checkRandomSpawns()

	if handleTimeInterface() then
		API.RandomSleep2(150, 50, 25)
		goto continue
	end

	if handleContributionConfirmation() then
		API.RandomSleep2(150, 50, 25)
		goto continue
	end

	if checkAndSendCompactedItems() then
		API.RandomSleep2(150, 50, 25)
		goto continue
	end

	if API.GetVarbitValue(51159) > 0 then
		checkMixingAnimation() -- Update animation tracking
		local isActuallyMixing = checkMixingAnimation()

		local currentStatus
		if isActuallyMixing then
			currentStatus = "Mixing tinctures"
		else
			currentStatus = "Should be mixing - no animation detected!"
		end

		if lastStatus ~= currentStatus then
			print(currentStatus)
			lastStatus = currentStatus
		end

		if not isActuallyMixing then
			print("Attempting to restart mixing - no animation for 10+ seconds")
			Interact:Object("Apothecary", "Mix tinctures", 10)
			API.RandomSleep2(2000, 500, 200)
		end
	else
		local currentStatus = "No XP left, attempting to advance time"
		if lastStatus ~= currentStatus then
			print(currentStatus)
			lastStatus = currentStatus
		end
		if not castAdvanceTime() then
			local errorStatus = "Cannot advance time - insufficient runes or other issue"
			if lastStatus ~= errorStatus then
				print(errorStatus)
				lastStatus = errorStatus
			end
		end
	end

	::continue::
	displayMetrics()
	API.RandomSleep2(150, 50, 25)
end
