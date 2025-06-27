# WorldHop

A simple Lua script for automating world-hopping in RuneScape.

## Table of Contents

* [Features](#features)
* [Installation](#installation)
* [Configuration](#configuration)
* [Usage](#usage)
* [Script Overview](#script-overview)
* [Contributing](#contributing)

## Features

* Automatically swaps game worlds after a random interval.
* Maintains a history of recent worlds to prevent hopping back too soon.
* Retry logic for opening in-game menus.
* Configurable swap durations and world lists.

## Installation

1. Ensure `api.lua`, `WorldHop.lua`, and `WorldHopTest.lua` are in the same directory.
2. Install any dependencies required by your scripting environment.

## Configuration

All configuration happens at the top of `WorldHop.lua`. You can tweak the following variables:

```lua
local swapForDuration   = true
local worldChanges      = 0
local recentWorlds      = {}
local maxRecent         = 3
local swapWorldDuration = math.random(40, 90) * 60 * 1000
local startTime         = API.ScriptRuntime()
local worlds            = {6, 9, 22, 27, 31, 35, 39, 42, 44, 45, 46, 58, 59, 60, 62, 64, 74, 76, 77, 89, 91, 97, 98, 99, 100, 103, 104, 116, 117}
```

* **swapForDuration**: Enable/disable timed swaps.
* **maxRecent**: Number of most-recent worlds to avoid.
* **swapWorldDuration**: Random duration (ms) between hops.
* **worlds**: List of world IDs eligible for hopping.

## Usage

Require the `WorldHop` module in your script (e.g., `WorldHopTest.lua`):

```lua
local API         = require("api")
local WorldHop    = require("WorldHop")

while API.Read_LoopyLoop() do
    WorldHop.checkHopWorlds()
    API.RandomSleep2(math.random(600, 1800), 1200, 600)
end
```

## Script Overview

* **WorldHop.getCurrentWorld()**: Scans the on-screen interface to read the current world number.
* **WorldHop.pickWorld(worldID)**: Clicks the chosen world and waits for login confirmation.
* **WorldHop.chooseNewWorld(currentWorld)**: Selects a new world not in the recent history.
* **WorldHop.openLogoutMenu() / openWorldMenu()**: Opens the mini and main logout/world menus with retry logic.
* **WorldHop.hopWorld()**: Full sequence to log out, open menus, pick a new world, and track history.
* **WorldHop.checkHopWorlds()**: Checks elapsed time and triggers `hopWorld()` when the duration is exceeded.

## Contributing

Contributions and bug reports are welcome! Feel free to [open an issue](https://github.com/<your-username>/WorldHop/issues) or [submit a pull request](https://github.com/<your-username>/WorldHop/pulls).
