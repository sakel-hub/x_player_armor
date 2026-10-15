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
---@field cache_index table<string, number> LRU access timestamps for disk cache management
---@field MAX_CACHE_FILES number Maximum number of cached models retained on disk
local media = {
	delivered_media = {},
	delivered_players = {},
	client_ready_media = {},
	player_ready_media = {},
	ready_callbacks = {},
	cache_index = {},
	MAX_CACHE_FILES = 200,
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

---Resolves the disk media cache directory path.
---Creates the directory on disk if it does not already exist.
---@return string? dir Absolute filesystem path to <worldpath>/x_player_armor_cache
function media.get_cache_dir()
	local worldpath = core.get_worldpath()
	if not worldpath or worldpath == "" then return nil end
	local dir = worldpath .. "/x_player_armor_cache"
	core.mkdir(dir)
	return dir
end

---Updates or registers the last access time of a cached model file.
---@param filename string Model filename
function media.touch_cache_entry(filename)
	media.cache_index[filename] = os.time()
end

---Resolves the absolute filepath for a cached model if it exists on disk.
---@param filename string Model filename (e.g. "x_pa_v16_abcd.glb")
---@return string? path Absolute path if file exists and has content, nil otherwise
function media.get_cached_filepath(filename)
	local dir = media.get_cache_dir()
	if not dir then return nil end
	local full_path = dir .. "/" .. filename
	local f = io.open(full_path, "rb")
	if f then
		local sz = f:seek("end")
		f:close()
		if sz and sz > 0 then
			media.touch_cache_entry(filename)
			return full_path
		end
	end
	return nil
end

---Enforces LRU bounds on the disk cache to prevent unbounded growth.
function media.prune_cache()
	local dir = media.get_cache_dir()
	if not dir then return end
	local files = core.get_dir_list(dir, false)
	if not files or #files <= media.MAX_CACHE_FILES then return end

	-- Sort ascending by access timestamp (oldest first)
	table.sort(files, function(a, b)
		local ta = media.cache_index[a] or 0
		local tb = media.cache_index[b] or 0
		return ta < tb
	end)

	local to_remove = #files - media.MAX_CACHE_FILES
	for i = 1, to_remove do
		local fname = files[i]
		core.rmdir(dir .. "/" .. fname, false)
		media.cache_index[fname] = nil
		media.delivered_media[fname] = nil
		media.client_ready_media[fname] = nil
		media.delivered_players[fname] = nil
		media.player_ready_media[fname] = nil
		media.ready_callbacks[fname] = nil
		local hash = fname:match("^(.-)%.glb$")
		if hash then
			x_player_armor.gltf_assembler.cache[hash] = nil
		end
	end
end

---Persists an assembled binary .glb model to the bounded disk cache.
---@param filename string Model filename
---@param filedata string Raw binary glb string
---@return string? path Full absolute path to written file
function media.save_cached_file(filename, filedata)
	if not filedata or filedata == "" then return nil end
	local dir = media.get_cache_dir()
	if not dir then return nil end
	local full_path = dir .. "/" .. filename
	local f = io.open(full_path, "wb")
	if f then
		f:write(filedata)
		f:close()
		media.touch_cache_entry(filename)
		media.prune_cache()
		return full_path
	end
	return nil
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
---Supports both in-memory streaming and zero-rebuild on-disk cached files.
---@param filename string Model filename
---@param filedata? string Raw binary glb string (optional if filepath provided)
---@param player_name string? Target player name or nil for global broadcast
---@param filepath string? Optional absolute filesystem path to cached .glb file
function media.deliver_media(filename, filedata, player_name, filepath)
	local disk_path = filepath or media.get_cached_filepath(filename)
	if not disk_path and (not filedata or filedata == "") then
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
		to_player = player_name,
		ephemeral = false,
		client_cache = true,
	}

	if disk_path then
		opts.filepath = disk_path
	else
		opts.filedata = filedata
	end

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
---Purges legacy storage and pre-registers existing disk cache models for fast client loading.
function media.init()
	media.purge_legacy_storage()
	local dir = media.get_cache_dir()
	if not dir then return end

	local files = core.get_dir_list(dir, false)
	if not files then return end

	for _, fname in ipairs(files) do
		if fname:match("%.glb$") then
			local full_path = dir .. "/" .. fname
			media.touch_cache_entry(fname)
			if core.features and core.features.dynamic_add_media_startup then
				local ok = core.dynamic_add_media({
					filename = fname,
					filepath = full_path,
					startup = true,
				})
				if ok ~= false then
					media.delivered_media[fname] = true
					media.client_ready_media[fname] = true
				end
			end
		end
	end
end

---Cleans up player-specific media delivery and readiness state on disconnect.
---@param player_name string Disconnecting player name
function media.cleanup_player(player_name)
	if not player_name or player_name == "" then return end
	for _, players in pairs(media.delivered_players) do
		players[player_name] = nil
	end
	for _, players in pairs(media.player_ready_media) do
		players[player_name] = nil
	end
end

---Clears media delivery registries and purges disk cache files.
function media.clear_cache()
	media.delivered_media = {}
	media.delivered_players = {}
	media.client_ready_media = {}
	media.player_ready_media = {}
	media.ready_callbacks = {}
	media.cache_index = {}
	media.purge_legacy_storage()
	local dir = media.get_cache_dir()
	if dir then
		core.rmdir(dir, true)
	end
end

return media
