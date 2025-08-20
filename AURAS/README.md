** NOT current 1.1 info - will update soon **

**AURAS**

A lightweight Lua module to automate aura management in your game client. This library provides functions to open the equipment interface, select and activate auras, handle aura extensions, and perform reset logic when auras are recharging.

---

## Table of Contents

* [Features](#features)
* [Prerequisites](#prerequisites)
* [Installation](#installation)
* [Configuration](#configuration)
* [Usage](#usage)
  * [Basic Example](#basic-example)
* [API Reference](#api-reference)  
* [Contributing](#contributing)

---

## Features

* Open and navigate to the equipment and aura management interfaces
* Select, activate, and extend auras based on available Vis
* Parse and handle short and long extension costs
* Detect and enter bank PIN automatically when required
* Handle aura resets (generic, tiered, and premier) when auras are recharging
* Easily extend the `auraActions` mapping with new aura IDs

## Prerequisites

* **API module**: Provides methods for interface actions, scanning UI elements, etc.

Ensure the `api.lua` module is available on your `package.path`:

```lua
local API = require("api")
```

## Installation

Download the latest ME build: [Build\_DLL.7z](https://discord.com/channels/809828167015596053/1094154063702147122)

1. Copy `AURAS.lua` into your project directory.

2. Require the module in your Lua script and set your bank pin:

   ```lua
   local AURAS = require("AURAS").pin(0000)	-- enter your bank pin
   ```

## Configuration
   
1. **Add Custom Auras** — To add your own aura mappings, convert the aura's ID from decimal to hex and add it to the `AURAS.auraActions` table:

   ```lua
   -- Example: Add "myAura" with decimal ID 30000
   local decimalId = 30000
   local hexAddr = 0x7530  -- convert decimal value to hex
   AURAS.auraActions.myAura = { row=120, addr=hexAddr, id=decimalId, resetTypes={1,2} }
   ```

2. Optionally refresh auras early (in AURAS.lua)
    ```lua
    AURAS.refreshEarly = false --(change to true)
    AURAS.auraRefreshTime = math.random(15, 120) -- refresh at 15 - 120 seconds
    ```

## Usage

### Basic Example

```lua
local API      		= require("api")		-- require api
local aura     		= require("AURAS").pin(0000)	-- require AURAS library & enter your bank pin
local whichAura		= "legendary call of the sea"	-- enter the desired aura

-- usage example
while API.Read_LoopyLoop() do
  API.RandomSleep2(math.random(1200,2400),200,200)

  print("[DEBUG] Remaining:", aura.auraTimeRemaining(), "-> refresh at", aura.auraRefreshTime)
  if aura.auraTimeRemaining() <= aura.auraRefreshTime then
    aura.activateAura(whichAura)
  end
end
```

## API Reference

| Function                             | Description                                                                          |
| ------------------------------------ | ------------------------------------------------------------------------------------ |
| `AURAS.verifyAuras()`                | Ensures every aura mapping’s `id` matches its `addr` (hex) value.                    |
| `AURAS.openEquipment()`              | Opens the equipment interface tab.                                                   |
| `AURAS.isEquipmentOpen()`            | Returns `true` if the equipment tab is currently open.                               |
| `AURAS.openAuraWindow()`             | Opens the aura management window from the equipment tab.                             |
| `AURAS.isAuraManagementOpen()`       | Returns `true` if the aura management interface is currently displayed.              |
| `AURAS.selectAura(name)`             | Selects the specified aura by name in the management window.                         |
| `AURAS.parseVisCost(raw)`            | Parses a string like `"1.2M"` or `"350K"` into a numeric Vis cost (e.g. 1200000).    |
| `AURAS.parseAvailableVis()`          | Reads and returns the available Vis displayed in the aura interface.                 |
| `AURAS.getResetCounts()`             | Scans the interface and returns counts of generic and tiered resets in a table.      |
| `AURAS.getAuraResetCount(name)`      | Determines how many resets (generic, tiered, or premier) are available for an aura.  |
| `AURAS.maybeEnterPin()`              | Detects a bank PIN prompt and automatically enters your configured PIN.              |
| `AURAS.pin(bankPin)`                 | Sets your bank PIN (`yourbankpin`) for use in PIN entry operations.                  |
| `AURAS.extensionLogic()`             | Chooses and performs a long or short aura extension based on available Vis.          |
| `AURAS.activateLoop()`               | Attempts to activate an aura up to three times, verifying success on the buff bar.   |
| `AURAS.performReset(name, count, t)` | Executes a generic, tiered, or premier reset to recharge an aura.                    |
| `AURAS.deactivateAura()`             | Deactivates the currently active aura, confirming any dialog as needed.              |
| `AURAS.manageAura(rawInput)`         | Core workflow: opens interfaces, selects aura, checks status, then activates/resets. |
| `AURAS.activateAura(name)`           | Public entry point to manage and activate any aura by name.                          |
| `AURAS.auraTimeRemaining()`          | Returns the remaining duration (in seconds) of the currently active aura.            |
| `AURAS.noResets` *(variable)*        | Boolean flag set to `true` when no valid resets remain for the current aura.         |
| `AURAS.auraRefreshTime` *(variable)* | Threshold (in seconds) for how early to attempt an aura refresh when enabled.        |

## Contributing

Contributions are welcome! Please open an issue or submit a pull request with:

* Bug fixes
* New aura mappings
* Enhanced error handling or logging
