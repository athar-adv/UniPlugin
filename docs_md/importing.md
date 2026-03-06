---
sidebar_position: 3
---

# Importing Other Plugins

`withImports` lets you declare a list of plugin aliases you depend on and receive them once they're all available. It handles waiting, re-runs if a dependency reloads, and cleans up automatically.

## Basic Usage

```lua
local UniPlugin = require(path.to.UniPlugin)(plugin)

UniPlugin:withImports({"athar-adv/PluginA", "athar-adv/PluginB"}, function(plugins, onImportClosed)
    local pluginA, pluginB = plugins()

    local apiA = pluginA:getApi("main")
    local apiB = pluginB:getApi("utilities")

    apiA.doSomething()
    apiB.helperFn()
end)
```

`plugins()` returns the resolved `UniPlugin` instances as multiple returns, in the same order as the aliases list.

## Waiting for Exports

`withImports` does **not** require the other plugins to already be loaded. It will wait indefinitely until all listed aliases are exported, then fire the handler. This means plugin load order doesn't matter.

## Reacting When a Dependency Closes

If one of your imported plugins unloads or is destroyed, the import group tears down and the handler re-runs once all aliases become available again. Use `onImportClosed` inside the handler to register cleanup:

```lua
UniPlugin:withImports({"athar-adv/PluginA"}, function(plugins, onImportClosed)
    local pluginA = plugins()
    local api = pluginA:getApi("main")

    local connection = api.SomeEvent:Connect(function() ... end)

    onImportClosed(function()
        connection:Disconnect()
    end)
end)
```

`onImportClosed` only accepts one callback at a time — calling it again overwrites the previous one.

## Getting an API

Use `getApi` on a resolved `UniPlugin` to retrieve an API by alias. It errors if no API was set under that alias, so you get a clear message rather than a silent `nil`.

```lua
local api = pluginA:getApi("math")     -- explicit alias
local main = pluginA:getApi()           -- defaults to "main"
```

## Stopping an Import

`withImports` returns a `UniPluginConnection`. Close it to stop watching entirely:

```lua
local importConn = UniPlugin:withImports({"athar-adv/PluginA"}, function(plugins, onImportClosed)
    ...
end)

-- later, when you no longer need the import:
importConn:close()
```

Closing it also fires the current `onImportClosed` callback if one is registered.