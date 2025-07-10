--[[
    AURAS.lua [1.03]
	Last update: 07/10/25 by <@600408294003048450>
        * AURAS.isAuraActive() change - uses buffbar, not VB
]]

local AURAS = {}
local API   = require("api")
AURAS.noResets = false
AURAS.yourbankpin  = 0000
AURAS.refreshEarly = false

if AURAS.refreshEarly then
	AURAS.auraRefreshTime = math.random(15, 120)
else
	AURAS.auraRefreshTime = 0
end

API.Write_fake_mouse_do(false)

-- to add auraActions, find aura ID.. ex 22300 for penance
-- convert 22300 decimal to hex -> addr = 571C (verify in table penance addr == 0x571c)
-- add more mappings as needed
AURAS.auraActions = {
    oddball                 = {row=0,  addr=0x51dd, id=20957, resetTypes={1}},
    ["friend in need"]      = {row=2,  addr=0x51e3, id=20963, resetTypes={1}},
    equilibrium             = {row=23, addr=0x5716, id=22294, resetTypes={2}},
    inspiration             = {row=24, addr=0x5718, id=22296, resetTypes={2}},
    vampyrism               = {row=25, addr=0x571a, id=22298, resetTypes={2}},
    penance                 = {row=26, addr=0x571c, id=22300, resetTypes={2}},
    aegis                   = {row=28, addr=0x5969, id=22889, resetTypes={4}},
    regeneration            = {row=29, addr=0x596d, id=22893, resetTypes={3}},
    ["dark magic"]          = {row=30, addr=0x596b, id=22891, resetTypes={3}},
    berserker               = {row=31, addr=0x5971, id=22897, resetTypes={3}},
    ["ancestor spirits"]    = {row=32, addr=0x596f, id=22895, resetTypes={3}},
    reckless                = {row=93, addr=0x8bd2, id=35794, resetTypes={3}},
    maniacal                = {row=94, addr=0x8bd4, id=35796, resetTypes={3}},
    mahjarrat               = {row=113,addr=0x8d1e, id=36126, resetTypes={3}},
    ["desert pantheon"]     = {row=115,addr=0x9981, id=39297},
    ["dwarven instinct"]    = {row=117,addr=0x836e, id=33646},
    prime                   = {row=118,addr=0xcbc8, id=52168},
    resourceful             = {row=22, addr=0x5714, id=22292},
    festive                 = {row=88, addr=0x6608, id=26120},
    tracker                 = {row=36, addr=0x598f, id=22927},
    ["greater tracker"]     = {row=37, addr=0x5991, id=22929},
    ["master tracker"]      = {row=38, addr=0x5993, id=22931},
    ["supreme tracker"]     = {row=72, addr=0x5d40, id=23872},
    ["legendary tracker"]   = {row=78, addr=0x7852, id=30802},
    salvation               = {row=39, addr=0x5973, id=22899},
    ["greater salvation"]   = {row=40, addr=0x5975, id=22901},
    ["master salvation"]    = {row=41, addr=0x5977, id=22903},
    ["supreme salvation"]   = {row=54, addr=0x5d44, id=23876},
    corruption              = {row=42, addr=0x5979, id=22905},
    ["greater corruption"]  = {row=43, addr=0x597b, id=22907},
    ["master corruption"]   = {row=44, addr=0x597d, id=22909},
    ["supreme corruption"]  = {row=55, addr=0x5d42, id=23874},
    harmony                 = {row=56, addr=0x5d28, id=23848},
    ["greater harmony"]     = {row=57, addr=0x5d2a, id=23850},
    ["master harmony"]      = {row=58, addr=0x5d2c, id=23852},
    ["supreme harmony"]     = {row=59, addr=0x5d2e, id=23854},
    invigorate              = {row=60, addr=0x5d20, id=23840, resetTypes={1}},
    ["greater invigorate"]  = {row=61, addr=0x5d22, id=23842, resetTypes={2}},
    ["master invigorate"]   = {row=62, addr=0x5d24, id=23844, resetTypes={3}},
    ["supreme invigorate"]  = {row=63, addr=0x5d26, id=23846, resetTypes={4}},
    greenfingers            = {row=33, addr=0x5963, id=22883},
    ["greater greenfingers"]= {row=34, addr=0x5965, id=22885},
    ["master greenfingers"] = {row=35, addr=0x5967, id=22887},
    ["supreme greenfingers"]= {row=73, addr=0x5d46, id=23878},
    ["legendary greenfingers"] = {row=79, addr=0x7854, id=30804},
    enrichment              = {row=80, addr=0x7840, id=30784},
    ["greater enrichment"]  = {row=81, addr=0x7842, id=30786},
    ["master enrichment"]   = {row=82, addr=0x7844, id=30788},
    ["supreme enrichment"]  = {row=83, addr=0x7846, id=30790},
    ["legendary enrichment"]= {row=84, addr=0x7848, id=30792},
    brawler                 = {row=89, addr=0x8bca, id=35786, resetTypes={1}},
    ["greater brawler"]     = {row=90, addr=0x8bcc, id=35788, resetTypes={2}},
    ["master brawler"]      = {row=91, addr=0x8bce, id=35790, resetTypes={3}},
    ["supreme brawler"]     = {row=92, addr=0x8bd0, id=35792, resetTypes={4}},
    ["dedicated slayer"]    = {row=95, addr=0x8bd6, id=35798},
    ["greater dedicated slayer"] = {row=96, addr=0x8bd8, id=35800},
    ["master dedicated slayer"]  = {row=97, addr=0x8bda, id=35802},
    ["supreme dedicated slayer"]= {row=98, addr=0x8bdc, id=35804},
    ["legendary dedicated slayer"] = {row=99, addr=0x8bde, id=35806},
    ["focused siphoning"]   = {row=100,addr=0x8be0, id=35808},
    ["greater focused siphoning"] = {row=101,addr=0x8be2, id=35810},
    ["master focused siphoning"]  = {row=102,addr=0x8be4, id=35812},
    ["supreme focused siphoning"] = {row=103,addr=0x8be6, id=35814},
    ["legendary focused siphoning"]= {row=104,addr=0x8be8, id=35816},
    flameproof               = {row=105,addr=0x8bea, id=35818},
    ["greater flameproof"]   = {row=106,addr=0x8bec, id=35820},
    ["master flameproof"]    = {row=107,addr=0x8bee, id=35822},
    ["supreme flameproof"]   = {row=108,addr=0x8bf0, id=35824},
    ["legendary flameproof"] = {row=109,addr=0x8bf2, id=35826},
    ["jack of trades"]       = {row=9,  addr=0x51df, id=20959},
    ["master jack of trades"]= {row=85, addr=0x7856, id=30806},
    ["supreme jack of trades"]= {row=86, addr=0x7858, id=30808},
    ["legendary jack of trades"]= {row=110,addr=0x8bf4, id=35828},
    wisdom                   = {row=27, addr=0x571e, id=22302},
    ["supreme wisdom"]       = {row=111,addr=0x8bf6, id=35830},
    ["legendary wisdom"]     = {row=112,addr=0x8bf8, id=35832},
    ["knock out"]            = {row=3,  addr=0x51e1, id=20961, resetTypes={1}},
    ["master knock out"]     = {row=53, addr=0x5995, id=22933, resetTypes={3}},
    surefooted               = {row=6,  addr=0x51e4, id=20964},
    ["greater surefooted"]   = {row=15, addr=0x5706, id=22278},
    reverence                = {row=7,  addr=0x51e5, id=20965, resetTypes={1}},
    ["greater reverence"]    = {row=14, addr=0x5704, id=22276, resetTypes={2}},
    ["master reverence"]     = {row=52, addr=0x598d, id=22925, resetTypes={3}},
    ["supreme reverence"]    = {row=71, addr=0x5d3e, id=23870, resetTypes={4}},
    ["call of the sea"]      = {row=8,  addr=0x51e6, id=20966},
    ["greater call of the sea"] = {row=13, addr=0x5702, id=22274},
    ["master call of the sea"]  = {row=51, addr=0x598b, id=22923},
    ["supreme call of the sea"] = {row=70, addr=0x5d3c, id=23868},
    ["legendary call of the sea"] = {row=74, addr=0x784a, id=30794},
    lumberjack               = {row=16, addr=0x5708, id=22280},
    ["greater lumberjack"]   = {row=17, addr=0x570a, id=22282},
    ["master lumberjack"]    = {row=47, addr=0x5983, id=22915},
    ["supreme lumberjack"]   = {row=66, addr=0x5d34, id=23860},
    ["legendary lumberjack"]= {row=75, addr=0x784c, id=30796},
    quarrymaster             = {row=18, addr=0x570c, id=22284},
    ["greater quarrymaster"]= {row=19, addr=0x570e, id=22286},
    ["master quarrymaster"] = {row=46, addr=0x5981, id=22913},
    ["supreme quarrymaster"]= {row=65, addr=0x5d32, id=23858},
    ["legendary quarrymaster"]= {row=77, addr=0x7850, id=30800},
    ["five finger discount"]= {row=20, addr=0x5710, id=22288},
    ["greater five finger discount"] = {row=21, addr=0x5712, id=22290},
    ["master five finger discount"]  = {row=45, addr=0x597f, id=22911},
    ["supreme five finger discount"] = {row=64, addr=0x5d30, id=23856},
    ["legendary five finger discount"]= {row=76, addr=0x784e, id=30798},
    ["poison purge"]        = {row=1,  addr=0x51de, id=20958, resetTypes={1}},
    ["greater poison purge"]= {row=10, addr=0x56fc, id=22268, resetTypes={2}},
    ["master poison purge"] = {row=48, addr=0x5985, id=22917, resetTypes={3}},
    ["supreme poison purge"]= {row=67, addr=0x5d36, id=23862, resetTypes={4}},
    ["runic accuracy"]      = {row=5,  addr=0x51e2, id=20962, resetTypes={1}},
    ["greater runic accuracy"] = {row=11, addr=0x56fe, id=22270, resetTypes={2}},
    ["master runic accuracy"]  = {row=49, addr=0x5987, id=22919, resetTypes={3}},
    ["supreme runic accuracy"] = {row=68, addr=0x5d38, id=23864, resetTypes={4}},
    sharpshooter            = {row=4,  addr=0x51e7, id=20967, resetTypes={1}},
    ["greater sharpshooter"]= {row=12, addr=0x5700, id=22272, resetTypes={2}},
    ["master sharpshooter"] = {row=50, addr=0x5989, id=22921, resetTypes={3}},
    ["supreme sharpshooter"]= {row=69, addr=0x5d3a, id=23866, resetTypes={4}},
}

-- not implemented
AURAS.visAuras = {
    ["wisdom"] = true,
    ["supreme wisdom"] = true,
    ["legendary wisdom"] = true,
    ["jack of trades"] = true,
    ["master jack of trades"] = true,
    ["supreme jack of trades"] = true,
    ["legendary jack of trades"] = true
}

AURAS.noGenericAuras = {
    ["wisdom"] = true,
    ["supreme wisdom"] = true,
    ["legendary wisdom"] = true,
    ["jack of trades"] = true,
    ["master jack of trades"] = true,
    ["supreme jack of trades"] = true,
    ["legendary jack of trades"] = true,
    ["festive"] = true
}

function AURAS.verifyAuras(auraDefs)
    local mismatches = {}
    for name, aura in pairs(auraDefs) do
        if aura.addr ~= aura.id then
            print(string.format(
                "MISMATCH: '%s' -> addr=0x%X (%d)  id=%d",
                name, aura.addr, aura.addr, aura.id
            ))
            table.insert(mismatches, name)
        end
    end
    if #mismatches == 0 then
        print("[DEBUG] - All aura IDs match their hex addresses.")
    end
    return mismatches
end

function AURAS.isBackpackOpen()
	return API.VB_FindPSettinOrder(3039).state == 1
end

function AURAS.openBackpack()
    for i = 1, 3 do
	if AURAS.isBackpackOpen() then
		print(string.format("[AURA] Backpack tab opened on try %d", i))
		return true
	end
	print(string.format("[AURA] Opening Backpack tab (try %d)", i))
	API.DoAction_Interface(0xc2,0xffffffff,1,1431,0,9,API.OFF_ACT_GeneralInterface_route)
        API.RandomSleep2(math.random(600,1800), 400, 200)
    end
    error("[ERROR] Unable to open Backpack tab")
    return false
end

function AURAS.isEquipmentOpen()
	return API.VB_FindPSettinOrder(3074).state == 1
end

function AURAS.openEquipment()
    for i = 1, 3 do
	if AURAS.isEquipmentOpen() then
		print(string.format("[AURA] Equipment tab opened on try %d", i))
		return true
	end
	print(string.format("[AURA] Opening Equipment tab (try %d)", i))
        API.DoAction_Interface(0xc2, 0xffffffff, 1, 1431, 0, 10, API.OFF_ACT_GeneralInterface_route)
        API.RandomSleep2(math.random(600,1800), 400, 200)
    end
    error("[ERROR] Unable to open Equipment tab")
    return false
end

function AURAS.isAuraActive()
    return API.Bbar_ConvToSeconds(API.Buffbar_GetIDstatus(26098, false))>0
end

function AURAS.isAuraManagementOpen()
    local inter = {{1929,0,-1,0},{1929,2,-1,0},{1929,2,14,0}}
    local iface = API.ScanForInterfaceTest2Get(false, inter)[1]
    return iface.textids == "Aura Management"
end

function AURAS.openAuraWindow()
    for i = 1, 3 do
    if AURAS.isAuraManagementOpen() then
        print(string.format("[AURA] Aura Management opened on try %d", i))
        return true
    end
    print(string.format("[AURA] Opening Aura Management (try %d)", i))
        if not AURAS.isAuraActive() then
            API.DoAction_Interface(0xffffffff, 0xffffffff, 1, 1464, 15, 14, API.OFF_ACT_GeneralInterface_route)
        else
            API.DoAction_Interface(0xffffffff, API.GetEquipSlot(11).itemid1, 2, 1464, 15, 14, API.OFF_ACT_GeneralInterface_route)
        end
        API.RandomSleep2(math.random(1200, 2400), 200, 200)
    end
    error("[ERROR] Unable to open Aura Management")
    return false
end

function AURAS.selectAura(auraName)
    local mapping = AURAS.auraActions[auraName]
    if not mapping then error(string.format("[ERROR] No mapping for aura '%s'", auraName)) end

    local inter = {{1929,0,-1,0},{1929,3,-1,0},{1929,4,-1,0},{1929,72,-1,0}}
    for i = 1, 3 do
        local iface = API.ScanForInterfaceTest2Get(false, inter)[1]
        local cleaned = iface.textids:lower():gsub("%-", " ")
        if cleaned == auraName then
            print(string.format("[AURA] '%s' selected", auraName))
            return true
        end
        print(string.format("[AURA] Selecting '%s' (try %d)", auraName, i))
        API.DoAction_Interface(0xffffffff,mapping.addr,1,1929,95,mapping.row,API.OFF_ACT_GeneralInterface_route)
        API.RandomSleep2(math.random(1200,2400), 200, 200)
    end
    error(string.format("[ERROR] Unable to select '%s'", auraName))
    return false
end

function AURAS.parseVisCost(raw)
    if type(raw) ~= "string" then return nil end
    local token = raw:match("^(%S+)")
    if not token then return nil end
    local num, suffix = token:match("([%d%.]+)(%a*)")
    local n = tonumber(num)
    if not n then return nil end
    local mult = ({ K = 1e3, M = 1e6 })[suffix] or 1
    return math.floor(n * mult)
end

function AURAS.parseAvailableVis()
    local inter = {
        {1929,0,-1,0},{1929,3,-1,0},{1929,4,-1,0},
        {1929,30,-1,0},{1929,53,-1,0},{1929,56,-1,0},
    }
    local raw = API.ScanForInterfaceTest2Get(false, inter)[1].textids
    local avail = AURAS.parseVisCost(raw)
    if not avail then
        print("[AURA] ERROR: Unable to parse available Vis -> aborting extension")
        return nil
    end
    print(string.format("[AURA] Total Vis = %d", avail))
    return avail
end

function AURAS.getResetCounts()
    local scans = {
        { key = "genericResets", label = "generic resets", expected = 42661, pattern = {
            {1929,0,-1,0},{1929,3,-1,0},{1929,4,-1,0},{1929,20,-1,0},{1929,21,-1,0},{1929,22,-1,0},
        }},
        { key = "tier1Resets",  label = "tier 1 resets",  expected = 31847, pattern = {
            {1929,0,-1,0},{1929,3,-1,0},{1929,4,-1,0},{1929,20,-1,0},{1929,21,-1,0},{1929,23,-1,0},
        }},
        { key = "tier2Resets",  label = "tier 2 resets",  expected = 31848, pattern = {
            {1929,0,-1,0},{1929,3,-1,0},{1929,4,-1,0},{1929,20,-1,0},{1929,21,-1,0},{1929,24,-1,0},
        }},
        { key = "tier3Resets",  label = "tier 3 resets",  expected = 31849, pattern = {
            {1929,0,-1,0},{1929,3,-1,0},{1929,4,-1,0},{1929,20,-1,0},{1929,21,-1,0},{1929,25,-1,0},
        }},
        { key = "tier4Resets",  label = "tier 4 resets",  expected = 31850, pattern = {
            {1929,0,-1,0},{1929,3,-1,0},{1929,4,-1,0},{1929,20,-1,0},{1929,21,-1,0},{1929,26,-1,0},
        }},
        { key = "exactVis",     label = "exact vis",      expected = 32092, pattern = {
            {1929,0,-1,0},{1929,3,-1,0},{1929,4,-1,0},{1929,20,-1,0},{1929,21,-1,0},{1929,27,-1,0},
        }},
    }

    local resetCounts = {}
    for _, scan in ipairs(scans) do
        local iface = API.ScanForInterfaceTest2Get(false, scan.pattern)[1]
        if iface and iface.itemid1 == scan.expected then
            resetCounts[scan.key] = iface.itemid1_size
        else
            resetCounts[scan.key] = 0
        end
    end
    return resetCounts
end

function AURAS.getAuraResetCount(auraName, useGeneric)
    local action = AURAS.auraActions[auraName]
    local counts = AURAS.getResetCounts()
    print("[DEBUG] getAuraResetCount for", auraName)
    print("[DEBUG]  resetTypes:", action and (table.concat(action.resetTypes or {}, ",")) or "<no mapping>")
    print(string.format(
        "[DEBUG]  counts: generic=%d, t1=%d, t2=%d, t3=%d, t4=%d",
        counts.genericResets, counts.tier1Resets, counts.tier2Resets, counts.tier3Resets, counts.tier4Resets
    ))

    if API.IsPremiumMember() and API.IsAuraResetAvailable() then
        return 1, "premier"
    end

    if action and action.resetTypes then
        local tiers = {table.unpack(action.resetTypes)}
        table.sort(tiers)
        for _, t in ipairs(tiers) do
            local cnt = counts["tier" .. t .. "Resets"] or 0
            print(string.format("[DEBUG]  checking tier %d -> %d resets", t, cnt))
            if cnt > 0 then
                return cnt, t
            end
        end
    end

    if useGeneric and not AURAS.noGenericAuras[auraName] then
        print("[DEBUG]  genericResets available:", counts.genericResets)
        if counts.genericResets > 0 then
            return counts.genericResets, 0
        end
    end

    print("[DEBUG] No resets found for: ", auraName)
    return 0, nil
end

function AURAS.maybeEnterPin()
    if API.VB_FindPSettinOrder(2874).state == 18 then
        print("[PIN] PIN window detected -> entering PIN")
        API.DoBankPin(AURAS.yourbankpin)
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

function AURAS.extensionLogic()
    API.RandomSleep2(math.random(1200,2400),200,200)
    local avail = AURAS.parseAvailableVis()
    if not avail then return end

    local interLong  = {{1929,0,-1,0},{1929,3,-1,0},{1929,4,-1,0},{1929,30,-1,0},{1929,32,-1,0},{1929,51,-1,0}}
    local rawLong    = API.ScanForInterfaceTest2Get(false, interLong)[1].textids
    local costLong   = AURAS.parseVisCost(rawLong)
    if not costLong then
        print("[AURA] ERROR: Unable to parse long-extension cost -> skipping")
        return
    end

    local interShort = {{1929,0,-1,0},{1929,3,-1,0},{1929,4,-1,0},{1929,30,-1,0},{1929,32,-1,0},{1929,52,-1,0}}
    local rawShort   = API.ScanForInterfaceTest2Get(false, interShort)[1].textids
    local costShort  = AURAS.parseVisCost(rawShort)
    if not costShort then
        print("[AURA] ERROR: Unable to parse short-extension cost -> skipping")
        return
    end

    if costLong <= avail then
        print(string.format("[AURA] Extending long duration (%d Vis)", costLong))
        API.DoAction_Interface(0x24, 0xffffffff, 1, 1929, 38, -1, API.OFF_ACT_GeneralInterface_route)
        API.RandomSleep2(math.random(1200,2400),200,200)
        AURAS.maybeEnterPin()

    elseif costShort <= avail then
        print(string.format("[AURA] Extending short duration (%d Vis)", costShort))
        API.DoAction_Interface(0x24, 0xffffffff, 1, 1929, 47, -1, API.OFF_ACT_GeneralInterface_route)
        API.RandomSleep2(math.random(1200,2400),200,200)
        AURAS.maybeEnterPin()

    else
        API.RandomSleep2(math.random(1200,2400),200,200)
        print("[AURA] Not enough Vis to extend the aura")
        API.RandomSleep2(math.random(1200,2400),200,200)
    end
end

function AURAS.activateLoop()
    for i = 1, 3 do
        print(string.format("[AURA] Activation attempt %d...", i))
        API.DoAction_Interface(0x24, 0xffffffff, 1, 1929, 16, -1, API.OFF_ACT_GeneralInterface_route)
        API.RandomSleep2(math.random(1200,2400),200,200)
        local buff = API.Buffbar_GetIDstatus(26098, false)
        if buff and buff.found and AURAS.isAuraActive() then
            print(string.format("[AURA] Aura activated on attempt %d", i))
            return true
        end
    end
    print("[ERROR] Aura failed to activate after 3 attempts")
    return false
end

function AURAS.performReset(auraName, resets, resetType)
    resets = resets or 0
    print(string.format(
        "[DEBUG] performReset called for aura=%s, resetType=%s, resetsRemaining=%s",
        auraName, tostring(resetType), tostring(resets)
    ))

    for attempt = 1, 3 do
        local state = API.VB_FindPSettinOrder(2874).state
        print(string.format("[DEBUG] VB_FindPSettinOrder(2874).state = %s", tostring(state)))

        if state == 12 then
            print("[DEBUG] Confirmation dialog detected -> confirming reset")
            API.DoAction_Interface(
                0xffffffff, 0xffffffff, 0,
                1188, 8, -1,
                API.OFF_ACT_GeneralInterface_Choose_option
            )
            API.RandomSleep2(math.random(1200,2400), 200, 200)
            print("[DEBUG] performReset -> successful")
            return true
        end

        print(string.format("[DEBUG] Reset attempt (%d/3)", attempt))
        if resetType == "premier" then
            print(string.format("[DEBUG] Clicking Premier reset for %s (resets left: %s)", auraName, resets))
            API.DoAction_Interface(0xffffffff, 0xadb9, 1, 1929, 28, -1, API.OFF_ACT_GeneralInterface_route)

        elseif resetType == 0 then
            print(string.format("[DEBUG] Clicking Generic reset for %s (resets left: %s)", auraName, resets))
            API.DoAction_Interface(0xffffffff, 0xa6a5, 1, 1929, 22, -1, API.OFF_ACT_GeneralInterface_route)

        elseif type(resetType) == "number" and resetType >= 1 and resetType <= 4 then
            print(string.format("[DEBUG] Clicking Tier %s reset for %s (resets left: %s)", resetType, auraName, resets))
            local addrMap = { [1]=0x7c67, [2]=0x7c68, [3]=0x7c69, [4]=0x7c6a }
            API.DoAction_Interface(0xffffffff, addrMap[resetType], 1, 1929, 22 + resetType, -1, API.OFF_ACT_GeneralInterface_route)

        else
            print(string.format("[DEBUG] Unknown resetType=%s for aura=%s", tostring(resetType), auraName))
            return false
        end

        API.RandomSleep2(math.random(1200,2400), 200, 200)
    end

    print(string.format("[DEBUG] performReset failed after 3 attempts for aura=%s", auraName))
    return false
end

function AURAS.deactivateAura()
    for i = 1, 3 do
        print(string.format("[AURA] Deactivation attempt %d...", i))
	API.RandomSleep2(math.random(600,1800),200,200)
	API.DoAction_Interface(0x24,0xffffffff,1,1929,16,-1,API.OFF_ACT_GeneralInterface_route)
	API.RandomSleep2(math.random(1200,2400),200,200)

	local state = API.VB_FindPSettinOrder(2874).state
        print(string.format("[DEBUG] VB_FindPSettinOrder(2874).state = %s", tostring(state)))
	
        if state == 12 then
            print("[DEBUG] Confirmation dialog detected -> confirming deactivate")
	    API.DoAction_Interface(0xffffffff,0xffffffff,0,1188,8,-1,API.OFF_ACT_GeneralInterface_Choose_option)
	    API.RandomSleep2(math.random(1200,2400),200,200)
      	    print("[DEBUG] performDeactivate -> successful")
        end
	
        local buff = API.Buffbar_GetIDstatus(26098, false)
        if not buff.found and not AURAS.isAuraActive() then
            print(string.format("[AURA] Aura deactivated on attempt %d", i))
            return true
        end
    end
    print("[DEBUG] Aura failed to deactivate after 3 attempts")
    return false
end

function AURAS.manageAura(rawInput)

    local bad = AURAS.verifyAuras(AURAS.auraActions)
    if #bad > 0 then
        error("Found mismatched auras: " .. table.concat(bad, ", "))
    end

    local function normalize(name)
        return name:lower():gsub("%-", " ")
    end

    local auraName = normalize(rawInput)
    local mapping = AURAS.auraActions[auraName]
    if not mapping then
        error(string.format("[ERROR] No mapping for aura '%s'", auraName))
	return false
    end

    if not AURAS.openEquipment() then 
	error("[ERROR] - Failed to open the equipment tab")
	return false 
    end

    if not AURAS.openAuraWindow() then
	error("[ERROR] - Failed to open the aura management tab") 
        return false 
    end

    if not AURAS.selectAura(auraName) then 
	error("[ERROR] - Failed to select the correct aura")
        return false 
    end

    local counts = AURAS.getResetCounts()

    local ownedBox = {
        {1929,0,-1,0},{1929,3,-1,0},{1929,4,-1,0},
        {1929,6,-1,0},{1929,11,-1,0},{1929,18,-1,0},
        {1929,19,-1,0}
    }
    local ownedStatus = API.ScanForInterfaceTest2Get(false, ownedBox)[1].textids
    print(string.format("[AURA] Owned status: %s", ownedStatus))

    if ownedStatus == "Buy" then
        error(string.format("[AURA] '%s' not available to use -> aborting", auraName))
        return false

    elseif ownedStatus == "Deactivate" then
        if not AURAS.deactivateAura() then
		error(string.format("[ERROR] '%s': failed to deactivate", auraName))
		return false
	end
    end

    local interStatus = {{1929,0,-1,0},{1929,3,-1,0},{1929,4,-1,0},{1929,74,-1,0}}
    local status = API.ScanForInterfaceTest2Get(false, interStatus)[1].textids

    if status == "Currently active" then
        print(string.format("[AURA] '%s' already active", auraName))
        return true

    elseif status == "Ready to use" then
        print(string.format("[AURA] '%s' ready to activate", auraName))
        AURAS.extensionLogic()
        return AURAS.activateLoop()

    elseif status == "Currently recharging" then
        print(string.format("[AURA] '%s' recharging -> resetting", auraName))
        local resets, usedType = AURAS.getAuraResetCount(auraName, true)
        if resets and resets > 0 then
            if AURAS.performReset(auraName, resets, usedType) then
                AURAS.extensionLogic()
                return AURAS.activateLoop()
            else
                error("[DEBUG] - Failed to reset aura")
                return false
            end
        else
	    AURAS.noResets = true
            print("[DEBUG] - No valid resets for aura: " .. auraName)
            return true
        end

    else
        error(string.format("[ERROR] Unhandled status '%s'", status))
        return false
    end
end

function AURAS.activateAura(auraName)
    if not AURAS.noResets then

    	print(string.format("[AURA] Starting activation for aura '%s'", auraName))
    	local ok = AURAS.manageAura(auraName)
    	print(string.format("[AURA] manageAura returned: %s", tostring(ok)))

	if ok then
		print(string.format("[DEBUG] manageAura success for '%s'", auraName))
		if AURAS.refreshEarly then
			AURAS.auraRefreshTime = math.random(15, 120)	-- reset the time to refresh the aura
		end
    	else
        	print(string.format("[DEBUG] manageAura failed for '%s', aborting activation.", auraName))
		API.Write_LoopyLoop(false) -- issue detected
    	end
    --else
	--print("[DEBUG] - No valid resets found for: ".. auraName)
    end

    if AURAS.isAuraManagementOpen() then
	print("[AURA] Attempting to close interface...")
        local closed = API.DoAction_Interface(0x24, 0xffffffff, 1, 1929, 167, -1, API.OFF_ACT_GeneralInterface_route)
        print(string.format("[AURA] Close aura interface returned: %s", tostring(closed)))
        if closed then
        	API.RandomSleep2(math.random(1200,2400), 200, 200)
            	print("[DEBUG] Aura interface closed and delay complete")
       	else
            	print("[ERROR] Failed to close aura management interface")
            	API.Write_LoopyLoop(false)
        end
    end
end

function AURAS.auraTimeRemaining()
    local status = API.Buffbar_GetIDstatus(26098, false)
    local found  = status and status.found
    return found and API.Bbar_ConvToSeconds(status) or 0
end

function AURAS.pin(bankPin)
    AURAS.yourbankpin = bankPin
    return AURAS
end

return AURAS

--[[
    AURAS.lua
    Permission is hereby granted, free of charge, to any person obtaining a copy
    of this software and associated documentation files to use them
    without restriction, including without limitation to the rights
    to use, copy, modify, merge, publish, and distribute. 
]]
