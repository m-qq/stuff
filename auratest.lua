local API		= require("api")
local aura 		= require("AURAS")
local whichAura 	= "legendary lumberjack"


-- usage loop
while API.Read_LoopyLoop() do
    if not aura.isAuraActive() then
        aura.activateAura(whichAura)
    else
        print("[DEBUG] - An aura is already active")
    end
    API.RandomSleep2(math.random(1200,2400), 200, 200)
end
