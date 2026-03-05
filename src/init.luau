--!strict
--!optimize 2
--version 0.0.0

--[[
	UniPlugin: Plugins, unified.
	
	Author: athar_adv
]]

export type Api = {[string]: any}
export type UniPluginListener = {
	close: (UniPluginListener) -> (),
	isClosed: boolean
}

local exports: {[string]: UniPlugin} = shared

local MAIN_API_ALIAS = "main"

if not shared.__UniPluginExportOpened then
	shared.__UniPluginExportOpened = Instance.new("BindableEvent")
end
local ExportOpened: BindableEvent = shared.__UniPluginExportOpened

local UniPlugin = {}

type Impl = {
	plugin: Plugin,
	apis: {[string]: Api},
	onCloseListeners: {() -> ()},
	listenersToClose: {UniPluginListener},
	isClosed: boolean,
	closerConnections: {RBXScriptConnection}
}
export type UniPlugin = typeof(UniPlugin) & Impl
export type ImportedUniPlugins = () -> ...UniPlugin

local function findAndRemove<V>(tbl: {[any]: V}, v: V)
	local idx = table.find(tbl, v)
	if idx then table.remove(tbl, idx) end
end

local function checkIsClosed(self: UniPlugin, methodName: string)
	if self.isClosed then
		error(`UniPlugin '{self.plugin.Name}' is closed, cannot call UniPlugin:{methodName}(...)`, 0)
	end
end

--[[
	Registers this UniPlugin under <code>alias</code> in the shared exports table, making
	it discoverable by other plugins calling <code>withImports</code>. Fires the global
	ExportOpened event so any waiting <code>withImports</code> listeners are unblocked.

	The returned listener's <code>close</code> removes the export and can be called
	manually; it is also called automatically when the plugin unloads or is
	destroyed.
]]
function UniPlugin.exportAs(self: UniPlugin, alias: string): UniPluginListener
	checkIsClosed(self, "exportAs")
	
	exports[alias] = self
	ExportOpened:Fire(alias)

	local onClose
	local conn = {
		close = function(conn: UniPluginListener)
			if conn.isClosed then return end
			conn.isClosed = true

			findAndRemove(self.listenersToClose, conn)
			onClose:close()
			exports[alias] = nil
		end,
		isClosed = false
	}
	onClose = self:bindToClose(function()
		conn:close()
	end)
	table.insert(self.listenersToClose, conn)
	return conn
end

--[[
	Waits for all plugins in <code>aliases</code> to be exported, then calls <code>handler</code>
	with two arguments:
	  * <code>plugins()</code> — returns all resolved UniPlugins in the same order as <code>aliases</code> via multiple returns.
	  * <code>bindOnImportClosed(fn)</code> — registers a single callback (overwriting any previous one) that fires whenever this import group is torn down, whether because one of the imported plugins closed naturally or because the returned listener was closed manually.

	The handler re-runs automatically each time all aliases become available
	again after a close. Duplicate aliases are silently deduplicated. Passing
	an empty <code>aliases</code> table is a no-op and returns an inert listener.

	Close the returned listener to stop listening entirely and tear down the
	current import group.
]]
function UniPlugin.withImports(self: UniPlugin, aliases: {string}, handler: (plugins: ImportedUniPlugins, bindOnImportClosed: (fn: () -> ()) -> ()) -> ()): UniPluginListener
	checkIsClosed(self, "withImports")
	
	if #aliases == 0 then
		return {
			close = function(conn) conn.isClosed = true end,
			isClosed = false
		}
	end

	local seen: {[string]: boolean} = {}
	local dedupedAliases: {string} = {}
	for _, alias in aliases do
		if not seen[alias] then
			seen[alias] = true
			table.insert(dedupedAliases, alias)
		end
	end

	local onCloses: {UniPluginListener} = {}
	local generation = 0
	local onImportClosed: (() -> ())?

	local conn
	local function onPlugins(unips: {[string]: UniPlugin})
		local currentGen = generation
		for _, unip in unips do
			local onClose = unip:bindToClose(function()
				if generation ~= currentGen then return end
				generation += 1
				for _, oc in onCloses do oc:close() end
				table.clear(onCloses)
				local cb = onImportClosed
				onImportClosed = nil
				if cb then cb() end
				conn:close()
				self:withImports(aliases, handler)
			end)
			table.insert(onCloses, onClose)
		end
		local ordered: {UniPlugin} = {}
		for _, alias in dedupedAliases do
			table.insert(ordered, unips[alias])
		end
		handler(
			function()
				return table.unpack(ordered)
			end,
			function(fn)
				onImportClosed = fn
			end
		)
	end

	local listenerConn: RBXScriptConnection
	local t = task.spawn(function()
		local resolved: {[string]: UniPlugin} = {}
		local unresolved: {[string]: boolean} = {}

		for _, alias in dedupedAliases do
			if exports[alias] then
				resolved[alias] = exports[alias]
			else
				unresolved[alias] = true
			end
		end

		if next(unresolved) then
			listenerConn = ExportOpened.Event:Connect(function(alias: string)
				if not unresolved[alias] then return end
				resolved[alias] = exports[alias]
				unresolved[alias] = nil
				if next(unresolved) == nil then
					listenerConn:Disconnect()
					onPlugins(resolved)
				end
			end)

			for alias in unresolved do
				if exports[alias] then
					resolved[alias] = exports[alias]
					unresolved[alias] = nil
				end
			end
			if next(unresolved) == nil then
				listenerConn:Disconnect()
				onPlugins(resolved)
			end
		else
			onPlugins(resolved)
		end
	end)

	conn = {
		close = function(conn: UniPluginListener)
			if conn.isClosed then return end
			conn.isClosed = true
			findAndRemove(self.listenersToClose, conn)

			generation += 1
			if listenerConn then listenerConn:Disconnect() end
			for _, oc in onCloses do oc:close() end
			table.clear(onCloses)
			local cb = onImportClosed
			onImportClosed = nil
			if cb then cb() end
			if coroutine.status(t) ~= "dead" then
				task.cancel(t)
			end
		end,
		isClosed = false
	}
	table.insert(self.listenersToClose, conn)

	return conn
end

--[[
	Registers <code>fn</code> to be called when this plugin is torn down (i.e. when the
	plugin unloads or is destroyed). Multiple listeners can be registered and
	all will fire on close.

	The returned listener's <code>close</code> unregisters <code>fn</code> and can be used to cancel
	the subscription before the plugin closes.
]]
function UniPlugin.bindToClose(self: UniPlugin, fn: () -> ()): UniPluginListener
	checkIsClosed(self, "bindToClose")
	
	table.insert(self.onCloseListeners, fn)
	local conn = {
		close = function(conn: UniPluginListener)
			if conn.isClosed then return end
			conn.isClosed = true
			findAndRemove(self.onCloseListeners, fn)
			findAndRemove(self.listenersToClose, conn)
		end,
		isClosed = false
	}
	table.insert(self.listenersToClose, conn)
	return conn
end

--[[
	Stores <code>api</code> under <code>alias</code> (defaults to "main") on this UniPlugin.
	Retrieve it from another plugin via <code>getApi</code>.
]]
function UniPlugin.setApi(self: UniPlugin, alias: string?, api: Api): ()
	checkIsClosed(self, "setApi")
	
	local alias = alias or MAIN_API_ALIAS
	self.apis[alias] = api
end

--[[
	Returns the Api stored under <code>alias</code> (defaults to "main").
	Errors if no Api has been set for that alias.
]]
function UniPlugin.getApi(self: UniPlugin, alias: string?): Api
	checkIsClosed(self, "getApi")
	
	local alias = alias or MAIN_API_ALIAS
	return assert(self.apis[alias], `Could not find Api '{alias}' inside UniPlugin '{self.plugin.Name}'`)
end

--[[
	Closes this <code>UniPlugin</code>. Cleans up any listeners, fires <code>bindToClose</code> handlers and makes all methods error on call.
]]
function UniPlugin.close(self: UniPlugin)
	if self.isClosed then return end
	self.isClosed = true
	for _, v in self.closerConnections do
		v:Disconnect()
	end
	for _, v in table.clone(self.onCloseListeners) do
		v()
	end
	for _, v in table.clone(self.listenersToClose) do
		v:close()
	end
	table.clear(self.closerConnections)
	table.clear(self.onCloseListeners)
	table.clear(self.listenersToClose)
end

local created = {}

--[[
	Returns the UniPlugin instance for the given <code>plugin</code>, creating it if one
	doesn't already exist. Only one UniPlugin is ever created per Plugin
	instance for the lifetime of the studio session.

	Automatically connects to <code>plugin.Unloading</code> and <code>plugin.Destroying</code> to
	fire all <code>bindToClose</code> listeners and close all active <code>withImports</code> and
	<code>exportAs</code> listeners when the plugin is torn down.
]]
local function openUniPlugin(plugin: Plugin): UniPlugin
	local existing = created[plugin]
	if existing then return existing end

	local uniPlugin = {
		plugin = plugin,
		apis = {},
		onCloseListeners = {},
		listenersToClose = {},
		isClosed = false,
		
		exportAs = UniPlugin.exportAs,
		withImports = UniPlugin.withImports,
		bindToClose = UniPlugin.bindToClose,
		close = UniPlugin.close,

		setApi = UniPlugin.setApi,
		getApi = UniPlugin.getApi
	} :: UniPlugin
	created[plugin] = uniPlugin
	
	uniPlugin.closerConnections = {
		plugin.Destroying:Connect(function()
			uniPlugin:close()
		end),
		plugin.Unloading:Connect(function()
			uniPlugin:close()
		end)
	}

	return uniPlugin
end

return openUniPlugin