---
sidebar_position: 5
---

# Full Example

This walks through two plugins — a **provider** and a **consumer** — to show how everything fits together in practice.

## PluginA — The Provider

PluginA exposes a simple counter API and registers itself under `"athar-adv/PluginA"`.

```lua
-- PluginA/init.server.lua
local UniPlugin = require(path.to.UniPlugin)(plugin)

local count = 0

UniPlugin:setApi("counter", {
    increment = function() count += 1 end,
    decrement = function() count -= 1 end,
    get = function() return count end,
})

UniPlugin:setApi("logger", {
    log = function(msg) print(`[PluginA] {msg}`) end,
})

UniPlugin:exportAs("athar-adv/PluginA")

UniPlugin:onClose(function()
    print("PluginA shutting down")
end)
```

## PluginB — The Consumer

PluginB waits for PluginA, uses its APIs, and cleans up properly when either plugin unloads.

```lua
-- PluginB/init.server.lua
local UniPlugin = require(path.to.UniPlugin)(plugin)

local toolbar = plugin:CreateToolbar("Counter Plugin")
local incrementBtn = toolbar:CreateButton("Increment", "Add 1 to counter", "")
local decrementBtn = toolbar:CreateButton("Decrement", "Subtract 1 from counter", "")

UniPlugin:withImports({"athar-adv/PluginA"}, function(plugins, onImportClosed)
    local pluginA = plugins()

    local counter = pluginA:getApi("counter")
    local logger = pluginA:getApi("logger")

    local connections = {
        incrementBtn.Click:Connect(function()
            counter.increment()
            logger.log(`Count is now {counter.get()}`)
        end),
        decrementBtn.Click:Connect(function()
            counter.decrement()
            logger.log(`Count is now {counter.get()}`)
        end),
    }

    onImportClosed(function()
        for _, c in connections do
            c:Disconnect()
        end
        logger.log("PluginB disconnected from PluginA")
    end)
end)

UniPlugin:onClose(function()
    toolbar:Destroy()
end)
```

## What Happens at Runtime

1. Both plugins load. Load order doesn't matter — `withImports` waits.
2. Once PluginA calls `exportAs`, PluginB's handler fires immediately.
3. Clicking the buttons calls into PluginA's counter API.
4. If PluginA is reloaded, `onImportClosed` fires, connections are cleaned up, and `withImports` starts waiting again automatically.
5. When PluginB unloads, the toolbar is destroyed via `onClose`.