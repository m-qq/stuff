local API      		= require("api")		-- require api
local aura     		= require("AURAS").pin(0000)	-- require AURAS library & enter your bank pin
local whichAura		= "legendary call of the sea"	-- enter the desired aura

-- usage example
while API.Read_LoopyLoop() do
  API.RandomSleep2(math.random(1200,2400),200,200)

  print("[DEBUG] Remaining:", aura.auraTimeRemaining(), "-> refresh at", aura.auraRefreshTime)
  if aura.auraTimeRemaining() <= aura.auraRefreshTime then
    aura.activateAura(whichAura)
    --AURAS.activateAura(auraName, autoExtend)
    --autoExtend Aura is an optional param, default = true (param only needed when FALSE)
  end
end
