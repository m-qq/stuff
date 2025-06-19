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

* **Lua** (5.1 or newer)
* **API module**: Provides methods for interface actions, scanning UI elements, and premium checks

Ensure the `api.lua` module is available on your `package.path`:

```lua
local API = require("api")
```

## Installation

Download the latest ME build: [Build\_DLL.7z](https://discord.com/channels/809828167015596053/1094154063702147122)

1. Copy `AURAS.lua` into your project directory.

2. Require the module in your Lua script:

   ```lua
   local AURAS = require("AURAS")
   ```

## Configuration

1. **Bank PIN** — Set your bank PIN to allow automatic PIN entry when extending auras:

   ```lua
   AURAS.yourbankpin = 1234  -- Replace with your actual PIN
   ```
   
2. **Add Custom Auras** — To add your own aura mappings, convert the aura's ID from decimal to hex and add it to the `AURAS.auraActions` table:

   ```lua
   -- Example: Add "myAura" with decimal ID 30000
   local decimalId = 30000
   local hexAddr = AURAS.decToHex(decimalId)  -- "0x7530"
   AURAS.auraActions.myAura = { row=120, addr=hexAddr, id=decimalId, resetTypes={1,2} }
   ```

## Usage

### Basic Example

```lua
local AURAS = require("AURAS")

-- Configure your bank pin
AURAS.yourbankpin = 1234

-- Activate the "penance" aura
AURAS.activateAura("penance")  -- Opens interfaces, resets if needed, extends, and activates
```

## API Reference

| Function                     | Description                                                                      |
| ---------------------------- | -------------------------------------------------------------------------------- |
| `AURAS.verifyAuras()`        | Ensures every `id` matches its `addr` mapping.                                   |
| `AURAS.decToHex(n)`          | Converts a decimal integer to a hexadecimal string (e.g., `0x1A2B`).             |
| `AURAS.openEquipment()`      | Opens the equipment interface tab.                                               |
| `AURAS.openAuraWindow()`     | Opens the aura management window.                                                |
| `AURAS.selectAura(name)`     | Selects the specified aura by name.                                              |
| `AURAS.parseVisCost(raw)`    | Parses a string like "1.2M" into a numeric Vis cost of 1200000.                  |
| `AURAS.parseAvailableVis()`  | Reads the available Vis displayed in the interface.                              |
| `AURAS.getResetCounts()`     | Returns a table with counts of generic and tiered resets.                        |
| `AURAS.getAuraResetCount()`  | Determines how many resets you can use for a specific aura.                      |
| `AURAS.maybeEnterPin()`      | Detects and enters your bank PIN if the PIN dialog appears.                      |
| `AURAS.extensionLogic()`     | Chooses and performs a long or short extension based on available Vis.           |
| `AURAS.activateLoop()`       | Attempts to activate an aura up to three times, verifying on the buff bar.       |
| `AURAS.performReset()`       | Executes generic, tiered, or premier resets for recharging auras.                |
| `AURAS.manageAura(rawInput)` | Core logic: opens interfaces, selects aura, checks status, and activates/resets. |
| `AURAS.activateAura(name)`   | External entry point to manage and activate any aura by name.                    |

## Contributing

Contributions are welcome! Please open an issue or submit a pull request with:

* Bug fixes
* New aura mappings
* Enhanced error handling or logging
