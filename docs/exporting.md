---
sidebar_position: 2
---

# Exporting a Plugin

To make your plugin discoverable by others, you need to:
1. Set up one or more APIs with `setApi`
2. Register your plugin under a name with `exportAs`

## Setting an API

`setApi` stores a table of values on your `UniPlugin` instance under an alias. Other plugins retrieve it later using `getApi` with the same alias.

```lua
local UniPlugin = require(path.to.UniPlugin)(plugin)

UniPlugin:setApi("math", {
    add = function(a, b) return a + b end,
    multiply = function(a, b) return a * b end,
})
```

If you only have one API to expose, you can omit the alias entirely — it defaults to `"main"`:

```lua
UniPlugin:setApi(nil, {
    doSomething = function() ... end,
})

-- equivalent to:
UniPlugin:setApi("main", {
    doSomething = function() ... end,
})
```

## Registering the Export

Once your APIs are set, call `exportAs` with a unique name. Convention is `"author/PluginName"`:

```lua
UniPlugin:exportAs("athar-adv/MyPlugin")
```

This fires a global signal so any plugin already waiting on `"athar-adv/MyPlugin"` via `withImports` is immediately unblocked.

:::tip Pick a unique alias
Because exports live in a shared global table, use a namespaced alias like `"your-name/PluginName"` to avoid collisions with other plugins.
:::

## Closing an Export

`exportAs` returns a `UniPluginConnection`. You can close it early to unregister the export before the plugin itself unloads:

```lua
local exportConn = UniPlugin:exportAs("athar-adv/MyPlugin")

-- later...
exportConn:close() -- removes the export from the shared table
```

You don't need to close it manually on plugin unload — UniPlugin handles that automatically.