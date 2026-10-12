--[[
	X Player Armor - glTF 2.0 In-Memory Dynamic Model Assembler: Media Pipeline Subsystem
	Author: SaKeL
	License: LGPL-2.1+ / CC-BY-4.0 / CC0 1.0

	Manages on-the-fly dynamic media streaming via core.dynamic_add_media,
	targeted delivery deduplication, client readiness tracking, and legacy storage cleanup.
]]

---@class XPlayerArmorAssemblerMedia
---@field delivered_media table<string, boolean> Map of media filenames broadcast globally to all clients
---@field delivered_players table<string, table<string, boolean>> Map of media filenames to tables of targeted player names
---@field client_ready_media table<string, boolean> Map of media filenames acknowledged as ready on client
---@field player_ready_media table<string, table<string, boolean>> Map of media filenames to tables of players acknowledging readiness
---@field ready_callbacks table<string, fun()[]> Map of media filenames to pending readiness callbacks
local media = {
	delivered_media = {},
	delivered_players = {},
	client_ready_media = {},
	player_ready_media = {},
	ready_callbacks = {},
}

---Resolves the legacy world media directory path for cleanup purposes.
---@return string? dir Absolute filesystem path to <worldpath>/x_player_armor_media
function media.get_media_dir()
	local worldpath = core.get_worldpath()
	if not worldpath or worldpath == "" then return nil end
	return worldpath .. "/x_player_armor_media"
end

---Purges legacy disk media directory (<worldpath>/x_player_armor_media) to eliminate leftover files.
function media.purge_legacy_storage()
	local dir = media.get_media_dir()
	if not dir then return end
	core.rmdir(dir, true)
end

---Checks if a dynamically assembled mesh is already downloaded and ready on the client.
---@param filename string Model filename
---@param player_name string? Optional player name for targeted delivery check
---@return boolean is_ready
function media.is_media_ready(filename, player_name)
	if player_name then
		if media.player_ready_media[filename] and media.player_ready_media[filename][player_name] then
			return true
		end
		if media.delivered_media[filename] and media.client_ready_media[filename] then
			return true
		end
		return false
	end
	return media.client_ready_media[filename] == true
end

---Queues or executes a callback once the specified dynamic media is acknowledged as ready on the client.
---@param filename string Model filename
---@param callback fun() Callback function executed when media is ready
function media.when_media_ready(filename, callback)
	if not callback then return end
	if media.client_ready_media[filename] then
		callback()
		return
	end
	media.ready_callbacks[filename] = media.ready_callbacks[filename] or {}
	table.insert(media.ready_callbacks[filename], callback)
end

---Marks a dynamic media file as ready on clients and dispatches any queued readiness callbacks.
---@param filename string Model filename
---@param player_name string? Optional player name acknowledging receipt
function media.mark_media_ready(filename, player_name)
	if player_name then
		media.player_ready_media[filename] = media.player_ready_media[filename] or {}
		media.player_ready_media[filename][player_name] = true
	end
	if media.client_ready_media[filename] then return end
	media.client_ready_media[filename] = true

	local cbs = media.ready_callbacks[filename]
	if cbs then
		media.ready_callbacks[filename] = nil
		for i = 1, #cbs do
			cbs[i]()
		end
	end
end

---Delivers an assembled .glb model to clients on the fly via core.dynamic_add_media.
---Zero disk writes: transmits directly from Lua memory to clients.
---@param filename string Model filename
---@param filedata string Raw binary glb string
---@param player_name string? Target player name or nil for global broadcast
function media.deliver_media(filename, filedata, player_name)
	if not filedata or filedata == "" then
		return
	end

	-- Deduplicate delivery
	if player_name then
		if media.delivered_media[filename] then
			return
		end
		media.delivered_players[filename] = media.delivered_players[filename] or {}
		if media.delivered_players[filename][player_name] then
			return
		end
		media.delivered_players[filename][player_name] = true
	else
		if media.delivered_media[filename] then
			return
		end
		media.delivered_media[filename] = true
	end

	local opts = {
		filename = filename,
		filedata = filedata,
		to_player = player_name,
		ephemeral = false,
		client_cache = true,
	}

	local ok = core.dynamic_add_media(opts, function(target_name)
		core.log("verbose", "[x_player_armor] Dynamic media " .. filename .. " delivered to " .. tostring(target_name))
		media.mark_media_ready(filename, target_name or player_name)
	end)
	core.log("verbose", "[x_player_armor] dynamic_add_media " .. filename .. " accepted: " .. tostring(ok))

	core.after(0.2, function()
		media.mark_media_ready(filename, player_name)
	end)
end

---Initializes the dynamic media subsystem on server boot.
---Purges any legacy on-disk media storage to reclaim disk space.
function media.init()
	media.purge_legacy_storage()
end

---Clears media delivery registries and pending readiness callbacks, and purges legacy storage.
function media.clear_cache()
	media.delivered_media = {}
	media.delivered_players = {}
	media.client_ready_media = {}
	media.player_ready_media = {}
	media.ready_callbacks = {}
	media.purge_legacy_storage()
end

return media
