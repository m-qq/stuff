local API      		= require("api")		-- require api
local AURAS     		= require("AURAS").pin(0000)	-- require AURAS library & enter your bank pin
  
while API.Read_LoopyLoop() do
  API.RandomSleep2(600, 0, 0)
	if not AURAS.isAuraActive() and AURAS.isAnyAuraReady("friend in need") then
    AURAS.activateAura("friend in need", false, false)
  end
	if not AURAS.isAnyAuraReady("friend in need") then
		print("Aura cd left: "..tostring(AURAS.getAuraCooldownRemaining("friend in need")))
	end
end
