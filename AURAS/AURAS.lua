--[[
    AURAS.lua [1.1b]
	Last update: 08/19/25 by <@600408294003048450>
        * sequencing system for multiple auras
	* refresh aura interface if time info was not available
	* AURAS.activateAura({"aura1", "aura2"}, false, false)
	* or AURAS.activateAura("aura1") -- defaults to autoExtend = true, autoReset = true
	* autoExtend / autoReset are optional parameters	
	* make sure to initialize bank pin via AURAS.pin(1234) (using your real bank pin) if a bank pin is present
]]

local AURAS = {}
local API   = require("api")
AURAS.noResets = false  		-- do not change this
AURAS.yourbankpin  = 0000 		-- set this value from your script using AURAS.pin(1234)
AURAS.refreshEarly = false 		-- can modify for early refreshing aura, not typically recommended

AURAS.minRefresh = 15  			-- settings related to refreshEarly, not used by default
AURAS.maxRefresh = 120

if AURAS.refreshEarly then
    AURAS.auraRefreshTime = math.random(AURAS.minRefresh, AURAS.maxRefresh)
else
    AURAS.auraRefreshTime = 0
end

AURAS.currentSequence = {}        	-- stores active aura sequence
AURAS.currentSequenceIndex = 1    	-- tracks position in sequence
AURAS.isSequenceMode = false      	-- flag indicating sequence vs single aura mode

AURAS.auraLastUsed = {}           	-- timestamp when each aura was last activated
AURAS.sequenceExhausted = false   	-- flag to prevent infinite sequence cycling

AURAS.auraCooldownCache = {}      	-- stores actual cooldown values from interface
AURAS.auraCooldownTimestamp = {}  	-- stores when each cooldown was cached

AURAS.sequenceNextCheckTime = 0   	-- timestamp when sequence should next be checked
AURAS.sequenceShortestCooldown = 0 	-- shortest cooldown found in last sequence check

AURAS.nextActivationTime = 0      	-- when any aura/sequence can next be checked
AURAS.currentWaitingAura = ""     	-- which aura we're waiting for (for single mode)
AURAS.isWaiting = false           	-- flag indicating we're in a wait state

AURAS.interfacesOpened = false    	-- flag to track if equipment/aura interfaces are already open

AURAS.nextReadyCheckTime = 0      	-- when to next check for ready auras
AURAS.lastFoundReadyAura = nil    	-- cache the last aura found ready by isAnyAuraReady

API.Write_fake_mouse_do(false)  	-- can remove if you call this in your script

-- new param: cd = cooldown of the aura (in seconds), includes active time + cooldown
AURAS.auraActions = {
    ["friend in need"]      		= {row=2,  addr=0x51e3, id=20963, resetTypes={1}, cd=912},
    equilibrium             		= {row=23, addr=0x5716, id=22294, resetTypes={2}, cd=21600},
    inspiration             		= {row=24, addr=0x5718, id=22296, resetTypes={2}, cd=14400},
    vampyrism               		= {row=25, addr=0x571a, id=22298, resetTypes={2}, cd=14400},
    penance                 		= {row=26, addr=0x571c, id=22300, resetTypes={2}, cd=14400},
    aegis                   		= {row=28, addr=0x5969, id=22889, resetTypes={4}, cd=19800},
    regeneration            		= {row=29, addr=0x596d, id=22893, resetTypes={3}, cd=14400},
    ["dark magic"]          		= {row=30, addr=0x596b, id=22891, resetTypes={3}, cd=14400},
    berserker               		= {row=31, addr=0x5971, id=22897, resetTypes={3}, cd=19800},
    ["ancestor spirits"]    		= {row=32, addr=0x596f, id=22895, resetTypes={3}, cd=19800},
    reckless               		= {row=93, addr=0x8bd2, id=35794, resetTypes={3}, cd=19800},
    maniacal                		= {row=94, addr=0x8bd4, id=35796, resetTypes={3}, cd=19800},
    mahjarrat               		= {row=113,addr=0x8d1e, id=36126, resetTypes={3}, cd=86400},
    ["dwarven instinct"]    		= {row=117,addr=0x836e, id=33646, cd=86400},
    prime                   		= {row=118,addr=0xcbc8, id=52168, cd=86400},
    resourceful            		= {row=22, addr=0x5714, id=22292, cd=14400},
    festive                 		= {row=88, addr=0x6608, id=26120, cd=86400},

    tracker                 		= {row=36, addr=0x598f, id=22927, cd=14400},
    ["greater tracker"]     		= {row=37, addr=0x5991, id=22929, cd=14400},
    ["master tracker"]      		= {row=38, addr=0x5993, id=22931, cd=14400},
    ["supreme tracker"]     		= {row=72, addr=0x5d40, id=23872, cd=14400},
    ["legendary tracker"]   		= {row=78, addr=0x7852, id=30802, cd=14400},

    salvation               		= {row=39, addr=0x5973, id=22899, cd=14400},
    ["greater salvation"]   		= {row=40, addr=0x5975, id=22901, cd=14400},
    ["master salvation"]    		= {row=41, addr=0x5977, id=22903, cd=14400},
    ["supreme salvation"]   		= {row=54, addr=0x5d44, id=23876, cd=14400},

    corruption              		= {row=42, addr=0x5979, id=22905, cd=14400},
    ["greater corruption"]  		= {row=43, addr=0x597b, id=22907, cd=14400},
    ["master corruption"]   		= {row=44, addr=0x597d, id=22909, cd=14400},
    ["supreme corruption"]  		= {row=55, addr=0x5d42, id=23874, cd=14400},

    harmony                 		= {row=56, addr=0x5d28, id=23848, cd=14400},
    ["greater harmony"]     		= {row=57, addr=0x5d2a, id=23850, cd=14400},
    ["master harmony"]      		= {row=58, addr=0x5d2c, id=23852, cd=14400},
    ["supreme harmony"]     		= {row=59, addr=0x5d2e, id=23854, cd=14400},

    invigorate              		= {row=60, addr=0x5d20, id=23840, resetTypes={1}, cd=14400},
    ["greater invigorate"]  		= {row=61, addr=0x5d22, id=23842, resetTypes={2}, cd=14400},
    ["master invigorate"]   		= {row=62, addr=0x5d24, id=23844, resetTypes={3}, cd=14400},
    ["supreme invigorate"]  		= {row=63, addr=0x5d26, id=23846, resetTypes={4}, cd=14400},

    greenfingers            		= {row=33, addr=0x5963, id=22883, cd=4800},
    ["greater greenfingers"]		= {row=34, addr=0x5965, id=22885, cd=4800},
    ["master greenfingers"] 		= {row=35, addr=0x5967, id=22887, cd=4800},
    ["supreme greenfingers"]		= {row=73, addr=0x5d46, id=23878, cd=4800},
    ["legendary greenfingers"] 		= {row=79, addr=0x7854, id=30804, cd=4800},

    enrichment              		= {row=80, addr=0x7840, id=30784, cd=14400},
    ["greater enrichment"]  		= {row=81, addr=0x7842, id=30786, cd=14400},
    ["master enrichment"]   		= {row=82, addr=0x7844, id=30788, cd=14400},
    ["supreme enrichment"]  		= {row=83, addr=0x7846, id=30790, cd=14400},
    ["legendary enrichment"]		= {row=84, addr=0x7848, id=30792, cd=14400},

    brawler                 		= {row=89, addr=0x8bca, id=35786, resetTypes={1}, cd=14400},
    ["greater brawler"]     		= {row=90, addr=0x8bcc, id=35788, resetTypes={2}, cd=14400},
    ["master brawler"]     		= {row=91, addr=0x8bce, id=35790, resetTypes={3}, cd=14400},
    ["supreme brawler"]     		= {row=92, addr=0x8bd0, id=35792, resetTypes={4}, cd=14400},

    ["dedicated slayer"]    		= {row=95, addr=0x8bd6, id=35798, cd=14400},
    ["greater dedicated slayer"]	= {row=96, addr=0x8bd8, id=35800, cd=14400},
    ["master dedicated slayer"] 	= {row=97, addr=0x8bda, id=35802, cd=14400},
    ["supreme dedicated slayer"]	= {row=98, addr=0x8bdc, id=35804, cd=14400},
    ["legendary dedicated slayer"] 	= {row=99, addr=0x8bde, id=35806, cd=14400},

    ["focused siphoning"]   		= {row=100,addr=0x8be0, id=35808, cd=14400},
    ["greater focused siphoning"] 	= {row=101,addr=0x8be2, id=35810, cd=14400},
    ["master focused siphoning"]  	= {row=102,addr=0x8be4, id=35812, cd=14400},
    ["supreme focused siphoning"] 	= {row=103,addr=0x8be6, id=35814, cd=14400},
    ["legendary focused siphoning"]	= {row=104,addr=0x8be8, id=35816, cd=14400},

    flameproof               		= {row=105,addr=0x8bea, id=35818, cd=14400},
    ["greater flameproof"]   		= {row=106,addr=0x8bec, id=35820, cd=14400},
    ["master flameproof"]    		= {row=107,addr=0x8bee, id=35822, cd=14400},
    ["supreme flameproof"]   		= {row=108,addr=0x8bf0, id=35824, cd=14400},
    ["legendary flameproof"] 		= {row=109,addr=0x8bf2, id=35826, cd=14400},

    ["jack of trades"]       		= {row=9,  addr=0x51df, id=20959, cd=86400},
    ["master jack of trades"]		= {row=85, addr=0x7856, id=30806, cd=86400},
    ["supreme jack of trades"]		= {row=86, addr=0x7858, id=30808, cd=86400},
    ["legendary jack of trades"]	= {row=110,addr=0x8bf4, id=35828, cd=86400},

    wisdom                   		= {row=27, addr=0x571e, id=22302, cd=86400},
    ["supreme wisdom"]       		= {row=111,addr=0x8bf6, id=35830, cd=86400},
    ["legendary wisdom"]     		= {row=112,addr=0x8bf8, id=35832, cd=86400},

    ["knock out"]            		= {row=3,  addr=0x51e1, id=20961, resetTypes={1}, cd=18000},
    ["master knock out"]     		= {row=53, addr=0x5995, id=22933, resetTypes={3}, cd=18000},

    surefooted               		= {row=6,  addr=0x51e4, id=20964, cd=8400},
    ["greater surefooted"]   		= {row=15, addr=0x5706, id=22278, cd=8400},

    reverence                		= {row=7,  addr=0x51e5, id=20965, resetTypes={1}, cd=14400},
    ["greater reverence"]    		= {row=14, addr=0x5704, id=22276, resetTypes={2}, cd=14400},
    ["master reverence"]     		= {row=52, addr=0x598d, id=22925, resetTypes={3}, cd=14400},
    ["supreme reverence"]    		= {row=71, addr=0x5d3e, id=23870, resetTypes={4}, cd=14400},

    ["call of the sea"]      		= {row=8,  addr=0x51e6, id=20966, cd=14400},
    ["greater call of the sea"] 	= {row=13, addr=0x5702, id=22274, cd=14400},
    ["master call of the sea"]  	= {row=51, addr=0x598b, id=22923, cd=14400},
    ["supreme call of the sea"] 	= {row=70, addr=0x5d3c, id=23868, cd=14400},
    ["legendary call of the sea"] 	= {row=74, addr=0x784a, id=30794, cd=14400},

    lumberjack               		= {row=16, addr=0x5708, id=22280, cd=14400},
    ["greater lumberjack"]   		= {row=17, addr=0x570a, id=22282, cd=14400},
    ["master lumberjack"]    		= {row=47, addr=0x5983, id=22915, cd=14400},
    ["supreme lumberjack"]   		= {row=66, addr=0x5d34, id=23860, cd=14400},
    ["legendary lumberjack"]		= {row=75, addr=0x784c, id=30796, cd=14400},

    quarrymaster             		= {row=18, addr=0x570c, id=22284, cd=14400},
    ["greater quarrymaster"]		= {row=19, addr=0x570e, id=22286, cd=14400},
    ["master quarrymaster"] 		= {row=46, addr=0x5981, id=22913, cd=14400},
    ["supreme quarrymaster"]		= {row=65, addr=0x5d32, id=23858, cd=14400},
    ["legendary quarrymaster"]		= {row=77, addr=0x7850, id=30800, cd=14400},

    ["five finger discount"]		= {row=20, addr=0x5710, id=22288, cd=14400},
    ["greater five finger discount"] 	= {row=21, addr=0x5712, id=22290, cd=14400},
    ["master five finger discount"]  	= {row=45, addr=0x597f, id=22911, cd=14400},
    ["supreme five finger discount"] 	= {row=64, addr=0x5d30, id=23856, cd=14400},
    ["legendary five finger discount"]	= {row=76, addr=0x784e, id=30798, cd=14400},

    ["poison purge"]        		= {row=1,  addr=0x51de, id=20958, resetTypes={1}, cd=4200},
    ["greater poison purge"]		= {row=10, addr=0x56fc, id=22268, resetTypes={2}, cd=4800},
    ["master poison purge"] 		= {row=48, addr=0x5985, id=22917, resetTypes={3}, cd=5400},
    ["supreme poison purge"]		= {row=67, addr=0x5d36, id=23862, resetTypes={4}, cd=7200},

    ["runic accuracy"]      		= {row=5,  addr=0x51e2, id=20962, resetTypes={1}, cd=14400},
    ["greater runic accuracy"] 		= {row=11, addr=0x56fe, id=22270, resetTypes={2}, cd=14400},
    ["master runic accuracy"]  		= {row=49, addr=0x5987, id=22919, resetTypes={3}, cd=14400},
    ["supreme runic accuracy"] 		= {row=68, addr=0x5d38, id=23864, resetTypes={4}, cd=14400},

    sharpshooter            		= {row=4,  addr=0x51e7, id=20967, resetTypes={1}, cd=14400},
    ["greater sharpshooter"]		= {row=12, addr=0x5700, id=22272, resetTypes={2}, cd=14400},
    ["master sharpshooter"] 		= {row=50, addr=0x5989, id=22921, resetTypes={3}, cd=14400},
    ["supreme sharpshooter"]		= {row=69, addr=0x5d3a, id=23866, resetTypes={4}, cd=14400},
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
            print(string.format("[MISMATCH] '%s' -> addr = 0x%X (%d) | id = %d", name, aura.addr, aura.addr, aura.id))
            table.insert(mismatches, name)
        end
    end
    if #mismatches == 0 then
        print("[DEBUG] - All aura IDs match their hex addresses.")
    end
    return mismatches
end

function AURAS.timeToSeconds(timeStr)
    local h, m, s
    h, m, s = timeStr:match("^(%d+):(%d+):(%d+)$")
    if h and m and s then
        return tonumber(h) * 3600 + tonumber(m) * 60 + tonumber(s)
    end
    m, s = timeStr:match("^(%d+):(%d+)$")
    if m and s then
        return tonumber(m) * 60 + tonumber(s)
    end
    s = timeStr:match("^(%d+)$")
    if s then
        return tonumber(s)
    end

    print("[AURA] - No valid format detected, using fallback timer")
    return 24 * 3600
end

function AURAS.getAuraCD(auraName)
    local timeBox =  { { 1929,0,-1,0 }, { 1929,3,-1,0 }, { 1929,4,-1,0 }, { 1929,73,-1,0 } }
    local statusBox = { { 1929,0,-1,0 }, { 1929,3,-1,0 }, { 1929,4,-1,0 }, { 1929,74,-1,0 } }
 
    API.RandomSleep2(math.random(1600, 2400), 800, 600)
    
    if not API.Read_LoopyLoop() then
        print("[AURA] Script stopping after cooldown check sleep")
        return 86400 
    end

    local statusText = API.ScanForInterfaceTest2Get(false, statusBox)[1].textids
    local timeText = API.ScanForInterfaceTest2Get(false, timeBox)[1].textids
    
    if statusText == "Ready to use" and timeText == "" then
        print("[DEBUG] Aura is ready to use, no cooldown remaining")
        return 0
    end
    
    if statusText == "Currently active" and timeText == "" then
        print("[DEBUG] Aura is currently active")
        return 0
    end
    
    if statusText == "Currently recharging" and timeText == "" then
        print("[DEBUG] Aura is recharging and time display not available, reclicking aura to refresh interface")
        
        local function normalize(name)
            if not name then return nil end
            return name:lower():gsub("%-", " ")
        end
        
        local normalizedName = normalize(auraName)
        local mapping = AURAS.auraActions[normalizedName]
        
        if mapping then
            API.DoAction_Interface(0xffffffff, mapping.addr, 1, 1929, 95, mapping.row, API.OFF_ACT_GeneralInterface_route)
            API.RandomSleep2(math.random(1200, 2400), 200, 200)
            
            if not API.Read_LoopyLoop() then
                print("[AURA] Script stopping after aura reclick")
                return 86400 
            end
            
            statusText = API.ScanForInterfaceTest2Get(false, statusBox)[1].textids
            timeText = API.ScanForInterfaceTest2Get(false, timeBox)[1].textids
            print("[DEBUG] Status after refresh: " .. tostring(statusText))
            print("[DEBUG] Time display after refresh: " .. tostring(timeText))
            
            if statusText == "Ready to use" and timeText == "" then
                print("[DEBUG] Aura became ready after refresh, no cooldown remaining")
                return 0
            elseif statusText == "Currently active" and timeText == "" then
                print("[DEBUG] Aura became active after refresh")
                return 0
            end
        else
            print("[ERROR] No mapping found for aura: " .. tostring(auraName))
        end
    elseif statusText == "Currently recharging" then
        print("[DEBUG] Aura is recharging")
    end
    
    return AURAS.timeToSeconds(timeText) or 86400
end

function AURAS.isBackpackOpen()
    return API.VB_FindPSettinOrder(3039).state == 1
end

function AURAS.openBackpack()
    for i = 1, 3 do
        if not API.Read_LoopyLoop() then
            print("[AURA] Script stopping, exiting backpack open")
            return false
        end
        
	if AURAS.isBackpackOpen() then
	    return true
	end
	API.DoAction_Interface(0xc2,0xffffffff,1,1431,0,9,API.OFF_ACT_GeneralInterface_route)
        API.RandomSleep2(math.random(600, 1800), 400, 200)
    end
    error("[ERROR] Unable to open Backpack tab")
    return false
end

function AURAS.isEquipmentOpen()
	return API.VB_FindPSettinOrder(3074).state == 1
end

function AURAS.openEquipment()
    for i = 1, 3 do
        if not API.Read_LoopyLoop() then
            print("[AURA] Script stopping, exiting equipment open")
            return false
        end
        
	if AURAS.isEquipmentOpen() then
		return true
	end
        API.DoAction_Interface(0xc2, 0xffffffff, 1, 1431, 0, 10, API.OFF_ACT_GeneralInterface_route)
        API.RandomSleep2(math.random(600,1800), 400, 200)
    end
    error("[ERROR] Unable to open Equipment tab")
    return false
end

function AURAS.isAuraActive()
    return API.Bbar_ConvToSeconds(API.Buffbar_GetIDstatus(26098, false)) > 0
end

function AURAS.isAuraManagementOpen()
    local inter = {{1929,0,-1,0},{1929,2,-1,0},{1929,2,14,0}}
    local iface = API.ScanForInterfaceTest2Get(false, inter)[1]
    return iface.textids == "Aura Management"
end

function AURAS.ensureInterfacesOpen()
    if AURAS.isEquipmentOpen() and AURAS.isAuraManagementOpen() then
        AURAS.interfacesOpened = true
        return true
    end
    
    if not AURAS.openEquipment() then 
        print("[ERROR] - Failed to open the equipment tab")
        return false 
    end

    if not AURAS.openAuraWindow() then
        print("[ERROR] - Failed to open the aura management tab") 
        return false 
    end
    
    AURAS.interfacesOpened = true
    return true
end

function AURAS.resetInterfaceState()
    AURAS.interfacesOpened = false
end

function AURAS.cleanupInterfaces()
    if not AURAS.isBackpackOpen() then
        AURAS.openBackpack()
    end
    if AURAS.isAuraManagementOpen() then
        local closed = API.DoAction_Interface(0x24, 0xffffffff, 1, 1929, 167, -1, API.OFF_ACT_GeneralInterface_route)
        if closed then
            API.RandomSleep2(math.random(1200,2400), 200, 200)
        else
            print("[ERROR] Failed to close aura management interface")
        end
    end
    AURAS.resetInterfaceState()
end

function AURAS.openAuraWindow()
    for i = 1, 3 do
        if not API.Read_LoopyLoop() then
            print("[AURA] Script stopping, exiting aura window open")
            return false
        end
        
    	if AURAS.isAuraManagementOpen() then
            return true
   	end
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
    local timeBox =  { { 1929,0,-1,0 }, { 1929,3,-1,0 }, { 1929,4,-1,0 }, { 1929,73,-1,0 } }
    local statusBox = { { 1929,0,-1,0 }, { 1929,3,-1,0 }, { 1929,4,-1,0 }, { 1929,74,-1,0 } }
    local mapping = AURAS.auraActions[auraName]
    if not mapping then error(string.format("[ERROR] No mapping for aura '%s'", auraName)) end

    local inter = {{1929,0,-1,0},{1929,3,-1,0},{1929,4,-1,0},{1929,72,-1,0}}
    for i = 1, 3 do
        if not API.Read_LoopyLoop() then
            print("[AURA] Script stopping, exiting aura select")
            return false
        end
        
        local iface = API.ScanForInterfaceTest2Get(false, inter)[1]
        local cleaned = iface.textids:lower():gsub("%-", " ")
        if (cleaned == auraName) then
            print(string.format("[AURA] '%s' selected", auraName))
            return true
        else
		print("Reselect aura to refresh timing interface")
	end
        API.DoAction_Interface(0xffffffff,mapping.addr,1,1929,95,mapping.row,API.OFF_ACT_GeneralInterface_route)
        API.RandomSleep2(math.random(1800, 2800), 200, 200)
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
        {1929,0,-1,0}, {1929,3,-1,0}, {1929,4,-1,0},
        {1929,30,-1,0}, {1929,53,-1,0}, {1929,56,-1,0},
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
            {1929,0,-1,0}, {1929,3,-1,0}, {1929,4,-1,0}, {1929,20,-1,0}, {1929,21,-1,0}, {1929,22,-1,0},
        }},
        { key = "tier1Resets",  label = "tier 1 resets",  expected = 31847, pattern = {
            {1929,0,-1,0}, {1929,3,-1,0}, {1929,4,-1,0}, {1929,20,-1,0}, {1929,21,-1,0}, {1929,23,-1,0},
        }},
        { key = "tier2Resets",  label = "tier 2 resets",  expected = 31848, pattern = {
            {1929,0,-1,0}, {1929,3,-1,0}, {1929,4,-1,0}, {1929,20,-1,0}, {1929,21,-1,0}, {1929,24,-1,0},
        }},
        { key = "tier3Resets",  label = "tier 3 resets",  expected = 31849, pattern = {
            {1929,0,-1,0}, {1929,3,-1,0}, {1929,4,-1,0}, {1929,20,-1,0}, {1929,21,-1,0}, {1929,25,-1,0},
        }},
        { key = "tier4Resets",  label = "tier 4 resets",  expected = 31850, pattern = {
            {1929,0,-1,0}, {1929,3,-1,0}, {1929,4,-1,0}, {1929,20,-1,0}, {1929,21,-1,0}, {1929,26,-1,0},
        }},
        { key = "exactVis",     label = "exact vis",      expected = 32092, pattern = {
            {1929,0,-1,0}, {1929,3,-1,0}, {1929,4,-1,0}, {1929,20,-1,0}, {1929,21,-1,0}, {1929,27,-1,0},
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

    if API.IsPremiumMember() and API.IsAuraResetAvailable() then
        return 1, "premier"
    end

    if action and action.resetTypes then
        local tiers = {table.unpack(action.resetTypes)}
        table.sort(tiers)
        for _, t in ipairs(tiers) do
            local cnt = counts["tier" .. t .. "Resets"] or 0
            if cnt > 0 then
                return cnt, t
            end
        end
    end

    if useGeneric and not AURAS.noGenericAuras[auraName] then
        if counts.genericResets > 0 then
            return counts.genericResets, 0
        end
    end

    return 0, nil
end

function AURAS.maybeEnterPin()
    if API.VB_FindPSettinOrder(2874).state == 18 then
	if not API.Read_LoopyLoop() then
            print("[PIN] Script stopping after PIN entry sleep")
            return false
        end
        print("[PIN] PIN window detected -> entering PIN")
        API.DoBankPin(AURAS.yourbankpin)
        API.RandomSleep2(math.random(1200, 2400), 200, 200)

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

function AURAS.resetSequence()
    AURAS.currentSequenceIndex = 1
    print("[SEQUENCE] Reset sequence index to 1")
end

function AURAS.clearExpiredCooldownCache()
    local currentTime = os.time()
    local cleared = 0
    
    for auraName, cachedCooldown in pairs(AURAS.auraCooldownCache) do
        local cachedTimestamp = AURAS.auraCooldownTimestamp[auraName]
        if cachedTimestamp then
            local timeElapsed = currentTime - cachedTimestamp
            local remainingCooldown = math.max(0, cachedCooldown - timeElapsed)
            
            if remainingCooldown <= 0 then
                AURAS.auraCooldownCache[auraName] = nil
                AURAS.auraCooldownTimestamp[auraName] = nil
                cleared = cleared + 1
            end
        else
            AURAS.auraCooldownCache[auraName] = nil
            cleared = cleared + 1
        end
    end
    
end

function AURAS.getAuraCooldownRemaining(auraName)
    local function normalize(name)
        if not name then return nil end
        return name:lower():gsub("%-", " ")
    end
    
    local normalizedName = normalize(auraName)
    local lastUsed = AURAS.auraLastUsed[normalizedName]
    local currentTime = os.time()
    local mapping = AURAS.auraActions[normalizedName]
    
    if not mapping then 
        print(string.format("[COOLDOWN] %s: no mapping found, returning 86,400s", auraName))
        return 86400 
    end
    
    if not lastUsed or lastUsed == 0 then
        local cachedCooldown = AURAS.auraCooldownCache[normalizedName]
        local cachedTimestamp = AURAS.auraCooldownTimestamp[normalizedName]
        
        if cachedCooldown and cachedTimestamp then
            local timeElapsed = currentTime - cachedTimestamp
            local remainingCooldown = math.max(0, cachedCooldown - timeElapsed)
            if remainingCooldown > 0 then
                --print(string.format("[COOLDOWN] %s: using cached value, %ds remaining", auraName, remainingCooldown))
                return remainingCooldown
            else
                AURAS.auraCooldownCache[normalizedName] = nil
                AURAS.auraCooldownTimestamp[normalizedName] = nil
            end
        end
        
        print(string.format("[COOLDOWN] %s: no session data, checking interface for actual remaining time", auraName))
        local interfaceCooldown = AURAS.getAuraCD(auraName)
        if interfaceCooldown and interfaceCooldown < mapping.cd and interfaceCooldown > 0 then
            local buffer = math.random(5, 10)
            local bufferedCooldown = interfaceCooldown + buffer
            print(string.format("[COOLDOWN] %s: interface shows %ds remaining (instead of default %ds), adding %ds buffer", auraName, interfaceCooldown, mapping.cd, buffer))
            AURAS.auraCooldownCache[normalizedName] = bufferedCooldown
            AURAS.auraCooldownTimestamp[normalizedName] = currentTime
            return bufferedCooldown
        else
            return mapping.cd
        end
    end
    
    local timeElapsed = currentTime - lastUsed
    local timeBased = math.max(0, mapping.cd - timeElapsed)
    
    if timeBased <= 0 then
        AURAS.auraLastUsed[normalizedName] = nil
    end
    
    return timeBased
end

function AURAS.getCurrentAuraCooldown(auraName)
    local function normalize(name)
        return name:lower():gsub("%-", " ")
    end
    
    local normalizedName = normalize(auraName)
    local mapping = AURAS.auraActions[normalizedName]

    if not mapping then return 86400 end
    
    local timeBased = AURAS.getAuraCooldownRemaining(normalizedName)
    if timeBased < 86400 then
        return timeBased
    end
    
    if not AURAS.ensureInterfacesOpen() then return 86400 end
    if not AURAS.selectAura(normalizedName) then return 86400 end
    
    local interfaceCooldown = AURAS.getAuraCD(auraName)
    return interfaceCooldown
end

function AURAS.isAuraAvailable(auraName)
    local function normalize(name)
        return name:lower():gsub("%-", " ")
    end
    
    local normalizedName = normalize(auraName)
    local mapping = AURAS.auraActions[normalizedName]
    if not mapping then
        print(string.format("[SEQUENCE] No mapping found for aura '%s'", auraName))
        return false
    end
    
    local currentTime = os.time()
    local cachedCooldown = AURAS.auraCooldownCache[normalizedName]
    local cachedTimestamp = AURAS.auraCooldownTimestamp[normalizedName]
    
    if cachedCooldown and cachedTimestamp then
        local timeElapsed = currentTime - cachedTimestamp
        local remainingCooldown = math.max(0, cachedCooldown - timeElapsed)
        if remainingCooldown > 0 then
            print(string.format("[SEQUENCE] Aura '%s' not available (cached), cooldown: %ds", auraName, remainingCooldown))
            return false, remainingCooldown
        else
            -- Cache expired, clear it and continue to interface check
            AURAS.auraCooldownCache[normalizedName] = nil
            AURAS.auraCooldownTimestamp[normalizedName] = nil
        end
    end
    
    local lastUsed = AURAS.auraLastUsed[normalizedName]
    if lastUsed and lastUsed > 0 then
        local timeElapsed = currentTime - lastUsed
        local timeBased = math.max(0, mapping.cd - timeElapsed)
        if timeBased > 0 then
            print(string.format("[SEQUENCE] Aura '%s' not available (session-based), cooldown: %ds", auraName, timeBased))
            return false, timeBased
        end
    end
    
    if not AURAS.ensureInterfacesOpen() then return false end
    if not AURAS.selectAura(normalizedName) then return false end
    
    local ownedBox = {
        {1929,0,-1,0}, {1929,3,-1,0}, {1929,4,-1,0},
        {1929,6,-1,0}, {1929,11,-1,0}, {1929,18,-1,0},
        {1929,19,-1,0}
    }
    local ownedStatus = API.ScanForInterfaceTest2Get(false, ownedBox)[1].textids
    
    if ownedStatus == "Buy" then
        print(string.format("[SEQUENCE] Aura '%s' not owned", auraName))
        return false
    end
    
    local interStatus = {{1929,0,-1,0}, {1929,3,-1,0}, {1929,4,-1,0}, {1929,74,-1,0}}
    local status = API.ScanForInterfaceTest2Get(false, interStatus)[1].textids
    
    if status == "Currently active" then
        print(string.format("[SEQUENCE] Aura '%s' is currently active, skipping", auraName))
        return false
    elseif status == "Ready to use" then
        print(string.format("[SEQUENCE] Aura '%s' is available", auraName))
        return true
    end
    
    local interfaceCooldown = AURAS.getAuraCD(auraName)
    
    if interfaceCooldown == 0 then
        status = API.ScanForInterfaceTest2Get(false, interStatus)[1].textids
        if status == "Ready to use" then
            print(string.format("[SEQUENCE] Aura '%s' is available (after refresh)", auraName))
            AURAS.auraCooldownCache[normalizedName] = nil
            AURAS.auraCooldownTimestamp[normalizedName] = nil
            return true
        elseif status == "Currently active" then
            print(string.format("[SEQUENCE] Aura '%s' is currently active (after refresh)", auraName))
            return false
        end
    end
    
    if interfaceCooldown > 0 then
        local buffer = math.random(5, 10)
        local bufferedCooldown = interfaceCooldown + buffer
        AURAS.auraCooldownCache[normalizedName] = bufferedCooldown
        AURAS.auraCooldownTimestamp[normalizedName] = currentTime
        print(string.format("[SEQUENCE] Adding %ds buffer to %ds cooldown", buffer, interfaceCooldown))
    end
    
    print(string.format("[SEQUENCE] Aura '%s' not available (%s), cooldown: %ds", auraName, status, interfaceCooldown))
    return false, interfaceCooldown
end

function AURAS.getNextSequenceAura()
    if not AURAS.isSequenceMode or #AURAS.currentSequence == 0 then
        return nil
    end
    
    if AURAS.lastFoundReadyAura then
        print(string.format("[SEQUENCE] Using cached ready aura: '%s'", AURAS.lastFoundReadyAura))
        local cachedAura = AURAS.lastFoundReadyAura
        AURAS.lastFoundReadyAura = nil
        return cachedAura
    end
    
    local currentTime = os.time()
    
    if AURAS.sequenceNextCheckTime > currentTime then
        local waitTime = AURAS.sequenceNextCheckTime - currentTime
        --print(string.format("[SEQUENCE] Too early to check sequence, waiting %ds more", waitTime))
        return nil
    end
    
    local shortestCooldown = math.huge
    local availableAura = nil
    local shortestAuraName = ""
    
    print("[SEQUENCE] Checking all auras in sequence for availability...")
    
    for i, auraName in ipairs(AURAS.currentSequence) do
        if not API.Read_LoopyLoop() then
            print("[SEQUENCE] Script stopping, exiting sequence check")
            return nil
        end
        
        print(string.format("[SEQUENCE] Checking aura (%d/%d): '%s'", i, #AURAS.currentSequence, auraName))
        
        local function normalize(name)
            return name:lower():gsub("%-", " ")
        end
        
        local normalizedName = normalize(auraName)
        local currentTime = os.time()
        local cachedCooldown = AURAS.auraCooldownCache[normalizedName]
        local cachedTimestamp = AURAS.auraCooldownTimestamp[normalizedName]
        local shouldCheckInterface = true
        local cooldown = 0
        
        if cachedCooldown and cachedTimestamp then
            local timeElapsed = currentTime - cachedTimestamp
            local remainingCooldown = math.max(0, cachedCooldown - timeElapsed)
            
            if remainingCooldown > 0 then
                shouldCheckInterface = false
                cooldown = remainingCooldown
            else
                -- Cache indicates cooldown should be over, check interface
            end
        else
        end
        
        if shouldCheckInterface then
            local available, interfaceCooldown = AURAS.isAuraAvailable(normalizedName)
            if available then
                print(string.format("[SEQUENCE] Found available aura: '%s'", auraName))
                AURAS.sequenceExhausted = false
                AURAS.sequenceNextCheckTime = 0
                AURAS.auraCooldownCache[normalizedName] = nil
                AURAS.auraCooldownTimestamp[normalizedName] = nil
                return auraName
            else
                cooldown = interfaceCooldown or 86400
                if cooldown > 0 and cooldown < 86400 then
                    local buffer = math.random(5, 10)
                    cooldown = cooldown + buffer
                end
                AURAS.auraCooldownCache[normalizedName] = cooldown
                AURAS.auraCooldownTimestamp[normalizedName] = currentTime
            end
        end
        
        if cooldown < shortestCooldown then
            shortestCooldown = cooldown
            shortestAuraName = auraName
        end
    end
    
    if shortestCooldown < math.huge and shortestCooldown > 0 then
        AURAS.sequenceNextCheckTime = currentTime + shortestCooldown
        AURAS.sequenceShortestCooldown = shortestCooldown
        AURAS.nextActivationTime = currentTime + shortestCooldown
        AURAS.currentWaitingAura = shortestAuraName
        AURAS.isWaiting = true
        print(string.format("[SEQUENCE] No auras ready. Next check in %ds when '%s' is available", shortestCooldown, shortestAuraName))
        AURAS.sequenceExhausted = false 
	-- Not truly exhausted, just waiting
    else
        print("[SEQUENCE] No auras have valid cooldowns, marking sequence as exhausted")
        AURAS.sequenceExhausted = true
    end
    
    return nil
end

function AURAS.isAnyAuraReady(auraNameOrSequence)

    if not auraNameOrSequence then
        print("[DEBUG] isAnyAuraReady: No aura provided")
        return false
    end
    
    local currentTime = os.time()
    
    if AURAS.nextReadyCheckTime > currentTime then
        local waitTime = AURAS.nextReadyCheckTime - currentTime
        --print(string.format("[DEBUG] Too early to check aura, next check in %ds", waitTime))
        return false
    end
    
    if type(auraNameOrSequence) == "table" then
        print(string.format("[DEBUG] Checking availability for %d auras in sequence", #auraNameOrSequence))
        
        local shortestCooldown = math.huge
        
        for i, auraName in ipairs(auraNameOrSequence) do
            if not API.Read_LoopyLoop() then
                print("[DEBUG] Script stopping, exiting aura ready check")
                AURAS.cleanupInterfaces()
                return false
            end
            
            local function normalize(name)
                if not name then return nil end
                return name:lower():gsub("%-", " ")
            end
            
            local normalizedName = normalize(auraName)
            if normalizedName and AURAS.auraActions[normalizedName] then
                local cachedCooldown = AURAS.auraCooldownCache[normalizedName]
                local cachedTimestamp = AURAS.auraCooldownTimestamp[normalizedName]
                local shouldCheckInterface = true
                local cooldownRemaining = 0
                
                if cachedCooldown and cachedTimestamp then
                    local timeElapsed = currentTime - cachedTimestamp
                    local remainingCooldown = math.max(0, cachedCooldown - timeElapsed)
                    
                    if remainingCooldown > 0 then
                        shouldCheckInterface = false
                        cooldownRemaining = remainingCooldown
                    else
                        -- Cache indicates cooldown should be over, check interface
                    end
                end
                
                if shouldCheckInterface then
                    local available, interfaceCooldown = AURAS.isAuraAvailable(normalizedName)
                    
                    if available then
                        print(string.format("[DEBUG] Found ready aura: %s", auraName))
                        AURAS.nextReadyCheckTime = 0 
                        AURAS.lastFoundReadyAura = auraName
                        AURAS.auraCooldownCache[normalizedName] = nil
                        AURAS.auraCooldownTimestamp[normalizedName] = nil
                        return true
                    else
                        cooldownRemaining = interfaceCooldown or 86400
                        if cooldownRemaining > 0 and cooldownRemaining < 86400 then
                            local buffer = math.random(5, 10)
                            cooldownRemaining = cooldownRemaining + buffer
                        end
                        AURAS.auraCooldownCache[normalizedName] = cooldownRemaining
                        AURAS.auraCooldownTimestamp[normalizedName] = currentTime
                    end
                end
                
                if cooldownRemaining and cooldownRemaining < shortestCooldown then
                    shortestCooldown = cooldownRemaining
                end
            else
                print(string.format("[DEBUG] No mapping found for aura: %s", auraName))
            end
        end
        
        if shortestCooldown < math.huge and shortestCooldown > 0 then
            AURAS.nextReadyCheckTime = currentTime + shortestCooldown
            print(string.format("[DEBUG] No auras ready now, next check in %ds", shortestCooldown))
        else
            print("[DEBUG] No valid cooldowns found")
        end
        
        AURAS.cleanupInterfaces()
        AURAS.lastFoundReadyAura = nil
        return false
    else
        local function normalize(name)
            if not name then return nil end
            return name:lower():gsub("%-", " ")
        end
        
        local normalizedName = normalize(auraNameOrSequence)
        if not normalizedName or not AURAS.auraActions[normalizedName] then
            print(string.format("[DEBUG] No mapping found for aura: %s", auraNameOrSequence))
            AURAS.cleanupInterfaces()
            AURAS.lastFoundReadyAura = nil
            return false
        end
        
        local available, cooldownRemaining = AURAS.isAuraAvailable(normalizedName)
        
        if available then
            AURAS.nextReadyCheckTime = 0 
            AURAS.lastFoundReadyAura = auraNameOrSequence 
            return true
        else
            local waitTime = cooldownRemaining or 3600
            AURAS.nextReadyCheckTime = currentTime + waitTime
            --print(string.format("[DEBUG] Aura not ready, next check in %ds", waitTime))
            AURAS.cleanupInterfaces()
            AURAS.lastFoundReadyAura = nil
            return false
        end
    end
end

function AURAS.extensionLogic()
    API.RandomSleep2(math.random(1200, 2400), 200, 200)
    local avail = AURAS.parseAvailableVis()
    if not avail then return end

    local interLong  = {{1929,0,-1,0}, {1929,3,-1,0}, {1929,4,-1,0}, {1929,30,-1,0}, {1929,32,-1,0}, {1929,51,-1,0}}
    local rawLong    = API.ScanForInterfaceTest2Get(false, interLong)[1].textids
    local costLong   = AURAS.parseVisCost(rawLong)
    if not costLong then
        print("[AURA] ERROR: Unable to parse long-extension cost -> skipping")
        return
    end

    local interShort = {{1929,0,-1,0}, {1929,3,-1,0}, {1929,4,-1,0}, {1929,30,-1,0}, {1929,32,-1,0}, {1929,52,-1,0}}
    local rawShort   = API.ScanForInterfaceTest2Get(false, interShort)[1].textids
    local costShort  = AURAS.parseVisCost(rawShort)
    if not costShort then
        print("[AURA] ERROR: Unable to parse short-extension cost -> skipping")
        return
    end

    if (costLong <= avail) then
        print(string.format("[AURA] Extending long duration (%d vis)", costLong))
	if not API.Read_LoopyLoop() then
            print("[AURA] Script stopping after long extension sleep")
            return
        end
        API.DoAction_Interface(0x24, 0xffffffff, 1, 1929, 38, -1, API.OFF_ACT_GeneralInterface_route)
        API.RandomSleep2(math.random(1200, 2400), 200, 200)
        
        AURAS.maybeEnterPin()

    elseif costShort <= avail then
        print(string.format("[AURA] Extending short duration (%d Vis)", costShort))
	if not API.Read_LoopyLoop() then
            print("[AURA] Script stopping after short extension sleep")
            return
        end
        API.DoAction_Interface(0x24, 0xffffffff, 1, 1929, 47, -1, API.OFF_ACT_GeneralInterface_route)
        API.RandomSleep2(math.random(1200, 2400), 200, 200)
        
        AURAS.maybeEnterPin()

    else
        API.RandomSleep2(math.random(1200, 2400), 200, 200)
        print("[AURA] Not enough Vis to extend the aura")
        API.RandomSleep2(math.random(1200, 2400), 200, 200)   
    end
end

function AURAS.activateLoop(auraName)
    for i = 1, 3 do
        if not API.Read_LoopyLoop() then
            print("[AURA] Script stopping, exiting activation loop")
            return false
        end
        
        print(string.format("[AURA] Activation attempt %d...", i))
        API.DoAction_Interface(0x24, 0xffffffff, 1, 1929, 16, -1, API.OFF_ACT_GeneralInterface_route)
        API.RandomSleep2(math.random(1200,2400),200,200)
        
        if AURAS.isAuraActive() then
            if auraName then
                local timestamp = os.time()
                AURAS.auraLastUsed[auraName] = timestamp
                print(string.format("[COOLDOWN] Set activation timestamp for '%s': %d", auraName, timestamp))
                
                local function normalize(name)
                    return name:lower():gsub("%-", " ")
                end
                local normalizedName = normalize(auraName)
                local mapping = AURAS.auraActions[normalizedName]
                if mapping then
                    local buffer = math.random(5, 10)
                    local bufferedCooldown = mapping.cd + buffer
                    AURAS.auraCooldownCache[normalizedName] = bufferedCooldown
                    AURAS.auraCooldownTimestamp[normalizedName] = timestamp
                end
            end
            print(string.format("[AURA] Aura activated on attempt %d", i))
            return true
        end
    end
    print("[ERROR] Aura failed to activate after 3 attempts")
    return false
end

function AURAS.performReset(auraName, resets, resetType)
    resets = resets or 0
    print(string.format("[DEBUG] performReset called for aura = %s, resetType = %s, resetsRemaining = %s",auraName, tostring(resetType), tostring(resets)))

    for attempt = 1, 3 do
        if not API.Read_LoopyLoop() then
            print("[DEBUG] Script stopping, exiting reset attempt")
            return false
        end
        
        local state = API.VB_FindPSettinOrder(2874).state
        print(string.format("[DEBUG] VB_FindPSettinOrder(2874).state = %s", tostring(state)))

        if state == 12 then
            print("[DEBUG] Confirmation dialog detected -> confirming reset")
            API.DoAction_Interface(0xffffffff, 0xffffffff, 0, 1188, 8, -1, API.OFF_ACT_GeneralInterface_Choose_option)
            API.RandomSleep2(math.random(1200, 2400), 200, 200)
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
            local addrMap = { [1] = 0x7c67, [2] = 0x7c68, [3] = 0x7c69, [4] = 0x7c6a }
            API.DoAction_Interface(0xffffffff, addrMap[resetType], 1, 1929, 22 + resetType, -1, API.OFF_ACT_GeneralInterface_route)

        else
            print(string.format("[DEBUG] Unknown resetType = %s for aura = %s", tostring(resetType), auraName))
            return false
        end

        API.RandomSleep2(math.random(1200, 2400), 200, 200)
    end

    print(string.format("[DEBUG] performReset failed after 3 attempts for aura = %s", auraName))
    return false
end

function AURAS.deactivateAura(auraName)
    for i = 1, 3 do
        if not API.Read_LoopyLoop() then
            print("[AURA] Script stopping, exiting deactivation loop")
            return false
        end
        API.RandomSleep2(math.random(650, 1800), 200, 200)
        print(string.format("[AURA] Deactivation attempt %d...", i))
        
	API.DoAction_Interface(0x24,0xffffffff,1,1929,16,-1,API.OFF_ACT_GeneralInterface_route)
	API.RandomSleep2(math.random(1200, 2400), 200, 200)

	local state = API.VB_FindPSettinOrder(2874).state
        print(string.format("[DEBUG] VB_FindPSettinOrder(2874).state = %s", tostring(state)))
	
        if state == 12 then
            print("[DEBUG] Confirmation dialog detected -> confirming deactivate")
	    API.DoAction_Interface(0xffffffff,0xffffffff,0,1188,8,-1,API.OFF_ACT_GeneralInterface_Choose_option)
	    API.RandomSleep2(math.random(1200, 2400), 200, 200)
      	    print("[DEBUG] performDeactivate -> successful")
        end
	
        if not AURAS.isAuraActive() then
            print(string.format("[AURA] Aura deactivated on attempt %d", i))
            if auraName then
                local timestamp = os.time()
                AURAS.auraLastUsed[auraName] = timestamp
                print(string.format("[COOLDOWN] Started cooldown for deactivated aura '%s': %d", auraName, timestamp))
                
                local function normalize(name)
                    return name:lower():gsub("%-", " ")
                end
                local normalizedName = normalize(auraName)
                local mapping = AURAS.auraActions[normalizedName]
                if mapping then
                    local buffer = math.random(5, 10)
                    local bufferedCooldown = mapping.cd + buffer
                    AURAS.auraCooldownCache[normalizedName] = bufferedCooldown
                    AURAS.auraCooldownTimestamp[normalizedName] = timestamp
                end
            end
            return true
        end
    end
    print("[DEBUG] Aura failed to deactivate after 3 attempts")
    return false
end

function AURAS.manageAura(rawInput, autoExtend, autoReset)
    if autoExtend == nil then
        autoExtend = true
    end
    if autoReset == nil then
        autoReset = true
    end

    local bad = AURAS.verifyAuras(AURAS.auraActions)
    if #bad > 0 then
        error("Found mismatched auras: " .. table.concat(bad, ", "))
    end

    local function normalize(name)
        if not name then return nil end
        return name:lower():gsub("%-", " ")
    end

    local auraName = normalize(rawInput)
    if not auraName then
        error("[ERROR] Invalid aura name provided (nil or empty)")
        return false
    end
    local mapping = AURAS.auraActions[auraName]
    if not mapping then
        error(string.format("[ERROR] No mapping for aura '%s'", auraName))
	return false
    end

    if not AURAS.ensureInterfacesOpen() then
	error("[ERROR] - Failed to open required interfaces")
	return false 
    end

    if not AURAS.selectAura(auraName) then 
	error("[ERROR] - Failed to select the correct aura")
        return false 
    end

    local counts = AURAS.getResetCounts()

    local ownedBox = {
        {1929,0,-1,0}, {1929,3,-1,0}, {1929,4,-1,0},
        {1929,6,-1,0}, {1929,11,-1,0}, {1929,18,-1,0},
        {1929,19,-1,0}
    }
    local ownedStatus = API.ScanForInterfaceTest2Get(false, ownedBox)[1].textids
    print(string.format("[AURA] Owned status: %s", ownedStatus))

    if ownedStatus == "Buy" then
        error(string.format("[AURA] '%s' not available to use -> aborting", auraName))
        return false

    elseif ownedStatus == "Deactivate" then
        if not AURAS.deactivateAura(auraName) then
		error(string.format("[ERROR] '%s': failed to deactivate", auraName))
		return false
	end
    end

    local interStatus = {{1929,0,-1,0}, {1929,3,-1,0}, {1929,4,-1,0}, {1929,74,-1,0}}
    local status = API.ScanForInterfaceTest2Get(false, interStatus)[1].textids

    if status == "Currently active" then
        print(string.format("[AURA] '%s' already active", auraName))
        if not AURAS.auraLastUsed[auraName] then
            print(string.format("[COOLDOWN] Setting activation timestamp for currently active aura '%s'", auraName))
            AURAS.auraLastUsed[auraName] = os.time()
        else
            print(string.format("[COOLDOWN] Aura '%s' already has activation timestamp: %d", auraName, AURAS.auraLastUsed[auraName]))
        end
        return true

    elseif status == "Ready to use" then
        print(string.format("[AURA] '%s' ready to activate", auraName))
        if autoExtend then
            print("[AURA] Auto-extension enabled, extending aura")
            AURAS.extensionLogic()
        else
            print("[AURA] Auto-extension disabled, skipping extension")
        end
        return AURAS.activateLoop(auraName)

    elseif status == "Currently recharging" then
        print(string.format("[AURA] '%s' recharging", auraName))
        
        if AURAS.isSequenceMode then
            if not AURAS.sequenceExhausted then
                print("[SEQUENCE] Current aura recharging, cycling through sequence for next available aura")
                local nextAura = AURAS.getNextSequenceAura()
                if nextAura then
                    print(string.format("[SEQUENCE] Found next available aura: '%s'", nextAura))
                    return AURAS.manageAura(nextAura, autoExtend, autoReset)
                else
                    print("[SEQUENCE] All auras in sequence have been checked, none available")
                end
            end
            
            if autoReset then
                print("[SEQUENCE] No other auras available, attempting reset")
                local resets, usedType = AURAS.getAuraResetCount(auraName, true)
                if resets and resets > 0 then
                    if AURAS.performReset(auraName, resets, usedType) then
                        if autoExtend then
                            print("[AURA] Auto-extension enabled, extending aura after reset")
                            AURAS.extensionLogic()
                        else
                            print("[AURA] Auto-extension disabled, skipping extension after reset")
                        end
                        return AURAS.activateLoop(auraName)
                    else
                        error("[DEBUG] - Failed to reset aura")
                        return false
                    end
                else
                    print("[SEQUENCE] No resets available, will wait for cooldowns")
                end
            else
                print("[SEQUENCE] autoReset disabled, will wait for cooldowns")
            end
        else
            if autoReset then
                print(string.format("[AURA] autoReset enabled, attempting to reset '%s'", auraName))
                local resets, usedType = AURAS.getAuraResetCount(auraName, true)
                if resets and resets > 0 then
                    if AURAS.performReset(auraName, resets, usedType) then
                        if autoExtend then
                            print("[AURA] Auto-extension enabled, extending aura after reset")
                            AURAS.extensionLogic()
                        else
                            print("[AURA] Auto-extension disabled, skipping extension after reset")
                        end
                        return AURAS.activateLoop(auraName)
                    else
                        error("[DEBUG] - Failed to reset aura")
                        return false
                    end
                else
                    print("[AURA] No resets available, setting wait state")
                end
            else
                print("[AURA] autoReset disabled, setting wait state")
            end
            
            local cooldown = AURAS.getCurrentAuraCooldown(auraName)
            if cooldown > 0 then
                AURAS.nextActivationTime = os.time() + cooldown
                AURAS.currentWaitingAura = auraName
                AURAS.isWaiting = true
                print(string.format("[AURA] '%s' on cooldown for %ds, setting wait state", auraName, cooldown))
                return true
            end
        end
        
        AURAS.noResets = true
        print("[DEBUG] - Reached fallback logic")
        return true

    else
        error(string.format("[ERROR] Unhandled status '%s'", status))
        return false
    end
end

function AURAS.activateAura(auraNameOrSequence, autoExtend, autoReset)
    local debugState = false

    if autoExtend == nil then
        autoExtend = true
    end
    if autoReset == nil then
        autoReset = true
    end

    local currentTime = os.time()
    local activationSuccess = false
    local needsInterfaceCleanup = false
    
    AURAS.clearExpiredCooldownCache()
    
    if AURAS.nextActivationTime > currentTime then
        local waitTime = AURAS.nextActivationTime - currentTime
	if (debugState == true) then
        	if AURAS.isSequenceMode then
            		print(string.format("[SEQUENCE] Waiting %ds more for next aura", waitTime))
        	else
            		print(string.format("[AURA] Waiting %ds more for '%s' cooldown", waitTime, AURAS.currentWaitingAura))
        	end
	end
        return false
    end
    
    AURAS.isWaiting = false
    AURAS.nextActivationTime = 0
    AURAS.currentWaitingAura = ""

    if type(auraNameOrSequence) == "table" then
        print(string.format("[SEQUENCE] Starting sequence mode with %d auras", #auraNameOrSequence))
        AURAS.currentSequence = auraNameOrSequence
        AURAS.currentSequenceIndex = 1
        AURAS.isSequenceMode = true
        AURAS.sequenceExhausted = false
        AURAS.sequenceNextCheckTime = 0
        AURAS.sequenceShortestCooldown = 0
        print("[SEQUENCE] Reset sequence state for new sequence")
        
        local firstAura = AURAS.getNextSequenceAura()
        if not firstAura then
            print("[SEQUENCE] No available auras in sequence")
            AURAS.isSequenceMode = false
            needsInterfaceCleanup = true
        else
            auraNameOrSequence = firstAura
            print(string.format("[SEQUENCE] Using first available aura: '%s'", auraNameOrSequence))
            needsInterfaceCleanup = true
        end
    else
        AURAS.isSequenceMode = false
        needsInterfaceCleanup = true
        print(string.format("[AURA] Starting activation for single aura '%s' (autoExtend: %s)", auraNameOrSequence, tostring(autoExtend)))
    end

    if auraNameOrSequence and type(auraNameOrSequence) == "string" and not AURAS.noResets then
        local ok = AURAS.manageAura(auraNameOrSequence, autoExtend, autoReset)
        print(string.format("[AURA] manageAura returned: %s", tostring(ok)))

        if ok then
            print(string.format("[DEBUG] manageAura success for '%s'", auraNameOrSequence))
            if AURAS.refreshEarly then
                AURAS.auraRefreshTime = math.random(AURAS.minRefresh, AURAS.maxRefresh)
            end
            activationSuccess = true
        else
            print(string.format("[DEBUG] manageAura failed for '%s', aborting activation.", auraNameOrSequence))
        end
    elseif AURAS.noResets then
        print("[DEBUG] - No aura resets available")
    end
    
    if needsInterfaceCleanup then
        if not API.Read_LoopyLoop() then
            print("[DEBUG] Script stopping, skipping interface cleanup")
            return activationSuccess
        end
        
        if not AURAS.isBackpackOpen() then
            print("[DEBUG] Opening backpack tab to restore game state")
            AURAS.openBackpack()
        end
        
        if AURAS.isAuraManagementOpen() then
            print("[DEBUG] Closing aura interface to restore game state")
            local closed = API.DoAction_Interface(0x24, 0xffffffff, 1, 1929, 167, -1, API.OFF_ACT_GeneralInterface_route)
            if closed then
                API.RandomSleep2(math.random(1200,2400), 200, 200)
                
                if not API.Read_LoopyLoop() then
                    print("[DEBUG] Script stopping after aura interface close sleep")
                    return activationSuccess
                end
                
                print("[DEBUG] Interface cleanup complete")
            else
                print("[ERROR] Failed to close aura management interface")
                API.Write_LoopyLoop(false)
            end
        end
        AURAS.resetInterfaceState()
    end
    
    return activationSuccess
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
