---
sidebar_position: 4
---

# Managing Connections & Cleanup

Every method that sets up a subscription in UniPlugin returns a `UniPluginConnection`. Understanding when and how to close these is important for keeping plugins well-behaved.

## Automatic Cleanup

You don't need to manually close anything on plugin unload. UniPlugin connects to `plugin.Unloading` and `plugin.Destroying` and closes everything — exports, imports, and `onClose` listeners — automatically.

## UniPluginConnection

Every connection has two members:

- `isClosed: boolean` — `true` after `close()` has been called
- `close()` — tears down the subscription; safe to call multiple times (subsequent calls are no-ops)

```lua
local conn = UniPlugin:exportAs("athar-adv/MyPlugin")

print(conn.isClosed) -- false

conn:close()

print(conn.isClosed) -- true
conn:close()          -- no-op, no error
```

## onClose

Register a callback to fire when the UniPlugin itself is closed (i.e. the plugin unloads or is destroyed):

```lua
UniPlugin:onClose(function()
    toolbar:Destroy()
    widget:Destroy()
end)
```

You can register as many `onClose` listeners as you like — all of them fire. The returned connection lets you cancel a listener early if needed:

```lua
local listener = UniPlugin:onClose(function()
    print("closing!")
end)

-- changed your mind:
listener:close()
```

## Cleaning Up Imports

Use `onImportClosed` inside a `withImports` handler to clean up anything tied to that import group's lifetime:

```lua
UniPlugin:withImports({"athar-adv/PluginA"}, function(plugins, onImportClosed)
    local api = plugins():getApi("main")

    local rbxConn = api.SomeEvent:Connect(function() ... end)
    local toolbar = plugin:CreateToolbar("My Toolbar")

    onImportClosed(function()
        rbxConn:Disconnect()
        toolbar:Destroy()
    end)
end)
```

This fires whenever the import group tears down — whether because a dependency closed or because you closed the returned `UniPluginConnection` manually.

## Closing UniPlugin Manually

If you need to shut down your UniPlugin early (e.g. in response to a UI button), call `close()` directly:

```lua
closeButton.Activated:Connect(function()
    UniPlugin:close()
end)
```

After `close()`, calling any method on the UniPlugin throws an error. Check `UniPlugin.isClosed` if you're unsure of its state.